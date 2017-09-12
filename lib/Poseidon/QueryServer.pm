###########################################################
# Poseidon server - OpenKore communication channel
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License 
# as published by the Free Software Foundation; either version 2 
# of the License, or (at your option) any later version.
#
# Copyright (c) 2005-2006 OpenKore Development Team
###########################################################
package Poseidon::QueryServer;

use strict;
use Scalar::Util;
use Base::Server;
use Bus::MessageParser;
use Bus::Messages qw(serialize);
use Poseidon::RagnarokServer;
use Poseidon::Config;
use base qw(Base::Server);
use Utils qw(timeOut);
use Plugins;
use Time::HiRes qw(time sleep);

use Hades::Config;
use Hades::Messages;
use Hades::Packet::GameGuardReply;
use Hades::RagnarokServer::Client;
use Hades::RequestServer::Request;
use Hades::Logger;

my $CLASS = "Poseidon::QueryServer";

use constant REQUEST_TIMEOUT => 50;

# struct Request {
#     Bytes packet;
#     Base::Server::Client client;
# }

##
# Poseidon::QueryServer->new(String port, String host, Poseidon::RagnarokServer ROServer)
# port: The port to start this server on.
# host: The host to bind this server to.
# ROServer: The RagnarokServer object to send GameGuard queries to.
# Require: defined($port) && defined($ROServer)
#
# Create a new Poseidon::QueryServer object.
sub new {
	my ($class, $port, $host, $roServer) = @_;
	my $self = $class->SUPER::new($port, $host);

	# Invariant: server isa 'Poseidon::RagnarokServer'
	$self->{"$CLASS server"} = $roServer;

	# Array<Request> queue
	#
	# The GameGuard query packets queue.
	#
	# Invariant: defined(queue)
	$self->{"$CLASS queue"} = [];

	$self->{RequestListener} = undef;

	return $self;
}

##
# void $QueryServer->process(Base::Server::Client client, String ID, Hash* args)
#
# Push an OpenKore GameGuard query to the queue.
sub process {
	my ($self, $client, $ID, $args) = @_;

	if ($ID eq Hades::Messages::HADES_MESSAGE_ID) {
		my $hadesMID = $args->{"ID"};

		print "[QueryServer]-> Incoming message from (" . $client->getIndex() . ")\n";

		if ($hadesMID eq Hades::Messages::C_GAMEGUARD_QUERY) {
			$self->handleGameGuardQuery($client, $args);
		} elsif ($hadesMID eq Hades::Messages::C_UNBOUND_REQUEST) {
			$self->handleUnboundRequest($client, $args);
		} elsif ($hadesMID eq Hades::Messages::C_QUERY_SLOT_AVAILABLE) {
			$self->handleQuerySlotAvailable($client, $args);
		} elsif ($hadesMID eq Hades::Messages::C_QUERY_SERVER_SUMMARY) {
			$self->handleQuerySummary($client, $args);
		} else {
			print "Unsupported message ".$hadesMID."\n";
		}
	} else {
		$client->close();
		return;
	}
}

sub hadesReply {
	my ($self, $client, $messageID, $args) = @_;

	$args->{"ID"} = $messageID;

	#construct data
	my $data = serialize(Hades::Messages::HADES_MESSAGE_ID, \%$args);

	print "Hades is sending a message $messageID\n";

	if (!defined $client) {
		my ($package, $filename, $line) = caller;
		my $log = "We tried to reply, but client ref var isn't defined anymore! Called by $package $line\n";
		print sprintf( "%s\n", $log );
		Hades::Logger::logLine( $log );
		return;
	}

	$client->send($data);
	$client->close();

	
}

##################################################

sub onClientNew {
	my ($self, $client, $index) = @_;
	$client->{"$CLASS parser"} = new Bus::MessageParser();
	print "[QueryServer]-> New Bot Client Connected : " . $client->getIndex() . "\n";
}

sub onClientExit {
	my ($self, $client, $index) = @_;
	print "[QueryServer]-> Bot Client Disconnected : " . $client->getIndex() . "\n";
}

sub onClientData {
	my ($self, $client, $msg) = @_;
	my ($ID, $args);

	my $parser = $client->{"$CLASS parser"};
	
	$parser->add($msg);
	
	while ($args = $parser->readNext(\$ID)) {
		$self->process($client, $ID, $args);
	}
}

sub iterate {
	my ($self) = @_;
	# my ($server, $queue);

	$self->SUPER::iterate();
	# $server = $self->{"$CLASS server"};
}


