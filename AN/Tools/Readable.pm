package AN::Tools::Readable;
# 
# This module contains methods used to process values in ways that make it easier for humans to understand 
# (or from human-readable formats into computer-friendly values).
# 

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Readable.pm";

### Methods;
# base2
# bytes_to_hr
# center_text
# comma
# hr_to_bytes
# time


#############################################################################################################
# House keeping methods                                                                                     #
#############################################################################################################

sub new
{
	#print "$THIS_FILE ".__LINE__."; In AN::Readable->new()\n";
	my $class = shift;
	
	my $self  = {
		USE_BASE_2	=>	1,
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

# Return and/or set whether Base 2 or Base 10 notation is in use.
sub base2
{
	my $self = shift;
	my $set  = shift;
	
	if (defined $set)
	{
		if (($set == 0) or ($set == 1))
		{
			$self->{USE_BASE_2} = $set;
		}
		else
		{
			my $an = $self->parent;
			$an->Alert->error({title_key => "error_title_0009", message_key => "error_message_0013", message_variables => { set => $set }, code => 3, file => $THIS_FILE, line => __LINE__});
			return(undef);
		}
	}
	
	return ($self->{USE_BASE_2});
}

# Takes a raw number of bytes (whole integer).
sub bytes_to_hr
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "bytes_to_hr" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Now see if the user passed the values in a hash reference or directly.
	my $size = $parameter->{'bytes'} ? $parameter->{'bytes'}  : 0;
	my $unit = $parameter->{unit}    ? uc($parameter->{unit}) : "";
	
	# Expand exponential numbers.
	if ($size =~ /(\d+)e\+(\d+)/)
	{
		my $base = $1;
		my $exp  = $2;
		   $size = $base;
		for (1..$exp)
		{
			$size .= "0";
		}
	}
	
	# Setup my variables.
	my $suffix  = "";
	my $hr_size = $size;
	
	# Store and strip the sign
	my $sign = "";
	if ($hr_size =~ /^-/)
	{
		$sign    =  "-";
		$hr_size =~ s/^-//;
	}
	$hr_size =~ s/,//g;
	$hr_size =~ s/^\+//g;
	
	# Die if either the 'time' or 'float' has a non-digit character in it.	
	if ($hr_size =~ /\D/)
	{
		$an->Alert->error({title_key => "error_title_0011", title_variables => { method => "AN::Tools::Readable->bytes_to_hr()", }, message_key => "error_message_0016", message_variables => { size => $size }, code => 6, file => $THIS_FILE, line => __LINE__});
		# Return nothing in case the user is blocking fatal errors.
		return (undef);
	}
	
	# Do the math.
	if ($an->Readable->base2)
	{
		# Has the user requested a certain unit to use?
		if ($unit)
		{
			# Yup
			if ($unit =~ /Y/i)
			{
				# Yebibyte
				$hr_size = sprintf("%.3f", ($hr_size /= (2 ** 80)));
# 				$hr_size = $an->Readable->comma($hr_size);
				$suffix  = "YiB";
			}
			elsif ($unit =~ /Z/i)
			{
				# Zebibyte
				$hr_size = sprintf("%.3f", ($hr_size /= (2 ** 70)));
				$suffix  = "ZiB";
			}
			elsif ($unit =~ /E/i)
			{
				# Exbibyte
				$hr_size = sprintf("%.3f", ($hr_size /= (2 ** 60)));
				$suffix  = "EiB";
			}
			elsif ($unit =~ /P/i)
			{
				# Pebibyte
				$hr_size = sprintf("%.3f", ($hr_size /= (2 ** 50)));
				$suffix  = "PiB";
			}
			elsif ($unit =~ /T/i)
			{
				# Tebibyte
				$hr_size = sprintf("%.2f", ($hr_size /= (2 ** 40)));
				$suffix  = "TiB";
			}
			elsif ($unit =~ /G/i)
			{
				# Gibibyte
				$hr_size = sprintf("%.2f", ($hr_size /= (2 ** 30)));
				$suffix  = "GiB";
			}
			elsif ($unit =~ /M/i)
			{
				# Mebibyte
				$hr_size = sprintf("%.2f", ($hr_size /= (2 ** 20)));
				$suffix  = "MiB";
			}
			elsif ($unit =~ /K/i)
			{
				# Kibibyte
				$hr_size = sprintf("%.1f", ($hr_size /= (2 ** 10)));
				$suffix  = "KiB";
			}
			else
			{
# 				$hr_size = $an->Readable->comma($hr_size);
				$suffix  = "B";
			}
		}
		else
		{
			# Nope, use the most efficient.
			if ($hr_size >= (2 ** 80))
			{
				# Yebibyte
				$hr_size = sprintf("%.3f", ($hr_size /= (2 ** 80)));
# 				$hr_size = $an->Readable->comma($hr_size);
				$suffix  = "YiB";
			}
			elsif ($hr_size >= (2 ** 70))
			{
				# Zebibyte
				$hr_size = sprintf("%.3f", ($hr_size /= (2 ** 70)));
				$suffix  = "ZiB";
			}
			elsif ($hr_size >= (2 ** 60))
			{
				# Exbibyte
				$hr_size = sprintf("%.3f", ($hr_size /= (2 ** 60)));
				$suffix  = "EiB";
			}
			elsif ($hr_size >= (2 ** 50))
			{
				# Pebibyte
				$hr_size = sprintf("%.3f", ($hr_size /= (2 ** 50)));
				$suffix  = "PiB";
			}
			elsif ($hr_size >= (2 ** 40))
			{
				# Tebibyte
				$hr_size = sprintf("%.2f", ($hr_size /= (2 ** 40)));
				$suffix  = "TiB";
			}
			elsif ($hr_size >= (2 ** 30))
			{
				# Gibibyte
				$hr_size = sprintf("%.2f", ($hr_size /= (2 ** 30)));
				$suffix  = "GiB";
			}
			elsif ($hr_size >= (2 ** 20))
			{
				# Mebibyte
				$hr_size = sprintf("%.2f", ($hr_size /= (2 ** 20)));
				$suffix  = "MiB";
			}
			elsif ($hr_size >= (2 ** 10))
			{
				# Kibibyte
				$hr_size = sprintf("%.1f", ($hr_size /= (2 ** 10)));
				$suffix  = "KiB";
			}
			else
			{
# 				$hr_size = $an->Readable->comma($hr_size);
				$suffix  = "B";
			}
		}
	}
	else
	{
		# Has the user requested a certain unit to use?
		if ($unit)
		{
			# Yup
			if ($unit =~ /Y/i)
			{
				# Yottabyte
				$hr_size = sprintf("%.3f", ($hr_size /= (10 ** 24)));
# 				$hr_size = $an->Readable->comma($hr_size);
				$suffix  = "YB";
			}
			elsif ($unit =~ /Z/i)
			{
				# Zettabyte
				$hr_size = sprintf("%.3f", ($hr_size /= (10 ** 21)));
				$suffix  = "ZB";
			}
			elsif ($unit =~ /E/i)
			{
				# Exabyte
				$hr_size = sprintf("%.3f", ($hr_size /= (10 ** 18)));
				$suffix  = "EB";
			}
			elsif ($unit =~ /P/i)
			{
				# Petabyte
				$hr_size = sprintf("%.3f", ($hr_size /= (10 ** 15)));
				$suffix  = "PB";
			}
			elsif ($unit =~ /T/i)
			{
				# Terabyte
				$hr_size = sprintf("%.2f", ($hr_size /= (10 ** 12)));
				$suffix  = "TB";
			}
			elsif ($unit =~ /G/i)
			{
				# Gigabyte
				$hr_size = sprintf("%.2f", ($hr_size /= (10 ** 9)));
				$suffix  = "GB";
			}
			elsif ($unit =~ /M/i)
			{
				# Megabyte
				$hr_size = sprintf("%.2f", ($hr_size /= (10 ** 6)));
				$suffix  = "MB";
			}
			elsif ($unit =~ /K/i)
			{
				# Kilobyte
				$hr_size = sprintf("%.1f", ($hr_size /= (10 ** 3)));
				$suffix  = "KB";
			}
			else
			{
# 				$hr_size = $an->Readable->comma($hr_size);
				$suffix  = "b";
			}
		}
		else
		{
			# Nope, use the most efficient.
			if ($hr_size >= (10 ** 24))
			{
				# Yottabyte
				$hr_size = sprintf("%.3f", ($hr_size /= (10 ** 24)));
# 				$hr_size = $an->Readable->comma($hr_size);
				$suffix  = "YB";
			}
			elsif ($hr_size >= (10 ** 21))
			{
				# Zettabyte
				$hr_size = sprintf("%.3f", ($hr_size /= (10 ** 21)));
				$suffix  = "ZB";
			}
			elsif ($hr_size >= (10 ** 18))
			{
				# Exabyte
				$hr_size = sprintf("%.3f", ($hr_size /= (10 ** 18)));
				$suffix  = "EB";
			}
			elsif ($hr_size >= (10 ** 15))
			{
				# Petabyte
				$hr_size = sprintf("%.3f", ($hr_size /= (10 ** 15)));
				$suffix  = "PB";
			}
			elsif ($hr_size >= (10 ** 12))
			{
				# Terabyte
				$hr_size = sprintf("%.2f", ($hr_size /= (10 ** 12)));
				$suffix  = "TB";
			}
			elsif ($hr_size >= (10 ** 9))
			{
				# Gigabyte
				$hr_size = sprintf("%.2f", ($hr_size /= (10 ** 9)));
				$suffix  = "GB";
			}
			elsif ($hr_size >= (10 ** 6))
			{
				# Megabyte
				$hr_size = sprintf("%.2f", ($hr_size /= (10 ** 6)));
				$suffix  = "MB";
			}
			elsif ($hr_size >= (10 ** 3))
			{
				# Kilobyte
				$hr_size = sprintf("%.1f", ($hr_size /= (10 ** 3)));
				$suffix  = "KB";
			}
			else
			{
# 				$hr_size = $an->Readable->comma($hr_size);
				$suffix  = "b";
			}
		}
	}
	
	# Restore the sign.
	if ( $sign eq "-" )
	{
		$hr_size = $sign.$hr_size;
	}
	$hr_size .= " $suffix";
	
	return($hr_size);
}

# This takes a string and an integer and pads the string with spaces on either side until the length is that
# of the integer. For uneven splits, the smaller number of spaces will be on the left.
sub center_text
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "center_text" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Pick up the parameters.
	return("") if not $parameter->{string};
	my $string = $parameter->{string};
	my $width  = defined $parameter->{width} ? $parameter->{width} : 0;
	return($string) if not $width;
	### NOTE: If a '#!string!x!#' is passed, the Log->entry method will translate it in the log itself,
	###       so you won't see that string.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "string", value1 => $string,
		name2 => "width",  value2 => $width,
	}, file => $THIS_FILE, line => __LINE__});
	
	if ($string =~ /#!string!(.*?)!#/)
	{
		$string = $an->String->get({key => $1});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "string", value1 => $string,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	my $current_length = length($string);
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "current_length", value1 => $current_length,
	}, file => $THIS_FILE, line => __LINE__});
	if ($current_length < $width)
	{
		my $difference = $width - $current_length;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "difference", value1 => $difference,
		}, file => $THIS_FILE, line => __LINE__});
		if ($difference == 1)
		{
			$string .= " ";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "string", value1 => $string,
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			my $remainder  =  $difference % 2;
			   $difference -= $remainder;
			my $spaces     =  $difference / 2;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "remainder", value1 => $remainder,
				name2 => "spaces",    value2 => $spaces,
			}, file => $THIS_FILE, line => __LINE__});
			for (1..$spaces)
			{
				$string = " ".$string." ";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "string", value1 => $string,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($remainder)
			{
				$string .= " ";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "string", value1 => $string,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "string", value1 => $string,
		name2 => "length", value2 => length($string),
	}, file => $THIS_FILE, line => __LINE__});
	return($string);
}

