package AN::Tools::System;
# 
# This module contains methods used to handle system-level things, like powering off machines.
# 

use strict;
use warnings;
use Data::Dumper;

our $VERSION  = "0.1.001";
my $THIS_FILE = "System.pm";

### Methods;
# compress_file
# configure_ipmi
# daemon_boot_config
# delayed_run
# dual_command_run
# get_daemon_state
# get_uptime
# poweroff
# synchronous_command_run
# _avoid_duplicate_delayed_runs

#############################################################################################################
# House keeping methods                                                                                     #
#############################################################################################################

sub new
{
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

# This compresses a given file using 
sub compress_file
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "compress_file" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $file     = $parameter->{file}     ? $parameter->{file}     : "";
	my $keep     = $parameter->{keep}     ? $parameter->{keep}     : 0;
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "file",   value1 => $file, 
		name2 => "keep",   value2 => $keep, 
		name3 => "target", value3 => $target, 
		name4 => "port",   value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Make sure a file was passed and, if it was, that it looks sane.
	if (not $file)
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0188", code => 188, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	if ($file !~ /^\//)
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0189", message_variables => { file => $file }, code => 189, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	my $return     = [];
	my $start_time = time;
	my $i_am_a     = $an->Get->what_am_i();
	my $say_keep   = $keep             ? "--keep"  : "";
	my $say_small  = $i_am_a eq "node" ? "--small" : "";
	my $shell_call = $an->data->{path}{bzip2}." --compress $say_keep $say_small ".$file;
	if ($target)
	{
		# Remote call.
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
		# Local call
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
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
	
	my $compress_time = time - $start_time;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "compress_time", value1 => $compress_time, 
	}, file => $THIS_FILE, line => __LINE__});
	
	return($return);
}

