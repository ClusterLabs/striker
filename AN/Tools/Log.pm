package AN::Tools::Log;

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
		$an->Alert->error({
			fatal		=>	1,
			title_key	=>	"error_title_0009",
			message_key	=>	"error_message_0012",
			message_vars	=>	{
				set		=>	$set,
			},
			code		=>	19,
			file		=>	"$THIS_FILE",
			line		=>	__LINE__
		});
		# Return nothing in case the user is blocking fatal
		# errors.
		return (undef);
	}
	
	$self->{LOG_LEVEL} = $set if defined $set;
	
	return ($self->{LOG_LEVEL});
}

# This does all the work of recording an entry in the log file when
# appropriate.
sub entry
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Alert->_set_error;
	
	# Setup my variables.
	my ($string, $log_level, $file, $line, $title_key, $title_vars, $message_key, $message_vars, $language, $log_to, $raw);
	
	# Now see if the user passed the values in a hash reference or
	# directly.
	#print "$THIS_FILE ".__LINE__."; parameter: [$parameter]\n";
	if (ref($parameter) eq "HASH")
	{
		# Values passed in a hash, good.
		$log_level    = $parameter->{log_level}                   ? $parameter->{log_level}    : 0;
		$file         = $parameter->{file}                        ? $parameter->{file}         : "";
		$line         = $parameter->{line}                        ? $parameter->{line}         : "";
		$title_key    = $parameter->{title_key}                   ? $parameter->{title_key}    : "tools_default_0001";
		$title_vars   = ref($parameter->{title_vars}) eq "HASH"   ? $parameter->{title_vars}   : "";
		$message_key  = $parameter->{message_key}                 ? $parameter->{message_key}  : "";
		$message_vars = ref($parameter->{message_vars}) eq "HASH" ? $parameter->{message_vars} : "";
		$language     = $parameter->{language}                    ? $parameter->{language}     : $an->default_log_language;
		$raw          = $parameter->{raw}                         ? $parameter->{raw}          : "";
		$log_to       = $parameter->{log_to}                      ? $parameter->{log_to}       : "";
		#print "$THIS_FILE ".__LINE__."; log_level: [$log_level (".$an->Log->level.")], file: [$file], line: [$line], title_key: [$title_key], title_vars: [$title_vars], message_key: [$message_key], message_vars: [$message_vars], language: [$language], raw: [$raw], log_to: [$log_to]\n";
	}
	else
	{
		# Values passed directly.
		$log_level    = defined $parameter ? $parameter : 0;
		$file         = defined $_[0]  ? $_[0]  : "";
		$line         = defined $_[1]  ? $_[1]  : "";
		$title_key    = defined $_[2]  ? $_[2]  : "";
		$title_vars   = defined $_[3]  ? $_[3]  : "";
		$message_key  = defined $_[4]  ? $_[4]  : "";
		$message_vars = defined $_[5]  ? $_[5]  : "";
		$language     = defined $_[6]  ? $_[6]  : $an->default_language;
		$log_to       = defined $_[7]  ? $_[7]  : "";
		$raw          = defined $_[8]  ? $_[8]  : "";
		#print "$THIS_FILE ".__LINE__."; log_level: [$log_level (".$an->Log->level.")], file: [$file], line: [$line], title_key: [$title_key], title_vars: [$title_vars], message_key: [$message_key], message_vars: [$message_vars], language: [$language], raw: [$raw], log_to: [$log_to]\n";
		#if ($message_vars)
		#{
		#	use Data::Dumper;
		#	print Dumper $message_vars;
		#}
	}
	
	# Return if the log level of the message is less than the current
	# system log level.
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
			variables	=>	$title_vars,
			languages	=>	$language,
		}) : "";
		
		#if ($message_vars)
		#{
		#	use Data::Dumper;
		#	print Dumper $message_vars;
		#	print "$THIS_FILE ".__LINE__."; message_key: [$message_key], message_vars: [$message_vars]\n";
		#}
		my $message = $message_key ? $an->String->get({
			key		=>	$message_key,
			variables	=>	$message_vars,
			languages	=>	$language,
		}) : "";
		#print "$THIS_FILE ".__LINE__."; message: [$message]\n";
		
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
	#print $filehandle $string, "\n";
	#print "$THIS_FILE ".__LINE__."; string: [$string]\n";
	if ($log_to)
	{
		my $shell_call = ">>$log_to";
		#print "$THIS_FILE ".__LINE__."; shell_call: [$shell_call], string: [$string]\n";
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
			
			#print "$THIS_FILE ".__LINE__."; [ Debug ] - line: [$line]\n";
			my $shell_call = "logger -- '$line'";
			if ($file)
			{
				$shell_call =~ s/logger /logger -t $file /;
			}
			if ($shell_call =~ /^(logger .*)$/) { $shell_call = $1; }
			#print "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n";
			open (my $filehandle, "$shell_call 2>&1 |") or die "Failed to call: [$shell_call]. Error: $!\n";
			while (<$filehandle>)
			{
				print $_;
			}
			close $filehandle;
		}
	}
	
	# This returns the exact string written to the log, if any.
	return($string);
}

1;
