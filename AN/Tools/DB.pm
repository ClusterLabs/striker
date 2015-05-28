package AN::Tools::DB;

# TODO: Move the ScanCore stuff into another Module and make this more generic.

use strict;
use warnings;
use DBI;

our $VERSION  = "0.1.001";
my $THIS_FILE = "DB.pm";


sub new
{
	my $class = shift;
	
	my $self = {};
	
	bless $self, $class;
	
	return ($self);
}

# Get a handle on the AN::Tools object. I know that technically that is a
# sibling module, but it makes more sense in this case to think of it as a
# parent.
sub parent
{
	my $self   = shift;
	my $parent = shift;
	
	$self->{HANDLE}{TOOLS} = $parent if $parent;
	
	return ($self->{HANDLE}{TOOLS});
}

# This records data to one or all of the databases. If an ID is passed, the query is written to one database only. Otherwise, it will be written to all DBs.
sub do_db_write
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Setup my variables.
	my ($id, $query);

	$id    = $parameter->{id}    ? $parameter->{id}    : "";
	$query = $parameter->{query} ? $parameter->{query} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "id", value1 => $id, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If I don't have a query, die.
	if (not $query)
	{
		print $an->String->get({ key => "scancore_message_0002", variables => {
			title		=>	$an->String->get({key => "scancore_title_0003"}),
			message		=>	$an->String->get({key => "scancore_error_0011"}),
		}}), "\n";
		exit(1);
	}
	
	# This array will hold either just the passed DB ID or all of them, if
	# no ID was specified.
	my @db_ids;
	if ($id)
	{
		push @db_ids, $id;
	}
	else
	{
		foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
		{
			push @db_ids, $id;
		}
	}
	
	# Sort out if I have one or many queries.
	my $is_array = 0;
	my @query;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	if (ref($query) eq "ARRAY")
	{
		# Multiple things to enter.
		$is_array = 1;
		foreach my $this_query (@{$query})
		{
			push @query, $this_query;
		}
	}
	else
	{
		push @query, $query;
	}
	foreach my $id (@db_ids)
	{
		# Do the actual query(ies)
		if ($is_array)
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "is_array", value1 => $is_array
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{dbh}{$id}->begin_work;
		}
		foreach my $query (@query)
		{
			# Record the query
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "id",    value1 => $id,
				name2 => "query", value2 => $query
			}, file => $THIS_FILE, line => __LINE__});
			
			# Just one query.
			$an->data->{dbh}{$id}->do($query) or $an->Alert->error({fatal => 1, title_key => "scancore_title_0003", message_key => "scancore_error_0012", message_variables => { 
								query    => $query, 
								server   => "$an->data->{scancore}{db}{$id}{host}:$an->data->{scancore}{db}{$id}{port} -> $an->data->{scancore}{db}{$id}{name}", 
								db_error => $DBI::errstr
							}, code => 2, file => "$THIS_FILE", line => __LINE__});
		}
		
		# Commit the changes.
		if ($is_array)
		{
			$an->data->{dbh}{$id}->commit();
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "is_array", value1 => $is_array
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

# This does a database query and returns the resulting array. It must be passed
# the ID of the database to connect to.
sub do_db_query
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Setup my variables.
	my ($id, $query);
	
	# Values passed in a hash, good.
	$id    = $parameter->{id}    ? $parameter->{id}    : $an->data->{sys}{read_db_id};
	$query = $parameter->{query} ? $parameter->{query} : "";	# This should throw an error
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "id",    value1 => $id, 
		name2 => "query", value2 => $query
	}, file => $THIS_FILE, line => __LINE__});
	
	# Prepare the query
	my $DBreq = $an->data->{dbh}{$id}->prepare($query) or $an->Alert->error({fatal => 1, title_key => "scancore_title_0003", message_key => "scancore_error_0001", message_variables => { query => $query, server => "$an->data->{scancore}{db}{$id}{host}:$an->data->{scancore}{db}{$id}{port} -> $an->data->{scancore}{db}{$id}{name}", db_error => $DBI::errstr}, code => 2, file => "$THIS_FILE", line => __LINE__});
	
	# Execute on the query
	$DBreq->execute() or $an->Alert->error({ fatal => 1, title_key => "scancore_title_0003", message_key => "scancore_error_0002", message_variables => {query => $query, server => "$an->data->{scancore}{db}{$id}{host}:$an->data->{scancore}{db}{$id}{port} -> $an->data->{scancore}{db}{$id}{name}", db_error => $DBI::errstr, }, code => 3, file => "$THIS_FILE", line => __LINE__});
	
	# Return the array
	return($DBreq->fetchall_arrayref());
}

# This cleanly closes any open file handles.
sub disconnect_from_databases
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	
	# Clear the old timestamp.
	$an->data->{sys}{db_timestamp} = "";
	
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
	{
		$an->data->{dbh}{$id}->disconnect;
	}
	
	return(0);
}

