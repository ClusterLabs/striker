package AN::Tools::ScanCore;
# 
# This module contains methods used to get data from the ScanCore database.
# 

use strict;
use warnings;
use Data::Dumper;

our $VERSION  = "0.1.001";
my $THIS_FILE = "ScanCore.pm";

### Methods;
# get_anvils
# get_hosts
# get_manifests
# get_migration_target
# get_nodes
# get_nodes_cache
# get_notifications
# get_owners
# get_power_check_data
# get_recipients
# get_servers
# get_smtp
# host_state
# insert_or_update_anvils
# insert_or_update_nodes
# insert_or_update_nodes_cache
# insert_or_update_notifications
# insert_or_update_owners
# insert_or_update_recipients
# insert_or_update_smtp
# insert_or_update_variables
# parse_anvil_data
# parse_install_manifest
# read_cache
# save_install_manifest
# target_power
# update_server_stop_reason

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

# Get a list of Anvil! systems as an array of hash references
sub get_anvils
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_anvils" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $query = "
SELECT 
    anvil_uuid, 
    anvil_owner_uuid, 
    anvil_smtp_uuid, 
    anvil_name, 
    anvil_description, 
    anvil_note, 
    anvil_password, 
    modified_date 
FROM 
    anvils
;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return  = [];
	my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
	my $count   = @{$results};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "results", value1 => $results, 
		name2 => "count",   value2 => $count
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $row (@{$results})
	{
		my $anvil_uuid        = $row->[0];
		my $anvil_owner_uuid  = $row->[1];
		my $anvil_smtp_uuid   = $row->[2];
		my $anvil_name        = $row->[3];
		my $anvil_description = $row->[4];
		my $anvil_note        = $row->[5];
		my $anvil_password    = $row->[6];
		my $modified_date     = $row->[7];
		$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
			name1 => "anvil_uuid",        value1 => $anvil_uuid, 
			name2 => "anvil_owner_uuid",  value2 => $anvil_owner_uuid, 
			name3 => "anvil_smtp_uuid",   value3 => $anvil_smtp_uuid, 
			name4 => "anvil_name",        value4 => $anvil_name, 
			name5 => "anvil_description", value5 => $anvil_description, 
			name6 => "anvil_note",        value6 => $anvil_note, 
			name7 => "modified_date",     value7 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "anvil_password", value1 => $anvil_password, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$return}, {
			anvil_uuid		=>	$anvil_uuid,
			anvil_owner_uuid	=>	$anvil_owner_uuid, 
			anvil_smtp_uuid		=>	$anvil_smtp_uuid, 
			anvil_name		=>	$anvil_name, 
			anvil_description	=>	$anvil_description, 
			anvil_note		=>	$anvil_note, 
			anvil_password		=>	$anvil_password, 
			modified_date		=>	$modified_date, 
		};
	}
	
	return($return);
}

# Get a list of Anvil! hosts as an array of hash references
sub get_hosts
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_hosts" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $query = "
SELECT 
    host_uuid, 
    host_name, 
    host_type, 
    host_emergency_stop, 
    host_stop_reason, 
    host_health, 
    modified_date 
FROM 
    hosts
;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return  = [];
	my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
	my $count   = @{$results};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "results", value1 => $results, 
		name2 => "count",   value2 => $count
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $row (@{$results})
	{
		my $host_uuid           = $row->[0];
		my $host_name           = $row->[1];
		my $host_type           = $row->[2];
		my $host_emergency_stop = $row->[3] ? $row->[3] : "";
		my $host_stop_reason    = $row->[4] ? $row->[4] : "";
		my $host_health         = $row->[5] ? $row->[5] : "";
		my $modified_date       = $row->[6];
		$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
			name1 => "host_uuid",           value1 => $host_uuid, 
			name2 => "host_name",           value2 => $host_name, 
			name3 => "host_type",           value3 => $host_type, 
			name4 => "host_emergency_stop", value4 => $host_emergency_stop, 
			name5 => "host_stop_reason",    value5 => $host_stop_reason, 
			name6 => "host_health",         value6 => $host_health, 
			name7 => "modified_date",       value7 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$return}, {
			host_uuid		=>	$host_uuid,
			host_name		=>	$host_name, 
			host_type		=>	$host_type, 
			host_emergency_stop	=>	$host_emergency_stop, 
			host_stop_reason	=>	$host_stop_reason, 
			host_health		=>	$host_health, 
			modified_date		=>	$modified_date, 
		};
		
		# Record the host_uuid in a hash so that the name can be easily retrieved.
		$an->data->{sys}{uuid_to_name}{$host_uuid} = $host_name;
	}
	
	return($return);
}

# Get a list of Anvil! Install Manifests as an array of hash references
sub get_manifests
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_manifests" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $query = "
SELECT 
    manifest_uuid, 
    manifest_data, 
    manifest_note, 
    modified_date 
FROM 
    manifests
;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return  = [];
	my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
	my $count   = @{$results};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "results", value1 => $results, 
		name2 => "count",   value2 => $count
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $row (@{$results})
	{
		my $manifest_uuid = $row->[0];
		my $manifest_data = $row->[1];
		my $manifest_note = $row->[2] ? $row->[2] : "NULL";
		my $modified_date = $row->[3];
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "manifest_uuid", value1 => $manifest_uuid, 
			name2 => "manifest_data", value2 => $manifest_data, 
			name3 => "manifest_note", value3 => $manifest_note, 
			name4 => "modified_date", value4 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$return}, {
			manifest_uuid	=>	$manifest_uuid,
			manifest_data	=>	$manifest_data, 
			manifest_note	=>	$manifest_note, 
			modified_date	=>	$modified_date, 
		};
	}
	
	return($return);
}

# This returns the migration target of a given server, if it is being migrated.
sub get_migration_target
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_migration_target" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $server = $parameter->{server} ? $parameter->{server} : "";
	if (not $server)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0101", code => 101, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	my $query  = "
SELECT 
    a.host_name 
FROM 
    hosts a, 
    states b 
WHERE 
    a.host_uuid = b.state_host_uuid 
AND 
    b.state_name = 'migration' 
AND 
    b.state_note = ".$an->data->{sys}{use_db_fh}->quote($server)."
;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query, 
	}, file => $THIS_FILE, line => __LINE__});
	my $target = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__})->[0]->[0];
	   $target = "" if not $target;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "target", value1 => $target, 
	}, file => $THIS_FILE, line => __LINE__});
	
	return($target);
}

# Get a list of Anvil! nodes as an array of hash references
sub get_nodes
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_nodes" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $query = "
SELECT 
    a.node_uuid, 
    a.node_anvil_uuid, 
    a.node_host_uuid, 
    a.node_remote_ip, 
    a.node_remote_port, 
    a.node_note, 
    a.node_bcn, 
    a.node_sn, 
    a.node_ifn, 
    a.node_password,
    b.host_name,  
    a.modified_date 
FROM 
    nodes a,
    hosts b 
WHERE 
    a.node_host_uuid = b.host_uuid
;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return  = [];
	my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
	my $count   = @{$results};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "results", value1 => $results, 
		name2 => "count",   value2 => $count
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $row (@{$results})
	{
		my $node_uuid        = $row->[0];
		my $node_anvil_uuid  = $row->[1];
		my $node_host_uuid   = $row->[2];
		my $node_remote_ip   = $row->[3] ? $row->[3] : "";
		my $node_remote_port = $row->[4] ? $row->[4] : "";
		my $node_note        = $row->[5] ? $row->[5] : "";
		my $node_bcn         = $row->[6] ? $row->[6] : "";
		my $node_sn          = $row->[7] ? $row->[7] : "";
		my $node_ifn         = $row->[8] ? $row->[8] : "";
		my $node_password    = $row->[9] ? $row->[9] : "";
		my $host_name        = $row->[10];
		my $modified_date    = $row->[11];
		$an->Log->entry({log_level => 3, message_key => "an_variables_0011", message_variables => {
			name1  => "node_uuid",        value1  => $node_uuid, 
			name2  => "node_anvil_uuid",  value2  => $node_anvil_uuid, 
			name3  => "node_host_uuid",   value3  => $node_host_uuid, 
			name4  => "node_remote_ip",   value4  => $node_remote_ip, 
			name5  => "node_remote_port", value5  => $node_remote_port, 
			name6  => "node_note",        value6  => $node_note, 
			name7  => "node_bcn",         value7  => $node_bcn, 
			name8  => "node_sn",          value8  => $node_sn, 
			name9  => "node_ifn",         value9  => $node_ifn, 
			name10 => "host_name",        value10 => $host_name, 
			name11 => "modified_date",    value11 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "node_password", value1 => $node_password, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$return}, {
			node_uuid		=>	$node_uuid,
			node_anvil_uuid		=>	$node_anvil_uuid, 
			node_host_uuid		=>	$node_host_uuid, 
			node_remote_ip		=>	$node_remote_ip, 
			node_remote_port	=>	$node_remote_port, 
			node_note		=>	$node_note, 
			node_bcn		=>	$node_bcn, 
			node_sn			=>	$node_sn, 
			node_ifn		=>	$node_ifn, 
			host_name		=>	$host_name, 
			node_password		=>	$node_password, 
			modified_date		=>	$modified_date, 
		};
	}
	
	return($return);
}

# Get a list of node's cache as an array of hash references
sub get_nodes_cache
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_nodes_cache" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# The user may want cache data from all machines but only of a certain type.
	my $type = $parameter->{type} ? $parameter->{type} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "type", value1 => $type,
	}, file => $THIS_FILE, line => __LINE__});
	
	### NOTE: This is NOT restricted to the host because if this host doesn't have cache data for a given
	###       node, it might be able to use data cached by another host.
	my $query = "
SELECT 
    node_cache_uuid, 
    node_cache_host_uuid, 
    node_cache_node_uuid, 
    node_cache_name, 
    node_cache_data, 
    node_cache_note, 
    modified_date 
FROM 
    nodes_cache ";
	if ($type)
	{
		$query .= "
WHERE 
    node_cache_name = ".$an->data->{sys}{use_db_fh}->quote($type)."
";
	}
	$query .= "
;";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return  = [];
	my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
	my $count   = @{$results};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "results", value1 => $results, 
		name2 => "count",   value2 => $count
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $row (@{$results})
	{
		my $node_cache_uuid      = $row->[0];
		my $node_cache_host_uuid = $row->[1];
		my $node_cache_node_uuid = $row->[2];
		my $node_cache_name      = $row->[3];
		my $node_cache_data      = $row->[4] ? $row->[4] : "";
		my $node_cache_note      = $row->[5] ? $row->[5] : "";
		my $modified_date        = $row->[6];
		$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
			name1 => "node_cache_uuid",      value1 => $node_cache_uuid, 
			name2 => "node_cache_host_uuid", value2 => $node_cache_host_uuid, 
			name3 => "node_cache_node_uuid", value3 => $node_cache_node_uuid, 
			name4 => "node_cache_name",      value4 => $node_cache_name, 
			name5 => "node_cache_data",      value5 => $node_cache_data, 
			name6 => "node_cache_note",      value6 => $node_cache_note, 
			name7 => "modified_date",        value7 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$return}, {
			node_cache_uuid		=>	$node_cache_uuid, 
			node_cache_host_uuid	=>	$node_cache_host_uuid, 
			node_cache_node_uuid	=>	$node_cache_node_uuid, 
			node_cache_name		=>	$node_cache_name, 
			node_cache_data		=>	$node_cache_data, 
			node_cache_note		=>	$node_cache_note, 
			modified_date		=>	$modified_date, 
		};
	}
	
	return($return);
}

# Get a list of Anvil! Owners as an array of hash references
sub get_notifications
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_notifications" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $query = "
SELECT 
    notify_uuid, 
    notify_name, 
    notify_target, 
    notify_language, 
    notify_level, 
    notify_units, 
    notify_note, 
    modified_date 
FROM 
    notifications
;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return  = [];
	my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
	my $count   = @{$results};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "results", value1 => $results, 
		name2 => "count",   value2 => $count
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $row (@{$results})
	{
		my $notify_uuid     = $row->[0];
		my $notify_name     = $row->[1];
		my $notify_target   = $row->[2];
		my $notify_language = $row->[3];
		my $notify_level    = $row->[4];
		my $notify_units    = $row->[5];
		my $notify_note     = $row->[6] ? $row->[6] : "";
		my $modified_date   = $row->[7];
		$an->Log->entry({log_level => 3, message_key => "an_variables_0008", message_variables => {
			name1 => "notify_uuid",     value1 => $notify_uuid, 
			name2 => "notify_name",     value2 => $notify_name, 
			name3 => "notify_target",   value3 => $notify_target, 
			name4 => "notify_language", value4 => $notify_language, 
			name5 => "notify_level",    value5 => $notify_level, 
			name6 => "notify_units",    value6 => $notify_units, 
			name7 => "notify_note",     value7 => $notify_note, 
			name8 => "modified_date",   value8 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$return}, {
			notify_uuid	=>	$notify_uuid,
			notify_name	=>	$notify_name, 
			notify_target	=>	$notify_target, 
			notify_language	=>	$notify_language, 
			notify_level	=>	$notify_level, 
			notify_units	=>	$notify_units, 
			notify_note	=>	$notify_note, 
			modified_date	=>	$modified_date, 
		};
	}
	
	return($return);
}

# Get a list of Anvil! Owners as an array of hash references
sub get_owners
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_owners" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $query = "
SELECT 
    owner_uuid, 
    owner_name, 
    owner_note, 
    modified_date 
FROM 
    owners
;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return  = [];
	my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
	my $count   = @{$results};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "results", value1 => $results, 
		name2 => "count",   value2 => $count
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $row (@{$results})
	{
		my $owner_uuid    = $row->[0];
		my $owner_name    = $row->[1];
		my $owner_note    = $row->[2] ? $row->[2] : "";
		my $modified_date = $row->[3];
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "owner_uuid",    value1 => $owner_uuid, 
			name2 => "owner_name",    value2 => $owner_name, 
			name3 => "owner_note",    value3 => $owner_note, 
			name4 => "modified_date", value4 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$return}, {
			owner_uuid	=>	$owner_uuid,
			owner_name	=>	$owner_name, 
			owner_note	=>	$owner_note, 
			modified_date	=>	$modified_date, 
		};
	}
	
	return($return);
}

# This returns an array containing all of the power check commands for nodes that the caller knows about.
sub get_power_check_data
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_power_check_data" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# If I am a node, I will check the local cluster.conf and override anything that conflicts with cache
	# as the cluster.conf is more accurate.
	my $return   = [];
	my $i_am_a   = $an->Get->what_am_i();
	my $hostname = $an->hostname();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "i_am_a",   value1 => $i_am_a,
		name2 => "hostname", value2 => $hostname
	}, file => $THIS_FILE, line => __LINE__});
	
	# Parse the cluster.conf file. This will cause the cache to be up to date.
	if (($i_am_a eq "node") && (-e $an->data->{path}{cman_config}))
	{
		# Read and parse our cluster.conf (which updates the cache).
		$an->Striker->_parse_cluster_conf();
	}
	
	# Read the power_check data from cache for all the machines we know about.
	my $power_check_data = $an->ScanCore->get_nodes_cache({type => "power_check"});
	my $node_data        = $an->ScanCore->get_nodes();
	foreach my $hash_ref (@{$node_data})
	{
		my $node_name                                  = $hash_ref->{host_name};
		my $node_uuid                                  = $hash_ref->{node_uuid};
		   $an->data->{node}{uuid_to_name}{$node_uuid} = $node_name;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node::uuid_to_name::$node_uuid", value1 => $an->data->{node}{uuid_to_name}{$node_uuid}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	foreach my $hash_ref (@{$power_check_data})
	{
		# Ignore any data cache by other nodes.
		my $node_cache_host_uuid = $hash_ref->{node_cache_host_uuid}; 
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "sys::host_uuid",       value1 => $an->data->{sys}{host_uuid}, 
			name2 => "node_cache_host_uuid", value2 => $node_cache_host_uuid, 
		}, file => $THIS_FILE, line => __LINE__});
		next if $node_cache_host_uuid ne $an->data->{sys}{host_uuid};
		
		my $node_cache_node_uuid = $hash_ref->{node_cache_node_uuid};
		my $node_cache_data      = $hash_ref->{node_cache_data};
		my $node_name            = $an->data->{node}{uuid_to_name}{$node_cache_node_uuid};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node_cache_node_uuid", value1 => $node_cache_node_uuid, 
			name2 => "node_cache_data",      value2 => $node_cache_data, 
			name3 => "node_name",            value3 => $node_name, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Find the IPMI entry, if any
		my $power_check_command = ($node_cache_data =~ /(fence_ipmilan .*?);/)[0];
		next if not $power_check_command;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "power_check_command", value1 => $power_check_command, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# I need to remove the double-quotes from the '-p "<password>"'.
		$power_check_command =~ s/-p "(.*?)"/-p $1/;
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "node_name",            value1 => $node_name, 
			name2 => "node_cache_node_uuid", value2 => $node_cache_node_uuid, 
			name3 => "power_check_command",  value3 => $power_check_command, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$return}, {
			node_name           => $node_name,
			node_uuid           => $node_cache_node_uuid, 
			power_check_command => $power_check_command,
		};
	}
	
	return($return);
}

# Get a list of recipients (links between Anvil! systems and who receives alert notifications from it).
sub get_recipients
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_recipients" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $query = "
SELECT 
    recipient_uuid, 
    recipient_anvil_uuid, 
    recipient_notify_uuid, 
    recipient_notify_level, 
    recipient_note, 
    modified_date 
FROM 
    recipients
;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return  = [];
	my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
	my $count   = @{$results};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "results", value1 => $results, 
		name2 => "count",   value2 => $count
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $row (@{$results})
	{
		my $recipient_uuid         = $row->[0];
		my $recipient_anvil_uuid   = $row->[1];
		my $recipient_notify_uuid  = $row->[2];
		my $recipient_notify_level = $row->[3];
		my $recipient_note         = $row->[4] ? $row->[4] : "";
		my $modified_date          = $row->[5];
		$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
			name1 => "recipient_uuid",         value1 => $recipient_uuid, 
			name2 => "recipient_anvil_uuid",   value2 => $recipient_anvil_uuid, 
			name3 => "recipient_notify_uuid",  value3 => $recipient_notify_uuid, 
			name4 => "recipient_notify_level", value4 => $recipient_notify_level, 
			name5 => "recipient_note",         value5 => $recipient_note, 
			name6 => "modified_date",          value6 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$return}, {
			recipient_uuid		=>	$recipient_uuid,
			recipient_anvil_uuid	=>	$recipient_anvil_uuid, 
			recipient_notify_uuid	=>	$recipient_notify_uuid, 
			recipient_notify_level	=>	$recipient_notify_level, 
			recipient_note		=>	$recipient_note, 
			modified_date		=>	$modified_date, 
		};
	}
	
	return($return);
}

# Get a list of Anvil! servers as an array of hash references
sub get_servers
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_servers" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $query = "
SELECT 
    server_uuid, 
    server_name, 
    server_stop_reason, 
    server_start_after, 
    server_start_delay, 
    server_note, 
    server_definition, 
    server_host, 
    server_state, 
    server_migration_type, 
    server_pre_migration_script, 
    server_pre_migration_arguments, 
    server_post_migration_script, 
    server_post_migration_arguments, 
    modified_date 
FROM 
    servers
;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return  = [];
	my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
	my $count   = @{$results};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "results", value1 => $results, 
		name2 => "count",   value2 => $count
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $row (@{$results})
	{
		my $server_uuid                     = $row->[0];
		my $server_name                     = $row->[1];
		my $server_stop_reason              = $row->[2];
		my $server_start_after              = $row->[3];
		my $server_start_delay              = $row->[4];
		my $server_note                     = $row->[5] ? $row->[5] : "";
		my $server_definition               = $row->[6];
		my $server_host                     = $row->[7];
		my $server_state                    = $row->[8];
		my $server_migration_type           = $row->[9];
		my $server_pre_migration_script     = $row->[10];
		my $server_pre_migration_arguments  = $row->[11];
		my $server_post_migration_script    = $row->[12];
		my $server_post_migration_arguments = $row->[13];
		my $modified_date                   = $row->[14];
		$an->Log->entry({log_level => 3, message_key => "an_variables_0014", message_variables => {
			name1  => "server_uuid",                     value1  => $server_uuid, 
			name2  => "server_name",                     value2  => $server_name, 
			name3  => "server_stop_reason",              value3  => $server_stop_reason, 
			name4  => "server_start_after",              value4  => $server_start_after, 
			name5  => "server_start_delay",              value5  => $server_start_delay, 
			name6  => "server_note",                     value6  => $server_note, 
			name7  => "server_definition",               value7  => $server_definition, 
			name8  => "server_host",                     value8  => $server_host, 
			name9  => "server_state",                    value9  => $server_state, 
			name10 => "server_migration_type",           value10 => $server_migration_type, 
			name11 => "server_pre_migration_script",     value11 => $server_pre_migration_script, 
			name12 => "server_pre_migration_arguments",  value12 => $server_pre_migration_arguments, 
			name13 => "server_post_migration_script",    value13 => $server_post_migration_script, 
			name14 => "server_post_migration_arguments", value14 => $server_post_migration_arguments, 
			name15 => "modified_date",                   value15 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$return}, {
			server_uuid			=>	$server_uuid,
			server_name			=>	$server_name, 
			server_stop_reason		=>	$server_stop_reason, 
			server_start_after		=>	$server_start_after, 
			server_start_delay		=>	$server_start_delay, 
			server_note			=>	$server_note, 
			server_definition		=>	$server_definition, 
			server_host			=>	$server_host, 
			server_state			=>	$server_state, 
			server_migration_type		=>	$server_migration_type, 
			server_pre_migration_script	=>	$server_pre_migration_script, 
			server_pre_migration_arguments	=>	$server_pre_migration_arguments, 
			server_post_migration_script	=>	$server_post_migration_script, 
			server_post_migration_arguments	=>	$server_post_migration_arguments, 
			modified_date			=>	$modified_date, 
		};
	}
	
	return($return);
}

# Get a list of Anvil! SMTP mail servers as an array of hash references
sub get_smtp
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_smtp" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $query = "
SELECT 
    smtp_uuid, 
    smtp_server, 
    smtp_port, 
    smtp_username, 
    smtp_password, 
    smtp_security, 
    smtp_authentication, 
    smtp_helo_domain,
    modified_date 
FROM 
    smtp
;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return  = [];
	my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
	my $count   = @{$results};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "results", value1 => $results, 
		name2 => "count",   value2 => $count
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $row (@{$results})
	{
		my $smtp_uuid           = $row->[0];
		my $smtp_server         = $row->[1];
		my $smtp_port           = $row->[2];
		my $smtp_username       = $row->[3];
		my $smtp_password       = $row->[4];
		my $smtp_security       = $row->[5];
		my $smtp_authentication = $row->[6];
		my $smtp_helo_domain    = $row->[7];
		my $modified_date       = $row->[8];
		$an->Log->entry({log_level => 3, message_key => "an_variables_0008", message_variables => {
			name1 => "smtp_uuid",           value1 => $smtp_uuid, 
			name2 => "smtp_server",         value2 => $smtp_server, 
			name3 => "smtp_port",           value3 => $smtp_port, 
			name4 => "smtp_username",       value4 => $smtp_username, 
			name5 => "smtp_security",       value5 => $smtp_security, 
			name6 => "smtp_authentication", value6 => $smtp_authentication, 
			name7 => "smtp_helo_domain",    value7 => $smtp_helo_domain, 
			name8 => "modified_date",       value8 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "smtp_password", value1 => $smtp_password, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$return}, {
			smtp_uuid		=>	$smtp_uuid,
			smtp_server		=>	$smtp_server, 
			smtp_port		=>	$smtp_port, 
			smtp_username		=>	$smtp_username, 
			smtp_password		=>	$smtp_password, 
			smtp_security		=>	$smtp_security, 
			smtp_authentication	=>	$smtp_authentication, 
			smtp_helo_domain	=>	$smtp_helo_domain, 
			modified_date		=>	$modified_date, 
		};
	}
	
	return($return);
}

# Returns (and sets, if requested) the health of the target.
sub host_state
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "host_state" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# This will store the state.
	my $state = "";
	
	# If I don't have a target, use the local host.
	my $target = $parameter->{target} ? $parameter->{target} : "host_uuid";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "target", value1 => $target, 
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->Validate->is_uuid({uuid => $target}))
	{
		# Translate the target to a host_uuid
		$target = $an->Get->uuid({get => $target});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "target", value1 => $target, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $valid = $an->Validate->is_uuid({uuid => $target});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "valid", value1 => $valid, 
		}, file => $THIS_FILE, line => __LINE__});
		if (not $valid)
		{
			# No host 
			$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0099", message_variables => { target => $parameter->{target} }, code => 99, file => $THIS_FILE, line => __LINE__});
			return("");
		}
	}
	
	# First, read the current state. We'll update it if needed in a minute.
	my $query = "
