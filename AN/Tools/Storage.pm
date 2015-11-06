package AN::Tools::Storage;

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Storage.pm";

# The constructor
sub new
{
	#print "$THIS_FILE ".__LINE__."; In AN::Storage->new()\n";
	my $class = shift;
	my $self  = {};
	
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

# Get (create if needed) my UUID.
sub prep_local_uuid
{
	my $self  = shift;
	my $parameter = shift;
	
	# Clear any prior errors.
	my $an    = $self->parent;
	$an->Alert->_set_error;
	
	# Does it exist?
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "path::host_uuid", value1 => $an->data->{path}{host_uuid}, 
	}, file => $THIS_FILE, line => __LINE__});
	if (not -e $an->data->{path}{host_uuid})
	{
		# Nope. What about the parent directory? Split the path from 
		# the file name.
		my ($directory, $file) = ($an->data->{path}{host_uuid} =~ /^(.*)\/(.*)/);
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "directory", value1 => $directory, 
			name2 => "file",      value2 => $file, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Check the directory now
		if (not -e $directory)
		{
			# The directory needs to be created.
			mkdir $directory or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0019", message_variables => {
				directory => $directory, 
				error     => $! 
			}, code => 2, file => "$THIS_FILE", line => __LINE__});
			
			# Set the mode
			my $directory_mode = 0775;
			$an->Log->entry({log_level => 2, message_key => "scancore_log_0046", message_variables => {
				directory_mode => sprintf("%04o", $directory_mode), 
			}, file => $THIS_FILE, line => __LINE__});
			chmod $directory_mode, $an->data->{path}{email_directory};
		}
		
		### I don't use AN::Get->uuid() because I need to write to the file anyway, so I can do both
		### in one step.
		# Now create the UUID.
		my $shell_call = $an->data->{path}{uuidgen}." > ".$an->data->{path}{host_uuid};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			# There should never be any output, but just in case...
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		close $file_handle;
	}
	
	# Now read in the UUID.
	$an->Get->uuid({get => 'host_uuid'});
	
	# Verify I have a good UUID.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::host_uuid", value1 => $an->data->{sys}{host_uuid}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{host_uuid} !~ /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/)
	{
		# derp
		$an->Log->entry({log_level => 0, message_key => "scancore_error_0017", file => $THIS_FILE, line => __LINE__});
		exit(7);
	}
	
	return($an->data->{sys}{host_uuid});
}

### TODO: Add a function to create a list of searchable directories that starts with @INC so that a CSV of 
###       directories can be added to it after reading a config file. Make this method take an array 
###       reference to work on.
# This method searches the storage device for a give file or directory.
sub find
{
	my $self      = shift;
	my $parameter = shift;
	
	# Clear any prior errors.
	my $an    = $self->parent;
	$an->Alert->_set_error;
	
	# Setup default values
	#print "$THIS_FILE ".__LINE__."; ENV{PWD}: [$ENV{PWD}]<br />\n";
	my $file  = "";
	my $dirs  = $an->Storage->search_dirs;
	#print "$THIS_FILE ".__LINE__."; dirs: [$dirs]<br />\n";
	#if (ref($dirs) eq "ARRAY") { foreach my $dir (@{$dirs}) { print "$THIS_FILE ".__LINE__."; - dir: [$dir]<br />\n"; } }
	my $fatal = 0;
	push @{$dirs}, $ENV{PWD} if $ENV{PWD};
	
	# See if I am getting parameters is a hash reference or directly as
	# element arrays.
	if (ref($parameter))
	{
		# Called via a hash ref, good.
		$fatal = $parameter->{fatal} if $parameter->{fatal};
		$file  = $parameter->{file}  if $parameter->{file};
		$dirs  = $parameter->{dirs}  if $parameter->{dirs};
	}
	else
	{
		# Called directly.
		$file  = $parameter;
		# I don't want to overwrite the defaults if undef or a blank
		# value was passed.
		$dirs  = $_[0] if $_[0];
		$fatal = $_[1] if $_[1];
	}
	#print "$THIS_FILE ".__LINE__."; file: [$file], dirs: [$dirs], fatal: [$fatal]<br />\n";
	
	# This is the underlying operating system's directory delimiter as set
	# by the parent method.
	my $delimiter = $an->_directory_delimiter;
# 	if ($file =~ /::/)
# 	{
# 		$file =~ s/::/$delimiter/g;
# 		print "$THIS_FILE ".__LINE__."; file: [$file]<br />\n";
# 	}
	
	# Each full path and file name will be stored here before the test.
	my $full_file = "";
	foreach my $dir (@{$dirs})
	{
		# If "dir" is ".", expand it.
		$dir       =  $ENV{PWD} if (($dir eq ".") && ($ENV{PWD}));
		#print "$THIS_FILE ".__LINE__."; dir: [$dir], delimiter: [$delimiter], file: [$file]<br />\n";
		
		# Put together the initial path
		$full_file =  $dir.$delimiter.$file;
		#print "$THIS_FILE ".__LINE__."; full file: [$full_file]<br />\n";

		# Convert double-colons to the OS' directory delimiter
		$full_file =~ s/::/$delimiter/g;
		#print "$THIS_FILE ".__LINE__."; full file: [$full_file]<br />\n";

		# Clear double-delimiters.
		$full_file =~ s/$delimiter$delimiter/$delimiter/g;
		#print "$THIS_FILE ".__LINE__."; full file: [$full_file]<br />\n";
		
		#print "$THIS_FILE ".__LINE__."; Searching for: [$full_file] ([$dir] / [$file])<br />\n";
		if (-f $full_file)
		{
			# Found it, return.
			#print "$THIS_FILE ".__LINE__."; Found it!<br />\n";
			return ($full_file);
		}
	}
	
	if ($fatal)
	{
		$an->Alert->error({
			fatal			=>	1,
			title_key		=>	"error_title_0002",
			message_key		=>	"error_message_0002",
			message_variables	=>	{
				file			=>	$file,
			},
			code			=>	44,
			file			=>	"$THIS_FILE",
			line			=>	__LINE__
		});
	}
	
	# If I am here, I failed but fatal errors are disabled.
	return (0);
}

