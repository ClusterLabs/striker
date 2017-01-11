package AN::Tools::Validate;
# 
# This module will contain methods used to validate various user inputs.
# 

use strict;
use warnings;
use Data::Dumper;
use Mail::RFC822::Address qw(valid validlist);

our $VERSION  = "0.1.001";
my $THIS_FILE = "Validate.pm";

### Methods;
# is_cron_schedule
# is_email
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

### TODO: This needs a LOT of testing!
# Checks to see if the string is a valid crontab schedule. It returns a transformed/normalized scheduke for
# callers who might want to use it.
sub is_cron_schedule
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "is_email" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $is_valid = 1;
	my $schedule = $parameter->{schedule} ? $parameter->{schedule} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "schedule", value1 => $schedule,
	}, file => $THIS_FILE, line => __LINE__});
	
	if ($schedule =~ /^@(.*)$/)
	{
		# Yup. Convert it to the normal string though.
		my $nickname = $1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "nickname", value1 => $nickname,
		}, file => $THIS_FILE, line => __LINE__});
		
		# @reboot..: Run once after reboot.
		# @yearly..: Run once a year  = "0 0 1 1 *".
		# @annually: Run once a year  = "0 0 1 1 *".
		# @monthly.: Run once a month = "0 0 1 * *".
		# @weekly..: Run once a week  = "0 0 * * 0".
		# @daily...: Run once a day   = "0 0 * * *".
		# @hourly..: Run once an hour = "0 * * * *".
		if (lc($nickname) eq "reboot")
		{
			# Valid and no transformation needed
		}
		elsif ((lc($nickname) eq "yearly") or (lc($nickname) eq "annually"))
		{
			$schedule = "0 0 1 1 *";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "schedule", value1 => $schedule,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (lc($nickname) eq "monthly")
		{
			$schedule = "0 0 1 * *";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "schedule", value1 => $schedule,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (lc($nickname) eq "weekly")
		{
			$schedule = "0 0 * * 0";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "schedule", value1 => $schedule,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (lc($nickname) eq "daily")
		{
			$schedule = "0 0 * * *";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "schedule", value1 => $schedule,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (lc($nickname) eq "hourly")
		{
			# Really?! Oooookay.,,
			$schedule = "0 * * * *";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "schedule", value1 => $schedule,
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Not valid.
			$is_valid = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "is_valid", value1 => $is_valid,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	elsif ($schedule =~ /^(.*?) (.*?) (.*?) (.*?) (.*?)$/)
	{
		### NOTE: All fields may be CSVs, so we'll split on ',' for all five fields. Entries without
		###       commas will be processed as if they were a list of one.
		# field          allowed values
		# -----          --------------
		# minute         0-59
		# hour           0-23
		# day of month   1-31
		# month          1-12 (or names)
		# day of week    0-7 (0 or 7 is Sunday, or use names)
		my $minutes       = $1;
		my $hours         = $2;
		my $days_of_month = $3;
		my $months        = $4;
		my $days_of_week  = $5;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
			name1 => "minutes",       value1 => $minutes,
			name2 => "hours",         value2 => $hours,
			name3 => "days_of_month", value3 => $days_of_month,
			name4 => "months",        value4 => $months,
			name5 => "days_of_week",  value5 => $days_of_week,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Minutes.
		foreach my $minute (split/,/, $minutes)
		{
			# The 'minute' field can be '0-59', ranges and steps.
			if ($minute =~ /^(.*?)\/(.*)$/)
			{
				my $left_side  = $1;
				my $right_side = $2;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "left_side",  value1 => $left_side,
					name2 => "right_side", value2 => $right_side,
				}, file => $THIS_FILE, line => __LINE__});
				
				# The left side is allowed to be '*' or a range, the right side is not.
				if ($left_side =~ /^(\d+)-(\d+)/)
				{
					my $start = $1;
					my $end   = $2;
					if (($start > 59) or ($end > 59))
					{
						# The minute range is invalid
						$is_valid = 0;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "is_valid", value1 => $is_valid,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($left_side =~ /^(\d+)$/)
				{
					# Left side is a single value
					if ($left_side > 59)
					{
						# The minute is invalid
						$is_valid = 0;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "is_valid", value1 => $is_valid,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($left_side ne "*")
				{
					# Not sure what the left side is, but it isn't valid.
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
				
				# The right side can only be a digit. I'm not sure what a sane 
				# maximum is. So we'll only verify that it is a digit and leave it at
				# that. Though anything over '30' doesn't make much sense...
				if ($right_side =~ /\D/)
				{
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
			} 
			elsif ($minute =~ /^(\d+)-(\d+)/)
			{
				# Range.
				my $start = $1;
				my $end   = $2;
				if (($start > 59) or ($end > 59))
				{
					# The minute range is invalid
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($minute =~ /^(\d+)/)
			{
				# It is not a step, evaluate normally
				if ($minute > 59)
				{
					# The minute is invalid
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			else
			{
				# Invalid
				$is_valid = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "is_valid", value1 => $is_valid,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Hours.
		foreach my $hour (split/,/, $hours)
		{
			# The 'hour' field can be '0-23', ranges and steps.
			if ($hour =~ /^(.*?)\/(.*)$/)
			{
				my $left_side  = $1;
				my $right_side = $2;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "left_side",  value1 => $left_side,
					name2 => "right_side", value2 => $right_side,
				}, file => $THIS_FILE, line => __LINE__});
				
				# The left side is allowed to be '*' or a range, the right side is not.
				if ($left_side =~ /^(\d+)-(\d+)/)
				{
					my $start = $1;
					my $end   = $2;
					if (($start > 23) or ($end > 23))
					{
						# The hour range is invalid
						$is_valid = 0;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "is_valid", value1 => $is_valid,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($left_side =~ /^(\d+)$/)
				{
					# Left side is a single value
					if ($left_side > 23)
					{
						# The hour is invalid
						$is_valid = 0;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "is_valid", value1 => $is_valid,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($left_side ne "*")
				{
					# Not sure what the left side is, but it isn't valid.
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
				
				# The right side can only be a digit. I'm not sure what a sane maximum is. So
				# we'll only verify that it is a digit and leave it at that. Though anything 
				# over '6' doesn't make much sense...
				if ($right_side =~ /\D/)
				{
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
			} 
			elsif ($hour =~ /^(\d+)-(\d+)/)
			{
				# Range.
				my $start = $1;
				my $end   = $2;
				if (($start > 23) or ($end > 23))
				{
					# The hour range is invalid
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($hour =~ /^(\d+)/)
			{
				# It is not a step, evaluate normally
				if ($hour > 23)
				{
					# The hour is invalid
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			else
			{
				# Invalid
				$is_valid = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "is_valid", value1 => $is_valid,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Days of the month
		foreach my $day_of_month (split/,/, $days_of_month)
		{
			# The 'day_of_month' field can be '1-31', ranges and steps.
			if ($day_of_month =~ /^(.*?)\/(.*)$/)
			{
				my $left_side  = $1;
				my $right_side = $2;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "left_side",  value1 => $left_side,
					name2 => "right_side", value2 => $right_side,
				}, file => $THIS_FILE, line => __LINE__});
				
				# The left side is allowed to be '*' or a range, the right side is not.
				if ($left_side =~ /^(\d+)-(\d+)/)
				{
					my $start = $1;
					my $end   = $2;
					if ((not $start) or (not $end) or ($start > 31) or ($end > 31))
					{
						# The day_of_month range is invalid
						$is_valid = 0;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "is_valid", value1 => $is_valid,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($left_side =~ /^(\d+)$/)
				{
					# Left side is a single value
					if ((not $left_side) or ($left_side > 12))
					{
						# The day_of_month is invalid
						$is_valid = 0;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "is_valid", value1 => $is_valid,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($left_side ne "*")
				{
					# Not sure what the left side is, but it isn't valid.
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
				
				# The right side can only be a digit. I'm not sure what a sane maximum is. So
				# we'll only verify that it is a digit and leave it at that. Though anything 
				# over '15' doesn't make much sense...
				if ($right_side =~ /\D/)
				{
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
			} 
			elsif ($day_of_month =~ /^(\d+)-(\d+)/)
			{
				# Range.
				my $start = $1;
				my $end   = $2;
				if ((not $start) or (not $end) or ($start > 31) or ($end > 31))
				{
					# The day_of_month range is invalid
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($day_of_month =~ /^(\d+)/)
			{
				# It is not a step, evaluate normally
				if ((not $day_of_month) or ($day_of_month > 31))
				{
					# The day_of_month is invalid
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			else
			{
				# Invalid
				$is_valid = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "is_valid", value1 => $is_valid,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Months.
		foreach my $month (split/,/, $months)
		{
			### NOTE: Cron expects just the first three letters. We'll be less strict. In any
			###       case, we will transform the names to numbers,
			# Transform the month, if needed.
			if    ($month =~ /^jan/i) { $month = 1; }
			elsif ($month =~ /^feb/i) { $month = 2; }
			elsif ($month =~ /^mar/i) { $month = 3; }
			elsif ($month =~ /^apr/i) { $month = 4; }
			elsif ($month =~ /^may/i) { $month = 5; }
			elsif ($month =~ /^jun/i) { $month = 6; }
			elsif ($month =~ /^jul/i) { $month = 7; }
			elsif ($month =~ /^aug/i) { $month = 8; }
			elsif ($month =~ /^sep/i) { $month = 9; }
			elsif ($month =~ /^oct/i) { $month = 10; }
			elsif ($month =~ /^nov/i) { $month = 11; }
			elsif ($month =~ /^dec/i) { $month = 12; }
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "month", value1 => $month,
			}, file => $THIS_FILE, line => __LINE__});
			
			# The 'month' field can be '1-12', ranges and steps.
			if ($month =~ /^(.*?)\/(.*)$/)
			{
				my $left_side  = $1;
				my $right_side = $2;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "left_side",  value1 => $left_side,
					name2 => "right_side", value2 => $right_side,
				}, file => $THIS_FILE, line => __LINE__});
				
				# The left side is allowed to be '*' or a range, the right side is not.
				if ($left_side =~ /^(\d+)-(\d+)/)
				{
					my $start = $1;
					my $end   = $2;
					if ((not $start) or (not $end) or ($start > 12) or ($end > 12))
					{
						# The month range is invalid
						$is_valid = 0;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "is_valid", value1 => $is_valid,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($left_side =~ /^(\d+)$/)
				{
					# Left side is a single value
					if ((not $left_side) or ($left_side > 12))
					{
						# The month is invalid
						$is_valid = 0;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "is_valid", value1 => $is_valid,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($left_side ne "*")
				{
					# Not sure what the left side is, but it isn't valid.
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
				
				# The right side can only be a digit. I'm not sure what a sane maximum is. So
				# we'll only verify that it is a digit and leave it at that. Though anything 
				# over '6' doesn't make much sense...
				if ($right_side =~ /\D/)
				{
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
			} 
			elsif ($month =~ /^(\d+)-(\d+)/)
			{
				# Range.
				my $start = $1;
				my $end   = $2;
				if ((not $start) or (not $end) or ($start > 12) or ($end > 12))
				{
					# The month range is invalid
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($month =~ /^(\d+)/)
			{
				# It is not a step, evaluate normally
				if ((not $month) or ($month > 12))
				{
					# The month is invalid
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			else
			{
				# Invalid
				$is_valid = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "is_valid", value1 => $is_valid,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Days of the week.
		foreach my $day_of_week (split/,/, $days_of_week)
		{
			# Transform the day, if needed. Note that '7' is valid for 'Sunday', but we'll 
			# normalize it to '0'.
			if    ($day_of_week =~ /^sun/i) { $day_of_week = 0; }
			elsif ($day_of_week =~ /^mon/i) { $day_of_week = 1; }
			elsif ($day_of_week =~ /^tue/i) { $day_of_week = 2; }
			elsif ($day_of_week =~ /^wed/i) { $day_of_week = 3; }
			elsif ($day_of_week =~ /^thu/i) { $day_of_week = 4; }
			elsif ($day_of_week =~ /^fri/i) { $day_of_week = 5; }
			elsif ($day_of_week =~ /^sat/i) { $day_of_week = 6; }
			elsif ($day_of_week eq "7")     { $day_of_week = 0; }
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "day_of_week", value1 => $day_of_week,
			}, file => $THIS_FILE, line => __LINE__});
			
			# The 'day_of_week' field can be '0-6', ranges and steps.
			if ($day_of_week =~ /^(.*?)\/(.*)$/)
			{
				my $left_side  = $1;
				my $right_side = $2;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "left_side",  value1 => $left_side,
					name2 => "right_side", value2 => $right_side,
				}, file => $THIS_FILE, line => __LINE__});
				
				# The left side is allowed to be '*' or a range, the right side is not.
				if ($left_side =~ /^(\d+)-(\d+)/)
				{
					my $start = $1;
					my $end   = $2;
					if (($start > 6) or ($end > 6))
					{
						# The day_of_week range is invalid
						$is_valid = 0;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "is_valid", value1 => $is_valid,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($left_side =~ /^(\d+)$/)
				{
					# Left side is a single value
					if ($left_side > 6)
					{
						# The day_of_week is invalid
						$is_valid = 0;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "is_valid", value1 => $is_valid,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($left_side ne "*")
				{
					# Not sure what the left side is, but it isn't valid.
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
				
				# The right side can only be a digit. I'm not sure what a sane maximum is. So
				# we'll only verify that it is a digit and leave it at that. Though anything 
				# over '6' doesn't make much sense...
				if ($right_side =~ /\D/)
				{
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
			} 
			elsif ($day_of_week =~ /^(\d+)-(\d+)/)
			{
				# Range.
				my $start = $1;
				my $end   = $2;
				if (($start > 6) or ($end > 6))
				{
					# The day_of_week range is invalid
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($day_of_week =~ /^(\d+)/)
			{
				# It is not a step, evaluate normally
				if ($day_of_week > 6)
				{
					# The day_of_week is invalid
					$is_valid = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "is_valid", value1 => $is_valid,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			else
			{
				# Invalid
				$is_valid = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "is_valid", value1 => $is_valid,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	else
	{
		# Malformed.
		$is_valid = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "is_valid", value1 => $is_valid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "is_valid", value1 => $is_valid,
	}, file => $THIS_FILE, line => __LINE__});
	return($is_valid);
}

# Check to see if the string is a valid email
sub is_email
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "is_email" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $email = $parameter->{email} ? $parameter->{email} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "email", value1 => $email,
	}, file => $THIS_FILE, line => __LINE__});
	
	# We cheat here by using Mail::RFC822::Address because trying to be thorough with email regex is a 
	# fool's errand.
	my $valid = 0;
	if (valid($email))
	{
		$valid = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "valid", value1 => $valid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "valid", value1 => $valid,
	}, file => $THIS_FILE, line => __LINE__});
	return($valid);
}

# Check to see if the string looks like a valid hostname
sub is_domain_name
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "is_domain_name" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $name = $parameter->{name} ? $parameter->{name} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "name", value1 => $name,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $valid = 1;
	if (not $name)
	{
		$valid = 0;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "valid", value1 => $valid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif (($name !~ /^((([a-z]|[0-9]|\-)+)\.)+([a-z])+$/i) && (($name !~ /^\w+$/) && ($name !~ /-/)))
	{
		# Doesn't appear to be valid.
		$valid = 0;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "valid", value1 => $valid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "is_integer_or_unsigned_float" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $number = $parameter->{number} ? $parameter->{number} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "number", value1 => $number,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $valid = 1;
	if ($number =~ /^\D/)
	{
		# Non-digit could mean it is signed or just garbage.
		$valid = 0;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "valid", value1 => $valid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif (($number !~ /^\d+$/) && ($number != /^\d+\.\d+$/))
	{
		# Not an integer or float
		$valid = 0;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "valid", value1 => $valid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "is_ipv4" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ip = $parameter->{ip} ? $parameter->{ip} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "ip", value1 => $ip,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $valid = 1;
	if ($ip =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/)
	{
		# It is in the right format.
		my $first_octal  = $1;
		my $second_octal = $2;
		my $third_octal  = $3;
		my $fourth_octal = $4;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "first_octal",  value1 => $first_octal,
			name2 => "second_octal", value2 => $second_octal,
			name3 => "third_octal",  value3 => $third_octal,
			name4 => "fourth_octal", value4 => $fourth_octal,
		}, file => $THIS_FILE, line => __LINE__});
		
		if (($first_octal  < 0) or ($first_octal  > 255) or
		    ($second_octal < 0) or ($second_octal > 255) or
		    ($third_octal  < 0) or ($third_octal  > 255) or
		    ($fourth_octal < 0) or ($fourth_octal > 255))
		{
			# One of the octals is out of range.
			$valid = 0;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "valid", value1 => $valid,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	else
	{
		# Not in the right format.
		$valid = 0;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "valid", value1 => $valid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "is_url" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $url = $parameter->{url} ? $parameter->{url} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "url", value1 => $url,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $valid = 1;
	if (not $url)
	{
		$valid = 0;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "valid", value1 => $valid,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($url =~ /^(.*?):\/\/(.*?)\/(.*)$/)
	{
		my $protocol = $1;
		my $host     = $2;
		my $path     = $3;
		my $port     = "";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "protocol", value1 => $protocol,
			name2 => "host",     value2 => $host,
			name3 => "path",     value3 => $path,
			name4 => "port",     value4 => $port,
		}, file => $THIS_FILE, line => __LINE__});
		if ($protocol eq "http")
		{
			$port = 80;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "port", value1 => $port,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($protocol eq "https")
		{
			$port = 443;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "port", value1 => $port,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($protocol eq "ftp")
		{
			$port = 21;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "port", value1 => $port,
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Invalid protocol
			$valid = 0;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "valid", value1 => $valid,
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($host =~ /^(.*?):(\d+)$/)
		{
			$host = $1;
			$port = $2;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "host", value1 => $host,
				name2 => "port", value2 => $port,
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($host =~ /^\d+\.\d+\.\d+\.\d+/)
		{
			if (not $an->Validate->is_ipv4({ip => $host}))
			{
				$valid = 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "valid", value1 => $valid,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		else
		{
			if (not $an->Validate->is_domain_name({name => $host}))
			{
				$valid = 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "valid", value1 => $valid,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
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
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "is_uuid" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
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
