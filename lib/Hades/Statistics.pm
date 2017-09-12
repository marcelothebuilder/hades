package Hades::Statistics;
use strict;
use warnings;
use Utils qw/timeConvert/;

use Hades::Config;
use Hades::ThirdParty::Pushover;

my $startTime = time;
our $instance;

my $deadClients = 0;
my $notificationTimeout = 0;

sub new {
	my $class = shift;
	$class = ref $class if ref $class;
	my $self = bless {}, $class;
	$self->{packetsRequestedCount} = 0;
	$self->{packetsRepliedCount} = 0;
	$self->{packetsAverageReplyTime} = 0;

	$self;
}

sub getUptime {
	my $time = time - $startTime;
	return timeConvert($time);
}

sub getUptimeInSeconds {
	my $time = time - $startTime;
	return $time;
}

sub getExitedClients {
	my $self = shift;
}

sub getConnectedClients {
	my $self = shift;
}

sub clientExit {
	my $self = shift;
	my $client = shift;
	if ($client->{zone} == Poseidon::RagnarokServer::MAP_SERVER && !$client->{requestedQuit}) {
		print "[HADES Statistics] Client exited while MAP SERVER\n";
		$deadClients++;

		print $notificationTimeout;
		if ( Hades::Config::get("PushOverEnabled") &&
				time > Hades::Config::get("DeadClientNotificationTimeout") + $notificationTimeout ) {

			my $push = new Hades::ThirdParty::Pushover(
				Hades::Config::get("PushOverApp"),
				Hades::Config::get("PushOverUserKey")
			);

			$push->setTitle("Hades - Warning");
			$push->setMessage("One Ragnarök client disconnected from our server. Dead client count: " . $self->getDeadClientsCount() );

			$push->send();

			$notificationTimeout = time;
		}
	}
}

sub getDeadClientsCount {
	my $self = shift;
	return $deadClients;
}

sub getAverageReplyTime {
	my $self = shift;
	return $self->{packetsAverageReplyTime};
}

sub getReplyCount {
	my $self = shift;
	return $self->{packetsRepliedCount};
}

sub getRequestCount {
	my $self = shift;
	return $self->{packetsRequestedCount};
}

##
# Hades::Statistics Hades::Statistics::getInstance()
#
# Get the global Hades::Statistics instance.
sub getInstance {
	if (!$instance) {
		$instance = new Hades::Statistics();
	}
	return $instance;
}

sub queueUpdate {
	my $self = shift;
	my $request = shift;

	if ($request->getState() == Hades::RequestServer::Request::STATE_REPLIED) {
		$self->{packetsRepliedCount}++;

		$self->{packetsAverageReplyTime} = _getAverage(
			$self->{packetsAverageReplyTime},
			$request->timeFromRequest(),
			$self->{packetsRepliedCount}
		);

	} elsif ($request->getState() == Hades::RequestServer::Request::STATE_RECEIVED) {
		$self->{packetsRequestedCount}++;
	}
}

sub _getAverage {
	# http://stackoverflow.com/questions/12636613/how-to-calculate-moving-average-without-keeping-the-count-and-data-total
	my $average = shift;
	my $addedValue = shift;
	my $valuesCount = shift;

	$average -= $average / $valuesCount;
	$average += $addedValue / $valuesCount;

	return $average;
}

1;