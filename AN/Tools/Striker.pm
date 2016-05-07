package AN::Tools::Striker;
# 
# This module will contain methods used specifically for Striker (WebUI) related tasks.
# 

use strict;
use warnings;
use Data::Dumper;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Striker.pm";

### Methods;
# configure
# configure_ssh_local
# load_anvil
# mark_node_as_clean_off
# mark_node_as_clean_on
# scan_anvil
# scan_node
# scan_servers
# update_peers
### NOTE: All of these private methods are ports of functions from the old Striker.pm. None will be developed
###       further and all will be phased out over time. Do not use any of these in new dev work.
# _check_lv
# _check_node_daemons
# _check_node_readiness
# _confirm_delete_server
# _confirm_dual_join
# _confirm_fence_node
# _confirm_force_off_server
# _confirm_join_anvil
# _confirm_migrate_server
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
# _dual_join
# _error
# _fence_node
# _find_preferred_host
# _force_off_server
# _gather_node_details
# _header
# _join_anvil
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
# _process_tasks
# _read_server_definition
# _start_server
# _stop_server
# _wothdraw_node

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
	
	if (not $parameter->{anvil_name})
	{
		# Nothing passed in or set in CGI
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0123", code => 123, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	my $anvil_name = $parameter->{anvil_name} ? $parameter->{anvil_name} : "";
	my $output     = "";
	
	# Add the user's SSH keys to the new anvil! (will simply exit if disabled in striker.conf).
	my $shell_call = $an->data->{path}{'call_striker-push-ssh'}." --anvil $anvil_name";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "Calling", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
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

# This uses the 'cgi::anvil_uuid' to load the anvil data into the active system variables.
sub load_anvil
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "load_anvil" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	if ($parameter->{anvil_uuid})
	{
		$anvil_uuid = $parameter->{anvil_uuid};
	}
	
	if (not $anvil_uuid)
	{
		# Nothing passed in or set in CGI
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0102", code => 102, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	elsif (not $an->Validate->is_uuid({uuid => $anvil_uuid}))
	{
		# Value read, but it isn't a UUID.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0103", message_variables => { uuid => $anvil_uuid }, code => 103, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	elsif (not $an->data->{anvils}{$anvil_uuid}{name})
	{
		# Load Anvil! data and try again.
		$an->ScanCore->parse_anvil_data();
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "anvils::${anvil_uuid}::name", value1 => $an->data->{anvils}{$anvil_uuid}{name}, 
		}, file => $THIS_FILE, line => __LINE__});
		if (not $an->data->{anvils}{$anvil_uuid}{name})
		{
			# Valid UUID, but it doesn't match a known Anvil!.
			$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0104", message_variables => { uuid => $anvil_uuid }, code => 104, file => "$THIS_FILE", line => __LINE__});
			return(1);
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
	$an->data->{sys}{anvil}{smtp}{username}       = $an->data->{anvils}{$anvil_uuid}{smtp}{username};
	$an->data->{sys}{anvil}{smtp}{security}       = $an->data->{anvils}{$anvil_uuid}{smtp}{security};
	$an->data->{sys}{anvil}{smtp}{authentication} = $an->data->{anvils}{$anvil_uuid}{smtp}{authentication};
	$an->data->{sys}{anvil}{smtp}{helo_domain}    = $an->data->{anvils}{$anvil_uuid}{smtp}{helo_domain};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0012", message_variables => {
		name1  => "sys::anvil::uuid",                 value1  => $an->data->{sys}{anvil}{uuid}, 
		name2  => "sys::anvil::name",                 value2  => $an->data->{sys}{anvil}{name}, 
		name3  => "sys::anvil::description",          value3  => $an->data->{sys}{anvil}{description}, 
		name4  => "sys::anvil::note",                 value4  => $an->data->{sys}{anvil}{note}, 
		name5  => "sys::anvil::owner::name",          value5  => $an->data->{sys}{anvil}{owner}{name}, 
		name6  => "sys::anvil::owner::note",          value6  => $an->data->{sys}{anvil}{owner}{note}, 
		name7  => "sys::anvil::smtp::server",         value7  => $an->data->{sys}{anvil}{smtp}{server}, 
		name8  => "sys::anvil::smtp::port",           value8  => $an->data->{sys}{anvil}{smtp}{port}, 
		name9  => "sys::anvil::smtp::username",       value9  => $an->data->{sys}{anvil}{smtp}{username}, 
		name10 => "sys::anvil::smtp::security",       value10 => $an->data->{sys}{anvil}{smtp}{security}, 
		name11 => "sys::anvil::smtp::authentication", value11 => $an->data->{sys}{anvil}{smtp}{authentication}, 
		name12 => "sys::anvil::smtp::helo_domain",    value12 => $an->data->{sys}{anvil}{smtp}{helo_domain}, 
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
		$an->data->{sys}{anvil}{$node_key}{uuid}           =  $an->data->{anvils}{$anvil_uuid}{$node_key}{uuid};
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0017", message_variables => {
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "sys::node_name::${node_name}::uuid",          value1 => $an->data->{sys}{node_name}{$node_name}{uuid}, 
			name2 => "sys::node_name::${node_name}::node_key",      value2 => $an->data->{sys}{node_name}{$node_name}{node_key}, 
			name3 => "sys::node_name::${node_name}::peer_node_key", value3 => $an->data->{sys}{node_name}{$node_name}{peer_node_key}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return(0);
}

# Update the ScanCore database(s) to mark the node's (hosts -> host_stop_reason = 'clean') so that they don't
# just turn right back on.
sub mark_node_as_clean_off
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "mark_node_as_clean_off" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid = $parameter->{node_uuid} ? $parameter->{node_uuid} : "";
	my $delay     = $parameter->{delay}     ? $parameter->{delay}     : 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node_uuid", value1 => $node_uuid,
		name2 => "delay",     value2 => $delay,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $node_uuid)
	{
		# Nothing passed in or set in CGI
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0114", code => 114, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	elsif (not $an->Validate->is_uuid({uuid => $node_uuid}))
	{
		# Value read, but it isn't a UUID.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0115", message_variables => { uuid => $node_uuid }, code => 115, file => "$THIS_FILE", line => __LINE__});
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
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0116", message_variables => { uuid => $node_uuid }, code => 116, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}

	# Update the hosts entry.
	my $say_off = "clean";
	if ($delay)
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::power_off_delay", value1 => $an->data->{sys}{power_off_delay},
		}, file => $THIS_FILE, line => __LINE__});
		$an->data->{sys}{power_off_delay} = 300 if not $an->data->{sys}{power_off_delay};
		$say_off = time + $an->data->{sys}{power_off_delay};
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "say_off", value1 => $say_off,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $query = "
UPDATE 
    hosts 
SET 
    host_emergency_stop = FALSE, 
    host_stop_reason    = ".$an->data->{sys}{use_db_fh}->quote($say_off).", 
    modified_date       = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
WHERE 
    host_uuid = ".$an->data->{sys}{use_db_fh}->quote($node_uuid)."
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
	
	my $node_uuid = $parameter->{node_uuid} ? $parameter->{node_uuid} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node_uuid", value1 => $node_uuid,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $node_uuid)
	{
		# Nothing passed in or set in CGI
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0117", code => 117, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	elsif (not $an->Validate->is_uuid({uuid => $node_uuid}))
	{
		# Value read, but it isn't a UUID.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0118", message_variables => { uuid => $node_uuid }, code => 118, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	
	my $host_data = $an->ScanCore->get_hosts();
	my $node_name = "";
	foreach my $hash_ref (@{$host_data})
	{
		my $host_uuid = $hash_ref->{host_uuid};
		my $host_name = $hash_ref->{host_name};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "host_uuid", value1 => $host_uuid, 
			name2 => "host_name", value2 => $host_name, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($host_uuid eq $node_uuid)
		{
			# We're good.
			$node_name = $host_name;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node_name", value1 => $node_name, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node_name", value1 => $node_name, 
	}, file => $THIS_FILE, line => __LINE__});
	if (not $node_name)
	{
		# Valid UUID, but it doesn't match a known Anvil!.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0119", message_variables => { uuid => $node_uuid }, code => 119, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	
	# Get the current health.
	my $query = "
SELECT 
    host_health 
FROM 
    hosts 
WHERE 
    host_uuid = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{host_uuid})."
;";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query, 
	}, file => $THIS_FILE, line => __LINE__});
	my $old_health = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__})->[0]->[0];
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "old_health", value1 => $old_health, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Update the hosts entry.
	$query = "
UPDATE 
    hosts 
SET 
    host_emergency_stop = FALSE, 
    host_stop_reason    = NULL, 
";
	# Update the health to 'ok' if it was 'shutdown' before.
	if ($old_health eq "shutdown")
	{
		$query .= "    host_health         = 'ok', ";
	}
	$query .= "
    modified_date       = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
WHERE 
    host_name = ".$an->data->{sys}{use_db_fh}->quote($node_uuid)."
;";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	
	return(0);
}

