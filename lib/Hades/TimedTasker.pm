package Hades::TimedTasker;

use strict;
use warnings;
use Misc;
use Utils;


sub new {
	my ($class, @args) = @_;
	# my $self = $class->SUPER::new(@args);
	my $self = {};

	# Array<Task> queue
	# $self->{"$CLASS task"} = [];
	$self->{tasks} = [];

	bless $self, $class;

	return $self;
}

sub registerTask {
	my ($self, $task, $timeout) = @_;

	if ($task->can("iterate")) {
		my $taskOptions = {
			name => ref($task)."-"._randomName(),
			task => $task,
			interval_manager => {
				time => 0,
				timeout => $timeout
				}
			};

		push @{$self->{tasks}}, $taskOptions;
		print sprintf("[HADES TimedTasker] Task %s will run every %d seconds \n",
			$taskOptions->{name},
			$taskOptions->{interval_manager}->{timeout}
		);


	} else {
		warn "Not a task passed to TimedTasker \n";
	}
}

sub iterate {
	my ($self) = @_;

	foreach my $task (@{$self->{tasks}}) {
		if ( _timeOut($task->{interval_manager}) ) {

			$task->{task}->iterate();
		}
	}
}

sub _timeOut {
	my $timeout = shift;
	if ( time > ( $timeout->{time} + $timeout->{timeout} ) ) {
		$timeout->{time} = time;
	}
}

sub _randomName {
	my @chars = ("A".."Z", "a".."z");
	my $string;
	$string .= $chars[rand @chars] for 1..8;
	return $string;
}

1;