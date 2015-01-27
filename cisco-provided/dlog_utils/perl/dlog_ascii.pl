#!/usr/bin/perl 
# dlog_ascii.pl - dump IronPort delivery logs ascii format
#
# Copyright (C) 2002, IronPort Systems.  All rights reserved.
# $Revision: 1.9 $

use IO::String;
use IronPort_DeliveryLog;

use strict vars;

#global version
our $VERSION = 1;
our $backwards_compat = 0;
our $revision = q$Name: DLOG_PARSING_TOOLS_1_4 $;

package DLOG_ASCII;

sub parse_split_string
{
	# This code is for reference.  An old version of the delivery logs
 	# may have embedded an code object in the report files instead of 	
	# a string.  This parses the "split-string" class back into a string

	my $r = shift;
	my $key;
	my $retV = "";

	if (ref($r) eq "HASH") {
		my $hr = $r->{__dict__};
		foreach $key (keys(%$hr)) { 
			my $val = $hr->{$key};

			if (ref($val) eq "SCALAR") {
				# print "Key $key => $val\n";
			}
			elsif (ref($val) eq "ARRAY") {
			 	#print "Key $key => array of ", @$val, "\n";
				return join("", @$val);
			}
		}

	}

	return $r;
}

sub callback 
{
	my ($self, $rec) = @_;

	$self->cb_start($rec)    if $rec->{Type} == $IronPort_DeliveryLog::START;
	$self->cb_delivery($rec) if $rec->{Type} == $IronPort_DeliveryLog::DELIVERY;
	$self->cb_bounce($rec)   if $rec->{Type} == $IronPort_DeliveryLog::BOUNCE;
	$self->cb_end($rec)      if $rec->{Type} == $IronPort_DeliveryLog::END;
}

sub flush
{
    my ($self) = @_;
	my $fh = $self->{FileHandle};
	my $str = $self->{IO}->string_ref;
	$self->{IO} = new IO::String;
	print $fh $$str;
}

sub print
{
	my ($self, @args) = @_;
	my $fh = $self->{IO};
	print $fh @args;
}

sub printf
{
	my ($self, @args) = @_;
	my $fh = $self->{IO};
	printf $fh @args;
}

sub cb_start
{
	my ($self, $rec) = @_;
	my $VER = $rec->{Version};
	my $log_tm = IronPort_DeliveryLog::Time_to_String($rec->{Log_Time});
	
	$self->{Version} = $VER;

	$self->print("START $log_tm\n");
    if ($backwards_compat) {
	    $self->print(". Version " . "" . "\n");
    }
    else {
	    $self->print(". Version " . $VERSION . "\n");
        $self->print(". File Version $VER\n");
    }
	$self->print("\n");
	$self->flush();
}

sub cb_end
{
	my ($self, $rec) = @_;
    if ($rec->{Log_Time}[0] == 0 && $rec->{Log_time}[1] == 0) {
        return;
    }
	my $log_tm = IronPort_DeliveryLog::Time_to_String($rec->{Log_Time});

    

	if ($self->{Processing_Finished} != 1) {
		$self->{Processing_Finished} = 1;
		$self->print("END $log_tm\n");
        if (!$backwards_compat) {
            $self->print( "\n");
        }
		$self->flush();
	}
}

sub _errs_to_str
{
	my $arr = shift;

	if ($#$arr < 0) { return "[]"; }
	else            { return "[" . join (", ", @$arr) . "]"; }
}

my $PAT = '[\x0-\x1F\7F-]';
sub ascii_format
{
	my $str_ref = shift;
	my $val;
	while ($$str_ref =~ /($PAT)/) 
	{
		my $chr = $1;
		my $val = sprintf ("\\%03o", ord($chr));
		$$str_ref =~ s/$chr/$val/g;
	}
	return $str_ref;
}

sub ip_str
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
	
	my $log_tm  = IronPort_DeliveryLog::Time_to_String($rec->{Log_Time});
	my $delv_tm = IronPort_DeliveryLog::Time_to_String($rec->{Time});

	$self->print("DELIVERY ", $log_tm, "\n");
	$self->print(". Time   ", $delv_tm, "\n");
	$self->print(". Bytes  ", $rec->{Bytes}, "\n");
	$self->print(". Msg_Id ", $rec->{Msg_Id}, "\n");
	$self->print(". IP     ", ip_str($rec->{IP}), "\n");
	$self->print(". From   ", ${ascii_format(\$rec->{From})}, "\n");
	$self->print(". Domain ", $rec->{Domain}, "\n");

	#handle V4 added fields
	if ($self->{Version} >= 4) {
		$self->print(". Src_IP ", ip_str($rec->{SRC_IP}), "\n");
		$self->print(". Code   ", $rec->{Code}, "\n");
		$self->print(". Reply  ", $rec->{Reply}, "\n");
	}
	
	$self->print("\n");

	$self->rcpt_dump ($rec->{Recipient_Information});

    if (!$backwards_compat) {
        $self->print("\n");
    }

	$self->cust_dump ($rec->{Customer_Information});
	$self->print("\n");
	$self->flush();
}

