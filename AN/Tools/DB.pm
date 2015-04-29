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
	
	my $self = {
	};
	
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

# This does a database query and returns the resulting array. It must be passed
# the ID of the database to connect to.
sub db_do_query
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
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
	$an->Log->entry({log_level => 2, title_key => "scancore_title_0001", message_key => "scancore_log_0006", message_vars => {name1 => "id", value1 => $id, name2 => "query", value2 => $query}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to => $an->data->{path}{log_file} });
	
	# Prepare the query
	my $DBreq = $an->data->{dbh}{$id}->prepare($query) or $an->Alert->error({fatal => 1, title_key => "scancore_title_0003", message_key => "scancore_error_0001", message_vars => { query => $query, server => "$an->data->{scancore}{db}{$id}{host}:$an->data->{scancore}{db}{$id}{port} -> $an->data->{scancore}{db}{$id}{name}", db_error => $DBI::errstr}, code => 2, file => "$THIS_FILE", line => __LINE__ });
	
	# Execute on the query
	$DBreq->execute() or $an->Alert->error({ fatal => 1, title_key => "scancore_title_0003", message_key => "scancore_error_0002", message_vars => {query => $query, server => "$an->data->{scancore}{db}{$id}{host}:$an->data->{scancore}{db}{$id}{port} -> $an->data->{scancore}{db}{$id}{name}", db_error => $DBI::errstr, }, code => 3, file => "$THIS_FILE", line => __LINE__ });
	
	# Return the array
	return($DBreq->fetchrow_array());
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
	$an->Log->entry({log_level => 2, title_key => "scancore_title_0001", message_key => "scancore_log_0006", message_vars => {name1 => "id", value1 => $id, name2 => "query", value2 => $query}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to => $an->data->{path}{log_file} });
	
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
	
	# Setup my variables.
	my ($id, $sql);
	
	# Now see if the user passed the values in a hash reference or
	# directly.
	#print "$THIS_FILE ".__LINE__."; parameter: [$parameter]\n";
	if (ref($parameter) eq "HASH")
	{
		# Values passed in a hash, good.
		$id  = $parameter->{id}    ? $parameter->{id}    : 0;		# This should throw an error
		$sql = $parameter->{query} ? $parameter->{query} : "";	# This should throw an error
		print "$THIS_FILE ".__LINE__."; id: [$id], query: [$sql]\n";
	}
	else
	{
		# Values passed directly.
		$id  = defined $parameter ? $parameter : 0;	# This should throw an error
		$sql = defined $_[0]      ? $_[0]      : "";	# This should throw an error
		print "$THIS_FILE ".__LINE__."; id: [$id], query: [$sql]\n";
	}
	$an->Log->entry({log_level => 2, title_key => "scancore_title_0001", message_key => "scancore_log_0006", message_vars => {name1 => "id", value1 => $id, name2 => "sql", value2 => $sql}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to => $an->data->{path}{log_file} });
	
	my $errors = "";
	$an->Log->entry({log_level => 2, title_key => "scancore_title_0001", message_key => "scancore_log_0003", message_vars => {name1 => "sql", value1 => $sql}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to => $an->data->{path}{log_file} });
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
		
	$an->Log->entry({log_level => 2, title_key => "scancore_title_0001", message_key => "scancore_log_0003", message_vars => {name1 => "errors", value1 => $errors}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to => $an->data->{path}{log_file} });
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
		$an->Log->entry({log_level => 2, title_key => "scancore_title_0001", message_key => "scancore_log_0008", file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to => $an->data->{path}{log_file} });
		$an->data->{dbh}{$id}->commit;
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
	
	$an->Log->entry({log_level => 3, title_key => "scancore_title_0001", message_key => "scancore_log_0001", message_vars => {function => "connect_to_databases"}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to  => $an->data->{path}{log_file} });
	
	my $connections = 0;
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
	{
		### TODO: Read in the cache for each DB and write it out if we
		###       connect
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
		$an->Log->entry({log_level => 3, title_key => "scancore_title_0001", message_key => "scancore_log_0003", message_vars => {name1 => "db_connect_string", value1 => $db_connect_string}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to => $an->data->{path}{log_file} });
		
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
			
			# Now that I have connected, see if my 'nodes' table exists.
			my $query = "SELECT COUNT(*) FROM pg_catalog.pg_tables WHERE tablename='nodes';";
			my $count = $an->DB->db_do_query({id => $id, query => $query});
			$an->Log->entry({log_level => 2, title_key => "scancore_title_0001", message_key => "scancore_log_0003", message_vars => {name1 => "count", value1 => $count}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to => $an->data->{path}{log_file} });
			if ($count < 1)
			{
				# Need to load the database.
				$an->DB->initialize_db({id => $id});
			}
		}
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
	
	return($connections);
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
	
	$an->Log->entry({log_level => 2, title_key => "scancore_title_0001", message_key => "scancore_log_0001", message_vars => {function => "initialize_db"}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to  => $an->data->{path}{log_file} });
	$an->Log->entry({log_level => 2, title_key => "scancore_title_0001", message_key => "scancore_log_0003", message_vars => {name1 => "id", value1 => $id}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to => $an->data->{path}{log_file} });
	
	# Tell the user we need to initialize
	$an->Log->entry({log_level => 1, title_key => "scancore_title_0005", message_key => "scancore_log_0009", message_vars => {name => $an->data->{scancore}{db}{$id}{name}, host => $an->data->{scancore}{db}{$id}{host}}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to => $an->data->{path}{log_file} });
	
	my $success = 1;
	
	# Read in the SQL file and replace #!variable!name!# with the database
	# owner name.
	my $user       = $an->data->{scancore}{db}{$id}{user};
	my $sql        = "";
	$an->Log->entry({log_level => 2, title_key => "scancore_title_0001", message_key => "scancore_log_0003", message_vars => {user => $user}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to => $an->data->{path}{log_file} });
	
	# Create the read shell call.
	my $shell_call = $an->data->{path}{scancore_sql};
	$an->Log->entry({log_level => 2, title_key => "scancore_title_0001", message_key => "scancore_log_0007", message_vars => {shell_call => $shell_call}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to => $an->data->{path}{log_file} });
	open (my $file_handle, "<$shell_call") or $an->Alert->error({fatal => 1, title_key => "scancore_title_0003", message_key => "scancore_error_0003", message_vars => { shell_call => $shell_call, error => $! }, code => 3, file => "$THIS_FILE", line => __LINE__});
	while (<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 2, title_key => "scancore_title_0001", message_key => "scancore_log_0003", message_vars => {name1 => "line", value1 => $line}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to => $an->data->{path}{log_file} });
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
	$an->Log->entry({log_level => 2, title_key => "scancore_title_0001", message_key => "scancore_log_0003", message_vars => {name1 => "sql", value1 => $sql}, file => $THIS_FILE, line => __LINE__, language => $an->data->{sys}{log_language}, log_to => $an->data->{path}{log_file} });
	
	# Now that I am ready, disable autocommit, write and commit.
	$an->DB->db_do_write($id, $sql);
	
	
	return($success);
};

1;
