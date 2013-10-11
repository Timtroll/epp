#!/usr/bin/perl -w

use strict;
use warnings;
use Time::Local;
use MongoDB;
use MongoDB::OID;
use Net::EPP::Simple;

# use Tie::IxHash;
# use JSON::XS;

# for developers
use Data::Dumper;

BEGIN {
	IO::Socket::SSL::set_ctx_defaults(
		'SSL_verify_mode' => 0 #'SSL_VERIFY_NONE'
        );
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = '0';
};

our (%conf, %collection, %months, %week, %in, %tmpl, %mesg, %domain_mail, %command_epp, %commands, %menu_line);

require "../drs.pm";

print "Content-type: text/html; charset = utf-8\nPragma: no-cache\n\n";

# my %conf = (
	# 'give_mail'	=> 'auto-dbm@drs.net.ua',
# #	'give_mail'	=> 'troll@spam.net.ua',
	# 'give_copy'	=> 'timtroll@yandex.ru',
	# 'smtp'	=> '217.20.175.186',
	# 'smtp_port'	=> '587',
	# 'login_mail'	=> 'troll@spam.net.ua',
	# 'pass_mail'	=> 'ghjuhfvvf',
	# 'database'	=> 'mongodb://localhost,localhost;27017',

# # 	# preference URL`s
	# 'public_url'	=> 'http://localhost/domain',
	# 'public_css'	=> 'http://localhost/domain/css',
	# 'public_cgi'	=> 'http://localhost/domain/drs.pl'
# );

my @list = ();
open ('TMPL', "</var/www/epp/tools/list.txt") ;
	while(<TMPL>){
		chomp;
		s/\,.*$//;
		push @list, $_;
	}
close(TMPL);


# Connect to Epp server
my $epp = &connect_epp();

# Mongo
print "$conf{'database'}, $collection{'domains'}\n\n";
my $connect = &connect($conf{'database'}, $collection{'domains'});


foreach my $key (@list) {
	my $count = $connect -> find( {'name' => $key}, { 'name' => 1 } ) -> count;
	unless ($count) {
		print "$key = $count\n";
		my $info = $epp -> domain_info($key);
		print Dumper($info);
		if ($key =~ /wushu.sebastopol.ua/) {
		last;
		}
		$info->{'date'} = &sec2date(&date2sec($info->{'crDate'}), 'md');
		$info->{'expires'} = &date2sec($info->{'exDate'});
		$info->{'type'} = 'use';
		print "\n\n\n";
	}
}
exit;

sub date2sec {
	my ($date, $sec);
	$date = shift;

	$date =~ /(\d{4}?)\-(\d{2}?)\-(\d{2}?).(\d{2}?)\:(\d{2}?)\:(\d{2}?)/;
	$sec = timelocal($6, $5, $4, $3, ($2-1), $1);

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

sub connect {
	my ($col, $client, $db, $base, $collections);
	$base = shift;
	$col = shift;

	# Set collection name if not exists
	unless ($base) { $base = $conf{'database'}; }
	unless ($col) { $col = $collection{'domains'}; }

	# Read list of domains
#	$client = MongoDB::MongoClient->new(host => $conf{'db_link'});
	$client = MongoDB::Connection->new(host => $conf{'db_link'});
	$db = $client->get_database( $base );
	$collections = $db->get_collection( $col);

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

print $Net::EPP::Simple::Error;
	# if (($Net::EPP::Simple::Code == 2500)||($Net::EPP::Simple::Code == 2501)||($Net::EPP::Simple::Code == 2502)) {
		# $in{'messages'} = $Net::EPP::Simple::Message."<br>".$Net::EPP::Simple::Error;
	# }

	return $epp;
}

