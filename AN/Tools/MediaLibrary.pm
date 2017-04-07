package AN::Tools::MediaLibrary;
# 
# This module will contain methods used specifically for MediaLibrary component of the striker related tasks.
# 

use strict;
use warnings;
use Data::Dumper;

our $VERSION  = "0.1.001";
my $THIS_FILE = "MediaLibrary.pm";

### Methods;
### NOTE: All of these private methods are ports of functions from the old Striker.pm. None will be developed
###       further and all will be phased out over time. Do not use any of these in new dev work.
# _abort_download
# _check_local_dvd
# _confirm_abort_download
# _confirm_delete_file
# _confirm_download_url
# _confirm_image_and_upload
# _delete_file
# _download_url
# _image_and_upload
# _monitor_downloads
# _process_task
# _read_shared
# _save_file_to_disk
# _toggle_executable
# _upload_to_shared

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


#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

# This aborts (and deletes, if requested) an in-progress download.
sub _abort_download
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_abort_download" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $subtask    = $an->data->{cgi}{subtask} eq "delete" ? "delete" : "abort";
	my $job_uuid   = $an->data->{cgi}{job_uuid};
	my $url        = $an->data->{cgi}{url};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "subtask",    value2 => $subtask,
		name3 => "job_uuid",   value3 => $job_uuid,
		name4 => "url",        value4 => $url,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Show the progress. 
	my $found_node   = "";
	my $do_abort     = 0;
	my $aborted      = 0;
	my $already_done = 0;
	foreach my $node_key ("node1", "node2")
	{
		next if $found_node;
		
		my $node_name = $an->data->{sys}{anvil}{$node_key}{name};
		my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
		my $port      = $an->data->{sys}{anvil}{$node_key}{use_port}; 
		my $password  = $an->data->{sys}{anvil}{$node_key}{password};
		my $online    = $an->data->{sys}{anvil}{$node_key}{online};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "node_name", value1 => $node_name, 
			name2 => "target",    value2 => $target, 
			name3 => "port",      value3 => $port, 
			name4 => "online",    value4 => $online, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password, 
		}, file => $THIS_FILE, line => __LINE__});
		my $file_displayed = 0;
		
		# Is the node accessible?
		next if not $online;
		
		# Still alive? Good. Is this the node hosting the download?
		my $opened_list = 0;
		my $shell_call  = $an->data->{path}{'anvil-download-file'}." --status";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target, 
			name2 => "shell_call", value2 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			next if $found_node;
			
			if ($line =~ /uuid=(.*?) bytes_downloaded=(\d+) percent=(\d+) current_rate=(\d+) average_rate=(\d+) seconds_running=(\d+) seconds_left=(.*?) url=(.*?) out_file=(.*)$/)
			{
				my $uuid             = $1;
				my $bytes_downloaded = $2;
				my $percent          = $3;
				my $current_rate     = $4;
				my $average_rate     = $5;
				my $seconds_running  = $6;
				my $seconds_left     = $7;
				my $url              = $8;
				my $out_file         = $9;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0009", message_variables => {
					name1 => "uuid",             value1 => $uuid, 
					name2 => "bytes_downloaded", value2 => $bytes_downloaded, 
					name3 => "percent",          value3 => $percent, 
					name4 => "current_rate",     value4 => $current_rate, 
					name5 => "average_rate",     value5 => $average_rate, 
					name6 => "seconds_running",  value6 => $seconds_running, 
					name7 => "seconds_left",     value7 => $seconds_left, 
					name8 => "url",              value8 => $url, 
					name9 => "out_file",         value9 => $out_file, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($uuid eq $job_uuid)
				{
					$found_node = $node_key;
					$do_abort   = 1;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "found_node", value1 => $found_node, 
						name2 => "do_abort",   value2 => $do_abort, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			if ($line =~ /done=(\d+?) uuid=(.*?) bytes_downloaded=(\d+?) average_rate=(\d+?) seconds_running=(\d+?) url=(.*?) out_file=(.*)$/)
			{
				my $done             = $1;
				my $uuid             = $2;
				my $bytes_downloaded = $3;
				my $average_rate     = $4;
				my $seconds_running  = $5;
				my $url              = $6;
				my $out_file         = $7;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0009", message_variables => {
					name1 => "done",             value1 => $done, 
					name2 => "uuid",             value2 => $uuid, 
					name3 => "bytes_downloaded", value3 => $bytes_downloaded, 
					name4 => "average_rate",     value4 => $average_rate, 
					name5 => "seconds_running",  value5 => $seconds_running, 
					name6 => "url",              value6 => $url, 
					name7 => "out_file",         value7 => $out_file, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($uuid eq $job_uuid)
				{
					$found_node = $node_key;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "found_node", value1 => $found_node, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		
	}
	
	# If I found the host and I need to do the abort, do it.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "found_node", value1 => $found_node, 
		name2 => "do_abort",   value2 => $do_abort, 
	}, file => $THIS_FILE, line => __LINE__});
	if (($found_node) && ($do_abort))
	{
		my $node_key  = $found_node;
		my $node_name = $an->data->{sys}{anvil}{$node_key}{name};
		my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
		my $port      = $an->data->{sys}{anvil}{$node_key}{use_port}; 
		my $password  = $an->data->{sys}{anvil}{$node_key}{password};
		my $online    = $an->data->{sys}{anvil}{$node_key}{online};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
			name1 => "node_key",  value1 => $node_key, 
			name2 => "node_name", value2 => $node_name, 
			name3 => "target",    value3 => $target, 
			name4 => "port",      value4 => $port, 
			name5 => "online",    value5 => $online, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password, 
		}, file => $THIS_FILE, line => __LINE__});
		my $file_displayed = 0;
		
		# Is the node accessible?
		next if not $online;
		
		# Still alive? Good. Is this the node hosting the download?
		my $opened_list = 0;
		my $shell_call  = $an->data->{path}{'anvil-download-file'}." --abort $job_uuid";
		if ($subtask eq "delete")
		{
			$shell_call .= " --delete";
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target, 
			name2 => "shell_call", value2 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		# There should be no output.
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			next if $found_node;
		}
	}
	
	# Print the footer
	my $string_key = "message_0505";
	if ($subtask eq "delete")
	{
		$string_key = "message_0506";
	}
	my $message    = $an->String->get({key => $string_key, variables => { url => $url }});
	print $an->Web->template({file => "media-library.html", template => "download-aborted", replace => { 
		message      => $message,
		reload_time  => 15,
		redirect_url => "/cgi-bin/mediaLibrary?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&task=monitor_downloads",
	}});
}