# This will connect to the databases and record their database handles. It will
# also initialize the databases, if needed.
sub connect_to_databases
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 3, message_key => "scancore_log_0001", message_variables => { function => "connect_to_databases" }, file => $THIS_FILE, line => __LINE__});
	
	my $file = $parameter->{file};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "file", value1 => $file, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $connections = 0;
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
	{
		my $driver            = "DBI:Pg";
		my $host              = $an->data->{scancore}{db}{$id}{host}              ? $an->data->{scancore}{db}{$id}{host}              : ""; # This should fail
		my $port              = $an->data->{scancore}{db}{$id}{port}              ? $an->data->{scancore}{db}{$id}{port}              : 5432;
		my $name              = $an->data->{scancore}{db}{$id}{name}              ? $an->data->{scancore}{db}{$id}{name}              : ""; # This should fail
		my $user              = $an->data->{scancore}{db}{$id}{user}              ? $an->data->{scancore}{db}{$id}{user}              : ""; # This should fail
		my $password          = $an->data->{scancore}{db}{$id}{password}          ? $an->data->{scancore}{db}{$id}{password}          : "";
		
		# These are not used yet.
		my $postgres_password = $an->data->{scancore}{db}{$id}{postgres_password} ? $an->data->{scancore}{db}{$id}{postgres_password} : "";
		my $initialize        = $an->data->{scancore}{db}{$id}{initialize}        ? $an->data->{scancore}{db}{$id}{initialize}        : 0;
		
		# Log what we're doing.
		$an->Log->entry({log_level => 3, title_key => "scancore_title_0001", message_key => "scancore_log_0002", message_variables => {
				id			=>	$id,
				driver			=>	$driver,
				host			=>	$host,
				port			=>	$port,
				postgres_password	=>	$postgres_password,
				name			=>	$name,
				user			=>	$user,
				password		=>	$password,
				initialize		=>	$initialize,
			}, file => $THIS_FILE, line => __LINE__});
		
		# Assemble my connection string
		my $db_connect_string = "$driver:dbname=$name;host=$host;port=$port";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "db_connect_string", value1 => $db_connect_string
		}, file => $THIS_FILE, line => __LINE__});
		
		# Connect!
		my $dbh = "";
		### NOTE: The AN::Tools::DB->do_db_write() method, when passed
		###       an array, will automatically disable autocommit, do
		###       the bulk write, then commit when done.
		# We connect with fatal errors, autocommit and UTF8 enabled.
		eval { $dbh = DBI->connect($db_connect_string, $user, $password, {
			RaiseError => 1,
			AutoCommit => 1,
			pg_enable_utf8 => 1
		}); };
		if ($@)
		{
			# Something went wrong...
			$an->Alert->warning({ title_key => "scancore_title_0002", message_key => "scancore_warning_0001", message_variables => {
				name		=>	$name,
				host		=>	$host,
				port		=>	$port,
			}, file => $THIS_FILE, line => __LINE__});
			#print "[ Warning ] - Failed to connect to database: [$name] on host: [$host:$port].\n";
			if ($DBI::errstr =~ /No route to host/)
			{
				$an->Alert->warning({ message_key => "scancore_warning_0002", message_variables => {
					port	=>	$port,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($DBI::errstr =~ /no password supplied/)
			{
				$an->Alert->warning({ message_key => "scancore_warning_0003", message_variables => {
					id		=>	$id,
					config_file	=>	$an->data->{path}{striker_config},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($DBI::errstr =~ /password authentication failed for user/)
			{
				$an->Alert->warning({ message_key => "scancore_warning_0004", message_variables => {
					user		=>	$user,
					id		=>	$id,
					config_file	=>	$an->data->{path}{striker_config},
				}, file	 => $THIS_FILE, line => __LINE__});
			}
			else
			{
				$an->Alert->warning({ message_key => "scancore_warning_0005", message_variables => {
					dbi_error	=>	$DBI::errstr,
				}, file => $THIS_FILE, line => __LINE__});
			}
			$an->Alert->warning({ message_key => "scancore_warning_0006", file => $THIS_FILE, line => __LINE__});
		}
		elsif ($dbh =~ /^DBI::db=HASH/)
		{
			# Woot!
			$connections++;
			$an->data->{dbh}{$id} = $dbh;
			$an->Log->entry({ log_level => 3, title_key => "scancore_title_0004", message_key => "scancore_log_0004", message_variables => {
				host		=>	$host,
				port		=>	$port,
				name		=>	$name,
				id		=>	$id,
				dbh		=>	$dbh,
				conf_dbh	=>	$an->data->{dbh}{$id},
			}, file => $THIS_FILE, line => __LINE__});
			
			# Now that I have connected, see if my 'hosts' table exists.
			my $query = "SELECT COUNT(*) FROM pg_catalog.pg_tables WHERE tablename='hosts' AND schemaname='public';";
			my $count = $an->DB->do_db_query({id => $id, query => $query})->[0]->[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "count", value1 => $count
			}, file => $THIS_FILE, line => __LINE__});
			if ($count < 1)
			{
				# Need to load the database.
				$an->DB->initialize_db({id => $id});
			}
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "sys::read_db_id", value1 => $an->data->{sys}{read_db_id}, 
			name2 => "dbh::$id",        value2 => $an->data->{dbh}{$id}, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Set the first ID to be the one I read from later.
		if (not $an->data->{sys}{read_db_id})
		{
			$an->data->{sys}{read_db_id} = $id;
			$an->data->{sys}{use_db_fh}  = $an->data->{dbh}{$id} ;
			
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "sys::read_db_id", value1 => $an->data->{sys}{read_db_id}, 
				name2 => "sys::use_db_fh",  value2 => $an->data->{sys}{use_db_fh}
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::db_timestamp", value1 => $an->data->{sys}{db_timestamp}
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{dbh}{$id})
		{
			if (not $an->data->{sys}{db_timestamp})
			{
				my $query = "SELECT cast(now() AS timestamp with time zone)";
				$an->data->{sys}{db_timestamp} = $an->DB->do_db_query({id => $id, query => $query})->[0]->[0];
				$an->data->{sys}{db_timestamp} = $an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp});
				
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "sys::db_timestamp",  value1 => $an->data->{sys}{db_timestamp},
				}, file => $THIS_FILE, line => __LINE__});
			}
			$an->data->{sys}{host_id_query} = "SELECT host_id FROM hosts WHERE host_name = ".$an->data->{sys}{use_db_fh}->quote($an->hostname);
			
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "sys::read_db_id",    value1 => $an->data->{sys}{read_db_id},
				name2 => "sys::use_db_fh",     value2 => $an->data->{sys}{use_db_fh},
				name3 => "sys::host_id_query", value2 => $an->data->{sys}{host_id_query},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	if (not $connections)
	{
		# Failed to connect to any database.
		print $an->String->get({ key => "scancore_message_0002", variables => {
			title		=>	$an->String->get({key => "scancore_title_0003"}),
			message		=>	$an->String->get({key => "scancore_error_0004"}),
		}}), "\n";
		exit(1);
	}
	
	### TODO: This is coming along nicely, but the problem right now is 
	###       sorting out which tables reference 'hosts -> host_id' and
	###       which reference other tables (possibly layers deep) that
	###       reference node_id.
	#$an->DB->sync_dbs();
	$an->DB->find_behind_databases({file => $file});
	
	# Now look to see if our hostname has changed.
	#$an->DB->check_hostname();
	
	return($connections);
}

# This looks up the hosts -> host_id for a given hostname.
sub get_host_id
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	
	# What's the query?
	my $id       = $parameter->{id}       ? $parameter->{id}       : $an->data->{sys}{read_db_id};
	my $hostname = $parameter->{hostname} ? $parameter->{hostname} : die "$THIS_FILE ".__LINE__."; AN::Tools::DB->get_host_id() called without specifying a 'hostname'.\n";
	
	my $query = "SELECT host_id, round(extract(epoch from modified_date)) FROM hosts WHERE host_name = ".$an->data->{sys}{use_db_fh}->quote($hostname).";";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1  => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	
	my $results = $an->DB->do_db_query({id => $id, query => $query})->[0];
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "results",       value1 => $results
	}, file => $THIS_FILE, line => __LINE__});
	
	# I need to see if 'results' is an array reference. If no records were
	# found, 'results' will be an empty string, in which case we'll set 
	# '0' for the two values.
	my ($host_id, $modified_time) = ref($results) eq "ARRAY" ? @{$results} : (0, 0);
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "host_id",       value1 => $host_id, 
		name2 => "modified_time", value2 => $modified_time
	}, file => $THIS_FILE, line => __LINE__});
	
	return($host_id, $modified_time);
}