# This does a full manual scan of an Anvil! system.
sub scan_anvil
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "scan_anvil" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Show the 'scanning in progress' table.
	print $an->Web->template({file => "common.html", template => "scanning-message", replace => {
		anvil_message	=>	$an->String->get({key => "message_0272", variables => { anvil => $an->data->{sys}{anvil}{name} }}),
	}});
	
	# Start your engines!
	$an->Striker->scan_node({uuid => $an->data->{sys}{anvil}{node1}{uuid}});
	$an->Striker->scan_node({uuid => $an->data->{sys}{anvil}{node2}{uuid}});
	
	my $node1_name   = $an->data->{sys}{anvil}{node1}{name};
	my $node1_online = $an->data->{sys}{anvil}{node1}{online};
	my $node2_name   = $an->data->{sys}{anvil}{node2}{name};
	my $node2_online = $an->data->{sys}{anvil}{node2}{online};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node1_name",   value1 => $node1_name,
		name2 => "node1_online", value2 => $node1_online,
		name3 => "node2_name",   value3 => $node2_name,
		name4 => "node2_online", value4 => $node2_online,
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "up nodes", value1 => $an->data->{sys}{up_nodes},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{up_nodes} > 0)
	{
		$an->Striker->scan_servers();
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
	
	my $node_uuid = $parameter->{uuid};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node_uuid", value1 => $node_uuid,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $node_uuid)
	{
		# Nothing passed in or set in CGI
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0105", code => 105, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	elsif (not $an->Validate->is_uuid({uuid => $node_uuid}))
	{
		# Value read, but it isn't a UUID.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0106", message_variables => { uuid => $node_uuid }, code => 106, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	elsif (not $an->data->{db}{nodes}{$node_uuid}{name})
	{
		# Valid UUID, but it doesn't match a known Anvil!.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0107", message_variables => { uuid => $node_uuid }, code => 107, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	
	# First, see how to access the node.
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $node_key  = $node_uuid eq $an->data->{sys}{anvil}{node1}{uuid} ? "node1" : "node2";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node_name", value1 => $node_name, 
		name2 => "node_key",  value2 => $node_key, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# See if I have a cached 'access' data.
	my $access = $an->ScanCore->read_cache({target => $node_uuid, type => "access"});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "access", value1 => $access, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($access)
	{
		# If this fails, we'll walk our various connections.
		my $target = $access;
		my $port   = 22;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target", value1 => $target, 
			name2 => "port",   value2 => $port, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($target =~ /^(.*?):(\d+)$/)
		{
			$target = $1;
			$port   = $2;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "target", value1 => $target, 
				name2 => "port",   value2 => $port, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		my $access = $an->Check->access({
				target   => $target,
				port     => $port,
				password => $an->data->{sys}{anvil}{$node_key}{password},
			});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "access", value1 => $access, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($access)
		{
			$an->data->{sys}{anvil}{$node_key}{use_ip}   = $target;
			$an->data->{sys}{anvil}{$node_key}{use_port} = $port; 
			$an->data->{sys}{anvil}{$node_key}{online}   = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "sys::anvil::${node_key}::use_ip",   value1 => $an->data->{sys}{anvil}{$node_key}{use_ip}, 
				name2 => "sys::anvil::${node_key}::use_port", value2 => $an->data->{sys}{anvil}{$node_key}{use_port}, 
				name3 => "sys::anvil::${node_key}::online",   value3 => $an->data->{sys}{anvil}{$node_key}{online}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If I don't have access (no cache or cache didn't work), walk through the networks.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::anvil::${node_key}::online", value1 => $an->data->{sys}{anvil}{$node_key}{online}, 
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->data->{sys}{anvil}{$node_key}{online})
	{
		# BCN first.
		my $bcn_access = $an->Check->access({
				target   => $an->data->{sys}{anvil}{$node_key}{bcn_ip},
				port     => 22,
				password => $an->data->{sys}{anvil}{$node_key}{password},
			});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "bcn_access", value1 => $bcn_access, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($bcn_access)
		{
			# Woot
			$an->data->{sys}{anvil}{$node_key}{use_ip}   = $an->data->{sys}{anvil}{$node_key}{bcn_ip};
			$an->data->{sys}{anvil}{$node_key}{use_port} = 22; 
			$an->data->{sys}{anvil}{$node_key}{online}   = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "ifn_access", value1 => $ifn_access, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($ifn_access)
			{
				# Woot
				$an->data->{sys}{anvil}{$node_key}{use_ip}   = $an->data->{sys}{anvil}{$node_key}{ifn_ip};
				$an->data->{sys}{anvil}{$node_key}{use_port} = 22; 
				$an->data->{sys}{anvil}{$node_key}{online}   = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "sys::anvil::${node_key}::use_ip",   value1 => $an->data->{sys}{anvil}{$node_key}{use_ip}, 
					name2 => "sys::anvil::${node_key}::use_port", value2 => $an->data->{sys}{anvil}{$node_key}{use_port}, 
					name3 => "sys::anvil::${node_key}::online",   value3 => $an->data->{sys}{anvil}{$node_key}{online}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Try the remote IP/Port
				my $remote_access = $an->Check->access({
						target   => $an->data->{sys}{anvil}{$node_key}{remote_ip},
						port     => $an->data->{sys}{anvil}{$node_key}{remote_port},
						password => $an->data->{sys}{anvil}{$node_key}{password},
					});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "remote_access", value1 => $remote_access, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($remote_access)
				{
					# Woot
					$an->data->{sys}{anvil}{$node_key}{use_ip}   = $an->data->{sys}{anvil}{$node_key}{remote_ip};
					$an->data->{sys}{anvil}{$node_key}{use_port} = $an->data->{sys}{anvil}{$node_key}{remote_port}; 
					$an->data->{sys}{anvil}{$node_key}{online}   = 1;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
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
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "sys::anvil::${node_key}::power", value1 => $an->data->{sys}{anvil}{$node_key}{power}, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
	}
	
	# If I connected, cache the data.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::anvil::${node_key}::online", value1 => $an->data->{sys}{anvil}{$node_key}{online}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{anvil}{$node_key}{online})
	{
		my $say_access = $an->data->{sys}{anvil}{$node_key}{use_ip};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "say_access",                      value1 => $say_access, 
			name2 => "sys::anvil::${node_key}::online", value2 => $an->data->{sys}{anvil}{$node_key}{online}, 
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{sys}{anvil}{$node_key}{use_port}) && ($an->data->{sys}{anvil}{$node_key}{use_port} ne 22))
		{
			$say_access = $an->data->{sys}{anvil}{$node_key}{use_ip}.":".$an->data->{sys}{anvil}{$node_key}{use_port};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
		if ($an->data->{sys}{anvil}{$node_key}{power} eq "off")
		{
			$an->data->{sys}{online_nodes}                 = 1;
			$an->data->{node}{$node_name}{enable_poweron}  = 1;
			$an->data->{node}{$node_name}{enable_poweroff} = 0;
			$an->data->{node}{$node_name}{enable_fence}    = 0;
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
			$an->Log->entry({log_level => 2, message_key => "log_0017", file => $THIS_FILE, line => __LINE__});
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
			$an->Log->entry({log_level => 2, message_key => "log_0017", file => $THIS_FILE, line => __LINE__});
			foreach my $daemon ("cman", "rgmanager", "drbd", "clvmd", "gfs2", "libvirtd")
			{
				$an->data->{node}{$node_name}{daemon}{$daemon}{status}    = "<span class=\"highlight_unavailable\">#!string!an_state_0001!#</span>";
				$an->data->{node}{$node_name}{daemon}{$daemon}{exit_code} = "";
			}
		}
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "up_nodes_count", value1 => $up_nodes_count,
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->Striker->_gather_node_details({node => $node_uuid});
	}
	else
	{
		# Mark it as offline.
		$an->data->{node}{$node_name}{connected}      = 0;
		$an->data->{node}{$node_name}{info}{'state'}  = "<span class=\"highlight_unavailable\">#!string!row_0003!#</span>";
		$an->data->{node}{$node_name}{info}{note}     = "";
		$an->data->{node}{$node_name}{up}             = 0;
		$an->data->{node}{$node_name}{enable_poweron} = 0;
		
		# If I have confirmed the node is powered off, don't display this.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "sys::anvil::${node_key}::power", value1 => $an->data->{sys}{anvil}{$node_key}{power},
			name2 => "cgi::task",                      value2 => $an->data->{cgi}{task},
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{sys}{anvil}{$node_key}{power} eq "off") && (not $an->data->{cgi}{task}))
		{
			print $an->Web->template({file => "main-page.html", template => "node-state-table", replace => { 
				'state'	=>	$an->data->{node}{$node_name}{info}{'state'},
				note	=>	$an->data->{node}{$node_name}{info}{note},
			}});
		}
	}
	
	push @{$an->data->{online_nodes}}, $node_name if $an->Striker->_check_node_daemons({node => $node_uuid});
	
	# If I have no nodes up, exit.
	my $anvil_name                    = $an->data->{sys}{anvil}{name};
	   $an->data->{sys}{up_nodes}     = @{$an->data->{up_nodes}};
	   $an->data->{sys}{online_nodes} = @{$an->data->{online_nodes}};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "anvil_name",        value1 => $anvil_name,
		name2 => "sys::up_nodes",     value2 => $an->data->{sys}{up_nodes},
		name3 => "sys::online_nodes", value3 => $an->data->{sys}{online_nodes},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{up_nodes} < 1)
	{
		# Neither node is up. If I can power them on, then I will show the node section to enable 
		# power up.
		if (not $an->data->{sys}{online_nodes})
		{
			if ($an->data->{clusters}{$anvil_name}{cache_exists})
			{
				print $an->Web->template({file => "main-page.html", template => "no-access-message", replace => { 
					anvil	=>	$an->data->{sys}{anvil}{name},
					message	=>	"#!string!message_0028!#",
				}});
			}
			else
			{
				print $an->Web->template({file => "main-page.html", template => "no-access-message", replace => { 
					anvil	=>	$an->data->{sys}{anvil}{name},
					message	=>	"#!string!message_0029!#",
				}});
			}
		}
	}
	else
	{
		$an->Striker->_post_scan_calculations();
	}
	
	return (0);
}

# Check the status of server on the active Anvil!.
sub scan_servers
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "scan_servers" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make it a little easier to print the name of each node
	my $node1_name = $an->data->{sys}{anvil}{node1}{name};
	my $node1_uuid = $an->data->{sys}{node_name}{$node1_name}{uuid};
	my $node2_name = $an->data->{sys}{anvil}{node2}{name};
	my $node2_uuid = $an->data->{sys}{node_name}{$node2_name}{uuid};
	
	$an->data->{node}{$node1_name}{info}{host_name}       = $node1_name;
	$an->data->{node}{$node1_name}{info}{short_host_name} = $an->data->{sys}{anvil}{node1}{short_name};
	$an->data->{node}{$node2_name}{info}{host_name}       = $node2_name;
	$an->data->{node}{$node2_name}{info}{short_host_name} = $an->data->{sys}{anvil}{node2}{short_name};
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
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
		my $say_server;
		if ($server =~ /^vm:(.*)/)
		{
			$say_server = $1;
		}
		else
		{
			my $say_message = $an->String->get({key => "message_0467", variables => { server => $server }});
			$an->Striker->_error({message => $say_message});
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "server",     value1 => $server,
			name2 => "say_server", value2 => $say_server,
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "server::${server}::say_node1",                    value1 => $an->data->{server}{$server}{say_node1},
			name2 => "node::${node1_name}::daemon::cman::exit_code", value2 => $an->data->{node}{$node1_name}{daemon}{cman}{exit_code},
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->data->{server}{$server}{say_node2}   = $an->data->{node}{$node2_name}{daemon}{cman}{exit_code} eq "0" ? "<span class=\"highlight_warning\">#!string!state_0006!#</span>" : "<span class=\"code\">--</span>";
		$an->data->{server}{$server}{node2_ready} = 0;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "server::${server}::say_node2",                    value1 => $an->data->{server}{$server}{say_node2},
			name2 => "node::${node2_name}::daemon::cman::exit_code", value2 => $an->data->{node}{$node2_name}{daemon}{cman}{exit_code},
		}, file => $THIS_FILE, line => __LINE__});
		
		# If a server's XML definition file is found but there is no host, the user probably forgot 
		# to define it.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "server::${server}::node::${node_name}::virsh::${key}", value1 => $an->data->{server}{$server}{node}{$node_name}{virsh}{$key},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			$an->data->{server}{$server}{say_node1} = "--";
			$an->data->{server}{$server}{say_node2} = "--";
			my $say_error = $an->String->get({key => "message_0271", variables => { 
					server	=>	$say_server,
					url	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&task=add_server&name=$say_server&node=$host_node&state=$server_state",
				}});
			$an->Striker->_error({message => $say_error, fatal => 0});
			next;
		}
		
		$an->data->{server}{$server}{host} = "" if not defined $an->data->{server}{$server}{host};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
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
			
			# Disable cluster withdrawl of this node.
			$an->data->{node}{$node1_name}{enable_withdraw} = 0;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
				name1 => "server",               value1 => $server,
				name2 => "node1_name",            value2 => $node1_name,
				name3 => "node2 ready",      value3 => $an->data->{server}{$server}{node2_ready},
				name4 => "can migrate",      value4 => $an->data->{server}{$server}{can_migrate},
				name5 => "migration target", value5 => $an->data->{server}{$server}{migration_target},
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
			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
				name1 => "server",               value1 => $server,
				name2 => "node1_name",            value2 => $node1_name,
				name3 => "node2 ready",      value3 => $an->data->{server}{$server}{node2_ready},
				name4 => "can migrate",      value4 => $an->data->{server}{$server}{can_migrate},
				name5 => "migration target", value5 => $an->data->{server}{$server}{migration_target},
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			$an->data->{server}{$server}{can_stop}      = 0;
			($an->data->{server}{$server}{node1_ready}) = $an->Striker->_check_node_readiness({server => $server, node => $node1_uuid});
			($an->data->{server}{$server}{node2_ready}) = $an->Striker->_check_node_readiness({server => $server, node => $node2_uuid});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "server",          value1 => $server,
				name2 => "node1_ready", value2 => $an->data->{server}{$server}{node1_ready},
				name3 => "node2_ready", value3 => $an->data->{server}{$server}{node2_ready},
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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
			my $say_server =  $server;
			   $say_server =~ s/^vm://;
			my $shell_call =  $an->data->{path}{virsh}." dumpxml $say_server";
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
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				$line =~ s/\s+/ /g;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				push @{$an->data->{server}{$server}{xml}}, $line;
			}
		}
		else
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "server::${server}::node1_ready", value1 => $an->data->{server}{$server}{node1_ready},
				name2 => "server::${server}::node2_ready", value2 => $an->data->{server}{$server}{node2_ready},
			}, file => $THIS_FILE, line => __LINE__});
			if (($an->data->{server}{$server}{node1_ready}) && ($an->data->{server}{$server}{node2_ready}))
			{
				# I can boot on either node, so choose the first one in the server's failover
				# domain.
				$an->data->{server}{$server}{boot_target} = $an->Striker->_find_preferred_host({server => $server});
				$an->data->{server}{$server}{can_start}   = 1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "server::${server}::boot_target", value1 => $an->data->{server}{$server}{boot_target},
					name2 => "server::${server}::can_start",   value2 => $an->data->{server}{$server}{can_start},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($an->data->{server}{$server}{node1_ready})
			{
				$an->data->{server}{$server}{boot_target} = $node1_name;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "server::${server}::boot_target", value1 => $an->data->{server}{$server}{boot_target},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($an->data->{server}{$server}{node2_ready})
			{
				$an->data->{server}{$server}{boot_target} = $node2_name;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "server::${server}::boot_target", value1 => $an->data->{server}{$server}{boot_target},
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				$an->data->{server}{$server}{can_start} = 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0124", code => 124, file => "$THIS_FILE", line => __LINE__});
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



#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0008", message_variables => {
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
			name1 => "server",        value1 => $server,
			name2 => "node_name", value2 => $node_name,
			name3 => "lv",        value3 => $lv,
			name4 => "on_res",    value4 => $on_res,
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}{$on_res}{connection_state} = $an->data->{drbd}{$on_res}{node}{$node_name}{connection_state};
		$an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}{$on_res}{role}             = $an->data->{drbd}{$on_res}{node}{$node_name}{role};
		$an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}{$on_res}{disk_state}       = $an->data->{drbd}{$on_res}{node}{$node_name}{disk_state};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
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

