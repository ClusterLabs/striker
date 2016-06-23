package AN::Tools::Log;
# 
# This module contains methods used to handle logging events.
# 

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Log.pm";

### Methods;
# adjust_log_level
# db_transactions
# entry
# level


#############################################################################################################
# House keeping methods                                                                                     #
#############################################################################################################

sub new
{
	my $class = shift;
	
	my $self = {
		LOG_LEVEL			=>	1,
		LOG_HANDLE			=>	"",
		LOG_FILE			=>	"",
		DEFAULT_LOG_FILE		=>	"/var/log/an_tools.log",
		LOG_DB_TRANSACTIONS		=>	0,
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

# Change to a user-requested log level.
sub adjust_log_level
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "adjust_log_level" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $key = $parameter->{key} ? $parameter->{key} : "sys";
	
	if ($an->data->{switches}{v})
	{
		$an->data->{$key}{log_level} = 1;
		$an->Log->level($an->data->{$key}{log_level});
	}
	elsif ($an->data->{switches}{vv})
	{
		$an->data->{$key}{log_level} = 2;
		$an->Log->level($an->data->{$key}{log_level});
	}
	elsif ($an->data->{switches}{vvv})
	{
		$an->data->{$key}{log_level} = 3;
		$an->Log->level($an->data->{$key}{log_level});
	}
	elsif ($an->data->{switches}{vvvv})
	{
		$an->data->{$key}{log_level} = 4;
		$an->Log->level($an->data->{$key}{log_level});
	}
	
	return(0);
}

### NOTE: This does NOT look to see if a value is a hash or array reference. 
# This takes a hash reference and prints multiple 'variable: [value]' entries all aligned for easier log
# reading.
sub aligned_entries
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "aligned_entries" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $hash_ref  = $parameter->{hash_ref}  ? $parameter->{hash_ref}  : "";
	my $log_level = $parameter->{log_level} ? $parameter->{log_level} : 0;
	my $file      = $parameter->{file}      ? $parameter->{file}      : $THIS_FILE;
	my $line      = $parameter->{line}      ? $parameter->{line}      : __LINE__;
	my $prefix    = $parameter->{prefix}    ? $parameter->{prefix}    : "";
	
	# Return if the log level is too high or if we weren't passed in a hash reference.
	return(1) if $log_level > $an->Log->level;
	return(2) if not ref($hash_ref) eq "HASH";
	
	my $longest_variable = 0;
	foreach my $variable (sort {$a cmp $b} keys %{$hash_ref})
	{
		next if $hash_ref->{$variable} eq "";
		if (length($variable) > $longest_variable)
		{
			$longest_variable = length($variable);
		}
	}
	
	# Now loop again in alphabetical order printing in the dots as needed.
	foreach my $variable (sort {$a cmp $b} keys %{$hash_ref})
	{
		next if $hash_ref->{$variable} eq "";
		my $difference   = $longest_variable - length($variable);
		my $say_variable = $variable;
		if ($prefix)
		{
			$say_variable = $prefix." - ".$variable;
		}
		if ($difference == 0)
		{
			# Do nothing
		}
		elsif ($difference == 1) 
		{
			$say_variable .= " ";
		}
		elsif ($difference == 2) 
		{
			$say_variable .= "  ";
		}
		else
		{
			my $dots         =  $difference - 2;
			   $say_variable .= " ";
			for (1 .. $dots)
			{
				$say_variable .= ".";
			}
			$say_variable .= " ";
		}
		$an->Log->entry({log_level => $log_level, message_key => "an_variables_0001", message_variables => {
			name1 => "$say_variable", value1 => $hash_ref->{$variable},
		}, file => $file, line => $line});
	}
	
	return(0);
}

# This, when set, causes DB transactions to be logged.
sub db_transactions
{
	my $self = shift;
	my $set  = shift if defined $_[0];
	my $an   = $self->parent;
	
	if ((defined $set) && (($set ne "0") && ($set ne "1")))
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0009", message_key => "error_message_0057", message_variables => {
			set	=>	$set,
		}, code => 57, file => "$THIS_FILE", line => __LINE__});
		# Return nothing in case the user is blocking fatal errors.
		return (undef);
	}
	
	$self->{LOG_DB_TRANSACTIONS} = $set if defined $set;
	
	return ($self->{LOG_DB_TRANSACTIONS});
}

