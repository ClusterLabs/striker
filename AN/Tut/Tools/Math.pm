package AN::Tut::Tools::Math;

# This sets the version of this file. It will be useful later.
BEGIN
{
	our $VERSION="0.1.001";
}

# This just sets perl to be strict about how it runs and to die in a way
# more compatible with the caller.
use strict;
use warnings;
use Carp;


# The constructor method.
sub new
{
	my $class=shift;
	
	my $self={};
	
	bless ($self, $class);
	
	return ($self);
}

# My addition method
sub add
{
	# I expect this to be called via the object returned by the constructor
	# method. The next two arguments are the two numbers to sum up.
	my $self=shift;
	my $num_a=shift;
	my $num_b=shift;
	
	# Make sure that this method is called via the module's object.
	croak "The method 'add' must be called via the object returned by 'new'.\n" if not ref($self);
	
	# Just a little sanity check.
	if (($num_a !~ /(^-?)\d+(\.\d+)?/) || ($num_b !~ /(^-?)\d+(\.\d+)?/))
	{
		croak "The method 'AN::Tut::Sample2->add' needs to be passed two numbers.\n";
	}
	
	# Do the math.
	my $result=$num_a + $num_b;
	
	# Return the results.
	return ($result);
}

# My subtraction method
sub subtract
{
	# I expect this to be called via the object returned by the constructor
	# method. Then I expect a number followed by the number to subtract
	# from it.
	my $self=shift;
	my $num_a=shift;
	my $num_b=shift;
	
	# Make sure that this method is called via the module's object.
	croak "The method 'subtract' must be called via the object returned by 'new'.\n" if not ref($self);
	
	# Just a little sanity check.
	if (($num_a !~ /(^-?)\d+(\.\d+)?/) || ($num_b !~ /(^-?)\d+(\.\d+)?/))
	{
		croak "The method 'AN::Tut::Sample2->subtract' needs to be passed two numbers.\n";
	}
	
	# Do the math.
	my $result=$num_a - $num_b;
	
	# Return the results.
	return ($result);
}

1;
