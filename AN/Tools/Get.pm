package AN::Tools::Get;

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Get.pm";


sub new
{
	#print "$THIS_FILE ".__LINE__."; In AN::Get->new()\n";
	my $class = shift;
	
	my $self  = {
		USE_24H		=>	1,
		SAY		=>	{
			AM		=>	"am",
			PM		=>	"pm",
		},
		SEPERATOR	=>	{
			DATE		=>	"-",
			TIME		=>	":",
		},
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

# Sets/returns the "am" suffix.
sub say_am
{
	my $self = shift;
	my $say  = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	if ( defined $say )
	{
		$self->{SAY}->{AM} = $say;
	}
	
	return $self->{SAY}->{AM};
}

# Sets/returns the "pm" suffix.
sub say_pm
{
	my $self = shift;
	my $say  = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	if ( defined $say )
	{
		$self->{SAY}->{PM} = $say;
	}
	
	return $self->{SAY}->{PM};
}

# Sets/returns the date separator.
sub date_seperator
{
	my $self=shift;
	my $symbol=shift;
	
	# This just makes the code more consistent.
	my $an=$self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	if ( defined $symbol )
	{
		$self->{SEPERATOR}->{DATE}=$symbol;
	}
	
	return $self->{SEPERATOR}->{DATE};
}

# Sets/returns the time separator.
sub time_seperator
{
	my $self   = shift;
	my $symbol = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	if ( defined $symbol )
	{
		$self->{SEPERATOR}->{TIME} = $symbol;
	}
	
	return $self->{SEPERATOR}->{TIME};
}

# This sets/returns whether to use 24-hour or 12-hour, am/pm notation.
sub use_24h
{
	my $self    = shift;
	my $use_24h = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	if (defined $use_24h)
	{
		if (( $use_24h == 0 ) || ( $use_24h == 1 ))
		{
			$self->{USE_24H} = $use_24h;
		}
		else
		{
			die "The 'use_24h' method must be passed a '0' or '1' value only.\n";
		}
	}
	
	return $self->{USE_24H};
}

# This returns the date and time based on the given unix-time.
sub date_and_time
{
	my $self  = shift;
	my $param = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# Set default values then check for passed parameters to over-write
	# them with.
	my ($offset, $use_time, $require_weekday, $skip_weekends);
	
	# Now see if the user passed the values in a hash reference or
	# directly.
	if (ref($param) eq "HASH")
	{
		# Values passed in a hash, good.
		$offset		 = $param->{offset}		? $param->{offset} : 0;
		$use_time	 = $param->{use_time}		? $param->{use_time} : time;
		$require_weekday = $param->{require_weekday}	? $param->{require_weekday} : 0;
		$skip_weekends	 = $param->{skip_weekends}	? $param->{skip_weekends} : 0;
	}
	else
	{
		# Values passed directly.
		$offset		 = defined $param ? $param : 0;
		$use_time	 = defined $_[0] ? $_[0] : time;
		$require_weekday = defined $_[1] ? $_[1] : "";
		$skip_weekends	 = defined $_[2] ? $_[2] : "";
	}
	
	# Do my initial calculation.
	my %time          = ();
	my $adjusted_time = $use_time+$offset;
	($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);

	# If I am set to skip weekends and I land on a weekend, simply add 48
	# hours. This is useful when you need to move X-weekdays.
	if (($skip_weekends) && ($offset))
	{
		# First thing I need to know is how many weekends pass between
		# now and the requested date. So to start, how many days are we
		# talking about?
		my $difference   = 0;			# Hold the accumulated days in seconds.
		my $local_offset = $offset;		# Local offset I can mess with.
		my $day          = 24 * 60 * 60;	# For clarity.
		my $week         = $day * 7;		# For clarity.
		
		# As I proceed, 'local_time' will be subtracted as I account
		# for time and 'difference' will increase to account for known
		# weekend days.
		if ($local_offset =~ /^-/)
		{
			### Go back in time...
			$local_offset =~ s/^-//;
			
			# First, how many seconds have passed today?
			my $seconds_passed_today = $time{sec} + ($time{min}*60) + ($time{hour}*60*60);
			
			# Now, get the number of seconds in the offset beyond
			# an even day. This is compared to the seconds passed
			# in this day. If greater, I count an extra day.
			my $local_offset_second_over_day =  $local_offset % $day;
			$local_offset                    -= $local_offset_second_over_day;
			my $local_offset_days            =  $local_offset / $day;
			$local_offset_days++ if $local_offset_second_over_day > $seconds_passed_today;
			
			# If the number of days is greater than one week, add
			# two days to the 'difference' for every seven days and
			# reduce 'local_offset_days' to the number of days
			# beyond the given number of weeks.
			my $local_offset_remaining_days = $local_offset_days;
			if ($local_offset_days > 7)
			{
				# Greater than a week, do the math.
				$local_offset_remaining_days =  $local_offset_days % 7;
				$local_offset_days           -= $local_offset_remaining_days;
				my $weeks_passed             =  $local_offset_days / 7;
				$difference                  += ($weeks_passed * (2 * $day));
			}
			
			# If I am currently in a weekend, add two days.
			if (($time{wday} == 6) || ($time{wday} == 0))
			{
				$difference += (2 * $day);
			}
			else
			{
				# Compare 'local_offset_remaining_days' to
				# today's day. If greater, I've passed a
				# weekend and need to add two days to
				# 'difference'.
				my $today_day = (localtime())[6];
				if ($local_offset_remaining_days > $today_day)
				{
					$difference+=(2 * $day);
				}
			}
			
			# If I have a difference, recalculate the offset date.
			if ($difference)
			{
				my $new_offset = ($offset - $difference);
				$adjusted_time = ($use_time + $new_offset);
				($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);
			}
		}
		else
		{
			### Go forward in time...
			# First, how many seconds are left in today?
			my $left_hours            = 23 - $time{hour};
			my $left_minutes          = 59 - $time{min};
			my $left_seconds          = 59 - $time{sec};
			my $seconds_left_in_today = $left_seconds + ($left_minutes*60) + ($left_hours*60*60);
			
			# Now, get the number of seconds in the offset beyond
			# an even day. This is compared to the seconds left in
			# this day. If greater, I count an extra day.
			my $local_offset_second_over_day =  $local_offset % $day;
			$local_offset                    -= $local_offset_second_over_day;
			my $local_offset_days            =  $local_offset / $day;
			$local_offset_days++ if $local_offset_second_over_day > $seconds_left_in_today;
			
			# If the number of days is greater than one week, add
			# two days to the 'difference' for every seven days and
			# reduce 'local_offset_days' to the number of days
			# beyond the given number of weeks.
			my $local_offset_remaining_days = $local_offset_days;
			if ($local_offset_days > 7)
			{
				# Greater than a week, do the math.
				$local_offset_remaining_days =  $local_offset_days % 7;
				$local_offset_days           -= $local_offset_remaining_days;
				my $weeks_passed             =  $local_offset_days / 7;
				$difference                  += ($weeks_passed * (2 * $day));
			}
			
			# If I am currently in a weekend, add two days.
			if (($time{wday} == 6) || ($time{wday} == 0))
			{
				$difference += (2 * $day);
			}
			else
			{
				# Compare 'local_offset_remaining_days' to
				# 5 minus today's day to get the number of days
				# until the weekend. If greater, I've crossed a
				# weekend and need to add two days to
				# 'difference'.
				my $today_day=(localtime())[6];
				my $days_to_weekend=5 - $today_day;
				if ($local_offset_remaining_days > $days_to_weekend)
				{
					$difference+=(2 * $day);
				}
			}
			
			# If I have a difference, recalculate the offset date.
			if ($difference)
			{
				my $new_offset = ($offset + $difference);
				$adjusted_time = ($use_time + $new_offset);
				($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);
			}
		}
	}

	# If the 'require_weekday' is set and if 'time{wday}' is 0 (Sunday) or
	# 6 (Saturday), set or increase the offset by 24 or 48 hours.
	if (($require_weekday) && (( $time{wday} == 0 ) || ( $time{wday} == 6 )))
	{
		# The resulting day is a weekend and the require weekday was
		# set.
		$adjusted_time = $use_time + ($offset + (24 * 60 * 60));
		($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);
		
		# I don't check for the date and adjust automatically because I
		# don't know if I am going forward or backwards in the calander.
		if (( $time{wday} == 0 ) || ( $time{wday} == 6 ))
		{
			# Am I still ending on a weekday?
			$adjusted_time = $use_time + ($offset + (48 * 60 * 60));
			($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);
		}
	}

	# Increment the month by one.
	$time{mon}++;
	
	# Parse the 12/24h time components.
	if ($self->use_24h)
	{
		# 24h time.
		$time{pad_hour} = sprintf("%02d", $time{hour});
		$time{suffix}   = "";
	}
	else
	{
		# 12h am/pm time.
		if ( $time{hour} == 0 )
		{
			$time{pad_hour} = 12;
			$time{suffix}   = " ".$self->say_am;
		}
		elsif ( $time{hour} < 12 )
		{
			$time{pad_hour} = $time{hour};
			$time{suffix}   = " ".$self->say_am;
		}
		else
		{
			$time{pad_hour} = ($time{hour}-12);
			$time{suffix}   = " ".$self->say_pm;
		}
		$time{pad_hour} = sprintf("%02d", $time{pad_hour});
	}
	
	# Now parse the global components.
	$time{pad_min}  = sprintf("%02d", $time{min});
	$time{pad_sec}  = sprintf("%02d", $time{sec});
	$time{year}     = ($time{year} + 1900);
	$time{pad_mon}  = sprintf("%02d", $time{mon});
	$time{pad_mday} = sprintf("%02d", $time{mday});
	$time{mon}++;
	
	my $date = $time{year}.$self->date_seperator.$time{pad_mon}.$self->date_seperator.$time{pad_mday};
	my $time = $time{pad_hour}.$self->time_seperator.$time{pad_min}.$self->time_seperator.$time{pad_sec}.$time{suffix};
	
	return ($date, $time);
}

# This returns the RAM used by the passed in PID. If not PID was passed, it 
# returns the RAM used by the parent process.
sub get_ram_used_by_pid
{
	my $self  = shift;
	my $param = shift;
	
	# This just makes the code more consistent.
	my $an = $self->parent;
	
	# Clear any prior errors as I may set one here.
	$an->Alert->_set_error;
	
	# What PID?
	my $pid = $param->{pid} ? $param->{pid} : $$;
	
	my $total_bytes = 0;
	my $shell_call  = $an->data->{path}{pmap}." $pid 2>&1 |";
	open (my $file_handle, $shell_call) or $an->Alert->error({fatal => 1, title_key => "an_0003", message_key => "error_title_0014", message_variables => { shell_call => $shell_call, error => $! }, code => 2, file => "$THIS_FILE", line => __LINE__ });
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => ">> line", value1 => "$line"
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
		
		next if $line !~ /total/;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => "$line"
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
		
		# Dig out the PID
		my $kilobytes   =  ($line =~ /total (\d+)K/i)[0];
		my $bytes       =  ($kilobytes * 1024);
		   $total_bytes += $bytes;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "kilobytes",   value1 => "$kilobytes", 
			name2 => "bytes",       value2 => "$bytes", 
			name3 => "total_bytes", value3 => "$total_bytes"
		}, file => $THIS_FILE, line => __LINE__, log_to => $an->data->{path}{log_file}});
	}
	close $file_handle;
	
	return($total_bytes);
}

1;
