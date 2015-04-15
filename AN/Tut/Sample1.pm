package AN::Tut::Sample1;

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

# My constructor method
sub new
{
	# get's the Package name.
	my $class=shift;
	print "The first argument passed into my constructor method is the 'class': [$class]\n";
	
	# Create an anonymous hash reference for later use.
	my $self={};
	print "This is what the simple hash reference 'self' looks like at first: [$self]\n";
	
	bless ($self, $class);	# Associate 'self' as an object in 'class'.
	print "This is what the hash reference 'self' looks like after being 'bless'ed into this class: [$self]\n";
	
	return ($self);
}

# My addition method
sub add
{
	# I expect this to be called via the object returned by the constructor
	# method.
	my $self=shift;
	print "The first argument passed into my 'add' method: [$self]\n";
	
	# Pick up my two numbers.
	my $num_a=shift;
	my $num_b=shift;
	
	# Just a little sanity check.
	if (($num_a !~ /(^-?)\d+(\.\d+)?/) || ($num_b !~ /(^-?)\d+(\.\d+)?/))
	{
		croak "The method 'AN::Tut::Sample1->add' needs to be passed two numbers.\n";
	}
	
	# Do the math.
	my $result=$num_a + $num_b;
	
	# Return the results.
	return ($result);
}

1;
