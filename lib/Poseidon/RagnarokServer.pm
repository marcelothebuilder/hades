###########################################################
# Poseidon server - Ragnarok Online server emulator
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License 
# as published by the Free Software Foundation; either version 2 
# of the License, or (at your option) any later version.
#
# Copyright (c) 2005-2006 OpenKore Development Team
###########################################################
# This class emulates a Ragnarok Online server.
# The RO client connects to this server. This server
# periodically sends a GameGuard query to the RO client,
# and saves the RO client's response.
###########################################################

# TODO:
# 1) make use of unpack strings to pack our packets depending on serverType
# 2) make plugin like connection algorithms for each serverType or 1 main algo on which serverTypes have hooks

package Poseidon::RagnarokServer;

use strict;
use Base::Server;
use base qw(Base::Server);
use Misc;
use Utils qw(binSize getCoordString timeOut getHex getTickCount);
use Carp::Assert;
use Data::Dumper;
use FileParsers;
use Hades::Logger;
use Hades::Packet;
use Hades::RagnarokServer::Client;
use List::Util qw( first );
use Math::BigInt;
use Poseidon::Config;

my %clientdata;

# Decryption Keys
my $client->{state} = 0;

my %rpackets;

use constant {
	NOT_CONNECTED => 0,
	LOGIN_SERVER => 1,
	CHAR_SERVER => 2,
	MAP_SERVER => 3
};


sub new {
	my ($class, @args) = @_;
	my $self = $class->SUPER::new(@args);
	# Bytes response
	#
	# A response for the last GameGuard query.
	$self->{response} = undef;

	# Invariant: state ne ''
	$self->{state} = 'ready';

	# No debugging by default
	$self->{debug} = 0;

	$self->{clientListeners} = [];

	#load needed files

	if (-e 'conf/servertypes.txt') {
		parseSectionedFile('conf/servertypes.txt', \%{$self->{type}});
	} else {
		die "conf/servertypes.txt not found! \n";
	}
	
	if (-e 'conf/recvpackets.txt') {
		parseRecvpackets('conf/recvpackets.txt', \%rpackets);	
	} else {
		die "conf/recvpackets.txt not found! \n";
	}
	

	if (!$self->{type}->{Hades::Config::get("ServerType")}) {
		die("Invalid serverType ".Hades::Config::get("ServerType")." specified. Please check your poseidon config file.\n");
	}

	# else {
	# 	print "Building RagnarokServer with serverType ".Hades::Config::get("ServerType")."...\n";
	# }

	return $self;
}

sub addClientListener {
	my $self = shift;
	my $listener = shift;
	push @{$self->{clientListeners}}, $listener;
}

sub removeClientListener {
	die "Not implemented";
}


sub fireClientExit {
	my $self = shift;
	my $client = shift;
	foreach my $listener (@{$self->{clientListeners}}) {
		if ($listener->can("clientExit")) {
			$listener->clientExit($client);
		}
	}
}

sub fireClientNew {
	my $self = shift;
	my $client = shift;
	foreach my $listener (@{$self->{clientListeners}}) {
		if ($listener->can("clientNew")) {
			$listener->clientNew($client);
		}
	}
}

sub fireClientZoneChange {
	my $self = shift;
	my $client = shift;

	foreach my $listener (@{$self->{clientListeners}}) {
		if ($listener->can("clientZoneChange")) {
			$listener->clientZoneChange($client);
		}
	}
}

sub getFreeClients {
	my $self = shift;
	my $userId = shift;
	return scalar grep { 
		$_ 
		&& $_->{connectedToMap} 
		&& (!$_->{boundUsername} || ($userId && $_->{boundUsername} eq $userId) ) } @{$self->clients()};
}

sub getReadyClientsCount {
	my $self = shift;
	return scalar grep { $_ && $_->{connectedToMap} } @{$self->clients()};
}

sub getClientCount {
	my $self = shift;
	return scalar @{$self->clients()};
}

