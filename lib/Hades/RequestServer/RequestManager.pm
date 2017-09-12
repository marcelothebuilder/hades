package Hades::RequestServer::RequestManager;
use Scalar::Util qw/weaken/;
use Carp::Assert;
use Hades::Logger;
use Hades::Messages;
use Hades::Packet::GameGuardReply;
use Hades::RequestServer::Request;
use Hades::RequestServer::RequestQueue;
use Poseidon::RagnarokServer;
use Time::HiRes 'time';

##
# Hades::QueryServer::Request->new(Base::Server::Client client, String clientID, Bytes data, Integer index)
##
sub new {
	my $class = shift;
	$class = ref $class if ref $class;

	my $self = {};

	# $self->{RequestQueue} = [];
	$self->{RequestQueue} = new Hades::RequestServer::RequestQueue();
	$self->{QueueListener} = [];
	$self->{RagnarokServer} = shift;
	$self->{LastRequestTime} = time;

	weaken($self->{RagnarokServer});

	bless $self, $class;
	return $self;
}

sub add {
	my ($self, $request) = @_;
	assert(defined($request));
	assert($request);

	if (Hades::Config::get("QueueMaxSize") > $self->{RequestQueue}->getSize()) {
		print sprintf("[RequestManager]-> Request placed on queue (size %d), should be processed soon.\n", $self->{RequestQueue}->getSize());
		$self->{RequestQueue}->add($request);
	} else {
		# queue full
		$request->setState( Hades::RequestServer::Request::STATE_QUEUE_FULL );
		$self->notifyQueueUpdate( $request );
		# $self->{RequestQueue}->remove( $request ); #nothing to remove.
	}
	
}

sub iterate {
	my ($self) = @_;

	my $hasPriority = 0;

	my $exclusive = Hades::Config::get("FirstRequestExclusiveProcessing");

	foreach my $request (@{$self->{RequestQueue}->getItems()}) {
		assert($request);
		assert(defined($request));

		last if ($exclusive && $hasPriority && $request->getIndex() != 0);

		if ($exclusive && $request->getIndex() == 0) {
			$hasPriority = 1;
		}

		if ( ( $request->getIndex() == 0 && (time - $request->getStartTime()) >= Hades::Config::get("FirstRequestTimeout") )
			|| ( $request->getIndex() != 0 && (time - $request->getStartTime()) > Hades::Config::get("RequestTimeout")  ) ) {

			my $log = sprintf("Removing timed out request, this shouldn't have happened. Index: %d State: %s",
					$request->getIndex(),
					$request->getState() );

			print sprintf("[RequestManager]-> %s\n", $log);
			Hades::Logger::logLine($log);

			
			# discard any response that we may be storing
			if ($request->getRagnarokClient()) {
				print ("[RequestManager]-> Discarding response.\n");
				Hades::Logger::logLine("Discarding response.");
				Poseidon::RagnarokServer::readResponse( $request->getRagnarokClient() );
			}

			$request->setState( Hades::RequestServer::Request::STATE_TIMED_OUT );
			$self->notifyQueueUpdate($request);
			$self->{RequestQueue}->remove($request);

		} elsif ($request->getState() == Hades::RequestServer::Request::STATE_RECEIVED) {
			$self->doQuery($request);
		} elsif ($request->getState() == Hades::RequestServer::Request::STATE_REQUESTED &&
			$request->getRagnarokClient()->{query_state} == Hades::RagnarokServer::Client::REPLIED) {
			# receive response packet from client

			# print sprintf("Getting response from request #%d %s\n", $request->getIndex(), (time - $request->getStartTime()) );

			$self->doGetResponse($request);
		}
	}

}

sub isRequestIntervalPassed {
	my $self = shift;

	# if (Hades::Config::get("MinimumRequestInterval") < 1) {
	# 	return 1;
	# }

	if ( time > $self->{LastRequestTime} + Hades::Config::get("MinimumRequestInterval") ) {
		$self->{LastRequestTime} = time;
		return 1;
	}

	return 0;
}

sub setQueueListener {
	my ($self, $listener) = @_;
	if ($listener->can("queueUpdate")) {
		push @{$self->{QueueListener}}, $listener;
	} else {
		die "Listener can't listener->queueUpdate()!";
	}
}

sub notifyQueueUpdate {
	my ($self, $request) = @_;
	foreach my $listener (@{$self->{QueueListener}}) {
		$listener->queueUpdate($request);
	}
}


sub doQuery {
	my $self = shift;
	my $request = shift;

	if ( $self->isRequestIntervalPassed() ) {
		my $roClient = $self->{RagnarokServer}->getClientForRequest($request);

		# my $roClientReady = $roClient->{query_state} == Hades::RagnarokServer::Client::READY;
		# my $roClientReplied = $roClient->{query_state} == Hades::RagnarokServer::Client::REPLIED;

		# my $roClientTimeout = (time - $client->{last_request}) < 10;
		
		# no RO client available
		if (!$roClient) {
			$request->setState( Hades::RequestServer::Request::STATE_NO_CLIENT );
			$self->notifyQueueUpdate($request);
			$self->{RequestQueue}->remove($request);
		# was causing a bug where RO client would never get ready
		# } elsif ( !$roClientReady && !$roClientTimeout ) {
		# 	$request->setState( Hades::RequestServer::Request::STATE_BUSY_CLIENT_ERROR );
		# 	$self->notifyQueueUpdate($request);
		# 	$self->{RequestQueue}->remove($request);
		} else {
			$request->setState( Hades::RequestServer::Request::STATE_REQUESTED );
			$self->{RagnarokServer}->query($roClient, $request);
			$request->setRagnarokClient($roClient);
		}
	}
}

sub doGetResponse {
	my $self = shift;
	my $request = shift;

	# assert($request->getClient());

	if ( $request->getClient() ) {
		my $data = Poseidon::RagnarokServer::readResponse( $request->getRagnarokClient() );
		my $packet = Hades::Packet::GameGuardReply::fromBytes( $data );

		$request->setReply($packet);
	} else {
		Hades::Logger::logLine("Client left before we could send a response.");
	}

	$self->notifyQueueUpdate($request);
	$self->{RequestQueue}->remove($request);
}

1;