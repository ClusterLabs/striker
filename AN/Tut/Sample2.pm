package AN::Tut::Sample2;

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
	
	# Now this hash reference will be used to store a counter of how many
	# times the module is called and how many times each method is called.
	my $self={
		CALL_COUNT	=>	0,
		CALLED		=>	{
			ADD		=>	0,
			SUBTRACT	=>	0,
		},
	};
	
	bless ($self, $class);	# Associate 'self' as an object in 'class'.
	
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
	
	# Count this call.
	&_count_module($self);
	$self->_count_method_add;
	
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
	
	# Count this call.
	$self->_count_module;
	$self->_count_method_subtract;
	
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

# This simply returns how many times things have been called.
sub get_counts
{
	my $self=shift;
	croak "The method 'get_counts' must be called via the object returned by 'new'.\n" if not ref($self);
	
	# I don't actually do anything here, I just return value. The one thing
	# to note though is how I call the internal method '_count_module',
	# which will increment the overall module call to account for this
	# call, and then return the values from the 'self' hash directly so
	# that they don't increment.
	return ($self->_count_module, $self->{CALLED}{ADD}, $self->{CALLED}{SUBTRACT});
}

# My internal method to count calls to this module. Returns the current count.
sub _count_module
{
	my $self=shift;
	print "Passed into '_count_module': [$self]\n";
	
	# Increment by one.
	$self->{CALL_COUNT}++;
	
	return ($self->{CALL_COUNT});
}

# My internal method to count calls to the 'add' method.
sub _count_method_add
{
	my $self=shift;
	
	# Increment by one.
	$self->{CALLED}{ADD}++;
	
	return ($self->{CALLED}{ADD});
}

# My internal method to count calls to the 'add' method.
sub _count_method_subtract
{
	my $self=shift;
	
	# Increment by one.
	$self->{CALLED}{SUBTRACT}++;
	
	return ($self->{CALLED}{SUBTRACT});
}

1;
