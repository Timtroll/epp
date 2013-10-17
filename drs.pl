#!/usr/bin/perl -w

use strict;
use warnings;
use CGI qw/param/;
use MIME::Base64;
use IO::Socket;
# use Encode qw(encode decode);
#use Net::Whois::Raw qw( whois );
use MongoDB;
use MongoDB::OID;
use Time::Local;
use Net::EPP::Simple;
use LWP::Simple;
use XML::Simple;
#use JSON::XS;

BEGIN {
	IO::Socket::SSL::set_ctx_defaults(
		'SSL_verify_mode' => 0 #'SSL_VERIFY_NONE'
        );
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = '0';
};

our (%conf, %collection, %months, %week, %in, %tmpl, %mesg, %domain_mail, %command_epp, %commands, %menu_line);
our (@week, @sceleton);
our ($domain_sceleton, $domain_info);

use Subs;
require "drs.pm";

 # for developers
use Data::Dumper;
use Tie::IxHash;

print "Content-type: text/html; charset = utf-8\nPragma: no-cache\n\n";

# set limit to post request
$CGI::POST_MAX = 16384;

&read_param();
if ($in{'query_domain'})	{ &query_domain(&connect($conf{'database'}, $collection{'domains'})); }
elsif ($in{'query_contact'})	{ &query_contact(&connect($conf{'database'}, $collection{'cantacts'})); }
elsif ($in{'send_request'})	{ &send_request(&connect($conf{'database'}, $collection{'domains'})); }
elsif ($in{'list_domains'})	{ &list_domains(&connect($conf{'database'}, $collection{'domains'})); }
elsif ($in{'list_waiting'})	{ $in{'type_list'} = 'waiting'; &list_domains(&connect($conf{'database'}, $collection{'domains'})); }
elsif ($in{'list_ending'})	{ $in{'type_list'} = 'ending'; &list_domains(&connect($conf{'database'}, $collection{'domains'})); }
elsif ($in{'list_contacts'})	{ &list_contacts(&connect($conf{'database'}, $collection{'contacts'})); }
elsif ($in{'list_messages'})	{ &list_messages(&connect($conf{'database'}, $collection{'messages'})); }
elsif ($in{'list_transfer'})	{ &list_transfer(&connect($conf{'database'}, $collection{'messages'})); }
elsif ($in{'domain_info'})	{ &domain_info(&connect($conf{'database'}, $collection{'domains'})); }
elsif ($in{'calendar'})		{ &calendar(&connect($conf{'database'}, $collection{'domains'})); }
elsif ($in{'price'})		{ &get_price(&connect($conf{'database'}, $collection{'zones'})); }
elsif ($in{'get_price'})	{ &get_price(&connect($conf{'database'}, $collection{'zones'})); }
elsif ($in{'message_read'})	{ &message_read(&connect($conf{'database'}, $collection{'messages'})); }
elsif ($in{'domain_create'})	{ &domain_create(&connect($conf{'database'}, $collection{'domains'})); }
elsif ($in{'domain_save'})	{ &domain_save(&connect($conf{'database'}, $collection{'domains'})); }
elsif ($in{'domain_update'})	{ &domain_update(&connect($conf{'database'}, $collection{'domains'})); }
elsif ($in{'domain_renew'})	{ &domain_renew(&connect($conf{'database'}, $collection{'domains'})); }
else				{ &main('title' => 'Стартовая'); }

sub domain_update {
	my ($html, $info, $mess, $collections, $epp, $update, @tmp, @temp,  %tmp, %out);
	$collections = shift;

	# Prepare params data for sending
	map { if ($in{$_}) { $tmp{$_} = $in{$_}; } } @sceleton;

	# Prerare request obect
	$domain_sceleton = {
			'name'	=> $in{'name'},
			'add'		=> {
				'contacts'	=> {
					'tech'	=> $in{'contacts_tech'},
					'admin'	=> $in{'contacts_admin'}
				},
			},
			'chg'		=> {
				'authInfo'	=> &create_rnd(11)
			}
	};
	unless (($in{'name'} =~ /^(\w|\-)+\.ua$/)||($in{'name'} =~ /^(\w|\-)+\.in\.ua$/)||($in{'name'} =~ /^(\w|\-)+\.crimea\.ua$/)||($in{'name'} =~ /^(\w|\-)+\.od\.ua$/)) {
		$domain_sceleton->{'chg'}->{'registrant'} = $in{'registrant'};
	}

	# skip setting billing contact for *.kiev.ua
	unless (($in{'name'} =~ /^(\w|\-)+\.kiev\.ua$/)||($in{'name'} =~ /^(\w|\-)+\.od\.ua$/)||($in{'name'} =~ /^(\w|\-)+\.com\.ua$/)) {
print "sdf\n\n";
		$domain_sceleton->{'add'}->{'contacts'}->{'billing'} = $in{'contacts_billing'};
	}

	# 'add' segment 'ns'
	@tmp = ();
	foreach (keys %tmp) {
		if (/^ns/) { push @tmp, $tmp{$_}; }
	}
	if (scalar(@tmp)) {
		if (scalar(@tmp)) { $domain_sceleton->{'add'}->{'ns'} = \@tmp; }
	}
#print Dumper(\@tmp);

	# check domain & get donain info
	($info, $mess) = &chck_domain();

	# Find difference of input and exists 'ns'
	my ($diff, $tt) = &cmp_array($domain_sceleton->{'add'}->{'ns'}, $info->{'ns'});
	if ($diff) {
		$domain_sceleton->{'rem'}->{'ns'} = $info->{'ns'};
	}
	else {
		delete $domain_sceleton->{'add'}->{'ns'};
	}
# print "$diff = ";
# print Dumper($tt);
# exit;

	# Prepare 'rem' contacts
	if (($in{'contacts_tech'} ne $info->{'contacts'}->{'tech'})&&($in{'contacts_tech'})) {
		$domain_sceleton->{'rem'}->{'contacts'}->{'tech'} = $info->{'contacts'}->{'tech'};
	}
	if ($info->{'contacts'}->{'billing'}) {
		if (($in{'contacts_billing'} ne $info->{'contacts'}->{'billing'})&&($in{'contacts_billing'})) {
			$domain_sceleton->{'rem'}->{'contacts'}->{'billing'} = $info->{'contacts'}->{'billing'};
			$domain_sceleton->{'add'}->{'contacts'}->{'billing'} = $in{'contacts_billing'};
		}
	}
	if (($in{'contacts_admin'} ne $info->{'contacts'}->{'admin'})&&($in{'contacts_admin'})) {
		$domain_sceleton->{'rem'}->{'contacts'}->{'admin'} = $info->{'contacts'}->{'admin'};
	}

	# Prepare obect to update database
	$update = {
		%{$domain_sceleton->{'chg'}},
		%{$domain_sceleton->{'add'}},
		'type' => 'updating'
	};
	
#print Dumper($info);
print Dumper($domain_sceleton);
#exit;
	# Send create domain request
	$epp = &connect_epp();

	# Update domain by EPP
	$epp->update_domain($domain_sceleton);
# print Dumper($info->{'response'});

	# check response errors
	&check_response('', 2001, 2003, 2004, 2005, 2201, 2302, 2303, 2307,  2309);

	# Store new domain
	if (($Net::EPP::Simple::Code == 1000)||($Net::EPP::Simple::Code == 1000)) {
		# Find and Update domain status to 'updating' in the base
		@temp = $collections->find( { 'name' => $in{'name'} } )->all;
print $temp[0]->{'name'}, "\n";
print Dumper($update);
#exit;
		if (scalar(@temp) == 1) {
			$collections->update( { '_id' => $temp[0]->{'_id'}}, { '$set' => { %{$update} } } );
		}
		else {
			$out{'messages'} .= "В базе  несколько записей о домене $in{'name'}";
		}
	}
# print $Net::EPP::Simple::Code;
# print $Net::EPP::Simple::Message;

	# Send create domain request
	$html = Dumper($domain_sceleton);

	# Load mail frame template
	$html = &load_tempfile('file' => $tmpl{'frame'});

	$out{'title'} = "<div class='title'>UPDATE домена $in{'name'}</div>";
	$out{'messages'} .= $Net::EPP::Simple::Error.' '.$Net::EPP::Simple::Code.' '.$Net::EPP::Simple::Message;
	print &small_parsing(
		$html,
		'public_cgi'	=> $conf{'public_cgi'},
		'public_css'	=> $conf{'public_css'},
		'public_url'	=> $conf{'public_url'},
		%out
	);

	$html = '';
	exit;
}

