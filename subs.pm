package Subs;

sub cmp_array {
	my ($data, $target, $tmp, $cnt, @diff);
	$data = shift;
	$target = shift;

	if (scalar(@{$data}) > scalar(@{$target})) {
		$cnt = scalar(@{$data});
	}
	else {
		$cnt = scalar(@{$target});
	}
	for (0..$cnt) {
		if ((ref($$data[$_]) eq 'HASH') && (ref($$data[$_]) eq 'HASH')) {
			$tmp = &cmp_hash($$data[$_], $$target[$_]);
			if (ref($tmp) eq 'HASH') {
				push @diff, $tmp;
			}	
		}
		elsif ((ref($$target[$_]) eq 'ARRAY') && (ref($$target[$_]) eq 'ARRAY')) {
			$tmp = &cmp_array($$data[$_], $$target[$_]);
			if (ref($tmp) eq 'ARRAY') {
				push @diff, $tmp;
			}
		}
		else {
			if ($$data[$_] && $$target[$_]) {
				if (($$data[$_] =~ /\D/) && ($$target[$_] =~ /\D/)) {
					unless ($$data[$_] eq $$target[$_]) {
						push @diff, $$target[$_];
					}
				}
				else {
					unless ($$data[$_] == $$target[$_]) {
						push @diff, $$target[$_];
					}
				}
			}
		}
	}

	if (scalar(@diff)) {
		return \@diff;
	}
	else {
		return;
	}
}

