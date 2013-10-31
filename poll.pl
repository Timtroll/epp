#!/usr/bin/perl -w

#######
# This tool get Poll messages from Epp to local database 'messages_list'
# For all Ack messages sets 'new' status.
# It must be regular run (once per day or more often)
#######

print "Content-type: text/html; charset = utf-8\nPragma: no-cache\n\n";

use strict;
use warnings;
use Net::EPP::Simple;

use XML::Simple;
use MongoDB;

use Data::Dumper;
use Time::Local;

our (%conf, %collection, %months, %week, %in, %tmpl, %mesg, %domain_mail, %command_epp, %commands, %menu_line);

use Subs; # qw/sec2date/;
require "drs.pm";

my ($messages, $domains, $epp, $obj, $ack, $count, $log, $transfer, @tmp, @temp);
$log = &connect($conf{'database'}, $collection{'log_poll'});

# Connect to Epp server
$epp = &connect_epp();

# Req Poll messages
$obj = &get_req($epp, $log);

# Check exists message
if ($obj->{'message_id'}) {
	$messages = &connect($conf{'database'}, $collection{'messages'});

	# $transfer = &connect($conf{'database'}, $collection{'transfer'});
	# Calculate exist same message in the databse
	$count = $messages -> find( { 'message_id' => $obj->{'message_id'} } ) -> count;

	# Set flag for message reader if message not exists in base and flag not exists too
	unless ($count) {
		# Insert message into message base if not exists
		$messages->insert( $obj );
		&error_log($log, 'epp', "Add new message id: $obj->{'message_id'} in 'messages_list' database");

		unless (-e "$conf{'home'}/poll") {
			# set flag-file for mail icon
			open (FILE, ">$conf{'home'}/poll") or &error_log($log, 'system', "Could not open to write: $conf{'home'}/poll : $!");
				print FILE "";
			close (FILE) or &error_log($log, 'system', "Could not open to write: $conf{'home'}/poll : $!");
			chmod 0666, "$conf{'home'}/poll";
		}
	}

	# Ack this message
	if ($obj->{'message_id'}) {
print "=$obj->{'message_id'}=\n";
		$ack = &get_ack($epp, $log, $obj->{'message_id'});
	}

	# Find transfer message in 'message_list' base
	$count = 0;
	$count = $messages -> find( { 'msgQ.msg' => qr/Pending/i } ) -> count;

	# Set flag for message reader if message not exists in base and flag not exists too
	if ($count) {
		# set date on 5 days before now
		my $cnt = (time() -  60*60*24*5);

		# check 'pending' status for updating domains
		@tmp = $messages -> find( { 'msgQ.msg' => qr/Pending/i, 'date' => { '$gte' => $cnt } } ) -> sort( { 'date' => -1 } ) -> all; # , { 'resData.drs:notify.drs:object' => 1 }
# print Dumper($count);
print scalar(@tmp);
print "<br>";
$count = 0;
		foreach (@tmp) {
			# Skip error action
			unless ($_->{'msgQ'}->{'msg'} =~ /Pending action completed with error/ ) {
				# Find domain name in Poll message
				my $name = '';
				if ($_->{'resData'}->{'domain:panData'}->{'domain:name'}->{'content'}) {
					$name = $_->{'resData'}->{'domain:panData'}->{'domain:name'}->{'content'};
				}
				elsif ($_->{'resData'}->{'domain:trnData'}->{'domain:name'}) {
					$name = $_->{'resData'}->{'domain:trnData'}->{'domain:name'};
				}
				if ($name) {
					$domains = &connect($conf{'database'}, $collection{'domains'});
			
					# Change domain 'type' to 'updating' for checking data equals
					@temp = $domains -> find( { 'name' => $name } ) -> all;
					if (scalar(@temp)) {
						$domains->update( { '_id' => $temp[0]->{'_id'}}, { '$set' => { 'type' => 'updating' } } );
					print "$temp[0]->{'_id'} $count =  $cnt ", int((time() - $_->{'date'})/24/60/60), " $_->{'msgQ'}->{'qDate'} ";
					print $_->{'resData'}->{'domain:panData'}->{'domain:name'}->{'content'} if $_->{'resData'}->{'domain:panData'}->{'domain:name'}->{'content'};
			#		print " = ";
					print $_->{'resData'}->{'domain:trnData'}->{'domain:name'}, ' = ' if $_->{'resData'}->{'domain:trnData'}->{'domain:name'};
					print " $_->{'msgQ'}->{'msg'}";
					print "<br>\n";
					}
				}
				$count++;
			}
		}

		# check 'pendingTransfer' status for my domains
exit;
		# Insert trasnfer request into transfer base if not exists
		# $messages->insert( {
			# 'transfer_id' => $obj->{'message_id'},
			# 'name' =>
		# } );

		if ($obj->{'msgQ'}->{'msg'}) {
			# Find transfer message in Tranfer base
			$count = 0;
			$count =  $transfer -> find( { 'name' => $tmp[$_]->{'resData'}->{'domain:trnData'}->{'domain:name'} } ) -> count;

			unless ($count) {
print Dumper($obj);
				# Insert message into message base if not exists
				$transfer->insert( {
					'id'		=> $tmp[$_]->{'msgQ'}->{'id'},
					'msg'		=> $tmp[$_]->{'msgQ'}->{'msg'},
					'msg_date'	=> $tmp[$_]->{'msgQ'}->{'qDate'},
					'name'	=> $tmp[$_]->{'resData'}->{'domain:trnData'}->{'domain:name'},
					'epp'		=> '',
					'time'	=> &sec2date(time(), '.'),
					'status'	=> ((time() - &date2sec($tmp[$_]->{'msgQ'}->{'qDate'})) < $conf{'panding_period'}) ? 'new' : 'old'
				} );
			}
		}
	}
}

