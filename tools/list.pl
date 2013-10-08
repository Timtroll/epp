#!/usr/bin/perl -w

use strict;
use warnings;
use Time::Local;
use MongoDB;
use MongoDB::OID;
use Net::EPP::Simple;

use Tie::IxHash;
use JSON::XS;

# for developers
use Data::Dumper;

print "Content-type: text/html; charset = utf-8\nPragma: no-cache\n\n";

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

my @list = ();
open ('TMPL', "</var/www/domain/list.txt") ;
	while(<TMPL>){
		chomp;
		push @list, $_;
	}
close(TMPL);

foreach my $list (@list) {
	my $name = $list;
	$list = `nslookup $list`;
	$list =~ s/\n/ /go;
	$list =~ s/.*answer//;
	$list =~ /Address\:(.*)/;
	$list = $1;
	$list =~ s/ //go;
	print "<li>$list = $name</li>";
}
exit;

# my $json = JSON::XS->new();
# Connect to Epp server
my ($info, $resp);
my $epp = Net::EPP::Simple->new(
	host	=>'epp.uadns.com',
	user	=>'trol-mnt-cunic',
	pass	=>'hB2W2RzO86Fa'
);

#my $test = Net::EPP::Frame::Command::Poll::Req->new;
#my $test = Net::EPP::Frame::Command::Poll::Ack->new;
# $test->addChild($test);
#my $t = $epp->request($test)->msg;
#my $t = $epp->request($test)->code;
#my $t = $epp->request($test)->resData;
#my $t = $epp->request($test)->response;
#my $t = $epp->request($test)->result;
#my $t = $epp->request($test)->trID;
#my $t = $epp->request($test)->clTRID;
#my $t = $epp->request($test)->svTRID;
#print Dumper($t);
#exit;

# Mongo
my $connect = &connect('domains', 'domains_list');
my %data = map { $_-> {'name'}, $_ } $connect -> find( {}, { 'name' => 1 } ) -> all;

foreach (keys %data) {
	print "$_ = ";
	print $data{$_}->{'exDate'};
	print " = ";
$data{$_}->{'date'} = &sec2date(&date2sec($data{$_}->{'exDate'}), 'md');
$data{$_}->{'expires'} = &date2sec($data{$_}->{'exDate'});
	print " = ";
	print $data{$_}->{'date'};
	print "<br>";
	$connect->update( { '_id' => $data{$_}->{'_id'} }, { '$set' => { 'date' =>$data{$_}->{'date'}, 'expires' =>$data{$_}->{'expires'} } } );
}
exit;
foreach my $list (@list) {
	if (exists $data{$list}) {
		next;
	}
	# check domain
	$resp = $epp->check_domain($list);
print "<li>$resp = $list</li>";
	my $cnt = 0;
	if ($resp) {
		print "Домен свободен";
	}
	else {
		$info = undef;
		my $t = undef;
LOOP:	$info = $epp->domain_info($list);
		unless ($info) {
			if ($cnt <50) {
				$cnt++;
				sleep 1;
				goto LOOP;
			}
			else {
				print "<hr><b>Свалился на домене $list<b>";
			}
		}
print Dumper($info);
print $info->{'exDate'}, "<br>";
$info->{'date'} = &sec2date(&date2sec($info->{'exDate'}), 'md');
$info->{'expires'} = &date2sec($info->{'exDate'});
#print Dumper($info);
		$connect->insert($info);
	}
#	print "$list\n<br>";
#print $resp;
#	last;
	sleep 1;
}

sub date2sec {
	my ($date, $sec);
	$date = shift;

	$date =~ /(\d{4}?)\-(\d{2}?)\-(\d{2}?).(\d{2}?)\:(\d{2}?)\:(\d{2}?)/;
#	print "$3 $2 $1 $4 $5 $6<br>";
#	$sec = timelocal($6, $5, $4, $3, $2, $1);
	$sec = timelocal($6, $5, $4, $3, ($2-1), $1);
#print "$sec<br>";
#	print &sec2date($sec);
#print "<br>$sec<br>";
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

	if ($sep eq 'md') {
		$date = $tmp[4].$tmp[3];
	}
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
	unless ($base) { $base = 'domains'; }
	unless ($col) { $col = 'domains'; }

	# Read list of domains
	$client = MongoDB::MongoClient -> new(host => $conf{'database'});
	$db = $client -> get_database( $base );
	$collections = $db->get_collection( $col);

	return $collections;
}
