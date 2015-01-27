#Tomki
#Feb 2004

sub round {
	my($number) = shift;
	if ($number < 0) {
		return int($number - .5);
	}
	return int($number + .5);
}

our %sortfuncs = (
		'Envelope From domains which at least began sending mail' => #collate-domain
		sub {
			#same handling, refer it on
			my $rsub = $sortfuncs{'Envelope From addresses which at least began sending mail'};
			return &$rsub('Envelope From domains which at least began sending mail', $_[1]);
		},
		'Envelope From addresses which at least began sending mail' => #collate-from
		sub {
			our $area = $_[0];
			#this top level element
			my $output = "$area\n";
			$output .= sprintf "\t%-40s\t%10s\t%10s\t%10s\t%10s\t%10s\t%10s\t%13s\n", 'Address', 'Xseen', 'Acc Msgs', 'Acc Rcpts', 'Rej Rcpts', 'Rcv Failed', '%ASpos', 'Avg bytes/msg';
			my $itemcount = 0;
			#Iterate over all keys for output formatting
			foreach my $subitem (sort sort_froms keys %{$_[1]}) {
				#Check to see if I've reached item-printout limit
				if ($optctl{'collate-limit'} and ($optctl{'collate-limit'} <= $itemcount++)) {
					delete ${$_[1]}{$subitem};
					next;
				}
				if (ref(${$_[1]}{$subitem}) eq 'HASH') {
					my $count = ${$_[1]}{$subitem}{'count'};
					my $msgs = ${$_[1]}{$subitem}{'Msgs'} || 0;
					my $acc_rcpts = ${$_[1]}{$subitem}{'Acc Rcpts'} || '0';
					my $rej_rcpts = ${$_[1]}{$subitem}{'Rej Rcpts'} || '0';
					my $failed = ${$_[1]}{$subitem}{'Receiving Failed'} || '0';
					my $aspos = ${$_[1]}{$subitem}{'ASpos'} || '0';
					my $aspos_percent = &percentize($aspos / ($msgs || 1));
					my $avgbytes = int((${$_[1]}{$subitem}{'totalbytes'} || 0) / ($msgs || 1));

					if ($aspos_percent > 100) {
						#This can occur because PRSA splintered messages can also be counted as SPAM positive.
						#To fix the issue properly the number of messages needs to be marked up upon splingering.
						#Some difficult problems around this - needing to determine when the last recipient(s)
						# have been id'd by policies is one.
						#So for now at least just force 100% for the view.
						if (!$optctl{'quiet'}) {
							print STDERR "aspos_percent $aspos_percent for $subitem (aspos/msgs is $aspos/$msgs) - setting down\n";
						}
						$aspos_percent = 100;
						#print STDERR "$area\n\taspos_percent for $subitem is greater than 100 ($aspos_percent) because.. 'ASpos/msgs' => $aspos/$msgs\n";
					}
					$output .= sprintf "\t%-40s\t%10d\t%10d\t%10s\t%10s\t%10d\t%10d\t%13s\n", $subitem, $count, $msgs, $acc_rcpts, $rej_rcpts, $failed, $aspos_percent, $avgbytes;
					delete ${$_[1]}{$subitem};
				}
			}
			#Print out items skipped over above
			foreach my $subitem (sort keys %{$_[1]}) {
				$output .="\t$subitem\t${$_[1]}{$subitem}\n";
			}
			return $output;
		}, # "Envelope From addresses which at least began sending mail"

		'Policy matches' => #PRSA info
		sub {
			our $area = $_[0];
			#Print this top level element
			my $output = "$area\n";
			$output .= sprintf "\t%-45s\t%11s\t%10s\t%11s\t%11s\t%8s\n", 'Policy', 'Whole', 'Splinters', '#ASpos', '#ASsusp', '#AVpos';
			foreach my $subitem (sort keys %{$_[1]}) {
				my $whole = (${$_[1]}{$subitem}{'Whole'} || 0);
				my $splinters = (${$_[1]}{$subitem}{'Splinters'} || 0);
				my $spam = (${$_[1]}{$subitem}{'Anti-Spam positive'} || 0);
				my $sspam = (${$_[1]}{$subitem}{'Anti-Spam suspect'} || 0);
				my $virus = (${$_[1]}{$subitem}{'Anti-Virus positive'} || 0);
				$output .= sprintf "\t%-45s\t%11d\t%10d\t%11d\t%11d\t%8d\n", $subitem, $whole, $splinters, $spam, $sspam, $virus;
			}
			return $output;
		},

		'Per destination rcpt' => # -per_rcpt, -collate-to in the future?
		sub {
			#same handling, refer it on
			my $rsub = $sortfuncs{'Per destination domain'};
			return &$rsub('Per destination rcpt', $_[1]);
		},
		'Per destination domain' => # -per_domain, -collate-rcvdomain in the future?
		sub {
			our $area = $_[0];
			#Print this top level element
			my $output = "$area\n";
			#Set this up so I can dynamically find the correct optctl limit variable
			# further on
			my $type;
			$area =~ m/^Per destination (.+)/;
			if ($1 =~ m/domain/i) {
				$type = 'per_domain';
			}
			else {
				$type = 'per_rcpt';
			}
			my $itemcount = 0;
			$output .= sprintf "\t%-40s\t%10s\t%10s\t%11s\t%10s\t%5s\t%15s\n", 'Address', 'Rcpts in', 'Rcpts out', '%ASpositive', '%ASsuspect', '#AVpos', 'Bytes delivered';
			foreach my $subitem (sort sort_froms keys %{$_[1]}) {
				my $count = (${$_[1]}{$subitem}{'count'} || 0); #This is rcpts in
				my $rcpts_out = (${$_[1]}{$subitem}{'rcpts out'} || 0);
				#Check to see if I've reached item-printout limit
				if ($optctl{'collate-limit'} and ($optctl{'collate-limit'} <= $itemcount++)) {
					delete ${$_[1]}{$subitem};
					next;
				}
				if (${$_[1]}{$subitem}{'count'} < $optctl{"${type}limit"}) {
					next;
				}
				my $assusp_percent = &percentize((${$_[1]}{$subitem}{'spam suspect'} || 0) / ($count || 1));
				if ($assusp_percent > 100) {
					#See explanation earlier - Envelope From domains
					$assusp_percent = 100;
				}
				my $aspos_percent = &percentize((${$_[1]}{$subitem}{'spam positive'} || 0) / ($count || 1));
				if ($aspos_percent > 100) {
					#See explanation earlier - Envelope From domains
					$aspos_percent = 100;
				}
				my $avpos = ${$_[1]}{$subitem}{'viruses'} || '0';
				my $bytesdelivered = &commaize(${$_[1]}{$subitem}{'bytes delivered'} || '-');
				$output .= sprintf "\t%-40s\t%10d\t%10d\t%11d\t%10d\t%5d\t%15s\n", $subitem, $count, $rcpts_out, $aspos_percent, $assusp_percent, $avpos, $bytesdelivered;
				delete ${$_[1]}{$subitem};
			}
			return $output;
		}, # 'Per destination domain'

		'DNS switching' =>
		sub {
			my $output = "$_[0]\n";
			my $count = 0;
			foreach my $item (sort {${$_[1]}{$b} <=> ${$_[1]}{$a}} keys %{$_[1]}) {
				last if $count++ == 100; #only 100 lines of this
				$output .= "\t$item\t${$_[1]}{$item}\n";
			}

			return $output;
		}, # 'DNS switching'

		'Sizes' =>
		sub {
			my $output = "$_[0]\n";

			#some special formatting for byte size range items:
			my $blank = '';
			my ($subitem, $Mbytes, $msgs, $avgkbytes, $percentbytes, $percentmsgs) = ();
			$output .=  sprintf "\t%-14s\t%12s\t%9s\t%9s\t%6s\t%9s\n", 'Size Range', 'MB Total', 'messages', 'AvgKBytes', '%bytes', '%messages';

			foreach $subitem (sort sort_bytesizes keys %{$_[1]}) {
				next if $subitem !~ m/^\d+\s*\w+/;
				$Mbytes = int((${$_[1]}{$subitem}{'bytes'}/(1024*1024))*100)/100;
				$msgs = ${$_[1]}{$subitem}{'count'};
				$avgkbytes = int(((${$_[1]}{$subitem}{'bytes'} / $msgs)/1024)*100)/100;
				$percentbytes = &percentize(${$_[1]}{$subitem}{'bytes'} / ($statistics{'Sizes'}{'Total bytes received'}));
				$percentmsgs = &percentize(${$_[1]}{$subitem}{'count'} / $statistics{'Messages'}{'received (system/splintered/external origin)'});
				$output .= sprintf "\t%-14s\t%12.2f\t%9d\t%9.2f\t%6.2f\t%9.2f\n", $subitem, $Mbytes, $msgs, $avgkbytes, $percentbytes, $percentmsgs;
				#Populate the calculated percentage back in
				${$_[1]}{$subitem}{'percent_msgs'} = $percentmsgs;
				${$_[1]}{$subitem}{'percent_bytes'} = $percentbytes;
			}
			#Print out items skipped over above
			foreach my $subitem (sort sort_bytesizes keys %{$_[1]}) {
				next if defined(${$_[1]}{$subitem}{'percent_msgs'});
				next if $subitem =~ m/^Total bytes/; #skip this detail
				$output .= "\t$subitem\t${$_[1]}{$subitem}\n";
			}
			return $output;
		}, #Sizes

		'Costliness' =>
		sub {
			#Print this top level element
			my $output = "$_[0]\n";
			$output .= sprintf "\t%14s\t%25s\t%6s\t%25s\n", 'Size', 'From', '#rcpts', 'Time';
			foreach my $subitem (sort {${$_[1]}{$b}{'size'} <=> ${$_[1]}{$a}{'size'}} keys %{$_[1]}) {
				$output .= sprintf "\t%14d\t%25s\t%6d\t%25s\n", ${$_[1]}{$subitem}{'size'}, ${$_[1]}{$subitem}{'from'}, ${$_[1]}{$subitem}{'rcpt_count'}, ${$_[1]}{$subitem}{'time'};
			}
			return $output;
		}, #Costliness

		'TLS in' =>
		sub {
			#looks like the default format is good for this for now!
			#same handling, refer it on
			my $rsub = $sortfuncs{'Limited Standard Output'};
			return &$rsub('TLS in', $_[1]);
		}, #TLS in

		'TLS out' =>
		sub {
			#looks like the default format is good for this for now!
			#same handling, refer it on
			my $rsub = $sortfuncs{'Limited Standard Output'};
			return &$rsub('TLS out', $_[1]);
		}, #TLS out

		#gathered by collate-rejects
		'Recipients rejected by RAT' =>
		sub {
			#looks like the default format is good for this for now!
			#same handling, refer it on
			my $rsub = $sortfuncs{'Limited Standard Output'};
			return &$rsub('Recipients rejected by RAT', $_[1]);
		}, #Recipients rejected by RAT

		#gathered by collate-rejects

		'Recipients rejected by LDAPACCEPT' =>
		sub {
			#looks like the default format is good for this for now!
			#same handling, refer it on
			my $rsub = $sortfuncs{'Limited Standard Output'};
			return &$rsub('Recipients rejected by LDAPACCEPT', $_[1]);
		}, #Recipients rejected by LDAPACCEPT

		#A standard output format, limited by collate-limit
		'Limited Standard Output' =>
		sub {
			my $itemcount = 0;
			#Print this top level element
			my $output = "$_[0]\n";
			foreach my $subitem (sort {${$_[1]}{$b} <=> ${$_[1]}{$a}} keys %{$_[1]}) {
				#Check to see if I've reached item-printout limit
				if ($optctl{'collate-limit'} and ($optctl{'collate-limit'} <= $itemcount++)) {
					delete ${$_[1]}{$subitem};
					next;
				}
				$output .= sprintf "\t%32s\t%12s\n", $subitem, ${$_[1]}{$subitem};
			}
			return $output;
		}, #Limited Standard Output

		"IP addresses that connected (distinct $optctl{'collate-ip-class'}s)" =>
		sub {
			#$_[1] is a reference, like $statistics{'IP .. ected'} in this case
			#This is the section header as 2 lines up from here
			#Print this top level element
			my $output = "$_[0]\n";

			if (${$_[1]}{'Unknown (old conn)'}) {
				#provide initialization to avoid errors
				${$_[1]}{'Unknown (old conn)'}{1} = 0;
			}
			$output .= "\tUnique $optctl{'collate-ip-class'}s\t" . ${$_[1]}{" Unique $optctl{'collate-ip-class'}s"} . "\n";
			$output .= "\tUnique connections\t${$_[1]}{' Unique connections'}\n";

			my $tmp1 = ${$_[1]}{" Unique $optctl{'collate-ip-class'}s"};
			my $tmp2 = ${$_[1]}{' Unique connections'};
			delete ${$_[1]}{" Unique $optctl{'collate-ip-class'}s"};
			delete ${$_[1]}{' Unique connections'};

			my $blank = '';
			my ($subitem, $seencount, $sbrs, $msginj, $as_scanned, $aspos, $avpos, $concurr, $rej_rcpt, $rem_host) = ();
			$output .= sprintf "\t%-15s\t%8s\t%4s\t%10s\t%10s\t%10s\t%10s\t%8s\t%-4s\t%-40s\n", 'IP Address', 'XSeen', 'SBRS', 'MsgInj', '#RejRcpts', '#AS-scanned', '%ASpos', '#AVpos', 'MaxCncr', 'Remote Host';
			my $itemcount = 0;
			#Iterate over all keys for output formatting
			foreach $subitem (sort {${$_[1]}{$b}{1} <=> ${$_[1]}{$a}{1}} keys %{$_[1]}) {
				#1 is the IP seen-count, 2 is the SBRS, 3 is the # of msg injections, 4 is the AS-pos count
				$seencount = ${$_[1]}{$subitem}{1} || 0;
				$sbrs = ${$_[1]}{$subitem}{2} || 'None';
				$msginj = ${$_[1]}{$subitem}{3} || 0;
				$as_scanned = ${$_[1]}{$subitem}{4} || 0;
				$aspos_percent = &percentize((${$_[1]}{$subitem}{5} || 0) / ($msginj || '1'));
				if ($aspos_percent > 100) {
					#See explanation earlier - Envelope From domains
					$aspos_percent = 100;
				}
				$avpos = ${$_[1]}{$subitem}{6} || 0;
				$concurr = ${$_[1]}{$subitem}{7} || 0;
				$rej_rcpt = ${$_[1]}{$subitem}{9} || 0;
				$rem_host = ${$_[1]}{$subitem}{10} || 'NA';
				$output .= sprintf "\t%-15s\t%8d\t%4s\t%10d\t%10d\t%10d\t%10d\t%8d\t%-4d\t%-40s\n", $subitem, $seencount, $sbrs, $msginj, $rej_rcpt, $as_scanned, $aspos_percent, $avpos, $concurr, $rem_host;
				#Check to see if I've reached item-printout limit
				if ($optctl{'collate-limit'} and ($optctl{'collate-limit'} <= $itemcount++)) {
					last;
				}
			}
			${$_[1]}{" Unique $optctl{'collate-ip-class'}s"} = $tmp1;
			${$_[1]}{' Unique connections'} = $tmp2;
			return $output;
		}, # IP addresses that connected

		'Anti-Virus - Sophos' =>
		sub {
			my $rsub = $sortfuncs{'Anti-Virus'}; #same handling, refer it on
			return &$rsub('Anti-Virus - Sophos', $_[1]);
		},

		'Anti-Virus - McAfee' =>
		sub {
			my $rsub = $sortfuncs{'Anti-Virus'}; #same handling, refer it on
			return &$rsub('Anti-Virus - McAfee', $_[1]);
		},

		'Anti-Virus' =>
		sub {
			#Print this top level element
			my $output = "$_[0]\n";
			foreach my $subitem (sort sort_bynumfirst keys %{$_[1]}) {
				#Special output formatting for the sizes table
				if ($subitem eq 'Sizes') {
					my $blank = '';
					my ($sizeitem, $result, $seencount) = ();
					$output .= sprintf "\t%-10s\t%10s\t%10s\t%5s\t%5s\n", 'Size Range', 'Pos', 'Neg', 'Unsc', 'Rprd';
					foreach $sizeitem (sort sort_bytesizes keys %{${$_[1]}{$subitem}}) {
						my $pos  = ${$_[1]}{$subitem}{$sizeitem}{'positive'} || '0';
						my $neg = ${$_[1]}{$subitem}{$sizeitem}{'negative'} || '0';
						my $unsc = ${$_[1]}{$subitem}{$sizeitem}{'unscannable'} || '0';
						my $rprd = ${$_[1]}{$subitem}{$sizeitem}{'repaired'} || '0';
						$output .= sprintf "\t%-10s\t%10s\t%10s\t%5s\t%5s\n", $sizeitem, $pos, $neg, $unsc, $rprd;
					}
					#do stuff here
					next;
				}
				$output .= "\t$subitem\t" . &commaize(${$_[1]}{$subitem}) . "\n";
			}
			return $output;
		}, #Anti-Virus

		'Anti-Spam - Cloudmark' =>
		sub {
			my $rsub = $sortfuncs{'Anti-Spam'}; #same handling, refer it on
			return &$rsub('Anti-Spam - Cloudmark', $_[1]);
		},

		'Anti-Spam - Brightmail' =>
		sub {
			my $rsub = $sortfuncs{'Anti-Spam'}; #same handling, refer it on
			return &$rsub('Anti-Spam - Brightmail', $_[1]);
		},

		'Anti-Spam - CASE' =>
		sub {
			my $rsub = $sortfuncs{'Anti-Spam'}; #same handling, refer it on
			return &$rsub('Anti-Spam - CASE', $_[1]);
		},

		'Anti-Spam' =>
		sub {
			#Print this top level element
			my $output = "$_[0]\n";
			foreach my $subitem (sort sort_bynumfirst keys %{$_[1]}) {
				#Special output formatting for the sizes table
				if ($subitem eq 'Sizes') {
					my $blank = '';
					my ($sizeitem, $result, $seencount) = ();
					$output .= sprintf "\t%-10s\t%10s\t%10s\t%10s\n", 'Size Range', 'Pos', 'Neg', 'Susp';
					foreach $sizeitem (sort sort_bytesizes keys %{${$_[1]}{$subitem}}) {
						my $pos = ${$_[1]}{$subitem}{$sizeitem}{'positive'} || '0';
						my $neg = ${$_[1]}{$subitem}{$sizeitem}{'negative'} || '0';
						my $suspect = ${$_[1]}{$subitem}{$sizeitem}{'suspect'} || '0';
						$output .= sprintf "\t%-10s\t%10s\t%10s\t%10s\n", $sizeitem, $pos, $neg, $suspect;
					}
					#do stuff here
					next;
				}
				elsif ($subitem eq 'AS-positive messages') {
					#Special case printing out a percentage for this entry
					$output .= "\t$subitem"
						. "\t" . &commaize(${$_[1]}{$subitem})
						. "\t" . &percentize(${$_[1]}{$subitem} / ${$_[1]}{'AS Total messages'}) . "%\n";
					next;
				}
				elsif ($subitem eq 'AS-positive rcpts') {
					#Special case printing out a percentage for this entry
					$output .= "\t$subitem"
						. "\t" . &commaize(${$_[1]}{$subitem})
						. "\t" . &percentize(${$_[1]}{$subitem} / ${$_[1]}{'AS Total recipients'}) . "%\n";
					next;
				}
				$output .= "\t$subitem\t" . &commaize(${$_[1]}{$subitem}) . "\n";
			}
			return $output;
		}, #Anti-Spam

		'SBRS' =>
		sub {
			#Print this top level element
			my $output = "$_[0]\n";

			#Default action is to compress this all down to single integers
			if (!$optctl{'all-sbrs'}) {
				foreach my $fullscore (keys %{$_[1]}) {
					my $shortscore = $fullscore;
					next unless $shortscore =~ m/\./; #numerical score pattern
					$shortscore =~ s/^(-?\d{1,2})\.\d{1,2}$/$1/;
					foreach my $key (keys %{${$_[1]}{$fullscore}}) {
						if (ref($key) eq 'HASH') {
							#not planning on having to recurse more..  err and pass
							print STDERR "Extra level of hashing in SBRS container $fullscore?\n";
							next;
						}
						${$_[1]}{$shortscore}{$key} += ${$_[1]}{$fullscore}{$key};
						#print "mapping fullscore $fullscore item $key value ${$_[1]}{$fullscore}{$key} into shortscore: $shortscore\n";
					}
					#Now get rid of the full score since we only want the short
					delete ${$_[1]}{$fullscore};
				}
			}
			#construct a matrix showing the number of messages received at each
			#score level, with relevant Brightmail Positive catchrate.
			foreach my $score (sort sort_bynumfirst keys %{$_[1]}) {
				if (!defined(${$_[1]}{$score}{'ScdMsgs'})) {
					#this score hasn't been attached to a message scanned by AS
					${$_[1]}{$score}{'ScdMsgs'} = 'NA';
					${$_[1]}{$score}{'%AS Pos'} = 'NA';
				}
				else {
					${$_[1]}{$score}{'%AS Pos'} = &percentize((${$_[1]}{$score}{'positive'} || '0') / (${$_[1]}{$score}{'ScdMsgs'} || 1));
				}

				#messages with this score might not have made it to AS matching
				${$_[1]}{$score}{'%Total Conns'} = &percentize((${$_[1]}{$score}{'Conns'} || '0') / ($statistics{'Connections in'}{' Total Initiated'} || 1));
				${$_[1]}{$score}{'%Total Msgs'} = &percentize((${$_[1]}{$score}{'MsgBgn'} || '0') / ($statistics{'Messages'}{'Deliveries Begun Inbound'} || 1));

				if ($optctl{'SBRS-subjects'} and $sbrs_subjects{$score}) {
					#hackishly outside of output control function
					$output .= "$score\n";
					foreach my $subject (@{$sbrs_subjects{$score}}) {
						$output .= "\t$subject\n";
						delete $sbrs_subjects{$score};
					}
				}
			}

			#determine the order of the columns printed out
			#I have a set order I want these printed in, so I have to know the names
			my @item_order = ('Score', 'Conns', '%Total Conns', 'MsgBgn', '%Total Msgs', 'ScdMsgs', '%AS Pos');
			#Output headers
			$output .= sprintf "\t%-7s\t%11s\t\%12s\t%11s\t%12s\t%10s\t%7s\n", 'Score', 'Conns', '%Total Conns', 'MsgBgn', '%Total Msgs', 'ScdMsgs', '%AS Pos';

			#now just print data
			foreach my $score (sort sort_bynumfirst keys %{$_[1]}) {
				next unless ${${$_[1]}{$score}}{'Conns'};
				my $conns = ${${$_[1]}{$score}}{'Conns'} || '0';
				my $percent_conns = ${${$_[1]}{$score}}{'%Total Conns'} || '0';
				my $msgbgn = ${${$_[1]}{$score}}{'MsgBgn'} || '0';
				my $percent_msgs = ${${$_[1]}{$score}}{'%Total Msgs'} || '0';
				my $scdmsgs = ${${$_[1]}{$score}}{'ScdMsgs'} || '0';
				my $percent_aspos = ${${$_[1]}{$score}}{'%AS Pos'} || '0';
				$output .= sprintf "\t%-.6s\t%11s\t\%12s\t%11s\t%12s\t%10s\t%7s\n", $score, $conns, $percent_conns, $msgbgn, $percent_msgs, $scdmsgs, $percent_aspos;
			}
			return $output;
		}, #SBRS

		'Minutes' =>
		sub {
			my $rsub = $sortfuncs{'Daily'}; #same handling, refer it on
			return &$rsub('Minutes', $_[1]);
		},

		'Hourly' =>
		sub {
			my $rsub = $sortfuncs{'Daily'}; #same handling, refer it on
			return &$rsub('Hourly', $_[1]);
		},

		'Daily' =>
		sub {
			my $call_as = $_[0]; #called by minutes and hourly also
			#Print this top level element
			my $output = "$call_as\n";
			#not asked to output this:
			if (!$optctl{lc($call_as)} < 2) {
				#$output .= "\t$call_as output not requested\n";
				return '';
			}
			my $outfile = lc($call_as) . "$$.txt";
			if (!open (TIMEFILE, ">$outfile")) {
				$output .= "\tUnable to open file for $call_as output: $outfile: $!\n";
				return $output;
			}
			my %item_lengths;
			my @item_order;
			#find all headers I need to print out
			# operation isn't too pricey..  #days * #elements..
			foreach my $time (keys %{$_[1]}) {
				#I can have dynamic header types in each timeslice..
				#if it changes halfway thru the logs then a lot of rows may simply be blank.
				foreach my $item (keys %{${$_[1]}{$time}}) {
					$item_lengths{$item} = length($item);
				}
			}
			#determine the order of the columns printed out
			@item_order = reverse sort sort_bynumfirst keys %item_lengths;

			print TIMEFILE "Time\t";
			#Output headers
			foreach my $item (@item_order) {
				print TIMEFILE "$item\t";
			}
			print TIMEFILE "\n";

			#now just print data hopefully in chronological order
			foreach my $time (@{$statistics2{"$call_as-array"}}) {
				print TIMEFILE "$time\t";
				foreach my $item (@item_order) {
					print TIMEFILE ${${$_[1]}{$time}}{$item} || '0';
					print TIMEFILE "\t";
				}
				print TIMEFILE "\n";
			}
			close (TIMEFILE);
			$output .= "\tWritten to file: $outfile\n";
			return $output;
		}, #Daily
	); #sortfuncs hash of anonymous functions

