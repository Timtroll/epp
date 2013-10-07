#!/usr/bin/perl -w

use strict;
use warnings;
use Net::EPP::Simple;

use XML::Simple;
use MongoDB;

use Data::Dumper;
use Time::Local;

our (%conf, %collection, %months, %week, %in, %tmpl, %mesg, %domain_mail, %command_epp, %commands, %menu_line);

require "drs.pm";

my ($collections, $epp, $resp, $xml, $xml2json, $obj, $count, $frame, $log, $transfer, @tmp);

		# # # Find transfer message in Tranfer base
		# # @tmp = $collections -> find( {}, { 'msg_date' => 1 } ) -> all;
		# # print scalar(@tmp);
		# # print "\n";
		# # foreach (0..(scalar(@tmp)-1)) {
			# # if (exists $tmp[$_]->{'msg_date'}) {
				# # print $tmp[$_]->{'_id'};
		# # print "\n";
				# # $collections->remove({"_id" => $tmp[$_]->{'_id'}});
		# # #		last;
			# # }
		# # }
		# # exit;
# @tmp = $collections -> find( {}, { 'domain:name' => 1 } ) -> all;
# #print Dumper(\@tmp);
# foreach (0..(scalar(@tmp)-1)) {
	# if ($tmp[$_]->{'resData'}->{'domain:trnData'}->{'domain:name'}) {
		# $obj = '';
		# $obj = {
			# 'id'		=> $tmp[$_]->{'msgQ'}->{'id'},
			# 'msg'		=> $tmp[$_]->{'msgQ'}->{'msg'},
			# 'msg_date'	=> $tmp[$_]->{'msgQ'}->{'qDate'},
# #			'msg_date'	=> &sec2date(&date2sec($tmp[$_]->{'msgQ'}->{'qDate'}), '.'),
			# 'name'	=> $tmp[$_]->{'resData'}->{'domain:trnData'}->{'domain:name'},
			# 'epp'		=> '',
			# 'time'	=> &sec2date(time(), '.'),
			# 'status'	=> ((time() -&date2sec($tmp[$_]->{'msgQ'}->{'qDate'})) < 432000) ? 'new' : 'old'
		# };

		# $count = 0;
		# $count =  $transfer -> find( { 'name' => $tmp[$_]->{'resData'}->{'domain:trnData'}->{'domain:name'} } ) -> count;
# # print "$_ = ";
# # print " = ";
# # print $tmp[$_]->{'resData'}->{'domain:trnData'}->{'domain:name'};
# # print "\n";
# # print Dumper(@temp);
# # print "\n";
		# unless ($count) {
			# print Dumper($obj);
			# # Insert message into message base if not exists
			# $transfer->insert( $obj );
		# }
	# }
# }


# exit;

# Connect to Epp server
$epp = &connect_epp();

# Send Request to get Poll
$frame = Net::EPP::Frame::Command::Poll::Req->new;
$resp = $epp->request($frame);

# Store new message if have not errors & message not exists in a base
# Get & store new message
$xml = $resp->toString(1);

# Convert XML response to object
$xml2json = XML::Simple->new();
$obj = $xml2json->XMLin($xml, KeyAttr => '');

# Add new fields to message object
$obj->{'response'}->{'status'} = 'new';
$in{'id'} = $obj->{'response'}->{'message_id'} = $obj->{'response'}->{'msgQ'}->{'id'};

if ($obj->{'response'}->{'message_id'}) {
	$collections = &connect($conf{'database'}, $collection{'messages'});
	$transfer = &connect($conf{'database'}, $collection{'transfer'});
	$log = &connect($conf{'database'}, $collection{'log_poll'});

	# Calculate exist same message in the databse
	$count = $collections -> find( { 'message_id' => $obj->{'response'}->{'message_id'} } ) -> count;

	# Set flag for message reader if message not exists in base and flag not exists too
	unless ($count) {
		# Insert message into message base if not exists
		$collections->insert( $obj->{'response'} );

		unless (-e "$conf{'home'}/poll") {
			# set flag-file for mail icon
			open (FILE, ">$conf{'home'}/poll") or &error_log($log, 'system', "Could not open to write: $conf{'home'}/poll : $!");
				print FILE "";
			close (FILE) or &error_log($log, 'system', "Could not open to write: $conf{'home'}/poll : $!");
			chmod 0666, "$conf{'home'}/poll";
		}
	}

	# Find transfer message in Tranfer base
	$count = 0;
	$count = $collections -> find( { 'resData' => { 'domain:trnData' => {'domain:name' => 1 } } } ) -> count;

	# Set flag for message reader if message not exists in base and flag not exists too
	unless ($count) {
		# check 'pendingTransfer' status for domain
		pendingTransfer

		# Insert trasnfer request into transfer base if not exists
		$collections->insert( {
			'transfer_id' => $obj->{'response'}->{'message_id'},
			'name' =>
		} );

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
					'status'	=> ((time() -&date2sec($tmp[$_]->{'msgQ'}->{'qDate'})) < $conf{'panding_period'}) ? 'new' : 'old'
				} );
			}
		}
	}

	# Ack this message
	$frame = Net::EPP::Frame::Command::Poll::Ack->new;
	$frame->setMsgID($obj->{'response'}->{'message_id'});
	$resp = $epp->request($frame);

	# Convert XML response to object
	$xml = $resp->toString(1);
	$xml2json = XML::Simple->new();
	$obj = $xml2json->XMLin($xml, KeyAttr => '');

	if ($obj->{'response'}->{'result'}->{'code'} == 1000) {
		&error_log($log, 'epp', "Command completed successfully. Ack dequeue. Message id: $in{'id'}");
	}
	else {
		&error_log($log, 'epp', "Connection error when Ack Poll: $obj->{'response'}->{'result'}->{'code'}");
	}
}
else {
	$log = &connect($conf{'database'}, $collection{'log_poll'});
	&error_log($log, 'epp', "We have not message in Poll");
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