sub cb_bounce
{
	my ($self, $rec) = @_;
	my $err_tm = IronPort_DeliveryLog::Time_to_String($rec->{Time});
	my $log_tm = IronPort_DeliveryLog::Time_to_String($rec->{Log_Time});

	$self->print("BOUNCE ", $log_tm, "\n");
	$self->print(". Time   ", $err_tm, "\n");
	$self->print(". Bytes  ", $rec->{Bytes}, "\n");
	$self->print(". Msg_Id ", $rec->{Msg_Id}, "\n");
	$self->print(". IP     ", ip_str($rec->{IP}), "\n");
	$self->print(". From   ", ${ascii_format(\$rec->{From})}, "\n");
	$self->print(". Reason ", $rec->{Reason}, "\n");
	$self->print(". Code   ", $rec->{Code}, "\n");
	#handle V4 added field
	if ($self->{Version} >= 4) {
		$self->print(". Src_IP ", ip_str($rec->{SRC_IP}), "\n");
	}
	$self->print("\n");

	$self->rcpt_dump ($rec->{Recipient_Information});

    if (!$backwards_compat) {
        $self->print("\n");
    }

	$self->cust_dump ($rec->{Customer_Information});
	$self->err_dump ($rec->{Errors});
	$self->print("\n");
	$self->flush();
}

sub arr_size 
{
	my $arr = shift;
	return $#$arr + 1;
}

sub rcpt_dump
{
	my $self = shift;
	my $arr = shift;
	my $sz = arr_size($arr);

	if ($sz == 0) { return; }

	$self->printf("Rcpt Data: (%d elem)\n", $sz);
	foreach my $elem (@$arr)
	{
		my ($rid, $email, $attempts) = (
			$elem->{Rcpt_Id},
			$elem->{Address},
			$elem->{Attempt});

		ascii_format(\$email);
		$attempts += 1;
		$self->print(" .. Rcpt_Id $rid\n");
		$self->print(" ..   Attempt_Number $attempts\n");
		$self->print(" ..   Email $email\n");
	}
}

sub err_dump
{
	my $self= shift;
	my $arr = shift;
	my $sz = arr_size($arr);

	if ($sz > 0) 
	{
		$self->printf("\n");
		$self->printf("Error Data: (%d elem)\n", $sz);

		foreach my $elem (@$arr) 
		{
			$self->print(" .. " . $elem . "\n");
		}
	}
}

sub cust_dump
{
	my $self = shift;
	my $arr = shift;
	my $sz = arr_size($arr);

	if ($sz == 0) { return; }

	$self->printf("Cust Data: (%d elem)\n", $sz);
	foreach my $elem (@$arr)
	{
		my ($name, $val) = (
			$elem->{Name},
			$elem->{Value});
                #$val2 = parse_split_string($val);
                my $val2 = $val;
		$self->print(" .. $name => $val2 \n");
	}
}

sub new 
{
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $fh = shift;

    my $self = {};

	if (! defined $fh) { $fh = \*STDOUT; }
	$self->{FileHandle} = $fh;
	$self->{IO} = new IO::String;

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
	print IronPort_DeliveryLog::Time_to_String($record->{Log_Time});
	print "\n";
}

my $next = 0;
my @infiles = ();
*OUTFILE = \*STDOUT;

sub print_version
{
     $revision =~ /.*: (.*)/;
     print "\n\tdlog_ascii.pl version $1\n\n";

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
   die "Usage:  $0  [ -o output_file ] [-B] dlog_1 dlog_2 .. dlog_n\n";
}

my $parser = new IronPort_DeliveryLog;
my $xml_printer = new DLOG_ASCII(\*OUTFILE);
my $cref = sub { $xml_printer->callback(@_); };


$parser->set_callback($cref);

if ($backwards_compat) {
    $parser->ignore('end');
}

foreach my $file (@infiles) 
{
	$parser->read_file($file);
    if ($backwards_compat) {
	    $parser->ignore('start');
    }

}

if ($backwards_compat) {
    my $rec = { Log_Time=>[time, 0] };
    $xml_printer->cb_end($rec);
}
close OUTFILE;

1;