# This checks to see if the hostname changed and, if so, update the hosts table
# so that we don't accidentally create a separate entry for this host.
sub check_hostname
{
	my $self = shift;
	my $an   = $self->parent;
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "sync_dbs", }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	#$an->hostname();
	
	return(0);
}

# This simply updates the 'updated' table with the current time.
sub update_time
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "update_time", }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $id   = $parameter->{id};
	my $file = $parameter->{file};
	
	# If I wasn't passed a specific ID, update all DBs.
	my @db_ids;
	if ($id)
	{
		push @db_ids, $id;
	}
	else
	{
		foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
		{
			push @db_ids, $id;
		}
	}
	
	foreach my $id (@db_ids)
	{
		# Check to see if there is a time record yet.
		my $query = "
SELECT 
    COUNT(*) 
FROM 
    updated 
WHERE 
    updated_host_id = (".$an->data->{sys}{host_id_query}.")
AND
    updated_by = ".$an->data->{sys}{use_db_fh}->quote($file).";"; 

		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1  => "query", value1 => $query
		}, file => $THIS_FILE, line => __LINE__ });
		my $count = $an->DB->do_db_query({id => $id, query => $query})->[0]->[0];	# (->[row]->[column])
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "count", value1 => $count
		}, file => $THIS_FILE, line => __LINE__ });
		if (not $count)
		{
			# Add this agent to the DB
			my $query = "
INSERT INTO 
    updated 
(
    updated_host_id, 
    updated_by, 
    modified_date
) VALUES (
    (".$an->data->{sys}{host_id_query}."), 
    ".$an->data->{sys}{use_db_fh}->quote($file).", 
    ".$an->data->{sys}{db_timestamp}."
);
";
			$an->DB->do_db_write({id => $id, query => $query});
		}
		else
		{
			# It exists and the value has changed.
			my $query = "
UPDATE 
    updated 
SET
    modified_date = ".$an->data->{sys}{db_timestamp}."
WHERE 
    updated_by = ".$an->data->{sys}{use_db_fh}->quote($file)." 
AND
    updated_host_id = (".$an->data->{sys}{host_id_query}.");
";
			$an->DB->do_db_write({id => $id, query => $query});
		}
	}
	
	return(0);
}