sub domain_save {
	my ($collections, $epp, $info, $tmp, $html);
	$collections = shift;

	# Send create domain request
	$epp = &connect_epp();

	# get information about new domain
	$info = $epp->domain_info($in{'name'});

	# check response errors
	&check_response($info, 2001);

	if ($Net::EPP::Simple::Code == 1000) {
		# Convert response to UTF8
		$info = &obj2utf($info);

		# Add required fields
		$info->{'expires'} = &date2sec($info->{'exDate'});
		$info->{'date'} = &sec2date($info->{'expires'}, 'md');
		$info->{'upDate'} = '';

		# Add new domain to database
		$collections->insert( $info );
		$html = &info_table($info);
		$in{'messages'} = 'Домен успешно добавлен в базу';
	}
	$epp = '';

	&main(
		'content'	=> $html
	);
}

sub domain_renew {
	my ($collections, $epp, $renew, $info, $html, @tmp, %out);
	$collections = shift;

	# Find current domain in database
	@tmp = $collections->find( { 'name' => $in{'name'} } )->all;

	# Create error if domain more than one
	if ((scalar(@tmp) > 1) || (scalar(@tmp) == 0)) {
		$in{'messages'} = "В базе находится ".scalar(@tmp)." доменов ".$in{'name'}.", требуется вмешательство.";
		&main();
	}

	# Create renew object
	$html = $tmp[0]->{'exDate'};
	unless ($in{'name'} =~ /.ua$/) {
#		$html=~s/2013/2014/;
	}
	$renew = {
		'name'		=> $in{'name'},
		'cur_exp_date'	=> $html,
		'period'		=> 1
	};

	# Send create domain request
	$epp = &connect_epp();
#print Dumper($renew);

	# Create new domain
	$info = $epp->renew_domain($renew);

	# check response errors
	&check_response('', 2105, 2201, 2303, 2304, 2309);

	# Store new domain
	if ($Net::EPP::Simple::Code == 1000) {
		$html = {
			'type' 		=> 'updating',
			'expires'	=> (&date2sec($html)+60*60*24*365),
			'date'		=> &sec2date((&date2sec($html)+60*60*24*365), 'md'),
			'exDate'	=> &sec2date((&date2sec($html)+60*60*24*365), 'iso')
		};
		$collections->update( { '_id' => $tmp[0]->{'_id'}}, { '$set' => { %{$html} } } );

		$out{'info'} = "Домен поставлен в очередь на продление: ".$Net::EPP::Simple::Message;
	}
	else {
		$out{'info'} = "Ошибка продления домена: ".$Net::EPP::Simple::Message;
	}
	$epp = $info = '';
	@tmp = ();

	# Load mail frame template
	$html = &load_tempfile('file' => $tmpl{'frame'});

	$out{'title'} = "<div class='title'>RENEW домена $in{'name'}</div>";
	$out{'messages'} = $Net::EPP::Simple::Error;
	print &small_parsing(
		$html,
		'public_cgi'	=> $conf{'public_cgi'},
		'public_css'	=> $conf{'public_css'},
		'public_url'	=> $conf{'public_url'},
		%out
	);

	$html = '';
	exit;
}

sub domain_create {
	my ($collections, $epp, $info, $tmp, $html, @ns, @status);
	$collections = shift;

	# Prerare request obect
	$domain_sceleton = {
			'name'	=> $in{'name'},
			'period'	=> $in{'period'},
			'registrant'	=> $in{'registrant'},
			'authInfo'	=> &create_rnd(10),
			'contacts'	=> {
				'tech'		=> $in{'contacts_tech'},
				'billing'	=> $in{'contacts_billing'},
				'admin'	=> $in{'contacts_admin'}
			}
	};
	foreach (keys %in) {
		if (/^ns/) { push @ns, $in{$_}; }
		elsif (/^status/) { push @status, $in{$_}; }
	}
	$domain_sceleton->{'ns'} = \@ns;
	$domain_sceleton->{'status'} = \@status;
	if ($in{'name'} =~ /^(\w|\-)+\.com\.ua$/) {
		delete ($domain_sceleton->{'contacts'}->{'billing'});
	}
	if ($in{'name'} =~ /^(\w|\-)+\.ua$/) {
		$domain_sceleton->{'license'} = $in{'license'};
	}

	# Send create domain request
	$epp = &connect_epp();

	# Create new domain
	$info = $epp->create_domain($domain_sceleton);
	
	# check response errors
	&check_response('', 2001, 2003, 2004, 2005, 2201, 2302, 2303, 2307,  2309);

	# Store new domain to request queue
	if ($Net::EPP::Simple::Code == 1000) {
		$domain_sceleton->{'date'} = time();
		$domain_sceleton->{'expires'} = time();
		$domain_sceleton->{'type'} = 'creating';
		$collections->insert( $domain_sceleton );

		$in{'messages'} = "Запрос на добавление домена $in{'name'} добавлен в очередь";
	}
	else {
		$in{'messages'} = $Net::EPP::Simple::Code.$Net::EPP::Simple::Message;
	}
	$epp = '';

	&main(
		'content'	=> $html
	);
}

