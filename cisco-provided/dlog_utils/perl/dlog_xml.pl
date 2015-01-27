#!/usr/bin/perl 
# dlog_xml.pl - dump IronPort delivery logs in XML format
#
# Copyright (C) 2002, IronPort Systems.  All rights reserved.
# $Revision: 1.9 $

use IronPort_DeliveryLog;

our $backwards_compat = 0;
our $revision = q$Name: DLOG_PARSING_TOOLS_1_4 $;
package DLOG_XML;

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
	
	$self->{Version} = $VER;
	$self->{Output}  = qq(<?xml version="1.0" encoding="ISO-8859-1"?>\n);
	$self->{Output} .= qq(<delivery-report version="$VER">\n);
}

sub cb_end
{
	my ($self, $rec) = @_;

	if ($self->{Processing_Finished} != 1) {
		$self->{Output} .= "</delivery-report>\n";
		$self->{Processing_Finished} = 1;

		my $fh = $self->{FileHandle};
		print $fh $self->{Output};
		$self->{Output} = '';
	}
}

sub _errs_to_str
{
	my $arr = shift;

	if    ($#$arr < 0) { return ""; }
	elsif ($#$arr < 1) { return @$arr[0]; }
	else               { return "[" . join (", ", @$arr) . "]"; }
}

my $ASCII_PAT = '[\x0-\x1F\7F-]';
sub _ascii_format
{
	my $str_ref = shift;
	my $val;
	while ($$str_ref =~ /($ASCII_PAT)/) 
	{
		my $chr = $1;
		my $val = sprintf ("\\%03o", ord($chr));
		$$str_ref =~ s/$chr/$val/g;
	}
	return $str_ref;
}


use MIME::Base64;
my %XML_ESCAPE = 
	( '&' => '&amp;',
	  '<' => '&lt;',
	  '>' => '&gt;',
	  '"' => '&quot;',
	  # "'" => '&apos;',
	  );

sub _xml_quote_inplace
{
	my $tmp;
	my $str_ref = shift;

	if ($$str_ref =~ /[\x00-\x08\x0B\x0C\x0E-\x1F]/) {
		# return _ascii_format($str_ref);
		
		$$str_ref = "=?ascii?B?" . encode_base64($$str_ref);
		chomp($$str_ref); 
		$$str_ref .= "?=";
	}
	else {
		foreach my $key (keys %XML_ESCAPE) { 
			$$str_ref =~ s/($key)/$XML_ESCAPE{$key}/gx;
		}
	}

	return $str_ref;
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
	     $del_time = IronPort_DeliveryLog::Time_to_String($rec->{Time});
	     $inj_time = IronPort_DeliveryLog::Time_to_String($rec->{Log_Time});
    }
    else {
	     $del_time = IronPort_DeliveryLog::Time_to_String($rec->{Log_Time});
	     $inj_time = IronPort_DeliveryLog::Time_to_String($rec->{Time});
    }
	my $estr = _errs_to_str($rec->{Errors});
	my $istr = _ip_to_str($rec->{IP});

	_xml_quote_inplace(\$estr);
	_xml_quote_inplace(\$rec->{From}); 



	#for v4
	my $val = '';
	if ($self->{Version} >=4) {
		my $fmt =
			qq(  <success mid="%d" bytes="%d" ip="%s"\n)
			. qq(     from="%s"\n)
			. qq(     del_time="%s" \n) 
			. qq(     inj_time="%s" \n)
	        	. qq(     source_ip="%s" \n)
                	. qq(     code = "%s" \n)
                	. qq(     reply = "%s">\n);
	
		$val = sprintf($fmt, $rec->{Msg_Id}, $rec->{Bytes}, $istr, 
					  $rec->{From}, $del_time, $inj_time,
			                  _ip_to_str($rec->{SRC_IP}), 
					  $rec->{Code}, $rec->{Reply});
	}
	#for early versions
	else {
		my $fmt =
			qq(  <success mid="%d" bytes="%d" ip="%s"\n)
			. qq(     from="%s"\n)
			. qq(     del_time="%s" \n) 
			. qq(     inj_time="%s">\n);

		$val = sprintf($fmt, $rec->{Msg_Id}, $rec->{Bytes}, $istr, 
					  $rec->{From}, $del_time, $inj_time);
	}

	$self->{Output} .= $val;
	$self->gen_rcpt($rec->{Recipient_Information}, $rec->{Domain});
	$self->gen_cust($rec->{Customer_Information});

	$self->{Output} .= "  </success>\n";

	my $fh = $self->{FileHandle};
	print $fh $self->{Output};
	$self->{Output} = '';
}

sub cb_bounce
{
	my ($self, $rec) = @_;

    my $del_time, $inj_time;

    if ($backwards_compat) {

	     $del_time = IronPort_DeliveryLog::Time_to_String($rec->{Time});
	     $inj_time = IronPort_DeliveryLog::Time_to_String($rec->{Log_Time});

    } else {

	     $del_time = IronPort_DeliveryLog::Time_to_String($rec->{Log_Time});
	     $inj_time = IronPort_DeliveryLog::Time_to_String($rec->{Time});

    }

	my $estr = _errs_to_str($rec->{Errors});
	my $istr = _ip_to_str($rec->{IP});

	_xml_quote_inplace(\$estr);

	my $val = '';

	# for V4 and higher
	if ($self->{Version} >= 4) {
		my $fmt =
			qq(  <bounce mid="%d" bytes="%d" ip="%s" code="%s"\n)
			. qq(     from="%s" \n)
			. qq(     del_time="%s" \n) 
			. qq(     inj_time="%s" \n)
			. qq(     error="%s" reason="%s"\n)
                	. qq(     source_ip="%s">\n);

		_xml_quote_inplace(\$rec->{From}); 
		$val = sprintf($fmt, $rec->{Msg_Id}, $rec->{Bytes}, $istr, 	
					  $rec->{Code}, 
					  $rec->{From}, 
					  $del_time, 
					  $inj_time, 
					  $estr, $rec->{Reason},
					  $rec->{SRC_IP});
	}
	#otherwise
	else {
		my $fmt =
			qq(  <bounce mid="%d" bytes="%d" ip="%s" code="%s"\n)
			. qq(     from="%s" \n)
			. qq(     del_time="%s" \n) 
			. qq(     inj_time="%s" \n)
			. qq(     error="%s" reason="%s">\n);

		_xml_quote_inplace(\$rec->{From}); 
		$val = sprintf($fmt, $rec->{Msg_Id}, $rec->{Bytes}, $istr, 	
					  $rec->{Code}, 
					  $rec->{From}, 
					  $del_time, 
					  $inj_time, 
					  $estr, $rec->{Reason});
	}
	$self->{Output} .= $val;

	$self->gen_rcpt($rec->{Recipient_Information});
	$self->gen_cust($rec->{Customer_Information});
	$self->{Output} .= "  </bounce>\n";

	my $fh = $self->{FileHandle};
	print $fh $self->{Output};
	$self->{Output} = '';
}

sub gen_rcpt
{
	my ($self, $arr, $domain) = @_;
	my $fmt = qq(     <rcpt rid="%d" to="%s" attempts="%d" />\n);
	my $cnt = $#$arr + 1;

	return if $cnt == 0;


	$self->{Output} .= "\n";
	# $self->{Output} .= qq(   <debug type="rcpt_meta" count="$cnt" />\n);
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

		_xml_quote_inplace(\$addr);
	 	my $ret = sprintf($fmt, 
	 					  $elem->{Rcpt_Id}, 
	 					  $addr,
	 					  $elem->{Attempt} + 1);
	 	$self->{Output} .= $ret;
	}
}

sub gen_cust
{
	my ($self, $arr) = @_;
	my $cnt = $#$arr + 1;

	return if $cnt == 0;

	my $top = qq(     <customer_data>\n);
	my $fmt = qq(          <header name="%s" value="%s"/>\n);
	my $btm = qq(     </customer_data>\n);

	$self->{Output} .= "\n";
	# $self->{Output} .= qq(   <debug name="cust_meta" count="$cnt" />\n);

	if ($cnt > 0) {
		$self->{Output} .= $top;
	
		foreach my $elem (@$arr)
		{
			_xml_quote_inplace(\$elem->{Name});
			_xml_quote_inplace(\$elem->{Value});
			$self->{Output} .= sprintf ($fmt, $elem->{Name}, $elem->{Value});
		}

		$self->{Output} .= $btm;
	}
}

sub new 
{
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $fh = shift;

	if (! defined $fh) { $fh = \*STDOUT; }
	$self->{FileHandle} = $fh;

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
    print "\n\tdlog_xml.pl version $1\n\n";

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
my $xml_printer = new DLOG_XML(\*OUTFILE);
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
