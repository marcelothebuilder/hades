package Hades::RequestServer::RequestQueue;
use strict;
use Carp::Assert;

sub new {
	my $class = shift;
	$class = ref $class if ref $class;
	my $self = bless {}, $class;
	$self->{RequestArray} = [];
	$self;
}

sub add {
	my ($self, $request) = @_;
	assert($request);
	assert(defined($request));
	
	# find the best place where (i - 1).index > i.index > (i + 1).index
	my $insertionPoint = undef;
	for (my $i = 0; $i < $self->getSize(); $i++) {
		my $listRequestItem = $self->getItems()->[$i];
		if ( $listRequestItem->getIndex() > $request->getIndex() ) {
			$insertionPoint = $i;
			last;
		}
	}

	if (defined($insertionPoint)) {
		splice @{ $self->{RequestArray} }, $insertionPoint, 0, $request;	
	} else {
		push @{ $self->{RequestArray} }, $request;	
	}
	
}

sub remove {
	my $self = shift;
	my $request = shift;
	assert($request);
	assert(defined $request);
	for (my $i = 0; $i < @{$self->{RequestArray}}; $i++) {
		my $arrayItem = @{$self->{RequestArray}}[$i];
		if ($arrayItem eq $request) {
			splice @{$self->{RequestArray}}, $i, 1;
			return 1;
		}
	}
	return 0;
}

sub getItems {
	my $self = shift;
	return $self->{RequestArray};
}

sub getSize {
	my $self = shift;
	return scalar @{$self->{RequestArray}};
}

1;