# This tries to see of there is a DVD or CD in the local drive (if there is a local drive at all).
sub _check_local_dvd
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_check_local_dvd" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $dev        = "";
	my $shell_call = $an->data->{path}{check_dvd}." ".$an->data->{args}{check_dvd};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
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
			my $volume                          = $1;
			   $an->data->{drive}{$dev}{volume} = $volume;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "drive::${dev}::volume", value1 => $an->data->{drive}{$dev}{volume},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /Volume Set\s+:\s+(.*)/i)
		{
			my $volume_set                          = $1;
			   $an->data->{drive}{$dev}{volume_set} = $volume_set;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "drive::${dev}::volume_set", value1 => $an->data->{drive}{$dev}{volume_set},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /No medium found/i)
		{
			$an->data->{drive}{$dev}{no_disc} = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "drive::${dev}::no_disc", value1 => $an->data->{drive}{$dev}{no_disc},
			}, file => $THIS_FILE, line => __LINE__});
			last;
		}
		elsif ($line =~ /unknown filesystem/i)
		{
			$an->data->{drive}{$dev}{reload} = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "drive::${dev}::reload", value1 => $an->data->{drive}{$dev}{reload},
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

# This asks the user to confirm that s/he wants to about (and delete) the downloading file.
sub _confirm_abort_download
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_confirm_abort_download" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $subtask    = $an->data->{cgi}{subtask} eq "delete" ? "delete" : "abort";
	my $job_uuid   = $an->data->{cgi}{job_uuid};
	my $url        = $an->data->{cgi}{url};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "subtask",    value2 => $subtask,
		name3 => "job_uuid",   value3 => $job_uuid,
		name4 => "url",        value4 => $url,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $warning_key = "message_0504";
	if ($subtask eq "abort")
	{
		$warning_key = "message_0503";
	}
	my $say_title = $an->String->get({key => "title_0208"});
	my $message   = $an->String->get({key => $warning_key, variables => { url => $url }});
	
	my $confirm_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
			button_class	=>	"bold_button",
			button_link	=>	$an->data->{sys}{cgi_string}."&confirm=true",
			button_text	=>	"#!string!button_0004!#",
			id		=>	"abort_download_confirmed",
		}});

	# Display the confirmation window now.
	print $an->Web->template({file => "media-library.html", template => "abort-download-confirm", replace => { 
		title          => $say_title,
		message        => $message,
		confirm_button => $confirm_button,
	}});
	
	return (0);
}

# This asks the user to confirm that s/he wants to delete the file.
sub _confirm_delete_file
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_confirm_delete_file" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $name       = $an->data->{cgi}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "name",       value3 => $name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# See if this file is currently used by any servers. If so, we can proceed, but warn that migration 
	# scripts will be automatically deleted and ISOs will be automatically ejected.
	my $warning     = "";
	my $server_data = $an->ScanCore->get_servers();
	foreach my $hash_ref (@{$server_data})
	{
		my $server_uuid                     = $hash_ref->{server_uuid};
		my $server_name                     = $hash_ref->{server_name};
		my $server_definition               = $hash_ref->{server_definition};
		my $server_pre_migration_script     = $hash_ref->{server_pre_migration_script};
		my $server_pre_migration_arguments  = $hash_ref->{server_pre_migration_arguments};
		my $server_post_migration_script    = $hash_ref->{server_post_migration_script};
		my $server_post_migration_arguments = $hash_ref->{server_post_migration_arguments};
		my $server_anvil_uuid               = $hash_ref->{server_anvil_uuid};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0008", message_variables => {
			name1 => "server_uuid",                     value1 => $server_uuid,
			name2 => "server_name",                     value2 => $server_name,
			name3 => "server_definition",               value3 => $server_definition,
			name4 => "server_pre_migration_script",     value4 => $server_pre_migration_script,
			name5 => "server_pre_migration_arguments",  value5 => $server_pre_migration_arguments,
			name6 => "server_post_migration_script",    value6 => $server_post_migration_script,
			name7 => "server_post_migration_arguments", value7 => $server_post_migration_arguments,
			name8 => "server_anvil_uuid",               value8 => $server_anvil_uuid,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Skip this server if it isn't on this Anvil!.
		next if $anvil_uuid ne $server_anvil_uuid;
		
		# Is the file to be deleted one of the scripts?
		if ($name eq $server_pre_migration_script)
		{
			# File is set as a pre-migration script for this server.
			my $say_script =  $server_pre_migration_arguments ? $server_pre_migration_script." ".$server_pre_migration_arguments : $server_pre_migration_script;
			   $warning    .= $an->String->get({key => "warning_0003", variables => { 
				server_name => $server_name,
				script      => $say_script,
			}});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "warning", value1 => $warning, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($name eq $server_post_migration_script)
		{
			# File is set as a post-migration script for this server.
			my $say_script =  $server_pre_migration_arguments ? $server_pre_migration_script." ".$server_pre_migration_arguments : $server_pre_migration_script;
			   $warning    .= $an->String->get({key => "warning_0004", variables => { 
				server_name => $server_name,
				script      => $say_script,
			}});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "warning", value1 => $warning, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# See if this file is a mounted ISO.
			my $in_cdrom = 0;
			foreach my $line (split/\n/, $server_definition)
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if (($line =~ /type='file'/) && ($line =~ /device='cdrom'/))
				{
					# Found an optical disk (DVD/CD).
					$in_cdrom = 1;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "in_cdrom", value1 => $in_cdrom, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($in_cdrom)
				{
					if ($line =~ /<\/disk>/)
					{
						$in_cdrom = 0;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "in_cdrom", value1 => $in_cdrom, 
						}, file => $THIS_FILE, line => __LINE__});
					}
					elsif ($line =~ /file='(.*?)'\/>/)
					{
						# Found media
						my $this_media = $1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "this_media", value1 => $this_media, 
						}, file => $THIS_FILE, line => __LINE__});
						
						if ($name eq $this_media)
						{
							# This file is an ISO mounted on this server.
							$warning .= $an->String->get({key => "warning_0005", variables => { server_name => $server_name }});
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "warning", value1 => $warning, 
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
				}
			}
		}
	}
	
	# If I have any warnings, add the warning footer
	if ($warning)
	{
		$warning .= $an->String->get({key => "warning_0006"});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "warning", value1 => $warning, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	my $say_title = $an->String->get({key => "title_0134", variables => { 
			name	=>	$name,
			anvil	=>	$anvil_name,
		}});
	my $say_delete = $an->String->get({key => "message_0316", variables => { 
			name	=>	$name,
			anvil	=>	$anvil_name,
		}});
	my $confirm_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
			button_class	=>	"bold_button",
			button_link	=>	$an->data->{sys}{cgi_string}."&confirm=true",
			button_text	=>	"#!string!button_0004!#",
			id		=>	"delete_file_confirmed",
		}});

	# Display the confirmation window now.
	print $an->Web->template({file => "media-library.html", template => "file-delete-confirm", replace => { 
		title		=>	$say_title,
		say_delete	=>	$say_delete,
		confirm_button	=>	$confirm_button,
		warning		=>	$warning,
	}});
	
	return (0);
}

