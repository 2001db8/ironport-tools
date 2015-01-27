#!/usr/bin/perl -w

#Tomki
#Feb 9 2004

require 5.006;
package spamtowho;
use strict;

BEGIN {
	#help spamtowho compile/run on Windows
	push @INC, 'c:\Perl\site\lib';
	$| = 1;
	#help spamtowho run via parl on an MGA.
	#dig out possible CASE lib dir, put it on @INC
	#var/log/godspeed/third_party/case/tmp/par-SYSTEM/cache-e5929db0d40ba803bff44ebea561ee8365d7516b/inc/lib/
	#To run in this circumstance, use the command like so:
	#/var/log/godspeed/third_party/case/libexec/tools-1.1.0-002/parl spamtowho.pl -f ../mail.current
	my $parldir = '/var/log/godspeed/third_party/case/tmp/par-SYSTEM/';
	if (-e "$parldir") {
		if (!opendir(DIR, $parldir)) {
			print STDERR "Error - parldir $parldir exists but I failed to open it: $!";
			exit(1);
		}
		my @dirs = readdir(DIR);
		shift @dirs; #move off '.'
		shift @dirs; #move off '..'
		if (scalar(@dirs) > 1) { #I'm not sure what to expect here
			print STDERR "parldir $parldir has more than one plausible location for 'use' use.\n";
		}
		push @INC, "$parldir/$dirs[0]/inc/lib";
	}
	elsif (-e '/var/log/godspeed/third_party') {
		#I seem to be on an MGA..  but the 1st tested par-SYSTEM wasn't there?
		print STDERR "It looks like this system is an MGA, but not set up to use or download any CASE packages.\n";
		print STDERR "This program needs modules in there in order to function.\n";
		print STDERR "Since that stuff is missing, this program won't be able to run.\n";
		exit(1);
	}
}

use Data::Dumper;
use Getopt::Long;
use DBI;
our $dbh;
use File::Spec;
our $cwd = File::Spec->curdir();
#use Devel::Size qw(size total_size);

our $mainVERSION = .184;
require 'timefuncs.pl';
require 'logfuncs.pl';
require 'postprocess.pl';

$SIG{INT} = \&catch_zap;  # best strategy
if ($SIG{INFO}) {
	$SIG{INFO} = \&info_zap;  #in-process printout
}

### stuff for matching specific user-specified searches
our $toRegex = '';
our $fromRegex = '';

#I will use this hash to store to and form data until all rcpts for a given MID
# are seen. At that time the data will be printed and deleted from the hash
our %tracemail;

our $SN = 'default';
our $utc_offset = '-25200';

our %statistics;
our %statistics2; #use this to track useful data I don't want to show directly

our %has_items; #use to generate recommendations

our @logfiles; #populated in process_opts