# This sets the IPMI password on the target machine (remote or local). It's name is this because, later, it 
# will replace InstallManifest->configure_ipmi_on_node().
sub configure_ipmi
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_ipmi" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $return       = 0;
	my $ipmi_ip      = $parameter->{ipmi_ip}       ? $parameter->{ipmi_ip}       : "";
	my $ipmi_netmask = $parameter->{ipmi_netmask}  ? $parameter->{ipmi_netmask}  : "";
	my $ipmi_user    = $parameter->{ipmi_user}     ? $parameter->{ipmi_user}     : "";
	my $ipmi_gateway = $parameter->{ipmi_gateway}  ? $parameter->{ipmi_gateway}  : "";
	my $new_password = $parameter->{new_password} ? $parameter->{new_password} : "";
	my $target       = $parameter->{target}       ? $parameter->{target}       : "";
	my $port         = $parameter->{port}         ? $parameter->{port}         : "";
	my $password     = $parameter->{password}     ? $parameter->{password}     : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "ipmi_ip",       value1 => $ipmi_ip, 
		name2 => "ipmi_netmask",  value2 => $ipmi_netmask, 
		name3 => "ipmi_user",     value3 => $ipmi_user, 
		name4 => "ipmi_gateway",  value4 => $ipmi_gateway, 
		name5 => "target",        value5 => $target, 
		name6 => "port",          value6 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "new_password", value1 => $new_password, 
		name2 => "password",     value2 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Make sure a file was passed and, if it was, that it looks sane.
	if (not $new_password)
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0194", code => 194, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	my $return_code = 255;
	# 0 = Configured
	# 1 = Failed to set the IPMI password
	# 2 = No IPMI device found
	# 3 = LAN channel not found
	# 4 = User ID not found
	
	# Is there an IPMI device?
	my ($state) = $an->System->get_daemon_state({
			target   => $target, 
			port     => $port, 
			password => $password,
			daemon   => "ipmi", 
		});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "state", value1 => $state,
	}, file => $THIS_FILE, line => __LINE__});
	if ($state eq "7")
	{
		# IPMI not found
		$return_code = 2;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "return_code", value1 => $return_code,
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# If we're still alive, then it is safe to say IPMI is running. Find the LAN channel
		my $lan_found = 0;
		my $channel   = 0;
		while (not $lan_found)
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "channel", value1 => $channel,
			}, file => $THIS_FILE, line => __LINE__});
			if ($channel > 10)
			{
				# Give up...
				$an->Log->entry({log_level => 1, message_key => "log_0127", file => $THIS_FILE, line => __LINE__});
				$channel = "";
				last;
			}
			
			# check to see if this is the right channel
			my $return_code = "";
			my $return      = [];
			my $shell_call  = $an->data->{path}{ipmitool}." lan print $channel; ".$an->data->{path}{echo}." return_code:\$?";
			if ($target)
			{
				# Remote call.
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
				# Local call
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
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
				
				if ($line =~ /Invalid channel: /)
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "channel", value1 => $channel,
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($line =~ "return_code:0")
				{
					# Found it!
					$lan_found = 1;
					$an->Log->entry({log_level => 2, message_key => "log_0128", message_variables => { channel => $channel }, file => $THIS_FILE, line => __LINE__});
				}
			}
			$channel++ if not $lan_found;
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "channel", value1 => $channel,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Now find the admin user ID number
		my $user_id   = 0;
		my $uid_found = 0;
		if ($lan_found)
		{
			while (not $uid_found)
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "user_id", value1 => $user_id,
				}, file => $THIS_FILE, line => __LINE__});
				if ($user_id > 20)
				{
					# Give up...
					$an->Log->entry({log_level => 1, message_key => "log_0129", file => $THIS_FILE, line => __LINE__});
					$user_id = "";
					last;
				}
				
				# check to see if this is the write channel
				my $return_code = "";
				my $return      = [];
				my $shell_call  = $an->data->{path}{ipmitool}." user list $channel";
				if ($target)
				{
					# Remote call.
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
					# Local call
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "shell_call", value1 => $shell_call,
					}, file => $THIS_FILE, line => __LINE__});
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
					$line =~ s/\s+/ /g;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
					
					if ($line =~ /^(\d+) $ipmi_user /)
					{
						$user_id   = $1;
						$uid_found = 1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "user_id", value1 => $user_id,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				$user_id++ if not $uid_found;
			}
			
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "ipmi_user", value1 => $ipmi_user,
				name2 => "user_id",   value2 => $user_id,
			}, file => $THIS_FILE, line => __LINE__});
			if ($uid_found)
			{
				# Set the password.
				my $return     = [];
				my $shell_call = $an->data->{path}{ipmitool}." user set password $user_id '$new_password'";
				if ($target)
				{
					# Remote call.
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
					# Local call
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "shell_call", value1 => $shell_call,
					}, file => $THIS_FILE, line => __LINE__});
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
				
				# Test the password. If this fails with '16', try '20'.
				my $password_ok = 0;
				my $try_20      = 0;
				   $return      = [];
				   $shell_call  = $an->data->{path}{ipmitool}." user test $user_id 16 '$new_password'";
				if ($target)
				{
					# Remote call.
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
					# Local call
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "shell_call", value1 => $shell_call,
					}, file => $THIS_FILE, line => __LINE__});
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
					
					if ($line =~ /Success/i)
					{
						# Woo!
						$an->Log->entry({log_level => 2, message_key => "log_0130", message_variables => { channel => $channel }, file => $THIS_FILE, line => __LINE__});
					}
					elsif ($line =~ /wrong password size/i)
					{
						# Try size 20.
						$try_20 = 1;
						$an->Log->entry({log_level => 2, message_key => "log_0131", file => $THIS_FILE, line => __LINE__});
					}
					elsif ($line =~ /password incorrect/i)
					{
						# Password didn't take. :(
						$return_code = 1;
						$an->Log->entry({log_level => 1, message_key => "log_0132", message_variables => { channel => $channel }, file => $THIS_FILE, line => __LINE__});
					}
				}
				if ($try_20)
				{
					my $shell_call = $an->data->{path}{ipmitool}." user test $user_id 20 '$new_password'";
					my $return     = [];
					if ($target)
					{
						# Remote call.
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
						# Local call
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "shell_call", value1 => $shell_call,
						}, file => $THIS_FILE, line => __LINE__});
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
						
						if ($line =~ /Success/i)
						{
							# Woo!
							$an->Log->entry({log_level => 2, message_key => "log_0133", message_variables => {
								channel => $channel, 
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($line =~ /password incorrect/i)
						{
							# Password didn't take. :(
							$return_code = 1;
							$an->Log->entry({log_level => 1, message_key => "log_0132", message_variables => {
								channel => $channel, 
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
				}
			}
		}
		
		# If I am missing either the channel or the user ID, we're done.
		if (not $lan_found)
		{
			$return_code = 3;
		}
		elsif (not $uid_found)
		{
			$return_code = 4;
		}
		elsif ($return_code ne "1")
		{
			### TODO: This isn't used yet. Fill it out from InstallManifest->configure_ipmi_on_node()
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return);
}

# This checks/sets whether a daemon is set to start on boot or not.
sub daemon_boot_config
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "daemon_boot_config" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	if (not $parameter->{daemon})
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0162", code => 162, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	my $daemon   = $parameter->{daemon}   ? $parameter->{daemon}   : "";
	my $set      = $parameter->{set}      ? $parameter->{set}      : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "daemon", value1 => $daemon, 
		name2 => "set",    value2 => $set, 
		name3 => "target", value3 => $target, 
		name4 => "port",   value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Make sure a valid 'set' was passed in, if any.
	if (($set) && (($set ne "off") && ($set ne "on")))
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0163", message_variables => { set => $set }, code => 163, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# If I have a host, we're checking the daemon state on a remote system.
	my $state  = {
		0 => "unknown",
		1 => "unknown",
		2 => "unknown",
		3 => "unknown",
		4 => "unknown",
		5 => "unknown",
		6 => "unknown",
	};
	my $return     = [];
	my $shell_call = $an->data->{path}{chkconfig}." --list $daemon";
	if ($set)
	{
		$shell_call = $an->data->{path}{chkconfig}." $daemon $set; ".$an->data->{path}{chkconfig}." --list $daemon";
	}
	if ($target)
	{
		# Remote call.
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
	}
	else
	{
		# Local call
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /$daemon\s+0:(.*?)\s+1:(.*?)\s+2:(.*?)\s+3:(.*?)\s+4:(.*?)\s+5:(.*?)\s+6:(.*)$/)
		{
			$state = {
				0 => $1,
				1 => $2,
				2 => $3,
				3 => $4,
				4 => $5,
				5 => $6,
				6 => $7,
			};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
				name1 => "state->0", value1 => $state->{0}, 
				name2 => "state->1", value2 => $state->{1}, 
				name3 => "state->2", value3 => $state->{2}, 
				name4 => "state->3", value4 => $state->{3}, 
				name5 => "state->4", value5 => $state->{4}, 
				name6 => "state->5", value6 => $state->{5}, 
				name7 => "state->6", value7 => $state->{6}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "state", value1 => $state, 
	}, file => $THIS_FILE, line => __LINE__});
	return($state);
}

# This uses 'anvil-run-jobs' to run a job in the future (or just to run it in the background)
sub delayed_run
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "delayed_run" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Get the target
	my $command  =         $parameter->{command};
	my $delay    = defined $parameter->{delay}    ? $parameter->{delay}    : 60;
	my $target   =         $parameter->{target}   ? $parameter->{target}   : "local";
	my $password =         $parameter->{password} ? $parameter->{password} : "";
	my $port     =         $parameter->{port}     ? $parameter->{port}     : 22;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "command", value1 => $command, 
		name2 => "delay",   value2 => $delay, 
		name3 => "target",  value3 => $target, 
		name4 => "port",    value4 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Check to see if this job has already been requested. The other job's token will be returned, if so.
	my $problem = "";
	my $output  = "";
	my ($token) = $an->System->_avoid_duplicate_delayed_runs({
		command  => $command,
		target   => $target, 
		port     => $port,
		password => $password, 
	});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "token", value1 => $token, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If we don't have a token, it is a new job.
	if (not $token)
	{
		$token  =  $an->Get->uuid();
		$output =  $an->data->{path}{'anvil-jobs-output'};
		$output =~ s/#!token!#/$token/;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "token",  value1 => $token, 
			name2 => "output", value2 => $output, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Setup the job line
		my $time     =  time;
		my $run_time =  $time + $delay;
		my $job_line =  "$run_time:".$token.":$command";
		   $job_line =~ s/'/\'/g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "time",     value1 => $time, 
			name2 => "run_time", value2 => $run_time, 
			name3 => "job_line", value3 => $job_line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# The call might be local or on a remote system.
		my $shell_call = $an->data->{path}{echo}." '$job_line' >> ".$an->data->{path}{'anvil-jobs'};
		my $return     = [];
		
		# If the node name is 'local', we'll run locally.
		if ((not $target) or ($target eq "local") or ($target eq $an->hostname) or ($target eq $an->short_hostname))
		{
			# Local call.
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call, 
			}, file => $THIS_FILE, line => __LINE__});
			open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
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
		else
		{
			# Remote call
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "target",     value1 => $target,
				name2 => "port",       value2 => $port,
				name3 => "shell_call", value3 => $shell_call,
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
		foreach my $line (@{$return})
		{
			next if not $line;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			$problem .= "$line\n";
		}
	}
	
	# Make sure we didn't hit an error
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "output", value1 => $output,
	}, file => $THIS_FILE, line => __LINE__});
	if ($problem)
	{
		$token = "";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "token", value1 => $token,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# This method doesn't wait. We'll return the token and let the caller decide whether to wait or not.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "token",   value1 => $token,
		name2 => "output",  value2 => $output,
		name3 => "problem", value3 => $problem,
	}, file => $THIS_FILE, line => __LINE__});
	return($token, $output, $problem);
}

