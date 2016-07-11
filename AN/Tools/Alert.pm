package AN::Tools::Alert;
# 
# This module contains methods used to handle alerts and errors.
# 

use strict;
use warnings;

our $VERSION  = "0.1.001";
my $THIS_FILE = "Alert.pm";

### Methods;
# check_alert_sent
# convert_level_name_to_number
# convert_level_number_to_name
# error
# no_fatal_errors
# register_alert
# silence_warnings
# warning
# _error_code
# _error_string
# _nice_exit
# _set_error
# _set_error_code


#############################################################################################################
# House keeping methods                                                                                     #
#############################################################################################################

sub new
{
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

# This is used by scan agents that need to track whether an alert was sent when a sensor dropped below/rose 
# above a set alert threshold. For example, if a sensor alerts at 20°C and clears at 25°C, this will be 
# called when either value is passed. When passing the warning threshold, the alert is registered and sent to
# the user. Once set, no further warning alerts are sent. When the value passes over the clear threshold, 
# this is checked and if an alert was previously registered, it is removed and an "all clear" message is 
# sent. In this way, multiple alerts will not go out if a sensor floats around the warning threshold and a 
# "cleared" message won't be sent unless a "warning" message was previously sent.
sub check_alert_sent
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_alert_sent" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# This will get set to '1' if an alert is added or removed.
	my $set = 0;
	
	# If 'type' is 'warning', an entry will be made if it doesn't exist. If 'clear', an alert will be 
	# removed if it exists. 
	my $type                 = $parameter->{type}                 ? $parameter->{type}                 : ""; # This should error.
	my $alert_sent_by        = $parameter->{alert_sent_by}        ? $parameter->{alert_sent_by}        : "";
	my $alert_record_locator = $parameter->{alert_record_locator} ? $parameter->{alert_record_locator} : "";
	my $alert_name           = $parameter->{alert_name}           ? $parameter->{alert_name}           : "";
	my $modified_date        = $parameter->{modified_date}        ? $parameter->{modified_date}        : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
		name1 => "type",                 value1 => $type, 
		name2 => "alert_sent_by",        value2 => $alert_sent_by, 
		name3 => "alert_record_locator", value3 => $alert_record_locator, 
		name4 => "alert_name",           value4 => $alert_name, 
		name5 => "modified_date",        value5 => $modified_date, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $query = "
SELECT 
    COUNT(*) 
FROM 
    alert_sent 
WHERE 
    alert_sent_host_uuid = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{host_uuid})." 
AND 
    alert_sent_by        = ".$an->data->{sys}{use_db_fh}->quote($alert_sent_by)." 
AND 
    alert_record_locator = ".$an->data->{sys}{use_db_fh}->quote($alert_record_locator)." 
AND 
    alert_name           = ".$an->data->{sys}{use_db_fh}->quote($alert_name)."
;";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $count = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__})->[0]->[0];
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "type",  value1 => $type, 
		name2 => "count", value2 => $count, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Now, if this is type=warning, register the alert if it doesn't exist. If it is type=clear, remove 
	# the alert if it exists.
	if (($type eq "warning") && (not $count))
	{
		### New alert
		# Make sure this host is in the database... It might not be on the very first run of ScanCore
		# before the peer exists (tried to connect to the peer, fails, tries to send an alert, but
		# this host hasn't been added because it's the very first attempt to connect...)
		if (not $an->data->{sys}{host_is_in_db})
		{
			my $query = "
SELECT 
    COUNT(*)
FROM 
    hosts 
WHERE 
    host_uuid = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{host_uuid})."
;";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "query", value1 => $query, 
			}, file => $THIS_FILE, line => __LINE__});
			my $count = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__})->[0]->[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "count", value1 => $count, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if (not $count)
			{
				# Too early, we can't set an alert.
				$an->Alert->warning({message_key => "error_message_0068", message_variables => {
					type			=>	$type, 
					alert_sent_by		=>	$alert_sent_by, 
					alert_record_locator	=>	$alert_record_locator, 
					alert_name		=>	$alert_name, 
					modified_date		=>	$modified_date,
				}, file => $THIS_FILE, line => __LINE__});
				return(0);
			}
			else
			{
				$an->data->{sys}{host_is_in_db} = 1;
			}
		}
		
		   $set   = 1;
		my $query = "
INSERT INTO 
    alert_sent 