our %optctl;
#set defaults
$optctl{'nostats'} = 0; #print out stats by default
$optctl{'output'} = 0; #output file specification
$optctl{'jsdir'} = ''; #Javascript file location
$optctl{'syslog'} = 0; #indicate whether input logs are syslog formatted
$optctl{'per_domain'} = 0;
$optctl{'use_domains'} = 0;
$optctl{'per_domainlimit'} = 1;
$optctl{'per_rcpt'} = 0;
$optctl{'per_rcptlimit'} = 1;
$optctl{'ASstats'} = 1;
$optctl{'antispam'} = 1;
$optctl{'collate-ip'} = 0;
$optctl{'collate-host'} = 0;
$optctl{'collate-from'} = 0;
$optctl{'collate-from-to'} = 0;
$optctl{'collate-domain'} = 0;
$optctl{'timings'} = 0;
$optctl{'overwrite-msg-csv'} = 0; #if given the same output filename, default is to append not overwrite
$optctl{'msg-csv-cachesize-count'} = 0,
$optctl{'msg-csv-cachesize'} = 10000;
$optctl{'deletecache'} = 20;  #MID objects to collect before running the delete
$optctl{'skip-processed'} = 0;
$optctl{'AVstats'} = 1;
$optctl{'antivirus'} = 1;
$optctl{'interim'} = 0; #by default do not collate full interim AS/AV data
$optctl{'oldoutput'} = 1;
$optctl{'newoutput'} = 0;
$optctl{'etisoutput'} = 0;
$optctl{'SBRS-subjects'} = 0;
$optctl{'quiet'} = 1;
$optctl{'minutes'} = 0;
$optctl{'hourly'} = 0;
$optctl{'daily'} = 0;
$optctl{'recurse'} = 0;
$optctl{'bounces'} = 1;
$optctl{'bouncedetail'} = 0;
$optctl{'doublebounces'} = 0;
$optctl{'seat-count'} = 0;
$optctl{'all-sbrs'} = 0;
$optctl{'collate-ip-class'} = 'Class C';
$optctl{'sql'} = 0;
$optctl{'sql-cache'} = 20000;
#Default database access settings
$optctl{'dbhost'} = 'localhost';
$optctl{'database'} = 'tcamp';
$optctl{'dbuser'} = 'tcamp';
$optctl{'dbpassword'} = 'hell';
$optctl{'dbsocket'} = ''; #'/tmp/mysql.sock';
$optctl{'collate-limit'} = 100; #0 is off; this limits the amount of output for -collate* options
$optctl{'inbound'} = 0; #not yet in use - change back to 1 when implemented
$optctl{'outbound'} = 0;
$optctl{'inout'} = 0;
#to help emulate MGA rej counter multiplier
# If left to 0 this is figured out at runtime
$optctl{'HATmultiplier'} = 1;

our $avslowest = 0;
our $avslowestMID = 0;

#I don't care too much about holding onto this for statefulness:
our %sbrs_subjects;
#If these are going to be used I should write them out before program close,
# ensuring state save that way
our @sql_icidarray; #hold a buffer of ICID information yet to be flushed
our %sql_data; #easily available hash of smaller tables for relating ids

our $msg_csv_cache; #buffer for msg-csv lines

undef $optctl{'debug'};

#Populate 'Utility info' here - getopt clears this data
my $flags = $0;
foreach my $arg (@ARGV) {
	$flags .= " $arg";
}
$statistics{' Utility info'}{'flags'} = $flags;
$statistics{' Utility info'}{'Version'} = &version();

GetOptions (\%optctl,
	'help',
	'Hiddenhelp',
	'support',
	'version',
	'd=s@',
	'directory=s@',
	'file=s@',
	'f=s@',
	'recurse',
	'nostats', #flag to allow for suppression of stats output
	'output=s',
	'savestate=s', #requires skip-processed, forces a loadstate attempt
	'oldoutput!',
	'newoutput',
	'etisoutput',
	'jsdir=s', #optionally specify where JS files referred to live
	'htmloutput=s',
	'logofile=s',
	'per_rcpt!',
	'per_rcptlimit=s',
	'syslog',
	'per_domain!',
	'per_domainlimit=s',
	'fromall',
	'to=s',
	'from=s',
	'inbound',
	'outbound',
	'inout',
	't1=s',
	't2=s',
	'antispam!',
	'antivirus!',
	'interim',
	'debugmid=s',
	'debug!',
	'tracemailfrom=s',
	'tracemailto=s',
	'collate-from',
	'collate-from-to',
	'collate-domain',
	'collate-ip+',
	'collate-host',
	'collate-rejects',
	'collate-limit=s',
	'timings',
	'detail',
	'nodomains',
	'myip=s@',
	'mydomain=s@',
	'interface=s@',
	'SBRS-subjects',
	'bouncedetail',
	'bounces',
	'doublebounces',
	'quiet!',
	'msg-csv=s',
	'msg-project=s',
	'overwrite-msg-csv',
	'msg-csv-cachesize=s',
	'deletecache=s',
	'skip-processed',
	'minutes',
	'hourly+',
	'daily+',
	'seat-count',
	'all-sbrs',
	'sql',
	'sql-cache=s',
	'dbhost=s',
	'database=s',
	'dbpassword=s',
	'dbuser=s',
	'dbsocket=s',
	'HATmultiplier=s',
);
&process_opts(\%optctl);