##
# $RagnarokServer->query(Hades::RequestServer::Request request)
# packet: The request object
# Require: defined($packet) && $self->getState() eq 'ready'
# Ensure: $self->getState() eq 'requesting'
#
# Send a GameGuard query to the RO client.
sub query {
	my ($self, $client, $request) = @_;

	print "[RagnarokServer]-> Querying Ragnarok Online client [" . time . "]...\n";
	print "[RagnarokServer]-> User: ". $request->getClientID() ."...\n";

	if (!$client->{boundUsername}) {
		print sprintf("[HADES]-> Bounding userID %s to client %d %s \n", $request->getClientID(), $client->getIndex() );
		$client->{boundUsername} = $request->getClientID();
	}

	print sprintf( "[HADES]-> Issuing request from userID %s to client %d\n", $request->getClientID(), $client->getIndex() );

	$client->send( $request->getData() );
	$client->{query_state} = Hades::RagnarokServer::Client::REQUESTING;
	# print "RO Client state now $client->{query_state} \n";
	$client->{last_request} = time;
}

sub getClientForRequest {
	my ($self, $request) = @_;

	my ($self, $request) = @_;

	my $clients = $self->clients();

	my $client = undef;

	foreach my $loop_client (@$clients) {
		if ($loop_client && $loop_client->{connectedToMap}) {
			if ( $loop_client->{boundUsername} eq $request->getClientID() ) {
				$client = $loop_client;
				last;
			} elsif ( !$loop_client->{boundUsername} ) {
				$client = $loop_client;
			}

			# if none of those conditions matches then it's bounded
		}
	}

	if (!$client) {
		print "[HADES]-> Error: no Ragnarok Online client available.\n";
		return undef;
	}

	return $client;
}

sub unbound {
	my ($self, $requesterId) = @_;
	my $client = first {
				$_
				&& $_->{boundUsername} eq $requesterId
			} @{$self->clients()};

	if ($client) {
		print sprintf("[HADES]-> UNbounding userID %s to client %d %s \n", $requesterId, $client->getIndex() );
		$client->{boundUsername} = undef;
		return 1;
	} else {
		print sprintf("[HADES]-> ClientID %s is already unbounded \n", $requesterId );
		return 0;
	}
}

##
# String $RagnarokServer->getState()
#
# Get the state of this RagnarokServer object.
# The result can be one of:
# 'ready' - The RO client is ready to handle another GameGuard query.
# 'requesting' - The query has been sent to the RO client, but it hasn't responded yet.
# 'requested' - The RO client has responded to the last GameGuard query.
# 'not connected' - The RO client hasn't connected to this server yet.
sub getState {
	my ($self) = @_;
	my $clients = $self->clients();
 
	if ($self->{state} eq 'requested') {
		return 'requested';
	} elsif (binSize($clients) == 0) {
		return 'not connected';
	} else {
		return $self->{state};
	}
}

##
# Bytes $RagnarokServer->readResponse()
# Require: $self->getState() eq 'requested'
# Ensure: defined(result) && $self->getState() eq 'ready'
#
# Read the response for the last GameGuard query.
sub readResponse {
	#print Dumper($_[0]);
	my $resp = $_[0]->{response};
	$_[0]->{response} = undef;
	$_[0]->{query_state} = Hades::RagnarokServer::Client::READY;
	return $resp;
}


#####################################################

sub onClientNew 
{
	my ($self, $client, $index) = @_;
	
	my $aID = pack("V",randomInteger(7));
	my $cID = pack("V",randomInteger(6));
	my $sID = pack("V",randomInteger(5));
	
	$client->{accountID} = pack("a4", $aID);
	$client->{charID} = pack("a4", $cID); #6 caracteres
	$client->{sessionID} = pack("a4", $sID); #5 caracteres
	
	$client->{zone} = NOT_CONNECTED;
	
	$client->{query_state} = Hades::RagnarokServer::Client::READY;
	# print "RO Client state now $client->{query_state} \n";
	
	my @enc_values = split( /\s+/, $self->{type}->{Hades::Config::get("ServerType")}->{decrypt_mid_keys} );
	($client->{cryptKey_1}, $client->{cryptKey_3}, $client->{cryptKey_2}) = (Math::BigInt->new(@enc_values[0]), Math::BigInt->new(@enc_values[1]), Math::BigInt->new(@enc_values[2]));
		
	print "[RagnarokServer]-> Ragnarok Online client ($index) connected.\n";
	#print sprintf("[RagnarokServer]-> accID: %s charID: %s sID: %s \n", $aID, $cID, $sID);

	$self->fireClientNew($client);
}

