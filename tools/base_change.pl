#!/usr/bin/perl -w

use strict;
use warnings;
use Data::Dumper;
use Net::EPP::Simple;
use Time::Local;
use MongoDB;

BEGIN {
	IO::Socket::SSL::set_ctx_defaults(
		'SSL_verify_mode' => 0 # 'SSL_VERIFY_NONE'
        );
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = '0';
};

our (%conf, %collection, %months, %week, %in, %tmpl, %mesg, %domain_mail, %command_epp, %commands, %menu_line);
our (@week, @sceleton);
our ($domain_sceleton, $domain_info);

require "../drs.pm";

my ($cnt, $key, $collections, $not_exists, $for_detete, $info, $epp, @tmp, %tmp);

# Send create domain request
$epp = &connect_epp();

$collections = &connect($conf{'database'}, $collection{'domains'});

@tmp = $collections -> find( ) -> all;

$cnt = 0;
foreach $key (@tmp) {
	# Compare exists & needed fields
	print "$key->{'_id'} $key->{'name'}\n";
	($not_exists, $for_detete) = &normalize($domain_info, $key);

	# check domain
	$info = $epp->domain_info($key->{'name'});

	# Prepare fields for adding
	foreach (keys %{$not_exists} ) {
		if (/^date$/) {
			if (exists $key->{'exDate'}) {
				$not_exists->{'date'} = &sec2date(&date2sec($key->{'exDate'}), 'md');
			}
			else {
				$not_exists->{'date'} = '';
			}
		}
		elsif (/^expires$/) {
			if (exists $key->{'exDate'}) {
				$not_exists->{'expires'} = &date2sec($key->{'exDate'});
			}
			else {
				$not_exists->{'expires'} = '';
			}
		}
		elsif (/^type$/) {
			$not_exists->{'type'} = 'use';
		}
		elsif (/^registrant$/) {
			delete ($not_exists->{'registrant$'});
			$tmp{$key->{'name'}} = 1;
		}
	}

	$collections -> update( { '_id' => $key->{'_id'}}, { '$set' => { %{$not_exists }} } );
	$cnt++;
}
print "======\n";
print join("\n", keys %tmp);

#print Dumper($dominfo);

############## Subs ##############

sub date2sec {
	my ($date, $sec);
	$date = shift;

	if ($date) {
		$date =~ /(\d{4}?)\-(\d{2}?)\-(\d{2}?).(\d{2}?)\:(\d{2}?)\:(\d{2}?)/;
		$sec = timelocal($6, $5, $4, $3, ($2-1), $1);
	}

	return $sec;
}

sub sec2date {
	my ($sec, $sep, $date, @tmp);
	$sec = shift;
	$sep = shift;

	unless ($sep) { $sep = '/'; }
	@tmp = localtime($sec);
	if ($tmp[0] < 10) { $tmp[0] ='0'.$tmp[0]; }
	if ($tmp[1] < 10) { $tmp[1] ='0'.$tmp[1]; }
	if ($tmp[2] < 10) { $tmp[2] ='0'.$tmp[2]; }
	if ($tmp[3] < 10) { $tmp[3] ='0'.$tmp[3]; }
	$tmp[4] = ($tmp[4]+1);
	if ($tmp[4] < 10) { $tmp[4] ='0'.$tmp[4]; }

	# 1101 (month+day)
	if ($sep eq 'md') {
		$date = $tmp[4].$tmp[3];
	}
	# 2011-12-06T08:53:24.0948Z
	elsif ($sep eq 'iso') {
		$date = ($tmp[5]+1900)."-$tmp[4]-$tmp[3]T$tmp[2]:$tmp[1]:$tmp[0].1111Z";
	}
	# 2001-12-01 (yy-mm-dd where '-' is separeator)
	elsif ($sep eq 'date') {
		$date = ($tmp[5]+1900)."-".$tmp[4]."-".$tmp[3];
#		$date = ($tmp[5]+1900)."-".$tmp[3]."-".$tmp[4];
	}
	# 01-02-2001 (dd-mm-yy where '-' is separeator)
	else {
		$date = $tmp[3].$sep.$tmp[4].$sep.($tmp[5]+1900);
	}
	@tmp = ();

	return $date;
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

sub normalize {
	my ($first, $secont, $key, %tmp, %not_exists, %for_delete);
	$first = shift;
	$secont = shift;

	if ((ref($first) eq ref($secont)) && (ref($first) eq 'HASH')) {
		%tmp = (%{$first}, %{$secont});
		foreach $key (keys %{$first}) {
			unless ($key =~ /^_id$/) {
				unless (exists $secont->{$key}) {
					$not_exists{$key} = 1;
				}
			}
		}
		foreach $key (keys %{$secont}) {
			unless ($key =~ /^_id$/) {
				unless (exists $first->{$key}) {
					$for_delete{$key} = 1;
				}
			}
		}
	}

	return \%not_exists, \%for_delete;
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

