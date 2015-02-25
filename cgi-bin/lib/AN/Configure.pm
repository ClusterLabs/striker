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

# Check the OS
sub verify_local_os
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; verify_os()\n");
	
	my $shell_call = "$conf->{path}{'redhat-release'}";
	record($conf, "$THIS_FILE ".__LINE__."; Reading: [$shell_call]\n");
	open (my $file_handle, "<", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to read: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line =  $_;
		
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
		if ($line =~ /^(.*?) release (\d+)\.(.*)/)
		{
			my $brand = $1;
			my $major = $2;
			my $minor = $3;
			# CentOS uses 'CentOS Linux release 7.0.1406 (Core)', 
			# so I need to parse off the second '.' and whatever 
			# is after it.
			$minor =~ s/\..*$//;
			
			# Some have 'x.y (Final)', this strips that last bit off.
			$minor =~ s/\ \(.*?\)$//;
			$conf->{striker}{os}{brand}          = $brand;
			$conf->{striker}{os}{version}{full}  = "$major.$minor";
			$conf->{striker}{os}{version}{major} = "$major";
			$conf->{striker}{os}{version}{minor} = "$minor";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; striker::os::brand: [$conf->{striker}{os}{brand}], striker::os::version: [$conf->{striker}{os}{version}]\n");
		}
	}
	
	# If it's RHEL, see if it's registered.
	if ($conf->{striker}{os}{brand} =~ /Red Hat Enterprise Linux Server/)
	{
		# See if it's been registered already.
		$conf->{striker}{os}{registered} = 0;
		
		my $shell_call = "$conf->{path}{rhn_check}; $conf->{path}{echo} exit:\$?";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sc: [$shell_call]\n");
		open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /^exit:(\d+)$/)
			{
				my $rc = $1;
				if ($rc eq "0")
				{
					$conf->{striker}{os}{registered} = 1;
				}
			}
		}
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is registered on RHN? [$conf->{node}{$node}{os}{registered}].\n");
	}
	
	my $say_os = $conf->{striker}{os}{brand} =~ /Red Hat Enterprise Linux Server/ ? "RHEL" : $conf->{node}{$node1}{os}{brand};

	my $class   = "highlight_good_bold";
	my $message = "$say_os $conf->{striker}{os}{version}{full}";
	if ($conf->{striker}{os}{version}{major} != 6)
	{
		$class   = "highlight_bad_bold";
		$message = "--" if $message =~ /0.0/;
		$ok      = 0;
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0220!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	if (not $ok)
	{
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed", {
			message		=>	"#!string!message_0362!#",
		});
	}
	
	return($ok);
}

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