# This checks a node to see if it's ready to run a given server.
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
				# It's active, so now check the backing storage.
				foreach my $resource (sort {$a cmp $b} keys %{$an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}})
				{
					# For easier reading...
					my $connection_state = $an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}{$resource}{connection_state};
					my $role             = $an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}{$resource}{role};
					my $disk_state       = $an->data->{server}{$server}{node}{$node_name}{lv}{$lv}{drbd}{$resource}{disk_state};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
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
		name1 => "server",        value1 => $server,
		name2 => "node_name", value2 => $node_name,
		name3 => "ready",     value3 => $ready,
	}, file => $THIS_FILE, line => __LINE__});
	
	return ($ready);
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
		$an->data->{sys}{cgi_string} .= "expire=$expire_time";
	}
	
	print $an->Web->template({file => "server.html", template => "confirm-delete-server", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});
	
	return (0);
}

# Confirm that the user wants to join both nodes to the cluster.
sub _confirm_dual_join
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_confirm_dual_join" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $anvil_uuid  = $an->data->{cgi}{anvil_uuid};
	my $anvil_name  = $an->data->{sys}{anvil}{name};
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
	my $say_title               =  $an->String->get({key => "title_0038", variables => { node_name => $an->data->{cgi}{node_name} }});
	my $say_message             =  $an->String->get({key => "message_0151", variables => { node_name => $an->data->{cgi}{node_name} }});
	my $expire_time             =  time + $an->data->{sys}{actime_timeout};
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
	
	my $expire_time =  time + $an->data->{sys}{actime_timeout};
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

