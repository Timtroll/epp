#!/usr/bin/perl -w

use strict;
use warnings;
use MongoDB;
use MongoDB::OID;
use Data::Dumper;
use Net::EPP::Simple;

BEGIN {
	IO::Socket::SSL::set_ctx_defaults(
		'SSL_verify_mode' => 'SSL_VERIFY_NONE'
        );
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = '0';
};

our (%conf, %collection, %months, %week, %in, %tmpl, %mesg, %domain_mail, %command_epp, %commands, %menu_line);

require "drs.pm";

print "Content-type: text/html; charset = utf-8\nPragma: no-cache\n\n";

my ($collections, $count, $info, $epp, @tmp);

# Send create domain request
$epp = &connect_epp();

$collections = &connect($conf{'database'}, $collection{'domains'});

# Calculate exist same message in the databse
@tmp = $collections -> find( { } ) -> all;

foreach (0..(scalar(@tmp)-1)) {
	$count = 0;
#	$count = $collections -> find( { 'name' => $tmp[$_]->{'name'} } ) -> count;
	$count = $collections -> find( { 'add' => {'$exists' => 1 },  'name' => $tmp[$_]->{'name'} } ) -> count;
	if ($count) {
		$collections -> remove({"_id" => $tmp[$_]->{'_id'} } );
		print "<li>$tmp[$_]->{'_id'} = $count</li>\n";
	}
	else {
		# check domain
		$info = $epp->domain_info($tmp[$_]->{'name'});

		print Dumper($info);
		last;
	}
}

############## Subs ##############

sub connect_epp {
	my ($epp);

	# Connect to Epp server
	$epp = Net::EPP::Simple->new(
		host		=> $conf{'epp_host'},
		user		=> $conf{'epp_user'},
		timeout	=> $conf{'epp_timeout'},
		pass		=> $conf{'epp_pass'},
		debug	=> $conf{'debug_epp'}	
	);

	if (($Net::EPP::Simple::Code == 2500)||($Net::EPP::Simple::Code == 2501)||($Net::EPP::Simple::Code == 2502)) {
		$in{'messages'} = $Net::EPP::Simple::Message."<br>".$Net::EPP::Simple::Error;
	}

	return $epp;
}

sub connect {
	my ($col, $client, $db, $base, $collections);
	$base = shift;
	$col = shift;

	# Set collection name if not exists
	unless ($base) { $base = $conf{'database'}; }
	unless ($col) { $col = $collection{'domains'}; }

	# Read list of domains
	$client = MongoDB::Connection -> new( host => $conf{'db_link'} );
	$db = $client -> get_database( $base );
	$collections = $db->get_collection( $col );

	return $collections;
}

