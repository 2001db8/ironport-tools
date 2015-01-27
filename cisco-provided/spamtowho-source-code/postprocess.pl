#Tomki
#Feb 2004

sub generic_postprocessing {
	my ($section, $result) = @_;
	my ($typename, $shortname);
	if (($section eq 'Brightmail') or ($section eq 'CASE') or ($section eq 'Cloudmark') or ($section eq 'Anti-Spam')) {
		$typename = 'anti-spam';
		$shortname = 'AS';
	}
	if ($section eq 'Anti-Virus') {
		$typename = 'anti-virus';
		$shortname = 'AV';
	}
	my $type_res = "$shortname-$result";
	if (!$statistics{$section} or !$statistics{$section}{"$shortname Total messages"}) {
		return 0;
	}
	if ($statistics{$section}{'Bytes scanned (Total)'}) { #worked this section yet?
		#Average = Total/# instances
		$statistics{$section}{'Average message byte size'} = $statistics{$section}{'Bytes scanned (Total)'} / $statistics{$section}{"$shortname Total messages"};
		delete $statistics{$section}{'Bytes scanned (Total)'};
	}

	if ($statistics{$section}{"$type_res messages"}) {
		$statistics{$section}{"Average message byte size ($result)"} = $statistics{$section}{"Bytes scanned ($result)"} / $statistics{$section}{"$type_res messages"};
		delete $statistics{$section}{"Bytes scanned ($result)"};
	}

	return 1 unless $optctl{'timings'};
	if ($statistics{$section}{"$type_res messages"}) {
		#$statistics{$section}{"Time from injection to $shortname scan completion (avg $type_res)"} = $statistics{$section}{"Total time messages spent in the system until $shortname scan completion ($result)"} / $statistics{$section}{"$type_res messages"};
	}

	#$timings{"Time from injection to $shortname scan completion (avg all)"} = $statistics{$section}{"Time from injection to $shortname scan completion (avg all)"};
	return 1;
} #generic_postprocessing

sub postprocess_seats {
	return 0 unless $optctl{'seat-count'};
	foreach my $type (keys %{$statistics2{'feature_use'}}) {
		$statistics{'Seats in use'}{$type} = scalar(keys %{$statistics2{'feature_use'}{$type}});
	}
}

sub postprocess_AS {
	#ASstats gets incremented for every type of Brightmail/CASE log line.
	#If it's still 0 or 1, there were no Brightmail/CASE things in the log.
	if ($optctl{'ASstats'} < 2) {
		$optctl{'ASstats'} = 0;
		return 0;
	}
	foreach my $type ('positive', 'negative', 'suspect', 'reinsert') {
		&generic_postprocessing('Brightmail', $type);
		&generic_postprocessing('CASE', $type);
		&generic_postprocessing('Anti-Spam', $type);
	}

	if ($optctl{'timings'}) {
#		$statistics{'Brightmail'}{'Time from injection to AS scan completion (median)'} = $AStimeArray[int($#AStimeArray/2)];
#		$timings{'Time from injection to AS scan completion (median)'} = $AStimeArray[int($#AStimeArray/2)];
#		$statistics{'Brightmail'}{'Time from injection to AS scan completion (slowest 75th percentile)'} = $AStimeArray[int($#AStimeArray * 0.75)];
#		$timings{'Time from injection to AS scan completion (slowest 75th percentile)'} = $AStimeArray[int($#AStimeArray * 0.75)];
#		$statistics{'Brightmail'}{'Time from injection to AS scan completion (slowest)'} = $AStimeArray[$#AStimeArray];
#		$timings{'Time from injection to AS scan completion (slowest)'} = $AStimeArray[$#AStimeArray];
#		undef @AStimeArray; #no longer necessary
	}
	return 1;
} #postprocess_AS


sub postprocess_AV {
	if ($optctl{'AVstats'} < 2) {
		$optctl{'AVstats'} = 0;
		return 0;
	}
	foreach my $type ('positive', 'negative', 'encrypted', 'repaired', 'unscannable') {
		&generic_postprocessing('Anti-Virus', $type);
	}

	if ($optctl{'timings'}) {
#		$statistics{'Anti-Virus'}{'Time from injection to AV scan completion (median)'} = $avtimeArray[int($#avtimeArray/2)];
#		$timings{'Time from injection to AV scan completion (median)'} = $avtimeArray[int($#avtimeArray/2)];
#		$statistics{'Anti-Virus'}{'Time from injection to AV scan completion (slowest 75th percentile)'} = $avtimeArray[int($#avtimeArray * 0.75)];
#		$timings{'Time from injection to AV scan completion (slowest 75th percentile)'} = $avtimeArray[int($#avtimeArray * 0.75)];
#		$statistics{'Anti-Virus'}{'Time from injection to AV scan completion (slowest)'} = $avtimeArray[$#avtimeArray] . " MID $avslowestMID";
#		$timings{'Time from injection to AV scan completion (slowest)'} = $avtimeArray[$#avtimeArray] . " MID $avslowestMID";
#		undef @avtimeArray; #no longer necessary
	}
	return 1;
} #postprocess_AV


sub postprocess_sizes {
	return 0 unless $statistics{'Sizes'};
	$statistics{'Sizes'}{'Average message size'} = $statistics{'Messages'}{'received (system/splintered/external origin)'} ? $statistics{'Sizes'}{'Total bytes received'} / $statistics{'Messages'}{'received (system/splintered/external origin)'} : 0;
	#Make it an int, no decimal places
	$statistics{'Sizes'}{'Average message size'} = int($statistics{'Sizes'}{'Average message size'});
	$statistics{'Sizes'}{'Total MB received'} = (int(($statistics{'Sizes'}{'Total bytes received'} || 0)* 100 / (1024*1024)) / 100) || .01;
	$statistics{'Sizes'}{'Total MB sent'} = (int(($statistics{'Sizes'}{'Total bytes sent'} || 0) * 100 / (1024*1024)) / 100) || .01;
	return 1;
} #postprocess_sizes

sub postprocess_timings {
	if (!$optctl{'timings'}) {
		return 0;
	}
#	$statistics{'Timings'}{'Time from injection to scan completion (median)'} = $alltimingsArray[int($#alltimingsArray/2)];
#	$timings{'Time from injection to scan completion (median)'} = $alltimingsArray[int($#alltimingsArray/2)];
#	$statistics{'Timings'}{'Time from injection to scan completion (slowest 75th percentile)'} = $alltimingsArray[int($#alltimingsArray * 0.75)];
#	$timings{'Time from injection to scan completion (slowest 75th percentile)'} = $alltimingsArray[int($#alltimingsArray * 0.75)];
#	$statistics{'Timings'}{'Time from injection to scan completion (slowest)'} = $alltimingsArray[$#alltimingsArray];
#	$timings{'Time from injection to scan completion (slowest)'} = $alltimingsArray[$#alltimingsArray];
	return 1;
}

sub postprocess_sql {
	return 0 unless $optctl{'sql'};
	while (my ($table, $file) = each %tmp_sqlfiles) {
		&load_sql_data($table, $file);
	#	unlink $file;
	}
	return 1;
}

#This is to clean out leftovers which didn't get written out yet since the
# buffer size trigger hasn't gotten hit yet
sub postprocess_msg_csv {
	return 0 unless ($optctl{'msg-csv'} and $optctl{'msg-csv-cachesize-count'});
	no warnings;
	my $globref = *{$tmpfh{'msg-csv'}};
	print $globref $msg_csv_cache; #print out the buffer
	return 1;
}

1;