SELECT 
    host_health 
FROM 
    hosts 
WHERE 
    host_uuid = ".$an->data->{sys}{use_db_fh}->quote($target)." 
;";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
	my $count   = @{$results};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "results", value1 => $results, 
		name2 => "count",   value2 => $count
	}, file => $THIS_FILE, line => __LINE__});
	
	# If the count is '0', the host wasn't found and we've hit a program error.
	if (not $count)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0100", message_variables => { target => $target }, code => 100, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	my $current_health = "";
	foreach my $row (@{$results})
	{
		$current_health = $row->[0] ? $row->[0] : "";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "current_health", value1 => $current_health, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Am I setting?
	my $host_health = $parameter->{set} ? $parameter->{set} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "host_health", value1 => $host_health, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($host_health)
	{
		# Yup. Has it changed?
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "current_health", value1 => $current_health, 
			name2 => "host_health",    value2 => $host_health, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($current_health ne $host_health)
		{
			# It has changed.
			   $current_health = $host_health;
			my $query          = "
UPDATE 
    hosts 
SET 
    host_health   = ".$an->data->{sys}{use_db_fh}->quote($host_health).", 
    modified_date = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    host_uuid     = ".$an->data->{sys}{use_db_fh}->quote($target)." 
";
			$query =~ s/'NULL'/NULL/g;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "query", value1 => $query
			}, file => $THIS_FILE, line => __LINE__});
			$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If there is no current health data, assume the node is healthy.
	if ($current_health eq "")
	{
		$current_health = "ok";
		$an->Log->entry({log_level => 1, message_key => "warning_message_0016", message_variables => {
			target => $target, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "current_health", value1 => $current_health, 
	}, file => $THIS_FILE, line => __LINE__});
	return($current_health);
}

# This updates (or inserts) a record in the 'anvils' table.
sub insert_or_update_anvils
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "insert_or_update_anvils" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid        = $parameter->{anvil_uuid}        ? $parameter->{anvil_uuid}        : "";
	my $anvil_owner_uuid  = $parameter->{anvil_owner_uuid}  ? $parameter->{anvil_owner_uuid}  : "";
	my $anvil_smtp_uuid   = $parameter->{anvil_smtp_uuid}   ? $parameter->{anvil_smtp_uuid}   : "";
	my $anvil_name        = $parameter->{anvil_name}        ? $parameter->{anvil_name}        : "";
	my $anvil_description = $parameter->{anvil_description} ? $parameter->{anvil_description} : "";
	my $anvil_note        = $parameter->{anvil_note}        ? $parameter->{anvil_note}        : "";
	my $anvil_password    = $parameter->{anvil_password}    ? $parameter->{anvil_password}    : "";
	if (not $anvil_name)
	{
		# Throw an error and exit.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0079", code => 79, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# If we don't have a UUID, see if we can find one for the given Anvil! name.
	if (not $anvil_uuid)
	{
		my $query = "
SELECT 
    anvil_uuid 
FROM 
    anvils 
WHERE 
    anvil_name = ".$an->data->{sys}{use_db_fh}->quote($anvil_name)." 
;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			$anvil_uuid = $row->[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "anvil_uuid", value1 => $anvil_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If I still don't have an anvil_uuid, we're INSERT'ing .
	if (not $anvil_uuid)
	{
		# INSERT, *if* we have an owner and smtp UUID.
		if (not $anvil_owner_uuid)
		{
			$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0080", code => 80, file => $THIS_FILE, line => __LINE__});
			return("");
		}
		if (not $anvil_smtp_uuid)
		{
			$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0081", code => 81, file => $THIS_FILE, line => __LINE__});
			return("");
		}
		   $anvil_uuid = $an->Get->uuid();
		my $query      = "
INSERT INTO 
    anvils 
(
    anvil_uuid,
    anvil_owner_uuid,
    anvil_smtp_uuid,
    anvil_name,
    anvil_description,
    anvil_note,
    anvil_password,
    modified_date 
) VALUES (
    ".$an->data->{sys}{use_db_fh}->quote($anvil_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($anvil_owner_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($anvil_smtp_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($anvil_name).", 
    ".$an->data->{sys}{use_db_fh}->quote($anvil_description).", 
    ".$an->data->{sys}{use_db_fh}->quote($anvil_note).", 
    ".$an->data->{sys}{use_db_fh}->quote($anvil_password).", 
    ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
);
";
		$query =~ s/'NULL'/NULL/g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Query the rest of the values and see if anything changed.
		my $query = "
SELECT 
    anvil_owner_uuid,
    anvil_smtp_uuid,
    anvil_name,
    anvil_description,
    anvil_note,
    anvil_password 
FROM 
    anvils 
WHERE 
    anvil_uuid = ".$an->data->{sys}{use_db_fh}->quote($anvil_uuid)." 
;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			my $old_anvil_owner_uuid  = $row->[0];
			my $old_anvil_smtp_uuid   = $row->[1];
			my $old_anvil_name        = $row->[2];
			my $old_anvil_description = $row->[3];
			my $old_anvil_note        = $row->[4];
			my $old_anvil_password    = $row->[5];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
				name1 => "old_anvil_owner_uuid",  value1 => $old_anvil_owner_uuid, 
				name2 => "old_anvil_smtp_uuid",   value2 => $old_anvil_smtp_uuid, 
				name3 => "old_anvil_name",        value3 => $old_anvil_name, 
				name4 => "old_anvil_description", value4 => $old_anvil_description, 
				name5 => "old_anvil_note",        value5 => $old_anvil_note, 
				name6 => "old_anvil_password",    value6 => $old_anvil_password, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Anything change?
			if (($old_anvil_owner_uuid  ne $anvil_owner_uuid)  or 
			    ($old_anvil_smtp_uuid   ne $anvil_smtp_uuid)   or 
			    ($old_anvil_name        ne $anvil_name)        or 
			    ($old_anvil_description ne $anvil_description) or 
			    ($old_anvil_note        ne $anvil_note)        or 
			    ($old_anvil_password    ne $anvil_password)) 
			{
				# Something changed, save.
				my $query = "
UPDATE 
    anvils 
SET 
    anvil_owner_uuid  = ".$an->data->{sys}{use_db_fh}->quote($anvil_owner_uuid).",
    anvil_smtp_uuid   = ".$an->data->{sys}{use_db_fh}->quote($anvil_smtp_uuid).",
    anvil_name        = ".$an->data->{sys}{use_db_fh}->quote($anvil_name).", 
    anvil_description = ".$an->data->{sys}{use_db_fh}->quote($anvil_description).",
    anvil_note        = ".$an->data->{sys}{use_db_fh}->quote($anvil_note).",
    anvil_password    = ".$an->data->{sys}{use_db_fh}->quote($anvil_password).",
    modified_date     = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    anvil_uuid        = ".$an->data->{sys}{use_db_fh}->quote($anvil_uuid)." 
";
				$query =~ s/'NULL'/NULL/g;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "query", value1 => $query, 
				}, file => $THIS_FILE, line => __LINE__});
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($anvil_uuid);
}

# This updates (or inserts) a record in the 'nodes' table.
sub insert_or_update_nodes
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "insert_or_update_nodes" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_uuid        = $parameter->{node_uuid}        ? $parameter->{node_uuid}        : "";
	my $node_anvil_uuid  = $parameter->{node_anvil_uuid}  ? $parameter->{node_anvil_uuid}  : "";
	my $node_host_uuid   = $parameter->{node_host_uuid}   ? $parameter->{node_host_uuid}   : "";
	my $node_remote_ip   = $parameter->{node_remote_ip}   ? $parameter->{node_remote_ip}   : "NULL";
	my $node_remote_port = $parameter->{node_remote_port} ? $parameter->{node_remote_port} : "NULL";
	my $node_note        = $parameter->{node_note}        ? $parameter->{node_note}        : "NULL";
	my $node_bcn         = $parameter->{node_bcn}         ? $parameter->{node_bcn}         : "NULL";
	my $node_sn          = $parameter->{node_sn}          ? $parameter->{node_sn}          : "NULL";
	my $node_ifn         = $parameter->{node_ifn}         ? $parameter->{node_ifn}         : "NULL";
	my $node_password    = $parameter->{node_password}    ? $parameter->{node_password}    : "NULL";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0009", message_variables => {
		name1 => "node_uuid",        value1 => $node_uuid, 
		name2 => "node_anvil_uuid",  value2 => $node_anvil_uuid, 
		name3 => "node_host_uuid",   value3 => $node_host_uuid, 
		name4 => "node_remote_ip",   value4 => $node_remote_ip, 
		name5 => "node_remote_port", value5 => $node_remote_port, 
		name6 => "node_note",        value6 => $node_note, 
		name7 => "node_bcn",         value7 => $node_bcn, 
		name8 => "node_sn",          value8 => $node_sn, 
		name9 => "node_ifn",         value9 => $node_ifn, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "node_password", value1 => $node_password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If we don't have a UUID, see if we can find one for the given host UUID.
	if (not $node_uuid)
	{
		my $query = "
SELECT 
    node_uuid 
FROM 
    nodes 
WHERE 
    node_host_uuid = ".$an->data->{sys}{use_db_fh}->quote($node_host_uuid)." 
;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			$node_uuid = $row->[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "node_uuid", value1 => $node_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If I still don't have an anvil_uuid, we're INSERT'ing .
	if (not $node_uuid)
	{
		# INSERT, *if* we have an owner and smtp UUID.
		if (not $node_anvil_uuid)
		{
			$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0082", code => 82, file => $THIS_FILE, line => __LINE__});
			return("");
		}
		if (not $node_host_uuid)
		{
			$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0083", code => 83, file => $THIS_FILE, line => __LINE__});
			return("");
		}
		   $node_uuid = $an->Get->uuid();
		my $query      = "
INSERT INTO 
    nodes 
(
    node_uuid,
    node_anvil_uuid, 
    node_host_uuid, 
    node_remote_ip, 
    node_remote_port, 
    node_note, 
    node_bcn, 
    node_sn, 
    node_ifn, 
    node_password,
    modified_date 
) VALUES (
    ".$an->data->{sys}{use_db_fh}->quote($node_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($node_anvil_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($node_host_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($node_remote_ip).", 
    ".$an->data->{sys}{use_db_fh}->quote($node_remote_port).", 
    ".$an->data->{sys}{use_db_fh}->quote($node_note).", 
    ".$an->data->{sys}{use_db_fh}->quote($node_bcn).", 
    ".$an->data->{sys}{use_db_fh}->quote($node_sn).", 
    ".$an->data->{sys}{use_db_fh}->quote($node_ifn).", 
    ".$an->data->{sys}{use_db_fh}->quote($node_password).", 
    ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
);
";
		$query =~ s/'NULL'/NULL/g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Query the rest of the values and see if anything changed.
		my $query = "
SELECT 
    node_anvil_uuid, 
    node_host_uuid, 
    node_remote_ip, 
    node_remote_port, 
    node_note, 
    node_bcn, 
    node_sn, 
    node_ifn, 
    node_password 
FROM 
    nodes 
WHERE 
    node_uuid = ".$an->data->{sys}{use_db_fh}->quote($node_uuid)." 
;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			my $old_node_anvil_uuid  = $row->[0]; 
			my $old_node_host_uuid   = $row->[1]; 
			my $old_node_remote_ip   = $row->[2] ? $row->[2] : "NULL"; 
			my $old_node_remote_port = $row->[3] ? $row->[3] : "NULL"; 
			my $old_node_note        = $row->[4] ? $row->[4] : "NULL"; 
			my $old_node_bcn         = $row->[5] ? $row->[5] : "NULL"; 
			my $old_node_sn          = $row->[6] ? $row->[6] : "NULL"; 
			my $old_node_ifn         = $row->[7] ? $row->[7] : "NULL"; 
			my $old_node_password    = $row->[8] ? $row->[8] : "NULL"; 
			$an->Log->entry({log_level => 3, message_key => "an_variables_0009", message_variables => {
				name1 => "old_node_anvil_uuid",  value1 => $old_node_anvil_uuid, 
				name2 => "old_node_host_uuid",   value2 => $old_node_host_uuid, 
				name3 => "old_node_remote_ip",   value3 => $old_node_remote_ip, 
				name4 => "old_node_remote_port", value4 => $old_node_remote_port, 
				name5 => "old_node_note",        value5 => $old_node_note, 
				name6 => "old_node_bcn",         value6 => $old_node_bcn, 
				name7 => "old_node_sn",          value7 => $old_node_sn, 
				name8 => "old_node_ifn",         value8 => $old_node_ifn, 
				name9 => "old_node_password",    value9 => $old_node_password, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Anything change?
			if (($old_node_anvil_uuid  ne $node_anvil_uuid)  or 
			    ($old_node_host_uuid   ne $node_host_uuid)   or 
			    ($old_node_remote_ip   ne $node_remote_ip)   or 
			    ($old_node_remote_port ne $node_remote_port) or 
			    ($old_node_note        ne $node_note)        or 
			    ($old_node_bcn         ne $node_bcn)         or 
			    ($old_node_sn          ne $node_sn)          or 
			    ($old_node_ifn         ne $node_ifn)         or 
			    ($old_node_password    ne $node_password)) 
			{
				# Something changed, save.
				my $query = "
UPDATE 
    nodes 
SET 
    node_anvil_uuid  = ".$an->data->{sys}{use_db_fh}->quote($node_anvil_uuid).",  
    node_host_uuid   = ".$an->data->{sys}{use_db_fh}->quote($node_host_uuid).",  
    node_remote_ip   = ".$an->data->{sys}{use_db_fh}->quote($node_remote_ip).",  
    node_remote_port = ".$an->data->{sys}{use_db_fh}->quote($node_remote_port).",  
    node_note        = ".$an->data->{sys}{use_db_fh}->quote($node_note).",  
    node_bcn         = ".$an->data->{sys}{use_db_fh}->quote($node_bcn).",  
    node_sn          = ".$an->data->{sys}{use_db_fh}->quote($node_sn).",  
    node_ifn         = ".$an->data->{sys}{use_db_fh}->quote($node_ifn).",  
    node_password    = ".$an->data->{sys}{use_db_fh}->quote($node_password).", 
    modified_date    = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    node_uuid        = ".$an->data->{sys}{use_db_fh}->quote($node_uuid)." 
";
				$query =~ s/'NULL'/NULL/g;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "query", value1 => $query, 
				}, file => $THIS_FILE, line => __LINE__});
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($node_uuid);
}

# This updates (or inserts) a record in the 'nodes_cache' table.
sub insert_or_update_nodes_cache
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "insert_or_update_nodes_cache" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_cache_uuid      = $parameter->{node_cache_uuid}      ? $parameter->{node_cache_uuid}      : "";
	my $node_cache_host_uuid = $parameter->{node_cache_host_uuid} ? $parameter->{node_cache_host_uuid} : "";
	my $node_cache_node_uuid = $parameter->{node_cache_node_uuid} ? $parameter->{node_cache_node_uuid} : "";
	my $node_cache_name      = $parameter->{node_cache_name}      ? $parameter->{node_cache_name}      : "";
	my $node_cache_data      = $parameter->{node_cache_data}      ? $parameter->{node_cache_data}      : "NULL";
	my $node_cache_note      = $parameter->{node_cache_note}      ? $parameter->{node_cache_note}      : "NULL";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "node_cache_uuid",      value1 => $node_cache_uuid, 
		name2 => "node_cache_host_uuid", value2 => $node_cache_host_uuid, 
		name3 => "node_cache_node_uuid", value3 => $node_cache_node_uuid, 
		name4 => "node_cache_name",      value4 => $node_cache_name, 
		name5 => "node_cache_data",      value5 => $node_cache_data, 
		name6 => "node_cache_note",      value6 => $node_cache_note, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# We need a host_uuid, node_uuid and name
	if (not $node_cache_host_uuid)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0082", code => 82, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	if (not $node_cache_node_uuid)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0083", code => 83, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	if (not $node_cache_name)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0083", code => 83, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# If we don't have a UUID, see if we can find one for the given host UUID.
	if (not $node_cache_uuid)
	{
		my $query = "
SELECT 
    node_cache_uuid 
FROM 
    nodes_cache 
WHERE 
    node_cache_host_uuid = ".$an->data->{sys}{use_db_fh}->quote($node_cache_host_uuid)." 
AND 
    node_cache_node_uuid = ".$an->data->{sys}{use_db_fh}->quote($node_cache_node_uuid)." 
AND 
    node_cache_name      = ".$an->data->{sys}{use_db_fh}->quote($node_cache_name)." 
;";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			$node_cache_uuid = $row->[0];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node_cache_uuid", value1 => $node_cache_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If I still don't have an anvil_uuid, we're INSERT'ing .
	if (not $node_cache_uuid)
	{
		   $node_cache_uuid = $an->Get->uuid();
		my $query           = "
INSERT INTO 
    nodes_cache 
(
    node_cache_uuid, 
    node_cache_host_uuid, 
    node_cache_node_uuid, 
    node_cache_name, 
    node_cache_data, 
    node_cache_note, 
    modified_date 
) VALUES (
    ".$an->data->{sys}{use_db_fh}->quote($node_cache_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($node_cache_host_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($node_cache_node_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($node_cache_name).", 
    ".$an->data->{sys}{use_db_fh}->quote($node_cache_data).", 
    ".$an->data->{sys}{use_db_fh}->quote($node_cache_note).", 
    ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
);
";
		$query =~ s/'NULL'/NULL/g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Query the rest of the values and see if anything changed.
		my $query = "
SELECT 
    node_cache_uuid, 
    node_cache_host_uuid, 
    node_cache_node_uuid, 
    node_cache_name, 
    node_cache_data, 
    node_cache_note 
FROM 
    nodes_cache 
WHERE 
    node_cache_uuid = ".$an->data->{sys}{use_db_fh}->quote($node_cache_uuid)." 
;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			my $old_node_cache_uuid      = $row->[0];
			my $old_node_cache_host_uuid = $row->[1];
			my $old_node_cache_node_uuid = $row->[2];
			my $old_node_cache_name      = $row->[3];
			my $old_node_cache_data      = $row->[4] ? $row->[4] : "NULL";
			my $old_node_cache_note      = $row->[5] ? $row->[5] : "NULL";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
				name1 => "old_node_cache_uuid",      value1 => $old_node_cache_uuid, 
				name2 => "old_node_cache_host_uuid", value2 => $old_node_cache_host_uuid, 
				name3 => "old_node_cache_node_uuid", value3 => $old_node_cache_node_uuid, 
				name4 => "old_node_cache_name",      value4 => $old_node_cache_name, 
				name5 => "old_node_cache_data",      value5 => $old_node_cache_data, 
				name6 => "old_node_cache_note",      value6 => $old_node_cache_note, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Anything change?
			if (($old_node_cache_uuid      ne $node_cache_uuid)      or 
			    ($old_node_cache_host_uuid ne $node_cache_host_uuid) or 
			    ($old_node_cache_node_uuid ne $node_cache_node_uuid) or 
			    ($old_node_cache_name      ne $node_cache_name)      or 
			    ($old_node_cache_data      ne $node_cache_data)      or 
			    ($old_node_cache_note      ne $node_cache_note))
			{
				# Something changed, save.
				my $query = "
UPDATE 
    nodes_cache 
SET 
    node_cache_uuid      = ".$an->data->{sys}{use_db_fh}->quote($node_cache_uuid).", 
    node_cache_host_uuid = ".$an->data->{sys}{use_db_fh}->quote($node_cache_host_uuid).", 
    node_cache_node_uuid = ".$an->data->{sys}{use_db_fh}->quote($node_cache_node_uuid).", 
    node_cache_name      = ".$an->data->{sys}{use_db_fh}->quote($node_cache_name).", 
    node_cache_data      = ".$an->data->{sys}{use_db_fh}->quote($node_cache_data).", 
    node_cache_note      = ".$an->data->{sys}{use_db_fh}->quote($node_cache_note).", 
    modified_date        = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    node_cache_uuid      = ".$an->data->{sys}{use_db_fh}->quote($node_cache_uuid)." 
";
				$query =~ s/'NULL'/NULL/g;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "query", value1 => $query, 
				}, file => $THIS_FILE, line => __LINE__});
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($node_cache_uuid);
}

# This updates (or inserts) a record in the 'notifications' table.
sub insert_or_update_notifications
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "insert_or_update_notifications" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $notify_uuid     = $parameter->{notify_uuid}     ? $parameter->{notify_uuid}     : "";
	my $notify_name     = $parameter->{notify_name}     ? $parameter->{notify_name}     : "";
	my $notify_target   = $parameter->{notify_target}   ? $parameter->{notify_target}   : "";
	my $notify_language = $parameter->{notify_language} ? $parameter->{notify_language} : "";
	my $notify_level    = $parameter->{notify_level}    ? $parameter->{notify_level}    : "";
	my $notify_units    = $parameter->{notify_units}    ? $parameter->{notify_units}    : "";
	my $notify_note     = $parameter->{notify_note}     ? $parameter->{notify_note}     : "NULL";
	if (not $notify_target)
	{
		# Throw an error and exit.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0088", code => 88, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# If we don't have a UUID, see if we can find one for the given notify server name.
	if (not $notify_uuid)
	{
		my $query = "
SELECT 
    notify_uuid 
FROM 
    notifications 
WHERE 
    notify_target = ".$an->data->{sys}{use_db_fh}->quote($notify_target)." 
;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			$notify_uuid = $row->[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "notify_uuid", value1 => $notify_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If I still don't have an notify_uuid, we're INSERT'ing .
	if (not $notify_uuid)
	{
		# INSERT
		   $notify_uuid = $an->Get->uuid();
		my $query      = "
INSERT INTO 
    notifications 
(
    notify_uuid, 
    notify_name, 
    notify_target, 
    notify_language, 
    notify_level, 
    notify_units, 
    notify_note, 
    modified_date 
) VALUES (
    ".$an->data->{sys}{use_db_fh}->quote($notify_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($notify_name).", 
    ".$an->data->{sys}{use_db_fh}->quote($notify_target).", 
    ".$an->data->{sys}{use_db_fh}->quote($notify_language).", 
    ".$an->data->{sys}{use_db_fh}->quote($notify_level).", 
    ".$an->data->{sys}{use_db_fh}->quote($notify_units).", 
    ".$an->data->{sys}{use_db_fh}->quote($notify_note).", 
    ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
);
";
		$query =~ s/'NULL'/NULL/g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Query the rest of the values and see if anything changed.
		my $query = "
SELECT 
    notify_name, 
    notify_target, 
    notify_language, 
    notify_level, 
    notify_units, 
    notify_note 
FROM 
    notifications 
WHERE 
    notify_uuid = ".$an->data->{sys}{use_db_fh}->quote($notify_uuid)." 
;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			my $old_notify_name     = $row->[0];
			my $old_notify_target   = $row->[1];
			my $old_notify_language = $row->[2];
			my $old_notify_level    = $row->[3];
			my $old_notify_units    = $row->[4];
			my $old_notify_note     = $row->[5] ? $row->[5] : "NULL";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
				name1 => "old_notify_name",     value1 => $old_notify_name, 
				name2 => "old_notify_target",   value2 => $old_notify_target, 
				name3 => "old_notify_language", value3 => $old_notify_language, 
				name4 => "old_notify_level",    value4 => $old_notify_level, 
				name5 => "old_notify_units",    value5 => $old_notify_units, 
				name6 => "old_notify_note",     value6 => $old_notify_note, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Anything change?
			if (($old_notify_name     ne $notify_name)     or 
			    ($old_notify_target   ne $notify_target)   or 
			    ($old_notify_language ne $notify_language) or 
			    ($old_notify_level    ne $notify_level)    or 
			    ($old_notify_units    ne $notify_units)    or 
			    ($old_notify_note     ne $notify_note))
			{
				# Something changed, save.
				my $query = "
UPDATE 
    notifications 
SET 
    notify_name     = ".$an->data->{sys}{use_db_fh}->quote($notify_name).", 
    notify_target   = ".$an->data->{sys}{use_db_fh}->quote($notify_target).", 
    notify_language = ".$an->data->{sys}{use_db_fh}->quote($notify_language).", 
    notify_level    = ".$an->data->{sys}{use_db_fh}->quote($notify_level).", 
    notify_units    = ".$an->data->{sys}{use_db_fh}->quote($notify_units).", 
    notify_note     = ".$an->data->{sys}{use_db_fh}->quote($notify_note).", 
    modified_date   = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    notify_uuid     = ".$an->data->{sys}{use_db_fh}->quote($notify_uuid)." 
";
				$query =~ s/'NULL'/NULL/g;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "query", value1 => $query, 
				}, file => $THIS_FILE, line => __LINE__});
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($notify_uuid);
}

# This updates (or inserts) a record in the 'owners' table.
sub insert_or_update_owners
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "insert_or_update_owners" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $owner_uuid = $parameter->{owner_uuid} ? $parameter->{owner_uuid} : "";
	my $owner_name = $parameter->{owner_name} ? $parameter->{owner_name} : "";
	my $owner_note = $parameter->{owner_note} ? $parameter->{owner_note} : "NULL";
	if (not $owner_name)
	{
		# Throw an error and exit.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0078", code => 78, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# If we don't have a UUID, see if we can find one for the given owner server name.
	if (not $owner_uuid)
	{
		my $query = "
SELECT 
    owner_uuid 
FROM 
    owners 
WHERE 
    owner_name = ".$an->data->{sys}{use_db_fh}->quote($owner_name)." 
;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			$owner_uuid = $row->[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "owner_uuid", value1 => $owner_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If I still don't have an owner_uuid, we're INSERT'ing .
	if (not $owner_uuid)
	{
		# INSERT
		   $owner_uuid = $an->Get->uuid();
		my $query      = "
INSERT INTO 
    owners 
(
    owner_uuid, 
    owner_name, 
    owner_note, 
    modified_date 
) VALUES (
    ".$an->data->{sys}{use_db_fh}->quote($owner_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($owner_name).", 
    ".$an->data->{sys}{use_db_fh}->quote($owner_note).", 
    ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
);
";
		$query =~ s/'NULL'/NULL/g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Query the rest of the values and see if anything changed.
		my $query = "
SELECT 
    owner_name, 
    owner_note 
FROM 
    owners 
WHERE 
    owner_uuid = ".$an->data->{sys}{use_db_fh}->quote($owner_uuid)." 
;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			my $old_owner_name = $row->[0];
			my $old_owner_note = $row->[1];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "old_owner_name", value1 => $old_owner_name, 
				name2 => "old_owner_note", value2 => $old_owner_note, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Anything change?
			if (($old_owner_name ne $owner_name) or 
			    ($old_owner_note ne $owner_note))
			{
				# Something changed, save.
				my $query = "
UPDATE 
    owners 
SET 
    owner_name    = ".$an->data->{sys}{use_db_fh}->quote($owner_name).", 
    owner_note    = ".$an->data->{sys}{use_db_fh}->quote($owner_note).", 
    modified_date = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    owner_uuid    = ".$an->data->{sys}{use_db_fh}->quote($owner_uuid)." 
";
				$query =~ s/'NULL'/NULL/g;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "query", value1 => $query, 
				}, file => $THIS_FILE, line => __LINE__});
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($owner_uuid);
}

# This updates (or inserts) a record in the 'recipients' table.
sub insert_or_update_recipients
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "insert_or_update_recipients" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $recipient_uuid         = $parameter->{recipient_uuid}         ? $parameter->{recipient_uuid}         : "";
	my $recipient_anvil_uuid   = $parameter->{recipient_anvil_uuid}   ? $parameter->{recipient_anvil_uuid}   : "";
	my $recipient_notify_uuid  = $parameter->{recipient_notify_uuid}  ? $parameter->{recipient_notify_uuid}  : "";
	my $recipient_notify_level = $parameter->{recipient_notify_level} ? $parameter->{recipient_notify_level} : "NULL";
	my $recipient_note         = $parameter->{recipient_note}         ? $parameter->{recipient_note}         : "NULL";
	if ((not $recipient_anvil_uuid) or (not $recipient_notify_uuid))
	{
		# Throw an error and exit.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0091", code => 91, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# If we don't have a UUID, see if we can find one for the given recipient server name.
	if (not $recipient_uuid)
	{
		my $query = "
SELECT 
    recipient_uuid 
FROM 
    recipients 
WHERE 
    recipient_anvil_uuid = ".$an->data->{sys}{use_db_fh}->quote($recipient_anvil_uuid)." 
AND 
    recipient_notify_uuid = ".$an->data->{sys}{use_db_fh}->quote($recipient_notify_uuid)." 
;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			$recipient_uuid = $row->[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "recipient_uuid", value1 => $recipient_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If I still don't have an recipient_uuid, we're INSERT'ing .
	if (not $recipient_uuid)
	{
		# INSERT
		   $recipient_uuid = $an->Get->uuid();
		my $query          = "
INSERT INTO 
    recipients 
(
    recipient_uuid, 
    recipient_anvil_uuid, 
    recipient_notify_uuid, 
    recipient_notify_level, 
    recipient_note, 
    modified_date 
) VALUES (
    ".$an->data->{sys}{use_db_fh}->quote($recipient_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($recipient_anvil_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($recipient_notify_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($recipient_notify_level).", 
    ".$an->data->{sys}{use_db_fh}->quote($recipient_note).", 
    ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
);
";
		$query =~ s/'NULL'/NULL/g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Query the rest of the values and see if anything changed.
		my $query = "
SELECT 
    recipient_anvil_uuid, 
    recipient_notify_uuid, 
    recipient_notify_level, 
    recipient_note 
FROM 
    recipients 
WHERE 
    recipient_uuid = ".$an->data->{sys}{use_db_fh}->quote($recipient_uuid)." 
;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			my $old_recipient_anvil_uuid   = $row->[0];
			my $old_recipient_notify_uuid  = $row->[1];
			my $old_recipient_notify_level = $row->[2] ? $row->[2] : "NULL";
			my $old_recipient_note         = $row->[3] ? $row->[3] : "NULL";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
				name1 => "old_recipient_anvil_uuid",   value1 => $old_recipient_anvil_uuid, 
				name2 => "old_recipient_notify_uuid",  value2 => $old_recipient_notify_uuid, 
				name3 => "old_recipient_notify_level", value3 => $old_recipient_notify_level, 
				name4 => "old_recipient_note",         value4 => $old_recipient_note, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Anything change?
			if (($old_recipient_anvil_uuid   ne $recipient_anvil_uuid)   or 
			    ($old_recipient_notify_uuid  ne $recipient_notify_uuid)  or 
			    ($old_recipient_notify_level ne $recipient_notify_level) or 
			    ($old_recipient_note         ne $recipient_note))
			{
				# Something changed, save.
				my $query = "
UPDATE 
    recipients 
SET 
    recipient_anvil_uuid   = ".$an->data->{sys}{use_db_fh}->quote($recipient_anvil_uuid).", 
    recipient_notify_uuid  = ".$an->data->{sys}{use_db_fh}->quote($recipient_notify_uuid).",  
    recipient_notify_level = ".$an->data->{sys}{use_db_fh}->quote($recipient_notify_level).", 
    recipient_note         = ".$an->data->{sys}{use_db_fh}->quote($recipient_note).", 
    modified_date          = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    recipient_uuid         = ".$an->data->{sys}{use_db_fh}->quote($recipient_uuid)." 
";
				$query =~ s/'NULL'/NULL/g;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "query", value1 => $query, 
				}, file => $THIS_FILE, line => __LINE__});
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($recipient_uuid);
}

# This updates (or inserts) a record in the 'smtp' table.
sub insert_or_update_smtp
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "insert_or_update_smtp" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $smtp_uuid           = $parameter->{smtp_uuid}           ? $parameter->{smtp_uuid}           : "";
	my $smtp_server         = $parameter->{smtp_server}         ? $parameter->{smtp_server}         : "";
	my $smtp_port           = $parameter->{smtp_port}           ? $parameter->{smtp_port}           : "";
	my $smtp_username       = $parameter->{smtp_username}       ? $parameter->{smtp_username}       : "";
	my $smtp_password       = $parameter->{smtp_password}       ? $parameter->{smtp_password}       : "";
	my $smtp_security       = $parameter->{smtp_security}       ? $parameter->{smtp_security}       : "";
	my $smtp_authentication = $parameter->{smtp_authentication} ? $parameter->{smtp_authentication} : "";
	my $smtp_helo_domain    = $parameter->{smtp_helo_domain}    ? $parameter->{smtp_helo_domain}    : "";
	my $smtp_note           = $parameter->{smtp_note}           ? $parameter->{smtp_note}           : "";
	if (not $smtp_server)
	{
		# Throw an error and exit.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0077", code => 77, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# If we don't have a UUID, see if we can find one for the given SMTP server name.
	if (not $smtp_uuid)
	{
		my $query = "
SELECT 
    smtp_uuid 
FROM 
    smtp 
WHERE 
    smtp_server = ".$an->data->{sys}{use_db_fh}->quote($smtp_server)." 
;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			$smtp_uuid = $row->[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "smtp_uuid", value1 => $smtp_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If I still don't have an smtp_uuid, we're INSERT'ing .
	if (not $smtp_uuid)
	{
		# INSERT
		   $smtp_uuid = $an->Get->uuid();
		my $query     = "
INSERT INTO 
    smtp 
(
    smtp_uuid, 
    smtp_server, 
    smtp_port, 
    smtp_username, 
    smtp_password, 
    smtp_security, 
    smtp_authentication, 
    smtp_helo_domain, 
    smtp_note, 
    modified_date 
) VALUES (
    ".$an->data->{sys}{use_db_fh}->quote($smtp_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($smtp_server).", 
    ".$an->data->{sys}{use_db_fh}->quote($smtp_port).", 
    ".$an->data->{sys}{use_db_fh}->quote($smtp_username).", 
    ".$an->data->{sys}{use_db_fh}->quote($smtp_password).", 
    ".$an->data->{sys}{use_db_fh}->quote($smtp_security).", 
    ".$an->data->{sys}{use_db_fh}->quote($smtp_authentication).", 
    ".$an->data->{sys}{use_db_fh}->quote($smtp_helo_domain).", 
    ".$an->data->{sys}{use_db_fh}->quote($smtp_note).", 
    ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
);
";
		$query =~ s/'NULL'/NULL/g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Query the rest of the values and see if anything changed.
		my $query = "
SELECT 
    smtp_server, 
    smtp_port, 
    smtp_username, 
    smtp_password, 
    smtp_security, 
    smtp_authentication, 
    smtp_helo_domain, 
    smtp_note  
FROM 
    smtp 
WHERE 
    smtp_uuid = ".$an->data->{sys}{use_db_fh}->quote($smtp_uuid)." 
;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			my $old_smtp_server         = $row->[0];
			my $old_smtp_port           = $row->[1] ? $row->[1] : "";
			my $old_smtp_username       = $row->[2] ? $row->[2] : "";
			my $old_smtp_password       = $row->[3] ? $row->[3] : "";
			my $old_smtp_security       = $row->[4];
			my $old_smtp_authentication = $row->[5];
			my $old_smtp_helo_domain    = $row->[6] ? $row->[6] : "";
			my $old_smtp_note           = $row->[7] ? $row->[7] : "NULL";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0008", message_variables => {
				name1 => "old_smtp_server",         value1 => $old_smtp_server, 
				name2 => "old_smtp_port",           value2 => $old_smtp_port, 
				name3 => "old_smtp_username",       value3 => $old_smtp_username, 
				name4 => "old_smtp_password",       value4 => $old_smtp_password, 
				name5 => "old_smtp_security",       value5 => $old_smtp_security, 
				name6 => "old_smtp_authentication", value6 => $old_smtp_authentication, 
				name7 => "old_smtp_helo_domain",    value7 => $old_smtp_helo_domain, 
				name8 => "old_smtp_note",           value8 => $old_smtp_note, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Anything change?
			if (($old_smtp_server         ne $smtp_server)         or 
			    ($old_smtp_port           ne $smtp_port)           or 
			    ($old_smtp_username       ne $smtp_username)       or 
			    ($old_smtp_password       ne $smtp_password)       or 
			    ($old_smtp_security       ne $smtp_security)       or 
			    ($old_smtp_authentication ne $smtp_authentication) or 
			    ($old_smtp_note           ne $smtp_note)           or
			    ($old_smtp_helo_domain    ne $smtp_helo_domain))
			{
				# Something changed, save.
				my $query = "
UPDATE 
    smtp 
SET 
    smtp_server         = ".$an->data->{sys}{use_db_fh}->quote($smtp_server).", 
    smtp_port           = ".$an->data->{sys}{use_db_fh}->quote($smtp_port).", 
    smtp_username       = ".$an->data->{sys}{use_db_fh}->quote($smtp_username).", 
    smtp_password       = ".$an->data->{sys}{use_db_fh}->quote($smtp_password).", 
    smtp_security       = ".$an->data->{sys}{use_db_fh}->quote($smtp_security).", 
    smtp_authentication = ".$an->data->{sys}{use_db_fh}->quote($smtp_authentication).", 
    smtp_helo_domain    = ".$an->data->{sys}{use_db_fh}->quote($smtp_helo_domain).", 
    smtp_note           = ".$an->data->{sys}{use_db_fh}->quote($smtp_note).", 
    modified_date       = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    smtp_uuid           = ".$an->data->{sys}{use_db_fh}->quote($smtp_uuid)." 
";
				$query =~ s/'NULL'/NULL/g;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "query", value1 => $query, 
				}, file => $THIS_FILE, line => __LINE__});
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($smtp_uuid);
}

### NOTE: Unlike the other methods of this type, this method can be told to update the 'variable_value' only.
###       This is so because the section, description and default columns rarely ever change. If this is set
###       and the variable name is new, an INSERT will be done the same as if it weren't set, with the unset
###       columns set to NULL.
# This updates (or inserts) a record in the 'variables' table.
sub insert_or_update_variables
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "insert_or_update_variables" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $variable_uuid        = $parameter->{variable_uuid}        ? $parameter->{variable_uuid}        : "";
	my $variable_name        = $parameter->{variable_name}        ? $parameter->{variable_name}        : "";
	my $variable_value       = $parameter->{variable_value}       ? $parameter->{variable_value}       : "NULL";
	my $variable_default     = $parameter->{variable_default}     ? $parameter->{variable_default}     : "NULL";
	my $variable_description = $parameter->{variable_description} ? $parameter->{variable_description} : "NULL";
	my $variable_section     = $parameter->{variable_section}     ? $parameter->{variable_section}     : "NULL";
	my $update_value_only    = $parameter->{update_value_only}    ? $parameter->{update_value_only}    : 1;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "variable_uuid",        value1 => $variable_uuid, 
		name2 => "variable_name",        value2 => $variable_name, 
		name3 => "variable_value",       value3 => $variable_value, 
		name4 => "variable_default",     value4 => $variable_default, 
		name5 => "variable_description", value5 => $variable_description, 
		name6 => "variable_section",     value6 => $variable_section, 
	}, file => $THIS_FILE, line => __LINE__});
	if (not $variable_name)
	{
		# Throw an error and exit.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0164", code => 164, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# If we don't have a UUID, see if we can find one for the given SMTP server name.
	if (not $variable_uuid)
	{
		my $query = "
SELECT 
    variable_uuid 
FROM 
    variables 
WHERE 
    variable_name = ".$an->data->{sys}{use_db_fh}->quote($variable_name)." 
;";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			$variable_uuid = $row->[0];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "variable_uuid", value1 => $variable_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If I still don't have an variable_uuid, we're INSERT'ing .
	if (not $variable_uuid)
	{
		# INSERT
		   $variable_uuid = $an->Get->uuid();
		my $query         = "
INSERT INTO 
    variables 
(
    variable_uuid, 
    variable_name, 
    variable_value, 
    variable_default, 
    variable_description, 
    variable_section, 
    modified_date 
) VALUES (
    ".$an->data->{sys}{use_db_fh}->quote($variable_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($variable_name).", 
    ".$an->data->{sys}{use_db_fh}->quote($variable_value).", 
    ".$an->data->{sys}{use_db_fh}->quote($variable_default).", 
    ".$an->data->{sys}{use_db_fh}->quote($variable_description).", 
    ".$an->data->{sys}{use_db_fh}->quote($variable_section).", 
    ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
);
";
		$query =~ s/'NULL'/NULL/g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Query only the value
		if ($update_value_only)
		{
			my $query = "
SELECT 
    variable_value 
FROM 
    variables 
WHERE 
    variable_uuid = ".$an->data->{sys}{use_db_fh}->quote($variable_uuid)." 
;";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "query", value1 => $query, 
			}, file => $THIS_FILE, line => __LINE__});
			
			my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
			my $count   = @{$results};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "results", value1 => $results, 
				name2 => "count",   value2 => $count
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $row (@{$results})
			{
				my $old_variable_value = $row->[0];
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "old_variable_value", value1 => $old_variable_value, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# Anything change?
				if ($old_variable_value ne $variable_value)
				{
					# Variable changed, save.
					my $query = "
UPDATE 
    variables 
SET 
    variable_value = ".$an->data->{sys}{use_db_fh}->quote($variable_value).", 
    modified_date  = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    variable_uuid  = ".$an->data->{sys}{use_db_fh}->quote($variable_uuid)." 
";
					$query =~ s/'NULL'/NULL/g;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "query", value1 => $query, 
					}, file => $THIS_FILE, line => __LINE__});
					$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
				}
			}
		}
		else
		{
			# Query the rest of the values and see if anything changed.
			my $query = "
SELECT 
    variable_name, 
    variable_value, 
    variable_default, 
    variable_description, 
    variable_section 
FROM 
    variables 
WHERE 
    variable_uuid = ".$an->data->{sys}{use_db_fh}->quote($variable_uuid)." 
;";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "query", value1 => $query, 
			}, file => $THIS_FILE, line => __LINE__});
			
			my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
			my $count   = @{$results};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "results", value1 => $results, 
				name2 => "count",   value2 => $count
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $row (@{$results})
			{
				my $old_variable_name        = $row->[0];
				my $old_variable_value       = $row->[1] ? $row->[1] : "NULL";
				my $old_variable_default     = $row->[2] ? $row->[2] : "NULL";
				my $old_variable_description = $row->[3] ? $row->[3] : "NULL";
				my $old_variable_section     = $row->[4] ? $row->[4] : "NULL";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "old_variable_name",        value1 => $old_variable_name, 
					name2 => "old_variable_value",       value2 => $old_variable_value, 
					name3 => "old_variable_default",     value3 => $old_variable_default, 
					name4 => "old_variable_description", value4 => $old_variable_description, 
					name5 => "old_variable_section",     value5 => $old_variable_section, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# Anything change?
				if (($old_variable_name        ne $variable_name)        or 
				    ($old_variable_value       ne $variable_value)       or 
				    ($old_variable_default     ne $variable_default)     or 
				    ($old_variable_description ne $variable_description) or 
				    ($old_variable_section     ne $variable_section))
				{
					# Something changed, save.
					my $query = "
UPDATE 
    variables 
SET 
    variable_name        = ".$an->data->{sys}{use_db_fh}->quote($variable_name).", 
    variable_value       = ".$an->data->{sys}{use_db_fh}->quote($variable_value).", 
    variable_default     = ".$an->data->{sys}{use_db_fh}->quote($variable_default).", 
    variable_description = ".$an->data->{sys}{use_db_fh}->quote($variable_description).", 
    variable_section     = ".$an->data->{sys}{use_db_fh}->quote($variable_section).", 
    modified_date        = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    variable_uuid        = ".$an->data->{sys}{use_db_fh}->quote($variable_uuid)." 
";
					$query =~ s/'NULL'/NULL/g;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "query", value1 => $query, 
					}, file => $THIS_FILE, line => __LINE__});
					$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
				}
			}
		}
	}
	
	return($variable_uuid);
}