# Confirm that the user wants to join a node to the cluster.
sub _confirm_join_anvil
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_confirm_join_anvil" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $anvil_uuid  = $an->data->{cgi}{anvil_uuid};
	my $anvil_name  = $an->data->{sys}{anvil}{name};
	my $say_title = $an->String->get({key => "title_0036", variables => { 
			node_name	=>	$an->data->{cgi}{node_name},
			anvil		=>	$anvil_name,
		}});
	my $say_message = $an->String->get({key => "message_0147", variables => { node_name => $an->data->{cgi}{node_name} }});
	print $an->Web->template({file => "server.html", template => "confirm-join-anvil", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
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
	my $anvil_data  = $an->Get->anvil_data({uuid => $an->data->{cgi}{anvil_uuid});
	my $anvil_uuid  = $anvil_uuid->{anvil_uuid};
	my $server_uuid = $an->Get->server_uuid({
			server => $an->data->{cgi}{server},
			anvil  => $anvil_uuid,
		});
	
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

	# Ask the user to confirm
	my $say_title = $an->String->get({key => "title_0047", variables => { 
			server	=>	$an->data->{cgi}{server},
			target	=>	$an->data->{cgi}{target},
		}});
	my $say_message = $an->String->get({key => "message_0177", variables => { 
			server			=>	$an->data->{cgi}{server},
			target			=>	$an->data->{cgi}{target},
			ram			=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{vm_ram} }),
			migration_time_estimate	=>	$migration_time_estimate,
		}});
	print $an->Web->template({file => "server.html", template => "confirm-migrate-server", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
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

# Confirm that the user wants to join both nodes to the cluster.
sub _confirm_withdraw_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_confirm_withdraw_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $anvil_uuid  = $an->data->{cgi}{anvil_uuid};
	my $anvil_name  = $an->data->{sys}{anvil}{name};
	my $say_title = $an->String->get({key => "title_0035", variables => { 
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

# This stops the VM, if it's running, edits the cluster.conf to remove the VM's entry, pushes the changed 
# cluster out, deletes the VM's definition file and finally deletes the LV.
sub _delete_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_delete_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make sure the server name exists.
	my $server     = $an->data->{cgi}{server}     ? $an->data->{cgi}{server}     : "";
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid} ? $an->data->{cgi}{anvil_uuid} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $anvil_uuid)
	{
		# Hey user, don't be cheeky!
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0134", code => 134, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	### TODO: If this fails, check to see if the 'vm:' prefix needs to be added
	my $server_host = $an->data->{server}{$server}{host};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "server_host", value1 => $server_host,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If the server is on, we'll do our work through that node.
	my $node_key    = "";
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
	my $node_name = ""
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target", value1 => $target,
			name2 => "port",   value2 => $port,
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
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0135", message_variables => { server => $server }, code => 135, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	# Has the timer expired?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "current time", value1 => time,
		name2 => "cgi::expire",  value2 => $an->data->{cgi}{expire},
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
	
	# Remove the server from the cluster.
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
		name1 => "ccs exit code", value1 => $ccs_exit_code,
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
		name1 => "stop_server",   value1 => $stop_server,
		name2 => "ccs_exit_code", value2 => $ccs_exit_code,
	}, file => $THIS_FILE, line => __LINE__});
	if ((($server_host) && ($server_host ne "none")) && ($ccs_exit_code eq "0"))
	{
		# Server is still running, kill it.
		print $an->Web->template({file => "server.html", template => "delete-server-force-off-header"});
		
		   $proceed         = 0;
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
			name1 => "virsh exit code", value1 => $virsh_exit_code,
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
		
		### NOTE: Yes, the actual path is in '$an->data->{server}{$server}{definition_file}', but 
		###       we're doing an 'rm -f' so we're going to be paranoid.
		# Regardless of whether the LV removal(s) succeeded, delete the definition file.
		my $file         = $an->data->{server}{$server}{definition_file};
		my $ls_exit_code = 255;
		my $shell_call   = "
if [ '/shared/definitions/${server}.xml' ];
then
    ".$an->data->{path}{rm}." -f /shared/definitions/${server}.xml;
    ".$an->data->{path}{ls}." /shared/definitions/${server}.xml;
    ".$an->data->{path}{echo}." ls:\$?
fi;
";
		my $password   = $an->data->{sys}{root_password};
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
		my $return = $an->Get->server_data({
			server => $say_vm, 
			anvil  => $cluster, 
		});
		my $server_uuid = $return->{uuid};
		my $query       = "
UPDATE 
    servers 
SET 
    server_note = 'DELETED' 
WHERE 
    server_uuid = ".$an->data->{sys}{use_db_fh}->quote($server_uuid)."
;";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
		
		my $message = $an->String->get({key => "message_0205", variables => { server => $say_vm }});
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
	my $this_cluster            = $an->data->{cgi}{anvil_uuid};
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

# This creates the summary page after a cluster has been selected.
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
			
			# This shows the status of each DRBD resource in the cluster.
			$drbd_details_panel = $an->Striker->_display_drbd_details();
			
			# Show the free resources available for new servers.
			$free_resources_panel = $an->Striker->_display_free_resources();
			
			# This generates a panel below 'Available Resources' 
			# *if* the user has enabled 'tools::anvil-kick-apc-ups::enabled'
			$watchdog_panel = $an->Striker->_display_watchdog_panel({note => ""});
		}
		else
		{
			# Was able to confirm the nodes are off.
			$no_access_panel = $an->Web->template({file => "server.html", template => "display-details-nodes-unreachable", replace => { message => "#!string!message_0268!#" }});
			
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

# This shows the status of each DRBD resource in the cluster.
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
					$say_n1_ds .= " <span class=\"subtle_text\" style=\"font-style: normal;\">($an->data->{drbd}{$res}{node}{$node1}{resync_percent}%)</span>";
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
					$say_n2_ds .= " <span class=\"subtle_text\" style=\"font-style: normal;\">($an->data->{drbd}{$res}{node}{$node2}{resync_percent}%)</span>";
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
		# If it's not a clustered VG, I don't care about it.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name2 => "resources::vg::${vg}::clustered", value2 => $an->data->{resources}{vg}{$vg}{clustered},
		}, file => $THIS_FILE, line => __LINE__});
		next if not $an->data->{resources}{vg}{$vg}{clustered};
		push @vg,      $vg;
		push @vg_size, $an->data->{resources}{vg}{$vg}{size};
		push @vg_used, $an->data->{resources}{vg}{$vg}{used_space};
		push @vg_free, $an->data->{resources}{vg}{$vg}{free_space};
		push @pv_name, $an->data->{resources}{vg}{$vg}{pv_name};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "resources::vg::${vg}::size",       value1 => $an->data->{resources}{vg}{$vg}{size},
			name2 => "resources::vg::${vg}::used_space", value2 => $an->data->{resources}{vg}{$vg}{used_space},
			name3 => "resources::vg::${vg}::free_space", value3 => $an->data->{resources}{vg}{$vg}{free_space},
			name4 => "resources::vg::${vg}::pv_name",    value4 => $an->data->{resources}{vg}{$vg}{pv_name},
		}, file => $THIS_FILE, line => __LINE__});
		
		# If there is at least a GiB free, mark free storage as sufficient.
		if (not $an->data->{sys}{clvmd_down})
		{
			$enough_storage =  1 if $an->data->{resources}{vg}{$vg}{free_space} > (2**30);
			$vg_link        .= "$vg:$an->data->{resources}{vg}{$vg}{free_space},";
		}
	}
	$vg_link =~ s/,$//;
	
	# Count how much RAM and CPU cores have been allocated.
	my $allocated_cores = 0;
	my $allocated_ram   = 0;
	foreach my $server (sort {$a cmp $b} keys %{$an->data->{server}})
	{
		next if $server !~ /^vm/;
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
				name1 => "allocated_ram",           value1 => $allocated_ram,
				name2 => "allocated_cores",         value2 => $allocated_cores,
				name3 => "server::${server}::details::ram", value3 => $an->data->{server}{$server}{details}{ram},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Always knock off some RAM for the host OS.
	my $real_total_ram            =  $an->Readable->bytes_to_hr({'bytes' => $an->data->{resources}{total_ram} });
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
		# The cluster is running, so enable the media library link.
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
	
	foreach my $node ($an->data->{sys}{anvil}{node1}{name}, $an->data->{sys}{anvil}{node2}{name})
	{
		$an->data->{node}{$node}{enable_withdraw} = 0 if not defined $an->data->{node}{$node}{enable_withdraw};
		
		# Join button.
		my $say_join_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0031!#" }});
		
		### TODO: See if the peer is online already and, if so, add 'confirm=true' as the join is safe.
		my $say_join_enabled_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
				button_class	=>	"bold_button",
				button_link	=>	"?anvil_uuid=$anvil_uuid&task=join_anvil&node=$node",
				button_text	=>	"#!string!button_0031!#",
				id		=>	"join_anvil_$node",
			}});
		$say_join[$i] = $an->data->{node}{$node}{enable_join} ? $say_join_enabled_button : $say_join_disabled_button;
		$say_join[$i] = $say_join_disabled_button if $disable_join;
		   
		# Withdraw button
		my $say_withdraw_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0032!#" }});
		my $say_withdraw_enabled_button  = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	"?anvil_uuid=$anvil_uuid&task=withdraw&node=$node",
				button_text	=>	"#!string!button_0032!#",
				id		=>	"withdraw_$node",
			}});
		$say_withdraw[$i] = $an->data->{node}{$node}{enable_withdraw} ? $say_withdraw_enabled_button : $say_withdraw_disabled_button;
		
		# Shutdown button
		my $say_shutdown_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0033!#" }});
		my $say_shutdown_enabled_button  = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	"?anvil_uuid=$anvil_uuid&expire=$expire_time&task=poweroff_node&node=$node",
				button_text	=>	"#!string!button_0033!#",
				id		=>	"poweroff_node_$node",
			}});
		$say_shutdown[$i] = $an->data->{node}{$node}{enable_poweroff} ? $say_shutdown_enabled_button : $say_shutdown_disabled_button;
		
		# Boot button
		my $say_boot_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0034!#" }});
		my $say_boot_enabled_button  = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
				button_class	=>	"bold_button",
				button_link	=>	"?anvil_uuid=$anvil_uuid&task=poweron_node&node=$node&confirm=true",
				button_text	=>	"#!string!button_0034!#",
				id		=>	"poweron_node_$node",
			}});
		$say_boot[$i] = $an->data->{node}{$node}{enable_poweron} ? $say_boot_enabled_button : $say_boot_disabled_button;
		
		# Fence button
		# If the node is already confirmed off, no need to fence.
		my $say_fence_node_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0037!#" }});
		my $expire_time                    = time + $an->data->{sys}{actime_timeout};
		# &expire=$expire_time
		my $say_fence_node_enabled_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
				button_class	=>	"highlight_dangerous",
				button_link	=>	"?anvil_uuid=$anvil_uuid&expire=$expire_time&task=fence_node&node=$node",
				button_text	=>	"#!string!button_0037!#",
				id		=>	"fence_node_$node",
			}});
		$say_fence[$i] = $an->data->{node}{$node}{enable_poweron} ? $say_fence_node_disabled_button : $say_fence_node_enabled_button;
		
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
		$say_node_name[$i] = $an->data->{node}{$node}{info}{host_name};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "i",                              value1 => $i,
			name2 => "node::${node}::info::host_name", value2 => $an->data->{node}{$node}{info}{host_name},
			name3 => "say_node_name",                  value3 => $say_node_name[$i],
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{node}{$node}{connected})
		{
			$say_node_name[$i] = $an->Web->template({file => "common.html", template => "enabled-button-new-tab", replace => { 
					button_class	=>	"fixed_width_button",
					button_link	=>	"?anvil_uuid=$anvil_uuid&task=display_health&node=$node",
					button_text	=>	$an->data->{node}{$node}{info}{host_name},
					id		=>	"display_health_$node",
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
					button_text	=>	$an->data->{node}{$node}{info}{host_name},
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
		next if $server !~ /^vm/;
		
		my $say_server  = ($server =~ /^vm:(.*)/)[0];
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
				push @bridge, $current_bridge;
				push @device, $an->data->{server}{$server}{details}{bridge}{$current_bridge}{device};
				push @mac,    uc($an->data->{server}{$server}{details}{bridge}{$current_bridge}{mac});
				push @type,   $an->data->{server}{$server}{details}{bridge}{$current_bridge}{type};
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
						bridge	=>	$bridge[0],
						device	=>	$device[0],
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0008", message_variables => {
			name1 => "say_server",                            value1 => $say_server,
			name2 => "server::${server}::details::cpu_count", value2 => $an->data->{server}{$server}{details}{cpu_count},
			name3 => "say_ram",                               value3 => $say_ram,
			name4 => "lv_path[0]",                            value4 => $lv_path[0],
			name5 => "lv_size[0]",                            value5 => $lv_size[0],
			name6 => "say_net_host",                          value6 => $say_net_host,
			name7 => "type[0]",                               value7 => $type[0],
			name8 => "mac[0]",                                value8 => $mac[0],
		}, file => $THIS_FILE, line => __LINE__});
		$server_details_panel .= $an->Web->template({file => "server.html", template => "display-server-details-resources", replace => { 
				say_server	=>	$say_server,
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
								bridge		=>	$bridge[$i],
								device		=>	$device[$i],
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
		my ($say_server) = ($server =~ /^vm:(.*)/);
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "server",     value1 => $server,
			name2 => "say_server", value2 => $say_server,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Use the node's short name for the buttons.
		my $say_start_target     =  $an->data->{server}{$server}{boot_target} ? $an->data->{server}{$server}{boot_target} : "--";
		   $say_start_target     =~ s/\..*?$//;
		my $start_target_long    =  $node1_name =~ /$say_start_target/ ? $an->data->{node}{$node1_name}{info}{host_name} : $an->data->{node}{$node2_name}{info}{host_name};
		my $start_target_name    =  $node1_name =~ /$say_start_target/ ? $node1_name : $node2_name;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "say_start_target",           value1 => $say_start_target,
			name2 => "server::${server}::boot_target", value2 => $an->data->{server}{$server}{boot_target},
			name3 => "start_target_long",          value3 => $start_target_long,
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
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
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
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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
			my $button_link = "?anvil_uuid=$anvil_uuid&server=$say_server&task=migrate_server";
			my $server_data = $an->Get->server_data({
				server   => $say_server, 
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
					button_link	=>	"?anvil_uuid=$anvil_uuid&server=$say_server&task=stop_server",
					button_text	=>	"#!string!button_0028!#",
					id		=>	"stop_server_$server",
				}});
			$force_off_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
					button_class	=>	"highlight_dangerous",
					button_link	=>	"?anvil_uuid=$anvil_uuid&server=$say_server&task=force_off_server&expire=$expire_time",
					button_text	=>	"#!string!button_0027!#",
					id		=>	"force_off_server_$say_server",
				}});
		}
		my $start_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0029!#" }});

		if ($an->data->{server}{$server}{boot_target})
		{
			$start_button = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"?anvil_uuid=$anvil_uuid&server=$say_server&task=start_server&confirm=true",
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
					button_link	=>	"?anvil_uuid=$anvil_uuid&server=$say_server&task=delete_server",
					button_text	=>	"#!string!button_0030!#",
					id		=>	"delete_server_$say_server",
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
		
		# I don't want to make the server editable until the cluster is running on at least one node.
		my $dual_join       = (($an->data->{node}{$node1_name}{enable_join}) && ($an->data->{node}{$node2_name}{enable_join})) ? 1 : 0;
		my $say_server_link = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
			button_class	=>	"fixed_width_button",
			button_link	=>	"?anvil_uuid=$anvil_uuid&server=$server&task=manage_server",
			button_text	=>	"$say_server",
			id		=>	"manage_server_$say_server",
		}});
		if ($dual_join)
		{
			my $say_server_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => $say_server }});
			   $say_server_link            = $say_server_disabled_button;
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
	
	my $note             = $parameter->{note} ? $parameter->{note} : "";
	my $expire_time      = time + $an->data->{sys}{actime_timeout};
	my $power_cycle_link = "?anvil_uuid=$anvil_uuid&expire=$expire_time&task=cold_stop&subtask=power_cycle";
	my $power_off_link   = "?anvil_uuid=$anvil_uuid&expire=$expire_time&task=cold_stop&subtask=power_off";
	my $watchdog_panel   = "";
	my $use_node         = "";
	my $enable           = 0;
	my $target           = "";
	my $port             = "";
	my $password         = "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "note",             value1 => $note,
		name2 => "expire_time",      value2 => $expire_time,
		name3 => "power_cycle_link", value3 => $power_cycle_link,
		name4 => "power_off_link",   value4 => $power_off_link,
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $node_key ("node1", "node2")
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::anvil::${node_key}::online", value1 => $an->data->{sys}{anvil}{$node_key}{online},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{sys}{anvil}{$node_key}{online})
		{
			$use_node = $node_key;
			$target   = $an->data->{sys}{anvil}{$use_node}{use_ip};
			$port     = $an->data->{sys}{anvil}{$use_node}{use_port};
			$password = $an->data->{sys}{anvil}{$use_node}{password};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "use_node", value1 => $use_node,
				name2 => "target",   value2 => $target,
				name3 => "port",     value3 => $port,
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
				name1 => "password", value1 => $password,
			}, file => $THIS_FILE, line => __LINE__});
			last;
		}
	}
	
	### TODO: If not 'use_node', use our local copy of the watchdog script if we can reach the UPSes.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "tools::anvil-kick-apc-ups::enabled", value1 => $an->data->{tools}{'anvil-kick-apc-ups'}{enabled},
		name2 => "use_node",                           value2 => $use_node,
	}, file => $THIS_FILE, line => __LINE__});
	if ($use_node)
	{
		# Check that 'anvil-kick-apc-ups' exists.
		my $shell_call = "
if \$(".$an->data->{path}{nodes}{'grep'}." -q '^tools::anvil-kick-apc-ups::enabled\\s*=\\s*1' ".$an->data->{path}{nodes}{striker_config}.");
then 
    ".$an->data->{path}{echo}." enabled; 
else 
    ".$an->data->{path}{echo}." disabled;
fi";
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
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line eq "enabled")
			{
				$enable = 1;
			}
		}
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "enable", value1 => $enable,
		}, file => $THIS_FILE, line => __LINE__});
		if ($enable)
		{
			# It exists, load the template
			$watchdog_panel = $an->Web->template({file => "server.html", template => "watchdog_panel", replace => { 
					power_cycle	=>	$power_cycle_link,
					power_off	=>	$power_off_link,
				}});
			$watchdog_panel =~ s/\n$//;
		}
	}
	else
	{
		# Anvil! is down, try to use our own copy.
		my $shell_call = "
if \$(".$an->data->{path}{'grep'}." -q '^tools::anvil-kick-apc-ups::enabled\\s*=\\s*1' ".$an->data->{path}{striker_config}.");
then 
    ".$an->data->{path}{echo}." enabled; 
else 
    ".$an->data->{path}{echo}." disabled;
fi
";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line eq "enabled")
			{
				$enable = 1;
			}
		}
		close $file_handle;
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "enable", value1 => $enable,
		}, file => $THIS_FILE, line => __LINE__});
		if ($enable)
		{
			# It exists, load the template
			$power_cycle_link .= "&note=$note";
			$power_off_link   .= "&note=$note";
			$watchdog_panel   =  $an->Web->template({file => "server.html", template => "watchdog_panel", replace => { 
					power_cycle	=>	$power_cycle_link,
					power_off	=>	$power_off_link,
				}});
			$watchdog_panel =~ s/\n$//;
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "watchdog_panel", value1 => $watchdog_panel,
	}, file => $THIS_FILE, line => __LINE__});
	return($watchdog_panel);
}