### TODO: Convert this to take each target's IP, Port and Password separately, as we do with 
###       'synchronous_command_run()'.
# This runs a command on both nodes (or local and remote), but it does it in serial not synchronously.
sub dual_command_run
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "dual_command_run" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Get the target
	my $command = $parameter->{command} ? $parameter->{command} : "";
	my $delay   = $parameter->{delay}   ? $parameter->{delay}   : 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "command",        value1 => $command, 
		name2 => "delay",          value2 => $delay, 
		name3 => "hostname",       value3 => $an->hostname,
		name4 => "short_hostname", value4 => $an->short_hostname, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Well store the output of both machines here.
	my $output     = {};
	my $shell_call = $command;
	foreach my $node_key ("node1", "node2")
	{
		my $node     = $an->data->{sys}{anvil}{$node_key}{name};
		my $target   = $an->data->{sys}{anvil}{$node_key}{use_ip};
		my $port     = $an->data->{sys}{anvil}{$node_key}{use_port};
		my $password = $an->data->{sys}{anvil}{$node_key}{use_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node",   value1 => $node, 
			name2 => "target", value2 => $target, 
			name3 => "port",   value3 => $port, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password, 
		}, file => $THIS_FILE, line => __LINE__});
		# This will contain the output seen for both nodes
		   $output->{$node} = "";
		my $return          = [];
		
		# If the node name is 'local', we'll run locally.
		if (($node eq "local") or ($node eq $an->hostname) or ($node eq $an->short_hostname))
		{
			# Local call.
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call, 
			}, file => $THIS_FILE, line => __LINE__});
			open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
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
		else
		{
			# Remote call
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
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			$output->{$node} .= "$line\n";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node}::output", value1 => $an->data->{node}{$node}{output},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Return the hash reference of output from both nodes.
	return($output);
}