# This returns the most up to date database ID, the time it was last updated
# and an array or DB IDs that are behind.
sub find_behind_databases
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "find_behind_databases", }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $file = $parameter->{file};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "file", value1 => $file, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Look at all the databases and find the most recent time stamp (and
	# the ID of the DB).
	$an->data->{scancore}{sql}{source_db_id}        = 0;
	$an->data->{scancore}{sql}{source_updated_time} = 0;
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
	{
		my $name = $an->data->{scancore}{db}{$id}{name};
		my $user = $an->data->{scancore}{db}{$id}{user};
		
		# Read the table's last modified_date
		my $query = "
SELECT 
    round(extract(epoch from modified_date)) 
FROM 
    updated 
WHERE 
    updated_host_id = (".$an->data->{sys}{host_id_query}.")";
		if ($file)
		{
			$query .= "
AND
    updated_by = ".$an->data->{sys}{use_db_fh}->quote($file).";";
		}
		else
		{
			$query .= ";";
		}
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "id",    value1 => $id, 
			name2 => "query", value2 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		my $last_updated = $an->DB->do_db_query({id => $id, query => $query})->[0]->[0];
		   $last_updated = 0 if not defined $last_updated;
		   
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "last_updated",                       value1 => $last_updated, 
			name2 => "scancore::sql::source_updated_time", value2 => $an->data->{scancore}{sql}{source_updated_time}
		}, file => $THIS_FILE, line => __LINE__});
		if ($last_updated > $an->data->{scancore}{sql}{source_updated_time})
		{
			$an->data->{scancore}{sql}{source_updated_time} = $last_updated;
			$an->data->{scancore}{sql}{source_db_id}        = $id;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "scancore::sql::source_db_id",        value1 => $an->data->{scancore}{sql}{source_db_id}, 
				name2 => "scancore::sql::source_updated_time", value2 => $an->data->{scancore}{sql}{source_updated_time}
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		### TODO: Determine if I should be checking per-table... Is it
		###       possible for one agent's table to fall behind? Maybe,
		###       if the agent is deleted/recovered...
		$an->data->{scancore}{db}{$id}{last_updated} = $last_updated;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "scancore::sql::source_updated_time",   value1 => $an->data->{scancore}{sql}{source_updated_time}, 
			name2 => "scancore::sql::source_db_id",    value2 => $an->data->{scancore}{sql}{source_db_id}, 
			name3 => "scancore::db::${id}::last_updated", value3 => $an->data->{scancore}{db}{$id}{last_updated}
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Find which DB is most up to date.
	$an->data->{scancore}{db_to_update} = {};
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "scancore::sql::source_updated_time", value1 => $an->data->{scancore}{sql}{source_updated_time}, 
			name2 => "scancore::db::${id}::last_updated",  value2 => $an->data->{scancore}{db}{$id}{last_updated}, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{scancore}{sql}{source_updated_time} > $an->data->{scancore}{db}{$id}{last_updated})
		{
			# This database is behind
			$an->Log->entry({log_level => 3, message_key => "scancore_log_0031", message_variables => {
				id => $id, 
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{scancore}{db_to_update}{$id}{behind} = 1;
		}
		else
		{
			# This database is up to date.
			$an->data->{scancore}{db_to_update}{$id}{behind} = 0;
		}
	}
	
	return(0);
}

# This 'checks last_updated -> last_updated_date' for this node on all DBs and
# if any are behind, it will read in the changes from the most up to date DB
sub sync_dbs
{
	my $self = shift;
	my $an   = $self->parent;
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "sync_dbs", }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# First, read all databases to see if any are behind and, if so, bring
	# them up to date.
	$an->data->{scancore}{sql}{source_db_id}  = 0;
	$an->data->{scancore}{sql}{source_updated_time} = 0;
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
	{
		my $name = $an->data->{scancore}{db}{$id}{name};
		my $user = $an->data->{scancore}{db}{$id}{user};
		
		# First, get a list of the tables in the database
		my $query   = "SELECT DISTINCT table_name FROM information_schema.columns WHERE table_catalog = ".$an->data->{sys}{use_db_fh}->quote($name)." AND table_schema = 'public';";
		my $results = $an->DB->do_db_query({id => $id, query => $query});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "query",        value1 => $query, 
			name2 => "results",      value2 => $results, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Read the table's last modified_date
		$query = "
SELECT 
    round (
        extract (
            epoch FROM (
                SELECT 
                    modified_date 
                FROM 
                    ram_used 
                WHERE 
                    ram_used_by = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{program_name})." 
                AND 
                    ram_used_host_id = (".$an->data->{sys}{host_id_query}.")
            )
        )
    );
";
		my $last_updated = $an->DB->do_db_query({id => $id, query => $query})->[0]->[0];
		   $last_updated = 0 if not defined $last_updated;
		
		if ($last_updated > $an->data->{scancore}{sql}{source_updated_time})
		{
			$an->data->{scancore}{sql}{source_updated_time} = $last_updated;
			$an->data->{scancore}{sql}{source_db_id}  = $id;
		}
		
		### TODO: Determine if I should be checking per-table... Is it
		###       possible for one agent's table to fall behind? Maybe,
		###       if the agent is deleted/recovered...
		$an->data->{scancore}{db}{$id}{last_updated} = $last_updated;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "scancore::db::${id}::last_updated", value1 => $an->data->{scancore}{db}{$id}{last_updated}, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Now see what tables are in each DB.
		foreach my $row (@{$results})
		{
			my $table = $row->[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "id",   value1 => $id, 
				name2 => "table", value2 => $table, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Record this table in the general list.
			$an->data->{scancore}{sql}{master_table_list}{$table} = 1;
			
			# Record it as a table in this DB.
			$an->data->{scancore}{sql}{db}{$id}{table}{$table} = 1;
		}
	}
	
	# Find which DB is most up to date.
	$an->data->{scancore}{db_to_update} = {};
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
	{
		if ($an->data->{scancore}{sql}{source_updated_time} > $an->data->{scancore}{db}{$id}{last_updated})
		{
			print "The DB with ID: [$id] is behind!\n";
			$an->data->{scancore}{db_to_update}{$id}{behind} = 1;
		}
		else
		{
			$an->data->{scancore}{db_to_update}{$id}{behind} = 0;
		}
	}
	
	# Now, loop through all the tables and see if any are missing on any DBs.
	foreach my $table (sort {$a cmp $b} keys %{$an->data->{scancore}{sql}{master_table_list}})
	{
		# Loop through all DBs and verify the table exists.
		foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
		{
			my $exists = $an->data->{scancore}{sql}{db}{$id}{table}{$table} ? $an->data->{scancore}{sql}{db}{$id}{table}{$table} : 0;
			#print "id: [$id], table: [$table], exists?: [$exists]\n";
			if (not $exists)
			{
				print "Will add the table: [$table] to the DB with ID: [$id]\n";
				$an->data->{scancore}{db_to_update}{$id}{add_table}{$table} = 1;
			}
		}
	}
	
	# Now I know who needs to be updated and what, if any, tables need to
	# be loaded.
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db_to_update}})
	{
		next if $id eq $an->data->{scancore}{sql}{source_db_id};
		my $name = $an->data->{scancore}{db}{$id}{name};
		my $user = $an->data->{scancore}{db}{$id}{user};
		print "Updating the DB with ID: [$id]\n";
		
		# First, make sure all the tables exist.
		foreach my $this_table (sort {$a cmp $b} keys %{$an->data->{scancore}{db_to_update}{$id}{add_table}})
		{
			print "- Adding table: [$this_table]\n";
			if (not $an->data->{scancore}{sql}{schema})
			{
				print "I need to read in the DB schema.\n";
				$an->DB->get_sql_schema or die "Failed to read the SQL schema from the database with ID: [$id]!\n";
			}
			
			# The SQL was assembled already, so we can load it directly.
			$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} =~ s/#!variable!user!#/$user/sg;
			$an->DB->do_db_write({id => $id, query => $an->data->{scancore}{sql}{schema}{raw_table}{$this_table}});
		}
		
		# Now I know that all tables exist in the target DB, look for
		# actual data that needs to be copied.
		foreach my $table (sort {$a cmp $b} keys %{$an->data->{scancore}{sql}{master_table_list}})
		{
			print "Table: [$table]\n";
			my $subquery = "SELECT ";
			my $query = "
SELECT 
	column_name 
FROM 
	information_schema.columns 
WHERE 
	table_catalog = ".$an->data->{sys}{use_db_fh}->quote($name)." 
AND 
	table_schema = 'public' 
AND 
	table_name = ".$an->data->{sys}{use_db_fh}->quote($table)."
";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "query", value1 => $query, 
			}, file => $THIS_FILE, line => __LINE__});
			my $results        = $an->DB->do_db_query({id => $id, query => $query});
			my $host_id_column = "";
			my @columns;
			foreach my $row (@{$results})
			{
				my $column = $row->[0];
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "column", value1 => $column, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($column =~ /_host_id$/)
				{
					$host_id_column = $column;
				}
				else
				{
					$subquery .= "$column, ";
					push @columns, $column;
				}
			}
			my $this_db_last_updated =  $an->data->{scancore}{db}{$id}{last_updated};
			   $subquery             =~ s/, $/ /;
			   $subquery             .= "FROM history.$table WHERE $host_id_column = (".$an->data->{sys}{host_id_query}.") AND (SELECT to_timestamp(".$an->data->{sys}{use_db_fh}->quote($this_db_last_updated).")) < modified_date";
			my $query_id             =  $an->data->{scancore}{sql}{source_db_id};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
				name1 => "scancore::sql::source_updated_time", value1 => $an->data->{scancore}{sql}{source_updated_time},
				name2 => "this_db_last_updated",            value2 => $this_db_last_updated,
				name3 => "query_id",                        value3 => $query_id,
				name4 => "id",                              value4 => $id, 
				name5 => "subquery",                        value5 => $subquery
			}, file => $THIS_FILE, line => __LINE__});
			
			# Query the up-to-date DB
		}

	}
	
	# Show all tables in the DB
	# SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema = 'public' OR table_schema = 'history' ORDER BY table_schema, table_name;
	
	# Get the timestamp of the last entry for each table.
	# SELECT round(extract(epoch from (SELECT modified_date FROM ram_used WHERE ram_used_by = 'ScanCore' AND ram_used_host_id = (SELECT host_id FROM hosts WHERE host_name = 'an-a05n01.alteeve.ca'))));
	
	# List all tables and their columns.
	# SELECT table_schema || '.' || table_name AS table, column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_catalog = 'scancore' AND table_schema = 'public' OR table_schema = 'history';
	
	# Get this node's ID for each DB with:
	# 
	
	# Cast a timestamp as unixtime
	# SELECT ram_used_by, ram_used_bytes, extract(epoch from modified_date) FROM history.ram_used WHERE ram_used_host_id = 1;
	
	# Read the time as a unix timestamp for easier comparison with:
	# SELECT round(extract(epoch from now()));
	
	return(0);
}