# This sttempts to start the cluster stack on both nodes simultaneously.
sub _dual_join
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_dual_join" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# grab the CGI data
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $node_name  = $an->data->{cgi}{node_name};
	
	if (not $anvil_uuid)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0141", code => 141, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	if (not $node_name)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0142", code => 142, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
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
	
	# Scan the Anvil!.
	$an->Striker->scan_anvil();
	
	# Proceed only if all of the storage components, cman and rgmanager are off.
	my @abort_reason;
	foreach my $node ($node_name, $peer_name)
	{
		if (($an->data->{node}{$node}{daemon}{cman}{exit_code}      eq "0") or
		    ($an->data->{node}{$node}{daemon}{rgmanager}{exit_code} eq "0") or
		    ($an->data->{node}{$node}{daemon}{drbd}{exit_code}      eq "0") or
		    ($an->data->{node}{$node}{daemon}{clvmd}{exit_code}     eq "0") or
		    ($an->data->{node}{$node}{daemon}{gfs2}{exit_code}      eq "0"))
		{
			# Already joined the Anvil!
			   $proceed = 0;
			my $reason  = $an->String->get({key => "message_0190", variables => { node => $node }});
			push @abort_reason, $reason;
		}
	}
	if ($proceed)
	{
		my $say_title = $an->String->get({key => "title_0054", variables => { anvil => $anvil_name }});
		print $an->Web->template({file => "server.html", template => "dual-join-anvil-header", replace => { title => $say_title }});
		
		# Now call the command against both nodes using '$an->Remote->synchronous_command_run()'.
		my $command         = $an->data->{path}{initd}."/cman start && ".$an->data->{path}{initd}."/rgmanager start";
		my ($node1, $node2) = @{$an->data->{clusters}{$cluster}{nodes}};
		my $password        = $an->data->{sys}{root_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "command", value1 => $command,
			name2 => "node1",   value2 => $node1,
			name3 => "node2",   value3 => $node2,
		}, file => $THIS_FILE, line => __LINE__});
		my ($output) = $an->Remote->synchronous_command_run({
			command		=>	$command, 
			node1		=>	$node1, 
			node2		=>	$node2, 
			delay		=>	0,
			password	=>	$password, 
		});
		
		foreach my $node ($node_name, $peer_name)
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "output->$node", value1 => $output->{$node},
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $line (split/\n/, $output->{$node})
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
					node	=>	$node,
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
	
	exit(1) if $fatal;
	return(1);
}

