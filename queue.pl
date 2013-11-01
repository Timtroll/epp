#!/usr/bin/perl -w

#######
# This tool sycn data between Epp & local database 'domains'
# It changing type of document to 'use' if database & Epp info are equal.
# It must be regular run (once per day or more often)
#######

use strict;
use warnings;
use MongoDB;
use Encode qw(encode decode);
use Net::EPP::Simple;
use Time::Local;

use Data::Dumper;

print "Content-type: text/html; charset = utf-8\nPragma: no-cache\n\n";

our (%conf, %collection, %months, %week, %in, %tmpl, %mesg, %domain_mail, %command_epp, %commands, %menu_line);
our ($domain_info);

use Subs;
require "drs.pm";

my ($log, $collection, $request, $key, $tmp, $epp, @data, @skip);

$collection = &connect($conf{'database'}, $collection{'domains'});
$log = &connect($conf{'database'}, $collection{'queue_log'});

# Get list of domain cantained type as 'updating'
@data = $collection -> find( {'$or' => [ {'type' => 'updating'}, {'type' => 'creating'} ] }) -> all;

# Connect to Epp server
$epp = &connect_epp();

foreach $key (@data) {
	# Get domain fields from Epp
	$request = $epp->domain_info($key->{'name'});

	# compare database & Epp documents
	@skip = ( '_id', 'authInfo', 'clID', 'crDate', 'crID', 'roid', 'upDate', 'upID', 'date', 'period', 'expires', 'type' );
	if (($key->{'name'} =~ /^[\w\d]+\.ua$/)||($key->{'name'} =~ /^.*\.in\.ua$/)||($key->{'name'} =~ /^.*\.crimea\.ua$/)||($key->{'name'} =~ /^.*\.od\.ua$/)) {
		push @skip, 'registrant';
	}
	if ($key->{'type'} eq 'updating') {
		$tmp = &cmp_obj($key, $request, \@skip);
print "$key->{'name'}\n";
print Dumper($tmp);
		unless (scalar(keys %{$tmp})) {
			# Change type to 'use' if database & Epp info are equal
			$collection->update( { '_id' => $key->{'_id'} }, { '$set' => { 'type' => 'use' } });

			# print $key->{'name'};
			&error_log($log, 'queue', "Success $key->{'type'} domain $key->{'name'}. Change '$key->{'type'}' to 'use'");
			last;
		}
	}
	elsif ($key->{'type'} eq 'creating') {
print "$key->{'name'} $Net::EPP::Simple::Code\n";
		if ($Net::EPP::Simple::Code == 1000) {
			# Change type to 'use' if database & Epp info are equal
			$collection->update( { '_id' => $key->{'_id'} },
			{
				'$set' => {
					'type' => 'use',
					'exDate' => $request->{'exDate'},
					'expires' => &date2sec($request->{'exDate'}),
					'date' => &sec2date(&date2sec($request->{'exDate'}), 'md')
				}
			});

			# print $key->{'name'};
			&error_log($log, 'queue', "Success $key->{'type'} domain $key->{'name'} was add. Change '$key->{'type'}' to 'use'");
			last;
		}
	}

	$request = $tmp = '';
}

exit;

############## Subs ##############

sub cmp_obj {
	my ($data, $target, $tmp, $skip, @tmp, %tmp);
	$data = shift; # source
	$target = shift; # target
	$skip = shift; # target

	# Set fields skiped for check
	map { $tmp{$_} = 1 } ( @{$skip} );

	$tmp = &cmp_hash($data, $target);

	foreach (keys %{$tmp}) {
		# skip non checked fields
		if (exists $tmp{$_}) {
			delete ($$tmp{$_});
		}
	}
	%tmp = ();
	@tmp = ();

	return $tmp;
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

sub error_log {
	my ($collection, $log, $type, $data, $srting);
	$collection = shift;
	$type = shift;
	$data = shift;

	unless ($data) {
		return;
	}

	$srting = {
		'time'	=> time(),
		'type'		=> $type ? $type : '',
		'data'		=> $data ? $data : ''
	};
	$collection->insert( $srting );

	$data = $srting = '';
	return;
}
