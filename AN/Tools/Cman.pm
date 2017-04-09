package AN::Tools::Cman;
# 
# This package is used for things specific to RHEL 6's cman + rgmanager cluster stack.
# 

use strict;
use warnings;
use IO::Handle;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Cman.pm";

### Methods;
# boot_server
# check_for_pending_fence
# cluster_conf_data
# cluster_name
# find_node_in_cluster
# get_clustat_data
# get_cluster_server_list
# migrate_server
# peer_hostname
# peer_short_hostname
# stop_server
# update_cluster_conf
# withdraw_node
# _read_cluster_conf
# _recover_rgmanager
# _do_server_boot


#############################################################################################################
# House keeping methods                                                                                     #
#############################################################################################################

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


#############################################################################################################
# Provided methods                                                                                          #
#############################################################################################################

### TODO: Abort if the server is off because of a DR job (or, eventually, a migration to a new Anvil!).
### NOTE: This requires being invoked on the node.
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
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "boot_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# If requested_node is healthy, we will boot on that. If 'force' is set and both nodes are sick, 
	# we'll boot on the requested node or, if not set, the highest priority node, if storage is OK on 
	# both, or else it will boot on the UpToDate node.
	my $server         = $parameter->{server} ? $parameter->{server} : "";
	my $requested_node = $parameter->{node}   ? $parameter->{node}   : "";
	my $force          = $parameter->{force}  ? $parameter->{force}  : 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "server",         value1 => $server, 
		name2 => "requested_node", value2 => $requested_node, 
		name3 => "force",          value3 => $force, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If we weren't given a server name, then why were we called?
	if (not $server)
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0059", code => 59, file => $THIS_FILE, line => __LINE__});
	}
	
	# Get this node's cluster name
	my $anvil_data = $an->Get->local_anvil_details();
	my $anvil_name = $anvil_data->{anvil_name};
	my $anvil_uuid = $anvil_data->{anvil_uuid};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_name", value1 => $anvil_name, 
		name2 => "anvil_uuid", value2 => $anvil_uuid, 
	}, file => $THIS_FILE, line => __LINE__});
	
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
			$server_uuid  = $an->Get->server_uuid({server => $server_name, anvil => $anvil_uuid});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "server_found", value1 => $server_found, 
				name2 => "server_state", value2 => $server_state, 
				name3 => "server_uuid",  value3 => $server_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Did we find it?
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "server_found", value1 => $server_found, 
	}, file => $THIS_FILE, line => __LINE__});
	if (not $server_found)
	{
		# We're done.
		$an->Alert->warning({message_key => "warning_message_0003", message_variables => { server => $server }, quiet => 1, file => $THIS_FILE, line => __LINE__});
		return(2);
	}
	
	### TODO: Check with 'virsh' on both nodes. If it is running on either, immediately start it on that
	###       node.
	# Is it already running?
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "state->{$server}", value1 => $state->{$server}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($state->{$server} =~ /start/)
	{
		# Yup
		$an->Log->entry({log_level => 1, message_key => "tools_log_0009", message_variables => {
			server => $server,
		}, file => $THIS_FILE, line => __LINE__});
		return(1);
	}
	
	# If the state is 'failed', disable it before proceeding.
	if ($state->{$server} =~ /fail/)
	{
		# Crap...
		$an->Log->entry({log_level => 1, message_key => "tools_log_0041", message_variables => { server => $server }, file => $THIS_FILE, line => __LINE__});
		
		my $shell_call = $an->data->{path}{clusvcadm}." -d $server";
		$an->Log->entry({log_level => 1, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			$an->Log->entry({log_level => 1, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		close $file_handle;
	}
	
	### NOTE: If we're still alive, we're going to try and start it now. Start by getting the information
	###       about the server so that we can be smart about it.
	# Get the server's data, the cluster config, and the general LVM and DRBD data so that we can 
	# determine where best to boot the server.
	my $server_data    = $an->Get->server_data({server => $server});
	my $lvm_data       = $an->Get->lvm_data();
	my $cluster_data   = $an->Cman->cluster_conf_data();
	my $drbd_data      = $an->Get->drbd_data();
	my $nodes          = {};
	my $my_host_name   = "";
	my $peer_host_name = "";
	
	# Get the cluster names for node 1 and 2.
	foreach my $node (sort {$a cmp $b} keys %{$cluster_data->{node}})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node", value1 => $node, 
		}, file => $THIS_FILE, line => __LINE__});
		$nodes->{$node}{healthy}       = "";
		$nodes->{$node}{storage_ready} = 1;
		$nodes->{$node}{preferred}     = 0;
		$nodes->{$node}{'local'}       = 0;
		if (($node eq $an->hostname) or ($node eq $an->short_hostname))
		{
			$nodes->{$node}{'local'} = 1;
			$my_host_name            = $node;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "my_host_name", value1 => $my_host_name, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			$peer_host_name = $node;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "peer_host_name", value1 => $peer_host_name, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# What is the preferred node given the failover domain?
	my $failoverdomain = $cluster_data->{server}{$server}{domain};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "failoverdomain", value1 => $failoverdomain, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Take the highest priority node
	foreach my $priority (sort {$a cmp $b} keys %{$cluster_data->{failoverdomain}{$failoverdomain}{priority}})
	{
		my $node                      = $cluster_data->{failoverdomain}{$failoverdomain}{priority}{$priority};
		   $nodes->{$node}{preferred} = 1;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "node",                      value1 => $node, 
			name2 => "nodes->${node}::preferred", value2 => $nodes->{$node}{preferred}, 
		}, file => $THIS_FILE, line => __LINE__});
		last;
	}
	
	# Look at storage
	my $device_type = "disk";
	foreach my $target_device (sort {$a cmp $b} keys %{$server_data->{storage}{$device_type}{target_device}})
	{
		my $backing_device = $server_data->{storage}{$device_type}{target_device}{$target_device}{backing_device};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "server",         value1 => $server, 
			name2 => "backing_device", value2 => $backing_device, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Find what PV(s) the backing device is on. Comma-separated list of PVs that this LV spans.
		# Usually only one device.
		my $on_devices = $lvm_data->{logical_volume}{$backing_device}{on_devices};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "on_devices", value1 => $on_devices, 
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $device (split/,/, $on_devices)
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "device", value1 => $device, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Check to see if this device is UpToDate on both nodes. If a node isn't, it will not
			# be a boot target.
			my $resource = $drbd_data->{device}{$device}{resource};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "resource", value1 => $resource, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Check the state of the backing device on both nodes.
			my $local_disk_state = $drbd_data->{resource}{$resource}{my_disk_state};
			my $peer_disk_state  = $drbd_data->{resource}{$resource}{peer_disk_state};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "local_disk_state", value1 => $local_disk_state, 
				name2 => "peer_disk_state",  value2 => $peer_disk_state, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($local_disk_state !~ /UpToDate/i)
			{
				# Not safe to run locally.
				$an->Log->entry({log_level => 1, message_key => "tools_log_0010", message_variables => {
					server     => $server,
					disk       => $device, 
					disk_state => $local_disk_state, 
					resource   => $resource, 
				}, file => $THIS_FILE, line => __LINE__});
				$nodes->{$my_host_name}{storage_ready} = 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "nodes->${my_host_name}::storage_ready", value1 => $nodes->{$my_host_name}{storage_ready}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($peer_disk_state !~ /UpToDate/i)
			{
				# Not safe to run on the peer, either.
				$an->Log->entry({log_level => 1, message_key => "tools_log_0011", message_variables => {
					server     => $server,
					disk       => $device, 
					disk_state => $local_disk_state, 
					resource   => $resource, 
					peer       => $peer_host_name, 
				}, file => $THIS_FILE, line => __LINE__});
				$nodes->{$peer_host_name}{storage_ready} = 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "nodes->${peer_host_name}::storage_ready", value1 => $nodes->{$peer_host_name}{storage_ready}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Check the node health files and log what we've found.
	foreach my $node (sort {$a cmp $b} keys %{$nodes})
	{
		$nodes->{$node}{healthy} = $an->ScanCore->host_state({target => $node});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "nodes->${node}::healthy", value1 => $nodes->{$node}{healthy}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# All thing being equal, which node is preferred?
	my $preferred_node = "";
	my $secondary_node = "";
	foreach my $node (sort {$a cmp $b} keys %{$nodes})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "node",                     value1 => $node, 
			name2 => "requested_node",           value2 => $requested_node, 
			name3 => "nodes->{$node}{preferred}", value3 => $nodes->{$node}{preferred}, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($requested_node)
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "node",           value1 => $node, 
				name2 => "requested_node", value2 => $requested_node, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($node eq $requested_node)
			{
				$preferred_node = $node;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "preferred_node", value1 => $preferred_node, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		elsif ($nodes->{$node}{preferred})
		{
			$preferred_node = $node;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "preferred_node", value1 => $preferred_node, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	foreach my $node (sort {$a cmp $b} keys %{$nodes})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "node",           value1 => $node, 
			name2 => "preferred_node", value2 => $preferred_node, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($node ne $preferred_node)
		{
			$secondary_node = $node;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "secondary_node", value1 => $secondary_node, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	### Now we know which node is preferred, is it healthy?
	# If the user's requested node is healthy, boot it. If there is no requested node, see if the 
	# failover domain's highest priority node is ready. If not, is the peer? If not, sadness,
	my $booted      = 0;
	my $boot_return = "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "nodes->{$preferred_node}{storage_ready}", value1 => $nodes->{$preferred_node}{storage_ready}, 
		name2 => "nodes->{$secondary_node}{storage_ready}", value2 => $nodes->{$secondary_node}{storage_ready}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($nodes->{$preferred_node}{storage_ready})
	{
		# The preferred node's storage is healthy, so will boot here *if*:
		# - Storage is healhy (or both nodes have the same health state)
		# - Health is OK *or* both nodes are 'warning' and 'force' was used.
		# Storage is good. Are we healthy?
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "nodes->{$preferred_node}{healthy}",       value1 => $nodes->{$preferred_node}{healthy}, 
			name2 => "nodes->{$secondary_node}{storage_ready}", value2 => $nodes->{$secondary_node}{storage_ready}, 
			name3 => "nodes->{$secondary_node}{healthy}",       value3 => $nodes->{$secondary_node}{healthy}, 
			name4 => "force",                                   value4 => $force, 
		}, file => $THIS_FILE, line => __LINE__});
		if (($nodes->{$preferred_node}{healthy} eq "ok") or ($nodes->{$preferred_node}{healthy} eq $nodes->{$secondary_node}{healthy}))
		{
			# wee!
			$an->Log->entry({log_level => 1, message_key => "tools_log_0012", message_variables => {
				server => $server,
				node   => $preferred_node, 
			}, file => $THIS_FILE, line => __LINE__});
			($booted, $boot_return) = $an->Cman->_do_server_boot({
				server => $server, 
				node   => $preferred_node, 
			});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "booted", value1 => $booted, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		# Is the peer OK?
		elsif (($nodes->{$secondary_node}{storage_ready}) && ($nodes->{$secondary_node}{healthy}))
		{
			# The peer is perfectly healthy, boot there.
			$an->Log->entry({log_level => 1, message_key => "tools_log_0013", message_variables => {
				server => $server,
				node   => $secondary_node, 
			}, file => $THIS_FILE, line => __LINE__});
			($booted, $boot_return) = $an->Cman->_do_server_boot({
				server => $server, 
				node   => $secondary_node, 
			});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "booted", value1 => $booted, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		# If I was forced, boot locally.
		elsif ($force)
		{
			# OK, Go.
			$an->Log->entry({log_level => 1, message_key => "tools_log_0014", message_variables => {
				server => $server,
				node   => $secondary_node, 
			}, file => $THIS_FILE, line => __LINE__});
			($booted, $boot_return) = $an->Cman->_do_server_boot({
				server => $server, 
				node   => $preferred_node, 
			});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "booted", value1 => $booted, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# No luck
			$an->Alert->warning({message_key => "warning_message_0004", message_variables => { server => $server }, quiet => 1, file => $THIS_FILE, line => __LINE__});
		}
	}
	elsif ($nodes->{$secondary_node}{storage_ready})
	{
		# Secondary's storage is healthy, we'll boot here if our health is OK. If not, we'll boot 
		# here if we were forced.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "nodes->{$secondary_node}{healthy}", value1 => $nodes->{$secondary_node}{healthy}, 
			name2 => "force",                             value2 => $force, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($nodes->{$secondary_node}{healthy} eq "ok")
		{
			# Good enough
			$an->Log->entry({log_level => 1, message_key => "tools_log_0015", message_variables => {
				preferred_node => $preferred_node,
				secondary_node => $secondary_node,
				server         => $server,
			}, file => $THIS_FILE, line => __LINE__});
			($booted, $boot_return) = $an->Cman->_do_server_boot({
				server => $server, 
				node   => $secondary_node, 
			});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "booted", value1 => $booted, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($force)
		{
			# We've been told...
			$an->Log->entry({log_level => 1, message_key => "tools_log_0016", message_variables => {
				preferred_node => $preferred_node,
				secondary_node => $secondary_node,
				server         => $server,
			}, file => $THIS_FILE, line => __LINE__});
			($booted, $boot_return) = $an->Cman->_do_server_boot({
				server => $server, 
				node   => $secondary_node, 
			});
			$booted = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "booted", value1 => $booted, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# No luck...
			$an->Alert->warning({message_key => "warning_message_0004", message_variables => { server => $server }, quiet => 1, file => $THIS_FILE, line => __LINE__});
		}
	}
	elsif ($force)
	{
		# We'll boot on the preferred node... May his noodly appendages take mercy on our soul.
		$an->Alert->warning({title_key => "warning_title_0008", message_key => "warning_message_0005", message_variables => {
			server => $server,
		        node   => $preferred_node, 
		}, quiet => 1, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# No safe node to boot on
		$an->Alert->warning({message_key => "warning_message_0006", message_variables => { server => $server }, quiet => 1, file => $THIS_FILE, line => __LINE__});
	}
	
	### Rescan if booted.
	# 0 = Not booted
	# 1 = Booted
	# 2 = Failed to boot.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "booted", value1 => $booted, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($booted eq "1")
	{
		($servers, $state) = $an->Cman->get_cluster_server_list();
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
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "server_found", value1 => $server_found, 
					name2 => "server_state", value2 => $server_state, 
					name3 => "server_uuid",  value3 => $server_uuid, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "booted",      value1 => $booted, 
		name2 => "boot_return", value2 => $boot_return, 
	}, file => $THIS_FILE, line => __LINE__});
	return($booted, $boot_return);
}

# This checks to see if fencing is working by calling 'fence_check'
sub check_fencing
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_fencing" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target, 
		name2 => "port",   value2 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# This will be set to '0' if OK and '1' if it fails.
	my $return_code = 2;
	
	# If the 'target' is set, we'll call over SSH unless 'target' is 'local' or our hostname.
	my $shell_call = $an->data->{path}{fence_check}." -f; ".$an->data->{path}{echo}." return_code:\$?";
	my $return     = [];
	if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
	{
		### Remote calls
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
	}
	else
	{
		### Local calls
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$return}, $line;
		}
		close $file_handle;
	}
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /return_code:(\d+)/)
		{
			# 0 == OK
			# 5 == Failed
			my $rc = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "rc", value1 => $rc, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($rc eq "0")
			{
				# Passed
				$return_code = 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code, 
				}, file => $THIS_FILE, line => __LINE__});
				$an->Log->entry({log_level => 3, message_key => "log_0118", file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Failed
				$return_code = 1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code, 
				}, file => $THIS_FILE, line => __LINE__});
				$an->Log->entry({log_level => 1, message_key => "log_0119", message_variables => { return_code => $rc }, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code, 
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

### NOTE: At this time, this can only be called against the local machine.
# This uses 'fence_tool' to see if there is a pending fence. If so, it returns '1'. Otherwise it returns '0'.
sub check_for_pending_fence
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_for_pending_fence" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Sleep for 5 seconds to make sure that, if a fence is starting, fence_tool reflects it.
	sleep 5;
	
	# Now call 'fence_tool -n ls'. The '-n' isn't needed, but it might be useful is some debugging 
	# contexts.
	my $pending    = 0;
	my $shell_call = $an->data->{path}{fence_tool}." -n ls ";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
	while(<$file_handle>)
	{
		chomp;
		my $line =  $_;
		   $line =~ s/^\s+//;
		   $line =~ s/\s+$//;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^wait state\s+(.*)$/)
		{
			my $wait_state = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "wait_state", value1 => $wait_state, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if (lc($wait_state) eq "fencing")
			{
				# A fence is pending, so wait.
				$pending = 1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "pending", value1 => $pending, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	close $file_handle;
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "pending", value1 => $pending, 
	}, file => $THIS_FILE, line => __LINE__});
	return($pending);
}

# This gathers the data from a cluster.conf file. Returns '0' if the file wasn't read successfully.
sub cluster_conf_data
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "cluster_conf_data" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# This will store the LVM data returned to the caller.
	my $return   = {};
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target, 
		name2 => "port",   value2 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# These will store the output from the 'drbdadm' call and /proc/drbd data.
	my $cluster_conf_return = [];
	my $shell_call          = $an->data->{path}{cat}." ".$an->data->{path}{cman_config};
	
	# If the 'target' is set, we'll call over SSH unless 'target' is 'local' or our hostname.
	if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
	{
		### Remote calls
		# Read in drbdadm dump-xml regardless of whether the module is loaded.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $cluster_conf_return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
	}
	else
	{
		### Local calls
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$cluster_conf_return}, $line;
		}
		close $file_handle;
	}
	
	### Parsing the XML data is a little involved.
	# Convert the XML array into a string.
	my $xml_data  = "";
	my $good_data = 0;
	foreach my $line (@{$cluster_conf_return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /<\/cluster>/)
		{
			$good_data = 1;
		}
		$xml_data .= "$line\n";
	}
	
	# Did we get actual data?
	if (not $good_data)
	{
		# Sadness
		return(0);
	}
	
	# Parse the data from XML::Simple
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "xml_data", value1 => $xml_data,
	}, file => $THIS_FILE, line => __LINE__});
	if ($xml_data)
	{
		my $xml  = XML::Simple->new();
		my $data = $xml->XMLin($xml_data, KeyAttr => {node => 'name'}, ForceArray => 1);
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "data", value1 => $data,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Cluster core details
		$return->{cluster_name}    = $data->{name};
		$return->{config_version}  = $data->{config_version};
		$return->{totem}{secauth}  = $data->{totem}->[0]->{secauth};
		$return->{totem}{rrp_mode} = $data->{totem}->[0]->{rrp_mode};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "cluster_name",    value1 => $return->{cluster_name},
			name2 => "config_version",  value2 => $return->{config_version},
			name3 => "totem::secauth",  value3 => $return->{totem}{secauth},
			name4 => "totem::rrp_mode", value4 => $return->{totem}{rrp_mode},
		}, file => $THIS_FILE, line => __LINE__});
		
		# Dig out the fence devices (methods will be collected per-node)
		$return->{fence}{post_join_delay} = $data->{fence_daemon}->[0]->{post_join_delay};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "fence::post_join_delay", value1 => $return->{fence}{post_join_delay},
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $hash_ref (@{$data->{fencedevices}->[0]->{fencedevice}})
		{
			my $device_name = $hash_ref->{name};
			foreach my $variable (sort {$a cmp $b} keys %{$hash_ref})
			{
				next if $variable eq "name";
				$return->{fence}{device}{$device_name}{$variable} = $hash_ref->{$variable};
				if ($variable =~ /passw/)
				{
					$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
						name1 => "fence::device::${device_name}::${variable}", value1 => $return->{fence}{device}{$device_name}{$variable},
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "fence::device::${device_name}::${variable}", value1 => $return->{fence}{device}{$device_name}{$variable},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		
		# Dig out cluster node details. Yes, fencing is a little complicated because we have ordered
		# methods and then ordered devices within those methods.
		foreach my $hash_ref (@{$data->{clusternodes}->[0]->{clusternode}})
		{
			# One entry per node.
			my $node_name                           = $hash_ref->{name};
			   $return->{node}{$node_name}{nodeid}  = $hash_ref->{nodeid};
			   $return->{node}{$node_name}{altname} = $hash_ref->{altname}->[0]->{name} ? $hash_ref->{altname}->[0]->{name} : "";
			   $return->{node}{$node_name}{fence}   = [];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "node::${node_name}::nodeid",  value1 => $return->{node}{$node_name}{nodeid},
				name2 => "node::${node_name}::altname", value2 => $return->{node}{$node_name}{altname},
				name3 => "node::${node_name}::fence",   value3 => $return->{node}{$node_name}{fence},
			}, file => $THIS_FILE, line => __LINE__});
			for (my $i = 0; $i < @{$hash_ref->{fence}->[0]->{method}}; $i++)
			{
				$return->{node}{$node_name}{fence}->[$i]->{name}   = $hash_ref->{fence}->[0]->{method}->[$i]->{name};
				$return->{node}{$node_name}{fence}->[$i]->{method} = [];
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node_name}::fence::[$i]::name", value1 => $return->{node}{$node_name}{fence}->[$i]->{name},
				}, file => $THIS_FILE, line => __LINE__});
				for (my $j = 0; $j < @{$hash_ref->{fence}->[0]->{method}->[$i]->{device}}; $j++)
				{
					foreach my $variable (sort {$a cmp $b} keys %{$hash_ref->{fence}->[0]->{method}->[$i]->{device}->[$j]})
					{
						$return->{node}{$node_name}{fence}->[$i]->{method}->[$j]->{$variable} = $hash_ref->{fence}->[0]->{method}->[$i]->{device}->[$j]->{$variable};
						if ($variable =~ /passw/)
						{
							$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
								name1 => "node::${node_name}::fence::[$i]::method::[$j]::${variable}", value1 => $return->{node}{$node_name}{fence}->[$i]->{method}->[$j]->{$variable},
							}, file => $THIS_FILE, line => __LINE__});
						}
						else
						{
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => "node::${node_name}::fence::[$i]::method::[$j]::${variable}", value1 => $return->{node}{$node_name}{fence}->[$i]->{method}->[$j]->{$variable},
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
				}
			}
		}
		
		# Now dig out the servers.
		foreach my $hash_ref (@{$data->{rm}->[0]->{vm}})
		{
			my $server_name = $hash_ref->{name};
			foreach my $variable (sort {$a cmp $b} keys %{$hash_ref})
			{
				next if $variable eq "name";
				$return->{server}{$server_name}{$variable} = $hash_ref->{$variable};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "server::${server_name}::${variable}", value1 => $return->{server}{$server_name}{$variable},
				}, file => $THIS_FILE, line => __LINE__});
			}
			
		}
		
		# Dig out the resources.
		foreach my $resource_type (sort {$a cmp $b} keys %{$data->{rm}->[0]->{resources}->[0]})
		{
			foreach my $hash_ref (@{$data->{rm}->[0]->{resources}->[0]->{$resource_type}})
			{
				my $resource_name = $hash_ref->{name};
				foreach my $variable (sort {$a cmp $b} keys %{$hash_ref})
				{
					next if $variable eq "name";
					$return->{resource}{type}{$resource_type}{name}{$resource_name}{$variable} = $hash_ref->{$variable};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "resource::type::${resource_type}::name::${resource_name}::${variable}", value1 => $return->{resource}{type}{$resource_type}{name}{$resource_name}{$variable},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		
		# Dig out the failover domain info
		foreach my $hash_ref (@{$data->{rm}->[0]->{failoverdomains}->[0]->{failoverdomain}})
		{
			my $failoverdomain_name = $hash_ref->{name};
			foreach my $hash_ref2 (@{$hash_ref->{failoverdomainnode}})
			{
				my $priority = $hash_ref2->{priority} ? $hash_ref2->{priority} : 0;
				$return->{failoverdomain}{$failoverdomain_name}{priority}{$priority} = $hash_ref2->{name};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "failoverdomain::${failoverdomain_name}::priority::${priority}", value1 => $return->{failoverdomain}{$failoverdomain_name}{priority}{$priority},
				}, file => $THIS_FILE, line => __LINE__});
			}
			foreach my $variable (sort {$a cmp $b} keys %{$hash_ref})
			{
				next if $variable eq "name";
				next if $variable eq "failoverdomainnode";
				$return->{failoverdomain}{$failoverdomain_name}{$variable} = $hash_ref->{$variable};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "failoverdomain::${failoverdomain_name}::${variable}", value1 => $return->{failoverdomain}{$failoverdomain_name}{$variable},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Finally, dig out services... This can get complex.
		foreach my $hash_ref (@{$data->{rm}->[0]->{service}})
		{
			my $service_name = $hash_ref->{name};
			foreach my $variable (sort {$a cmp $b} keys %{$hash_ref})
			{
				next if $variable eq "name";
				# For now, we don't bother digging down this, so we'll just record and return
				# array references. The caller can handle it if they wish.
				$return->{service}{$service_name}{$variable} = $hash_ref->{$variable};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "service::${service_name}::${variable}", value1 => $return->{service}{$service_name}{$variable},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($return);
}

# This reads cluster.conf to find the cluster name.
sub cluster_name
{
	my $self = shift;
	my $an   = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "cluster_name" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Read in cluster.conf. if necessary
	$an->Cman->_read_cluster_conf();
	
	my $cluster_name = $an->data->{cman_config}{data}{name};
	
	return($cluster_name);
}

# This looks at node 1, then if necessary, node 2 checking to see if the node is accessible and, if so, if 
# rgmanager is running. If one of the nodes is accessible, the name/IP, ssh port and password to access it 
# are returned.
sub find_node_in_cluster
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "find_node_in_cluster" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# If no anvil uuid has been set, return.
	if (not $an->data->{cgi}{anvil_uuid})
	{
		return("", "", "");
	}
	
	my $node_name = "";
	my $target    = "";
	my $port      = "";
	my $password  = "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "sys::anvil::node1::online", value1 => $an->data->{sys}{anvil}{node1}{online},
		name2 => "sys::anvil::node2::online", value2 => $an->data->{sys}{anvil}{node2}{online},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{anvil}{node1}{online})
	{
		$node_name = $an->data->{sys}{anvil}{node1}{name};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node_name}::daemon::rgmanager::exit_code", value1 => $an->data->{node}{$node_name}{daemon}{rgmanager}{exit_code},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{node}{$node_name}{daemon}{rgmanager}{exit_code} eq "0")
		{
			# Use this node.
			$target   = $an->data->{sys}{anvil}{node1}{use_ip};
			$port     = $an->data->{sys}{anvil}{node1}{use_port};
			$password = $an->data->{sys}{anvil}{node1}{password};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "target", value1 => $target,
				name2 => "port",   value2 => $port,
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
				name1 => "password", value1 => $password,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	if ((not $target) && ($an->data->{sys}{anvil}{node2}{online}))
	{
		$node_name = $an->data->{sys}{anvil}{node2}{name};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node_name}::daemon::rgmanager::exit_code", value1 => $an->data->{node}{$node_name}{daemon}{rgmanager}{exit_code},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{node}{$node_name}{daemon}{rgmanager}{exit_code} eq "0")
		{
			# Use this node.
			$target   = $an->data->{sys}{anvil}{node2}{use_ip};
			$port     = $an->data->{sys}{anvil}{node2}{use_port};
			$password = $an->data->{sys}{anvil}{node2}{password};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "target", value1 => $target,
				name2 => "port",   value2 => $port,
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
				name1 => "password", value1 => $password,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return($target, $port, $password, $node_name);
}

### NOTE: This is largely a copy of Striker->_parse_clustat_xml()'. Both will be removed eventually.
# This returns a hash reference containing the cluster information from 'clustat'.
sub get_clustat_data
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_clustat_data" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target, 
		name2 => "port",   value2 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# We redirect STDERR to /dev/null to avoid printing the 'Could not connect to CMAN' message
	my $shell_call = $an->data->{path}{timeout}." 15 ".$an->data->{path}{clustat}." -x 2>/dev/null; ".$an->data->{path}{echo}." clustat:\$?";
	my $return     = [];
	my $details    = {
			cluster		=>	{
				name		=>	"",
				quorate		=>	0,
			},
			node		=>	{
				'local'		=>	{
					name		=>	"",
					id		=>	"",
					cman		=>	0,
					rgmanager	=>	0,
				},
				peer		=>	{
					name		=>	"",
					id		=>	"",
					cman		=>	0,
					rgmanager	=>	0,
				},
			},
		};
	
	# If the 'target' is set, we'll call over SSH unless 'target' is 'local' or our hostname.
	if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
	{
		### Remote calls
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
	}
	else
	{
		### Local calls
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$return}, $line;
		}
		close $file_handle;
	}
	my $xml_data = "";
	foreach my $line (@{$return})
	{
		if ($line =~ /clustat:(\d+)/)
		{
			### TODO: If this is 124, make sure sane null values are set because timeout fired.
			my $return_code = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
			next;
		}
		if ($line =~ /Could not connect to CMAN/i)
		{
			# CMAN isn't running.
			$an->Log->entry({log_level => 1, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			last;
		}
		$xml_data .= $line."\n";
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "xml_data", value1 => $xml_data,
	}, file => $THIS_FILE, line => __LINE__});
	if ($xml_data)
	{
		my $xml     = XML::Simple->new();
		my $clustat = $xml->XMLin($xml_data, KeyAttr => {node => 'name'}, ForceArray => 1);
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "clustat", value1 => $clustat,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Gather the data we used to parse out of a normal clustat call...
		$details->{cluster}{name}    = $clustat->{cluster}->[0]->{name};
		$details->{cluster}{quorate} = $clustat->{quorum}->[0]->{quorate};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "details->cluster::name",    value1 => $details->{cluster}{name}, 
			name2 => "details->cluster::quorate", value2 => $details->{cluster}{quorate}, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Gather the node details.
		foreach my $this_node (sort {$a cmp $b} keys %{$clustat->{nodes}->[0]->{node}})
		{
			my $is_local     =  $clustat->{nodes}->[0]->{node}{$this_node}{'local'};
			my $rgmanager_up =  $clustat->{nodes}->[0]->{node}{$this_node}{rgmanager};
			my $cman_up      =  $clustat->{nodes}->[0]->{node}{$this_node}{'state'};
			my $node_id      =  $clustat->{nodes}->[0]->{node}{$this_node}{nodeid};
			   $node_id      =~ s/^0x0+//;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
				name1 => "this_node",    value1 => $this_node,
				name2 => "is_local",     value2 => $is_local,
				name3 => "rgmanager_up", value3 => $rgmanager_up,
				name4 => "cman_up",      value4 => $cman_up,
				name5 => "node_id",      value5 => $node_id,
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($is_local)
			{
				# It's moi!
				$details->{node}{'local'} = {
					name      => $this_node, 
					id        => $node_id, 
					cman      => $cman_up, 
					rgmanager => $rgmanager_up, 
				},
				$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
					name1 => "details->node::local::name",      value1 => $details->{node}{'local'}{name}, 
					name2 => "details->node::local::id",        value2 => $details->{node}{'local'}{id}, 
					name3 => "details->node::local::cman",      value3 => $details->{node}{'local'}{cman}, 
					name4 => "details->node::local::rgmanager", value4 => $details->{node}{'local'}{rgmanager}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# C'est le peer.
				$details->{node}{peer} = {
					name      => $this_node,
					id        => $node_id,
					cman      => $cman_up,
					rgmanager => $rgmanager_up
				},
				$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
					name1 => "details->node::peer::name",      value1 => $details->{node}{peer}{name}, 
					name2 => "details->node::peer::id",        value2 => $details->{node}{peer}{id}, 
					name3 => "details->node::peer::cman",      value3 => $details->{node}{peer}{cman}, 
					name4 => "details->node::peer::rgmanager", value4 => $details->{node}{peer}{rgmanager}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Parse out services.
		foreach my $hash_ref (@{$clustat->{groups}->[0]->{group}})
		{
			my $service_name =  $hash_ref->{name};
			my $is_server    =  $service_name =~ /^vm:/ ? 1 : 0;
			   $service_name =~ s/^.*?://;
			my $host         =  $hash_ref->{owner};
			my $state        =  $hash_ref->{state_str};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
				name1 => "is_server",    value1 => $is_server, 
				name2 => "service_name", value2 => $service_name, 
				name3 => "host",         value3 => $host, 
				name4 => "state",        value4 => $state, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if (($state eq "disabled") or ($state eq "stopped"))
			{
				# Set host to 'none'.
				$host = $an->String->get({key => "state_0002"});
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "host", value1 => $host,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($state eq "failed")
			{
				# Don't do anything here now, it is possible the server is still running. Set
				# the host to 'Unknown' and let the user decide what to do. This can happen 
				# if, for example, the XML file is temporarily removed or corrupted.
				$host = $an->String->get({key => "state_0001", variables => { host => $host }});
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "host", value1 => $host,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if (not $host)
			{
				$host = "none";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "host", value1 => $host,
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			if ($is_server)
			{
				# For historical reasons...
				my $server                             = $service_name;
				   $details->{server}{$server}{host}   = $host;
				   $details->{server}{$server}{status} = $state;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "details->server::${server}::host",   value1 => $details->{server}{$server}{host}, 
					name2 => "details->server::${server}::status", value2 => $details->{server}{$server}{status}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Also for historical reasons...
				my $service                              = $service_name;
				   $details->{service}{$service}{host}   = $host;
				   $details->{service}{$service}{status} = $state;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "details->service::${service}::host",   value1 => $details->{service}{$service}{host}, 
					name2 => "details->service::${service}::status", value2 => $details->{service}{$service}{status}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($details);
}

### TODO: Why does this exist? It is a lesser duplicate of what 'get_clustat_data()' does already...
# This returns an array reference of the servers found on this Anvil!
sub get_cluster_server_list
{
	my $self      = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_cluster_server_list" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $servers = [];
	my $state   = {};
	my $shell_call = $an->data->{path}{clustat};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
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
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
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

### NOTE: This must be called from one of the nodes.
# This migrates the server.
sub migrate_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "migrate_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $server = $parameter->{server} ? $parameter->{server} : "";
	if (not $server)
	{
		$an->Alert->error({title_key => "error_title_0003", message_key => "error_message_0120", code => 120, file => $THIS_FILE, line => __LINE__});
		return ("");
	}
	
	my $return     = "";
	my $shell_call = $an->data->{path}{'anvil-migrate-server'}." --server $server";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
	while(<$file_handle>)
	{
		chomp;
		my $line   =  $_;
		   $return .= "$line\n";
	}
	close $file_handle;
	
	return($return);
}

# This looks takes the local hostname and the cluster.conf data to figure out what the peer's host name is.
sub peer_hostname
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "peer_hostname" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $peer_hostname = "";
	my $hostname      = $parameter->{node} ? $parameter->{node} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "hostname", value1 => $hostname, 
	}, file => $THIS_FILE, line => __LINE__});
	
	if ((not $hostname) or ($hostname eq "local"))
	{
		$hostname = $an->hostname();
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "hostname", value1 => $hostname, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# If I've parsed the active Anvil! data, use that. Otherwise read in cluster.conf.
	my $nodes = [];
	if ($an->data->{cgi}{anvil_uuid})
	{
		push @{$nodes}, $an->data->{sys}{anvil}{node1}{name};
		push @{$nodes}, $an->data->{sys}{anvil}{node2}{name}; 
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "sys::anvil::node1::name", value1 => $an->data->{sys}{anvil}{node1}{name}, 
			name2 => "sys::anvil::node2::name", value2 => $an->data->{sys}{anvil}{node2}{name}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		$an->Cman->_read_cluster_conf();
		foreach my $index1 (@{$an->data->{cman_config}{data}{clusternodes}})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "index1", value1 => $index1, 
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $key (sort {$a cmp $b} keys %{$index1})
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "key", value1 => $key, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($key eq "clusternode")
				{
					foreach my $node (sort {$a cmp $b} keys %{$index1->{$key}})
					{
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "node", value1 => $node, 
						}, file => $THIS_FILE, line => __LINE__});
						push @{$nodes}, $node;
					}
				}
			}
		}
	}
	
	my $found_myself = 0;
	foreach my $node (sort {$a cmp $b} @{$nodes})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "node",     value1 => $node, 
			name2 => "hostname", value2 => $hostname, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($node eq $hostname)
		{
			$found_myself = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "found_myself", value1 => $found_myself, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			$peer_hostname = $node;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "peer_hostname", value1 => $peer_hostname, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Only trust the peer hostname if I found myself.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "found_myself", value1 => $found_myself, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($found_myself)
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "peer_hostname", value1 => $peer_hostname, 
		}, file => $THIS_FILE, line => __LINE__});
		if (not $peer_hostname)
		{
			# Found myself, but not my peer.
			$an->Alert->error({title_key => "error_title_0025", message_key => "error_message_0045", message_variables => { file => $an->data->{path}{cman_config} }, code => 42, file => $THIS_FILE, line => __LINE__});
			return ("");
		}
	}
	else
	{
		# I didn't find myself, so I can't trust the peer was found or is accurate.
		$an->Alert->error({title_key => "error_title_0025", message_key => "error_message_0046", message_variables => { file => $an->data->{path}{cman_config} }, code => 46, file => $THIS_FILE, line => __LINE__});
		return ("");
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "peer_hostname", value1 => $peer_hostname, 
	}, file => $THIS_FILE, line => __LINE__});
	return($peer_hostname);
}

