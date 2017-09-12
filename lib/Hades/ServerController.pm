package Hades::ServerController;
use Hades::RequestServer::RequestManager;
use Carp::Assert;
sub new {
	my $class = shift;
	$class = ref $class if ref $class;

	my $self = bless {}, $class;

	$self->{RagnarokServer} = shift;
	$self->{QueryServer} = shift;

	$self->{RequestManager} = new Hades::RequestServer::RequestManager( $self->{RagnarokServer} );

	$self->{QueryServer}->setRequestListener($self);
	
	$self->{RequestManager}->setQueueListener( $self );

	$self->{RequestManager}->setQueueListener( Hades::Statistics::getInstance() );

	$self->{RagnarokServer}->addClientListener( Hades::Statistics::getInstance() );

	return $self;
}

sub iterate {
	my $self = shift;
	$self->{RequestManager}->iterate();
	$self->{RagnarokServer}->iterate();
	$self->{QueryServer}->iterate();
}

sub requestReceived {
	my $self = shift;
	my $request = shift;
	assert($request);
	assert(defined($request));
	$self->{RequestManager}->add($request);
}

sub queueUpdate {
	my ($self, $request) = @_;

	if ($request->getState() == Hades::RequestServer::Request::STATE_NO_CLIENT) {

		$self->{QueryServer}->hadesReply($request->getClient(), Hades::Messages::S_NO_SLOT_AVAILABLE, undef);

	} elsif ($request->getState() == Hades::RequestServer::Request::STATE_REPLIED) {
		
		print sprintf( "[QueryServer]-> Reply took %.3f seconds \n", $request->timeFromRequest() );

		$self->{QueryServer}->hadesReply( $request->getClient() , Hades::Messages::S_GAMEGUARD_REPLY,
			{
				packet => $request->getReply()->toBytes(),
				delay => $request->timeFromRequest(),
				isSync => $request->getReply()->isSync()
			});
	} elsif ($request->getState() == Hades::RequestServer::Request::STATE_BUSY_CLIENT_ERROR) {
		$self->{QueryServer}->hadesReply( $request->getClient() , Hades::Messages::S_BUSY_CLIENT_ERROR, undef);
	} elsif ($request->getState() == Hades::RequestServer::Request::STATE_QUEUE_FULL) {
		$self->{QueryServer}->hadesReply( $request->getClient() , Hades::Messages::S_REQUEST_QUEUE_FULL, undef);
	}  elsif ($request->getState() == Hades::RequestServer::Request::STATE_TIMED_OUT) {
		$self->{QueryServer}->hadesReply( $request->getClient() , Hades::Messages::S_REQUEST_TIMED_OUT, undef);
	}
}


1;