# Footer that closes out all pages.
sub _footer
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_footer" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "sys::footer_printed", value1 => $an->data->{sys}{footer_printed},
	}, file => $THIS_FILE, line => __LINE__});
	return(0) if $an->data->{sys}{footer_printed}; 
	
	print $an->Web->template({file => "common.html", template => "footer"});
	$an->data->{sys}{footer_printed} = 1;
	
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
	
	if (not $anvil_uuid)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0143", code => 143, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	if (not $node_name)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0144", code => 144, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
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
	
	# Has the timer expired?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "current time", value1 => time,
		name2 => "cgi::expire",  value2 => $an->data->{cgi}{expire},
	}, file => $THIS_FILE, line => __LINE__});
	if (time > $an->data->{cgi}{expire})
	{
		# Abort!
		my $say_title   = $an->String->get({key => "title_0188"});
		my $say_message = $an->String->get({key => "message_0447", variables => { node => $node_name} }});
		print $an->Web->template({file => "server.html", template => "request-expired", replace => { 
			title		=>	$say_title,
			message		=>	$say_message,
		}});
		return(1);
	}
	
	# Scan the cluster
	$an->Striker->scan_anvil();
	
	# Now, if I can reach the peer node, use it to fence the target. Otherwise, we'll try to fence it 
	# using cached 'power_check' data, if available.
	if ($an->data->{sys}{anvil}{$peer_key}{online})
	{
		# Sweet, fence via the peer.
		my $say_title   = $an->String->get({key => "title_0068", variables => { node_anvil_name => $node_cluster_name }});
		my $say_message = $an->String->get({key => "message_0233", variables => { node_anvil_name => $node_cluster_name }});
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
			print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
				status	=>	$status,
				message	=>	$message,
			}});
		}
		print $an->Web->template({file => "server.html", template => "fence-node-output-footer"});
		print $an->Web->template({file => "server.html", template => "fence-node-footer"});
	}
	else
	{
		# OK, use cache to try to call it locally
		my $say_title   = $an->String->get({key => "title_0068", variables => { node_anvil_name => $node_cluster_name }});
		my $say_message = $an->String->get({key => "message_0233", variables => { node_anvil_name => $node_cluster_name }});
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
			}
			else
			{
				# She's dead, Jim.
			}
		}
		else
		{
			# Something went wrong.
		}
	}
	
	$an->Striker->_footer();
	
	
	
	
	# See if I already have the fence string. If not, load it from cache.
	if ($an->data->{node}{$node_name}{info}{fence_methods})
	{
		$fence_string = $an->data->{node}{$node_name}{info}{fence_methods};
	}
	else
	{
		
		AN::Cluster::read_node_cache($an, $node);
		if ($an->data->{node}{$node}{info}{fence_methods})
		{
			$fence_string = $an->data->{node}{$node}{info}{fence_methods};
		}
		else
		{
			   $proceed = 0;
			my $reason  = $an->String->get({key => "message_0231", variables => { node => $node }});
			push @abort_reason, "$reason\n";
		}
	}
	
	# If the peer node is up, use the fence command as compiled by it. 
	# Otherwise, read the cache. If the fence command(s) are still not
	# available, abort.
	if ($proceed)
	{
		if (not $an->data->{node}{$peer}{up})
		{
			# See if this machine can reach each '-a ...' fence device
			# address.
			foreach my $address ($fence_string =~ /-a\s(.*?)\s/g)
			{
				my ($local_access, $target_ip) = AN::Cluster::on_same_network($an, $address, $node);
				if (not $local_access)
				{
					   $proceed = 0;
					my $reason  = $an->String->get({key => "message_0232", variables => { 
							node	=>	$node,
							peer	=>	$peer,
							address	=>	$address,
						}});
					push @abort_reason, "$reason\n";
				}
			}
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node",    value1 => $node,
		name2 => "proceed", value2 => $proceed,
	}, file => $THIS_FILE, line => __LINE__});
	if ($proceed)
	{
		my $say_title   = $an->String->get({key => "title_0068", variables => { node_anvil_name => $node_cluster_name }});
		my $say_message = $an->String->get({key => "message_0233", variables => { node_anvil_name => $node_cluster_name }});
		print $an->Web->template({file => "server.html", template => "fence-node-header", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});

		# This loops for each method, which may have multiple device calls. I parse each call into an
		# 'off' and 'on' call. If the 'off' call fails, I go to the next method until there are no
		# methods left. If the 'off' works, I call the 'on' call from the same method to (try to) 
		# boot the node back up (or simply unfence it in the case of PDUs and the like).
		my $fence_success   = 0;
		my $unfence_success = 0;
		foreach my $line ($fence_string =~ /\d+:.*?;\./g)
		{
			print $an->Web->template({file => "server.html", template => "fence-node-output-header"});
			my ($method_num, $method_name, $command) = ($line =~ /(\d+):(.*?): (.*?;)\./);
			my $off_command = $command;
			my $on_command  = $command;
			my $off_success = 1;
			my $on_success  = 1;
			
			# If the peer is up, set the command to run through it.
			if ($an->data->{node}{$peer}{up})
			{
				# When called remotely, I need to double-escape
				# the $? to protect it inside the "".
				$off_command =~ s/#!action!#;/off; echo fence:\$?;/g;
				$on_command  =~ s/#!action!#;/on;  echo fence:\$?;/g;
				$off_command = "ssh:$peer,$off_command";
				$on_command  = "ssh:$peer,$on_command";
			}
			else
			{
				# When called locally, I only need to escape
				# the $? once.
				$off_command =~ s/#!action!#;/off; echo fence:\$?;/g;
				$on_command  =~ s/#!action!#;/on;  echo fence:\$?;/g;
			}
			
			# Make the off attempt.
			my $output = [];
			my $ssh_fh;
			my $shell_call = "$off_command";
			if ($shell_call =~ /ssh:(.*?),(.*)$/)
			{
				my $node       = $1;
				my $shell_call = $2;
				my $password   = $an->data->{sys}{root_password};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
					name2 => "node",       value2 => $node,
				}, file => $THIS_FILE, line => __LINE__});
				my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$node,
					port		=>	$an->data->{node}{$node}{port}, 
					password	=>	$password,
					ssh_fh		=>	"",
					'close'		=>	0,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			else
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
				open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
				while(<$file_handle>)
				{
					chomp;
					push @{$output}, $_;
				}
				$file_handle->close()
			}
			foreach my $line (@{$output})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node", value1 => $node,
					name2 => "line", value2 => $line,
				}, file => $THIS_FILE, line => __LINE__});
				# This is how I get the fence call's exit code.
				if ($line =~ /fence:(\d+)/)
				{
					# Anything but '0' is a failure.
					my $exit = $1;
					if ($exit ne "0")
					{
						$off_success = 0;
					}
				}
				else
				{
					print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
				}
			}
			print $an->Web->template({file => "server.html", template => "fence-node-output-footer"});
			if ($off_success)
			{
				# Fence succeeded!
				$an->Log->entry({log_level => 2, message_key => "log_0253", message_variables => {
					method_name => $method_name, 
				}, file => $THIS_FILE, line => __LINE__});
				my $say_message = $an->String->get({key => "message_0234", variables => { method_name => $method_name }});
				print $an->Web->template({file => "server.html", template => "fence-node-message", replace => { message => $say_message }});
				$fence_success = 1;
			}
			else
			{
				# Fence failed!
				$an->Log->entry({log_level => 2, message_key => "log_0254", message_variables => {
					method_name => $method_name, 
				}, file => $THIS_FILE, line => __LINE__});
				my $say_message = $an->String->get({key => "message_0235", variables => { method_name => $method_name }});
				print $an->Web->template({file => "server.html", template => "fence-node-message", replace => { message => $say_message }});
				next;
			}
			
			# If I'm here, I can try the unfence command.
			print $an->Web->template({file => "server.html", template => "fence-node-unfence-header"});
			$shell_call = "$on_command";
			if ($shell_call =~ /ssh:(.*?),(.*)$/)
			{
				my $node       = $1;
				my $shell_call = $2;
				my $password   = $an->data->{sys}{root_password};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
					name2 => "node",       value2 => $node,
				}, file => $THIS_FILE, line => __LINE__});
				my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$node,
					port		=>	$an->data->{node}{$node}{port}, 
					password	=>	$password,
					ssh_fh		=>	"",
					'close'		=>	0,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			else
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
				open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
				while(<$file_handle>)
				{
					chomp;
					push @{$output}, $_;
				}
				$file_handle->close()
			}
			foreach my $line (@{$output})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node", value1 => $node,
					name2 => "line", value2 => $line,
				}, file => $THIS_FILE, line => __LINE__});
				# This is how I get the fence call's exit code.
				if ($line =~ /fence:(\d+)/)
				{
					# Anything but '0' is a failure.
					my $exit = $1;
					if ($exit ne "0")
					{
						$on_success = 0;
					}
				}
				else
				{
					print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
				}
			}
			print $an->Web->template({file => "server.html", template => "fence-node-unfence-footer"});
			if ($on_success)
			{
				# Unfence succeeded!
				$an->Log->entry({log_level => 2, message_key => "log_0254", message_variables => {
					method_name => $method_name, 
				}, file => $THIS_FILE, line => __LINE__});
				my $say_message = $an->String->get({key => "message_0236", variables => { method_name => $method_name }});
				print $an->Web->template({file => "server.html", template => "fence-node-message", replace => { message => $say_message }});
				$unfence_success = 1;
				last;
			}
			else
			{
				# Unfence failed!
				# This is allowed to go to the next fence method because some servers may 
				# hang their IPMI interface after a fence call, requiring power to be cut in
				# order to reset the BMC. HP, I'm looking at you and your DL1** G7 line...
				my $say_message = $an->String->get({key => "message_0237", variables => { method_name => $method_name }});
				print $an->Web->template({file => "server.html", template => "fence-node-message", replace => { message => $say_message }});
			}
		}
	}
	else
	{
		my $say_title = $an->String->get({key => "title_0069", variables => { node_anvil_name => $node_cluster_name }});
		print $an->Web->template({file => "server.html", template => "fence-node-aborted-header", replace => { title => $say_title }});
		foreach my $reason (@abort_reason)
		{
			print $an->Web->template({file => "server.html", template => "fence-node-abort-reason", replace => { reason => $reason }});
		}
	}
	print $an->Web->template({file => "server.html", template => "fence-node-footer"});
	AN::Cluster::footer($an);
	
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
		# Not yet defined in the cluster.
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

# This forcibly shuts down a VM on a target node. The cluster should restart it shortly after.
sub _force_off_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_force_off_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make sure the server name exists.
	my $server     = $an->data->{cgi}{server}     ? $an->data->{cgi}{server}     : "";
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid} ? $an->data->{cgi}{anvil_uuid} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $anvil_uuid)
	{
		# Hey user, don't be cheeky!
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0132", code => 132, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	### TODO: If this fails, check to see if the 'vm:' prefix needs to be added
	my $server_host = $an->data->{server}{$server}{host};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "server_host", value1 => $server_host,
	}, file => $THIS_FILE, line => __LINE__});
	if ($server_host eq "none")
	{
		# It's already off.
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
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0133", message_variables => {
			server => $server, 
			host   => $server_host,
		}, code => 133, file => "$THIS_FILE", line => __LINE__});
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
		name1 => "current time", value1 => time,
		name2 => "cgi::expire",  value2 => $an->data->{cgi}{expire},
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
		print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
			status	=>	$status,
			message	=>	$message,
		}});
	}
	print $an->Web->template({file => "server.html", template => "force-off-server-footer"});
	
	return(0);
}

### NOTE: This is ugly, but it's basically a port of the old function so ya, whatever.
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
	
	my $shell_call = $an->data->{path}{dmidecode}." -t 4,16,17";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
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
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $anvil_safe_start) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# Get meminfo
	$shell_call = $an->data->{path}{cat}." ".$an->data->{path}{proc_meminfo};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
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
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $proc_drbd) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	$shell_call = $an->data->{path}{drbdadm}." dump-xml";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $parse_drbdadm_dumpxml) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# clustat info
	$shell_call = $an->data->{path}{clustat};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $clustat) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# Read cluster.conf
	$shell_call = $an->data->{path}{cat}." ".$an->data->{path}{cman_config};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $cluster_conf) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# Read the daemon states
	$shell_call = "
".$an->data->{path}{initd}."/rgmanager status; ".$an->data->{path}{echo}." striker:rgmanager:\$?; 
".$an->data->{path}{initd}."/cman status; ".$an->data->{path}{echo}." striker:cman:\$?; 
".$an->data->{path}{initd}."/drbd status; ".$an->data->{path}{echo}." striker:drbd:\$?; 
".$an->data->{path}{initd}."/clvmd status; ".$an->data->{path}{echo}." striker:clvmd:\$?; 
".$an->data->{path}{initd}."/gfs2 status; ".$an->data->{path}{echo}." striker:gfs2:\$?; 
".$an->data->{path}{initd}."/libvirtd status; ".$an->data->{path}{echo}." striker:libvirtd:\$?;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $daemons) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# LVM data
	$shell_call = "
".$an->data->{path}{pvscan}."; 
".$an->data->{path}{vgscan}."; 
".$an->data->{path}{lvscan};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $lvm_scan) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	$shell_call = "
".$an->data->{path}{pvs}." --units b --separator \\\#\\\!\\\# -o pv_name,vg_name,pv_fmt,pv_attr,pv_size,pv_free,pv_used,pv_uuid; 
".$an->data->{path}{vgs}." --units b --separator \\\#\\\!\\\# -o vg_name,vg_attr,vg_extent_size,vg_extent_count,vg_uuid,vg_size,vg_free_count,vg_free,pv_name; 
".$an->data->{path}{lvs}." --units b --separator \\\#\\\!\\\# -o lv_name,vg_name,lv_attr,lv_size,lv_uuid,lv_path,devices;",
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
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
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $gfs2) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# virsh data
	$shell_call = $an->data->{path}{virsh}." list --all";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $virsh) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# server definitions - from file
	$shell_call = $an->data->{path}{cat}." ".$an->data->{path}{definitions}."/*";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
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
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $server_defs_in_mem) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# Host name, in case the cluster isn't configured yet.
	$shell_call = $an->data->{path}{hostname};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
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
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
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

