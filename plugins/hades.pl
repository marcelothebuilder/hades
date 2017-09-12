###################################
#                                 #
#   |   |,---.    | Apr 2016      #
#   |---||---|,---|,---.,---.     #
#   |   ||   ||   ||---'`---.     #
#   `   '`   '`---'`---'`---'     #
#               revok.com.br      #
#                                 #
###################################
# fuck sosaiety

package hades;

use strict;

use Plugins;
use lib $Plugins::current_plugin_folder;
use Globals;
use Utils;
use Misc;
use Log qw(error debug message);
use Hades::Messages;
use Hades::Client;
use Hades::ClientStatus;
use Time::HiRes qw(time);

Plugins::register('hades', 'hades auth', \&ul, \&rl);

my $hooks = Plugins::addHooks(

	['mainLoop::setTitle', \&check_hades, undef],
	['packet/gameguard_request', \&gameguard_request, undef],
	['packet/gameguard_request', \&gameguard_request_reset_dc, undef],

	['packet_pre/gameguard_request', \&pre_gameguard_request, undef],
	['packet_pre/map_changed', \&reset_state, undef],
	['packet_pre/received_character_ID_and_Map', \&reset_state, undef],


	['disconnected',	\&checkTimeout],
	['Network::timeout/map_server',	\&checkTimeout],
	['Network::timeout/account_server',	\&checkTimeout],
	['Network::timeout/char_server',	\&checkTimeout],
	['Network::timeout/char_select_server',	\&checkTimeout],
	['start3', \&initialize],

	['start3',	\&setOriginalTimeout],

	['start3', \&overrideConnection]

	# ['Network::connectTo',	\&connection]
);

my $chooks = Commands::register(
	['hades', 'hades commands.', \&command]
);


# globals;
my $permittedToConnect = 0;
my $synced = 0;
my $secretKey = "2be8b9b78addc5bab742fbf3b3d992df"; # shouldn't be hardcoded!
my $waitingReply = 0;
my $waitingStartTime = 0;

my $lastRequestDiff = 0;

## FROM AVOIDDC

my $original_reconnect_timeout;
my $dc_count;

my $originalConnectionMethod;

my $clientStatus = Hades::ClientStatus::NEW;

my $clientCheckTime = time;

sub overrideConnection {
	Log::warning "Overriding connection with hades handler \n";
	$originalConnectionMethod = \&Network::DirectConnection::checkConnection;
	*Network::DirectConnection::checkConnection = \&hadesConnectionHandler;
}

sub hadesConnectionHandler {
	my ($self) = @_;

	my $wantAccountServer = $self->getState() == Network::NOT_CONNECTED
		&& (!$self->{remote_socket} || !$self->{remote_socket}->connected)
		&& timeOut($timeout_ex{'master'}) && !$conState_tries;

	# add conditions
	if (($wantAccountServer && canConnect()) || !$wantAccountServer) {
		# call original function.
		$originalConnectionMethod->(@_);

		if (!$wantAccountServer) {
			$clientStatus = Hades::ClientStatus::NEW;
		}
	}
}

sub canConnect {
	my $isAllowed = $clientStatus == Hades::ClientStatus::ALLOWED;
	if ($isAllowed) {
		return 1;
	} else {
		if (time > $clientCheckTime && !Hades::Client::getInstance()->isConnected()) {
			Log::message("[Hades] Checking hades status...\n", "info");

			$clientCheckTime = time + int(rand(180)) + 180;

			my $hades = Hades::Client::getInstance();
			$hades->setSecret( $secretKey );
			$hades->setIdentifier( $config{username} );
			$hades->post(Hades::Messages::C_QUERY_SLOT_AVAILABLE, undef);
		}
		return 0;
	}
}

sub setOriginalTimeout {
	$original_reconnect_timeout = $timeout{reconnect}{timeout};
}

sub restoreOriginalTimeout {
	$timeout{reconnect}{timeout} = $original_reconnect_timeout;
	$dc_count = 0;
}

sub gameguard_request_reset_dc {
	if ( Hades::Client::getInstance()->getIndex() >= 3 ) {
		restoreOriginalTimeout();
	}
}

