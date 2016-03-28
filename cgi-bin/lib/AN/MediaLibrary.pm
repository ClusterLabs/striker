package AN::MediaLibrary;

# AN!MediaLibrary
# 
# This allows a mechanism for taking a CD or DVD, turning it into an ISO and
# pushing it to a cluster's /shared/files/ directory. It also allows for 
# connecting and disconnecting these ISOs to and from VMs.
# 
# BUG:
# - Uploading fails if the SSH fingerprint isn't recorded
# - Upload fails if /shared/files/ doesn't exist.
# 
# TODO:
# - Make uploads have a progress bar.
# - When an upload fails, do NOT clear the previous selection
# - Show file time-stamps
#
# 
# NOTE: The '$an' file handle has been added to all functions to enable the transition to using AN::Tools.
# 

use strict;
use warnings;
use IO::Handle;
use CGI;
use Encode;
use CGI::Carp "fatalsToBrowser";

# Setup for UTF-8 mode.
binmode STDOUT, ":utf8:";
$ENV{'PERL_UNICODE'} = 1;
my $THIS_FILE = "mediaLibrary.pm";


# Do whatever the user has asked.
sub process_task
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "process_task" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "Task", value1 => $conf->{cgi}{task},
	}, file => $THIS_FILE, line => __LINE__});
	if ($conf->{cgi}{task} eq "image_and_upload")
	{
		if ($conf->{cgi}{confirm})
		{
			# Proceed.
			image_and_upload($conf);
		}
		else
		{
			# Get the user to confirm.
			confirm_image_and_upload($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "delete")
	{
		if ($conf->{cgi}{confirm})
		{
			# Proceed.
			delete_file($conf);
		}
		else
		{
			# Get the user to confirm.
			confirm_delete_file($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "upload_file")
	{
		save_file_to_disk($conf);
	}
	elsif ($conf->{cgi}{task} eq "download_url")
	{
		if ($conf->{cgi}{confirm})
		{
			# Proceed.
			download_url($conf);
		}
		else
		{
			# Get the user to confirm.
			confirm_download_url($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "make_plain_text")
	{
		toggle_executable($conf, "off");
	}
	elsif ($conf->{cgi}{task} eq "make_executable")
	{
		toggle_executable($conf, "on");
	}
	
	return (0);
}

# This chmod's the file to 755 if 'on' and 644 if 'off'.
sub toggle_executable
{
	my ($conf, $turn) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "toggle_executable" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "turn", value1 => $turn, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $file = $an->data->{path}{shared_files}."/".$an->data->{cgi}{name};
	my $mode = $turn eq "on" ? "755" : "644";
	my $node = $an->data->{sys}{use_node};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "file", value1 => $file,
		name2 => "mode", value2 => $mode,
		name3 => "node", value3 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $shell_call = $an->data->{path}{'chmod'}." $mode $file";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node",       value1 => $node, 
		name2 => "shell_call", value2 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$an->data->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Show the files.
	AN::MediaLibrary::read_shared($conf);
	
	return(0);
}

# This downloads a given URL directly to the cluster using 'wget'.
sub download_url
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "download_url" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Show the 'scanning in progress' table.
	# variables hash feeds 'message_0272'.
	print AN::Common::template($conf, "common.html", "scanning-message", {}, {
		anvil	=>	$conf->{cgi}{cluster},
	});
	
	my $cluster       = $conf->{cgi}{cluster};
	my $url           = $conf->{cgi}{url};
	my ($base, $file) = ($url =~ /^(.*)\/(.*?)$/);
	$base .= "/" if $base !~ /\/$/;
	
	my ($node) = AN::Cluster::read_files_on_shared($conf);
	print AN::Common::template($conf, "media-library.html", "download-website-header", {
		file	=>	$file,
		base	=>	$base,
	});

	my $failed          = 0;
	my $header_printed  = 0;
	my $progress_points = 5;
	my $next_percent    = $progress_points;
	my $shell_call      = $an->data->{path}{wget}." -c --progress=dot -e dotbytes=10M $url -O ".$an->data->{path}{shared_files}."/$file";
	my $password        = $conf->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$conf->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		### TODO: This doesn't work anymore because the 'remote_call()' function returns all output
		###       in one go. Add a section to remote_call that does this for wget calls.
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/“/"/g;
		$line =~ s/”/"/g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if (($line =~ /Name or service not known/i) or ($line =~ /unable to resolve/i))
		{
			$failed = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "failed", value1 => $failed, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		if ($line =~ /^(\d+)K .*? (\d+)% (.*?)(\w) (.*?)$/)
		{
			my $received = $1;
			my $percent  = $2;
			my $rate     = $3;
			my $rate_suf = $4;
			my $time     = $5;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "percent",      value1 => $percent,
				name2 => "next percent", value2 => $next_percent,
			}, file => $THIS_FILE, line => __LINE__});
			if ($percent eq "100")
			{
				print AN::Common::template($conf, "media-library.html", "download-website-complete");
			}
			elsif ($percent >= $next_percent)
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "percent",      value1 => $percent,
					name2 => "next percent", value2 => $next_percent,
					name3 => "received",     value3 => $received,
					name4 => "rate",         value4 => $rate,
					name5 => "time",         value5 => $time,
				}, file => $THIS_FILE, line => __LINE__});
				# This prevents multiple prints when the file
				# is partially downloaded.
				while ($percent >= $next_percent)
				{
					$next_percent += $progress_points;
				}
				$received        *= 1024;
				my $say_received =  AN::Cluster::bytes_to_hr($conf, $received);
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "received",     value1 => $received,
					name2 => "say_received", value2 => $say_received,
				}, file => $THIS_FILE, line => __LINE__});
				if (uc($rate_suf) eq "M")
				{
					$rate            =  int(($rate * (1024 * 1024)));
				}
				elsif (uc($rate_suf) eq "K")
				{
					$rate            =  int(($rate * 1024));
				}
				my $say_rate     =  AN::Cluster::bytes_to_hr($conf, $rate);
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "rate",     value1 => $rate,
					name2 => "say_rate", value2 => $say_rate,
				}, file => $THIS_FILE, line => __LINE__});
				my $hours   = 0;
				my $minutes = 0;
				my $seconds = 0;
				if ($time =~ /(\d+)h/)
				{
					$hours  = $1;
				}
				if ($time =~ /(\d+)m/)
				{
					$minutes = $1;
				}
				if ($time =~ /(\d+)s/)
				{
					$seconds = $1;
				}
				$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
					name1 => "time",    value1 => $time,
					name2 => "hours",   value2 => $hours,
					name3 => "minutes", value3 => $minutes,
					name4 => "seconds", value4 => $seconds,
				}, file => $THIS_FILE, line => __LINE__});
				my $say_hour   = $hours   == 1 ? "#!string!suffix_0010!#" : "#!string!suffix_0011!#";
				my $say_minute = $minutes == 1 ? "#!string!suffix_0012!#" : "#!string!suffix_0013!#";
				my $say_second = $seconds == 1 ? "#!string!suffix_0014!#" : "#!string!suffix_0015!#";
				my $say_time_remaining;
				if ($hours)
				{
					$say_time_remaining = AN::Common::get_string($conf, {key => "message_0293", variables => {
						hours		=>	$hours,
						say_hour	=>	$say_hour,
						minutes		=>	$minutes,
						say_minute	=>	$say_minute,
						seconds		=>	$minutes,
						say_second	=>	$say_minute,
					}});
				}
				elsif ($minutes)
				{
					$say_time_remaining = AN::Common::get_string($conf, {key => "message_0293", variables => {
						hours		=>	"0",
						say_hour	=>	$say_hour,
						minutes		=>	$minutes,
						say_minute	=>	$say_minute,
						seconds		=>	$minutes,
						say_second	=>	$say_minute,
					}});
				}
				else
				{
					$say_time_remaining = AN::Common::get_string($conf, {key => "message_0293", variables => {
						hours		=>	"0",
						say_hour	=>	$say_hour,
						minutes		=>	"0",
						say_minute	=>	$say_minute,
						seconds		=>	$minutes,
						say_second	=>	$say_minute,
					}});
				}
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "time",               value1 => $time,
					name2 => "say_time_remaining", value2 => $say_time_remaining,
				}, file => $THIS_FILE, line => __LINE__});
				my $say_progress = AN::Common::get_string($conf, {key => "message_0291", variables => {
					percent		=>	$percent,
					received	=>	$say_received,
					rate		=>	$say_rate,
				}});
				my $say_remaining = AN::Common::get_string($conf, {key => "message_0292", variables => {
					time_remaining	=>	$say_time_remaining,
				}});
				print AN::Common::template($conf, "media-library.html", "download_website_progress", {
					progress	=>	$say_progress,
					remaining	=>	$say_remaining,
				});
			}
		}
		else
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if (not $header_printed)
			{
				print AN::Common::template($conf, "common.html", "open-shell-call-output");
				$header_printed = 1;
			}
			
			if ($failed)
			{
				$line = AN::Common::get_string($conf, {key => "message_0354"}).$line;
			}
			
			print AN::Common::template($conf, "common.html", "shell-call-output", {
				line	=>	$line,
			});
		}
	}
	
	# If the 'script' bit was set, chmod the target file.
	if ($failed)
	{
		# Remove the file if it exists
		my $shell_call = $an->data->{path}{rm}." -f ".$an->data->{path}{shared_files}."/".$file;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$conf->{node}{$node}{port}, 
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	elsif ($an->data->{cgi}{script})
	{
		my $shell_call = $an->data->{path}{'chmod'}." 755 ".$an->data->{path}{shared_files}."/".$file;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$conf->{node}{$node}{port}, 
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	if ($header_printed)
	{
		print AN::Common::template($conf, "common.html", "close-shell-call-output");
	}
	print AN::Common::template($conf, "media-library.html", "download-website-footer");
	
	return (0);
}

# This prompts the user to confirm the download of a file from the web.
sub confirm_download_url
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_download_url" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $cluster = $conf->{cgi}{cluster};
	my $url     = $conf->{cgi}{url};
	my ($base, $file) = ($url =~ /^(.*)\/(.*?)$/);
	
	my $say_title = AN::Common::get_string($conf, {key => "title_0122", variables => {
		anvil	=>	$cluster,
	}});
	my $say_download = AN::Common::get_string($conf, {key => "message_0294", variables => {
		anvil	=>	$cluster,
	}});
	
	print AN::Common::template($conf, "media-library.html", "download-website-confirm", {
		file		=>	$file,
		title		=>	$say_title,
		base		=>	$base,
		download	=>	$say_download,
		confirm_url	=>	"$conf->{sys}{cgi_string}&confirm=true",
	});

	return (0);
}

