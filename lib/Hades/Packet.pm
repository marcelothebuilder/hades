package Hades::Packet;
use strict;


use overload
    '""' => \&toString;

sub new {
	my $class = shift;
	$class = ref $class if ref $class;

	my $self = bless {}, $class;
	$self;
}

sub setRawData {
	my $self = shift;
	$self->{_raw_data} = shift;
}

sub getRawData {
	my $self = shift;
	return $self->{_raw_data};
}

sub setData {
	my $self = shift;
	$self->{_data} = shift;
}

sub getData {
	my $self = shift;
	if (!defined $self->{_data}) {
		return $self->{_raw_data};
	} else {
		return $self->{_data};
	}
}

sub getPacketId {
	my $self = shift;
	if (defined $self->{_decryptionKey}) {
		return $self->{_decryptionKey} ^ $self->getRawPacketId();
	}

	return $self->getRawPacketId();
}

sub setDecryptionKey {
	my $self = shift;
	$self->{_decryptionKey} = shift;
}

sub getRawPacketId {
	my $self = shift;
	return unpack( "v", $self->getData() );
}

sub getPacketSwitch {
	my $self = shift;

	return sprintf( "%04X", $self->getPacketId() );
}

sub getLength {
	my $self = shift;
	return length( $self->getData() );
}

sub isDetangled {
	my $self = shift;
	return $self->getLength() != length( $self->getRawData() );
}

sub toString {
	my $self = shift;

	my $msg = sprintf("Packet=switch:%s;decrypted:%s;length:%d;detangled:%s",
		$self->getPacketSwitch(),
		defined $self->{_decryptionKey} ? "yes" : "no",
		$self->getLength(),
		$self->isDetangled() ? "yes" : "no"
	);

	return $msg;
}

1;