package AN::Tools::DB;
# 
# This module contains methods used to access and manage ScanCore databases.
# 

# TODO: Move the ScanCore stuff into another Module and make this more generic.

use strict;
use warnings;
use DBI;
use Data::Dumper;
no warnings 'recursion';

our $VERSION  = "0.1.001";
my $THIS_FILE = "DB.pm";

### Methods;
# archive_table
# check_lock_age
# check_hostname
# commit_sql
# connect_to_databases
# disconnect_from_databases
# do_db_query
# do_db_write
# find_behind_databases
# get_sql_schema
# initialize_db
# load_schema
# locking
# mark_active
# prep_for_archive
# set_update_db_flag
# update_time
# verify_host_uuid
# wait_if_db_is_updating


#############################################################################################################
# House keeping methods                                                                                     #
#############################################################################################################

sub new
{
	my $class = shift;
	
	my $self = {};
	
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

# This takes an array of table columns and a hash of colum=variable pairs and uses that to archive the data
# from the history schema to a plain-text dump. 
# NOTE: 'modified_date' and 'history_id' should NOT be passed in to 'columns'. They will be ignored.
# NOTE: If we're asked to use an offset that is too high, we'll go into a loop and may end up doing some 
#       empty loops. We don't check to see if the offset is sensible, though setting it too high won't cause
#       the archive operation to fail, but it won't chunk as expected.
# NOTE: If using 'join_table', the table being archived will use the 'a.' prefix and the 'join_table' will 
#       use the 'b.' prefix. Please setup the conditionals accordingly.
sub archive_table
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "archive_table" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $table        = $parameter->{table}                        ? $parameter->{table}        : "";
	my $join_table   = $parameter->{join_table}                   ? $parameter->{join_table}   : "";
	my $offset       = $parameter->{offset}                       ? $parameter->{offset}       : 0;
	my $loop         = $parameter->{loop}                         ? $parameter->{loop}         : 0;
	my $division     = $parameter->{division}                     ? $parameter->{division}     : $an->data->{scancore}{archive}{division};
	my $compress     = $parameter->{compress}                     ? $parameter->{compress}     : 1;
	my $conditionals = ref($parameter->{conditionals}) eq "HASH"  ? $parameter->{conditionals} : "";
	my $columns      = ref($parameter->{columns})      eq "ARRAY" ? $parameter->{columns}      : [];
	my $column_count = @{$columns};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0008", message_variables => {
		name1 => "table",        value1 => $table, 
		name2 => "join_table",   value2 => $join_table, 
		name3 => "offset",       value3 => $offset, 
		name4 => "loop",         value4 => $loop, 
		name5 => "division",     value5 => $division, 
		name6 => "compress",     value6 => $compress, 
		name7 => "conditionals", value7 => ref($conditionals), 
		name8 => "column_count", value8 => $column_count, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Make these proper errors.
	if (not $table)
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0236", code => 236, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	if (not $offset)
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0237", message_variables => { table => $table }, code => 237, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	if (@{$columns} < 1)
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0238", message_variables => { table => $table }, code => 238, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# If the 'division' is not valid, override it
	$division = "" if not defined $division;
	if ($division !~ /^\d+$/)
	{
		$division = 60000;
		# Warn the user
		$an->Log->entry({log_level => 1, message_key => "notice_message_0016", message_variables => { 
			division => $division, 
			table    => $table, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# This will store the archive file(s).
	my $archives = [];
	
	# If the offset is greater than 'division' and 'loop' is '0', don't actually archive here. Instead,
	# go into a loop, setting the offset to the division amount until we hit the original offset.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "loop",                        value1 => $loop, 
		name2 => "division",                    value2 => $division,
		name3 => "scancore::archive::division", value3 => $an->data->{scancore}{archive}{division},
	}, file => $THIS_FILE, line => __LINE__});
	if (((not $loop) && ($division > 0) && ($offset > $division)))
	{
		# OK, how many chunks do we need, and how big will they be?
		my $chunk      = 0;
		my $chunk_size = 0;
		my $chunks     = ($offset / $division);
		# Round up if 'chunks' isn't a real number
		if ($chunks != int($chunks))
		{
			$chunks = int($chunks += 1);
		}
		# If the offset isn't divided evenly, pull the remainder and we'll add it to the first chunk.
		my $remainder  =  ($offset % $chunks);
		   $offset     -= $remainder;
		   $chunk_size =  ($offset / $chunks);
		$an->Log->entry({log_level => 2, message_key => "tools_log_0042", message_variables => {
			chunks     => $chunks, 
			chunk_size => $chunk_size, 
			remainder  => $remainder,
		}, file => $THIS_FILE, line => __LINE__});
		# Enter the loop (the 'left' is mainly for logging purposes).
		my $left       = $offset;
		my $start_time =  time;
		for (1..$chunks)
		{
			$chunk++;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "chunk", value1 => $chunk, 
			}, file => $THIS_FILE, line => __LINE__});
			my $this_chunk = $chunk_size;
			if ($remainder)
			{
				# Adding the remainder to this chunk
				$this_chunk += $remainder;
				$remainder = 0;
			}
			$left -= $this_chunk;
			$left = 0 if $left < 0;
			
			# Re-enter, this time with a smaller offset
			$an->Log->entry({log_level => 2, message_key => "tools_log_0043", message_variables => {
				chunk      => $chunk, 
				this_chunk => $this_chunk, 
				left       => $left,
			}, file => $THIS_FILE, line => __LINE__});
			my $this_archive = $an->DB->archive_table({
				table        => $table, 
				join_table   => $join_table, 
				offset       => $this_chunk, 
				division     => $division, 
				conditionals => $conditionals,
				columns      => $columns,
				loop         => $chunk, 
			});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "this_archive",      value1 => $this_archive, 
				name2 => "this_archive->[0]", value2 => $this_archive->[0], 
			}, file => $THIS_FILE, line => __LINE__});
			push @{$archives}, $this_archive->[0];
		}
		
		# Logging...
		foreach my $archive_file (@{$archives})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "archive_file", value1 => $archive_file, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		my $total_archive_time = time - $start_time;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "total_archive_time", value1 => $total_archive_time, 
		}, file => $THIS_FILE, line => __LINE__});
		return($archives);
	}
	
	# Get the datestamp for the requested offset (first query is the usual one, second one is used when 
	# we've got a joined table).
	my $said_where = 0;
	my $query      = "
SELECT 
    modified_date 
FROM 
    history.$table 
";
	if (ref($conditionals) eq "HASH")
	{
		foreach my $key (sort {$a cmp $b} keys %{$conditionals})
		{
			my $value =  $conditionals->{$key};
			my $say   =  $said_where ? "AND" : "WHERE";
			   $query .= "$say 
    $key = ".$an->data->{sys}{use_db_fh}->quote($value)."
";
			$said_where = 1;
		}
	}
	$query .= "ORDER BY 
    modified_date ASC 
OFFSET ".$an->data->{sys}{use_db_fh}->quote($offset)." 
LIMIT 1
;";

	# If we are using a joined table, re-write this accordingly.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "join_table", value1 => $join_table, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($join_table)
	{
		my $said_where = 0;
		   $query      = "
SELECT 
    a.modified_date 
FROM 
    history.$table a, 
    $join_table b 
";
		foreach my $key (sort {$a cmp $b} keys %{$conditionals})
		{
			my $say   =  $said_where ? "AND" : "WHERE";
			my $value =  $conditionals->{$key};
			# I usually want to quote the value, unless it's a referenced column 
			# from the joined table (which will always start with 'a.foo' or 
			# 'b.foo').
			if ($value !~ /^[ab]\./)
			{
				$value = $an->data->{sys}{use_db_fh}->quote($value);
			}
			$said_where =  1;
			$query      .= "$say \n    $key = $value \n";
		}
		$query .= "ORDER BY 
    a.modified_date ASC 
OFFSET ".$an->data->{sys}{use_db_fh}->quote($offset)." 
LIMIT 1
";
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $date = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__})->[0]->[0];
	   $date = "" if not defined $date;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "date", value1 => $date, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If I got a date, proceed.
	my $archive_file = "";
	if ($date)
	{
		# Start the output file.
		my $start_time    =  time;
		my $date_and_time =  $an->Get->date_and_time({split_date_time => 0, no_spaces => 1});
		   $date_and_time =~ s/:/-/g;
		   $archive_file  =  $an->data->{path}{scancore_archive}."/scancore-archive_".$table."_".$an->hostname."_".$date_and_time."_".$loop.".out";
		   $archive_file  =~ s/\/+/\//g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "loop",          value1 => $loop,
			name2 => "date_and_time", value2 => $date_and_time,
			name3 => "archive_file",  value3 => $archive_file,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Build the 'COPY' header and query (we'll rebuild the query if we have a join table)
		my $header = "COPY $table (";
		my $query  = "\nSELECT \n";
		foreach my $column (@{$columns})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "column", value1 => $column, 
			}, file => $THIS_FILE, line => __LINE__});
			next if (($column eq "modified_date") or ($column eq "history_id"));
			$header .= "$column, ";
			$query  .= "    $column, \n";
		}
		$header .= "modified_date) FROM stdin;\n";
		$query  .= "    modified_date 