# This saves a file to disk from a user's upload.
sub save_file_to_disk
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "save_file_to_disk" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my ($node) = AN::Cluster::read_files_on_shared($conf);
	print AN::Common::template($conf, "media-library.html", "save-to-disk-header");
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "cgi_fh::file", value1 => $conf->{cgi_fh}{file},
		name2 => "path::media",  value2 => $conf->{path}{media},
		name3 => "cgi::file",    value3 => $conf->{cgi}{file},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "path::media", value1 => $conf->{path}{media},
		name2 => "cgi::file",   value2 => $conf->{cgi}{file},
	}, file => $THIS_FILE, line => __LINE__});
	my $in_fh = $conf->{cgi_fh}{file};
	
	if (not $in_fh)
	{
		# User didn't specify a file.
		print AN::Common::template($conf, "media-library.html", "save-to-disk-no-file");
	}
	else
	{
		# TODO: Make sure characters like spaces and whatnot don't need to be escaped.
		my $out_file =  "$conf->{path}{media}/$conf->{cgi}{file}";
		$out_file    =~ s/\/\//\//g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "out_file", value1 => $out_file,
			name2 => "in_fh",    value2 => $in_fh,
		}, file => $THIS_FILE, line => __LINE__});
		
		open (my $file_handle, ">", $out_file) or die "$THIS_FILE ".__LINE__."; Failed to open for writing: [$out_file], error was: $!\n";
		binmode $file_handle;
		while(<$in_fh>)
		{
			print $file_handle $_;
		}
		close $file_handle;
		
		# Tell the user we're starting.
		print AN::Common::template($conf, "media-library.html", "save-to-disk-starting");
		
		my ($failed) = upload_to_shared($conf, $node, $out_file);
		unlink $out_file if -e $out_file;
		if ($failed)
		{
			# Something went wrong
			print AN::Common::template($conf, "media-library.html", "save-to-disk-failed");
		}
		else
		{
			# TODO: "Looks like"? Really? do a 'sum' of the files to confirm.
			print AN::Common::template($conf, "media-library.html", "save-to-disk-success");
		}
	}
	print AN::Common::template($conf, "media-library.html", "save-to-disk-footer");
	
	return (0);
}