sub cmp_hash {
	my ($data, $target, $key, $tmp, %tmp);
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
				$tmp = &cmp_array($$data{$key}, $$target{$key});
				if (ref($tmp) eq 'ARRAY') {
					$tmp{$key} = $tmp;
				}
			}
			else {
				if (($$data{$key} =~ /\D/) && ($$target{$key} =~ /\D/)) {
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
		&main(
			'title'		=> $mesg{'epp_connection_error'},
			'path'		=> '/ '.$mesg{'epp_connection_error'}.' : Code '.$Net::EPP::Simple::Code,
			'messages'	=> $Net::EPP::Simple::Message."<br>".$Net::EPP::Simple::Error,
			'content'	=> "<a href='$conf{'public_cgi'}' color='blue'>$mesg{'goto_start'}</a>",
		);
	}

	return $epp;
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

sub create_command_list {
	my ($comm, $out, $tmp, @tmp);

	$comm = &load_tempfile('file' => $tmpl{'commands'});
	foreach (sort {$b cmp $a} keys %commands) {
		unshift @tmp, "<input class='sbmt' type='submit' value='$_' name='$commands{$_}'>";
	}
	$out = &small_parsing(
		$comm,
		'public_cgi'	=> $conf{'public_cgi'},
		'commands'=> join('</td><td>', @tmp)
	);
	$comm = '';

	return $out;
}

sub create_command {
	my ($text, $tag, $key, $comm, $tmp, %hach);
	$text = shift;
	%hach = @_;

	if ($hach{'tag'}) {
		$tag = $hach{'tag'};
		delete($hach{'tag'});
	}
	else { $tag = 'li'; }
	unless (exists $hach{'post'}) {
		if (scalar(keys %hach)) {
			map {
				if ($hach{$_}) {
					unless (($_ eq 'class')||($_ eq 'target')||($_ eq 'title')||($_ eq 'alt')||($_ eq 'style')) { 
						if ($tmp) { $tmp .= "&$_=$hach{$_}"; }
						else { $tmp = "$_=$hach{$_}"; }
					}
				}
			} (keys %hach);
		}
	}

	if (exists $hach{'url'}) {
		$comm = "<$tag onClick=\"javascript:document.location.href='$hach{'url'}';\"";
	}
	elsif (exists $hach{'post'} && exists $hach{'form'}) {
		$comm = "<$tag onClick=\"javascript:PostData(this, '$hach{'form'}', '$hach{'post'}');\"";
	}
	else {
		$comm = "<$tag onClick=\"javascript:document.location.href='$conf{'public_cgi'}";
		if ($tmp) { $comm .= "?$tmp"; }
		 $comm .= "';\"";
	}

	if (defined $hach{'title'})	{ if ($hach{'title'})	{ $comm .= " title='$hach{'title'}'"; }}
	if (defined $hach{'alt'})	{ if ($hach{'alt'})	{ $comm .= " alt='$hach{'alt'}'"; }}
	if (defined $hach{'style'})	{ if ($hach{'style'})	{ $comm .= " style='$hach{'style'}'"; }}
	if (defined $hach{'class'})	{ if ($hach{'class'})	{ $comm .= " class='$hach{'class'}'"; }}
	if (defined $hach{'target'})	{ if ($hach{'target'})	{ $comm .= " target='$hach{'target'}'"; }}
	$comm .= ">$text</$tag>";

	return $comm;
}

sub read_param {
	my ($domain, $key, $cnt);

	foreach (keys %in) {
		if (param($_)) {
			if ($_ eq 'store') {
				$in{$_} = 'on';
			}
			else {
				$in{$_} = param($_);
			}
		}
		else {
			if ($_ eq 'store') {
				$in{$_} = 'off';
			}
			else {
				$in{$_} = '';
			}
		}
#		print "<li>$_ = $in{$_}</li>";
	}

	# read fields for domain commands
	foreach (keys %commands) {
		if ($in{$commands{$_}}) {
			$commands{$_} =~ /domain_(.*)/;
			$domain = $1;
			last;
		}
	}
	if ($domain) {
		# Rean fields for object
		if (@sceleton = split(' ', param('sceleton'))){
			foreach (@sceleton) {
				$in{$_} = param($_);
			}
		}
=comment
		$domain_sceleton = $command_epp{$domain};
		foreach $key (keys %{$domain_sceleton}) {
print "$key= ";
			if (ref($domain_sceleton->{$key}) eq 'HASH') {
				foreach (keys %{$domain_sceleton->{$key}}) {
					if (exists $command_epp{"domain_$domain"}->{$_}) {
						unless ($domain_sceleton->{$key}->{$_} = param($key."_$_")) {
							$domain_sceleton->{$key}->{$_} = '';
						}
					}
				}
			}
			elsif (ref($domain_sceleton->{$key}) eq 'ARRAY') {
				$cnt = 0;
				foreach (0..(param($key."_count")-1)) {
					if (exists $command_epp{"domain_$domain"}->{$key}) {
						unless ($domain_sceleton->{$key}[$cnt] = param($key."_$_")) {
							$domain_sceleton->{$key}[$cnt] = '';
						}
					}
					$cnt++;
				}
			}
			else {
				if (exists $command_epp{"domain_$domain"}->{$key}) {
					unless ($domain_sceleton->{$key} = param($key)) {
						$domain_sceleton->{$key} = '';
					}
				}
			}
		}
 print Dumper($domain_sceleton);
# print "<hr>";
=cut
	}
}

sub small_parsing {
	my ($tmpl, $setup, %hach);
	$tmpl = shift;
	%hach = @_;

	$tmpl =~ s/\<\%(\w+)?\%\>/$hach{$1}?$hach{$1}:''/gex;

	return $tmpl;
}

sub load_tempfile {
	my ($templ, %hach);
	%hach = @_;

	open ('TMPL', "<$hach{'file'}") || &prnerr("$mesg{'not_read_file'} $hach{'file'}:$!");
		while(<TMPL>){ $templ .= $_; }
	close(TMPL) || &prnerr("$mesg{'not_read_file'} $hach{'file'}: $!");

	return $templ;
}

sub put_mail_auth {
	my ($message, $error, $transport, %hach);
	%hach = @_;

	use Email::Sender::Simple qw(sendmail);
	use Email::Sender::Transport::SMTP::TLS;
	use Try::Tiny;

	$transport = Email::Sender::Transport::SMTP::TLS->new(
		host		=> $hach{'mail_server'},
		port		=> $hach{'port'},
		username	=> $hach{'login'},
		password	=> $hach{'pass'},
		helo		=> 'robot.spam.net.ua',
	);

	use Email::Simple::Creator; # or other Email::
	$message = Email::Simple->create(
		header => [
			From		=> $hach{'from'},
			To		=> "$hach{'to'};$hach{'cc'}",
			Subject	=> $hach{'subj'}
		],
		body => $hach{'text'}
	);

	try {
		sendmail($message, { transport => $transport });
	}
	catch {
		$error = "Error sending email: $_";
	};

	return $error;
}

sub create_rnd {
	my ($amount, $out, @chars);
	$amount = shift;

	$amount--;
	@chars = split('', 'Aa0Bb1Cc2Dd3Ee4Ff5Gg6Hh7Ii8Jj9KkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz');
	$out = join("", @chars[ map{ rand @chars } (0 .. $amount) ]);

	return $out;
}

sub prnerr {
	print @_; exit;
}

1;