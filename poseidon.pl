package Poseidon;

use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/";
use lib "$RealBin/lib/";
use lib "$RealBin/lib/Openkore/";
use lib "$RealBin/lib/Openkore/deps/";

use Time::HiRes qw(time sleep);
use Hades::Config;

use Poseidon::RagnarokServer;
use Poseidon::QueryServer;
use Hades::ServerController;

use Hades::Task::Reaper;
use Hades::Task::Reconfig;
use Hades::Task::Title;
use Hades::TimedTasker;
use Hades::Logger;

use Win32::Console;
use POSIX 'strftime';

use IO::Handle;
STDERR->autoflush(1);
STDOUT->autoflush(1);

$SIG{PIPE} = sub { die "Aborting on SIGPIPE\n" };
$SIG{QUIT} = sub { die "Aborting on SIGQUIT\n" };
*STDERR = *STDOUT;


use constant SLEEP_TIME => 0.005;

# our ($roServer, $queryServer);
use Win32::Console; 
my $CONSOLE=Win32::Console->new;

Hades::Logger::setLogFolder('./logs/');
Hades::Logger::logLine("Starting hades.");

sub print_banner {
	my ($ro, $qe, $st) = @_;
	open (my $fh, "<", 'hades.banner');
	while (<$fh>) {
		$_ =~ s/{RoServer}/$ro/;
		$_ =~ s/{RoServerType}/$st/;
		$_ =~ s/{QueryServer}/$qe/;
		print $_;
	}
	close $fh;
	print "\n";
}

sub __start {

	# Loading Configuration
	Hades::Config::load ("conf/poseidon.txt");

	# Starting Poseidon
	my $roServer = new Poseidon::RagnarokServer(
		Hades::Config::get("RagnarokServerPort"),
		Hades::Config::get("RagnarokServerIp")
	);

	my $queryServer = new Poseidon::QueryServer(
		Hades::Config::get("QueryServerPort"),
		Hades::Config::get("QueryServerIp"),
		$roServer
	);

	
	my $roInfo = sprintf("RO: %s:%s",
		Hades::Config::get("RagnarokServerIp"),
		Hades::Config::get("RagnarokServerPort")
	);

	my $qeInfo = sprintf("Query: %s:%s",
		Hades::Config::get("QueryServerIp"),
		Hades::Config::get("QueryServerPort")
	);

	print_banner($roInfo, $qeInfo, Hades::Config::get("ServerType"));

	my $timedTasker = new Hades::TimedTasker();
	{
		my $reaperTask = new Hades::Task::Reaper( $roServer, Hades::Config::get("ReaperTime") );
		my $reconfigTask = new Hades::Task::Reconfig();
		my $titleTask = new Hades::Task::Title( $CONSOLE, $roServer );

		$timedTasker->registerTask( $reaperTask , Hades::Config::get("TimedTasker_Reaper") );
		$timedTasker->registerTask( $reconfigTask , Hades::Config::get("TimedTasker_Reconfig") );
		$timedTasker->registerTask( $titleTask , Hades::Config::get("TimedTasker_Title") );
	}

	my $serverController = new Hades::ServerController( $roServer, $queryServer );

	print "[HADES] >>>>>>> Server ready <<<<<<<!\n\n";

	while (1) {
		$timedTasker->iterate();
		$serverController->iterate();
		sleep Hades::Config::get("SleepTime");
	}
}


__start() unless defined $ENV{INTERPRETER};
