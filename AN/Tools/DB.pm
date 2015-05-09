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
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_vars => {
		name1 => "id",    value1 => $id, 
		name2 => "query", value2 => $query
	}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
	
	# If I don't have a query, die.
	if (not $query)
	{
		print $an->String->get({
			key		=>	"scancore_message_0002",
			variables	=>	{
				title		=>	$an->String->get({key => "scancore_title_0003"}),
				message		=>	$an->String->get({key => "scancore_error_0011"}),
			},
		}), "\n";
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
	my @query;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_vars => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
	if (ref($query) eq "ARRAY")
	{
		# Multiple things to enter.
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
		foreach my $query (@query)
		{
			# Record the query
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_vars => {
				name1 => "id",    value1 => $id,
				name2 => "query", value2 => $query
			}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
			
			# Just one query.
			$an->data->{dbh}{$id}->do($query) or $an->Alert->error({fatal => 1, title_key => "scancore_title_0003", message_key => "scancore_error_0012", message_vars => { 
				query    => $query, 
				server   => "$an->data->{scancore}{db}{$id}{host}:$an->data->{scancore}{db}{$id}{port} -> $an->data->{scancore}{db}{$id}{name}", 
				db_error => $DBI::errstr
			}, code => 2, file => "$THIS_FILE", line => __LINE__ });
		}
		
		# Commit the changes.
		$an->data->{dbh}{$id}->commit();
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_vars => {
		name1 => "id",    value1 => $id, 
		name2 => "query", value2 => $query
	}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
	
	# Prepare the query
	my $DBreq = $an->data->{dbh}{$id}->prepare($query) or $an->Alert->error({fatal => 1, title_key => "scancore_title_0003", message_key => "scancore_error_0001", message_vars => { query => $query, server => "$an->data->{scancore}{db}{$id}{host}:$an->data->{scancore}{db}{$id}{port} -> $an->data->{scancore}{db}{$id}{name}", db_error => $DBI::errstr}, code => 2, file => "$THIS_FILE", line => __LINE__ });
	
	# Execute on the query
	$DBreq->execute() or $an->Alert->error({ fatal => 1, title_key => "scancore_title_0003", message_key => "scancore_error_0002", message_vars => {query => $query, server => "$an->data->{scancore}{db}{$id}{host}:$an->data->{scancore}{db}{$id}{port} -> $an->data->{scancore}{db}{$id}{name}", db_error => $DBI::errstr, }, code => 3, file => "$THIS_FILE", line => __LINE__ });
	
	# Return the array
	return($DBreq->fetchall_arrayref());
}

# This will cache failed updates to the DB.
sub record_failed_db_write_to_cache
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	
	# Setup my variables.
	my ($id, $query);
	
	# Now see if the user passed the values in a hash reference or
	# directly.
	#print "$THIS_FILE ".__LINE__."; parameter: [$parameter]\n";
	if (ref($parameter) eq "HASH")
	{
		# Values passed in a hash, good.
		$id    = $parameter->{id}    ? $parameter->{id}    : 0;		# This should throw an error
		$query = $parameter->{query} ? $parameter->{query} : "";	# This should throw an error
		print "$THIS_FILE ".__LINE__."; id: [$id], query: [$query]\n";
	}
	else
	{
		# Values passed directly.
		$id    = defined $parameter ? $parameter : 0;	# This should throw an error
		$query = defined $_[0]      ? $_[0]      : "";	# This should throw an error
		print "$THIS_FILE ".__LINE__."; id: [$id], query: [$query]\n";
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_vars => {
		name1 => "id",    value1 => $id, 
		name2 => "query", value2 => $query
	}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
	
	# TODO: ...
	
	return(0);
}

# This does an UPDATE, INSERT or some combination of both. It expects the 'sql'
# variable to be an array reference. 
sub db_do_write
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	
	# What's the query?
	my $sql = $parameter->{query} ? $parameter->{query} : "";	# This should throw an error
	my $id  = $parameter->{id}    ? $parameter->{id}    : "";	# This should throw an error
	
	my @id;
	if (not $id)
	{
		# Write to all DBs.
		foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
		{
			push @id, $id;
		}
	}
	else
	{
		# We've been given a specific DB
		push @id, $id;
	}
	
	foreach my $id (@id)
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_vars => {
			name1 => "id",  value2 => $id, 
			name2 => "sql", value2 => $sql
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
		
		my $errors = "";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_vars => {
			name1 => "sql", value1 => $sql
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
		$errors .= $an->data->{dbh}{$id}->do($sql) or $an->Alert->warning({
			title_key	=>	"scancore_title_0002",
			message_key	=>	"scancore_warning_0007",
			message_vars	=>	{
				dbi_error	=>	$DBI::errstr,
			},
			file		=>	$THIS_FILE,
			line		=>	__LINE__,
			to_log		=>	$an->data->{path}{log_file},
		});
		$errors = "" if $errors eq "0E0";
			
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_vars => {
			name1 => "errors", value1 => $errors
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
		if ($errors)
		{
			# Abort, abort!
			$an->Alert->warning({
				title_key	=>	"scancore_title_0002",
				message_key	=>	"scancore_warning_0008",
				file		=>	$THIS_FILE,
				line		=>	__LINE__,
				to_log		=>	$an->data->{path}{log_file},
			});
			$an->data->{dbh}{$id}->rollback;
			
			# Now record the data to our cache.
			$an->DB->record_failed_db_write_to_cache($id, $sql);
		}
		else
		{
			# Good!
			$an->Log->entry({log_level => 2, message_key => "scancore_log_0008", file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
			$an->data->{dbh}{$id}->commit;
		}
	}
	
	return(0);
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
	
	$an->Log->entry({log_level => 3, message_key => "scancore_log_0001", message_vars => {function => "connect_to_databases"}, file => $THIS_FILE, line => __LINE__, log_to  => $an->data->{path}{log_file} });
	
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
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_vars => {
			name1 => "id",              value1 => $id, 
			name2 => "sys::read_db_id", value2 => $an->data->{sys}{read_db_id}, 
			name3 => "dbh::$id",        value3 => $an->data->{dbh}{$id}, 
			name4 => "sys::use_db_fh",  value4 => $an->data->{sys}{use_db_fh}
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
		
		# Log what we're doing.
		$an->Log->entry({
			log_level	=>	3,
			file		=>	$THIS_FILE,
			line		=>	__LINE__,
			title_key	=>	"scancore_title_0001",
			title_vars	=>	"",
			message_key	=>	"scancore_log_0002",
			message_vars	=>	{
				id			=>	$id,
				driver			=>	$driver,
				host			=>	$host,
				port			=>	$port,
				postgres_password	=>	$postgres_password,
				name			=>	$name,
				user			=>	$user,
				password		=>	$password,
				initialize		=>	$initialize,
			},
			language	=>	$an->data->{sys}{log_language},
			log_to		=>	$an->data->{path}{log_file},
		});
		
		# Assemble my connection string
		my $db_connect_string = "$driver:dbname=$name;host=$host;port=$port";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_vars => {
			name1 => "db_connect_string", value1 => $db_connect_string
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
		
		# Connect!
		my $dbh = "";
		### NOTE: With autocommit off, we need to call an explicit
		###       '->commit' when done!
		# We connect with fatal errors, NO autocommit and UTF8 enabled.
		eval { $dbh = DBI->connect($db_connect_string, $user, $password, {
			RaiseError => 1,
			AutoCommit => 0,
			pg_enable_utf8 => 1
		}); };
		if ($@)
		{
			# Something went wrong...
			$an->Alert->warning({
				title_key	=>	"scancore_title_0002",
				message_key	=>	"scancore_warning_0001",
				message_vars	=>	{
					name		=>	$name,
					host		=>	$host,
					port		=>	$port,
				},
				file		=>	$THIS_FILE,
				line		=>	__LINE__,
				to_log		=>	$an->data->{path}{log_file},
			});
			#print "[ Warning ] - Failed to connect to database: [$name] on host: [$host:$port].\n";
			if ($DBI::errstr =~ /No route to host/)
			{
				$an->Alert->warning({
					message_key	=>	"scancore_warning_0002",
					message_vars	=>	{
						port		=>	$port,
					},
					file		=>	$THIS_FILE,
					line		=>	__LINE__,
					to_log		=>	$an->data->{path}{log_file},
				});
			}
			elsif ($DBI::errstr =~ /no password supplied/)
			{
				$an->Alert->warning({
					message_key	=>	"scancore_warning_0003",
					message_vars	=>	{
						id		=>	$id,
						config_file	=>	$an->data->{path}{striker_config},
					},
					file		=>	$THIS_FILE,
					line		=>	__LINE__,
					to_log		=>	$an->data->{path}{log_file},
				});
			}
			elsif ($DBI::errstr =~ /password authentication failed for user/)
			{
				$an->Alert->warning({
					message_key	=>	"scancore_warning_0004",
					message_vars	=>	{
						user		=>	$user,
						id		=>	$id,
						config_file	=>	$an->data->{path}{striker_config},
					},
					file		=>	$THIS_FILE,
					line		=>	__LINE__,
					to_log		=>	$an->data->{path}{log_file},
				});
			}
			else
			{
				$an->Alert->warning({
					message_key	=>	"scancore_warning_0005",
					message_vars	=>	{
						dbi_error	=>	$DBI::errstr,
					},
					file		=>	$THIS_FILE,
					line		=>	__LINE__,
					to_log		=>	$an->data->{path}{log_file},
				});
			}
			$an->Alert->warning({
				message_key	=>	"scancore_warning_0006",
				file		=>	$THIS_FILE,
				line		=>	__LINE__,
				to_log		=>	$an->data->{path}{log_file},
			});
			print "\n";
		}
		elsif ($dbh =~ /^DBI::db=HASH/)
		{
			# Woot!
			$connections++;
			$an->data->{dbh}{$id} = $dbh;
			$an->Log->entry({
				log_level	=>	3,
				title_key	=>	"scancore_title_0004",
				message_key	=>	"scancore_log_0004",
				message_vars	=>	{
					host		=>	$host,
					port		=>	$port,
					name		=>	$name,
					id		=>	$id,
					dbh		=>	$dbh,
					conf_dbh	=>	$an->data->{dbh}{$id},
				},
				file		=>	$THIS_FILE,
				line		=>	__LINE__,
				language	=>	$an->data->{sys}{log_language},
				log_to		=>	$an->data->{path}{log_file},
			});
			
			# Now that I have connected, see if my 'hosts' table exists.
			my $query = "SELECT COUNT(*) FROM pg_catalog.pg_tables WHERE tablename='hosts' AND schemaname='public';";
			my $count = $an->DB->do_db_query({id => $id, query => $query})->[0]->[0];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_vars => {
				name1 => "count", value1 => $count
			}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
			if ($count < 1)
			{
				# Need to load the database.
				$an->DB->initialize_db({id => $id});
			}
		}
		
		# Set the first ID to be the one I read from later.
		$an->data->{sys}{read_db_id}    = $id if not $an->data->{sys}{read_db_id};
		$an->data->{sys}{use_db_fh}     = $an->data->{dbh}{$id};
		if (not $an->data->{sys}{db_timestamp})
		{
			my $query = "SELECT cast(now() AS timestamp with time zone)";
			$an->data->{sys}{db_timestamp}  = $an->DB->do_db_query({id => $id, query => $query})->[0]->[0];
			$an->data->{sys}{db_timestamp}  = $an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_vars => {
				name1 => "sys::db_timestamp",  value1 => $an->data->{sys}{db_timestamp},
			}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
		}
		$an->data->{sys}{host_id_query} = "SELECT host_id FROM hosts WHERE host_name = ".$an->data->{sys}{use_db_fh}->quote($an->hostname);
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_vars => {
			name1 => "sys::read_db_id",    value1 => $an->data->{sys}{read_db_id},
			name2 => "sys::use_db_fh",     value2 => $an->data->{sys}{use_db_fh},
			name3 => "sys::host_id_query", value2 => $an->data->{sys}{host_id_query},
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
	}
	if (not $connections)
	{
		# Failed to connect to any database.
		print $an->String->get({
			key		=>	"scancore_message_0002",
			variables	=>	{
				title		=>	$an->String->get({key => "scancore_title_0003"}),
				message		=>	$an->String->get({key => "scancore_error_0004"}),
			},
		}), "\n";
		exit(1);
	}
	
	# Look to see if any of the DBs fell behind and, if so, update their
	# 'hosts', 'alerts' and 'agents' tables.
	$an->DB->sync_dbs();
	
	# Now look to see if our hostname has changed.
	$an->DB->check_hostname();
	
	return($connections);
}

# This checks to see if the hostname changed and, if so, update the hosts table
# so that we don't accidentally create a separate entry for this host.
sub check_hostname
{
	my $self = shift;
	my $an   = $self->parent;
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_vars => { function => "sync_dbs", }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
	
	#$an->hostname();
	
	return(0);
}

# This 'checks last_updated -> last_updated_date' for this node on all DBs and
# if any are behind, it will read in the changes from the most up to date DB
sub sync_dbs
{
	my $self = shift;
	my $an   = $self->parent;
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_vars => { function => "sync_dbs", }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
	
	# Get this node's ID for each DB with:
	# 
	
	# Read the time as a unix timestamp for easier comparison with:
	# SELECT round(extract(epoch from now()));
	
	return(0);
}

# This loads a SQL schema into the specified DB.
sub load_schema
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 2, message_key => "scancore_log_0001", message_vars => { function => "load_schema" }, file => $THIS_FILE, line => __LINE__, log_to  => $an->data->{path}{log_file} });
	
	my $file = $parameter->{file} ? $parameter->{file} : "";
	my $id   = $parameter->{id}   ? $parameter->{id}   : "";
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_vars => { 
		name1 => "id",   value1 => $id, 
		name2 => "file", variable2 => $file 
	}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
	
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
	
	$an->Log->entry({log_level => 1, title_key => "scancore_title_0005", message_key => "scancore_log_0021", message_vars => {
		name => $an->data->{scancore}{db}{$id}{name}, 
		host => $an->data->{scancore}{db}{$id}{host}, 
		file => $file
	}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
	
	# Read in the SQL file and replace #!variable!name!# with the database
	# owner name.
	my $success = 1;
	my $user    = $an->data->{scancore}{db}{$id}{user};
	my $sql     = "";
	
	# Create the read shell call.
	my $shell_call = $file;
	$an->Log->entry({log_level => 2, message_key => "scancore_log_0007", message_vars => { shell_call => $shell_call }, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
	open (my $file_handle, "<$shell_call") or $an->Alert->error({fatal => 1, title_key => "scancore_title_0003", message_key => "scancore_error_0003", message_vars => { shell_call => $shell_call, error => $! }, code => 3, file => "$THIS_FILE", line => __LINE__});
	while (<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_vars => { 
			name1 => ">> line", value1 => $line 
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
		$line =~ s/#!variable!user!#/$user/g;
		$line =~ s/--.*//g;
		$line =~ s/\t/ /g;
		$line =~ s/\s+/ /g;
		$line =~ s/^\s+//g;
		$line =~ s/\s+$//g;
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_vars => { 
			name1 => "line", value1 => $line 
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
		$sql .= "$line\n";
	}
	close $file_handle;
	
	# Now we should be ready.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_vars => { 
		name1 => "sql", value1 => $sql
	}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
	
	# Now that I am ready, write!
	$an->DB->db_do_write({id => $id, query => $sql});
	
	return($success);
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
	
	$an->Log->entry({log_level => 2, message_key => "scancore_log_0001", message_vars => {function => "initialize_db"}, file => $THIS_FILE, line => __LINE__, log_to  => $an->data->{path}{log_file} });
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_vars => {
		name1 => "id", value1 => $id
	}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
	
	# Tell the user we need to initialize
	$an->Log->entry({log_level => 1, title_key => "scancore_title_0005", message_key => "scancore_log_0009", message_vars => {name => $an->data->{scancore}{db}{$id}{name}, host => $an->data->{scancore}{db}{$id}{host}}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
	
	my $success = 1;
	
	# Read in the SQL file and replace #!variable!name!# with the database
	# owner name.
	my $user       = $an->data->{scancore}{db}{$id}{user};
	my $sql        = "";
	
	# Create the read shell call.
	my $shell_call = $an->data->{path}{scancore_sql};
	$an->Log->entry({log_level => 2, message_key => "scancore_log_0007", message_vars => {shell_call => $shell_call }, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
	open (my $file_handle, "<$shell_call") or $an->Alert->error({fatal => 1, title_key => "scancore_title_0003", message_key => "scancore_error_0003", message_vars => { shell_call => $shell_call, error => $! }, code => 3, file => "$THIS_FILE", line => __LINE__});
	while (<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_vars => {
			name1 => "line", value1 => $line
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_vars => {
		name1 => "sql", value1 => $sql
	}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file} });
	
	# Now that I am ready, disable autocommit, write and commit.
	$an->DB->db_do_write({id => $id, query => $sql});
	
	
	return($success);
};

1;
