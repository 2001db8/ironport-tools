#Tomki tomki@ironport.com
#Feb 9 2004
# Copyright (C) 2004, IronPort Systems.  All rights reserved.

#package spamtowho;

our $funcVERSION = .243;
our $VERSION = &version();

our %requeued;

our $highest_cost = 0;
our $highest_cost_count = 0;

#Uncomment all this if I get around to completing/using size_graph in output.pl
#our $sizecollateMAX = 40 * 1024 * 1024; #40 MB
##Presize this hash
#my $bytemark = 0;
#while ($bytemark < $sizecollateMAX) {
#	$bytemark += 10240;
#	$statistics2{'Sizes'}{$bytemark}{'bytes'} = 0;
#	$statistics2{'Sizes'}{$bytemark}{'count'} = 0;
#}

#this procedure takes the name of a file to read, and a reference to the
#variable that will hold its contents.
sub getfilestring{
	my ($thisfile, $thistextref) = @_;
	my $descript = ($_[2]) ? $_[2] : 'file';
	if (! -e $thisfile) {  #The file does not exist
		return 0;
	}
	open(THISFILE, "<$thisfile")
		or die __LINE__."::$funcVERSION Unable to open $descript '$thisfile': $!\n";
	undef $/;
	$$thistextref = <THISFILE>;
	$/ = "\n";
	close THISFILE;
	return(1);
}

sub version {
	my $version = $mainVERSION + $funcVERSION;
	while (length($version) < length($funcVERSION)) {
		$version .= '0';
	}
	return $version;
}

sub process_opts {
	my $optctl = $_[0];
	if ($$optctl{'help'}) {
		&printhelp();
	}
	if ($$optctl{'Hiddenhelp'}) {
		&printhelp('allhelp');
	}
	elsif ($$optctl{'version'}) {
		print "program version $VERSION\n";
		exit(0);
	}
	elsif ($$optctl{'support'}) {
		print STDERR "This utility is UNSUPPORTED.\n";
		unlink('.spamtowho-disclaimer-agreed');
		&disclaimer();
		exit(0);
	}

	#Make a single indicator of any of these being in use
	if ($$optctl{'nostats'} and ($$optctl{'output'} or $$optctl{'htmloutput'})) {
		print STDERR "Flag '-nostats' given in conjunction with specific output flag(s). Exiting.\n";
		&exitcleanup(\%nocleanup, '', 1)
	}

	#If using htmloutput, make sure that hourly and daily stat collection is on
	if ($$optctl{'htmloutput'} and (!$$optctl{'hourly'} || !$$optctl{'daily'})) {
		$$optctl{'hourly'}++ unless $$optctl{'hourly'};
		$$optctl{'daily'}++ unless $$optctl{'daily'};
	}
	#Make a single indicator of any of these being in use
	foreach my $period ('minutes', 'hourly', 'daily') {
		if ($$optctl{$period}) {
			$$optctl{'timeperiods'}++;
			#also make a duplicate optctl entry with first letter capitalized for output purposes
			$$optctl{ucfirst($period)} = $$optctl{$period};
		}
	}

	#This is unfinished and may always be.
	if ($$optctl{'myip'}) {
		foreach my $ip (keys %{$optctl{'myip'}}) {
			if ($ip =~ m/\//o) {
				print STDERR "Sorry no CIDR support.\n";
				exit(1);
			}
			elsif ($ip !~ m/^(?:\d{1,3}\.?){1,4}$/) {
				print STDERR "I do not recognize '$ip' as being an IP address.\n";
				exit(1);
			}
		}
	}
	if ($$optctl{'mydomain'} and $$optctl{'fromall'}) {
		print STDERR "The mydomain and fromall options are mutually exclusive.\n";
		exit(1);
	}
	#Check validity of provided 'output' flag
	elsif ($$optctl{'output'}) {
		if ($$optctl{'debug'}) {
			print STDERR "An 'output' file may not be specified when running in 'debug' mode.\n";
			exit(1);
		}
		elsif (-e "$$optctl{'output'}") {
			print STDERR "Specified 'output' file already exists.\n";
			exit(1);
		}
		elsif ($$optctl{'output'} !~ m/\w/) {
			print STDERR "Option 'output' must be given with an output file specified.\n";
			exit(1);
		}
	}
	#input logfile specification processing
	if (@$optctl{'f'}) {
		foreach my $f (@{$optctl{'f'}}) {
			if (-f $f) {
				push @{$optctl{'file'}}, $f;
			}
			elsif ((-d $f) and $$optctl{'recurse'}) {
				push @{$optctl{'directory'}}, $f;
			}
			else {
				print STDERR "'$f' is not a regular file or directory, or -recurse not used.\n";
			}
		}
	}
	#input logfile directory specification processing
	if (@$optctl{'d'}) {
		foreach (@{$optctl{'d'}}) {
			push @{$optctl{'directory'}}, $_;
		}
	}
	#input logfile directory specification processing, cont'd
	if (@$optctl{'directory'}) {
		my @files;
		foreach my $dir (@{$optctl{'directory'}}) {
			if (!-d $dir) {
				print STDERR "Your 'directory' parameter entry $dir is not a directory..\n";
				exit(1);
			}
			else {
				$dir =~ s/\/$//; #strip trailing slash
				if (!$optctl{'quiet'}) {
					print STDERR "Checking directory: $dir\n";
				}
				if ($$optctl{'recurse'}) {
					#recursively find files in given dir
					&findfiles($dir, \@files);
				}
				else {
					opendir(DIR, $dir);
					@files = readdir(DIR);
					closedir(DIR);
				}
				foreach my $f (@files) {
					#Check for '.' or '..', skip them
					if (($f eq '.') or ($f eq '..')) {
						next;
					}
					if ($f !~ m/.*\.c|s|(?:current)|(?:log)$/) {
						print STDERR "Skipping $f: mail_log files provided currently must end in either .c, .s, .current, or .log.\n";
						next;
					}

					my $dir_file = File::Spec->catfile($dir, $f);
					if (-f $f) {
						push @{$optctl{'file'}}, $f;
					}
					elsif (-f "$dir_file") {
						push @{$optctl{'file'}}, $dir_file;
					}
					else {
						print STDERR "Failed to understand '$dir_file' or '$f' - skipping\n";
					}
				}
			}
		} #foreach dir
	}

	#obviously needs some files to read yah?
	if (!($$optctl{'file'} or $$optctl{'f'})) {
			print STDERR "Provide the name(s) of maillog files with -f flags.  Use -help for options.\n";
			exit(0);
	}
	#check all files found
	foreach my $file (@{$optctl{'file'}}) {
		if ((!-e "$file") or (!-r "$file") or (-l "$file") or (-d "$file")) {
			print STDERR "Pass: '$file' skipped because it wasn't there/readable/a file or was a symlink.\n";
			next;
		}
		#test general mail-log format validity
		if (open (FILE, "<$file")) {
			#Wed May  4 00:24:31 2005 Info: Begin Logfile
			#Wed May  4 00:24:31 2005 Info: Version: 3.8.4-003 SN: 000F1F6ACFA6-2Y5SQ41
			#Mon May  9 15:32:11 2005 Info: Begin Logfile
			#Mon May  9 15:32:11 2005 Info: Version: 4.0.7-011 SN: 000BDBE64917-C4GYF31
			#syslog format:
			#Thu Feb  1 08:32:59 c60 smail: Info: ICID ...
			my $line1 = <FILE>;
			my $line2 = <FILE>;
			close(FILE);
			#skip this stuff if log is in syslog format
			# - it's probably a bit different.
			if (!$optctl{'syslog'}) {
				if (!$line1 or ($line1 !~ m/Info: Begin Logfile$/mo)) {
					if (!$optctl{'quiet'}) {
						print STDERR "File $file does not conform to expected mail log format. (line1) Skipping.\n";
					}
					next;
				}
				if (!$line2 or ($line2 !~ m/ Info: Version: .+ SN: \S+$/mo)) {
					if (!$optctl{'quiet'}) {
						print STDERR "File $file does not conform to expected mail log format. (line2) Skipping.\n";
					}
					next;
				}
			}
			push @logfiles, $file;
		}
		else {
			print STDERR "Cannot open $file, skipping. $!\n";
			next;
		}
	}
	#Check for valid files left after any -t1 or -t2

	if ($$optctl{'logofile'} and (!-e $$optctl{'logofile'})) {
		print STDERR "Specified logo image file '$$optctl{'logofile'}' does not exist.\n";
		exit (0);
	}

	#does this work?
	my $domainfile = 'domains';
	if (-e $domainfile and !$$optctl{'nodomains'}) {
		if (!open(FILE, "<$domainfile")) {
			print STDERR "Cannot open $domainfile: $!\n";
		}
		else {
			$optctl{'use_domains'} = 1;
			foreach (<FILE>) {
				chomp;
				s/#.*$//; #strip comments
				next unless $_ =~ m/\w+/; #skip meaninless lines
				$$optctl{'mydomains'}{$_} = 1;
				$domains{$_}{'From'} = 0; #initialize
				$domains{$_}{'To'} = 0; #initialize
			}
			close(FILE);
		}
	}
	#does this work?
	if ($$optctl{'mydomain'}) {
		foreach my $dom (@{$optctl{'mydomain'}}) {
			#shouldn't be any whitespace in domainnames
			if ($dom =~ m/\s/) {
				print STDERR "Domain names do not have spaces: '$dom'\n";
				exit(1);
			}
			$$optctl{'mydomains'}{$dom} = 1;
		}
	}

	if ($$optctl{'to'}) {
		$toRegex = $$optctl{'to'};
		$statistics{'Searches'}{"Number of email messages to '$$optctl{'to'}'"} = 0;
		if ($$optctl{'to'} =~ m/\w@\w/) {
			#looks like a full email addr was specified, so force a perfect regex
			$toRegex = "^$$optctl{'to'}\$";
		}
	}
	if ($$optctl{'from'}) {
		$fromRegex = $$optctl{'from'};
		$statistics{'Searches'}{"Number of email messages from '$$optctl{'from'}'"} = 0;
		if ($$optctl{'from'} =~ m/\w@\w/) {
			#looks like a full email addr was specified, so force a perfect regex
			$fromRegex = "^$$optctl{'from'}\$";
		}
	}

	if ($$optctl{'t1'}) {
		if (($$optctl{'t1_epoch'} = &maketime($$optctl{'t1'}, 0)) <= 0) {
			print STDERR "t1: The format of your input '$$optctl{'t1'}' is incorrect.\nYou must provide input of the form 'Fri Jan 30 07:18:52 2004'\n";
			exit(0);
		}
	}
	if ($$optctl{'t2'}) {
		if (($$optctl{'t2_epoch'} = &maketime($$optctl{'t2'}, 0)) <= 0) {
			print STDERR "t2: The format of your input '$$optctl{'t2'}' is incorrect.\nYou must provide input of the form 'Fri Jan 30 07:18:52 2004'\n";
			exit(0);
		}
	}
	if ($$optctl{'t1'} and $$optctl{'t2'}) {
		$statistics{'Searches'}{'Time Parameters'} = "Using only entries btwn the times $$optctl{'t1'} and $$optctl{'t2'}.";
	}
	elsif ($$optctl{'t1'}) {
		$statistics{'Searches'}{'Time Parameters'} = "Using only entries after $$optctl{'t1'}.";
	}
	elsif ($$optctl{'t2'}) {
		$statistics{'Searches'}{'Time Parameters'} = "Using only entries before $$optctl{'t2'}.";
	}

	#check logfiles found to see where to begin
	if ($$optctl{'t1'} or $$optctl{'t2'}) {
		my $dateregex = '\w{3} \w{3}\s[\s\d]\d \d{2}:\d{2}:\d{2} \d{4}';
		my @keepfiles;
		my $keephash; #make sure I don't get the same file 2x
		#check t1 to see if any of the front logs can be excluded
		if ($$optctl{'t1'}) {
			foreach my $file (@logfiles) {
				if (!open(FILE, "<$file")) {
					die "Cannot open file $file for reading.\n";
				}
				my $lastdate;
				#seek back until an identifiable line is found
				for (my $i = -40 ; $i > -750; $i--) {
					seek FILE, $i, 2; #end of file, back by $i
					my $l = <FILE>;
					if ($l =~ m/^($dateregex) /) {
						$lastdate = $1;
						last;
					}
				}
				close (FILE);
				if (&maketime($lastdate, 0) > &maketime($$optctl{'t1'}, 0)) {
					#last line was after t1, keep this file
					push @keepfiles, $file;
					$keephash{$file} = 1;
				}
			}
		}
		#check t2 to see if any of the last logs can be excluded
		if ($$optctl{'t2'}) {
			foreach my $file (@logfiles) {
				my $thisdate;
				if (!open(FILE, "<$file")) {
					die "Cannot open file $file for reading.\n";
				}
				my $l = <FILE>; #get a line
				close (FILE);
				if ($l =~ m/^($dateregex) /) {
					$thisdate = $1;
				}
				if (!$keephash{$file} and (&maketime($thisdate, 0) < &maketime($$optctl{'t2'}, 0))) {
					#last line was after t1, keep this file
					push @keepfiles, $file;
				}
			}
		}
		@logfiles = @keepfiles;
	}
	if (!scalar(@logfiles)) {
		print STDERR "No valid files to operate upon.\n";
		exit(0);
	}
	else {
		unless ($$optctl{'quiet'}) {
			print STDERR 'Found ' . scalar(@logfiles) . " files to operate on.\n";
		}
	}

	#Set some internally used optctl settings
	if ($$optctl{'antispam'}) {
		$$optctl{'ASstats'} = 1;
	}
	if ($$optctl{'antivirus'}) {
		$$optctl{'AVstats'} = 1;
	}
	if ($$optctl{'tracemailto'} or $$optctl{'tracemailfrom'} or $$optctl{'tracemailip'}) {
		$$optctl{'tracemail'} = 1;
	}

	#if doing msg-project, turn on msg-csv with that output name
	if ($optctl{'msg-project'}) {
		#Turn on msg-csv w/same filename
		$optctl{'msg-csv'} = $optctl{'msg-project'};
	}
	#Populate the header string for these uses:
	if ($optctl{'msg-csv'} or $optctl{'tracemail'}) {
		$statistics2{'msg-csv-header'} = 'Time-In,Time-done,SN-MID,IP,SenderGroup,Policy,SBRS,Envelope From,Message size (bytes),Message-ID,AV-Pos,AS-Pos,Recipients and resolution,Subject';
		#with msg-project we keep abbreviated and different headers instead:
		if ($optctl{'msg-project'}) {
			$statistics2{'msg-csv-header'} = 'Time-In,IP,SBRS,Envelope From,Message size (bytes),AV-Pos,AS-Pos,From Domain,Sender,Resent-From,Resent-Sender,DK-sig,DKIM';
		}
		#Populate an array with these header values
		foreach my $key (split /,/, $statistics2{'msg-csv-header'}) {
			push @{$statistics2{'msg-csv-header_array'}}, $key;
		}
	}

	if ($$optctl{'collate-ip'}) {
		if ($$optctl{'collate-ip'} == 1) {
			$$optctl{'collate-ip-class'} = 'Class C';
		}
		elsif ($$optctl{'collate-ip'} == 2) {
			$$optctl{'collate-ip-class'} = 'IP';
		}
		else {
			print STDERR "Unrecognized value '$$optctl{'collate-ip'}' given for collate-ip\n";
			exit(1);
		}
	}

	if ($$optctl{'jsdir'} and ($$optctl{'jsdir'} !~ m/\/$/)) {
		$$optctl{'jsdir'} = "$$optctl{'jsdir'}/";
	}

	if ($$optctl{'savestate'} and ((!-e $$optctl{'savestate'}) or (!-d $$optctl{'savestate'}))) {
		print STDERR "The argument for -savestate must be a directory.\n";
		exit(1);
	}

#	if ($optctl{'outbound'} and $optctl{'inbound'}) {
#		$statistics{' Notes'}{"All statistics have been calculated based upon both 'inbound' and 'outbound' connections."} = ' ';
#	}
#	elsif ($optctl{'inbound'}) { #most common case
#		$statistics{' Notes'}{"All statistics have been calculated based upon only 'inbound' connections."} = ' ';
#	}
#	else { #only case left is 'outbound' only
#		$statistics{' Notes'}{"All statistics have been calculated based upon only 'outbound' connections."} = ' ';
#	}
#	#sanity check against dumbness:
#	if (!$optctl{'outbound'} and !$optctl{'inbound'}) {
#		print STDERR "One of inbound or outbound must be allowed for processing...\n";
#		exit(1);
#	}

sub printhelp {
	my $hiddenhelp = '';
	print "This utility provides for some parsing of Ironport MGA mail logs, and limited data compilation.\nOptions:\n";
	if ($_[0]) {
		print <<'HIDDEN';
	debug         Print some debug info
	debugmid      Print specific debug info on the given MID
	oldoutput     Show output the old, messier way
	newoutput     Show output the new way
	timings       Show timing info (slows processing tremendously)
HIDDEN
	}
	print <<"END";
	directory     Indicate a directory to check for mail*.s files.
	              All found will be processed.
	file          Indicate files for input.  May be given multiple times
	f             Synonym for file
	output        Specify an output file
	jsdir         Specify an optional other directory where .js files live
	htmloutput    Specify an output file for HTML-version output
	logofile      Specify an image file for use in the HTML output
	to            Perform matching and printing of output for matches
	                in 'rcpt to' addresses
	from          Perform matching and printing of output for matches
	                in 'mail from' addresses
	antivirus     Turn on compiling/printing of AV stats
	antispam      Turn on compiling/printing of AS stats
	per_rcpt      Flag for printing out per-rcpt stats
	per_domain    Flag for printing out per-domain stats
	per_domainlimit and
	per_rcptlimit  These two options default to 10.  They limit the
	              results returned by the relevant data collector to
	              entries with at least the specified number of hits.
	fromall       Modifier for per_ information.  Collate data on email sent
                        even if the envelope-from is empty. (usually a bounce)
	t1            Indicate earliest time to begin looking at messages
	t2            Indicate latest time to begin looking at messages
	mydomain      Specify domains which belong to your organisation, to
	              limit stat gathering.
		      These entries serve the same purpose as ones in the file
		      'domains'
	nodomains     Ignore the domains file if present
	tracemailip
	tracemailto
	tracemailfrom Given a string, match against connecting IP, To, or From
	              addresses, printing results to STDOUT during processing
	collate-from  Collate stats on sending addresses
	collate-from-to Collate stats on sending addresses relative to each recipient
	collate-domain  Collate stats on sending domains
	collate-ip    Collate stats on connecting IPs
	              By default this lumps IPs in Class-C blocks.
		      Issue the -collate-ip 2 times to get individual IPs
	collate-rejects  Collate a list of all addresses rejected by
	              LDAPACCEPT and/or RAT
	collate-limit Limits the data printed out by collate-* options to the
	              specified number of entries.  Default is 100
	bounces       Collate specifie bounce errors that appear in the log
	doublebounces Collate specifie double-bounce errors that appear in the
	              log
	bouncedetail  Collate a list of recipients which bounced, how many times
	SBRS-subjects For all AS-pos messages, print the incoming message
	              Subjects and SBRS scores
	all-sbrs      Include decimal ranges in SBRS output
	interface     Specify an interface to limit data collection to
	msg-csv       Filename to output CSV data to, about each message injected
	overwrite-msg-csv If specified the msg-csv file specified will be overwritten
	skip-processed Maintain a log of which files were processed
	savestate     Directory in which state-save files will be written and
	              updated.  Implies to perform the load/save actions
	minutes       Output to tab-delimited file per-minute data
	hourly        Output to tab-delimited file per-hour data
	daily         Output to tab-delimited file per-day data
	interim       Show full details of interim AV and AS processing
	recurse       Follow directories to find all mail_log files to read
	HATmultiplier Default of 1 can be modified to emulate ESA GUI output
	seat-count    Help in determining # of users of some features
	support       Print supported status of this utility
	help          To obtain this printout
	version       Print current version of this utility
	quiet         Suppresses most non-report output (default: on)
$hiddenhelp
Examples:
 Basic:
  $0 -f mail.current
 Read all entries since ...
  $0 -f mail.current -t1 "Fri Jan 28 00:00:00 2004"
 Read all entries until ...
  $0 -f mail.current -t2 "Fri Feb  8 00:00:00 2004"
 Get some specific detail on messages from addresses matching 'yahoo'
  $0 -f mail.current -f mail.current.01 -tracemailfrom yahoo
 Collate information about sending IPs and rcving domains, generate a file
 with hourly statistics, written to a file, verbose
  $0 -recurse -d allmyLogs -collate-ip -per_domain -hourly -output output.txt -noquiet
 etc...
  $0 -recurse -d allmyLogs -d ../otherlogs/ -collate-domain -collate-ip -hourly -output=output.txt -htmloutput=output.html
END
#myip          Specify IP addresses which belong to your organisation
		exit(0);
}
} #process_opts


#Sort-use function.
#sorts strings prepended numerically by that number first, then non-numerically
# prepended strings next, lexically.
sub sort_bynumfirst {
	if (($a =~ m/^-?\d+/) and ($b =~ m/^-?\d+/)) { #both numerical (inc. neg.)
		#this is unanchored at the right so that items such as
		#'15 Rcpts' gets sorted by #
		$a =~ m/^(-?\d+(\.\d+)?)/;
		my $a_num = $1;
		$b =~ m/^(-?\d+(\.\d+)?)/;
		my $b_num = $1;
		return $a_num <=> $b_num;
	}
	elsif ($a =~ m/^(\D+)\d+/) {
		my $foo = quotemeta $1;
		if ($b =~ m/^$foo\d+/) {
			#identical text followed by numbers..  sort by the numbers
			$a =~ m/^\D+?(-?\d+(\.\d+)?)/;
			my $a_num = $1;
			$b =~ m/^\D+?(-?\d+(\.\d+)?)/;
			my $b_num = $1;
			return $a_num <=> $b_num;
		}
	}
	#just text comparison
	return $a cmp $b;
} #sort_bynumfirst

#sort_bytesizes is used to sort things of this sort:
#0B-5KB
#5KB-10KB
#10KB-15KB
#1MB-20MB
sub sort_bytesizes {
	if (($a =~ m/^(?: < )?\d+\s*\w+/) and ($b =~ m/^(?: < )?\d+\s*\w+/)) {
		$a =~ m/^(?: < )?(\d+)\s*(\w+)/;
		my $a_num = $1;
		my $a_char = $2;
		$b =~ m/^(?: < )?(\d+)\s*(\w+)/;
		my $b_num = $1;
		my $b_char = $2;
		if ($a_char ne $b_char) {
			if ($a_char eq 'B') {
				#If a is Bytes, it's the smaller
				return -1;
			}
			elsif ($b_char eq 'B') {
				#If b is Bytes, it's the smaller
				return 1;
			}
			elsif ($a_char eq 'KB') {
				#If neither is Bytes and a is KB, a is smaller
				return -1;
			}
			elsif ($b_char eq 'KB') {
				#If neither is Bytes and b is KB, b is smaller
				return 1;
			}
			#No need to put MB here..  there will never be GB afaik,
			#so if they're ne as per the test, the previous tests
			#will suffice.
			#Just to check for insanity:
			else {
				print STDERR "insanity in sort_bytesizes sort of $a vs $b\n";
				return 0;
			}
		}
		else {
			return $a_num <=> $b_num;
		}
	}
	#normal comparison
	return $a cmp $b;
} #end sort_bytesizes

