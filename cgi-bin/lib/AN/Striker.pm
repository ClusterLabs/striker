package AN::Striker;

# Striker - Alteeve's Niche! Anvil Dashboard
# 
# This software is released under the GNU GPL v2+ license.
# 
# No warranty is provided. Do not use this software unless you are willing and
# able to take full liability for it's use. The authors take care to prevent
# unexpected side effects when using this program. However, no software is
# perfect and bugs may exist which could lead to hangs or crashes in the
# program, in your Anvil and possibly even data loss.
# 
# If you are concerned about these risks, please stick to command line tools.
# 
# This program is designed to extend Anvils built according to this tutorial:
# - https://alteeve.com/w/2-Node_Red_Hat_KVM_Cluster_Tutorial
#
# This program's source code and updates are available on Github:
# - https://github.com/digimer/striker
#
# Author;
# Alteeve's Niche!  -  https://alteeve.com
# Madison Kelly     -  mkelly@alteeve.ca
# 
# TODO:
# - Do not allow a node to withdraw if it is UpToDate and the peer is not!
# - When cold-stopping, check if one node is UpToDate and the other not. In such a case, stop the 
#   Inconsistent one FIRST.
# 

use strict;
use warnings;
use IO::Handle;
use CGI;
use Encode;
use CGI::Carp "fatalsToBrowser";

use AN::Cluster;
use AN::Common;

# Setup for UTF-8 mode.
binmode STDOUT, ":utf8:";
$ENV{'PERL_UNICODE'} = 1;
my $THIS_FILE = "AN::Striker.pm";


# Update the ScanCore database(s) to mark the node's 
# (hosts -> host_stop_reason = 'clean') so that they don't just turn right back
# on.
sub mark_node_as_clean_off
{
	my ($conf, $node, $delay) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; mark_node_as_clean_off(); node: [$node], delay: [$delay]\n");
	
	# Put the '$an' handle into the variable for cleaner access.
	my $an = $conf->{handle}{an};
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; an: [".$an."]\n");
	
	# Connect to the databases.
	my $connections = $an->DB->connect_to_databases({
		file	=>	$THIS_FILE,
		quiet	=>	1
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; connections: [$connections]\n");
	if ($connections)
	{
		# Update the hosts entry.
		if (-e $an->data->{path}{host_uuid})
		{
			# Now read in the UUID.
			$an->Get->uuid({get => 'host_uuid'});
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; path::host_uuid: [".$an->data->{path}{host_uuid}."], delay: [$delay]\n");
		
		my $say_off = "clean";
		if ($delay)
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sys::power_off_delay: [$conf->{sys}{power_off_delay}]\n");
			$conf->{sys}{power_off_delay} = 300 if not $conf->{sys}{power_off_delay};
			$say_off = time + $conf->{sys}{power_off_delay};
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_off: [$say_off]\n");
		
		my $query = "
UPDATE 
    hosts 
SET 
    host_emergency_stop = FALSE, 
    host_stop_reason    = ".$an->data->{sys}{use_db_fh}->quote($say_off).", 
    modified_date       = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
WHERE 
    host_name = ".$an->data->{sys}{use_db_fh}->quote($node)."
;";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query});
		
		### TODO: Move the connect/disconnect to outside here so that we don't connect for each 
		###       node...
		# Disconnect from databases.
		$an->DB->disconnect_from_databases();
	}
	else
	{
		# Tell the user we failed to connect to the database.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to connect to any databases. Node: [$node] NOT marked as cleanly off.\n");
	}
	
	return(0);
}

# Update the ScanCore database(s) to mark the node's (hosts -> host_stop_reason = NULL) so that they turn on
# if they're suddenly found to be off.
sub mark_node_as_clean_on
{
	my ($conf, $node) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; mark_node_as_clean_on(); node: [$node]\n");
	
	# Put the '$an' handle into the variable for cleaner access.
	my $an = $conf->{handle}{an};
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; an: [".$an."]\n");
	
	# Connect to the databases.
	my $connections = $an->DB->connect_to_databases({
		file	=>	$THIS_FILE,
		quiet	=>	1
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; connections: [$connections]\n");
	if ($connections)
	{
		# Update the hosts entry.
		if (-e $an->data->{path}{host_uuid})
		{
			# Now read in the UUID.
			$an->Get->uuid({get => 'host_uuid'});
		}
		
		my $query = "
UPDATE 
    hosts 
SET 
    host_emergency_stop = FALSE, 
    host_stop_reason    = NULL, 
    modified_date       = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})."
WHERE 
    host_name = ".$an->data->{sys}{use_db_fh}->quote($node)."
;";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query
		}, file => $THIS_FILE, line => __LINE__});
		$an->DB->do_db_write({query => $query});
		
		### TODO: Move the connect/disconnect to outside here so that we don't connect for each 
		###       node...
		# Disconnect from databases.
		$an->DB->disconnect_from_databases();
	}
	else
	{
		# Tell the user we failed to connect to the database.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to connect to any databases. Node: [$node] NOT marked as cleanly off.\n");
	}
	
	return(0);
}

# This takes a node name and returns the peer node.
sub get_peer_node
{
	my ($conf, $node) = @_;
	my $peer = "";
	
	my $cluster = $conf->{cgi}{cluster};
	foreach my $this_node (sort {$a cmp $b} @{$conf->{clusters}{$cluster}{nodes}})
	{
		next if $node eq $this_node;
		$peer = $this_node;
		last;
	}
	
	if (not $peer)
	{
		AN::Cluster::error($conf, "I was asked to find the peer to: [$node], but failed. This is likely a program error.\n");
	}
	
	return($peer);
}

# This sorts out what needs to happen if 'task' was set.
sub process_task
{
	my ($conf) = @_;
	if ($conf->{cgi}{task} eq "withdraw")
	{
		# Confirmed yet?
		if ($conf->{cgi}{confirm})
		{
			withdraw_node($conf);
		}
		else
		{
			confirm_withdraw_node($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "join_cluster")
	{
		# Confirmed yet?
		if ($conf->{cgi}{confirm})
		{
			join_cluster($conf);
		}
		else
		{
			confirm_join_cluster($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "dual_join")
	{
		# Confirmed yet?
		if ($conf->{cgi}{confirm})
		{
			dual_join($conf);
		}
		else
		{
			confirm_dual_join($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "fence_node")
	{
		# Confirmed yet?
		if ($conf->{cgi}{confirm})
		{
			fence_node($conf);
		}
		else
		{
			confirm_fence_node($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "poweroff_node")
	{
		# Confirmed yet?
		if ($conf->{cgi}{confirm})
		{
			poweroff_node($conf);
		}
		else
		{
			confirm_poweroff_node($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "poweron_node")
	{
		# Confirmed yet?
		if ($conf->{cgi}{confirm})
		{
			poweron_node($conf);
		}
		else
		{
			confirm_poweron_node($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "dual_boot")
	{
		# Confirmed yet?
		if ($conf->{cgi}{confirm})
		{
			dual_boot($conf);
		}
		else
		{
			confirm_dual_boot($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "cold_stop")
	{
		# Confirmed yet?
		if ($conf->{cgi}{confirm})
		{
			# The '1' cancels the APC UPS watchdog timer, if used.
			cold_stop_anvil($conf, 1);
		}
		else
		{
			confirm_cold_stop_anvil($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "start_vm")
	{
		# Confirmed yet?
		if ($conf->{cgi}{confirm})
		{
			start_vm($conf);
		}
		else
		{
			confirm_start_vm($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "stop_vm")
	{
		# Confirmed yet?
		if ($conf->{cgi}{confirm})
		{
			stop_vm($conf);
		}
		else
		{
			confirm_stop_vm($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "force_off_vm")
	{
		# Confirmed yet?
		if ($conf->{cgi}{confirm})
		{
			force_off_vm($conf);
		}
		else
		{
			confirm_force_off_vm($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "delete_vm")
	{
		# Confirmed yet?
		if ($conf->{cgi}{confirm})
		{
			delete_vm($conf);
		}
		else
		{
			confirm_delete_vm($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "migrate_vm")
	{
		# Confirmed yet?
		if ($conf->{cgi}{confirm})
		{
			migrate_vm($conf);
		}
		else
		{
			confirm_migrate_vm($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "provision")
	{
		### TODO: If '$conf->{cgi}{os_variant}' is "generic", warn the
		###       user and ask them to confirm that they really want to
		###       do this.
		# Confirmed yet?
		if ($conf->{cgi}{confirm})
		{
			if (verify_vm_config($conf))
			{
				# We're golden
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; VM verified, creating now.\n");
				provision_vm($conf);
			}
			else
			{
				# Something wasn't sane.
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; VM verification failed.\n");
				confirm_provision_vm($conf);
			}
		}
		else
		{
			confirm_provision_vm($conf);
		}
	}
	elsif ($conf->{cgi}{task} eq "add_vm")
	{
		# This is called after provisioning a VM usually, so no need to
		# confirm
		add_vm_to_cluster($conf, 0);
	}
	elsif ($conf->{cgi}{task} eq "manage_vm")
	{
		manage_vm($conf);
	}
	elsif ($conf->{cgi}{task} eq "display_health")
	{
		print AN::Common::template($conf, "common.html", "scanning-message", {
			anvil	=>	$conf->{cgi}{cluster},
		});
		get_storage_data($conf, $conf->{cgi}{node});
		
		if ((not $conf->{storage}{is}{lsi}) && 
		    (not $conf->{storage}{is}{hp})  &&
		    (not $conf->{storage}{is}{mdadm}))
		{
			# No managers found
			my $say_title = AN::Common::get_string($conf, {key => "title_0016", variables => {
				node	=>	$conf->{cgi}{node},
			}});
			my $say_message = AN::Common::get_string($conf, {key => "message_0051", variables => {
				node_cluster_name	=>	$conf->{cgi}{node_cluster_name},
			}});
			print AN::Common::template($conf, "lsi-storage.html", "no-managers-found", {
				title	=>	$say_title,
				message	=>	$say_message,
			});
		}
		else
		{
			my $display_details = 1;
			if ($conf->{cgi}{'do'})
			{
				if ($conf->{cgi}{'do'} eq "start_id_disk")
				{
					lsi_control_disk_id_led($conf, "start");
					get_storage_data($conf, $conf->{cgi}{node});
				}
				elsif ($conf->{cgi}{'do'} eq "stop_id_disk")
				{
					lsi_control_disk_id_led($conf, "stop");
					get_storage_data($conf, $conf->{cgi}{node});
				}
				elsif ($conf->{cgi}{'do'} eq "make_disk_good")
				{
					lsi_control_make_disk_good($conf);
					get_storage_data($conf, $conf->{cgi}{node});
				}
				elsif ($conf->{cgi}{'do'} eq "add_disk_to_array")
				{
					lsi_control_add_disk_to_array($conf);
					get_storage_data($conf, $conf->{cgi}{node});
				}
				elsif ($conf->{cgi}{'do'} eq "put_disk_online")
				{
					lsi_control_put_disk_online($conf);
					get_storage_data($conf, $conf->{cgi}{node});
				}
				elsif ($conf->{cgi}{'do'} eq "put_disk_offline")
				{
					lsi_control_put_disk_offline($conf);
					get_storage_data($conf, $conf->{cgi}{node});
				}
				elsif ($conf->{cgi}{'do'} eq "mark_disk_missing")
				{
					lsi_control_mark_disk_missing($conf);
					get_storage_data($conf, $conf->{cgi}{node});
				}
				elsif ($conf->{cgi}{'do'} eq "spin_disk_down")
				{
					lsi_control_spin_disk_down($conf);
					get_storage_data($conf, $conf->{cgi}{node});
				}
				elsif ($conf->{cgi}{'do'} eq "spin_disk_up")
				{
					lsi_control_spin_disk_up($conf);
					get_storage_data($conf, $conf->{cgi}{node});
				}
				elsif ($conf->{cgi}{'do'} eq "make_disk_hot_spare")
				{
					lsi_control_make_disk_hot_spare($conf);
					get_storage_data($conf, $conf->{cgi}{node});
				}
				elsif ($conf->{cgi}{'do'} eq "unmake_disk_as_hot_spare")
				{
					lsi_control_unmake_disk_as_hot_spare($conf);
					get_storage_data($conf, $conf->{cgi}{node});
				}
				elsif ($conf->{cgi}{'do'} eq "clear_foreign_state")
				{
					lsi_control_clear_foreign_state($conf);
					get_storage_data($conf, $conf->{cgi}{node});
				}
				### Prepare Unconfigured drives for removal
				# MegaCli64 AdpSetProp AlarmDsbl aN|a0,1,2|aALL 
			}
			if ($display_details)
			{
				display_node_health($conf);
			}
		}
	}
# 	elsif ($conf->{cgi}{task} eq "restart_tomcat")
# 	{
# 		restart_tomcat($conf);
# 	}
	else
	{
		print "<pre>\n";
		foreach my $var (sort {$a cmp $b} keys %{$conf->{cgi}})
		{
			print "var: [$var] -> [$conf->{cgi}{$var}]\n" if $conf->{cgi}{$var};
		}
		print "</pre>";
	}
	
	return(0);
}

# This restarts tomcat on the local machine.
# sub restart_tomcat
# {
# 	my ($conf, $quiet) = @_;
# 	   $quiet     = 0 if not defined $quiet;
# 	my $tries     = 0;
# 	my $max_tries = 3;
# 	
# 	if (not $quiet)
# 	{
# 		# Open the table for telling the user that tomcat is restarting.
# 		print AN::Common::template($conf, "common.html", "restart-guacamole-header");
# 	}
# 	
# 	# Call the restart. It will return '1' if there was a failure and a
# 	# retry is needed.
# 	while (call_restart_tomcat_guacd($conf, $quiet))
# 	{
# 		$tries++;
# 		if ($tries > $max_tries)
# 		{
# 			if ($quiet)
# 			{
# 				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Restart failed, giving up.\n");
# 			}
# 			else
# 			{
# 				print AN::Common::template($conf, "common.html", "shell-call-output", {
# 					line	=>	"message_0336",
# 				});
# 			}
# 			last;
# 		}
# 		else
# 		{
# 			if ($quiet)
# 			{
# 				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Restart failed, giving up.\n");
# 			}
# 			else
# 			{
# 				print AN::Common::template($conf, "common.html", "shell-call-output", {
# 					line	=>	"message_0335",
# 				});
# 			}
# 		}
# 		sleep 5;
# 	}
# 	
# 	# Done.
# 	if (not $quiet)
# 	{
# 		print AN::Common::template($conf, "common.html", "restart-guacamole-footer");
# 	}
# 	
# 	return(0);
# }

# This handles the actual restart calls.
# sub call_restart_tomcat_guacd
# {
# 	my ($conf, $quiet) = @_;
# 	
# 	my $retry = 0;
# 	my $shell_call = "$conf->{path}{restart_tomcat} restart && $conf->{path}{restart_guacd} restart";
# 	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
# 	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
# 	while(<$file_handle>)
# 	{
# 		chomp;
# 		my $line = $_;
# 		if (($line =~ /Starting/i) && ($line =~ /Failed/i))
# 		{
# 			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failure detected: [$line]. Will retry.\n");
# 			$retry = 1;
# 		}
# 		if ($quiet)
# 		{
# 			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
# 		}
# 		else
# 		{
# 			$line = parse_text_line($conf, $line);
# 			print AN::Common::template($conf, "common.html", "shell-call-output", {
# 				line	=>	$line,
# 			});
# 		}
# 	}
# 	close $file_handle;
# 
# 	return($retry);
# }

# This unmarks a disk as a hot spare.
sub lsi_control_unmake_disk_as_hot_spare
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lsi_control_unmake_disk_as_hot_spare()\n");
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $conf->{cgi}{cluster};
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	
	# Mark the disk as a global hot-spare.
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"$conf->{storage}{is}{lsi} PDHSP Rmv PhysDrv [$conf->{cgi}{disk_address}] -a$conf->{cgi}{adapter}",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$return_string .= "$line<br />\n";
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /as Hot Spare Success/i)
		{
			$success = 1;
		}
	}
	
	# Show the user the results.
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = AN::Common::get_string($conf, {key => "lsi_0002", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
			}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = $message_body  = AN::Common::get_string($conf, {key => "lsi_0003", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
				message	=>	$return_string,
			}});
	}
	print AN::Common::template($conf, "lsi-storage.html", "lsi-complete-table-message", {
		title		=>	"#!string!lsi_0001!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	});

	return(0);
}

# Thus clears a disk's foreign state
sub lsi_control_clear_foreign_state
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lsi_control_clear_foreign_state()\n");
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $conf->{cgi}{cluster};
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	
	# Mark the disk as a global hot-spare.
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	"$conf->{storage}{is}{lsi} CfgForeign Clear -a$conf->{cgi}{adapter}",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$return_string .= "$line<br />\n";
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /is cleared/i)
		{
			$success = 1;
		}
	}
	
	# Show the user the results.
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = AN::Common::get_string($conf, {key => "lsi_0043", variables => {
				adapter	=>	$conf->{cgi}{adapter},
			}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = AN::Common::get_string($conf, {key => "lsi_0044", variables => {
				adapter	=>	$conf->{cgi}{adapter},
				message	=>	$return_string,
			}});
	}
	print AN::Common::template($conf, "lsi-storage.html", "lsi-complete-table-message", {
		title		=>	"#!string!lsi_0045!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	});

	return(0);
}

# This marks a disk as a hot spare.
sub lsi_control_make_disk_hot_spare
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lsi_control_make_disk_hot_spare()\n");
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $conf->{cgi}{cluster};
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	
	# Mark the disk as a global hot-spare.
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	"$conf->{storage}{is}{lsi} PDHSP Set PhysDrv [$conf->{cgi}{disk_address}] -a$conf->{cgi}{adapter}",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$return_string .= "$line<br />\n";
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /as Hot Spare Success/i)
		{
			$success = 1;
		}
	}
	
	# Show the user the results.
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = AN::Common::get_string($conf, {key => "lsi_0005", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
			}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = AN::Common::get_string($conf, {key => "lsi_0006", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
				message	=>	$return_string,
			}});
	}
	print AN::Common::template($conf, "lsi-storage.html", "lsi-complete-table-message", {
		title		=>	"#!string!lsi_0004!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	});

	return(0);
}

# This marks an "Offline" disk as "Missing".
sub lsi_control_mark_disk_missing
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lsi_control_mark_disk_missing()\n");
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $conf->{cgi}{cluster};
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"$conf->{storage}{is}{lsi} PDMarkMissing PhysDrv [$conf->{cgi}{disk_address}] -a$conf->{cgi}{adapter}",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$return_string .= "$line<br />\n";
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /is marked missing/i)
		{
			$success = 1;
		}
		elsif ($line =~ /in a state that doesn't support the requested command/i)
		{
			$success = 2;
		}
	}
	
	# Show the user the results.
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = AN::Common::get_string($conf, {key => "lsi_0007", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
			}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = AN::Common::get_string($conf, {key => "lsi_0008", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
				message	=>	$return_string,
			}});
	}
	elsif ($success == 2)
	{
		$title_message = "#!string!row_0032!#";
		$title_class   = "highlight_detail";
		$message_body  = AN::Common::get_string($conf, {key => "lsi_0009", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
			}});
	}
	print AN::Common::template($conf, "lsi-storage.html", "lsi-complete-table-message", {
		title		=>	"#!string!lsi_0013!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	});
	
	if ($success)
	{
		lsi_control_spin_disk_down($conf);
	}

	return(0);
}

# This spins up an "Unconfigured, spun down" disk, making it available again.
sub lsi_control_spin_disk_up
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lsi_control_spin_disk_up()\n");
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $conf->{cgi}{cluster};
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	
	# This spins the drive back up.
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"$conf->{storage}{is}{lsi} PDPrpRmv Undo PhysDrv [$conf->{cgi}{disk_address}] -a$conf->{cgi}{adapter}",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$return_string .= "$line<br />\n";
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /Undo Prepare for removal Success/i)
		{
			$success = 1;
		}
	}

	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = AN::Common::get_string($conf, {key => "lsi_0010", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
			}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = AN::Common::get_string($conf, {key => "lsi_0011", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
				message	=>	$return_string,
			}});
	}
	print AN::Common::template($conf, "lsi-storage.html", "lsi-complete-table-message", {
		title		=>	"#!string!lsi_0012!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	});

	return(0);
}

# This spins down an "Offline" disk, Preparing it for removal.
sub lsi_control_spin_disk_down
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lsi_control_spin_disk_down()\n");
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $conf->{cgi}{cluster};
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"$conf->{storage}{is}{lsi} PDPrpRmv PhysDrv [$conf->{cgi}{disk_address}] -a$conf->{cgi}{adapter}",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$return_string .= "$line<br />\n";
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /Prepare for removal Success/i)
		{
			$success = 1;
		}
		elsif ($line =~ /in a state that doesn't support the requested command/i)
		{
			$success = 2;
		}
	}

	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = AN::Common::get_string($conf, {key => "lsi_0015", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
			}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = AN::Common::get_string($conf, {key => "lsi_0016", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
				message	=>	$return_string,
			}});
	}
	elsif ($success == 2)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = AN::Common::get_string($conf, {key => "lsi_0017", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
			}});
	}
	print AN::Common::template($conf, "lsi-storage.html", "lsi-complete-table-message", {
		title		=>	"#!string!lsi_0014!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	});
	
	# If this failed because the firmware rejected the request, try to mark
	# the disk as good and then spin it down.
	if ($success == 2)
	{
		if (lsi_control_make_disk_good($conf))
		{
			lsi_control_spin_disk_down($conf);
		}
	}
	
	return(0);
}

# This gets the rebuild status of a drive
sub lsi_control_get_rebuild_progress
{
	my ($conf, $disk_address, $adapter) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lsi_control_get_rebuild_progress(); disk_address: [$disk_address], adapter: [$adapter]\n");
	
	my $rebuild_percent   = "";
	my $time_to_complete  = "";
	my $cluster           = $conf->{cgi}{cluster};
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"$conf->{storage}{is}{lsi} PDRbld ShowProg PhysDrv [$disk_address] a$adapter",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		next if not $line;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /completed (\d+)% in (.*?)\./i)
		{
			$rebuild_percent  = $1;
			$time_to_complete = $2;
		}
	}
	
	return($rebuild_percent, $time_to_complete);
}

# This puts an "Online, Spun Up" disk into "Offline" state.
sub lsi_control_put_disk_offline
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lsi_control_put_disk_offline()\n");
	
	### NOTE: I don't think I need this function. For now, I simply
	###       redirect to the "prepare for removal" function.
	#lsi_control_mark_disk_missing($conf);
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $conf->{cgi}{cluster};
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	my $this_adapter      = $conf->{cgi}{adapter};
	my $this_logical_disk = $conf->{cgi}{logical_disk};
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], State: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'}]\n");
	if (($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'} =~ /Degraded/i) && ($this_logical_disk != 9999))
	{
		my $reason = AN::Common::get_string($conf, {key => "lsi_0019"});
		if ($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{primary_raid_level} eq "6")
		{
			$reason = AN::Common::get_string($conf, {key => "lsi_0020"});
		}
		my $message = AN::Common::get_string($conf, {key => "lsi_0021", variables => {
				disk		=>	$conf->{cgi}{disk_address},
				logical_disk	=>	$this_logical_disk,
				reason		=>	$reason,
			}});
		print AN::Common::template($conf, "lsi-storage.html", "lsi-complete-table-message", {
			title		=>	"#!string!lsi_0018!#",
			row		=>	"#!string!row_0045!#",
			row_class	=>	"highlight_warning",
			message		=>	$message,
		});
		return(0);
	}
	
	if (not $conf->{cgi}{confirm})
	{
		my $message = AN::Common::get_string($conf, {key => "lsi_0022", variables => {
				disk		=>	$conf->{cgi}{disk_address},
				logical_disk	=>	$this_logical_disk,
			}});
		my $alert       =  "#!string!row_0044!#";
		my $alert_class =  "highlight_warning_bold";
		if ($this_logical_disk == 9999)
		{
			$message     = AN::Common::get_string($conf, {key => "lsi_0023"});
			$alert       = "#!string!row_0032!#";
			$alert_class = "highlight_detail_bold";
		}
		# Both messages have the same second part that asks the user to confirm.
		$message .= AN::Common::get_string($conf, {key => "lsi_0024", variables => {
				confirm_url	=>	"?cluster=$conf->{cgi}{cluster}&node=$conf->{cgi}{node}&node_cluster_name=$conf->{cgi}{node_cluster_name}&task=display_health&do=put_disk_offline&disk_address=$conf->{cgi}{disk_address}&adapter=$this_adapter&logical_disk=$this_logical_disk&confirm=true",
				cancel_url	=>	"?cluster=$conf->{cgi}{cluster}&node=$conf->{cgi}{node}&node_cluster_name=$conf->{cgi}{node_cluster_name}&task=display_health",
			}});
		print AN::Common::template($conf, "lsi-storage.html", "lsi-complete-table-message", {
			title		=>	"#!string!title_0018!#",
			row		=>	$alert,
			row_class	=>	$alert_class,
			message		=>	$message,
		});
		return (0);
	}
	
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"$conf->{storage}{is}{lsi} PDOffline PhysDrv [$conf->{cgi}{disk_address}] -a$conf->{cgi}{adapter}",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$return_string .= "$line<br />\n";
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /state changed to offline/i)
		{
			$success = 1;
		}
	}
	
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = AN::Common::get_string($conf, {key => "lsi_0025", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
			}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = AN::Common::get_string($conf, {key => "lsi_0027", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
				message	=>	$return_string,
			}});
	}
	print AN::Common::template($conf, "lsi-storage.html", "lsi-complete-table-message", {
		title		=>	"#!string!lsi_0026!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	});
	
	if ($success)
	{
		# Mark the disk as "missing" from the array.
		lsi_control_mark_disk_missing($conf);
	}

	return(0);
}

# This puts an "Offline" disk into "Online" state.
sub lsi_control_put_disk_online
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lsi_control_put_disk_online()\n");
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $conf->{cgi}{cluster};
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"$conf->{storage}{is}{lsi} PDRbld Start PhysDrv [$conf->{cgi}{disk_address}] -a$conf->{cgi}{adapter}",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$return_string .= "$line<br />\n";
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /started rebuild progress on device/i)
		{
			$success = 1;
		}
	}
	
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = AN::Common::get_string($conf, {key => "lsi_0028", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
			}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = AN::Common::get_string($conf, {key => "lsi_0029", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
				message	=>	$return_string,
			}});
	}
	print AN::Common::template($conf, "lsi-storage.html", "lsi-complete-table-message", {
		title		=>	"#!string!lsi_0030!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	});

	return(0);
}

# This adds an "Unconfigured Good" disk to the specified array.
sub lsi_control_add_disk_to_array
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lsi_control_add_disk_to_array()\n");
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $conf->{cgi}{cluster};
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"$conf->{storage}{is}{lsi} PdReplaceMissing PhysDrv [$conf->{cgi}{disk_address}] -array$conf->{cgi}{logical_disk} -row$conf->{cgi}{row} -a$conf->{cgi}{adapter}",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$return_string .= "$line<br />\n";
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if (($line =~ /successfully added the disk/i) || ($line =~ /missing pd at array/i))
		{
			$success = 1;
		}
	}
	
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = AN::Common::get_string($conf, {key => "lsi_0031", variables => {
				disk		=>	$conf->{cgi}{disk_address},
				adapter		=>	$conf->{cgi}{adapter},
				logical_disk	=>	$conf->{cgi}{logical_disk},
			}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = AN::Common::get_string($conf, {key => "lsi_0032", variables => {
				disk		=>	$conf->{cgi}{disk_address},
				adapter		=>	$conf->{cgi}{adapter},
				logical_disk	=>	$conf->{cgi}{logical_disk},
				message		=>	$return_string,
			}});
	}
	print AN::Common::template($conf, "lsi-storage.html", "lsi-complete-table-message", {
		title		=>	"#!string!lsi_0033!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	});
	
	# If successful, put the disk Online.
	if ($success)
	{
		lsi_control_put_disk_online($conf);
	}
	
	return(0);
}

# This looks ip the missing disk(s) in a given degraded array
sub lsi_control_get_missing_disks
{
	my ($conf, $this_adapter, $this_logical_disk) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lsi_control_get_missing_disks(); this_adapter: [$this_adapter] this_logical_disk: [$this_logical_disk]\n");
	
	my $cluster           = $conf->{cgi}{cluster};
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"$conf->{storage}{is}{lsi} PdGetMissing a$this_adapter",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /\d+\s+\d+\s+(\d+)\s(\d+)/i)
		{
			my $this_row     =  $1;
			my $minimum_size =  $2;		# This is in MiB and is the cooerced size.
			   $minimum_size *= 1048576;	# Now it should be in bytes
			$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{missing_row}{$this_row} = $minimum_size;
		}
	}
	
	return(0);
}

# This tells the controller to make the flagged disk "Good"
sub lsi_control_make_disk_good
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lsi_control_make_disk_good()\n");
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $conf->{cgi}{cluster};
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"$conf->{storage}{is}{lsi} PDMakeGood PhysDrv [$conf->{cgi}{disk_address}] -a$conf->{cgi}{adapter}",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$return_string .= "$line<br />\n";
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /state changed to unconfigured-good/i)
		{
			$success = 1;
		}
	}
	
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = AN::Common::get_string($conf, {key => "lsi_0034", variables => {
				disk		=>	$conf->{cgi}{disk_address},
				adapter		=>	$conf->{cgi}{adapter},
			}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = AN::Common::get_string($conf, {key => "lsi_0035", variables => {
				disk		=>	$conf->{cgi}{disk_address},
				adapter		=>	$conf->{cgi}{adapter},
				message		=>	$return_string,
			}});
	}
	print AN::Common::template($conf, "lsi-storage.html", "lsi-complete-table-message", {
		title		=>	"#!string!lsi_0036!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	});
	
	return($success);
}

# This turns on or off the "locate" LED on the hard drives.
sub lsi_control_disk_id_led
{
	my ($conf, $action) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lsi_control_disk_id_led(); action: [$action]\n");
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $conf->{cgi}{cluster};
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	my $say_action        = "#!string!state_0014!#";
	if ($action eq "stop")
	{
		$say_action = "#!string!state_0015!#";
	}
	elsif ($action ne "start")
	{
		$action = "start";
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; action: [$action], say_action: [$say_action]\n");
	
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"$conf->{storage}{is}{lsi} PdLocate $action physdrv [$conf->{cgi}{disk_address}] -a$conf->{cgi}{adapter}",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$return_string .= "$line<br />\n";
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /command was successfully sent to firmware/i)
		{
			$success = 1;
		}
	}
	
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = AN::Common::get_string($conf, {key => "lsi_0037", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
				action	=>	$say_action,
			}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = AN::Common::get_string($conf, {key => "lsi_0038", variables => {
				disk	=>	$conf->{cgi}{disk_address},
				adapter	=>	$conf->{cgi}{adapter},
				message	=>	$return_string,
				action	=>	$say_action,
			}});
	}
	print AN::Common::template($conf, "lsi-storage.html", "lsi-complete-table-message", {
		title		=>	"#!string!lsi_0039!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	});
	
	return ($success);
}

# This reads the sensor values of a given node and displays them. Some sensors
# will be controllable; like failing/adding a hard drive.
sub display_node_health
{
	my ($conf) = @_;
	
	my $cluster           = $conf->{cgi}{cluster};
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	
	# Open up the table.
	print AN::Common::template($conf, "lsi-storage.html", "lsi-adapter-health-header", {
		anvil		=>	$cluster,
		node_anvil_name	=>	$node_cluster_name,
		node		=>	$node,
	});
	
	# Display results.
	if ($conf->{storage}{is}{lsi})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Displaying storage\n");
		foreach my $this_adapter (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; - this_adapter: [$this_adapter]\n");
			foreach my $this_logical_disk (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}})
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";   - this_logical_disk: [$this_logical_disk]\n");
				foreach my $this_enclosure_device_id (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}})
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";     - this_enclosure_device_id: [$this_enclosure_device_id]\n");
					foreach my $this_slot_number (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}})
					{
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";       - this_slot_number: [$this_slot_number]\n");
						#print "adapter: [$this_adapter], logical disk: [$this_logical_disk], enclosure: [$this_enclosure_device_id], slot: [$this_slot_number]\n";
						#$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{raw_sector_count_in_hex}
					}
				}
			}
			my $say_bbu   =                      $conf->{storage}{lsi}{adapter}{$this_adapter}{bbu_is}                        ? "Present" : "Not Installed";
			my $say_flash =                      $conf->{storage}{lsi}{adapter}{$this_adapter}{flash_is}                      ? "Present" : "Not Installed";
			my $say_restore_hotspare_on_insert = $conf->{storage}{lsi}{adapter}{$this_adapter}{restore_hotspare_on_insertion} ? "Yes"     : "No";
			my $say_title = AN::Common::get_string($conf, {key => "lsi_0040", variables => {
				adapter	=>	$this_adapter,
			}});

			print AN::Common::template($conf, "lsi-storage.html", "lsi-adapter-state", {
				title				=>	$say_title,
				model				=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{product_name},
				cache_size			=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{cache_size},
				bbu				=>	$say_bbu,
				flash_module			=>	$say_flash,
				restore_hotspare_on_insert	=>	$say_restore_hotspare_on_insert,
			});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";   - storage::lsi::adapter::${this_adapter}::bbu_is: [$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu_is}]\n");
			if ($conf->{storage}{lsi}{adapter}{$this_adapter}{bbu_is})
			{
				my $say_replace_bbu     = $conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{replace_bbu}        ? "Yes" : "No";
				my $say_learn_cycle     = $conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{learn_cycle_active} ? "Yes" : "No";
				my $battery_state_class = "highlight_good";
				if ($conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{battery_state} ne "Optimal")
				{
					$battery_state_class = "highlight_bad";
				}
				
				# What I show depends on the device the user has.
				my $say_current_capacity = "--";
				my $say_design_capcity   = "--";
				my $say_current_charge   = "--";
				my $say_cycle_count      = "<span class=\"highlight_unavailable\">#!string!state_0016!#</a>";
				if ($conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{full_capacity})
				{
					$say_current_capacity = $conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{full_capacity};
				}
				elsif ($conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{capacitance})
				{
					$say_current_capacity = "$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{capacitance} %";
				}
				if ($conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{design_capacity})
				{
					$say_design_capcity = $conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{design_capacity};
				}
				if ($conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{remaining_capacity})
				{
					$say_current_charge = $conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{remaining_capacity};
				}
				elsif ($conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{pack_energy})
				{
					$say_current_charge = $conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{pack_energy};
				}
				if ($conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{cycle_count})
				{
					$say_cycle_count = $conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{cycle_count};
				}
				
				print AN::Common::template($conf, "lsi-storage.html", "lsi-bbu-state", {
					battery_state		=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{battery_state},
					battery_state_class	=>	$battery_state_class,
					manufacture_name	=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{manufacture_name},
					bbu_type		=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{type},
					full_capacity		=>	$say_current_capacity,
					design_capacity		=>	$say_design_capcity,
					remaining_capacity	=>	$say_current_charge,
					replace_bbu		=>	$say_replace_bbu,
					learn_cycle		=>	$say_learn_cycle,
					next_learn_cycle	=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{next_learn_time},
					cycle_count		=>	$say_cycle_count,
				});
			}
			
			# Show the logical disks now.
			foreach my $this_logical_disk (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}})
			{
				next if $this_logical_disk eq "";
				my $say_bad_blocks =  $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{bad_blocks_exist} ? "Yes" : "No";
				my $say_size       =  $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{size};
				   $say_size       =~ s/(\w)B/$1iB/;	# The use 'GB' when it should be 'GiB'.
				my $logical_disk_state_class = "highlight_good";
				my $say_missing    = "";
				my $allow_offline  = 1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], State: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'}]\n");
				if ($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'} =~ /Degraded/i)
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], State: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'}]\n");
					lsi_control_get_missing_disks($conf, $this_adapter, $this_logical_disk);
					$allow_offline            = 0;
					$logical_disk_state_class = "highlight_bad";
					if ($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'} =~ /Partially Degraded/i)
					{
						$logical_disk_state_class = "highlight_warning";
					}
					$say_missing = "<br />";
					foreach my $this_row (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{missing_row}})
					{
						my $say_minimum_size =  AN::Cluster::bytes_to_hr($conf, $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{missing_row}{$this_row});
						$say_missing         .= AN::Common::get_string($conf, {key => "lsi_0041", variables => {
										row		=>	$this_row,
										minimum_size	=>	$say_minimum_size,
									}});
					}
				}
				
				if ($this_logical_disk == 9999)
				{
					$allow_offline = 1;
					# Unconfigured disks, show the list 
					# header in the place of the logic 
					# disk state.
					print AN::Common::template($conf, "lsi-storage.html", "lsi-unassigned-disks");
				}
				else
				{
					# Real logical disk
					next if not $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'};
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], State: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'}]\n");
					my $title = AN::Common::get_string($conf, {key => "title_0021", variables => {
							logical_disk	=>	$this_logical_disk,
						}});
					print AN::Common::template($conf, "lsi-storage.html", "lsi-logical-disk-state", {
						title				=>	$title,
						logical_disk_state		=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'},
						logical_disk_state_class	=>	$logical_disk_state_class,
						missing				=>	$say_missing,
						bad_blocks_exist		=>	$say_bad_blocks,
						primary_raid_level		=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{primary_raid_level},
						raid_url			=>	"https://alteeve.ca/w/TLUG_Talk:_Storage_Technologies_and_Theory#Level_$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{primary_raid_level}",
						size				=>	$say_size,
						number_of_drives		=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{number_of_drives},
						encryption_type			=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{encryption_type},
						target_id			=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{target_id},
						current_cache_policy		=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{current_cache_policy},
						disk_cache_policy		=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{disk_cache_policy},
					});
				}
				
				# Display the drives in this logical disk.
				foreach my $this_enclosure_device_id (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}})
				{
					#print " | |- Enclusure Device ID: [$this_enclosure_device_id]<br />\n";
					foreach my $this_slot_number (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}})
					{
						my $raw_size_sectors = hex($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{raw_sector_count_in_hex});
						my $raw_size_bytes   = ($raw_size_sectors * $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sector_size});
						my $say_raw_size     = AN::Cluster::bytes_to_hr($conf, $raw_size_bytes);
						my $disk_temp_class  = "highlight_good";
						if ($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_c} > 54)
						{
							$disk_temp_class = "highlight_dangerous";
						}
						elsif ($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_c} > 45)
						{
							$disk_temp_class = "highlight_warning";
						}
						my $say_drive_temp_c = $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_c} ? $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_c} : "--";
						my $say_drive_temp_f = $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_f} ? $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_f} : "--";
						my $say_temperature = "<span class=\"$disk_temp_class\">$say_drive_temp_c &deg;C ($say_drive_temp_f &deg;F)</span>";
						
						my $say_location_title = AN::Common::get_string($conf, {key => "row_0066"});
						my $say_location_body  = "$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{span}, $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{arm}, $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_id}";
						if ($this_logical_disk == 9999)
						{
							$say_location_title = AN::Common::get_string($conf, {key => "row_0067"});
							$say_location_body  = "$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_id}";
						}
						
						my $say_offline_disabled_button = AN::Common::template($conf, "common.html", "disabled-button", {
							button_text	=>	AN::Common::get_string($conf, {key => "row_0067"}),
						}, "", 1);
						my $offline_button = $say_offline_disabled_button;
						if ($allow_offline)
						{
							$offline_button = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
								button_link	=>	"?cluster=$conf->{cgi}{cluster}&node=$conf->{cgi}{node}&node_cluster_name=$conf->{cgi}{node_cluster_name}&task=display_health&do=put_disk_offline&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter&logical_disk=$this_logical_disk",
								button_text	=>	"#!string!button_0006!#",
								id		=>	"put_disk_offline_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
							}, "", 1);
							if ($this_logical_disk == 9999)
							{
								$offline_button = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
									button_link	=>	"?cluster=$conf->{cgi}{cluster}&node=$conf->{cgi}{node}&node_cluster_name=$conf->{cgi}{node_cluster_name}&task=display_health&do=spin_disk_down&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter&logical_disk=$this_logical_disk",
									button_text	=>	"#!string!button_0007!#",
									id		=>	"spin_disk_down_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
								}, "", 1);
							}
						}
						
						my $disk_state_class = "highlight_good";
						my $say_disk_action  = "";
						if ($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Unconfigured(bad)")
						{
							$disk_state_class = "highlight_bad";
							$say_disk_action = AN::Common::template($conf, "common.html", "new_line", "", "", 1);
							$say_disk_action .= AN::Common::template($conf, "common.html", "enabled-button", {
								button_class	=>	"highlight_warning",
								button_link	=>	"?cluster=$conf->{cgi}{cluster}&node=$conf->{cgi}{node}&node_cluster_name=$conf->{cgi}{node_cluster_name}&task=display_health&do=make_disk_good&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
								button_text	=>	"#!string!button_0008!#",
								id		=>	"make_disk_good_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
							}, "", 1);
						}
						elsif ($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Offline")
						{
							$disk_state_class = "highlight_detail";
							my $say_put_disk_online_button = AN::Common::template($conf, "common.html", "enabled-button", {
								button_class	=>	$disk_state_class,
								button_link	=>	"?cluster=$conf->{cgi}{cluster}&node=$conf->{cgi}{node}&node_cluster_name=$conf->{cgi}{node_cluster_name}&task=display_health&do=put_disk_online&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
								button_text	=>	"#!string!button_0009!#",
								id		=>	"put_disk_online__${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
							}, "", 1);
							my $say_spin_disk_down_button = AN::Common::template($conf, "common.html", "enabled-button_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}", {
								button_class	=>	$disk_state_class,
								button_link	=>	"?cluster=$conf->{cgi}{cluster}&node=$conf->{cgi}{node}&node_cluster_name=$conf->{cgi}{node_cluster_name}&task=display_health&do=spin_disk_down&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
								button_text	=>	"#!string!button_0007!#",
								id		=>	"spin_disk_down",
							}, "", 1);
							$say_disk_action  =  " - $say_put_disk_online_button - $say_spin_disk_down_button";
						}
						elsif ($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Rebuild")
						{
							my ($rebuild_percent, $time_to_complete) = lsi_control_get_rebuild_progress($conf, "$this_enclosure_device_id:$this_slot_number", $this_adapter);
							$disk_state_class = "highlight_warning";
							$say_disk_action  = AN::Common::get_string($conf, {key => "lsi_0042", variables => {
								rebuild_percent		=>	$rebuild_percent,
								time_to_complete	=>	$time_to_complete,
							}})
						}
						elsif ($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Unconfigured(good), Spun Up")
						{
							$disk_state_class = "highlight_detail";
							foreach my $this_logical_disk (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}})
							{
								next if $this_logical_disk eq "";
								if ($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'} =~ /Degraded/i)
								{
									# NOTE: I only loop once because if two drives are missing from a RAID 6 
									#       array, the 'Add to Logical Disk' will print twice, once for each
									#       row. So we exit the loop after the first run and thus will always
									#       add disks to the first open row.
									foreach my $this_row (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{missing_row}})
									{
										AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; this_row: [$this_row]\n");
										if ($raw_size_bytes >= $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{missing_row}{$this_row})
										{
											my $say_button = AN::Common::get_string($conf, {key => "button_0010", variables => { logical_disk => $this_logical_disk }});
											AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_button: [$say_button]\n");
											
											$say_disk_action =  AN::Common::template($conf, "common.html", "new_line", "", "", 1) if not $say_disk_action;
											$say_disk_action .= AN::Common::template($conf, "common.html", "enabled-button", {
												button_class	=>	"bold_button",
												button_link	=>	"?cluster=$conf->{cgi}{cluster}&node=$conf->{cgi}{node}&node_cluster_name=$conf->{cgi}{node_cluster_name}&task=display_health&do=add_disk_to_array&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter&row=$this_row&logical_disk=$this_logical_disk",
												button_text	=>	$say_button,
												id		=>	"add_disk_to_array_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
											}, "", 1);
											$say_disk_action .= AN::Common::template($conf, "common.html", "new_line", "", "", 1);
											AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_disk_action: [$say_disk_action]\n");
										}
										last;
									}
								}
								elsif ($this_logical_disk == 9999)
								{
									$say_disk_action = AN::Common::template($conf, "common.html", "new_line", "", "", 1) if not $say_disk_action;
									
									$say_disk_action .= AN::Common::template($conf, "common.html", "enabled-button-no-class", {
										button_link	=>	"?cluster=$conf->{cgi}{cluster}&node=$conf->{cgi}{node}&node_cluster_name=$conf->{cgi}{node_cluster_name}&task=display_health&do=make_disk_hot_spare&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
										button_text	=>	"#!string!button_0011!#",
										id		=>	"make_disk_hot_spare_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
									}, "", 1);
									$say_disk_action .= AN::Common::template($conf, "common.html", "new_line", "", "", 1);
									#$offline_button   = "<a href=\"?cluster=$conf->{cgi}{cluster}&node=$conf->{cgi}{node}&node_cluster_name=$conf->{cgi}{node_cluster_name}&task=display_health&do=make_disk_hot_spare&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter\">".AN::Common::get_string($conf, {key => "button_0011"})."</a>";
								}
							}
						}
						elsif ($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Unconfigured(good), Spun down")
						{
							$disk_state_class =  "highlight_detail";
							$say_disk_action  =  AN::Common::template($conf, "common.html", "new_line", "", "", 1);
							$say_disk_action  .= AN::Common::template($conf, "common.html", "enabled-button-no-class", {
								button_link	=>	"?cluster=$conf->{cgi}{cluster}&node=$conf->{cgi}{node}&node_cluster_name=$conf->{cgi}{node_cluster_name}&task=display_health&do=spin_disk_up&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
								button_text	=>	"#!string!button_0012!#",
								id		=>	"spin_disk_up_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
							}, "", 1);
							$say_temperature  = "<span class=\"highlight_unavailable\">".AN::Common::get_string($conf, {key => "message_0055"})."</a>";
							$offline_button   = AN::Common::get_string($conf, {key => "message_0054"});
						}
						elsif ($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Hotspare, Transition")
						{
							$disk_state_class =  "highlight_detail";
							$say_disk_action  =  AN::Common::template($conf, "common.html", "new_line", "", "", 1);
							$say_disk_action  .= AN::Common::get_string($conf, {key => "message_0056"});
							$say_temperature  =  "<span class=\"highlight_unavailable\">".AN::Common::get_string($conf, {key => "message_0057"})."</span>";
							$offline_button   =  AN::Common::get_string($conf, {key => "message_0058"});
						}
						elsif ($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Hotspare, Spun Up")
						{
							$disk_state_class = "highlight_detail";
							$say_disk_action  = "";
							$offline_button   = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
								button_link	=>	"?cluster=$conf->{cgi}{cluster}&node=$conf->{cgi}{node}&node_cluster_name=$conf->{cgi}{node_cluster_name}&task=display_health&do=unmake_disk_as_hot_spare&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter&logical_disk=$this_logical_disk",
								button_text	=>	"#!string!button_0013!#",
								id		=>	"unmake_disk_as_hot_spare_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
							}, "", 1);
						}
						### TODO: 'Copyback' state is when a drive has been inserted into an
						### array after a hot-spare took over a failed disk. This state is
						### where the hot-spare's data gets copied to the replaced drive, then
						### the old hot spare reverts again to being a hot spare.
						my $disk_icon    = "$conf->{url}{skins}/$conf->{sys}{skin}/images/hard-drive_128x128.png";
						my $id_led_url   = "?cluster=$conf->{cgi}{cluster}&node=$conf->{cgi}{node}&node_cluster_name=$conf->{cgi}{node_cluster_name}&task=display_health&do=start_id_disk&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter";
						my $say_identify = AN::Common::get_string($conf, {key => "button_0014"});
						#print "adapter: [$this_adapter], Disk: [$this_enclosure_device_id:$this_slot_number], Locator ID Status: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit}]\n";
						if ($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit})
						{
							$disk_icon    = "$conf->{url}{skins}/$conf->{sys}{skin}/images/hard-drive-with-led_128x128.png";
							$id_led_url   = "?cluster=$conf->{cgi}{cluster}&node=$conf->{cgi}{node}&node_cluster_name=$conf->{cgi}{node_cluster_name}&task=display_health&do=stop_id_disk&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter";
							$say_identify = AN::Common::get_string($conf, {key => "button_0015"});
						}
						# This needs to be last because if a drive is foreign,
						# we can't do anything else to it.
						my $foreign_state_class = "fixed_width_left";
						my $say_foreign_state   = "#!string!state_0013!#";
						if ($conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{foreign_state} eq "Foreign")
						{
							$foreign_state_class =  "highlight_warning_bold_fixed_width_left";
							$say_foreign_state   =  "#!string!state_0012!#";
							$say_disk_action     .= AN::Common::template($conf, "common.html", "new_line", "", "", 1);
							$say_disk_action     .= AN::Common::template($conf, "common.html", "enabled-button-no-class", {
								button_link	=>	"?cluster=$conf->{cgi}{cluster}&node=$conf->{cgi}{node}&node_cluster_name=$conf->{cgi}{node_cluster_name}&task=display_health&do=clear_foreign_state&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
								button_text	=>	"#!string!button_0038!#",
								id		=>	"clear_foreign_state_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
							}, "", 1);
						}
						
						# Finally, show the drive.
						my $title = AN::Common::get_string($conf, {key => "title_0022", variables => {
								slot_number		=>	$this_slot_number,
								enclosure_device_id	=>	$this_enclosure_device_id,
							}});
						$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_1} = "--" if not $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_1};
						print AN::Common::template($conf, "lsi-storage.html", "lsi-physical-disk-state", {
							title				=>	$title,
							id_led_url			=>	$id_led_url,
							disk_icon			=>	$disk_icon,
							model				=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{inquiry_data},
							wwn				=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{wwn},
							disk_state			=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state},
							foreign_state			=>	$say_foreign_state,
							foreign_state_class		=>	$foreign_state_class,
							disk_state_class		=>	$disk_state_class,
							disk_action			=>	$say_disk_action,
							temperature			=>	$say_temperature,
							id_led_url			=>	$id_led_url,
							identify			=>	$say_identify,
							device_type			=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{media_type},
							media_error_count		=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{media_error_count},
							other_error_count		=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{other_error_count},
							predictive_failure_count	=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{predictive_failure_count},
							raw_drive_size			=>	$say_raw_size,
							pd_type				=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{pd_type},
							device_speed			=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_speed},
							link_speed			=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{link_speed},
							sas_address_0			=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_0},
							sas_address_1			=>	$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_1},
							location_title			=>	$say_location_title,
							location_body			=>	$say_location_body,
							offline_button			=>	$offline_button,
						});
					}
				}
			}
		}
	}
	
	# Close the table.
	print AN::Common::template($conf, "lsi-storage.html", "lsi-adapter-health-footer");

	return(0);
}

# This determines what kind of storage the user has and then calls the
# appropriate function to gather the details.
sub get_storage_data
{
	my ($conf, $node) = @_;
	
	$conf->{storage}{is}{lsi}   = "";
	$conf->{storage}{is}{hp}    = "";
	$conf->{storage}{is}{mdadm} = "";
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		#shell_call	=>	"whereis MegaCli64 hpacucli mdadm",
		shell_call	=>	"whereis MegaCli64 hpacucli",
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /^(.*?):\s(.*)/)
		{
			my $program = $1;
			my $path    = $2;
			#print "program: [$program], path: [$path]\n";
			if ($program eq "MegaCli64")
			{
				$conf->{storage}{is}{lsi} = $path;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; storage::is::lsi: [$conf->{storage}{is}{lsi}]\n");
			}
			elsif ($program eq "hpacucli")
			{
				$conf->{storage}{is}{hp} = $path;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; storage::is::hp: [$conf->{storage}{is}{hp}]\n");
			}
			elsif ($program eq "mdadm")
			{
				### TODO: This is always installed... 
				### Check if any arrays are configured and drop this if none.
				$conf->{storage}{is}{mdadm} = $path;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; storage::is::mdadm: [$conf->{storage}{is}{mdadm}]\n");
			}
		}
	}
	
	# For now, only LSI is supported.
	if ($conf->{storage}{is}{lsi})
	{
		get_storage_data_lsi($conf, $node);
	}
	
	return(0);
}

# This uses the 'MegaCli64' program to gather information about the LSI-based
# storage of a node.
sub get_storage_data_lsi
{
	my ($conf, $node) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; get_storage_data_lsi(); node: [$node]\n");
	
	# This is used when recording all fields.
	my $this_adapter = "";
	
	# Each section's title has an opening and closing line of "==". This is
	# used to skip the first one.
	my $skip_equal_sign_bar = 0;
	
	# These are used to sort out fields from Hardware Info.
	my $in_hw_information = 0;
	my $in_settings       = 0;
	
	# This is used for sorting logical disk info.
	my $this_logical_disk = "";
	
	# These are used for sorting physical disks.
	my $this_enclosure_device_id = "";
	my $this_slot_number         = "";
	my $this_span                = "";
	my $this_arm                 = "";
	
	# Delete any old data.
	delete $conf->{storage}{lsi}{adapter};
	
	# This is set to 1 once all the discovered physical drives have been
	# found and their ID LED statuses set to '0'.
	my $initial_led_state_set = 0;
	
	# Now call.
	my $in_section     =  0;
	my $megacli64_path =  $conf->{storage}{is}{lsi};
	my $shell_call     =  "echo '==] Start adapter_info'; $megacli64_path AdpAllInfo aAll; ";
	   $shell_call     .= "echo '==] Start bbu_info'; $megacli64_path AdpBbuCmd aAll; ";
	   $shell_call     .= "echo '==] Start logical_disk_info'; $megacli64_path LDInfo Lall aAll; ";
	   $shell_call     .= "echo '==] Start physical_disk_info'; $megacli64_path PDList aAll; ";
	   $shell_call     .= "echo '==] Start pd_id_led_state'; $conf->{path}{grep} \"PD Locate\" /root/MegaSAS.log;";
	##AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"$shell_call",
	});
	##AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		next if not $line;
		if ($line =~ /==] Start (.*)/)
		{
			$in_section        = $1;
			$this_adapter      = "";
			$this_logical_disk = "";
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in_section: [$in_section], this_adapter: [$this_adapter], this_logical_disk: [$this_logical_disk]\n");
			next;
		}
		if ($in_section eq "adapter_info")
		{
			### TODO: Get the amount of cache allocated to 
			###       write-back vs. read caching and make it
			###       adjustable.
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in_section: [$in_section], line: [$line]\n");
			if ($line =~ /Adapter #(\d+)/)
			{
				$this_adapter = $1;
				next;
			}
			next if $this_adapter eq "";
			
			if (($skip_equal_sign_bar) && ($line =~ /^====/))
			{
				$skip_equal_sign_bar = 0;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter: [$conf->{storage}{lsi}{adapter}{$this_adapter}{product_name}], skip_equal_sign_bar: [$skip_equal_sign_bar]\n");
				next;
			}
			
			if ($line =~ /Product Name\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{product_name} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Controller Description: [$conf->{storage}{lsi}{adapter}{$this_adapter}{product_name}]\n");
			}
			
			# Hardware Configuration values.
			if ($line eq "HW Configuration")
			{
				$in_hw_information   = 1;
				$skip_equal_sign_bar = 1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter: [$conf->{storage}{lsi}{adapter}{$this_adapter}{product_name}], in_hw_information: [$in_hw_information], skip_equal_sign_bar: [$skip_equal_sign_bar]\n");
				next
			}
			elsif ($in_hw_information)
			{
				if ($line =~ /^====/)
				{
					$in_hw_information = 0;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter: [$conf->{storage}{lsi}{adapter}{$this_adapter}{product_name}], in_hw_information: [$in_hw_information]\n");
					next
				}
				elsif ($line =~ /Memory Size\s*:\s*(.*)/)
				{
					$conf->{storage}{lsi}{adapter}{$this_adapter}{cache_size} = $1;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Controller cache_size: [$conf->{storage}{lsi}{adapter}{$this_adapter}{cache_size}]\n");
				}
				elsif ($line =~ /BBU\s*:\s*(.*)/)
				{
					my $bbu_is = $1;
					$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu_is} = $bbu_is eq "Present" ? 1 : 0;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Controller BBU Present? [$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu_is} ($bbu_is)]\n");
				}
				elsif ($line =~ /Flash\s*:\s*(.*)/)
				{
					my $flash_is = $1;
					$conf->{storage}{lsi}{adapter}{$this_adapter}{flash_is} = $flash_is eq "Present" ? 1 : 0;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Controller Flash Present? [$conf->{storage}{lsi}{adapter}{$this_adapter}{flash_is} ($flash_is)]\n");
				}
			}
			
			# Settings.
			if ($line eq "Settings")
			{
				$in_settings         = 1;
				$skip_equal_sign_bar = 1;
				next
			}
			elsif ($in_hw_information)
			{
				if ($line =~ /^====/)
				{
					$in_settings = 0;
					next
				}
				elsif ($line =~ /Restore HotSpare on Insertion\s*:\s*(.*)/)
				{
					my $is_enabled = $1;
					$conf->{storage}{lsi}{adapter}{$this_adapter}{restore_hotspare_on_insertion} = $is_enabled eq "Enabled" ? 1 : 0;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Controller Restore HotSpare on Insertion: [$conf->{storage}{lsi}{adapter}{$this_adapter}{restore_hotspare_on_insertion} ($is_enabled)]\n");
				}
			}
		}
		elsif ($in_section eq "bbu_info")
		{
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in_section: [$in_section], line: [$line]\n");
			if ($line =~ /BBU status for Adapter\s*:\s*(\d+)/)
			{
				$this_adapter = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], BBU.\n");
				next;
			}
			next if $this_adapter eq "";
			
			if ($line =~ /BatteryType\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{type} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], BBU type: [$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{type}]\n");
			}
			elsif ($line =~ /Battery State\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{battery_state} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], BBU State: [$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{battery_state}]\n");
			}
			elsif ($line =~ /Learn Cycle Active\s*:\s*(.*)/)
			{
				my $learn_cycle_active = $1;
				$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{learn_cycle_active} = $learn_cycle_active eq "Yes" ? 1 : 0;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], BBU Learn Cycle Active: [$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{learn_cycle_active} ($learn_cycle_active)]\n");
			}
			elsif ($line =~ /Pack is about to fail & should be replaced\s*:\s*(.*)/)
			{
				my $replace_bbu = $1;
				$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{replace_bbu} = $replace_bbu eq "Yes" ? 1 : 0;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], BBU Should be replaced: [$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{replace_bbu} ($replace_bbu)]\n");
			}
			elsif ($line =~ /Design Capacity\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{design_capacity} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], BBU Design Capacity: [$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{design_capacity}]\n");
			}
			elsif ($line =~ /Remaining Capacity Alarm\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{remaining_capacity_alarm} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], BBU Remaining Capacity Alarm: [$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{remaining_capacity_alarm}]\n");
			}
			elsif ($line =~ /Cycle Count\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{cycle_count} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], BBU Cycle Count: [$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{cycle_count}]\n");
			}
			elsif ($line =~ /Next Learn time\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{next_learn_time} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], BBU Next Learn Time: [$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{next_learn_time}]\n");
			}
			elsif ($line =~ /Remaining Capacity\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{remaining_capacity} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], BBU Remaining Capacity: [$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{remaining_capacity}]\n");
			}
			elsif ($line =~ /Full Charge Capacity\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{full_capacity} = $1;
				##AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], BBU Full Capacity: [$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{full_capacity}]\n");
			}
			elsif ($line =~ /Manufacture Name\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{manufacture_name} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], BBU Manufactore Name: [$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{manufacture_name}]\n");
			}
			elsif ($line =~ /Pack energy\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{pack_energy} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Pack energy: [$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{pack_energy}]\n");
			}
			elsif ($line =~ /Capacitance\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{capacitance} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Capacitance: [$conf->{storage}{lsi}{adapter}{$this_adapter}{bbu}{capacitance}]\n");
			}
		}
		elsif ($in_section eq "logical_disk_info")
		{
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in_section: [$in_section], line: [$line]\n");
			if ($line =~ /Adapter (\d+) -- Virtual Drive Information/)
			{
				$this_adapter = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk.\n");
				next;
			}
			next if $this_adapter eq "";
			
			if ($line =~ /Virtual Drive: (\d+) \(Target Id: (\d+)\)/)
			{
				$this_logical_disk = $1;
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{target_id} = $2;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Target ID: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{target_id}]\n");
			}
			next if $this_logical_disk eq "";
			
			if ($line =~ /^Size\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{size} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Size: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{size}]\n");
			}
			elsif ($line =~ /State\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], State: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'}]\n");
				##AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], State: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'}]\n");
			}
			elsif ($line =~ /Current Cache Policy\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{current_cache_policy} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Current Cache Policy: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{current_cache_policy}]\n");
			}
			elsif ($line =~ /Bad Blocks Exist\s*:\s*(.*)/)
			{
				my $bad_blocks = $1;
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{bad_blocks_exist} = $bad_blocks eq "Yes" ? 1 : 0;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Bad Blocks Exist: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{bad_blocks_exist} ($bad_blocks)]\n");
			}
			elsif ($line =~ /Number Of Drives\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{number_of_drives} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Number of drives: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{number_of_drives}]\n");
			}
			elsif ($line =~ /Encryption Type\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{encryption_type} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Encryption Type: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{encryption_type}]\n");
			}
			elsif ($line =~ /Disk Cache Policy\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{disk_cache_policy} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Disk Cache Policy: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{disk_cache_policy}]\n");
			}
			elsif ($line =~ /Sector Size\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{sector_size} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Sector size: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{sector_size}]\n");
			}
			elsif ($line =~ /RAID Level\s*:\s*Primary-(\d+), Secondary-(\d+), RAID Level Qualifier-(\d+)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{primary_raid_level}   = $1;
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{secondary_raid_level} = $2;
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{raid_qualifier}       = $3;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Primary RAID level: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{primary_raid_level}]\n");
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Secondary RAID level: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{secondary_raid_level}]\n");
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], RAID Qualifier: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{raid_qualifier}]\n");
			}
		}
		elsif ($in_section eq "physical_disk_info")
		{
			### TODO: Confirm that 'Disk Group' in fact relates to
			###       the logical disk ID.
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in_section: [$in_section], line: [$line]\n");
			if ($line =~ /Adapter #(\d+)/)
			{
				$this_adapter = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Physical Disk.\n");
				next;
			}
			next if $this_adapter eq "";
			
			$this_logical_disk = "9999" if $this_logical_disk eq "";
			$this_span         = "9999" if $this_span         eq "";
			$this_arm          = "9999" if $this_arm          eq "";
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Disk Group: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number].\n");
			if ($line =~ /Enclosure Device ID\s*:\s*(\d+)/)
			{
				$this_enclosure_device_id = $1;
				# New device, clear the old logical disk, span and arm.
				$this_logical_disk = "";
				$this_span         = "";
				$this_arm          = "";
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Physical Disk, Encluse Device ID: [$this_enclosure_device_id].\n");
				next;
			}
			if ($line =~ /Slot Number\s*:\s*(\d+)/)
			{
				$this_slot_number = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Physical Disk, Slot Number: [$this_slot_number].\n");
				next;
			}
			#             Drive's position: DiskGroup: 0,     Span: 0,     Arm: 0
			if ($line =~ /Drive's position: DiskGroup: (\d+), Span: (\d+), Arm: (\d+)/)
			{
				$this_logical_disk = $1;
				$this_span         = $2;
				$this_arm          = $3;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Disk Group: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number].\n");
				next;
			}
			if (($line =~ /Enclosure position: N\/A/) && ($this_logical_disk eq ""))
			{
				# This is a disk not yet in any array.
				#$this_logical_disk = "9999";
				#$this_span         = "9999";
				#$this_arm          = "9999";
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Disk Group: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number].\n");
				next;
			}
			next if (($this_enclosure_device_id eq "") or ($this_slot_number eq "") or ($this_logical_disk eq ""));
			
			if (not exists $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{span})
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{span} = $this_span;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Disk Group: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], this_span: [$this_span].\n");
			}
			if (not exists $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{arm})
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{arm} = $this_arm;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Disk Group: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], this_arm: [$this_arm].\n");
			}
			
			# Record the slot number.
			if ($line =~ /Device Id\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_id} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Device ID: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_id}].\n");
			}
			elsif ($line =~ /WWN\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{wwn} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], World Wide Number: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{wwn}].\n");
			}
			elsif ($line =~ /Sequence Number\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sequence_number} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Sequence Number: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sequence_number}].\n");
			}
			elsif ($line =~ /Media Error Count\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{media_error_count} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Media Error Count: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{media_error_count}].\n");
			}
			elsif ($line =~ /Other Error Count\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{other_error_count} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Other Error Count: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{other_error_count}].\n");
			}
			elsif ($line =~ /Predictive Failure Count\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{predictive_failure_count} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Predictive Failure Count: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{predictive_failure_count}].\n");
			}
			elsif ($line =~ /PD Type\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{pd_type} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Physical Disk Type: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{pd_type}].\n");
			}
			elsif ($line =~ /Raw Size: .*? \[0x(.*?) Sectors\]/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{raw_sector_count_in_hex} = "0x".$1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Raw Sector Count in Hex: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{raw_sector_count_in_hex}].\n");
			}
			elsif ($line =~ /Sector Size\s*:\s*(.*)/)
			{
				# NOTE: Some drives report 0. If this is the
				#       case, we'll use the logical disk sector
				#       size, if available. If not, we'll 
				#       assume 512 bytes.
				my $sector_size = $1;
				if (not $sector_size)
				{
					$sector_size = $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{sector_size} ? $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{sector_size} : 512;
				}
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sector_size} = $sector_size ? $sector_size : 512;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Sector Size: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sector_size}].\n");
			}
			elsif ($line =~ /Firmware state\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Firmware-Reported State: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state}].\n");
			}
			elsif ($line =~ /SAS Address\(0\)\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_0} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], SAS Address, Port #0: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_0}].\n");
			}
			elsif ($line =~ /SAS Address\(1\)\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_1} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], SAS Address, Port #1: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_1}].\n");
			}
			elsif ($line =~ /Connected Port Number\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{connected_port_number} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Connected Port Number: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{connected_port_number}].\n");
			}
			elsif ($line =~ /Inquiry Data\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{inquiry_data} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Drive Data: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{inquiry_data}].\n");
			}
			elsif ($line =~ /Device Speed\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_speed} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Device Speed: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_speed}].\n");
			}
			elsif ($line =~ /Link Speed\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{link_speed} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Link Speed: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{link_speed}].\n");
			}
			elsif ($line =~ /Media Type\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{media_type} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Media Type: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{media_type}].\n");
			}
			elsif ($line =~ /Foreign State\s*:\s*(.*)/)
			{
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{foreign_state} = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Foreign State: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{foreign_state}].\n");
			}
			elsif ($line =~ /Drive Temperature\s*:\s*(\d+)C \((.*?) F\)/)
			{
				my $temp_c = $1;
				my $temp_f = $2;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; temp_c: [$temp_c], temp_f: [$temp_f]\n");
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_c} = $temp_c;
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_f} = $temp_f;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Drive Temperature (*C): [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_c}].\n");
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], Drive Temperature (*F): [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_f}].\n");
			}
			elsif ($line =~ /Drive has flagged a S.M.A.R.T alert\s*:\s*(.*)/)
			{
				my $alert = $1;
				$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{smart_alert} = $alert eq "Yes" ? 1 : 0;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], SMART Alert: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{smart_alert} ($alert)].\n");
			}
		}
		elsif ($in_section eq "pd_id_led_state")
		{
			### TODO: Verify this catches/tracks unconfigured PDs.
			# Assume all physical drives have their ID LEDs off.
			# Not great, but there is no way to check the state
			# directly.
			if (not $initial_led_state_set)
			{
				$initial_led_state_set = 1;
				foreach my $this_adapter (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}})
				{
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LSI Adapter number: [$this_adapter]\n");
					foreach my $this_logical_disk (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}})
					{
						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; - Logical Disk: [$this_logical_disk]\n");
						foreach my $this_enclosure_device_id (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}})
						{
							#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";    - Enclosure Device ID: [$this_enclosure_device_id]\n");
							foreach my $this_slot_number (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}})
							{
								#print __LINE__.";      - Slot ID: [$this_slot_number]\n");
								$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit} = 0;
								#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";        - LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], id_led_lit: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit}]\n");
							}
						}
					}
				}
			}
			   $line                     = lc($line);
			   $this_adapter             = "";
			   $this_logical_disk        = "";
			   $this_enclosure_device_id = "";
			   $this_slot_number         = "";
			my $this_action              = "";
			my $set_state                = "";
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; this_adapter: [$this_adapter], this_logical_disk: [$this_logical_disk], this_enclosure_device_id: [$this_enclosure_device_id], this_slot_number: [$this_slot_number], this_action: [$this_action], set_state: [$set_state]\n");
			if ($line =~ /adapter: (\d+): device at enclid-(\d+) slotid-(\d+) -- pd locate (.*?) command was successfully sent to firmware/)
			{
				$this_adapter             = $1;
				$this_enclosure_device_id = $2;
				$this_slot_number         = $3;
				$this_action              = $4;
				$set_state                = $this_action eq "start" ? 1 : 0;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; - this_adapter: [$this_adapter], this_logical_disk: [$this_logical_disk], this_enclosure_device_id: [$this_enclosure_device_id], this_slot_number: [$this_slot_number], this_action: [$this_action], set_state: [$set_state]\n");
				
				# the log doesn't reference the disk's logic
				# drive, so we loop through all looking for a
				# match.
				foreach my $this_adapter (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}})
				{
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Adapter: [$this_adapter]\n");
					foreach my $this_logical_disk (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}})
					{
						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";   - Adapter: [$this_logical_disk], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number]\n");
						if (exists $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number})
						{
							$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit} = $set_state;
							#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";     - Exists\n");
							#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";     - Set State: LSI Adapter number: [$this_adapter], Logical Disk: [$this_logical_disk], Enclosure Device ID: [$this_enclosure_device_id], Slot Number: [$this_slot_number], id_led_lit: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit}]\n");
							last;
						}
						else
						{
							#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";     - Doesn't exist.\n");
						}
					}
				}
			}
		}
		else
		{
			die "$THIS_FILE ".__LINE__."; unknown section!, line: [$line]\n";
		}
	}
	
	# This is purely debug to show the status of the drive LEDs.
	foreach my $this_adapter (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}})
	{
		foreach my $this_logical_disk (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}})
		{
			foreach my $this_enclosure_device_id (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}})
			{
				foreach my $this_slot_number (sort {$a cmp $b} keys %{$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}})
				{
					if (exists $conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit})
					{
						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; adapter: [$this_adapter], Logical Disk: [$this_logical_disk], Disk Address: [$this_enclosure_device_id:$this_slot_number], Locator ID Status: [$conf->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit}]<br />\n");
					}
				}
			}
		}
	}
	
	return(0);
}

# This changes the amount of RAM or the number of CPUs allocated to a VM.
sub change_vm
{
	my ($conf, $node) = @_;
	
	my $cluster             = $conf->{cgi}{cluster};
	my $vm                  = $conf->{cgi}{vm};
	my $say_vm              = ($vm =~ /vm:(.*)/)[0];
	my $node1               = $conf->{clusters}{$cluster}{nodes}[0];
	my $node2               = $conf->{clusters}{$cluster}{nodes}[1];
	my $device              = $conf->{cgi}{device};
	my $definition_file     = "/shared/definitions/$say_vm.xml";
	my $other_allocated_ram = $conf->{resources}{allocated_ram} - $conf->{vm}{$vm}{details}{ram};
	
	# Read the values the user passed, see if they differ from what
	# was read in the config and, if they do differ, make sure the
	# requested resources are available. If all this passes, 
	# rewrite the definition file and tell the user to stop/start
	# their server for the changes to take effect.
	my $current_ram           =  $conf->{vm}{$vm}{details}{ram};
	my $available_ram         =  ($conf->{resources}{total_ram} - $conf->{sys}{unusable_ram} - $conf->{resources}{allocated_ram}) + $current_ram;
	   $current_ram           /= 1024;
	my $requested_ram         =  AN::Cluster::hr_to_bytes($conf, $conf->{cgi}{ram}, $conf->{cgi}{ram_suffix}, 1);
	   $requested_ram         /= 1024;
	my $max_ram               =  $available_ram / 1024;
	my $current_cpus          =  $conf->{vm}{$vm}{details}{cpu_count};
	my $requested_cpus        =  $conf->{cgi}{cpu_cores};
	my $current_boot_device   =  $conf->{vm}{$vm}{current_boot_device};
	my $requested_boot_device =  $conf->{cgi}{boot_device};
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm]\n");
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; - requested RAM:          [$requested_ram]\n");
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; - current RAM:            [$current_ram]\n");
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; - requested CPUs: [$requested_cpus]\n");
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; - current CPUs:   [$current_cpus]\n");
	
	# Open the table.
	my $title = AN::Common::get_string($conf, {key => "title_0023", variables => {
			server	=>	$say_vm,
		}});
	print AN::Common::template($conf, "server.html", "update-server-config-header", {
		title	=>	$title,
	});

	# Make sure something changed.
	if (
		($current_ram         ne $requested_ram)         || 
		($current_cpus        ne $requested_cpus)        || 
		($current_boot_device ne $requested_boot_device)
	)
	{
		# Something has changed. Make sure the request is sane,
		my $max_cpus      = $conf->{resources}{total_threads};
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; requested ram:    [$requested_ram]\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";       max ram:    [$max_ram]\n");
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; requested cpus:   [$requested_cpus]\n");
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";       max cpus:   [$max_cpus]\n");
		if ($requested_ram > $max_ram)
		{
			# Not enough RAM
			my $say_requested_ram = AN::Cluster::bytes_to_hr($conf, ($requested_ram * 1024));
			my $say_max_ram       = AN::Cluster::bytes_to_hr($conf, ($max_ram * 1024));
			my $message = AN::Common::get_string($conf, {key => "message_0059", variables => {
				requested_ram	=>	$title,
				max_ram		=>	$say_requested_ram,
			}});
			print AN::Common::template($conf, "server.html", "update-server-error-message", {
				title		=>	"#!string!title_0025!",
				message		=>	$message,
			});
		}
		elsif ($requested_cpus > $max_cpus)
		{
			# Not enough CPUs
			my $message = AN::Common::get_string($conf, {key => "message_0060", variables => {
				requested_cpus	=>	$requested_cpus,
				max_cpus	=>	$max_cpus,
			}});
			print AN::Common::template($conf, "server.html", "update-server-error-message", {
				title		=>	"#!string!title_0026!",
				message		=>	$message,
			});
		}
		else
		{
			# Request is sane. Archive the current definition.
			my ($backup) = archive_file($conf, $node, $definition_file, 1);
			
			# Make the boot device easier to understand.
			my $say_requested_boot_device = $requested_boot_device;
			if ($requested_boot_device eq "hd")
			{
				$say_requested_boot_device = "Hard drive";
			}
			elsif ($requested_boot_device eq "cdrom")
			{
				$say_requested_boot_device = "Optical drive";
			}
			
			# Rewrite the XML file.
			print AN::Common::get_string($conf, {key => "message_0061", variables => {
				ram			=>	$conf->{cgi}{ram},
				ram_suffix		=>	$conf->{cgi}{ram_suffix},
				requested_cpus		=>	$requested_cpus,
				requested_boot_device	=>	$say_requested_boot_device,
			}});
			my $new_definition = "";
			my $in_os          = 0;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
			my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
				node		=>	$node,
				port		=>	$conf->{node}{$node}{port},
				user		=>	"root",
				password	=>	$conf->{sys}{root_password},
				ssh_fh		=>	"",
				'close'		=>	0,
				shell_call	=>	"cat $definition_file",
			});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
			foreach my $line (@{$output})
			{
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], line: [$line]\n");
				if ($line =~ /^(.*?)<memory>\d+<\/memory>/)
				{
					my $prefix = $1;
					$line = "${prefix}<memory>$requested_ram<\/memory>";
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Changed line:    [$line]\n");
				}
				if ($line =~ /^(.*?)<memory unit='.*?'>\d+<\/memory>/)
				{
					my $prefix = $1;
					$line = "${prefix}<memory unit='KiB'>$requested_ram<\/memory>";
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Changed line:    [$line]\n");
				}
				if ($line =~ /^(.*?)<currentMemory>\d+<\/currentMemory>/)
				{
					my $prefix = $1;
					$line = "${prefix}<currentMemory>$requested_ram<\/currentMemory>";
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Changed line:    [$line]\n");
				}
				if ($line =~ /^(.*?)<currentMemory unit='.*?'>\d+<\/currentMemory>/)
				{
					my $prefix = $1;
					$line = "${prefix}<currentMemory unit='KiB'>$requested_ram<\/currentMemory>";
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Changed line:    [$line]\n");
				}
				if ($line =~ /^(.*?)<vcpu>(\d+)<\/vcpu>/)
				{
					my $prefix = $1;
					$line = "${prefix}<vcpu>$requested_cpus<\/vcpu>";
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Changed line:    [$line]\n");
				}
				if ($line =~ /^(.*?)<vcpu placement='(.*?)'>(\d+)<\/vcpu>/)
				{
					my $prefix    = $1;
					my $placement = $2;
					$line = "${prefix}<vcpu placement='$placement'>$requested_cpus<\/vcpu>";
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Changed line:    [$line]\n");
				}
				if ($line =~ /<os>/)
				{
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], going into the OS block.\n");
					$in_os          =  1;
					$new_definition .= "$line\n";
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], Adding line: [$line].\n");
					next;
				}
				if ($in_os)
				{
					my $boot_menu_exists = 0;
					if ($line =~ /<\/os>/)
					{
						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], exiting the OS block.\n");
						$in_os          =  0;
						# Write out the new list of boot devices. Start with the
						# requested boot device and then loop through the rest.
						$new_definition .= "    <boot dev='$requested_boot_device'/>\n";
						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], Adding initiall boot device: [$requested_boot_device]\n");
						foreach my $device (split /,/, $conf->{vm}{$vm}{available_boot_devices})
						{
							next if $device eq $requested_boot_device;
							$new_definition .= "    <boot dev='$device'/>\n";
							#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], Adding device: [$device] to boot list\n");
						}
						
						# Cap off with the command to enable the boot prompt
						if (not $boot_menu_exists)
						{
							$new_definition .= "    <bootmenu enable='yes'/>\n";
						}
						
						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], Adding line: [$line].\n");
						$new_definition .= "$line\n";
						next;
					}
					elsif ($line =~ /<bootmenu enable=/)
					{
						$new_definition   .= "$line\n";
						$boot_menu_exists =  1;
					}
					elsif ($line !~ /<boot dev/)
					{
						$new_definition .= "$line\n";
						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], Adding to 'os' element line: [$line].\n");
						next;
					}
				}
				else
				{
					$new_definition .= "$line\n";
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], Adding line: [$line].\n");
				}
			}
			$new_definition =~ s/(\S)\s+$/$1\n/;
			$conf->{vm}{$vm}{available_boot_devices} =~ s/,$//;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; new definition: [$new_definition]\n");
			
			# Write the new definition file.
			($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
				node		=>	$node,
				port		=>	$conf->{node}{$node}{port},
				user		=>	"root",
				password	=>	$conf->{sys}{root_password},
				ssh_fh		=>	$ssh_fh,
				'close'		=>	1,
				shell_call	=>	"echo \"$new_definition\" > $definition_file && chmod 644 $definition_file",
			});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
			foreach my $line (@{$output})
			{
				print AN::Common::template($conf, "common.html", "shell-call-output", {
					line	=>	$line,
				});
			}
			
			# Wipe and re-read the definition file's XML and reset
			# the amount of RAM and the number of CPUs allocated
			# to this machine.
			$conf->{vm}{$vm}{xml}                = [];	# this is probably redundant
			@{$conf->{vm}{$vm}{xml}}             = split/\n/, $new_definition;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; requested_ram: [$requested_ram KiB (".AN::Cluster::bytes_to_hr($conf, ($requested_ram * 1024)).")], vm::${vm}::details::ram: [$conf->{vm}{$vm}{details}{ram}]\n");
			$conf->{vm}{$vm}{details}{ram}       = ($requested_ram * 1024);
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm::${vm}::details::ram: [$conf->{vm}{$vm}{details}{ram}]\n");
			$conf->{resources}{allocated_ram}    = $other_allocated_ram + ($requested_ram * 1024);
			$conf->{vm}{$vm}{details}{cpu_count} = $requested_cpus;
			
			# If the server is running, tell the user they need to
			# power it off.
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; host: [$conf->{vm}{$vm}{current_host}]<br />\n");
			if ($conf->{vm}{$vm}{current_host})
			{
				print AN::Common::template($conf, "server.html", "server-poweroff-required-message");
			}
			print AN::Common::template($conf, "server.html", "update-server-config-footer", {
				url	=>	"?cluster=$conf->{cgi}{cluster}&vm=$conf->{cgi}{vm}&task=manage_vm",
			});

			AN::Cluster::footer($conf);
			exit(0);
		}
	}
	else
	{
		# Nothing changed.
		print AN::Common::template($conf, "server.html", "no-change-message");
	}
	
	return (0);
}

# This inserts an ISO into the server's virtual optical drive.
sub vm_insert_media
{
	my ($conf, $node, $insert_media, $insert_drive, $vm_is_running) = @_;
	
	my $cluster         = $conf->{cgi}{cluster};
	my $vm              = $conf->{cgi}{vm};
	my $say_vm          = ($vm =~ /vm:(.*)/)[0];
	my $node1           = $conf->{clusters}{$cluster}{nodes}[0];
	my $node2           = $conf->{clusters}{$cluster}{nodes}[1];
	my $device          = $conf->{cgi}{device};
	my $definition_file = "/shared/definitions/$say_vm.xml";

	# Archive the current config, just in case.
	my ($backup)   = archive_file($conf, $node, $definition_file, 1);
	
	# The variables hash feeds into 'title_0030'.
	print AN::Common::template($conf, "server.html", "insert-media-header", {}, {
		media	=>	$insert_media,
		drive	=>	$insert_drive,
	});
	
	# How I do this depends on whether the VM is running or not.
	if ($vm_is_running)
	{
		# It is, so I will use 'virsh'.
		my $virsh_exit_code;
		my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	1,
			shell_call	=>	"/usr/bin/virsh change-media $say_vm $insert_drive --insert '/shared/files/$insert_media'; echo virsh:\$?",
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			next if not $line;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], line: [$line]\n");
			if ($line =~ /virsh:(\d+)/)
			{
				$virsh_exit_code = $1;
			}
			else
			{
				print AN::Common::template($conf, "common.html", "shell-call-output", {
					line	=>	$line,
				});
			}
		}
		if ($virsh_exit_code eq "1")
		{
			# Disk already inserted.
			print AN::Common::template($conf, "server.html", "insert-media-failed-already-mounted");

			# Update the definition file in case it was missed by .
			update_vm_definition($conf, $node, $vm);
		}
		elsif ($virsh_exit_code eq "0")
		{
			print AN::Common::template($conf, "server.html", "insert-media-success");

			# Update the definition file.
			update_vm_definition($conf, $node, $vm);
		}
		else
		{
			$virsh_exit_code = "-" if not defined $virsh_exit_code;
			my $say_error = AN::Common::get_string($conf, {key => "message_0069", variables => {
				media		=>	$insert_media,
				drive		=>	$insert_drive,
				virsh_exit_code	=>	$virsh_exit_code,
			}});
			print AN::Common::template($conf, "server.html", "insert-media-failed-bad-exit-code", {
				error	=>	$say_error,
			});
		}
	}
	else
	{
		# The VM isn't running. Directly re-write the XML file.
		# The variable hash feeds into 'message_0070'.
		print AN::Common::template($conf, "server.html", "insert-media-server-off", {}, {
			server	=>	$say_vm,
		});
		my $new_definition = "";
		my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	"cat $definition_file",
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /dev='(.*?)'/)
			{
				my $this_device = $1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Found the device: [$this_device].\n");
				if ($this_device eq $insert_drive)
				{
					$new_definition .= "      <source file='/shared/files/$insert_media'/>\n";
				}
			}
			$new_definition .= "$line\n";
		}
		$new_definition =~ s/(\S)\s+$/$1\n/;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; new definition: [$new_definition]\n");
		
		# Write the new definition file.
		print AN::Common::template($conf, "server.html", "saving-server-config");
		($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	1,
			shell_call	=>	"echo \"$new_definition\" > $definition_file && chmod 644 $definition_file",
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			print AN::Common::template($conf, "common.html", "shell-call-output", {
				line	=>	$line,
			});
		}
		print AN::Common::template($conf, "server.html", "insert-media-footer");
		
		# Lastly, copy the new definition to the stored XML for
		# this VM.
		$conf->{vm}{$vm}{xml}    = [];	# this is probably redundant
		@{$conf->{vm}{$vm}{xml}} = split/\n/, $new_definition;
	}
	
	return(0);
}

# This ejects an ISO from a server's virtual optical drive.
sub vm_eject_media
{
	my ($conf, $node, $vm_is_running) = @_;
	
	my $cluster         = $conf->{cgi}{cluster};
	my $vm              = $conf->{cgi}{vm};
	my $say_vm          = ($vm =~ /vm:(.*)/)[0];
	my $node1           = $conf->{clusters}{$cluster}{nodes}[0];
	my $node2           = $conf->{clusters}{$cluster}{nodes}[1];
	my $device          = $conf->{cgi}{device};
	my $definition_file = "/shared/definitions/$say_vm.xml";
	
	# The variables hash feeds into 'title_0031'.
	print AN::Common::template($conf, "server.html", "eject-media-header", {}, {
		device	=>	$conf->{cgi}{device},
	});
	
	# Archive the current config, just in case.
	my ($backup) = archive_file($conf, $node, $definition_file, 1);
	my $drive    = $conf->{cgi}{device};
	
	# How I do this depends on whether the VM is running or not.
	if ($vm_is_running)
	{
		# It is, so I will use 'virsh'.
		my $virsh_exit_code;
		my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	1,
			shell_call	=>	"/usr/bin/virsh change-media $say_vm $conf->{cgi}{device} --eject; echo virsh:\$?",
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			next if not $line;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], line: [$line]\n");
			if ($line =~ /virsh:(\d+)/)
			{
				$virsh_exit_code = $1;
			}
			else
			{
				print AN::Common::template($conf, "common.html", "shell-call-output", {
					line	=>	$line,
				});
			}
		}
		if ($virsh_exit_code eq "1")
		{
			# Someone already ejected it.
			print AN::Common::template($conf, "server.html", "eject-media-failed-already-ejected");
			
			# Update the definition file in case it was missed by .
			update_vm_definition($conf, $node, $vm);
		}
		elsif ($virsh_exit_code eq "0")
		{
			print AN::Common::template($conf, "server.html", "eject-media-success");
			
			# Update the definition file.
			update_vm_definition($conf, $node, $vm);
		}
		else
		{
			$virsh_exit_code = "-" if not defined $virsh_exit_code;
			my $say_error = AN::Common::get_string($conf, {key => "message_0073", variables => {
				drive		=>	$drive,
				virsh_exit_code	=>	$virsh_exit_code,
			}});
			print AN::Common::template($conf, "server.html", "eject-media-failed-bad-exit-code", {
				error	=>	$say_error,
			});
		}
	}
	else
	{
		# The VM isn't running. Directly re-write the XML file.
		# The variable hash feeds into 'message_0070'.
		print AN::Common::template($conf, "server.html", "eject-media-server-off", {}, {
			server	=>	$say_vm,
		});
		my $in_cdrom       = 0;
		my $this_media     = "";
		my $this_device    = "";
		my $new_definition = "";
		my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	"cat $definition_file",
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			$new_definition .= "$line\n";
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if (($line =~ /type='file'/) && ($line =~ /device='cdrom'/))
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Found a cdrom disk.\n");
				$in_cdrom = 1;
			}
			if ($in_cdrom)
			{
				if ($line =~ /file='(.*?)'\/>/)
				{
					$this_media = $1;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Found the media: [$this_media].\n");
				}
				if ($line =~ /dev='(.*?)'/)
				{
					$this_device = $1;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Found the device: [$this_device].\n");
				}
				if ($line =~ /<\/disk>/)
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Checking if: [$this_device] is the device: [$conf->{cgi}{device}] I want to eject...\n");
					if ($this_device eq $conf->{cgi}{device})
					{
						# This is the device I want to unmount.
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; It is!\n");
						$new_definition =~ s/<disk(.*?)device='cdrom'(.*?)<source file='$this_media'\/>\s+(.*?)<\/disk>/<disk${1}device='cdrom'${2}${3}<\/disk>/s;
					}
					else
					{
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; It is not.\n");
					}
					$in_cdrom    = 0;
					$this_device = "";
					$this_media  = "";
				}
			}
		}
		$new_definition =~ s/(\S)\s+$/$1\n/;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; new definition: [$new_definition]\n");
		
		# Write the new definition file.
		print AN::Common::template($conf, "server.html", "saving-server-config");
		($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	$ssh_fh,
			'close'		=>	1,
			shell_call	=>	"echo \"$new_definition\" > $definition_file && chmod 644 $definition_file",
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			print AN::Common::template($conf, "common.html", "shell-call-output", {
				line	=>	$line,
			});
		}
		print AN::Common::template($conf, "server.html", "eject-media-footer");

		# Lastly, copy the new definition to the stored XML for
		# this VM.
		$conf->{vm}{$vm}{xml}    = [];	# this is probably redundant
		@{$conf->{vm}{$vm}{xml}} = split/\n/, $new_definition;
	}
	
	return(0);
}

# This shows or changes the configuration of the VM, including mounted media.
sub manage_vm
{
	my ($conf) = @_;
	
	# I need to get a list of the running VM's resource/media, read the VM's current XML if it's up, 
	# otherwise read the stored XML, read the available ISOs and then display everything in a form. If
	# the user submits the form and something is different, re-write the stored config and, if possible,
	# make the required changes immediately.
	my $cluster         = $conf->{cgi}{cluster};
	my $vm              = $conf->{cgi}{vm};
	my $say_vm          = ($vm =~ /vm:(.*)/)[0];
	my $node1           = $conf->{clusters}{$cluster}{nodes}[0];
	my $node2           = $conf->{clusters}{$cluster}{nodes}[1];
	my $device          = $conf->{cgi}{device};
	my $definition_file = "/shared/definitions/$say_vm.xml";
	
	# First, see if the VM is up.
	AN::Cluster::scan_cluster($conf);
	
	# Count how much RAM and CPU cores have been allocated.
	$conf->{resources}{available_ram}   = 0;
	$conf->{resources}{max_cpu_cores}   = 0;
	$conf->{resources}{allocated_cores} = 0;
	$conf->{resources}{allocated_ram}   = 0;
	foreach my $vm (sort {$a cmp $b} keys %{$conf->{vm}})
	{
		next if $vm !~ /^vm/;
		# I check GFS2 because, without it, I can't read the VM's details.
		if ($conf->{sys}{gfs2_down})
		{
			$conf->{resources}{allocated_ram}   = "--";
			$conf->{resources}{allocated_cores} = "--";
		}
		else
		{
			$conf->{resources}{allocated_ram}   += $conf->{vm}{$vm}{details}{ram};
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; allocated_ram: [$conf->{resources}{allocated_ram}], vm: [$vm], ram: [$conf->{vm}{$vm}{details}{ram}]\n");
			$conf->{resources}{allocated_cores} += $conf->{vm}{$vm}{details}{cpu_count};
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; allocated_cores: [$conf->{resources}{allocated_cores}], vm: [$vm], cpu_count: [$conf->{vm}{$vm}{details}{cpu_count}]\n");
		}
	}
	
	# First up, if the cluster is not running, go no further.
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node1}::daemon::gfs2::exit_code: [$conf->{node}{$node1}{daemon}{gfs2}{exit_code}], node::${node2}::daemon::gfs2::exit_code: [$conf->{node}{$node2}{daemon}{gfs2}{exit_code}]\n");
	if (($conf->{node}{$node1}{daemon}{gfs2}{exit_code}) && ($conf->{node}{$node2}{daemon}{gfs2}{exit_code}))
	{
		print AN::Common::template($conf, "server.html", "storage-not-ready");
	}
	
	# Now choose the node to work through.
	my $node          = "";
	my $vm_is_running = 0;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm::${vm}::current_host: [$conf->{vm}{$vm}{current_host}]\n");
	if ($conf->{vm}{$vm}{current_host})
	{
		# Read the current VM config from virsh.
		$vm_is_running = 1;
		$node          = $conf->{vm}{$vm}{current_host};
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm] is running on: [$node], will read: [$conf->{vm}{$vm}{definition_file}].\n");
	}
	else
	{
		# The VM isn't running.
		if ($conf->{node}{$node1}{daemon}{gfs2}{exit_code} eq "0")
		{
			# Node 1 is up.
			$node = $node1;
		}
		else
		{
			# Node 2 must be up.
			$node = $node2;
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm] is not running, will read: [$conf->{vm}{$vm}{definition_file}] via: [$node].\n");
		read_vm_definition($conf, $node, $vm);
	}
	
	# Find the list of bootable devices and present them in a selection box.
	my $boot_select = "<select name=\"boot_device\" style=\"width: 165px;\">";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; boot select: [$boot_select].\n");
	$conf->{vm}{$vm}{current_boot_device}    = "";
	$conf->{vm}{$vm}{available_boot_devices} = "";
	my $say_current_boot_device              = "";
	my $in_os                                = 0;
	my $saw_cdrom                            = 0;
	foreach my $line (@{$conf->{vm}{$vm}{xml}})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in_os: [$in_os] vm: [$vm], xml line: [$line].\n");
		last if $line =~ /<\/domain>/;
		
		if ($line =~ /<os>/)
		{
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], going into the OS block.\n");
			$in_os = 1;
			next;
		}
		if ($in_os == 1)
		{
			if ($line =~ /<\/os>/)
			{
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], exiting the OS block.\n");
				$in_os = 0;
				if ($saw_cdrom)
				{
					last;
				}
				else
				{
					# I didn't see a CD-ROM boot option, so
					# keep looking.
					$in_os = 2;
				}
			}
			elsif ($line =~ /<boot dev='(.*?)'/)
			{
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], OS boot line: [$line].\n");
				my $device                               =  $1;
				my $say_device                           =  $device;
				$conf->{vm}{$vm}{available_boot_devices} .= "$device,";
				if ($device eq "hd")
				{
					$say_device = "#!string!device_0001!#";
				}
				elsif ($device eq "cdrom")
				{
					$say_device = "#!string!device_0002!#";
					$saw_cdrom  = 1;
				}
				
				my $selected = "";
				if (not $conf->{vm}{$vm}{current_boot_device})
				{
					$conf->{vm}{$vm}{current_boot_device} = $device;
					$say_current_boot_device = $say_device;
					$selected = "selected";
				}
				
				$boot_select .= "<option value=\"$device\" $selected>$say_device</option>";
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; boot select: [$boot_select].\n");
			}
		}
		elsif ($in_os == 2)
		{
			# I'm out of the OS block, but I haven't seen a CD-ROM
			# yet, so keep looping and looking for one.
			if ($line =~ /<disk .*?device='cdrom'/)
			{
				# There is a CD-ROM, add it as a boot option.
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], Found a CDROM drive, adding it as a boot option.\n");
				my $say_device  =  "#!string!device_0002!#";
				   $boot_select .= "<option value=\"cdrom\">$say_device</option>";
				   $in_os = 0;
				last;
			}
		}
	}
	$boot_select .= "</select>";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; boot select: [$boot_select].\n");
	
	# If I need to change the number of CPUs or the amount of RAM, do so now.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::change: [$conf->{cgi}{change}].\n");
	if ($conf->{cgi}{change})
	{
		change_vm($conf, $node);
	}
	
	# If I've been asked to insert a disc, do so now.
	my $do_insert    = 0;
	my $insert_media = "";
	my $insert_drive = "";
	foreach my $key (split/,/, $conf->{cgi}{device_keys})
	{
		next if not $key;
		next if not $conf->{cgi}{$key};
		my $device_key = $key;
		$insert_drive  = ($key =~ /media_(.*)/)[0];
		my $insert_key = "insert_${insert_drive}";
		if ($conf->{cgi}{$insert_key})
		{
			$do_insert    = 1;
			$insert_media = $conf->{cgi}{$device_key};
		}
	}
	
	### TODO: Merge insert and eject into one function.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; do_insert: [$do_insert], insert_drive: [$insert_drive], insert_media: [$insert_media]\n");
	if ($do_insert)
	{
		vm_insert_media($conf, $node, $insert_media, $insert_drive, $vm_is_running);
	}
	
	# If I've been asked to eject a disc, do so now.
	if ($conf->{cgi}{'do'} eq "eject")
	{
		vm_eject_media($conf, $node, $vm_is_running);
	}
	
	# Get the list of files on the /shared/files/ directory.
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"df -P && ls -l /shared/files/",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], line: [$line]\n");
		if ($line =~ /\s(\d+)-blocks\s/)
		{
			$conf->{partition}{shared}{block_size} = $1;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; block_size: [$conf->{partition}{shared}{block_size}]\n");
		}
		elsif ($line =~ /^\/.*?\s+(\d+)\s+(\d+)\s+(\d+)\s(\d+)%\s+\/shared/)
		{
			$conf->{partition}{shared}{total_space}  = $1;
			$conf->{partition}{shared}{used_space}   = $2;
			$conf->{partition}{shared}{free_space}   = $3;
			$conf->{partition}{shared}{used_percent} = $4;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; total_space: [$conf->{partition}{shared}{total_space}], used_space: [$conf->{partition}{shared}{used_space} / $conf->{partition}{shared}{used_percent}%], free_space: [$conf->{partition}{shared}{free_space}]\n");
		}
		elsif ($line =~ /^(\S)(\S+)\s+\d+\s+(\S+)\s+(\S+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\S+)\s+(.*)$/)
		{
			my $type   = $1;
			my $mode   = $2;
			my $user   = $3;
			my $group  = $4;
			my $size   = $5;
			my $month  = $6;
			my $day    = $7;
			my $time   = $8; # might be a year, look for '\d+:\d+'.
			my $file   = $9;
			my $target = "";
			if ($type eq "l")
			{
				# It's a symlink, strip off the destination.
				($file, $target) = ($file =~ /^(.*?) -> (.*)$/);
			}
			$conf->{files}{shared}{$file}{type}   = $type;
			$conf->{files}{shared}{$file}{mode}   = $mode;
			$conf->{files}{shared}{$file}{user}   = $user;
			$conf->{files}{shared}{$file}{group}  = $group;
			$conf->{files}{shared}{$file}{size}   = $size;
			$conf->{files}{shared}{$file}{month}  = $month;
			$conf->{files}{shared}{$file}{day}    = $day;
			$conf->{files}{shared}{$file}{'time'} = $time; # might be a year, look for '\d+:\d+'.
			$conf->{files}{shared}{$file}{target} = $target;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; file: [$file], mode: [$conf->{files}{shared}{$file}{type}, $conf->{files}{shared}{$file}{mode}], owner: [$conf->{files}{shared}{$file}{user} / $conf->{files}{shared}{$file}{group}], size: [$conf->{files}{shared}{$file}{size}], modified: [$conf->{files}{shared}{$file}{month} $conf->{files}{shared}{$file}{day} $conf->{files}{shared}{$file}{'time'}], target: [$conf->{files}{shared}{$file}{target}]\n");
		}
	}

	# Find which ISOs are mounted currently.
	my $this_device = "";
	my $this_media  = "";
	my $in_cdrom    = 0;
	### TODO: Find out why the XML data is doubled up.
	foreach my $line (@{$conf->{vm}{$vm}{xml}})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], xml line: [$line].\n");
		last if $line =~ /<\/domain>/;
		if ($line =~ /device='cdrom'/)
		{
			$in_cdrom = 1;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], going into a CD-ROM child element on: [$line].\n");
		}
		elsif (($line =~ /<\/disk>/) && ($in_cdrom))
		{
			# Record what I found/
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], exiting a CD-ROM child element on: [$line].\n");
			$conf->{vm}{$vm}{cdrom}{$this_device}{media} = $this_media ? $this_media : "";
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm::${vm}::cdrom::${this_device}::media: [$conf->{vm}{$vm}{cdrom}{$this_device}{media}].\n");
			$in_cdrom    = 0;
			$this_device = "";
			$this_media  = "";
		}
		
		if ($in_cdrom)
		{
			if ($line =~ /source file='(.*?)'/)
			{
				$this_media = $1;
				$this_media =~ s/^.*\/(.*?)$/$1/;
			}
			elsif ($line =~ /source dev='(.*?)'/)
			{
				$this_media = $1;
				$this_media =~ s/^.*\/(.*?)$/$1/;
			}
			elsif ($line =~ /target dev='(.*?)'/)
			{
				$this_device = $1;
			}
		}
	}

	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; current_cpu_count: [$current_cpu_count], current_ram: [$current_ram (".AN::Cluster::bytes_to_hr($conf, $current_ram).")], available_ram: [$available_ram (".AN::Cluster::bytes_to_hr($conf, $available_ram).")]\n");
	my $current_cpu_count = $conf->{vm}{$vm}{details}{cpu_count};
	my $max_cpu_count     = $conf->{resources}{total_threads};
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; max_ram: [$max_ram (".AN::Cluster::bytes_to_hr($conf, $max_ram).")], max_cpu_count: [$max_cpu_count]\n");
	
	# Create the media select boxes.
	foreach my $device (sort {$a cmp $b} keys %{$conf->{vm}{$vm}{cdrom}})
	{
		my $key                                 =  "media_$device";
		   $conf->{vm}{$vm}{cdrom}{device_keys} .= "$key,";
		if ($conf->{vm}{$vm}{cdrom}{$device}{media})
		{
			### TODO: If the media no longer exists, re-write the XML definition immediately.
			# Offer the eject button.
			$conf->{vm}{$vm}{cdrom}{$device}{say_select}   = "<select name=\"$key\" disabled>\n";
			$conf->{vm}{$vm}{cdrom}{$device}{say_in_drive} = "<span class=\"fixed_width\">$conf->{vm}{$vm}{cdrom}{$device}{media}</span>\n";
			$conf->{vm}{$vm}{cdrom}{$device}{say_eject}    = AN::Common::template($conf, "common.html", "enabled-button", {
				button_class	=>	"bold_button",
				button_link	=>	"?cluster=$conf->{cgi}{cluster}&vm=$conf->{cgi}{vm}&task=manage_vm&do=eject&device=$device",
				button_text	=>	"#!string!button_0017!#",
				id		=>	"eject_$device",
			}, "", 1);
			my $say_insert_disabled_button = AN::Common::template($conf, "common.html", "disabled-button", {
				button_text	=>	"#!string!button_0018!#",
			}, "", 1);
			$conf->{vm}{$vm}{cdrom}{$device}{say_insert}   = "$say_insert_disabled_button\n";
		}
		else
		{
			# Offer the insert button
			$conf->{vm}{$vm}{cdrom}{$device}{say_select}   = "<select name=\"$key\">\n";
			$conf->{vm}{$vm}{cdrom}{$device}{say_in_drive} = "<span class=\"highlight_unavailable\">(#!string!state_0007!#)</span>\n";
			my $say_eject_disabled_button = AN::Common::template($conf, "common.html", "disabled-button", {
				button_text	=>	"#!string!button_0017!#",
			}, "", 1);
			$conf->{vm}{$vm}{cdrom}{$device}{say_eject}    = "$say_eject_disabled_button\n";
			$conf->{vm}{$vm}{cdrom}{$device}{say_insert}   = AN::Common::template($conf, "common.html", "form-input", {
				type	=>	"submit",
				name	=>	"insert_$device",
				id	=>	"insert_$device",
				value	=>	"#!string!button_0018!#",
				class	=>	"bold_button",
			});
		}
		foreach my $file (sort {$a cmp $b} keys %{$conf->{files}{shared}})
		{
			next if ($file eq $conf->{vm}{$vm}{cdrom}{$device}{media});
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; file: [$file], cgi::${key}: [$conf->{cgi}{$key}]\n");
			if ((defined $conf->{cgi}{$key}) && ($file eq $conf->{cgi}{$key}))
			{
				$conf->{vm}{$vm}{cdrom}{$device}{say_select} .= "<option name=\"$file\" selected>$file</option>\n";
			}
			else
			{
				$conf->{vm}{$vm}{cdrom}{$device}{say_select} .= "<option name=\"$file\">$file</option>\n";
			}
		}
		$conf->{vm}{$vm}{cdrom}{$device}{say_select} .= "</select>\n";
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Media in: [$device] -> [$conf->{vm}{$vm}{cdrom}{$device}{media}]. [Select: $conf->{vm}{$vm}{cdrom}{$device}{say_select}]\n");
	}
	
	# Allow the user to select the number of CPUs.
	my $cpu_cores = [];
	foreach my $core_num (1..$max_cpu_count)
	{
		if ($max_cpu_count > 9)
		{
			#push @{$cpu_cores}, sprintf("%.2d", $core_num);
			push @{$cpu_cores}, $core_num;
		}
		else
		{
			push @{$cpu_cores}, $core_num;
		}
	}
	$conf->{cgi}{cpu_cores} = $current_cpu_count if not $conf->{cgi}{cpu_cores};
	my $select_cpu_cores    = AN::Cluster::build_select($conf, "cpu_cores", 0, 0, 60, $conf->{cgi}{cpu_cores}, $cpu_cores);
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; select_cpu_cores: [$select_cpu_cores]\n");
	
	# Something has changed. Make sure the request is sane,
	my $current_ram   = $conf->{vm}{$vm}{details}{ram};
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; current_ram: [$current_ram]\n");

	my $diff          = $conf->{resources}{total_ram} % (1024 ** 3);
	my $available_ram = ($conf->{resources}{total_ram} - $diff - $conf->{sys}{unusable_ram} - $conf->{resources}{allocated_ram}) + $current_ram;
	my $max_ram       = $available_ram;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; available_ram: [$available_ram]\n");
	
	# If the user sets the RAM to less than 1 GiB, warn them. If the user sets the RAM to less that 32 
	# MiB, error out.
	my $say_max_ram          = AN::Cluster::bytes_to_hr($conf, $max_ram);
	my $say_current_ram      = AN::Cluster::bytes_to_hr($conf, $current_ram);
	my ($current_ram_value, $current_ram_suffix) = (split/ /, $say_current_ram);
	$conf->{cgi}{ram}        = $current_ram_value if not $conf->{cgi}{ram};
	$conf->{cgi}{ram_suffix} = $current_ram_suffix if not $conf->{cgi}{ram_suffix};
	my $select_ram_suffix    = AN::Cluster::build_select($conf, "ram_suffix", 0, 0, 60, $conf->{cgi}{ram_suffix}, ["MiB", "GiB"]);
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; (<span class=\"subtle_text\">Maximum $say_max_ram</span>) <input type=\"input\" name=\"ram\" value=\"$conf->{cgi}{ram}\" style=\"width: 100px;\"> $select_ram_suffix\n");
	
	### Disabled now.
# 	# Setup Guacamole, if installed.
	my $message     = "";
	my $remote_icon = "";
# 	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; path::guacamole_config: [$conf->{path}{guacamole_config}]\n");
# 	if (-e $conf->{path}{guacamole_config})
# 	{
# 		# Installed.
# 		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], Guacamole installed, getting VNC info.\n");
# 		($node, my $type, my $listen, my $port) = get_current_vm_vnc_info($conf, $vm, $node);
# 		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], type: [$type], listen: [$listen], port: [$port]\n");
# 		
# 		# See if I need to update the XML definition file.
# 		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm::${vm}::graphics::type: [$conf->{vm}{$vm}{graphics}{type}],  vm::${vm}::graphics::listen: [$conf->{vm}{$vm}{graphics}{'listen'}]\n");
# 		if ((not $conf->{sys}{use_spice_graphics}) && (($conf->{vm}{$vm}{graphics}{type} ne "vnc") || ($conf->{vm}{$vm}{graphics}{'listen'} ne "0.0.0.0")))
# 		{
# 			# Rewrite the XML definition. The 'graphics' section should look like:
# 			#     <graphics type='vnc' port='5900' autoport='yes' listen='0.0.0.0'>
# 			#       <listen type='address' address='0.0.0.0'/>
# 			#     </graphics>
# 			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; VM: [$say_vm]'s definition file: [$conf->{vm}{$vm}{definition_file}] is not using VNC, updating it via: [$node].\n");
# 			print AN::Common::template($conf, "server.html", "switch-to-vnc-header");
# 			my ($backup_file) = archive_file($conf, $node, $conf->{vm}{$vm}{definition_file}, 0, "hidden_table");
# 			switch_vm_xml_to_vnc($conf, $node, $vm, $backup_file);
# 			print AN::Common::template($conf, "server.html", "switch-to-vnc-footer");
# 		}
# 		
# 		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; type: [$type]\n");
# 		if ($type ne "vnc")
# 		{
# 			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; VM: [$say_vm] is not using VNC, can't use Guacamole.\n");
# 			# Check the recorded XML file and is necesary, update
# 			# it. In any case, disable VNC and tell the user they
# 			# will need to power off and restart the server before
# 			# this will work.
# 			$message     = "#!string!message_0076!#";
# 			$remote_icon = AN::Common::template($conf, "common.html", "image", {
# 				image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/icon_server-desktop_oops.png",
# 				alt_text	=>	"",
# 				id		=>	"remote_icon",
# 			}, "", 1);
# 		}
# 		else
# 		{
# 			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; VM: [$say_vm] is using VNC, we can offer remote desktop access.\n");
# 			update_guacamole_config($conf, $say_vm, $node, $port);
# 		}
# 		
# 		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; message: [$message]\n");
# 		if (not $message)
# 		{
# 			my ($guacamole_url) = AN::Cluster::get_guacamole_link($conf, $node);
# 			$message = "#!string!message_0077!#";	# Connect to the desktop
# 			if (not $node)
# 			{
# 				$message     = "#!string!message_0078!#";	# Server is off
# 				$remote_icon = AN::Common::template($conf, "common.html", "image", {
# 					image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/icon_server-desktop_offline.png",
# 					alt_text	=>	"",
# 					id		=>	"remote_icon",
# 				}, "", 1);
# 			}
# 			elsif (($node =~ /n01/) || ($node =~ /node01/))
# 			{
# 				my $image = AN::Common::template($conf, "common.html", "image", {
# 					image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/icon_server-desktop_n01.png",
# 					alt_text	=>	"",
# 					id		=>	"server-desktop_n01",
# 				}, "", 1);
# 				$remote_icon = AN::Common::template($conf, "common.html", "enabled-button-no-class-new-tab", {
# 					button_link	=>	"$guacamole_url?id=c\%2F$say_vm",
# 					button_text	=>	"$image",
# 					id		=>	"guacamole_url_$say_vm",
# 				}, "", 1);
# 			}
# 			elsif (($node =~ /n02/) || ($node =~ /node02/))
# 			{
# 				my $image = AN::Common::template($conf, "common.html", "image", {
# 					image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/icon_server-desktop_n02.png",
# 					alt_text	=>	"",
# 					id		=>	"server-desktop_n02",
# 				}, "", 1);
# 				$remote_icon = AN::Common::template($conf, "common.html", "enabled-button-no-class-new-tab", {
# 					button_link	=>	"$guacamole_url?id=c\%2F$say_vm",
# 					button_text	=>	"$image",
# 					id		=>	"guacamole_url_$say_vm",
# 				}, "", 1);
# 			}
# 			else
# 			{
# 				$message     = "#!string!message_0079!#";	# Think the server is running, but unknown where.
# 				$remote_icon = AN::Common::template($conf, "common.html", "image", {
# 					image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/icon_server-desktop_oops.png",
# 					alt_text	=>	"",
# 					id		=>	"server-desktop_oops",
# 				}, "", 1);
# 			}
# 		}
# 	}
# 	else
# 	{
# 		# Not installed.
# 		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Guacamole is disabled.\n");
# 		$message     = "#!string!message_0080!#";	# Version doesn't support guacamole
# 		$remote_icon = AN::Common::template($conf, "common.html", "image", {
# 			image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/icon_server-desktop_oops.png",
# 			alt_text	=>	"",
# 			id		=>	"server-desktop_oops",
# 		}, "", 1);
# 	}
	
	# Finally, print it all
	# The variable hash feeds 'title_0032'.
	print AN::Common::template($conf, "server.html", "manager-server-header", {}, {
		server	=>	$say_vm,
	});

	my $i = 1;
	foreach my $device (sort {$a cmp $b} keys %{$conf->{vm}{$vm}{cdrom}})
	{
		next if $device eq "device_keys";
		my $say_disk   = $conf->{vm}{$vm}{cdrom}{$device}{say_select};
		my $say_button = $conf->{vm}{$vm}{cdrom}{$device}{say_insert};
		my $say_state  = "#!string!state_0124!#";
		if ($conf->{vm}{$vm}{cdrom}{$device}{media})
		{
			$say_disk   = $conf->{vm}{$vm}{cdrom}{$device}{say_in_drive};
			$say_button = $conf->{vm}{$vm}{cdrom}{$device}{say_eject};
			$say_state  = "#!string!state_0125!#";
		}
		my $say_optical_drive = AN::Common::get_string($conf, {key => "device_0003", variables => {
				drive_number	=>	$i,
			}});
		print AN::Common::template($conf, "server.html", "manager-server-optical-drive", {
			optical_drive	=>	$say_optical_drive,
			'state'		=>	$say_state,
			disk		=>	$say_disk,
			button		=>	$say_button,
		});
		$i++;
	}
	
	my $current_boot_device = AN::Common::get_string($conf, {key => "message_0081", variables => {
			boot_device	=>	$say_current_boot_device,
		}});
	my $ram_details = AN::Common::get_string($conf, {key => "message_0082", variables => {
			current_ram	=>	$say_current_ram,
			maximum_ram	=>	$say_max_ram,
		}});
	my $cpu_details = AN::Common::get_string($conf, {key => "message_0083", variables => {
			current_cpus	=>	$conf->{vm}{$vm}{details}{cpu_count},
		}});
	my $restart_tomcat = AN::Common::get_string($conf, {key => "message_0085", variables => {
			reset_tomcat_url	=>	"?cluster=$conf->{cgi}{cluster}&task=restart_tomcat",
		}});

	# Display all this wonderful data.
	print AN::Common::template($conf, "server.html", "manager-server-show-details", {
		current_boot_device	=>	$current_boot_device,
		boot_select		=>	$boot_select,
		ram_details		=>	$ram_details,
		ram			=>	$conf->{cgi}{ram},
		select_ram_suffix	=>	$select_ram_suffix,
		cpu_details		=>	$cpu_details,
		select_cpu_cores	=>	$select_cpu_cores,
		remote_icon		=>	$remote_icon,
		message			=>	$message,
		restart_tomcat		=>	$restart_tomcat,
		anvil			=>	$conf->{cgi}{cluster},
		server			=>	$conf->{cgi}{vm},
		task			=>	$conf->{cgi}{task},
		device_keys		=>	$conf->{vm}{$vm}{cdrom}{device_keys},
	});
	
	return (0);
}

# This modifies the VM's XML definition file to tell it to use VNC instead of
# spice or another protocol.
sub switch_vm_xml_to_vnc
{
	my ($conf, $node, $vm, $backup_file) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; switch_vm_xml_to_vnc(); node: [$node], vm: [$vm], backup_file: [$backup_file]\n");
	
	my $proceed         = 1;
	my $definition_file = $conf->{vm}{$vm}{definition_file};
	my $new_definition  = "";
	my $in_graphics     = 0;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm::${vm}::raw_xml: [$conf->{vm}{$vm}{raw_xml}]\n");
	if (not $conf->{vm}{$vm}{raw_xml})
	{
		my $say_error = AN::Common::get_string($conf, {key => "message_0341", variables => {
			definition_file	=>	$definition_file,
		}});
		print AN::Common::template($conf, "common.html", "no-definition-file", {
			error			=>	$say_error,
		});
		$proceed = 0;
	}
	else
	{
		foreach my $line (@{$conf->{vm}{$vm}{raw_xml}})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> line: [$line]\n");
			if ($line =~ /<graphics .*\/>/)
			{
				# Self-closing element.
				$new_definition .= "    <graphics type='vnc' port='5900' autoport='yes' listen='0.0.0.0'>\n";
				$new_definition .= "      <listen type='address' address='0.0.0.0'/>\n";
				$new_definition .= "    </graphics>\n";
			}
			elsif ($line =~ /<graphics /)
			{
				$in_graphics = 1;
				next;
			}
			elsif ($in_graphics)
			{
				if ($line =~ /<\/graphics>/)
				{
					# The port here doesn't matter.
					$in_graphics    =  0;
					$new_definition .= "    <graphics type='vnc' port='5900' autoport='yes' listen='0.0.0.0'>\n";
					$new_definition .= "      <listen type='address' address='0.0.0.0'/>\n";
					$new_definition .= "    </graphics>\n";
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << new_definition: [$new_definition]\n");
					next;
				}
				else
				{
					# Skip this.
					next;
				}
			}
			else
			{
				$new_definition .= "$line\n";
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << new_definition: [$new_definition]\n");
			}
		}
		$new_definition =~ s/\n+$//;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; New definition file:\n===\n$new_definition===\n");
		
		# Make sure the definition file is sane.
		if (($new_definition !~ /^<domain/s) || ($new_definition !~ /<\/domain>/s))
		{
			my $say_error = "";
			if (length($new_definition) < 5)
			{
				# Empty
				$say_error = AN::Common::get_string($conf, {key => "message_0338", variables => {
					definition_file	=>	$definition_file,
				}});
			}
			else
			{
				# Malformed
				$say_error = AN::Common::get_string($conf, {key => "message_0339", variables => {
					definition_file	=>	$definition_file,
				}});
			}
			$new_definition = AN::Cluster::convert_text_to_html($conf, $new_definition);
			print AN::Common::template($conf, "common.html", "bad-definition-file", {
				error			=>	$say_error,
				definition_content	=>	$new_definition,
			});
			$proceed = 0;
		}
	}
	
	# Write the new definition file.
	if ($proceed)
	{
		my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	"cat > $definition_file << EOF\n$new_definition\nEOF",
		});
			#shell_call	=>	"echo \"$new_definition\" > $definition_file && chmod 644 $definition_file",
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		}
		
		# Set the permissions
		$error  = "";
		$output = "";
		($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	"chmod 644 $definition_file",
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		}
		
		# Read it back.
		$error  = "";
		$output = "";
		($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	1,
			shell_call	=>	"cat $definition_file",
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		my $recover         = 0;
		my $first_line_read = 0;
		my $read_content     = "";
		foreach my $line (@{$output})
		{
			if (not $first_line_read)
			{
				$read_content .= "$line\n";
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
				if ($line !~ /^<domain/)
				{
					# well crap...
					$recover = 1;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; First line diesn't start with: '<domain', recovery required!\n");
				}
				$first_line_read = 1;
			}
		}
		if ($recover)
		{
			my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
				node		=>	$node,
				port		=>	$conf->{node}{$node}{port},
				user		=>	"root",
				password	=>	$conf->{sys}{root_password},
				ssh_fh		=>	"",
				'close'		=>	0,
				shell_call	=>	"cp -f $backup_file $definition_file && chmod 644 $definition_file",
			});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
			foreach my $line (@{$output})
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			}
			
			my $say_error = AN::Common::get_string($conf, {key => "message_0340", variables => {
				definition_file	=>	$definition_file,
				backup_file	=>	$backup_file,
			}});
			print AN::Common::template($conf, "common.html", "bad-definition-file", {
				error			=>	$say_error,
				definition_content	=>	$read_content,
			});
		}
	}
	
	return(0);
}

### Disabled
# # This reads the current guacamole configuration file and, if necessary,
# # updates it to add/modify the given VM's host and port.
# sub update_guacamole_config
# {
# 	my ($conf, $say_vm, $node, $port) = @_;
# 	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; update_guacamole_config; say_vm: [$say_vm], node: [$node], port: [$port]\n");
# 	
# 	# Read the guacamole config file.
# 	$conf->{guacamole}{config}{old} = [];
# 	my $shell_call = $conf->{path}{guacamole_config};
# 	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Reading: [$shell_call]\n");
# 	open (my $file_handle, "<", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to read: [$shell_call], error was: $!\n";
# 	while(<$file_handle>)
# 	{
# 		chomp;
# 		my $line = $_;
# 		$line =~ s/^\s+//;
# 		$line =~ s/\s+$//;
# 		$line =~ s/\s+/ /g;
# 		next if not $line;
# 		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
# 		push @{$conf->{guacamole}{config}{old}}, $line;
# 	}
# 	close $file_handle;
# 	
# 	my $match_found    = 0;
# 	my $rewrite_needed = 0;
# 	my $this_vm        = "";
# 	my $this_host      = "";
# 	my $this_port      = "";
# 	foreach my $line (@{$conf->{guacamole}{config}{old}})
# 	{
# 		$line =~ s/^\s+//;
# 		$line =~ s/\s+$//;
# 		$line =~ s/\s+/ /g;
# 		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
# 		if ($line =~ /^<\/config>/)
# 		{
# 			# Save the data.
# 			$conf->{guacamole}{vm}{$this_vm}{host} = $this_host;
# 			$conf->{guacamole}{vm}{$this_vm}{port} = $this_port;
# 			
# 			# See of this entry matches my current VM and, if so,
# 			# see if the port or host needs to be updated.
# 			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Checking if this_vm: [$this_vm] matches say_vm: [$say_vm]\n");
# 			if ($this_vm eq $say_vm)
# 			{
# 				$match_found = 1;
# 				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Matched. Checking now if this_host: [$this_host] matches node: [$node] and if this_port: [$this_port] matches port: [$port]\n");
# 				if (($node ne $this_host) || ($port ne $this_port))
# 				{
# 					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Difference found, rewrite needed.\n");
# 					$rewrite_needed                        = 1;
# 					$conf->{guacamole}{vm}{$this_vm}{host} = $node;
# 					$conf->{guacamole}{vm}{$this_vm}{port} = $port;
# 					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; New values; guacamole::vm::${this_vm}::host: [$conf->{guacamole}{vm}{$this_vm}{host}], guacamole::vm::${this_vm}::port: [$conf->{guacamole}{vm}{$this_vm}{port}]!\n");
# 				}
# 				else
# 				{
# 					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Same, rewrite not needed.\n");
# 				}
# 			}
# 			else
# 			{
# 				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; this_vm: [$this_vm], host: [$conf->{guacamole}{vm}{$this_vm}{host}], port: [$conf->{guacamole}{vm}{$this_vm}{port}]\n");
# 				# See if this VM still exists on the cluster.
# 				my $exists =  0;
# 				foreach my $existing_vm (sort {$a cmp $b} keys %{$conf->{vm}})
# 				{
# 					$existing_vm =~ s/^vm://;
# 					if ($existing_vm eq $this_vm)
# 					{
# 						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; this_vm: [$this_vm] still exists on the Anvil!.\n");
# 						$exists = 1;
# 					}
# 				}
# 				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; exists: [$exists], this_vm: [$this_vm], say_vm: [$say_vm].\n");
# 				if ((not $exists) && ($this_vm ne $say_vm))
# 				{
# 					# Delete it so that it's removed from guacamole.
# 					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Existing server: [$this_vm] no longer exists, deleting it from guacamole.\n");
# 					delete $conf->{guacamole}{vm}{$this_vm};
# 					$rewrite_needed = 1;
# 				}
# 			}
# 			
# 			$this_vm   = "";
# 			$this_host = "";
# 			$this_port = "";
# 			next;
# 		}
# 		
# 		if ($line =~ /^<config /)
# 		{
# 			($this_vm) = ($line =~ /name="(.*?)"/);
# 			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; this_vm: [$this_vm]\n");
# 		}
# 		
# 		next if not $this_vm;
# 		if (($line =~ /^<param /) && ($line =~ /name="hostname"/))
# 		{
# 			($this_host) = ($line =~ /value="(.*?)"/);
# 			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; this_host: [$this_host]\n");
# 		}
# 		if (($line =~ /^<param /) && ($line =~ /name="port"/))
# 		{
# 			($this_port) = ($line =~ /value="(.*?)"/);
# 			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; this_port: [$this_port]\n");
# 		}
# 	}
# 	if (not $match_found)
# 	{
# 		$rewrite_needed                       = 1;
# 		$conf->{guacamole}{vm}{$say_vm}{host} = $node;
# 		$conf->{guacamole}{vm}{$say_vm}{port} = $port;
# 		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; This server not found, rewrite needed to add it.\n");
# 		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; New values; guacamole::vm::${say_vm}::host: [$conf->{guacamole}{vm}{$say_vm}{host}], guacamole::vm::${say_vm}::port: [$conf->{guacamole}{vm}{$say_vm}{port}].\n");
# 	}
# 	
# 	# Now look to see if we need to update the config.
# 	if ($rewrite_needed)
# 	{
# 		my ($date) = AN::Cluster::get_date($conf);
# 		my $say_warning = AN::Common::get_string($conf, {key => "text_0006"});
# 		my $say_updated = AN::Common::get_string($conf, {key => "text_0007", variables => {
# 				date	=>	$date,
# 			}});
# 		my $new_config;
# 		$new_config .= "<configs>\n";
# 		$new_config .= "	<!-- $say_warning -->\n";
# 		$new_config .= "	<!-- $say_updated -->\n";
# 		foreach my $this_vm (sort {$a cmp $b} keys %{$conf->{guacamole}{vm}})
# 		{
# 			my $this_host = $conf->{guacamole}{vm}{$this_vm}{host};
# 			my $this_port = $conf->{guacamole}{vm}{$this_vm}{port};
# 			$new_config .= "	<config name=\"$this_vm\" protocol=\"vnc\">\n";
# 			$new_config .= "		<param name=\"hostname\" value=\"$this_host\" />\n";
# 			$new_config .= "		<param name=\"port\" value=\"$this_port\" />\n";
# 			$new_config .= "	</config>\n";
# 		}
# 		$new_config .= "</configs>\n";
# 		
# 		# Save the new config.
# 		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; new guacamole config:\n===\n$new_config\n===\n");
# 		
# 		# Backup the last config.
# 		my $backup_file =  "$conf->{path}{guacamole_config}.$date";
# 		   $backup_file =~ s/ /_/;
# 		my $shell_call  =  "cp $conf->{path}{guacamole_config} $backup_file";
# 		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
# 		open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
# 		while(<$file_handle>)
# 		{
# 			chomp;
# 			my $line = $_;
# 			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
# 		}
# 		close $file_handle;
# 		
# 		# Save the new config.
# 		$shell_call = "$conf->{path}{guacamole_config}";
# 		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
# 		open ($file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
# 		print $file_handle $new_config;
# 		close $file_handle;
# 	}
# 	else
# 	{
# 		# Rewrite not needed.
# 		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Guacamole config update is not needed.\n");
# 	}
# 	
# 	return(0);
# }

# This figures out which node a VM is running on, calls 'virsh dumpxml $vm',
# parses out the currently used VNC port and returns the host and port.
sub get_current_vm_vnc_info
{
	my ($conf, $vm, $node) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; get_current_vm_vnc_info(); vm: [$vm]\n");
	my $say_vm = $vm;
	if ($vm =~ /^vm:/)
	{
		($say_vm) = ($vm =~ /^vm:(.*)/);
	}
	else
	{
		$vm = "vm:$vm";
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_vm: [$say_vm]\n");
	
	my $port    = "";
	my $type    = "";
	my $listen  = "";
	my $xml_ref = "";
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm::${vm}::current_host: [$conf->{vm}{$vm}{current_host}]\n");
	if ($conf->{vm}{$vm}{current_host})
	{
		$node = $conf->{vm}{$vm}{current_host};
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$say_vm] is running on: [$node].\n");
		
		# Read the current VM config from virsh.
		read_live_xml($conf, $vm, $say_vm, $node);
		$xml_ref = $conf->{vm}{$vm}{live_xml};
	}
	else
	{
		# The VM isn't running.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$say_vm] is not running.\n");
		$xml_ref = $conf->{vm}{$vm}{xml};
	}
	
	foreach my $line (@{$xml_ref})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$say_vm] definition line: [$line].\n");
		if ($line =~ /^<graphics /)
		{
			($port)   = ($line =~ / port='(\d+)'/);
			($type)   = ($line =~ / type='(.*?)'/);
			($listen) = ($line =~ / listen='(.*?)'/);
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$say_vm] is using: [$type] and listening on: [$listen] port: [$port].\n");
			last;
		}
	}
	
	# Set the global hash values.
	$conf->{vm}{$vm}{graphics}{type}     = $type;
	$conf->{vm}{$vm}{graphics}{'listen'} = $listen;
	$conf->{vm}{$vm}{graphics}{port}     = $port;
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], type: [$type], listen: [$listen], port: [$port]\n");
	return($node, $type, $listen, $port);
}

# This uses virsh to dump the running config of a server.
sub read_live_xml
{
	my ($conf, $vm, $say_vm, $node) = @_;
	
	$conf->{vm}{$vm}{live_xml} = [];
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"/usr/bin/virsh dumpxml $say_vm",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		push @{$conf->{vm}{$vm}{live_xml}}, $line;
	}
	
	return(0);
}

# This looks at a VM and determines which storage pool it is on.
sub find_node_storage_pool
{
	my ($conf) = @_;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in find_node_storage_pool().\n");
	
	my $vm     = $conf->{cgi}{vm};
	my $say_vm = ($vm =~ /^vm:(.*)/)[0];
	
	my $current_lv = "";
	my $in_block   = 0;
	foreach my $line (sort {$a cmp $b} @{$conf->{vm}{$vm}{xml}})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$say_vm], xml line: [$line]\n");
		if (($line =~ /<disk/) && ($line =~ /type='block'/))
		{
			$in_block = 1;
			next;
		}
		if ($in_block)
		{
			if ($line =~ /<\/disk>/)
			{
				$in_block = 0;
				next;
			}
			elsif (($line =~ /source/) && ($line =~ /dev='(.*?)'/))
			{
				$current_lv = $1;
				last;
			}
		}
	}
	my $lv_size = $conf->{resources}{lv}{$current_lv}{size};
	my $on_vg   = $conf->{resources}{lv}{$current_lv}{on_vg};
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$say_vm], current_lv: [$current_lv], size: [$lv_size], on_vg: [$on_vg]\n");
	
	return($on_vg, $lv_size);
}

# This calls 'virsh dumpxml' against the given VM.
sub update_vm_definition
{
	my ($conf, $node, $vm) = @_;
	my $say_vm = $vm;
	if ($vm =~ /^vm:(.*)/)
	{
		$say_vm = $1;
	}
	else
	{
		$vm = "vm:$vm";
	}
	my $definition_file = $conf->{vm}{$vm}{definition_file};
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in update_vm_definition(); node: [$node], vm: [$vm], say_vm: [$say_vm], definition_file: [$definition_file]\n");
	
	my $virsh_exit_code;
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"/usr/bin/virsh dumpxml $say_vm > $definition_file; echo virsh:\$?",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		next if not $line;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /virsh:(\d+)/)
		{
			$virsh_exit_code = $1;
		}
		else
		{
			#print "<span class=\"code\">$line</span><br />\n";
		}
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; virsh exit code: [$virsh_exit_code]\n");
	if ($virsh_exit_code eq "0")
	{
		# Delete the old definition values and read the new one.
		$conf->{vm}{$vm}{xml} = "";
		read_vm_definition($conf, $node, $vm);
	}
	else
	{
		$virsh_exit_code = "-" if not defined $virsh_exit_code;
		my $say_error = AN::Common::get_string($conf, {key => "message_0086", variables => {
			server		=>	$say_vm,
			virsh_exit_code	=>	$virsh_exit_code,
		}});
		print AN::Common::template($conf, "server.html", "update-definition-failed-bad-exit-code", {
			error	=>	$say_error,
		});
		return($virsh_exit_code);
	}
	return(0);
}

sub add_vm_to_cluster
{
	my ($conf, $skip_scan) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; add_vm_to_cluster(); skip_scan: [$skip_scan]\n");
	
	# If this is being called after provisioning a VM, we'll skip scanning the cluster and we'll not 
	# print the opening header. 
	
	# Two steps needed; Dump the definition and use ccs to add it to the cluster.
	my $cluster    = $conf->{cgi}{cluster};
	my $vm         = $conf->{cgi}{name};
	#my $node       = $conf->{cgi}{node};
	my $node       = $conf->{new_vm}{host_node} ? $conf->{new_vm}{host_node} : $conf->{cgi}{node};
	my $host_node  = $conf->{new_vm}{host_node};
	my $definition = "/shared/definitions/$vm.xml";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cluster: [$cluster], host_node: [$host_node], node: [$node], definition: [$definition]\n");
	my $peer;
	foreach my $this_node (@{$conf->{clusters}{$cluster}{nodes}})
	{
		if ($this_node ne $node)
		{
			$peer = $this_node;
			$node = $this_node if not $node;
		}
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], peer: [$peer]\n");
	
	# First, find the failover domain...
	my $failover_domain;
	$conf->{sys}{ignore_missing_vm} = 1;
	
	if ($skip_scan)
	{
		# Table is open.
	}
	else
	{
		AN::Cluster::scan_cluster($conf);
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; finished scan of Anvil!.\n");
		print AN::Common::template($conf, "server.html", "add-server-to-anvil-header");
	}
	
	# Find the failover domain.
	foreach my $fod (keys %{$conf->{failoverdomain}})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; fod: [$fod]\n");
		if ($fod =~ /primary_(.*?)$/)
		{
			my $node_suffix = $1;
			my $alt_suffix  = (($node_suffix eq "n01") || ($node_suffix eq "n1")) ? "node01" : "node02";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node_suffix: [$node_suffix], alt_suffix: [$alt_suffix]\n");
			
			# If the user has named their nodes 'nX' or 'nodeX',
			# the 'n0X'/'node0X' won't match, so we fudge it here.
			my $say_node = $node;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_node: [$say_node]\n");
			if (($node !~ /node0\d/) && ($node !~ /n0\d/))
			{
				if ($node =~ /node(\d)/)
				{
					my $integer = $1;
					$say_node = "node0".$integer;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_node: [$say_node]\n");
				}
				elsif ($node =~ /n(\d)/)
				{
					my $integer = $1;
					$say_node = "n0".$integer;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_node: [$say_node]\n");
				}
			}
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], say_node: [$say_node], node_suffix: [$node_suffix], alt_suffix: [$alt_suffix]\n");
			if (($say_node =~ /$node_suffix/) || ($say_node =~ /$alt_suffix/))
			{
				$failover_domain = $fod;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; failover_domain: [$failover_domain]\n");
				last;
			}
		}
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Using failover domain: [$failover_domain]\n");
	
	# How I print the next message depends on whether I'm doing a 
	# stand-alone addition or on the heels of a new provisioning.
	if ($skip_scan)
	{
		# Running on the heels of a server provision, so the table is already opened.
		print AN::Common::template($conf, "server.html", "general-message", {
			row	=>	"#!string!row_0281!#",
			message	=>	"#!string!message_0090!#",
		});
		print AN::Common::template($conf, "server.html", "general-message", {
			row	=>	"#!string!row_0092!#",
			message	=>	AN::Common::get_string($conf, {key => "title_0033", variables => {
				server		=>	$vm,
				failover_domain	=>	$failover_domain,
			}}),
		});
	}
	else
	{
		# Doing a stand-alone addition of a server to the Anvil!, so
		# we need a title.
		print AN::Common::template($conf, "server.html", "add-server-to-anvil-header-detail", {}, {
			server		=>	$vm,
			failover_domain	=>	$failover_domain,
		});
	}
	
	# If there is no password set, abort.
	if (not $conf->{clusters}{$cluster}{ricci_pw})
	{
		# No ricci user, so we can't add it. Tell the user and give 
		# them a link to the config for this Anvil!.
		print AN::Common::template($conf, "server.html", "general-error-message", {
			row	=>	"#!string!row_0090!#",
			message	=>	AN::Common::get_string($conf, {key => "message_0087", variables => {
				server		=>	$vm,
			}}),
		});
		print AN::Common::template($conf, "server.html", "general-error-message", {
			row	=>	"#!string!row_0091!#",
			message	=>	AN::Common::get_string($conf, {key => "message_0088", variables => {
				manage_url	=>	"?config=true&anvil=$cluster",
			}}),
		});
		return(1);
	}

	if (not $failover_domain)
	{
		# No failover domain found
		print AN::Common::template($conf, "server.html", "general-message", {
			row	=>	"#!string!row_0096!#",
			message	=>	"#!string!message_0089!#",
		});
		return (1);
	}
	
	# Lets get started!

	# On occasion, the installed VM will power off, not reboot. So this
	# checks to see if the VM needs to be kicked awake.
	my ($host) = find_vm_host($conf, $node, $peer, $vm);
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], host: [$host]\n");
	if ($host eq "none")
	{
		# Server isn't running yet.
		print AN::Common::template($conf, "server.html", "general-message", {
			row	=>	"#!string!row_0280!#",
			message	=>	"#!string!message_0091!#",
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; I will now boot the VM.\n");
		my $virsh_exit_code;
		my $shell_call      = "/usr/bin/virsh start $vm; echo virsh:\$?";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			next if not $line;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /virsh:(\d+)/)
			{
				$virsh_exit_code = $1;
			}
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; virsh exit code: [$virsh_exit_code]\n");
		if ($virsh_exit_code eq "0")
		{
			# Server has booted.
			print AN::Common::template($conf, "server.html", "general-message", {
				row	=>	"&nbsp;",
				message	=>	"#!string!message_0092!#",
			});
		}
		else
		{
			# If something undefined the VM already and the server
			# is not running, this will fail. Try to start the
			# server using the definition file before giving up.
			print AN::Common::template($conf, "server.html", "general-message", {
				row	=>	"&nbsp;",
				message	=>	"#!string!message_0093!#",
			});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; It didn't start on the first try. Trying again with the definition file.\n");
			my $virsh_exit_code;
			my $shell_call      = "/usr/bin/virsh create /shared/definitions/${vm}.xml; echo virsh:\$?";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
			($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
				node		=>	$node,
				port		=>	$conf->{node}{$node}{port},
				user		=>	"root",
				password	=>	$conf->{sys}{root_password},
				ssh_fh		=>	$ssh_fh,
				'close'		=>	1,
				shell_call	=>	$shell_call,
			});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
			foreach my $line (@{$output})
			{
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				next if not $line;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
				if ($line =~ /virsh:(\d+)/)
				{
					$virsh_exit_code = $1;
				}
			}
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; virsh exit code: [$virsh_exit_code]\n");
			if ($virsh_exit_code eq "0")
			{
				# Should now be booting.
				print AN::Common::template($conf, "server.html", "general-message", {
					row	=>	"&nbsp;",
					message	=>	"#!string!message_0092!#",
				});
			}
			else
			{
				# Failed to boot.
				my $say_message = AN::Common::get_string($conf, {key => "message_0094", variables => {
					server		=>	$vm,
					virsh_exit_code	=>	$virsh_exit_code,
				}});
				print AN::Common::template($conf, "server.html", "general-error-message", {
					row	=>	"#!string!row_0044!#",
					message	=>	$say_message,
				});
				return (1);
			}
		}
	}
	elsif ($host eq $node)
	{
		# Already running
		print AN::Common::template($conf, "server.html", "general-message", {
			row	=>	"&nbsp;",
			message	=>	"#!string!message_0095!#",
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The VM is now running on this node: [$node].\n");
	}
	else
	{
		# Already running, but on the peer.
		$node = $host;
		print AN::Common::template($conf, "server.html", "general-message", {
			row	=>	"&nbsp;",
			message	=>	"#!string!message_0096!#",
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The VM is now running on the peer. Will proceed using: [$node].\n");
	}
	
	# Dump the VM's XML definition.
	print AN::Common::template($conf, "server.html", "general-message", {
		row	=>	"#!string!row_0093!#",
		message	=>	"#!string!message_0097!#",
	});
	if (not $vm)
	{
		# No server name... wth?
		print AN::Common::template($conf, "server.html", "general-error-message", {
			row	=>	"#!string!row_0044!#",
			message	=>	"#!string!message_0098!#",
		});
		return (1);
	}
	my @new_vm_xml;
	my $virsh_exit_code;
	my $shell_call = "/usr/bin/virsh dumpxml $vm; echo virsh:\$?";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		#$line =~ s/^\s+//;
		#$line =~ s/\s+$//;
		next if not $line;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /virsh:(\d+)/)
		{
			$virsh_exit_code = $1;
		}
		else
		{
			push @new_vm_xml, $line;
		}
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; virsh exit code: [$virsh_exit_code]\n");
	if ($virsh_exit_code eq "0")
	{
		# Wrote the definition.
		my $say_message = AN::Common::get_string($conf, {key => "message_0099", variables => {
			definition	=>	$definition,
		}});
		print AN::Common::template($conf, "server.html", "general-message", {
			row	=>	"&nbsp;",
			message	=>	$say_message,
		});
	}
	else
	{
		# Failed to write the definition file.
		my $say_error = AN::Common::get_string($conf, {key => "message_0100", variables => {
			virsh_exit_code	=>	$virsh_exit_code,
		}});
		print AN::Common::template($conf, "server.html", "general-error-message", {
			row	=>	"&nbsp;",
			message	=>	$say_error,
		});
		return (1);
	}
	
	# We'll switch to boot the 'hd' first if needed and add a cdrom if it doesn't exist.
	my $new_xml = "";
	my $hd_seen = 0;
	my $cd_seen = 0;
	my $in_os   = 0;
	foreach my $line (@new_vm_xml)
	{
		next if not $line;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /<boot dev='(.*?)'/)
		{
			my $device = $1;
			if ($device eq "hd")
			{
				next if $hd_seen;
				$hd_seen = 1;
			}
			if ($device eq "cdrom")
			{
				$cd_seen = 1;
				if (not $hd_seen)
				{
					# Inject the hd first.
					$new_xml .= "    <boot dev='hd'/>\n";
					$hd_seen =  1;
				}
			}
		}
		if ($line =~ /<\/os>/)
		{
			if (not $cd_seen)
			{
				# Inject an optical drive.
				$new_xml .= "    <boot dev='cdrom'/>\n";
			}
		}
		$new_xml .= "$line\n";
	}
	
	# See if I need to insert or edit any network interface driver elements.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sys::server::bcn_nic_driver: [$conf->{sys}{server}{bcn_nic_driver}], sys::server::sn_nic_driver: [$conf->{sys}{server}{sn_nic_driver}], sys::server::ifn_nic_driver: [$conf->{sys}{server}{ifn_nic_driver}]\n");
	if (($conf->{sys}{server}{bcn_nic_driver}) or ($conf->{sys}{server}{sn_nic_driver} or $conf->{sys}{server}{ifn_nic_driver}))
	{
		# Clear out the old array and refill it with the possibly-edited 'new_xml'.
		undef @new_vm_xml;
		foreach my $line (split/\n/, $new_xml)
		{
			push @new_vm_xml, "$line";
		}
		$new_xml = "";
		
		my $in_interface = 0;
		my $this_network = "";
		my $this_driver  = "";
		foreach my $line (@new_vm_xml)
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /<interface type='bridge'>/)
			{
				$in_interface = 1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in_interface: [$in_interface]\n");
			}
			if ($in_interface)
			{
				if ($line =~ /<source bridge='(.*?)_bridge1'\/>/)
				{
					$this_network = $1;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; this_network: [$this_network]\n");
				}
				if ($line =~ /<driver name='(.*?)'\/>/)
				{
					$this_driver = $1;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; this_driver: [$this_driver]\n");
					
					# See if I need to update it.
					if ($this_network)
					{
						my $key = $this_network."_nic_driver";
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; key: [$key], sys::server::$key: [$conf->{sys}{server}{$key}]\n");
						if ($conf->{sys}{server}{$key})
						{
							AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; this_driver: [$this_driver], sys::server::$key: [$conf->{sys}{server}{$key}]\n");
							if ($this_driver ne $conf->{sys}{server}{$key})
							{
								# Change the driver
								AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> line: [$line]\n");
								$line =~ s/driver name='.*?'/driver name='$conf->{sys}{server}{$key}'/;
								AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << line: [$line]\n");
							}
						}
						else
						{
							# Delete the driver
							AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Skipping the line: [$line] to remove the driver.\n");
							next;
						}
					}
				}
				if ($line =~ /<\/interface>/)
				{
					# Insert the driver, if needed.
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; this_network: [$this_network]\n");
					if ($this_network)
					{
						my $key = $this_network."_nic_driver";
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; key: [$key], sys::server::$key: [$conf->{sys}{server}{$key}]\n");
						if ($conf->{sys}{server}{$key})
						{
							# Insert it
							$new_xml .= "      <driver name='$conf->{sys}{server}{$key}'/>\n";
							AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; inserting driver: [<driver name='$conf->{sys}{server}{$key}'/>]\n");
						}
					}
					
					$in_interface = 0;
					$this_network = "";
					$this_driver  = "";
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in_interface: [$in_interface], this_network: [$this_network], this_driver: [$this_driver]\n");
				}
			}
			
			$new_xml .= "$line\n";
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; new_xml:\n====\n$new_xml\n====\n");
	}
	
	# Now write out the XML.
	$shell_call = "cat > $definition << EOF\n$new_xml\nEOF";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
	($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		#$line =~ s/^\s+//;
		#$line =~ s/\s+$//;
		next if not $line;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /virsh:(\d+)/)
		{
			$virsh_exit_code = $1;
		}
		else
		{
			push @new_vm_xml, $line;
		}
	}
	
	# Undefine the new VM
	print AN::Common::template($conf, "server.html", "general-message", {
		row	=>	"#!string!row_0094!#",
		message	=>	"#!string!message_0101!#",
	});

	undef $virsh_exit_code;
	($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	$ssh_fh,
		'close'		=>	0,
		shell_call	=>	"/usr/bin/virsh undefine $vm; echo virsh:\$?",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	my $undefine_ok = 0;
	foreach my $line (@{$output})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		next if not $line;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /virsh:(\d+)/)
		{
			$virsh_exit_code = $1;
		}
		if ($line =~ /cannot undefine transient domain/)
		{
			# This seems to be shown when trying to undefine a
			# server that has already been undefined, so treat
			# this like a success.
			$undefine_ok = 1;
		}
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; virsh exit code: [$virsh_exit_code], undefine_ok: [$undefine_ok]\n");
	$virsh_exit_code = "0" if $undefine_ok;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; virsh exit code: [$virsh_exit_code]\n");
	if ($virsh_exit_code eq "0")
	{
		print AN::Common::template($conf, "server.html", "general-message", {
			row	=>	"&nbsp;",
			message	=>	"#!string!message_0102!#",
		});
	}
	else
	{
		$virsh_exit_code = "--" if not $virsh_exit_code;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; virsh exit code: [$virsh_exit_code]\n");
		my $say_error = AN::Common::get_string($conf, {key => "message_0103", variables => {
			virsh_exit_code	=>	$virsh_exit_code,
		}});
		print AN::Common::template($conf, "server.html", "general-warning-message", {
			row	=>	"#!string!row_0044!#",
			message	=>	$say_error,
		});
	}
	
	# If I've made it this far, I am ready to add it to the cluster configuration.
	print AN::Common::template($conf, "server.html", "general-message", {
		row	=>	"#!string!row_0095!#",
		message	=>	"#!string!message_0105!#",
	});
	
	my $ccs_exit_code;
	my $ccs_call =  "ccs ";
	   $ccs_call .= "-h localhost --activate --sync --password \"$conf->{clusters}{$cluster}{ricci_pw}\" --addvm $vm ";
	   $ccs_call .= "domain=\"$failover_domain\" ";
	   $ccs_call .= "path=\"/shared/definitions/\" ";
	   $ccs_call .= "autostart=\"0\" ";
	   $ccs_call .= "exclusive=\"0\" ";
	   $ccs_call .= "recovery=\"restart\" ";
	   $ccs_call .= "max_restarts=\"2\" ";
	   $ccs_call .= "restart_expire_time=\"600\" ";
	   #$ccs_call .= "no_kill=\"1\"; echo ccs:\$?";
	   $ccs_call .= "; echo ccs:\$?";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$ccs_call]\n");
	($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	$ssh_fh,
		'close'		=>	0,
		shell_call	=>	"$ccs_call"
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		next if not $line;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /ccs:(\d+)/)
		{
			$ccs_exit_code = $1;
		}
		else
		{
			if ($line =~ /make sure the ricci server is started/)
			{
				# Tell the user that 'ricci' isn't running.
				print AN::Common::template($conf, "server.html", "general-message", {
					row	=>	"#!string!row_0044!#",
					message	=>	AN::Common::get_string($conf, {key => "message_0108", variables => {
						node	=>	$node,
					}}),
				});
				print AN::Common::template($conf, "server.html", "general-message", {
					row	=>	"&nbsp;",
					message	=>	"#!string!message_0109!#",
				});
				print AN::Common::template($conf, "server.html", "general-message", {
					row	=>	"&nbsp;",
					message	=>	"#!string!message_0110!#",
				});
			}
			else
			{
				# Show any output from the call.
				$line = parse_text_line($conf, $line);
				print AN::Common::template($conf, "server.html", "general-message", {
					row	=>	"#!string!row_0127!#",
					message	=>	"<span class=\"fixed_width\">$line</span>",
				});
			}
		}
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ccs exit code: [$ccs_exit_code]\n");
	$ccs_exit_code = "--" if not defined $ccs_exit_code;
	if ($ccs_exit_code eq "0")
	{
		print AN::Common::template($conf, "server.html", "general-message", {
			row	=>	"#!string!row_0083!#",
			message	=>	"#!string!message_0111!#",
		});
		
		### TODO: Make this watch 'clustat' for the VM to appear.
		sleep 10;
	}
	else
	{
		# ccs call failed
		print AN::Common::template($conf, "server.html", "general-error-message", {
			row	=>	"#!string!row_0096!#",
			message	=>	AN::Common::get_string($conf, {key => "message_0112", variables => {
				ccs_exit_code	=>	$ccs_exit_code,
			}}),
		});
		return (1);
	}
	# Enable/boot the server.
	print AN::Common::template($conf, "server.html", "general-message", {
		row	=>	"#!string!row_0097!#",
		message	=>	"#!string!message_0113!#",
	});
	
	### TODO: Get the cluster's idea of the node name and use '-m ...'.
	# Tell the cluster to start the VM. I don't bother to check for 
	# readiness because I confirmed it was running on this node earlier.
	my $clusvcadm_exit_code;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [clusvcadm -e vm:$vm; echo clusvcadm:\$?]\n");
	($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	$ssh_fh,
		'close'		=>	1,
		shell_call	=>	"clusvcadm -e vm:$vm; echo clusvcadm:\$?",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		next if not $line;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /clusvcadm:(\d+)/)
		{
			$clusvcadm_exit_code = $1;
		}
		else
		{
			$line = parse_text_line($conf, $line);
			print AN::Common::template($conf, "server.html", "general-message", {
				row	=>	"#!string!row_0127!#",
				message	=>	"<span class=\"fixed_width\">$line</span>",
			});
		}
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; clusvcadm exit code: [$clusvcadm_exit_code]\n");
	if ($clusvcadm_exit_code eq "0")
	{
		# Server added succcessfully.
		print AN::Common::template($conf, "server.html", "general-message", {
			row	=>	"#!string!row_0083!#",
			message	=>	"#!string!message_0114!#",
		});
	}
	else
	{
		# Appears to have failed.
		my $say_instruction = AN::Common::get_string($conf, {key => "message_0088", variables => {
			manage_url		=>	"?config=true&anvil=$cluster",
		}});
		my $say_message = AN::Common::get_string($conf, {key => "message_0115", variables => {
			clusvcadm_exit_code	=>	$clusvcadm_exit_code,
			instructions		=>	$say_instruction,
		}});
		print AN::Common::template($conf, "server.html", "general-error-message", {
			row	=>	"#!string!row_0096!#",
			message	=>	$say_message,
		});
		return (1);
	}
	# Done!
	print AN::Common::template($conf, "server.html", "add-server-to-anvil-footer");

	return (0);
}

# This looks for a VM on the cluster and returns the current host node, if any.
# If the VM is not running, then "none" is returned.
sub find_vm_host
{
	my ($conf, $node, $peer, $vm) = @_;
	my $host = "none";
	
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"/usr/bin/virsh list --all",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		next if not $line;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /\s$vm\s/)
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Found the VM.\n");
			if ($line =~ /^-/)
			{
				# It looks off... We have to go deeper!
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The VM appears to be off. Checking the peer to see if it is running there.\n");
			}
			else
			{
				# It's running.
				$host = $node;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The VM is running.\n");
				#print "It is already running, as expected.<br />\n";
			}
		}
	}
	
	if ($host eq "none")
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Looking for the VM on the peer node: [$peer].\n");
		my $on_peer = 0;
		my $found   = 0;
		my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$peer,
			port		=>	$conf->{node}{$peer}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	1,
			shell_call	=>	"/usr/bin/virsh list --all",
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			next if not $line;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /\s$vm\s/)
			{
				#print "Found it on the peer node. Checking if it's running there.<br />\n";
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Found it on the peer. Checking if it's running.\n");
				if ($line =~ /^\d/)
				{
					$found   = 1;
					$on_peer = 1;
					$node    = $peer;
					$host    = $peer;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; It is.\n");
				}
				else
				{
					$found = 1;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; It is not running on the peer.\n");
				}
			}
		}
		if (($found) && (not $on_peer))
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; I did not find it on the peer node.\n");
		}
	}
	
	return ($host);
}

# This gets the name of the bridge on the target node.
sub get_bridge_name
{
	my ($conf, $node) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; get_bridge_name(); node: [$node]\n");
	
	my $bridge     = "";
	my $shell_call = "brctl show";
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /^(.*?)\s+\d/)
		{
			$bridge = $1;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; found bridge: [$bridge]\n");
			last;
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; bridge: [$bridge]\n");
	return($bridge);
}

# This actually kicks off the VM.
sub provision_vm
{
	my ($conf) = @_;
	
	my $say_title = AN::Common::get_string($conf, {key => "title_0115", variables => {
			server	=>	$conf->{new_vm}{name},
		}});
	print AN::Common::template($conf, "server.html", "provision-server-header", {
		title	=>	$say_title,
	});
	
	# I need to know what the bridge is called.
	my $node   = $conf->{new_vm}{host_node};
	my $bridge = get_bridge_name($conf, $node);
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; new_vm::host_node: [$conf->{new_vm}{host_node}]\n");
	
	# Create the LVs
	my $provision = "";
	my @logical_volumes;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; new_vm::vg: [$conf->{new_vm}{vg}]\n");
	foreach my $vg (keys %{$conf->{new_vm}{vg}})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vg: [$vg]\n");
		for (my $i = 0; $i < @{$conf->{new_vm}{vg}{$vg}{lvcreate_size}}; $i++)
		{
			my $lv_size   = $conf->{new_vm}{vg}{$vg}{lvcreate_size}->[$i];
			my $lv_device = "/dev/$vg/$conf->{new_vm}{name}_$i";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; i: [$i], vg: [$vg], lv_size: [$lv_size], lv_device: [$lv_device]\n");
			$provision .= "if [ -e '/dev/$vg/$conf->{new_vm}{name}_$i' ];\n";
			$provision .= "then\n";
			$provision .= "\tlvremove -f /dev/$vg/$conf->{new_vm}{name}_$i\n";
			$provision .= "fi\n";
			if (lc($lv_size) eq "all")
			{
				$provision .= "lvcreate -l 100\%FREE -n $conf->{new_vm}{name}_$i $vg\n";
			}
			elsif ($lv_size =~ /^(\d+\.?\d+?)%$/)
			{
				my $size = $1;
				$provision .= "lvcreate -l $size\%FREE -n $conf->{new_vm}{name}_$i $vg\n";
			}
			else
			{
				$provision .= "lvcreate -L ${lv_size}GiB -n $conf->{new_vm}{name}_$i $vg\n";
			}
			push @logical_volumes, $lv_device;
		}
	}
	
	# Setup the 'virt-install' call.
	$provision .= "virt-install --connect qemu:///system \\\\\n";
	$provision .= "  --name $conf->{new_vm}{name} \\\\\n";
	$provision .= "  --ram $conf->{new_vm}{ram} \\\\\n";
	$provision .= "  --arch x86_64 \\\\\n";
	$provision .= "  --vcpus $conf->{new_vm}{cpu_cores} \\\\\n";
	$provision .= "  --cdrom '/shared/files/$conf->{new_vm}{install_iso}' \\\\\n";
	$provision .= "  --boot menu=on \\\\\n";
	if ($conf->{cgi}{driver_iso})
	{
		$provision .= "  --disk path='/shared/files/$conf->{new_vm}{driver_iso}',device=cdrom --force\\\\\n";
	}
	$provision .= "  --os-variant $conf->{cgi}{os_variant} \\\\\n";
	
	# Connect to the discovered bridge
	my $nic_driver = "virtio";
	if (not $conf->{new_vm}{virtio}{nic})
	{
		$nic_driver = $conf->{sys}{server}{alternate_nic_model} ? $conf->{sys}{server}{alternate_nic_model} : "e1000";
	}
	$conf->{sys}{server}{nic_count} = 1 if not $conf->{sys}{server}{nic_count};
	for (1..$conf->{sys}{server}{nic_count})
	{
		$provision .= "  --network bridge=$bridge,model=$nic_driver \\\\\n";
	}
	
	foreach my $lv_device (@logical_volumes)
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lv_device: [$lv_device], use virtio: [$conf->{new_vm}{virtio}{disk}]\n");
		$provision .= "  --disk path=$lv_device";
		if ($conf->{new_vm}{virtio}{disk})
		{
			$provision .= ",bus=virtio";
		}
		$provision .= " \\\\\n";
	}
	$provision .= "  --graphics spice \\\\\n";
	# See https://www.redhat.com/archives/virt-tools-list/2014-August/msg00078.html
	# for why we're using '--noautoconsole --wait -1'.
	$provision .= "  --noautoconsole --wait -1 > /var/log/an-install_".$conf->{new_vm}{name}.".log &\n";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; provision:\n$provision\n");
	
	### TODO: Make sure the desired node is up and, if not, use the one
	###       good node.
	
	# Push the provision script into a file.
	my $shell_script = "/shared/provision/$conf->{new_vm}{name}.sh";
	print AN::Common::template($conf, "server.html", "one-line-message", {
		message	=>	"#!string!message_0118!#",
	}, {
		script	=>	$shell_script,
	});
	my $shell_call = "echo \"$provision\" > $shell_script && chmod 755 $shell_script";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
	}
	print AN::Common::template($conf, "server.html", "one-line-message", {
		message	=>	"#!string!message_0119!#",
	}, {
		server	=>	$conf->{new_vm}{name},
	});
	
	### NOTE: Don't try to redirect output (2>&1 |), it causes errors I've
	###       not yet solved.
	# Run the script.
	$shell_call = "$shell_script";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
	($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	$ssh_fh,
		'close'		=>	1,
		shell_call	=>	$shell_call,
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	$error = 0;
	foreach my $line (@{$output})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		next if $line =~ /One or more specified logical volume\(s\) not found./;
		if ($line =~ /No such file or directory/i)
		{
			 # Failed to write the provision file.
			$error = AN::Common::get_string($conf, {key => "message_0330", variables => {
				provision_script	=>	$shell_script,
			}});
		}
		if ($line =~ /Unable to read from monitor/i)
		{
			### TODO: Delete the just-created LV
			# This can be caused by insufficient free RAM
			$error = AN::Common::get_string($conf, {key => "message_0437", variables => {
				server		=>	$conf->{new_vm}{name},
				node		=>	$node,
			}});
		}
		if ($line =~ /syntax error/i)
		{
			# Something is wrong with the provision script
			$error = AN::Common::get_string($conf, {key => "message_0438", variables => {
				provision_script	=>	$shell_script,
				error			=>	$line,
			}});
		}
		### Supressing output to clean-up what the user sees.
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		#print AN::Common::template($conf, "server.html", "one-line-message-fixed-width", {
		#	message	=>	"$line",
		#});
	}
	if ($error)
	{
		print AN::Common::template($conf, "server.html", "provision-server-problem", {
			message	=>	$error,
		});
	}
	else
	{
		print AN::Common::template($conf, "server.html", "one-line-message", {
			message	=>	"#!string!message_0120!#",
		});
		
		# Verify that the new VM is running.
		my $shell_call = "sleep 3; virsh list | grep -q '$conf->{new_vm}{name}'; echo rc:\$?";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			chomp;
			my $line = $_;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /^rc:(\d+)/)
			{
				# 0 == found
				# 1 == not found
				my $rc = $1;
				if ($rc eq "1")
				{
					# Server wasn't created, it seems.
					print AN::Common::template($conf, "server.html", "provision-server-problem", {
						message	=>	"#!string!message_0434!#",
					});
					$error = 1;
				}
			}
		}
	}
	
	# Done!
	#print AN::Common::template($conf, "server.html", "provision-server-footer");
	
	# Add the server to the cluster if no errors exist.
	if (not $error)
	{
		# Add it and then change the boot device to 'hd'.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; host_node: [$conf->{new_vm}{host_node}]\n");
		add_vm_to_cluster($conf, 1);
	}
	
	return (0);
}

# This sanity-checks the requested VM config prior to creating the VM itself.
sub verify_vm_config
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; verify_vm_config()\n");
	
	# First, get a current view of the cluster.
	my $proceed = 1;
	AN::Cluster::scan_cluster($conf);
	AN::Cluster::read_files_on_shared($conf);
	
	# If we connected, start parsing.
	my $cluster = $conf->{cgi}{cluster};
	my @errors;
	if ($conf->{sys}{up_nodes})
	{
		# Did the user name the VM?
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::name: [$conf->{cgi}{name}]\n");
		if ($conf->{cgi}{name})
		{
			# Normally, it's safer to only allow a subset of
			# characters, but it would be nice to allow users to 
			# name their servers using non-latin characters, so for
			# now, we look for bad characters only.
			$conf->{cgi}{name} =~ s/^\s+//;
			$conf->{cgi}{name} =~ s/\s+$//;
			if ($conf->{cgi}{name} =~ /\s/)
			{
				# Bad name, no spaces allowed.
				my $say_row     = AN::Common::get_string($conf, {key => "row_0102"});
				my $say_message = AN::Common::get_string($conf, {key => "message_0127"});
				push @errors, "$say_row#!#$say_message";
			}
			# If this changes, remember to update message_0127!
			elsif (($conf->{cgi}{name} =~ /;/) || 
			       ($conf->{cgi}{name} =~ /&/) || 
			       ($conf->{cgi}{name} =~ /\|/) || 
			       ($conf->{cgi}{name} =~ /\$/) || 
			       ($conf->{cgi}{name} =~ />/) || 
			       ($conf->{cgi}{name} =~ /</) || 
			       ($conf->{cgi}{name} =~ /\[/) || 
			       ($conf->{cgi}{name} =~ /\]/) || 
			       ($conf->{cgi}{name} =~ /\(/) || 
			       ($conf->{cgi}{name} =~ /\)/) || 
			       ($conf->{cgi}{name} =~ /}/) || 
			       ($conf->{cgi}{name} =~ /{/) || 
			       ($conf->{cgi}{name} =~ /!/) || 
			       ($conf->{cgi}{name} =~ /\^/))
			{
				# Illegal characters.
				my $say_row     = AN::Common::get_string($conf, {key => "row_0102"});
				my $say_message = AN::Common::get_string($conf, {key => "message_0127"});
				push @errors, "$say_row#!#$say_message";
			}
			else
			{
				my $vm     = $conf->{cgi}{name};
				my $vm_key = "vm:$vm";
				if (exists $conf->{vm}{$vm_key})
				{
					# Duplicate name
					my $say_row     = AN::Common::get_string($conf, {key => "row_0103"});
					my $say_message = AN::Common::get_string($conf, {key => "message_0128", variables => {
						server	=>	$vm,
					}});
					push @errors, "$say_row#!#$say_message";
				}
				else
				{
					# Name is OK
					$conf->{new_vm}{name} = $vm;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; new_vm::name: [$conf->{new_vm}{name}]\n");
				}
			}
		}
		else
		{
			# Missing server name
			my $say_row     = AN::Common::get_string($conf, {key => "row_0104"});
			my $say_message = AN::Common::get_string($conf, {key => "message_0129"});
			push @errors, "$say_row#!#$say_message";
		}
		
		# Did the user ask for too many cores?
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::cpu_cores: [$conf->{cgi}{cpu_cores}], resources::total_threads: [$conf->{resources}{total_threads}]\n");
		if ($conf->{cgi}{cpu_cores} =~ /\D/)
		{
			# Not a digit.
			my $say_row     = AN::Common::get_string($conf, {key => "row_0105"});
			my $say_message = AN::Common::get_string($conf, {key => "message_0130", variables => {
				cpu_cores	=>	$conf->{cgi}{cpu_cores},
			}});
			push @errors, "$say_row#!#$say_message";
		}
		elsif ($conf->{cgi}{cpu_cores} > $conf->{resources}{total_threads})
		{
			# Not enough cores
			my $say_row     = AN::Common::get_string($conf, {key => "row_0106"});
			my $say_message = AN::Common::get_string($conf, {key => "message_0131", variables => {
				total_threads	=>	$conf->{resources}{total_threads},
				cpu_cores	=>	$conf->{cgi}{cpu_cores},
			}});
			push @errors, "$say_row#!#$say_message";
		}
		else
		{
			$conf->{new_vm}{cpu_cores} = $conf->{cgi}{cpu_cores};
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; new_vm::cpu_cores: [$conf->{new_vm}{cpu_cores}]\n");
		}
		
		# Now what about RAM?
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::ram: [$conf->{cgi}{ram}]\n");
		if (($conf->{cgi}{ram} =~ /\D/) && ($conf->{cgi}{ram} !~ /^\d+\.\d+$/))
		{
			# RAM amount isn't a digit...
			my $say_row     = AN::Common::get_string($conf, {key => "row_0107"});
			my $say_message = AN::Common::get_string($conf, {key => "message_0132", variables => {
				ram	=>	$conf->{cgi}{ram},
			}});
			push @errors, "$say_row#!#$say_message";
		}
		my $requested_ram = AN::Cluster::hr_to_bytes($conf, $conf->{cgi}{ram}, $conf->{cgi}{ram_suffix});
		my $diff          = $conf->{resources}{total_ram} % (1024 ** 3);
		my $available_ram = $conf->{resources}{total_ram} - $diff - $conf->{sys}{unusable_ram};
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; requested_ram: [$requested_ram], available_ram: [$available_ram]\n");
		if ($requested_ram > $available_ram)
		{
			# Requested too much RAM.
			my $say_free_ram  = AN::Cluster::bytes_to_hr($conf, $available_ram);
			my $say_requested = AN::Cluster::bytes_to_hr($conf, $requested_ram);
			my $say_row       = AN::Common::get_string($conf, {key => "row_0108"});
			my $say_message   = AN::Common::get_string($conf, {key => "message_0133", variables => {
				free_ram	=>	$say_free_ram,
				requested_ram	=>	$say_requested,
			}});
			push @errors, "$say_row#!#$say_message";
		}
		else
		{
			# RAM is specified as a number of MiB.
			my $say_ram = sprintf("%.0f", ($requested_ram /= (2 ** 20)));
			$conf->{new_vm}{ram} = $say_ram;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; new_vm::ram: [$conf->{new_vm}{ram}]\n");
		}
		
		# Look at the selected storage. if VGs named for two separate
		# nodes are defined, error.
		$conf->{new_vm}{host_node} = "";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; host_node: [$conf->{new_vm}{host_node}], vg_list: [$conf->{cgi}{vg_list}]\n");
		foreach my $vg (split /,/, $conf->{cgi}{vg_list})
		{
			my $short_vg   = $vg;
			my $short_node = $vg;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; short_vg: [$short_vg], short_node: [$short_node], vg: [$vg]\n");
			if ($vg =~ /^(.*?)_(vg\d+)$/)
			{
				$short_node = $1;
				$short_vg   = $2;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; short_vg: [$short_vg], short_node: [$short_node]\n");
			}
			my $say_node      = $short_node;
			my $vg_key        = "vg_$vg";
			my $vg_suffix_key = "vg_suffix_$vg";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_node: [$say_node], vg_key: [$vg_key], vg_suffix_key: [$vg_suffix_key]\n");
			next if not $conf->{cgi}{$vg_key};
			foreach my $node (sort {$a cmp $b} @{$conf->{clusters}{$cluster}{nodes}})
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], short_node: [$short_node]\n");
				if ($node =~ /$short_node/)
				{
					$say_node = $node;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_node: [$say_node]\n");
					last;
				}
			}
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; host_node: [$conf->{new_vm}{host_node}]\n");
			if (not $conf->{new_vm}{host_node})
			{
				$conf->{new_vm}{host_node} = $say_node;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; host_node: [$conf->{new_vm}{host_node}]\n");
			}
			elsif ($conf->{new_vm}{host_node} ne $say_node)
			{
				# Conflicting Storage
				my $say_row     = AN::Common::get_string($conf, {key => "row_0109"});
				my $say_message = AN::Common::get_string($conf, {key => "message_0134"});
				push @errors, "$say_row#!#$say_message";
			}
			
			# Setup the 'lvcreate' call
			foreach my $lv_size (split/:/, $conf->{cgi}{$vg_key})
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lv_size: [$lv_size]\n");
				if ($lv_size eq "all")
				{
					push @{$conf->{new_vm}{vg}{$vg}{lvcreate_size}}, "all";
				}
				elsif ($conf->{cgi}{$vg_suffix_key} eq "%")
				{
					push @{$conf->{new_vm}{vg}{$vg}{lvcreate_size}}, "${lv_size}%";
				}
				else
				{
					# Make to lvcreate command a GiB value.
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::${vg_key}: [$lv_size], cgi::${vg_suffix_key}: [$conf->{cgi}{$vg_suffix_key}]\n");
					
					my $lv_size = AN::Cluster::hr_to_bytes($conf, $lv_size, $conf->{cgi}{$vg_suffix_key});
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; > lv_size: [$lv_size]\n");
					$lv_size    = sprintf("%.0f", ($lv_size /= (2 ** 30)));
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; < lv_size: [$lv_size]\n");
					
					push @{$conf->{new_vm}{vg}{$vg}{lvcreate_size}}, "$lv_size";
				}
			}
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; host_node: [$conf->{new_vm}{host_node}]\n");
		
		# Make sure the user specified an install disc.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::install_iso: [$conf->{cgi}{install_iso}]\n");
		if ($conf->{cgi}{install_iso})
		{
			my $file_name = $conf->{cgi}{install_iso};
			if (exists $conf->{files}{shared}{$file_name})
			{
				$conf->{new_vm}{install_iso} = $conf->{cgi}{install_iso};
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; new_vm::install_iso: [$conf->{new_vm}{install_iso}]\n");
			}
			else
			{
				# Dude, where's my ISO?
				my $say_row     = AN::Common::get_string($conf, {key => "row_0110"});
				my $say_message = AN::Common::get_string($conf, {key => "message_0135"});
				push @errors, "$say_row#!#$say_message";
			}
		}
		else
		{
			# The user needs an install source...
			my $say_row     = AN::Common::get_string($conf, {key => "row_0110"});
			my $say_message = AN::Common::get_string($conf, {key => "message_0136"});
			push @errors, "$say_row#!#$say_message";
		}
		
		# A few OSes we set don't match a real os-variant. Swap them here.
		if ($conf->{cgi}{os_variant} eq "debianjessie")
		{
			# Debian is modern enough so we'll use the 'rhel7' variant.
			$conf->{cgi}{os_variant} = "rhel7";
		}
		
		### TODO: Find a better way to determine this.
		# Look at the OS type to try and determine if 'e1000' or
		# 'virtio' should be used by the network.
		$conf->{new_vm}{virtio}{nic}  = 0;
		$conf->{new_vm}{virtio}{disk} = 0;
		if (($conf->{cgi}{os_variant} =~ /fedora1\d/) || 
		    ($conf->{cgi}{os_variant} =~ /virtio/) || 
		    ($conf->{cgi}{os_variant} =~ /ubuntu/) || 
		    ($conf->{cgi}{os_variant} =~ /sles11/) || 
		    ($conf->{cgi}{os_variant} =~ /rhel5/) || 
		    ($conf->{cgi}{os_variant} =~ /rhel6/) || 
		    ($conf->{cgi}{os_variant} =~ /rhel7/))
		{
			$conf->{new_vm}{virtio}{disk} = 1;
			$conf->{new_vm}{virtio}{nic}  = 1;
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; new_vm::virtio::disk: [$conf->{new_vm}{virtio}{disk}], new_vm::virtio::nic: [$conf->{new_vm}{virtio}{nic}]\n");
		
		# Optional driver disk, enables virtio when appropriate
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::driver_iso: [$conf->{cgi}{driver_iso}]\n");
		if ($conf->{cgi}{driver_iso})
		{
			my $file_name = $conf->{cgi}{driver_iso};
			if (exists $conf->{files}{shared}{$file_name})
			{
				$conf->{new_vm}{driver_iso} = $conf->{cgi}{driver_iso};
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; new_vm::driver_iso: [$conf->{new_vm}{driver_iso}]\n");
			}
			else
			{
				# Install media no longer exists.
				my $say_row     = AN::Common::get_string($conf, {key => "row_0111"});
				my $say_message = AN::Common::get_string($conf, {key => "message_0137"});
				push @errors, "$say_row#!#$say_message";
			}
			
			if (lc($file_name) =~ /virtio/)
			{
				$conf->{new_vm}{virtio}{disk} = 1;
				$conf->{new_vm}{virtio}{nic}  = 1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; new_vm::virtio::disk: [$conf->{new_vm}{virtio}{disk}], new_vm::virtio::nic: [$conf->{new_vm}{virtio}{nic}]\n");
			}
		}
		
		# Make sure a valid os-variant was passed.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::os_variant: [$conf->{cgi}{os_variant}]\n");
		if ($conf->{cgi}{os_variant})
		{
			my $match = 0;
			foreach my $os_variant (@{$conf->{sys}{os_variant}})
			{
				my ($short_name, $desc) = ($os_variant =~ /^(.*?)#!#(.*)$/);
				if ($conf->{cgi}{os_variant} eq $short_name)
				{
					$match = 1;
				}
			}
			if (not $match)
			{
				# OS variant specified but invalid
				my $say_row     = AN::Common::get_string($conf, {key => "row_0112"});
				my $say_message = AN::Common::get_string($conf, {key => "message_0138"});
				push @errors, "$say_row#!#$say_message";
			}
		}
		else
		{
			# No OS variant specified.
			my $say_row     = AN::Common::get_string($conf, {key => "row_0113"});
			my $say_message = AN::Common::get_string($conf, {key => "message_0139"});
			push @errors, "$say_row#!#$say_message";
		}
		
		# If there were errors, push the user back to the form.
		if (@errors > 0)
		{
			$proceed = 0;
			print AN::Common::template($conf, "server.html", "verify-server-header");
			
			foreach my $error (@errors)
			{
				my ($title, $body) = ($error =~ /^(.*?)#!#(.*)$/);
				print AN::Common::template($conf, "server.html", "verify-server-error", {
					title	=>	$title,
					body	=>	$body,
				});
			}
			print AN::Common::template($conf, "server.html", "verify-server-footer");
		}
	}
	else
	{
		# Failed to connect to the cluster, errors should already be
		# reported to the user.
	}
	# Check the currently available resources on the cluster.
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; proceed: [$proceed]\n");
	return ($proceed);
}

# This doesn't so much confirm as it does ask the user how they want to build
# the VM.
sub confirm_provision_vm
{
	my ($conf) = @_;
	
	my ($node) = AN::Cluster::read_files_on_shared($conf);
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; read file list from node: [$node]\n");
	return if not $node;
	
	my $cluster = $conf->{cgi}{cluster};
	my $images  = [];
	foreach my $file (sort {$a cmp $b} keys %{$conf->{files}{shared}})
	{
		next if $file !~ /iso$/i;
		push @{$images}, $file;
	}
	my $cpu_cores = [];
	foreach my $core_num (1..$conf->{cgi}{max_cores})
	{
		if ($conf->{cgi}{max_cores} > 9)
		{
			#push @{$cpu_cores}, sprintf("%.2d", $core_num);
			push @{$cpu_cores}, $core_num;
		}
		else
		{
			push @{$cpu_cores}, $core_num;
		}
	}
	$conf->{cgi}{cpu_cores}  = 2 if not $conf->{cgi}{cpu_cores};
	my $select_cpu_cores     = AN::Cluster::build_select($conf, "cpu_cores", 0, 0, 60, $conf->{cgi}{cpu_cores}, $cpu_cores);
	foreach my $storage (sort {$a cmp $b} split/,/, $conf->{cgi}{max_storage})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; storage: [$storage]\n");
		my ($vg, $space)             =  ($storage =~ /^(.*?):(\d+)$/);
		my $say_max_storage          =  AN::Cluster::bytes_to_hr($conf, $space);
		$say_max_storage             =~ s/\.(\d+)//;
		$conf->{cgi}{vg_list}        .= "$vg,";
		my $vg_key                   =  "vg_$vg";
		my $vg_suffix_key            =  "vg_suffix_$vg";
		$conf->{cgi}{$vg_key}        =  ""    if not $conf->{cgi}{$vg_key};
		$conf->{cgi}{$vg_suffix_key} =  "GiB" if not $conf->{cgi}{$vg_suffix_key};
		my $select_vg_suffix         =  AN::Cluster::build_select($conf, "$vg_suffix_key", 0, 0, 60, $conf->{cgi}{$vg_suffix_key}, ["MiB", "GiB", "TiB", "%"]);
		if ($space < (2 ** 30))
		{
			# Less than a Terabyte
			$select_vg_suffix            = AN::Cluster::build_select($conf, "$vg_suffix_key", 0, 0, 60, $conf->{cgi}{$vg_suffix_key}, ["MiB", "GiB", "%"]);
			$conf->{cgi}{$vg_suffix_key} = "GiB" if not $conf->{cgi}{$vg_suffix_key};
		}
		elsif ($space < (2 ** 20))
		{
			# Less than a Gigabyte
			$select_vg_suffix            = AN::Cluster::build_select($conf, "$vg_suffix_key", 0, 0, 60, $conf->{cgi}{$vg_suffix_key}, ["MiB", "%"]);
			$conf->{cgi}{$vg_suffix_key} = "MiB" if not $conf->{cgi}{$vg_suffix_key};
		}
		# Devine the node associated with this VG.
		my $short_vg   =  $vg;
		my $short_node =  $vg;
		if ($vg =~ /^(.*?)_(vg\d+)$/)
		{
			$short_node = $1;
			$short_vg   = $2;
		}
		my $say_node =  $short_vg;
		foreach my $node (sort {$a cmp $b} @{$conf->{clusters}{$cluster}{nodes}})
		{
			if ($node =~ /$short_node/)
			{
				$say_node = $node;
				last;
			}
		}
		
		$conf->{vg_selects}{$vg}{space}         = $space;
		$conf->{vg_selects}{$vg}{say_storage}   = $say_max_storage;
		$conf->{vg_selects}{$vg}{select_suffix} = $select_vg_suffix;
		$conf->{vg_selects}{$vg}{say_node}      = $say_node;
		$conf->{vg_selects}{$vg}{short_vg}      = $short_vg;
	}
	my $say_selects;
	my $say_or      = AN::Common::template($conf, "server.html", "provision-server-storage-pool-or-message", {}, {}, 1);
	foreach my $vg (sort {$a cmp $b} keys %{$conf->{vg_selects}})
	{
		my $space            =  $conf->{vg_selects}{$vg}{space};
		my $say_max_storage  =  $conf->{vg_selects}{$vg}{say_storage};
		my $select_vg_suffix =  $conf->{vg_selects}{$vg}{select_suffix};
		my $say_node         =  $conf->{vg_selects}{$vg}{say_node};
		   $say_node         =~ s/\..*$//;
		my $short_vg         =  $conf->{vg_selects}{$vg}{short_vg};
		my $vg_key           =  "vg_$vg";
		   $say_selects      .= AN::Common::template($conf, "server.html", "provision-server-selects", {
			node			=>	$say_node,
			short_vg		=>	$short_vg,
			max_storage		=>	$say_max_storage,
			vg_key			=>	$vg_key,
			vg_key_value		=>	$conf->{cgi}{$vg_key},
			select_vg_suffix	=>	$select_vg_suffix,
		});
		$say_selects .= "$say_or";
	}
	$say_selects =~ s/$say_or$//m;
	$say_selects .= AN::Common::template($conf, "server.html", "provision-server-vg-list-hidden-input", {
		vg_list	=>	$conf->{cgi}{vg_list},
	});
	my $say_max_ram          = AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{max_ram});
	$conf->{cgi}{ram}        = 2 if not $conf->{cgi}{ram};
	$conf->{cgi}{ram_suffix} = "GiB" if not $conf->{cgi}{ram_suffix};
	my $select_ram_suffix    = AN::Cluster::build_select($conf, "ram_suffix", 0, 0, 60, $conf->{cgi}{ram_suffix}, ["MiB", "GiB"]);
	$conf->{cgi}{os_variant} = "generic" if not $conf->{cgi}{os_variant};
	my $select_install_iso   = AN::Cluster::build_select($conf, "install_iso", 1, 1, 300, $conf->{cgi}{install_iso}, $images);
	my $select_driver_iso    = AN::Cluster::build_select($conf, "driver_iso", 1, 1, 300, $conf->{cgi}{driver_iso}, $images);
	my $select_os_variant    = AN::Cluster::build_select($conf, "os_variant", 1, 0, 300, $conf->{cgi}{os_variant}, $conf->{sys}{os_variant});
	
	my $say_title = AN::Common::get_string($conf, {key => "message_0142", variables => {
		anvil	=>	$conf->{cgi}{cluster},
	}});
	print AN::Common::template($conf, "server.html", "provision-server-questions", {
		title			=>	$say_title,
		name			=>	$conf->{cgi}{name},
		select_os_variant	=>	$select_os_variant,
		media_library_url	=>	"mediaLibrary?cluster=$conf->{cgi}{cluster}",
		select_install_iso	=>	$select_install_iso,
		select_driver_iso	=>	$select_driver_iso,
		say_max_ram		=>	$say_max_ram,
		ram			=>	$conf->{cgi}{ram},
		select_ram_suffix	=>	$select_ram_suffix,
		select_cpu_cores	=>	$select_cpu_cores,
		selects			=>	$say_selects,
		anvil			=>	$conf->{cgi}{cluster},
		task			=>	$conf->{cgi}{task},
		max_ram			=>	$conf->{cgi}{max_ram},
		max_cores		=>	$conf->{cgi}{max_cores},
		max_storage		=>	$conf->{cgi}{max_storage},
	});
	
	return (0);
}

# Confirm that the user wants to join both nodes to the cluster.
sub confirm_withdraw_node
{
	my ($conf) = @_;
	
	# Ask the user to confirm
	my $say_title = AN::Common::get_string($conf, {key => "title_0035", variables => {
		node_anvil_name	=>	$conf->{cgi}{node_cluster_name},
		anvil		=>	$conf->{cgi}{cluster},
	}});
	my $say_message = AN::Common::get_string($conf, {key => "message_0145", variables => {
		node_anvil_name	=>	$conf->{cgi}{node_cluster_name},
	}});
	print AN::Common::template($conf, "server.html", "confirm-withdrawl", {
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	"$conf->{sys}{cgi_string}&confirm=true",
	});
	
	return (0);
}

# Confirm that the user wants to join a node to the cluster.
sub confirm_join_cluster
{
	my ($conf) = @_;
	
	# Ask the user to confirm
	my $say_title = AN::Common::get_string($conf, {key => "title_0036", variables => {
		node_anvil_name	=>	$conf->{cgi}{node_cluster_name},
		anvil		=>	$conf->{cgi}{cluster},
	}});
	my $say_message = AN::Common::get_string($conf, {key => "message_0147", variables => {
		node_anvil_name	=>	$conf->{cgi}{node_cluster_name},
	}});
	print AN::Common::template($conf, "server.html", "confirm-join-anvil", {
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	"$conf->{sys}{cgi_string}&confirm=true",
	});

	return (0);
}

# Confirm that the user wants to join both nodes to the cluster.
sub confirm_dual_join
{
	my ($conf) = @_;
	
	# Ask the user to confirm
	my $say_title = AN::Common::get_string($conf, {key => "title_0037", variables => {
		anvil	=>	$conf->{cgi}{cluster},
	}});
	my $say_message = AN::Common::get_string($conf, {key => "message_0150", variables => {
		anvil	=>	$conf->{cgi}{cluster},
	}});
	print AN::Common::template($conf, "server.html", "confirm-dual-join-anvil", {
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	"$conf->{sys}{cgi_string}&confirm=true",
	});
	
	return (0);
}

# Confirm that the user wants to fence a nodes.
sub confirm_fence_node
{
	my ($conf) = @_;
	
	# Ask the user to confirm
	my $say_title = AN::Common::get_string($conf, {key => "title_0038", variables => {
		node_anvil_name	=>	$conf->{cgi}{node_cluster_name},
	}});
	my $say_message = AN::Common::get_string($conf, {key => "message_0151", variables => {
		node_anvil_name	=>	$conf->{cgi}{node_cluster_name},
	}});
	my $expire_time = time + $conf->{sys}{actime_timeout};
	$conf->{sys}{cgi_string} =~ s/expire=(\d+)/expire=$expire_time/;
	print AN::Common::template($conf, "server.html", "confirm-fence-node", {
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	"$conf->{sys}{cgi_string}&confirm=true",
	});

	return (0);
}

# Confirm that the user wants to power-off a nodes.
sub confirm_poweroff_node
{
	my ($conf) = @_;
	
	# Ask the user to confirm
	my $say_title = AN::Common::get_string($conf, {key => "title_0039", variables => {
		node_anvil_name	=>	$conf->{cgi}{node_cluster_name},
	}});
	my $say_message = AN::Common::get_string($conf, {key => "message_0156", variables => {
		node_anvil_name	=>	$conf->{cgi}{node_cluster_name},
	}});
	my $expire_time = time + $conf->{sys}{actime_timeout};
	$conf->{sys}{cgi_string} =~ s/expire=(\d+)/expire=$expire_time/;
	print AN::Common::template($conf, "server.html", "confirm-poweroff-node", {
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	"$conf->{sys}{cgi_string}&confirm=true",
	});
	
	return (0);
}

# Confirm that the user wants to boot a nodes.
sub confirm_poweron_node
{
	my ($conf) = @_;
	
	# Ask the user to confirm
	my $say_title = AN::Common::get_string($conf, {key => "title_0040", variables => {
		node_anvil_name	=>	$conf->{cgi}{node_cluster_name},
	}});
	my $say_message = AN::Common::get_string($conf, {key => "message_0160", variables => {
		node_anvil_name	=>	$conf->{cgi}{node_cluster_name},
	}});
	print AN::Common::template($conf, "server.html", "confirm-poweron-node", {
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	"$conf->{sys}{cgi_string}&confirm=true",
	});

	return (0);
}

# Confirm that the user wants to boot both nodes.
sub confirm_dual_boot
{
	my ($conf) = @_;
	
	# Ask the user to confirm
	my $say_message = AN::Common::get_string($conf, {key => "message_0161", variables => {
		anvil	=>	$conf->{cgi}{cluster},
	}});
	print AN::Common::template($conf, "server.html", "confirm-dual-poweron-node", {
		message		=>	$say_message,
		confirm_url	=>	"$conf->{sys}{cgi_string}&confirm=true",
	});

	return (0);
}

# Confirm that the user wants to cold-stop the Anvil!.
sub confirm_cold_stop_anvil
{
	my ($conf) = @_;
	
	# Ask the user to confirm
	my $say_message = AN::Common::get_string($conf, {key => "message_0418", variables => {
		anvil	=>	$conf->{cgi}{cluster},
	}});
	
	# If there is a subtype, use a different warning.
	if ($conf->{cgi}{subtask} eq "power_cycle")
	{
		$say_message = AN::Common::get_string($conf, {key => "message_0439", variables => {
			anvil	=>	$conf->{cgi}{cluster},
		}});
	}
	elsif($conf->{cgi}{subtask} eq "power_off")
	{
		$say_message = AN::Common::get_string($conf, {key => "message_0440", variables => {
			anvil	=>	$conf->{cgi}{cluster},
		}});
	}
	
	my $expire_time = time + $conf->{sys}{actime_timeout};
	$conf->{sys}{cgi_string} =~ s/expire=(\d+)/expire=$expire_time/;
	print AN::Common::template($conf, "server.html", "confirm-cold-stop", {
		message		=>	$say_message,
		confirm_url	=>	"$conf->{sys}{cgi_string}&confirm=true",
	});

	return (0);
}

# Confirm that the user wants to start a VM.
sub confirm_start_vm
{
	my ($conf) = @_;
	
	# Ask the user to confirm
	my $say_title = AN::Common::get_string($conf, {key => "title_0042", variables => {
		server		=>	$conf->{cgi}{vm},
		node_anvil_name	=>	$conf->{cgi}{node_cluster_name},
	}});
	my $say_message = AN::Common::get_string($conf, {key => "message_0163", variables => {
		server		=>	$conf->{cgi}{vm},
		node_anvil_name	=>	$conf->{cgi}{node_cluster_name},
	}});
	print AN::Common::template($conf, "server.html", "confirm-start-server", {
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	"$conf->{sys}{cgi_string}&confirm=true",
	});

	return (0);
}	

# Confirm that the user wants to stop a VM.
sub confirm_stop_vm
{
	my ($conf) = @_;
	
	# Ask the user to confirm
	my $say_title = AN::Common::get_string($conf, {key => "title_0043", variables => {
		server		=>	$conf->{cgi}{vm},
	}});
	my $say_message = AN::Common::get_string($conf, {key => "message_0165", variables => {
		server		=>	$conf->{cgi}{vm},
		node_anvil_name	=>	$conf->{cgi}{node_cluster_name},
	}});
	my $say_warning = AN::Common::get_string($conf, {key => "message_0166", variables => {
		server		=>	$conf->{cgi}{vm},
	}});
	my $say_precaution = AN::Common::get_string($conf, {key => "message_0167", variables => {
		node_anvil_name	=>	$conf->{cgi}{node_cluster_name},
	}});
	my $expire_time = time + $conf->{sys}{actime_timeout};
	$conf->{sys}{cgi_string} =~ s/expire=(\d+)/expire=$expire_time/;
	print AN::Common::template($conf, "server.html", "confirm-stop-server", {
		title		=>	$say_title,
		message		=>	$say_message,
		warning		=>	$say_warning,
		precaution	=>	$say_precaution,
		confirm_url	=>	"$conf->{sys}{cgi_string}&confirm=true",
	});

	return (0);
}

# Confirm that the user wants to force-off a VM.
sub confirm_force_off_vm
{
	my ($conf) = @_;
	
	# Ask the user to confirm
	my $say_title = AN::Common::get_string($conf, {key => "title_0044", variables => {
		server		=>	$conf->{cgi}{vm},
	}});
	my $say_message = AN::Common::get_string($conf, {key => "message_0168", variables => {
		server		=>	$conf->{cgi}{vm},
		host		=>	$conf->{cgi}{host},
	}});
	my $expire_time = time + $conf->{sys}{actime_timeout};
	$conf->{sys}{cgi_string} =~ s/expire=(\d+)/expire=$expire_time/;
	print AN::Common::template($conf, "server.html", "confirm-force-off-server", {
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	"$conf->{sys}{cgi_string}&confirm=true",
	});
	
	return (0);
}

# Confirm that the user wants to migrate a VM.
sub confirm_delete_vm
{
	my ($conf) = @_;

	# Ask the user to confirm
	my $say_title = AN::Common::get_string($conf, {key => "title_0045", variables => {
		server		=>	$conf->{cgi}{vm},
	}});
	my $say_message = AN::Common::get_string($conf, {key => "message_0178", variables => {
		server		=>	$conf->{cgi}{vm},
	}});
	print AN::Common::template($conf, "server.html", "confirm-delete-server", {
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	"$conf->{sys}{cgi_string}&confirm=true",
	});
	
	return (0);
}

# Confirm that the user wants to migrate a VM.
sub confirm_migrate_vm
{
	my ($conf) = @_;
	
	# Calculate roughly how long the migration will take.
	my $migration_time_estimate = $conf->{cgi}{vm_ram} / 1073741824; # Get # of GB.
	$migration_time_estimate *= 10; # ~10s / GB

	# Ask the user to confirm
	my $say_title = AN::Common::get_string($conf, {key => "title_0047", variables => {
		server		=>	$conf->{cgi}{vm},
		target		=>	$conf->{cgi}{target},
	}});
	my $say_message = AN::Common::get_string($conf, {key => "message_0177", variables => {
		server			=>	$conf->{cgi}{vm},
		target			=>	$conf->{cgi}{target},
		ram			=>	AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{vm_ram}),
		migration_time_estimate	=>	$migration_time_estimate,
	}});
	print AN::Common::template($conf, "server.html", "confirm-migrate-server", {
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	"$conf->{sys}{cgi_string}&confirm=true",
	});
	
	return (0);
}

# This boots a VM on a target node.
sub start_vm
{
	my ($conf) = @_;
	
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	my $vm                = $conf->{cgi}{vm};
	my $say_vm            = $vm =~ /^vm:/ ? ($vm =~ /vm:(.*)/)[0] : $vm;
	my $remote_message    = "";
	my $remote_icon       = "";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], say_vm: [$say_vm], node: [$node], node_cluster_name: [$node_cluster_name]\n");
	
	# Make sure the node is still ready to take this VM.
	AN::Cluster::scan_cluster($conf);
	my $vm_key = "vm:$vm";
	my $ready = check_node_readiness($conf, $vm_key, $node);
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], ready: [$ready]\n");
	if ($ready)
	{
		my $say_title = AN::Common::get_string($conf, {key => "title_0046", variables => {
			server		=>	$say_vm,
			node_anvil_name	=>	$node_cluster_name,
		}});
		print AN::Common::template($conf, "server.html", "start-server-header", {
			title		=>	$say_title,
		});

		my $show_remote_desktop_link = 0;
		my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	"clusvcadm -e vm:$vm -m $node_cluster_name",
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /Success/i)
			{
				# Set the host manually as the server wasn't
				# running when the cluster was last scanned.
				my $vm_key = "vm:$vm";
				$conf->{vm}{$vm_key}{current_host} = $node;
				$show_remote_desktop_link      = 1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], vm_key: [$vm_key], node: [$node], vm::${vm_key}::current_host: [$conf->{vm}{$vm_key}{current_host}]\n");
			}
			elsif ($line =~ /Service is already running/i)
			{
				$show_remote_desktop_link = 2;
				$line = "";
				print AN::Common::template($conf, "server.html", "start-server-already-running");
			}
			elsif ($line =~ /Fail/i)
			{
				# The VM failed to start. Call a stop against it.
				print AN::Common::template($conf, "server.html", "start-server-failed");
				($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
					node		=>	$node,
					port		=>	$conf->{node}{$node}{port},
					user		=>	"root",
					password	=>	$conf->{sys}{root_password},
					ssh_fh		=>	$ssh_fh,
					'close'		=>	0,
					shell_call	=>	"clusvcadm -d vm:$vm",
				});
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
				foreach my $line (@{$output})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
					$line = parse_text_line($conf, $line);
					my $message = ($line =~ /^(.*)\[/)[0];
					my $status  = ($line =~ /(\[.*)$/)[0];
					if (not $message)
					{
						$message = $line;
						$status  = "";
					}
					print AN::Common::template($conf, "server.html", "start-server-shell-output", {
						status	=>	$status,
						message	=>	$message,
					});
				}
				print AN::Common::template($conf, "server.html", "start-server-failed-trying-again");
				($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
					node		=>	$node,
					port		=>	$conf->{node}{$node}{port},
					user		=>	"root",
					password	=>	$conf->{sys}{root_password},
					ssh_fh		=>	$ssh_fh,
					'close'		=>	1,
					shell_call	=>	"clusvcadm -e vm:$vm -m $node_cluster_name",
				});
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
				foreach my $line (@{$output})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
					$line = parse_text_line($conf, $line);
					if ($line =~ /Fail/i)
					{
						# The VM failed to start. Call a stop against it.
						print AN::Common::template($conf, "server.html", "start-server-failed-again");
					}
					my $message = ($line =~ /^(.*)\[/)[0];
					my $status  = ($line =~ /(\[.*)$/)[0];
					if (not $message)
					{
						$message = $line;
						$status  = "";
					}
					print AN::Common::template($conf, "server.html", "start-server-shell-output", {
						status	=>	$status,
						message	=>	$message,
					});
				}
			}
			$line = parse_text_line($conf, $line);
			my $message = ($line =~ /^(.*)\[/)[0];
			my $status  = ($line =~ /(\[.*)$/)[0];
			if (not $message)
			{
				$message = $line;
				$status  = "";
			}
			print AN::Common::template($conf, "server.html", "start-server-shell-output", {
				status	=>	$status,
				message	=>	$message,
			});
		}
		
		if ($show_remote_desktop_link)
		{
			### Disabled
# 			# Show the link to the server's desktop.
# 			# If guac is installed, of course...
# 			if (-e $conf->{path}{guacamole_config})
# 			{
# 				# Installed.
# 				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], say_vm: [$say_vm]\n");
# 				# Give time for the server to actually come up.
# 				if ($show_remote_desktop_link == 1)
# 				{
# 					sleep 3;
# 				}
# 				($node, my $type, my $listen, my $port) = get_current_vm_vnc_info($conf, $vm, $node);
# 				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], type: [$type], listen: [$listen], port: [$port]\n");
# 				if ($type ne "vnc")
# 				{
# 					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; VM: [$say_vm] is not using VNC, can't use Guacamole.\n");
# 					# Check the recorded XML file and is necesary, update
# 					# it. In any case, disable VNC and tell the user they
# 					# will need to power off and restart the server before
# 					# this will work.
# 					$remote_message = AN::Common::get_string($conf, {key => "message_0076"});
# 					$remote_icon    = AN::Common::template($conf, "common.html", "image", {
# 						image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/icon_server-desktop_oops.png",
# 						alt_text	=>	"",
# 						id		=>	"server-desktop_oops",
# 					}, "", 1);
# 					
# 					# See if I need to update the XML definition file.
# 					if (($conf->{vm}{$vm}{graphics}{type} ne "vnc") || ($conf->{vm}{$vm}{graphics}{'listen'} ne "0.0.0.0"))
# 					{
# 						# Rewrite the XML definition. The 'graphics' section should look like:
# 						#     <graphics type='vnc' port='5900' autoport='yes' listen='0.0.0.0'>
# 						#       <listen type='address' address='0.0.0.0'/>
# 						#     </graphics>
# 						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; VM: [$say_vm]'s definition file is not using VNC, updating it.\n");
# 						my ($backup_file) = archive_file($conf, $node, $conf->{vm}{$vm}{definition_file}, 0, "hidden_table");
# 						switch_vm_xml_to_vnc($conf, $node, $vm, $backup_file);
# 					}
# 				}
# 				else
# 				{
# 					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; VM: [$say_vm] is using VNC, we can offer remote desktop access.\n");
# 					update_guacamole_config($conf, $say_vm, $node, $port);
# 				}
# 				if (not $remote_message)
# 				{
# 					my ($guacamole_url) = AN::Cluster::get_guacamole_link($conf, $node);
# 					$remote_message     = AN::Common::get_string($conf, {key => "message_0077"});
# 					if (not $node)
# 					{
# 						$remote_message = AN::Common::get_string($conf, {key => "message_0078"});
# 						$remote_icon    = AN::Common::template($conf, "common.html", "image", {
# 							image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/icon_server-desktop_offline.png",
# 							alt_text	=>	"",
# 							id		=>	"server-desktop_offline",
# 						}, "", 1);
# 					}
# 					elsif (($node =~ /n01/) || ($node =~ /node01/))
# 					{
# 						my $image = AN::Common::template($conf, "common.html", "image", {
# 							image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/icon_server-desktop_n01.png",
# 							alt_text	=>	"",
# 							id		=>	"server-desktop_n01",
# 						}, "", 1);
# 						$remote_icon = AN::Common::template($conf, "common.html", "enabled-button-no-class-new-tab", {
# 							button_link	=>	"$guacamole_url?id=c\%2F$say_vm",
# 							button_text	=>	"$image",
# 							id		=>	"guacamole_url_$say_vm",
# 						}, "", 1);
# 					}
# 					elsif (($node =~ /n02/) || ($node =~ /node02/))
# 					{
# 						my $image = AN::Common::template($conf, "common.html", "image", {
# 							image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/icon_server-desktop_n02.png",
# 							alt_text	=>	"",
# 							id		=>	"server-desktop_n02",
# 						}, "", 1);
# 						$remote_icon = AN::Common::template($conf, "common.html", "enabled-button-no-class-new-tab", {
# 							button_link	=>	"$guacamole_url?id=c\%2F$say_vm",
# 							button_text	=>	"$image",
# 							id		=>	"guacamole_url_$say_vm",
# 						}, "", 1);
# 					}
# 					else
# 					{
# 						$remote_message = AN::Common::get_string($conf, {key => "message_0079"});
# 						$remote_icon    = AN::Common::template($conf, "common.html", "image", {
# 							image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/icon_server-desktop_oops.png",
# 							alt_text	=>	"",
# 							id		=>	"server-desktop_oops",
# 						}, "", 1);
# 					}
# 				}
# 			}
# 			else
# 			{
# 				# Not installed.
# 				$remote_message = "#!string!message_0080!#";
# 				$remote_icon    = AN::Common::template($conf, "common.html", "image", {
# 					image_source	=>	"$conf->{url}{skins}/$conf->{sys}{skin}/images/icon_server-desktop_oops.png",
# 					alt_text	=>	"",
# 					id		=>	"server-desktop_oops",
# 				}, "", 1);
# 			}
		}
		
		print AN::Common::template($conf, "server.html", "start-server-output-footer");
		if ($show_remote_desktop_link)
		{
			### Disabled
# 			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::cluster: [$conf->{cgi}{cluster}]\n");
# 			my $restart_tomcat = AN::Common::get_string($conf, {key => "message_0085", variables => {
# 					reset_tomcat_url	=>	"?cluster=$conf->{cgi}{cluster}&task=restart_tomcat",
# 				}});
# 			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; restart_tomcat: [$restart_tomcat]\n");
# 			print AN::Common::template($conf, "server.html", "start-server-show-guacamole-link", {
# 				remote_icon	=>	$remote_icon,
# 				remote_message	=>	$remote_message,
# 				restart_tomcat	=>	$restart_tomcat,
# 			});
		}
		print AN::Common::template($conf, "server.html", "start-server-footer");
	}
	else
	{
		# The target node is not ready to run a server.
		my $say_title = AN::Common::get_string($conf, {key => "title_0048", variables => {
			server		=>	$vm,
			node_anvil_name	=>	$node_cluster_name,
		}});
		my $say_message = AN::Common::get_string($conf, {key => "message_0184", variables => {
			node_anvil_name	=>	$node_cluster_name,
			server		=>	$vm,
		}});
		print AN::Common::template($conf, "server.html", "start-server-node-not-ready", {
			title	=>	$say_title,
			message	=>	$say_message,
		});
	}
	
	return(0);
}

# This tries to parse lines coming back from a shell call to add highlighting and what-not.
sub parse_text_line
{
	my ($conf, $line) = @_;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; parse_text_line(); line: [$line]\n");
	
	# 'Da good ^_^
	$line =~ s/(success)/<span class="highlight_good">$1<\/span>/ig;
	$line =~ s/\[\s+(ok)\s+\]/[ <span class="highlight_good">$1<\/span> ]/ig;
	
	# Informational.
	$line =~ s/(done)/<span class="highlight_ready">$1<\/span>/ig;
	$line =~ s/(Starting Cluster):/<span class="highlight_ready">$1<\/span>:/ig;
	$line =~ s/(Stopping Cluster):/<span class="highlight_ready">$1<\/span>:/ig;
	#$line =~ s/(disabled)/<span class="highlight_ready">$1<\/span>/ig;
	#$line =~ s/(shutdown)/<span class="highlight_ready">$1<\/span>/ig;
	$line =~ s/(shut down)/<span class="highlight_ready">$1<\/span>/ig;
	
	# 'Da bad. ;_;
	$line =~ s/(failed)/<span class="highlight_bad">$1<\/span>/ig;
	$line =~ s/\[\s+(failed)\s+\]/[ <span class="highlight_bad">$1<\/span> ]/ig;
	
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
	return($line);
}

# This migrates a VM to the target node.
sub migrate_vm
{
	my ($conf) = @_;
	
	my $target = $conf->{cgi}{target};
	my $vm     = $conf->{cgi}{vm};
	my $node   = long_host_name_to_node_name($conf, $target);
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], node: [$node], target: [$target]\n");
	
	# Make sure the node is still ready to take this VM.
	AN::Cluster::scan_cluster($conf);
	my $vm_key = "vm:$vm";
	my $ready = check_node_readiness($conf, $vm_key, $node);
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], ready: [$ready]\n");
	if ($ready)
	{
		my $say_title = AN::Common::get_string($conf, {key => "title_0049", variables => {
			server	=>	$vm,
			target	=>	$target,
		}});
		print AN::Common::template($conf, "server.html", "migrate-server-header", {
			title	=>	$say_title,
		});
		my $shell_call = "$conf->{path}{clusvcadm} -M vm:$vm -m $target";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
		my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	1,
			shell_call	=>	$shell_call,
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			$line = parse_text_line($conf, $line);
			my $message = ($line =~ /^(.*)\[/)[0];
			my $status  = ($line =~ /(\[.*)$/)[0];
			if (not $message)
			{
				$message = $line;
				$status  = "";
			}
			print AN::Common::template($conf, "server.html", "start-server-shell-output", {
				status	=>	$status,
				message	=>	$message,
			});
		}
		print AN::Common::template($conf, "server.html", "migrate-server-footer");
	}
	else
	{
		# Target not ready
		my $say_title = AN::Common::get_string($conf, {key => "title_0050", variables => {
			server	=>	$vm,
			target	=>	$target,
		}});
		my $say_message = AN::Common::get_string($conf, {key => "message_0187", variables => {
			server	=>	$vm,
			target	=>	$target,
		}});
		print AN::Common::template($conf, "server.html", "migrate-server-target-not-ready", {
			title	=>	$say_title,
			message	=>	$say_message,
		});
	}
	
	return(0);
}

# This sttempts to shut down a VM on a target node.
sub stop_vm
{
	my ($conf) = @_;
	
	my $node = $conf->{cgi}{node};
	my $vm   = $conf->{cgi}{vm};
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], node: [$node]\n");
	
	# Has the timer expired?
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; current time: [".time."], cgi::expire: [$conf->{cgi}{expire}].\n");
	if (time > $conf->{cgi}{expire})
	{
		# Abort!
		my $say_title   = AN::Common::get_string($conf, {key => "title_0185"});
		my $say_message = AN::Common::get_string($conf, {key => "message_0444", variables => {
			server	=>	$conf->{cgi}{vm},
		}});
		print AN::Common::template($conf, "server.html", "request-expired", {
			title		=>	$say_title,
			message		=>	$say_message,
		});
		return(1);
	}
	
	AN::Cluster::scan_cluster($conf);
	my $say_title = AN::Common::get_string($conf, {key => "title_0051", variables => {
		server	=>	$vm,
	}});
	print AN::Common::template($conf, "server.html", "stop-server-header", {
		title	=>	$say_title,
	});
	my $say_node = node_name_to_long_host_name($conf, $node);
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"$conf->{path}{clusvcadm} -d vm:$vm",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$line =~ s/Local machine/$say_node/;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		$line = parse_text_line($conf, $line);
		my $message = ($line =~ /^(.*)\[/)[0];
		my $status  = ($line =~ /(\[.*)$/)[0];
		if (not $message)
		{
			$message = $line;
			$status  = "";
		}
		print AN::Common::template($conf, "server.html", "start-server-shell-output", {
			status	=>	$status,
			message	=>	$message,
		});
	}
	print AN::Common::template($conf, "server.html", "stop-server-footer");
	
	return(0);
}

# This sttempts to shut down a VM on a target node.
sub join_cluster
{
	my ($conf) = @_;
	
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	my $proceed           = 0;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in join_cluster(), node: [$node], node_cluster_name: [$node_cluster_name]\n");
	
	# This, more than 
	AN::Cluster::scan_cluster($conf);
	
	# Proceed only if all of the storage components, cman and rgmanager are
	# off.
	if (($conf->{node}{$node}{daemon}{cman}{exit_code} ne "0") ||
	($conf->{node}{$node}{daemon}{rgmanager}{exit_code} ne "0") ||
	($conf->{node}{$node}{daemon}{drbd}{exit_code} ne "0") ||
	($conf->{node}{$node}{daemon}{clvmd}{exit_code} ne "0") ||
	($conf->{node}{$node}{daemon}{gfs2}{exit_code} ne "0") ||
	($conf->{node}{$node}{daemon}{libvirtd}{exit_code} ne "0"))
	{
		$proceed = 1;
	}
	if ($proceed)
	{
		my $say_title = AN::Common::get_string($conf, {key => "title_0052", variables => {
			node_anvil_name	=>	$node_cluster_name,
			anvil		=>	$conf->{cgi}{cluster},
		}});
		print AN::Common::template($conf, "server.html", "join-anvil-header", {
			title	=>	$say_title,
		});
		my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	1,
			shell_call	=>	"/etc/init.d/cman start && /etc/init.d/rgmanager start",
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			$line = parse_text_line($conf, $line);
			my $message = ($line =~ /^(.*)\[/)[0];
			my $status  = ($line =~ /(\[.*)$/)[0];
			if (not $message)
			{
				$message = $line;
				$status  = "";
			}
			print AN::Common::template($conf, "server.html", "start-server-shell-output", {
				status	=>	$status,
				message	=>	$message,
			});
		}
		print AN::Common::template($conf, "server.html", "join-anvil-footer");
	}
	else
	{
		# Node is already in the Anvil!
		my $say_title = AN::Common::get_string($conf, {key => "title_0053", variables => {
			node_anvil_name	=>	$node_cluster_name,
			anvil		=>	$conf->{cgi}{cluster},
		}});
		print AN::Common::template($conf, "server.html", "join-anvil-aborted", {
			title	=>	$say_title,
		});
	}
	
	return(0);
}

# This sttempts to start the cluster stack on both nodes simultaneously.
sub dual_join
{
	my ($conf) = @_;
	
	my $cluster = $conf->{cgi}{cluster};
	my $proceed = 1;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in dual_join(), cluster: [$cluster]\n");
	
	# This, more than 
	AN::Cluster::scan_cluster($conf);
	
	# Proceed only if all of the storage components, cman and rgmanager are
	# off.
	my @abort_reason;
	foreach my $node (sort {$a cmp $b} @{$conf->{clusters}{$cluster}{nodes}})
	{
		if (($conf->{node}{$node}{daemon}{cman}{exit_code} eq "0") ||
		($conf->{node}{$node}{daemon}{rgmanager}{exit_code} eq "0") ||
		($conf->{node}{$node}{daemon}{drbd}{exit_code} eq "0") ||
		($conf->{node}{$node}{daemon}{clvmd}{exit_code} eq "0") ||
		($conf->{node}{$node}{daemon}{gfs2}{exit_code} eq "0"))
		{
			$proceed = 0;
			# Already joined the Anvil!
			my $reason = AN::Common::get_string($conf, {key => "message_0190", variables => {
				node	=>	$node,
			}});
			push @abort_reason, $reason;
		}
	}
	if ($proceed)
	{
		my $say_title = AN::Common::get_string($conf, {key => "title_0054", variables => {
			anvil	=>	$conf->{cgi}{cluster},
		}});
		print AN::Common::template($conf, "server.html", "dual-join-anvil-header", {
			title	=>	$say_title,
		});

		# I need to fork here because the calls won't return until cman
		# either talks to it's peer or fences it.
		my $parent_pid = $$;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Parent process has PID: [$parent_pid]. Spawning a child process for each node.\n");
		my %pids;
		my $node_count = @{$conf->{clusters}{$cluster}{nodes}};
		foreach my $node (sort {$a cmp $b} @{$conf->{clusters}{$cluster}{nodes}})
		{
			defined(my $pid = fork) or die "$THIS_FILE ".__LINE__."; Can't fork(), error was: $!\n";
			if ($pid)
			{
				# Parent thread.
				$pids{$pid} = 1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], Spawned child with PID: [$pid].\n");
			}
			else
			{
				# This is the child thread, so do the call.
				# Note that, without the 'die', we could end
				# up here if the fork() failed.
				my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
					node		=>	$node,
					port		=>	$conf->{node}{$node}{port},
					user		=>	"root",
					password	=>	$conf->{sys}{root_password},
					ssh_fh		=>	"",
					'close'		=>	1,
					shell_call	=>	"/etc/init.d/cman start && /etc/init.d/rgmanager start",
				});
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
				foreach my $line (@{$output})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					next if not $line;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; $node; $line\n");
					$line = parse_text_line($conf, $line);
					my $message = ($line =~ /^(.*)\[/)[0];
					my $status  = ($line =~ /(\[.*)$/)[0];
					if (not $message)
					{
						$message = $line;
						$status  = "";
					}
					print AN::Common::template($conf, "server.html", "dual-join-anvil-output", {
						node	=>	$node,
						message	=>	$message,
						status	=>	$status,
					});
				}
				
				# Kill the child process.
				exit;
			}
		}
		
		# Now loop until both child processes are dead.
		# This helps to catch hung children.
		my $saw_reaped = 0;
		
		# If I am here, then I am the parent process and all the child process have
		# been spawned. I will not enter a while() loop that will exist for however
		# long the %pids hash has data.
		while (%pids)
		{
			# This is a bit of an odd loop that put's the while()
			# at the end. It will cycle once per child-exit event.
			my $pid;
			do
			{
				# 'wait' returns the PID of each child as they
				# exit. Once all children are gone it returns 
				# '-1'.
				$pid = wait;
				if ($pid < 1)
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Parent process thinks all children are gone now as wait returned: [$pid]. Exiting loop.\n");
				}
				else
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Parent process told that child with PID: [$pid] has exited.\n");
				}
				
				# This deletes the just-exited child process' PID from the
				# %pids hash.
				delete $pids{$pid};
				
				# This counter is a safety mechanism. If I see more PIDs exit
				# than I spawned, something went oddly and I need to bail.
				$saw_reaped++;
				my $say_error = AN::Common::get_string($conf, {key => "message_0192"});
				AN::Cluster::error($conf, "$say_error\n") if $saw_reaped > ($node_count + 1);
			}
			while $pid > 0;	# This re-enters the do() loop for as
					# long as the PID returned by wait()
					# was >0.
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; All child processes reaped, exiting threaded execution.\n");
		print AN::Common::template($conf, "server.html", "dual-join-anvil-footer");
	}
	else
	{
		my $say_title = AN::Common::get_string($conf, {key => "title_0055", variables => {
			anvil	=>	$conf->{cgi}{cluster},
		}});
		print AN::Common::template($conf, "server.html", "dual-join-anvil-aborted-header", {
			title	=>	$say_title,
		});
		foreach my $reason (@abort_reason)
		{
			print AN::Common::template($conf, "server.html", "one-line-message", {
				message	=>	"$reason",
			});
		}
		print AN::Common::template($conf, "server.html", "dual-join-anvil-aborted-footer");
	}
	
	return(0);
}

# This forcibly shuts down a VM on a target node. The cluster should restart it
# shortly after.
sub force_off_vm
{
	my ($conf) = @_;
	
	my $node = $conf->{cgi}{node};
	my $vm   = $conf->{cgi}{vm};
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in force_off_vm(), vm: [$vm], node: [$node]\n");
	
	# Has the timer expired?
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; current time: [".time."], cgi::expire: [$conf->{cgi}{expire}].\n");
	if (time > $conf->{cgi}{expire})
	{
		# Abort!
		my $say_title   = AN::Common::get_string($conf, {key => "title_0186"});
		my $say_message = AN::Common::get_string($conf, {key => "message_0445", variables => {
			server	=>	$conf->{cgi}{vm},
		}});
		print AN::Common::template($conf, "server.html", "request-expired", {
			title		=>	$say_title,
			message		=>	$say_message,
		});
		return(1);
	}
	
	AN::Cluster::scan_cluster($conf);
	my $say_title = AN::Common::get_string($conf, {key => "title_0056", variables => {
		server	=>	$vm,
	}});
	print AN::Common::template($conf, "server.html", "force-off-server-header", {
		title	=>	$say_title,
	});
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"/usr/bin/virsh destroy $vm",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		$line = parse_text_line($conf, $line);
		my $message = ($line =~ /^(.*)\[/)[0];
		my $status  = ($line =~ /(\[.*)$/)[0];
		if (not $message)
		{
			$message = $line;
			$status  = "";
		}
		print AN::Common::template($conf, "server.html", "start-server-shell-output", {
			status	=>	$status,
			message	=>	$message,
		});
	}
	print AN::Common::template($conf, "server.html", "force-off-server-footer");
	
	return(0);
}

# This stops the VM, if it's running, edits the cluster.conf to remove the VM's
# entry, pushes the changed cluster out, deletes the VM's definition file and 
# finally deletes the LV.
sub delete_vm
{
	my ($conf) = @_;
	
	my $cluster = $conf->{cgi}{cluster};
	my $say_vm  = $conf->{cgi}{vm};
	my $vm      = "vm:$conf->{cgi}{vm}";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in delete_vm(), vm: [$vm], cluster: [$cluster]\n");
	
	# This, more than ... what? what was I going to say here?!
	AN::Cluster::scan_cluster($conf);
	my $proceed      = 1;
	my $stop_vm      = 0;
	my $say_host     = "";
	my $host         = "";
	my $abort_reason = "";
	my $node         = $conf->{sys}{cluster}{node1_name};
	my $node1        = $conf->{sys}{cluster}{node1_name};
	my $node2        = $conf->{sys}{cluster}{node2_name};
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm::${vm}::host: [$conf->{vm}{$vm}{host}]\n");
	if (not $conf->{vm}{$vm}{host})
	{
		$proceed      = 0;
		# Failed to read the server's details.
		my $sat_problem = AN::Common::get_string($conf, {key => "message_0195", variables => {
			server	=>	$say_vm,
		}});
		$abort_reason = "<b>$sat_problem!</b><br />#!string!message_0194!#<br />#!string!explain_0035!#<br />#!string!brand_0011!#<br />";
	}
	elsif ($conf->{vm}{$vm}{host} ne "none")
	{
		$stop_vm  = 1;
		$say_host = $conf->{vm}{$vm}{host};
		$host     = long_host_name_to_node_name($conf, $conf->{vm}{$vm}{host});
	}
	else
	{
		# Pick the first up node to use.
		if ($conf->{node}{$node1}{up})
		{
			$host = $node1;
		}
		elsif ($conf->{node}{$node2}{up})
		{
			$host = $node2;
		}
		else
		{
			$proceed      = 0;
			# Neither node is online.
			$abort_reason = AN::Common::get_string($conf, {key => "message_0196", variables => {
				server	=>	$say_vm,
			}});
		}
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; proceed: [$proceed], host: [$host]\n");
	
	# Get to work!
	my $say_title = AN::Common::get_string($conf, {key => "title_0057", variables => {
		server	=>	$vm,
	}});
	print AN::Common::template($conf, "server.html", "delete-server-header", {
		title	=>	$say_title,
	});
	
	# We have to remove the server from the cluster *before* we force it
	# off. Otherwise, the cluster will boot it right back up.
	if ($proceed)
	{
		print AN::Common::template($conf, "server.html", "delete-server-start");
		### Note: I don't use 'path' for these calls as the location of
		###       a program on the cluster may differ from the local
		###       copy. Further, I will have $PATH on the far side of
		###       the ssh call anyway.
		# First, delete the VM from the cluster.
		my $ccs_exit_code;
		   $proceed = 0;
		my $shell_call = "ccs -h localhost --activate --sync --password \"$conf->{clusters}{$cluster}{ricci_pw}\" --rmvm $conf->{cgi}{vm}; echo ccs:\$?";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
		my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$host,
			port		=>	$conf->{node}{$host}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			next if not $line;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /ccs:(\d+)/)
			{
				$ccs_exit_code = $1;
			}
			else
			{
				$line = parse_text_line($conf, $line);
				print AN::Common::template($conf, "server.html", "one-line-message", {
					message	=>	$line,
				});
			}
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ccs exit code: [$ccs_exit_code]\n");
		if ($ccs_exit_code eq "0")
		{
			print AN::Common::template($conf, "server.html", "one-line-message", {
				message	=>	"#!string!message_0197!#",
			});
			$proceed = 1;
		}
		else
		{
			my $say_error = AN::Common::get_string($conf, {key => "message_0198", variables => {
				ccs_exit_code	=>	$ccs_exit_code,
			}});
			print AN::Common::template($conf, "server.html", "delete-server-bad-exit-code", {
				error	=>	$say_error,
			});
		}
		print AN::Common::template($conf, "server.html", "delete-server-start-footer");
		
		my $stop_exit_code;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; stop_vm: [$stop_vm], ccs_exit_code: [$ccs_exit_code]\n");
		if (($stop_vm) && ($ccs_exit_code eq "0"))
		{
			# Server is still running, kill it.
			print AN::Common::template($conf, "server.html", "delete-server-force-off-header");
			
			   $proceed = 0;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
			my $virsh_exit_code;
			my $shell_call = "/usr/bin/virsh destroy $say_vm; echo virsh:\$?";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
			($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
				node		=>	$host,
				port		=>	$conf->{node}{$host}{port},
				user		=>	"root",
				password	=>	$conf->{sys}{root_password},
				ssh_fh		=>	$ssh_fh,
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
			foreach my $line (@{$output})
			{
				next if not $line;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
				if ($line =~ /virsh:(\d+)/)
				{
					$virsh_exit_code = $1;
				}
				else
				{
					$line = parse_text_line($conf, $line);
					print AN::Common::template($conf, "server.html", "one-line-message", {
						message	=>	$line,
					});
				}
			}
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; virsh exit code: [$virsh_exit_code]\n");
			if ($virsh_exit_code eq "0")
			{
				print AN::Common::template($conf, "server.html", "one-line-message", {
					message	=>	"#!string!message_0199!#",
				});
				$proceed = 1;
			}
			else
			{
				# This is fatal
				my $say_error = AN::Common::get_string($conf, {key => "message_0200", variables => {
					virsh_exit_code	=>	$virsh_exit_code,
				}});
				print AN::Common::template($conf, "server.html", "delete-server-bad-exit-code", {
					error	=>	$say_error,
				});
				$proceed = 0;
			}
			print AN::Common::template($conf, "server.html", "delete-server-force-off-footer");
		}
		
		# Now delete the backing LVs
		if ($proceed)
		{
			# Free up the storage
			print AN::Common::template($conf, "server.html", "delete-server-remove-lv-header");
			foreach my $lv (keys %{$conf->{vm}{$vm}{node}{$node}{lv}})
			{
				print AN::Common::template($conf, "server.html", "one-line-message", {
					message	=>	"#!string!message_0201!#",
				}, {
					lv	=>	$lv,
				});
				my $lvremove_exit_code;
				($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
					node		=>	$host,
					port		=>	$conf->{node}{$host}{port},
					user		=>	"root",
					password	=>	$conf->{sys}{root_password},
					ssh_fh		=>	$ssh_fh,
					'close'		=>	1,
					shell_call	=>	"lvremove -f $lv; echo lvremove:\$?",
				});
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
				foreach my $line (@{$output})
				{
					next if not $line;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
					if ($line =~ /lvremove:(\d+)/)
					{
						$lvremove_exit_code = $1;
					}
					else
					{
						#$line = parse_text_line($conf, $line);
						print AN::Common::template($conf, "server.html", "one-line-message", {
							message	=>	$line,
						});
					}
				}
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lvremove exit code: [$lvremove_exit_code]\n");
				if ($lvremove_exit_code eq "0")
				{
					print AN::Common::template($conf, "server.html", "one-line-message", {
						message	=>	"#!string!message_0202!#",
					});
				}
				else
				{
					my $say_error = AN::Common::get_string($conf, {key => "message_0204", variables => {
						lvremove_exit_code	=>	$lvremove_exit_code,
					}});
					print AN::Common::template($conf, "server.html", "delete-server-bad-exit-code", {
						error			=>	$say_error,
					});
				}
			}
			
			# Regardless of whether the removal succeeded, archive
			# and then delete the definition file.
			my $file = $conf->{vm}{$vm}{definition_file};
			archive_file($conf, $host, $file, 0, "hidden_table");
			remove_vm_definition($conf, $host, $file);
			# variables hash feeds 'message_0205'.
			print AN::Common::template($conf, "server.html", "delete-server-success", {}, {
				server	=>	$say_vm,
			});
		}
	}
	else
	{
		print AN::Common::template($conf, "server.html", "delete-server-abort-reason", {
			abort_reason	=>	$abort_reason,
		});
	}
	print AN::Common::template($conf, "server.html", "delete-server-footer");
	
	return(0);
}

# This deletes a VM definition file.
sub remove_vm_definition
{
	my ($conf, $node, $file) = @_;
	
	# We only delete server definition files.
	if ($file !~ /^\/shared\/definitions\/.*?\.xml/)
	{
		# We will only touch files in /shared/definitions
		# The variables hash feeds 'message_0207'.
		print AN::Common::template($conf, "server.html", "remove-vm-definition-wrong-definition-file", {}, {
			file	=>	$file,
		});
		return (1);
	}
	
	# 'rm' seems to return '0' no matter what. So I use the 'ls' to ensure
	# the file is gone. 'ls' will return '2' on file not found.
	my $ls_exit_code;
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"rm -f $file; ls $file; echo ls:\$?",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		next if not $line;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /ls:(\d+)/)
		{
			$ls_exit_code = $1;
		}
		else
		{
			### There will be output, I don't care about it.
			#$line = parse_text_line($conf, $line);
			#print AN::Common::template($conf, "server.html", "one-line-message", {
			#	message	=>	$line,
			#});
		}
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ls exit code: [$ls_exit_code]\n");
	if ($ls_exit_code eq "2")
	{
		# File deleted successfully.
		print AN::Common::template($conf, "server.html", "one-line-message", {
			message	=>	"#!string!message_0209!#",
		}, {
			file	=>	$file,
		});
	}
	else
	{
		# Delete seems to have failed
		# The variables hash feeds 'message_0210'
		print AN::Common::template($conf, "server.html", "remove-vm-definition-failed", {}, {
			file		=>	$file,
			ls_exit_code	=>	$ls_exit_code,
		});
	}
	
	return (0);
}

# This copies the passed file to 'node:/shared/archive'
sub archive_file
{
	my ($conf, $node, $file, $quiet, $table_type) = @_;
	$table_type = "hidden_table" if not $table_type;
	$quiet = 0 if not defined $quiet;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; archive_file(); node: [$node], file: [$file], quiet: [$quiet], table_type: [$table_type]\n");
	
	### TODO: Check/create the archive directory.
	
	my ($directory, $file_name) =  ($file =~ /^(.*)\/(.*?)$/);
	my ($date)                  =  AN::Cluster::get_date($conf, time);
	my $destination             =  "/shared/archive/$file_name.$date";
	   $destination             =~ s/ /_/;

	my $cp_exit_code;
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"cp $file $destination; echo cp:\$?",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	my $header_printed = 0;
	foreach my $line (@{$output})
	{
		next if not $line;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /cp:(\d+)/)
		{
			$cp_exit_code = $1;
		}
		else
		{
			if (not $header_printed)
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; table_type: [$table_type]\n");
				if ($table_type eq "hidden_table")
				{
					print AN::Common::template($conf, "server.html", "one-line-message-header-hidden");
				}
				else
				{
					print AN::Common::template($conf, "server.html", "one-line-message-header");
				}
				$header_printed = 1;
			}
			$line = parse_text_line($conf, $line);
			print AN::Common::template($conf, "server.html", "one-line-message", {
				message	=>	$line,
			});
		}
	}
	if ($header_printed)
	{
		print AN::Common::template($conf, "server.html", "one-line-message-footer");
	}
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cp exit code: [$cp_exit_code]\n");
	if ($cp_exit_code eq "0")
	{
		# Success
		if (not $quiet)
		{
			if ($table_type eq "hidden_table")
			{
				print AN::Common::template($conf, "server.html", "one-line-message-header-hidden");
			}
			else
			{
				print AN::Common::template($conf, "server.html", "one-line-message-header");
			}
			my $message = AN::Common::get_string($conf, {key => "message_0211", variables => {
				file		=>	$file,
				destination	=>	$destination,
			}});
			print AN::Common::template($conf, "server.html", "one-line-message", {
				message	=>	$message,
			});
			print AN::Common::template($conf, "server.html", "one-line-message-footer");
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The file: [$file] has been archived as: [$destination].\n");
	}
	else
	{
		# Failure
		# The variables hash feeds 'message_0212'.
		print AN::Common::template($conf, "server.html", "archive-file-failed", {}, {
			file		=>	$file,
			destination	=>	$destination,
			cp_exit_code	=>	$cp_exit_code,
		});
		$destination = 0;
	}
	
	return ($destination);
}

# This adds or removes a VM from the cluster.conf file.
sub update_cluster_conf
{
	my ($conf, $do, $vm, $node) = @_;
	my $say_vm  = ($vm =~ /vm:(.*)/)[0];
	my $success = 1;
	
	# I 'cat' the current cluster.conf, incrementing 'config_version="x"'
	# by one, add or remove the <vm ...> line and then write out the edited
	# version locally. Next I backup the current cluster.conf to 
	# '/shared/archive/vX.cluster.conf', 'rsync' the updated local copy to
	# the target node, 'ccs_config_validate' it and, if all is well, 
	# 'cman_tool version -r' to push out the changes.
	
	# Read in the current cluster.conf.
	
	return($success);
}

# This makes an ssh call to the node and sends a simple 'poweroff' command.
sub poweroff_node
{
	my ($conf) = @_;
	
	# Make sure no VMs are running.
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	
	# Has the timer expired?
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; current time: [".time."], cgi::expire: [$conf->{cgi}{expire}].\n");
	if (time > $conf->{cgi}{expire})
	{
		# Abort!
		my $say_title   = AN::Common::get_string($conf, {key => "title_0187"});
		my $say_message = AN::Common::get_string($conf, {key => "message_0446", variables => {
			node	=>	$conf->{cgi}{node_cluster_name},
		}});
		print AN::Common::template($conf, "server.html", "request-expired", {
			title		=>	$say_title,
			message		=>	$say_message,
		});
		return(1);
	}
	
	# Scan the cluster, then confirm that withdrawl is still enabled.
	AN::Cluster::scan_cluster($conf);
	my $proceed = $conf->{node}{$node}{enable_poweroff};
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in poweroff_node(), node: [$node], proceed: [$proceed]\n");
	if ($proceed)
	{
		# Call the 'poweroff'.
		my $say_title = AN::Common::get_string($conf, {key => "title_0061", variables => {
			node_anvil_name	=>	$node_cluster_name,
		}});
		my $say_message = AN::Common::get_string($conf, {key => "message_0213", variables => {
			node_anvil_name	=>	$node_cluster_name,
		}});
		print AN::Common::template($conf, "server.html", "poweroff-node-header", {
			title	=>	$say_title,
			message	=>	$say_message,
		});
		
		# The ScanCore that we're cleanly shutting down so we don't 
		# auto-reboot the node.
		mark_node_as_clean_off($conf, $node, 0);	# 0 == no delay reboot time
		
		my $shell_call = "poweroff && echo \"Power down initiated. Please return to the main page now.\"";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	1,
			shell_call	=>	$shell_call,
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			$line = parse_text_line($conf, $line);
			my $message = ($line =~ /^(.*)\[/)[0];
			my $status  = ($line =~ /(\[.*)$/)[0];
			if (not $message)
			{
				$message = $line;
				$status  = "";
			}
			print AN::Common::template($conf, "server.html", "start-server-shell-output", {
				status	=>	$status,
				message	=>	$message,
			});
		}
		print AN::Common::template($conf, "server.html", "poweroff-node-footer");
	}
	else
	{
		# Aborted, in use now.
		my $say_title = AN::Common::get_string($conf, {key => "title_0062", variables => {
			node_anvil_name	=>	$conf->{cgi}{node_cluster_name},
		}});
		my $say_message = AN::Common::get_string($conf, {key => "message_0214", variables => {
			node_anvil_name	=>	$conf->{cgi}{node_cluster_name},
		}});
		print AN::Common::template($conf, "server.html", "poweroff-node-aborted", {
			title	=>	$say_title,
			message	=>	$say_message,
		});
	}
	
	AN::Cluster::footer($conf);
	return(0);
}

# This sequentially stops all servers, withdraws both nodes and powers down the
# Anvil!.
sub cold_stop_anvil
{
	my ($conf, $cancel_ups) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cold_stop(); cancel_ups: [$cancel_ups]\n");
	
	my $anvil   = $conf->{cgi}{cluster};
	my $proceed = 1;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; anvil: [$anvil]\n");
	
	# Has the timer expired?
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; current time: [".time."], cgi::expire: [$conf->{cgi}{expire}].\n");
	if (time > $conf->{cgi}{expire})
	{
		# Abort!
		my $say_title   = AN::Common::get_string($conf, {key => "title_0184"});
		my $say_message = AN::Common::get_string($conf, {key => "message_0443", variables => {
			anvil	=>	$conf->{cgi}{cluster},
		}});
		print AN::Common::template($conf, "server.html", "request-expired", {
			title		=>	$say_title,
			message		=>	$say_message,
		});
		return(1);
	}
	
	# Make sure we've got an up-to-date view of the cluster.
	AN::Cluster::scan_cluster($conf);
	
	# Abort if the system is down already.
	if ($conf->{sys}{up_nodes} > 0)
	{
		my $say_title = AN::Common::get_string($conf, {key => "title_0181", variables => {
			anvil	=>	$anvil,
		}});
		print AN::Common::template($conf, "server.html", "cold-stop-header", {
			title		=>	$say_title,
		});
		
		# Pick a node to use to stop servers.
		my $node = $conf->{up_nodes}->[0];
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node]\n");
		
		# Now find and stop all servers.
		foreach my $server (sort {$a cmp $b} keys %{$conf->{vm}})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; server: [$server], host: [$conf->{vm}{$server}{host}], state: [$conf->{vm}{$server}{'state'}]\n");
			if ($conf->{vm}{$server}{'state'} eq "started")
			{
				# Stop the server
				my $say_server  =  $server;
				   $say_server  =~ s/^vm://;
				my $say_message =  AN::Common::get_string($conf, {key => "message_0420", variables => {
					server	=>	$say_server,
				}});
				print AN::Common::template($conf, "server.html", "cold-stop-entry", {
					row_class	=>	"highlight_detail_bold",
					row		=>	"#!string!row_0270!#",
					message_class	=>	"td_hidden_white",
					message		=>	"$say_message",
				});
				
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Disabling server: [$server]...\n");
				my $shell_call = "$conf->{path}{clusvcadm} -d $server";
				my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
					node		=>	$node,
					port		=>	$conf->{node}{$node}{port},
					user		=>	"root",
					password	=>	$conf->{sys}{root_password},
					ssh_fh		=>	"",
					'close'		=>	1,
					shell_call	=>	$shell_call,
				});
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
				my $shell_output = "";
				foreach my $line (@{$output})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					$line =~ s/Local machine/$node/;
					$line =  parse_text_line($conf, $line);
					$shell_output .= "$line<br />\n";
					if ($line =~ /success/i)
					{
						$conf->{vm}{$server}{'state'} = "disabled";
					}
				}
				$shell_output =~ s/\n$//;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_output: [$shell_output]\n");
				print AN::Common::template($conf, "server.html", "cold-stop-entry", {
					row_class	=>	"code",
					row		=>	"#!string!row_0127!#",
					message_class	=>	"quoted_text",
					message		=>	$shell_output,
				});
			}
		}
		
		# Servers down?
		my $proceed = 1;
		foreach my $server (sort {$a cmp $b} keys %{$conf->{vm}})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; server: [$server], host: [$conf->{vm}{$server}{host}], state: [$conf->{vm}{$server}{'state'}]\n");
			if ($conf->{vm}{$server}{'state'} eq "started")
			{
				# Well crap...
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; server: [$server] is still up!\n");
				   $proceed     =  0;
				my $say_server  =  $server;
				   $say_server  =~ s/^vm://;
				my $say_message =  AN::Common::get_string($conf, {key => "message_0421", variables => {
					server	=>	$say_server,
				}});
				print AN::Common::template($conf, "server.html", "cold-stop-entry", {
					row_class	=>	"highlight_detail_bold",
					row		=>	"#!string!row_0270!#",
					message_class	=>	"td_hidden_white",
					message		=>	"$say_message",
				});
			}
			else
			{
				# Server is down.
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; server: [$server] is down.\n");
			}
		}
		if ($proceed)
		{
			# All servers are down.
			print AN::Common::template($conf, "server.html", "cold-stop-entry", {
				row_class	=>	"highlight_good_bold",
				row		=>	"#!string!row_0083!#",
				message_class	=>	"td_hidden_white",
				message		=>	"#!string!message_0422!#",
			});
			
			# Now withdraw both nodes from the cluster, if they're
			# up.
			foreach my $node (@{$conf->{up_nodes}})
			{
				# rc == 0 -> up
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Checking if I need to withdraw node: [$node], cman's exit code: [$conf->{node}{$node}{daemon}{cman}{exit_code}]\n");
				if ($conf->{node}{$node}{daemon}{cman}{exit_code})
				{
					# Was already withdrawn.
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Not in the cluster.\n");
					my $say_message = AN::Common::get_string($conf, {key => "message_0424", variables => {
						node	=>	$node,
					}});
					print AN::Common::template($conf, "server.html", "cold-stop-entry", {
						row_class	=>	"highlight_good_bold",
						row		=>	"#!string!row_0271!#",
						message_class	=>	"td_hidden_white",
						message		=>	"$say_message",
					});
				}
				else
				{
					# Withdraw
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Withdrawing...\n");
					my $say_message = AN::Common::get_string($conf, {key => "message_0425", variables => {
						node	=>	$node,
					}});
					print AN::Common::template($conf, "server.html", "cold-stop-entry", {
						row_class	=>	"highlight_good_bold",
						row		=>	"#!string!row_0271!#",
						message_class	=>	"td_hidden_white",
						message		=>	"$say_message",
					});
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Disabling node: [$node]...\n");
					my $shell_call = "/etc/init.d/rgmanager stop && /etc/init.d/cman stop; echo rc:\$?";
					my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
						node		=>	$node,
						port		=>	$conf->{node}{$node}{port},
						user		=>	"root",
						password	=>	$conf->{sys}{root_password},
						ssh_fh		=>	"",
						'close'		=>	1,
						shell_call	=>	$shell_call,
					});
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
					my $shell_output = "";
					foreach my $line (@{$output})
					{
						$line =~ s/^\s+//;
						$line =~ s/\s+$//;
						$line =~ s/\s+/ /g;
						$line =~ s/Local machine/$node/;
						if ($line =~ /rc:(\d+)/i)
						{
							my $rc = $1;
							AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc]\n");
							if ($rc)
							{
								AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node] failed to withdraw! Return code was: [$rc], expected '0'.\n");
								$proceed = 0;
							}
						}
						else
						{
							$line =  parse_text_line($conf, $line);
							$shell_output .= "$line<br />\n";
						}
					}
					$shell_output =~ s/\n$//;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_output: [$shell_output]\n");
					print AN::Common::template($conf, "server.html", "cold-stop-entry", {
						row_class	=>	"code",
						row		=>	"#!string!row_0127!#",
						message_class	=>	"quoted_text",
						message		=>	$shell_output,
					});
				}
			}
			
			# Safe to power off?
			if ($proceed)
			{
				### Yup!
				# Tell ScanCore that we're cleanly shutting down so we don't 
				# auto-reboot the node. If we're powering off or power cycling the
				# system, tell 'mark_node_as_clean_off()' to set a delay instead of
				# "clean" (off).
				my $delay = 0;
				if (($conf->{cgi}{subtask} eq "power_cycle") or ($conf->{cgi}{subtask} eq "power_off"))
				{
					# Set the delay. This will set the hosts -> host_stop_reason
					# to be time + sys::power_off_delay.
					$delay = 1;
				}
				
				print AN::Common::template($conf, "server.html", "cold-stop-entry", {
					row_class	=>	"highlight_good_bold",
					row		=>	"#!string!row_0083!#",
					message_class	=>	"td_hidden_white",
					message		=>	"#!string!message_0427!#",
				});
				
				# Now withdraw both nodes from the cluster, if they're
				# up.
				foreach my $node (@{$conf->{up_nodes}})
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Marking node: [$node] as 'off' ($delay) in ScanCore...\n");
					mark_node_as_clean_off($conf, $node, $delay);
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Powering down node: [$node]...\n");
					my $say_message = AN::Common::get_string($conf, {key => "message_0430", variables => {
						node	=>	$node,
					}});
					print AN::Common::template($conf, "server.html", "cold-stop-entry", {
						row_class	=>	"highlight_good_bold",
						row		=>	"#!string!row_0272!#",
						message_class	=>	"td_hidden_white",
						message		=>	"$say_message",
					});
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Disabling node: [$node]...\n");
					
					# If 'cancel_ups' is '1' or '2', I will stop the UPS timer. In '2', 
					# we'll call the poweroff from here once the nodes are down.
					my $shell_call = "poweroff";
					if ($cancel_ups)
					{
						$shell_call = "
if [ -e '$conf->{path}{nodes}{'anvil-kick-apc-ups'}' ]
then
    echo 'Cancelling APC UPS watchdog timer.'
    $conf->{path}{nodes}{'anvil-kick-apc-ups'} --cancel --force
fi;
poweroff";
					}
					my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
						node		=>	$node,
						port		=>	$conf->{node}{$node}{port},
						user		=>	"root",
						password	=>	$conf->{sys}{root_password},
						ssh_fh		=>	"",
						'close'		=>	1,
						shell_call	=>	$shell_call,
					});
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
					foreach my $line (@{$output})
					{
						# Only output should be from
						# the stopping of the APC UPS 
						# watchdog app.
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
					}
					my $message = "#!string!message_0436!#";
					if ($cancel_ups eq "1")
					{
						$message = "#!string!message_0428!#";
					}
					print AN::Common::template($conf, "server.html", "cold-stop-entry", {
						row_class	=>	"highlight_detail_bold",
						row		=>	"#!string!row_0273!#",
						message_class	=>	"td_hidden_white",
						message		=>	$message,
					});
				}
				# All done!
				print AN::Common::template($conf, "server.html", "cold-stop-entry", {
					row_class	=>	"highlight_good_bold",
					row		=>	"#!string!row_0083!#",
					message_class	=>	"td_hidden_white",
					message		=>	"#!string!message_0429!#",
				});
			}
			else
			{
				# Nope. :(
				print AN::Common::template($conf, "server.html", "cold-stop-entry", {
					row_class	=>	"highlight_warning_bold",
					row		=>	"#!string!row_0129!#",
					message_class	=>	"td_hidden_white",
					message		=>	"#!string!message_0426!#",
				});
			}
		}
		else
		{
			# One or more nodes are still up...
			print AN::Common::template($conf, "server.html", "cold-stop-entry", {
				row_class	=>	"highlight_warning_bold",
				row		=>	"#!string!row_0129!#",
				message_class	=>	"td_hidden_white",
				message		=>	"#!string!message_0423!#",
			});
		}
	}
	else
	{
		# Already down, abort.
		my $say_title = AN::Common::get_string($conf, {key => "title_0180", variables => {
			anvil	=>	$anvil,
		}});
		my $say_message = AN::Common::get_string($conf, {key => "message_0419", variables => {
			anvil	=>	$anvil,
		}});
		print AN::Common::template($conf, "server.html", "cold-stop-aborted", {
			title	=>	$say_title,
			message	=>	$say_message,
		});
	}
	
	# If I have a sub-task, perform it now.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::subtask: [$conf->{cgi}{subtask}]\n");
	if ($conf->{cgi}{subtask} eq "power_cycle")
	{
		# Tell the user
		print AN::Common::template($conf, "server.html", "cold-stop-entry", {
			row_class	=>	"highlight_warning_bold",
			row		=>	"#!string!row_0044!#",
			message_class	=>	"td_hidden_white",
			message		=>	"#!string!explain_0154!#",
		});
		
		# Nighty night, see you in the morning!
		my $shell_call = "$conf->{path}{'call_anvil-kick-apc-ups'} --reboot --force";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
		open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		}
		close $file_handle;
	}
	elsif($conf->{cgi}{subtask} eq "power_off")
	{
		# Tell the user
		print AN::Common::template($conf, "server.html", "cold-stop-entry", {
			row_class	=>	"highlight_warning_bold",
			row		=>	"#!string!row_0044!#",
			message_class	=>	"td_hidden_white",
			message		=>	"#!string!explain_0155!#",
		});
		
		# Do eet!
		my $shell_call = "$conf->{path}{'call_anvil-kick-apc-ups'} --shutdown --force";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
		open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		}
		close $file_handle;
	}
	
	# All done.
	print AN::Common::template($conf, "server.html", "cold-stop-footer");
	
	AN::Cluster::footer($conf);
	return(0);
}

# This uses the local machine to call "power on" against both nodes in the
# cluster.
sub dual_boot
{
	my ($conf) = @_;
	
	my $proceed      = 1;
	my $cluster      = $conf->{cgi}{cluster};
	my $shell_call   = "";
	my $booted_nodes = [];
	# TODO: Provide an option to boot just one node if one node fails for
	# some reason but the other node is fine.
	AN::Cluster::scan_cluster($conf);
	my @abort_reasons;
	foreach my $node (sort {$a cmp $b} @{$conf->{clusters}{$cluster}{nodes}})
	{
		# Read the cache files.
		AN::Cluster::read_node_cache($conf, $node);
		if (not $conf->{node}{$node}{info}{power_check_command})
		{
			# No cache
			my $reason = AN::Common::get_string($conf, {key => "message_0215", variables => {
				node	=>	$node,
			}});
			push @abort_reasons, "$reason\n";
			$proceed = 0;
		}
		
		# Confirm the node is off still.
		AN::Cluster::check_if_on($conf, $node);
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node}::is_on: [$conf->{node}{$node}{is_on}]\n");
		if ($conf->{node}{$node}{is_on} == 1)
		{
			# Already on.
			my $reason = AN::Common::get_string($conf, {key => "message_0216", variables => {
				node	=>	$node,
			}});
			push @abort_reasons, "$reason\n";
			$proceed = 0;
		}
		elsif ($conf->{node}{$node}{is_on} == 2)
		{
			# Can't reach IPMI interface
			my ($target_host) = ($conf->{node}{$node}{info}{power_check_command} =~ /-a\s(.*?)\s/)[0];
			my $reason = AN::Common::get_string($conf, {key => "message_0217", variables => {
				node		=>	$node,
				target_host	=>	$target_host,
			}});
			push @abort_reasons, "$reason\n";
			$proceed = 0;
		}
		elsif ($conf->{node}{$node}{is_on} == 3)
		{
			# Not on the IPMI interface's subnet
			my ($target_host) = ($conf->{node}{$node}{info}{power_check_command} =~ /-a\s(.*?)\s/)[0];
			my $reason = AN::Common::get_string($conf, {key => "message_0218", variables => {
				node		=>	$node,
				target_host	=>	$target_host,
			}});
			push @abort_reasons, "$reason\n";
			$proceed = 0;
		}
		elsif ($conf->{node}{$node}{is_on} == 4)
		{
			# Cache found, but no power command recorded
			my ($target_host) = ($conf->{node}{$node}{info}{power_check_command} =~ /-a\s(.*?)\s/)[0];
			my $reason = AN::Common::get_string($conf, {key => "message_0219", variables => {
				node		=>	$node,
				target_host	=>	$target_host,
			}});
			push @abort_reasons, "$reason\n";
			$proceed = 0;
		}
		
		# Still alive?
		$shell_call .= "$conf->{node}{$node}{info}{power_check_command} -o on; ";
		push @{$booted_nodes}, $node;
	}
	
	# Let's go
	if ($proceed)
	{
		my $say_message = AN::Common::get_string($conf, {key => "message_0220", variables => {
			anvil	=>	$conf->{cgi}{cluster},
		}});
		print AN::Common::template($conf, "server.html", "dual-boot-header", {
			message	=>	$say_message,
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
		open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			
			# If I can't contact the peer's database, I will get an error message. 
			
			$line = parse_text_line($conf, $line);
			my $message = ($line =~ /^(.*)\[/)[0];
			my $status  = ($line =~ /(\[.*)$/)[0];
			if (not $message)
			{
				$message = $line;
				$status  = "";
			}
			print AN::Common::template($conf, "server.html", "start-server-shell-output", {
				status	=>	$status,
				message	=>	$message,
			});
		}
		close $file_handle;
		
		# Update ScanCore to tell it that the nodes should now be
		# booted if they're found to be off.
		foreach my $node (sort {$a cmp $b} @{$booted_nodes})
		{
			mark_node_as_clean_on($conf, $node);
		}
		
		print AN::Common::template($conf, "server.html", "dual-boot-footer");
	}
	else
	{
		# Abort, abort!
		my $say_title= AN::Common::get_string($conf, {key => "title_0064", variables => {
			anvil	=>	$conf->{cgi}{cluster},
		}});
		print AN::Common::template($conf, "server.html", "dual-boot-aborted-header", {
			title	=>	$say_title,
		});
		foreach my $reason (@abort_reasons)
		{
			print AN::Common::template($conf, "server.html", "dual-boot-abort-reason", {
				reason	=>	$reason,
			});
		}
		print AN::Common::template($conf, "server.html", "dual-boot-aborted-footer");
	}
	
	return(0);
}

# This uses the IPMI (or similar) to try and power on the node.
sub poweron_node
{
	my ($conf) = @_;
	
	# Make sure no VMs are running.
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in poweron_node(), node: [$node]\n");
	
	# Scan the cluster, then confirm that withdrawl is still enabled.
	AN::Cluster::scan_cluster($conf);
	AN::Cluster::check_if_on($conf, $node);
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is on: [$conf->{node}{$node}{is_on}]\n");
	my $proceed      = 0;
	# Unknown error is the default.
	my $abort_reason = AN::Common::get_string($conf, {key => "message_0224", variables => {
		node	=>	$node,
	}});
	if ($conf->{node}{$node}{is_on} == 0)
	{
		$proceed = 1;
	}
	elsif ($conf->{node}{$node}{is_on} == 1)
	{
		# Already on
		$abort_reason = AN::Common::get_string($conf, {key => "message_0225", variables => {
			node_anvil_name	=>	$node_cluster_name,
		}});
	}
	elsif ($conf->{node}{$node}{is_on} == 2)
	{
		# Unable to contact the IPMI BMC
		$abort_reason = AN::Common::get_string($conf, {key => "message_0226", variables => {
			node_anvil_name	=>	$node_cluster_name,
		}});
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], proceed: [$proceed]\n");
	if ($proceed)
	{
		# It is still off.
		my $say_title = AN::Common::get_string($conf, {key => "title_0065", variables => {
			node_anvil_name	=>	$node_cluster_name,
		}});
		my $say_message = AN::Common::get_string($conf, {key => "message_0222", variables => {
			node_anvil_name	=>	$node_cluster_name,
		}});
		print AN::Common::template($conf, "server.html", "poweron-node-header", {
			title	=>	$say_title,
			message	=>	$say_message,
		});

		# The node is still off. Now can I call it from it's peer?
		my $peer  = "";
		my $is_on = 2;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; up nodes: [$conf->{sys}{up_nodes}]\n");
		if ($conf->{sys}{up_nodes} == 1)
		{
			# It has to be the peer of this node.
			$peer = @{$conf->{up_nodes}}[0];
		}
		
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], peer: [$peer]\n");
		if ($peer)
		{
			# It's peer is up, use it.
			if (not $conf->{node}{$node}{info}{power_check_command})
			{
				# Can't find the power command on the peer
				my $error = AN::Common::get_string($conf, {key => "message_0227", variables => {
						node	=>	$node,
						peer	=>	$peer,
					}});
				AN::Cluster::error($conf, "$error\n");
			}
			my $shell_call = "$conf->{node}{$node}{info}{power_check_command} -o on";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
			my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
				node		=>	$peer,
				port		=>	$conf->{node}{$peer}{port},
				user		=>	"root",
				password	=>	$conf->{sys}{root_password},
				ssh_fh		=>	"",
				'close'		=>	1,
				shell_call	=>	$shell_call,
			});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
			foreach my $line (@{$output})
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], line: [$line]\n");
				print AN::Common::template($conf, "server.html", "one-line-message", {
					message	=>	$line,
				});
			}
			
			# Update ScanCore to tell it that the nodes should now be booted.
			mark_node_as_clean_on($conf, $node);
			print AN::Common::template($conf, "server.html", "poweron-node-close-tr");
		}
		else
		{
			# Try to boot the node locally.
			if ($conf->{node}{$node}{info}{power_check_command})
			{
				my ($target_host) = ($conf->{node}{$node}{info}{power_check_command} =~ /-a\s(.*?)\s/)[0];
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], target host: [$target_host], power check command: [$conf->{node}{$node}{info}{power_check_command}].\n");
				my ($local_access, $target_ip) = AN::Cluster::on_same_network($conf, $target_host, $node);
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], local access: [$local_access].\n");
				if ($local_access)
				{
					# I can reach it directly
					my $shell_call = "$conf->{node}{$node}{info}{power_check_command} -o on";
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
					open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
					while(<$file_handle>)
					{
						chomp;
						my $line = $_;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], line: [$line]\n");
						print AN::Common::template($conf, "server.html", "one-line-message", {
							message	=>	$line,
						});
					}
					close $file_handle;
					print AN::Common::template($conf, "server.html", "poweron-node-close-tr");
				}
				else
				{
					# I can't reach it from here.
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; This machine is not on the same network out of band management interface: [$target_host] for node: [$node], unable to check power state.\n");
				}
			}
			else
			{
				# Can't check the power.
				my $say_title = AN::Common::get_string($conf, {key => "title_0066", variables => {
					node_anvil_name	=>	$node_cluster_name,
				}});
				my $say_message = AN::Common::get_string($conf, {key => "message_0228", variables => {
					node_anvil_name	=>	$node_cluster_name,
				}});
				print AN::Common::template($conf, "server.html", "poweron-node-failed", {
					title	=>	$say_title,
					message	=>	$say_message,
				});
			}
		}
	}
	else
	{
		# Poweron aborted
		my $say_title = AN::Common::get_string($conf, {key => "title_0067", variables => {
			node_anvil_name	=>	$node_cluster_name,
		}});
		print AN::Common::template($conf, "server.html", "poweron-node-aborted", {
			title	=>	$say_title,
			message	=>	$abort_reason,
		});
	}
	print AN::Common::template($conf, "server.html", "poweron-node-footer");
	AN::Cluster::footer($conf);
	
	return(0);
}

# This uses the fence methods, as defined in cluster.conf and in the proper
# order, to fence the target node.
sub fence_node
{
	my ($conf) = @_;
	
	# Make sure no VMs are running.
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	my $peer              = get_peer_node($conf, $node);
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in poweron_node(), node: [$node], peer: [$peer], cluster name: [$node_cluster_name]\n");
	
	# Has the timer expired?
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; current time: [".time."], cgi::expire: [$conf->{cgi}{expire}].\n");
	if (time > $conf->{cgi}{expire})
	{
		# Abort!
		my $say_title   = AN::Common::get_string($conf, {key => "title_0188"});
		my $say_message = AN::Common::get_string($conf, {key => "message_0447", variables => {
			node	=>	$conf->{cgi}{node_cluster_name},
		}});
		print AN::Common::template($conf, "server.html", "request-expired", {
			title		=>	$say_title,
			message		=>	$say_message,
		});
		return(1);
	}
	
	# Scan the cluster, then confirm that withdrawl is still enabled.
	AN::Cluster::scan_cluster($conf);
	my $proceed      = 1;
	my @abort_reason = "";
	
	my $fence_string = "";
	# See if I already have the fence string. If not, load it from cache.
	if ($conf->{node}{$node}{info}{fence_methods})
	{
		$fence_string = $conf->{node}{$node}{info}{fence_methods};
	}
	else
	{
		AN::Cluster::read_node_cache($conf, $node);
		if ($conf->{node}{$node}{info}{fence_methods})
		{
			$fence_string = $conf->{node}{$node}{info}{fence_methods};
		}
		else
		{
			$proceed      = 0;
			my $reason = AN::Common::get_string($conf, {key => "message_0231", variables => {
				node	=>	$node,
			}});
			push @abort_reason, "$reason\n";
		}
	}
	
	# If the peer node is up, use the fence command as compiled by it. 
	# Otherwise, read the cache. If the fence command(s) are still not
	# available, abort.
	if ($proceed)
	{
		if (not $conf->{node}{$peer}{up})
		{
			# See if this machine can reach each '-a ...' fence device
			# address.
			foreach my $address ($fence_string =~ /-a\s(.*?)\s/g)
			{
				my ($local_access, $target_ip) = AN::Cluster::on_same_network($conf, $address, $node);
				if (not $local_access)
				{
					$proceed = 0;
					my $reason = AN::Common::get_string($conf, {key => "message_0232", variables => {
						node	=>	$node,
						peer	=>	$peer,
						address	=>	$address,
					}});
					push @abort_reason, "$reason\n";
				}
			}
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], proceed: [$proceed]\n");
	if ($proceed)
	{
		my $say_title = AN::Common::get_string($conf, {key => "title_0068", variables => {
			node_anvil_name	=>	$node_cluster_name,
		}});
		my $say_message = AN::Common::get_string($conf, {key => "message_0233", variables => {
			node_anvil_name	=>	$node_cluster_name,
		}});
		print AN::Common::template($conf, "server.html", "fence-node-header", {
			title	=>	$say_title,
			message	=>	$say_message,
		});
		# This loops for each method, which may have multiple device 
		# calls. I parse each call into an 'off' and 'on' call. If the
		# 'off' call fails, I go to the next method until there are no
		# methods left. If the 'off' works, I call the 'on' call from
		# the same method to (try to) boot the node back up (or simply
		# unfence it in the case of PDUs and the like).
		my $fence_success   = 0;
		my $unfence_success = 0;
		foreach my $line ($fence_string =~ /\d+:.*?;\./g)
		{
			print AN::Common::template($conf, "server.html", "fence-node-output-header");
			my ($method_num, $method_name, $command) = ($line =~ /(\d+):(.*?): (.*?;)\./);
			my $off_command = $command;
			my $on_command  = $command;
			my $off_success = 1;
			my $on_success  = 1;
			
			# If the peer is up, set the command to run through it.
			if ($conf->{node}{$peer}{up})
			{
				# When called remotely, I need to double-escape
				# the $? to protect it inside the "".
				$off_command =~ s/#!action!#;/off; echo fence:\$?;/g;
				$on_command  =~ s/#!action!#;/on;  echo fence:\$?;/g;
				$off_command = "ssh:$peer,$off_command";
				$on_command  = "ssh:$peer,$on_command";
			}
			else
			{
				# When called locally, I only need to escape
				# the $? once.
				$off_command =~ s/#!action!#;/off; echo fence:\$?;/g;
				$on_command  =~ s/#!action!#;/on;  echo fence:\$?;/g;
			}
			
			# Make the off attempt.
			my $output = [];
			my $ssh_fh;
			my $shell_call = "$off_command";
			if ($shell_call =~ /ssh:(.*?),(.*)$/)
			{
				my $node    = $1;
				my $command = $2;
				(my $error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
					node		=>	$node,
					port		=>	$conf->{node}{$node}{port},
					user		=>	"root",
					password	=>	$conf->{sys}{root_password},
					ssh_fh		=>	"",
					'close'		=>	0,
					shell_call	=>	"$command",
				});
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
			}
			else
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
				open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
				while(<$file_handle>)
				{
					chomp;
					push @{$output}, $_;
				}
				$file_handle->close()
			}
			foreach my $line (@{$output})
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], line: [$line]\n");
				# This is how I get the fence call's exit code.
				if ($line =~ /fence:(\d+)/)
				{
					# Anything but '0' is a failure.
					my $exit = $1;
					if ($exit ne "0")
					{
						$off_success = 0;
					}
				}
				else
				{
					print AN::Common::template($conf, "server.html", "one-line-message", {
						message	=>	$line,
					});
				}
			}
			print AN::Common::template($conf, "server.html", "fence-node-output-footer");
			if ($off_success)
			{
				# Fence succeeded!
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Fencing using the '$method_name' method succeeded. Proceeding with unfence action.\n");
				my $say_message = AN::Common::get_string($conf, {key => "message_0234", variables => {
					method_name	=>	$method_name,
				}});
				print AN::Common::template($conf, "server.html", "fence-node-message", {
					message	=>	$say_message,
				});
				$fence_success = 1;
			}
			else
			{
				# Fence failed!
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Fencing using the '$method_name' method failed. Will try next method, if available.\n");
				my $say_message = AN::Common::get_string($conf, {key => "message_0235", variables => {
					method_name	=>	$method_name,
				}});
				print AN::Common::template($conf, "server.html", "fence-node-message", {
					message	=>	$say_message,
				});
				next;
			}
			
			# If I'm here, I can try the unfence command.
			print AN::Common::template($conf, "server.html", "fence-node-unfence-header");
			$shell_call = "$on_command";
			if ($shell_call =~ /ssh:(.*?),(.*)$/)
			{
				my $node    = $1;
				my $command = $2;
				(my $error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
					node		=>	$node,
					port		=>	$conf->{node}{$node}{port},
					user		=>	"root",
					password	=>	$conf->{sys}{root_password},
					ssh_fh		=>	$ssh_fh,
					'close'		=>	1,
					shell_call	=>	"$command",
				});
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
			}
			else
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$shell_call]\n");
				open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
				while(<$file_handle>)
				{
					chomp;
					push @{$output}, $_;
				}
				$file_handle->close()
			}
			foreach my $line (@{$output})
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], line: [$line]\n");
				# This is how I get the fence call's exit code.
				if ($line =~ /fence:(\d+)/)
				{
					# Anything but '0' is a failure.
					my $exit = $1;
					if ($exit ne "0")
					{
						$on_success = 0;
					}
				}
				else
				{
					print AN::Common::template($conf, "server.html", "one-line-message", {
						message	=>	$line,
					});
				}
			}
			print AN::Common::template($conf, "server.html", "fence-node-unfence-footer");
			if ($on_success)
			{
				# Unfence succeeded!
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Unfencing using the '$method_name' method succeeded. Fence operation a complete success!\n");
				my $say_message = AN::Common::get_string($conf, {key => "message_0236", variables => {
					method_name	=>	$method_name,
				}});
				print AN::Common::template($conf, "server.html", "fence-node-message", {
					message	=>	$say_message,
				});
				$unfence_success = 1;
				last;
			}
			else
			{
				# Unfence failed!
				# This is allowed to go to the next fence method
				# because some servers may hang their IPMI 
				# interface after a fence call, requiring power
				# to be cut in order to reset the BMC. HP, I'm
				# looking at you and your DL1** G7 line...
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Unfencing using the '$method_name' method failed. The core fence action was a success, but something went wrong and manual intervention may be required before the node can be returned to service. If another fence method remains, it will now be tried in hopes of assisting recovery.\n");
				my $say_message = AN::Common::get_string($conf, {key => "message_0237", variables => {
					method_name	=>	$method_name,
				}});
				print AN::Common::template($conf, "server.html", "fence-node-message", {
					message	=>	$say_message,
				});
			}
		}
	}
	else
	{
		my $say_title = AN::Common::get_string($conf, {key => "title_0069", variables => {
			node_anvil_name	=>	$node_cluster_name,
		}});
		print AN::Common::template($conf, "server.html", "fence-node-aborted-header", {
			title	=>	$say_title,
		});
		foreach my $reason (@abort_reason)
		{
			print AN::Common::template($conf, "server.html", "fence-node-abort-reason", {
				reason	=>	$reason,
			});
		}
	}
	print AN::Common::template($conf, "server.html", "fence-node-footer");
	AN::Cluster::footer($conf);
	
	return(0);
}

# This does a final check of the target node then withdraws it from the
# cluster.
sub withdraw_node
{
	my ($conf) = @_;
	
	# Make sure no VMs are running.
	my $node              = $conf->{cgi}{node};
	my $node_cluster_name = $conf->{cgi}{node_cluster_name};
	
	# Scan the cluster, then confirm that withdrawl is still enabled.
	AN::Cluster::scan_cluster($conf);
	my $proceed = $conf->{node}{$node}{enable_withdraw};
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in withdraw_node(), node: [$node], proceed: [$proceed]\n");
	if ($proceed)
	{
		# Stop rgmanager and then check it's status.
		my $say_title = AN::Common::get_string($conf, {key => "title_0070", variables => {
			node_anvil_name	=>	$node_cluster_name,
		}});
		print AN::Common::template($conf, "server.html", "withdraw-node-header", {
			title	=>	$say_title,
		});

		my $rgmanager_stop = 1;
		my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	"/etc/init.d/rgmanager stop",
		});
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			if ($line =~ /failed/i)
			{
				$rgmanager_stop = 0;
			}
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			$line = parse_text_line($conf, $line);
			my $message = ($line =~ /^(.*)\[/)[0];
			my $status  = ($line =~ /(\[.*)$/)[0];
			if (not $message)
			{
				$message = $line;
				$status  = "";
			}
			print AN::Common::template($conf, "server.html", "start-server-shell-output", {
				status	=>	$status,
				message	=>	$message,
			});
		}
		print AN::Common::template($conf, "server.html", "withdraw-node-close-output");
		if ($rgmanager_stop)
		{
			print AN::Common::template($conf, "server.html", "withdraw-node-resource-manager-stopped");
			my $cman_stop = 1;
			($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
				node		=>	$node,
				port		=>	$conf->{node}{$node}{port},
				user		=>	"root",
				password	=>	$conf->{sys}{root_password},
				ssh_fh		=>	$ssh_fh,
				'close'		=>	0,
				shell_call	=>	"/etc/init.d/cman stop",
			});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
			foreach my $line (@{$output})
			{
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				$line =~ s/\s+/ /g;
				if ($line =~ /failed/i)
				{
					$cman_stop = 0;
				}
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
				$line = parse_text_line($conf, $line);
				my $message = ($line =~ /^(.*)\[/)[0];
				my $status  = ($line =~ /(\[.*)$/)[0];
				if (not $message)
				{
					$message = $line;
					$status  = "";
				}
				print AN::Common::template($conf, "server.html", "start-server-shell-output", {
					status	=>	$status,
					message	=>	$message,
				});
			}
			print AN::Common::template($conf, "server.html", "withdraw-node-close-output");

			if (not $cman_stop)
			{
				# Crap...
				print AN::Common::template($conf, "server.html", "withdraw-node-membership-withdrawl-failed");
				my $cman_start = 1;
				($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
					node		=>	$node,
					port		=>	$conf->{node}{$node}{port},
					user		=>	"root",
					password	=>	$conf->{sys}{root_password},
					ssh_fh		=>	$ssh_fh,
					'close'		=>	1,
					shell_call	=>	"/etc/init.d/cman start",
				});
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
				foreach my $line (@{$output})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					if ($line =~ /failed/i)
					{
						$cman_start = 0;
					}
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
					$line = parse_text_line($conf, $line);
					my $message = ($line =~ /^(.*)\[/)[0];
					my $status  = ($line =~ /(\[.*)$/)[0];
					if (not $message)
					{
						$message = $line;
						$status  = "";
					}
					print AN::Common::template($conf, "server.html", "start-server-shell-output", {
						status	=>	$status,
						message	=>	$message,
					});
				}
				print AN::Common::template($conf, "server.html", "withdraw-node-close-output");
				if ($cman_start)
				{
					# and we're back
					print AN::Common::template($conf, "server.html", "withdraw-node-membership-restarted-successfully");
					recover_rgmanager($conf, $node);
					
				}
				else
				{
					# Failed, call support.
					print AN::Common::template($conf, "server.html", "withdraw-node-membership-restarted-failed");
				}
			}
		}
		else
		{
			# Recover rgmanager
			print AN::Common::template($conf, "server.html", "withdraw-node-resource-manager-failed-to-stop");
			recover_rgmanager($conf, $node);
		}
		print AN::Common::template($conf, "server.html", "withdraw-node-footer");
	}
	else
	{
		my $say_title = AN::Common::get_string($conf, {key => "title_0071", variables => {
			node_anvil_name	=>	$node_cluster_name,
		}});
		my $say_message = AN::Common::get_string($conf, {key => "message_0249", variables => {
			node_anvil_name	=>	$node_cluster_name,
		}});
		print AN::Common::template($conf, "server.html", "withdraw-node-aborted", {
			title	=>	$say_title,
			message	=>	$say_message,
		});
	}
	
	AN::Cluster::footer($conf);
	
	return(0);
}

# This restarts rgmanager and, if necessary, disables and re-enables the 
# storage service
sub recover_rgmanager
{
	my ($conf, $node) = @_;
	
	# Tell the user we're recovering rgmanager
	print AN::Common::template($conf, "server.html", "recover-resource-manager-header");
	my $rgmanager_start = 1;
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	1,
		shell_call	=>	"/etc/init.d/rgmanager start",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		if ($line =~ /failed/i)
		{
			$rgmanager_start = 0;
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		print AN::Common::template($conf, "server.html", "one-line-message", {
			message	=>	$line,
		});
	}
	print AN::Common::template($conf, "server.html", "recover-resource-manager-output-footer");

	if ($rgmanager_start)
	{
		my $storage_service = $conf->{node}{$node}{info}{storage_name};
		print AN::Common::template($conf, "server.html", "recover-resource-manager-successful");
		if ($storage_service)
		{
			# Need to rescan the Anvil!...
			# variables hash feeds 'message_0251'
			print AN::Common::template($conf, "server.html", "recover-resource-manager-check-storage", {}, {
				storage_service	=>	$storage_service,
			});
			
			# I need to sleep for ~ten seconds to give time for
			# 'clustat' to start showing the service section again.
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], rescanning the #!string!brand_0003!# in ten seconds.\n");
			sleep 10;
			AN::Cluster::check_node_status($conf);
			my $storage_state = $conf->{node}{$node}{info}{storage_state};
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], storage service: [$storage_service], storage state: [$storage_state]\n");
			if ($storage_state =~ /Failed/i) 
			{
				my $say_failed = AN::Common::get_string($conf, {key => "message_0253", variables => {
					storage_service	=>	$storage_service,
				}});
				my $say_cycle = AN::Common::get_string($conf, {key => "message_0254", variables => {
					storage_service	=>	$storage_service,
				}});
				print AN::Common::template($conf, "server.html", "recover-resource-manager-cycle-storage-service", {
					failed	=>	$say_failed,
					cycle	=>	$say_cycle,
				});

				# NOTE: This will return 'Warning' because of
				# whatever is holding open the storage. This is
				# fine, as the goal is to enable, not stop.
				my $storage_stop = 1;
				my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
					node		=>	$node,
					port		=>	$conf->{node}{$node}{port},
					user		=>	"root",
					password	=>	$conf->{sys}{root_password},
					ssh_fh		=>	"",
					'close'		=>	0,
					shell_call	=>	"$conf->{path}{clusvcadm} -d $storage_service",
				});
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
				foreach my $line (@{$output})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					if ($line =~ /failed/i)
					{
						$storage_stop = 0;
					}
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
					$line = parse_text_line($conf, $line);
					my $message = ($line =~ /^(.*)\[/)[0];
					my $status  = ($line =~ /(\[.*)$/)[0];
					if (not $message)
					{
						$message = $line;
						$status  = "";
					}
					print AN::Common::template($conf, "server.html", "start-server-shell-output", {
						status	=>	$status,
						message	=>	$message,
					});
				}
				print AN::Common::template($conf, "server.html", "recover-resource-manager-close-output");

				if ($storage_stop)
				{
					my $say_stopped = AN::Common::get_string($conf, {key => "message_0255", variables => {
						storage_service	=>	$storage_service,
					}});
					print AN::Common::template($conf, "server.html", "recover-resource-manager-storage-service-stopped", {
						stopped	=>	$say_stopped,
					});
					
					my $storage_start = 1;
					($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
						node		=>	$node,
						port		=>	$conf->{node}{$node}{port},
						user		=>	"root",
						password	=>	$conf->{sys}{root_password},
						ssh_fh		=>	"",
						'close'		=>	1,
						shell_call	=>	"$conf->{path}{clusvcadm} -e $storage_service",
					});
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
					foreach my $line (@{$output})
					{
						$line =~ s/^\s+//;
						$line =~ s/\s+$//;
						$line =~ s/\s+/ /g;
						if ($line =~ /failed/i)
						{
							$storage_start = 0;
						}
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
						$line = parse_text_line($conf, $line);
						my $message = ($line =~ /^(.*)\[/)[0];
						my $status  = ($line =~ /(\[.*)$/)[0];
						if (not $message)
						{
							$message = $line;
							$status  = "";
						}
						print AN::Common::template($conf, "server.html", "start-server-shell-output", {
							status	=>	$status,
							message	=>	$message,
						});
					}
					print AN::Common::template($conf, "server.html", "recover-resource-manager-close-output");
					
					if ($storage_start)
					{
						# Hoozah!
						my $say_restarted = AN::Common::get_string($conf, {key => "message_0257", variables => {
							storage_service	=>	$storage_service,
						}});
						my $say_advice = AN::Common::get_string($conf, {key => "message_0259", variables => {
							node	=>	$node,
						}});
						print AN::Common::template($conf, "server.html", "recover-resource-manager-storage-service-recovered", {
							restarted	=>	$say_restarted,
							advice		=>	$say_advice,
						});
					}
					else
					{
						# We're boned.
						my $say_failed = AN::Common::get_string($conf, {key => "message_0262", variables => {
							storage_service	=>	$storage_service,
						}});
						print AN::Common::template($conf, "server.html", "recover-resource-manager-storage-service-unrecovered", {
							failed	=>	$say_failed,
						});
					}
				}
				else
				{
					# Failed to disable.
					my $say_failed = AN::Common::get_string($conf, {key => "message_0263", variables => {
						storage_service	=>	$storage_service,
					}});
					print AN::Common::template($conf, "server.html", "recover-resource-manager-failed-to-disable", {
						failed	=>	$say_failed,
					});
				}
			}
			else
			{
				# Storage service is running, recovery unneeded.
				# TODO: Check each individual storage service
				# and restart each if needed.
				my $say_abort = AN::Common::get_string($conf, {key => "message_0264", variables => {
					storage_service	=>	$storage_service,
				}});
				print AN::Common::template($conf, "server.html", "recover-resource-manager-abort-storage-recovery", {
					abort	=>	$say_abort,
				});
			}
		}
		else
		{
			# Unable to identify the storage service
			print AN::Common::template($conf, "server.html", "recover-resource-manager-cant-find-storage");
		}
	}
	else
	{
		# Failed. :(
		print AN::Common::template($conf, "server.html", "recover-resource-manager-failed");
	}
	
	return(0);
}

# This creates the summary page after a cluster has been selected.
sub display_details
{
	my ($conf) = @_;
	
	#print AN::Common::template($conf, "server.html", "display-details-header");
	# Display the status of each node's daemons
	my $up_nodes = @{$conf->{up_nodes}};
	
	# TODO: Rework this, I always show nodes now so that the 'fence_...' 
	# calls are available. IE: enable this when the cache exists and the
	# fence command addresses are reachable.
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; show nodes: [$conf->{sys}{show_nodes}], up nodes: [$conf->{sys}{up_nodes}] ($up_nodes)\n");
#	if ($conf->{sys}{show_nodes})
	if (1)
	{
		my $node_control_panel = display_node_controls($conf);
		#print $node_control_panel;
		
		my $vm_state_and_control_panel = "";
		my $node_details_panel         = "";
		my $server_details_panel       = "";
		my $gfs2_details_panel         = "";
		my $drbd_details_panel         = "";
		my $free_resources_panel       = "";
		my $no_access_panel            = "";
		my $watchdog_panel             = "";

		# I don't show below here unless at least one node is up.
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; up nodes: [$conf->{sys}{up_nodes}] ($up_nodes)\n");
		if ($conf->{sys}{up_nodes} > 0)
		{
			# Show the user the current VM states and the control buttons.
			$vm_state_and_control_panel = display_vm_state_and_controls($conf);
			#print $vm_state_and_control_panel;
			
			# Show the state of the daemons.
			$node_details_panel = display_node_details($conf);
			#print $node_details_panel;
		
			# Show the details about each VM.
			$server_details_panel = display_vm_details($conf);
			#print $server_details_panel;
			
			# Show the status of each node's GFS2 share(s)
			$gfs2_details_panel = display_gfs2_details($conf);
			#print $gfs2_details_panel;
			
			# This shows the status of each DRBD resource in the cluster.
			$drbd_details_panel = display_drbd_details($conf);
			#print $drbd_details_panel;
			
			# Show the free resources available for new VMs.
			$free_resources_panel = display_free_resources($conf);
			#print $free_resources_panel;
			
			# This generates a panel below 'Available Resources' 
			# *if* the user has enabled 'tools::anvil-kick-apc-ups::enabled'
			$watchdog_panel = display_watchdog_panel($conf);
		}
		else
		{
			# Was able to confirm the nodes are off.
			$no_access_panel = AN::Common::template($conf, "server.html", "display-details-nodes-unreachable", {
				message	=>	"#!string!message_0268!#",
			});
		}
		
		print AN::Common::template($conf, "server.html", "main-page", {
			node_control_panel		=>	$node_control_panel,
			vm_state_and_control_panel	=>	$vm_state_and_control_panel,
			node_details_panel		=>	$node_details_panel,
			server_details_panel		=>	$server_details_panel,
			gfs2_details_panel		=>	$gfs2_details_panel,
			drbd_details_panel		=>	$drbd_details_panel,
			free_resources_panel		=>	$free_resources_panel,
			no_access_panel			=>	$no_access_panel,
			watchdog_panel			=>	$watchdog_panel,
		});
	}
	
	return (0);
}

# This returns a panel for controlling hard-resets via the 'APC UPS Watchdog' tools
sub display_watchdog_panel
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in display_watchdog_panel()\n");
	
	my $watchdog_panel = "";
	my $use_node       = "";
	my $this_cluster   = $conf->{cgi}{cluster};
	my $enable         = 0;
	foreach my $node (sort {$a cmp $b} @{$conf->{clusters}{$this_cluster}{nodes}})
	{
		if ($conf->{node}{$node}{up})
		{
			$use_node = $node;
			last;
		}
	}
	
	# Return nothing if this feature is disabled or if neither node is up.
# 	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; tools::anvil-kick-apc-ups::enabled: [$conf->{tools}{'anvil-kick-apc-ups'}{enabled}], use_node: [$use_node].\n");
# 	return("") if ((not $conf->{tools}{'anvil-kick-apc-ups'}{enabled}) or (not $use_node));
	return("") if (not $use_node);
	my $node = $use_node;

	# Check that 'anvil-kick-apc-ups' exists.
	my $shell_call = "
if \$($conf->{path}{nodes}{'grep'} -q '^tools::anvil-kick-apc-ups::enabled\\s*=\\s*1' $conf->{path}{nodes}{striker_config});
then 
    echo enabled; 
else 
    echo disabled;
fi";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
	my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	$conf->{node}{$node}{port},
		user		=>	"root",
		password	=>	$conf->{sys}{root_password},
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
	foreach my $line (@{$output})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line eq "enabled")
		{
			$enable = 1;
		}
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; enable: [$enable]\n");
	if ($enable)
	{
		# It exists, load the template
		my $expire_time = time + $conf->{sys}{actime_timeout};
		$watchdog_panel = AN::Common::template($conf, "server.html", "watchdog_panel", {
			power_cycle	=>	"?cluster=$conf->{cgi}{cluster}&expire=$expire_time&task=cold_stop&subtask=power_cycle",
			power_off	=>	"?cluster=$conf->{cgi}{cluster}&expire=$expire_time&task=cold_stop&subtask=power_off",
		}, "", 1);
		$watchdog_panel =~ s/\n$//;
	}
	
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; watchdog_panel: [$watchdog_panel].\n");
	return($watchdog_panel);
}

# This shows the free resources available to be assigned to new VMs.
sub display_free_resources
{
	my ($conf) = @_;
	
	my $free_resources_panel .= AN::Common::template($conf, "server.html", "display-details-free-resources-header");
	
	# I only show one row for CPU and RAM, but usually have two or more
	# VGs. So the first step is to put my VG info into an array.
	my $enough_storage = 0;
	my $available_ram  = 0;
	my $max_cpu_cores  = 0;
	my @vg;
	my @vg_size;
	my @vg_used;
	my @vg_free;
	my @pv_name;
	my $vg_link="";
	foreach my $vg (sort {$a cmp $b} keys %{$conf->{resources}{vg}})
	{
		# If it's not a clustered VG, I don't care about it.
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vg: [$vg], clustered: [$conf->{resources}{vg}{$vg}{clustered}]\n");
		next if not $conf->{resources}{vg}{$vg}{clustered};
		push @vg,      $vg;
		push @vg_size, $conf->{resources}{vg}{$vg}{size};
		push @vg_used, $conf->{resources}{vg}{$vg}{used_space};
		push @vg_free, $conf->{resources}{vg}{$vg}{free_space};
		push @pv_name, $conf->{resources}{vg}{$vg}{pv_name};
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vg: [$vg], size: [$conf->{resources}{vg}{$vg}{size}], used space: [$conf->{resources}{vg}{$vg}{used_space}], free space: [$conf->{resources}{vg}{$vg}{free_space}], pv name: [$conf->{resources}{vg}{$vg}{pv_name}]\n");
		
		# If there is at least a GiB free, mark free storage as
		# sufficient.
		if (not $conf->{sys}{clvmd_down})
		{
			$enough_storage =  1 if $conf->{resources}{vg}{$vg}{free_space} > (2**30);
			$vg_link        .= "$vg:$conf->{resources}{vg}{$vg}{free_space},";
		}
	}
	$vg_link =~ s/,$//;
	
	# Count how much RAM and CPU cores have been allocated.
	my $allocated_cores = 0;
	my $allocated_ram   = 0;
	foreach my $vm (sort {$a cmp $b} keys %{$conf->{vm}})
	{
		next if $vm !~ /^vm/;
		# I check GFS2 because, without it, I can't read the VM's details.
		if ($conf->{sys}{gfs2_down})
		{
			$allocated_ram   = "#!string!symbol_0011!#";
			$allocated_cores = "#!string!symbol_0011!#";
		}
		else
		{
			$allocated_ram   += $conf->{vm}{$vm}{details}{ram};
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; allocated_ram: [$allocated_ram], vm: [$vm], ram: [$conf->{vm}{$vm}{details}{ram}]\n");
			$allocated_cores += $conf->{vm}{$vm}{details}{cpu_count};
		}
	}
	
	# Always knock off some RAM for the host OS.
	my $real_total_ram            =  AN::Cluster::bytes_to_hr($conf, $conf->{resources}{total_ram});
	# Reserved RAM and BIOS memory holes rarely leave us with an even GiB
	# of total RAM. So we modulous off the difference, then subtract that
	# plus the reserved RAM to get an even left-over amount of memory for
	# the user to allocate to their servers.
	my $diff                      = $conf->{resources}{total_ram} % (1024 ** 3);
	$conf->{resources}{total_ram} = $conf->{resources}{total_ram} - $diff - $conf->{sys}{unusable_ram};
	$conf->{resources}{total_ram} =  0 if $conf->{resources}{total_ram} < 0;
	my $free_ram                  =  $conf->{sys}{gfs2_down}  ? 0    : $conf->{resources}{total_ram} - $allocated_ram;
	my $say_free_ram              =  $conf->{sys}{gfs2_down}  ? "--" : AN::Cluster::bytes_to_hr($conf, $free_ram);
	my $say_total_ram             =  AN::Cluster::bytes_to_hr($conf, $conf->{resources}{total_ram});
	my $say_allocated_ram         =  $conf->{sys}{gfs2_down}  ? "--" : AN::Cluster::bytes_to_hr($conf, $allocated_ram);
	my $say_vg_size               =  $conf->{sys}{clvmd_down} ? "--" : AN::Cluster::bytes_to_hr($conf, $vg_size[0]);
	my $say_vg_used               =  $conf->{sys}{clvmd_down} ? "--" : AN::Cluster::bytes_to_hr($conf, $vg_used[0]);
	my $say_vg_free               =  $conf->{sys}{clvmd_down} ? "--" : AN::Cluster::bytes_to_hr($conf, $vg_free[0]);
	my $say_vg                    =  $conf->{sys}{clvmd_down} ? "--" : $vg[0];
	my $say_pv_name               =  $conf->{sys}{clvmd_down} ? "--" : $pv_name[0];
	
	# Show the main info.
	$free_resources_panel .= AN::Common::template($conf, "server.html", "display-details-free-resources-entry", {
		total_cores		=>	$conf->{resources}{total_cores},
		total_threads		=>	$conf->{resources}{total_threads},
		allocated_cores		=>	$allocated_cores,
		real_total_ram		=>	$real_total_ram,
		say_total_ram		=>	$say_total_ram,
		say_allocated_ram	=>	$say_allocated_ram,
		say_free_ram		=>	$say_free_ram,
		say_vg			=>	$say_vg,
		say_pv_name		=>	$say_pv_name,
		say_vg_size		=>	$say_vg_size,
		say_vg_used		=>	$say_vg_used,
		say_vg_free		=>	$say_vg_free,
	});

	if (@vg > 0)
	{
		for (my $i=1; $i < @vg; $i++)
		{
			my $say_vg_size = AN::Cluster::bytes_to_hr($conf, $vg_size[$i]);
			my $say_vg_used = AN::Cluster::bytes_to_hr($conf, $vg_used[$i]);
			my $say_vg_free = AN::Cluster::bytes_to_hr($conf, $vg_free[$i]);
			my $say_pv_name = $pv_name[$i];
			$free_resources_panel .= AN::Common::template($conf, "server.html", "display-details-free-resources-entry-extra-storage", {
				vg		=>	$vg[$i],
				pv_name		=>	$pv_name[$i],
				say_vg_size	=>	$say_vg_size,
				say_vg_used	=>	$say_vg_used,
				say_vg_free	=>	$say_vg_free,
			});
		}
	}
	
	### NOTE: Disabled in this release.
	# If I found enough free disk space, have at least 1 GiB of free RAM 
	# and both nodes are up, enable the "provision new server" button.
	my $node1   = $conf->{sys}{cluster}{node1_name};
	my $node2   = $conf->{sys}{cluster}{node2_name};
	#my $say_bns = "<span class=\"disabled_button\">#!string!button_0022!#</span>";
	#my $say_mc  = "<span class=\"disabled_button\">#!string!button_0023!#</span>";
	my $say_bns = AN::Common::template($conf, "common.html", "disabled-button", {
		button_text	=>	"#!string!button_0022!#",
	}, "", 1);
	my $say_mc = AN::Common::template($conf, "common.html", "disabled-button", {
		button_text	=>	"#!string!button_0023!#",
	}, "", 1);
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in enough_storage: [$enough_storage], free_ram: [$free_ram], node1 cman: [$conf->{node}{$node1}{daemon}{cman}{exit_code}], node2 cman: [$conf->{node}{$node2}{daemon}{cman}{exit_code}]\n");
	if (($conf->{node}{$node1}{daemon}{cman}{exit_code} eq "0") && 
	    ($conf->{node}{$node2}{daemon}{cman}{exit_code} eq "0"))
	{
		# The cluster is running, so enable the media library link.
		$say_mc = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
			button_link	=>	"/cgi-bin/mediaLibrary?cluster=$conf->{cgi}{cluster}",
			button_text	=>	"#!string!button_0023!#",
			id		=>	"media_library_$conf->{cgi}{cluster}",
		}, "", 1);
		
		# Enable the "New Server" button if there is enough free memory
		# and storage space.
		if (($enough_storage) && ($free_ram > $conf->{sys}{server}{minimum_ram}))
		{
			$say_bns = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
				button_link	=>	"?cluster=$conf->{cgi}{cluster}&task=provision&max_ram=$free_ram&max_cores=$conf->{resources}{total_cores}&max_storage=$vg_link",
				button_text	=>	"#!string!button_0022!#",
				id		=>	"provision",
			}, "", 1);
		}
	}
	$free_resources_panel .= AN::Common::template($conf, "server.html", "display-details-bottom-button-bar", {
		say_bns	=>	$say_bns,
		say_mc	=>	$say_mc,
	});
	$free_resources_panel .= AN::Common::template($conf, "server.html", "display-details-footer");

	return ($free_resources_panel);
}

# Simply converts a full domain name back to the node name used in the main hash.
sub long_host_name_to_node_name
{
	my ($conf, $host) = @_;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in long_host_name_to_node_name(), host: [$host]\n");
	
	my $cluster   = $conf->{cgi}{cluster};
	my $node_name = "";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cluster: [$cluster]\n");
	foreach my $node (sort {$a cmp $b} @{$conf->{clusters}{$cluster}{nodes}})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node]\n");
		my $short_host =  $host;
		   $short_host =~ s/\..*$//;
		my $short_node =  $node;
		   $short_node =~ s/\..*$//;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; short_host: [$short_host], short_node: [$short_node]\n");
		if ($short_host eq $short_node)
		{
			$node_name = $node;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node name: [$node_name]\n");
			last;
		}
	}
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node name: [$node_name]\n");
	return ($node_name);
}

# Simply converts a node name to the full domain name.
sub node_name_to_long_host_name
{
	my ($conf, $host) = @_;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in node_name_to_long_host_name(), host: [$host]\n");
	
	my $node_name = $conf->{node}{$host}{me}{name};

	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node name: [$node_name]\n");
	return ($node_name);
}

# This just shows the details of the server (no controls)
sub display_vm_details
{
	my ($conf) = @_;
	
	my $node1 = $conf->{sys}{cluster}{node1_name};
	my $node2 = $conf->{sys}{cluster}{node2_name};
	my $server_details_panel = AN::Common::template($conf, "server.html", "display-server-details-header");
	
	# Pull up the server details.
	foreach my $vm (sort {$a cmp $b} keys %{$conf->{vm}})
	{
		next if $vm !~ /^vm/;
		
		my $say_vm  = ($vm =~ /^vm:(.*)/)[0];
		my $say_ram = $conf->{sys}{gfs2_down} ? "#!string!symbol_0011!#" : AN::Cluster::bytes_to_hr($conf, $conf->{vm}{$vm}{details}{ram});
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], say_ram: [$say_ram], ram: [$conf->{vm}{$vm}{details}{ram}]\n");
		
		# Get the LV arrays populated.
		my @lv_path;
		my @lv_size;
		my $host = $conf->{vm}{$vm}{host};
		
		# If the host is "none", read the details from one of the "up"
		# nodes.
		if ($host eq "none")
		{
			# If the first node is running, use it. Otherwise use
			# the second node.
			my $node1_daemons_running = check_node_daemons($conf, $node1);
			my $node2_daemons_running = check_node_daemons($conf, $node2);
			if ($node1_daemons_running)
			{
				$host = $node1;
			}
			elsif ($node2_daemons_running)
			{
				$host = $node2;
			}
		}
		
		my @bridge;
		my @device;
		my @mac;
		my @type;
		my $node         = "--";
		my $say_net_host = ""; # Don't want anything printed when the server is down
		my $say_host     = "--";
		if ($host)
		{
			$node = long_host_name_to_node_name($conf, $host);
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], host: [$host], node: [$node]\n");
			
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], host: [$host], node: [$node], lv hash on node1: [$conf->{vm}{$vm}{node}{$node1}{lv}], lv hash on node2: [$conf->{vm}{$vm}{node}{$node2}{lv}]\n");
			foreach my $lv (sort {$a cmp $b} keys %{$conf->{vm}{$vm}{node}{$node}{lv}})
			{
				#record ($conf, "$THIS_FILE ".__LINE__."; lv: [$lv], size: [$conf->{vm}{$vm}{node}{$node}{lv}{$lv}{size}]\n");
				push @lv_path, $lv;
				push @lv_size, $conf->{vm}{$vm}{node}{$node}{lv}{$lv}{size};
			}
			
			# Get the network arrays built.
			foreach my $current_bridge (sort {$a cmp $b} keys %{$conf->{vm}{$vm}{details}{bridge}})
			{
				push @bridge, $current_bridge;
				push @device, $conf->{vm}{$vm}{details}{bridge}{$current_bridge}{device};
				push @mac,    uc($conf->{vm}{$vm}{details}{bridge}{$current_bridge}{mac});
				push @type,   $conf->{vm}{$vm}{details}{bridge}{$current_bridge}{type};
			}
			
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], host: [$conf->{vm}{$vm}{host}]\n");
			if ($conf->{vm}{$vm}{host} ne "none")
			{
				$say_host  =  $conf->{vm}{$vm}{host};
				$say_host  =~ s/\..*//;
				$say_net_host = AN::Common::template($conf, "server.html", "display-server-details-network-entry", {
					host	=>	$say_host,
					bridge	=>	$bridge[0],
					device	=>	$device[0],
				});
			}
		}
		
		# If there is no host, only the device type and MAC address are valid.
		$conf->{vm}{$vm}{details}{cpu_count} = "#!string!symbol_0011!#" if $conf->{sys}{gfs2_down};
		$lv_path[0]                          = "#!string!symbol_0011!#" if $conf->{sys}{gfs2_down};
		$lv_size[0]                          = "#!string!symbol_0011!#" if $conf->{sys}{gfs2_down};
		$type[0]                             = "#!string!symbol_0011!#" if $conf->{sys}{gfs2_down};
		$mac[0]                              = "#!string!symbol_0011!#" if $conf->{sys}{gfs2_down};
		$conf->{vm}{$vm}{details}{cpu_count} = "--" if not defined $conf->{vm}{$vm}{details}{cpu_count};
		$say_ram                             = "--" if ((not $say_ram) or ($say_ram =~ /^0 /));
		$lv_path[0]                          = "--" if not defined $lv_path[0];
		$lv_size[0]                          = "--" if not defined $lv_size[0];
		$type[0]                             = "--" if not defined $type[0];
		$mac[0]                              = "--" if not defined $mac[0];
		$server_details_panel .= AN::Common::template($conf, "server.html", "display-server-details-resources", {
				say_vm		=>	$say_vm,
				cpu_count	=>	$conf->{vm}{$vm}{details}{cpu_count},
				say_ram		=>	$say_ram,
				lv_path		=>	$lv_path[0],
				lv_size		=>	$lv_size[0],
				say_net_host	=>	$say_net_host,
				type		=>	$type[0],
				mac		=>	$mac[0],
			});

		my $lv_count   = @lv_path;
		my $nic_count  = @bridge;
		my $loop_count = $lv_count >= $nic_count ? $lv_count : $nic_count;
		if ($loop_count > 0)
		{
			for (my $i=1; $loop_count > $i; $i++)
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], lv_path[$i]: [$lv_path[$i]], lv_size[$i]: [$lv_size[$i]]n");
				my $say_lv_path = $lv_path[$i] ? $lv_path[$i] : "&nbsp;";
				my $say_lv_size = $lv_size[$i] ? $lv_size[$i] : "&nbsp;";
				my $say_network = "&nbsp;";
				if ($bridge[$i])
				{
					my $say_net_host = "";
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], host: [$conf->{vm}{$vm}{host}]\n");
					if ($conf->{vm}{$vm}{host} ne "none")
					{
						my $say_host  =  $conf->{vm}{$vm}{host};
						$say_host  =~ s/\..*//;
						$say_net_host = AN::Common::template($conf, "server.html", "display-server-details-entra-nics", {
							say_host	=>	$say_host,
							bridge		=>	$bridge[$i],
							device		=>	$device[$i],
						});
					}
					$say_network = "$say_net_host <span class=\"highlight_detail\">$type[$i]</span> / <span class=\"highlight_detail\">$mac[$i]</span>";
				}
				
				# Show extra LVs and/or networks.
				$server_details_panel .= AN::Common::template($conf, "server.html", "display-server-details-entra-storage", {
					say_lv_path	=>	$say_lv_path,
					say_lv_size	=>	$say_lv_size,
					say_network	=>	$say_network,
				});
			}
		}
	}
	$server_details_panel .= AN::Common::template($conf, "server.html", "display-server-details-footer");

	return ($server_details_panel);
}

# This checks the daemons running on a node and returns '1' if all are running.
sub check_node_daemons
{
	my ($conf, $node) = @_;
	if (not $node)
	{
		AN::Cluster::error($conf, "I was asked to check the daemons for a node, but was not passed a node name. This is likely a program error.\n");
	}
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in check_node_daemons(), node: [$node]\n");
	my $ready = 1;
	
# 	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], cman exit_code:      [$conf->{node}{$node}{daemon}{cman}{exit_code}]\n");
# 	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], rgmanager exit_code: [$conf->{node}{$node}{daemon}{rgmanager}{exit_code}]\n");
# 	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], drbd exit_code:      [$conf->{node}{$node}{daemon}{drbd}{exit_code}]\n");
# 	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], clvmd exit_code:     [$conf->{node}{$node}{daemon}{clvmd}{exit_code}]\n");
# 	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], gfs2 exit_code:      [$conf->{node}{$node}{daemon}{gfs2}{exit_code}]\n");
# 	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], libvirtd exit_code:  [$conf->{node}{$node}{daemon}{libvirtd}{exit_code}]\n");
	
	if (($conf->{node}{$node}{daemon}{cman}{exit_code} ne "0") ||
	($conf->{node}{$node}{daemon}{rgmanager}{exit_code} ne "0") ||
	($conf->{node}{$node}{daemon}{drbd}{exit_code} ne "0") ||
	($conf->{node}{$node}{daemon}{clvmd}{exit_code} ne "0") ||
	($conf->{node}{$node}{daemon}{gfs2}{exit_code} ne "0") ||
	($conf->{node}{$node}{daemon}{libvirtd}{exit_code} ne "0"))
	{
		$ready = 0;
	}
	
	return($ready);
}

# This checks a node to see if it's ready to run a given VM.
sub check_node_readiness
{
	my ($conf, $vm, $node) = @_;
	if (not $node)
	{
		AN::Cluster::error($conf, "I was asked to check the node readiness to run the $vm server, but was not passed a node name. This is likely a program error.\n");
	}

	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in check_node_readiness(); vm: [$vm], node: [$node]\n");
	
	# This will get negated if something isn't ready.
	my $ready = check_node_daemons($conf, $node);
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; 1. vm: [$vm], node: [$node], ready: [$ready]\n");
	
	# TODO: Add split-brain detection. If both nodes are 
	# Primary/StandAlone, shut the whole cluster down.
	
	# Make sure the storage is ready.
	if ($ready)
	{
		# Still alive, find out what storage backs this VM and ensure
		# that the LV is 'active' and that the DRBD resource(s) they
		# sit on are Primary and UpToDate.
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], vm: [$vm]\n");
		read_vm_definition($conf, $node, $vm);
		
		foreach my $lv (sort {$a cmp $b} keys %{$conf->{vm}{$vm}{node}{$node}{lv}})
		{
			# Make sure the LV is active.
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";  - vm: [$vm], node: [$node], lv: [$lv]\n");
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";    - active:           [$conf->{vm}{$vm}{node}{$node}{lv}{$lv}{active}]\n");
			if ($conf->{vm}{$vm}{node}{$node}{lv}{$lv}{active})
			{
				# It's active, so now check the backing storage.
				foreach my $res (sort {$a cmp $b} keys %{$conf->{vm}{$vm}{node}{$node}{lv}{$lv}{drbd}})
				{
					# For easier reading...
					my $cs = $conf->{vm}{$vm}{node}{$node}{lv}{$lv}{drbd}{$res}{connection_state};
					my $ro = $conf->{vm}{$vm}{node}{$node}{lv}{$lv}{drbd}{$res}{role};
					my $ds = $conf->{vm}{$vm}{node}{$node}{lv}{$lv}{drbd}{$res}{disk_state};
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";    - res:              [$res]\n");
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";    - connection state: [$cs]\n");
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";    - role:             [$ro]\n");
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__.";    - disk state:       [$ds]\n");
					
					# I consider a node "ready" if it is UpToDate and Primary.
					if (($ro ne "Primary") || ($ds ne "UpToDate"))
					{
						$ready = 0;
						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; 2. ready: [$ready]\n");
					}
				}
			}
			else
			{
				# The LV is inactive.
				# TODO: Try to change the LV to active.
				$ready = 0;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; 3. vm: [$vm], node: [$node], ready: [$ready]\n");
			}
		}
	}
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; 4. vm: [$vm], node: [$node], ready: [$ready]\n");
	
	return ($ready);
}

# This reads a VM's definition file and pulls out information about the system.
sub read_vm_definition
{
	my ($conf, $node, $vm) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; read_vm_definition(); node: [$node], vm: [$vm]\n");
	if (not $vm)
	{
		AN::Cluster::error($conf, "I was asked to look at a server's definition file, but no server was specified.", 1);
	}
	
	my $say_vm = $vm;
	if ($vm =~ /vm:(.*)/)
	{
		$say_vm = $1;
	}
	else
	{
		$vm = "vm:$vm";
	}
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], say_vm: [$say_vm]\n");
	$conf->{vm}{$vm}{definition_file} = "" if not defined $conf->{vm}{$vm}{definition_file};
	$conf->{vm}{$vm}{xml}             = "" if not defined $conf->{vm}{$vm}{xml};
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], say_vm: [$say_vm], definition_file: [$conf->{vm}{$vm}{definition_file}], XML array? [".ref($conf->{vm}{$vm}{xml})."]\n");

	# Here I want to parse the VM definition XML. Hopefully it was already
	# read in, but if not, I'll make a specific SSH call to get it.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], XML: [$conf->{vm}{$vm}{xml}], def: [$conf->{vm}{$vm}{definition_file}]\n");
	if ((not ref($conf->{vm}{$vm}{xml}) eq "ARRAY") && ($conf->{vm}{$vm}{definition_file}))
	{
		$conf->{vm}{$vm}{raw_xml} = [];
		$conf->{vm}{$vm}{xml}     = [];
		my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	$conf->{node}{$node}{port},
			user		=>	"root",
			password	=>	$conf->{sys}{root_password},
			ssh_fh		=>	"",
			'close'		=>	1,
			shell_call	=>	"cat $conf->{vm}{$vm}{definition_file}",
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
		foreach my $line (@{$output})
		{
			push @{$conf->{vm}{$vm}{raw_xml}}, $line;
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			push @{$conf->{vm}{$vm}{xml}}, $line;
		}
	}
	
	my $fill_raw_xml = 0;
	my $in_disk      = 0;
	my $in_interface = 0;
	my $current_bridge;
	my $current_device;
	my $current_mac_address;
	my $current_interface_type;
	if (not $conf->{vm}{$vm}{xml})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node]; I was asked to look at: [$vm]'s definition file, it was not read or was not found.\n");
		return (0);
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm::${vm}::raw_xml: [$conf->{vm}{$vm}{raw_xml}]\n");
	if (not ref($conf->{vm}{$vm}{raw_xml}) eq "ARRAY")
	{
		$conf->{vm}{$vm}{raw_xml} = [];
		$fill_raw_xml             = 1;
	}
	foreach my $line (@{$conf->{vm}{$vm}{xml}})
	{
		next if not $line;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], line: [$line], fill_raw_xml: [$fill_raw_xml]\n");
		push @{$conf->{vm}{$vm}{raw_xml}}, $line if $fill_raw_xml;
		
		# Pull out RAM amount.
		if ($line =~ /<memory>(\d+)<\/memory>/)
		{
			# Record the memory, multiple by 1024 to get bytes.
			$conf->{vm}{$vm}{details}{ram} =  $1;
			$conf->{vm}{$vm}{details}{ram} *= 1024;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], ram: [$conf->{vm}{$vm}{details}{ram}]\n");
		}
		if ($line =~ /<memory unit='(.*?)'>(\d+)<\/memory>/)
		{
			# Record the memory, multiple by 1024 to get bytes.
			my $units                      =  $1;
			my $ram                        =  $2;
			$conf->{vm}{$vm}{details}{ram} = AN::Cluster::hr_to_bytes($conf, $ram, $units, 1);
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], ram: [$conf->{vm}{$vm}{details}{ram}]\n");
		}
		
		# TODO: Support pinned cores.
		# Pull out the CPU details
		if ($line =~ /<vcpu>(\d+)<\/vcpu>/)
		{
			$conf->{vm}{$vm}{details}{cpu_count} = $1;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], cpu count: [$conf->{vm}{$vm}{details}{cpu_count}]\n");
		}
		if ($line =~ /<vcpu placement='(.*?)'>(\d+)<\/vcpu>/)
		{
			my $cpu_type                         = $1;
			$conf->{vm}{$vm}{details}{cpu_count} = $2;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], cpu count: [$conf->{vm}{$vm}{details}{cpu_count}], type: [$cpu_type]\n");
		}
		
		# Pull out network details.
		if (($line =~ /<interface/) && ($line =~ /type='bridge'/))
		{
			$in_interface = 1;
			next;
		}
		elsif ($line =~ /<\/interface/)
		{
			# Record the values I found
			$conf->{vm}{$vm}{details}{bridge}{$current_bridge}{device} = $current_device         ? $current_device         : "unknown";
			$conf->{vm}{$vm}{details}{bridge}{$current_bridge}{mac}    = $current_mac_address    ? $current_mac_address    : "unknown";
			$conf->{vm}{$vm}{details}{bridge}{$current_bridge}{type}   = $current_interface_type ? $current_interface_type : "unknown";
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], bride: [$current_bridge], device: [$conf->{vm}{$vm}{details}{bridge}{$current_bridge}{device}], mac: [$conf->{vm}{$vm}{details}{bridge}{$current_bridge}{mac}], type: [$conf->{vm}{$vm}{details}{bridge}{$current_bridge}{type}]\n");
			$current_bridge         = "";
			$current_device         = "";
			$current_mac_address    = "";
			$current_interface_type = "";
			$in_interface           = 0;
			next;
		}
		if ($in_interface)
		{
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], interface line: [$line]\n");
			if ($line =~ /source bridge='(.*?)'/)
			{
				$current_bridge = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], bridge: [$current_bridge]\n");
			}
			if ($line =~ /mac address='(.*?)'/)
			{
				$current_mac_address = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], mac: [$current_mac_address]\n");
			}
			if ($line =~ /target dev='(.*?)'/)
			{
				$current_device = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], device: [$current_device]\n");
			}
			if ($line =~ /model type='(.*?)'/)
			{
				$current_interface_type = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], type: [$current_interface_type]\n");
			}
		}
		
		# Pull out disk info.
		if (($line =~ /<disk/) && ($line =~ /type='block'/) && ($line =~ /device='disk'/))
		{
			$in_disk = 1;
			next;
		}
		elsif ($line =~ /<\/disk/)
		{
			$in_disk = 0;
			next;
		}
		if ($in_disk)
		{
			if ($line =~ /source dev='(.*?)'/)
			{
				my $lv = $1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], checking LV: [$lv]\n");
				check_lv($conf, $node, $vm, $lv);
			}
		}
		
		# Record what graphics we're using for remote connection.
		if ($line =~ /^<graphics /)
		{
			my ($port)   = ($line =~ / port='(\d+)'/);
			my ($type)   = ($line =~ / type='(.*?)'/);
			my ($listen) = ($line =~ / listen='(.*?)'/);
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$say_vm] is using: [$type] and listening on: [$listen] port: [$port].\n");
			$conf->{vm}{$vm}{graphics}{type}     = $type;
			$conf->{vm}{$vm}{graphics}{port}     = $port;
			$conf->{vm}{$vm}{graphics}{'listen'} = $listen;
		}
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm::${vm}::raw_xml: [".@{$conf->{vm}{$vm}{raw_xml}}." lines]\n");
	
	return (0);
}

# This takes a node name and an LV and checks the DRBD resources to see if they
# are Primary and UpToDate.
sub check_lv
{
	my ($conf, $node, $vm, $lv) = @_;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], VM: [$vm], LV: [$lv]\n");
	
	# If this node is down, just return.
	if ($conf->{node}{$node}{daemon}{clvmd}{exit_code} ne "0")
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The node: [$node] is down, skipping LV check for: [$lv] for VM: [$vm]\n");
		return(0);
	}
	
	$conf->{vm}{$vm}{node}{$node}{lv}{$lv}{active} = $conf->{node}{$node}{lvm}{lv}{$lv}{active};
	$conf->{vm}{$vm}{node}{$node}{lv}{$lv}{size}   = AN::Cluster::bytes_to_hr($conf, $conf->{node}{$node}{lvm}{lv}{$lv}{total_size});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], VM: [$vm], LV: [$lv], active: [$conf->{node}{$node}{lvm}{lv}{$lv}{active}], size: [$conf->{vm}{$vm}{node}{$node}{lv}{$lv}{size}], on device(s): [$conf->{node}{$node}{lvm}{lv}{$lv}{on_devices}]\n");
	
	# If there is a comman in the devices, the LV spans multiple devices.
	foreach my $device (split/,/, $conf->{node}{$node}{lvm}{lv}{$lv}{on_devices})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; device: [$device]\n");
		# Find the resource name.
		my $on_res;
		foreach my $res (sort {$a cmp $b} keys %{$conf->{drbd}})
		{
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; res: [$res]\n");
			my $res_device = $conf->{drbd}{$res}{node}{$node}{device};
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; res: [$res], device: [$device], res. device: [$res_device]\n");
			if ($device eq $res_device)
			{
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; match! Recording res as: [$res]\n");
				$on_res = $res;
				last;
			}
		}
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], node: [$node], lv: [$lv], on_res: [$on_res]\n");
		
		$conf->{vm}{$vm}{node}{$node}{lv}{$lv}{drbd}{$on_res}{connection_state} = $conf->{drbd}{$on_res}{node}{$node}{connection_state};
		$conf->{vm}{$vm}{node}{$node}{lv}{$lv}{drbd}{$on_res}{role}             = $conf->{drbd}{$on_res}{node}{$node}{role};
		$conf->{vm}{$vm}{node}{$node}{lv}{$lv}{drbd}{$on_res}{disk_state}       = $conf->{drbd}{$on_res}{node}{$node}{disk_state};
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], node: [$node], lv: [$lv], cs: [$conf->{vm}{$vm}{node}{$node}{lv}{$lv}{drbd}{$on_res}{connection_state}]\n");
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], node: [$node], lv: [$lv], ro: [$conf->{vm}{$vm}{node}{$node}{lv}{$lv}{drbd}{$on_res}{role}]\n");
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], node: [$node], lv: [$lv], ds: [$conf->{vm}{$vm}{node}{$node}{lv}{$lv}{drbd}{$on_res}{disk_state}]\n");
	}
	
	return (0);
}

# Check the status of servers.
sub check_vms
{
	my ($conf) = @_;
	
	# Make it a little easier to print the name of each node
	my $node1 = $conf->{sys}{cluster}{node1_name};
	my $node2 = $conf->{sys}{cluster}{node2_name};
	
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node 1: n[$node1] s[$conf->{node}{$node1}{info}{short_host_name}] l[$conf->{node}{$node1}{info}{host_name}], node 2: n[$node2] s[$conf->{node}{$node2}{info}{short_host_name}] l[$conf->{node}{$node2}{info}{host_name}]\n");
	my $short_node1 = "$conf->{node}{$node1}{info}{short_host_name}";
	my $short_node2 = "$conf->{node}{$node2}{info}{short_host_name}";
	my $long_node1  = "$conf->{node}{$node1}{info}{host_name}";
	my $long_node2  = "$conf->{node}{$node2}{info}{host_name}";
	my $say_node1   = "<span class=\"fixed_width\">$conf->{node}{$node1}{info}{short_host_name}</span>";
	my $say_node2   = "<span class=\"fixed_width\">$conf->{node}{$node2}{info}{short_host_name}</span>";
	foreach my $vm (sort {$a cmp $b} keys %{$conf->{vm}})
	{
		my $say_vm;
		if ($vm =~ /^vm:(.*)/)
		{
			$say_vm = $1;
		}
		else
		{
			AN::Cluster::error($conf, "I was asked to check on a VM that didn't have the <span class=\"code\">vm:</span> prefix. I got the name: <span class=\"code\">$vm</span>. This is likely a programming error.\n");
		}
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], say_vm: [$say_vm]\n");
		
		# This will control the buttons.
		$conf->{vm}{$vm}{can_start}        = 0;
		$conf->{vm}{$vm}{can_stop}         = 0;
		$conf->{vm}{$vm}{can_migrate}      = 0;
		$conf->{vm}{$vm}{current_host}     = 0;
		$conf->{vm}{$vm}{migration_target} = "";
		
		# Find out who, if anyone, is running this VM and who *can* run
		# it. 2 == Running, 1 == Can run, 0 == Can't run.
		$conf->{vm}{$vm}{say_node1}        = $conf->{node}{$node1}{daemon}{cman}{exit_code} eq "0" ? "<span class=\"highlight_warning\">Not Ready</span>" : "<span class=\"code\">--</span>";
		$conf->{vm}{$vm}{node1_ready}      = 0;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm::${vm}::say_node1: [$conf->{vm}{$vm}{say_node1}], node::${node1}::daemon::cman::exit_code: [$conf->{node}{$node1}{daemon}{cman}{exit_code}]\n");
		$conf->{vm}{$vm}{say_node2}        = $conf->{node}{$node2}{daemon}{cman}{exit_code} eq "0" ? "<span class=\"highlight_warning\">Not Ready</span>" : "<span class=\"code\">--</span>";
		$conf->{vm}{$vm}{node2_ready}      = 0;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm::${vm}::say_node2: [$conf->{vm}{$vm}{say_node2}], node::${node2}::daemon::cman::exit_code: [$conf->{node}{$node2}{daemon}{cman}{exit_code}]\n");
		
		# If a VM's XML definition file is found but there is no host,
		# the user probably forgot to define it.
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], host: [$conf->{vm}{$vm}{host}]\n");
		if ((not $conf->{vm}{$vm}{host}) && (not $conf->{sys}{ignore_missing_vm}))
		{
			# Pull the host node and current state out of the hash.
			my $host_node = "";
			my $vm_state  = "";
			foreach my $node (sort {$a cmp $b} keys %{$conf->{vm}{$vm}{node}})
			{
				$host_node = $node;
				foreach my $key (sort {$a cmp $b} keys %{$conf->{vm}{$vm}{node}{$node}{virsh}})
				{
					if ($key eq "state") 
					{
						$vm_state = $conf->{vm}{$vm}{node}{$host_node}{virsh}{'state'};
					}
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], node: [$node], virsh '$key': [$conf->{vm}{$vm}{node}{$node}{virsh}{$key}]\n");
				}
			}
			$conf->{vm}{$vm}{say_node1} = "--";
			$conf->{vm}{$vm}{say_node2} = "--";
			my $say_error = AN::Common::get_string($conf, {key => "message_0271", variables => {
				server	=>	$say_vm,
				url	=>	"?cluster=$conf->{cgi}{cluster}&task=add_vm&name=$say_vm&node=$host_node&state=$vm_state",
			}});
			AN::Cluster::error($conf, "$say_error", 0);
			next;
		}
		
		$conf->{vm}{$vm}{host} = "" if not defined $conf->{vm}{$vm}{host};
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], current host: [$conf->{vm}{$vm}{host}], node1 / node2 short names: [$short_node1] / [$short_node2]\n");
		if ($conf->{vm}{$vm}{host} =~ /$short_node1/)
		{
			# Even though I know the host is ready, this function
			# loads some data, like LV details, which I will need
			# later.
			check_node_readiness($conf, $vm, $node1);
			$conf->{vm}{$vm}{can_start}     = 0;
			$conf->{vm}{$vm}{can_stop}      = 1;
			$conf->{vm}{$vm}{current_host}  = $node1;
			$conf->{vm}{$vm}{node1_ready}   = 2;
			($conf->{vm}{$vm}{node2_ready}) = check_node_readiness($conf, $vm, $node2);
			if ($conf->{vm}{$vm}{node2_ready})
			{
				$conf->{vm}{$vm}{migration_target} = $long_node2;
				$conf->{vm}{$vm}{can_migrate}      = 1;
			}
			# Disable cluster withdrawl of this node.
			$conf->{node}{$node1}{enable_withdraw} = 0;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], node1: [$node1], node2 ready: [$conf->{vm}{$vm}{node2_ready}], can migrate: [$conf->{vm}{$vm}{can_migrate}], migration target: [$conf->{vm}{$vm}{migration_target}]\n");
		}
		elsif ($conf->{vm}{$vm}{host} =~ /$short_node2/)
		{
			# Even though I know the host is ready, this function
			# loads some data, like LV details, which I will need
			# later.
			check_node_readiness($conf, $vm, $node2);
			$conf->{vm}{$vm}{can_start}     = 0;
			$conf->{vm}{$vm}{can_stop}      = 1;
			$conf->{vm}{$vm}{current_host}  = $node2;
			($conf->{vm}{$vm}{node1_ready}) = check_node_readiness($conf, $vm, $node1);
			$conf->{vm}{$vm}{node2_ready}   = 2;
			if ($conf->{vm}{$vm}{node1_ready})
			{
				$conf->{vm}{$vm}{migration_target} = $long_node1;
				$conf->{vm}{$vm}{can_migrate}      = 1;
			}
			# Disable withdrawl of this node.
			$conf->{node}{$node2}{enable_withdraw} = 0;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], node1: [$node1], node2 ready: [$conf->{vm}{$vm}{node2_ready}], can migrate: [$conf->{vm}{$vm}{can_migrate}], migration target: [$conf->{vm}{$vm}{migration_target}]\n");
		}
		else
		{
			$conf->{vm}{$vm}{can_stop}      = 0;
			($conf->{vm}{$vm}{node1_ready}) = check_node_readiness($conf, $vm, $node1);
			($conf->{vm}{$vm}{node2_ready}) = check_node_readiness($conf, $vm, $node2);
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], node1_ready: [$conf->{vm}{$vm}{node1_ready}], node2_ready: [$conf->{vm}{$vm}{node2_ready}]\n");
		}
		
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], current host: [$conf->{vm}{$vm}{current_host}]\n");
		$conf->{vm}{$vm}{boot_target} = "";
		if ($conf->{vm}{$vm}{current_host})
		{
			# This is a bit expensive, but read the VM's running
			# definition.
			my $node   = $conf->{vm}{$vm}{current_host};
			my $say_vm = $vm;
			$say_vm =~ s/^vm://;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Reading the XML for the VM: [$vm] which is currently running on: [$conf->{vm}{$vm}{current_host}]\n");
			my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
				node		=>	$node,
				port		=>	$conf->{node}{$node}{port},
				user		=>	"root",
				password	=>	$conf->{sys}{root_password},
				ssh_fh		=>	"",
				'close'		=>	1,
				shell_call	=>	"/usr/bin/virsh dumpxml $say_vm",
			});
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
			foreach my $line (@{$output})
			{
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				$line =~ s/\s+/ /g;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
				push @{$conf->{vm}{$vm}{xml}}, $line;
			}
		}
		else
		{
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], node1_ready: [$conf->{vm}{$vm}{node1_ready}], node2_ready: [$conf->{vm}{$vm}{node2_ready}]\n");
			if (($conf->{vm}{$vm}{node1_ready}) && ($conf->{vm}{$vm}{node2_ready}))
			{
				# I can boot on either node, so choose the 
				# first one in the VM's failover domain.
				$conf->{vm}{$vm}{boot_target} = find_prefered_host($conf, $vm);
				$conf->{vm}{$vm}{can_start}   = 1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], boot target: [$conf->{vm}{$vm}{boot_target}], vm::${vm}::can_start: [$conf->{vm}{$vm}{can_start}]\n");
			}
			elsif ($conf->{vm}{$vm}{node1_ready})
			{
				$conf->{vm}{$vm}{boot_target} = $node1;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], boot target: [$conf->{vm}{$vm}{boot_target}]\n");
			}
			elsif ($conf->{vm}{$vm}{node2_ready})
			{
				$conf->{vm}{$vm}{boot_target} = $node2;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], boot target: [$conf->{vm}{$vm}{boot_target}]\n");
			}
			else
			{
				$conf->{vm}{$vm}{can_start} = 0;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], can_start: [$conf->{vm}{$vm}{can_start}]\n");
			}
		}
	}
	
	return (0);
}

### NOTE: Yes, I know 'prefered' is spelled wrong...
# This looks through the failover domain for a VM and returns the prefered host.
sub find_prefered_host
{
	my ($conf, $vm) = @_;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in find_prefered_host(), vm: [$vm]\n");
	my $prefered_host = "";
	
	my $failover_domain = $conf->{vm}{$vm}{failover_domain};
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], failover_domain: [$failover_domain]\n");
	if (not $failover_domain)
	{
		# Not yet defined in the cluster.
		return("--");
	}
	
	# TODO: Check to see if I need to use <=> instead of cmp.
	foreach my $priority (sort {$a cmp $b} keys %{$conf->{failoverdomain}{$failover_domain}{priority}})
	{
		# I only care about the first entry, so I will
		# exit the loop as soon as I analyze it.
		$prefered_host = $conf->{failoverdomain}{$failover_domain}{priority}{$priority}{node};
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], prefered host: [$prefered_host]\n");
		last;
	}
	
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], prefered host: [$prefered_host]\n");
	return ($prefered_host);
}

# This function simply sets a couple variables using the node names as set in
# the $conf hash declaration
sub set_node_names
{
	my ($conf) = @_;
	
	# First pull the names into easier to follow variables.
	my $this_cluster = $conf->{cgi}{cluster};
	$conf->{sys}{cluster}{node1_name} = $conf->{clusters}{$this_cluster}{nodes}[0];
	$conf->{sys}{cluster}{node2_name} = $conf->{clusters}{$this_cluster}{nodes}[1];
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; this_cluster: [$this_cluster], node1: [$conf->{sys}{cluster}{node1_name}], node2: [$conf->{sys}{cluster}{node2_name}]\n");
	
	return (0);
}

# This shows the current state of the VMs as well as the available control
# buttons.
sub display_vm_state_and_controls
{
	my ($conf) = @_;
	
	# Make it a little easier to print the name of each node
	my $node1 = $conf->{sys}{cluster}{node1_name};
	my $node2 = $conf->{sys}{cluster}{node2_name};
	my $node1_long = $conf->{node}{$node1}{info}{host_name};
	my $node2_long = $conf->{node}{$node2}{info}{host_name};
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1: [$node1], node1_long: [$node1_long]\n");
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node2: [$node2], node2_long: [$node2_long]\n");
	
	my $vm_state_and_control_panel = AN::Common::template($conf, "server.html", "display-server-state-and-control-header", {
		anvil			=>	$conf->{cgi}{cluster},
		node1_short_host_name	=>	$conf->{node}{$node1}{info}{short_host_name},
		node2_short_host_name	=>	$conf->{node}{$node2}{info}{short_host_name},
	});

	foreach my $vm (sort {$a cmp $b} keys %{$conf->{vm}})
	{
		# Break the name out of the hash key.
		my ($say_vm) = ($vm =~ /^vm:(.*)/);
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], say vm: [$say_vm]\n");
		
		# Use the node's short name for the buttons.
		my $say_start_target     =  $conf->{vm}{$vm}{boot_target} ? $conf->{vm}{$vm}{boot_target} : "--";
		$say_start_target        =~ s/\..*?$//;
		my $start_target_long    = $node1_long =~ /$say_start_target/ ? $conf->{node}{$node1}{info}{host_name} : $conf->{node}{$node2}{info}{host_name};
		my $start_target_name    = $node1      =~ /$say_start_target/ ? $node1 : $node2;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_start_target: [$say_start_target], vm::${vm}::boot_target: [$conf->{vm}{$vm}{boot_target}], start_target_long: [$start_target_long]\n");
		
		my $prefered_host        =  find_prefered_host($conf, $vm);
		$prefered_host           =~ s/\..*$//;
		if ($conf->{vm}{$vm}{boot_target})
		{
			$prefered_host = "<span class=\"highlight_ready\">$prefered_host</span>";
		}
		else
		{
			my $on_host =  $conf->{vm}{$vm}{host};
			   $on_host =~ s/\..*$//;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; on_host: [$on_host], prefered_host: [$prefered_host]\n");
			if (($on_host eq $prefered_host) || ($on_host eq "none"))
			{
				$prefered_host = "<span class=\"highlight_good\">$prefered_host</span>";
			}
			else
			{
				$prefered_host = "<span class=\"highlight_warning\">$prefered_host</span>";
			}
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; prefered_host: [$prefered_host]\n");
		}
		
		my $say_migration_target =  $conf->{vm}{$vm}{migration_target};
		$say_migration_target    =~ s/\..*?$//;
		#my $migrate_button = "<span class=\"disabled_button\">#!string!button_0024!#</span>";
		my $migrate_button = AN::Common::template($conf, "common.html", "disabled-button", {
			button_text	=>	"#!string!button_0024!#",
		}, "", 1);
		if ($conf->{vm}{$vm}{can_migrate})
		{
			my $say_target = AN::Common::get_string($conf, {key => "button_0025", variables => {
				migration_target	=>	$say_migration_target,
			}});
			$migrate_button = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
				button_link	=>	"?cluster=$conf->{cgi}{cluster}&vm=$say_vm&task=migrate_vm&target=$conf->{vm}{$vm}{migration_target}&vm_ram=$conf->{vm}{$vm}{details}{ram}&confirm=true",
				button_text	=>	$say_target,
				id		=>	"migrate_vm_$vm",
			}, "", 1);
		}
		my $host_node        = "$conf->{vm}{$vm}{host}";
		#my $stop_button      = "<span class=\"disabled_button\">#!string!button_0033!#</span>";
		#my $force_off_button = "<span class=\"disabled_button\">#!string!button_0027!#</span>";
		my $stop_button = AN::Common::template($conf, "common.html", "disabled-button", {
			button_text	=>	"#!string!button_0033!#",
		}, "", 1);
		my $force_off_button = AN::Common::template($conf, "common.html", "disabled-button", {
			button_text	=>	"#!string!button_0027!#",
		}, "", 1);
		if ($conf->{vm}{$vm}{can_stop})
		{
			$host_node        = long_host_name_to_node_name($conf, $conf->{vm}{$vm}{host});
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vm: [$vm], host node: [$host_node], vm host: [$conf->{vm}{$vm}{host}]\n");
			my $expire_time = time + $conf->{sys}{actime_timeout};
			$stop_button      = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
				button_link	=>	"?cluster=$conf->{cgi}{cluster}&expire=$expire_time&task=stop_vm&vm=$say_vm&node=$host_node",
				button_text	=>	"#!string!button_0028!#",
				id		=>	"stop_vm_$vm",
			}, "", 1);
			$force_off_button = AN::Common::template($conf, "common.html", "enabled-button", {
				button_class	=>	"highlight_dangerous",
				button_link	=>	"?cluster=$conf->{cgi}{cluster}&expire=$expire_time&task=force_off_vm&vm=$say_vm&node=$host_node&host=$conf->{vm}{$vm}{host}",
				button_text	=>	"#!string!button_0027!#",
				id		=>	"force_off_vm_$say_vm",
			}, "", 1);
		}
		#my $start_button     = "<span class=\"disabled_button\">#!string!button_0029!#</span>";
		my $start_button = AN::Common::template($conf, "common.html", "disabled-button", {
			button_text	=>	"#!string!button_0029!#",
		}, "", 1);

		if ($conf->{vm}{$vm}{boot_target})
		{
			$start_button = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
				button_link	=>	"?cluster=$conf->{cgi}{cluster}&task=start_vm&vm=$say_vm&node=$start_target_name&node_cluster_name=$start_target_long&confirm=true",
				button_text	=>	"#!string!button_0029!#",
				id		=>	"start_vm_$vm",
			}, "", 1);
		}
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; start_button:     [$start_button], vm::${vm}::boot_target: [$conf->{vm}{$vm}{boot_target}]\n");
		
		# I need both nodes up to delete a VM.
		#my $say_delete_button = "<a href=\"?cluster=$conf->{cgi}{cluster}&vm=$say_vm&task=delete_vm\"><span class=\"highlight_dangerous\">Delete</span></a>";
		# I need both nodes up to delete a VM.
		#my $say_delete_button = "<span class=\"disabled_button\">#!string!button_0030!#</span>";
		my $say_delete_button = AN::Common::template($conf, "common.html", "disabled-button", {
			button_text	=>	"#!string!button_0030!#",
		}, "", 1);
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node1}::daemon::cman::exit_code: [$conf->{node}{$node1}{daemon}{cman}{exit_code}], node::${node2}::daemon::cman::exit_code: [$conf->{node}{$node2}{daemon}{cman}{exit_code}], prefered_host: [$prefered_host]\n");
		if (($conf->{node}{$node1}{daemon}{cman}{exit_code} eq "0") && ($conf->{node}{$node2}{daemon}{cman}{exit_code} eq "0") && ($prefered_host !~ /--/))
		{
			$say_delete_button = AN::Common::template($conf, "common.html", "enabled-button", {
				button_class	=>	"highlight_dangerous",
				button_link	=>	"?cluster=$conf->{cgi}{cluster}&vm=$say_vm&task=delete_vm",
				button_text	=>	"#!string!button_0030!#",
				id		=>	"delete_vm_$say_vm",
			}, "", 1);
		}
		
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__." > say_n1: [$conf->{vm}{$vm}{say_node1}], say_n2: [$conf->{vm}{$vm}{say_node2}]\n");
		if ($conf->{vm}{$vm}{node1_ready} == 2)
		{
			$conf->{vm}{$vm}{say_node1} = "<span class=\"highlight_good\">#!string!state_0003!#</span>";
		}
		elsif ($conf->{vm}{$vm}{node1_ready} == 1)
		{
			$conf->{vm}{$vm}{say_node1} = "<span class=\"highlight_ready\">#!string!state_0009!#</span>";
		}
		if ($conf->{vm}{$vm}{node2_ready} == 2)
		{
			$conf->{vm}{$vm}{say_node2} = "<span class=\"highlight_good\">#!string!state_0003!#</span>";
		}
		elsif ($conf->{vm}{$vm}{node2_ready} == 1)
		{
			$conf->{vm}{$vm}{say_node2} = "<span class=\"highlight_ready\">#!string!state_0009!#</span>";
		}
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__." < say_n1: [$conf->{vm}{$vm}{say_node1}], say_n2: [$conf->{vm}{$vm}{say_node2}]\n");
		
		# I don't want to make the VM editable until the cluster is
		# runnong on at least one node.
		my $dual_join   = (($conf->{node}{$node1}{enable_join})    && ($conf->{node}{$node2}{enable_join}))    ? 1 : 0;
		my $say_vm_link = AN::Common::template($conf, "common.html", "enabled-button", {
			button_class	=>	"fixed_width_button",
			button_link	=>	"?cluster=$conf->{cgi}{cluster}&vm=$vm&task=manage_vm",
			button_text	=>	"$say_vm",
			id		=>	"manage_vm_$say_vm",
		}, "", 1);
		if ($dual_join)
		{
			my $say_vm_disabled_button = AN::Common::template($conf, "common.html", "disabled-button", {
				button_text	=>	"$say_vm",
			}, "", 1);
			$say_vm_link   = "$say_vm_disabled_button";
		}
		
		$vm_state_and_control_panel .= AN::Common::template($conf, "server.html", "display-server-details-entry", {
			vm_link			=>	$say_vm_link,
			say_node1		=>	$conf->{vm}{$vm}{say_node1},
			say_node2		=>	$conf->{vm}{$vm}{say_node2},
			prefered_host		=>	$prefered_host,
			start_button		=>	$start_button,
			migrate_button		=>	$migrate_button,
			stop_button		=>	$stop_button,
			force_off_button	=>	$force_off_button,
			delete_button		=>	$say_delete_button,
		});
	}
	
	# When enabling the "Start" button, be sure to start on the highest 
	# priority host in the failover domain, when possible.
	$vm_state_and_control_panel .= AN::Common::template($conf, "server.html", "display-server-state-and-control-footer");
	
	return ($vm_state_and_control_panel);
}

# This shows the status of each DRBD resource in the cluster.
sub display_drbd_details
{
	my ($conf) = @_;
	
	# Make it a little easier to print the name of each node
	my $node1 = $conf->{sys}{cluster}{node1_name};
	my $node2 = $conf->{sys}{cluster}{node2_name};
	my $say_node1 = "<span class=\"fixed_width\">$conf->{node}{$node1}{info}{short_host_name}</span>";
	my $say_node2 = "<span class=\"fixed_width\">$conf->{node}{$node2}{info}{short_host_name}</span>";
	my $drbd_details_panel = AN::Common::template($conf, "server.html", "display-replicated-storage-header", {
		say_node1	=>	$say_node1,
		say_node2	=>	$say_node2,
	});

	foreach my $res (sort {$a cmp $b} keys %{$conf->{drbd}})
	{
		next if not $res;
		# If the DRBD daemon is stopped, I will use the values from the
		# resource files.
		my $say_n1_dev  = "--";
		my $say_n2_dev  = "--";
		my $say_n1_cs   = "--";
		my $say_n2_cs   = "--";
		my $say_n1_ro   = "--";
		my $say_n2_ro   = "--";
		my $say_n1_ds   = "--";
		my $say_n2_ds   = "--";
		
		# Check if node 1 is online.
		if ($conf->{node}{$node1}{up})
		{
			# It is, but is DRBD running?
			if ($conf->{node}{$node1}{daemon}{drbd}{exit_code} eq "0")
			{
				# It is. 
				$say_n1_dev = $conf->{drbd}{$res}{node}{$node1}{device}           if $conf->{drbd}{$res}{node}{$node1}{device};
				$say_n1_cs  = $conf->{drbd}{$res}{node}{$node1}{connection_state} if $conf->{drbd}{$res}{node}{$node1}{connection_state};
				$say_n1_ro  = $conf->{drbd}{$res}{node}{$node1}{role}             if $conf->{drbd}{$res}{node}{$node1}{role};
				$say_n1_ds  = $conf->{drbd}{$res}{node}{$node1}{disk_state}       if $conf->{drbd}{$res}{node}{$node1}{disk_state};
				if (($conf->{drbd}{$res}{node}{$node1}{disk_state} eq "Inconsistent") && ($conf->{drbd}{$res}{node}{$node1}{resync_percent} =~ /^\d/))
				{
					$say_n1_ds .= " <span class=\"subtle_text\" style=\"font-style: normal;\">($conf->{drbd}{$res}{node}{$node1}{resync_percent}%)</span>";
				}
			}
			else
			{
				# It is not, use the {res_file} values.
				$say_n1_dev = $conf->{drbd}{$res}{node}{$node1}{res_file}{device}           if $conf->{drbd}{$res}{node}{$node1}{res_file}{device};
				$say_n1_cs  = $conf->{drbd}{$res}{node}{$node1}{res_file}{connection_state} if $conf->{drbd}{$res}{node}{$node1}{res_file}{connection_state};
				$say_n1_ro  = $conf->{drbd}{$res}{node}{$node1}{res_file}{role}             if $conf->{drbd}{$res}{node}{$node1}{res_file}{role};
				$say_n1_ds  = $conf->{drbd}{$res}{node}{$node1}{res_file}{disk_state}       if $conf->{drbd}{$res}{node}{$node1}{res_file}{disk_state};
			}
		}
		# Check if node 2 is online.
		if ($conf->{node}{$node2}{up})
		{
			# It is, but is DRBD running?
			if ($conf->{node}{$node2}{daemon}{drbd}{exit_code} eq "0")
			{
				# It is. 
				$say_n2_dev = $conf->{drbd}{$res}{node}{$node2}{device}           if $conf->{drbd}{$res}{node}{$node2}{device};
				$say_n2_cs  = $conf->{drbd}{$res}{node}{$node2}{connection_state} if $conf->{drbd}{$res}{node}{$node2}{connection_state};
				$say_n2_ro  = $conf->{drbd}{$res}{node}{$node2}{role}             if $conf->{drbd}{$res}{node}{$node2}{role};
				$say_n2_ds  = $conf->{drbd}{$res}{node}{$node2}{disk_state}       if $conf->{drbd}{$res}{node}{$node2}{disk_state};
				if (($conf->{drbd}{$res}{node}{$node2}{disk_state} eq "Inconsistent") && ($conf->{drbd}{$res}{node}{$node2}{resync_percent} =~ /^\d/))
				{
					$say_n2_ds .= " <span class=\"subtle_text\" style=\"font-style: normal;\">($conf->{drbd}{$res}{node}{$node2}{resync_percent}%)</span>";
				}
			}
			else
			{
				# It is not, use the {res_file} values.
				$say_n2_dev = $conf->{drbd}{$res}{node}{$node2}{res_file}{device}           if $conf->{drbd}{$res}{node}{$node2}{res_file}{device};
				$say_n2_cs  = $conf->{drbd}{$res}{node}{$node2}{res_file}{connection_state} if $conf->{drbd}{$res}{node}{$node2}{res_file}{connection_state};
				$say_n2_ro  = $conf->{drbd}{$res}{node}{$node2}{res_file}{role}             if $conf->{drbd}{$res}{node}{$node2}{res_file}{role};
				$say_n2_ds  = $conf->{drbd}{$res}{node}{$node2}{res_file}{disk_state}       if $conf->{drbd}{$res}{node}{$node2}{res_file}{disk_state};
			}
		}
		
		my $class_n1_cs  = "highlight_unavailable";
		   $class_n1_cs  = "highlight_good"    if $say_n1_cs eq "Connected";
		   $class_n1_cs  = "highlight_good"    if $say_n1_cs eq "SyncSource";
		   $class_n1_cs  = "highlight_ready"   if $say_n1_cs eq "WFConnection";
		   $class_n1_cs  = "highlight_ready"   if $say_n1_cs eq "PausedSyncS";
		   $class_n1_cs  = "highlight_warning" if $say_n1_cs eq "PausedSyncT";
		   $class_n1_cs  = "highlight_warning" if $say_n1_cs eq "SyncTarget";
		my $class_n2_cs  = "highlight_unavailable";
		   $class_n2_cs  = "highlight_good"    if $say_n2_cs eq "Connected";
		   $class_n2_cs  = "highlight_good"    if $say_n2_cs eq "SyncSource";
		   $class_n2_cs  = "highlight_ready"   if $say_n2_cs eq "WFConnection";
		   $class_n2_cs  = "highlight_ready"   if $say_n2_cs eq "PausedSyncS";
		   $class_n2_cs  = "highlight_warning" if $say_n2_cs eq "PausedSyncT";
		   $class_n2_cs  = "highlight_warning" if $say_n2_cs eq "SyncTarget";
		my $class_n1_ro  = "highlight_unavailable";
		   $class_n1_ro  = "highlight_good"    if $say_n1_ro eq "Primary";
		   $class_n1_ro  = "highlight_warning" if $say_n1_ro eq "Secondary";
		my $class_n2_ro  = "highlight_unavailable";
		   $class_n2_ro  = "highlight_good"    if $say_n2_ro eq "Primary";
		   $class_n2_ro  = "highlight_warning" if $say_n2_ro eq "Secondary";
		my $class_n1_ds  = "highlight_unavailable";
		   $class_n1_ds  = "highlight_good"    if $say_n1_ds eq "UpToDate";
		   $class_n1_ds  = "highlight_warning" if $say_n1_ds =~ /Inconsistent/;
		   $class_n1_ds  = "highlight_warning" if $say_n1_ds eq "Outdated";
		   $class_n1_ds  = "highlight_bad"     if $say_n1_ds eq "Diskless";
		my $class_n2_ds  = "highlight_unavailable";
		   $class_n2_ds  = "highlight_good"    if $say_n2_ds eq "UpToDate";
		   $class_n2_ds  = "highlight_warning" if $say_n2_ds =~ /Inconsistent/;
		   $class_n2_ds  = "highlight_warning" if $say_n2_ds eq "Outdated";
		   $class_n2_ds  = "highlight_bad"     if $say_n2_ds eq "Diskless";
		$drbd_details_panel .= AN::Common::template($conf, "server.html", "display-replicated-storage-entry", {
			res		=>	$res,
			say_n1_dev	=>	$say_n1_dev,
			say_n2_dev	=>	$say_n2_dev,
			class_n1_cs	=>	$class_n1_cs,
			say_n1_cs	=>	$say_n1_cs,
			class_n2_cs	=>	$class_n2_cs,
			say_n2_cs	=>	$say_n2_cs,
			class_n1_ro	=>	$class_n1_ro,
			say_n1_ro	=>	$say_n1_ro,
			class_n2_ro	=>	$class_n2_ro,
			say_n2_ro	=>	$say_n2_ro,
			class_n1_ds	=>	$class_n1_ds,
			say_n1_ds	=>	$say_n1_ds,
			class_n2_ds	=>	$class_n2_ds,
			say_n2_ds	=>	$say_n2_ds,
		});
	}
	$drbd_details_panel .= AN::Common::template($conf, "server.html", "display-replicated-storage-footer");
	
	return ($drbd_details_panel);
}

# This shows the details on each node's GFS2 mount(s)
sub display_gfs2_details
{
	my ($conf) = @_;
	
	# Make it a little easier to print the name of each node
	my $node1 = $conf->{sys}{cluster}{node1_name};
	my $node2 = $conf->{sys}{cluster}{node2_name};
	my $say_node1 = "<span class=\"fixed_width\">$conf->{node}{$node1}{info}{short_host_name}</span>";
	my $say_node2 = "<span class=\"fixed_width\">$conf->{node}{$node2}{info}{short_host_name}</span>";
	my $gfs2_details_panel = AN::Common::template($conf, "server.html", "display-cluster-storage-header", {
		say_node1	=>	$say_node1,
		say_node2	=>	$say_node2,
	});

	my $gfs2_hash;
	my $node;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1 - cman exit code: [$conf->{node}{$node1}{daemon}{cman}{exit_code}], gfs2 exit code: [$conf->{node}{$node1}{daemon}{gfs2}{exit_code}]\n");
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node2 - cman exit code: [$conf->{node}{$node2}{daemon}{cman}{exit_code}], gfs2 exit code: [$conf->{node}{$node2}{daemon}{gfs2}{exit_code}]\n");
	if (($conf->{node}{$node1}{daemon}{cman}{exit_code} eq "0") && ($conf->{node}{$node1}{daemon}{gfs2}{exit_code} eq "0") && (ref($conf->{node}{$node1}{gfs}) eq "HASH"))
	{
		$gfs2_hash = $conf->{node}{$node1}{gfs};
		$node      = $node1;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; using node1's gfs2 hash: [$gfs2_hash]\n");
	}
	elsif (($conf->{node}{$node2}{daemon}{cman}{exit_code} eq "0") && ($conf->{node}{$node2}{daemon}{gfs2}{exit_code} eq "0") && (ref($conf->{node}{$node2}{gfs}) eq "HASH"))
	{
		$gfs2_hash = $conf->{node}{$node2}{gfs};
		$node      = $node2;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; using node2's gfs2 hash: [$gfs2_hash]\n");
	}
	else
	{
		# Neither node has the GFS2 partition mounted. Use the data
		# from /etc/fstab. This is what will be stored in either node's
		# hash. So pick a node that's online and use it.
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; up nodes: [$conf->{sys}{up_nodes}]\n");
		if ($conf->{sys}{up_nodes} == 1)
		{
			$node      = @{$conf->{up_nodes}}[0];
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Neither node has the GFS2 partition mounted.\n");
			$gfs2_hash = $conf->{node}{$node}{gfs};
		}
		else
		{
			# Neither node is online at all.
			$gfs2_details_panel .= AN::Common::template($conf, "server.html", "display-cluster-storage-not-online");
		}
	}
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; gfs2_hash: [$gfs2_hash], node1 hash: [".(ref($conf->{node}{$node1}{gfs}))."], node2 hash: [".(ref($conf->{node}{$node2}{gfs}))."]\n");
	if (ref($gfs2_hash) eq "HASH")
	{
		foreach my $mount_point (sort {$a cmp $b} keys %{$gfs2_hash})
		{
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node1}::gfs::${mount_point}::mounted: [$conf->{node}{$node1}{gfs}{$mount_point}{mounted}], node::${node2}::gfs::${mount_point}::mounted: [$conf->{node}{$node2}{gfs}{$mount_point}{mounted}]\n");
			my $say_node1_mounted = $conf->{node}{$node1}{gfs}{$mount_point}{mounted} ? "<span class=\"highlight_good\">#!string!state_0010!#</span>" : "<span class=\"highlight_bad\">#!string!state_0011!#</span>";
			my $say_node2_mounted = $conf->{node}{$node2}{gfs}{$mount_point}{mounted} ? "<span class=\"highlight_good\">#!string!state_0010!#</span>" : "<span class=\"highlight_bad\">#!string!state_0011!#</span>";
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_node1_mounted: [$say_node1_mounted], say_node2_mounted: [$say_node2_mounted]\n");
			my $say_size         = "--";
			my $say_used         = "--";
			my $say_used_percent = "--%";
			my $say_free         = "--";
			
			# This is to avoid the "undefined variable" errors in
			# the log from when a node isn't online.
			$conf->{node}{$node1}{gfs}{$mount_point}{total_size} = "" if not defined $conf->{node}{$node1}{gfs}{$mount_point}{total_size};
			$conf->{node}{$node2}{gfs}{$mount_point}{total_size} = "" if not defined $conf->{node}{$node2}{gfs}{$mount_point}{total_size};
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1 total size: [$conf->{node}{$node1}{gfs}{$mount_point}{total_size}]\n");
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node2 total size: [$conf->{node}{$node2}{gfs}{$mount_point}{total_size}]\n");
			if ($conf->{node}{$node1}{gfs}{$mount_point}{total_size} =~ /^\d/)
			{
				$say_size         = $conf->{node}{$node1}{gfs}{$mount_point}{total_size};
				$say_used         = $conf->{node}{$node1}{gfs}{$mount_point}{used_space};
				$say_used_percent = $conf->{node}{$node1}{gfs}{$mount_point}{percent_used};
				$say_free         = $conf->{node}{$node1}{gfs}{$mount_point}{free_space};
			}
			elsif ($conf->{node}{$node2}{gfs}{$mount_point}{total_size} =~ /^\d/)
			{
				$say_size         = $conf->{node}{$node2}{gfs}{$mount_point}{total_size};
				$say_used         = $conf->{node}{$node2}{gfs}{$mount_point}{used_space};
				$say_used_percent = $conf->{node}{$node2}{gfs}{$mount_point}{percent_used};
				$say_free         = $conf->{node}{$node2}{gfs}{$mount_point}{free_space};
			}
			$gfs2_details_panel .= AN::Common::template($conf, "server.html", "display-cluster-storage-entry", {
				mount_point		=>	$mount_point,
				say_node1_mounted	=>	$say_node1_mounted,
				say_node2_mounted	=>	$say_node2_mounted,
				say_size		=>	$say_size,
				say_used		=>	$say_used,
				say_used_percent	=>	$say_used_percent,
				say_free		=>	$say_free,
			});
		}
	}
	else
	{
		# No gfs2 FSes found
		$gfs2_details_panel .= AN::Common::template($conf, "server.html", "display-cluster-storage-no-entries-found");
	}
	$gfs2_details_panel .= AN::Common::template($conf, "server.html", "display-cluster-storage-footer");

	return ($gfs2_details_panel);
}

# This shows the user the state of the nodes and their daemons.
sub display_node_details
{
	my ($conf) = @_;
	
	my $this_cluster = $conf->{cgi}{cluster};
	my $node1 = $conf->{sys}{cluster}{node1_name};
	my $node2 = $conf->{sys}{cluster}{node2_name};
	my $node1_long = $conf->{node}{$node1}{info}{host_name};
	my $node2_long = $conf->{node}{$node2}{info}{host_name};
	
	my $i = 0;
	my @host_name;
	my @cman;
	my @rgmanager;
	my @drbd;
	my @clvmd;
	my @gfs2;
	my @libvirtd;
	
	foreach my $node (sort {$a cmp $b} @{$conf->{clusters}{$this_cluster}{nodes}})
	{
		# Get the cluster's node name.
		my $say_short_name =  $node;
		$say_short_name    =~ s/\..*//;
		my $node_long_name =  $node1_long =~ /$say_short_name/ ? $conf->{node}{$node1}{info}{host_name} : $conf->{node}{$node2}{info}{host_name};
		
		$host_name[$i] = $conf->{node}{$node}{info}{short_host_name};
		$cman[$i]      = $conf->{node}{$node}{daemon}{cman}{status};
		$rgmanager[$i] = $conf->{node}{$node}{daemon}{rgmanager}{status};
		$drbd[$i]      = $conf->{node}{$node}{daemon}{drbd}{status};
		$clvmd[$i]     = $conf->{node}{$node}{daemon}{clvmd}{status};
		$gfs2[$i]      = $conf->{node}{$node}{daemon}{gfs2}{status};
		$libvirtd[$i]  = $conf->{node}{$node}{daemon}{libvirtd}{status};
		$i++;
	}
	
	my $node_details_panel =AN::Common::template($conf, "server.html", "display-node-details-full", {
		node1_host_name	=>	$host_name[0],
		node2_host_name	=>	$host_name[1],
		node1_cman	=>	$cman[0],
		node2_cman	=>	$cman[1],
		node1_rgmanager	=>	$rgmanager[0],
		node2_rgmanager	=>	$rgmanager[1],
		node1_drbd	=>	$drbd[0],
		node2_drbd	=>	$drbd[1],
		node1_clvmd	=>	$clvmd[0],
		node2_clvmd	=>	$clvmd[1],
		node1_gfs2	=>	$gfs2[0],
		node2_gfs2	=>	$gfs2[1],
		node1_libvirtd	=>	$libvirtd[0],
		node2_libvirtd	=>	$libvirtd[1],
	});

	return ($node_details_panel);
}

# This shows the controls for the nodes.
sub display_node_controls
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; display_node_controls()\n");

	# Variables for the full template.
	my $i                = 0;
	my $say_boot_or_stop = "";
	my $say_hard_reset   = "";
	my $say_dual_join    = "";
	my @say_node_name;
	my @say_boot;
	my @say_shutdown;
	my @say_join;
	my @say_withdraw;
	my @say_fence;
	
	# I want to map storage service to nodes for the "Withdraw" buttons.
	my $expire_time = time + $conf->{sys}{actime_timeout};
	my $disable_join = 0;
	my $this_cluster = $conf->{cgi}{cluster};
	my $node1 = $conf->{sys}{cluster}{node1_name};
	my $node2 = $conf->{sys}{cluster}{node2_name};
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1: [$node1], node2: [$node2]\n");
	my $node1_long = $conf->{node}{$node1}{info}{host_name};
	my $node2_long = $conf->{node}{$node2}{info}{host_name};
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_long: [$node1_long], node2_long: [$node2_long]\n");
	my $rowspan    = 2;
	my $dual_boot  = (($conf->{node}{$node1}{enable_poweron}) && ($conf->{node}{$node2}{enable_poweron})) ? 1 : 0;
	my $dual_join  = (($conf->{node}{$node1}{enable_join})    && ($conf->{node}{$node2}{enable_join}))    ? 1 : 0;
	my $cold_stop  = ($conf->{sys}{up_nodes} > 0)                                                         ? 1 : 0;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sys::up_nodes: [$conf->{sys}{up_nodes}], dual_boot: [$dual_boot], dual_join: [$dual_join], cold_stop: [$cold_stop]\n");
	foreach my $node (sort {$a cmp $b} @{$conf->{clusters}{$this_cluster}{nodes}})
	{
		# Get the cluster's node name.
		my $say_short_name =  $node;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_short_name: [$say_short_name]\n");
		$say_short_name    =~ s/\..*//;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_short_name: [$say_short_name], node::${node1}::info::host_name: [$conf->{node}{$node1}{info}{host_name}], node::${node2}::info::host_name: [$conf->{node}{$node2}{info}{host_name}]\n");
		my $node_long_name = "";
		if ($node1_long =~ /$say_short_name/)
		{
			$node_long_name = $conf->{node}{$node1}{info}{host_name};
		}
		elsif ($node2_long =~ /$say_short_name/)
		{
			$node_long_name = $conf->{node}{$node2}{info}{host_name};
		}
		else
		{
			# The name in the config doesn't match the name in the
			# cluster.
			$node_long_name = "??";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The node name set in striker.conf does not match either node name on the nodes (/etc/cluster/cluster.conf and/or /etc/hosts).\n");
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node_long_name: [$node_long_name]\n");
		$conf->{node}{$node}{enable_withdraw} = 0 if not defined $conf->{node}{$node}{enable_withdraw};
		
		# Join button.
		my $say_join_disabled_button = AN::Common::template($conf, "common.html", "disabled-button", {
			button_text	=>	"#!string!button_0031!#",
		}, "", 1);
		### TODO: See if the peer is online already and, if so, add
		###      'confirm=true' as the join is safe.
		my $say_join_enabled_button = AN::Common::template($conf, "common.html", "enabled-button", {
			button_class	=>	"bold_button",
			button_link	=>	"?cluster=$conf->{cgi}{cluster}&task=join_cluster&node=$node&node_cluster_name=$node_long_name",
			button_text	=>	"#!string!button_0031!#",
			id		=>	"join_cluster_$node",
		}, "", 1);
		$say_join[$i] = $conf->{node}{$node}{enable_join} ? $say_join_enabled_button : $say_join_disabled_button;
		$say_join[$i] = $say_join_disabled_button if $disable_join;
		   
		# Withdraw button
		my $say_withdraw_disabled_button = AN::Common::template($conf, "common.html", "disabled-button", {
			button_text	=>	"#!string!button_0032!#",
		}, "", 1);
		my $say_withdraw_enabled_button = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
			button_link	=>	"?cluster=$conf->{cgi}{cluster}&task=withdraw&node=$node&node_cluster_name=$node_long_name",
			button_text	=>	"#!string!button_0032!#",
			id		=>	"withdraw_$node",
		}, "", 1);
		$say_withdraw[$i] = $conf->{node}{$node}{enable_withdraw} ? $say_withdraw_enabled_button : $say_withdraw_disabled_button;
		
		# Shutdown button
		my $say_shutdown_disabled_button = AN::Common::template($conf, "common.html", "disabled-button", {
			button_text	=>	"#!string!button_0033!#",
		}, "", 1);
		my $say_shutdown_enabled_button = AN::Common::template($conf, "common.html", "enabled-button-no-class", {
			button_link	=>	"?cluster=$conf->{cgi}{cluster}&expire=$expire_time&task=poweroff_node&node=$node&node_cluster_name=$node_long_name",
			button_text	=>	"#!string!button_0033!#",
			id		=>	"poweroff_node_$node",
		}, "", 1);
		$say_shutdown[$i] = $conf->{node}{$node}{enable_poweroff} ? $say_shutdown_enabled_button : $say_shutdown_disabled_button;
		
		# Boot button
		my $say_boot_disabled_button = AN::Common::template($conf, "common.html", "disabled-button", {
			button_text	=>	"#!string!button_0034!#",
		}, "", 1);
		my $say_boot_enabled_button = AN::Common::template($conf, "common.html", "enabled-button", {
			button_class	=>	"bold_button",
			button_link	=>	"?cluster=$conf->{cgi}{cluster}&task=poweron_node&node=$node&node_cluster_name=$node_long_name&confirm=true",
			button_text	=>	"#!string!button_0034!#",
			id		=>	"poweron_node_$node",
		}, "", 1);
		$say_boot[$i] = $conf->{node}{$node}{enable_poweron} ? $say_boot_enabled_button : $say_boot_disabled_button;
		
		# Fence button
		# If the node is already confirmed off, no need to fence.
		my $say_fence_node_disabled_button = AN::Common::template($conf, "common.html", "disabled-button", {
			button_text	=>	"#!string!button_0037!#",
		}, "", 1);
	my $expire_time = time + $conf->{sys}{actime_timeout};
	# &expire=$expire_time
		my $say_fence_node_enabled_button = AN::Common::template($conf, "common.html", "enabled-button", {
			button_class	=>	"highlight_dangerous",
			button_link	=>	"?cluster=$conf->{cgi}{cluster}&expire=$expire_time&task=fence_node&node=$node&node_cluster_name=$node_long_name",
			button_text	=>	"#!string!button_0037!#",
			id		=>	"fence_node_$node",
		}, "", 1);
		$say_fence[$i] = $conf->{node}{$node}{enable_poweron} ? $say_fence_node_disabled_button : $say_fence_node_enabled_button;
		
		# Dual-boot/Cold-Stop button.
		if ($i == 0)
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; i: [$i]\n");
			my $say_boot_or_stop_disabled_button = AN::Common::template($conf, "common.html", "disabled-button", {
				button_text	=>	"#!string!button_0035!#",
			}, "", 1);
			$say_boot_or_stop_disabled_button =~ s/\n$//;
			$say_boot_or_stop                 =  $say_boot_or_stop_disabled_button;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_boot_or_stop: [$say_boot_or_stop].\n");
			
			# If either node is up, offer the 'Cold-Stop Anvil!'
			# button.
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cold_stop: [$cold_stop]\n");
			if ($cold_stop)
			{
				my $expire_time = time + $conf->{sys}{actime_timeout};
				$say_boot_or_stop = AN::Common::template($conf, "common.html", "enabled-button", {
					button_class	=>	"bold_button",
					button_link	=>	"?cluster=$conf->{cgi}{cluster}&expire=$expire_time&task=cold_stop",
					button_text	=>	"#!string!button_0062!#",
					id		=>	"dual_boot",
				}, "", 1);
				$say_boot_or_stop =~ s/\n$//;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_boot_or_stop: [$say_boot_or_stop].\n");
			}
			
			# Dual-Join button
			my $say_dual_join_disabled_button = AN::Common::template($conf, "common.html", "disabled-button", {
				button_text	=>	"#!string!button_0036!#",
			}, "", 1);
			$say_dual_join_disabled_button =~ s/\n$//;
			$say_dual_join                 =  $say_dual_join_disabled_button;
			if ($rowspan)
			{
				# First row.
				if ($dual_boot)
				{
					$say_boot_or_stop = AN::Common::template($conf, "common.html", "enabled-button", {
						button_class	=>	"bold_button",
						button_link	=>	"?cluster=$conf->{cgi}{cluster}&task=dual_boot&confirm=true",
						button_text	=>	"#!string!button_0035!#",
						id		=>	"dual_boot",
					}, "", 1);
					$say_boot_or_stop =~ s/\n$//;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_boot_or_stop: [$say_boot_or_stop].\n");
				}
				if ($dual_join)
				{
					$say_dual_join = AN::Common::template($conf, "common.html", "enabled-button", {
						button_class	=>	"bold_button",
						button_link	=>	"?cluster=$conf->{cgi}{cluster}&task=dual_join&confirm=true",
						button_text	=>	"#!string!button_0036!#",
						id		=>	"dual_join",
					}, "", 1);
					# Disable the per-node "join" options".
					$say_join[$i] = $say_join_disabled_button;
					$disable_join = 1;
				}
			}
		}
		
		# Make the node names click-able to show the hardware states.
		$say_node_name[$i] = "$conf->{node}{$node}{info}{host_name}";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; i: [$i], node::${node}::info::host_name: [$conf->{node}{$node}{info}{host_name}], say_node_name: [$say_node_name[$i]].\n");
		if ($conf->{node}{$node}{connected})
		{
			$say_node_name[$i] = AN::Common::template($conf, "common.html", "enabled-button-new-tab", {
				button_class	=>	"fixed_width_button",
				button_link	=>	"?cluster=$conf->{cgi}{cluster}&task=display_health&node=$node&node_cluster_name=$node_long_name",
				button_text	=>	"$conf->{node}{$node}{info}{host_name}",
				id		=>	"display_health_$node",
			}, "", 1);
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; i: [$i], say_node_name: [$say_node_name[$i]].\n");
		}
		else
		{
			$say_node_name[$i] = AN::Common::template($conf, "common.html", "disabled-button-with-class", {
				button_class	=>	"highlight_offline_fixed_width",
				button_text	=>	"$conf->{node}{$node}{info}{host_name}",
			}, "", 1);
		}
		$rowspan = 0;
		$i++;
	}
	
	my $boot_or_stop = "";
	my $hard_reset   = "";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_boot_or_stop: [$say_boot_or_stop].\n");
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_hard_reset: [$say_hard_reset] (length: [".length($say_hard_reset)."]).\n");
	if ($say_hard_reset)
	{
		$boot_or_stop = AN::Common::template($conf, "server.html", "boot-or-stop-two-buttons", {
			button	=>	$say_boot_or_stop,
		}, "", 1);
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; boot_or_stop: [$boot_or_stop].\n");
		$hard_reset = AN::Common::template($conf, "server.html", "boot-or-stop-two-buttons", {
			button	=>	$say_hard_reset,
		}, "", 1);
	}
	else
	{
		$boot_or_stop = AN::Common::template($conf, "server.html", "boot-or-stop-one-button", {
			button	=>	$say_boot_or_stop,
		}, "", 1);
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; boot_or_stop: [$boot_or_stop].\n");
	}
	my $node_control_panel = AN::Common::template($conf, "server.html", "display-node-controls-full", {
		say_node1_name		=>	$say_node_name[0],
		say_node2_name		=>	$say_node_name[1],
		boot_or_stop_button_1	=>	$boot_or_stop,
		boot_or_stop_button_2	=>	$hard_reset,
		dual_join_button	=>	$say_dual_join,
		say_node1_boot		=>	$say_boot[0],
		say_node2_boot		=>	$say_boot[1],
		say_node1_shutdown	=>	$say_shutdown[0],
		say_node2_shutdown	=>	$say_shutdown[1],
		say_node1_join		=>	$say_join[0],
		say_node2_join		=>	$say_join[1],
		say_node1_withdraw	=>	$say_withdraw[0],
		say_node2_withdraw	=>	$say_withdraw[1],
		say_node1_fence		=>	$say_fence[0],
		say_node2_fence		=>	$say_fence[1],
	});
	
	return ($node_control_panel);
}

1;
