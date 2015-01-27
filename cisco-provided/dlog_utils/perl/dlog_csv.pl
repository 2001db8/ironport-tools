#!/usr/bin/perl 
# dlog_xml.pl - dump IronPort delivery logs in XML format
#
# Copyright (C) 2002, IronPort Systems.  All rights reserved.
# $Revision: 1.9 $

use IronPort_DeliveryLog;
use Text::CSV;

our $backwards_compat = 0;
our $revision = q$Name: DLOG_PARSING_TOOLS_1_4 $;

package DLOG_CSV;
use POSIX qw(strftime);

my $OUTPUT_VERSION = "1";

sub CSV_Time
{
	my $a = shift;
        my ($sec, $usec) = @$a;

        my @arr = localtime $sec;
        my $tm1 = strftime q(%d %b-%Y %H:%M:%S), @arr;
        return [$tm1, sprintf ("%03d", $usec / 1000)];
}

sub callback 
{
	my ($self, $rec) = @_;

	$self->cb_start($rec)    if $rec->{Type} == $IronPort_DeliveryLog::START;
	$self->cb_delivery($rec) if $rec->{Type} == $IronPort_DeliveryLog::DELIVERY;
	$self->cb_bounce($rec)   if $rec->{Type} == $IronPort_DeliveryLog::BOUNCE;
	$self->cb_end($rec)      if $rec->{Type} == $IronPort_DeliveryLog::END;
}

sub cb_start
{
	my ($self, $rec) = @_;

        my $VER = $rec->{Version};
        my $log_tm = CSV_Time($rec->{Log_Time});

	$self->{Version}  = $VER;
	$self->colgen("START", @$log_tm, $VER, $OUTPUT_VERSION);	
	$self->{Output} = $self->colstring() . "\n";
}

sub cb_end
{
	my ($self, $rec) = @_;
       	my $log_tm = CSV_Time($rec->{Log_Time});

	if ($self->{Processing_Finished} != 1) {
		$self->colgen("END", @$log_tm);
		$self->{Processing_Finished} = 1;

		my $fh = $self->{FileHandle};
		$self->{Output} = $self->colstring() . "\n";
		print $fh $self->{Output};
		$self->{Output} = '';
	}
}

sub _ip_to_str
{
	my $ip = shift;
	my ($d, $c, $b, $a) = ($ip & 0xFF, 
						   ($ip >> 8) & 0xFF,
						   ($ip >> 16) & 0xFF,
						   ($ip >> 24) & 0xFF);

	return sprintf("%u.%u.%u.%u", $a, $b, $c, $d);
}

sub cb_delivery
{
	my ($self, $rec) = @_;

    my $del_time, $inj_time;
    if ($backwards_compat) {
	    $del_time = CSV_Time($rec->{Time});
	    $inj_time = CSV_Time($rec->{Log_Time});
    }
    else {
	    $del_time = CSV_Time($rec->{Log_Time});
	    $inj_time = CSV_Time($rec->{Time});
    }

	my $istr = _ip_to_str($rec->{IP});

	$self->colgen("DELV", @$del_time, @$inj_time, "$rec->{Bytes}",
			"$rec->{Msg_Id}", "$istr", "$rec->{From}", "$rec->{Domain}");


	#handle v4 added fields
	if ($self->{Version} >= 4) {
		my $sistr = _ip_to_str($rec->{SRC_IP});
		$self->colgen("$sistr");
		$self->colgen("$rec->{Code}");
		$self->colgen("$rec->{Reply}");
	}

	$self->gen_rcpt($rec->{Recipient_Information}, $rec->{Domain});
	$self->gen_cust($rec->{Customer_Information});

	$self->{Output} = $self->colstring() . "\n";
	my $fh = $self->{FileHandle};
	print $fh $self->{Output};
	$self->{Output} = '';
}

sub cb_bounce
{
	my ($self, $rec) = @_;
	
    my $del_time, $inj_time;
    if ($backwards_compat) {
	    $del_time = CSV_Time($rec->{Time});
	    $inj_time = CSV_Time($rec->{Log_Time});
    }
    else {
	    $del_time = CSV_Time($rec->{Log_Time});
	    $inj_time = CSV_Time($rec->{Time});
    }
	my $istr = _ip_to_str($rec->{IP});

	$self->colgen("BOUNCE", @$del_time, @$inj_time, "$rec->{Bytes}",
			"$rec->{Msg_Id}", "$istr", "$rec->{From}", 
			"$rec->{Reason}", "$rec->{Code}");

	
	#handle v4 added fields
	if ($self->{Version} >= 4) {
        	my $sistr = _ip_to_str($rec->{SRC_IP});
        	$self->colgen("$sistr");
	}
	

	$self->gen_rcpt($rec->{Recipient_Information}, $rec->{Domain});
	$self->gen_cust($rec->{Customer_Information});
	$self->gen_errors($rec->{Errors});

	$self->{Output} = $self->colstring() . "\n";
	my $fh = $self->{FileHandle};
	print $fh $self->{Output};
	$self->{Output} = '';
}

