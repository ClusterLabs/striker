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
# cluster_conf_data
# cluster_name
# get_clustat_data
# get_cluster_server_list
# peer_hostname
# peer_short_hostname
# stop_server
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
	
	# If requested_node is healthy, we will boot on that. If 'force' is set and both nodes are sick, 
	# we'll boot on the requested node or, if not set, the highest priority node, if storage is OK on 
	# both, or else it will boot on the UpToDate node.
	my $server         = $parameter->{server} ? $parameter->{server} : "";
	my $requested_node = $parameter->{node}   ? $parameter->{node}   : "";
	my $force          = $parameter->{force}  ? $parameter->{force}  : 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "server",         value1 => $server, 
		name2 => "requested_node", value2 => $requested_node, 
		name3 => "force",          value3 => $force, 
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
		$an->Alert->warning({message_key => "warning_message_0003", message_variables => {
			server => $server,
		}, file => $THIS_FILE, line => __LINE__});
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
		$an->Log->entry({log_level => 1, message_key => "tools_log_0009", message_variables => {
			server => $server,
		}, file => $THIS_FILE, line => __LINE__});
		return(1);
	}
	
	# If we're still alive, we're going to try and start it now. Start by getting the information about 
	# the server so that we can be smart about it.
	
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
		$nodes->{$node}{healthy}       = "";
		$nodes->{$node}{storage_ready} = 1;
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
	
	# Take the highest priority node
	foreach my $priority (sort {$a cmp $b} keys %{$cluster_data->{failoverdomain}{$failoverdomain}{priority}})
	{
		my $node                      = $cluster_data->{failoverdomain}{$failoverdomain}{priority}{$priority};
		   $nodes->{$node}{preferred} = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "nodes->${peer_host_name}::storage_ready", value1 => $nodes->{$peer_host_name}{storage_ready}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Check the node health files and log what we've found.
	foreach my $node (sort {$a cmp $b} keys %{$nodes})
	{
		$nodes->{$node}{healthy} = $an->ScanCore->host_state({target => $node});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "nodes->${node}::healthy", value1 => $nodes->{$node}{healthy}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# All thing being equal, which node is preferred?
	my $preferred_node = "";
	my $secondary_node = "";
	foreach my $node (sort {$a cmp $b} keys %{$nodes})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node",                     value1 => $node, 
			name2 => "requested_node",           value2 => $requested_node, 
			name3 => "nodes->{$node}{preferred}", value3 => $nodes->{$node}{preferred}, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($requested_node)
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "node",           value1 => $node, 
				name2 => "requested_node", value2 => $requested_node, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($node eq $requested_node)
			{
				$preferred_node = $node;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "preferred_node", value1 => $preferred_node, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		elsif ($nodes->{$node}{preferred})
		{
			$preferred_node = $node;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "preferred_node", value1 => $preferred_node, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	foreach my $node (sort {$a cmp $b} keys %{$nodes})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node",           value1 => $node, 
			name2 => "preferred_node", value2 => $preferred_node, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($node ne $preferred_node)
		{
			$secondary_node = $node;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "secondary_node", value1 => $secondary_node, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	### Now we know which node is preferred, is it healthy?
	# If the user's requested node is healthy, boot it. If there is no requested node, see if the 
	# failover domain's highest priority node is ready. If not, is the peer? If not, sadness,
	my $booted      = 0;
	my $boot_return = "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "nodes->{$preferred_node}{storage_ready}", value1 => $nodes->{$preferred_node}{storage_ready}, 
		name2 => "nodes->{$secondary_node}{storage_ready}", value2 => $nodes->{$secondary_node}{storage_ready}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($nodes->{$preferred_node}{storage_ready})
	{
		# The preferred node's storage is healthy, so will boot here *if*:
		# - Storage is healhy
		# - Health is OK *or* both nodes are 'warning' and 'force' was used.
		# Storage is good. Are we healthy?
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "nodes->{$preferred_node}{healthy}",       value1 => $nodes->{$preferred_node}{healthy}, 
			name2 => "nodes->{$secondary_node}{storage_ready}", value2 => $nodes->{$secondary_node}{storage_ready}, 
			name3 => "nodes->{$secondary_node}{healthy}",       value3 => $nodes->{$secondary_node}{healthy}, 
			name4 => "force",                                   value4 => $force, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($nodes->{$preferred_node}{healthy} eq "ok")
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "booted", value1 => $booted, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# No luck
			$an->Alert->warning({message_key => "warning_message_0004", message_variables => {
				server => $server,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	elsif ($nodes->{$secondary_node}{storage_ready})
	{
		# Secondary's storage is healthy, we'll boot here if our health is OK. If not, we'll boot 
		# here if we were forced.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "booted", value1 => $booted, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# No luck...
			$an->Alert->warning({message_key => "warning_message_0004", message_variables => {
				server => $server,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	elsif ($force)
	{
		# We'll boot on the preferred node... May his noodly appendages take mercy on our soul.
		$an->Alert->warning({title_key => "warning_title_0008", message_key => "warning_message_0005", message_variables => {
			server => $server,
		        node   => $preferred_node, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# No safe node to boot on
		$an->Alert->warning({message_key => "warning_message_0006", message_variables => {
			server => $server,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	### Rescan if booted.
	# 0 = Not booted
	# 1 = Booted
	# 2 = Failed to boot.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "server_found", value1 => $server_found, 
					name2 => "server_state", value2 => $server_state, 
					name3 => "server_uuid",  value3 => $server_uuid, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($booted, $boot_return);
}

# This gathers the data from a cluster.conf file. Returns '0' if the file wasn't read successfully.
sub cluster_conf_data
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	
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
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $cluster_conf_return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			ssh_fh		=>	"",
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
		open (my $file_handle, "$shell_call 2>&1 |") or die "Failed to call: [$shell_call], error was: $!\n";
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
	
	# Read in cluster.conf. if necessary
	$an->Cman->_read_cluster_conf();
	
	my $cluster_name = $an->data->{cman_config}{data}{name};
	
	return($cluster_name);
}

# This returns a hash reference containing the cluster information from 'clustat'.
sub get_clustat_data
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target, 
		name2 => "port",   value2 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $shell_call = $an->data->{path}{clustat};
	my $return     = [];
	my $details    = {};
	
	# If the 'target' is set, we'll call over SSH unless 'target' is 'local' or our hostname.
	if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
	{
		### Remote calls
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or die "Failed to call: [$shell_call], error was: $!\n";
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
		   $line =~ s/^\s+//;
		   $line =~ s/\s+$//;
		   $line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Header
		if ($line =~ /Cluster Status for (.*?) \@/)
		{
			$details->{cluster}{name} = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "details->cluster::name", value1 => $details->{cluster}{name}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /Member Status: (.*)$/)
		{
			my $quorate = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "quorate", value1 => $quorate, 
			}, file => $THIS_FILE, line => __LINE__});
			
			$details->{cluster}{quorate} = lc($quorate) eq "quorate" ? 1 : 0;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "details->cluster::quorate", value1 => $details->{cluster}{quorate}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Parse out nodes.
		if ($line =~ /^(.*?) (\d+) (.*)$/)
		{
			my $node_name  = $1;
			my $node_id    = $2;
			my $node_state = $3;
			my $cman       = $node_state =~ /online/i    ? 1 : 0;
			my $rgmanager  = $node_state =~ /rgmanager/i ? 1 : 0;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
				name1 => "node_name",  value1 => $node_name, 
				name2 => "node_id",    value2 => $node_id, 
				name3 => "node_state", value3 => $node_state, 
				name4 => "cman",       value4 => $cman, 
				name5 => "rgmanager",  value5 => $rgmanager, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Is this us or our peer?
			if ($node_state =~ /local/i)
			{
				# Us.
				$details->{node}{'local'} = {
					name      => $node_name,
					id        => $node_id,
					cman      => $cman,
					rgmanager => $rgmanager
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
				# Peer
				$details->{node}{peer} = {
					name      => $node_name,
					id        => $node_id,
					cman      => $cman,
					rgmanager => $rgmanager
				},
				$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
					name1 => "details->node::peer::name",      value1 => $details->{node}{peer}{name}, 
					name2 => "details->node::peer::id",        value2 => $details->{node}{peer}{id}, 
					name3 => "details->node::peer::cman",      value3 => $details->{node}{peer}{cman}, 
					name4 => "details->node::peer::rgmanager", value4 => $details->{node}{peer}{rgmanager}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Parse out services.
		if ($line =~ /service:(.*?) (.*?) (.*)$/)
		{
			my $service = $1;
			my $host    = $2;
			my $status  = $3;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "service", value1 => $service, 
				name2 => "host",    value2 => $host, 
				name3 => "status",  value3 => $status, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# If the service isn't starting, started or stopping, the host is useless.
			if (($status !~ /start/) && ($status !~ /stopping/))
			{
				$host = "";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "host", value1 => $host, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			# If the host is bracketed, it's not running and it is showing where it last ran. 
			# This doesn't matter to us.
			if ($host =~ /^\(.*\)$/)
			{
				$host = "";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "host", value1 => $host, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			$details->{service}{$service} = {
				host   => $host,
				status => $status,
			};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "details->service::${service}::host",   value1 => $details->{service}{$service}{host}, 
				name2 => "details->service::${service}::status", value2 => $details->{service}{$service}{status}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Parse out servers.
		if ($line =~ /vm:(.*?) (.*?) (.*)$/)
		{
			my $server = $1;
			my $host   = $2;
			my $status = $3;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "server", value1 => $server, 
				name2 => "host",   value2 => $host, 
				name3 => "status", value3 => $status, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# If the server isn't starting, started or stopping, the host is useless.
			if (($status !~ /start/) && ($status !~ /stopping/))
			{
				$host = "";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "host", value1 => $host, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			# If the host is bracketed, it's not running and it is showing where it last ran. 
			# This doesn't matter to us.
			if ($host =~ /^\(.*\)$/)
			{
				$host = "";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "host", value1 => $host, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			$details->{server}{$server} = {
				host   => $host,
				status => $status,
			};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "details->server::${server}::host",   value1 => $details->{server}{$server}{host}, 
				name2 => "details->server::${server}::status", value2 => $details->{server}{$server}{status}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return($details);
}

# This returns an array reference of the servers found on this Anvil!
sub get_cluster_server_list
{
	my $self      = shift;
	my $an        = $self->parent;
	
	my $servers = [];
	my $state   = {};
	my $shell_call = $an->data->{path}{clustat};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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

# This stops a server
sub stop_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	
	# This will store the shutdown output and return it to the caller.
	my $output   = "";
	my $return   = [];
	my $server   = $parameter->{server}   ? $parameter->{server}   : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $reason   = $parameter->{reason}   ? $parameter->{reason}   : "clear";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
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
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0071", code => 71, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	# This will disable the server.
	my $shell_call = $an->data->{path}{clusvcadm}." -d $server";
	
	# If the 'target' is set, we'll call over SSH unless 'target' is 'local' or our hostname.
	if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
	{
		### Remote calls
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
	}
	else
	{
		### Local calls
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or die "Failed to call: [$shell_call], error was: $!\n";
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		$output .= "$line\n";
	}
	
	# TODO: Handle stop failures
	my $details     = $an->Get->server_data({server => $server});
	my $server_uuid = $details->{uuid};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "server_uuid", value1 => $server_uuid, 
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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

# Withdraw a node from the cluster, using a delayed run that stops gfs2 and clvmd in case rgmanager gets stuck.
sub withdraw_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
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
	# we'll call '$an->Remote->delayed_run()' for at least 60 seconds in the future. This usually gives 
	# rgmanager the kick it needs to actually stop.
	my ($token, $delayed_run_output, $problem) = $an->Remote->delayed_run({
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or die "Failed to call: [$shell_call], error was: $!\n";
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /fail/i)
		{
			$rgmanager_stop = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "rgmanager_stop", value1 => $rgmanager_stop,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Now clear the delayed run, if rgmanager stopped, then stop cman.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "rgmanager_stop", value1 => $rgmanager_stop, 
		name2 => "token",          value2 => $token, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($rgmanager_stop)
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "token", value1 => $token,
		}, file => $THIS_FILE, line => __LINE__});
		if ($token)
		{
			my $shell_call = $an->data->{path}{'anvil-run-jobs'}." --abort $token";
			my $return     = [];
			
			if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
			{
				### Remote calls
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "shell_call", value1 => $shell_call, 
				}, file => $THIS_FILE, line => __LINE__});
				open (my $file_handle, "$shell_call 2>&1 |") or die "Failed to call: [$shell_call], error was: $!\n";
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
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call, 
			}, file => $THIS_FILE, line => __LINE__});
			open (my $file_handle, "$shell_call 2>&1 |") or die "Failed to call: [$shell_call], error was: $!\n";
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /fail/i)
			{
				$cman_stop = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "shell_call", value1 => $shell_call, 
				}, file => $THIS_FILE, line => __LINE__});
				open (my $file_handle, "$shell_call 2>&1 |") or die "Failed to call: [$shell_call], error was: $!\n";
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
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /fail/i)
				{
					$cman_start = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "recover", value1 => $recover,
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($recover)
				{
					# Failed to restart rgmanager...
					$return_code = 2;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "return_code", value1 => $return_code,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			else
			{
				# Failed to restart cman...
				$return_code = 2;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	else
	{
		# rgmanager failed to stop... Restart it
		$return_code = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "return_code", value1 => $return_code,
		}, file => $THIS_FILE, line => __LINE__});
		
		my ($recover, $recover_output) = $an->Cman->_recover_rgmanager({
			target   => $target, 
			port     => $port, 
			password => $password,
		});
		$output .= $recover_output;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "recover", value1 => $recover,
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($recover)
		{
			# Failed to restart rgmanager...
			$return_code = 2;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}

	# 0 == success
	# 1 == failed, restart succeeded.
	# 2 == failed, restart also failed.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
	
	my $return      = 0;
	my $boot_return = [];
	my $server      = $parameter->{server} ? $parameter->{server} : "";
	my $node        = $parameter->{node}   ? $parameter->{node}   : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "server", value1 => $server, 
		name2 => "node",   value2 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $shell_call = $an->data->{path}{clusvcadm}." -e $server -m $node";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		push @{$boot_return}, $line;
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "server_uuid", value1 => $server_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			}, file => $THIS_FILE, line => __LINE__});
			$return = 2;
			
			# Disable it
			my $shell_call = $an->data->{path}{clusvcadm}." -d $server";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call, 
			}, file => $THIS_FILE, line => __LINE__});
			open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
	
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or die "Failed to call: [$shell_call], error was: $!\n";
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /fail/i)
		{
			$return_code = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}

	# 0 == success
	# 1 == failed
	return($return_code, $output);
}

1;