# This uses the '$an->data->{scancore}{sql}{source_db_id}' to call 'pg_dump'
# and get the database schema. This is parsed and then used to add tables that
# are missing to other DBs.
sub get_sql_schema
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 3, message_key => "scancore_log_0001", message_variables => { function => "get_sql_schema" }, file => $THIS_FILE, line => __LINE__});
	
	# Make the variables easier to read
	my $id       = $an->data->{scancore}{sql}{source_db_id};
	my $host     = $an->data->{scancore}{db}{$id}{host};
	my $port     = $an->data->{scancore}{db}{$id}{port};
	my $name     = $an->data->{scancore}{db}{$id}{name};
	my $user     = $an->data->{scancore}{db}{$id}{user};
	my $password = $an->data->{scancore}{db}{$id}{password};
	my $pgpass   = "/root/.pgpass";
	my $dump_ok  = 0;
	
	# These are used when walking through the SQL schema
	my $this_function = "";
	my $this_table    = "";
	my $this_trigger  = "";
	my $this_schema   = "";
	my $this_sequence = "";
	my $last_line     = "";
	
	# Now I need to connect to the remote host and dump the DB schema. I
	# need to do this by setting .pgpass.
	my $shell_call = "$pgpass";
	$an->Log->entry({log_level => 3, message_key => "scancore_log_0007", message_variables => { shell_call => $shell_call }, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, ">$shell_call") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0015", message_variables => { shell_call => $shell_call, error => $! }, code => 3, file => "$THIS_FILE", line => __LINE__});
	print $file_handle "$host:*:*:$user:$password\n";
	close $file_handle;
	
	# Set the permissions on .pgpass
	my $mode = 0600;
	chmod $mode, $pgpass; 
	
	# Make the shell call.
	$shell_call =  $an->data->{path}{pg_dump}." --host $host";
	$shell_call .= " --port $port" if $port;
	$shell_call .= " --username $user --schema-only $name 2>&1 |";
	$an->Log->entry({log_level => 3, message_key => "scancore_log_0007", message_variables => { shell_call => $shell_call }, file => $THIS_FILE, line => __LINE__});
	open ($file_handle, "$shell_call") or $an->Alert->error({fatal => 1, title_key => "scancore_title_0003", message_key => "scancore_error_0006", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
	while (<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => ">> line", value1 => "$line"
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line eq "-- PostgreSQL database dump complete")
		{
			$dump_ok = 1;
			next;
		}
		
		#$line =~ s/-- .*//;
		next if not $line;
		next if $line eq "--";
		
		# Note which schema is being used.
		if ($line =~ /SET search_path = (.*?), pg_catalog;/)
		{
			$this_schema = $1;
			next;
		}
		
		# Dig out functions
		if ($line =~ /^CREATE FUNCTION (.*?)\(\)/)
		{
			$this_function = $1;
			$an->data->{scancore}{sql}{schema}{function}{$this_function} = "SET search_path = $this_schema, pg_catalog;\n";
			$an->data->{scancore}{sql}{schema}{function}{$this_function} .= "$line\n";
			next;
		}
		if ($this_function)
		{
			$an->data->{scancore}{sql}{schema}{function}{$this_function} .= "$line\n";
			if ($line eq '$$;')
			{
				$this_function = "";
			}
			next;
		}
		
		# Dig out tables;
		if ($line =~ /CREATE TABLE (.*?) \(/)
		{
			$this_table = $1;
			# Stick the schema onto the table name if it's not 'public'.
			$an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{body} = "SET search_path = $this_schema, pg_catalog;\n";
			$an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{body} .= "$line\n";
			next;
		}
		if ($this_table)
		{
			$an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{body} .= "$line\n";
			if ($line eq ');')
			{
				$this_table = "";
			}
			next;
		}
		
		# Dig out default values.
		if ($line =~ /ALTER TABLE ONLY (.*?) ALTER COLUMN (.*?) SET DEFAULT .*?;/)
		{
			my $this_table  = $1;
			my $this_column = $2;
			$an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{column}{$this_column}{default_value} = "SET search_path = $this_schema, pg_catalog;\n";
			$an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{column}{$this_column}{default_value} .= "$line\n";
			next;
		}
		
		# Dig out sequences;
		if ($line =~ /CREATE SEQUENCE (.*)/)
		{
			$this_sequence = $1;
			$an->data->{scancore}{sql}{schema}{sequence}{$this_schema}{$this_sequence} = "SET search_path = $this_schema, pg_catalog;\n";
			$an->data->{scancore}{sql}{schema}{sequence}{$this_schema}{$this_sequence} .= "$line\n";
			next;
		}
		if ($this_sequence)
		{
			$an->data->{scancore}{sql}{schema}{sequence}{$this_schema}{$this_sequence} .= "$line\n";
			if ($line =~ /;$/)
			{
				$this_sequence = "";
			}
			next;
		}
		
		# Digging out constraints is a little trickier as a line goes
		# by before we see 'CONSTRAINT'...
		if ($line =~ /ADD CONSTRAINT (.*?) /)
		{
			my $this_constraint = $1;
			my $this_table      = ($last_line =~ /ALTER TABLE ONLY (.*)/)[0];
			my $full_line       = "$last_line\n$line";
			$an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{constraint}{$this_constraint} = "SET search_path = $this_schema, pg_catalog;\n";
			$an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{constraint}{$this_constraint} .= "$full_line\n";
			next;
		}
		
		# Triggers are easy one-liners
		if ($line =~ /CREATE TRIGGER (.*?) /)
		{
			$this_trigger = $1;
			$an->data->{scancore}{sql}{schema}{trigger}{$this_trigger} = "SET search_path = $this_schema, pg_catalog;\n";
			$an->data->{scancore}{sql}{schema}{trigger}{$this_trigger} .= "$line\n";
			next;
		}
		
		#print "line: [$line]\n";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => ">> line", value1 => "$line"
		}, file => $THIS_FILE, line => __LINE__});
		
		$last_line = $line;
	}
	close $file_handle;
	
	# Remove the .pgpass file.
	unlink $pgpass;
	
	# Put the SQL states together by table.
	foreach my $this_table (sort {$a cmp $b} keys %{$an->data->{scancore}{sql}{schema}{table}})
	{
		print "Recording the SQL schema for the table: [$this_table]\n";
		my $this_schema = "public";
		$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} = "
