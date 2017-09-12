package Hades::ThirdParty::Pushover;
use strict;
use LWP::UserAgent;

sub new {
	my $class = shift;
	$class = ref $class if ref $class;
	my $self = bless {}, $class;

	$self->{appToken} = shift;
	$self->{userKey} = shift;
	$self->{message} = shift; # optional

	$self->{priority} = 0;

	$self->{title} = "HADES Message";

	return $self;
}

sub setTitle {
	my $self = shift;
	my $title = shift;
	$self->{title} = $title;
}

sub setPriority {
	my $self = shift;
	$self->{priority} = shift;
}

sub setMessage {
	my $self = shift;
	$self->{message} = shift;
}

sub send {
	my $self = shift;
	
	print "[HADES Pushover]-> Sending notification. \n";
	
	LWP::UserAgent->new()->post(
	  'https://api.pushover.net/1/messages.json' , [
	  "token" => $self->{appToken},
	  "user" => $self->{userKey},
	  "message" => $self->{message},
	  "title" => $self->{title},
	  "priority" => $self->{priority}
	]);
}

1;