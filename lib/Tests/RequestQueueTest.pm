package Hades::Tests::RequestQueue;
use strict;

# libs
use FindBin qw($RealBin);
use lib "$RealBin/..";

use Test::More qw(no_plan);
use Hades::RequestServer::RequestQueue;
use Hades::RequestServer::Request;
use Data::Dumper;

{
	# test with no priority
	my $RequestQueue = new Hades::RequestServer::RequestQueue();

	is ($RequestQueue->getSize(), 0, "0 length queue test" );

	my $ReqObject1 = getRequest();
	$RequestQueue->add($ReqObject1);

	is ($RequestQueue->getSize(), 1, "1 length queue test" );


	$RequestQueue->add(getRequest());

	is ($RequestQueue->getSize(), 2, "2 length queue test" );


	for (my $i = 0; $i < $RequestQueue->getSize() && $i < 5; $i++) {
		is (defined $RequestQueue->getItems()->[$i], 1, "test if object $i is defined");
	}


	$RequestQueue->remove($ReqObject1);

	is ($RequestQueue->getSize(), 1, "1 length queue (removal) test" );
}


{

	# test priority
	my $RequestPriorityQueue = new Hades::RequestServer::RequestQueue();
	$RequestPriorityQueue->add( new Hades::RequestServer::Request(undef, undef, "Garbage", 2) );
	$RequestPriorityQueue->add( new Hades::RequestServer::Request(undef, undef, "Garbage", 1) );

	is ($RequestPriorityQueue->getItems()->[0]->getIndex(), 1, "item in lower queue positon should have greater or equal index then the precedent");

	is ($RequestPriorityQueue->getItems()->[1]->getIndex(), 2, "item in lower queue positon should have greater or equal index then the precedent");

}

# exit();

{
	# test priority
	my $RequestPriorityQueue = new Hades::RequestServer::RequestQueue();

	for (my $var = 0; $var < 20; $var++) {
		my $index = int(rand(20));
		$RequestPriorityQueue->add( new Hades::RequestServer::Request(undef, time, time, $index) );
	}

	for (my $i = 1; $i < $RequestPriorityQueue->getSize(); $i++) {
		ok (
			($RequestPriorityQueue->getItems()->[$i]->getIndex() >= $RequestPriorityQueue->getItems()->[$i - 1]->getIndex(),
			"item in lower queue positon should have greater or equal index then the precedent"
		);
	}
}


sub getRequest {
	my $Request = new Hades::RequestServer::Request(undef, undef, "Garbage", 5);
	return $Request;
}