package Hades::RequestServer::Request;
use strict;
use Scalar::Util qw/weaken/;
use Time::HiRes qw/time/;

use constant {
	STATE_RECEIVED => 0,
	STATE_REQUESTED => 1,
	STATE_REPLIED => 3,
	
	STATE_NO_CLIENT => 10,
	STATE_BUSY_CLIENT_ERROR => 11,
	STATE_QUEUE_FULL => 12,
	STATE_TIMED_OUT => 13
	## ????????/
};

##
# Hades::QueryServer::Request->new(Base::Server::Client client, String clientID, Bytes data, Integer index)
##
sub new {
	my $class = shift;
	$class = ref $class if ref $class;

	my $self = {};
	
	$self->{client} = shift;
	$self->{clientID} = shift;

	$self->{data} = shift;
	$self->{index} = shift;

	$self->{startTime} = time;
	$self->{requestTime} = 0;

	$self->{state} = STATE_RECEIVED;

	$self->{ragnarokClient} = undef;

	$self->{Reply} = undef;

	weaken($self->{client});

	bless $self, $class;
	return $self;
}

sub getData {
	my $self = shift;
	return $self->{data};
}

sub getStartTime {
	my $self = shift;
	return $self->{startTime};
}
sub getClient {
	my $self = shift;
	return $self->{client};
}

sub getClientID {
	my $self = shift;
	return $self->{clientID};
}

sub getIndex {
	my $self = shift;
	return $self->{index};
}

sub getState {
	my $self = shift;
	return $self->{state};
}

sub setState {
	my $self = shift;
	$self->{state} = shift;

	if ($self->{state} == STATE_REQUESTED) {
		$self->{requestTime} = time;
	}
}

sub setRagnarokClient {
	my ($self, $roClient) = @_;
	weaken($roClient);

	$self->{ragnarokClient} = $roClient;
	$self->{state} = STATE_REQUESTED;
}

sub getRagnarokClient {
	my ($self) = @_;
	return $self->{ragnarokClient};
}

sub timeFromRequest {
	my ($self) = @_;
	return time - $self->{requestTime};
}

sub setReply {
	my ($self, $reply) = @_;
	$self->{Reply} = $reply;
	$self->{state} = STATE_REPLIED;
	# weaken($self->{Reply});
}

sub getReply {
	my ($self) = @_;
	return $self->{Reply};
}

1;