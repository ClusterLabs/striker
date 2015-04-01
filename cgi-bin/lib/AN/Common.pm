package AN::Common;
#
# This will store general purpose functions.
# 

use strict;
use warnings;
use IO::Handle;
use Encode;
use CGI;
use utf8;
use Term::ReadKey;
use XML::Simple qw(:strict);

use AN::Cluster;

# Set static variables.
my $THIS_FILE = 'AN::Cluster.pm';


# This takes an integer and, if it is a valid CIDR range, returns the 
# dotted-decimal equivalent. If it's not, it returns '#!INVALID!#'.
sub convert_cidr_to_dotted_decimal
{
	my ($conf, $netmask) = @_;
	
	if ($netmask =~ /^\d{1,2}$/)
	{
		# Make sure it's a (useful) CIDR
		if (($netmask >= 1) && ($netmask <= 32))
		{
			# 0 and 31 are useless in Striker
			if    ($netmask == 1)  { $netmask = "128.0.0.0"; }
			elsif ($netmask == 2)  { $netmask = "192.0.0.0"; }
			elsif ($netmask == 3)  { $netmask = "224.0.0.0"; }
			elsif ($netmask == 4)  { $netmask = "240.0.0.0"; }
			elsif ($netmask == 5)  { $netmask = "248.0.0.0"; }
			elsif ($netmask == 6)  { $netmask = "252.0.0.0"; }
			elsif ($netmask == 7)  { $netmask = "254.0.0.0"; }
			elsif ($netmask == 8)  { $netmask = "255.0.0.0"; }
			elsif ($netmask == 9)  { $netmask = "255.128.0.0"; }
			elsif ($netmask == 10) { $netmask = "255.192.0.0"; }
			elsif ($netmask == 11) { $netmask = "255.224.0.0"; }
			elsif ($netmask == 12) { $netmask = "255.240.0.0"; }
			elsif ($netmask == 13) { $netmask = "255.248.0.0"; }
			elsif ($netmask == 14) { $netmask = "255.252.0.0"; }
			elsif ($netmask == 15) { $netmask = "255.254.0.0"; }
			elsif ($netmask == 16) { $netmask = "255.255.0.0"; }
			elsif ($netmask == 17) { $netmask = "255.255.128.0"; }
			elsif ($netmask == 18) { $netmask = "255.255.192.0"; }
			elsif ($netmask == 19) { $netmask = "255.255.224.0"; }
			elsif ($netmask == 20) { $netmask = "255.255.240.0"; }
			elsif ($netmask == 21) { $netmask = "255.255.248.0"; }
			elsif ($netmask == 22) { $netmask = "255.255.252.0"; }
			elsif ($netmask == 23) { $netmask = "255.255.254.0"; }
			elsif ($netmask == 24) { $netmask = "255.255.255.0"; }
			elsif ($netmask == 25) { $netmask = "255.255.255.128"; }
			elsif ($netmask == 26) { $netmask = "255.255.255.192"; }
			elsif ($netmask == 27) { $netmask = "255.255.255.224"; }
			elsif ($netmask == 28) { $netmask = "255.255.255.240"; }
			elsif ($netmask == 29) { $netmask = "255.255.255.248"; }
			elsif ($netmask == 30) { $netmask = "255.255.255.252"; }
			elsif ($netmask == 32) { $netmask = "255.255.255.255"; }
			else
			{
				$netmask = "#!INVALID!#";
			}
		}
		else
		{
			$netmask = "#!INVALID!#";
		}
	}
	
	return($netmask);
}

# This takes a dotted-decimal subnet mask and converts it to it's CIDR
# equivalent. If it's not, it returns '#!INVALID!#'.
sub convert_dotted_decimal_to_cidr
{
	my ($conf, $netmask) = @_;
	
	if    ($netmask eq "128.0.0.0")       { $netmask = 1; }
	elsif ($netmask eq "192.0.0.0")       { $netmask = 2; }
	elsif ($netmask eq "224.0.0.0")       { $netmask = 3; }
	elsif ($netmask eq "240.0.0.0")       { $netmask = 4; }
	elsif ($netmask eq "248.0.0.0")       { $netmask = 5; }
	elsif ($netmask eq "252.0.0.0")       { $netmask = 6; }
	elsif ($netmask eq "254.0.0.0")       { $netmask = 7; }
	elsif ($netmask eq "255.0.0.0")       { $netmask = 8; }
	elsif ($netmask eq "255.128.0.0")     { $netmask = 9; }
	elsif ($netmask eq "255.192.0.0")     { $netmask = 10; }
	elsif ($netmask eq "255.224.0.0")     { $netmask = 11; }
	elsif ($netmask eq "255.240.0.0")     { $netmask = 12; }
	elsif ($netmask eq "255.248.0.0")     { $netmask = 13; }
	elsif ($netmask eq "255.252.0.0")     { $netmask = 14; }
	elsif ($netmask eq "255.254.0.0")     { $netmask = 15; }
	elsif ($netmask eq "255.255.0.0")     { $netmask = 16; }
	elsif ($netmask eq "255.255.128.0")   { $netmask = 17; }
	elsif ($netmask eq "255.255.192.0")   { $netmask = 18; }
	elsif ($netmask eq "255.255.224.0")   { $netmask = 19; }
	elsif ($netmask eq "255.255.240.0")   { $netmask = 20; }
	elsif ($netmask eq "255.255.248.0")   { $netmask = 21; }
	elsif ($netmask eq "255.255.252.0")   { $netmask = 22; }
	elsif ($netmask eq "255.255.254.0")   { $netmask = 23; }
	elsif ($netmask eq "255.255.255.0")   { $netmask = 24; }
	elsif ($netmask eq "255.255.255.128") { $netmask = 25; }
	elsif ($netmask eq "255.255.255.192") { $netmask = 26; }
	elsif ($netmask eq "255.255.255.224") { $netmask = 27; }
	elsif ($netmask eq "255.255.255.240") { $netmask = 28; }
	elsif ($netmask eq "255.255.255.248") { $netmask = 29; }
	elsif ($netmask eq "255.255.255.252") { $netmask = 30; }
	elsif ($netmask eq "255.255.255.255") { $netmask = 32; }
	else
	{
		$netmask = "#!INVALID!#";
	}
	
	return($netmask);
}

# This creates an 'expect' script for an rsync call.
sub create_rsync_wrapper
{
	my ($conf, $node) = @_;
	
	my $cluster = $conf->{cgi}{cluster};
	my $root_pw = $conf->{clusters}{$cluster}{root_pw};
	my $shell_call = "
echo '#!/usr/bin/expect' > ~/rsync.$node
echo 'set timeout 3600' >> ~/rsync.$node
echo 'eval spawn rsync \$argv' >> ~/rsync.$node
echo 'expect \"password:\" \{ send \"$root_pw\\n\" \}' >> ~/rsync.$node
echo 'expect eof' >> ~/rsync.$node
chmod 755 ~/rsync.$node;";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		print $_;
	}
	close $file_handle;
	
	return(0);
}

# This checks to see if we've see the peer before and if not, add it's ssh
# fingerprint to known_hosts
sub test_ssh_fingerprint
{
	my ($conf, $node) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; test_ssh_fingerprint(); node: [$node]\n");
	
	### TODO: This won't detect when the target's SSH key changed after a
	###       node was replaced! Need to fix this.
	my $failed     = 0;
	my $cluster    = $conf->{cgi}{cluster};
	my $root_pw    = $conf->{clusters}{$cluster}{root_pw};
	my $shell_call = "grep ^\"$node\[, \]\" ~/.ssh/known_hosts -q; echo rc:\$?";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call] as user: [$<]\n");
	open (my $file_handle, '-|', "$shell_call 2>&1") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		   $line =~ s/\n/ /g;
		   $line =~ s/\r/ /g;
		   $line =~ s/\s+$//;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			if ($rc eq "0")
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node] already in '~/.ssh/known_hosts'.\n");
				last;
			}
			elsif (($rc eq "1") or ($rc eq "2"))
			{
				if ($rc eq "1")
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node] not in '~/.ssh/known_hosts', adding.\n");
				}
				else
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The '~/.ssh/known_hosts' file doesn't exist, creating it and adding node: [$node].\n");
				}
				# Add fingerprint to known_hosts
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; authenticity of host message\n");
				my $message = get_string($conf, {key => "message_0279", variables => {
					node	=>	$node,
				}});
				print template($conf, "common.html", "generic-note", {
					message	=>	$message,
				});
				#print "Trying to add the node: <span class=\"fixed_width\">$node</span>'s ssh fingerprint to my list of known hosts...<br />";
				#print template($conf, "common.html", "shell-output-header");
				my $shell_call = "$conf->{path}{'ssh-keyscan'} $node 2>&1 >> ~/.ssh/known_hosts";
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call] as user: [$<]\n");
				open (my $file_handle, '-|', "$shell_call 2>&1") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
				while(<$file_handle>)
				{
					chomp;
					my $line = $_;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
				}
				close $file_handle;
				sleep 5;
			}
		}
	}
	close $file_handle;

	return($failed);
}

