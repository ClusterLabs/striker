package AN::Tools::Storage;
# 
# This module contains methods used to handle storage related tasks
# 

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Storage.pm";

### Methods;
# cleanup_gfs2
# find
# prep_uuid
# read_conf
# read_hosts
# read_ssh_config
# read_words
# read_xml_file
# rsync
# search_dirs
# _create_rsync_wrapper


#############################################################################################################
# House keeping methods                                                                                     #
#############################################################################################################

# The constructor
sub new
{
	#print "$THIS_FILE ".__LINE__."; In AN::Storage->new()\n";
	my $class = shift;
	my $self  = {
		CORE_WORDS	=>	"AN::tools.xml",
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

# This cleans up stale gfs2 lock files.
sub cleanup_gfs2
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target, 
		name2 => "port",   value2 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Make sure gfs2 isn't, in fact, running
	my $gfs2_running = 0;
	my $return       = [];
	my $shell_call   = $an->data->{path}{pgrep}." gfs2";
	if ($target)
	{
		# Remote call.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
	}
	else
	{
		# Local call
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			push @{$return}, $line;
		}
		close $file_handle;
	}
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Any return means that something is running and we DON'T want to remove the lock file.
		$gfs2_running = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "gfs2_running", value1 => $gfs2_running, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	if (not $gfs2_running)
	{
		# Remove the lock file.
		die "GFS2 lock file path appears to be invalid! Path is: [".$an->data->{path}{gfs2_lock}."], should be under '/var/lock/'.\n" if $an->data->{path}{gfs2_lock} !~ /^\/var\/lock/;
		my $return     = [];
		my $shell_call = $an->data->{path}{rm}." -f ".$an->data->{path}{gfs2_lock};
		if ($target)
		{
			# Remote call.
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "target",     value2 => $target,
			}, file => $THIS_FILE, line => __LINE__});
			(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$target,
				port		=>	$port, 
				password	=>	$password,
				ssh_fh		=>	"",
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
		}
		else
		{
			# Local call
			open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				push @{$return}, $line;
			}
			close $file_handle;
		}
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

### TODO: Add a function to create a list of searchable directories that starts with @INC so that a CSV of 
###       directories can be added to it after reading a config file. Make this method take an array 
###       reference to work on.
# This method searches the storage device for a give file or directory.
sub find
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	
	# Setup default values
	#print "$THIS_FILE ".__LINE__."; ENV{PWD}: [$ENV{PWD}]\n";
	my $file  = "";
	my $dirs  = $an->Storage->search_dirs;
	#print "$THIS_FILE ".__LINE__."; dirs: [$dirs]\n";
	#if (ref($dirs) eq "ARRAY") { foreach my $dir (@{$dirs}) { print "$THIS_FILE ".__LINE__."; - dir: [$dir]\n"; } }
	my $fatal = 0;
	push @{$dirs}, $ENV{PWD} if $ENV{PWD};
	
	$fatal = $parameter->{fatal} if $parameter->{fatal};
	$file  = $parameter->{file}  if $parameter->{file};
	$dirs  = $parameter->{dirs}  if $parameter->{dirs};
	#print "$THIS_FILE ".__LINE__."; file: [$file], dirs: [$dirs], fatal: [$fatal]\n";
	
	# This is the underlying operating system's directory delimiter as set by the parent method.
	my $delimiter = $an->_directory_delimiter;
	#print "$THIS_FILE ".__LINE__."; delimiter: [$delimiter]\n";
	if ($file =~ /::/)
	{
		$file =~ s/::/$delimiter/g;
		#print "$THIS_FILE ".__LINE__."; file: [$file]\n";
	}
	
	# Each full path and file name will be stored here before the test.
	my $full_file = "";
	foreach my $dir (@{$dirs})
	{
		# If "dir" is ".", expand it.
		$dir =  $ENV{PWD} if (($dir eq ".") && ($ENV{PWD}));
		#print "$THIS_FILE ".__LINE__."; dir: [$dir], delimiter: [$delimiter], file: [$file]\n";
		
		# Put together the initial path
		$full_file =  $dir.$delimiter.$file;
		#print "$THIS_FILE ".__LINE__."; full file: [$full_file]\n";

		# Convert double-colons to the OS' directory delimiter
		$full_file =~ s/::/$delimiter/g;
		#print "$THIS_FILE ".__LINE__."; full file: [$full_file]\n";

		# Clear double-delimiters.
		$full_file =~ s/$delimiter$delimiter/$delimiter/g;
		#print "$THIS_FILE ".__LINE__."; full file: [$full_file]\n";
		
		#print "$THIS_FILE ".__LINE__."; Searching for: [$full_file] ([$dir] / [$file])\n";
		if (-f $full_file)
		{
			# Found it, return.
			#print "$THIS_FILE ".__LINE__."; Found it!\n";
			return ($full_file);
		}
	}
	
	if ($fatal)
	{
		print "$THIS_FILE ".__LINE__."; Failed to find: [$file]\n";
		$an->Alert->error({title_key => "error_title_0002", message_key => "error_message_0002", message_variables => { file => $file }, code => 44, file => $THIS_FILE, line => __LINE__});
	}
	
	# If I am here, I failed but fatal errors are disabled.
	return (0);
}

