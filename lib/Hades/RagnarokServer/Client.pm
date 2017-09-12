package Hades::RagnarokServer::Client;

# query states
use constant {
	READY => 0,
	REQUESTING => 1,
	REQUESTED => 2,
	REPLIED => 3
};

sub new {
	my $class = shift;
	$class = ref $class if ref $class;
	my $self = bless {}, $class;
	$self;
}

1;