sub onClientExit 
{
	my ($self, $client, $index) = @_;
		
	print "[RagnarokServer]-> Ragnarok Online client ($index) disconnected.\n";

	$self->fireClientExit($client);
}

sub randomInteger {
  my $length = shift;
  my $string;
  for (my $i; $i < $length; $i++) {
    $string .= int(rand(9));
  }
  return $string;
}

## constants
my $posX = 53;
my $posY = 113;

## Globals
my $sessionID2 = pack("C4", 0xff);
my $npcID1 = pack("a4", "npc1");
my $npcID0 = pack("a4", "npc2");
my $monsterID = pack("a4", "mon1");
my $itemID = pack("a4", "itm1");

sub DecryptMID {
	my ($self, $client, $MID) = @_;

	my $packet = $MID;

	if ($client->{zone} ne MAP_SERVER) {
		die "Can't decrypt outside MAP_SERVER! \n";
	}
	
	my $value = (($self->DecryptMIDGetKey($client) >> 16) & 0x7FFF);

	$packet->setDecryptionKey($value);
}

sub DecryptMIDGetKey {
	my ($self, $client) = @_;
	# no key yet
	if (!($client->{cryptKey} > 0)) {
		# get the first key
		$client->{cryptKey} = $client->{cryptKey_1};
		# calculate with it
		$self->_DecryptMIDGetNextKey($client);
	}

	# current key
	my $key = $client->{cryptKey};

	# calculate the next one
	$self->_DecryptMIDGetNextKey($client);

	return $key;
}

sub _DecryptMIDGetNextKey {
	my ($self, $client) = @_;
	$client->{cryptKey} = ((($client->{cryptKey} * $client->{cryptKey_2}) + $client->{cryptKey_3}) & 0xFFFFFFFF);
}

sub onClientData
{
	my ($self, $client, $msg, $index) = @_;
	my $mode = $clientdata{$index}{mode};
	my $packet_id = unpack("v",$msg);
	my $switch = sprintf("%04X", $packet_id);

	my $packet = new Hades::Packet();
	$packet->setRawData($msg);

	# Parsing Packet
	ParsePacket($self, $client, $msg, $index, $packet);
}

