package AN::Tools::Web;
# 
# This module will be used to process anything to do with presenting data to a user's web browser.
# 

use strict;
use warnings;
use Data::Dumper;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Encode;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Web.pm";


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

# This builds an HTML select field.
sub build_select
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Required
	my $name     = $parameter->{name};
	my $options  = $parameter->{options};
	# Optional
	my $id       = $parameter->{id}       ? $parameter->{id}       : $name;
	my $sort     = $parameter->{'sort'}   ? $parameter->{'sort'}   : 1;	# Sort the entries?
	my $width    = $parameter->{width}    ? $parameter->{width}    : 0;	# 0 = let the browser set the width
	my $blank    = $parameter->{blank}    ? $parameter->{blank}    : 0;	# Add a blank/null entry?
	my $selected = $parameter->{selected} ? $parameter->{selected} : "";	# Pre-select an option?
	$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
		name1 => "name",     value1 => $name, 
		name2 => "options",  value2 => $options, 
		name3 => "sort",     value3 => $sort, 
		name4 => "width",    value4 => $width, 
		name5 => "blank",    value5 => $blank, 
		name6 => "selected", value6 => $selected, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $select = "<select name=\"$name\" id=\"$id\">\n";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "select", value1 => $select,
	}, file => $THIS_FILE, line => __LINE__});
	if ($width)
	{
		$select = "<select name=\"$name\" id=\"$id\" style=\"width: ${width}px;\">\n";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "select", value1 => $select,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Insert a blank line.
	if ($blank)
	{
		$select .= "<option value=\"\"></option>\n";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "select", value1 => $select,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# This needs to be smarter.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "sort", value1 => $sort,
	}, file => $THIS_FILE, line => __LINE__});
	if ($sort)
	{
		foreach my $entry (sort {$a cmp $b} @{$options})
		{
			next if not $entry;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "entry", value1 => $entry,
			}, file => $THIS_FILE, line => __LINE__});
			if ($entry =~ /^(.*?)#!#(.*)$/)
			{
				my $value       =  $1;
				my $description =  $2;
				   $select      .= "<option value=\"$value\">$description</option>\n";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "value",       value1 => $value,
					name2 => "description", value2 => $description,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				$select .= "<option value=\"$entry\">$entry</option>\n";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "entry", value1 => $entry,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	else
	{
		foreach my $entry (@{$options})
		{
			next if not $entry;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "entry", value1 => $entry,
			}, file => $THIS_FILE, line => __LINE__});
			if ($entry =~ /^(.*?)#!#(.*)$/)
			{
				my $value       =  $1;
				my $description =  $2;
				   $select      .= "<option value=\"$value\">$description</option>\n";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "value",       value1 => $value,
					name2 => "description", value2 => $description,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				$select .= "<option value=\"$entry\">$entry</option>\n";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "entry", value1 => $entry,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "selected", value1 => $selected,
	}, file => $THIS_FILE, line => __LINE__});
	if ($selected)
	{
		$select =~ s/value=\"$selected\">/value=\"$selected\" selected>/m;
	}
	
	$select .= "</select>\n";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "select", value1 => $select,
	}, file => $THIS_FILE, line => __LINE__});
	
	return ($select);
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