(
    alert_sent_host_uuid, 
    alert_sent_by, 
    alert_record_locator, 
    alert_name, 
    modified_date
) VALUES (
    ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{host_uuid}).", 
    ".$an->data->{sys}{use_db_fh}->quote($alert_sent_by).", 
    ".$an->data->{sys}{use_db_fh}->quote($alert_record_locator).", 
    ".$an->data->{sys}{use_db_fh}->quote($alert_name).", 
    ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
);
";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "query", value1 => $query, 
			name2 => "set",   value2 => $set, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	}
	elsif (($type eq "clear") && ($count))
	{
		# Alert previously existed, clear it.
		   $set   = 1;
		my $query = "
DELETE FROM 
    alert_sent 
WHERE 
    alert_sent_host_uuid = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{host_uuid})." 
AND 
    alert_sent_by        = ".$an->data->{sys}{use_db_fh}->quote($alert_sent_by)." 
AND 
    alert_record_locator = ".$an->data->{sys}{use_db_fh}->quote($alert_record_locator)." 
AND 
    alert_name           = ".$an->data->{sys}{use_db_fh}->quote($alert_name)."
;";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "query", value1 => $query, 
			name2 => "set",   value2 => $set, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "set", value1 => $set, 
	}, file => $THIS_FILE, line => __LINE__});
	return($set);
}

# This converts a level name to a number for easier comparison.
sub convert_level_name_to_number
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "convert_level_name_to_number" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $level = $parameter->{level} ? $parameter->{level} : ""; # This should error.
	
	if ($level eq "debug")
	{
		$level = 5;
	}
	elsif ($level eq "info")
	{
		$level = 4;
	}
	elsif ($level eq "notice")
	{
		$level = 3;
	}
	elsif ($level eq "warning")
	{
		$level = 2;
	}
	elsif ($level eq "critical")
	{
		$level = 1;
	}
	elsif ($level eq "ignore")
	{
		$level = 0;
	}
	
	return ($level);
}

# This converts an alert level number to a name.
sub convert_level_number_to_name
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "convert_level_number_to_name" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $level = $parameter->{level} ? $parameter->{level} : ""; # This should error.
	
	if ($level eq "5")
	{
		# Debug
		$level = "debug";
	}
	elsif ($level eq "4")
	{
		# Info
		$level = "info";
	}
	elsif ($level eq "3")
	{
		# Notice
		$level = "notice";
	}
	elsif ($level eq "2")
	{
		# Warning
		$level = "warning";
	}
	elsif ($level eq "1")
	{
		# Critical
		$level = "critical";
	}
	
	return ($level);
}

