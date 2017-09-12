package Poseidon::Config;

use strict;
require Exporter;  

our @ISA = qw(Exporter);  
our @EXPORT=qw(%config);

our %config = ();
 
# Function to Parse the Environment Variables
sub parse_config_file 
{
    my ($config_line, $Name, $Value, $Config);

    warn "Using (deprecated) Poseidon::Config\n";
    my ($File, $Config) = @_;
    open (CONFIG, "../../conf/$File") or open (CONFIG, "./conf/$File") or die "ERROR: Config file not found : $File\n";
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