package AN::Tools::Check;
# 
# This module contains methods used to check things, like ssh access to remote machines.
# 

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Check.pm";

### Methods:
# access
# daemon
# drbd_resource
# kernel_module
# ping
# _environment
# _os

#############################################################################################################
# House keeping methods                                                                                     #
#############################################################################################################

# The constructor
sub new
{
	#print "$THIS_FILE ".__LINE__."; In AN::Check->new()\n";
	my $class = shift;
	
	my $self  = {};
	
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

# This tries to ssh into the target and echo back '1'.
sub access
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "AN::Tools::Check->access()" }, file => $THIS_FILE, line => __LINE__});
	
	if (not $parameter->{target})
	{
		$an->Alert->warning({title_key => "warning_title_0004", message_key => "warning_title_0009", file => "$THIS_FILE", line => __LINE__});
		return(2);
	}
	
	my $access     = 0;
	my $target     = $parameter->{target};
	my $port       = $parameter->{port}     ? $parameter->{port}     : 22;
	my $password   = $parameter->{password} ? $parameter->{password} : "";
	my $shell_call = $an->data->{path}{echo}." 1";

	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line eq "1")
		{
			$access = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "access", value1 => $access, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return($access);
}

# This reports whether a given daemon is running (locally or remotely). It return '0' if the daemon is NOT
# running, '1' if it is and '2' if it is not found. If the return code wasn't expected, the returned state 
# will be set to the return code. The caller will have to decide what to do.
sub daemon
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	$an->Alert->_set_error;
	
	my $state = 2;
	if (not $parameter->{daemon})
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0054", code => 54, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	my $daemon   = $parameter->{daemon};
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "daemon", value1 => $daemon, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### Return codes:
	# 0   == Started
	# 1   == Bad call
	# 3   == Stopped
	# 127 == File not found
	
	# If I have a host, we're checking the daemon state on a remote system.
	my $return      = [];
	my $shell_call  = $an->data->{path}{initd}."/$daemon status; echo rc:\$?";
	my $return_code = 9999;
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
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /rc:(\d+)/)
		{
			$return_code = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($return_code eq "0")
	{
		# It is running.
		$state = 1;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "state", value1 => $state, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($return_code eq "3")
	{
		# It is stopped.
		$state = 0;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "state", value1 => $state, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($return_code eq "127")
	{
		# It wasn't found.
		$state = 2;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "state", value1 => $state, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# No idea...
		$state = $return_code;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "state", value1 => $state, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "state", value1 => $state, 
	}, file => $THIS_FILE, line => __LINE__});
	return($state);
}