# This takes a large number and inserts commas every three characters left of the decimal place. This method
# doesn't take a parameter hash reference.
sub comma
{
	my $self   = shift;
	my $number = shift;
	my $an     = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "comma" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Return if nothing passed.
	return undef if not defined $number;
	
	# Strip out any existing commas.
	$number =~ s/,//g;
	$number =~ s/^\+//g;
	
	# Split on the left-most period.
	#print "$THIS_FILE ".__LINE__."; number: [$number]\n";
	my ($whole, $decimal) = split/\./, $number, 2;
	$whole   = "" if not defined $whole;
	$decimal = "" if not defined $decimal;
	
	# Now die if either number has a non-digit character in it.
	#print "$THIS_FILE ".__LINE__."; whole: [$whole], decimal: [$decimal]\n";
	if (($whole =~ /\D/) or ($decimal =~ /\D/))
	{
		my $an = $self->parent;
		$an->Alert->error({title_key => "error_title_0010", message_key => "error_message_0014", message_variables => { number => $number }, code => 4, file => $THIS_FILE, line => __LINE__});
		# Return nothing in case the user is blocking fatal errors.
		return (undef);
	}
	
	local($_) = $whole ? $whole : "";
	
	1 while s/^(-?\d+)(\d{3})/$1,$2/;
	$whole = $_;
	
	my $return = $decimal ? "$whole.$decimal" : $whole;
	
	return ($return);
}

