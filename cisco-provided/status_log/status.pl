#!/usr/bin/perl -w

# Copyright Â© 2003-2006 IronPort Systems, Inc. All rights reserved.
# Last modified by Tomki, April 04 2006
# Unsupported utility script
# Usage:
# ./status.pl < status.log.current > status.csv
# Now open status.csv with a spreadsheet program such as Gnumeric or KSpread or Excel
# Most common next step: make a chart with these columns:
# Time    Delta InjRcp    Delta CmpRcp     Delta MsgIn     WorkQ
#
# Supported versions:
# known good up to AsyncOS 4.6.0-232 (however perhaps not below 4.0.2)

require 5.006;
use strict;
my $VERSION = "1.12";
use Getopt::Long;

our %graphables = ('Delta Recipients Received' => 1,
		'Delta Recipients Completed' => 1,
		'Delta Messages in' => 1,
		'Delta Messages Attempted' => 1,
		'Delta Connections Attempted' => 1,
		'CPULd' => 1,
		'TotalLd' => 1,
		'DskIO' => 1,
		'RAMUtil' => 1,
		'WorkQ' => 1);

our $pathsep = '/'; #does this continue to work alright on Windoze?
my %monthmap = (
 'Jan' => 1, 'Feb' => 2, 'Mar' => 3, 'Apr' => 4,  'May' => 5,  'Jun' => 6,
 'Jul' => 7, 'Aug' => 8, 'Sep' => 9, 'Oct' => 10, 'Nov' => 11, 'Dec' => 12
);

our %graphitems; #to hold graph items confirmed for use on this run

our %optctl;
#set defaults
$optctl{'output'} = 0; #output file specification
$optctl{'csv'} = 0;
$optctl{'js'} = 1;
$optctl{'colors'} = 0;
$optctl{'debug'} = 0;
GetOptions (\%optctl, "help", "conf=s", "js-filename=s", "csv-filename=s", "csv!", "js!", "colors=s@", "showgraphables", "debug+");
&process_opts(\%optctl);

our @logfiles; #populated in process_opts

#Regular expression to match Mail Log or Status log lines
my $statusregex = '^(\w\w\w) (\w\w\w) (\d+| \d+) (\d+):(\d+):(\d+) (\d+) Info: Status: (.*)$';

my $d_rcprcv = -1; #Delta Recipients Received
my $d_rcpcmp = -1; #Delta Recipients Completed
my $d_msgin = -1; #Delta Messages In
my $d_msgattempt = -1; #Delta Messages attempted
my $d_conns = -1; #Delta Messages attempted
my $d_sb = -1; #Delta soft bounces
my $d_hb = -1; #Delta hard bounces

my @graphdata; #will hold the things I want to graph

#Other versions of logfiles..
#More work will need to be done if any of the variable names used in the Custom
# fields area change.

my @statusvars; #Will be populated with field names
my $linecount = 0;

my $goodinputs = 0;
foreach my $infile (@ARGV) {
	if (!-e $infile or !-r $infile or !-f $infile) {
		print STDERR "Specified input '$infile' is unusable.\n";
		next;
	}
	$goodinputs++;
}
if ($goodinputs == 0) {
	print STDERR "No usable input files specified.  Cannot continue.\n";
	exit(0);
}

if (($optctl{'csv'}) && open(CSVFILE, ">$optctl{'csv-filename'}")) {
	print STDERR "Writing $optctl{'csv-filename'}\n";
}
elsif ($optctl{'csv'}) { #couldn't open the file?
	print STDERR "Could not open file '$optctl{'csv-filename'}' for writing: $!\n";
	exit(0);
}
else {
}