# This images and uploads a DVD or CD disc
sub image_and_upload
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "image_and_upload" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Let the user know that this might take a bit.
	print AN::Common::template($conf, "common.html", "scanning-message", {
		anvil	=>	$conf->{cgi}{cluster},
	});
	
	my $dev  = $conf->{cgi}{dev};
	my $name = $conf->{cgi}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "dev",  value1 => $dev,
		name2 => "name", value2 => $name,
	}, file => $THIS_FILE, line => __LINE__});
	
	my ($node) = AN::Cluster::read_files_on_shared($conf);
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node",                   value1 => $node,
		name2 => "files::shared::${name}", value2 => $conf->{files}{shared}{$name},
	}, file => $THIS_FILE, line => __LINE__});
	if (not $name)
	{
		# Tell the user that no name was given.
		print AN::Common::template($conf, "media-library.html", "image-and-upload-no-name");
	}
	elsif (not $dev)
	{
		# Tell the user that no name was given.
		print AN::Common::template($conf, "media-library.html", "image-and-upload-no-device");
	}
	elsif (exists $conf->{files}{shared}{$name})
	{
		# Tell the user a file with that name already exists. The variables hash ref feeds 
		# 'message_0232'.
		print AN::Common::template($conf, "media-library.html", "image-and-upload-name-conflict", {}, {
			name	=>	$name,
		});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "name", value1 => $name,
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Now make sure the disc is still in the drive.
		check_local_dvd($conf);
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "drive::${dev}",          value1 => $conf->{drive}{$dev},
			name2 => "drive::${dev}::reload",  value2 => $conf->{drive}{$dev}{reload},
			name3 => "drive::${dev}::no_disc", value3 => $conf->{drive}{$dev}{no_disc},
		}, file => $THIS_FILE, line => __LINE__});
		if (not exists $conf->{drive}{$dev})
		{
			# The drive vanished.
			my $say_missing_drive = AN::Common::get_string($conf, {key => "message_0304", variables => {
				device	=>	$dev,
			}});
			my $say_try_again = AN::Common::template($conf, "common.html", "enabled_button_no_class", {
				button_link	=>	"$conf->{sys}{cgi_string}",
				button_text	=>	"#!string!button_0043!#",
			}, "", 1);
			print AN::Common::template($conf, "media-library.html", "image-and-upload-drive-gone", {
				missing_drive	=>	$say_missing_drive,
				try_again	=>	$say_try_again,
			});
		}
		elsif ($conf->{drive}{$dev}{reload})
		{
			# Need to reload to read the disc.
			my $say_drive_not_ready = AN::Common::get_string($conf, {key => "message_0305", variables => {
				device	=>	$dev,
			}});
			my $say_try_again = AN::Common::template($conf, "common.html", "enabled_button_no_class", {
				button_link	=>	"$conf->{sys}{cgi_string}",
				button_text	=>	"#!string!button_0043!#",
			}, "", 1);
			print AN::Common::template($conf, "media-library.html", "image-and-upload-reload-needed", {
				drive_not_ready	=>	$say_drive_not_ready,
				try_again	=>	$say_try_again,
			});
		}
		elsif ($conf->{drive}{$dev}{no_disc})
		{
			# No disc in the drive
			my $say_no_disc = AN::Common::get_string($conf, {key => "message_0307", variables => {
				device	=>	$dev,
			}});
			my $say_try_again = AN::Common::template($conf, "common.html", "enabled_button_no_class", {
				button_link	=>	"$conf->{sys}{cgi_string}",
				button_text	=>	"#!string!button_0043!#",
			}, "", 1);
			print AN::Common::template($conf, "media-library.html", "image-and-upload-no-disc", {
				no_disk		=>	$say_no_disc,
				try_again	=>	$say_try_again,
			});
		}
		else
		{
			# Ok, we're good to go.
			# Finally...
			#my $out_file = $conf->{path}{media}.$name;
			my $out_file = "'$conf->{path}{media}/$name'";
			my $in_dev   = $dev;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "dev",       value1 => $dev,
				name2 => "directory", value2 => $conf->{path}{media},
				name3 => "name",      value3 => $name,
			}, file => $THIS_FILE, line => __LINE__});
			my $message  = AN::Common::get_string($conf, {key => "explain_0059", variables => {
				device		=>	$dev,
				name		=>	$name,
				directory	=>	$conf->{path}{media},
			}});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "message", value1 => $message,
			}, file => $THIS_FILE, line => __LINE__});
			print AN::Common::template($conf, "media-library.html", "image-and-upload-proceed-header", {
				message		=>	$message,
			});
			
			my $shell_call = "$conf->{path}{do_dd} if=$in_dev of=$out_file bs=$conf->{sys}{dd_block_size}";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "Calling", value1 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			
			my $header_printed = 0;
			open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
			my $error;
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				
				if (not $header_printed)
				{
					print AN::Common::template($conf, "common.html", "open-shell-call-output");
					$header_printed = 1;
				}
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "output", value1 => $line,
				}, file => $THIS_FILE, line => __LINE__});
				if ($line =~ /Is a directory/i)
				{
					$error .= AN::Common::get_string($conf, {key => "message_0333"});
				}
				print AN::Common::template($conf, "common.html", "shell-call-output", {
					line	=>	$line,
				});
			}
			$file_handle->close;
			if ($header_printed)
			{
				print AN::Common::template($conf, "common.html", "close-shell-call-output");
			}
			
			if ($error)
			{
				# Image failed, no sense trying to upload.
				print AN::Common::template($conf, "media-library.html", "image-and-upload-proceed-failed", {}, {
					error	=>	$error,
				});
			}
			else
			{
				# Starting to upload now.
				# The variables hash feeds 'explain_0052'.
				print AN::Common::template($conf, "media-library.html", "image-and-upload-proceed-uploading", {}, {
					name	=>	$name,
					anvil	=>	$conf->{cgi}{cluster},
				});

				my ($failed) = upload_to_shared($conf, $node, $out_file);
				unlink $out_file if -e $out_file;
				if ($failed)
				{
					# Upload appears to have failed.
					print AN::Common::template($conf, "media-library.html", "image-and-upload-proceed-upload-failed");
				}
				else
				{
					# Looks like? Really? do a 'sum' of the files to confirm.
					print AN::Common::template($conf, "media-library.html", "image-and-upload-proceed-upload-success");
				}
			}
			print AN::Common::template($conf, "media-library.html", "image-and-upload-proceed-footer");
		}
	}
	
	return (0);
}

