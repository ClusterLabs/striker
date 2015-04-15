package AN::Tools::Convert;

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Convert.pm";


sub new
{
	#print "$THIS_FILE ".__LINE__."; In AN::Convert->new()\n";
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

1;
