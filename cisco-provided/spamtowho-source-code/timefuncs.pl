#Tomki
#Feb 2004

use Time::Local;

our %monthnums = ('Jan' => '0',
		'Feb' => '1',
		'Mar' => '2',
		'Apr' => '3',
		'May' => '4',
		'Jun' => '5',
		'Jul' => '6',
		'Aug' => '7',
		'Sep' => '8',
		'Oct' => '9',
		'Nov' => '10',
		'Dec' => '11');
our %daynums = (
		'Sun' => 0,
		'Mon' => 1,
		'Tue' => 2,
		'Wed' => 3,
		'Thu' => 4,
		'Fri' => 5,
		'Sat' => 6);
our %t_last;

#Given an input format such as retrieved from log lines:
#Mon Jan 12 12:52:46 2004 Info: MID 9753 rewritten to 9755 by antispam
#this function will create and return a string in epoch time format
sub maketime {
	my $t_str = $_[0];
	return 0 unless $t_str;

	#Hack to indicate not to update t_last in cases where I just want to
	# get a value w/o that action:
	# Default to update
	my $updatelast_flag = $_[1];

	my $tlast_tmp = $t_last{'time'} || 0;
	my $t_str_tmp = $t_str;
	my %thash;

	my $rv = 0;
	if ($_[6]) { #$1 - $6 prepopulated..
		#what to do here...
	}
	elsif (!&time_verify($t_str, \%thash)) {
		print "Unrecognized input date format: $t_str\n";
		return -1;
	}
	elsif ($t_last{'time'} and $t_last{'time_epoch'} and (substr($tlast_tmp, 0, 14, '') eq substr($t_str_tmp, 0, 14, ''))) {
		#try to avoid having to call timelocal() by remembering last time I did
		my $diff = 0;
		my $min1 = substr($tlast_tmp, 0, 2, '');
		my $min2 = substr($t_str_tmp, 0, 2, '');
		#print "doing: $tlast_tmp $t_str_tmp\n";
		if ($min1 != $min2) {
			$diff = $min2 - $min1;
		}
		substr($t_str_tmp, 0, 1, ''); #remove ':'
		substr($tlast_tmp, 0, 1, ''); #remove ':'
		$tlast_tmp = substr($tlast_tmp, 0, 2, '');
		$t_str_tmp = substr($t_str_tmp, 0, 2, '');
		$diff += $t_str_tmp - $tlast_tmp;
		if ($diff < 0) {
			$diff = 0;
		}
		return ($t_last{'time_epoch'} + $diff);
	}
	else {
		$rv = timelocal($thash{'second'}, $thash{'minute'}, $thash{'hour'}, $thash{'mday'}, $monthnums{$thash{'mon'}}, $thash{'year'});
		if (!$rv) {
			print "something wrong in maketime for $t_str: $!\n";
			exit(1);
		}
		if (defined($updatelast_flag) and ($updatelast_flag != 0)) {
			$t_last{'time'} = $t_str;
			$t_last{'time_epoch'} = $rv;
		}
	}
	return int($rv);
} #maketime

#formats:
#Mon Jan 12 12:52:46 2004
#Mon Jan  2 12:52:46 2004
sub time_verify {
	my ($timestring, $timevars_href) = @_;
	$$timevars_href{'day'} = substr $timestring, 0, 3, '';
	substr $timestring, 0, 1, ''; #strip ' '
	$$timevars_href{'mon'} = substr $timestring, 0, 3, '';
	if (!defined($monthnums{$$timevars_href{'mon'}}) or !defined($daynums{$$timevars_href{'day'}})) {
		#Something wrong with the format of the line attempting to be parsed.
		print STDERR "Something wrong with parsed Day '$$timevars_href{'day'}' or Month '$$timevars_href{'mon'}'\n";
		return 0;
	}
	substr $timestring, 0, 1, ''; #strip ' '
	if (!(index $timestring, ' ', 0)) { #success returns 0
		substr $timestring, 0, 1, ''; #strip ' '
		#1 digit left:
		$$timevars_href{'mday'} = int(substr $timestring, 0, 1, '');
	}
	else {
		#2 digits left:
		$$timevars_href{'mday'} = int(substr $timestring, 0, 2, '');
	}
	substr $timestring, 0, 1, ''; #strip ' '
	#Now what I have left in $timestring is: 12:52:46 2004
	$$timevars_href{'hour'} = int(substr $timestring, 0, 2, '');
	substr $timestring, 0, 1, ''; #strip ':'
	$$timevars_href{'minute'} = int(substr $timestring, 0, 2, '');
	substr $timestring, 0, 1, ''; #strip ':'
	$$timevars_href{'second'} = int(substr $timestring, 0, 2, '');
	substr $timestring, 0, 1, ''; #strip ':'
	$$timevars_href{'year'} = int($timestring);

	return 1;
} #time_verify

#Mon Jan 12 12:52:46 2004
#Given 2 timestamps in the format from the maillog, determine the time btwn them
sub timediff {
	my ($t1_str, $t2_str) = @_;
	my %thash1;
	my %thash2;
	if (!$t1_str or !$t2_str) {
		# If the message start wasn't seen (or something else?)
		return .5;
	}
	#already in numerical format?
	elsif (($t1_str =~ m/^\d+$/o) and ($t2_str =~ m/^\d+$/o)) {
		if ($t1_str > $t2_str) {
			return .5;
		}
		return ($t2_str - $t1_str);
	}
	elsif (&time_verify($t1_str, \%thash1) and (&time_verify($t2_str, \%thash2) and ($thash1{'hour'} == $thash2{'hour'}) and (($thash2{'minute'} - $thash1{'minute'}) >= 0))) {
		my $newtime;
		my $mindiff = $thash2{'minute'} - $thash1{'minute'};
		my $minsecs = $mindiff * 60;
		if ($thash1{'second'} > $thash2{'second'}) {
			if ($mindiff >= 1) {
				$newtime = ($minsecs - ($thash1{'second'} - $thash2{'second'}));
			}
			else {
				$newtime = ($minsecs + (60 - $thash1{'second'}) + $thash2{'second'});
			}
		}
		else {
			$newtime = ($minsecs + $thash2{'second'} - $thash1{'second'});
		}
		return $newtime;
	}
	#If that didn't work, rely on the heavyweight method to get the answer.
	else {
		return 0;
	}
	my $t1 = &maketime ($t1_str);
	my $t2 = &maketime ($t2_str);
	if (($t1 < 0) || ($t2 < 0)) {
		return -1;
	}
	my $diff = int($t2 - $t1);
	if (($diff > 10000) and $optctl{'debug'}) {
		print "Too long??? time diff of $t1_str and $t2_str is big: $diff\n";
	}
	if ($diff < 0) {
		#I've seen this. I bet it happens when NTP corrects system time
		return 0;
	}
	return $diff;
} #timediff

sub epoch2local {
	my $i = localtime($_[0]);
	return $i;
}

1;