# This updates (or inserts) a record in the 'owners' table.
sub insert_or_update_owners
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $owner_uuid = $parameter->{owner_uuid} ? $parameter->{owner_uuid} : "";
	my $owner_name = $parameter->{owner_name} ? $parameter->{owner_name} : "";
	if (not $owner_name)
	{
		# Throw an error and exit.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0078", code => 78, file => "$THIS_FILE", line => __LINE__});
	}
	
	# If we don't have a UUID, see if we can find one for the given SMTP server name.
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
    modified_date 
) VALUES (
    ".$an->data->{sys}{use_db_fh}->quote($owner_uuid).", 
    ".$an->data->{sys}{use_db_fh}->quote($owner_name).", 
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
    owner_name 
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "old_owner_name", value1 => $old_owner_name, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Anything change?
			if ($old_owner_name ne $owner_name)
			{
				# Something changed, save.
				my $query = "
UPDATE 
    owners 
SET 
    owner_name    = ".$an->data->{sys}{use_db_fh}->quote($owner_name).", 
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
    smtp_helo_domain 
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
				name1 => "old_smtp_server",         value1 => $old_smtp_server, 
				name2 => "old_smtp_port",           value2 => $old_smtp_port, 
				name3 => "old_smtp_username",       value3 => $old_smtp_username, 
				name4 => "old_smtp_password",       value4 => $old_smtp_password, 
				name5 => "old_smtp_security",       value5 => $old_smtp_security, 
				name6 => "old_smtp_authentication", value6 => $old_smtp_authentication, 
				name7 => "old_smtp_helo_domain",    value7 => $old_smtp_helo_domain, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Anything change?
			if (($old_smtp_server         ne $smtp_server)         or 
			    ($old_smtp_port           ne $smtp_port)           or 
			    ($old_smtp_username       ne $smtp_username)       or 
			    ($old_smtp_password       ne $smtp_password)       or 
			    ($old_smtp_security       ne $smtp_security)       or 
			    ($old_smtp_authentication ne $smtp_authentication) or 
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

# This reads in data from CGI
sub get_cgi
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Make sure we have an array reference of variables to read.
	my $variables = ref($parameter->{variables}) eq "ARRAY" ? $parameter->{variables} : "";
	if (not $variables)
	{
		# Throw an error and exit.
		$an->Alert->error({fatal => 1, title_key => "tools_title_0003", message_key => "error_message_0069", code => 69, file => "$THIS_FILE", line => __LINE__});
	}
	
	# Needed to read in passed CGI variables
	my $cgi = CGI->new();
	
	# This will store the string I was passed.
	$an->data->{sys}{cgi_string} = "?";
	foreach my $variable (@{$variables})
	{
		# A stray comma will cause a loop with no var name
		next if not $variable;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "variable", value1 => $variable, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# I auto-select the 'anvil' variable if only one is checked. Because of this, I don't want
		# to overwrite the empty CGI value. This prevents that.
		if (($variable eq "anvil") && ($an->data->{cgi}{anvil}))
		{
			$an->data->{sys}{cgi_string} .= "$variable=$an->data->{cgi}{$variable}&";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "variable", value1 => $variable, 
				name2 => "value",    value2 => $an->data->{cgi}{$variable},
			}, file => $THIS_FILE, line => __LINE__});
			next;
		}
		
		# Avoid "uninitialized" warning messages.
		$an->data->{cgi}{$variable} = "";
		if (defined $cgi->param($variable))
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "cgi->param($variable)", value1 => $cgi->param($variable)
			}, file => $THIS_FILE, line => __LINE__});
			if ($variable eq "file")
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "variable", value1 => $variable,
				}, file => $THIS_FILE, line => __LINE__});
				if (not $cgi->upload($variable))
				{
					# Empty file passed, looks like the user forgot to select a file to upload.
					$an->Log->entry({log_level => 2, message_key => "log_0016", file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					   $an->data->{cgi_fh}{$variable}       = $cgi->upload($variable);
					my $file                                = $an->data->{cgi_fh}{$variable};
					   $an->data->{cgi_mimetype}{$variable} = $cgi->uploadInfo($file)->{'Content-Type'};
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "variable",                value1 => $variable,
						name2 => "cgi_fh::$variable",       value2 => $an->data->{cgi_fh}{$variable},
						name3 => "cgi_mimetype::$variable", value3 => $an->data->{cgi_mimetype}{$variable},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			$an->data->{cgi}{$variable} = $cgi->param($variable);
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "cgi::${variable}", value1 => $an->data->{cgi}{$variable}, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Make this UTF8 if it isn't already.
			if (not Encode::is_utf8($an->data->{cgi}{$variable}))
			{
				$an->data->{cgi}{$variable} = Encode::decode_utf8( $an->data->{cgi}{$variable} );
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "cgi::${variable}", value1 => $an->data->{cgi}{$variable}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Log the variable and add to cgi_string, if set
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::${variable}", value1 => $an->data->{cgi}{$variable}, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{$variable})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "cgi::$variable", value1 => $an->data->{cgi}{$variable},
			}, file => $THIS_FILE, line => __LINE__});
			
			$an->data->{sys}{cgi_string} .= "$variable=".$an->data->{cgi}{$variable}."&";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "sys::cgi_string", value1 => $an->data->{sys}{cgi_string}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	# Clear the final '&' from sys::cgi_string
	$an->data->{sys}{cgi_string} =~ s/&$//;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::cgi_string", value1 => $an->data->{sys}{cgi_string}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	return(0);
}

# This returns a "More Info" link, *if* 'sys::disable_links' is not set.
sub more_info_link
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# TODO: Error if this is not set.
	my $url  = $parameter->{url} ? $parameter->{url} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "url", value1 => $url,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $link = $an->Web->template({file => "web.html", template => "more-info-link", replace => { url => $url }, no_comment => 1});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "link",               value1 => $link,
		name2 => "sys::disable_links", value2 => $an->data->{sys}{disable_links},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{disable_links})
	{
		$link = "&nbsp;";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "link", value1 => $link,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "link", value1 => $link,
	}, file => $THIS_FILE, line => __LINE__});
	return($link);
}

