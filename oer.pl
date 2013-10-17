#!/usr/bin/perl -w

use strict;
use warnings;
use MongoDB;

print "Content-type: text/html; charset = utf-8\nPragma: no-cache\n\n";
our (%conf, %collection, %months, %week, %in, %tmpl, %mesg, %domain_mail, %command_epp, %commands, %menu_line);
our (@week, @sceleton);
our ($domain_sceleton, $domain_info);
require 'drs.pm';
use Subs;

my $collections = &connect($conf{'database'}, $collection{'domains'});

my @tmp = $collections->find( {}, { 'exDate' => 1 } )->all;

foreach (@tmp) {
	if ($_->{'exDate'} =~ s/1111Z/0000Z/) {
		print "$_->{'_id'} : $_->{'name'} = ";
		print "$_->{'exDate'} = $_->{'expires'} = ";
		$_->{'expires'} = &date2sec($_->{'exDate'});
		print "$_->{'expires'}<br>\n";
		# $collections->update( { '_id' => $_->{'_id'}}, { '$set' => { 'exDate' => $_->{'exDate'}, 'expires' => $_->{'expires'}} } );
	}
}


sub connect {
	my ($col, $client, $db, $base, $collections);
	$base = shift;
	$col = shift;

	# Set collection name if not exists
	unless ($base) { $base = $conf{'database'}; }
	unless ($col) { $col = $collection{'domains'}; }

	# Read list of domains
	$client = MongoDB::Connection -> new(host => $conf{'db_link'});
	$db = $client -> get_database( $base );
	$collections = $db->get_collection( $col );

	return $collections;
}