sub ParsePacket
{
	my ($self, $client, $msg, $index, $packet) = @_;
	
	my $aID = $client->{accountID};
	my $cID = $client->{charID};
	my $sID = $client->{sessionID};
	
	### These variables control the account information ###
	my $host = $self->getHost();
	my $port = pack("v", $self->getPort());
	$host = '127.0.0.1' if ($host eq 'localhost');
	my @ipElements = split /\./, $host;	
	
	if ($client->{zone} eq MAP_SERVER) {
		# decrypt
		$self->DecryptMID($client, $packet);
	}

	my $mapLogin = hex($self->{type}->{Hades::Config::get("ServerType")}->{maploginPacket});
	my $encryptedMap = ($mapLogin ^ ((($client->{cryptKey_1} * $client->{cryptKey_2}) + $client->{cryptKey_3}) >> 16 ) & 0x7FFF);

	# map_login
	if ( $client->{zone} != MAP_SERVER && $packet->getPacketId() == $encryptedMap)  {
		$client->{zone} = MAP_SERVER;
		$clientdata{$index}{serverType} = 0;

		# recursive call
		return $self->ParsePacket($client, $msg, $index, $packet);
	}

	# print "$packet\n";


	# ValidatePacket($packet);
	if (!_IsValidPacketID($packet)) {
		print sprintf("Client sent us an invalid packetid %s (%d).\n", $packet->getPacketSwitch(), $packet->getLength() );

		my @log = (
			sprintf( "Got an unknown packet switch: %s", $packet->getPacketSwitch() ),
			sprintf( "\tDetails: %s", $packet ),
			sprintf( "\tDump: %s", unpack("H*", $packet->getData()) ),
			sprintf( "\tDump Raw: %s", unpack("H*", $packet->getRawData()) )
		);

		if ($client->{latestPacket}) {
			push (@log, "PREVIOUS PACKET:");
			push (@log, sprintf( "\tDetails: %s", $client->{latestPacket} ) );
			push (@log, sprintf( "\tDump: %s", unpack("H*", $client->{latestPacket}->getData()) ) );
			push (@log, sprintf( "\tDump Raw: %s", unpack("H*", $client->{latestPacket}->getRawData() ) ));
		}
		
		Hades::Logger::logLines(@log);

		if (Hades::Config::get("KickClientWhenInvalidPacket")) {
			print "Kick client \n";
			SendGoToCharSelection($self, $client, $msg, $index);
		}
		return;
	}

	# take care of tangled packets
	my $excedent = $self->Detangle($packet);

	if (!_IsValidPacketSize($packet)) {
		print sprintf("Client sent us an invalid packetsize %s (%d).\n", $packet->getPacketSwitch(), $packet->getLength() );
		SendGoToCharSelection($self, $client, $msg, $index);
		return;
	}

	# is map login
	if ($packet->getPacketSwitch() eq $self->{type}->{Hades::Config::get("ServerType")}->{maploginPacket}) {
		SendAccountID($self, $client, $msg, $index); # 0283
		SendMapLogin($self, $client, $msg, $index); # 02EB
	} if ($packet->getPacketSwitch() eq '02B0' || $packet->getPacketSwitch() eq '0064') {
		my $sex = 1;
		my $serverName = pack("a20", "Asgard"); # server name should be less than or equal to 20 characters
		my $serverUsers = pack("V", @{$self->clients()} - 1);
		# '0069' => ['account_server_info', 'x2 a4 a4 a4 x30 C1 a*',
		# 			[qw(sessionID accountID sessionID2 accountSex serverInfo)]],
		my $data;
		$data = pack("C*", 0x69, 0x00, 0x4F, 0x00) . 
		$sID . $aID . $sessionID2 . 
		pack("x30") . pack("C1", $sex) .
		pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) .
		$port .	$serverName . $serverUsers . pack("x2");
		
		$client->send($data);
		$client->{zone} = LOGIN_SERVER;
		$self->fireClientZoneChange($client);
		
	} elsif ($packet->getPacketSwitch() eq '0065') { # client sends server choice packet
		$client->{zone} = CHAR_SERVER;
		$self->fireClientZoneChange($client);
		# Character List
		SendCharacterList($self, $client, $msg, $index);
	} elsif ($packet->getPacketSwitch() eq '0066') { # client sends character choice packet
		# chosen slot
		$clientdata{$index}{mode} = unpack('C1', substr($msg, 2, 1));
		
		# '0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 v1', [qw(charID mapName mapIP mapPort)]],
		my $mapName = pack("a16", "moc_prydb1.gat");
		my $data = pack("C*", 0x71, 0x00) . $cID . $mapName . 
			pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) . $port;
		
		$client->send($data);
	} elsif ($packet->getPacketSwitch() eq '007D') { # client sends the map loaded packet
		PerformMapLoadedTasks($self, $client, $msg, $index);
		$client->{zone} = MAP_SERVER;
		$self->fireClientZoneChange($client);
	} elsif ($packet->getPacketSwitch() eq '0896') { # client sends sync packet
		my $data = pack("C*", 0x7F, 0x00) . pack("V", getTickCount);
		$client->send($data);
	} elsif ($packet->getPacketSwitch() eq '00B2') { # quit to character select screen
		SendGoToCharSelection($self, $client, $msg, $index);
		my $length = unpack("C",substr($msg,2,3));
		print "CharSelection length $length \n";
	} elsif ($packet->getPacketSwitch() eq '0187') { # accountid sync (what does this do anyway?)
		$client->send($msg);
	} elsif ($packet->getPacketSwitch() eq '018A') { # client sends quit packet
		$client->{requestedQuit} = 1;
		SendQuitGame($self, $client, $msg, $index);
	} elsif ($packet->getPacketSwitch() eq '09D0') { # new bRO gameGuard packet response
		my $length = unpack("v",substr($msg,2,2));
		# print sprintf("Packetlength : %s/%s \n", $length, length($msg));
		assert(length($msg), 20);
		# send with original packetID
		
		$client->{response} = pack("v", 0x9D0) . substr($msg,2,$length);
		$client->{query_state} = Hades::RagnarokServer::Client::REPLIED;
		# print "RO Client state now $client->{query_state} \n";


	} elsif ($packet->getPacketSwitch() eq '008C') { # chat
		my $charname = 'NoName';
		my $command = substr($msg, 4+length($charname)+2, -1);
		print "Client sent chat: $command\n";
		if ($command eq 'sendme 0081') {
			print 
			SendSystemChatMessage($self, $client, $msg, $index, "[GM] Hades: I'm sending you PACKET_SC_NOTIFY_BAN Arg(0)");
			my $data = pack("v", 0x81) . pack("C1", 0);
			$client->send($data);
		} elsif ($command eq 'kickme') {
			SendGoToCharSelection($self, $client, $msg, $index);
		} elsif ($command eq 'unbind') {
			$client->{boundUsername} = undef;
			SendNotification($client, "[PoseidonServer] Unbound");
		} elsif ($command =~ /^bind (.+)/) {
			SendNotification($client, "[PoseidonServer] Binding to username ".$1);
			$client->{boundUsername} = $1;
		}
	} else {
		if ($clientdata{$index}{mode}) {
			print "\nReceived packet $packet->getPacketSwitch():\n";
			visualDump($msg, "$packet->getPacketSwitch()");
			my $data = pack("v2 a31", 0x8E, 35, "Sent packet $packet->getPacketSwitch() (" . length($msg) . " bytes).");
			$client->send($data);
		}
	}

	$client->{latestPacket} = $packet;

	if (defined $excedent) {
		$self->ParsePacket($client, $msg, $index, $excedent);
	}
	
	
	
}

