package AN::Tools::Convert;
# 
# This module contains methods used to convert units (metric to imperial, etc)
# 

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Convert.pm";

### Methods;
# convert_format_mmddyy_to_yymmdd
# convert_to_celsius
# convert_to_fahrenheit
# hex_to_decimal

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

# This converts a mm/dd/yy or mm/dd/yyyy string into the more sensible yy/mm/dd or yyyy/mm/dd string.
sub convert_format_mmddyy_to_yymmdd
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "convert_format_mmddyy_to_yymmdd" }, file => $THIS_FILE, line => __LINE__});
	
	my $date = $parameter->{date};
	return("#!null!#") if not $date;
	
	# Split off the value from the suffix, if any.
	if ($date =~ /^(\d\d)\/(\d\d)\/(\d\d\d\d)/)
	{
		$date = "$3/$1/$2";
	}
	elsif ($date =~ /^(\d\d)\/(\d\d)\/(\d\d)/)
	{
		$date = "$3/$1/$2";
	}
	
	# Return if the temperature wasn't found.
	return("#!invalid!#") if $date !~ /^\d/;
	
	return($date);
}

# This takes value and converts it from fahrenheit to celsius.
sub convert_to_celsius
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "convert_to_celsius" }, file => $THIS_FILE, line => __LINE__});
	
	my $temperature = $parameter->{temperature};
	return("#!null!#") if not $temperature;
	
	# Split off the value from the suffix, if any.
	if ($temperature =~ /^(\d+\.\d+).*/)
	{
		$temperature = $1;
	}
	elsif ($temperature =~ /^(\d+)(.*)/)
	{
		$temperature = $1;
	}
	
	# Return if the temperature wasn't found.
	return("#!invalid!#") if $temperature !~ /^\d/;
	
	# Convert the temperature.
	my $new_temperature = (($temperature - 32) / 1.8);
	
	return($new_temperature);
}

# This takes value and converts it from celsius to fahrenheit.
sub convert_to_fahrenheit
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, message_key => "tools_log_0001", message_variables => { function => "convert_to_fahrenheit" }, file => $THIS_FILE, line => __LINE__});
	
	my $temperature = $parameter->{temperature};
	return("#!null!#") if not $temperature;
	
	# Split off the value from the suffix, if any.
	if ($temperature =~ /^(\d+\.\d+).*/)
	{
		$temperature = $1;
	}
	elsif ($temperature =~ /^(\d+)(.*)/)
	{
		$temperature = $1;
	}
	
	# Return if the temperature wasn't found.
	return("#!invalid!#") if $temperature !~ /^\d/;
	
	# Convert the temperature.
	my $new_temperature = (($temperature * 1.8) + 32);
	
	return($new_temperature);
}

# This converts a hexidecimal value to a decimal value.
sub hex_to_decimal
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, message_key => "tools_log_0001", message_variables => { function => "hex_to_decimal" }, file => $THIS_FILE, line => __LINE__});
	
	my $hex = $parameter->{hex};
	return("#!null!#") if not defined $hex;
	
	my $decimal = hex($hex);
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "hex",     value1 => $hex, 
		name2 => "decimal", value2 => $decimal, 
	}, file => $THIS_FILE, line => __LINE__});
	
	return($decimal);
}

#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

1;
