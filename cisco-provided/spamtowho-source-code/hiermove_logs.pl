#!/usr/bin/perl -w

#This script should be run from a cron job.
#Its purpose is to check for new log files in a directory, and move new
# log files into a heirarchical directory structure.
# 'searchhier.pl' has been designed to search against the CSV digest
# generated by spamtowho.pl

# Tomki
# Dec 2006

use strict;
use Getopt::Long;
use File::Copy;
use File::Spec;

our $spamtowho = 'spamtowho.exe'; #Windows version by default
if ($^O ne 'MSWin32') {
	$spamtowho = './spamtowho.pl'; #for UNIX-type environments
}

our %optctl;
$optctl{'move'} = 1; #move by default
$optctl{'copy'} = 0;
$optctl{'html'} = 0; #no html by default

#d - directory to check for new mail log files
#t - directory base of the heirarchy to move new logs into
GetOptions (\%optctl,
	'rd=s',
	'td=s',
	'norun', #to indicate not to run spamtowho this time
	'move',
	'copy',
	'html',
	'debug',
	'help',
	   );

if ($optctl{'help'}) {
	&printhelp();
	exit;
}
if ((!-e "$spamtowho")  and !$optctl{'norun'}){
	print STDERR "$spamtowho not found, required for execution.\n";
	exit(0);
}
elsif (!$optctl{'rd'} or !$optctl{'td'}) {
	print STDERR "-rd and -td parameters must be provided.\n";
	exit;
}
elsif (!-e $optctl{'rd'}) {
	print STDERR "Directory '$optctl{'rd'}' to check for new files - does not exist\n";
	exit;
}
elsif (!-e $optctl{'td'}) {
	print STDERR "Directory '$optctl{'td'}' to  place new files - does not exist\n";
	exit;
}
if ($optctl{'copy'}) {
	$optctl{'move'} = 0;
}


#mostly for cleanliness, strip trailing slashes on input strings
$optctl{'td'} =~ s/(?:[\\\/])$//;
$optctl{'rd'} =~ s/(?:[\\\/])$//;

opendir(DIR, $optctl{'rd'});
my @infiles = readdir(DIR);
closedir(DIR);

my %movefiles; #Reference newly discovered file pointing to target location
my %newfiles_perdir; #Reference all new files moved, per directory
my @createddirs; #List of all new directories created

#Iterate over the new files found, do whatever is appropriate with them
foreach my $file (@infiles) {
	#Check for '.' or '..', skip them
	#also skip directories
	if (($file eq '.') or ($file eq '..') or (-d "$optctl{'rd'}/$file")) {
		next;
	}
	
	#filenames must be in a format such as: mail.@20061107T182155.s
	if ($file !~ m/(\d{4})(\d{2})(\d{2})T\d{6}\.(?:c|s|(?:log))$/) {
		if ($optctl{'debug'}) {
			print STDERR "Skipping '$file': mail_log filenames must have a time-stamp and end in .c, .s, or .log.\n";
		}
		next;
	}
	my $year = $1;
	my $month = $2;
	my $day = $3;
	my $serialNumber = '';
#my $path_and_file = "$optctl{'rd'}/$file";
	my $path_and_file = File::Spec->catfile($optctl{'rd'}, $file);

	if (-f $path_and_file) { #plain file
		#test general mail-log format validity
		if (open (FILE, "<$path_and_file")) {
			# 2 format examples:
			#Wed May  4 00:24:31 2005 Info: Begin Logfile
			#Wed May  4 00:24:31 2005 Info: Version: 3.8.4-003 SN: 000F1F6ACFA6-2Y5SQ41
			#Mon May  9 15:32:11 2005 Info: Begin Logfile
			#Mon May  9 15:32:11 2005 Info: Version: 4.0.7-011 SN: 000BDBE64917-C4GYF31
			my $line1 = <FILE>;
			my $line2 = <FILE>;
			close(FILE);
			if (!$line1 or ($line1 !~ m/^\w{3} .{15} \d{4} Info: Begin Logfile$/mo)) {
				print STDERR "File $path_and_file does not conform to expected mail log format. (line1) Skipping.\n";
				next;
			}
			if (!$line2 or ($line2 !~ m/ Info: Version: .+ SN: (\S+)$/mo)) {
				print STDERR "File $path_and_file does not conform to expected mail log format. (line2) Skipping.\n";
				next;
			}
			$serialNumber = $1;
		}
		else {
			print STDERR "Cannot open $path_and_file, skipping. $!\n";
			next;
		}

		#Check for any MISSING DIRECTORIES
		my $createdDir = 0;
		#If the year dir doesn't exist, create it
		my $yearpath = File::Spec->catfile($optctl{'td'}, $year);
		if (!-e $yearpath) {
#if (!-e "$optctl{'td'}/$year") {
			mkdir($yearpath) or die "Failed to make year-dir $yearpath: $!";
			$createdDir++;
			if ($optctl{'debug'}) {
				print STDERR "Created directory '$yearpath'\n";
			}
		}
		#If the month dir doesn't exist, create it
		my $monthpath = File::Spec->catfile($optctl{'td'}, $year, $month);
#if (!-e "$optctl{'td'}/$year/$month") {
		if (!-e $monthpath) {
			mkdir($monthpath) or die "Failed to make month-dir $monthpath: $!";
			$createdDir++;
			if ($optctl{'debug'}) {
				print STDERR "Created directory '$monthpath'\n";
			}
		}
		#If the day dir doesn't exist, create it
		my $daypath = File::Spec->catfile($optctl{'td'}, $year, $month, $day);
		if (!-e $daypath) {
#if (!-e "$optctl{'td'}/$year/$month/$day") {
			mkdir($daypath) or die "Failed to make day-dir $daypath: $!";
			$createdDir++;
			if ($optctl{'debug'}) {
				print STDERR "Created directory '$daypath'\n";
			}
		}
		#If the SN dir doesn't exist, create it
		my $SNpath = File::Spec->catfile($optctl{'td'}, $year, $month, $day, $serialNumber);
		if (!-e $SNpath) {
#if (!-e "$optctl{'td'}/$year/$month/$day/$serialNumber") {
			mkdir($SNpath) or die "Failed to make SN-dir $SNpath: $!";
			$createdDir++;
			if ($optctl{'debug'}) {
				print STDERR "Created directory '$SNpath'\n";
			}
		}
		if ($createdDir) {
			push @createddirs, $SNpath;
		}
		#DONE creating missing directories

		#Keep track of the current file and where it's supposed to be moved to:
		$movefiles{$path_and_file} = File::Spec->catfile($SNpath, $file);

		#Construct a string that will be used to launch spamtowho processing of new log files
		# for each directory that gets new log files.
		$newfiles_perdir{$SNpath} .= " -f $movefiles{$path_and_file}";
	}
	else {
		print STDERR "Failed to understand '$path_and_file' - skipping\n";
	}
} #foreach file