# This takes a path to a file on the dashboard and uploads it to the cluster's
# /shared/files/ folder.
sub upload_to_shared
{
	my ($conf, $node, $source) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "upload_to_shared" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "source", value1 => $source, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $cluster     = $an->data->{cgi}{cluster};
	my $password    = $an->data->{sys}{root_password};
	my $switches    = $an->data->{args}{rsync};
	my $file        = ($source =~ /^.*\/(.*)$/)[0];
	my $destination = "root\@${node}:".$an->data->{path}{shared_files}."/";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "cluster",     value1 => $cluster,
		name2 => "switches",    value2 => $switches,
		name3 => "destination", value3 => $destination,
		name4 => "file",        value4 => $file,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	my $failed = $an->Storage->rsync({
		source		=>	$source,
		target		=>	$node,
		password	=>	$password,
		destination	=>	$destination,
		switches	=>	$switches,
	});
	
	# If the 'script' bit was set, chmod the target file.
	if ($an->data->{cgi}{script})
	{
		my $shell_call = $an->data->{path}{'chmod'}." 755 ".$an->data->{path}{shared_files}."/".$file;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$conf->{node}{$node}{port}, 
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "failed", value1 => $failed,
	}, file => $THIS_FILE, line => __LINE__});
	return ($failed);
}