FROM 
    history.$table 
WHERE 
    modified_date <= '$date'
";
		if (ref($conditionals) eq "HASH")
		{
			foreach my $key (sort {$a cmp $b} keys %{$conditionals})
			{
				my $value = $conditionals->{$key};
				$query .= "AND \n    $key = ".$an->data->{sys}{use_db_fh}->quote($value)." \n";
			}
		}
	$query .= "ORDER BY 
    modified_date DESC
;";
		# Rebuild the query if we have a join table.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "join_table", value1 => $join_table, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($join_table)
		{
			# Rebuild the query...
			$query = "\nSELECT \n";
			foreach my $column (@{$columns})
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "column", value1 => $column, 
				}, file => $THIS_FILE, line => __LINE__});
				next if (($column eq "modified_date") or ($column eq "history_id"));
				$query  .= "    a.".$column.", \n";
			}
			$query  .= "    a.modified_date 
FROM 
    history.$table a, 
    $join_table b
WHERE 
    a.modified_date <= '$date'
";
			if (ref($conditionals) eq "HASH")
			{
				foreach my $key (sort {$a cmp $b} keys %{$conditionals})
				{
					my $value = $conditionals->{$key};
					# I usually want to quote the value, unless it's a referenced column 
					# from the joined table (which will always start with 'a.foo' or 
					# 'b.foo').
					if ($value !~ /^[ab]\./)
					{
						$value = $an->data->{sys}{use_db_fh}->quote($value);
					}
					$query .= "AND \n    $key = $value \n";
				}
			}
			$query .= "ORDER BY 
    a.modified_date DESC
;";
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "header", value1 => $header, 
			name2 => "query",  value2 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Open the file
		my $header_date = $an->Get->date_and_time({split_date_time => 0});
		my $shell_call  = $archive_file;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, ">$shell_call") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0015", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
		print $file_handle "-- $header_date\n";
		print $file_handle $an->data->{scancore}{archive}{dump_file_header}."\n";
		print $file_handle $header;
		
		# Do the query against the source DB and loop through the results.
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "count",   value1 => $count, 
			name2 => "results", value2 => $results, 
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $row (@{$results})
		{
			# Build the string.
			my $line = "";
			my $i    = 0;
			foreach my $column (@{$columns})
			{
				next if (($column eq "modified_date") or ($column eq "history_id"));
				my $value = defined $row->[$i] ? $row->[$i] : '\N';
				$i++;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "i",      value1 => $i, 
					name2 => "column", value2 => $column, 
					name3 => "value",  value3 => $value, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# We need to convert tabs and newlines into \t and \n
				$value =~ s/\t/\\t/g;
				$value =~ s/\n/\\n/g;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "<< value", value1 => $value, 
				}, file => $THIS_FILE, line => __LINE__});
			
				$line .= $value."\t";
			}
			
			# Add the modified_date and close the line
			my $modified_date =  defined $row->[$i] ? $row->[$i] : '\N';
			   $line          .= $modified_date."\n";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "i",             value1 => $i, 
				name2 => "modified_date", value2 => $modified_date, 
				name3 => "line",          value3 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# The 'history_id' is NOT consistent between databases! So we don't record it here.
			print $file_handle $line;
		}
		
		# Close it up.
		print $file_handle "\\.\n\n";;
		close $file_handle;
		
		# Compress, if requested.
		if ($compress)
		{
			my ($compressed_file, $output) = $an->System->compress_file({file => $archive_file});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "compressed_file", value1 => $compressed_file, 
				name2 => "output",          value2 => $output, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($compressed_file)
			{
				$archive_file = $compressed_file;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "archive_file", value1 => $archive_file, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Delete the records now (I'll redo this if there is a join table in a moment).
		$said_where = 0;
		$query      = "
DELETE FROM 
    history.$table 
";
		if (ref($conditionals) eq "HASH")
		{
			foreach my $key (sort {$a cmp $b} keys %{$conditionals})
			{
				my $value =  $conditionals->{$key};
				my $say   = $said_where ? "AND" : "WHERE";
				   $query .= "$say 
    $key = ".$an->data->{sys}{use_db_fh}->quote($value)." 
";
				$said_where = 1;
			}
		}
		my $say   = $said_where ? "AND" : "WHERE";
		   $query .= "$say 
    modified_date <= '$date' 
;";
		# Rebuild the query if we have a join table.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "join_table", value1 => $join_table, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($join_table)
		{
			$query = "
DELETE FROM 
    history.$table a
USING 
    $join_table b
WHERE 
    a.modified_date <= '$date'
";
			if (ref($conditionals) eq "HASH")
			{
				foreach my $key (sort {$a cmp $b} keys %{$conditionals})
				{
					my $value =  $conditionals->{$key};
					# I usually want to quote the value, unless it's a referenced column 
					# from the joined table (which will always start with 'a.foo' or 
					# 'b.foo').
					if ($value !~ /^[ab]\./)
					{
						$value = $an->data->{sys}{use_db_fh}->quote($value);
					}
					$query .= "AND \n    $key = $value \n";
				}
			}
			$query .= ";";
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Do the delete
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
		
		# Record how long all this took
		my $archive_time = time - $start_time;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "archive_time", value1 => $archive_time, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	push @{$archives}, $archive_file;
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "archives", value1 => $archives, 
	}, file => $THIS_FILE, line => __LINE__});
	return($archives);
}

