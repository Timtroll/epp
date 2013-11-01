#!/usr/bin/perl -w

use strict;
use warnings;
use Data::Dumper;
use Time::Local;
use MongoDB;

our (%conf, %collection, %months, %week, %in, %tmpl, %mesg, %domain_mail, %command_epp, %commands, %menu_line);
our (@week, @sceleton);
our ($domain_sceleton, $domain_info);

require "../drs.pm";

my ($cnt, $key, $collections, $not_exists, $for_detete, $info, $epp, @tmp, %tmp);

$collections = &connect($conf{'database'}, $collection{'domains'});

@tmp = $collections -> find( ) -> all;

$cnt = 0;
foreach $key (@tmp) {
	# Compare exists & needed fields
	print "$key->{'date'} $key->{'expires'} $key->{'exDate'} $key->{'name'} \n";

	$collections->update( { '_id' => $key->{'_id'} }, { '$set' => { 'type' => 'updating' } });

	# foreach (keys %{$not_exists} ) {
		# if (/^date$/) {
			# if (exists $key->{'exDate'}) {
				# $not_exists->{'date'} = &sec2date(&date2sec($key->{'exDate'}), 'md');
			# }
			# else {
				# $not_exists->{'date'} = '';
			# }
		# }
		# elsif (/^expires$/) {
			# if (exists $key->{'exDate'}) {
				# $not_exists->{'expires'} = &date2sec($key->{'exDate'});
			# }
			# else {
				# $not_exists->{'expires'} = '';
			# }
		# }
		# elsif (/^type$/) {
			# $not_exists->{'type'} = 'use';
		# }
		# elsif (/^registrant$/) {
			# delete ($not_exists->{'registrant$'});
			# $tmp{$key->{'name'}} = 1;
		# }
	# }

#	$collections -> update( { '_id' => $key->{'_id'}}, { '$set' => { %{$not_exists }} } );
}
print "======\n";
# print join("\n", keys %tmp);

#print Dumper($dominfo);

############## Subs ##############

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