# This simply checks a DRBD resource's state.
sub drbd_resource
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	$an->Alert->_set_error;
	
	if (not $parameter->{resource})
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0056", code => 56, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	my $state    = {
		minor_number     => "",
		connection_state => "",
		this_role        => "",
		peer_role        => "",
		this_disk_state  => "",
		peer_disk_state  => "",
		resource_is_up   => 0,
		percent_synced   => "",
		synced_eta       => "",
	};
	my $drbd     = {};
	my $resource = $parameter->{resource};
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "resource", value1 => $resource, 
		name2 => "target",   value2 => $target, 
		name3 => "port",     value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return = [];
	my $shell_call = $an->data->{path}{'drbd-overview'};
	if ($target)
	{
		# Working on the peer.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
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
		# Working locally
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
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

	$state->{resource_is_up} = 0;
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /(\d+):$resource\/\d+ (.*?) (.*?)\/(.*?) (.*?)\/(.*)$/)
		{
			$state->{minor_number}     = $1;
			$state->{connection_state} = $2;
			$state->{this_role}        = $3;
			$state->{peer_role}        = $4;
			$state->{this_disk_state}  = $5;
			$state->{peer_disk_state}  = $6;
			$state->{resource_is_up}   = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0008", message_variables => {
				name1 => "resource",         value1 => $resource, 
				name2 => "minor_number",     value2 => $state->{minor_number}, 
				name3 => "connection_state", value3 => $state->{connection_state}, 
				name4 => "this_role",        value4 => $state->{this_role}, 
				name5 => "peer_role",        value5 => $state->{peer_role}, 
				name6 => "this_disk_state",  value6 => $state->{this_disk_state}, 
				name7 => "peer_disk_state",  value7 => $state->{peer_disk_state}, 
				name8 => "resource_is_up",   value8 => $state->{resource_is_up}, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Record the detail for when we parse /proc/drbd
			$an->data->{drbd}{$resource}{minor_number}     = $state->{minor_number};
		}
	}
	
	# Read in /proc/drbd
	$return = [];
	$shell_call = $an->data->{path}{cat}." ".$an->data->{path}{proc_drbd};
	if ($target)
	{
		# Working on the peer.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
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
		# Working locally
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
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
	my $in_resource = "";
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^(\d+): cs/)
		{
			my $minor_number = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "minor_number", value1 => $minor_number, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Find the resource name.
			foreach my $resource (sort {$a cmp $b} keys %{$an->data->{drbd}})
			{
				my $this_minor_number = $an->data->{drbd}{$resource}{minor_number};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "resource",          value1 => $resource, 
					name2 => "this_minor_number", value2 => $this_minor_number, 
					name3 => "minor_number",      value3 => $minor_number, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($this_minor_number eq $minor_number)
				{
					# Got it.
					$in_resource = $resource;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "in_resource", value1 => $in_resource, 
					}, file => $THIS_FILE, line => __LINE__});
					last;
				}
			}
		}
		elsif ($line =~ /cs:/)
		{
			# This just checks to clear the resource if we missed a regex check and we've hit a 
			# new resource. It should never actually be hit.
			$in_resource = "";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "in_resource", value1 => $in_resource, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Only care if this is the resource the user asked for.
		next if not $in_resource;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "resource",    value1 => $resource, 
			name2 => "in_resource", value2 => $in_resource, 
		}, file => $THIS_FILE, line => __LINE__});
		next if $in_resource ne $resource;
		
		if ($line =~ /sync'ed: (.*?)%/)
		{
			$state->{percent_synced} = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "state->{percent_synced}", value1 => $state->{percent_synced}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /finish: (\d+):(\d+):(\d+) /)
		{
			my $hours          = $1;
			my $minutes        = $2;
			my $seconds        = $3;
			my $total_seconds  = (($hours * 3600) + ($minutes * 60) + $seconds);
			$state->{sync_eta} = $total_seconds;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
				name1 => "hours",             value1 => $hours, 
				name2 => "minutes",           value2 => $minutes, 
				name3 => "seconds",           value3 => $seconds, 
				name4 => "state->{sync_eta}", value4 => $state->{sync_eta}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return($state);
}

# This reports back whether a kernel module is loaded or not.
sub kernel_module
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	$an->Alert->_set_error;
	
	my $state = 0;
	if (not $parameter->{module})
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0055", code => 55, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	my $module   = $parameter->{module};
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "module", value1 => $module, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### Return codes:
	# 0 == not loaded or found
	# 1 == module is loaded
	
	# If I have a host, we're checking the daemon state on a remote system.
	my $shell_call = $an->data->{path}{lsmod};
	my $return     = [];
	if ($target)
	{
		# Remote call.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
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
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^$module\s/)
		{
			$state = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "state", value1 => $state, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "state", value1 => $state, 
	}, file => $THIS_FILE, line => __LINE__});
	return($state);
}

