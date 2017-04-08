package AN::Tools::Remote;
# 
# This module contains methods used to handle accessing remote systems over SSH.
# 

use strict;
use warnings;
use Net::SSH2;

our $VERSION    = "0.1.001";
my $THIS_FILE   = "Remote.pm";
my $THIS_MODULE = "AN::Tools::Remote";

### Methods;
# add_rsa_key_to_target
# add_target_to_known_hosts
# generate_rsa_public_key
# remote_call
# wait_on_peer
# _call_ssh_keyscan
# _check_known_hosts_for_target


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

# This adds the given RSA key to the target machine and target user's authorized_keys file.
sub add_rsa_key_to_target
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "add_rsa_key_to_target" }, file => $THIS_FILE, line => __LINE__});
	
	# We don't try to divine the user, so we need to called to tell us who we're dealing with.
	my $user            = $parameter->{user};
	my $target          = $parameter->{target};
	my $port            = $parameter->{port} ? $parameter->{port} : 22;
	my $key             = $parameter->{key};
	my $key_owner       = $parameter->{key_owner};
	my $password        = $parameter->{password};
	my $users_home      = $an->Get->users_home({user => $user});
	my $authorized_keys = "$users_home/.ssh/authorized_keys";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0008", message_variables => {
		name1 => "user",            value1 => $user, 
		name2 => "target",          value2 => $target, 
		name3 => "port",            value3 => $port, 
		name4 => "key",             value4 => $key, 
		name5 => "key_owner",       value5 => $key_owner, 
		name6 => "password",        value6 => $password, 
		name7 => "users_home",      value7 => $users_home, 
		name8 => "authorized_keys", value8 => $authorized_keys,
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: WTF is this? I'm ssh'ing into the machine to ssh into itself to check the key?!
	# First, is the key already there?
	my $return_code = 0;
	my $shell_call  = $an->data->{path}{ssh}." $user\@$target \"".$an->data->{path}{'grep'}." -q 'ssh-rsa $key ' $authorized_keys; ".$an->data->{path}{echo}." rc:\\\$?\"";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port,
		password	=>	$password,
		'close'		=>	1,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		### TODO: Handle a rebuilt machine where the fingerprint no longer matches.
		next if not $line;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /rc:(\d+)$/)
		{
			# If the RC is 0, it exists.
			my $rc = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "rc", value1 => $rc, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($rc)
			{
				# Add it.
				my $shell_call = $an->data->{path}{ssh}." $user\@$target \"".$an->data->{path}{'echo'}." 'ssh-rsa $key $key_owner' >> $authorized_keys\"";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "shell_call", value1 => $shell_call, 
				}, file => $THIS_FILE, line => __LINE__});
				my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$target,
					port		=>	$port,
					password	=>	$password,
					'close'		=>	0,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					### TODO: Handle a rebuilt machine where the fingerprint no longer matches.
					next if not $line;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				
				# And verify.
				$shell_call = $an->data->{path}{ssh}." $user\@$target \"".$an->data->{path}{'grep'}." -q 'ssh-rsa $key ' $authorized_keys; ".$an->data->{path}{echo}." rc:\\\$?\"";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "shell_call", value1 => $shell_call, 
				}, file => $THIS_FILE, line => __LINE__});
				($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$target,
					port		=>	$port,
					password	=>	$password,
					'close'		=>	1,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					### TODO: Handle a rebuilt machine where the fingerprint no longer matches.
					next if not $line;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
					if ($line =~ /rc:(\d+)$/)
					{
						# If the RC is 0, it exists.
						my $rc = $1;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "rc", value1 => $rc, 
						}, file => $THIS_FILE, line => __LINE__});
						if ($rc)
						{
							# Failed
							$return_code = 1;
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => "return_code", value1 => $return_code, 
							}, file => $THIS_FILE, line => __LINE__});
						}
						else
						{
							# Succeed.
							$return_code = 2;
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => "return_code", value1 => $return_code, 
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
				}
			}
		}
	}
	
	# 0 == Existed
	# 1 == Failed to add
	# 2 == Added successfully
	return($return_code);
}