# This checks to see if a daemon is running or not.
sub get_daemon_state
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_daemon_state" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $daemon   = $parameter->{daemon}   ? $parameter->{daemon}   : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "daemon", value1 => $daemon, 
		name2 => "target", value2 => $target, 
		name3 => "target", value3 => $target, 
		name4 => "port",   value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# LSB says
	# 0 == running
	# 3 == stopped
	# Reality;
	# * ipmi;
	#   0 == running
	#   6 == stopped
	# * network
	#   0 == running
	#   0 == stopped   o_O
	my $running_return_code = 0;
	my $stopped_return_code = 3;
	if ($daemon eq "ipmi")
	{
		$stopped_return_code = 6;
	}
	
	# This will store the state.
	my $state = "";
	
	# Check if the daemon is running currently.
	my $return     = [];
	my $i_am_a     = $an->Get->what_am_i();
	my $shell_call = $an->data->{path}{initd}."/$daemon status; ".$an->data->{path}{echo}." return_code:\$?";
	if ($target)
	{
		# Remote call.
		$an->Log->entry({log_level => 2, message_key => "log_0150", message_variables => {
			target => $target, 
			daemon => $daemon,
		}, file => $THIS_FILE, line => __LINE__});
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
		# Local call
		$an->Log->entry({log_level => 2, message_key => "log_0271", message_variables => { daemon => $daemon }, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
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
		
		if ($line =~ /No such file or directory/i)
		{
			# Not installed, pretend it is off. The log entry depends on if we checked locally 
			# or not.
			if ($target)
			{
				$an->Log->entry({log_level => 2, message_key => "log_0151", message_variables => {
					target => $target, 
					daemon => $daemon,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				$an->Log->entry({log_level => 2, message_key => "log_0272", message_variables => { daemon => $daemon }, file => $THIS_FILE, line => __LINE__});
			}
			$state = 0;
			last;
		}
		if ($line =~ /^return_code:(\d+)/)
		{
			my $return_code = $1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "return_code",         value1 => $return_code,
				name2 => "stopped_return_code", value2 => $stopped_return_code,
				name3 => "running_return_code", value3 => $running_return_code,
			}, file => $THIS_FILE, line => __LINE__});
			if ($return_code eq $running_return_code)
			{
				$state = 1;
			}
			elsif ($return_code eq $stopped_return_code)
			{
				$state = 0;
			}
			else
			{
				$state = "undefined:$return_code";
			}
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "return_code", value1 => $return_code,
				name2 => "state",       value2 => $state,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "state", value1 => $state,
	}, file => $THIS_FILE, line => __LINE__});
	return($state);
}