# This uses the data from 'get_anvils()', 'get_nodes()' and 'get_owners()' and stores the data in 
# '$an->data->{anvils}{<uuid>}{<values>}' as used in striker.
sub parse_anvil_data
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "parse_anvil_data" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_data = $an->ScanCore->get_anvils();
	my $host_data  = $an->ScanCore->get_hosts();
	my $node_data  = $an->ScanCore->get_nodes();
	my $owner_data = $an->ScanCore->get_owners();
	my $smtp_data  = $an->ScanCore->get_smtp();
	$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
		name1 => "anvil_data", value1 => $anvil_data, 
		name2 => "host_data",  value2 => $host_data, 
		name3 => "node_data",  value3 => $node_data, 
		name4 => "owner_data", value4 => $owner_data, 
		name5 => "smtp_data",  value5 => $smtp_data, 
	}, file => $THIS_FILE, line => __LINE__});
	
	foreach my $hash_ref (@{$host_data})
	{
		# Get the host UUID
		my $host_uuid = $hash_ref->{host_uuid};
		
		$an->data->{db}{hosts}{$host_uuid}{name}           = $hash_ref->{host_name};
		$an->data->{db}{hosts}{$host_uuid}{type}           = $hash_ref->{host_type};
		$an->data->{db}{hosts}{$host_uuid}{health}         = $hash_ref->{host_health} ? $hash_ref->{host_health} : 0;
		$an->data->{db}{hosts}{$host_uuid}{emergency_stop} = $hash_ref->{host_emergency_stop};
		$an->data->{db}{hosts}{$host_uuid}{stop_reason}    = $hash_ref->{host_stop_reason};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
			name1 => "db::hosts::${host_uuid}::name",           value1 => $an->data->{db}{hosts}{$host_uuid}{name}, 
			name2 => "db::hosts::${host_uuid}::type",           value2 => $an->data->{db}{hosts}{$host_uuid}{type}, 
			name3 => "db::hosts::${host_uuid}::health",         value3 => $an->data->{db}{hosts}{$host_uuid}{health}, 
			name4 => "db::hosts::${host_uuid}::emergency_stop", value4 => $an->data->{db}{hosts}{$host_uuid}{emergency_stop}, 
			name5 => "db::hosts::${host_uuid}::stop_reason",    value5 => $an->data->{db}{hosts}{$host_uuid}{stop_reason}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	foreach my $hash_ref (@{$node_data})
	{
		# Get the node UUID.
		my $node_uuid = $hash_ref->{node_uuid};
		my $host_uuid = $hash_ref->{node_host_uuid};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "node_uuid", value1 => $node_uuid, 
			name2 => "host_uuid", value2 => $host_uuid, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Store the data
		$an->data->{db}{nodes}{$node_uuid}{anvil_uuid}  = $hash_ref->{node_anvil_uuid};
		$an->data->{db}{nodes}{$node_uuid}{remote_ip}   = $hash_ref->{node_remote_ip};
		$an->data->{db}{nodes}{$node_uuid}{remote_port} = $hash_ref->{node_remote_port};
		$an->data->{db}{nodes}{$node_uuid}{note}        = $hash_ref->{node_note};
		$an->data->{db}{nodes}{$node_uuid}{bcn_ip}      = $hash_ref->{node_bcn};
		$an->data->{db}{nodes}{$node_uuid}{sn_ip}       = $hash_ref->{node_sn};
		$an->data->{db}{nodes}{$node_uuid}{ifn_ip}      = $hash_ref->{node_ifn};
		$an->data->{db}{nodes}{$node_uuid}{host_uuid}   = $host_uuid;
		$an->data->{db}{nodes}{$node_uuid}{password}    = $hash_ref->{node_password};
		
		# Push in the host data
		$an->data->{db}{nodes}{$node_uuid}{name}           = $an->data->{db}{hosts}{$host_uuid}{name};
		$an->data->{db}{nodes}{$node_uuid}{type}           = $an->data->{db}{hosts}{$host_uuid}{type};
		$an->data->{db}{nodes}{$node_uuid}{health}         = $an->data->{db}{hosts}{$host_uuid}{health};
		$an->data->{db}{nodes}{$node_uuid}{emergency_stop} = $an->data->{db}{hosts}{$host_uuid}{emergency_stop};
		$an->data->{db}{nodes}{$node_uuid}{stop_reason}    = $an->data->{db}{hosts}{$host_uuid}{stop_reason};
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0013", message_variables => {
			name1  => "db::nodes::${node_uuid}::anvil_uuid",     value1  => $an->data->{db}{nodes}{$node_uuid}{anvil_uuid}, 
			name2  => "db::nodes::${node_uuid}::remote_ip",      value2  => $an->data->{db}{nodes}{$node_uuid}{remote_ip}, 
			name3  => "db::nodes::${node_uuid}::remote_port",    value3  => $an->data->{db}{nodes}{$node_uuid}{remote_port}, 
			name4  => "db::nodes::${node_uuid}::note",           value4  => $an->data->{db}{nodes}{$node_uuid}{note}, 
			name5  => "db::nodes::${node_uuid}::bcn_ip",         value5  => $an->data->{db}{nodes}{$node_uuid}{bcn_ip}, 
			name6  => "db::nodes::${node_uuid}::sn_ip",          value6  => $an->data->{db}{nodes}{$node_uuid}{sn_ip}, 
			name7  => "db::nodes::${node_uuid}::ifn_ip",         value7  => $an->data->{db}{nodes}{$node_uuid}{ifn_ip}, 
			name8  => "db::nodes::${node_uuid}::host_uuid",      value8  => $an->data->{db}{nodes}{$node_uuid}{host_uuid}, 
			name9  => "db::nodes::${node_uuid}::name",           value9  => $an->data->{db}{nodes}{$node_uuid}{name}, 
			name10 => "db::nodes::${node_uuid}::type",           value10 => $an->data->{db}{nodes}{$node_uuid}{type}, 
			name11 => "db::nodes::${node_uuid}::health",         value11 => $an->data->{db}{nodes}{$node_uuid}{health}, 
			name12 => "db::nodes::${node_uuid}::emergency_stop", value12 => $an->data->{db}{nodes}{$node_uuid}{emergency_stop}, 
			name13 => "db::nodes::${node_uuid}::stop_reason",    value13 => $an->data->{db}{nodes}{$node_uuid}{stop_reason}, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "db::nodes::${node_uuid}::password", value1 => $an->data->{db}{nodes}{$node_uuid}{password}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	foreach my $hash_ref (@{$owner_data})
	{
		# Get the owner UUID
		my $owner_uuid = $hash_ref->{owner_uuid};
		
		# Store the data
		$an->data->{db}{owners}{$owner_uuid}{name} = $hash_ref->{owner_name};
		$an->data->{db}{owners}{$owner_uuid}{note} = $hash_ref->{owner_note};
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "db::owners::${owner_uuid}::name", value1 => $an->data->{db}{owners}{$owner_uuid}{name}, 
			name2 => "db::owners::${owner_uuid}::note", value2 => $an->data->{db}{owners}{$owner_uuid}{note}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	foreach my $hash_ref (@{$smtp_data})
	{
		# Get the SMTP UUID
		my $smtp_uuid = $hash_ref->{smtp_uuid};
		
		# Store the data
		$an->data->{db}{smtp}{$smtp_uuid}{server}         = $hash_ref->{smtp_uuid};
		$an->data->{db}{smtp}{$smtp_uuid}{port}           = $hash_ref->{smtp_port};
		$an->data->{db}{smtp}{$smtp_uuid}{username}       = $hash_ref->{smtp_username};
		$an->data->{db}{smtp}{$smtp_uuid}{security}       = $hash_ref->{smtp_security};
		$an->data->{db}{smtp}{$smtp_uuid}{authentication} = $hash_ref->{smtp_authentication};
		$an->data->{db}{smtp}{$smtp_uuid}{helo_domain}    = $hash_ref->{smtp_helo_domain};
		$an->data->{db}{smtp}{$smtp_uuid}{password}       = $hash_ref->{smtp_password};
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
			name1 => "db::smtp::${smtp_uuid}::server",         value1 => $an->data->{db}{smtp}{$smtp_uuid}{server}, 
			name2 => "db::smtp::${smtp_uuid}::port",           value2 => $an->data->{db}{smtp}{$smtp_uuid}{port}, 
			name3 => "db::smtp::${smtp_uuid}::username",       value3 => $an->data->{db}{smtp}{$smtp_uuid}{username}, 
			name4 => "db::smtp::${smtp_uuid}::security",       value4 => $an->data->{db}{smtp}{$smtp_uuid}{security}, 
			name5 => "db::smtp::${smtp_uuid}::authentication", value5 => $an->data->{db}{smtp}{$smtp_uuid}{authentication}, 
			name6 => "db::smtp::${smtp_uuid}::helo_domain",    value6 => $an->data->{db}{smtp}{$smtp_uuid}{helo_domain}, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "db::smtp::${smtp_uuid}::password", value1 => $an->data->{db}{smtp}{$smtp_uuid}{password}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# If no 'cgi::anvil_uuid' has been set and if only one anvil is defined, we will auto-select it.
	my $anvil_count = @{$anvil_data};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil_count", value1 => $anvil_count, 
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $hash_ref (@{$anvil_data})
	{
		# Get the Anvil! UUID and associates UUIDs.
		my $anvil_uuid       = $hash_ref->{anvil_uuid};
		my $anvil_name       = $hash_ref->{anvil_name};
		my $anvil_owner_uuid = $hash_ref->{anvil_owner_uuid};
		my $anvil_smtp_uuid  = $hash_ref->{anvil_smtp_uuid};
		
		if (($anvil_count == 1) && (not $an->data->{cgi}{anvil_uuid}))
		{
			$an->data->{cgi}{anvil_uuid} = $anvil_uuid;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "cgi::anvil_uuid", value1 => $an->data->{cgi}{anvil_uuid}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Store the data
		$an->data->{anvils}{$anvil_uuid}{name}        = $hash_ref->{anvil_name};
		$an->data->{anvils}{$anvil_uuid}{description} = $hash_ref->{anvil_description};
		$an->data->{anvils}{$anvil_uuid}{note}        = $hash_ref->{anvil_note};
		$an->data->{anvils}{$anvil_uuid}{password}    = $hash_ref->{anvil_password};
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "anvils::${anvil_uuid}::name",        value1 => $an->data->{anvils}{$anvil_uuid}{name}, 
			name2 => "anvils::${anvil_uuid}::description", value2 => $an->data->{anvils}{$anvil_uuid}{description}, 
			name3 => "anvils::${anvil_uuid}::note",        value3 => $an->data->{anvils}{$anvil_uuid}{note}, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "anvils::${anvil_uuid}::password", value1 => $an->data->{anvils}{$anvil_uuid}{password}, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# This will be used later to display Anvil! systems to users in a sorted list.
		$an->data->{sorted}{anvils}{$anvil_name}{uuid} = $anvil_uuid;
		
		# Find the nodes associated with this Anvil!
		my $nodes = [];
		foreach my $node_uuid (keys %{$an->data->{db}{nodes}})
		{
			# Is this node related to this Anvil! system?
			my $node_anvil_uuid = $an->data->{db}{nodes}{$node_uuid}{anvil_uuid};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "node_uuid",       value1 => $node_uuid, 
				name2 => "node_anvil_uuid", value2 => $node_anvil_uuid, 
				name3 => "anvil_uuid",      value3 => $anvil_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($node_anvil_uuid eq $anvil_uuid)
			{
				my $node_name   = $an->data->{db}{nodes}{$node_uuid}{name};
				my $node_string = "$node_name,$node_uuid";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "node_string", value1 => $node_string, 
				}, file => $THIS_FILE, line => __LINE__});
				
				push @{$nodes}, $node_string;
			}
		}
		# Sort the nodes by their name and pull out their UUID.
		my $processed_node1 = 0;
		foreach my $node (sort {$a cmp $b} @{$nodes})
		{
			my ($node_name, $node_uuid) = ($node =~ /^(.*?),(.*)$/);
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "node_name", value1 => $node_name, 
				name2 => "node_uuid", value2 => $node_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
			my $node_key = "node1";
			if ($processed_node1)
			{
				$node_key = "node2";
			}
			else
			{
				$processed_node1 = 1;
			}
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "node_key", value1 => $node_key, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Store this so that we can later access the data as 'node1' or 'node2'
			$an->data->{db}{nodes}{$node_uuid}{node_key} = $node_key;
			$an->data->{anvils}{$anvil_uuid}{$node_key}  = {
				uuid           => $node_uuid,
				name           => $an->data->{db}{nodes}{$node_uuid}{name}, 
				remote_ip      => $an->data->{db}{nodes}{$node_uuid}{remote_ip}, 
				remote_port    => $an->data->{db}{nodes}{$node_uuid}{remote_port}, 
				note           => $an->data->{db}{nodes}{$node_uuid}{note}, 
				bcn_ip         => $an->data->{db}{nodes}{$node_uuid}{bcn_ip}, 
				sn_ip          => $an->data->{db}{nodes}{$node_uuid}{sn_ip}, 
				ifn_ip         => $an->data->{db}{nodes}{$node_uuid}{ifn_ip}, 
				type           => $an->data->{db}{nodes}{$node_uuid}{type}, 
				health         => $an->data->{db}{nodes}{$node_uuid}{health}, 
				emergency_stop => $an->data->{db}{nodes}{$node_uuid}{emergency_stop}, 
				stop_reason    => $an->data->{db}{nodes}{$node_uuid}{stop_reason}, 
				use_ip         => "",        # This will be set to the IP/name we successfully connect to the node with.
				use_port       => 22,        # This will switch to the remote_port if we use the remote_ip to access.
				online         => 0,         # This will be set to '1' if we successfully access the node
				power          => "unknown", # This will be set to 'on' or 'off' when we access it or based on the 'power check command' output
				host_uuid      => $an->data->{db}{nodes}{$node_uuid}{host_uuid}, 
				password       => $an->data->{db}{nodes}{$node_uuid}{password} ? $an->data->{db}{nodes}{$node_uuid}{password} : $an->data->{anvils}{$anvil_uuid}{password}, 
			};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0017", message_variables => {
				name1  => "anvils::${anvil_uuid}::${node_key}::uuid",           value1  => $an->data->{anvils}{$anvil_uuid}{$node_key}{uuid}, 
				name2  => "anvils::${anvil_uuid}::${node_key}::name",           value2  => $an->data->{anvils}{$anvil_uuid}{$node_key}{name}, 
				name3  => "anvils::${anvil_uuid}::${node_key}::remote_ip",      value3  => $an->data->{anvils}{$anvil_uuid}{$node_key}{remote_ip}, 
				name4  => "anvils::${anvil_uuid}::${node_key}::remote_port",    value4  => $an->data->{anvils}{$anvil_uuid}{$node_key}{remote_port}, 
				name5  => "anvils::${anvil_uuid}::${node_key}::note",           value5  => $an->data->{anvils}{$anvil_uuid}{$node_key}{note}, 
				name6  => "anvils::${anvil_uuid}::${node_key}::bcn_ip",         value6  => $an->data->{anvils}{$anvil_uuid}{$node_key}{bcn_ip}, 
				name7  => "anvils::${anvil_uuid}::${node_key}::sn_ip",          value7  => $an->data->{anvils}{$anvil_uuid}{$node_key}{sn_ip}, 
				name8  => "anvils::${anvil_uuid}::${node_key}::ifn_ip",         value8  => $an->data->{anvils}{$anvil_uuid}{$node_key}{ifn_ip}, 
				name9  => "anvils::${anvil_uuid}::${node_key}::type",           value9  => $an->data->{anvils}{$anvil_uuid}{$node_key}{type}, 
				name10 => "anvils::${anvil_uuid}::${node_key}::health",         value10 => $an->data->{anvils}{$anvil_uuid}{$node_key}{health}, 
				name11 => "anvils::${anvil_uuid}::${node_key}::emergency_stop", value11 => $an->data->{anvils}{$anvil_uuid}{$node_key}{emergency_stop}, 
				name12 => "anvils::${anvil_uuid}::${node_key}::stop_reason",    value12 => $an->data->{anvils}{$anvil_uuid}{$node_key}{stop_reason}, 
				name13 => "anvils::${anvil_uuid}::${node_key}::use_ip",         value13 => $an->data->{anvils}{$anvil_uuid}{$node_key}{use_ip}, 
				name14 => "anvils::${anvil_uuid}::${node_key}::use_port",       value14 => $an->data->{anvils}{$anvil_uuid}{$node_key}{use_port}, 
				name15 => "anvils::${anvil_uuid}::${node_key}::online",         value15 => $an->data->{anvils}{$anvil_uuid}{$node_key}{online}, 
				name16 => "anvils::${anvil_uuid}::${node_key}::power",          value16 => $an->data->{anvils}{$anvil_uuid}{$node_key}{power}, 
				name17 => "anvils::${anvil_uuid}::${node_key}::host_uuid",      value17 => $an->data->{anvils}{$anvil_uuid}{$node_key}{host_uuid}, 
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
				name1 => "anvils::${anvil_uuid}::${node_key}::password", value1 => $an->data->{anvils}{$anvil_uuid}{$node_key}{password}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Store the owner data.
		foreach my $owner_uuid (keys %{$an->data->{db}{owners}})
		{
			if ($anvil_owner_uuid eq $owner_uuid)
			{
				$an->data->{anvils}{$anvil_uuid}{owner}{name} = $an->data->{db}{owners}{$owner_uuid}{name};
				$an->data->{anvils}{$anvil_uuid}{owner}{note} = $an->data->{db}{owners}{$owner_uuid}{note};
				
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "anvils::${anvil_uuid}::owner::name", value1 => $an->data->{anvils}{$anvil_uuid}{owner}{name}, 
					name2 => "anvils::${anvil_uuid}::owner::note", value2 => $an->data->{anvils}{$anvil_uuid}{owner}{note}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Store the SMTP mail server info.
		foreach my $smtp_uuid (keys %{$an->data->{db}{smtp}})
		{
			if ($anvil_smtp_uuid eq $smtp_uuid)
			{
				$an->data->{anvils}{$anvil_uuid}{smtp}{server}         = $an->data->{db}{smtp}{$smtp_uuid}{server};
				$an->data->{anvils}{$anvil_uuid}{smtp}{port}           = $an->data->{db}{smtp}{$smtp_uuid}{port};
				$an->data->{anvils}{$anvil_uuid}{smtp}{username}       = $an->data->{db}{smtp}{$smtp_uuid}{username};
				$an->data->{anvils}{$anvil_uuid}{smtp}{security}       = $an->data->{db}{smtp}{$smtp_uuid}{security};
				$an->data->{anvils}{$anvil_uuid}{smtp}{authentication} = $an->data->{db}{smtp}{$smtp_uuid}{authentication};
				$an->data->{anvils}{$anvil_uuid}{smtp}{helo_domain}    = $an->data->{db}{smtp}{$smtp_uuid}{helo_domain};
				$an->data->{anvils}{$anvil_uuid}{smtp}{password}       = $an->data->{db}{smtp}{$smtp_uuid}{password};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
					name1 => "anvils::${anvil_uuid}::smtp::server",         value1 => $an->data->{anvils}{$anvil_uuid}{smtp}{server}, 
					name2 => "anvils::${anvil_uuid}::smtp::port",           value2 => $an->data->{anvils}{$anvil_uuid}{smtp}{port}, 
					name3 => "anvils::${anvil_uuid}::smtp::username",       value3 => $an->data->{anvils}{$anvil_uuid}{smtp}{username}, 
					name4 => "anvils::${anvil_uuid}::smtp::security",       value4 => $an->data->{anvils}{$anvil_uuid}{smtp}{security}, 
					name5 => "anvils::${anvil_uuid}::smtp::authentication", value5 => $an->data->{anvils}{$anvil_uuid}{smtp}{authentication}, 
					name6 => "anvils::${anvil_uuid}::smtp::helo_domain",    value6 => $an->data->{anvils}{$anvil_uuid}{smtp}{helo_domain}, 
				}, file => $THIS_FILE, line => __LINE__});
				$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
					name1 => "anvils::${anvil_uuid}::smtp::password", value1 => $an->data->{anvils}{$anvil_uuid}{smtp}{password}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return(0);
}

# This parses an Install Manifest
sub parse_install_manifest
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "parse_install_manifest" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### TODO: Support getting a UUID
	if (not $parameter->{uuid})
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0093", code => 93, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	my $manifest_data = "";
	my $return        = $an->ScanCore->get_manifests();
	foreach my $hash_ref (@{$return})
	{
		if ($parameter->{uuid} eq $hash_ref->{manifest_uuid})
		{
			$manifest_data = $hash_ref->{manifest_data};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "manifest_data", value1 => $manifest_data,
			}, file => $THIS_FILE, line => __LINE__});
			last;
		}
	}
	
	if (not $manifest_data)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0094", message_variables => { uuid => $parameter->{uuid} }, code => 94, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	my $uuid = $parameter->{uuid};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "uuid", value1 => $uuid,
	}, file => $THIS_FILE, line => __LINE__});
	
	# TODO: Verify the XML is sane (xmlint?)
	my $xml  = XML::Simple->new();
	my $data = $xml->XMLin($manifest_data, KeyAttr => {node => 'name'}, ForceArray => 1);
	
	# Nodes.
	foreach my $node (keys %{$data->{node}})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node", value1 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $a (keys %{$data->{node}{$node}})
		{
			if ($a eq "interfaces")
			{
				foreach my $b (keys %{$data->{node}{$node}{interfaces}->[0]})
				{
					foreach my $c (@{$data->{node}{$node}{interfaces}->[0]->{$b}})
					{
						my $name = $c->{name} ? $c->{name} : "";
						my $mac  = $c->{mac}  ? $c->{mac}  : "";
						$an->data->{install_manifest}{$uuid}{node}{$node}{interface}{$name}{mac} = "";
						if (($mac) && ($mac =~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i))
						{
							$an->data->{install_manifest}{$uuid}{node}{$node}{interface}{$name}{mac} = $mac;
						}
						elsif ($mac)
						{
							# Malformed MAC
							$an->Log->entry({log_level => 3, message_key => "tools_log_0027", message_variables => {
								uuid => $uuid, 
								node => $node, 
								name => $name, 
								mac  => $mac, 
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
				}
			}
			elsif ($a eq "network")
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "a",                                 value1 => $a,
					name2 => "data->node::${node}::network->[0]", value2 => $data->{node}{$node}{network}->[0],
				}, file => $THIS_FILE, line => __LINE__});
				foreach my $network (keys %{$data->{node}{$node}{network}->[0]})
				{
					my $ip = $data->{node}{$node}{network}->[0]->{$network}->[0]->{ip};
					$an->data->{install_manifest}{$uuid}{node}{$node}{network}{$network}{ip} = $ip ? $ip : "";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name3 => "install_manifest::${uuid}::node::${node}::network::${network}::ip", value1 => $an->data->{install_manifest}{$uuid}{node}{$node}{network}{$network}{ip},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($a eq "pdu")
			{
				foreach my $b (@{$data->{node}{$node}{pdu}->[0]->{on}})
				{
					my $reference       = $b->{reference};
					my $name            = $b->{name};
					my $port            = $b->{port};
					my $user            = $b->{user};
					my $password        = $b->{password};
					my $password_script = $b->{password_script};
					
					$an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$reference}{name}            = $name            ? $name            : "";
					$an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$reference}{port}            = $port            ? $port            : ""; 
					$an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$reference}{user}            = $user            ? $user            : "";
					$an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$reference}{password}        = $password        ? $password        : "";
					$an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$reference}{password_script} = $password_script ? $password_script : "";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
						name1 => "install_manifest::${uuid}::node::${node}::pdu::${reference}::name",            value1 => $an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$reference}{name},
						name2 => "install_manifest::${uuid}::node::${node}::pdu::${reference}::port",            value2 => $an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$reference}{port},
						name3 => "install_manifest::${uuid}::node::${node}::pdu::${reference}::user",            value3 => $an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$reference}{user},
						name4 => "install_manifest::${uuid}::node::${node}::pdu::${reference}::password_script", value4 => $an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$reference}{password_script},
					}, file => $THIS_FILE, line => __LINE__});
					$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
						name1 => "install_manifest::${uuid}::node::${node}::pdu::${reference}::password", value1 => $an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$reference}{password},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($a eq "kvm")
			{
				foreach my $b (@{$data->{node}{$node}{kvm}->[0]->{on}})
				{
					my $reference       = $b->{reference};
					my $name            = $b->{name};
					my $port            = $b->{port};
					my $user            = $b->{user};
					my $password        = $b->{password};
					my $password_script = $b->{password_script};
					
					$an->data->{install_manifest}{$uuid}{node}{$node}{kvm}{$reference}{name}            = $name            ? $name            : "";
					$an->data->{install_manifest}{$uuid}{node}{$node}{kvm}{$reference}{port}            = $port            ? $port            : "";
					$an->data->{install_manifest}{$uuid}{node}{$node}{kvm}{$reference}{user}            = $user            ? $user            : "";
					$an->data->{install_manifest}{$uuid}{node}{$node}{kvm}{$reference}{password}        = $password        ? $password        : "";
					$an->data->{install_manifest}{$uuid}{node}{$node}{kvm}{$reference}{password_script} = $password_script ? $password_script : "";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
						name1 => "install_manifest::${uuid}::node::${node}::kvm::${reference}::name",            value3 => $an->data->{install_manifest}{$uuid}{node}{$node}{kvm}{$reference}{name},
						name2 => "install_manifest::${uuid}::node::${node}::kvm::${reference}::port",            value4 => $an->data->{install_manifest}{$uuid}{node}{$node}{kvm}{$reference}{port},
						name3 => "install_manifest::${uuid}::node::${node}::kvm::${reference}::user",            value5 => $an->data->{install_manifest}{$uuid}{node}{$node}{kvm}{$reference}{user},
						name4 => "install_manifest::${uuid}::node::${node}::kvm::${reference}::password_script", value7 => $an->data->{install_manifest}{$uuid}{node}{$node}{kvm}{$reference}{password_script},
					}, file => $THIS_FILE, line => __LINE__});
					$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
						name1 => "install_manifest::${uuid}::node::${node}::kvm::${reference}::password", value1 => $an->data->{install_manifest}{$uuid}{node}{$node}{kvm}{$reference}{password},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($a eq "ipmi")
			{
				foreach my $b (@{$data->{node}{$node}{ipmi}->[0]->{on}})
				{
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "b",    value1 => $b,
						name2 => "node", value2 => $node,
					}, file => $THIS_FILE, line => __LINE__});
					foreach my $key (keys %{$b})
					{
						$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
							name1 => "b",       value1 => $b,
							name2 => "node",    value2 => $node,
							name3 => "b->$key", value3 => $b->{$key}, 
						}, file => $THIS_FILE, line => __LINE__});
					}
					my $reference       = $b->{reference};
					my $name            = $b->{name};
					my $ip              = $b->{ip};
					my $gateway         = $b->{gateway};
					my $netmask         = $b->{netmask};
					my $user            = $b->{user};
					my $password        = $b->{password};
					my $password_script = $b->{password_script};
					
					# If the password is more than 16 characters long, truncate it so 
					# that nodes with IPMI v1.5 don't spazz out.
					$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
						name1 => "password", value1 => $password,
						name2 => "length",   value2 => length($password),
					}, file => $THIS_FILE, line => __LINE__});
					if (length($password) > 16)
					{
						$password = substr($password, 0, 16);
						$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
							name1 => "password", value1 => $password,
							name2 => "length",   value2 => length($password),
						}, file => $THIS_FILE, line => __LINE__});
					}
					
					$an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{name}            = $name            ? $name            : "";
					$an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{ip}              = $ip              ? $ip              : "";
					$an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{gateway}         = $gateway         ? $gateway         : "";
					$an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{netmask}         = $netmask         ? $netmask         : "";
					$an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{user}            = $user            ? $user            : "";
					$an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{password}        = $password        ? $password        : "";
					$an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{password_script} = $password_script ? $password_script : "";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
						name1 => "install_manifest::${uuid}::node::${node}::ipmi::${reference}::name",            value1 => $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{name},
						name2 => "install_manifest::${uuid}::node::${node}::ipmi::${reference}::ip",              value2 => $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{ip},
						name3 => "install_manifest::${uuid}::node::${node}::ipmi::${reference}::netmask",         value3 => $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{netmask}, 
						name4 => "install_manifest::${uuid}::node::${node}::ipmi::${reference}::gateway",         value4 => $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{gateway},
						name5 => "install_manifest::${uuid}::node::${node}::ipmi::${reference}::user",            value5 => $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{user},
						name6 => "install_manifest::${uuid}::node::${node}::ipmi::${reference}::password_script", value6 => $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{password_script},
					}, file => $THIS_FILE, line => __LINE__});
					$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
						name1 => "install_manifest::${uuid}::node::${node}::ipmi::${reference}::password", value1 => $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{password},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($a eq "uuid")
			{
				my $node_uuid = $data->{node}{$node}{uuid};
				$an->data->{install_manifest}{$uuid}{node}{$node}{uuid} = $node_uuid ? $node_uuid : "";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "install_manifest::${uuid}::node::${node}::uuid", value1 => $an->data->{install_manifest}{$uuid}{node}{$node}{uuid},
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# What's this?
				$an->Log->entry({log_level => 3, message_key => "tools_log_0028", message_variables => {
					node    => $node, 
					uuid    => $uuid, 
					element => $b, 
				}, file => $THIS_FILE, line => __LINE__});
				foreach my $b (@{$data->{node}{$node}{$a}})
				{
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "data->node::${node}::${a}->[${b}]", value1 => $data->{node}{$node}{$a}->[$b],
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
	}
	
	# The common variables
	foreach my $a (@{$data->{common}})
	{
		foreach my $b (keys %{$a})
		{
			# Pull out and record the 'anvil'
			if ($b eq "anvil")
			{
				# Only ever one entry in the array reference, so we can safely dereference 
				# immediately.
				my $prefix           = $a->{$b}->[0]->{prefix};
				my $domain           = $a->{$b}->[0]->{domain};
				my $sequence         = $a->{$b}->[0]->{sequence};
				my $password         = $a->{$b}->[0]->{password};
				my $striker_user     = $a->{$b}->[0]->{striker_user};
				my $striker_database = $a->{$b}->[0]->{striker_database};
				$an->data->{install_manifest}{$uuid}{common}{anvil}{prefix}           = $prefix           ? $prefix           : "";
				$an->data->{install_manifest}{$uuid}{common}{anvil}{domain}           = $domain           ? $domain           : "";
				$an->data->{install_manifest}{$uuid}{common}{anvil}{sequence}         = $sequence         ? $sequence         : "";
				$an->data->{install_manifest}{$uuid}{common}{anvil}{password}         = $password         ? $password         : "";
				$an->data->{install_manifest}{$uuid}{common}{anvil}{striker_user}     = $striker_user     ? $striker_user     : "";
				$an->data->{install_manifest}{$uuid}{common}{anvil}{striker_database} = $striker_database ? $striker_database : "";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "install_manifest::${uuid}::common::anvil::prefix",           value1 => $an->data->{install_manifest}{$uuid}{common}{anvil}{prefix},
					name2 => "install_manifest::${uuid}::common::anvil::domain",           value2 => $an->data->{install_manifest}{$uuid}{common}{anvil}{domain},
					name3 => "install_manifest::${uuid}::common::anvil::sequence",         value3 => $an->data->{install_manifest}{$uuid}{common}{anvil}{sequence},
					name4 => "install_manifest::${uuid}::common::anvil::striker_user",     value4 => $an->data->{install_manifest}{$uuid}{common}{anvil}{striker_user},
					name5 => "install_manifest::${uuid}::common::anvil::striker_database", value5 => $an->data->{install_manifest}{$uuid}{common}{anvil}{striker_database},
				}, file => $THIS_FILE, line => __LINE__});
				$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
					name1 => "install_manifest::${uuid}::common::anvil::password", value1 => $an->data->{install_manifest}{$uuid}{common}{anvil}{password},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($b eq "cluster")
			{
				# Cluster Name
				my $name = $a->{$b}->[0]->{name};
				$an->data->{install_manifest}{$uuid}{common}{cluster}{name} = $name ? $name : "";
				
				# Fencing stuff
				my $post_join_delay = $a->{$b}->[0]->{fence}->[0]->{post_join_delay};
				my $order           = $a->{$b}->[0]->{fence}->[0]->{order};
				my $delay           = $a->{$b}->[0]->{fence}->[0]->{delay};
				my $delay_node      = $a->{$b}->[0]->{fence}->[0]->{delay_node};
				$an->data->{install_manifest}{$uuid}{common}{cluster}{fence}{post_join_delay} = $post_join_delay ? $post_join_delay : "";
				$an->data->{install_manifest}{$uuid}{common}{cluster}{fence}{order}           = $order           ? $order           : "";
				$an->data->{install_manifest}{$uuid}{common}{cluster}{fence}{delay}           = $delay           ? $delay           : "";
				$an->data->{install_manifest}{$uuid}{common}{cluster}{fence}{delay_node}      = $delay_node      ? $delay_node      : "";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
					name1 => "install_manifest::${uuid}::common::cluster::fence::post_join_delay", value1 => $an->data->{install_manifest}{$uuid}{common}{cluster}{fence}{post_join_delay},
					name2 => "install_manifest::${uuid}::common::cluster::fence::order",           value2 => $an->data->{install_manifest}{$uuid}{common}{cluster}{fence}{order},
					name3 => "install_manifest::${uuid}::common::cluster::fence::delay",           value3 => $an->data->{install_manifest}{$uuid}{common}{cluster}{fence}{delay},
					name4 => "install_manifest::${uuid}::common::cluster::fence::delay_node",      value4 => $an->data->{install_manifest}{$uuid}{common}{cluster}{fence}{delay_node},
				}, file => $THIS_FILE, line => __LINE__});
			}
			### This is currently not used, may not have a use-case in the future.
			elsif ($b eq "file")
			{
				foreach my $c (@{$a->{$b}})
				{
					my $name    = $c->{name};
					my $mode    = $c->{mode};
					my $owner   = $c->{owner};
					my $group   = $c->{group};
					my $content = $c->{content};
					
					$an->data->{install_manifest}{$uuid}{common}{file}{$name}{mode}    = $mode    ? $mode    : "";
					$an->data->{install_manifest}{$uuid}{common}{file}{$name}{owner}   = $owner   ? $owner   : "";
					$an->data->{install_manifest}{$uuid}{common}{file}{$name}{group}   = $group   ? $group   : "";
					$an->data->{install_manifest}{$uuid}{common}{file}{$name}{content} = $content ? $content : "";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
						name1 => "install_manifest::${uuid}::common::file::${name}::mode",    value1 => $an->data->{install_manifest}{$uuid}{common}{file}{$name}{mode},
						name2 => "install_manifest::${uuid}::common::file::${name}::owner",   value2 => $an->data->{install_manifest}{$uuid}{common}{file}{$name}{owner},
						name3 => "install_manifest::${uuid}::common::file::${name}::group",   value3 => $an->data->{install_manifest}{$uuid}{common}{file}{$name}{group},
						name4 => "install_manifest::${uuid}::common::file::${name}::content", value4 => $an->data->{install_manifest}{$uuid}{common}{file}{$name}{content},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($b eq "iptables")
			{
				my $ports = $a->{$b}->[0]->{vnc}->[0]->{ports};
				$an->data->{install_manifest}{$uuid}{common}{cluster}{iptables}{vnc_ports} = $ports ? $ports : 100;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "install_manifest::${uuid}::common::cluster::iptables::vnc_ports", value1 => $an->data->{install_manifest}{$uuid}{common}{cluster}{iptables}{vnc_ports},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($b eq "servers")
			{
				my $use_spice_graphics = $a->{$b}->[0]->{provision}->[0]->{use_spice_graphics};
				$an->data->{install_manifest}{$uuid}{common}{cluster}{servers}{provision}{use_spice_graphics} = $use_spice_graphics ? $use_spice_graphics : "0";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "install_manifest::${uuid}::common::cluster::servers::provision::use_spice_graphics", value1 => $an->data->{install_manifest}{$uuid}{common}{cluster}{servers}{provision}{use_spice_graphics},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($b eq "tools")
			{
				# Used to control which Anvil! tools are used and how to use them.
				my $anvil_safe_start   = $a->{$b}->[0]->{'use'}->[0]->{'anvil-safe-start'};
				my $anvil_kick_apc_ups = $a->{$b}->[0]->{'use'}->[0]->{'anvil-kick-apc-ups'};
				my $scancore           = $a->{$b}->[0]->{'use'}->[0]->{scancore};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "anvil-safe-start",   value1 => $anvil_safe_start,
					name2 => "anvil-kick-apc-ups", value2 => $anvil_kick_apc_ups,
					name3 => "scancore",           value3 => $scancore,
				}, file => $THIS_FILE, line => __LINE__});
				
				# Make sure we're using digits.
				$anvil_safe_start   =~ s/true/1/i;
				$anvil_safe_start   =~ s/yes/1/i;
				$anvil_safe_start   =~ s/false/0/i;
				$anvil_safe_start   =~ s/no/0/i;
				
				$anvil_kick_apc_ups =~ s/true/1/i;  
				$anvil_kick_apc_ups =~ s/yes/1/i;
				$anvil_kick_apc_ups =~ s/false/0/i; 
				$anvil_kick_apc_ups =~ s/no/0/i;
				
				$scancore           =~ s/true/1/i;  
				$scancore           =~ s/yes/1/i;
				$scancore           =~ s/false/0/i; 
				$scancore           =~ s/no/0/i;
				
				$an->data->{install_manifest}{$uuid}{common}{cluster}{tools}{'use'}{'anvil-safe-start'}   = defined $anvil_safe_start   ? $anvil_safe_start   : $an->data->{sys}{install_manifest}{'default'}{'use_anvil-safe-start'};
				$an->data->{install_manifest}{$uuid}{common}{cluster}{tools}{'use'}{'anvil-kick-apc-ups'} = defined $anvil_kick_apc_ups ? $anvil_kick_apc_ups : $an->data->{sys}{install_manifest}{'default'}{'use_anvil-kick-apc-ups'};
				$an->data->{install_manifest}{$uuid}{common}{cluster}{tools}{'use'}{scancore}             = defined $scancore           ? $scancore           : $an->data->{sys}{install_manifest}{'default'}{use_scancore};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "install_manifest::${uuid}::common::cluster::tools::use::anvil-safe-start",   value1 => $an->data->{install_manifest}{$uuid}{common}{cluster}{tools}{'use'}{'anvil-safe-start'},
					name2 => "install_manifest::${uuid}::common::cluster::tools::use::anvil-kick-apc-ups", value2 => $an->data->{install_manifest}{$uuid}{common}{cluster}{tools}{'use'}{'anvil-kick-apc-ups'},
					name3 => "install_manifest::${uuid}::common::cluster::tools::use::scancore",           value3 => $an->data->{install_manifest}{$uuid}{common}{cluster}{tools}{'use'}{scancore},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($b eq "media_library")
			{
				my $size  = $a->{$b}->[0]->{size};
				my $units = $a->{$b}->[0]->{units};
				$an->data->{install_manifest}{$uuid}{common}{media_library}{size}  = $size  ? $size  : "";
				$an->data->{install_manifest}{$uuid}{common}{media_library}{units} = $units ? $units : "";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "install_manifest::${uuid}::common::media_library::size",  value1 => $an->data->{install_manifest}{$uuid}{common}{media_library}{size}, 
					name2 => "install_manifest::${uuid}::common::media_library::units", value2 => $an->data->{install_manifest}{$uuid}{common}{media_library}{units}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($b eq "repository")
			{
				my $urls = $a->{$b}->[0]->{urls};
				$an->data->{install_manifest}{$uuid}{common}{anvil}{repositories} = $urls ? $urls : "";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "install_manifest::${uuid}::common::anvil::repositories",  value1 => $an->data->{install_manifest}{$uuid}{common}{anvil}{repositories}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($b eq "networks")
			{
				foreach my $c (keys %{$a->{$b}->[0]})
				{
					if ($c eq "bonding")
					{
						foreach my $d (keys %{$a->{$b}->[0]->{$c}->[0]})
						{
							if ($d eq "opts")
							{
								# Global bonding options.
								my $options = $a->{$b}->[0]->{$c}->[0]->{opts};
								$an->data->{install_manifest}{$uuid}{common}{network}{bond}{options} = $options ? $options : "";
								$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
									name1 => "Common bonding options", value1 => $an->data->{install_manifest}{$uuid}{common}{network}{bonds}{options},
								}, file => $THIS_FILE, line => __LINE__});
							}
							else
							{
								# Named network.
								my $name      = $a->{$b}->[0]->{$c}->[0]->{$d}->[0]->{name};
								my $primary   = $a->{$b}->[0]->{$c}->[0]->{$d}->[0]->{primary};
								my $secondary = $a->{$b}->[0]->{$c}->[0]->{$d}->[0]->{secondary};
								$an->data->{install_manifest}{$uuid}{common}{network}{bond}{name}{$name}{primary}   = $primary   ? $primary   : "";
								$an->data->{install_manifest}{$uuid}{common}{network}{bond}{name}{$name}{secondary} = $secondary ? $secondary : "";
								$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
									name1 => "Bond",      value1 => $name,
									name2 => "Primary",   value2 => $an->data->{install_manifest}{$uuid}{common}{network}{bond}{name}{$name}{primary},
									name3 => "Secondary", value3 => $an->data->{install_manifest}{$uuid}{common}{network}{bond}{name}{$name}{secondary},
								}, file => $THIS_FILE, line => __LINE__});
							}
						}
					}
					elsif ($c eq "bridges")
					{
						foreach my $d (@{$a->{$b}->[0]->{$c}->[0]->{bridge}})
						{
							my $name = $d->{name};
							my $on   = $d->{on};
							$an->data->{install_manifest}{$uuid}{common}{network}{bridge}{$name}{on} = $on ? $on : "";
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => "install_manifest::${uuid}::common::network::bridge::${name}::on", value1 => $an->data->{install_manifest}{$uuid}{common}{network}{bridge}{$name}{on},
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
					elsif ($c eq "mtu")
					{
						#<mtu size=\"".$an->data->{cgi}{anvil_mtu_size}."\" />
						my $size = $a->{$b}->[0]->{$c}->[0]->{size};
						$an->data->{install_manifest}{$uuid}{common}{network}{mtu}{size} = $size ? $size : 1500;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "install_manifest::${uuid}::common::network::mtu::size", value1 => $an->data->{install_manifest}{$uuid}{common}{network}{mtu}{size},
						}, file => $THIS_FILE, line => __LINE__});
					}
					else
					{
						my $netblock     = $a->{$b}->[0]->{$c}->[0]->{netblock};
						my $netmask      = $a->{$b}->[0]->{$c}->[0]->{netmask};
						my $gateway      = $a->{$b}->[0]->{$c}->[0]->{gateway};
						my $defroute     = $a->{$b}->[0]->{$c}->[0]->{defroute};
						my $dns1         = $a->{$b}->[0]->{$c}->[0]->{dns1};
						my $dns2         = $a->{$b}->[0]->{$c}->[0]->{dns2};
						my $ntp1         = $a->{$b}->[0]->{$c}->[0]->{ntp1};
						my $ntp2         = $a->{$b}->[0]->{$c}->[0]->{ntp2};
						my $ethtool_opts = $a->{$b}->[0]->{$c}->[0]->{ethtool_opts};
						
						my $netblock_key     = "${c}_network";
						my $netmask_key      = "${c}_subnet";
						my $gateway_key      = "${c}_gateway";
						my $defroute_key     = "${c}_defroute";
						my $ethtool_opts_key = "${c}_ethtool_opts";
						$an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{netblock}     = defined $netblock     ? $netblock     : $an->data->{sys}{install_manifest}{'default'}{$netblock_key};
						$an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{netmask}      = defined $netmask      ? $netmask      : $an->data->{sys}{install_manifest}{'default'}{$netmask_key};
						$an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{gateway}      = defined $gateway      ? $gateway      : $an->data->{sys}{install_manifest}{'default'}{$gateway_key};
						$an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{defroute}     = defined $defroute     ? $defroute     : $an->data->{sys}{install_manifest}{'default'}{$defroute_key};
						$an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{dns1}         = defined $dns1         ? $dns1         : "";
						$an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{dns2}         = defined $dns2         ? $dns2         : "";
						$an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{ntp1}         = defined $ntp1         ? $ntp1         : "";
						$an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{ntp2}         = defined $ntp2         ? $ntp2         : "";
						$an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{ethtool_opts} = defined $ethtool_opts ? $ethtool_opts : $an->data->{sys}{install_manifest}{'default'}{$ethtool_opts_key};
						$an->Log->entry({log_level => 3, message_key => "an_variables_0009", message_variables => {
							name1 => "install_manifest::${uuid}::common::network::name::${c}::netblock",     value1 => $an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{netblock},
							name2 => "install_manifest::${uuid}::common::network::name::${c}::netmask",      value2 => $an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{netmask},
							name3 => "install_manifest::${uuid}::common::network::name::${c}::gateway",      value3 => $an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{gateway},
							name4 => "install_manifest::${uuid}::common::network::name::${c}::defroute",     value4 => $an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{defroute},
							name5 => "install_manifest::${uuid}::common::network::name::${c}::dns1",         value5 => $an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{dns1},
							name6 => "install_manifest::${uuid}::common::network::name::${c}::dns2",         value6 => $an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{dns2},
							name7 => "install_manifest::${uuid}::common::network::name::${c}::ntp1",         value7 => $an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{ntp1},
							name8 => "install_manifest::${uuid}::common::network::name::${c}::ntp2",         value8 => $an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{ntp2},
							name9 => "install_manifest::${uuid}::common::network::name::${c}::ethtool_opts", value9 => $an->data->{install_manifest}{$uuid}{common}{network}{name}{$c}{ethtool_opts},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
			}
			elsif ($b eq "drbd")
			{
				foreach my $c (keys %{$a->{$b}->[0]})
				{
					if ($c eq "disk")
					{
						my $disk_barrier = $a->{$b}->[0]->{$c}->[0]->{'disk-barrier'};
						my $disk_flushes = $a->{$b}->[0]->{$c}->[0]->{'disk-flushes'};
						my $md_flushes   = $a->{$b}->[0]->{$c}->[0]->{'md-flushes'};
						
						$an->data->{install_manifest}{$uuid}{common}{drbd}{disk}{'disk-barrier'} = defined $disk_barrier ? $disk_barrier : "";
						$an->data->{install_manifest}{$uuid}{common}{drbd}{disk}{'disk-flushes'} = defined $disk_flushes ? $disk_flushes : "";
						$an->data->{install_manifest}{$uuid}{common}{drbd}{disk}{'md-flushes'}   = defined $md_flushes   ? $md_flushes   : "";
						$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
							name1 => "install_manifest::${uuid}::common::drbd::disk::disk-barrier", value1 => $an->data->{install_manifest}{$uuid}{common}{drbd}{disk}{'disk-barrier'},
							name2 => "install_manifest::${uuid}::common::drbd::disk::disk-flushes", value2 => $an->data->{install_manifest}{$uuid}{common}{drbd}{disk}{'disk-flushes'},
							name3 => "install_manifest::${uuid}::common::drbd::disk::md-flushes",   value3 => $an->data->{install_manifest}{$uuid}{common}{drbd}{disk}{'md-flushes'},
						}, file => $THIS_FILE, line => __LINE__});
					}
					elsif ($c eq "options")
					{
						my $cpu_mask = $a->{$b}->[0]->{$c}->[0]->{'cpu-mask'};
						$an->data->{install_manifest}{$uuid}{common}{drbd}{options}{'cpu-mask'} = defined $cpu_mask ? $cpu_mask : "";
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "install_manifest::${uuid}::common::drbd::options::cpu-mask", value1 => $an->data->{install_manifest}{$uuid}{common}{drbd}{options}{'cpu-mask'},
						}, file => $THIS_FILE, line => __LINE__});
					}
					elsif ($c eq "net")
					{
						my $max_buffers = $a->{$b}->[0]->{$c}->[0]->{'max-buffers'};
						my $sndbuf_size = $a->{$b}->[0]->{$c}->[0]->{'sndbuf-size'};
						my $rcvbuf_size = $a->{$b}->[0]->{$c}->[0]->{'rcvbuf-size'};
						$an->data->{install_manifest}{$uuid}{common}{drbd}{net}{'max-buffers'} = defined $max_buffers ? $max_buffers : "";
						$an->data->{install_manifest}{$uuid}{common}{drbd}{net}{'sndbuf-size'} = defined $sndbuf_size ? $sndbuf_size : "";
						$an->data->{install_manifest}{$uuid}{common}{drbd}{net}{'rcvbuf-size'} = defined $rcvbuf_size ? $rcvbuf_size : "";
						$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
							name1 => "install_manifest::${uuid}::common::drbd::net::max-buffers", value1 => $an->data->{install_manifest}{$uuid}{common}{drbd}{net}{'max-buffers'},
							name2 => "install_manifest::${uuid}::common::drbd::net::sndbuf-size", value2 => $an->data->{install_manifest}{$uuid}{common}{drbd}{net}{'sndbuf-size'},
							name3 => "install_manifest::${uuid}::common::drbd::net::rcvbuf-size", value3 => $an->data->{install_manifest}{$uuid}{common}{drbd}{net}{'rcvbuf-size'},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
			}
			elsif ($b eq "pdu")
			{
				foreach my $c (@{$a->{$b}->[0]->{pdu}})
				{
					my $reference       = $c->{reference};
					my $name            = $c->{name};
					my $ip              = $c->{ip};
					my $user            = $c->{user};
					my $password        = $c->{password};
					my $password_script = $c->{password_script};
					my $agent           = $c->{agent};
					
					$an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{name}            = $name            ? $name            : "";
					$an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{ip}              = $ip              ? $ip              : "";
					$an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{user}            = $user            ? $user            : "";
					$an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{password}        = $password        ? $password        : "";
					$an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{password_script} = $password_script ? $password_script : "";
					$an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{agent}           = $agent           ? $agent           : $an->data->{sys}{install_manifest}{pdu_agent};
					$an->Log->entry({log_level => 4, message_key => "an_variables_0005", message_variables => {
						name1 => "install_manifest::${uuid}::common::pdu::${reference}::name",            value1 => $an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{name},
						name2 => "install_manifest::${uuid}::common::pdu::${reference}::ip",              value2 => $an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{ip},
						name3 => "install_manifest::${uuid}::common::pdu::${reference}::user",            value3 => $an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{user},
						name4 => "install_manifest::${uuid}::common::pdu::${reference}::password_script", value4 => $an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{password_script},
						name5 => "install_manifest::${uuid}::common::pdu::${reference}::agent",           value5 => $an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{agent},
					}, file => $THIS_FILE, line => __LINE__});
					$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
						name1 => "install_manifest::${uuid}::common::pdu::${reference}::password", value1 => $an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{password},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($b eq "kvm")
			{
				foreach my $c (@{$a->{$b}->[0]->{kvm}})
				{
					my $reference       = $c->{reference};
					my $name            = $c->{name};
					my $ip              = $c->{ip};
					my $user            = $c->{user};
					my $password        = $c->{password};
					my $password_script = $c->{password_script};
					my $agent           = $c->{agent};
					
					$an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{name}            = $name            ? $name            : "";
					$an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{ip}              = $ip              ? $ip              : "";
					$an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{user}            = $user            ? $user            : "";
					$an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{password}        = $password        ? $password        : "";
					$an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{password_script} = $password_script ? $password_script : "";
					$an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{agent}           = $agent           ? $agent           : "fence_virsh";
					$an->Log->entry({log_level => 4, message_key => "an_variables_0005", message_variables => {
						name1 => "install_manifest::${uuid}::common::kvm::${reference}::name",            value1 => $an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{name},
						name2 => "install_manifest::${uuid}::common::kvm::${reference}::ip",              value2 => $an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{ip},
						name3 => "install_manifest::${uuid}::common::kvm::${reference}::user",            value3 => $an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{user},
						name4 => "install_manifest::${uuid}::common::kvm::${reference}::password_script", value4 => $an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{password_script},
						name5 => "install_manifest::${uuid}::common::kvm::${reference}::agent",           value5 => $an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{agent},
					}, file => $THIS_FILE, line => __LINE__});
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "install_manifest::${uuid}::common::kvm::${reference}::password", value1 => $an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{password},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($b eq "ipmi")
			{
				foreach my $c (@{$a->{$b}->[0]->{ipmi}})
				{
					my $reference       = $c->{reference};
					my $name            = $c->{name};
					my $ip              = $c->{ip};
					my $netmask         = $c->{netmask};
					my $gateway         = $c->{gateway};
					my $user            = $c->{user};
					my $password        = $c->{password};
					my $password_script = $c->{password_script};
					my $agent           = $c->{agent};
					
					$an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{name}            = $name            ? $name            : "";
					$an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{ip}              = $ip              ? $ip              : "";
					$an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{netmask}         = $netmask         ? $netmask         : "";
					$an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{gateway}         = $gateway         ? $gateway         : "";
					$an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{user}            = $user            ? $user            : "";
					$an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{password}        = $password        ? $password        : "";
					$an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{password_script} = $password_script ? $password_script : "";
					$an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{agent}           = $agent           ? $agent           : "fence_ipmilan";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0008", message_variables => {
						name1 => "install_manifest::${uuid}::common::ipmi::${reference}::name",             value1 => $an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{name},
						name2 => "install_manifest::${uuid}::common::ipmi::${reference}::ip",               value2 => $an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{ip},
						name3 => "install_manifest::${uuid}::common::ipmi::${reference}::netmask",          value3 => $an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{netmask},
						name4 => "install_manifest::${uuid}::common::ipmi::${reference}::gateway",          value4 => $an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{gateway},
						name5 => "install_manifest::${uuid}::common::ipmi::${reference}::user",             value5 => $an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{user},
						name6 => "install_manifest::${uuid}::common::ipmi::${reference}::password_script",  value6 => $an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{password_script},
						name7 => "install_manifest::${uuid}::common::ipmi::${reference}::agent",            value7 => $an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{agent},
						name8 => "length(install_manifest::${uuid}::common::ipmi::${reference}::password)", value8 => length($an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{password}),
					}, file => $THIS_FILE, line => __LINE__});
					$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
						name1 => "install_manifest::${uuid}::common::ipmi::${reference}::password", value1 => $an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{password},
					}, file => $THIS_FILE, line => __LINE__});
					
					# If the password is more than 16 characters long, truncate it so 
					# that nodes with IPMI v1.5 don't spazz out.
					if (length($an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{password}) > 16)
					{
						$an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{password} = substr($an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{password}, 0, 16);
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "length(install_manifest::${uuid}::common::ipmi::${reference}::password)", value1 => length($an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{password}),
						}, file => $THIS_FILE, line => __LINE__});
						$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
							name1 => "install_manifest::${uuid}::common::ipmi::${reference}::password", value1 => $an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{password},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
			}
			elsif ($b eq "ssh")
			{
				my $keysize = $a->{$b}->[0]->{keysize};
				$an->data->{install_manifest}{$uuid}{common}{ssh}{keysize} = $keysize ? $keysize : "";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "install_manifest::${uuid}::common::ssh::keysize", value1 => $an->data->{install_manifest}{$uuid}{common}{ssh}{keysize},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($b eq "storage_pool_1")
			{
				my $size  = $a->{$b}->[0]->{size};
				my $units = $a->{$b}->[0]->{units};
				$an->data->{install_manifest}{$uuid}{common}{storage_pool}{1}{size}  = $size  ? $size  : "";
				$an->data->{install_manifest}{$uuid}{common}{storage_pool}{1}{units} = $units ? $units : "";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "install_manifest::${uuid}::common::storage_pool::1::size",  value1 => $an->data->{install_manifest}{$uuid}{common}{storage_pool}{1}{size},
					name2 => "install_manifest::${uuid}::common::storage_pool::1::units", value2 => $an->data->{install_manifest}{$uuid}{common}{storage_pool}{1}{units},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($b eq "striker")
			{
				foreach my $c (@{$a->{$b}->[0]->{striker}})
				{
					my $name     = $c->{name};
					my $bcn_ip   = $c->{bcn_ip};
					my $ifn_ip   = $c->{ifn_ip};
					my $password = $c->{password};
					my $user     = $c->{user};
					my $database = $c->{database};
					
					$an->data->{install_manifest}{$uuid}{common}{striker}{name}{$name}{bcn_ip}   = $bcn_ip   ? $bcn_ip   : "";
					$an->data->{install_manifest}{$uuid}{common}{striker}{name}{$name}{ifn_ip}   = $ifn_ip   ? $ifn_ip   : "";
					$an->data->{install_manifest}{$uuid}{common}{striker}{name}{$name}{password} = $password ? $password : "";
					$an->data->{install_manifest}{$uuid}{common}{striker}{name}{$name}{user}     = $user     ? $user     : "";
					$an->data->{install_manifest}{$uuid}{common}{striker}{name}{$name}{database} = $database ? $database : "";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
						name1 => "install_manifest::${uuid}::common::striker::name::${name}::bcn_ip",   value1 => $an->data->{install_manifest}{$uuid}{common}{striker}{name}{$name}{bcn_ip},
						name2 => "install_manifest::${uuid}::common::striker::name::${name}::ifn_ip",   value2 => $an->data->{install_manifest}{$uuid}{common}{striker}{name}{$name}{ifn_ip},
						name3 => "install_manifest::${uuid}::common::striker::name::${name}::user",     value3 => $an->data->{install_manifest}{$uuid}{common}{striker}{name}{$name}{user},
						name4 => "install_manifest::${uuid}::common::striker::name::${name}::database", value4 => $an->data->{install_manifest}{$uuid}{common}{striker}{name}{$name}{database},
					}, file => $THIS_FILE, line => __LINE__});
					$an->Log->entry({log_level => 4, message_key => "an_variables_0006", message_variables => {
						name1 => "install_manifest::${uuid}::common::striker::name::${name}::password", value1 => $an->data->{install_manifest}{$uuid}{common}{striker}{name}{$name}{password},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($b eq "switch")
			{
				foreach my $c (@{$a->{$b}->[0]->{switch}})
				{
					my $name = $c->{name};
					my $ip   = $c->{ip};
					$an->data->{install_manifest}{$uuid}{common}{switch}{$name}{ip} = $ip ? $ip : "";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "Switch", value1 => $name,
						name2 => "IP",     value2 => $an->data->{install_manifest}{$uuid}{common}{switch}{$name}{ip},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($b eq "update")
			{
				my $os = $a->{$b}->[0]->{os};
				$an->data->{install_manifest}{$uuid}{common}{update}{os} = $os ? $os : "";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "install_manifest::${uuid}::common::update::os", value1 => $an->data->{install_manifest}{$uuid}{common}{update}{os},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($b eq "ups")
			{
				foreach my $c (@{$a->{$b}->[0]->{ups}})
				{
					my $name = $c->{name};
					my $ip   = $c->{ip};
					my $type = $c->{type};
					my $port = $c->{port};
					$an->data->{install_manifest}{$uuid}{common}{ups}{$name}{ip}   = $ip   ? $ip   : "";
					$an->data->{install_manifest}{$uuid}{common}{ups}{$name}{type} = $type ? $type : "";
					$an->data->{install_manifest}{$uuid}{common}{ups}{$name}{port} = $port ? $port : "";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
						name1 => "install_manifest::${uuid}::common::ups::${name}::ip",   value1 => $an->data->{install_manifest}{$uuid}{common}{ups}{$name}{ip},
						name2 => "install_manifest::${uuid}::common::ups::${name}::type", value2 => $an->data->{install_manifest}{$uuid}{common}{ups}{$name}{type},
						name3 => "install_manifest::${uuid}::common::ups::${name}::port", value3 => $an->data->{install_manifest}{$uuid}{common}{ups}{$name}{port},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($b eq "pts")
			{
				foreach my $c (@{$a->{$b}->[0]->{pts}})
				{
					my $name = $c->{name};
					my $ip   = $c->{ip};
					my $type = $c->{type};
					my $port = $c->{port};
					$an->data->{install_manifest}{$uuid}{common}{pts}{$name}{ip}   = $ip   ? $ip   : "";
					$an->data->{install_manifest}{$uuid}{common}{pts}{$name}{type} = $type ? $type : "";
					$an->data->{install_manifest}{$uuid}{common}{pts}{$name}{port} = $port ? $port : "";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
						name1 => "install_manifest::${uuid}::common::pts::${name}::ip",   value1 => $an->data->{install_manifest}{$uuid}{common}{pts}{$name}{ip},
						name2 => "install_manifest::${uuid}::common::pts::${name}::type", value2 => $an->data->{install_manifest}{$uuid}{common}{pts}{$name}{type},
						name3 => "install_manifest::${uuid}::common::pts::${name}::port", value3 => $an->data->{install_manifest}{$uuid}{common}{pts}{$name}{port},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			else
			{
				# Extra element.
				$an->Log->entry({log_level => 3, message_key => "tools_log_0029", message_variables => {
					uuid    => $uuid, 
					element => $b, 
					value   => $a->{$b}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Load the common variables.
	$an->data->{cgi}{anvil_prefix}       = $an->data->{install_manifest}{$uuid}{common}{anvil}{prefix};
	$an->data->{cgi}{anvil_domain}       = $an->data->{install_manifest}{$uuid}{common}{anvil}{domain};
	$an->data->{cgi}{anvil_sequence}     = $an->data->{install_manifest}{$uuid}{common}{anvil}{sequence};
	$an->data->{cgi}{anvil_password}     = $an->data->{install_manifest}{$uuid}{common}{anvil}{password}         ? $an->data->{install_manifest}{$uuid}{common}{anvil}{password}         : $an->data->{sys}{install_manifest}{'default'}{password};
	$an->data->{cgi}{anvil_repositories} = $an->data->{install_manifest}{$uuid}{common}{anvil}{repositories};
	$an->data->{cgi}{anvil_ssh_keysize}  = $an->data->{install_manifest}{$uuid}{common}{ssh}{keysize}            ? $an->data->{install_manifest}{$uuid}{common}{ssh}{keysize}            : $an->data->{sys}{install_manifest}{'default'}{ssh_keysize};
	$an->data->{cgi}{anvil_mtu_size}     = $an->data->{install_manifest}{$uuid}{common}{network}{mtu}{size}      ? $an->data->{install_manifest}{$uuid}{common}{network}{mtu}{size}      : $an->data->{sys}{install_manifest}{'default'}{mtu_size};
	$an->data->{cgi}{striker_user}       = $an->data->{install_manifest}{$uuid}{common}{anvil}{striker_user}     ? $an->data->{install_manifest}{$uuid}{common}{anvil}{striker_user}     : $an->data->{sys}{install_manifest}{'default'}{striker_user};
	$an->data->{cgi}{striker_database}   = $an->data->{install_manifest}{$uuid}{common}{anvil}{striker_database} ? $an->data->{install_manifest}{$uuid}{common}{anvil}{striker_database} : $an->data->{sys}{install_manifest}{'default'}{striker_database};
	$an->Log->entry({log_level => 4, message_key => "an_variables_0006", message_variables => {
		name1 => "cgi::anvil_prefix",       value1 => $an->data->{cgi}{anvil_prefix},
		name2 => "cgi::anvil_domain",       value2 => $an->data->{cgi}{anvil_domain},
		name3 => "cgi::anvil_sequence",     value3 => $an->data->{cgi}{anvil_sequence},
		name4 => "cgi::anvil_repositories", value4 => $an->data->{cgi}{anvil_repositories},
		name5 => "cgi::anvil_ssh_keysize",  value5 => $an->data->{cgi}{anvil_ssh_keysize},
		name6 => "cgi::striker_database",   value6 => $an->data->{cgi}{striker_database},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_password", value1 => $an->data->{cgi}{anvil_password},
	}, file => $THIS_FILE, line => __LINE__});
	
	# Media Library values
	$an->data->{cgi}{anvil_media_library_size} = $an->data->{install_manifest}{$uuid}{common}{media_library}{size};
	$an->data->{cgi}{anvil_media_library_unit} = $an->data->{install_manifest}{$uuid}{common}{media_library}{units};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::anvil_media_library_size", value1 => $an->data->{cgi}{anvil_media_library_size},
		name2 => "cgi::anvil_media_library_unit", value2 => $an->data->{cgi}{anvil_media_library_unit},
	}, file => $THIS_FILE, line => __LINE__});
	
	# Networks
	$an->data->{cgi}{anvil_bcn_ethtool_opts} = $an->data->{install_manifest}{$uuid}{common}{network}{name}{bcn}{ethtool_opts};
	$an->data->{cgi}{anvil_bcn_network}      = $an->data->{install_manifest}{$uuid}{common}{network}{name}{bcn}{netblock};
	$an->data->{cgi}{anvil_bcn_subnet}       = $an->data->{install_manifest}{$uuid}{common}{network}{name}{bcn}{netmask};
	$an->data->{cgi}{anvil_sn_ethtool_opts}  = $an->data->{install_manifest}{$uuid}{common}{network}{name}{sn}{ethtool_opts};
	$an->data->{cgi}{anvil_sn_network}       = $an->data->{install_manifest}{$uuid}{common}{network}{name}{sn}{netblock};
	$an->data->{cgi}{anvil_sn_subnet}        = $an->data->{install_manifest}{$uuid}{common}{network}{name}{sn}{netmask};
	$an->data->{cgi}{anvil_ifn_ethtool_opts} = $an->data->{install_manifest}{$uuid}{common}{network}{name}{ifn}{ethtool_opts};
	$an->data->{cgi}{anvil_ifn_network}      = $an->data->{install_manifest}{$uuid}{common}{network}{name}{ifn}{netblock};
	$an->data->{cgi}{anvil_ifn_subnet}       = $an->data->{install_manifest}{$uuid}{common}{network}{name}{ifn}{netmask};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0009", message_variables => {
		name1 => "cgi::anvil_bcn_ethtool_opts", value1 => $an->data->{cgi}{anvil_bcn_ethtool_opts},
		name2 => "cgi::anvil_bcn_network",      value2 => $an->data->{cgi}{anvil_bcn_network},
		name3 => "cgi::anvil_bcn_subnet",       value3 => $an->data->{cgi}{anvil_bcn_subnet},
		name4 => "cgi::anvil_sn_ethtool_opts",  value4 => $an->data->{cgi}{anvil_sn_ethtool_opts},
		name5 => "cgi::anvil_sn_network",       value5 => $an->data->{cgi}{anvil_sn_network},
		name6 => "cgi::anvil_sn_subnet",        value6 => $an->data->{cgi}{anvil_sn_subnet},
		name7 => "cgi::anvil_ifn_ethtool_opts", value7 => $an->data->{cgi}{anvil_ifn_ethtool_opts},
		name8 => "cgi::anvil_ifn_network",      value8 => $an->data->{cgi}{anvil_ifn_network},
		name9 => "cgi::anvil_ifn_subnet",       value9 => $an->data->{cgi}{anvil_ifn_subnet},
	}, file => $THIS_FILE, line => __LINE__});
	
	# iptables
	$an->data->{cgi}{anvil_open_vnc_ports} = $an->data->{install_manifest}{$uuid}{common}{cluster}{iptables}{vnc_ports};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_open_vnc_ports", value1 => $an->data->{cgi}{anvil_open_vnc_ports},
	}, file => $THIS_FILE, line => __LINE__});
	
	# Storage Pool 1
	$an->data->{cgi}{anvil_storage_pool1_size} = $an->data->{install_manifest}{$uuid}{common}{storage_pool}{1}{size};
	$an->data->{cgi}{anvil_storage_pool1_unit} = $an->data->{install_manifest}{$uuid}{common}{storage_pool}{1}{units};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::anvil_storage_pool1_size", value1 => $an->data->{cgi}{anvil_storage_pool1_size},
		name2 => "cgi::anvil_storage_pool1_unit", value2 => $an->data->{cgi}{anvil_storage_pool1_unit},
	}, file => $THIS_FILE, line => __LINE__});
	
	# Tools
	$an->data->{sys}{install_manifest}{'use_anvil-safe-start'}   = defined $an->data->{install_manifest}{$uuid}{common}{cluster}{tools}{'use'}{'anvil-safe-start'}   ? $an->data->{install_manifest}{$uuid}{common}{cluster}{tools}{'use'}{'anvil-safe-start'}   : $an->data->{sys}{install_manifest}{'default'}{'use_anvil-safe-start'};
	$an->data->{sys}{install_manifest}{'use_anvil-kick-apc-ups'} = defined $an->data->{install_manifest}{$uuid}{common}{cluster}{tools}{'use'}{'anvil-kick-apc-ups'} ? $an->data->{install_manifest}{$uuid}{common}{cluster}{tools}{'use'}{'anvil-kick-apc-ups'} : $an->data->{sys}{install_manifest}{'default'}{'use_anvil-kick-apc-ups'};
	$an->data->{sys}{install_manifest}{use_scancore}             = defined $an->data->{install_manifest}{$uuid}{common}{cluster}{tools}{'use'}{scancore}             ? $an->data->{install_manifest}{$uuid}{common}{cluster}{tools}{'use'}{scancore}             : $an->data->{sys}{install_manifest}{'default'}{use_scancore};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "sys::install_manifest::use_anvil-safe-start",   value1 => $an->data->{sys}{install_manifest}{'use_anvil-safe-start'},
		name2 => "sys::install_manifest::use_anvil-kick-apc-ups", value2 => $an->data->{sys}{install_manifest}{'use_anvil-kick-apc-ups'},
		name3 => "sys::install_manifest::use_scancore",           value3 => $an->data->{sys}{install_manifest}{use_scancore},
	}, file => $THIS_FILE, line => __LINE__});
	
	# Shared Variables
	$an->data->{cgi}{anvil_name}        = $an->data->{install_manifest}{$uuid}{common}{cluster}{name};
	$an->data->{cgi}{anvil_ifn_gateway} = $an->data->{install_manifest}{$uuid}{common}{network}{name}{ifn}{gateway};
	$an->data->{cgi}{anvil_dns1}        = $an->data->{install_manifest}{$uuid}{common}{network}{name}{ifn}{dns1};
	$an->data->{cgi}{anvil_dns2}        = $an->data->{install_manifest}{$uuid}{common}{network}{name}{ifn}{dns2};
	$an->data->{cgi}{anvil_ntp1}        = $an->data->{install_manifest}{$uuid}{common}{network}{name}{ifn}{ntp1};
	$an->data->{cgi}{anvil_ntp2}        = $an->data->{install_manifest}{$uuid}{common}{network}{name}{ifn}{ntp2};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
		name1 => "cgi::anvil_name",        value1 => $an->data->{cgi}{anvil_name},
		name2 => "cgi::anvil_ifn_gateway", value2 => $an->data->{cgi}{anvil_ifn_gateway},
		name3 => "cgi::anvil_dns1",        value3 => $an->data->{cgi}{anvil_dns1},
		name4 => "cgi::anvil_dns2",        value4 => $an->data->{cgi}{anvil_dns2},
		name5 => "cgi::anvil_ntp1",        value5 => $an->data->{cgi}{anvil_ntp1},
		name6 => "cgi::anvil_ntp2",        value6 => $an->data->{cgi}{anvil_ntp2},
	}, file => $THIS_FILE, line => __LINE__});
	
	# DRBD variables
	$an->data->{cgi}{'anvil_drbd_disk_disk-barrier'} = defined $an->data->{install_manifest}{$uuid}{common}{drbd}{disk}{'disk-barrier'}    ? $an->data->{install_manifest}{$uuid}{common}{drbd}{disk}{'disk-barrier'}    : $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_disk-barrier'};
	$an->data->{cgi}{'anvil_drbd_disk_disk-flushes'} = defined $an->data->{install_manifest}{$uuid}{common}{drbd}{disk}{'disk-flushes'}    ? $an->data->{install_manifest}{$uuid}{common}{drbd}{disk}{'disk-flushes'}    : $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_disk-flushes'};
	$an->data->{cgi}{'anvil_drbd_disk_md-flushes'}   = defined $an->data->{install_manifest}{$uuid}{common}{drbd}{disk}{'md-flushes'}      ? $an->data->{install_manifest}{$uuid}{common}{drbd}{disk}{'md-flushes'}      : $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_disk_md-flushes'};
	$an->data->{cgi}{'anvil_drbd_options_cpu-mask'}  = defined $an->data->{install_manifest}{$uuid}{common}{drbd}{options}{'cpu-mask'}     ? $an->data->{install_manifest}{$uuid}{common}{drbd}{options}{'cpu-mask'}     : $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_options_cpu-mask'};
	$an->data->{cgi}{'anvil_drbd_net_max-buffers'}   = defined $an->data->{install_manifest}{$uuid}{common}{drbd}{net}{'max-buffers'}      ? $an->data->{install_manifest}{$uuid}{common}{drbd}{net}{'max-buffers'}      : $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_net_max-buffers'};
	$an->data->{cgi}{'anvil_drbd_net_sndbuf-size'}   = defined $an->data->{install_manifest}{$uuid}{common}{drbd}{net}{'sndbuf-size'}      ? $an->data->{install_manifest}{$uuid}{common}{drbd}{net}{'sndbuf-size'}      : $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_net_sndbuf-size'};
	$an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'}   = defined $an->data->{install_manifest}{$uuid}{common}{drbd}{net}{'rcvbuf-size'}      ? $an->data->{install_manifest}{$uuid}{common}{drbd}{net}{'rcvbuf-size'}      : $an->data->{sys}{install_manifest}{'default'}{'anvil_drbd_net_rcvbuf-size'};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
		name1 => "cgi::anvil_drbd_disk_disk-barrier", value1 => $an->data->{cgi}{'anvil_drbd_disk_disk-barrier'},
		name2 => "cgi::anvil_drbd_disk_disk-flushes", value2 => $an->data->{cgi}{'anvil_drbd_disk_disk-flushes'},
		name3 => "cgi::anvil_drbd_disk_md-flushes",   value3 => $an->data->{cgi}{'anvil_drbd_disk_md-flushes'},
		name4 => "cgi::anvil_drbd_options_cpu-mask",  value4 => $an->data->{cgi}{'anvil_drbd_options_cpu-mask'},
		name5 => "cgi::anvil_drbd_net_max-buffers",   value5 => $an->data->{cgi}{'anvil_drbd_net_max-buffers'},
		name6 => "cgi::anvil_drbd_net_sndbuf-size",   value6 => $an->data->{cgi}{'anvil_drbd_net_sndbuf-size'},
		name7 => "cgi::anvil_drbd_net_rcvbuf-size",   value7 => $an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'},
	}, file => $THIS_FILE, line => __LINE__});
	
	### Foundation Pack
	# Switches
	my $i = 1;
	foreach my $switch (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$uuid}{common}{switch}})
	{
		my $name_key = "anvil_switch".$i."_name";
		my $ip_key   = "anvil_switch".$i."_ip";
		$an->data->{cgi}{$name_key} = $switch;
		$an->data->{cgi}{$ip_key}   = $an->data->{install_manifest}{$uuid}{common}{switch}{$switch}{ip};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "switch",           value1 => $switch,
			name2 => "cgi::${name_key}", value2 => $an->data->{cgi}{$name_key},
			name3 => "cgi::${ip_key}",   value3 => $an->data->{cgi}{$ip_key},
		}, file => $THIS_FILE, line => __LINE__});
		$i++;
	}
	# PDUs
	$i = 1;
	foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$uuid}{common}{pdu}})
	{
		my $name_key = "anvil_pdu".$i."_name";
		my $ip_key   = "anvil_pdu".$i."_ip";
		my $name     = $an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{name};
		my $ip       = $an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{ip};
		$an->data->{cgi}{$name_key} = $name ? $name : "";
		$an->data->{cgi}{$ip_key}   = $ip   ? $ip   : "";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "reference",        value1 => $reference,
			name2 => "cgi::${name_key}", value2 => $an->data->{cgi}{$name_key},
			name3 => "cgi::${ip_key}",   value3 => $an->data->{cgi}{$ip_key},
		}, file => $THIS_FILE, line => __LINE__});
		$i++;
	}
	# UPSes
	$i = 1;
	foreach my $ups (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$uuid}{common}{ups}})
	{
		my $name_key = "anvil_ups".$i."_name";
		my $ip_key   = "anvil_ups".$i."_ip";
		$an->data->{cgi}{$name_key} = $ups;
		$an->data->{cgi}{$ip_key}   = $an->data->{install_manifest}{$uuid}{common}{ups}{$ups}{ip};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "ups",              value1 => $ups,
			name2 => "cgi::${name_key}", value2 => $an->data->{cgi}{$name_key},
			name3 => "cgi::${ip_key}",   value3 => $an->data->{cgi}{$ip_key},
		}, file => $THIS_FILE, line => __LINE__});
		$i++;
	}
	# PTSes
	$i = 1;
	foreach my $pts (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$uuid}{common}{pts}})
	{
		my $name_key = "anvil_pts".$i."_name";
		my $ip_key   = "anvil_pts".$i."_ip";
		$an->data->{cgi}{$name_key} = $pts;
		$an->data->{cgi}{$ip_key}   = $an->data->{install_manifest}{$uuid}{common}{pts}{$pts}{ip};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
			name1 => "PTS",       value1 => $pts,
			name2 => "name_key",  value2 => $name_key,
			name3 => "ip_key",    value3 => $ip_key,
			name4 => "CGI; Name", value4 => $an->data->{cgi}{$name_key},
			name5 => "IP",        value5 => $an->data->{cgi}{$ip_key},
		}, file => $THIS_FILE, line => __LINE__});
		$i++;
	}
	# Striker Dashboards
	$i = 1;
	foreach my $striker (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$uuid}{common}{striker}{name}})
	{
		my $name_key     =  "anvil_striker".$i."_name";
		my $bcn_ip_key   =  "anvil_striker".$i."_bcn_ip";
		my $ifn_ip_key   =  "anvil_striker".$i."_ifn_ip";
		my $user_key     =  "anvil_striker".$i."_user";
		my $password_key =  "anvil_striker".$i."_password";
		my $database_key =  "anvil_striker".$i."_database";
		$an->data->{cgi}{$name_key}     = $striker;
		$an->data->{cgi}{$bcn_ip_key}   = $an->data->{install_manifest}{$uuid}{common}{striker}{name}{$striker}{bcn_ip};
		$an->data->{cgi}{$ifn_ip_key}   = $an->data->{install_manifest}{$uuid}{common}{striker}{name}{$striker}{ifn_ip};
		$an->data->{cgi}{$user_key}     = $an->data->{install_manifest}{$uuid}{common}{striker}{name}{$striker}{user}     ? $an->data->{install_manifest}{$uuid}{common}{striker}{name}{$striker}{user}     : $an->data->{cgi}{striker_user};
		$an->data->{cgi}{$password_key} = $an->data->{install_manifest}{$uuid}{common}{striker}{name}{$striker}{password} ? $an->data->{install_manifest}{$uuid}{common}{striker}{name}{$striker}{password} : $an->data->{cgi}{anvil_password};
		$an->data->{cgi}{$database_key} = $an->data->{install_manifest}{$uuid}{common}{striker}{name}{$striker}{database} ? $an->data->{install_manifest}{$uuid}{common}{striker}{name}{$striker}{database} : $an->data->{cgi}{striker_database};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
			name1 => "cgi::$name_key",     value1 => $an->data->{cgi}{$name_key},
			name2 => "cgi::$bcn_ip_key",   value2 => $an->data->{cgi}{$bcn_ip_key},
			name3 => "cgi::$ifn_ip_key",   value3 => $an->data->{cgi}{$ifn_ip_key},
			name4 => "cgi::$user_key",     value4 => $an->data->{cgi}{$user_key},
			name5 => "cgi::$database_key", value5 => $an->data->{cgi}{$database_key},
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::$password_key", value1 => $an->data->{cgi}{$password_key},
		}, file => $THIS_FILE, line => __LINE__});
		$i++;
	}
	
	### Now the Nodes.
	$i = 1;
	foreach my $node (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$uuid}{node}})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "i",    value1 => $i,
			name2 => "node", value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my $name_key          = "anvil_node".$i."_name";
		my $bcn_ip_key        = "anvil_node".$i."_bcn_ip";
		my $bcn_link1_mac_key = "anvil_node".$i."_bcn_link1_mac";
		my $bcn_link2_mac_key = "anvil_node".$i."_bcn_link2_mac";
		my $sn_ip_key         = "anvil_node".$i."_sn_ip";
		my $sn_link1_mac_key  = "anvil_node".$i."_sn_link1_mac";
		my $sn_link2_mac_key  = "anvil_node".$i."_sn_link2_mac";
		my $ifn_ip_key        = "anvil_node".$i."_ifn_ip";
		my $ifn_link1_mac_key = "anvil_node".$i."_ifn_link1_mac";
		my $ifn_link2_mac_key = "anvil_node".$i."_ifn_link2_mac";
		my $uuid_key          = "anvil_node".$i."_uuid";
		
		my $ipmi_ip_key       = "anvil_node".$i."_ipmi_ip";
		my $ipmi_netmask_key  = "anvil_node".$i."_ipmi_netmask",
		my $ipmi_gateway_key  = "anvil_node".$i."_ipmi_gateway",
		my $ipmi_password_key = "anvil_node".$i."_ipmi_password",
		my $ipmi_user_key     = "anvil_node".$i."_ipmi_user",
		my $pdu1_key          = "anvil_node".$i."_pdu1_outlet";
		my $pdu2_key          = "anvil_node".$i."_pdu2_outlet";
		my $pdu3_key          = "anvil_node".$i."_pdu3_outlet";
		my $pdu4_key          = "anvil_node".$i."_pdu4_outlet";
		
		# IPMI is, by default, tempremental about passwords. If the manifest doesn't specify 
		# the password to use, we'll copy the cluster password but then strip out special 
		# characters and shorten it to 16 characters or less.
		my $default_ipmi_pw =  $an->data->{cgi}{anvil_password};
			$default_ipmi_pw =~ s/!//g;
		if (length($default_ipmi_pw) > 16)
		{
			$default_ipmi_pw = substr($default_ipmi_pw, 0, 16);
		}
		
		# Find the IPMI, PDU and KVM reference names
		my $ipmi_reference = "";
		my $pdu1_reference = "";
		my $pdu2_reference = "";
		my $pdu3_reference = "";
		my $pdu4_reference = "";
		my $kvm_reference  = "";
		foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}})
		{
			# There should only be one entry
			$ipmi_reference = $reference;
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "ipmi_reference", value1 => $ipmi_reference,
		}, file => $THIS_FILE, line => __LINE__});
		
		my $j = 1;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "j",                                             value1 => $j,
			name2 => "install_manifest::${uuid}::node::${node}::pdu", value2 => $an->data->{install_manifest}{$uuid}{node}{$node}{pdu},
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$uuid}{node}{$node}{pdu}})
		{
			# There should be two or four PDUs
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "j",         value1 => $j,
				name2 => "reference", value2 => $reference,
			}, file => $THIS_FILE, line => __LINE__});
			if ($j == 1)
			{
				$pdu1_reference = $reference;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "pdu1_reference", value1 => $pdu1_reference,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($j == 2)
			{
				$pdu2_reference = $reference;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "pdu2_reference", value1 => $pdu2_reference,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($j == 3)
			{
				$pdu3_reference = $reference;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "pdu3_reference", value1 => $pdu3_reference,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($j == 4)
			{
				$pdu4_reference = $reference;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "pdu4_reference", value1 => $pdu4_reference,
				}, file => $THIS_FILE, line => __LINE__});
			}
			$j++;
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "pdu1_reference", value1 => $pdu1_reference,
			name2 => "pdu2_reference", value2 => $pdu2_reference,
			name3 => "pdu3_reference", value3 => $pdu3_reference,
			name4 => "pdu4_reference", value4 => $pdu4_reference,
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$uuid}{node}{$node}{kvm}})
		{
			# There should only be one entry
			$kvm_reference = $reference;
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "kvm_reference", value1 => $kvm_reference,
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->data->{cgi}{$name_key}          = $node;
		$an->data->{cgi}{$bcn_ip_key}        = $an->data->{install_manifest}{$uuid}{node}{$node}{network}{bcn}{ip};
		$an->data->{cgi}{$sn_ip_key}         = $an->data->{install_manifest}{$uuid}{node}{$node}{network}{sn}{ip};
		$an->data->{cgi}{$ifn_ip_key}        = $an->data->{install_manifest}{$uuid}{node}{$node}{network}{ifn}{ip};
		
		$an->data->{cgi}{$ipmi_ip_key}       = $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$ipmi_reference}{ip};
		$an->data->{cgi}{$ipmi_netmask_key}  = $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$ipmi_reference}{netmask}  ? $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$ipmi_reference}{netmask}  : $an->data->{cgi}{anvil_bcn_subnet};
		$an->data->{cgi}{$ipmi_gateway_key}  = $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$ipmi_reference}{gateway}  ? $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$ipmi_reference}{gateway}  : "";
		$an->data->{cgi}{$ipmi_password_key} = $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$ipmi_reference}{password} ? $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$ipmi_reference}{password} : $default_ipmi_pw;
		$an->data->{cgi}{$ipmi_user_key}     = $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$ipmi_reference}{user}     ? $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$ipmi_reference}{user}     : "admin";
		$an->data->{cgi}{$pdu1_key}          = $an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$pdu1_reference}{port};
		$an->data->{cgi}{$pdu2_key}          = $an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$pdu2_reference}{port};
		$an->data->{cgi}{$pdu3_key}          = $an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$pdu3_reference}{port};
		$an->data->{cgi}{$pdu4_key}          = $an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$pdu4_reference}{port};
		$an->data->{cgi}{$uuid_key}          = $an->data->{install_manifest}{$uuid}{node}{$node}{uuid}                            ? $an->data->{install_manifest}{$uuid}{node}{$node}{uuid}                            : "";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0013", message_variables => {
			name1  => "cgi::$name_key",          value1  => $an->data->{cgi}{$name_key},
			name2  => "cgi::$bcn_ip_key",        value2  => $an->data->{cgi}{$bcn_ip_key},
			name3  => "cgi::$ipmi_ip_key",       value3  => $an->data->{cgi}{$ipmi_ip_key},
			name4  => "cgi::$ipmi_netmask_key",  value4  => $an->data->{cgi}{$ipmi_netmask_key},
			name5  => "cgi::$ipmi_gateway_key",  value5  => $an->data->{cgi}{$ipmi_gateway_key},
			name6  => "cgi::$ipmi_user_key",     value6  => $an->data->{cgi}{$ipmi_user_key},
			name7  => "cgi::$sn_ip_key",         value7  => $an->data->{cgi}{$sn_ip_key},
			name8  => "cgi::$ifn_ip_key",        value8  => $an->data->{cgi}{$ifn_ip_key},
			name9  => "cgi::$pdu1_key",          value9  => $an->data->{cgi}{$pdu1_key},
			name10 => "cgi::$pdu2_key",          value10 => $an->data->{cgi}{$pdu2_key},
			name11 => "cgi::$pdu3_key",          value11 => $an->data->{cgi}{$pdu3_key},
			name12 => "cgi::$pdu4_key",          value12 => $an->data->{cgi}{$pdu4_key},
			name13 => "cgi::$uuid_key",          value13 => $an->data->{cgi}{$uuid_key},
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::$ipmi_password_key", value1 => $an->data->{cgi}{$ipmi_password_key},
		}, file => $THIS_FILE, line => __LINE__});
		
		# If the user remapped their network, we don't want to undo the results.
		if (not $an->data->{cgi}{perform_install})
		{
			$an->data->{cgi}{$bcn_link1_mac_key} = $an->data->{install_manifest}{$uuid}{node}{$node}{interface}{bcn_link1}{mac};
			$an->data->{cgi}{$bcn_link2_mac_key} = $an->data->{install_manifest}{$uuid}{node}{$node}{interface}{bcn_link2}{mac};
			$an->data->{cgi}{$sn_link1_mac_key}  = $an->data->{install_manifest}{$uuid}{node}{$node}{interface}{sn_link1}{mac};
			$an->data->{cgi}{$sn_link2_mac_key}  = $an->data->{install_manifest}{$uuid}{node}{$node}{interface}{sn_link2}{mac};
			$an->data->{cgi}{$ifn_link1_mac_key} = $an->data->{install_manifest}{$uuid}{node}{$node}{interface}{ifn_link1}{mac};
			$an->data->{cgi}{$ifn_link2_mac_key} = $an->data->{install_manifest}{$uuid}{node}{$node}{interface}{ifn_link2}{mac};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
				name1 => "cgi::$bcn_link1_mac_key", value1 => $an->data->{cgi}{$bcn_link1_mac_key},
				name2 => "cgi::$bcn_link2_mac_key", value2 => $an->data->{cgi}{$bcn_link2_mac_key},
				name3 => "cgi::$sn_link1_mac_key",  value3 => $an->data->{cgi}{$sn_link1_mac_key},
				name4 => "cgi::$sn_link2_mac_key",  value4 => $an->data->{cgi}{$sn_link2_mac_key},
				name5 => "cgi::$ifn_link1_mac_key", value5 => $an->data->{cgi}{$ifn_link1_mac_key},
				name6 => "cgi::$ifn_link2_mac_key", value6 => $an->data->{cgi}{$ifn_link2_mac_key},
			}, file => $THIS_FILE, line => __LINE__});
		}
		$i++;
	}
	
	### Now to build the fence strings.
	my $fence_order                        = $an->data->{install_manifest}{$uuid}{common}{cluster}{fence}{order};
	   $an->data->{cgi}{anvil_fence_order} = $fence_order;
	
	# Nodes
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::anvil_node1_name", value1 => $an->data->{cgi}{anvil_node1_name},
		name2 => "cgi::anvil_node2_name", value2 => $an->data->{cgi}{anvil_node2_name},
	}, file => $THIS_FILE, line => __LINE__});
	my $node1_name = $an->data->{cgi}{anvil_node1_name};
	my $node2_name = $an->data->{cgi}{anvil_node2_name};
	my $delay_set  = 0;
	my $delay_node = $an->data->{install_manifest}{$uuid}{common}{cluster}{fence}{delay_node};
	my $delay_time = $an->data->{install_manifest}{$uuid}{common}{cluster}{fence}{delay};
	foreach my $node ($an->data->{cgi}{anvil_node1_name}, $an->data->{cgi}{anvil_node2_name})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node", value1 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my $i = 1;
		foreach my $method (split/,/, $fence_order)
		{
			if ($method eq "kvm")
			{
				# Only ever one, but...
				my $j = 1;
				foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$uuid}{node}{$node}{kvm}})
				{
					my $port            = $an->data->{install_manifest}{$uuid}{node}{$node}{kvm}{$reference}{port};
					my $user            = $an->data->{install_manifest}{$uuid}{node}{$node}{kvm}{$reference}{user};
					my $password        = $an->data->{install_manifest}{$uuid}{node}{$node}{kvm}{$reference}{password};
					my $password_script = $an->data->{install_manifest}{$uuid}{node}{$node}{kvm}{$reference}{password_script};
					
					# Build the string.
					my $string =  "<device name=\"$reference\"";
						$string .= " port=\"$port\""  if $port;
						$string .= " login=\"$user\"" if $user;
					# One or the other, not both.
					if ($password)
					{
						$string .= " passwd=\"$password\"";
					}
					elsif ($password_script)
					{
						$string .= " passwd_script=\"$password_script\"";
					}
					if (($node eq $delay_node) && (not $delay_set))
					{
						$string    .= " delay=\"$delay_time\"";
						$delay_set =  1;
					}
					$string .= " action=\"reboot\" />";
					$string =~ s/\s+/ /g;
					$an->data->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string} = $string;
					$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
						name1 => "fence::node::${node}::order::${i}::method::${method}::device::${j}::string", value1 => $an->data->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string},
					}, file => $THIS_FILE, line => __LINE__});
					$j++;
				}
			}
			elsif ($method eq "ipmi")
			{
				# Only ever one, but...
				my $j = 1;
				foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}})
				{
					my $name            = $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{name};
					my $ip              = $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{ip};
					my $user            = $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{user};
					my $password        = $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{password};
					my $password_script = $an->data->{install_manifest}{$uuid}{node}{$node}{ipmi}{$reference}{password_script};
					if ((not $name) && ($ip))
					{
						$name = $ip;
					}
					# Build the string
					my $string =  "<device name=\"$reference\"";
						$string .= " ipaddr=\"$name\"" if $name;
						$string .= " login=\"$user\""  if $user;
					# One or the other, not both.
					if ($password)
					{
						$string .= " passwd=\"$password\"";
					}
					elsif ($password_script)
					{
						$string .= " passwd_script=\"$password_script\"";
					}
					if (($node eq $delay_node) && (not $delay_set))
					{
						$string    .= " delay=\"$delay_time\"";
						$delay_set =  1;
					}
					$string .= " action=\"reboot\" />";
					$string =~ s/\s+/ /g;
					$an->data->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string} = $string;
					$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
						name1 => "fence::node::${node}::order::${i}::method::${method}::device::${j}::string", value1 => $an->data->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string},
					}, file => $THIS_FILE, line => __LINE__});
					$j++;
				}
			}
			elsif ($method eq "pdu")
			{
				# Here we can have > 1.
				my $j = 1;
				foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$uuid}{node}{$node}{pdu}})
				{
					my $port            = $an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$reference}{port};
					my $user            = $an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$reference}{user};
					my $password        = $an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$reference}{password};
					my $password_script = $an->data->{install_manifest}{$uuid}{node}{$node}{pdu}{$reference}{password_script};
					
					# If there is no port, skip.
					next if not $port;
					
					# Build the string
					my $string = "<device name=\"$reference\" ";
						$string .= " port=\"$port\""  if $port;
						$string .= " login=\"$user\"" if $user;
					# One or the other, not both.
					if ($password)
					{
						$string .= " passwd=\"$password\"";
					}
					elsif ($password_script)
					{
						$string .= " passwd_script=\"$password_script\"";
					}
					if (($node eq $delay_node) && (not $delay_set))
					{
						$string    .= " delay=\"$delay_time\"";
						$delay_set =  1;
					}
					$string .= " action=\"reboot\" />";
					$string =~ s/\s+/ /g;
					$an->data->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string} = $string;
					$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
						name1 => "fence::node::${node}::order::${i}::method::${method}::device::${j}::string", value1 => $an->data->{fence}{node}{$node}{order}{$i}{method}{$method}{device}{$j}{string},
					}, file => $THIS_FILE, line => __LINE__});
					$j++;
				}
			}
			$i++;
		}
	}
	
	# Devices
	foreach my $device (split/,/, $fence_order)
	{
		if ($device eq "kvm")
		{
			foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$uuid}{common}{kvm}})
			{
				my $name            = $an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{name};
				my $ip              = $an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{ip};
				my $user            = $an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{user};
				my $password        = $an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{password};
				my $password_script = $an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{password_script};
				my $agent           = $an->data->{install_manifest}{$uuid}{common}{kvm}{$reference}{agent};
				if ((not $name) && ($ip))
				{
					$name = $ip;
				}
				
				# Build the string
				my $string =  "<fencedevice name=\"$reference\" agent=\"$agent\"";
					$string .= " ipaddr=\"$name\"" if $name;
					$string .= " login=\"$user\""  if $user;
				# One or the other, not both.
				if ($password)
				{
					$string .= " passwd=\"$password\"";
				}
				elsif ($password_script)
				{
					$string .= " passwd_script=\"$password_script\"";
				}
				$string .= " />";
				$string =~ s/\s+/ /g;
				$an->data->{fence}{device}{$device}{name}{$reference}{string} = $string;
				$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
					name1 => "fence::device::${device}::name::${reference}::string", value1 => $an->data->{fence}{device}{$device}{name}{$reference}{string},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		if ($device eq "ipmi")
		{
			foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$uuid}{common}{ipmi}})
			{
				my $name            = $an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{name};
				my $ip              = $an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{ip};
				my $user            = $an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{user};
				my $password        = $an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{password};
				my $password_script = $an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{password_script};
				my $agent           = $an->data->{install_manifest}{$uuid}{common}{ipmi}{$reference}{agent};
				if ((not $name) && ($ip))
				{
					$name = $ip;
				}
					
				# Build the string
				my $string =  "<fencedevice name=\"$reference\" agent=\"$agent\"";
					$string .= " ipaddr=\"$name\"" if $name;
					$string .= " login=\"$user\""  if $user;
				if ($password)
				{
					$string .= " passwd=\"$password\"";
				}
				elsif ($password_script)
				{
					$string .= " passwd_script=\"$password_script\"";
				}
				$string .= " />";
				$string =~ s/\s+/ /g;
				$an->data->{fence}{device}{$device}{name}{$reference}{string} = $string;
				$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
					name1 => "fence::device::${device}::name::${reference}::string", value1 => $an->data->{fence}{device}{$device}{name}{$reference}{string},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		if ($device eq "pdu")
		{
			foreach my $reference (sort {$a cmp $b} keys %{$an->data->{install_manifest}{$uuid}{common}{pdu}})
			{
				my $name            = $an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{name};
				my $ip              = $an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{ip};
				my $user            = $an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{user};
				my $password        = $an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{password};
				my $password_script = $an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{password_script};
				my $agent           = $an->data->{install_manifest}{$uuid}{common}{pdu}{$reference}{agent};
				if ((not $name) && ($ip))
				{
					$name = $ip;
				}
					
				# Build the string
				my $string =  "<fencedevice name=\"$reference\" agent=\"$agent\" ";
					$string .= " ipaddr=\"$name\"" if $name;
					$string .= " login=\"$user\""  if $user;
				if ($password)
				{	
					$string .= "passwd=\"$password\"";
				}
				elsif ($password_script)
				{
					$string .= "passwd_script=\"$password_script\"";
				}
				$string .= " />";
				$string =~ s/\s+/ /g;
				$an->data->{fence}{device}{$device}{name}{$reference}{string} = $string;
				$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
					name1 => "fence::device::${device}::name::${reference}::string", value1 => $an->data->{fence}{device}{$device}{name}{$reference}{string},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Some system stuff.
	$an->data->{sys}{post_join_delay} = $an->data->{install_manifest}{$uuid}{common}{cluster}{fence}{post_join_delay};
	$an->data->{sys}{update_os}       = $an->data->{install_manifest}{$uuid}{common}{update}{os};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "sys::post_join_delay", value1 => $an->data->{sys}{post_join_delay},
		name2 => "sys::update_os",       value2 => $an->data->{sys}{update_os},
	}, file => $THIS_FILE, line => __LINE__});
	if ((lc($an->data->{install_manifest}{$uuid}{common}{update}{os}) eq "false") || (lc($an->data->{install_manifest}{$uuid}{common}{update}{os}) eq "no"))
	{
		$an->data->{sys}{update_os} = 0;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::update_os", value1 => $an->data->{sys}{update_os},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return(0);
}