# This checks to see if 'sys::local_lock_active' is set. If it is, its age is checked and if the age is >50%
# of scancore::locking::reap_age, it will renew the lock.
sub check_lock_age
{
	my $self = shift;
	my $an   = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_lock_age" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make sure we've got the 'local_lock_active' and 'reap_age' variables set.
	if ((not defined $an->data->{sys}{local_lock_active}) or ($an->data->{sys}{local_lock_active} =~ /\D/))
	{
		$an->data->{sys}{local_lock_active} = 0;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::local_lock_active", value1 => $an->data->{sys}{local_lock_active}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	if ((not $an->data->{scancore}{locking}{reap_age}) or ($an->data->{scancore}{locking}{reap_age} =~ /\D/))
	{
		$an->data->{scancore}{locking}{reap_age} = 300;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "scancore::locking::reap_age", value1 => $an->data->{scancore}{locking}{reap_age}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# If I have an active lock, check its age and also update the ScanCore lock file.
	my $renewed = 0;
	if ($an->data->{sys}{local_lock_active})
	{
		my $current_time  = time;
		my $lock_age      = $current_time - $an->data->{sys}{local_lock_active};
		my $half_reap_age = int($an->data->{scancore}{locking}{reap_age} / 2);
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "current_time",  value1 => $current_time, 
			name2 => "lock_age",      value2 => $lock_age, 
			name3 => "half_reap_age", value3 => $half_reap_age, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($lock_age > $half_reap_age)
		{
			$an->DB->locking({renew => 1});
			   $renewed                            = 1;
			   $an->data->{sys}{local_lock_active} = time;
			my $lock_file_age                      = $an->ScanCore->lock_file({'do' => "set"});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "renewed",                value1 => $renewed, 
				name2 => "sys::local_lock_active", value2 => $an->data->{sys}{local_lock_active}, 
				name3 => "lock_file_age",          value3 => $lock_file_age, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return($renewed);
}

### TODO: This isn't done...
# This checks to see if the hostname changed and, if so, update the hosts table so that we don't accidentally
# create a separate entry for this host.
sub check_hostname
{
	my $self = shift;
	my $an   = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_hostname" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	#$an->hostname();
	
	return(0);
}

# This commits the SQL queries in the 'sys::sql' array reference.
sub commit_sql
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "commit_sql" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $source = defined $parameter->{source} ? $parameter->{source} : $THIS_FILE;
	my $line   = defined $parameter->{line}   ? $parameter->{line}   : __LINE__;
	my $count  = @{$an->data->{sys}{sql}};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "source", value1 => $source, 
		name2 => "line",   value2 => $line, 
		name3 => "count",  value3 => $count, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# DEBUG
	foreach my $query (@{$an->data->{sys}{sql}})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	if ($count > 0)
	{
		$an->DB->do_db_write({query => $an->data->{sys}{sql}, source => $source, line => $line});
		$an->data->{sys}{sql} = [];
	}
	
	return($count);
}

# This will connect to the databases and record their database handles. It will also initialize the 
# databases, if needed.
sub connect_to_databases
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "connect_to_databases" }, file => $THIS_FILE, line => __LINE__});
	
	my $file  = defined $parameter->{file}  ? $parameter->{file}  : "";
	my $quiet = defined $parameter->{quiet} ? $parameter->{quiet} : 1;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "file",  value1 => $file, 
		name2 => "quiet", value2 => $quiet, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# We need the host_uuid before we connect.
	$an->Get->uuid({get => 'host_uuid'}) if not $an->data->{sys}{host_uuid};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::host_uuid", value1 => $an->data->{sys}{host_uuid}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# This will be used in a few cases where the local DB ID is needed (or the lack of it being set 
	# showing we failed to connect to the local DB).
	$an->data->{sys}{local_db_id} = "";
	
	# This will be set to '1' if either DB needs to be initialized or if the last_updated differs on any node.
	$an->data->{scancore}{db_resync_needed} = 0;
	
	# Now setup or however-many connections
	my $seen_connections       = [];
	my $connections            = 0;
	my $failed_connections     = [];
	my $successful_connections = [];
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
	{
		my $driver   = "DBI:Pg";
		my $host     = $an->data->{scancore}{db}{$id}{host}     ? $an->data->{scancore}{db}{$id}{host}     : ""; # This should fail
		my $port     = $an->data->{scancore}{db}{$id}{port}     ? $an->data->{scancore}{db}{$id}{port}     : 5432;
		my $name     = $an->data->{scancore}{db}{$id}{name}     ? $an->data->{scancore}{db}{$id}{name}     : ""; # This should fail
		my $user     = $an->data->{scancore}{db}{$id}{user}     ? $an->data->{scancore}{db}{$id}{user}     : ""; # This should fail
		my $password = $an->data->{scancore}{db}{$id}{password} ? $an->data->{scancore}{db}{$id}{password} : "";
		
		# If not set, we will always ping before connecting.
		if ((not exists $an->data->{scancore}{db}{$id}{ping_before_connect}) or (not defined $an->data->{scancore}{db}{$id}{ping_before_connect}))
		{
			$an->data->{scancore}{db}{$id}{ping_before_connect} = 1;
		}
		
		# These are not used yet.
		my $postgres_password = $an->data->{scancore}{db}{$id}{postgres_password} ? $an->data->{scancore}{db}{$id}{postgres_password} : "";
		my $initialize        = $an->data->{scancore}{db}{$id}{initialize}        ? $an->data->{scancore}{db}{$id}{initialize}        : 0;
		
		# Make sure the user didn't specify the same target twice.
		my $target_host = "$host:$port";
		my $duplicate   = 0;
		foreach my $existing_host (sort {$a cmp $b} @{$seen_connections})
		{
			if ($existing_host eq $target_host)
			{
				# User is connecting to the same target twice.
				$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0193", message_variables => { target => $target_host}, code => 193, file => $THIS_FILE, line => __LINE__});
				$duplicate = 1;
			}
		}
		if (not $duplicate)
		{
			push @{$seen_connections}, $target_host;
		}
		next if $duplicate;
		
		# Log what we're doing.
		$an->Log->entry({log_level => 3, title_key => "an_alert_title_0001", message_key => "tools_log_0007", message_variables => {
			id         => $id,
			driver     => $driver,
			host       => $host,
			port       => $port,
			name       => $name,
			user       => $user,
			password   => $password,
			initialize => $initialize,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "postgres_password", value1 => $postgres_password, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Assemble my connection string
		my $db_connect_string = "$driver:dbname=$name;host=$host;port=$port";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "db_connect_string", value1 => $db_connect_string, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "scancore::db::${id}::ping_before_connect", value1 => $an->data->{scancore}{db}{$id}{ping_before_connect}, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{scancore}{db}{$id}{ping_before_connect})
		{
			# Can I ping?
			my ($pinged) = $an->Check->ping({ping => $host, count => 1});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "pinged", value1 => $pinged, 
			}, file => $THIS_FILE, line => __LINE__});
			if (not $pinged)
			{
				$an->Log->entry({log_level => 1, message_key => "warning_message_0002", message_variables => { id => $id }, file => $THIS_FILE, line => __LINE__});
				
				$an->data->{scancore}{db}{$id}{connection_error} = [];
				push @{$failed_connections}, $id;
				
				$an->Alert->warning({ message_key => "warning_message_0002", message_variables => { id => $id }, quiet => $quiet, file => $THIS_FILE, line => __LINE__});
				push @{$an->data->{scancore}{db}{$id}{connection_error}}, { message_key => "warning_message_0002", message_variables => { id => $id }};
				next;
			}
		}
		
		# Connect!
		my $dbh = "";
		### NOTE: The AN::Tools::DB->do_db_write() method, when passed an array, will automatically 
		###       disable autocommit, do the bulk write, then commit when done.
		# We connect with fatal errors, autocommit and UTF8 enabled.
		eval { $dbh = DBI->connect($db_connect_string, $user, $password, {
			RaiseError     => 1,
			AutoCommit     => 1,
			pg_enable_utf8 => 1
		}); };
		if ($@)
		{
			# Something went wrong...
			$an->Alert->warning({message_key => "warning_message_0008", message_variables => {
				id   => $id,
				host => $host,
				name => $name,
			}, quiet => $quiet, file => $THIS_FILE, line => __LINE__});
			$an->data->{scancore}{db}{$id}{connection_error} = [];
			push @{$failed_connections}, $id;
			if (not defined $DBI::errstr)
			{
				# General error
				$an->Alert->warning({ message_key => "warning_message_0009", message_variables => { dbi_error => $@ }, quiet => $quiet, file => $THIS_FILE, line => __LINE__});
				push @{$an->data->{scancore}{db}{$id}{connection_error}}, { message_key => "warning_message_0009", message_variables => { dbi_error => $@ }};
			}
			elsif ($DBI::errstr =~ /No route to host/)
			{
				$an->Alert->warning({ message_key => "warning_message_0010", message_variables => { port => $port }, quiet => $quiet, file => $THIS_FILE, line => __LINE__});
				push @{$an->data->{scancore}{db}{$id}{connection_error}}, { message_key => "warning_message_0010", message_variables => { port => $port }};
			}
			elsif ($DBI::errstr =~ /no password supplied/)
			{
				$an->Alert->warning({ message_key => "warning_message_0011", message_variables => {
					id          => $id,
					config_file => $an->data->{path}{striker_config},
				}, quiet => $quiet, file => $THIS_FILE, line => __LINE__});
				push @{$an->data->{scancore}{db}{$id}{connection_error}}, { message_key => "warning_message_0011", message_variables => {
					id		=>	$id,
					config_file	=>	$an->data->{path}{striker_config},
				}};
			}
			elsif ($DBI::errstr =~ /password authentication failed for user/)
			{
				$an->Alert->warning({ message_key => "warning_message_0012", message_variables => {
					name        => $name,
					host        => $host,
					user        => $user,
					id          => $id,
					config_file => $an->data->{path}{striker_config},
				}, quiet => $quiet, file => $THIS_FILE, line => __LINE__});
				push @{$an->data->{scancore}{db}{$id}{connection_error}}, { message_key => "warning_message_0012", message_variables => {
					user		=>	$user,
					id		=>	$id,
					config_file	=>	$an->data->{path}{striker_config},
				}};
			}
			elsif ($DBI::errstr =~ /Connection refused/)
			{
				$an->Alert->warning({ message_key => "warning_message_0013", message_variables => {
					name => $name,
					host => $host,
					port => $port,
				}, quiet => $quiet, file => $THIS_FILE, line => __LINE__});
				push @{$an->data->{scancore}{db}{$id}{connection_error}}, { message_key => "warning_message_0013", message_variables => {
					name		=>	$name,
					host		=>	$host,
					port		=>	$port,
				}};
			}
			elsif ($DBI::errstr =~ /Temporary failure in name resolution/i)
			{
				$an->Alert->warning({ message_key => "warning_message_0014", message_variables => {
					name => $name,
					host => $host,
					port => $port,
				}, quiet => $quiet, file => $THIS_FILE, line => __LINE__});
				push @{$an->data->{scancore}{db}{$id}{connection_error}}, { message_key => "warning_message_0014", message_variables => {
					name		=>	$name,
					host		=>	$host,
					port		=>	$port,
				}};
			}
			else
			{
				$an->Alert->warning({ message_key => "warning_message_0009", message_variables => { dbi_error => $DBI::errstr }, quiet => $quiet, file => $THIS_FILE, line => __LINE__});
				push @{$an->data->{scancore}{db}{$id}{connection_error}}, { message_key => "warning_message_0009", message_variables => { dbi_error => $DBI::errstr }};
			}
		}
		elsif ($dbh =~ /^DBI::db=HASH/)
		{
			# Woot!
			$connections++;
			push @{$successful_connections}, $id;
			$an->data->{dbh}{$id} = $dbh;
			$an->Log->entry({log_level => 2, title_key => "tools_title_0004", message_key => "tools_log_0019", message_variables => {
				host => $host,
				port => $port,
				name => $name,
				id   => $id,
			}, file => $THIS_FILE, line => __LINE__});
			
			# Now that I have connected, see if my 'hosts' table exists.
			my $query = "SELECT COUNT(*) FROM pg_catalog.pg_tables WHERE tablename='hosts' AND schemaname='public';";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "query", value1 => $query
			}, file => $THIS_FILE, line => __LINE__});
			
			my $count = $an->DB->do_db_query({id => $id, query => $query, source => $THIS_FILE, line => __LINE__})->[0]->[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "count", value1 => $count
			}, file => $THIS_FILE, line => __LINE__});
			if ($count < 1)
			{
				# Need to load the database.
				$an->DB->initialize_db({id => $id});
			}
			
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "sys::read_db_id", value1 => $an->data->{sys}{read_db_id}, 
				name2 => "dbh::$id",        value2 => $an->data->{dbh}{$id}, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Set the first ID to be the one I read from later. Alternatively, if this host is 
			# local, use it.
			if (($host eq $an->hostname)       or 
			    ($host eq $an->short_hostname) or 
			    ($host eq "localhost")         or 
			    ($host eq "127.0.0.1")         or 
			    (not $an->data->{sys}{read_db_id}))
			{
				$an->data->{sys}{read_db_id}  = $id;
				$an->data->{sys}{local_db_id} = $id;
				$an->data->{sys}{use_db_fh}   = $an->data->{dbh}{$id};
				
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "sys::read_db_id", value1 => $an->data->{sys}{read_db_id}, 
					name2 => "sys::use_db_fh",  value2 => $an->data->{sys}{use_db_fh}
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			# Get a time stamp for this run, if not yet gotten.
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "dbh::$id",          value1 => $an->data->{dbh}{$id}, 
				name2 => "sys::db_timestamp", value2 => $an->data->{sys}{db_timestamp}
			}, file => $THIS_FILE, line => __LINE__});
			if (not $an->data->{sys}{db_timestamp})
			{
				my $query = "SELECT cast(now() AS timestamp with time zone)";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "query", value1 => $query
				}, file => $THIS_FILE, line => __LINE__});
				$an->data->{sys}{db_timestamp} = $an->DB->do_db_query({id => $id, query => $query, source => $THIS_FILE, line => __LINE__})->[0]->[0];
				
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "sys::db_timestamp",  value1 => $an->data->{sys}{db_timestamp},
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "sys::read_db_id",   value1 => $an->data->{sys}{read_db_id},
				name2 => "sys::use_db_fh",    value2 => $an->data->{sys}{use_db_fh},
				name3 => "sys::db_timestamp", value3 => $an->data->{sys}{db_timestamp},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Do I have any connections? Don't die, if not, just return.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "connections", value1 => $connections, 
	}, file => $THIS_FILE, line => __LINE__});
	if (not $connections)
	{
		# Failed to connect to any database. Log this, print to the caller and return.
		$an->Log->entry({log_level => 1, message_key => "tools_log_0021", message_variables => {
			title		=>	$an->String->get({key => "tools_title_0003"}),
			message		=>	$an->String->get({key => "error_message_0060"}),
		}, file => $THIS_FILE, line => __LINE__});
		print $an->String->get({ key => "tools_log_0021", variables => {
			title		=>	$an->String->get({key => "tools_title_0003"}),
			message		=>	$an->String->get({key => "error_message_0060"}),
		}})."\n";
		return($connections);
	}
	
	# Report any failed DB connections
	foreach my $id (@{$failed_connections})
	{
		# Copy my alert hash before I delete the id.
		my $error_array = [];
		foreach my $hash (@{$an->data->{scancore}{db}{$id}{connection_error}})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1  => "hash", value1 => $hash
			}, file => $THIS_FILE, line => __LINE__});
			push @{$error_array}, $hash;
		}
		
		# Delete this DB so that we don't try to use it later.
		$an->Log->entry({log_level => 3, message_key => "error_title_0018", message_variables => {
			id	=>	$id
		}, file => $THIS_FILE, line => __LINE__});
		delete $an->data->{scancore}{db}{$id};
		
		# If I've not sent an alert about this DB loss before, send one now.
		my $set = $an->Alert->check_alert_sent({
			type			=>	"warning",
			alert_sent_by		=>	$THIS_FILE,
			alert_record_locator	=>	$id,
			alert_name		=>	"connect_to_db",
			modified_date		=>	$an->data->{sys}{db_timestamp},
		});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1  => "set", value1 => $set
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($set)
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1  => "error_array", value1 => $error_array
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $hash (@{$error_array})
			{
				my $message_key       = $hash->{message_key};
				my $message_variables = $hash->{message_variables};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "hash",              value1 => $hash, 
					name2 => "message_key",       value2 => $message_key, 
					name3 => "message_variables", value3 => $message_variables, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# These are warning level alerts.
				$an->Alert->register_alert({
					alert_level		=>	"warning", 
					alert_agent_name	=>	"ScanCore",
					alert_title_key		=>	"an_alert_title_0004",
					alert_message_key	=>	$message_key,
					alert_message_variables	=>	$message_variables,
				});
			}
		}
	}
	
	# Send an 'all clear' message if a now-connected DB previously wasn't.
	foreach my $id (@{$successful_connections})
	{
		# Query to see if the newly connected host is in the DB yet. If it isn't, don't send an
		# alert as it'd cause a duplicate UUID error.
		my $query = "SELECT COUNT(*) FROM hosts WHERE host_name = ".$an->data->{sys}{use_db_fh}->quote($an->data->{scancore}{db}{$id}{host}).";";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query
		}, file => $THIS_FILE, line => __LINE__});
		my $count = $an->DB->do_db_query({id => $id, query => $query, source => $THIS_FILE, line => __LINE__})->[0]->[0];
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "count", value1 => $count
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($count > 0)
		{
			my $cleared = $an->Alert->check_alert_sent({
				type			=>	"clear",
				alert_sent_by		=>	$THIS_FILE,
				alert_record_locator	=>	$id,
				alert_name		=>	"connect_to_db",
				modified_date		=>	$an->data->{sys}{db_timestamp},
			});
			if ($cleared)
			{
				$an->Alert->register_alert({
					alert_level		=>	"warning", 
					alert_agent_name	=>	"ScanCore",
					alert_title_key		=>	"an_alert_title_0006",
					alert_message_key	=>	"cleared_message_0001",
					alert_message_variables	=>	{
						name			=>	$an->data->{scancore}{db}{$id}{name},
						host			=>	$an->data->{scancore}{db}{$id}{host},
						port			=>	$an->data->{scancore}{db}{$id}{port} ? $an->data->{scancore}{db}{$id}{port} : 5432,
					},
				});
			}
		}
	}

	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::host_uuid", value1 => $an->data->{sys}{host_uuid}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{host_uuid} !~ /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/)
	{
		# derp
		$an->Log->entry({log_level => 0, message_key => "error_message_0061", file => $THIS_FILE, line => __LINE__});
		
		# Disconnect and set the connection count to '0'.
		$an->DB->disconnect_from_databases();
		$connections = 0;
	}
	
	# For now, we just find which DBs are behind and let each agent deal with bringing their tables up to
	# date.
	$an->DB->find_behind_databases({file => $file});
	
	# Hold if a lock has been requested.
	$an->DB->locking();
	
	# Mark that we're not active.
	$an->DB->mark_active({set => 1});
	
	return($connections);
}

