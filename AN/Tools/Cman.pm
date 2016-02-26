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

### TODO: For now, this requires being invoked on the node.
# This boots a server and tries to handle common errors. It will boot on the healthiest node if one host is
# not ready (ie: The VM's backing storage is on a DRBD resource that is Inconsistent on one of the nodes).
# Returns:
# - 0 = It was booted
# - 1 = It was already running
# - 2 = It wasn't found on the cluster
# - 3 = It was found but failed to boot.
sub boot_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $server = $parameter->{server} ? $parameter->{server} : "";
	my $node   = $parameter->{node}   ? $parameter->{node}   : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "server", value1 => $server, 
		name2 => "node",   value2 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If we weren't given a server name, then why were we called?
	if (not $server)
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0059", code => 59, file => "$THIS_FILE", line => __LINE__});
	}
	
	# Get a list of servers on the system.
	my $server_found      = 0;
	my $server_state      = "";
	my $server_uuid       = "";
	my ($servers, $state) = $an->Cman->get_cluster_server_list();
	foreach my $server_name (sort {$a cmp $b} keys %{$state})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "server_name", value1 => $server_name, 
			name2 => "server",      value2 => $server, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($server_name eq $server)
		{
			$server_found = 1;
			$server_state = $state->{$server_name};
			$server_uuid  = $an->data->{server_name}{$server_name}{uuid};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "server_found", value1 => $server_found, 
				name2 => "server_state", value2 => $server_state, 
				name3 => "server_uuid",  value3 => $server_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Did we find it?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "server_found", value1 => $server_found, 
	}, file => $THIS_FILE, line => __LINE__});
	if (not $server_found)
	{
		# We're done.
		return(2);
	}
	
	### TODO: Check with 'virsh' on both nodes. If it's running on either, immediately start it on that
	###       node.
	# Is it already running?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "state->{$server}", value1 => $state->{$server}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($state->{$server} =~ /start/)
	{
		# Yup
		return(1);
	}
	
	# If we're still alive, we're going to try and start it now. Start by getting the information about 
	# the server so that we can be smart about it.
	
	# Get the server's data, the cluster config, and the general LVM and DRBD data so that we can 
	# determine where best to boot the server.
	my $server_data    = $an->Get->server_data({server => $server});
	my $lvm_data       = $an->Get->lvm_data();
	my $cluster_data   = $an->Get->cluster_conf_data();
	my $drbd_data      = $an->Get->drbd_data();
	my $nodes          = {};
	my $my_host_name   = "";         
	my $peer_host_name = "";         
	
	# Get the cluster names for node 1 and 2.
	foreach my $node (sort {$a cmp $b} keys %{$cluster_data->{node}})
	{
		$nodes->{$node}{healthy}       = "";
		$nodes->{$node}{storage_ready} = 0;
		$nodes->{$node}{preferred}     = 0;
		$nodes->{$node}{'local'}       = 0;
		if (($node eq $an->hostname) or ($node eq $an->short_hostname))
		{
			$nodes->{$node}{'local'} = 1;
			$my_host_name            = $node;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "my_host_name", value1 => $my_host_name, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			$peer_host_name = $node;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "peer_host_name", value1 => $peer_host_name, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# What is the preferred node given the failover domain?
	my $failoverdomain = $cluster_data->{server}{$server}{domain};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "failoverdomain", value1 => $failoverdomain, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Which node are we?
	
	# Take the highest priority node
	foreach my $priority (sort {$a cmp $b} keys %{$cluster_data->{failoverdomain}{$failoverdomain}{priority}})
	{
		my $node = $cluster_data->{failoverdomain}{$failoverdomain}{priority}{$priority};
		$nodes->{$node}{preferred} = 1;
		last;
	}
	
	# Look at storage
	my $device_type = "disk";
	foreach my $target_device (sort {$a cmp $b} keys %{$server_data->{storage}{$device_type}{target_device}})
	{
		my $backing_device = $server_data->{storage}{$device_type}{target_device}{$target_device}{backing_device};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "server",         value1 => $server, 
			name2 => "backing_device", value2 => $backing_device, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Find what PV(s) the backing device is on. Comma-separated list of PVs that this LV spans.
		# Usually only one device.
		my $on_devices = $lvm_data->{logical_volume}{$backing_device}{on_devices};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "on_devices", value1 => $on_devices, 
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $device (split/,/, $on_devices)
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "device", value1 => $device, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Check to see if this device is UpToDate on both nodes. If a node isn't, it will not
			# be a boot target.
			my $resource = $drbd_data->{device}{$device}{resource};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "resource", value1 => $resource, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Check the state of the backing device on both nodes.
			my $local_disk_state = $drbd_data->{resource}{$resource}{my_disk_state};
			my $peer_disk_state  = $drbd_data->{resource}{$resource}{peer_disk_state};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "local_disk_state", value1 => $local_disk_state, 
				name2 => "peer_disk_state",  value2 => $peer_disk_state, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($local_disk_state != /UpToDate/i)
			{
				$nodes->{$my_host_name}{storage_ready} = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "nodes->${my_host_name}::storage_ready", value1 => $nodes->{$my_host_name}{storage_ready}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($peer_disk_state != /UpToDate/i)
			{
				$nodes->{$peer_host_name}{storage_ready} = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "nodes->${peer_host_name}::storage_ready", value1 => $nodes->{$peer_host_name}{storage_ready}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Check the node health files and log what we've found.
	foreach my $node (sort {$a cmp $b} keys %{$nodes})
	{
		my $short_host_name =  $node;
		   $short_host_name =~ s/\..*$//;
		my $health_file     = $an->data->{path}{status}."/.".$short_host_name;
		if (-e $health_file)
		{
			my $shell_call = $health_file;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call, 
			}, file => $THIS_FILE, line => __LINE__});
			open (my $file_handle, "<$shell_call") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0016", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				$nodes->{$node}{healthy} = ($line =~ /health = (.*)$/)[0];
			}
			close $file_handle;
		}
		
		# Report
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "${node}::healthy",       value1 => $nodes->{$node}{healthy}, 
			name2 => "${node}::storage_ready", value2 => $nodes->{$node}{storage_ready}, 
			name3 => "${node}::preferred",     value3 => $nodes->{$node}{preferred}, 
			name4 => "${node}::local",         value4 => $nodes->{$node}{'local'}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return(0);
}

# This returns an array reference of the servers found on this Anvil!
sub get_cluster_server_list
{
	my $self      = shift;
	my $an        = $self->parent;
	
	my $servers = [];
	my $state   = {};
	my $shell_call = $an->data->{path}{clustat};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
	while(<$file_handle>)
	{
		chomp;
		my $line =  $_;
		   $line =~ s/^\s+//;
		   $line =~ s/\s+$//;
		   $line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /vm:(.*?) .*? (.*)$/)
		{
			my $server = $1;
			my $status = $2;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "server", value1 => $server, 
				name2 => "status", value2 => $status, 
			}, file => $THIS_FILE, line => __LINE__});
			
			push @{$servers}, $server;
			$state->{$server} = $status;
		}
	}
	close $file_handle;
	
	return($servers, $state);
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