# This checks the current user's 'known_hosts' file for the presence of a given host and, if not found, uses
# 'ssh-keyscan' to add the host.
sub add_target_to_known_hosts
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "add_target_to_known_hosts" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target          = $parameter->{target};
	my $port            = $parameter->{port}            ? $parameter->{port}            : 22;
	my $user            = $parameter->{user}            ? $parameter->{user}            : $<; 
	my $delete_if_found = $parameter->{delete_if_found} ? $parameter->{delete_if_found} : 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "target",          value1 => $target,
		name2 => "port",            value2 => $port,
		name3 => "user",            value3 => $user,
		name4 => "delete_if_found", value4 => $delete_if_found,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Get the local user's home
	my $users_home = $an->Get->users_home({user => $user});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "users_home", value1 => $users_home,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $users_home)
	{
		# No sense proceeding... An error will already have been recorded.
		return("");
	}
	
	# I'll need to make sure I've seen the fingerprint before.
	my $known_hosts = "$users_home/.ssh/known_hosts";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "known_hosts", value1 => $known_hosts, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# OK, now do we have a 'known_hosts' at all?
	my $known_machine = 0;
	if (-e $known_hosts)
	{
		# Yup, see if the target is there already,
		$known_machine = $an->Remote->_check_known_hosts_for_target({
			target          => $target, 
			port            => $port, 
			known_hosts     => $known_hosts, 
			user            => $user,
			delete_if_found => $delete_if_found,
		});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "known_machine", value1 => $known_machine, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# If either known_hosts didn't contain this target or simply didn't exist, add it.
	if (not $known_machine)
	{
		# We don't know about this machine yet, so scan it.
		my $added = $an->Remote->_call_ssh_keyscan({
			target      => $target, 
			port        => $port, 
			user        => $user, 
			known_hosts => $known_hosts});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "added", value1 => $added, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Verify
		$known_machine = $an->Remote->_check_known_hosts_for_target({
			target          => $target, 
			port            => $port, 
			known_hosts     => $known_hosts,
			user            => $user,
			delete_if_found => $delete_if_found,
		});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "known_machine", value1 => $known_machine, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($known_machine)
		{
			# Successfully added!
			$an->Log->entry({log_level => 2, message_key => "notice_message_0009", message_variables => {
				target => $target, 
				port   => $port, 
				user   => $user, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Failed to add. :(
			$an->Alert->warning({message_key => "warning_title_0007", message_variables => {
				target => $target, 
				port   => $port, 
				user   => $user, 
			}, quiet => 1, file => $THIS_FILE, line => __LINE__});
			return(1);
		}
	}
	
	return(0);
}

# This generates an RSA key for the user.
sub generate_rsa_public_key
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "generate_rsa_public_key" }, file => $THIS_FILE, line => __LINE__});
	
	# We don't try to divine the user, so we need to called to tell us who we're dealing with.
	my $user             = $parameter->{user};
	my $key_size         = $parameter->{key_size} ? $parameter->{key_size} : 8191;
	my $home             = $an->Get->users_home({user => $user});
	my $rsa_private_file = "${home}/.ssh/id_rsa";
	my $rsa_public_file  = "${rsa_private_file}.pub";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
		name1 => "user",             value1 => $user, 
		name2 => "home",             value2 => $home,
		name3 => "key_size",         value3 => $key_size,
		name4 => "rsa_private_file", value4 => $rsa_private_file,
		name5 => "rsa_public_file",  value5 => $rsa_public_file,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Log that this can take time and then make the call.
	$an->Log->entry({log_level => 3, message_key => "notice_message_0006", file => $THIS_FILE, line => __LINE__});
	my $shell_call  = "
".$an->data->{path}{'ssh-keygen'}." -t rsa -N \"\" -b $key_size -f $rsa_private_file
".$an->data->{path}{'chown'}." $user:$user $rsa_private_file
".$an->data->{path}{'chown'}." $user:$user $rsa_public_file
".$an->data->{path}{'chmod'}." 600 $rsa_private_file
".$an->data->{path}{'chown'}." 644 $rsa_public_file
";
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
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "rsa_private_file", value1 => $rsa_private_file, 
		name2 => "rsa_public_file",  value2 => $rsa_public_file,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Did it work?
	my $ok = 0;
	if (-e $rsa_private_file)
	{
		# Yup!
		$ok = 1;
		$an->Log->entry({log_level => 3, message_key => "notice_message_0007", message_variables => {
			user => $user, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Failed, tell the user.
		$an->Alert->warning({message_key => "warning_title_0005", message_variables => { user => $user }, quiet => 1, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok, 
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This does a remote call over SSH. The connection is held open and the file handle for the target is cached
# and re-used unless a specific ssh_fh is passed or a request to close the connection is received. 
sub remote_call
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "remote_call" }, file => $THIS_FILE, line => __LINE__});
	
	# Get the target and port so that we can create the ssh_fh key
	my $target     = $parameter->{target};
	my $port       = $parameter->{port} ? $parameter->{port} : 22;
	my $ssh_fh_key = $target.":".$port;
	
	# This will store the SSH file handle for the given target after the initial connection.
	$an->data->{target}{$ssh_fh_key}{ssh_fh} = defined $an->data->{target}{$ssh_fh_key}{ssh_fh} ? $an->data->{target}{$ssh_fh_key}{ssh_fh} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "target::${ssh_fh_key}::ssh_fh", value1 => $an->data->{target}{$ssh_fh_key}{ssh_fh},
	}, file => $THIS_FILE, line => __LINE__});
	
	# Now pick up the rest of the variables.
	my $user       =         $parameter->{user}       ? $parameter->{user}       : "root";
	my $password   =         $parameter->{password}   ? $parameter->{password}   : $an->data->{sys}{root_password};
	my $ssh_fh     =         $parameter->{ssh_fh}     ? $parameter->{ssh_fh}     : $an->data->{target}{$ssh_fh_key}{ssh_fh};
	my $close      = defined $parameter->{'close'}    ? $parameter->{'close'}    : 0;
	my $shell_call =         $parameter->{shell_call};
	my $start_time = time;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
		name1 => "start_time", value1 => $start_time,
		name2 => "target",     value2 => $target,
		name3 => "port",       value3 => $port,
		name4 => "user",       value4 => $user,
		name5 => "ssh_fh_key", value5 => $ssh_fh_key,
		name6 => "ssh_fh",     value6 => $ssh_fh,
		name7 => "close",      value7 => $close,
	}, file => $THIS_FILE, line => __LINE__});
	# Shell calls can expose passwords, which is why it is down here.
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "password",   value1 => $password,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: Make this a better looking error.
	if (not $target)
	{
		# No target...
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0174", code => 174, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Break out the port, if needed.
	my $state;
	my $error;
	if ($target =~ /^(.*):(\d+)$/)
	{
		$target = $1;
		$port   = $2;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "target", value1 => $target,
			name2 => "port",   value2 => $port,
		}, file => $THIS_FILE, line => __LINE__});
		if (($port < 0) or ($port > 65536))
		{
			$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0175", message_variables => {
				target	=>	$target, 
				port	=>	"$port",
			}, code => 175, file => $THIS_FILE, line => __LINE__});
			return("");
		}
	}
	else
	{
		### TODO: Determine if this is still worth having now that everything has been moved to the 
		###       ScanCore database.
		# In case the user is using ports in /etc/ssh/ssh_config, we'll want to check for an entry.
		$an->Storage->read_ssh_config();
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "hosts::${target}::port", value1 => $an->data->{hosts}{$target}{port}, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{hosts}{$target}{port})
		{
			$port = $an->data->{hosts}{$target}{port};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "port", value1 => $port, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If the target is a host name, convert it to an IP.
	if (not $an->Validate->is_ipv4({ip => $target}))
	{
		my $new_target = $an->Get->ip_from_hostname({host_name => $target});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "new_target", value1 => $new_target, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($new_target)
		{
			$target = $new_target;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "target", value1 => $target, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# No luck, this will probably fail.
		}
	}
	
	# These will be merged into a single 'output' array before returning.
	my $stdout_output = [];
	my $stderr_output = [];
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "ssh_fh", value1 => $ssh_fh, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If I don't already have an active SSH file handle, connect now.
	if ($ssh_fh !~ /^Net::SSH2/)
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "user",       value1 => $user, 
			name2 => "target",     value2 => $target, 
			name3 => "port",       value3 => $port, 
			name4 => "shell_call", value4 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		
		$ssh_fh = Net::SSH2->new();
		if (not $ssh_fh->connect($target, $port, Timeout => 10))
		{
			$an->Log->entry({log_level => 1, message_key => "an_variables_0005", message_variables => {
				name1 => "user",       value1 => $user, 
				name2 => "target",     value2 => $target, 
				name3 => "port",       value3 => $port, 
				name4 => "shell_call", value4 => $shell_call,
				name5 => "error",      value5 => $@, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($@ =~ /Bad hostname/)
			{
				# This is for the user
				$error = $an->String->get({key => "error_message_0027", variables => { target => $target }});
				# This is for our logs
				$an->Log->entry({log_level => 1, message_key => "error_message_0027", message_variables => {
					target	=>	$target,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($@ =~ /Connection refused/)
			{
				# This is for the user
				$error = $an->String->get({key => "error_message_0028", variables => {
						target	=>	$target,
						port	=>	$port,
						user	=>	$user,
					},
				});
				# This is for our logs
				$an->Log->entry({log_level => 1, message_key => "error_message_0028", message_variables => { target => $target }, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($@ =~ /No route to host/)
			{
				# This is for the user
				$error = $an->String->get({key => "error_message_0029", variables => { target => $target }});
				# This is for our logs
				$an->Log->entry({log_level => 1, message_key => "error_message_0029", message_variables => { target => $target }, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($@ =~ /timeout/)
			{
				# This is for the user
				$error = $an->String->get({key => "error_message_0030", variables => { target => $target }});
				# This is for our logs
				$an->Log->entry({log_level => 1, message_key => "error_message_0030", message_variables => { target => $target }, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# This is for the user
				$error = $an->String->get({key => "error_message_0031", variables => { target => $target }});
				# This is for our logs
				$an->Log->entry({log_level => 1, message_key => "error_message_0031", message_variables => { target => $target }, file => $THIS_FILE, line => __LINE__});
			}
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "error",  value1 => $error, 
			name2 => "ssh_fh", value2 => $ssh_fh, 
		}, file => $THIS_FILE, line => __LINE__});
		if (not $error)
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "user", value1 => $user, 
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
				name1 => "password", value1 => $password, 
			}, file => $THIS_FILE, line => __LINE__});
			if (not $ssh_fh->auth_password($user, $password)) 
			{
				# Can we log in without a password?
				my $public_key  = $an->Get->users_home({user => getpwuid($<)})."/.ssh/id_rsa.pub";
				my $private_key = $an->Get->users_home({user => getpwuid($<)})."/.ssh/id_rsa";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "public_key",  value1 => $public_key, 
					name2 => "private_key", value2 => $private_key, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($ssh_fh->auth_publickey($user, $public_key, $private_key)) 
				{
					# We're in! Record the file handle for this target.
					$an->data->{target}{$ssh_fh_key}{ssh_fh} = $ssh_fh;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "target::${ssh_fh_key}::ssh_fh", value1 => $an->data->{target}{$ssh_fh_key}{ssh_fh}, 
					}, file => $THIS_FILE, line => __LINE__});
					
					$an->Log->entry({log_level => 2, message_key => "notice_message_0014", message_variables => { target => $ssh_fh_key }, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# This is for the user
					$error = $an->String->get({key => "error_message_0032", variables => { target => $ssh_fh_key }});
					# This is for our logs
					$an->Log->entry({log_level => 1, message_key => "error_message_0032", message_variables => { target => $ssh_fh_key }, file => $THIS_FILE, line => __LINE__});
				}
			}
			else
			{
				# We're in! Record the file handle for this target.
				$an->data->{target}{$ssh_fh_key}{ssh_fh} = $ssh_fh;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "target::${ssh_fh_key}::ssh_fh", value1 => $an->data->{target}{$ssh_fh_key}{ssh_fh}, 
				}, file => $THIS_FILE, line => __LINE__});
				
				$an->Log->entry({log_level => 2, message_key => "notice_message_0004", message_variables => { target => $ssh_fh_key }, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	### Special thanks to Rafael Kitover (rkitover@gmail.com), maintainer of Net::SSH2, for helping me
	### sort out the polling and data collection in this section.
	#
	# Open a channel and make the call.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "error",  value1 => $error, 
		name2 => "ssh_fh", value2 => $ssh_fh, 
	}, file => $THIS_FILE, line => __LINE__});
	if (($ssh_fh =~ /^Net::SSH2/) && (not $error))
	{
		# We need to open a channel every time for 'exec' calls. We want to keep blocking off, but we
		# need to enable it for the channel() call.
		   $ssh_fh->blocking(1);
		my $channel = $ssh_fh->channel();
		   $ssh_fh->blocking(0);
		
		# Make the shell call
		if (not $channel)
		{
			# ... or not.
			$error = $an->String->get({key => "error_message_0033", variables => {
					target		=>	$target,
					shell_call	=>	$shell_call
				},
			});
			$ssh_fh = "";
		}
		else
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "channel",    value1 => $channel, 
				name2 => "shell_call", value2 => $shell_call, 
			}, file => $THIS_FILE, line => __LINE__});
			$channel->exec("$shell_call");
			
			# This keeps the connection open when the remote side is slow to return data, like in
			# '/etc/init.d/rgmanager stop'.
			my @poll = {
				handle => $channel,
				events => [qw/in err/],
			};
			
			# We'll store the STDOUT and STDERR data here.
			my $stdout = "";
			my $stderr = "";
			
			# Not collect the data.
			while(1)
			{
				$ssh_fh->poll(250, \@poll);
				
				# Read in anything from STDOUT
				while($channel->read(my $chunk, 80))
				{
					$stdout .= $chunk;
				}
				while ($stdout =~ s/^(.*)\n//)
				{
					my $line = $1;
					   $line =~ s/\r//g;	# Remove \r from things like output of daemon start/stops.
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "STDOUT line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
					push @{$stdout_output}, $line;
				}
				
				# Read in anything from STDERR
				while($channel->read(my $chunk, 80, 1))
				{
					$stderr .= $chunk;
				}
				while ($stderr =~ s/^(.*)\n//)
				{
					my $line = $1;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "STDERR line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
					push @{$stderr_output}, $line;
				}
				
				# Exit when we get the end-of-file.
				last if $channel->eof;
			}
			if ($stdout)
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "stdout", value1 => $stdout, 
				}, file => $THIS_FILE, line => __LINE__});
				push @{$stdout_output}, $stdout;
			}
			if ($stderr)
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "stderr", value1 => $stderr, 
				}, file => $THIS_FILE, line => __LINE__});
				push @{$stderr_output}, $stderr;
			}
		}
	}
	
	# Merge the STDOUT and STDERR
	my $output = [];
	
	foreach my $line (@{$stderr_output}, @{$stdout_output})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		push @{$output}, $line;
	}
	
	# Close the connection if requested.
	if ($close)
	{
		$an->Log->entry({log_level => 2, message_key => "notice_message_0005", message_variables => { target => $ssh_fh_key }, file => $THIS_FILE, line => __LINE__});
		$ssh_fh->disconnect() if $ssh_fh;
		
		# For good measure, blank both variables.
		$an->data->{target}{$ssh_fh_key}{ssh_fh} = "";
		$ssh_fh                                  = "";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "target::${ssh_fh_key}::ssh_fh", value1 => $an->data->{target}{$ssh_fh_key}{ssh_fh}, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$error = "" if not defined $error;
	return($error, $ssh_fh, $output);
};

