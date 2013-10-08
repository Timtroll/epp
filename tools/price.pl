#!/usr/bin/perl -w

use strict;
use warnings;
use LWP::Simple;
use Data::Dumper;
use MongoDB;
use MongoDB::OID;

print "Content-type: text/html; charset = utf-8\nPragma: no-cache\n\n";

my %in = ();
my %conf = (
	'give_mail'	=> 'auto-dbm@drs.net.ua',
#	'give_mail'	=> 'troll@spam.net.ua',
	'give_copy'	=> 'timtroll@yandex.ru',
	'smtp'	=> '217.20.175.186',
	'smtp_port'	=> '587',
	'login_mail'	=> 'troll@spam.net.ua',
	'pass_mail'	=> 'ghjuhfvvf',
	'database'	=> 'mongodb://localhost,localhost;27017',

	# preference URL`s
	'public_url'	=> 'http://localhost/domain',
	'public_css'	=> 'http://localhost/domain/css',
	'public_cgi'	=> 'http://localhost/domain/drs.pl'
);

# Mongo
my $connect = &connect('domains', 'zones_list');
# my %data = map {$_-> {'domain'} , $_} $connect -> find( {}, { 'domain' => 1 } ) -> all;
# foreach (keys %data) {
	# print  "<li>$_ = ", Dumper($data{$_}), " = " ,$data{$_} ->{'_id'}, "</li>\n";
# }
# exit;

&get_price($connect);
print $in{'messages'};

sub get_price {
	my ($key, $search, $content, $connect, @tmp, @table, %data);
	$connect = shift;

	# Get new price
	$content = get("http://drs.ua/rus/price.html") or $in{'messages'} .= 'Не удалось получить свежий прайс';
	$content =~ /.*\<div\sclass\=\"current\-orders\"\>(.*?)<\/div>.*/;

	@table = split ('</tr><tr>', $1);
	if (scalar(@table)) {
		# check exists price in database
		%data = map {$_-> {'zone'} , $_} $connect -> find( {}, { 'zone' => 1 } ) -> all;
#		%data = map {$_-> {'domain'} , } $connect -> find( {}, { 'domain' => 1 } ) -> all;
#exit;
		foreach my $string (@table) {
			@tmp = ();
			@tmp = split('</td><td>', $string);
			$key = shift @tmp;
			$key =~ s/<.*>//;
			$tmp[$#tmp] =~ s/<.*>//;
print "<li>$key ";
if (exists $data{$key}) {
	print $data{$key} ->{'_id'};
	print " ~ ";
	print $data{$key} ->{'price'}[1];
}
print "</li>\n";
			$connect->insert( { 'zone' => $key, 'price' =>[ @tmp ] } );
		}
	}
	else {
		$in{'messages'} .= 'Неправильный формат прайса - http://drs.ua/rus/price.html';
	}

	return scalar(@table);
}



sub connect {
	my ($col, $client, $db, $base, $collections);
	$base = shift;
	$col = shift;

	# Set collection name if not exists
	unless ($base) { $base = 'domains'; }
	unless ($col) { $col = 'domains'; }

	# Read list of domains
	$client = MongoDB::MongoClient -> new(host => $conf{'database'});
	$db = $client -> get_database( $base );
	$collections = $db->get_collection( $col);

	return $collections;
}
