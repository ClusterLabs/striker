package AN::Tools::Log;
# 
# This module contains methods used to handle logging events.
# 

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Log.pm";


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

# This sets or returns the log level.
sub level
{
	my $self = shift;
	my $set  = shift if defined $_[0];
	
	my $an   = $self->parent;
	$an->Alert->_set_error;
	
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

# This, when set, causes DB transactions to be logged.
sub db_transactions
{
	my $self = shift;
	my $set  = shift if defined $_[0];
	my $an   = $self->parent;
	$an->Alert->_set_error;
	
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
	$an->Alert->_set_error;
	
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
			$string = "$now_date $now_time - $file $line; [ $title ] - $message";
		}
		else
		{
			$string = "$now_date $now_time - $file $line; $message";
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

1;
