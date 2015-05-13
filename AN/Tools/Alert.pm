package AN::Tools::Alert;

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Alert.pm";


sub new
{
	#print "$THIS_FILE ".__LINE__."; In AN::Alert->new()\n";
	my $class = shift;
	
	my $self = {
		NO_FATAL_ERRORS		=>	0,
		SILENCE_WARNINGS	=>	0,
		ERROR_STRING		=>	"",
		ERROR_CODE		=>	0,
		OS_VALUES		=>	{
			DIRECTORY_DELIMITER	=>	"/",
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

# This registers an alert with ScanCore
sub register_alert
{
	my $self  = shift;
	my $parameter = shift;
	
	# Clear any prior errors.
# 	$self->_set_error;
	my $an = $self->parent;
	
	my $alert_agent_name        = $parameter->{alert_agent_name}        ? $parameter->{alert_agent_name}        : ""; # This should error.
	my $alert_level             = $parameter->{alert_level}             ? $parameter->{alert_level}             : "warning";	# Not being set by the agent should be treated as a bug.
	my $alert_title_key         = $parameter->{alert_title_key}         ? $parameter->{alert_title_key}         : "an_alert_title_0003";
	my $alert_title_variables   = $parameter->{alert_title_variables}   ? $parameter->{alert_title_variables}   : "";
	my $alert_message_key       = $parameter->{alert_message_key}       ? $parameter->{alert_message_key}       : ""; # This should error.
	my $alert_message_variables = $parameter->{alert_message_variables} ? $parameter->{alert_message_variables} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_vars => {
		name1 => "alert_agent_name",        value1 => $alert_agent_name,
		name2 => "alert_level",             value2 => $alert_level,
		name3 => "alert_title_key",         value3 => $alert_title_key,
		name4 => "alert_title_variables",   value4 => $alert_title_variables, 
		name5 => "alert_message_key",       value5 => $alert_message_key, 
		name6 => "alert_message_variables", value6 => $alert_message_variables
	}, file => $THIS_FILE, line => __LINE__});
	
	my $title_variables = "";
	if (ref($alert_title_variables) eq "HASH")
	{
		foreach my $key (sort {$a cmp $b} keys %{$alert_title_variables})
		{
			$title_variables .= "#!$key!$alert_title_variables->{$key}!#,";
		}
	}
	my $message_variables = "";
	if (ref($alert_message_variables) eq "HASH")
	{
		foreach my $key (sort {$a cmp $b} keys %{$alert_message_variables})
		{
			$alert_message_variables->{$key} = "--" if not defined $alert_message_variables->{$key};
			$message_variables .= "#!$key!$alert_message_variables->{$key}!#,";
		}
	}
	
	# Always INSERT. ScanCore removes them as they're acted on (copy is left in history.alerts).
	my $query = "
INSERT INTO 
    alerts
(
    alert_host_id, 
    alert_agent_name, 
    alert_level, 
    alert_title_key, 
    alert_title_variables, 
    alert_message_key, 
    alert_message_variables, 
    modified_date
) VALUES (
    (".$an->data->{sys}{host_id_query}."), 
    ".$an->data->{sys}{use_db_fh}->quote($alert_agent_name).", 
    ".$an->data->{sys}{use_db_fh}->quote($alert_level).", 
    ".$an->data->{sys}{use_db_fh}->quote($alert_title_key).", 
    ".$an->data->{sys}{use_db_fh}->quote($title_variables).", 
    ".$an->data->{sys}{use_db_fh}->quote($alert_message_key).", 
    ".$an->data->{sys}{use_db_fh}->quote($message_variables).",
    ".$an->data->{sys}{db_timestamp}."
);
";
	
	# Record!
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_vars => {
		name1 => "query",  value1 => $query,
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->DB->do_db_write({query => $query});
	
	return(0);
}

# Later, this will support all the translation and logging methods. For now,
# just print the error and exit;
sub error
{
	my $self  = shift;
	my $parameter = shift;
	
	# Clear any prior errors.
# 	$self->_set_error;
	my $an = $self->parent;
	
	# Setup default values
	my ($fatal, $title_key, $title_variables, $message_key, $message_vars, $code, $file, $line);
	
	# See if I am getting parameters is a hash reference or directly as
	# element arrays.
	if (ref($parameter))
	{
		# Called via a hash ref, good.
		$fatal  	= $parameter->{fatal}		? $parameter->{fatal}		: 1;
		$title_key	= $parameter->{title_key}	? $parameter->{title_key}	: $an->String->get({key => "an_0004"});
		$title_variables	= $parameter->{title_vars}	? $parameter->{title_vars}	: "";
		$message_key	= $parameter->{message_key}	? $parameter->{message_key}	: $an->String->get({key => "an_0005"});
		$message_vars	= $parameter->{message_vars}	? $parameter->{message_vars}	: "";
		$code   	= $parameter->{code}		? $parameter->{code}		: 1;
		$file		= $parameter->{file}		? $parameter->{file}		: $an->String->get({key => "an_0006"});
		$line		= $parameter->{line}		? $parameter->{line}		: "";
		#print "$THIS_FILE ".__LINE__."; fatal: [$fatal], title: [$title], title_vars: [$title_variables], message_key: [$message_key], message_vars: [$message_vars], code: [$code], file: [$file], line: [$line]\n";
	}
	else
	{
		# Called directly.
		$fatal		= $parameter ? $parameter : 1;
		$title_key	= shift;
		$title_variables	= shift;
		$message_key	= shift;
		$message_vars	= shift;
		$code		= shift;
		$file		= shift;
		$line		= shift;
		#print "$THIS_FILE ".__LINE__."; fatal: [$fatal], title_key: [$title_key], title_vars: [$title_variables], message_key: [$message_key], message_vars: [$message_vars], code: [$code], file: [$file], line: [$line]\n";
	}
	
	# It is possible for this to become a run-away call, so this helps
	# catch when that happens.
	$an->_error_count($an->_error_count + 1);
	if ($an->_error_count > $an->_error_limit)
	{
		print "Infinite loop detected while trying to print an error:\n";
		print "- fatal:        [$fatal]\n";
		print "- title_key:    [$title_key]\n";
		print "- title_vars:   [$title_variables]\n";
		print "- message_key:  [$message_key]\n";
		print "- message_vars: [$title_variables]\n";
		print "- code:         [$code]\n";
		print "- file:         [$file]\n";
		print "- line:         [$line]\n";
		die "Infinite loop detected while trying to print an error, exiting.\n";
	}
	
	# If the 'code' is empty and 'message' is "error_\d+", strip that code
	# off and use it as the error code.
	#print "$THIS_FILE ".__LINE__."; code: [$code], message_key: [$message_key]\n";
	if ((not $code) && ($message_key =~ /error_(\d+)/))
	{
		$code = $1;
		#print "$THIS_FILE ".__LINE__."; code: [$code], message_key: [$message_key]\n";
	}
	
	# If the title is a key, translate it.
	#print "$THIS_FILE ".__LINE__."; title_key: [$title_key]\n";
	if ($title_key =~ /\w+_\d+$/)
	{
		$title_key = $an->String->get({
			key		=>	$title_key,
			variables	=>	$title_variables,
		});
		print "$THIS_FILE ".__LINE__."; title_key: [$title_key]\n";
	}
	
	# If the message is a key, translate it.
	#print "$THIS_FILE ".__LINE__."; message_key: [$message_key]\n";
	if ($message_key =~ /\w+_\d+$/)
	{
		$message_key = $an->String->get({
			key		=>	$message_key,
			variables	=>	$message_vars,
		});
		#print "$THIS_FILE ".__LINE__."; message_key: [$message_key]\n";
	}
	
	# Set my error string
	my $fatal_heading = $fatal ? $an->String->get({key => "an_0002"}) : $an->String->get({key => "an_0003"});
	#print "$THIS_FILE ".__LINE__."; fatal_heading: [$fatal_heading]\n";
	
	my $readable_line = $an->Readable->comma($line);
	#print "$THIS_FILE ".__LINE__."; readable_line: [$readable_line]\n";
	
	### TODO: Copy this to 'warning'.
	# At this point, the title and message keys are the actual messages.
	my $error = "\n".$an->String->get({
		key		=>	"an_0007",
		variables	=>	{
			code		=>	$code,
			heading		=>	$fatal_heading,
			file		=>	$file,
			line		=>	$readable_line,
			title		=>	$title_key,
			message		=>	$message_key,
		},
	})."\n\n";
	#print "$THIS_FILE ".__LINE__."; error: [$error]\n";
	
	# Set the internal error flags
	$self->_set_error($error);
	$self->_set_error_code($code);
	
	# Append "exiting" to the error string if it is fatal.
	if ($fatal)
	{
		# Don't append this unless I really am exiting.
		$error .= $an->String->get({key => "an_0008"})."\n";
	}
	
	# Write a copy of the error to the log.
	$an->Log->entry({
		file		=>	$THIS_FILE,
		level		=>	1,
		raw		=>	$error,
	});
	
	# Don't actually die, but do print the error, if fatal errors have been
	# globally disabled (as is done in the tests).
	if ($self->no_fatal_errors == 0)
	{
		#$error =~ s/\n/<br \/>\n/g;
		print "$error\n" if not $self->no_fatal_errors;
		$self->_nice_exit($code);
	}
	
	return ($code);
}

# Later, this will support all the translation and logging methods. For now,
# just print the warning and return;
sub warning
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	
	# Clear any prior errors.
	$self->_set_error;
	
	# Setup default values
	my $title_key    = "";
	my $title_variables   = "";
	my $message_key  = "";
	my $message_vars = "";
	my $code         = 1;
	my $file         = "";
	my $line         = 0;
	my $log_to       = "";
	
	# See if I am getting parameters is a hash reference or directly as
	# element arrays.
	if (ref($parameter))
	{
		# Called via a hash ref, good.
		$title_key    = $parameter->{title_key}    ? $parameter->{title_key}    : "";
		$title_variables   = $parameter->{title_vars}   ? $parameter->{title_vars}   : "";
		$message_key  = $parameter->{message_key}  ? $parameter->{message_key}  : ""; # This should cause an error
		$message_vars = $parameter->{message_vars} ? $parameter->{message_vars} : "";
		$file         = $parameter->{file}         ? $parameter->{file}         : ""; # This should cause an error
		$line         = $parameter->{line}         ? $parameter->{line}         : ""; # This should cause an error
		$log_to       = $parameter->{log_to}       ? $parameter->{log_to}       : "";
	}
	else
	{
		# Called directly.
		$title_key    = $parameter;
		$title_variables   = shift;
		$message_key  = shift;
		$message_vars = shift;
		$file         = shift;
		$line         = shift;
		$log_to       = shift;
	}
	if (0)
	{
		print "$THIS_FILE ".__LINE__."; title_key: [$title_key], title_vars: [$title_variables], message_key: [$message_key], message_vars: [$message_vars], file: [$file], line: [$line], log_to: [$log_to]\n";
		use Data::Dumper;
		if ($title_variables)   { print "$THIS_FILE ".__LINE__."; Title vars hash:\n"; print Dumper $title_variables; }
		if ($message_vars) { print "$THIS_FILE ".__LINE__."; Message vars hash:\n"; print Dumper $message_vars; }
	}
	
	# Turn the arguments into strings.
	
	# It is possible for this to become a run-away call, so this helps
	# catch when that happens.
	$an->_error_count($an->_error_count + 1);
	if ($an->_error_count > $an->_error_limit)
	{
		print "Infinite loop detected while trying to print a warning:\n";
		print "- title_key:    [$title_key]\n";
		print "- title_vars:   [$title_variables]\n";
		print "- message_key:  [$message_key]\n";
		print "- message_vars: [$title_variables]\n";
		print "- code:         [$code]\n";
		print "- file:         [$file]\n";
		print "- line:         [$line]\n";
		die "Infinite loop detected while trying to print a warning, exiting.\n";
	}
	
	# If the title is a key, translate it.
	#print "$THIS_FILE ".__LINE__."; title_key: [$title_key]\n";
	if ($title_key =~ /\w+_\d+$/)
	{
		$title_key = $an->String->get({
			key		=>	$title_key,
			variables	=>	$title_variables,
		});
		#print "$THIS_FILE ".__LINE__."; title_key: [$title_key]\n";
	}
	
	# If the message is a key, translate it.
	#print "$THIS_FILE ".__LINE__."; message_key: [$message_key], message_vars: [$message_vars]\n";
	if ($message_key =~ /\w+_\d+$/)
	{
		$message_key = $an->String->get({
			key		=>	$message_key,
			variables	=>	$message_vars,
		});
		#print "$THIS_FILE ".__LINE__."; message_key: [$message_key]\n";
	}
	
	my $readable_line = $an->Readable->comma($line);
	#print "$THIS_FILE ".__LINE__."; readable_line: [$readable_line]\n";
	
	# At this point, the title and message keys are the actual messages.
	my $warning = "";
	if ($title_key)
	{
		$warning = $an->String->get({
			key		=>	"an_0009",
			variables	=>	{
				file		=>	$file,
				line		=>	$readable_line,
				title		=>	$title_key,
				message		=>	$message_key,
			},
		});
	}
	else
	{
		# This is usually a continuation of an earlier warning.
		$warning = $an->String->get({
			key		=>	"an_0010",
			variables	=>	{
				message		=>	$message_key,
			},
		});
	}
	#print "$THIS_FILE ".__LINE__."; warning: [$warning]\n";
	
	### TODO: Make sure this is using the log language.
	# Write a copy of the error to the log.
	$an->Log->entry({
		file		=>	$THIS_FILE,
		level		=>	1,
		raw		=>	$warning,
		log_to		=>	$log_to,
	});
	
	if ($title_key)
	{
		print "\n";
	}
	print "$warning\n";
	
	return (1);
}

# This stops the 'warning' method from printing to STDOUT. It will still print
# to the log though (once that's implemented).
sub silence_warnings
{
	my $self  = shift;
	my $parameter = shift;
	
	# Have to check if defined because '0' is valid.
	if (defined $parameter->{set})
	{
		$self->{SILENCE_WARNINGS} = $parameter->{set} if (($parameter->{set} == 0) || ($parameter->{set} == 1));
	}
	
	return ($self->{SILENCE_WARNINGS});
}

# This un/sets the prevention of errors being fatal.
sub no_fatal_errors
{
	my $self  = shift;
	my $parameter = shift;
	
	# Have to check if defined because '0' is valid.
	if (defined $parameter->{set})
	{
		$self->{NO_FATAL_ERRORS} = $parameter->{set} if (($parameter->{set} == 0) || ($parameter->{set} == 1));
	}
	
	return ($self->{NO_FATAL_ERRORS});
}

# This returns an error message if one is set.
sub _error_string
{
	my $self = shift;
	return $self->{ERROR_STRING};
}

# This returns an error code if one is set.
sub _error_code
{
	my $self = shift;
	return $self->{ERROR_CODE};
}

# This simply sets the error string method. Calling this method with an empty
# but defined string will clear the error message.
sub _set_error
{
	my $self  = shift;
	my $error = shift;
	
	# This is a bit of a cheat, but it saves a call when a method calls
	# this just to clear the error message.
	if ($error)
	{
		$self->{ERROR_STRING} = $error;
	}
	else
	{
		$self->{ERROR_STRING} = "";
		$self->{ERROR_CODE}   = 0;
	}
	
	return $self->{ERROR_STRING};
}

# This simply sets the error code method. Calling this method with an empty
# but defined string will clear the error code.
sub _set_error_code
{
	my $self  = shift;
	my $error = shift;
	
	$self->{ERROR_CODE} = $error ? $error : "";
	
	return $self->{ERROR_CODE};
}

# This will handle cleanup prior to exit.
sub _nice_exit
{
	my $self       = shift;
	my $error_code = $_[0] ? shift : 1;
	
	exit ($error_code);
}

1;
