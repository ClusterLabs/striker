package AN::Tools::Cman;
# 
# This package is used for things specific to RHEL 6's cman + rgmanager cluster stack.
# 

use strict;
use warnings;
use IO::Handle;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Cman.pm";

sub new
{
	my $class = shift;
	
	my $self  = {};
	
	bless $self, $class;
	
	return ($self);
}

# Get a handle on the AN::Tools object. I know that technically that is a sibling module, but it makes more
# sense in this case to think of it as a parent.
sub parent
{
	my $self   = shift;
	my $parent = shift;
	
	$self->{HANDLE}{TOOLS} = $parent if $parent;
	
	return ($self->{HANDLE}{TOOLS});
}

# This looks takes the local hostname and the cluster.conf data to figure out what the peer's host name is.
sub peer_hostname
{
	my $self = shift;
	my $an   = $self->parent;
	
	my $peer_hostname = "";
	my $hostname      = $an->hostname();
	#print "$THIS_FILE ".__LINE__."; hostname: [$hostname]\n";
	
	# Read in cluster.conf. if necessary
	$an->Cman->_read_cluster_conf();
	
	my $nodes = [];
	foreach my $index1 (@{$an->data->{cman_config}{data}{clusternodes}})
	{
		#print "$THIS_FILE ".__LINE__."; index1: [$index1]\n";
		foreach my $key (sort {$a cmp $b} keys %{$index1})
		{
			#print "$THIS_FILE ".__LINE__."; key: [$key]\n";
			if ($key eq "clusternode")
			{
				foreach my $node (sort {$a cmp $b} keys %{$index1->{$key}})
				{
					#print "$THIS_FILE ".__LINE__."; node: [$node]\n";
					push @{$nodes}, $node;
				}
			}
		}
	}
	
	my $found_myself = 0;
	foreach my $node (sort {$a cmp $b} @{$nodes})
	{
		if ($node eq $hostname)
		{
			$found_myself = 1;
		}
		else
		{
			$peer_hostname = $node;
		}
	}
	
	# Only trust the peer hostname if I found myself.
	if ($found_myself)
	{
		if ($peer_hostname)
		{
			# Yay!
			#print "$THIS_FILE ".__LINE__."; peer_hostname: [$peer_hostname]\n";
		}
		else
		{
			# Found myself, but not my peer.
			$an->Alert->error({fatal => 1, title_key => "error_title_0025", message_key => "error_message_0045", message_variables => { file => $an->data->{path}{cman_config} }, code => 42, file => "$THIS_FILE", line => __LINE__});
			# Return nothing in case the user is blocking fatal errors.
			return (undef);
		}
	}
	else
	{
		# I didn't find myself, so I can't trust the peer was found or is accurate.
		$an->Alert->error({fatal => 1, title_key => "error_title_0025", message_key => "error_message_0046", message_variables => { file => $an->data->{path}{cman_config} }, code => 46, file => "$THIS_FILE", line => __LINE__});
		# Return nothing in case the user is blocking fatal errors.
		return (undef);
	}
	
	return($peer_hostname);
}

# This returns the short hostname for the machine this is running on. That is to say, the hostname up to the 
# first '.'.
sub peer_short_hostname
{
	my $self = shift;
	my $an   = $self->parent;
	
	my $peer_short_hostname =  $an->Cman->peer_hostname();
	   $peer_short_hostname =~ s/\..*$//;
	
	return($peer_short_hostname);
}

# This reads cluster.conf to find the cluster name.
sub cluster_name
{
	my $self = shift;
	my $an   = $self->parent;
	
	# Read in cluster.conf. if necessary
	$an->Cman->_read_cluster_conf();
	
	my $cluster_name = $an->data->{cman_config}{data}{name};
	
	return($cluster_name);
}

# This reads in cluster.conf if needed.
sub _read_cluster_conf
{
	my $self = shift;
	my $an   = $self->parent;
	
	my $cman_file = $an->data->{path}{cman_config};
	if (not exists $an->data->{cman_config}{'read'})
	{
		my $cman_hash               = {};
		   $an->data->{cman_config} = $cman_hash;
		if (not $an->Storage->read_xml_file({file => $cman_file, hash => $an->data->{cman_config}}))
		{
			# Failed to read the config. The Storage module should have exited, but in case fatal errors
			# are suppressed, return 'undef'.
			return (undef);
		}
		$an->data->{cman_config}{'read'} = 1;
	}
	
	return($an->data->{cman_config});
}

1;