# This cleanly closes any open file handles.
sub disconnect_from_databases
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "disconnect_from_databases" }, file => $THIS_FILE, line => __LINE__});
	
	my $marked_inactive = 0;
	foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
	{
		# Don't do anything if there isn't an active file handle for this DB.
		next if ((not $an->data->{dbh}{$id}) or ($an->data->{dbh}{$id} !~ /^DBI::db=HASH/));
		
		# Clear locks and mark that we're done running.
		if (not $marked_inactive)
		{
			$an->DB->mark_active({set => 0});
			$an->DB->locking({release => 1});
			$marked_inactive = 1;
		}
		
		$an->data->{dbh}{$id}->disconnect;
		delete $an->data->{dbh}{$id};
	}
	
	# Delete the stored DB-related values.
	delete $an->data->{sys}{db_timestamp};
	delete $an->data->{sys}{use_db_fh};
	delete $an->data->{sys}{read_db_id};
	
	return(0);
}

# This does a database query and returns the resulting array. It must be passed the ID of the database to 
# connect to.
sub do_db_query
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "do_db_query" }, file => $THIS_FILE, line => __LINE__});
	
	# Where we given a specific ID to use?
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "parameter->{id}", value1 => $parameter->{id}, 
	}, file => $THIS_FILE, line => __LINE__}) if $parameter->{id};
	my $id = $parameter->{id} ? $parameter->{id} : $an->data->{sys}{read_db_id};
	
	if (not $id)
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0098", code => 98, file => $THIS_FILE, line => __LINE__});
		# Return nothing in case the user is blocking fatal errors.
		return (undef);
	}
	
	my $source = $parameter->{source} ? $parameter->{source} : "";
	my $line   = $parameter->{line}   ? $parameter->{line}   : "";
	my $query  = $parameter->{query}  ? $parameter->{query}  : "";	# This should throw an error
	$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
		name1 => "id",       value1 => $id, 
		name2 => "dbh::$id", value2 => $an->data->{dbh}{$id}, 
		name3 => "query",    value3 => $query, 
		name4 => "source",   value4 => $source, 
		name5 => "line",     value5 => $line, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Prepare the query
	if (not defined $an->data->{dbh}{$id})
	{
		# Can't proceed on an undefined connection...
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_title_0028", message_variables => {
			server => $an->data->{scancore}{db}{$id}{host}.":".$an->data->{scancore}{db}{$id}{port}." -> ".$an->data->{scancore}{db}{$id}{name}, 
		}, code => 4, file => $THIS_FILE, line => __LINE__});
	}
	
	# If I am still alive check if any locks need to be renewed.
	$an->DB->check_lock_age;
	
	# Do I need to log the transaction?
	if ($an->Log->db_transactions())
	{
		$an->Log->entry({log_level => 0, message_key => "an_variables_0004", message_variables => {
			name1 => "query",  value1 => $query, 
			name2 => "id",     value2 => $id,
			name3 => "source", value3 => $source, 
			name4 => "line",   value4 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Do the query.
	my $DBreq = $an->data->{dbh}{$id}->prepare($query) or $an->Alert->error({title_key => "tools_title_0003", message_key => "error_title_0029", message_variables => { 
		query    => $query, 
		server   => $an->data->{scancore}{db}{$id}{host}.":".$an->data->{scancore}{db}{$id}{port}." -> ".$an->data->{scancore}{db}{$id}{name},
		db_error => $DBI::errstr, 
	}, code => 2, file => $THIS_FILE, line => __LINE__});
	
	### TODO: If a target DB becomes unavailable, call a disconnect and remove its ID from the list of DBs.
	# Execute on the query
	$DBreq->execute() or $an->Alert->error({title_key => "tools_title_0003", message_key => "error_title_0030", message_variables => {
					query    => $query, 
					server   => $an->data->{scancore}{db}{$id}{host}.":".$an->data->{scancore}{db}{$id}{port}." -> ".$an->data->{scancore}{db}{$id}{name}, 
					db_error => $DBI::errstr
				}, code => 3, file => $THIS_FILE, line => __LINE__});
	
	# Return the array
	return($DBreq->fetchall_arrayref());
}

# This records data to one or all of the databases. If an ID is passed, the query is written to one database only. Otherwise, it will be written to all DBs.
sub do_db_write
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "do_db_write" }, file => $THIS_FILE, line => __LINE__});
	
	# Setup my variables.
	my $id      = $parameter->{id}      ? $parameter->{id}      : "";
	my $source  = $parameter->{source}  ? $parameter->{source}  : $THIS_FILE;
	my $line    = $parameter->{line}    ? $parameter->{line}    : "";
	my $query   = $parameter->{query}   ? $parameter->{query}   : "";
	my $reenter = $parameter->{reenter} ? $parameter->{reenter} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
		name1 => "id",      value1 => $id, 
		name2 => "source",  value2 => $source, 
		name3 => "line",    value3 => $line, 
		name4 => "query",   value4 => $query, 
		name5 => "reenter", value5 => $reenter, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If I don't have a query, die.
	if (not $query)
	{
		print $an->String->get({ key => "tools_log_0021", variables => {
			title   => $an->String->get({key => "tools_title_0003"}),
			message => $an->String->get({key => "error_title_0026"}),
		}})."\n";
		$an->nice_exit({exit_code => 1});
	}
	
	# If I am still alive check if any locks need to be renewed.
	$an->DB->check_lock_age;
	
	# This array will hold either just the passed DB ID or all of them, if no ID was specified.
	my @db_ids;
	if ($id)
	{
		push @db_ids, $id;
	}
	else
	{
		#foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
		foreach my $id (sort {$a cmp $b} keys %{$an->data->{dbh}})
		{
			push @db_ids, $id;
		}
	}
	
	# Sort out if I have one or many queries.
	my $limit     = 25000;
	my $count     = 0;
	my $query_set = [];
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "query",                       value1 => $query, 
		name2 => "sys::db::maximum_batch_size", value2 => $an->data->{sys}{db}{maximum_batch_size}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{db}{maximum_batch_size})
	{
		if ($an->data->{sys}{db}{maximum_batch_size} =~ /\D/)
		{
			# Bad value.
			$an->data->{sys}{db}{maximum_batch_size} = 25000;
			$an->Log->entry({log_level => 0, message_key => "an_variables_0001", message_variables => {
				name1 => "sys::db::maximum_batch_size", value1 => $an->data->{sys}{db}{maximum_batch_size}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Use the set value now.
		$limit = $an->data->{sys}{db}{maximum_batch_size};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "limit", value1 => $limit, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	if (ref($query) eq "ARRAY")
	{
		# Multiple things to enter.
		$count = @{$query};
		
		# If I am re-entering, then we'll proceed normally. If not, and if we have more than 10k 
		# queries, we'll split up the queries into 10k chunks and re-enter.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "count",   value1 => $count, 
			name2 => "limit",   value2 => $limit, 
			name3 => "reenter", value3 => $reenter, 
		}, file => $THIS_FILE, line => __LINE__});
		if (($count > $limit) && (not $reenter))
		{
			my $i    = 0;
			my $next = $limit;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "i",    value1 => $i, 
				name2 => "next", value2 => $next, 
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $this_query (@{$query})
			{
				push @{$query_set}, $this_query;
				$i++;
				
				if ($i > $next)
				{
					# Commit this batch.
					foreach my $id (@db_ids)
					{
						# Commit this chunk to this DB.
						$an->DB->do_db_write({id => $id, query => $query_set, source => $THIS_FILE, line => $line, reenter => 1});
						
						# This can get memory intensive, so check our RAM usage and 
						# bail if we're eating too much.
						$an->ScanCore->check_ram_usage({
							program_name => $THIS_FILE, 
							check_usage  => 1,
							maximum_ram  => $an->data->{scancore}{maximum_ram},
						});
						
						# Wipe out the old set array, create it as a new anonymous array and reset 'i'.
						undef $query_set;
						$query_set =  [];
						$i         =  0;
					}
				}
			}
		}
		else
		{
			# Not enough to worry about or we're dealing with a chunk, proceed as normal.
			foreach my $this_query (@{$query})
			{
				push @{$query_set}, $this_query;
			}
		}
	}
	else
	{
		push @{$query_set}, $query;
	}
	foreach my $id (@db_ids)
	{
		# Do the actual query(ies)
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "id",    value1 => $id, 
			name2 => "count", value2 => $count, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($count)
		{
			$an->data->{dbh}{$id}->begin_work;
		}
		foreach my $query (@{$query_set})
		{
			# Record the query
			if ($an->Log->db_transactions())
			{
				$an->Log->entry({log_level => 0, message_key => "an_variables_0005", message_variables => {
					name1 => "query",    value1 => $query, 
					name2 => "id",       value2 => $id,
					name3 => "source",   value3 => $source, 
					name4 => "line",     value4 => $line, 
					name5 => "dbh::$id", value5 => $an->data->{dbh}{$id}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			if (not $an->data->{dbh}{$id})
			{
				$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0072", message_variables => { 
					id     => $id, 
					query  => $query, 
					server => $an->data->{scancore}{db}{$id}{host}.":".$an->data->{scancore}{db}{$id}{port}." -> ".$an->data->{scancore}{db}{$id}{name}, 
				}, code => 72, file => $THIS_FILE, line => __LINE__});
			}
			
			### TODO: If a target DB becomes unavailable, call a disconnect and remove its ID from the list of DBs.
			# Do the do.
			$an->data->{dbh}{$id}->do($query) or $an->Alert->error({title_key => "tools_title_0003", message_key => "error_title_0027", message_variables => { 
								query    => $query, 
								server   => $an->data->{scancore}{db}{$id}{host}.":".$an->data->{scancore}{db}{$id}{port}." -> ".$an->data->{scancore}{db}{$id}{name}, 
								db_error => $DBI::errstr
							}, code => 2, file => $THIS_FILE, line => __LINE__});
		}
		
		# Commit the changes.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "count", value1 => $count
		}, file => $THIS_FILE, line => __LINE__});
		if ($count)
		{
			$an->data->{dbh}{$id}->commit();
		}
	}
	
	if ($count)
	{
		# Free up some memory.
		undef $query_set;
	}
	
	return(0);
}

