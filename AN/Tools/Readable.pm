package AN::Tools::Readable;

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Readable.pm";


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

# Return and/or set whether Base 2 or Base 10 notation is in use.
sub base2
{
	my $self = shift;
	my $set  = shift;
	
	if (defined $set)
	{
		if (($set == 0) || ($set == 1))
		{
			$self->{USE_BASE_2} = $set;
		}
		else
		{
			my $an = $self->parent;
			$an->Alert->error({
				fatal			=>	1,
				title_key		=>	"error_title_0009",
				message_key		=>	"error_message_0013",
				message_variables	=>	{
					set			=>	$set,
				},
				code			=>	3,
				file			=>	"$THIS_FILE",
				line			=>	__LINE__
			});
		}
	}
	
	return ($self->{USE_BASE_2});
}

# This takes a large number and inserts commas every three characters left of
# the decimal place. This method doesn't take a parameter hash reference.
sub comma
{
	my $self   = shift;
	my $number = shift;
	my $an     = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
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
	if (($whole =~ /\D/) || ($decimal =~ /\D/))
	{
		my $an = $self->parent;
		$an->Alert->error({
			fatal		=>	1,
			title_key	=>	"error_title_0010",
			message_key	=>	"error_message_0014",
			message_variables	=>	{
				number		=>	$number,
			},
			code		=>	4,
			file		=>	"$THIS_FILE",
			line		=>	__LINE__
		});
		# Return nothing in case the user is blocking fatal errors.
		return (undef);
	}
	
	local($_) = $whole ? $whole : "";
	
	1 while s/^(-?\d+)(\d{3})/$1,$2/;
	$whole = $_;
	
	my $return = $decimal ? "$whole.$decimal" : $whole;
	
	return ($return);
}

