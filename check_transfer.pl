#!/usr/bin/perl -w

our (%conf, %collection, %months, %week, %in, %tmpl, %mesg, %domain_mail, %command_epp, %commands, %menu_line);

print "Content-type: text/html; charset = utf-8\nPragma: no-cache\n\n";

require "drs.pm";

my ($html, $flag);

# set flag for mail css
$flag = 'old';
if (-e "$conf{'home'}/transfer") {
	$flag = 'new';
}

# Load mail frame template
$html = &load_tempfile('file' => $tmpl{'get_transfer'});

print &small_parsing(
	$html,
	'poll'		=> $flag
);

$html = '';
exit;

############## Subs ##############

sub load_tempfile {
	my ($templ, %hach);
	%hach = @_;

	open ('TMPL', "<$hach{'file'}") || die;
		while(<TMPL>){ $templ .= $_; }
	close(TMPL) || die;

	return $templ;
}

sub small_parsing {
	my ($tmpl, $setup, %hach);
	$tmpl = shift;
	%hach = @_;

	$tmpl =~ s/\<\%(\w+)?\%\>/$hach{$1}?$hach{$1}:''/gex;

	return $tmpl;
}