# This reads a cache type for the given target for the requesting host and returns the data, if found.
sub read_cache
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "read_cache" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target = $parameter->{target} ? $parameter->{target} : "";
	my $type   = $parameter->{type}   ? $parameter->{type}   : "";
	my $source = $parameter->{source} ? $parameter->{source} : $an->data->{sys}{host_uuid};
	
	my $query = "
SELECT 
    node_cache_data 
FROM 
    nodes_cache 
WHERE 
    node_cache_name      = ".$an->data->{sys}{use_db_fh}->quote($type)."
AND 
    node_cache_node_uuid = ".$an->data->{sys}{use_db_fh}->quote($target);
    
	if ($source eq "any")
	{
		$query .= "
LIMIT 1
;";
	}
	else
	{
		$query .= "
AND 
    node_cache_host_uuid = ".$an->data->{sys}{use_db_fh}->quote($source)."
;";
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query, 
	}, file => $THIS_FILE, line => __LINE__});
	my $data = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__})->[0]->[0];
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "data", value1 => $data, 
	}, file => $THIS_FILE, line => __LINE__});
	
	return($data);
}

# This generates an Install Manifest and records it in the 'manifests' table.
sub save_install_manifest
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "save_install_manifest" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# If 'raw' is set, just straight update the manifest_data.
	my $xml;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::raw",           value1 => $an->data->{cgi}{raw}, 
		name2 => "cgi::manifest_data", value2 => $an->data->{cgi}{manifest_data}, 
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{cgi}{raw}) && ($an->data->{cgi}{manifest_data}))
	{
		$xml = $an->data->{cgi}{manifest_data};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "xml", value1 => $xml, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Break up hostsnames
		my ($node1_short_name)    = ($an->data->{cgi}{anvil_node1_name}    =~ /^(.*?)\./);
		my ($node2_short_name)    = ($an->data->{cgi}{anvil_node2_name}    =~ /^(.*?)\./);
		my ($switch1_short_name)  = ($an->data->{cgi}{anvil_switch1_name}  =~ /^(.*?)\./);
		my ($switch2_short_name)  = ($an->data->{cgi}{anvil_switch2_name}  =~ /^(.*?)\./);
		my ($pdu1_short_name)     = ($an->data->{cgi}{anvil_pdu1_name}     =~ /^(.*?)\./);
		my ($pdu2_short_name)     = ($an->data->{cgi}{anvil_pdu2_name}     =~ /^(.*?)\./);
		my ($pdu3_short_name)     = ($an->data->{cgi}{anvil_pdu3_name}     =~ /^(.*?)\./);
		my ($pdu4_short_name)     = ($an->data->{cgi}{anvil_pdu4_name}     =~ /^(.*?)\./);
		my ($ups1_short_name)     = ($an->data->{cgi}{anvil_ups1_name}     =~ /^(.*?)\./);
		my ($ups2_short_name)     = ($an->data->{cgi}{anvil_ups2_name}     =~ /^(.*?)\./);
		my ($pts1_short_name)     = ($an->data->{cgi}{anvil_pts1_name}     =~ /^(.*?)\./);
		my ($pts2_short_name)     = ($an->data->{cgi}{anvil_pts2_name}     =~ /^(.*?)\./);
		my ($striker1_short_name) = ($an->data->{cgi}{anvil_striker1_name} =~ /^(.*?)\./);
		my ($striker2_short_name) = ($an->data->{cgi}{anvil_striker1_name} =~ /^(.*?)\./);
		my ($now_date, $now_time) = $an->Get->date_and_time();
		my $date                  = "$now_date, $now_time";
		
		# Note yet supported but will be later.
		$an->data->{cgi}{anvil_node1_ipmi_password} = $an->data->{cgi}{anvil_node1_ipmi_password} ? $an->data->{cgi}{anvil_node1_ipmi_password} : $an->data->{cgi}{anvil_password};
		$an->data->{cgi}{anvil_node1_ipmi_user}     = $an->data->{cgi}{anvil_node1_ipmi_user}     ? $an->data->{cgi}{anvil_node1_ipmi_user}     : "admin";
		$an->data->{cgi}{anvil_node2_ipmi_password} = $an->data->{cgi}{anvil_node2_ipmi_password} ? $an->data->{cgi}{anvil_node2_ipmi_password} : $an->data->{cgi}{anvil_password};
		$an->data->{cgi}{anvil_node2_ipmi_user}     = $an->data->{cgi}{anvil_node2_ipmi_user}     ? $an->data->{cgi}{anvil_node2_ipmi_user}     : "admin";
		
		# Generate UUIDs if needed.
		$an->data->{cgi}{anvil_node1_uuid}          = $an->Get->uuid() if not $an->data->{cgi}{anvil_node1_uuid};
		$an->data->{cgi}{anvil_node2_uuid}          = $an->Get->uuid() if not $an->data->{cgi}{anvil_node2_uuid};
		
		### TODO: This isn't set for some reason, fix
		$an->data->{cgi}{anvil_open_vnc_ports} = $an->data->{sys}{install_manifest}{'default'}{open_vnc_ports} if not $an->data->{cgi}{anvil_open_vnc_ports};
		
		# Set the MTU.
		$an->data->{cgi}{anvil_mtu_size} = $an->data->{sys}{install_manifest}{'default'}{mtu_size} if not $an->data->{cgi}{anvil_mtu_size};
		
		# Use the subnet mask of the IPMI devices by comparing their IP to that
		# of the BCN and IFN, and use the netmask of the matching network.
		my $node1_ipmi_netmask = $an->Get->netmask_from_ip({ip => $an->data->{cgi}{anvil_node1_ipmi_ip}});
		my $node2_ipmi_netmask = $an->Get->netmask_from_ip({ip => $an->data->{cgi}{anvil_node2_ipmi_ip}});
		
		### Setup the DRBD lines.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
			name1 => "cgi::anvil_drbd_disk_disk-barrier", value1 => $an->data->{cgi}{'anvil_drbd_disk_disk-barrier'},
			name2 => "cgi::anvil_drbd_disk_disk-flushes", value2 => $an->data->{cgi}{'anvil_drbd_disk_disk-flushes'},
			name3 => "cgi::anvil_drbd_disk_md-flushes",   value3 => $an->data->{cgi}{'anvil_drbd_disk_md-flushes'},
			name4 => "cgi::anvil_drbd_options_cpu-mask",  value4 => $an->data->{cgi}{'anvil_drbd_options_cpu-mask'},
			name5 => "cgi::anvil_drbd_net_max-buffers",   value5 => $an->data->{cgi}{'anvil_drbd_net_max-buffers'},
			name6 => "cgi::anvil_drbd_net_sndbuf-size",   value6 => $an->data->{cgi}{'anvil_drbd_net_sndbuf-size'},
			name7 => "cgi::anvil_drbd_net_rcvbuf-size",   value7 => $an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'},
		}, file => $THIS_FILE, line => __LINE__});
		
		# Standardize
		$an->data->{cgi}{'anvil_drbd_disk_disk-barrier'} =  lc($an->data->{cgi}{'anvil_drbd_disk_disk-barrier'});
		$an->data->{cgi}{'anvil_drbd_disk_disk-barrier'} =~ s/no/false/;
		$an->data->{cgi}{'anvil_drbd_disk_disk-barrier'} =~ s/0/false/;
		$an->data->{cgi}{'anvil_drbd_disk_disk-flushes'} =  lc($an->data->{cgi}{'anvil_drbd_disk_disk-flushes'});
		$an->data->{cgi}{'anvil_drbd_disk_disk-flushes'} =~ s/no/false/;
		$an->data->{cgi}{'anvil_drbd_disk_disk-flushes'} =~ s/0/false/;
		$an->data->{cgi}{'anvil_drbd_disk_md-flushes'}   =  lc($an->data->{cgi}{'anvil_drbd_disk_md-flushes'});
		$an->data->{cgi}{'anvil_drbd_disk_md-flushes'}   =~ s/no/false/;
		$an->data->{cgi}{'anvil_drbd_disk_md-flushes'}   =~ s/0/false/;
		
		# Convert
		$an->data->{cgi}{'anvil_drbd_disk_disk-barrier'} = $an->data->{cgi}{'anvil_drbd_disk_disk-barrier'} eq "false" ? "no" : "yes";
		$an->data->{cgi}{'anvil_drbd_disk_disk-flushes'} = $an->data->{cgi}{'anvil_drbd_disk_disk-flushes'} eq "false" ? "no" : "yes";
		$an->data->{cgi}{'anvil_drbd_disk_md-flushes'}   = $an->data->{cgi}{'anvil_drbd_disk_md-flushes'}   eq "false" ? "no" : "yes";
		$an->data->{cgi}{'anvil_drbd_options_cpu-mask'}  = defined $an->data->{cgi}{'anvil_drbd_options_cpu-mask'}   ? $an->data->{cgi}{'anvil_drbd_options_cpu-mask'} : "";
		$an->data->{cgi}{'anvil_drbd_net_max-buffers'}   = $an->data->{cgi}{'anvil_drbd_net_max-buffers'} =~ /^\d+$/ ? $an->data->{cgi}{'anvil_drbd_net_max-buffers'}  : "";
		$an->data->{cgi}{'anvil_drbd_net_sndbuf-size'}   = $an->data->{cgi}{'anvil_drbd_net_sndbuf-size'}            ? $an->data->{cgi}{'anvil_drbd_net_sndbuf-size'}  : "";
		$an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'}   = $an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'}            ? $an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'}  : "";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
			name1 => "cgi::anvil_drbd_disk_disk-barrier", value1 => $an->data->{cgi}{'anvil_drbd_disk_disk-barrier'},
			name2 => "cgi::anvil_drbd_disk_disk-flushes", value2 => $an->data->{cgi}{'anvil_drbd_disk_disk-flushes'},
			name3 => "cgi::anvil_drbd_disk_md-flushes",   value3 => $an->data->{cgi}{'anvil_drbd_disk_md-flushes'},
			name4 => "cgi::anvil_drbd_options_cpu-mask",  value4 => $an->data->{cgi}{'anvil_drbd_options_cpu-mask'},
			name5 => "cgi::anvil_drbd_net_max-buffers",   value5 => $an->data->{cgi}{'anvil_drbd_net_max-buffers'},
			name6 => "cgi::anvil_drbd_net_sndbuf-size",   value6 => $an->data->{cgi}{'anvil_drbd_net_sndbuf-size'},
			name7 => "cgi::anvil_drbd_net_rcvbuf-size",   value7 => $an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'},
		}, file => $THIS_FILE, line => __LINE__});
		
		### TODO: Get the node and dashboard UUIDs if not yet set.
		
		### KVM-based fencing is supported but not documented. Sample entries
		### are here for those who might ask for it when building test Anvil!
		### systems later.
		# Many things are currently static but might be made configurable later.
		$xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>