### TODO: If the tables were dropped for some reason, but the updated table left alone, a sync will be needed
###       but not set here. In v3, we should take an option table name and do:
###       'SELECT modified_data FROM $table ORDER BY modified_date DESC LIMIT 1;'
###       If any tables return a different value, or one table returns a value and another doesn't, set the 
###       resync-required flag.
# This returns the most up to date database ID, the time it was last updated and an array or DB IDs that are 
# behind.
sub find_behind_databases
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "find_behind_databases" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $file = $parameter->{file} ? $parameter->{file} : "";
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
    updated_host_uuid = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{host_uuid});
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
		my $last_updated = $an->DB->do_db_query({id => $id, query => $query, source => $THIS_FILE, line => __LINE__})->[0]->[0];
		   $last_updated = 0 if not defined $last_updated;
		   
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "last_updated",                       value1 => $last_updated, 
			name2 => "scancore::sql::source_updated_time", value2 => $an->data->{scancore}{sql}{source_updated_time}
		}, file => $THIS_FILE, line => __LINE__});
		if ($last_updated > $an->data->{scancore}{sql}{source_updated_time})
		{
			$an->data->{scancore}{sql}{source_updated_time} = $last_updated;
			$an->data->{scancore}{sql}{source_db_id}        = $id;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "scancore::sql::source_db_id",        value1 => $an->data->{scancore}{sql}{source_db_id}, 
				name2 => "scancore::sql::source_updated_time", value2 => $an->data->{scancore}{sql}{source_updated_time}
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		### TODO: Determine if I should be checking per-table... Is it possible for one agent's table
		###       to fall behind? Maybe, if the agent is deleted/recovered...
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
			if ($file)
			{
				# For a specific scan agent.
				$an->Log->entry({log_level => 1, message_key => "tools_log_0037", message_variables => { 
					id   => $id,
					file => $file,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# the core tables.
				$an->Log->entry({log_level => 1, message_key => "tools_log_0022", message_variables => { id => $id }, file => $THIS_FILE, line => __LINE__});
			}
			$an->data->{scancore}{db_to_update}{$id}{behind} = 1;
			
			# A database is behind, resync
			$an->data->{scancore}{db_resync_needed} = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "scancore::db_to_update::${id}::behind", value1 => $an->data->{scancore}{db_to_update}{$id}{behind}, 
				name2 => "scancore::db_resync_needed",            value2 => $an->data->{scancore}{db_resync_needed}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# This database is up to date.
			$an->data->{scancore}{db_to_update}{$id}{behind} = 0;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "scancore::db_to_update::${id}::behind", value1 => $an->data->{scancore}{db_to_update}{$id}{behind}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

### TODO: Finishe this someday
# This uses the '$an->data->{scancore}{sql}{source_db_id}' to call 'pg_dump' and get the database schema. 
# This is parsed and then used to add tables that are missing to other DBs.
sub get_sql_schema
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "get_sql_schema" }, file => $THIS_FILE, line => __LINE__});
	
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
	
	# Now I need to connect to the remote host and dump the DB schema. I need to do this by setting 
	# .pgpass.
	my $shell_call = "$pgpass";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, ">$shell_call") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0015", message_variables => { shell_call => $shell_call, error => $! }, code => 3, file => $THIS_FILE, line => __LINE__});
	print $file_handle "$host:*:*:$user:$password\n";
	close $file_handle;
	
	# Set the permissions on .pgpass
	my $mode = 0600;
	chmod $mode, $pgpass; 
	
	# Make the shell call.
	$shell_call =  $an->data->{path}{pg_dump}." --host $host";
	$shell_call .= " --port $port" if $port;
	$shell_call .= " --username $user --schema-only $name 2>&1 |";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open ($file_handle, "$shell_call") or $an->Alert->error({title_key => "tools_title_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
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
			# Stick the schema onto the table name if its not 'public'.
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
		#print "Recording the SQL schema for the table: [$this_table]\n";
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

# This will initialize the database using the data in the ScanCore.sql file.
sub initialize_db
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, message_key => "tools_log_0001", message_variables => { function => "initialize_db" }, file => $THIS_FILE, line => __LINE__});
	
	my $success = 1;
	my $id      = $parameter->{id} ? $parameter->{id} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "id", value1 => $id
	}, file => $THIS_FILE, line => __LINE__});
	
	# If I don't have an ID, die.
	if (not $id)
	{
		### TODO: Why don't we use the usual ->error()
		# what DB?
		print $an->String->get({key => "tools_log_0021", variables => {
			title		=>	$an->String->get({key => "tools_title_0003"}),
			message		=>	$an->String->get({key => "error_message_0067"}),
		}})."\n";
		$an->nice_exit({exit_code => 67});
	}
	
	# Tell the user we need to initialize
	$an->Log->entry({log_level => 1, title_key => "tools_title_0005", message_key => "tools_log_0020", message_variables => {
		name => $an->data->{scancore}{db}{$id}{name}, 
		host => $an->data->{scancore}{db}{$id}{host}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Read in the SQL file and replace #!variable!name!# with the database owner name.
	my $user = $an->data->{scancore}{db}{$id}{user};
	my $sql  = "";
	
	if (not $an->data->{path}{scancore_sql})
	{
		### NOTE: On striker dashboards, this error will prevent the user from logging in because !0
		###       exit codes abort the login. Therefor, if this is a dashbaord, we'll exit with 
		###       'code => 0'.
		# This is likely caused by running an agent directly on a system where ScanCore has never run
		# before.
		my $i_am_a = $an->Get->what_am_i();
		if ($i_am_a eq "dashboard")
		{
			$an->Alert->error({title_key => "an_0003", message_key => "error_message_0048", code => 0, file => $THIS_FILE, line => __LINE__});
			return("");
		}
		else
		{
			$an->Alert->error({title_key => "an_0003", message_key => "error_message_0048", code => 48, file => $THIS_FILE, line => __LINE__});
			return("");
		}
	}
	
	# Create the read shell call.
	my $shell_call = $an->data->{path}{scancore_sql};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "<$shell_call") or $an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0066", message_variables => { shell_call => $shell_call, error => $! }, code => 3, file => $THIS_FILE, line => __LINE__});
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sql", value1 => $sql, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Now that I am ready, disable autocommit, write and commit.
	$an->DB->do_db_write({id => $id, query => $sql, source => $THIS_FILE, line => __LINE__});
	$an->data->{sys}{db_initialized}{$id} = 1;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::db_initialized::$id", value1 => $an->data->{sys}{db_initialized}{$id}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Mark that we need to update the DB.
	$an->data->{scancore}{db_resync_needed} = 1;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "scancore::db_resync_needed", value1 => $an->data->{scancore}{db_resync_needed}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	return($success);
};

# This loads a SQL schema into the specified DB.
sub load_schema
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "load_schema" }, file => $THIS_FILE, line => __LINE__});
	
	my $file = $parameter->{file} ? $parameter->{file} : "";
	my $id   = $parameter->{id}   ? $parameter->{id}   : "";
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => { 
		name1 => "id",   value1 => $id, 
		name2 => "file", value2 => $file 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Do I know which DB I am loading the schema into?
	if (not $id)
	{
		# We can't load the schema into all. That's not safe as DBs
		# can't be sync'ed until their schema exists.
		print $an->String->get({
			key		=>	"tools_log_0021",
			variables	=>	{
				title		=>	$an->String->get({key => "tools_title_0003"}),
				message		=>	$an->String->get({key => "error_message_0062"}),
			},
		})."\n";
		$an->nice_exit({exit_code => 62});
	}
	
	# Do I have a file to load?
	if (not $file)
	{
		# what file?
		print $an->String->get({
			key		=>	"tools_log_0021",
			variables	=>	{
				title		=>	$an->String->get({key => "tools_title_0003"}),
				message		=>	$an->String->get({key => "error_message_0063"}),
			},
		})."\n";
		$an->nice_exit({exit_code => 63});
	}
	# Does the file exist?
	if (not -e $file)
	{
		# file not found
		print $an->String->get({
			key		=>	"tools_log_0021",
			variables	=>	{
				title		=>	$an->String->get({key => "tools_title_0003"}),
				message		=>	$an->String->get({key => "error_message_0064", variables => { file => $file }}),
			},
		})."\n";
		$an->nice_exit({exit_code => 64});
	}
	# And can I read it?
	if (not -r $file)
	{
		# file found, but can't be read. <sad_trombine />
		print $an->String->get({
			key		=>	"tools_log_0021",
			variables	=>	{
				title		=>	$an->String->get({key => "tools_title_0003"}),
				message		=>	$an->String->get({key => "error_message_0065", variables => { file => $file }}),
			},
		})."\n";
		$an->nice_exit({exit_code => 65});
	}
	
	# Tell the user we're loading a schema
	$an->Log->entry({log_level => 1, title_key => "tools_title_0005", message_key => "tools_log_0023", message_variables => {
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
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "<$shell_call") or $an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0066", message_variables => { shell_call => $shell_call, error => $! }, code => 3, file => $THIS_FILE, line => __LINE__});
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => { 
			name1 => "line", value1 => $line 
		}, file => $THIS_FILE, line => __LINE__});
		$sql .= "$line\n";
	}
	close $file_handle;
	
	# Now we should be ready.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => { 
		name1 => "id",  value1 => $id, 
		name2 => "sql", value2 => $sql
	}, file => $THIS_FILE, line => __LINE__});
	
	# Now that I am ready, write!
	$an->DB->do_db_write({id => $id, query => $sql, source => $THIS_FILE, line => __LINE__});
	
	# Mark that we need to update the DB.
	$an->data->{scancore}{db_resync_needed} = 1;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "scancore::db_resync_needed", value1 => $an->data->{scancore}{db_resync_needed}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	return(0);
}