# This takes a "human readable" size with an ISO suffix and converts it back to a base byte size as 
# accurately as possible.
sub hr_to_bytes
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "hr_to_bytes" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	return undef if not defined $parameter;
	
	# Pick up the parameters.
	my $base2  =  defined $parameter->{base2}  ? $parameter->{base2}  : 0;
	my $base10 =  defined $parameter->{base10} ? $parameter->{base10} : 0;
	my $size   =  defined $parameter->{size}   ? $parameter->{size}   : 0;
	my $type   =  defined $parameter->{type}   ? $parameter->{type}   : 0;
	my $value  =  $size;
	   $size   =~ s/ //g;
	   $type   =~ s/ //g;
	
	# Store and strip the sign
	my $sign = "";
	if ($size =~ /^-/)
	{
		$sign =  "-";
		$size =~ s/^-//;
	}
	$size =~ s/,//g;
	$size =~ s/^\+//g;
	
	# If I don't have a passed type, see if there is a letter or letters after the size to hack off.
	if ((not $type) && ($size =~ /[a-zA-Z]$/))
	{
		($size, $type) = ($size =~ /^(.*\d)(\D+)/);
	}
	$type = lc($type);
	
	# Make sure that 'size' is now an integer or float.
	if ($size !~ /\d+[\.\d+]?/)
	{
		$an->Alert->error({title_key => "error_title_0011", title_variables => { method => "AN::Tools::Readable->hr_to_bytes()" }, message_key => "error_message_0017", message_variables => { size => $size, sign => $sign, type => $type }, code => 7, file => $THIS_FILE, line => __LINE__});
		# Return nothing in case the user is blocking fatal errors.
		return (undef);
	}
	
	# If 'type' is still blank, set it to 'b'.
	$type = "b" if not $type;
	
	# If the type is already bytes, make sure the size is an integer and return.
	if ($type eq "b")
	{
		if ($size =~ /\D/)
		{
			$an->Alert->error({title_key => "error_title_0011", title_variables => { method => "AN::Tools::Readable->hr_to_bytes()" }, message_key => "error_message_0018", message_variables => { size => $size, sign => $sign, type => $type }, code => 8, file => $THIS_FILE, line => __LINE__});
			return(undef);
		}
		return ($sign.$size);
	}
	
	# If the "type" is "Xib" or if '$base2' is set, make sure we're running in Base2 notation. Conversly,
	# if the type is "Xb" or if '$base10' is set, make sure that we're running in Base10 notation. In 
	# either case, shorten the 'type' to just the first letter to make the next sanity check simpler.
	my $prior_base2 = $an->Readable->base2();
	if ($base2)
	{
		$an->Readable->base2(1);
		$type = ($type =~ /^(\w)/)[0];
	}
	elsif ($base10)
	{
		$an->Readable->base2(0);
		$type = ($type =~ /^(\w)/)[0];
	}
	elsif ($type =~ /^(\w)ib$/)
	{
		# Make sure we're running in Base2.
		$type = $1;
		$an->Readable->base2(1);
	}
	elsif ($type =~ /^(\w)b$/)
	{
		# Make sure we're running in Base2.
		$type = $1;
		$an->Readable->base2(0);
	}
	
	# Check if we have a valid '$type' and that 'Math::BigInt' is loaded, if the size is big enough to 
	# require it.
	if (($type eq "p") or ($type eq "e") or ($type eq "z") or ($type eq "y"))
	{
		# If this is a big size needing "Math::BigInt", check if it is loaded yet and load it, if not.
		if (not $an->_math_bigint_loaded)
		{
			$an->_load_math_bigint();
		}
	}
	elsif (($type ne "t") && ($type ne "g") && ($type ne "m") && ($type ne "k"))
	{
		# If we're here, we didn't match one of the large sizes or any of the other sizes, so die.

		$an->Alert->error({title_key => "error_title_0012", message_key => "error_message_0168", message_variables => { 
			value => $value,
			size  => $size, 
			type  => $type,
		}, code => 168, file => $THIS_FILE, line => __LINE__});
		
		# Return nothing in case the user is blocking fatal errors.
		return (undef);
	}
	
	# Now the magic... lame magic, true, but still.
	my $bytes;
	if ($an->Readable->base2)
	{
		if    ($type eq "y") { $bytes = Math::BigInt->new('2')->bpow('80')->bmul($size); }	# Yobibyte
		elsif ($type eq "z") { $bytes = Math::BigInt->new('2')->bpow('70')->bmul($size); }	# Zibibyte
		elsif ($type eq "e") { $bytes = Math::BigInt->new('2')->bpow('60')->bmul($size); }	# Exbibyte
		elsif ($type eq "p") { $bytes = Math::BigInt->new('2')->bpow('50')->bmul($size); }	# Pebibyte
		elsif ($type eq "t") { $bytes = ($size * (2 ** 40)) }					# Tebibyte
		elsif ($type eq "g") { $bytes = ($size * (2 ** 30)) }					# Gibibyte
		elsif ($type eq "m") { $bytes = ($size * (2 ** 20)) }					# Mebibyte
		elsif ($type eq "k") { $bytes = ($size * (2 ** 10)) }					# Kibibyte
	}
	else
	{
		if    ($type eq "y") { $bytes = Math::BigInt->new('10')->bpow('24')->bmul($size); }	# Yottabyte
		elsif ($type eq "z") { $bytes = Math::BigInt->new('10')->bpow('21')->bmul($size); }	# Zettabyte
		elsif ($type eq "e") { $bytes = Math::BigInt->new('10')->bpow('18')->bmul($size); }	# Exabyte
		elsif ($type eq "p") { $bytes = Math::BigInt->new('10')->bpow('15')->bmul($size); }	# Petabyte
		elsif ($type eq "t") { $bytes = ($size * (10 ** 12)) }					# Terabyte
		elsif ($type eq "g") { $bytes = ($size * (10 ** 9)) }					# Gigabyte
		elsif ($type eq "m") { $bytes = ($size * (10 ** 6)) }					# Megabyte
		elsif ($type eq "k") { $bytes = ($size * (10 ** 3)) }					# Kilobyte
	}
	
	# Last, round off the byte size if it is a float.
	if ($bytes =~ /\./)
	{
		$bytes = $an->Math->round({
			number => $bytes,
			places => 0
		});
	}
	
	# Switch the base2() method back in case it was changed.
	$an->Readable->base2($prior_base2);
	
	return ($sign.$bytes);
}