# This deletes a file from the Anvil! system.
sub _delete_file
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_delete_file" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $name       = $an->data->{cgi}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "name",       value3 => $name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	my ($target, $port, $password, $node_name) = $an->Cman->find_node_in_cluster();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node_name", value1 => $node_name,
		name2 => "target",    value2 => $target,
		name3 => "port",      value3 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $target)
	{
		# Tell the user we have no access and can't proceed.
		my $explain = $an->String->get({key => "message_0328", variables => { anvil => $anvil_name }});
		print $an->Web->template({file => "media-library.html", template => "read-shared-no-access", replace => { message => $explain }});
		return("");
	}
	
	my ($files, $partition) = $an->Get->shared_files({
		target		=>	$target,
		port		=>	$port,
		password	=>	$password,
	});
	
	# Make sure things are sane
	if (exists $files->{$name})
	{
		# Do the delete.
		my $say_title = $an->String->get({key => "title_0135", variables => { name => $name }});
		print $an->Web->template({file => "media-library.html", template => "file-delete-header", replace => { title => $say_title }});
		
		# First, update any servers that use this file.
		my $warning     = "";
		my $server_data = $an->ScanCore->get_servers();
		foreach my $hash_ref (@{$server_data})
		{
			my $server_uuid                     = $hash_ref->{server_uuid};
			my $server_name                     = $hash_ref->{server_name};
			my $server_definition               = $hash_ref->{server_definition};
			my $server_pre_migration_script     = $hash_ref->{server_pre_migration_script};
			my $server_pre_migration_arguments  = $hash_ref->{server_pre_migration_arguments};
			my $server_post_migration_script    = $hash_ref->{server_post_migration_script};
			my $server_post_migration_arguments = $hash_ref->{server_post_migration_arguments};
			my $server_anvil_uuid               = $hash_ref->{server_anvil_uuid};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0008", message_variables => {
				name1 => "server_uuid",                     value1 => $server_uuid,
				name2 => "server_name",                     value2 => $server_name,
				name3 => "server_definition",               value3 => $server_definition,
				name4 => "server_pre_migration_script",     value4 => $server_pre_migration_script,
				name5 => "server_pre_migration_arguments",  value5 => $server_pre_migration_arguments,
				name6 => "server_post_migration_script",    value6 => $server_post_migration_script,
				name7 => "server_post_migration_arguments", value7 => $server_post_migration_arguments,
				name8 => "server_anvil_uuid",               value8 => $server_anvil_uuid,
			}, file => $THIS_FILE, line => __LINE__});
			
			# Skip this server if it isn't on this Anvil!.
			next if $anvil_uuid ne $server_anvil_uuid;
			
			# Is the file to be deleted one of the scripts?
			if ($name eq $server_pre_migration_script)
			{
				# Remove it.
				my $query = "
UPDATE 
    servers 
SET 
    server_pre_migration_script    = NULL, 
    server_pre_migration_arguments = NULL, 
    modified_date                  = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    server_uuid                    = ".$an->data->{sys}{use_db_fh}->quote($server_uuid)."
";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "query", value1 => $query
				}, file => $THIS_FILE, line => __LINE__});
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
				
				$warning .= $an->String->get({key => "warning_0007", variables => { server_name => $server_name }});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "warning", value1 => $warning, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($name eq $server_post_migration_script)
			{
				my $query = "
UPDATE 
    servers 
SET 
    server_post_migration_script    = NULL, 
    server_post_migration_arguments = NULL, 
    modified_date                   = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    server_uuid                     = ".$an->data->{sys}{use_db_fh}->quote($server_uuid)."
";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "query", value1 => $query
				}, file => $THIS_FILE, line => __LINE__});
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
				
				$warning .= $an->String->get({key => "warning_0008", variables => { server_name => $server_name }});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "warning", value1 => $warning, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# See if this file is a mounted ISO.
				my $in_cdrom = 0;
				foreach my $line (split/\n/, $server_definition)
				{
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
					
					if (($line =~ /type='file'/) && ($line =~ /device='cdrom'/))
					{
						# Found an optical disk (DVD/CD).
						$in_cdrom = 1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "in_cdrom", value1 => $in_cdrom, 
						}, file => $THIS_FILE, line => __LINE__});
					}
					if ($in_cdrom)
					{
						if ($line =~ /<\/disk>/)
						{
							$in_cdrom = 0;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "in_cdrom", value1 => $in_cdrom, 
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($line =~ /file='(.*?)'\/>/)
						{
							# Found media
							my $this_media = $1;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "this_media", value1 => $this_media, 
							}, file => $THIS_FILE, line => __LINE__});
							
							if ($name eq $this_media)
							{
								# Eject this disk
								my $server_is_running = 0;
								$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
									name1 => "server::${server_name}::current_host", value1 => $an->data->{server}{$server_name}{current_host},
								}, file => $THIS_FILE, line => __LINE__});
								if ($an->data->{server}{$server_name}{current_host})
								{
									# Read the current server config from virsh.
									$server_is_running = 1;
									$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
										name1 => "server_is_running", value1 => $server_is_running,
									}, file => $THIS_FILE, line => __LINE__});
								}
								$an->Striker->_server_eject_media({
									target            => $target,
									port              => $port,
									password          => $password,
									server_is_running => $server_is_running,
									quiet             => 1,
								});
								
								$warning .= $an->String->get({key => "warning_0009", variables => { server_name => $server_name }});
								$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
									name1 => "warning", value1 => $warning, 
								}, file => $THIS_FILE, line => __LINE__});
							}
						}
					}
				}
			}
		}
		
		my $shell_call = $an->data->{path}{rm}." -f \"".$an->data->{path}{shared_files}."/$name\"";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			print $an->Web->template({file => "common.html", template => "shell-call-output", replace => { line => $line }});
		}
		print $an->Web->template({file => "media-library.html", template => "file-delete-footer", replace => { warning => $warning }});
	}
	else
	{
		# Failed...
		my $say_title = $an->String->get({key => "title_0136", variables => { 
				name	=>	$name,
				anvil	=>	$anvil_name,
			}});
		my $say_message = $an->String->get({key => "message_0318", variables => { 
				name	=>	$name,
				anvil	=>	$anvil_name,
			}});
		print $an->Web->template({file => "media-library.html", template => "file-delete-failed", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});
	}
	
	return (0);
}

# This prompts the user to confirm the download of a file from the web.
sub _confirm_download_url
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_confirm_download_url" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid    = $an->data->{cgi}{anvil_uuid};
	my $anvil_name    = $an->data->{sys}{anvil}{name};
	my $url           = $an->data->{cgi}{url};
	my ($base, $file) = ($url =~ /^(.*)\/(.*?)$/);
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "url",        value3 => $url,
		name4 => "base",       value4 => $base,
		name5 => "file",       value5 => $file,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $say_title    = $an->String->get({key => "title_0122", variables => { anvil => $anvil_name }});
	my $say_download = $an->String->get({key => "message_0294", variables => { anvil => $anvil_name }});
	
	print $an->Web->template({file => "media-library.html", template => "download-website-confirm", replace => { 
		file		=>	$file,
		title		=>	$say_title,
		base		=>	$base,
		download	=>	$say_download,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});

	return (0);
}

# This asks the user to confirm the image and upload task. It also gives a chance for the user to name the 
# image before upload.
sub _confirm_image_and_upload
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_confirm_image_and_upload" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $dev        = $an->data->{cgi}{dev};
	my $name       = $an->data->{cgi}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "dev",        value3 => $dev,
		name4 => "name",       value4 => $name,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $say_title  = $an->String->get({key => "title_0132", variables => { anvil => $anvil_name }});
	my $input_name = $an->Web->template({file => "common.html", template => "form-input-no-class-defined-width", replace => { 
			type	=>	"text",
			name	=>	"name",
			id	=>	$name,
			value	=>	$name,
			width	=>	"250px",
		}});
	my $hidden_inputs = $an->Web->template({file => "common.html", template => "form-input-no-class", replace => { 
			type	=>	"hidden",
			name	=>	"dev",
			id	=>	"dev",
			value	=>	"$dev",
		}});
	$hidden_inputs .= "\n";
	$hidden_inputs .= $an->Web->template({file => "common.html", template => "form-input-no-class", replace => { 
			type	=>	"hidden",
			name	=>	"anvil_uuid",
			id	=>	"anvil_uuid",
			value	=>	$an->data->{cgi}{anvil_uuid},
		}});
	$hidden_inputs .= "\n";
	$hidden_inputs .= $an->Web->template({file => "common.html", template => "form-input-no-class", replace => { 
			type	=>	"hidden",
			name	=>	"task",
			id	=>	"task",
			value	=>	"image_and_upload",
		}});
	$hidden_inputs .= "\n";
	$hidden_inputs .= $an->Web->template({file => "common.html", template => "form-input-no-class", replace => { 
			type	=>	"hidden",
			name	=>	"confirm",
			id	=>	"confirm",
			value	=>	"true",
		}});
	my $submit_button = $an->Web->template({file => "common.html", template => "form-input", replace => { 
			type	=>	"submit",
			name	=>	"null",
			id	=>	"null",
			value	=>	"#!string!button_0004!#",
			class	=>	"bold_button",
		}});
	$submit_button =~ s/^\s+//; 
	$submit_button =~ s/\s+$//s;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "submit_button", value1 => $submit_button,
	}, file => $THIS_FILE, line => __LINE__});

	# Display the confirmation window now.
	print $an->Web->template({file => "media-library.html", template => "image-and-upload-confirm", replace => { 
		title		=>	$say_title,
		input_name	=>	$input_name,
		hidden_inputs	=>	$hidden_inputs,
		submit_button	=>	$submit_button,
	}});
	
	return (0);
}

