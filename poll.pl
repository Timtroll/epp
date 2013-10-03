#!/usr/bin/perl -w

use strict;
use warnings;
use Encode qw(encode decode);
use Net::EPP::Simple;
use Net::EPP::Simple;

use XML::Simple;
use MongoDB;

use Time::Local;

print "Content-type: text/html; charset = utf-8\nPragma: no-cache\n\n";

our (%conf, %collection, %months, %week, %in, %tmpl, %mesg, %domain_mail, %command_epp, %commands, %menu_line);
require "drs.pm";

my ($collections, $epp, $resp, $xml, $xml2json, $obj, $count, $frame, $log, @tmp);

# Connect to Epp server
$epp = &connect_epp();

# Send Request to get Poll
$frame = Net::EPP::Frame::Command::Poll::Req->new;
$resp = $epp->request($frame);


# print $Net::EPP::Simple::Code;
# print $Net::EPP::Simple::Error;
# print $Net::EPP::Simple::Message;

# Store new message if have not errors & message not exists in a base
# Get & store new message
$xml = $resp->toString(1);

# print Dumper($xml);

# Convert XML response to object
$xml2json = XML::Simple->new();
$obj = $xml2json->XMLin($xml, KeyAttr => '');

# Add new fields to message object
$obj->{'response'}->{'status'} = 'new';
$obj->{'response'}->{'id'} = $obj->{'response'}->{'msgQ'}->{'id'};

# print $obj->{'response'}->{'id'};
# print $in{'messages'};
# print Dumper($obj);

if ($obj->{'response'}->{'id'}) {
	$collections = &connect($conf{'database'}, $collection{'messages'});
	$log = &connect($conf{'database'}, $collection{'log_poll'});

	# Calculate exist same message in the databse
	$count = $collections -> find( { 'id' => $obj->{'response'}->{'id'} } ) -> count;

	# Insert message into message base if not exists
#	$collections->insert( $obj->{'response'} );

	unless ($count) {
		unless (-e "$conf{'home'}/poll") {
print "=$count=";
print $obj->{'response'}->{'id'};

			# set flag-file for mail icon
			open (FILE, ">$conf{'home'}/poll") or &error_log($log, 'system', "Could not open to write: $conf{'home'}/poll : $!");
				print FILE "";
			close (FILE) or &error_log($log, 'system', "Could not open to write: $conf{'home'}/poll : $!");
			chmod 0666, "$conf{'home'}/poll";
		}

		# Ack this message
		$frame = Net::EPP::Frame::Command::Poll::Ack->new;
		$frame->setMsgID($in{'id'});
		$resp = $epp->request($frame);

		# Convert XML response to object
		$xml = $resp->toString(1);
		$xml2json = XML::Simple->new();
		$obj = $xml2json->XMLin($xml, KeyAttr => '');

		# check response errors
		&check_response($obj, 2001, 2004, 2400);
print $obj->{'response'}->{'result'}->{'code'};
#		if ($obj->{'response'}->{'result'}->{'code'} == 1000) {
			&error_log($log, 'epp', "We has EPP error during Ack massage");
#		}
	}
}

print "Good";
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
		'type'		=> $data ? $data : '' 
	};
	$collection->insert( $srting );

	$data = $srting = '';
	return;
}