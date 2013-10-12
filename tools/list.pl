#!/usr/bin/perl -w

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

require "drs.pm";

my ($log, $collection, $info, $epp, @data, @diff, %list, %diff);

if (-e "/var/www/epp/list.txt") {
	open ('TMPL', "</var/www/epp/list.txt") ;
		while(<TMPL>){
			chomp;
			s/\,.*$//;
#print "$_\n";
			$list{$_} = 1;
		}
	close(TMPL);
}

# Connect to Epp server
$epp = &connect_epp();
# print Dumper($epp->domain_info(''));
# exit;

$collection = &connect($conf{'database'}, $collection{'domains'});

# Check equal data in EPP & database & check doubles in database
#@data = $collection -> find( {'type' => 'updating'}, {'name' => 1}) -> all;
@data = $collection -> find( {}, {'name' => 1}) -> all;

foreach my $key (@data) {
	# Check exists domain in the file list
	if (exists $list{$key->{'name'}}) {
		delete $list{$key->{'name'}};
	}
}

my $cc = 0;
foreach my $key (@data) {
	unless (exists $diff{$key->{'name'}}) {
		$diff{$key->{'name'}} = 1;

		# Get domain fields from Epp
		my $request = $epp->domain_info($key->{'name'});

		# compare database & Epp documents
		my $tmp = &cmp_obj($key, $request);
		print "$key->{'name'}\n";
		if (scalar(keys %{$tmp})) {
			# print Dumper($key);
			# print Dumper($request);
			# print Dumper($tmp);
		}

		$cc++;
	}
	else {
		push @diff, $key->{'_id'};
	}
}
print "$cc\n";

# Delete doubles if them found in database
if (scalar(@diff)) {
	print "===Doubles===\n";
	foreach my $key (@diff) {
		print "$key\n";
		$collection->remove({"_id" => $key});
	}
}

# Insert new domains if them not found in database
if (scalar(keys %list)) {
	print "===New===\n";
	print scalar(keys %list);

	foreach my $key (keys %list) {
		my $request = $epp->domain_info($key);
		$request->{'date'} = &sec2date(&date2sec($request->{'crDate'}), 'md');
		$request->{'expires'} = &date2sec($request->{'exDate'});
		$request->{'type'} = 'updating';
		$request->{'upDate'} = '';
		print Dumper($request);
		$collection->insert( $request );
	}
}

exit;

sub cmp_obj {
	my ($data, $target, $tmp, @tmp, %tmp);
	$data = shift; # source
	$target = shift; # target

	# Set fields skiped for check
	map { $tmp{$_} = 1 } ( '_id', 'authInfo', 'clID', 'crDate', 'crID', 'date', 'expires', 'roid', 'type', 'upDate', 'upID' );

	$tmp = &cmp_hash($data, $target);

	foreach (keys %{$tmp}) {
		# skip non checked fields
		if (exists $tmp{$_}) {
			delete ($$tmp{$_});
			next;
		}

#		if (ref($$tmp{$_}) eq 'ARRAY') {
#			print "$_ = @{$$tmp{$_}}\n";
#		}
#		else {
#			print "$_ = $$tmp{$_}\n";
#		}
	}

	%tmp = ();
	@tmp = ();
	return $tmp;
}

##########################

$log = &connect($conf{'database'}, $collection{'queue'});

@data = $log -> find( {} ) -> all;

foreach (0..(scalar(@data) - 1)) {
print "<li>$data[$_]->{'name'}</li>";
	
	# Connect to Epp server
	$epp = &connect_epp();

	# check domain
	$info = $epp->domain_info($data[$_]->{'name'});
	
	&check_response($info, 2001);

	if ($Net::EPP::Simple::Code == 1000) {
		# Convert response to UTF8
		$info = &obj2utf($info);

		$in{'messages'} = "Домен зарегистрирован. Последнее обновление ".$info->{upDate}." till ".$info->{exDate}." by ".$info->{clID};
	}
	elsif ($Net::EPP::Simple::Code == 2001 || $Net::EPP::Simple::Code == 2202) {
		$in{'messages'} .= "Ошибка EPP: <li>$Net::EPP::Simple::Code</li><li>$Net::EPP::Simple::Message</li><li>$Net::EPP::Simple::Error</li>";
	}

	if ($data[$_]->{'command'} =~ /^domain_create$/) {
print Dumper($info);
print "\n\n";
print Dumper($data[$_]);
	}
	elsif ($data[$_]->{'command'} =~ /^domain_update$/) {
	}
exit;
	# $log->update(
		# { '_id' => $data[$_]->{'_id'} },
		# { '$set' => { 'message_id' => $data[$_]->{'msgQ'}->{'id'} } },
	# );
	#{}, {$set => {"message_id" => x.name.additional}, $unset => {"id" =>1}}
}