#this is the normal textual style output - 'new' was almost never used
# and is not maintained.
sub oldoutput {
	#sectionlinks will contain a directory of HTML anchor links
	our %sectionlinks;
	our $outglobref = *{$tmpfh{'output'}};
	print $outglobref "\n------------ Statistics gathered and compiled: ------------\n";
	my $htmloutput = '';
	if ($optctl{'htmloutput'}) {
		open(HTML, ">$optctl{'htmloutput'}") or warn "problem opening file '$optctl{'htmloutput'}': $!\n";
	}
	#at the top level, everything is printed out in num first, char second order
	foreach my $stat (sort sort_bynumfirst keys %statistics) {
		my $sectionout = '';
		#If the value is not a hash, print it straight out also.
		if (ref($statistics{$stat}) ne 'HASH') {
			#Print this top level element
			$sectionout .= "$stat\t\t";
			$sectionout .= &commaize($statistics{$stat});
			$sectionout .= "\n";
		}
		#If I have an anonymous function defined for handling this data, use it
		elsif (exists $sortfuncs{$stat}) {
			my $rsub = $sortfuncs{$stat};
			$sectionout .= &$rsub($stat, $statistics{$stat});
			#skip further stuff unless some text was returned:
			next unless $sectionout;
		}
		#Else do more complex (or uncoded in sortfuncs) stuff
		else {
			#Print this top level element
			$sectionout .= "$stat\t\t";
			$sectionout .= "\n";
			foreach my $subitem (sort sort_bynumfirst keys %{$statistics{$stat}}) {
				my $percent_total = 0;
				my $percent_total_spam = '.00';
				$sectionout .= "\t$subitem\t" . &commaize($statistics{$stat}{$subitem});
				$sectionout .= "\n";
			} #Foreach subitem
		} #else
		print $outglobref $sectionout;

		if ($optctl{'htmloutput'}) {
			#build directory of anchor links
			my $good_link = $stat;
			my $tmp_stat = quotemeta $stat;
			$good_link =~ s/\W/_/g; #replace any nonword chars with '_'

			$sectionlinks{$stat}{'link'} = "<A HREF='#$good_link'>$stat</A>";
			$sectionlinks{$stat}{'anchor'} = "<A name='$good_link'>$stat</A>";
			$sectionout =~ s/$tmp_stat/<H3>$sectionlinks{$stat}{'anchor'}<\/H3><PRE>/;

			$htmloutput .= " <TR>\n";
			$htmloutput .= "  <TD>\n";
			$htmloutput .= "$sectionout</PRE>\n";
			$htmloutput .= "  </TD>\n";
			$htmloutput .= " </TR>\n";
		}
	} #foreach stat
	print $outglobref "----------- end of auto-stats -----------\n";
	if ($use_domains) {
		foreach my $dom (sort keys %domains) {
			printf $outglobref ("%33s From: %7u To: %7u\n", $dom, $domains{$dom}{'From'}, $domains{$dom}{'To'});
		}
	}

	if ($optctl{'htmloutput'}) {
		#if the daily/hourly/minute files exist, linkify them
		#Written to file: daily3388.txt
		$htmloutput =~ s/^(\s+Written to file: )(\S+)$/$1<A HREF="$2">$2<\/A>/mg;

		&beginhtml();
		print HTML &datagraphs();
		if ($optctl{'logofile'}) {
			print HTML "<IMG src='$optctl{'logofile'}' title='logo'><BR>\n";
		}

		#Print 2 columns (Table cells) of links
		print HTML "<TABLE border=1>\n";
		print HTML " <TR>\n";
		#Column 1
		print HTML "  <TD>\n";
		print HTML "   <UL>\n";
		my $count = 1;
		foreach my $stat (sort keys %sectionlinks) {
			next if (scalar keys %sectionlinks)/$count++ < 2;
			print HTML "    <LI>$sectionlinks{$stat}{'link'}</LI>\n";
		}
		print HTML "   </UL>\n";
		print HTML "  </TD>\n";
		#Column 2
		print HTML "  <TD>\n";
		print HTML "   <UL>\n";
		$count = 1;
		foreach my $stat (sort keys %sectionlinks) {
			next unless (scalar keys %sectionlinks)/$count++ < 2;
			print HTML "    <LI>$sectionlinks{$stat}{'link'}</LI>\n";
		}
		print HTML "   </UL>\n";
		print HTML "  </TD>\n";
		print HTML " </TR>\n";
		print HTML "</TABLE>\n";

		#Main body of data
		print HTML "<TABLE border=0>\n";
		print HTML " <TR>\n";
		print HTML $htmloutput; #large amount of generated data
		print HTML "</TABLE>\n";
		&endhtml();
		close(HTML);
	}
	return 1;
} #oldoutput