if ($optctl{'sql'}) {
	my $socket = '';
	if ($optctl{'dbsocket'}) {
		$socket = ":mysql_socket=$optctl{'dbsocket'}";
	}
	$dbh = DBI->connect("DBI:mysql:$optctl{'database'}:$optctl{'dbhost'}$socket", $optctl{'dbuser'}, $optctl{'dbpassword'}, {RaiseError => 1, AutoCommit => 0});
	if (!$dbh) {
		die $DBI::errstr;
	}
}

#Some variables in this required file get populated in process_opts
# such as: collate-ip-class
require 'output.pl';

&disclaimer();

####

our %domains;

#This main hash contains the data I want to keep for display/ops
our %msginfo;

#this hash var will be used to track normally instantiated ICID connects
our %icid_init;

our %tmp_sqlfiles;
$tmp_sqlfiles{'connections'} = ".tmpsqldata_connections_$$";

# file handle hash to track output files - tmp and non-tmp:
our %tmpfh;

#files which exitcleanup should not delete:
our %nocleanup;

#Some arrays for datatracking - broken out from $statistics to try to flatten
# data structures, that should save some memory.
our %tmpfiles = (
		#"" => ".tmpfile__$$",
		);
if ($optctl{'output'}) { #create this one if asked
	$tmpfiles{'output'} = $optctl{'output'};
	$nocleanup{$optctl{'output'}} = 1; #flag for no deletion
}
else {
	$tmpfh{'output'} = *{STDOUT};
}

#If doing msg-csv, set up to add onto or create the specified file
if ($optctl{'msg-csv'}) {
	use CSV;
	if ($optctl{'overwrite-msg-csv'}) {
		unlink($optctl{'msg-csv'});
	}

	my $newfile = 0;
	if (!-e "$optctl{'msg-csv'}") {
		$newfile = 1;
	}
	$tmpfh{'msg-csv'} = 'msg-csv';
	no strict 'refs';
	open ($tmpfh{'msg-csv'}, ">>$optctl{'msg-csv'}") or &exitcleanup(\%nocleanup, $!, 1);
	#If the file exists already exist we don't need to print in the column header line!
	if ($newfile) {
		#update this header string from deletestuff in logfuncs.pl
		my $globref = *{$tmpfh{'msg-csv'}};
		print $globref "$statistics2{'msg-csv-header'}\n";
	}
}

#initialize the tmpfiles
while (my ($type, $name) = each %tmpfiles) {
	open ($tmpfh{$type}, "+>$name") or &exitcleanup(\%nocleanup, $!, 1);
}

our %collate_ip;

our $linetimestamp; #global to hold time of current line
our $linetimeepoch;
our %linetime; #hash relating current 'Minutes', 'Hourly', 'Daily' to the line time minute/hour/day
our $linetime_minute;
our $linetime_hour;
our $linetime_day;

if ($optctl{'savestate'}) {
	&loadstate(File::Spec->catfile($optctl{'savestate'}, '.spt-msginfo'), \%msginfo);
	&loadstate(File::Spec->catfile($optctl{'savestate'}, '.spt-icid_init'), \%icid_init);
	&loadstate(File::Spec->catfile($optctl{'savestate'}, '.spt-statistics'), \%statistics);
	&loadstate(File::Spec->catfile($optctl{'savestate'}, '.spt-statistics2'), \%statistics2);
}

