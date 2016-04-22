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

# This calls 'poweroff' on a machine (possibly this one).
sub poweroff
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
	
	my $shell_call = $an->data->{path}{poweroff}." --verbose";
	my $return     = [];
	
	# If the 'target' is set, we'll call over SSH unless 'target' is 'local' or our hostname.
	if (($target) && ($target ne "local") && ($target ne $an->hostname) && ($target ne $an->short_hostname))
	{
		### Remote calls
		# Stop rgmanager
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
		### Local calls
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or die "Failed to call: [$shell_call], error was: $!\n";
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
