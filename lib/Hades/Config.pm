package Hades::Config;

use strict;

my %config = ();
my $lastFile;

my %defaults = (
    TimedTasker_Reaper => 60,
    TimedTasker_Reconfig => 90,
    TimedTasker_Title => 5,
    ReaperTime => 600,
    ServerType => 'bRO_2016-04-03a',
    RagnarokServerIp => '127.0.0.1',
    RagnarokServerPort => 6902,
    QueryServerIp => '0.0.0.0',
    QueryServerPort => 24380,
    RequestTimeout => 120,
    FirstRequestTimeout => 27,
    QueueMaxSize => 6,
    MinimumRequestInterval => 0.25,
    SleepTime => 0.005,
    SecretKey => "2be8b9b78addc5bab742fbf3b3d992df",
    TitleTemplate => 'Total clients: %1$d Free: %2$d Dead: %4$d Uptime: %3$s',

    FirstRequestExclusiveProcessing=>0,

    DeadClientNotificationTimeout=> 60*5,
    PushOverEnabled => 0
);

sub get {

    my $key = shift;
    my $val = defined($config{$key}) ? $config{$key} : $defaults{$key};
    # my $val = $defaults{$key};
    # print "Key $key -> $val\n";
    return $val;
}

sub load {
    my $file = shift;
    $lastFile = $file;
    _parse_config_file($file, \%config);
}

sub getFilePath {
    return $lastFile;
}

sub reload {
    load($lastFile);
}
 
# Function to Parse the Environment Variables
sub _parse_config_file 
{
    my ($config_line, $Name, $Value, $Config);
    my ($File, $Config) = @_;
    %{$Config} = ();
    open (CONFIG, "$File") or die "ERROR: Config file not found : $File\n";
    while (<CONFIG>) {
        $config_line=$_;
        chomp ($config_line);											# Remove trailling \n
        $config_line =~ s/^\s*//;										# Remove spaces at the start of the line
        $config_line =~ s/\s*$//;     									# Remove spaces at the end of the line
        if ( ($config_line !~ /^#/) && ($config_line ne "") ){  		# Ignore lines starting with # and blank lines
            ($Name, $Value) = split (/=/, $config_line);        		# Split each line into name value pairs
            $$Config{$Name} = $Value;                           		# Create a hash of the name value pairs
        }
    }
    close(CONFIG);
}

1;