while (my $line = <>) {
	if ($line !~ m/$statusregex/) {
		#only looking at status lines
		next;
	}
	if ($optctl{'debug'} > 1) {
		print STDERR "Debug: $line\n";
	}
	my $wday = $1;
	my $month = $2;
	my $day = $3;
	my $hour = $4;
	my $minute = $5;
	my $second = $6;
	my $year = $7;
	my $status_info = $8;
	my %v;

	# Convert values of all the status info into assoc array
	my @values = split(/\s/, $status_info);
	while(@values) {
		my $name = shift @values; #first item is identifier/name
		my $value = shift @values;#second is the identifier's value
		$v{$name} = "$value";
	}

	#Initial Deltas will be the first number seen.
	#Check for delta of Recipients Received
	if(($d_rcprcv == -1) || ($v{'InjRcp'} < $d_rcprcv)) {
		$d_rcprcv = $v{'InjRcp'};
	}
	#Check for delta of Recipients Completed
	if(($d_rcpcmp == -1) || ($v{'CmpRcp'} < $d_rcpcmp)) {
		$d_rcpcmp = $v{'CmpRcp'};
	}
	#Check for delta of Messages in
	if(($d_msgin == -1) || ($v{'InjMsg'} < $d_msgin)) {
		$d_msgin = $v{'InjMsg'};
	}
	#Check for delta of Message attempts (indicated by MID change)
	if(($d_msgattempt == -1) || ($v{'CrtMID'} < $d_msgattempt)) {
		$d_msgattempt = $v{'CrtMID'};
	}
	#Check for delta of connections (indicated by ICID change)
	if(($d_conns == -1) || ($v{'CrtICID'} < $d_conns)) {
		$d_conns = $v{'CrtICID'};
	}
	#Check for delta of Soft Bounces
	if(($d_sb == -1) || ($v{'SftBncEvnt'} < $d_sb)) {
		$d_sb = $v{'SftBncEvnt'};
	}
	#Check for delta of Hard Bounces
	if(($d_hb == -1) || ($v{'HrdBncRcp'} < $d_hb)) {
		$d_hb = $v{'HrdBncRcp'};
	}

	#Print out Custom fields for csv output
	my $datestr = sprintf("%02d/%02d/%4d %02d:%02d:00", $monthmap{$month}, $day, $year, $hour, $minute, $second);

	if ($optctl{'csv'}) {
		if ($linecount < 1) { #first line, print out headers!
			#Custom fields
			print CSVFILE "Time,Delta InjRcp,Delta CmpRcp,Delta MsgIn,Delta SftBncEvnt,Delta HrdBncRcp,";
			my $statusline = $status_info; #make a copy to munge
			$statusline =~ s/ \d+G?\b/ /g;  #get ones sometimes with a 'G' end
			@statusvars = split(/\s+/, $statusline);
			#print header fields for All other fields (custom done above)
			print CSVFILE join(',', @statusvars), "\n";
		}
		print CSVFILE "$datestr,";
		print CSVFILE $v{'InjRcp'} - $d_rcprcv, ",", $v{'CmpRcp'} - $d_rcpcmp, ",";
		print CSVFILE $v{'InjMsg'} - $d_msgin, ",";
		print CSVFILE $v{'SftBncEvnt'} - $d_sb, ",", $v{'HrdBncRcp'} - $d_hb, ",";

		my $count = 0;
		#Print out Normal fields for csv output
		foreach my $var (@statusvars) {
			if (!defined($v{$var})) {
				print STDERR "Error: no item $var for hash '\$v'\n";
				print STDERR "Line:\n\t$line\n\n";
				print STDERR "Vars found:\n\t@statusvars\n";
				print STDERR "Cannot continue\n";
				exit 1;
			}
			print CSVFILE "$v{$var}";
			if ($count++ < $#statusvars) {
				print CSVFILE ","; #more to come!
			}
		}
		print CSVFILE "\n";
	} #if csv

	#Generate pretty graph output?  Then populate necessary data arrays with the interesting data
	if ($optctl{'js'}) {
		my %tmphash = ();
		$tmphash{'date'} = $datestr;
		if ($graphitems{'Delta Recipients Received'}) {
			$tmphash{'Delta Recipients Received'} = $v{'InjRcp'} - $d_rcprcv;
		}
		if ($graphitems{'Delta Recipients Completed'}) {
			$tmphash{'Delta Recipients Completed'} = $v{'CmpRcp'} - $d_rcpcmp;
		}
		if ($graphitems{'Delta Messages in'}) {
			$tmphash{'Delta Messages in'} = $v{'InjMsg'} - $d_msgin;
		}
		if ($graphitems{'Delta Messages Attempted'}) {
			$tmphash{'Delta Messages Attempted'} = $v{'CrtMID'} - $d_msgattempt;
		}
		if ($graphitems{'Delta Connections Attempted'}) {
			$tmphash{'Delta Connections Attempted'} = $v{'CrtICID'} - $d_conns;
		}
		if ($graphitems{'CPULd'}) {
			$tmphash{'CPULd'} = $v{'CPULd'};
		}
		if ($graphitems{'TotalLd'}) {
			$tmphash{'TotalLd'} = $v{'TotalLd'};
		}
		if ($graphitems{'DskIO'}) {
			$tmphash{'DskIO'} = $v{'DskIO'};
		}
		if ($graphitems{'RAMUtil'}) {
			$tmphash{'RAMUtil'} = $v{'RAMUtil'};
		}
		if ($graphitems{'WorkQ'}) {
			$tmphash{'WorkQ'} = $v{'WorkQ'};
		}
		#Array of anonymous hashes
		push @graphdata, \%tmphash;

		if ($optctl{'debug'} > 1) {
			use Data::Dumper;
			print STDERR "=> linecount: $linecount\n";
			print STDERR Dumper(%{$graphdata[$linecount]});
			sleep 1;
		}
	} #if js

	#set these for computation of deltas in next round
	$d_rcprcv = $v{'InjRcp'};
	$d_rcpcmp = $v{'CmpRcp'};
	$d_msgin = $v{'InjMsg'};
	$d_msgattempt = $v{'CrtMID'};
	$d_conns = $v{'CrtICID'};
	$d_sb = $v{'SftBncEvnt'};
	$d_hb = $v{'HrdBncRcp'};
	$linecount++;
} #while <>

