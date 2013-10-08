#!/usr/bin/perl -w

use Time::Local;

print "Content-type: text/html; charset = utf-8\nPragma: no-cache\n\n";
print qq~<html><header><style type="text/css">
.date {
	background-color: #fafafa;
	width: 15%;
	height: 60px;
	vertical-align:top;
	font-size:11px;
}
.dateh {
	background-color: #FFEFE4;
	width: 15%;
	height: 60px;
	vertical-align:top;
	font-size:11px;
}
.dat {
	width: 15%;
}
th {
	text-align: center;
	font-weight: bold;
	font-size:11px;
}
</style><header><body>~;

#my @months = ('Январь','Февраль','Март','Апрель','Май','Июнь','Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь');

#my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
# $time = timelocal( $sec, $min, $hour, $mday, $mon, $year );
my %week = (
	1	=> 'Понедельник',
	2	=> 'Вторник',
	3	=> 'Среда',
	4	=> 'Четверг',
	5	=> 'Пятница',
	6	=> 'Суббота',
	0	=> 'Воскресенье'
);
my @week = (1, 2, 3, 4, 5, 6, 0);

my $currtime = time;
my @tmp = localtime($currtime);
$newtime = timelocal(0,0,0,1,$tmp[4],$tmp[5]);
print &show_calendar($tmp[4], $newtime);

print "</body></html>";
exit;

sub show_calendar {
	my ($raw, $datetime, $class, $flag, $html, @tmp);
	$mon = shift;
	$datetime = shift;

	@tmp = localtime($datetime);
	$html = "<table cellspacing='1' cellspacing='1'  border='0' width='100%'><tr>";
	foreach (@week) {
		$html .= "<th>$week{$_}</ht>";
	}
	$html .= "</tr>";
	$flag = 0;
	foreach $raw (1..5) {
		$html .= "<tr>";
		foreach (@week) {
			if (($_ == 0)||($_ == 6)) { $class = 'dateh'; }
			else { $class = 'date'; }
			@tmp = localtime($datetime);
			if ($raw == 1) {
				if ($tmp[6] <= $_) {
					$html .= "<td class='$class'>$tmp[3]/".($tmp[4]+1)."/".($tmp[5]+1900)."</td>";
					$flag = 1;
				}
				else {
					$html .= "<td class='dat'></td>";
				}
			}
			else {
				if ($mon == $tmp[4]) {
					$html .= "<td class='$class'>$tmp[3]/".($tmp[4]+1)."/".($tmp[5]+1900)."</td>";
					$flag = 1;
				}
				else {
					$html .= "<td class='dat'></td>";
				}
			}
			if ($flag) {
				$flag = 0;
				$datetime = $datetime + 86400;
			}
		}
		$html .= "</tr>";
	}
	$html .= "</table";

	return $html;
}
exit;
