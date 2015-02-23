package AN::Configure;
#
# This contains functions related to configuring the Striker machine itself.
# 

use strict;
use warnings;
use IO::Handle;
use AN::Cluster;
use AN::Common;

# Set static variables.
my $THIS_FILE = "AN::Configure.pm";

sub testing
{
	my ($conf) = @_;
	
	print "<pre>\n";
	my $shell_call = "$conf->{path}{'call_gather-system-info'}";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sc: [$shell_call]\n");
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		
	}
	close $file_handle;
	print "</pre>\n";
	
	
	return(0);
}


1;