# This sets up and displays the old-style header.
sub _header
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_header" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $caller = $parameter->{'caller'} ? $parameter->{'caller'} : "striker";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "caller", value1 => $caller,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Load some data
	my $anvil_name = "";
	my $anvil_uuid = "";
	my $node1_name = "";
	my $node2_name = "";
	if ($an->data->{cgi}{anvil_uuid})
	{
		$an->Striker->load_anvil();
		$anvil_uuid = $an->data->{cgi}{anvil_uuid};
		$anvil_name = $an->data->{sys}{anvil}{name};
		$node1_name = $an->data->{sys}{anvil}{node1}{name};
		$node2_name = $an->data->{sys}{anvil}{node2}{name};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "anvil_uuid", value1 => $anvil_uuid,
			name2 => "anvil_name", value2 => $anvil_name,
			name3 => "node1_name", value3 => $node1_name,
			name4 => "node2_name", value4 => $node2_name,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Header buttons.
	my $say_back        = "&nbsp;";
	my $say_refresh     = "&nbsp;";
	
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
	
	if ($an->data->{cgi}{config})
	{
		$an->data->{sys}{cgi_string} =~ s/anvil_uuid=(.*?)&//;
		$an->data->{sys}{cgi_string} =~ s/anvil_uuid=(.*)$//;
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
			elsif ($an->data->{cgi}{task} eq "create-install-manifest")
			{
				my $link =  $an->data->{sys}{cgi_string};
				   $link =~ s/generate=true//;
				   $link =~ s/anvil_password=.*?&//;
				   $link =~ s/anvil_password=.*?$//;	# Catch the password if it's the last variable in the URL
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
							button_link	=>	"?config=true&task=create-install-manifest",
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
							button_link	=>	"?config=true&task=create-install-manifest",
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
							button_link	=>	"?config=true&task=create-install-manifest",
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
					button_link	=>	"?anvil_uuid=$anvil_uuid&node=".$an->data->{cgi}{node}."&task=display_health",
					button_text	=>	"$refresh_image",
					id		=>	"refresh",
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
		if ($an->data->{sys}{cgi_string} =~ /\?anvil_uuid.*?&task=display_health&node=.*?$/)
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

# This sttempts to shut down a VM on a target node.
sub _join_anvil
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_join_anvil" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# grab the CGI data
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $node_name  = $an->data->{cgi}{node_name};
	
	if (not $anvil_uuid)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0139", code => 139, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	if (not $node_name)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0140", code => 140, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
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
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	### TODO: Should we abort if cman is not running on the peer but the peer is otherwise accessible? 
	###       One the one hand, it is not hosting any servers so the user's servers won't be impacted if
	###       it gets fenced. On the otherhand, the peer will get fenced after a delay... Maybe just
	###       print a warning that it will take a bit and that the peer will be fenced shortly if it's
	###       cman isn't started separately?
	# Proceed only if all of the storage components, cman and rgmanager are off.
	if (($an->data->{node}{$node_name}{daemon}{cman}{exit_code}      ne "0") or
	    ($an->data->{node}{$node_name}{daemon}{rgmanager}{exit_code} ne "0") or
	    ($an->data->{node}{$node_name}{daemon}{drbd}{exit_code}      ne "0") or
	    ($an->data->{node}{$node_name}{daemon}{clvmd}{exit_code}     ne "0") or
	    ($an->data->{node}{$node_name}{daemon}{gfs2}{exit_code}      ne "0") or
	    ($an->data->{node}{$node_name}{daemon}{libvirtd}{exit_code}  ne "0"))
	{
		$proceed = 1;
	}
	if ($proceed)
	{
		my $say_title = $an->String->get({key => "title_0052", variables => { 
				node_name => $node_name,
				anvil           => $anvil_name,
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
		my $shell_call      = $an->data->{path}{initd}."/rgmanager start; ".$an->data->{path}{echo}." rc:\$?";
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

# This migrates a server using 'anvil-migrate-server'
sub _migrate_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_migrate_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $server = $an->data->{cgi}{server};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "server", value1 => $server,
	}, file => $THIS_FILE, line => __LINE__});
	
	# This simply calls '$an->Cman->boot_server()' and processes the output.
	my $anvil_name = $an->data->{cgi}{anvil_uuid};
	my $server     = $an->data->{cgi}{server};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_name", value1 => $anvil_name,
		name2 => "server",     value2 => $server,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $server)
	{
		# Error...
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0130", code => 130, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
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
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0126", message_variables => { server => $server }, code => 126, file => "$THIS_FILE", line => __LINE__});
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
	
	
	my $output = $an->Cman->migrate_server({server => $server});
	
	foreach my $line (split/\n/, $output)
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		$line = parse_text_line($an, $line);
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
	
	return(0);
}

# Parse the cluster configuration.
sub _parse_cluster_conf
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_parse_cluster_conf" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid  = $parameter->{node} ? $parameter->{node} : "";
	my $node_key   = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $data       = $parameter->{data};
	
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
			   
			# If I need to record the host name from cluster.conf,
			# do so here.
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
			my $server_key = "vm:$server";
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
				name2 => "method",    value2 => $in_method,
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
						if (($agent eq "fence_ipmilan") || ($agent eq "fence_virsh"))
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
			### TODO: Why did I put a '.' here? typo?
			# Record the fence command.
			$fence_command =~ s/ $/. /;
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
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "server", value1 => $server,
					name2 => "host",   value2 => $host,
					name3 => "state",  value3 => $state,
				}, file => $THIS_FILE, line => __LINE__});
				if (($state eq "disabled") || ($state eq "stopped"))
				{
					# Set host to 'none'.
					$host = $an->String->get({key => "state_0002"});
				}
				if ($state eq "failed")
				{
					# Don't do anything here now, it's possible the server is still 
					# running. Set the host to 'Unknown' and let the user decide what to 
					# do. This can happen if, for example, the XML file is temporarily
					# removed or corrupted.
					$host = $an->String->get({key => "state_0128", variables => { host => $host }});
				}
				
				# If the service is disabled, it will have '()' around the host name which I 
				# need to remove.
				$host =~ s/^\((.*?)\)$/$1/g;
				
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "server",   value1 => $server,
					name2 => "host", value2 => $host,
				}, file => $THIS_FILE, line => __LINE__});
				
				$host                                 = "none" if not $host;
				$an->data->{server}{$server}{host}    = $host;
				$an->data->{server}{$server}{'state'} = $state;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "server::${server}::host",  value1 => $an->data->{server}{$server}{host},
					name2 => "server::${server}::state", value2 => $an->data->{server}{$server}{'state'},
				}, file => $THIS_FILE, line => __LINE__});
				
				# Pick out who the peer node is.
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "host",                         value1 => $host,
					name2 => "node::${node_name}::me::name", value2 => $an->data->{node}{$node_name}{me}{name},
				}, file => $THIS_FILE, line => __LINE__});
				if ($host eq $an->data->{node}{$node_name}{me}{name})
				{
					$an->data->{server}{$server}{peer} = $an->data->{node}{$node_name}{peer}{name};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "node_name",       value1 => $node_name,
						name2 => "server::${server}::peer", value2 => $an->data->{server}{$server}{peer},
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					$an->data->{server}{$server}{peer} = $an->data->{node}{$node_name}{me}{name};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "node_name",       value1 => $node_name,
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
	
	# If this is set, the cluster isn't running.
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
	$an->data->{node}{$node_name}{enable_poweroff} = 0;
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
		$exit_code = "" if not defined $exit_code;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "node_name", value1 => $node_name,
			name2 => "daemon",    value2 => $daemon,
			name3 => "exit_code", value3 => $exit_code,
		}, file => $THIS_FILE, line => __LINE__});
		if ($exit_code eq "0")
		{
			# Running
			$an->data->{node}{$node_name}{daemon}{$daemon}{status} = "<span class=\"highlight_good\">#!string!an_state_0003!#</span>";
			$an->data->{node}{$node_name}{enable_poweroff}         = 0;
		}
		$an->data->{node}{$node_name}{daemon}{$daemon}{exit_code} = defined $exit_code ? $exit_code : "";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node_name}::daemon::${daemon}::exit_code", value1 => $an->data->{node}{$node_name}{daemon}{$daemon}{exit_code},
			name2 => "node::${node_name}::daemon::${daemon}::status",    value2 => $an->data->{node}{$node_name}{daemon}{$daemon}{status},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# If cman is running, enable withdrawl. If not, enable shut down.
	my $cman_exit      = $an->data->{node}{$node_name}{daemon}{cman}{exit_code};
	my $rgmanager_exit = $an->data->{node}{$node_name}{daemon}{rgmanager}{exit_code};
	my $drbd_exit      = $an->data->{node}{$node_name}{daemon}{drbd}{exit_code};
	my $clvmd_exit     = $an->data->{node}{$node_name}{daemon}{clvmd}{exit_code};
	my $gfs2_exit      = $an->data->{node}{$node_name}{daemon}{gfs2}{exit_code};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
		name1 => "cman_exit",      value1 => $cman_exit,
		name2 => "rgmanager_exit", value2 => $rgmanager_exit,
		name3 => "drbd_exit",      value3 => $drbd_exit,
		name4 => "clvmd_exit",     value4 => $clvmd_exit,
		name5 => "gfs2_exit",      value5 => $gfs2_exit,
	}, file => $THIS_FILE, line => __LINE__});
	if ($cman_exit eq "0")
	{
		$an->data->{node}{$node_name}{enable_withdraw} = 1;
	}
	else
	{
		# If something went wrong, one of the storage resources might still be running.
		if (($rgmanager_exit eq "0") ||
		    ($drbd_exit      eq "0") ||
		    ($clvmd_exit     eq "0") ||
		    ($gfs2_exit      eq "0"))
		{
			# This can happen if the user loads the page (or it auto-loads) while the storage is 
			# coming online.
			#my $message = $an->String->get({key => "message_0044", variables => { node => $node }});
			#$an->Striker->_error({message => $message}); 
		}
		else
		{
			# Ready to power off the node, if I was actually able to connect to the node.
			if ($an->data->{node}{$node_name}{connected})
			{
				$an->data->{node}{$node_name}{enable_poweroff} = 1;
			}
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
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
						
						# This is used for locating a resource by it's minor number
						$an->data->{node}{$node_name}{drbd}{minor_number}{$minor_number}{resource} = $resource;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "node::${node_name}::drbd::minor_number::${minor_number}::resource", value1 => $an->data->{node}{$node_name}{drbd}{minor_number}{$minor_number}{resource},
						}, file => $THIS_FILE, line => __LINE__});
						
						# This is where the data itself is stored.
						$an->data->{node}{$node_name}{drbd}{resource}{$resource}{metadisk}       = $metadisk;
						$an->data->{node}{$node_name}{drbd}{resource}{$resource}{minor_number}   = $minor_number;
						$an->data->{node}{$node_name}{drbd}{resource}{$resource}{drbd_device}    = $drbd_device;
						$an->data->{node}{$node_name}{drbd}{resource}{$resource}{backing_device} = $backing_device;
						
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
	# it's all done, we have 0 cores listed.
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
			if ($line =~ /Locator: (.*)/)      { $dimm_locator     = $1; }
			if ($line =~ /Bank Locator: (.*)/) { $dimm_bank        = $1; }
			if ($line =~ /Type: (.*)/)         { $dimm_type        = $1; }
			if ($line =~ /Speed: (.*)/)        { $dimm_speed       = $1; }
			if ($line =~ /Form Factor: (.*)/)  { $dimm_form_factor = $1; }
			if ($line =~ /Size: (.*)/)
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0010", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
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
				print $an->Web->template({file => "main-page.html", template => "lv-inactive-error", replace => { replace => $message }});
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
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_parse_server_defs" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
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
			my $server_key = "vm:$this_server";
			my $lines      = @{$this_array};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "this_server", value1 => $this_server,
				name2 => "this_array",  value2 => $this_array,
				name3 => "lines",       value3 => $lines,
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{server}{$server_key}{xml} = $this_array;
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
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_parse_server_defs_in_mem" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
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
			my $server_key = "vm:$this_server";
			my $lines      = @{$this_array};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "this_server", value1 => $this_server,
				name2 => "this_array",  value2 => $this_array,
				name3 => "lines",       value3 => $lines,
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{server}{$server_key}{xml} = $this_array;
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
		
		my ($id, $say_server, $state) = split/ /, $line, 3;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "id",         value1 => $id,
			name2 => "say_server", value2 => $say_server,
			name3 => "state",      value3 => $state,
		}, file => $THIS_FILE, line => __LINE__});
		
		my $server                                                        = "vm:$say_server";
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
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
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
	
	# It's a program error to try and write the cache file when the node is down.
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
	my $anvil_uuid                 = $an->data->{sys}{anvil}{uuid};
	my $anvil_name                 = $an->data->{sys}{anvil}{name};
	my $node1_name                 = $an->data->{sys}{anvil}{node1}{name};
	my $node2_name                 = $an->data->{sys}{anvil}{node2}{name};
	   $an->data->{sys}{gfs2_down} = 0;
	if (($an->data->{node}{$node1_name}{daemon}{gfs2}{exit_code} ne "0") && ($an->data->{node}{$node2_name}{daemon}{gfs2}{exit_code} ne "0"))
	{
		$an->data->{sys}{gfs2_down} = 1;
	}
	$an->data->{sys}{clvmd_down} = 0;
	if (($an->data->{node}{$node1_name}{daemon}{clvmd}{exit_code} ne "0") && ($an->data->{node}{$node2_name}{daemon}{clvmd}{exit_code} ne "0"))
	{
		$an->data->{sys}{clvmd_down} = 1;
	}
	$an->data->{sys}{drbd_down} = 0;
	if (($an->data->{node}{$node1_name}{daemon}{drbd}{exit_code} ne "0") && ($an->data->{node}{$node2_name}{daemon}{drbd}{exit_code} ne "0"))
	{
		$an->data->{sys}{drbd_down} = 1;
	}
	$an->data->{sys}{rgmanager_down} = 0;
	if (($an->data->{node}{$node1_name}{daemon}{rgmanager}{exit_code} ne "0") && ($an->data->{node}{$node2_name}{daemon}{rgmanager}{exit_code} ne "0"))
	{
		$an->data->{sys}{rgmanager_down} = 1;
	}
	$an->data->{sys}{cman_down} = 0;
	if (($an->data->{node}{$node1_name}{daemon}{cman}{exit_code} ne "0") && ($an->data->{node}{$node2_name}{daemon}{cman}{exit_code} ne "0"))
	{
		$an->data->{sys}{cman_down} = 1;
	}
	
	# Loop through the DRBD resources on each node and see if any resources are 'SyncSource', disable
	# withdrawing that node. 
	foreach my $node_name ($node1_name, $node2_name)
	{
		foreach my $resource (sort {$a cmp $b} keys %{$an->data->{node}{$node_name}{drbd}{resource}})
		{
			my $connection_state = $an->data->{node}{$node_name}{drbd}{resource}{$resource}{connection_state};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "connection_state", value1 => $an->data->{node}{$node_name}{drbd}{resource}{$resource}{io_flags},
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

# This sorts out what needs to happen if 'task' was set.
sub _process_task
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "process_task" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::task",    value1 => $an->data->{cgi}{task}, 
		name2 => "cgi::confirm", value2 => $an->data->{cgi}{confirm}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
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
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			$an->Striker->_join_anvil();
		}
		else
		{
			$an->Striker->_confirm_join_anvil();
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
# 			$an->Striker->_poweroff_node();
		}
		else
		{
# 			$an->Striker->_confirm_poweroff_node();
		}
	}
	elsif ($an->data->{cgi}{task} eq "poweron_node")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
