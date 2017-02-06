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
# change_apache_password
# change_postgresql_password
# change_shell_user_password
# compress_file
# configure_ipmi
# daemon_boot_config
# delayed_run
# dual_command_run
# get_daemon_state
# get_local_ip_addresses
# get_uptime
# pick_shutdown_target
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

### NOTE: This module (for now) assumes on
# This changes the password for the apache user.
sub change_apache_password
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "change_apache_password" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $user         = $parameter->{user}         ? $parameter->{user}         : "";
	my $new_password = $parameter->{new_password} ? $parameter->{new_password} : "";
	my $target       = $parameter->{target}       ? $parameter->{target}       : "";
	my $port         = $parameter->{port}         ? $parameter->{port}         : "";
	my $password     = $parameter->{password}     ? $parameter->{password}     : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "user",   value1 => $user, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "new_password", value1 => $new_password, 
		name2 => "password",     value2 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# OK, what about a password?
	if (not $new_password)
	{
		# Um...
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0196", message_variables => { user => $user }, code => 196, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Only the root user can do this!
	# $< == real UID, $> == effective UID
	if (($< != 0) && ($> != 0))
	{
		# Not root
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0197", message_variables => { user => $user }, code => 197, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# First, read in the existing file to get the current user list. Any user that matches the requested
	# user (or all users when no user set) will be marked to update.
	my $return_code = 255;
	my $create_file = 0;
	my $user_count  = 0;
	my $to_update   = {};
	my $return      = [];
	my $shell_call  = "
if [ -e '".$an->data->{path}{htpasswd_access}."' ]
then
    ".$an->data->{path}{cat}." ".$an->data->{path}{htpasswd_access}."
else
    ".$an->data->{path}{echo}." 'no files'
fi;";
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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
		
		if ($line eq "no files")
		{
			# No file, so use '-c' for htpasswd
			$create_file = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "create_file", value1 => $create_file, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /^return_code:(\d+)$/)
		{
			$return_code = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /^(.*?):/)
		{
			my $this_user = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "this_user", value1 => $this_user, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ((not $user) or ($this_user eq $user))
			{
				# This is the requested user to update (or no specific user was requested).
				$to_update->{$this_user} = 1;
				$user_count++;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "to_update->$this_user", value1 => $to_update->{$this_user}, 
					name2 => "user_count",            value2 => $user_count, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# If we're creating the file, make sure we have at least one user.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "create_file", value1 => $create_file, 
		name2 => "user_count",  value2 => $user_count, 
	}, file => $THIS_FILE, line => __LINE__});
	if (($create_file) && (not $user_count))
	{
		# No file and no user... can't proceed.
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0196", message_variables => { user => $user }, code => 196, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Clean up the password for use in "".
	$new_password =~ s/"/\\\"/g;
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "new_password", value1 => $new_password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $changed_users = {};
	foreach my $user (sort {$a cmp $b} keys %{$to_update})
	{
		$changed_users->{$user} = 255;
		   
		# Still alive? Good!
		my $return     = [];
		my $shell_call = $an->data->{path}{htpasswd}." -b ".$an->data->{path}{htpasswd_access}." $user \"$new_password\" &>/dev/null; ".$an->data->{path}{'echo'}." return_code:\$?";
		if ($create_file)
		{
			$shell_call = $an->data->{path}{htpasswd}." -cb \"$new_password\" &>/dev/null; ".$an->data->{path}{'echo'}." return_code:\$?";
		}
		if ($target)
		{
			### WARNING: Exposes passwords
			# Remote call.
			$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
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
			### WARNING: Exposes passwords
			# Local call
			$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				push @{$return}, $line;
			}
			close $file_handle;
		}
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /^return_code:(\d+)$/)
			{
				$changed_users->{$user} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "changed_users->$user", value1 => $changed_users->{$user}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($changed_users);
}

# This changes the password for a postgres user account.
sub change_postgresql_password
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "change_postgresql_password" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $user         = $parameter->{user}         ? $parameter->{user}         : "";
	my $new_password = $parameter->{new_password} ? $parameter->{new_password} : "";
	my $target       = $parameter->{target}       ? $parameter->{target}       : "";
	my $port         = $parameter->{port}         ? $parameter->{port}         : "";
	my $password     = $parameter->{password}     ? $parameter->{password}     : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "user",   value1 => $user, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "new_password", value1 => $new_password, 
		name2 => "password",     value2 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Do I have a user?
	if (not $user)
	{
		# Woops!
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0201", code => 201, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# OK, what about a password?
	if (not $new_password)
	{
		# Um...
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0202", message_variables => { user => $user }, code => 202, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Only the root user can do this!
	# $< == real UID, $> == effective UID
	if (($< != 0) && ($> != 0))
	{
		# Not root
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0203", message_variables => { user => $user }, code => 203, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Clean up the password for use in "".
	$new_password =~ s/'/''/g;
	$new_password =~ s/"/\\\"/g;
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "new_password", value1 => $new_password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# 
	# Still alive? Good!
	my $return_code = 255;
	my $return      = [];
	my $shell_call  = $an->data->{path}{su}." - postgres -c \"".$an->data->{path}{psql}." template1 -c \\\"ALTER ROLE $user WITH PASSWORD '${new_password}';\\\"\"; ".$an->data->{path}{'echo'}." return_code:\$?";
	if ($target)
	{
		### WARNING: Exposes passwords
		# Remote call.
		$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
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
		### WARNING: Exposes passwords
		# Local call
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
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
		
		if ($line =~ /^return_code:(\d+)$/)
		{
			$return_code = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code, 
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This changes the password for a shell user account.
sub change_shell_user_password
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "change_shell_user_password" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $user         = $parameter->{user}         ? $parameter->{user}         : "";
	my $new_password = $parameter->{new_password} ? $parameter->{new_password} : "";
	my $target       = $parameter->{target}       ? $parameter->{target}       : "";
	my $port         = $parameter->{port}         ? $parameter->{port}         : "";
	my $password     = $parameter->{password}     ? $parameter->{password}     : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "user",   value1 => $user, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "new_password", value1 => $new_password, 
		name2 => "password",     value2 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Do I have a user?
	if (not $user)
	{
		# Woops!
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0195", code => 195, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# OK, what about a password?
	if (not $new_password)
	{
		# Um...
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0196", message_variables => { user => $user }, code => 196, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Only the root user can do this!
	# $< == real UID, $> == effective UID
	if (($< != 0) && ($> != 0))
	{
		# Not root
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0197", message_variables => { user => $user }, code => 197, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Clean up the password for use in "".
	$new_password =~ s/"/\\\"/g;
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "new_password", value1 => $new_password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Still alive? Good!
	my $return_code = 255;
	my $return      = [];
	my $shell_call  = $an->data->{path}{'echo'}." \"$new_password\" | ".$an->data->{path}{passwd}." $user --stdin; ".$an->data->{path}{'echo'}." return_code:\$?";
	if ($target)
	{
		### WARNING: Exposes passwords
		# Remote call.
		$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
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
		### WARNING: Exposes passwords
		# Local call
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
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
		
		if ($line =~ /^return_code:(\d+)$/)
		{
			$return_code = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code, 
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

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
	
	my $new_file   = "";
	my $return     = [];
	my $start_time = time;
	my $i_am_a     = $an->Get->what_am_i();
	my $say_keep   = $keep             ? "--keep"  : "";
	my $say_small  = $i_am_a eq "node" ? "--small" : "";
	my $shell_call = "
if [ -e '$file' ];
then
    ".$an->data->{path}{bzip2}." --compress $say_keep $say_small $file; ".$an->data->{path}{'echo'}." rc:\$?
    if [ -e '".$file.".bz2' ];
    then
        ".$an->data->{path}{'echo'}." 'success:".$file.".bz2'
    else
        ".$an->data->{path}{'echo'}." 'compress failed'
    fi;
else
    ".$an->data->{path}{'echo'}." 'file not found'
fi";
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
			push @{$return}, $line;
		}
		close $file_handle;
	}
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /success:(.*)$/)
		{
			$new_file = $1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "new_file", value1 => $new_file, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	my $compress_time = time - $start_time;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "compress_time", value1 => $compress_time, 
	}, file => $THIS_FILE, line => __LINE__});
	
	return($new_file, $return);
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
	my $task         = $parameter->{task}         ? $parameter->{task}         : "";
	my $ipmi_ip      = $parameter->{ipmi_ip}      ? $parameter->{ipmi_ip}      : "";
	my $ipmi_netmask = $parameter->{ipmi_netmask} ? $parameter->{ipmi_netmask} : "";
	my $ipmi_user    = $parameter->{ipmi_user}    ? $parameter->{ipmi_user}    : "";
	my $ipmi_gateway = $parameter->{ipmi_gateway} ? $parameter->{ipmi_gateway} : "";
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
	
	# Do we have a task? It could be 'password', 'network' or 'both'
	if (not $task)
	{
		# Missing task.
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0231", code => 231, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	if (($task ne "password") && ($task ne "network") && ($task ne "both"))
	{
		# Invalid task
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0232", message_variables => { task => $task }, code => 232, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# If we're changing a password (no IP to set), 
	if ((($task eq "password") or ($task eq "both")) && (not $new_password))
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0194", code => 194, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Make sure I have a user, if I am setting a new password.
	if ((($task eq "password") or ($task eq "both")) && (not $ipmi_user))
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0233", code => 233, file => $THIS_FILE, line => __LINE__});
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
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "state", value1 => $state,
	}, file => $THIS_FILE, line => __LINE__});
	if ($state eq "undefined:7")
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
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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
				
				if ($line =~ /Invalid channel: /)
				{
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "channel",   value1 => $channel,
			name2 => "lan_found", value2 => $lan_found,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Now find the admin user ID number
		my $user_id = "";
		if ($lan_found)
		{
			# check to see if this is the correct channel
			my $shell_call  = $an->data->{path}{ipmitool}." user list $channel";
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
				$line =~ s/\s+/ /g;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "ipmi_user", value1 => $ipmi_user, 
					name2 => "line",      value2 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /^(\d+) $ipmi_user /)
				{
					$user_id = $1;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "user_id", value1 => $user_id,
					}, file => $THIS_FILE, line => __LINE__});
					last;
				}
			}
			
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "ipmi_user", value1 => $ipmi_user,
				name2 => "user_id",   value2 => $user_id,
			}, file => $THIS_FILE, line => __LINE__});
			if ($user_id =~ /^\d/)
			{
				# Set the password.
				my $return     = [];
				my $shell_call = $an->data->{path}{ipmitool}." user set password $user_id '$new_password'";
				if ($target)
				{
					# Remote call.
					$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
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
					$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
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
						$return_code = 0;
						$an->Log->entry({log_level => 2, message_key => "log_0130", message_variables => { target => $target }, file => $THIS_FILE, line => __LINE__});
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
						$an->Log->entry({log_level => 1, message_key => "log_0132", message_variables => { target => $target }, file => $THIS_FILE, line => __LINE__});
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
							$return_code = 0;
							$an->Log->entry({log_level => 2, message_key => "log_0133", message_variables => { target => $target }, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($line =~ /password incorrect/i)
						{
							# Password didn't take. :(
							$return_code = 1;
							$an->Log->entry({log_level => 1, message_key => "log_0132", message_variables => { target => $target }, file => $THIS_FILE, line => __LINE__});
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
		elsif ($user_id eq "")
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
	return($return_code);
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

### TODO: Shouldn't the s/'/\'/ be s/'/\\\'/ ?
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "token",  value1 => $token, 
			name2 => "output", value2 => $output, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Setup the job line
		my $time     =  time;
		my $run_time =  $time + $delay;
		my $job_line =  "$run_time:".$token.":$command";
		   $job_line =~ s/'/\'/g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call, 
			}, file => $THIS_FILE, line => __LINE__});
			open(my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				push @{$return}, $line;
			}
			close $file_handle;
		}
		else
		{
			# Remote call
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
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
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_daemon_state" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $daemon   = $parameter->{daemon}   ? $parameter->{daemon}   : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "daemon", value1 => $daemon, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
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
	my $shell_call = $an->data->{path}{initd}."/$daemon status &>/dev/null; ".$an->data->{path}{echo}." return_code:\$?";
	if ($target)
	{
		# Remote call.
		$an->Log->entry({log_level => 3, message_key => "log_0150", message_variables => {
			target => $target, 
			daemon => $daemon,
		}, file => $THIS_FILE, line => __LINE__});
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
		$an->Log->entry({log_level => 3, message_key => "log_0271", message_variables => { daemon => $daemon }, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
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
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "return_code", value1 => $return_code,
				name2 => "state",       value2 => $state,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "state", value1 => $state,
	}, file => $THIS_FILE, line => __LINE__});
	return($state);
}

# This returns an array reference containing local IPs.
sub get_local_ip_addresses
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_local_ip_addresses" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $in_device  = "";
	my $ip_list    = {};
	my $shell_call = $an->data->{path}{ip}." addr list";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
	while(<$file_handle>)
	{
		chomp;
		my $line = $an->String->clean_spaces({string => $_});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /\d+: (.*?): <BROADCAST/)
		{
			$in_device = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "in_device", value1 => $in_device, 
			}, file => $THIS_FILE, line => __LINE__});
			next;
		}
		
		if (($in_device) && ($line =~ /inet (\d+\.\d+\.\d+\.\d+)\/\d/))
		{
			$ip_list->{$in_device} = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "ip_list->$in_device", value1 => $ip_list->{$in_device}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	close $file_handle;
	
	return($ip_list);
}

