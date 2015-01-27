#!/usr/bin/perl

######################################################
# IronPort alerts system
#   retrieve.pl: retrieve c60 XML status page
#
####################################################

use LWP::UserAgent;
use HTTP::Request::Common;
use Crypt::SSLeay;

package main;

my $user = "admin";
my $pass = "ironport";
my $url = "https://devlin.run/xml/status";
my %config;

my $agent = new LWP::UserAgent;

open CONFIG, "<config.txt";

while (<CONFIG>) {
	chop;
	($attr,$value) = split /:/,$_,2 unless /^#/;
	$config{$attr} = $value;
}

close CONFIG;

# set up the request
my $request = new HTTP::Request (GET=>$config{'url'}) || die "failed on https request to $url";
$request->authorization_basic ($config{'user'}, $config{'pass'});

# make the request
if ($request) {
	$response = $agent->request ($request);
}
else {
	die "request isn't valid";
}

# check the result
if ($response->is_error) {
	print $response->error_as_HTML();
	exit;
}
else {
	$xmlstatus = $response->content;
}

open FOUT, ">$config{'outfile'}";

print FOUT $xmlstatus;

close FOUT;