sub calendar {
	my ($collections, $html, $months, $day, $days, $list_month , $raw, $datetime, $class, $flag, $list, $curdate, @tmp, @date);
	$collections = shift;

	# Get 01.01.current_year 00:00:00 in seconds
	$datetime = time;
	@tmp = localtime($datetime);
	$curdate = $tmp[3].$tmp[4];
	unless ($in{'month'}) { $in{'month'} = $tmp[4]; }
	else { $in{'month'}--; }
	$datetime = timelocal(0, 0, 0, 1, $in{'month'}, $tmp[5]);

	$days = "<table cellspacing='1' cellspacing='1'  border='0' width='100%'  height='100%' style='height:100%'><tr>";
	foreach (@week) {
		$days .= "<td class='day'>$week{$_}</td>";
	}
	$days .= "</tr>";
	$flag = 0;
	foreach $raw (1..5) {
		$days .= "<tr>";
		foreach $day (1..7) {
			if ($day > 5) { $class = 'dateh'; }
			else { $class = 'date'; }
			@tmp = localtime($datetime);
			unless ($tmp[6]) { $tmp[6] = 7; };

			# highlight current date
			if ($curdate == $tmp[3].$tmp[4]) { $class = 'datec'; }

			$list = '';
			$list = &find_domains($datetime, $collections);
			if ($raw == 1) {
				if ($tmp[6] == $day) {
					$days .= "<td class='$class'><i><b>".&sec2date($datetime, '.')."</b></i>$list</td>";
					$flag = 1;
				}
				else { $days .= "<td class='dat'></td>"; }
			}
			else {
				if ($in{'month'} == $tmp[4]) {
					$days .= "<td class='$class'><i><b>".&sec2date($datetime, '.')."</b></i>$list</td>";
					$flag = 1;
				}
				else { $days .= "<td class='dat'></td>"; }
			}
			if ($flag) {
				$flag = 0;
				$datetime = $datetime + 86400;
			}
		}
		$days .= "</tr>";
	}
	$days .= "</table";


	foreach (sort {$a <=> $b} keys %months) {
		if ($in{'month'}+1 == $_) { $class='month-cur'; }
		else { $class=''; }
		$list_month .= &create_command(
			$months{$_},
			'calendar'	=> 1,
			'class'	=> $class,
			'login'	=> $in{'login'},
			'session'	=> $in{'session'},
			'month'	=> $_
		);
	}

	# Read templates
	$html = &load_tempfile('file' => $tmpl{'calendar'});

	$html = &small_parsing(
		$html,
		'public_cgi'	=> $conf{'public_cgi'},
		'days'	=> $days,
		'months'	=> $list_month
	);

	&main(
		'content'	=> $html
	);
}

