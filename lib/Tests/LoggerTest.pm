package Hades::Tests::LoggerTest;
use strict;

# libs
use FindBin qw($RealBin);
use lib "$RealBin/..";

use Test::More qw(no_plan);
use Hades::Logger;
use Data::Dumper;

print Hades::Logger::logLine("Bot off.");
Hades::Logger::setLogFolder("../");
print Hades::Logger::logLines("Bot off.", "Bot off 1.", "Bot off 2.", "Bot off 3.");

print "\n\nEnd.\n\n";