#our @piecolors = ('#FF6060', '#FFA000', '#F6F600', '#A6F60F', '#00F6FF', '#CCF600', '#C6F600',
our @piecolors = ('#FF6060', '#FFA000', '#FFF600', '#BB6060', '#BBA00A', '#BBF600', '#AA6060',
		'#FF60FF', '#00A000', '#F6F600', '#A6F60F', '#00F6FF', '#BBF600', '#C6F600');
#our @piecolors = ('#9933CC', '#CC33B3', '#CC3366', '#CC4D33', '#4D33CC', '#66CC33', '#33CC4D', '#33CC99', '#33B3CC');

#This is the function where the HTML graph items are created and placed.
sub datagraphs {
	#figure out the multiplier...
	if (!$optctl{'HATmultiplier'} and $statistics{'Recipients'}{'Average # per connection (successful)'}) {
		$optctl{'HATmultiplier'} = $statistics{'Recipients'}{'Average # per connection (successful)'};
	}
	elsif (!$optctl{'HATmultiplier'} and !$statistics{'Recipients'}{'Average # per connection (successful)'}) {
		$optctl{'HATmultiplier'} = 1;
	}

	my $overall_pie = &overall_pie();
	my $msgoutcomes_pie = &msgoutcomes_pie();
	my $sbrs_graph = &sbrs_graph();
	my $hourly_graph = &periods_graph('Hourly');
	my $daily_graph = &periods_graph('Daily');
	#my $sizes_graph = &sizes_graph();

	my $htmlgraphs = << "END";
<TABLE border=1>
 <TR>
  <TD width=370px cellpadding=3 align=center bgcolor='#ccccc0'>
   <CENTER><B>Overall system catch-rate groups.</B></CENTER>
   <!-- <I>Assumption: 1 denied connection == $optctl{'HATmultiplier'} denied message(s).</I><BR> -->
   <!-- If this is an integer it was provided as a flag at runtime, or no avg # of recipients was calculable.
   If it's a float it was calculated by the program on the basis of how many recipients were injected on a successful connection. -->
    <DIV style='position:relative; top:0px; height:220px'>
$overall_pie
    </DIV>
  </TD>
  <TD width=370px cellpadding=3 align=center bgcolor='#00ccc0'>
   <CENTER><B>Results for messages actually accepted.</B></CENTER>
    <DIV style='position:relative; top:0px; height:220px'>
$msgoutcomes_pie
    </DIV>
  </TD>
 </TR>
 <TR>
  <TD colspan=2 cellpadding=3 align=center bgcolor='#00ccc0'>
    <DIV style='position:relative; top:0px; height:265px'>
$sbrs_graph
    </DIV>
  </TD>
 </TR>
$daily_graph
$hourly_graph
END
# <TR>
#  <TD height=300px colspan=2 cellpadding=3 align=center>
#    <DIV style='position:relative; top:0px; height:300px'>
#$sizes_graph
#    </DIV>
#  </TD>
# </TR>
#</TABLE>
#END
	return $htmlgraphs;
} #datagraphs

