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
# load_anvil
# mark_node_as_clean_off
# mark_node_as_clean_on
# scan_anvil
# scan_node
# scan_servers
### NOTE: All of these private methods are ports of functions from the old Striker.pm. None will be developed
###       further and all will be phased out over time. Do not use any of these in new dev work.
# _check_lv
# _check_node_daemons
# _check_node_readiness
# _error
# _find_preferred_host
# _gather_node_details
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
# _parse_virsh
# _parse_vm_defs
# _parse_vm_defs_in_mem
# _post_node_calculations
# _post_scan_calculations
# _read_vm_definition

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
	
	
	
	return(0);
}

# This uses the 'cgi::anvil_uuid' to load the anvil data into the active system variables.
sub load_anvil
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
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
		# Valid UUID, but it doesn't match a known Anvil!.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0104", message_variables => { uuid => $anvil_uuid }, code => 104, file => "$THIS_FILE", line => __LINE__});
		return(1);
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
		name1 => "sys::anvil::smtp::password", value1 => $an->data->{sys}{anvil}{smtp}{password}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	foreach my $node_key ("node1", "node2")
	{
		$an->data->{sys}{anvil}{$node_key}{uuid}           = $an->data->{anvils}{$anvil_uuid}{$node_key}{uuid};
		$an->data->{sys}{anvil}{$node_key}{name}           = $an->data->{anvils}{$anvil_uuid}{$node_key}{name};
		$an->data->{sys}{anvil}{$node_key}{remote_ip}      = $an->data->{anvils}{$anvil_uuid}{$node_key}{remote_ip};
		$an->data->{sys}{anvil}{$node_key}{remote_port}    = $an->data->{anvils}{$anvil_uuid}{$node_key}{remote_port};
		$an->data->{sys}{anvil}{$node_key}{note}           = $an->data->{anvils}{$anvil_uuid}{$node_key}{note};
		$an->data->{sys}{anvil}{$node_key}{bcn_ip}         = $an->data->{anvils}{$anvil_uuid}{$node_key}{bcn_ip};
		$an->data->{sys}{anvil}{$node_key}{sn_ip}          = $an->data->{anvils}{$anvil_uuid}{$node_key}{sn_ip};
		$an->data->{sys}{anvil}{$node_key}{ifn_ip}         = $an->data->{anvils}{$anvil_uuid}{$node_key}{ifn_ip};
		$an->data->{sys}{anvil}{$node_key}{type}           = $an->data->{anvils}{$anvil_uuid}{$node_key}{type};
		$an->data->{sys}{anvil}{$node_key}{health}         = $an->data->{anvils}{$anvil_uuid}{$node_key}{health};
		$an->data->{sys}{anvil}{$node_key}{emergency_stop} = $an->data->{anvils}{$anvil_uuid}{$node_key}{emergency_stop};
		$an->data->{sys}{anvil}{$node_key}{stop_reason}    = $an->data->{anvils}{$anvil_uuid}{$node_key}{stop_reason};
		$an->data->{sys}{anvil}{$node_key}{use_ip}         = $an->data->{anvils}{$anvil_uuid}{$node_key}{use_ip};
		$an->data->{sys}{anvil}{$node_key}{use_port}       = $an->data->{anvils}{$anvil_uuid}{$node_key}{use_port};
		$an->data->{sys}{anvil}{$node_key}{online}         = $an->data->{anvils}{$anvil_uuid}{$node_key}{online};
		$an->data->{sys}{anvil}{$node_key}{power}          = $an->data->{anvils}{$anvil_uuid}{$node_key}{power};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0016", message_variables => {
			name1  => "sys::anvil::${node_key}::uuid",           value1  => $an->data->{sys}{anvil}{$node_key}{uuid}, 
			name2  => "sys::anvil::${node_key}::name",           value2  => $an->data->{sys}{anvil}{$node_key}{name}, 
			name3  => "sys::anvil::${node_key}::remote_ip",      value3  => $an->data->{sys}{anvil}{$node_key}{remote_ip}, 
			name4  => "sys::anvil::${node_key}::remote_port",    value4  => $an->data->{sys}{anvil}{$node_key}{remote_port}, 
			name5  => "sys::anvil::${node_key}::note",           value5  => $an->data->{sys}{anvil}{$node_key}{note}, 
			name6  => "sys::anvil::${node_key}::bcn_ip",         value6  => $an->data->{sys}{anvil}{$node_key}{bcn_ip}, 
			name7  => "sys::anvil::${node_key}::sn_ip",          value7  => $an->data->{sys}{anvil}{$node_key}{sn_ip}, 
			name8  => "sys::anvil::${node_key}::ifn_ip",         value8  => $an->data->{sys}{anvil}{$node_key}{ifn_ip}, 
			name9  => "sys::anvil::${node_key}::type",           value9  => $an->data->{sys}{anvil}{$node_key}{type}, 
			name10 => "sys::anvil::${node_key}::health",         value10 => $an->data->{sys}{anvil}{$node_key}{health}, 
			name11 => "sys::anvil::${node_key}::emergency_stop", value11 => $an->data->{sys}{anvil}{$node_key}{emergency_stop}, 
			name12 => "sys::anvil::${node_key}::stop_reason",    value12 => $an->data->{sys}{anvil}{$node_key}{stop_reason}, 
			name13 => "sys::anvil::${node_key}::use_ip",         value13 => $an->data->{sys}{anvil}{$node_key}{use_ip}, 
			name14 => "sys::anvil::${node_key}::use_port",       value14 => $an->data->{sys}{anvil}{$node_key}{use_port}, 
			name15 => "sys::anvil::${node_key}::online",         value15 => $an->data->{sys}{anvil}{$node_key}{online}, 
			name16 => "sys::anvil::${node_key}::power",          value16 => $an->data->{sys}{anvil}{$node_key}{power}, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Password
		$an->data->{sys}{anvil}{$node_key}{password} = $an->data->{anvils}{$anvil_uuid}{$node_key}{password};
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::anvil::${node_key}::password", value1 => $an->data->{sys}{anvil}{$node_key}{password}, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Make the node UUID easy to get from the node name.
		my $node_uuid = $an->data->{sys}{anvil}{$node_key}{uuid};
		my $node_name = $an->data->{sys}{anvil}{$node_key}{name};
		$an->data->{sys}{name_to_uuid}{$node_name} = $node_uuid;
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
	
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
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
	
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
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
	
	# Show the 'scanning in progress' table.
	print $an->Web->template({file => "common.html", template => "scanning-message", replace => {
		anvil_message	=>	$an->String->get({key => "message_0272", variables => { anvil => $an->data->{sys}{anvil}{name} }}),
	}});
	
	# Start your engines!
	$an->Striker->scan_node({uuid => $an->data->{sys}{anvil}{node1}{uuid}});
	$an->Striker->scan_node({uuid => $an->data->{sys}{anvil}{node2}{uuid}});
	
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
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
	$an->data->{up_nodes} = [];
	if ($an->data->{sys}{anvil}{$node_key}{online})
	{
		$an->data->{sys}{online_nodes}    = 1;
		$an->data->{node}{$node_name}{up} = 1;
		push @{$an->data->{up_nodes}}, $node_name;
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
	my $anvil                         = $an->data->{sys}{anvil}{name};
	   $an->data->{sys}{up_nodes}     = @{$an->data->{up_nodes}};
	   $an->data->{sys}{online_nodes} = @{$an->data->{online_nodes}};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "anvil",             value1 => $anvil,
		name2 => "sys::up_nodes",     value2 => $an->data->{sys}{up_nodes},
		name3 => "sys::online_nodes", value3 => $an->data->{sys}{online_nodes},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{up_nodes} < 1)
	{
		# Neither node is up. If I can power them on, then I will show the node section to enable 
		# power up.
		if (not $an->data->{sys}{online_nodes})
		{
			if ($an->data->{clusters}{$anvil}{cache_exists})
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
	
	# Make it a little easier to print the name of each node
	my $node1_name = $an->data->{sys}{anvil}{node1}{name};
	my $node1_uuid = $an->data->{sys}{name_to_uuid}{$node1_name};
	my $node2_name = $an->data->{sys}{anvil}{node2}{name};
	my $node2_uuid = $an->data->{sys}{name_to_uuid}{$node2_name};
	
	$an->data->{node}{$node1_name}{info}{host_name}       =  $node1_name;
	$an->data->{node}{$node1_name}{info}{short_host_name} =  $node1_name;
	$an->data->{node}{$node1_name}{info}{short_host_name} =~ s/\..*$//;
	$an->data->{node}{$node2_name}{info}{host_name}       =  $node2_name;
	$an->data->{node}{$node2_name}{info}{short_host_name} =  $node2_name;
	$an->data->{node}{$node2_name}{info}{short_host_name} =~ s/\..*$//;
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
		name1 => "node1_name",                                 value1 => $node1_name,
		name2 => "node::${node1_name}::info::short_host_name", value2 => $an->data->{node}{$node1_name}{info}{short_host_name},
		name3 => "node::${node1_name}::info::host_name",       value3 => $an->data->{node}{$node1_name}{info}{host_name},
		name4 => "node2_name",                                 value4 => $node2_name,
		name5 => "node::${node2_name}::info::short_host_name", value5 => $an->data->{node}{$node2_name}{info}{short_host_name},
		name6 => "node::${node2_name}::info::host_name",       value6 => $an->data->{node}{$node2_name}{info}{host_name},
	}, file => $THIS_FILE, line => __LINE__});
	
	my $short_node1 = $an->data->{node}{$node1_name}{info}{short_host_name};
	my $short_node2 = $an->data->{node}{$node2_name}{info}{short_host_name};
	my $long_node1  = $an->data->{node}{$node1_name}{info}{host_name};
	my $long_node2  = $an->data->{node}{$node2_name}{info}{host_name};
	my $say_node1   = "<span class=\"fixed_width\">".$an->data->{node}{$node1_name}{info}{short_host_name}."</span>";
	my $say_node2   = "<span class=\"fixed_width\">".$an->data->{node}{$node2_name}{info}{short_host_name}."</span>";
	foreach my $vm (sort {$a cmp $b} keys %{$an->data->{vm}})
	{
		my $say_vm;
		if ($vm =~ /^vm:(.*)/)
		{
			$say_vm = $1;
		}
		else
		{
			my $say_message = $an->String->get({key => "message_0467", variables => { server => $vm }});
			$an->Striker->_error({message => $say_message});
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "vm",     value1 => $vm,
			name2 => "say_vm", value2 => $say_vm,
		}, file => $THIS_FILE, line => __LINE__});
		
		# This will control the buttons.
		$an->data->{vm}{$vm}{can_start}        = 0;
		$an->data->{vm}{$vm}{can_stop}         = 0;
		$an->data->{vm}{$vm}{can_migrate}      = 0;
		$an->data->{vm}{$vm}{current_host}     = 0;
		$an->data->{vm}{$vm}{migration_target} = "";
		
		# Find out who, if anyone, is running this VM and who *can* run it. 
		# 2 == Running
		# 1 == Can run 
		# 0 == Can't run
		$an->data->{vm}{$vm}{say_node1}   = $an->data->{node}{$node1_name}{daemon}{cman}{exit_code} eq "0" ? "<span class=\"highlight_warning\">#!string!state_0006!#</span>" : "<span class=\"code\">--</span>";
		$an->data->{vm}{$vm}{node1_ready} = 0;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "vm::${vm}::say_node1",                    value1 => $an->data->{vm}{$vm}{say_node1},
			name2 => "node::${node1_name}::daemon::cman::exit_code", value2 => $an->data->{node}{$node1_name}{daemon}{cman}{exit_code},
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->data->{vm}{$vm}{say_node2}   = $an->data->{node}{$node2_name}{daemon}{cman}{exit_code} eq "0" ? "<span class=\"highlight_warning\">#!string!state_0006!#</span>" : "<span class=\"code\">--</span>";
		$an->data->{vm}{$vm}{node2_ready} = 0;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "vm::${vm}::say_node2",                    value1 => $an->data->{vm}{$vm}{say_node2},
			name2 => "node::${node2_name}::daemon::cman::exit_code", value2 => $an->data->{node}{$node2_name}{daemon}{cman}{exit_code},
		}, file => $THIS_FILE, line => __LINE__});
		
		# If a VM's XML definition file is found but there is no host, the user probably forgot to define it.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "vm::${vm}::host", value1 => $an->data->{vm}{$vm}{host},
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $an->data->{vm}{$vm}{host}) && (not $an->data->{sys}{ignore_missing_vm}))
		{
			# Pull the host node and current state out of the hash.
			my $host_node = "";
			my $vm_state  = "";
			foreach my $node_name (sort {$a cmp $b} keys %{$an->data->{vm}{$vm}{node}})
			{
				$host_node = $node_name;
				foreach my $key (sort {$a cmp $b} keys %{$an->data->{vm}{$vm}{node}{$node_name}{virsh}})
				{
					if ($key eq "state") 
					{
						$vm_state = $an->data->{vm}{$vm}{node}{$host_node}{virsh}{'state'};
					}
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "vm::${vm}::node::${node_name}::virsh::${key}", value1 => $an->data->{vm}{$vm}{node}{$node_name}{virsh}{$key},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			$an->data->{vm}{$vm}{say_node1} = "--";
			$an->data->{vm}{$vm}{say_node2} = "--";
			my $say_error = $an->String->get({key => "message_0271", variables => { 
					server	=>	$say_vm,
					url	=>	"?cluster=".$an->data->{sys}{anvil}{name}."&task=add_vm&name=$say_vm&node=$host_node&state=$vm_state",
				}});
			$an->Striker->_error({message => $say_error, fatal => 0});
			next;
		}
		
		$an->data->{vm}{$vm}{host} = "" if not defined $an->data->{vm}{$vm}{host};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "vm::${vm}::host", value1 => $an->data->{vm}{$vm}{host},
			name2 => "short_node1",     value2 => $short_node1,
			name3 => "short_node2",     value3 => $short_node2,
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{vm}{$vm}{host} =~ /$short_node1/)
		{
			# Even though I know the host is ready, this function loads some data, like LV 
			# details, which I will need later.
			$an->Striker->_check_node_readiness({server => $vm, node => $node1_uuid});
			$an->data->{vm}{$vm}{can_start}     = 0;
			$an->data->{vm}{$vm}{can_stop}      = 1;
			$an->data->{vm}{$vm}{current_host}  = $node1_name;
			$an->data->{vm}{$vm}{node1_ready}   = 2;
			($an->data->{vm}{$vm}{node2_ready}) = $an->Striker->_check_node_readiness({server => $vm, node => $node2_uuid});
			if ($an->data->{vm}{$vm}{node2_ready})
			{
				$an->data->{vm}{$vm}{migration_target} = $long_node2;
				$an->data->{vm}{$vm}{can_migrate}      = 1;
			}
			
			# Disable cluster withdrawl of this node.
			$an->data->{node}{$node1_name}{enable_withdraw} = 0;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
				name1 => "vm",               value1 => $vm,
				name2 => "node1_name",            value2 => $node1_name,
				name3 => "node2 ready",      value3 => $an->data->{vm}{$vm}{node2_ready},
				name4 => "can migrate",      value4 => $an->data->{vm}{$vm}{can_migrate},
				name5 => "migration target", value5 => $an->data->{vm}{$vm}{migration_target},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($an->data->{vm}{$vm}{host} =~ /$short_node2/)
		{
			# Even though I know the host is ready, this function loads some data, like LV 
			# details, which I will need later.
			$an->Striker->_check_node_readiness({server => $vm, node => $node2_uuid});
			$an->data->{vm}{$vm}{can_start}     = 0;
			$an->data->{vm}{$vm}{can_stop}      = 1;
			$an->data->{vm}{$vm}{current_host}  = $node2_name;
			($an->data->{vm}{$vm}{node1_ready}) = $an->Striker->_check_node_readiness({server => $vm, node => $node1_uuid});
			$an->data->{vm}{$vm}{node2_ready}   = 2;
			if ($an->data->{vm}{$vm}{node1_ready})
			{
				$an->data->{vm}{$vm}{migration_target} = $long_node1;
				$an->data->{vm}{$vm}{can_migrate}      = 1;
			}
			
			# Disable withdrawl of this node.
			$an->data->{node}{$node2_name}{enable_withdraw} = 0;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
				name1 => "vm",               value1 => $vm,
				name2 => "node1_name",            value2 => $node1_name,
				name3 => "node2 ready",      value3 => $an->data->{vm}{$vm}{node2_ready},
				name4 => "can migrate",      value4 => $an->data->{vm}{$vm}{can_migrate},
				name5 => "migration target", value5 => $an->data->{vm}{$vm}{migration_target},
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			$an->data->{vm}{$vm}{can_stop}      = 0;
			($an->data->{vm}{$vm}{node1_ready}) = $an->Striker->_check_node_readiness({server => $vm, node => $node1_uuid});
			($an->data->{vm}{$vm}{node2_ready}) = $an->Striker->_check_node_readiness({server => $vm, node => $node2_uuid});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "vm",          value1 => $vm,
				name2 => "node1_ready", value2 => $an->data->{vm}{$vm}{node1_ready},
				name3 => "node2_ready", value3 => $an->data->{vm}{$vm}{node2_ready},
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "vm::${vm}::current_host", value1 => $an->data->{vm}{$vm}{current_host},
		}, file => $THIS_FILE, line => __LINE__});
		$an->data->{vm}{$vm}{boot_target} = "";
		if ($an->data->{vm}{$vm}{current_host})
		{
			# Get the current host's details
			my $this_host     = $an->data->{vm}{$vm}{current_host};
			my $target_uuid   = $an->data->{sys}{name_to_uuid}{$this_host};
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
			
			# This is a bit expensive, but read the VM's running definition.
			my $say_vm        =  $vm;
			   $say_vm        =~ s/^vm://;
			my $shell_call    =  $an->data->{path}{virsh}." dumpxml $say_vm";
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
				
				push @{$an->data->{vm}{$vm}{xml}}, $line;
			}
		}
		else
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "vm::${vm}::node1_ready", value1 => $an->data->{vm}{$vm}{node1_ready},
				name2 => "vm::${vm}::node2_ready", value2 => $an->data->{vm}{$vm}{node2_ready},
			}, file => $THIS_FILE, line => __LINE__});
			if (($an->data->{vm}{$vm}{node1_ready}) && ($an->data->{vm}{$vm}{node2_ready}))
			{
				# I can boot on either node, so choose the first one in the VM's failover 
				# domain.
				$an->data->{vm}{$vm}{boot_target} = $an->Striker->_find_preferred_host({server => $vm});
				$an->data->{vm}{$vm}{can_start}   = 1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "vm::${vm}::boot_target", value1 => $an->data->{vm}{$vm}{boot_target},
					name2 => "vm::${vm}::can_start",   value2 => $an->data->{vm}{$vm}{can_start},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($an->data->{vm}{$vm}{node1_ready})
			{
				$an->data->{vm}{$vm}{boot_target} = $node1_name;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "vm::${vm}::boot_target", value1 => $an->data->{vm}{$vm}{boot_target},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($an->data->{vm}{$vm}{node2_ready})
			{
				$an->data->{vm}{$vm}{boot_target} = $node2_name;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "vm::${vm}::boot_target", value1 => $an->data->{vm}{$vm}{boot_target},
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				$an->data->{vm}{$vm}{can_start} = 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "vm::${vm}::can_start", value1 => $an->data->{vm}{$vm}{can_start},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return (0);
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
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $vm        = $parameter->{vm};
	my $lv        = $parameter->{logical_volume};
	
	# If this node is down, just return.
	if ($an->data->{node}{$node_name}{daemon}{clvmd}{exit_code} ne "0")
	{
		# Node is down, skip LV check.
		$an->Log->entry({log_level => 3, message_key => "log_0258", message_variables => {
			node           => $node_name, 
			logical_volume => $lv,
			server         => $vm, 
		}, file => $THIS_FILE, line => __LINE__});
		return(0);
	}
	
	$an->data->{vm}{$vm}{node}{$node_name}{lv}{$lv}{active} = $an->data->{node}{$node_name}{lvm}{lv}{$lv}{active};
	$an->data->{vm}{$vm}{node}{$node_name}{lv}{$lv}{size}   = $an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node_name}{lvm}{lv}{$lv}{total_size} });
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "node::${node_name}::lvm::lv::${lv}::active",     value1 => $an->data->{node}{$node_name}{lvm}{lv}{$lv}{active},
		name2 => "node::${node_name}::lvm::lv::${lv}::on_devices", value2 => $an->data->{node}{$node_name}{lvm}{lv}{$lv}{on_devices},
		name3 => "vm::${vm}::node::${node_name}::lv::${lv}::size", value3 => $an->data->{vm}{$vm}{node}{$node_name}{lv}{$lv}{size},
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
			name1 => "vm",        value1 => $vm,
			name2 => "node_name", value2 => $node_name,
			name3 => "lv",        value3 => $lv,
			name4 => "on_res",    value4 => $on_res,
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->data->{vm}{$vm}{node}{$node_name}{lv}{$lv}{drbd}{$on_res}{connection_state} = $an->data->{drbd}{$on_res}{node}{$node_name}{connection_state};
		$an->data->{vm}{$vm}{node}{$node_name}{lv}{$lv}{drbd}{$on_res}{role}             = $an->data->{drbd}{$on_res}{node}{$node_name}{role};
		$an->data->{vm}{$vm}{node}{$node_name}{lv}{$lv}{drbd}{$on_res}{disk_state}       = $an->data->{drbd}{$on_res}{node}{$node_name}{disk_state};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "vm::${vm}::node::${node_name}::lv::${lv}::drbd::${on_res}::connection_state", value1 => $an->data->{vm}{$vm}{node}{$node_name}{lv}{$lv}{drbd}{$on_res}{connection_state},
			name2 => "vm::${vm}::node::${node_name}::lv::${lv}::drbd::${on_res}::role",             value2 => $an->data->{vm}{$vm}{node}{$node_name}{lv}{$lv}{drbd}{$on_res}{role},
			name3 => "vm::${vm}::node::${node_name}::lv::${lv}::drbd::${on_res}::disk_state",       value3 => $an->data->{vm}{$vm}{node}{$node_name}{lv}{$lv}{drbd}{$on_res}{disk_state},
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
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $data      = $parameter->{data};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
		name1 => "node_uuid", value1 => $node_uuid,
		name2 => "node_key",  value2 => $node_key,
		name3 => "anvil",     value3 => $anvil,
		name4 => "node_name", value4 => $node_name,
		name5 => "target",    value5 => $target,
		name6 => "port",      value6 => $port,
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
	if (($an->data->{node}{$node_name}{daemon}{cman}{exit_code}  ne "0") or
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

# This checks a node to see if it's ready to run a given VM.
sub _check_node_readiness
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $vm        = $parameter->{server};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
		name1 => "node_uuid", value1 => $node_uuid,
		name2 => "node_key",  value2 => $node_key,
		name3 => "anvil",     value3 => $anvil,
		name4 => "node_name", value4 => $node_name,
		name5 => "target",    value5 => $target,
		name6 => "port",      value6 => $port,
		name7 => "vm",        value7 => $vm,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $node_name)
	{
		my $say_message = $an->String->get({key => "message_0468", variables => { server => $vm }});
		$an->Striker->_error({message => $say_message});
	}
	
	# This will get negated if something isn't ready.
	my $ready = $an->Striker->_check_node_daemons({node => $node_uuid});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "vm",        value1 => $vm,
		name2 => "node_name", value2 => $node_name,
		name3 => "ready",     value3 => $ready,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Make sure the storage is ready.
	if ($ready)
	{
		# Still alive, find out what storage backs this VM and ensure that the LV is 'active' and 
		# that the DRBD resource(s) they sit on are Primary and UpToDate.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "node_name", value1 => $node_name,
			name2 => "vm",        value2 => $vm,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Striker->_read_vm_definition({node => $node_uuid, server => $vm});
		
		foreach my $lv (sort {$a cmp $b} keys %{$an->data->{vm}{$vm}{node}{$node_name}{lv}})
		{
			# Make sure the LV is active.
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "vm::${vm}::node::${node_name}::lv::${lv}::active", value1 => $an->data->{vm}{$vm}{node}{$node_name}{lv}{$lv}{active},
			}, file => $THIS_FILE, line => __LINE__});
			if ($an->data->{vm}{$vm}{node}{$node_name}{lv}{$lv}{active})
			{
				# It's active, so now check the backing storage.
				foreach my $resource (sort {$a cmp $b} keys %{$an->data->{vm}{$vm}{node}{$node_name}{lv}{$lv}{drbd}})
				{
					# For easier reading...
					my $connection_state = $an->data->{vm}{$vm}{node}{$node_name}{lv}{$lv}{drbd}{$resource}{connection_state};
					my $role             = $an->data->{vm}{$vm}{node}{$node_name}{lv}{$lv}{drbd}{$resource}{role};
					my $disk_state       = $an->data->{vm}{$vm}{node}{$node_name}{lv}{$lv}{drbd}{$resource}{disk_state};
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
					name1 => "vm",        value1 => $vm,
					name2 => "node_name", value2 => $node_name,
					name3 => "ready",     value3 => $ready,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "vm",        value1 => $vm,
		name2 => "node_name", value2 => $node_name,
		name3 => "ready",     value3 => $ready,
	}, file => $THIS_FILE, line => __LINE__});
	
	return ($ready);
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

