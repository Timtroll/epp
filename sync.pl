#!/usr/bin/perl -w

use strict;
use warnings;
use MongoDB;
use MongoDB::OID;
use Data::Dumper;
use Net::EPP::Simple;
use Time::Local;

BEGIN {
	IO::Socket::SSL::set_ctx_defaults(
		'SSL_verify_mode' => 0 # 'SSL_VERIFY_NONE'
        );
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = '0';
};

our (%conf, %collection, %months, %week, %in, %tmpl, %mesg, %domain_mail, %command_epp, %commands, %menu_line);

require "drs.pm";

print "Content-type: text/html; charset = utf-8\nPragma: no-cache\n\n";

my ($collections, $count, $cnt, $info, $epp, $diff, $flag, $key, $kkey, @tmp, @temp, %tmp, %list, %df);

# get list of my domains
open (FILE, "<./list.txt") or die ($!);
	while (<FILE>) {
		s/\r//;
		chomp;
		$list{$_} = 1;
	}
close (FILE) or die;

# Send create domain request
$epp = &connect_epp();

$collections = &connect($conf{'database'}, $collection{'domains'});

# Calculate exist same message in the databse
#@tmp = $collections -> find( { } ) -> all;

foreach $cnt (keys %list) {
	$count = 0;
#	$count = $collections -> find( { 'add' => {'$exists' => 1 },  'name' => $cnt } ) -> count;
	
	# check domain
	$info = $epp->domain_info($cnt);
	
	# delete from real list of domains
	# if (exists $list{$tmp[$cnt]->{'name'}}) {
		# delete ($list{$tmp[$cnt]->{'name'}});
	# }
	# else {
	print "=$cnt=";
	@tmp =();
	if ($info->{'ns'}) { @tmp = @{$info->{'ns'}}; }
	else {
		$df{$cnt} = 1;
	}
	@temp =();
	if ($info->{'status'}) { @temp = @{$info->{'status'}}; }
	else {
		$df{$cnt} = 1;
	}
	%tmp =();
	if ($info->{'contacts'}) { %tmp = %{$info->{'contacts'}}; }
	else {
		$df{$cnt} = 1;
	}
		$diff = {
		  'registrant' => $info->{'registrant'},
		  'clID' => $info->{'clID'},
		  'roid' => $info->{'roid'},
		  'status' => [ @temp ],
		  'date' => &sec2date(&date2sec($info->{'exDate'}), 'md'),
		  'authInfo' => $info->{'authInfo'},
		  'crID' => $info->{'crID'},
		  'upDate' =>$info->{'upDate'},
		  'contacts' => { %tmp },
		  'exDate' => $info->{'exDate'},
		  'name' => $info->{'name'},
		  'upID' => $info->{'upID'},
		  'ns' =>[ @tmp ],
		  'crDate' => $info->{'crDate'},
		  'expires' => $info->{'exDate'} ? &date2sec($info->{'exDate'}) : ''
		};
		print Dumper($diff);
		$collections->insert( $info );
	# }
	sleep(0.5);
}

print "==========\n";
print join("\n", keys %df);

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