exit;

############## Subs ##############

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

sub uniq_cmp_array {
	my ($data, $target, $arrayd, $arrayt, $diff, @diff, %tmp);
	$data = shift;
	$target = shift;

	if (scalar(@{$data}) <= scalar(@{$target})) {
		$arrayt = $target;
		$arrayd = $data;
		$diff = 1;
	}
	else {
		$arrayt = $data;
		$arrayd = $target;
		$diff = -1;
	}
	map { $tmp{$_} = 1; } (@{$arrayd});

	map {
		unless (exists $tmp{$_}) {
			push @diff, $_;
		}
	}  (@{$arrayt});


	if (scalar(@diff)) {
		return $diff, \@diff;
	}
	else {
		return;
	}
}

sub cmp_hash {
	my ($data, $target, $key, $tmp, $diff, %tmp);
	$data = shift;
	$target = shift;

	foreach $key (keys %{$data}) {
		if (exists($$target{$key})) {
			if ((ref($$data{$key}) eq 'HASH') && (ref($$target{$key}) eq 'HASH')) {
				$tmp = &cmp_hash($$data{$key}, $$target{$key});
				if (ref($tmp) eq 'HASH') {
					$tmp{$key} = $tmp;
				}
			}
			elsif ((ref($$data{$key}) eq 'ARRAY') && (ref($$target{$key}) eq 'ARRAY')) {
				($diff, $tmp) = &uniq_cmp_array($$data{$key}, $$target{$key});
				if ($diff && $tmp) {
					if (ref($tmp) eq 'ARRAY') {
						$tmp{$key} = $tmp;
					}
				}
			}
			else {
				if (($$data{$key} =~ /\D/) || ($$target{$key} =~ /\D/)) {
					unless ($$data{$key} eq $$target{$key}) {
						$tmp{$key} = $$target{$key};
					}
				}
				else {
					unless ($$data{$key} == $$target{$key}) {
						$tmp{$key} = $$target{$key};
					}
				}
			}
		}
		else {
			$tmp{$key} = $$target{$key};
		}
	}
	if (scalar(keys %tmp)) {
		return \%tmp;
	}
	else {
		return;
	}
}

sub check_response {
	my ($obj, @erors);
	$obj = shift;
	@erors = @_;

	# Find errors in the EPP response
	unless ($obj) {
		foreach (@erors) {
			if ($Net::EPP::Simple::Code == $_) {
				$in{'messages'} .= $mesg{'epp_connection_error'}.' : Code '.$Net::EPP::Simple::Code."<br>";
				$in{'messages'} .= $Net::EPP::Simple::Message."<br>".$Net::EPP::Simple::Error;
				last;
			}
		}
	}
	else {
		foreach (@erors) {
			if ($obj->{'response'}->{'result'}->{'code'}) {
				if ($obj->{'response'}->{'result'}->{'code'} == $_) {
					$in{'messages'} .= $mesg{'epp_request_error'}.' : Code '.$obj->{'response'}->{'result'}->{'code'}."<br>";
					$in{'messages'} .= $obj->{'response'}->{'result'}->{'msg'}."<br>".$obj->{'response'}->{'trID'}->{'svTRID'};
					last;
				}
			}
		}
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

sub obj2utf {
	my ($obj, $key);
	$obj = shift;

	foreach $key (keys %{$obj}) {
		if (ref($obj->{$key}) eq 'HASH') {
			$obj->{$key} = &hash2utf($obj->{$key});
		}
		elsif (ref($obj->{$key}) eq 'ARRAY') {
			$obj->{$key} = &array2utf($obj->{$key});
		}
		else {
			$obj->{$key} = encode('UTF8', $obj->{$key});
		}
	}

	return $obj;
}

sub hash2utf {
	my ($hach, $key);
	$hach = shift;

	foreach $key (keys %{$hach}) {
		if (ref($hach->{$key}) eq 'HASH') {
			$hach->{$key} = &hash2utf($hach->{$key});
		}
		elsif (ref($hach->{$key}) eq 'ARRAY') {
			$hach->{$key} = &array2utf($hach->{$key});
		}
		else {
			$hach->{$key} = encode('UTF8', $hach->{$key});
		}
	}

	return $hach;
}

sub array2utf {
	my ($arr, @tmp);
	$arr = shift;

	@tmp = @{$arr};
	foreach (@tmp) {
		if (ref($_) eq 'HASH') {
			$_ = &hash2utf($_);
		}
		elsif (ref($_) eq 'ARRAY') {
			$_ = &array2utf($_);
		}
		else {
			$_ = encode('UTF8', $_);
		}
	}

	return \@tmp;
}

