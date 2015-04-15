package AN::Tut::Tools;

# This sets the version of this file. It will be useful later.
BEGIN
{
	our $VERSION="0.1.001";
}

# This just sets perl to be strict about how it runs and to die in a way
# more compatible with the caller.
use strict;
use warnings;
# use Carp;

use AN::Tut::Tools::Math;
use AN::Tut::Tools::Say;

# My constructor method
sub new
{
	# get's the Package name.
	my $class=shift;
	
	# Now this hash reference will be used to store a counter of how many
	# times the module is called and how many times each method is called.
	my $self={
		HANDLE	=>	{
			MATH	=>	"",
			SAY	=>	"",
		},
	};
	
	# Associate 'self' as an object in 'class'.
	bless ($self, $class);
	
	# Get a handle on the other three modules.
	$self->Math(AN::Tut::Tools::Math->new());
	$self->Say(AN::Tut::Tools::Say->new());
	
	return ($self);
}

# This is a the public access method to the internal 'AN::Tut::Tools::Math'
# object.
sub Math
{
	my $self=shift;
	
	$self->{HANDLE}{MATH}=shift if defined $_[0];
	
	return ($self->{HANDLE}{MATH});
}

# This is a the public access method to the internal 'AN::Tut::Tools::Say'
# object.
sub Say
{
	my $self=shift;
	
	$self->{HANDLE}{SAY}=shift if defined $_[0];
	
	return ($self->{HANDLE}{SAY});
}

1;