# Get (create if needed) my UUID.
sub prep_uuid
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Did the user give us a UUID to use?
	my $host_uuid = $parameter->{host_uuid} ? $parameter->{host_uuid} : "";
	my $target    = $parameter->{target}    ? $parameter->{target}    : "";
	my $port      = $parameter->{port}      ? $parameter->{port}      : "";
	my $password  = $parameter->{password}  ? $parameter->{password}  : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "host_uuid", value1 => $host_uuid, 
		name2 => "target",    value2 => $target, 
		name3 => "port",      value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### NOTE: We don't call ->uuid() above to help debug passed-in values.
	# If I wasn't passed in a UUID, set one now.
	if (not $host_uuid)
	{
		$host_uuid = $an->Get->uuid();
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "host_uuid", value1 => $host_uuid, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# The shell call needs to work locally and remotely, so we can't use perl built-in file tests (well,
	# we could, but then we'd have two ways to do the same job).
	my ($directory, $file) = ($an->data->{path}{host_uuid} =~ /^(.*)\/(.*)/);
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "directory", value1 => $directory, 
		name2 => "file",      value2 => $file, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $set_sys_host_uuid = 1;
	my $return            = [];
	my $shell_call        = "
if [ ! -e '$directory' ];
then
    ".$an->data->{path}{echo}." creating $directory
    ".$an->data->{path}{'mkdir'}." $directory
    ".$an->data->{path}{'chmod'}." 755 $directory
fi
if [ ! -e '".$an->data->{path}{host_uuid}."' ];
then
    ".$an->data->{path}{echo}." generating ".$an->data->{path}{host_uuid}."
    ".$an->data->{path}{echo}." $host_uuid > ".$an->data->{path}{host_uuid}."
fi
UUID=\$(".$an->data->{path}{cat}." ".$an->data->{path}{host_uuid}.")
".$an->data->{path}{echo}." host_uuid:\$UUID
";
	if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
	{
		### Remote call
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port,
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		$set_sys_host_uuid = 0;
	}
	else
	{
		### Local call
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$return}, $line;
		}
		close $file_handle;
	}
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^host_uuid:(.*)$/)
		{
			$host_uuid = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "host_uuid", value1 => $host_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Verify I have a good UUID.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "host_uuid", value1 => $host_uuid, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($host_uuid !~ /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/)
	{
		# derp
		$an->Log->entry({log_level => 0, message_key => "error_message_0061", file => $THIS_FILE, line => __LINE__});
		
		### TODO: Make this exit 69?
		$an->nice_exit({exit_code => 7});
	}
	
	# Set the system host_uuid if this is local
	if ($set_sys_host_uuid)
	{
		$an->data->{sys}{host_uuid} = $host_uuid;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::host_uuid", value1 => $an->data->{sys}{host_uuid}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "host_uuid", value1 => $host_uuid, 
	}, file => $THIS_FILE, line => __LINE__});
	return($host_uuid);
}

