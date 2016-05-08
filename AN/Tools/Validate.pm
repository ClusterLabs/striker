package AN::Tools::Validate;
# 
# This module will contain methods used to validate various user inputs.
# 

use strict;
use warnings;
use Data::Dumper;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Validate.pm";

### Methods;
# is_domain_name
# is_integer_or_unsigned_float
# is_ipv4
# is_url
# is_uuid


#############################################################################################################
# House keeping methods                                                                                     #
#############################################################################################################

sub new
{
	my $class = shift;
	
	my $self  = {
	};
	
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

# Check to see if the string looks like a valid hostname
sub is_domain_name
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	my $name = $parameter->{name} ? $parameter->{name} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "name", value1 => $name,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $valid = 1;
	if (not $name)
	{
		$valid = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "valid", value1 => $valid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif (($name !~ /^((([a-z]|[0-9]|\-)+)\.)+([a-z])+$/i) && (($name !~ /^\w+$/) && ($name !~ /-/)))
	{
		# Doesn't appear to be valid.
		$valid = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "valid", value1 => $valid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "valid", value1 => $valid,
	}, file => $THIS_FILE, line => __LINE__});
	return($valid);
}

# Check if the passed string is an unsigned floating point number. A whole number is allowed.
sub is_integer_or_unsigned_float
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	my $number = $parameter->{number} ? $parameter->{number} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "number", value1 => $number,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $valid = 1;
	if ($number =~ /^\D/)
	{
		# Non-digit could mean it's signed or just garbage.
		$valid = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "valid", value1 => $valid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif (($number !~ /^\d+$/) && ($number != /^\d+\.\d+$/))
	{
		# Not an integer or float
		$valid = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "valid", value1 => $valid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "valid", value1 => $valid,
	}, file => $THIS_FILE, line => __LINE__});
	return($valid);
}

# Checks if the passed-in string is an IPv4 address. Returns '1' if OK, 0 if not.
sub is_ipv4
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	my $ip = $parameter->{ip} ? $parameter->{ip} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ip", value1 => $ip,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $valid = 1;
	if ($ip =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/)
	{
		# It's in the right format.
		my $first_octal  = $1;
		my $second_octal = $2;
		my $third_octal  = $3;
		my $fourth_octal = $4;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "first_octal",  value1 => $first_octal,
			name2 => "second_octal", value2 => $second_octal,
			name3 => "third_octal",  value3 => $third_octal,
			name4 => "fourth_octal", value4 => $fourth_octal,
		}, file => $THIS_FILE, line => __LINE__});
		
		if (($first_octal  < 0) || ($first_octal  > 255) ||
		    ($second_octal < 0) || ($second_octal > 255) ||
		    ($third_octal  < 0) || ($third_octal  > 255) ||
		    ($fourth_octal < 0) || ($fourth_octal > 255))
		{
			# One of the octals is out of range.
			$valid = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "valid", value1 => $valid,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	else
	{
		# Not in the right format.
		$valid = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "valid", value1 => $valid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "valid", value1 => $valid,
	}, file => $THIS_FILE, line => __LINE__});
	return($valid);
}

# Checks to see if the passed string is a URL or not.
sub is_url
{   
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	my $url = $parameter->{url} ? $parameter->{url} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "url", value1 => $url,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $valid = 1;
	if (not $url)
	{
		$valid = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "valid", value1 => $valid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($url =~ /^(.*?):\/\/(.*?)\/(.*)$/)
	{
		my $protocol = $1;
		my $host     = $2;
		my $path     = $3;
		my $port     = "";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "protocol", value1 => $protocol,
			name2 => "host",     value2 => $host,
			name3 => "path",     value3 => $path,
			name4 => "port",     value4 => $port,
		}, file => $THIS_FILE, line => __LINE__});
		if ($protocol eq "http")
		{
			$port = 80;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "port", value1 => $port,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($protocol eq "https")
		{
			$port = 443;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "port", value1 => $port,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($protocol eq "ftp")
		{
			$port = 21;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "port", value1 => $port,
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Invalid protocol
			$valid = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "valid", value1 => $valid,
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($host =~ /^(.*?):(\d+)$/)
		{
			$host = $1;
			$port = $2;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "host", value1 => $host,
				name2 => "port", value2 => $port,
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($host =~ /^\d+\.\d+\.\d+\.\d+/)
		{
			if (not $an->Validate->is_ipv4({ip => $host}))
			{
				$valid = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "valid", value1 => $valid,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		else
		{
			if (not $an->Validate->is_domain_name({name => $host}))
			{
				$valid = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "valid", value1 => $valid,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "protocol", value1 => $protocol,
			name2 => "host",     value2 => $host,
			name3 => "path",     value3 => $path,
			name4 => "port",     value4 => $port,
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{   
		$valid = 0;
		$an->Log->entry({log_level => 0, message_key => "an_variables_0001", message_variables => {
			name1 => "valid", value1 => $valid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "valid", value1 => $valid,
	}, file => $THIS_FILE, line => __LINE__});
	return($valid);
}

# This checks to see if the string is a UUID or not.
sub is_uuid
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	my $valid = 0;
	my $uuid  = $parameter->{uuid} ? $parameter->{uuid} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "uuid", value1 => $uuid, 
	}, file => $THIS_FILE, line => __LINE__});
	if (($uuid) && ($uuid =~ /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/))
	{
		$valid = 1;
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "valid", value1 => $valid, 
	}, file => $THIS_FILE, line => __LINE__});
	return($valid);
}



#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

1;