sub _IsValidPacketSize {
	my $packet = shift;
	# should be already untagled and valid id
	my $packetInfo = $rpackets{$packet->getPacketSwitch()};

	if (_IsValidPacketSizeMinLength($packet) != 1) {
		return 0;
	}

	# variable length?
	if ( $packetInfo->{length} == -1 ) {
		# is variable
		if ( $packet->getLength() != _GetVarPacketLen($packet) ) {
			my $message = "Packet with variable length error:\n";
			$message .= "Switch: ".$packet->getPacketSwitch()."\n";
			$message .= "Packet: $packet \n";
			$message .= "Dump: ".unpack("H*", $packet->getData())."\n";
				$message .= "Dump Raw: ".unpack("H*", $packet->getRawData())."\n";
			$message .= sprintf("\tLength: Expected %d, got %d\n", _GetVarPacketLen($packet), $packet->getLength() );
			$message .= sprintf("\tDump: $packet->getPacketSwitch()\n", unpack("H*", $packet->getData() ));
			my ($package, $filename, $line) = caller;
			$message .= "$package, $line \n";		

			Hades::Logger::logLines(split("\n", $message));
			return 0;
		}

		return 1;
	} else {
		# is fixed
		if ( $packet->getLength() != $packetInfo->{length} ) {
			my $message = "Packet with fixed length error:\n";
			$message .= "Switch: ".$packet->getPacketSwitch()."\n";
			$message .= "Packet: $packet \n";
			$message .= "Dump: ".unpack("H*", $packet->getData())."\n";
			$message .= "Dump Raw: ".unpack("H*", $packet->getRawData())."\n";
			$message .= sprintf( "\tLength: Expected %d, got %d\n", $packetInfo->{length}, $packet->getLength() );
			$message .= Dumper($packet);
			my ($package, $filename, $line) = caller;
			$message .= "$package, $line \n";		
			Hades::Logger::logLines(split("\n", $message));

			return 0;
		}

		return 1;
	}

	return 1;
}

sub _IsValidPacketSizeMinLength {
	my $packet = shift;
	my $packetInfo = $rpackets{ $packet->getPacketSwitch() };

	# is minimum length available?
	if ($packetInfo->{minlength} != 0 && defined($packetInfo->{minlength}) && $packetInfo->{minlength} != undef) {
		if ( $packet->getLength() < $packetInfo->{minlength} ) {
			my $message = "Packet has less than minimum size:\n";
			$message .= "Switch: ".$packet->getPacketSwitch()."\n";
			$message .= "Packet: $packet \n";
			$message .= "Dump: ".unpack("H*", $packet->getData())."\n";
			$message .= "Dump Raw: ".unpack("H*", $packet->getRawData())."\n";
			$message .= sprintf( "\tLength: Expected at least %d, got %d\n", $packetInfo->{minlength}, $packet->getLength() );

			my ($package, $filename, $line) = caller;
			$message .= "$package, $line \n";		
			

			Hades::Logger::logLines(split("\n", $message));

			return 0;
		}
	}

	return 1;
}