our $starttime = 0;
our $filecount = 0;
our $linecount;
my $totallines = 1;
my $runtime = time();
#Iterate over the MID-strings I have left in the hashola
# this is the MAIN WORK AREA of the program.
foreach our $logfile (sort @logfiles) {
	my $logfile_dir = ''; #default to empty, as if the file is in this directory
	my $logfile_only = $logfile; #default to being the same thing
	if ($logfile =~ m/^(.*[\\\/])(.+)$/) {
		$logfile_dir = $1;
		$logfile_only = $2;
	}
	unless ($optctl{'quiet'}) {
		print STDERR "$filecount Operation progress: logfile_dir '$logfile_dir' and logfile '$logfile_only'\n";
	}

	#if indicted, check processed file list - skip listed ones
	if ($optctl{'skip-processed'}) {
		if (-e "$logfile_dir.sptw_processed") {
			if (!open(PROCESSEDLOGS, "<$logfile_dir.sptw_processed")) {
				print STDERR "Could not open processed-logs logfile for reading. ($!) Skipping processing of $logfile\n";
				next;
			}
			my @processed_logs = <PROCESSEDLOGS>;
			close(PROCESSEDLOGS);
			chomp @processed_logs;
			if (grep(/^$logfile_only$/, @processed_logs)) {
				print STDERR "$logfile appears to have been previously processed.  Skipping\n";
				next;
			}
		}
	}

	#attempt to lock each file.  If locked, skip this file
	# using a separate advisory file lock configuration because flock
	# would just wait forever until the lock is granted.
	if (-e "$logfile.sptw_locked") {
		print STDERR "Skipping $logfile because an advisory lock is in place.\n";
		next;
	}
	if (!open(LOCKFILE, ">$logfile.sptw_locked")) {
		print STDERR "Failed to create lockfile for $logfile.  ($!) Skipping\n";
		next;
	}
	#add the file onto %tmpfiles for cleanup
	$tmpfiles{'lock'} = "$logfile.sptw_locked";
	close(LOCKFILE);

	#it is the hope that the above sort would make sure that the logs are in
	# descending date order
	if (not open(LOGFILE, "<$logfile")) {
		print STDERR "failed in attempt to open $logfile: $!\n";
		next;
	}

	#Check the 1st - 3rd lines
	my $firstlines = readline(*LOGFILE); #1st line
	if ($firstlines !~ m/Info: Begin Logfile$/) {
		print STDERR "Logfile composition error 1 - skipping $logfile\n";
		next;
	}
	#get the time of the first line read
	if (!$starttime or !$statistics{' Time Frame of log entries processed'}{'begin'}) {
		$starttime = $firstlines;
		if ($optctl{'syslog'}) {
			#syslog entries do not have year.
			$starttime = substr $starttime, 0, 19, '';
			$starttime .= ' 1969';
		}
		else {
			$starttime = substr $starttime, 0, 24, '';
		}
		$statistics{' Time Frame of log entries processed'}{'begin'} = $starttime;
	}
	$firstlines = readline(*LOGFILE); #2nd line
	#Tue Oct 19 20:45:56 2004 Info: Version: 3.8.3-023 SN: 000BDBE73114-5SDYL31
	if ($firstlines !~ m/Info: Version: ((\d{1,2})\.(\d{1,2})\.\S{1,6}) SN: (\S{20})$/) {
		print STDERR "Logfile composition error 2 - skipping $logfile due to log line: $firstlines\n";
		print STDERR "\t(I expect this line to be the Info: Version: ... entry)\n";
		next;
	}
	$SN = $4;
	$statistics{' System & version -> number of log files'}{"SN $SN version $1"}++;
	$statistics2{'logfiles'}{$logfile}{'version'} = $1;
	$statistics2{'logfiles'}{$logfile}{'majorversion'} = $2;
	$statistics2{'logfiles'}{$logfile}{'minorversion'} = $3;
	$statistics2{'systems'}{$SN}{'majorversion'} = $statistics2{'logfiles'}{$logfile}{'majorversion'};
	$statistics2{'systems'}{$SN}{'minorversion'} = $statistics2{'logfiles'}{$logfile}{'minorversion'};
	$statistics2{'logfiles'}{$logfile}{'SN'} = $SN;
	$firstlines = readline(*LOGFILE); #3rd line
	#Info: Time offset from UTC: -14400 seconds
	if ($firstlines !~ m/Time offset from UTC: (\S{1,7}) seconds$/) {
		print STDERR "Logfile composition error 3 - skipping $logfile\n";
		next;
	}
	$utc_offset = $1;
	$statistics2{'logfiles'}{$logfile}{'utc_offset'} = $utc_offset;
	$statistics2{'systems'}{$SN}{'utc_offset'} = $utc_offset;
	if ($optctl{'sql'} and !$sql_data{'system'}{$SN}) {
		&system_sql($SN, {'utc_offset'=>$utc_offset}); #populate table and reference hash
	}

	#Output filehandle glob:
	my $outglobref = *{$tmpfh{'output'}};

	#reset linecount for each new file
	$linecount = 0;
	$filecount++;
	unless ($optctl{'quiet'}) {
		print STDERR "$filecount. Processing $logfile (" . (-s $logfile) . " bytes)\n";
	}
	my $proctime = time();
	while (my $fileline = readline(*LOGFILE)) {
		#skip anything w/o an ID (MID/RID/ICID/DCID) of some sort in it
		next if ((index $fileline, 'ID', 0) < 0);
		chomp($fileline);
		our $fileline_orig = $fileline;
		#strip out and keep the line timestamp
		#Used for more than just -timings
		if (!($linetimestamp = substr $fileline, 0, 24, '')) {
			#Sat May  7 06:15:22 2005
			#012345678901234567890123
			#There are not 24 characters beginning the line. (timestamp should always be there)
			#This occurs when some jackass injection puts extra carriage returns in the
			#email address, and the log wraps brokenly.
			#broken injection with linefeeds before > caused this
			#This doesn't seem to occur post 4.5.0
			$statistics{'Broken mail log entry detected'}++;
			next;
		}

		if ($optctl{'timings'} or $optctl{'t1'} or $optctl{'t2'}) {
			$linetimeepoch = &maketime($linetimestamp);
			if ($optctl{'t1'} and ($linetimeepoch < $optctl{'t1_epoch'})) {
				#Looking for matches later in time than this line.  skip
				next;
			}
			if ($optctl{'t2'} and ($linetimeepoch > $optctl{'t2_epoch'})) {
				#Looking for matches sooner in time than this line.  stop looking
				last;
			}
		}
		#setup for per-minute/hour/day collation of some stats
		#copy the timestamp
		if ($optctl{'minutes'}) {
			$linetime_minute = $linetimestamp;
			#zero the seconds - track only by whole minutes
			substr($linetime_minute, 16, 3, ':00');
			$linetime{'Minutes'} = $linetime_minute;
		}
		if ($optctl{'hourly'}) {
			$linetime_hour = $linetimestamp;
			#zero the minutes and seconds - track only by whole hours
			substr($linetime_hour, 13, 6, ':00:00');
			$linetime{'Hourly'} = $linetime_hour;
		}
		if ($optctl{'daily'}) {
			$linetime_day = $linetimestamp;
			#zero the hours, minutes and seconds - track only by whole days
			substr($linetime_day, 10, 9, ' 00:00:00');
			$linetime{'Daily'} = $linetime_day;
		}

		$linecount++;
		my $result = &process_logline($logfile, $fileline);
	} #while there are lines in the file..

	#flush the delete-mid cache after each file processed:
	if ($optctl{'debug'}) {
		print STDERR "Logfile $logfile processing close - calling deletestuff flush\n";
	}
	&deletestuff(0, 1);

	#Record this log as processed if indicated
	if ($optctl{'skip-processed'}) {
		if (!open(PROCESSEDFILES, ">>$logfile_dir.sptw_processed")) {
			print STDERR "Failed to open processed_logs file for writing: $!\n";
		}
		else {
			print PROCESSEDFILES "$logfile_only\n";
			close(PROCESSEDFILES);
		}
	}
	#Remove lockfile
	unlink ("$logfile.sptw_locked");

	#How long did it take to process that file?
	$proctime = (time() - $proctime) || 1; #set to 1 if it is 0
	$totallines += $linecount;
	unless ($optctl{'quiet'}) {
		print STDERR 'Processing time: ' . $proctime . ' seconds.  Speed: ' . int(100*($linecount / $proctime))/100 . " lines per second\n";
		print $outglobref 'Processing time: ' . $proctime . ' seconds.  Speed: ' . int(100*($linecount / $proctime))/100 . " lines per second\n";
	}

} #foreach logfile