# This asks the user to confirm the image and upload task. It also gives a
# chance for the user to name the image before upload.
sub confirm_image_and_upload
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_image_and_upload" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $dev  = $conf->{cgi}{dev};
	my $name = $conf->{cgi}{name};
	
	my $say_title = AN::Common::get_string($conf, {key => "title_0132", variables => {
		anvil	=>	$conf->{cgi}{cluster},
	}});
	my $input_name = AN::Common::template($conf, "common.html", "form-input-no-class-defined-width", {
		type	=>	"text",
		name	=>	"name",
		id	=>	$name,
		value	=>	$name,
		width	=>	"250px",
	}, "", 1);
	my $hidden_inputs = AN::Common::template($conf, "common.html", "form-input-no-class", {
		type	=>	"hidden",
		name	=>	"dev",
		id	=>	"dev",
		value	=>	"$dev",
	}, "", 1);
	$hidden_inputs .= "\n";
	$hidden_inputs .= AN::Common::template($conf, "common.html", "form-input-no-class", {
		type	=>	"hidden",
		name	=>	"cluster",
		id	=>	"cluster",
		value	=>	"$conf->{cgi}{cluster}",
	}, "", 1);
	$hidden_inputs .= "\n";
	$hidden_inputs .= AN::Common::template($conf, "common.html", "form-input-no-class", {
		type	=>	"hidden",
		name	=>	"task",
		id	=>	"task",
		value	=>	"image_and_upload",
	}, "", 1);
	$hidden_inputs .= "\n";
	$hidden_inputs .= AN::Common::template($conf, "common.html", "form-input-no-class", {
		type	=>	"hidden",
		name	=>	"confirm",
		id	=>	"confirm",
		value	=>	"true",
	}, "", 1);
	my $submit_button = AN::Common::template($conf, "common.html", "form-input", {
		type	=>	"submit",
		name	=>	"null",
		id	=>	"null",
		value	=>	"#!string!button_0004!#",
		class	=>	"bold_button",
	}, "", 1);
	$submit_button =~ s/^\s+//; $submit_button =~ s/\s+$//s;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "submit_button", value1 => $submit_button,
	}, file => $THIS_FILE, line => __LINE__});

	# Display the confirmation window now.
	print AN::Common::template($conf, "media-library.html", "image-and-upload-confirm", {
		title		=>	$say_title,
		input_name	=>	$input_name,
		hidden_inputs	=>	$hidden_inputs,
		submit_button	=>	$submit_button,
	});
	
	return (0);
}

# This asks the user to confirm that s/he wants to delete the image.
sub confirm_delete_file
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_delete_file" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $cluster = $conf->{cgi}{cluster};
	my $name    = $conf->{cgi}{name};
	
	my $say_title = AN::Common::get_string($conf, {key => "title_0134", variables => {
		name	=>	$name,
		anvil	=>	$conf->{cgi}{cluster},
	}});
	my $say_delete = AN::Common::get_string($conf, {key => "message_0316", variables => {
		name	=>	$name,
		anvil	=>	$conf->{cgi}{cluster},
	}});
	my $confirm_button = AN::Common::template($conf, "common.html", "enabled-button", {
		button_class	=>	"bold_button",
		button_link	=>	"$conf->{sys}{cgi_string}&confirm=true",
		button_text	=>	"#!string!button_0004!#",
		id		=>	"delete_file_confirmed",
	}, "", 1);

	# Display the confirmation window now.
	print AN::Common::template($conf, "media-library.html", "file-delete-confirm", {
		title		=>	$say_title,
		say_delete	=>	$say_delete,
		confirm_button	=>	$confirm_button,
	});
	
	return (0);
}