# This is presented when no access to a ScanCore database is available.
sub no_db_access
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	### TODO: Move these to 'common.html' once the clean-up is done.
	# Put together the frame of the page.
	my $back_image    = "";
	my $refresh_image = $an->Web->template({file => "common.html", template	=> "image", no_comment => 1, replace => {
			image_source => $an->data->{url}{skins}."/".$an->data->{sys}{skin}."/images/refresh.png",
			alt_text     => "#!string!button_0002!#",
			id           => "refresh_icon",
		}});
	my $header = $an->Web->template({file => "configure.html", template => "configure-header", replace => {
			back		=>	$back_image,
			refresh		=>	"<a href=\"".$an->data->{sys}{cgi_string}."\">$refresh_image</a>",,
		}});
	my $footer = $an->Web->template({file => "configure.html", template => "configure-footer"});
	
	my $menu = $an->Web->template({file => "configure.html", template => "no-database-access"});
	
	print $an->Web->template({
			file		=>	"configure.html",
			template	=>	"configure-main-page",
			replace		=>	{
				header		=>	$header, 
				body		=>	$menu, 
				footer		=>	$footer, 
			},
		});
	
	
	return(0);
}

# This takes the name of a template file, the name of a template section within the file, an optional hash
# containing replacement variables to feed into the template and an optional hash containing variables to
# pass into strings, and generates a page to display formatted according to the page.
sub template
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Make sure we got a file and template name.
	if (not $parameter->{file})
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0073", code => 73, file => "$THIS_FILE", line => __LINE__});
	}
	if (not $parameter->{template})
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0074", code => 74, file => "$THIS_FILE", line => __LINE__});
	}
	
	my $file       = $parameter->{file};
	my $template   = $parameter->{template};
	my $replace    = $parameter->{replace}    ? $parameter->{replace}    : {};
	my $no_comment = $parameter->{no_comment} ? $parameter->{no_comment} : 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "file",       value1 => $file,
		name2 => "template",   value2 => $template,
		name3 => "no_comment", value3 => $no_comment,
	}, file => $THIS_FILE, line => __LINE__});
	
	my @contents;
	my $template_file = $an->data->{path}{skins}."/".$an->data->{sys}{skin}."/".$file;
	
	# Make sure the file exists.
	if (not -e $template_file)
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0075", message_variables => { file => $template_file }, code => 75, file => "$THIS_FILE", line => __LINE__});
	}
	elsif (not -r $template_file)
	{
		my $user = getpwuid($<);
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0075", message_variables => { 
			file => $template_file,
			user => $user,
		}, code => 75, file => "$THIS_FILE", line => __LINE__});
	}
	
	# Read in the raw template.
	my $in_template = 0;
	my $shell_call  = $template_file;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "<$shell_call") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0016", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
	#binmode $file_handle, ":utf8:";
	while (<$file_handle>)
	{
		chomp;
		my $line = $_;
		
		if ($line =~ /<!-- start $template -->/)
		{
			$in_template = 1;
			next;
		}
		if ($line =~ /<!-- end $template -->/)
		{
			$in_template = 0;
			last;
		}
		if ($in_template)
		{
			# Read in the template.
			push @contents, $line;
		}
	}
	close $file_handle;
	
	# Now parse the contents for replacement keys.
	my $page = "";
	if (not $no_comment)
	{
		# Add the template opening comment
		my $comment = $an->String->get({key => "tools_log_0025", variables => { 
				template => $template, 
				file     => $file,
			}});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "comment", value1 => $comment,
		}, file => $THIS_FILE, line => __LINE__});
		$page .= "<!-- $comment -->\n";
	}
	foreach my $string (@contents)
	{
		# Replace the '#!replace!...!#' substitution keys.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => ">> string", value1 => $string,
		}, file => $THIS_FILE, line => __LINE__});
		
		$string = $an->String->_process_string_replace({
			string   => $string,
			replace  => $replace, 
			file     => $template_file,
			template => $template,
		});
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "<< string", value1 => $string,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Process all the #!...!# escape variables.
		($string) = $an->String->_process_string({string => $string, variables => {}});

		$page .= "$string\n";
	}
	if (not $no_comment)
	{
		# Add the closing comment
		my $comment = $an->String->get({key => "tools_log_0026", variables => { 
				template => $template, 
				file     => $file,
			}});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "comment", value1 => $comment,
		}, file => $THIS_FILE, line => __LINE__});
		$page .= "<!-- $comment -->\n";
	}
	
	return($page);
}

1;