# This handles requesting, releasing and waiting on locks.
sub locking
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "locking" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $request     = defined $parameter->{request}     ? $parameter->{request}     : 0;
	my $release     = defined $parameter->{release}     ? $parameter->{release}     : 0;
	my $renew       = defined $parameter->{renew}       ? $parameter->{renew}       : 0;
	my $check       = defined $parameter->{check}       ? $parameter->{check}       : 0;
	my $source_name =         $parameter->{source_name} ? $parameter->{source_name} : $an->hostname;
	my $source_uuid =         $parameter->{source_uuid} ? $parameter->{source_uuid} : $an->data->{sys}{host_uuid};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
		name1 => "request",     value1 => $request, 
		name2 => "release",     value2 => $release, 
		name3 => "renew",       value3 => $renew, 
		name4 => "check",       value4 => $check, 
		name5 => "source_name", value5 => $source_name, 
		name6 => "source_uuid", value6 => $source_uuid, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $set            = 0;
	my $variable_name  = "lock_request";
	my $variable_value = $source_name."::".$source_uuid."::".time;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "variable_name",  value1 => $variable_name, 
		name2 => "variable_value", value2 => $variable_value, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Make sure we have a sane lock age
	if ((not $an->data->{scancore}{locking}{reap_age}) or ($an->data->{scancore}{locking}{reap_age} =~ /\D/))
	{
		$an->data->{scancore}{locking}{reap_age} = 300;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "scancore::locking::reap_age", value1 => $an->data->{scancore}{locking}{reap_age}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# If I have been asked to check, we will return the variable_uuid if a lock is set.
	if ($check)
	{
		my ($lock_value, $variable_uuid, $modified_date) = $an->ScanCore->read_variable({variable_name => $variable_name});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "lock_value",    value1 => $lock_value, 
			name2 => "variable_uuid", value2 => $variable_uuid, 
			name3 => "modified_date", value3 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		
		return($lock_value);
	}
	
	# If I've been asked to clear a lock, do so now.
	if ($release)
	{
		# We check to see if there is a lock before we clear it. This way we don't log that we 
		# released a lock unless we really released a lock.
		my ($lock_value, $variable_uuid, $modified_date) = $an->ScanCore->read_variable({variable_name => $variable_name});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "lock_value",    value1 => $lock_value, 
			name2 => "variable_uuid", value2 => $variable_uuid, 
			name3 => "modified_date", value3 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($lock_value)
		{
			my $variable_uuid = $an->ScanCore->insert_or_update_variables({
				variable_name     => $variable_name,
				variable_value    => "",
				update_value_only => 1,
			});
			$an->data->{sys}{local_lock_active} = 0;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "variable_uuid",          value1 => $variable_uuid, 
				name2 => "sys::local_lock_active", value2 => $an->data->{sys}{local_lock_active}, 
			}, file => $THIS_FILE, line => __LINE__});
			
			$an->Log->entry({log_level => 1, message_key => "tools_log_0040", message_variables => { host => $an->hostname }, file => $THIS_FILE, line => __LINE__});
		}
		return($set);
	}
	
	# If I've been asked to renew, do so now.
	if ($renew)
	{
		# Yup, do it.
		my $variable_uuid = $an->ScanCore->insert_or_update_variables({
			variable_name     => $variable_name,
			variable_value    => $variable_value,
			update_value_only => 1,
		});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "variable_uuid", value1 => $variable_uuid, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($variable_uuid)
		{
			$set = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "set", value1 => $set, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		$an->data->{sys}{local_lock_active} = time;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "variable_uuid",          value1 => $variable_uuid, 
			name2 => "sys::local_lock_active", value2 => $an->data->{sys}{local_lock_active}, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->Log->entry({log_level => 1, message_key => "tools_log_0039", message_variables => { host => $an->hostname }, file => $THIS_FILE, line => __LINE__});
		return($set);
	}
	
	# No matter what, we always check for, and then wait for, locks. Read in the locks, if any. If any 
	# are set and they are younger than scancore::locking::reap_age, we'll hold.
	my $waiting = 1;
	while ($waiting)
	{
		# Set the 'waiting' to '0'. If we find a lock, we'll set it back to '1'.
		$waiting = 0;
		
		# See if we had a lock.
		my ($lock_value, $variable_uuid, $modified_date) = $an->ScanCore->read_variable({variable_name => $variable_name});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "waiting",       value1 => $waiting, 
			name2 => "lock_value",    value2 => $lock_value, 
			name3 => "variable_uuid", value3 => $variable_uuid, 
			name4 => "modified_date", value4 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($lock_value =~ /^(.*?)::(.*?)::(\d+)/)
		{
			my $lock_source_name = $1;
			my $lock_source_uuid = $2;
			my $lock_time        = $3;
			my $current_time     = time;
			my $timeout_time     = $lock_time + $an->data->{scancore}{locking}{reap_age};
			my $lock_age         = $current_time - $lock_time;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
				name1 => "lock_source_name", value1 => $lock_source_name, 
				name2 => "lock_source_uuid", value2 => $lock_source_uuid, 
				name3 => "current_time",     value3 => $current_time, 
				name4 => "lock_time",        value4 => $lock_time, 
				name5 => "timeout_time",     value5 => $timeout_time, 
				name6 => "lock_age",         value6 => $lock_age, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# If the lock is stale, delete it.
			if ($current_time > $timeout_time)
			{
				# The lock is stale.
				my $variable_uuid = $an->ScanCore->insert_or_update_variables({
					variable_name     => $variable_name,
					variable_value    => "",
					update_value_only => 1,
				});
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "variable_uuid", value1 => $variable_uuid, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			# Only wait if this isn't our own lock.
			elsif ($lock_source_uuid ne $source_uuid)
			{
				# Mark 'wait', set inactive and sleep.
				$an->DB->mark_active({set => 0});
				
				$waiting = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "lock_source_uuid", value1 => $lock_source_uuid, 
					name2 => "source_uuid",      value2 => $source_uuid, 
					name3 => "waiting",          value3 => $waiting, 
				}, file => $THIS_FILE, line => __LINE__});
				sleep 5;
			}
		}
	}
	
	# If I am here, there are no pending locks. Have I been asked to set one?
	if ($request)
	{
		# Yup, do it.
		my $variable_uuid = $an->ScanCore->insert_or_update_variables({
			variable_name     => $variable_name,
			variable_value    => $variable_value,
			update_value_only => 1,
		});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "variable_uuid", value1 => $variable_uuid, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($variable_uuid)
		{
			$set = 1;
			$an->data->{sys}{local_lock_active} = time;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "set",                    value1 => $set, 
				name2 => "variable_uuid",          value2 => $variable_uuid, 
				name3 => "sys::local_lock_active", value3 => $an->data->{sys}{local_lock_active}, 
			}, file => $THIS_FILE, line => __LINE__});
			
			$an->Log->entry({log_level => 1, message_key => "tools_log_0038", message_variables => { host => $an->hostname }, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Now return.
	return($set);
}

# This sets or clears that the caller is about to work on the database
sub mark_active
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "mark_active" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $set = defined $parameter->{set} ? $parameter->{set} : 1;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "set",  value1 => $set, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If I haven't connected to a database yet, why am I here?
	if (not $an->data->{sys}{read_db_id})
	{
		return(0);
	}
	
	my $value = "false";
	if ($set)
	{
		$value = "true";
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "value",  value1 => $value, 
	}, file => $THIS_FILE, line => __LINE__});
	my $state_uuid = $an->ScanCore->insert_or_update_states({
		state_name      => "db_in_use",
		state_host_uuid => $an->data->{sys}{host_uuid},
		state_note      => $value,
	});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "state_uuid",  value1 => $state_uuid, 
	}, file => $THIS_FILE, line => __LINE__});
	
	return($state_uuid);
}

