package AN::Tut::Tools::Say;

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

sub say_add
{
	my $self=shift;
	my $param=shift;
	
	# This will be the resulting string.
	my $string="";
	my $lang;
	my $task;
	my $num1;
	my $num2;
	my $result;
	
	# Pick out the passed in paramters or switch to reading by array.
	if (ref($param) eq "HASH")
	{
		$lang=$param->{lang};
		$task=$param->{task};
		$num1=$param->{num1};
		$num2=$param->{num2};
		$result=$param->{result};
	}
	else
	{
		$lang=$param;
		$task=shift;
		$num1=shift;
		$num2=shift;
		$result=shift;
	}
	
	# Now choose the task 
	
	return ($string);
}

# This prints out information on the author. Ya, it's contrived.
sub say_author
{
	my $self=shift;
	
	print "AN::Tools was written by a totally crazy lady.\n";
	
	return(0);
}

1;