exit;

############## Subs ##############

sub get_ack {
	my ($epp, $log, $id, $mess, $frame, $resp, $obj, $xml, $xml2json);
	$epp = shift;
	$log = shift;
	$id = shift;

	# Ack this message
	$frame = Net::EPP::Frame::Command::Poll::Ack->new;
	$frame->setMsgID($id);
	$resp = $epp->request($frame);

	# Convert XML response to object
	$xml = $resp->toString(1);
	$xml2json = XML::Simple->new();
	$obj = $xml2json->XMLin($xml, KeyAttr => '');

	&log_poll($obj, 'Ack');

	return $obj->{'response'};
}

sub get_req {
	my ($epp, $log, $mess, $frame, $resp, $xml, $obj, $xml2json);
	$epp = shift;
	$log = shift;

	# Send Request to get Poll
	$frame = Net::EPP::Frame::Command::Poll::Req->new;
	$resp = $epp->request($frame);

	# Store new message if have not errors & message not exists in a base
	# Get & store new message
	$xml = $resp->toString(1);

	# Convert XML response to object
	$xml2json = XML::Simple->new();
	$obj = $xml2json->XMLin($xml, KeyAttr => '');

	# Add'new fields to message object
print Dumper($obj);
	if ($obj->{'response'}->{'msgQ'}->{'qDate'}) {
		$obj->{'response'}->{'date'} = &date2sec($obj->{'response'}->{'msgQ'}->{'qDate'});
	}
	else {
		$obj->{'response'}->{'date'} = time();
	}
	$obj->{'response'}->{'status'} = 'new';
	$obj->{'response'}->{'message_id'} = $obj->{'response'}->{'msgQ'}->{'id'};

	&log_poll($obj, 'Req');

	return $obj->{'response'};
}

sub log_poll {
	my ($obj, $mess);
	$obj = shift;
	$mess = shift;

	$mess = "$obj->{'response'}->{'result'}->{'code'}: '$mess' $obj->{'response'}->{'result'}->{'msg'}.";
	if ($obj->{'response'}->{'message_id'}) {
		$mess .= " Message id: $obj->{'response'}->{'message_id'}";
	}
	&error_log($log, 'epp',  $mess);
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