### WARNING: This is slow when processing thousands or records, each with many columns! Only call this when 
###          there is a reasonable expectation that the string will need to actually be processed!
# This prepares a string for writing to an archive file. It generates strings equivelant to the 'COPY ...' section in a 'pgdump'
sub prep_for_archive
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "prep_for_archive" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $string = defined $parameter->{string} ? $parameter->{string} : '\N';
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "string", value1 => $string, 
	}, file => $THIS_FILE, line => __LINE__});
	
	$string =~ s/\n/\\n/gs;
	$string =~ s/\t/\\t/gs;
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "string", value1 => $string, 
	}, file => $THIS_FILE, line => __LINE__});
	return($string);
}

# This sets the 'db_resync_in_progress' variable to be the timestamp that a db sync starts or '0' when a
# resync is finished.
sub set_update_db_flag
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "set_update_db_flag" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $set  = defined $parameter->{set}    ? $parameter->{set}    : 0;
	my $wait = defined $parameter->{'wait'} ? $parameter->{'wait'} : 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "set",  value1 => $set, 
		name2 => "wait", value2 => $wait, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $variable_uuid = $an->ScanCore->insert_or_update_variables({
		variable_name     => 'db_resync_in_progress',
		variable_value    => $set,
		update_value_only => 1,
	});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "variable_uuid", value1 => $variable_uuid, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If we've been asked to wait, wait. This is sometimes requested to give the other instances time to 
	# finish their scan runs before starting the actual update process.
	if (($wait) && ($wait =~ /^\d+$/))
	{
		$an->Log->entry({log_level => 1, message_key => "tools_log_0036", message_variables => { 'wait' => $wait }, file => $THIS_FILE, line => __LINE__});
		sleep $wait;
	}
	
	return(0);
}