# Later, this will support all the translation and logging methods. For now, just print the error and exit.
sub error
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "error" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Setup default values
	my ($fatal, $title_key, $title_variables, $message_key, $message_variables, $code, $file, $line);
	
	# See if I am getting parameters is a hash reference or directly as
	# element arrays.
	if (ref($parameter))
	{
		# Called via a hash ref, good.
		$fatal             = $parameter->{fatal}             ? $parameter->{fatal}             : 1;
		$title_key         = $parameter->{title_key}         ? $parameter->{title_key}         : $an->String->get({key => "an_0004"});
		$title_variables   = $parameter->{title_variables}   ? $parameter->{title_variables}   : "";
		$message_key       = $parameter->{message_key}       ? $parameter->{message_key}       : $an->String->get({key => "an_0005"});
		$message_variables = $parameter->{message_variables} ? $parameter->{message_variables} : "";
		$code              = $parameter->{code}              ? $parameter->{code}              : 1;
		$file              = $parameter->{file}              ? $parameter->{file}              : $an->String->get({key => "an_0006"});
		$line              = $parameter->{line}              ? $parameter->{line}              : "";
		#print "$THIS_FILE ".__LINE__."; fatal: [$fatal], title_key: [$title_key], title_variables: [$title_variables], message_key: [$message_key], message_variables: [$message_variables], code: [$code], file: [$file], line: [$line]\n";
	}
	else
	{
		# Called directly.
		$fatal			= $parameter ? $parameter : 1;
		$title_key		= shift;
		$title_variables	= shift;
		$message_key		= shift;
		$message_variables	= shift;
		$code			= shift;
		$file			= shift;
		$line			= shift;
		#print "$THIS_FILE ".__LINE__."; fatal: [$fatal], title_key: [$title_key], title_variables: [$title_variables], message_key: [$message_key], message_variables: [$message_variables], code: [$code], file: [$file], line: [$line]\n";
	}
	
	# It is possible for this to become a run-away call, so this helps
	# catch when that happens.
	$an->_error_count($an->_error_count + 1);
	if ($an->_error_count > $an->_error_limit)
	{
		print "Infinite loop detected while trying to print an error:\n";
		print "- fatal:             [$fatal]\n";
		print "- title_key:         [$title_key]\n";
		print "- title_variables:   [$title_variables]\n";
		print "- message_key:       [$message_key]\n";
		print "- message_variables: [$title_variables]\n";
		print "- code:              [$code]\n";
		print "- file:              [$file]\n";
		print "- line:              [$line]\n";
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
		#print "$THIS_FILE ".__LINE__."; title_key: [$title_key]\n";
	}
	
	# If the message is a key, translate it.
	#print "$THIS_FILE ".__LINE__."; message_key: [$message_key]\n";
	if ($message_key =~ /\w+_\d+$/)
	{
		$message_key = $an->String->get({
			key		=>	$message_key,
			variables	=>	$message_variables,
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
	$an->Alert->_set_error($error);
	$an->Alert->_set_error_code($code);
	
	# Append "exiting" to the error string if it is fatal.
	if ($fatal)
	{
		# Don't append this unless I really am exiting.
		$error .= $an->String->get({key => "an_0008"})."\n";
	}
	
	# Write a copy of the error to the log.
	$an->Log->entry({file => $THIS_FILE, level => 0, raw => $error});
	
	# Don't actually die, but do print the error, if fatal errors have been globally disabled (as is done
	# in the tests).
	#if (($fatal) && (not $an->Alert->no_fatal_errors))
	if ($fatal)
	{
		if ($ENV{'HTTP_REFERER'})
		{
			print "<pre>\n";
			print "$error\n" if not $an->Alert->no_fatal_errors;
			print "</pre>\n";
		}
		else
		{
			print "$error\n" if not $an->Alert->no_fatal_errors;
		}
		$an->Alert->_nice_exit($code);
	}
	
	return ($code);
}

# This un/sets the prevention of errors being fatal.
sub no_fatal_errors
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "no_fatal_errors" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Have to check if defined because '0' is valid.
	if (defined $parameter->{set})
	{
		$an->Alert->{NO_FATAL_ERRORS} = $parameter->{set} if (($parameter->{set} == 0) || ($parameter->{set} == 1));
	}
	
	return ($an->Alert->{NO_FATAL_ERRORS});
}

# This registers an alert with ScanCore
sub register_alert
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "register_alert" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $alert_agent_name        = $parameter->{alert_agent_name}        ? $parameter->{alert_agent_name}        : die "$THIS_FILE ".__LINE__." 'alert_agent_name' parameter not passed to AN::Tools::Alert->register_alert()\n";
	my $alert_level             = $parameter->{alert_level}             ? $parameter->{alert_level}             : "warning";	# Not being set by the agent should be treated as a bug.
	my $alert_title_key         = $parameter->{alert_title_key}         ? $parameter->{alert_title_key}         : "an_alert_title_0003";
	my $alert_title_variables   = $parameter->{alert_title_variables}   ? $parameter->{alert_title_variables}   : "";
	my $alert_message_key       = $parameter->{alert_message_key}       ? $parameter->{alert_message_key}       : die "$THIS_FILE ".__LINE__." 'alert_message_key' parameter not passed to AN::Tools::Alert->register_alert()\n";
	my $alert_message_variables = $parameter->{alert_message_variables} ? $parameter->{alert_message_variables} : "";
	my $alert_sort              = $parameter->{alert_sort}              ? $parameter->{alert_sort}              : 9999;
	my $alert_header            = $parameter->{alert_header}            ? $parameter->{alert_header}            : 'TRUE';
	$an->Log->entry({log_level => 2, message_key => "an_variables_0008", message_variables => {
		name1 => "alert_agent_name",        value1 => $alert_agent_name,
		name2 => "alert_level",             value2 => $alert_level,
		name3 => "alert_title_key",         value3 => $alert_title_key,
		name4 => "alert_title_variables",   value4 => $alert_title_variables, 
		name5 => "alert_message_key",       value5 => $alert_message_key, 
		name6 => "alert_message_variables", value6 => $alert_message_variables, 
		name7 => "alert_sort",              value7 => $alert_sort, 
		name8 => "alert_header",            value8 => $alert_header, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# zero-pad sort numbers so that they sort properly.
	$alert_sort = sprintf("%04d", $alert_sort);
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "alert_sort", value1 => $alert_sort,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $title_variables = "";
	if (ref($alert_title_variables) eq "HASH")
	{
		foreach my $key (sort {$a cmp $b} keys %{$alert_title_variables})
		{
			$title_variables .= "!!$key!$alert_title_variables->{$key}!!,";
		}
	}
	my $message_variables = "";
	if (ref($alert_message_variables) eq "HASH")
	{
		foreach my $key (sort {$a cmp $b} keys %{$alert_message_variables})
		{
			$alert_message_variables->{$key} = "--" if not defined $alert_message_variables->{$key};
			$message_variables .= "!!$key!$alert_message_variables->{$key}!!,";
		}
	}
	
	# In most cases, no one is listening to 'debug' or 'info' level alerts. If that is the case here, 
	# don't record the alert because it can cause the history.alerts table to grow needlessly. So find
	# the lowest level log level actually being listened to and simply skip anything lower than that.
	# 5 == debug
	# 1 == critical
	my $lowest_log_level = 5;
	foreach my $integer (sort {$a cmp $b} keys %{$an->data->{alerts}{recipient}})
	{
		# We want to know the alert level, regardless of whether the recipient is an email of file 
		# target.
		my $this_level;
		if ($an->data->{alerts}{recipient}{$integer}{email})
		{
			# Email recipient
			$this_level = ($an->data->{alerts}{recipient}{$integer}{email} =~ /level="(.*?)"/)[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "this_level", value1 => $this_level,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($an->data->{alerts}{recipient}{$integer}{file})
		{
			# File target
			$this_level = ($an->data->{alerts}{recipient}{$integer}{file} =~ /level="(.*?)"/)[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "this_level", value1 => $this_level,
			}, file => $THIS_FILE, line => __LINE__});
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "this_level",  value1 => $this_level,
		}, file => $THIS_FILE, line => __LINE__});
		if ($this_level)
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "this_level",  value1 => $this_level,
			}, file => $THIS_FILE, line => __LINE__});
			$this_level = $an->Alert->convert_level_name_to_number({level => $this_level});
			
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "this_level",       value1 => $this_level,
				name2 => "lowest_log_level", value2 => $lowest_log_level,
			}, file => $THIS_FILE, line => __LINE__});
			if ($this_level < $lowest_log_level)
			{
				$lowest_log_level = $this_level;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "lowest_log_level", value1 => $lowest_log_level,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Now get the numeric value of this alert and return if it is higher.
	my $this_level = $an->Alert->convert_level_name_to_number({level => $alert_level});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "alert_level",      value1 => $alert_level,
		name2 => "this_level",       value2 => $this_level,
		name3 => "lowest_log_level", value3 => $lowest_log_level,
	}, file => $THIS_FILE, line => __LINE__});
	if ($this_level > $lowest_log_level)
	{
		# Return.
		$an->Log->entry({log_level => 3, message_key => "tools_log_0004", message_variables => {
			message_key => "$alert_message_key"
		}, file => $THIS_FILE, line => __LINE__});
		return(0);
	}
	
	# Always INSERT. ScanCore removes them as they're acted on (copy is left in history.alerts).
	my $query = "