# Takes a number of seconds and turns it into d/h/m/s
sub time
{
	my $self  = shift;
	my $param = shift;
	return undef if not defined $param;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# Now see if the user passed the values in a hash reference or
	# directly.
	my $time = 0;
	if (ref($param) eq "HASH")
	{
		# Values passed in a hash, good.
		$time = $param->{'time'} ? $param->{'time'} : 0;
	}
	else
	{
		# Values passed directly.
		$time = $param ? $param : 0;
	}
	
	# Exit if 'time' is not defined or set as '--'.
	$param->{'time'} = "--" if not defined $param->{'time'};
	return('--') if $param->{'time'} eq "--";
	
	my $old_time =  $time;
	my $float    =  0;
	my $sign     =  $time =~ /^-/ ? "-" : "";
	$time        =~ s/^-//;
	$time        =~ s/,//g;
	if ($time=~/\./)
	{
		($time, $float) = split/\./, $time, 2;
	}
	
	### TODO: Change the suffixes to 'tools_suffix_XXXX'.
	
	# Die if either the 'time' or 'float' has a non-digit character in it.
	if (($time =~ /\D/) || ($float =~ /\D/))
	{
		$an->Alert->error({
			fatal			=>	1,
			title_key		=>	"error_title_0011",
			title_variables		=>	{
				method			=>	"AN::Tools::Readable->time()",
			},
			message_key		=>	"error_message_0015",
			message_variables	=>	{
				old_time		=>	$old_time,
			},
			code			=>	5,
			file			=>	"$THIS_FILE",
			line			=>	__LINE__
		});
		# Return nothing in case the user is blocking fatal
		# errors.
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

	my $hr_time;
	if ($seconds < 1)
	{
		$hr_time = $float ? "0.${float}s" : "0s";
	}
	else
	{
		$hr_time = sprintf("%01d", $seconds);
		if ( $float > 0 )
		{
			$hr_time .= ".".$float."s";
		}
		else
		{
			$hr_time.="s";
		}
	}
	if ( $rem_min > 0 )
	{
		$hr_time =~ s/ sec.$/s/;
		$hr_time =  sprintf("%01d", $rem_min)."m $hr_time";
	}
	elsif (($hours > 0) || ($days > 0) || ($weeks > 0))
	{
		$hr_time = "0m $hr_time";
	}
	if ( $rem_hours > 0 )
	{
		$hr_time = sprintf("%01d", $rem_hours)."h $hr_time";
	}
	elsif (($days > 0) || ($weeks > 0))
	{
		$hr_time = "0h $hr_time";
	}
	if ( $days > 0 )
	{
		$hr_time = sprintf("%01d", $rem_days)."d $hr_time";
	}
	elsif ($weeks > 0)
	{
		$hr_time = "0d $hr_time";
	}
	if ( $weeks > 0 )
	{
		$weeks   = $an->Readable->comma($weeks);
		$hr_time = $weeks."w $hr_time";
	}
	$hr_time = $sign ? $sign.$hr_time : $hr_time;
	
	return ($hr_time);
}

# Takes a raw number of bytes (whole integer).
sub bytes_to_hr
{
	my $self  = shift;
	my $param = shift;
	return undef if not defined $param;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# Now see if the user passed the values in a hash reference or
	# directly.
	my $size = 0;
	if (ref($param) eq "HASH")
	{
		# Values passed in a hash, good.
		$size = $param->{'bytes'} ? $param->{'bytes'} : 0;
	}
	else
	{
		# Values passed directly.
		$size = $param ? $param : 0;
	}
	
	# Expand exponential numbers.
	if ($size =~ /(\d+)e\+(\d+)/)
	{
		my $base = $1;
		my $exp  = $2;
		$size    = $base;
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
	if ( $hr_size =~ /^-/ )
	{
		$sign    =  "-";
		$hr_size =~ s/^-//;
	}
	$hr_size =~ s/,//g;
	$hr_size =~ s/^\+//g;
	
	# Die if either the 'time' or 'float' has a non-digit character in it.	
	if ($hr_size =~ /\D/)
	{
		$an->Alert->error({
			fatal			=>	1,
			title_key		=>	"error_title_0011",
			title_variables		=>	{
				method			=>	"AN::Tools::Readable->bytes_to_hr()",
			},
			message_key		=>	"error_message_0016",
			message_variables	=>	{
				size			=>	$size,
			},
			code			=>	6,
			file			=>	"$THIS_FILE",
			line			=>	__LINE__
		});
		# Return nothing in case the user is blocking fatal
		# errors.
		return (undef);
	}
	
	# Do the math.
	if ($an->Readable->base2)
	{
		if ($hr_size >= (2 ** 80))
		{
			# Yebibyte
			$hr_size = sprintf("%.3f", ($hr_size /= (2 ** 80)));
			$hr_size = $an->Readable->comma($hr_size);
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
			$hr_size = $an->Readable->comma($hr_size);
			$suffix  = "B";
		}
	}
	else
	{
		if ($hr_size >= (10 ** 24))
		{
			# Yottabyte
			$hr_size = sprintf("%.3f", ($hr_size /= (10 ** 24)));
			$hr_size = $an->Readable->comma($hr_size);
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
			$hr_size = $an->Readable->comma($hr_size);
			$suffix  = "b";
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

# This takes a "human readable" size with an ISO suffix and converts it back to
# a base byte size as accurately as possible.
sub hr_to_bytes
{
	my $self  = shift;
	my $param = shift;
	return undef if not defined $param;
	
	my $an = $self->parent;
	$an->Alert->_set_error;
	
	# Now see if the user passed the values in a hash reference or
	# directly.
	my $size = 0;
	my $type = "";
	if (ref($param) eq "HASH")
	{
		# Values passed in a hash, good.
		$size = $param->{size} ? $param->{size} : 0;
		$type = $param->{type} ? $param->{type} : 0;
	}
	else
	{
		# Values passed directly.
		$size = $param ? $param : 0;
		$type = $_[0]  ? shift  : "";
	}
	$size =~ s/ //g;
	$type =~ s/ //g;
	
	# Store and strip the sign
	my $sign = "";
	if ($size =~ /^-/)
	{
		$sign =  "-";
		$size =~ s/^-//;
	}
	$size =~ s/,//g;
	$size =~ s/^\+//g;
	
	# If I don't have a passed type, see if there is a letter or letters
	# after the size to hack off.
	if ((not $type) && ($size =~ /[a-zA-Z]$/))
	{
		($size, $type) = ($size =~ /^(.*\d)(\D+)/);
	}
	$type = lc($type);
	
	# Make sure that 'size' is now an integer or float.
	if ($size !~ /\d+[\.\d+]?/)
	{
		$an->Alert->error({
			fatal			=>	1,
			title_key		=>	"error_title_0011",
			title_variables		=>	{
				method			=>	"AN::Tools::Readable->hr_to_bytes()",
			},
			message_key		=>	"error_message_0017",
			message_variables	=>	{
				size			=>	$size,
				sign			=>	$sign,
				type			=>	$type,
			},
			code			=>	7,
			file			=>	"$THIS_FILE",
			line			=>	__LINE__
		});
		# Return nothing in case the user is blocking fatal
		# errors.
		return (undef);
	}
	
	# If 'type' is still blank, set it to 'b'.
	$type = "b" if not $type;
	
	# If the type is already bytes, make sure the size is an integer and
	# return.
	if ($type eq "b")
	{
		if ($size =~ /\D/)
		{
			$an->Alert->error({
				fatal			=>	1,
				title_key		=>	"error_title_0011",
				title_variables		=>	{
					method			=>	"AN::Tools::Readable->hr_to_bytes()",
				},
				message_key		=>	"error_message_0018",
				message_variables	=>	{
					size			=>	$size,
					sign			=>	$sign,
					type			=>	$type,
				},
				code			=>	8,
				file			=>	"$THIS_FILE",
				line			=>	__LINE__
			});
		}
		return ($sign.$size);
	}
	
	# If the "type" is "Xib", make sure we're running in Base2 notation.
	# Conversly, if the type is "Xb", make sure that we're running in
	# Base10 notation. In either case, shorten the 'type' to just the first
	# letter to make the next sanity check simpler.
	my $prior_base2 = $an->Readable->base2();
	if ($type =~ /^(\w)ib$/)
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
	
	# Check if we have a valid '$type' and that 'Math::BigInt' is loaded,
	# if the size is big enough to require it.
	if (($type eq "p") || ($type eq "e") || ($type eq "z") || ($type eq "y"))
	{
		# If this is a big size needing "Math::BigInt", check if it's loaded
		# yet and load it, if not.
		if (not $an->_math_bigint_loaded)
		{
			$an->_load_math_bigint();
		}
	}
	elsif (($type ne "t") && ($type ne "g") && ($type ne "m") && ($type ne "k"))
	{
		# If we're here, we didn't match one of the large sizes or any
		# of the other sizes, so die.
		$an->Alert->error({
			fatal			=>	1,
			title_key		=>	"error_title_0012",
			message_key		=>	"",
			message_variables	=>	{
				size			=>	$size,
				type			=>	$type,
			},
			code			=>	10,
			file			=>	"$THIS_FILE",
			line			=>	__LINE__
		});
		# Return nothing in case the user is blocking fatal
		# errors.
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
	
	# Last, round off the byte size if it's a float.
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

1;