sub get_price {
	my ($flag, $key, $search, $content, $connect, @tmp, @table, %data, %changed);
	$connect = shift;
	$flag = shift;

	# Read exists price in database
	%data = map { $_-> {'zone'}, $_ } $connect->find( {}, { 'zone' => 1 } )->all;

	if ($flag) {
		# Get new price
		$content = get($conf{'get_price'}) or $in{'messages'} = 'Не удалось получить свежий прайс';

		if ($in{'messages'}) {
			$flag = 0;
		}
	}

	if ($flag) {
		$content =~ /.*\<div\sclass\=\"current\-orders\"\>(.*?)<\/div>.*/;

		@table = split ('</tr><tr>', $1);
		if (scalar(@table)) {
			foreach my $string (@table) {
				@tmp = ();
				@tmp = split('</td><td>', $string);
				$key = shift @tmp;
				$key =~ s/<.*>//;
				$tmp[$#tmp] =~ s/<.*>//;

				# Check & compare price value, if new zone not exists insert them
				if (exists $data{$key}) {
					if ($tmp[1] ne $data{$key}->{'price'}[1]) {
						$connect->update( { '_id' => $data{$key}->{'_id'} }, { '$set' => { 'price' => [ @tmp ] } } );
						$changed{$key} = int(($data{$key}->{'price'}[1] - $tmp[1])*100 + 5)/100;
						$data{$key}->{'price'} = \@tmp;
					}
				}
				else {
					$connect->insert( { 'zone' => $key, 'price' =>[ @tmp ] } );
				}
			}
		}
		else {
			$in{'messages'} .= 'Неправильный формат прайса - http://drs.ua/rus/price.html';
		}
	}

	# create result table (with new or show old price-list)
	$content = "<table width='100%'><tr>";
	map { if ($_) { $content .= "<td><b>$_<b></td>"; } else { $content .= "<td></td>"; }} ('Доменная зона', '', '0 %', '7 %', '10 %', '12 %', '15 %', '17 %');
	$content .= '</tr>';
	foreach $key (sort {$a cmp $b} keys %data) {
		$content .= '<tr>';
		$content .= "<td><i>$key</i></td><td class='overdue'>";
		if (exists $changed{$key}) {
			$content .= " ( $changed{$key} ) ";
		}
		$content .= "</td>";
		map { $content .= "<td>$_</td>"; } @{$data{$key}->{'price'}};
		$content .= '</tr>';
	}
	%data = ();
	$content .= '</table>';

	&main(
		'content'	=> $content
	);
}

sub find_domains {
	my ($html, $date,  $curtime, $collections, $search, @tmp);
	$date = shift;
	$collections = shift;

	# Load template for one day
	$html = &load_tempfile('file' => $tmpl{'one_day'});
	
	# create time range
	@tmp = localtime($date);
	if ($tmp[3] < 10) { $tmp[3] = "0".$tmp[3]; }
	$tmp[4]++;
	$search = $tmp[4].$tmp[3];
	if ($tmp[4] < 10) { $search = "0".$search; }
	@tmp = ();
	$tmp[0] = $collections->find( { 'date' => $search } )->count;

	# variable for check domain expires (current time + )
	$curtime = time + 86400;
	if ($tmp[0]) {
		$tmp[1] = $collections->find( { 'date' => $search ,  'status.0' => 'ok', 'expires' => { '$lt' => $curtime } } ) ->count;
		$tmp[2] = $collections->find( { 'date' => $search ,  'status.0' => 'ok', 'expires' => { '$gt' => $curtime } } ) ->count;
		$tmp[3] = $collections->find( { 'date' => $search ,  'status.0' => qr/hold/i } ) ->count;

		# Fotmat output
		map { unless ($_) { $_ = " $_"; } } (@tmp);

		$html = &small_parsing(
			$html,
			'txt_expires'=> &create_command("Ending",
						'list_domains'	=> 1,
						'type_list'	=> 'expires',
						'class'	=> 'expires',
						'tag'		=> 'span',
						'login'	=> $in{'login'},
						'session'	=> $in{'session'},
						'date'		=> $search,
						'time'	=> $date
					),
			'txt_waiting'=> &create_command("Waiting",
						'list_domains'	=> 1,
						'type_list'	=> 'waiting',
						'class'	=> 'waiting',
						'tag'		=> 'span',
						'login'	=> $in{'login'},
						'session'	=> $in{'session'},
						'date'		=> $search,
						'time'	=> $date
					),
			'txt_expired'=> &create_command("Expired",
						'list_domains'	=> 1,
						'type_list'	=> 'expired',
						'class'	=> 'expired',
						'tag'		=> 'span',
						'login'	=> $in{'login'},
						'session'	=> $in{'session'},
						'date'		=> $search,
						'time'	=> $date
					),
			'txt_all'	=> &create_command("Amount",
						'list_domains'	=> 1,
						'type_list'	=> 'all',
						'class'	=> 'all',
						'tag'		=> 'span',
						'login'	=> $in{'login'},
						'session'	=> $in{'session'},
						'date'		=> $search,
						'time'	=> $date
					),

			'all'		=> $tmp[0],
			'waiting'	=> $tmp[1],
			'expired'	=> $tmp[2],
			'expires'	=> $tmp[3]
		);
	}
	else {
		$html = ' ';
	}

	return $html;
}

sub info_table {
	my ($info, $flag, $tmp, $out);
	$info = shift;
	$flag = shift;

	if ($info) {
#		unless (exists $info->{'_id'}) {
#			$info = &obj2utf($info);
#		}

		$out = '<ul class="dump">';
		foreach (sort {$a cmp $b} keys %{$info}) {
			if (/^_id$/) { next; }
			elsif (/^response$/) { next; }

			if (ref($info->{$_}) eq 'HASH') {
				$out .= &print_hash($info->{$_}, $_, $flag);
			}
			elsif (ref($info->{$_}) eq 'ARRAY') {
				$out .= &print_array($info->{$_}, $_, $flag);
			}
			else {
				if ($flag) {
					$out .= "<li>";
					$out .= "<input type='text' class='dump-edit' name='$_' value='".$info->{$_}."'>";
					$out .= "<i>$_ :</i></li>";
					push @sceleton, $_;
				}
				else {
					$out .= "<li><i>$_ :</i>";
					$out .= "<span class='dump-text'>".$info->{$_}."</span>";
					$out .= "</li>";
				}
			}
		}
		$out .= '</ul>';
	}
	if ($flag) {
		$out .= "<input type='hidden' name='sceleton' id='sceleton' value='".join(' ', @sceleton)."'>";
	}

	return $out;
}

sub print_hash {
	my ($info, $name, $flag, $tmp, $out);
	$info = shift;
	$name = shift;
	$flag = shift;

	$out = "<li><i class='dump_span'>$name :</i></li><ul>";
	foreach (sort {$a cmp $b} keys %{$info}) {
		if (ref($info->{$_}) eq 'HASH') {
			$out .= &print_hash($info->{$_}, $_, $flag);
		}
		elsif (ref($info->{$_}) eq 'ARRAY') {
			$out .= &print_array($info->{$_}, $_, $flag);
		}
		else {
			if ($flag) {
				$out .= "<li>";
				if (/^cc$/) {
					$out .= "<table width='70%' border='0' cellpadding='0' cellspacing='0' align='right'><tr><td width='8%'><input class='dump-edit' name='".$name."_$_"."' id='".$name."_$_"."' type='text' size='4' maxlength='2' onkeyup='javascript:chkChar(this);Country();' value='".$info->{$_}."'><div class='country-none' id='countr_list'></div></td><td width='20'>&nbsp;</td><td class='cntr'><div id='countr_none'>Латинская аббревиатура (например RU)</div><div id='country' class='country'></div></td></tr></table>";
					push @sceleton, $name."_$_";
				}
				else {
					$out .= "<input type='text' class='dump-cc' name='".$name."_$_"."' value='".$info->{$_}."'>";
					push @sceleton, $name."_$_";
				}
				$out .= "<i>$_ :</i></li>";
				
			}
			else {
				$out .= "<li><i>$_ :</i>";
				$out .= "<span class='dump-text'>".$info->{$_}."</span>";
				$out .= "</li>";
			}
		}
	}
	$out .= '</ul>';
}

sub print_array {
	my ($info, $name, $flag, $tmp, $out, $cnt);
	$info = shift;
	$name = shift;
	$flag = shift;

	$out = "<li><i id='dump_span'>$name :</i></li><ul id='$name'>";
	$cnt = 0;
	$tmp = '>&nbsp;';
	
	foreach (sort {$a cmp $b} keys @{$info}) {
		if (ref($_) eq 'HASH') {
			$out .= &print_hash($_, $name, $flag);
		}
		elsif (ref($_) eq 'ARRAY') {
			$out .= &print_array($_, $name, $flag);
		}
		else {
			$out .= "<li>";
			if ($flag) {
				if ($cnt) { $tmp = " onclick=\"javascript:DelInput(this.parentNode, '".$name."');\">x"; }
				$out .= "<u$tmp</u>";
				$out .= "<input type='text' class='dump-edit' name='".$name."_$cnt' value='".$info->[$_]."'>";
				$out .= "<b onclick=\"javascript:AddInput(this.parentNode, '$name');\">+</b>";
				push @sceleton, $name."_$cnt";
			}
			else {
				$out .= "<span class='dump-text'>".$info->[$_]."</span>";
			}
			$out .= "</li>";
		}
		$cnt++;
	}
#		$out .= "<div id='".$name."__new'></div>";
	if ($flag) {
		if ($cnt) {
			$out .= "<input type='hidden' name='".$name."_count' id='".$name."_count' value='$cnt'>";
		}
	}
	$out .= '</ul>';
}

sub message_read {
	my ($html, $out, $count, $collections, @tmp);
	$collections = shift;

	# Find & read message
	@tmp = $collections->find( { 'message_id' => $in{'id'} } )->all;

	if (scalar(@tmp) == 1) {
		if ($tmp[0]->{'status'} eq 'new') {
			$in{'messages'} .= $mesg{'message_read_success'};

			# Change status of this message if ack to dequeue
			$tmp[0]->{'status'} = 'old';
			$collections->update( { '_id' => $tmp[0]->{'_id'} }, { '$set' => { 'status' => 'old' } } );
		}

		# remove flag-file for display mail informer
		$count = 0;
		$count = $collections->find( { 'status' =>'new' } )->count;
		unless ($count) {
			unlink ("$conf{'home'}/poll");
		}

		# Create html for message
		$out = &info_table($tmp[0]);
	}
	elsif (scalar(@tmp) > 1) {
		# we have dublicate
		$in{'messages'} = $mesg{'double_mess'}.$in{'id'};
	}
	else {
		$in{'messages'} = $mesg{'have_not_id_mess'};
		&list_messages($collections);
	}
	
	$html = &load_tempfile('file' => $tmpl{'frame'});

	print &small_parsing(
		$html,
		'public_cgi'	=> $conf{'public_cgi'},
		'public_css'	=> $conf{'public_css'},
		'title'		=> "<div class='title'>Read message: id $in{'id'}</div>",
		'messages'	=> $in{'messages'},
		'info'		=> $out
	);

	exit;
}

sub domain_info {
	my ($html, $info, $mess, $comm, $out, $collections, $cmpr, @tmp);
	$collections = shift;

	# check domain
	($info, $mess) = &chck_domain();

	# delete system field
	delete $info->{'request'};
	delete $info->{'response'};

	@tmp = $collections->find( { 'name' => $in{'name'} } )->all;

	# delete system field
	$cmpr = $tmp[0];
	delete $cmpr->{'_id'};
	delete $cmpr->{'date'};
	delete $cmpr->{'expires'};

	$cmpr = &cmp_request($cmpr, $info);

	$out = &info_table($info, 'edit');

	$comm = &create_command_list('frame');

	if ($in{'frame'}) {
		$html = &load_tempfile('file' => $tmpl{'frame'});
		print &small_parsing(
			$html,
			'public_cgi'	=> $conf{'public_cgi'},
			'public_css'	=> $conf{'public_css'},
			'title'		=> '<div class="title">Information from Epp</div>',
			'commands'=> $comm,
			'info'		=> $out
		);
	}
	else {
		$html = &load_tempfile('file' => $tmpl{'query_domain'});

		&main(
			'content'	=> $out.$comm,
			'path'		=> $mesg{'domain_info'}.$in{'name'},
			'javascript'	=> "<script src='$conf{'public_url'}/css/domain_info.js'></script>"
		);
	}

	exit;
}

sub list_contacts {
	my ($html, $raw, $list, $collections, $class, $path, @tmp, @data, %comm);
	$collections = shift;

	# Read list of contacts
	@data = $collections->find->sort( {'name' => 1} )->all;
	$path = $mesg{'list_domains'};

	# Read templates
	$html = &load_tempfile('file' => $tmpl{'list_domains'});
	$raw = &load_tempfile('file' => $tmpl{'domain_line'});
	$class = '';
#print timelocal(0, 0, 12, 8, 7, 2007);
#print "<br>";

	foreach (0..(scalar(@data) - 1)) {
		%comm = (
			'info'			=> "<li><a href='#modalopen' onClick=\"javascript:open_frame('$conf{'public_cgi'}?domain_info=1&name=".$data[$_]->{'name'}."');\" class='text'>info</a></li>",
			'suspend'		=> &create_command('Suspend',
							'domain_suspend'=> 1,
							'name'		=> $data[$_]->{'name'}
						),
			'renew'		=> &create_command('Renew',
							'domain_renew'	=> 1,
							'name'		=> $data[$_]->{'name'}
						),
			'update'		=> &create_command('Modify',
							'domain_update'	=> 1,
							'name'		=> $data[$_]->{'name'}
						),
			'transfert'		=> &create_command('Transfert',
							'domain_transfert'=> 1,
							'name'		=> $data[$_]->{'name'}
						),
			'delete'		=> &create_command('Delete',
							'domain_delete'	=> 1,
							'name'		=> $data[$_]->{'name'}
						)
		);

		# Convert date from sec to europe format
		if ($data[$_]->{'expires'}) {
			$data[$_]->{'expires'} = &sec2date($data[$_]->{'expires'});
		}
		$list .= &small_parsing(
			$raw,
			'public_cgi'	=> $conf{'public_cgi'},
			'name'	=> &create_command($data[$_]->{'name'}, 'class' => 'dom'),
			'class'	=> $class,
			'expires'	=> $data[$_]->{'expires'},
			%comm
		);
		unless ($class) { $class = 'lineh'; }
		else { $class = ''; }
		$list .= qq~~;
	}

	$html = &small_parsing(
		$html,
		'public_cgi'		=> $conf{'public_cgi'},
		'list_domains'	=> $list
	);

	&main(
		'content'	=> $html,
		'path'		=> $path,
		'javascript'	=> "<script src='$conf{'public_url'}/css/domain_info.js'></script>"
	);
}

sub list_messages {
	my ($collections, $html, $list, $raw, $class, $path, $count, @data, @tmp);
	$collections = shift;

	@data = $collections->find( {} )->sort( { 'message_id' => -1 } )->all;
	$path = $mesg{'list_message_all'};

	# Read templates
	$html = &load_tempfile('file' => $tmpl{'list_domains'});
	$raw = &load_tempfile('file' => $tmpl{'message_line'});
	$class = '';

	$count = 1;
	foreach (0..(scalar(@data) - 1)) {
		@tmp = (
			$data[$_]->{'resData'}->{'domain:panData'}->{'domain:name'}->{'content'} ? $data[$_]->{'resData'}->{'domain:panData'}->{'domain:name'}->{'content'} : $data[$_]->{'resData'}->{'drs:notify'}->{'drs:object'},
			'',
			'mess',
			'mess'
		);
		unless ($tmp[0]) { $tmp[0] = $data[$_]->{'resData'}->{'domain:trnData'}->{'domain:name'}; }
		if ($data[$_]->{'resData'}->{'drs:notify'}->{'drs:message'}) {
			$tmp[1] = $data[$_]->{'resData'}->{'drs:notify'}->{'drs:message'};
		}
		else {
			$tmp[1] = $data[$_]->{'msgQ'}->{'msg'};
		}
		if (length($tmp[1]) > 72) {
			$tmp[1] = substr($tmp[1], 0, 72).'...';
		}
		if ($data[$_]->{'status'} =~ /^new$/) {
			$tmp[2] = 'messb';
			$tmp[3] = 'messbl';
		}

		$list .= &small_parsing(
			$raw,
			'public_cgi'	=> $conf{'public_cgi'},
			'id'		=> $data[$_]->{'msgQ'}->{'id'},
			'text'		=> "<li class='$tmp[3]' id='text_$count'><a href='#modalopen' onClick=\"javascript:open_frame('$conf{'public_cgi'}?message_read=1&id=".$data[$_]->{'msgQ'}->{'id'}."'); MarkRead('$count');\" class='$tmp[3]' id='textl_$count'>$tmp[1]</a></li>",
			'status'	=> $data[$_]->{'status'},
			'text_class'	=> $tmp[2],
			'class'	=> $class,
			'count'	=> $count,
			'date'		=> &sec2date(&date2sec($data[$_]->{'msgQ'}->{'qDate'}), '/'),
			'title'		=> "<li class='$tmp[3]' id='tit_$count'><a href='#modalopen' onClick=\"javascript:open_frame('$conf{'public_cgi'}?message_read=1&id=".$data[$_]->{'msgQ'}->{'id'}."'); MarkRead('$count');\" class='$tmp[3]' id='title_$count'>$tmp[0]</a></li>"
		);
		@tmp = ();
		unless ($class) { $class = 'lineh'; }
		else { $class = ''; }
		$count++;
	}

	$html = &small_parsing(
		$html,
		'public_cgi'		=> $conf{'public_cgi'},
		'list_domains'	=> $list
	);

	&main(
		'content'	=> $html,
		'path'		=> $path
	);
}

sub list_domains {
	my ($html, $raw, $list, $collections, $class, $path, @tmp, @data, %comm);
	$collections = shift;

	# Read list of domains
	if (($in{'type_list'} eq 'all') && ($in{'date'})) {
		@data = $collections->find( { 'date' => $in{'date'} } )->sort( {'name' => 1} )->all;
		$path = $mesg{'list_domains_all'}.&sec2date($in{'time'},'.');
	}
	elsif (($in{'type_list'} eq 'expires') && ($in{'date'})) {
		@data = $collections->find( { 'date' => $in{'date'},  'status.0' => qr/hold/i } )->sort( {'name' => 1} )->all;
		$path = $mesg{'list_domains_end'}.&sec2date($in{'time'},'.');
	}
	elsif (($in{'type_list'} eq 'expired') && ($in{'date'})) {
		@data = $collections->find( { 'date' => $in{'date'},  'status.0' => 'ok', 'expires' => { '$gt' => time } } )->sort( {'name' => 1} )->all;
		$path = $mesg{'list_domains_ok'}.&sec2date($in{'time'},'.');
	}
	elsif (($in{'type_list'} eq 'waiting') && ($in{'date'})) {
		@data = $collections->find( { 'date' => $in{'date'},  'status.0' => 'ok', 'expires' => { '$lt' => time } } )->sort( {'name' => 1} )->all;
		$path = $mesg{'list_domains_wait'}.&sec2date($in{'time'},'.');
	}
	elsif (($in{'type_list'} eq 'waiting')) {
		@data = $collections->find( { 'status.0' => 'ok', 'expires' => { '$gt' => time } } )->sort( {'name' => 1} )->all;
		$path = $mesg{'list_domains'};
	}
	elsif (($in{'type_list'} eq 'ending')) {
		@data = $collections->find( { 'status.0' => 'ok', 'expires' => { '$lt' => time } } )->sort( {'name' => 1} )->all;
		$path = $mesg{'list_domains'};
	}
	else {
		@data = $collections->find->sort( {'name' => 1} )->all;
		$path = $mesg{'list_domains'};
	}

	# Read templates
	$html = &load_tempfile('file' => $tmpl{'list_domains'});
	$raw = &load_tempfile('file' => $tmpl{'domain_line'});
	$class = '';

	foreach (0..(scalar(@data) - 1)) {
		%comm = (
			'info'			=> "<li><a href='#modalopen' onClick=\"javascript:open_frame('$conf{'public_cgi'}?domain_info=1&frame=1&name=".$data[$_]->{'name'}."');\" class='text $data[$_]->{'type'}'>info</a></li>",
			'suspend'		=> &create_command('Suspend',
							'domain_suspend'=> 1,
							'name'		=> $data[$_]->{'name'}
						),
			'renew'		=> &create_command('Renew',
							'domain_renew'	=> 1,
							'name'		=> $data[$_]->{'name'}
						),
			'update'		=> &create_command('Modify',
							'domain_update'	=> 1,
							'name'		=> $data[$_]->{'name'}
						),
			'transfert'		=> &create_command('Transfert',
							'domain_transfert'=> 1,
							'name'		=> $data[$_]->{'name'}
						),
			'delete'		=> &create_command('Delete',
							'domain_delete'	=> 1,
							'name'		=> $data[$_]->{'name'}
						)
		);

		# Convert date from sec to europe format
		if ($data[$_]->{'expires'}) {
			$data[$_]->{'expires'} = &sec2date($data[$_]->{'expires'});
		}
		$list .= &small_parsing(
			$raw,
			'public_cgi'	=> $conf{'public_cgi'},
			'name'	=> &create_command($data[$_]->{'name'}, 'class' => "dom $data[$_]->{'type'}"),
			'class'	=> $class,
			'expires'	=> $data[$_]->{'expires'},
			%comm
		);
		unless ($class) { $class = 'lineh'; }
		else { $class = ''; }
	}

	$html = &small_parsing(
		$html,
		'public_cgi'		=> $conf{'public_cgi'},
		'list_domains'	=> $list
	);

	&main(
		'content'	=> $html,
		'path'		=> $path
	);
}

sub send_request {
	my ($html, $error, $tmp, $collections, %text, %tmp, @tmp);
	$collections =shift;

	$text{'text'} = $in{'request_data'};
	if ($in{'operation'} ne 'add_to_base') {
		$text{'subj'} = uc($in{'operation'})." ".$in{'name'};

=comment
		$error = &put_mail_auth(
			'from'		=>$conf{'login_mail'},
			'to'			=>$conf{'give_mail'},
			'cc'			=>$conf{'give_copy'},
			'subj'			=>$text{'subj'},
			'text'			=>$text{'text'},
			'mail_server'	=>$conf{'smtp'},
			'port'			=>$conf{'smtp_port'},
			'login'		=>$conf{'login_mail'},
			'pass'		=>$conf{'pass_mail'}
		);
=cut
	}
	else {
		$in{'store'} = 1;
	}
# print "=$in{'name'}=<br>";
	# Check for dublicate in database
# print " 'name' => $in{'name'} <br>";
	@tmp = $collections->find( { 'name' => $in{'name'} } )->all;
#print $tmp[0]->{'_id'};
# print Dumper(\@tmp);
	if (scalar(@tmp) && $tmp[0]->{'_id'}) {
#print $in{'name'};
		# 
		if (scalar(@tmp) == 1) {
# print Dumper($tmp[0]);
print "\n<hr>\n";
			# if domain exist in the base
			&cmp_request($tmp[0]);
#			$tmp = $collections->update( { '_id' => $tmp[0]->{'_id'} }, { %tmp } );
		}
		else {
			# print request page for resolve conflict
			$html = &load_tempfile('file' => $tmpl{'request_form'});

			&main(
				'messages'	=> 'You have to resolve conflict. Found more than one raw about domain.',
				'content'	=> $html
			);
		}
#print "<hr>";
	}
	else {
#		@tmp = $collections->insert( { %tmp } );
	}
exit;
#print "<hr>";
#@tmp = $collections->find( { 'name' => $in{'name'} } )->all;
#print $tmp[0]->{'_id'};
#exit;
#print "<hr>";
#		print $tmp;
#print "<hr>";
#		$tmp = $collections->insert( {%tmp} );
#		print Dumper($tmp);
#print "<hr>";
#		$tmp = $collections->find( { 'name' => $in{'name'} } )->all;
#		print Dumper($tmp);
#		$db = $client->get_database( 'tutorial' )->drop();
#		$db->run_command($cmd);

	# store domain if sending success
	if ($in{'store'} eq 'on') {
#		my $client = MongoDB::MongoClient->new(host => $conf{'database'});
#		my @dbs = $client->database_names;
#print "<hr>";
#my %tmp = map { $_ => 1 } @dbs;
#print "<hr>";
	
#		my $db = $client->get_database( 'domains' );
#		my $collections = $db->get_collection( 'domains' );

		# Prepare data for storing
		my @tmp = ();
		$text{'text'} =~ s/\r//go;
#print "$text{'text'}<br>";
		map {
			# clear temporary data
			my $key;
			@tmp = ();

			foreach $key (split(':', $_)) {
				$key =~ s/^\s+//;
				$key =~ s/\s+$//;
				$key =~ s/\s+/ /go;
				push @tmp, $key;
			}
			if (exists $tmp{$tmp[0]}) {
				if (ref($tmp{$tmp[0]}) eq 'ARRAY') {
					push @{$tmp{$tmp[0]}}, $tmp[1];
				}
				elsif ($tmp{$tmp[0]}) {
					$tmp{$tmp[0]} = [$tmp[1], $tmp{$tmp[0]}];
				}
				else {
					$tmp{$tmp[0]} = [$tmp[1]];
				}
			}
			else {
				%tmp = (%tmp, @tmp);
			}
		} split("\n", $text{'text'});

		if ($in{'operation'} eq 'renew') {
			$tmp{'expires'} = time + 31536000;
			@tmp = split('/', &sec2date(time + 31536000));
			$tmp{'date'} = $tmp[1].$tmp[0];
		}
		elsif ($in{'operation'} eq 'add_to_base') {
			$tmp{'expires'} = $in{'expires'};
			@tmp = split('/', &sec2date($in{'expires'}));
			$tmp{'date'} = $tmp[1].$tmp[0];
		}
		else {
			if ($in{'expires'}) {
				$tmp{'expires'} = $in{'expires'};
				@tmp = split('/', &sec2date($in{'expires'}));
				$tmp{'date'} = $tmp[1].$tmp[0];
			}
			else {
				$tmp{'expires'} = time;
				@tmp = split('/', &sec2date(time));
				$tmp{'date'} = $tmp[1].$tmp[0];
			}
		}
	}
#	else {
#	}
#print Dumper(\%tmp);
#exit;


	$text{'text'} =~ s/\n/<br>/go;
	if ($in{'operation'} ne 'add_to_base') {
		$in{'messages'} = "Отправлено письмо:<p><b>subj:</b> $text{'subj'}</p><p>$text{'text'}</p>",
	}
	else {
		$in{'messages'} = "В базу добавлена запись:<p><b>subj:</b> $in{'name'}</p><p>$text{'text'}</p>",
	}
#	&list_domains();
	&main(
#		'messages'	=> "Отправлено письмо:<p><b>subj:</b> $text{'subj'}</p><p>$text{'text'}</p>",
		'content'	=> $html
	);
}

sub query_contact {
	my ($collections, $mess, $data, $out, $html, @tmp);
	$collections = shift;

	# check domain in the base
	if ($in{'contact'}) {
		# Check exists domains
		@tmp = $collections->find( { 'id' => $in{'contact'} } )->all;

		if (scalar(@tmp) > 1) {
			$in{'messages'} = "Есть небольшая проблема - контактов <b>$in{'contact'}</b> в базе несколько штук.";
		}
		elsif (scalar(@tmp) == 1) {
			$in{'messages'} = "Такой контакт <b>$in{'contact'}</b> уже есть в базе.";
			$data = $tmp[0];
		}
		else {
			$data = '';
		}
	}
	else {
		&main(
			'messages' => $mesg{'empty_contact'}
		);
	}

	unless ($in{'messages'}) {
		$data = &chck_contact();
	}
	
	$out = &info_table($data, 'edit');

	$html = &load_tempfile('file' => $tmpl{'contact_form'});

	$html = &small_parsing(
		$html,
		'public_css'		=> $conf{'public_css'},
		'public_cgi'		=> $conf{'public_cgi'},
		'info'			=> $out
	);

	&main(
		'content'	=> $html
	);
}

sub query_domain {
	my ($rows, $flag, $date, $html, $out, $req, $expires, $collections, $data, $key, $keys, $mess, $comm, @tmp);
	$collections = shift;

	# check domain in the base
	if ($in{'name'}) {
		# Check exists domains
		$data = $collections->find( { 'name' => $in{'name'} } )->count;

		if ($data > 1) {
			$in{'messages'} = "Есть небольшая проблема - доменов <b>$in{'name'}</b> в базе несколько штук.";
		}
		elsif ($data == 1) {
			$in{'messages'} = "Такой домен <b>$in{'name'}</b> уже есть в базе.";
			$data = $tmp[0];
		}
		$data = '';
	}
	else {
		&main(
			'messages' => $mesg{'empty_field'}
		);
	}

	# whois check domain
	($data, $mess) = &chck_domain();

	# check response errors
	&check_response($data, 2001);
# print $mess;
	# if ($mess == 2302) {
		# $in{'messages'} .= 'Такой домен зарегистрирован';
	# }
	# elsif ($mess == 2303) {
		# $in{'messages'} .= 'Домен свободен для регистрации';
	# }

	# Create ADD form for EPP request
	unless ($data) {
		# delete Billing field from sceleton if domain is *.com.ua
		if ($in{'name'} =~ /^(\w|\-)+\.com\.ua$/) {
			delete ($command_epp{'create'}->{'contacts'}->{'billing'});
			delete ($command_epp{'create'}->{'license'});
		}
		$command_epp{'create'}->{'name'} = $in{'name'};
		$command_epp{'create'}->{'contacts'}->{'tech'} = 'trol-cunic';
		$command_epp{'create'}->{'contacts'}->{'admin'} = 'trol-cunic';
		$command_epp{'create'}->{'registrant'} = 'trol-cunic';
		$out = &info_table($command_epp{'create'}, 'edit');
	}

	# Create UPDATE form for EPP request
	else {
print Dumper($data);
		$out = &info_table($data, 'edit');
	}
	$comm = &create_command_list();
	$out .= $comm;

	# Create form for E-mail request
	# Create changed date
	$date = join('', reverse(split('/', &sec2date(time))));

	$html = &load_tempfile('file' => $tmpl{'request_form'});

	$expires = time();
	$rows = 14;
	# $out = "Домен <b>$in{'name'}</b> не обнаружен";
		
	$req = qq~domain:         $in{'name'}
descr:          V interesah clienta
admin-c:        TROL-CUNIC
tech-c:         TROL-CUNIC
registrant:     TROL-CUNIC
nserver:        ns1.spam.net.ua
nserver:        ns2.spam.net.ua
mnt-by:         TROL-MNT-CUNIC
source:         CUNIC
changed:        TROL-CUNIC $date
~;
	# }

	# Change nic-handles & source
	# $req =~ s/UAEPP/CUNIC/;
	# $req =~ s/kv\-.*$/TROL\-CUNIC/;
	# $req =~ s/ua\.drs/TROL\-MNT\-CUNIC/;

	# print request form
	$html = &small_parsing(
		$html,
		'public_cgi'		=> $conf{'public_cgi'},
		'info'			=> $out,
		'name'		=> $in{'name'},
		'request_data'	=> $req,
		'rows'		=> $rows,
		'expires'		=> $expires
	);

	&main(
		'content'	=> $html
	);
}

sub main {
	my ($query, $html, $menu, $cnt, $key, $kkey, @tmp, %hach);
	%hach = @_;

	$html = &load_tempfile('file' => $tmpl{'main'});
	$query = &load_tempfile('file' => $tmpl{'query_domain'});
	$query = &small_parsing(
		$query,
		'public_css'	=> $conf{'public_css'},
		'public_url'	=> $conf{'public_url'},
		'public_cgi'	=> $conf{'public_cgi'},
		'name'	=> $in{'name'}
	);

	# Create message
	if ($hach{'messages'} && $in{'messages'}) {
		$hach{'messages'} .= "<br>$in{'messages'}";
	}
	elsif ($in{'messages'}) {
		$hach{'messages'} = $in{'messages'};
	}

	# create menu
	foreach $key (sort {$a <=> $b} keys %menu_line) {
		$menu = '';
		$cnt = 0;
		foreach $kkey (@{$menu_line{$key}}) {
			foreach (keys %{$kkey}) {
				$menu .=  &create_command($$kkey{$_}, 'form' => 'menu_form', 'post' => $_);
			}
			$cnt++;
		}
		push @tmp, $menu;
	}
	$menu = join('<hr>', @tmp);
	@tmp = ();

	$html = &small_parsing(
		$html,
		'public_css'	=> $conf{'public_css'},
		'public_url'	=> $conf{'public_url'},
		'public_cgi'	=> $conf{'public_cgi'},
		'menu'	=> $menu,
		'query'	=> $query,
		%hach
	);

	print $html;
	exit;
}

sub chck_contact {
	my ($epp, $info);

	# Clear request data
	$in{'contact'} = lc($in{'contact'});

	# Open check page if contact name incorrect
	unless ($in{'contact'} =~ /^[0-9a-z\-\.]+$/) {
		&main(
			'title'		=>'Проверка домена',
			'messages'	=> "Проверьте корректность названия контакта."
		);
	}
	else {
		# Connect to Epp server
		$epp = &connect_epp();

		# check contact
		$info = $epp->contact_info($in{'contact'});

		# check response errors
		&check_response($info, 2001, 2005, 2202);

		# check contact
		if ($Net::EPP::Simple::Code == 1000) {
			# Recode to UTF8
			$info = &obj2utf($info);
		}
		elsif ($Net::EPP::Simple::Code == 2303) {
			$in{'messages'} .= "Записи о таком контакте не сущестует";
		}
		else {
			$in{'messages'} .= "Неизвестная ошибка";
		}
	}
	$epp ='';

	return $info;
}

sub chck_domain {
	my ($flag, $tmp, $resp, $string, $info, $epp, $mess, @temp);

	# Clear request data

	# Open check page if domain name incorrect
	unless ($in{'name'} =~ /^[0-9a-z\-\.]+\.[a-z]+$/) {
		&main(
			'title'		=>'Проверка домена',
			'messages'	=> "Проверьте корректность доменного имени."

		);
	}

	if ($in{'name'}) {
		# Connect to Epp server
		$epp = &connect_epp();

		# check domain
		$info = $epp->domain_info($in{'name'});

		&check_response($info, 2001);

		if ($Net::EPP::Simple::Code == 1000) {
			# Convert response to UTF8
			$info = &obj2utf($info);

			$in{'messages'} .= "Домен зарегистрирован. ";
			$in{'messages'} .= "Последнее обновление ".$info->{upDate} if $info->{upDate};
			$in{'messages'} .= ". Домен зарегистрирован до ".$info->{exDate} if $info->{exDate};
		}
		elsif ($Net::EPP::Simple::Code == 2303) {
			$in{'messages'} .= "Домен зарегистрирован. ";
		}
		elsif ($Net::EPP::Simple::Code == 2001 || $Net::EPP::Simple::Code == 2202) {
			$in{'messages'} .= "Ошибка EPP: <li>$Net::EPP::Simple::Code</li><li>$Net::EPP::Simple::Message</li><li>$Net::EPP::Simple::Error</li>";
		}
		$mess = $Net::EPP::Simple::Code;
		$epp = '';
	}
	else {
		$mess = "Введите название домена";
	}

	return $info, $mess;
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

######## Subs ########

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

sub cmp_request {
	my ($data, $key, $cnt, $tmp, $target, @tmp, %tmp);
	$data = shift; # source
	$target = shift; # target

# print Dumper($data);

# print "<hr>";

# print Dumper($target);
# print "<hr>";

	# if ((ref($data) eq 'HASH') && (ref($target) eq 'HASH')) {
		# print Dumper(&cmp_hash($data, $target));
	# }

	# clear domain sceleton
	$domain_sceleton = '';
	$domain_sceleton = {};
	
#comment
	if (ref($data) eq 'HASH') {
		foreach $key (keys %{$data}) {
			if ($key =~ /^_id$/) { next; }
			elsif (ref($data->{$key}) eq 'HASH') {
				%tmp =();
				foreach (keys %{$data->{$key}}) {
					unless ($target) {
						$tmp = param($key."_$_");
					}
					else {
						$tmp = $target->{$key}->{$_};
					}
					unless ($data->{$key}->{$_} eq $tmp) {
						$tmp{$_} = $tmp;
					}
					$tmp = '';
				}
				if (scalar(keys %tmp)) {
					$domain_sceleton->{$key} = { %tmp };
				}
			}
			elsif (ref($data->{$key}) eq 'ARRAY') {
				$cnt = 0;
				@tmp =();
				unless ($target) {
					$cnt = param($key.'_count');
				}
				else {
					$cnt = scalar(@{$data->{$key}});
				}
				foreach (0..($cnt-1)) {
					unless ($target) {
						$tmp = param($key."_$_");
					}
					else {
						$tmp = $target->{$key}[$_];
					}
					unless ($tmp eq $data->{$key}[$_]) {
						push @tmp, $tmp;
					}
					$tmp = '';
				}
				if (scalar(@tmp)) {
					$domain_sceleton->{$key} = [ @tmp ];
				}
			}
			else {
				unless ($target) {
					$tmp = param($key);
				}
				else {
					$tmp = $target->{$key};
				}
				unless ($data->{$key} eq $tmp) {
					$domain_sceleton->{$key} = $tmp;
				}
			}
		}
	}
#cut

# print "\n<hr>\n";
# print Dumper($domain_sceleton);
	if (scalar(keys %{$domain_sceleton})) {
		return 0;
	}
	else {
		return 1;
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
