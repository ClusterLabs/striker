package AN::Tools::ScanCore;
# 
# This module contains methods use to get data from the ScanCore database.
# 

use strict;
use warnings;
use Data::Dumper;

our $VERSION  = "0.1.001";
my $THIS_FILE = "ScanCore.pm";


sub new
{
	#print "$THIS_FILE ".__LINE__."; In AN::Storage->new()\n";
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

# Get a list of Anvil! Install Manifests as an array of hash references
sub get_manifests
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
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

# Get a list of Anvil! hosts as an array of hash references
sub get_hosts
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	my $query = "
SELECT 
    host_uuid, 
    host_name, 
    host_type, 
    host_emergency_stop, 
    host_stop_reason, 
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
		my $modified_date       = $row->[5];
		$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
			name1 => "host_uuid",           value1 => $host_uuid, 
			name2 => "host_name",           value2 => $host_name, 
			name3 => "host_type",           value3 => $host_type, 
			name4 => "host_emergency_stop", value4 => $host_emergency_stop, 
			name5 => "host_stop_reason",    value5 => $host_stop_reason, 
			name6 => "modified_date",       value6 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$return}, {
			host_uuid		=>	$host_uuid,
			host_name		=>	$host_name, 
			host_type		=>	$host_type, 
			host_emergency_stop	=>	$host_emergency_stop, 
			host_stop_reason	=>	$host_stop_reason, 
			modified_date		=>	$modified_date, 
		};
	}
	
	return($return);
}

# Get a list of Anvil! nodes as an array of hash references
sub get_nodes
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0011", message_variables => {
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

# Get a list of Anvil! systems as an array of hash references
sub get_anvils
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
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