# This downloads a given URL directly to the cluster using 'wget'.
sub _download_url
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_download_url" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid    =  $an->data->{cgi}{anvil_uuid};
	my $anvil_name    =  $an->data->{sys}{anvil}{name};
	my $url           =  $an->data->{cgi}{url};
	my ($base, $file) =  ($url =~ /^(.*)\/(.*?)$/);
	   $base          .= "/" if $base !~ /\/$/;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "url",        value3 => $url,
		name4 => "base",       value4 => $base,
		name5 => "file",       value5 => $file,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	my ($target, $port, $password, $node_name) = $an->Cman->find_node_in_cluster();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node_name", value1 => $node_name,
		name2 => "target",    value2 => $target,
		name3 => "port",      value3 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $target)
	{
		# Tell the user we have no access and can't proceed.
		my $explain = $an->String->get({key => "message_0328", variables => { anvil => $anvil_name }});
		print $an->Web->template({file => "media-library.html", template => "read-shared-no-access", replace => { message => $explain }});
		return("");
	}
	
	# Get the shared partition info and the list of files.
	my ($files, $partition) = $an->Get->shared_files({
		target		=>	$target,
		port		=>	$port,
		password	=>	$password,
	});
	
	print $an->Web->template({file => "media-library.html", template => "download-website-header", replace => { 
		file	=>	$file,
		base	=>	$base,
	}});
	
	# We call this and background it immediately so that we don't get stuck waiting for it to return.
	# This does mean though that we'll not get output. So the 'failed' check is, for now, useless.
	my $failed          = 0;
	my $header_printed  = 0;
	my $shell_call      = $an->data->{path}{'anvil-download-file'}." --url $url";
	if ($an->data->{cgi}{script})
	{
		$shell_call .= " --script";
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($token, $delayed_run_output, $problem) = $an->System->delayed_run({
		command  => $shell_call,
		delay    => 0,
		target   => $target,
		password => $password,
		port     => $port,
	});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "token",              value1 => $token,
		name2 => "problem",            value2 => $problem,
		name3 => "delayed_run_output", value3 => $delayed_run_output,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Tell the user that the download will be starting in a moment.
	print $an->Web->template({file => "media-library.html", template => "download_queued", replace => { 
		message      => "#!string!explain_0240!#",
		redirect_url => "/cgi-bin/mediaLibrary?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&task=monitor_downloads",
		reload_time  => 10,
	}});
	
	return (0);
}

# This images and uploads a DVD or CD disc
sub _image_and_upload
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_image_and_upload" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $dev        = $an->data->{cgi}{dev};
	my $name       = $an->data->{cgi}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "dev",        value3 => $dev,
		name4 => "name",       value4 => $name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	my ($target, $port, $password, $node_name) = $an->Cman->find_node_in_cluster();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node_name", value1 => $node_name,
		name2 => "target",    value2 => $target,
		name3 => "port",      value3 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $target)
	{
		# Tell the user we have no access and can't proceed.
		my $explain = $an->String->get({key => "message_0328", variables => { anvil => $anvil_name }});
		print $an->Web->template({file => "media-library.html", template => "read-shared-no-access", replace => { message => $explain }});
		return("");
	}
	
	print $an->Web->template({file => "media-library.html", template => "read-shared-header"});
	# Get the shared partition info and the list of files.
	my ($files, $partition) = $an->Get->shared_files({
		target		=>	$target,
		port		=>	$port,
		password	=>	$password,
	});
	
	# Make sure things are sane
	if (not $name)
	{
		# Tell the user that no name was given.
		print $an->Web->template({file => "media-library.html", template => "image-and-upload-no-name"});
	}
	elsif (not $dev)
	{
		# Tell the user that no name was given.
		print $an->Web->template({file => "media-library.html", template => "image-and-upload-no-device"});
	}
	elsif (exists $files->{$name})
	{
		# Tell the user a file with that name already exists. 
		my $message = $an->String->get({key => "message_0302", variables => { name => $name }});
		print $an->Web->template({file => "media-library.html", template => "image-and-upload-name-conflict", replace => { message => $message }});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "name", value1 => $name,
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Now make sure the disc is still in the drive.
		$an->MediaLibrary->_check_local_dvd();
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "drive::${dev}::reload",  value1 => $an->data->{drive}{$dev}{reload},
			name2 => "drive::${dev}::no_disc", value2 => $an->data->{drive}{$dev}{no_disc},
		}, file => $THIS_FILE, line => __LINE__});
		if (not exists $an->data->{drive}{$dev})
		{
			# The drive vanished.
			my $say_missing_drive = $an->String->get({key => "message_0304", variables => { device => $dev }});
			my $say_try_again     = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	$an->data->{sys}{cgi_string},
				button_text	=>	"#!string!button_0043!#",
			}});
			print $an->Web->template({file => "media-library.html", template => "image-and-upload-drive-gone", replace => { 
				missing_drive	=>	$say_missing_drive,
				try_again	=>	$say_try_again,
			}});
		}
		elsif ($an->data->{drive}{$dev}{reload})
		{
			# Need to reload to read the disc.
			my $say_drive_not_ready = $an->String->get({key => "message_0305", variables => { device => $dev }});
			my $say_try_again       = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	$an->data->{sys}{cgi_string},
					button_text	=>	"#!string!button_0043!#",
				}});
			print $an->Web->template({file => "media-library.html", template => "image-and-upload-reload-needed", replace => { 
				drive_not_ready	=>	$say_drive_not_ready,
				try_again	=>	$say_try_again,
			}});
		}
		elsif ($an->data->{drive}{$dev}{no_disc})
		{
			# No disc in the drive
			my $say_no_disc   = $an->String->get({key => "message_0307", variables => { device => $dev }});
			my $say_try_again = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	$an->data->{sys}{cgi_string},
					button_text	=>	"#!string!button_0043!#",
				}});
			print $an->Web->template({file => "media-library.html", template => "image-and-upload-no-disc", replace => { 
				no_disk		=>	$say_no_disc,
				try_again	=>	$say_try_again,
			}});
		}
		else
		{
			# Ok, we're good to go.
			my $out_file = "'".$an->data->{path}{media}."/$name'";
			my $in_dev   = $dev;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "dev",       value1 => $dev,
				name2 => "directory", value2 => $an->data->{path}{media},
				name3 => "name",      value3 => $name,
			}, file => $THIS_FILE, line => __LINE__});
			my $message = $an->String->get({key => "explain_0059", variables => { 
					device		=>	$dev,
					name		=>	$name,
					directory	=>	$an->data->{path}{media},
				}});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "message", value1 => $message,
			}, file => $THIS_FILE, line => __LINE__});
			print $an->Web->template({file => "media-library.html", template => "image-and-upload-proceed-header", replace => { message => $message }});
			
			my $shell_call = $an->data->{path}{do_dd}." if=$in_dev of=$out_file bs=".$an->data->{sys}{dd_block_size};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			
			my $header_printed = 0;
			open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
			my $error;
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				
				if (not $header_printed)
				{
					print $an->Web->template({file => "common.html", template => "open-shell-call-output"});
					$header_printed = 1;
				}
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "output", value1 => $line,
				}, file => $THIS_FILE, line => __LINE__});
				if ($line =~ /Is a directory/i)
				{
					$error .= $an->String->get({key => "message_0333"});
				}
				print $an->Web->template({file => "common.html", template => "shell-call-output", replace => { line => $line }});
			}
			close $file_handle;
			if ($header_printed)
			{
				print $an->Web->template({file => "common.html", template => "close-shell-call-output"});
			}
			
			if ($error)
			{
				# Image failed, no sense trying to upload.
				print $an->Web->template({file => "media-library.html", template => "image-and-upload-proceed-failed", replace => { error => $error }});
			}
			else
			{
				# Starting to upload now.
				my $explain = $an->String->get({key => "explain_0052", variables => { 
					name	=>	$name,
					anvil	=>	$anvil_name,
				}});
				print $an->Web->template({file => "media-library.html", template => "image-and-upload-proceed-uploading", replace => { explain => $explain }});

				my ($failed) = $an->MediaLibrary->_upload_to_shared({
						source   => $out_file,
						target   => $target,
						port     => $port,
						password => $password,
					});
				
				unlink $out_file if -e $out_file;
				if ($failed)
				{
					# Upload appears to have failed.
					print $an->Web->template({file => "media-library.html", template => "image-and-upload-proceed-upload-failed"});
				}
				else
				{
					# Looks like? Really? do a 'sum' of the files to confirm.
					print $an->Web->template({file => "media-library.html", template => "image-and-upload-proceed-upload-success"});
				}
			}
			print $an->Web->template({file => "media-library.html", template => "image-and-upload-proceed-footer"});
		}
	}
	
	return (0);
}

