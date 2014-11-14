package AN::MediaLibrary;

# AN!MediaLibrary
# 
# This allows a mechanism for taking a CD or DVD, turning it into an ISO and
# pushing it to a cluster's /shared/files/ directory. It also allows for 
# connecting and disconnecting these ISOs to and from VMs.
# 

use strict;
use warnings;

use strict;
use warnings;
use CGI;
use Encode;
use IO::Handle;
use CGI::Carp "fatalsToBrowser";

# Setup for UTF-8 mode.
binmode STDOUT, ":utf8:";
$ENV{'PERL_UNICODE'} = 1;
my $THIS_FILE = "an-mc.lib";


# Do whatever the user has asked.
sub process_task
{
	my ($conf) = @_;
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Task: [$conf->{cgi}{task}]\n");
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
	
	return (0);
}

# This downloads a given URL directly to the cluster using 'wget'.
sub download_url
{
	my ($conf) = @_;
	
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

	my $header_printed  = 0;
	my $progress_points = 5;
	my $next_percent    = $progress_points;
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{'system'}{root_password},
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	"wget -c --progress=dot -e dotbytes=10M $url -O /shared/files/$file",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		### TODO: This doesn't work anymore because the 'remote_call()'
		### function returns all output in one go. Add a section to
		### remote_call that does this for wget calls.
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/“/"/g;
		$line =~ s/”/"/g;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /^(\d+)K .*? (\d+)% (.*?)(\w) (.*?)$/)
		{
			my $received = $1;
			my $percent  = $2;
			my $rate     = $3;
			my $rate_suf = $4;
			my $time     = $5;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; percent: [$percent], next percent: [$next_percent].\n");
			if ($percent eq "100")
			{
				print AN::Common::template($conf, "media-library.html", "download-website-complete");
			}
			elsif ($percent >= $next_percent)
			{
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; percent: [$percent], next percent: [$next_percent], received: [$received], rate: [$rate], time: [$time].\n");
				# This prevents multiple prints when the file
				# is partially downloaded.
				while ($percent >= $next_percent)
				{
					$next_percent += $progress_points;
				}
				$received        *= 1024;
				my $say_received =  AN::Cluster::bytes_to_hr($conf, $received);
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; received: [$received] -> [$say_received]\n");
				if (uc($rate_suf) eq "M")
				{
					$rate            =  int(($rate * (1024 * 1024)));
				}
				elsif (uc($rate_suf) eq "K")
				{
					$rate            =  int(($rate * 1024));
				}
				my $say_rate     =  AN::Cluster::bytes_to_hr($conf, $rate);
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rate: [$rate] -> [$say_rate]\n");
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
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; time: [$time] -> h[$hours], m[$minutes], s[$seconds]\n");
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
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; time: [$time] -> [$say_time_remaining]\n");
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
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if (not $header_printed)
			{
				print AN::Common::template($conf, "common.html", "open-shell-call-output");
				$header_printed = 1;
			}
			print AN::Common::template($conf, "common.html", "shell-call-output", {
				line	=>	$line,
			});
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
		confirm_url	=>	"$conf->{'system'}{cgi_string}&confirm=true",
	});

	return (0);
}