-- ------------------------------------------------------------------------- --
-- Start Table: [$this_table]
-- ------------------------------------------------------------------------- --
";
		# The sequences
		my $table_id_sequence   = "${this_table}_${this_table}_id_seq";
		my $history_id_sequence = "${this_table}_history_id_seq";
		foreach my $this_schema (sort {$b cmp $a} keys %{$an->data->{scancore}{sql}{schema}{sequence}})
		{
			if ($an->data->{scancore}{sql}{schema}{sequence}{$this_schema}{$table_id_sequence})
			{
				$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= "-- Table ID Sequence: [$table_id_sequence]\n";
				$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= $an->data->{scancore}{sql}{schema}{sequence}{$this_schema}{$table_id_sequence}."\n";
			}
			else
			{
				$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= "-- No Table ID sequence: [$table_id_sequence] found.\n";
			}
			if ($an->data->{scancore}{sql}{schema}{sequence}{$this_schema}{$history_id_sequence})
			{
				$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= "-- History ID Sequence: [$history_id_sequence]\n";
				$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= $an->data->{scancore}{sql}{schema}{sequence}{$this_schema}{$history_id_sequence}."\n";
			}
			else
			{
				$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= "-- No History ID sequence: [$history_id_sequence] found.\n";
			}
		}
		
		foreach my $this_schema (sort {$b cmp $a} keys %{$an->data->{scancore}{sql}{schema}{table}{$this_table}})
		{
			$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= $an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{body};
			$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= "ALTER TABLE $this_schema.$this_table OWNER TO #!variable!user!#;\n\n";
			
			foreach my $this_column (sort {$a cmp $b} keys %{$an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{column}})
			{
				$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= "-- Column: [$this_column] default:\n";
				$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= $an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{column}{$this_column}{default_value}."\n";
			}
			foreach my $this_constraint (sort {$a cmp $b} keys %{$an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{constraint}})
			{
				$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= "-- Constraint: [$this_constraint]\n";
				$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= $an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{constraint}{$this_constraint}."\n";
			}
		}
		
		# The function
		my $this_function = "history_$this_table";
		if ($an->data->{scancore}{sql}{schema}{function}{$this_function})
		{
			$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= "-- Function: [$this_function]\n";
			$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= $an->data->{scancore}{sql}{schema}{function}{$this_function}."\n";
		}
		else
		{
			$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= "-- No function called: [$this_function] found.\n";
		}
		
		# The trigger.
		my $this_trigger = "trigger_$this_table";
		if ($an->data->{scancore}{sql}{schema}{trigger}{$this_trigger})
		{
			$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= "-- Trigger: [$this_trigger]\n";
			$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= $an->data->{scancore}{sql}{schema}{trigger}{$this_trigger}."\n";
		}
		else
		{
			$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= "-- No function called: [$this_trigger] found.\n";
		}
		
		$an->data->{scancore}{sql}{schema}{raw_table}{$this_table} .= "
