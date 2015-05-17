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

### MADI: Add a function to create a list of searchable directories that starts
###       with @INC so that a CSV of directories can be added to it after
###       reading a config file. Make this method take an array reference to
###       work on.
# This method searches the storage device for a give file or directory.
sub find
{
	my $self  = shift;
	my $param = shift;
	
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
	if (ref($param))
	{
		# Called via a hash ref, good.
		$fatal = $param->{fatal} if $param->{fatal};
		$file  = $param->{file}  if $param->{file};
		$dirs  = $param->{dirs}  if $param->{dirs};
	}
	else
	{
		# Called directly.
		$file  = $param;
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
	my $param = shift;
	
	# This just makes the code more consistent.
	my $an    = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	my $file;
	my $hash = $an->data;
	#print "$THIS_FILE ".__LINE__."; hash: [$hash]\n";
	
	# This is/was for testing.
	if (0)
	{
		foreach my $key (sort {$a cmp $b} keys %ENV) { print "ENV key: [$key]\t=\t[$ENV{$key}]\n"; }
		foreach my $key (sort {$a cmp $b} keys %INC) { print "INC key: [$key]\t=\t[$INC{$key}]\n"; }
		exit;
	}
	
	# Now see if the user passed the values in a hash reference or
	# directly.
	if (ref($param) eq "HASH")
	{
		# Values passed in a hash, good.
		$file = $param->{file} if $param->{file};
		$hash = $param->{hash} if $param->{hash};
	}
	else
	{
		# Values passed directly.
		$file = $param;
		$hash = $_[0] if defined $_[0];
	}
	#print "$THIS_FILE ".__LINE__."; hash: [$hash], file: [$file]\n";
	
	# Make sure I have a sane file name.
	#print "$THIS_FILE ".__LINE__."; file: [$file]<br />\n";
	if ($file)
	{
		# Find it relative to the AN::Tools root directory.
		#print "$THIS_FILE ".__LINE__."; file: [$file]<br />\n";
		if ($file =~ /^AN::Tools/)
		{
			my $dir =  $INC{'AN/Tools.pm'};
			#print "$THIS_FILE ".__LINE__."; dir: [$dir], file: [$file]<br />\n";
			$dir    =~ s/Tools.pm//;
			$file   =~ s/AN::Tools\//$dir/;
			$file   =~ s/\/\//\//g;
			#print "$THIS_FILE ".__LINE__."; dir: [$dir], file: [$file]<br />\n";
		}
		
		# I have a file. Is it relative to the install dir or fully
		# qualified?
		#print "$THIS_FILE ".__LINE__."; file: [$file]<br />\n";
		if (($file =~ /^\.\//) || ($file !~ /^\//))
		{
			# It's in or relative to this directory.
			if ($ENV{PWD})
			{
				# Can expand using the environment variable.
				$file =~ s/^\./$ENV{PWD}/;
				#print "$THIS_FILE ".__LINE__."; file: [$file]<br />\n";
			}
			else
			{
				# No environmnet variable, search the array of
				# directories.
				#print "$THIS_FILE ".__LINE__."; Searching for file: [$file]<br />\n";
				$file = $an->Storage->find({fatal=>1, file=>$file});
				#print "$THIS_FILE ".__LINE__."; file: [$file]<br />\n";
			}
		}
	}
	else
	{
		# No file at all...
		die "I can't read config a file I wasn't passed...\n";
	}
	#print "$THIS_FILE ".__LINE__."; hash: [$hash], file: [$file]\n";
	
	# Now that I have a file, read it.
	$an->_load_io_handle() if not $an->_io_handle_loaded();
	my $read = IO::Handle->new();
	
	# Is it too early to use "$an->error"?
	#print "$THIS_FILE ".__LINE__."; Reading file: [$file]\n";
	open ($read, "<$file") or die "Can't read: [$file], error was: $!\n";
	while (<$read>)
	{
		chomp;
		my $line  =  $_;
		$line     =~ s/^\s+//;
		$line     =~ s/\s+$//;
		next if ((not $line) or ($line =~ /^#/));
		next if $line !~ /=/;
		my ($variable, $value) = split/=/, $line, 2;
		$variable =~ s/\s+$//;
		$value    =~ s/^\s+//;
		next if not $variable;
		#print "$THIS_FILE ".__LINE__."; variable: [$variable]\t->\t[$value]\n";
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

1;
