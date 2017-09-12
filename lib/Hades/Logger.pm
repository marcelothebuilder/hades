package Hades::Logger;
use strict;

# my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
# my @days = qw(Sun Mon Tue Wed Thu Fri Sat Sun);

my $logFolder = "./";

sub _new {
	my $class = shift;
	$class = ref $class if ref $class;
	my $self = bless {}, $class;
	$self;
}

sub _printToFile {
	my $strings = shift;

	open FILE, ">>".$logFolder._getFormattedFileDate().".log";
	print FILE $strings;
	close FILE;
}

sub setLogFolder {
	my $folder = shift;
	$logFolder = $folder;

	if (!-e $folder) {
		die "$folder doesn't exist!";
	} elsif (!-d $folder) {
		die "$folder not a dir!";
	}
}

sub logLine {
	my $message = shift;

	_printToFile sprintf("%s %s\n", _getFormattedDate(), $message);
}

sub logLines {
	my @lines = @_;
	my $message = sprintf("%s %s\n", _getFormattedDate(), '=' x 55);

	foreach my $line (@lines) {
		$message .= "= ".$line."\n";
	}

	$message .= sprintf("%s\n", '=' x 78);

	_printToFile $message;
}

sub _getFormattedDate {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();

	$year += 1900;
	$mon += 1;

	return sprintf("[%d-%.2d-%.2d %.2d:%.2d:%.2d]", $year, $mon, $mday, $hour, $min, $sec);
}

sub _getFormattedFileDate {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();

	$year += 1900;
	$mon += 1;

	return sprintf("%d.%.2d.%.2d", $year, $mon, $mday);
}


1;