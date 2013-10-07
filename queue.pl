#!/usr/bin/perl -w

use strict;
use warnings;
use MongoDB;
use Encode qw(encode decode);
use Net::EPP::Simple;

use Data::Dumper;

print "Content-type: text/html; charset = utf-8\nPragma: no-cache\n\n";

our (%conf, %collection, %months, %week, %in, %tmpl, %mesg, %domain_mail, %command_epp, %commands, %menu_line);

require "drs.pm";

my ($log, $info, $epp, @data);

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