sub periods_graph {
	my ($period_type) = @_;

	my %periodmap = ('Minutes' => 'minutes', 'Hourly' => 'hours', 'Daily' => 'days');
	my $js_cols_headers = 'var stacked_cols_headers = ["Date", "Rejected", "Bad Rcpts", "Spam", "Viral", "Clean"];';
	my $js_cols = 'var stacked_cols = [';
	my $js_colors = 'var js_colors = [
		"#000000", //#Black
		"#BBA00A", //#Brownish
		"#00F0B1", //#Blueish
		"#BB6060", //#Purplish
		"#FFF600", //#Yellow
		"#FFFFFF" //#White
		];';

	#If the number of elements is greater than 100, compress the elements down by half.
	#Repeat until element count is below 100
	# each iteration of this doubles the time-range encompassed by each vertical bar
	my $compressnum = 1;
	my $compress_note = '';
	while ($#{$statistics2{"$period_type-array"}} > 100) {
		if ($optctl{'debug'}) {
			print STDERR "$compressnum) statistics2 array of $period_type-array is over 100: " . scalar(@{$statistics2{"$period_type-array"}}) . "\n";
		}
		$compressnum++;
		my @tmparray;
		for (my $i = 0; $i < $#{$statistics2{"$period_type-array"}}; $i += 2) {
			#break the loop if there isn't a next element
			last if not ${$statistics2{"$period_type-array"}}[$i+1];
			my $date = ${$statistics2{"$period_type-array"}}[$i];
			my $nextdate = ${$statistics2{"$period_type-array"}}[$i+1];
			push @tmparray, $date;
			foreach my $key (keys %{$statistics{$period_type}{$nextdate}}) {
				next unless $statistics{$period_type}{$nextdate}{$key} =~ m/^\d+$/;
				$statistics{$period_type}{$date}{$key} += $statistics{$period_type}{$nextdate}{$key};
			}
		}
		@{$statistics2{"$period_type-array"}} = @tmparray;
	}
	if ($compressnum > 1) {
		#create sentence like "(2 days per column)"
		$compress_note = " ($compressnum $periodmap{$period_type} per column)";
	}

	#logical max height:
	my $max_height = 0;
	#Number of columns (number of datasets):
	my $numcolumns = 0;
	#Pre scan the items I'll be adding up in order to determine the max height
	#This will be:
	#Messages Received + Recipients Rejected by RAT + Recipients Rejected by Receiving Control
	#also generate JS arrays for dynamic graph element creation
	foreach my $date (@{$statistics2{"$period_type-array"}}) {
		$numcolumns++;
		my $bad_conn = ($statistics{$period_type}{$date}{'HAT Policy REJECT'} || 0)
			+ ($statistics{$period_type}{$date}{'HAT Policy REFUSE'} || 0)
			+ ($statistics{$period_type}{$date}{'Recipients Rejected by Receiving Control'} || 0);
		my $bad_rcpts = ($statistics{$period_type}{$date}{'Recipients Rejected by RAT'} || 0);
			+ ($statistics{$period_type}{$date}{'Recipients Rejected by LDAPACCEPT'} || 0);
		my $spam = ($statistics{$period_type}{$date}{'Anti-Spam suspect'} || 0)
			+ ($statistics{$period_type}{$date}{'Anti-Spam positive'} || 0);
		my $virus = ($statistics{$period_type}{$date}{'Anti-Virus positive'} || 0);
		#Good messages are ones accepted MINUS viral and spam ones
		my $good = ($statistics{$period_type}{$date}{'Recipients accepted'} || 0)
			- $spam - $virus;
		#height is rejects + accepts (regardless of whether they get dropped in WQ:
		my $this_height = ($statistics{$period_type}{$date}{'Recipients accepted'} || 0)
				+ $bad_conn + $bad_rcpts;
		if ($this_height > $max_height) {
			$max_height = $this_height;
		}
		#Aside from date, this is reverse order from the legend in 'js_col_headers' because
		# this drives the stacked bar creation from bottom-up
		$js_cols .= "['$date', $good, $virus, $spam, $bad_rcpts, $bad_conn],\n";
	}
	$js_cols =~ s/,\n$/\];/;

	#If not enough data was detected for this for even 1 column, return empty string
	if (!$numcolumns) {
		return '';
	}

	#physical sizing:
	my $x_L = 100;  #x Left
	my $x_R = 580; #x Right - rather hard-set than have it dynamic
	#my $x_R = $x_L + (3 * $numcolumns); #x Right is x_L + 3*numcolumns
	my $y_T = 20;  #y Top
	my $y_B = 240; #y Bottom

	my $html = " <TR>
  <TD ID='periods_graph_$period_type' colspan=2 cellpadding=3 align=center bgcolor='#00ccc0'>
      <DIV style='position:relative; top:0px; height:265px'>
	<SCRIPT Language='JavaScript'>
		document.open();
	var D=new Diagram();
	D.SetFrame($x_L, $y_T, $x_R, $y_B);
	//set a logical border $numcolumns (time divisions) * 3 units wide
	// and $max_height (max_height) high
	D.SetBorder(0, 3 * $numcolumns, 0, $max_height);
	D.SetText('','', '$period_type message attempts$compress_note');
	D.XScale=0;
	D.Draw('#FFFF80', '#004080', false);
	$js_cols_headers
	$js_cols
	$js_colors
	var regiontotals = [0, 0, 0, 0, 0];;
	var totalcount = 0;
	for (var x = 0; x < $numcolumns; x++) {
		//build bars on top of each other for each of good, virus, spam, bad
		var y_bottom = 0; //to begin
		var y_top = 0; //to begin
		//The left side of the vert bar:
		var x1 = x*3;
		//The right side of the vert bar is 2 further:
		var x2 = x1 + 2;
		//Start at 1 to skip over date entry
		for (var j = 1; j < 6; j++) {
			//skip this one if there is a 0-count
			if (stacked_cols[x][j] > 0) {
				//add this count to regiontotal
				regiontotals[j-1] += stacked_cols[x][j];
				totalcount += stacked_cols[x][j];
				//the top of this bar is the current data + the last graphed bottom
				y_top = stacked_cols[x][j] + y_bottom;
				new Bar(D.ScreenX(x1), D.ScreenY(y_top), D.ScreenX(x2), D.ScreenY(y_bottom), js_colors[6 - j], '', '#000000', stacked_cols[x][0] + ' - ' + stacked_cols_headers[6 - j] + ': ' + stacked_cols[x][j]);
				//new y minimum will be the last max:
				y_bottom = y_top;
			}
		}
	}
	for (var j = 1; j < 6; j++) {
		var barPercent = 100*(regiontotals[5-j]/totalcount);
		var X_left = $x_R + 20; //#a bit off the graph's right edge
		var X_right = X_left + 120;
		var Y_top = j * 40;
		var Y_bottom = Y_top + 20;
		//Bar(left, top, right, bottom, color, text, textcolor)
		new Bar(X_left, Y_top, X_right, Y_bottom, js_colors[j], stacked_cols_headers[j] + ' ' + barPercent.toFixed(1) + '%', '#000000', regiontotals[5-j], 'void(0)');
	}
	document.close();
	</SCRIPT>
    </DIV>
  </TD>
 </TR>";
	return $html;
} #periods_graph