# This returns the targets uptime expressed in seconds
sub get_uptime
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_uptime" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
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

# This looks at both nodes to see which should be shutdown first (when both are online). It returns "alone" 
# if the peer is not up or running cman/drbd, "none" when both are drbd synctarget, or one of the nodes 
# names. The selection criteria depends on a few things;
# 
# 1. If one node is the 'Inconsistent' or 'Diskless', it will be chosen. If both are this way, 'none' will be
#    returned.
# 
# 2. If one of the nodes is NOT in the cluster and the other is, the withdrawn one will be chosen.
# 
# 3. If both nodes are UpToDate, and one node's health is not 'OK', then the sick node will be chosen.
# 
# *If* not 'ignore_servers';
# 
# 4. If both nodes are UpToDate and healthy, the the sum of the RAM used by servers on each node is added. 
#    The node with the least amount of RAM used by servers is chosen.
#    
# 5. If the RAM in use by servers on both nodes is the same, the node with the fewest servers will be chosen.
# 
# 6. If no differences are found at all, node 2 will be chosen.
sub pick_shutdown_target
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "pick_shutdown_target" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid     = $parameter->{anvil_uuid}     ? $parameter->{anvil_uuid}     : "";
	my $ignore_servers = $parameter->{ignore_servers} ? $parameter->{ignore_servers} : 0;	# Set for cold-stop
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_uuid",     value1 => $anvil_uuid, 
		name2 => "ignore_servers", value2 => $ignore_servers, 
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $anvil_uuid)
	{
		$an->Alert->error({title_key => "error_title_0005", message_key => "error_message_0234", code => 234, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	my $target     = "";
	my $node1_name = $an->data->{sys}{anvil}{node1}{name};
	my $node1_uuid = $an->data->{sys}{anvil}{node1}{uuid};
	my $node2_name = $an->data->{sys}{anvil}{node2}{name};
	my $node2_uuid = $an->data->{sys}{anvil}{node2}{uuid};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node1_name", value1 => $node1_name, 
		name2 => "node1_uuid", value2 => $node1_uuid, 
		name3 => "node2_name", value3 => $node2_name, 
		name4 => "node2_uuid", value4 => $node2_uuid, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If either node's power is 'unknown', set to 'on' if 'online' was set. Otherwise, check manually.
	if ($an->data->{sys}{anvil}{node1}{power} eq "unknown")
	{
		if ($an->data->{sys}{anvil}{node1}{online})
		{
			$an->data->{sys}{anvil}{node1}{power} = "on";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "sys::anvil::node1::power", value1 => $an->data->{sys}{anvil}{node1}{power}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			$an->data->{sys}{anvil}{node1}{power} = $an->ScanCore->target_power({target => $node1_uuid});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "sys::anvil::node1::power", value1 => $an->data->{sys}{anvil}{node1}{power}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	if ($an->data->{sys}{anvil}{node2}{power} eq "unknown")
	{
		if ($an->data->{sys}{anvil}{node2}{online})
		{
			$an->data->{sys}{anvil}{node2}{power} = "on";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "sys::anvil::node2::power", value1 => $an->data->{sys}{anvil}{node2}{power}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			$an->data->{sys}{anvil}{node2}{power} = $an->ScanCore->target_power({target => $node2_uuid});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "sys::anvil::node2::power", value1 => $an->data->{sys}{anvil}{node2}{power}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If both nodes are off, or if either node can't be reached but is powered on, return 'none' (abort).
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "sys::anvil::node1::online", value1 => $an->data->{sys}{anvil}{node1}{online}, 
		name2 => "sys::anvil::node1::power",  value2 => $an->data->{sys}{anvil}{node1}{power}, 
		name3 => "sys::anvil::node2::online", value3 => $an->data->{sys}{anvil}{node2}{online}, 
		name4 => "sys::anvil::node2::power",  value4 => $an->data->{sys}{anvil}{node2}{power}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $an->data->{sys}{anvil}{node1}{online}) && (not $an->data->{sys}{anvil}{node2}{online}))
	{
		# Neither node is online. Are both known off?
		if (($an->data->{sys}{anvil}{node1}{power} eq "off") && ($an->data->{sys}{anvil}{node2}{power} eq "off"))
		{
			# Both nodes are off.
			$target = "none:both_off";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "target", value1 => $target, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# At least one node is not accessible but appears on. Abort.
			$target = "none:unknown_state";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "target", value1 => $target, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	elsif ((not $an->data->{sys}{anvil}{node1}{online}) && ($an->data->{sys}{anvil}{node1}{power} ne "off"))
	{
		# Node 1 is offline. but powered on, abort.
		$target = "none:unknown_state";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "target", value1 => $target, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ((not $an->data->{sys}{anvil}{node2}{online}) && ($an->data->{sys}{anvil}{node2}{power} ne "off"))
	{
		# Node 2 is offline. but powered on, abort.
		$target = "none:unknown_state";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "target", value1 => $target, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif (($an->data->{sys}{anvil}{node1}{power} eq "off") && ($an->data->{sys}{anvil}{node2}{online}))
	{
		# Node 1 is known off and node 2 is accessible.
		$target = "node2:".$an->data->{sys}{anvil}{node2}{name};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "target", value1 => $target, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif (($an->data->{sys}{anvil}{node2}{power} eq "off") && ($an->data->{sys}{anvil}{node1}{online}))
	{
		# Node 2 is known off and node 1 is accessible.
		$target = "node1:".$an->data->{sys}{anvil}{node1}{name};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "target", value1 => $target, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# 1. If one node is the 'Inconsistent' for the other, then the Inconsistent peer will be chosen.
	if (not $target)
	{
		if ((not $an->data->{node}{$node1_name}{drbd}{version}) && (not $an->data->{node}{$node2_name}{drbd}{version}))
		{
			# Neither node is running DRBD, shut down node 2.
			$target = "node2:".$an->data->{sys}{anvil}{node2}{name};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "target", value1 => $target, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (not $an->data->{node}{$node1_name}{drbd}{version})
		{
			# Node 1 is not running DRBD, stop it first.
			$target = "node1:".$an->data->{sys}{anvil}{node1}{name};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "target", value1 => $target, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (not $an->data->{node}{$node2_name}{drbd}{version})
		{
			# Node 2 is not running DRBD, stop it first.
			$target = "node2:".$an->data->{sys}{anvil}{node2}{name};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "target", value1 => $target, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Look to see if any resource is Inconsistent on either node
			my $node1_is_source = 0;
			my $node2_is_source = 0;
			
			# Node 1's perspective
			foreach my $resource (sort {$a cmp $b} keys %{$an->data->{node}{$node1_name}{drbd}{resource}})
			{
				my $node1_disk_state = $an->data->{node}{$node1_name}{drbd}{resource}{$resource}{my_disk_state};
				my $node2_disk_state = $an->data->{node}{$node1_name}{drbd}{resource}{$resource}{peer_disk_state};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node1_disk_state", value1 => $node1_disk_state, 
					name2 => "node2_disk_state", value2 => $node2_disk_state, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if (($node1_disk_state =~ /Inconsistent/i) or ($node1_disk_state =~ /Diskless/i))
				{
					$node2_is_source = 1;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "node2_is_source", value1 => $node2_is_source, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				if (($node2_disk_state =~ /Inconsistent/i) or ($node2_disk_state =~ /Diskless/i))
				{
					$node1_is_source = 1;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "node1_is_source", value1 => $node1_is_source, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			# Node 2's perspective
			foreach my $resource (sort {$a cmp $b} keys %{$an->data->{node}{$node2_name}{drbd}{resource}})
			{
				my $node1_disk_state = $an->data->{node}{$node2_name}{drbd}{resource}{$resource}{peer_disk_state};
				my $node2_disk_state = $an->data->{node}{$node2_name}{drbd}{resource}{$resource}{my_disk_state};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node1_disk_state", value1 => $node1_disk_state, 
					name2 => "node2_disk_state", value2 => $node2_disk_state, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if (($node1_disk_state =~ /Inconsistent/i) or ($node1_disk_state =~ /Diskless/i))
				{
					$node2_is_source = 1;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "node2_is_source", value1 => $node2_is_source, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				if (($node2_disk_state =~ /Inconsistent/i) or ($node2_disk_state =~ /Diskless/i))
				{
					$node1_is_source = 1;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "node1_is_source", value1 => $node1_is_source, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			
			# If both are syncsource, return 'none'
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "node1_is_source", value1 => $node1_is_source, 
				name2 => "node2_is_source", value2 => $node2_is_source, 
			}, file => $THIS_FILE, line => __LINE__});
			if (($node1_is_source) && ($node2_is_source))
			{
				# Both are needed to operate
				$target = "none:both_drbdsource";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "target", value1 => $target, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($node1_is_source)
			{
				# Node 1 is needed, shut down node 2 first.
				$target = "node2:".$an->data->{sys}{anvil}{node2}{name};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "target", value1 => $target, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($node2_is_source)
			{
				# Node 2 is needed, shut down node 1 first.
				$target = "node1:".$an->data->{sys}{anvil}{node1}{name};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "target", value1 => $target, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# 2. If one of the nodes is NOT in the cluster and the other is, the withdrawn one will be chosen.
	if (not $target)
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node1_name", value1 => $node1_name, 
			name2 => "node2_name", value2 => $node2_name, 
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{node}{$node1_name}{daemon}{cman}{exit_code} ne "0") && ($an->data->{node}{$node2_name}{daemon}{cman}{exit_code} ne "0"))
		{
			# Neither node is in the cluster, shut down node 2 first.
			$target = "node2:".$node2_name;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "target", value1 => $target, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($an->data->{node}{$node1_name}{daemon}{cman}{exit_code} ne "0")
		{
			# Node 1 is in the cluster, node 2 isn't. Withdraw node 2.
			$target = "node2:".$node2_name;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "target", value1 => $target, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($an->data->{node}{$node2_name}{daemon}{cman}{exit_code} ne "0")
		{
			# Node 2 is in the cluster, node 1 isn't. Withdraw node 1.
			$target = "node1:".$node1_name;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "target", value1 => $target, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# 3. If both nodes are UpToDate, and one node's health is not 'OK', then the sick node will be chosen.
	if (not $target)
	{
		### TODO: Switch this to using the 'health' ScanCore table.
		# Read in the node health score.
		my $node1_health = $an->ScanCore->get_node_health({target => $node1_name});
		my $node2_health = $an->ScanCore->get_node_health({target => $node2_name});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node1_health", value1 => $node1_health, 
			name2 => "node2_health", value2 => $node2_health, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($node1_health > $node2_health)
		{
			# Node 1 is healthier
			$target = "node1:".$node1_name;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "target", value1 => $target, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($node2_health > $node1_health)
		{
			# Node 2 is healthier
			$target = "node2:".$node2_name;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "target", value1 => $target, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	if (not $target)
	{
		if ($ignore_servers)
		{
			# No selection criteria helped, so set node 2.
			$target = "node2:".$node2_name;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "target", value1 => $target, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			### We're NOT ignoring servers.
			# 4. If both nodes are UpToDate and healthy, the the sum of the RAM used by servers on each node is added. 
			#    The node with the least amount of RAM used by servers is chosen.
			my $node1_ram          = 0;
			my $node1_server_count = 0;
			my $node2_ram          = 0;
			my $node2_server_count = 0;
			foreach my $server (sort {$a cmp $b} keys %{$an->data->{server}})
			{
				my $ram  = $an->data->{server}{$server}{details}{ram};
				my $host = $an->data->{server}{$server}{host};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "server", value1 => $server,
					name2 => "ram",    value2 => $ram." (".$an->Readable->bytes_to_hr({'bytes' => $ram}).")",
					name3 => "host",   value3 => $host,
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($host eq $node1_name)
				{
					$node1_ram += $ram;
					$node1_server_count++;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "node1_ram",          value1 => $node1_ram." (".$an->Readable->bytes_to_hr({'bytes' => $node1_ram}).")",
						name2 => "node1_server_count", value2 => $node1_server_count,
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($host eq $node2_name)
				{
					$node2_ram += $ram;
					$node2_server_count++;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "node2_ram",          value1 => $node2_ram." (".$an->Readable->bytes_to_hr({'bytes' => $node2_ram}).")",
						name2 => "node2_server_count", value2 => $node2_server_count,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			
			# Does one node have more RAM in use by hosted servers than the other?
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "node1_ram", value1 => $node1_ram." (".$an->Readable->bytes_to_hr({'bytes' => $node1_ram}).")",
				name2 => "node2_ram", value2 => $node2_ram." (".$an->Readable->bytes_to_hr({'bytes' => $node2_ram}).")",
			}, file => $THIS_FILE, line => __LINE__});
			if ($node1_ram > $node2_ram)
			{
				# Node 1 has more RAM used by node 2, so nix node 2.
				$target = "node2:".$node2_name;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "target", value1 => $target, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($node2_ram > $node1_ram)
			{
				# Node 1 has more RAM used by node 2, so nix node 2.
				$target = "node1:".$node1_name;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "target", value1 => $target, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			# Does one node have more servers than the other?
			if (not $target)
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node1_server_count", value1 => $node1_server_count,
					name2 => "node2_server_count", value2 => $node2_server_count,
				}, file => $THIS_FILE, line => __LINE__});
				if ($node1_server_count > $node2_server_count)
				{
					# Node 1 has more RAM used by node 2, so nix node 2.
					$target = "node2:".$node2_name;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "target", value1 => $target, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($node2_server_count > $node1_server_count)
				{
					# Node 1 has more RAM used by node 2, so nix node 2.
					$target = "node1:".$node1_name;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "target", value1 => $target, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			
			# 5. Finally; If I still don't have a target, set node 2.
			if (not $target)
			{
				$target = "node2:".$node2_name;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "target", value1 => $target, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# none:both_off        = Both were off
	# none:unknown_state   = One or both of the nodes couldn't be accessed and aren't powered off (or the
	#                        power state is unknown)
	# none:both_drbdsource = Both nodes are acting as SyncSource for one or more resources (or one or 
	#                        more peer resource's disk state is Diskless).
	# node1:<node_name>    = Node 1 was was chosed to turn off first.
	# node2:<node_name>    = Node 2 was was chosed to turn off first.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "target", value1 => $target, 
	}, file => $THIS_FILE, line => __LINE__});
	return($target);
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
