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
	
	my $self  = {
	};
	
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
			title_key	=>	"warning_title_0001",
			message_key	=>	"warning_message_0001",
			message_vars	=>	{
				os		=>	$^O,
			},
			file		=>	"$THIS_FILE",
			line		=>	__LINE__
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