# This saves a file to disk from a user's upload.
sub save_file_to_disk
{
	my ($conf) = @_;
	
	my ($node) = AN::Cluster::read_files_on_shared($conf);
	print AN::Common::template($conf, "media-library.html", "save-to-disk-header");
	
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi_fh::file: [$conf->{cgi_fh}{file}], path::media: [$conf->{path}{media}], cgi::file: [$conf->{cgi}{file}].\n");
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; path::media: [$conf->{path}{media}], cgi::file: [$conf->{cgi}{file}].\n");
	my $in_fh = $conf->{cgi_fh}{file};
	
	if (not $in_fh)
	{
		# User didn't specify a file.
		print AN::Common::template($conf, "media-library.html", "save-to-disk-no-file");
	}
	else
	{
		# TODO: Make sure characters like spaces and whatnot don't need
		#       to be escaped.
		my $out_file =  "$conf->{path}{media}/$conf->{cgi}{file}";
		$out_file    =~ s/\/\//\//g;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Writing out_file: [$out_file] with cgi fh: [$in_fh].\n");
		
		open (my $fh, ">", $out_file) or die "$THIS_FILE ".__LINE__."; Failed to open for writing: [$out_file], error was: $!\n";
		binmode $fh;
		while(<$in_fh>)
		{
			print $fh $_;
		}
		close $fh;
		
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
	
	# Let the user know that this might take a bit.
	print AN::Common::template($conf, "common.html", "scanning-message", {
		anvil	=>	$conf->{cgi}{cluster},
	});
	
	my $dev  = $conf->{cgi}{dev};
	my $name = $conf->{cgi}{name};
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; dev: [$dev], name: [$name]\n");
	
	my ($node) = AN::Cluster::read_files_on_shared($conf);
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], files::shared::${name}: [$conf->{files}{shared}{$name}]\n");
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
		# Tell the user a file with that name already exists.
		# the variables hash ref feeds 'message_0232'.
		print AN::Common::template($conf, "media-library.html", "image-and-upload-name-conflict", {}, {
			name	=>	$name,
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; name: [$name]\n");
	}
	else
	{
		# Now make sure the disc is still in the drive.
		check_local_dvd($conf);
		
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; drive::${dev}: [$conf->{drive}{$dev}], drive::${dev}::reload: [$conf->{drive}{$dev}{reload}], drive::${dev}::no_disc: [$conf->{drive}{$dev}{no_disc}]\n");
		if (not exists $conf->{drive}{$dev})
		{
			# The drive vanished.
			my $say_missing_drive = AN::Common::get_string($conf, {key => "message_0304", variables => {
				device	=>	$dev,
			}});
			my $say_try_again = AN::Common::template($conf, "common.html", "enabled_button_no_class", {
				button_link	=>	"$conf->{'system'}{cgi_string}",
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
				button_link	=>	"$conf->{'system'}{cgi_string}",
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
				button_link	=>	"$conf->{'system'}{cgi_string}",
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; dev: [$dev], directory: [$conf->{path}{media}], name: [$name]\n");
			my $message  = AN::Common::get_string($conf, {key => "explain_0059", variables => {
				device		=>	$dev,
				name		=>	$name,
				directory	=>	$conf->{path}{media},
			}});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; message: [$message]\n");
			print AN::Common::template($conf, "media-library.html", "image-and-upload-proceed-header", {
				message		=>	$message,
			});
			
			my $sc = "$conf->{path}{do_dd} if=$in_dev of=$out_file bs=$conf->{'system'}{dd_block_size}";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$sc]\n");
			
			my $header_printed = 0;
			my $fh = IO::Handle->new();
			open ($fh, "$sc 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$sc], error was: $!\n";
			my $error;
			while(<$fh>)
			{
				chomp;
				my $line = $_;
				
				if (not $header_printed)
				{
					print AN::Common::template($conf, "common.html", "open-shell-call-output");
					$header_printed = 1;
				}
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; output: [$line]\n");
				if ($line =~ /Is a directory/i)
				{
					$error .= AN::Common::get_string($conf, {key => "message_0333"});
				}
				print AN::Common::template($conf, "common.html", "shell-call-output", {
					line	=>	$line,
				});
			}
			$fh->close;
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
	my ($conf, $node, $source_file) = @_;
	
	# Some prep work.
	my $failed = 0;
	($failed) = AN::Common::test_ssh_fingerprint($conf, $node);
	
	if ($failed)
	{
		my $message = AN::Common::get_string($conf, {key => "message_0359", variables => {
			node	=>	$node,
			file	=>	$source_file,
		}});
		print AN::Common::template($conf, "common.html", "generic-error", {
			message	=>	$message,
		});
	}
	else
	{
		my $sc = "$conf->{path}{rsync} $conf->{args}{rsync} $source_file root\@$node:$conf->{path}{shared}";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sc: [$sc].\n");
		# This is a dumb way to check, try a test upload and see if it fails.
		if (-e $conf->{path}{expect})
		{
			#print "Creating 'expect' rsync wrapper.<br />";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Creating rsync wrapper.\n");
			AN::Common::create_rsync_wrapper($conf, $node);
			$sc = "~/rsync.$node $conf->{args}{rsync} $source_file root\@$node:$conf->{path}{shared}";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sc: [$sc].\n");
		}
		else
		{
			print AN::Common::template($conf, "media-library.html", "image-and-upload-expect-not-found");
		}
		
		my $header_printed = 0;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$sc]\n");
		my $fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$sc], error was: $!\n";
		my $no_key = 0;
		while(<$fh>)
		{
			chomp;
			my $line = $_;
			if ($line =~ /Permission denied/i)
			{
				$failed = 1;
			}
			if (not $header_printed)
			{
				print AN::Common::template($conf, "common.html", "open-shell-call-output");
				$header_printed = 1;
			}
			print AN::Common::template($conf, "common.html", "shell-call-output", {
				line	=>	$line,
			});
		}
		$fh->close;
		
		if ($header_printed)
		{
			print AN::Common::template($conf, "common.html", "close-shell-call-output");
		}
	}
	
	return ($failed);
}

# This asks the user to confirm the image and upload task. It also gives a
# chance for the user to name the image before upload.
sub confirm_image_and_upload
{
	my ($conf) = @_;
	
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; submit_button: [$submit_button]\n");

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
		button_link	=>	"$conf->{'system'}{cgi_string}&confirm=true",
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
		
		my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{'system'}{root_password},
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	"rm -f \"/shared/files/$name\"",
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
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
	
	my $dev = "";
	my $sc  = "$conf->{path}{check_dvd} $conf->{args}{check_dvd}";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$sc]\n");
	my $fh  = IO::Handle->new();
	open ($fh, "$sc 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$sc], error was: $!\n";
	while(<$fh>)
	{
		chomp;
		my $line = $_;
		if ($line =~ /CD location\s+:\s+(.*)/i)
		{
			$dev = $1;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cd-info:device:$dev\n");
		}
		elsif ($line =~ /Volume\s+:\s+(.*)/i)
		{
			my $volume = $1;
			$conf->{drive}{$dev}{volume} = $volume;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cd-info:volume:$volume\n");
		}
		elsif ($line =~ /Volume Set\s+:\s+(.*)/i)
		{
			my $volume_set = $1;
			$conf->{drive}{$dev}{volume_set} = $volume_set;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cd-info:volume set:$volume_set\n");
		}
		elsif ($line =~ /No medium found/i)
		{
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cd-info:no-disc:true\n");
			$conf->{drive}{$dev}{no_disc} = 1;
			last;
		}
		elsif ($line =~ /unknown filesystem/i)
		{
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cd-info:reload needed:true\n");
			$conf->{drive}{$dev}{reload} = 1;
			last;
		}
		else
		{
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cd-info:$line\n");
		}
	}
	$fh->close;

	return(0);
}

# This prints a small header with the current status of any background running
# jobs
sub check_status
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; check_status()\n");
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; path::status: [$conf->{path}{status}]\n");
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

# This tries to log into each node in the Anvil!. The first one it connects to
# which has /shared/files mounted is the one it will use to up upload the ISO
# and generate the list of available media. It also compiles a list of which 
# VMs are on each node.
sub read_shared
{
	my ($conf) = @_;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; In read_shared().\n");
	
	check_status($conf);
	
	# Let the user know that this might take a bit.
	print AN::Common::template($conf, "common.html", "scanning-message", {
		anvil	=>	$conf->{cgi}{cluster},
	});
	
	my $cluster   = $conf->{cgi}{cluster};
	my $connected = 0;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cluster: [$cluster], connecter: [$connected]\n");
	
	# This returns the name of the node used to read /shared/files/. If no
	# node was available, it returns an empty string.
	my ($node) = AN::Cluster::read_files_on_shared($conf);
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node]\n");
	
	print AN::Common::template($conf, "media-library.html", "read-shared-header");
	if ($node)
	{
		my $block_size       = $conf->{partition}{shared}{block_size};
		my $total_space      = ($conf->{partition}{shared}{total_space} * $block_size);
		my $say_total_space  = AN::Cluster::bytes_to_hr($conf, $total_space);
		my $used_space       = ($conf->{partition}{shared}{used_space} * $block_size);
		my $say_used_space   = AN::Cluster::bytes_to_hr($conf, $used_space);
		my $free_space       = ($conf->{partition}{shared}{free_space} * $block_size);
		my $say_free_space   = AN::Cluster::bytes_to_hr($conf, $free_space);
		my $say_used_percent = $conf->{partition}{shared}{used_percent}."%";
		
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
		foreach my $file (sort {$a cmp $b} keys %{$conf->{files}{shared}})
		{
			next if $conf->{files}{shared}{$file}{type} ne "-";
			my $say_size = AN::Cluster::bytes_to_hr($conf, $conf->{files}{shared}{$file}{size});
			my $delete_button = AN::Common::template($conf, "common.html", "enabled-button", {
				button_link	=>	"?cluster=$cluster&task=delete&name=$file",
				button_text	=>	"#!string!button_0030!#",
				button_class	=>	"highlight_bad",
				id		=>	"delete_$file",
			}, "", 1);
			print AN::Common::template($conf, "media-library.html", "read-shared-file-entry", {
				size		=>	$say_size,
				file		=>	$file,
				delete_button	=>	$delete_button,
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