sub gen_errors
{
	my ($self, $arr) = @_;
	my $cnt = $#$arr + 1;

	if ($cnt > 0) 
	{
		$self->colgen("Errors", $cnt);

		foreach my $elem (@$arr) 
		{
			$self->colgen($elem);
		}
	}
}

sub gen_rcpt
{
	my ($self, $arr, $domain) = @_;
	my $cnt = $#$arr + 1;

	return if $cnt == 0;

	$self->colgen("RCPT", $cnt);

	foreach my $elem (@$arr) 
	{
		my $addr;

		if (($self->{Version} < 3) && (defined $domain)) {
			my $tmp = $elem->{Address};
			$addr = "$tmp\@$domain";
		}
		else {
			$addr = $elem->{Address};
		}

		$self->colgen("Id", $elem->{Rcpt_Id}, 
			      "Attempt", $elem->{Attempt} + 1,
			      "Email", $addr);
	}
}

sub gen_cust
{
	my ($self, $arr) = @_;
	my $cnt = $#$arr + 1;

	return if $cnt == 0;

	$self->colgen("Cust", $cnt);

        my @sorted =  sort { $a->{Name} <=> $b->{Name} } @$arr;

	if ($cnt > 0) {
		foreach my $elem (@sorted)
		{
			my $N = $elem->{Name};
			my $V = $elem->{Value};
			$self->colgen("$N=$V");
		}
	}
}

sub colgen
{
	my ($self, @rest) = @_;
	$self->{CSV}->combine(@rest);
	if ($self->{CSVL} ne "") {
		$self->{CSVL} = join(",", $self->{CSVL}, $self->{CSV}->string());
	}
	else {
		$self->{CSVL} = $self->{CSV}->string();
	}
}

sub colstring
{
	my $self = shift;
	my $line = $self->{CSVL};
	$self->{CSVL} = "";
	return $line;
}

sub new 
{
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $fh = shift;

	if (! defined $fh) { $fh = \*STDOUT; }
	$self->{FileHandle} = $fh;
	$self->{CSV} =  Text::CSV->new();
	$self->{CSVL} = "";

	bless $self, $class;
	return $self;
}

1;

package main;

sub callback 
{
	my $record = shift;

	my $str = 'UNKNOWN';
	$str = 'ERROR ' if $record->{Type} == $IronPort_DeliveryLog::ERROR;
	$str = 'DELVRY' if $record->{Type} == $IronPort_DeliveryLog::DELIVERY;
	$str = 'BOUNCE' if $record->{Type} == $IronPort_DeliveryLog::BOUNCE;
	$str = 'START ' if $record->{Type} == $IronPort_DeliveryLog::START;
	$str = 'END   ' if $record->{Type} == $IronPort_DeliveryLog::END;

	print "Record type: $str at ";
	print CSV_Time($record->{Log_Time});
	print "\n";
}

my $next = 0;
my @infiles = ();
*OUTFILE = \*STDOUT;

sub print_version
{
     $revision =~ /.*: (.*)/;
     print "\n\tdlog_csv.pl version $1\n\n";

}


while (my $arg = shift (@ARGV)) {
   if ($next) {
       open OUTFILE, "> $arg" || die "Unable to open $arg for output\n";
       $next = 0;
   }
   elsif ($arg eq "-version") {
        print_version();
        exit(0);
   }
   elsif ($arg eq "-o") {
      $next = 1;
   }
   elsif ($arg eq "-B") {
      $backwards_compat = 1;
   }
   else {
      push @infiles, $arg;
   }
}

if ($#infiles < 0) {
   die "Usage:  $0  [ -o output_file ] dlog_1 dlog_2 .. dlog_n\n";
}

my $parser = new IronPort_DeliveryLog;
my $xml_printer = new DLOG_CSV(\*OUTFILE);
my $cref = sub { $xml_printer->callback(@_); };

$parser->set_callback($cref);
$parser->ignore('end');

foreach my $file (@infiles) 
{
	$parser->read_file($file);
	$parser->ignore('start');
}
$xml_printer->cb_end();
close OUTFILE;

1;