sub _GetRealPacketLen {
	my $packet = shift;
	my $packetInfo = $rpackets{ $packet->getPacketSwitch() };
	# variable length?
	if ( $packetInfo->{length} == -1 ) {
		# yup, variable
		return _GetVarPacketLen($packet);
	} else {
		# is fixed
		return $packetInfo->{length};
	}
}

sub _GetVarPacketLen {
	my $packet = shift;
	my $data = $packet->getData();
	# TODO: throw error when data not available
	return unpack("x2 v", $data);
}

sub _IsValidPacketID {
	my $packet = shift;

	my $switch = $packet->getPacketSwitch();
	
	if (!$rpackets{$packet->getPacketSwitch()}) {
		return 0;
	}

	return 1;
}

##
# Gets 
# $packetId : the decrypted packetid
# \$msg : a refrence to the data, all the incoming data
# \$excedent : a reference to a scalar that will hold the new data
#
# results in:
# 1) the real packet (with proper size) will remain in $msg
# 2) $data will hold the excedent data if it exists, undef otherwise
#
# usage: 
# $self->Detangle($packet_id, \$msg, \$excedent);
##
sub Detangle {
	my ($self, $packet) = @_;

	# return undef unless _IsValidPacketID( $packet );

	my $realLen = _GetRealPacketLen( $packet );

	# print "Next packet should be $realLen \n";
	# check for tangled packets
	if ($packet->getLength() > $realLen) {
		my $excedent = new Hades::Packet();
		$excedent->setRawData( $packet->getRawData() );
		$excedent->setData( substr( $packet->getData(), $realLen ) );

		$packet->setData( substr( $packet->getData(), 0, $realLen ) );

		return $excedent;
	}

	return undef;
}

sub SendNotification {
	my ($client, $msg) = @_;
	# id length msg
	my $length = length($msg) + 4 + 1;
	my $data = pack("v2 a".($length - 4), 0x8E, $length, $msg);

	$client->send($data);

}

# PACKET SENDING S->C