sub sbrs_graph {
	my $html = '';
	my $x_L = 100;  #x Left
	my $x_R = 580; #x Right
	my $y_T = 20;  #y Top
	my $y_B = 240; #y Bottom

	#construct JS array -9 to 9
	#like this:
	#SBRSs=new Array('-9', '-8', '-7', '-6', '-5', '-4', '-3', '-2', '-1', '0', '1', '2', '3', '4', '5', '6', '7', '8', ' 9');
	# and create %spam bars
	my $js_SBRSs = 'var SBRSs=new Array(';
	my $js_msgpercentASpos = 'var msgpercentASpos=new Array(';
	my $js_msgpercent = 'var msgpercent=new Array(';
	for (my $i = -10; $i <= 10; $i ++) {
		#make a -0 and +0 side:
		if ($i == 0) {
			$js_SBRSs .= "-$i, ";
			if ($statistics{'SBRS'}{"-$i"} and ($statistics{'SBRS'}{"-$i"}{'%AS Pos'} =~ m/[a-z]/i)) {
				$js_msgpercentASpos .= "0, ";
			}
			$js_msgpercentASpos .= ($statistics{'SBRS'}{"-$i"}{'%AS Pos'} || 0) . ", ";
			if ($statistics{'SBRS'}{"-$i"}{'%Total Msgs'} and ($statistics{'SBRS'}{"-$i"}{'%Total Msgs'} =~ m/[a-z]/i)) {
				$js_msgpercent .= "0, ";
			}
			$js_msgpercent .= ($statistics{'SBRS'}{"-$i"}{'%Total Msgs'} || 0) . ", ";
		}
		$js_SBRSs .= "$i, ";
		#get around NA (and other?) non-numeric entries
		if (!defined($statistics{'SBRS'}{"$i"}{'%AS Pos'}) or ($statistics{'SBRS'}{"$i"}{'%AS Pos'} =~ m/[a-z]/i)) {
			$js_msgpercentASpos .= "0, ";
		}
		else {
			$js_msgpercentASpos .= ($statistics{'SBRS'}{$i}{'%AS Pos'} || 0) . ", ";
		}
		if (!defined($statistics{'SBRS'}{"$i"}{'%Total Msgs'}) or ($statistics{'SBRS'}{"$i"}{'%Total Msgs'} =~ m/[a-z]/i)) {
			$js_msgpercent .= "0, ";
		}
		else {
			$js_msgpercent .= ($statistics{'SBRS'}{$i}{'%Total Msgs'} || 0) . ", ";
		}
	}
	$js_SBRSs =~ s/, $/\);/;
	$js_msgpercentASpos =~ s/, $/\);/;
	$js_msgpercent =~ s/, $/\);/;

	$html = "<SCRIPT Language='JavaScript'>
		document.open();
	var D=new Diagram();
	D.SetFrame($x_L, $y_T, $x_R, $y_B);
	//set a logical border 22 units wide (-0 to 10 and 0 to 10) and 100 (for percent) high
	D.SetBorder(0, 22, 0, 100);
	D.SetText('','', 'Percent of spam-positive messages per SBRS level');
	D.XScale=0;
	D.Draw('#FFFF80', '#004080', false);
	$js_SBRSs
	$js_msgpercentASpos
	$js_msgpercent
	for (var i=0; i<22; i++) {
		//percent of messages that were AS positive at this score
		var y_AS=msgpercentASpos[i];
		//percent of messages that came in at this score
		var y_msg=msgpercent[i];
		//set up the screen area
		var x=D.ScreenX(i);
		//Set up the vertical bar
		new Bar(x, D.ScreenY(y_AS), x+15, D.ScreenY(0), '#0000FF', SBRSs[i], '#000000', 'Percent of messages determined to be Anti-Spam positive at this SBRS: '+y_AS);
		//add a '+' sign indicating the percent of total messages rcvd at this score
		new Dot(x+7, D.ScreenY(y_msg), 8, 1, '#000000', 'Percent of messages rcvd: '+y_msg);
	}
	document.close();
	</SCRIPT>";
	return $html;
} #sbrs_graph

