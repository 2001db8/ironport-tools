#!/usr/bin/perl -w

#Tomki
#Jan 2007

use strict;
use Getopt::Long;
use Time::Local;
use CSV;
use File::Spec;
use re 'eval';

our %optctl;
#set some defaults
$optctl{'searchrange'} = 2; #days
$optctl{'basedir'} = './hiertest'; #base directory to look for matches
$optctl{'trackfile'} = 'track.csv'; #base directory to look for matches

GetOptions (\%optctl,
	'help',
	'search=s',
	'searchrange=s',
	'range=s',
	'startdate=s',
	'enddate=s',
	'csv',
	'basedir=s',
	'trackfile=s',
	'debug'
	);

#Get information about today's date
#      0    1    2        3        4         5     6     7     8
our ($sec,$min,$hour,$mday_now,$mon_now,$year_now,$wday,$yday,$isdst) = localtime(time);
$mday_now = sprintf("%02d", $mday_now); #get $mday in a DD format
$mon_now++; #to get into a 1-12 range
$mon_now = sprintf("%02d", $mon_now); #get $mon in a MM format
$year_now += 1900; #to get full current year
#Set epochtime1 to be the now time in case startdate was not provided:
$optctl{'epochtime1'} = timelocal(0, 0, 0, $mday_now, $mon_now-1, $year_now);

#How many seconds in 1 day?
our $seconds_ina_day = 60 * 60 * 24;
our $seconds_offset = 0;

#Check the inputs and do some processing around them:
exit unless &process_opts(\%optctl);

my $header = '';
#Now go thru the time range determined, checking for matches in directories
my $etime_check = $optctl{'epochtime1'}; #current epochtime to check

my $proctime = time();
my $linecount = 0;
my $matchcount = 0;

while ($etime_check <= $optctl{'epochtime2'}) {
	my ($mday_check, $mon_check, $year_check) = (localtime($etime_check))[3,4,5];
	$mday_check = sprintf("%02d", $mday_check); #get $mday in a DD format
	$mon_check++; #to get into a 1-12 range
	$mon_check = sprintf("%02d", $mon_check); #get $mon in a MM format
	$year_check += 1900; #to get full year
	my $thisdate = "$year_check-$mon_check-$mday_check";

	my $dir = File::Spec->catfile($optctl{'basedir'}, $year_check, $mon_check, $mday_check);
	my $dir_file = File::Spec->catfile($dir, $optctl{'trackfile'});
	#name of the file if it's not in a subdir, but has the date format in the name:
	my $datefile_tracker = File::Spec->catfile($optctl{'basedir'}, "$thisdate-$optctl{'trackfile'}");

	if ($optctl{'debug'}) {
		print STDERR "Now checking '$dir'\n";
	}

	my $onefile = 0; #indicate if the data isn't in hierarchical dirs
	my $nogood = 0;  #indicate if checks found some problem
	if (-e $datefile_tracker) {
		$onefile = 1;
		$dir_file = $datefile_tracker;
	}
	elsif ((!-e $dir_file) and (!-e $datefile_tracker)) {
		if ($optctl{'debug'}) {
			print STDERR "\t - trackfile for $thisdate does not exist\n";
		}
		$nogood = 1;
	}

	if (!$nogood and !open(CSV, "<$dir_file")) {
		if ($optctl{'debug'}) {
			print STDERR "Could not open '$dir_file' for reading: $!\n";
		}
		$nogood = 1;
	}
	if ($nogood) {
		#Increment to next day
		$etime_check += $seconds_ina_day;
		next;
	}

	#Got here, the file is in this dir and opened ok
	if ($optctl{'debug'}) {
		print STDERR "\t - found $dir_file\n";
	}

	#Get the 1st line, header line
	my $header_check = readline(*CSV); #1st line
	chomp($header_check);
	if ($header eq '') { #first time
		$header = $header_check;
	}
	elsif ($header ne $header_check) {
		if ($optctl{'debug'}) {
			print STDERR "New header is not the same as in previously processed files.\n";
			print STDERR "OLD:\n$header\nNEW:\n$header_check\n";
		}
		$header = $header_check;
	}
	my %fieldLayout = CSVinit($header);

	my @matches;
	#Now iterate over the file looking for our matches:
	while (my $fileline = readline(*CSV)) {
		$linecount++;
		if ($fileline =~ m/$optctl{'search'}/i) {
			$matchcount++;
			if ($optctl{'debug'}) {
				print STDERR "$matchcount Matched $&\n";
			}
			chomp($fileline);
			push @matches, $fileline;
		}
	}
	close(CSV); #close out the CSV filehandle

	foreach my $line (@matches) {
		&printmatch_fromCSV($line);
	}

	#Increment to next day
	$etime_check += $seconds_ina_day;
} #while less than end of check time epochtime2

#How long did it take to process that stuff?
$proctime = (time() - $proctime) || 1; #set to 1 if it is 0
print "Searched $linecount lines for $matchcount matches in $proctime seconds.\n";


