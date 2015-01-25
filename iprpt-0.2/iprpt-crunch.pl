#! /usr/bin/perl -w

# Copyright IronPort Systems 2005

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or (at
# your option) any later version.

# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

# $Id:$

use strict;
use Getopt::Long;
use POSIX qw(strftime);

#
# USAGE
#

# -v Verbose
# -t Output text report
# -d <dir> Output xml files for HTML report to <dir>

my ($opt_verbose, $opt_ntop, $opt_text, $opt_dir);
$opt_ntop = 10;
GetOptions("verbose" => \$opt_verbose,
	   "ntop=i" => \$opt_ntop,
	   "text" => \$opt_text,
	   "dir=s" => \$opt_dir) or die "error getting options";

#
# DESIGN
#

# Report Contents
# ---------------
# Header
# Pie chart of inbound mail summary
# Inbound mail summary table:
#   Total Attempted
#    Stopped by Reputation
#    Invalid Recipients
#    Detected as Spam
#    Detected as Virus
#   Total Threat
#    Clean
# Mail trend graph for time period
# Top threat sending domains
# Top clean sending domains

# Data Needed
# ----------------------
# Total count for all times/all domains (pie chart, summary table)
#   Walk through rows and sum up total
# Per-time-period bucket for all domains (trend graph)
#   Walk through rows and aggregate into time period bucket
# Per-domain buckets for all time periods (top threat and clean sending domains)
#   Walk through rows and aggregate into domain buckets
#   Collect the buckets then walk bucket list for top 10
#
# NO NEED for per-time-period, per-domain buckets

#
# CONFIG
#

my @csv_header_4_5_5 = ("timeStamp","StartTime","primaryDomain","remoteIP","localIP","recipientsIn","recipientRejectsIn","RATrecipientRejectsIn","tooManyrecipientRejectsIn","messagesIn","bytesIn","connectionAcceptsIn","spamSuspectMsgsIn","connectionRejectsIn","starttlsSuccessesIn","starttlsFailuresIn","recipientsOut","recipientRejectsOut","messagesOut","bytesOut","connectionAcceptsOut","connectionFailuresOut","connectionRejectsOut","starttlsSuccessesOut","starttlsFailuresOut","SenderBaseOrgID","SenderBaseReputationScore","senderGroup","senderPolicy","spamScanMsgsIn","spamFoundMsgsIn","virusFoundMsgsIn","virusScanMsgsIn","workDequeues","recipientsUnknownIn");
my @csv_header = @csv_header_4_5_5;

# The following snippit will print out the below mapping for CSV column number constants
# my ($csv_col, $csv_col_num);
# $csv_col_num = 0;
# foreach $csv_col (@csv_header)
# {
# 	print "\$C::$csv_col = $csv_col_num;\n"
# 	$csv_col_num += 1;
# }
# exit;

$C::timeStamp = 0;
#$C::StartTime = 1;
$C::primaryDomain = 2;
#$C::remoteIP = 3;
#$C::localIP = 4;
#$C::recipientsIn = 5;
$C::recipientRejectsIn = 6;
#$C::RATrecipientRejectsIn = 7;
$C::tooManyrecipientRejectsIn = 8;
#$C::messagesIn = 9;
#$C::bytesIn = 10;
#$C::connectionAcceptsIn = 11;
$C::spamSuspectMsgsIn = 12;
$C::connectionRejectsIn = 13;
#$C::starttlsSuccessesIn = 14;
#$C::starttlsFailuresIn = 15;
#$C::recipientsOut = 16;
#$C::recipientRejectsOut = 17;
#$C::messagesOut = 18;
#$C::bytesOut = 19;
#$C::connectionAcceptsOut = 20;
#$C::connectionFailuresOut = 21;
#$C::connectionRejectsOut = 22;
#$C::starttlsSuccessesOut = 23;
#$C::starttlsFailuresOut = 24;
#$C::SenderBaseOrgID = 25;
#$C::SenderBaseReputationScore = 26;
#$C::senderGroup = 27;
#$C::senderPolicy = 28;
#$C::spamScanMsgsIn = 29;
$C::spamFoundMsgsIn = 30;
$C::virusFoundMsgsIn = 31;
#$C::virusScanMsgsIn = 32;
$C::workDequeues = 33;
#$C::recipientsUnknownIn = 34;

$C::recKey = 0;
$C::totalAttempted = 1;
$C::stoppedByReputation = 2;
$C::invalidRecipients = 3;
$C::spamDetected = 4;
$C::virusDetected = 5;
$C::totalThreatMsgs = 6;
$C::cleanMsgs = 7;


$C::GRAND_TOTAL = 'GRAND_TOTAL';

$C::MULT_RCPTS_PER_CONN = 3;

#
# READ - Do O(n) read of file, bucket by time period and then by primary domain
#

my ($line, @line_vals, $i, $vcnt,
    $time_records, $domain_records, $total_record,
    $line_time, $line_domain, $cur_timerec, $cur_domrec);

$time_records = { };
$domain_records = { };
# EXTEND - Define a new empty bucket here:

$total_record = new_record($C::GRAND_TOTAL);
$cur_timerec = undef;
$cur_domrec = undef;
$vcnt = 0;

# Begin the parsing
print STDERR "reading input: " if ($opt_verbose);
while ($line = <>)
{
	@line_vals = parse_mailflow_csv_line($line);

	# Detect if a new file has started
	if ($line_vals[0] eq $csv_header[0])
	{
		for ($i = 0; $i <= $#line_vals; $i++)
		{
			die "Header $line_vals[$i] != expected $csv_header[$i]"
				unless ($line_vals[$i] eq "$csv_header[$i]");
		}
		next;
	}

	# Ignore the TOTAL lines
	next if ($line_vals[$C::primaryDomain] eq 'TOTAL');

	$line_domain = $line_vals[$C::primaryDomain];
	$cur_domrec = load_bucket($domain_records, $cur_domrec, $line_domain, \@line_vals);

	$line_time = $line_vals[$C::timeStamp];
	$cur_timerec = load_bucket($time_records, $cur_timerec, $line_time, \@line_vals);

	# EXTEND - Load your new bucket from above

	$total_record = load_record($total_record, $C::GRAND_TOTAL, \@line_vals);

	if ($opt_verbose and $vcnt++ >= 1000)
	{
		print STDERR '.';
		$vcnt = 0;
	}
}
print STDERR "\n" if $opt_verbose;

#
# CALC - Do O(n) traverse of complete domain data, looking for top 10
#

my $topThreatList =
{
	'field' => $C::totalThreatMsgs,
	'nelems' => $opt_ntop,
	'listptr' => undef,
};

my $topCleanList =
{
	'field' => $C::cleanMsgs,
	'nelems' => $opt_ntop,
	'listptr' => undef,
};

my @top_lists = ( $topThreatList, $topCleanList );

print STDERR "finding top $opt_ntop lists..." if $opt_verbose;
find_toplists($domain_records, \@top_lists);
print STDERR "\n" if $opt_verbose;

# EXTEND - Create new toplists for your new buckets if needed

#
# OUTPUT - Spit out HTML
#

my ($key, $record);

# EXTEND - Update output text reports here
if (defined $opt_text)
{
	print "\nTime Buckets\n";
	print_header();
	foreach $key (sort keys %{ $time_records })
	{
		print_record($time_records->{$key});
	}

# print "\nDomain Buckets\n";
# print_header();
# foreach $key (sort keys %{ $domain_records })
# {
# 	print_record($domain_records->{$key});
# }

	print "\nTop Threats\n";
	print_header();
	foreach $record (@{ $topThreatList->{'listptr'} })
	{
		print_record($record);
	}

	print "\nTop Clean\n";
	print_header();
	foreach $record (@{ $topCleanList->{'listptr'} })
	{
		print_record($record);
	}

	print "\n";
	print_header();
	print_record($total_record);
}

#
# XML Output
#

# EXTEND - Output new HTML/XML reports here
if (defined $opt_dir)
{
	my $datadir = $opt_dir;
	my ($file);

	$file = "$datadir/messages_bytype.xml";
	open(XML, ">$file") or die "could not open $file";
	print XML <<EOB;
<graph hoverCapSepChar=' : ' bgColor='FFFFFF' caption='Messages' showNames='0' animation='0' pieYScale='45' pieBorderAlpha='40' pieFillAlpha='100' pieSliceDepth='15' slicingDistance='5' nameTBDistance='15' showShadow='1' shadowAlpha='20' shadowColor='282828' pieBorderThickness='0' formatNumberScale='0' decimalPrecision='0' showPercentageValues='1' showValues='0' showPercentageInLabel='0'>
<set color='00668C' value='$total_record->[$C::stoppedByReputation]' name='Blocked by Reputation' isSliced='1'/>
<set color='555555' value='$total_record->[$C::invalidRecipients]' name='Invalid Recipients' isSliced='1'/>
<set color='FF7400' value='$total_record->[$C::spamDetected]' name='Spam Messages' isSliced='1'/>
<set color='CC3333' Value='$total_record->[$C::virusDetected]' name='Virus Messages' isSliced='1'/>
<set color='33AA33' value='$total_record->[$C::cleanMsgs]' name='Clean Messages' isSliced='1'/>
</graph>
EOB
       close(XML);

	$file = "$datadir/messages_byday.xml";
	open(XML, ">$file") or die "could not open $file";

	my ($day_str, $buf_cats, $buf_clean, $buf_virus, $buf_spam, $buf_invalid, $buf_sbrs);
	foreach $key (sort keys %{ $time_records })
	{
		$record = $time_records->{$key};
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($record->[$C::recKey]);
		$day_str = strftime("%a %b %d", $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
		$buf_cats .= qq|<category name='$day_str'/>\n|;
		$buf_clean .= qq|<set value='$record->[$C::cleanMsgs]'/>\n|;
		$buf_virus .= qq|<set value='$record->[$C::virusDetected]'/>\n|;
		$buf_spam .= qq|<set value='$record->[$C::spamDetected]'/>\n|;
		$buf_invalid .= qq|<set value='$record->[$C::invalidRecipients]'/>\n|;
		$buf_sbrs .= qq|<set value='$record->[$C::stoppedByReputation]'/>\n|;
	}

print XML <<EOB;
<graph hoverCapSepChar=' : ' caption='Incoming Message Volume By Day' xAxisName='Day' yAxisName='Messages' numberPrefix='' rotateNames='1' showhovercap='1' hovercapbg='DEDEBE' hovercapborder='889E6D' animation='0' yAxisMaxValue='100' numdivlines='9' divLineColor='CCCCCC' divLineAlpha='80' decimalPrecision='0' showAlternateHGridColor='1' AlternateHGridAlpha='30' AlternateHGridColor='CCCCCC' formatNumberScale='0' >
<categories>
$buf_cats
</categories>
<dataset color='33AA33' Seriesname='Clean Messages' showValues='0'>
$buf_clean
</dataset>
<dataset color='CC3333' seriesname='Virus Messages' showValues='0'>
$buf_virus
</dataset>
<dataset color='FF7400' seriesname='Spam Messages' showValues='0'>
$buf_spam
</dataset>
<dataset color='555555' seriesname='Invalid Recipients' showValues='0'>
$buf_invalid
</dataset>
<dataset color='00668C' seriesname='Blocked by Reputation' showValues='0'>
$buf_sbrs
</dataset>
</graph>
EOB
close(XML);

        $file = "$datadir/threats_bydomain.xml";
	open(XML, ">$file") or die "could not open $file";
	print XML qq|<graph hoverCapSepChar=' : ' caption='Threat Messages By Domain' yAxisName='Messages' numberPrefix='' rotateNames='0' showhovercap='1' hovercapbg='DEDEBE' hovercapborder='889E6D' animation='0' numdivlines='0' divLineColor='CCCCCC' divLineAlpha='80' decimalPrecision='0' showAlternateHGridColor='1' AlternateHGridAlpha='30' AlternateHGridColor='CCCCCC' formatNumberScale='0' showvalues='0' >\n|;
	foreach $record (@{ $topThreatList->{'listptr'} })
	{
		print XML qq|<set name='$record->[$C::recKey]' value='$record->[$C::totalThreatMsgs]' color='CC3333'/>\n|;
	}
	print XML qq|</graph>\n|;
	close(XML);

        $file = "$datadir/clean_bydomain.xml";
	open(XML, ">$file") or die "could not open $file";
	print XML qq|<graph hoverCapSepChar=' : ' caption='Clean Messages By Domain' yAxisName='Messages' numberPrefix='' rotateNames='0' showhovercap='1' hovercapbg='DEDEBE' hovercapborder='889E6D' animation='0' numdivlines='0' divLineColor='CCCCCC' divLineAlpha='80' decimalPrecision='0' showAlternateHGridColor='1' AlternateHGridAlpha='30' AlternateHGridColor='CCCCCC' formatNumberScale='0' showvalues='0' >\n|;
	foreach $record (@{ $topCleanList->{'listptr'} })
	{
		print XML qq|<set name='$record->[$C::recKey]' value='$record->[$C::cleanMsgs]' color='33AA33'/>\n|;
	}
	print XML qq|</graph>\n|;
	close(XML);

}

#
# LIBRARY FUNCTIONS
#

#
# PARSE_MAILFLOW_CSV_LINE -- Splits and unquotes the CSV
#

sub parse_mailflow_csv_line
{
	my ($line) = (@_);
	die unless (@_ == 1);
	my (@vals);

	chomp($line);

	# From Mastering Regular Expressions (via Perl FAQ)
	@vals = ();
	push(@vals, $+) while $line =~ m{
                "([^\"\\]*(?:\\.[^\"\\]*)*)",?  # groups the phrase inside the quotes
              | ([^,]+),?
              | ,
            }gx;
	push(@vals, undef) if substr($line,-1,1) eq ',';

	return @vals;
}

#
# LOAD_BUCKET -- Optimized load into a bucket of records
#
# PARAMETERS
#    $bucket -- hashptr of records
#    $cur_rec -- the most recently used record
#    $key -- the key we are looking for
#    $valsptr -- arrayptr of values
#
# RETURNS
#    Latest $cur_rec value
#

sub load_bucket
{
	my ($bucket, $cur_rec, $key, $valsptr) = (@_);
	die unless (@_ == 4);

	if (! defined $cur_rec or $cur_rec->[$C::recKey] ne $key)
	{
		if (! defined $bucket->{$key})
		{
			$cur_rec = new_record($key);
			$bucket->{$key} = $cur_rec;
		}
		else
		{
			$cur_rec = $bucket->{$key};
		}
		die unless ($cur_rec->[$C::recKey] eq $key);  # PERFHIT
	}

	load_record($cur_rec, $key, $valsptr);

	return $cur_rec;
}

#
# LOAD_RECORD -- Loads an array of values into a possibly pre-existing record
#

sub load_record
{
	my ($rec, $key, $vals) = (@_);
	die unless (@_ == 3);
	die unless ($rec->[$C::recKey] eq $key);  # PERFHIT

	my $totalAttempted = ($C::MULT_RCPTS_PER_CONN *
			      $vals->[$C::connectionRejectsIn]) +
			      $vals->[$C::recipientRejectsIn] +
			      $vals->[$C::workDequeues];
	my $stoppedByReputation = ($C::MULT_RCPTS_PER_CONN *
				   $vals->[$C::connectionRejectsIn]) +
				   $vals->[$C::tooManyrecipientRejectsIn];
	my $invalidRecipients = $vals->[$C::recipientRejectsIn] -
		                $vals->[$C::tooManyrecipientRejectsIn];
	my $spamDetected = $vals->[$C::spamFoundMsgsIn] +
		           $vals->[$C::spamSuspectMsgsIn];
	my $virusDetected = $vals->[$C::virusFoundMsgsIn];
	my $threatMsgs = $stoppedByReputation +
		         $invalidRecipients +
			 $spamDetected +
			 $virusDetected;
	my $cleanMsgs = $vals->[$C::workDequeues] -
		        $spamDetected - $virusDetected;

	$rec->[$C::totalAttempted] += $totalAttempted;
	$rec->[$C::stoppedByReputation] += $stoppedByReputation;
	$rec->[$C::invalidRecipients] += $invalidRecipients;
	$rec->[$C::spamDetected] += $spamDetected;
	$rec->[$C::virusDetected] += $virusDetected;
	$rec->[$C::totalThreatMsgs] += $threatMsgs;
	$rec->[$C::cleanMsgs] += $cleanMsgs;

	return $rec;
}

#
# NEW_RECORD -- Initialize a new record
#

sub new_record
{
	my ($key) = (@_);
	die unless (@_ == 1);
	my $rec = [ ];

	$rec->[$C::recKey] = $key;

	$rec->[$C::totalAttempted] = 0;
	$rec->[$C::stoppedByReputation] = 0;
	$rec->[$C::invalidRecipients] = 0;
	$rec->[$C::spamDetected] = 0;
	$rec->[$C::virusDetected] = 0;
	$rec->[$C::totalThreatMsgs] = 0;
	$rec->[$C::cleanMsgs] = 0;

	return $rec;
}

#
# PRINT_RECORD and PRINT_HEADER
#

sub print_record
{
	my ($rec) = @_;
	die unless (@_ == 1);

	print "$rec->[$C::recKey]\t";
	print "\t" if (length($rec->[$C::recKey]) < 8);
	print "$rec->[$C::totalAttempted]\t" .
		"$rec->[$C::stoppedByReputation]\t" .
		"$rec->[$C::invalidRecipients]\t" .
		"$rec->[$C::spamDetected]\t" .
		"$rec->[$C::virusDetected]\t" .
		"$rec->[$C::totalThreatMsgs]\t" .
		"$rec->[$C::cleanMsgs]\n";
}

sub print_header
{
	print "Key\t\tAttempt\tSBRS\tBadRcpt\tSpam\tVirus\tThreat\tClean\n";
}

#
# FIND_TOPLISTS -- Traverses a bucket for top N of different fields
#
# PARAMETERS
#    $buckets -- Hash of buckets to look through
#    $field_list -- An array of hash reference descriptors of fields to look for:
#        'field' => Numeric field identifier
#        'nelems' => Number of elements for the top N list
#        'listptr' => undef on input, set to an ordered array of top N record pointers
#
#
# RETURNS
#    Updated $field_list
#

sub find_toplists
{
	my ($buckets, $field_list) = @_;
	die unless (@_ == 2);

	my (@fields, $fhash, $field, $i, $key, $record, $list);

	# Initialize field lists
	@fields = @{ $field_list };
	foreach $fhash (@fields)
	{
		die unless ($fhash->{'nelems'} > 0);
		$fhash->{'listptr'} = [ ];
	}

	# Traverse the buckets
	while (($key, $record) = each %{ $buckets })
	{
		# Traverse the Top N lists, sorting in new records as necessary
		foreach $fhash (@fields)
		{
			$field = $fhash->{'field'};
			$list = $fhash->{'listptr'};

			# Bootstrap the first N records
			if (scalar(@{ $list }) < $fhash->{'nelems'})
			{
				$i = 0;
				while (defined $list->[$i] and
				       $record->[$field] < $list->[$i]->[$field])
				{ $i += 1; }
				splice(@{ $list }, $i, 0, $record);
				next;
			}

			# Check if this value even belongs in the top N
			$i = $fhash->{'nelems'} - 1;
			next if ($record->[$field] <= $list->[$i]->[$field]);

			# Find where this record belongs (start at the beginning)
			$i = 0;
			while ($i < $fhash->{'nelems'} and
			       $record->[$field] < $list->[$i]->[$field])
			{ $i += 1; }
			# Check to see if we've fallen off the end of the list
			next if ($i == $fhash->{'nelems'});

			# Insert it
			splice(@{ $list }, $i, 0, $record);
			pop(@{ $list });  # Remove the excess one at the back
			die unless (scalar(@{ $list }) == $fhash->{'nelems'});
		}
	}

	return $field_list;
}