#pie chart showing outcomes for messages which were fully accepted
sub sizes_graph {
	#determine percentages for each grouping
	foreach $subitem (sort sort_bytesizes keys %{$statistics2{'Sizes'}}) {
		next if $subitem !~ m/^\d+\s*\w+/;
		$percentbytes = &percentize(${$statistics2{'Sizes'}}{$subitem}{'bytes'} / ($statistics{'Sizes'}{'Total MB received'}*(1024*1024)));
		$percentmsgs = &percentize(${$statistics2{'Sizes'}}{$subitem}{'count'} / $statistics{'Messages'}{'received (system/splintered/external origin)'});
		#Populate the calculated percentage back in
		${$statistics2{'Sizes'}}{$subitem}{'percent_msgs'} = $percentmsgs;
		${$statistics2{'Sizes'}}{$subitem}{'percent_bytes'} = $percentbytes;
	}

	#get max %hit for graph sizing
	my $highest_percent = 0;
	my $items = 0;
	foreach my $item (keys %{$statistics2{'Sizes'}}) {
		next unless $statistics2{'Sizes'}{$item}{'percent_bytes'};
		$items++;
		if ($statistics2{'Sizes'}{$item}{'percent_bytes'} > $highest_percent) {
			$highest_percent = $statistics2{'Sizes'}{$item}{'percent_bytes'};
		}
		if ($statistics2{'Sizes'}{$item}{'percent_msgs'} > $highest_percent) {
			$highest_percent = $statistics2{'Sizes'}{$item}{'percent_msgs'};
		}
	}

	#physical sizing:
	my $x_L = 100;  #x Left
	my $x_R = 580; #x Right - rather hard-set than have it dynamic
	my $y_T = 20;  #y Top
	my $y_B = 240; #y Bottom

	my $html = '';
	$html = "  <SCRIPT Language='JavaScript' type='text/javascript'>
  document.open();
  var D=new Diagram();
  D.SetFrame($x_L, $y_T, $x_R, $y_B);
  D.SetBorder(0, $items-1, 0, $highest_percent+3);
  D.SetText('','', 'Message size and volume percentages');
  D.XScale=' ';
  D.YScale='%';
  D.SetGridColor('#cccccc');
  D.Draw('#FFEECC', '#663300', false);
  D.GetYGrid();
  _BFont='font-family:Verdana;font-size:10pt;line-height:13pt;';\n";

	#make the line showing increase of % of bytes as msg size grows
	my $X = 0;
	my $Y1 = 0;
	my $Y2 = 0;
	foreach my $subitem (sort sort_bytesizes keys %{$statistics2{'Sizes'}}) {
		next unless $statistics2{'Sizes'}{$subitem}{'percent_bytes'};
		if ($X == 0) { #initial case
			$X = 1;
			$Y1 = $statistics2{'Sizes'}{$subitem}{'percent_bytes'};
			next;
		}
		$Y2 = $statistics2{'Sizes'}{$subitem}{'percent_bytes'};

		$html .= "  new Line(D.ScreenX($X-1), D.ScreenY($Y1), D.ScreenX($X), D.ScreenY($Y2), '#cc99FF', 2, '\% bytes');\n";
		#verticle bar for the grid
#		$html .= "  new Line(D.ScreenX($X-1), D.ScreenY(0.3), D.ScreenX($X-1), D.ScreenY($highest_percent), '#cccccc', 2, '');\n";
		$X++;
		$Y1 = $Y2;
	}

	#make the line showing decline of msg #s as msg size grows
	$X = 0;
	$Y1 = 0;
	$Y2 = 0;
	foreach my $subitem (sort sort_bytesizes keys %{$statistics2{'Sizes'}}) {
		next unless $statistics2{'Sizes'}{$subitem}{'percent_msgs'};
		if ($X == 0) { #initial case
			$X = 1;
			$Y1 = $statistics2{'Sizes'}{$subitem}{'percent_msgs'};
			next;
		}
		$Y2 = $statistics2{'Sizes'}{$subitem}{'percent_msgs'};

		$html .= "  new Line(D.ScreenX($X-1), D.ScreenY($Y1), D.ScreenX($X), D.ScreenY($Y2), '#AAFF66', 2, '\% msgs');\n";
		$X++;
		$Y1 = $Y2;
	}
	$html .= " document.close();
  </SCRIPT>\n";
	return $html;
} #sizes_graph

#pie chart showing outcomes for messages which were fully accepted
sub msgoutcomes_pie {
	#determine percentages for my components
	my %component;
	$component{'Anti-Spam'}{'quantity'} = (($statistics{'Anti-Spam'}{'AS-positive messages'} || 0)
			+ ($statistics{'Anti-Spam'}{'AS-suspect messages'} || 0));
	$component{'Anti-Spam'}{'tooltip'} = "Messages determined to be Anti-Spam Positive and Suspect: $component{'Anti-Spam'}{'quantity'}";
	$component{'Anti-Virus'}{'quantity'} = ($statistics{'Anti-Virus'}{'AV-positive messages'} || 0);
	$component{'Anti-Virus'}{'tooltip'} = "Messages determined to be Anti-Virus Positive: $component{'Anti-Virus'}{'quantity'}";
	#$component{'Clean'}{'quantity'} = $statistics{'Messages'}{'Total received (external origin)'}
	# Changing from using the 'real' whole message as the count because
	#  in situations such as LDAP drop/bounce in the workqueue, they operate
	#  on the recipient level and it's impossible to map it back to messages
	#  and then the dropped-msg count can exceed the accepted count.  :(
	$component{'Clean'}{'quantity'} = ($statistics{'Recipients'}{'received'} || 0)
			- $component{'Anti-Spam'}{'quantity'}
			- $component{'Anti-Virus'}{'quantity'};
	if ($statistics{'LDAP'} and ($statistics{'LDAP'}{'Rcpts bounced'} or $statistics{'LDAP'}{'Rcpts dropped'})) {
		$component{'LDAP rej'}{'quantity'} = ($statistics{'LDAP'}{'Rcpts bounced'} || 0) + ($statistics{'LDAP'}{'Rcpts dropped'} || 0);
		$component{'LDAP rej'}{'tooltip'} = "Messages rejected or bounced by LDAPACCEPT in the workqueue: $component{'LDAP rej'}{'quantity'}";
		$component{'Clean'}{'quantity'} -= $component{'LDAP rej'}{'quantity'};
	}

	#Add in counts for everything dropped by filters
	foreach my $i (keys %{$statistics{'Filter Actions'}}) {
		next unless $i =~ m/Dropped by/;
		$component{'Filters'}{'quantity'} += $statistics{'Filter Actions'}{$i};
	}
	#Add the tooltip only if there is a quantity
	if ($component{'Filters'} && $component{'Filters'}{'quantity'}) {
		$component{'Filters'}{'tooltip'} = "Messages dropped by filters: $component{'Filters'}{'quantity'}";
		$component{'Clean'}{'quantity'} -= $component{'Filters'}{'quantity'};
	}
	$component{'Clean'}{'tooltip'} = "Clean messages: $component{'Clean'}{'quantity'}";

	#Account for messages sent to the quarantines.
	#In general these never come out, so don't try to account for that.
	#DO NOT count ones sent to ISQ, those are counted in Anti-spam section
	#$component{'Quarantined'}{'quantity'} = $statistics{'Messages'}{'Sent to IronPort Spam Quarantine'};

	#Add in counts for everything dropped by filters
	foreach my $i (keys %{$statistics{'Quarantines'}}) {
		if (($i =~ m/- Messages in/) and ($i !~ m/duplicated/)) {
			$component{'Quarantined'}{'quantity'} += $statistics{'Quarantines'}{$i};
		}
		if ($i =~ m/- Messages out/) {
			#There may some very slight overcount here because we don't know
			#if a released message was place in quarantine as a duplicate.
			#But that number is almost certainly trivially small.
			$component{'Quarantined'}{'quantity'} -= $statistics{'Quarantines'}{$i};
		}
	}
	#Add the tooltip only if there is a quantity
	if ($component{'Quarantined'} && $component{'Quarantined'}{'quantity'}) {
		$component{'Quarantined'}{'tooltip'} = "Number of messages sent to the System Quarantines: $component{'Quarantined'}{'quantity'}";
		$component{'Clean'}{'quantity'} -= $component{'Quarantined'}{'quantity'};
		#and modify tooltip
		$component{'Clean'}{'tooltip'} = "Clean messages: $component{'Clean'}{'quantity'}";
	}

	#add up quantities
	my $totalquantity = 0;
	foreach my $i (keys %component) {
		if (!$component{$i}{'quantity'}) {
			#print STDERR "component defined but no quantity for '$i'??\n";
			delete $component{$i};
			next;
		}
		$totalquantity += $component{$i}{'quantity'};
	}
	#now slot percentages
	foreach my $i (keys %component) {
		$component{$i}{'percent'} = int(($component{$i}{'quantity'}/$totalquantity)*10000)/100;
	}
	my $html = '';
	$html = "  <SCRIPT Language='JavaScript' type='text/javascript'>
  var P2=new Array();
  document.open();\n";
	my $piecount = 0;
	my $lastangle = 0;
	my $lasttop = 20;
	foreach my $pie (sort {$component{$b}{'quantity'} <=> $component{$a}{'quantity'}} keys %component) {
		$thisangle = $lastangle + $component{$pie}{'percent'} * 3.6;
		#Pie(xcent, ycent, offset, rad, angle0, angle1, color[, tooltip]);
		$html .= "  P2[$piecount]=new Pie(100,100,0,80,$lastangle," #angle0
			. "$thisangle," #angle1
			. "'$piecolors[$piecount]');\n"; #color
		#Bar(left, top, right, bottom, color, text, textcolor)
		$html .= "  new Bar(200,$lasttop,360,$lasttop+20,'$piecolors[$piecount]','$pie $component{$pie}{'percent'}\%','#000000','$component{$pie}{'tooltip'}', 'void(0)','MouseOver2($piecount)','MouseOut2($piecount)');\n";
		$lastangle = $thisangle;
		$lasttop += 30;
		$piecount++;
	}
	$html .= " document.close();
  function MouseOver2(i) { P2[i].MoveTo('','',10); }
  function MouseOut2(i) { P2[i].MoveTo('','',0); }
  </SCRIPT>\n";
	return $html;
} #msgoutcomes_pie