### WARNING: This is legacy and should not be used anymore.
# Footer that closes out all pages.
sub _footer
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	return(0) if $an->data->{sys}{footer_printed}; 
	
	print $an->Web->template({file => "common.html", template => "footer"});
	$an->data->{sys}{footer_printed} = 1;
	
	return (0);
}

# This looks through the failover domain for a VM and returns the prefered host.
sub _find_preferred_host
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	my $vm        = $parameter->{server};
	
	my $prefered_host   = "";
	my $failover_domain = $an->data->{vm}{$vm}{failover_domain};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "vm",              value1 => $vm,
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
		name1 => "vm",            value1 => $vm,
		name2 => "prefered_host", value2 => $prefered_host,
	}, file => $THIS_FILE, line => __LINE__});
	return ($prefered_host);
}

### NOTE: This is ugly, but it's basically a port of the old function so ya, whatever.
# This does the actual calls out to get the data and parse the returned data.
sub _gather_node_details
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "node_uuid", value1 => $node_uuid,
		name2 => "node_key",  value2 => $node_key,
		name3 => "anvil",     value3 => $anvil,
		name4 => "node_name", value4 => $node_name,
		name5 => "target",    value5 => $target,
		name6 => "port",      value6 => $port,
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
	
	# VM definitions - from file
	$shell_call = $an->data->{path}{cat}." ".$an->data->{path}{definitions}."/*";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, my $vm_defs) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	
	# VM definitions - in memory
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
	($error, $ssh_fh, my $vm_defs_in_mem) = $an->Remote->remote_call({
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
	
	$an->Striker->_parse_anvil_safe_start({node => $node_uuid, data => $anvil_safe_start});
	$an->Striker->_parse_clustat         ({node => $node_uuid, data => $clustat});
	$an->Striker->_parse_cluster_conf    ({node => $node_uuid, data => $cluster_conf});
	$an->Striker->_parse_daemons         ({node => $node_uuid, data => $daemons});
	$an->Striker->_parse_drbdadm_dumpxml ({node => $node_uuid, data => $parse_drbdadm_dumpxml});
	$an->Striker->_parse_dmidecode       ({node => $node_uuid, data => $dmidecode});
	$an->Striker->_parse_gfs2            ({node => $node_uuid, data => $gfs2});
	$an->Striker->_parse_hosts           ({node => $node_uuid, data => $hosts});
	$an->Striker->_parse_lvm_data        ({node => $node_uuid, data => $lvm_data});
	$an->Striker->_parse_lvm_scan        ({node => $node_uuid, data => $lvm_scan});
	$an->Striker->_parse_meminfo         ({node => $node_uuid, data => $meminfo});
	$an->Striker->_parse_proc_drbd       ({node => $node_uuid, data => $proc_drbd});
	$an->Striker->_parse_virsh           ({node => $node_uuid, data => $virsh});
	$an->Striker->_parse_vm_defs         ({node => $node_uuid, data => $vm_defs});
	$an->Striker->_parse_vm_defs_in_mem  ({node => $node_uuid, data => $vm_defs_in_mem});	# Always parse this after 'parse_vm_defs()' so that we overwrite it.

	# Some stuff, like setting the system memory, needs some post-scan math.
	$an->Striker->_post_node_calculations({node => $node_uuid});
	
	return (0);
}

# Parse the 'anvil-safe-start' status.
sub _parse_anvil_safe_start
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $data      = $parameter->{data};
	
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
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $data      = $parameter->{data};
	
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
		
		# Find VMs.
		if ($line =~ /<vm.*?name="(.*?)"/)
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "node_name", value1 => $node_name,
				name2 => "line",      value2 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			my $vm         = $1;
			my $vm_key     = "vm:$vm";
			my $definition = ($line =~ /path="(.*?)"/)[0].$vm.".xml";
			my $domain     = ($line =~ /domain="(.*?)"/)[0];
			# I need to set the host to 'none' to avoid triggering the error caused by seeing and
			# foo.xml VM definition outside of here.
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "vm_key", value1 => $vm_key,
				name2 => "definition",    value2 => $definition,
				name3 => "domain", value3 => $domain,
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{vm}{$vm_key}{definition_file} = $definition;
			$an->data->{vm}{$vm_key}{failover_domain} = $domain;
			$an->data->{vm}{$vm_key}{host}            = "none" if not $an->data->{vm}{$vm_key}{host};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
				name1 => "node_name",  value1 => $node_name,
				name2 => "vm_key",     value2 => $vm_key,
				name3 => "definition", value3 => $an->data->{vm}{$vm_key}{definition_file},
				name4 => "host",       value4 => $an->data->{vm}{$vm_key}{host},
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node_name}::info::fence_methods", value1 => $an->data->{node}{$node_name}{info}{fence_methods},
		name2 => "node::${peer}::info::fence_methods",      value2 => $an->data->{node}{$peer}{info}{fence_methods},
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: Make sure this works
	if ($an->data->{sys}{name_to_uuid}{$node_name})
	{
		$an->ScanCore->insert_or_update_nodes_cache({
			node_cache_host_uuid	=>	$an->data->{sys}{host_uuid},
			node_cache_node_uuid	=>	$an->data->{sys}{name_to_uuid}{$node_name}, 
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
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $data      = $parameter->{data};
	
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
				my ($vm, $host, $state) = split/ /, $line, 3;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "vm",    value1 => $vm,
					name2 => "host",  value2 => $host,
					name3 => "state", value3 => $state,
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
					name1 => "vm",   value1 => $vm,
					name2 => "host", value2 => $host,
				}, file => $THIS_FILE, line => __LINE__});
				
				$host                         = "none" if not $host;
				$an->data->{vm}{$vm}{host}    = $host;
				$an->data->{vm}{$vm}{'state'} = $state;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "vm::${vm}::host",  value1 => $an->data->{vm}{$vm}{host},
					name2 => "vm::${vm}::state", value2 => $an->data->{vm}{$vm}{'state'},
				}, file => $THIS_FILE, line => __LINE__});
				
				# Pick out who the peer node is.
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "host",                         value1 => $host,
					name2 => "node::${node_name}::me::name", value2 => $an->data->{node}{$node_name}{me}{name},
				}, file => $THIS_FILE, line => __LINE__});
				if ($host eq $an->data->{node}{$node_name}{me}{name})
				{
					$an->data->{vm}{$vm}{peer} = $an->data->{node}{$node_name}{peer}{name};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "node_name",       value1 => $node_name,
						name2 => "vm::${vm}::peer", value2 => $an->data->{vm}{$vm}{peer},
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					$an->data->{vm}{$vm}{peer} = $an->data->{node}{$node_name}{me}{name};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "node_name",       value1 => $node_name,
						name2 => "vm::${vm}::peer", value2 => $an->data->{vm}{$vm}{peer},
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
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $data      = $parameter->{data};
	
	# If all daemons are down, record here that I can shut down this VM. If any are up, enable withdrawl.
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
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $data      = $parameter->{data};
	
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
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $data      = $parameter->{data};
	
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
	# In some cases, like in VMs, the CPU core count is not provided. So this keeps a running tally of 
	# how many times we've gone in and out of 'in_cpu' and will be used as the core count if, when it's
	# all done, we have 0 cores listed.
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
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $data      = $parameter->{data};
	
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
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $data      = $parameter->{data};
	
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
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $data      = $parameter->{data};
	
	my $in_pvs = 0;
	my $in_vgs = 0;
	my $in_lvs = 0;
	foreach my $line (@{$data})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "in_pvs", value1 => $in_pvs,
			name2 => "in_vgs", value2 => $in_vgs,
			name3 => "in_lvs", value3 => $in_lvs,
			name4 => "line",   value4 => $line,
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

# Parse the LVM scan output.
sub _parse_lvm_scan
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $data      = $parameter->{data};
	
	foreach my $line (@{$data})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /(.*?)\s+'(.*?)'\s+\[(.*?)\]/)
		{
			my $state     = $1;
			my $lv        = $2;
			my $size      = $3;
			my $bytes     = $an->Readable->hr_to_bytes({size => $size });
			my $vg        = ($lv =~ /^\/dev\/(.*?)\//)[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
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
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $data      = $parameter->{data};
	
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
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $data      = $parameter->{data};
	
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

# Parse the virsh data.
sub _parse_virsh
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $data      = $parameter->{data};
	
	foreach my $line (@{$data})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		next if $line !~ /^\d/;
		
		my ($id, $say_vm, $state) = split/ /, $line, 3;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "id",     value1 => $id,
			name2 => "saw_vm", value2 => $say_vm,
			name3 => "state",  value3 => $state,
		}, file => $THIS_FILE, line => __LINE__});
		
		my $vm = "vm:$say_vm";
		$an->data->{vm}{$vm}{node}{$node_name}{virsh}{'state'} = $state;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "vm::${vm}::node::${node_name}::virsh::state", value1 => $an->data->{vm}{$vm}{node}{$node_name}{virsh}{'state'},
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($state eq "paused")
		{
			# This VM is being migrated here, disable withdrawl of this node and migration of 
			# this VM.
			$an->data->{node}{$node_name}{enable_withdraw} = 0;
			$an->data->{vm}{$vm}{can_migrate}              = 0;
			$an->data->{node}{$node_name}{enable_poweroff} = 0;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "node::${node_name}::enable_withdraw", value1 => $an->data->{node}{$node_name}{enable_withdraw},
				name2 => "vm::${vm}::can_migrate",              value2 => $an->data->{vm}{$vm}{can_migrate},
				name3 => "node::${node_name}::enable_poweroff", value3 => $an->data->{node}{$node_name}{enable_poweroff},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

# This (tries to) parse the VM definitions files.
sub _parse_vm_defs
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $data      = $parameter->{data};
	
	my $this_vm    = "";
	my $in_domain  = 0;
	my $this_array = [];
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
			$this_vm = $1;
		}
		
		# Push all lines into the current domain array.
		if ($in_domain)
		{
			push @{$this_array}, $line;
		}
		
		# When the end of a domain is found, push the array over to $an->data.
		my $lines = @{$this_array};
		if ($line =~ /<\/domain>/)
		{
			my $vm_key = "vm:$this_vm";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "this_vm",    value1 => $this_vm,
				name2 => "this_array", value2 => $this_array,
				name3 => "lines",      value3 => $lines,
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{vm}{$vm_key}{xml} = $this_array;
			$in_domain  = 0;
			$this_array = [];
		}
	}
	
	return (0);
}