# 			$an->Striker->_poweron_node();
		}
		else
		{
# 			$an->Striker->_confirm_poweron_node();
		}
	}
	elsif ($an->data->{cgi}{task} eq "dual_boot")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
# 			$an->Striker->_dual_boot();
		}
		else
		{
# 			$an->Striker->_confirm_dual_boot();
		}
	}
	elsif ($an->data->{cgi}{task} eq "cold_stop")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			# The '1' cancels the APC UPS watchdog timer, if used.
# 			$an->Striker->_cold_stop_anvil($an, 1);
		}
		else
		{
# 			$an->Striker->_confirm_cold_stop_anvil();
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
			if (verify_server_config())
			{
				# We're golden
				$an->Log->entry({log_level => 2, message_key => "log_0216", file => $THIS_FILE, line => __LINE__});
# 				$an->Striker->_provision_server();
			}
			else
			{
				# Something wasn't sane.
				$an->Log->entry({log_level => 2, message_key => "log_0217", file => $THIS_FILE, line => __LINE__});
# 				$an->Striker->_confirm_provision_server();
			}
		}
		else
		{
# 			$an->Striker->_confirm_provision_server();
		}
	}
	elsif ($an->data->{cgi}{task} eq "add_server")
	{
		# This is called after provisioning a server usually, so no need to confirm
# 		$an->Striker->_add_server_to_cluster($an, 0);
	}
	elsif ($an->data->{cgi}{task} eq "manage_server")
	{
# 		$an->Striker->_manage_server();
	}
	elsif ($an->data->{cgi}{task} eq "display_health")
	{
		print $an->Web->template({file => "common.html", template => "scanning-message", replace => {
			anvil_message	=>	$an->String->get({key => "message_0272", variables => { anvil => $anvil_name }}),
		}});
# 		$an->Striker->_get_storage_data($an, $an->data->{cgi}{node});
		
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
# 					lsi_control_disk_id_led($an, "start");
# 					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "stop_id_disk")
				{
# 					lsi_control_disk_id_led($an, "stop");
# 					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "make_disk_good")
				{
# 					lsi_control_make_disk_good();
# 					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "add_disk_to_array")
				{
# 					lsi_control_add_disk_to_array();
# 					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "put_disk_online")
				{
# 					lsi_control_put_disk_online();
# 					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "put_disk_offline")
				{
# 					lsi_control_put_disk_offline();
# 					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "mark_disk_missing")
				{
# 					lsi_control_mark_disk_missing();
# 					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "spin_disk_down")
				{
# 					lsi_control_spin_disk_down();
# 					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "spin_disk_up")
				{
# 					lsi_control_spin_disk_up();
# 					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "make_disk_hot_spare")
				{
# 					lsi_control_make_disk_hot_spare();
# 					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "unmake_disk_as_hot_spare")
				{
# 					lsi_control_unmake_disk_as_hot_spare();
# 					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "clear_foreign_state")
				{
# 					lsi_control_clear_foreign_state();
# 					get_storage_data($an, $an->data->{cgi}{node});
				}
				### Prepare Unconfigured drives for removal
				# MegaCli64 AdpSetProp AlarmDsbl aN|a0,1,2|aALL 
			}
			if ($display_details)
			{
# 				display_node_health();
			}
		}
	}
	else
	{
		# Dirty debugging...
		print "<pre>\n";
		foreach my $var (sort {$a cmp $b} keys %{$an->data->{cgi}})
		{
			print "var: [$var] -> [$an->data->{cgi}{$var}]\n" if $an->data->{cgi}{$var};
		}
		print "</pre>";
	}
	
	return(0);
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
	
	my $say_server = $server;
	if ($server =~ /vm:(.*)/)
	{
		$say_server = $1;
	}
	else
	{
		$server = "vm:$server";
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "server",     value1 => $server,
		name2 => "say_server", value2 => $say_server,
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->data->{server}{$server}{definition_file} = "" if not defined $an->data->{server}{$server}{definition_file};
	$an->data->{server}{$server}{xml}             = "" if not defined $an->data->{server}{$server}{xml};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name2 => "server::${server}::definition_file", value1 => $an->data->{server}{$server}{definition_file},
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
				server  => $say_server, 
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

# This boots a server on a target node.
sub _start_server
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_start_server" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# This simply calls '$an->Cman->boot_server()' and processes the output.
	my $anvil_name = $an->data->{cgi}{anvil_uuid};
	my $server     = $an->data->{cgi}{server};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_name", value1 => $anvil_name,
		name2 => "server",     value2 => $server,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $server)
	{
		# Error...
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0125", code => 125, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	my $say_title = $an->String->get({key => "title_0046", variables => { server =>	$server }});
	print $an->Web->template({file => "server.html", template => "start-server-header", replace => { title => $say_title }});
	
	# Which node to use?
	my ($target, $port, $password, $node_name) = $an->Cman->find_node_in_cluster();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "target", value1 => $target,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $target)
	{
		# Couldn't log into either node.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0126", message_variables => { server => $server }, code => 126, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	# Call 'anvil-boot-server'
	my $shell_call = $an->data->{path}{'anvil-boot-server'}." --server $server";
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
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0127", code => 127, file => "$THIS_FILE", line => __LINE__});
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
	
	# Which node to use?
	my ($target, $port, $password, $node_name) = $an->Cman->find_node_in_cluster();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "target", value1 => $target,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $target)
	{
		# Couldn't log into either node.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0128", message_variables => { server => $server }, code => 128, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	my $say_title = $an->String->get({key => "title_0051", variables => { server =>	$server }});
	print $an->Web->template({file => "server.html", template => "stop-server-header", replace => { title => $say_title }});
	
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
	print $an->Web->template({file => "server.html", template => "stop-server-footer"});
	
	return(0);
}

# This does a final check of the target node then withdraws it from the cluster.
sub _withdraw_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_withdraw_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $node_name  = $an->data->{cgi}{node_name};
	
	if (not $anvil_uuid)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0136", code => 136, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	if (not $node_name)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0137", code => 137, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	
	my $node_key = $an->data->{sys}{node_name}{$node_name}{node_key};
	if (not $node_key)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0138", message_variables => { node_name => $node_name }, code => 138, file => "$THIS_FILE", line => __LINE__});
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
		
		# Stop rgmanager and then check it's status.
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
			
			if ($line =~ /failed/i)
			{
				$rgmanager_stop = 0;
			}
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
