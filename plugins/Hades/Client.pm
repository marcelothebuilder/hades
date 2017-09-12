###################################
#                                 #
#   |   |,---.    | Apr 2016      #
#   |---||---|,---|,---.,---.     #
#   |   ||   ||   ||---'`---.     #
#   `   '`   '`---'`---'`---'     #
#               revok.com.br      #
#                                 #
###################################
package Hades::Client;

use strict;
use IO::Socket::INET;
use Globals qw(%config);
use Log qw(error debug message);
use Bus::MessageParser;
use Bus::Messages qw(serialize);
use Utils qw(dataWaiting);
use Plugins;
use Misc;

# do we need all of these?
use Network::Receive;
use Network::Send ();
use Network::ClientReceive;
use Network::PaddedPackets;
use Network::MessageTokenizer;

use Hades::Messages;
use Hades::ServerQueryResult;

our $instance;

# Hades::Client Hades::Client->new(String host, int port)
#
# Create a new Hades::Client object.
sub _new {
    my ( $class, $host, $port ) = @_;
    my %self = (
        host       => $host,
        port       => $port,
        identifier => undef,
        secret     => undef,
        index      => 0
    );
    return bless \%self, $class;
}

# IO::Socket::INET $HadesClient->_connect()
#
# Connect to the poseidon server.
sub _connect {
    my ($self) = @_;
    my $socket = new IO::Socket::INET(
        PeerHost => $self->{host},
        PeerPort => $self->{port},
        Proto    => 'tcp',
        Timeout  => 10
    );
    return $socket;
}

##
# void $HadesClient->query(Bytes packet)
# packet: A GameGuard query packet.
#
# Send a GameGuard query packet to the Hades core.
#
# When an appropriate response packet has been determined,
# it will be available through $HadesClient->getResult()
sub queryGameGuard {
    my ( $self, $packet ) = @_;
    my $socket = $self->_connect();
    if ( !$socket ) {
        error "Your Ragnarok Online server uses GameGuard. In order "
          . "to support GameGuard, you must use the Hades "
          . "server. \n";

        # unsafe to continue, disconnect
        # offlineMode();
        return -1;
    }

    my ( %args, $data );
    $args{index}  = $self->{index}++;
    $args{ID}     = Hades::Messages::C_GAMEGUARD_QUERY;
    $args{ro_id}  = $self->{identifier};
    $args{packet} = $packet;
    if ( $self->{secret} ) {
        $args{secret} = $self->{secret};
    }
    $data = serialize( Hades::Messages::HADES_MESSAGE_ID, \%args );
    $socket->send($data);
    $socket->flush();
    $self->{socket} = $socket;
    $self->{parser} = new Bus::MessageParser();
}

sub post {
    my ( $self, $id, $args, $anonymous ) = @_;
    if ( $self->isConnected() ) {
        error "[Hades] client is busy.\n";
        return;
    }

    my $socket = $self->_connect();
    if ( !$socket ) {
        error "[Hades] didn't respond.\n";
        return Hades::ServerQueryResult::NO_RESPONSE;
    }

    $args->{ID}    = $id;
    $args->{ro_id} = $self->{identifier};
    if ( $self->{secret} ) {
        $args->{secret} = $self->{secret};
    }
    $socket->send( serialize( Hades::Messages::HADES_MESSAGE_ID, \%$args ) );
    $socket->flush();
    $self->{socket} = $socket;
    $self->{parser} = new Bus::MessageParser();

}

##
# Bytes $HadesClient->getResult()
# Returns: the GameGuard query result, or undef if there is no result yet.
# Ensures: if defined(result): !defined($self->getResult())
#
# Get the result for the last query.
sub getResult {
    my ($self) = @_;

    if (   !$self->isConnected()
        || !dataWaiting( $self->{socket} ) )
    {
        return undef;
    }

    my ( $buf, $ID, $args );
    $self->{socket}->recv( $buf, 1024 * 32 );
    if ( !$buf ) {

        # This shouldn't have happened.
        error
"The Hades server closed the connection unexpectedly or could not respond "
          . "to your request due to a server bandwidth issue. Please report this bug.\n";
        $self->{socket} = undef;

        # offlineMode();
        return Hades::ServerQueryResult::INTERRUPTED;
    }

    $self->{parser}->add($buf);
    if ( $args = $self->{parser}->readNext( \$ID ) ) {
        if ( $ID ne Hades::Messages::HADES_MESSAGE_ID ) {
            error
"The Hades server sent a wrong reply ID ($ID). Please report this bug.\n";
            $self->{socket} = undef;
            offlineMode();
            return undef;
        }
        else {
            $self->{socket} = undef;
            return $args;
        }
    }
    else {
        # We haven't gotten a full message yet.
        return undef;
    }
}

##
# Hades::Client Hades::Client::getInstance()
#
# Get the global Hades::Client instance.
sub getInstance {

    if ( !$instance ) {
        $instance = Hades::Client->_new(
            $config{hadesServer} || 'localhost',
            $config{hadesPort}   || 24380
        );
    }
    return $instance;
}

sub clearState {
    my ($self) = @_;
    $self->{index} = 0;
}

sub isConnected {
    my ($self) = @_;
    return $self->{socket} && $self->{socket}->connected();
}

sub setSecret {
    my ( $self, $secret ) = @_;
    $self->{secret} = $secret;
}

sub setIdentifier {
    my ( $self, $id ) = @_;
    $self->{identifier} = $id;
}

sub getIndex {
    my ($self) = @_;
    return $self->{index};
}

sub disconnect {
		my ($self) = @_;
		$self->{socket}->close();
}

1;
