package Hades::Task::Reaper;

use strict;
use warnings;
use Misc;
use Utils;
use Poseidon::RagnarokServer;
use Carp::Assert;

sub new {
	my $class = shift;
	$class = ref $class if ref $class;
	my $self = bless {}, $class;

	$self->{roServer} = shift;

	print sprintf("[HADES Reaper]-> Reaper will take to hell those who sleeps more than %d secs.\n", Hades::Config::get("ReaperTime"));

	# assert(Hades::Config::get("ReaperTime") > 0);

	return $self;
}

sub iterate {
	my $self = shift;

	return if Hades::Config::get("ReaperTime") < 1;

	# assert( !1 && Hades::Config::get("ReaperTime") < 1 );

	my $clients = $self->{roServer}->clients();

	foreach my $client (@{$clients}) {
		if ($client && $client->{boundUsername} && time > ($client->{last_request} + Hades::Config::get("ReaperTime")) ) {
			print sprintf("[HADES Reaper]-> Reaping dead bound between client #%s and $client->{boundUsername}\n", $client->getIndex() );
			$client->{boundUsername} = undef;
		}
	}
	
}

1;