sub SendCharacterList {
	my ($self, $client, $msg, $index) = @_;
	
	# Log
	# print "Requested Char List (Standard)\n";
	
	# Wanted Block Size
	my $blocksize = $self->{type}->{ Hades::Config::get("ServerType") }->{charBlockSize} || 116; #defaults to 116

	# Packet Len, Total Characters and Total Slots
	my $totalchars = 2;
	my $totalslots = 12;
	my $len = $blocksize * $totalchars;
	
	# Character Block Pack String
	my $packstring = '';

	$packstring = 'a4 V9 v V2 v14 Z24 C8 v Z16 x4 x4' if $blocksize == 136;
	$packstring = 'a4 V9 v V2 v14 Z24 C8 v Z16 x4' if $blocksize == 132;
	$packstring = 'a4 V9 v V2 v14 Z24 C8 v Z16' if $blocksize == 128;
	$packstring = 'a4 V9 v V2 v14 Z24 C8 v Z12' if $blocksize == 124;
	$packstring = 'a4 V9 v V2 v14 Z24 C6 v2 x4' if $blocksize == 116;
	$packstring = 'a4 V9 v V2 v14 Z24 C6 v2' if $blocksize == 112;
	$packstring = 'a4 V9 v17 Z24 C6 v2' if $blocksize == 108;
	$packstring = 'a4 V9 v17 Z24 C6 v' if $blocksize == 106;
	
	# Unknown CharBlockSize
	if ( length($packstring) == 0 ) { print "Unknown CharBlockSize : $blocksize\n"; return; }
	
	# Character Block Format
	my($cID,$exp,$zeny,$jobExp,$jobLevel,$opt1,$opt2,$option,$stance,$manner,$statpt,$hp,$maxHp,$sp,$maxSp,$walkspeed,$jobId,$hairstyle,$weapon,$level,$skillpt,$headLow,$shield,$headTop,$headMid,$hairColor,$clothesColor,$name,$str,$agi,$vit,$int,$dex,$luk,$slot,$rename) = 0;

	# Preparing Begin of Character List Packet
	my $data;
	if ($self->{type}->{ Hades::Config::get("ServerType") }->{charListPacket} eq '0x82d') {
		$data = $client->{accountID} . pack("v2 C5 a20", 0x82d, $len + 29,$totalchars,0,0,0,$totalchars,-0); # 29 = v2 C5 a20 size for bRO
	} else {
		$data = $client->{accountID} . pack("v v C3", 0x6b, $len + 7, $totalslots, -1, -1);
	}
	
	# Character Block
	my $block;
	
	# Filling Character 1 Block
	$cID = $client->{charID};	$hp = 666; $maxHp = 666; $sp = 666; $maxSp = 666; $hairstyle = 1; $level = 99; $headTop = 0; $hairColor = 6;
	$name = "Hades"; $str = 1; $agi = 1; $vit = 1; $int = 1; $dex = 1; $luk = 1;	$exp = 1; $zeny = 1; $jobExp = 1; $jobLevel = 50; $slot = 0; $rename = 0;
	
	# Preparing Character 1 Block
	$block = pack($packstring,$cID,$exp,$zeny,$jobExp,$jobLevel,$opt1,$opt2,$option,$stance,$manner,$statpt,$hp,$maxHp,$sp,$maxSp,$walkspeed,$jobId,$hairstyle,$weapon,$level,$skillpt,$headLow,$shield,$headTop,$headMid,$hairColor,$clothesColor,$name,$str,$agi,$vit,$int,$dex,$luk,$slot,$rename);

	# Attaching Block
	$data .= $block;
	
	# Filling Character 2 Block
	$cID = $client->{charID};	$hp = 10000; $maxHp = 10000; $sp = 10000; $maxSp = 10000; $hairstyle = 1; $level = 99; $headTop = 0; $hairColor = 6;
	$name = "Developer Mode"; $str = 1; $agi = 1; $vit = 1; $int = 1; $dex = 1; $luk = 1;	$exp = 1; $zeny = 1; $jobExp = 1; $jobLevel = 50; $slot = 1; $rename = 0;
	
	# Preparing Character 2 Block
	$block = pack($packstring,$cID,$exp,$zeny,$jobExp,$jobLevel,$opt1,$opt2,$option,$stance,$manner,$statpt,$hp,$maxHp,$sp,$maxSp,$walkspeed,$jobId,$hairstyle,$weapon,$level,$skillpt,$headLow,$shield,$headTop,$headMid,$hairColor,$clothesColor,$name,$str,$agi,$vit,$int,$dex,$luk,$slot,$rename);		
	
	# Attaching Block
	$data .= $block;		
	
	# Measuring Size of Block
	# print sprintf ("Wanted CharBlockSize : %s - Got : %s\n", $blocksize, length($block));		

	$client->send($data);
}

sub SendMapLogin {
	my ($self, $client, $msg, $index) = @_;

	# '0073' => ['map_loaded','x4 a3',[qw(coords)]]
	my $data;
	
	#if ( Hades::Config::get("ServerType") !~ /^bRO/ ) { $data .= $client->{accountID}; } #<- This is Server Type Based !!
	#$data .= pack("v", 0x73) . pack("V", getTickCount) . getCoordString($posX, $posY, 1) . pack("C*", 0x05, 0x05);
	$data .= pack("v", 0x2EB) . pack("V", getTickCount) . getCoordString($posX, $posY, 1) . pack("C*", 0x05, 0x05) .  pack("C*", 0x05, 0x05);
	#print "Datasize: ".length($data)."\n";
	$client->send($data);
	
	$client->{connectedToMap} = 1;	
}

sub SendGoToCharSelection {
	my ($self, $client, $msg, $index) = @_;
	
	# Log	
	print "Requested Char Selection Screen\n";	
	
	$client->send(pack("v v", 0xB3, 1));

	$client->{cryptKey} = undef;
	$client->{zone} = CHAR_SERVER;
	$self->fireClientZoneChange($client);
}

sub SendQuitGame {
	my ($self, $client, $msg, $index) = @_;
	
	# Log
	print "Requested Quit Game...\n";
	
	$client->send(pack("v v", 0x18B, 0));	
}

