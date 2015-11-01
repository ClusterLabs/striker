package AN::Tools::Remote;

use strict;
use warnings;
use Net::SSH2;

our $VERSION    = "0.1.001";
my $THIS_FILE   = "Remote.pm";
my $THIS_MODULE = "AN::Tools::Remote";

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

# This does a remote call over SSH.
sub remote_call
{
	my $self      = shift;
	my $parameter = shift;
	
	my $an        = $self->parent;
	
	my $target     = $parameter->{target};
	my $port       = $parameter->{port}             ? $parameter->{port}     : 22;
	my $user       = $parameter->{user}             ? $parameter->{user}     : "root";
	my $password   = $parameter->{password}         ? $parameter->{password} : $an->data->{sys}{root_password};
	my $ssh_fh     = $parameter->{ssh_fh}           ? $parameter->{ssh_fh}   : "";
	my $close      = defined $parameter->{'close'}  ? $parameter->{'close'}  : 1;
	my $shell_call = $parameter->{shell_call};
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "port",       value2 => $port,
		name3 => "user",       value3 => $user,
		name4 => "password",   value4 => $password,
		name5 => "ssh_fh",     value5 => $ssh_fh,
		name6 => "close",      value6 => $close,
 		name7 => "shell_call", value7 => $shell_call,

	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: Make this a better looking error.
	if (not $target)
	{
		# No target...
		$an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_message_0026", message_variables => {
			method	=>	$THIS_MODULE."->remote_call()",
			target	=>	$target, 
		}});
	}
	
	# Break out the port, if needed.
	my $state;
	my $error;
	if ($target =~ /^(.*):(\d+)$/)
	{
		$target = $1;
		$port = $2;
		if (($port < 0) || ($port > 65536))
		{
			# Variables for 'message_0373'.
			$an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_message_0025", message_variables => {
				target	=>	$target, 
				port	=>	"$port",
			}});
		}
	}
	else
	{
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
	
	# These will be merged into a single 'output' array before returning.
	my $stdout_output = [];
	my $stderr_output = [];
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "ssh_fh", value1 => $ssh_fh, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($ssh_fh !~ /^Net::SSH2/)
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "user",   value1 => $user, 
			name2 => "target", value1 => $target, 
			name3 => "port",   value1 => $port, 
		}, file => $THIS_FILE, line => __LINE__});
		$ssh_fh = Net::SSH2->new();
		if (not $ssh_fh->connect($target, $port, Timeout => 10))
		{
			$an->Log->entry({log_level => 1, message_key => "an_variables_0001", message_variables => {
				name1 => "error", value1 => $@, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($@ =~ /Bad hostname/)
			{
				# This is for the user
				$error = $an->String->get({key => "error_message_0027", variables => {
						target	=>	$target,
					},
				});
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
					},
				});
				# This is for our logs
				$an->Log->entry({log_level => 1, message_key => "error_message_0028", message_variables => {
					target	=>	$target,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($@ =~ /No route to host/)
			{
				# This is for the user
				$error = $an->String->get({key => "error_message_0029", variables => {
						target	=>	$target,
					},
				});
				# This is for our logs
				$an->Log->entry({log_level => 1, message_key => "error_message_0029", message_variables => {
					target	=>	$target,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($@ =~ /timeout/)
			{
				# This is for the user
				$error = $an->String->get({key => "error_message_0030", variables => {
						target	=>	$target,
					},
				});
				# This is for our logs
				$an->Log->entry({log_level => 1, message_key => "error_message_0030", message_variables => {
					target	=>	$target,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# This is for the user
				$error = $an->String->get({key => "error_message_0031", variables => {
						target	=>	$target,
					},
				});
				# This is for our logs
				$an->Log->entry({log_level => 1, message_key => "error_message_0031", message_variables => {
					target	=>	$target,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "error",  value1 => $error, 
			name2 => "ssh_fh", value2 => $ssh_fh, 
		}, file => $THIS_FILE, line => __LINE__});
		if (not $error)
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "user",     value1 => $user, 
				name2 => "password", value2 => $password, 
			}, file => $THIS_FILE, line => __LINE__});
			if (not $ssh_fh->auth_password($user, $password)) 
			{
				# This is for the user
				$error = $an->String->get({key => "error_message_0032", variables => {
						target	=>	$target,
					},
				});
				# This is for our logs
				$an->Log->entry({log_level => 1, message_key => "error_message_0032", message_variables => {
					target	=>	$target,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				$an->Log->entry({log_level => 3, message_key => "notice_message_0004", message_variables => {
					target => $target, 
				}, file => $THIS_FILE, line => __LINE__});
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
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
		$an->Log->entry({log_level => 3, message_key => "notice_message_0005", message_variables => {
			target => $target, 
		}, file => $THIS_FILE, line => __LINE__});
		$ssh_fh->disconnect() if $ssh_fh;
		
		# For good measure, blank both variables.
		$an->data->{target}{$target}{ssh_fh} = "";
		$ssh_fh                              = "";
	}
	
	$error = "" if not defined $error;
	return($error, $ssh_fh, $output);
};

1;
