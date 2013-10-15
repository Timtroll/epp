#!/usr/bin/perl -w

use strict;
use warnings;
use MongoDB;

print "Content-type: text/html; charset = utf-8\nPragma: no-cache\n\n";

# Read list of domains
# my $client = MongoDB::Connection -> new( host => 'mongodb://admin:r3dp0w3r@db1mongo.betterknow.com;27017' );
# my $db = $client -> get_database( 'oerMaterials' );
# my $collections = $db->get_collection( 'materials' );

# # my @tmp = $collections -> find( { 'oer_type' => 1 } ) -> sort( { 'oer_type' => 1 } ) -> all;

# # foreach (@tmp) {
	# print "<li>$_-{'oer_type'}</li>";
# }

open (FILE, '<./listing.txt') or die;
open (OUT, '>./list.txt') or die($!);
	while (<FILE>) {
		unless (/\.404/) {
			print "$_<br>";
			print OUT $_;
		}
	}
close OUT;
close FILE;