sub SendLookTo {
	my ($self, $client, $msg, $index, $ID, $to) = @_;
	
	# Make Poseidon look to front
	$client->send(pack('v1 a4 C1 x1 C1', 0x9C, $ID, 0, $to));
}

sub SendUnitInfo {
	my ($self, $client, $msg, $index, $ID, $name) = @_;
	
	# Let's not wait for the client to ask for the unit info
	# '0095' => ['actor_info', 'a4 Z24', [qw(ID name)]],
	$client->send(pack("v1 a4 a24", 0x95, $ID, $name));
}

sub SendSystemChatMessage {
	my ($self, $client, $msg, $index, $message) = @_;
	
	# '009A' => ['system_chat', 'v Z*', [qw(len message)]],
	$client->send(pack("v2 a".length($message), 0x9A, length($message)+4, $message));
}

sub SendAccountID {
	my ($self, $client, $msg, $index) = @_;
	
	# '009A' => ['system_chat', 'v Z*', [qw(len message)]],
	$client->send(pack("v a4", 0x283, $client->{accountID}));
}

sub SendShowNPC {
	my ($self, $client, $msg, $index, $obj_type, $GID, $SpriteID, $X, $Y, $MobName) = @_;
	
	# Packet Structure
	my ($object_type,$NPCID,$walk_speed,$opt1,$opt2,$option,$type,$hair_style,$weapon,$lowhead,$shield,$tophead,$midhead,$hair_color,$clothes_color,$head_dir,$guildID,$emblemID,$manner,$opt3,$stance,$sex,$xSize,$ySize,$lv,$font,$name) = 0;

	# Building NPC Data
	$object_type = $obj_type;
	$NPCID = $GID;
	$walk_speed = 0x1BD;
	$type = $SpriteID;
	$lv = 1;
	$name = $MobName;
	
	# '0856' => ['actor_exists', 'v C a4 v3 V v11 a4 a2 v V C2 a3 C3 v2 Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font name)]], # -1 # spawning provided by try71023
	my $dbuf;
	if ( Hades::Config::get("ServerType") !~ /^bRO/ ) { $dbuf .= pack("C", $object_type); } #<- This is Server Type Based !!
	$dbuf .= pack("a4 v3 V v11 a4 a2 v V C2",$NPCID,$walk_speed,$opt1,$opt2,$option,$type,$hair_style,$weapon,$lowhead,$shield,$tophead,$midhead,$hair_color,$clothes_color,$head_dir,$guildID,$emblemID,$manner,$opt3,$stance,$sex);
	$dbuf .= getCoordString($X, $Y, 1);
	$dbuf .= pack("C2 v2",$xSize,$ySize,$lv,$font);
	$dbuf .= pack("Z" . length($name),$name);
	my $opcode;
	if ( Hades::Config::get("ServerType") !~ /^bRO/ ) { $opcode = 0x858; } #<- This is Server Type Based !!
	$client->send(pack("v v",$opcode,length($dbuf) + 4) . $dbuf);
}

# SERVER TASKS

sub PerformMapLoadedTasks
{
	my ($self, $client, $msg, $index) = @_;
	# Global Announce

	# SendSystemChatMessage($self, $client, $msg, $index, $banner);
	SendSystemChatMessage($self, $client, $msg, $index, sprintf("[GM] Hades: Welcome to HADES, %s", `hostname`));
	SendSystemChatMessage($self, $client, $msg, $index, sprintf("[GM] Hades: You're the client #%d", $client->getIndex()));
}

sub parseRecvpackets {
	my ($file, $r_hash) = @_;

	%{$r_hash} = ();
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/\x{FEFF}//g;
		next if ($line =~ /^#/);
		$line =~ s/[\r\n]//g;
		next if (length($line) == 0);

		my ($key, $length, $minlength) = split / /, $line, 4;
		$key =~ s/^(0x[0-9a-f]+)$/hex $1/e;
		$r_hash->{$key}{length} = $length;
		$r_hash->{$key}{minlength} = $minlength;
	}
	close FILE;
	
	return 1;
}

sub isDebugging {
	my $self = shift;
	return $self->{debug};
}

1;