# This returns the short hostname for the machine this is running on. That is to say, the hostname up to the 
# first '.'.
sub peer_short_hostname
{
	my $self = shift;
	my $an   = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "peer_short_hostname" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $peer_short_hostname =  $an->Cman->peer_hostname();
	   $peer_short_hostname =~ s/\..*$//;
	
	return($peer_short_hostname);
}

# This stops a server
sub stop_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "stop_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# This will store the shutdown output and return it to the caller.
	my $output   = "";
	my $return   = [];
	my $server   = $parameter->{server}   ? $parameter->{server}   : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $reason   = $parameter->{reason}   ? $parameter->{reason}   : "clean";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "server", value1 => $server, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
		name4 => "reason", value4 => $reason, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If we weren't given a server name, then why were we called?
	if (not $server)
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0071", code => 71, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# This will disable the server.
	my $shell_call = $an->data->{path}{clusvcadm}." -d $server";
	
	# If the 'target' is set, we'll call over SSH unless 'target' is 'local' or our hostname.
	if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
	{
		### Remote calls
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
	}
	else
	{
		### Local calls
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$return}, $line;
		}
		close $file_handle;
	}
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		$output .= "$line\n";
	}
	
	# TODO: Handle stop failures
	my $details     = $an->Get->server_data({server => $server});
	my $server_uuid = $details->{uuid};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "server_uuid", value1 => $server_uuid, 
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::read_db_id", value1 => $an->data->{sys}{read_db_id}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{read_db_id})
	{
		my $query = "
UPDATE 
    servers 
SET 
    server_stop_reason = ".$an->data->{sys}{use_db_fh}->quote($reason).", 
    modified_date      = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    server_uuid = ".$an->data->{sys}{use_db_fh}->quote($server_uuid)."
;";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	}
	
	return($output);
}