if ($optctl{'savestate'}) {
	&savestate(File::Spec->catfile($optctl{'savestate'}, '.spt-msginfo'), \%msginfo, 'msginfo');
	&savestate(File::Spec->catfile($optctl{'savestate'}, '.spt-icid_init'), \%icid_init, 'icid_init');
	&savestate(File::Spec->catfile($optctl{'savestate'}, '.spt-statistics'), \%statistics, 'statistics');
	&savestate(File::Spec->catfile($optctl{'savestate'}, '.spt-statistics2'), \%statistics2, 'statistics2');
}

#check for full flush of sql_array in sql usage:
$optctl{'sql-cache'} = 0;
&icid_sql('0');

#How long did it take to process all these files?
$runtime = (time() - $runtime) || 1; #set to 1 if it is 0
$statistics{' Utility info'}{'Processing time'} = "$runtime seconds for $totallines lines, " . int($totallines/$runtime) . ' lines per second.';

#print "total memory size of msginfo: " . total_size(\%msginfo) . "\n";
#print "total memory size of collate_ip: " . total_size(\%collate_ip) . "\n";
#print "total memory size of statistics: " . total_size(\%statistics) . "\n";

#without at least this many lines, do_stats will probably have un-init errors
if ($totallines > 8) {
	&do_stats() unless $optctl{'nostats'};
}

