package Subs;

use Encode qw(encode);
use Time::Local;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(cmp_array cmp_hash obj2utf hash2utf array2utf date2sec sec2date  small_parsing create_rnd prnerr);
@EXPORT_OK = qw(cmp_array cmp_hash obj2utf hash2utf array2utf date2sec sec2date  small_parsing create_rnd prnerr);

sub cmp_obj {
	my ($data, $target, $tmp, $skip, @tmp, %tmp);
	$data = shift; # source
	$target = shift; # target
	$skip = shift; # target

	# Set fields skiped for check
	map { $tmp{$_} = 1 } ( @{$skip} ) if (ref($skip) eq 'ARRAY');

	$tmp = &cmp_hash($data, $target);

	foreach (keys %{$tmp}) {
		# skip non checked fields
		if (exists $tmp{$_}) {
			delete ($$tmp{$_});
		}
	}
	%tmp = ();
	@tmp = ();

	return $tmp;
}


sub cmp_array {
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
				($diff, $tmp) = &cmp_array($$data{$key}, $$target{$key});
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
		$date = ($tmp[5]+1900)."-$tmp[4]-$tmp[3]T$tmp[2]:$tmp[1]:$tmp[0].0000Z";
	}
	# 2001-12-01 (yy-mm-dd where '-' is separeator)
	elsif ($sep eq 'date') {
		$date = ($tmp[5]+1900)."-".$tmp[4]."-".$tmp[3];
	}
	# 01-02-2001 (dd-mm-yy where '-' is separeator)
	else {
		$date = $tmp[3].$sep.$tmp[4].$sep.($tmp[5]+1900);
	}
	@tmp = ();

	return $date;
}

sub small_parsing {
	my ($tmpl, $setup, %hach);
	$tmpl = shift;
	%hach = @_;

	$tmpl =~ s/\<\%(\w+)?\%\>/$hach{$1}?$hach{$1}:''/gex;

	return $tmpl;
}

sub create_rnd {
	my ($amount, $out, @chars);
	$amount = shift;

	$amount--;
	srand();
	@chars = split('', 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz');
	$out = join("", @chars[ map{ rand @chars } (0 .. ($amount-6)) ]);
	@chars = split('', '!#$%*_');
	$out .= join("", @chars[ map{ rand @chars } (0 .. 1) ]);
	@chars = split('', [0 .. 9]);
	$out .= join("", @chars[ map{ rand @chars } (0 .. 1) ]);
	@chars = split('', map{ rand @chars } (0 .. $#chars));
	$out .= join("", @chars[ map{ rand @chars } (0 .. $#chars) ]);

	return $out;
}

sub prnerr {
	print @_; exit;
}

1;