if ($optctl{'csv'}) {
	#close out the filehandle used for writing in the 'while' iteration
	close(CSVFILE);
}

if ($optctl{'js'} && open(FILE, ">$optctl{'js-filename'}")) {
	print STDERR "Writing $optctl{'js-filename'}\n";
	&beginhtml();

	#y_move is an advisory number of pixels further down the next diagram should be placed
	my $y_move = 80; #initial position
	foreach my $graph_array (@{$optctl{'graphs'}}) {
		if ($optctl{'debug'}) {
			print STDERR "Calling multigraph with graph_array @{$graph_array}\n";
		}
		$y_move += &multigraph(
			$graph_array,
			{'x1' => 80,
			 'y1' => $y_move,
			 'height' => 240,
			 'width' => 700
			}
		) + 50;
	}

	&endhtml();
	close(FILE);
}
elsif ($optctl{'js'}) { #couldn't open the file?
	print STDERR "Could not open file '$optctl{'js-filename'}' for writing: $!\n";
}
else {
}

sub multigraph {
	my ($graphitems_array, $sizes_hash) = @_;
	no strict 'refs';
	my $x1 = $$sizes_hash{'x1'} || 80;
	my $y1 = $$sizes_hash{'y1'} || 80;
	my $x2 = $x1 + ($$sizes_hash{'width'} || 700);
	my $y2 = $y1 + ($$sizes_hash{'height'} || 240);

	#Iterate over all data in graphdata to find how high the y-axis scale needs to be
	my $highest = 0;
	foreach my $hashrow (@graphdata) {
		foreach my $item (@{$graphitems_array}) {
			#use 'defined' because it could be 0
			if (!defined($$hashrow{$item})){
				print STDERR "Err - no hashrow for '$item'?   @{$graphitems_array}\n";
				print STDERR "\t all hashrow items:\n";
				foreach my $h (keys %{$hashrow}) {
					print "\t\t found '$h' - value '$$hashrow{$item}'\n";
				}
			}
			if ($$hashrow{$item} > $highest) {
				$highest = $$hashrow{$item};
				if ($optctl{'debug'}) {
					print "highest number is in '$item': $highest\n";
				}
			}
		}
	}
	print FILE << "END";
<SCRIPT Language="JavaScript" type="text/javascript">
END
	&make_js_scalefunc();
	print FILE << "END";
	function multigraph(vv){ return("<nobr>"); }
	document.open();
	var D=new Diagram();
	D.SetFrame($x1, $y1, $x2, $y2);
	D.SetBorder(1, $#graphdata+1, 0, $highest);
	D.SetText("","", "${$graphdata[0]}{'date'} to ${$graphdata[-1]}{'date'}");
	D.XScale="function MyXScale";
	D.SetGridColor("#cccccc");
	D.Draw("#FFEECC", "#663300", false);
	var t;
	D.GetYGrid();
	_BFont="font-family:Verdana;font-size:10pt;line-height:13pt;";
	for (t=D.YGrid[0]; t<=D.YGrid[2]; t+=D.YGrid[1])
		  new Bar(D.right+6, D.ScreenY(t)-8, D.right+6, D.ScreenY(t)+8, "", multigraph(t), "#663300");
	var colormap = new Array(4);
	colormap[0] = '#00EE11';
	colormap[1] = '#009966';
	colormap[2] = '#FF9F66';
	colormap[3] = '#FF0000';
	colormap[4] = '#0000FF';
	colormap[5] = '#000000';
END
	my $js_X1_str = "\tvar X1 = new Array(";
	my $js_X2_str = "\tvar X2 = new Array(";
	my $js_Y1_str = "\tvar Y1 = new Array(";
	my $js_Y2_str = "\tvar Y2 = new Array(";
	my $js_linecolor = "\tvar linecolor = new Array(";

	#trim down to 3600 pts if there are more..
	# without this the file rapidly grows beyond 1MB
	my $step = 1;
	my $step_pos = 0;
	if ($#graphdata > 3600) {
		$step = $#graphdata / 3600;
		if ($optctl{'debug'}) {
			print STDERR "step for @{$graphitems_array} is $step\n";
		}
	}

	#Set up a holding var for each item-type last y-position
	# and put the starting numbers in
	my %newY = ();
	my %lastY = ();
	my %lastX = ();
	foreach my $item (@{$graphitems_array}) {
		$newY{$item} = ${$graphdata[0]}{$item}; #set starting Y-coordinate
		$lastX{$item} = 1; #set starting X-coordinate (the js does '1')
		if ($optctl{'debug'}) {
			print STDERR "Starting number for $item: $newY{$item}\n";
		}
	}

	my $count = 0;
	foreach my $hashrow (@graphdata) {
		#Skip processing this one unless we've incremented past the step increment step_pos
		if (($count++) < $step_pos) {
			next;
		}
		#Store the position of the last item used
		#$count has to increment past this before another line is drawn
		$step_pos += $step;

		my $colorcount = 0;
		foreach my $item (@{$graphitems_array}) {
			#Assign the old 2nd y-pos into the new 1st y-pos for this new line
			$lastY{$item} = $newY{$item};
			#is the new y-pos the same as the putative 'new' one here?
			# if *not*, update the arrays so it's drawn.  Otherwise don't,
			# when a changed pt is found the line made will go btwn the old and this new changed one
			# - if the x-step is more than one use a flat line to cover the distance
			if ($lastY{$item} != $$hashrow{$item}) { #Value changed?
				#is the x-step more than 1?
				if ($count - $lastX{$item} > 1) {
					#set up a flat line from (oldx, oldy) to (newx - 1, oldy)
					$js_X1_str .= "$lastX{$item},";
					$js_X2_str .= ($count - 1) . ",";
					$js_Y1_str .= "$lastY{$item},";
					$js_Y2_str .= "$lastY{$item},";
					$js_linecolor .= "$colorcount,";
					if ($optctl{'debug'}) {
						print STDERR "flat - drawing color $colorcount line from ($lastX{$item}, $lastY{$item}) to (" . ($count-1) . ", $lastY{$item}) for $item\n";
					}
					$lastX{$item} = $count - 1;
				}
				#Assign this new y-pos into storage for use/check in next iteration
				$newY{$item} = $$hashrow{$item}; #new point
				#Assign the old 2nd x-pos into the new 1st x-pos for this new line
				$js_X1_str .= "$lastX{$item},";
				#Assign the new 1st x-pos for this new line
				$js_X2_str .= "$count,";
				#Assign the old 2nd y-pos into the new 1st y-pos for this new line
				$js_Y1_str .= "$lastY{$item},";
				#Assign the new 2nd y-pos for this new line
				$js_Y2_str .= "$newY{$item},";
				$js_linecolor .= "$colorcount,";
				if ($optctl{'debug'}) {
					print STDERR "drawing color $colorcount line from ($lastX{$item}, $lastY{$item}) to ($count, $newY{$item}) for $item\n";
				}
				$lastX{$item} = $count;
			}
			elsif ($count-1 == $#graphdata) { #last row of data and value didn't change?
				#draw flat lines
				$js_X1_str .= "$lastX{$item},";
				$js_X2_str .= $count . ",";
				$js_Y1_str .= "$lastY{$item},";
				$js_Y2_str .= "$lastY{$item},";
				$js_linecolor .= "$colorcount,";
				if ($optctl{'debug'}) {
					print STDERR "end - drawing color $colorcount line from ($lastX{$item}, $lastY{$item}) to ($count, $lastY{$item}) for $item\n";
				}
			}
			$colorcount++;
		} #foreach item (graphitems_array)
	} #foreach hashrow (@graphdata)

	#Replace trailing commas with )
	$js_X1_str =~ s/,$/);/;
	$js_X2_str =~ s/,$/);/;
	$js_Y1_str =~ s/,$/);/;
	$js_Y2_str =~ s/,$/);/;
	$js_linecolor =~ s/,$/);/;
	#And print the JS arrays into the file for use in the followup iteration
	print FILE "$js_X1_str\n";
	print FILE "$js_X2_str\n";
	print FILE "$js_Y1_str\n";
	print FILE "$js_Y2_str\n";
	print FILE "$js_linecolor\n";

	print FILE << "END";
	//iterate over all of the array items, drawing pt to pt lines
	for (var i = 0 ; i < X1.length ; i++) {
		new Line(D.ScreenX(X1[i]), D.ScreenY(Y1[i]), D.ScreenX(X2[i]), D.ScreenY(Y2[i]), colormap[linecolor[i]], 2, '');
	}