<!--
Generated on:    ".$date."
Striker Version: ".$an->data->{sys}{version}."
-->

<config>
	<node name=\"".$an->data->{cgi}{anvil_node1_name}."\" uuid=\"".$an->data->{cgi}{anvil_node1_uuid}."\">
		<network>
			<bcn ip=\"".$an->data->{cgi}{anvil_node1_bcn_ip}."\" />
			<sn ip=\"".$an->data->{cgi}{anvil_node1_sn_ip}."\" />
			<ifn ip=\"".$an->data->{cgi}{anvil_node1_ifn_ip}."\" />
		</network>
		<ipmi>
			<on reference=\"ipmi_n01\" ip=\"".$an->data->{cgi}{anvil_node1_ipmi_ip}."\" netmask=\"$node1_ipmi_netmask\" user=\"".$an->data->{cgi}{anvil_node1_ipmi_user}."\" password=\"".$an->data->{cgi}{anvil_node1_ipmi_password}."\" gateway=\"\" />
		</ipmi>
		<pdu>
			<on reference=\"pdu01\" port=\"".$an->data->{cgi}{anvil_node1_pdu1_outlet}."\" />
			<on reference=\"pdu02\" port=\"".$an->data->{cgi}{anvil_node1_pdu2_outlet}."\" />
			<on reference=\"pdu03\" port=\"".$an->data->{cgi}{anvil_node1_pdu3_outlet}."\" />
			<on reference=\"pdu04\" port=\"".$an->data->{cgi}{anvil_node1_pdu4_outlet}."\" />
		</pdu>
		<kvm>
			<!-- port == virsh name of VM -->
			<on reference=\"kvm_host\" port=\"\" />
		</kvm>
		<interfaces>
			<interface name=\"bcn_link1\" mac=\"".$an->data->{cgi}{anvil_node1_bcn_link1_mac}."\" />
			<interface name=\"bcn_link2\" mac=\"".$an->data->{cgi}{anvil_node1_bcn_link2_mac}."\" />
			<interface name=\"sn_link1\" mac=\"".$an->data->{cgi}{anvil_node1_sn_link1_mac}."\" />
			<interface name=\"sn_link2\" mac=\"".$an->data->{cgi}{anvil_node1_sn_link2_mac}."\" />
			<interface name=\"ifn_link1\" mac=\"".$an->data->{cgi}{anvil_node1_ifn_link1_mac}."\" />
			<interface name=\"ifn_link2\" mac=\"".$an->data->{cgi}{anvil_node1_ifn_link2_mac}."\" />
		</interfaces>
	</node>
	<node name=\"".$an->data->{cgi}{anvil_node2_name}."\" uuid=\"".$an->data->{cgi}{anvil_node2_uuid}."\">
		<network>
			<bcn ip=\"".$an->data->{cgi}{anvil_node2_bcn_ip}."\" />
			<sn ip=\"".$an->data->{cgi}{anvil_node2_sn_ip}."\" />
			<ifn ip=\"".$an->data->{cgi}{anvil_node2_ifn_ip}."\" />
		</network>
		<ipmi>
			<on reference=\"ipmi_n02\" ip=\"".$an->data->{cgi}{anvil_node2_ipmi_ip}."\" netmask=\"$node2_ipmi_netmask\" user=\"".$an->data->{cgi}{anvil_node2_ipmi_user}."\" password=\"".$an->data->{cgi}{anvil_node2_ipmi_password}."\" gateway=\"\" />
		</ipmi>
		<pdu>
			<on reference=\"pdu01\" port=\"".$an->data->{cgi}{anvil_node2_pdu1_outlet}."\" />
			<on reference=\"pdu02\" port=\"".$an->data->{cgi}{anvil_node2_pdu2_outlet}."\" />
			<on reference=\"pdu03\" port=\"".$an->data->{cgi}{anvil_node2_pdu3_outlet}."\" />
			<on reference=\"pdu04\" port=\"".$an->data->{cgi}{anvil_node2_pdu4_outlet}."\" />
		</pdu>
		<kvm>
			<on reference=\"kvm_host\" port=\"\" />
		</kvm>
		<interfaces>
			<interface name=\"bcn_link1\" mac=\"".$an->data->{cgi}{anvil_node2_bcn_link1_mac}."\" />
			<interface name=\"bcn_link2\" mac=\"".$an->data->{cgi}{anvil_node2_bcn_link2_mac}."\" />
			<interface name=\"sn_link1\" mac=\"".$an->data->{cgi}{anvil_node2_sn_link1_mac}."\" />
			<interface name=\"sn_link2\" mac=\"".$an->data->{cgi}{anvil_node2_sn_link2_mac}."\" />
			<interface name=\"ifn_link1\" mac=\"".$an->data->{cgi}{anvil_node2_ifn_link1_mac}."\" />
			<interface name=\"ifn_link2\" mac=\"".$an->data->{cgi}{anvil_node2_ifn_link2_mac}."\" />
		</interfaces>
	</node>
	<common>
		<networks>
			<bcn netblock=\"".$an->data->{cgi}{anvil_bcn_network}."\" netmask=\"".$an->data->{cgi}{anvil_bcn_subnet}."\" gateway=\"\" defroute=\"no\" ethtool_opts=\"".$an->data->{cgi}{anvil_bcn_ethtool_opts}."\" />
			<sn netblock=\"".$an->data->{cgi}{anvil_sn_network}."\" netmask=\"".$an->data->{cgi}{anvil_sn_subnet}."\" gateway=\"\" defroute=\"no\" ethtool_opts=\"".$an->data->{cgi}{anvil_sn_ethtool_opts}."\" />
			<ifn netblock=\"".$an->data->{cgi}{anvil_ifn_network}."\" netmask=\"".$an->data->{cgi}{anvil_ifn_subnet}."\" gateway=\"".$an->data->{cgi}{anvil_ifn_gateway}."\" dns1=\"".$an->data->{cgi}{anvil_dns1}."\" dns2=\"".$an->data->{cgi}{anvil_dns2}."\" ntp1=\"".$an->data->{cgi}{anvil_ntp1}."\" ntp2=\"".$an->data->{cgi}{anvil_ntp2}."\" defroute=\"yes\" ethtool_opts=\"".$an->data->{cgi}{anvil_ifn_ethtool_opts}."\" />
			<bonding opts=\"mode=1 miimon=100 use_carrier=1 updelay=120000 downdelay=0\">
				<bcn name=\"bcn_bond1\" primary=\"bcn_link1\" secondary=\"bcn_link2\" />
				<sn name=\"sn_bond1\" primary=\"sn_link1\" secondary=\"sn_link2\" />
				<ifn name=\"ifn_bond1\" primary=\"ifn_link1\" secondary=\"ifn_link2\" />
			</bonding>
			<bridges>
				<bridge name=\"ifn_bridge1\" on=\"ifn\" />
			</bridges>
			<mtu size=\"".$an->data->{cgi}{anvil_mtu_size}."\" />
		</networks>
		<repository urls=\"".$an->data->{cgi}{anvil_repositories}."\" />
		<media_library size=\"".$an->data->{cgi}{anvil_media_library_size}."\" units=\"".$an->data->{cgi}{anvil_media_library_unit}."\" />
		<storage_pool_1 size=\"".$an->data->{cgi}{anvil_storage_pool1_size}."\" units=\"".$an->data->{cgi}{anvil_storage_pool1_unit}."\" />
		<anvil prefix=\"".$an->data->{cgi}{anvil_prefix}."\" sequence=\"".$an->data->{cgi}{anvil_sequence}."\" domain=\"".$an->data->{cgi}{anvil_domain}."\" password=\"".$an->data->{cgi}{anvil_password}."\" striker_user=\"".$an->data->{cgi}{striker_user}."\" striker_database=\"".$an->data->{cgi}{striker_database}."\" />
		<ssh keysize=\"8191\" />
		<cluster name=\"".$an->data->{cgi}{anvil_name}."\">
			<!-- Set the order to 'kvm' if building on KVM-backed VMs -->
			<fence order=\"ipmi,pdu\" post_join_delay=\"90\" delay=\"15\" delay_node=\"".$an->data->{cgi}{anvil_node1_name}."\" />
		</cluster>
		<drbd>
			<disk disk-barrier=\"".$an->data->{cgi}{'anvil_drbd_disk_disk-barrier'}."\" disk-flushes=\"".$an->data->{cgi}{'anvil_drbd_disk_disk-flushes'}."\" md-flushes=\"".$an->data->{cgi}{'anvil_drbd_disk_md-flushes'}."\" />
			<options cpu-mask=\"".$an->data->{cgi}{'anvil_drbd_options_cpu-mask'}."\" />
			<net max-buffers=\"".$an->data->{cgi}{'anvil_drbd_net_max-buffers'}."\" sndbuf-size=\"".$an->data->{cgi}{'anvil_drbd_net_sndbuf-size'}."\" rcvbuf-size=\"".$an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'}."\" />
		</drbd>
		<switch>
			<switch name=\"".$an->data->{cgi}{anvil_switch1_name}."\" ip=\"".$an->data->{cgi}{anvil_switch1_ip}."\" />