# This deletes a file from the cluster.
sub delete_file
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "delete_file" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### TODO: Make sure to unmount from (and rewrite definition files of)
	###       VMs currently using the file being deleted.
	my $cluster = $conf->{cgi}{cluster};
	my $name    = $conf->{cgi}{name};
	my ($node) = AN::Cluster::read_files_on_shared($conf);
	if (exists $conf->{files}{shared}{$name})
	{
		# Do the delete.
		my $say_title = AN::Common::get_string($conf, {key => "title_0135", variables => {
			name	=>	$name,
		}});
		print AN::Common::template($conf, "media-library.html", "file-delete-header", {
			title		=>	$say_title,
		});
		
		my $shell_call = "rm -f \"/shared/files/$name\"";
		my $password   = $conf->{sys}{root_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$conf->{node}{$node}{port}, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			print AN::Common::template($conf, "common.html", "shell-call-output", {
				line	=>	$line,
			});
		}
		print AN::Common::template($conf, "media-library.html", "file-delete-footer");
	}
	else
	{
		# Failed...
		my $say_title = AN::Common::get_string($conf, {key => "title_0136", variables => {
			name	=>	$name,
			anvil	=>	$cluster,
		}});
		my $say_message = AN::Common::get_string($conf, {key => "message_0318", variables => {
			name	=>	$name,
			anvil	=>	$cluster,
		}});
		print AN::Common::template($conf, "media-library.html", "file-delete-failed", {
			title	=>	$say_title,
			message	=>	$say_message,
		});
	}
	
	return (0);
}

# This tries to see of there is a DVD or CD in the local drive (if there is a
# local drive at all).
sub check_local_dvd
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_local_dvd" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $dev        = "";
	my $shell_call = "$conf->{path}{check_dvd} $conf->{args}{check_dvd}";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "Calling", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		if ($line =~ /CD location\s+:\s+(.*)/i)
		{
			$dev = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "dev", value1 => $dev,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /Volume\s+:\s+(.*)/i)
		{
			my $volume = $1;
			$conf->{drive}{$dev}{volume} = $volume;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "drive::${dev}::volume", value1 => $conf->{drive}{$dev}{volume},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /Volume Set\s+:\s+(.*)/i)
		{
			my $volume_set = $1;
			$conf->{drive}{$dev}{volume_set} = $volume_set;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "drive::${dev}::volume_set", value1 => $conf->{drive}{$dev}{volume_set},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /No medium found/i)
		{
			$conf->{drive}{$dev}{no_disc} = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "drive::${dev}::no_disc", value1 => $conf->{drive}{$dev}{no_disc},
			}, file => $THIS_FILE, line => __LINE__});
			last;
		}
		elsif ($line =~ /unknown filesystem/i)
		{
			$conf->{drive}{$dev}{reload} = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "drive::${dev}::reload", value1 => $conf->{drive}{$dev}{reload},
			}, file => $THIS_FILE, line => __LINE__});
			last;
		}
		else
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	$file_handle->close;

	return(0);
}

# This prints a small header with the current status of any background running jobs
sub check_status
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_status" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "path::status", value1 => $conf->{path}{status},
	}, file => $THIS_FILE, line => __LINE__});
	if (not -e $conf->{path}{status})
	{
		# Directory doesn't exist...
		my $say_message = AN::Common::get_string($conf, {key => "message_0319", variables => {
			directory	=>	$conf->{path}{status},
		}});
		print AN::Common::template($conf, "media-library.html", "check-status-config-error", {
			message	=>	$say_message,
		});
	}
	elsif (not -r $conf->{path}{status})
	{
		# Can't read the directory
		my $user = getpwuid($<);
		my $say_message = AN::Common::get_string($conf, {key => "message_0320", variables => {
			directory	=>	$conf->{path}{status},
			user		=>	$user,
		}});
		print AN::Common::template($conf, "media-library.html", "check-status-config-error", {
			message	=>	$say_message,
		});
	}
	
	return (0);
}