# This reads in a configuration file and stores it in either the passed hash reference else in $an->data else
# in a new anonymous hash.
sub read_conf
{
	my $self  = shift;
	my $parameter = shift;
	
	# This just makes the code more consistent.
	my $an    = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# This is/was for testing.
	if (0)
	{
		foreach my $key (sort {$a cmp $b} keys %ENV) { print "ENV key: [$key]\t=\t[$ENV{$key}]\n"; }
		foreach my $key (sort {$a cmp $b} keys %INC) { print "INC key: [$key]\t=\t[$INC{$key}]\n"; }
		$an->nice_exit({exit_code => 0});
	}
	
	my $file  = $parameter->{file}  ? $parameter->{file}  : "";
	my $hash  = $parameter->{hash}  ? $parameter->{hash}  : $an->data;
	my $debug = $parameter->{debug} ? $parameter->{debug} : 0;
	
	# Make sure I have a sane file name.
	if ($file)
	{
		# Find it relative to the AN::Tools root directory.
		if ($file =~ /^AN::Tools/)
		{
			my $dir  =  $INC{'AN/Tools.pm'};
			   $dir  =~ s/Tools.pm//;
			   $file =~ s/AN::Tools\//$dir/;
			   $file =~ s/\/\//\//g;
		}
		
		# I have a file. Is it relative to the install dir or fully qualified?
		if (($file =~ /^\.\//) or ($file !~ /^\//))
		{
			# It is in or relative to this directory.
			if ($ENV{PWD})
			{
				# Can expand using the environment variable.
				$file =~ s/^\./$ENV{PWD}/;
			}
			else
			{
				# No environmnet variable, search the array of directories.
				$file = $an->Storage->find({fatal=>1, file=>$file});
			}
		}
	}
	else
	{
		# No file at all...
		die "$THIS_FILE ".__LINE__."; [ Error ] - No file was passed in to read.\n";
	}
	
	# Now that I have a file, read it.
	$an->_load_io_handle() if not $an->_io_handle_loaded();
	my $read = IO::Handle->new();
	
	if ($debug)
	{
		print "Content-type: text/html; charset=utf-8\n\n";
		print "<pre>\n";
	}
	
	# Is it too early to use "$an->error"?
	my $short_hostname = $an->short_hostname;
	my $hostname       = $an->hostname;
	open ($read, "<$file") or die "Can't read: [$file], error was: $!\n";
	while (<$read>)
	{
		chomp;
		my $line =  $_;
		   $line =~ s/^\s+//;
		   $line =~ s/\s+$//;
		next if ((not $line) or ($line =~ /^#/));
		next if $line !~ /=/;
		my ($variable, $value) = split/=/, $line, 2;
		$variable =~ s/\s+$//;
		$value    =~ s/^\s+//;
		next if not $variable;
		
		if ($debug)
		{
			print "$variable = $value\n";
		}
		
		# If the variable has '#!hostname!#' or '#!short_hostname!#', convert it now.
		$value =~ s/#!hostname!#/$hostname/g;
		$value =~ s/#!short_hostname!#/$short_hostname/g;
		
		$an->_make_hash_reference($hash, $variable, $value);
	}
	$read->close();
	if ($debug)
	{
		print "</pre>\n";
		die "$THIS_FILE ".__LINE__."; testing...\n";
	}
	
	### TODO: Make this a more intelligent method that can go a variable number of sub-keys deep and does
	###       a search/replace of variables based on a given key match.
	# Some keys store directories. Below, I convert the ones I know about to the current operating 
	# system's directory delimiter where '::' is found.
	my $directory_delimiter = $an->_directory_delimiter();
	foreach my $key (keys %{$an->data->{dir}})
	{
		if (not ref($an->data->{dir}{$key}))
		{
			$an->data->{dir}{$key} =~ s/::/$directory_delimiter/g;
		}
	}
	
	return ($hash);
}

# This reads in the /etc/hosts file.
sub read_hosts
{
	my $self      = shift;
	my $parameter = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	$an->Log->entry({log_level => 3, message_key => "notice_message_0003", message_variables => {
		file => $an->data->{path}{etc_hosts}, 
	}, file => $THIS_FILE, line => __LINE__});
	my $hash = ref($parameter->{hash}) eq "HASH" ? $parameter->{hash} : $an->data;
	
	# This will hold the raw contents of the file.
	$hash->{raw}{etc_hosts} = "";
	
	# Now read in the file
	my $shell_call = $an->data->{path}{etc_hosts};
	open (my $file_handle, "<$shell_call") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0016", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
	while (<$file_handle>)
	{
		chomp;
		my $line                   =  $_;
		   $hash->{raw}{etc_hosts} .= "$line\n";
		   $line                   =~ s/^\s+//;
		   $line                   =~ s/#.*$//;
		   $line                   =~ s/\s+$//;
		next if not $line;
		
		my $this_ip     = "";
		my $these_hosts = "";
		### NOTE: We don't support IPv6 yet
		if ($line =~ /^(\d+\.\d+\.\d+\.\d+)\s+(.*)/)
		{
			$this_ip     = $1;
			$these_hosts = $2;
			foreach my $this_host (split/ /, $these_hosts)
			{
				$hash->{hosts}{$this_host}{ip} = $this_ip;
				if (not exists $hash->{hosts}{by_ip}{$this_ip})
				{
					$hash->{hosts}{by_ip}{$this_ip} = [];
				}
				push @{$hash->{hosts}{by_ip}{$this_ip}}, $this_host;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "this_host", value1 => $this_host, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	close $file_handle;
	
	# Debug
	foreach my $this_ip (sort {$a cmp $b} keys %{$hash->{hosts}{by_ip}})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "this_ip", value1 => $this_ip, 
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $this_host (sort {$a cmp $b} @{$hash->{hosts}{by_ip}{$this_ip}})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "this_host", value1 => $this_host, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

# This reads /etc/ssh/ssh_config and later will try to match host names to port forwards.
sub read_ssh_config
{
	my $self      = shift;
	my $parameter = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	$an->Log->entry({log_level => 3, message_key => "notice_message_0003", message_variables => {
		file	=>	$an->data->{path}{ssh_config}, 
	}, file => $THIS_FILE, line => __LINE__});
	my $hash = ref($parameter->{hash}) eq "HASH" ? $parameter->{hash} : $an->data;
	
	# This will hold the raw contents of the file.
	$hash->{raw}{ssh_config} = "";
	
	# Now read in the file
	my $this_host  = "";
	my $shell_call = $an->data->{path}{ssh_config};
	open (my $file_handle, "<$shell_call") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0016", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
	while (<$file_handle>)
	{
		chomp;
		my $line                    =  $_;
		   $hash->{raw}{ssh_config} .= "$line\n";
		   $line                    =~ s/#.*$//;
		   $line                    =~ s/\s+$//;
		next if not $line;
		
		if ($line =~ /^host (.*)/i)
		{
			$this_host = $1;
			next;
		}
		next if not $this_host;
		if ($line =~ /port (\d+)/i)
		{
			my $port = $1;
			$hash->{hosts}{$this_host}{port} = $port;
		}
	}
	close $file_handle;
	
	return($hash);
}

# This takes the path/name of an XML file containing AN::Tools type words and reads them into a hash 
# reference.
sub read_words
{
	my $self      = shift;
	my $parameter = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# Setup my variables.
	my $file = $parameter->{file} ? $parameter->{file} : $an->Storage->find({file => $self->{CORE_WORDS}, fatal => 1});
	my $hash = $parameter->{hash} ? $parameter->{hash} : $an->data;
	
	# Make sure that the 'file' exists and is readable.
	#print "$THIS_FILE ".__LINE__."; words file: [$file]\n";
	if (not -e $file)
	{
		$an->Alert->error({title_key => "error_title_0006", message_key => "error_message_0009", message_variables => { file => $file }, code => 11, file => $THIS_FILE, line => __LINE__});
		return (undef);
	}
	if (not -r $file)
	{
		$an->Alert->error({title_key => "error_title_0007", message_key => "error_message_0010", message_variables => { file => $file }, code => 12, file => $THIS_FILE, line => __LINE__});
		return (undef);
	}
	
	my $in_comment  = 0;	# Set to '1' when in a comment stanza that spans more than one line.
	my $in_data     = 0;	# Set to '1' when reading data that spans more than one line.
	my $closing_key = "";	# While in_data, look for this key to know when we're done.
	my $xml_version = "";	# The XML version of the words file.
	my $encoding    = "";	# The encoding used in the words file. Should only be UTF-8.
	my $data        = "";	# The data being read for the given key.
	my $key_name    = "";	# This is a double-colon list of hash keys used to build each hash element.
	
	# Load IO::Handle if needed.
	$an->_load_io_handle() if not $an->_io_handle_loaded();
	
	### TODO: Replace this with XMLin
	# Read in the XML file with the word strings to load.
	my $read       = IO::Handle->new;
	my $shell_call = "<$file";
	open ($read, $shell_call) or $an->Alert->error({title_key => "error_title_0008", message_key => "error_message_0011", message_variables => { file => $file, error => $! }, code => 28, file => $THIS_FILE, line => __LINE__});
	
	# If I have been asked to read in UTF-8 mode, do so.
	if ($an->String->force_utf8)
	{
		binmode $read, "encoding(utf8)";
	}
	
	# Now loop through the XML file, line by line.
	while (<$read>)
	{
		chomp;
		my $line = $_;
		
		### Deal with comments.
		# Look for a clozing stanza if I am (still) in a comment.
		if (($in_comment) && ( $line =~ /-->/ ))
		{
			$line       =~ s/^(.*?)-->//;
			$in_comment =  0;
		}
		next if ($in_comment);
		
		# Strip out in-line comments.
		while ( $line =~ /<!--(.*?)-->/ )
		{
			$line =~ s/<!--(.*?)-->//;
		}
		
		# See if there is an comment opening stanza.
		if ( $line =~ /<!--/ )
		{
			$in_comment =  1;
			$line       =~ s/<!--(.*)$//;
		}
		### Comments dealt with.
		
		### Parse data
		# XML data
		if ($line =~ /<\?xml version="(.*?)" encoding="(.*?)"\?>/)
		{
			$xml_version = $1;
			$encoding    = $2;
			next;
		}
		
		# If I am not "in_data" (looking for more data for a currently in use key).
		if (not $in_data)
		{
			# Skip blank lines.
			next if $line =~ /^\s+$/;
			next if $line eq "";
			$line =~ s/^\s+//;
			
			# Look for an inline data-structure.
			if (($line =~ /<(.*?) (.*?)>/) && ($line =~ /<\/$1>/))
			{
				# First, look for CDATA.
				my $cdata = "";
				if ($line =~ /<!\[CDATA\[(.*?)\]\]>/)
				{
					$cdata =  $1;
					$line  =~ s/<!\[CDATA\[$cdata\]\]>/$cdata/;
				}
				
				# Pull out the key and name.
				my ($key) = ($line =~ /^<(.*?) /);
				my ($name, $data) = ($line =~ /^<$key name="(.*?)">(.*?)<\/$key>/);
				$data = $cdata if $cdata;
				
				# If I picked up data within a CDATA block, push it into 'data' proper.
				$data = $cdata if $cdata;
				
				# No break out the data and push it into the corresponding keyed hash 
				# reference '$hash'.
				$an->_make_hash_reference($hash, "${key_name}::${key}::${name}::content", $data);
				
				next;
			}
			
			# Look for a self-contained unkeyed structure.
			if (($line =~ /<(.*?)>/) && ($line =~ /<\/$1>/))
			{
				my $key  =  $line;
				   $key  =~ s/<(.*?)>.*/$1/;
				   $data =  $line;
				   $data =~ s/<$key>(.*?)<\/$key>/$1/;
				$an->_make_hash_reference($hash, "${key_name}::${key}", $data);
				next;
			}
			
			# Look for a line with a closing stanza.
			if ($line =~ /<\/(.*?)>/)
			{
				my $closing_key =  $line;
				   $closing_key =~ s/<\/(\w+)>/$1/;
				   $key_name    =~ s/(.*?)::$closing_key(.*)/$1/;
				next;
			}
			
			# Look for a key with an embedded value.
			if ($line =~ /^<(\w+) name="(.*?)" (\w+)="(.*?)">/)
			{
				my $key      =  $1;
				my $name     =  $2;
				my $key2     =  $3;
				my $data     =  $4;
				   $key_name .= "::${key}::${name}";
				$an->_make_hash_reference($hash, "${key_name}::${key}::${key2}", $data);
				next;
			}
			
			# Look for a contained value.
			if ($line =~ /^<(\w+) name="(.*?)">(.*)/)
			{
				my $key  = $1;
				my $name = $2;
				# Don't scope 'data' locally in case it spans multiple lines.
				   $data = $3;
				
				# Parse the data now.
				if ($data =~ /<\/$key>/)
				{
					# Fully contained data.
					$data =~ s/<\/$key>(.*)$//;
					$an->_make_hash_reference($hash, "${key_name}::${key}::${name}", $data);
				}
				else
				{
					# Element closes later.
					$in_data     =  1;
					$closing_key =  $key;
					$name        =~ s/^<$key name="(\w+).*/$1/;
					$key_name    .= "::${key}::${name}";
					$data        =~ s/^<$key name="$name">(.*)/$1/;
					$data        .= "\n";
				}
				next;
			}
			
			# Look for an opening data structure.
			if ($line =~ /<(.*?)>/)
			{
				my $key      =  $1;
				   $key_name .= "::$key";
				next;
			}
		}
		else
		{
			### I'm in a multi-line data block.
			# If this line doesn't close the data block, feed it wholesale into 'data'. If it 
			# does, see how much of this line, if anything, is pushed into 'data'.
			if ($line !~ /<\/$closing_key>/)
			{
				$data .= "$line\n";
			}
			else
			{
				# This line closes the data block.
				$in_data =  0;
				$line    =~ s/(.*?)<\/$closing_key>/$1/;
				$data    .= "$line";
				
				# If this line contain new-line control characters, break the line up into 
				# multiple lines and process them seperately.
				my $save_data = "";
				my @lines     = split/\n/, $data;
				
				# I use this to track CDATA blocks.
				my $in_cdata  = 0;
				
				# Loop time.
				foreach my $line (@lines)
				{
					# If I am in a CDATA block, check for the closing stanza.
					if (($in_cdata == 1) && ($line =~ /]]>$/))
					{
						# CDATA closes here.
						$line      =~ s/]]>$//;
						$save_data .= "\n$line";
						$in_cdata  =  0;
					}
					
					# If this line is a self-contained CDATA block, pull the data out.
					# Otherwise, check if this line starts a CDATA block.
					if (($line =~ /^<\!\[CDATA\[/) && ($line =~ /]]>$/))
					{
						# CDATA opens and closes in this line.
						$line      =~ s/^<\!\[CDATA\[//;
						$line      =~ s/]]>$//;
						$save_data .= "\n$line";
					}
					elsif ($line =~ /^<\!\[CDATA\[/)
					{
						$line     =~ s/^<\!\[CDATA\[//;
						$in_cdata =  1;
					}
					
					# If I am in a CDATA block, feed the (sub)line into 'save_data' 
					# wholesale.
					if ($in_cdata == 1)
					{
						# Don't analyze, just store.
						$save_data .= "\n$line";
					}
					else
					{
						# Not in CDATA, look for XML data.
						while (($line =~ /<(.*?)>/) && ($line =~ /<\/$1>/))
						{
							# Found a value.
							my $key =  $line;
							$key    =~ s/.*?<(.*?)>.*/$1/;
							$data   =  $line;
							$data   =~ s/.*?<$key>(.*?)<\/$key>/$1/;
							
							$an->_make_hash_reference($hash, "${key_name}::${key}", $data);
							$line =~ s/<$key>(.*?)<\/$key>//
						}
						$save_data .= "\n$line";
					}
				}
				
				# Knock out and new-lines and save.
				$save_data=~s/^\n//;
				if ($save_data =~ /\S/s)
				{
					# Record the data in my '$hash' hash
					# reference.
					$an->_make_hash_reference($hash, "${key_name}::content", $save_data);
				}
				
				$key_name =~ s/(.*?)::$closing_key(.*)/$1/;
			}
		}
		next if $line eq "";
	}
	close $read;
	
	# Set a couple values about this file.
	$self->{FILE}->{XML_VERSION} = $xml_version;
	$self->{FILE}->{ENCODING}    = $encoding;
	
	# Return the number.
	return (1);
}

# This reads an XML file into the requested hash reference.
sub read_xml_file
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# If the user didn't give us a file name to read, exit.
	my $file = $parameter->{file} if $parameter->{file};
	my $hash = $parameter->{hash} ?  $parameter->{hash} : "";
	
	if ($file)
	{
		# Can I read it?
		if (not -e $file)
		{
			# Nope :(
			$an->Alert->error({title_key => "error_title_0023", message_key => "error_message_0042", message_variables => { file => $file }, code => 39, file => $THIS_FILE, line => __LINE__});
			
			# Return nothing in case the user is blocking fatal errors.
			return (undef);
		}
	}
	else
	{
		# What file?
		$an->Alert->error({title_key => "error_title_0023", message_key => "error_message_0043", code => 40, file => $THIS_FILE, line => __LINE__});
		
		# Return nothing in case the user is blocking fatal errors.
		return (undef);
	}
	
	if (not $hash)
	{
		# Use the file name.
		$hash              = {};
		$an->data->{$file} = $hash;
	}
	elsif (ref($hash) ne "HASH")
	{
		# The user passed ... something.
		$an->Alert->error({title_key => "error_title_0024", message_key => "error_message_0044", message_variables => { hash => $hash }, code => 41, file => $THIS_FILE, line => __LINE__});
		return (undef);
	}
	
	# Still alive? Good!
	my $xml          = XML::Simple->new();
	my $data         = $xml->XMLin($file, ForceArray => 1);
	   $hash->{data} = $data;
	
	return($hash);
}

# This creates an 'expect' wrapper and then calls rsync to copy data between this machine and a remote 
# system.
sub rsync
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	
	# Check my parameters.
	my $node        = $parameter->{node}        ? $parameter->{node}        : "";	# TODO: What was this for? Can I remove it?
	my $target      = $parameter->{target}      ? $parameter->{target}      : "";
	my $port        = $parameter->{port}        ? $parameter->{port}        : "";
	my $password    = $parameter->{password}    ? $parameter->{password}    : "";
	my $source      = $parameter->{source}      ? $parameter->{source}      : "";
	my $destination = $parameter->{destination} ? $parameter->{destination} : "";
	my $switches    = $parameter->{switches}    ? $parameter->{switches}    : "-av";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "node",        value1 => $node, 
		name2 => "target",      value2 => $target, 
		name3 => "port",        value3 => $port, 
		name4 => "source",      value4 => $source, 
		name5 => "destination", value5 => $destination, 
		name6 => "switches",    value6 => $switches, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Add an argument for the port if set
	if (($port) && ($port ne "22"))
	{
		$switches .= " -e 'ssh -p $port'";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "switches", value1 => $switches, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Make sure I have everything I need.
	my $failed = 0;
	if (not $source)
	{
		# No source
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0037", code => 27, file => $THIS_FILE, line => __LINE__});
		$failed = 1;
	}
	if (not $destination)
	{
		# No destination
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0038", code => 32, file => $THIS_FILE, line => __LINE__});
		$failed = 1;
	}
	
	# If either the source or destination is remote, we need to make sure we have the remote machine in
	# the current user's ~/.ssh/known_hosts file.
	my $remote_user    = "";
	my $remote_machine = "";
	if ($source =~ /^(.*?)@(.*?):/)
	{
		$remote_user    = $1;
		$remote_machine = $2;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "remote_user",    value1 => $remote_user, 
			name2 => "remote_machine", value2 => $remote_machine, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($destination =~ /^(.*?)@(.*?):/)
	{
		$remote_user    = $1;
		$remote_machine = $2;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "remote_user",    value1 => $remote_user, 
			name2 => "remote_machine", value2 => $remote_machine, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	if ($remote_machine)
	{
		# Make sure we know the fingerprint of the remote machine
		$an->Log->entry({log_level => 2, message_key => "log_0035", message_variables => { target => $remote_machine }, file => $THIS_FILE, line => __LINE__});
		$an->Remote->add_target_to_known_hosts({target => $remote_machine});
		
		# Make sure we have a target and password for the remote machine.
		if (not $target)
		{
			# No target, set the 'remote_machine' as the target.
			$target = $remote_machine;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "target", value1 => $target, 
			}, file => $THIS_FILE, line => __LINE__});
			#$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0035", code => 22, file => $THIS_FILE, line => __LINE__});
			$failed = 1;
		}
		# TODO: Make sure this works with passwordless SSH
		if (not $password)
		{
			# No password
			$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0036", code => 23, file => $THIS_FILE, line => __LINE__});
			$failed = 1;
		}
	}
	
	# If local, call rsync directly. If remote, setup the rsync wrapper
	my $shell_call = $an->data->{path}{rsync}." $switches $source $destination";
	if ($remote_machine)
	{
		# Remote target, wrapper needed.
		my $wrapper = $an->Storage->_create_rsync_wrapper({
			target   => $target,
			password => $password, 
		});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "wrapper", value1 => $wrapper, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# And make the shell call
		$shell_call = "$wrapper $switches $source $destination";
	}
	# Now make the call
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
	while(<$file_handle>)
	{
		# There should never be any output, but just in case...
		chomp;
		my $line = $_;
		   $line =~ s/\r//g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	close $file_handle;
	
	return($failed);
}

# This method returns an array reference of directories to search within for files and directories.
sub search_dirs
{
	my $self  = shift;
	my $array = shift;
	
	# This just makes the code more consistent.
	my $an    = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# Set a default if nothing was passed.
	$array = $an->_defaut_search_dirs() if not $array;
	
	# If the array is a CSV of directories, convert it now.
	if ($array =~ /,/)
	{
		# CSV, convert to an array.
		my @new_array = split/,/, $array;
		$array        = \@new_array;
	}
	elsif (ref($array) ne "ARRAY")
	{
		# Unless changed, this should return a reference to the @INC
		# array.
		if ($array)
		{
			# Something non-sensical was passed.
			$an->Alert->error({title_key => "error_title_0003", message_key => "error_message_0003", message_variables => { array => $array }, code => 45, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# MADI: Delete before release.
	if (0)
	{
		print "Returning an array containing:\n";
		foreach my $dir (@{$array}) { print "\t- [$dir]\n"; }
	}
	
	return ($array);
}


#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

# This does the actual work of creating the 'expect' wrapper script and returns the path to that wrapper.
sub _create_rsync_wrapper
{
	my $self      = shift;
	my $parameter = shift;
	
	# Clear any prior errors.
	my $an    = $self->parent;
	$an->Alert->_set_error;
	
	# Check my parameters.
	my $target   = $parameter->{target};
	my $password = $parameter->{password};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",   value1 => $target, 
		name2 => "password", value2 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $target) or (not $password))
	{
		# Can't do much without a target or password.
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0034", code => 21, file => $THIS_FILE, line => __LINE__});
	}
	
	my $wrapper    = "/tmp/rsync.$target";
	my $shell_call = "
".$an->data->{path}{echo}." '#!".$an->data->{path}{expect}."' > $wrapper
".$an->data->{path}{echo}." 'set timeout 3600' >> $wrapper
".$an->data->{path}{echo}." 'eval spawn rsync \$argv' >> $wrapper
".$an->data->{path}{echo}." 'expect \"password:\" \{ send \"$password\\n\" \}' >> $wrapper
".$an->data->{path}{echo}." 'expect eof' >> $wrapper
".$an->data->{path}{'chmod'}." 755 $wrapper;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		print $_;
	}
	close $file_handle;
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "wrapper", value1 => $wrapper, 
	}, file => $THIS_FILE, line => __LINE__});
	return($wrapper);
}

1;