# This (tries to) parse the VM definitions as they are in memory.
sub _parse_vm_defs_in_mem
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $data      = $parameter->{data};
	
	my $this_vm    = "";
	my $in_domain  = 0;
	my $this_array = [];
	foreach my $line (@{$data})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			$this_vm = $1;
		}
		
		# Push all lines into the current domain array.
		if ($in_domain)
		{
			push @{$this_array}, $line;
		}
		
		# When the end of a domain is found, push the array over to $an->data.
		if ($line =~ /<\/domain>/)
		{
			my $vm_key = "vm:$this_vm";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "this_vm",    value1 => $this_vm,
				name2 => "this_array", value2 => $this_array,
				name3 => "lines",      value3 => @{$this_array},
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{vm}{$vm_key}{xml} = $this_array;
			$in_domain  = 0;
			$this_array = [];
		}
	}
	
	return (0);
}

# This sorts out some values once the parsing is collected.
sub _post_node_calculations
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	
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
		$an->Striker->_write_node_cache({node => $node_name});
	}
	
	return (0);
}

# This records this scan's data to the cache file.
sub _write_node_cache
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	
	# It's a program error to try and write the cache file when the node is down.
	my @lines;
	my $cache_file = $an->data->{path}{'striker_cache'}."/cache_".$anvil."_".$node_name.".striker";
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
	my $anvil                      = $an->data->{sys}{anvil}{name};
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