# This tries to log into each node in the Anvil!. The first one it connects to which has /shared/files 
# mounted is the one it will use to up upload the ISO and generate the list of available media. It also 
# compiles a list of which  VMs are on each node.
sub read_shared
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "read_shared" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Look for info on running jobs (not implemented yet)
	#check_status($conf);
	
	my $connected = 0;
	
	# What node should I use?
	my $cluster = $conf->{cgi}{cluster};
	my $node    = $an->data->{sys}{use_node};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "cluster", value1 => $cluster,
		name2 => "node",    value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	
	print AN::Common::template($conf, "media-library.html", "read-shared-header");
	if ($node)
	{
		# Get the shared partition info and the list of files.
		my ($files, $partition) = $an->Get->shared_files({
			password	=>	$an->data->{sys}{root_password},
			port		=>	$conf->{node}{$node}{port},
			target		=>	$node,
		});
		
		my $block_size       = $partition->{block_size};
		my $say_total_space  = $an->Readable->bytes_to_hr({'bytes' => ($partition->{total_space} * $block_size)});
		my $say_used_space   = $an->Readable->bytes_to_hr({'bytes' => ($partition->{used_space} * $block_size)});
		my $say_free_space   = $an->Readable->bytes_to_hr({'bytes' => ($partition->{free_space} * $block_size)});
		my $say_used_percent = $partition->{used_percent}."%";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
			name1 => "block_size",       value1 => $block_size,
			name2 => "say_total_space",  value2 => $say_total_space,
			name3 => "say_used_space",   value3 => $say_used_space,
			name4 => "say_free_space",   value4 => $say_free_space,
			name5 => "say_used_percent", value5 => $say_used_percent,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Print the general header and the files header
		my $say_title = AN::Common::get_string($conf, {key => "title_0138", variables => {
			anvil	=>	$cluster,
		}});
		print AN::Common::template($conf, "media-library.html", "read-shared-list-header", {
			title		=>	$say_title,
			total_space	=>	$say_total_space,
			used_space	=>	$say_used_space,
			free_space	=>	$say_free_space,
		});
		
		# Show existing files.
		foreach my $file (sort {$a cmp $b} keys %{$files})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0012", message_variables => {
				name1  => "${file}::type",       value1  => $files->{$file}{type},
				name2  => "${file}::mode",       value2  => $files->{$file}{mode},
				name3  => "${file}::owner",      value3  => $files->{$file}{user},
				name4  => "${file}::group",      value4  => $files->{$file}{group},
				name5  => "${file}::size",       value5  => $files->{$file}{size},
				name6  => "${file}::modified",   value6  => $files->{$file}{month},
				name7  => "${file}::day",        value7  => $files->{$file}{day},
				name8  => "${file}::time",       value8  => $files->{$file}{'time'},
				name9  => "${file}::year",       value9  => $files->{$file}{year},
				name10 => "${file}::target",     value10 => $files->{$file}{target},
				name11 => "${file}::optical",    value11 => $files->{$file}{optical},
				name12 => "${file}::executable", value12 => $files->{$file}{executable},
			}, file => $THIS_FILE, line => __LINE__});
			
			next if $files->{$file}{type} ne "-";
			my $say_size = $an->Readable->bytes_to_hr({'bytes' => $files->{$file}{size}});

			my $delete_button = AN::Common::template($conf, "common.html", "enabled-button", {
				button_link	=>	"?cluster=$cluster&task=delete&name=$file",
				button_text	=>	"<img src=\"#!conf!url::skins!#/#!conf!sys::skin!#/images/icon_clear-fields_16x16.png\" alt=\"#!string!button_0030!#\" border=\"0\" />",
				button_class	=>	"highlight_bad",
				id		=>	"delete_$file",
			}, "", 1);
			
			my $script_button = AN::Common::template($conf, "common.html", "enabled-button", {
				button_link	=>	"?cluster=$cluster&task=make_executable&name=$file",
				button_text	=>	"<img src=\"#!conf!url::skins!#/#!conf!sys::skin!#/images/icon_plain-text_16x16.png\" alt=\"#!string!button_0067!#\" border=\"0\" />",
				button_class	=>	"highlight_bad",
				id		=>	"executable_$file",
			}, "", 1);
			if ($files->{$file}{executable})
			{
				$script_button = AN::Common::template($conf, "common.html", "enabled-button", {
					button_link	=>	"?cluster=$cluster&task=make_plain_text&name=$file",
					button_text	=>	"<img src=\"#!conf!url::skins!#/#!conf!sys::skin!#/images/icon_executable_16x16.png\" alt=\"#!string!button_0068!#\" border=\"0\" />",
					button_class	=>	"highlight_bad",
					id		=>	"executable_$file",
				}, "", 1);
			}
			
			# Add an optical disk icon if it's an ISO
			my $iso_icon = "&nbsp;";
			if ($files->{$file}{optical})
			{
				$iso_icon      = "<img src=\"#!conf!url::skins!#/#!conf!sys::skin!#/images/icon_plastic-circle_16x16.png\" alt=\"#!string!row_0215!#\" border=\"0\" />";
				$script_button = "&nbsp;";
			}
			
			print AN::Common::template($conf, "media-library.html", "read-shared-file-entry", {
				size			=>	$say_size,
				file			=>	$file,
				delete_button		=>	$delete_button,
				executable_button	=>	$script_button,
				iso_icon		=>	$iso_icon,
			});
		}
		
		# Read from the DVD drive(s), if found.
		print AN::Common::template($conf, "media-library.html", "read-shared-optical-drive-header");

		check_local_dvd($conf);
		foreach my $dev (sort {$a cmp $b} keys %{$conf->{drive}})
		{
			my $cluster   = $conf->{cgi}{cluster};
			my $disc_name = "";
			my $upload    = "--";
			if ($conf->{drive}{$dev}{reload})
			{
				# Drive wasn't ready, rescan needed.
				$disc_name = "#!string!message_0322!#";
			}
			elsif ($conf->{drive}{$dev}{no_disc})
			{
				# No disc found
				$disc_name = "#!string!message_0323!#";
			}
			elsif ($conf->{drive}{$dev}{volume})
			{
				$disc_name = "<span class=\"fixed_width\">$conf->{drive}{$dev}{volume}</span>";
				$upload    = AN::Common::template($conf, "common.html", "enabled-button", {
					button_class	=>	"bold_button",
					button_link	=>	"?cluster=$cluster&task=image_and_upload&dev=$dev&name=$conf->{drive}{$dev}{volume}.iso",
					button_text	=>	"#!string!button_0042!#",
					id		=>	"image_and_upload_$dev",
				}, "", 1);
			}
			elsif ($conf->{drive}{$dev}{volume_set})
			{
				$disc_name = "<span class=\"fixed_width\">$conf->{drive}{$dev}{volume_set}</span>";
				$upload    = AN::Common::template($conf, "common.html", "enabled-button", {
					button_class	=>	"bold_button",
					button_link	=>	"?cluster=$cluster&task=image_and_upload&dev=$dev&name=$conf->{drive}{$dev}{volume_set}.iso",
					button_text	=>	"#!string!button_0042!#",
					id		=>	"image_and_upload_$dev",
				}, "", 1);
			}
			else
			{
				# Some other problem reading the disc.
				$disc_name = AN::Common::get_string($conf, {key => "message_0324", variables => {
					device	=>	$dev,
				}});
			}
			print AN::Common::template($conf, "media-library.html", "read-shared-optical-drive-entry", {
				device		=>	$dev,
				disc_name	=>	$disc_name,
				upload		=>	$upload,
			});
		}
		print AN::Common::template($conf, "media-library.html", "read-shared-footer");

		# Show the option to download an ISO directly from a URL.
		my $hidden_inputs = AN::Common::template($conf, "common.html", "form-input-no-class", {
			type	=>	"hidden",
			name	=>	"cluster",
			id	=>	"cluster",
			value	=>	"$conf->{cgi}{cluster}",
		});
		$hidden_inputs .= "\n";
		$hidden_inputs .= AN::Common::template($conf, "common.html", "form-input-no-class", {
			type	=>	"hidden",
			name	=>	"task",
			id	=>	"task",
			value	=>	"download_url",
		});
		my $url_input = AN::Common::template($conf, "common.html", "form-input-no-class-defined-width", {
			type	=>	"text",
			name	=>	"url",
			id	=>	"url",
			value	=>	"",
			width	=>	"250px",
		});
		my $script_input = AN::Common::template($conf, "common.html", "form-input-checkbox", {
			name	=>	"script",
			id	=>	"script",
			value	=>	"true",
			checked	=>	"",
		});
		my $download_button = AN::Common::template($conf, "common.html", "form-input", {
			type	=>	"submit",
			name	=>	"null",
			id	=>	"null",
			value	=>	"#!string!button_0041!#",
			class	=>	"bold_button",
		});
		print AN::Common::template($conf, "media-library.html", "read-shared-direct-download", {
			hidden_inputs	=>	$hidden_inputs,
			url_input	=>	$url_input,
			script_input	=>	$script_input,
			download_button	=>	$download_button,
		});

		# Show the option to upload from the user's local machine.
		$hidden_inputs = "";
		$hidden_inputs = AN::Common::template($conf, "common.html", "form-input-no-class", {
			type	=>	"hidden",
			name	=>	"cluster",
			id	=>	"cluster",
			value	=>	"$conf->{cgi}{cluster}",
		});
		$hidden_inputs .= "\n";
		$hidden_inputs .= AN::Common::template($conf, "common.html", "form-input-no-class", {
			type	=>	"hidden",
			name	=>	"task",
			id	=>	"task",
			value	=>	"upload_file",
		});
		my $file_input = AN::Common::template($conf, "common.html", "form-input-no-class", {
			type	=>	"file",
			name	=>	"file",
			id	=>	"file",
			value	=>	"",
		});
		my $upload_button = AN::Common::template($conf, "common.html", "form-input", {
			type	=>	"submit",
			name	=>	"null",
			id	=>	"null",
			value	=>	"#!string!button_0042!#",
			class	=>	"bold_button",
		});
		print AN::Common::template($conf, "media-library.html", "read-shared-upload", {
			hidden_inputs	=>	$hidden_inputs,
			file_input	=>	$file_input,
			script_input	=>	$script_input,
			upload_button	=>	$upload_button,
		});
	}
	else
	{
		# Can't access either node.
		# The variables hash feeds 'message_0328'.
		print AN::Common::template($conf, "media-library.html", "read-shared-no-access", {}, {
			anvil	=>	$cluster,
		});
	}

	return($connected);
}

1;