sub printmatch_fromCSV {
	my ($line) = @_;
	my @linevalues = CSVsplit($line);
	my %values_hash;
	my $count = 0;
	#Populate a hash relating the header name to the value for that column:
	foreach my $key (split /,/, $header) {
		$values_hash{$key} = $linevalues[$count++];
	}

	#Print out certain fields in this desired ordering:
	# and then delete them so that the 'all the rest' print out doesn't get them again
	foreach my $field ('Envelope From', 'Subject', 'Recipients and resolution', 'Message size (bytes)', 'AS-Pos', 'AV-Pos', 'Time-In', 'Time-done', 'SenderGroup', 'Policy') {
		#Just skip this header if for some reason it's not there
		next if !$values_hash{$field};
		print "$field\t$values_hash{$field}\n";
		#Delete this entry from the hash so that the
		# "remaining fields" printout below doesn't reprint it
		delete $values_hash{$field};
	}
	#Print out the remaining fields:
	foreach my $key (sort keys %values_hash) {
		print "$key\t$values_hash{$key}\n";
	}
	print "-" x 55 . "\n";
	return 1;
}

# process/check input options, develop their internal use
sub process_opts {
	my $optctl = $_[0];

	if ($$optctl{'help'}) {
		&printhelp();
		return 0;
	}

	#Make easier synonym for 'searchrange'
	if ($optctl{'range'}) {
		$optctl{'searchrange'} = $optctl{'range'};
	}

	if ($optctl{'searchrange'}) {
		if ($optctl{'searchrange'} !~ m/^\d{1,3}$/) {
			print STDERR "-searchrange must be a 3-digit integer\n";
			return 0;
		}
		$seconds_offset = $seconds_ina_day * $optctl{'searchrange'};
	}

	if ($optctl{'enddate'} and !$optctl{'startdate'}) {
		print STDERR "-enddate cannot be provided without -startdate\n";
		return 0;
	}
	if ($optctl{'startdate'}) {
		if ($optctl{'startdate'} !~ m/^(\d{4})[-\/](\d{2})[-\/](\d{2})$/) {
			print STDERR "-startdate entry format must be YYYY-MM-DD\n";
			return 0;
		}
		elsif (($1 > $year_now) or ($2 > 12) or ($3 > 31)) {
			print STDERR "-startdate entry format problem\n";
			return 0;
		}
		else { #all looks ok?
			#Determine and set the epoch time for the startdate provided
			$optctl{'epochtime1'} = timelocal(0, 0, 0, $3, $2-1, $1);

			#startdate provided, so the 2nd epoch date is the first PLUS the offset
			$optctl{'epochtime2'} = $optctl{'epochtime1'} + $seconds_offset;
			#This will be changed in a few lines, if enddate is given as well
		}
	}
	#If startdate was not provided, the 2nd epoch date is the first MINUS the offset
	else {
		$optctl{'epochtime2'} = $optctl{'epochtime1'} - $seconds_offset;
	}

	if ($optctl{'enddate'}) {
		if ($optctl{'enddate'} !~ m/^(\d{4})[-\/\.](\d{2})[-\/\.](\d{2})$/) {
			print STDERR "-enddate entry format must be YYYY-MM-DD\n";
			return 0;
		}
		elsif (($1 > $year_now) or ($2 > 12) or ($3 > 31)) {
			print STDERR "-enddate entry format problem\n";
			return 0;
		}
		else { #all looks ok?
			#Determine and set the epoch time for the enddate provided
			$optctl{'epochtime2'} = timelocal(0, 0, 0, $3, $2-1, $1);
		}
	}

	$optctl{'basedir'} =~ s/\/$//g; #cut off trailing slashes
	if (! -e $optctl{'basedir'}) {
			print STDERR "-basedir entry '$optctl{'basedir'}' does not exist\n";
			return 0;
	}

	#swap!
	if ($optctl{'epochtime1'} > $optctl{'epochtime2'}) {
		my $tmp = $optctl{'epochtime2'};
		$optctl{'epochtime2'} = $optctl{'epochtime1'};
		$optctl{'epochtime1'} = $tmp;
	}

	if ($optctl{'debug'}) {
		print STDERR "Determined epochtime1 to be $optctl{'epochtime1'}\n";
		print STDERR "  Which equates to " . localtime($optctl{'epochtime1'}) . "\n";
		print STDERR "Determined epochtime2 to be $optctl{'epochtime2'}\n";
		print STDERR "  Which equates to " . localtime($optctl{'epochtime2'}) . "\n";
	}

	if ($optctl{'basedir'}) {
		if (! -e $optctl{'basedir'}) {
			print STDERR "-basedir entry '$optctl{'basedir'}' does not exist here?\n";
			return 0;
		}
		elsif (! -d $optctl{'basedir'}) {
			print STDERR "-basedir entry '$optctl{'basedir'}' is not a directory.\n";
			return 0;
		}
	}

	return 1;
} #process_opts

sub printhelp {
	print "Program options:
	-search		Text to match upon
	-searchrange	Number of days back to look for matches (default $optctl{'searchrange'})
			If no 'startdate' is provided this range is backward
			If 'startdate' is provided this range is forward
	-startdate	Optional - date in yyyy/mm/dd format from whence to look
			for matches
	-enddate	Optional - date in yyyy/mm/dd format until whence to look
			for matches - will cause searchrange to be ignored
	-csv		Display raw results, CSV format data
	-basedir	Specify base directory of the hierarchy to search

Example use:
	$0 -basedir logs -search 'commission' -searchrange 5

If basedir is predefined properly and you only want to search the last 2 days:
	$0 -search 'commission'

If you want to search a specific date range:
	$0 -startdate 2007/02/05 -enddate 2007/02/08 -search 'commission'

";
	return 1;
} #printhelp