# This will wait for a bit, then check to see if node 1 is running the passed-in program. If it is, it will 
# keep waiting until it exits. If it isn't, it will run without further delay.
sub wait_on_peer
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "wait_on_peer" }, file => $THIS_FILE, line => __LINE__});
	
	if (not $parameter->{program})
	{
		# Throw an error and exit.
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0096", code => 96, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	if (not $parameter->{target})
	{
		# Throw an error and exit.
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0097", code => 97, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	my $program  = $parameter->{program}  ? $parameter->{program}  : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	### NOTE: Customer requested, move to 2 before v2.0 release
	$an->Log->entry({log_level => 1, message_key => "an_variables_0003", message_variables => {
		name1 => "program", value1 => $program, 
		name2 => "target",  value2 => $target, 
		name3 => "port",    value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});

	### TODO: Change this; Wait until we can reach node 1, sleep 30 seconds, then go into a loop that
	###       waits while this program is running on the peer. Once it is done, we'll run as a 
	###       precaution.
	sleep 30;
	my $pids = $an->Get->pids({
		program_name	=>	$program, 
		target		=>	$target, 
		password	=>	$password,
		port		=>	$port,
	});
	my $count = @{$pids};
	if (not $count)
	{
		# It still isn't running, so we probably booted while the peer didn't.
		$an->Log->entry({log_level => 1, message_key => "tools_log_0030", message_variables => { program => $program }, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Wait for it to finish.
		my $wait = 1;
		while ($wait)
		{
			my $pids = $an->Get->pids({
				program_name	=>	$program, 
				target		=>	$target, 
				password	=>	$password,
				port		=>	$port,
			});
			my $count = @{$pids};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "count", value1 => $count, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($count)
			{
				$an->Log->entry({log_level => 1, message_key => "tools_log_0031", message_variables => { 
					program => $program,
					peer    => $target,
				}, file => $THIS_FILE, line => __LINE__});
				sleep 10;
			}
			else
			{
				# We're done waiting.
				$wait = 0;
				$an->Log->entry({log_level => 1, message_key => "tools_log_0032", message_variables => { program => $program }, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return(0);
}


#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

# This calls 'ssh-keyscan' to add a remote machine's fingerprint to the local user's list of known_hosts.
sub _call_ssh_keyscan
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $target      = $parameter->{target};
	my $port        = $parameter->{port};
	my $user        = $parameter->{user}; 
	my $known_hosts = $parameter->{known_hosts};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_call_ssh_keyscan" }, message_key => "an_variables_0004", message_variables => { 
		name1 => "target",      value1 => $target,
		name2 => "port",        value2 => $port,
		name3 => "user",        value3 => $user,
		name4 => "known_hosts", value4 => $known_hosts,
	}, file => $THIS_FILE, line => __LINE__});

	$an->Log->entry({log_level => 2, message_key => "notice_message_0010", message_variables => {
		target => $target, 
		port   => $port, 
		user   => $user, 
	}, file => $THIS_FILE, line => __LINE__});
	my $shell_call = $an->data->{path}{'ssh-keyscan'}." $target >> $known_hosts";
	if (($port) && ($port ne "22"))
	{
		$shell_call = $an->data->{path}{'ssh-keyscan'}." -p $port $target >> $known_hosts";
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
	}
	close $file_handle;
	
	# Set the ownership
	$shell_call = $an->data->{path}{'chown'}." $user:$user $known_hosts";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open ($file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
	}
	close $file_handle;
	
	return(0);
}

# This checks to see if a given target machine is in the user's known_hosts file.
sub _check_known_hosts_for_target
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_check_known_hosts_for_target" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target          = $parameter->{target}          ? $parameter->{target}          : "";
	my $port            = $parameter->{port}            ? $parameter->{port}            : "";
	my $known_hosts     = $parameter->{known_hosts}     ? $parameter->{known_hosts}     : "";
	my $user            = $parameter->{user}            ? $parameter->{user}            : $<;
	my $delete_if_found = $parameter->{delete_if_found} ? $parameter->{delete_if_found} : 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
		name1 => "target",          value1 => $target,
		name2 => "port",            value2 => $port,
		name3 => "known_hosts",     value3 => $known_hosts,
		name4 => "user",            value4 => $user,
		name5 => "delete_if_found", value5 => $delete_if_found,
	}, file => $THIS_FILE, line => __LINE__});
	
	# read it in and search.
	my $known_machine = 0;
	my $shell_call    = $known_hosts;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "<$shell_call") or $an->Alert->error({title_key => "an_0003", message_key => "error_title_0016", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => $THIS_FILE, line => __LINE__});
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		if (($line =~ /$target ssh-rsa /) or ($line =~ /\[$target\]:$port ssh-rsa /))
		{
			# We already know this machine (or rather, we already have a fingerprint for
			# this machine).
			$known_machine = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "known_machine", value1 => $known_machine, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	close $file_handle;
	
	if ($delete_if_found)
	{
		### NOTE: It appears the port is not needed.
		# If we have a non-digit user, run this through 'su.
		my $shell_call = $an->data->{path}{'ssh-keygen'}." -R $target";
		if (($user) && ($user =~ /\D/))
		{
			$shell_call = $an->data->{path}{su}." - $user -c '".$an->data->{path}{'ssh-keygen'}." -R $target'";
		}
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
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "known_machine", value1 => $known_machine, 
	}, file => $THIS_FILE, line => __LINE__});
	return($known_machine);
}

1;
