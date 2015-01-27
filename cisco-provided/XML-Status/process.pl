#!/usr/bin/perl

########################################
# IronPort alerts subscription.
#
# process.pl : processes all subscriptions and emails alerts based on preferences
#
#  should be placed in crontab to be run every minute

use XML::Parser;
use Net::SMTP;

package main;

my $triggered = 0;
my $upper = 0;
my $smtp;
my $target_email = "";
my $email = "";
my $email_header = "";

my %gauges, %rates, %counters;
my $attrib = "";
my $lower = 0;
my $upper = 0;
my $attrList = "";
my %config;

sub xmlCharHandler {
	return;
}

sub xmlElementHandler {
	my ($parser, $element, %attr) = @_;
	$element = lc ($element);

	if ($element eq "gauge") {
		if ($attr {'name'} eq "ram_utilization") {
			$gauges{'ram'} = ($attr{'current'});
		}
		elsif ($attr {'name'} eq "cpu_utilization") {
			$gauges{'cpu'} = ($attr{'current'});
		}
		elsif ($attr {'name'} eq "disk_utilization") {
			$gauges{'disk'} = ($attr{'current'});
		}
		elsif ($attr {'name'} eq "conn_in") {
			$gauges{'conn_in'} = ($attr{'current'});
		}
		elsif ($attr {'name'} eq "conn_out") {
			$gauges{'conn_out'} =  ($attr{'current'});
		}
		elsif ($attr {'name'} eq "unattempted_recips") {
			$gauges{'unattempted_recips'} =  ($attr{'current'});
		}
		elsif ($attr {'name'} eq "active_recips") {
			$gauges{'active_recips'} =  ($attr{'current'});
		}
		elsif ($attr {'name'} eq "attempted_recips") {
			$gauges{'attempted_recips'} =  ($attr{'current'});
		}
		elsif ($attr {'name'} eq "msgs_in_work_queue") {
			$gauges{'msgs_in_work_queue'} =  ($attr{'current'});
		}
		elsif ($attr {'name'} eq "dests_in_memory") {
			$gauges{'dests_in_memory'} =  ($attr{'current'});
		}
		elsif ($attr {'name'} eq "kbytes_used") {
			$gauges{'kbytes_used'} =  ($attr{'current'});
		}
		elsif ($attr {'name'} eq "kbytes_free") {
			$gauges{'kbytes_free'} =  ($attr{'current'});
		}
		elsif ($attr {'name'} eq "resource_conservation") {
			$gauges{'resource_conservation'} = ($attr{'current'});
		} 

	}
	elsif ($element eq "rate") {
	}
	elsif ($element eq "counter") {
	}
        elsif ($element eq "status") {
                        $hostname = ($attr{'hostname'});
                        $build = ($attr{'build'});
                        $timestamp = ($attr{'timestamp'});
        } 
}

open CONFIG, "<config.txt";

while (<CONFIG>) {
        chop;
        ($attr,$value) = split /:/,$_,2 unless /^#/;
        $config{$attr} = $value;
}

close CONFIG;

$parser = new XML::Parser ();
$parser->setHandlers (Char => \&xmlCharHandler,
			Start => \&xmlElementHandler);
$parser->parsefile ($config{'outfile'}) || die "cannot open $config{'outfile'} for reading";

open FIN, $config{'subscr'} || die "can't open subscription database";

# handle each subscription
while (<FIN>) {
	$email = "";
	$triggered = 0;
	($target_email, $full_name, $attrList) = split /:/, $_, 3;
	$attrib = "";
	$lower = $upper = 0;

	# handle each attribute in the subscription
	($attrib, $lower, $upper, $attrList) = split /:/, $attrList, 4;
	while ($attrList) {
		if ( ($gauges{$attrib} > $lower) && ($gauges{$attrib} < $upper) ) {
			$triggered = 1;
			$email .= "$attrib usage of $gauges{$attrib} was between specified alert floor of $lower and ceiling of $upper\n";
		}
		($attrib, $lower, $upper, $attrList) = split /:/, $attrList, 4;
	} 

	if ($triggered != 0) {
		$date = scalar localtime;
		$email_header .= "New alert generated for $full_name on $date\n\n";
		$email_header .= "From system $hostname - $build at time $timestamp\n\n";
		$email_header .= "This alert has been automatically generated because: \n";
	
		$email = $email_header . $email;

		$smtp = new Net::SMTP ($config{'smtp'}) || die "couldn't open mail connection";

		die "couldn't open mail connection" unless $smtp;
		$smtp->mail ("alerts\@localhost");
		$smtp->to ($target_email);
		$smtp->data ();
		$smtp->datasend ("To: $target_email\n");
		$smtp->datasend ("Subject: IronPort C60 Custom Alert\n");
		$smtp->datasend ("\n");
		$smtp->datasend ($email);
		$smtp->dataend();
		$smtp->quit();
	}
}