INSERT INTO 
    alerts
(
    alert_uuid, 
    alert_host_uuid, 
    alert_agent_name, 
    alert_level, 
    alert_title_key, 
    alert_title_variables, 
    alert_message_key, 
    alert_message_variables, 
    alert_sort, 
    alert_header, 
    modified_date
) VALUES (
    ".$an->data->{sys}{use_db_fh}->quote($an->Get->uuid()).", 
    ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{host_uuid}).", 
    ".$an->data->{sys}{use_db_fh}->quote($alert_agent_name).", 
    ".$an->data->{sys}{use_db_fh}->quote($alert_level).", 
    ".$an->data->{sys}{use_db_fh}->quote($alert_title_key).", 
    ".$an->data->{sys}{use_db_fh}->quote($title_variables).", 
    ".$an->data->{sys}{use_db_fh}->quote($alert_message_key).", 
    ".$an->data->{sys}{use_db_fh}->quote($message_variables).",
    ".$an->data->{sys}{use_db_fh}->quote($alert_sort).", 
    ".$an->data->{sys}{use_db_fh}->quote($alert_header).", 
    ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
);
";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "query", value1 => $query,
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
	
	return(0);
}

# This stops the 'warning' method from printing to STDOUT. It will still print to the log though (once that's
# implemented).
sub silence_warnings
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "silence_warnings" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Have to check if defined because '0' is valid.
	if (defined $parameter->{set})
	{
		$an->Alert->{SILENCE_WARNINGS} = $parameter->{set} if (($parameter->{set} == 0) || ($parameter->{set} == 1));
	}
	
	return ($an->Alert->{SILENCE_WARNINGS});
}