#pie chart showing HAT, AS, AV and clean numbers and percentage
sub overall_pie {
	#determine percentages for my 4 components
	my %component;
	if ($statistics{'HAT Policies'}{'~Total REJECT'} or $statistics{'HAT Policies'}{'~Total REFUSE'}) {
		$component{'HAT Reject'}{'quantity'} += $statistics{'HAT Policies'}{'~Total REJECT'} || 0;
		$component{'HAT Reject'}{'quantity'} += $statistics{'HAT Policies'}{'~Total REFUSE'} || 0;
		$component{'HAT Reject'}{'quantity'} += $statistics{'Recipients'}{'Rejected by Receiving Control'} || 0;
		#multiplier effect:
		$component{'HAT Reject'}{'quantity'} = int($component{'HAT Reject'}{'quantity'} * $optctl{'HATmultiplier'});
		$component{'HAT Reject'}{'tooltip'} = "Messages rejected at connection level by HAT definitions: $component{'HAT Reject'}{'quantity'}";
	}
	#See if there are any 'Rejectable' but allowed SG/Policy combinations:
	foreach my $sendergroup (keys %{$statistics{'HAT Policies'}}) {
		#only counting BLACKLIST items which are *not* reject or refuse hits:
		next unless $sendergroup =~ m/BLACKLIST (?!RE)/i;
		$component{'Rejectable'}{'quantity'} += $statistics{'HAT Policies'}{$sendergroup} || 0;
		$component{'Rejectable'}{'quantity'} = int($component{'Rejectable'}{'quantity'} * $optctl{'HATmultiplier'});
		$component{'Rejectable'}{'tooltip'} = "Msgs which *would* be rejected if configured to reject conns: $component{'Rejectable'}{'quantity'}";
	}

	$component{'Rcpt Reject'}{'quantity'} = ($statistics{'Recipients'}{'Rejected by RAT'} || 0)
				+ ($statistics{'Recipients'}{'Rejected by LDAPACCEPT'} || 0)
				+ ($statistics{'LDAP'}{'Rcpts rejected'} || 0)
				+ ($statistics{'LDAP'}{'Rcpts bounced'} || 0)
				+ ($statistics{'LDAP'}{'Rcpts dropped'} || 0);
	$component{'Rcpt Reject'}{'tooltip'} = "Messages rejected/dropped/bounced by RAT, LDAP: $component{'Rcpt Reject'}{'quantity'}";

	#Add in counts for everything rejected by the address parser
	foreach my $i (keys %{$statistics{'Address Parser'}}) {
		$component{'Other'}{'quantity'} += $statistics{'Address Parser'}{$i};
	}
	#Add in counts for everything rejected by sender verification
	foreach my $i (keys %{$statistics{'Sender Verification'}}) {
		$component{'Other'}{'quantity'} += $statistics{'Sender Verification'}{$i};
	}
	if ($component{'Other'}{'quantity'}) {
		$component{'Other'}{'tooltip'} = "Messages rej by Address Parser, Sender Verification: $component{'Other'}{'quantity'}";
	}

	$component{'Anti-Spam'}{'quantity'} = (($statistics{'Anti-Spam'}{'AS-positive messages'} || 0)
			+ ($statistics{'Anti-Spam'}{'AS-suspect messages'} || 0));
	$component{'Anti-Spam'}{'tooltip'} = "Messages determined to be Anti-Spam Positive and Suspect: $component{'Anti-Spam'}{'quantity'}";

	$component{'Anti-Virus'}{'quantity'} = ($statistics{'Anti-Virus'}{'AV-positive messages'} || 0);
	$component{'Anti-Virus'}{'tooltip'} = "Messages determined to be Anti-Virus Positive: $component{'Anti-Virus'}{'quantity'}";

	#$component{'Clean'}{'quantity'} = $statistics{'Messages'}{'Total received (external origin)'}
	# Changing from using the 'real' whole message as the count because
	#  in situations such as LDAP drop/bounce in the workqueue, they operate
	#  on the recipient level and it's impossible to map it back to messages
	#  and then the dropped-msg count can exceed the accepted count.  :(
	$component{'Clean'}{'quantity'} = ($statistics{'Recipients'}{'received'} || 0)
			- $component{'Anti-Spam'}{'quantity'}
			- $component{'Anti-Virus'}{'quantity'}
			- ($statistics{'LDAP'}{'Rcpts bounced'} || 0)
			- ($statistics{'LDAP'}{'Rcpts dropped'} || 0);
	$component{'Clean'}{'tooltip'} = "Clean messages: $component{'Clean'}{'quantity'}";
	#add up quantities
	my $totalquantity = 0;
	foreach my $i (keys %component) {
		#Remove the component if the quantity is 0
		if (!$component{$i}{'quantity'}) {
			delete $component{$i};
			next;
		}
		$totalquantity += $component{$i}{'quantity'};
	}
	#now slot percentages
	foreach my $i (keys %component) {
		$component{$i}{'percent'} = int(($component{$i}{'quantity'}/$totalquantity)*10000)/100;
	}
	my $html = '';
	$html = "  <SCRIPT Language='JavaScript' type='text/javascript'>
  var P=new Array();
  document.open();\n";
	my $piecount = 0;
	my $lastangle = 0;
	my $lasttop = 20;
	foreach my $pie (sort {$component{$b}{'quantity'} <=> $component{$a}{'quantity'}} keys %component) {
		$thisangle = $lastangle + $component{$pie}{'percent'} * 3.6;
		#Pie(xcent, ycent, offset, rad, angle0, angle1, color[, tooltip]);
		$html .= "  P[$piecount]=new Pie(100,100,0,80,$lastangle," #angle0
			. "$thisangle," #angle1
			. "'$piecolors[$piecount]');\n"; #color
		#Bar(left, top, right, bottom, color, text, textcolor)
		$html .= "  new Bar(200,$lasttop,350,$lasttop+20,'$piecolors[$piecount]','$pie $component{$pie}{'percent'}\%','#000000', '$component{$pie}{'tooltip'}', 'void(0)','MouseOver($piecount)','MouseOut($piecount)');\n";
		$lastangle = $thisangle;
		$lasttop += 30;
		$piecount++;
	}
	$html .= " document.close();
  function MouseOver(i) { P[i].MoveTo('','',10); }
  function MouseOut(i) { P[i].MoveTo('','',0); }
  </SCRIPT>\n";
	return $html;
} #overall_pie

