package AN::Tools::Check;

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Check.pm";


# The constructor
sub new
{
	#print "$THIS_FILE ".__LINE__."; In AN::Check->new()\n";
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

# This pings the target (hostname or IP) and if it can be reached, it returns '0'. If it can't be reached, it
# returns '1'.
sub ping
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	$an->Alert->_set_error;
	$an->Log->entry({log_level => 3, message_key => "scancore_log_0001", message_variables => { function => "AN::Tools::Check->ping()" }, file => $THIS_FILE, line => __LINE__});
	
	if (not $parameter->{target})
	{
		$an->Alert->warning({title_key => "warning_title_0004", message_key => "warning_title_0003", file => "$THIS_FILE", line => __LINE__});
		return(2);
	}
	my $target = $parameter->{target};
	my $count  = $parameter->{count} ? $parameter->{count} : 1;
	
	my $pinged = 0;
	foreach my $try (1..$count)
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "try",    value1 => $try,
			name2 => "pinged", value2 => $pinged
		}, file => $THIS_FILE, line => __LINE__});
		next if $pinged;
		
		my $shell_call  = $an->data->{path}{'ping'}." -n $target -c 1";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0016", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__});
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /(\d+) packets transmitted, (\d+) received/)
			{
				# This isn't really needed, but might help folks watching the logs.
				my $pings_sent     = $1;
				my $pings_received = $2;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "target",         value1 => $target, 
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
		close $file_handle;
	}
	my $return_code = $pinged ? 0 : 1;
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code, 
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This private method is called my AN::Tools' constructor at startup and checks
# the underlying OS and sets any internal variables as needed. It takes no
# arguments and simply returns '1' when complete.
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

# This private method is called my AN::Tools' constructor at startup and checks
# the calling environment. It will set 'cli' or 'html' depending on what
# environment variables are set. This in turn is used when displaying output to
# the user.
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

1;