# This reloads itself so long as at least one download is running in the background. It also allows the 
# user a chance to abort a download.
sub _monitor_downloads
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_monitor_downloads" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "cgi::anvil_uuid", value1 => $an->data->{cgi}{anvil_uuid}, 
		name2 => "cgi::subtask",    value2 => $an->data->{cgi}{subtask}, 
		name3 => "cgi::job_uuid",   value3 => $an->data->{cgi}{job_uuid}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Load the information about the active Anvil! and then do a short scan. We want to be quick so we
	# just want to scan enough to make sure we can still talk to the nodes.
	$an->Striker->load_anvil({anvil_uuid => $an->data->{cgi}{anvil_uuid}});
	$an->Striker->scan_node({uuid => $an->data->{sys}{anvil}{node1}{uuid}, short_scan => 1});
	$an->Striker->scan_node({uuid => $an->data->{sys}{anvil}{node2}{uuid}, short_scan => 1});
	
	# First, read both nodes (if possible) and if either have any running jobs, monitor them.
	if (($an->data->{cgi}{subtask} eq "abort") or ($an->data->{cgi}{subtask} eq "delete"))
	{
		### TODO: ...
		if ($an->data->{cgi}{confirm})
		{
			# Do the dew
			$an->MediaLibrary->_abort_download();
			return(0);
		}
		else
		{
			# Pull the plug nao.
			$an->MediaLibrary->_confirm_abort_download();
			return(0);
		}

	}
	
	# Print the header
	print $an->Web->template({file => "media-library.html", template => "download-progress-header", replace => { anvil_name => $an->data->{sys}{anvil}{name} }});
	
	# Show the progress. 
	my $something_downloading = 0;
	foreach my $node_key ("node1", "node2")
	{
		my $node_name = $an->data->{sys}{anvil}{$node_key}{name};
		my $target    = $an->data->{sys}{anvil}{$node_key}{use_ip};
		my $port      = $an->data->{sys}{anvil}{$node_key}{use_port}; 
		my $password  = $an->data->{sys}{anvil}{$node_key}{password};
		my $online    = $an->data->{sys}{anvil}{$node_key}{online};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "node_name", value1 => $node_name, 
			name2 => "target",    value2 => $target, 
			name3 => "port",      value3 => $port, 
			name4 => "online",    value4 => $online, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password, 
		}, file => $THIS_FILE, line => __LINE__});
		my $file_displayed = 0;
		
		# Print the node header
		print $an->Web->template({file => "media-library.html", template => "download-progress-node-header", replace => { node_name => $node_name }});
		
		# Is the node accessible?
		if (not $online)
		{
			# Offline.
			print $an->Web->template({file => "media-library.html", template => "download-progress-node-text-entry", replace => { 
				message => "#!string!state_0004!#",
				class   => "highlight_offline",
			}});
			print $an->Web->template({file => "media-library.html", template => "download-progress-node-footer"});
			next;
		}
		
		# Still alive? Gooood.
		my $opened_list = 0;
		my $shell_call  = $an->data->{path}{'anvil-download-file'}." --status";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target, 
			name2 => "shell_call", value2 => $shell_call, 
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if (not $opened_list)
			{
				$opened_list = 1;
				print $an->Web->template({file => "media-library.html", template => "download-progress-file-progress-open-list"});
			}
			
			# Update our counters
			$file_displayed++;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "file_displayed", value1 => $file_displayed, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /uuid=(.*?) bytes_downloaded=(\d+) percent=(\d+) current_rate=(\d+) average_rate=(\d+) seconds_running=(\d+) seconds_left=(.*?) url=(.*?) out_file=(.*)$/)
			{
				my $uuid             = $1;
				my $bytes_downloaded = $2;
				my $percent          = $3;
				my $current_rate     = $4;
				my $average_rate     = $5;
				my $seconds_running  = $6;
				my $seconds_left     = $7;
				my $url              = $8;
				my $out_file         = $9;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0009", message_variables => {
					name1 => "uuid",             value1 => $uuid, 
					name2 => "bytes_downloaded", value2 => $bytes_downloaded, 
					name3 => "percent",          value3 => $percent, 
					name4 => "current_rate",     value4 => $current_rate, 
					name5 => "average_rate",     value5 => $average_rate, 
					name6 => "seconds_running",  value6 => $seconds_running, 
					name7 => "seconds_left",     value7 => $seconds_left, 
					name8 => "url",              value8 => $url, 
					name9 => "out_file",         value9 => $out_file, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# Update our counters
				$something_downloading++;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "something_downloading", value1 => $something_downloading, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# Convert the units to be human readable.
				my $say_downloaded   = $an->Readable->bytes_to_hr({'bytes' => $bytes_downloaded});
				my $say_percent      = $percent."%";
				my $say_current_rate = $an->Readable->bytes_to_hr({'bytes' => $current_rate})."/s";
				my $say_average_rate = $an->Readable->bytes_to_hr({'bytes' => $average_rate})."/s";
				my $say_running_time = $an->Readable->time({'time' => $seconds_running, suffix => "long"});
				my $say_time_left    = $an->Readable->time({'time' => $seconds_left, suffix => "long"});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
					name1 => "say_downloaded",   value1 => $say_downloaded, 
					name2 => "say_percent",      value2 => $say_percent, 
					name3 => "say_current_rate", value3 => $say_current_rate, 
					name4 => "say_average_rate", value4 => $say_average_rate, 
					name5 => "say_running_time", value5 => $say_running_time, 
					name6 => "say_time_left",    value6 => $say_time_left, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# Now display!
				print $an->Web->template({file => "media-library.html", template => "download-progress-file-progress", replace => { 
					url          => $url,
					target       => $out_file,
					downloaded   => $say_downloaded,
					percent      => $say_percent,
					current_rate => $say_current_rate,
					average_rate => $say_average_rate,
					running_time => $say_running_time,
					time_left    => $say_time_left,
					abort_url    => "/cgi-bin/mediaLibrary?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&task=monitor_downloads&subtask=abort&job_uuid=$uuid&url=$url", 
					delete_url   => "/cgi-bin/mediaLibrary?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&task=monitor_downloads&subtask=delete&job_uuid=$uuid&url=$url", 
				}});
			}
			if ($line =~ /done=(\d+?) uuid=(.*?) bytes_downloaded=(\d+?) average_rate=(\d+?) seconds_running=(\d+?) url=(.*?) out_file=(.*)$/)
			{
				my $done             = $1;
				my $uuid             = $2;
				my $bytes_downloaded = $3;
				my $average_rate     = $4;
				my $seconds_running  = $5;
				my $url              = $6;
				my $out_file         = $7;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0009", message_variables => {
					name1 => "done",             value1 => $done, 
					name2 => "uuid",             value2 => $uuid, 
					name3 => "bytes_downloaded", value3 => $bytes_downloaded, 
					name4 => "average_rate",     value4 => $average_rate, 
					name5 => "seconds_running",  value5 => $seconds_running, 
					name6 => "url",              value6 => $url, 
					name7 => "out_file",         value7 => $out_file, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# Convert the units to be human readable.
				my $say_downloaded   = $an->Readable->bytes_to_hr({'bytes' => $bytes_downloaded});
				my $say_average_rate = $an->Readable->bytes_to_hr({'bytes' => $average_rate})."/s";
				my $say_running_time = $an->Readable->time({'time' => $seconds_running, suffix => "long"});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "say_downloaded",   value1 => $say_downloaded, 
					name2 => "say_average_rate", value2 => $say_average_rate, 
					name3 => "say_running_time", value3 => $say_running_time, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# Now display!
				print $an->Web->template({file => "media-library.html", template => "download-progress-file-done", replace => { 
					url          => $url,
					target       => $out_file,
					downloaded   => $say_downloaded,
					average_rate => $say_average_rate,
					running_time => $say_running_time,
				}});
			}
			if ($line =~ /failed=(\d+) uuid=(.*?) out_file=(.*) url=(.*)$/)
			{
				my $failed       = $1;
				my $uuid         = $2;
				my $out_file     = $3;
				my $url          = $4;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
					name1 => "failed",   value1 => $failed, 
					name2 => "uuid",     value2 => $uuid, 
					name3 => "out_file", value3 => $out_file, 
					name4 => "url",      value4 => $url, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if (($failed =~ /\D/) or (($failed < 1) or ($failed > 7)))
				{
					$failed = 99;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "failed", value1 => $failed, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				
				my $string_key   = "adf_error_000".$failed;
				my $error_string = $an->String->get({key => $string_key, variables => { 
					uuid     => $uuid,
					out_file => $out_file,
					url      => $url,
				}});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "error_string", value1 => $error_string, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# Display the sadness
				print $an->Web->template({file => "media-library.html", template => "download-progress-file-failed", replace => { 
					url    => $url,
					target => $out_file,
					error  => $error_string,
				}});
			}
			if ($line =~ /aborted=(\d+) uuid=(.*?) url=(.*?) out_file=(.*)$/)
			{
				my $abort    = $1;
				my $uuid     = $2;
				my $url      = $3;
				my $out_file = $4;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
					name1 => "abort",    value1 => $abort, 
					name2 => "uuid",     value2 => $uuid, 
					name3 => "url",      value3 => $url, 
					name4 => "out_file", value4 => $out_file, 
				}, file => $THIS_FILE, line => __LINE__});
				
				my $say_time     = $an->Get->date_and_time({use_time => $abort});
				my $error_string = $an->String->get({key => "adf_warning_0003", variables => { 'time' => $say_time }});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "error_string", value1 => $error_string, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# Display the sadness
				print $an->Web->template({file => "media-library.html", template => "download-progress-file-aborted", replace => { 
					url    => $url,
					target => $out_file,
					error  => $error_string,
				}});
			}
			if ($line =~ /queued=(.*)$/)
			{
				my $url = $1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "url", value1 => $url, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# Tell the user
				my $message = $an->String->get({key => "explain_0241", variables => { url => $url }});;
				print $an->Web->template({file => "media-library.html", template => "download-progress-node-text-entry", replace => { 
					message => $message,
					class   => "highlight_ready",
				}});
			}
		}
		
		if ($opened_list)
		{
			print $an->Web->template({file => "media-library.html", template => "download-progress-file-progress-close-list"});
		}
		
		if (not $file_displayed)
		{
			# Print the 'nothing being downloaded' message.
			print $an->Web->template({file => "media-library.html", template => "download-progress-file-progress-open-list"});
			print $an->Web->template({file => "media-library.html", template => "download-progress-node-text-entry", replace => { 
				message => "#!string!state_0135!#",
				class   => "code",
			}});
		}
		print $an->Web->template({file => "media-library.html", template => "download-progress-file-progress-close-list"});
		
		# Print the node footer
		print $an->Web->template({file => "media-library.html", template => "download-progress-node-footer"});
	}
	
	my $reload_timer = 15;
	if (not $something_downloading)
	{
		# Reload each 30s.
		$reload_timer = 30;
	}
	
	# Print the footer
	print $an->Web->template({file => "media-library.html", template => "download-progress-footer", replace => { 
		reload_time  => $reload_timer,
		redirect_url => "/cgi-bin/mediaLibrary?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&task=monitor_downloads",
	}});
	
	return (0);
}