# Get a list of Anvil! SMTP mail servers as an array of hash references
sub get_smtp
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
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
		my $smtp_uuid           = $row->[0];
		my $smtp_server         = $row->[1];
		my $smtp_port           = $row->[2];
		my $smtp_username       = $row->[3];
		my $smtp_password       = $row->[4];
		my $smtp_security       = $row->[5];
		my $smtp_authentication = $row->[6];
		my $smtp_helo_domain    = $row->[7];
		my $modified_date       = $row->[8];
		$an->Log->entry({log_level => 2, message_key => "an_variables_0008", message_variables => {
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

# Get a list of Anvil! Owners as an array of hash references
sub get_owners
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
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

# Get a list of recipients (links between Anvil! systems and who receives alert notifications from it).
sub get_recipients
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
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

# Get a list of Anvil! Owners as an array of hash references
sub get_notifications
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0008", message_variables => {
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

# This updates (or inserts) a record in the 'nodes' table.
sub insert_or_update_nodes
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0009", message_variables => {
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
			$node_uuid = $row->[0];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0082", code => 82, file => "$THIS_FILE", line => __LINE__});
		}
		if (not $node_host_uuid)
		{
			$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0083", code => 83, file => "$THIS_FILE", line => __LINE__});
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
			my $old_node_anvil_uuid  = $row->[0]; 
			my $old_node_host_uuid   = $row->[1]; 
			my $old_node_remote_ip   = $row->[2] ? $row->[2] : "NULL"; 
			my $old_node_remote_port = $row->[3] ? $row->[3] : "NULL"; 
			my $old_node_note        = $row->[4] ? $row->[4] : "NULL"; 
			my $old_node_bcn         = $row->[5] ? $row->[5] : "NULL"; 
			my $old_node_sn          = $row->[6] ? $row->[6] : "NULL"; 
			my $old_node_ifn         = $row->[7] ? $row->[7] : "NULL"; 
			my $old_node_password    = $row->[8] ? $row->[8] : "NULL"; 
			$an->Log->entry({log_level => 2, message_key => "an_variables_0009", message_variables => {
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
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($node_uuid);
}

# This updates (or inserts) a record in the 'anvils' table.
sub insert_or_update_anvils
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
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
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0079", code => 79, file => "$THIS_FILE", line => __LINE__});
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
			$anvil_uuid = $row->[0];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0080", code => 80, file => "$THIS_FILE", line => __LINE__});
		}
		if (not $anvil_smtp_uuid)
		{
			$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0081", code => 81, file => "$THIS_FILE", line => __LINE__});
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
			my $old_anvil_owner_uuid  = $row->[0];
			my $old_anvil_smtp_uuid   = $row->[1];
			my $old_anvil_name        = $row->[2];
			my $old_anvil_description = $row->[3];
			my $old_anvil_note        = $row->[4];
			my $old_anvil_password    = $row->[5];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
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
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($anvil_uuid);
}

# This updates (or inserts) a record in the 'notifications' table.
sub insert_or_update_notifications
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
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
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0088", code => 88, file => "$THIS_FILE", line => __LINE__});
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
			$notify_uuid = $row->[0];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			my $old_notify_name     = $row->[0];
			my $old_notify_target   = $row->[1];
			my $old_notify_language = $row->[2];
			my $old_notify_level    = $row->[3];
			my $old_notify_units    = $row->[4];
			my $old_notify_note     = $row->[5] ? $row->[5] : "NULL";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
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
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($notify_uuid);
}

# This updates (or inserts) a record in the 'recipients' table.
sub insert_or_update_recipients
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $recipient_uuid         = $parameter->{recipient_uuid}         ? $parameter->{recipient_uuid}         : "";
	my $recipient_anvil_uuid   = $parameter->{recipient_anvil_uuid}   ? $parameter->{recipient_anvil_uuid}   : "";
	my $recipient_notify_uuid  = $parameter->{recipient_notify_uuid}  ? $parameter->{recipient_notify_uuid}  : "";
	my $recipient_notify_level = $parameter->{recipient_notify_level} ? $parameter->{recipient_notify_level} : "NULL";
	my $recipient_note         = $parameter->{recipient_note}         ? $parameter->{recipient_note}         : "NULL";
	if ((not $recipient_anvil_uuid) or (not $recipient_notify_uuid))
	{
		# Throw an error and exit.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0091", code => 91, file => "$THIS_FILE", line => __LINE__});
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
			$recipient_uuid = $row->[0];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			my $old_recipient_anvil_uuid   = $row->[0];
			my $old_recipient_notify_uuid  = $row->[1];
			my $old_recipient_notify_level = $row->[2] ? $row->[2] : "NULL";
			my $old_recipient_note         = $row->[3] ? $row->[3] : "NULL";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
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
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($recipient_uuid);
}

# This updates (or inserts) a record in the 'owners' table.
sub insert_or_update_owners
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $owner_uuid = $parameter->{owner_uuid} ? $parameter->{owner_uuid} : "";
	my $owner_name = $parameter->{owner_name} ? $parameter->{owner_name} : "";
	my $owner_note = $parameter->{owner_note} ? $parameter->{owner_note} : "NULL";
	if (not $owner_name)
	{
		# Throw an error and exit.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0078", code => 78, file => "$THIS_FILE", line => __LINE__});
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
			$owner_uuid = $row->[0];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			my $old_owner_name = $row->[0];
			my $old_owner_note = $row->[1];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($owner_uuid);
}

# This updates (or inserts) a record in the 'smtp' table.
sub insert_or_update_smtp
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
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
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0077", code => 77, file => "$THIS_FILE", line => __LINE__});
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
			$smtp_uuid = $row->[0];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			my $old_smtp_server         = $row->[0];
			my $old_smtp_port           = $row->[1] ? $row->[1] : "";
			my $old_smtp_username       = $row->[2] ? $row->[2] : "";
			my $old_smtp_password       = $row->[3] ? $row->[3] : "";
			my $old_smtp_security       = $row->[4];
			my $old_smtp_authentication = $row->[5];
			my $old_smtp_helo_domain    = $row->[6] ? $row->[6] : "";
			my $old_smtp_note           = $row->[7] ? $row->[7] : "NULL";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0008", message_variables => {
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
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($smtp_uuid);
}

# This parses an Install Manifest
sub parse_install_manifest
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	### TODO: Support getting a UUID
	if (not $parameter->{uuid})
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0093", code => 93, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	
	my $manifest_data = "";
	my $return        = $an->ScanCore->get_manifests($an);
	foreach my $hash_ref (keys %{$return})
	{
		if ($parameter->{uuid} eq $hash_ref->{manifest_uuid})
		{
			$manifest_data = $hash_ref->{manifest_data};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "manifest_data", value1 => $manifest_data,
			}, file => $THIS_FILE, line => __LINE__});
			last;
		}
	}
	
	if (not $manifest_data)
	{
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0094", message_variables => { uuid => $parameter->{uuid} }, code => 94, file => "$THIS_FILE", line => __LINE__});
		return(1);
	}
	
	my $uuid = $parameter->{uuid};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
							$an->Log->entry({log_level => 2, message_key => "tools_log_0027", message_variables => {
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
				my $uuid = $data->{node}{$node}{uuid};
				$an->data->{install_manifest}{$uuid}{node}{$node}{uuid} = $uuid ? $uuid : "";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "install_manifest::${uuid}::node::${node}::uuid", value1 => $an->data->{install_manifest}{$uuid}{node}{$node}{uuid},
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# What's this?
				$an->Log->entry({log_level => 2, message_key => "tools_log_0028", message_variables => {
					node    => $node, 
					uuid    => $uuid, 
					element => $b, 
				}, file => $THIS_FILE, line => __LINE__});
				foreach my $b (@{$data->{node}{$node}{$a}})
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
						#<mtu size=\"$an->data->{cgi}{anvil_mtu_size}\" />
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
				$an->Log->entry({log_level => 2, message_key => "tools_log_0029", message_variables => {
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
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
		$an->Log->entry({log_level => 4, message_key => "an_variables_0013", message_variables => {
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

1;
