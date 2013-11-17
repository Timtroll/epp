#!/usr/bin/perl -w

use LWP::Simple;


while (1) {
	@chars = split('', 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz');
	$user = join("", @chars[ map{ rand @chars } (0 .. 6) ]);
	@chars = split('', 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz');
	$pass = join("", @chars[ map{ rand @chars } (0 .. 6) ]);
$url = "http://troll:666/user=$user\&pass=$pass";

print "$url\n";
	my $content = get $url;

	die "Couldn't get $url" unless defined $content;
print "$content\n";
	sleep((rand()/100));
}