# This returns the targets uptime expressed in seconds
sub get_uptime
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "poweroff" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target, 
		name2 => "port",   value2 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $uptime     = 99999999;
	my $shell_call = $an->data->{path}{cat}." ".$an->data->{path}{proc_uptime};
	my $return     = [];
	
	# If the 'target' is set, we'll call over SSH unless 'target' is 'local' or our hostname.
	if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
	{
		### Remote calls
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
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
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line =  $_;
			push @{$return}, $line;
		}
		close $file_handle;
	}
	my $output = "";
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^(\d+)\./)
		{
			$uptime = $1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "uptime", value1 => $uptime, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return($uptime);
}

# This calls 'poweroff' on a machine (possibly this one).
sub poweroff
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "poweroff" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
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
	
	### NOTE: The alternate call effectively disables the shutdown, which can be useful in debugging 
	###       shutdown and restart issues.
	#my $shell_call = $an->data->{path}{echo}." '".$an->data->{path}{poweroff}." --verbose'";
	my $shell_call = $an->data->{path}{poweroff}." --verbose";
	my $return     = [];
	
	# If the 'target' is set, we'll call over SSH unless 'target' is 'local' or our hostname.
	if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
	{
		# This is an untranslated string used by '$an->Striker->_cold_stop_anvil()' to know which machine is powering down.
		print "poweroff: $target\n";
		
		### Remote calls
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "target",     value2 => $target,
		}, file => $THIS_FILE, line => __LINE__});
		(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			'close'		=>	1,
			shell_call	=>	$shell_call,
		});
	}
	else
	{
		# This is an untranslated string used by '$an->Striker->_cold_stop_anvil()' to know which machine is powering down.
		print "poweroff: ".$an->hostname."\n";
		
		### Local calls
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
	my $output = "";
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		$output .= "$line\n";
	}
	
	return($output);
}

