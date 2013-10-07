#!/usr/bin/perl -w

use strict;
use warnings;
use MongoDB;
use MongoDB::OID;
use Data::Dumper;

our (%conf, %collection, %months, %week, %in, %tmpl, %mesg, %domain_mail, %command_epp, %commands, %menu_line);

require "drs.pm";

print "Content-type: text/html; charset = utf-8\nPragma: no-cache\n\n";

my ($collections, $count, @tmp);

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