sub checkTimeout {
	$dc_count++;
	if ($dc_count > 1) {
		$timeout{reconnect}{timeout} = int($timeout{reconnect}{timeout}*(rand(0.5)+2));
		Log::warning "Timeout +25%: ".$timeout{reconnect}{timeout}."s\n";
	}
}

sub pinerror {
	my (undef, $args) = @_;
	return if ($args->{flag} != 8);
	error ("PIN code is incorrect.\n", "hades");
	$timeout_ex{'master'}{'time'} = time + $timeout_ex{'master'}{'timeout'};
	$net->{conRetries} = 20;
	$timeout{reconnect}{timeout} = int($timeout{reconnect}{timeout}*(rand(0.4)+1.2));
	$args->{mangle} = 2;
	$args->{return} = 2;
}

sub initialize {
	message "Initializing hades plugin \n", "hades";
	configModify('gameGuard', 0); # poseidon should be ALWAYS turned off.
	$config{gameGuard} = 0; # poseidon should be ALWAYS turned off.
	# $Hades::Client::instance = undef;
}

sub command {
	my ($cmd, $args) = @_;

	# prepare input
	$args =~ s/^\s+//; # ltrim
	chomp($args);
	$args = lc($args);

	my ($command, $args) = split(/\s+/, $args, 2);
	# $net->setState( Network::NOT_CONNECTED );
	# 	$net->serverDisconnect();
	my $hades = Hades::Client::getInstance();

	if ("unbound" eq $command) {
		$hades->post( Hades::Messages::C_UNBOUND_REQUEST , undef );
	} elsif ("slotquery" eq $command) {
		$hades->post( Hades::Messages::C_QUERY_SLOT_AVAILABLE , undef, 1 );
	} else {
		error "Unknown command [hades $command]. \n", "hades";
		error "Available: unbound slotquery \n", "hades";
	}
}

sub gameguard_request {
	my ($net, $args) = @_;

	message "GameGuard request!\n", "hades";

	$config{gameGuard} = 0; # poseidon should be ALWAYS turned off.

	my $packet = substr($args->{RAW_MSG}, 0, $args->{RAW_MSG_SIZE});

	my $hades = Hades::Client::getInstance();
	$hades->setSecret( $secretKey );
	$hades->setIdentifier( $config{username} );
	my $queryResult = $hades->queryGameGuard( $packet  );

	if ($queryResult == -1) {
		$clientStatus = Hades::ClientStatus::OFFLINE;
	}

	$waitingReply = 1;
	$waitingStartTime = time;

	if ($synced) {
		message sprintf("%.3f seconds since the last request.\n", (time - $lastRequestDiff) ), "hades";
	}

	$lastRequestDiff = time;

	debug "Querying HADES\n", "hades";
}

sub pre_gameguard_request {
	$config{gameGuard} = 0; # poseidon should be ALWAYS turned off.
}

sub reset_state {
	$synced = 0;
	$waitingReply = 0;
	Hades::Client::getInstance()->clearState();
}