# This reads a VM's definition file and pulls out information about the system.
sub _read_vm_definition
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
	my $anvil     = $an->data->{sys}{anvil}{name};
	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
	my $vm        = $parameter->{server};
	
	if (not $vm)
	{
		my $say_message = $an->String->get({key => "message_0469"});
		$an->Striker->_error({message => $say_message});
	}
	
	my $say_vm = $vm;
	if ($vm =~ /vm:(.*)/)
	{
		$say_vm = $1;
	}
	else
	{
		$vm = "vm:$vm";
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "vm",     value1 => $vm,
		name2 => "say_vm", value2 => $say_vm,
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->data->{vm}{$vm}{definition_file} = "" if not defined $an->data->{vm}{$vm}{definition_file};
	$an->data->{vm}{$vm}{xml}             = "" if not defined $an->data->{vm}{$vm}{xml};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name2 => "vm::${vm}::definition_file", value1 => $an->data->{vm}{$vm}{definition_file},
	}, file => $THIS_FILE, line => __LINE__});

	# Here I want to parse the VM definition XML. Hopefully it was already read in, but if not, I'll go
	# get it.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "vm::${vm}::xml",             value1 => $an->data->{vm}{$vm}{xml},
		name2 => "vm::${vm}::definition_file", value2 => $an->data->{vm}{$vm}{definition_file},
	}, file => $THIS_FILE, line => __LINE__});
	if ((not ref($an->data->{vm}{$vm}{xml}) eq "ARRAY") && ($an->data->{vm}{$vm}{definition_file}))
	{
		$an->data->{vm}{$vm}{raw_xml} = [];
		$an->data->{vm}{$vm}{xml}     = [];
		my $shell_call = $an->data->{path}{cat}." ".$an->data->{vm}{$vm}{definition_file};
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
			push @{$an->data->{vm}{$vm}{raw_xml}}, $line;
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			push @{$an->data->{vm}{$vm}{xml}}, $line;
		}
	}
	
	my $fill_raw_xml = 0;
	my $in_disk      = 0;
	my $in_interface = 0;
	my $current_bridge;
	my $current_device;
	my $current_mac_address;
	my $current_interface_type;
	if (not $an->data->{vm}{$vm}{xml})
	{
		# XML definition not found on the node.
		$an->Log->entry({log_level => 2, message_key => "log_0257", message_variables => {
			node   => $node_name, 
			server => $vm, 
		}, file => $THIS_FILE, line => __LINE__});
		return (0);
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "vm::${vm}::raw_xml", value1 => $an->data->{vm}{$vm}{raw_xml},
	}, file => $THIS_FILE, line => __LINE__});
	if (not ref($an->data->{vm}{$vm}{raw_xml}) eq "ARRAY")
	{
		$an->data->{vm}{$vm}{raw_xml} = [];
		$fill_raw_xml                 = 1;
	}
	foreach my $line (@{$an->data->{vm}{$vm}{xml}})
	{
		next if not $line;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "vm",           value1 => $vm,
			name2 => "line",         value2 => $line,
			name3 => "fill_raw_xml", value3 => $fill_raw_xml,
		}, file => $THIS_FILE, line => __LINE__});
		push @{$an->data->{vm}{$vm}{raw_xml}}, $line if $fill_raw_xml;
		
		# Pull out RAM amount.
		if ($line =~ /<memory>(\d+)<\/memory>/)
		{
			# Record the memory, multiple by 1024 to get bytes.
			$an->data->{vm}{$vm}{details}{ram} =  $1;
			$an->data->{vm}{$vm}{details}{ram} *= 1024;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "vm::${vm}::details::ram", value1 => $an->data->{vm}{$vm}{details}{ram},
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /<memory unit='(.*?)'>(\d+)<\/memory>/)
		{
			# Record the memory, multiple by 1024 to get bytes.
			my $units                             = $1;
			my $ram                               = $2;
			   $an->data->{vm}{$vm}{details}{ram} = $an->Readable->hr_to_bytes({size => $ram, type => $units });
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name2 => "vm::${vm}::details::ram", value2 => $an->data->{vm}{$vm}{details}{ram},
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Pull out the CPU details
		if ($line =~ /<vcpu>(\d+)<\/vcpu>/)
		{
			$an->data->{vm}{$vm}{details}{cpu_count} = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "vm::${vm}::details::cpu_count", value1 => $an->data->{vm}{$vm}{details}{cpu_count},
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /<vcpu placement='(.*?)'>(\d+)<\/vcpu>/)
		{
			my $cpu_type                                = $1;
			   $an->data->{vm}{$vm}{details}{cpu_count} = $2;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "vm::${vm}::details::cpu_count", value1 => $an->data->{vm}{$vm}{details}{cpu_count},
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
			$an->data->{vm}{$vm}{details}{bridge}{$current_bridge}{device} = $current_device         ? $current_device         : "unknown";
			$an->data->{vm}{$vm}{details}{bridge}{$current_bridge}{mac}    = $current_mac_address    ? $current_mac_address    : "unknown";
			$an->data->{vm}{$vm}{details}{bridge}{$current_bridge}{type}   = $current_interface_type ? $current_interface_type : "unknown";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "vm::${vm}::details::bridge::${current_bridge}::device", value1 => $an->data->{vm}{$vm}{details}{bridge}{$current_bridge}{device},
				name2 => "vm::${vm}::details::bridge::${current_bridge}::mac",    value2 => $an->data->{vm}{$vm}{details}{bridge}{$current_bridge}{mac},
				name3 => "vm::${vm}::details::bridge::${current_bridge}::type",   value3 => $an->data->{vm}{$vm}{details}{bridge}{$current_bridge}{type},
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
				name1 => "vm",             value1 => $vm,
				name2 => "interface line", value2 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /source bridge='(.*?)'/)
			{
				$current_bridge = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "vm",             value1 => $vm,
					name2 => "current_bridge", value2 => $current_bridge,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /mac address='(.*?)'/)
			{
				$current_mac_address = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "vm",                  value1 => $vm,
					name2 => "current_mac_address", value2 => $current_mac_address,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /target dev='(.*?)'/)
			{
				$current_device = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "vm",             value1 => $vm,
					name2 => "current_device", value2 => $current_device,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /model type='(.*?)'/)
			{
				$current_interface_type = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "vm",                     value1 => $vm,
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
					name1 => "vm", value1 => $vm,
					name2 => "lv", value2 => $lv,
				}, file => $THIS_FILE, line => __LINE__});
				$an->Striker->_check_lv({node => $node_uuid, server => $vm, logical_volume => $lv});
			}
		}
		
		# Record what graphics we're using for remote connection.
		if ($line =~ /^<graphics /)
		{
			my ($port)   = ($line =~ / port='(\d+)'/);
			my ($type)   = ($line =~ / type='(.*?)'/);
			my ($listen) = ($line =~ / listen='(.*?)'/);
			$an->Log->entry({log_level => 2, message_key => "log_0230", message_variables => {
				server  => $say_vm, 
				type    => $type,
				address => $listen, 
				port    => $port, 
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{vm}{$vm}{graphics}{type}     = $type;
			$an->data->{vm}{$vm}{graphics}{port}     = $port;
			$an->data->{vm}{$vm}{graphics}{'listen'} = $listen;
		}
	}
	my $xml_line_count = @{$an->data->{vm}{$vm}{raw_xml}};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "xml_line_count", value1 => $xml_line_count,
	}, file => $THIS_FILE, line => __LINE__});
	
	return (0);
}


# 	my $self      = shift;
# 	my $parameter = shift;
# 	my $an        = $self->parent;
# 	
# 	my $node_uuid = $parameter->{node} ? $parameter->{node} : "";
# 	my $node_key  = $an->data->{db}{nodes}{$node_uuid}{node_key};
# 	my $anvil     = $an->data->{sys}{anvil}{name};
# 	my $node_name = $an->data->{db}{nodes}{$node_uuid}{name};
# 	my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
# 	my $port      = $an->data->{sys}{anvil}{$node_key}{use_port};
# 	my $password  = $an->data->{sys}{anvil}{$node_key}{password};
# 	my $data      = $parameter->{data};

1;