-- ------------------------------------------------------------------------- --
-- End Table: [$this_table]
-- ------------------------------------------------------------------------- --
";
	}
	
	# Show what we read
=pod
	foreach my $this_table (sort {$a cmp $b} keys %{$an->data->{scancore}{sql}{schema}{table}})
	{
		foreach my $this_schema (sort {$b cmp $a} keys %{$an->data->{scancore}{sql}{schema}{table}{$this_table}})
		{
			print "Table: [$this_schema.$this_table]\n";
			print "========\n";
			print $an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{body};
			print "========\n";
			foreach my $this_column (sort {$a cmp $b} keys %{$an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{column}})
			{
				print "Column: [$this_column] default:\n";
				print $an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{column}{$this_column}{default_value};
			}
			foreach my $this_constraint (sort {$a cmp $b} keys %{$an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{constraint}})
			{
				print "Constraint: [$this_constraint]\n";
				print $an->data->{scancore}{sql}{schema}{table}{$this_table}{$this_schema}{constraint}{$this_constraint};
			}
			print "========\n\n";
		}
	}
	foreach my $this_function (sort {$a cmp $b} keys %{$an->data->{scancore}{sql}{schema}{function}})
	{
		print "Function: [$this_function]\n";
		print "========\n";
		print $an->data->{scancore}{sql}{schema}{function}{$this_function};
		print "========\n\n";
	}
	foreach my $this_trigger (sort {$a cmp $b} keys %{$an->data->{scancore}{sql}{schema}{trigger}})
	{
		print "Trigger: [$this_trigger]\n";
		print "========\n";
		print $an->data->{scancore}{sql}{schema}{trigger}{$this_trigger};
		print "========\n\n";
	}
	foreach my $this_sequence (sort {$a cmp $b} keys %{$an->data->{scancore}{sql}{schema}{sequence}})
	{
		print "Sequence: [$this_sequence]\n";
		print "========\n";
		print $an->data->{scancore}{sql}{schema}{sequence}{$this_schema}{$this_sequence};
		print "========\n\n";
	}
	
	print "dump_ok: [$dump_ok]\n";
	die;
=cut
	
	return($dump_ok);
}

