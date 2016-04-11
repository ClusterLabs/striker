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
    notify_auto_add, 
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
		my $notify_auto_add = $row->[6];
		my $notify_note     = $row->[7] ? $row->[7] : "";
		my $modified_date   = $row->[8];
		$an->Log->entry({log_level => 2, message_key => "an_variables_0009", message_variables => {
			name1 => "notify_uuid",     value1 => $notify_uuid, 
			name2 => "notify_name",     value2 => $notify_name, 
			name3 => "notify_target",   value3 => $notify_target, 
			name4 => "notify_language", value4 => $notify_language, 
			name5 => "notify_level",    value5 => $notify_level, 
			name6 => "notify_units",    value6 => $notify_units, 
			name7 => "notify_auto_add", value7 => $notify_auto_add, 
			name8 => "notify_note",     value8 => $notify_note, 
			name9 => "modified_date",   value9 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$return}, {
			notify_uuid	=>	$notify_uuid,
			notify_name	=>	$notify_name, 
			notify_target	=>	$notify_target, 
			notify_language	=>	$notify_language, 
			notify_level	=>	$notify_level, 
			notify_units	=>	$notify_units, 
			notify_auto_add	=>	$notify_auto_add, 
			notify_note	=>	$notify_note, 
			modified_date	=>	$modified_date, 
		};
	}
	
	return($return);
}

1;