# This simply sorts out the current directory the program is running in.
sub get_current_directory
{
	my ($conf) = @_;
	
	my $current_dir = "/var/www/html/";
	if ($ENV{DOCUMENT_ROOT})
	{
		$current_dir = $ENV{DOCUMENT_ROOT};
	}
	elsif ($ENV{CONTEXT_DOCUMENT_ROOT})
	{
		$current_dir = $ENV{CONTEXT_DOCUMENT_ROOT};
	}
	elsif ($ENV{PWD})
	{
		$current_dir = $ENV{PWD};
	}
	
	return($current_dir);
}

# This returns the date and time based on the given unix-time.
sub get_date_and_time
{
	my ($conf, $variables) = @_;
	
	# Set default values then check for passed parameters to over-write
	# them with.
	my $offset          = $variables->{offset}          ? $variables->{offset}          : 0;
	my $use_time        = $variables->{use_time}        ? $variables->{use_time}        : time;
	my $require_weekday = $variables->{require_weekday} ? $variables->{require_weekday} : 0;
	my $skip_weekends   = $variables->{skip_weekends}   ? $variables->{skip_weekends}   : 0;
	my $use_24h         = $variables->{use_24h}         ? $variables->{use_24h}         : $conf->{sys}{use_24h};
	
	# Do my initial calculation.
	my %time          = ();
	my $adjusted_time = $use_time + $offset;
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
			my $seconds_passed_today = $time{sec} + ($time{min} * 60) + ($time{hour} * 60 * 60);
			
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
			my $seconds_left_in_today = $left_seconds + ($left_minutes * 60) + ($left_hours * 60 * 60);
			
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
				my $today_day       = (localtime())[6];
				my $days_to_weekend = 5 - $today_day;
				if ($local_offset_remaining_days > $days_to_weekend)
				{
					$difference += (2 * $day);
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
	if (($require_weekday) && (($time{wday} == 0) || ($time{wday} == 6)))
	{
		# The resulting day is a weekend and the require weekday was
		# set.
		$adjusted_time = $use_time + ($offset + (24 * 60 * 60));
		($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);
		
		# I don't check for the date and adjust automatically because I
		# don't know if I am going forward or backwards in the calander.
		if (($time{wday} == 0) || ($time{wday} == 6))
		{
			# Am I still ending on a weekday?
			$adjusted_time = $use_time + ($offset + (48 * 60 * 60));
			($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);
		}
	}

	# Increment the month by one.
	$time{mon}++;
	
	# Parse the 12/24h time components.
	if ($use_24h)
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
			$time{suffix}   = " am";
		}
		elsif ( $time{hour} < 12 )
		{
			$time{pad_hour} = $time{hour};
			$time{suffix}   = " am";
		}
		else
		{
			$time{pad_hour} = ($time{hour}-12);
			$time{suffix}   = " pm";
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
	
	my $date = $time{year}.$conf->{sys}{date_seperator}.$time{pad_mon}.$conf->{sys}{date_seperator}.$time{pad_mday};
	my $time = $time{pad_hour}.$conf->{sys}{time_seperator}.$time{pad_min}.$conf->{sys}{time_seperator}.$time{pad_sec}.$time{suffix};
	
	return($date, $time);
}

# This pulls out all of the configured languages from the 'strings.xml' file
# and returns them as an array reference with comma-separated "key,name" 
# values.
sub get_languages
{
	my ($conf) = @_;
	my $language_options = [];
	
	foreach my $key (sort {$a cmp $b} keys %{$conf->{string}{lang}})
	{
		my $name = $conf->{string}{lang}{$key}{lang}{long_name};
		push @{$language_options}, "$key,$name";
	}
	
	return($language_options);
}

# This takes a string key and returns the string for the currently active
# language.
sub get_string
{
	my ($conf, $vars) = @_;
	#print __LINE__."; vars: [$vars]\n";
	
	my $key       = $vars->{key};
	my $language  = $vars->{language}  ? $vars->{language}  : $conf->{sys}{language};
	my $variables = $vars->{variables} ? $vars->{variables} : "";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; key: [$key], language: [$language], variables: [$variables]\n");
	
	if (not $key)
	{
		hard_die($conf, $THIS_FILE, __LINE__, 2, "No string key was passed into common.lib's 'get_string()' function.\n");
	}
	if (not $language)
	{
		hard_die($conf, $THIS_FILE, __LINE__, 3, "No language key was set when trying to build a string in common.lib's 'get_string()' function.\n");
	}
	elsif (not exists $conf->{string}{lang}{$language})
	{
		hard_die($conf, $THIS_FILE, __LINE__, 4, "The language key: [$language] does not exist in the 'strings.xml' file.\n");
	}
	my $say_language = $language;
	#print __LINE__."; 2. say_language: [$say_language]\n";
	if ($conf->{string}{lang}{$language}{lang}{long_name})
	{
		$say_language = "$language ($conf->{string}{lang}{$language}{lang}{long_name})";
		#print __LINE__."; 2. say_language: [$say_language]\n";
	}
	if (($variables) && (ref($variables) ne "HASH"))
	{
		hard_die($conf, $THIS_FILE, __LINE__, 5, "The 'variables' string passed into common.lib's 'get_string()' function is not a hash reference. The string's data is: [$variables].\n");
	}
	
	#print "$THIS_FILE ".__LINE__."; string::lang::${language}::key::${key}::content: [$conf->{string}{lang}{$language}{key}{$key}{content}]\n";
	if (not exists $conf->{string}{lang}{$language}{key}{$key}{content})
	{
		#use Data::Dumper; print Dumper %{$conf->{string}{lang}{$language}};
		hard_die($conf, $THIS_FILE, __LINE__, 6, "The 'string' generated by common.lib's 'get_string()' function is undefined.<br />This passed string key: '$key' for the language: '$say_language' may not exist in the 'strings.xml' file.\n");
	}
	
	# Grab the string and start cleaning it up.
	my $string = $conf->{string}{lang}{$language}{key}{$key}{content};
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; 1. string: [$string]\n");
	#print __LINE__."; 3. string: [$string]\n";
	
	# This clears off the new-line and trailing white-spaces caused by the
	# indenting of the '</key>' field in the words XML file when printing
	# to the command line.
	$string =~ s/^\n//;
	$string =~ s/\n(\s+)$//;
	#print __LINE__."; 4. string: [$string]\n";
	
	# Process all the #!...!# escape variables.
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> string: [$string]\n");
	($string) = process_string($conf, $string, $variables);
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << string: [$string]\n");
	
	#print "$THIS_FILE ".__LINE__."; key: [$key], language: [$language]\n";
	return($string);
}

# This is a wrapper for 'get_string' that simply calls 'wrap_string()' before returning.
sub get_wrapped_string
{
	my ($conf, $vars) = @_;
	
	#print __LINE__."; vars: [$vars]\n";
	my $string = wrap_string($conf, get_string($conf, $vars));
	
	return($string);
}

# This funtion does not try to parse anything, use templates or what have you.
# It's very close to a simple 'die'. This should be used as rarely as possible
# as translations can't be used.
sub hard_die
{
	my ($conf, $file, $line, $exit_code, $message) = @_;
	
	$file      = "--" if not defined $file;
	$line      = 0    if not defined $line;
	$exit_code = 999  if not defined $exit_code;
	$message   = "?"  if not defined $message;
	
	# This can't be skinned or translated. :(
	print "
	<div name=\"hard_die\">
	Fatal error: [<span class=\"code\">$exit_code</span>] in file: [<span class=\"code\">$file</span>] at line: [<span class=\"code\">$line</span>]!<br />
	$message<br />
	Exiting.<br />
	</div>
	";
	
	exit ($exit_code);
}

# This initializes a call; reads variables, etc.
sub initialize
{
	# Set default configuration variable values
	my ($conf) = initialize_conf();
	
	# First thing first, initialize the web session.
	initialize_http($conf);

	# First up, read in the default strings file.
	read_strings($conf, $conf->{path}{words_common});
	read_strings($conf, $conf->{path}{words_file});

	# Read in the configuration file. If the file doesn't exist, initial 
	# setup will be triggered.
	read_configuration_file($conf);
	
	return($conf);
}

# Set default configuration variable values
sub initialize_conf
{
	# Setup (sane) defaults
	my $conf = {
		nodes			=>	"",
		check_using_node	=>	"",
		up_nodes		=>	[],
		online_nodes		=>	[],
		handles			=>	{
			'log'			=>	"",
		},
		path			=>	{
			apache_manifests_dir	=>	"/var/www/html/manifests",
			apache_manifests_url	=>	"/manifests",
			backup_config		=>	"/var/www/html/striker-backup_#!hostname!#_#!date!#.txt",	# Remember to update the sys::backup_url value below if you change this
			'call_gather-system-info'	=>	"/var/www/tools/call_gather-system-info",
			cat			=>	"/bin/cat",
			ccs			=>	"/usr/sbin/ccs",
			check_dvd		=>	"/var/www/tools/check_dvd",
			cluster_conf		=>	"/etc/cluster/cluster.conf",
			clusvcadm		=>	"/usr/sbin/clusvcadm",
			config_file		=>	"/etc/striker/striker.conf",
			control_dhcpd		=>	"/var/www/tools/control_dhcpd",
			control_libvirtd	=>	"/var/www/tools/control_libvirtd",
			cp			=>	"/bin/cp",
			default_striker_manifest	=>	"/var/www/html/manifests/striker-default.xml",
			dhcpd_conf		=>	"/etc/dhcp/dhcpd.conf",
			do_dd			=>	"/var/www/tools/do_dd",
			docroot			=>	"/var/www/html/",
			echo			=>	"/bin/echo",
			email_password_file	=>	"/var/www/tools/email_pw.txt",
			expect			=>	"/usr/bin/expect",
			fence_ipmilan		=>	"/sbin/fence_ipmilan",
			gethostip		=>	"/bin/gethostip",
			'grep'			=>	"/bin/grep",
			home			=>	"/var/www/home/",
			hostname		=>	"/bin/hostname",
			hosts			=>	"/etc/hosts",
			ifconfig		=>	"/sbin/ifconfig",
			initd_libvirtd		=>	"/etc/init.d/libvirtd",
			ip			=>	"/sbin/ip",
			log_file		=>	"/var/log/striker.log",
			lvdisplay		=>	"/sbin/lvdisplay",
			media			=>	"/var/www/home/media/",
			ping			=>	"/usr/bin/ping",
			'redhat-release'	=>	"/etc/redhat-release",
			repo_centos		=>	"/var/www/html/c6/x86_64/img/repodata",
			repo_centos_path	=>	"/c6/x86_64/img/",
			repo_generic		=>	"/var/www/html/repo/repodata",
			repo_generic_path	=>	"/repo/",
			repo_rhel		=>	"/var/www/html/rhel6/x86_64/img/repodata",
			repo_rhel_path		=>	"/rhel6/x86_64/img/",
			rhn_check		=>	"/usr/sbin/rhn_check",
			rhn_file		=>	"/etc/sysconfig/rhn/systemid",
			rsync			=>	"/usr/bin/rsync",
			screen			=>	"/usr/bin/screen",
			shared			=>	"/shared/files/",	# This is hard-coded in the file delete function.
			skins			=>	"../html/skins/",
			ssh_config		=>	"/etc/ssh/ssh_config",
			'ssh-keyscan'		=>	"/usr/bin/ssh-keyscan",
			status			=>	"/var/www/home/status/",
			'striker_files'		=>	"/var/www/home",
			'striker_cache'		=>	"/var/www/home/cache",
			sync			=>	"/bin/sync",
			tools_directory		=>	"/var/www/tools/",
			'touch_striker.log'	=>	"/var/www/tools/touch_striker.log",
			tput			=>	"/usr/bin/tput",
			virsh			=>	"/usr/bin/virsh",
			words_common		=>	"Data/common.xml",
			words_file		=>	"Data/strings.xml",
			
			# These are the tools that will be copied to 'docroot'
			# if either node doesn't have an internet connection.
			tools			=>	[
				"anvil-configure-network",
				"anvil-map-drives",
				"anvil-map-network",
				"anvil-self-destruct",
			],
			
			# These are files on nodes, not on the dashboard machin itself.
			nodes			=>	{
				anvil_kick_apc_ups	=>	"/sbin/striker/anvil-kick-apc-ups",
				anvil_kick_apc_ups_link	=>	"/etc/rc3.d/S99z_anvil-kick-apc-ups",
				backups			=>	"/root/backups",
				bcn_bond1_config	=>	"/etc/sysconfig/network-scripts/ifcfg-bcn_bond1",
				bcn_link1_config	=>	"/etc/sysconfig/network-scripts/ifcfg-bcn_link1",
				bcn_link2_config	=>	"/etc/sysconfig/network-scripts/ifcfg-bcn_link2",
				cluster_conf		=>	"/etc/cluster/cluster.conf",
				drbd			=>	"/etc/drbd.d",
				drbd_global_common	=>	"/etc/drbd.d/global_common.conf",
				drbd_r0			=>	"/etc/drbd.d/r0.res",
				drbd_r1			=>	"/etc/drbd.d/r1.res",
				fstab			=>	"/etc/fstab",
				hostname		=>	"/etc/sysconfig/network",
				hosts			=>	"/etc/hosts",
				ifcfg_directory		=>	"/etc/sysconfig/network-scripts/",
				ifn_bond1_config	=>	"/etc/sysconfig/network-scripts/ifcfg-ifn_bond1",
				ifn_bridge1_config	=>	"/etc/sysconfig/network-scripts/ifcfg-ifn_bridge1",
				ifn_link1_config	=>	"/etc/sysconfig/network-scripts/ifcfg-ifn_link1",
				ifn_link2_config	=>	"/etc/sysconfig/network-scripts/ifcfg-ifn_link2",
				iptables		=>	"/etc/sysconfig/iptables",
				lvm_conf		=>	"/etc/lvm/lvm.conf",
				MegaCli64		=>	"/opt/MegaRAID/MegaCli/MegaCli64",
				network_scripts		=>	"/etc/sysconfig/network-scripts",
				ntp_conf		=>	"/etc/ntp.conf",
				safe_anvil_start	=>	"/sbin/striker/safe_anvil_start",
				safe_anvil_start_link	=>	"/etc/rc3.d/S99z_safe_anvil_start",
				shadow			=>	"/etc/shadow",
				shared_subdirectories	=>	["definitions", "provision", "archive", "files", "status"],
				sn_bond1_config		=>	"/etc/sysconfig/network-scripts/ifcfg-sn_bond1",
				sn_link1_config		=>	"/etc/sysconfig/network-scripts/ifcfg-sn_link1",
				sn_link2_config		=>	"/etc/sysconfig/network-scripts/ifcfg-sn_link2",
				udev_net_rules		=>	"/etc/udev/rules.d/70-persistent-net.rules",
			},
		},
		args			=>	{
			check_dvd		=>	"--dvd --no-cddb --no-device-info --no-disc-mode --no-vcd",
			rsync			=>	"-av --partial",
		},
		sys			=>	{
			auto_populate_ssh_users	=>	"",
			backup_url		=>	"/striker-backup_#!hostname!#_#!date!#.txt",
			clustat_timeout		=>	120,
			cluster_conf		=>	"",
			config_read		=>	0,
			daemons			=>	{
				enable			=>	[
					"gpm",		# LSB compliant
					"ipmi",		# NOT LSB compliant! 0 == running, 6 == stopped
					"iptables",	# LSB compliant
					"modclusterd",	# LSB compliant
					"network",	# Does NOT appear to be LSB compliant; returns '0' for 'stopped'
					"ntpd",		# LSB compliant
					"ricci",	# LSB compliant
				],
				disable		=>	[
					"acpid",
					"clvmd",	# Appears to be LSB compliant
					"cman",		# 
					"drbd",		# 
					"gfs2",		# 
					"ip6tables",	# 
					"rgmanager",	# 
				],
			},
			date_seperator		=>	"-",			# Should put these in the strings.xml file
			dd_block_size		=>	"1M",
			debug			=>	1,
			default_password	=>	"Initial1",
			# When set to '1', (almost) all external links will be
			# disabled. Useful for sites without an Internet
			# connection.
			disable_links		=>	0,
			error_limit		=>	10000,
			# This will significantly cut down on the text shown
			# on the screen to make information more digestable for
			# experts.
			expert_ui		=>	0,
			footer_printed		=>	0,
			html_lang		=>	"en",
			ignore_missing_vm	=>	0,
			# These options control some of the Install Manifest
			# options. They can be overwritten by adding matching 
			# entries is striker.conf.
			install_manifest	=>	{
				'default'		=>	{
					bcn_network		=>	"10.20.0.0",
					bcn_subnet		=>	"255.255.0.0",
					cluster_name		=>	"anvil",
					dns1			=>	"8.8.8.8",
					dns2			=>	"8.8.4.4",
					domain			=>	"",
					ifn_gateway		=>	"",
					ifn_network		=>	"10.255.0.0",
					ifn_subnet		=>	"255.255.0.0",
					library_size		=>	"40",
					library_unit		=>	"GiB",
					name			=>	"",
					node1_bcn_ip		=>	"",
					node1_ifn_ip		=>	"",
					node1_ipmi_ip		=>	"",
					node1_name		=>	"",
					node1_sn_ip		=>	"",
					node2_bcn_ip		=>	"",
					node2_ifn_ip		=>	"",
					node2_ipmi_ip		=>	"",
					node2_name		=>	"",
					node2_sn_ip		=>	"",
					node1_pdu1_outlet	=>	"",
					node1_pdu2_outlet	=>	"",
					node1_pdu3_outlet	=>	"",
					node1_pdu4_outlet	=>	"",
					node2_pdu1_outlet	=>	"",
					node2_pdu2_outlet	=>	"",
					node2_pdu3_outlet	=>	"",
					node2_pdu4_outlet	=>	"",
					ntp1			=>	"",
					ntp2			=>	"",
					open_vnc_ports		=>	100,
					password		=>	"Initial1",
					pdu1_name		=>	"",
					pdu1_ip			=>	"",
					pdu1_agent		=>	"",
					pdu2_name		=>	"",
					pdu2_ip			=>	"",
					pdu2_agent		=>	"",
					pdu3_name		=>	"",
					pdu3_ip			=>	"",
					pdu3_agent		=>	"",
					pdu4_name		=>	"",
					pdu4_ip			=>	"",
					pdu4_agent		=>	"",
					pool1_size		=>	"50",
					pool1_unit		=>	"%",
					prefix			=>	"",
					repositories		=>	"",
					sequence		=>	"01",
					sn_network		=>	"10.10.0.0",
					sn_subnet		=>	"255.255.0.0",
					striker1_bcn_ip		=>	"",
					striker1_ifn_ip		=>	"",
					striker1_name		=>	"",
					striker2_bcn_ip		=>	"",
					striker2_ifn_ip		=>	"",
					striker2_name		=>	"",
					switch1_ip		=>	"",
					switch1_name		=>	"",
					switch2_ip		=>	"",
					switch2_name		=>	"",
					ups1_ip			=>	"",
					ups1_name		=>	"",
					ups2_ip			=>	"",
					ups2_name		=>	"",
				},
				# If the user wants to build install manifests for
				# environments with 4 PDUs, this will be set to '4'.
				pdu_count		=>	2,
				# This sets the default fence agent to use for
				# the PDUs.
				pdu_fence_agent		=>	"fence_apc_snmp",
				# These variables control whether certain
				# fields are displayed or not when generating
				# Install Manifests. If you set any of these to
				# '0', please be sure to have an appropriate
				# default set above.
				show			=>	{
					### Primary
					prefix_field		=>	1,
					sequence_field		=>	1,
					domain_field		=>	1,
					password_field		=>	1,
					bcn_network_fields	=>	1,
					sn_network_fields	=>	1,
					ifn_network_fields	=>	1,
					library_fields		=>	1,
					pool1_fields		=>	1,
					repository_field	=>	1,
					
					### Shared
					name_field		=>	1,
					dns_fields		=>	1,
					ntp_fields		=>	1,
					
					### Foundation pack
					switch_fields		=>	1,
					ups_fields		=>	1,
					pdu_fields		=>	1,
					dashboard_fields	=>	1,
					
					### Nodes
					nodes_name_field	=>	1,
					nodes_bcn_field		=>	1,
					nodes_ipmi_field	=>	1,
					nodes_sn_field		=>	1,
					nodes_ifn_field		=>	1,
					nodes_pdu_fields	=>	1,
					
					# Control tests/output shown when the
					# install runs. Mainly useful when a
					# site will never have Internet access.
					internet_check		=>	1,
					rhn_checks		=>	1,
				},
				# This sets anvil-kick-apc-ups to start on boot
				use_anvil_kick_apc_ups	=>	0,
				# This controls whether safe_anvil_start is
				# enabled or not.
				use_safe_anvil_start	=>	0,
			},
			language		=>	"en_CA",
			log_language		=>	"en_CA",
			log_level		=>	3,
			lvm_conf		=>	"",
			lvm_filter		=>	"filter = [ \"a|/dev/drbd*|\", \"r/.*/\" ]",
			# This allows for custom MTU sizes in an Install Manifest
			mtu_size		=>	1500,
			# This tells the install manifest generator how many
			# ports to open on the IFN for incoming VNC connections
			node_names		=>	[],
			online_nodes		=>	0,
			os_variant		=>	[
				"win7#!#Microsoft Windows 7",
				"win7#!#Microsoft Windows 8",
				"vista#!#Microsoft Windows Vista",
				"winxp64#!#Microsoft Windows XP (x86_64)",
				"winxp#!#Microsoft Windows XP",
				"win2k#!#Microsoft Windows 2000",
				"win2k8#!#Microsoft Windows Server 2008 (R2)",
				"win2k8#!#Microsoft Windows Server 2012 (R2)",
				"win2k3#!#Microsoft Windows Server 2003",
				"openbsd4#!#OpenBSD 4.x",
				"freebsd8#!#FreeBSD 8.x",
				"freebsd7#!#FreeBSD 7.x",
				"freebsd6#!#FreeBSD 6.x",
				"solaris9#!#Sun Solaris 9",
				"solaris10#!#Sun Solaris 10",
				"opensolaris#!#Sun OpenSolaris",
				"netware6#!#Novell Netware 6",
				"netware5#!#Novell Netware 5",
				"netware4#!#Novell Netware 4",
				"msdos#!#MS-DOS",
				"generic#!#Generic",
				"debianwheezy#!#Debian Wheezy",
				"debiansqueeze#!#Debian Squeeze",
				"debianlenny#!#Debian Lenny",
				"debianetch#!#Debian Etch",
				"fedora18#!#Fedora 18",
				"fedora17#!#Fedora 17",
				"fedora16#!#Fedora 16",
				"fedora15#!#Fedora 15",
				"fedora14#!#Fedora 14",
				"fedora13#!#Fedora 13",
				"fedora12#!#Fedora 12",
				"fedora11#!#Fedora 11",
				"fedora10#!#Fedora 10",
				"fedora9#!#Fedora 9",
				"fedora8#!#Fedora 8",
				"fedora7#!#Fedora 7",
				"fedora6#!#Fedora Core 6",
				"fedora5#!#Fedora Core 5",
				"mageia1#!#Mageia 1 and later",
				"mes5.1#!#Mandriva Enterprise Server 5.1 and later",
				"mes5#!#Mandriva Enterprise Server 5.0",
				"mandriva2010#!#Mandriva Linux 2010 and later",
				"mandriva2009#!#Mandriva Linux 2009 and earlier",
				"rhel7#!#Red Hat Enterprise Linux 7",
				"rhel6#!#Red Hat Enterprise Linux 6",
				"rhel5.4#!#Red Hat Enterprise Linux 5.4 or later",
				"rhel5#!#Red Hat Enterprise Linux 5",
				"rhel4#!#Red Hat Enterprise Linux 4",
				"rhel3#!#Red Hat Enterprise Linux 3",
				"rhel2.1#!#Red Hat Enterprise Linux 2.1",
				"sles11#!#Suse Linux Enterprise Server 11",
				"sles10#!#Suse Linux Enterprise Server",
				"opensuse12#!#openSuse 12",
				"opensuse11#!#openSuse 11",
				"ubuntuquantal#!#Ubuntu 12.10 (Quantal Quetzal)",
				"ubuntuprecise#!#Ubuntu 12.04 LTS (Precise Pangolin)",
				"ubuntuoneiric#!#Ubuntu 11.10 (Oneiric Ocelot)",
				"ubuntunatty#!#Ubuntu 11.04 (Natty Narwhal)",
				"ubuntumaverick#!#Ubuntu 10.10 (Maverick Meerkat)",
				"ubuntulucid#!#Ubuntu 10.04 LTS (Lucid Lynx)",
				"ubuntukarmic#!#Ubuntu 9.10 (Karmic Koala)",
				"ubuntujaunty#!#Ubuntu 9.04 (Jaunty Jackalope)",
				"ubuntuintrepid#!#Ubuntu 8.10 (Intrepid Ibex)",
				"ubuntuhardy#!#Ubuntu 8.04 LTS (Hardy Heron)",
				"virtio26#!#Generic 2.6.25 or later kernel with virtio",
				"generic26#!#Generic 2.6.x kernel",
				"generic24#!#Generic 2.4.x kernel",
			],
			output			=>	"web",
			pool1_shrunk		=>	0,
			reboot_timeout		=>	600,
			root_password		=>	"",
			# Set this to an integer to have the main Striker page
			# and the hardware status pages automatically reload.
			reload_page_timer	=>	0,
			# These options allow customization of newly provisioned
			# servers.
			server			=>	{
				nic_count		=>	1,
				alternate_nic_model	=>	"e1000",
				minimum_ram		=>	67108864,
			},
			shared_fs_uuid		=>	"",
			show_nodes		=>	0,
			show_refresh		=>	1,
			skin			=>	"alteeve",
			striker_uid		=>	$<,
			system_timezone		=>	"America/Toronto",
			time_seperator		=>	":",
			# ~3 GiB, but in practice more because it will round down the
			# available RAM before subtracting this to leave the user with
			# an even number of GiB or RAM to allocate to servers.
			unusable_ram		=>	(3 * (1024 ** 3)),
			up_nodes		=>	0,
			update_os		=>	1,
			use_24h			=>	1,			# Set to 0 for am/pm time, 1 for 24h time
			use_drbd		=>	"8.3",			# Set to 8.3 if having trouble with 8.4
			# If this is set to 1, a second option will be added 
			# below 'Cold-Stop Anvil!' called 'Hard-Reset Anvil!'.
			# The 'Hard-Reset' option will do the exact same thing
			# that 'Cold-Stop' normally does, but an additional
			# step will be added to 'Cold-Stop' which will cancel
			# the APC UPS watchdog timer function. The result is 
			# that 'Cold-Stop' will leave the cluster offline and 
			# the power enabled where 'Hard-Reset' will *NOT* 
			# cancel the UPS watchdog timer, causing full power 
			# loss a few minutes after the nodes are powered off.
			# In this way, 'Hard-Reset' will cause everything 
			# powered by the UPSes to be power cycled. Assuming 
			# that 'safe-anvil-start' is configured to run on boot
			# on the nodes and that ScanCore is set to run the 
			# 'nodemonitor' scan agent, the full cluster will 
			# automatically restart after the UPS's configured
			# sleep time (typically 5 minutes) plus boot time 
			# overhead.
			# NOTE: This will be ignored if the 'anvil-kick-apc-ups'
			#       script is NOT found in /root/ on both nodes!
			use_apc_ups_watchdog	=>	0,
			username		=>	getpwuid( $< ),
			# If a user wants to use spice + qxl for video in VMs,
			# set this to '1'. NOTE: This disables web-based VNC!
# 			use_spice_graphics	=>	1,
			version			=>	"2.0.0a",
		},
		# Config values needed to managing strings
		strings				=>	{
			encoding			=>	"",
			force_utf8			=>	0,
			xml_version			=>	"",
		},
		# The actual strings
		string				=>	{},
		url				=>	{
			skins				=>	"/skins",
			cgi				=>	"/cgi-bin",
		},
	};
	
	return($conf);
}

# Check to see if the global settings have been setup.
sub check_global_settings
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; check_global_settings()\n");
	
	my $global_set = 1;
	
	# Pull out the current config.
	my $smtp__server              = $conf->{smtp}{server}; 			# mail.alteeve.ca
	my $smtp__port                = $conf->{smtp}{port};			# 587
	my $smtp__username            = $conf->{smtp}{username};		# example@alteeve.ca
	my $smtp__password            = $conf->{smtp}{password};		# Initial1
	my $smtp__security            = $conf->{smtp}{security};		# STARTTLS
	my $smtp__encrypt_pass        = $conf->{smtp}{encrypt_pass};		# 1
	my $smtp__helo_domain         = $conf->{smtp}{helo_domain};		# example.com
	my $mail_data__to             = $conf->{mail_data}{to};			# you@example.com
	my $mail_data__sending_domain = $conf->{mail_data}{sending_domain};	# example.com
	
	# TODO: Make this smarter... For now, just check the SMTP username to
	# see if it is default.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; smtp__username: [$smtp__username]\n");
	if ((not $smtp__username) or ($smtp__username =~ /example\.com/))
	{
		# Not configured yet.
		$global_set = 0;
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; global_set: [$global_set]\n");
	return($global_set);
}

# At this point in time, all this does is print the content type needed for
# printing to browsers.
sub initialize_http
{
	my ($conf) = @_;
	
	print "Content-type: text/html; charset=utf-8\n\n";
	
	return(0);
}

# This takes a completed string and inserts variables into it as needed.
sub insert_variables_into_string
{
	my ($conf, $string, $variables) = @_;
	
	my $i = 0;
	#print "$THIS_FILE ".__LINE__."; string: [$string], variables: [$variables]\n";
	while ($string =~ /#!variable!(.+?)!#/s)
	{
		my $variable = $1;
		#print "$THIS_FILE ".__LINE__."; variable [$variable]: [$variables->{$variable}]\n";
		if (not defined $variables->{$variable})
		{
			# I can't expect there to always be a defined value in
			# the variables array at any given position so if it's
			# blank I blank the key.
			$string =~ s/#!variable!$variable!#//;
		}
		else
		{
			my $value = $variables->{$variable};
			chomp $value;
			$string =~ s/#!variable!$variable!#/$value/;
		}
		
		# Die if I've looped too many times.
		if ($i > $conf->{sys}{error_limit})
		{
			hard_die($conf, $THIS_FILE, __LINE__, 7, "Infitie loop detected will inserting variables into the string: [$string]. If this is triggered erroneously, increase the 'sys::error_limit' value.\n");
		}
		$i++;
	}
	
	#print "$THIS_FILE ".__LINE__."; << string: [$string]\n";
	return($string);
}

# This reads in the configuration file.
sub read_configuration_file
{
	my ($conf) = @_;
	
	my $return_code = 1;
	if (-e $conf->{path}{config_file})
	{
		   $conf->{raw}{config_file} = [];
		   $return_code              = 0;
		my $shell_call               = "$conf->{path}{config_file}";
		open (my $file_handle, "<", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to read: [$shell_call], error was: $!\n";
		while (<$file_handle>)
		{
			chomp;
			my $line = $_;
			push @{$conf->{raw}{config_file}}, $line;
			next if not $line;
			next if $line !~ /=/;
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			next if $line =~ /^#/;
			next if not $line;
			my ($variable, $value) = (split/=/, $line, 2);
			$variable =~ s/^\s+//;
			$variable =~ s/\s+$//;
			$value    =~ s/^\s+//;
			$value    =~ s/\s+$//;
			next if (not $variable);
			_make_hash_reference($conf, $variable, $value);
		}
		close $file_handle;
	}
	
	return($return_code);
}

# This records log messages to the log file.
sub to_log
{
	my ($conf, $variables) = @_;
	
	my $line    = $variables->{line}    ? $variables->{line}    : "--";
	my $file    = $variables->{file}    ? $variables->{file}    : "--";
	my $level   = $variables->{level}   ? $variables->{level}   : 1;
	my $message = $variables->{message} ? $variables->{message} : "--";
	
	#print "<pre>record; line: [$line], file: [$file], level: [$level] (sys::log_level: [$conf->{sys}{log_level}]), message: [$message]</pre>\n";
	if ($conf->{sys}{log_level} >= $level)
	{
		# Touch the file if it doesn't exist yet.
		#print "[ Debug ] - Checking if: [$conf->{path}{log_file}] is writable...\n";
		if (not -w $conf->{path}{log_file})
		{
			# NOTE: The setuid '$conf->{path}{'touch_striker.log'}'
			#       is hard-coded to use '/var/log/striker.log'.
			#print "[ Debug ] - It is not. Running: [$conf->{path}{'touch_striker.log'}]\n";
			my $shell_call = $conf->{path}{'touch_striker.log'};
			open (my $file_handle, '-|', "$shell_call") || die "Failed to call: [$shell_call], error was: $!\n";
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				#print "[ Debug ] - Output: [$line]\n";
			}
			close $file_handle;
			
			#print "[ Debug ] - Checking if it is writable now...\n";
			if (not -w $conf->{path}{log_file})
			{
				#print "[ Error ] - Failed to make: [$conf->{path}{log_file}] writable! Is: [$conf->{path}{'touch_striker.log'}] setuid root?\n";
				exit(1);
			}
		}
		
		my $file_handle = $conf->{handles}{'log'};
		if (not $file_handle)
		{
			my $shell_call = $conf->{path}{log_file};
			open (my $file_handle, ">>", "$shell_call") or hard_die($conf, $THIS_FILE, __LINE__, 13, "Unable to open the file: [$shell_call] for writing. The error was: $!.\n");
			$file_handle->autoflush(1);
			$conf->{handles}{'log'} = $file_handle;
			
			my $current_dir         = get_current_directory($conf);
			my $log_file            = $current_dir."/".$conf->{path}{log_file};
			if ($conf->{path}{log_file} =~ /^\//)
			{
				$log_file = $conf->{path}{log_file};
			}
			my ($date, $time)  = get_date_and_time($conf);
			my $say_log_header = get_string($conf, {language => $conf->{sys}{log_language}, key => "log_0001", variables => {
				date	=>	$date,
				'time'	=>	$time,
			}});
			print $file_handle "-=] $say_log_header\n";
		}
		print $file_handle "$file $line; $message";
	}
	
	return(0);
}

# This takes the name of a template file, the name of a template section within
# the file, an optional hash containing replacement variables to feed into the
# template and an optional hash containing variables to pass into strings, and
# generates a page to display formatted according to the page.
sub template
{
	my ($conf, $file, $template, $replace, $variables, $hide_template_name) = @_;
	$replace            = {} if not defined $replace;
	$variables          = {} if not defined $variables;
	$hide_template_name = 0 if not defined $hide_template_name;
	
	my @contents;
	# Down the road, I may want to have different suffixes depending on the
	# user's environment. For now, it'll always be ".html".
	my $current_dir   = get_current_directory($conf);
	my $template_file = $current_dir."/".$conf->{path}{skins}."/".$conf->{sys}{skin}."/".$file;
	
	# Make sure the file exists.
	if (not -e $template_file)
	{
		hard_die($conf, $THIS_FILE, __LINE__, 10, "The template file: [$template_file] does not appear to exist.\n");
	}
	elsif (not -r $template_file)
	{
		my $user  = getpwuid($<);
		hard_die($conf, $THIS_FILE, __LINE__, 11, "The template file: [$template_file] is not readable by the user this program is running as the user: [$user]. Please check the permissions on the template file and it's parent directory.\n");
	}
	
	# Read in the raw template.
	my $in_template = 0;
	my $shell_call  = "$template_file";
	open (my $file_handle, "<", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to read: [$shell_call], error was: $!\n";
	binmode $file_handle, ":utf8:";
	while (<$file_handle>)
	{
		chomp;
		my $line = $_;
		
		if ($line =~ /<!-- start $template -->/)
		{
			$in_template = 1;
			next;
		}
		if ($line =~ /<!-- end $template -->/)
		{
			# Once I hit this, I am done.
			$in_template = 0;
			last;
		}
		if ($in_template)
		{
			# Read in the template.
			push @contents, $line;
		}
	}
	close $file_handle;
	
	# Now parse the contents for replacement keys.
	my $page = "";
	if (not $hide_template_name)
	{
		$page .= "<!-- Start template: [$template] from file: [$file] -->\n";
	}
	foreach my $string (@contents)
	{
		# Replace the '#!replace!...!#' substitution keys.
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> string: [$string]\n");
		($string) = process_string_replace($conf, $string, $replace, $template_file, $template);
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << string: [$string]\n");
		
		# Process all the #!...!# escape variables.
		#print "$THIS_FILE ".__LINE__."; >> string: [$string]\n";
		#print __LINE__."; >> file: [$file], template: [$template], string: [$string]\n";
		($string) = process_string($conf, $string, $variables);
		#print __LINE__."; << file: [$file], template: [$template], string: [$string\n";
		#print "$THIS_FILE ".__LINE__."; << string: [$string]\n";
		$page .= "$string\n";
	}
	if (not $hide_template_name)
	{
		$page .= "<!-- End template: [$template] from file: [$file] -->\n\n";
	}
	
	return($page);
}

# Process all the other #!...!# escape variables.
sub process_string
{
	my ($conf, $string, $variables) = @_;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> string: [$string]\n");
	#print __LINE__."; i. string: [$string], variables: [$variables]\n";
	
	# Insert variables into #!variable!x!# 
	my $i = 0;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> string: [$string]\n");
	($string) = insert_variables_into_string($conf, $string, $variables);
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << string: [$string]\n");
	
	while ($string =~ /#!(.+?)!#/s)
	{
		# Insert strings that are referenced in this string.
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; [$i], 2.\n");
		($string) = process_string_insert_strings($conf, $string, $variables);
		
		# Protect unmatchable keys.
		#print __LINE__."; [$i], 3.\n";
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; [$i], 3.\n");
		($string) = process_string_protect_escape_variables($conf, $string, "string");

		# Inject any 'conf' values.
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; [$i], 4.\n");
		($string) = process_string_conf_escape_variables($conf, $string);
		
		# Die if I've looped too many times.
		if ($i > $conf->{sys}{error_limit})
		{
			hard_die($conf, $THIS_FILE, __LINE__, 8, "Infitie loop detected will processing escape variables in the string: [$string]. If this is triggered erroneously, increase the 'sys::error_limit' value. If you are a developer or translator, did you use '#!replace!...!#' when you meant to use '#!variable!...!#' in a string key?\n");
		}
		$i++;
	}

	# Restore and unrecognized substitution values.
	($string) = process_string_restore_escape_variables($conf, $string);
	#print __LINE__."; << string: [$string]\n";
	if ($string =~ /Etc\/GMT\+0/)
	{
		$conf->{i}++;
		die if $conf->{i} > 10;
	}
	
	return($string);
}

# This looks for #!string!...!# substitution variables.
sub process_string_insert_strings
{
	my ($conf, $string, $variables) = @_;
	
	#print __LINE__."; A. string: [$string], variables: [$variables]\n";
	while ($string =~ /#!string!(.+?)!#/)
	{
		my $key        = $1;
		#print __LINE__."; B. key: [$key]\n";
		# I don't insert variables into strings here. If a complex
		# string is needed, the user should process it and pass the
		# completed string to the template function as a
		# #!replace!...!# substitution variable.
		#print __LINE__."; >>> string: [$string]\n";
		my $say_string = get_string($conf, {key => $key, variables => $variables});
		#print __LINE__."; C. say_string: [$key]\n";
		if ($say_string eq "")
		{
			$string =~ s/#!string!$key!#/!! [$key] !!/;
		}
		else
		{
			$string =~ s/#!string!$key!#/$say_string/;
		}
		#print __LINE__."; <<< string: [$string]\n";
	}
	
	return($string);
}

# This replaces "conf" escape variables using variables 
sub process_string_conf_escape_variables
{
	my ($conf, $string) = @_;

	while ($string =~ /#!conf!(.+?)!#/)
	{
		my $key   = $1;
		my $value = "";
		
		# If the key has double-colons, I need to break it up and make
		# each one a key in the multi-dimensional hash.
		if ($key =~ /::/)
		{
			($value) = _get_hash_value_from_string($conf, $key);
		}
		else
		{
			# First dimension
			($value) = defined $conf->{$key} ? $conf->{$key} : "!!Undefined config variable: [$key]!!";
		}
		$string =~ s/#!conf!$key!#/$value/;
	}

	return($string);
}

# Protect unrecognized or unused replacement keys by flipping '#!...!#' to
# '_!|...|!_'. This gets reversed in 'process_string_restore_escape_variables()'.
sub process_string_protect_escape_variables
{
	my ($conf, $string) = @_;

	foreach my $check ($string =~ /#!(.+?)!#/)
	{
		if (
			($check !~ /^free/)    &&
			($check !~ /^replace/) &&
			($check !~ /^conf/)    &&
			($check !~ /^var/)
		)
		{
			$string =~ s/#!($check)!#/_!\|$1\|!_/g;
		}
	}

	return($string);
}

# This is used by the 'template()' function to insert '#!replace!...!#' 
# replacement variables in templates.
sub process_string_replace
{
	my ($conf, $string, $replace, $template_file, $template) = @_;
	
	my $i = 0;
	while ($string =~ /#!replace!(.+?)!#/)
	{
		my $key   =  $1;
		my $value =  defined $replace->{$key} ? $replace->{$key} : "!! Undefined replacement key: [$key] !!\n";
		$string   =~ s/#!replace!$key!#/$value/;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; string: [$string]\n");
		
		# Die if I've looped too many times.
		if ($i > $conf->{sys}{error_limit})
		{
			hard_die($conf, $THIS_FILE, __LINE__, 12, "Infitie loop detected while replacing '#!replace!...!#' replacement variables in the template file: [$template_file] in the template: [$template]. If this is triggered erroneously, increase the 'sys::error_limit' value.\n");
		}
		$i++;
	}
	
	return($string);
}

# This restores the original escape variable format for escape variables that
# were protected by the 'process_string_protect_escape_variables()' function.
sub process_string_restore_escape_variables
{
	my ($conf, $string)=@_;

	# Restore and unrecognized substitution values.
	my $i = 0;
	while ($string =~ /_!\|(.+?)\|!_/s)
	{
		my $check  =  $1;
		   $string =~ s/_!\|$check\|!_/#!$check!#/g;
		
		# Die if I've looped too many times.
		if ($i > $conf->{sys}{error_limit})
		{
			hard_die($conf, $THIS_FILE, __LINE__, 9, "Infitie loop detected will restoring protected escape variables in the string: [$string]. If this is triggered erroneously, increase the 'sys::error_limit' value.\n");
		}
		$i++;
	}

	return($string);
}

# This reads in the strings XML file.
sub read_strings
{
	my ($conf, $file) = @_;
	
	my $string_ref = $conf;

	my $in_comment  = 0;	# Set to '1' when in a comment stanza that spans more than one line.
	my $in_data     = 0;	# Set to '1' when reading data that spans more than one line.
	my $closing_key = "";	# While in_data, look for this key to know when we're done.
	my $xml_version = "";	# The XML version of the strings file.
	my $encoding    = "";	# The encoding used in the strings file. Should only be UTF-8.
	my $data        = "";	# The data being read for the given key.
	my $key_name    = "";	# This is a double-colon list of hash keys used to build each hash element.
	
	my $shell_call  = "$file";
	open (my $file_handle, "<", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to read: [$shell_call], error was: $!\n";
	if ($conf->{strings}{force_utf8})
	{
		binmode $file_handle, "encoding(utf8)";
	}
	while(<$file_handle>)
	{
		chomp;
		my $line=$_;

		### Deal with comments.
		# Look for a closing stanza if I am (still) in a comment.
		if (($in_comment) && ( $line =~ /-->/ ))
		{
			$line       =~ s/^(.*?)-->//;
			$in_comment =  0;
		}
		next if ($in_comment);

		# Strip out in-line comments.
		while ($line =~ /<!--(.*?)-->/)
		{
			$line =~ s/<!--(.*?)-->//;
		}

		# See if there is an comment opening stanza.
		if ($line =~ /<!--/)
		{
			$in_comment =  1;
			$line       =~ s/<!--(.*)$//;
		}
		### Comments dealt with.

		### Parse data
		# XML data
		if ($line =~ /<\?xml version="(.*?)" encoding="(.*?)"\?>/)
		{
			$conf->{strings}{xml_version} = $1;
			$conf->{strings}{encoding}    = $2;
			next;
		}

		# If I am not "in_data" (looking for more data for a currently in use key).
		if (not $in_data)
		{
			# Skip blank lines.
			next if $line =~ /^\s+$/;
			next if $line eq "";
			$line =~ s/^\s+//;
			
			# Look for an inline data-structure.
			if (($line =~ /<(.*?) (.*?)>/) && ($line =~ /<\/$1>/))
			{
				# First, look for CDATA.
				my $cdata = "";
				if ($line =~ /<!\[CDATA\[(.*?)\]\]>/)
				{
					$cdata =  $1;
					$line  =~ s/<!\[CDATA\[$cdata\]\]>/$cdata/;
				}

				# Pull out the key and name.
				my ($key) = ($line =~ /^<(.*?) /);
				my ($name, $data) = ($line =~ /^<$key name="(.*?)">(.*?)<\/$key>/);
				$data =  $cdata if $cdata;
				_make_hash_reference($string_ref, "${key_name}::${key}::${name}::content", $data);
				next;
			}

			# Look for a self-contained unkeyed structure.
			if (($line =~ /<(.*?)>/) && ($line =~ /<\/$1>/))
			{
				my $key  =  $line;
				   $key  =~ s/<(.*?)>.*/$1/;
				   $data =  $line;
				   $data =~ s/<$key>(.*?)<\/$key>/$1/;
				_make_hash_reference($string_ref, "${key_name}::${key}", $data);
				next;
			}

			# Look for a line with a closing stanza.
			if ($line =~ /<\/(.*?)>/)
			{
				my $closing_key =  $line;
				   $closing_key =~ s/<\/(\w+)>/$1/;
				   $key_name    =~ s/(.*?)::$closing_key(.*)/$1/;
				next;
			}

			# Look for a key with an embedded value.
			if ($line =~ /^<(\w+) name="(.*?)" (\w+)="(.*?)">/)
			{
				my $key   =  $1;
				my $name  =  $2;
				my $key2  =  $3;
				my $data  =  $4;
				$key_name .= "::${key}::${name}";
				_make_hash_reference($string_ref, "${key_name}::${key}::${key2}", $data);
				next;
			}

			# Look for a contained value.
			if ($line =~ /^<(\w+) name="(.*?)">(.*)/)
			{
				my $key  = $1;
				my $name = $2;
				   $data = $3;	# Don't scope locally in case this data spans lines.

				if ($data =~ /<\/$key>/)
				{
					# Fully contained data.
					$data =~ s/<\/$key>(.*)$//;
					_make_hash_reference($string_ref, "${key_name}::${key}::${name}", $data);
				}
				else
				{
					# Element closes later.
					$in_data     =  1;
					$closing_key =  $key;
					$name        =~ s/^<$key name="(\w+).*/$1/;
					$key_name    .= "::${key}::${name}";
					$data        =~ s/^<$key name="$name">(.*)/$1/;
					$data        .= "\n";
				}
				next;
			}

			# Look for an opening data structure.
			if ($line =~ /<(.*?)>/)
			{
				my $key      =  $1;
				   $key_name .= "::$key";
				next;
			}
		}
		else
		{
			if ($line !~ /<\/$closing_key>/)
			{
				$data .= "$line\n";
			}
			else
			{
				$in_data =  0;
				$line    =~ s/(.*?)<\/$closing_key>/$1/;
				$data    .= "$line";

				# If there is CDATA, set it aside.
				my $save_data = "";
				my @lines     = split/\n/, $data;

				my $in_cdata  = 0;
				foreach my $line (@lines)
				{
					if (($in_cdata == 1) && ($line =~ /]]>$/))
					{
						# CDATA closes here.
						$line      =~ s/]]>$//;
						$save_data .= "\n$line";
						$in_cdata  =  0;
					}
					if (($line =~ /^<\!\[CDATA\[/) && ($line =~ /]]>$/))
					{
						# CDATA opens and closes in this line.
						$line      =~ s/^<\!\[CDATA\[//;
						$line      =~ s/]]>$//;
						$save_data .= "\n$line";
					}
					elsif ($line =~ /^<\!\[CDATA\[/)
					{
						$line     =~ s/^<\!\[CDATA\[//;
						$in_cdata =  1;
					}
					
					if ($in_cdata == 1)
					{
						# Don't analyze, just store.
						$save_data .= "\n$line";
					}
					else
					{
						# Not in CDATA, look for XML data.
						#print "Checking: [$line] for an XML item.\n";
						while (($line =~ /<(.*?)>/) && ($line =~ /<\/$1>/))
						{
							# Found a value.
							my $key  =  $line;
							   $key  =~ s/.*?<(.*?)>.*/$1/;
							   $data =  $line;
							   $data =~ s/.*?<$key>(.*?)<\/$key>/$1/;

							#print "Saving: key: [$key], [${key_name}::${key}] -> [$data]\n";
							_make_hash_reference($string_ref, "${key_name}::${key}", $data);
							$line =~ s/<$key>(.*?)<\/$key>//;
						}
						$save_data .= "\n$line";
					}
					#print "$THIS_FILE ".__LINE__."; [$in_cdata] Check: [$line]\n";
				}

				$save_data =~ s/^\n//;
				if ($save_data =~ /\S/s)
				{
					#print "$THIS_FILE ".__LINE__."; save_data: [$save_data]\n";
					_make_hash_reference($string_ref, "${key_name}::content", $save_data);
				}

				$key_name =~ s/(.*?)::$closing_key(.*)/$1/;
			}
		}
		next if $line eq "";
	}
	close $file_handle;
	#use Data::Dumper; print Dumper $conf;
	
	return(0);
}

# This wraps the passed screen to the current screen width. Assumes output of
# to text/command line.
sub wrap_string
{
	my ($conf, $string) = @_;
	
	my $wrap_to = get_screen_width($conf);
	
	# No sense proceeding if the string is empty.
	return ($string) if not $string;
	
	# No sense proceeding if there isn't a length to wrap to.
	return ($string) if not $wrap_to;

	# When the string starts with certain borders, try to make it look
	# better by indenting the wrapped portion(s) an appropriate number
	# of spaces and put in a border where it seems needed.
	my $prefix_spaces = "";
	if ( $string =~ /^\[ (.*?) \] - / )
	{
		my $prefix      = "[ $1 ] - ";
		my $wrap_spaces = length($prefix);
		for (1..$wrap_spaces)
		{
			$prefix_spaces .= " ";
		}
	}
	# If the line has spaces at the start, maintain those spaces for
	# wrapped lines.
	elsif ( $string =~/^(\s+)/ )
	{
		# We have some number of white spaces.
		my $prefix     =  $1;
		my $say_prefix =  $prefix;
		$say_prefix    =~ s/\t/\\t/g;
		my $wrap_spaces = length($prefix);
		for (1..$wrap_spaces)
		{
			$prefix_spaces.=" ";
		}
	}
	
	my @words          = split/ /, $string;
	my $wrapped_string = "";
	my $this_line;
	for (my $i=0; $i<@words; $i++)
	{
		# Store the line as it was before in case the next word pushes line line past the 'wrap_to' value.
		my $last_line =  $this_line;
		$this_line    .= $words[$i];
		my $length    =  0;
		if ($this_line)
		{
			$length = length($this_line);
		}
		if ((not $last_line) && ($length >= $wrap_to))
		{
			# This one 'word' is longer than the width of the screen so just pass it along.
			$wrapped_string .= $words[$i]."\n";
			$this_line      =  "";
		}
		elsif (length($this_line) > $wrap_to)
		{
			$last_line      =~ s/\s+$/\n/;
			$wrapped_string .= $last_line;
			$this_line      =  $prefix_spaces.$words[$i]." ";
		}
		else
		{
			$this_line.=" ";
		}
	}
	$wrapped_string .= $this_line;
	$wrapped_string =~ s/\s+$//;
	
	return($string);
}

# Get the current number of colums for the user's terminal.
sub get_screen_width
{
	my ($conf) = @_;
	
	my $cols = 0;
	open my $file_handle, '-|', "$conf->{path}{tput}", "cols" or die "Failed to call: [$conf->{path}{tput} cols]\n";
	while (<$file_handle>)
	{
		chomp;
		$cols = $_;
	}
	close $file_handle;
	
	return($cols);
}

###############################################################################
### Private functions                                                       ###
###############################################################################

### Contributed by Shaun Fryer and Viktor Pavlenko by way of TPM.
# This is a helper to the below '_make_hash_reference' function. It is called
# each time a new string is to be created as a new hash key in the passed hash
# reference.
sub _add_hash_reference
{
	my ($href1, $href2) = @_;

	for my $key (keys %$href2)
	{
		if (ref $href1->{$key} eq 'HASH')
		{
			_add_hash_reference($href1->{$key}, $href2->{$key});
		}
		else
		{
			$href1->{$key} = $href2->{$key};
		}
	}
}

# This is the reverse of '_make_hash_reference()'. It takes a double-colon
# separated string, breaks it up and returns the value stored in the
# corosponding $conf hash.
sub _get_hash_value_from_string
{
	my ($conf, $key_string) = @_;
	
	my @keys      = split /::/, $key_string;
	my $last_key  = pop @keys;
	my $this_href = $conf;
	while (my $key = shift @keys)
	{
		$this_href = $this_href->{$key};
	}
	
	my $value = defined $this_href->{$last_key} ? $this_href->{$last_key} : "!!Undefined config variable: [$key_string]!!";
	
	return($value);
}

### Contributed by Shaun Fryer and Viktor Pavlenko by way of TPM.
# This takes a string with double-colon seperators and divides on those
# double-colons to create a hash reference where each element is a hash key.
sub _make_hash_reference
{
	my ($href, $key_string, $value) = @_;

	my @keys            = split /::/, $key_string;
	my $last_key        = pop @keys;
	my $_href           = {};
	$_href->{$last_key} = $value;
	while (my $key = pop @keys)
	{
		my $elem      = {};
		$elem->{$key} = $_href;
		$_href        = $elem;
	}
	_add_hash_reference($href, $_href);
}

1;