# This pings the target (hostname or IP) and if it can be reached, it returns '0'. If it can't be reached, it
# returns '1'.
sub ping
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "AN::Tools::Check->ping()" }, file => $THIS_FILE, line => __LINE__});
	
	if (not $parameter->{target})
	{
		$an->Alert->warning({title_key => "warning_title_0004", message_key => "warning_title_0003", file => "$THIS_FILE", line => __LINE__});
		return(2);
	}
	
	# If we were passed a target, try pinging from it instead of locally
	my $ping     = $parameter->{ping};
	my $count    = $parameter->{count}    ? $parameter->{count}    : 1;	# How many times to try to ping it? Will exit as soon as one succeeds
	my $fragment = $parameter->{fragment} ? $parameter->{fragment} : 1;	# Allow fragmented packets? Set to '0' to check MTU.
	my $payload  = $parameter->{payload}  ? $parameter->{payload}  : 0;	# The size of the ping payload. Use when checking MTU.
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "ping",     value1 => $ping, 
		name2 => "count",    value2 => $count, 
		name3 => "fragment", value3 => $fragment, 
		name4 => "payload",  value4 => $payload, 
		name5 => "target",   value5 => $target, 
		name6 => "port",     value6 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If the payload was set, take 28 bytes off to account for ICMP overhead.
	if ($payload)
	{
		$payload -= 28;
	}
	
	# Build the call
	my $shell_call = $an->data->{path}{'ping'}." -n $ping -c 1";
	if (not $fragment)
	{
		$shell_call .= " -M do";
	}
	if ($payload)
	{
		$shell_call .= " -s $payload";
	}
	
	my $pinged = 0;
	foreach my $try (1..$count)
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "try",    value1 => $try,
			name2 => "pinged", value2 => $pinged
		}, file => $THIS_FILE, line => __LINE__});
		last if $pinged;
		
		my $return = [];
		
		# If the 'target' is set, we'll call over SSH unless 'target' is 'local' or our hostname.
		if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
		{
			### Remote calls
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "target",     value1 => $target,
				name2 => "shell_call", value2 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$target,
				port		=>	$port, 
				password	=>	$password,
				shell_call	=>	$shell_call,
			});
		}
		else
		{
			### Local calls
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call, 
			}, file => $THIS_FILE, line => __LINE__});
			open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				push @{$return}, "$line\n";
			}
			close $file_handle;
		}
		
		foreach my $line (@{$return})
		{
			if ($line =~ /(\d+) packets transmitted, (\d+) received/)
			{
				# This isn't really needed, but might help folks watching the logs.
				my $pings_sent     = $1;
				my $pings_received = $2;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "ping",           value1 => $ping, 
					name2 => "pings_sent",     value2 => $pings_sent, 
					name3 => "pings_received", value3 => $pings_received, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($pings_received)
				{
					# Contact!
					$pinged = 1;
				}
				else
				{
					# Not yet... Sleep to give time for transient network problems to 
					# pass.
					sleep 1;
				}
			}
		}
	}
	my $return_code = $pinged ? 0 : 1;
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code, 
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}


#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

# This private method is called my AN::Tools' constructor at startup and checks the calling environment. It 
# will set 'cli' or 'html' depending on what environment variables are set. This in turn is used when 
# displaying output to the user.
sub _environment
{
	my $self = shift;
	my $an   = $self->parent;
	
	if ($ENV{SHELL})
	{
		# Some linux variant
		$an->environment("cli");
	}
	elsif ($ENV{HTTP_USER_AGENT})
	{
		# Some windows variant.
		$an->environment("html");
	}
	else
	{
		# Huh?
		$an->Alert->warning({
			title_key	=>	"warning_title_0002",
			message_key	=>	"warning_message_0002",
			file		=>	"$THIS_FILE",
			line		=>	__LINE__
		});
		$an->environment("html");
	}
	
	return (1);
}

# This private method is called my AN::Tools' constructor at startup and checks the underlying OS and sets 
# any internal variables as needed. It takes no arguments and simply returns '1' when complete.
sub _os
{
	my $self = shift;
	my $an   = $self->parent;
	
	if (lc($^O) eq "linux")
	{
		# Some linux variant
		$an->_directory_delimiter("/");
	}
	elsif (lc($^O) eq "mswin32")
	{
		# Some windows variant.
		$an->_directory_delimiter("\\");
	}
	else
	{
		# Huh?
		$an->Alert->warning({
			title_key		=>	"warning_title_0001",
			message_key		=>	"warning_message_0001",
			message_variables	=>	{
				os			=>	$^O,
			},
			file			=>	"$THIS_FILE",
			line			=>	__LINE__
		});
		$an->_directory_delimiter("/");
	}
	
	return (1);
}

1;