my $movedfiles_count = 0;
my $action = "Moved";
if ($optctl{'copy'}) {
	$action = "Copied";
}
	
foreach my $file (keys %movefiles) {
	if (-e $movefiles{$file}) {
		my $size1 = -s $file;
		my $size2 = -s $movefiles{$file};
		if ($size1 == $size2) {
			print STDERR "'$file' target '$movefiles{$file}' exists.  Not moving/copying.\n";
			next;
		}
		else {
			print STDERR "'$file' target '$movefiles{$file}' exists but is a different size. ($size1 vs $size2) Overwriting.\n";
		}
	}
	if ($optctl{'move'}) {
		move("$file", "$movefiles{$file}") or die "Failed to perform action: move(\"$file\", \"$movefiles{$file}\").  $!\n";
	}
	elsif ($optctl{'copy'}) {
		copy("$file", "$movefiles{$file}") or die "Failed to perform action: copy(\"$file\", \"$movefiles{$file}\").  $!\n";
	}
	$movedfiles_count++;
	if ($optctl{'debug'}) {
		print STDERR "$action '$file' to '$movefiles{$file}'\n";
	}
}
if ($optctl{'debug'}) {
	print STDERR "Read $optctl{'rd'} and $action $movedfiles_count files.\n";
}


if ($optctl{'norun'}) {
	if ($optctl{'debug'}) {
		print STDERR "-norun given, not digesting logs\n";
	}
	exit(0);
}

#Now run an instance of spamtowho against all of the new log files in each dir.
#The msg-csv extract will be appended to any existing msg-csv file
foreach my $targetDir (keys %newfiles_perdir) {
	my $csvDir = $targetDir;
	$csvDir =~ s/^(.+)[\\\/](\w+-\w+)/$1/; #strip off SN directory
	$csvDir = File::Spec->catfile($csvDir, "track.csv");
	my $runThis = "$spamtowho -skip-processed -d $targetDir -msg-csv $csvDir";
	if ($optctl{'html'}) {
		$runThis .= " -htmloutput " . File::Spec->catfile($targetDir, 'statistics.html');
		#Copy over files necessary for the HTML output file:
		copy("diagram.js", "$targetDir") or die "Failed to perform action: copy(\"diagram.js\", \"$targetDir\").  $!\n";
		copy("diagram_dom.js", "$targetDir") or die "Failed to perform action: copy(\"diagram_dom.js\", \"$targetDir\").  $!\n";
		copy("diagram_nav.js", "$targetDir") or die "Failed to perform action: copy(\"diagram_nav.js\", \"$targetDir\").  $!\n";
	}
	if ($optctl{'debug'}) {
		$runThis .= " -noquiet";
		print STDERR "$runThis\n";
	}
	`$runThis`;
}

sub printhelp {
	print "Flags for this program are:
	-rd Read Directory - indicate what directory to check for new log files
	-td Target Directory - indicate what base directory to move log files into
	-norun Flag to indicate that CSV collation should not be performed
	-copy  Flag to indicate that log files should be copied rather than moved
	-html - create HTML statistics file for current files processed
	-debug - verbose output and progress data
	-help - this output\n";
	return 1;
}