# This sorts out what needs to happen if 'task' was set.
sub _process_task
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_process_task" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::task",    value1 => $an->data->{cgi}{task}, 
		name2 => "cgi::confirm", value2 => $an->data->{cgi}{confirm}, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	if ($an->data->{cgi}{task} eq "image_and_upload")
	{
		if ($an->data->{cgi}{confirm})
		{
			# Proceed.
			$an->MediaLibrary->_image_and_upload();
		}
		else
		{
			# Get the user to confirm.
			$an->MediaLibrary->_confirm_image_and_upload();
		}
	}
	elsif ($an->data->{cgi}{task} eq "delete")
	{
		if ($an->data->{cgi}{confirm})
		{
			# Proceed.
			$an->MediaLibrary->_delete_file();
		}
		else
		{
			# Get the user to confirm.
			$an->MediaLibrary->_confirm_delete_file();
		}
	}
	elsif ($an->data->{cgi}{task} eq "upload_file")
	{
		$an->MediaLibrary->_save_file_to_disk();
	}
	elsif ($an->data->{cgi}{task} eq "download_url")
	{
		if ($an->data->{cgi}{confirm})
		{
			# Proceed.
			$an->MediaLibrary->_download_url();
		}
		else
		{
			# Get the user to confirm.
			$an->MediaLibrary->_confirm_download_url();
		}
	}
	elsif ($an->data->{cgi}{task} eq "make_plain_text")
	{
		$an->MediaLibrary->_toggle_executable({mark => "off"});
	}
	elsif ($an->data->{cgi}{task} eq "make_executable")
	{
		$an->MediaLibrary->_toggle_executable({mark => "on"});
	}
	elsif ($an->data->{cgi}{task} eq "monitor_downloads")
	{
		$an->MediaLibrary->_monitor_downloads();
	}
	else
	{
		# Dirty debugging...
		print "<pre>\n";
		foreach my $var (sort {$a cmp $b} keys %{$an->data->{cgi}})
		{
			print "var: [$var] -> [".$an->data->{cgi}{$var}."]\n" if $an->data->{cgi}{$var};
		}
		print "</pre>";
	}
	
	return(0);
}

