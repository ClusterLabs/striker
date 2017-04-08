package AN::Tools::Math;
# 
# This module contains methods used to handle math things, like financially accurate rounding of real 
# numbers.
# 

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Math.pm";

### Methods;
# round


#############################################################################################################
# House keeping methods                                                                                     #
#############################################################################################################


# The constructor
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


### TODO: Does this handle "x.95" type rounding properly?
# This takes a number and rounds it to a given number of places after the decimal (defaulting to an even 
# integer). This does financial-type rounding.
sub round
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "round" }, file => $THIS_FILE, line => __LINE__});
	
	# Setup my numbers.
	my $num    = $parameter->{number} ? $parameter->{number} : 0;
	my $places = $parameter->{places} ? $parameter->{places} : 0;
	
	# Return if the user passed a double-dash.
	return('--') if $num eq "--";
	
	# Make a copy of the passed number that I can manipulate.
	my $rounded_num = $num;
	
	# Take out any commas.
	$rounded_num =~ s/,//g;
	
	# If there is a decimal place in the number, do the smart math. Otherwise, just pad the number with 
	# the requested number of zeros after the decimal place.
	if ( $rounded_num =~ /\./ )
	{
		# Split up the number.
		my ($real, $decimal) = split/\./, $rounded_num, 2;
		
		# If there is anything other than one ',' and digits, error.
		if (($real =~ /\D/) or ($decimal =~ /\D/))
		{
			$an->Alert->error({title_key => "error_title_0011", title_variables => { method => "AN::Tools::Math->round()" }, message_key => "error_message_0020", message_variables => { number => $num }, code => 2, file => $THIS_FILE, line => __LINE__});
			# Return nothing in case the user is blocking fatal errors.
			return (undef);
		}
		
		# If the number is already equal to the requested number of places after the decimal, just 
		# return. If it is less, pad the needed number of zeros. Otherwise, start rounding.
		if ( length($decimal) == $places )
		{
			# Equal, return.
			return $rounded_num;
		}
		elsif ( length($decimal) < $places )
		{
			# Less, pad.
			$rounded_num = sprintf("%.${places}f", $rounded_num);
		}
		else
		{
			# Greater than; I need to round the number. Start by getting the number of places I 
			# need to round.
			my $round_diff = length($decimal) - $places;
			
			# This keeps track of whether the next (left) digit needs to be incremented.
			my $increase = 0;
			
			# Now loop the number of times needed to round to the requested number of places.
			for (1..$round_diff)
			{
				# Reset 'increase'.
				$increase = 0;
				
				# Make sure I am dealing with a digit.
				if ($decimal =~ /(\d)$/)
				{
					my $last_digit =  $1;
					$decimal       =~ s/$last_digit$//;
					if ($last_digit > 4)
					{
						$increase = 1;
						if ($decimal eq "")
						{
							$real++;
						}
						else
						{
							$decimal++;
						}
					}
				}
			}
			if ($places == 0 )
			{
				$rounded_num = $real;
			}
			else
			{
				$rounded_num = $real.".".$decimal;
			}
		}
	}
	else
	{
		# This is a whole number so just pad 0s as needed.
		$rounded_num = sprintf("%.${places}f", $rounded_num);
	}
	
	# Return the number.
	return ($rounded_num);
}

#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

1;