# This reads in a configuration file and stores it in either the passed hash
# reference else in $an->data else in a new anonymous hash.
sub read_conf
{
	my $self  = shift;
	my $parameter = shift;
	
	# This just makes the code more consistent.
	my $an    = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	my $file;
	my $hash = $an->data;
	
	# This is/was for testing.
	if (0)
	{
		foreach my $key (sort {$a cmp $b} keys %ENV) { print "ENV key: [$key]\t=\t[$ENV{$key}]\n"; }
		foreach my $key (sort {$a cmp $b} keys %INC) { print "INC key: [$key]\t=\t[$INC{$key}]\n"; }
		exit;
	}
	
	# Now see if the user passed the values in a hash reference or directly.
	if (ref($parameter) eq "HASH")
	{
		# Values passed in a hash, good.
		$file = $parameter->{file} if $parameter->{file};
		$hash = $parameter->{hash} if $parameter->{hash};
	}
	else
	{
		# Values passed directly.
		$file = $parameter;
		$hash = $_[0] if defined $_[0];
	}
	
	# Make sure I have a sane file name.
	if ($file)
	{
		# Find it relative to the AN::Tools root directory.
		if ($file =~ /^AN::Tools/)
		{
			my $dir =  $INC{'AN/Tools.pm'};
			$dir    =~ s/Tools.pm//;
			$file   =~ s/AN::Tools\//$dir/;
			$file   =~ s/\/\//\//g;
		}
		
		# I have a file. Is it relative to the install dir or fully qualified?
		if (($file =~ /^\.\//) || ($file !~ /^\//))
		{
			# It's in or relative to this directory.
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
	
	# Is it too early to use "$an->error"?
	open ($read, "<$file") or die "Can't read: [$file], error was: $!\n";
	while (<$read>)
	{
		chomp;
		my $line  =  $_;
		   $line  =~ s/^\s+//;
		   $line  =~ s/\s+$//;
		next if ((not $line) or ($line =~ /^#/));
		next if $line !~ /=/;
		my ($variable, $value) = split/=/, $line, 2;
		$variable =~ s/\s+$//;
		$value    =~ s/^\s+//;
		next if not $variable;
		
		# If the variable has '#!hostname!#' or '#!short_hostname!#', convert it now.
		$variable =~ s/#!hostname!#/$an->hostname/g;
		$variable =~ s/#!short_hostname!#/$an->short_hostname/g;
		
		$an->_make_hash_reference($hash, $variable, $value);
	}
	$read->close();
	
	### MADI: Make this a more intelligent method that can go a variable
	###       number of sub-keys deep and does a search/replace of
	###       variables based on a given key match.
	# Some keys store directories. Below, I convert the ones I know about
	# to the current operating system's directory delimiter where '::' is
	# found.
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

# This method returns an array reference of directories to search within for
# files and directories.
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
			$an->Alert->error({
				fatal			=>	1,
				title_key		=>	"error_title_0003",
				message_key		=>	"error_message_0003",
				message_variables	=>	{
					array			=>	$array,
				},
				code		=>	45,
				file		=>	"$THIS_FILE",
				line		=>	__LINE__
			});
			
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
	
	my $this_host  = "";
	my $shell_call = $an->data->{path}{ssh_config};
	open (my $file_handle, "<$shell_call") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0016", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
	while (<$file_handle>)
	{
		chomp;
		my $line = $_;
		$line =~ s/#.*$//;
		$line =~ s/\s+$//;
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

1;