";

		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_switch2_name", value1 => $an->data->{cgi}{anvil_switch2_name},
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{cgi}{anvil_switch2_name}) && ($an->data->{cgi}{anvil_switch2_name} ne "--"))
		{
			$xml .= "\t\t\t<switch name=\"".$an->data->{cgi}{anvil_switch2_name}."\" ip=\"".$an->data->{cgi}{anvil_switch2_ip}."\" />";
		}
		$xml .= "
		</switch>
		<ups>
			<ups name=\"".$an->data->{cgi}{anvil_ups1_name}."\" type=\"apc\" port=\"3551\" ip=\"".$an->data->{cgi}{anvil_ups1_ip}."\" />
			<ups name=\"".$an->data->{cgi}{anvil_ups2_name}."\" type=\"apc\" port=\"3552\" ip=\"".$an->data->{cgi}{anvil_ups2_ip}."\" />
		</ups>
		<pts>
			<pts name=\"".$an->data->{cgi}{anvil_pts1_name}."\" type=\"raritan\" port=\"161\" ip=\"".$an->data->{cgi}{anvil_pts1_ip}."\" />
			<pts name=\"".$an->data->{cgi}{anvil_pts2_name}."\" type=\"raritan\" port=\"161\" ip=\"".$an->data->{cgi}{anvil_pts2_ip}."\" />
		</pts>
		<pdu>";
		# PDU 1 and 2 always exist.
		my $pdu1_agent = $an->data->{cgi}{anvil_pdu1_agent} ? $an->data->{cgi}{anvil_pdu1_agent} : $an->data->{sys}{install_manifest}{anvil_pdu_agent};
		$xml .= "
			<pdu reference=\"pdu01\" name=\"".$an->data->{cgi}{anvil_pdu1_name}."\" ip=\"".$an->data->{cgi}{anvil_pdu1_ip}."\" agent=\"$pdu1_agent\" />";
		my $pdu2_agent = $an->data->{cgi}{anvil_pdu2_agent} ? $an->data->{cgi}{anvil_pdu2_agent} : $an->data->{sys}{install_manifest}{anvil_pdu_agent};
		$xml .= "
			<pdu reference=\"pdu02\" name=\"".$an->data->{cgi}{anvil_pdu2_name}."\" ip=\"".$an->data->{cgi}{anvil_pdu2_ip}."\" agent=\"$pdu2_agent\" />";
		if ($an->data->{cgi}{anvil_pdu3_name})
		{
			my $pdu3_agent = $an->data->{cgi}{anvil_pdu3_agent} ? $an->data->{cgi}{anvil_pdu3_agent} : $an->data->{sys}{install_manifest}{anvil_pdu_agent};
			$xml .= "
			<pdu reference=\"pdu03\" name=\"".$an->data->{cgi}{anvil_pdu3_name}."\" ip=\"".$an->data->{cgi}{anvil_pdu3_ip}."\" agent=\"$pdu3_agent\" />";
		}
		if ($an->data->{cgi}{anvil_pdu4_name})
		{
			my $pdu4_agent = $an->data->{cgi}{anvil_pdu4_agent} ? $an->data->{cgi}{anvil_pdu4_agent} : $an->data->{sys}{install_manifest}{anvil_pdu_agent};
			$xml .= "
			<pdu reference=\"pdu04\" name=\"".$an->data->{cgi}{anvil_pdu4_name}."\" ip=\"".$an->data->{cgi}{anvil_pdu4_ip}."\" agent=\"$pdu4_agent\" />";
		}
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "sys::install_manifest::use_anvil-kick-apc-ups", value1 => $an->data->{sys}{install_manifest}{'use_anvil-kick-apc-ups'},
			name2 => "sys::install_manifest::use_anvil-safe-start",   value2 => $an->data->{sys}{install_manifest}{'use_anvil-safe-start'},
			name3 => "sys::install_manifest::use_scancore",           value3 => $an->data->{sys}{install_manifest}{use_scancore},
		}, file => $THIS_FILE, line => __LINE__});
		my $say_use_anvil_kick_apc_ups = $an->data->{sys}{install_manifest}{'use_anvil-kick-apc-ups'} ? "true" : "false";
		my $say_use_anvil_safe_start   = $an->data->{sys}{install_manifest}{'use_anvil-safe-start'}   ? "true" : "false";
		my $say_use_scancore           = $an->data->{sys}{install_manifest}{use_scancore}             ? "true" : "false";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "say_use_anvil_kick_apc_ups", value1 => $say_use_anvil_kick_apc_ups,
			name2 => "say_use_anvil-safe-start",   value2 => $say_use_anvil_safe_start,
			name3 => "say_use_scancore",           value3 => $say_use_scancore,
		}, file => $THIS_FILE, line => __LINE__});
		
		$xml .= "
		</pdu>
		<ipmi>
			<ipmi reference=\"ipmi_n01\" agent=\"fence_ipmilan\" />
			<ipmi reference=\"ipmi_n02\" agent=\"fence_ipmilan\" />
		</ipmi>
		<kvm>
			<kvm reference=\"kvm_host\" ip=\"192.168.122.1\" user=\"root\" password=\"\" password_script=\"\" agent=\"fence_virsh\" />
		</kvm>
		<striker>
			<striker name=\"".$an->data->{cgi}{anvil_striker1_name}."\" bcn_ip=\"".$an->data->{cgi}{anvil_striker1_bcn_ip}."\" ifn_ip=\"".$an->data->{cgi}{anvil_striker1_ifn_ip}."\" database=\"\" user=\"\" password=\"\" uuid=\"\" />
			<striker name=\"".$an->data->{cgi}{anvil_striker2_name}."\" bcn_ip=\"".$an->data->{cgi}{anvil_striker2_bcn_ip}."\" ifn_ip=\"".$an->data->{cgi}{anvil_striker2_ifn_ip}."\" database=\"\" user=\"\" password=\"\" uuid=\"\" />
		</striker>
		<update os=\"true\" />
		<iptables>
			<vnc ports=\"".$an->data->{cgi}{anvil_open_vnc_ports}."\" />
		</iptables>
		<servers>
			<!-- This isn't used anymore, but this section may be useful for other things in the future, -->
			<!-- <provision use_spice_graphics=\"0\" /> -->
		</servers>
		<tools>
			<use anvil-safe-start=\"$say_use_anvil_safe_start\" anvil-kick-apc-ups=\"$say_use_anvil_kick_apc_ups\" scancore=\"$say_use_scancore\" />
		</tools>
	</common>
