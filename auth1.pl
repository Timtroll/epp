#!/usr/bin/perl -w

use strict;
use HTTP::Daemon;
use HTTP::Status;
use MongoDB;
use threads;

# use threads;
our ($answer, %conf, %collection, %pass);
require "drs.pm";

my $script_host = 'http://localhost';
my $port = 666;

my $daemon = HTTP::Daemon->new(
	LocalAddr => 'troll', #$ARGV[0],
	Reuse => 1,
	Listen => 200,
	LocalPort => $port
) || die;

# load password hash
&load_users();
print "Please contact me at: <URL:", $daemon->url, ">\n";

while (1) {
	while ($answer = $daemon->accept) {
		threads->create(\&process_client_requests, $answer)->detach;
	}
}
exit;

sub process_client_requests {
	my $answer = shift;
#	$answer->daemon->close;  # close server socket in client
	while( my $resp = $answer->get_request) {
		if (($resp->method eq 'GET') and (length($resp->uri->path) < 256)) {
			my %pram = ();
			$answer->send_basic_header;

			my $param = $resp->url->path;
			$param =~ s/^.*\///;
			$param =~ s/\?//;
			$param = substr($param, 0, 64);
			if ($param =~ /\&/) {
				if ($param =~ /reload\=/) { $pram{'reload'} = 1; }
				else {
					my @tmp = split('&', $param);
					foreach (@tmp) {
						my @temp = split('=', $_);
						if ($temp[0] =~ /^user$/) {
							$pram{'user'} = $temp[1];
						}
						elsif ($temp[0] =~ /^pass$/) {
							$pram{'pass'} = $temp[1];
						}
					}
				}
			}
			else {
				if ($param =~ /reload\=/) { $pram{'reload'} = 1; }
			}

			# Command selector
			if ($pram{'reload'}) {
				&load_users();
				&print_response($answer, "reloaded");
			}
			elsif ($pram{'user'} && $pram{'pass'}) {
				# threads->new(\&get_now, $pram{'user'}, $pram{'pass'})->dettach();
				&get_now($answer, $pram{'user'}, $pram{'pass'});
			}
			else {
				&print_response($answer, 0);
			}
		}
		else {
			$answer->send_error(RC_FORBIDDEN)
			# undef($answer);
		}
	}
	# $answer->close;
}

sub res {
    HTTP::Response->new(
        RC_OK, OK => [ 'Content-Type' => 'text/html' ], shift
    )
}

sub print_response {
	my ($answer, $text);
	$answer = shift;
	$text = shift;

	$answer->send_response( &res($text) );
	$answer->close;
	undef($answer);

	return;
}

sub load_users {
	my ($client, $db, $collections, @data);

	# Read list of domains
	$client = MongoDB::Connection->new(
		host		=> $conf{'mongohost'},
		query_timeout	=> 1000,
		username	=> $conf{'mongouser'},
		password	=> $conf{'mongopass'}
	);
	$db = $client->get_database( $conf{'database'} );
	$collections = $db->get_collection( $collection{'contacts'} );

	@data = $collections->find()->all;
	%pass = ();
	map {
		if ($_->{'user'} && $_->{'pass'}) {
			$pass{$_->{'user'}} = $_->{'pass'};
		}
	} (@data);
	$client = $db = $collections = '';
	@data = ();
	return;
}

sub get_now {
	my ($answer, $user, $pass);
	$answer = shift;
	$user = shift;
	$pass = shift;

	if ($user && $pass) {
		if (exists $pass{$user}) {
			if ($pass{$user} =~ /$pass/) {
				&print_response($answer, 1);
			}
			else {
				&print_response($answer, 0);
			}
		}
		else {
			&print_response($answer, 0);
		}
	}
	else {
		&print_response($answer, 0);
	}

	return;
}