#Build up a string consisting of JavaScript arrays representing the time periods construsted
sub make_JSperiods {
	my $astring = '';
	foreach my $period ('Minutes', 'Hourly', 'Daily') {
		next unless $statistics{$period};
		$astring .= "var myJS_$period = [";
		my $count = 0;
		foreach my $row (@{$statistics2{"$period-array"}}) {
			#construct header row first time thru:
			if ($count++ == 0) {
				$astring .= '[';
				#Get Date in there
				$astring .= "'Date',";
				foreach my $key (keys %{$statistics{$period}{$row}}) {
					$astring .= " '$key',";
				}
				#remove trailing ',', add closing ],
				$astring =~ s/,$/],\n/;
			}
			$astring .= '[';
			#Get Date in there
			$astring .= "'$row',";
			#Now construct the values into the array string:
			foreach my $val (values %{$statistics{$period}{$row}}) {
				#no quotes if fully numerical:
				if ($val =~ m/^\d+$/) {
					$astring .= " $val,";
				}
				else {
					$astring .= " '$val',";
				}
			}
			#remove trailing ',', add closing ],
			$astring =~ s/,$/],\n/;
		} #foreach time slice in this period

		#Close out the array:
		$astring =~ s/,\n$/];\n/;
	} #foreach period type

	#clean up some extra spaces:
	$astring =~ s/\[ /[/g;

	#if the string was populated, wrap it with the JS tags:
	if ($astring ne '') {
		$astring = "<SCRIPT Language='JavaScript1.2' type='text/javascript'>\n$astring\n</SCRIPT>";
	}
	return $astring;
} #make_JSperiods

sub beginhtml {
	my $periods_JSarray = &make_JSperiods();
	print HTML << "END";
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
  <HEAD>
    <TITLE>Generated mail_log statistics $statistics{' Time Frame of log entries processed'}{'begin'} - $statistics{' Time Frame of log entries processed'}{'end'}</TITLE>
    <SCRIPT Language="JavaScript" type="text/javascript" src="$optctl{'jsdir'}diagram.js"></SCRIPT>
   $periods_JSarray
  </HEAD>
  <BODY>
<!-- output generated by spamtowho version $VERSION -->

END
	return 1;
} #beginhtml

sub endhtml {
	print HTML << "END";
  </BODY>
</HTML>
END
	return 1;
} #endhtml


## this is the output required for ETIS Excel dashboard (Belgacom)
## code submission: Andy De Petter <andy\@secure-mail.be> 05/15/2007
sub etisoutput {
	my %months = ( "Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4, "May" => 5, "Jun" => 6, "Jul" => 7, "Aug" => 8, "Sep" => 9, "Oct" => 10, "Nov" => 11, "Dec" => 12 );
	foreach my $day (keys %{$statistics{'Daily'}}) {
		my $formatdate;
		if ($day =~ m/ ([A-Z][a-z]{2})\s+(\d+)\s+(\d+):(\d+):(\d+) (\d+)/) {
			my $dmon = $2;
			my $mon = $months{$1};
			my $year = $6;
			$formatdate = sprintf("%2d/%02d/%04d", $dmon, $mon, $year);
		}
		my $rejected = $statistics{'Daily'}{$day}{'HAT Policy REJECT'}*$optctl{'HATmultiplier'};
		my $processed = $rejected+$statistics{'Daily'}{$day}{'Recipients accepted'};
		print "$formatdate,$processed,$statistics{'Daily'}{$day}{'Anti-Spam positive'},$statistics{'Daily'}{$day}{'Anti-Virus positive'},$rejected";
		print "\n";
	}
	return 1;
} #etisoutput


sub newoutput {
	my $filestring;
	my @cleanup;
	my @deletelater;
	my $templatefile = "report.cfg";
	if (!&getfilestring($templatefile, \$filestring)) {
		print "File $templatefile does not exist for newreport format guideline.\n";
		exit 0;
	}
	foreach my $option (keys %optctl) {
		next unless $optctl{$option};
		#for each specified option, I want to keep the template area if it's configured.
		#So go thru and wipe out the surrounding matching template taglines
		my $uc_option = uc($option);
		$filestring =~ s/!$uc_option!//g;
		$filestring =~ s/!${uc_option}END!//g;
	}
	#And now for any that are left, delete the section
	$filestring =~ s/!(\w+?)!.+!\1END!//msg;
	#Now replace values
	foreach my $stat (sort sort_bynumfirst keys %statistics) {
		if ($stat =~ m/Senderbase received/) {
			$filestring =~ m/^(.*?!SBVALUE!.+?)$/m;
			my $line = $1;
			push @cleanup, $line; #needs to be deleted later
			$line =~ s/!SBVALUE!/$stat/;
			$line =~ s/!VALUE!/$statistics{$stat}/e;
			$filestring =~ s/^(.*?!SBVALUE!.+?)$/$line\n$1/m;
#	print '-' x 30 . "\n" . $sbline . "\n" . '-' x 30 . "\n";
			next;
		}
		elsif ($stat eq 'Connections in') {
			foreach my $conn (keys %{$statistics{$stat}}) {
				my $type;
				if ($conn =~ m/^In on /) {
					$type = 'IN';
				}
				elsif ($conn =~ m/^Out on /) {
					$type = 'OUT';
				}
				$filestring =~ m/^(.*?!${type}_INTERFACE!.+?)$/m;
				my $line = $1;
				push @cleanup, $line; #needs to be deleted later
				$line =~ s/!${type}_INTERFACE!/$conn/;
				$line =~ s/!VALUE!/$statistics{$stat}{$conn}/e;
				$filestring =~ s/^(.*?!${type}_INTERFACE!.+?)$/$line\n$1/m;
			}
			next;
		}
		elsif ($stat eq 'Connection Errors') {
			foreach my $conn (keys %{$statistics{$stat}}) {
				$filestring =~ m/^(.*?!CONNERR!.+?)$/m;
				my $line = $1;
				push @cleanup, $line; #needs to be deleted later
				$line =~ s/!CONNERR!/$conn/;
				$line =~ s/!VALUE!/$statistics{$stat}{$conn}/e;
				$filestring =~ s/^(.*?!CONNERR!.+?)$/$line\n$1/m;
			}
		}
		elsif ($stat eq 'Brightmail') {
			foreach my $conn (keys %{$statistics{$stat}}) {
				#Flatten down to first level so that the default case gets it
				$statistics{$conn} = $statistics{$stat}{$conn};
				push @deletelater, $conn;
			}
		}
		elsif ($stat eq 'Anti-Virus') {
			foreach my $conn (keys %{$statistics{$stat}}) {
				#Flatten down to first level so that the default case gets it
				$statistics{$conn} = $statistics{$stat}{$conn};
				push @deletelater, $conn;
			}
		}
		elsif ($stat eq 'ICID') {
			#Do this one for the TLS stuff
			foreach my $conn (keys %{$statistics{$stat}}) {
				#Flatten down to first level so that the default case gets it
				$statistics{$conn} = $statistics{$stat}{$conn};
				push @deletelater, $conn;
			}
		}
	}
	#redo the iteration with the new stuff that mighta gotten shoved on
	foreach my $stat (sort sort_bynumfirst keys %statistics) {
		#Default case
		if ($filestring =~ m/^(.*?$stat.+?)!VALUE!.*?$/m) {
			my $match1 = $1;
			next if ref $statistics{$stat} eq 'HASH'; #not coping with deeper undef structures
			my $cv = &commaize($statistics{$stat}); #pretty
			$filestring =~ s/($match1)!VALUE!/$1$cv/m;
		}
		else {
			if ($optctl{'debug'}) {
#	print "No match for $stat\n";
			}
		}
	}
	#remove stuff that got put on for newoutput
	foreach (@deletelater) {
		delete $statistics{$_};
	}
	#Remove all leftover template-holding lines
	foreach my $line (@cleanup) {
		$filestring =~ s/$line//;
	}
	$filestring =~ s/!VALUE!/0/g;
	$filestring =~ s/!\w+!//g;
	#try to get rid of extra hanging empty lines
	$filestring =~ s/\n\s*\n\s*\n/\n\n/g;
	print $filestring;
	return 1;
} #newoutput

#A function used by sort to sort 'from' addresses as desired
sub sort_froms {
	if ((ref($statistics{$area}{$a}) ne 'HASH') or (ref($statistics{$area}{$b}) ne 'HASH')) {
		return -1;
	}
	#Setting these counts to 0 can be necessary when the data was collated
	# for -per_domain or -per_rcpt on the outbound side but the message was
	# from a rewritten one, meaning that the same domain/rcpt did not get an 'inbound' count.
	if (!$statistics{$area}{$a}{'count'}) {
		if ($optctl{'debug'}) {
			print STDERR "uninit for statistics->$area->$a->count - setting to 0\n";
		}
		$statistics{$area}{$a}{'count'} = 0;
	}
	if (!$statistics{$area}{$b}{'count'}) {
		if ($optctl{'debug'}) {
			print STDERR "uninit for statistics->$area->$b->count - setting to 0\n";
		}
		$statistics{$area}{$b}{'count'} = 0;
	}
	if ($statistics{$area}{$a}{'count'} == $statistics{$area}{$b}{'count'}) {
		return (-1 * ($statistics{$area}{$a} cmp $statistics{$area}{$b}));
	}
	return(-1 * ($statistics{$area}{$a}{'count'} <=> $statistics{$area}{$b}{'count'}));
} #sort_froms

1;

