package Hades::Task::Title;

use strict;
use warnings;
use Misc;
use Utils;
use Poseidon::RagnarokServer;
use Hades::Config;
use Carp::Assert;
use Hades::Statistics;

sub new {
	my $class = shift;
	$class = ref $class if ref $class;
	my $self = bless {}, $class;

	$self->{CONSOLE} = shift;
	$self->{roServer} = shift;
	$self->{queryServer} = shift;

	print sprintf("[HADES Title]-> I'll keep your console title updated.\n", Hades::Config::get("TimedTasker_Title"));

	return $self;
}

sub iterate {
	my $self = shift;

	$self->{CONSOLE}->Title(
		sprintf(Hades::Config::get("TitleTemplate"), 
			$self->{roServer}->getClientCount(), 
			$self->{roServer}->getFreeClients(),
			$self->{roServer}->getReadyClientsCount(),
			Hades::Statistics->getInstance()->getUptime(),
			Hades::Statistics->getInstance()->getDeadClientsCount(),
			Hades::Statistics->getInstance()->getAverageReplyTime(),
			Hades::Statistics->getInstance()->getReplyCount(),
			Hades::Statistics->getInstance()->getRequestCount()
		)
	);
}

1;