# This uses 'anvil-run-jobs' to run a command on both nodes at the same time (or at least within a minute of
# each other).
sub synchronous_command_run
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "synchronous_command_run" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Get the target
	my $command = $parameter->{command} ? $parameter->{command} : "";
	my $delay   = $parameter->{delay}   ? $parameter->{delay}   : 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "command",        value1 => $command, 
		name2 => "delay",          value2 => $delay, 
		name3 => "hostname",       value3 => $an->hostname,
		name4 => "short_hostname", value4 => $an->short_hostname, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### NOTE: This now uses 'anvil-run-jobs' in order to start cman on both nodes at the same time
	###       without the need to fork(). This is done because it is not reliable enough. It is too easy
	###       for a non-thread-safe bit of code to sneak in and clobber file handles.
	my $waiting = 1;
	my $output  = {};
	
	# Add the command to each node's anvil-run-jobs queue and then wait in a loop for both to have run
	# (or time out).
	foreach my $node_key ("node1", "node2")
	{
		my $node     = $an->data->{sys}{anvil}{$node_key}{name};
		my $target   = $an->data->{sys}{anvil}{$node_key}{use_ip};
		my $port     = $an->data->{sys}{anvil}{$node_key}{use_port};
		my $password = $an->data->{sys}{anvil}{$node_key}{use_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node",   value1 => $node, 
			name2 => "target", value2 => $target, 
			name3 => "port",   value3 => $port, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Before we start, see if there is a job like this in the queue already. If so, take its 
		# token and don't add a new entry.
		my ($token) = $an->System->_avoid_duplicate_delayed_runs({
			command  => $command,
			target   => $target, 
			port     => $port,
			password => $password, 
		});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "token", value1 => $token, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$output->{$node} = "";
		if ($token)
		{
			$an->data->{node}{$node}{token}  = $token;
			$an->data->{node}{$node}{output} = $an->data->{path}{'anvil-jobs-output'};
			$an->data->{node}{$node}{output} =~ s/#!token!#/$token/;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "node::${node}::token",  value1 => $an->data->{node}{$node}{token}, 
				name2 => "node::${node}::output", value2 => $an->data->{node}{$node}{output}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# This will contain the output seen for both nodes
			$token                           = $an->Get->uuid();
			$an->data->{node}{$node}{token}  = $token;
			$an->data->{node}{$node}{output} = $an->data->{path}{'anvil-jobs-output'};
			$an->data->{node}{$node}{output} =~ s/#!token!#/$token/;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "node::${node}::token",  value1 => $an->data->{node}{$node}{token}, 
				name2 => "node::${node}::output", value2 => $an->data->{node}{$node}{output}, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# Setup the job line
			my $time     =  time;
			my $run_time =  $time + $delay;
			my $job_line =  "$run_time:".$an->data->{node}{$node}{token}.":$command";
			   $job_line =~ s/'/\'/g;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "time",     value1 => $time, 
				name2 => "run_time", value2 => $run_time, 
				name3 => "job_line", value3 => $job_line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			# We use a delay of 30 seconds to ensure that we don't have one node trigger a minute before
			# the other in cases where this is invoked near the end of a minute.
			my $shell_call = $an->data->{path}{echo}." '$job_line' >> ".$an->data->{path}{'anvil-jobs'};
			my $return     = [];
			
			# If the node name is 'local', we'll run locally.
			if (($target eq "local") or ($target eq $an->hostname) or ($target eq $an->short_hostname))
			{
				# Local call.
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "shell_call", value1 => $shell_call, 
				}, file => $THIS_FILE, line => __LINE__});
				open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
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
			else
			{
				# Remote call, so get the time from the target machine in case the time in 
				# this dashboard differs.
				my $time       = time;
				my $shell_call = $an->data->{path}{perl}." -e 'print time'";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "target",     value1 => $target,
					name2 => "port",       value2 => $port,
					name3 => "shell_call", value3 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
				(my $error, my $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$target,
					port		=>	$port, 
					password	=>	$password,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					next if not $line;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
					
					if ($line =~ /^(\d+)$/)
					{
						$time = $1;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "time", value1 => $time, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				undef $return;
				
				# Now rebuild our job time.
				my $run_time =  $time + $delay;
				my $job_line =  "$run_time:".$an->data->{node}{$node}{token}.":$command";
				   $job_line =~ s/'/\'/g;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "time",     value1 => $time, 
					name2 => "run_time", value2 => $run_time, 
					name3 => "job_line", value3 => $job_line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				$shell_call = $an->data->{path}{echo}." '$job_line' >> ".$an->data->{path}{'anvil-jobs'};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "target",     value1 => $target,
					name2 => "port",       value2 => $port,
					name3 => "shell_call", value3 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
				($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$target,
					port		=>	$port, 
					password	=>	$password,
					shell_call	=>	$shell_call,
				});
			}
			foreach my $line (@{$return})
			{
				next if not $line;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Make sure we didn't hit an error
	my $node1 = $an->data->{sys}{anvil}{node1}{name};
	my $node2 = $an->data->{sys}{anvil}{node2}{name};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node1}::output", value1 => $an->data->{node}{$node1}{output},
		name2 => "node::${node2}::output", value2 => $an->data->{node}{$node2}{output},
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $an->data->{node}{$node1}{output}) or (not $an->data->{node}{$node2}{output}))
	{
		$waiting = 0;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "waiting", value1 => $waiting,
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Now sit back and wait for the call to run.
		$an->Log->entry({log_level => 1, message_key => "log_0264", file => $THIS_FILE, line => __LINE__});
	}
	
	my $current_time = time;
	my $timeout      = $current_time + $delay + 120;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "current_time", value1 => $current_time,
		name2 => "timeout",      value2 => $timeout,
		name3 => "waiting",      value3 => $waiting,
	}, file => $THIS_FILE, line => __LINE__});
	while ($waiting)
	{
		# This will get set back to '1' if we're still waiting on either node's output.
		foreach my $node_key ("node1", "node2")
		{
			my $node     = $an->data->{sys}{anvil}{$node_key}{name};
			my $target   = $an->data->{sys}{anvil}{$node_key}{use_ip};
			my $port     = $an->data->{sys}{anvil}{$node_key}{use_port};
			my $password = $an->data->{sys}{anvil}{$node_key}{use_password};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "node",   value1 => $node, 
				name2 => "target", value2 => $target, 
				name3 => "port",   value3 => $port, 
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
				name1 => "password", value1 => $password, 
			}, file => $THIS_FILE, line => __LINE__});

			#next if not $an->data->{node}{$node}{token};
			next if not $an->data->{node}{$node}{output};
			
			my $call_output = "";
			my $return      = [];
			my $shell_call  = "
