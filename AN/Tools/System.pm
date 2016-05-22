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
# daemon_boot_config
# poweroff


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

# This checks/sets whether a daemon is set to start on boot or not.
sub daemon_boot_config
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "daemon_boot_config" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	if (not $parameter->{daemon})
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0162", code => 162, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	my $daemon   = $parameter->{daemon}   ? $parameter->{daemon}   : "";
	my $set      = $parameter->{set}      ? $parameter->{set}      : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
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
		$an->Alert->error({fatal => 1, title_key => "error_title_0005", message_key => "error_message_0163", message_variables => { set => $set }, code => 163, file => "$THIS_FILE", line => __LINE__});
		return("");
	}
	
	# If I have a host, we're checking the daemon state on a remote system.
	my $return = [];
	my $state  = {
		0 => "unknown",
		1 => "unknown",
		2 => "unknown",
		3 => "unknown",
		4 => "unknown",
		5 => "unknown",
		6 => "unknown",
	};
	my $shell_call = $an->data->{path}{chkconfig}." --list $daemon";
	if ($set)
	{
		$shell_call = $an->data->{path}{chkconfig}." $daemon $set; ".$an->data->{path}{chkconfig}." --list $daemon";
	}
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
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
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "state", value1 => $state, 
	}, file => $THIS_FILE, line => __LINE__});
	return($state);
}


### TODO: Set the stop reason
# This calls 'poweroff' on a machine (possibly this one).
sub poweroff
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "poweroff" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
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
		print "poweroff: $target\n";
		
		### Local calls
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => "$THIS_FILE", line => __LINE__});
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		$output .= "$line\n";
	}
	
	return($output);
}


#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

1;