# This simply updates the 'updated' table with the current time.
sub update_time
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "update_time" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
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
    updated_host_uuid = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{host_uuid})."
AND
    updated_by        = ".$an->data->{sys}{use_db_fh}->quote($file).";"; 

		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1  => "query", value1 => $query
		}, file => $THIS_FILE, line => __LINE__ });
		
		my $count = $an->DB->do_db_query({id => $id, query => $query, source => $THIS_FILE, line => __LINE__})->[0]->[0];	# (->[row]->[column])
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
    updated_host_uuid, 
    updated_by, 
    modified_date
) VALUES (
    ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{host_uuid}).", 
    ".$an->data->{sys}{use_db_fh}->quote($file).", 
    ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
);
";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1  => "query", value1 => $query
			}, file => $THIS_FILE, line => __LINE__ });
			$an->DB->do_db_write({id => $id, query => $query, source => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# It exists and the value has changed.
			my $query = "
UPDATE 
    updated 
SET
    modified_date     = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
WHERE 
    updated_by        = ".$an->data->{sys}{use_db_fh}->quote($file)." 
AND
    updated_host_uuid = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{host_uuid}).";
";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1  => "query", value1 => $query
			}, file => $THIS_FILE, line => __LINE__ });
			$an->DB->do_db_write({id => $id, query => $query, source => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

# This returns '1' if the host UUID is in 'hosts' and '0' if not.
sub verify_host_uuid
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "verify_host_uuid" }, file => $THIS_FILE, line => __LINE__});
	
	$an->Get->uuid({get => "host_uuid"});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "sys::host_uuid",  value1 => $an->data->{sys}{host_uuid}, 
		name2 => "path::host_uuid", value2 => $an->data->{path}{host_uuid}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $ok = 0;
	my $query = "
SELECT 
    host_name 
FROM 
    hosts 
WHERE
    host_uuid = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{host_uuid})."
;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query
	}, file => $THIS_FILE, line => __LINE__});
	
	# Do the query against the source DB and loop through the results.
	my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "results", value1 => $results
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $row (@{$results})
	{
		my $server_name = $row->[0];
		   $ok          = 1;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "server_name", value1 => $server_name, 
			name2 => "ok",          value2 => $ok, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This checks to see if 'db_resync_in_progress' is set and, if so, waits until it is cleared.
sub wait_if_db_is_updating
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "wait_if_db_is_updating" }, file => $THIS_FILE, line => __LINE__});
	
	my ($last_peer_state, $variable_uuid, $modified_date) = $an->ScanCore->read_variable({variable_name => 'db_resync_in_progress'});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "last_peer_state", value1 => $last_peer_state,
		name2 => "variable_uuid",   value2 => $variable_uuid, 
		name3 => "modified_date",   value3 => $modified_date, 
	}, file => $THIS_FILE, line => __LINE__});
	if (($last_peer_state) && ($last_peer_state =~ /^\d+$/))
	{
		# Wait.
		while ($last_peer_state)
		{
			$an->Log->entry({log_level => 1, message_key => "scancore_log_0092", file => $THIS_FILE, line => __LINE__});
			sleep 10;
			
			($last_peer_state, $variable_uuid, $modified_date) = $an->ScanCore->read_variable({variable_name => 'db_resync_in_progress'});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "last_peer_state", value1 => $last_peer_state,
				name2 => "variable_uuid",   value2 => $variable_uuid, 
				name3 => "modified_date",   value3 => $modified_date, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}


#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

1;