if [ -e \"".$an->data->{node}{$node}{output}."\" ];
then
    ".$an->data->{path}{cat}." ".$an->data->{node}{$node}{output}."
else
    ".$an->data->{path}{echo}." \"No output yet\"
fi
";
	
			# If the node name is 'local', we'll run locally.
			if (($node eq "local") or ($node eq $an->hostname) or ($node eq $an->short_hostname))
			{
				# Local call.
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "shell_call", value1 => $shell_call, 
				}, file => $THIS_FILE, line => __LINE__});
				open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
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
			else
			{
				# Remote call
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
			}
			foreach my $line (@{$return})
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "target", value1 => $target,
					name2 => "line",   value2 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /No output yet/)
				{
					# We have to wait more.
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "target",  value1 => $target,
						name2 => "waiting", value2 => $waiting,
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($line =~ /arj-rc:(\d+)/)
				{
					# We're done!
					my $return_code = $1;
					my $shell_call  = $an->data->{path}{rm}." -f ".$an->data->{node}{$node}{output};
					if (($node eq "local") or ($node eq $an->hostname) or ($node eq $an->short_hostname))
					{
						# Local call.
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "shell_call", value1 => $shell_call, 
						}, file => $THIS_FILE, line => __LINE__});
						open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
						while(<$file_handle>)
						{
							chomp;
							my $line = $_;
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => "line", value1 => $line, 
							}, file => $THIS_FILE, line => __LINE__});
						}
						close $file_handle;
					}
					else
					{
						# Remote call
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
						foreach my $line (@{$return})
						{
							$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
								name1 => "target", value1 => $target,
								name2 => "line",   value2 => $line, 
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
					
					# I don't bother examining the output. If it fails, the file will be
					# wiped in the next reboot anyway.
					$an->data->{node}{$node}{output} = "";
					$an->data->{node}{$node}{token}  = "";
					
					# Only record the last loop of output, otherwise partial output will
					# stack on top of the final contents of the output file.
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "call_output", value1 => $call_output,
					}, file => $THIS_FILE, line => __LINE__});
					
					$output->{$node} = $call_output;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "output->{$node}", value1 => $output->{$node},
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# This is output from the call.
					$call_output .= "$line\n";
				}
			}
		}
		
		# See if I still have an output file. If not, we're done.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node::${node1}::output", value1 => $an->data->{node}{$node1}{output},
			name2 => "node::${node2}::output", value2 => $an->data->{node}{$node2}{output},
			name3 => "waiting",                value3 => $waiting,
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $an->data->{node}{$node1}{output}) && (not $an->data->{node}{$node2}{output}))
		{
			$waiting = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "waiting", value1 => $waiting,
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Abort if we've waited too long, otherwise sleep.
		if (($waiting) && (time > $timeout))
		{
			# Timeout, exit.
			$waiting = 0;
			$an->Log->entry({log_level => 1, message_key => "log_0265", file => $THIS_FILE, line => __LINE__});
		}
		if ($waiting)
		{
			sleep 10;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "time",    value1 => time,
				name2 => "timeout", value2 => $timeout,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Return the hash reference of output from both nodes.
	return($output);
}


#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

# This returns the token from the target target if the command is found already in the target's 
# 'anvil-run-jobs' queue.
sub _avoid_duplicate_delayed_runs
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_avoid_duplicate_delayed_runs" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Get the target
	my $token    = "";
	my $command  = $parameter->{command};
	my $target   = $parameter->{target};
	my $port     = $parameter->{port};
	my $password = $parameter->{password};
	
	# Now do the call, locally or remotely.
	my $return     = [];
	my $shell_call = $an->data->{path}{cat}." ".$an->data->{path}{'anvil-jobs'};
	if (($target eq "local") or ($target eq $an->hostname) or ($target eq $an->short_hostname))
	{
		# Local call.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
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
	else
	{
		# Remote call
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "port",       value2 => $port,
			name3 => "shell_call", value3 => $shell_call,
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
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /^(\d+):(.*?):(.*)$/)
		{
			my $this_runtime = $1;
			my $this_token   = $2;
			my $this_command = $3;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
				name1 => "this_runtime", value1 => $this_runtime, 
				name2 => "this_token",   value2 => $this_token, 
				name3 => "this_command", value3 => $this_command, 
				name4 => "command",      value4 => $command, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($command eq $this_command)
			{
				# Steal this token!
				$token = $this_token;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "token", value1 => $token, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "token", value1 => $token, 
	}, file => $THIS_FILE, line => __LINE__});
	return($token);
}

1;