# This tries to log into each node in the Anvil!. The first one it connects to which has /shared/files 
# mounted is the one it will use to up upload the ISO and generate the list of available media. It also 
# compiles a list of which  VMs are on each node.
sub _read_shared
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_read_shared" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $no_scan    = $parameter->{no_scan} ? $parameter->{no_scan} : 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "no_scan",    value1 => $no_scan,
		name2 => "anvil_uuid", value2 => $anvil_uuid,
		name3 => "anvil_name", value3 => $anvil_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# The scan is already done when toggling a script, so this prevents a second scan from happening.
	if (not $no_scan)
	{
		# Scan the Anvil!
		$an->Striker->scan_anvil();
	}
	my ($target, $port, $password, $node_name) = $an->Cman->find_node_in_cluster();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node_name", value1 => $node_name,
		name2 => "target",    value2 => $target,
		name3 => "port",      value3 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	print $an->Web->template({file => "media-library.html", template => "read-shared-header"});
	if ($target)
	{
		# Get the shared partition info and the list of files.
		my ($files, $partition) = $an->Get->shared_files({
			target		=>	$target,
			port		=>	$port,
			password	=>	$password,
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
		my $say_title = $an->String->get({key => "title_0138", variables => { anvil => $anvil_name }});
		print $an->Web->template({file => "media-library.html", template => "read-shared-list-header", replace => { 
			title		=>	$say_title,
			total_space	=>	$say_total_space,
			used_space	=>	$say_used_space,
			free_space	=>	$say_free_space,
		}});
		
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

			my $delete_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
					button_link	=>	"?anvil_uuid=$anvil_uuid&task=delete&name=$file",
					button_text	=>	"<img src=\"#!conf!url::skins!#/#!conf!sys::skin!#/images/icon_clear-fields_16x16.png\" alt=\"#!string!button_0030!#\" border=\"0\" />",
					button_class	=>	"highlight_bad",
					id		=>	"delete_$file",
				}});
			
			my $script_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
					button_link	=>	"?anvil_uuid=$anvil_uuid&task=make_executable&name=$file",
					button_text	=>	"<img src=\"#!conf!url::skins!#/#!conf!sys::skin!#/images/icon_plain-text_16x16.png\" alt=\"#!string!button_0067!#\" border=\"0\" />",
					button_class	=>	"highlight_bad",
					id		=>	"executable_$file",
				}});
			if ($files->{$file}{executable})
			{
				$script_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
						button_link	=>	"?anvil_uuid=$anvil_uuid&task=make_plain_text&name=$file",
						button_text	=>	"<img src=\"#!conf!url::skins!#/#!conf!sys::skin!#/images/icon_executable_16x16.png\" alt=\"#!string!button_0068!#\" border=\"0\" />",
						button_class	=>	"highlight_bad",
						id		=>	"executable_$file",
					}});
			}
			
			# Add an optical disk icon if it is an ISO
			my $iso_icon = "&nbsp;";
			if ($files->{$file}{optical})
			{
				$iso_icon      = "<img src=\"#!conf!url::skins!#/#!conf!sys::skin!#/images/icon_plastic-circle_16x16.png\" alt=\"#!string!row_0215!#\" border=\"0\" />";
				$script_button = "&nbsp;";
			}
			
			print $an->Web->template({file => "media-library.html", template => "read-shared-file-entry", replace => { 
				size			=>	$say_size,
				file			=>	$file,
				delete_button		=>	$delete_button,
				executable_button	=>	$script_button,
				iso_icon		=>	$iso_icon,
			}});
		}
		
		# Read from the DVD drive(s), if found.
		print $an->Web->template({file => "media-library.html", template => "read-shared-optical-drive-header"});

		$an->MediaLibrary->_check_local_dvd();
		foreach my $dev (sort {$a cmp $b} keys %{$an->data->{drive}})
		{
			my $disc_name = "";
			my $upload    = "--";
			if ($an->data->{drive}{$dev}{reload})
			{
				# Drive wasn't ready, rescan needed.
				$disc_name = "#!string!message_0322!#";
			}
			elsif ($an->data->{drive}{$dev}{no_disc})
			{
				# No disc found
				$disc_name = "#!string!message_0323!#";
			}
			elsif ($an->data->{drive}{$dev}{volume})
			{
				$disc_name = "<span class=\"fixed_width\">".$an->data->{drive}{$dev}{volume}."</span>";
				$upload    = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
					button_class	=>	"bold_button",
					button_link	=>	"?anvil_uuid=$anvil_uuid&task=image_and_upload&dev=$dev&name=".$an->data->{drive}{$dev}{volume}.".iso",
					button_text	=>	"#!string!button_0042!#",
					id		=>	"image_and_upload_$dev",
				}});
			}
			elsif ($an->data->{drive}{$dev}{volume_set})
			{
				$disc_name = "<span class=\"fixed_width\">".$an->data->{drive}{$dev}{volume_set}."</span>";
				$upload    = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
					button_class	=>	"bold_button",
					button_link	=>	"?anvil_uuid=$anvil_uuid&task=image_and_upload&dev=$dev&name=".$an->data->{drive}{$dev}{volume_set}.".iso",
					button_text	=>	"#!string!button_0042!#",
					id		=>	"image_and_upload_$dev",
				}});
			}
			else
			{
				# Some other problem reading the disc.
				$disc_name = $an->String->get({key => "message_0324", variables => { device => $dev }});
			}
			print $an->Web->template({file => "media-library.html", template => "read-shared-optical-drive-entry", replace => { 
				device		=>	$dev,
				disc_name	=>	$disc_name,
				upload		=>	$upload,
			}});
		}
		print $an->Web->template({file => "media-library.html", template => "read-shared-footer"});

		# Show the option to download an ISO directly from a URL.
		my $hidden_inputs = $an->Web->template({file => "common.html", template => "form-input-no-class", replace => { 
				type	=>	"hidden",
				name	=>	"anvil_uuid",
				id	=>	"anvil_uuid",
				value	=>	$an->data->{cgi}{anvil_uuid},
			}});
		$hidden_inputs .= "\n";
		$hidden_inputs .= $an->Web->template({file => "common.html", template => "form-input-no-class", replace => { 
				type	=>	"hidden",
				name	=>	"task",
				id	=>	"task",
				value	=>	"download_url",
			}});
		my $url_input = $an->Web->template({file => "common.html", template => "form-input-no-class-defined-width", replace => { 
				type	=>	"text",
				name	=>	"url",
				id	=>	"url",
				value	=>	"",
				width	=>	"250px",
			}});
		my $script_input = $an->Web->template({file => "common.html", template => "form-input-checkbox", replace => { 
				name	=>	"script",
				id	=>	"script",
				value	=>	"true",
				checked	=>	"",
			}});
		my $download_button = $an->Web->template({file => "common.html", template => "form-input", replace => { 
				type	=>	"submit",
				name	=>	"null",
				id	=>	"null",
				value	=>	"#!string!button_0041!#",
				class	=>	"bold_button",
			}});
		print $an->Web->template({file => "media-library.html", template => "read-shared-direct-download", replace => { 
			hidden_inputs	=>	$hidden_inputs,
			url_input	=>	$url_input,
			script_input	=>	$script_input,
			download_button	=>	$download_button,
		}});

		# Show the option to upload from the user's local machine.
		$hidden_inputs = "";
		$hidden_inputs = $an->Web->template({file => "common.html", template => "form-input-no-class", replace => { 
				type	=>	"hidden",
				name	=>	"anvil_uuid",
				id	=>	"anvil_uuid",
				value	=>	$an->data->{cgi}{anvil_uuid},
			}});
		$hidden_inputs .= "\n";
		$hidden_inputs .= $an->Web->template({file => "common.html", template => "form-input-no-class", replace => { 
				type	=>	"hidden",
				name	=>	"task",
				id	=>	"task",
				value	=>	"upload_file",
			}});
		my $file_input = $an->Web->template({file => "common.html", template => "form-input-no-class", replace => { 
				type	=>	"file",
				name	=>	"file",
				id	=>	"file",
				value	=>	"",
			}});
		my $upload_button = $an->Web->template({file => "common.html", template => "form-input", replace => { 
				type	=>	"submit",
				name	=>	"null",
				id	=>	"null",
				value	=>	"#!string!button_0042!#",
				class	=>	"bold_button",
			}});
		print $an->Web->template({file => "media-library.html", template => "read-shared-upload", replace => { 
			hidden_inputs	=>	$hidden_inputs,
			file_input	=>	$file_input,
			script_input	=>	$script_input,
			upload_button	=>	$upload_button,
		}});
	}
	else
	{
		# Can't access either node.
		my $explain = $an->String->get({key => "message_0328", variables => { anvil => $anvil_name }});
		print $an->Web->template({file => "media-library.html", template => "read-shared-no-access", replace => { message => $explain }});
	}

	return(0);
}

