package Hades::Task::Reconfig;

use strict;
use warnings;
use Misc;
use Utils;
use Hades::Config;
use Carp::Assert;

sub new {
	my $class = shift;
	$class = ref $class if ref $class;
	my $self = bless {}, $class;

	my (undef, undef, undef, undef, undef, undef, undef,
		$currentSize, undef,
		$currentModificationTime,
		$currentChangeTime,
		undef, undef) = stat( Hades::Config::getFilePath() );

	$self->{lastSize} = $currentSize;
	$self->{lastModificationTime} = $currentModificationTime;
	$self->{lastChangeTime} = $currentChangeTime;

	$self->{callbacks} = [];

	print sprintf("[HADES Reconfig]-> Reconfig will re-check your config file for change.\n");

	return $self;
}


sub addCallback {
	my ($self, $callback) = @_;
	push (@{$self->{callbacks}}, $callback);
}

sub _runCallbacks {
	my ($self) = @_;
	foreach my $callback (@{$self->{callbacks}}) {
		$callback->();
	}
}

sub iterate {
	my $self = shift;
	if ( $self->_isModified() ) {
		print sprintf("[HADES Reconfig]-> Reloading %s.\n", Hades::Config::getFilePath());
		Hades::Config::reload();
		$self->_runCallbacks();
	}
}

sub _isModified {
	my $self = shift;

	my (undef, undef, undef, undef, undef, undef, undef,
		$currentSize, undef,
		$currentModificationTime,
		$currentChangeTime,
		undef, undef) = stat( Hades::Config::getFilePath() );

	my $modified = ($currentSize != $self->{lastSize}
		|| $currentModificationTime != $self->{lastModificationTime}
		|| $currentChangeTime != $self->{lastChangeTime});

	$self->{lastSize} = $currentSize;
	$self->{lastModificationTime} = $currentModificationTime;
	$self->{lastChangeTime} = $currentChangeTime;

	return $modified;
}

1;