sub check_hades {
	my $result = Hades::Client::getInstance()->getResult();
	if (defined($result)) {
		message "[Hades] has something to say:\n", "hades";


		if ($result == Hades::ServerQueryResult::INTERRUPTED) {
			error "[Hades] request INTERRUPTED. This shouldn't have happened. \n", "hades";
			$net->setState( Network::NOT_CONNECTED );
			$net->serverDisconnect();
		} elsif ($result->{"ID"} == Hades::Messages::S_GAMEGUARD_REPLY) {
			# auth errors

			message sprintf(
				"[Hades] Got GameGuard reply in %.3f seconds\n",
				(time - $waitingStartTime)
				# $result->{"delay"}
			), "hades";

			# if waiting for sync and not sync
			if (!$waitingReply) {
				error "HADES sent a GameGuard reply that we weren't waiting. Discarding. \n", "hades";
				return;
			} if (!$synced && !$result->{"isSync"}) {
				error "HADES sent a REGULAR packet, but we are waiting for SYNC. Discarding. \n", "hades";
				return;
			} elsif ($synced && $result->{"isSync"}) {
				error "HADES sent a SYNC packet we were not expecting. This is a fatal error. \n", "hades";
				offlineMode();
				return;
			} elsif ($result->{"isSync"}) {
				$synced = 1;
			}

			$messageSender->sendToServer($result->{"packet"});

		} elsif ($result->{"ID"} == Hades::Messages::S_AUTH_REQUIRED) {
			error "[Hades] auth is required. \n", "hades";
			offlineMode();
		} elsif ($result->{"ID"} == Hades::Messages::S_AUTH_INVALID) {
			error "[Hades] auth is invalid. \n", "hades";
			offlineMode();
		} elsif ($result->{"ID"} == Hades::Messages::S_AUTH_BANNED) {
			error "[Hades] you are banned from this server. \n", "hades";
			offlineMode();
		} elsif ($result->{"ID"} == Hades::Messages::S_AUTH_EXPIRED) {
			error "[Hades] auth expired. \n", "hades";
			offlineMode();
			# data errors
		} elsif ($result->{"ID"} == Hades::Messages::S_RO_USERNAME_REQUIRED) {
			error "[Hades] ragnarok ID is required. \n", "hades";
			offlineMode();
		} elsif ($result->{"ID"} == Hades::Messages::S_RO_USERNAME_INVALID) {
			# state errors
			error "[Hades] ragnarok ID is invalid. \n", "hades";
			offlineMode();
		} elsif ($result->{"ID"} == Hades::Messages::S_REQUEST_QUEUE_FULL) {
			error "[Hades] queue is busy, retrying in a while. \n", "hades";
			$net->setState( Network::NOT_CONNECTED );
			$net->serverDisconnect();
		} elsif ($result->{"ID"} == Hades::Messages::S_NO_SLOT_AVAILABLE) {
			error "[Hades] has no slots for us, we should stay offline. \n", "hades";
			$clientStatus = Hades::ClientStatus::NO_SLOTS;
		} elsif ($result->{"ID"} == Hades::Messages::S_UNBOUNDED) {
			error "[Hades] unbounded. \n", "hades";
		} elsif ($result->{"ID"} == Hades::Messages::S_REQUEST_TIMED_OUT) {
			error "[Hades] request timed out. This shouldn't have happened. \n", "hades";
			$net->setState( Network::NOT_CONNECTED );
			$net->serverDisconnect();
		} elsif ($result->{"ID"} == Hades::Messages::S_UNBOUND_NO_EFFECT) {
			error "[Hades] you were already unbounded for this id, no changed made. \n", "hades";
		} elsif ($result->{"ID"} == Hades::Messages::S_SLOT_AVAILABLE_REPLY) {
			message sprintf("[Hades] has %d slots available. \n", $result->{"free"}), "info";
			if ($result->{"free"} > 0) {
				$clientStatus = Hades::ClientStatus::ALLOWED;
			} else {
				$clientStatus = Hades::ClientStatus::NO_SLOTS;
			}
		} elsif ($result->{"ID"} == Hades::Messages::S_NO_SLOT_AVAILABLE_REPLY) {
			error "[Hades] has no slots for us. \n", "hades";
			if ($net->getState() != Network::NOT_CONNECTED) {
				 $net->setState( Network::NOT_CONNECTED );
				$net->serverDisconnect();
			}
			$clientStatus = Hades::ClientStatus::NO_SLOTS;
		} elsif ($result->{"ID"} == Hades::Messages::S_BUSY_CLIENT_ERROR) {
			error "[Hades] We sent a request while our ragnarök client is busy!\n", "hades";
			$net->setState( Network::NOT_CONNECTED );
			$net->serverDisconnect();
		} else {
			error "[Hades] replied with an unknown message id: \n", "hades";
			error Data::Dumper::Dumper(\$result);
		}
	}
}

sub rl {
	ul();
}
sub ul {
	Plugins::delHooks($hooks);
	Commands::unregister($chooks);
	undef $hooks;
	undef $chooks;
}

1;