# This saves a file to disk from a user's upload.
sub _save_file_to_disk
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_save_file_to_disk" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Scan the Anvil!
	$an->Striker->scan_anvil();
	my ($target, $port, $password, $node_name) = $an->Cman->find_node_in_cluster();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node_name", value1 => $node_name,
		name2 => "target",    value2 => $target,
		name3 => "port",      value3 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $target)
	{
		# Tell the user we have no access and can't proceed.
		my $explain = $an->String->get({key => "message_0328", variables => { anvil => $anvil_name }});
		print $an->Web->template({file => "media-library.html", template => "read-shared-no-access", replace => { message => $explain }});
		return("");
	}
	
	my ($files, $partition) = $an->Get->shared_files({
		target		=>	$target,
		port		=>	$port,
		password	=>	$password,
	});
	
	print $an->Web->template({file => "media-library.html", template => "save-to-disk-header"});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "cgi_fh::file", value1 => $an->data->{cgi_fh}{file},
		name2 => "path::media",  value2 => $an->data->{path}{media},
		name3 => "cgi::file",    value3 => $an->data->{cgi}{file},
	}, file => $THIS_FILE, line => __LINE__});
	
	my $in_fh = $an->data->{cgi_fh}{file};
	if (not $in_fh)
	{
		# User didn't specify a file.
		print $an->Web->template({file => "media-library.html", template => "save-to-disk-no-file"});
	}
	else
	{
		# TODO: Make sure characters like spaces and whatnot don't need to be escaped.
		my $out_file =  $an->data->{path}{media}."/".$an->data->{cgi}{file};
		   $out_file =~ s/\/\//\//g;
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
		print $an->Web->template({file => "media-library.html", template => "save-to-disk-starting"});
		
		my ($failed) = $an->MediaLibrary->_upload_to_shared({
				source   => $out_file,
				target   => $target,
				port     => $port,
				password => $password,
			});
			
		unlink $out_file if -e $out_file;
		if ($failed)
		{
			# Something went wrong
			print $an->Web->template({file => "media-library.html", template => "save-to-disk-failed"});
		}
		else
		{
			# TODO: "Looks like"? Really? do a 'sum' of the files to confirm.
			print $an->Web->template({file => "media-library.html", template => "save-to-disk-success"});
		}
	}
	print $an->Web->template({file => "media-library.html", template => "save-to-disk-footer"});
	
	return (0);
}

# This chmod's the file to 755 if 'on' and 644 if 'off'.
sub _toggle_executable
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_toggle_executable" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $mark       = $parameter->{mark} ? $parameter->{mark} : "";
	my $file       = $an->data->{path}{shared_files}."/".$an->data->{cgi}{name};
	my $mode       = $parameter->{mark} eq "on" ? "755" : "644";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "mark",       value3 => $mark,
		name4 => "file",       value4 => $file,
		name5 => "mode",       value5 => $mode,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Scan the Anvil!.
	$an->Striker->scan_anvil();
	my ($target, $port, $password, $node_name) = $an->Cman->find_node_in_cluster();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node_name", value1 => $node_name,
		name2 => "target",    value2 => $target,
		name3 => "port",      value3 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $shell_call = $an->data->{path}{'chmod'}." $mode $file";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target, 
		name2 => "shell_call", value2 => $shell_call, 
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Show the files.
	$an->MediaLibrary->_read_shared({no_scan => 1});
	
	return(0);
}

# This takes a path to a file on the dashboard and uploads it to the Anvil!'s /shared/files/ folder.
sub _upload_to_shared
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_upload_to_shared" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{cgi}{anvil_uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $source     = $parameter->{source}   ? $parameter->{source}   : "";
	my $target     = $parameter->{target}   ? $parameter->{target}   : "";
	my $port       = $parameter->{port}     ? $parameter->{port}     : "";
	my $password   = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "source",     value3 => $source,
		name4 => "target",     value4 => $target,
		name5 => "port",       value5 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	
	my $switches    = $an->data->{args}{rsync};
	my $file        = ($source =~ /^.*\/(.*)$/)[0];
	my $destination = "root\@${target}:".$an->data->{path}{shared_files}."/";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "switches",    value1 => $switches,
		name2 => "destination", value2 => $destination,
		name3 => "file",        value3 => $file,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	my $failed = $an->Storage->rsync({
		source		=>	$source,
		target		=>	$target,
		port		=>	$port,
		password	=>	$password,
		destination	=>	$destination,
		switches	=>	$switches,
	});
	
	# If the 'script' bit was set, chmod the target file.
	if ($an->data->{cgi}{script})
	{
		my $shell_call = $an->data->{path}{'chmod'}." 755 ".$an->data->{path}{shared_files}."/".$file;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
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

1;