</config>
		";
	}
	
	# Record it to the database.
	if (not $an->data->{cgi}{manifest_uuid})
	{
		# Insert it.
		   $an->data->{cgi}{manifest_uuid} = $an->Get->uuid();
		my $query = "
INSERT INTO 
    manifests 
(
    manifest_uuid, 
    manifest_data, 
    manifest_note, 
    modified_date 
) VALUES (
    ".$an->data->{sys}{use_db_fh}->quote($an->data->{cgi}{manifest_uuid}).", 
    ".$an->data->{sys}{use_db_fh}->quote($xml).", 
    NULL, 
    ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
);";
		$query =~ s/'NULL'/NULL/g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Update it
		my $query = "
UPDATE 
    public.manifests 
SET
    manifest_data = ".$an->data->{sys}{use_db_fh}->quote($xml).", 
    modified_date = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
WHERE 
    manifest_uuid = ".$an->data->{sys}{use_db_fh}->quote($an->data->{cgi}{manifest_uuid})." 
;";
		$query =~ s/'NULL'/NULL/g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::manifest_uuid", value1 => $an->data->{cgi}{manifest_uuid}, 
	}, file => $THIS_FILE, line => __LINE__});
	return($an->data->{cgi}{manifest_uuid});
}

# This reads in the cache for the target and checks or sets the power state of the target UUID, if possible.
sub target_power
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "target_power" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $task   = $parameter->{task}   ? $parameter->{task}   : "status";
	my $target = $parameter->{target} ? $parameter->{target} : "";
	my $state  = "unknown";
	
	if (($task ne "status") && ($task ne "on") && ($task ne "off"))
	{
		# Bad task.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0111", message_variables => { task => $task }, code => 111, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	if (not $target)
	{
		# No target UUID
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0112", code => 112, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	elsif (not $an->Validate->is_uuid({uuid => $target}))
	{
		# Not a valid UUID.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0113", message_variables => { target => $target }, code => 113, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Check the power state.
	my $power_check = $an->ScanCore->read_cache({target => $target, type => "power_check"});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "power_check", value1 => $power_check, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If I don't have a power_check, see if anyone else does.
	if (not $power_check)
	{
		$power_check = $an->ScanCore->read_cache({target => $target, type => "power_check", source => "any"});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "power_check", value1 => $power_check, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Now check, if we can.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "power_check", value1 => $power_check, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($power_check)
	{
		# Convert the '-a X' to an IP address, if needed.
		my $target = ($power_check =~ /-a\s(.*?)\s/)[0];
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "target", value1 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		if (not $an->Validate->is_ipv4({ip => $target}))
		{
			my $ip = $an->Get->ip({host => $target});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "ip", value1 => $ip,
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($ip)
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => ">> power_check", value1 => $power_check,
				}, file => $THIS_FILE, line => __LINE__});
				
				$power_check =~ s/$target/$ip/;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "<< power_check", value1 => $power_check,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		$power_check =~ s/#!action!#/$task/;
		$power_check =~ s/^.*fence_/fence_/;
		
		my $shell_call = $power_check;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ / On$/i)
			{
				$state = "on";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "state", value1 => $state,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ / Off$/i)
			{
				$state = "off";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "state", value1 => $state,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		close $file_handle;
	}
	else
	{
		# Couldn't find a power_check comman in the cache.
		$an->Log->entry({log_level => 1, message_key => "warning_message_0017", message_variables => {
			name => $an->data->{sys}{uuid_to_name}{$target},
			uuid => $target,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Set to 'unknown', 'on' or 'off'.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "state", value1 => $state,
	}, file => $THIS_FILE, line => __LINE__});
	return($state);
}

# This updates the server's stop_reason (if it's changed)
sub update_server_stop_reason
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "update_server_stop_reason" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $server_name = $parameter->{server_name} ? $parameter->{server_name} : "";
	my $stop_reason = $parameter->{stop_reason} ? $parameter->{stop_reason} : "NULL";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "server_name", value1 => $server_name,
		name2 => "stop_reason", value2 => $stop_reason,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Die if I wasn't passed a server name or stop reason.
	if (not $server_name)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0158", code => 159, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	my $server_data = $an->ScanCore->get_servers();
	foreach my $hash_ref (@{$server_data})
	{
		my $this_server_uuid        = $hash_ref->{server_uuid};
		my $this_server_name        = $hash_ref->{server_name};
		my $this_server_stop_reason = $hash_ref->{server_stop_reason};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "this_server_uuid",        value1 => $this_server_uuid,
			name2 => "this_server_name",        value2 => $this_server_name,
			name3 => "this_server_stop_reason", value3 => $this_server_stop_reason,
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($server_name eq $this_server_name)
		{
			# Found the server. Has the stop_reason changed?
			if ($stop_reason ne $this_server_stop_reason)
			{
				# Yes, update.
				my $query = "
UPDATE 
    servers 
SET 
    server_stop_reason = ".$an->data->{sys}{use_db_fh}->quote($stop_reason).", 
    modified_date      = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    server_uuid        = ".$an->data->{sys}{use_db_fh}->quote($this_server_uuid)." 
";
				$query =~ s/'NULL'/NULL/g;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "query", value1 => $query
				}, file => $THIS_FILE, line => __LINE__});
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return(0);
}

#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

1;