# Takes a number of seconds and turns it into d/h/m/s
sub time
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "time" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	return undef if not defined $parameter;
	
	my $time    = $parameter->{'time'}  ? $parameter->{'time'}  : 0;
	my $suffix  = $parameter->{suffix}  ? $parameter->{suffix}  : "short";
	my $process = $parameter->{process} ? $parameter->{process} : 0;
	
	# The suffix used for each unit of time will depend on the requested suffix type.
	my $suffix_seconds = $suffix eq "long"? " #!string!tools_suffix_0032!#" : " #!string!tools_suffix_0027!#";
	my $suffix_minutes = $suffix eq "long"? " #!string!tools_suffix_0033!#" : " #!string!tools_suffix_0028!#";
	my $suffix_hours   = $suffix eq "long"? " #!string!tools_suffix_0034!#" : " #!string!tools_suffix_0029!#";
	my $suffix_days    = $suffix eq "long"? " #!string!tools_suffix_0035!#" : " #!string!tools_suffix_0030!#";
	my $suffix_weeks   = $suffix eq "long"? " #!string!tools_suffix_0036!#" : " #!string!tools_suffix_0031!#";
	
	# Exit if 'time' is not defined or set as '--'.
	$parameter->{'time'} = "--" if not defined $parameter->{'time'};
	return('--') if $parameter->{'time'} eq "--";
	
	my $old_time =  $time;
	my $float    =  0;
	my $sign     =  $time =~ /^-/ ? "-" : "";
	   $time     =~ s/^-//;
	   $time     =~ s/,//g;
	if ($time=~/\./)
	{
		($time, $float) = split/\./, $time, 2;
	}
	
	# Die if either the 'time' or 'float' has a non-digit character in it.
	if (($time =~ /\D/) or ($float =~ /\D/))
	{
		$an->Alert->error({title_key => "error_title_0011", title_variables => { method => "AN::Tools::Readable->time()", }, message_key => "error_message_0015", message_variables => { old_time => $old_time }, code => 5, file => $THIS_FILE, line => __LINE__});
		# Return nothing in case the user is blocking fatal errors.
		return (undef);
	}
	
	my $seconds   = $time % 60;
	my $minutes   = ($time - $seconds) / 60;
	my $rem_min   = $minutes % 60;
	my $hours     = ($minutes - $rem_min) / 60;
	my $rem_hours = $hours % 24;
	my $days      = ($hours - $rem_hours) / 24;
	my $rem_days  = $days % 7;
	my $weeks     = ($days - $rem_days) / 7;

	my $hr_time = "";
	if ($seconds < 1)
	{
		$hr_time = $float ? "0.${float}s" : "0".$suffix_seconds;
		#print "$THIS_FILE ".__LINE__."; hr_time: [$hr_time]\n";
	}
	else
	{
		$hr_time = sprintf("%01d", $seconds);
		#print "$THIS_FILE ".__LINE__."; hr_time: [$hr_time]\n";
		if ( $float > 0 )
		{
			$hr_time .= ".".$float.$suffix_seconds;
			#print "$THIS_FILE ".__LINE__."; hr_time: [$hr_time]\n";
		}
		else
		{
			$hr_time .= $suffix_seconds;
			#print "$THIS_FILE ".__LINE__."; hr_time: [$hr_time]\n";
		}
	}
	if ($rem_min > 0)
	{
		$hr_time =~ s/ sec.$/$suffix_seconds/;
		$hr_time =  sprintf("%01d", $rem_min).$suffix_minutes." $hr_time";
		#print "$THIS_FILE ".__LINE__."; hr_time: [$hr_time]\n";
	}
	elsif (($hours > 0) or ($days > 0) or ($weeks > 0))
	{
		$hr_time = "0".$suffix_minutes." ".$hr_time;
		#print "$THIS_FILE ".__LINE__."; hr_time: [$hr_time]\n";
	}
	if ($rem_hours > 0)
	{
		$hr_time = sprintf("%01d", $rem_hours)."$suffix_hours $hr_time";
		#print "$THIS_FILE ".__LINE__."; hr_time: [$hr_time]\n";
	}
	elsif (($days > 0) or ($weeks > 0))
	{
		$hr_time = "0".$suffix_hours." ".$hr_time;
		#print "$THIS_FILE ".__LINE__."; hr_time: [$hr_time]\n";
	}
	if ($days > 0)
	{
		$hr_time = sprintf("%01d", $rem_days).$suffix_days." ".$hr_time;
		#print "$THIS_FILE ".__LINE__."; hr_time: [$hr_time]\n";
	}
	elsif ($weeks > 0)
	{
		$hr_time = "0".$suffix_days." ".$hr_time;
		#print "$THIS_FILE ".__LINE__."; hr_time: [$hr_time]\n";
	}
	if ($weeks > 0)
	{
		$weeks   = $an->Readable->comma($weeks);
		$hr_time = $weeks.$suffix_weeks." ".$hr_time;
		#print "$THIS_FILE ".__LINE__."; hr_time: [$hr_time]\n";
	}
	$hr_time = $sign ? $sign.$hr_time : $hr_time;
	#print "$THIS_FILE ".__LINE__."; hr_time: [$hr_time]\n";
	
	# Return an already-translated string, if requested.
	if ($process)
	{
		#print "$THIS_FILE ".__LINE__."; >> hr_time: [$hr_time]\n";
		$hr_time = $an->String->_process_string({
			string    => $hr_time, 
			language  => $an->default_language, 
			hash      => $an->data, 
			variables => {}, 
		});
		#print "$THIS_FILE ".__LINE__."; << hr_time: [$hr_time]\n";
	}
	
	return ($hr_time);
}


#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

1;