if ($optctl{'sql'}) {
	$dbh->disconnect;
}

&exitcleanup(\%nocleanup);

#Catch control-c (^c)
sub catch_zap {
	my $signame = shift;
	if ($optctl{'debug'}) {
		&debugdump();
	}
	print STDERR "Somebody sent me a SIG$signame\n";
	&exitcleanup(\%nocleanup, '', 1);
}

#Catch control-t (^t)
sub info_zap {
	my $signame = shift;
	if ($optctl{'debug'}) {
		&debugdump();
	}
	print STDERR "Somebody sent me a SIG$signame\n";
	&do_stats();
	return 1;
}

sub debugdump {
	our $debug = "------- Debug info -------\n";
	if (scalar %msginfo) {
		$debug .= 'Leftover runtime msginfo hash entities: ' . (scalar keys %msginfo) . "\n"
			. 'Leftover runtime icid_init hash entities: ' . (scalar keys %icid_init) . "\n"
			. "This may indicate some number of entries are not finished yet.\n"
			. "It may also indicate log/program peculiarities as yet unhandled.\n";
	}
	print $debug;
	print 'Show Dump structure for leftover elements? [y/N] ';
	my $response = <STDIN>;
	if ($response && ($response =~ m/^y/i)) {
		print "+++++msginfo\n";
		print Dumper(%msginfo);
		print 'Hit enter to continue';
		$response = <STDIN>;
		print "+++++icid_init\n";
		print Dumper(%icid_init);
	}
	return 1;
}

sub savestate {
	my ($statefile, $dump, $name) = @_;
	if (!open(STATE, ">$statefile")) {
		print STDERR "Could not open file '$statefile' to save state: $!\n";
		return 0;
	}
	#preserve names correctly:
	$Data::Dumper::Purity = 1;
	#This ugly little bit saves a stringified version of the hash, named properly:
	my $dd = Data::Dumper->new([\%{$dump}], [("*$name")]);
	print STATE $dd->Dump;
	close(STATE);
	return 1;
}
sub loadstate {
	my ($statefile, $fill) = @_;
	return 0 unless -e $statefile;
	if (!open(STATE, "<$statefile")) {
		print STDERR "Could not open file '$statefile' to load state: $!\n";
		return 0;
	}
	local $/;
	my $state = <STATE>;
	close(STATE);
	#This next line evaluates the hash that was written out to be persistent
	eval $state;
	return 1;
}