# This does all the work of recording an entry in the log file when appropriate.
sub entry
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Setup my variables.
	my $string            = "";
	my $log_level         = $parameter->{log_level}                        ? $parameter->{log_level}         : 0;
	my $file              = $parameter->{file}                             ? $parameter->{file}              : "";
	my $line              = $parameter->{line}                             ? $parameter->{line}              : "";
	my $title_key         = $parameter->{title_key}                        ? $parameter->{title_key}         : "tools_default_0001";
	my $title_variables   = ref($parameter->{title_variables}) eq "HASH"   ? $parameter->{title_variables}   : "";
	my $message_key       = $parameter->{message_key}                      ? $parameter->{message_key}       : "";
	my $message_variables = ref($parameter->{message_variables}) eq "HASH" ? $parameter->{message_variables} : "";
	my $language          = $parameter->{language}                         ? $parameter->{language}          : $an->default_log_language;
	my $raw               = $parameter->{raw}                              ? $parameter->{raw}               : "";
	my $log_to            = $parameter->{log_to}                           ? $parameter->{log_to}            : $an->default_log_file;
	my $debug             = $parameter->{debug}                            ? $parameter->{debug}             : 0;
	
	# Return if the log level of the message is less than the current system log level.
	return(1) if $log_level > $an->Log->level;
	
	# Get the current data and time.
	my ($now_date, $now_time) = $an->Get->date_and_time();
	
	# If 'raw' is set, just write to the file handle. Otherwise, parse the
	# entry.
	if ($raw)
	{
		$string = "$now_date $now_time: $raw";
	}
	else
	{
		# Create the log string. 
		my $title = $title_key ? $an->String->get({
			key		=>	$title_key,
			variables	=>	$title_variables,
			languages	=>	$language,
		}) : "";
		
		#if ($message_variables)
		#{
		#	use Data::Dumper;
		#	print Dumper $message_variables if $debug;
		#	print "$THIS_FILE ".__LINE__."; message_key: [$message_key], message_variables: [$message_variables]\n" if $debug;
		#}
		my $message = $message_key ? $an->String->get({
			key		=>	$message_key,
			variables	=>	$message_variables,
			languages	=>	$language,
		}) : "";
		#print "$THIS_FILE ".__LINE__."; message: [$message]\n" if $debug;
		
		if ($title)
		{
			if ($an->data->{sys}{'log'}{log_pid})
			{
				$string = "$now_date $now_time - ".$$." - $file $line; [ $title ] - $message";
			}
			else
			{
				$string = "$now_date $now_time - $file $line; [ $title ] - $message";
			}
		}
		else
		{
			if ($an->data->{sys}{logging}{log_pid})
			{
				$string = "$now_date $now_time - ".$$." - $file $line; $message";
			}
			else
			{
				$string = "$now_date $now_time - $file $line; $message";
			}
		}
	}

	### TODO: Record the file handles so we don't incure the overhead of 
	###       opening the file for every message.
	# Write the entry
	if ($log_to)
	{
		my $shell_call = ">>$log_to";
		#print "$THIS_FILE ".__LINE__."; shell_call: [$shell_call], string: [$string]\n" if $debug;
		$string .= "\n" if $string !~ /\n$/;
		open (my $filehandle, "$shell_call") or die "Failed to write: [$log_to]. Error: $!\n";
		print $filehandle $string;
		close $filehandle;
	}
	else
	{
		foreach my $line (split/\n/, $string)
		{
			# We need to escape single-quotes
			$line =~ s/'/'\\\''/g;
			
			# This is needed to make logger print an empty line.
			$line = "' '" if $line eq "";
			
			#print "$THIS_FILE ".__LINE__."; [ Debug ] - line: [$line]\n" if $debug;
			my $shell_call = "logger -- '$line'";
			if ($file)
			{
				$shell_call =~ s/logger /logger -t $file /;
			}
			if ($shell_call =~ /^(logger .*)$/) { $shell_call = $1; }
			#print "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n" if $debug;
			open (my $filehandle, "$shell_call 2>&1 |") or die "Failed to call: [$shell_call]. Error: $!\n";
			while (<$filehandle>)
			{
				print $_ if $debug;
			}
			close $filehandle;
		}
	}
	
	# This returns the exact string written to the log, if any.
	return($string);
}

### WARNING: DO NOT CALL $an->Log->entry() in this method! It will loop because that method calls this one.
# This sets or returns the log level.
sub level
{
	my $self = shift;
	my $set  = shift if defined $_[0];
	my $an   = $self->parent;
	
	if ((defined $set) && ($set =~ /\D/))
	{
		$an->Alert->error({fatal => 1, title_key => "error_title_0009", message_key => "error_message_0012", message_variables => {
			set	=>	$set,
		}, code => 19, file => "$THIS_FILE", line => __LINE__});
		# Return nothing in case the user is blocking fatal errors.
		return (undef);
	}
	
	$self->{LOG_LEVEL} = $set if defined $set;
	
	return ($self->{LOG_LEVEL});
}


#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

1;