#This is the main processing function of the program; it processes each
# logfile's lines as they are passed in.
# It makes extensive use of other subprocedures.
# Input:
#     The name of the logfile currently being processed
#     The fileline to be processed
#     Line number in the current file of the logline currently being processed.
sub process_logline {
	our ($logfile, $fileline) = @_;
	#Info: ICID 52525189 ACCEPT SG None match  SBRS 3.7
	#Note: I did test tokenizing vs use of 'index' throughout:
	# our @tokens = split(' ', $fileline, 15);
	# if ($tokens[0] eq 'Info:') {
	# ->it just seems to not be nearly as fast.  'split' too expensive?

	#Check for a flag indicating that the log being read is from a syslog logged file
	#Which starts like:
	#Feb  1 08:32:59 c60 smail: Info: ICID ...
	if ($optctl{'syslog'}) {
		substr $fileline, 0, (index $fileline, ':')+1, ''; #strip up to & including :
		#So now what's left should conform to the non-syslog type entry
	}

	#Remove the space btwn further info
	substr $fileline, 0, 1, '';

	if ((index $fileline, 'Info: ') == 0) {

		substr $fileline, 0, 6, ''; #strip off 'Info: '
		undef $SN_MID;

		#Fri Jan 30 08:16:18 2004 Info: ICID 10304570 TLS success
		#4.5.0 has:
		#Thu Oct 27 00:00:01 2005 Info: DCID 33 TLS success CN: <eq-c601.ironport.com>
		#Info: ICID 623143 TLS success protocol TLSv1/SSLv3 cipher DHE-RSA-AES256-SHA
		#Fri Jan 30 08:16:20 2004 Info: ICID 10304580 TLS failed
		#Mon Mar  8 19:37:40 2004 Info: ICID 8 TLS was required but remote host did not initiate it
		#Fri Jan 30 08:16:20 2004 Info: ICID 10304580 lost
		#Mon Mar  8 19:37:40 2004 Info: ICID 9033 Receiving Failed: Message loop
		#Info: ICID 440090 Receiving Failed: Message size exceeds limit
		#Info: ICID 33256263 Receiving Failed: Connection limit exceeded
		#Mon Mar  8 19:37:40 2004 Info: ICID 11723972 Injection Failed: Message loop
		#New for 3.7.3:
		#Tue Apr 27 12:04:18 2004 Info: ICID 9461571 SBRS None
		#New for 3.8.1 HP1:
		#Info: ICID 282194765 REJECT SG BLACKLIST match sbrs[-10.0:-2.0] SBRS -9.9
		#Info: ICID 0 TCPREFUSE SG BLACKLIST match sbrs[-10.0:-0.5] SBRS -9.9
		#can have this since 3.8.2:
		#Tue Feb 22 19:26:25 2005 Info: ICID 3 ACCEPT SG None match  SBRS rfc1918
		#4.5, address parser output: (bug 13536)
		# ICID ~2~ Invalid sender address: ~1~ ~3~
		#4.5, Sender Verification output:
		# ICID ~1~ Address: ~2~ sender allowed, envelope sender matched domain exception
		#Info: ICID 493771866 MID 340448731 Invalid recipient address:  'RCPT TO:<>'
		if ((index $fileline, 'ICID ') == 0) {
			return &info_ICID($fileline);
		} #end of Info: ICID section

		##Fri Jan 29 08:12:00 2004 Info: MID 1 ..
		elsif ((index $fileline, 'MID ') == 0) {
			return &info_MID($fileline);
		} #end of Info: MID section

		#New in 4.6.0 is the port:
		#Mon Jan 23 16:55:42 2006 Info: New SMTP DCID 1 interface 172.19.0.21 address 72.14.205.27 port 25
		#Fri Jan 30 07:18:52 2004 Info: New SMTP DCID 1162933 interface 166.77.6.10 address 66.180.244.17
		#Fri Jan 30 07:18:52 2004 Info: New SMTP ICID 10292815 interface private address 81.137.223.69
		#3.8:
		#Fri May 14 20:48:51 2004 Info: New SMTP ICID 4 interface Management (172.19.0.81) address 10.1.1.140 reverse dns host unknown verified no
		#Wed Jun  2 14:58:14 2004 Info: New SMTP ICID 244315254 interface ausc60ps305.us.ex.com (143.166.148.150) address 217.238.244.89 reverse dns host pd9eef459.dip.t-dialin.net verified yes
		#Wed Jun  2 15:01:17 2004 Info: New SMTP ICID 244323261 interface ausc60ps305.us.ex.com (143.166.148.150) address 220.93.58.10 reverse dns host unknown verified no
		#Info: New SMTP ICID 27389415 interface Marsh (205.156.189.20) address 205.234.144.192 reverse dns host  server.masterplace.com.br verified no
		elsif ((index $fileline, 'New SMTP ') == 0) {
			return &info_New_SMTP($fileline);
		} #end of Info: New SMTP section

		#Tue Jan  6 15:07:12 2004 Info: Start MID 4 ICID 4
		#Wed Jun  2 14:57:32 2004 Info: Start MID 179632420 ICID 244312960
		elsif ((index $fileline, 'Start MID ') == 0) {
			return &info_Start_MID($fileline);
		} #end of Info: Start MID section

		#Wed Feb  4 14:02:12 2004 Info: Message done/aborted/finished
		#Wed Feb  4 14:02:12 2004 Info: Message done DCID 3312 MID 4806 to [0]
		elsif ((index $fileline, 'Message ') == 0) {
			return &info_Message($fileline);
		} #end of Info: Message section

		#DCID 12 TLS success CN: <Messaging Gateway Appliance Demo Cert>
		#DCID 58744 TLS success CN=mail.internetsellout.com
		#DCID 239490 TLS success protocol TLSv1 cipher RC4-SHA CN=c602.soma.ironport.com
		#DCID 80167 TLS failed: STARTTLS unexpected response
		#DCID 8 IP 204.15.82.140 TLS was required but could not be successfully negotiated
		#Wed Jan  7 11:15:47 2004 Info: DCID 4 close
		elsif ((index $fileline, 'DCID ') == 0) {
			substr $fileline, 0, 5, ''; #strip off 'DCID '
			my $DCID = substr $fileline, 0, (index $fileline, ' '), '';
			substr $fileline, 0, 1, ''; #strip ' '
			if ($fileline eq 'close') {
			}
			elsif ((index $fileline, 'TLS ') == 0) {
				substr $fileline, 0, 3, ''; #strip 'TLS '
				if ($fileline =~ m/^(.+) CN=(.+)$/) {
					$fileline =~ s/[<>]//g; #strip angle brackets for HTML safety
					my $remoteCN = $2;
					$statistics{'Connections out (delivery)'}{"TLS $1"}++;
					$statistics{'TLS out'}{sprintf "%32s\t%-60s", $remoteCN, $fileline}++;
				}
				else {
					$statistics{'Connections out (delivery)'}{"TLS $fileline"}++;
					$statistics{'TLS out'}{$fileline}++;
				}
			}
			#bug 25546 filed to address the inconsistent TLS log entry format:
			elsif ((index $fileline, 'IP ') == 0) {
				substr $fileline, 0, 3, ''; #strip 'IP '
				substr $fileline, 0, (index $fileline, ' ')+1, ''; #strip the IP and a space
				$statistics{'Connections out (delivery)'}{"$fileline"}++; #use what's left
			}
			else {
				return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
			}
			return 1;
		}
		#Sat Feb 14 01:16:30 2004 Info: Delivery start DCID 4901127 MID 10288263 to [0]
		elsif ((index $fileline, 'Delivery start DCID ') == 0) {
			$statistics{'Messages'}{'Deliveries Begun Outbound'}++;
			return 1;
		}

		#4.6.0 Beta1, EUQ messages:
		#Thu Dec  8 15:52:11 2005 Info: EUQ: Tagging MID 4433 for quarantine
		#As of 5.0.0:
		#Thu Dec  8 15:52:11 2005 Info: ISQ: Tagging MID 4433 for quarantine
		elsif (((index $fileline, 'EUQ: ') == 0) or ((index $fileline, 'ISQ: ') == 0)) {
			substr $fileline, 0, 5, ''; #strip off 'EUQ: '
			if ((index $fileline, 'Tagging ') == 0) {
				#Determined that this message should go to quarantine,
				# if something else doesn't delete it along the way
				return 1;
			}
			#Thu Dec  8 15:52:15 2005 Info: EUQ: Quarantined MID 4433
			elsif ((index $fileline, 'Quarantined ') == 0) {
				#The message has been quarantined
				#TKI Potential problem here where I may end up having to store out these accumulated
				# message objects as messages can stay in the quarantine for a long time and I'd
				#end up building up stuff in memory until (if ever) the message is seen/logged as coming out.
				return 1;
			}
			#Thu Dec  8 20:16:32 2005 Info: EUQ: Reinjected MID 4433 as MID 4449
			elsif ((index $fileline, 'Reinjected MID ') == 0) {
				#Message came back in from EUQ
				$statistics{'Messages'}{'Reinjected from IronPort Spam Quarantine'}++;
				#substr $fileline, 0, 15, ''; #strip off 'Reinjected MID '
				#strip out the MID and put it into $thismid;
				#This next line takes everything from the beginning of the string up to the first ' '
				#our $thismid = int(substr $fileline, 0, int(index $fileline, ' ', 0), '');
				#our $SN_MID = $SN.'-'.$thismid;
				#substr $fileline, 0, 8, ''; #strip off ' as MID '
				#my $newmid = int($fileline); #only the MID left now

				#Tki - do I want to have had this message stored out, resurrect now?
				#For now I'm going to skip over these
				return 0;
				#return &process_rewrite($SN, $SN_MID, $thismid, $newmid, 'EUQ Reinjection');
				#                  ($SN, $SN_MID, $oldmid, $newmid, $rewrite_agent) = @_;
			}
			else {
				#return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
				$statistics{'uninteresting? log entries'}{'EUQ loglines'}++;
			}

			return 1;
		} #end of Info: EUQ: section
		#Info: RPC Delivery start RCID 4051 MID 14077 to local IronPort Spam Quarantine
		#Info: RPC Message done RCID 4051 MID 14077
		#all, Beta2:
		#'RPC Delivery start RCID $rcid MID $mid to local IronPort Spam Quarantine',
		#'RPC Message done RCID $rcid MID $mid',
		#'RPC Message rejected RCID $rcid MID $mid',
		#'RPC connection RCID $rcid to $address sleeping for $secs seconds',
		#'RPC connection RCID $rcid to $address reset sleep time',
		#'RPC connection to $address failed RCID $rcid MID $mid ($message)',
		#'RPC connection RCID $rcid killed',
		elsif ((index $fileline, 'RPC') == 0) {
#Tki - more to do here..  could use Storable to write out the records?
			substr $fileline, 0, 4, ''; #strip off 'RPC '
			if ((index $fileline, 'Delivery start RCID ') == 0) {
				#spurious?
			}
			elsif ((index $fileline, 'Message done RCID ') == 0) {
				$fileline =~ m/MID (\d+)/;
				our $thismid = $1;
				our $SN_MID = $SN.'-'.$thismid;

				if (!$msginfo{$SN_MID}) {
					return 0;
				}
				foreach (keys %{$msginfo{$SN_MID}{'rcpts'}}) {
					my $rid = int($_);
					next if $msginfo{$SN_MID}{'rcpts'}{$rid}{'resolution'};
					$msginfo{$SN_MID}{'rcpts'}{$rid}{'resolution'} = 'sent to IronPort Spam Quarantine';
					$msginfo{$SN_MID}{'finalized_rcpts'}++;
					$statistics{'Recipients'}{'Sent to IronPort Spam Quarantine'}++;
				}
				$statistics{'Messages'}{'Sent to IronPort Spam Quarantine'}++;
			}
			#else - Ignore the other RPC messages?
			#RPC Message rejected RCID $rcid MID $mid
			elsif ((index $fileline, 'Message rejected RCID') == 0) {
				$statistics{'Messages'}{'Rejected for injection to IronPort Spam Quarantine'}++;
			}
			else {
				$statistics{'uninteresting? log entries'}{'RPC loglines'}++;
			}
			return 1;
		}
		#4.6.0 Beta1, EUQ messages:
		#Thu Dec  8 15:52:15 2005 Info: Start delivery of MID 4433 over RPC connection 0
		#Thu Dec  8 15:52:15 2005 Info: Delivery of MID 4433 over RPC completed on connection 0
		elsif ((index $fileline, ' over RPC ') > 0) {
			#nothing to do/record, yah?
			return 1;
		}
		#Sat Jan 10 09:45:42 2004 Info: Bounced: DCID: 1911 Message 3993 to 0 - 5.1.0 - Unknown address error ('554', ['Too long line.']) []
		#3.8.0:
		#Fri May 14 20:49:30 2004 Info: Bounced: DCID 0 MID 8 to RID 0 - 5.1.2 - Bad destination host ('000', ['DNS Hard Error looking up BMQ-WIN.RUN (MX):  NXDomain'])
		# Info: Bounced: DCID 947091 MID 12217124 to RID 0 - 5.1.0 - Unknown address error ('501', ['5.5.4 Invalid Address'])
		elsif ((index $fileline, 'Bounced: DCID') == 0) {
			substr $fileline, 0, 13, ''; #strip off 'Bounced: DCID'
			$fileline =~ m/^(?::)? \d+ (?:Message|MID) (\d+) to (?:RID )?(\d+) - (.+?) (\(.+?\))$/;
			my $mid = $1;
			my $rid = $2;
			my $extradata = $3;
			my $bouncedetail = $4;
			my $SN_MID = $SN.'-'.$mid;
			return 0 unless $msginfo{$SN_MID};

			$msginfo{$SN_MID}{'rcpts'}{int($rid)}{'resolution'} = "bounced: $bouncedetail";
			$msginfo{$SN_MID}{'finalized_rcpts'}++;

			if (!$extradata) {
				print STDERR "$fileline_orig\n";
				print STDERR "$fileline\n";
				print STDERR __LINE__."::$funcVERSION: caught \n1 $mid\n2 $rid\n\t..but not 3rd parameter as expected\n";
			}

			#don't count in certain ways if this message itself is a generated bounce.
			if (!$msginfo{$SN_MID}{'notes'} or ($msginfo{$SN_MID}{'notes'} !~ m/generated bounce/)) {
				if ($optctl{'bounces'}) {
					$statistics{'Bounces'}{$extradata}++;
				}
				if ($optctl{'bouncedetail'}) {
					$statistics{'Bounced Recipient counts'}{$msginfo{$SN_MID}{'rcpts'}{int($rid)}{'rcpt_name'}}++;
				}

				$statistics{'Bounces'}{'hard'}++;
			}
			#No need to deletestuff here, 'Message finished' line should handle it..
			#&deletestuff($SN_MID);
			return 1;
		} #end of Bounced section
		#Fri Feb 27 09:26:25 2004 Info: Double bounce: Message 8963393 to 0 - 5.1.1 - Bad destination email address
		#Double bounce: MID 12222130 to 0 - 5.1.0 - Unknown address error 501-'5.5.4 Invalid Address'
		elsif ((index $fileline, 'Double bounce: ') == 0) {
			$fileline =~ m/(?:Message|MID) (\d+) to (?:RID )?(\d+) - (.+? - .+)(?:-|')?/;
			my $mid = $1;
			my $SN_MID = $SN.'-'.$mid;
			return 0 unless $msginfo{$SN_MID};
			my $rid = $2;
			if (!$3) {
				print STDERR "$fileline_orig\n";
				print STDERR "$fileline\n";
				print STDERR __LINE__."::$funcVERSION: caught \n$mid\n$rid\n\tbut not 3rd\n";
				return 0;
			}
			my $reason = $3;

			$msginfo{$SN_MID}{'rcpts'}{int($rid)}{'resolution'} .= ' DOUBLEBOUNCE';
			$msginfo{$SN_MID}{'finalized_rcpts'}++;

			#set this up for data collection in deletestuff:
			#$msginfo{$SN_MID}{'rcpts'}{$rid}{'doublebounce'} = 1;
			#$msginfo{$SN_MID}{'doublebounces'}{$reason}++;
			if ($optctl{'doublebounces'}) {
				$statistics{'Double bounce'}{$reason}++;
			}
			$statistics{'Bounces'}{'double'}++;
			#No need to deletestuff here, 'Message finished' line should handle it..
			#&deletestuff($SN_MID);
			return 1;
		}
		#Info: Connection Error: connection timed out DCID: 2804 IP: 69.59.158.5 details: timeout interface: 10.20.1.49
		elsif ((index $fileline, 'Connection Error: ') == 0) {
			substr $fileline, 0, 18, ''; #strip off 'Connection Error: '
			if ($fileline =~ m/^(.+?) DCID:? /) {
				$statistics{'Connections out (delivery)'}{"Error: $1"}++;
			}
			#Info: Connection Error: DCID: 263 IP: 128.242.110.90 details: EOF interface: 128.197.12.246 reason: network error
			elsif ($fileline =~ m/^DCID:? .+reason: (.+)$/) {
				$statistics{'Connections out (delivery)'}{"Error: $1"}++;
			}
			else {
				return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
			}
			return 1;
		}
		#Info: Delayed: DCID: 4370 Message 10800 to 0 - 4.4.0 - Other network problem ('000', ['[Errno 54] Connection reset by peer']) []
		elsif ((index $fileline, 'Delayed: DCID') == 0) {
			$statistics{'Connections out (delivery)'}{'Delayed'}++;
			return 1;
		}
		#Status log line
		#Will be something similar to this, with more or fewer counters per version:
		#Thu Jan 25 18:57:01 2007 Info: Status: CPULd 3 DskIO 0 RAMUtil 1 QKUsd 141 QKFre 34602867 CrtMID 414695 CrtICID 644374 CrtDCID 76943 InjMsg 243087 InjRcp 264562 GenBncRcp 7185 RejRcp 108438 DrpMsg 9355 SftBncEvnt 2273 CmpRcp 265790 HrdBncRcp 12199 DnsHrdBnc 3596 5XXHrdBnc 8531 FltrHrdBnc 5 ExpHrdBnc 67 OtrHrdBnc 0 DlvRcp 253369 DelRcp 222 GlbUnsbHt 0 ActvRcp 5 UnatmptRcp 4 AtmptRcp 1 CrtCncIn 0 CrtCncOut 0 DnsReq 3133538 NetReq 3209768 CchHit 20318803 CchMis 8519477 CchEct 60069 CchExp 302309 CPUTTm 260 CPUETm 169984 MaxIO 350 RAMUsd 32542088 MMLen 7 DstInMem 38 ResCon 0 WorkQ 0 QuarMsgs 2 QuarQKUsd 121 LogUsd 8 AVLd 0 BMLd 1 CASELd 0 TotalLd 4 LogAvail 66G EuQ 0 EuqRls 0
		#This log entry goes away in 5.5.0, bug 33107
		elsif ((index $fileline, 'Status: ') == 0) {
			if ($optctl{'timeperiods'}) {
				&collate_timeperiods('Status', $fileline);
			}
			return 1;
		}

		#These are examples of LDAP queries that occur in the workqueue
		#Mon Mar 22 08:49:37 2004 Info: LDAP: unable to process, MID 4069647 requeued
		#Info: LDAP: unable to process, MID 611628 requeued
		#Info: LDAP: Bounce query HutchLDAP.ldapaccept MID 718417 RID 2 address 8k00000l037@hutchcity.com
		#Info: LDAP: Drop query HutchLDAP.ldapaccept MID 349817 RID 1 address dlzb@hutchcity.com
		#Info: LDAP: Reroute query BBLDAP.routing MID 349826 RID 0 address joanne@tashun.com to [('joanne@tashun.com', 'smtp07b.on-nets.com')]
		elsif ((index $fileline, 'LDAP: ') == 0) {
			substr $fileline, 0, 6, ''; #strip off 'LDAP: '
			my $thismid = '';
			my $rid = '';
			my $SN_MID = '';
			#Up to (including?) 4.0.8 a lot of LDAP logged lines did not have MID relevance (bug 13576)
			if ((index $fileline, 'MID ') == 0) {
				substr $fileline, 0, 4, ''; #remove 'MID '
				$thismid = int(substr $fileline, 0, (index $fileline, ' '), '');
				$SN_MID = "$SN-$thismid";
			}
			elsif ($fileline =~ m/MID (\d+)/) {
				$thismid = $1;
				$SN_MID = "$SN-$thismid";
				return 0 unless $msginfo{$SN_MID};
				if ($fileline =~ m/RID (\d+)/) {
					$rid = $1;
				}
			}

			#LDAP_ACCEPTED: 'LDAP: Accepted query ~1~ address ~2~',
			if ((index $fileline, 'Accepted query ') == 0) {
				$statistics{'LDAP'}{'Accepted'}++;
			}
			elsif ((index $fileline, 'Bounce query ') == 0) {
				$msginfo{$SN_MID}{'rcpts'}{$rid}{'resolution'} = 'bounced by LDAPACCEPT';
				$statistics{'LDAP'}{'Rcpts bounced'}++;
				$msginfo{$SN_MID}{'finalized_rcpts'}++;
				$statistics{'Recipients'}{'Bounced by LDAPACCEPT (workqueue)'}++;
				if ($optctl{'collate-rejects'}) {
					$fileline =~ m/address (\S+)$/;
					$statistics{'Recipients rejected by LDAPACCEPT'}{$1}++;
				}
			}
			elsif ((index $fileline, 'Drop query ') == 0) {
				$msginfo{$SN_MID}{'rcpts'}{$rid}{'resolution'} = 'dropped by LDAPACCEPT';
				$statistics{'LDAP'}{'Rcpts dropped'}++;
				$msginfo{$SN_MID}{'finalized_rcpts'}++;
				$statistics{'Recipients'}{'Dropped by LDAPACCEPT (workqueue)'}++;
				if ($optctl{'collate-rejects'}) {
					$fileline =~ m/address (\S+)$/;
					$statistics{'Recipients rejected by LDAPACCEPT'}{$1}++;
				}
			}
			elsif ((index $fileline, 'Reroute query ') == 0) {
				$statistics{'LDAP'}{'Rcpts rerouted'}++;
			}
			#LDAP_MAILHOST: 'LDAP: Mailhost query ~1~ address ~2~ to ~3~',
			elsif ((index $fileline, 'Mailhost query ') == 0) {
				$statistics{'LDAP'}{'Mailhost query'}++;
			}
			#LDAP_MASQUERADE: 'LDAP: Masquerade query ~1~ address ~2~ to ~3~',
			elsif ((index $fileline, 'Masquerade query ') == 0) {
				$statistics{'LDAP'}{'Masquerade query'}++;
			}
			#LDAP_GROUP: 'LDAP: Group query ~1~ address ~2~',
			elsif ((index $fileline, 'Group query ') == 0) {
				$statistics{'LDAP'}{'Group query'}++;
			}
			elsif ((index $fileline, 'unable to process, ') == 0) {
				$statistics{'LDAP'}{'Processing errors'}++;
			}
			#LDAP_NOMATCH: 'LDAP: No Match query ~1~ address ~2~',
			elsif ((index $fileline, 'No Match query ') == 0) {
				$statistics{'LDAP'}{'No Match'}++;
			}
			#LDAP_MESSAGE_RCPTS_BOUNCED:  'LDAP: unable to process, MID ~1~ bouncing recipients',
			elsif ((index $fileline, 'unable to process, MID ') == 0) {
				$statistics{'LDAP'}{'unable to process, bounced all rcpts'}++;
			}
			elsif ((index $fileline, 'unable to process, MID ') == 0) {
				$fileline =~ m/unable to process, MID (\d+) requeued/;
				if (!$thismid) {
					return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
				}
				#If I have not seen this MID before, and I'm doing debug
				if (!$requeued{$1} and $optctl{'debug'}) {
					my $errmid = $thismid;
					print "I found an LDAP requeue error.\n";
					print "Try to find info about beginning of this message?\n";
					print 'NOTE: requires that the program is being run in a UNIX/Cygwin environment. [yN] ';
					my $answer = <>;
					if ($answer =~ m/^y/i) {
						print "Running command: \"grep ' $errmid' $logfile |head\"\n";
						print `grep ' $errmid' $logfile |head`;
						print "\n";
					}
				}
				$requeued{$thismid}++;
			}
			else {
				return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
			}
			return 1;
		} #end of LDAP: section (Workqueue processing)

		#Tue Jan 17 14:24:50 2006 Info: Mail delivery client with DCID 8163315 exited due to the maximum concurrency configuration.
		elsif ((index $fileline, 'exited due to the maximum concurrency configuration') > 30) {
			$statistics{'Connections out (delivery)'}{'exited due to the maximum concurrency configuration'}++;
			return 1;
		}

		#Thu Apr 15 13:39:43 2004 Info: Alias match: recipient me@ironport.com mapped to ['me@ironport.com'] (bug 5997)
		#ALIAS_MATCH: 'Alias match: MID ~1~ RID ~2~ recipient ~3~ mapped to ~4~'
		elsif ((index $fileline, 'Alias match: ') == 0) {
			if ($fileline =~ m/^Alias match: MID (\d+) RID (\d+) recipient (.+) mapped to (.+)$/) {
				my $SN_MID = $SN . '-' . $1;
				return 0 unless $msginfo{$SN_MID};
				$msginfo{$SN_MID}{'aliases'}{$3} = $4;
			}
			else {
				return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
			}
			$statistics{'Recipients'}{'Alias hits'}++;
			return 1;
		} #end of Alias match: section
		#Info: Possible Delivery: DCID: 4641294 MID 8956463 to [0]
		#Message done does occur after this.
		elsif ((index $fileline, 'Possible Delivery: DCID') == 0) {
			$statistics{'Connections out (delivery)'}{'Possible Delivery'}++;
			return 1;
		}
		#SMTPAUTH_SUCCESS: 'SMTP Auth (ICID ~1~) succeeded for user: ~2~ using AUTH mechanism: ~3~ with profile: ~4~',
		#SMTPAUTH_FAILED:  'SMTP Auth (ICID ~1~) failed for user: ~2~ using AUTH mechanism: ~3~ with profile: ~4~',
		#SMTPAUTH_FWD_SERVER_BADCFG: 'SMTP Auth (ICID ~1~) profile: ~2~ is misconfigured or missing causing an Auth failure',
		#SMTPAUTH_FWD_SERVER_FAILED: 'SMTP Auth (ICID ~1~) could not reach forwarding server ~2~',
		#SMTPAUTH_FWD_SERVER_FAILED_ALERT: 'SMTP Auth (ICID ~1~) could not reach forwarding server ~2~ with reason: ~3~',
		#SMTPAUTH_FWD_SERVER_CONNECT: 'SMTP Auth forward server connection to ~1~, port ~2~, interface ~3~, ~4~ connections available',
		#SMTPAUTH_LDAP_QUERY_FAILED: 'SMTP Auth LDAP query failed, possible LDAP misconfiguration or unreachable server.',
		#SMTPAUTH_LDAP_QUERY_FAILED_INFO: 'SMTP Auth (ICID ~1~) LDAP query/user lookup failed for user: ~2~',
		#CONNECTION_INJECTION_SMTPAUTH_REQUIRED: 'SMTP Auth (ICID ~1~) was required but remote host did not initiate it',
		elsif ((index $fileline, 'SMTP Auth ') == 0) {
			if ($fileline =~ m/SMTP Auth \(ICID \d+\) (\S+) for user: (.+) using AUTH mechanism:/) {
				$statistics{'SMTP Auth'}{"$1 for $2"}++;
			}
			else{
				$statistics{'uninteresting? log entries'}{'SMTP Auth'}++;
			}
			return 1;
		}
		#Info: SMTP server connection killed ICID: 629531
		#Info: SMTP client connection killed DCID: 196546347
		elsif ((index $fileline, 'SMTP ') == 0) {
			if ((index $fileline, 'SMTP client connection killed DCID: ') == 0) {
			}
			elsif ((index $fileline, 'SMTP server connection killed ICID: ') == 0) {
			}
			elsif ((index $fileline, 'SMTP server shut down') == 0) {
			}
			elsif ((index $fileline, 'SMTP server starting') == 0) {
			}
			$statistics{'uninteresting? log entries'}{'SMTP server/client loglines'}++;
			return 1;
		}
		elsif ((index $fileline, 'QMQP ') == 0) {
			$statistics{'uninteresting? log entries'}{'QMQP loglines'}++;
			return 1;
		}
		elsif ((index $fileline, 'QMTP ') == 0) {
			$statistics{'uninteresting? log entries'}{'QMTP loglines'}++;
			return 1;
		}
		#BAD_ADDRESS: 'Incoming ~1~ connection undetermined IP on interface ~2~',
		elsif ((index $fileline, 'Incoming ') == 0) {
			$statistics{'uninteresting? log entries'}{$fileline}++;
			return 1;
		}
		#Tue Apr 27 12:05:15 2004 Info: Scanning over-the-limit.com with 1 msgs for expiration candidates.
		#Tue Apr 27 12:05:16 2004 Info: Done scanning inplaster.com,  1 msgs remain in queue.
		#something here at some point?

		#Info: DNS Temporary Failure structure.com MX - ServFail
		#never reached - no 'ID'
		elsif ((index $fileline, 'DNS ') == 0) {
			return 1;
		}
		#Info: lame DNS referral
		elsif ((index $fileline, 'lame DNS ') == 0) {
			return 1;
		}
		#Tue Jun 15 10:48:41 2004 Info: Global unsubscribe matched entry @263.net MID: 5542748 RID: 0 Address: bymtggipk@263.net
		#at some point prior to 4.0.8? this changed to:
		#Info: MID 85 Global unsubscribe matched entry foo@ RID 0 Address foo@domain0.d1.qa41.qa Action bounced
		#(duplicate entry made in 'Info: MID' section)
		elsif ((index $fileline, 'Global unsubscribe matched entry ') == 0) {
			$statistics{'Global unsubscribe matches'}++;
			return 1;
		}
		#4.0.0+
		#Wed Aug 25 23:25:17 2004 Info: SenderBase upload: 1 hosts totalling 309 bytes
		elsif ((index $fileline, 'Senderbase upload: ') == 0) {
			return 1;
		}
		#3.8.0:
		#this occurs when 'deleterecipients' is run
		#Fri May 14 20:41:12 2004 Info: Deleted: MID 3 to [0]
		elsif ((index $fileline, 'Deleted: MID ') == 0) {
			$fileline =~ m/Deleted: MID (\d+) to \[(.+)\]$/;
			my $SN_MID = $SN.'-'.$1;
			return 0 unless $msginfo{$SN_MID};
			foreach (split /,\s?/, $2) {
				my $rid = int($_);
				#deleted, so they're finalized
				$msginfo{$SN_MID}{'rcpts'}{$rid}{'resolution'} = 'deleted by deleterecipients';
				$msginfo{$SN_MID}{'finalized_rcpts'}++;
				$statistics{'Recipients'}{'deleted by deleterecipients'}++;
			}
			return 1;
		}
		#Wed Mar 17 18:48:29 2004 Info: Checkpoint Finished
		#internal SMTP process memory management stuff
		#never reached - no 'ID'
		elsif ((index $fileline, 'Checkpoint ') == 0) {
			return 1;
		}
		#Mon Oct  3 09:21:54 2005 Info: A Anti-Virus/Critical alert was sent to ironportalerts@interpublic.com with subject "Critical <Anti-Virus> nycmgw01.interpublic.com: MID 198463616 antivirus timeout error".
		elsif ((index $fileline, 'alert was sent to ') > 0) {
			$fileline =~ m/(\S+) alert was sent to/;
			$statistics{'uninteresting? log entries'}{"$1 alerts sent"}++;
			return 1;
		}
		#Info: Deliveries are currently suspended [5857.cerdamailers.com]
		#never reached - no 'ID'
		elsif ((index $fileline, 'Deliveries are currently suspended') == 0) {
			return 1;
		}
		elsif ((index $fileline, 'Begin Logfile') == 0) {
			return 1;
		}
		elsif ((index $fileline, 'End Logfile') == 0) {
			return 1;
		}
		#This section is for pre-3.8.0-038, bug 4989 - deleted all content 4-26-2005, since it's no longer useful..
		#Info: LDAP Mailhost: query unknown address IDomingu@se.verizonwireless.com to mre.vzwcorp.com
		#Info: LDAP Mailhost: query COD-LDAP.routing address IDomingu@SE.verizonwireless.com to mre.vzwcorp.com
		#Info: LDAP Reroute: query COD-LDAP.routing address ivan.dominguez@verizonwireless.com to [('IDomingu@SE.verizonwireless.com', 'mre.vzwcorp.com')]
		#Info: LDAP Masquerade: query COD-LDAP.masquerade address WHIDBSE@NE.VerizonWireless.com to Selena.Whidbee@VerizonWireless.com
		elsif ((index $fileline, 'LDAP ') == 0) {
			return 1;
		}
		#'Mon Jan 16 16:41:00 2006 Info: Mail delivery client with DCID 7590360 exited due to the maximum concurrency configuration.'
		elsif ((index $fileline, 'exited due to the maximum concurrency configuration') > 0) {
			$statistics{'Delivery client exited due to maximum concurrency configuration'}++;
			return 1;
		}
		else {
			return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
		}
	} #end of Info: section
	elsif ((index $fileline, 'Debug') == 0) {
		#skip for now
		return -1;
	}
	elsif ((index $fileline, 'Trace') == 0) {
		#skip for now
		return -1;
	}
	elsif ((index $fileline, 'Warning') == 0) {
		#skip for now
		return -1;
	}
	elsif ((index $fileline, 'Message-ID:') >= 0) {
		#linefeed-broken Message-IDs seem really common
		return -1;
	}
	elsif ((index $fileline, 'Critical: ') == 0) {
		#$statistics{'uninteresting? log entries'}{'Critical errors'}++;
		#I believe this will be handled enough by the 'alert was sent to' section
		return 1;
	}
	else {
		return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
	}
	print STDERR "late return: $fileline_orig\n";
	return 1;
} #process_logline

sub process_rewrite {
	my($SN, $SN_MID, $oldmid, $newmid, $rewrite_agent) = @_;
	my $SN_newmid = "$SN-$newmid";
	#return &process_rewrite($SN, $SN_MID, $thismid, int($1), $2);
	if (!$msginfo{$SN_MID}{'interface'}) {
		#Tue Jan  6 15:03:18 2004 Info: MID 2 rewritten to 3 by antispam
		if ($optctl{'debug'}) {
			print STDERR "$SN_MID - didn't see old mid $oldmid get init'd, so skipping rewrite to new info, MID $newmid\n";
			print STDERR "\tmost likely reason - message in quarantine released.\n";
		}
		return 0;
	}
	if ((index $rewrite_agent, 'filter') >= 0) {
		$statistics{'Filter Actions'}{$rewrite_agent}++;
	}
	$statistics{'Rewrite Agents'}{$rewrite_agent}++;
	foreach my $key (keys %{$msginfo{$SN_MID}}) {
		#Do not move over the rcpts unless the rewrite was a footer-stamp or drop-attachments type filter
		# neither of which clobber existing recipients
		if (($key eq 'rcpts') and ($rewrite_agent !~ m/add-footer filter/) and ($rewrite_agent !~ m/drop-attach.+filter/)) {
			next;
		}
		#Do not overwrite already gathered info
		# pertaining to where the rewritten msg is going
		$msginfo{$SN_newmid}{$key} = $msginfo{$SN_MID}{$key};
	}

	$msginfo{$SN_newmid}{'finalized_rcpts'} = 0;
	$msginfo{$SN_newmid}{'MID'} = $newmid;
	$msginfo{$SN_newmid}{'camefrom_MID'} = $oldmid;
	$msginfo{$SN_MID}{'Delivery status'} = 'was rewritten';
	$msginfo{$SN_newmid}{'Delivery status'} = 'from rewritten';
	$msginfo{$SN_newmid}{'rewrite agent'} = $rewrite_agent;

	#instantiate the ICID - MID relationship - ICID stays the same
	$icid_init{$msginfo{$SN_MID}{'ICID'}}{'MIDs'}{$newmid} = 1;

	return 1;
} #process_rewrite

#Handle removal of stuff from primary hash, to keep memory usage down
#Force flushing of the delete cache if the cleanflag is given
sub deletestuff {
	my ($tmpSN_MID, $cleanflag) = @_;
	if (!$msginfo{$tmpSN_MID} and !$cleanflag) {
		return 0;
	}
	if ($optctl{'debug'} and $cleanflag) {
		print STDERR "cleanflag given, should proceed to flush cache.\n";
	}

	if ($optctl{'debugmid'} and ($thismid == $optctl{'debugmid'})) {
		print " ---- deletestuff caching $tmpSN_MID\n";
		print "$fileline_orig\n";
		print Dumper($msginfo{$tmpSN_MID});
		print " ---- \n";
		my $foo = <>;
	}

	#push this onto the cache tracker
	if ($msginfo{$tmpSN_MID}) {
		push @{$statistics2{'msginfo-deletecache'}}, $tmpSN_MID;
	}
	#return unless forcing flush or cache is full
	if (!$cleanflag and !($#{$statistics2{'msginfo-deletecache'}} > $optctl{'deletecache'})) {
		return 1;
	}

	#iterate over entries in the cache for delete and other ops
	foreach my $SN_MID (@{$statistics2{'msginfo-deletecache'}}) {
		if ($optctl{'debugmid'} and ($msginfo{$SN_MID}{'MID'} == $optctl{'debugmid'})) {
			print " ---- deletestuff deleting $SN_MID\n";
			print Dumper($msginfo{$SN_MID});
			print " ---- \n";
			my $foo = <>;
		}

		#Since this is the last time to collect data from this object I need to
		# check timings here
		if ($optctl{'timings'}) {
			my $t = &timediff($msginfo{$SN_MID}{'starttime'}, $msginfo{$SN_MID}{'endtime'});
			&make_timingschart('Messages', $t);
		}

		#if the size is just 1 it means that the real size was not determined.
		#This generally happens for messages generated by the system.
		#I might want to track this for accounting of overall number of bytes processed
		#As the memory object gets deleted seems to be the best place for this accounting
		# to take place.
		#if (!$msginfo{$SN_MID}{'size'} or ($msginfo{$SN_MID}{'size'} == 1)) {
		#}

		#check for finalization of all seen recipients - this way I can call this function
		#multiple times and not actually delete until all data I might want to see has been gathered
		if (($msginfo{$SN_MID}{'rcpt_count'} && $msginfo{$SN_MID}{'finalized_rcpts'})
			&& ($msginfo{$SN_MID}{'rcpt_count'} > $msginfo{$SN_MID}{'finalized_rcpts'})) {
			#greater-than because a rewrite means 1 rcpt, but multiple finalizations to that one may occur
			# - see corestaff example
			next;
		}

		#No ICID -> MID relationship defined?  shouldn't occur..
		#3-7-2006: since I'm removing functionality to do anything unless the ICID_init was seen, this really should never occur.
		my $thisICID = $msginfo{$SN_MID}{'ICID'} || 0;
		if (!defined($msginfo{$SN_MID}{'ICID'}) or ((scalar keys %{$icid_init{$thisICID}{'MIDs'}}) == 0)) {
				print STDERR "MID $SN_MID - No ICID -> MID relationship defined?  shouldn't occur except at start..\n";
				print "MID:\n" . Dumper($msginfo{$SN_MID});
				print "thisICID: $thisICID\n";
				print "icid_init:\n" . Dumper($icid_init{$thisICID});
				&exitcleanup(\%nocleanup, "Line " . __LINE__ . " Exiting with cleanup during processing of $logfile entry:\n$fileline_orig", 1);
		}
		#Only 1 MID associated with this ICID and the ICID is closed, drop the ICID relationships entirely
		elsif ($icid_init{$thisICID}{'closed'} and ((scalar keys %{$icid_init{$thisICID}{'MIDs'}}) == 1)) {
			if ($icid_init{$msginfo{$SN_MID}{'ICID'}}{'msgs injected'}) {
				$statistics{'Connections in'}{' Which injected messages'}++;
			}
			else {
				#getting here indicates that a MID began, but no messages were successfully injected
				$statistics{'Connections in'}{' Which did not inject messages'}++;
			}
			&deleteicid($thisICID);
		}
		#In all other cases I at least want to remove the icid_mid_rel item
		else {
			delete $icid_init{$thisICID}{'MIDs'}{$msginfo{$SN_MID}{'MID'}};
		}

		#a flag to indicate printing out this message trace, for tracemail purposes:
		my $show = 0;

		#Conditions under which I write out a CSV file of message completions
		#flag msg-csv given & known RemoteIP & some # rcpts & msg size greater than 1
		if (($optctl{'msg-csv'} or $optctl{'tracemail'}) and ($msginfo{$SN_MID}{'remoteip'} !~ m/Unknown/o)
				and ((scalar keys %{$msginfo{$SN_MID}{'rcpts'}}) > 0)
				and ($msginfo{$SN_MID}{'size'} > 1)
				and (!defined($msginfo{$SN_MID}{'Delivery status'})
					or (($msginfo{$SN_MID}{'Delivery status'} ne 'was rewritten')
						and ($msginfo{$SN_MID}{'Delivery status'} ne 'generated message')))) {
			if ($optctl{'debugmid'} and ($thismid == $optctl{'debugmid'})) {
				print " ---- deletestuff cache deleting $SN_MID\n";
			}
			#print out certain of these values for use in other parsing
			my $rcpts_entry = '"'; #Beginning quote
			foreach my $rcpt (keys %{$msginfo{$SN_MID}{'rcpts'}}) {
				if (!defined($msginfo{$SN_MID}{'rcpts'}{$rcpt}{'rcpt_name'})) {
					print STDERR "bad rcpt? $SN_MID\n";
					print STDERR Dumper($msginfo{$SN_MID});
					#&exitcleanup(\%nocleanup, "Line " . __LINE__ . " Exiting with cleanup during processing of $logfile entry\n$fileline_orig", 1)
				}
				$rcpts_entry .= $msginfo{$SN_MID}{'rcpts'}{$rcpt}{'rcpt_name'}
				. "\t" . ($msginfo{$SN_MID}{'rcpts'}{$rcpt}{'resolution'} || 'dropped') . ',';
			}
			chop($rcpts_entry); #remove trailing ','
			$rcpts_entry .= '"'; #add ending quote for section
			$rcpts_entry =~ s/\\/\\\\/g; #escape escapes

			#Initialize an empty subject
			my $esc_subject;
			if (!$msginfo{$SN_MID}{'subject'}) {
				$esc_subject = "\"\"";
			}
			else {
				$esc_subject = $msginfo{$SN_MID}{'subject'};
				$esc_subject =~ s/\\/\\\\/g; #Escape escapes
				$esc_subject = "\"$esc_subject\""; #enquote
			}

			my $from = ($msginfo{$SN_MID}{'from'} || '');
			$from =~ s/\\/\\\\/g; #Escape escapes
			$from = "\"$from\""; #enquote

			if ($optctl{'tracemailto'} and ($rcpts_entry =~ m/$optctl{'tracemailto'}/)) {
				$show = 1;
			}
			elsif ($optctl{'tracemailfrom'} and ($from =~ m/$optctl{'tracemailfrom'}/)) {
				$show = 1;
			}
			elsif ($optctl{'tracemailip'} and ($msginfo{$SN_MID}{'remoteip'} =~ m/$optctl{'tracemailip'}/)) {
				$show = 1;
			}

			my $msg_csv_cache_tmp =
				$msginfo{$SN_MID}{'starttimestamp'} . ','  #Message start time
				. $linetimestamp . ',' #set Message end time to that of current line
				. $SN_MID . ','                        #system SN-MID string
				. $msginfo{$SN_MID}{'remoteip'} . ','  #injecting IP
				. ($msginfo{$SN_MID}{'sendergroup'} || 'NA') . ','  #assigned SenderGroup
				. ($msginfo{$SN_MID}{'policy'} || 'NA') . ','  #assigned Policy (action really)
				. ($msginfo{$SN_MID}{'SBRS'} || 'NA') . ','    #IP's SBRS
				. ($msginfo{$SN_MID}{'from'} || '') . ','    #envelope from
				. $msginfo{$SN_MID}{'size'} . ','    #original! message size
				. ($msginfo{$SN_MID}{'Message-ID'} || '') . ','    #actual message ID
				. ($msginfo{$SN_MID}{'AV-positive'} || '0') . ',' #AV-pos flag
				. ($msginfo{$SN_MID}{'AS-positive'} || '0') . ',' #BM-pos flag
				. $rcpts_entry . ','                 #Recipients and resolution
				. $esc_subject #subject
				. "\n";

			#if doing msg-project (IronPort internal project), store different data set:
			if ($optctl{'msg-project'}) {
				$msg_csv_cache_tmp =
					$msginfo{$SN_MID}{'starttimestamp'} . ','  #Message start time
					. $msginfo{$SN_MID}{'remoteip'} . ','  #injecting IP
					. ($msginfo{$SN_MID}{'SBRS'} || 'NA') . ','    #IP's SBRS
					. (&striplocal($msginfo{$SN_MID}{'from'}) || '') . ','    #envelope from
					. $msginfo{$SN_MID}{'size'} . ','    #original! message size
					. ($msginfo{$SN_MID}{'AV-positive'} || '0') . ',' #AV-pos flag
					. ($msginfo{$SN_MID}{'AS-positive'} || '0') . ',' #BM-pos flag
					. "\"" . ($msginfo{$SN_MID}{'header:from'} || '') . "\"," #From: header content - domain only
					. "\"" . ($msginfo{$SN_MID}{'header:sender'} || '') . "\","
					. "\"" . ($msginfo{$SN_MID}{'header:resent-from'} || '') . "\","
					. "\"" . ($msginfo{$SN_MID}{'header:resent-sender'} || '') . "\","
					. "\"" . ($msginfo{$SN_MID}{'header:domainkey-signature'} || '') . "\"," #DomainKey-Signature header content
					. "\"" . ($msginfo{$SN_MID}{'header:dkim-signature'} || '') . "\"" #DKIM-Signature header content
					. "\n";
			}

			#Only keep this stuff if doing msg-csv (not tracemail)
			if ($optctl{'msg-csv'}) {
				$msg_csv_cache .= $msg_csv_cache_tmp;
				$optctl{'msg-csv-cachesize-count'}++;
			}
			#Show message trace if this entry matched a tracemail parameter:
			if ($optctl{'tracemail'}
					and (($optctl{'tracemailto'} and ($msg_csv_cache_tmp =~ m/$optctl{'tracemailto'}/))
					or ($optctl{'tracemailfrom'} and ($msg_csv_cache_tmp =~ m/$optctl{'tracemailfrom'}/)))) {
				&printmatch_fromCSV($msg_csv_cache_tmp);
			}
		} #if optctl msg-csv or tracemail
		delete $msginfo{$SN_MID};

		#Don't do this yet if the cache isn't full.  This buffering should help prevent too much thrash
		if ($optctl{'msg-csv-cachesize-count'} > $optctl{'msg-csv-cachesize'}) {
			no warnings;
			my $globref = *{$tmpfh{'msg-csv'}};
			print $globref $msg_csv_cache; #print out the buffer
			$msg_csv_cache = ''; #now zero the buffer
			$optctl{'msg-csv-cachesize-count'} = 0; #zero the count
		}
	} #foreach my $SN_MID (@{$statistics2{'msginfo-deletecache'}}) {
	#Empty the cache I just did deletes for:
	@{$statistics2{'msginfo-deletecache'}} = ();

	return 1;
} #sub deletestuff

sub deleteicid {
	my $icid = $_[0];

	#I decided not so use an encachement scheme here since the delete
	#is so much less complex than the MID one.  (Unless SQL in use)
	#exit before SQL if no SQL or 'sendergroup' wasn't found:
	if (!$optctl{'sql'} or !$icid_init{$icid}{'sendergroup'}) {
		delete $icid_init{$icid};
		return 1;
	}
	#$icid_init{$icid}{'time_end'} = $linetimestamp;
	#Wed Apr 26 17:59:12 2006
	# 1   2  3    4        5
	#needs to be in this format: YYYY-MM-DD HH:MM:SS
	$linetimestamp =~ m/^(?:\w{3}) (\w{3})\s{1,2}(\d{1,2}) (\d{2}:\d{2}:\d{2}) (\d{4})$/;
	#                       1       2              3        4                    5
	$icid_init{$icid}{'endtime'} = sprintf '%d-%02d-%02d %s', $4, $monthnums{$1}, $2, $3;
	$icid_init{$icid}{'starttime'} =~ m/^(?:\w{3}) (\w{3})\s{1,2}(\d{1,2}) (\d{2}:\d{2}:\d{2}) (\d{4})$/;
	$icid_init{$icid}{'starttime'} = sprintf '%d-%02d-%02d %s', $4, $monthnums{$1}, $2, $3;

	my @sql_a = ($icid,
		$sql_data{'system'}{$SN}, #id of row for this SN in system table
		$icid_init{$icid}{'remoteip'},
		$icid_init{$icid}{'interface'},
		$icid_init{$icid}{'starttime'},
		$icid_init{$icid}{'endtime'},
		$sql_data{'policy'}{$icid_init{$icid}{'policy'}},
		$sql_data{'sendergroup'}{$icid_init{$icid}{'sendergroup'}},
		$icid_init{$icid}{'hatmatch'},
		$icid_init{$icid}{'score'});
	push @sql_icidarray, \@sql_a;
	delete $icid_init{$icid};
	&icid_sql();
	return 1;
} #sub deleteicid

# This function is used to print out msg-csv matches.  Duplicated from searchhier.pl
sub printmatch_fromCSV {
	my ($line) = @_;
	my @linevalues = CSVsplit($line);
	my $count = 0;

	#Print out certain fields in this desired ordering:
	foreach my $field (@{$statistics2{'msg-csv-header_array'}}) {
		#if this match from the header array isn't in the CSVsplit, print an empty string
		my $printval = $linevalues[$count++] || '';
		print "$field\t$printval\n";
	}
	print "-" x 55 . "\n";
	return 1;
} #printmatch_fromCSV

sub icid_sql_old {
	#Don't do this yet if the cache isn't full.  This buffering should help prevent too much thrash
	if ($#sql_icidarray < $optctl{'sql-cache'}) {
		return -1;
	}
	my $sth = $dbh->prepare("INSERT IGNORE INTO connections(`icid`, `system_id`, `remoteip`, `interface`, `starttime`, `endtime`, `policy_id`, `sendergroup_id`, `match`, `sbrs`) "
		. "VALUES (?, " #icid
		. "?, " #system_id
		. "?, " #remoteip
		. "?, " #interface
		. "?, " #starttime
		. "?, " #endtime
		. "?, " #policy_id
		. "?, " #sendergroup_id
		. "?, " #hatmatch
		. "?)"); #score
	$dbh->do('SET AUTOCOMMIT=0');
	$dbh->do('LOCK TABLE connections WRITE');
	#This is for innodb if in use:
	#$dbh->do('START TRANSACTION');
	#prevent index updates per insert - thrashes:
	$dbh->do('ALTER TABLE connections DISABLE KEYS') unless $optctl{'sql-cache'} <= 1000;
	foreach my $s_arr (@sql_icidarray) {
		my $rv = $sth->execute($$s_arr[0], $$s_arr[1], $$s_arr[2], $$s_arr[3], $$s_arr[4], $$s_arr[5], $$s_arr[6], $$s_arr[7], $$s_arr[8], $$s_arr[9]);
		if (!$rv) {
			print STDERR "DB error on \n@{$s_arr} print $$s_arr[0]\n\t" . $dbh->errstr . "\n";
		}
	}
	$sth->finish();
	undef(@sql_icidarray);
	$dbh->do('COMMIT');
	#reenable index updates:
	$dbh->do('ALTER TABLE connections ENABLE KEYS') unless $optctl{'sql-cache'} <= 1000;
	$dbh->do('UNLOCK TABLES');
	return 1;
} #sub icid_sql_old

sub icid_sql {
	if ($#sql_icidarray < $optctl{'sql-cache'}) {
		return -1;
	}
#	my $sth = $dbh->prepare("INSERT IGNORE INTO connections(`icid`, `system_id`, `remoteip`, `interface`, `starttime`, `endtime`, `policy_id`, `sendergroup_id`, `match`, `sbrs`) "
#		. "VALUES (?, " #icid
#		. "?, " #system_id
#		. "?, " #remoteip
#		. "?, " #interface
#		. "?, " #starttime
#		. "?, " #endtime
#		. "?, " #policy_id
#		. "?, " #sendergroup_id
#		. "?, " #match
#		. "?)"); #score
	open(FILE, ">>$tmp_sqlfiles{'connections'}");
	foreach my $s_arr (@sql_icidarray) {
		print FILE "\t$$s_arr[0]\t$$s_arr[1]\t$$s_arr[2]\t$$s_arr[3]\t$$s_arr[4]\t$$s_arr[5]\t$$s_arr[6]\t$$s_arr[7]\t$$s_arr[8]\t$$s_arr[9]\n";
	}
	undef(@sql_icidarray);
	close(FILE);
	return 1;
} #sub icid_sql

sub load_sql_data {
	my ($table, $file) = @_;
	my $dir_file = File::Spec->catfile($cwd, $file);
	my $query = "LOAD DATA INFILE '$dir_file' INTO TABLE $table "
		. 'FIELDS TERMINATED BY "\t" LINES TERMINATED BY "\n"';
	print STDERR "$query\n" if $optctl{'debug'};
	my $rv = $dbh->do($query);
	return $rv;
}

#This function gets called if an in-memory map of policy->id
# does not find a match for a given policy.
#Given the unmatched policy, this function looks for an update in
# the database.  If none is found the new entry is inserted and
# the reference hash is updated.
sub policy_sql {
	return &tablehash_update('policy', 'policy', $_[0]);
}
#This function gets called if an in-memory map of sendergroup->id
# does not find a match for a given sendergroup.
#Given the unmatched sendergroup, this function looks for an update in
# the database.  If none is found the new entry is inserted and
# the reference hash is updated.
sub sendergroup_sql {
	return &tablehash_update('sendergroup', 'sendergroup', $_[0]);
}
#This function gets called if an in-memory map of system->id
# does not find a match for a given SN.
#Given the unmatched SN, this function looks for an update in
# the database.  If none is found the new entry is inserted and
# the reference hash is updated.
sub system_sql {
	return &tablehash_update('sn', 'system', $_[0], $_[1] || undef);
}

#general function used to update db tables and sql_hash table reference data
sub tablehash_update {
	my ($cell, $table, $newdata, $otherdata_href) = @_;
	return 1 if $sql_data{$table}{$newdata};
	my $select = "SELECT id,$cell FROM $table";
	my $href = $dbh->selectall_hashref($select, 'id');
	#update sql_data{$table} hash from the db
	foreach my $id (keys %{$href}) {
		my $thiscell = $$href{$id}{$cell};
		$sql_data{$table}{$thiscell} = $id;
	}
	return 1 if $sql_data{$table}{$cell};
	my $othercells = '';
	my $otherdata = '';
	if ($otherdata_href) {
		foreach my $key (keys %{$otherdata_href}) {
			$othercells .= ",`$key`";
			$otherdata .= ",'$$otherdata_href{$key}'";
		}
	}
	#update the db with this SN if I don't have it now
	my $sql = "INSERT IGNORE INTO $table(`$cell`$othercells) VALUES ('$newdata'$otherdata)";
	$dbh->do($sql);
	#now try again
	$href = $dbh->selectall_hashref($select, 'id');
	#update sql_data{$table} hash from the db
	foreach my $id (keys %{$href}) {
		my $thiscell = $$href{$id}{$cell};
		$sql_data{$table}{$thiscell} = $id;
	}
	return 1 if $sql_data{$table}{$newdata};
	return 0;
} #sub tablehash_update

# Input:
#     The SN-MID string
#     The ICID
#     The email sender 'From' string
sub process_from {
	my($SN_MID, $ICID, $from) = @_;
	if (!$from) { #so I can use it w/o worry
		$from = '';
	}
	#Processing for domains in ./domains or provided via -mydomain
	if ($optctl{'use_domains-from'}) {
		my $dom = $from;
		substr $dom, 0, (index $dom, '@') + 1, ''; #keep all after '@'
		if (defined($domains{$dom})) {
			$domains{$dom}{'From'}++;
		}
		if ($dom =~ m/\..+\..+/) {
			#subdomain?  let's look one finer also
			$dom =~ s/^.+?\.(.+)$/$1/;
			if (defined($domains{$dom})) {
				$domains{$dom}{'From'}++;
			}
		}
		#use_domains in use, but this was not one of them.  Skip further 'from' processing
		if (!defined($domains{$dom}) or !defined($domains{$dom}{'From'})) {
			&deletestuff($SN_MID);
			return 1;
		}
	}
	#if the ICID is 0, it's a bounce or rewrite of some sort
	# - may want to do more with these, here...

	#return here if the relevant ICID is 0, to avoid double-counting stats
	# since ICID 0 messages are rewrites of some sort
	if ($msginfo{$SN_MID}{'Delivery status'} or ($msginfo{$SN_MID}{'ICID'} == 0)) {
		return 1;
	}

	#Initialize even if unseen; get around problem where rewrite message comes late.
	if (!$msginfo{$SN_MID}) {
		$msginfo{$SN_MID}{'MID'} = $thismid;
		$msginfo{$SN_MID}{'ICID'} = $ICID;
		$msginfo{$SN_MID}{'starttimestamp'} = $linetimestamp;
		$msginfo{$SN_MID}{'rcpt_count'} = 0;
		$msginfo{$SN_MID}{'interface'} = 'Unknown (old conn)';
		$msginfo{$SN_MID}{'remoteip'} = 'Unknown (old conn)';
		if (!$icid_init{$ICID}) {
			$icid_init{$ICID}{'interface'} = 'Unknown (old conn)';
		}
	}

	if ($from eq '') { #probably a bounce
		$msginfo{$SN_MID}{'from'} = 'None';
		$from = 'None';
		$statistics{'Messages'}{'Unspecified mail-from (bounces, etc)'}++;
	}
	$msginfo{$SN_MID}{'from'} = $from;
	if ($fromRegex && ((index $from, $fromRegex) >= 0)) {
		$statistics{'Searches'}{"Number of email messages from '$optctl{'from'}'"}++;
	}
	if ($optctl{'collate-from'}) {
		$statistics{'Envelope From addresses which at least began sending mail'}{$from}{'count'}++;
		$statistics{'Envelope From addresses which at least began sending mail'}{' Total'}++;
		if ($msginfo{$SN_MID}{'ICID'} == 0) {
			$statistics{'Envelope From addresses which at least began sending mail'}{' Overcount (generated msgs)'}++;
		}
	}
	if ($optctl{'collate-domain'}) {
		$statistics{'Envelope From domains which at least began sending mail'}{&whatdomain($from)}{'count'}++;
		$statistics{'Envelope From domains which at least began sending mail'}{' Total'}++;
		if ($msginfo{$SN_MID}{'ICID'} == 0) {
			$statistics{'Envelope From domains which at least began sending mail'}{' Overcount (generated msgs)'}++;
		}
	}
	return 1;
} #process_from

# Input:
#     The SN-MID string
#     The email recipient 'To' string
#     The RID or '' in cases where there is no RID
#     Some possible status, such as "Rejected by RAT"
sub process_to {
	my ($SN_MID, $to, $rid, $status) = @_;
	if ($msginfo{$SN_MID}{'Delivery status'}) {
		#This indicates it was rewritten or generated
#if ($msginfo{$SN_MID}{'Delivery status'} and ($msginfo{$SN_MID}{'Delivery status'} eq 'from rewritten')) {
		my $originalMID = $msginfo{$SN_MID}{'camefrom_MID'};
		my $originalSN_MID = $SN.'-'.$originalMID;
		#debug use:
		if ($optctl{'debugmid'} and ($thismid == $optctl{'debugmid'})) {
			print STDERR "in process_to, seeing original MID $originalMID:\n";
			print STDERR Dumper($msginfo{$SN_MID});
			print STDERR "CURRENT MID $SN_MID:\n";
		}
		if ($rid ne '') { #sometimes empty when the rcpt was rejected
			$msginfo{$SN_MID}{'rcpts'}{$rid}{'rcpt_name'} = $to || '?';
			$msginfo{$SN_MID}{'rcpt_count'}++;
		}

		#Look for all recipients in the original message ane mark them as rewritten
		foreach (keys %{$msginfo{$originalSN_MID}{'rcpts'}}) {
			my $rid = int($_);
			#skip this rcpt unless there is NOT already a resolution and a rewrite agent is listed for *this* MID
			next unless (!defined($msginfo{$originalSN_MID}{'rcpts'}{$rid}{'resolution'}) and $msginfo{$SN_MID}{'rewrite agent'});
			$msginfo{$originalSN_MID}{'rcpts'}{$rid}{'resolution'} = "rewritten into MID $msginfo{$SN_MID}{'MID'} rcpt $to by $msginfo{$SN_MID}{'rewrite agent'}";
			#finalize each recipient in the original MID
			$msginfo{$originalSN_MID}{'finalized_rcpts'}++;
		}
		#This came from a rewritten message, do not gather more stats on it.
		return 1;
	} #rewritten

	#Processing for domains in ./domains or provided via -mydomain
	if ($optctl{'use_domains'}) {
		my $dom = $to;
		substr $dom, 0, (index $dom, '@') + 1, ''; #keep all after '@'
		if (defined($domains{$dom})) {
			$domains{$dom}{'To'}++;
		}
		if ($dom =~ m/\..+\..+/) {
			#subdomain?  let's look one finer also
			$dom =~ s/^.+?\.(.+)$/$1/;
			if (defined($domains{$dom})) {
				$domains{$dom}{'To'}++;
			}
		}
		#use_domains in use, but this was not one of them.  Skip further 'to' processing
		if (!defined($domains{$dom}) or !defined($domains{$dom}{'From'})) {
			return 1;
		}
	}

	#If this message was splintered from another and I have msginfo for the *original* msg:
	if ($msginfo{$SN_MID}{'splintered from'} and defined($msginfo{$SN.'-'.$msginfo{$SN_MID}{'splintered from'}})) {
		my $originalMID = $msginfo{$SN_MID}{'splintered from'};
		my $originalSN_MID = $SN.'-'.$originalMID;

		#FIND this recipient in the original message ane mark it as splintered out
		foreach (keys %{$msginfo{$originalSN_MID}{'rcpts'}}) {
			my $rid = int($_);
			#This isn't the splintered rcpt?:
			next unless ($msginfo{$originalSN_MID}{'rcpts'}{$rid}{'rcpt_name'} eq $to);
			if (!$msginfo{$originalSN_MID}{'rcpts'}{$rid}{'resolution'}) {
				#fill out the resolution if it isn't there
				$msginfo{$originalSN_MID}{'rcpts'}{$rid}{'resolution'} = "splintered into MID $msginfo{$SN_MID}{'MID'}";
			}
			last; #no need to check the rest, 1 rcpt of matching name
		}
		#account for finalized recipient in the original MID for each one in splinters
		#but only if the original MID is actually still around...
		if (defined $msginfo{$originalMID}) {
			$msginfo{$originalMID}{'finalized_rcpts'}++;
		}
		#Increment a statistical counter indicating more messages via splintering
		$statistics{'Messages'}{'received extra via splintering'}++;
	} #splintered recipient

	else { #this is not a recipient splintered - real count
		#If a value was passed in $status, it indicates a rejected recipient
		#- status is the detail on that. Such as: Rejected by LDAPACCEPT
		if ($status) {
			$statistics{'Recipients'}{$status}++;

			if ($optctl{'timeperiods'}) {
				&collate_timeperiods('Recipient Status', $status);
			}

			if ($status eq 'Rejected by LDAPACCEPT') {
				#not doing 'finalized_rcpts here because these never get RIDs
				if ($optctl{'collate-rejects'}) {
					$statistics{'Recipients rejected by LDAPACCEPT'}{$to}++;
				}
			}
			elsif ($status eq 'Rejected by RAT') {
				#not doing 'finalized_rcpts here because these never get RIDs
				if ($optctl{'collate-rejects'}) {
					$statistics{'Recipients rejected by RAT'}{$to}++;
				}
			}

			if ($optctl{'collate-ip'} and (index $status, 'Rejected') == 0) {
				#increment the # of rejected recipients from this IP
				$collate_ip{$msginfo{$SN_MID}{'collate-ip'}}{9}++;
			}
			if ($optctl{'collate-from'}) {
				$statistics{'Envelope From addresses which at least began sending mail'}{$msginfo{$SN_MID}{'from'}}{'Rej Rcpts'}++;
			}
			if ($optctl{'collate-domain'}) {
				$statistics{'Envelope From domains which at least began sending mail'}{&whatdomain($msginfo{$SN_MID}{'from'})}{'Rej Rcpts'}++;
			}
		} #if status
		else {
			if ($optctl{'collate-from'}) {
				$statistics{'Envelope From addresses which at least began sending mail'}{$msginfo{$SN_MID}{'from'}}{'Acc Rcpts'}++;
			}
			if ($optctl{'collate-domain'}) {
				$statistics{'Envelope From domains which at least began sending mail'}{&whatdomain($msginfo{$SN_MID}{'from'})}{'Acc Rcpts'}++;
			}
		}
	} #else - not a splintered recipient

	if ($rid ne '') { #sometimes empty when the rcpt was rejected - no RID allocated
		$msginfo{$SN_MID}{'rcpts'}{$rid}{'rcpt_name'} = $to || '?';
		$msginfo{$SN_MID}{'rcpt_count'}++;
		#Use this to track whether or not to garner stats per_domain and per_rcpt for this addr
		my $domaincontrol = 0;
		if ($optctl{'mydomains'}) {
			foreach my $dom	(keys %{$optctl{'mydomains'}}) {
				if ((index $to, $dom) >= 2) {
					$domaincontrol = 1;
				}
			}
		}
		#put this here so my counts don't have relay-attempt domains
		#I want per_ entries for this item if:
		#(domaincontrol is on) OR (fromall is on) OR (!domaincontrol and (fromall or (it was not from a blank envelope sender)))
		if ($optctl{'per_domain'} and $msginfo{$SN_MID}{'directionality'} and ($msginfo{$SN_MID}{'directionality'} eq 'Incoming')) {
			if ($domaincontrol or ($optctl{'fromall'} || 0) or ((!$domaincontrol) and (($optctl{'fromall'} || 0) or ($msginfo{$SN_MID}{'from'} ne 'None')))) {
				my $domain = &striplocal($to);
				$statistics{'Per destination domain'}{$domain}{'count'}++;
			}
		}

		#I want per_ entries for this item if:
		#(domaincontrol is on) OR (fromall is on) OR (!domaincontrol and (fromall or (it was not from a blank envelope sender)))
		if ($optctl{'per_rcpt'} and $msginfo{$SN_MID}{'directionality'} and ($msginfo{$SN_MID}{'directionality'} eq 'Incoming')) {
			if ($domaincontrol or $optctl{'fromall'} or (!$domaincontrol and ($optctl{'fromall'} or ($msginfo{$SN_MID}{'from'} ne 'None')))) {
				$statistics{'Per destination rcpt'}{lc($msginfo{$SN_MID}{'rcpts'}{$rid}{'rcpt_name'})}{'count'}++;
			}
		}
	} #$rid ne ''

	if ($toRegex && ((index $to, $toRegex) >= 0)) {
		$statistics{'Searches'}{"Number of email messages to '$optctl{'to'}'"}++;
		if ((index $status, 'Rejected') >= 0) {
			$statistics{'Searches'}{"Number of email messages to '$optctl{'to'}' $status"}++;
		}
		if ($fromRegex && ((index $msginfo{$SN_MID}{'from'}, $fromRegex) >= 0)) {
			#Wording is important here, because each email message
			# may have multiple recipients.  This is NOT simply the
			# tally of messages.
			$statistics{'Searches'}{"Number of rcpts of messages from '$optctl{'from'}' to '$optctl{'to'}'"}++;
			$msginfo{$SN_MID}{'to-from-match'} = 1;
		}
	}

	return 1;
} #End of process_to

#Do Anti-Virus logline processing
# return 1 if positive, 2 if negative, 0 if err
# Input:
#     -The SN-MID string
#     -The result of the scan, a string which SHOULD always be either
#       'positive' or 'negative' or 'encrypted' or 'repaired'
#     -other information that was on the end of the AV result line.
#       Usually unscannable code or virus type
sub process_AV {
	my ($SN_MID, $scan_result, $otherinfo, $engine) = @_;
	our $timediff = 0;
	our $shortname = 'AV';
	our $typename = 'virus';
	our $pluralname = 'viruses';
	if ($engine) {
		$engine = " - $engine";
	}

	if ($otherinfo) {
		if ($otherinfo =~ m/0x/o) { #unscannable code
			#some error code interpretation could go here
		}
		elsif ($otherinfo eq '(released from Outbreak)') {
			$otherinfo = '(Negative, released from Outbreak)';
		}
		$statistics{"Anti-Virus$engine"}{$otherinfo}++;
	}

	if ($engine) { #means this is an interim verdict
		#So jump out earlier to avoid double-counting
		return &generic_AVASfunc("Anti-Virus$engine", $scan_result, $shortname);
	}

	if ($optctl{'collate-ip'} and $msginfo{$SN_MID}{'collate-ip'}) {
		#if we're collecting stats for collate-ip, note another AV-pos occurence for this IP
		if ($scan_result eq 'positive') {
			#increment the # of av-positives
			#count number of messages per IP/Class
			$collate_ip{$msginfo{$SN_MID}{'collate-ip'}}{6}++;
		}
	}

	if ($optctl{'timings'}) {
		$msginfo{$SN_MID}{'AVid_time'} = $linetimeepoch;
		$timediff = &timediff($msginfo{$SN_MID}{'starttime'}, $msginfo{$SN_MID}{'AVid_time'});
		if ($timediff < 0) {
			$timediff = 0;
		}
		&make_timingschart("Anti-Virus$engine", $timediff);
		if ($timediff > $avslowest) {
			$avslowest = $timediff;
			$avslowestMID = $SN_MID;
		}
	}

	$optctl{'AVstats'}++; #increment this to know we have seen some
	return &generic_AVASfunc("Anti-Virus$engine", $scan_result, $shortname);
} #process_AV

#Do Brightmail logline processing
# return 1 if positive/suspect, 2 if negative, 0 if err
# Input:
#     The SN-MID string
#     The result of the scan, a string which SHOULD always be either
#       'positive' or 'negative' or 'suspect'
sub process_AS {
	my ($SN_MID, $scan_result, $engine) = @_;
	our $timediff = 0;
	our $pluralname = 'spam';
	our $typename = 'spam';
	our $shortname = 'AS';


	if (!($engine eq 'Anti-Spam')) { #means this is an interim verdict
		#So jump out earlier to avoid double-counting
		return &generic_AVASfunc($engine, $scan_result, $shortname);
	}

	$optctl{'ASstats'}++;
	if ($optctl{'timings'}) {
		$msginfo{$SN_MID}{'ASid_time'} = $linetimeepoch;
		$timediff = &timediff($msginfo{$SN_MID}{'starttime'}, $msginfo{$SN_MID}{'ASid_time'});
		if ($timediff < 0) {
			#this is weird, time of AS identification is prior to message start time.
			#Set the timediff to be 0 because this almost certainly is just an ntp jump.
			#if ($optctl{'debug'}) {
				print STDERR "Jumpy NTP?  AS scantime ($msginfo{$SN_MID}{'ASid_time'}) prior to message starttime ($msginfo{$SN_MID}{'starttime'})\n";
			#}
			$timediff = 0;
		}
		&make_timingschart($engine, $timediff);
	}
	#Restrict this to 'Anti-Spam' so that we don't collate for interim verdicts:
	if ($msginfo{$SN_MID}{'SBRS'} and ($engine eq 'Anti-Spam')) {
		#associate sbrs to count of scan_result hits
		$statistics{'SBRS'}{$msginfo{$SN_MID}{'SBRS'}}{$scan_result}++;
		#count total amount of email which got to BM for this score
		$statistics{'SBRS'}{$msginfo{$SN_MID}{'SBRS'}}{'ScdMsgs'}++;
	}
	else {
		#this would be a little odd - if we're in this function then all
		#connections should have it even if 'None'.
		#may occur if I don't see the connection initiate, though.
		#or if it's a system-generated message
	}
	#if the scan result is positive and I want to see subjects per SBRS score:
	if ($optctl{'SBRS-subjects'} and ($scan_result eq 'positive') and $msginfo{$SN_MID}{'SBRS'} and $msginfo{$SN_MID}{'subject'}) {
		push @{$sbrs_subjects{$msginfo{$SN_MID}{'SBRS'}}}, "[$scan_result, $icid_init{$msginfo{$SN_MID}{'ICID'}}{'remoteip'}] $msginfo{$SN_MID}{'subject'}";
	}
	if ($optctl{'collate-ip'} and $msginfo{$SN_MID}{'collate-ip'}) {
		#count number of messages per IP/Class C
		my $remoteip = $msginfo{$SN_MID}{'collate-ip'};
		#if we are collecting stats for collate-ip, note another AS-pos occurence for this IP
		if ($scan_result eq 'positive') {
			$collate_ip{$remoteip}{5}++;
		}
		#count all messages scanned at this IP's injection
		$collate_ip{$remoteip}{4}++;
	}
	if ($scan_result eq 'positive') {
		if ($optctl{'collate-domain'}) {
			$statistics{'Envelope From domains which at least began sending mail'}{&whatdomain($msginfo{$SN_MID}{'from'})}{'ASpos'}++;
		}
		if ($optctl{'collate-from'}) {
			$statistics{'Envelope From addresses which at least began sending mail'}{$msginfo{$SN_MID}{'from'}}{'ASpos'}++;
		}
	}

	return &generic_AVASfunc($engine, $scan_result, $shortname);
} #process_AS

#used by process_AS and process_AV
sub generic_AVASfunc {
	my ($section, $result, $shortname) = @_;
	my $type_res = "$shortname-$result";

	if ($optctl{'timeperiods'}) {
		&collate_timeperiods("AVAS", "$section $result");
	}

	if (($msginfo{$SN_MID}{'from'} eq 'None') or !$msginfo{$SN_MID}{'from'} or ($msginfo{$SN_MID}{'from'} eq '')) {
		if ($section =~ m/^Anti-\w{4,5}$/) { #not interim?
			$statistics{'Bounces'}{"which were $type_res"}++;
		}
	}

	$statistics{$section}{"$shortname Total messages"}++;
	$statistics{$section}{"$type_res messages"}++;
	$msginfo{$SN_MID}{$type_res} = 1;

	#Collate AV and AS positive/suspect counts for PRSA
	if ($result eq 'positive') {
		$statistics{'Policy matches'}{$msginfo{$SN_MID}{'PRSA'}}{"$section $result"}++;
	}
	elsif ($result eq 'suspect') {
		$statistics{'Policy matches'}{$msginfo{$SN_MID}{'PRSA'}}{"$section $result"}++;
	}

	#For the purposes of size determination, I'll set the size to be 5120
	# for any message which I don't know the size to.
	#This happens if the 'ready bytes' line wasn't seen
	if (!$msginfo{$SN_MID}{'size'}) {
		$msginfo{$SN_MID}{'size'} = 1;
	}

	#This is for generation of a general message sizes table
	#copied this general format from Evan
	my $bytes = $msginfo{$SN_MID}{'size'};
	#round into numbers multiplicable by 10KB, 10240:
	$bytemark = 10240 * (int($bytes/10240) + 1);

	my $kbytemark = $bytemark / 1024;
	if ($kbytemark < 130) {
		$statistics{$section}{'Sizes'}{" < $kbytemark"."KB"}{$result}++;
	}
	elsif ($bytemark <= 153600) { #150KB
		$statistics{$section}{'Sizes'}{" < 150KB"}{$result}++;
	}
	elsif ($bytemark <= 204800) { #200KB
		$statistics{$section}{'Sizes'}{" < 200KB"}{$result}++;
	}
	elsif ($bytemark <= 512000) { #500KB
		$statistics{$section}{'Sizes'}{" < 500KB"}{$result}++;
	}
	elsif ($bytemark <= 1024000) { #1MB
		$statistics{$section}{'Sizes'}{" < 1MB"}{$result}++;
	}
	else { #above 1MB
		$statistics{$section}{'Sizes'}{" > 1MB"}{$result}++;
	}

	if (defined($msginfo{$SN_MID}{'size'}) and ($msginfo{$SN_MID}{'size'} != 1)) {
		$statistics{$section}{'Bytes scanned (Total)'} += $msginfo{$SN_MID}{'size'};
		$statistics{$section}{"Bytes scanned ($result)"} += $msginfo{$SN_MID}{'size'};
	}
	else {
		if ($optctl{'debug'}) {
			print STDERR "No size found for message with MID $msginfo{$SN_MID}{'MID'} ($SN_MID)\n";
		}
	}

	#This key is used to indicate whether one or more of the rcpts
	# of the message matched a provided 'to' search string.
	my $searchspamto_key = 0;
	#Iterate over each of the found recipients for the message, for special data collation
	foreach my $rcpt_rid (keys %{$msginfo{$SN_MID}{'rcpts'}}) {
		$statistics{$section}{"$type_res rcpts"}++;
		$statistics{$section}{"$shortname Total recipients"}++;

		if ($toRegex && ((index $msginfo{$SN_MID}{'rcpts'}{$rcpt_rid}{'rcpt_name'}, $toRegex) >= 0)) {
			#This rcpt message is $typename and matches our 'To' search
			$statistics{'Searches'}{"Number of $type_res rcpt messages to '$optctl{'to'}'"}++;
			$searchspamto_key = 1;
		}
		#count for positive & suspect cases final Anti-[Spam|Virus] results:
		if ((($result eq 'positive') or ($result eq 'suspect')) and ($section =~ m/^Anti-\w{4,5}$/)) {
			my $domaincontrol = 0;
			if ($optctl{'mydomains'}) {
				foreach my $dom	(keys %{$optctl{'mydomains'}}) {
					if ((index $msginfo{$SN_MID}{'rcpts'}{$rcpt_rid}{'rcpt_name'}, $dom) >= 2) {
						$domaincontrol = 1;
					}
				}
			}
			#want per_domain stuff, AND (domain is one I track, OR I want them all)
			#I want per_ entries for this item if:
			#(domaincontrol is on) OR (fromall is on) OR (!domaincontrol and (fromall or (it was not from a blank envelope sender)))
			if ($optctl{'per_domain'} and !$msginfo{$SN_MID}{'Delivery status'}) {
				if ($domaincontrol or $optctl{'fromall'} or (!$domaincontrol and ($optctl{'fromall'} or ($msginfo{$SN_MID}{'from'} ne 'None')))) {
					my $domain = &striplocal($msginfo{$SN_MID}{'rcpts'}{$rcpt_rid}{'rcpt_name'});
					#collate the count of $pluralname positive email to this recipient
					$statistics{'Per destination domain'}{$domain}{"$pluralname $result"}++;
				}
			}
			#I want per_ entries for this item if:
			#(domaincontrol is on) OR (fromall is on) OR (!domaincontrol and (fromall or (it was not from a blank envelope sender)))
			if ($optctl{'per_rcpt'} and !$msginfo{$SN_MID}{'Delivery status'}) {
				if ($domaincontrol or $optctl{'fromall'} or (!$domaincontrol and ($optctl{'fromall'} or ($msginfo{$SN_MID}{'from'} ne 'None')))) {
					#collate the count of $pluralname positive email to this recipient
					$statistics{'Per destination rcpt'}{lc($msginfo{$SN_MID}{'rcpts'}{$rcpt_rid}{'rcpt_name'})}{"$pluralname $result"}++;
				}
			}
		} #Positive or suspect result

		#Count number of addresses this feature is in use for
		if ($optctl{'seat-count'} and ($icid_init{$msginfo{$SN_MID}{'ICID'}}{'policy'} ne 'RELAY')) {
			$statistics2{'feature_use'}{$section}{lc($msginfo{$SN_MID}{'rcpts'}{$rcpt_rid}{'rcpt_name'})}++;
		}
	} #done iterating for per-rcpt/domain calcs

	if ($fromRegex && ((index $msginfo{$SN_MID}{'from'}, $fromRegex) >= 0)) {
		$statistics{'Searches'}{"Number of $type_res message injections from '$optctl{'from'}'"}++;
		if ($searchspamto_key) { #implicit that 'to' was given
			$statistics{'Searches'}{"Number of $type_res message injections from '$optctl{'from'}' to '$optctl{'to'}'"}++;
		}
	}
	if ($toRegex && $searchspamto_key) {
		$statistics{'Searches'}{"Number of $type_res message injections which had '$optctl{'to'}' in at least 1 rctp address"}++;
	}
	return 1;
} #generic_AVASfunc

#Return a string such as 71.23% based on an inputted decimal value
sub percentize {
	my $percent = $_[0] * 100;
	if ($percent < .010) {
		return '0';
	}
	return sprintf('%.2f', $percent);
}

#Put commas every 3 digits and clip to 2 decimal places
sub commaize {
	my ($num) = @_;
	if (!$num) {
		return 0;
	}
	if ((length($num) < 4) or ($num !~ m/^(\d+)(?:\.\d+)?$/) or (length($1) < 4)) {
		return $num;
	}
	my ($pre_dec, $post_dec) = split(/\./, $num);
	($post_dec and ($post_dec =~ m/^(\d{1,2})/)) ? $post_dec = $1 : $post_dec = 0;
	if ($post_dec) {
		$num = "$pre_dec.$post_dec";
	}
	if ($pre_dec =~ m/\D/) { #Not all digits
		return $num;
	}
	if (length($pre_dec) < 4) {
		return $num;
	}
	my @nums = split('', reverse($pre_dec));
	my $newnum = '';
	my $count = 0;
	foreach my $i (@nums) {
		if ($count++ == 3) {
			$newnum .= ',';
			$count = 1; #1 because I'm putting on a num this round
		}
		$newnum .= $i;
	}
	$newnum = reverse($newnum);
	if ($post_dec) {
		$newnum .= ".$post_dec";
	}
	return ($newnum);
} #commaize

#exitcleanup
#Will be called to clean up temporary files used to preserve memory, and clean up other stuff
# call as &exitcleanup(\%nocleanup, "", 0) to clean up files and not exit
# call as &exitcleanup(\%nocleanup, "foo", 1) to print "foo", clean up files and exit
sub exitcleanup($$) {
	my ($nocleanup, $output, $exitflag) = @_;
	if ($optctl{'debug'}) {
		print STDERR "In exitcleanup\n";
	}
	if ($output and $output =~ m/\w+/) {
		print "$output\n";
	}
	while (my ($type, $name) = each(%tmpfiles)) {
		#close file
		if (defined($tmpfh{$type})) {
			close($tmpfh{$type});
		}
		next if $$nocleanup{$name}; #do not delete these
		#delete file
		if (-e $name) {
			unlink ($name);
		}
	}
	if ($optctl{'sql'}) {
		while (my($table, $file) = each %tmp_sqlfiles) {
#			unlink $file;
		}
	}
	if ($exitflag and $exitflag > 0) {
		exit($exitflag);
	}
} #exitcleanup

sub disclaimer {
	if ((-e '.spamtowho-disclaimer-agreed') and (!$optctl{'support'})) {
		return 1;
	}
	print <<"END";
	***** DISCLAIMER *****
	IRONPORT MAKES NO WARRANTIES, EXPRESS, IMPLIED OR STATUTORY, WITH
	RESPECT TO THIS PACKAGE, INCLUDING WITHOUT LIMITATION ANY IMPLIED
	WARRANTY OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
	NONINFRINGEMENT, OR ARISING FROM COURSE OF PERFORMANCE, DEALING,
	USAGE OR TRADE. IRONPORT DOES NOT PROVIDE ANY SUPPORT SERVICES FOR
	THIS PACKAGE.

	This utility is provided WITHOUT WARRANTY and WITHOUT GUARANTEE of
	any specific utility or exactitude in operation.
	NO SUPPORT of this utility is provided or may be expected regardless
	of implicit or explicit guarantees by any person or contract.
	If any of this is not agreeable to you, you must discontinue use of
	this utility.

	Do you agree to all of the above provisions?
END
	print "\t[y/N] ";
	my $re = <>;
	chomp $re;
	$re = lc($re);
	if ($re ne 'y') {
		exit(0);
	}
	open(FILE, ">.spamtowho-disclaimer-agreed");
	close(FILE);
	return 1;
}

#reference var @files is where it puts all matches
#does not follow symbolic links, only matches regular files not directories
sub findfiles {
	my ($thisdir, $files_aref) = @_;
	return 0 unless((-d $thisdir) and !(-l $thisdir));

	opendir(DIR, "$thisdir");
	my @thesefiles = readdir(DIR);
	closedir(DIR);

	foreach (@thesefiles) {
		#Check for '.' or '..', skip them
		if (($_ eq '.') or ($_ eq '..')) {
			next;
		}

		my $x = File::Spec->catfile($thisdir, $_);
		if (-l $x) {
			return 0;
		}
		elsif (-d $x) {
			print STDERR "searching $x\n" unless $optctl{'quiet'};
			&findfiles("$x", $files_aref);
		}
		elsif (-f $x) {
			push @$files_aref, $x;
		}
		else {
			print STDERR "I don't know what to do with $x?\n";
		}
	}
	return 1;
} #findfiles

sub unknownline {
	my ($linenumber, $funcversion, $fileline_orig, $fileline_here) = @_;
	my $outglobref = *{$tmpfh{'output'}};
	print $outglobref $linenumber."::$funcversion Unhandled entry, please report: \n'$fileline_orig' (mod: '$fileline_here')\n";
	return 0;
}

#Function to centralize this logic, used several places
# - if the -collate-ip flag is given 2 times the desire is to collate-ip
#   based upon the full IP.  Otherwise use a Class-C /24
sub collate_ip_range {
	my ($remoteip) = @_;
	if (!$remoteip) {
		print STDERR "Logic error - remoteip IRT '$fileline_orig' is whack - empty value. Using 0.0.0.0 instead\n";
		$remoteip = '0.0.0.0';
	}
	if ($optctl{'collate-ip'} > 1) { #flag given more than once, means use /32
		return $remoteip;
	}
	if ($remoteip =~ m/^(\d{1,3}\.\d{1,3}\.\d{1,3})/) {
		$remoteip = $1;
	}
	return $remoteip;
} #collate_ip_range

sub make_timingschart {
	my ($section, $time_dur) = @_;
	if ($time_dur < 2) {
		$statistics{$section}{'Time to end of this stage: 0 - 2 seconds'}++;
	}
	elsif ($time_dur < 5) {
		$statistics{$section}{'Time to end of this stage: 2 - 5 seconds'}++;
	}
	elsif ($time_dur < 10) {
		$statistics{$section}{'Time to end of this stage: 5 - 10 seconds'}++;
	}
	elsif ($time_dur < 30) {
		$statistics{$section}{'Time to end of this stage: 10 - 30 seconds'}++;
	}
	elsif ($time_dur < 60) {
		$statistics{$section}{'Time to end of this stage: 30 - 60 seconds'}++;
	}
	elsif ($time_dur < 300) { #5 minutes
		$statistics{$section}{'Time to end of this stage: 60 - 300 seconds'}++;
	}
	else {
		$statistics{$section}{'Time to end of this stage: > 300 seconds'}++;
	}
	return 1;
} #make_timingschart

#Strip local (user) portion of an email address, leaving only *FULL* domain portion
# currently used only for msg-project
sub striplocal {
	my $input = $_[0];
	return '' unless $input =~ m/\@/;
	$input =~ s/^.+\@//; #strip any potential user portions
	$input =~ s/>$//; #strip any potential ending angle brackets
	return lc($input);
}

#May take input in any of these formats, and just return the domain:
#	Randy Mays <randy@randymays.com>
#	"w2csh" <w2csh@comcast.net>
#	tomki@comcast.net
sub whatdomain {
	my ($input) = @_;
	if (!$input or ($input eq '')) {
		print STDERR "$input is '$input' for file line \n\t$fileline_orig\n\t(mod: $fileline)\n";
		return 'error';
	}
	$input =~ s/^.+\@//; #strip any potential user portions
	$input =~ s/>$//; #strip any potential ending angle brackets
	#if there are 3 (or more) parts to this supplied host/domain part
	if ($input =~ m/([\w-]+)\.([\w-]+)\.(\w{2,5})$/) {
		#if the last bit on the name is more than 2 letters (.ru, .ca, .th, etc)
		if (length($3) > 2) {
			return ("$2.$3");
		}
		#Otherwise return 2 previous parts
		return ("$1.$2.$3");
	}
	return $input;
} #whatdomain

sub info_MID {
	my ($fileline) = @_;
	substr $fileline, 0, 4, ''; #strip off 'MID '
	#strip out the MID and put it into $thismid
	our $thismid = int(substr $fileline, 0, int(index $fileline, ' ', 0), '');
	substr $fileline, 0, 1, ''; #strip off leading space
	our $SN_MID = $SN.'-'.$thismid;

	if ($optctl{'interface'}
			and (
				(!$msginfo{$SN_MID} or !$msginfo{$SN_MID}{'ICID'})
				or !grep(/^$icid_init{$msginfo{$SN_MID}{'ICID'}}{'interface'}$/, @{$optctl{'interface'}})
			)) {
		#Looking for specific interface matches and this one isn't in the list
		return 0;
	}
	if ($optctl{'debugmid'} and ($thismid == $optctl{'debugmid'})) {
		print "$fileline\n";
		print Dumper($msginfo{$SN_MID});
		my $foo = <>;
	}

	if (!$msginfo{$SN_MID}) {
		#continue processing if it's a 'From:' line,
		# because it may appear later that it was a 'rewritten' case
		#also continue processing if it's a 'generated based on MID'
		# line, because the new MID appears backwards in that line.
		if (!((index $fileline, 'From: ') >= 0)
				or !((index $fileline, 'generated based on MID ') >= 0)
				or !((index $fileline, 'generated for bounce of MID ') >= 0)) {
			return 0;
		}
		#continue..
	}

	#Fri Jan 29 08:12:00 2004 Info: MID 1 ICID 2 To: <postmaster@corestaff.com> Rejected by RAT
	#Fri Jan 29 08:12:00 2004 Info: MID 2 ICID 7 To: <ggarner@kentelec.com> Rejected by Injection Control
	#Fri Jan 30 07:18:51 2004 Info: MID 5091055 ICID 10292813 RID 0 To: <joe@parade.com>
	#Thu Oct 14 17:27:21 2004 Info: MID 11916996 ICID 7416170 RID 99 To: <chan_swarnakar@yahoo.com>
	#Fri Jan 30 07:18:51 2004 Info: MID 83143152 ICID 0 RID 0 To: <>
	#Fri Jan 30 07:18:52 2004 Info: MID 5091057 ICID 10292815 From: <linda@dataselect.co.u>
	if ((index $fileline, 'ICID ') == 0) {
		substr $fileline, 0, 5, ''; #strip off 'ICID '
		#10292813 RID 0 To: <joe@parade.com>

		#remove ICID # into a var
		my $ICID = int(substr $fileline, 0, (index $fileline, ' '), '');

		#Try to cope with different situations where ICID can be 0
		if (($ICID == 0) and $msginfo{$SN_MID} and ($msginfo{$SN_MID}{'splintered from'} or $msginfo{$SN_MID}{'camefrom_MID'})) {
			$ICID = $msginfo{$SN_MID}{'ICID'};
		}

		if (!defined($icid_init{$ICID})) {
			#stop trying to do stuff with lines where I don't know the ICID
			return 0;
		}
		elsif (($ICID == 0) and !$msginfo{$SN_MID}) {
			#stop trying to do stuff with bounce message log entries
			return 0;
		}
		elsif ((index $fileline, ' RID ') == 0) {
			substr $fileline, 0, 5, ''; #strip off ' RID '
			my $RID = substr $fileline, 0, (index $fileline, ' '), '';
			substr $fileline, 0, 6, ''; #strip off ' To: <'
			my $rcpt = substr $fileline, 0, (index $fileline, '>'), '';
			return &process_to($SN_MID, $rcpt, int($RID), '');
		}
		#2 To: <postmaster@corestaff.com> Rejected by RAT
		#Info: MID 410727821 ICID 643905448 To: <larry_zuccaro@ex.com> Rejected by LDAPACCEPT
		elsif ((index $fileline, ' To: ') == 0) {
			substr $fileline, 0, 6, ''; #strip off ' To: <'
			my $rcpt = substr $fileline, 0, (index $fileline, '>'), '';
			substr $fileline, 0, 2, ''; #now remove leading '> '
			return &process_to($SN_MID, $rcpt, '', $fileline);
		}
		#10292815 From: <linda@dataselect.co.u>
		elsif ((index $fileline, ' From: ') == 0) {
			substr $fileline, 0, 8, ''; #strip off ' From: <'
			chop $fileline; #remove '>'
			return &process_from($SN_MID, int($ICID), $fileline);
		}
		#Fri Jul 21 16:02:40 2006 Info: MID 26603 ICID 125192 invalid bounce, rcpt address <scott@ncironport.net> rejected by bounce verification.
		#Tue Sep 26 08:01:28 2006 Info: MID 12767811 ICID 14967245 invalid bounce, tagging
		elsif ((index $fileline, ' invalid bounce') == 0) {
			if ((index $fileline, ' rejected by bounce verification') > 0) {
				$statistics{'Bounces'}{"Invalid, Rejected by bounce verification on interface $msginfo{$SN_MID}{'interface'}"}++;
			}
			elsif ((index $fileline, ' tagging') > 0) {
				$statistics{'Bounces'}{"Invalid, Tagged by bounce verification on interface $msginfo{$SN_MID}{'interface'}"}++;
			}
			else {
				return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
			}
			return 1;
		}
		else {
			return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
		}
	} #end of section 'MID 1 ICID 1'

	#Interim AV and AS verdicts - positioned here for performance, hopefully
	elsif ((index $fileline, 'interim ') == 0) {
		return 1 unless ($optctl{'interim'});
		substr $fileline, 0, 8, ''; #strip off 'interim '

		#5.0.0 has this entry to support dual-scanning info:
		#MID 164148 interim verdict using engine: CASE spam negative
		#To support interim verdicts for Anti-Spam
		if ((index $fileline, 'verdict using engine: ') == 0) {
			$fileline =~ m/verdict using engine: (\w{4,10})\sspam\s(\w{7,9})\s*(.+?)?$/;
			my $engine = $1;
			my $result = $2;
			#Record the trail of interims for this message
			$msginfo{$SN_MID}{'Anti-Spam interim results'} .= "$engine $result ";

			return &process_AS($SN_MID, $result, "Anti-Spam - $engine");
		} #AS interim
		#Since 5.1.0:
		#Tue Jan 23 19:45:19 2007 Info: MID 408721 interim AV verdict using Sophos CLEAN
		#Tue Jan 23 19:45:19 2007 Info: MID 408721 interim AV verdict using McAfee CLEAN
		#Info: MID 428573 interim AV verdict using Sophos UNSCANNABLE
		elsif ((index $fileline, 'AV verdict using ') == 0) {
			if ($fileline !~ m/verdict using (\w{5,10})\s(\w{5,11})\s*(.+?)?$/) {
				return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
			}
			my $engine = $1;
			my $result = $2;
			my $otherinfo = $3;
			if ($result eq 'CLEAN') {
				$result = 'negative';
			}
			elsif ($result eq 'VIRAL') {
				$result = 'positive';
			}
			elsif ($result eq 'UNSCANNABLE') {
				$result = 'unscannable';
			}
			else {
				$result = lc($result);
				print STDERR "Unknown result from interim AV verdict: $result\n";
			}

			#Record the trail of interims for this message
			$msginfo{$SN_MID}{'Anti-Virus interim results'} .= "$engine $result ";

			return &process_AV($SN_MID, $result, $otherinfo, $engine);
		} #AV interim
		return 1;
	} #interim verdicts

	#3.8.0 gives us:
	#Fri May 14 20:49:30 2004 Info: MID 8 Subject 'test'
	elsif ((index $fileline, 'Subject ') == 0) {
		#Don't bother saving this normally:
		return 0 unless ($optctl{'SBRS-subjects'} or $optctl{'msg-csv'} or $optctl{'tracemail'});
		substr $fileline, 0, 8, ''; #strip off 'Subject '
		$fileline =~ s/^'|'$//g;
		$msginfo{$SN_MID}{'subject'} = $fileline;
		return 1;
	}

	#Tue Jan  6 15:03:18 2004 Info: MID 2 ready 88 bytes from <blah@ironport.com>
	elsif ((index $fileline, 'ready ') == 0) {
		return 0 if ($msginfo{$SN_MID}{'Delivery status'}); #do not track rewritten/generateds
		return &info_MID_ready_bytes($fileline);
	} #end of section 'ready .. bytes'

	#Mon Apr  5 10:23:05 2004 Info: MID 71897 Message-ID '<322n7l$266p@stable.mfg>'
	elsif ((index $fileline, 'Message-ID ') == 0) {
		#forget it unless doing tracemail or msg-csv
		return 0 unless  ($optctl{'msg-csv'} or $optctl{'tracemail'});
		substr $fileline, 0, 11, ''; #strip off 'Message-ID '
		$fileline =~ s/^'|'$//g;
		$msginfo{$SN_MID}{'Message-ID'} = $fileline;
		return 1;
	}
	#Pre 4.5 format:
	#Fri Jan  9 21:06:36 2004 Info: MID 3033 Brightmail positive/negative
	#Wed Aug 18 14:18:11 2004 Info: MID 29266130 Brightmail positive
	elsif ((index $fileline, 'Brightmail ') == 0) {
		substr $fileline, 0, 11, ''; #strip off 'Brightmail '
		my $res = &process_AS($SN_MID, $fileline, 'Brightmail');
		if ($res <= 0) {
			return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
		}
		return $res;
	}

	#4.5 changes to:
	#Info: MID 928 using engine: Brightmail spam negative
	#Info: MID 928 using engine: Cloudmark spam negative
	#Info: MID 11802766 using engine: CASE spam positive
	#Info: MID 7 using engine: CASE spam suspect
	#5.0.0 has:
	#MID 164668 using engine: CASE using cached verdict
	elsif ((index $fileline, 'using engine: ') == 0) {
		substr $fileline, 0, 14, ''; #strip off 'using engine: '
		#get first word - the engine name.  Stripped from $fileline at the same time
		my $engine = substr $fileline, 0, int(index $fileline, ' ', 0), '';
		substr $fileline, 0, 1, ''; #remove leading space
		#Remove up to, including, next ' '
		substr $fileline, 0, ((index $fileline, ' ') + 1), '';
		#Since 'cached verdict' entries are returned also for SBNP CASE scans,
		#I can't really associate this entry with AS.  So ignore for now at least
		if ($fileline eq 'cached verdict') {
			return 0;
		}

		#Collate interims into general statistics
		if ($msginfo{$SN_MID}{'Anti-Spam interim results'}) {
			$statistics{'Anti-Spam interim results'}{$msginfo{$SN_MID}{'Anti-Spam interim results'}}++;
		}

		#set up a per-engine result entry
		$msginfo{$SN_MID}{'AS'}{$engine} = $fileline;

		#Make this the general engine-agnostic verdict, the others all roll into:
		return &process_AS($SN_MID, $fileline, 'Anti-Spam');
	}

	#Sat Feb 14 01:08:08 2004 Info: MID 10281774 antivirus negative
	#Sat Feb 14 01:08:08 2004 Info: MID 10281774 antivirus positive
	#Wed Feb  4 14:49:37 2004 Info: MID 108217 antivirus encrypted
	#Tue Jan 25 09:46:01 2005 Info: MID 199460 antivirus repaired 'W32/Zafi-D'
	#Fri Oct  7 08:27:07 2005 Info: MID 18313686 antivirus positive 'W32/Sober-P' (released from Outbreak)
	# This means that AS scanning is past.. (until WQ rearrangement is done or possible)
	elsif ((index $fileline, 'antivirus ') == 0) {
		if ($fileline !~ m/^antivirus (\w{8,11})\s*(.+?)?$/) {
			return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
		}

		#Collate interims into general statistics
		if ($msginfo{$SN_MID}{'Anti-Virus interim results'}) {
			$statistics{'Anti-Virus interim results'}{$msginfo{$SN_MID}{'Anti-Virus interim results'}}++;
		}

		return &process_AV($SN_MID, $1, $2, '');
	}
	#for 3.7.3+
	#qmail:
	#Tue Apr 27 12:05:29 2004 Info: MID 5911872 RID [0] Response ok 1083092729 qp 3998
	#exchange:
	#Fri May 14 20:49:30 2004 Info: MID 9 RID [0] Response 2.6.0 <DIABLO8k69RKLpgTFur00000086@diablo.ironportsystems.com> Queued mail for delivery
	elsif ((index $fileline, 'RID ') == 0) {
		return 1;
	}
	#Fri May 14 20:49:30 2004 Info: MID 9 queued for delivery
	elsif ($fileline eq 'queued for delivery') {
		return 1;
	}
	#4.0.0+:
	#Fri Aug 27 00:12:25 2004 Info: MID 58 was split creating MID 60 due to a per-recipient policy tcamp
	elsif ((index $fileline, 'was split creating MID ') == 0) {
		substr $fileline, 0, 23, ''; #strip off 'was split creating MID '
		my $newMID = int(substr $fileline, 0, (index $fileline, ' '), '');
		my $newSN_MID = $SN.'-'.$newMID;
		substr $fileline, 0, (index $fileline, ' policy ') + 8, ''; #strip up to policy name
		my $splintering_policy = $fileline;

		#1. generate the new MID setup
		#2. will need to indicate splintered' or similar in original MID,
		#    for recipients that show up in the new one.
		$msginfo{$newSN_MID}{'MID'} = $newMID;
		$msginfo{$newSN_MID}{'size'} = $msginfo{$SN_MID}{'size'};
		$msginfo{$newSN_MID}{'SBRS'} = $msginfo{$SN_MID}{'SBRS'};
		$msginfo{$SN_MID}{'splinters made'}++;

		#Stick this MID with the same ICID of the original, tho in the mail_log it's shown as 0
		$msginfo{$newSN_MID}{'ICID'} = $msginfo{$SN_MID}{'ICID'};
		$icid_init{$msginfo{$newSN_MID}{'ICID'}}{'MIDs'}{$newMID} = 1;
		$msginfo{$newSN_MID}{'splintered from'} = $thismid;
		$msginfo{$newSN_MID}{'starttimestamp'} = $linetimestamp; #set start time to this line's
		$msginfo{$newSN_MID}{'interface'} = $msginfo{$SN_MID}{'interface'};
		$msginfo{$newSN_MID}{'remoteip'} = $msginfo{$SN_MID}{'remoteip'};
		$msginfo{$newSN_MID}{'sendergroup'} = $msginfo{$SN_MID}{'sendergroup'};
		$msginfo{$newSN_MID}{'policy'} = $msginfo{$SN_MID}{'policy'};
		$msginfo{$newSN_MID}{'directionality'} = $msginfo{$SN_MID}{'directionality'};
		#put in a val for collate-ip here, but do not collate on splits
		if ($msginfo{$SN_MID}{'collate-ip'}) {
			$msginfo{$newSN_MID}{'collate-ip'} = $msginfo{$SN_MID}{'collate-ip'};
		}
		$msginfo{$newSN_MID}{'PRSA'} = $splintering_policy;
		#$statistics{'Policy matches'}{"for some rcpts on $fileline"}++;
		#becomes:
		$statistics{'Policy matches'}{$fileline}{'Splinters'}++;
		$statistics{'Policy matches'}{$fileline}{'messages'}++;
#No way of knowing how many recipients are here...  process later on as the ICID 0 'To's are seen?

		#Count up splintered messages as a full new message
		return &info_MID_ready_bytes("ready $msginfo{$newSN_MID}{'size'} fake from splintering!");

		return 1;
	}
	#4.0.0+:
	#MID ~1~ matched all recipients for per-recipient policy ~2~
	elsif ((index $fileline, 'matched all recipients for per-recipient policy ') == 0) {
		substr $fileline, 0, (index $fileline, ' policy ') + 8, ''; #strip up to policy name
		#$statistics{'Policy matches'}{"for all rcpts on $fileline"}++;
		#becomes:
		$statistics{'Policy matches'}{$fileline}{'Whole'}++;
		$statistics{'Policy matches'}{$fileline}{'messages'}++;
		$statistics{'Policy matches'}{$fileline}{'recipients'} += $msginfo{$SN_MID}{'rcpt_count'};
		$msginfo{$SN_MID}{'PRSA'} = $fileline;
		return 1;
	}
	#4.5.0+:
	#Info: MID 84463820 IncomingRelay(mxip10): Header Received found, ip 211.74.204.34 being used
	#format_text='MID $mid IncomingRelay($name): Header $header found, ip $ip being used'
	#MID $mid IncomingRelay($name): Header $header not found
	#MID $mid IncomingRelay($name): Could not find valid IP address in header
	#4.6.0+:
	#MID 19319 IncomingRelay(PureMessage): Header Received found, IP 84.40.178.131 being used, SBRS -4.6
	elsif ((index $fileline, 'IncomingRelay') == 0) {
		substr $fileline, 0, 14, ''; #strip 'Incomingrelay(
		my $name = substr $fileline, 0, (index $fileline, ')'), '';
		substr $fileline, 0, 3, ''; #strip '): '
		if ((index $fileline, 'Header') == 0) {
			substr $fileline, 0, 7, ''; #strip 'Header '
			my $header = substr $fileline, 0, (index $fileline, ' '), '';
			substr $fileline, 0, 1, ''; #strip ' '
			if ((index $fileline, 'found') == 0) {
				$statistics{'IncomingRelay'}{"success: $name, header $header"}++;
			}
			elsif ((index $fileline, 'not found') == 0) {
				$statistics{'IncomingRelay'}{"failed: $name, header $header"}++;
			}
			else {
				#err
				return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
			}

			#Try to backfill connection type data from here
			my $ICID = $msginfo{$SN_MID}{'ICID'};
			my $oldip = $msginfo{$SN_MID}{'remoteip'};
			my $newip;
			my $newcollate_ip;
			my $old_collate_ip = $msginfo{$SN_MID}{'collate-ip'};
			if ($fileline =~ m/IP (\S+) being used/) {
				$newip = $1;
				if ($newip eq $oldip) {
					#detected relay from self?
					return 0;
				}
				$newcollate_ip = &collate_ip_range($newip);
				$icid_init{$ICID}{'remoteip'} = $newip;
				$icid_init{$ICID}{'collate-ip'} = $newcollate_ip;
				$msginfo{$SN_MID}{'remoteip'} = $newip;
				$msginfo{$SN_MID}{'collate-ip'} = $newcollate_ip;
			}
			if ($fileline =~ m/SBRS (\S+)/) {
				my $score = $1;
				#falsify the score for this ICID
				$icid_init{$ICID}{'score'} = $score;
				#decrement whatever the score was before identification of the real SBRS:
				$statistics{'SBRS'}{$msginfo{$SN_MID}{'SBRS'}}{'Conns'}--;
				$statistics{'SBRS'}{$msginfo{$SN_MID}{'SBRS'}}{'MsgBgn'}--;
				#set it to what it is now, retroactively note that a connection with this score began
				$statistics{'SBRS'}{$score}{'Conns'}++;
				#retroactively note that a message with this score began
				$statistics{'SBRS'}{$score}{'MsgBgn'}++;
				#etc
				$msginfo{$SN_MID}{'SBRS'} = $score;
				if ($optctl{'collate-ip'}) {
					#count number of messages per IP/Class
					$collate_ip{$icid_init{$ICID}{'collate-ip'}} = \%{$collate_ip{$old_collate_ip}};
					$collate_ip{$icid_init{$ICID}{'collate-ip'}}{2} = "$score";
				}

				if ($optctl{'timeperiods'}) {
					my $int_score = ($score =~ m/(-?\d{1,2})\.\d{1,2}$/)?$1:$score;
					&collate_timeperiods("SBRS", $int_score);
				}

				$statistics{' Notes'}{'This program has retroactively set SBRS scores for messages and connections based upon IncomingRelay detection.'} = ' ';
			}
		} #Header found
		elsif ((index $fileline, 'Could not find valid') == 0) {
			$statistics{'IncomingRelay'}{"$fileline"}++;
		}
		else {
			#err
			return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
		}
		return 1;
	} #IncomingRelay

	#bug 12952
	#Tue Jan  6 15:03:18 2004 Info: MID 2 rewritten to 3 by antispam
	#Tue Apr  5 17:34:20 2005 Info: MID 35381452 rewritten to 35381453 by antivirus
	#3.8.0:
	#Fri May 14 20:44:43 2004 Info: MID 6 rewritten to 7 by alt-rcpt-to-filter filter 'testfilt'
	#Tue May  3 06:07:03 2005 Info: MID 424576592 rewritten to 424576594 by antivirus(unsafe alt-rcpt-to) filter 'unknown'
	#Thu Aug 17 00:55:23 2006 Info: MID 1 rewritten to MID 2 by antispam (alt-rcpt-to) filter 'unknown'
	#Thing about the add-footer filter is that it doesn't compress the recipients!
	#Info: MID 386736 rewritten to MID 386737 by add-footer filter 'Footer Stamping'
	#Info: MID 419747 rewritten to MID 419761 by drop-attachments-by-filetype filter 'Block_Attachments'
	elsif ((index $fileline, 'rewritten to ') == 0) {
		substr $fileline, 0, 13, ''; #strip off 'rewritten to '
		#bug 12952 - missing 'MID' fixed in 4.5.0?
		if ($fileline =~ m/^(?:MID )?(\d+) by (.+)$/) {
			return &process_rewrite($SN, $SN_MID, $thismid, int($1), $2);
		}
		else {
			return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
		}
	}
	#4.0.0+
	#MID ~1~ was bounced by policy ~2~ in the ~3~ table
	elsif ((index $fileline, 'was bounced by policy ') == 0) {
		substr $fileline, 0, 22, ''; #strip off before policy name
		my $policy = substr $fileline, 0, (index $fileline, ' in the '), '';
		substr $fileline, 0, 8, ''; #strip off before table name
		my $table = substr $fileline, 0, (index $fileline, ' table'), '';
		$statistics{'Policy bounces'}{"$policy $table"}++;
		#no recipients will be delivered if the MID is bounced
		foreach (keys %{$msginfo{$SN_MID}{'rcpts'}}) {
			my $rid = int($_);
			#fill out the resolution if it isn't there
			next if $msginfo{$SN_MID}{'rcpts'}{$rid}{'resolution'};
			$msginfo{$SN_MID}{'rcpts'}{$rid}{'resolution'} = "bounced by $policy";
			$msginfo{$SN_MID}{'finalized_rcpts'}++;
		}
		return 1;
	}
	#4.0.0+
	#MID ~1~ was dropped by policy ~2~ in the ~3~ table
	elsif ((index $fileline, 'was dropped by policy ') == 0) {
		substr $fileline, 0, 22, ''; #strip off before policy name
		my $policy = substr $fileline, 0, (index $fileline, ' in the '), '';
		substr $fileline, 0, 8, ''; #strip off before table name
		my $table = substr $fileline, 0, (index $fileline, ' table'), '';
		$statistics{'Policy drops'}{"$policy $table"}++;
		#no recipients will be delivered if the MID is dropped
		foreach (keys %{$msginfo{$SN_MID}{'rcpts'}}) {
			my $rid = int($_);
			#fill out the resolution if it isn't there
			next if $msginfo{$SN_MID}{'rcpts'}{$rid}{'resolution'};
			$msginfo{$SN_MID}{'rcpts'}{$rid}{'resolution'} = "dropped by $policy";
			$msginfo{$SN_MID}{'finalized_rcpts'}++;
		}
		return 1;
	}
	#4.0.0+
	#MID ~1~ could not be split
	elsif ((index $fileline, 'could not be split') == 0) {
		$statistics{'could not be split'}{$thismid} = 1;
		return 1;
	}
	#4.0.0+
	#Wed Aug 25 23:23:13 2004 Info: MID 43 quarantined to "Policy"
	#Mon May  2 12:50:34 2005 Info: MID 423370831 quarantined to "Outbreak" (VOF rule:.pif file in zip)
	#MID ~2~ quarantined to "~3~" (~1~:~4~)
	elsif ((index $fileline, 'quarantined to ') == 0) {
		substr $fileline, 0, 16, ''; #strip off before quarantine name
		my $quar_name = substr $fileline, 0, (index $fileline, '" '), '';
		substr $fileline, 0, 2, ''; #strip '" '
		$statistics{'Quarantines'}{"$quar_name - Messages in $fileline"}++;

		if (!$msginfo{$SN_MID}) {
			return 0;
		}
		$statistics{'Quarantines'}{"$quar_name - bytes in"} += $msginfo{$SN_MID}{'size'};
		if (not defined $msginfo{$SN_MID}{'size'}) {
			print STDERR "size not defined for MID $SN_MID\n";
			exit(0);
		}
		return 1;
	}
	#Thu Nov  2 04:59:40 2006 Info: MID 2 masquerading header 'To' from '"Peterson,  Sus
	#Tue Mar 15 13:58:30 2005 Info: MID 1 masquerading envelope sender from 'TOMKI' to 'tomki@masqueraded.com'
	#Tue Mar 15 13:58:30 2005 Info: MID 1 masquerading header 'To' from 'TCAMP' to 'TCAMP@masqueraded.com'
	#masquerading header 'Cc' from '<Stephen_B@Ex.com>,\r 'Cc' from '<Stephen_B@Ex.com>,
	#To, Cc, Reply-to, From can appear
	elsif ((index $fileline, 'masquerading ') == 0) {
		if ($fileline =~ m/^masquerading envelope sender from '(.+)?'? to '(.+)'?/) {
			$statistics{'Masqueraded'}{'Envelope Sender'}++;
			#TKI - should do something for tracemail here.
		}
		#Catch instances of stuff like:
		#Thu Dec 29 00:06:36 2005 Info: MID 20332097 masquerading header 'Cc' from '<Stephen_B@Ex.com>,^M
		#        <foo@tm.net.my>,^M
		#        <joe@Exchange.ex.com>' to '<Stephen_B@Ex.com>,^M
		#        <foo@tm.net.my>,^M
		#        <joe@ex.com>'
		elsif ($fileline =~ m/^masquerading header '(.+)?' from '.+?>,\r/) {
			$statistics{'Masqueraded'}{$1}++;
			$statistics{'Masqueraded'}{'badly formatted data in logs'}++;
		}
		elsif ($fileline =~ m/^masquerading header '(.+)?' from '(.+)?'? to '(.+)'?/) {
			$statistics{'Masqueraded'}{$1}++;
		}
		elsif ($fileline =~ m/^masquerading header '(.+)?' from '(.+)?'?/) {
			#looks like a broken line?
			$statistics{'Masqueraded'}{$1}++;
			$statistics{'Masqueraded'}{'badly formatted data in logs'}++;
		}
		else {
			return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
		}
		return 1;
	} #end of 'masquerading' section
	#4.0.0
	#Info: MID 422464642 released from quarantine "Outbreak" (expired)
	#format_text='MID $mid deleted from quarantine "$name" ($reason) t=$time'
	#Info: MID 9735 released (attachments stripped) from quarantine "Outbreak" (queue full) t=190
	#format_text='MID $mid released (attachments stripped) from quarantine "$name" ($reason) t=$time'
	elsif (((index $fileline, 'released from quarantine ') == 0) or ((index $fileline, 'released (attachments stripped) from quarantine ') == 0)) {
		substr $fileline, 0, (index $fileline, 'ine "') + 5, ''; #strip off before quarantine name
		my $quar_name = substr $fileline, 0, (index $fileline, '" '), '';
		substr $fileline, 0, 3, ''; #strip '" ('
		my $reason = substr $fileline, 0, (index $fileline, ") "), '';

		$statistics{'Quarantines'}{"$quar_name - Messages out"}++;
		$statistics{'Quarantines'}{"$quar_name - released $reason"}++;
		if (!$msginfo{$SN_MID}) { #not found in tracking
			return 0;
		}
		$statistics{'Quarantines'}{"$quar_name - bytes out"} += $msginfo{$SN_MID}{'size'};
		return 1;
	}
	#4.0.0
	#Wed Aug 25 23:25:41 2004 Info: MID 43 deleted from quarantine "Policy" (manual)
	#Fri Apr  8 16:48:07 2005 Info: MID 134 deleted from quarantine "Policy" (expired)
	#4.5.0 format_text='MID $mid deleted from quarantine "$name" ($reason) t=$time'
	elsif ((index $fileline, 'deleted from quarantine ') == 0) {
		substr $fileline, 0, (index $fileline, 'ine "') + 5, ''; #strip off before quarantine name
		my $quar_name = substr $fileline, 0, (index $fileline, '" '), '';
		substr $fileline, 0, 3, ''; #strip '" ('
		my $reason = substr $fileline, 0, (index $fileline, ") "), '';

		$statistics{'Quarantines'}{"$quar_name - Messages deleted ($reason)"}++;
		if (!$msginfo{$SN_MID}) { #not found in tracking
			return 0;
		}
		$statistics{'Quarantines'}{"$quar_name - bytes deleted"} += $msginfo{$SN_MID}{'size'};

		return 1;
	}
	#4.0.0
	#Wed Aug 25 23:25:41 2004 Info: MID 43 deleted from all quarantines
	#4.5.0 format_text='MID $mid $what from all quarantines'
	#Info: MID 7729 released (attachments stripped) from all quarantines
	elsif (((index $fileline, 'deleted from all quarantines') == 0)
			or ((index $fileline, 'released from all quarantines') == 0)
			or ((index $fileline, 'released (attachments stripped) from all quarantines') == 0)) {
		return 1;
	}

	#Info: MID 1960958 was dropped by content filter 'dontsend' in the inbound table
	#Info: MID 1960959 was bounced by content filter 'bounceme' in the inbound table
	#I have an itch to point out that this should be of the same format as:
	#Fri Jun 18 12:58:19 2004 Info: Message aborted MID 346002679 Dropped by filter 'FileType'
	#filed as bug 12951
	#fixed in 4.5.0 by bcottrell to be:
	#PERRCPT_FILTER_DROPPED: 'Message aborted MID ~1~ Dropped by content filter ~2~ in the ~3~ table',
	#PERRCPT_FILTER_BOUNCED: 'Message aborted MID ~1~ Bounced by content filter ~2~ in the ~3~ table',
	elsif (((index $fileline, 'was ') == 0) and ((index $fileline, 'by content filter ') > 5)) {
		if ($fileline !~ m/was ((\S+) by content filter '(.+?)' in the (.+?) table)/) {
			return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
		}
		my $data = $1;
		my $action = $2;
		my $filtername = $3;
		my $table = $4;
		$statistics{'Filter Actions'}{"$data"}++;
		#no recipients will be delivered if the MID is aborted
		foreach (keys %{$msginfo{$SN_MID}{'rcpts'}}) {
			my $rid = int($_);
			#fill out the resolution if it isn't there
			next if $msginfo{$SN_MID}{'rcpts'}{$rid}{'resolution'};
			$msginfo{$SN_MID}{'rcpts'}{$rid}{'resolution'} = "$action by $filtername";
			$msginfo{$SN_MID}{'finalized_rcpts'}++;
		}
		$statistics{'Aborts'}{"$table $action - content filter $filtername"}++;
		$statistics{'Filter Actions'}{"$table $action - content filter $filtername"}++;

		#This is the last seen, get it out of memory
		&deletestuff($SN_MID);
		return 1;
	}
	#3.8.3?
	#Tue Oct 19 20:47:37 2004 Info: MID 15216898 generated for bounce of MID 8785588
	#ENQUEUE_BOUNCE_MID: 'MID ~2~ generated for bounce of MID ~1~',
	#enqueue_ancillary_mid
	#Tue Apr  5 17:41:50 2005 Info: MID 35381767 generated based on MID 35381766 by bcc-scan filter 'testsrbs'
	#Tue Jun  1 20:02:16 2004 Info: MID 14 generated based on MID 13 by bcc filter 'nonetest'
	#Tue Oct 19 20:49:20 2004 Info: MID 15220406 generated based on MID 15220404 by notify filter 'Return_From_Trend'
	#bug 26921 fixed in 5.0.0 gives us:
	#Info: MID 1665 was generated based on MID 1664 by antivirus
	#It is because of this backwards ordering of new MID vs old MID
	# that I need to not disregard processing of mids I have not yet
	# seen 'Start'.
	#I think this is a logging bug.
	#bug 12953
	#4.5 has:
	#Info: MID 515 was generated for bounce of MID 511
	elsif (((index $fileline, 'was generated ') == 0) or ((index $fileline, 'generated ') == 0)) {
#Leave this as a warning for later.. when I don't remember whaaaa?
# -- cannot dump out here because this could be the first time this MID is seen.
#  - this seems fixed in at least 4.6.0+
#				if (!defined($msginfo{$SN_MID})) {
#					#unknown MID - likely near beginning of log processing
#					return 0;
#				}
#However I should skip processing mostly if I have not seen oldmid before, will do so below
		my $oldmid = 0;
		my $reason = '';
		my $extra = ''; #only used by filter name?
		if ((index $fileline, 'was ') == 0) {
			substr $fileline, 0, 4, ''; #strip 'was '
			#this appears to be the only addition to this line in 4.5.0
		}
		if ((index $fileline, 'generated for bounce of MID ') == 0) {
			$statistics{'Bounces'}{'Generated'}++;
			if ($fileline =~ m/^generated for bounce of MID (\d+)$/) {
				$oldmid = int($1);
			}
			$reason = 'generated bounce';
			$msginfo{$SN_MID}{'notes'} .= "$reason";
		}
		elsif ((index $fileline, 'generated based on MID ') == 0) {
			if ($fileline =~ m/^generated based on MID (\d+) by (.+) filter (.+)$/) {
				$oldmid = int($1);
				$statistics{'Filter Actions'}{"$2 generated by $3"}++;
				$extra = "[$3]";
				$reason = $2;
			}
			elsif ($fileline =~ m/^generated based on MID (\d+) by antivirus$/) {
				$oldmid = int($1);
				$reason = "copied by AV policy";
				$extra = "[antivirus]";
			}
			else {
				return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
			}
		}
		else {
			return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
		}
		#old MID is $oldmid here - new MID is in $SN_MID
		if (!$msginfo{"$SN-$oldmid"}) {
			#the old mid was never set up - don't do anything with this one
			return 0;
		}

		#Start a new msginfo entry for the new message
		$msginfo{$SN_MID}{'from'} = '';
		#Set the msginfo Delivery status to act as a flag against
		# double or just unnecearry and problematic data collation.
		$msginfo{$SN_MID}{'Delivery status'} = 'generated message';
		$msginfo{$SN_MID}{'camefrom_MID'} = $msginfo{$SN.'-'.$oldmid}{'MID'};
		$msginfo{$SN_MID}{'SBRS'} = 'system';
		if (!$msginfo{$SN.'-'.$oldmid}{'ICID'}) {
			if ($msginfo{$SN.'-'.$oldmid}{'ICID'} == 0) {
				$msginfo{$SN_MID}{'ICID'} = 0;
			}
			else {
				#This is the case which really shouldn't happen
				$msginfo{$SN_MID}{'ICID'} = 'unknown';
			}
		}

		#filter actions section (not yet present) should have this?
		return 1;
	} #end of Info: MID ~1~ generated section

	#DomainKeys!
	#Signing, 4.5.0+

	#4.2. Verifier Logging [NOT FOR PALMS/4.5.0]
	#MID <mid> bad record format <Sender:/From:> <sender address>
	#MID <mid> domain mismatch <Sender:/From:> <sender address>
	#MID <mid> no key <Sender:/From:> <sender address>
	#MID <mid> no signature <Sender:/From:> <sender address>
	#MID <mid> query timeout, deferred <Sender:/From:> <sender address>
	#MID <mid> query timeout, failed verify <Sender:/From:> <sender address>
	#MID <mid> verified bad <Sender:/From:> <sender address>
	#MID <mid> verified good <Sender:/From:> <sender address>
	#MID <mid> wrong key type <Sender:/From:> <sender address>
#THIS IS NOT CURRENTLY CORRECT OR FINISHED - 4-26-2005
	elsif ((index $fileline, 'DomainKeys: ') == 0) {
		substr $fileline, 0, 12, ''; #strip off 'DomainKeys: '

		#Signing
		#DK_SIGN_MSG_SIGN: 'MID ~1~ DomainKeys: signing with ~2~ - matches ~3~'
		if ((index $fileline, 'signing with ') == 0) {
			$fileline =~ m/signing with (.+) - matches .+$/;
			$statistics{'DomainKeys'}{"signed with $1"}++;
			#A value of 1 indicates a try, and success.
			#A value of 0 indicates a try, and failure.
			#If the attribute doesn't exist it wasn't attempted
			$msginfo{$SN_MID}{'DK'}{'signing success'} = 1;
			$msginfo{$SN_MID}{'DK'}{'signed with'} = $1;
		}
		#DK_SIGN_MSG_RESIGN: 'MID ~1~ DomainKeys: resigning - Sender header added after existing signature'
		elsif ($fileline eq 'resigning - Sender header added after existing signature') {
			$statistics{'DomainKeys'}{'resigning - Sender header added after existing signature'}++;
			$msginfo{$SN_MID}{'DK'}{'signing success'} = 1;
		}
		#DK_SIGN_MSG_NO_ALREADY_SIGNED: 'MID ~1~ DomainKeys: cannot sign - already signed'
		elsif ($fileline eq 'cannot sign - already signed') {
			$statistics{'DomainKeys'}{'cannot sign - already signed'}++;
			#treat this as success for the sake of statistical counting
			$msginfo{$SN_MID}{'DK'}{'signing success'} = 1;
		}
		#DK_SIGN_MSG_NO_ADDRESS: 'MID ~1~ DomainKeys: cannot sign - no identifiable sending address'
		elsif ($fileline eq 'cannot sign - no identifiable sending address') {
			$statistics{'DomainKeys'}{'cannot sign - no identifiable sending address'}++;
			$msginfo{$SN_MID}{'DK'}{'signing success'} = 0;
		}
		#DK_SIGN_MSG_NO_PROFILE: 'MID ~1~ DomainKeys: cannot sign - no profile matches ~2~'
		#Info: MID 20332107 DomainKeys: cannot sign - no profile matches foey_you@Blah.com
		elsif ((index $fileline, 'cannot sign - no profile matches ') == 0) {
			$statistics{'DomainKeys'}{'cannot sign - no profile matches'}++;
			$msginfo{$SN_MID}{'DK'}{'signing success'} = 0;
		}
		#DK_SIGN_MSG_NO_SKEY_NONE: 'MID ~1~ DomainKeys: cannot sign - no signing key specified for profile ~2~'
		elsif ((index $fileline, 'cannot sign - no signing key specified for profile') == 0) {
			$statistics{'DomainKeys'}{'cannot sign - no signing key specified for profile'}++;
			$msginfo{$SN_MID}{'DK'}{'signing success'} = 0;
		}
		#DK_SIGN_MSG_NO_SKEY_MISSING: 'MID ~1~ DomainKeys: cannot sign - profile ~2~ signing key ~3~ does not exist'
		elsif ((index $fileline, 'cannot sign - profile ') == 0) {
			$statistics{'DomainKeys'}{'cannot sign - signing key does not exist for profile'}++;
			$msginfo{$SN_MID}{'DK'}{'signing success'} = 0;
		}
		#DK_SIGN_MSG_NO_SKEY_INCOMPLETE: 'MID ~1~ DomainKeys: cannot sign - signing key ~2~ is missing key data'
		elsif ((index $fileline, 'cannot sign - signing key') == 0) {
			$statistics{'DomainKeys'}{'cannot sign - signing key is missing key data'}++;
			$msginfo{$SN_MID}{'DK'}{'signing success'} = 0;
		}
		elsif ((index $fileline, 'attempting to re-sign') == 0) {
			$statistics{'DomainKeys'}{$fileline}++;
		}
		else {
			return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
		}
		return 1;
	} #end of DomainKeys: section
	#4.5.0:
	#Info: MID 824 was too big (455698/120000) for scanning by BRIGHTMAIL
	#Info: MID 821 was too big (455520/262144) for scanning by VOF
	elsif ((index $fileline, 'was too big (') == 0) {
		substr $fileline, 0, ((index $fileline, ' by ') + 4), ''; #strip off all the way to the type
		my $section = 'Anti-Spam - Brightmail';
		my $subsection = ' by Brightmail';
		if ($fileline eq 'BRIGHTMAIL') {
			#this is the default just defined above
		}
		elsif ($fileline eq 'CASE') {
			$section = 'Anti-Spam - CASE';
			$subsection = ' by CASE';
		}
		elsif ($fileline eq 'VOF') {
			$section = 'VOF';
			$subsection = '';
		}
		elsif ($fileline =~ m/CLOUDMARK/i) {
			$section = 'Anti-Spam - Cloudmark';
			$subsection = ' by Cloudmark';
		}
		else {
			print STDERR "New 'was too big' case: $fileline_orig (mod: '$fileline')\n";
			return 0;
		}
		$statistics{$section}{"Messages which were too big for scanning$subsection (res will be negative)"}++;
		return 1;
	}
	#Mon Oct  3 13:42:21 2005 Info: MID 198579961 Could not convert character set: 136
	elsif ((index $fileline, 'Could not convert character set: ') == 0) {
		return 1; #begin ignoring this as of .234
		#$fileline =~ m/Could not convert character set: (.+)/;
		#$statistics{'Could not convert character set'}{$1}++;
		#return 1;
	}
	#4.5.0 gives this entry, I don't know what it is for:
	#Info: MID 9733 attachment types rartn
	elsif ((index $fileline, 'attachment types ') == 0) {
		return 1;
	}
	#from bug 13763, these are new in 4.5.0:
	#Tue Apr 27 12:05:16 2004 Info: MID 4195162 to [0] pending till Tue Apr 27 13:05:17 2004 [Default]
	#Tue Jan  6 15:07:12 2004 Info: MID 1232089 to RID [0] pending till Wed May 26 14:58:26 2004
	#Info: MID 154 to RID [0] pending till Wed Jul 20 10:15:41 2005 [Default]
	elsif ((index $fileline, ' pending till') > 9) {
		return 1;
	}
	#Info: MID 9731 Virus Threat Level=3
	elsif ((index $fileline, 'Virus Threat Level') == 0) {
		return 1;
	}
	#Fri Oct  7 03:05:11 2005 Info: MID 18313985 quarantine "Outbreak" new reason (VOF rule:OUTBREAK_0000231)
	elsif ((index $fileline, 'quarantine "') == 0) {
		if ($fileline =~ m/VOF rule:(.+)\)/) {
			$statistics{'VOF'}{"Messages requarantined due to rule $1"}++;
			return 1;
		}
		else {
			return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
		}
	}
	# Tue Jan 13 12:39:32 2004 Info: MID 68615 From: <> To: <blah2@ironport.com>, ... 1 total recipients
	#4.6.0:
	#Thu Dec  8 14:23:54 2005 Info: MID 4422 From: <me@ironport.com> To: <ironPort@tomki.com>, ... 1 total recipients
	#This is the case where the system independently generates mail
	# to send to those listed in alertconfig. (or supportrequest/scheduled report?)
	#This is the first instance of this MID in use.
	# No message size or ICID will be recorded.
	elsif (((index $fileline, 'From: <') == 0)
			and ((index $fileline, '...') > 0)
			and ((index $fileline, 'total recipients') > 0)) {
		return 1;
	}
	#Info: MID 85 Global unsubscribe matched entry foo@ RID 0 Address foo@domain0.qa Action bounced
	elsif ((index $fileline, 'Global unsubscribe matched entry ') == 0) {
		return 1;
	}
	#Tue Sep  5 10:11:38 2006 Info: MID 428274923 CASE sent a poorly formatted response: <<garbage>>...
	elsif ((index $fileline, 'CASE sent a poorly formatted response:') == 0) {
		$statistics{'uninteresting? log entries'}{'CASE sent a poorly formatted response'}++;
		return 1;
	}
	else {
		return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
	}
	return 1;
} #info_MID


#Wed Jun  2 14:58:14 2004 Info: New SMTP ICID 244315254 interface ausc60ps305.us.ex.com (143.166.148.150) address 217.238.244.89 reverse dns host pd9eef459.dip.t-dialin.net verified yes
sub info_New_SMTP {
	my ($fileline) = @_;
	substr $fileline, 0, 9, ''; #strip 'New SMTP '
	if ((index $fileline, 'ICID') == 0) {
		substr $fileline, 0, 5, ''; #strip 'ICID '
		my $ICID = int(substr $fileline, 0, (index $fileline, ' '), '');
		substr $fileline, 0, 11, ''; #strip ' interface '

		my $interface = substr ($fileline, 0, (index $fileline, ' '), '') || '-----BLANK INTERFACE NAME-----';
		$icid_init{$ICID}{'interface'} = $interface;
		if ($optctl{'interface'} and !grep(/^$interface$/, @{$optctl{'interface'}})) {
			#Looking for specific interface matches and this one isn't in the list
			return 0;
		}

		substr $fileline, 0, (index $fileline, ' address ') + 9, ''; #strip up past ' address '
		$icid_init{$ICID}{'remoteip'} = substr $fileline, 0, (index $fileline, ' '), '';

		$icid_init{$ICID}{'remotehost'} = 'unknown'; #default
		my $host = 'unknown';
		#record hostname of the incoming connection
		substr $fileline, 0, 18, ''; #strip ' reverse dns host '
		$host = substr $fileline, 0, (index $fileline, ' '), '';
		$icid_init{$ICID}{'remotehost'} = $host;

		if ($optctl{'collate-ip'}) {
			#get data for the $statistics{'IP addresses that connected'} section

			#count number of messages per IP or IP range
			my $collate_ip = &collate_ip_range($icid_init{$ICID}{'remoteip'});
			$icid_init{$ICID}{'collate-ip'} = $collate_ip;

			#Have we seen this IP at all, yet?
			##1 is the IP seen-count,
			##2 is the SBRS (put in at another location)
			##3 is the # of completed message injections from this IP
			##4 is the # of AS-scanned from this IP
			##5 is the # of AS-positives from this IP
			##6 is the # of AV-positives from this IP
			##7 is the # of max concurrent connections from this IP
			##8 is the # of *current* concurrent connections from this IP
			#   - used to help calculate #7
			##9 is the # of rejected recipients
			##10 is the resolved remote hostname, if /32 collate is in use
			if (!$collate_ip{$collate_ip}) {
				#make sure that there is a linkage from $statistics{'IP addresses that connected'} to $collate_ip
				$statistics{"IP addresses that connected (distinct $optctl{'collate-ip-class'}s)"} = \%collate_ip;
				$collate_ip{" Unique $optctl{'collate-ip-class'}s"}++;
				#make the sbrs unknown as blank by default
				#it is only populated if the verbose logging line is on.  (< asyncos 4.5)
				$collate_ip{$collate_ip}{2} = '';
				#make the # of message injections 0 by default
				$collate_ip{$collate_ip}{3} = 0;
				#make the # of AS-scanned 0 by default
				$collate_ip{$collate_ip}{4} = 0;
				#make the # of AS-positives 0 by default
				$collate_ip{$collate_ip}{5} = 0;
				#make the # of AV-positives 0 by default
				$collate_ip{$collate_ip}{6} = 0;
				#make the max # of concurrent connections 1 by default
				$collate_ip{$collate_ip}{7} = 1;
				#make the # of rejected recipients 0 by default
				$collate_ip{$collate_ip}{9} = 0;
			}
			#How many times did this IP connect?
			$collate_ip{$collate_ip}{1}++;
			#Increment current # of concurrent connections from this IP
			$collate_ip{$collate_ip}{8}++;
			#How many distinct IP addresses connected?
			$collate_ip{' Unique connections'}++;
			if (($optctl{'collate-ip'} > 1) ) {
				if ($collate_ip{$collate_ip}{10}
						and ($collate_ip{$collate_ip}{10} ne $host)
						and ($collate_ip{$collate_ip}{10} ne 'unknown')
						and ($host ne 'unknown')) {
					$statistics{'DNS switching'}{"$collate_ip was $collate_ip{$collate_ip}{10}, became $host"}++;
				}
				#don't overwrite with 'unknown' or same:
				if (!$collate_ip{$collate_ip}{10} or (($collate_ip{$collate_ip}{10} ne $host) and ($host ne 'unknown'))) {
					$collate_ip{$collate_ip}{10} = $host;
				}
			}
		} #if collate-ip

		#Not yet doing this:
		if ($optctl{'collate-host'}) {
			#For hostnames with > 3 sections, keep only 3, prepended by the .
			#unless the addr is in the format stuff.sfo.ironport.com.uk
			# in which case we'll allow 4
			#This code is similar to the whatdomain function..
			if ($host =~ m/^(?:[\w-]+)(\.[\w-]+\.[\w-]+\.[\w-]{2,3}\.\w{2})$/) {
				$host = $1;
			}
			elsif ($host =~ m/^(?:[\w-]+)(\.[\w-]+\.[\w-]+\.\w+)$/) {
				$host = $1;
			}
			$icid_init{$ICID}{'remotehost'} = $host;
		}

		$icid_init{$ICID}{'starttime'} = $linetimestamp;
		if ($optctl{'timings'}) {
			$icid_init{$ICID}{'time_begin'} = $linetimeepoch;
		}
		#otherwise keep on truckin, collate for all interfaces
		$statistics{'Connections in'}{"On interface $interface"}++;
		$statistics{'Connections in'}{' Total Initiated'}++;
	} #end of 'New SMTP ICID
	#Mon Jan 23 16:55:42 2006 Info: New SMTP DCID 1 interface 172.19.0.21 address 72.14.205.27 port 25
	elsif ((index $fileline, 'DCID') == 0) {
		substr $fileline, 0, (index $fileline, 'interface ') + 10, '';
		my $interface = substr ($fileline, 0, (index $fileline, ' address '), '') || '-----BLANK INTERFACE NAME-----';
		#In 4.6.0 and greater, all that's left in $fileline now should be the remote port #

		$statistics{'Connections out (delivery)'}{"On interface '$interface'"}++;
		$statistics{'Connections out (delivery)'}{' Total Initiated'}++;
	}
	else {
		return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
	}
	return 1;
} #info_New_SMTP


sub info_ICID {
	my ($fileline) = @_;
	substr $fileline, 0, 5, ''; #remove 'ICID '
	#strip ICID into a var, leaving $fileline w/the rest:
	my $ICID = int(substr $fileline, 0, (index $fileline, ' '), '');
	#I could 'return 0 unless $icid_init{$ICID};' here.
	#However I don't necessarily want to do that, due to some other general
	#stat counting that can be done with these lines
	substr $fileline, 0, 1, ''; #remove remaining ' '
	#ICID \d+ has been stripped off

	#check to see if my search is interface-limited
	if ($optctl{'interface'} and (!$icid_init{$ICID} or !grep(/^$icid_init{$ICID}{'interface'}$/, @{$optctl{'interface'}}))) {
		#Looking for specific interface matches and this one isn't in the list
		return 0 unless $icid_init{$ICID};
#Tki - note: if inserting into SQL might want to forbid limiting the input collected
		&deleteicid($ICID);
		return 1;
	}
	#Fri Jan 30 08:18:20 2004 Info: ICID 10304588 close
	if ($fileline eq 'close') {
		return 0 unless $icid_init{$ICID};
		$icid_init{$ICID}{'closed'} = 1;
		#This is the case where I need to identify message inputs
		# which never got to the 'ready' stage - they can be removed from memory
		if ($icid_init{$ICID}{'MIDs'} and ((scalar keys %{$icid_init{$ICID}{'MIDs'}}) > 0)) {
			foreach my $keyMID (keys %{$icid_init{$ICID}{'MIDs'}}) {
				my $SN_MID = $SN.'-'.$keyMID;
				#size is determined at the 'ready' stage
				if (defined($msginfo{$SN_MID}) && !defined($msginfo{$SN_MID}{'size'})) {
					if ($msginfo{$SN_MID}{'rcpts'}) {
						foreach (keys %{$msginfo{$SN_MID}{'rcpts'}}) {
							my $rid = int($_);
							#fill out the resolution if it isn't there
							next unless $msginfo{$SN_MID}{'rcpts'}{$rid}{'resolution'};
							$msginfo{$SN_MID}{'rcpts'}{$rid}{'resolution'} = 'lost on ICID close';
							$msginfo{$SN_MID}{'finalized_rcpts'}++;
						}
					}
					&deletestuff($SN_MID);
				}
			}
		}
		if ($optctl{'timings'}) {
			my $icid_conn_time = $linetimeepoch - $icid_init{$ICID}{'time_begin'};
			if ((!$statistics{'Connections in'}{'Longest connection (time)'})
				|| ($icid_conn_time > $statistics{'Connections in'}{'Longest connection (time)'})) {
				$statistics{'Connections in'}{'Longest connection (time)'} = $icid_conn_time;
				$statistics{'Connections in'}{'Longest connection (IP)'} = $icid_init{$ICID}{'remoteip'};
			}
			&make_timingschart('Connections in', $icid_conn_time);
		}

		#If current # of connections from this IP is greater
		#than the previously recorded max, move it into the max slot:
		if ($optctl{'collate-ip'}) {
			my $remoteip = $icid_init{$ICID}{'collate-ip'};
			#not present if icid started in previous log file
			#-icid_init is partially populated in 'Start MID' section
			# which is why the logic reaches here at all
			if ($collate_ip{$remoteip}{8} > $collate_ip{$remoteip}{7}) {
				$collate_ip{$remoteip}{7} = $collate_ip{$remoteip}{8};
			}
			#decrement current # of connections from this IP:
			$collate_ip{$remoteip}{8}--;
		}
		#Do not delete the icid_init here unless all relevant MIDs are done and handled
		# - info needed is needed by message objects still undergoing processing
		if ((scalar keys %{$icid_init{$ICID}{'MIDs'}}) == 0) {
			if ($icid_init{$ICID}{'msgs injected'}) {
				$statistics{'Connections in'}{' Which injected messages'}++;
			}
			else {
				$statistics{'Connections in'}{' Which did not inject messages'}++;
			}
			&deleteicid($ICID);
		}
		return 1;
	} #ICID - fileline eq 'close'
	#Handle the expanded line for SBRS
	#Info: ICID 282194765 REJECT SG BLACKLIST match sbrs[-10.0:-2.0] SBRS -9.9
	#Info: ICID 0 TCPREFUSE SG BLACKLIST match sbrs[-10.0:-0.5] SBRS -9.9
	#Info: ICID 0 TCPREFUSE SG RBLBlacklist match dnslist[sbl-xbl.spamhaus.org] SBRS None
	#ICID 1793844420 REJECT SG Internal_Dell_Non-IronPort match 143.166.0.0/16 SBRS None
	#Tue Aug  9 09:55:42 2005 Info: ICID 2 REJECT SG None match  SBRS None
	#4.5 fixes the blank match 'match  ' case, bug 17464, now we get some lines w/o 'match':
	#Tue Feb 22 19:26:25 2005 Info: ICID 3 ACCEPT SG None SBRS rfc1918
	#4.5.0 has:
	#Info: ICID 21591 ACCEPT SG None match  SBRS unable to retrieve
	#ACCEPT SG SUSPECTLIST match sbrs[none] SBRS unable to retrieve
	elsif (((index $fileline, ' SG ') > 1) and ((index $fileline, ' SBRS ') > 6)) {
		return 0 unless $icid_init{$ICID};
		$fileline =~ m/^(\w{1,40}) SG (\S{1,40}) (match .{1,100}?)?\s?SBRS (.{3,18})$/;
		my $policy = $1;
		my $sendergroup = $2;
		my $hatmatch = '';
		my $score = $4;
		if ($3) {
			$hatmatch = $3;
			substr $hatmatch, 0, 6, ''; #remove 'match '
			if ($hatmatch =~ m/\w/) {
				my $matchtext = '';
				#Identify the type of thing matched
				if ((index $hatmatch, 'sbrs') == 0) {
					$matchtext = 'SBRS';
				}
				elsif ((index $hatmatch, 'dnslist') == 0) {
					$matchtext = 'DNSlist';
				}
				elsif ($hatmatch =~ m/^\d{1,3}\./) { #beginning of an IP addr
					$matchtext = 'IP';
				}
				elsif ($hatmatch eq 'ALL') {
					$matchtext = 'ALL (default)';
				}
				elsif ($hatmatch =~ m/^\.?[\w-]{1,80}\./) { #beginning of a domain name
					$matchtext = 'Domain';
				}
				elsif ((index $hatmatch, 'sbo') == 0) {
					$matchtext = 'SB Org ID';
				}
				else {
					$matchtext = 'Other';
				}
				$statistics{'HAT match types'}{"$matchtext - $policy policy"}++;
			}
		}
		$icid_init{$ICID}{'hatmatch'} = $hatmatch;

		$icid_init{$ICID}{'policy'} = $policy;
		if ($policy !~ m/RELAY/i) {
			$icid_init{$ICID}{'directionality'} = 'Incoming';
		}
		else {
			$icid_init{$ICID}{'directionality'} = 'Outgoing';
		}

		#Check for the sql hash ref knowing about this
		if ($optctl{'sql'} and !$sql_data{'policy'}{$policy}) {
			&policy_sql($policy);
		}
		$icid_init{$ICID}{'sendergroup'} = $sendergroup;
		#Check for the sql hash ref knowing about this
		if ($optctl{'sql'} and !$sql_data{'sendergroup'}{$sendergroup}) {
			&sendergroup_sql($sendergroup);
		}
		$icid_init{$ICID}{'score'} = $score;

		$has_items{$SN}{"verbose log $policy"} = 1;
		$has_items{$SN}{$hatmatch} = 1 unless ($hatmatch eq '');
		$statistics{'HAT Policies'}{"~Total $policy"}++;
		$statistics{'HAT Policies'}{"$sendergroup $policy"}++;

		#make the incrementation of scores when the new message begins
		$statistics{'SBRS'}{$score}{'Conns'}++;
		if ($optctl{'collate-ip'}) {
			#count number of messages per IP/Class
			$collate_ip{$icid_init{$ICID}{'collate-ip'}}{2} = "$score";
		}

		if ($optctl{'timeperiods'}) {
			my $int_score = ($score =~ m/(-?\d{1,2})\.\d{1,2}$/)?$1:$score;
			&collate_timeperiods('SBRS', $int_score);
			&collate_timeperiods('HAT Policy', $policy);
		}

		return 1;
	} #verbose SBRS and SG log entry
	elsif ($fileline eq 'lost') {
		#if an ICID is lost, associated messages are either done or won't be done
		#this could happen when the message is already in, or not in.
		$statistics{'Connections in'}{'lost'}++;
		return -1;
	}
	#format_text='ICID $icid Invalid sender address: $error $invalid_part'
	#Info: ICID 493829828 Invalid sender address: Unsupported domain literal: '[]'
	elsif ((index $fileline, 'Invalid sender address: ') == 0) { #4.5.0
		$fileline =~ m/^(Invalid sender address: .+?):\s+'/;
		$statistics{'Address Parser'}{'Invalid sender address'}++;
		return 1;
	}
	#Info: ICID 3 MID 1 Invalid recipient address: Invalid character in address: '!'
	#Info: ICID 493771866 MID 340448731 Invalid recipient address:  'RCPT TO:<>'
	#important: if the data has a ' in it, the enclosure may be "":
	#Info: ICID 6 MID 9 Invalid recipient address:  "RCPT TO: <Albert Cater (acater@magma.ca) <acater@magma.ca>; Albert Cater (awc_ccc@hotmail.com) <awc_ccc@hotmail.com>; 'cspence2@mts.net' <cspence2@mts.net>; Dave Mackie (dmackie@digistar.mb.ca) <dmackie@digist>"

	elsif ((index $fileline, 'Invalid recipient address: ') >= 5) { #4.5.0
		$fileline =~ m/MID \d+ (.+?):\s+/;
		$statistics{'Address Parser'}{$1}++;
		return 1;
	}
	#4.5.0:
	#Mon Aug 15 15:38:19 2005 Info: ICID 3 disconnected address 10.1.1.101, no messages injected within timeout period
	#also:
	#ICID $icid disconnected address ${ip}, exceeded allowable connection time
	elsif ((index $fileline, 'disconnected address ') == 0) {
		#strip off all before ', ' + 2 chars
		substr $fileline, 0, (index $fileline, ', ') + 2, '';
		$statistics{'Connections in'}{$fileline}++;
		return 1;
	}
	#CONNECTION_LOST_BEFORE_CMD
	#4.5.0 format (same as before, basically):
	#format_text='ICID $icid Connection from $ip on interface $interface ($interface_ip) lost after $seconds seconds (DNS query took $dns_seconds seconds), before any commands were received',
	#Tue Oct  4 13:21:23 2005 Info: ICID 30308138 Connection from 216.39.115.138 on interface PublicNet (202.123.2.25) lost after 139 seconds (DNS query took 139 seconds), before any commands were received
	elsif ((index $fileline, 'Connection from ') == 0) {
		if ($fileline =~ m/lost after \d+ seconds \(DNS query took/) {
			$statistics{'DNS query timeout, connection lost'}++;
		}
		else {
			return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
		}
		return 1;
	}
	elsif ((index $fileline, 'Bad syntax for command: ') == 0) {
		$statistics{'Connections in'}{'Bad syntax for command'}++;
		return 1;
	}
	#ICID ~1~ Unknown command: ~2~
	#This occurs when someone/thing issues stuff into SMTP that is not a valid SMTP command;
	#most common reason is that it doesn't realize it's not in DATA session.
	elsif ((index $fileline, 'Unknown command: ') == 0) {
		$statistics{'Connections in'}{'Unknown command'}++;
		return 1;
	}
	# ICID ~1~ Address: ~2~ sender allowed, envelope sender matched domain exception
	#Info: ICID 4 Address: <foo@barf.com> sender rejected, envelope sender domain does not exist
	#Info: ICID 9 Address: <blah@fleag.com> sender rejected, envelope sender domain could not be resolved
	elsif ((index $fileline, 'Address: ') == 0) {
		substr $fileline, 0, (index $fileline, '> ') + 2, '';
		$statistics{'Sender Verification'}{$fileline}++;
		return 1;
	}
	#Info: ICID 623143 TLS success protocol TLSv1/SSLv3 cipher DHE-RSA-AES256-SHA
	#ICID 27389415 TLS success protocol TLSv1/SSLv3 cipher DHE-RSA-AES256-SHA
	#Older versions have only: (pre 5.0.0?)
	#ICID 27389415 TLS success
	elsif ((index $fileline, 'TLS ') == 0) {
		return 0 unless (defined($icid_init{$ICID}) and defined($icid_init{$ICID}{'remotehost'}));
		my $remote = &whatdomain($icid_init{$ICID}{'remotehost'});
		if ($remote eq 'unknown') {
			$remote .= " - $icid_init{$ICID}{'remoteip'}";
		}
		substr $fileline, 0, 4, ''; #strip 'TLS '
		$fileline =~ m/^(\w+)( (protocol .+) cipher .+)?$/;
		if ($2) { #Longer entry available
			$statistics{'Connections in'}{"TLS $1 $2"}++;
		}
		else {
			$statistics{'Connections in'}{"TLS $1"}++;
		}
		$statistics{'TLS in'}{sprintf "%25s\t%-60s", $remote, $fileline}++;
		return 1;
	}
	#For 4.6.0,
	# Bug 22469 was filed with the subject "Some Receiving Failed log messages need MID relevance"
	#Receiving Failed: Message loop
	elsif ((index $fileline, 'Receiving Failed: ') == 0) {
		$statistics{'Connections in'}{$fileline}++;
		return 0 unless $icid_init{$ICID};

		substr $fileline, 0, 18, ''; #remove 'Receiving Failed: '
		#Receiving Failed messages which ARE NOT relevant to a MID:
		if ($fileline =~ m/^(?:Protocol)|(?:Queue)|(?:Memory)|(?:Connection limit)|(?:Resources Low)/) {
			#this is already collated above for connections
			return 1;
		}
		elsif (($fileline eq 'Message size exceeds limit') or ($fileline eq 'Too Many Messages')) {
			$statistics{'Messages'}{"Rejected because '$fileline'"}++;
			return 1;
		}

		return 1 unless defined $icid_init{$ICID}{'MIDs'};
		#Receiving Failed messages which ARE relevant to a MID should get here..
		my $thisfrom = $msginfo{$SN.'-'.(sort keys %{$icid_init{$ICID}{'MIDs'}})[-1]}{'from'};
		if ($optctl{'collate-from'}) {
			$statistics{'Envelope From addresses which at least began sending mail'}{$thisfrom}{'Receiving Failed'}++;
		}
		if ($optctl{'collate-domain'}) {
			$statistics{'Envelope From domains which at least began sending mail'}{&whatdomain($thisfrom)}{'Receiving Failed'}++;
		}
		return 1;
	} #Receiving Failed
	else {
		return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
	}
	return 1;
} #info_ICID


sub info_Message {
	my ($fileline) = @_;
	#Thu Mar  4 08:38:41 2004 Info: Message done DCID 570107 MID 3605203 to [0] [('X-SBRS', 'BadRep -9.4')]
	#Fri Jun 18 11:13:39 2004 Info: Message done DCID 6193797 MID 345766720 to RID [0] [('X-SBRS', '3.5')]
	#Info: Message done DCID 55306 MID 797710 to [0]
	#This one entry can indicate delivery success to one or multiple end rcpts
	# over 1 SMTP connection to the remote server.
	#NOTE: this entry is NOT the last log entry for this MID
	if ((index $fileline, 'Message done DCID ') == 0) {
		substr $fileline, 0, 18, ''; #strip 'Message done DCID '
		my $DCID = int(substr $fileline, 0, (index $fileline, ' '), '');
		substr $fileline, 0, 5, ''; #strip ' MID '
		my $MID = int(substr $fileline, 0, (index $fileline, ' '), '');
		my $SN_MID = $SN.'-'.$MID;
		substr $fileline, 0, (index $fileline, '[') + 1, ''; #strip all up to (including) the '['
		my $ridstring = substr $fileline, 0, (index $fileline, ']'), '';

		if (not $msginfo{$SN_MID}) {
			return 0;
		}
		if (!$msginfo{$SN_MID}{'size'} or ($msginfo{$SN_MID}{'size'} == 1)) {
			#unknown size of delivery
		}
		else {
			$statistics{'Sizes'}{'Total bytes sent'} += $msginfo{$SN_MID}{'size'};
			#Possibly add another size chart here
		}
		foreach (split /,\s?/, $ridstring) {
			my $rid = int($_);
			$msginfo{$SN_MID}{'delivered_rcpts'}++;
			#not the same, one tracks deliveries, the other can do bounces as well
			$msginfo{$SN_MID}{'rcpts'}{$rid}{'resolution'} = 'delivered';
			$msginfo{$SN_MID}{'rcpts'}{$rid}{'deliverytime'} = $linetimestamp;
			$msginfo{$SN_MID}{'finalized_rcpts'}++;
			$statistics{'Recipients'}{'sent'}++;
		}
		$statistics{'Messages'}{'sent'}++;

		#Attempt to keep track of bytes delivered internally/Incoming for -per_domain purposes
		if (($optctl{'per_domain'} or $optctl{'per_rcpt'}) and $msginfo{$SN_MID}{'directionality'} and ($msginfo{$SN_MID}{'directionality'} eq 'Incoming')) {
			my @rids = split /,\s?/, $ridstring;
			#just use the first one to count bytes delivery:
			if ($optctl{'per_domain'}) {
				my $domain = &striplocal($msginfo{$SN_MID}{'rcpts'}{$rids[0]}{'rcpt_name'});
				$statistics{'Per destination domain'}{$domain}{'bytes delivered'} += ($msginfo{$SN_MID}{'size'} || 0);
			}
			foreach my $rid (@rids) {
				my $rcpt = $msginfo{$SN_MID}{'rcpts'}{$rids[0]}{'rcpt_name'};
				if ($optctl{'per_domain'}) {
					my $domain = &striplocal($rcpt);
					$statistics{'Per destination domain'}{$domain}{'rcpts out'}++;
				}
				if ($optctl{'per_rcpt'}) {
					$statistics{'Per destination rcpt'}{$rcpt}{'rcpts out'}++;
					$statistics{'Per destination rcpt'}{$rcpt}{'bytes delivered'} += ($msginfo{$SN_MID}{'size'} || 0);
				}
			}
		}

		#Now I can look at extra headers logged here
		#Currently I'm only doing this to catch 'Domainkey-Signature', 'DKIM-Signature', 'From' headers
		#	for a statistical analysis project
		#  if that use-need changes the last condition here should be removed/changed
		#Wed Mar  8 10:22:32 2006 Info: Message done DCID 329979 MID 16106944 to RID [0] [('X-IronPort-Anti-Spam-Result', 'AQAAAMQfDEQJ'), ('from', '"w2csh" <w2csh@comcast.net>'), ('x-sbrs', '0.0'), ('domainkey-signature', 'blah')]
		#Fri Jun  1 23:09:16 2007 Info: Message done DCID 475670127 MID 947395125 to RID [0] [('from', '"Amy Phillips" <midlandThoth\'s@moscowmail.com>')]
		if ($optctl{'msg-project'} and (index $fileline, '] [') == 0) {
			my @loggedheaders = split /\), \(/, $fileline;
			foreach my $logged (@loggedheaders) {
				if ($logged =~ m/'From', '(.+)>/i) {
					$msginfo{$SN_MID}{'header:from'} = &striplocal($1) . ',';
				}
				elsif ($logged =~ m/'Domainkey-Signature', '(.+)'/i) {
					$msginfo{$SN_MID}{'header:domainkey-signature'} .= $1 . ',';
				}
				elsif ($logged =~ m/'DKIM-Signature', '(.+)'/i) {
					$msginfo{$SN_MID}{'header:dkim-signature'} .= $1 . ',';
				}
				elsif ($logged =~ m/'Sender', '(.+)>/i) {
					$msginfo{$SN_MID}{'header:sender'} .= &striplocal($1) . ',';
				}
				elsif ($logged =~ m/'Resent-From', '(.+)>/i) {
					$msginfo{$SN_MID}{'header:resent-from'} .= &striplocal($1) . ',';
				}
				elsif ($logged =~ m/'Resent-Sender', '(.+)>/i) {
					$msginfo{$SN_MID}{'header:resent-sender'} .= &striplocal($1) . ',';
				}
				#else - this is not a header I'm interested in
			}
			foreach my $logged ('from', 'domainkey-signature', 'dkim-signature', 'sender', 'resent-from', 'resent-sender') {
				if (defined($msginfo{$SN_MID}{"header:$logged"})) {
					chop $msginfo{$SN_MID}{"header:$logged"}; #remove trailing comma
				}
			}
		}
		return 1;
	} #end of section 'Message done DCID '

	#this is in 3.8.2+
	#Tue Apr 27 12:05:16 2004 Info: Message finished MID 1648122665 done
	#This is the last log entry for each MID
	elsif ((index $fileline, 'Message finished MID ') == 0) {
		substr $fileline, 0, 21, ''; #strip 'Message finished MID '
		my $MID = int(substr $fileline, 0, (index $fileline, ' '), '');
		substr $fileline, 0, 1, ''; #strip ' '
		#$fileline can be 'done', 'aborted', ...

		my $SN_MID = $SN.'-'.$MID;
		my $state = $fileline;
		if (!$msginfo{$SN_MID}) {
			if ($optctl{'debug'}) {
				#print "skipping line from previous file, msg begin unseen or del'd already:\n\t$fileline_orig\n";
			}
			return 0;
		}
		$msginfo{$SN_MID}{'endtime'} = $linetimeepoch;
		#Do recipients will be delivered if the MID was aborted for some reason
		# so I'll mark all recipients as finalized at this point
		#Of additional complication in 4.0.0 is that a MID
		# could be finalized when all of the recipients are accounted for by splinters.
		$msginfo{$SN_MID}{'finalized_rcpts'} = $msginfo{$SN_MID}{'rcpt_count'};

		#This is the last seen, get it out of memory
		&deletestuff($SN_MID);
		return 1;
	} #end of section "Message finished MID"
	#Sat Feb 14 01:16:30 2004 Info: Message aborted MID 10288257 Receiving aborted
	#Wed Jun  2 15:04:13 2004 Info: Message aborted MID 179637280 Dropped by Brightmail
	#Fri Jun 18 12:58:19 2004 Info: Message aborted MID 346002679 Dropped by filter 'FileType'
	#A60:
	#Fri Jun 11 09:43:50 2004 Info: Message aborted MID 1548 Injection aborted
	#in 4.5+: (bug 12951)
	#PERRCPT_FILTER_DROPPED: 'Message aborted MID ~1~ Dropped by content filter ~2~ in the ~3~ table',
	#PERRCPT_FILTER_BOUNCED: 'Message aborted MID ~1~ Bounced by content filter ~2~ in the ~3~ table',
	#Bug 31170 filed against the fact that this line (Bounced by filter) can come after the 'Message finished' line
	# fixed in 5.1.0
	elsif ((index $fileline, 'Message aborted MID ') == 0) {
		substr $fileline, 0, 20, ''; #strip 'Message aborted MID '
		my $MID = int(substr $fileline, 0, (index $fileline, ' '), '');
		substr $fileline, 0, 1, ''; #strip ' '
		my $SN_MID = $SN.'-'.$MID;
		my $data = $fileline; #everything after the MID
		if (!$msginfo{$SN_MID}) {
			return 0;
		}

		#no recipients will be delivered if the MID is aborted
		#set all rcpts to aborted
		if ((scalar keys %{$msginfo{$SN_MID}{'rcpts'}}) > 0) {
			foreach (keys %{$msginfo{$SN_MID}{'rcpts'}}) {
				my $rid = int($_);
				next if $msginfo{$SN_MID}{'rcpts'}{$rid}{'resolution'};
				$msginfo{$SN_MID}{'rcpts'}{$rid}{'resolution'} = "$data";
				$msginfo{$SN_MID}{'finalized_rcpts'}++;
			}
		}

		$statistics{'Aborts'}{$data}++;
		if ((index $data, 'filter') >= 0) {
			$statistics{'Filter Actions'}{$data}++;
		}
		return 1;
	} #end of Message aborted MID section
	#Nothing for this yet (ever?):
	#bug 13763 fixed in 4.5.0-505:
	#Tue Apr 27 12:05:16 2004 Info: Message 4195162 to [0] pending till Tue Apr 27 13:05:17 2004 [Default]
	#Tue Jan  6 15:07:12 2004 Info: Message 1232089 to RID [0] pending till Wed May 26 14:58:26 2004
	elsif ((index $fileline, ' pending till') > 17) {
	}
	else {
		return &unknownline(__LINE__, $funcVERSION, $fileline_orig, $fileline);
	}
	return 1;
} #info_Message


sub info_Start_MID {
	my ($fileline) = @_;
	substr $fileline, 0, 10, ''; #strip 'Start MID '
	my $MID = int(substr $fileline, 0, (index $fileline, ' '), '');
	substr $fileline, 0, 6, ''; #strip ' ICID '
	#Fri Nov 17 06:00:31 2006 Info: Start MID 9 ICID 0 (ISQ Notification)
	if ((index $fileline, '(ISQ ') > 0) {
		#ignore these
		return 1;
		#$fileline =~ s/\s.+$//; #strip from ' ' o#
		#though at this point this ICID is always 0, will it always be?
	}
	my $ICID = int($fileline);
	if ($ICID == 0) {
		#ignore generated messages?
		# - can't really..  this can be a bcc-filter message too
		#return 1;
	}
	#If the ICID is not 0 but I didn't get the icid_init, it's an old injection - ignore
	elsif (($ICID != 0) and !$icid_init{$ICID}) {
		return 1;
	}

	my $SN_MID = $SN.'-'.$MID;
	#ICID might have been populated already if this message got 'generated'
	if ($msginfo{$SN_MID} and $msginfo{$SN_MID}{'ICID'}) {
		$ICID = $msginfo{$SN_MID}{'ICID'};
	}
	#if we're looking for stuff from a particular interface
	# and we either don't know what interface this connection
	# was on, or this connection was on a different interface,
	# ignore the data
	if ($optctl{'interface'} and (!$icid_init{$ICID} or !grep(/^$icid_init{$ICID}{'interface'}$/, @{$optctl{'interface'}}))) {
		#Looking for specific interface matches and this one isn't in the list
		return 0;
	}
	#if both of these are unknown, set them to 'Unknown ..'
	if (!$icid_init{$ICID} and !$msginfo{$SN_MID}) {
		#this will mean that it's a generated bounce, right??
		#Because generated bounces do not have this line
		#Such as:
		#Tue Aug  9 10:28:55 2005 Info: MID 11 generated for bounce of MID 8
		#Tue Aug  9 10:28:55 2005 Info: Start MID 11 ICID 0
		#Can also mean it's something like a bcc-generated message

		$statistics{'Messages'}{'System-generated'}++;

		#Populate icid_init for some uses
		$icid_init{$ICID}{'interface'} = 'generated on-system';
		$icid_init{$ICID}{'remoteip'} = 'generated on-system';
		$icid_init{$ICID}{'MIDs'}{$MID} = 1;
		$msginfo{$SN_MID}{'interface'} = 'generated on-system';
		$msginfo{$SN_MID}{'remoteip'} = 'generated on-system';
		if ($optctl{'collate-ip'}) {
			$collate_ip{'generated on-system'}{1} = 1;
		}
		$icid_init{$ICID}{'starttime'} = $linetimestamp;
		if ($optctl{'timings'}) {
			#wanna do timings but this MID is seen without the ICID having been seen;
			#assume the ICID-in timestamp is the same as this start MID timestamp.
			$icid_init{$ICID}{'time_begin'} = $linetimeepoch;
		}
		#Default to outgoing for this case's directionality:
		$msginfo{$SN_MID}{'directionality'} = 'outgoing';
	}
	else {
		$msginfo{$SN_MID}{'interface'} = $icid_init{$ICID}{'interface'};
		$msginfo{$SN_MID}{'remoteip'} = $icid_init{$ICID}{'remoteip'};
		$msginfo{$SN_MID}{'sendergroup'} = $icid_init{$ICID}{'sendergroup'};
		$msginfo{$SN_MID}{'policy'} = $icid_init{$ICID}{'policy'};
		$msginfo{$SN_MID}{'directionality'} = $icid_init{$ICID}{'directionality'};;
		if ($icid_init{$ICID}{'collate-ip'}) {
			$msginfo{$SN_MID}{'collate-ip'} = $icid_init{$ICID}{'collate-ip'};
		}
	}
	#set a default message size in case it isn't seen later.
	#Typically we only care about this when we see a 'Start MID' from a quarantine release,
	#start state for the MID with its original size is lost in space.
	$msginfo{$SN_MID}{'size'} = 1;
	$msginfo{$SN_MID}{'starttime'} = $linetimeepoch;

	#Normal indication of new message start?
	#the 'unless' cases are abnormal - indicate I knew of this MID before the Start MID
	# - or that happens with rewrites
	if (!$msginfo{$SN_MID}{'from'} and ($ICID != 0)) {
		$statistics{'Messages'}{'Deliveries Begun Inbound'}++;
	}
	#increment SBRS scores seen - multiple messages per ICID will count
	if (($ICID != 0) and ($icid_init{$ICID}{'score'})) {
		$statistics{'SBRS'}{$icid_init{$ICID}{'score'}}{'MsgBgn'}++;
		$msginfo{$SN_MID}{'SBRS'} = $icid_init{$ICID}{'score'};
	}
	$msginfo{$SN_MID}{'MID'} = $MID;
	$msginfo{$SN_MID}{'ICID'} = $ICID;
	$icid_init{$ICID}{'MIDs'}{$MID} = 1;

	$msginfo{$SN_MID}{'from'} = 'None' unless $msginfo{$SN_MID}{'from'};
	$msginfo{$SN_MID}{'starttimestamp'} = $linetimestamp;
	return 1;
} #info_Start_MID


sub info_MID_ready_bytes {
	my ($fileline) = @_;
	if (!defined($msginfo{$SN_MID}{'rcpt_count'})) {
		#If recipient domains are being limited (-mydomain, 'domain' file),
		# there may be no rcpts here, just delete the message object, force
		return &deletestuff($SN_MID, 1);
	}

	substr $fileline, 0, 6, ''; #strip off 'ready '
	my $bytes = int(substr $fileline, 0, (index $fileline, ' '), '');

	$icid_init{$msginfo{$SN_MID}{'ICID'}}{'msgs injected'}++;

	#count by groupings of 10KB increment
#				$bytemark = 10240 * (int($bytes/10240) + 1);
#				$statistics2{'Sizes'}{$bytemark}{'bytes'} += $bytes;
#				$statistics2{'Sizes'}{$bytemark}{'count'}++;

	#This is for generation of a general message sizes table
	#copied this general format from Evan
	#Allow this to be used for splintered messages as the most common and useful
	# application of this data is to determine hwo many messages at what sizes have
	# to be processed by the system..  avg message size processed is much more
	# important than avg message size received
	if ($bytes <= 5120) { #5KB
		$statistics{'Sizes'}{'0B - 5KB'}{'bytes'} += $bytes;
		$statistics{'Sizes'}{'0B - 5KB'}{'count'}++;
	}
	elsif ($bytes <= 10240) { #10KB
		$statistics{'Sizes'}{'5KB - 10KB'}{'bytes'} += $bytes;
		$statistics{'Sizes'}{'5KB - 10KB'}{'count'}++;
	}
	elsif ($bytes <= 15360) { #15KB
		$statistics{'Sizes'}{'10KB - 15KB'}{'bytes'} += $bytes;
		$statistics{'Sizes'}{'10KB - 15KB'}{'count'}++;
	}
	elsif ($bytes <= 20480) { #20KB
		$statistics{'Sizes'}{'15KB - 20KB'}{'bytes'} += $bytes;
		$statistics{'Sizes'}{'15KB - 20KB'}{'count'}++;
	}
	elsif ($bytes <= 32768) { #32KB
		$statistics{'Sizes'}{'20KB - 32KB'}{'bytes'} += $bytes;
		$statistics{'Sizes'}{'20KB - 32KB'}{'count'}++;
	}
	elsif ($bytes <= 65536) { #64KB
		$statistics{'Sizes'}{'32KB - 64KB'}{'bytes'} += $bytes;
		$statistics{'Sizes'}{'32KB - 64KB'}{'count'}++;
	}
	elsif ($bytes <= 98304) { #96KB
		$statistics{'Sizes'}{'64KB - 96KB'}{'bytes'} += $bytes;
		$statistics{'Sizes'}{'64KB - 96KB'}{'count'}++;
	}
	elsif ($bytes <= 131072) { #128KB
		$statistics{'Sizes'}{'96KB - 128KB'}{'bytes'} += $bytes;
		$statistics{'Sizes'}{'96KB - 128KB'}{'count'}++;
	}
	elsif ($bytes <= 524288) { #512KB
		$statistics{'Sizes'}{'128KB - 512KB'}{'bytes'} += $bytes;
		$statistics{'Sizes'}{'128KB - 512KB'}{'count'}++;
	}
	elsif ($bytes <= 1048576) { #1MB
		$statistics{'Sizes'}{'512KB - 1024KB'}{'bytes'} += $bytes;
		$statistics{'Sizes'}{'512KB - 1024KB'}{'count'}++;
	}
	elsif ($bytes <= 5242880) { #5MB
		$statistics{'Sizes'}{'1MB - 5MB'}{'bytes'} += $bytes;
		$statistics{'Sizes'}{'1MB - 5MB'}{'count'}++;
	}
	elsif ($bytes <= 10485760) { #10MB
		$statistics{'Sizes'}{'5MB - 10MB'}{'bytes'} += $bytes;
		$statistics{'Sizes'}{'5MB - 10MB'}{'count'}++;
	}
	elsif ($bytes <= 20971520) { #20MB
		$statistics{'Sizes'}{'10MB - 20MB'}{'bytes'} += $bytes;
		$statistics{'Sizes'}{'10MB - 20MB'}{'count'}++;
	}
	elsif ($bytes <= 31457280) { #30MB
		$statistics{'Sizes'}{'20MB - 30MB'}{'bytes'} += $bytes;
		$statistics{'Sizes'}{'20MB - 30MB'}{'count'}++;
	}
	elsif ($bytes <= 104857600) { #100MB
		$statistics{'Sizes'}{'30MB - 100MB'}{'bytes'} += $bytes;
		$statistics{'Sizes'}{'30MB - 100MB'}{'count'}++;
	}
	else { #btwn 100MB and 250MB
		$statistics{'Sizes'}{'100MB - 250MB'}{'bytes'} += $bytes;
		$statistics{'Sizes'}{'100MB - 250MB'}{'count'}++;
	}

	if ($optctl{'collate-from'}) {
		$statistics{'Envelope From addresses which at least began sending mail'}{$msginfo{$SN_MID}{'from'}}{'totalbytes'} += $bytes;
		$statistics{'Envelope From addresses which at least began sending mail'}{$msginfo{$SN_MID}{'from'}}{'Msgs'}++;
	}
	if ($optctl{'collate-domain'}) {
		my $domain = &whatdomain($msginfo{$SN_MID}{'from'}.'');
		$statistics{'Envelope From domains which at least began sending mail'}{$domain}{'totalbytes'} += $bytes;
		$statistics{'Envelope From domains which at least began sending mail'}{$domain}{'Msgs'}++;
	}

	#Allow this to be counted even in cases of splintering?
	if ($optctl{'collate-ip'} and $msginfo{$SN_MID}{'collate-ip'}) {
		#count number of messages per IP/Class C
		$collate_ip{$msginfo{$SN_MID}{'collate-ip'}}{3}++;
	}

	if ($optctl{'timeperiods'}) {
		&collate_timeperiods('Ready', $bytes);
	}

	if ($optctl{'timings'}) {
		$msginfo{$SN_MID}{'readytime'} = $linetimeepoch;
	}

	$msginfo{$SN_MID}{'size'} = $bytes;
	$statistics{'Messages'}{'received (system/splintered/external origin)'}++;

	#Do not count certain stats for splintered or system-generated messages
	if ($msginfo{$SN_MID}{'interface'}
			and ($msginfo{$SN_MID}{'interface'} ne 'generated on-system')
			and ($msginfo{$SN_MID}{'interface'} ne 'splintered from')) {
		$statistics{'Messages'}{"received on '$msginfo{$SN_MID}{'interface'}'"}++;
		$statistics{'Messages'}{'Total received (external origin)'}++;
		$statistics{'Sizes'}{'Total bytes received'} += $bytes;
		$statistics{'Recipients'}{'received'} += $msginfo{$SN_MID}{'rcpt_count'};
		#add in accepted rcpts for this time period
		if ($optctl{'timeperiods'}) {
			&collate_timeperiods('Recipients accepted', $msginfo{$SN_MID}{'rcpt_count'});
		}

		#find info about top 10 most costly messages
		#If the highest (lowest of 10) cost is less than the cost of the current message
		# OR the number of sizes recorded is less than 10
		if (($highest_cost < ($msginfo{$SN_MID}{'size'} * $msginfo{$SN_MID}{'rcpt_count'})) or (10 > $highest_cost_count)) {
			$statistics{'Costliness'}{$SN_MID}{'size'} = $bytes;
			$statistics{'Costliness'}{$SN_MID}{'time'} = $linetimestamp;
			$statistics{'Costliness'}{$SN_MID}{'from'} = $msginfo{$SN_MID}{'from'};
			$statistics{'Costliness'}{$SN_MID}{'rcpt_count'} = $msginfo{$SN_MID}{'rcpt_count'};
			$highest_cost_count++;
			#if there are more than 10, lop off the lowest ones
			if (10 < $highest_cost_count) {
				my $i = 0;
				foreach my $snmid (sort {$statistics{'Costliness'}{$b}{'size'} <=> $statistics{'Costliness'}{$a}{'size'}} keys %{$statistics{'Costliness'}}) {
					if ($i++ < 10) {
						#get the size of lowest of the 10 highest:
						$highest_cost = $statistics{'Costliness'}{$snmid}{'size'};
						next;
					}
					delete $statistics{'Costliness'}{$snmid};
					$highest_cost_count--;
				}
			}
		}
	}

	return 1;
} #info_MID_ready_bytes

#linetime_minute, hour, day will be taken from global along with the general
#body of $statistics
#only the type of item being collected needs to be passed in to indicate the operation
#the $data parameter will be used for other info needed by the particular collection
sub collate_timeperiods {
	my ($operation, $data) = @_;

	#if this is for 'Status', pre-parse the log entry so it's not re-done 3 times:
	my %status;
	if ($operation eq 'Status') {
		substr $data, 0, 8, ''; #strip off 'Status: '
		#Split the entire thing for selective use
		%status = split(' ', $data);
	}

	foreach my $period ('Minutes', 'Hourly', 'Daily') {
		my $lcperiod = lc($period);
		next unless ($optctl{$lcperiod} > 0);
		#Keep an array to be used later in making sure the row ordering comes out right from the hash
		#If I have not yet seen this timestamp:
		if (!$statistics{$period}{$linetime{$period}}) {
			push @{$statistics2{"$period-array"}}, $linetime{$period};
		}
		if ($#{$statistics2{"$period-array"}} > 1000) {
			$statistics{' Notes'}{"Max number of $period entries (1000) reached on $linetime{$period}."} = ' ';
			$optctl{$lcperiod} = -1;
		}

		#This may look confusing, but it's not, really.  :-)
		#$linetime{$period} refers to the desired minute/hour/day timestamp for the current line being processed.

		if ($operation eq 'SBRS') {
			$statistics{$period}{$linetime{$period}}{"SBRS $data"}++;
		}
		elsif ($operation eq 'HAT Policy') {
			$statistics{$period}{$linetime{$period}}{"HAT Policy $data"}++;
		}
		elsif ($operation eq 'Recipients accepted') {
			$statistics{$period}{$linetime{$period}}{'Recipients accepted'} += $data;
		}
		elsif ($operation eq 'Recipient Status') {
			$statistics{$period}{$linetime{$period}}{"Recipients $data"}++;
		}
		elsif ($operation eq 'Ready') {
			$statistics{$period}{$linetime{$period}}{'Messages Received'}++;
			$statistics{$period}{$linetime{$period}}{'Bytes Received'} += $data;
		}
		elsif ($operation eq 'AVAS') {
			$statistics{$period}{$linetime{$period}}{$data}++;
		}
		#parsing of the Status line for fun and profit
		elsif ($operation eq 'Status') {
			#If a WQ max counter doesn't exist, or is less than the current number, set it
			if (!$statistics{$period}{$linetime{$period}}{'Workqueue max'}
					or ($statistics{$period}{$linetime{$period}}{'Workqueue max'} < $status{'WorkQ'})) {
				$statistics{$period}{$linetime{$period}}{'Workqueue max'} = $status{'WorkQ'};
			}
			#If a concurrency max counter doesn't exist, or is less than the current number, set it
			if (!$statistics{$period}{$linetime{$period}}{'Concurrency max'}
					or ($statistics{$period}{$linetime{$period}}{'Concurrency max'} < $status{'CrtCncIn'})) {
				$statistics{$period}{$linetime{$period}}{'Concurrency max'} = $status{'CrtCncIn'};
			}

			#Some counters for which I want only the latest value per time slice
			foreach my $i ('CrtMID', 'CrtICID', 'CrtDCID', 'InjMsg', 'InjRcp', 'RejRcp', 'DrpMsg', 'DlvRcp', 'CrtCncIn', 'CrtCncOut') {
				$statistics{$period}{$linetime{$period}}{"Status-$i"} = $status{$i};
			}
		}
	} #foreach minutes, hourly, daily
	return 1;
} #collate_timeperiods


1;