sub handleGameGuardQuery {
	my ($self, $client, $args) = @_;

	if (!$args->{ro_id}) {
		$self->hadesReply($client, Hades::Messages::S_RO_USERNAME_REQUIRED, undef);
		return 0;
	} elsif (!$args->{secret}) {
		$self->hadesReply($client, Hades::Messages::S_AUTH_REQUIRED, undef);
		return 0;
	} elsif ($args->{secret} != Hades::Config::get("SecretKey") ) {
		$self->hadesReply($client, Hades::Messages::S_AUTH_INVALID, undef);
		return 0;
	} elsif (!defined $args->{index}) {
		$self->hadesReply($client, Hades::Messages::S_RO_USERNAME_REQUIRED, undef);
		return 0;
	}

	print sprintf("[QueryServer]-> Query from ( %s )\n", $args->{ro_id});

	my $request = new Hades::RequestServer::Request($client, $args->{ro_id}, $args->{packet}, $args->{index});
	$self->notifyRequestListener($request);
}

sub handleUnboundRequest {
	my ($self, $client, $args) = @_;

	if (!$args->{ro_id}) {
		$self->hadesReply($client, Hades::Messages::S_RO_USERNAME_REQUIRED, undef);
		return 0;
	} elsif (!$args->{secret}) {
		$self->hadesReply($client, Hades::Messages::S_AUTH_REQUIRED, undef);
		return 0;
	} elsif ($args->{secret} != Hades::Config::get("SecretKey") ) {
		$self->hadesReply($client, Hades::Messages::S_AUTH_INVALID, undef);
		return 0;
	}

	# requests to unbound
	if (!$args->{ro_id}) {
		$self->hadesReply($client, Hades::Messages::S_RO_USERNAME_REQUIRED, undef);
		return;
	}

	my $roServer = $self->{"$CLASS server"};

	if ($roServer->unbound($args->{ro_id})) {
		$self->hadesReply($client, Hades::Messages::S_UNBOUNDED, undef);
	} else {
		$self->hadesReply($client, Hades::Messages::S_UNBOUND_NO_EFFECT, undef);
	}
}

sub handleQuerySlotAvailable {
	my ($self, $client, $args) = @_;

	if (!$args->{ro_id}) {
		$self->hadesReply($client, Hades::Messages::S_RO_USERNAME_REQUIRED, undef);
		return 0;
	} elsif (!$args->{secret}) {
		$self->hadesReply($client, Hades::Messages::S_AUTH_REQUIRED, undef);
		return 0;
	} elsif ($args->{secret} != Hades::Config::get("SecretKey") ) {
		$self->hadesReply($client, Hades::Messages::S_AUTH_INVALID, undef);
		return 0;
	}

	my $roServer = $self->{"$CLASS server"};
	my $freeCount;
	if ($args->{ro_id}) {
		$freeCount = $roServer->getFreeClients($args->{ro_id});
	} else {
		$freeCount = $roServer->getFreeClients();
	}

	if ( $freeCount ) {
		$self->hadesReply($client, Hades::Messages::S_SLOT_AVAILABLE_REPLY, { free => $freeCount });
	} else {
		$self->hadesReply($client, Hades::Messages::S_NO_SLOT_AVAILABLE_REPLY, { free => $freeCount });
	}
}

# C_QUERY_SERVER_SUMMARY
sub handleQuerySummary {
	my ($self, $client, $args) = @_;

	my $roServer = $self->{"$CLASS server"};

	my $stats = Hades::Statistics::getInstance();

	$self->hadesReply($client, Hades::Messages::S_SERVER_SUMMARY,
		{
			client_total => $roServer->getClientCount(),
			client_free => $roServer->getFreeClients(),
			client_ready => $roServer->getReadyClientsCount(),
			client_dead => $stats->getDeadClientsCount(),
			uptime => $stats->getUptimeInSeconds(),
			uptime_pretty => $stats->getUptime()
		}
	);
}

sub _getMaxQueueSize {
	my ($self) = @_;
	return 5;
}

sub _getRequestTimeout {
	return Hades::Config::get("RequestTimeout") || REQUEST_TIMEOUT;
}

sub setRequestListener {
	my ($self, $listener) = @_;
	if ($listener->can("requestReceived")) {
		$self->{RequestListener} = $listener;
	} else {
		die "Listener can't listener->requestReceived()!";
	}
}

sub notifyRequestListener {
	my ($self, $request) = @_;
	if ($self->{RequestListener}) {
		$self->{RequestListener}->requestReceived($request);
	}
}

1;