# This updates cluster.conf in a limited set of ways. It can change which node has the fence delay, the 
# shutdown timer for a given server or change a fence device password. It will validate and then push the
# changes. 
sub update_cluster_conf
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "update_cluster_conf" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid   = $parameter->{anvil_uuid}   ? $parameter->{anvil_uuid}   : "";
	my $task         = $parameter->{task}         ? $parameter->{task}         : "";
	my $subtask      = $parameter->{subtask}      ? $parameter->{subtask}      : "";
	my $server       = $parameter->{server}       ? $parameter->{server}       : "";
	my $method       = $parameter->{method}       ? $parameter->{method}       : "";
	my $node         = $parameter->{node}         ? $parameter->{node}         : "";
	my $timeout      = $parameter->{timeout}      ? $parameter->{timeout}      : "";
	my $new_password = $parameter->{new_password} ? $parameter->{new_password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid, 
		name2 => "task",       value2 => $task, 
		name3 => "subtask",    value3 => $subtask, 
		name4 => "server",     value4 => $server, 
		name5 => "method",     value5 => $method, 
		name6 => "node",       value6 => $node, 
		name7 => "timeout",    value7 => $timeout, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "new_password", value1 => $new_password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# The current default shutdown timeout is 120 seconds. I doubt this will ever change, but...
	my $default_timeout     = 120;
	my $default_fence_delay = 15;
	
	# If I don't have an Anvil! UUID, try to divine it. CGI first
	if ((not $anvil_uuid) && ($an->data->{cgi}{anvil_uuid}))
	{
		$anvil_uuid = $an->data->{cgi}{anvil_uuid};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "anvil_uuid", value1 => $anvil_uuid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Next, loading the anvil.
	if (not $anvil_uuid)
	{
		if ($an->Validate->is_uuid({uuid => $an->data->{sys}{anvil}{uuid}}))
		{
			$anvil_uuid = $an->data->{sys}{anvil}{uuid};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "anvil_uuid", value1 => $anvil_uuid,
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Try loading the anvil
			$an->Striker->load_anvil();
			
			# Now do we have the UUID? If not, we'll fail shortly.
			if ($an->Validate->is_uuid({uuid => $an->data->{sys}{anvil}{uuid}}))
			{
				$anvil_uuid = $an->data->{sys}{anvil}{uuid};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "anvil_uuid", value1 => $anvil_uuid,
				}, file => $THIS_FILE, line => __LINE__});
				
				# Do a quick scan of the nodes.
				$an->Striker->scan_node({uuid => $an->data->{sys}{anvil}{node1}{uuid}, short_scan => 1});
				$an->Striker->scan_node({uuid => $an->data->{sys}{anvil}{node2}{uuid}, short_scan => 1});
			}
		}
	}
	
	# Return codes:
	# 0  = Successfully updated the config.
	# 1  = Did not need to update the config.
	# 2  = Something went wrong. Details will be reported in the error.
	my $return_code = 2;
	
	# Do I have a valid anvil_uuid?
	if ($an->Validate->is_uuid({uuid => $anvil_uuid}))
	{
		# It's a valud UUID. Is it a valid Anvil! though?
		$an->Striker->load_anvil({anvil_uuid => $anvil_uuid});
		if (not $an->data->{sys}{anvil}{name})
		{
			# Unknown Anvil!
			$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0216", message_variables => { anvil_uuid => $anvil_uuid }, code => 216, file => $THIS_FILE, line => __LINE__});
			return("");
		}
	}
	elsif ($anvil_uuid)
	{
		# What iz zis?!
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0207", message_variables => { anvil_uuid => $anvil_uuid }, code => 207, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	else
	{
		# Can't do much, now can I?
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0208", code => 208, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Do I have a valid task?
	if (not $task)
	{
		# No task at all...
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0209", code => 209, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	elsif (($task ne "server") && ($task ne "fence"))
	{
		# Have a task, but it isn't valid.
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0210", message_variables => { task => $task }, code => 210, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	### NOTE: The task can be 'server' or 'fence'
	#         The subtasks can be:
	#         - server -> delay (requires 'timeout')
	#         - fence  -> password (requires 'method'), delay (requires 'node')
	# Do I have a valid sub-task?
	if (not $subtask)
	{
		# No sub task at all...
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0211", message_variables => { task => $task }, code => 211, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	elsif ($task eq "server")
	{
		if ($subtask eq "delay")
		{
			# Valid, but do I have a timeout set?
			if (not $timeout)
			{
				# Nope
				$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0212", message_variables => { server => $server }, code => 212, file => $THIS_FILE, line => __LINE__});
				return("");
			}
			elsif ($timeout !~ /^\d+$/)
			{
				$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0213", message_variables => { 
					server  => $server, 
					timeout => $timeout, 
				}, code => 213, file => $THIS_FILE, line => __LINE__});
				return("");
			}
		}
		elsif ($subtask)
		{
			# Invalid subtask
			$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0214", message_variables => { 
				server  => $server, 
				subtask => $subtask, 
			}, code => 214, file => $THIS_FILE, line => __LINE__});
			return("");
		}
		else
		{
			# No sub-task
			$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0215", message_variables => { server => $server }, code => 215, file => $THIS_FILE, line => __LINE__});
			return("");
		}
	}
	elsif ($task eq "fence")
	{
		if ($subtask eq "delay")
		{
			# Valid, but I need a node.
			if (not $node)
			{
				# Nope
				$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0217", code => 217, file => $THIS_FILE, line => __LINE__});
				return("");
			}
			elsif (($node ne $an->data->{sys}{anvil}{node1}{name}) && ($node ne $an->data->{sys}{anvil}{node2}{name}))
			{
				# Node name doesn't match a known node.
				$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0218", message_variables => { 
					anvil      => $an->data->{sys}{anvil}{name},
					node       => $node, 
					node1_name => $an->data->{sys}{anvil}{node1}{name}, 
					node2_name => $an->data->{sys}{anvil}{node2}{name}, 
				}, code => 218, file => $THIS_FILE, line => __LINE__});
				return("");
			}
		}
		elsif ($subtask eq "password")
		{
			# Valid, but I need a method and new password.
			if (not $method)
			{
				# Nope
				$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0219", code => 219, file => $THIS_FILE, line => __LINE__});
				return("");
			}
			elsif (not $new_password)
			{
				# Nope
				$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0220", code => 220, message_variables => { method => $method }, file => $THIS_FILE, line => __LINE__});
				return("");
			}
			elsif (($node) && (($node ne $an->data->{sys}{anvil}{node1}{name}) && ($node ne $an->data->{sys}{anvil}{node2}{name})))
			{
				# Node name doesn't match a known node.
				$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0225", message_variables => { 
					anvil      => $an->data->{sys}{anvil}{name},
					node       => $node, 
					method     => $method, 
					node1_name => $an->data->{sys}{anvil}{node1}{name}, 
					node2_name => $an->data->{sys}{anvil}{node2}{name}, 
				}, code => 225, file => $THIS_FILE, line => __LINE__});
				return("");
			}
		}
		elsif ($subtask)
		{
			# Invalid sub-task
			$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0221", message_variables => { subtask => $subtask }, code => 221, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Invalid sub-task
			$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0222", code => 222, file => $THIS_FILE, line => __LINE__});
			return("");
		}
	}
	
	# Make sure both nodes are online. We'll check for cman membership later.
	if ((not $an->data->{sys}{anvil}{node1}{online}) or (not $an->data->{sys}{anvil}{node2}{online}))
	{
		# Both nodes need to be online.
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0223", code => 223, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Am I a node or dashboard? If I am a dashboard, I'll call node1. If I am a node, I'll work on myself.
	my $i_am = $an->Get->what_am_i();
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "i_am", value1 => $i_am, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Before we proceed, we need to decide two things. Are we a node, and are both nodes in the cluster?
	my $return       = [];
	my $shell_call   = $an->data->{path}{'anvil-report-state'};
	my $target       = "";
	my $port         = "";
	my $password     = "";
	my $node1_cman   = 0;
	my $node2_cman   = 0;
	if ($i_am eq "node")
	{
		# Operate locally
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$return}, $line;
		}
		close $file_handle;
	}
	else
	{
		# Operate on node 1.
		$target   = $an->data->{sys}{anvil}{node1}{use_ip};
		$port     = $an->data->{sys}{anvil}{node1}{use_port};
		$password = $an->data->{sys}{anvil}{node1}{password};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "port",       value2 => $port,
			name3 => "shell_call", value3 => $shell_call,
			name4 => "target",     value4 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
	}
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /clustat::cman::me = \[(\d+)\]/)
		{
			$node1_cman = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "node1_cman", value1 => $node1_cman, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /clustat::cman::peer = \[(\d+)\]/)
		{
			$node2_cman = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "node2_cman", value1 => $node2_cman, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	### NOTE: I know, "node1" could be node 2 if we're running this on node 2, but the results are the 
	###       same.
	# Finally; Are both nodes running cman?
	if ((not $node1_cman) or (not $node2_cman))
	{
		# Both nodes need to be a cluster member.
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0224", code => 224, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	### Still alive? NOW we're ready to proceed!
	# Read in the current config!
	my $file_changed = 0;
	   $return       = [];
	my $new_config   = "";
	   $shell_call   = $an->data->{path}{'cat'}." ".$an->data->{path}{cluster_conf};
	
	# We'll now use 'target' to determine if a call is local or remote.
	if ($target)
	{
		# Remote call
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
	}
	else
	{
		# Local call
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$return}, $line;
		}
		close $file_handle;
	}
	
	# The 'return' should be the full cluster.conf. We'll verify though as we loop through.
	my $new_file          = "";
	my $config_version    = "";
	my $close_found       = 0;
	my $this_server       = "";
	my $this_stop_timeout = $default_timeout;
	my $this_node         = "";
	my $this_fence_method = "";
	my $this_method       = "";
	my $first_method      = 1;
	foreach my $line (@{$return})
	{
		### WARNING: This exposes passwords!
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# If the file gets rewritten, we'll need to increment the cluster.conf version.
		if ($line =~ /<cluster /)
		{
			# Dig out and increment the config version, but DON'T set the 'file_changed' flag.
			$config_version = ($line =~ /config_version="(\d+)"/)[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "config_version", value1 => $config_version, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Increment the version now.
			$config_version++;
			$line =~ s/config_version="\d+"/config_version="$config_version"/;
		}
		
		# We won't do anything unless we see the cluster.conf close.
		if ($line =~ /<\/cluster>/)
		{
			# Close found.
			$close_found = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "close_found", value1 => $close_found, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# If this is a closing VM statement, process.
		if ($this_server)
		{
			# I'm in a <vm> element... 
			if (($line =~ /<action /) && ($line =~ /name="stop"/))
			{
				# We're in the stop timeout section. 
				my $old_timeout = ($line =~ /timeout="(.*?)"/)[0];
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "old_timeout", value1 => $old_timeout, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($old_timeout =~ /^(\d+)m$/)
				{
					# It's expressed in minutes, convert it.
					$old_timeout =  $1;
					$old_timeout *= 60;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "old_timeout", value1 => $old_timeout, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				
				# Now, does it differ?
				if ($old_timeout ne $timeout)
				{
					# Changed!
					$line =~ s/timeout=".*?"/timeout="$timeout"/;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			if ($line =~ /<\/vm>/)
			{
				# End of this server's element.
				$this_server = "";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "this_server", value1 => $this_server, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# If this is a VM, start processing (we'll close if it's a self-closing element).
		if ($line =~ /<vm .*?>/)
		{
			# In a VM line
			$this_server = ($line =~ /name="(.*?)"/)[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "this_server", value1 => $this_server, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# If this is a self-closing vm entry, process it now.
			if ($line =~ /<vm .*?\/>/)
			{
				# This is a self-closing line, so the shutdown timer will be the default of 120.
				if (($task eq "server") && ($subtask eq "delay") && ($server eq $this_server))
				{
					# This is the file we're working on. 
					if ($timeout ne $default_timeout)
					{
						# The user has asked us to set a timeout, so do so now. Note
						# that we'll change the line from self-closing the havinf a 
						# child element, mark the file as changed and clear 
						# 'this_server' now. Then we'll write out the element and 
						# 'child element and loop out.
						my $line         =~ s/\/>/>/;
						   $file_changed =  1;
						   $this_server  =  "";
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "file_changed", value1 => $file_changed, 
							name2 => "line",         value2 => $line, 
						}, file => $THIS_FILE, line => __LINE__});
						
						# Record the new element and loop.
						$new_file .= $line."\n";
						$new_file .= "\t\t<action name=\"stop\" timeout=\"$timeout\"/>\n";
						$new_file .= "\t</vm>\n";
						next;
					}
				}
			}
		}
		
		### NOTE: At this time, we *change* passwords, we can't set them when none existed.
		### TODO: Track is a password was seen for a given fence method and set it, if not.
		# If I am processing a node, we'll look for both it's fence delay and timing, if any, as well
		# as any possible passwords set for it's fence methods. If we don't find a password in them,
		# we'll not worry until we also fail to see a password of the corresponding fence method.
		if ($line =~ /<clusternode /)
		{
			$this_node    = ($line =~ /name="(.*?)"/)[0];
			$first_method = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "this_node",    value1 => $this_node, 
				name2 => "first_method", value2 => $first_method, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($this_node)
		{
			# We're inside a node element
			if ($line =~ /<\/clusternode>/)
			{
				# Done with this node
				$this_node    = "";
				$first_method = 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_node",    value1 => $this_node, 
					name2 => "first_method", value2 => $first_method, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /<method name="(.*?)">/)
			{
				$this_method = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "this_method", value1 => $this_method, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($this_method)
			{
				if ($line =~ /<\/method>/)
				{
					# Done with this method.
					$this_method = "";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "this_method", value1 => $this_method, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /<device /)
				{
					# If this is the first method and if we've been asked to change the 
					# node with the fence delay, do so now (if needed).
					if ($line =~ / delay="(\d+)"/)
					{
						my $old_delay = $1;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "old_delay", value1 => $old_delay, 
						}, file => $THIS_FILE, line => __LINE__});
						
						if (($task eq "fence") && ($subtask eq "delay") && ($node ne $this_node))
						{
							# Remove the delay.
							$file_changed =  1;
							$line         =~ s/ delay="\d+"//;
							# WARNING: Exposes passwords
							$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
								name1 => "file_changed", value1 => $file_changed, 
								name2 => "line",         value2 => $line, 
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
					if (($task eq "fence") && ($subtask eq "delay") && ($first_method) && ($node eq $this_node))
					{
						# Add it.
						$file_changed =  1;
						$line         =~ s/ delay=".*?"//;
						$line         =~ s/name="(.*?)"/name="$1" delay="$default_fence_delay"/;
						# WARNING: Exposes passwords
						$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
							name1 => "file_changed", value1 => $file_changed, 
							name2 => "line",         value2 => $line, 
						}, file => $THIS_FILE, line => __LINE__});
					}
					if (($task eq "fence") && ($subtask eq "password") && ($method eq $this_method))
					{
						# If we've been given a specific node, work on it. Otherwise,
						# change all methods that match.
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "node",      value1 => $node, 
							name2 => "this_node", value2 => $this_node, 
						}, file => $THIS_FILE, line => __LINE__});
						if ((not $node) or ($node eq $this_node))
						{
							# Pull the password out and see if we need to change it.
							if ($line =~ /passwd="(.*?)"/)
							{
								# Password found
								my $old_password = $1;
								$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
									name1 => "old_password", value1 => $old_password, 
								}, file => $THIS_FILE, line => __LINE__});
								
								if ($old_password ne $new_password)
								{
									# Change it!
									$file_changed =  1;
									$line         =~ s/passwd=".*?"/passwd="$new_password"/;
									$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
										name1 => "file_changed", value1 => $file_changed, 
									}, file => $THIS_FILE, line => __LINE__});
									$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
										name1 => "line", value1 => $line, 
									}, file => $THIS_FILE, line => __LINE__});
								}
							}
						}
					}
					
					# If the method is 'ipmi' and we have a login attribute, record it.
					if (($method eq "ipmi") && ($line =~ /login="(.*?)"/))
					{
						$an->data->{ipmi}{$this_node}{ipmi_user} = $1;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "ipmi::${this_node}::ipmi_user", value1 => $an->data->{ipmi}{$this_node}{ipmi_user}, 
						}, file => $THIS_FILE, line => __LINE__});
					}
					
					# Clear the "first method" flag so that we don't add a delay to a 
					# second fence method.
					$first_method = 0;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "first_method", value1 => $first_method, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		
		# Check for some fence device info.
		if ($line =~ /<fencedevice /)
		{
			if (($line =~ /agent="fence_ipmilan"/) && ($line =~ /login="(.*?)"/))
			{
				my $login = $1;
				foreach my $node_key ("node1", "node2")
				{
					if ($an->data->{sys}{anvil}{$node_key}{name})
					{
						my $this_node = $an->data->{sys}{anvil}{$node_key}{name};
						$an->data->{ipmi}{$this_node}{ipmi_user} = $1;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "ipmi::${this_node}::ipmi_user", value1 => $an->data->{ipmi}{$this_node}{ipmi_user}, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
			}
		}
		
		# Record the line (modified or not)
		$new_file .= $line."\n";
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "file_changed", value1 => $file_changed, 
	}, file => $THIS_FILE, line => __LINE__});
	if (not $file_changed)
	{
		# We're done.
		$return_code = 1;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "return_code", value1 => $return_code, 
		}, file => $THIS_FILE, line => __LINE__});
		
		return($return_code);
	}

	### WARNING: This exposes passwords!
	# Now I have the current config.
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "new_file", value1 => $new_file, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# We're only going to proceed *if* we set the version number AND saw the close of the XML.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "close_found",    value1 => $close_found, 
		name2 => "config_version", value2 => $config_version, 
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $close_found) or (not $config_version))
	{
		# Something went wrong, abort.
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0226", code => 226, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Still alive? Write out the file to /tmp/ before to test it with ccs_config_validate. If 
	# we're not a node, we'll rsync it to node 1.
	my $temp_file  = "/tmp/cluster.conf";
	   $shell_call = $temp_file;
	open (my $file_handle, ">$shell_call") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0015", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
	print $file_handle $new_file;
	close $file_handle;
	
	# Now rsync the file, if necessary.
	if ($target)
	{
		# Remote, send over the temp file.
		my $source      = $temp_file;
		my $destination = "root\@${target}:/tmp/";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "source",      value1 => $source,
			name2 => "destination", value2 => $destination,
			name3 => "target",      value3 => $target,
			name4 => "port",        value4 => $port,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password,
		}, file => $THIS_FILE, line => __LINE__});
		my $failed = $an->Storage->rsync({
			source      => $source,
			destination => $destination,
			switches    => $an->data->{args}{rsync},
			target      => $target,
			port        => $port,
			password    => $password,
		});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "failed", value1 => $failed,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Now call ccs_config_validate
	$return     = [];
	$shell_call = $an->data->{path}{ccs_config_validate}." -f ".$temp_file."; ".$an->data->{path}{echo}." return_code:\$?";
	if ($target)
	{
		# Remote call
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
	}
	else
	{
		# Local call
		# When we're running from cron, PATH isn't set and 'ccs_config_validate' calls 
		# '/usr/sbin/ccs_update_schema', but without the path. So we'll set PATH here.
		$shell_call = "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin; $shell_call";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			push @{$return}, $line;
		}
		close $file_handle;
	}
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /return_code:(\d+)/)
		{
			# 0 = success
			my $return_code = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($return_code)
			{
				# Validation failed.
				$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0227", code => 227, file => $THIS_FILE, line => __LINE__});
				return("");
			}
		}
	}
	
	# Backup the cluster.conf, move the temp file over the old one and then push out the changes with 
	# 'ccs'.
	my $date_stamp  = $an->Get->date_and_time({split_date_time => 0, no_spaces => 1});
	my $backup_file = $an->data->{path}{cluster_conf}.".".$date_stamp;
	   $shell_call  = "
