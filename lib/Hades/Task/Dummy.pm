package Hades::Task::Dummy;

use strict;
use warnings;
use Misc;
use Utils;

sub new {
	my $class = shift;
	$class = ref $class if ref $class;
	my $self = bless {}, $class;
	return $self;
}

sub iterate {
	my $self = shift;
	print "Dummy running \n";
}

1;