sub do_stats {
	$statistics{' Time Frame of log entries processed'}{'end'} = $linetimestamp;

	#do postprocessing calculations prior to output
	&postprocess_sql();
	&postprocess_msg_csv();
	&postprocess_AS();
	&postprocess_AV();
	&postprocess_sizes();
	&postprocess_timings();
	&postprocess_seats();

	#If there *were* messages:
	if ($statistics{'Messages'}{'received (system/splintered/external origin)'}) {
		$statistics{'Recipients'}{'Average # per message'} = $statistics{'Recipients'}{'received'} / $statistics{'Messages'}{'received (system/splintered/external origin)'};
		$statistics{'Recipients'}{'Average # per connection (all)'} = $statistics{'Recipients'}{'received'} / $statistics{'Connections in'}{' Total Initiated'};
		$statistics{'Recipients'}{'Average # per connection (successful)'} = $statistics{'Recipients'}{'received'} / ($statistics{'Connections in'}{' Which injected messages'} || 1);

		#All this to do 'Bandwidth savings'..
		my $aspos_msgs = 0;
		my $aspos_bytes = 0;
		my $as_areas = 0;
		#These standalone top-level AS engine areas roll up into 'Anti-Spam' as of spamtowho 0.417
		# - the only reason to keep any of them (Brightmail) is for compatibility with pre-4.5 logs
		if ($statistics{'CASE'}) {
			$aspos_msgs += $statistics{'CASE'}{'AS-positive messages'} || 0;
			$aspos_bytes += ($statistics{'CASE'}{'Average message byte size (positive)'} || 0) * ($statistics{'CASE'}{'AS-positive messages'} || 0);
		}
		if ($statistics{'Brightmail'}) {
			$aspos_msgs += $statistics{'Brightmail'}{'AS-positive messages'} || 0;
			$aspos_bytes += ($statistics{'Brightmail'}{'Average message byte size (positive)'} || 0) * ($statistics{'Brightmail'}{'AS-positive messages'} || 0);
		}
		if ($statistics{'Anti-Spam'}) {
			$aspos_msgs += $statistics{'Anti-Spam'}{'AS-positive messages'} || 0;
			$aspos_bytes += ($statistics{'Anti-Spam'}{'Average message byte size (positive)'} || 0) * ($statistics{'Anti-Spam'}{'AS-positive messages'} || 0);
		}
		my $avg_spamsize = $aspos_bytes / ($aspos_msgs || 1);
		$statistics{'Bandwidth Savings'} = sprintf "%.2f", ((($statistics{'HAT Policies'}{'~Total REJECT'} || 0)
						   + ($statistics{'HAT Policies'}{'~Total REFUSE'} || 0))
							* $statistics{'Recipients'}{'Average # per connection (successful)'} #cheating?
							* $avg_spamsize
							+ (($statistics{'Recipients'}{'Rejected by LDAPACCEPT (conversationally)'} || 0) * $avg_spamsize))
							/ (1024 * 1024); #to get MB
		$statistics{'Bandwidth Savings'} = "$statistics{'Bandwidth Savings'} MB - ((Msgs refused by HAT) * (#Rcpts/connection) * (Avg spam+ size) + (Msgs rejected via LDAP) * (Avg spam+ size))";
	}

	if ($optctl{'oldoutput'}) {
		&oldoutput();
	}

	if ($optctl{'newoutput'}) {
		&newoutput();
	}

	if ($optctl{'etisoutput'}) {
		&etisoutput();
	}

	if ($optctl{'debug'}) {
		&debugdump();
	}

	#do I want to close filehandles in here when those files get read??
	# or just skip that for SIGINFO situations..
	return 1;
} #do_stats