# Later, this will support all the translation and logging methods. For now, just print the warning and 
# return.
sub warning
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "warning" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Setup default values
	my $title_key         = $parameter->{title_key}         ? $parameter->{title_key}         : "";
	my $title_variables   = $parameter->{title_variables}   ? $parameter->{title_variables}   : "";
	my $message_key       = $parameter->{message_key}       ? $parameter->{message_key}       : "";
	my $message_variables = $parameter->{message_variables} ? $parameter->{message_variables} : "";
	my $file              = $parameter->{file}              ? $parameter->{file}              : "";
	my $line              = $parameter->{line}              ? $parameter->{line}              : "";
	my $log_to            = $parameter->{log_to}            ? $parameter->{log_to}            : $an->default_log_file();
	my $quiet             = $parameter->{quiet}             ? $parameter->{quiet}             : 0;
	my $code              = 1;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0008", message_variables => {
		name1 => "title_key",         value1 => $title_key, 
		name2 => "title_variables",   value2 => $title_variables, 
		name3 => "message_key",       value3 => $message_key, 
		name4 => "message_variables", value4 => $message_variables, 
		name5 => "file",              value5 => $file, 
		name6 => "line",              value6 => $line, 
		name7 => "log_to",            value7 => $log_to, 
		name8 => "quiet",             value8 => $quiet, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Turn the arguments into strings.
	# It is possible for this to become a run-away call, so this helps catch when that happens.
	$an->_error_count($an->_error_count + 1);
	if ($an->_error_count > $an->_error_limit)
	{
		print "Infinite loop detected while trying to print a warning:\n";
		print "- title_key:         [$title_key]\n";
		print "- title_variables:   [$title_variables]\n";
		print "- message_key:       [$message_key]\n";
		print "- message_variables: [$title_variables]\n";
		print "- code:              [$code]\n";
		print "- file:              [$file]\n";
		print "- line:              [$line]\n";
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
	#print "$THIS_FILE ".__LINE__."; message_key: [$message_key], message_variables: [$message_variables]\n";
	if ($message_key =~ /\w+_\d+$/)
	{
		$message_key = $an->String->get({
			key		=>	$message_key,
			variables	=>	$message_variables,
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
	
	# If not quieted, print to stdout.
	if ($title_key)
	{
		print "\n" if not $quiet;
	}
	print "$warning\n" if not $quiet;
	
	# Reset the error counter.
	$an->_error_count(0);
	
	return (1);
}


#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

# This returns an error code if one is set.
sub _error_code
{
	my $self = shift;
	my $an   = $self->parent;
	return $an->Alert->{ERROR_CODE};
}

# This returns an error message if one is set.
sub _error_string
{
	my $self = shift;
	my $an   = $self->parent;
	return $an->Alert->{ERROR_STRING};
}

# This will handle cleanup prior to exit.
sub _nice_exit
{
	my $self       = shift;
	my $error_code = $_[0] ? shift : 1;
	
	exit ($error_code);
}

# This simply sets the error string method. Calling this method with an empty
# but defined string will clear the error message.
sub _set_error
{
	my $self  = shift;
	my $error = shift;
	my $an    = $self->parent;
	
	# This is a bit of a cheat, but it saves a call when a method calls
	# this just to clear the error message.
	if ($error)
	{
		$an->Alert->{ERROR_STRING} = $error;
	}
	else
	{
		$an->Alert->{ERROR_STRING} = "";
		$an->Alert->{ERROR_CODE}   = 0;
	}
	
	return $an->Alert->{ERROR_STRING};
}

# This simply sets the error code method. Calling this method with an empty
# but defined string will clear the error code.
sub _set_error_code
{
	my $self  = shift;
	my $error = shift;
	my $an    = $self->parent;
	
	$an->Alert->{ERROR_CODE} = $error ? $error : "";
	
	return $an->Alert->{ERROR_CODE};
}

1;