# This loads a SQL schema into the specified DB.
sub load_schema
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 2, message_key => "scancore_log_0001", message_variables => { function => "load_schema" }, file => $THIS_FILE, line => __LINE__});
	
	my $file = $parameter->{file} ? $parameter->{file} : "";
	my $id   = $parameter->{id}   ? $parameter->{id}   : "";
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => { 
		name1 => "id",   value1 => $id, 
		name2 => "file", value2 => $file 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Do I know which DB I am loading the schema into?
	if (not $id)
	{
		# We can't load the schema into all. That's not safe as DBs
		# can't be sync'ed until their schema exists.
		print $an->String->get({
			key		=>	"scancore_message_0002",
			variables	=>	{
				title		=>	$an->String->get({key => "scancore_title_0003"}),
				message		=>	$an->String->get({key => "scancore_error_0007"}),
			},
		}), "\n";
		exit(1);
	}
	
	# Do I have a file to load?
	if (not $file)
	{
		# what file?
		print $an->String->get({
			key		=>	"scancore_message_0002",
			variables	=>	{
				title		=>	$an->String->get({key => "scancore_title_0003"}),
				message		=>	$an->String->get({key => "scancore_error_0008"}),
			},
		}), "\n";
		exit(1);
	}
	# Does the file exist?
	if (not -e $file)
	{
		# file not found
		print $an->String->get({
			key		=>	"scancore_message_0002",
			variables	=>	{
				title		=>	$an->String->get({key => "scancore_title_0003"}),
				message		=>	$an->String->get({key => "scancore_error_0009", variables => { file => $file }}),
			},
		}), "\n";
		exit(1);
	}
	# And can I read it?
	if (not -r $file)
	{
		# file found, but can't be read. <sad_trombine />
		print $an->String->get({
			key		=>	"scancore_message_0002",
			variables	=>	{
				title		=>	$an->String->get({key => "scancore_title_0003"}),
				message		=>	$an->String->get({key => "scancore_error_0010", variables => { file => $file }}),
			},
		}), "\n";
		exit(1);
	}
	
	# Tell the user we're loading a schema
	$an->Log->entry({log_level => 1, title_key => "scancore_title_0005", message_key => "scancore_log_0021", message_variables => {
		name => $an->data->{scancore}{db}{$id}{name}, 
		host => $an->data->{scancore}{db}{$id}{host}, 
		file => $file
	}, file => $THIS_FILE, line => __LINE__});
	
	# Read in the SQL file and replace #!variable!name!# with the database
	# owner name.
	my $user = $an->data->{scancore}{db}{$id}{user};
	my $sql  = "";
	
	# Create the read shell call.
	my $shell_call = $file;
	$an->Log->entry({log_level => 2, message_key => "scancore_log_0007", message_variables => { shell_call => $shell_call }, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "<$shell_call") or $an->Alert->error({fatal => 1, title_key => "scancore_title_0003", message_key => "scancore_error_0003", message_variables => { shell_call => $shell_call, error => $! }, code => 3, file => "$THIS_FILE", line => __LINE__});
	while (<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => { 
			name1 => ">> line", value1 => $line 
		}, file => $THIS_FILE, line => __LINE__});
		$line =~ s/#!variable!user!#/$user/g;
		$line =~ s/--.*//g;
		$line =~ s/\t/ /g;
		$line =~ s/\s+/ /g;
		$line =~ s/^\s+//g;
		$line =~ s/\s+$//g;
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => { 
			name1 => "line", value1 => $line 
		}, file => $THIS_FILE, line => __LINE__});
		$sql .= "$line\n";
	}
	close $file_handle;
	
	# Now we should be ready.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => { 
		name1 => "id",  value1 => $id, 
		name2 => "sql", value2 => $sql
	}, file => $THIS_FILE, line => __LINE__});
	
	# Now that I am ready, write!
	$an->DB->do_db_write({id => $id, query => $sql});
	
	return(0);
}

# This will initialize the database using the data in the ScanCore.sql file.
sub initialize_db
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	
	my $id = $parameter->{id} ? $parameter->{id} : "";
	
	# If I don't have an ID, die.
	if (not $id)
	{
		# what DB?
		print $an->String->get({
			key		=>	"scancore_message_0002",
			variables	=>	{
				title		=>	$an->String->get({key => "scancore_title_0003"}),
				message		=>	$an->String->get({key => "scancore_error_0005"}),
			},
		}), "\n";
		exit(1);
	}
	
	$an->Log->entry({log_level => 3, message_key => "scancore_log_0001", message_variables => {function => "initialize_db"}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "id", value1 => $id
	}, file => $THIS_FILE, line => __LINE__});
	
	# Tell the user we need to initialize
	$an->Log->entry({log_level => 1, title_key => "scancore_title_0005", message_key => "scancore_log_0009", message_variables => {name => $an->data->{scancore}{db}{$id}{name}, host => $an->data->{scancore}{db}{$id}{host}}, file => $THIS_FILE, line => __LINE__});
	
	my $success = 1;
	
	# Read in the SQL file and replace #!variable!name!# with the database
	# owner name.
	my $user       = $an->data->{scancore}{db}{$id}{user};
	my $sql        = "";
	
	# Create the read shell call.
	my $shell_call = $an->data->{path}{scancore_sql};
	$an->Log->entry({log_level => 3, message_key => "scancore_log_0007", message_variables => {shell_call => $shell_call }, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "<$shell_call") or $an->Alert->error({fatal => 1, title_key => "scancore_title_0003", message_key => "scancore_error_0003", message_variables => { shell_call => $shell_call, error => $! }, code => 3, file => "$THIS_FILE", line => __LINE__});
	while (<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line
		}, file => $THIS_FILE, line => __LINE__});
		$line =~ s/#!variable!user!#/$user/g;
		$line =~ s/--.*//g;
		$line =~ s/\t/ /g;
		$line =~ s/\s+/ /g;
		$line =~ s/^\s+//g;
		$line =~ s/\s+$//g;
		next if not $line;
		$sql .= "$line\n";
	}
	close $file_handle;
	
	# Now we should be ready.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "sql", value1 => $sql
	}, file => $THIS_FILE, line => __LINE__});
	
	# Now that I am ready, disable autocommit, write and commit.
	$an->DB->do_db_write({id => $id, query => $sql});
	
	
	return($success);
};

1;
