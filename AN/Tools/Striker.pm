package AN::Tools::Striker;
# 
# This module will contain methods used specifically for Striker (WebUI) related tasks.
# 

use strict;
use warnings;
use Data::Dumper;
use Text::Diff;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Striker.pm";

### Methods;
# access_all_upses
# build_local_host_list
# configure
# configure_ssh_local
# get_db_id_from_striker_conf
# load_anvil
# mark_node_as_clean_off
# mark_node_as_clean_on
# scan_anvil
# scan_node
# scan_servers
# update_peers
# update_striker_conf
### NOTE: All of these private methods are ports of functions from the old Striker.pm. None will be developed
###       further and all will be phased out over time. Do not use any of these in new dev work.
# _add_server_to_anvil
# _archive_file
# _change_server
# _check_lv
# _check_node_daemons
# _check_node_readiness
# _check_peer_access
# _cold_stop_anvil
# _confirm_cold_stop_anvil
# _confirm_delete_server
# _confirm_dual_boot
# _confirm_dual_join
# _confirm_fence_node
# _confirm_force_off_server
# _confirm_join_anvil
# _confirm_migrate_server
# _confirm_poweroff_node
# _confirm_poweron_node
# _confirm_provision_server
# _confirm_start_server
# _confirm_stop_server
# _confirm_withdraw_node
# _delete_server
# _display_anvil_safe_start_notice
# _display_details
# _display_drbd_details
# _display_free_resources
# _display_gfs2_details
# _display_node_controls
# _display_node_details
# _display_server_details
# _display_server_state_and_controls
# _display_watchdog_panel
# _dual_boot
# _dual_join
# _error
# _fence_node
# _find_preferred_host
# _force_off_server
# _gather_node_details
# _get_storage_data
# _get_striker_prefix_and_domain
# _header
# _join_anvil
# _manage_server
# _migrate_server
# _parse_anvil_safe_start
# _parse_clustat
# _parse_cluster_conf
# _parse_daemons
# _parse_drbdadm_dumpxml
# _parse_dmidecode
# _parse_gfs2
# _parse_hosts
# _parse_lvm_data
# _parse_lvm_scan
# _parse_meminfo
# _parse_proc_drbd
# _parse_server_defs
# _parse_server_defs_in_mem
# _parse_virsh
# _post_node_calculations
# _post_scan_calculations
# _poweroff_node
# _poweron_node
# _process_task
# _provision_server
# _read_server_definition
# _server_eject_media
# _server_insert_media
# _start_server
# _stop_server
# _update_network_driver
# _update_server_definition
# _verify_server_config
# _withdraw_node

#############################################################################################################
# House keeping methods                                                                                     #
#############################################################################################################

sub new
{
	my $class = shift;
	
	my $self  = {
	};
	
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

# This finds all the UPSes under an Anvil! system and pings them. If all are accessible, it returns '1'. If
# *any* can't be reached, it returns '0'. If no UPSes are found, it also returns '0'.
sub access_all_upses
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "access_all_upses" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ups_count = 0;
	my $access    = 1;
	my $upses     = $an->Get->upses({anvil_uuid => $an->data->{sys}{anvil}{uuid}});
	foreach my $ip (sort {$a cmp $b} keys %{$upses})
	{
		$ups_count++;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "ip",        value1 => $ip,
			name2 => "ups_count", value2 => $ups_count,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Can I ping the UPSes?
		my $ping = $an->Check->ping({ping => $ip});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "ping", value1 => $ping,
		}, file => $THIS_FILE, line => __LINE__});
		if ($ping)
		{
			foreach my $node_name (sort {$a cmp $b} keys %{$an->data->{node_name}})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "node_name", value1 => $node_name,
				}, file => $THIS_FILE, line => __LINE__});
				if (exists $an->data->{node_name}{$node_name}{upses}{$ip}{name})
				{
					# Mark this UPS as being accessible.
					$an->data->{node_name}{$node_name}{upses}{$ip}{can_ping} = 1;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "node_name::${node_name}::upses::${ip}::can_ping", value1 => $an->data->{node_name}{$node_name}{upses}{$ip}{can_ping},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		else
		{
			$access = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "access", value1 => $access,
			}, file => $THIS_FILE, line => __LINE__});
			
			foreach my $node_name (sort {$a cmp $b} keys %{$an->data->{node_name}})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "node_name", value1 => $node_name,
				}, file => $THIS_FILE, line => __LINE__});
				if (exists $an->data->{node_name}{$node_name}{upses}{$ip}{name})
				{
					# Mark this UPS as being inaccessible.
					$an->data->{node_name}{$node_name}{upses}{$ip}{can_ping} = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "node_name::${node_name}::upses::${ip}::can_ping", value1 => $an->data->{node_name}{$node_name}{upses}{$ip}{can_ping},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
	}
	
	# Set '0' if no UPSes were found.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ups_count", value1 => $ups_count,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $ups_count)
	{
		$access = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "access", value1 => $access,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "access", value1 => $access,
	}, file => $THIS_FILE, line => __LINE__});
	return($access);
}

# This builds a list of possible host names and IPs that other machines might call us by and returns the list
# in an array reference.
sub build_local_host_list
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "build_local_host_list" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ip_list        = $an->System->get_local_ip_addresses();
	my $possible_hosts = [];
	push @{$possible_hosts}, $an->hostname;
	push @{$possible_hosts}, $an->short_hostname;
	foreach my $device (sort {$a cmp $b} keys %{$ip_list})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "ip_list->$device", value1 => $ip_list->{$device}, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$possible_hosts}, $ip_list->{$device};
	}
	
	### DEBUG
	foreach my $host (sort {$a cmp $b} @{$possible_hosts})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "host", value1 => $host, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return($possible_hosts);
}

# This presents and manages the 'configure' component of Striker.
sub configure
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	
	
	return(0);
}

# This calls 'striker-push-ssh'
sub configure_ssh_local
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_ssh_local" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Exit if we weren't given an Anvil! name,
	if (not $parameter->{anvil_name})
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0123", code => 123, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	my $output       = "";
	my $anvil_name   = $parameter->{anvil_name}           ? $parameter->{anvil_name}           : "";
	my $remove_hosts = $parameter->{remove_hosts}         ? $parameter->{remove_hosts}         : 0;
	my $node1_name   = $an->data->{cgi}{anvil_node1_name} ? $an->data->{cgi}{anvil_node1_name} : "";
	my $node2_name   = $an->data->{cgi}{anvil_node2_name} ? $an->data->{cgi}{anvil_node2_name} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "anvil_name",   value1 => $anvil_name,
		name2 => "remove_hosts", value2 => $remove_hosts,
		name3 => "node1_name",   value3 => $node1_name,
		name4 => "node2_name",   value4 => $node2_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Add the user's SSH keys to the new anvil! (will simply exit if disabled in striker.conf).
	my $shell_call = $an->data->{path}{'call_striker-push-ssh'}." --anvil $anvil_name";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		$output .= "$line\n";
	}
	close $file_handle;
	
	return($output);
}

# This takes an array reference of names/IPs and tries to match it to a 'scancore::db::X::host' entry. If it 
# is found, 'X' is returned.
sub get_db_id_from_striker_conf
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "load_anvil" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $hosts    = $parameter->{hosts}    ? $parameter->{hosts}    : "";
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
	
	# Make sure I have at least one host
	if (ref($hosts) ne "ARRAY")
	{
		# Not an array
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0205", code => 205, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	elsif (@{$hosts} < 1)
	{
		# Nothing in the array
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0206", code => 206, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	my $db_id       = "";
	my $return_code = 255;
	my $return      = [];
	my $shell_call  = $an->data->{path}{cat}." ".$an->data->{path}{striker_config};
	if ($target)
	{
		# Remote call.
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
		# Local call
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			push @{$return}, $line;
		}
		close $file_handle;
	}
	foreach my $line (@{$return})
	{
		### WARNING: This exposes passwords!
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^scancore::db::(\d+)::host\s*=\s*(.*)$/)
		{
			my $this_db_id = $1;
			my $this_host  = $2;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "this_db_id", value1 => $this_db_id, 
				name2 => "this_host",  value2 => $this_host, 
			}, file => $THIS_FILE, line => __LINE__});
			
			foreach my $host (sort {$a cmp $b} @{$hosts})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "this_host", value1 => $this_host, 
					name2 => "host",      value2 => $host, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($host eq $this_host)
				{
					$db_id = $this_db_id;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "db_id", value1 => $db_id, 
					}, file => $THIS_FILE, line => __LINE__});
					last;
				}
			}
		}
		last if $db_id;
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "db_id", value1 => $db_id, 
	}, file => $THIS_FILE, line => __LINE__});
	return($db_id);
}

# This uses the 'cgi::anvil_uuid' to load the anvil data into the active system variables.
sub load_anvil
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "load_anvil" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Did the user specify an anvil_uuid?
	my $anvil_uuid = $parameter->{anvil_uuid} ? $parameter->{anvil_uuid} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If not, is the CGI variable set?
	if ((not $anvil_uuid) && ($an->data->{cgi}{anvil_uuid}))
	{
		$anvil_uuid = $an->data->{cgi}{anvil_uuid};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "anvil_uuid", value1 => $anvil_uuid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# If we've already loaded this Anvil!, return now.
	if ((defined $an->data->{sys}{anvil}{uuid}) && ($an->data->{sys}{anvil}{uuid} eq $anvil_uuid))
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::anvil::uuid", value1 => $an->data->{sys}{anvil}{uuid},
		}, file => $THIS_FILE, line => __LINE__});
		return(0);
	}
	
	# If we still don't have an anvil_uuid, see if this is an Anvil! node and, if so, if we can locate 
	# the anvil_uuid by matching the cluster name to an entry in 'anvils'.
	if (not $anvil_uuid)
	{
		# See if we can divine the UUID by reading the cluster name from the local cluster.conf, if 
		# it exists.
		my $cluster_name = $an->Cman->cluster_name();
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cluster_name", value1 => $cluster_name,
		}, file => $THIS_FILE, line => __LINE__});
		
		my $anvil_data = $an->ScanCore->get_anvils();
		foreach my $hash_ref (@{$anvil_data})
		{
			my $anvil_name = $hash_ref->{anvil_name};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "anvil_name", value1 => $anvil_name,
			}, file => $THIS_FILE, line => __LINE__});

			if ($anvil_name eq $cluster_name)
			{
				# Found it.
				$anvil_uuid = $hash_ref->{anvil_uuid};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "anvil_uuid", value1 => $anvil_uuid,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Did we find it?
		if (not $anvil_uuid)
		{
			# Nope ;_;
			$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0102", code => 102, file => $THIS_FILE, line => __LINE__});
			return(1);
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "anvils::${anvil_uuid}::name", value1 => $an->data->{anvils}{$anvil_uuid}{name},
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->Validate->is_uuid({uuid => $anvil_uuid}))
	{
		# Value read, but it isn't a UUID.
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0103", message_variables => { uuid => $anvil_uuid }, code => 103, file => $THIS_FILE, line => __LINE__});
		return(1);
	}
	elsif (not $an->data->{anvils}{$anvil_uuid}{name})
	{
		# Load Anvil! data and try again.
		$an->ScanCore->parse_anvil_data();
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "anvils::${anvil_uuid}::name", value1 => $an->data->{anvils}{$anvil_uuid}{name}, 
		}, file => $THIS_FILE, line => __LINE__});
		if (not $an->data->{anvils}{$anvil_uuid}{name})
		{
			# Valid UUID, but it doesn't match a known Anvil!.
			$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0104", message_variables => { uuid => $anvil_uuid }, code => 104, file => $THIS_FILE, line => __LINE__});
			return(1);
		}
	}
	
	# Last test; Do I know about my nodes? If this is the root user calling us, don't die (because it is 
	# ScanCore or a command line tool).
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "anvils::${anvil_uuid}::node1::name", value1 => $an->data->{anvils}{$anvil_uuid}{node1}{name},
		name2 => "anvils::${anvil_uuid}::node2::name", value2 => $an->data->{anvils}{$anvil_uuid}{node2}{name},
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $an->data->{anvils}{$anvil_uuid}{node1}{name}) or (not $an->data->{anvils}{$anvil_uuid}{node2}{name}))
	{
		if (($>) or ($<))
		{
			# Remind the user to run ScanCore on the nodes.
			$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0176", code => 176, file => $THIS_FILE, line => __LINE__});
			return(1);
		}
		else
		{
			# Nothing more to do.
			return("");
		}
	}
	
	# Variables
	$an->data->{sys}{anvil}{uuid}                 = $anvil_uuid;
	$an->data->{sys}{anvil}{name}                 = $an->data->{anvils}{$anvil_uuid}{name};
	$an->data->{sys}{anvil}{description}          = $an->data->{anvils}{$anvil_uuid}{description};
	$an->data->{sys}{anvil}{note}                 = $an->data->{anvils}{$anvil_uuid}{note};
	$an->data->{sys}{anvil}{owner}{name}          = $an->data->{anvils}{$anvil_uuid}{owner}{name};
	$an->data->{sys}{anvil}{owner}{note}          = $an->data->{anvils}{$anvil_uuid}{owner}{note};
	$an->data->{sys}{anvil}{smtp}{server}         = $an->data->{anvils}{$anvil_uuid}{smtp}{server};
	$an->data->{sys}{anvil}{smtp}{port}           = $an->data->{anvils}{$anvil_uuid}{smtp}{port};
	$an->data->{sys}{anvil}{smtp}{alt_server}     = $an->data->{anvils}{$anvil_uuid}{smtp}{alt_server};
	$an->data->{sys}{anvil}{smtp}{alt_port}       = $an->data->{anvils}{$anvil_uuid}{smtp}{alt_port};
	$an->data->{sys}{anvil}{smtp}{username}       = $an->data->{anvils}{$anvil_uuid}{smtp}{username};
	$an->data->{sys}{anvil}{smtp}{security}       = $an->data->{anvils}{$anvil_uuid}{smtp}{security};
	$an->data->{sys}{anvil}{smtp}{authentication} = $an->data->{anvils}{$anvil_uuid}{smtp}{authentication};
	$an->data->{sys}{anvil}{smtp}{helo_domain}    = $an->data->{anvils}{$anvil_uuid}{smtp}{helo_domain};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0014", message_variables => {
		name1  => "sys::anvil::uuid",                 value1  => $an->data->{sys}{anvil}{uuid}, 
		name2  => "sys::anvil::name",                 value2  => $an->data->{sys}{anvil}{name}, 
		name3  => "sys::anvil::description",          value3  => $an->data->{sys}{anvil}{description}, 
		name4  => "sys::anvil::note",                 value4  => $an->data->{sys}{anvil}{note}, 
		name5  => "sys::anvil::owner::name",          value5  => $an->data->{sys}{anvil}{owner}{name}, 
		name6  => "sys::anvil::owner::note",          value6  => $an->data->{sys}{anvil}{owner}{note}, 
		name7  => "sys::anvil::smtp::server",         value7  => $an->data->{sys}{anvil}{smtp}{server}, 
		name8  => "sys::anvil::smtp::port",           value8  => $an->data->{sys}{anvil}{smtp}{port}, 
		name9  => "sys::anvil::smtp::alt_server",     value9  => $an->data->{sys}{anvil}{smtp}{alt_server}, 
		name10 => "sys::anvil::smtp::alt_port",       value10 => $an->data->{sys}{anvil}{smtp}{alt_port}, 
		name11 => "sys::anvil::smtp::username",       value11 => $an->data->{sys}{anvil}{smtp}{username}, 
		name12 => "sys::anvil::smtp::security",       value12 => $an->data->{sys}{anvil}{smtp}{security}, 
		name13 => "sys::anvil::smtp::authentication", value13 => $an->data->{sys}{anvil}{smtp}{authentication}, 
		name14 => "sys::anvil::smtp::helo_domain",    value14 => $an->data->{sys}{anvil}{smtp}{helo_domain}, 
	}, file => $THIS_FILE, line => __LINE__});
		
	# Passwords
	$an->data->{sys}{anvil}{password}       = $an->data->{anvils}{$anvil_uuid}{password};
	$an->data->{sys}{anvil}{smtp}{password} = $an->data->{anvils}{$anvil_uuid}{smtp}{password};
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "sys::anvil::password",       value1 => $an->data->{sys}{anvil}{password}, 
		name2 => "sys::anvil::smtp::password", value2 => $an->data->{sys}{anvil}{smtp}{password}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	foreach my $node_key ("node1", "node2")
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "node_key",   value1 => $node_key, 
			name2 => "anvil_uuid", value2 => $anvil_uuid, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->data->{sys}{anvil}{$node_key}{uuid}           =  $an->data->{anvils}{$anvil_uuid}{$node_key}{uuid};	# node_uuid
		$an->data->{sys}{anvil}{$node_key}{name}           =  $an->data->{anvils}{$anvil_uuid}{$node_key}{name};
		$an->data->{sys}{anvil}{$node_key}{short_name}     =  $an->data->{anvils}{$anvil_uuid}{$node_key}{name};
		$an->data->{sys}{anvil}{$node_key}{short_name}     =~ s/\..*//;
		$an->data->{sys}{anvil}{$node_key}{remote_ip}      =  $an->data->{anvils}{$anvil_uuid}{$node_key}{remote_ip};
		$an->data->{sys}{anvil}{$node_key}{remote_port}    =  $an->data->{anvils}{$anvil_uuid}{$node_key}{remote_port};
		$an->data->{sys}{anvil}{$node_key}{note}           =  $an->data->{anvils}{$anvil_uuid}{$node_key}{note};
		$an->data->{sys}{anvil}{$node_key}{bcn_ip}         =  $an->data->{anvils}{$anvil_uuid}{$node_key}{bcn_ip};
		$an->data->{sys}{anvil}{$node_key}{sn_ip}          =  $an->data->{anvils}{$anvil_uuid}{$node_key}{sn_ip};
		$an->data->{sys}{anvil}{$node_key}{ifn_ip}         =  $an->data->{anvils}{$anvil_uuid}{$node_key}{ifn_ip};
		$an->data->{sys}{anvil}{$node_key}{type}           =  $an->data->{anvils}{$anvil_uuid}{$node_key}{type};
		$an->data->{sys}{anvil}{$node_key}{health}         =  $an->data->{anvils}{$anvil_uuid}{$node_key}{health};
		$an->data->{sys}{anvil}{$node_key}{emergency_stop} =  $an->data->{anvils}{$anvil_uuid}{$node_key}{emergency_stop};
		$an->data->{sys}{anvil}{$node_key}{stop_reason}    =  $an->data->{anvils}{$anvil_uuid}{$node_key}{stop_reason};
		$an->data->{sys}{anvil}{$node_key}{use_ip}         =  $an->data->{anvils}{$anvil_uuid}{$node_key}{use_ip};
		$an->data->{sys}{anvil}{$node_key}{use_port}       =  $an->data->{anvils}{$anvil_uuid}{$node_key}{use_port};
		$an->data->{sys}{anvil}{$node_key}{online}         =  $an->data->{anvils}{$anvil_uuid}{$node_key}{online};
		$an->data->{sys}{anvil}{$node_key}{power}          =  $an->data->{anvils}{$anvil_uuid}{$node_key}{power};
		$an->data->{sys}{anvil}{$node_key}{host_uuid}      =  $an->data->{anvils}{$anvil_uuid}{$node_key}{host_uuid};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0018", message_variables => {
			name1  => "sys::anvil::${node_key}::uuid",           value1  => $an->data->{sys}{anvil}{$node_key}{uuid}, 
			name2  => "sys::anvil::${node_key}::name",           value2  => $an->data->{sys}{anvil}{$node_key}{name}, 
			name3  => "sys::anvil::${node_key}::short_name",     value3  => $an->data->{sys}{anvil}{$node_key}{short_name}, 
			name4  => "sys::anvil::${node_key}::remote_ip",      value4  => $an->data->{sys}{anvil}{$node_key}{remote_ip}, 
			name5  => "sys::anvil::${node_key}::remote_port",    value5  => $an->data->{sys}{anvil}{$node_key}{remote_port}, 
			name6  => "sys::anvil::${node_key}::note",           value6  => $an->data->{sys}{anvil}{$node_key}{note}, 
			name7  => "sys::anvil::${node_key}::bcn_ip",         value7  => $an->data->{sys}{anvil}{$node_key}{bcn_ip}, 
			name8  => "sys::anvil::${node_key}::sn_ip",          value8  => $an->data->{sys}{anvil}{$node_key}{sn_ip}, 
			name9  => "sys::anvil::${node_key}::ifn_ip",         value9  => $an->data->{sys}{anvil}{$node_key}{ifn_ip}, 
			name10 => "sys::anvil::${node_key}::type",           value10 => $an->data->{sys}{anvil}{$node_key}{type}, 
			name11 => "sys::anvil::${node_key}::health",         value11 => $an->data->{sys}{anvil}{$node_key}{health}, 
			name12 => "sys::anvil::${node_key}::emergency_stop", value12 => $an->data->{sys}{anvil}{$node_key}{emergency_stop}, 
			name13 => "sys::anvil::${node_key}::stop_reason",    value13 => $an->data->{sys}{anvil}{$node_key}{stop_reason}, 
			name14 => "sys::anvil::${node_key}::use_ip",         value14 => $an->data->{sys}{anvil}{$node_key}{use_ip}, 
			name15 => "sys::anvil::${node_key}::use_port",       value15 => $an->data->{sys}{anvil}{$node_key}{use_port}, 
			name16 => "sys::anvil::${node_key}::online",         value16 => $an->data->{sys}{anvil}{$node_key}{online}, 
			name17 => "sys::anvil::${node_key}::power",          value17 => $an->data->{sys}{anvil}{$node_key}{power}, 
			name18 => "sys::anvil::${node_key}::host_uuid",      value18 => $an->data->{sys}{anvil}{$node_key}{host_uuid}, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Password
		$an->data->{sys}{anvil}{$node_key}{password} = $an->data->{anvils}{$anvil_uuid}{$node_key}{password};
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::anvil::${node_key}::password", value1 => $an->data->{sys}{anvil}{$node_key}{password}, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Make the node UUID, node key and peer key easy to get from the node name. First, setup some
		# variables.
		my $node_uuid = $an->data->{sys}{anvil}{$node_key}{uuid};
		my $node_name = $an->data->{sys}{anvil}{$node_key}{name};
		my $peer_key  = $node_key eq "node1" ? "node2" : "node1";
		
		# Now store the data.
		$an->data->{sys}{node_name}{$node_name}{uuid}          = $node_uuid;
		$an->data->{sys}{node_name}{$node_name}{node_key}      = $node_key;
		$an->data->{sys}{node_name}{$node_name}{peer_node_key} = $peer_key;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "sys::node_name::${node_name}::uuid",          value1 => $an->data->{sys}{node_name}{$node_name}{uuid}, 
			name2 => "sys::node_name::${node_name}::node_key",      value2 => $an->data->{sys}{node_name}{$node_name}{node_key}, 
			name3 => "sys::node_name::${node_name}::peer_node_key", value3 => $an->data->{sys}{node_name}{$node_name}{peer_node_key}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return(0);
}

### TODO: Fix the calls to this method to pass in the host_uuid, NOT the node_uuid...
# Update the ScanCore database(s) to mark the node's (hosts -> host_stop_reason = 'clean') so that they don't
# just turn right back on.
sub mark_node_as_clean_off
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "mark_node_as_clean_off" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid   = $parameter->{node_uuid}   ? $parameter->{node_uuid}   : "";
	my $delay       = $parameter->{delay}       ? $parameter->{delay}       : 0;
	my $stop_reason = $parameter->{stop_reason} ? $parameter->{stop_reason} : "clean";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node_uuid",   value1 => $node_uuid,
		name2 => "delay",       value2 => $delay,
		name3 => "stop_reason", value3 => $stop_reason,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $node_uuid)
	{
		# Nothing passed in or set in CGI
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0114", code => 114, file => $THIS_FILE, line => __LINE__});
		return(1);
	}
	elsif (not $an->Validate->is_uuid({uuid => $node_uuid}))
	{
		# Value read, but it isn't a UUID.
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0115", message_variables => { uuid => $node_uuid }, code => 115, file => $THIS_FILE, line => __LINE__});
		return(1);
	}
	
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	if (not $node_name)
	{
		# Valid UUID, but it doesn't match a known Anvil!.
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0116", message_variables => { uuid => $node_uuid }, code => 116, file => $THIS_FILE, line => __LINE__});
		return(1);
	}

	# Update the hosts entry.
	if ($delay)
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::power_off_delay", value1 => $an->data->{sys}{power_off_delay},
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->data->{sys}{power_off_delay} = 300 if not $an->data->{sys}{power_off_delay};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::power_off_delay", value1 => $an->data->{sys}{power_off_delay},
		}, file => $THIS_FILE, line => __LINE__});
		
		$stop_reason = time + $an->data->{sys}{power_off_delay};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "stop_reason", value1 => $stop_reason,
		}, file => $THIS_FILE, line => __LINE__});
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "stop_reason", value1 => $stop_reason,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $query = "
UPDATE 
    hosts 
SET 
    host_emergency_stop = FALSE, 
    host_stop_reason    = ".$an->data->{sys}{use_db_fh}->quote($stop_reason).", 
    host_health         = 'shutdown', 
    modified_date       = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
WHERE 
    host_uuid = (
        SELECT 
            node_host_uuid 
        FROM 
            nodes 
        WHERE 
            node_uuid = ".$an->data->{sys}{use_db_fh}->quote($node_uuid)."
        )
;";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	
	return(0);
}

# Update the ScanCore database(s) to mark the node's (hosts -> host_stop_reason = NULL) so that they turn on
# if they're suddenly found to be off.
sub mark_node_as_clean_on
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "mark_node_as_clean_on" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### TODO: Fix this mess...
	### NOTE: I made this confusing by calling this 'node_uuid' when it is really the 'host_uuid'. So
	###       we'll check the UUID against both nodes and hosts for now.
	my $host_uuid = $parameter->{node_uuid} ? $parameter->{node_uuid} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "host_uuid", value1 => $host_uuid,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $host_uuid)
	{
		# Nothing passed in or set in CGI
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0117", code => 117, file => $THIS_FILE, line => __LINE__});
		return(1);
	}
	elsif (not $an->Validate->is_uuid({uuid => $host_uuid}))
	{
		# Value read, but it isn't a UUID.
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0118", message_variables => { uuid => $host_uuid }, code => 118, file => $THIS_FILE, line => __LINE__});
		return(1);
	}
	
	# Don't set another node's stack if this machine is itself a node.
	my $i_am_a = $an->Get->what_am_i();
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "i_am_a",         value1 => $i_am_a, 
		name2 => "sys::host_uuid", value2 => $an->data->{sys}{host_uuid}, 
	}, file => $THIS_FILE, line => __LINE__});
	if (($i_am_a eq "node") && ($host_uuid ne $an->data->{sys}{host_uuid}))
	{
		# Don't proceed.
		$an->Log->entry({log_level => 1, message_key => "tools_log_0035", message_variables => { host_uuid => $host_uuid }, file => $THIS_FILE, line => __LINE__});
		return(0);
	}
	
	my $node_data = $an->ScanCore->get_nodes();
	my $host_data = $an->ScanCore->get_hosts();
	my $node_name = "";
	foreach my $hash_ref (@{$host_data})
	{
		my $this_host_uuid = $hash_ref->{host_uuid};
		my $this_host_name = $hash_ref->{host_name};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "this_host_uuid", value1 => $this_host_uuid, 
			name2 => "this_host_name", value2 => $this_host_name, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($this_host_uuid eq $host_uuid)
		{
			# We're good.
			$node_name = $this_host_name;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "node_name", value1 => $node_name, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "node_name", value1 => $node_name, 
	}, file => $THIS_FILE, line => __LINE__});
	if (not $node_name)
	{
		# See if this is a node_uuid instead of a host_uuid.
		foreach my $hash_ref (@{$node_data})
		{
			my $this_node_name      = $hash_ref->{host_name};
			my $this_node_uuid      = $hash_ref->{node_uuid};
			my $this_node_host_uuid = $hash_ref->{node_host_uuid}; 
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "this_node_name",      value1 => $this_node_name, 
				name2 => "this_node_uuid",      value2 => $this_node_uuid, 
				name3 => "this_node_host_uuid", value3 => $this_node_host_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($this_node_uuid eq $host_uuid)
			{
				# Found it. Switch the active node UUID out.
				$node_name = $this_node_name;
				$host_uuid = $this_node_host_uuid;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "node_name", value1 => $node_name, 
					name2 => "host_uuid", value2 => $host_uuid, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# If I still don't have a node name, well, crap.
	if (not $node_name)
	{
		# Valid UUID, but it doesn't match a known Anvil!.
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0119", message_variables => { uuid => $host_uuid }, code => 119, file => $THIS_FILE, line => __LINE__});
		return(1);
	}
	
	# Get the current health and stop reason.
	my $query = "
SELECT 
    host_health, 
    host_stop_reason, 
    host_emergency_stop, 
    round(extract(epoch from modified_date)) 
FROM 
    hosts 
WHERE 
    host_uuid = ".$an->data->{sys}{use_db_fh}->quote($host_uuid)."
;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query, 
	}, file => $THIS_FILE, line => __LINE__});
		
	my $results            = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
	my $old_health         = "";
	my $old_stop_reason    = "";
	my $old_emergency_stop = "";
	my $unix_modified_date = "";
	foreach my $row (@{$results})
	{
		$old_health         = defined $row->[0] ? $row->[0] : "";
		$old_stop_reason    = defined $row->[1] ? $row->[1] : "";
		$old_emergency_stop = defined $row->[2] ? $row->[2] : "";
		$unix_modified_date =         $row->[3];
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "old_health",         value1 => $old_health, 
			name2 => "old_stop_reason",    value2 => $old_stop_reason, 
			name3 => "old_emergency_stop", value3 => $old_emergency_stop, 
			name4 => "unix_modified_date", value4 => $unix_modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	my $current_time = time;
	my $record_age   = 0;
	if ($unix_modified_date)
	{
		$record_age = $current_time - $unix_modified_date;
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "current_time", value1 => $current_time, 
		name2 => "record_age",   value2 => $record_age, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If the stop_reason is 'clean' and that was set less than fine minutes ago, don't clear the stop
	# reason as the host might still be shutting down.
	if (($old_stop_reason eq "clean") && ($record_age) && ($record_age < 300))
	{
		$an->Log->entry({log_level => 2, message_key => "tools_log_0034", message_variables => { 
			host_uuid => $host_uuid,
			seconds   => $record_age,
		}, file => $THIS_FILE, line => __LINE__});
		return(0);
	}
	
	# If the old stop reason is a time stamp and if that time stamp is in the future, abort.
	if ($old_stop_reason =~ /^\d+$/)
	{
		my $time       = time;
		my $difference = time - $old_stop_reason;
		### NOTE: Customer requested, move to 2 before v2.0 release
		$an->Log->entry({log_level => 1, message_key => "an_variables_0003", message_variables => {
			name1 => "time",            value1 => $time, 
			name2 => "old_stop_reason", value2 => $old_stop_reason, 
			name3 => "difference",      value3 => $difference, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($time < $old_stop_reason)
		{
			# We're still waiting, don't do anything.
			$an->Log->entry({log_level => 2, message_key => "tools_log_0033", message_variables => { node => $node_name }, file => $THIS_FILE, line => __LINE__});
			return(0);
		}
	}
	
	if (($old_stop_reason) or ($old_health eq "shutdown") or ($old_emergency_stop))
	{
		# Update the hosts entry.
		$query = "
UPDATE 
    hosts 
SET 
    host_emergency_stop = FALSE, 
    host_stop_reason    = NULL, 
    host_health         = 'ok', 
    modified_date       = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
WHERE 
    host_uuid = ".$an->data->{sys}{use_db_fh}->quote($host_uuid)."
;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	}
	
	return(0);
}

# This does a full manual scan of an Anvil! system.
sub scan_anvil
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "scan_anvil" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Show the 'scanning in progress' table.
	print $an->Web->template({file => "common.html", template => "scanning-message", replace => {
		anvil_message => $an->String->get({key => "message_0272", variables => { anvil => $an->data->{sys}{anvil}{name} }}),
	}});
	
	# Check the power state of both nodes. If either report 'on', we'll do a full scan.
	my $node1_state = $an->ScanCore->target_power({target => $an->data->{sys}{anvil}{node1}{uuid}});
	my $node2_state = $an->ScanCore->target_power({target => $an->data->{sys}{anvil}{node2}{uuid}});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_state", value1 => $node1_state, 
		name2 => "node2_state", value2 => $node2_state, 
	}, file => $THIS_FILE, line => __LINE__});
	if (($node1_state eq "off") && ($node2_state eq "off"))
	{
		# Neither node is up. If I can power them on, then I will show the node section to enable 
		# power up.
		if (($node1_state eq "unknown") or ($node2_state eq "unknown"))
		{	
			print $an->Web->template({file => "main-page.html", template => "no-access-message", replace => { 
				anvil	=>	$an->data->{sys}{anvil}{name},
				message	=>	"#!string!message_0029!#",
			}});
		}
		if ($node1_state eq "off")
		{
			my $node1_name = $an->data->{sys}{anvil}{node1}{name};
			$an->data->{node}{$node1_name}{enable_poweron} = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node1_name}::enable_poweron", value1 => $an->data->{node}{$node1_name}{enable_poweron}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($node2_state eq "off")
		{
			my $node2_name = $an->data->{sys}{anvil}{node2}{name};
			$an->data->{node}{$node2_name}{enable_poweron} = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node2_name}::enable_poweron", value1 => $an->data->{node}{$node2_name}{enable_poweron}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		return(1);
	}
	
	# Still here? Start your engines!
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "sys::anvil::node1::uuid", value1 => $an->data->{sys}{anvil}{node1}{uuid},
		name2 => "sys::anvil::node2::uuid", value2 => $an->data->{sys}{anvil}{node2}{uuid},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Striker->scan_node({uuid => $an->data->{sys}{anvil}{node1}{uuid}});
	$an->Striker->scan_node({uuid => $an->data->{sys}{anvil}{node2}{uuid}});
	
	my $anvil_name   = $an->data->{sys}{anvil}{name};
	my $node1_name   = $an->data->{sys}{anvil}{node1}{name};
	my $node1_online = $an->data->{sys}{anvil}{node1}{online};
	my $node2_name   = $an->data->{sys}{anvil}{node2}{name};
	my $node2_online = $an->data->{sys}{anvil}{node2}{online};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "anvil_name",   value1 => $anvil_name,
		name2 => "node1_name",   value2 => $node1_name,
		name3 => "node1_online", value3 => $node1_online,
		name4 => "node2_name",   value4 => $node2_name,
		name5 => "node2_online", value5 => $node2_online,
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->data->{sys}{up_nodes}     = @{$an->data->{up_nodes}};
	$an->data->{sys}{online_nodes} = @{$an->data->{online_nodes}};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "up nodes",          value1 => $an->data->{sys}{up_nodes},
		name2 => "sys::online_nodes", value2 => $an->data->{sys}{online_nodes},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{up_nodes} > 0)
	{
		$an->Striker->scan_servers();
		$an->Striker->_post_scan_calculations();
	}

	return(0);
}

# This attempts to gather all information about a node.
sub scan_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "scan_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = defined $parameter->{uuid}       ? $parameter->{uuid}       : "";
	my $short_scan = defined $parameter->{short_scan} ? $parameter->{short_scan} : 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_uuid",  value1 => $node_uuid,
		name2 => "short_scan", value2 => $short_scan,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $node_uuid)
	{
		# Nothing passed in or set in CGI
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0105", code => 105, file => $THIS_FILE, line => __LINE__});
		return(1);
	}
	elsif (not $an->Validate->is_uuid({uuid => $node_uuid}))
	{
		# Value read, but it isn't a UUID.
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0106", message_variables => { uuid => $node_uuid }, code => 106, file => $THIS_FILE, line => __LINE__});
		return(1);
	}
	elsif (not $an->data->{db}{nodes}{$node_uuid}{name})
	{
		# Valid UUID, but it doesn't match a known Anvil!.
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0107", message_variables => { uuid => $node_uuid }, code => 107, file => $THIS_FILE, line => __LINE__});
		return(1);
	}
	
	# First, see how to access the node.
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $node_key  = $node_uuid eq $an->data->{sys}{anvil}{node1}{uuid} ? "node1" : "node2";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name", value1 => $node_name, 
		name2 => "node_key",  value2 => $node_key, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# See if I have a cached 'access' data.
	my $cached_access = $an->ScanCore->read_cache({target => $node_uuid, type => "access"});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cached_access", value1 => $cached_access, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($cached_access)
	{
		# If this fails, we'll walk our various connections.
		my $target   = $cached_access;
		my $port     = 22;
		my $password = $an->data->{sys}{anvil}{$node_key}{password};
		if ($target =~ /^(.*?):(\d+)$/)
		{
			$target = $1;
			$port   = $2;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "target", value1 => $target, 
				name2 => "port",   value2 => $port, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "target", value1 => $target, 
			name2 => "port",   value2 => $port, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password, 
		}, file => $THIS_FILE, line => __LINE__});
		my $access = $an->Check->access({
				target   => $target,
				port     => $port,
				password => $password,
			});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "access", value1 => $access, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($access)
		{
			$an->data->{sys}{anvil}{$node_key}{use_ip}   = $target;
			$an->data->{sys}{anvil}{$node_key}{use_port} = $port; 
			$an->data->{sys}{anvil}{$node_key}{online}   = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "sys::anvil::${node_key}::use_ip",   value1 => $an->data->{sys}{anvil}{$node_key}{use_ip}, 
				name2 => "sys::anvil::${node_key}::use_port", value2 => $an->data->{sys}{anvil}{$node_key}{use_port}, 
				name3 => "sys::anvil::${node_key}::online",   value3 => $an->data->{sys}{anvil}{$node_key}{online}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If I don't have access (no cache or cache didn't work), walk through the networks.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::anvil::${node_key}::online", value1 => $an->data->{sys}{anvil}{$node_key}{online}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{anvil}{$node_key}{online})
	{
		# Make sure it is marked as up (if I am a dashboard).
		my $i_am_a = $an->Get->what_am_i();
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "i_am_a",         value1 => $i_am_a, 
			name2 => "sys::host_uuid", value2 => $an->data->{sys}{host_uuid}, 
		}, file => $THIS_FILE, line => __LINE__});
		if (($i_am_a eq "dashboard") or ($an->data->{sys}{host_uuid} eq $an->data->{sys}{anvil}{$node_key}{host_uuid}))
		{
			$an->Striker->mark_node_as_clean_on({node_uuid => $an->data->{sys}{anvil}{$node_key}{host_uuid}});
		}
	}
	else
	{
		# BCN first.
		my $bcn_access = $an->Check->access({
				target   => $an->data->{sys}{anvil}{$node_key}{bcn_ip},
				port     => 22,
				password => $an->data->{sys}{anvil}{$node_key}{password},
			});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "bcn_access", value1 => $bcn_access, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($bcn_access)
		{
			# Woot
			$an->data->{sys}{anvil}{$node_key}{use_ip}   = $an->data->{sys}{anvil}{$node_key}{bcn_ip};
			$an->data->{sys}{anvil}{$node_key}{use_port} = 22; 
			$an->data->{sys}{anvil}{$node_key}{online}   = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "sys::anvil::${node_key}::use_ip",   value1 => $an->data->{sys}{anvil}{$node_key}{use_ip}, 
				name2 => "sys::anvil::${node_key}::use_port", value2 => $an->data->{sys}{anvil}{$node_key}{use_port}, 
				name3 => "sys::anvil::${node_key}::online",   value3 => $an->data->{sys}{anvil}{$node_key}{online}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Try the IFN
			my $ifn_access = $an->Check->access({
					target   => $an->data->{sys}{anvil}{$node_key}{ifn_ip},
					port     => 22,
					password => $an->data->{sys}{anvil}{$node_key}{password},
				});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "ifn_access", value1 => $ifn_access, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($ifn_access)
			{
				# Woot
				$an->data->{sys}{anvil}{$node_key}{use_ip}   = $an->data->{sys}{anvil}{$node_key}{ifn_ip};
				$an->data->{sys}{anvil}{$node_key}{use_port} = 22; 
				$an->data->{sys}{anvil}{$node_key}{online}   = 1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "sys::anvil::${node_key}::use_ip",   value1 => $an->data->{sys}{anvil}{$node_key}{use_ip}, 
					name2 => "sys::anvil::${node_key}::use_port", value2 => $an->data->{sys}{anvil}{$node_key}{use_port}, 
					name3 => "sys::anvil::${node_key}::online",   value3 => $an->data->{sys}{anvil}{$node_key}{online}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Try the remote IP/Port, if set.
				if ($an->data->{sys}{anvil}{$node_key}{remote_ip})
				{
					my $remote_access = $an->Check->access({
							target   => $an->data->{sys}{anvil}{$node_key}{remote_ip},
							port     => $an->data->{sys}{anvil}{$node_key}{remote_port},
							password => $an->data->{sys}{anvil}{$node_key}{password},
						});
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "remote_access", value1 => $remote_access, 
					}, file => $THIS_FILE, line => __LINE__});
					if ($remote_access)
					{
						# Woot
						$an->data->{sys}{anvil}{$node_key}{use_ip}   = $an->data->{sys}{anvil}{$node_key}{remote_ip};
						$an->data->{sys}{anvil}{$node_key}{use_port} = $an->data->{sys}{anvil}{$node_key}{remote_port}; 
						$an->data->{sys}{anvil}{$node_key}{online}   = 1;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
							name1 => "sys::anvil::${node_key}::use_ip",   value1 => $an->data->{sys}{anvil}{$node_key}{use_ip}, 
							name2 => "sys::anvil::${node_key}::use_port", value2 => $an->data->{sys}{anvil}{$node_key}{use_port}, 
							name3 => "sys::anvil::${node_key}::online",   value3 => $an->data->{sys}{anvil}{$node_key}{online}, 
						}, file => $THIS_FILE, line => __LINE__});
					}
					else
					{
						# No luck.
						$an->data->{sys}{anvil}{$node_key}{online} = 0;
						$an->data->{sys}{anvil}{$node_key}{power}  = $an->ScanCore->target_power({target => $node_uuid});
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "sys::anvil::${node_key}::power", value1 => $an->data->{sys}{anvil}{$node_key}{power}, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				else
				{
					# No luck.
					$an->data->{sys}{anvil}{$node_key}{online} = 0;
					$an->data->{sys}{anvil}{$node_key}{power}  = $an->ScanCore->target_power({target => $node_uuid});
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "sys::anvil::${node_key}::power", value1 => $an->data->{sys}{anvil}{$node_key}{power}, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
	}
	
	# If I connected, cache the data.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::anvil::${node_key}::online", value1 => $an->data->{sys}{anvil}{$node_key}{online}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{anvil}{$node_key}{online})
	{
		my $say_access = $an->data->{sys}{anvil}{$node_key}{use_ip};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "say_access",                      value1 => $say_access, 
			name2 => "sys::anvil::${node_key}::online", value2 => $an->data->{sys}{anvil}{$node_key}{online}, 
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{sys}{anvil}{$node_key}{use_port}) && ($an->data->{sys}{anvil}{$node_key}{use_port} ne 22))
		{
			$say_access = $an->data->{sys}{anvil}{$node_key}{use_ip}.":".$an->data->{sys}{anvil}{$node_key}{use_port};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "say_access", value1 => $say_access, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		$an->ScanCore->insert_or_update_nodes_cache({
			node_cache_host_uuid	=>	$an->data->{sys}{host_uuid},
			node_cache_node_uuid	=>	$node_uuid, 
			node_cache_name		=>	"access",
			node_cache_data		=>	$say_access,
		});
	}
	else
	{
		# Failed to connect, set some values.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::anvil::${node_key}::power", value1 => $an->data->{sys}{anvil}{$node_key}{power}, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{sys}{anvil}{$node_key}{power} eq "off")
		{
			$an->data->{sys}{online_nodes}                 = 1;
			$an->data->{node}{$node_name}{enable_poweron}  = 1;
			$an->data->{node}{$node_name}{enable_poweroff} = 0;
			$an->data->{node}{$node_name}{enable_fence}    = 0;
			$an->data->{node}{$node_name}{info}{note}      = "";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
				name1 => "sys::online_nodes",                   value1 => $an->data->{sys}{online_nodes},
				name2 => "node::${node_name}::enable_poweron",  value2 => $an->data->{node}{$node_name}{enable_poweron},
				name3 => "node::${node_name}::enable_poweroff", value3 => $an->data->{node}{$node_name}{enable_poweroff},
				name4 => "node::${node_name}::enable_fence",    value4 => $an->data->{node}{$node_name}{enable_fence},
				name5 => "node::${node_name}::info::note",      value5 => $an->data->{node}{$node_name}{info}{note},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($an->data->{sys}{anvil}{$node_key}{power} eq "on")
		{
			# The node is on but unreachable.
			$an->data->{sys}{online_nodes}                 = 1;
			$an->data->{node}{$node_name}{enable_poweron}  = 0;
			$an->data->{node}{$node_name}{enable_poweroff} = 0;
			$an->data->{node}{$node_name}{enable_fence}    = 1;
			if (not $an->data->{node}{$node_name}{info}{'state'})
			{
				# No access
				$an->data->{node}{$node_name}{info}{'state'} = "<span class=\"highlight_warning\">#!string!row_0033!#</span>";
			}
			if (not $an->data->{node}{$node_name}{info}{note})
			{
				# Unable to log into node.
				$an->data->{node}{$node_name}{info}{note} = $an->String->get({key => "message_0034", variables => { node => $node_name }});
			}
			$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
				name1 => "sys::online_nodes",                   value1 => $an->data->{sys}{online_nodes},
				name2 => "node::${node_name}::enable_poweron",  value2 => $an->data->{node}{$node_name}{enable_poweron},
				name3 => "node::${node_name}::enable_poweroff", value3 => $an->data->{node}{$node_name}{enable_poweroff},
				name4 => "node::${node_name}::enable_fence",    value4 => $an->data->{node}{$node_name}{enable_fence},
				name5 => "node::${node_name}::info::state",     value5 => $an->data->{node}{$node_name}{info}{'state'},
				name6 => "node::${node_name}::info::note",      value6 => $an->data->{node}{$node_name}{info}{note},
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 3, message_key => "log_0017", file => $THIS_FILE, line => __LINE__});
			foreach my $daemon ("cman", "rgmanager", "drbd", "clvmd", "gfs2", "libvirtd")
			{
				$an->data->{node}{$node_name}{daemon}{$daemon}{status}    = "<span class=\"highlight_unavailable\">#!string!an_state_0001!#</span>";
				$an->data->{node}{$node_name}{daemon}{$daemon}{exit_code} = "";
			}
		}
		else
		{
			# Unable to determine node state.
			$an->data->{node}{$node_name}{enable_poweron}  = 0;
			$an->data->{node}{$node_name}{enable_poweroff} = 0;
			$an->data->{node}{$node_name}{enable_fence}    = 0;
			if (not $an->data->{node}{$node_name}{info}{'state'})
			{
				# No access
				$an->data->{node}{$node_name}{info}{'state'} = "<span class=\"highlight_warning\">#!string!row_0033!#</span>";
			}
			if (not $an->data->{node}{$node_name}{info}{note})
			{
				$an->data->{node}{$node_name}{info}{note} = $an->String->get({key => "message_0037", variables => { node => $node_name }});
			}
			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
				name1 => "node::${node_name}::enable_poweron",  value1 => $an->data->{node}{$node_name}{enable_poweron},
				name2 => "node::${node_name}::enable_poweroff", value2 => $an->data->{node}{$node_name}{enable_poweroff},
				name3 => "node::${node_name}::enable_fence",    value3 => $an->data->{node}{$node_name}{enable_fence},
				name4 => "node::${node_name}::info::state",     value4 => $an->data->{node}{$node_name}{info}{'state'},
				name5 => "node::${node_name}::info::note",      value5 => $an->data->{node}{$node_name}{info}{note},
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 3, message_key => "log_0017", file => $THIS_FILE, line => __LINE__});
			foreach my $daemon ("cman", "rgmanager", "drbd", "clvmd", "gfs2", "libvirtd")
			{
				$an->data->{node}{$node_name}{daemon}{$daemon}{status}    = "<span class=\"highlight_unavailable\">#!string!an_state_0001!#</span>";
				$an->data->{node}{$node_name}{daemon}{$daemon}{exit_code} = "";
			}
		}
	}
	
	# If I was asked to do a short scan, return here.
	if ($short_scan)
	{
		return(0);
	}
	
	# set daemon states to 'Unknown'.
	$an->Log->entry({log_level => 3, message_key => "log_0017", file => $THIS_FILE, line => __LINE__});
	foreach my $daemon ("cman", "rgmanager", "drbd", "clvmd", "gfs2", "libvirtd")
	{
		$an->data->{node}{$node_name}{daemon}{$daemon}{status}    = "<span class=\"highlight_unavailable\">#!string!an_state_0001!#</span>";
		$an->data->{node}{$node_name}{daemon}{$daemon}{exit_code} = "";
	}
	
	# Gather details on the node.
	$an->Log->entry({log_level => 3, message_key => "log_0018", message_variables => { node => $node_name }, file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::anvil::${node_key}::online", value1 => $an->data->{sys}{anvil}{$node_key}{online},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{anvil}{$node_key}{online})
	{
		$an->data->{sys}{online_nodes}    = 1;
		$an->data->{node}{$node_name}{up} = 1;
		
		push @{$an->data->{up_nodes}}, $node_name;
		my $up_nodes_count = @{$an->data->{up_nodes}};
		
		# There has been trouble trying to access offline nodes, so this is additional logging to 
		# help debug such cases.
		my $node_key = $an->data->{sys}{node_name}{$node_name}{node_key};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
			name1 => "sys::online_nodes",                 value1 => $an->data->{sys}{online_nodes},
			name2 => "node::${node_name}::up",            value2 => $an->data->{node}{$node_name}{up},
			name3 => "sys::anvil::${node_key}::use_ip",   value3 => $an->data->{sys}{anvil}{$node_key}{use_ip},
			name4 => "sys::anvil::${node_key}::use_port", value4 => $an->data->{sys}{anvil}{$node_key}{use_port},
			name5 => "up_nodes_count",                    value5 => $up_nodes_count,
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->Striker->_gather_node_details({node => $node_uuid});
	}
	else
	{
		# Mark it as offline.
		$an->data->{node}{$node_name}{connected}      = 0;
		$an->data->{node}{$node_name}{info}{'state'}  = "<span class=\"highlight_unavailable\">#!string!state_0001!#</span>";
		$an->data->{node}{$node_name}{up}             = 0;
		$an->data->{node}{$node_name}{enable_poweron} = 0;
		
		# If the server is known off, enable the power on button
		if ($an->data->{sys}{anvil}{$node_key}{power} eq "off")
		{
			$an->data->{node}{$node_name}{enable_poweron} = 1;
			$an->data->{node}{$node_name}{info}{'state'}  = "<span class=\"highlight_detail\">#!string!state_0004!#</span>";
		}
		
		# If I have confirmed the node is powered off, don't display this.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "sys::anvil::${node_key}::power", value1 => $an->data->{sys}{anvil}{$node_key}{power},
			name2 => "cgi::task",                      value2 => $an->data->{cgi}{task},
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{sys}{anvil}{$node_key}{power} eq "off") && (not $an->data->{cgi}{task}) && ($an->data->{node}{$node_name}{info}{note}))
		{
			print $an->Web->template({file => "main-page.html", template => "node-state-table", replace => { 
				'state'	=>	$an->data->{node}{$node_name}{info}{'state'},
				note	=>	$an->data->{node}{$node_name}{info}{note},
			}});
		}
	}
	
	push @{$an->data->{online_nodes}}, $node_name if $an->Striker->_check_node_daemons({node => $node_uuid});
	
	return (0);
}

# Check the status of server on the active Anvil!.
sub scan_servers
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "scan_servers" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make it a little easier to print the name of each node
	my $node1_name = $an->data->{sys}{anvil}{node1}{name};
	my $node1_uuid = $an->data->{sys}{node_name}{$node1_name}{uuid};
	my $node2_name = $an->data->{sys}{anvil}{node2}{name};
	my $node2_uuid = $an->data->{sys}{node_name}{$node2_name}{uuid};
	
	$an->data->{node}{$node1_name}{info}{host_name}       = $node1_name;
	$an->data->{node}{$node1_name}{info}{short_host_name} = $an->data->{sys}{anvil}{node1}{short_name};
	$an->data->{node}{$node2_name}{info}{host_name}       = $node2_name;
	$an->data->{node}{$node2_name}{info}{short_host_name} = $an->data->{sys}{anvil}{node2}{short_name};
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "node1_name",                                 value1 => $node1_name,
		name2 => "node::${node1_name}::info::short_host_name", value2 => $an->data->{node}{$node1_name}{info}{short_host_name},
		name3 => "node::${node1_name}::info::host_name",       value3 => $an->data->{node}{$node1_name}{info}{host_name},
		name4 => "node2_name",                                 value4 => $node2_name,
		name5 => "node::${node2_name}::info::short_host_name", value5 => $an->data->{node}{$node2_name}{info}{short_host_name},
		name6 => "node::${node2_name}::info::host_name",       value6 => $an->data->{node}{$node2_name}{info}{host_name},
	}, file => $THIS_FILE, line => __LINE__});
	
	my $short_node1 = $an->data->{sys}{anvil}{node1}{short_name};
	my $short_node2 = $an->data->{sys}{anvil}{node2}{short_name};
	my $long_node1  = $an->data->{sys}{anvil}{node1}{name};
	my $long_node2  = $an->data->{sys}{anvil}{node2}{name};
	my $say_node1   = "<span class=\"fixed_width\">".$an->data->{sys}{anvil}{node1}{short_name}."</span>";
	my $say_node2   = "<span class=\"fixed_width\">".$an->data->{sys}{anvil}{node2}{short_name}."</span>";
	foreach my $server (sort {$a cmp $b} keys %{$an->data->{server}})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "server", value1 => $server,
		}, file => $THIS_FILE, line => __LINE__});
		
		# This will control the buttons.
		$an->data->{server}{$server}{can_start}        = 0;
		$an->data->{server}{$server}{can_stop}         = 0;
		$an->data->{server}{$server}{can_migrate}      = 0;
		$an->data->{server}{$server}{current_host}     = 0;
		$an->data->{server}{$server}{migration_target} = "";
		
		# Find out who, if anyone, is running this server and who *can* run it. 
		# 2 == Running
		# 1 == Can run 
		# 0 == Can't run
		$an->data->{server}{$server}{say_node1}   = $an->data->{node}{$node1_name}{daemon}{cman}{exit_code} eq "0" ? "<span class=\"highlight_warning\">#!string!state_0006!#</span>" : "<span class=\"code\">--</span>";
		$an->data->{server}{$server}{node1_ready} = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "server::${server}::say_node1",                 value1 => $an->data->{server}{$server}{say_node1},
			name2 => "node::${node1_name}::daemon::cman::exit_code", value2 => $an->data->{node}{$node1_name}{daemon}{cman}{exit_code},
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->data->{server}{$server}{say_node2}   = $an->data->{node}{$node2_name}{daemon}{cman}{exit_code} eq "0" ? "<span class=\"highlight_warning\">#!string!state_0006!#</span>" : "<span class=\"code\">--</span>";
		$an->data->{server}{$server}{node2_ready} = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "server::${server}::say_node2",                 value1 => $an->data->{server}{$server}{say_node2},
			name2 => "node::${node2_name}::daemon::cman::exit_code", value2 => $an->data->{node}{$node2_name}{daemon}{cman}{exit_code},
		}, file => $THIS_FILE, line => __LINE__});
		
		# If a server's XML definition file is found but there is no host, the user probably forgot 
		# to define it.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "server::${server}::host", value1 => $an->data->{server}{$server}{host},
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $an->data->{server}{$server}{host}) && (not $an->data->{sys}{ignore_missing_server}))
		{
			# Pull the host node and current state out of the hash.
			my $host_node    = "";
			my $server_state = "";
			foreach my $node_name (sort {$a cmp $b} keys %{$an->data->{server}{$server}{node}})
			{
				$host_node = $node_name;
				foreach my $key (sort {$a cmp $b} keys %{$an->data->{server}{$server}{node}{$node_name}{virsh}})
				{
					if ($key eq "state") 
					{
						$server_state = $an->data->{server}{$server}{node}{$host_node}{virsh}{'state'};
					}
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "server::${server}::node::${node_name}::virsh::${key}", value1 => $an->data->{server}{$server}{node}{$node_name}{virsh}{$key},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			$an->data->{server}{$server}{say_node1} = "--";
			$an->data->{server}{$server}{say_node2} = "--";
			
			my $say_error = $an->String->get({key => "message_0271", variables => { 
					server	=>	$server,
					url	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&task=add_server&name=$server&node_name=$host_node&state=$server_state",
				}});
			print $an->Web->template({file => "common.html", template => "error-table", replace => { message => $say_error }});
			next;
		}
		
		$an->data->{server}{$server}{host} = "" if not defined $an->data->{server}{$server}{host};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "server::${server}::host", value1 => $an->data->{server}{$server}{host},
			name2 => "short_node1",             value2 => $short_node1,
			name3 => "short_node2",             value3 => $short_node2,
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{server}{$server}{host} =~ /$short_node1/)
		{
			# Even though I know the host is ready, this function loads some data, like LV 
			# details, which I will need later.
			$an->Striker->_check_node_readiness({server => $server, node => $node1_uuid});
			$an->data->{server}{$server}{can_start}     = 0;
			$an->data->{server}{$server}{can_stop}      = 1;
			$an->data->{server}{$server}{current_host}  = $node1_name;
			$an->data->{server}{$server}{node1_ready}   = 2;
			($an->data->{server}{$server}{node2_ready}) = $an->Striker->_check_node_readiness({server => $server, node => $node2_uuid});
			if ($an->data->{server}{$server}{node2_ready})
			{
				$an->data->{server}{$server}{migration_target} = $long_node2;
				$an->data->{server}{$server}{can_migrate}      = 1;
			}
			
			# Disable Anvil! withdrawl of this node.
			$an->data->{node}{$node1_name}{enable_withdraw} = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
				name1 => "node::${node1_name}::enable_withdraw", value1 => $an->data->{node}{$node1_name}{enable_withdraw},
				name2 => "server::${server}::node2_ready",       value2 => $an->data->{server}{$server}{node2_ready},
				name3 => "server::${server}::can_migrate",       value3 => $an->data->{server}{$server}{can_migrate},
				name4 => "server::${server}::migration_target",  value4 => $an->data->{server}{$server}{migration_target},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($an->data->{server}{$server}{host} =~ /$short_node2/)
		{
			# Even though I know the host is ready, this function loads some data, like LV 
			# details, which I will need later.
			$an->Striker->_check_node_readiness({server => $server, node => $node2_uuid});
			$an->data->{server}{$server}{can_start}     = 0;
			$an->data->{server}{$server}{can_stop}      = 1;
			$an->data->{server}{$server}{current_host}  = $node2_name;
			($an->data->{server}{$server}{node1_ready}) = $an->Striker->_check_node_readiness({server => $server, node => $node1_uuid});
			$an->data->{server}{$server}{node2_ready}   = 2;
			if ($an->data->{server}{$server}{node1_ready})
			{
				$an->data->{server}{$server}{migration_target} = $long_node1;
				$an->data->{server}{$server}{can_migrate}      = 1;
			}
			
			# Disable withdrawl of this node.
			$an->data->{node}{$node2_name}{enable_withdraw} = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
				name1 => "node${node2_name}::enable_withdraw",  value1 => $an->data->{node}{$node2_name}{enable_withdraw},
				name2 => "server::${server}::node2_ready::",    value2 => $an->data->{server}{$server}{node2_ready},
				name3 => "server::${server}::can_migrate",      value3 => $an->data->{server}{$server}{can_migrate},
				name4 => "server::${server}::migration_target", value4 => $an->data->{server}{$server}{migration_target},
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			$an->data->{server}{$server}{can_stop}      = 0;
			($an->data->{server}{$server}{node1_ready}) = $an->Striker->_check_node_readiness({server => $server, node => $node1_uuid});
			($an->data->{server}{$server}{node2_ready}) = $an->Striker->_check_node_readiness({server => $server, node => $node2_uuid});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "server::${server}::node1_ready", value1 => $an->data->{server}{$server}{node1_ready},
				name2 => "server::${server}::node2_ready", value2 => $an->data->{server}{$server}{node2_ready},
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "server::${server}::current_host", value1 => $an->data->{server}{$server}{current_host},
		}, file => $THIS_FILE, line => __LINE__});
		$an->data->{server}{$server}{boot_target} = "";
		if ($an->data->{server}{$server}{current_host})
		{
			# Get the current host's details
			my $this_host     = $an->data->{server}{$server}{current_host};
			my $target_uuid   = $an->data->{sys}{node_name}{$this_host}{uuid};
			my $this_node_key = $an->data->{db}{nodes}{$target_uuid}{node_key};
			my $this_target   = $an->data->{sys}{anvil}{$this_node_key}{use_ip};
			my $this_port     = $an->data->{sys}{anvil}{$this_node_key}{use_port};
			my $this_password = $an->data->{sys}{anvil}{$this_node_key}{password};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
				name1 => "this_host",     value1 => $this_host,
				name2 => "target_uuid",   value2 => $target_uuid,
				name3 => "this_node_key", value3 => $this_node_key,
				name4 => "this_target",   value4 => $this_target,
				name5 => "this_port",     value5 => $this_port,
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
				name1 => "this_password", value1 => $this_password,
			}, file => $THIS_FILE, line => __LINE__});
			
			# This is a bit expensive, but read the server's running definition.
			my $shell_call = $an->data->{path}{virsh}." dumpxml $server";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "node_target", value1 => $this_target,
				name2 => "shell_call",  value2 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$this_target,
				port		=>	$this_port, 
				password	=>	$this_password,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				### TODO: Why did I do this?
				#$line =~ s/^\s+//;
				#$line =~ s/\s+$//;
				#$line =~ s/\s+/ /g;
				next if not $line;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				push @{$an->data->{server}{$server}{xml}}, $line;
			}
		}
		else
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "server::${server}::node1_ready", value1 => $an->data->{server}{$server}{node1_ready},
				name2 => "server::${server}::node2_ready", value2 => $an->data->{server}{$server}{node2_ready},
			}, file => $THIS_FILE, line => __LINE__});
			if (($an->data->{server}{$server}{node1_ready}) && ($an->data->{server}{$server}{node2_ready}))
			{
				# I can boot on either node, so choose the first one in the server's failover
				# domain.
				$an->data->{server}{$server}{boot_target} = $an->Striker->_find_preferred_host({server => $server});
				$an->data->{server}{$server}{can_start}   = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "server::${server}::boot_target", value1 => $an->data->{server}{$server}{boot_target},
					name2 => "server::${server}::can_start",   value2 => $an->data->{server}{$server}{can_start},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($an->data->{server}{$server}{node1_ready})
			{
				$an->data->{server}{$server}{boot_target} = $node1_name;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "server::${server}::boot_target", value1 => $an->data->{server}{$server}{boot_target},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($an->data->{server}{$server}{node2_ready})
			{
				$an->data->{server}{$server}{boot_target} = $node2_name;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "server::${server}::boot_target", value1 => $an->data->{server}{$server}{boot_target},
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				$an->data->{server}{$server}{can_start} = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "server::${server}::can_start", value1 => $an->data->{server}{$server}{can_start},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return (0);
}

### NOTE: This will be deprecated and removed once we get a viable in-browser Spice client working. Until 
###       then though, this sets up passwordless SSH from dashboards to Anvil! nodes and then configures 
###       virtual machine manager.
###       See: http://www.spice-space.org/page/Html5
# This calls each Striker peer we know of and sets updates its ssh and virtual-machine-manager configs
sub update_peers
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "update_peers" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# No Anvil! name is fatal
	if (not $parameter->{anvil_name})
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0124", code => 124, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	my $anvil_name = $parameter->{anvil_name} ? $parameter->{anvil_name} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil_name", value1 => $anvil_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Return if this is disabled.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "striker::peers::configure_anvils", value1 => $an->data->{striker}{peers}{configure_anvils},
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->data->{tools}{striker}{'auto-sync'})
	{
		return("");
	}
	
	# Peers are the same machines hosting ScanCore databases, so that is what we'll look for.
	my $local_id      = "";
	my $peer_name     = "";
	my $peer_password = "";
	my $updated_peers = [];
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "hostname",       value1 => $an->hostname(),
		name2 => "short_hostname", value2 => $an->short_hostname(),
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
	{
		my $this_host = $an->data->{scancore}{db}{$id}{host};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "id",        value1 => $id,
			name2 => "this_host", value2 => $this_host,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Skip this host if scancore::db::X::no_sync is set
		next if $an->data->{scancore}{db}{$id}{no_sync};
		
		if (($this_host eq $an->hostname()) or ($this_host eq $an->short_hostname()))
		{
			$local_id = $id;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "local_id", value1 => $local_id,
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Sync
			my $peer_hostname = $an->data->{scancore}{db}{$id}{host};
			my $peer_user     = $an->data->{scancore}{db}{$id}{user};
			my $peer_ssh_port = $an->data->{scancore}{db}{$id}{ssh_port} ? $an->data->{scancore}{db}{$id}{ssh_port} : 0;
			my $peer_password = $an->data->{scancore}{db}{$id}{password};
			
			# Call 'striker-push-ssh'
			my $shell_call = $an->data->{path}{'striker-push-ssh'}." --anvil $anvil_name";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "peer_hostname",  value1 => $peer_hostname,
				name2 => "shell_call",     value2 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$peer_hostname,
				port		=>	$peer_ssh_port, 
				password	=>	$peer_password,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			# Now call 'striker-configure-vmm'.
			$shell_call = $an->data->{path}{'striker-configure-vmm'};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "peer_hostname",  value1 => $peer_hostname,
				name2 => "shell_call",     value2 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$peer_hostname,
				port		=>	$peer_ssh_port, 
				password	=>	$peer_password,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			# Note that we updated this peer.
			push @{$updated_peers}, $peer_hostname;
		}
	}
	
	my $updated_peer_count = @{$updated_peers};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "updated_peer_count", value1 => $updated_peer_count,
	}, file => $THIS_FILE, line => __LINE__});
	return($updated_peers);
}

# This uses sed to update a local or remote striker.conf value.
sub update_striker_conf
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "update_striker_conf" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $variable = $parameter->{variable} ? $parameter->{variable} : "";
	my $value    = $parameter->{value}    ? $parameter->{value}    : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "variable", value1 => $variable, 
		name2 => "target",   value2 => $target, 
		name3 => "port",     value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	# The value might be a password, so it is log level 4
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "value",    value1 => $value, 
		name2 => "password", value2 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Do I have a variable (values are allowed to be blank)?
	if (not $variable)
	{
		# Woops!
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0204", code => 204, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	### TODO: Should this require root? What about for local calls only?
	
	# Clean up the value for use in "".
	$value =~ s/"/\\"/g;
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "value", value1 => $value, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Still alive? Good!
	my $date_time   = $an->Get->date_and_time({split_date_time => 0, no_spaces => 1});
	my $return_code = 255;
	my $return      = [];
	my $shell_call  = $an->data->{path}{sed}." -i.$date_time \"s/^$variable\\(\\s*\\)=\\(\\s*\\).*/$variable\\1=\\2$value/\" ".$an->data->{path}{striker_config}."; ".$an->data->{path}{'echo'}." return_code:\$?";
	if ($target)
	{
		# Remote call.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
		# Local call
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			push @{$return}, $line;
		}
		close $file_handle;
	}
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^return_code:(\d+)$/)
		{
			$return_code = $1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code, 
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}


#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

sub _add_server_to_anvil
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_add_server_to_anvil" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $skip_scan  = $parameter->{skip_scan} ? $parameter->{skip_scan} : 0;
	my $server     = $an->data->{cgi}{name};
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $definition = $an->data->{path}{shared_definitions}."/$server.xml";
	my $node_name  = $an->data->{new_server}{host_node} ? $an->data->{new_server}{host_node} : $an->data->{cgi}{node_name};
	my $node_key   = $an->data->{sys}{node_name}{$node_name}{node_key};
	my $node_uuid  = $an->data->{sys}{anvil}{$node_key}{uuid};
	my $peer_key   = $an->data->{sys}{node_name}{$node_name}{peer_node_key};
	my $peer_name  = $an->data->{sys}{anvil}{$peer_key}{name};
	my $host_node  = $an->data->{new_server}{host_node};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0013", message_variables => {
		name1  => "skip_scan",  value1  => $skip_scan,
		name2  => "server",     value2  => $server,
		name3  => "anvil_uuid", value3  => $anvil_uuid,
		name4  => "anvil_name", value4  => $anvil_name,
		name5  => "definition", value5  => $definition,
		name6  => "node_name",  value6  => $node_name,
		name7  => "node_key",   value7  => $node_key,
		name8  => "node_uuid",  value8  => $node_uuid,
		name9  => "peer_key",   value9  => $peer_key,
		name10 => "peer_name",  value10 => $peer_name,
		name11 => "host_node",  value11 => $host_node,
		name12 => "target",     value12 => $target,
		name13 => "port",       value13 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	# First, find the failover domain...
	my $failover_domain = "";
	$an->data->{sys}{ignore_missing_server} = 1;
	
	# If this is being called after provisioning a server, we'll skip scanning the Anvil! and we'll not 
	# print the opening header. 
	if (not $skip_scan)
	{
		$an->Striker->scan_anvil();
		$an->Log->entry({log_level => 2, message_key => "log_0231", file => $THIS_FILE, line => __LINE__});
		print $an->Web->template({file => "server.html", template => "add-server-to-anvil-header"});
	}
	
	# Find the failover domain.
	foreach my $fod (keys %{$an->data->{failoverdomain}})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "fod", value1 => $fod,
		}, file => $THIS_FILE, line => __LINE__});
		if ($fod =~ /primary_(.*?)$/)
		{
			my $node_suffix = $1;
			my $alt_suffix  = (($node_suffix eq "n01") or ($node_suffix eq "n1")) ? "node01" : "node02";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "node_suffix", value1 => $node_suffix,
				name2 => "alt_suffix",  value2 => $alt_suffix,
			}, file => $THIS_FILE, line => __LINE__});
			
			# If the user has named their nodes 'nX' or 'nodeX', the 'n0X'/'node0X' won't match,
			# so we fudge it here.
			my $say_node = $node_name;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "say_node", value1 => $say_node,
			}, file => $THIS_FILE, line => __LINE__});
			if (($node_name !~ /node0\d/) && ($node_name !~ /n0\d/))
			{
				if ($node_name =~ /node(\d)/)
				{
					my $integer  = $1;
					   $say_node = "node0".$integer;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "say_node", value1 => $say_node,
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($node_name =~ /n(\d)/)
				{
					my $integer  = $1;
					   $say_node = "n0".$integer;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "say_node", value1 => $say_node,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
				name1 => "node_name",   value1 => $node_name,
				name2 => "say_node",    value2 => $say_node,
				name3 => "node_suffix", value3 => $node_suffix,
				name4 => "alt_suffix",  value4 => $alt_suffix,
			}, file => $THIS_FILE, line => __LINE__});
			if (($say_node =~ /$node_suffix/) or ($say_node =~ /$alt_suffix/))
			{
				$failover_domain = $fod;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "failover_domain", value1 => $failover_domain,
				}, file => $THIS_FILE, line => __LINE__});
				last;
			}
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "failover_domain", value1 => $failover_domain,
	}, file => $THIS_FILE, line => __LINE__});
	
	# How I print the next message depends on whether I'm doing a stand-alone addition or on the heels of
	# a new provisioning.
	if ($skip_scan)
	{
		# Running on the heels of a server provision, so the table is already opened.
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
				row	=>	"#!string!row_0281!#",
				message	=>	"#!string!message_0090!#",
			}});
		my $message = $an->String->get({key => "title_0033", variables => { 
				server		=>	$server,
				failover_domain	=>	$failover_domain,
			}});
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
				row	=>	"#!string!row_0092!#",
				message	=>	$message,
			}});
	}
	else
	{
		# Doing a stand-alone addition of a server to the Anvil!, so we need a title.
		my $title = $an->String->get({key => "title_0033", variables => { 
			server		=>	$server,
			failover_domain	=>	$failover_domain,
		}});
		print $an->Web->template({file => "server.html", template => "add-server-to-anvil-header-detail", replace => { title => $title }});
	}
	
	# If there is no password set, abort.
	if (not $an->data->{sys}{anvil}{password})
	{
		# No ricci user, so we can't add it. Tell the user and give them a link to the config for 
		# this Anvil!.
		print $an->Web->template({file => "server.html", template => "general-error-message", replace => { 
			row	=>	"#!string!row_0090!#",
			message	=>	$an->String->get({key => "message_0087", variables => { server => $server }}),
		}});
		print $an->Web->template({file => "server.html", template => "general-error-message", replace => { 
			row	=>	"#!string!row_0091!#",
			message	=>	$an->String->get({key => "message_0088", variables => { manage_url => "/cgi-bin/configure&anvil_uuid=$anvil_uuid" }}),
		}});
		return(1);
	}

	if (not $failover_domain)
	{
		# No failover domain found
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
			row	=>	"#!string!row_0096!#",
			message	=>	"#!string!message_0089!#",
		}});
		return (1);
	}
	
	### Lets get started!
	# On occasion, the installed server will power off, not reboot. So this checks to see if the server 
	# needs to be kicked awake.
	my $host = $an->data->{new_server}{host_node} ? $an->data->{new_server}{host_node} : $an->data->{cgi}{node_name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "server", value1 => $server,
		name2 => "host",   value2 => $host,
	}, file => $THIS_FILE, line => __LINE__});
	if ($host eq "none")
	{
		# Server isn't running yet.
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
				row	=>	"#!string!row_0280!#",
				message	=>	"#!string!message_0091!#",
			}});
		$an->Log->entry({log_level => 2, message_key => "log_0232", message_variables => { server => $server }, file => $THIS_FILE, line => __LINE__});
		my $virsh_exit_code = 255;
		my $shell_call      = $an->data->{path}{virsh}." start $server; ".$an->data->{path}{echo}." virsh:\$?";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			next if not $line;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /virsh:(\d+)/)
			{
				$virsh_exit_code = $1;
			}
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "virsh_exit_code", value1 => $virsh_exit_code,
		}, file => $THIS_FILE, line => __LINE__});
		if ($virsh_exit_code eq "0")
		{
			# Server has booted.
			print $an->Web->template({file => "server.html", template => "general-message", replace => { 
				row	=>	"&nbsp;",
				message	=>	"#!string!message_0092!#",
			}});
		}
		else
		{
			# If something undefined the server already and the server is not running, this will
			# fail. Try to start the server using the definition file before giving up.
			print $an->Web->template({file => "server.html", template => "general-message", replace => { 
				row	=>	"&nbsp;",
				message	=>	"#!string!message_0093!#",
			}});
			$an->Log->entry({log_level => 2, message_key => "log_0233", message_variables => {
				server  => $server, 
				file    => $an->data->{path}{shared_definitions}."/${server}.xml", 
			}, file => $THIS_FILE, line => __LINE__});
			my $virsh_exit_code;
			my $shell_call = $an->data->{path}{virsh}." create ".$an->data->{path}{shared_definitions}."/${server}.xml; ".$an->data->{path}{echo}." virsh:\$?";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "target",     value1 => $target,
				name2 => "shell_call", value2 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$target,
				port		=>	$port, 
				password	=>	$password,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				next if not $line;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /virsh:(\d+)/)
				{
					$virsh_exit_code = $1;
				}
			}
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "virsh_exit_code", value1 => $virsh_exit_code,
			}, file => $THIS_FILE, line => __LINE__});
			if ($virsh_exit_code eq "0")
			{
				# Should now be booting.
				print $an->Web->template({file => "server.html", template => "general-message", replace => { 
					row	=>	"&nbsp;",
					message	=>	"#!string!message_0092!#",
				}});
			}
			else
			{
				# Failed to boot.
				my $say_message = $an->String->get({key => "message_0094", variables => { 
						server		=>	$server,
						virsh_exit_code	=>	$virsh_exit_code,
					}});
				print $an->Web->template({file => "server.html", template => "general-error-message", replace => { 
					row	=>	"#!string!row_0044!#",
					message	=>	$say_message,
				}});
				return (1);
			}
		}
	}
	elsif ($host eq $node_name)
	{
		# Already running
		$target   = $an->data->{sys}{anvil}{$node_key}{use_ip};
		$port     = $an->data->{sys}{anvil}{$node_key}{use_port};
		$password = $an->data->{sys}{anvil}{$node_key}{password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node_name", value1 => $node_name,
			name2 => "target",    value2 => $target,
			name3 => "port",      value3 => $port,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password,
		}, file => $THIS_FILE, line => __LINE__});
		
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
			row	=>	"&nbsp;",
			message	=>	"#!string!message_0095!#",
		}});
	}
	else
	{
		# Already running, but on the peer.
		$node_name = $host;
		$target    = $an->data->{sys}{anvil}{$peer_key}{use_ip};
		$port      = $an->data->{sys}{anvil}{$peer_key}{use_port};
		$password  = $an->data->{sys}{anvil}{$peer_key}{password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node_name", value1 => $node_name,
			name2 => "target",    value2 => $target,
			name3 => "port",      value3 => $port,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password,
		}, file => $THIS_FILE, line => __LINE__});
		
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
			row	=>	"&nbsp;",
			message	=>	"#!string!message_0096!#",
		}});
	}
	
	# Dump the server's XML definition.
	print $an->Web->template({file => "server.html", template => "general-message", replace => { 
		row	=>	"#!string!row_0093!#",
		message	=>	"#!string!message_0097!#",
	}});
	if (not $server)
	{
		# No server name... wth?
		print $an->Web->template({file => "server.html", template => "general-error-message", replace => { 
			row	=>	"#!string!row_0044!#",
			message	=>	"#!string!message_0098!#",
		}});
		return (1);
	}
	
	my @new_server_xml;
	my $virsh_exit_code = 255;
	my $shell_call      = $an->data->{path}{virsh}." dumpxml $server; ".$an->data->{path}{echo}." virsh:\$?";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		next if not $line;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /virsh:(\d+)/)
		{
			$virsh_exit_code = $1;
		}
		else
		{
			push @new_server_xml, $line;
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "virsh_exit_code", value1 => $virsh_exit_code,
	}, file => $THIS_FILE, line => __LINE__});
	if ($virsh_exit_code eq "0")
	{
		# Wrote the definition.
		my $say_message = $an->String->get({key => "message_0099", variables => { definition => $definition }});
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
			row	=>	"&nbsp;",
			message	=>	$say_message,
		}});
	}
	else
	{
		# Failed to write the definition file.
		my $say_error = $an->String->get({key => "message_0100", variables => { virsh_exit_code	=> $virsh_exit_code }});
		print $an->Web->template({file => "server.html", template => "general-error-message", replace => { 
			row	=>	"&nbsp;",
			message	=>	$say_error,
		}});
		return (1);
	}
	
	# We'll switch to boot the 'hd' first if needed and add a cdrom if it doesn't exist.
	my $new_xml = "";
	my $hd_seen = 0;
	my $cd_seen = 0;
	my $in_os   = 0;
	foreach my $line (@new_server_xml)
	{
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /<boot dev='(.*?)'/)
		{
			my $device = $1;
			if ($device eq "hd")
			{
				next if $hd_seen;
				$hd_seen = 1;
			}
			if ($device eq "cdrom")
			{
				$cd_seen = 1;
				if (not $hd_seen)
				{
					# Inject the hd first.
					$new_xml .= "    <boot dev='hd'/>\n";
					$hd_seen =  1;
				}
			}
		}
		if ($line =~ /<\/os>/)
		{
			if (not $cd_seen)
			{
				# Inject an optical drive.
				$new_xml .= "    <boot dev='cdrom'/>\n";
			}
		}
		$new_xml .= "$line\n";
	}
	
	# See if I need to insert or edit any network interface driver elements.
	$new_xml = $an->Striker->_update_network_driver({xml => $new_xml});
	
	# Now write out the XML.
	$shell_call = $an->data->{path}{cat}." > $definition << EOF\n$new_xml\nEOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /virsh:(\d+)/)
		{
			$virsh_exit_code = $1;
		}
		else
		{
			push @new_server_xml, $line;
		}
	}
	
	# Undefine the new server
	print $an->Web->template({file => "server.html", template => "general-message", replace => { 
		row	=>	"#!string!row_0094!#",
		message	=>	"#!string!message_0101!#",
	}});

	   $virsh_exit_code = "";
	my $undefine_ok     = 0;
	   $shell_call      = $an->data->{path}{virsh}." undefine $server; ".$an->data->{path}{echo}." virsh:\$?";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /virsh:(\d+)/)
		{
			$virsh_exit_code = $1;
		}
		if ($line =~ /cannot undefine transient domain/)
		{
			# This seems to be shown when trying to undefine a server that has already been 
			# undefined, so treat this like a success.
			$undefine_ok = 1;
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "virsh_exit_code", value1 => $virsh_exit_code,
		name2 => "undefine_ok",     value2 => $undefine_ok,
	}, file => $THIS_FILE, line => __LINE__});
	
	$virsh_exit_code = "0" if $undefine_ok;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "virsh_exit_code", value1 => $virsh_exit_code,
	}, file => $THIS_FILE, line => __LINE__});
	if ($virsh_exit_code eq "0")
	{
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
			row	=>	"&nbsp;",
			message	=>	"#!string!message_0102!#",
		}});
	}
	else
	{
		$virsh_exit_code = "--" if not $virsh_exit_code;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "virsh_exit_code", value1 => $virsh_exit_code,
		}, file => $THIS_FILE, line => __LINE__});
		my $say_error = $an->String->get({key => "message_0103", variables => { virsh_exit_code	=> $virsh_exit_code }});
		print $an->Web->template({file => "server.html", template => "general-warning-message", replace => { 
			row	=>	"#!string!row_0044!#",
			message	=>	$say_error,
		}});
	}
	
	# If I've made it this far, I am ready to add it to the Anvil! configuration.
	print $an->Web->template({file => "server.html", template => "general-message", replace => { 
		row	=>	"#!string!row_0095!#",
		message	=>	"#!string!message_0105!#",
	}});
	
	# The 'migrate_options="--unsafe"" is required when using 4kn based disks and it is OK if the cache 
	# policy is "writethrough".
	my $ccs_exit_code;
	   $shell_call = "
".$an->data->{path}{ccs}." \\
-h localhost --activate --sync --password \"".$an->data->{sys}{anvil}{password}."\" --addvm $server \\
domain=\"$failover_domain\" \\
path=\"".$an->data->{path}{shared_definitions}."/\" \\
autostart=\"0\" \\
exclusive=\"0\" \\
no_kill=\"1\" \\
recovery=\"restart\" \\
max_restarts=\"2\" \\
restart_expire_time=\"600\" \\
migrate_options=\"--unsafe\";
echo ccs:\$?";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /ccs:(\d+)/)
		{
			$ccs_exit_code = $1;
		}
		else
		{
			if ($line =~ /make sure the ricci server is started/)
			{
				# Tell the user that 'ricci' isn't running.
				print $an->Web->template({file => "server.html", template => "general-message", replace => { 
					row	=>	"#!string!row_0044!#",
					message	=>	$an->String->get({key => "message_0108", variables => { node => $node_name }}),
				}});
				print $an->Web->template({file => "server.html", template => "general-message", replace => { 
					row	=>	"&nbsp;",
					message	=>	"#!string!message_0109!#",
				}});
				print $an->Web->template({file => "server.html", template => "general-message", replace => { 
					row	=>	"&nbsp;",
					message	=>	"#!string!message_0110!#",
				}});
			}
			else
			{
				# Show any output from the call.
				$line = $an->Web->parse_text_line({line => $line});
				print $an->Web->template({file => "server.html", template => "general-message", replace => { 
					row	=>	"#!string!row_0127!#",
					message	=>	"<span class=\"fixed_width\">$line</span>",
				}});
			}
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ccs exit code", value1 => $ccs_exit_code,
	}, file => $THIS_FILE, line => __LINE__});
	$ccs_exit_code = "--" if not defined $ccs_exit_code;
	if ($ccs_exit_code eq "0")
	{
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
			row	=>	"#!string!row_0342!#",
			message	=>	"#!string!message_0111!#",
		}});
		
		### TODO: Make this watch 'clustat' for the server to appear.
		sleep 10;
	}
	else
	{
		# ccs call failed
		print $an->Web->template({file => "server.html", template => "general-error-message", replace => { 
			row	=>	"#!string!row_0096!#",
			message	=>	$an->String->get({key => "message_0112", variables => { ccs_exit_code => $ccs_exit_code }}),
		}});
		return (1);
	}
	# Enable/boot the server.
	print $an->Web->template({file => "server.html", template => "general-message", replace => { 
		row	=>	"#!string!row_0097!#",
		message	=>	"#!string!message_0113!#",
	}});
	
	### TODO: Get the Anvil!'s idea of the node name and use '-m ...'.
	# Tell the Anvil! to start the server. I don't bother to check for readiness because I confirmed it
	# was running on this node earlier.
	my $clusvcadm_exit_code = 255;
	   $shell_call          = $an->data->{path}{clusvcadm}." -e vm:$server; ".$an->data->{path}{echo}." clusvcadm:\$?";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /clusvcadm:(\d+)/)
		{
			$clusvcadm_exit_code = $1;
		}
		else
		{
			$line = $an->Web->parse_text_line({line => $line});
			print $an->Web->template({file => "server.html", template => "general-message", replace => { 
				row	=>	"#!string!row_0127!#",
				message	=>	"<span class=\"fixed_width\">$line</span>",
			}});
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "clusvcadm_exit_code", value1 => $clusvcadm_exit_code,
	}, file => $THIS_FILE, line => __LINE__});
	if ($clusvcadm_exit_code eq "0")
	{
		# Server added succcessfully.
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
			row	=>	"#!string!row_0083!#",
			message	=>	"#!string!message_0114!#",
		}});
	}
	else
	{
		# Appears to have failed.
		my $say_instruction = $an->String->get({key => "message_0088", variables => { manage_url => "?config=true&anvil_uuid=$anvil_uuid" }});
		my $say_message     = $an->String->get({key => "message_0115", variables => { 
				clusvcadm_exit_code	=>	$clusvcadm_exit_code,
				instructions		=>	$say_instruction,
			}});
		print $an->Web->template({file => "server.html", template => "general-error-message", replace => { 
			row	=>	"#!string!row_0096!#",
			message	=>	$say_message,
		}});
		return (1);
	}
	# Done!
	print $an->Web->template({file => "server.html", template => "add-server-to-anvil-footer"});

	return (0);
}

### WARNING: Deprecated, don't use this anymore.
# This copies the passed file to 'node:/shared/archive'
sub _archive_file
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $table_type = $parameter->{table_type} ? $parameter->{table_type} : "hidden_table";
	my $file       = $parameter->{file}       ? $parameter->{file}       : "";
	my $quiet      = $parameter->{quiet}      ? $parameter->{quiet}      : 0;
	my $target     = $parameter->{target}     ? $parameter->{target}     : "";
	my $port       = $parameter->{port}       ? $parameter->{port}       : "";
	my $password   = $parameter->{password}   ? $parameter->{password}   : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "file",       value1 => $file, 
		name2 => "table_type", value2 => $table_type, 
		name3 => "quiet",      value3 => $quiet, 
		name4 => "target",     value4 => $target, 
		name5 => "port",       value5 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Setup some variable
	my ($directory, $file_name) =  ($file =~ /^(.*)\/(.*?)$/);
	my ($date)                  =  $an->Get->date_and_time({split_date_time => 0, no_spaces => 1});
	my $destination             =  $an->data->{path}{shared_archive}."/$file_name.$date";
	   $destination             =~ s/ /_/;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "directory",   value1 => $directory, 
		name2 => "file_name",   value2 => $file_name, 
		name3 => "date",        value3 => $date, 
		name4 => "destination", value4 => $destination, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $cp_exit_code   = 255;
	my $header_printed = 0;
	my $shell_call     = $an->data->{path}{cp}." $file $destination; ".$an->data->{path}{echo}." cp:\$?";
	my $return         = [];
	if ($target)
	{
		# Remote call
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
		# Local call
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			push @{$return}, $line;
		}
		close $file_handle;
	}
	foreach my $line (@{$return})
	{
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /cp:(\d+)/)
		{
			$cp_exit_code = $1;
		}
		elsif (not $quiet)
		{
			if (not $header_printed)
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "table_type", value1 => $table_type,
				}, file => $THIS_FILE, line => __LINE__});
				if ($table_type eq "hidden_table")
				{
					print $an->Web->template({file => "server.html", template => "one-line-message-header-hidden"});
				}
				else
				{
					print $an->Web->template({file => "server.html", template => "one-line-message-header"});
				}
				$header_printed = 1;
			}
			$line = $an->Web->parse_text_line({line => $line});
			print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
		}
	}
	if ($header_printed)
	{
		print $an->Web->template({file => "server.html", template => "one-line-message-footer"});
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cp_exit_code", value1 => $cp_exit_code,
	}, file => $THIS_FILE, line => __LINE__});
	if ($cp_exit_code eq "0")
	{
		# Success
		if (not $quiet)
		{
			if ($table_type eq "hidden_table")
			{
				print $an->Web->template({file => "server.html", template => "one-line-message-header-hidden"});
			}
			else
			{
				print $an->Web->template({file => "server.html", template => "one-line-message-header"});
			}
			my $message = $an->String->get({key => "message_0211", variables => { 
					file		=>	$file,
					destination	=>	$destination,
				}});
			print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $message }});
			print $an->Web->template({file => "server.html", template => "one-line-message-footer"});
		}
		$an->Log->entry({log_level => 2, message_key => "log_0242", message_variables => {
			file        => $file, 
			destination => $destination, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Failure
		if (not $quiet)
		{
			my $message = $an->String->get({key => "message_0212", variables => { 
				file		=>	$file,
				destination	=>	$destination,
				cp_exit_code	=>	$cp_exit_code,
			}});
			print $an->Web->template({file => "server.html", template => "archive-file-failed", replace => { message => $message }});
		}
		$destination = 0;
	}
	
	return ($destination);
}

# This changes the amount of RAM or the number of CPUs allocated to a VM.
sub _change_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_change_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_name                           =  $parameter->{node_name} ? $parameter->{node_name} : "";
	my $node_key                            =  $an->data->{sys}{node_name}{$node_name}{node_key};
	my $target                              =  $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port                                =  $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password                            =  $an->data->{sys}{anvil}{$node_key}{password};
	my $anvil_uuid                          =  $an->data->{cgi}{anvil_uuid};
	my $anvil_name                          =  $an->data->{sys}{anvil}{name};
	my $server                              =  $an->data->{cgi}{server};
	my $device                              =  $an->data->{cgi}{device};
	my $new_server_note                     =  $an->data->{cgi}{server_note};
	my $new_server_migration_type           =  $an->data->{cgi}{server_migration_type};
	my $new_server_pre_migration_script     =  $an->data->{cgi}{server_pre_migration_script};
	my $new_server_pre_migration_arguments  =  $an->data->{cgi}{server_pre_migration_arguments};
	my $new_server_post_migration_script    =  $an->data->{cgi}{server_post_migration_script};
	my $new_server_post_migration_arguments =  $an->data->{cgi}{server_post_migration_arguments};
	my $new_server_start_after              =  $an->data->{cgi}{server_start_after};
	   $new_server_start_after              =~ s/^\s+//;
	   $new_server_start_after              =~ s/\s+$//;
	my $new_server_start_delay              = $an->data->{cgi}{server_start_delay};
	   $new_server_start_delay              =~ s/^\s+//;
	   $new_server_start_delay              =~ s/\s+$//;
	my $definition_file                     =  $an->data->{path}{shared_definitions}."/${server}.xml";
	my $other_allocated_ram                 =  $an->data->{resources}{allocated_ram} - $an->data->{server}{$server}{details}{ram};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0017", message_variables => {
		name1  => "node_name",                           value1  => $node_name,
		name2  => "node_key",                            value2  => $node_key,
		name3  => "target",                              value3  => $target,
		name4  => "port",                                value4  => $port,
		name5  => "anvil_uuid",                          value5  => $anvil_uuid,
		name6  => "anvil_name",                          value6  => $anvil_name,
		name7  => "server",                              value7  => $server,
		name8  => "device",                              value8  => $device,
		name9  => "new_server_note",                     value9  => $new_server_note,
		name10 => "new_server_migration_type",           value10 => $new_server_migration_type, 
		name11 => "new_server_pre_migration_script",     value11 => $new_server_pre_migration_script, 
		name12 => "new_server_pre_migration_arguments",  value12 => $new_server_pre_migration_arguments, 
		name13 => "new_server_post_migration_script",    value13 => $new_server_post_migration_script, 
		name14 => "new_server_post_migration_arguments", value14 => $new_server_post_migration_arguments, 
		name15 => "new_server_start_after",              value15 => $new_server_start_after,
		name16 => "new_server_start_delay",              value16 => $new_server_start_delay,
		name17 => "other_allocated_ram",                 value17 => $other_allocated_ram,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Read the values the user passed, see if they differ from what was read in the config and scancore 
	# DB. If hardware resources differ, make sure the requested resources are available. If a DB entry 
	# changes, update the DB. If all this passes, rewrite the definition file and/or update the DB.
	my $hardware_changed      = 0;
	my $database_changed      = 0;
	my $current_ram           =  $an->data->{server}{$server}{details}{ram};
	my $available_ram         =  ($an->data->{resources}{total_ram} - $an->data->{sys}{unusable_ram} - $an->data->{resources}{allocated_ram}) + $current_ram;
	   $current_ram           /= 1024;
	my $requested_ram         =  $an->Readable->hr_to_bytes({size => $an->data->{cgi}{ram}, type => $an->data->{cgi}{ram_suffix} });
	   $requested_ram         /= 1024;
	my $max_ram               =  $available_ram / 1024;
	my $current_cpus          =  $an->data->{server}{$server}{details}{cpu_count};
	my $requested_cpus        =  $an->data->{cgi}{cpu_cores};
	my $current_boot_device   =  $an->data->{server}{$server}{current_boot_device};
	my $requested_boot_device =  $an->data->{cgi}{boot_device};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "server",             value1 => $server,
		name2 => "requested_ram",  value2 => $requested_ram,
		name3 => "current_ram",    value3 => $current_ram,
		name4 => "requested_cpus", value4 => $requested_cpus,
		name5 => "current_cpus",   value5 => $current_cpus,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Read in the existing note (if any) from the database.
	my $return = $an->Get->server_data({
		server => $server, 
		anvil  => $anvil_name, 
	});
	my $server_definition                   = $return->{definition};
	my $server_uuid                         = $return->{uuid};
	my $old_server_note                     = $return->{note};
	my $old_server_start_after              = $return->{start_after};
	my $old_server_start_delay              = $return->{start_delay};
	my $old_server_migration_type           = $return->{migration_type};
	my $old_server_pre_migration_script     = $return->{pre_migration_script};
	my $old_server_pre_migration_arguments  = $return->{pre_migration_arguments};
	my $old_server_post_migration_script    = $return->{post_migration_script};
	my $old_server_post_migration_arguments = $return->{post_migration_arguments};
	# Log the server definition on its own because it is big
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "server_definition", value1 => $server_definition,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0009", message_variables => {
		name1 => "server_uuid",                         value1 => $server_uuid,
		name2 => "old_server_note",                     value2 => $old_server_note,
		name3 => "old_server_start_after",              value3 => $old_server_start_after,
		name4 => "old_server_start_delay",              value4 => $old_server_start_delay,
		name5 => "old_server_migration_type",           value5 => $old_server_migration_type, 
		name6 => "old_server_pre_migration_script",     value6 => $old_server_pre_migration_script, 
		name7 => "old_server_pre_migration_arguments",  value7 => $old_server_pre_migration_arguments, 
		name8 => "old_server_post_migration_script",    value8 => $old_server_post_migration_script, 
		name9 => "old_server_post_migration_arguments", value9 => $old_server_post_migration_arguments, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Open the table.
	my $title = $an->String->get({key => "title_0023", variables => { server => $server }});
	print $an->Web->template({file => "server.html", template => "update-server-config-header", replace => { title => $title }});
	
	# If either script was removed, wipe its arguments as well.
	if (not $new_server_pre_migration_script)
	{
		$new_server_pre_migration_arguments = "";
	}
	if (not $new_server_post_migration_script)
	{
		$new_server_post_migration_arguments = "";
	}
	
	# If the 'server_start_delay' field was disabled, it would have passed nothing at all. In that case,
	# set it to the old value to avoid a needless DB update.
	if ($new_server_start_delay eq "")
	{
		$new_server_start_delay = $old_server_start_delay;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "new_server_start_delay", value1 => $new_server_start_delay,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Did any DB values change?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::db_connections", value1 => $an->data->{sys}{db_connections},
	}, file => $THIS_FILE, line => __LINE__});
	my $db_error = "";
	if (($old_server_note                     ne $new_server_note)                    or 
	    ($old_server_start_after              ne $new_server_start_after)             or 
	    ($old_server_start_delay              ne $new_server_start_delay)             or 
	    ($old_server_migration_type           ne $new_server_migration_type)          or 
	    ($old_server_pre_migration_script     ne $new_server_pre_migration_script)    or 
	    ($old_server_pre_migration_arguments  ne $new_server_pre_migration_arguments) or
	    ($old_server_post_migration_script    ne $new_server_post_migration_script)   or 
	    ($old_server_post_migration_arguments ne $new_server_post_migration_arguments))
	{
		# Something changed. If there was a UUID, we'll update. Otherwise we'll insert.
		$database_changed = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "database_changed", value1 => $database_changed,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Make sure the values passed in for the start delay and start after are valid.
		if (($new_server_start_after) && (not $an->Validate->is_uuid({uuid => $new_server_start_after})))
		{
			# Bad entry, must be a UUID.
			$db_error .= $an->String->get({key => "message_0203", variables => { value => $new_server_start_after }})."<br />";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "db_error", value1 => $db_error,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (not $new_server_start_after)
		{
			$new_server_start_after = "NULL";
			$new_server_start_delay = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "new_server_start_after", value1 => $new_server_start_after,
				name2 => "new_server_start_delay", value2 => $new_server_start_delay,
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($new_server_start_delay !~ /^\d+$/)
		{
			# Bad group, must be a digit.
			$db_error .= $an->String->get({key => "message_0239", variables => { value => $new_server_start_delay }})."<br />";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "db_error", value1 => $db_error,
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# If there was no error, proceed.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "db_error", value1 => $db_error,
		}, file => $THIS_FILE, line => __LINE__});
		if ($db_error)
		{
			$database_changed = 0;
		}
		else
		{
			my $query = "
UPDATE 
    servers 
SET 
    server_note                     = ".$an->data->{sys}{use_db_fh}->quote($new_server_note).", 
    server_start_after              = ".$an->data->{sys}{use_db_fh}->quote($new_server_start_after).", 
    server_start_delay              = ".$an->data->{sys}{use_db_fh}->quote($new_server_start_delay).", 
    server_migration_type           = ".$an->data->{sys}{use_db_fh}->quote($new_server_migration_type).", 
    server_pre_migration_script     = ".$an->data->{sys}{use_db_fh}->quote($new_server_pre_migration_script).", 
    server_pre_migration_arguments  = ".$an->data->{sys}{use_db_fh}->quote($new_server_pre_migration_arguments).", 
    server_post_migration_script    = ".$an->data->{sys}{use_db_fh}->quote($new_server_post_migration_script).", 
    server_post_migration_arguments = ".$an->data->{sys}{use_db_fh}->quote($new_server_post_migration_arguments).", 
    modified_date                   = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    server_uuid                     = ".$an->data->{sys}{use_db_fh}->quote($server_uuid)."
;";
			$query =~ s/'NULL'/NULL/g;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "query", value1 => $query
			}, file => $THIS_FILE, line => __LINE__});
			$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Did something in the hardware change?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "current_ram",           value1 => $current_ram,
		name2 => "requested_ram",         value2 => $requested_ram,
		name3 => "requested_cpus",        value3 => $requested_cpus,
		name4 => "current_cpus",          value4 => $current_cpus,
		name5 => "current_boot_device",   value5 => $current_boot_device,
		name6 => "requested_boot_device", value6 => $requested_boot_device,
	}, file => $THIS_FILE, line => __LINE__});
	if (($current_ram         ne $requested_ram) or 
	    ($current_cpus        ne $requested_cpus) or
	    ($current_boot_device ne $requested_boot_device))
	{
		# Something has changed. Make sure the request is sane,
		my $max_cpus = $an->data->{resources}{total_threads};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "requested_ram",  value1 => $requested_ram,
			name2 => "max_ram",        value2 => $max_ram,
			name3 => "requested_cpus", value3 => $requested_cpus,
			name4 => "max_cpus",       value4 => $max_cpus,
		}, file => $THIS_FILE, line => __LINE__});
		if ($requested_ram > $max_ram)
		{
			# Not enough RAM
			my $say_requested_ram = $an->Readable->bytes_to_hr({'bytes' => ($requested_ram * 1024) });
			my $say_max_ram       = $an->Readable->bytes_to_hr({'bytes' => ($max_ram * 1024) });
			my $message           = $an->String->get({key => "message_0059", variables => { 
					requested_ram	=>	$title,
					max_ram		=>	$say_requested_ram,
				}});
			print $an->Web->template({file => "server.html", template => "update-server-error-message", replace => { 
				title		=>	"#!string!title_0025!",
				message		=>	$message,
			}});
		}
		elsif ($requested_cpus > $max_cpus)
		{
			# Not enough CPUs
			my $message = $an->String->get({key => "message_0060", variables => { 
					requested_cpus	=>	$requested_cpus,
					max_cpus	=>	$max_cpus,
				}});
			print $an->Web->template({file => "server.html", template => "update-server-error-message", replace => { 
				title		=>	"#!string!title_0026!",
				message		=>	$message,
			}});
		}
		else
		{
			# Request is sane. Archive the current definition.
			$hardware_changed = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "hardware_changed", value1 => $hardware_changed,
			}, file => $THIS_FILE, line => __LINE__});
			
			my ($backup_file) = $an->Striker->_archive_file({
					target   => $target,
					port     => $port, 
					password => $password,
					file     => $definition_file, 
					quiet    => 1
				});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "backup_file", value1 => $backup_file,
			}, file => $THIS_FILE, line => __LINE__});
			
			# Make the boot device easier to understand.
			my $say_requested_boot_device = $requested_boot_device;
			if ($requested_boot_device eq "hd")
			{
				$say_requested_boot_device = "#!string!device_0001!#";
			}
			elsif ($requested_boot_device eq "cdrom")
			{
				$say_requested_boot_device = "#!string!device_0002!#";
			}
			
			# Rewrite the XML file.
			print $an->String->get({key => "message_0061", variables => { 
					ram			=>	$an->data->{cgi}{ram},
					ram_suffix		=>	$an->data->{cgi}{ram_suffix},
					requested_cpus		=>	$requested_cpus,
					requested_boot_device	=>	$say_requested_boot_device,
				}});
			my $new_definition = "";
			my $in_os          = 0;
			foreach my $line (split/\n/, $server_definition)
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /^(.*?)<memory>\d+<\/memory>/)
				{
					my $prefix = $1;
					   $line   = "${prefix}<memory>$requested_ram<\/memory>";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /^(.*?)<memory unit='.*?'>\d+<\/memory>/)
				{
					my $prefix = $1;
					   $line   = "${prefix}<memory unit='KiB'>$requested_ram<\/memory>";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /^(.*?)<currentMemory>\d+<\/currentMemory>/)
				{
					my $prefix = $1;
					   $line   = "${prefix}<currentMemory>$requested_ram<\/currentMemory>";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /^(.*?)<currentMemory unit='.*?'>\d+<\/currentMemory>/)
				{
					my $prefix = $1;
					   $line   = "${prefix}<currentMemory unit='KiB'>$requested_ram<\/currentMemory>";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /^(.*?)<vcpu>(\d+)<\/vcpu>/)
				{
					my $prefix = $1;
					   $line   = "${prefix}<vcpu>$requested_cpus<\/vcpu>";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /^(.*?)<vcpu placement='(.*?)'>(\d+)<\/vcpu>/)
				{
					my $prefix    = $1;
					my $placement = $2;
					   $line      = "${prefix}<vcpu placement='$placement'>$requested_cpus<\/vcpu>";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /<os>/)
				{
					$in_os          =  1;
					$new_definition .= "$line\n";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "server",   value1 => $server,
						name2 => "line", value2 => $line,
					}, file => $THIS_FILE, line => __LINE__});
					next;
				}
				if ($in_os)
				{
					my $boot_menu_exists = 0;
					if ($line =~ /<\/os>/)
					{
						$in_os = 0;
						
						# Write out the new list of boot devices. Start with the
						# requested boot device and then loop through the rest.
						$new_definition .= "    <boot dev='$requested_boot_device'/>\n";
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "server",                value1 => $server,
							name2 => "requested_boot_device", value2 => $requested_boot_device,
						}, file => $THIS_FILE, line => __LINE__});
						foreach my $device (split /,/, $an->data->{server}{$server}{available_boot_devices})
						{
							next if $device eq $requested_boot_device;
							$new_definition .= "    <boot dev='$device'/>\n";
							$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
								name1 => "server", value1 => $server,
								name2 => "device", value2 => $device,
							}, file => $THIS_FILE, line => __LINE__});
						}
						
						# Cap off with the command to enable the boot prompt
						if (not $boot_menu_exists)
						{
							$new_definition .= "    <bootmenu enable='yes'/>\n";
						}
						
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "server", value1 => $server,
							name2 => "line",   value2 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						$new_definition .= "$line\n";
						next;
					}
					elsif ($line =~ /<bootmenu enable=/)
					{
						$new_definition   .= "$line\n";
						$boot_menu_exists =  1;
					}
					elsif ($line !~ /<boot dev/)
					{
						$new_definition .= "$line\n";
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "server",   value1 => $server,
							name2 => "line", value2 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						next;
					}
				}
				else
				{
					$new_definition .= "$line\n";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "server",   value1 => $server,
						name2 => "line", value2 => $line,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			$new_definition                                      =~ s/(\S)\s+$/$1\n/;
			$an->data->{server}{$server}{available_boot_devices} =~ s/,$//;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "new_definition", value1 => $new_definition,
			}, file => $THIS_FILE, line => __LINE__});
			
			# See if I need to insert or edit any network interface driver elements.
			$new_definition = $an->Striker->_update_network_driver({xml => $new_definition});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "new_definition", value1 => $new_definition,
			}, file => $THIS_FILE, line => __LINE__});
			
			# Write the new definition file.
			my $shell_call = $an->data->{path}{echo}." \"$new_definition\" > $definition_file && ".$an->data->{path}{'chmod'}." 644 $definition_file";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "target",     value1 => $target,
				name2 => "shell_call", value2 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$target,
				port		=>	$port, 
				password	=>	$password,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				print $an->Web->template({file => "common.html", template => "shell-call-output", replace => { line => $line }});
			}
			
			# Sanity check the new XML and restore the backup if anything goes wrong.
			my $say_ok  =  $an->String->get({key => "message_0335"});
			my $say_bad =  $an->String->get({key => "message_0336"});
			   $say_ok  =~ s/'/\\'/g;
			   $say_ok  =~ s/\\/\\\\/g;
			   $say_bad =~ s/'/\\'/g;
			   $say_bad =~ s/\\/\\\\/g;
			$shell_call = "
if \$(".$an->data->{path}{'grep'}." -q '</domain>' $definition_file);
then
    ".$an->data->{path}{echo}." '$say_ok'; 
else 
    ".$an->data->{path}{echo}." revert
    ".$an->data->{path}{echo}." '$say_bad';
    ".$an->data->{path}{cp}." -f $backup_file $definition_file
fi
";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "target",     value1 => $target,
				name2 => "shell_call", value2 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$target,
				port		=>	$port, 
				password	=>	$password,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /revert/)
				{
					$hardware_changed = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "hardware_changed", value1 => $hardware_changed,
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					print $an->Web->template({file => "common.html", template => "shell-call-output", replace => { line => $line }});
				}
			}
			# This just puts a space under the output above.
			print $an->Web->template({file => "common.html", template => "shell-call-output", replace => { line => "&nbsp;" }});
			
			# Wipe and re-read the definition file's XML and reset the amount of RAM and the 
			# number of CPUs allocated to this machine.
			$an->data->{server}{$server}{xml}    = [];
			@{$an->data->{server}{$server}{xml}} = split/\n/, $new_definition;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "requested_ram",                   value1 => $requested_ram,
				name2 => "server::${server}::details::ram", value2 => $an->data->{server}{$server}{details}{ram},
			}, file => $THIS_FILE, line => __LINE__});
			
			$an->data->{server}{$server}{details}{ram} = ($requested_ram * 1024);
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "server::${server}::details::ram", value1 => $an->data->{server}{$server}{details}{ram},
			}, file => $THIS_FILE, line => __LINE__});
			
			$an->data->{resources}{allocated_ram}            = $other_allocated_ram + ($requested_ram * 1024);
			$an->data->{server}{$server}{details}{cpu_count} = $requested_cpus;
		}
	}
	
	# Was there an error?
	if ($db_error)
	{
		print $an->Web->template({file => "server.html", template => "update-server-db-error", replace => { error => $db_error }});
	}
	
	# If the server is running, tell the user they need to power it off.
	if ($hardware_changed)
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "host", value1 => $an->data->{server}{$server}{current_host},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{server}{$server}{current_host})
		{
			print $an->Web->template({file => "server.html", template => "server-poweroff-required-message"});
		}
	}
	if ($database_changed)
	{
		if (not $hardware_changed)
		{
			# Tell the user that there were no hardware changes made so that we don't have an 
			# empty box.
			print $an->Web->template({file => "server.html", template => "server-updated-note-no-hardware-changed"});
		}
		print $an->Web->template({file => "server.html", template => "server-updated-note"});
	}
	
	# Did something change?
	if (($hardware_changed) or ($database_changed))
	{
		# Yup, we're good.
		print $an->Web->template({file => "server.html", template => "update-server-config-footer", replace => { url => "?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&server=".$an->data->{cgi}{server}."&task=manage_server" }});
		
		$an->Striker->_footer();
		$an->nice_exit({exit_code => 0});
	}
	else
	{
		# Nothing changed.
		print $an->Web->template({file => "server.html", template => "no-change-message"});
	}
	
	return (0);
}

# This takes a node name and an LV and checks the DRBD resources to see if they are Primary and UpToDate.
sub _check_lv
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_check_lv" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $server     = $parameter->{server};
	my $lv         = $parameter->{logical_volume};
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0008", message_variables => {
		name1 => "server",     value1 => $server,
		name2 => "lv",         value2 => $lv,
		name3 => "node_uuid",  value3 => $node_uuid,
		name4 => "node_key",   value4 => $node_key,
		name5 => "anvil_name", value5 => $anvil_name,
		name6 => "node_name",  value6 => $node_name,
		name7 => "target",     value7 => $target,
		name8 => "port",       value8 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If this node is down, just return.
	if ($an->data->{node}{$node_name}{daemon}{clvmd}{exit_code} ne "0")
	{
		# Node is down, skip LV check.
		$an->Log->entry({log_level => 3, message_key => "log_0258", message_variables => {
			node           => $node_name, 
			logical_volume => $lv,
			server         => $server, 
		}, file => $THIS_FILE, line => __LINE__});
		return(0);
	}
	
	$an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{active} = $an->data->{node}{$node_name}{lvm}{lv}{$lv}{active};
	$an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{size}   = $an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node_name}{lvm}{lv}{$lv}{total_size} });
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "node::${node_name}::lvm::lv::${lv}::active",     value1 => $an->data->{node}{$node_name}{lvm}{lv}{$lv}{active},
		name2 => "node::${node_name}::lvm::lv::${lv}::on_devices", value2 => $an->data->{node}{$node_name}{lvm}{lv}{$lv}{on_devices},
		name3 => "server::${server}::node::${node_name}::lv::${lv}::size", value3 => $an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{size},
	}, file => $THIS_FILE, line => __LINE__});
	
	# If there is a comman in the devices, the LV spans multiple devices.
	foreach my $device (split/,/, $an->data->{node}{$node_name}{lvm}{lv}{$lv}{on_devices})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "device", value1 => $device,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Find the resource name.
		my $on_res;
		foreach my $res (sort {$a cmp $b} keys %{$an->data->{drbd}})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "res", value1 => $res,
			}, file => $THIS_FILE, line => __LINE__});
			
			my $res_device = $an->data->{drbd}{$res}{node}{$node_name}{device};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "res",        value1 => $res,
				name2 => "device",     value2 => $device,
				name3 => "res_device", value3 => $res_device,
			}, file => $THIS_FILE, line => __LINE__});
			if ($device eq $res_device)
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "res", value1 => $res,
				}, file => $THIS_FILE, line => __LINE__});
				$on_res = $res;
				last;
			}
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "server",    value1 => $server,
			name2 => "node_name", value2 => $node_name,
			name3 => "lv",        value3 => $lv,
			name4 => "on_res",    value4 => $on_res,
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}{$on_res}{connection_state} = $an->data->{drbd}{$on_res}{node}{$node_name}{connection_state};
		$an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}{$on_res}{role}             = $an->data->{drbd}{$on_res}{node}{$node_name}{role};
		$an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}{$on_res}{disk_state}       = $an->data->{drbd}{$on_res}{node}{$node_name}{disk_state};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "server::${server}::node::${node_name}::lv::${lv}::drbd::${on_res}::connection_state", value1 => $an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}{$on_res}{connection_state},
			name2 => "server::${server}::node::${node_name}::lv::${lv}::drbd::${on_res}::role",             value2 => $an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}{$on_res}{role},
			name3 => "server::${server}::node::${node_name}::lv::${lv}::drbd::${on_res}::disk_state",       value3 => $an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}{$on_res}{disk_state},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return (0);
}

# This checks the daemons running on a node and returns '1' if all are running.
sub _check_node_daemons
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_check_node_daemons" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $data       = $parameter->{data};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
		name1 => "node_uuid",  value1 => $node_uuid,
		name2 => "node_key",   value2 => $node_key,
		name3 => "anvil_name", value3 => $anvil_name,
		name4 => "node_name",  value4 => $node_name,
		name5 => "target",     value5 => $target,
		name6 => "port",       value6 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $node_name)
	{
		my $say_message = $an->String->get({key => "message_0466"});
		$an->Striker->_error({message => $say_message});
	}
	my $ready = 1;
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
		name1 => "node::${node_name}::daemon::rgmanager::exit_code", value1 => $an->data->{node}{$node_name}{daemon}{rgmanager}{exit_code},
		name2 => "node::${node_name}::daemon::cman::exit_code",      value2 => $an->data->{node}{$node_name}{daemon}{cman}{exit_code},
		name3 => "node::${node_name}::daemon::drbd::exit_code",      value3 => $an->data->{node}{$node_name}{daemon}{drbd}{exit_code},
		name4 => "node::${node_name}::daemon::clvmd::exit_code",     value4 => $an->data->{node}{$node_name}{daemon}{clvmd}{exit_code},
		name5 => "node::${node_name}::daemon::gfs2::exit_code",      value5 => $an->data->{node}{$node_name}{daemon}{gfs2}{exit_code},
		name6 => "node::${node_name}::daemon::libvirtd::exit_code",  value6 => $an->data->{node}{$node_name}{daemon}{libvirtd}{exit_code},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node_name}{daemon}{cman}{exit_code}      ne "0") or
	    ($an->data->{node}{$node_name}{daemon}{rgmanager}{exit_code} ne "0") or
	    ($an->data->{node}{$node_name}{daemon}{drbd}{exit_code}      ne "0") or
	    ($an->data->{node}{$node_name}{daemon}{clvmd}{exit_code}     ne "0") or
	    ($an->data->{node}{$node_name}{daemon}{gfs2}{exit_code}      ne "0") or
	    ($an->data->{node}{$node_name}{daemon}{libvirtd}{exit_code}  ne "0"))
	{
		$ready = 0;
	}
	
	return($ready);
}

# This checks a node to see if it is ready to run a given server.
sub _check_node_readiness
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_check_node_readiness" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $server     = $parameter->{server};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
		name1 => "node_uuid",  value1 => $node_uuid,
		name2 => "node_key",   value2 => $node_key,
		name3 => "anvil_name", value3 => $anvil_name,
		name4 => "node_name",  value4 => $node_name,
		name5 => "target",     value5 => $target,
		name6 => "port",       value6 => $port,
		name7 => "server",     value7 => $server,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $node_name)
	{
		my $say_message = $an->String->get({key => "message_0468", variables => { server => $server }});
		$an->Striker->_error({message => $say_message});
	}
	
	# This will get negated if something isn't ready.
	my $ready = $an->Striker->_check_node_daemons({node => $node_uuid});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "server",        value1 => $server,
		name2 => "node_name", value2 => $node_name,
		name3 => "ready",     value3 => $ready,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Make sure the storage is ready.
	if ($ready)
	{
		# Still alive, find out what storage backs this server and ensure that the LV is 'active' and
		# that the DRBD resource(s) they sit on are Primary and UpToDate.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "node_name", value1 => $node_name,
			name2 => "server",        value2 => $server,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Striker->_read_server_definition({node => $node_uuid, server => $server});
		
		foreach my $lv (sort {$a cmp $b} keys %{$an->data->{server}{$server}{node}{$node_name}{lv}})
		{
			# Make sure the LV is active.
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "server::${server}::node::${node_name}::lv::${lv}::active", value1 => $an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{active},
			}, file => $THIS_FILE, line => __LINE__});
			if ($an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{active})
			{
				# It is active, so now check the backing storage.
				foreach my $resource (sort {$a cmp $b} keys %{$an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}})
				{
					# For easier reading...
					my $connection_state = $an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}{$resource}{connection_state};
					my $role             = $an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}{$resource}{role};
					my $disk_state       = $an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}{$resource}{disk_state};
					$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
						name1 => "resource",         value1 => $resource,
						name2 => "connection_state", value2 => $connection_state,
						name3 => "role",             value3 => $role,
						name4 => "disk_state",       value4 => $disk_state,
					}, file => $THIS_FILE, line => __LINE__});
					
					# I consider a node "ready" if it is UpToDate and Primary.
					if (($role ne "Primary") or ($disk_state ne "UpToDate"))
					{
						$ready = 0;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "ready", value1 => $ready,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
			}
			else
			{
				# The LV is inactive.
				$ready = 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "server",        value1 => $server,
					name2 => "node_name", value2 => $node_name,
					name3 => "ready",     value3 => $ready,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "server",    value1 => $server,
		name2 => "node_name", value2 => $node_name,
		name3 => "ready",     value3 => $ready,
	}, file => $THIS_FILE, line => __LINE__});
	
	return ($ready);
}

# This simply checks that the peer can be accessed on all three networks. Returns '1' if all are available,
# '0' otherwise. This also returns '1' if 'cman' is running on the peer, '0' if not (or not found).
sub _check_peer_access
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_check_peer_access" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Do a quick scan to get details about the nodes
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "sys::anvil::node1::uuid", value1 => $an->data->{sys}{anvil}{node1}{uuid},
		name2 => "sys::anvil::node2::uuid", value2 => $an->data->{sys}{anvil}{node2}{uuid},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Striker->scan_node({uuid => $an->data->{sys}{anvil}{node1}{uuid}, short_scan => 1});
	$an->Striker->scan_node({uuid => $an->data->{sys}{anvil}{node2}{uuid}, short_scan => 1});
	
	# The node name passed in CGI is the node we're going to join to the Anvil!. So that is the machine
	# we will log into and from there, test access to the peer.
	my $node_name     = $an->data->{cgi}{node_name};
	my $node_key      = $an->data->{sys}{node_name}{$node_name}{node_key};
	my $peer_key      = $an->data->{sys}{node_name}{$node_name}{peer_node_key};
	my $target        = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port          = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password      = $an->data->{sys}{anvil}{$node_key}{password};
	my $peer_bcn_ip   = $an->data->{sys}{anvil}{$peer_key}{bcn_ip};
	my $peer_sn_ip    = $an->data->{sys}{anvil}{$peer_key}{sn_ip};
	my $peer_ifn_ip   = $an->data->{sys}{anvil}{$peer_key}{ifn_ip};
	my $peer_password = $an->data->{sys}{anvil}{$peer_key}{ifn_ip};
	my $peer_target   = $an->data->{sys}{anvil}{$peer_key}{use_ip};
	my $peer_port     = $an->data->{sys}{anvil}{$peer_key}{use_port};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0010", message_variables => {
		name1  => "node_name",   value1  => $node_name,
		name2  => "node_key",    value2  => $node_key,
		name3  => "peer_key",    value3  => $peer_key,
		name4  => "target",      value4  => $target,
		name5  => "port",        value5  => $port,
		name6  => "peer_bcn_ip", value6  => $peer_bcn_ip,
		name7  => "peer_sn_ip",  value7  => $peer_sn_ip,
		name8  => "peer_ifn_ip", value8  => $peer_ifn_ip,
		name9  => "peer_target", value9  => $peer_target,
		name10 => "peer_port",   value10 => $peer_port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "password",      value1 => $password,
		name2 => "peer_password", value2 => $peer_password,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $peer_access  = 1;
	foreach my $peer_ip ($peer_bcn_ip, $peer_sn_ip, $peer_ifn_ip)
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "peer_ip", value1 => $peer_ip,
		}, file => $THIS_FILE, line => __LINE__});
		
		# We need to use '-o StrictHostKeyChecking=no' because the installer doesn't populate 
		# known_hosts for the IPs (and even if it did, this would fail if/when the user changed the
		# IP(s). In m3, we'll setup a mechanism to change IP addresses that handles this properly.
		my $success    = 0;
		my $shell_call = $an->data->{path}{ssh}." -o StrictHostKeyChecking=no root\@".$peer_ip." \"".$an->data->{path}{echo}." 1\"";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line eq "1")
			{
				$success = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "success", value1 => $success, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		$peer_access = 0 if not $success;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "peer_access", value1 => $peer_access, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# If I have access, check cman's state.
	my $peer_cman_up = 0;
	my $shell_call   = $an->data->{path}{initd}."/cman status; ".$an->data->{path}{echo}." rc:\$?";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$peer_target,
		port		=>	$peer_port, 
		password	=>	$peer_password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line eq "rc:0")
		{
			$peer_cman_up = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "peer_cman_up", value1 => $peer_cman_up, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "peer_access",  value1 => $peer_access,
		name2 => "peer_cman_up", value2 => $peer_cman_up,
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "peer_access",  value1 => $peer_access,
		name2 => "peer_cman_up", value2 => $peer_cman_up,
	}, file => $THIS_FILE, line => __LINE__});
	return($peer_access, $peer_cman_up);
}

### TODO: Make this handle a case where load-shedding fails if neither node can be stopped because both nodes
###       are SyncSource.
# This sequentially stops all servers, withdraws both nodes and powers down the Anvil!.
sub _cold_stop_anvil
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_cold_stop_anvil" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Canceling the UPS, unless specified, will depend on whether it is enabled locally or not.
	my $cancel_ups = $parameter->{cancel_ups} ? $parameter->{cancel_ups} : $an->data->{sys}{install_manifest}{'use_anvil-kick-apc-ups'};
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "cancel_ups", value1 => $cancel_ups,
		name2 => "anvil_uuid", value2 => $anvil_uuid,
		name3 => "anvil_name", value3 => $anvil_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $proceed = 1;
	
	# Has the timer expired?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "current time", value1 => time,
		name2 => "cgi::expire",  value2 => $an->data->{cgi}{expire},
	}, file => $THIS_FILE, line => __LINE__});
	if (time > $an->data->{cgi}{expire})
	{
		# Abort!
		my $say_title   = $an->String->get({key => "title_0184"});
		my $say_message = $an->String->get({key => "message_0443", variables => { anvil => $anvil_name }});
		print $an->Web->template({file => "server.html", template => "request-expired", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});
		return(1);
	}
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	# Set the delay. This will set the hosts -> host_stop_reason to be time + sys::power_off_delay if we
	# have a sub-task. We'll also check to see if the UPSes are still accessing. Even if 'note=no_abort',
	# we can not proceed unless both/all UPSes are available
	my $delay = 0;
	if (($an->data->{cgi}{subtask} eq "power_cycle") or ($an->data->{cgi}{subtask} eq "power_off"))
	{
		$delay = 1;
		
		# If any UPSes are inaccessible, abort.
		my $access = $an->Striker->access_all_upses({anvil_uuid => $an->data->{sys}{anvil}{uuid}});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "access", value1 => $access,
		}, file => $THIS_FILE, line => __LINE__});
		
		if (not $access)
		{
			# <sad sad sounds>
			my $say_title   = $an->String->get({key => "title_0184"});
			my $say_message = $an->String->get({key => "message_0487", variables => { anvil => $anvil_name }});
			print $an->Web->template({file => "server.html", template => "request-expired", replace => { 
				title	=>	$say_title,
				message	=>	$say_message,
			}});
			return(1);
		}
	}
	
	# If the system is already down, the user may be asking to power cycle/ power off the rack anyway.
	# So if the Anvil! is down, we'll instead perform the requested sub-task using our local copy of the
	# kick script.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "sys::anvil::node1::online", value1 => $an->data->{sys}{anvil}{node1}{online},
		name2 => "sys::anvil::node2::online", value2 => $an->data->{sys}{anvil}{node2}{online},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{sys}{anvil}{node1}{online}) or ($an->data->{sys}{anvil}{node2}{online}))
	{
		# One or both nodes are up. So do the shutdown of the system first.
		my $timestamp   = $an->Get->date_and_time({split_date_time => 0});
		my $say_title   = $an->String->get({key => "title_0181", variables => { anvil => $anvil_name }});
		my $say_message = $an->String->get({key => "message_0488", variables => { timestamp => $timestamp }});
		print $an->Web->template({file => "server.html", template => "cold-stop-header", replace => { 
			title   => $say_title, 
			message => $say_message, 
		}});
		
		# Find a node to use to stop the servers.
		my ($target, $port, $password, $node_name) = $an->Cman->find_node_in_cluster();
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node_name", value1 => $node_name,
			name2 => "target",    value2 => $target,
			name3 => "port",      value3 => $port,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password,
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $server (sort {$a cmp $b} keys %{$an->data->{server}})
		{
			my $host  = $an->data->{server}{$server}{host};
			my $state = $an->data->{server}{$server}{'state'};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "server", value1 => $server,
				name2 => "host",   value2 => $host,
				name3 => "state",  value3 => $state,
			}, file => $THIS_FILE, line => __LINE__});
			
			# Shut it down if it was started.
			if ($state =~ /start/)
			{
				my $say_message =  $an->String->get({key => "message_0420", variables => { server => $server }});
				print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
					row_class	=>	"highlight_detail_bold",
					row		=>	"#!string!row_0270!#",
					message_class	=>	"td_hidden_white",
					message		=>	"$say_message",
				}});
				
				my $shell_output = "";
				my $shell_call   = $an->data->{path}{'anvil-stop-server'}." --server $server --reason cold_stop";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "target",     value1 => $target,
					name2 => "shell_call", value2 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
				my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$target,
					port		=>	$port, 
					password	=>	$password,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					$line =~ s/Local machine/$node_name/;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
					
					$line         =  $an->Web->parse_text_line({line => $line});
					$shell_output .= "$line<br />\n";
					if ($line =~ /success/i)
					{
						$an->data->{server}{$server}{'state'} = "disabled";
					}
				}
				$shell_output =~ s/\n$//;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "shell_output", value1 => $shell_output,
				}, file => $THIS_FILE, line => __LINE__});
				print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
					row_class	=>	"code",
					row		=>	"#!string!row_0127!#",
					message_class	=>	"quoted_text",
					message		=>	$shell_output,
				}});
			}
		}
		
		# Start the UPS timer here and abort if the timer doesn't start.
		
		
		# Now, stop the nodes. If both nodes are up, we'll call '--cold-stop' to invoke 
		# 'anvil-safe-stop's logic to determine which node should die first. We'll look for 
		# 'poweroff: X' to determine which node went down.
		if (($an->data->{sys}{anvil}{node1}{online}) && ($an->data->{sys}{anvil}{node2}{online}))
		{
			# Both are up, so call the load-shed from node 1.
			my $node_name = $an->data->{sys}{anvil}{node1}{name};
			my $target    = $an->data->{sys}{anvil}{node1}{use_ip};
			my $port      = $an->data->{sys}{anvil}{node1}{use_port};
			my $password  = $an->data->{sys}{anvil}{node1}{password};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "node_name", value1 => $node_name,
				name2 => "target",    value2 => $target,
				name3 => "port",      value3 => $port,
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
				name1 => "password", value1 => $password,
			}, file => $THIS_FILE, line => __LINE__});
			
			# If 'cancel_ups' is set, we will stop the UPS timer. 
			my $shell_output = "";
			my $shell_call   = $an->data->{path}{timeout}." 120 ".$an->data->{path}{'anvil-safe-stop'}." --local --reason cold_stop; ".$an->data->{path}{echo}." rc:\$?";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "target",     value1 => $target,
				name2 => "shell_call", value2 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$target,
				port		=>	$port, 
				password	=>	$password,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line,
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /poweroff: (.*)$/)
				{
					# This is the first node to die. Mark it as offline.
					my $node_name = $1;
					my $node_key  = $an->data->{sys}{node_name}{$node_name}{node_key};
					my $node_uuid = $an->data->{sys}{anvil}{$node_key}{uuid};
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "node_name", value1 => $node_name,
						name2 => "node_key",  value2 => $node_key,
						name3 => "node_uuid", value3 => $node_uuid,
					}, file => $THIS_FILE, line => __LINE__});
					
					# Error out if we failed to get the node name.
					if (not $node_name)
					{
						$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0142", code => 142, file => $THIS_FILE, line => __LINE__});
						return("");
					}
					if (not $node_uuid)
					{
						$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0157", message_variables => { node_name => $node_name }, code => 157, file => $THIS_FILE, line => __LINE__});
						return("");
					}
					
					$an->data->{sys}{anvil}{$node_key}{online} = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "sys::anvil::${node_key}::online", value1 => $an->data->{sys}{anvil}{$node_key}{online},
					}, file => $THIS_FILE, line => __LINE__});
					
					$an->Log->entry({log_level => 2, message_key => "log_0250", message_variables => {
						node  => $node_name, 
						delay => $delay, 
					}, file => $THIS_FILE, line => __LINE__});
					$an->Striker->mark_node_as_clean_off({node_uuid => $node_uuid, delay => $delay});
				}
				elsif ($line =~ /rc:(\d+)/)
				{
					# Something went wrong.
					my $return_code = $1;
					
					if ($return_code eq "124")
					{
						$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0190", message_variables => { node_name => $node_name }, code => 190, file => $THIS_FILE, line => __LINE__});
						return("");
					}
				}
				else
				{
					$line         =  $an->Web->parse_text_line({line => $line});
					$shell_output .= "$line<br />\n";
				}
			}
			
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_output", value1 => $shell_output,
			}, file => $THIS_FILE, line => __LINE__});
			print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
				row_class	=>	"code",
				row		=>	"#!string!row_0127!#",
				message_class	=>	"quoted_text",
				message		=>	$shell_output,
			}});
		}
		
		# Now, only one node should be left up
		foreach my $node_key ("node1", "node2")
		{
			my $node_name = $an->data->{sys}{anvil}{$node_key}{name};
			my $node_uuid = $an->data->{sys}{anvil}{$node_key}{uuid};
			my $online    = $an->data->{sys}{anvil}{$node_key}{online};
			my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
			my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
			my $password  = $an->data->{sys}{anvil}{$node_key}{password};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
				name1 => "node_name", value1 => $node_name,
				name2 => "node_uuid", value2 => $node_uuid,
				name3 => "online",    value3 => $online,
				name4 => "target",    value4 => $target,
				name5 => "port",      value5 => $port,
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
				name1 => "password", value1 => $password,
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($online)
			{
				### NOTE: Madi: Even with 'timeout 1200', it stopped loading the page, 
				###             removing timeout entirely but the problem probably lies 
				###             elsewhere. Not that nothing is recorded in http/error_log.
				# We'll shut down with 'anvil-safe-stop'. No servers should be running, but 
				# just in case we oopsed and left one up, set the stop reason.
				my $shell_output = "";
				my $shell_call   = $an->data->{path}{'anvil-safe-stop'}." --local --reason cold_stop; ".$an->data->{path}{echo}." rc:\$?";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "target",     value1 => $target,
					name2 => "shell_call", value2 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
				my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$target,
					port		=>	$port, 
					password	=>	$password,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
					
					if ($line =~ /poweroff: (.*)$/)
					{
						my $node_name = $1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "node_name", value1 => $node_name,
						}, file => $THIS_FILE, line => __LINE__});
						
						# Loop until I can't ping it.
						my $stop_waiting = time + 30;
						my $waiting      = 1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "stop_waiting", value1 => $stop_waiting,
						}, file => $THIS_FILE, line => __LINE__});
						while ($waiting)
						{
							my $ping = $an->Check->ping({ping => $target});
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "ping", value1 => $ping,
							}, file => $THIS_FILE, line => __LINE__});
							if ($ping)
							{
								# Still alive, wait.
								sleep 1;
							}
							else
							{
								# It's down, we're done.
								$waiting = 0;
								$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
									name1 => "waiting", value1 => $waiting,
								}, file => $THIS_FILE, line => __LINE__});
							}
							
							my $current_time = time;
							my $difference   = $stop_waiting - $current_time;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
								name1 => "stop_waiting", value1 => $stop_waiting,
								name2 => "current_time", value2 => $current_time,
								name3 => "difference",   value3 => $difference,
							}, file => $THIS_FILE, line => __LINE__});
							if (time > $stop_waiting)
							{
								# Taking too long, stop waiting.
								$waiting = 0;
								$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
									name1 => "waiting", value1 => $waiting,
								}, file => $THIS_FILE, line => __LINE__});
							}
						}
					}
					elsif ($line =~ /rc:(\d+)/)
					{
						# Something went wrong.
						my $return_code = $1;
						
						if ($return_code eq "124")
						{
							$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0190", message_variables => { node_name => $node_name }, code => 190, file => $THIS_FILE, line => __LINE__});
							return("");
						}
					}
					else
					{
						$line = $an->Web->parse_text_line({line => $line});
						$shell_output .= "$line<br />\n";
					}
				}
				$an->Striker->mark_node_as_clean_off({node_uuid => $node_uuid, delay => $delay});
		
				$shell_output =~ s/\n$//;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "shell_output", value1 => $shell_output,
				}, file => $THIS_FILE, line => __LINE__});
				print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
					row_class	=>	"code",
					row		=>	"#!string!row_0127!#",
					message_class	=>	"quoted_text",
					message		=>	$shell_output,
				}});
			}
		}
		
		# All done!
		print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
			row_class	=>	"highlight_good_bold",
			row		=>	"#!string!row_0083!#",
			message_class	=>	"td_hidden_white",
			message		=>	"#!string!message_0429!#",
		}});
	}
	elsif ($an->data->{cgi}{note} eq "no_abort")
	{
		# The user called this while the Anvil! was down, so don't throw a warning.
		my $say_subtask = $an->data->{cgi}{subtask} eq "power_cycle" ? "#!string!button_0065!#" : "#!string!button_0066!#";
		my $timestamp   = $an->Get->date_and_time({split_date_time => 0});
		my $say_title   = $an->String->get({key => "title_0153", variables => { subtask => $say_subtask }});
		my $say_message = $an->String->get({key => "message_0488", variables => { timestamp => $timestamp }});
		print $an->Web->template({file => "server.html", template => "cold-stop-header", replace => { 
			title   => $say_title,
			message => $say_message, 
		}});
	}
	else
	{
		# Already down, abort.
		my $say_title   = $an->String->get({key => "title_0180", variables => { anvil => $anvil_name }});
		my $say_message = $an->String->get({key => "message_0419", variables => { anvil => $anvil_name }});
		print $an->Web->template({file => "server.html", template => "cold-stop-aborted", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});
	}
	
	# If I have a sub-task, perform it now.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::subtask", value1 => $an->data->{cgi}{subtask},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{cgi}{subtask} eq "power_cycle")
	{
		# Sleep until both nodes are off.
		my $time         = time;
		my $stop_waiting = $time + 120;
		my $both_down    = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "time",         value1 => $time,
			name2 => "stop_waiting", value2 => $stop_waiting,
		}, file => $THIS_FILE, line => __LINE__});
		until ($both_down)
		{
			$both_down = 1;
			if (time > $stop_waiting)
			{
				# Give up waiting
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "both_down", value1 => $both_down,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Try pinging both nodes.
				my $ping_node1 = 0;
				my $ping_node2 = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "sys::anvil::node1::bcn_ip", value1 => $an->data->{sys}{anvil}{node1}{bcn_ip},
					name2 => "sys::anvil::node2::bcn_ip", value2 => $an->data->{sys}{anvil}{node2}{bcn_ip},
				}, file => $THIS_FILE, line => __LINE__});
				if ($an->Validate->is_ipv4({ip => $an->data->{sys}{anvil}{node1}{bcn_ip}}))
				{
					$ping_node1 = $an->Check->ping({ping => $an->data->{sys}{anvil}{node1}{bcn_ip}});
				}
				if ($an->Validate->is_ipv4({ip => $an->data->{sys}{anvil}{node1}{bcn_ip}}))
				{
					$ping_node2 = $an->Check->ping({ping => $an->data->{sys}{anvil}{node2}{bcn_ip}});
				}
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "ping_node1", value1 => $ping_node1,
					name2 => "ping_node2", value2 => $ping_node2,
				}, file => $THIS_FILE, line => __LINE__});
				if (($ping_node1) or ($ping_node2))
				{
					$both_down = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "both_down", value1 => $both_down,
					}, file => $THIS_FILE, line => __LINE__});
					sleep 5;
				}
			}
		}
		
		# Tell the user
		print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
			row_class	=>	"highlight_warning_bold",
			row		=>	"#!string!row_0044!#",
			message_class	=>	"td_hidden_white",
			message		=>	"#!string!explain_0154!#",
		}});
		
		# Nighty night, see you in the morning!
		my $shell_call = $an->data->{path}{'call_anvil-kick-apc-ups'}." --reboot --force";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
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
	elsif($an->data->{cgi}{subtask} eq "power_off")
	{
		# Sleep until both nodes are off.
		my $time         = time;
		my $stop_waiting = $time + 120;
		my $both_down    = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "time",         value1 => $time,
			name2 => "stop_waiting", value2 => $stop_waiting,
		}, file => $THIS_FILE, line => __LINE__});
		until ($both_down)
		{
			$both_down = 1;
			if (time > $stop_waiting)
			{
				# Give up waiting
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "both_down", value1 => $both_down,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Try pinging both nodes.
				my $ping_node1 = $an->Check->ping({ping => $an->data->{sys}{anvil}{node1}{use_ip}});
				my $ping_node2 = $an->Check->ping({ping => $an->data->{sys}{anvil}{node2}{use_ip}});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "ping_node1", value1 => $ping_node1,
					name2 => "ping_node2", value2 => $ping_node2,
				}, file => $THIS_FILE, line => __LINE__});
				if (($ping_node1) or ($ping_node2))
				{
					$both_down = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "both_down", value1 => $both_down,
					}, file => $THIS_FILE, line => __LINE__});
					sleep 5;
				}
			}
		}
		
		# Tell the user
		print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
			row_class	=>	"highlight_warning_bold",
			row		=>	"#!string!row_0044!#",
			message_class	=>	"td_hidden_white",
			message		=>	"#!string!explain_0155!#",
		}});
		
		# Do eet!
		my $shell_call = $an->data->{path}{'call_anvil-kick-apc-ups'}." --shutdown --force";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
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
	
	# All done.
	print $an->Web->template({file => "server.html", template => "cold-stop-footer"});
	$an->Striker->_footer();
	
	return(0);
}

# Confirm that the user wants to cold-stop the Anvil!.
sub _confirm_cold_stop_anvil
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_confirm_cold_stop_anvil" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_message = $an->String->get({key => "message_0418", variables => { anvil => $anvil_name }});
	
	# If there is a subtype, use a different warning.
	if ($an->data->{cgi}{subtask} eq "power_cycle")
	{
		$say_message = $an->String->get({key => "message_0439", variables => { anvil => $anvil_name }});
	}
	elsif($an->data->{cgi}{subtask} eq "power_off")
	{
		$say_message = $an->String->get({key => "message_0440", variables => { anvil => $anvil_name }});
	}
	
	my $expire_time                 =  time + $an->data->{sys}{actime_timeout};
	   $an->data->{sys}{cgi_string} =~ s/expire=(\d+)/expire=$expire_time/;
	print $an->Web->template({file => "server.html", template => "confirm-cold-stop", replace => { 
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});

	return (0);
}

# Confirm that the user wants to delete the server.
sub _confirm_delete_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_confirm_delete_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});

	# Ask the user to confirm
	my $say_title   = $an->String->get({key => "title_0045", variables => { server => $an->data->{cgi}{server} }});
	my $say_message = $an->String->get({key => "message_0178", variables => { server => $an->data->{cgi}{server} }});
	
	my $expire_time =  time + $an->data->{sys}{actime_timeout};
	if ($an->data->{sys}{cgi_string} =~ /expire=/)
	{
		$an->data->{sys}{cgi_string} =~ s/expire=(\d+)/expire=$expire_time/;
	}
	else
	{
		$an->data->{sys}{cgi_string} .= "&expire=$expire_time";
	}
	
	print $an->Web->template({file => "server.html", template => "confirm-delete-server", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});
	
	return (0);
}

# Confirm that the user wants to boot both nodes.
sub _confirm_dual_boot
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_confirm_dual_boot" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $say_message = $an->String->get({key => "message_0161", variables => { anvil => $anvil_name }});
	print $an->Web->template({file => "server.html", template => "confirm-dual-poweron-node", replace => { 
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});

	return (0);
}

# Confirm that the user wants to join both nodes to the Anvil!.
sub _confirm_dual_join
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_confirm_dual_join" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $say_title   = $an->String->get({key => "title_0037", variables => { anvil => $anvil_name }});
	my $say_message = $an->String->get({key => "message_0150", variables => { anvil => $a }});
	print $an->Web->template({file => "server.html", template => "confirm-dual-join-anvil", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});
	
	return (0);
}

# Confirm that the user wants to fence a nodes.
sub _confirm_fence_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_confirm_fence_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_title                   =  $an->String->get({key => "title_0038", variables => { node_name => $an->data->{cgi}{node_name} }});
	my $say_message                 =  $an->String->get({key => "message_0151", variables => { node_name => $an->data->{cgi}{node_name} }});
	my $expire_time                 =  time + $an->data->{sys}{actime_timeout};
	   $an->data->{sys}{cgi_string} =~ s/expire=(\d+)/expire=$expire_time/;
	print $an->Web->template({file => "server.html", template => "confirm-fence-node", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});

	return (0);
}

# Confirm that the user wants to force-off a VM.
sub _confirm_force_off_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_confirm_force_off_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_title   = $an->String->get({key => "title_0044", variables => { server => $an->data->{cgi}{server} }});
	my $say_message = $an->String->get({key => "message_0168", variables => { server => $an->data->{cgi}{server} }});
	
	my $expire_time = time + $an->data->{sys}{actime_timeout};
	if ($an->data->{sys}{cgi_string} =~ /expire=/)
	{
		$an->data->{sys}{cgi_string} =~ s/expire=(\d+)/expire=$expire_time/;
	}
	else
	{
		$an->data->{sys}{cgi_string} .= "expire=$expire_time";
	}

	print $an->Web->template({file => "server.html", template => "confirm-force-off-server", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});
	
	return (0);
}

# Confirm that the user wants to join a node to the Anvil!.
sub _confirm_join_anvil
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_confirm_join_anvil" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm. This happens either because the peer node is not running cman or because 
	# (one of) the peer's network links didn't work.
	my $anvil_uuid     = $an->data->{cgi}{anvil_uuid};
	my $anvil_name     = $an->data->{sys}{anvil}{name};
	my $node_name      = $an->data->{cgi}{node_name};
	my $confirm_reason = $parameter->{confirm_reason} ? $parameter->{confirm_reason} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "node_name",  value3 => $node_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $say_title = $an->String->get({key => "title_0036", variables => { 
			node_name	=>	$an->data->{cgi}{node_name},
			anvil		=>	$anvil_name,
		}});
	my $say_message = $an->String->get({key => "message_0147", variables => { node_name => $an->data->{cgi}{node_name} }});
	print $an->Web->template({file => "server.html", template => "confirm-join-anvil", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		reason		=>	$confirm_reason, 
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});

	return (0);
}

# Confirm that the user wants to migrate a VM.
sub _confirm_migrate_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_confirm_migrate_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make sure the server name exists.
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $server     = $an->data->{cgi}{server};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "server",     value2 => $server,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $server_uuid = $an->Get->server_uuid({
			server => $server,
			anvil  => $anvil_uuid,
		});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "server_uuid", value1 => $server_uuid,
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: Check the link speed of both nodes' BCN and use that in the calculate.
	# Calculate roughly how long the migration will take.
	my $server_data             =  $an->Get->server_data({server => $an->data->{cgi}{server}});
	my $server_ram              =  $server_data->{current_ram};
	my $migration_time_estimate =  $server_ram / 1073741824; # Get # of GB.
	   $migration_time_estimate *= 10; # ~10s / GB
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "server_ram",              value1 => $server_ram,
		name2 => "migration_time_estimate", value2 => $migration_time_estimate,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Find the target node.
	my $clustat_data = $an->Cman->get_clustat_data({
			target   => $an->data->{sys}{anvil}{node1}{use_ip},
			port     => $an->data->{sys}{anvil}{node1}{use_port},
			password => $an->data->{sys}{anvil}{node1}{password},
		});
	my $host         = $clustat_data->{server}{$server}{host};
	my $target       = $clustat_data->{server}{$server}{host} eq $clustat_data->{node}{'local'}{name} ? $clustat_data->{node}{peer}{name} : $clustat_data->{node}{'local'}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "host",   value1 => $host,
		name2 => "target", value2 => $target,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_title = $an->String->get({key => "title_0047", variables => { 
			server	=>	$an->data->{cgi}{server},
			target	=>	$target,
		}});
	my $say_message = $an->String->get({key => "message_0177", variables => { 
			server			=>	$an->data->{cgi}{server},
			target			=>	$target,
			ram			=>	$an->Readable->bytes_to_hr({'bytes' => $server_ram }),
			migration_time_estimate	=>	$migration_time_estimate,
		}});
	print $an->Web->template({file => "server.html", template => "confirm-migrate-server", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});
	
	return (0);
}

# Confirm that the user wants to power-off a nodes.
sub _confirm_poweroff_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_confirm_poweroff_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_title                   =  $an->String->get({key => "title_0039", variables => { node_name => $an->data->{cgi}{node_name} }});
	my $say_message                 =  $an->String->get({key => "message_0156", variables => { node_name => $an->data->{cgi}{node_name} }});
	my $expire_time                 =  time + $an->data->{sys}{actime_timeout};
	   $an->data->{sys}{cgi_string} =~ s/expire=(\d+)/expire=$expire_time/;
	print $an->Web->template({file => "server.html", template => "confirm-poweroff-node", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});
	
	return (0);
}

# Confirm that the user wants to boot a nodes.
sub confirm_poweron_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_poweron_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_title   = $an->String->get({key => "title_0040", variables => { node_name => $an->data->{cgi}{node_name} }});
	my $say_message = $an->String->get({key => "message_0160", variables => { node_name => $an->data->{cgi}{node_name} }});
	print $an->Web->template({file => "server.html", template => "confirm-poweron-node", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});

	return (0);
}

# This doesn't so much confirm as it does ask the user how they want to build the VM.
sub _confirm_provision_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_confirm_provision_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Sort out my data from CGI
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	my ($target, $port, $password, $node_name) = $an->Cman->find_node_in_cluster();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node_name", value1 => $node_name,
		name2 => "target",    value2 => $target,
		name3 => "port",      value3 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	my ($files, $partition) = $an->Get->shared_files({
		target   => $target,
		port     => $port,
		password => $password,
	});
	
	my $images  = [];
	foreach my $file_name (sort {$a cmp $b} keys %{$files})
	{
		next if not $files->{$file_name}{optical};
		push @{$images}, $file_name;
	}
	my $cpu_cores = [];
	foreach my $core_num (1..$an->data->{cgi}{max_cores})
	{
		if ($an->data->{cgi}{max_cores} > 9)
		{
			push @{$cpu_cores}, $core_num;
		}
		else
		{
			push @{$cpu_cores}, $core_num;
		}
	}
	   $an->data->{cgi}{cpu_cores} = 2 if not $an->data->{cgi}{cpu_cores};
	my $select_cpu_cores           = $an->Web->build_select({
			name     => "cpu_cores", 
			options  => $cpu_cores, 
			blank    => 0,
			selected => $an->data->{cgi}{cpu_cores},
			width    => 60,
		});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::max_storage", value1 => $an->data->{cgi}{max_storage},
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $storage (sort {$a cmp $b} split/,/, $an->data->{cgi}{max_storage})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "storage", value1 => $storage,
		}, file => $THIS_FILE, line => __LINE__});
		
		my ($vg, $space)                    =  ($storage =~ /^(.*?):(\d+)$/);
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "vg",    value1 => $vg,
			name2 => "space", value2 => $space,
		}, file => $THIS_FILE, line => __LINE__});
		
		my $say_max_storage                 =  $an->Readable->bytes_to_hr({'bytes' => $space });
		   $say_max_storage                 =~ s/\.(\d+)//;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "say_max_storage", value1 => $say_max_storage,
		}, file => $THIS_FILE, line => __LINE__});
		
		   $an->data->{cgi}{vg_list}        .= "$vg,";
		my $vg_key                          =  "vg_$vg";
		my $vg_suffix_key                   =  "vg_suffix_$vg";
		   $an->data->{cgi}{$vg_key}        =  ""    if not $an->data->{cgi}{$vg_key};
		   $an->data->{cgi}{$vg_suffix_key} =  "GiB" if not $an->data->{cgi}{$vg_suffix_key};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "cgi::vg_list",        value1 => $an->data->{cgi}{vg_list},
			name2 => "cgi::$vg_key",        value2 => $an->data->{cgi}{$vg_key},
			name3 => "cgi::$vg_suffix_key", value3 => $an->data->{cgi}{$vg_suffix_key},
		}, file => $THIS_FILE, line => __LINE__});
		
		my $select_vg_suffix                =  $an->Web->build_select({
				name     => $vg_suffix_key, 
				options  => ["MiB", "GiB", "TiB", "%"], 
				blank    => 0,
				selected => $an->data->{cgi}{$vg_suffix_key},
				width    => 60,
			});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "select_vg_suffix", value1 => $select_vg_suffix,
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($space < (2 ** 30))
		{
			# Less than a Terabyte
			$select_vg_suffix = $an->Web->build_select({
					name     => $vg_suffix_key, 
					options  => ["MiB", "GiB", "%"], 
					blank    => 0,
					selected => $an->data->{cgi}{$vg_suffix_key},
					width    => 60,
				});
			$an->data->{cgi}{$vg_suffix_key} = "GiB" if not $an->data->{cgi}{$vg_suffix_key};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "select_vg_suffix",    value1 => $select_vg_suffix,
				name2 => "cgi::$vg_suffix_key", value2 => $an->data->{cgi}{$vg_suffix_key},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($space < (2 ** 20))
		{
			# Less than a Gigabyte
			$select_vg_suffix = $an->Web->build_select({
					name     => $vg_suffix_key, 
					options  => ["MiB", "%"], 
					blank    => 0,
					selected => $an->data->{cgi}{$vg_suffix_key},
					width    => 60,
				});
			$an->data->{cgi}{$vg_suffix_key} = "MiB" if not $an->data->{cgi}{$vg_suffix_key};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "select_vg_suffix",    value1 => $select_vg_suffix,
				name2 => "cgi::$vg_suffix_key", value2 => $an->data->{cgi}{$vg_suffix_key},
			}, file => $THIS_FILE, line => __LINE__});
		}
		# Devine the node associated with this VG.
		my $short_vg   =  $vg;
		my $short_node =  $vg;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "short_vg",   value1 => $short_vg,
			name2 => "short_node", value2 => $short_node,
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($vg =~ /^(.*?)_(vg\d+)$/)
		{
			$short_node = $1;
			$short_vg   = $2;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "short_vg",   value1 => $short_vg,
				name2 => "short_node", value2 => $short_node,
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		my $say_node = $short_vg;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "say_node", value1 => $say_node,
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $node_key ("node1", "node2")
		{
			my $node = $an->data->{sys}{anvil}{$node_key}{name};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node", value1 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($node =~ /$short_node/)
			{
				$say_node = $node;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "say_node", value1 => $say_node,
				}, file => $THIS_FILE, line => __LINE__});
				last;
			}
		}
		
		$an->data->{vg_selects}{$vg}{space}         = $space;
		$an->data->{vg_selects}{$vg}{say_storage}   = $say_max_storage;
		$an->data->{vg_selects}{$vg}{select_suffix} = $select_vg_suffix;
		$an->data->{vg_selects}{$vg}{say_node}      = $say_node;
		$an->data->{vg_selects}{$vg}{short_vg}      = $short_vg;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
			name1 => "vg_selects::${vg}::space",         value1 => $an->data->{vg_selects}{$vg}{space},
			name2 => "vg_selects::${vg}::say_storage",   value2 => $an->data->{vg_selects}{$vg}{say_storage},
			name3 => "vg_selects::${vg}::select_suffix", value3 => $an->data->{vg_selects}{$vg}{select_suffix},
			name4 => "vg_selects::${vg}::say_node",      value4 => $an->data->{vg_selects}{$vg}{say_node},
			name5 => "vg_selects::${vg}::short_vg",      value5 => $an->data->{vg_selects}{$vg}{short_vg},
		}, file => $THIS_FILE, line => __LINE__});
	}
	my $say_selects = "";
	my $say_or      = $an->Web->template({file => "server.html", template => "provision-server-storage-pool-or-message"});
	foreach my $vg (sort {$a cmp $b} keys %{$an->data->{vg_selects}})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "vg", value1 => $vg,
		}, file => $THIS_FILE, line => __LINE__});
		
		my $space            =  $an->data->{vg_selects}{$vg}{space};
		my $say_max_storage  =  $an->data->{vg_selects}{$vg}{say_storage};
		my $select_vg_suffix =  $an->data->{vg_selects}{$vg}{select_suffix};
		my $say_node         =  $an->data->{vg_selects}{$vg}{say_node};
		   $say_node         =~ s/\..*$//;
		my $short_vg         =  $an->data->{vg_selects}{$vg}{short_vg};
		my $vg_key           =  "vg_$vg";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
			name1 => "space",            value1 => $space,
			name2 => "say_max_storage",  value2 => $say_max_storage,
			name3 => "select_vg_suffix", value3 => $select_vg_suffix,
			name4 => "say_node",         value4 => $say_node,
			name5 => "short_vg",         value5 => $short_vg,
			name6 => "vg_key",           value6 => $vg_key,
		}, file => $THIS_FILE, line => __LINE__});
		
		   $say_selects      .= $an->Web->template({file => "server.html", template => "provision-server-selects", replace => { 
				node			=>	$say_node,
				short_vg		=>	$short_vg,
				max_storage		=>	$say_max_storage,
				vg_key			=>	$vg_key,
				vg_key_value		=>	$an->data->{cgi}{$vg_key},
				select_vg_suffix	=>	$select_vg_suffix,
			}});
		$say_selects .= $say_or;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "say_selects", value1 => $say_selects,
		}, file => $THIS_FILE, line => __LINE__});
	}
	   $say_selects                 =~ s/\Q$say_or\E$//m;
	   $say_selects                 .= $an->Web->template({file => "server.html", template => "provision-server-vg-list-hidden-input", replace => { vg_list => $an->data->{cgi}{vg_list} }});
	my $say_max_ram                 =  $an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{max_ram} });
	   $an->data->{cgi}{ram}        =  2 if not $an->data->{cgi}{ram};
	   $an->data->{cgi}{ram_suffix} =  "GiB" if not $an->data->{cgi}{ram_suffix};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "say_selects",     value1 => $say_selects,
		name2 => "say_max_ram",     value2 => $say_max_ram,
		name3 => "cgi::max_ram",    value3 => $an->data->{cgi}{max_ram},
		name4 => "cgi::ram",        value4 => $an->data->{cgi}{ram},
		name5 => "cgi::ram_suffix", value5 => $an->data->{cgi}{ram_suffix},
	}, file => $THIS_FILE, line => __LINE__});
	my $select_ram_suffix           =  $an->Web->build_select({
			name     => "ram_suffix", 
			options  => ["MiB", "GiB"], 
			blank    => 0,
			selected => $an->data->{cgi}{ram_suffix},
			width    => 60,
		});
	   $an->data->{cgi}{os_variant} = "rhel6" if not $an->data->{cgi}{os_variant};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "select_ram_suffix", value1 => $select_ram_suffix,
		name2 => "cgi::os_variant",   value2 => $an->data->{cgi}{os_variant},
	}, file => $THIS_FILE, line => __LINE__});
	
	my $select_install_iso = $an->Web->build_select({
			name     => "install_iso", 
			options  => $images, 
			'sort'   => 1,
			blank    => 1,
			selected => $an->data->{cgi}{install_iso},
			width    => 300,
		});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "select_install_iso", value1 => $select_install_iso,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $select_driver_iso = $an->Web->build_select({
			name     => "driver_iso", 
			options  => $images, 
			'sort'   => 1,
			blank    => 1,
			selected => $an->data->{cgi}{driver_iso},
			width    => 300,
		});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "select_driver_iso", value1 => $select_driver_iso,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $select_os_variant = $an->Web->build_select({
			name     => "os_variant", 
			options  => $an->data->{sys}{os_variant}, 
			'sort'   => 1,
			blank    => 0,
			selected => $an->data->{cgi}{os_variant},
			width    => 300,
		});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "select_os_variant", value1 => $select_os_variant,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $say_title = $an->String->get({key => "message_0142", variables => { 
			anvil	=>	$anvil_name,
		}});
	print $an->Web->template({file => "server.html", template => "provision-server-questions", replace => { 
		title			=>	$say_title,
		name			=>	$an->data->{cgi}{name},
		select_os_variant	=>	$select_os_variant,
		media_library_url	=>	"mediaLibrary?anvil_uuid=".$anvil_uuid,
		select_install_iso	=>	$select_install_iso,
		select_driver_iso	=>	$select_driver_iso,
		say_max_ram		=>	$say_max_ram,
		ram			=>	$an->data->{cgi}{ram},
		select_ram_suffix	=>	$select_ram_suffix,
		select_cpu_cores	=>	$select_cpu_cores,
		selects			=>	$say_selects,
		anvil_uuid		=>	$an->data->{cgi}{anvil_uuid},
		task			=>	$an->data->{cgi}{task},
		max_ram			=>	$an->data->{cgi}{max_ram},
		max_cores		=>	$an->data->{cgi}{max_cores},
		max_storage		=>	$an->data->{cgi}{max_storage},
	}});
	
	return (0);
}

# Confirm that the user wants to start a server.
sub _confirm_start_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_start_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_title = $an->String->get({key => "title_0042", variables => { 
			server		=>	$an->data->{cgi}{server},
			node_name	=>	$an->data->{cgi}{node_name},
		}});
	my $say_message = $an->String->get({key => "message_0163", variables => { 
			server		=>	$an->data->{cgi}{server},
			node_name	=>	$an->data->{cgi}{node_name},
		}});
	print $an->Web->template({file => "server.html", template => "confirm-start-server", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});

	return (0);
}	

# Confirm that the user wants to stop a VM.
sub _confirm_stop_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_confirm_stop_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_title      = $an->String->get({key => "title_0043", variables => { server => $an->data->{cgi}{server} }});
	my $say_message    = $an->String->get({key => "message_0165", variables => { server => $an->data->{cgi}{server} }});
	my $say_warning    =  $an->String->get({key => "message_0166", variables => { server => $an->data->{cgi}{server} }});
	my $say_precaution =  $an->String->get({key => "message_0167"});
	my $expire_time    =  time + $an->data->{sys}{actime_timeout};
	   $an->data->{sys}{cgi_string} =~ s/expire=(\d+)/expire=$expire_time/;
	print $an->Web->template({file => "server.html", template => "confirm-stop-server", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		warning		=>	$say_warning,
		precaution	=>	$say_precaution,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true&expire=$expire_time",
	}});

	return (0);
}

# Confirm that the user wants to join both nodes to the Anvil!.
sub _confirm_withdraw_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_confirm_withdraw_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{cgi}{node_name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "node_name",  value3 => $node_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $say_title  = $an->String->get({key => "title_0035", variables => { 
			node_name	=>	$an->data->{cgi}{node_name},
			anvil		=>	$anvil_name,
		}});
	my $say_message = $an->String->get({key => "message_0145", variables => { node_name => $an->data->{cgi}{node_name} }});
	print $an->Web->template({file => "server.html", template => "confirm-withdrawl", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});
	
	return (0);
}

# This stops the server, if it is running, edits the cluster.conf to remove the server's entry, pushes the 
# changed config out, deletes the server's definition file and finally deletes the logical volume.
sub _delete_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_delete_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make sure the server name exists.
	my $server     = $an->data->{cgi}{server}     ? $an->data->{cgi}{server}     : "";
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid} ? $an->data->{cgi}{anvil_uuid} : "";
	my $anvil_name = $an->data->{sys}{anvil}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "server",     value1 => $server,
		name2 => "anvil_uuid", value2 => $anvil_uuid,
		name3 => "anvil_name", value3 => $anvil_name,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $anvil_uuid)
	{
		# Hey user, don't be cheeky!
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0134", code => 134, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	my $server_host = $an->data->{server}{$server}{host};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "server_host", value1 => $server_host,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If the server is on, we'll do our work through that node.
	my $node_key = "";
	if (($server_host) && ($server_host ne "none"))
	{
		if ($server_host eq $an->data->{sys}{anvil}{node1}{name})
		{
			$node_key = "node1";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node_key", value1 => $node_key,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($server_host eq $an->data->{sys}{anvil}{node2}{name})
		{
			$node_key = "node2";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node_key", value1 => $node_key,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node_key", value1 => $node_key,
	}, file => $THIS_FILE, line => __LINE__});
	my $node_name = "";
	my $target    = "";
	my $port      = "";
	my $password  = "";
	if ($node_key)
	{
		# Use the given node.
		$node_name = $an->data->{sys}{anvil}{$node_key}{name};
		$target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
		$port      = $an->data->{sys}{anvil}{$node_key}{use_port};
		$password  = $an->data->{sys}{anvil}{$node_key}{password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node_name", value1 => $node_name,
			name2 => "target",    value2 => $target,
			name3 => "port",      value3 => $port,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password,
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Pick either node that is up.
		($target, $port, $password, $node_name) = $an->Cman->find_node_in_cluster();
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node_name", value1 => $node_name,
			name2 => "target",    value2 => $target,
			name3 => "port",      value3 => $port,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# If I still don't have a target, then we're done.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "target", value1 => $target,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $target)
	{
		# Couldn't log into either node.
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0135", message_variables => { server => $server }, code => 135, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Has the timer expired?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "time",        value1 => time,
		name2 => "cgi::expire", value2 => $an->data->{cgi}{expire},
	}, file => $THIS_FILE, line => __LINE__});
	if (time > $an->data->{cgi}{expire})
	{
		# Abort!
		my $say_title   = $an->String->get({key => "warning_title_0010"});
		my $say_message = $an->String->get({key => "message_0472", variables => { server => $an->data->{cgi}{server} }});
		print $an->Web->template({file => "server.html", template => "request-expired", replace => { 
			title		=>	$say_title,
			message		=>	$say_message,
		}});
		return(1);
	}
	
	# Get to work!
	my $say_title = $an->String->get({key => "title_0057", variables => { server => $server }});
	print $an->Web->template({file => "server.html", template => "delete-server-header", replace => { title => $say_title }});
	print $an->Web->template({file => "server.html", template => "delete-server-start"});
	
	# Remove the server from the Anvil!.
	my $proceed       = 1;
	my $ccs_exit_code = 255;
	my $shell_call    = $an->data->{path}{ccs}." -h localhost --activate --sync --password \"".$an->data->{sys}{anvil}{password}."\" --rmvm $server; ".$an->data->{path}{echo}." ccs:\$?";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",       value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /ccs:(\d+)/)
		{
			$ccs_exit_code = $1;
		}
		else
		{
			$line = $an->Web->parse_text_line({line => $line});
			print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ccs_exit_code", value1 => $ccs_exit_code,
	}, file => $THIS_FILE, line => __LINE__});
	if ($ccs_exit_code eq "0")
	{
		print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => "#!string!message_0197!#" }});
	}
	else
	{
		my $say_error = $an->String->get({key => "message_0198", variables => { ccs_exit_code => $ccs_exit_code }});
		print $an->Web->template({file => "server.html", template => "delete-server-bad-exit-code", replace => { error => $say_error }});
		$proceed = 0;
	}
	print $an->Web->template({file => "server.html", template => "delete-server-start-footer"});
	
	my $stop_exit_code = 255;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "server_host",   value1 => $server_host,
		name2 => "ccs_exit_code", value2 => $ccs_exit_code,
	}, file => $THIS_FILE, line => __LINE__});
	if ((($server_host) && ($server_host ne "none")) && ($ccs_exit_code eq "0"))
	{
		# Server is still running, kill it.
		print $an->Web->template({file => "server.html", template => "delete-server-force-off-header"});
		
		my $virsh_exit_code = 255;;
		my $shell_call      = $an->data->{path}{virsh}." destroy $server; ".$an->data->{path}{echo}." virsh:\$?";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",       value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			next if not $line;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /virsh:(\d+)/)
			{
				$virsh_exit_code = $1;
			}
			else
			{
				$line = $an->Web->parse_text_line({line => $line});
				print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
			}
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "virsh_exit_code", value1 => $virsh_exit_code,
		}, file => $THIS_FILE, line => __LINE__});
		if ($virsh_exit_code eq "0")
		{
			print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => "#!string!message_0199!#" }});
		}
		else
		{
			# This is fatal
			my $say_error = $an->String->get({key => "message_0200", variables => { virsh_exit_code => $virsh_exit_code }});
			print $an->Web->template({file => "server.html", template => "delete-server-bad-exit-code", replace => { error => $say_error }});
			$proceed = 0;
		}
		print $an->Web->template({file => "server.html", template => "delete-server-force-off-footer"});
	}
	
	# Now delete the backing LVs
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "proceed", value1 => $proceed, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($proceed)
	{
		# Free up the storage
		print $an->Web->template({file => "server.html", template => "delete-server-remove-lv-header"});
		
		foreach my $lv (keys %{$an->data->{server}{$server}{node}{$node_name}{lv}})
		{
			my $message = $an->String->get({key => "message_0201", variables => { lv => $lv }});
			print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $message }});
			my $lvremove_exit_code = 255;
			my $shell_call         = $an->data->{path}{lvremove}." -f $lv; ".$an->data->{path}{echo}." lvremove:\$?";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "target",       value1 => $target,
				name2 => "shell_call", value2 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$target,
				port		=>	$port, 
				password	=>	$password,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				next if not $line;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /lvremove:(\d+)/)
				{
					$lvremove_exit_code = $1;
				}
				else
				{
					print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
				}
			}
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "lvremove exit code", value1 => $lvremove_exit_code,
			}, file => $THIS_FILE, line => __LINE__});
			if ($lvremove_exit_code eq "0")
			{
				print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => "#!string!message_0202!#" }});
			}
			else
			{
				my $say_error = $an->String->get({key => "message_0204", variables => { lvremove_exit_code => $lvremove_exit_code }});
				print $an->Web->template({file => "server.html", template => "delete-server-bad-exit-code", replace => { error => $say_error }});
			}
		}
		
		# Read in the server data for our messaging below, before we actually blow away the file.
		my $server_data = $an->Get->server_data({
			server => $server, 
			anvil  => $anvil_name, 
		});
		
		### NOTE: Yes, the actual path is in '$an->data->{server}{$server}{definition_file}', but 
		###       we're doing an 'rm -f' so we're going to be paranoid.
		# Regardless of whether the LV removal(s) succeeded, delete the definition file.
		my $file         = $an->data->{server}{$server}{definition_file};
		my $ls_exit_code = 255;
		my $shell_call   = "
if [ '".$an->data->{path}{shared_definitions}."/${server}.xml' ];
then
    ".$an->data->{path}{rm}." -f ".$an->data->{path}{shared_definitions}."/${server}.xml;
    ".$an->data->{path}{ls}." ".$an->data->{path}{shared_definitions}."/${server}.xml;
    ".$an->data->{path}{echo}." ls:\$?
fi;
";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			next if not $line;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /ls:(\d+)/)
			{
				$ls_exit_code = $1;
			}
			else
			{
				### There will be output, I don't care about it.
				#$line = $an->Web->parse_text_line({line => $line});
				#print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
			}
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "ls exit code", value1 => $ls_exit_code,
		}, file => $THIS_FILE, line => __LINE__});
		if ($ls_exit_code eq "2")
		{
			# File deleted successfully.
			my $message = $an->String->get({key => "message_0209", variables => { file => $file }});
			print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $message }});
		}
		else
		{
			# Delete seems to have failed
			my $message = $an->String->get({key => "message_0210", variables => { 
				file		=>	$file,
				ls_exit_code	=>	$ls_exit_code,
			}});
			print $an->Web->template({file => "server.html", template => "remove-vm-definition-failed", replace => { message => $message }});
		}
		
		# Mark it as deleted.
		my $server_uuid = $server_data->{uuid};
		my $query       = "
UPDATE 
    servers 
SET 
    server_note   = 'DELETED', 
    modified_date = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
WHERE 
    server_uuid = ".$an->data->{sys}{use_db_fh}->quote($server_uuid)."
;";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
		
		my $message = $an->String->get({key => "message_0205", variables => { server => $server }});
		print $an->Web->template({file => "server.html", template => "delete-server-success", replace => { message => $message }});
	}
	print $an->Web->template({file => "server.html", template => "delete-server-footer"});
	
	return(0);
}

# This shows a banner asking for patience in anvil-safe-start is running on either node.
sub _display_anvil_safe_start_notice
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_display_anvil_safe_start_notice" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_safe_start_notice = "";
	my $display_notice          = 0;
	foreach my $node ($an->data->{sys}{anvil}{node1}{name}, $an->data->{sys}{anvil}{node2}{name})
	{
		$display_notice = 1 if $an->data->{node}{$node}{'anvil-safe-start'};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node}::anvil-safe-start", value1 => $an->data->{node}{$node}{'anvil-safe-start'},
			name2 => "display_notice",                  value2 => $display_notice,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "display_notice", value1 => $display_notice,
	}, file => $THIS_FILE, line => __LINE__});
	if ($display_notice)
	{
		$anvil_safe_start_notice = $an->Web->template({file => "server.html", template => "anvil_safe_start_notice"});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil_safe_start_notice", value1 => $anvil_safe_start_notice,
	}, file => $THIS_FILE, line => __LINE__});
	return($anvil_safe_start_notice)
}

# This creates the summary page after a Anvil! has been selected.
sub _display_details
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_display_details" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	#print $an->Web->template({file => "server.html", template => "display-details-header"});
	# Display the status of each node's daemons
	my $up_nodes = @{$an->data->{up_nodes}};
	
	# TODO: Rework this, I always show nodes now so that the 'fence_...' calls are available. IE: enable 
	#       this when the cache exists and the fence command addresses are reachable.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "sys::show_nodes", value1 => $an->data->{sys}{show_nodes},
		name2 => "sys::up_nodes",   value2 => $an->data->{sys}{up_nodes},
		name3 => "up_nodes",        value3 => $up_nodes,
	}, file => $THIS_FILE, line => __LINE__});
	
#	if ($an->data->{sys}{show_nodes})
	if (1)
	{
		my $node_control_panel = $an->Striker->_display_node_controls();
		#print $node_control_panel;
		
		my $anvil_safe_start_notice        = "";
		my $server_state_and_control_panel = "";
		my $node_details_panel             = "";
		my $server_details_panel           = "";
		my $gfs2_details_panel             = "";
		my $drbd_details_panel             = "";
		my $free_resources_panel           = "";
		my $no_access_panel                = "";
		my $watchdog_panel                 = "";

		# I don't show below here unless at least one node is up.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "sys::up_nodes", value1 => $an->data->{sys}{up_nodes},
			name2 => "up_nodes",      value2 => $up_nodes,
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{sys}{up_nodes} > 0)
		{
			# Displays a notice if anvil-safe-start is running on either node.
			$anvil_safe_start_notice = $an->Striker->_display_anvil_safe_start_notice();
			
			# Show the user the current server states and the control buttons.
			$server_state_and_control_panel = $an->Striker->_display_server_state_and_controls();
			
			# Show the state of the daemons.
			$node_details_panel = $an->Striker->_display_node_details();
			
			# Show the details about each server.
			$server_details_panel = $an->Striker->_display_server_details();
			
			# Show the status of each node's GFS2 share(s)
			$gfs2_details_panel = $an->Striker->_display_gfs2_details();
			
			# This shows the status of each DRBD resource in the Anvil!.
			$drbd_details_panel = $an->Striker->_display_drbd_details();
			
			# Show the free resources available for new servers.
			$free_resources_panel = $an->Striker->_display_free_resources();
			
			# This generates a panel below 'Available Resources' 
			# *if* the user has enabled 'tools::anvil-kick-apc-ups::enabled'
			$watchdog_panel = $an->Striker->_display_watchdog_panel({note => ""});
		}
		else
		{
			# Generic "I can't reach the nodes, wtf?" message
			my $message = $an->String->get({key => "message_0269"});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "message",                  value1 => $message,
				name2 => "sys::anvil::node1::power", value2 => $an->data->{sys}{anvil}{node1}{power},
				name3 => "sys::anvil::node2::power", value3 => $an->data->{sys}{anvil}{node2}{power},
			}, file => $THIS_FILE, line => __LINE__});
			if (($an->data->{sys}{anvil}{node1}{power} eq "off") && ($an->data->{sys}{anvil}{node2}{power} eq "off"))
			{
				$message = $an->String->get({key => "message_0268"});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "message", value1 => $message,
				}, file => $THIS_FILE, line => __LINE__});
			}
			$no_access_panel = $an->Web->template({file => "server.html", template => "display-details-nodes-unreachable", replace => { message => $message }});
			
			# This generates a panel below 'Available Resources' *if* the user has enabled 
			# 'tools::anvil-kick-apc-ups::enabled'
			$watchdog_panel = $an->Striker->_display_watchdog_panel({note => "no_abort"});
		}
		
		print $an->Web->template({file => "server.html", template => "main-page", replace => { 
			anvil_safe_start_notice		=>	$anvil_safe_start_notice, 
			node_control_panel		=>	$node_control_panel,
			server_state_and_control_panel	=>	$server_state_and_control_panel,
			node_details_panel		=>	$node_details_panel,
			server_details_panel		=>	$server_details_panel,
			gfs2_details_panel		=>	$gfs2_details_panel,
			drbd_details_panel		=>	$drbd_details_panel,
			free_resources_panel		=>	$free_resources_panel,
			no_access_panel			=>	$no_access_panel,
			watchdog_panel			=>	$watchdog_panel,
		}});
	}
	
	return (0);
}

# This shows the status of each DRBD resource in the Anvil!.
sub _display_drbd_details
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_display_drbd_details" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make it a little easier to print the name of each node
	my $node1     = $an->data->{sys}{anvil}{node1}{name};
	my $node2     = $an->data->{sys}{anvil}{node2}{name};
	my $say_node1 = "<span class=\"fixed_width\">".$an->data->{sys}{anvil}{node1}{short_name}."</span>";
	my $say_node2 = "<span class=\"fixed_width\">".$an->data->{sys}{anvil}{node2}{short_name}."</span>";
	my $drbd_details_panel = $an->Web->template({file => "server.html", template => "display-replicated-storage-header", replace => { 
			say_node1	=>	$say_node1,
			say_node2	=>	$say_node2,
		}});

	foreach my $res (sort {$a cmp $b} keys %{$an->data->{drbd}})
	{
		next if not $res;
		# If the DRBD daemon is stopped, I will use the values from the resource files.
		my $say_n1_dev  = "--";
		my $say_n2_dev  = "--";
		my $say_n1_cs   = "--";
		my $say_n2_cs   = "--";
		my $say_n1_ro   = "--";
		my $say_n2_ro   = "--";
		my $say_n1_ds   = "--";
		my $say_n2_ds   = "--";
		
		# Check if node 1 is online.
		if ($an->data->{node}{$node1}{up})
		{
			# It is, but is DRBD running?
			if ($an->data->{node}{$node1}{daemon}{drbd}{exit_code} eq "0")
			{
				# It is. 
				$say_n1_dev = $an->data->{drbd}{$res}{node}{$node1}{device}           if $an->data->{drbd}{$res}{node}{$node1}{device};
				$say_n1_cs  = $an->data->{drbd}{$res}{node}{$node1}{connection_state} if $an->data->{drbd}{$res}{node}{$node1}{connection_state};
				$say_n1_ro  = $an->data->{drbd}{$res}{node}{$node1}{role}             if $an->data->{drbd}{$res}{node}{$node1}{role};
				$say_n1_ds  = $an->data->{drbd}{$res}{node}{$node1}{disk_state}       if $an->data->{drbd}{$res}{node}{$node1}{disk_state};
				if (($an->data->{drbd}{$res}{node}{$node1}{disk_state} eq "Inconsistent") && ($an->data->{drbd}{$res}{node}{$node1}{resync_percent} =~ /^\d/))
				{
					$say_n1_ds .= " <span class=\"subtle_text\" style=\"font-style: normal;\">(".$an->data->{drbd}{$res}{node}{$node1}{resync_percent}."%)</span>";
				}
			}
			else
			{
				# It is not, use the {res_file} values.
				$say_n1_dev = $an->data->{drbd}{$res}{node}{$node1}{res_file}{device}           if $an->data->{drbd}{$res}{node}{$node1}{res_file}{device};
				$say_n1_cs  = $an->data->{drbd}{$res}{node}{$node1}{res_file}{connection_state} if $an->data->{drbd}{$res}{node}{$node1}{res_file}{connection_state};
				$say_n1_ro  = $an->data->{drbd}{$res}{node}{$node1}{res_file}{role}             if $an->data->{drbd}{$res}{node}{$node1}{res_file}{role};
				$say_n1_ds  = $an->data->{drbd}{$res}{node}{$node1}{res_file}{disk_state}       if $an->data->{drbd}{$res}{node}{$node1}{res_file}{disk_state};
			}
		}
		# Check if node 2 is online.
		if ($an->data->{node}{$node2}{up})
		{
			# It is, but is DRBD running?
			if ($an->data->{node}{$node2}{daemon}{drbd}{exit_code} eq "0")
			{
				# It is. 
				$say_n2_dev = $an->data->{drbd}{$res}{node}{$node2}{device}           if $an->data->{drbd}{$res}{node}{$node2}{device};
				$say_n2_cs  = $an->data->{drbd}{$res}{node}{$node2}{connection_state} if $an->data->{drbd}{$res}{node}{$node2}{connection_state};
				$say_n2_ro  = $an->data->{drbd}{$res}{node}{$node2}{role}             if $an->data->{drbd}{$res}{node}{$node2}{role};
				$say_n2_ds  = $an->data->{drbd}{$res}{node}{$node2}{disk_state}       if $an->data->{drbd}{$res}{node}{$node2}{disk_state};
				if (($an->data->{drbd}{$res}{node}{$node2}{disk_state} eq "Inconsistent") && ($an->data->{drbd}{$res}{node}{$node2}{resync_percent} =~ /^\d/))
				{
					$say_n2_ds .= " <span class=\"subtle_text\" style=\"font-style: normal;\">(".$an->data->{drbd}{$res}{node}{$node2}{resync_percent}."%)</span>";
				}
			}
			else
			{
				# It is not, use the {res_file} values.
				$say_n2_dev = $an->data->{drbd}{$res}{node}{$node2}{res_file}{device}           if $an->data->{drbd}{$res}{node}{$node2}{res_file}{device};
				$say_n2_cs  = $an->data->{drbd}{$res}{node}{$node2}{res_file}{connection_state} if $an->data->{drbd}{$res}{node}{$node2}{res_file}{connection_state};
				$say_n2_ro  = $an->data->{drbd}{$res}{node}{$node2}{res_file}{role}             if $an->data->{drbd}{$res}{node}{$node2}{res_file}{role};
				$say_n2_ds  = $an->data->{drbd}{$res}{node}{$node2}{res_file}{disk_state}       if $an->data->{drbd}{$res}{node}{$node2}{res_file}{disk_state};
			}
		}
		
		my $class_n1_cs        =  "highlight_unavailable";
		   $class_n1_cs        =  "highlight_good"    if $say_n1_cs eq "Connected";
		   $class_n1_cs        =  "highlight_good"    if $say_n1_cs eq "SyncSource";
		   $class_n1_cs        =  "highlight_ready"   if $say_n1_cs eq "WFConnection";
		   $class_n1_cs        =  "highlight_ready"   if $say_n1_cs eq "PausedSyncS";
		   $class_n1_cs        =  "highlight_warning" if $say_n1_cs eq "PausedSyncT";
		   $class_n1_cs        =  "highlight_warning" if $say_n1_cs eq "SyncTarget";
		my $class_n2_cs        =  "highlight_unavailable";
		   $class_n2_cs        =  "highlight_good"    if $say_n2_cs eq "Connected";
		   $class_n2_cs        =  "highlight_good"    if $say_n2_cs eq "SyncSource";
		   $class_n2_cs        =  "highlight_ready"   if $say_n2_cs eq "WFConnection";
		   $class_n2_cs        =  "highlight_ready"   if $say_n2_cs eq "PausedSyncS";
		   $class_n2_cs        =  "highlight_warning" if $say_n2_cs eq "PausedSyncT";
		   $class_n2_cs        =  "highlight_warning" if $say_n2_cs eq "SyncTarget";
		my $class_n1_ro        =  "highlight_unavailable";
		   $class_n1_ro        =  "highlight_good"    if $say_n1_ro eq "Primary";
		   $class_n1_ro        =  "highlight_warning" if $say_n1_ro eq "Secondary";
		my $class_n2_ro        =  "highlight_unavailable";
		   $class_n2_ro        =  "highlight_good"    if $say_n2_ro eq "Primary";
		   $class_n2_ro        =  "highlight_warning" if $say_n2_ro eq "Secondary";
		my $class_n1_ds        =  "highlight_unavailable";
		   $class_n1_ds        =  "highlight_good"    if $say_n1_ds eq "UpToDate";
		   $class_n1_ds        =  "highlight_warning" if $say_n1_ds =~ /Inconsistent/;
		   $class_n1_ds        =  "highlight_warning" if $say_n1_ds eq "Outdated";
		   $class_n1_ds        =  "highlight_bad"     if $say_n1_ds eq "Diskless";
		my $class_n2_ds        =  "highlight_unavailable";
		   $class_n2_ds        =  "highlight_good"    if $say_n2_ds eq "UpToDate";
		   $class_n2_ds        =  "highlight_warning" if $say_n2_ds =~ /Inconsistent/;
		   $class_n2_ds        =  "highlight_warning" if $say_n2_ds eq "Outdated";
		   $class_n2_ds        =  "highlight_bad"     if $say_n2_ds eq "Diskless";
		   $drbd_details_panel .= $an->Web->template({file => "server.html", template => "display-replicated-storage-entry", replace => { 
				res		=>	$res,
				say_n1_dev	=>	$say_n1_dev,
				say_n2_dev	=>	$say_n2_dev,
				class_n1_cs	=>	$class_n1_cs,
				say_n1_cs	=>	$say_n1_cs,
				class_n2_cs	=>	$class_n2_cs,
				say_n2_cs	=>	$say_n2_cs,
				class_n1_ro	=>	$class_n1_ro,
				say_n1_ro	=>	$say_n1_ro,
				class_n2_ro	=>	$class_n2_ro,
				say_n2_ro	=>	$say_n2_ro,
				class_n1_ds	=>	$class_n1_ds,
				say_n1_ds	=>	$say_n1_ds,
				class_n2_ds	=>	$class_n2_ds,
				say_n2_ds	=>	$say_n2_ds,
			}});
	}
	$drbd_details_panel .= $an->Web->template({file => "server.html", template => "display-replicated-storage-footer"});
	
	return ($drbd_details_panel);
}

# This shows the free resources available to be assigned to new servers.
sub _display_free_resources
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_display_free_resources" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Start the template
	my $free_resources_panel .= $an->Web->template({file => "server.html", template => "display-details-free-resources-header"});
	
	# Load some data
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node1_name = $an->data->{sys}{anvil}{node1}{name};
	my $node2_name = $an->data->{sys}{anvil}{node2}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "node1_name", value3 => $node1_name,
		name4 => "node2_name", value4 => $node2_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# I only show one row for CPU and RAM, but usually have two or more VGs. So the first step is to put 
	# my VG info into an array.
	my $enough_storage = 0;
	my $available_ram  = 0;
	my $max_cpu_cores  = 0;
	my @vg;
	my @vg_size;
	my @vg_used;
	my @vg_free;
	my @pv_name;
	my $vg_link="";
	foreach my $vg (sort {$a cmp $b} keys %{$an->data->{resources}{vg}})
	{
		# If it is not a clustered volume group, I don't care about it.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "resources::vg::${vg}::clustered", value1 => $an->data->{resources}{vg}{$vg}{clustered},
		}, file => $THIS_FILE, line => __LINE__});
		next if not $an->data->{resources}{vg}{$vg}{clustered};
		push @vg,      $vg;
		push @vg_size, $an->data->{resources}{vg}{$vg}{size};
		push @vg_used, $an->data->{resources}{vg}{$vg}{used_space};
		push @vg_free, $an->data->{resources}{vg}{$vg}{free_space};
		push @pv_name, $an->data->{resources}{vg}{$vg}{pv_name};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "resources::vg::${vg}::size",       value1 => $an->data->{resources}{vg}{$vg}{size},
			name2 => "resources::vg::${vg}::used_space", value2 => $an->data->{resources}{vg}{$vg}{used_space},
			name3 => "resources::vg::${vg}::free_space", value3 => $an->data->{resources}{vg}{$vg}{free_space},
			name4 => "resources::vg::${vg}::pv_name",    value4 => $an->data->{resources}{vg}{$vg}{pv_name},
		}, file => $THIS_FILE, line => __LINE__});
		
		# If there is at least a GiB free, mark free storage as sufficient.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::clvmd_down", value1 => $an->data->{sys}{clvmd_down},
		}, file => $THIS_FILE, line => __LINE__});
		if (not $an->data->{sys}{clvmd_down})
		{
			$enough_storage =  1 if $an->data->{resources}{vg}{$vg}{free_space} > (2**30);
			$vg_link        .= "$vg:".$an->data->{resources}{vg}{$vg}{free_space}.",";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "enough_storage", value1 => $enough_storage,
				name2 => "vg_link",        value2 => $vg_link,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	$vg_link =~ s/,$//;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "vg_link", value1 => $vg_link,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Count how much RAM and CPU cores have been allocated.
	my $allocated_cores = 0;
	my $allocated_ram   = 0;
	foreach my $server (sort {$a cmp $b} keys %{$an->data->{server}})
	{
		# I check GFS2 because, without it, I can't read the VM's details.
		if ($an->data->{sys}{gfs2_down})
		{
			$allocated_ram   = "#!string!symbol_0011!#";
			$allocated_cores = "#!string!symbol_0011!#";
		}
		else
		{
			$allocated_ram   += $an->data->{server}{$server}{details}{ram};
			$allocated_cores += $an->data->{server}{$server}{details}{cpu_count};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "allocated_ram",                   value1 => $allocated_ram,
				name2 => "allocated_cores",                 value2 => $allocated_cores,
				name3 => "server::${server}::details::ram", value3 => $an->data->{server}{$server}{details}{ram},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Always knock off some RAM for the host OS.
	my $real_total_ram = $an->Readable->bytes_to_hr({'bytes' => $an->data->{resources}{total_ram} });
	
	# Reserved RAM and BIOS memory holes rarely leave us with an even GiB of total RAM. So we modulous 
	# off the difference, then subtract that plus the reserved RAM to get an even left-over amount of 
	# memory for the user to allocate to their servers.
	my $diff                             = $an->data->{resources}{total_ram} % (1024 ** 3);
	   $an->data->{resources}{total_ram} = $an->data->{resources}{total_ram} - $diff - $an->data->{sys}{unusable_ram};
	   $an->data->{resources}{total_ram} =  0 if $an->data->{resources}{total_ram} < 0;
	my $free_ram                         =  $an->data->{sys}{gfs2_down}  ? 0    : $an->data->{resources}{total_ram} - $allocated_ram;
	my $say_free_ram                     =  $an->data->{sys}{gfs2_down}  ? "--" : $an->Readable->bytes_to_hr({'bytes' => $free_ram });
	my $say_total_ram                    =  $an->Readable->bytes_to_hr({'bytes' => $an->data->{resources}{total_ram} });
	my $say_allocated_ram                =  $an->data->{sys}{gfs2_down}  ? "--" : $an->Readable->bytes_to_hr({'bytes' => $allocated_ram });
	my $say_vg_size                      =  $an->data->{sys}{clvmd_down} ? "--" : $an->Readable->bytes_to_hr({'bytes' => $vg_size[0] });
	my $say_vg_used                      =  $an->data->{sys}{clvmd_down} ? "--" : $an->Readable->bytes_to_hr({'bytes' => $vg_used[0] });
	my $say_vg_free                      =  $an->data->{sys}{clvmd_down} ? "--" : $an->Readable->bytes_to_hr({'bytes' => $vg_free[0] });
	my $say_vg                           =  $an->data->{sys}{clvmd_down} ? "--" : $vg[0];
	my $say_pv_name                      =  $an->data->{sys}{clvmd_down} ? "--" : $pv_name[0];
	
	# Show the main info.
	$free_resources_panel .= $an->Web->template({file => "server.html", template => "display-details-free-resources-entry", replace => { 
		total_cores		=>	$an->data->{resources}{total_cores},
		total_threads		=>	$an->data->{resources}{total_threads},
		allocated_cores		=>	$allocated_cores,
		real_total_ram		=>	$real_total_ram,
		say_total_ram		=>	$say_total_ram,
		say_allocated_ram	=>	$say_allocated_ram,
		say_free_ram		=>	$say_free_ram,
		say_vg			=>	$say_vg,
		say_pv_name		=>	$say_pv_name,
		say_vg_size		=>	$say_vg_size,
		say_vg_used		=>	$say_vg_used,
		say_vg_free		=>	$say_vg_free,
	}});

	if (@vg > 0)
	{
		for (my $i=1; $i < @vg; $i++)
		{
			my $say_vg_size          =  $an->Readable->bytes_to_hr({'bytes' => $vg_size[$i] });
			my $say_vg_used          =  $an->Readable->bytes_to_hr({'bytes' => $vg_used[$i] });
			my $say_vg_free          =  $an->Readable->bytes_to_hr({'bytes' => $vg_free[$i] });
			my $say_pv_name          =  $pv_name[$i];
			   $free_resources_panel .= $an->Web->template({file => "server.html", template => "display-details-free-resources-entry-extra-storage", replace => { 
				vg		=>	$vg[$i],
				pv_name		=>	$pv_name[$i],
				say_vg_size	=>	$say_vg_size,
				say_vg_used	=>	$say_vg_used,
				say_vg_free	=>	$say_vg_free,
			}});
		}
	}
	
	# If I found enough free disk space, have at least 1 GiB of free RAM  and both nodes are up, enable 
	# the "provision new server" button.
	my $say_bns    = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0022!#" }});
	my $say_mc     = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0023!#" }});
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "enough_storage",                               value1 => $enough_storage,
		name2 => "free_ram",                                     value2 => $free_ram,
		name3 => "node::${node1_name}::daemon::cman::exit_code", value3 => $an->data->{node}{$node1_name}{daemon}{cman}{exit_code},
		name4 => "node::${node2_name}::daemon::cman::exit_code", value4 => $an->data->{node}{$node2_name}{daemon}{cman}{exit_code},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node1_name}{daemon}{cman}{exit_code} eq "0") && 
	    ($an->data->{node}{$node2_name}{daemon}{cman}{exit_code} eq "0"))
	{
		# The Anvil! is running, so enable the media library link.
		$say_mc = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	"/cgi-bin/mediaLibrary?anvil_uuid=".$an->data->{cgi}{anvil_uuid},
				button_text	=>	"#!string!button_0023!#",
				id		=>	"media_library_".$an->data->{cgi}{anvil_uuid},
			}});
		
		# Enable the "New Server" button if there is enough free memory and storage space.
		if (($enough_storage) && ($free_ram > $an->data->{sys}{server}{minimum_ram}))
		{
			$say_bns = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"?anvil_uuid=$anvil_uuid&task=provision&max_ram=$free_ram&max_cores=".$an->data->{resources}{total_cores}."&max_storage=$vg_link",
					button_text	=>	"#!string!button_0022!#",
					id		=>	"provision",
				}});
		}
	}
	$free_resources_panel .= $an->Web->template({file => "server.html", template => "display-details-bottom-button-bar", replace => { 
			say_bns	=>	$say_bns,
			say_mc	=>	$say_mc,
		}});
	$free_resources_panel .= $an->Web->template({file => "server.html", template => "display-details-footer"});

	return ($free_resources_panel);
}

# This shows the details on each node's GFS2 mount(s)
sub _display_gfs2_details
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_display_gfs2_details" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make it a little easier to print the name of each node
	my $node1              = $an->data->{sys}{anvil}{node1}{name};
	my $node2              = $an->data->{sys}{anvil}{node2}{name};
	my $say_node1          = "<span class=\"fixed_width\">".$an->data->{sys}{anvil}{node1}{short_name}."</span>";
	my $say_node2          = "<span class=\"fixed_width\">".$an->data->{sys}{anvil}{node2}{short_name}."</span>";
	my $gfs2_details_panel = $an->Web->template({file => "server.html", template => "display-cluster-storage-header", replace => { 
			say_node1	=>	$say_node1,
			say_node2	=>	$say_node2,
		}});

	my $gfs2_hash = "";
	my $node      = "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "node::${node1}::daemon::cman::exit_code", value1 => $an->data->{node}{$node1}{daemon}{cman}{exit_code},
		name2 => "node::${node1}::daemon::gfs2::exit_code", value2 => $an->data->{node}{$node1}{daemon}{gfs2}{exit_code},
		name3 => "node::${node2}::daemon::cman::exit_code", value3 => $an->data->{node}{$node2}{daemon}{cman}{exit_code},
		name4 => "node::${node2}::daemon::gfs2::exit_code", value4 => $an->data->{node}{$node2}{daemon}{gfs2}{exit_code},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node1}{daemon}{cman}{exit_code} eq "0") && ($an->data->{node}{$node1}{daemon}{gfs2}{exit_code} eq "0") && (ref($an->data->{node}{$node1}{gfs}) eq "HASH"))
	{
		$gfs2_hash = $an->data->{node}{$node1}{gfs};
		$node      = $node1;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "gfs2_hash", value1 => $gfs2_hash,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif (($an->data->{node}{$node2}{daemon}{cman}{exit_code} eq "0") && ($an->data->{node}{$node2}{daemon}{gfs2}{exit_code} eq "0") && (ref($an->data->{node}{$node2}{gfs}) eq "HASH"))
	{
		$gfs2_hash = $an->data->{node}{$node2}{gfs};
		$node      = $node2;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "gfs2_hash", value1 => $gfs2_hash,
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Neither node has the GFS2 partition mounted. Use the data from /etc/fstab. This is what
		# will be stored in either node's hash. So pick a node that's online and use it.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::up_nodes", value1 => $an->data->{sys}{up_nodes},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{sys}{up_nodes} == 1)
		{
			# Neither node has the GFS2 partition mounted.
			$an->Log->entry({log_level => 2, message_key => "log_0259", file => $THIS_FILE, line => __LINE__});
			$node      = @{$an->data->{up_nodes}}[0];
			$gfs2_hash = $an->data->{node}{$node}{gfs};
		}
		else
		{
			# Neither node is online at all.
			$gfs2_details_panel .= $an->Web->template({file => "server.html", template => "display-cluster-storage-not-online"});
		}
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "gfs2_hash",                value1 => $gfs2_hash,
		name2 => "ref(node::${node1}::gfs)", value2 => ref($an->data->{node}{$node1}{gfs}),
		name3 => "ref(node::${node2}::gfs)", value3 => ref($an->data->{node}{$node2}{gfs}),
	}, file => $THIS_FILE, line => __LINE__});
	if (ref($gfs2_hash) eq "HASH")
	{
		foreach my $mount_point (sort {$a cmp $b} keys %{$gfs2_hash})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "node::${node1}::gfs::${mount_point}::mounted", value1 => $an->data->{node}{$node1}{gfs}{$mount_point}{mounted},
				name2 => "node::${node2}::gfs::${mount_point}::mounted", value2 => $an->data->{node}{$node2}{gfs}{$mount_point}{mounted},
			}, file => $THIS_FILE, line => __LINE__});
			my $say_node1_mounted = $an->data->{node}{$node1}{gfs}{$mount_point}{mounted} ? "<span class=\"highlight_good\">#!string!state_0010!#</span>" : "<span class=\"highlight_bad\">#!string!state_0011!#</span>";
			my $say_node2_mounted = $an->data->{node}{$node2}{gfs}{$mount_point}{mounted} ? "<span class=\"highlight_good\">#!string!state_0010!#</span>" : "<span class=\"highlight_bad\">#!string!state_0011!#</span>";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "say_node1_mounted", value1 => $say_node1_mounted,
				name2 => "say_node2_mounted", value2 => $say_node2_mounted,
			}, file => $THIS_FILE, line => __LINE__});
			my $say_size         = "--";
			my $say_used         = "--";
			my $say_used_percent = "--%";
			my $say_free         = "--";
			
			# This is to avoid the "undefined variable" errors in the log from when a node isn't
			# online.
			$an->data->{node}{$node1}{gfs}{$mount_point}{total_size} = "" if not defined $an->data->{node}{$node1}{gfs}{$mount_point}{total_size};
			$an->data->{node}{$node2}{gfs}{$mount_point}{total_size} = "" if not defined $an->data->{node}{$node2}{gfs}{$mount_point}{total_size};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "node1 total size", value1 => $an->data->{node}{$node1}{gfs}{$mount_point}{total_size},
				name2 => "node2 total size", value2 => $an->data->{node}{$node2}{gfs}{$mount_point}{total_size},
			}, file => $THIS_FILE, line => __LINE__});
			if ($an->data->{node}{$node1}{gfs}{$mount_point}{total_size} =~ /^\d/)
			{
				$say_size         = $an->data->{node}{$node1}{gfs}{$mount_point}{total_size};
				$say_used         = $an->data->{node}{$node1}{gfs}{$mount_point}{used_space};
				$say_used_percent = $an->data->{node}{$node1}{gfs}{$mount_point}{percent_used};
				$say_free         = $an->data->{node}{$node1}{gfs}{$mount_point}{free_space};
			}
			elsif ($an->data->{node}{$node2}{gfs}{$mount_point}{total_size} =~ /^\d/)
			{
				$say_size         = $an->data->{node}{$node2}{gfs}{$mount_point}{total_size};
				$say_used         = $an->data->{node}{$node2}{gfs}{$mount_point}{used_space};
				$say_used_percent = $an->data->{node}{$node2}{gfs}{$mount_point}{percent_used};
				$say_free         = $an->data->{node}{$node2}{gfs}{$mount_point}{free_space};
			}
			$gfs2_details_panel .= $an->Web->template({file => "server.html", template => "display-cluster-storage-entry", replace => { 
					mount_point		=>	$mount_point,
					say_node1_mounted	=>	$say_node1_mounted,
					say_node2_mounted	=>	$say_node2_mounted,
					say_size		=>	$say_size,
					say_used		=>	$say_used,
					say_used_percent	=>	$say_used_percent,
					say_free		=>	$say_free,
				}});
		}
	}
	else
	{
		# No gfs2 FSes found
		$gfs2_details_panel .= $an->Web->template({file => "server.html", template => "display-cluster-storage-no-entries-found"});
	}
	$gfs2_details_panel .= $an->Web->template({file => "server.html", template => "display-cluster-storage-footer"});

	return ($gfs2_details_panel);
}

# This shows the controls for the nodes.
sub _display_node_controls
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_display_node_controls" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});

	# Variables for the full template.
	my $i                = 0;
	my $say_boot_or_stop = "";
	my $say_hard_reset   = "";
	my $say_dual_join    = "";
	my @say_node_name;
	my @say_boot;
	my @say_shutdown;
	my @say_join;
	my @say_withdraw;
	my @say_fence;
	
	# I want to map storage service to nodes for the "Withdraw" buttons.
	my $expire_time  = time + $an->data->{sys}{actime_timeout};
	my $disable_join = 0;
	my $anvil_uuid   = $an->data->{sys}{anvil}{uuid};
	my $anvil_name   = $an->data->{sys}{anvil}{name};
	my $node1_name   = $an->data->{sys}{anvil}{node1}{name};
	my $node2_name   = $an->data->{sys}{anvil}{node2}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "node1_name", value3 => $node1_name,
		name4 => "node2_name", value4 => $node2_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $rowspan    = 2;
	my $dual_boot  = (($an->data->{node}{$node1_name}{enable_poweron}) && ($an->data->{node}{$node2_name}{enable_poweron})) ? 1 : 0;
	my $dual_join  = (($an->data->{node}{$node1_name}{enable_join})    && ($an->data->{node}{$node2_name}{enable_join}))    ? 1 : 0;
	my $cold_stop  = ($an->data->{sys}{up_nodes} > 0)                                                                       ? 1 : 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "sys::up_nodes", value1 => $an->data->{sys}{up_nodes},
		name2 => "dual_boot",     value2 => $dual_boot,
		name3 => "dual_join",     value3 => $dual_join,
		name4 => "cold_stop",     value4 => $cold_stop,
	}, file => $THIS_FILE, line => __LINE__});
	
	foreach my $node_name ($an->data->{sys}{anvil}{node1}{name}, $an->data->{sys}{anvil}{node2}{name})
	{
		my $node_key                                      = $an->data->{sys}{node_name}{$node_name}{node_key};
		   $an->data->{node}{$node_name}{enable_withdraw} = 0 if not defined $an->data->{node}{$node_name}{enable_withdraw};
		
		# Join button.
		my $say_join_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0031!#" }});
		
		### TODO: See if the peer is online already and, if so, add 'confirm=true' as the join is safe.
		my $say_join_enabled_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
				button_class	=>	"bold_button",
				button_link	=>	"?anvil_uuid=$anvil_uuid&task=join_anvil&node_name=$node_name",
				button_text	=>	"#!string!button_0031!#",
				id		=>	"join_anvil_$node_name",
			}});
		$say_join[$i] = $an->data->{node}{$node_name}{enable_join} ? $say_join_enabled_button : $say_join_disabled_button;
		$say_join[$i] = $say_join_disabled_button if $disable_join;
		   
		# Withdraw button
		my $say_withdraw_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0032!#" }});
		my $say_withdraw_enabled_button  = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	"?anvil_uuid=$anvil_uuid&task=withdraw&node_name=$node_name",
				button_text	=>	"#!string!button_0032!#",
				id		=>	"withdraw_$node_name",
			}});
		$say_withdraw[$i] = $an->data->{node}{$node_name}{enable_withdraw} ? $say_withdraw_enabled_button : $say_withdraw_disabled_button;
		
		# Shutdown button
		my $say_shutdown_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0033!#" }});
		my $say_shutdown_enabled_button  = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	"?anvil_uuid=$anvil_uuid&expire=$expire_time&task=poweroff_node&node_name=$node_name",
				button_text	=>	"#!string!button_0033!#",
				id		=>	"poweroff_node_$node_name",
			}});
		$say_shutdown[$i] = $an->data->{node}{$node_name}{enable_poweroff} ? $say_shutdown_enabled_button : $say_shutdown_disabled_button;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "say_shutdown[$i]", value1 => $say_shutdown[$i],
		}, file => $THIS_FILE, line => __LINE__});
		
		# Boot button
		my $say_boot_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0034!#" }});
		my $say_boot_enabled_button  = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
				button_class	=>	"bold_button",
				button_link	=>	"?anvil_uuid=$anvil_uuid&task=poweron_node&node_name=$node_name&confirm=true",
				button_text	=>	"#!string!button_0034!#",
				id		=>	"poweron_node_$node_name",
			}});
		$say_boot[$i] = $an->data->{node}{$node_name}{enable_poweron} ? $say_boot_enabled_button : $say_boot_disabled_button;
		
		# Fence button
		# If the node is already confirmed off, no need to fence.
		my $say_fence_node_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0037!#" }});
		my $expire_time                    = time + $an->data->{sys}{actime_timeout};
		# &expire=$expire_time
		my $say_fence_node_enabled_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
				button_class	=>	"highlight_dangerous",
				button_link	=>	"?anvil_uuid=$anvil_uuid&expire=$expire_time&task=fence_node&node_name=$node_name",
				button_text	=>	"#!string!button_0037!#",
				id		=>	"fence_node_$node_name",
			}});
		$say_fence[$i] = $an->data->{node}{$node_name}{enable_poweron} ? $say_fence_node_disabled_button : $say_fence_node_enabled_button;
		
		# Dual-boot/Cold-Stop button.
		if ($i == 0)
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "i", value1 => $i,
			}, file => $THIS_FILE, line => __LINE__});
			my $say_boot_or_stop_disabled_button =  $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0035!#" }});
			   $say_boot_or_stop_disabled_button =~ s/\n$//;
			   $say_boot_or_stop                 =  $say_boot_or_stop_disabled_button;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "say_boot_or_stop", value1 => $say_boot_or_stop,
			}, file => $THIS_FILE, line => __LINE__});
			
			# If either node is up, offer the 'Cold-Stop Anvil!' button.
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "cold_stop", value1 => $cold_stop,
			}, file => $THIS_FILE, line => __LINE__});
			if ($cold_stop)
			{
				my $expire_time      = time + $an->data->{sys}{actime_timeout};
				   $say_boot_or_stop = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
						button_class	=>	"bold_button",
						button_link	=>	"?anvil_uuid=$anvil_uuid&expire=$expire_time&task=cold_stop",
						button_text	=>	"#!string!button_0062!#",
						id		=>	"dual_boot",
					}});
				$say_boot_or_stop =~ s/\n$//;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "say_boot_or_stop", value1 => $say_boot_or_stop,
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			# Dual-Join button
			my $say_dual_join_disabled_button =  $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0036!#" }});
			   $say_dual_join_disabled_button =~ s/\n$//;
			   $say_dual_join                 =  $say_dual_join_disabled_button;
			if ($rowspan)
			{
				# First row.
				if ($dual_boot)
				{
					$say_boot_or_stop = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
							button_class	=>	"bold_button",
							button_link	=>	"?anvil_uuid=$anvil_uuid&task=dual_boot&confirm=true",
							button_text	=>	"#!string!button_0035!#",
							id		=>	"dual_boot",
						}});
					$say_boot_or_stop =~ s/\n$//;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "say_boot_or_stop", value1 => $say_boot_or_stop,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($dual_join)
				{
					$say_dual_join = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
							button_class	=>	"bold_button",
							button_link	=>	"?anvil_uuid=$anvil_uuid&task=dual_join&confirm=true",
							button_text	=>	"#!string!button_0036!#",
							id		=>	"dual_join",
						}});
					# Disable the per-node "join" options".
					$say_join[$i] = $say_join_disabled_button;
					$disable_join = 1;
				}
			}
		}
		
		# Make the node names click-able to show the hardware states.
		$say_node_name[$i] = $node_name;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "i",             value1 => $i,
			name2 => "node_name",     value2 => $node_name,
			name3 => "say_node_name", value3 => $say_node_name[$i],
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{sys}{anvil}{$node_key}{online})
		{
			$say_node_name[$i] = $an->Web->template({file => "common.html", template => "enabled-button-new-tab", replace => { 
					button_class	=>	"fixed_width_button",
					button_link	=>	"?anvil_uuid=$anvil_uuid&task=display_health&node_name=$node_name",
					button_text	=>	$node_name,
					id		=>	"display_health_$node_name",
				}});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "i",             value1 => $i,
				name2 => "say_node_name", value2 => $say_node_name[$i],
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			$say_node_name[$i] = $an->Web->template({file => "common.html", template => "disabled-button-with-class", replace => { 
					button_class	=>	"highlight_offline_fixed_width_button",
					button_text	=>	$node_name,
				}});
		}
		$rowspan = 0;
		$i++;
	}
	
	my $boot_or_stop = "";
	my $hard_reset   = "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "say_boot_or_stop", value1 => $say_boot_or_stop,
		name2 => "say_hard_reset",   value2 => $say_hard_reset,
	}, file => $THIS_FILE, line => __LINE__});
	if ($say_hard_reset)
	{
		$boot_or_stop = $an->Web->template({file => "server.html", template => "boot-or-stop-two-buttons", replace => { button => $say_boot_or_stop }});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "boot_or_stop", value1 => $boot_or_stop,
		}, file => $THIS_FILE, line => __LINE__});
		$hard_reset = $an->Web->template({file => "server.html", template => "boot-or-stop-two-buttons", replace => { button => $say_hard_reset }});
	}
	else
	{
		$boot_or_stop = $an->Web->template({file => "server.html", template => "boot-or-stop-one-button", replace => { button => $say_boot_or_stop }});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "boot_or_stop", value1 => $boot_or_stop,
		}, file => $THIS_FILE, line => __LINE__});
	}
	my $node_control_panel = $an->Web->template({file => "server.html", template => "display-node-controls-full", replace => { 
			say_node1_name		=>	$say_node_name[0],
			say_node2_name		=>	$say_node_name[1],
			boot_or_stop_button_1	=>	$boot_or_stop,
			boot_or_stop_button_2	=>	$hard_reset,
			dual_join_button	=>	$say_dual_join,
			say_node1_boot		=>	$say_boot[0],
			say_node2_boot		=>	$say_boot[1],
			say_node1_shutdown	=>	$say_shutdown[0],
			say_node2_shutdown	=>	$say_shutdown[1],
			say_node1_join		=>	$say_join[0],
			say_node2_join		=>	$say_join[1],
			say_node1_withdraw	=>	$say_withdraw[0],
			say_node2_withdraw	=>	$say_withdraw[1],
			say_node1_fence		=>	$say_fence[0],
			say_node2_fence		=>	$say_fence[1],
		}});
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "node_control_panel", value1 => $node_control_panel,
	}, file => $THIS_FILE, line => __LINE__});
	return ($node_control_panel);
}

# This shows the user the state of the nodes and their daemons.
sub _display_node_details
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_display_node_details" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node1_name = $an->data->{sys}{anvil}{node1}{name};
	my $node2_name = $an->data->{sys}{anvil}{node2}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "node1_name", value3 => $node1_name,
		name4 => "node2_name", value4 => $node2_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $i = 0;
	my @host_name;
	my @cman;
	my @rgmanager;
	my @drbd;
	my @clvmd;
	my @gfs2;
	my @libvirtd;
	
	foreach my $node ($an->data->{sys}{anvil}{node1}{name}, $an->data->{sys}{anvil}{node2}{name})
	{
		$host_name[$i] = $i == 0 ? $an->data->{sys}{anvil}{node1}{short_name} : $an->data->{sys}{anvil}{node2}{short_name};
		$cman[$i]      = $an->data->{node}{$node}{daemon}{cman}{status};
		$rgmanager[$i] = $an->data->{node}{$node}{daemon}{rgmanager}{status};
		$drbd[$i]      = $an->data->{node}{$node}{daemon}{drbd}{status};
		$clvmd[$i]     = $an->data->{node}{$node}{daemon}{clvmd}{status};
		$gfs2[$i]      = $an->data->{node}{$node}{daemon}{gfs2}{status};
		$libvirtd[$i]  = $an->data->{node}{$node}{daemon}{libvirtd}{status};
		$i++;
	}
	
	my $node_details_panel = $an->Web->template({file => "server.html", template => "display-node-details-full", replace => { 
			node1_host_name	=>	$host_name[0],
			node2_host_name	=>	$host_name[1],
			node1_cman	=>	$cman[0],
			node2_cman	=>	$cman[1],
			node1_rgmanager	=>	$rgmanager[0],
			node2_rgmanager	=>	$rgmanager[1],
			node1_drbd	=>	$drbd[0],
			node2_drbd	=>	$drbd[1],
			node1_clvmd	=>	$clvmd[0],
			node2_clvmd	=>	$clvmd[1],
			node1_gfs2	=>	$gfs2[0],
			node2_gfs2	=>	$gfs2[1],
			node1_libvirtd	=>	$libvirtd[0],
			node2_libvirtd	=>	$libvirtd[1],
		}});

	return ($node_details_panel);
}

# This just shows the details of the server (no controls)
sub _display_server_details
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_display_server_details" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Start the template
	my $server_details_panel = $an->Web->template({file => "server.html", template => "display-server-details-header"});
	
	# Gather some details
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node1_name = $an->data->{sys}{anvil}{node1}{name};
	my $node1_uuid = $an->data->{sys}{anvil}{node1}{uuid};
	my $node2_name = $an->data->{sys}{anvil}{node2}{name};
	my $node2_uuid = $an->data->{sys}{anvil}{node2}{uuid};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "node1_name", value3 => $node1_name,
		name4 => "node1_uuid", value4 => $node1_uuid,
		name5 => "node2_name", value5 => $node2_name,
		name6 => "node2_uuid", value6 => $node2_uuid,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Pull up the server details.
	foreach my $server (sort {$a cmp $b} keys %{$an->data->{server}})
	{
		my $say_ram = $an->data->{sys}{gfs2_down} ? "#!string!symbol_0011!#" : $an->Readable->bytes_to_hr({'bytes' => $an->data->{server}{$server}{details}{ram} });
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "say_ram",                         value1 => $say_ram,
			name2 => "server::${server}::details::ram", value2 => $an->data->{server}{$server}{details}{ram},
		}, file => $THIS_FILE, line => __LINE__});
		
		# Get the LV arrays populated.
		my @lv_path;
		my @lv_size;
		my $host = $an->data->{server}{$server}{host};
		
		# If the host is "none", read the details from one of the "up" nodes.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "host", value1 => $host,
		}, file => $THIS_FILE, line => __LINE__});
		if ($host eq "none")
		{
			# If the first node is running, use it. Otherwise use the second node.
			my $node1_daemons_running = $an->Striker->_check_node_daemons({node => $node1_uuid});
			my $node2_daemons_running = $an->Striker->_check_node_daemons({node => $node2_uuid});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "node1_daemons_running", value1 => $node1_daemons_running,
				name2 => "node2_daemons_running", value2 => $node2_daemons_running,
			}, file => $THIS_FILE, line => __LINE__});
			if ($node1_daemons_running)
			{
				$host = $node1_name;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "host", value1 => $host,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($node2_daemons_running)
			{
				$host = $node2_name;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "host", value1 => $host,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		my @bridge;
		my @device;
		my @mac;
		my @type;
		my $node         = "--";
		my $say_net_host = ""; # Don't want anything printed when the server is down
		my $say_host     = "--";
		if ($host)
		{
			my $node = $host;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "server::${server}::node::${node}::lv", value1 => $an->data->{server}{$server}{node}{$node}{lv},
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $lv (sort {$a cmp $b} keys %{$an->data->{server}{$server}{node}{$node}{lv}})
			{
				push @lv_path, $lv;
				push @lv_size, $an->data->{server}{$server}{node}{$node}{lv}{$lv}{size};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "server::${server}::node::${node}::lv::${lv}::size", value1 => $an->data->{server}{$server}{node}{$node}{lv}{$lv}{size},
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			# Get the network arrays built.
			foreach my $current_bridge (sort {$a cmp $b} keys %{$an->data->{server}{$server}{details}{bridge}})
			{
				push @bridge, $current_bridge                                                         ? $current_bridge                                                         : "--";
				push @device, $an->data->{server}{$server}{details}{bridge}{$current_bridge}{device}  ? $an->data->{server}{$server}{details}{bridge}{$current_bridge}{device}  : "--";
				push @mac,    $an->data->{server}{$server}{details}{bridge}{$current_bridge}{mac}     ? uc($an->data->{server}{$server}{details}{bridge}{$current_bridge}{mac}) : "--";
				push @type,   $an->data->{server}{$server}{details}{bridge}{$current_bridge}{type}    ? $an->data->{server}{$server}{details}{bridge}{$current_bridge}{type}    : "--";
			}
			
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "server::${server}::host", value1 => $an->data->{server}{$server}{host},
			}, file => $THIS_FILE, line => __LINE__});
			if ($an->data->{server}{$server}{host} ne "none")
			{
				$say_host     =  $an->data->{server}{$server}{host};
				$say_host     =~ s/\..*//;
				$say_net_host =  $an->Web->template({file => "server.html", template => "display-server-details-network-entry", replace => { 
						host	=>	$say_host,
						bridge	=>	$bridge[0] ? $bridge[0] : "--",
						device	=>	$device[0] ? $device[0] : "--",
					}});
			}
		}
		
		# If there is no host, only the device type and MAC address are valid.
		$an->data->{server}{$server}{details}{cpu_count} = "#!string!symbol_0011!#" if $an->data->{sys}{gfs2_down};
		$lv_path[0]                                      = "#!string!symbol_0011!#" if $an->data->{sys}{gfs2_down};
		$lv_size[0]                                      = "#!string!symbol_0011!#" if $an->data->{sys}{gfs2_down};
		$type[0]                                         = "#!string!symbol_0011!#" if $an->data->{sys}{gfs2_down};
		$mac[0]                                          = "#!string!symbol_0011!#" if $an->data->{sys}{gfs2_down};
		$an->data->{server}{$server}{details}{cpu_count} = "--" if not defined $an->data->{server}{$server}{details}{cpu_count};
		$say_ram                                         = "--" if ((not $say_ram) or ($say_ram =~ /^0 /));
		$lv_path[0]                                      = "--" if not defined $lv_path[0];
		$lv_size[0]                                      = "--" if not defined $lv_size[0];
		$type[0]                                         = "--" if not defined $type[0];
		$mac[0]                                          = "--" if not defined $mac[0];
		$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
			name1 => "server::${server}::details::cpu_count", value1 => $an->data->{server}{$server}{details}{cpu_count},
			name2 => "say_ram",                               value2 => $say_ram,
			name3 => "lv_path[0]",                            value3 => $lv_path[0],
			name4 => "lv_size[0]",                            value4 => $lv_size[0],
			name5 => "say_net_host",                          value5 => $say_net_host,
			name6 => "type[0]",                               value6 => $type[0],
			name7 => "mac[0]",                                value7 => $mac[0],
		}, file => $THIS_FILE, line => __LINE__});
		$server_details_panel .= $an->Web->template({file => "server.html", template => "display-server-details-resources", replace => { 
				server		=>	$server,
				cpu_count	=>	$an->data->{server}{$server}{details}{cpu_count},
				say_ram		=>	$say_ram,
				lv_path		=>	$lv_path[0],
				lv_size		=>	$lv_size[0],
				say_net_host	=>	$say_net_host,
				type		=>	$type[0],
				mac		=>	$mac[0],
			}});

		my $lv_count   = @lv_path;
		my $nic_count  = @bridge;
		my $loop_count = $lv_count >= $nic_count ? $lv_count : $nic_count;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "lv_count",   value1 => $lv_count,
			name2 => "nic_count",  value2 => $nic_count,
			name3 => "loop_count", value3 => $loop_count,
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($loop_count > 0)
		{
			for (my $i=1; $loop_count > $i; $i++)
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "server",          value1 => $server,
					name2 => "lv_path[$i]", value2 => $lv_path[$i],
					name3 => "lv_size[$i]", value3 => $lv_size[$i],
				}, file => $THIS_FILE, line => __LINE__});
				my $say_lv_path = $lv_path[$i] ? $lv_path[$i] : "&nbsp;";
				my $say_lv_size = $lv_size[$i] ? $lv_size[$i] : "&nbsp;";
				my $say_network = "&nbsp;";
				if ($bridge[$i])
				{
					my $say_net_host = "";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "server",   value1 => $server,
						name2 => "host", value2 => $an->data->{server}{$server}{host},
					}, file => $THIS_FILE, line => __LINE__});
					if ($an->data->{server}{$server}{host} ne "none")
					{
						my $say_host     =  $an->data->{server}{$server}{host};
						   $say_host     =~ s/\..*//;
						   $say_net_host =  $an->Web->template({file => "server.html", template => "display-server-details-entra-nics", replace => { 
								say_host	=>	$say_host,
								bridge		=>	$bridge[$i] ? $bridge[$i] : "--",
								device		=>	$device[$i] ? $device[$i] : "--",
							}});
					}
					$say_network = "$say_net_host <span class=\"highlight_detail\">$type[$i]</span> / <span class=\"highlight_detail\">$mac[$i]</span>";
				}
				
				# Show extra LVs and/or networks.
				$server_details_panel .= $an->Web->template({file => "server.html", template => "display-server-details-entra-storage", replace => { 
						say_lv_path	=>	$say_lv_path,
						say_lv_size	=>	$say_lv_size,
						say_network	=>	$say_network,
					}});
			}
		}
	}
	$server_details_panel .= $an->Web->template({file => "server.html", template => "display-server-details-footer"});

	return ($server_details_panel);
}

# This shows the current state of the servers as well as the available control buttons.
sub _display_server_state_and_controls
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_display_server_state_and_controls" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make it a little easier to print the name of each node
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $node1_name = $an->data->{sys}{anvil}{node1}{name};
	my $node2_name = $an->data->{sys}{anvil}{node2}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "anvil_name", value1 => $anvil_name,
		name2 => "anvil_uuid", value2 => $anvil_uuid,
		name3 => "node1_name", value3 => $node1_name,
		name4 => "node2_name", value4 => $node2_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $server_state_and_control_panel = $an->Web->template({file => "server.html", template => "display-server-state-and-control-header", replace => { 
			anvil			=>	$an->data->{cgi}{anvil_uuid},
			node1_short_host_name	=>	$an->data->{sys}{anvil}{node1}{short_name},
			node2_short_host_name	=>	$an->data->{sys}{anvil}{node2}{short_name},
		}});

	foreach my $server (sort {$a cmp $b} keys %{$an->data->{server}})
	{
		# Break the name out of the hash key.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "server::${server}::host", value1 => $an->data->{server}{$server}{host},
		}, file => $THIS_FILE, line => __LINE__});
		
		# If the server has not yet been added to the Anvil!, skip it.
		if (not $an->data->{server}{$server}{host})
		{
			next;
		}
		
		# Use the node's short name for the buttons.
		my $say_start_target  =  $an->data->{server}{$server}{boot_target} ? $an->data->{server}{$server}{boot_target} : "--";
		   $say_start_target  =~ s/\..*?$//;
		my $start_target_long =  $node1_name =~ /$say_start_target/ ? $an->data->{node}{$node1_name}{info}{host_name} : $an->data->{node}{$node2_name}{info}{host_name};
		my $start_target_name =  $node1_name =~ /$say_start_target/ ? $node1_name : $node2_name;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "say_start_target",               value1 => $say_start_target,
			name2 => "server::${server}::boot_target", value2 => $an->data->{server}{$server}{boot_target},
			name3 => "start_target_long",              value3 => $start_target_long,
		}, file => $THIS_FILE, line => __LINE__});
		
		my $prefered_host =  $an->Striker->_find_preferred_host({server => $server});
		   $prefered_host =~ s/\..*$//;
		if ($an->data->{server}{$server}{boot_target})
		{
			$prefered_host = "<span class=\"highlight_ready\">$prefered_host</span>";
		}
		else
		{
			my $on_host =  $an->data->{server}{$server}{host};
			   $on_host =~ s/\..*$//;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "on_host",       value1 => $on_host,
				name2 => "prefered_host", value2 => $prefered_host,
			}, file => $THIS_FILE, line => __LINE__});
			if (($on_host eq $prefered_host) || ($on_host eq "none"))
			{
				$prefered_host = "<span class=\"highlight_good\">$prefered_host</span>";
			}
			else
			{
				$prefered_host = "<span class=\"highlight_warning\">$prefered_host</span>";
			}
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "prefered_host", value1 => $prefered_host,
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		my $say_migration_target =  $an->data->{server}{$server}{migration_target};
		   $say_migration_target =~ s/\..*?$//;
		my $migrate_button       =  $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0024!#" }});
		if ($an->data->{server}{$server}{can_migrate})
		{
			# If we're doing a cold migration, ask for confirmation. If this would be a live 
			# migration, just do it.
			my $button_link = "?anvil_uuid=$anvil_uuid&server=$server&task=migrate_server";
			my $server_data = $an->Get->server_data({
				server   => $server, 
				anvil    => $an->data->{cgi}{anvil_uuid}, 
			});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "button_link",                 value1 => $button_link,
				name2 => "server_data->migration_type", value2 => $server_data->{migration_type},
			}, file => $THIS_FILE, line => __LINE__});
			if ($server_data->{migration_type} eq "live")
			{
				$button_link .= "&confirm=true";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "button_link",                 value1 => $button_link,
					name2 => "server_data->migration_type", value2 => $server_data->{migration_type},
				}, file => $THIS_FILE, line => __LINE__});
			}
			my $say_target     = $an->String->get({key => "button_0025", variables => { migration_target => $say_migration_target }});
			   $migrate_button = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	$button_link,
					button_text	=>	$say_target,
					id		=>	"migrate_server_$server",
				}});
		}
		my $host_node        = $an->data->{server}{$server}{host};
		my $stop_button      = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0033!#" }});
		my $force_off_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0027!#" }});
		if ($an->data->{server}{$server}{can_stop})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "host node",           value1 => $host_node,
				name2 => "server::${server}::host", value2 => $an->data->{server}{$server}{host},
			}, file => $THIS_FILE, line => __LINE__});
			my $expire_time = time + $an->data->{sys}{actime_timeout};
			   $stop_button = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"?anvil_uuid=$anvil_uuid&server=$server&task=stop_server",
					button_text	=>	"#!string!button_0028!#",
					id		=>	"stop_server_$server",
				}});
			$force_off_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
					button_class	=>	"highlight_dangerous",
					button_link	=>	"?anvil_uuid=$anvil_uuid&server=$server&task=force_off_server&expire=$expire_time",
					button_text	=>	"#!string!button_0027!#",
					id		=>	"force_off_server_$server",
				}});
		}
		my $start_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0029!#" }});

		if ($an->data->{server}{$server}{boot_target})
		{
			$start_button = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"?anvil_uuid=$anvil_uuid&server=$server&task=start_server&confirm=true",
					button_text	=>	"#!string!button_0029!#",
					id		=>	"start_server_$server",
				}});
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "start_button",               value1 => $start_button,
			name2 => "server::${server}::boot_target", value2 => $an->data->{server}{$server}{boot_target},
		}, file => $THIS_FILE, line => __LINE__});
		
		# I need both nodes up to delete a server.
		my $say_delete_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0030!#" }});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "node::${node1_name}::daemon::cman::exit_code", value1 => $an->data->{node}{$node1_name}{daemon}{cman}{exit_code},
			name2 => "node::${node2_name}::daemon::cman::exit_code", value2 => $an->data->{node}{$node2_name}{daemon}{cman}{exit_code},
			name3 => "prefered_host",                           value3 => $prefered_host,
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{node}{$node1_name}{daemon}{cman}{exit_code} eq "0") && ($an->data->{node}{$node2_name}{daemon}{cman}{exit_code} eq "0") && ($prefered_host !~ /--/))
		{
			$say_delete_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
					button_class	=>	"highlight_dangerous",
					button_link	=>	"?anvil_uuid=$anvil_uuid&server=$server&task=delete_server",
					button_text	=>	"#!string!button_0030!#",
					id		=>	"delete_server_$server",
				}});
		}
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "server::${server}::say_node1", value1 => $an->data->{server}{$server}{say_node1},
			name2 => "server::${server}::say_node2", value2 => $an->data->{server}{$server}{say_node2},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{server}{$server}{node1_ready} == 2)
		{
			$an->data->{server}{$server}{say_node1} = "<span class=\"highlight_good\">#!string!state_0003!#</span>";
		}
		elsif ($an->data->{server}{$server}{node1_ready} == 1)
		{
			$an->data->{server}{$server}{say_node1} = "<span class=\"highlight_ready\">#!string!state_0009!#</span>";
		}
		if ($an->data->{server}{$server}{node2_ready} == 2)
		{
			$an->data->{server}{$server}{say_node2} = "<span class=\"highlight_good\">#!string!state_0003!#</span>";
		}
		elsif ($an->data->{server}{$server}{node2_ready} == 1)
		{
			$an->data->{server}{$server}{say_node2} = "<span class=\"highlight_ready\">#!string!state_0009!#</span>";
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "server::${server}::say_node1", value1 => $an->data->{server}{$server}{say_node1},
			name2 => "server::${server}::say_node2", value2 => $an->data->{server}{$server}{say_node2},
		}, file => $THIS_FILE, line => __LINE__});
		
		# I don't want to make the server editable until the Anvil! is running on at least one node.
		my $dual_join       = (($an->data->{node}{$node1_name}{enable_join}) && ($an->data->{node}{$node2_name}{enable_join})) ? 1 : 0;
		my $say_server_link = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
			button_class	=>	"fixed_width_button",
			button_link	=>	"?anvil_uuid=$anvil_uuid&server=$server&task=manage_server",
			button_text	=>	"$server",
			id		=>	"manage_server_$server",
		}});
		if ($dual_join)
		{
			my $say_server_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => $server }});
			   $say_server_link            = $say_server_disabled_button;
		}
		
		# If the state is 'failed', disable everything.
		$an->data->{server}{$server}{'state'} = "unknown" if not defined $an->data->{server}{$server}{'state'};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "server::${server}::state", value1 => $an->data->{server}{$server}{'state'},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{server}{$server}{'state'} eq "failed")
		{
			$say_server_link                        = $say_server_link." (<a href=\"#!string!url_0010!#\" target=\"_new\" class=\"highlight_bad\">#!string!state_0018!#</a>)";
			$an->data->{server}{$server}{say_node1} = "<span class=\"highlight_bad\">--</span>";
			$an->data->{server}{$server}{say_node2} = "<span class=\"highlight_bad\">--</span>";
			$prefered_host                          = "<span class=\"highlight_bad\">#!string!state_0001!#</span>";
			$start_button                           = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0029!#" }});
			$migrate_button                         = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0024!#" }});
			$stop_button                            = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0033!#" }});
			$force_off_button                       = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0027!#" }});
			$say_delete_button                      = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0030!#" }});
		}
		
		$server_state_and_control_panel .= $an->Web->template({file => "server.html", template => "display-server-details-entry", replace => { 
				server_link		=>	$say_server_link,
				say_node1		=>	$an->data->{server}{$server}{say_node1},
				say_node2		=>	$an->data->{server}{$server}{say_node2},
				prefered_host		=>	$prefered_host,
				start_button		=>	$start_button,
				migrate_button		=>	$migrate_button,
				stop_button		=>	$stop_button,
				force_off_button	=>	$force_off_button,
				delete_button		=>	$say_delete_button,
			}});
	}
	
	# When enabling the "Start" button, be sure to start on the highest 
	# priority host in the failover domain, when possible.
	$server_state_and_control_panel .= $an->Web->template({file => "server.html", template => "display-server-state-and-control-footer"});
	
	return ($server_state_and_control_panel);
}

# This returns a panel for controlling hard-resets via the 'APC UPS Watchdog' tools
sub _display_watchdog_panel
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_display_watchdog_panel" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $node1_name = $an->data->{sys}{anvil}{node1}{name};
	my $node2_name = $an->data->{sys}{anvil}{node2}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name1 => "anvil_name", value1 => $anvil_name,
		name2 => "node1_name", value2 => $node1_name,
		name3 => "node2_name", value3 => $node2_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	### NOTE: We used to try and use a node to cancel the countdown, but we're not doing that anymore 
	###       because it is possible they'll roll over and reset the counters before they shut down. So
	###       instead. we'll always use our local copy *provided* we can contact all of the UPSes on each
	###       node.
	
	my $note             = $parameter->{note} ? $parameter->{note} : "";
	my $expire_time      = time + $an->data->{sys}{actime_timeout};
	my $power_cycle_link = "?anvil_uuid=$anvil_uuid&expire=$expire_time&task=cold_stop&subtask=power_cycle";
	my $power_off_link   = "?anvil_uuid=$anvil_uuid&expire=$expire_time&task=cold_stop&subtask=power_off";
	my $watchdog_panel   = "";
	my $use_node         = "";
	my $target           = "";
	my $port             = "";
	my $password         = "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "note",             value1 => $note,
		name2 => "expire_time",      value2 => $expire_time,
		name3 => "power_cycle_link", value3 => $power_cycle_link,
		name4 => "power_off_link",   value4 => $power_off_link,
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: If not 'use_node', use our local copy of the watchdog script if we can reach the UPSes.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "tools::anvil-kick-apc-ups::enabled", value1 => $an->data->{tools}{'anvil-kick-apc-ups'}{enabled},
	}, file => $THIS_FILE, line => __LINE__});
	
	my $enabled = $an->data->{tools}{'anvil-kick-apc-ups'}{enabled};
	if ($enabled)
	{
		my ($upses) = $an->Get->node_upses({
				anvil_uuid => $an->data->{cgi}{anvil_uuid},
				node_name  => "both",
			});
		
		# See if we can access all the UPSes we found.
		my $access = $an->Striker->access_all_upses({anvil_uuid => $an->data->{sys}{anvil}{uuid}});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "access", value1 => $access,
		}, file => $THIS_FILE, line => __LINE__});
		
		### TODO: Show the connected UPS states.
		my $seen_upses = {};
		my $ups_list   = "";
		foreach my $node_name (sort {$a cmp $b} keys %{$an->data->{node_name}})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node_name", value1 => $node_name,
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $ip (sort {$a cmp $b} keys %{$an->data->{node_name}{$node_name}{upses}})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "ip", value1 => $ip,
				}, file => $THIS_FILE, line => __LINE__});
				
				# Skip this UPS if I saw it under the other node.
				next if exists $seen_upses->{$ip};
				$seen_upses->{$ip} = 1;
				
				# Still alive? Show our ability to ping it.
				my $ups_name = $an->data->{node_name}{$node_name}{upses}{$ip}{name};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "ups_name",                                        value1 => $ups_name,
					name2 => "node_name::${node_name}::upses::${ip}::can_ping", value2 => $an->data->{node_name}{$node_name}{upses}{$ip}{can_ping},
				}, file => $THIS_FILE, line => __LINE__});
				
				my $say_access = "<span class=\"highlight_warning\">".$an->String->get({key => "state_0021"})."</span>";
				if ($an->data->{node_name}{$node_name}{upses}{$ip}{can_ping})
				{
					# Accessible.
					$say_access = "<span class=\"highlight_good\">".$an->String->get({key => "state_0022"})."</span>";
				}
				$ups_list .= $an->Web->template({file => "server.html", template => "watchdog_panel_ups_entry", replace => { 
					name	=>	$upses->{$ip}{name},
					ip	=>	$ip,
					access	=>	$say_access,
				}});
			}
		}
		
		if ($access)
		{
			$power_cycle_link .= "&note=$note";
			$power_off_link   .= "&note=$note";
			$watchdog_panel   =  $an->Web->template({file => "server.html", template => "watchdog_panel", replace => { 
					power_cycle     => $power_cycle_link,
					power_off       => $power_off_link,
					ups_access_list => $ups_list,
				}});
			$watchdog_panel =~ s/\n$//;
		}
		else
		{
			# Tell the user that we've disabled this because one or more UPSes are not 
			# accessible.
			$watchdog_panel =  $an->Web->template({file => "server.html", template => "watchdog_panel-lost-access", replace => { ups_access_list => $ups_list }});
			$watchdog_panel =~ s/\n$//;
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "watchdog_panel", value1 => $watchdog_panel,
	}, file => $THIS_FILE, line => __LINE__});
	return($watchdog_panel);
}

# This uses the local machine to call "power on" against both nodes in the Anvil!.
sub _dual_boot
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_dual_boot" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# grab the CGI data
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $anvil_uuid)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0154", code => 154, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Pull out the rest of the data
	my $anvil_name = $an->data->{sys}{anvil}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil_name", value1 => $anvil_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Scan the Anvil!.
	$an->Striker->scan_anvil();
	
	my $say_message = $an->String->get({key => "message_0220", variables => { anvil => $anvil_name }});
	print $an->Web->template({file => "server.html", template => "dual-boot-header", replace => { message => $say_message }});
	
	# Boot each node.
	foreach my $node_key ("node1", "node2")
	{
		my $node_name = $an->data->{sys}{anvil}{$node_key}{name};
		my $node_uuid = $an->data->{sys}{anvil}{$node_key}{uuid};
		my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
		my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
		my $password  = $an->data->{sys}{anvil}{$node_key}{password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "node_name", value1 => $node_name,
			name2 => "node_uuid", value2 => $node_uuid,
			name3 => "target",    value3 => $target,
			name4 => "port",      value4 => $port,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password,
		}, file => $THIS_FILE, line => __LINE__});
		
		my $state = $an->ScanCore->target_power({target => $node_uuid});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "state", value1 => $state,
		}, file => $THIS_FILE, line => __LINE__});
		if ($state eq "off")
		{
			# Turn it on.
			my $state = $an->ScanCore->target_power({
					target => $node_uuid,
					task   => "on",
				});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "state", value1 => $state,
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($state eq "on")
			{
				# Success!
				my $message = $an->String->get({key => "message_0479", variables => { node_name => $node_name }});
				print $an->Web->template({file => "server.html", template => "dual-boot-shell-output", replace => { 
					status	=>	"#!string!state_0005!#",
					message	=>	$message,
				}});
				
				$an->Striker->mark_node_as_clean_on({node_uuid => $node_uuid});
			}
			else
			{
				# Failed to turn on
				my $message = $an->String->get({key => "message_0480", variables => { node_name => $node_name }});
				print $an->Web->template({file => "server.html", template => "dual-boot-shell-output", replace => { 
					status	=>	"#!string!state_0001!#",
					message	=>	$message,
				}});
			}
		}
		elsif ($state eq "on")
		{
			# It is already on
			my $message = $an->String->get({key => "message_0482", variables => { node_name => $node_name }});
			print $an->Web->template({file => "server.html", template => "dual-boot-shell-output", replace => { 
				status	=>	"#!string!state_0050!#",
				message	=>	$message,
			}});
		}
		elsif ($state eq "unknown")
		{
			# Failed to access the node.
			my $message = $an->String->get({key => "message_0483", variables => { node_name => $node_name }});
			print $an->Web->template({file => "server.html", template => "dual-boot-shell-output", replace => { 
				status	=>	"#!string!state_0050!#",
				message	=>	$message,
			}});
		}
	}
	
	print $an->Web->template({file => "server.html", template => "dual-boot-footer"});
	
	return(0);
}

# This sttempts to start the Anvil! stack on both nodes simultaneously.
sub _dual_join
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_dual_join" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# grab the CGI data
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $anvil_uuid)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0141", code => 141, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Scan the Anvil!.
	$an->Striker->scan_anvil();
	
	# Proceed only if all of the storage components, cman and rgmanager are off.
	my @abort_reason;
	my $proceed = 1;
	foreach my $node_key ("node1", "node2")
	{
		my $node_name = $an->data->{sys}{anvil}{$node_key}{name};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
			name1 => "node::${node_name}::daemon::cman::exit_code",      value1 => $an->data->{node}{$node_name}{daemon}{cman}{exit_code},
			name2 => "node::${node_name}::daemon::rgmanager::exit_code", value2 => $an->data->{node}{$node_name}{daemon}{rgmanager}{exit_code},
			name3 => "node::${node_name}::daemon::drbd::exit_code",      value3 => $an->data->{node}{$node_name}{daemon}{drbd}{exit_code},
			name4 => "node::${node_name}::daemon::clvmd::exit_code",     value4 => $an->data->{node}{$node_name}{daemon}{clvmd}{exit_code},
			name5 => "node::${node_name}::daemon::gfs2::exit_code",      value5 => $an->data->{node}{$node_name}{daemon}{gfs2}{exit_code},
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{node}{$node_name}{daemon}{cman}{exit_code}      eq "0") or
		    ($an->data->{node}{$node_name}{daemon}{rgmanager}{exit_code} eq "0") or
		    ($an->data->{node}{$node_name}{daemon}{drbd}{exit_code}      eq "0") or
		    ($an->data->{node}{$node_name}{daemon}{clvmd}{exit_code}     eq "0") or
		    ($an->data->{node}{$node_name}{daemon}{gfs2}{exit_code}      eq "0"))
		{
			# Already joined the Anvil!
			$proceed = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "proceed", value1 => $proceed,
			}, file => $THIS_FILE, line => __LINE__});
			my $reason  = $an->String->get({key => "message_0190", variables => { node => $node_name }});
			push @abort_reason, $reason;
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "proceed", value1 => $proceed,
	}, file => $THIS_FILE, line => __LINE__});
	if ($proceed)
	{
		my $say_title = $an->String->get({key => "title_0054", variables => { anvil => $anvil_name }});
		print $an->Web->template({file => "server.html", template => "dual-join-anvil-header", replace => { title => $say_title }});
		
		# Now call the command against both nodes using '$an->System->synchronous_command_run()'.
		my $command  = $an->data->{path}{initd}."/cman start && ".$an->data->{path}{initd}."/rgmanager start";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
			name1 => "command",                     value1 => $command,
			name2 => "sys::anvil::node1::use_ip",   value2 => $an->data->{sys}{anvil}{node1}{use_ip},
			name3 => "sys::anvil::node1::use_port", value3 => $an->data->{sys}{anvil}{node1}{use_port},
			name4 => "sys::anvil::node2::use_ip",   value4 => $an->data->{sys}{anvil}{node2}{use_ip},
			name5 => "sys::anvil::node2::use_port", value5 => $an->data->{sys}{anvil}{node2}{use_port},
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
			name1 => "sys::anvil::node1::use_password", value1 => $an->data->{sys}{anvil}{node1}{use_password},
			name2 => "sys::anvil::node2::use_password", value2 => $an->data->{sys}{anvil}{node2}{use_password},
		}, file => $THIS_FILE, line => __LINE__});
		my ($output) = $an->System->synchronous_command_run({
			command		=>	$command, 
			delay		=>	30,
			node1_ip	=>	$an->data->{sys}{anvil}{node1}{use_ip}, 
			node1_port	=>	$an->data->{sys}{anvil}{node1}{use_port}, 
			node1_password	=>	$an->data->{sys}{anvil}{node1}{use_password}, 
			node2_ip	=>	$an->data->{sys}{anvil}{node2}{use_ip}, 
			node2_port	=>	$an->data->{sys}{anvil}{node2}{use_port}, 
			node2_password	=>	$an->data->{sys}{anvil}{node2}{use_password}, 
		});
		
		foreach my $node_name ($an->data->{sys}{anvil}{node1}{name}, $an->data->{sys}{anvil}{node2}{name})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "output->$node_name", value1 => $output->{$node_name},
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $line (split/\n/, $output->{$node_name})
			{
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				$line =~ s/\s+/ /g;
				next if not $line;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				   $line    = $an->Web->parse_text_line({line => $line});
				my $message = ($line =~ /^(.*)\[/)[0];
				my $status  = ($line =~ /(\[.*)$/)[0];
				if (not $message)
				{
					$message = $line;
					$status  = "";
				}
				print $an->Web->template({file => "server.html", template => "dual-join-anvil-output", replace => { 
					node	=>	$node_name,
					message	=>	$message,
					status	=>	$status,
				}});
			}
		}
		
		# We're done.
		$an->Log->entry({log_level => 2, message_key => "log_0125", file => $THIS_FILE, line => __LINE__});
		print $an->Web->template({file => "server.html", template => "dual-join-anvil-footer"});
	}
	else
	{
		my $say_title = $an->String->get({key => "title_0055", variables => { anvil => $anvil_name }});
		print $an->Web->template({file => "server.html", template => "dual-join-anvil-aborted-header", replace => { title => $say_title }});
		foreach my $reason (@abort_reason)
		{
			print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $reason }});
		}
		print $an->Web->template({file => "server.html", template => "dual-join-anvil-aborted-footer"});
	}
	
	return(0);
}

### WARNING: This is legacy and should not be used anymore.
# This prints an error and exits. We don't log this in case the error was trigger when parsing a log entry or
# string.
sub _error
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $message = $parameter->{message};
	my $fatal   = $parameter->{fatal}   ? $parameter->{fatal} : 1;
	
	print $an->Web->template({file => "common.html", template => "error-table", replace => { message => $message }});
	$an->Striker->_footer() if $fatal;
	
	$an->nice_exit({exit_code => 1}) if $fatal;
	return(1);
}

# Footer that closes out all pages.
sub _footer
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_footer" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::footer_printed", value1 => $an->data->{sys}{footer_printed},
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->data->{sys}{footer_printed})
	{
		print $an->Web->template({file => "common.html", template => "footer"});
		$an->data->{sys}{footer_printed} = 1;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::footer_printed", value1 => $an->data->{sys}{footer_printed},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return (0);
}

# This uses the fence methods, as defined in cluster.conf and in the proper order, to fence the target node.
sub _fence_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_fence_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# grab the CGI data
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $node_name  = $an->data->{cgi}{node_name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "node_name",  value2 => $node_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $anvil_uuid)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0143", code => 143, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	if (not $node_name)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0144", code => 144, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Pull out the rest of the data
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_key   = $an->data->{sys}{node_name}{$node_name}{node_key};
	my $peer_key   = $an->data->{sys}{node_name}{$node_name}{peer_node_key};
	my $peer_name  = $an->data->{sys}{anvil}{$peer_key}{name};
	my $node_uuid  = $an->data->{sys}{anvil}{$node_key}{uuid};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
		name1 => "anvil_name", value1 => $anvil_name,
		name2 => "node_key",   value2 => $node_key,
		name3 => "peer_key",   value3 => $peer_key,
		name4 => "node_uuid",  value4 => $node_uuid,
		name5 => "peer_name",  value5 => $peer_name,
		name6 => "target",     value6 => $target,
		name7 => "port",       value7 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Has the timer expired?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "time",        value1 => time,
		name2 => "cgi::expire", value2 => $an->data->{cgi}{expire},
	}, file => $THIS_FILE, line => __LINE__});
	if (time > $an->data->{cgi}{expire})
	{
		# Abort!
		my $say_title   = $an->String->get({key => "title_0188"});
		my $say_message = $an->String->get({key => "message_0447", variables => { node => $node_name} });
		print $an->Web->template({file => "server.html", template => "request-expired", replace => { 
			title		=>	$say_title,
			message		=>	$say_message,
		}});
		return(1);
	}
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	### TODO: Fencing node 1 via node 2 on rapid reboot nodes hangs. So for now, directly fence it.
	# Now, if I can reach the peer node, use it to fence the target. Otherwise, we'll try to fence it 
	# using cached 'power_check' data, if available.
	#if ($an->data->{sys}{anvil}{$peer_key}{online})
	if (0)
	{
		# Sweet, fence via the peer.
		my $say_title   = $an->String->get({key => "title_0068", variables => { node_name => $node_name }});
		my $say_message = $an->String->get({key => "message_0233", variables => { node_name => $node_name }});
		print $an->Web->template({file => "server.html", template => "fence-node-header", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});
		print $an->Web->template({file => "server.html", template => "fence-node-output-header"});
		
		my $target   = $an->data->{sys}{anvil}{$node_key}{use_ip};
		my $port     = $an->data->{sys}{anvil}{$node_key}{use_port};
		my $password = $an->data->{sys}{anvil}{$node_key}{password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target", value1 => $target,
			name2 => "port",   value2 => $port,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password,
		}, file => $THIS_FILE, line => __LINE__});
		
		my $shell_call = $an->data->{path}{fence_node}." $node_name";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value2 => $target,
			name2 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			$line    = $an->Web->parse_text_line({line => $line});
			my $message = ($line =~ /^(.*)\[/)[0];
			my $status  = ($line =~ /(\[.*)$/)[0];
			if (not $message)
			{
				$message = $line;
				$status  = "";
			}
			print $an->Web->template({file => "server.html", template => "fence-node-message", replace => { 
				status	=>	$status,
				message	=>	$message,
			}});
		}
	}
	else
	{
		# OK, use cache to try to call it locally
		my $say_title   = $an->String->get({key => "title_0202", variables => { node_name => $node_name }});
		my $say_message = $an->String->get({key => "message_0233", variables => { node_name => $node_name }});
		print $an->Web->template({file => "server.html", template => "fence-node-header", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});
		print $an->Web->template({file => "server.html", template => "fence-node-output-header"});
		
		# Turn it off...
		my $state = $an->ScanCore->target_power({
				task   => "off",
				target => $node_uuid,
			});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "state", value1 => $state, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($state eq "off")
		{
			# Success, turn it back on.
			my $state = $an->ScanCore->target_power({
					task   => "on",
					target => $node_uuid,
				});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "state", value1 => $state, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($state eq "on")
			{
				# Success!
				my $message = $an->String->get({key => "message_0473", variables => { node_name => $node_name }});
				my $status  = $an->String->get({key => "state_0005"});
				print $an->Web->template({file => "server.html", template => "fence-node-message", replace => { 
					status	=>	$status,
					message	=>	$message,
				}});
			}
			else
			{
				# She's dead, Jim.
				my $message = $an->String->get({key => "message_0474", variables => { node_name => $node_name }});
				my $status  = $an->String->get({key => "state_0129"});
				print $an->Web->template({file => "server.html", template => "fence-node-message", replace => { 
					status	=>	$status,
					message	=>	$message,
				}});
			}
		}
		elsif ($state eq "on")
		{
			# Something went wrong. We got its state but it is on.
			my $message = $an->String->get({key => "message_0475", variables => { node_name => $node_name }});
			my $status  = $an->String->get({key => "state_0018"});
			print $an->Web->template({file => "server.html", template => "fence-node-message", replace => { 
				status	=>	$status,
				message	=>	$message,
			}});
		}
		else
		{
			my $message = $an->String->get({key => "message_0476", variables => { node_name => $node_name }});
			my $status  = $an->String->get({key => "state_0001"});
			print $an->Web->template({file => "server.html", template => "fence-node-message", replace => { 
				status	=>	$status,
				message	=>	$message,
			}});
		}
	}
	print $an->Web->template({file => "server.html", template => "fence-node-output-footer"});
	print $an->Web->template({file => "server.html", template => "fence-node-footer"});
	
	$an->Striker->_footer();
	
	return(0);
}

# This looks through the failover domain for a server and returns the prefered host.
sub _find_preferred_host
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_find_preferred_host" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $server = $parameter->{server};
	
	my $prefered_host   = "";
	my $failover_domain = $an->data->{server}{$server}{failover_domain};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "server",              value1 => $server,
		name2 => "failover_domain", value2 => $failover_domain,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $failover_domain)
	{
		# Not yet defined in the Anvil!.
		return("--");
	}
	
	# TODO: Check to see if I need to use <=> instead of cmp.
	foreach my $priority (sort {$a cmp $b} keys %{$an->data->{failoverdomain}{$failover_domain}{priority}})
	{
		# I only care about the first entry, so I will exit the loop as soon as I analyze it.
		$prefered_host = $an->data->{failoverdomain}{$failover_domain}{priority}{$priority}{node};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "prefered_host", value1 => $prefered_host,
		}, file => $THIS_FILE, line => __LINE__});
		last;
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "server",            value1 => $server,
		name2 => "prefered_host", value2 => $prefered_host,
	}, file => $THIS_FILE, line => __LINE__});
	return ($prefered_host);
}

# This forcibly shuts down a VM on a target node. The Anvil! should restart it shortly after.
sub _force_off_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_force_off_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make sure the server name exists.
	my $server     = $an->data->{cgi}{server}     ? $an->data->{cgi}{server}     : "";
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid} ? $an->data->{cgi}{anvil_uuid} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "server",     value1 => $server,
		name2 => "anvil_uuid", value2 => $anvil_uuid,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $anvil_uuid)
	{
		# Hey user, don't be cheeky!
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0132", code => 132, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	my $server_host = $an->data->{server}{$server}{host};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "server_host", value1 => $server_host,
	}, file => $THIS_FILE, line => __LINE__});
	if ($server_host eq "none")
	{
		# It is already off.
		my $say_message = $an->String->get({key => "message_0471", variables => { server => $an->data->{cgi}{server} }});
		print $an->Web->template({file => "server.html", template => "force-off-server-aborted", replace => { message => $say_message }});
		return("");
	}
	
	my $node_key = "";
	if ($server_host eq $an->data->{sys}{anvil}{node1}{name})
	{
		$node_key = "node1";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node_key", value1 => $node_key,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($server_host eq $an->data->{sys}{anvil}{node2}{name})
	{
		$node_key = "node2";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node_key", value1 => $node_key,
		}, file => $THIS_FILE, line => __LINE__});
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node_key", value1 => $node_key,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $node_key)
	{
		# What the deuce?!
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0133", message_variables => {
			server => $server, 
			host   => $server_host,
		}, code => 133, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	my $target   = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port     = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password = $an->data->{sys}{anvil}{$node_key}{password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target,
		name2 => "port",   value2 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Has the timer expired?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "time",        value1 => time,
		name2 => "cgi::expire", value2 => $an->data->{cgi}{expire},
	}, file => $THIS_FILE, line => __LINE__});
	if (time > $an->data->{cgi}{expire})
	{
		# Abort!
		my $say_title   = $an->String->get({key => "title_0186"});
		my $say_message = $an->String->get({key => "message_0445", variables => { server => $an->data->{cgi}{server} }});
		print $an->Web->template({file => "server.html", template => "request-expired", replace => { 
			title		=>	$say_title,
			message		=>	$say_message,
		}});
		return(1);
	}
	
	my $say_title = $an->String->get({key => "title_0056", variables => { server => $server }});
	print $an->Web->template({file => "server.html", template => "force-off-server-header", replace => { title => $say_title }});
	my $shell_call = $an->data->{path}{virsh}." destroy $server";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value2 => $target,
		name2 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		   $line    = $an->Web->parse_text_line({line => $line});
		my $message = ($line =~ /^(.*)\[/)[0];
		my $status  = ($line =~ /(\[.*)$/)[0];
		if (not $message)
		{
			$message = $line;
			$status  = "";
		}
		print $an->Web->template({file => "server.html", template => "fence-node-message", replace => { 
			status	=>	$status,
			message	=>	$message,
		}});
	}
	print $an->Web->template({file => "server.html", template => "force-off-server-footer"});
	
	return(0);
}

### NOTE: This is ugly, but it is basically a port of the old function so ya, whatever.
# This does the actual calls out to get the data and parse the returned data.
sub _gather_node_details
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_gather_node_details" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
		name1 => "node_uuid",  value1 => $node_uuid,
		name2 => "node_key",   value2 => $node_key,
		name3 => "anvil_uuid", value3 => $anvil_uuid,
		name4 => "anvil_name", value4 => $anvil_name,
		name5 => "node_name",  value5 => $node_name,
		name6 => "target",     value6 => $target,
		name7 => "port",       value7 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $shell_call = $an->data->{path}{dmidecode}." -t 4,16,17";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "target",     value2 => $target,
		name3 => "shell_call", value3 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $dmidecode) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
		
	# If this is the first up node, mark it as the one to use later if another function needs to get more
	# info from the Anvil!.
	$an->data->{sys}{use_node} = $node_name if not $an->data->{sys}{use_node};
	
	### Get the rest of the shell calls done before starting to parse.
	# Check to see if 'anvil-safe-start' is running
	$shell_call = $an->data->{path}{nodes}{'anvil-safe-start'}." --status";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "target",     value2 => $target,
		name3 => "shell_call", value3 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $anvil_safe_start) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# Get meminfo
	$shell_call = $an->data->{path}{cat}." ".$an->data->{path}{proc_meminfo};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "target",     value2 => $target,
		name3 => "shell_call", value3 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $meminfo) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# Get drbd info
	$shell_call = "
if [ -e ".$an->data->{path}{proc_drbd}." ]; 
then 
    ".$an->data->{path}{cat}." ".$an->data->{path}{proc_drbd}."; 
else 
    ".$an->data->{path}{echo}." 'drbd offline'; 
fi";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "target",     value2 => $target,
		name3 => "shell_call", value3 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $proc_drbd) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	$shell_call = $an->data->{path}{drbdadm}." dump-xml";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "target",     value2 => $target,
		name3 => "shell_call", value3 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $parse_drbdadm_dumpxml) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# clustat info
	$shell_call = $an->data->{path}{timeout}." 15 ".$an->data->{path}{clustat}."; ".$an->data->{path}{echo}." clustat:\$?";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "target",     value2 => $target,
		name3 => "shell_call", value3 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $clustat) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# Read cluster.conf
	$shell_call = $an->data->{path}{cat}." ".$an->data->{path}{cman_config};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "target",     value2 => $target,
		name3 => "shell_call", value3 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $cluster_conf) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	### NOTE: In the case of a failed/pending fence, it is possible that calling status on the cluster 
	###       daemons could hang. In such cases, the timeout will fire and allow the load to finish.
	# Read the daemon states
	$shell_call = "
".$an->data->{path}{timeout}." 15 ".$an->data->{path}{initd}."/rgmanager status; ".$an->data->{path}{echo}." striker:rgmanager:\$?; 
".$an->data->{path}{timeout}." 15 ".$an->data->{path}{initd}."/cman status; ".$an->data->{path}{echo}." striker:cman:\$?; 
".$an->data->{path}{initd}."/drbd status; ".$an->data->{path}{echo}." striker:drbd:\$?; 
".$an->data->{path}{timeout}." 15 ".$an->data->{path}{initd}."/clvmd status; ".$an->data->{path}{echo}." striker:clvmd:\$?; 
".$an->data->{path}{timeout}." 15 ".$an->data->{path}{initd}."/gfs2 status; ".$an->data->{path}{echo}." striker:gfs2:\$?; 
".$an->data->{path}{initd}."/libvirtd status; ".$an->data->{path}{echo}." striker:libvirtd:\$?;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "target",     value2 => $target,
		name3 => "shell_call", value3 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $daemons) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# LVM data
	$shell_call = "
".$an->data->{path}{timeout}." 15 ".$an->data->{path}{pvscan}."; ".$an->data->{path}{echo}." pvscan:\$?; 
".$an->data->{path}{timeout}." 15 ".$an->data->{path}{vgscan}."; ".$an->data->{path}{echo}." vgscan:\$?; 
".$an->data->{path}{timeout}." 15 ".$an->data->{path}{lvscan},"; ".$an->data->{path}{echo}." lvscan:\$?;
";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "target",     value2 => $target,
		name3 => "shell_call", value3 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $lvm_scan) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	$shell_call = "
".$an->data->{path}{timeout}." 15 ".$an->data->{path}{pvs}." --units b --separator \\\#\\\!\\\# -o pv_name,vg_name,pv_fmt,pv_attr,pv_size,pv_free,pv_used,pv_uuid; ".$an->data->{path}{echo}." pvs:\$?; 
".$an->data->{path}{timeout}." 15 ".$an->data->{path}{vgs}." --units b --separator \\\#\\\!\\\# -o vg_name,vg_attr,vg_extent_size,vg_extent_count,vg_uuid,vg_size,vg_free_count,vg_free,pv_name; ".$an->data->{path}{echo}." vgs:\$?; 
".$an->data->{path}{timeout}." 15 ".$an->data->{path}{lvs}." --units b --separator \\\#\\\!\\\# -o lv_name,vg_name,lv_attr,lv_size,lv_uuid,lv_path,devices; ".$an->data->{path}{echo}." lvs:\$?;
";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "target",     value2 => $target,
		name3 => "shell_call", value3 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $lvm_data) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# GFS2 data
	$shell_call = "
".$an->data->{path}{cat}." ".$an->data->{path}{etc_fstab}." | ".$an->data->{path}{'grep'}." gfs2;
".$an->data->{path}{df}." -hP";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "target",     value2 => $target,
		name3 => "shell_call", value3 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $gfs2) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# virsh data
	$shell_call = $an->data->{path}{virsh}." list --all";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "target",     value2 => $target,
		name3 => "shell_call", value3 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $virsh) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# server definitions - from file
	$shell_call = $an->data->{path}{timeout}." 15 ".$an->data->{path}{cat}." ".$an->data->{path}{shared_definitions}."/*; ".$an->data->{path}{echo}." rc:\$?; ";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "target",     value2 => $target,
		name3 => "shell_call", value3 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $server_defs) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# server definitions - in memory
	$shell_call = "
for server in \$(".$an->data->{path}{virsh}." list | ".$an->data->{path}{'grep'}." running | ".$an->data->{path}{awk}." '{print \$2}'); 
do 
    ".$an->data->{path}{virsh}." dumpxml \$server; 
done
";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "target",     value2 => $target,
		name3 => "shell_call", value3 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $server_defs_in_mem) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# Host name, in case the Anvil! isn't configured yet.
	$shell_call = $an->data->{path}{hostname};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "target",     value2 => $target,
		name3 => "shell_call", value3 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $hostname) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	if ($hostname->[0])
	{
		$an->data->{node}{$node_name}{info}{host_name} = $hostname->[0]; 
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node_name}::info::host_name", value1 => $an->data->{node}{$node_name}{info}{host_name},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Read the node's host file.
	$shell_call = $an->data->{path}{cat}." ".$an->data->{path}{etc_hosts};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "target",     value2 => $target,
		name3 => "shell_call", value3 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $hosts) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	$an->Striker->_parse_anvil_safe_start  ({node => $node_uuid, data => $anvil_safe_start});
	$an->Striker->_parse_clustat           ({node => $node_uuid, data => $clustat});
	$an->Striker->_parse_cluster_conf      ({node => $node_uuid, data => $cluster_conf});
	$an->Striker->_parse_daemons           ({node => $node_uuid, data => $daemons});
	$an->Striker->_parse_drbdadm_dumpxml   ({node => $node_uuid, data => $parse_drbdadm_dumpxml});
	$an->Striker->_parse_dmidecode         ({node => $node_uuid, data => $dmidecode});
	$an->Striker->_parse_gfs2              ({node => $node_uuid, data => $gfs2});
	$an->Striker->_parse_hosts             ({node => $node_uuid, data => $hosts});
	$an->Striker->_parse_lvm_data          ({node => $node_uuid, data => $lvm_data});
	$an->Striker->_parse_lvm_scan          ({node => $node_uuid, data => $lvm_scan});
	$an->Striker->_parse_meminfo           ({node => $node_uuid, data => $meminfo});
	$an->Striker->_parse_proc_drbd         ({node => $node_uuid, data => $proc_drbd});
	$an->Striker->_parse_virsh             ({node => $node_uuid, data => $virsh});
	$an->Striker->_parse_server_defs       ({node => $node_uuid, data => $server_defs});
	$an->Striker->_parse_server_defs_in_mem({node => $node_uuid, data => $server_defs_in_mem});	# Always parse this after 'parse_server_defs()' so that we overwrite it.

	# Some stuff, like setting the system memory, needs some post-scan math.
	$an->Striker->_post_node_calculations({node => $node_uuid});
	
	return (0);
}

# This determines what kind of storage the user has and then calls the appropriate function to gather the 
# details.
sub _get_storage_data
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_get_storage_data" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $node_name  = $an->data->{cgi}{node_name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "node_name",  value2 => $node_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $anvil_uuid)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0139", code => 139, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	if (not $node_name)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0140", code => 140, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	# Pull out the rest of the data
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_key   = $an->data->{sys}{node_name}{$node_name}{node_key};
	my $peer_key   = $an->data->{sys}{node_name}{$node_name}{peer_node_key};
	my $peer_name  = $an->data->{sys}{anvil}{$peer_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "anvil_name", value1 => $anvil_name,
		name2 => "node_key",   value2 => $node_key,
		name3 => "peer_key",   value3 => $peer_key,
		name4 => "peer_name",  value4 => $peer_name,
		name5 => "target",     value5 => $target,
		name6 => "port",       value6 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	   $an->data->{storage}{is}{lsi}   = "";
	   $an->data->{storage}{is}{hp}    = "";
	   $an->data->{storage}{is}{mdadm} = "";
	my $shell_call                     = $an->data->{path}{whereis}." MegaCli64 hpacucli";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^(.*?):\s(.*)/)
		{
			my $program = $1;
			my $path    = $2;
			if ($program eq "MegaCli64")
			{
				$an->data->{storage}{is}{lsi} = $path;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::is::lsi", value1 => $an->data->{storage}{is}{lsi},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($program eq "hpacucli")
			{
				$an->data->{storage}{is}{hp} = $path;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::is::hp", value1 => $an->data->{storage}{is}{hp},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($program eq "mdadm")
			{
				### TODO: This is always installed... 
				### Check if any arrays are configured and drop this if none.
				$an->data->{storage}{is}{mdadm} = $path;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::is::mdadm", value1 => $an->data->{storage}{is}{mdadm},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# For now, only LSI is supported.
	if ($an->data->{storage}{is}{lsi})
	{
		$an->HardwareLSI->_get_storage_data({
			target   => $target, 
			port     => $port, 
			password => $password, 
		});
	}
	
	return(0);
}

# This parses this Striker dashboard's hostname and returns the prefix and domain name.
sub _get_striker_prefix_and_domain
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_get_striker_prefix_and_domain" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $hostname = $an->hostname();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "hostname", value1 => $hostname,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $default_prefix = "";
	if ($hostname =~ /^(\w+)-/)
	{
		$default_prefix = $1;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "default_prefix", value1 => $default_prefix,
		}, file => $THIS_FILE, line => __LINE__});
	}
	my $default_domain = ($hostname =~ /\.(.*)$/)[0];
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "default_prefix", value1 => $default_prefix,
		name2 => "default_domain", value2 => $default_domain,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If the user has defined default prefix and/or domain, use them instead.
	if ($an->data->{sys}{install_manifest}{'default'}{prefix})
	{
		$default_prefix = $an->data->{sys}{install_manifest}{'default'}{prefix};
	}
	if ($an->data->{sys}{install_manifest}{'default'}{domain})
	{
		$default_domain = $an->data->{sys}{install_manifest}{'default'}{domain};
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "default_prefix", value1 => $default_prefix,
		name2 => "default_domain", value2 => $default_domain,
	}, file => $THIS_FILE, line => __LINE__});
	return($default_prefix, $default_domain);
}

# This sets up and displays the old-style header.
sub _header
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_header" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Who called us?
	my $caller = $parameter->{'caller'} ? $parameter->{'caller'} : "striker";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "caller", value1 => $caller,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Load some data
	my $anvil_name = "";
	my $anvil_uuid = "";
	my $node1_name = "";
	my $node2_name = "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_uuid", value1 => $an->data->{cgi}{anvil_uuid},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{cgi}{anvil_uuid}) && ($caller ne "configure"))
	{
		$an->Striker->load_anvil();
		$anvil_uuid = $an->data->{cgi}{anvil_uuid};
		$anvil_name = $an->data->{sys}{anvil}{name};
		$node1_name = $an->data->{sys}{anvil}{node1}{name};
		$node2_name = $an->data->{sys}{anvil}{node2}{name};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "anvil_uuid", value1 => $anvil_uuid,
			name2 => "anvil_name", value2 => $anvil_name,
			name3 => "node1_name", value3 => $node1_name,
			name4 => "node2_name", value4 => $node2_name,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Header buttons.
	my $say_back    = "&nbsp;";
	my $say_refresh = "&nbsp;";
	
	my $back_image = $an->Web->template({file => "common.html", template => "image", replace => { 
		image_source	=>	$an->data->{url}{skins}."/".$an->data->{sys}{skin}."/images/back.png",
		alt_text	=>	"#!string!button_0001!#",
		id		=>	"back_icon",
	}});

	my $refresh_image = $an->Web->template({file => "common.html", template => "image", replace => { 
		image_source	=>	$an->data->{url}{skins}."/".$an->data->{sys}{skin}."/images/refresh.png",
		alt_text	=>	"#!string!button_0002!#",
		id		=>	"refresh_icon",
	}});
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "caller", value1 => $caller,
	}, file => $THIS_FILE, line => __LINE__});
	if ($caller eq "configure")
	{
		$an->data->{sys}{cgi_string} =~ s/anvil_uuid=(.*?)&//;
		$an->data->{sys}{cgi_string} =~ s/anvil_uuid=(.*)$//;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "cgi::save", value1 => $an->data->{cgi}{save},
			name2 => "cgi::task", value2 => $an->data->{cgi}{task},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{save})
		{
			$say_refresh = "";
			$say_back    = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"?config=true",
					button_text	=>	"$back_image",
					id		=>	"back",
				}});
			if (($an->data->{cgi}{anvil_uuid} eq "new") && ($an->data->{cgi}{cluster__new__name}))
			{
				$an->data->{cgi}{anvil_uuid} = $an->data->{cgi}{cluster__new__name};
			}
			if (($an->data->{cgi}{anvil_uuid}) && ($an->data->{cgi}{anvil_uuid} ne "new"))
			{
				$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
						button_link	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&config=true",
						button_text	=>	"$back_image",
						id		=>	"back",
					}});
			}
		}
		elsif ($an->data->{cgi}{task})
		{
			$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"?config=true",
					button_text	=>	"$refresh_image",
					id		=>	"refresh",
				}});
			$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"/cgi-bin/configure",
					button_text	=>	"$back_image",
					id		=>	"back",
				}});
			
			if ($an->data->{cgi}{task} eq "load_config")
			{
				$say_refresh = "";
				my $back = "/cgi-bin/configure";
				if ($an->data->{cgi}{anvil_uuid})
				{
					$back = "?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&config=true";
				}
				$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
						button_link	=>	$back,
						button_text	=>	"$back_image",
						id		=>	"back",
					}});
			}
			elsif ($an->data->{cgi}{task} eq "push")
			{
				$say_refresh = "";
			}
			elsif ($an->data->{cgi}{task} eq "archive")
			{
				$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
						button_link	=>	"?config=true&task=archive",
						button_text	=>	"$refresh_image",
						id		=>	"refresh",
					}});
				$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
						button_link	=>	"/cgi-bin/configure",
						button_text	=>	"$back_image",
						id		=>	"back",
					}});
			}
			elsif ($an->data->{cgi}{task} eq "manifests")
			{
				my $link =  $an->data->{sys}{cgi_string};
				   $link =~ s/generate=true//;
				   $link =~ s/anvil_password=.*?&//;
				   $link =~ s/anvil_password=.*?$//;	# Catch the password if it is the last variable in the URL
				   $link =~ s/&&+/&/g;
				if ($an->data->{cgi}{confirm})
				{
					if ($an->data->{cgi}{run})
					{
						my $back_url =  $an->data->{sys}{cgi_string};
						   $back_url =~ s/confirm=.*?&//; $back_url =~ s/confirm=.*$//;
						   
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "sys::cgi_string", value1 => $an->data->{sys}{cgi_string},
						}, file => $THIS_FILE, line => __LINE__});
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "back_url", value1 => $back_url,
						}, file => $THIS_FILE, line => __LINE__});
						$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
								button_link	=>	"$back_url",
								button_text	=>	"$back_image",
								id		=>	"back",
							}});
					}
					elsif ($an->data->{cgi}{'delete'})
					{
						my $back_url =  $an->data->{sys}{cgi_string};
						   $back_url =~ s/confirm=.*?&//; $back_url =~ s/confirm=.*$//;
						   $back_url =~ s/delete=.*?&//;  $back_url =~ s/delete=.*$//;
						   
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "sys::cgi_string", value1 => $an->data->{sys}{cgi_string},
						}, file => $THIS_FILE, line => __LINE__});
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "back_url", value1 => $back_url,
						}, file => $THIS_FILE, line => __LINE__});
						$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
								button_link	=>	"$back_url",
								button_text	=>	"$back_image",
								id		=>	"back",
							}});
					}
					else
					{
						$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
								button_link	=>	"$link",
								button_text	=>	"$back_image",
								id		=>	"back",
							}});
					}
					$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	"?task=manifests",
							button_text	=>	"$refresh_image",
							id		=>	"refresh",
						}});
				}
				elsif ($an->data->{cgi}{generate})
				{
					$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	"$link",
							button_text	=>	"$back_image",
							id		=>	"back",
						}});
					$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	$an->data->{sys}{cgi_string},
							button_text	=>	"$refresh_image",
							id		=>	"refresh",
						}});
				}
				elsif ($an->data->{cgi}{run})
				{
					$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	"?task=manifests",
							button_text	=>	"$back_image",
							id		=>	"back",
						}});
					$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	$an->data->{sys}{cgi_string},
							button_text	=>	"$refresh_image",
							id		=>	"refresh",
						}});
				}
				elsif ($an->data->{cgi}{load})
				{
					$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	"?task=manifests",
							button_text	=>	"$back_image",
							id		=>	"back",
						}});
					$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	$an->data->{sys}{cgi_string},
							button_text	=>	"$refresh_image",
							id		=>	"refresh",
						}});
				}
				elsif ($an->data->{cgi}{raw})
				{
					$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	"?task=manifests",
							button_text	=>	"$back_image",
							id		=>	"back",
						}});
					$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	$an->data->{sys}{cgi_string},
							button_text	=>	"$refresh_image",
							id		=>	"refresh",
						}});
				}
				else
				{
					$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	"/cgi-bin/configure",
							button_text	=>	"$back_image",
							id		=>	"back",
						}});
					$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
							button_link	=>	"?task=manifests",
							button_text	=>	"$refresh_image",
							id		=>	"refresh",
						}});
				}
			}
			elsif ($an->data->{cgi}{anvil_uuid})
			{
				$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
						button_link	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&config=true",
						button_text	=>	"$refresh_image",
						id		=>	"refresh",
					}});
			}
		}
		else
		{
			$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	$an->data->{sys}{cgi_string},
					button_text	=>	"$refresh_image",
					id		=>	"refresh",
				}});
			$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"/cgi-bin/configure",
					button_text	=>	"$back_image",
					id		=>	"back",
				}});
			if ($an->data->{cgi}{anvil_uuid})
			{
				$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
						button_link	=>	"?config=true",
						button_text	=>	"$back_image",
						id		=>	"back",
					}});
			}
		}
	}
	elsif ($an->data->{cgi}{task})
	{
		$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid},
				button_text	=>	"$back_image",
				id		=>	"back",
			}});
		if ($an->data->{cgi}{task} eq "manage_server")
		{
			if ($an->data->{cgi}{change})
			{
				$say_refresh = "";
				$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
						button_link	=>	"?anvil_uuid=$anvil_uuid&server=".$an->data->{cgi}{server}."&task=manage_server",
						button_text	=>	"$back_image",
						id		=>	"back",
					}});
			}
			else
			{
				$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
						button_link	=>	"?anvil_uuid=$anvil_uuid&server=".$an->data->{cgi}{server}."&task=manage_server",
						button_text	=>	"$refresh_image",
						id		=>	"refresh",
					}});
			}
		}
		elsif ($an->data->{cgi}{task} eq "display_health")
		{
			$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"?anvil_uuid=$anvil_uuid&node_name=".$an->data->{cgi}{node_name}."&task=display_health",
					button_text	=>	"$refresh_image",
					id		=>	"refresh",
				}});
		}
		elsif ($an->data->{cgi}{task} eq "monitor_downloads")
		{
			$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"?anvil_uuid=$anvil_uuid&task=monitor_downloads",
					button_text	=>	"$refresh_image",
					id		=>	"refresh",
				}});
			$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"?anvil_uuid=$anvil_uuid",
					button_text	=>	"$back_image",
					id		=>	"back",
				}});
		}
	}
	elsif ($an->data->{cgi}{logo})
	{
		$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	"/cgi-bin/configure",
				button_text	=>	"$refresh_image",
				id		=>	"refresh",
			}});
		$say_back = "";
	}
	elsif ($caller eq "mediaLibrary")
	{
		$say_back = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	"/cgi-bin/striker?anvil_uuid=".$an->data->{cgi}{anvil_uuid},
				button_text	=>	"$back_image",
				id		=>	"back",
			}});
		$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	$an->data->{sys}{cgi_string},
				button_text	=>	"$refresh_image",
				id		=>	"refresh",
			}});
	}
	else
	{
		$say_refresh = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	$an->data->{sys}{cgi_string},
				button_text	=>	"$refresh_image",
				id		=>	"refresh",
			}});
	}
	
	foreach my $key (sort {$a cmp $b} keys %ENV)
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "key",        value1 => $key, 
			name2 => "ENV{\$key}", value2 => $ENV{$key},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# We only want the auto-refresh function to activate in certain pages.
	my $use_refresh = 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::reload_page_timer", value1 => $an->data->{sys}{reload_page_timer},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{reload_page_timer})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "sys::cgi_string",  value1 => $an->data->{sys}{cgi_string},
			name2 => "ENV{REQUEST_URI}", value2 => $ENV{REQUEST_URI},
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{sys}{cgi_string} eq "?anvil_uuid=".$an->data->{cgi}{anvil_uuid}) && 
		    ($ENV{REQUEST_URI} !~ /mediaLibrary/i))
		{
			# Use refresh
			$an->Log->entry({log_level => 3, message_key => "log_0014", file => $THIS_FILE, line => __LINE__});
			$use_refresh = 1;
		}
		else
		{
			# Do not use refresh
			$an->Log->entry({log_level => 3, message_key => "log_0015", file => $THIS_FILE, line => __LINE__});
		}
		if ($an->data->{sys}{cgi_string} =~ /\?anvil_uuid.*?&task=display_health&node_name.*?$/)
		{
			my $final = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "final", value1 => $final,
			}, file => $THIS_FILE, line => __LINE__});
			if ($final !~ /&/)
			{
				# Use refresh
				$an->Log->entry({log_level => 3, message_key => "log_0014", file => $THIS_FILE, line => __LINE__});
				$use_refresh = 1;
			}
			else
			{
				# Do not use refresh
				$an->Log->entry({log_level => 3, message_key => "log_0015", file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Now print the actual header.
	if ($use_refresh)
	{
		# Add the auto-reload function if requested by the user.
		print $an->Web->template({file => "common.html", template => "auto-refresh-header", replace => { 
			back		=>	$say_back,
			refresh		=>	$say_refresh,
		}});
	}
	else
	{
		print $an->Web->template({file => "common.html", template => "header", replace => { 
			back		=>	$say_back,
			refresh		=>	$say_refresh,
		}});
	}
	
	
	return (0);
}

# This attempts to join a node to an Anvil!.
sub _join_anvil
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_join_anvil" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# grab the CGI data
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $node_name  = $an->data->{cgi}{node_name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "node_name",  value2 => $node_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $anvil_uuid)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0139", code => 139, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	if (not $node_name)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0140", code => 140, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	# Pull out the rest of the data
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_key   = $an->data->{sys}{node_name}{$node_name}{node_key};
	my $peer_key   = $an->data->{sys}{node_name}{$node_name}{peer_node_key};
	my $peer_name  = $an->data->{sys}{anvil}{$peer_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "anvil_name", value1 => $anvil_name,
		name2 => "node_key",   value2 => $node_key,
		name3 => "peer_key",   value3 => $peer_key,
		name4 => "peer_name",  value4 => $peer_name,
		name5 => "target",     value5 => $target,
		name6 => "port",       value6 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: Should we abort if cman is not running on the peer but the peer is otherwise accessible? 
	###       One the one hand, it is not hosting any servers so the user's servers won't be impacted if
	###       it gets fenced. On the otherhand, the peer will get fenced after a delay... Maybe just
	###       print a warning that it will take a bit and that the peer will be fenced shortly if it is
	###       cman isn't started separately?
	# Proceed only if all of the storage components, cman and rgmanager are off.
	my $proceed = 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "node::${node_name}::daemon::cman::exit_code",      value1 => $an->data->{node}{$node_name}{daemon}{cman}{exit_code},
		name2 => "node::${node_name}::daemon::rgmanager::exit_code", value2 => $an->data->{node}{$node_name}{daemon}{rgmanager}{exit_code},
		name3 => "node::${node_name}::daemon::drbd::exit_code",      value3 => $an->data->{node}{$node_name}{daemon}{drbd}{exit_code},
		name4 => "node::${node_name}::daemon::clvmd::exit_code",     value4 => $an->data->{node}{$node_name}{daemon}{clvmd}{exit_code},
		name5 => "node::${node_name}::daemon::gfs2::exit_code",      value5 => $an->data->{node}{$node_name}{daemon}{gfs2}{exit_code},
		name6 => "node::${node_name}::daemon::libvirtd::exit_code",  value6 => $an->data->{node}{$node_name}{daemon}{libvirtd}{exit_code},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node_name}{daemon}{cman}{exit_code}      eq "3") or
	    ($an->data->{node}{$node_name}{daemon}{rgmanager}{exit_code} eq "3") or
	    ($an->data->{node}{$node_name}{daemon}{drbd}{exit_code}      eq "3") or
	    ($an->data->{node}{$node_name}{daemon}{clvmd}{exit_code}     eq "3") or
	    ($an->data->{node}{$node_name}{daemon}{gfs2}{exit_code}      eq "3") or
	    ($an->data->{node}{$node_name}{daemon}{libvirtd}{exit_code}  eq "3"))
	{
		$proceed = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "proceed", value1 => $proceed,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "proceed", value1 => $proceed,
	}, file => $THIS_FILE, line => __LINE__});
	if ($proceed)
	{
		my $say_title = $an->String->get({key => "title_0052", variables => { 
				node_name  => $node_name,
				anvil_name => $anvil_name,
			}});
		print $an->Web->template({file => "server.html", template => "join-anvil-header", replace => { title => $say_title }});
		
		# Start cman first.
		my $cman_state = 255;
		my $shell_call = $an->data->{path}{initd}."/cman start; ".$an->data->{path}{echo}." rc:\$?";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /^rc:(\d+)/)
			{
				$cman_state = $1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "cman_state", value1 => $cman_state, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				   $line    = $an->Web->parse_text_line({line => $line});
				my $message = ($line =~ /^(.*)\[/)[0];
				my $status  = ($line =~ /(\[.*)$/)[0];
				if (not $message)
				{
					$message = $line;
					$status  = "";
				}
				print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
					status	=>	$status,
					message	=>	$message,
				}});
			}
		}
		
		### TODO: Verify that cman actually started...
		my $rgmanager_state = 255;
		   $shell_call      = $an->data->{path}{initd}."/rgmanager start; ".$an->data->{path}{echo}." rc:\$?";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /^rc:(\d+)/)
			{
				$cman_state = $1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "cman_state", value1 => $cman_state, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				   $line    = $an->Web->parse_text_line({line => $line});
				my $message = ($line =~ /^(.*)\[/)[0];
				my $status  = ($line =~ /(\[.*)$/)[0];
				if (not $message)
				{
					$message = $line;
					$status  = "";
				}
				print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
					status	=>	$status,
					message	=>	$message,
				}});
			}
		}
		
		# Watch to see if storage starts. If it doesn't, the storage service might be disabled and 
		# we'll need to start it manually.
		my $started_waiting      = time;
		my $stop_waiting         = $started_waiting + 300;
		my $services_up          = 0;
		my $storage_n01_started  = 0;
		my $storage_n02_started  = 0;
		my $libvirtd_n01_started = 0;
		my $libvirtd_n02_started = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "started_waiting", value1 => $started_waiting,
			name2 => "stop_waiting",    value2 => $stop_waiting,
		}, file => $THIS_FILE, line => __LINE__});
		until ($services_up)
		{
			my $difference = $stop_waiting - time;
			if ($difference < 0)
			{
				# We're done waiting. Throw an error and exit the loop
				
				$services_up = 2;
			}
			my $shell_call = $an->data->{path}{clustat};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "target",     value1 => $target,
				name2 => "shell_call", value2 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$target,
				port		=>	$port, 
				password	=>	$password,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				$line =~ s/\s+/ /g;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /^service:(.*?) (.*?) (.*)$/)
				{
					my $service = $1;
					my $host    = $2;
					my $state   = $3;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "service", value1 => $service, 
						name2 => "host",    value2 => $host, 
						name3 => "state",   value3 => $state, 
					}, file => $THIS_FILE, line => __LINE__});
					
					# Storage on Node 1
					if ($service eq "storage_n01")
					{
						if ($state eq "started")
						{
							$storage_n01_started = 1;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "storage_n01_started", value1 => $storage_n01_started, 
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($state eq "disabled")
						{
							# We'll need to start it.
							$storage_n01_started = 2;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "storage_n01_started", value1 => $storage_n01_started, 
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($state eq "failed")
						{
							# Time to get a human involved.
							$storage_n01_started = 3;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "storage_n01_started", value1 => $storage_n01_started, 
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
					# Storage on Node 2
					if ($service eq "storage_n02")
					{
						if ($state eq "started")
						{
							$storage_n02_started = 1;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "storage_n02_started", value1 => $storage_n02_started, 
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($state eq "disabled")
						{
							# We'll need to start it.
							$storage_n02_started = 2;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "storage_n02_started", value1 => $storage_n02_started, 
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($state eq "failed")
						{
							# Time to get a human involved.
							$storage_n02_started = 3;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "storage_n02_started", value1 => $storage_n02_started, 
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
					# Libvirtd on Node 1
					if ($service eq "libvirtd_n01")
					{
						if ($state eq "started")
						{
							$libvirtd_n01_started = 1;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "libvirtd_n01_started", value1 => $libvirtd_n01_started, 
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($state eq "disabled")
						{
							# We'll need to start it.
							$libvirtd_n01_started = 2;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "libvirtd_n01_started", value1 => $libvirtd_n01_started, 
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($state eq "failed")
						{
							# Time to get a human involved.
							$libvirtd_n01_started = 3;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "libvirtd_n01_started", value1 => $libvirtd_n01_started, 
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
					# Libvirtd on Node 2
					if ($service eq "libvirtd_n02")
					{
						if ($state eq "started")
						{
							$libvirtd_n02_started = 1;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "libvirtd_n02_started", value1 => $libvirtd_n02_started, 
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($state eq "disabled")
						{
							# We'll need to start it.
							$libvirtd_n02_started = 2;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "libvirtd_n02_started", value1 => $libvirtd_n02_started, 
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($state eq "failed")
						{
							# Time to get a human involved.
							$libvirtd_n02_started = 3;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "libvirtd_n02_started", value1 => $libvirtd_n02_started, 
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
				}
			}
			
			### Check to see if any services are failed or disabled.
			# Storage Node 1
			if ($storage_n01_started eq "3")
			{
				# Throw a warning and exit the loop.
				$services_up = 3;
				print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
					status	=>	"<span class=\"highlight_bad\">#!string!state_0018!#</span>",
					message	=>	$an->String->get({key => "state_0134", variables => { service => "storage_n01" }}),
				}});
			}
			elsif ($storage_n01_started eq "2")
			{
				# Enable it.
				$storage_n01_started = 0;
				my $shell_call = $an->data->{path}{clusvcadm}." -e service:storage_n01";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "target",     value1 => $target,
					name2 => "shell_call", value2 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
				($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$target,
					port		=>	$port, 
					password	=>	$password,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			# Storage Node 2
			if ($storage_n02_started eq "3")
			{
				# Throw a warning and exit the loop.
				$services_up = 3;
				print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
					status	=>	"<span class=\"highlight_bad\">#!string!state_0018!#</span>",
					message	=>	$an->String->get({key => "state_0134", variables => { service => "storage_n02" }}),
				}});
			}
			elsif ($storage_n02_started eq "2")
			{
				# Enable it.
				$storage_n02_started = 0;
				my $shell_call = $an->data->{path}{clusvcadm}." -e service:storage_n02";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "target",     value1 => $target,
					name2 => "shell_call", value2 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
				($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$target,
					port		=>	$port, 
					password	=>	$password,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			# Libvirtd Node 1
			if ($libvirtd_n02_started eq "3")
			{
				# Throw a warning and exit the loop.
				$services_up = 3;
				print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
					status	=>	"<span class=\"highlight_bad\">#!string!state_0018!#</span>",
					message	=>	$an->String->get({key => "state_0134", variables => { service => "libvirtd_n02" }}),
				}});
			}
			elsif ($libvirtd_n02_started eq "2")
			{
				# Enable it.
				$libvirtd_n02_started = 0;
				my $shell_call = $an->data->{path}{clusvcadm}." -e service:libvirtd_n02";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "target",     value1 => $target,
					name2 => "shell_call", value2 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
				($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$target,
					port		=>	$port, 
					password	=>	$password,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			# Libvirtd Node 2
			if ($libvirtd_n02_started eq "3")
			{
				# Throw a warning and exit the loop.
				$services_up = 3;
				print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
					status	=>	"<span class=\"highlight_bad\">#!string!state_0018!#</span>",
					message	=>	$an->String->get({key => "state_0134", variables => { service => "libvirtd_n02" }}),
				}});
			}
			elsif ($libvirtd_n02_started eq "2")
			{
				# Enable it.
				$libvirtd_n02_started = 0;
				my $shell_call = $an->data->{path}{clusvcadm}." -e service:libvirtd_n02";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "target",     value1 => $target,
					name2 => "shell_call", value2 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
				($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$target,
					port		=>	$port, 
					password	=>	$password,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			
			# If all the services are up, exit.
			if (($storage_n01_started eq "1") && ($storage_n02_started eq "1") && ($libvirtd_n01_started eq "1") && ($libvirtd_n02_started eq "1"))
			{
				$services_up = 1;
			}
			else
			{
				sleep 5;
			}
		}
		
		print $an->Web->template({file => "server.html", template => "join-anvil-footer"});
	}
	else
	{
		# Node is already in the Anvil!
		my $say_title = $an->String->get({key => "title_0053", variables => { 
				node_name	=>	$node_name,
				anvil		=>	$anvil_name,
			}});
		print $an->Web->template({file => "server.html", template => "join-anvil-aborted", replace => { title => $say_title }});
	}
	
	return(0);
}

# This shows or changes the configuration of the VM, including mounted media.
sub _manage_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_manage_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# I need to get a list of the running VM's resource/media, read the VM's current XML if it is up, 
	# otherwise read the stored XML, read the available ISOs and then display everything in a form. If
	# the user submits the form and something is different, re-write the stored config and, if possible,
	# make the required changes immediately.
	
	# First, see if the server is up.
	$an->Striker->scan_anvil();
	my $anvil_uuid      = $an->data->{cgi}{anvil_uuid};
	my $anvil_name      = $an->data->{sys}{anvil}{name};
	my $server          = $an->data->{cgi}{server};
	my $node1_name      = $an->data->{sys}{anvil}{node1}{name};
	my $node2_name      = $an->data->{sys}{anvil}{node2}{name};
	my $device          = $an->data->{cgi}{device};
	my $definition_file = $an->data->{path}{shared_definitions}."/${server}.xml";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
		name1 => "anvil_uuid",      value1 => $anvil_uuid,
		name2 => "anvil_name",      value2 => $anvil_name,
		name3 => "server",          value3 => $server,
		name4 => "node1_name",      value4 => $node1_name,
		name5 => "node2_name",      value5 => $node2_name,
		name6 => "device",          value6 => $device,
		name7 => "definition_file", value7 => $definition_file,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Count how much RAM and CPU cores have been allocated.
	$an->data->{resources}{available_ram}   = 0;
	$an->data->{resources}{max_cpu_cores}   = 0;
	$an->data->{resources}{allocated_cores} = 0;
	$an->data->{resources}{allocated_ram}   = 0;
	foreach my $server (sort {$a cmp $b} keys %{$an->data->{server}})
	{
		# I check GFS2 because, without it, I can't read the VM's details.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "server",         value1 => $server,
			name2 => "sys::gfs2_down", value2 => $an->data->{sys}{gfs2_down},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{sys}{gfs2_down})
		{
			$an->data->{resources}{allocated_ram}   = "--";
			$an->data->{resources}{allocated_cores} = "--";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "resources::allocated_ram",   value1 => $an->data->{resources}{allocated_ram},
				name2 => "resources::allocated_cores", value2 => $an->data->{resources}{allocated_cores},
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			$an->data->{resources}{allocated_ram} += $an->data->{server}{$server}{details}{ram};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "resources::allocated_ram",        value1 => $an->data->{resources}{allocated_ram},
				name2 => "server::${server}::details::ram", value2 => $an->data->{server}{$server}{details}{ram},
			}, file => $THIS_FILE, line => __LINE__});
			
			$an->data->{resources}{allocated_cores} += $an->data->{server}{$server}{details}{cpu_count};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "resources::allocated_cores",            value1 => $an->data->{resources}{allocated_cores},
				name2 => "server::${server}::details::cpu_count", value2 => $an->data->{server}{$server}{details}{cpu_count},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# First up, if the Anvil! is not running, go no further.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node1_name}::daemon::gfs2::exit_code", value1 => $an->data->{node}{$node1_name}{daemon}{gfs2}{exit_code},
		name2 => "node::${node2_name}::daemon::gfs2::exit_code", value2 => $an->data->{node}{$node2_name}{daemon}{gfs2}{exit_code},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node1_name}{daemon}{gfs2}{exit_code}) && ($an->data->{node}{$node2_name}{daemon}{gfs2}{exit_code}))
	{
		print $an->Web->template({file => "server.html", template => "storage-not-ready"});
	}
	
	# Now choose the node to work through.
	my $node_name         = "";
	my $server_is_running = 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "server::${server}::current_host", value1 => $an->data->{server}{$server}{current_host},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{server}{$server}{current_host})
	{
		# Read the current server config from virsh.
		$server_is_running = 1;
		$node_name         = $an->data->{server}{$server}{current_host};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "server_is_running",                  value1 => $server_is_running,
			name2 => "node_name",                          value2 => $node_name,
			name3 => "server::${server}::definition_file", value3 => $an->data->{server}{$server}{definition_file},
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# The server isn't running.
		if ($an->data->{node}{$node1_name}{daemon}{gfs2}{exit_code} eq "0")
		{
			# Node 1 is up.
			$node_name = $node1_name;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node_name", value1 => $node_name,
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Node 2 must be up.
			$node_name = $node2_name;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node_name", value1 => $node_name,
			}, file => $THIS_FILE, line => __LINE__});
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "server::${server}::definition_file", value1 => $an->data->{server}{$server}{definition_file},
			name2 => "node_name",                          value2 => $node_name,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Use the new method to parse the server data and then feed it into the old hash keys
	my $server_data                             = $an->Get->server_data({server => $server});
	   $an->data->{server}{$server}{definition} = $server_data->{definition};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "server::${server}::definition", value1 => $an->data->{server}{$server}{definition},
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->data->{server}{$server}{details}{ram}       = $server_data->{current_ram};
	$an->data->{server}{$server}{details}{cpu_count} = $server_data->{cpu}{total};
	$an->data->{server}{$server}{graphics}{type}     = $server_data->{graphics}{type};
	$an->data->{server}{$server}{graphics}{port}     = $server_data->{graphics}{port};
	$an->data->{server}{$server}{graphics}{'listen'} = $server_data->{graphics}{address};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "server::${server}::details::ram",       value1 => $an->data->{server}{$server}{details}{ram},
		name2 => "server::${server}::details::cpu_count", value2 => $an->data->{server}{$server}{details}{cpu_count},
		name3 => "server::${server}::graphics::type",     value3 => $an->data->{server}{$server}{graphics}{type},
		name4 => "server::${server}::graphics::port",     value4 => $an->data->{server}{$server}{graphics}{port},
		name5 => "server::${server}::graphics::listen",   value5 => $an->data->{server}{$server}{graphics}{'listen'},
	}, file => $THIS_FILE, line => __LINE__});
	
	foreach my $mac_address (sort {$a cmp $b} keys %{$server_data->{network}{mac_address}})
	{
		my $current_bridge         = $server_data->{network}{mac_address}{$mac_address}{bridge};
		my $current_mac_address    = $mac_address;
		my $current_device         = $server_data->{network}{mac_address}{$mac_address}{vnet};
		my $current_interface_type = $server_data->{network}{mac_address}{$mac_address}{model};
		
		$an->data->{server}{$server}{details}{bridge}{$current_bridge}{device} = $current_device;
		$an->data->{server}{$server}{details}{bridge}{$current_bridge}{mac}    = $current_mac_address;
		$an->data->{server}{$server}{details}{bridge}{$current_bridge}{type}   = $current_interface_type;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "server::${server}::details::bridge::${current_bridge}::device", value1 => $an->data->{server}{$server}{details}{bridge}{$current_bridge}{device},
			name2 => "server::${server}::details::bridge::${current_bridge}::mac",    value2 => $an->data->{server}{$server}{details}{bridge}{$current_bridge}{mac},
			name3 => "server::${server}::details::bridge::${current_bridge}::type",   value3 => $an->data->{server}{$server}{details}{bridge}{$current_bridge}{type},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Load the target info now that we have a node name.
	my $node_key = $an->data->{sys}{node_name}{$node_name}{node_key};
	my $target   = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port     = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password = $an->data->{sys}{anvil}{$node_key}{password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node_key", value1 => $node_key,
		name2 => "target",   value2 => $target,
		name3 => "port",     value3 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0003", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If I've been asked to insert a disc, do so now.
	my $do_insert    = 0;
	my $insert_media = "";
	my $insert_drive = "";
	foreach my $key (split/,/, $an->data->{cgi}{device_keys})
	{
		next if not $key;
		next if not $an->data->{cgi}{$key};
		my $device_key   = $key;
		   $insert_drive = ($key =~ /media_(.*)/)[0];
		my $insert_key   = "insert_${insert_drive}";
		if ($an->data->{cgi}{$insert_key})
		{
			$do_insert    = 1;
			$insert_media = $an->data->{cgi}{$device_key};
		}
	}
	
	# Insert or eject media
	my $update_definition = 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "do_insert",    value1 => $do_insert,
		name2 => "insert_drive", value2 => $insert_drive,
		name3 => "insert_media", value3 => $insert_media,
	}, file => $THIS_FILE, line => __LINE__});
	if ($do_insert)
	{
		$an->Striker->_server_insert_media({
			target            => $target,
			port              => $port,
			password          => $password,
			insert_media      => $insert_media, 
			insert_drive      => $insert_drive,
			server_is_running => $server_is_running,
		});
		$update_definition = 1;
	}
	
	# If I've been asked to eject a disc, do so now.
	if ($an->data->{cgi}{'do'} eq "eject")
	{
		$an->Striker->_server_eject_media({
			target            => $target,
			port              => $port,
			password          => $password,
			server_is_running => $server_is_running,
		});
		$update_definition = 1;
	}
	
	# If I inserted or ejected a disk, update the definition in our hash.
	if ($update_definition)
	{
		my $server_data                             = $an->Get->server_data({server => $server});
		   $an->data->{server}{$server}{definition} = $server_data->{definition};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "server::${server}::definition", value1 => $an->data->{server}{$server}{definition},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Find the list of bootable devices and present them in a selection box. Also pull out the server's
	# UUID.
	my $boot_select = "<select name=\"boot_device\" style=\"width: 165px;\">";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "boot_select", value1 => $boot_select,
	}, file => $THIS_FILE, line => __LINE__});
	   $an->data->{server}{$server}{current_boot_device}    = "";
	   $an->data->{server}{$server}{available_boot_devices} = "";
	my $say_current_boot_device                             = "";
	my $in_os                                               = 0;
	my $saw_cdrom                                           = 0;
	my $server_uuid                                         = "";
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "server::${server}::definition", value1 => $an->data->{server}{$server}{definition},
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $line (split/\n/, $an->data->{server}{$server}{definition})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "in_os", value1 => $in_os,
			name2 => "server",    value2 => $server,
			name3 => "line",  value3 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		last if $line =~ /<\/domain>/;
		
		if ($line =~ /<uuid>([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})<\/uuid>/)
		{
			$server_uuid = $1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "server_uuid", value1 => $server_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /<os>/)
		{
			$in_os = 1;
			next;
		}
		if ($in_os == 1)
		{
			if ($line =~ /<\/os>/)
			{
				$in_os = 0;
				if ($saw_cdrom)
				{
					last;
				}
				else
				{
					# I didn't see a CD-ROM boot option, so keep looking.
					$in_os = 2;
				}
			}
			elsif ($line =~ /<boot dev='(.*?)'/)
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "server",   value1 => $server,
					name2 => "line", value2 => $line,
				}, file => $THIS_FILE, line => __LINE__});
				my $device                                              =  $1;
				my $say_device                                          =  $device;
				   $an->data->{server}{$server}{available_boot_devices} .= "$device,";
				if ($device eq "hd")
				{
					$say_device = "#!string!device_0001!#";
				}
				elsif ($device eq "cdrom")
				{
					$say_device = "#!string!device_0002!#";
					$saw_cdrom  = 1;
				}
				
				my $selected = "";
				if (not $an->data->{server}{$server}{current_boot_device})
				{
					$an->data->{server}{$server}{current_boot_device} = $device;
					$say_current_boot_device                          = $say_device;
					$selected                                         = "selected";
				}
				
				$boot_select .= "<option value=\"$device\" $selected>$say_device</option>";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "boot select", value1 => $boot_select,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		elsif ($in_os == 2)
		{
			# I'm out of the OS block, but I haven't seen a CD-ROM yet, so keep looping and 
			# looking for one.
			if ($line =~ /<disk .*?device='cdrom'/)
			{
				# There is a CD-ROM, add it as a boot option.
				my $say_device  =  "#!string!device_0002!#";
				   $boot_select .= "<option value=\"cdrom\">$say_device</option>";
				   $in_os       =  0;
				last;
			}
		}
	}
	$boot_select .= "</select>";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "boot_select", value1 => $boot_select,
	}, file => $THIS_FILE, line => __LINE__});
	
	# See if I have access to ScanCore and, if so, check for a note, the start after, start delay, 
	# migration type and pre/post migration scripts/args. If we have a database connection, show these 
	# options.
	my $show_db_options                 = 0;
	my $server_note                     = "";
	my $modified_date                   = "";
	my $server_start_after              = "";
	my $server_start_delay              = "";
	my $server_migration_type           = "";
	my $server_pre_migration_script     = "";
	my $server_pre_migration_arguments  = "";
	my $server_post_migration_script    = "";
	my $server_post_migration_arguments = "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "server_uuid",         value1 => $server_uuid, 
		name2 => "sys::db_connections", value2 => $an->data->{sys}{db_connections}, 
	}, file => $THIS_FILE, line => __LINE__});
	if (($server_uuid) && ($an->data->{sys}{db_connections}))
	{
		# Connection! Show the DB options.
		$show_db_options = 1;
		
		# Get the current DB data.
		my $results = $an->Get->server_data({
			uuid   => $server_uuid, 
			server => $server,
			anvil  => $anvil_name, 
		});
		$server_note                     = $results->{note};
		$server_start_after              = $results->{start_after};
		$server_start_delay              = $results->{start_delay};
		$server_migration_type           = $results->{migration_type};
		$server_pre_migration_script     = $results->{pre_migration_script};
		$server_pre_migration_arguments  = $results->{pre_migration_arguments};
		$server_post_migration_script    = $results->{post_migration_script};
		$server_post_migration_arguments = $results->{post_migration_arguments};
		$modified_date                   = $results->{modified_date};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0010", message_variables => {
			name1  => "show_db_options",                 value1  => $show_db_options, 
			name2  => "server_note",                     value2  => $server_note, 
			name3  => "server_start_after",              value3  => $server_start_after, 
			name4  => "server_start_delay",              value4  => $server_start_delay, 
			name5  => "server_migration_type",           value5  => $server_migration_type, 
			name6  => "server_pre_migration_script",     value6  => $server_pre_migration_script, 
			name7  => "server_pre_migration_arguments",  value7  => $server_pre_migration_arguments, 
			name8  => "server_post_migration_script",    value8  => $server_post_migration_script, 
			name9  => "server_post_migration_arguments", value9  => $server_post_migration_arguments, 
			name10 => "modified_date",                   value10 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# If the database is up, but we didn't get a result, the modified_date won't be set.
		if (not $modified_date)
		{
			$show_db_options = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "show_db_options", value1 => $show_db_options, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "show_db_options", value1 => $show_db_options
	}, file => $THIS_FILE, line => __LINE__});
	
	# If I need to change the number of CPUs or the amount of RAM, do so now.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::change", value1 => $an->data->{cgi}{change},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{cgi}{change})
	{
		$an->Striker->_change_server({node_name => $node_name});
	}
	
	# Get the list of files on the /shared/files/ directory.
	my $shell_call = $an->data->{path}{df}." -P && ".$an->data->{path}{ls}." -l /shared/files/";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /\s(\d+)-blocks\s/)
		{
			$an->data->{partition}{shared}{block_size} = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "partition::shared::block_size", value1 => $an->data->{partition}{shared}{block_size},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /^\/.*?\s+(\d+)\s+(\d+)\s+(\d+)\s(\d+)%\s+\/shared/)
		{
			$an->data->{partition}{shared}{total_space}  = $1;
			$an->data->{partition}{shared}{used_space}   = $2;
			$an->data->{partition}{shared}{free_space}   = $3;
			$an->data->{partition}{shared}{used_percent} = $4;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
				name1 => "partition::shared::total_space",  value1 => $an->data->{partition}{shared}{total_space},
				name2 => "partition::shared::used_space",   value2 => $an->data->{partition}{shared}{used_space},
				name3 => "partition::shared::used_percent", value3 => $an->data->{partition}{shared}{used_percent},
				name4 => "partition::shared::free_space",   value4 => $an->data->{partition}{shared}{free_space},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /^(\S)(\S+)\s+\d+\s+(\S+)\s+(\S+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\S+)\s+(.*)$/)
		{
			my $type   = $1;
			my $mode   = $2;
			my $user   = $3;
			my $group  = $4;
			my $size   = $5;
			my $month  = $6;
			my $day    = $7;
			my $time   = $8; # might be a year, look for '\d+:\d+'.
			my $file   = $9;
			my $target = "";
			if ($type eq "l")
			{
				# It is a symlink, strip off the destination.
				($file, $target) = ($file =~ /^(.*?) -> (.*)$/);
			}
			$an->data->{files}{shared}{$file}{type}   = $type;
			$an->data->{files}{shared}{$file}{mode}   = $mode;
			$an->data->{files}{shared}{$file}{user}   = $user;
			$an->data->{files}{shared}{$file}{group}  = $group;
			$an->data->{files}{shared}{$file}{size}   = $size;
			$an->data->{files}{shared}{$file}{month}  = $month;
			$an->data->{files}{shared}{$file}{day}    = $day;
			$an->data->{files}{shared}{$file}{'time'} = $time; # might be a year, look for '\d+:\d+'.
			$an->data->{files}{shared}{$file}{target} = $target;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0009", message_variables => {
				name1 => "files::shared::${file}::type",     value1 => $an->data->{files}{shared}{$file}{type},
				name2 => "files::shared::${file}::mode",     value2 => $an->data->{files}{shared}{$file}{mode},
				name3 => "files::shared::${file}::owner",    value3 => $an->data->{files}{shared}{$file}{user},
				name4 => "files::shared::${file}::group",    value4 => $an->data->{files}{shared}{$file}{group},
				name5 => "files::shared::${file}::size",     value5 => $an->data->{files}{shared}{$file}{size},
				name6 => "files::shared::${file}::modified", value6 => $an->data->{files}{shared}{$file}{month},
				name7 => "files::shared::${file}::day",      value7 => $an->data->{files}{shared}{$file}{day},
				name8 => "files::shared::${file}::time",     value8 => $an->data->{files}{shared}{$file}{'time'},
				name9 => "files::shared::${file}::target",   value9 => $an->data->{files}{shared}{$file}{target},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Find which ISOs are mounted currently.
	my $this_device = "";
	my $this_media  = "";
	my $in_cdrom    = 0;
	### TODO: Find out why the XML data is doubled up.
	foreach my $line (split/\n/, $an->data->{server}{$server}{definition})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "server", value1 => $server,
			name2 => "line",   value2 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		last if $line =~ /<\/domain>/;
		if ($line =~ /device='cdrom'/)
		{
			$in_cdrom = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "server",   value1 => $server,
				name2 => "in_cdrom", value2 => $in_cdrom,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (($line =~ /<\/disk>/) && ($in_cdrom))
		{
			# Record what I found/
			$an->data->{server}{$server}{cdrom}{$this_device}{media} = $this_media ? $this_media : "";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "server::${server}::cdrom::${this_device}::media", value1 => $an->data->{server}{$server}{cdrom}{$this_device}{media},
			}, file => $THIS_FILE, line => __LINE__});
			$in_cdrom    = 0;
			$this_device = "";
			$this_media  = "";
		}
		
		if ($in_cdrom)
		{
			if ($line =~ /source file='(.*?)'/)
			{
				$this_media = $1;
				$this_media =~ s/^.*\/(.*?)$/$1/;
			}
			elsif ($line =~ /source dev='(.*?)'/)
			{
				$this_media = $1;
				$this_media =~ s/^.*\/(.*?)$/$1/;
			}
			elsif ($line =~ /target dev='(.*?)'/)
			{
				$this_device = $1;
			}
		}
	}

	my $current_cpu_count = $an->data->{server}{$server}{details}{cpu_count};
	my $max_cpu_count     = $an->data->{resources}{total_threads};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "current_cpu_count", value1 => $current_cpu_count,
		name2 => "max_cpu_count",     value2 => $max_cpu_count,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Create the media select boxes.
	foreach my $device (sort {$a cmp $b} keys %{$an->data->{server}{$server}{cdrom}})
	{
		my $key                                             =  "media_$device";
		   $an->data->{server}{$server}{cdrom}{device_keys} .= "$key,";
		if ($an->data->{server}{$server}{cdrom}{$device}{media})
		{
			### TODO: If the media no longer exists, re-write the XML definition immediately.
			# Offer the eject button.
			$an->data->{server}{$server}{cdrom}{$device}{say_select}   = "<select name=\"$key\" disabled>\n";
			$an->data->{server}{$server}{cdrom}{$device}{say_in_drive} = "<span class=\"fixed_width\">".$an->data->{server}{$server}{cdrom}{$device}{media}."</span>\n";
			$an->data->{server}{$server}{cdrom}{$device}{say_eject}    = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
					button_class	=>	"bold_button",
					button_link	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&server=".$an->data->{cgi}{server}."&task=manage_server&do=eject&device=$device",
					button_text	=>	"#!string!button_0017!#",
					id		=>	"eject_$device",
				}});
			my $say_insert_disabled_button                  = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0018!#" }});
			   $an->data->{server}{$server}{cdrom}{$device}{say_insert} = "$say_insert_disabled_button\n";
		}
		else
		{
			# Offer the insert button
			   $an->data->{server}{$server}{cdrom}{$device}{say_select}   = "<select name=\"$key\">\n";
			   $an->data->{server}{$server}{cdrom}{$device}{say_in_drive} = "<span class=\"highlight_unavailable\">(#!string!state_0007!#)</span>\n";
			my $say_eject_disabled_button                                 = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0017!#" }});
			   $an->data->{server}{$server}{cdrom}{$device}{say_eject}    = "$say_eject_disabled_button\n";
			   $an->data->{server}{$server}{cdrom}{$device}{say_insert}   = $an->Web->template({file => "common.html", template => "form-input", replace => { 
					type	=>	"submit",
					name	=>	"insert_$device",
					id	=>	"insert_$device",
					value	=>	"#!string!button_0018!#",
					class	=>	"bold_button",
				}});
		}
		foreach my $file (sort {$a cmp $b} keys %{$an->data->{files}{shared}})
		{
			next if ($file eq $an->data->{server}{$server}{cdrom}{$device}{media});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "file",        value1 => $file,
				name2 => "cgi::${key}", value2 => $an->data->{cgi}{$key},
			}, file => $THIS_FILE, line => __LINE__});
			if ((defined $an->data->{cgi}{$key}) && ($file eq $an->data->{cgi}{$key}))
			{
				$an->data->{server}{$server}{cdrom}{$device}{say_select} .= "<option name=\"$file\" selected>$file</option>\n";
			}
			else
			{
				$an->data->{server}{$server}{cdrom}{$device}{say_select} .= "<option name=\"$file\">$file</option>\n";
			}
		}
		$an->data->{server}{$server}{cdrom}{$device}{say_select} .= "</select>\n";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "server::${server}::cdrom::${device}::media",      value1 => $an->data->{server}{$server}{cdrom}{$device}{media},
			name2 => "server::${server}::cdrom::${device}::say_select", value2 => $an->data->{server}{$server}{cdrom}{$device}{say_select},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Allow the user to select the number of CPUs.
	my $cpu_cores = [];
	foreach my $core_num (1..$max_cpu_count)
	{
		if ($max_cpu_count > 9)
		{
			push @{$cpu_cores}, $core_num;
		}
		else
		{
			push @{$cpu_cores}, $core_num;
		}
	}
	   $an->data->{cgi}{cpu_cores} = $current_cpu_count if not $an->data->{cgi}{cpu_cores};
	my $select_cpu_cores           = $an->Web->build_select({
			name     => "cpu_cores", 
			options  => $cpu_cores, 
			blank    => 0,
			selected => $an->data->{cgi}{cpu_cores},
			width    => 60,
		});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "select_cpu_cores", value1 => $select_cpu_cores,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Something has changed. Make sure the request is sane,
	my $current_ram = $an->data->{server}{$server}{details}{ram};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "current_ram", value1 => $current_ram,
	}, file => $THIS_FILE, line => __LINE__});

	my $diff          = $an->data->{resources}{total_ram} % (1024 ** 3);
	my $available_ram = ($an->data->{resources}{total_ram} - $diff - $an->data->{sys}{unusable_ram} - $an->data->{resources}{allocated_ram}) + $current_ram;
	my $max_ram       = $available_ram;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "available_ram", value1 => $available_ram,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If the user sets the RAM to less than 1 GiB, warn them. If the user sets the RAM to less that 32 
	# MiB, error out.
	my $say_max_ram                              = $an->Readable->bytes_to_hr({'bytes' => $max_ram });
	my $say_current_ram                          = $an->Readable->bytes_to_hr({'bytes' => $current_ram });
	my ($current_ram_value, $current_ram_suffix) = (split/ /, $say_current_ram);
	   $an->data->{cgi}{ram}                     = $current_ram_value if not $an->data->{cgi}{ram};
	   $an->data->{cgi}{ram_suffix}              = $current_ram_suffix if not $an->data->{cgi}{ram_suffix};
	my $select_ram_suffix                        = $an->Web->build_select({
			name     => "ram_suffix", 
			options  => ["MiB", "GiB"], 
			blank    => 0,
			selected => $an->data->{cgi}{ram_suffix},
			width    => 60,
		});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "say_max_ram",       value1 => $say_max_ram,
		name2 => "cgi::ram",          value2 => $an->data->{cgi}{ram},
		name3 => "select_ram_suffix", value3 => $select_ram_suffix,
	}, file => $THIS_FILE, line => __LINE__});
	
	### Disabled now.
	# Setup Guacamole, if installed.
	my $message     = "";
	my $remote_icon = "";
	
	# Finally, print it all
	my $title = $an->String->get({key => "title_0032", variables => { server => $server }});
	print $an->Web->template({file => "server.html", template => "manager-server-header", replace => { title => $title }});

	my $i = 1;
	foreach my $device (sort {$a cmp $b} keys %{$an->data->{server}{$server}{cdrom}})
	{
		next if $device eq "device_keys";
		my $say_disk   = $an->data->{server}{$server}{cdrom}{$device}{say_select};
		my $say_button = $an->data->{server}{$server}{cdrom}{$device}{say_insert};
		my $say_state  = "#!string!state_0124!#";
		if ($an->data->{server}{$server}{cdrom}{$device}{media})
		{
			$say_disk   = $an->data->{server}{$server}{cdrom}{$device}{say_in_drive};
			$say_button = $an->data->{server}{$server}{cdrom}{$device}{say_eject};
			$say_state  = "#!string!state_0125!#";
		}
		my $say_optical_drive = $an->String->get({key => "device_0003", variables => { drive_number => $i }});
		print $an->Web->template({file => "server.html", template => "manager-server-optical-drive", replace => { 
				optical_drive	=>	$say_optical_drive,
				'state'		=>	$say_state,
				disk		=>	$say_disk,
				button		=>	$say_button,
			}});
		$i++;
	}
	
	# If we can show the note, do so
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "show_db_options", value1 => $show_db_options,
	}, file => $THIS_FILE, line => __LINE__});
	my $note_form = "";
	if ($show_db_options)
	{
		### TODO: If there is only one server, present an option to "Always Boot", "Never Boot" and 
		###       "Last State" to inform anvil-safe-start as to what to do when it runs.
		my $return = $an->Get->server_data({
			server => $server, 
			anvil  => $anvil_name, 
		});
		if (not $an->data->{cgi}{server_start_after})
		{
			$an->data->{cgi}{server_start_after} = $return->{start_after};
		}
		
		# These will become the select boxes
		my $say_boot_delay_disabled          = "disabled";
		my $say_boot_after_select            = "#!string!message_0308!#";
		my $say_migration_type_select        = "--";
		my $say_pre_migration_script_select  = "--";
		my $say_post_migration_script_select = "--";
		
		# Now get the information to build the "Boot After" select.
		my $other_servers = [];
		my $server_uuid   = $return->{uuid};
		my $query         = "
SELECT 
    server_name, 
    server_uuid 
FROM 
    servers 
WHERE 
    server_uuid !=  ".$an->data->{sys}{use_db_fh}->quote($server_uuid)." 
AND 
    server_name IS DISTINCT FROM 'DELETED'
ORDER BY 
    server_name ASC
;";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		if ($count)
		{
			# At least one other server exists.
			foreach my $row (@{$results})
			{
				my $server_name = $row->[0];
				my $server_uuid = $row->[1];
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "server_name", value1 => $server_name, 
					name2 => "server_uuid", value2 => $server_uuid, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# Make sure this is a server on this Anvil!
				foreach my $server (sort {$a cmp $b} keys %{$an->data->{server}})
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "server_name", value1 => $server_name, 
						name2 => "server",      value2 => $server, 
					}, file => $THIS_FILE, line => __LINE__});
					if ($server_name eq $server)
					{
						push @{$other_servers}, "$server_uuid#!#$server_name";
					}
				}
			}
			
			# Add the 'Don't Boot' option
			my $say_dont_boot = $an->String->get({key => "title_0105"});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "say_dont_boot", value1 => $say_dont_boot,
			}, file => $THIS_FILE, line => __LINE__});
			push @{$other_servers}, "00000000-0000-0000-0000-000000000000#!#<i>$say_dont_boot</i>";
			
			# Build the Start After select
			$say_boot_after_select = $an->Web->build_select({
					name     => "server_start_after", 
					options  => $other_servers, 
					blank    => 1,
					selected => $an->data->{cgi}{server_start_after},
					width    => 150,
				});
			$say_boot_delay_disabled = "";
		}
		
		### Now build the rest of the selects.
		# If the user didn't click save, load the DB values.
		if (not $an->data->{cgi}{change})
		{
			if (not $an->data->{cgi}{server_migration_type})
			{
				$an->data->{cgi}{server_migration_type} = $server_migration_type;
			}
			if (not $an->data->{cgi}{server_pre_migration_script})
			{
				$an->data->{cgi}{server_pre_migration_script} = $server_pre_migration_script;
			}
			if (($an->data->{cgi}{server_pre_migration_script}) && (not $an->data->{cgi}{server_pre_migration_arguments}))
			{
				$an->data->{cgi}{server_pre_migration_arguments} = $server_pre_migration_arguments;
			}
			else
			{
				# No script, so clear args.
				$an->data->{cgi}{server_pre_migration_arguments} = "";
			}
			if (not $an->data->{cgi}{server_post_migration_script})
			{
				$an->data->{cgi}{server_post_migration_script} = $server_post_migration_script;
			}
			if (($an->data->{cgi}{server_post_migration_script}) && (not $an->data->{cgi}{server_post_migration_arguments}))
			{
				$an->data->{cgi}{server_post_migration_arguments} = $server_post_migration_arguments;
			}
			else
			{
				# No script, so clear args.
				$an->data->{cgi}{server_post_migration_arguments} = "";
			}
		}
		
		# Migration type
		$say_migration_type_select = $an->Web->build_select({
				name     => "server_migration_type", 
				options  => ["live#!##!string!state_0126!#", "cold#!##!string!state_0127!#"], 
				blank    => 0,
				selected => $an->data->{cgi}{server_migration_type},
				width    => 150,
			});
		
		# Get a list of files from /shared/files that are not ISOs and have their 'executable' bit 
		# set.
		my $scripts = [];
		my ($files, $partition) = $an->Get->shared_files({
			target   => $target,
			port     => $port,
			password => $password,
		});
		foreach my $file (sort {$a cmp $b} keys %{$files})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "${file}::executable", value1 => $files->{$file}{executable},
			}, file => $THIS_FILE, line => __LINE__});
			if ($files->{$file}{executable})
			{
				push @{$scripts}, $file;
			}
		}
		
		# Build the Pre and Post migration script selection boxes.
		$say_pre_migration_script_select = $an->Web->build_select({
				name     => "server_pre_migration_script", 
				options  => $scripts, 
				blank    => 1,
				selected => $an->data->{cgi}{server_pre_migration_script},
				width    => 150,
			});
		$say_post_migration_script_select = $an->Web->build_select({
				name     => "server_post_migration_script", 
				options  => $scripts, 
				blank    => 1,
				selected => $an->data->{cgi}{server_post_migration_script},
				width    => 150,
			});
		
		# Take the fractional component of the second off the modified date stamp.
		$modified_date =~ s/\..*//;
		$note_form     =  $an->Web->template({file => "server.html", template => "start-server-show-db-options", replace => { 
				server_note			=>	$server_note,
				server_start_after		=>	$say_boot_after_select,
				server_start_delay		=>	$server_start_delay,
				server_start_delay_disabled	=>	$say_boot_delay_disabled, 
				server_migration_type		=>	$say_migration_type_select,
				server_pre_migration_script	=>	$say_pre_migration_script_select, 
				server_pre_migration_arguments	=>	$an->data->{cgi}{server_pre_migration_arguments}, 
				server_post_migration_script	=>	$say_post_migration_script_select, 
				server_post_migration_arguments	=>	$an->data->{cgi}{server_post_migration_arguments}, 
				modified_date			=>	$modified_date,
			}});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "note_form", value1 => $note_form,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	my $current_boot_device = $an->String->get({key => "message_0081", variables => { boot_device => $say_current_boot_device }});
	my $cpu_details         = $an->String->get({key => "message_0083", variables => { current_cpus => $an->data->{server}{$server}{details}{cpu_count} }});
	my $restart_tomcat      = $an->String->get({key => "message_0085", variables => { reset_tomcat_url => "?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&task=restart_tomcat" }});
	my $ram_details         = $an->String->get({key => "message_0082", variables => { 
			current_ram	=>	$say_current_ram,
			maximum_ram	=>	$say_max_ram,
		}});

	# Display all this wonderful data.
	print $an->Web->template({file => "server.html", template => "manager-server-show-details", replace => { 
			current_boot_device	=>	$current_boot_device,
			boot_select		=>	$boot_select,
			ram_details		=>	$ram_details,
			ram			=>	$an->data->{cgi}{ram},
			select_ram_suffix	=>	$select_ram_suffix,
			cpu_details		=>	$cpu_details,
			select_cpu_cores	=>	$select_cpu_cores,
			remote_icon		=>	$remote_icon,
			message			=>	$message,
			server_note		=>	$note_form, 
			restart_tomcat		=>	$restart_tomcat,
			anvil_uuid		=>	$an->data->{cgi}{anvil_uuid},
			anvil			=>	$anvil_name,
			server			=>	$an->data->{cgi}{server},
			task			=>	$an->data->{cgi}{task},
			device_keys		=>	$an->data->{server}{$server}{cdrom}{device_keys},
			rowspan			=>	$show_db_options ? 10 : 5,
		}});
	
	return (0);
}

# This migrates a server using 'anvil-migrate-server'
sub _migrate_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_migrate_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $server     = $an->data->{cgi}{server};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "server",     value3 => $server,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $server)
	{
		# Error...
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0130", code => 130, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	my $say_title = $an->String->get({key => "title_0049", variables => { server =>	$server }});
	print $an->Web->template({file => "server.html", template => "migrate-server-header", replace => { title => $say_title }});
	
	# Which node to use?
	my ($target, $port, $password, $node_name) = $an->Cman->find_node_in_cluster();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "target", value1 => $target,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $target)
	{
		# Couldn't log into either node.
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0126", message_variables => { server => $server }, code => 126, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Call 'anvil-boot-server'
	my $shell_call = $an->data->{path}{'anvil-migrate-server'}." --server $server";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	if (@{$return} > 0)
	{
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			
			   $line    = $an->Web->parse_text_line({line => $line});
			my $message = ($line =~ /^(.*)\[/)[0];
			my $status  = ($line =~ /(\[.*)$/)[0];
			if (not $message)
			{
				$message = $line;
				$status  = "";
			}
			print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
				status	=>	$status,
				message	=>	$message,
			}});
		}
		print $an->Web->template({file => "server.html", template => "start-server-output-footer"});
	}
	print $an->Web->template({file => "server.html", template => "migrate-server-footer"});
	$an->Striker->_footer();

	return(0);
}

# Parse the 'anvil-safe-start' status.
sub _parse_anvil_safe_start
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_parse_anvil_safe_start" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $data       = $parameter->{data};
	
	$an->data->{node}{$node_name}{'anvil-safe-start'} = 0;
	foreach my $line (@{$data})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node_name", value1 => $node_name,
			name2 => "line",      value2 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		if (($line =~ /\[running\]/i) or ($line =~ /\[queued\]/i))
		{
			$an->data->{node}{$node_name}{'anvil-safe-start'} = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node_name}::anvil-safe-start", value1 => $an->data->{node}{$node_name}{'anvil-safe-start'},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# TODO: This is a dirty fix and we should feel dirty. It shouldn't return 'running' or 'queued' when
	#       it runs via crontab.
	# Check the uptime. If it is > 10 minutes, don't show this.
	if ($an->data->{node}{$node_name}{'anvil-safe-start'})
	{
		my $uptime = $an->System->get_uptime({
				target		=>	$target,
				port		=>	$port, 
				password	=>	$password,
			});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "uptime", value1 => $uptime,
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($uptime > 600)
		{
			$an->data->{node}{$node_name}{'anvil-safe-start'} = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node_name}::anvil-safe-start", value1 => $an->data->{node}{$node_name}{'anvil-safe-start'},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

# Parse the cluster configuration.
sub _parse_cluster_conf
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_parse_cluster_conf" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $data      = $parameter->{data} ? $parameter->{data} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node_uuid", value1 => $node_uuid,
		name2 => "data",      value2 => $data,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $node_name = "local";
	my $target     = "";
	my $port       = "";
	my $password   = "";
	if ($node_uuid)
	{
		my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
		   $node_name = $an->data->{sys}{anvil}{$node_key}{name};
		   $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
		   $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
		   $password  = $an->data->{sys}{anvil}{$node_key}{password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "node_key",  value1 => $node_key,
			name2 => "node_name", value2 => $node_name,
			name3 => "target",    value3 => $target,
			name4 => "port",      value4 => $port,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	my $in_failover_domain      = 0;
	my $current_failover_domain = "";
	my $in_node                 = "";
	my $in_fence                = 0;
	my $in_method               = "";
	my $device_count            = 0;
	my $in_fence_device         = 0;
	my $this_host_name          = "";
	my $this_node               = "";
	my $method_counter          = 0;
	
	# If the 'node_name' is "local" and there is no $data, read in the local cluster.conf
	if (($node_name eq "local") && (not $data))
	{
		   $data       = [];
		my $shell_call = $an->data->{path}{cat}." ".$an->data->{path}{cman_config};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			push @{$data}, $line;
		}
		close $file_handle;
	}
	
	foreach my $line (@{$data})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "node_name", value1 => $node_name,
			name2 => "line",      value2 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Find failover domains.
		if ($line =~ /<failoverdomain /)
		{
			$current_failover_domain = ($line =~ /name="(.*?)"/)[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "current_failover_domain", value1 => $current_failover_domain,
			}, file => $THIS_FILE, line => __LINE__});
			
			$in_failover_domain = 1;
			next;
		}
		if ($line =~ /<\/failoverdomain>/)
		{
			$current_failover_domain = "";
			$in_failover_domain      = 0;
			next;
		}
		if ($in_failover_domain)
		{
			next if $line !~ /failoverdomainnode/;
			my $node     = ($line =~ /name="(.*?)"/)[0];
			my $priority = ($line =~ /priority="(.*?)"/)[0] ? $1 : 0;
			$an->data->{failoverdomain}{$current_failover_domain}{priority}{$priority}{node} = $node;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "failoverdomain::${current_failover_domain}::priority::${priority}::node", value1 => $an->data->{failoverdomain}{$current_failover_domain}{priority}{$priority}{node},
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# If I didn't get the hostname from clustat, try to find it here.
		if ($line =~ /<clusternode.*?name="(.*?)"/)
		{
			   $this_host_name  =  $1;
			my $short_host_name =  $this_host_name;
			   $short_host_name =~ s/\..*$//;
			my $short_node_name =  $node_name;
			   $short_node_name =~ s/\..*$//;
			   
			# If I need to record the host name from cluster.conf, do so here.
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "short host name",                                value1 => $short_host_name,
				name2 => "short node name",                                value2 => $short_node_name,
				name3 => "node::${node_name}::get_host_from_cluster_conf", value3 => $an->data->{node}{$node_name}{get_host_from_cluster_conf},
			}, file => $THIS_FILE, line => __LINE__});
			if ($short_host_name eq $short_node_name)
			{
				# Found it.
				if ($an->data->{node}{$node_name}{get_host_from_cluster_conf})
				{
					$an->data->{node}{$node_name}{info}{host_name}            = $this_host_name;
					$an->data->{node}{$node_name}{info}{short_host_name}      = $short_host_name;
					$an->data->{node}{$node_name}{get_host_from_cluster_conf} = 0;
				}
				$this_node = $node_name;
			}
			else
			{
				$this_node = $an->Cman->peer_hostname({node => $node_name});
				if (not $an->data->{node}{$this_node}{host_name})
				{
					$an->data->{node}{$this_node}{info}{host_name}       = $this_host_name;
					$an->data->{node}{$this_node}{info}{short_host_name} = $short_host_name;
				}
			}
			
			# Mark that I am in a node child element.
			$in_node = $node_name;
		}
		if ($line =~ /<\/clusternode>/)
		{
			# Record my fence findings.
			$in_node        = "";
			$this_node      = "";
			$method_counter = 0;
		}
		
		if (($in_node) && ($line =~ /<fence>/))
		{
			$in_fence = 1;
		}
		if ($line =~ /<\/fence>/)
		{
			$in_fence = 0;
		}
		if (($in_fence) && ($line =~ /<method.*name="(.*?)"/))
		{
			# The method counter ensures ordered use of the fence devices.
			$in_method = "$method_counter:$1";
			$method_counter++;
		}
		if ($line =~ /<\/method>/)
		{
			$in_method    = "";
			$device_count = 0;
		}
		if (($in_method) && ($line =~ /<device\s/))
		{
			my $name            = $line =~ /name="(.*?)"/          ? $1 : "";
			my $port            = $line =~ /port="(.*?)"/          ? $1 : "";
			my $action          = $line =~ /action="(.*?)"/        ? $1 : "";
			my $address         = $line =~ /ipaddr="(.*?)"/        ? $1 : "";
			my $login           = $line =~ /login="(.*?)"/         ? $1 : "";
			my $password        = $line =~ /passwd="(.*?)"/        ? $1 : "";
			my $password_script = $line =~ /passwd_script="(.*?)"/ ? $1 : "";
			$an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{name}            = $name;
			$an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{port}            = $port;
			$an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{action}          = $action;
			$an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{address}         = $address;
			$an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{login}           = $login;
			$an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{password}        = $password;
			$an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{password_script} = $password_script;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
				name1 => "node::${this_node}::fence::method::${in_method}::device::${device_count}::name",    value1 => $an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{name},
				name2 => "node::${this_node}::fence::method::${in_method}::device::${device_count}::port",    value2 => $an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{port},
				name3 => "node::${this_node}::fence::method::${in_method}::device::${device_count}::action",  value3 => $an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{action},
				name4 => "node::${this_node}::fence::method::${in_method}::device::${device_count}::address", value4 => $an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{address},
				name5 => "node::${this_node}::fence::method::${in_method}::device::${device_count}::login",   value5 => $an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{login},
				name6 => "password_script",                                                                   value6 => $password_script,
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${this_node}::fence::method::${in_method}::device::${device_count}::password", value1 => $an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{password},
			}, file => $THIS_FILE, line => __LINE__});
			$device_count++;
		}
		
		# Parse out the fence device details.
		if ($line =~ /<fencedevices>/)
		{
			$in_fence_device = 1;
		}
		if ($line =~ /<\/fencedevices>/)
		{
			$in_fence_device = 0;
		}
		# This could be duplicated, but I don't care as cluster.conf has to be the same on both 
		# nodes, anyway.
		if ($in_fence_device)
		{
			my $name            = $line =~ /name="(.*?)"/          ? $1 : "";
			my $agent           = $line =~ /agent="(.*?)"/         ? $1 : "";
			my $action          = $line =~ /action="(.*?)"/        ? $1 : "";
			my $address         = $line =~ /ipaddr="(.*?)"/        ? $1 : "";
			my $login           = $line =~ /login="(.*?)"/         ? $1 : "";
			my $password        = $line =~ /passwd="(.*?)"/        ? $1 : "";
			my $password_script = $line =~ /passwd_script="(.*?)"/ ? $1 : "";
			# If the password has a single-quote, ricci changes it to &apos;. We need to change it back.
			$password =~ s/&apos;/'/g;
			$an->data->{fence}{$name}{agent}           = $agent;
			$an->data->{fence}{$name}{action}          = $action;
			$an->data->{fence}{$name}{address}         = $address;
			$an->data->{fence}{$name}{login}           = $login;
			$an->data->{fence}{$name}{password}        = $password;
			$an->data->{fence}{$name}{password_script} = $password_script;
			$an->Log->entry({log_level => 4, message_key => "an_variables_0007", message_variables => {
				name1 => "node_name",       value1 => $node_name,
				name2 => "agent",           value2 => $an->data->{fence}{$name}{agent},
				name3 => "address",         value3 => $an->data->{fence}{$name}{address},
				name4 => "login",           value4 => $an->data->{fence}{$name}{login},
				name5 => "password",        value5 => $an->data->{fence}{$name}{password},
				name6 => "action",          value6 => $an->data->{fence}{$name}{action},
				name7 => "password_script", value7 => $an->data->{fence}{$name}{password_script},
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Find servers.
		if ($line =~ /<vm.*?name="(.*?)"/)
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "node_name", value1 => $node_name,
				name2 => "line",      value2 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			my $server     = $1;
			my $server_key = $server;
			my $definition = ($line =~ /path="(.*?)"/)[0].$server.".xml";
			my $domain     = ($line =~ /domain="(.*?)"/)[0];
			# I need to set the host to 'none' to avoid triggering the error caused by seeing and
			# foo.xml server definition outside of here.
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "server_key", value1 => $server_key,
				name2 => "definition", value2 => $definition,
				name3 => "domain",     value3 => $domain,
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{server}{$server_key}{definition_file} = $definition;
			$an->data->{server}{$server_key}{failover_domain} = $domain;
			$an->data->{server}{$server_key}{host}            = "none" if not $an->data->{server}{$server_key}{host};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
				name1 => "node_name",  value1 => $node_name,
				name2 => "server_key", value2 => $server_key,
				name3 => "definition", value3 => $an->data->{server}{$server_key}{definition_file},
				name4 => "host",       value4 => $an->data->{server}{$server_key}{host},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# See if I got the fence details for both nodes.
	my $peer = $an->Cman->peer_hostname({node => $node_name});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name", value1 => $node_name,
		name2 => "peer",      value2 => $peer,
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $this_node ($node_name, $peer)
	{
		# This will contain possible fence methods.
		$an->data->{node}{$this_node}{info}{fence_methods} = "";
		
		# This will contain the command needed to check the node's power.
		$an->data->{node}{$this_node}{info}{power_check_command} = "";
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "this_node", value1 => $this_node,
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $in_method (sort {$a cmp $b} keys %{$an->data->{node}{$this_node}{fence}{method}})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "this_node", value1 => $this_node,
				name2 => "in_method", value2 => $in_method,
			}, file => $THIS_FILE, line => __LINE__});
			my $fence_command = "$in_method: ";
			foreach my $device_count (sort {$a cmp $b} keys %{$an->data->{node}{$this_node}{fence}{method}{$in_method}{device}})
			{
				#$fence_command .= " [$device_count]";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "node::${this_node}::fence::method::${in_method}::device::${device_count}::name",   value1 => $an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{name},
					name2 => "node::${this_node}::fence::method::${in_method}::device::${device_count}::port",   value2 => $an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{port},
					name3 => "node::${this_node}::fence::method::${in_method}::device::${device_count}::action", value3 => $an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{action},
				}, file => $THIS_FILE, line => __LINE__});
				#Find the matching fence device entry.
				foreach my $name (sort {$a cmp $b} keys %{$an->data->{fence}})
				{
					if ($name eq $an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{name})
					{
						my $agent           = $an->data->{fence}{$name}{agent};
						my $address         = $an->data->{fence}{$name}{address};
						my $login           = $an->data->{fence}{$name}{login};
						my $password        = $an->data->{fence}{$name}{password};
						my $password_script = $an->data->{fence}{$name}{password_script};
						my $port            = $an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{port};
						
						# See if we need to use values from the per-node definitions.
						# These override the general fence device configs if needed.
						if ($an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{address})
						{
							$address = $an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{address};
						}
						if ($an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{login})
						{
							$login = $an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{login};
						}
						if ($an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{password})
						{
							$password = $an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{password};
						}
						if ($an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{password_script})
						{
							$password_script = $an->data->{node}{$this_node}{fence}{method}{$in_method}{device}{$device_count}{password_script};
						}
						
						# If we have a password script but no password, we need to 
						# call the script and record the output because we probably 
						# don't have the script on the dashboard.
						if (($password_script) && (not $password))
						{
							# Convert the script to a password.
							my $shell_call = $password_script;
							$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
								name1 => "target",     value1 => $target,
								name2 => "shell_call", value2 => $shell_call,
							}, file => $THIS_FILE, line => __LINE__});
							my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
								target		=>	$target,
								port		=>	$port, 
								password	=>	$password,
								shell_call	=>	$shell_call,
							});
							foreach my $line (@{$return})
							{
								$password = $line;
								$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
									name1 => "password", value1 => $password, 
								}, file => $THIS_FILE, line => __LINE__});
								last;
							}
						}
						
						my $command  = "$agent -a $address ";
						   $command .= "-l $login "           if $login;
						   $command .= "-p \"$password\" "    if $password; # quote the password in case it has spaces in it.
						   $command .= "-n $port "            if $port;
						   $command =~ s/ $//;
						$an->data->{node}{$this_node}{fence_method}{$in_method}{device}{$device_count}{command} = $command;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "node::${this_node}::fence_method::${in_method}::device::${device_count}::command", value1 => $an->data->{node}{$this_node}{fence_method}{$in_method}{device}{$device_count}{command},
						}, file => $THIS_FILE, line => __LINE__});
						if (($agent eq "fence_ipmilan") or ($agent eq "fence_virsh"))
						{
							$an->data->{node}{$this_node}{info}{power_check_command} = $command;
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => "node::${this_node}::info::power_check_command", value1 => $an->data->{node}{$this_node}{info}{power_check_command},
							}, file => $THIS_FILE, line => __LINE__});
						}
						$fence_command .= "$command -o #!action!#; ";
					}
				}
			}
			
			# Record the fence command.
			$fence_command =~ s/ $//;
			if ($node_name eq $this_node)
			{
				$an->data->{node}{$node_name}{info}{fence_methods} .= $fence_command;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node_name}::info::fence_methods", value1 => $an->data->{node}{$node_name}{info}{fence_methods},
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				$an->data->{node}{$peer}{info}{fence_methods} .= $fence_command;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "node", value1 => $this_node,
					name2 => "peer", value2 => $peer,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		$an->data->{node}{$this_node}{info}{fence_methods} =~ s/\s+$//;
	}
	### NOTE: These expose passwords!
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node_name}::info::fence_methods", value1 => $an->data->{node}{$node_name}{info}{fence_methods},
		name2 => "node::${peer}::info::fence_methods",      value2 => $an->data->{node}{$peer}{info}{fence_methods},
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: Make sure this works
	if ($an->data->{sys}{node_name}{$node_name}{uuid})
	{
		$an->ScanCore->insert_or_update_nodes_cache({
			node_cache_host_uuid	=>	$an->data->{sys}{host_uuid},
			node_cache_node_uuid	=>	$an->data->{sys}{node_name}{$node_name}{uuid}, 
			node_cache_name		=>	"power_check",
			node_cache_data		=>	$an->data->{node}{$node_name}{info}{fence_methods},
		});
	}
	
	return(0);
}

### TODO: timeout is now used here. Verify we handle it properly. Check for the line 'clustat:(\d+)'. If it 
###       is 124, timeout fired.
# Parse the cluster status.
sub _parse_clustat
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_parse_clustat" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $data       = $parameter->{data};
	
	# Setup some variables.
	my $in_member  = 0;
	my $in_service = 0;
	my $line_num   = 0;
	
	# Default is 'unknown'
	my $host_name                                                = $an->String->get({key => "state_0001"});
	my $storage_name                                             = $an->String->get({key => "state_0001"});
	my $storage_state                                            = $an->String->get({key => "state_0001"});
	   $an->data->{node}{$node_name}{me}{cman}                   = 0;
	   $an->data->{node}{$node_name}{me}{rgmanager}              = 0;
	   $an->data->{node}{$node_name}{peer}{cman}                 = 0;
	   $an->data->{node}{$node_name}{peer}{rgmanager}            = 0;
	   $an->data->{node}{$node_name}{enable_join}                = 0;
	   $an->data->{node}{$node_name}{get_host_from_cluster_conf} = 0;

	### NOTE: This check seems odd, but I've run intp cases where a node, otherwise behaving fine, simple
	###       returns nothing when cman is off. Couldn't reproduce on the command line.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "node_name", value1 => $node_name,
	}, file => $THIS_FILE, line => __LINE__});
	my $line_count = @{$data};
	if (not $line_count)
	{
		# CMAN isn't running.
		$an->Log->entry({log_level => 3, message_key => "log_0022", message_variables => { node => $node_name }, file => $THIS_FILE, line => __LINE__});
		$an->data->{node}{$node_name}{get_host_from_cluster_conf} = 1;
		$an->data->{node}{$node_name}{enable_join}                = 1;
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "line_count", value1 => $line_count,
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $line (@{$data})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		if ($line =~ /clustat:(\d+)/)
		{
			### TODO: If this is 124, make sure sane null values are set because timeout fired.
			my $return_code = $1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
			next;
		}
		
		if ($line =~ /Could not connect to CMAN/i)
		{
			# CMAN isn't running.
			$an->Log->entry({log_level => 2, message_key => "log_0022", message_variables => { node => $node_name }, file => $THIS_FILE, line => __LINE__});
			$an->data->{node}{$node_name}{get_host_from_cluster_conf} = 1;
			$an->data->{node}{$node_name}{enable_join}                = 1;
		}
		next if not $line;
		next if $line =~ /^-/;
		
		if ($line =~ /^Member Name/)
		{
			$in_member  = 1;
			$in_service = 0;
			next;
		}
		elsif ($line =~ /^Service Name/)
		{
			$in_member  = 0;
			$in_service = 1;
			next;
		}
		if ($in_member)
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /Local/)
			{
				($an->data->{node}{$node_name}{me}{name}, undef, my $services) = (split/ /, $line, 3);
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node_name}::me::name", value1 => $an->data->{node}{$node_name}{me}{name},
				}, file => $THIS_FILE, line => __LINE__});
				$services =~ s/local//;
				$services =~ s/ //g;
				$services =~ s/,,/,/g;
				$an->data->{node}{$node_name}{me}{cman}      =  1 if $services =~ /Online/;
				$an->data->{node}{$node_name}{me}{rgmanager} =  1 if $services =~ /rgmanager/;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name2 => "node::${node_name}::me::name", value1 => $an->data->{node}{$node_name}{me}{name},
					name3 => "node::${node_name}::me::cman", value2 => $an->data->{node}{$node_name}{me}{cman},
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				($an->data->{node}{$node_name}{peer}{name}, undef, my $services) = split/ /, $line, 3;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node_name}::peer::name", value2 => $an->data->{node}{$node_name}{peer}{name}, 
				}, file => $THIS_FILE, line => __LINE__});
				$services =~ s/ //g;
				$services =~ s/,,/,/g;
				$an->data->{node}{peer}{cman}      = 1 if $services =~ /Online/;
				$an->data->{node}{peer}{rgmanager} = 1 if $services =~ /rgmanager/;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "node::${node_name}::peer::name", value1 => $an->data->{node}{$node_name}{peer}{name}, 
					name2 => "node::peer::cman",               value2 => $an->data->{node}{peer}{cman}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		elsif ($in_service)
		{
			if ($line =~ /^vm:/)
			{
				my ($server, $host, $state) = split/ /, $line, 3;
				$server =~ s/^vm://;
				$host   =~ s/^\((.*?)\)$/$1/g;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "server", value1 => $server,
					name2 => "host",   value2 => $host,
					name3 => "state",  value3 => $state,
				}, file => $THIS_FILE, line => __LINE__});
				if (($state eq "disabled") or ($state eq "stopped"))
				{
					# Set host to 'none'.
					$host = $an->String->get({key => "state_0002"});
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "host", value1 => $host,
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($state eq "failed")
				{
					# Don't do anything here now, it is possible the server is still 
					# running. Set the host to 'Unknown' and let the user decide what to 
					# do. This can happen if, for example, the XML file is temporarily
					# removed or corrupted.
					$host = $an->String->get({key => "state_0001", variables => { host => $host }});
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "host", value1 => $host,
					}, file => $THIS_FILE, line => __LINE__});
				}
				
				# If the service is disabled, it will have '()' around the host name which I 
				# need to remove.
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "server", value1 => $server,
					name2 => "host",   value2 => $host,
				}, file => $THIS_FILE, line => __LINE__});
				
				$host                                 = "none" if not $host;
				$an->data->{server}{$server}{host}    = $host;
				$an->data->{server}{$server}{'state'} = $state;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "server::${server}::host",  value1 => $an->data->{server}{$server}{host},
					name2 => "server::${server}::state", value2 => $an->data->{server}{$server}{'state'},
				}, file => $THIS_FILE, line => __LINE__});
				
				# Pick out who the peer node is.
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "host",                         value1 => $host,
					name2 => "node::${node_name}::me::name", value2 => $an->data->{node}{$node_name}{me}{name},
				}, file => $THIS_FILE, line => __LINE__});
				if ($host eq $an->data->{node}{$node_name}{me}{name})
				{
					$an->data->{server}{$server}{peer} = $an->data->{node}{$node_name}{peer}{name};
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "node_name",               value1 => $node_name,
						name2 => "server::${server}::peer", value2 => $an->data->{server}{$server}{peer},
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					$an->data->{server}{$server}{peer} = $an->data->{node}{$node_name}{me}{name};
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "node_name",               value1 => $node_name,
						name2 => "server::${server}::peer", value2 => $an->data->{server}{$server}{peer},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($line =~ /^service:(.*?)\s+(.*?)\s+(.*)$/)
			{
				my $name  = $1;
				my $host  = $2;
				my $state = $3;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "name",  value1 => $name,
					name2 => "host",  value2 => $host,
					name3 => "state", value3 => $state,
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($state eq "failed")
				{
					# Disable the service.
					my $shell_call = $an->data->{path}{clusvcadm}." -d service:$name";
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "target",     value1 => $target,
						name2 => "shell_call", value2 => $shell_call,
					}, file => $THIS_FILE, line => __LINE__});
					my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
						target		=>	$target,
						port		=>	$port, 
						password	=>	$password,
						shell_call	=>	$shell_call,
					});
					foreach my $line (@{$return})
					{
						$line =~ s/^\s+//;
						$line =~ s/\s+$//;
						$line =~ s/\s+/ /g;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line, 
						}, file => $THIS_FILE, line => __LINE__});
					}
					
					### TODO: This will hang if DLM is hung.
					# Sleep for a short bit and the start the service back up.
					sleep 5;
					$shell_call = $an->data->{path}{clusvcadm}." -e service:$name";
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "target",     value1 => $target,
						name2 => "shell_call", value2 => $shell_call,
					}, file => $THIS_FILE, line => __LINE__});
					($error, $ssh_fh, $return) = $an->Remote->remote_call({
						target		=>	$target,
						port		=>	$port, 
						password	=>	$password,
						shell_call	=>	$shell_call,
					});
					foreach my $line (@{$return})
					{
						$line =~ s/^\s+//;
						$line =~ s/\s+$//;
						$line =~ s/\s+/ /g;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				
				# If the service is disabled, it will have '()' which I need to remove.
				$host =~ s/\(//g;
				$host =~ s/\)//g;
				
				$an->data->{service}{$name}{host}    = $host;
				$an->data->{service}{$name}{'state'} = $state;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "service::${name}::host",  value1 => $an->data->{service}{$name}{host}, 
					name2 => "service::${name}::state", value2 => $an->data->{service}{$name}{'state'}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# If this is set, the Anvil! isn't running.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "node::${node_name}::get_host_from_cluster_conf", value1 => $an->data->{node}{$node_name}{get_host_from_cluster_conf},
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->data->{node}{$node_name}{get_host_from_cluster_conf})
	{
		$host_name = $an->data->{node}{$node_name}{me}{name};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "node_name", value1 => $node_name,
			name2 => "host_name", value2 => $host_name,
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $name (sort {$a cmp $b} keys %{$an->data->{service}})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "node_name", value1 => $node_name, 
				name2 => "name",      value2 => $name,
			}, file => $THIS_FILE, line => __LINE__});
			next if $an->data->{service}{$name}{host} ne $host_name;
			next if $name !~ /storage/;
			$storage_name  = $name;
			$storage_state = $an->data->{service}{$name}{'state'};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "node_name",    value1 => $node_name,
				name2 => "storage_name", value2 => $storage_name,
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "node_name", value1 => $node_name,
			name2 => "host name", value2 => $host_name,
		}, file => $THIS_FILE, line => __LINE__});
		if ($host_name)
		{
			$an->data->{node}{$node_name}{info}{host_name}            =  $host_name;
			$an->data->{node}{$node_name}{info}{short_host_name}      =  $host_name;
			$an->data->{node}{$node_name}{info}{short_host_name}      =~ s/\..*$//;
			$an->data->{node}{$node_name}{get_host_from_cluster_conf} = 0;
		}
		else
		{
			$an->data->{node}{$node_name}{get_host_from_cluster_conf} = 1;
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node_name}::get_host_from_cluster_conf", value1 => $node_name,
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->data->{node}{$node_name}{info}{storage_name}  = $storage_name;
		$an->data->{node}{$node_name}{info}{storage_state} = $storage_state;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node_name}::info::host_name", value1 => $an->data->{node}{$node_name}{info}{host_name},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return(0);
}

### TODO: timeout is now used here. Verify we handle it properly. If any daemons return 124, timeout fired.
# Parse the daemon statuses.
sub _parse_daemons
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_parse_daemons" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $data       = $parameter->{data};
	
	# If all daemons are down, record here that I can shut down this server. If any are up, enable 
	# withdrawl.
	$an->data->{node}{$node_name}{enable_poweroff} = 1;
	$an->data->{node}{$node_name}{enable_withdraw} = 0;
	
	# I need to pre-set the services as stopped because the little hack I have below doesn't echo when a
	# service isn't running.
	$an->Log->entry({log_level => 3, message_key => "log_0024", file => $THIS_FILE, line => __LINE__});
	foreach my $daemon ("cman", "rgmanager", "drbd", "clvmd", "gfs2", "libvirtd")
	{
		$an->data->{node}{$node_name}{daemon}{$daemon}{status}    = "<span class=\"highlight_bad\">#!string!an_state_0002!#</span>";
		$an->data->{node}{$node_name}{daemon}{$daemon}{exit_code} = "";
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "node_name", value1 => $node_name,
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $line (@{$data})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		next if $line !~ /^striker:/;
		my ($daemon, $exit_code) = ($line =~ /^.*?:(.*?):(.*?)$/);
		   $exit_code            = "" if not defined $exit_code;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node_name", value1 => $node_name,
			name2 => "daemon",    value2 => $daemon,
			name3 => "exit_code", value3 => $exit_code,
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($exit_code eq "0")
		{
			# Running
			$an->data->{node}{$node_name}{daemon}{$daemon}{status} = "<span class=\"highlight_good\">#!string!an_state_0003!#</span>";
			$an->data->{node}{$node_name}{enable_poweroff}         = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "node::${node_name}::daemon::${daemon}::status", value1 => $an->data->{node}{$node_name}{daemon}{$daemon}{status},
				name2 => "node::${node_name}::enable_poweroff",           value2 => $an->data->{node}{$node_name}{enable_poweroff},
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		$an->data->{node}{$node_name}{daemon}{$daemon}{exit_code} = $exit_code;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node_name}::daemon::${daemon}::exit_code", value1 => $an->data->{node}{$node_name}{daemon}{$daemon}{exit_code},
			name2 => "node::${node_name}::daemon::${daemon}::status",    value2 => $an->data->{node}{$node_name}{daemon}{$daemon}{status},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# If cman is running, enable withdrawl. If not, enable shut down.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "node::${node_name}::daemon::cman::exit_code", value1 => $an->data->{node}{$node_name}{daemon}{cman}{exit_code},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{node}{$node_name}{daemon}{cman}{exit_code} eq "0")
	{
		$an->data->{node}{$node_name}{enable_withdraw} = 1;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node_name}::enable_withdraw", value1 => $an->data->{node}{$node_name}{enable_withdraw},
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# If something went wrong, one of the storage resources might still be running.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "node::${node_name}::daemon::rgmanager::exit_code", value1 => $an->data->{node}{$node_name}{daemon}{rgmanager}{exit_code},
			name2 => "node::${node_name}::daemon::drbd::exit_code",      value2 => $an->data->{node}{$node_name}{daemon}{drbd}{exit_code},
			name3 => "node::${node_name}::daemon::clvmd::exit_code",     value3 => $an->data->{node}{$node_name}{daemon}{clvmd}{exit_code},
			name4 => "node::${node_name}::daemon::gfs2::exit_code",      value4 => $an->data->{node}{$node_name}{daemon}{gfs2}{exit_code},
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{node}{$node_name}{daemon}{rgmanager}{exit_code} eq "0") or
		    ($an->data->{node}{$node_name}{daemon}{drbd}{exit_code}      eq "0") or
		    ($an->data->{node}{$node_name}{daemon}{clvmd}{exit_code}     eq "0") or
		    ($an->data->{node}{$node_name}{daemon}{gfs2}{exit_code}      eq "0"))
		{
			# This can happen if the user loads the page (or it auto-loads) while the storage is 
			# coming online.
			#my $message = $an->String->get({key => "message_0044", variables => { node => $node }});
			#$an->Striker->_error({message => $message}); 
		}
		else
		{
			# Ready to power off the node, if I was actually able to connect to the node.
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node_name}::connected", value1 => $an->data->{node}{$node_name}{connected},
			}, file => $THIS_FILE, line => __LINE__});
			if ($an->data->{node}{$node_name}{connected})
			{
				$an->data->{node}{$node_name}{enable_poweroff} = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node_name}::enable_poweroff", value1 => $an->data->{node}{$node_name}{enable_poweroff},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node_name}::enable_poweroff", value1 => $an->data->{node}{$node_name}{enable_poweroff},
		name2 => "node::${node_name}::enable_withdraw", value2 => $an->data->{node}{$node_name}{enable_withdraw},
	}, file => $THIS_FILE, line => __LINE__});
	
	return(0);
}

# This reads the DRBD resource details from the resource definition files.
sub _parse_drbdadm_dumpxml
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_parse_drbdadm_dumpxml" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $data       = $parameter->{data};
	
	# Some variables we will fill later.
	my $xml_data  = "";
	
	# Convert the XML array into a string.
	foreach my $line (@{$data})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		$xml_data .= "$line\n";
	}
	
	# Now feed the string into XML::Simple.
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
		
		foreach my $a (keys %{$data})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "a", value1 => $a,
			}, file => $THIS_FILE, line => __LINE__});
			if ($a eq "file")
			{
				# This is just "/dev/drbd.conf", not needed.
			}
			elsif ($a eq "common")
			{
				$an->data->{node}{$node_name}{drbd}{protocol} = $data->{common}->[0]->{protocol};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "common",                             value1 => $data->{common}->[0],
					name2 => "node::${node_name}::drbd::protocol", value2 => $an->data->{node}{$node_name}{drbd}{protocol},
				}, file => $THIS_FILE, line => __LINE__});
				foreach my $b (@{$data->{common}->[0]->{section}})
				{
					my $name = $b->{name};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "b",    value1 => $b,
						name2 => "name", value2 => $name,
					}, file => $THIS_FILE, line => __LINE__});
					if ($name eq "handlers")
					{
						$an->data->{node}{$node_name}{drbd}{fence}{handler}{name} = $b->{option}->[0]->{name};
						$an->data->{node}{$node_name}{drbd}{fence}{handler}{path} = $b->{option}->[0]->{value};
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "node::${node_name}::drbd::fence::handler::name", value1 => $an->data->{node}{$node_name}{drbd}{fence}{handler}{name},
							name2 => "node::${node_name}::drbd::fence::handler::path", value2 => $an->data->{node}{$node_name}{drbd}{fence}{handler}{path},
						}, file => $THIS_FILE, line => __LINE__});
					}
					elsif ($name eq "disk")
					{
						$an->data->{node}{$node_name}{drbd}{fence}{policy} = $b->{option}->[0]->{value};
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "node::${node_name}::drbd::fence::policy", value1 => $an->data->{node}{$node_name}{drbd}{fence}{policy},
						}, file => $THIS_FILE, line => __LINE__});
					}
					elsif ($name eq "syncer")
					{
						$an->data->{node}{$node_name}{drbd}{syncer}{rate} = $b->{option}->[0]->{value};
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "node::${node_name}::drbd::syncer::rate", value1 => $an->data->{node}{$node_name}{drbd}{syncer}{rate},
						}, file => $THIS_FILE, line => __LINE__});
					}
					elsif ($name eq "startup")
					{
						foreach my $c (@{$b->{option}})
						{
							my $name  = $c->{name};
							my $value = $c->{value} ? $c->{value} : "--";
							$an->data->{node}{$node_name}{drbd}{startup}{$name} = $value;
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => "node::${node_name}::drbd::startup::${name}", value1 => $an->data->{node}{$node_name}{drbd}{startup}{$name},
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
					elsif ($name eq "net")
					{
						foreach my $c (@{$b->{option}})
						{
							my $name  = $c->{name};
							my $value = $c->{value} ? $c->{value} : "--";
							$an->data->{node}{$node_name}{drbd}{net}{$name} = $value;
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => "node::${node_name}::drbd::net::${name}", value1 => $an->data->{node}{$node_name}{drbd}{net}{$name},
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
					elsif ($name eq "options")
					{
						foreach my $c (@{$b->{option}})
						{
							my $name  = $c->{name};
							my $value = $c->{value} ? $c->{value} : "--";
							$an->data->{node}{$node_name}{drbd}{options}{$name} = $value;
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => "node::${node_name}::drbd::options::$name", value1 => $an->data->{node}{$node_name}{drbd}{options}{$name},
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
					else
					{
						# Unexpected element
						$an->Log->entry({log_level => 2, message_key => "log_0021", message_variables => {
							element     => $b, 
							node        => $node_name, 
							source_data => $an->data->{path}{drbdadm}." dump-xml", 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
			}
			elsif ($a eq "resource")
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "node_name",        value1 => $node_name,
					name2 => "data->{resource}", value2 => $data->{resource},
				}, file => $THIS_FILE, line => __LINE__});
				foreach my $b (@{$data->{resource}})
				{
					my $resource = $b->{name};
					foreach my $c (@{$b->{host}})
					{
						my $ip_type        = $c->{address}->[0]->{family};
						my $ip_address     = $c->{address}->[0]->{content};
						my $tcp_port       = $c->{address}->[0]->{port};
						my $hostname       = $c->{name};
						my $metadisk       = $c->{volume}->[0]->{'meta-disk'}->[0];
						my $minor_number   = $c->{volume}->[0]->{device}->[0]->{minor};
						### TODO: Why are these the same?
						my $drbd_device    = $c->{volume}->[0]->{device}->[0]->{content};
						my $backing_device = $c->{volume}->[0]->{device}->[0]->{content};
						
						# This is used for locating a resource by its minor number
						$an->data->{node}{$node_name}{drbd}{minor_number}{$minor_number}{resource} = $resource;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "node::${node_name}::drbd::minor_number::${minor_number}::resource", value1 => $an->data->{node}{$node_name}{drbd}{minor_number}{$minor_number}{resource},
						}, file => $THIS_FILE, line => __LINE__});
						
						# This is where the data itself is stored.
						$an->data->{node}{$node_name}{drbd}{resource}{$resource}{metadisk}       = $metadisk;
						$an->data->{node}{$node_name}{drbd}{resource}{$resource}{minor_number}   = $minor_number;
						$an->data->{node}{$node_name}{drbd}{resource}{$resource}{drbd_device}    = $drbd_device;
						$an->data->{node}{$node_name}{drbd}{resource}{$resource}{backing_device} = $backing_device;
						$an->data->{node}{$node_name}{drbd}{resource}{$resource}{connection_state} = "--";
						$an->data->{node}{$node_name}{drbd}{resource}{$resource}{role}             = "--";
						$an->data->{node}{$node_name}{drbd}{resource}{$resource}{disk_state}       = "--";
						
						# These entries are per-host.
						$an->data->{node}{$node_name}{drbd}{resource}{$resource}{hostname}{$hostname}{ip_address} = $ip_address;
						$an->data->{node}{$node_name}{drbd}{resource}{$resource}{hostname}{$hostname}{ip_type}    = $ip_type;
						$an->data->{node}{$node_name}{drbd}{resource}{$resource}{hostname}{$hostname}{tcp_port}   = $tcp_port;
						
						# These are needed for the display.
						$an->data->{node}{$node_name}{drbd}{res_file}{$resource}{device}           = $an->data->{node}{$node_name}{drbd}{resource}{$resource}{drbd_device};
						$an->data->{drbd}{$resource}{node}{$node_name}{res_file}{device}           = $an->data->{node}{$node_name}{drbd}{resource}{$resource}{drbd_device};
						$an->data->{drbd}{$resource}{node}{$node_name}{res_file}{connection_state} = "--";
						$an->data->{drbd}{$resource}{node}{$node_name}{res_file}{role}             = "--";
						$an->data->{drbd}{$resource}{node}{$node_name}{res_file}{disk_state}       = "--";
						$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
							name1 => "node::${node_name}::drbd::resource::${resource}::metadisk",                          value1 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{metadisk},
							name2 => "node::${node_name}::drbd::resource::${resource}::minor_number",                      value2 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{minor_number},
							name3 => "node::${node_name}::drbd::resource::${resource}::drbd_device",                       value3 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{drbd_device},
							name4 => "node::${node_name}::drbd::resource::${resource}::backing_device",                    value4 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{backing_device},
							name5 => "node::${node_name}::drbd::resource::${resource}::hostname::${hostname}::ip_address", value5 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{hostname}{$hostname}{ip_address},
							name6 => "node::${node_name}::drbd::resource::${resource}::hostname::${hostname}::tcp_port",   value6 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{hostname}{$hostname}{tcp_port},
							name7 => "node::${node_name}::drbd::resource::${resource}::hostname::${hostname}::ip_type",    value7 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{hostname}{$hostname}{ip_type},
						}, file => $THIS_FILE, line => __LINE__});
					}
					foreach my $c (@{$b->{section}})
					{
						my $name = $c->{name};
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "c",    value1 => $c,
							name2 => "name", value2 => $name,
						}, file => $THIS_FILE, line => __LINE__});
						if ($name eq "disk")
						{
							foreach my $d (@{$c->{options}})
							{
								my $name  = $d->{name};
								my $value = $d->{value};
								$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
									name1 => "d",     value1 => $d,
									name2 => "name",  value2 => $name,
									name3 => "value", value3 => $value,
								}, file => $THIS_FILE, line => __LINE__});
								$an->data->{node}{$node_name}{drbd}{res_file}{$resource}{disk}{$name} = $value;
							}
						}
					}
				}
			}
			else
			{
				$an->Log->entry({log_level => 2, message_key => "log_0021", message_variables => {
					element     => $a, 
					node        => $node_name, 
					source_data => $an->data->{path}{drbdadm}." dump-xml", 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return(0);
}

# Parse the dmidecode data.
sub _parse_dmidecode
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_parse_dmidecode" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $data       = $parameter->{data};
	
	# Some variables I will need.
	my $in_cpu           = 0;
	my $in_system_ram    = 0;
	my $in_dimm_module   = 0;
	
	# On SMP machines, the CPU socket becomes important. This tracks which CPU I am looking at.
	my $this_socket      = "";
	
	# Same deal with volume groups.
	my $this_vg          = "";
	
	# RAM is all over the place, so I need to record all the bits in strings and push to the hash when I
	# see a blank line.
	my $dimm_locator     = "";
	my $dimm_bank        = "";
	my $dimm_size        = "";
	my $dimm_type        = "";
	my $dimm_speed       = "";
	my $dimm_form_factor = "";
	
	# This will be set to the values I find on this node.
	$an->data->{node}{$node_name}{hardware}{total_node_cores}   = 0;
	$an->data->{node}{$node_name}{hardware}{total_node_threads} = 0;
	$an->data->{node}{$node_name}{hardware}{total_memory}       = 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "node::${node_name}::hardware::total_node_cores",   value1 => $an->data->{node}{$node_name}{hardware}{total_node_cores},
		name2 => "node::${node_name}::hardware::total_node_threads", value2 => $an->data->{node}{$node_name}{hardware}{total_node_threads},
		name3 => "node::${node_name}::hardware::total_memory",       value3 => $an->data->{node}{$node_name}{hardware}{total_memory},
	}, file => $THIS_FILE, line => __LINE__});
	
	# These will be set to the lowest available RAM, and CPU core available.
	$an->data->{resources}{total_cores}   = 0;
	$an->data->{resources}{total_threads} = 0;
	$an->data->{resources}{total_ram}     = 0;
	# In some cases, like in servers, the CPU core count is not provided. So this keeps a running tally 
	# of how many times we've gone in and out of 'in_cpu' and will be used as the core count if, when 
	# it is all done, we have 0 cores listed.
	$an->data->{resources}{total_cpus} = 0;
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "resources::total_cores",   value1 => $an->data->{resources}{total_cores},
		name2 => "resources::total_threads", value2 => $an->data->{resources}{total_threads},
		name3 => "resources::total_memory",  value3 => $an->data->{resources}{total_ram},
	}, file => $THIS_FILE, line => __LINE__});
	
	foreach my $line (@{$data})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		# Find out what I am looking at.
		if (not $line)
		{
			# Blank lines break sections. If I had been reading DIMM info, push it into the hash.
			if ($in_dimm_module)
			{
				$an->data->{node}{$node_name}{hardware}{dimm}{$dimm_locator}{bank}        = $dimm_bank;
				$an->data->{node}{$node_name}{hardware}{dimm}{$dimm_locator}{size}        = $dimm_size;
				$an->data->{node}{$node_name}{hardware}{dimm}{$dimm_locator}{type}        = $dimm_type;
				$an->data->{node}{$node_name}{hardware}{dimm}{$dimm_locator}{speed}       = $dimm_speed;
				$an->data->{node}{$node_name}{hardware}{dimm}{$dimm_locator}{form_factor} = $dimm_form_factor;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "node::${node_name}::hardware::dimm::${dimm_locator}::bank",        value1 => $an->data->{node}{$node_name}{hardware}{dimm}{$dimm_locator}{bank},
					name2 => "node::${node_name}::hardware::dimm::${dimm_locator}::size",        value2 => $an->data->{node}{$node_name}{hardware}{dimm}{$dimm_locator}{size},
					name3 => "node::${node_name}::hardware::dimm::${dimm_locator}::type",        value3 => $an->data->{node}{$node_name}{hardware}{dimm}{$dimm_locator}{type},
					name4 => "node::${node_name}::hardware::dimm::${dimm_locator}::speed",       value4 => $an->data->{node}{$node_name}{hardware}{dimm}{$dimm_locator}{speed},
					name5 => "node::${node_name}::hardware::dimm::${dimm_locator}::form_factor", value5 => $an->data->{node}{$node_name}{hardware}{dimm}{$dimm_locator}{form_factor},
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			$in_cpu         = 0;
			$in_system_ram  = 0;
			$in_dimm_module = 0;
			$this_socket    = "";
			$this_vg        = "";
			next;
		}
		if ($line =~ /Processor Information/)
		{
			$in_cpu = 1;
			$an->data->{resources}{total_cpus}++;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "resources::total_cpus", value1 => $an->data->{resources}{total_cpus},
			}, file => $THIS_FILE, line => __LINE__});
			next;
		}
		if ($line =~ /Physical Memory Array/)
		{
			$in_system_ram  = 1;
			next;
		}
		if ($line =~ /Memory Device/)
		{
			$in_dimm_module = 1;
			next;
		}
		if ((not $in_cpu) && (not $in_system_ram) && (not $in_dimm_module))
		{
			next;
		}
		
		# Now pull out data based on where I am.
		if ($in_cpu)
		{
			# The socket is the first line, so I can safely assume that 'this_socket' will be 
			# populated after this.
			if ($line =~ /Socket Designation: (.*)/)
			{
				$this_socket = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "node_name",   value1 => $node_name,
					name2 => "this_socket", value2 => $this_socket,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			
			# Grab some deets!
			if ($line =~ /Family: (.*)/)
			{
				$an->data->{node}{$node_name}{hardware}{cpu}{$this_socket}{family} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node_name}::hardware::cpu::${this_socket}::family", value1 => $an->data->{node}{$node_name}{hardware}{cpu}{$this_socket}{family},
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /Manufacturer: (.*)/)
			{
				$an->data->{node}{$node_name}{hardware}{cpu}{$this_socket}{oem} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node_name}::hardware::cpu::${this_socket}::oem", value1 => $an->data->{node}{$node_name}{hardware}{cpu}{$this_socket}{oem},
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /Version: (.*)/)
			{
				$an->data->{node}{$node_name}{hardware}{cpu}{$this_socket}{version} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node_name}::hardware::cpu::${this_socket}::version", value1 => $an->data->{node}{$node_name}{hardware}{cpu}{$this_socket}{version},
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /Max Speed: (.*)/)
			{
				$an->data->{node}{$node_name}{hardware}{cpu}{$this_socket}{max_speed} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node_name}::hardware::cpu::${this_socket}::max_speed", value1 => $an->data->{node}{$node_name}{hardware}{cpu}{$this_socket}{max_speed},
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /Status: (.*)/)
			{
				$an->data->{node}{$node_name}{hardware}{cpu}{$this_socket}{status} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node_name}::hardware::cpu::${this_socket}::status", value1 => $an->data->{node}{$node_name}{hardware}{cpu}{$this_socket}{status},
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /Core Count: (.*)/)
			{
				$an->data->{node}{$node_name}{hardware}{cpu}{$this_socket}{cores} =  $1;
				$an->data->{node}{$node_name}{hardware}{total_node_cores}         += $an->data->{node}{$node_name}{hardware}{cpu}{$this_socket}{cores};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node_name}::hardware::cpu::${this_socket}::cores", value1 => $an->data->{node}{$node_name}{hardware}{cpu}{$this_socket}{cores},
					name2 => "node::${node_name}::hardware::total_node_cores",           value2 => $an->data->{node}{$node_name}{hardware}{total_node_cores},
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /Thread Count: (.*)/)
			{
				$an->data->{node}{$node_name}{hardware}{cpu}{$this_socket}{threads} =  $1;
				$an->data->{node}{$node_name}{hardware}{total_node_threads}         += $an->data->{node}{$node_name}{hardware}{cpu}{$this_socket}{threads};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "node::${node_name}::hardware::cpu::${this_socket}::threads", value1 => $an->data->{node}{$node_name}{hardware}{cpu}{$this_socket}{threads},
					name2 => "node::${node_name}::hardware::total_node_threads",           value2 => $an->data->{node}{$node_name}{hardware}{total_node_threads},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		if ($in_system_ram)
		{
			# Not much in system RAM, but good to know stuff.
			if ($line =~ /Error Correction Type: (.*)/)
			{
				$an->data->{node}{$node_name}{hardware}{ram}{ecc_support} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node_name}::hardware::ram::ecc_support", value1 => $an->data->{node}{$node_name}{hardware}{ram}{ecc_support},
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /Number Of Devices: (.*)/)
			{
				$an->data->{node}{$node_name}{hardware}{ram}{slots}       = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node_name}::hardware::ram::slots", value1 => $an->data->{node}{$node_name}{hardware}{ram}{slots},
				}, file => $THIS_FILE, line => __LINE__});
			}
			# This needs to be converted to bytes.
			if ($line =~ /Maximum Capacity: (\d+) (.*)$/)
			{
				my $size   = $1;
				my $suffix = $2;
				$an->data->{node}{$node_name}{hardware}{ram}{max_support} = $an->Readable->hr_to_bytes({size => $size, type => $suffix });
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node_name}::hardware::ram::max_support", value1 => $an->data->{node}{$node_name}{hardware}{ram}{max_support},
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /Maximum Capacity: (.*)/)
			{
				$an->data->{node}{$node_name}{hardware}{ram}{max_support} = $1;
				$an->data->{node}{$node_name}{hardware}{ram}{max_support} = $an->Readable->hr_to_bytes({size => $an->data->{node}{$node_name}{hardware}{ram}{max_support} });
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node_name}::hardware::ram::max_support", value1 => $an->data->{node}{$node_name}{hardware}{ram}{max_support},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		if ($in_dimm_module)
		{
			if    ($line =~ /Bank Locator: (.*)/)     { $dimm_bank        = $1; }
			elsif ($line =~ /Locator: (.*)/)          { $dimm_locator     = $1; }
			elsif ($line =~ /Type: (.*)/)             { $dimm_type        = $1; }
			elsif ($line =~ /Configured Clock Speed/) {  }	# Ignore
			elsif ($line =~ /Speed: (.*)/)            { $dimm_speed       = $1; }
			elsif ($line =~ /Form Factor: (.*)/)  { $dimm_form_factor = $1; }
			elsif ($line =~ /Size: (.*)/)
			{
				$dimm_size = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "node_name", value1 => $node_name,
					name2 => "dimm_size", value2 => $dimm_size,
				}, file => $THIS_FILE, line => __LINE__});
				# If the DIMM couldn't be read, it will show "Unknown". I set this to 0 in 
				# that case.
				if ($dimm_size !~ /^\d/)
				{
					$dimm_size = 0;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "node_name", value1 => $node_name,
						name2 => "dimm_size", value2 => $dimm_size,
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					$dimm_size                                            =  $an->Readable->hr_to_bytes({size => $dimm_size });
					$an->data->{node}{$node_name}{hardware}{total_memory} += $dimm_size;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "dimm_size",                                  value1 => $dimm_size,
						name2 => "node::${node_name}::hardware::total_memory", value2 => $an->data->{node}{$node_name}{hardware}{total_memory},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "resources::total_cpus",                          value1 => $an->data->{resources}{total_cpus},
		name2 => "node::${node_name}::hardware::total_node_cores", value2 => $an->data->{node}{$node_name}{hardware}{total_node_cores},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{resources}{total_cpus}) && (not $an->data->{node}{$node_name}{hardware}{total_node_cores}))
	{
		$an->data->{node}{$node_name}{hardware}{total_node_cores} = $an->data->{resources}{total_cpus};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node_name}::hardware::total_node_cores", value1 => $an->data->{node}{$node_name}{hardware}{total_node_cores},
		}, file => $THIS_FILE, line => __LINE__});
	}
	if (($an->data->{resources}{total_cpus}) && (not $an->data->{node}{$node_name}{hardware}{total_node_threads}))
	{
		$an->data->{node}{$node_name}{hardware}{total_node_threads} = $an->data->{node}{$node_name}{hardware}{total_node_cores};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node_name}::hardware::total_node_threads", value1 => $an->data->{node}{$node_name}{hardware}{total_node_threads},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
		name1 => "node::${node_name}::hardware::total_node_cores",   value1 => $an->data->{node}{$node_name}{hardware}{total_node_cores},
		name2 => "node::${node_name}::hardware::total_node_threads", value2 => $an->data->{node}{$node_name}{hardware}{total_node_threads},
		name3 => "node::${node_name}::hardware::total_memory",       value3 => $an->data->{node}{$node_name}{hardware}{total_memory},
		name4 => "resources::total_cores",                           value4 => $an->data->{resources}{total_cores},
		name5 => "resources::total_threads",                         value5 => $an->data->{resources}{total_threads},
		name6 => "resources::total_ram",                             value6 => $an->data->{resources}{total_ram},
	}, file => $THIS_FILE, line => __LINE__});
	return(0);
}

# Parse the GFS2 data.
sub _parse_gfs2
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_parse_gfs2" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $data       = $parameter->{data};
	
	my $in_filesystem = 0;
	foreach my $line (@{$data})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /Filesystem/)
		{
			$in_filesystem = 1;
			next;
		}
		
		if ($in_filesystem)
		{
			next if $line !~ /^\//;
			my ($device_path, $total_size, $used_space, $free_space, $percent_used, $mount_point) = ($line =~ /^(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)$/);
			next if not $mount_point;
			$total_size   = "" if not defined $total_size;
			$used_space   = "" if not defined $used_space;
			$free_space   = "" if not defined $free_space;
			$percent_used = "" if not defined $percent_used;
			next if not exists $an->data->{node}{$node_name}{gfs}{$mount_point};
			
			$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
				name1 => "node_name",    value1 => $node_name,
				name2 => "device path",  value2 => $device_path,
				name3 => "total size",   value3 => $total_size,
				name4 => "used space",   value4 => $used_space,
				name5 => "free space",   value5 => $free_space,
				name6 => "percent used", value6 => $percent_used,
				name7 => "mount point",  value7 => $mount_point,
			}, file => $THIS_FILE, line => __LINE__});
			
			$an->data->{node}{$node_name}{gfs}{$mount_point}{device_path}  = $device_path;
			$an->data->{node}{$node_name}{gfs}{$mount_point}{total_size}   = $total_size;
			$an->data->{node}{$node_name}{gfs}{$mount_point}{used_space}   = $used_space;
			$an->data->{node}{$node_name}{gfs}{$mount_point}{free_space}   = $free_space;
			$an->data->{node}{$node_name}{gfs}{$mount_point}{percent_used} = $percent_used;
			$an->data->{node}{$node_name}{gfs}{$mount_point}{mounted}      = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
				name1 => "node::${node_name}::gfs::${mount_point}::device_path",  value1 => $an->data->{node}{$node_name}{gfs}{$mount_point}{device_path},
				name2 => "node::${node_name}::gfs::${mount_point}::total_size",   value2 => $an->data->{node}{$node_name}{gfs}{$mount_point}{total_size},
				name3 => "node::${node_name}::gfs::${mount_point}::used_space",   value3 => $an->data->{node}{$node_name}{gfs}{$mount_point}{used_space},
				name4 => "node::${node_name}::gfs::${mount_point}::free_space",   value4 => $an->data->{node}{$node_name}{gfs}{$mount_point}{free_space},
				name5 => "node::${node_name}::gfs::${mount_point}::percent_used", value5 => $an->data->{node}{$node_name}{gfs}{$mount_point}{percent_used},
				name6 => "node::${node_name}::gfs::${mount_point}::mounted",      value6 => $an->data->{node}{$node_name}{gfs}{$mount_point}{mounted},
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Read the GFS info.
			next if $line !~ /gfs2/;
			my (undef, $mount_point, $filesystem) = ($line =~ /^(.*?)\s+(.*?)\s+(.*?)\s/);
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "node_name",   value1 => $node_name,
				name2 => "mount_point", value2 => $mount_point,
				name3 => "filesystem",  value3 => $filesystem,
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{node}{$node_name}{gfs}{$mount_point}{device_path}  = "--";
			$an->data->{node}{$node_name}{gfs}{$mount_point}{total_size}   = "--";
			$an->data->{node}{$node_name}{gfs}{$mount_point}{used_space}   = "--";
			$an->data->{node}{$node_name}{gfs}{$mount_point}{free_space}   = "--";
			$an->data->{node}{$node_name}{gfs}{$mount_point}{percent_used} = "--";
			$an->data->{node}{$node_name}{gfs}{$mount_point}{mounted}      = 0;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
				name1 => "node::${node_name}::gfs::${mount_point}::device_path",  value1 => $an->data->{node}{$node_name}{gfs}{$mount_point}{device_path},
				name2 => "node::${node_name}::gfs::${mount_point}::total_size",   value2 => $an->data->{node}{$node_name}{gfs}{$mount_point}{total_size},
				name3 => "node::${node_name}::gfs::${mount_point}::used_space",   value3 => $an->data->{node}{$node_name}{gfs}{$mount_point}{used_space},
				name4 => "node::${node_name}::gfs::${mount_point}::free_space",   value4 => $an->data->{node}{$node_name}{gfs}{$mount_point}{free_space},
				name5 => "node::${node_name}::gfs::${mount_point}::percent_used", value5 => $an->data->{node}{$node_name}{gfs}{$mount_point}{percent_used},
				name6 => "node::${node_name}::gfs::${mount_point}::mounted",      value6 => $an->data->{node}{$node_name}{gfs}{$mount_point}{mounted},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

# This parses the node's /etc/hosts file so that it can pull out the IPs for anything matching the node's 
# short name and record it in the local cache.
sub _parse_hosts
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_parse_hosts" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $data       = $parameter->{data};
	
	my $hosts_file = "";
	foreach my $line (@{$data})
	{
		# This code is copy-pasted from read_hosts(), save for the hash is records to.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		$line =~ s/#.*$//;
		$line =~ s/\s+$//;
		next if not $line;
		next if $line =~ /^127.0.0.1\s/;
		next if $line =~ /^::1\s/;
		$hosts_file   .= "$line\n";
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		my $this_ip     = "";
		my $these_hosts = "";
		if ($line =~ /^(\d+\.\d+\.\d+\.\d+)\s+(.*)/)
		{
			$this_ip     = $1;
			$these_hosts = $2;
			foreach my $this_host (split/ /, $these_hosts)
			{
				next if not $this_host;
				$an->data->{node}{$node_name}{hosts}{$this_host}{ip} = $this_ip;
				if (not exists $an->data->{node}{$node_name}{hosts}{by_ip}{$this_ip})
				{
					$an->data->{node}{$node_name}{hosts}{by_ip}{$this_ip} = "";
				}
				$an->data->{node}{$node_name}{hosts}{by_ip}{$this_ip} .= "$this_host,";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "node::${node_name}::hosts::${this_host}::ip", value1 => $an->data->{node}{$node_name}{hosts}{$this_host}{ip},
					name2 => "node::${node_name}::hosts::by_ip::$this_ip",  value2 => $an->data->{node}{$node_name}{hosts}{by_ip}{$this_ip},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Cache the hosts file
	$an->ScanCore->insert_or_update_nodes_cache({
		node_cache_host_uuid	=>	$an->data->{sys}{host_uuid},
		node_cache_node_uuid	=>	$node_uuid, 
		node_cache_name		=>	"etc_hosts",
		node_cache_data		=>	$hosts_file,
	});
	
	return(0);
}

# Parse the LVM data.
sub _parse_lvm_data
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_parse_lvm_data" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $data       = $parameter->{data};
	
	my $in_pvs = 0;
	my $in_vgs = 0;
	my $in_lvs = 0;
	foreach my $line (@{$data})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		# This is a little odd but it makes reading the logs cleaner
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "in_pvs/in_vgs/in_lvs", value1 => "$in_pvs/$in_vgs/$in_lvs",
			name2 => "line",                 value2 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /^PV/)
		{
			$in_pvs = 1;
			$in_vgs = 0;
			$in_lvs = 0;
			next;
		}
		if ($line =~ /^VG/)
		{
			$in_pvs = 0;
			$in_vgs = 1;
			$in_lvs = 0;
			next;
		}
		if ($line =~ /^LV/)
		{
			$in_pvs = 0;
			$in_vgs = 0;
			$in_lvs = 1;
			next;
		}
		
		if ($in_pvs)
		{
			# pvs --units b --separator \\\#\\\!\\\# -o pv_name,vg_name,pv_fmt,pv_attr,pv_size,pv_free,pv_used,pv_uuid
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /pvs:(\d+)/)
			{
				### TODO: If this is 124, make sure sane null values are set because timeout fired.
				my $return_code = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			#   pv_name,  vg_name,     pv_fmt,  pv_attr,     pv_size,     pv_free,   pv_used,     pv_uuid
			my ($this_pv, $used_by_vg, $format, $attributes, $total_size, $free_size, $used_size, $uuid) = (split /#!#/, $line);
			$total_size =~ s/B$//;
			$free_size  =~ s/B$//;
			$used_size  =~ s/B$//;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0008", message_variables => {
				name1 => "this_pv",    value1 => $this_pv,
				name2 => "used_by_vg", value2 => $used_by_vg,
				name3 => "format",     value3 => $format,
				name4 => "attributes", value4 => $attributes,
				name5 => "total_size", value5 => $total_size,
				name6 => "free_size",  value6 => $free_size,
				name7 => "used_size",  value7 => $used_size,
				name8 => "uuid",       value8 => $uuid,
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{node}{$node_name}{lvm}{pv}{$this_pv}{used_by_vg} = $used_by_vg;
			$an->data->{node}{$node_name}{lvm}{pv}{$this_pv}{attributes} = $attributes;
			$an->data->{node}{$node_name}{lvm}{pv}{$this_pv}{total_size} = $total_size;
			$an->data->{node}{$node_name}{lvm}{pv}{$this_pv}{free_size}  = $free_size;
			$an->data->{node}{$node_name}{lvm}{pv}{$this_pv}{used_size}  = $used_size;
			$an->data->{node}{$node_name}{lvm}{pv}{$this_pv}{uuid}       = $uuid;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
				name1 => "node::${node_name}::lvm::pv::${this_pv}::used_by_vg", value1 => $an->data->{node}{$node_name}{lvm}{pv}{$this_pv}{used_by_vg},
				name2 => "node::${node_name}::lvm::pv::${this_pv}::attributes", value2 => $an->data->{node}{$node_name}{lvm}{pv}{$this_pv}{attributes},
				name3 => "node::${node_name}::lvm::pv::${this_pv}::total_size", value3 => $an->data->{node}{$node_name}{lvm}{pv}{$this_pv}{total_size},
				name4 => "node::${node_name}::lvm::pv::${this_pv}::free_size",  value4 => $an->data->{node}{$node_name}{lvm}{pv}{$this_pv}{free_size},
				name5 => "node::${node_name}::lvm::pv::${this_pv}::used_size",  value5 => $an->data->{node}{$node_name}{lvm}{pv}{$this_pv}{used_size},
				name6 => "node::${node_name}::lvm::pv::${this_pv}::uuid",       value6 => $an->data->{node}{$node_name}{lvm}{pv}{$this_pv}{uuid},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($in_vgs)
		{
			# vgs --units b --separator \\\#\\\!\\\# -o vg_name,vg_attr,vg_extent_size,vg_extent_count,vg_uuid,vg_size,vg_free_count,vg_free,pv_name
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /vgs:(\d+)/)
			{
				### TODO: If this is 124, make sure sane null values are set because timeout fired.
				my $return_code = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			#   vg_name,  vg_attr,     vg_extent_size, vg_extent_count, vg_uuid, vg_size,  vg_free_count, vg_free,  pv_name
			my ($this_vg, $attributes, $pe_size,       $total_pe,       $uuid,   $vg_size, $free_pe,      $vg_free, $pv_name) = split /#!#/, $line;
			$pe_size    = "" if not defined $pe_size;
			$vg_size    = "" if not defined $vg_size;
			$vg_free    = "" if not defined $vg_free;
			$attributes = "" if not defined $attributes;
			$pe_size =~ s/B$//;
			$vg_size =~ s/B$//;
			$vg_free =~ s/B$//;
			my $used_pe    = $total_pe - $free_pe if (($total_pe) && ($free_pe));
			my $used_space = $vg_size - $vg_free  if (($vg_size) && ($vg_free));
			$an->Log->entry({log_level => 3, message_key => "an_variables_0012", message_variables => {
				name1  => "this_vg",    value1  => $this_vg,
				name2  => "attributes", value2  => $attributes,
				name3  => "pe_size",    value3  => $pe_size,
				name4  => "total_pe",   value4  => $total_pe,
				name5  => "uuid",       value5  => $uuid,
				name6  => "vg_size",    value6  => $vg_size,
				name7  => "used_pe",    value7  => $used_pe,
				name8  => "used_space", value8  => $used_space,
				name9  => "free_pe",    value9  => $free_pe,
				name10 => "free_space", value10 => $vg_free,
				name11 => "vg_free",    value11 => $vg_free,
				name12 => "pv_name",    value12 => $pv_name,
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{clustered}  = $attributes =~ /c$/ ? 1 : 0;
			$an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{pe_size}    = $pe_size;
			$an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{total_pe}   = $total_pe;
			$an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{uuid}       = $uuid;
			$an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{size}       = $vg_size;
			$an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{used_pe}    = $used_pe;
			$an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{used_space} = $used_space;
			$an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{free_pe}    = $free_pe;
			$an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{free_space} = $vg_free;
			$an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{pv_name}    = $pv_name;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0010", message_variables => {
				name1  => "node::${node_name}::hardware::lvm::vg::${this_vg}::clustered",  value1  => $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{clustered},
				name2  => "node::${node_name}::hardware::lvm::vg::${this_vg}::pe_size",    value2  => $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{pe_size},
				name3  => "node::${node_name}::hardware::lvm::vg::${this_vg}::total_pe",   value3  => $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{total_pe},
				name4  => "node::${node_name}::hardware::lvm::vg::${this_vg}::uuid",       value4  => $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{uuid},
				name5  => "node::${node_name}::hardware::lvm::vg::${this_vg}::size",       value5  => $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{size},
				name6  => "node::${node_name}::hardware::lvm::vg::${this_vg}::used_pe",    value6  => $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{used_pe},
				name7  => "node::${node_name}::hardware::lvm::vg::${this_vg}::used_space", value7  => $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{used_space},
				name8  => "node::${node_name}::hardware::lvm::vg::${this_vg}::free_pe",    value8  => $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{free_pe},
				name9  => "node::${node_name}::hardware::lvm::vg::${this_vg}::free_space", value9  => $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{free_space},
				name10 => "node::${node_name}::hardware::lvm::vg::${this_vg}::pe_name",    value10 => $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$this_vg}{pv_name},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($in_lvs)
		{
			# lvs --units b --separator \\\#\\\!\\\# -o lv_name,vg_name,lv_attr,lv_size,lv_uuid,lv_path,devices
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /lvs:(\d+)/)
			{
				### TODO: If this is 124, make sure sane null values are set because timeout fired.
				my $return_code = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			my ($lv_name, $on_vg, $attributes, $total_size, $uuid, $path, $devices) = (split /#!#/, $line);
			$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
				name1 => "lv_name",    value1 => $lv_name,
				name2 => "on_vg",      value2 => $on_vg,
				name3 => "attributes", value3 => $attributes,
				name4 => "total_size", value4 => $total_size,
				name5 => "uuid",       value5 => $uuid,
				name6 => "path",       value6 => $path,
				name7 => "devices",    value7 => $devices,
			}, file => $THIS_FILE, line => __LINE__});
			$total_size =~ s/B$//;
			$devices    =~ s/\(\d+\)//g;	# Strip the starting PE number
			$an->data->{node}{$node_name}{lvm}{lv}{$path}{name}       = $lv_name;
			$an->data->{node}{$node_name}{lvm}{lv}{$path}{on_vg}      = $on_vg;
			$an->data->{node}{$node_name}{lvm}{lv}{$path}{active}     = ($attributes =~ /.{4}(.{1})/)[0] eq "a" ? 1 : 0;
			$an->data->{node}{$node_name}{lvm}{lv}{$path}{attributes} = $attributes;
			$an->data->{node}{$node_name}{lvm}{lv}{$path}{total_size} = $total_size;
			$an->data->{node}{$node_name}{lvm}{lv}{$path}{uuid}       = $uuid;
			$an->data->{node}{$node_name}{lvm}{lv}{$path}{on_devices} = $devices;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
				name1 => "node::${node_name}::lvm::lv::${path}::name",       value1 => $an->data->{node}{$node_name}{lvm}{lv}{$path}{name},
				name2 => "node::${node_name}::lvm::lv::${path}::on_vg",      value2 => $an->data->{node}{$node_name}{lvm}{lv}{$path}{on_vg},
				name3 => "node::${node_name}::lvm::lv::${path}::active",     value3 => $an->data->{node}{$node_name}{lvm}{lv}{$path}{active},
				name4 => "node::${node_name}::lvm::lv::${path}::attribute",  value4 => $an->data->{node}{$node_name}{lvm}{lv}{$path}{attributes},
				name5 => "node::${node_name}::lvm::lv::${path}::total_size", value5 => $an->data->{node}{$node_name}{lvm}{lv}{$path}{total_size},
				name6 => "node::${node_name}::lvm::lv::${path}::uuid",       value6 => $an->data->{node}{$node_name}{lvm}{lv}{$path}{uuid},
				name7 => "node::${node_name}::lvm::lv::${path}::on_devices", value7 => $an->data->{node}{$node_name}{lvm}{lv}{$path}{on_devices},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

### TODO: timeout is now used here. Verify we handle it properly. Check for the line '{pv,vg,lv}scan:(\d+)'.
###       If they are 124, timeout fired.
# Parse the LVM scan output.
sub _parse_lvm_scan
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_parse_lvm_scan" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $data       = $parameter->{data};
	
	foreach my $line (@{$data})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /pvscan:(\d+)/)
		{
			### TODO: If this is 124, make sure sane null values are set because timeout fired.
			my $return_code = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
			next;
		}
		if ($line =~ /vgscan:(\d+)/)
		{
			### TODO: If this is 124, make sure sane null values are set because timeout fired.
			my $return_code = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
			next;
		}
		if ($line =~ /lvscan:(\d+)/)
		{
			### TODO: If this is 124, make sure sane null values are set because timeout fired.
			my $return_code = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
			next;
		}
		
		if ($line =~ /(.*?)\s+'(.*?)'\s+\[(.*?)\]/)
		{
			my $state     = $1;
			my $lv        = $2;
			my $size      = $3;
			my $bytes     = $an->Readable->hr_to_bytes({size => $size });
			my $vg        = ($lv =~ /^\/dev\/(.*?)\//)[0];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
				name1 => "node_name", value1 => $node_name,
				name2 => "state",     value2 => $state,
				name3 => "vg",        value3 => $vg,
				name4 => "lv",        value4 => $lv,
				name5 => "size",      value5 => $size,
				name6 => "bytes",     value6 => $bytes,
			}, file => $THIS_FILE, line => __LINE__});
			
			if (lc($state) eq "inactive")
			{
				# The variables here pass onto 'message_0045'.
				my $message = $an->String->get({key => "message_0045", variables => { 
					lv	=>	$lv,
					node	=>	$node_name,
				}});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "message", value1 => $message,
				}, file => $THIS_FILE, line => __LINE__});
				print $an->Web->template({file => "main-page.html", template => "lv-inactive-error", replace => { message => $message }});
			}
			
			if (exists $an->data->{resources}{lv}{$lv})
			{
				if (($an->data->{resources}{lv}{$lv}{on_vg} ne $vg) || ($an->data->{resources}{lv}{$lv}{size} ne $bytes))
				{
					my $error = $an->String->get({key => "message_0046", variables => { 
							lv	=>	$lv,
							size	=>	$an->data->{resources}{lv}{$lv}{size},
							'bytes'	=>	$bytes,
							vg_1	=>	$an->data->{resources}{lv}{$lv}{on_vg},
							vg_2	=>	$vg,
						}});
					$an->Striker->_error({message => $error, fatal => 1});
				}
			}
			else
			{
				$an->data->{resources}{lv}{$lv}{on_vg} = $vg;
				$an->data->{resources}{lv}{$lv}{size}  = $bytes;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "resources::lv::${lv}::on_vg", value1 => $an->data->{resources}{lv}{$lv}{on_vg},
					name2 => "resources::lv::${lv}::size",  value2 => $an->data->{resources}{lv}{$lv}{size},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return(0);
}

# Parse the memory information.
sub _parse_meminfo
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_parse_meminfo" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $data       = $parameter->{data};
	
	foreach my $line (@{$data})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /MemTotal:\s+(.*)/)
		{
			$an->data->{node}{$node_name}{hardware}{meminfo}{memtotal} = $1;
			$an->data->{node}{$node_name}{hardware}{meminfo}{memtotal} = $an->Readable->hr_to_bytes({size => $an->data->{node}{$node_name}{hardware}{meminfo}{memtotal} });
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name2 => "node::${node_name}::hardware::meminfo::memtotal", value2 => $an->data->{node}{$node_name}{hardware}{meminfo}{memtotal},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

# Parse the DRBD status.
sub _parse_proc_drbd
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_parse_proc_drbd" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $data       = $parameter->{data};
	
	my $resource     = "";
	my $minor_number = "";
	foreach my $line (@{$data})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /drbd offline/)
		{
			$an->Log->entry({log_level => 3, message_key => "log_0267", message_variables => {
				node => $node_name
			}, file => $THIS_FILE, line => __LINE__});
			last;
		}
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		if ($line =~ /version: (.*?) \(/)
		{
			$an->data->{node}{$node_name}{drbd}{version} = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node_name}::drbd::version", value1 => $an->data->{node}{$node_name}{drbd}{version},
			}, file => $THIS_FILE, line => __LINE__});
			next;
		}
		elsif ($line =~ /GIT-hash: (.*?) build by (.*?), (\S+) (.*)$/)
		{
			$an->data->{node}{$node_name}{drbd}{git_hash}   = $1;
			$an->data->{node}{$node_name}{drbd}{builder}    = $2;
			$an->data->{node}{$node_name}{drbd}{build_date} = $3;
			$an->data->{node}{$node_name}{drbd}{build_time} = $4;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
				name1 => "node::${node_name}::drbd::git_hash",   value1 => $an->data->{node}{$node_name}{drbd}{git_hash},
				name2 => "node::${node_name}::drbd::builder",    value2 => $an->data->{node}{$node_name}{drbd}{builder},
				name3 => "node::${node_name}::drbd::build_date", value3 => $an->data->{node}{$node_name}{drbd}{build_date},
				name4 => "node::${node_name}::drbd::build_time", value4 => $an->data->{node}{$node_name}{drbd}{build_time},
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# This is just for hash key consistency
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /^(\d+): cs:(.*?) ro:(.*?)\/(.*?) ds:(.*?)\/(.*?) (.*?) (.*)$/)
			{
				   $minor_number     = $1;
				my $connection_state = $2;
				my $my_role          = $3;
				my $peer_role        = $4;
				my $my_disk_state    = $5;
				my $peer_disk_state  = $6;
				my $drbd_protocol    = $7;
				my $io_flags         = $8;	# See: http://www.drbd.org/users-guide/ch-admin.html#s-io-flags
				   $resource         = $an->data->{node}{$node_name}{drbd}{minor_number}{$minor_number}{resource};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "node::${node_name}::drbd::resource::${resource}::minor_number",     value1 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{minor_number},
					name2 => "node::${node_name}::drbd::resource::${resource}::connection_state", value2 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{connection_state},
				}, file => $THIS_FILE, line => __LINE__});
				   
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{minor_number}     = $minor_number;
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{connection_state} = $connection_state;
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{my_role}          = $my_role;
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{peer_role}        = $peer_role;
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{my_disk_state}    = $my_disk_state;
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{peer_disk_state}  = $peer_disk_state;
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{drbd_protocol}    = $drbd_protocol;
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{io_flags}         = $io_flags;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0008", message_variables => {
					name1 => "node::${node_name}::drbd::resource::${resource}::minor_number",     value1 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{minor_number},
					name2 => "node::${node_name}::drbd::resource::${resource}::connection_state", value2 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{connection_state},
					name3 => "node::${node_name}::drbd::resource::${resource}::my_role",          value3 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{my_role},
					name4 => "node::${node_name}::drbd::resource::${resource}::peer_role",        value4 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{peer_role},
					name5 => "node::${node_name}::drbd::resource::${resource}::my_disk_state",    value5 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{my_disk_state},
					name6 => "node::${node_name}::drbd::resource::${resource}::peer_disk_state",  value6 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{peer_disk_state},
					name7 => "node::${node_name}::drbd::resource::${resource}::drbd_protocol",    value7 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{drbd_protocol},
					name8 => "node::${node_name}::drbd::resource::${resource}::io_flags",         value8 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{io_flags},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /ns:(.*?) nr:(.*?) dw:(.*?) dr:(.*?) al:(.*?) bm:(.*?) lo:(.*?) pe:(.*?) ua:(.*?) ap:(.*?) ep:(.*?) wo:(.*?) oos:(.*)$/)
			{
				# Details: http://www.drbd.org/users-guide/ch-admin.html#s-performance-indicators
				my $network_sent            = $1;	# KiB send
				my $network_received        = $2;	# KiB received
				my $disk_write              = $3;	# KiB wrote
				my $disk_read               = $4;	# KiB read
				my $activity_log_updates    = $5;	# Number of updates of the activity log area of the meta data.
				my $bitmap_updates          = $6;	# Number of updates of the bitmap area of the meta data.
				my $local_count             = $7;	# Number of open requests to the local I/O sub-system issued by DRBD.
				my $pending_requests        = $8;	# Number of requests sent to the partner, but that have not yet been answered by the latter.
				my $unacknowledged_requests = $9;	# Number of requests received by the partner via the network connection, but that have not yet been answered.
				my $app_pending_requests    = $10;	# Number of block I/O requests forwarded to DRBD, but not yet answered by DRBD.
				my $epoch_objects           = $11;	# Number of epoch objects. Usually 1. Might increase under I/O load when using either the barrier or the none write ordering method.
				my $write_order             = $12;	# Currently used write ordering method: b(barrier), f(flush), d(drain) or n(none).
				my $out_of_sync             = $13;	# KiB that are out of sync
				if    ($write_order eq "b") { $write_order = "barrier"; }
				elsif ($write_order eq "f") { $write_order = "flush"; }
				elsif ($write_order eq "d") { $write_order = "drain"; }
				elsif ($write_order eq "n") { $write_order = "none"; }
				
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{network_sent}            = $an->Readable->hr_to_bytes({size => $network_sent, type => "KiB" });
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{network_received}        = $an->Readable->hr_to_bytes({size => $network_received, type => "KiB" });
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{disk_write}              = $an->Readable->hr_to_bytes({size => $disk_write, type => "KiB" });
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{disk_read}               = $an->Readable->hr_to_bytes({size => $disk_read, type => "KiB" });
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{activity_log_updates}    = $activity_log_updates;
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{bitmap_updates}          = $bitmap_updates;
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{local_count}             = $local_count;
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{pending_requests}        = $pending_requests;
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{unacknowledged_requests} = $unacknowledged_requests;
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{app_pending_requests}    = $app_pending_requests;
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{epoch_objects}           = $epoch_objects;
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{write_order}             = $write_order;
				$an->data->{node}{$node_name}{drbd}{resource}{$resource}{out_of_sync}             = $an->Readable->hr_to_bytes({size => $out_of_sync, type => "KiB" });
				
				$an->Log->entry({log_level => 3, message_key => "an_variables_0013", message_variables => {
					name1  => "node::${node_name}::drbd::resource::${resource}::network_sent",            value1 =>  $an->data->{node}{$node_name}{drbd}{resource}{$resource}{network_sent},
					name2  => "node::${node_name}::drbd::resource::${resource}::network_received",        value2 =>  $an->data->{node}{$node_name}{drbd}{resource}{$resource}{network_received},
					name3  => "node::${node_name}::drbd::resource::${resource}::disk_write",              value3 =>  $an->data->{node}{$node_name}{drbd}{resource}{$resource}{disk_write},
					name4  => "node::${node_name}::drbd::resource::${resource}::disk_read",               value4 =>  $an->data->{node}{$node_name}{drbd}{resource}{$resource}{disk_read},
					name5  => "node::${node_name}::drbd::resource::${resource}::activity_log_updates",    value5 =>  $an->data->{node}{$node_name}{drbd}{resource}{$resource}{activity_log_updates},
					name6  => "node::${node_name}::drbd::resource::${resource}::bitmap_updates",          value6 =>  $an->data->{node}{$node_name}{drbd}{resource}{$resource}{bitmap_updates},
					name7  => "node::${node_name}::drbd::resource::${resource}::local_count",             value7 =>  $an->data->{node}{$node_name}{drbd}{resource}{$resource}{local_count},
					name8  => "node::${node_name}::drbd::resource::${resource}::pending_requests",        value8 =>  $an->data->{node}{$node_name}{drbd}{resource}{$resource}{pending_requests},
					name9  => "node::${node_name}::drbd::resource::${resource}::unacknowledged_requests", value9 =>  $an->data->{node}{$node_name}{drbd}{resource}{$resource}{unacknowledged_requests},
					name10 => "node::${node_name}::drbd::resource::${resource}::app_pending_requests",    value10 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{app_pending_requests},
					name11 => "node::${node_name}::drbd::resource::${resource}::epoch_objects",           value11 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{epoch_objects},
					name12 => "node::${node_name}::drbd::resource::${resource}::write_order",             value12 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{write_order},
					name13 => "node::${node_name}::drbd::resource::${resource}::out_of_sync",             value13 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{out_of_sync},
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# The resync lines aren't consistent, so I pull out data one piece at a time.
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line,
				}, file => $THIS_FILE, line => __LINE__});
				if ($line =~ /sync'ed: (.*?)%/)
				{
					my $percent_synced = $1;
					$an->data->{node}{$node_name}{drbd}{resource}{$resource}{syncing}        = 1;
					$an->data->{node}{$node_name}{drbd}{resource}{$resource}{percent_synced} = $percent_synced;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "node::${node_name}::drbd::resource::${resource}::percent_synced", value1 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{percent_synced},
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /\((\d+)\/(\d+)\)M/)
				{
					# The 'M' is 'Mibibyte'
					my $left_to_sync  = $1;
					my $total_to_sync = $2;
					
					$an->data->{node}{$node_name}{drbd}{resource}{$resource}{left_to_sync}  = $an->Readable->hr_to_bytes({size => $left_to_sync, type => "MiB" });
					$an->data->{node}{$node_name}{drbd}{resource}{$resource}{total_to_sync} = $an->Readable->hr_to_bytes({size => $total_to_sync, type => "MiB" });
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "node::${node_name}::drbd::resource::${resource}::left_to_sync",  value1 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{left_to_sync},
						name2 => "node::${node_name}::drbd::resource::${resource}::total_to_sync", value2 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{total_to_sync},
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /finish: (\d+):(\d+):(\d+)/)
				{
					my $hours   = $1;
					my $minutes = $2;
					my $seconds = $3;
					$an->data->{node}{$node_name}{drbd}{resource}{$resource}{eta_to_sync} = ($hours * 3600) + ($minutes * 60) + $seconds;
					
					$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
						name1 => "hours",                                                        value1 => $hours, 
						name2 => "minutes",                                                      value2 => $minutes, 
						name3 => "seconds",                                                      value3 => $seconds,
						name4 => "node::${node_name}::drbd::resource::${resource}::eta_to_sync", value4 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{eta_to_sync}, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /speed: (.*?) \((.*?)\)/)
				{
					my $current_speed =  $1;
					my $average_speed =  $2;
					   $current_speed =~ s/,//g;
					   $average_speed =~ s/,//g;
					$an->data->{node}{$node_name}{drbd}{resource}{$resource}{current_speed} = $an->Readable->hr_to_bytes({size => $current_speed, type => "KiB" });
					$an->data->{node}{$node_name}{drbd}{resource}{$resource}{average_speed} = $an->Readable->hr_to_bytes({size => $average_speed, type => "KiB" });
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "node::${node_name}::drbd::resource::${resource}::current_speed", value1 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{current_speed},
						name2 => "node::${node_name}::drbd::resource::${resource}::average_speed", value2 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{average_speed},
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /want: (.*?) K/)
				{
					# The 'want' line is only calculated on the sync target
					my $want_speed =  $1;
					   $want_speed =~ s/,//g;
					$an->data->{node}{$node_name}{drbd}{resource}{$resource}{want_speed} = $an->Readable->hr_to_bytes({size => $want_speed, type => "KiB" });
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "node::${node_name}::drbd::resource::${resource}::want_speed", value1 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{want_speed},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
	}
	
	foreach my $resource (sort {$a cmp $b} keys %{$an->data->{node}{$node_name}{drbd}{resource}})
	{
		next if not $resource;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node_name}::drbd::resource::${resource}::minor_number",     value1 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{minor_number},
			name2 => "node::${node_name}::drbd::resource::${resource}::connection_state", value2 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{connection_state},
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->data->{drbd}{$resource}{node}{$node_name}{minor}            = $an->data->{node}{$node_name}{drbd}{resource}{$resource}{minor_number}     ? $an->data->{node}{$node_name}{drbd}{resource}{$resource}{minor_number}     : "--";
		$an->data->{drbd}{$resource}{node}{$node_name}{connection_state} = $an->data->{node}{$node_name}{drbd}{resource}{$resource}{connection_state} ? $an->data->{node}{$node_name}{drbd}{resource}{$resource}{connection_state} : "--";
		$an->data->{drbd}{$resource}{node}{$node_name}{role}             = $an->data->{node}{$node_name}{drbd}{resource}{$resource}{my_role}          ? $an->data->{node}{$node_name}{drbd}{resource}{$resource}{my_role}          : "--";
		$an->data->{drbd}{$resource}{node}{$node_name}{disk_state}       = $an->data->{node}{$node_name}{drbd}{resource}{$resource}{my_disk_state}    ? $an->data->{node}{$node_name}{drbd}{resource}{$resource}{my_disk_state}    : "--";
		$an->data->{drbd}{$resource}{node}{$node_name}{device}           = $an->data->{node}{$node_name}{drbd}{resource}{$resource}{drbd_device}      ? $an->data->{node}{$node_name}{drbd}{resource}{$resource}{drbd_device}      : "--";
		$an->data->{drbd}{$resource}{node}{$node_name}{resync_percent}   = $an->data->{node}{$node_name}{drbd}{resource}{$resource}{percent_synced}   ? $an->data->{node}{$node_name}{drbd}{resource}{$resource}{percent_synced}   : "--";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
			name1 => "drbd::${resource}::node::${node_name}::minor",            value1 => $an->data->{drbd}{$resource}{node}{$node_name}{minor},
			name2 => "drbd::${resource}::node::${node_name}::connection_state", value2 => $an->data->{drbd}{$resource}{node}{$node_name}{connection_state},
			name3 => "drbd::${resource}::node::${node_name}::role",             value3 => $an->data->{drbd}{$resource}{node}{$node_name}{role},
			name4 => "drbd::${resource}::node::${node_name}::disk_state",       value4 => $an->data->{drbd}{$resource}{node}{$node_name}{disk_state},
			name5 => "drbd::${resource}::node::${node_name}::device",           value5 => $an->data->{drbd}{$resource}{node}{$node_name}{device},
			name6 => "drbd::${resource}::node::${node_name}::resync_percent",   value6 => $an->data->{drbd}{$resource}{node}{$node_name}{resync_percent},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return(0);
}

# This (tries to) parse the server definitions files.
sub _parse_server_defs
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_parse_server_defs" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $data       = $parameter->{data};
	
	my $this_server = "";
	my $in_domain   = 0;
	my $this_array  = [];
	foreach my $line (@{$data})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /rc:(\d+)/)
		{
			### TODO: If this is 124, make sure sane null values are set because timeout fired.
			my $return_code = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
			next;
		}
		
		# Find the start of a domain.
		if ($line =~ /<domain/)
		{
			$in_domain = 1;
		}
		
		# Get this name of the current domain
		if ($line =~ /<name>(.*?)<\/name>/)
		{
			$this_server = $1;
		}
		
		# Push all lines into the current domain array.
		if ($in_domain)
		{
			push @{$this_array}, $line;
		}
		
		# When the end of a domain is found, push the array over to $an->data.
		if ($line =~ /<\/domain>/)
		{
			my $lines = @{$this_array};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "this_server", value1 => $this_server,
				name2 => "this_array",  value2 => $this_array,
				name3 => "lines",       value3 => $lines,
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{server}{$this_server}{xml} = $this_array;
			$in_domain  = 0;
			$this_array = [];
		}
	}
	
	return (0);
}

# This (tries to) parse the server definitions as they are in memory.
sub _parse_server_defs_in_mem
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_parse_server_defs_in_mem" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $data       = $parameter->{data};
	
	my $this_server = "";
	my $in_domain   = 0;
	my $this_array  = [];
	foreach my $line (@{$data})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Find the start of a domain.
		if ($line =~ /<domain/)
		{
			$in_domain = 1;
		}
		
		# Get this name of the current domain
		if ($line =~ /<name>(.*?)<\/name>/)
		{
			$this_server = $1;
		}
		
		# Push all lines into the current domain array.
		if ($in_domain)
		{
			push @{$this_array}, $line;
		}
		
		# When the end of a domain is found, push the array over to $an->data.
		if ($line =~ /<\/domain>/)
		{
			my $lines = @{$this_array};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "this_server", value1 => $this_server,
				name2 => "this_array",  value2 => $this_array,
				name3 => "lines",       value3 => $lines,
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{server}{$this_server}{xml} = $this_array;
			$in_domain  = 0;
			$this_array = [];
		}
	}
	
	return (0);
}

# Parse the virsh data.
sub _parse_virsh
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_parse_virsh" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $data       = $parameter->{data};
	
	foreach my $line (@{$data})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		next if $line !~ /^\d/;
		
		my ($id, $server, $state) = split/ /, $line, 3;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "id",     value1 => $id,
			name2 => "server", value2 => $server,
			name3 => "state",  value3 => $state,
		}, file => $THIS_FILE, line => __LINE__});
		
		   $an->data->{server}{$server}{node}{$node_name}{virsh}{'state'} = $state;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "server::${server}::node::${node_name}::virsh::state", value1 => $an->data->{server}{$server}{node}{$node_name}{virsh}{'state'},
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($state eq "paused")
		{
			# This server is being migrated here, disable withdrawl of this node and migration of
			# this server.
			$an->data->{node}{$node_name}{enable_withdraw} = 0;
			$an->data->{server}{$server}{can_migrate}      = 0;
			$an->data->{node}{$node_name}{enable_poweroff} = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "node::${node_name}::enable_withdraw", value1 => $an->data->{node}{$node_name}{enable_withdraw},
				name2 => "server::${server}::can_migrate",      value2 => $an->data->{server}{$server}{can_migrate},
				name3 => "node::${node_name}::enable_poweroff", value3 => $an->data->{node}{$node_name}{enable_poweroff},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

# This sorts out some values once the parsing is collected.
sub _post_node_calculations
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_post_node_calculations" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	
	# If I have no $an->data->{node}{$node_name}{hardware}{total_memory} value, use the 'meminfo' size.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "node::${node_name}::hardware::total_memory",      value1 => $an->data->{node}{$node_name}{hardware}{total_memory},
		name2 => "node::${node_name}::hardware::meminfo::memtotal", value2 => $an->data->{node}{$node_name}{hardware}{meminfo}{memtotal},
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->data->{node}{$node_name}{hardware}{total_memory})
	{
		$an->data->{node}{$node_name}{hardware}{total_memory} = $an->data->{node}{$node_name}{hardware}{meminfo}{memtotal};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node_name}::hardware::total_memory", value1 => $an->data->{node}{$node_name}{hardware}{total_memory},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# If the host name was set, then I can trust that I had good data.
	if ($an->data->{node}{$node_name}{info}{host_name})
	{
		# Find out if the nodes are powered up or not.
		$an->Striker->_write_node_cache({node => $node_uuid});
	}
	
	return (0);
}

# This records this scan's data to the cache file.
sub _write_node_cache
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_write_node_cache" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
		name1 => "node_uuid",  value1 => $node_uuid,
		name2 => "node_key",   value2 => $node_key,
		name3 => "anvil_uuid", value3 => $anvil_uuid,
		name4 => "anvil_name", value4 => $anvil_name,
		name5 => "node_name",  value5 => $node_name,
		name6 => "target",     value6 => $target,
		name7 => "port",       value7 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	# It is a program error to try and write the cache file when the node is down.
	my @lines;
	my $cache_file = $an->data->{path}{'striker_cache'}."/cache_".$anvil_name."_".$node_name.".striker";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node_name}::info::host_name",           value1 => $an->data->{node}{$node_name}{info}{host_name},
		name2 => "node::${node_name}::info::power_check_command", value2 => $an->data->{node}{$node_name}{info}{power_check_command},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node_name}{info}{host_name}) && ($an->data->{node}{$node_name}{info}{power_check_command}))
	{
		# Write the command to disk so that I can check the power state in the future when both nodes
		# are offline.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node_name}::info::power_check_command", value1 => $an->data->{node}{$node_name}{info}{power_check_command},
		}, file => $THIS_FILE, line => __LINE__});
		push @lines, "host_name = $an->data->{node}{$node_name}{info}{host_name}\n";
		push @lines, "power_check_command = $an->data->{node}{$node_name}{info}{power_check_command}\n";
		push @lines, "fence_methods = $an->data->{node}{$node_name}{info}{fence_methods}\n";
	}
	
	my $print_header = 0;
	foreach my $this_host (sort {$a cmp $b} keys %{$an->data->{node}{$node_name}{hosts}})
	{
		next if not $this_host;
		next if not $an->data->{node}{$node_name}{hosts}{$this_host}{ip};
		if (not $print_header)
		{
			push @lines, "#! start hosts !#\n";
			$print_header = 1;
		}
		push @lines, $an->data->{node}{$node_name}{hosts}{$this_host}{ip}."\t$this_host\n";
	}
	if ($print_header)
	{
		push @lines, "#! end hosts !#\n";
	}
	
	if (@lines > 0)
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cache_file", value1 => $cache_file,
		}, file => $THIS_FILE, line => __LINE__});
		my $shell_call = "$cache_file";
		open (my $file_handle, ">", "$shell_call") or error($an, $an->String->get({key => "message_0050", variables => { 
				cache_file	=>	$cache_file,
				uid		=>	$<,
				error		=>	$!,
			}}));
		foreach my $line (@lines)
		{
			print $file_handle $line;
		}
		close $file_handle;
	}
	
	return(0);
}

# This sorts out some stuff after both nodes have been scanned.
sub _post_scan_calculations
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_post_scan_calculations" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	$an->data->{resources}{total_ram}     = 0;
	$an->data->{resources}{total_cores}   = 0;
	$an->data->{resources}{total_threads} = 0;
	foreach my $node_name (sort {$a cmp $b} @{$an->data->{up_nodes}})
	{
		# Record this node's RAM and CPU as the maximum available if the max cores and max ram is 0 
		# or greater than that on this node.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "resources::total_ram",                       value1 => $an->data->{resources}{total_ram},
			name2 => "node::${node_name}::hardware::total_memory", value2 => $an->data->{node}{$node_name}{hardware}{total_memory},
		}, file => $THIS_FILE, line => __LINE__});
		
		if ((not $an->data->{resources}{total_ram}) or ($an->data->{node}{$node_name}{hardware}{total_memory} < $an->data->{resources}{total_ram}))
		{
			$an->data->{resources}{total_ram} = $an->data->{node}{$node_name}{hardware}{total_memory};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "resources::total_ram", value1 => $an->data->{resources}{total_ram},
			}, file => $THIS_FILE, line => __LINE__});
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "resources::total_ram", value1 => $an->data->{resources}{total_ram},
		}, file => $THIS_FILE, line => __LINE__});
		
		# Set by meminfo, if less (needed to catch mirrored RAM)
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node_name}::hardware::meminfo::memtotal", value1 => $an->data->{node}{$node_name}{hardware}{meminfo}{memtotal},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{node}{$node_name}{hardware}{meminfo}{memtotal} < $an->data->{resources}{total_ram})
		{
			$an->data->{resources}{total_ram} = $an->data->{node}{$node_name}{hardware}{meminfo}{memtotal};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "resources::total_ram", value1 => $an->data->{resources}{total_ram},
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "resources::total_cores",                         value1 => $an->data->{resources}{total_cores},
			name2 => "node::${node_name}::hardware::total_node_cores", value2 => $an->data->{node}{$node_name}{hardware}{total_node_cores},
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $an->data->{resources}{total_cores}) or ($an->data->{node}{$node_name}{hardware}{total_node_cores} < $an->data->{resources}{total_cores}))
		{
			$an->data->{resources}{total_cores} = $an->data->{node}{$node_name}{hardware}{total_node_cores};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "resources::total_cores", value1 => $an->data->{resources}{total_cores},
			}, file => $THIS_FILE, line => __LINE__});
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "resources::total_threads",                       value1 => $an->data->{resources}{total_threads},
			name2 => "node::${node_name}::hardware::total_node_cores", value2 => $an->data->{node}{$node_name}{hardware}{total_node_cores},
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $an->data->{resources}{total_threads}) or ($an->data->{node}{$node_name}{hardware}{total_node_threads} < $an->data->{resources}{total_threads}))
		{
			$an->data->{resources}{total_threads} = $an->data->{node}{$node_name}{hardware}{total_node_threads};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "resources::total_threads", value1 => $an->data->{resources}{total_threads},
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Record the VG info. I only record the first node I see as I only care about clustered VGs 
		# and they are, by definition, identical.
		foreach my $vg (sort {$a cmp $b} keys %{$an->data->{node}{$node_name}{hardware}{lvm}{vg}})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
				name1 => "node::${node_name}::hardware::lvm::vg::${vg}::clustered",  value1 => $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$vg}{clustered},
				name2 => "node::${node_name}::hardware::lvm::vg::${vg}::size",       value2 => $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$vg}{size},
				name3 => "node::${node_name}::hardware::lvm::vg::${vg}::used_space", value3 => $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$vg}{used_space},
				name4 => "node::${node_name}::hardware::lvm::vg::${vg}::free_space", value4 => $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$vg}{free_space},
				name5 => "node::${node_name}::hardware::lvm::vg::${vg}::pv_name",    value5 => $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$vg}{pv_name},
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{resources}{vg}{$vg}{clustered}  = $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$vg}{clustered}  if not $an->data->{resources}{vg}{$vg}{clustered};
			$an->data->{resources}{vg}{$vg}{pv_name}    = $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$vg}{pv_name}    if not $an->data->{resources}{vg}{$vg}{pv_name};
			$an->data->{resources}{vg}{$vg}{pe_size}    = $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$vg}{pe_size}    if not $an->data->{resources}{vg}{$vg}{pe_size};
			$an->data->{resources}{vg}{$vg}{total_pe}   = $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$vg}{total_pe}   if not $an->data->{resources}{vg}{$vg}{total_pe};
			$an->data->{resources}{vg}{$vg}{used_pe}    = $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$vg}{used_pe}    if not $an->data->{resources}{vg}{$vg}{used_pe};
			$an->data->{resources}{vg}{$vg}{free_pe}    = $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$vg}{free_pe}    if not $an->data->{resources}{vg}{$vg}{free_pe};
			$an->data->{resources}{vg}{$vg}{size}       = $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$vg}{size}       if not $an->data->{resources}{vg}{$vg}{size};
			$an->data->{resources}{vg}{$vg}{used_space} = $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$vg}{used_space} if not $an->data->{resources}{vg}{$vg}{used_space};
			$an->data->{resources}{vg}{$vg}{free_space} = $an->data->{node}{$node_name}{hardware}{lvm}{vg}{$vg}{free_space} if not $an->data->{resources}{vg}{$vg}{free_space};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0009", message_variables => {
				name1 => "resources::vg::${vg}::clustered",  value1 => $an->data->{resources}{vg}{$vg}{clustered},
				name2 => "resources::vg::${vg}::pv_name",    value2 => $an->data->{resources}{vg}{$vg}{pv_name},
				name3 => "resources::vg::${vg}::pe_size",    value3 => $an->data->{resources}{vg}{$vg}{pe_size},
				name4 => "resources::vg::${vg}::total_pe",   value4 => $an->data->{resources}{vg}{$vg}{total_pe},
				name5 => "resources::vg::${vg}::used_pe",    value5 => $an->data->{resources}{vg}{$vg}{used_pe},
				name6 => "resources::vg::${vg}::free_pe",    value6 => $an->data->{resources}{vg}{$vg}{free_pe},
				name7 => "resources::vg::${vg}::size",       value7 => $an->data->{resources}{vg}{$vg}{size},
				name8 => "resources::vg::${vg}::used_space", value8 => $an->data->{resources}{vg}{$vg}{used_space},
				name9 => "resources::vg::${vg}::free_space", value9 => $an->data->{resources}{vg}{$vg}{free_space},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If both nodes have a given daemon down, then some data may be unavailable. This saves logic when 
	# such checks are needed.
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node1_name = $an->data->{sys}{anvil}{node1}{name};
	my $node2_name = $an->data->{sys}{anvil}{node2}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "anvil_uuid",  value1 => $anvil_uuid,
		name2 => "anvil_name",  value2 => $anvil_name,
		name3 => "node1_name",  value3 => $node1_name,
		name4 => "node2_name",  value4 => $node2_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->data->{sys}{gfs2_down} = 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node1_name}::daemon::gfs2::exit_code", value1 => $an->data->{node}{$node1_name}{daemon}{gfs2}{exit_code},
		name2 => "node::${node2_name}::daemon::gfs2::exit_code", value2 => $an->data->{node}{$node2_name}{daemon}{gfs2}{exit_code},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node1_name}{daemon}{gfs2}{exit_code} ne "0") && ($an->data->{node}{$node2_name}{daemon}{gfs2}{exit_code} ne "0"))
	{
		$an->data->{sys}{gfs2_down} = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::gfs2_down", value1 => $an->data->{sys}{gfs2_down},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->data->{sys}{clvmd_down} = 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node1_name}::daemon::clvmd::exit_code", value1 => $an->data->{node}{$node1_name}{daemon}{clvmd}{exit_code},
		name2 => "node::${node2_name}::daemon::clvmd::exit_code", value2 => $an->data->{node}{$node2_name}{daemon}{clvmd}{exit_code},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node1_name}{daemon}{clvmd}{exit_code} ne "0") && ($an->data->{node}{$node2_name}{daemon}{clvmd}{exit_code} ne "0"))
	{
		$an->data->{sys}{clvmd_down} = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::clvmd_down", value1 => $an->data->{sys}{clvmd_down},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->data->{sys}{drbd_down} = 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node1_name}::daemon::drbd::exit_code", value1 => $an->data->{node}{$node1_name}{daemon}{drbd}{exit_code},
		name2 => "node::${node2_name}::daemon::drbd::exit_code", value2 => $an->data->{node}{$node2_name}{daemon}{drbd}{exit_code},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node1_name}{daemon}{drbd}{exit_code} ne "0") && ($an->data->{node}{$node2_name}{daemon}{drbd}{exit_code} ne "0"))
	{
		$an->data->{sys}{drbd_down} = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::drbd_down", value1 => $an->data->{sys}{drbd_down},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->data->{sys}{rgmanager_down} = 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node1_name}::daemon::rgmanager::exit_code", value1 => $an->data->{node}{$node1_name}{daemon}{rgmanager}{exit_code},
		name2 => "node::${node2_name}::daemon::rgmanager::exit_code", value2 => $an->data->{node}{$node2_name}{daemon}{rgmanager}{exit_code},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node1_name}{daemon}{rgmanager}{exit_code} ne "0") && ($an->data->{node}{$node2_name}{daemon}{rgmanager}{exit_code} ne "0"))
	{
		$an->data->{sys}{rgmanager_down} = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::rgmanager_down", value1 => $an->data->{sys}{rgmanager_down},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->data->{sys}{cman_down} = 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node1_name}::daemon::cman::exit_code", value1 => $an->data->{node}{$node1_name}{daemon}{cman}{exit_code},
		name2 => "node::${node2_name}::daemon::cman::exit_code", value2 => $an->data->{node}{$node2_name}{daemon}{cman}{exit_code},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node1_name}{daemon}{cman}{exit_code} ne "0") && ($an->data->{node}{$node2_name}{daemon}{cman}{exit_code} ne "0"))
	{
		$an->data->{sys}{cman_down} = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::cman_down", value1 => $an->data->{sys}{cman_down},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Loop through the DRBD resources on each node and see if any resources are 'SyncSource', disable
	# withdrawing that node. 
	foreach my $node_name ($node1_name, $node2_name)
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node_name", value1 => $node_name,
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $resource (sort {$a cmp $b} keys %{$an->data->{node}{$node_name}{drbd}{resource}})
		{
			my $connection_state = $an->data->{node}{$node_name}{drbd}{resource}{$resource}{connection_state};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "resource",         value1 => $resource,
				name2 => "connection_state", value2 => $connection_state,
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($connection_state =~ /SyncSource/)
			{
				$an->data->{node}{$node_name}{enable_withdraw} = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node_name}::enable_withdraw", value1 => $an->data->{node}{$node_name}{enable_withdraw},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return (0);
}

# This makes an ssh call to the node and sends a simple 'poweroff' command.
sub _poweroff_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_poweroff_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $node_name  = $an->data->{cgi}{node_name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "node_name",  value2 => $node_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $anvil_uuid)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0148", code => 148, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	if (not $node_name)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0149", code => 149, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Has the timer expired?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "time",        value1 => time,
		name2 => "cgi::expire", value2 => $an->data->{cgi}{expire},
	}, file => $THIS_FILE, line => __LINE__});
	if (time > $an->data->{cgi}{expire})
	{
		# Abort!
		my $say_title   = $an->String->get({key => "title_0187"});
		my $say_message = $an->String->get({key => "message_0446", variables => { node => $an->data->{cgi}{node_cluster_name} }});
		print $an->Web->template({file => "server.html", template => "request-expired", replace => { 
			title		=>	$say_title,
			message		=>	$say_message,
		}});
		return(1);
	}
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	my $node_key = $an->data->{sys}{node_name}{$node_name}{node_key};
	if (not $node_key)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0150", message_variables => { node_name => $node_name }, code => 150, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Make sure it is still safe to proceed.
	my $proceed = $an->data->{node}{$node_name}{enable_poweroff};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "proceed", value1 => $proceed,
	}, file => $THIS_FILE, line => __LINE__});
	if ($proceed)
	{
		my $node_uuid = $an->data->{sys}{anvil}{$node_key}{uuid};
		my $node_name = $an->data->{sys}{anvil}{$node_key}{name};
		my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
		my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
		my $password  = $an->data->{sys}{anvil}{$node_key}{password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "node_uuid", value1 => $node_uuid,
			name2 => "node_name", value2 => $node_name,
			name3 => "target",    value3 => $target,
			name4 => "port",      value4 => $port,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Call the 'poweroff'.
		my $say_title   = $an->String->get({key => "title_0061", variables => { node_name => $node_name }});
		my $say_message = $an->String->get({key => "message_0213", variables => { node_name => $node_name }});
		print $an->Web->template({file => "server.html", template => "poweroff-node-header", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});
		
		# Tell ScanCore that we're cleanly shutting down so we don't auto-reboot the node.
		$an->Striker->mark_node_as_clean_off({node_uuid => $node_uuid});
		
		# Shut it down now.
		my $output = $an->System->poweroff({
			target   => $target,
			port     => $port,
			password => $password,
		});
		foreach my $line (split/\n/, $output)
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /poweroff: (.*)$/)
			{
				my $victim = $1;
				if ($victim eq $target)
				{
					# Success
					$line = $an->String->get({key => "message_0477", variables => { node_name => $node_name }});
				}
				else
				{
					# wat...
					$line = $an->String->get({key => "message_0478", variables => { node_name => $node_name, victim => $victim }});
				}
			}
			else
			{
				$line = $an->Web->parse_text_line({line => $line});
			}
			
			my $message = ($line =~ /^(.*)\[/)[0];
			my $status  = ($line =~ /(\[.*)$/)[0];
			if (not $message)
			{
				$message = $line;
				$status  = "";
			}
			print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
				status	=>	$status,
				message	=>	$message,
			}});
		}
		print $an->Web->template({file => "server.html", template => "poweroff-node-footer"});
	}
	else
	{
		# Aborted, in use now.
		my $say_title   = $an->String->get({key => "title_0062", variables => { node_name => $node_name }});
		my $say_message = $an->String->get({key => "message_0214", variables => { node_name => $node_name }});
		print $an->Web->template({file => "server.html", template => "poweroff-node-aborted", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});
	}
	
	$an->Striker->_footer();
	
	return(0);
}

# This uses the fence methods, as defined in cluster.conf and in the proper order, to fence the target node.
sub _poweron_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_poweron_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# grab the CGI data
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $node_name  = $an->data->{cgi}{node_name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "node_name",  value2 => $node_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $anvil_uuid)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0151", code => 151, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	if (not $node_name)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0152", code => 152, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	### NOTE: The target node should be off, so 'target' will likely be empty.
	# Pull out the rest of the data
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_key   = $an->data->{sys}{node_name}{$node_name}{node_key};
	my $peer_key   = $an->data->{sys}{node_name}{$node_name}{peer_node_key};
	my $peer_name  = $an->data->{sys}{anvil}{$peer_key}{name};
	my $peer_uuid  = $an->data->{sys}{anvil}{$peer_key}{uuid};
	my $node_uuid  = $an->data->{sys}{anvil}{$node_key}{uuid};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
		name1 => "anvil_name", value1 => $anvil_name,
		name2 => "node_key",   value2 => $node_key,
		name3 => "peer_key",   value3 => $peer_key,
		name4 => "peer_uuid",  value4 => $peer_uuid,
		name5 => "node_uuid",  value5 => $node_uuid,
		name6 => "peer_name",  value6 => $peer_name,
		name7 => "target",     value7 => $target,
		name8 => "port",       value8 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Die if I don't know who my target is.
	if (not $node_key)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0150", message_variables => { node_name => $node_name }, code => 150, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	# Is the node already online?
	my $state = $an->ScanCore->target_power({target => $node_uuid});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "state", value1 => $state, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Unknown error is the default.
	my $proceed = 0;
	my $abort_reason = $an->String->get({key => "message_0224", variables => { node => $node_name }});
	if ($state eq "off")
	{
		$proceed = 1;
	}
	elsif ($state eq "on")
	{
		# Already on
		$abort_reason = $an->String->get({key => "message_0225", variables => { node_name => $node_name }});
	}
	elsif ($state eq "unknown")
	{
		# Unable to contact the IPMI BMC
		$abort_reason = $an->String->get({key => "message_0226", variables => { node_name => $node_name }});
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name", value1 => $node_name,
		name2 => "proceed",   value2 => $proceed,
	}, file => $THIS_FILE, line => __LINE__});
	
	if ($proceed)
	{
		# It is still off.
		my $say_title   = $an->String->get({key => "title_0065", variables => { node_name => $node_name }});
		my $say_message = $an->String->get({key => "message_0222", variables => { node_name => $node_name }});
		print $an->Web->template({file => "server.html", template => "poweron-node-header", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});

		# Now, if I can reach the peer node, use it to power on the target. Otherwise, we'll try to power it
		# on using cached 'power_check' data, if available.
		if ($an->data->{sys}{anvil}{$peer_key}{online})
		{
			# Sweet, power on via the peer.
			my $target   = $an->data->{sys}{anvil}{$peer_key}{use_ip};
			my $port     = $an->data->{sys}{anvil}{$peer_key}{use_port};
			my $password = $an->data->{sys}{anvil}{$peer_key}{password};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "target", value1 => $target,
				name2 => "port",   value2 => $port,
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
				name1 => "password", value1 => $password,
			}, file => $THIS_FILE, line => __LINE__});
			
			# Fencing is off -> verify -> on. Being already off, this effectively just boots the node.
			my $shell_call = $an->data->{path}{fence_node}." -v $node_name";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "target",     value1 => $target,
				name2 => "shell_call", value2 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$target,
				port		=>	$port, 
				password	=>	$password,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				$line = $an->Web->parse_text_line({line => $line});
				print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
			}
			
			# Update ScanCore to tell it that the nodes should now be booted.
			$an->Striker->mark_node_as_clean_on({node_uuid => $node_uuid});
			print $an->Web->template({file => "server.html", template => "poweron-node-close-tr"});
		}
		else
		{
			# OK, use cache to try to boot it locally
			my $state = $an->ScanCore->target_power({
					task   => "on",
					target => $node_uuid,
				});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "state", value1 => $state, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($state eq "on")
			{
				# Success
				my $line = $an->String->get({key => "message_0479", variables => { node_name => $node_name }});
				print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
				$an->Striker->mark_node_as_clean_on({node_uuid => $node_uuid});
			}
			elsif ($state eq "off")
			{
				# Something went wrong. We got its state but it is still off.
				my $line = $an->String->get({key => "message_0480", variables => { node_name => $node_name }});
				print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
			}
			else
			{
				# It is in an unknown state
				my $line = $an->String->get({key => "message_0481", variables => { node_name => $node_name }});
				print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
			}
		}
	}
	
	print $an->Web->template({file => "server.html", template => "poweron-node-footer"});
	$an->Striker->_footer();
	
	return(0);
}

# This sorts out what needs to happen if 'task' was set.
sub _process_task
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "process_task" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "cgi::task",    value1 => $an->data->{cgi}{task}, 
		name2 => "cgi::confirm", value2 => $an->data->{cgi}{confirm}, 
		name3 => "anvil_uuid",   value3 => $anvil_uuid,
		name4 => "anvil_name",   value4 => $anvil_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	if ($an->data->{cgi}{task} eq "withdraw")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			$an->Striker->_withdraw_node();
		}
		else
		{
			$an->Striker->_confirm_withdraw_node();
		}
	}
	elsif ($an->data->{cgi}{task} eq "join_anvil")
	{
		# If the peer is accessible on all three networks and if cman is running on the peer, don't
		# ask for confirmation.
		my $confirm_reason = "";
		if (not $an->data->{cgi}{confirm})
		{
			my ($peer_access, $peer_cman_up) = $an->Striker->_check_peer_access();
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "peer_access",  value1 => $peer_access, 
				name2 => "peer_cman_up", value2 => $peer_cman_up,
			}, file => $THIS_FILE, line => __LINE__});
			if (($peer_access) && ($peer_cman_up))
			{
				$an->data->{cgi}{confirm} = "true";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "cgi::confirm", value1 => $an->data->{cgi}{confirm}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ((not $peer_access) && (not $peer_cman_up))
			{
				$confirm_reason = "#!string!message_0148!#<br />#!string!message_0149!#";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "confirm_reason", value1 => $confirm_reason, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif (not $peer_access)
			{
				$confirm_reason = "#!string!message_0149!#";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "confirm_reason", value1 => $confirm_reason, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif (not $peer_cman_up)
			{
				$confirm_reason = "#!string!message_0148!#";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "confirm_reason", value1 => $confirm_reason, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			$an->Striker->_join_anvil();
		}
		else
		{
			$an->Striker->_confirm_join_anvil({confirm_reason => $confirm_reason});
		}
	}
	elsif ($an->data->{cgi}{task} eq "dual_join")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			$an->Striker->_dual_join();
		}
		else
		{
			$an->Striker->_confirm_dual_join();
		}
	}
	elsif ($an->data->{cgi}{task} eq "fence_node")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			$an->Striker->_fence_node();
		}
		else
		{
			$an->Striker->_confirm_fence_node();
		}
	}
	elsif ($an->data->{cgi}{task} eq "poweroff_node")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			$an->Striker->_poweroff_node();
		}
		else
		{
			$an->Striker->_confirm_poweroff_node();
		}
	}
	elsif ($an->data->{cgi}{task} eq "poweron_node")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			$an->Striker->_poweron_node();
		}
		else
		{
			$an->Striker->_confirm_poweron_node();
		}
	}
	elsif ($an->data->{cgi}{task} eq "dual_boot")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			$an->Striker->_dual_boot();
		}
		else
		{
			$an->Striker->_confirm_dual_boot();
		}
	}
	elsif ($an->data->{cgi}{task} eq "cold_stop")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			# The '1' cancels the APC UPS watchdog timer, if used.
			$an->Striker->_cold_stop_anvil({cancel_ups => 1});
		}
		else
		{
			$an->Striker->_confirm_cold_stop_anvil();
		}
	}
	elsif ($an->data->{cgi}{task} eq "start_server")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			$an->Striker->_start_server();
		}
		else
		{
			$an->Striker->_confirm_start_server();
		}
	}
	elsif ($an->data->{cgi}{task} eq "stop_server")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			$an->Striker->_stop_server();
		}
		else
		{
			$an->Striker->_confirm_stop_server();
		}
	}
	elsif ($an->data->{cgi}{task} eq "force_off_server")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			$an->Striker->_force_off_server();
		}
		else
		{
			$an->Striker->_confirm_force_off_server();
		}
	}
	elsif ($an->data->{cgi}{task} eq "delete_server")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			$an->Striker->_delete_server();
		}
		else
		{
			$an->Striker->_confirm_delete_server();
		}
	}
	elsif ($an->data->{cgi}{task} eq "migrate_server")
	{
		if ($an->data->{cgi}{confirm})
		{
			$an->Striker->_migrate_server();
		}
		else
		{
			$an->Striker->_confirm_migrate_server();
		}
	}
	elsif ($an->data->{cgi}{task} eq "provision")
	{
		### TODO: If '$an->data->{cgi}{os_variant}' is "generic", warn the user and ask them to 
		###       confirm that they really want to do this.
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			if ($an->Striker->_verify_server_config())
			{
				# We're golden
				$an->Log->entry({log_level => 2, message_key => "log_0216", file => $THIS_FILE, line => __LINE__});
				$an->Striker->_provision_server();
			}
			else
			{
				# Something wasn't sane.
				$an->Log->entry({log_level => 2, message_key => "log_0217", file => $THIS_FILE, line => __LINE__});
				$an->Striker->_confirm_provision_server();
			}
		}
		else
		{
			$an->Striker->_confirm_provision_server();
		}
	}
	elsif ($an->data->{cgi}{task} eq "add_server")
	{
		# This is called after provisioning a server usually, so no need to confirm
		$an->Striker->_add_server_to_anvil({skip_scan => 0});
	}
	elsif ($an->data->{cgi}{task} eq "manage_server")
	{
		$an->Striker->_manage_server();
	}
	elsif ($an->data->{cgi}{task} eq "display_health")
	{
		# I need to do a short scan of the node.
		my $node_name  = $an->data->{cgi}{node_name};
		my $node_key   = $an->data->{sys}{node_name}{$node_name}{node_key};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node_name", value1 => $node_name,
			name2 => "node_key",  value2 => $node_key,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Striker->scan_node({uuid => $an->data->{sys}{anvil}{$node_key}{uuid}, short_scan => 1});
		
		# Now I can gather the rest of the data.
		my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
		my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
		my $password   = $an->data->{sys}{anvil}{$node_key}{password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target", value1 => $target,
			name2 => "port",   value2 => $port,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password,
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->Striker->_get_storage_data();
		
		if ((not $an->data->{storage}{is}{lsi}) && 
		    (not $an->data->{storage}{is}{hp})  &&
		    (not $an->data->{storage}{is}{mdadm}))
		{
			# No managers found
			my $say_title = $an->String->get({key => "title_0016", variables => { node => $an->data->{cgi}{node} }});
			my $say_message = $an->String->get({key => "message_0051", variables => { node_name => $an->data->{cgi}{node_name} }});
			print $an->Web->template({file => "lsi-storage.html", template => "no-managers-found", replace => { 
				title	=>	$say_title,
				message	=>	$say_message,
			}});
		}
		else
		{
			my $display_details = 1;
			if ($an->data->{cgi}{'do'})
			{
				if ($an->data->{cgi}{'do'} eq "start_id_disk")
				{
					$an->HardwareLSI->_control_disk_id_led({
						action   => "start",
						target   => $target, 
						port     => $port, 
						password => $password, 
					});
				}
				elsif ($an->data->{cgi}{'do'} eq "stop_id_disk")
				{
					$an->HardwareLSI->_control_disk_id_led({
						action   => "stop",
						target   => $target, 
						port     => $port, 
						password => $password, 
					});
				}
				elsif ($an->data->{cgi}{'do'} eq "make_disk_good")
				{
					$an->HardwareLSI->_make_disk_good({
						target   => $target, 
						port     => $port, 
						password => $password, 
					});
				}
				elsif ($an->data->{cgi}{'do'} eq "add_disk_to_array")
				{
					$an->HardwareLSI->_add_disk_to_array({
						target   => $target, 
						port     => $port, 
						password => $password, 
					});
				}
				elsif ($an->data->{cgi}{'do'} eq "put_disk_online")
				{
					$an->HardwareLSI->_put_disk_online({
						target   => $target, 
						port     => $port, 
						password => $password, 
					});
				}
				elsif ($an->data->{cgi}{'do'} eq "put_disk_offline")
				{
					$an->HardwareLSI->_put_disk_offline({
						target   => $target, 
						port     => $port, 
						password => $password, 
					});
				}
				elsif ($an->data->{cgi}{'do'} eq "mark_disk_missing")
				{
					$an->HardwareLSI->_mark_disk_missing({
						target   => $target, 
						port     => $port, 
						password => $password, 
					});
				}
				elsif ($an->data->{cgi}{'do'} eq "spin_disk_down")
				{
					$an->HardwareLSI->_spin_disk_down({
						target   => $target, 
						port     => $port, 
						password => $password, 
					});
				}
				elsif ($an->data->{cgi}{'do'} eq "spin_disk_up")
				{
					$an->HardwareLSI->_spin_disk_up({
						target   => $target, 
						port     => $port, 
						password => $password, 
					});
				}
				elsif ($an->data->{cgi}{'do'} eq "make_disk_hot_spare")
				{
					$an->HardwareLSI->_make_disk_hot_spare({
						target   => $target, 
						port     => $port, 
						password => $password, 
					});
				}
				elsif ($an->data->{cgi}{'do'} eq "unmake_disk_as_hot_spare")
				{
					$an->HardwareLSI->_unmake_disk_as_hot_spare({
						target   => $target, 
						port     => $port, 
						password => $password, 
					});
				}
				elsif ($an->data->{cgi}{'do'} eq "clear_foreign_state")
				{
					$an->HardwareLSI->_clear_foreign_state({
						target   => $target, 
						port     => $port, 
						password => $password, 
					});
				}
				### Prepare Unconfigured drives for removal
				# MegaCli64 AdpSetProp AlarmDsbl aN|a0,1,2|aALL 
	
				# Rescan to update our view.
				$an->HardwareLSI->_get_storage_data({
					target   => $target, 
					port     => $port, 
					password => $password, 
				});
			}
			if ($display_details)
			{
				$an->HardwareLSI->_display_node_health({
					target   => $target, 
					port     => $port, 
					password => $password, 
				});
			}
		}
	}
	else
	{
		# Dirty debugging...
		print "<pre>\n";
		foreach my $var (sort {$a cmp $b} keys %{$an->data->{cgi}})
		{
			print "var: [$var] -> [".$an->data->{cgi}{$var}."]\n" if $an->data->{cgi}{$var};
		}
		print "</pre>";
	}
	
	return(0);
}

# This actually kicks off the VM.
sub _provision_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_provision_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $say_title = $an->String->get({key => "title_0115", variables => { server => $an->data->{new_server}{name} }});
	print $an->Web->template({file => "server.html", template => "provision-server-header", replace => { title => $say_title }});
	
	# I need to know what the bridge is called.
	my $node_name = $an->data->{new_server}{host_node};
	my $node_key  = $an->data->{sys}{node_name}{$node_name}{node_key};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $bridge    = $an->Get->bridge_name({
			target   => $target,
			port     => $port,
			password => $password,
		});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "node_name", value1 => $node_name,
		name2 => "node_key",  value2 => $node_key,
		name3 => "target",    value3 => $target,
		name4 => "port",      value4 => $port,
		name5 => "bridge",    value5 => $bridge,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Create the LVs
	my $provision = "";
	my @logical_volumes;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "new_server::vg", value1 => $an->data->{new_server}{vg},
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $vg (keys %{$an->data->{new_server}{vg}})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "vg", value1 => $vg,
		}, file => $THIS_FILE, line => __LINE__});
		for (my $i = 0; $i < @{$an->data->{new_server}{vg}{$vg}{lvcreate_size}}; $i++)
		{
			my $lv_size   = $an->data->{new_server}{vg}{$vg}{lvcreate_size}->[$i];
			my $lv_device = "/dev/$vg/".$an->data->{new_server}{name}."_$i";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
				name1 => "i",         value1 => $i,
				name2 => "vg",        value2 => $vg,
				name3 => "lv_size",   value3 => $lv_size,
				name4 => "lv_device", value4 => $lv_device,
			}, file => $THIS_FILE, line => __LINE__});
			$provision .= "if [ ! -e '/dev/$vg/".$an->data->{new_server}{name}."_$i' ];\n";
			$provision .= "then\n";
			if (lc($lv_size) eq "all")
			{
				$provision .= "    ".$an->data->{path}{lvcreate}." -l 100\%FREE -n ".$an->data->{new_server}{name}."_$i $vg\n";
			}
			elsif ($lv_size =~ /^(\d+\.?\d+?)%$/)
			{
				my $size = $1;
				$provision .= "    ".$an->data->{path}{lvcreate}." -l $size\%FREE -n ".$an->data->{new_server}{name}."_$i $vg\n";
			}
			else
			{
				$provision .= "    ".$an->data->{path}{lvcreate}." -L ${lv_size}GiB -n ".$an->data->{new_server}{name}."_$i $vg\n";
			}
			$provision .= "fi\n";
			push @logical_volumes, $lv_device;
		}
	}
	
	# Setup the 'virt-install' call.
	$provision .= "virt-install --connect qemu:///system \\\\\n";
	$provision .= "  --name ".$an->data->{new_server}{name}." \\\\\n";
	$provision .= "  --ram ".$an->data->{new_server}{ram}." \\\\\n";
	$provision .= "  --arch x86_64 \\\\\n";
	$provision .= "  --vcpus ".$an->data->{new_server}{cpu_cores}." \\\\\n";
	$provision .= "  --cpu host \\\\\n";
	$provision .= "  --cdrom '".$an->data->{path}{shared_files}."/".$an->data->{new_server}{install_iso}."' \\\\\n";
	$provision .= "  --boot menu=on \\\\\n";
	if ($an->data->{cgi}{driver_iso})
	{
		$provision .= "  --disk path='".$an->data->{path}{shared_files}."/".$an->data->{new_server}{driver_iso}."',device=cdrom --force\\\\\n";
	}
	$provision .= "  --os-variant ".$an->data->{cgi}{os_variant}." \\\\\n";
	
	# Connect to the discovered bridge
	my $nic_driver = "virtio";
	if (not $an->data->{new_server}{virtio}{nic})
	{
		$nic_driver = $an->data->{sys}{server}{alternate_nic_model} ? $an->data->{sys}{server}{alternate_nic_model} : "e1000";
	}
	$an->data->{sys}{server}{nic_count} = 1 if not $an->data->{sys}{server}{nic_count};
	for (1..$an->data->{sys}{server}{nic_count})
	{
		$provision .= "  --network bridge=$bridge,model=$nic_driver \\\\\n";
	}
	
	foreach my $lv_device (@logical_volumes)
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "lv_device",                value1 => $lv_device,
			name2 => "new_server::virtio::disk", value2 => $an->data->{new_server}{virtio}{disk},
		}, file => $THIS_FILE, line => __LINE__});
		$provision .= "  --disk path=$lv_device";
		if ($an->data->{new_server}{virtio}{disk})
		{
			### NOTE: Not anymore.
			# The 'cache=writeback' is required to support systems built on 4kb native sector 
			# size disks.
			$provision .= ",bus=virtio,cache=writethrough";
		}
		$provision .= " \\\\\n";
	}
	$provision .= "  --graphics spice \\\\\n";
	
	# TODO: (2016-06-08) There is a bug with provisioning Win7 and Win2008 servers with spice graphics.
	#       So until it is resolved, we will drop them to use more basic video. See:
	#       http://serverfault.com/questions/776406/windows-7-setup-hangs-at-starting-windows-using-proxmox-4-2
	if (($an->data->{cgi}{os_variant} eq "win7") or (($an->data->{cgi}{os_variant} eq "win2k8") && ($an->data->{new_server}{install_iso} !~ /12/)))
	{
		$provision .= "  --video cirrus \\\\\n";
	}
	
	# See https://www.redhat.com/archives/virt-tools-list/2014-August/msg00078.html
	# for why we're using '--noautoconsole --wait -1'.
	$provision .= "  --noautoconsole --wait -1 > /var/log/an-install_".$an->data->{new_server}{name}.".log &\n";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "provision", value1 => $provision,
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: Make sure the desired node is up and, if not, use the one good node.
	
	# Push the provision script into a file.
	my $shell_script = $an->data->{path}{shared_privision}."/".$an->data->{new_server}{name}.".sh";
	my $message      = $an->String->get({key => "message_0118", variables => { script => $shell_script }});
	print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $message }});
	
	my $shell_call = $an->data->{path}{echo}." \"$provision\" > $shell_script && ".$an->data->{path}{'chmod'}." 755 $shell_script";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
	}
	$message = $an->String->get({key => "message_0119", variables => { server => $an->data->{new_server}{name} }});
	print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $message }});
	
	### NOTE: Don't try to redirect output (2>&1 |), it causes errors I've not yet solved.
	# Run the script.
	$shell_call = $shell_script;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		next if $line =~ /One or more specified logical volume\(s\) not found./;
		if ($line =~ /No such file or directory/i)
		{
			 # Failed to write the provision file.
			$error = $an->String->get({key => "message_0330", variables => { provision_script => $shell_script }});
		}
		if ($line =~ /Unable to read from monitor/i)
		{
			### TODO: Delete the just-created LV
			# This can be caused by insufficient free RAM
			$error = $an->String->get({key => "message_0437", variables => { 
					server	=>	$an->data->{new_server}{name},
					node	=>	$node_name,
				}});
		}
		if ($line =~ /syntax error/i)
		{
			# Something is wrong with the provision script
			$error = $an->String->get({key => "message_0438", variables => { 
					provision_script	=>	$shell_script,
					error			=>	$line,
				}});
		}
		### Supressing output to clean-up what the user sees.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		#$an->Web->template({file => "server.html", template => "one-line-message-fixed-width", replace => { message => $line }});
	}
	if ($error)
	{
		print $an->Web->template({file => "server.html", template => "provision-server-problem", replace => { message => $error }});
	}
	else
	{
		print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => "#!string!message_0120!#" }});
		
		# Verify that the new VM is running.
		my $shell_call = $an->data->{path}{'sleep'}." 3; ".$an->data->{path}{virsh}." list | ".$an->data->{path}{'grep'}." -q '".$an->data->{new_server}{name}."'; ".$an->data->{path}{echo}." rc:\$?";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /^rc:(\d+)/)
			{
				# 0 == found
				# 1 == not found
				my $rc = $1;
				if ($rc eq "1")
				{
					# Server wasn't created, it seems.
					print $an->Web->template({file => "server.html", template => "provision-server-problem", replace => { message => "#!string!message_0434!#" }});
					$error = 1;
				}
			}
		}
	}
	
	# Done!
	#print $an->Web->template({file => "server.html", template => "provision-server-footer"});
	
	# Add the server to the Anvil! if no errors exist.
	if (not $error)
	{
		# Add it and then change the boot device to 'hd'.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "new_server::host_node", value1 => $an->data->{new_server}{host_node},
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->Striker->_add_server_to_anvil({skip_scan => 1});
	}
	
	return (0);
}

# This reads a server's definition file and pulls out information about the system.
sub _read_server_definition
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_read_server_definition" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $server     = $parameter->{server};
	
	if (not $server)
	{
		my $say_message = $an->String->get({key => "message_0469"});
		$an->Striker->_error({message => $say_message});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "server", value1 => $server,
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->data->{server}{$server}{definition_file} = "" if not defined $an->data->{server}{$server}{definition_file};
	$an->data->{server}{$server}{xml}             = "" if not defined $an->data->{server}{$server}{xml};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "server::${server}::definition_file", value1 => $an->data->{server}{$server}{definition_file},
	}, file => $THIS_FILE, line => __LINE__});

	# Here I want to parse the server definition XML. Hopefully it was already read in, but if not, I'll
	# go get it.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "server::${server}::xml",             value1 => $an->data->{server}{$server}{xml},
		name2 => "server::${server}::definition_file", value2 => $an->data->{server}{$server}{definition_file},
	}, file => $THIS_FILE, line => __LINE__});
	if ((not ref($an->data->{server}{$server}{xml}) eq "ARRAY") && ($an->data->{server}{$server}{definition_file}))
	{
		$an->data->{server}{$server}{raw_xml} = [];
		$an->data->{server}{$server}{xml}     = [];
		my $shell_call = $an->data->{path}{cat}." ".$an->data->{server}{$server}{definition_file};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			push @{$an->data->{server}{$server}{raw_xml}}, $line;
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			push @{$an->data->{server}{$server}{xml}}, $line;
		}
	}
	
	my $fill_raw_xml = 0;
	my $in_disk      = 0;
	my $in_interface = 0;
	my $current_bridge;
	my $current_device;
	my $current_mac_address;
	my $current_interface_type;
	if (not $an->data->{server}{$server}{xml})
	{
		# XML definition not found on the node.
		$an->Log->entry({log_level => 2, message_key => "log_0257", message_variables => {
			node   => $node_name, 
			server => $server, 
		}, file => $THIS_FILE, line => __LINE__});
		return (0);
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "server::${server}::raw_xml", value1 => $an->data->{server}{$server}{raw_xml},
	}, file => $THIS_FILE, line => __LINE__});
	if (not ref($an->data->{server}{$server}{raw_xml}) eq "ARRAY")
	{
		$an->data->{server}{$server}{raw_xml} = [];
		$fill_raw_xml                 = 1;
	}
	foreach my $line (@{$an->data->{server}{$server}{xml}})
	{
		next if not $line;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "server",           value1 => $server,
			name2 => "line",         value2 => $line,
			name3 => "fill_raw_xml", value3 => $fill_raw_xml,
		}, file => $THIS_FILE, line => __LINE__});
		push @{$an->data->{server}{$server}{raw_xml}}, $line if $fill_raw_xml;
		
		# Pull out RAM amount.
		if ($line =~ /<memory>(\d+)<\/memory>/)
		{
			# Record the memory, multiple by 1024 to get bytes.
			$an->data->{server}{$server}{details}{ram} =  $1;
			$an->data->{server}{$server}{details}{ram} *= 1024;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "server::${server}::details::ram", value1 => $an->data->{server}{$server}{details}{ram},
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /<memory unit='(.*?)'>(\d+)<\/memory>/)
		{
			# Record the memory, multiple by 1024 to get bytes.
			my $units                             = $1;
			my $ram                               = $2;
			   $an->data->{server}{$server}{details}{ram} = $an->Readable->hr_to_bytes({size => $ram, type => $units });
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name2 => "server::${server}::details::ram", value2 => $an->data->{server}{$server}{details}{ram},
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Pull out the CPU details
		if ($line =~ /<vcpu>(\d+)<\/vcpu>/)
		{
			$an->data->{server}{$server}{details}{cpu_count} = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "server::${server}::details::cpu_count", value1 => $an->data->{server}{$server}{details}{cpu_count},
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /<vcpu placement='(.*?)'>(\d+)<\/vcpu>/)
		{
			my $cpu_type                                = $1;
			   $an->data->{server}{$server}{details}{cpu_count} = $2;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "server::${server}::details::cpu_count", value1 => $an->data->{server}{$server}{details}{cpu_count},
				name2 => "type",                          value2 => $cpu_type,
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Pull out network details.
		if (($line =~ /<interface/) && ($line =~ /type='bridge'/))
		{
			$in_interface = 1;
			next;
		}
		elsif ($line =~ /<\/interface/)
		{
			# Record the values I found
			$an->data->{server}{$server}{details}{bridge}{$current_bridge}{device} = $current_device         ? $current_device         : "unknown";
			$an->data->{server}{$server}{details}{bridge}{$current_bridge}{mac}    = $current_mac_address    ? $current_mac_address    : "unknown";
			$an->data->{server}{$server}{details}{bridge}{$current_bridge}{type}   = $current_interface_type ? $current_interface_type : "unknown";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "server::${server}::details::bridge::${current_bridge}::device", value1 => $an->data->{server}{$server}{details}{bridge}{$current_bridge}{device},
				name2 => "server::${server}::details::bridge::${current_bridge}::mac",    value2 => $an->data->{server}{$server}{details}{bridge}{$current_bridge}{mac},
				name3 => "server::${server}::details::bridge::${current_bridge}::type",   value3 => $an->data->{server}{$server}{details}{bridge}{$current_bridge}{type},
			}, file => $THIS_FILE, line => __LINE__});
			$current_bridge         = "";
			$current_device         = "";
			$current_mac_address    = "";
			$current_interface_type = "";
			$in_interface           = 0;
			next;
		}
		if ($in_interface)
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "server",             value1 => $server,
				name2 => "interface line", value2 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /source bridge='(.*?)'/)
			{
				$current_bridge = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "server",             value1 => $server,
					name2 => "current_bridge", value2 => $current_bridge,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /mac address='(.*?)'/)
			{
				$current_mac_address = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "server",                  value1 => $server,
					name2 => "current_mac_address", value2 => $current_mac_address,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /target dev='(.*?)'/)
			{
				$current_device = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "server",             value1 => $server,
					name2 => "current_device", value2 => $current_device,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /model type='(.*?)'/)
			{
				$current_interface_type = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "server",                     value1 => $server,
					name2 => "current_interface_type", value2 => $current_interface_type,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Pull out disk info.
		if (($line =~ /<disk/) && ($line =~ /type='block'/) && ($line =~ /device='disk'/))
		{
			$in_disk = 1;
			next;
		}
		elsif ($line =~ /<\/disk/)
		{
			$in_disk = 0;
			next;
		}
		if ($in_disk)
		{
			if ($line =~ /source dev='(.*?)'/)
			{
				my $lv = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "server", value1 => $server,
					name2 => "lv", value2 => $lv,
				}, file => $THIS_FILE, line => __LINE__});
				$an->Striker->_check_lv({node => $node_uuid, server => $server, logical_volume => $lv});
			}
		}
		
		# Record what graphics we're using for remote connection.
		if ($line =~ /^<graphics /)
		{
			my ($port)   = ($line =~ / port='(\d+)'/);
			my ($type)   = ($line =~ / type='(.*?)'/);
			my ($listen) = ($line =~ / listen='(.*?)'/);
			$an->Log->entry({log_level => 2, message_key => "log_0230", message_variables => {
				server  => $server, 
				type    => $type,
				address => $listen, 
				port    => $port, 
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{server}{$server}{graphics}{type}     = $type;
			$an->data->{server}{$server}{graphics}{port}     = $port;
			$an->data->{server}{$server}{graphics}{'listen'} = $listen;
		}
	}
	my $xml_line_count = @{$an->data->{server}{$server}{raw_xml}};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "xml_line_count", value1 => $xml_line_count,
	}, file => $THIS_FILE, line => __LINE__});
	
	return (0);
}

# This ejects an ISO from a server's virtual optical drive.
sub _server_eject_media
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_server_eject_media" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid        = $an->data->{cgi}{anvil_uuid};
	my $anvil_name        = $an->data->{sys}{anvil}{name};
	my $server            = $an->data->{cgi}{server};
	my $device            = $an->data->{cgi}{device};
	my $drive             = $an->data->{cgi}{device};
	my $definition_file   = $an->data->{path}{shared_definitions}."/${server}.xml";
	my $server_is_running = $parameter->{server_is_running} ? $parameter->{server_is_running} : "";
	my $target            = $parameter->{target}            ? $parameter->{target}            : "";
	my $port              = $parameter->{port}              ? $parameter->{port}              : "";
	my $password          = $parameter->{password}          ? $parameter->{password}          : "";
	my $quiet             = $parameter->{quiet}             ? $parameter->{quiet}             : 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0010", message_variables => {
		name1  => "anvil_uuid",        value1  => $anvil_uuid, 
		name2  => "anvil_name",        value2  => $anvil_name, 
		name3  => "server",            value3  => $server, 
		name4  => "device",            value4  => $device, 
		name5  => "drive",             value5  => $drive, 
		name6  => "server_is_running", value6  => $server_is_running, 
		name7  => "definition_file",   value7  => $definition_file, 
		name8  => "target",            value8  => $target, 
		name9  => "port",              value9  => $port, 
		name10 => "quiet",             value10 => $quiet, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Die if I wasn't passed a server name.
	if (not $server)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0125", code => 125, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	if (not $quiet)
	{
		my $title = $an->String->get({key => "title_0031", variables => { device => $an->data->{cgi}{device} }});
		print $an->Web->template({file => "server.html", template => "eject-media-header", replace => { title => $title }});
	}
	
	my ($backup) = $an->Striker->_archive_file({
			target   => $target,
			port     => $port, 
			password => $password,
			file     => $definition_file, 
			quiet    => 1,
		});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "backup", value1 => $backup,
	}, file => $THIS_FILE, line => __LINE__});
	
	# How I do this depends on whether the server is running or not.
	if ($server_is_running)
	{
		# It is, so I will use 'virsh'.
		my $virsh_exit_code = 255;
		my $shell_call      = $an->data->{path}{virsh}." change-media $server $device --eject; ".$an->data->{path}{echo}." virsh:\$?";
		my $return          = [];
		if ($target)
		{
			# Remote call
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
			# Local call
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				push @{$return}, $line;
			}
			close $file_handle;
		}
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			next if not $line;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /virsh:(\d+)/)
			{
				$virsh_exit_code = $1;
			}
			else
			{
				if (not $quiet)
				{
					print $an->Web->template({file => "common.html", template => "shell-call-output", replace => { line => $line }});
				}
			}
		}
		if ($virsh_exit_code eq "1")
		{
			# Someone already ejected it.
			if (not $quiet)
			{
				print $an->Web->template({file => "server.html", template => "eject-media-failed-already-ejected"});
			}
			
			# Update the definition file in case it was missed by .
			$an->Striker->_update_server_definition({
				server_name => $server,
				target      => $target,
				port        => $port,
				password    => $password, 
			});
		}
		elsif ($virsh_exit_code eq "0")
		{
			if (not $quiet)
			{
				print $an->Web->template({file => "server.html", template => "eject-media-success"});
			}
			
			# Update the definition file.
			$an->Striker->_update_server_definition({
				server_name => $server,
				target      => $target,
				port        => $port,
				password    => $password, 
			});
		}
		else
		{
			   $virsh_exit_code = "-" if not defined $virsh_exit_code;
			my $say_error       = $an->String->get({key => "message_0073", variables => { 
					drive		=>	$drive,
					virsh_exit_code	=>	$virsh_exit_code,
				}});
			if (not $quiet)
			{
				print $an->Web->template({file => "server.html", template => "eject-media-failed-bad-exit-code", replace => { error => $say_error }});
			}
		}
	}
	else
	{
		# The server isn't running. Directly re-write the XML file.
		my $message = $an->String->get({key => "message_0070", variables => { server => $server }});
		if (not $quiet)
		{
			print $an->Web->template({file => "server.html", template => "eject-media-server-off", replace => { message => $message }});
		}
		my $in_cdrom       = 0;
		my $this_media     = "";
		my $this_device    = "";
		my $new_definition = "";
		my $server_uuid    = "";
		my $shell_call     = $an->data->{path}{cat}." $definition_file";
		my $return         = [];
		if ($target)
		{
			# Remote call
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
			# Local call
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				push @{$return}, $line;
			}
			close $file_handle;
		}
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			$new_definition .= "$line\n";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /<uuid>(.*?)<\/uuid>/)
			{
				$server_uuid = $1;
			}
			if (($line =~ /type='file'/) && ($line =~ /device='cdrom'/))
			{
				# Found an optical disk (DVD/CD).
				$an->Log->entry({log_level => 2, message_key => "log_0221", file => $THIS_FILE, line => __LINE__});
				$in_cdrom = 1;
			}
			if ($in_cdrom)
			{
				if ($line =~ /file='(.*?)'\/>/)
				{
					# Found media
					$this_media = $1;
					$an->Log->entry({log_level => 2, message_key => "log_0222", message_variables => {
						media => $this_media, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /dev='(.*?)'/)
				{
					# Found the device.
					$this_device = $1;
					$an->Log->entry({log_level => 2, message_key => "log_0223", message_variables => {
						device => $this_device, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /<\/disk>/)
				{
					# Check if this is what I want to eject.
					$an->Log->entry({log_level => 2, message_key => "log_0224", message_variables => {
						this_device   => $this_device, 
						target_device => $an->data->{cgi}{device}, 
					}, file => $THIS_FILE, line => __LINE__});
					if ($this_device eq $an->data->{cgi}{device})
					{
						# This is the device I want to unmount.
						$an->Log->entry({log_level => 2, message_key => "log_0225", file => $THIS_FILE, line => __LINE__});
						$new_definition =~ s/<disk(.*?)device='cdrom'(.*?)<source file='$this_media'\/>\s+(.*?)<\/disk>/<disk${1}device='cdrom'${2}${3}<\/disk>/s;
					}
					else
					{
						# It is not.
						$an->Log->entry({log_level => 2, message_key => "log_0226", file => $THIS_FILE, line => __LINE__});
					}
					$in_cdrom    = 0;
					$this_device = "";
					$this_media  = "";
				}
			}
		}
		$new_definition =~ s/(\S)\s+$/$1\n/;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "new_definition", value1 => $new_definition,
		}, file => $THIS_FILE, line => __LINE__});
		
		# See if I need to insert or edit any network interface driver elements.
		$new_definition = $an->Striker->_update_network_driver({xml => $new_definition});
		
		# Write the new definition file.
		if (not $quiet)
		{
			print $an->Web->template({file => "server.html", template => "saving-server-config"});
		}
		$shell_call = $an->data->{path}{echo}." \"$new_definition\" > $definition_file && ".$an->data->{path}{'chmod'}." 644 $definition_file";
		$return     = [];
		if ($target)
		{
			# Remote call
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
			# Local call
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				push @{$return}, $line;
			}
			close $file_handle;
		}
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if (not $quiet)
			{
				print $an->Web->template({file => "common.html", template => "shell-call-output", replace => { line => $line }});
			}
		}
		if (not $quiet)
		{
			print $an->Web->template({file => "server.html", template => "eject-media-footer"});
		}
		
		# Update the server's definition file in the database, if it actually changed, and register 
		# an alert.
		if ($an->Validate->is_uuid({uuid => $server_uuid}))
		{
			$an->ScanCore->insert_or_update_servers({
				server_uuid       => $server_uuid,
				server_definition => $new_definition,
				just_definition   => 1,
			});
		}
		
		# Lastly, copy the new definition to the stored XML for this server.
		  $an->data->{server}{$server}{xml}  = [];
		@{$an->data->{server}{$server}{xml}} = split/\n/, $new_definition;
	}
	
	return(0);
}

# This inserts an ISO into the server's virtual optical drive.
sub _server_insert_media
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_server_insert_media" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid        = $an->data->{cgi}{anvil_uuid};
	my $anvil_name        = $an->data->{sys}{anvil}{name};
	my $server            = $an->data->{cgi}{server};
	my $insert_media      = $parameter->{insert_media}      ? $parameter->{insert_media}      : "";
	my $insert_drive      = $parameter->{insert_drive}      ? $parameter->{insert_drive}      : "";
	my $server_is_running = $parameter->{server_is_running} ? $parameter->{server_is_running} : "";
	my $definition_file   = $an->data->{path}{shared_definitions}."/${server}.xml";
	my $target            = $parameter->{target}            ? $parameter->{target}            : "";
	my $port              = $parameter->{port}              ? $parameter->{port}              : "";
	my $password          = $parameter->{password}          ? $parameter->{password}          : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0009", message_variables => {
		name1 => "anvil_uuid",        value1 => $anvil_uuid, 
		name2 => "anvil_name",        value2 => $anvil_name, 
		name3 => "server",            value3 => $server, 
		name4 => "insert_media",      value4 => $insert_media, 
		name5 => "insert_drive",      value5 => $insert_drive, 
		name6 => "server_is_running", value6 => $server_is_running, 
		name7 => "definition_file",   value7 => $definition_file, 
		name8 => "target",            value8 => $target, 
		name9 => "port",              value9 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my ($backup) = $an->Striker->_archive_file({
			target   => $target,
			port     => $port, 
			password => $password,
			file     => $definition_file, 
			quiet    => 1,
		});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "backup", value1 => $backup,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $title = $an->String->get({key => "title_0030", variables => { 
		media	=>	$insert_media,
		drive	=>	$insert_drive,
	}});
	print $an->Web->template({file => "server.html", template => "insert-media-header", replace => { title => $title }});
	
	# How I do this depends on whether the server is running or not.
	if ($server_is_running)
	{
		# It is, so I will use 'virsh'.
		my $virsh_exit_code = 255;
		my $shell_call      = $an->data->{path}{virsh}." change-media $server $insert_drive --insert '".$an->data->{path}{shared_files}."/$insert_media'; ".$an->data->{path}{echo}." virsh:\$?";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			next if not $line;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /virsh:(\d+)/)
			{
				$virsh_exit_code = $1;
			}
			else
			{
				print $an->Web->template({file => "common.html", template => "shell-call-output", replace => { line => $line }});
			}
		}
		if ($virsh_exit_code eq "1")
		{
			# Disk already inserted.
			print $an->Web->template({file => "server.html", template => "insert-media-failed-already-mounted"});

			# Update the definition file in case it was missed earlier.
			$an->Striker->_update_server_definition({
				server_name => $server,
				target      => $target,
				port        => $port,
				password    => $password, 
			});
		}
		elsif ($virsh_exit_code eq "0")
		{
			print $an->Web->template({file => "server.html", template => "insert-media-success"});
			
			# Update the definition file.
			$an->Striker->_update_server_definition({
				server_name => $server,
				target      => $target,
				port        => $port,
				password    => $password, 
			});
		}
		else
		{
			   $virsh_exit_code = "-" if not defined $virsh_exit_code;
			my $say_error       = $an->String->get({key => "message_0069", variables => { 
					media		=>	$insert_media,
					drive		=>	$insert_drive,
					virsh_exit_code	=>	$virsh_exit_code,
				}});
			print $an->Web->template({file => "server.html", template => "insert-media-failed-bad-exit-code", replace => { error => $say_error }});
		}
	}
	else
	{
		# The server isn't running. Directly re-write the XML file. 
		my $message = $an->String->get({key => "message_0070", variables => { server => $server }});
		print $an->Web->template({file => "server.html", template => "insert-media-server-off", replace => { message => $message }});
		my $server_uuid    = "";
		my $new_definition = "";
		my $shell_call     = $an->data->{path}{cat}." $definition_file";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /<uuid>(.*?)<\/uuid>/)
			{
				$server_uuid = $1;
			}
			if ($line =~ /dev='(.*?)'/)
			{
				my $this_device = $1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "Found the device", value1 => $this_device,
				}, file => $THIS_FILE, line => __LINE__});
				if ($this_device eq $insert_drive)
				{
					$new_definition .= "      <source file='/shared/files/$insert_media'/>\n";
				}
			}
			$new_definition .= "$line\n";
		}
		$new_definition =~ s/(\S)\s+$/$1\n/;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "new definition", value1 => $new_definition,
		}, file => $THIS_FILE, line => __LINE__});
		
		# See if I need to insert or edit any network interface driver elements.
		$new_definition = $an->Striker->_update_network_driver({xml => $new_definition});
		
		# Write the new definition file.
		print $an->Web->template({file => "server.html", template => "saving-server-config"});
		$shell_call = $an->data->{path}{echo}." \"$new_definition\" > $definition_file && ".$an->data->{path}{'chmod'}." 644 $definition_file";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			print $an->Web->template({file => "common.html", template => "shell-call-output", replace => { line => $line }});
		}
		print $an->Web->template({file => "server.html", template => "insert-media-footer"});
		
		# Update the server's definition file in the database, if it actually changed, and register 
		# an alert.
		if ($an->Validate->is_uuid({uuid => $server_uuid}))
		{
			$an->ScanCore->insert_or_update_servers({
				server_uuid       => $server_uuid,
				server_definition => $new_definition,
				just_definition   => 1,
			});
		}
		
		# Lastly, copy the new definition to the stored XML for this server.
		  $an->data->{server}{$server}{xml}  = [];	# this is probably redundant
		@{$an->data->{server}{$server}{xml}} = split/\n/, $new_definition;
	}
	
	return(0);
}

# This boots a server on a target node.
sub _start_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_start_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# This simply calls '$an->Cman->boot_server()' and processes the output.
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $server     = $an->data->{cgi}{server};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "server",     value3 => $server,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $server)
	{
		# Error...
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0125", code => 125, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	# Which node to use?
	my ($target, $port, $password, $node_name) = $an->Cman->find_node_in_cluster();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "target", value1 => $target,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $target)
	{
		# Couldn't log into either node.
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0126", message_variables => { server => $server }, code => 126, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	my $say_title = $an->String->get({key => "title_0046", variables => { server =>	$server }});
	print $an->Web->template({file => "server.html", template => "start-server-header", replace => { title => $say_title }});
	
	# Call 'anvil-boot-server'
	my $shell_call = $an->data->{path}{'anvil-boot-server'}." --server $server";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	if (@{$return} > 0)
	{
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			
			   $line    = $an->Web->parse_text_line({line => $line});
			my $message = ($line =~ /^(.*)\[/)[0];
			my $status  = ($line =~ /(\[.*)$/)[0];
			if (not $message)
			{
				$message = $line;
				$status  = "";
			}
			print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
				status	=>	$status,
				message	=>	$message,
			}});
		}
		print $an->Web->template({file => "server.html", template => "start-server-output-footer"});
	}
	print $an->Web->template({file => "server.html", template => "start-server-footer"});
	
	$an->ScanCore->update_server_stop_reason({
		server_name => $server, 
		stop_reason => "NULL",
	});
	
	return(0);
}

# This sttempts to shut down a server.
sub _stop_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_stop_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $server = $an->data->{cgi}{server};
	my $reason = $an->data->{sys}{stop_reason} ? $an->data->{sys}{stop_reason} : "clean";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "server", value1 => $server, 
		name2 => "reason", value2 => $reason, 
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $server)
	{
		# Error...
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0127", code => 127, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	if (time > $an->data->{cgi}{expire})
	{
		# Abort!
		my $say_title   = $an->String->get({key => "title_0185"});
		my $say_message = $an->String->get({key => "message_0444", variables => { server => $an->data->{cgi}{server} }});
		print $an->Web->template({file => "server.html", template => "request-expired", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});
		return(1);
	}
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	# Which node to use?
	my ($target, $port, $password, $node_name) = $an->Cman->find_node_in_cluster();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "target", value1 => $target,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $target)
	{
		# Couldn't log into either node.
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0128", message_variables => { server => $server }, code => 128, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	my $say_title = $an->String->get({key => "title_0051", variables => { server =>	$server }});
	print $an->Web->template({file => "server.html", template => "stop-server-header", replace => { title => $say_title }});
	
	# Mark the server as 'stopping'
	$an->ScanCore->update_server_stop_reason({
		server_name => $server, 
		stop_reason => "stopping",
	});
	
	# Call 'clusvcadm -d ...'
	my $shell_call = $an->data->{path}{clusvcadm}." -d $server";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		#$line =~ s/Local machine/$say_node/;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		   $line    = $an->Web->parse_text_line({line => $line});
		my $message = ($line =~ /^(.*)\[/)[0];
		my $status  = ($line =~ /(\[.*)$/)[0];
		if (not $message)
		{
			$message = $line;
			$status  = "";
		}
		print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
			status	=>	$status,
			message	=>	$message,
		}});
	}
	$an->ScanCore->update_server_stop_reason({
		server_name => $server, 
		stop_reason => "user_stopped",
	});
	
	print $an->Web->template({file => "server.html", template => "stop-server-footer"});
	
	return(0);
}

# This inserts, updates or removes a network interface driver in the passed-in XML definition file.
sub _update_network_driver
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_update_network_driver" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $new_xml = $parameter->{xml} ? $parameter->{xml} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "new_xml", value1 => $new_xml,
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "sys::server::bcn_nic_driver", value1 => $an->data->{sys}{server}{bcn_nic_driver},
		name2 => "sys::server::sn_nic_driver",  value2 => $an->data->{sys}{server}{sn_nic_driver},
		name3 => "sys::server::ifn_nic_driver", value3 => $an->data->{sys}{server}{ifn_nic_driver},
	}, file => $THIS_FILE, line => __LINE__});
	
	# Clear out the old array and refill it with the possibly-edited 'new_xml'.
	my @new_server_xml;
	foreach my $line (split/\n/, $new_xml)
	{
		push @new_server_xml, "$line";
	}
	$new_xml = "";
	
	my $in_interface = 0;
	my $this_network = "";
	my $this_driver  = "";
	foreach my $line (@new_server_xml)
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /<interface type='bridge'>/)
		{
			$in_interface = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "in_interface", value1 => $in_interface,
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($in_interface)
		{
			if ($line =~ /<source bridge='(.*?)_bridge1'\/>/)
			{
				$this_network = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "this_network", value1 => $this_network,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /<driver name='(.*?)'\/>/)
			{
				$this_driver = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "this_driver", value1 => $this_driver,
				}, file => $THIS_FILE, line => __LINE__});
				
				# See if I need to update it.
				if ($this_network)
				{
					my $key    = $this_network."_nic_driver";
					my $driver = $an->data->{sys}{server}{$key};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "key",    value1 => $key,
						name2 => "driver", value2 => $driver,
					}, file => $THIS_FILE, line => __LINE__});
					if ($driver)
					{
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "this_driver", value1 => $this_driver,
							name2 => "driver",      value2 => $driver,
						}, file => $THIS_FILE, line => __LINE__});
						if ($this_driver ne $driver)
						{
							# Change the driver
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => ">> line", value1 => $line,
							}, file => $THIS_FILE, line => __LINE__});
							$line =~ s/driver name='.*?'/driver name='$driver'/;
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => "<< line", value1 => $line,
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
					else
					{
						# Delete the driver
						$an->Log->entry({log_level => 3, message_key => "log_0234", message_variables => {
							line => $line, 
						}, file => $THIS_FILE, line => __LINE__});
						next;
					}
				}
			}
			if ($line =~ /<\/interface>/)
			{
				# Insert the driver, if needed.
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "this_driver", value1 => $this_driver,
				}, file => $THIS_FILE, line => __LINE__});
				if (not $this_driver)
				{
					my $key    = $this_network."_nic_driver";
					my $driver = $an->data->{sys}{server}{$key};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "key",    value1 => $key,
						name2 => "driver", value2 => $driver,
					}, file => $THIS_FILE, line => __LINE__});
					if ($driver)
					{
						# Insert it
						$new_xml .= "      <driver name='$driver'/>\n";
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "driver", value1 => $driver, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				
				$in_interface = 0;
				$this_network = "";
				$this_driver  = "";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "in_interface", value1 => $in_interface,
					name2 => "this_network", value2 => $this_network,
					name3 => "this_driver",  value3 => $this_driver,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		$new_xml .= "$line\n";
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "new_xml", value1 => $new_xml,
	}, file => $THIS_FILE, line => __LINE__});
	return($new_xml);
}

# This calls 'virsh dumpxml' against the given server and updates scancore's 'server' database table.
sub _update_server_definition
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_update_server_definition" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});

	my $server_name     = $parameter->{server_name} ? $parameter->{server_name} : "";
	my $target          = $parameter->{target}      ? $parameter->{target}      : "";
	my $port            = $parameter->{port}        ? $parameter->{port}        : "";
	my $password        = $parameter->{password}    ? $parameter->{password}    : "";
	my $definition_file = $an->data->{server}{$server_name}{definition_file};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "definition_file", value1 => $definition_file, 
		name2 => "server_name",     value2 => $server_name, 
		name3 => "target",          value3 => $target, 
		name4 => "port",            value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If the definition_file isn't set, set it manually.
	if (not $definition_file)
	{
		$definition_file = $an->data->{path}{shared_definitions}."/${server_name}.xml";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "definition_file", value1 => $definition_file, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# We'll get the server's UUID directly from the definition file, as that is the most authoritative.
	my $server_uuid    = "";
	my $new_definition = "";
	my $shell_call     = $an->data->{path}{virsh}." dumpxml $server_name";
	my $return         = [];
	if ($target)
	{
		# Remote call.
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
		# Local call
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			push @{$return}, $line;
		}
		close $file_handle;
	}
	foreach my $line (@{$return})
	{
		### TODO: Why was I doing this?
		#$line =~ s/^\s+//;
		#$line =~ s/\s+$//;
		#$line =~ s/\s+/ /g;
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$new_definition .= "$line\n";
		if ($line =~ /<uuid>(.*?)<\/uuid>/)
		{
			$server_uuid = $1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "server_uuid", value1 => $server_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# See if I need to insert or edit any network interface driver elements.
	$new_definition = $an->Striker->_update_network_driver({xml => $new_definition});
	
	# Write out the new one.
	$shell_call = $an->data->{path}{cat}." > $definition_file << EOF\n$new_definition\nEOF";
	$return     = [];
	if ($target)
	{
		# Remote call.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
		# Local call
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		### NOTE: Don't use '2>&1' here!
		open (my $file_handle, "$shell_call |") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
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
	
	# Rebuild the $an->data->{server}{$server_name}{xml} array.
	undef $an->data->{server}{$server_name}{xml};
	      $an->data->{server}{$server_name}{xml} = [];
	foreach my $line (split/\n/, $new_definition)
	{
		push @{$an->data->{server}{$server_name}{xml}}, $line;
	}
	
	# Read in the old definition from the database and, if it has changed, update the definition file 
	# and register an alert.
	if ($an->Validate->is_uuid({uuid => $server_uuid}))
	{
		$an->ScanCore->insert_or_update_servers({
			server_uuid       => $server_uuid,
			server_definition => $new_definition,
			just_definition   => 1,
		});
	}
	
	return($new_definition);
}

# This sanity-checks the requested server config prior to creating the server itself.
sub _verify_server_config
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_verify_server_config" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Sort out my data from CGI
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# First, get a current view of the Anvil!.
	my $proceed = 1;
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	# Read the files on '/shared'
	my ($target, $port, $password, $node_name) = $an->Cman->find_node_in_cluster();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node_name", value1 => $node_name,
		name2 => "target",    value2 => $target,
		name3 => "port",      value3 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	my ($files, $partition) = $an->Get->shared_files({
		target   => $target,
		port     => $port,
		password => $password,
	});
	
	# Make sure a node is online
	my @errors;
	if (($an->data->{sys}{anvil}{node1}{online}) or ($an->data->{sys}{anvil}{node2}{online}))
	{
		# Did the user name the server?
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::name", value1 => $an->data->{cgi}{name},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{name})
		{
			# Normally, it is safer to only allow a subset of characters, but it would be nice to
			# allow users to name their servers using non-latin characters, so for now, we look 
			# for bad characters only.
			$an->data->{cgi}{name} =~ s/^\s+//;
			$an->data->{cgi}{name} =~ s/\s+$//;
			if ($an->data->{cgi}{name} =~ /\s/)
			{
				# Bad name, no spaces allowed.
				my $say_row     = $an->String->get({key => "row_0102"});
				my $say_message = $an->String->get({key => "message_0127"});
				push @errors, "$say_row#!#$say_message";
			}
			# If this changes, remember to update message_0127!
			elsif (($an->data->{cgi}{name} =~ /;/)  or 
			       ($an->data->{cgi}{name} =~ /&/)  or 
			       ($an->data->{cgi}{name} =~ /\|/) or 
			       ($an->data->{cgi}{name} =~ /\$/) or 
			       ($an->data->{cgi}{name} =~ />/)  or 
			       ($an->data->{cgi}{name} =~ /</)  or 
			       ($an->data->{cgi}{name} =~ /\[/) or 
			       ($an->data->{cgi}{name} =~ /\]/) or 
			       ($an->data->{cgi}{name} =~ /\(/) or 
			       ($an->data->{cgi}{name} =~ /\)/) or 
			       ($an->data->{cgi}{name} =~ /}/)  or 
			       ($an->data->{cgi}{name} =~ /{/)  or 
			       ($an->data->{cgi}{name} =~ /!/)  or 
			       ($an->data->{cgi}{name} =~ /\^/))
			{
				# Illegal characters.
				my $say_row     = $an->String->get({key => "row_0102"});
				my $say_message = $an->String->get({key => "message_0127"});
				push @errors, "$say_row#!#$say_message";
			}
			else
			{
				my $server = $an->data->{cgi}{name};
				if (exists $an->data->{server}{$server})
				{
					# Duplicate name
					my $say_row     = $an->String->get({key => "row_0103"});
					my $say_message = $an->String->get({key => "message_0128", variables => { server => $server }});
					push @errors, "$say_row#!#$say_message";
				}
				else
				{
					# Name is OK
					$an->data->{new_server}{name} = $server;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "new_server::name", value1 => $an->data->{new_server}{name},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		else
		{
			# Missing server name
			my $say_row     = $an->String->get({key => "row_0104"});
			my $say_message = $an->String->get({key => "message_0129"});
			push @errors, "$say_row#!#$say_message";
		}
		
		# Did the user ask for too many cores?
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "cgi::cpu_cores",           value1 => $an->data->{cgi}{cpu_cores},
			name2 => "resources::total_threads", value2 => $an->data->{resources}{total_threads},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{cpu_cores} =~ /\D/)
		{
			# Not a digit.
			my $say_row     = $an->String->get({key => "row_0105"});
			my $say_message = $an->String->get({key => "message_0130", variables => { cpu_cores => $an->data->{cgi}{cpu_cores} }});
			push @errors, "$say_row#!#$say_message";
		}
		elsif ($an->data->{cgi}{cpu_cores} > $an->data->{resources}{total_threads})
		{
			# Not enough cores
			my $say_row     = $an->String->get({key => "row_0106"});
			my $say_message = $an->String->get({key => "message_0131", variables => { 
					total_threads	=>	$an->data->{resources}{total_threads},
					cpu_cores	=>	$an->data->{cgi}{cpu_cores},
				}});
			push @errors, "$say_row#!#$say_message";
		}
		else
		{
			$an->data->{new_server}{cpu_cores} = $an->data->{cgi}{cpu_cores};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "new_server::cpu_cores", value1 => $an->data->{new_server}{cpu_cores},
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Now what about RAM?
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::ram", value1 => $an->data->{cgi}{ram},
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{cgi}{ram} =~ /\D/) && ($an->data->{cgi}{ram} !~ /^\d+\.\d+$/))
		{
			# RAM amount isn't a digit...
			my $say_row     = $an->String->get({key => "row_0107"});
			my $say_message = $an->String->get({key => "message_0132", variables => { ram => $an->data->{cgi}{ram} }});
			push @errors, "$say_row#!#$say_message";
		}
		my $requested_ram = $an->Readable->hr_to_bytes({size => $an->data->{cgi}{ram}, type => $an->data->{cgi}{ram_suffix} });
		my $diff          = $an->data->{resources}{total_ram} % (1024 ** 3);
		my $available_ram = $an->data->{resources}{total_ram} - $diff - $an->data->{sys}{unusable_ram};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "requested_ram", value1 => $requested_ram,
			name2 => "available_ram", value2 => $available_ram,
		}, file => $THIS_FILE, line => __LINE__});
		if ($requested_ram > $available_ram)
		{
			# Requested too much RAM.
			my $say_free_ram  = $an->Readable->bytes_to_hr({'bytes' => $available_ram });
			my $say_requested = $an->Readable->bytes_to_hr({'bytes' => $requested_ram });
			my $say_row       = $an->String->get({key => "row_0108"});
			my $say_message   = $an->String->get({key => "message_0133", variables => { 
					free_ram	=>	$say_free_ram,
					requested_ram	=>	$say_requested,
				}});
			push @errors, "$say_row#!#$say_message";
		}
		else
		{
			# RAM is specified as a number of MiB.
			my $say_ram = sprintf("%.0f", ($requested_ram /= (2 ** 20)));
			$an->data->{new_server}{ram} = $say_ram;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "new_server::ram", value1 => $an->data->{new_server}{ram},
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Look at the selected storage. if VGs named for two separate nodes are defined, error.
		$an->data->{new_server}{host_node} = "";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "host_node", value1 => $an->data->{new_server}{host_node},
			name2 => "vg_list",   value2 => $an->data->{cgi}{vg_list},
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $vg (split /,/, $an->data->{cgi}{vg_list})
		{
			my $short_vg   = $vg;
			my $short_node = $vg;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "short_vg",   value1 => $short_vg,
				name2 => "short_node", value2 => $short_node,
				name3 => "vg",         value3 => $vg,
			}, file => $THIS_FILE, line => __LINE__});
			if ($vg =~ /^(.*?)_(vg\d+)$/)
			{
				$short_node = $1;
				$short_vg   = $2;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "short_vg",   value1 => $short_vg,
					name2 => "short_node", value2 => $short_node,
				}, file => $THIS_FILE, line => __LINE__});
			}
			my $say_node      = $short_node;
			my $vg_key        = "vg_$vg";
			my $vg_suffix_key = "vg_suffix_$vg";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "say_node",      value1 => $say_node,
				name2 => "vg_key",        value2 => $vg_key,
				name3 => "vg_suffix_key", value3 => $vg_suffix_key,
			}, file => $THIS_FILE, line => __LINE__});
			next if not $an->data->{cgi}{$vg_key};
			
			foreach my $node_key ("node1", "node2")
			{
				my $node       = $an->data->{sys}{anvil}{$node_key}{name};
				my $short_node = $an->data->{sys}{anvil}{$node_key}{short_name};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node",       value1 => $node,
					name2 => "short_node", value2 => $short_node,
				}, file => $THIS_FILE, line => __LINE__});
				if ($node =~ /$short_node/)
				{
					$say_node = $node;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "say_node", value1 => $say_node,
					}, file => $THIS_FILE, line => __LINE__});
					last;
				}
			}
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "host_node", value1 => $an->data->{new_server}{host_node},
			}, file => $THIS_FILE, line => __LINE__});
			if (not $an->data->{new_server}{host_node})
			{
				$an->data->{new_server}{host_node} = $say_node;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "host_node", value1 => $an->data->{new_server}{host_node},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($an->data->{new_server}{host_node} ne $say_node)
			{
				# Conflicting Storage
				my $say_row     = $an->String->get({key => "row_0109"});
				my $say_message = $an->String->get({key => "message_0134"});
				push @errors, "$say_row#!#$say_message";
			}
			
			# Setup the 'lvcreate' call
			foreach my $lv_size (split/:/, $an->data->{cgi}{$vg_key})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "lv_size", value1 => $lv_size,
				}, file => $THIS_FILE, line => __LINE__});
				if ($lv_size eq "all")
				{
					push @{$an->data->{new_server}{vg}{$vg}{lvcreate_size}}, "all";
				}
				elsif ($an->data->{cgi}{$vg_suffix_key} eq "%")
				{
					push @{$an->data->{new_server}{vg}{$vg}{lvcreate_size}}, "${lv_size}%";
				}
				else
				{
					# Make to lvcreate command a GiB value.
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "cgi::${vg_key}",        value1 => $lv_size,
						name2 => "cgi::${vg_suffix_key}", value2 => $an->data->{cgi}{$vg_suffix_key},
					}, file => $THIS_FILE, line => __LINE__});
					
					my $lv_size = $an->Readable->hr_to_bytes({size => $lv_size, type => $an->data->{cgi}{$vg_suffix_key} });
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "> lv_size", value1 => $lv_size,
					}, file => $THIS_FILE, line => __LINE__});
					
					$lv_size    = sprintf("%.0f", ($lv_size /= (2 ** 30)));
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "< lv_size", value1 => $lv_size,
					}, file => $THIS_FILE, line => __LINE__});
					
					push @{$an->data->{new_server}{vg}{$vg}{lvcreate_size}}, "$lv_size";
				}
			}
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "host_node", value1 => $an->data->{new_server}{host_node},
		}, file => $THIS_FILE, line => __LINE__});
		
		# Make sure the user specified an install disc.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::install_iso", value1 => $an->data->{cgi}{install_iso},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{install_iso})
		{
			my $file_name = $an->data->{cgi}{install_iso};
			if ($files->{$file_name}{optical})
			{
				$an->data->{new_server}{install_iso} = $an->data->{cgi}{install_iso};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "new_server::install_iso", value1 => $an->data->{new_server}{install_iso},
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Dude, where's my ISO?
				my $say_row     = $an->String->get({key => "row_0110"});
				my $say_message = $an->String->get({key => "message_0135"});
				push @errors, "$say_row#!#$say_message";
			}
		}
		else
		{
			# The user needs an install source...
			my $say_row     = $an->String->get({key => "row_0110"});
			my $say_message = $an->String->get({key => "message_0136"});
			push @errors, "$say_row#!#$say_message";
		}
		
		# A few OSes we set don't match a real os-variant. Swap them here.
		if ($an->data->{cgi}{os_variant} eq "debianjessie")
		{
			# Debian is modern enough so we'll use the 'rhel7' variant.
			$an->data->{cgi}{os_variant} = "rhel7";
		}
		
		### TODO: Find a better way to determine this.
		# Look at the OS type to try and determine if 'e1000' or
		# 'virtio' should be used by the network.
		$an->data->{new_server}{virtio}{nic}  = 0;
		$an->data->{new_server}{virtio}{disk} = 0;
		if (($an->data->{cgi}{os_variant} =~ /fedora1\d/) or 
		    ($an->data->{cgi}{os_variant} =~ /virtio/)    or 
		    ($an->data->{cgi}{os_variant} =~ /ubuntu/)    or 
		    ($an->data->{cgi}{os_variant} =~ /sles11/)    or 
		    ($an->data->{cgi}{os_variant} =~ /rhel5/)     or 
		    ($an->data->{cgi}{os_variant} =~ /rhel6/)     or 
		    ($an->data->{cgi}{os_variant} =~ /rhel7/))
		{
			$an->data->{new_server}{virtio}{disk} = 1;
			$an->data->{new_server}{virtio}{nic}  = 1;
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "new_server::virtio::disk", value1 => $an->data->{new_server}{virtio}{disk},
			name2 => "new_server::virtio::nic",  value2 => $an->data->{new_server}{virtio}{nic},
		}, file => $THIS_FILE, line => __LINE__});
		
		# Optional driver disk, enables virtio when appropriate
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::driver_iso", value1 => $an->data->{cgi}{driver_iso},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{driver_iso})
		{
			my $file_name = $an->data->{cgi}{driver_iso};
			if ($files->{$file_name}{optical})
			{
				$an->data->{new_server}{driver_iso} = $an->data->{cgi}{driver_iso};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "new_server::driver_iso", value1 => $an->data->{new_server}{driver_iso},
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Driver media no longer exists.
				my $say_row     = $an->String->get({key => "row_0111"});
				my $say_message = $an->String->get({key => "message_0137"});
				push @errors, "$say_row#!#$say_message";
			}
			
			if (lc($file_name) =~ /virtio/)
			{
				$an->data->{new_server}{virtio}{disk} = 1;
				$an->data->{new_server}{virtio}{nic}  = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "new_server::virtio::disk", value1 => $an->data->{new_server}{virtio}{disk},
					name2 => "new_server::virtio::nic",  value2 => $an->data->{new_server}{virtio}{nic},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Make sure a valid os-variant was passed.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::os_variant", value1 => $an->data->{cgi}{os_variant},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{os_variant})
		{
			my $match = 0;
			foreach my $os_variant (@{$an->data->{sys}{os_variant}})
			{
				my ($short_name, $desc) = ($os_variant =~ /^(.*?)#!#(.*)$/);
				if ($an->data->{cgi}{os_variant} eq $short_name)
				{
					$match = 1;
				}
			}
			if (not $match)
			{
				# OS variant specified but invalid
				my $say_row     = $an->String->get({key => "row_0112"});
				my $say_message = $an->String->get({key => "message_0138"});
				push @errors, "$say_row#!#$say_message";
			}
		}
		else
		{
			# No OS variant specified.
			my $say_row     = $an->String->get({key => "row_0113"});
			my $say_message = $an->String->get({key => "message_0139"});
			push @errors, "$say_row#!#$say_message";
		}
		
		# If there were errors, push the user back to the form.
		if (@errors > 0)
		{
			$proceed = 0;
			print $an->Web->template({file => "server.html", template => "verify-server-header"});
			
			foreach my $error (@errors)
			{
				my ($title, $body) = ($error =~ /^(.*?)#!#(.*)$/);
				print $an->Web->template({file => "server.html", template => "verify-server-error", replace => { 
					title	=>	$title,
					body	=>	$body,
				}});
			}
			print $an->Web->template({file => "server.html", template => "verify-server-footer"});
		}
	}
	else
	{
		# Failed to connect to the Anvil!, errors should already be reported to the user.
	}
	# Check the currently available resources on the Anvil!.
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "proceed", value1 => $proceed,
	}, file => $THIS_FILE, line => __LINE__});
	return ($proceed);
}

# This does a final check of the target node then withdraws it from the Anvil!.
sub _withdraw_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_withdraw_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $node_name  = $an->data->{cgi}{node_name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "node_name",  value2 => $node_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $anvil_uuid)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0136", code => 136, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	if (not $node_name)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0137", code => 137, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	my $node_key = $an->data->{sys}{node_name}{$node_name}{node_key};
	if (not $node_key)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0138", message_variables => { node_name => $node_name }, code => 138, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	my $proceed = $an->data->{node}{$node_name}{enable_withdraw};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name", value1 => $node_name,
		name2 => "proceed",   value2 => $proceed,
	}, file => $THIS_FILE, line => __LINE__});
	if ($proceed)
	{
		my $target   = $an->data->{sys}{anvil}{$node_key}{use_ip};
		my $port     = $an->data->{sys}{anvil}{$node_key}{use_port};
		my $password = $an->data->{sys}{anvil}{$node_key}{password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target", value1 => $target,
			name2 => "port",   value2 => $port,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Stop rgmanager and then check its status.
		my $say_title = $an->String->get({key => "title_0070", variables => { node_name => $node_name }});
		print $an->Web->template({file => "server.html", template => "withdraw-node-header", replace => { title => $say_title }});
		
		my ($return_code, $withdraw_output) = $an->Cman->withdraw_node({
			target   => $target,
			port     => $port,
			password => $password, 
		});
		
		foreach my $line (split/\n/, $withdraw_output)
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});

			   $line    = $an->Web->parse_text_line({line => $line});
			my $message = ($line =~ /^(.*)\[/)[0];
			my $status  = ($line =~ /(\[.*)$/)[0];
			if (not $message)
			{
				$message = $line;
				$status  = "";
			}
			print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
				status	=>	$status,
				message	=>	$message,
			}});
		}
		print $an->Web->template({file => "server.html", template => "withdraw-node-close-output"});
		print $an->Web->template({file => "server.html", template => "withdraw-node-footer"});
	}
	else
	{
		my $say_title   = $an->String->get({key => "title_0071", variables => { node_name => $node_name }});
		my $say_message = $an->String->get({key => "message_0249", variables => { node_name => $node_name }});
		print $an->Web->template({file => "server.html", template => "withdraw-node-aborted", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});
	}
	
	$an->Striker->_footer();
	
	return(0);
}

1;