".$an->data->{path}{cp}." --force ".$an->data->{path}{cluster_conf}." ".$backup_file."
if [ -e '$backup_file' ]
then
    ".$an->data->{path}{echo}." ok
else
    ".$an->data->{path}{echo}." failed
fi;
";
	$return = [];
	if ($target)
	{
		# Remote call
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
	}
	else
	{
		# Local call
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$return}, $line;
		}
		close $file_handle;
	}
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /failed/)
		{
			$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0228", message_variables => { backup_file => $backup_file }, code => 228, file => $THIS_FILE, line => __LINE__});
			return("");
		}
	}
	
	# If we're still alive, copy the temp over and validate it.
	$shell_call  = "
".$an->data->{path}{cp}." --force ".$temp_file." ".$an->data->{path}{cluster_conf}."
if \$(".$an->data->{path}{'grep'}." -q 'config_version=\"$config_version\"' ".$an->data->{path}{cluster_conf}.");
then
    ".$an->data->{path}{echo}." ok
else
    ".$an->data->{path}{echo}." failed
fi;
";
	$return     = [];
	if ($target)
	{
		# Remote call
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
	}
	else
	{
		# Local call
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$return}, $line;
		}
		close $file_handle;
	}
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /failed/)
		{
			$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0229", message_variables => { version => $config_version }, code => 229, file => $THIS_FILE, line => __LINE__});
			return("");
		}
	}
	
	# Push it!
	$shell_call = $an->data->{path}{ccs}." -h localhost --activate --sync --password \"".$an->data->{sys}{anvil}{password}."\" && ".$an->data->{path}{ccs}." --getversion";
	$return     = [];
	if ($target)
	{
		# Remote call
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
	}
	else
	{
		# Local call
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$return}, $line;
		}
		close $file_handle;
	}
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^(\d+)$/)
		{
			### NOTE: 'ccs' will bump the version above what we set.
			my $new_version = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "new_version",    value1 => $new_version, 
				name2 => "config_version", value2 => $config_version, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($new_version < $config_version)
			{
				# Failed.
				$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0230", message_variables => { 
					config_version => $config_version,
					new_version    => $new_version, 
				}, code => 230, file => $THIS_FILE, line => __LINE__});
				return("");
			}
			else
			{
				# Success!
				$return_code = 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code, 
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# Withdraw a node from the cluster, using a delayed run that stops gfs2 and clvmd in case rgmanager gets stuck.
sub withdraw_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "withdraw_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target, 
		name2 => "port",   value2 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# This will report back what happened.
	# 0 == success
	# 1 == failed, restart succeeded.
	# 2 == failed, restart also failed.
	my $return_code = 0;
	my $output      = "";
	
	# Sometimes rgmanager gets stuck waiting for gfs2 and/or clvmd2 to stop. So to help with these cases,
	# we'll call '$an->System->delayed_run()' for at least 60 seconds in the future. This usually gives 
	# rgmanager the kick it needs to actually stop.
	my ($token, $delayed_run_output, $problem) = $an->System->delayed_run({
		command  => $an->data->{path}{initd}."/gfs2 stop && ".$an->data->{path}{initd}."/clvmd stop",
		delay    => 60,
		target   => $target,
		password => $password,
		port     => $port,
	});
	
	# First, stop rgmanager.
	my $rgmanager_stop = 1;
	my $shell_call     = $an->data->{path}{initd}."/rgmanager stop";
	my $return         = [];
	
	# If the 'target' is set, we'll call over SSH unless 'target' is 'local' or our hostname.
	if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
	{
		### Remote calls
		# Stop rgmanager
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
	}
	else
	{
		### Local calls
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$return}, $line;
		}
		close $file_handle;
	}
	foreach my $line (@{$return})
	{
		$output .= "$line\n";
		$line   =~ s/^\s+//;
		$line   =~ s/\s+$//;
		$line   =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /fail/i)
		{
			$rgmanager_stop = 0;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "rgmanager_stop", value1 => $rgmanager_stop,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Now clear the delayed run, if rgmanager stopped, then stop cman.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "rgmanager_stop", value1 => $rgmanager_stop, 
		name2 => "token",          value2 => $token, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($rgmanager_stop)
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "token", value1 => $token,
		}, file => $THIS_FILE, line => __LINE__});
		if ($token)
		{
			my $shell_call = $an->data->{path}{'anvil-run-jobs'}." --abort $token";
			my $return     = [];
			
			if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
			{
				### Remote calls
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
					name2 => "target",     value2 => $target,
				}, file => $THIS_FILE, line => __LINE__});
				(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$target,
					port		=>	$port, 
					password	=>	$password,
					'close'		=>	0,
					shell_call	=>	$shell_call,
				});
			}
			else
			{
				### Local calls
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "shell_call", value1 => $shell_call, 
				}, file => $THIS_FILE, line => __LINE__});
				open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
				while(<$file_handle>)
				{
					chomp;
					my $line =  $_;
					push @{$return}, $line;
				}
				close $file_handle;
			}
			foreach my $line (@{$return})
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Now stop 'cman'
		my $cman_stop  = 1;
		my $shell_call = $an->data->{path}{initd}."/cman stop";
		my $return     = [];
		if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
		{
			### Remote calls
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "target",     value2 => $target,
			}, file => $THIS_FILE, line => __LINE__});
			(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$target,
				port		=>	$port, 
				password	=>	$password,
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
		}
		else
		{
			### Local calls
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call, 
			}, file => $THIS_FILE, line => __LINE__});
			open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
			while(<$file_handle>)
			{
				chomp;
				my $line =  $_;
				push @{$return}, $line;
			}
			close $file_handle;
		}
		foreach my $line (@{$return})
		{
			$output .= "$line\n";
			$line   =~ s/^\s+//;
			$line   =~ s/\s+$//;
			$line   =~ s/\s+/ /g;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /fail/i)
			{
				$cman_stop = 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "cman_stop", value1 => $cman_stop, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		if ($cman_stop)
		{
			# cman stopped, we're good.
		}
		else
		{
			# stopping cman failed... Restart it
			   $return_code = 1;
			my $cman_start  = 1;
			my $shell_call  = $an->data->{path}{initd}."/cman start";
			my $return      = [];
			if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
			{
				### Remote calls
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
					name2 => "target",     value2 => $target,
				}, file => $THIS_FILE, line => __LINE__});
				(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$target,
					port		=>	$port, 
					password	=>	$password,
					'close'		=>	0,
					shell_call	=>	$shell_call,
				});
			}
			else
			{
				### Local calls
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "shell_call", value1 => $shell_call, 
				}, file => $THIS_FILE, line => __LINE__});
				open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
				while(<$file_handle>)
				{
					chomp;
					my $line =  $_;
					push @{$return}, $line;
				}
				close $file_handle;
			}
			foreach my $line (@{$return})
			{
				$output .= "$line\n";
				$line   =~ s/^\s+//;
				$line   =~ s/\s+$//;
				$line   =~ s/\s+/ /g;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /fail/i)
				{
					$cman_start = 0;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "cman_start", value1 => $cman_start,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			if ($cman_start)
			{
				my ($recover, $recover_output) = $an->Cman->_recover_rgmanager({
					target   => $target, 
					port     => $port, 
					password => $password,
				});
				$output .= $recover_output;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "recover", value1 => $recover,
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($recover)
				{
					# Failed to restart rgmanager...
					$return_code = 2;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "return_code", value1 => $return_code,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			else
			{
				# Failed to restart cman...
				$return_code = 2;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	else
	{
		# rgmanager failed to stop... Restart it
		$return_code = 1;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "return_code", value1 => $return_code,
		}, file => $THIS_FILE, line => __LINE__});
		
		my ($recover, $recover_output) = $an->Cman->_recover_rgmanager({
			target   => $target, 
			port     => $port, 
			password => $password,
		});
		$output .= $recover_output;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "recover", value1 => $recover,
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($recover)
		{
			# Failed to restart rgmanager...
			$return_code = 2;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}

	# 0 == success
	# 1 == failed, restart succeeded.
	# 2 == failed, restart also failed.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code, $output);
}


#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

# This performs the actual boot on the server after sanity checks are done. This should not be called directly!
sub _do_server_boot
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_do_server_boot" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $return      = 0;
	my $boot_return = [];
	my $server      = $parameter->{server} ? $parameter->{server} : "";
	my $node        = $parameter->{node}   ? $parameter->{node}   : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "server", value1 => $server, 
		name2 => "node",   value2 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $shell_call = $an->data->{path}{clusvcadm}." -e $server -m $node";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		push @{$boot_return}, $line;
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /success/i)
		{
			### TODO: Update 'server' with the new state and host.
			$return = 1;
			$an->Log->entry({log_level => 1, message_key => "tools_log_0017", message_variables => {
				server => $server,
				node   => $node, 
			}, file => $THIS_FILE, line => __LINE__});
			
			my $details     = $an->Get->server_data({server => $server});
			my $server_uuid = $details->{uuid};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "server_uuid", value1 => $server_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "sys::read_db_id", value1 => $an->data->{sys}{read_db_id}, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($an->data->{sys}{read_db_id})
			{
				my $query = "
UPDATE 
    servers 
SET 
    server_stop_reason = NULL, 
    modified_date      = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    server_uuid = ".$an->data->{sys}{use_db_fh}->quote($server_uuid)."
;";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "query", value1 => $query
				}, file => $THIS_FILE, line => __LINE__});
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
			}
		}
		if ($line =~ /fail/i)
		{
			### TODO: Add some recovery options here.
			### TODO: Update the database to mark the 'stop_reason' as 'failed'.
			$an->Alert->warning({message_key => "warning_message_0007", message_variables => {
				server => $server,
				node   => $node, 
				error  => $line,
			}, quiet => 1, file => $THIS_FILE, line => __LINE__});
			$return = 2;
			
			# Disable it
			my $shell_call = $an->data->{path}{clusvcadm}." -d $server";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call, 
			}, file => $THIS_FILE, line => __LINE__});
			open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
			}	
			close $file_handle;
		}
	}
	close $file_handle;
	
	return($return, $boot_return);
}

# This reads in cluster.conf if needed.
sub _read_cluster_conf
{
	my $self = shift;
	my $an   = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_read_cluster_conf" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
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

### NOTE: This was originally based on Striker.pm's 'recover_rgmanager()' function which checked/recovered
###       storage. This was not ported because storage is now monitored/fixed elsewhere.
# This performs a recovery of rgmanager after a failed stop (either because rgmanager itself failed to stop 
# or because cman failed to stop and we had to restart cman then rgmanager)
sub _recover_rgmanager
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_recover_rgmanager" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target, 
		name2 => "port",   value2 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return_code = 0;
	my $shell_call  = $an->data->{path}{initd}."/rgmanager start";
	my $return      = [];
	my $output      = "";
	
	# If the 'target' is set, we'll call over SSH unless 'target' is 'local' or our hostname.
	if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
	{
		### Remote calls
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
	}
	else
	{
		### Local calls
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$return}, $line;
		}
		close $file_handle;
	}
	foreach my $line (@{$return})
	{
		$output .= "$line\n";
		$line   =~ s/^\s+//;
		$line   =~ s/\s+$//;
		$line   =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /fail/i)
		{
			$return_code = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}

	# 0 == success
	# 1 == failed
	return($return_code, $output);
}

1;