END
	#Generate the js for legend for the lines drawn
	my $colorcount = 0;
	my $legend_x1 = $x2 + 20;
	my $legend_x2 = $legend_x1 + 200;
	my $legend_y1 = $y1 + 20;
	my $legend_height = 20;
	my $legend_separation = 7;
	foreach my $item (@{$graphitems_array}) {
		print FILE "\tnew Bar($legend_x1, "
			. ($legend_y1 + ($legend_height * $colorcount) + ($legend_separation * $colorcount))
			. ", $legend_x2, "
			. (($legend_y1 + $legend_height) + ($legend_height * $colorcount) + ($legend_separation * $colorcount))
			. ", colormap[$colorcount], '$item', '#FFFFFF');\n";
		$colorcount++;
	}
	print FILE << "END";
	document.close();
</SCRIPT>
END
	return $$sizes_hash{'height'}; #return height used
}

sub make_js_scalefunc {
	print FILE << "END";
	var scalecount = 0;
	function MyXScale(xx) {
		var retval;
END
	my $lastdate = '';
	for (my $i = 0; $i < 8; $i++) {
		#Get date in this 1/8th position in the array
		my $date = ${$graphdata[int(($#graphdata / 7) * $i)]}{'date'};
		#keep only HH:MM
		$date =~ s/^.*(.{5})\/\d{4}\s(\S+):\d{2}$/$2/;
		if ($lastdate eq $1) {
			$lastdate = $1;
		}
		else {
			$lastdate = $1;
			$date = "$1 $date";
		}
		#print out the derived JS logic for the webpage
		print FILE << "END";
		//using '7-$i' instead of just '$i' because with the latter it seems that the scale is
		// emplaced from right to left
		if (scalecount == 7 - $i) {
			retval='$date';
			//document.write('xx: ' + xx + ' i: ' + $i + ' date: ' + '$date ' + '<br>');
		}
END
	}
	print FILE << "END";
		scalecount = scalecount+1;
		return retval;
	}
END
}

sub beginhtml {
	print FILE << "END";
<HTML>
<HEAD>
  <TITLE>status graphing</TITLE>
  <SCRIPT Language="JavaScript" type="text/javascript" src="diagram.js"></SCRIPT>
</HEAD>
<BODY>
<!-- output generated by status.pl version $VERSION -->
<!-- $0 -->
<!-- graphdata\n@graphdata -->
Please make use of IronPort's KB - <A HREF="http://support.ironport.com/kb/" target="blank">http://support.ironport.com/kb/</A><BR>

END
}

sub endhtml {
	print FILE << "END";
	<DIV position: position: relative; bottom: 0px; left: 50px>
Questions about this output?  Please see the accompanying README.txt file.<BR>
</DIV>
</BODY>
</HTML>
END
}


sub process_opts {
	my $optctl = $_[0];

	#Immediate exit situations
	if ($$optctl{'help'}) {
		&printhelp();
	}
	elsif ($$optctl{'showgraphables'}) {
		print "These are the items you may use in a conf file for graphing:\n";
		foreach my $item (sort keys %graphables) {
			print "\t$item\n";
		}
		exit(0);
	}
	elsif ($$optctl{'version'}) {
		print STDERR "program version $VERSION\n";
		exit(0);
	}
	elsif ($$optctl{'support'}) {
		print STDERR "This utility is UNSUPPORTED.\n";
		exit(0);
	}
	#Check validity of provided 'output' flag
	if ($$optctl{'js-filename'} or $$optctl{'csv-filename'}) {
		if (($$optctl{'js-filename'} and (-e "$$optctl{'js-filename'}"))
				or ($$optctl{'csv-filename'} and (-e "$$optctl{'csv-filename'}"))) {
			print STDERR "Specified output file already exists.\n";
			exit(1);
		}
		elsif (($$optctl{'js-filename'} and ($$optctl{'js-filename'} !~ m/\w/))
				or ($$optctl{'csv-filename'} and ($$optctl{'csv-filename'} !~ m/\w/))) {
			print STDERR "Incomprehensible output filename specified.\n";
			exit(1);
		}
		if ($$optctl{'js-filename'} and not $$optctl{'js'}) {
			#assume implicit
			$$optctl{'js'} = 1;
		}
		if ($$optctl{'csv-filename'} and not $$optctl{'csv'}) {
			#assume implicit
			$$optctl{'csv'} = 1;
		}
	}
	elsif (!$$optctl{'js'} && !$$optctl{'csv'}) {
		print STDERR "You must have 1 type of output.\n";
		exit(1);
	}
	if ($$optctl{'js'} and not $$optctl{'js-filename'}) {
		#set up a default
		$$optctl{'js-filename'} = "status-js-$$.html";
	}
	if ($$optctl{'csv'} and not $$optctl{'csv-filename'}) {
		#set up a default
		$$optctl{'csv-filename'} = "status-csv-$$.txt";
	}

	if ($$optctl{'conf'}) {
	       	if (!-e $$optctl{'conf'}) {
			print STDERR "Specified conf file '$$optctl{'conf'}' does not seem to exist.\n";
			exit(1);
		}
		if (!open(FILE, "<$$optctl{'conf'}")) {
			print STDERR "Problem opening conf file '$$optctl{'conf'}': $!\n";
			exit(1);
		}
		while (<FILE>) {
			chomp;
			my $line = $_;
			#check for expected format and content
			next unless $line =~ m/\w/;
			if ($line !~ m/^('[\w\s]+',?\s?)+$/) {
				if ($optctl{'debug'}) {
					print STDERR "Line \"$line\" doesn't look right.  Skipping\n";
				}
				next;
			}
			#split up the line, check if they're all supported
			print STDERR "line: $line\n" if $optctl{'debug'};
			my @linearray = ();
			foreach my $item (split /',\s*'/, $line) {
				$item =~ s/^'|'$//g; #strip ' from beginning or end
				print STDERR "\titem: $item\n" if $optctl{'debug'};
				if (!$graphables{$item}) { #Not a graphable
					if ($optctl{'debug'}) {
						print STDERR "$item does not appear to be a registered graphable item.  Not using.\n";
					}
					#remove it from the line
					$line =~ s/'$item',?\s*//;
				}
				else {
					#register it for use in this run
					$graphitems{$item} = 1;
					push @linearray, $item;
				}
			}
			push @{$optctl{'graphs'}}, \@linearray;
		}
		close(FILE);
		if (!defined($optctl{'graphs'}) or ($#{$optctl{'graphs'}} > 10)) {
			print STDERR "Too few or too many graph items in conf file '$$optctl{'conf'}'.\n";
			print STDERR "\tGraphs variable got $#{$optctl{'graphs'}} valid - limit is 10.\n";
			exit(1);
		}
	}
	else { #set up the default one
		print STDERR "No config file specified - setting up default graph.\n";
		push @{$optctl{'graphs'}}, ['TotalLd', 'RAMUtil'];
		push @{$optctl{'graphs'}}, ['Delta Messages in', 'Delta Messages Attempted'];
		$graphitems{'RAMUtil'} = 1;
		$graphitems{'TotalLd'} = 1;
		$graphitems{'Delta Messages in'} = 1;
		$graphitems{'Delta Messages Attempted'} = 1;
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
			print STDERR "Checking directory: $_\n";
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
				$dir =~ s/\/$//;
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

					if (-f $f) {
						push @{$optctl{'file'}}, $f;
					}
					elsif (-f "$dir$pathsep$f") {
						push @{$optctl{'file'}}, "$dir$pathsep$f";
					}
					else {
						print STDERR "Failed to understand '$dir$pathsep$f' or '$f' - skipping\n";
					}
				}
			}
		}
	}
#Status.pl - commenting so that filenames can just be given on the commandline
#	if (!($$optctl{'file'} or $$optctl{'f'})) {
#			print STDERR "Provide the name(s) of maillog files with -f flags.  Use -help for options.\n";
#			exit(0);
#	}
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
			my $line1 = <FILE>;
			my $line2 = <FILE>;
			close(FILE);
			if (!$line1 or ($line1 !~ m/^\w{3} .{15} \d{4} Info: Begin Logfile$/mo)) {
				print STDERR "File $file does not conform to expected log format. (line1) Skipping.\n";
				next;
			}
			if (!$line2 or ($line2 !~ m/ Info: Version: .+ SN: \S+$/mo)) {
				print STDERR "File $file does not conform to expected log format. (line2) Skipping.\n";
				next;
			}
			push @logfiles, $file;
		}
		else {
			print STDERR "Cannot open $file, skipping. $!\n";
			next;
		}
	}
#Status.pl - commenting so that filenames can just be given on the commandline
#	if (!scalar(@logfiles)) {
#		print STDERR "No valid files to operate upon.\n";
#		exit(0);
#	}
#	else {
#		unless ($$optctl{'quiet'}) {
#			print STDERR "Found " . scalar(@logfiles) . " files to operate on.\n";
#		}
#	}

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
		print STDERR "Using only entries btwn the times $$optctl{'t1'} and $$optctl{'t2'}.";
	}
	elsif ($$optctl{'t1'}) {
		print STDERR "Using only entries after $$optctl{'t1'}.";
	}
	elsif ($$optctl{'t2'}) {
		print STDERR "Using only entries before $$optctl{'t2'}.";
	}

sub printhelp {
	print "This utility provides for some parsing of Ironport MGA status logs.\nOptions:\n";
	print <<"END";
	csv           Output all data to CSV file
	js            Generate HTML with graphs in Javascript
	conf          Indicate a file containing graph configuration lines
	showgraphables Print a list of supported graphable items
	support       Print supported status of this utility
	help          To obtain this printout
	version       Print current version of this utility
	quiet         Suppresses most non-report output
Examples:
  $0 -conf graphthis2 status.log
  $0 -conf graphthis2 -csv -nojs status.log > myfile.csv
END
		exit(0);
}
} #process_opts


