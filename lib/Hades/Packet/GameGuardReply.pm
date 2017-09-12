package Hades::Packet::GameGuardReply;

use constant TEMPLATE => "v v V4";

sub new {
	my $class = shift;
	$class = ref $class if ref $class;
	my $self = {};

	$self->{packetID} = shift;
	$self->{length} = shift;
	$self->{values}[0] = shift;
	$self->{values}[1] = shift;
	$self->{values}[2] = shift;
	$self->{values}[3] = shift;

	bless $self, $class;
	return $self;
}

sub getValues {
	my $self = shift;
	return $self->{values};
}

sub isSync {
	my $self = shift;
	return $self->{values}[1] == 1500064691 && $self->{values}[3] == 48557222;
}

sub fromBytes {
	my $data = shift;
	return new Hades::Packet::GameGuardReply( unpack("v v V4", $data) );
}

sub toBytes {
	my $self = shift;

	return pack ( TEMPLATE, 
		$self->{packetID},
		$self->{length},
		$self->{values}[0],
		$self->{values}[1],
		$self->{values}[2],
		$self->{values}[3],
		$self->{values}[4] );
}

1;