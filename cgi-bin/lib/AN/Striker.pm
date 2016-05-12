package AN::Striker;

# Striker - Alteeve's Niche! Anvil Dashboard
# 
# This software is released under the GNU GPL v2+ license.
# 
# No warranty is provided. Do not use this software unless you are willing and able to take full liability 
# for it's use. The authors take care to prevent unexpected side effects when using this program. However, no
# software is perfect and bugs may exist which could lead to hangs or crashes in the program, in your Anvil!
# and possibly even data loss.
# 
# If you are concerned about these risks, please stick to command line tools.
# 
# This program is designed to extend Anvils built according to this tutorial:
# - https://alteeve.com/w/2-Node_Red_Hat_KVM_Cluster_Tutorial
#
# This program's source code and updates are available on Github:
# - https://github.com/ClusterLabs/striker
#
# Author;
# Alteeve's Niche!  -  https://alteeve.ca
# Madison Kelly     -  mkelly@alteeve.ca
# 
# TODO:
# - Do not allow a node to withdraw if it is UpToDate and the peer is not!
# - When cold-stopping, check if one node is UpToDate and the other not. In such a case, stop the 
#   Inconsistent one FIRST.
# 
# - When recovering disks; If 'Make Good' is an option, suppress other options. Next, if 'clear foreign 
#   state' is an option, hide others. Ideally, make a "Recover" that does both make good and clear foreign in
#   one step.
# 
# 
# NOTE: The '$an' file handle has been added to all functions to enable the transition to using AN::Tools.
# 

use strict;
use warnings;
use IO::Handle;
use CGI;
use Encode;
#use CGI::Carp "fatalsToBrowser";

use AN::Cluster;
use AN::Common;

# Setup for UTF-8 mode.
binmode STDOUT, ":utf8:";
$ENV{'PERL_UNICODE'} = 1;
my $THIS_FILE = "AN::Striker.pm";


# This sorts out what needs to happen if 'task' was set.
sub process_task
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "process_task" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::task",    value1 => $an->data->{cgi}{task}, 
		name2 => "cgi::confirm", value2 => $an->data->{cgi}{confirm}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{cgi}{task} eq "withdraw")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			withdraw_node($an);
		}
		else
		{
			confirm_withdraw_node($an);
		}
	}
	elsif ($an->data->{cgi}{task} eq "join_cluster")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			join_cluster($an);
		}
		else
		{
			confirm_join_cluster($an);
		}
	}
	elsif ($an->data->{cgi}{task} eq "dual_join")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			dual_join($an);
		}
		else
		{
			confirm_dual_join($an);
		}
	}
	elsif ($an->data->{cgi}{task} eq "fence_node")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			fence_node($an);
		}
		else
		{
			confirm_fence_node($an);
		}
	}
	elsif ($an->data->{cgi}{task} eq "poweroff_node")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			poweroff_node($an);
		}
		else
		{
			confirm_poweroff_node($an);
		}
	}
	elsif ($an->data->{cgi}{task} eq "poweron_node")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			poweron_node($an);
		}
		else
		{
			confirm_poweron_node($an);
		}
	}
	elsif ($an->data->{cgi}{task} eq "dual_boot")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			dual_boot($an);
		}
		else
		{
			confirm_dual_boot($an);
		}
	}
	elsif ($an->data->{cgi}{task} eq "cold_stop")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			# The '1' cancels the APC UPS watchdog timer, if used.
			cold_stop_anvil($an, 1);
		}
		else
		{
			confirm_cold_stop_anvil($an);
		}
	}
	elsif ($an->data->{cgi}{task} eq "start_vm")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			start_vm($an);
		}
		else
		{
			confirm_start_vm($an);
		}
	}
	elsif ($an->data->{cgi}{task} eq "stop_vm")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			stop_vm($an);
		}
		else
		{
			confirm_stop_vm($an);
		}
	}
	elsif ($an->data->{cgi}{task} eq "force_off_vm")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			force_off_vm($an);
		}
		else
		{
			confirm_force_off_vm($an);
		}
	}
	elsif ($an->data->{cgi}{task} eq "delete_vm")
	{
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			delete_vm($an);
		}
		else
		{
			confirm_delete_vm($an);
		}
	}
	elsif ($an->data->{cgi}{task} eq "migrate_vm")
	{
		if ($an->data->{cgi}{confirm})
		{
			migrate_vm($an);
		}
		else
		{
			confirm_migrate_vm($an);
		}
	}
	elsif ($an->data->{cgi}{task} eq "provision")
	{
		### TODO: If '$an->data->{cgi}{os_variant}' is "generic", warn the
		###       user and ask them to confirm that they really want to
		###       do this.
		# Confirmed yet?
		if ($an->data->{cgi}{confirm})
		{
			if (verify_vm_config($an))
			{
				# We're golden
				$an->Log->entry({log_level => 2, message_key => "log_0216", file => $THIS_FILE, line => __LINE__});
				provision_vm($an);
			}
			else
			{
				# Something wasn't sane.
				$an->Log->entry({log_level => 2, message_key => "log_0217", file => $THIS_FILE, line => __LINE__});
				confirm_provision_vm($an);
			}
		}
		else
		{
			confirm_provision_vm($an);
		}
	}
	elsif ($an->data->{cgi}{task} eq "add_vm")
	{
		# This is called after provisioning a VM usually, so no need to
		# confirm
		add_vm_to_cluster($an, 0);
	}
	elsif ($an->data->{cgi}{task} eq "manage_vm")
	{
		manage_vm($an);
	}
	elsif ($an->data->{cgi}{task} eq "display_health")
	{
		print $an->Web->template({file => "common.html", template => "scanning-message", replace => {
			anvil_message	=>	$an->String->get({key => "message_0272", variables => { anvil => $an->data->{cgi}{cluster} }}),
		}});
		get_storage_data($an, $an->data->{cgi}{node});
		
		if ((not $an->data->{storage}{is}{lsi}) && 
		    (not $an->data->{storage}{is}{hp})  &&
		    (not $an->data->{storage}{is}{mdadm}))
		{
			# No managers found
			my $say_title = $an->String->get({key => "title_0016", variables => { node => $an->data->{cgi}{node} }});
			my $say_message = $an->String->get({key => "message_0051", variables => { node_cluster_name => $an->data->{cgi}{node_cluster_name} }});
			print $an->Web->template({file => "lsi-storage.html", template => "no-managers-found", replace => { 
				title	=>	$say_title,
				message	=>	$say_message,
			}});
		}
		else
		{
			my $display_details = 1;
			if ($an->data->{cgi}{'do'})
			{
				if ($an->data->{cgi}{'do'} eq "start_id_disk")
				{
					lsi_control_disk_id_led($an, "start");
					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "stop_id_disk")
				{
					lsi_control_disk_id_led($an, "stop");
					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "make_disk_good")
				{
					lsi_control_make_disk_good($an);
					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "add_disk_to_array")
				{
					lsi_control_add_disk_to_array($an);
					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "put_disk_online")
				{
					lsi_control_put_disk_online($an);
					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "put_disk_offline")
				{
					lsi_control_put_disk_offline($an);
					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "mark_disk_missing")
				{
					lsi_control_mark_disk_missing($an);
					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "spin_disk_down")
				{
					lsi_control_spin_disk_down($an);
					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "spin_disk_up")
				{
					lsi_control_spin_disk_up($an);
					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "make_disk_hot_spare")
				{
					lsi_control_make_disk_hot_spare($an);
					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "unmake_disk_as_hot_spare")
				{
					lsi_control_unmake_disk_as_hot_spare($an);
					get_storage_data($an, $an->data->{cgi}{node});
				}
				elsif ($an->data->{cgi}{'do'} eq "clear_foreign_state")
				{
					lsi_control_clear_foreign_state($an);
					get_storage_data($an, $an->data->{cgi}{node});
				}
				### Prepare Unconfigured drives for removal
				# MegaCli64 AdpSetProp AlarmDsbl aN|a0,1,2|aALL 
			}
			if ($display_details)
			{
				display_node_health($an);
			}
		}
	}
	else
	{
		print "<pre>\n";
		foreach my $var (sort {$a cmp $b} keys %{$an->data->{cgi}})
		{
			print "var: [$var] -> [$an->data->{cgi}{$var}]\n" if $an->data->{cgi}{$var};
		}
		print "</pre>";
	}
	
	return(0);
}

# This unmarks a disk as a hot spare.
sub lsi_control_unmake_disk_as_hot_spare
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "lsi_control_unmake_disk_as_hot_spare" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $an->data->{cgi}{cluster};
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	
	# Mark the disk as a global hot-spare.
	my $shell_call = $an->data->{storage}{is}{lsi}." PDHSP Rmv PhysDrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$return_string .= "$line<br />\n";
		if ($line =~ /as Hot Spare Success/i)
		{
			$success = 1;
		}
	}
	
	# Show the user the results.
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = $an->String->get({key => "lsi_0002", variables => { 
			disk	=>	$an->data->{cgi}{disk_address},
			adapter	=>	$an->data->{cgi}{adapter},
		}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = $an->String->get({key => "lsi_0003", variables => { 
				disk	=>	$an->data->{cgi}{disk_address},
				adapter	=>	$an->data->{cgi}{adapter},
				message	=>	$return_string,
			}});
	}
	print $an->Web->template({file => "lsi-storage.html", template => "lsi-complete-table-message", replace => { 
			title		=>	"#!string!lsi_0001!#",
			row		=>	$title_message,
			row_class	=>	$title_class,
			message		=>	$message_body,
		}});

	return(0);
}

# Thus clears a disk's foreign state
sub lsi_control_clear_foreign_state
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "lsi_control_clear_foreign_state" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $an->data->{cgi}{cluster};
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	
	# Mark the disk as a global hot-spare.
	my $shell_call = $an->data->{storage}{is}{lsi}." CfgForeign Clear -a".$an->data->{cgi}{adapter};
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$return_string .= "$line<br />\n";
		if ($line =~ /is cleared/i)
		{
			$success = 1;
		}
	}
	
	# Show the user the results.
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = $an->String->get({key => "lsi_0043", variables => { adapter => $an->data->{cgi}{adapter} }});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = $an->String->get({key => "lsi_0044", variables => { 
				adapter	=>	$an->data->{cgi}{adapter},
				message	=>	$return_string,
			}});
	}
	print $an->Web->template({file => "lsi-storage.html", template => "lsi-complete-table-message", replace => { 
		title		=>	"#!string!lsi_0045!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	}});

	return(0);
}

# This marks a disk as a hot spare.
sub lsi_control_make_disk_hot_spare
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "lsi_control_make_disk_hot_spare" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $an->data->{cgi}{cluster};
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	
	# Mark the disk as a global hot-spare.
	my $shell_call = $an->data->{storage}{is}{lsi}." PDHSP Set PhysDrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$return_string .= "$line<br />\n";
		if ($line =~ /as Hot Spare Success/i)
		{
			$success = 1;
		}
	}
	
	# Show the user the results.
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = $an->String->get({key => "lsi_0005", variables => { 
			disk	=>	$an->data->{cgi}{disk_address},
			adapter	=>	$an->data->{cgi}{adapter},
		}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = $an->String->get({key => "lsi_0006", variables => { 
				disk	=>	$an->data->{cgi}{disk_address},
				adapter	=>	$an->data->{cgi}{adapter},
				message	=>	$return_string,
			}});
	}
	print $an->Web->template({file => "lsi-storage.html", template => "lsi-complete-table-message", replace => { 
		title		=>	"#!string!lsi_0004!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	}});

	return(0);
}

# This marks an "Offline" disk as "Missing".
sub lsi_control_mark_disk_missing
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "lsi_control_mark_disk_missing" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $an->data->{cgi}{cluster};
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	
	my $shell_call = $an->data->{storage}{is}{lsi}." PDMarkMissing PhysDrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$return_string .= "$line<br />\n";
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
	my $message_body  = $an->String->get({key => "lsi_0007", variables => { 
			disk	=>	$an->data->{cgi}{disk_address},
			adapter	=>	$an->data->{cgi}{adapter},
		}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = $an->String->get({key => "", variables => { 
				disk	=>	$an->data->{cgi}{disk_address},
				adapter	=>	$an->data->{cgi}{adapter},
				message	=>	$return_string,
			}});
	}
	elsif ($success == 2)
	{
		$title_message = "#!string!row_0032!#";
		$title_class   = "highlight_detail";
		$message_body  = $an->String->get({key => "lsi_0009", variables => { 
				disk	=>	$an->data->{cgi}{disk_address},
				adapter	=>	$an->data->{cgi}{adapter},
			}});
	}
	print $an->Web->template({file => "lsi-storage.html", template => "lsi-complete-table-message", replace => { 
		title		=>	"#!string!lsi_0013!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	}});
	
	if ($success)
	{
		lsi_control_spin_disk_down($an);
	}

	return(0);
}

# This spins up an "Unconfigured, spun down" disk, making it available again.
sub lsi_control_spin_disk_up
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "lsi_control_spin_disk_up" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $an->data->{cgi}{cluster};
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	
	# This spins the drive back up.
	my $shell_call = $an->data->{storage}{is}{lsi}." PDPrpRmv Undo PhysDrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$return_string .= "$line<br />\n";
		if ($line =~ /Undo Prepare for removal Success/i)
		{
			$success = 1;
		}
	}

	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = $an->String->get({key => "lsi_0010", variables => { 
			disk	=>	$an->data->{cgi}{disk_address},
			adapter	=>	$an->data->{cgi}{adapter},
		}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = $an->String->get({key => "lsi_0011", variables => { 
				disk	=>	$an->data->{cgi}{disk_address},
				adapter	=>	$an->data->{cgi}{adapter},
				message	=>	$return_string,
			}});
	}
	print $an->Web->template({file => "lsi-storage.html", template => "lsi-complete-table-message", replace => { 
		title		=>	"#!string!lsi_0012!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	}});

	return(0);
}

# This spins down an "Offline" disk, Preparing it for removal.
sub lsi_control_spin_disk_down
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "lsi_control_spin_disk_down" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $an->data->{cgi}{cluster};
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	
	my $shell_call = $an->data->{storage}{is}{lsi}." PDPrpRmv PhysDrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$return_string .= "$line<br />\n";
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
	my $message_body  = $an->String->get({key => "lsi_0015", variables => { 
			disk	=>	$an->data->{cgi}{disk_address},
			adapter	=>	$an->data->{cgi}{adapter},
		}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = $an->String->get({key => "lsi_0016", variables => { 
				disk	=>	$an->data->{cgi}{disk_address},
				adapter	=>	$an->data->{cgi}{adapter},
				message	=>	$return_string,
			}});
	}
	elsif ($success == 2)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = $an->String->get({key => "lsi_0017", variables => { 
				disk	=>	$an->data->{cgi}{disk_address},
				adapter	=>	$an->data->{cgi}{adapter},
			}});
	}
	print $an->Web->template({file => "lsi-storage.html", template => "lsi-complete-table-message", replace => { 
		title		=>	"#!string!lsi_0014!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	}});
	
	# If this failed because the firmware rejected the request, try to mark
	# the disk as good and then spin it down.
	if ($success == 2)
	{
		if (lsi_control_make_disk_good($an))
		{
			lsi_control_spin_disk_down($an);
		}
	}
	
	return(0);
}

# This gets the rebuild status of a drive
sub lsi_control_get_rebuild_progress
{
	my ($an, $disk_address, $adapter) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "lsi_control_get_rebuild_progress" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "disk_address", value1 => $disk_address, 
		name2 => "adapter",      value2 => $adapter, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $rebuild_percent   = "";
	my $time_to_complete  = "";
	my $cluster           = $an->data->{cgi}{cluster};
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	
	my $shell_call = $an->data->{storage}{is}{lsi}." PDRbld ShowProg PhysDrv [$disk_address] a$adapter";
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
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
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "lsi_control_put_disk_offline" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### NOTE: I don't think I need this function. For now, I simply
	###       redirect to the "prepare for removal" function.
	#lsi_control_mark_disk_missing($an);
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $an->data->{cgi}{cluster};
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	my $this_adapter      = $an->data->{cgi}{adapter};
	my $this_logical_disk = $an->data->{cgi}{logical_disk};
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "this_adapter",                                                                      value1 => $this_adapter,
		name2 => "this_logical_disk",                                                                 value2 => $this_logical_disk,
		name3 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::state", value3 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'} =~ /Degraded/i) && ($this_logical_disk != 9999))
	{
		my $reason = $an->String->get({key => "lsi_0019"});
		if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{primary_raid_level} eq "6")
		{
			$reason = $an->String->get({key => "lsi_0020"});
		}
		my $message = $an->String->get({key => "lsi_0021", variables => { 
				disk		=>	$an->data->{cgi}{disk_address},
				logical_disk	=>	$this_logical_disk,
				reason		=>	$reason,
			}});
		print $an->Web->template({file => "lsi-storage.html", template => "lsi-complete-table-message", replace => { 
			title		=>	"#!string!lsi_0018!#",
			row		=>	"#!string!row_0045!#",
			row_class	=>	"highlight_warning",
			message		=>	$message,
		}});
		return(0);
	}
	
	if (not $an->data->{cgi}{confirm})
	{
		my $message = $an->String->get({key => "lsi_0022", variables => { 
				disk		=>	$an->data->{cgi}{disk_address},
				logical_disk	=>	$this_logical_disk,
			}});
		my $alert       =  "#!string!row_0044!#";
		my $alert_class =  "highlight_warning_bold";
		if ($this_logical_disk == 9999)
		{
			$message     = $an->String->get({key => "lsi_0023"});
			$alert       = "#!string!row_0032!#";
			$alert_class = "highlight_detail_bold";
		}
		# Both messages have the same second part that asks the user to confirm.
		$message .= $an->String->get({key => "lsi_0024", variables => { 
				confirm_url	=>	"?cluster=".$an->data->{cgi}{cluster}."&node=".$an->data->{cgi}{node}."&node_cluster_name=".$an->data->{cgi}{node_cluster_name}."&task=display_health&do=put_disk_offline&disk_address=".$an->data->{cgi}{disk_address}."&adapter=$this_adapter&logical_disk=$this_logical_disk&confirm=true",
				cancel_url	=>	"?cluster=".$an->data->{cgi}{cluster}."&node=".$an->data->{cgi}{node}."&node_cluster_name=".$an->data->{cgi}{node_cluster_name}."&task=display_health",
			}});
		print $an->Web->template({file => "lsi-storage.html", template => "lsi-complete-table-message", replace => { 
			title		=>	"#!string!title_0018!#",
			row		=>	$alert,
			row_class	=>	$alert_class,
			message		=>	$message,
		}});
		return (0);
	}
	
	my $shell_call = $an->data->{storage}{is}{lsi}." PDOffline PhysDrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$return_string .= "$line<br />\n";
		if ($line =~ /state changed to offline/i)
		{
			$success = 1;
		}
	}
	
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = $an->String->get({key => "lsi_0025", variables => { 
			disk	=>	$an->data->{cgi}{disk_address},
			adapter	=>	$an->data->{cgi}{adapter},
		}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = $an->String->get({key => "lsi_0027", variables => { 
				disk	=>	$an->data->{cgi}{disk_address},
				adapter	=>	$an->data->{cgi}{adapter},
				message	=>	$return_string,
			}});
	}
	print $an->Web->template({file => "lsi-storage.html", template => "lsi-complete-table-message", replace => { 
		title		=>	"#!string!lsi_0026!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	}});
	
	if ($success)
	{
		# Mark the disk as "missing" from the array.
		lsi_control_mark_disk_missing($an);
	}

	return(0);
}

# This puts an "Offline" disk into "Online" state.
sub lsi_control_put_disk_online
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "lsi_control_put_disk_online" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $an->data->{cgi}{cluster};
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	
	my $shell_call = $an->data->{storage}{is}{lsi}." PDRbld Start PhysDrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$return_string .= "$line<br />\n";
		if ($line =~ /started rebuild progress on device/i)
		{
			$success = 1;
		}
	}
	
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = $an->String->get({key => "lsi_0028", variables => { 
			disk	=>	$an->data->{cgi}{disk_address},
			adapter	=>	$an->data->{cgi}{adapter},
		}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = $an->String->get({key => "lsi_0029", variables => { 
				disk	=>	$an->data->{cgi}{disk_address},
				adapter	=>	$an->data->{cgi}{adapter},
				message	=>	$return_string,
			}});
	}
	print $an->Web->template({file => "lsi-storage.html", template => "lsi-complete-table-messag", replace => { 
		title		=>	"#!string!lsi_0030!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
	}});

	return(0);
}

# This adds an "Unconfigured Good" disk to the specified array.
sub lsi_control_add_disk_to_array
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "lsi_control_add_disk_to_array" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $an->data->{cgi}{cluster};
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	
	my $shell_call = $an->data->{storage}{is}{lsi}." PdReplaceMissing PhysDrv [".$an->data->{cgi}{disk_address}."] -array$an->data->{cgi}{logical_disk} -row$an->data->{cgi}{row} -a".$an->data->{cgi}{adapter};
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$return_string .= "$line<br />\n";
		if (($line =~ /successfully added the disk/i) || ($line =~ /missing pd at array/i))
		{
			$success = 1;
		}
	}
	
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = $an->String->get({key => "lsi_0031", variables => { 
			disk		=>	$an->data->{cgi}{disk_address},
			adapter		=>	$an->data->{cgi}{adapter},
			logical_disk	=>	$an->data->{cgi}{logical_disk},
		}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = $an->String->get({key => "lsi_0032", variables => { 
				disk		=>	$an->data->{cgi}{disk_address},
				adapter		=>	$an->data->{cgi}{adapter},
				logical_disk	=>	$an->data->{cgi}{logical_disk},
				message		=>	$return_string,
			}});
	}
	print $an->Web->template({file => "lsi-storage.html", template => "lsi-complete-table-message", replace => { 
		title		=>	"#!string!lsi_0033!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	}});
	
	# If successful, put the disk Online.
	if ($success)
	{
		lsi_control_put_disk_online($an);
	}
	
	return(0);
}

# This looks ip the missing disk(s) in a given degraded array
sub lsi_control_get_missing_disks
{
	my ($an, $this_adapter, $this_logical_disk) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "lsi_control_get_missing_disks" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "this_adapter",      value1 => $this_adapter, 
		name2 => "this_logical_disk", value2 => $this_logical_disk, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $cluster           = $an->data->{cgi}{cluster};
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	
	my $shell_call = $an->data->{storage}{is}{lsi}." PdGetMissing a$this_adapter";
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /\d+\s+\d+\s+(\d+)\s(\d+)/i)
		{
			my $this_row     =  $1;
			my $minimum_size =  $2;		# This is in MiB and is the cooerced size.
			   $minimum_size *= 1048576;	# Now it should be in bytes
			$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{missing_row}{$this_row} = $minimum_size;
		}
	}
	
	return(0);
}

# This tells the controller to make the flagged disk "Good"
sub lsi_control_make_disk_good
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "lsi_control_make_disk_good" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $an->data->{cgi}{cluster};
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	
	my $shell_call = $an->data->{storage}{is}{lsi}." PDMakeGood PhysDrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$return_string .= "$line<br />\n";
		if ($line =~ /state changed to unconfigured-good/i)
		{
			$success = 1;
		}
	}
	
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = $an->String->get({key => "lsi_0034", variables => { 
			disk		=>	$an->data->{cgi}{disk_address},
			adapter		=>	$an->data->{cgi}{adapter},
		}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = $an->String->get({key => "lsi_0035", variables => { 
				disk		=>	$an->data->{cgi}{disk_address},
				adapter		=>	$an->data->{cgi}{adapter},
				message		=>	$return_string,
			}});
	}
	print $an->Web->template({file => "lsi-storage.html", template => "lsi-complete-table-message", replace => { 
		title		=>	"#!string!lsi_0036!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	}});
	
	return($success);
}

# This turns on or off the "locate" LED on the hard drives.
sub lsi_control_disk_id_led
{
	my ($an, $action) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "lsi_control_disk_id_led" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "action", value1 => $action, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $success           = 0;
	my $return_string     = "";
	my $cluster           = $an->data->{cgi}{cluster};
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	my $say_action        = "#!string!state_0014!#";
	if ($action eq "stop")
	{
		$say_action = "#!string!state_0015!#";
	}
	elsif ($action ne "start")
	{
		$action = "start";
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "action",     value1 => $action,
		name2 => "say_action", value2 => $say_action,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $shell_call = $an->data->{storage}{is}{lsi}." PdLocate $action physdrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$return_string .= "$line<br />\n";
		if ($line =~ /command was successfully sent to firmware/i)
		{
			$success = 1;
		}
	}
	
	my $title_message = "#!string!state_0005!#";
	my $title_class   = "highlight_good";
	my $message_body  = $an->String->get({key => "lsi_0037", variables => { 
			disk	=>	$an->data->{cgi}{disk_address},
			adapter	=>	$an->data->{cgi}{adapter},
			action	=>	$say_action,
		}});
	if (not $success)
	{
		$title_message = "#!string!row_0044!#";
		$title_class   = "highlight_warning";
		$message_body  = $an->String->get({key => "lsi_0038", variables => { 
				disk	=>	$an->data->{cgi}{disk_address},
				adapter	=>	$an->data->{cgi}{adapter},
				message	=>	$return_string,
				action	=>	$say_action,
			}});
	}
	print $an->Web->template({file => "lsi-storage.html", template => "lsi-complete-table-message", replace => { 
		title		=>	"#!string!lsi_0039!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
		message		=>	$message_body,
	}});
	
	return ($success);
}

# This reads the sensor values of a given node and displays them. Some sensors will be controllable; like 
# failing/adding a hard drive.
sub display_node_health
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "display_node_health" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $cluster           = $an->data->{cgi}{cluster};
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	
	# Open up the table.
	print $an->Web->template({file => "lsi-storage.html", template => "lsi-adapter-health-header", replace => { 
		anvil		=>	$cluster,
		node_anvil_name	=>	$node_cluster_name,
		node		=>	$node,
	}});
	
	# Display results.
	if ($an->data->{storage}{is}{lsi})
	{
		# Displaying storage
		$an->Log->entry({log_level => 2, message_key => "log_0218", file => $THIS_FILE, line => __LINE__});
		foreach my $this_adapter (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "- this_adapter", value1 => $this_adapter,
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $this_logical_disk (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "  - this_logical_disk", value1 => $this_logical_disk,
				}, file => $THIS_FILE, line => __LINE__});
				foreach my $this_enclosure_device_id (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}})
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "    - this_enclosure_device_id", value1 => $this_enclosure_device_id,
					}, file => $THIS_FILE, line => __LINE__});
					foreach my $this_slot_number (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}})
					{
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "      - this_slot_number", value1 => $this_slot_number,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
			}
			my $say_bbu   =                      $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu_is}                        ? "Present" : "Not Installed";
			my $say_flash =                      $an->data->{storage}{lsi}{adapter}{$this_adapter}{flash_is}                      ? "Present" : "Not Installed";
			my $say_restore_hotspare_on_insert = $an->data->{storage}{lsi}{adapter}{$this_adapter}{restore_hotspare_on_insertion} ? "Yes"     : "No";
			my $say_title = $an->String->get({key => "lsi_0040", variables => { adapter => $this_adapter }});

			print $an->Web->template({file => "lsi-storage.html", template => "lsi-adapter-state", replace => { 
				title				=>	$say_title,
				model				=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{product_name},
				cache_size			=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{cache_size},
				bbu				=>	$say_bbu,
				flash_module			=>	$say_flash,
				restore_hotspare_on_insert	=>	$say_restore_hotspare_on_insert,
			}});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "  - storage::lsi::adapter::${this_adapter}::bbu_is", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu_is},
			}, file => $THIS_FILE, line => __LINE__});
			if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu_is})
			{
				my $say_replace_bbu     = $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{replace_bbu}        ? "Yes" : "No";
				my $say_learn_cycle     = $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{learn_cycle_active} ? "Yes" : "No";
				my $battery_state_class = "highlight_good";
				if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{battery_state} ne "Optimal")
				{
					$battery_state_class = "highlight_bad";
				}
				
				# What I show depends on the device the user has.
				my $say_current_capacity = "--";
				my $say_design_capcity   = "--";
				my $say_current_charge   = "--";
				my $say_cycle_count      = "<span class=\"highlight_unavailable\">#!string!state_0016!#</a>";
				if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{full_capacity})
				{
					$say_current_capacity = $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{full_capacity};
				}
				elsif ($an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{capacitance})
				{
					$say_current_capacity = $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{capacitance}." %";
				}
				if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{design_capacity})
				{
					$say_design_capcity = $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{design_capacity};
				}
				if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{remaining_capacity})
				{
					$say_current_charge = $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{remaining_capacity};
				}
				elsif ($an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{pack_energy})
				{
					$say_current_charge = $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{pack_energy};
				}
				if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{cycle_count})
				{
					$say_cycle_count = $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{cycle_count};
				}
				
				print $an->Web->template({file => "lsi-storage.html", template => "lsi-bbu-state", replace => { 
					battery_state		=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{battery_state},
					battery_state_class	=>	$battery_state_class,
					manufacture_name	=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{manufacture_name},
					bbu_type		=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{type},
					full_capacity		=>	$say_current_capacity,
					design_capacity		=>	$say_design_capcity,
					remaining_capacity	=>	$say_current_charge,
					replace_bbu		=>	$say_replace_bbu,
					learn_cycle		=>	$say_learn_cycle,
					next_learn_cycle	=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{next_learn_time},
					cycle_count		=>	$say_cycle_count,
				}});
			}
			
			# Show the logical disks now.
			foreach my $this_logical_disk (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}})
			{
				next if $this_logical_disk eq "";
				my $say_bad_blocks =  $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{bad_blocks_exist} ? "Yes" : "No";
				my $say_size       =  $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{size};
				   $say_size       =~ s/(\w)B/$1iB/;	# The use 'GB' when it should be 'GiB'.
				my $logical_disk_state_class = "highlight_good";
				my $say_missing    = "";
				my $allow_offline  = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "this_adapter",                                                                      value1 => $this_adapter,
					name2 => "this_logical_disk",                                                                 value2 => $this_logical_disk,
					name3 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::state", value3 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'},
				}, file => $THIS_FILE, line => __LINE__});
				if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'} =~ /Degraded/i)
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "this_adapter",                                                                      value1 => $this_adapter,
						name2 => "this_logical_disk",                                                                 value2 => $this_logical_disk,
						name3 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::state", value3 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'},
					}, file => $THIS_FILE, line => __LINE__});
					lsi_control_get_missing_disks($an, $this_adapter, $this_logical_disk);
					$allow_offline            = 0;
					$logical_disk_state_class = "highlight_bad";
					if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'} =~ /Partially Degraded/i)
					{
						$logical_disk_state_class = "highlight_warning";
					}
					$say_missing = "<br />";
					foreach my $this_row (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{missing_row}})
					{
						my $say_minimum_size =  $an->Readable->bytes_to_hr({'bytes' => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{missing_row}{$this_row} });
						$say_missing         .= $an->String->get({key => "lsi_0041", variables => { 
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
					print $an->Web->template({file => "lsi-storage.html", template => "lsi-unassigned-disks"});
				}
				else
				{
					# Real logical disk
					next if not $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'};
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "this_adapter",                                                                      value1 => $this_adapter,
						name2 => "this_logical_disk",                                                                 value2 => $this_logical_disk,
						name3 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::state", value3 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'},
					}, file => $THIS_FILE, line => __LINE__});
					my $title = $an->String->get({key => "title_0021", variables => { logical_disk => $this_logical_disk }});
					print $an->Web->template({file => "lsi-storage.html", template => "lsi-logical-disk-state", replace => { 
						title				=>	$title,
						logical_disk_state		=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'},
						logical_disk_state_class	=>	$logical_disk_state_class,
						missing				=>	$say_missing,
						bad_blocks_exist		=>	$say_bad_blocks,
						primary_raid_level		=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{primary_raid_level},
						raid_url			=>	"https://alteeve.ca/w/TLUG_Talk:_Storage_Technologies_and_Theory#Level_$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{primary_raid_level}",
						size				=>	$say_size,
						number_of_drives		=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{number_of_drives},
						encryption_type			=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{encryption_type},
						target_id			=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{target_id},
						current_cache_policy		=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{current_cache_policy},
						disk_cache_policy		=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{disk_cache_policy},
					}});
				}
				
				# Display the drives in this logical disk.
				foreach my $this_enclosure_device_id (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}})
				{
					#print " | |- Enclusure Device ID: [$this_enclosure_device_id]<br />\n";
					foreach my $this_slot_number (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}})
					{
						my $raw_size_sectors = hex($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{raw_sector_count_in_hex});
						my $raw_size_bytes   = ($raw_size_sectors * $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sector_size});
						my $say_raw_size     = $an->Readable->bytes_to_hr({'bytes' => $raw_size_bytes });
						my $disk_temp_class  = "highlight_good";
						if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_c} > 54)
						{
							$disk_temp_class = "highlight_dangerous";
						}
						elsif ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_c} > 45)
						{
							$disk_temp_class = "highlight_warning";
						}
						my $say_drive_temp_c = $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_c} ? $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_c} : "--";
						my $say_drive_temp_f = $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_f} ? $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_f} : "--";
						my $say_temperature = "<span class=\"$disk_temp_class\">$say_drive_temp_c &deg;C ($say_drive_temp_f &deg;F)</span>";
						
						my $say_location_title = $an->String->get({key => "row_0066"});
						my $say_location_body  = $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{span}.", ".$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{arm}.", ".$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_id};
						if ($this_logical_disk == 9999)
						{
							$say_location_title = $an->String->get({key => "row_0067"});
							$say_location_body  = $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_id};
						}
						
						my $button = $an->String->get({key => "row_0067"});
						my $say_offline_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => $button }});
						my $offline_button = $say_offline_disabled_button;
						if ($allow_offline)
						{
							$offline_button = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
									button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&node=".$an->data->{cgi}{node}."&node_cluster_name=".$an->data->{cgi}{node_cluster_name}."&task=display_health&do=put_disk_offline&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter&logical_disk=$this_logical_disk",
									button_text	=>	"#!string!button_0006!#",
									id		=>	"put_disk_offline_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
								}});
							if ($this_logical_disk == 9999)
							{
								$offline_button = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
										button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&node=".$an->data->{cgi}{node}."&node_cluster_name=".$an->data->{cgi}{node_cluster_name}."&task=display_health&do=spin_disk_down&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter&logical_disk=$this_logical_disk",
										button_text	=>	"#!string!button_0007!#",
										id		=>	"spin_disk_down_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
									}});
							}
						}
						
						my $disk_state_class = "highlight_good";
						my $say_disk_action  = "";
						if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Unconfigured(bad)")
						{
							$disk_state_class =  "highlight_bad";
							$say_disk_action  =  $an->Web->template({file => "common.html", template => "new_line"});
							$say_disk_action  .= $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
									button_class	=>	"highlight_warning",
									button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&node=".$an->data->{cgi}{node}."&node_cluster_name=".$an->data->{cgi}{node_cluster_name}."&task=display_health&do=make_disk_good&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
									button_text	=>	"#!string!button_0008!#",
									id		=>	"make_disk_good_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
								}});
						}
						elsif ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Offline")
						{
							$disk_state_class = "highlight_detail";
							my $say_put_disk_online_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
									button_class	=>	$disk_state_class,
									button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&node=".$an->data->{cgi}{node}."&node_cluster_name=".$an->data->{cgi}{node_cluster_name}."&task=display_health&do=put_disk_online&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
									button_text	=>	"#!string!button_0009!#",
									id		=>	"put_disk_online__${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
								}});
							my $say_spin_disk_down_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
									button_class	=>	$disk_state_class,
									button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&node=".$an->data->{cgi}{node}."&node_cluster_name=".$an->data->{cgi}{node_cluster_name}."&task=display_health&do=spin_disk_down&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
									button_text	=>	"#!string!button_0007!#",
									id		=>	"spin_disk_down",
								}});
							$say_disk_action = " - $say_put_disk_online_button - $say_spin_disk_down_button";
						}
						elsif ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Rebuild")
						{
							my ($rebuild_percent, $time_to_complete) = lsi_control_get_rebuild_progress($an, "$this_enclosure_device_id:$this_slot_number", $this_adapter);
							$disk_state_class = "highlight_warning";
							$say_disk_action  = $an->String->get({key => "lsi_0042", variables => { 
									rebuild_percent		=>	$rebuild_percent,
									time_to_complete	=>	$time_to_complete,
								}});
						}
						elsif ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Unconfigured(good), Spun Up")
						{
							$disk_state_class = "highlight_detail";
							foreach my $this_logical_disk (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}})
							{
								next if $this_logical_disk eq "";
								if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'} =~ /Degraded/i)
								{
									# NOTE: I only loop once because if two drives are missing from a RAID 6 
									#       array, the 'Add to this_logical_disk' will print twice, once for each
									#       row. So we exit the loop after the first run and thus will always
									#       add disks to the first open row.
									foreach my $this_row (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{missing_row}})
									{
										$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
											name1 => "this_row", value1 => $this_row,
										}, file => $THIS_FILE, line => __LINE__});
										if ($raw_size_bytes >= $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{missing_row}{$this_row})
										{
											my $say_button = $an->String->get({key => "button_0010", variables => { logical_disk => $this_logical_disk }});
											$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
												name1 => "say_button", value1 => $say_button,
											}, file => $THIS_FILE, line => __LINE__});
											
											$say_disk_action =  $an->Web->template({file => "common.html", template => "new_line"}) if not $say_disk_action;
											$say_disk_action .= $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
												button_class	=>	"bold_button",
												button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&node=".$an->data->{cgi}{node}."&node_cluster_name=".$an->data->{cgi}{node_cluster_name}."&task=display_health&do=add_disk_to_array&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter&row=$this_row&logical_disk=$this_logical_disk",
												button_text	=>	$say_button,
												id		=>	"add_disk_to_array_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
											}});
											$say_disk_action .= $an->Web->template({file => "common.html", template => "new_line"});
											$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
												name1 => "say_disk_action", value1 => $say_disk_action,
											}, file => $THIS_FILE, line => __LINE__});
										}
										last;
									}
								}
								elsif ($this_logical_disk == 9999)
								{
									$say_disk_action =  $an->Web->template({file => "common.html", template => "new_line"}) if not $say_disk_action;
									$say_disk_action .= $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
											button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&node=".$an->data->{cgi}{node}."&node_cluster_name=".$an->data->{cgi}{node_cluster_name}."&task=display_health&do=make_disk_hot_spare&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
											button_text	=>	"#!string!button_0011!#",
											id		=>	"make_disk_hot_spare_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
										}});
									$say_disk_action = $an->Web->template({file => "common.html", template => "new_line"});
								}
							}
						}
						elsif ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Unconfigured(good), Spun down")
						{
							$disk_state_class =  "highlight_detail";
							$say_disk_action  =  $an->Web->template({file => "common.html", template => "new_line"});
							$say_disk_action  .= $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
									button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&node=".$an->data->{cgi}{node}."&node_cluster_name=".$an->data->{cgi}{node_cluster_name}."&task=display_health&do=spin_disk_up&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
									button_text	=>	"#!string!button_0012!#",
									id		=>	"spin_disk_up_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
								}});
							$say_temperature  = "<span class=\"highlight_unavailable\">".$an->String->get({key => "message_0055"})."</a>";
							$offline_button   = $an->String->get({key => "message_0054"});
						}
						elsif ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Hotspare, Transition")
						{
							$disk_state_class =  "highlight_detail";
							$say_disk_action  =  $an->Web->template({file => "common.html", template => "new_line"});
							$say_disk_action  .= $an->String->get({key => "message_0056"});
							$say_temperature  =  "<span class=\"highlight_unavailable\">".$an->String->get({key => "message_0057"})."</span>";
							$offline_button   =  $an->String->get({key => "message_0058"});
						}
						elsif ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Hotspare, Spun Up")
						{
							$disk_state_class = "highlight_detail";
							$say_disk_action  = "";
							$offline_button   = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
									button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&node=".$an->data->{cgi}{node}."&node_cluster_name=".$an->data->{cgi}{node_cluster_name}."&task=display_health&do=unmake_disk_as_hot_spare&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter&logical_disk=$this_logical_disk",
									button_text	=>	"#!string!button_0013!#",
									id		=>	"unmake_disk_as_hot_spare_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
								}});
						}
						### TODO: 'Copyback' state is when a drive has been inserted 
						###       into an array after a hot-spare took over a failed 
						###       disk. This state is where the hot-spare's data gets
						###       copied to the replaced drive, then the old hot 
						###       spare reverts again to being a hot spare.
						my $disk_icon    = $an->data->{url}{skins}."/".$an->data->{sys}{skin}."/images/hard-drive_128x128.png";
						my $id_led_url   = "?cluster=".$an->data->{cgi}{cluster}."&node=".$an->data->{cgi}{node}."&node_cluster_name=".$an->data->{cgi}{node_cluster_name}."&task=display_health&do=start_id_disk&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter";
						my $say_identify = $an->String->get({key => "button_0014"});
						#print "adapter: [$this_adapter], Disk: [$this_enclosure_device_id:$this_slot_number], Locator ID Status: [$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit}]\n";
						if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit})
						{
							$disk_icon    = $an->data->{url}{skins}."/".$an->data->{sys}{skin}."/images/hard-drive-with-led_128x128.png";
							$id_led_url   = "?cluster=".$an->data->{cgi}{cluster}."&node=".$an->data->{cgi}{node}."&node_cluster_name=".$an->data->{cgi}{node_cluster_name}."&task=display_health&do=stop_id_disk&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter";
							$say_identify = $an->String->get({key => "button_0015"});
						}
						# This needs to be last because if a drive is foreign,
						# we can't do anything else to it.
						my $foreign_state_class = "fixed_width_left";
						my $say_foreign_state   = "#!string!state_0013!#";
						if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{foreign_state} eq "Foreign")
						{
							$foreign_state_class =  "highlight_warning_bold_fixed_width_left";
							$say_foreign_state   =  "#!string!state_0012!#";
							$say_disk_action     .= $an->Web->template({file => "common.html", template => "new_line"});
							$say_disk_action     .= $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
									button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&node=".$an->data->{cgi}{node}."&node_cluster_name=".$an->data->{cgi}{node_cluster_name}."&task=display_health&do=clear_foreign_state&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
									button_text	=>	"#!string!button_0038!#",
									id		=>	"clear_foreign_state_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
								}});
						}
						
						# Finally, show the drive.
						my $title = $an->String->get({key => "title_0022", variables => { 
								slot_number		=>	$this_slot_number,
								enclosure_device_id	=>	$this_enclosure_device_id,
							}});
						$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_1} = "--" if not $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_1};
						print $an->Web->template({file => "lsi-storage.html", template => "lsi-physical-disk-state", replace => { 
							title				=>	$title,
							id_led_url			=>	$id_led_url,
							disk_icon			=>	$disk_icon,
							model				=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{inquiry_data},
							wwn				=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{wwn},
							disk_state			=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state},
							foreign_state			=>	$say_foreign_state,
							foreign_state_class		=>	$foreign_state_class,
							disk_state_class		=>	$disk_state_class,
							disk_action			=>	$say_disk_action,
							temperature			=>	$say_temperature,
							id_led_url			=>	$id_led_url,
							identify			=>	$say_identify,
							device_type			=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{media_type},
							media_error_count		=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{media_error_count},
							other_error_count		=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{other_error_count},
							predictive_failure_count	=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{predictive_failure_count},
							raw_drive_size			=>	$say_raw_size,
							pd_type				=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{pd_type},
							device_speed			=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_speed},
							link_speed			=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{link_speed},
							sas_address_0			=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_0},
							sas_address_1			=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_1},
							location_title			=>	$say_location_title,
							location_body			=>	$say_location_body,
							offline_button			=>	$offline_button,
						}});
					}
				}
			}
		}
	}
	
	# Close the table.
	print $an->Web->template({file => "lsi-storage.html", template => "lsi-adapter-health-footer"});

	return(0);
}

# This determines what kind of storage the user has and then calls the appropriate function to gather the 
# details.
sub get_storage_data
{
	my ($an, $node) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_storage_data" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->data->{storage}{is}{lsi}   = "";
	$an->data->{storage}{is}{hp}    = "";
	$an->data->{storage}{is}{mdadm} = "";
	my $shell_call = "whereis MegaCli64 hpacucli";
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^(.*?):\s(.*)/)
		{
			my $program = $1;
			my $path    = $2;
			#print "program: [$program], path: [$path]\n";
			if ($program eq "MegaCli64")
			{
				$an->data->{storage}{is}{lsi} = $path;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::is::lsi", value1 => $an->data->{storage}{is}{lsi},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($program eq "hpacucli")
			{
				$an->data->{storage}{is}{hp} = $path;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::is::hp", value1 => $an->data->{storage}{is}{hp},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($program eq "mdadm")
			{
				### TODO: This is always installed... 
				### Check if any arrays are configured and drop this if none.
				$an->data->{storage}{is}{mdadm} = $path;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::is::mdadm", value1 => $an->data->{storage}{is}{mdadm},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# For now, only LSI is supported.
	if ($an->data->{storage}{is}{lsi})
	{
		get_storage_data_lsi($an, $node);
	}
	
	return(0);
}

# This uses the 'MegaCli64' program to gather information about the LSI-based storage of a node.
sub get_storage_data_lsi
{
	my ($an, $node) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_storage_data_lsi" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
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
	delete $an->data->{storage}{lsi}{adapter};
	
	# This is set to 1 once all the discovered physical drives have been
	# found and their ID LED statuses set to '0'.
	my $initial_led_state_set = 0;
	
	# Now call.
	my $in_section     =  0;
	my $megacli64_path =  $an->data->{storage}{is}{lsi};
	my $shell_call     =  "echo '==] Start adapter_info'; $megacli64_path AdpAllInfo aAll; ";
	   $shell_call     .= "echo '==] Start bbu_info'; $megacli64_path AdpBbuCmd aAll; ";
	   $shell_call     .= "echo '==] Start logical_disk_info'; $megacli64_path LDInfo Lall aAll; ";
	   $shell_call     .= "echo '==] Start physical_disk_info'; $megacli64_path PDList aAll; ";
	   $shell_call     .= "echo '==] Start pd_id_led_state'; $an->data->{path}{grep} \"PD Locate\" /root/MegaSAS.log;";
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /==] Start (.*)/)
		{
			$in_section        = $1;
			$this_adapter      = "";
			$this_logical_disk = "";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "in_section",        value1 => $in_section,
				name2 => "this_adapter",      value2 => $this_adapter,
				name3 => "this_logical_disk", value3 => $this_logical_disk,
			}, file => $THIS_FILE, line => __LINE__});
			next;
		}
		if ($in_section eq "adapter_info")
		{
			### TODO: Get the amount of cache allocated to 
			###       write-back vs. read caching and make it
			###       adjustable.
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "in_section", value1 => $in_section,
				name2 => "line",       value2 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /Adapter #(\d+)/)
			{
				$this_adapter = $1;
				next;
			}
			next if $this_adapter eq "";
			
			if (($skip_equal_sign_bar) && ($line =~ /^====/))
			{
				$skip_equal_sign_bar = 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::product_name", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{product_name},
					name2 => "skip_equal_sign_bar",                                  value2 => $skip_equal_sign_bar,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			
			if ($line =~ /Product Name\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{product_name} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_adapter",                                         value1 => $this_adapter,
					name2 => "storage::lsi::adapter::${this_adapter}::product_name", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{product_name},
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			# Hardware Configuration values.
			if ($line eq "HW Configuration")
			{
				$in_hw_information   = 1;
				$skip_equal_sign_bar = 1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::product_name", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{product_name},
					name2 => "in_hw_information",                                    value2 => $in_hw_information,
					name3 => "skip_equal_sign_bar",                                  value3 => $skip_equal_sign_bar,
				}, file => $THIS_FILE, line => __LINE__});
				next
			}
			elsif ($in_hw_information)
			{
				if ($line =~ /^====/)
				{
					$in_hw_information = 0;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "storage::lsi::adapter::${this_adapter}::product_name", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{product_name},
						name2 => "in_hw_information",                                    value2 => $in_hw_information,
					}, file => $THIS_FILE, line => __LINE__});
					next
				}
				elsif ($line =~ /Memory Size\s*:\s*(.*)/)
				{
					$an->data->{storage}{lsi}{adapter}{$this_adapter}{cache_size} = $1;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "this_adapter",                                       value1 => $this_adapter,
						name2 => "storage::lsi::adapter::${this_adapter}::cache_size", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{cache_size},
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($line =~ /BBU\s*:\s*(.*)/)
				{
					my $bbu_is = $1;
					$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu_is} = $bbu_is eq "Present" ? 1 : 0;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
						name1 => "this_adapter",                                   value1 => $this_adapter,
						name2 => "storage::lsi::adapter::${this_adapter}::bbu_is", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu_is},
						name3 => "bbu_is",                                         value3 => $bbu_is,
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($line =~ /Flash\s*:\s*(.*)/)
				{
					my $flash_is = $1;
					$an->data->{storage}{lsi}{adapter}{$this_adapter}{flash_is} = $flash_is eq "Present" ? 1 : 0;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
						name1 => "this_adapter",                                     value1 => $this_adapter,
						name2 => "storage::lsi::adapter::${this_adapter}::flash_is", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{flash_is},
						name3 => "flash_is",                                         value3 => $flash_is,
					}, file => $THIS_FILE, line => __LINE__});
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
					$an->data->{storage}{lsi}{adapter}{$this_adapter}{restore_hotspare_on_insertion} = $is_enabled eq "Enabled" ? 1 : 0;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
						name1 => "this_adapter",                                                          value1 => $this_adapter,
						name2 => "storage::lsi::adapter::${this_adapter}::restore_hotspare_on_insertion", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{restore_hotspare_on_insertion}, 
						name3 => "is_enabled",                                                            value3 => $is_enabled,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		elsif ($in_section eq "bbu_info")
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "in_section", value1 => $in_section,
				name2 => "line",       value2 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /BBU status for Adapter\s*:\s*(\d+)/)
			{
				$this_adapter = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "this_adapter", value1 => $this_adapter,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			next if $this_adapter eq "";
			
			if ($line =~ /BatteryType\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{type} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_adapter",                                      value1 => $this_adapter,
					name2 => "storage::lsi::adapter::${this_adapter}::bbu::type", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{type},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Battery State\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{battery_state} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_adapter",                                               value1 => $this_adapter,
					name2 => "storage::lsi::adapter::${this_adapter}::bbu::battery_state", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{battery_state},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Learn Cycle Active\s*:\s*(.*)/)
			{
				my $learn_cycle_active = $1;
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{learn_cycle_active} = $learn_cycle_active eq "Yes" ? 1 : 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "this_adapter",                                               value1 => $this_adapter,
					name2 => "storage::lsi::adapter::${this_adapter}::learn_cycle_active", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{learn_cycle_active}, 
					name3 => "learn_cycle_active",                                         value3 => $learn_cycle_active,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Pack is about to fail & should be replaced\s*:\s*(.*)/)
			{
				my $replace_bbu = $1;
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{replace_bbu} = $replace_bbu eq "Yes" ? 1 : 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "this_adapter",                                             value1 => $this_adapter,
					name2 => "storage::lsi::adapter::${this_adapter}::bbu::replace_bbu", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{replace_bbu}, 
					name3 => "replace_bbu",                                              value3 => $replace_bbu,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Design Capacity\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{design_capacity} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_adapter",                                                 value1 => $this_adapter,
					name2 => "storage::lsi::adapter::${this_adapter}::bbu::design_capacity", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{design_capacity},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Remaining Capacity Alarm\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{remaining_capacity_alarm} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_adapter",                                                          value1 => $this_adapter,
					name2 => "storage::lsi::adapter::${this_adapter}::bbu::remaining_capacity_alarm", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{remaining_capacity_alarm},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Cycle Count\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{cycle_count} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_adapter",                                             value1 => $this_adapter,
					name2 => "storage::lsi::adapter::${this_adapter}::bbu::cycle_count", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{cycle_count},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Next Learn time\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{next_learn_time} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_adapter",                                                 value1 => $this_adapter,
					name2 => "storage::lsi::adapter::${this_adapter}::bbu::next_learn_time", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{next_learn_time},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Remaining Capacity\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{remaining_capacity} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_adapter",                                                    value1 => $this_adapter,
					name2 => "storage::lsi::adapter::${this_adapter}::bbu::remaining_capacity", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{remaining_capacity},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Full Charge Capacity\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{full_capacity} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_adapter",                                               value1 => $this_adapter,
					name2 => "storage::lsi::adapter::${this_adapter}::bbu::full_capacity", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{full_capacity},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Manufacture Name\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{manufacture_name} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_adapter",                                                  value1 => $this_adapter,
					name2 => "storage::lsi::adapter::${this_adapter}::bbu::manufacture_name", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{manufacture_name},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Pack energy\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{pack_energy} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_adapter",                                             value1 => $this_adapter,
					name2 => "storage::lsi::adapter::${this_adapter}::bbu::pack_energy", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{pack_energy},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Capacitance\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{capacitance} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_adapter",                                             value1 => $this_adapter,
					name2 => "storage::lsi::adapter::${this_adapter}::bbu::capacitance", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu}{capacitance},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		elsif ($in_section eq "logical_disk_info")
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "in_section", value1 => $in_section,
				name2 => "line",       value2 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /Adapter (\d+) -- Virtual Drive Information/)
			{
				$this_adapter = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "this_adapter", value1 => $this_adapter,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			next if $this_adapter eq "";
			
			if ($line =~ /Virtual Drive: (\d+) \(Target Id: (\d+)\)/)
			{
				$this_logical_disk = $1;
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{target_id} = $2;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "this_adapter",                                                                          value1 => $this_adapter,
					name2 => "this_logical_disk",                                                                     value2 => $this_logical_disk,
					name3 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::target_id", value3 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{target_id},
				}, file => $THIS_FILE, line => __LINE__});
			}
			next if $this_logical_disk eq "";
			
			if ($line =~ /^Size\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{size} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "this_adapter",                                                                     value1 => $this_adapter,
					name2 => "this_logical_disk",                                                                value2 => $this_logical_disk,
					name3 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::size", value3 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{size},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /State\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "this_adapter",                                                                      value1 => $this_adapter,
					name2 => "this_logical_disk",                                                                 value2 => $this_logical_disk,
					name3 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::state", value3 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Current Cache Policy\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{current_cache_policy} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "this_adapter",                                                                                     value1 => $this_adapter,
					name2 => "this_logical_disk",                                                                                value2 => $this_logical_disk,
					name3 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::current_cache_policy", value3 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{current_cache_policy},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Bad Blocks Exist\s*:\s*(.*)/)
			{
				my $bad_blocks = $1;
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{bad_blocks_exist} = $bad_blocks eq "Yes" ? 1 : 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
					name1 => "this_adapter",                                                                                 value1 => $this_adapter,
					name2 => "this_logical_disk",                                                                            value2 => $this_logical_disk,
					name3 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::bad_blocks_exist", value3 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{bad_blocks_exist}, 
					name4 => "bad_blocks",                                                                                   value4 => $bad_blocks, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Number Of Drives\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{number_of_drives} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "this_adapter",                                                                                 value1 => $this_adapter,
					name2 => "this_logical_disk",                                                                            value2 => $this_logical_disk,
					name3 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::number_of_drives", value3 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{number_of_drives},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Encryption Type\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{encryption_type} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "this_adapter",                                                                                value1 => $this_adapter,
					name2 => "this_logical_disk",                                                                           value2 => $this_logical_disk,
					name3 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::encryption_type", value3 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{encryption_type},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Disk Cache Policy\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{disk_cache_policy} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "this_adapter",                                                                                  value1 => $this_adapter,
					name2 => "this_logical_disk",                                                                             value2 => $this_logical_disk,
					name3 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::disk_cache_policy", value3 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{disk_cache_policy},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Sector Size\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{sector_size} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "this_adapter",                                                                            value1 => $this_adapter,
					name2 => "this_logical_disk",                                                                       value2 => $this_logical_disk,
					name3 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::sector_size", value3 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{sector_size},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /RAID Level\s*:\s*Primary-(\d+), Secondary-(\d+), RAID Level Qualifier-(\d+)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{primary_raid_level}   = $1;
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{secondary_raid_level} = $2;
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{raid_qualifier}       = $3;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "this_adapter",                                                                                   value1 => $this_adapter,
					name2 => "this_logical_disk",                                                                              value2 => $this_logical_disk,
					name3 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::primary_raid_level", value3 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{primary_raid_level},
				}, file => $THIS_FILE, line => __LINE__});
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "this_adapter",                                                                                     value1 => $this_adapter,
					name2 => "this_logical_disk",                                                                                value2 => $this_logical_disk,
					name3 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::secondary_raid_level", value3 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{secondary_raid_level},
				}, file => $THIS_FILE, line => __LINE__});
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "this_adapter",                                                                               value1 => $this_adapter,
					name2 => "this_logical_disk",                                                                          value2 => $this_logical_disk,
					name3 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::raid_qualifier", value3 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{raid_qualifier},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		elsif ($in_section eq "physical_disk_info")
		{
			### TODO: Confirm that 'Disk Group' in fact relates to
			###       the logical disk ID.
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "in_section", value1 => $in_section,
				name2 => "line",       value2 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /Adapter #(\d+)/)
			{
				$this_adapter = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "this_adapter", value1 => $this_adapter,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			next if $this_adapter eq "";
			
			$this_logical_disk = "9999" if $this_logical_disk eq "";
			$this_span         = "9999" if $this_span         eq "";
			$this_arm          = "9999" if $this_arm          eq "";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
				name1 => "this_adapter",        value1 => $this_adapter,
				name2 => "Disk Group",          value2 => $this_logical_disk,
				name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
				name4 => "Slot Number",         value4 => $this_slot_number,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /Enclosure Device ID\s*:\s*(\d+)/)
			{
				$this_enclosure_device_id = $1;
				# New device, clear the old logical disk, span and arm.
				$this_logical_disk = "";
				$this_span         = "";
				$this_arm          = "";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_adapter",                     value1 => $this_adapter,
					name2 => "Physical Disk, Encluse Device ID", value2 => $this_enclosure_device_id,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			if ($line =~ /Slot Number\s*:\s*(\d+)/)
			{
				$this_slot_number = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_adapter",               value1 => $this_adapter,
					name2 => "Physical Disk, Slot Number", value2 => $this_slot_number,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			#             Drive's position: DiskGroup: 0,     Span: 0,     Arm: 0
			if ($line =~ /Drive's position: DiskGroup: (\d+), Span: (\d+), Arm: (\d+)/)
			{
				$this_logical_disk = $1;
				$this_span         = $2;
				$this_arm          = $3;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "Disk Group",          value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			if (($line =~ /Enclosure position: N\/A/) && ($this_logical_disk eq ""))
			{
				# This is a disk not yet in any array.
				#$this_logical_disk = "9999";
				#$this_span         = "9999";
				#$this_arm          = "9999";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "Disk Group",          value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			next if (($this_enclosure_device_id eq "") or ($this_slot_number eq "") or ($this_logical_disk eq ""));
			
			if (not exists $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{span})
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{span} = $this_span;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "Disk Group",          value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
					name5 => "this_span",           value5 => $this_span,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if (not exists $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{arm})
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{arm} = $this_arm;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "Disk Group",          value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
					name5 => "this_arm",            value5 => $this_arm,
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			# Record the slot number.
			if ($line =~ /Device Id\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_id} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "this_logical_disk",   value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
					name5 => "Device ID",           value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_id},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /WWN\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{wwn} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "this_logical_disk",   value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
					name5 => "World Wide Number",   value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{wwn},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Sequence Number\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sequence_number} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "this_logical_disk",   value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
					name5 => "Sequence Number",     value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sequence_number},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Media Error Count\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{media_error_count} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "this_logical_disk",   value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
					name5 => "Media Error Count",   value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{media_error_count},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Other Error Count\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{other_error_count} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "this_logical_disk",   value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
					name5 => "Other Error Count",   value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{other_error_count},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Predictive Failure Count\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{predictive_failure_count} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",             value1 => $this_adapter,
					name2 => "this_logical_disk",        value2 => $this_logical_disk,
					name3 => "Enclosure Device ID",      value3 => $this_enclosure_device_id,
					name4 => "Slot Number",              value4 => $this_slot_number,
					name5 => "Predictive Failure Count", value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{predictive_failure_count},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /PD Type\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{pd_type} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "this_logical_disk",   value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
					name5 => "Physical Disk Type",  value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{pd_type},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Raw Size: .*? \[0x(.*?) Sectors\]/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{raw_sector_count_in_hex} = "0x".$1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",            value1 => $this_adapter,
					name2 => "this_logical_disk",       value2 => $this_logical_disk,
					name3 => "Enclosure Device ID",     value3 => $this_enclosure_device_id,
					name4 => "Slot Number",             value4 => $this_slot_number,
					name5 => "Raw Sector Count in Hex", value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{raw_sector_count_in_hex},
				}, file => $THIS_FILE, line => __LINE__});
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
					$sector_size = $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{sector_size} ? $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{sector_size} : 512;
				}
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sector_size} = $sector_size ? $sector_size : 512;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "this_logical_disk",   value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
					name5 => "Sector Size",         value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sector_size},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Firmware state\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",            value1 => $this_adapter,
					name2 => "this_logical_disk",       value2 => $this_logical_disk,
					name3 => "Enclosure Device ID",     value3 => $this_enclosure_device_id,
					name4 => "Slot Number",             value4 => $this_slot_number,
					name5 => "Firmware-Reported State", value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /SAS Address\(0\)\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_0} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",         value1 => $this_adapter,
					name2 => "this_logical_disk",    value2 => $this_logical_disk,
					name3 => "Enclosure Device ID",  value3 => $this_enclosure_device_id,
					name4 => "Slot Number",          value4 => $this_slot_number,
					name5 => "SAS Address, Port #0", value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_0},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /SAS Address\(1\)\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_1} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",         value1 => $this_adapter,
					name2 => "this_logical_disk",    value2 => $this_logical_disk,
					name3 => "Enclosure Device ID",  value3 => $this_enclosure_device_id,
					name4 => "Slot Number",          value4 => $this_slot_number,
					name5 => "SAS Address, Port #1", value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_1},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Connected Port Number\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{connected_port_number} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",          value1 => $this_adapter,
					name2 => "this_logical_disk",     value2 => $this_logical_disk,
					name3 => "Enclosure Device ID",   value3 => $this_enclosure_device_id,
					name4 => "Slot Number",           value4 => $this_slot_number,
					name5 => "Connected Port Number", value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{connected_port_number},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Inquiry Data\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{inquiry_data} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "this_logical_disk",   value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
					name5 => "Drive Data",          value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{inquiry_data},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Device Speed\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_speed} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "this_logical_disk",   value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
					name5 => "Device Speed",        value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_speed},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Link Speed\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{link_speed} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "this_logical_disk",   value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
					name5 => "Link Speed",          value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{link_speed},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Media Type\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{media_type} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "this_logical_disk",   value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
					name5 => "Media Type",          value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{media_type},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Foreign State\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{foreign_state} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "this_logical_disk",   value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
					name5 => "Foreign State",       value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{foreign_state},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Drive Temperature\s*:\s*(\d+)C \((.*?) F\)/)
			{
				my $temp_c = $1;
				my $temp_f = $2;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "temp_c", value1 => $temp_c,
					name2 => "temp_f", value2 => $temp_f,
				}, file => $THIS_FILE, line => __LINE__});
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_c} = $temp_c;
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_f} = $temp_f;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",           value1 => $this_adapter,
					name2 => "this_logical_disk",      value2 => $this_logical_disk,
					name3 => "Enclosure Device ID",    value3 => $this_enclosure_device_id,
					name4 => "Slot Number",            value4 => $this_slot_number,
					name5 => "Drive Temperature (*C)", value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_c},
				}, file => $THIS_FILE, line => __LINE__});
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",           value1 => $this_adapter,
					name2 => "this_logical_disk",      value2 => $this_logical_disk,
					name3 => "Enclosure Device ID",    value3 => $this_enclosure_device_id,
					name4 => "Slot Number",            value4 => $this_slot_number,
					name5 => "Drive Temperature (*F)", value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_f},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Drive has flagged a S.M.A.R.T alert\s*:\s*(.*)/)
			{
				my $alert = $1;
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{smart_alert} = $alert eq "Yes" ? 1 : 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
					name1 => "this_adapter",        value1 => $this_adapter,
					name2 => "this_logical_disk",   value2 => $this_logical_disk,
					name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
					name4 => "Slot Number",         value4 => $this_slot_number,
					name5 => "SMART Alert",         value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{smart_alert},
					name6 => "alert",               value6 => $alert,
				}, file => $THIS_FILE, line => __LINE__});
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
				foreach my $this_adapter (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}})
				{
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "this_adapter", value1 => $this_adapter,
					}, file => $THIS_FILE, line => __LINE__});
					foreach my $this_logical_disk (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}})
					{
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "- this_logical_disk", value1 => $this_logical_disk,
						}, file => $THIS_FILE, line => __LINE__});
						foreach my $this_enclosure_device_id (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}})
						{
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => "   - Enclosure Device ID", value1 => $this_enclosure_device_id,
							}, file => $THIS_FILE, line => __LINE__});
							foreach my $this_slot_number (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}})
							{
								#print __LINE__.";      - Slot ID: [$this_slot_number]\n");
								$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit} = 0;
								$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
									name1 => "       - this_adapter", value1 => $this_adapter,
									name2 => "this_logical_disk",                value2 => $this_logical_disk,
									name3 => "Enclosure Device ID",         value3 => $this_enclosure_device_id,
									name4 => "Slot Number",                 value4 => $this_slot_number,
									name5 => "id_led_lit",                  value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit},
								}, file => $THIS_FILE, line => __LINE__});
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
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
				name1 => "this_adapter",             value1 => $this_adapter,
				name2 => "this_logical_disk",        value2 => $this_logical_disk,
				name3 => "this_enclosure_device_id", value3 => $this_enclosure_device_id,
				name4 => "this_slot_number",         value4 => $this_slot_number,
				name5 => "this_action",              value5 => $this_action,
				name6 => "set_state",                value6 => $set_state,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /adapter: (\d+): device at enclid-(\d+) slotid-(\d+) -- pd locate (.*?) command was successfully sent to firmware/)
			{
				$this_adapter             = $1;
				$this_enclosure_device_id = $2;
				$this_slot_number         = $3;
				$this_action              = $4;
				$set_state                = $this_action eq "start" ? 1 : 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
					name1 => "- this_adapter",           value1 => $this_adapter,
					name2 => "this_logical_disk",        value2 => $this_logical_disk,
					name3 => "this_enclosure_device_id", value3 => $this_enclosure_device_id,
					name4 => "this_slot_number",         value4 => $this_slot_number,
					name5 => "this_action",              value5 => $this_action,
					name6 => "set_state",                value6 => $set_state,
				}, file => $THIS_FILE, line => __LINE__});
				
				# the log doesn't reference the disk's logic
				# drive, so we loop through all looking for a
				# match.
				foreach my $this_adapter (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}})
				{
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "Adapter", value1 => $this_adapter,
					}, file => $THIS_FILE, line => __LINE__});
					foreach my $this_logical_disk (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}})
					{
						$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
							name1 => "  - Adapter",         value1 => $this_logical_disk,
							name2 => "this_logical_disk",        value2 => $this_logical_disk,
							name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
							name4 => "Slot Number",         value4 => $this_slot_number,
						}, file => $THIS_FILE, line => __LINE__});
						if (exists $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number})
						{
							$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit} = $set_state;
							# Exists
							$an->Log->entry({log_level => 2, message_key => "log_0219", file => $THIS_FILE, line => __LINE__});
							$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
								name1 => "this_adapter",        value1 => $this_adapter,
								name2 => "this_logical_disk",   value2 => $this_logical_disk,
								name3 => "Enclosure Device ID", value3 => $this_enclosure_device_id,
								name4 => "Slot Number",         value4 => $this_slot_number,
								name5 => "id_led_lit",          value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit},
							}, file => $THIS_FILE, line => __LINE__});
							last;
						}
						else
						{
							# Doesn't exist.
							$an->Log->entry({log_level => 2, message_key => "log_0220", file => $THIS_FILE, line => __LINE__});
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
	foreach my $this_adapter (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}})
	{
		foreach my $this_logical_disk (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}})
		{
			foreach my $this_enclosure_device_id (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}})
			{
				foreach my $this_slot_number (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}})
				{
					if (exists $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit})
					{
						$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
							name1 => "adapter",                                                                                                                                                                    value1 => $this_adapter,
							name2 => "this_logical_disk",                                                                                                                                                          value2 => $this_logical_disk,
							name3 => "Disk Address",                                                                                                                                                               value3 => $this_enclosure_device_id, 
							name4 => "this_slot_number",                                                                                                                                                           value4 => $this_slot_number, 
							name5 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::id_led_lit", value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit},
						}, file => $THIS_FILE, line => __LINE__});
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
	my ($an, $node) = @_;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "change_vm" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $cluster                             =  $an->data->{cgi}{cluster};
	my $vm                                  =  $an->data->{cgi}{vm};
	my $say_vm                              =  ($vm =~ /vm:(.*)/)[0];
	my $node1                               =  $an->data->{clusters}{$cluster}{nodes}[0];
	my $node2                               =  $an->data->{clusters}{$cluster}{nodes}[1];
	my $device                              =  $an->data->{cgi}{device};
	my $new_server_note                     =  $an->data->{cgi}{server_note};
	my $new_server_migration_type           =  $an->data->{cgi}{server_migration_type};
	my $new_server_pre_migration_script     =  $an->data->{cgi}{server_pre_migration_script};
	my $new_server_pre_migration_arguments  =  $an->data->{cgi}{server_pre_migration_arguments};
	my $new_server_post_migration_script    =  $an->data->{cgi}{server_post_migration_script};
	my $new_server_post_migration_arguments =  $an->data->{cgi}{server_post_migration_arguments};
	my $new_server_start_after              =  $an->data->{cgi}{server_start_after};
	   $new_server_start_after              =~ s/^\s+//;
	   $new_server_start_after              =~ s/\s+$//;
	my $new_server_start_delay              = $an->data->{cgi}{server_start_delay};
	   $new_server_start_delay              =~ s/^\s+//;
	   $new_server_start_delay              =~ s/\s+$//;
	my $definition_file                     =  "/shared/definitions/$say_vm.xml";
	my $other_allocated_ram                 =  $an->data->{resources}{allocated_ram} - $an->data->{vm}{$vm}{details}{ram};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0015", message_variables => {
		name1  => "cluster",                             value1  => $cluster,
		name2  => "vm",                                  value2  => $vm,
		name3  => "say_vm",                              value3  => $say_vm,
		name4  => "node1",                               value4  => $node1,
		name5  => "node2",                               value5  => $node2,
		name6  => "device",                              value6  => $device,
		name7  => "new_server_note",                     value7  => $new_server_note,
		name8  => "new_server_migration_type",           value8  => $new_server_migration_type, 
		name9  => "new_server_pre_migration_script",     value9  => $new_server_pre_migration_script, 
		name10 => "new_server_pre_migration_arguments",  value10 => $new_server_pre_migration_arguments, 
		name11 => "new_server_post_migration_script",    value11 => $new_server_post_migration_script, 
		name12 => "new_server_post_migration_arguments", value12 => $new_server_post_migration_arguments, 
		name13 => "new_server_start_after",              value13 => $new_server_start_after,
		name14 => "new_server_start_delay",              value14 => $new_server_start_delay,
		name15 => "other_allocated_ram",                 value15 => $other_allocated_ram,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Read the values the user passed, see if they differ from what was read in the config and scancore 
	# DB. If hardware resources differ, make sure the requested resources are available. If a DB entry 
	# changes, update the DB. If all this passes, rewrite the definition file and/or update the DB.
	my $hardware_changed      = 0;
	my $database_changed      = 0;
	my $current_ram           =  $an->data->{vm}{$vm}{details}{ram};
	my $available_ram         =  ($an->data->{resources}{total_ram} - $an->data->{sys}{unusable_ram} - $an->data->{resources}{allocated_ram}) + $current_ram;
	   $current_ram           /= 1024;
	my $requested_ram         =  $an->Readable->hr_to_bytes({size => $an->data->{cgi}{ram}, type => $an->data->{cgi}{ram_suffix} });
	   $requested_ram         /= 1024;
	my $max_ram               =  $available_ram / 1024;
	my $current_cpus          =  $an->data->{vm}{$vm}{details}{cpu_count};
	my $requested_cpus        =  $an->data->{cgi}{cpu_cores};
	my $current_boot_device   =  $an->data->{vm}{$vm}{current_boot_device};
	my $requested_boot_device =  $an->data->{cgi}{boot_device};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "vm",             value1 => $vm,
		name2 => "requested_ram",  value2 => $requested_ram,
		name3 => "current_ram",    value3 => $current_ram,
		name4 => "requested_cpus", value4 => $requested_cpus,
		name5 => "current_cpus",   value5 => $current_cpus,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Read in the existing note (if any) from the database.
	my $return = $an->Get->server_data({
		server => $say_vm, 
		anvil  => $cluster, 
	});
	my $server_uuid                         = $return->{uuid};
	my $old_server_note                     = $return->{note};
	my $old_server_start_after              = $return->{start_after};
	my $old_server_start_delay              = $return->{start_delay};
	my $old_server_migration_type           = $return->{migration_type};
	my $old_server_pre_migration_script     = $return->{pre_migration_script};
	my $old_server_pre_migration_arguments  = $return->{pre_migration_arguments};
	my $old_server_post_migration_script    = $return->{post_migration_script};
	my $old_server_post_migration_arguments = $return->{post_migration_arguments};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0009", message_variables => {
		name1 => "server_uuid",                         value1 => $server_uuid,
		name2 => "old_server_note",                     value2 => $old_server_note,
		name3 => "old_server_start_after",              value3 => $old_server_start_after,
		name4 => "old_server_start_delay",              value4 => $old_server_start_delay,
		name5 => "old_server_migration_type",           value5 => $old_server_migration_type, 
		name6 => "old_server_pre_migration_script",     value6 => $old_server_pre_migration_script, 
		name7 => "old_server_pre_migration_arguments",  value7 => $old_server_pre_migration_arguments, 
		name8 => "old_server_post_migration_script",    value8 => $old_server_post_migration_script, 
		name9 => "old_server_post_migration_arguments", value9 => $old_server_post_migration_arguments, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Open the table.
	my $title = $an->String->get({key => "title_0023", variables => { server => $say_vm }});
	print $an->Web->template({file => "server.html", template => "update-server-config-header", replace => { title => $title }});
	
	# If either script was removed, wipe its arguments as well.
	if (not $new_server_pre_migration_script)
	{
		$new_server_pre_migration_arguments = "";
	}
	if (not $new_server_post_migration_script)
	{
		$new_server_post_migration_arguments = "";
	}
	
	# If the 'server_start_delay' field was disabled, it would have passed nothing at all. In that case,
	# set it to the old value to avoid a needless DB update.
	if ($new_server_start_delay eq "")
	{
		$new_server_start_delay = $old_server_start_delay;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "new_server_start_delay", value1 => $new_server_start_delay,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Did any DB values change (and do I have a connection to a database)?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::db_connections", value1 => $an->data->{sys}{db_connections},
	}, file => $THIS_FILE, line => __LINE__});
	my $db_error = "";
	if (($an->data->{sys}{db_connections}) && 
	    (($old_server_note                     ne $new_server_note)        or 
	     ($old_server_start_after              ne $new_server_start_after) or 
	     ($old_server_start_delay              ne $new_server_start_delay) or 
	     ($old_server_migration_type           ne $new_server_migration_type) or 
	     ($old_server_pre_migration_script     ne $new_server_pre_migration_script) or 
	     ($old_server_pre_migration_arguments  ne $new_server_pre_migration_arguments) or
	     ($old_server_post_migration_script    ne $new_server_post_migration_script) or 
	     ($old_server_post_migration_arguments ne $new_server_post_migration_arguments)))
	{
		# Something changed. If there was a UUID, we'll update. Otherwise we'll insert.
		$database_changed = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "database_changed", value1 => $database_changed,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Make sure the values passed in for the start delay and start after are valid.
		if (($new_server_start_after) && ($new_server_start_after !~ /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/))
		{
			# Bad entry, must be a UUID.
			$db_error .= $an->String->get({key => "message_0203", variables => { value => $new_server_start_after }})."<br />";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "db_error", value1 => $db_error,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (not $new_server_start_after)
		{
			$new_server_start_after = "NULL";
			$new_server_start_delay = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "new_server_start_after", value1 => $new_server_start_after,
				name2 => "new_server_start_delay", value2 => $new_server_start_delay,
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($new_server_start_delay !~ /^\d+$/)
		{
			# Bad group, must be a digit.
			$db_error .= $an->String->get({key => "message_0239", variables => { value => $new_server_start_delay }})."<br />";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "db_error", value1 => $db_error,
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# If there was no error, proceed.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "db_error", value1 => $db_error,
		}, file => $THIS_FILE, line => __LINE__});
		if ($db_error)
		{
			$database_changed = 0;
		}
		else
		{
			my $query = "
UPDATE 
    servers 
SET 
    server_note                     = ".$an->data->{sys}{use_db_fh}->quote($new_server_note).", 
    server_start_after              = ".$an->data->{sys}{use_db_fh}->quote($new_server_start_after).", 
    server_start_delay              = ".$an->data->{sys}{use_db_fh}->quote($new_server_start_delay).", 
    server_migration_type           = ".$an->data->{sys}{use_db_fh}->quote($new_server_migration_type).", 
    server_pre_migration_script     = ".$an->data->{sys}{use_db_fh}->quote($new_server_pre_migration_script).", 
    server_pre_migration_arguments  = ".$an->data->{sys}{use_db_fh}->quote($new_server_pre_migration_arguments).", 
    server_post_migration_script    = ".$an->data->{sys}{use_db_fh}->quote($new_server_post_migration_script).", 
    server_post_migration_arguments = ".$an->data->{sys}{use_db_fh}->quote($new_server_post_migration_arguments).", 
    modified_date                   = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    server_uuid = ".$an->data->{sys}{use_db_fh}->quote($server_uuid)."
;";
			$query =~ s/'NULL'/NULL/g;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "query", value1 => $query
			}, file => $THIS_FILE, line => __LINE__});
			$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Did something in the hardware change?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "current_ram",           value1 => $current_ram,
		name2 => "requested_ram",         value2 => $requested_ram,
		name3 => "requested_cpus",        value3 => $requested_cpus,
		name4 => "current_cpus",          value4 => $current_cpus,
		name5 => "current_boot_device",   value5 => $current_boot_device,
		name6 => "requested_boot_device", value6 => $requested_boot_device,
	}, file => $THIS_FILE, line => __LINE__});
	if (($current_ram         ne $requested_ram) or 
	    ($current_cpus        ne $requested_cpus) or
	    ($current_boot_device ne $requested_boot_device))
	{
		# Something has changed. Make sure the request is sane,
		my $max_cpus = $an->data->{resources}{total_threads};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "requested_ram",  value1 => $requested_ram,
			name2 => "max_ram",        value2 => $max_ram,
			name3 => "requested_cpus", value3 => $requested_cpus,
			name4 => "max_cpus",       value4 => $max_cpus,
		}, file => $THIS_FILE, line => __LINE__});
		if ($requested_ram > $max_ram)
		{
			# Not enough RAM
			my $say_requested_ram = $an->Readable->bytes_to_hr({'bytes' => ($requested_ram * 1024) });
			my $say_max_ram       = $an->Readable->bytes_to_hr({'bytes' => ($max_ram * 1024) });
			my $message           = $an->String->get({key => "message_0059", variables => { 
					requested_ram	=>	$title,
					max_ram		=>	$say_requested_ram,
				}});
			print $an->Web->template({file => "server.html", template => "update-server-error-message", replace => { 
				title		=>	"#!string!title_0025!",
				message		=>	$message,
			}});
		}
		elsif ($requested_cpus > $max_cpus)
		{
			# Not enough CPUs
			my $message = $an->String->get({key => "message_0060", variables => { 
					requested_cpus	=>	$requested_cpus,
					max_cpus	=>	$max_cpus,
				}});
			print $an->Web->template({file => "server.html", template => "update-server-error-message", replace => { 
				title		=>	"#!string!title_0026!",
				message		=>	$message,
			}});
		}
		else
		{
			# Request is sane. Archive the current definition.
			$hardware_changed = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "hardware_changed", value1 => $hardware_changed,
			}, file => $THIS_FILE, line => __LINE__});
			
			my ($backup_file) = archive_file($an, $node, $definition_file, 1);
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "backup_file", value1 => $backup_file,
			}, file => $THIS_FILE, line => __LINE__});
			
			# Make the boot device easier to understand.
			my $say_requested_boot_device = $requested_boot_device;
			if ($requested_boot_device eq "hd")
			{
				$say_requested_boot_device = "#!string!device_0001!#";
			}
			elsif ($requested_boot_device eq "cdrom")
			{
				$say_requested_boot_device = "#!string!device_0002!#";
			}
			
			# Rewrite the XML file.
			print $an->String->get({key => "message_0061", variables => { 
					ram			=>	$an->data->{cgi}{ram},
					ram_suffix		=>	$an->data->{cgi}{ram_suffix},
					requested_cpus		=>	$requested_cpus,
					requested_boot_device	=>	$say_requested_boot_device,
				}});
			my $new_definition = "";
			my $in_os          = 0;
			my $shell_call     = $an->data->{path}{cat}." $definition_file";
			my $password       = $an->data->{sys}{root_password};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "node",       value2 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$node,
				port		=>	$an->data->{node}{$node}{port}, 
				password	=>	$password,
				ssh_fh		=>	"",
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /^(.*?)<memory>\d+<\/memory>/)
				{
					my $prefix = $1;
					$line = "${prefix}<memory>$requested_ram<\/memory>";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /^(.*?)<memory unit='.*?'>\d+<\/memory>/)
				{
					my $prefix = $1;
					$line = "${prefix}<memory unit='KiB'>$requested_ram<\/memory>";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /^(.*?)<currentMemory>\d+<\/currentMemory>/)
				{
					my $prefix = $1;
					$line = "${prefix}<currentMemory>$requested_ram<\/currentMemory>";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /^(.*?)<currentMemory unit='.*?'>\d+<\/currentMemory>/)
				{
					my $prefix = $1;
					$line = "${prefix}<currentMemory unit='KiB'>$requested_ram<\/currentMemory>";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /^(.*?)<vcpu>(\d+)<\/vcpu>/)
				{
					my $prefix = $1;
					$line = "${prefix}<vcpu>$requested_cpus<\/vcpu>";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /^(.*?)<vcpu placement='(.*?)'>(\d+)<\/vcpu>/)
				{
					my $prefix    = $1;
					my $placement = $2;
					$line = "${prefix}<vcpu placement='$placement'>$requested_cpus<\/vcpu>";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /<os>/)
				{
					$in_os          =  1;
					$new_definition .= "$line\n";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "vm",   value1 => $vm,
						name2 => "line", value2 => $line,
					}, file => $THIS_FILE, line => __LINE__});
					next;
				}
				if ($in_os)
				{
					my $boot_menu_exists = 0;
					if ($line =~ /<\/os>/)
					{
						$in_os = 0;
						
						# Write out the new list of boot devices. Start with the
						# requested boot device and then loop through the rest.
						$new_definition .= "    <boot dev='$requested_boot_device'/>\n";
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "vm",                          value1 => $vm,
							name2 => "Adding initiall boot device", value2 => $requested_boot_device,
						}, file => $THIS_FILE, line => __LINE__});
						foreach my $device (split /,/, $an->data->{vm}{$vm}{available_boot_devices})
						{
							next if $device eq $requested_boot_device;
							$new_definition .= "    <boot dev='$device'/>\n";
							$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
								name1 => "vm",     value1 => $vm,
								name2 => "device", value2 => $device,
							}, file => $THIS_FILE, line => __LINE__});
						}
						
						# Cap off with the command to enable the boot prompt
						if (not $boot_menu_exists)
						{
							$new_definition .= "    <bootmenu enable='yes'/>\n";
						}
						
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "vm",   value1 => $vm,
							name2 => "line", value2 => $line,
						}, file => $THIS_FILE, line => __LINE__});
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
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "vm",   value1 => $vm,
							name2 => "line", value2 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						next;
					}
				}
				else
				{
					$new_definition .= "$line\n";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "vm",   value1 => $vm,
						name2 => "line", value2 => $line,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			$new_definition =~ s/(\S)\s+$/$1\n/;
			$an->data->{vm}{$vm}{available_boot_devices} =~ s/,$//;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "new_definition", value1 => $new_definition,
			}, file => $THIS_FILE, line => __LINE__});
			
			# See if I need to insert or edit any network interface driver elements.
			$new_definition = update_network_driver($an, $new_definition);
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "new_definition", value1 => $new_definition,
			}, file => $THIS_FILE, line => __LINE__});
			
			# Write the new definition file.
			$shell_call = "echo \"$new_definition\" > $definition_file && chmod 644 $definition_file";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "node",       value2 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$node,
				port		=>	$an->data->{node}{$node}{port}, 
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
				
				print $an->Web->template({file => "common.html", template => "shell-call-output", replace => { line => $line }});
			}
			
			# Sanity check the new XML and restore the backup if anything goes wrong.
			my $say_ok  =  $an->String->get({key => "message_0335"});
			my $say_bad =  $an->String->get({key => "message_0336"});
			   $say_ok  =~ s/'/\\'/g;
			   $say_ok  =~ s/\\/\\\\/g;
			   $say_bad =~ s/'/\\'/g;
			   $say_bad =~ s/\\/\\\\/g;
			$shell_call = "
if \$(".$an->data->{path}{'grep'}." -q '</domain>' $definition_file);
then
    echo '$say_ok'; 
else 
    echo revert
    echo '$say_bad';
    ".$an->data->{path}{cp}." -f $backup_file $definition_file
fi
";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "node",       value2 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$node,
				port		=>	$an->data->{node}{$node}{port}, 
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
				
				if ($line =~ /revert/)
				{
					$hardware_changed = 0;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "hardware_changed", value1 => $hardware_changed,
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					print $an->Web->template({file => "common.html", template => "shell-call-output", replace => { line => $line }});
				}
			}
			# This just puts a space under the output above.
			print $an->Web->template({file => "common.html", template => "shell-call-output", replace => { line => "&nbsp;" }});
			
			# Wipe and re-read the definition file's XML and reset the amount of RAM and the 
			# number of CPUs allocated to this machine.
			$an->data->{vm}{$vm}{xml}     = [];
			@{$an->data->{vm}{$vm}{xml}} = split/\n/, $new_definition;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "requested_ram",           value1 => $requested_ram,
				name2 => "vm::${vm}::details::ram", value2 => $an->data->{vm}{$vm}{details}{ram},
			}, file => $THIS_FILE, line => __LINE__});
			
			$an->data->{vm}{$vm}{details}{ram} = ($requested_ram * 1024);
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "vm::${vm}::details::ram", value1 => $an->data->{vm}{$vm}{details}{ram},
			}, file => $THIS_FILE, line => __LINE__});
			
			$an->data->{resources}{allocated_ram}    = $other_allocated_ram + ($requested_ram * 1024);
			$an->data->{vm}{$vm}{details}{cpu_count} = $requested_cpus;
		}
	}
	
	# Was there an error?
	if ($db_error)
	{
		print $an->Web->template({file => "server.html", template => "update-server-db-error", replace => { error => $db_error }});
	}
	
	# If the server is running, tell the user they need to power it off.
	if ($hardware_changed)
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "host", value1 => $an->data->{vm}{$vm}{current_host},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{vm}{$vm}{current_host})
		{
			print $an->Web->template({file => "server.html", template => "server-poweroff-required-message"});
		}
	}
	if ($database_changed)
	{
		if (not $hardware_changed)
		{
			# Tell the user that there were no hardware changes made so that we don't have an 
			# empty box.
			print $an->Web->template({file => "server.html", template => "server-updated-note-no-hardware-changed"});
		}
		print $an->Web->template({file => "server.html", template => "server-updated-note"});
	}
	
	# Did something change?
	if (($hardware_changed) or ($database_changed))
	{
		# Yup, we're good.
		print $an->Web->template({file => "server.html", template => "update-server-config-footer", replace => { url => "?cluster=".$an->data->{cgi}{cluster}."&vm=".$an->data->{cgi}{vm}."&task=manage_vm" }});
		
		AN::Cluster::footer($an);
		exit(0);
	}
	else
	{
		# Nothing changed.
		print $an->Web->template({file => "server.html", template => "no-change-message"});
	}
	
	return (0);
}

# This inserts an ISO into the server's virtual optical drive.
sub vm_insert_media
{
	my ($an, $node, $insert_media, $insert_drive, $vm_is_running) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "vm_insert_media" }, message_key => "an_variables_0004", message_variables => { 
		name1 => "node",          value1 => $node, 
		name2 => "insert_media",  value2 => $insert_media, 
		name3 => "insert_drive",  value3 => $insert_drive, 
		name4 => "vm_is_running", value4 => $vm_is_running, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $cluster         = $an->data->{cgi}{cluster};
	my $vm              = $an->data->{cgi}{vm};
	my $say_vm          = ($vm =~ /vm:(.*)/)[0];
	my $node1           = $an->data->{clusters}{$cluster}{nodes}[0];
	my $node2           = $an->data->{clusters}{$cluster}{nodes}[1];
	my $device          = $an->data->{cgi}{device};
	my $definition_file = "/shared/definitions/$say_vm.xml";

	# Archive the current config, just in case.
	my ($backup)   = archive_file($an, $node, $definition_file, 1);
	
	my $title = $an->String->get({key => "title_0030", variables => { 
		media	=>	$insert_media,
		drive	=>	$insert_drive,
	}});
	print $an->Web->template({file => "server.html", template => "insert-media-header", replace => { title => $title }});
	
	# How I do this depends on whether the VM is running or not.
	if ($vm_is_running)
	{
		# It is, so I will use 'virsh'.
		my $virsh_exit_code;
		my $shell_call = "/usr/bin/virsh change-media $say_vm $insert_drive --insert '/shared/files/$insert_media'; echo virsh:\$?";
		my $password   = $an->data->{sys}{root_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			next if not $line;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /virsh:(\d+)/)
			{
				$virsh_exit_code = $1;
			}
			else
			{
				print $an->Web->template({file => "common.html", template => "shell-call-output", replace => { line => $line }});
			}
		}
		if ($virsh_exit_code eq "1")
		{
			# Disk already inserted.
			print $an->Web->template({file => "server.html", template => "insert-media-failed-already-mounted"});

			# Update the definition file in case it was missed by .
			update_vm_definition($an, $node, $vm);
		}
		elsif ($virsh_exit_code eq "0")
		{
			print $an->Web->template({file => "server.html", template => "insert-media-success"});

			# Update the definition file.
			update_vm_definition($an, $node, $vm);
		}
		else
		{
			   $virsh_exit_code = "-" if not defined $virsh_exit_code;
			my $say_error       = $an->String->get({key => "message_0069", variables => { 
					media		=>	$insert_media,
					drive		=>	$insert_drive,
					virsh_exit_code	=>	$virsh_exit_code,
				}});
			print $an->Web->template({file => "server.html", template => "insert-media-failed-bad-exit-code", replace => { error => $say_error }});
		}
	}
	else
	{
		# The VM isn't running. Directly re-write the XML file. 
		my $message = $an->String->get({key => "message_0070", variables => { server => $say_vm }});
		print $an->Web->template({file => "server.html", template => "insert-media-server-off", replace => { message => $message }});
		my $new_definition = "";
		my $shell_call     = "cat $definition_file";
		my $password       = $an->data->{sys}{root_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
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
			
			if ($line =~ /dev='(.*?)'/)
			{
				my $this_device = $1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "Found the device", value1 => $this_device,
				}, file => $THIS_FILE, line => __LINE__});
				if ($this_device eq $insert_drive)
				{
					$new_definition .= "      <source file='/shared/files/$insert_media'/>\n";
				}
			}
			$new_definition .= "$line\n";
		}
		$new_definition =~ s/(\S)\s+$/$1\n/;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "new definition", value1 => $new_definition,
		}, file => $THIS_FILE, line => __LINE__});
		
		# See if I need to insert or edit any network interface driver elements.
		$new_definition = update_network_driver($an, $new_definition);
		
		# Write the new definition file.
		print $an->Web->template({file => "server.html", template => "saving-server-config"});
		$shell_call = "echo \"$new_definition\" > $definition_file && chmod 644 $definition_file";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
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
			
			print $an->Web->template({file => "common.html", template => "shell-call-output", replace => { line => $line }});
		}
		print $an->Web->template({file => "server.html", template => "insert-media-footer"});
		
		# Lastly, copy the new definition to the stored XML for
		# this VM.
		$an->data->{vm}{$vm}{xml}    = [];	# this is probably redundant
		@{$an->data->{vm}{$vm}{xml}} = split/\n/, $new_definition;
	}
	
	return(0);
}

# This ejects an ISO from a server's virtual optical drive.
sub vm_eject_media
{
	my ($an, $node, $vm_is_running) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "vm_eject_media" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node",          value1 => $node, 
		name2 => "vm_is_running", value2 => $vm_is_running, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $cluster         = $an->data->{cgi}{cluster};
	my $vm              = $an->data->{cgi}{vm};
	my $say_vm          = ($vm =~ /vm:(.*)/)[0];
	my $node1           = $an->data->{clusters}{$cluster}{nodes}[0];
	my $node2           = $an->data->{clusters}{$cluster}{nodes}[1];
	my $device          = $an->data->{cgi}{device};
	my $definition_file = "/shared/definitions/$say_vm.xml";
	
	my $title = $an->String->get({key => "title_0031", variables => { device => $an->data->{cgi}{device} }});
	print $an->Web->template({file => "server.html", template => "eject-media-header", replace => { title => $title }});
	
	# Archive the current config, just in case.
	my ($backup) = archive_file($an, $node, $definition_file, 1);
	my $drive    = $an->data->{cgi}{device};
	
	# How I do this depends on whether the VM is running or not.
	if ($vm_is_running)
	{
		# It is, so I will use 'virsh'.
		my $virsh_exit_code;
		my $shell_call = "/usr/bin/virsh change-media $say_vm $an->data->{cgi}{device} --eject; echo virsh:\$?";
		my $password   = $an->data->{sys}{root_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			next if not $line;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /virsh:(\d+)/)
			{
				$virsh_exit_code = $1;
			}
			else
			{
				print $an->Web->template({file => "common.html", template => "shell-call-output", replace => { line => $line }});
			}
		}
		if ($virsh_exit_code eq "1")
		{
			# Someone already ejected it.
			print $an->Web->template({file => "server.html", template => "eject-media-failed-already-ejected"});
			
			# Update the definition file in case it was missed by .
			update_vm_definition($an, $node, $vm);
		}
		elsif ($virsh_exit_code eq "0")
		{
			print $an->Web->template({file => "server.html", template => "eject-media-success"});
			
			# Update the definition file.
			update_vm_definition($an, $node, $vm);
		}
		else
		{
			   $virsh_exit_code = "-" if not defined $virsh_exit_code;
			my $say_error       = $an->String->get({key => "message_0073", variables => { 
					drive		=>	$drive,
					virsh_exit_code	=>	$virsh_exit_code,
				}});
			print $an->Web->template({file => "server.html", template => "eject-media-failed-bad-exit-code", replace => { error => $say_error }});
		}
	}
	else
	{
		# The VM isn't running. Directly re-write the XML file.
		my $message = $an->String->get({key => "message_0070", variables => { server => $say_vm }});
		print $an->Web->template({file => "server.html", template => "eject-media-server-off", replace => { message => $message }});
		my $in_cdrom       = 0;
		my $this_media     = "";
		my $this_device    = "";
		my $new_definition = "";
		my $shell_call     = "cat $definition_file";
		my $password       = $an->data->{sys}{root_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
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
			
			$new_definition .= "$line\n";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if (($line =~ /type='file'/) && ($line =~ /device='cdrom'/))
			{
				# Found an optical disk (DVD/CD).
				$an->Log->entry({log_level => 2, message_key => "log_0221", file => $THIS_FILE, line => __LINE__});
				$in_cdrom = 1;
			}
			if ($in_cdrom)
			{
				if ($line =~ /file='(.*?)'\/>/)
				{
					# Found media
					$this_media = $1;
					$an->Log->entry({log_level => 2, message_key => "log_0222", message_variables => {
						media => $this_media, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /dev='(.*?)'/)
				{
					# Found the device.
					$this_device = $1;
					$an->Log->entry({log_level => 2, message_key => "log_0223", message_variables => {
						device => $this_device, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /<\/disk>/)
				{
					# Check if this is what I want to eject.
					$an->Log->entry({log_level => 2, message_key => "log_0224", message_variables => {
						this_device   => $this_device, 
						target_device => $an->data->{cgi}{device}, 
					}, file => $THIS_FILE, line => __LINE__});
					if ($this_device eq $an->data->{cgi}{device})
					{
						# This is the device I want to unmount.
						$an->Log->entry({log_level => 2, message_key => "log_0225", file => $THIS_FILE, line => __LINE__});
						$new_definition =~ s/<disk(.*?)device='cdrom'(.*?)<source file='$this_media'\/>\s+(.*?)<\/disk>/<disk${1}device='cdrom'${2}${3}<\/disk>/s;
					}
					else
					{
						# It is not.
						$an->Log->entry({log_level => 2, message_key => "log_0226", file => $THIS_FILE, line => __LINE__});
					}
					$in_cdrom    = 0;
					$this_device = "";
					$this_media  = "";
				}
			}
		}
		$new_definition =~ s/(\S)\s+$/$1\n/;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "new_definition", value1 => $new_definition,
		}, file => $THIS_FILE, line => __LINE__});
		
		# See if I need to insert or edit any network interface driver elements.
		$new_definition = update_network_driver($an, $new_definition);
		
		# Write the new definition file.
		print $an->Web->template({file => "server.html", template => "saving-server-config"});
		$shell_call = "echo \"$new_definition\" > $definition_file && chmod 644 $definition_file";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
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
			
			print $an->Web->template({file => "common.html", template => "shell-call-output", replace => { line => $line }});
		}
		print $an->Web->template({file => "server.html", template => "eject-media-footer"});

		# Lastly, copy the new definition to the stored XML for
		# this VM.
		$an->data->{vm}{$vm}{xml}    = [];	# this is probably redundant
		@{$an->data->{vm}{$vm}{xml}} = split/\n/, $new_definition;
	}
	
	return(0);
}

# This shows or changes the configuration of the VM, including mounted media.
sub manage_vm
{
	my ($an) = @_;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "manage_vm" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# I need to get a list of the running VM's resource/media, read the VM's current XML if it's up, 
	# otherwise read the stored XML, read the available ISOs and then display everything in a form. If
	# the user submits the form and something is different, re-write the stored config and, if possible,
	# make the required changes immediately.
	my $cluster         = $an->data->{cgi}{cluster};
	my $vm              = $an->data->{cgi}{vm};
	my $say_vm          = ($vm =~ /vm:(.*)/)[0];
	my $node1           = $an->data->{clusters}{$cluster}{nodes}[0];
	my $node2           = $an->data->{clusters}{$cluster}{nodes}[1];
	my $device          = $an->data->{cgi}{device};
	my $definition_file = "/shared/definitions/$say_vm.xml";
	
	# First, see if the VM is up.
	AN::Cluster::scan_cluster($an);
	
	# Count how much RAM and CPU cores have been allocated.
	$an->data->{resources}{available_ram}   = 0;
	$an->data->{resources}{max_cpu_cores}   = 0;
	$an->data->{resources}{allocated_cores} = 0;
	$an->data->{resources}{allocated_ram}   = 0;
	foreach my $vm (sort {$a cmp $b} keys %{$an->data->{vm}})
	{
		next if $vm !~ /^vm/;
		# I check GFS2 because, without it, I can't read the VM's details.
		if ($an->data->{sys}{gfs2_down})
		{
			$an->data->{resources}{allocated_ram}   = "--";
			$an->data->{resources}{allocated_cores} = "--";
		}
		else
		{
			$an->data->{resources}{allocated_ram}   += $an->data->{vm}{$vm}{details}{ram};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "allocated_ram", value1 => $an->data->{resources}{allocated_ram},
				name2 => "vm",            value2 => $vm,
				name3 => "ram",           value3 => $an->data->{vm}{$vm}{details}{ram},
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{resources}{allocated_cores} += $an->data->{vm}{$vm}{details}{cpu_count};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "allocated_cores", value1 => $an->data->{resources}{allocated_cores},
				name2 => "vm",              value2 => $vm,
				name3 => "cpu_count",       value3 => $an->data->{vm}{$vm}{details}{cpu_count},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# First up, if the cluster is not running, go no further.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node1}::daemon::gfs2::exit_code", value1 => $an->data->{node}{$node1}{daemon}{gfs2}{exit_code},
		name2 => "node::${node2}::daemon::gfs2::exit_code", value2 => $an->data->{node}{$node2}{daemon}{gfs2}{exit_code},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node1}{daemon}{gfs2}{exit_code}) && ($an->data->{node}{$node2}{daemon}{gfs2}{exit_code}))
	{
		print $an->Web->template({file => "server.html", template => "storage-not-ready"});
	}
	
	# Now choose the node to work through.
	my $node          = "";
	my $vm_is_running = 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "vm::${vm}::current_host", value1 => $an->data->{vm}{$vm}{current_host},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{vm}{$vm}{current_host})
	{
		# Read the current VM config from virsh.
		$vm_is_running = 1;
		$node          = $an->data->{vm}{$vm}{current_host};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "vm",                         value1 => $vm,
			name2 => "node",                       value2 => $node,
			name3 => "vm::${vm}::definition_file", value3 => $an->data->{vm}{$vm}{definition_file},
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# The VM isn't running.
		if ($an->data->{node}{$node1}{daemon}{gfs2}{exit_code} eq "0")
		{
			# Node 1 is up.
			$node = $node1;
		}
		else
		{
			# Node 2 must be up.
			$node = $node2;
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "vm",                         value1 => $vm,
			name2 => "vm::${vm}::definition_file", value2 => $an->data->{vm}{$vm}{definition_file},
			name3 => "node",                       value3 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		read_vm_definition($an, $node, $vm);
	}
	
	# Find the list of bootable devices and present them in a selection box. Also pull out the server's
	# UUID.
	my $boot_select = "<select name=\"boot_device\" style=\"width: 165px;\">";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "boot select", value1 => $boot_select,
	}, file => $THIS_FILE, line => __LINE__});
	   $an->data->{vm}{$vm}{current_boot_device}    = "";
	   $an->data->{vm}{$vm}{available_boot_devices} = "";
	my $say_current_boot_device                 = "";
	my $in_os                                   = 0;
	my $saw_cdrom                               = 0;
	my $server_uuid                             = "";
	foreach my $line (@{$an->data->{vm}{$vm}{xml}})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "in_os", value1 => $in_os,
			name2 => "vm",    value2 => $vm,
			name3 => "line",  value3 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		last if $line =~ /<\/domain>/;
		
		if ($line =~ /<uuid>([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})<\/uuid>/)
		{
			$server_uuid = $1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "server_uuid", value1 => $server_uuid, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /<os>/)
		{
			$in_os = 1;
			next;
		}
		if ($in_os == 1)
		{
			if ($line =~ /<\/os>/)
			{
				$in_os = 0;
				if ($saw_cdrom)
				{
					last;
				}
				else
				{
					# I didn't see a CD-ROM boot option, so keep looking.
					$in_os = 2;
				}
			}
			elsif ($line =~ /<boot dev='(.*?)'/)
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "vm",   value1 => $vm,
					name2 => "line", value2 => $line,
				}, file => $THIS_FILE, line => __LINE__});
				my $device                               =  $1;
				my $say_device                           =  $device;
				$an->data->{vm}{$vm}{available_boot_devices} .= "$device,";
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
				if (not $an->data->{vm}{$vm}{current_boot_device})
				{
					$an->data->{vm}{$vm}{current_boot_device} = $device;
					$say_current_boot_device = $say_device;
					$selected = "selected";
				}
				
				$boot_select .= "<option value=\"$device\" $selected>$say_device</option>";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "boot select", value1 => $boot_select,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		elsif ($in_os == 2)
		{
			# I'm out of the OS block, but I haven't seen a CD-ROM yet, so keep looping and 
			# looking for one.
			if ($line =~ /<disk .*?device='cdrom'/)
			{
				# There is a CD-ROM, add it as a boot option.
				my $say_device  =  "#!string!device_0002!#";
				   $boot_select .= "<option value=\"cdrom\">$say_device</option>";
				   $in_os = 0;
				last;
			}
		}
	}
	$boot_select .= "</select>";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "boot_select", value1 => $boot_select,
	}, file => $THIS_FILE, line => __LINE__});
	
	# See if I have access to ScanCore and, if so, check for a note, the start after, start delay, 
	# migration type and pre/post migration scripts/args. If we have a database connection, show these 
	# options.
	my $show_db_options                 = 0;
	my $server_note                     = "";
	my $modified_date                   = "";
	my $server_start_after              = "";
	my $server_start_delay              = "";
	my $server_migration_type           = "";
	my $server_pre_migration_script     = "";
	my $server_pre_migration_arguments  = "";
	my $server_post_migration_script    = "";
	my $server_post_migration_arguments = "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "server_uuid",         value1 => $server_uuid, 
		name2 => "sys::db_connections", value2 => $an->data->{sys}{db_connections}, 
	}, file => $THIS_FILE, line => __LINE__});
	if (($server_uuid) && ($an->data->{sys}{db_connections}))
	{
		# Connection! Show the DB options.
		$show_db_options = 1;
		
		# Get the current DB data.
		my $results = $an->Get->server_data({
			uuid   => $server_uuid, 
			server => $vm,
			anvil  => $cluster, 
		});
		$server_note                     = $results->{note};
		$server_start_after              = $results->{start_after};
		$server_start_delay              = $results->{start_delay};
		$server_migration_type           = $results->{migration_type};
		$server_pre_migration_script     = $results->{pre_migration_script};
		$server_pre_migration_arguments  = $results->{pre_migration_arguments};
		$server_post_migration_script    = $results->{post_migration_script};
		$server_post_migration_arguments = $results->{post_migration_arguments};
		$modified_date                   = $results->{modified_date};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0010", message_variables => {
			name1  => "show_db_options",                 value1  => $show_db_options, 
			name2  => "server_note",                     value2  => $server_note, 
			name3  => "server_start_after",              value3  => $server_start_after, 
			name4  => "server_start_delay",              value4  => $server_start_delay, 
			name5  => "server_migration_type",           value5  => $server_migration_type, 
			name6  => "server_pre_migration_script",     value6  => $server_pre_migration_script, 
			name7  => "server_pre_migration_arguments",  value7  => $server_pre_migration_arguments, 
			name8  => "server_post_migration_script",    value8  => $server_post_migration_script, 
			name9  => "server_post_migration_arguments", value9  => $server_post_migration_arguments, 
			name10 => "modified_date",                   value10 => $modified_date, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# If the database is up, but we didn't get a result, the modified_date won't be set.
		if (not $modified_date)
		{
			$show_db_options = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "show_db_options", value1 => $show_db_options, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "show_db_options", value1 => $show_db_options
	}, file => $THIS_FILE, line => __LINE__});
	
	# If I need to change the number of CPUs or the amount of RAM, do so now.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::change", value1 => $an->data->{cgi}{change},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{cgi}{change})
	{
		change_vm($an, $node);
	}
	
	# If I've been asked to insert a disc, do so now.
	my $do_insert    = 0;
	my $insert_media = "";
	my $insert_drive = "";
	foreach my $key (split/,/, $an->data->{cgi}{device_keys})
	{
		next if not $key;
		next if not $an->data->{cgi}{$key};
		my $device_key = $key;
		$insert_drive  = ($key =~ /media_(.*)/)[0];
		my $insert_key = "insert_${insert_drive}";
		if ($an->data->{cgi}{$insert_key})
		{
			$do_insert    = 1;
			$insert_media = $an->data->{cgi}{$device_key};
		}
	}
	
	### TODO: Merge insert and eject into one function.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "do_insert",    value1 => $do_insert,
		name2 => "insert_drive", value2 => $insert_drive,
		name3 => "insert_media", value3 => $insert_media,
	}, file => $THIS_FILE, line => __LINE__});
	if ($do_insert)
	{
		vm_insert_media($an, $node, $insert_media, $insert_drive, $vm_is_running);
	}
	
	# If I've been asked to eject a disc, do so now.
	if ($an->data->{cgi}{'do'} eq "eject")
	{
		vm_eject_media($an, $node, $vm_is_running);
	}
	
	# Get the list of files on the /shared/files/ directory.
	my $shell_call = "df -P && ls -l /shared/files/";
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /\s(\d+)-blocks\s/)
		{
			$an->data->{partition}{shared}{block_size} = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "block_size", value1 => $an->data->{partition}{shared}{block_size},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /^\/.*?\s+(\d+)\s+(\d+)\s+(\d+)\s(\d+)%\s+\/shared/)
		{
			$an->data->{partition}{shared}{total_space}  = $1;
			$an->data->{partition}{shared}{used_space}   = $2;
			$an->data->{partition}{shared}{free_space}   = $3;
			$an->data->{partition}{shared}{used_percent} = $4;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
				name1 => "partition::shared::total_space",  value1 => $an->data->{partition}{shared}{total_space},
				name2 => "partition::shared::used_space",   value2 => $an->data->{partition}{shared}{used_space},
				name3 => "partition::shared::used_percent". value3 => $an->data->{partition}{shared}{used_percent},
				name4 => "partition::shared::free_space",   value4 => $an->data->{partition}{shared}{free_space},
			}, file => $THIS_FILE, line => __LINE__});
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
			$an->data->{files}{shared}{$file}{type}   = $type;
			$an->data->{files}{shared}{$file}{mode}   = $mode;
			$an->data->{files}{shared}{$file}{user}   = $user;
			$an->data->{files}{shared}{$file}{group}  = $group;
			$an->data->{files}{shared}{$file}{size}   = $size;
			$an->data->{files}{shared}{$file}{month}  = $month;
			$an->data->{files}{shared}{$file}{day}    = $day;
			$an->data->{files}{shared}{$file}{'time'} = $time; # might be a year, look for '\d+:\d+'.
			$an->data->{files}{shared}{$file}{target} = $target;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0010", message_variables => {
				name1  => "file",                             value1  => $file,
				name2  => "files::shared::${file}::type",     value2  => $an->data->{files}{shared}{$file}{type},
				name3  => "files::shared::${file}::mode",     value3  => $an->data->{files}{shared}{$file}{mode},
				name4  => "files::shared::${file}::owner",    value4  => $an->data->{files}{shared}{$file}{user},
				name5  => "files::shared::${file}::group",    value5  => $an->data->{files}{shared}{$file}{group},
				name6  => "files::shared::${file}::size",     value6  => $an->data->{files}{shared}{$file}{size},
				name7  => "files::shared::${file}::modified", value7  => $an->data->{files}{shared}{$file}{month},
				name8  => "files::shared::${file}::day",      value8  => $an->data->{files}{shared}{$file}{day},
				name9  => "files::shared::${file}::time",     value9  => $an->data->{files}{shared}{$file}{'time'},
				name10 => "files::shared::${file}::target",   value10 => $an->data->{files}{shared}{$file}{target},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Find which ISOs are mounted currently.
	my $this_device = "";
	my $this_media  = "";
	my $in_cdrom    = 0;
	### TODO: Find out why the XML data is doubled up.
	foreach my $line (@{$an->data->{vm}{$vm}{xml}})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "vm",   value1 => $vm,
			name2 => "line", value2 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		last if $line =~ /<\/domain>/;
		if ($line =~ /device='cdrom'/)
		{
			$in_cdrom = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "vm",       value1 => $vm,
				name2 => "in_cdrom", value2 => $in_cdrom,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (($line =~ /<\/disk>/) && ($in_cdrom))
		{
			# Record what I found/
			$an->data->{vm}{$vm}{cdrom}{$this_device}{media} = $this_media ? $this_media : "";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "vm::${vm}::cdrom::${this_device}::media", value1 => $an->data->{vm}{$vm}{cdrom}{$this_device}{media},
			}, file => $THIS_FILE, line => __LINE__});
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

	my $current_cpu_count = $an->data->{vm}{$vm}{details}{cpu_count};
	my $max_cpu_count     = $an->data->{resources}{total_threads};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "current_cpu_count", value1 => $current_cpu_count,
		name2 => "max_cpu_count",     value2 => $max_cpu_count,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Create the media select boxes.
	foreach my $device (sort {$a cmp $b} keys %{$an->data->{vm}{$vm}{cdrom}})
	{
		my $key                                 =  "media_$device";
		   $an->data->{vm}{$vm}{cdrom}{device_keys} .= "$key,";
		if ($an->data->{vm}{$vm}{cdrom}{$device}{media})
		{
			### TODO: If the media no longer exists, re-write the XML definition immediately.
			# Offer the eject button.
			$an->data->{vm}{$vm}{cdrom}{$device}{say_select}   = "<select name=\"$key\" disabled>\n";
			$an->data->{vm}{$vm}{cdrom}{$device}{say_in_drive} = "<span class=\"fixed_width\">".$an->data->{vm}{$vm}{cdrom}{$device}{media}."</span>\n";
			$an->data->{vm}{$vm}{cdrom}{$device}{say_eject}    = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
					button_class	=>	"bold_button",
					button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&vm=".$an->data->{cgi}{vm}."&task=manage_vm&do=eject&device=$device",
					button_text	=>	"#!string!button_0017!#",
					id		=>	"eject_$device",
				}});
			my $say_insert_disabled_button                  = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0018!#" }});
			   $an->data->{vm}{$vm}{cdrom}{$device}{say_insert} = "$say_insert_disabled_button\n";
		}
		else
		{
			# Offer the insert button
			   $an->data->{vm}{$vm}{cdrom}{$device}{say_select}   = "<select name=\"$key\">\n";
			   $an->data->{vm}{$vm}{cdrom}{$device}{say_in_drive} = "<span class=\"highlight_unavailable\">(#!string!state_0007!#)</span>\n";
			my $say_eject_disabled_button                     = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0017!#" }});
			   $an->data->{vm}{$vm}{cdrom}{$device}{say_eject}    = "$say_eject_disabled_button\n";
			   $an->data->{vm}{$vm}{cdrom}{$device}{say_insert}   = $an->Web->template({file => "common.html", template => "form-input", replace => { 
					type	=>	"submit",
					name	=>	"insert_$device",
					id	=>	"insert_$device",
					value	=>	"#!string!button_0018!#",
					class	=>	"bold_button",
				}});
		}
		foreach my $file (sort {$a cmp $b} keys %{$an->data->{files}{shared}})
		{
			next if ($file eq $an->data->{vm}{$vm}{cdrom}{$device}{media});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "file",        value1 => $file,
				name2 => "cgi::${key}", value2 => $an->data->{cgi}{$key},
			}, file => $THIS_FILE, line => __LINE__});
			if ((defined $an->data->{cgi}{$key}) && ($file eq $an->data->{cgi}{$key}))
			{
				$an->data->{vm}{$vm}{cdrom}{$device}{say_select} .= "<option name=\"$file\" selected>$file</option>\n";
			}
			else
			{
				$an->data->{vm}{$vm}{cdrom}{$device}{say_select} .= "<option name=\"$file\">$file</option>\n";
			}
		}
		$an->data->{vm}{$vm}{cdrom}{$device}{say_select} .= "</select>\n";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "device",                                  value1 => $device,
			name2 => "vm::${vm}::cdrom::${device}::media",      value2 => $an->data->{vm}{$vm}{cdrom}{$device}{media},
			name3 => "vm::${vm}::cdrom::${device}::say_select", value3 => $an->data->{vm}{$vm}{cdrom}{$device}{say_select},
		}, file => $THIS_FILE, line => __LINE__});
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
	$an->data->{cgi}{cpu_cores} = $current_cpu_count if not $an->data->{cgi}{cpu_cores};
	my $select_cpu_cores    = AN::Cluster::build_select($an, "cpu_cores", 0, 0, 60, $an->data->{cgi}{cpu_cores}, $cpu_cores);
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "select_cpu_cores", value1 => $select_cpu_cores,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Something has changed. Make sure the request is sane,
	my $current_ram   = $an->data->{vm}{$vm}{details}{ram};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "current_ram", value1 => $current_ram,
	}, file => $THIS_FILE, line => __LINE__});

	my $diff          = $an->data->{resources}{total_ram} % (1024 ** 3);
	my $available_ram = ($an->data->{resources}{total_ram} - $diff - $an->data->{sys}{unusable_ram} - $an->data->{resources}{allocated_ram}) + $current_ram;
	my $max_ram       = $available_ram;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "available_ram", value1 => $available_ram,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If the user sets the RAM to less than 1 GiB, warn them. If the user sets the RAM to less that 32 
	# MiB, error out.
	my $say_max_ram          = $an->Readable->bytes_to_hr({'bytes' => $max_ram });
	my $say_current_ram      = $an->Readable->bytes_to_hr({'bytes' => $current_ram });
	my ($current_ram_value, $current_ram_suffix) = (split/ /, $say_current_ram);
	$an->data->{cgi}{ram}        = $current_ram_value if not $an->data->{cgi}{ram};
	$an->data->{cgi}{ram_suffix} = $current_ram_suffix if not $an->data->{cgi}{ram_suffix};
	my $select_ram_suffix    = AN::Cluster::build_select($an, "ram_suffix", 0, 0, 60, $an->data->{cgi}{ram_suffix}, ["MiB", "GiB"]);
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "say_max_ram",       value1 => $say_max_ram,
		name2 => "cgi::ram",          value2 => $an->data->{cgi}{ram},
		name3 => "select_ram_suffix", value3 => $select_ram_suffix,
	}, file => $THIS_FILE, line => __LINE__});
	
	### Disabled now.
	# Setup Guacamole, if installed.
	my $message     = "";
	my $remote_icon = "";
	
	# Finally, print it all
	my $title = $an->String->get({key => "title_0032", variables => { server => $say_vm }});
	print $an->Web->template({file => "server.html", template => "manager-server-header", replace => { title => $title }});

	my $i = 1;
	foreach my $device (sort {$a cmp $b} keys %{$an->data->{vm}{$vm}{cdrom}})
	{
		next if $device eq "device_keys";
		my $say_disk   = $an->data->{vm}{$vm}{cdrom}{$device}{say_select};
		my $say_button = $an->data->{vm}{$vm}{cdrom}{$device}{say_insert};
		my $say_state  = "#!string!state_0124!#";
		if ($an->data->{vm}{$vm}{cdrom}{$device}{media})
		{
			$say_disk   = $an->data->{vm}{$vm}{cdrom}{$device}{say_in_drive};
			$say_button = $an->data->{vm}{$vm}{cdrom}{$device}{say_eject};
			$say_state  = "#!string!state_0125!#";
		}
		my $say_optical_drive = $an->String->get({key => "device_0003", variables => { drive_number => $i }});
		print $an->Web->template({file => "server.html", template => "manager-server-optical-drive", replace => { 
				optical_drive	=>	$say_optical_drive,
				'state'		=>	$say_state,
				disk		=>	$say_disk,
				button		=>	$say_button,
			}});
		$i++;
	}
	
	# If we can show the note, do so
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "show_db_options", value1 => $show_db_options,
	}, file => $THIS_FILE, line => __LINE__});
	my $note_form = "";
	if ($show_db_options)
	{
		### TODO: If there is only one server, present an option to "Always Boot", "Never Boot" and 
		###       "Last State" to inform anvil-safe-start as to what to do when it runs.
		my $return = $an->Get->server_data({
			server => $say_vm, 
			anvil  => $cluster, 
		});
		if (not $an->data->{cgi}{server_start_after})
		{
			$an->data->{cgi}{server_start_after} = $return->{start_after};
		}
		
		# These will become the select boxes
		my $say_boot_delay_disabled          = "disabled";
		my $say_boot_after_select            = "#!string!message_0308!#";
		my $say_migration_type_select        = "--";
		my $say_pre_migration_script_select  = "--";
		my $say_post_migration_script_select = "--";
		
		# Now get the information to build the "Boot After" select.
		my $other_servers = [];
		my $server_uuid   = $return->{uuid};
		my $query         = "
SELECT 
    server_name, 
    server_uuid 
FROM 
    servers 
WHERE 
    server_uuid !=  ".$an->data->{sys}{use_db_fh}->quote($server_uuid)." 
AND 
    server_name != 'DELETED'
ORDER BY 
    server_name ASC
;";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "query", value1 => $query, 
		}, file => $THIS_FILE, line => __LINE__});
		
		my $results = $an->DB->do_db_query({query => $query, source => $THIS_FILE, line => __LINE__});
		my $count   = @{$results};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "results", value1 => $results, 
			name2 => "count",   value2 => $count
		}, file => $THIS_FILE, line => __LINE__});
		if ($count)
		{
			# At least one other server exists.
			foreach my $row (@{$results})
			{
				my $server_name = $row->[0];
				my $server_uuid = $row->[1];
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "server_name", value1 => $server_name, 
					name2 => "server_uuid", value2 => $server_uuid, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# Make sure this is a server on this Anvil!
				foreach my $vm (sort {$a cmp $b} keys %{$an->data->{vm}})
				{
					next if $vm !~ /^vm/;
					my $say_vm  =  ($vm =~ /^vm:(.*)/)[0];
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "server_name", value1 => $server_name, 
						name2 => "say_vm",      value2 => $say_vm, 
					}, file => $THIS_FILE, line => __LINE__});
					if ($server_name eq $say_vm)
					{
						push @{$other_servers}, "$server_uuid#!#$server_name";
					}
				}
			}
			
			# Add the 'Don't Boot' option
			my $say_dont_boot = $an->String->get({key => "title_0105"});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "say_dont_boot", value1 => $say_dont_boot,
			}, file => $THIS_FILE, line => __LINE__});
			push @{$other_servers}, "00000000-0000-0000-0000-000000000000#!#<i>$say_dont_boot</i>";
			
			# Build the Start After select
			$say_boot_after_select   = AN::Cluster::build_select($an, "server_start_after", 0, 1, 150, $an->data->{cgi}{server_start_after}, $other_servers);
			$say_boot_delay_disabled = "";
		}
		
		### Now build the rest of the selects.
		# If the user didn't click save, load the DB values.
		if (not $an->data->{cgi}{change})
		{
			if (not $an->data->{cgi}{server_migration_type})
			{
				$an->data->{cgi}{server_migration_type} = $server_migration_type;
			}
			if (not $an->data->{cgi}{server_pre_migration_script})
			{
				$an->data->{cgi}{server_pre_migration_script} = $server_pre_migration_script;
			}
			if (($an->data->{cgi}{server_pre_migration_script}) && (not $an->data->{cgi}{server_pre_migration_arguments}))
			{
				$an->data->{cgi}{server_pre_migration_arguments} = $server_pre_migration_arguments;
			}
			else
			{
				# No script, so clear args.
				$an->data->{cgi}{server_pre_migration_arguments} = "";
			}
			if (not $an->data->{cgi}{server_post_migration_script})
			{
				$an->data->{cgi}{server_post_migration_script} = $server_post_migration_script;
			}
			if (($an->data->{cgi}{server_post_migration_script}) && (not $an->data->{cgi}{server_post_migration_arguments}))
			{
				$an->data->{cgi}{server_post_migration_arguments} = $server_post_migration_arguments;
			}
			else
			{
				# No script, so clear args.
				$an->data->{cgi}{server_post_migration_arguments} = "";
			}
		}
		
		# Migration type
		$say_migration_type_select = AN::Cluster::build_select($an, "server_migration_type", 0, 0, 150, $an->data->{cgi}{server_migration_type}, ["live#!##!string!state_0126!#", "cold#!##!string!state_0127!#"]);;
		
		# Get a list of files from /shared/files that are not ISOs and have their 'executable' bit 
		# set.
		my $password = $an->data->{sys}{root_password};
		my $node     = $an->data->{sys}{use_node};
		my $port     = $an->data->{node}{$node}{port};
		my $scripts  = [];
		my ($files, $partition) = $an->Get->shared_files({
			password	=>	$password,
			port		=>	$port,
			target		=>	$node,
		});
		foreach my $file (sort {$a cmp $b} keys %{$files})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "${file}::executable", value1 => $files->{$file}{executable},
			}, file => $THIS_FILE, line => __LINE__});
			if ($files->{$file}{executable})
			{
				push @{$scripts}, $file;
			}
		}
		
		# Build the Pre and Post migration script selection boxes.
		$say_pre_migration_script_select  = AN::Cluster::build_select($an, "server_pre_migration_script", 0, 1, 150, $an->data->{cgi}{server_pre_migration_script}, $scripts);;
		$say_post_migration_script_select = AN::Cluster::build_select($an, "server_post_migration_script", 0, 1, 150, $an->data->{cgi}{server_post_migration_script}, $scripts);;
		
		# Take the fractional component of the second off the modified date stamp.
		$modified_date =~ s/\..*//;
		$note_form     =  $an->Web->template({file => "server.html", template => "start-server-show-db-options", replace => { 
				server_note			=>	$server_note,
				server_start_after		=>	$say_boot_after_select,
				server_start_delay		=>	$server_start_delay,
				server_start_delay_disabled	=>	$say_boot_delay_disabled, 
				server_migration_type		=>	$say_migration_type_select,
				server_pre_migration_script	=>	$say_pre_migration_script_select, 
				server_pre_migration_arguments	=>	$an->data->{cgi}{server_pre_migration_arguments}, 
				server_post_migration_script	=>	$say_post_migration_script_select, 
				server_post_migration_arguments	=>	$an->data->{cgi}{server_post_migration_arguments}, 
				modified_date			=>	$modified_date,
			}});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "note_form", value1 => $note_form,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	my $current_boot_device = $an->String->get({key => "message_0081", variables => { boot_device => $say_current_boot_device }});
	my $cpu_details         = $an->String->get({key => "message_0083", variables => { current_cpus => $an->data->{vm}{$vm}{details}{cpu_count} }});
	my $restart_tomcat      = $an->String->get({key => "message_0085", variables => { reset_tomcat_url => "?cluster=".$an->data->{cgi}{cluster}."&task=restart_tomcat" }});
	my $ram_details         = $an->String->get({key => "message_0082", variables => { 
			current_ram	=>	$say_current_ram,
			maximum_ram	=>	$say_max_ram,
		}});

	# Display all this wonderful data.
	print $an->Web->template({file => "server.html", template => "manager-server-show-details", replace => { 
			current_boot_device	=>	$current_boot_device,
			boot_select		=>	$boot_select,
			ram_details		=>	$ram_details,
			ram			=>	$an->data->{cgi}{ram},
			select_ram_suffix	=>	$select_ram_suffix,
			cpu_details		=>	$cpu_details,
			select_cpu_cores	=>	$select_cpu_cores,
			remote_icon		=>	$remote_icon,
			message			=>	$message,
			server_note		=>	$note_form, 
			restart_tomcat		=>	$restart_tomcat,
			anvil			=>	$an->data->{cgi}{cluster},
			server			=>	$an->data->{cgi}{vm},
			task			=>	$an->data->{cgi}{task},
			device_keys		=>	$an->data->{vm}{$vm}{cdrom}{device_keys},
			rowspan			=>	$show_db_options ? 10 : 5,
		}});
	
	return (0);
}

# This calls 'virsh dumpxml' against the given VM.
sub update_vm_definition
{
	my ($an, $node, $vm) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "update_vm_definition" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node", value1 => $node, 
		name2 => "vm",   value2 => $vm, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $say_vm = $vm;
	if ($vm =~ /^vm:(.*)/)
	{
		$say_vm = $1;
	}
	else
	{
		$vm = "vm:$vm";
	}
	my $definition_file = $an->data->{vm}{$vm}{definition_file};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "in update_vm_definition(); node", value1 => $node,
		name2 => "vm",                              value2 => $vm,
		name3 => "say_vm",                          value3 => $say_vm,
		name4 => "definition_file",                 value4 => $definition_file,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $new_definition = "";
	my $shell_call     = "/usr/bin/virsh dumpxml $say_vm";
	my $password       = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$new_definition .= "$line\n";
	}
	
	# See if I need to insert or edit any network interface driver elements.
	$new_definition = update_network_driver($an, $new_definition);
	
	# Die if the definition_file data is an array because wtf.
	die if $new_definition =~ /ARRAY/;
	
	# Write out the new one.
	$shell_call = "cat > $definition_file << EOF\n$new_definition\nEOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
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
	}
	
	# Rebuild the $an->data->{vm}{$vm}{xml} array.
	undef $an->data->{vm}{$vm}{xml};
	$an->data->{vm}{$vm}{xml} = [];
	foreach my $line (split/\n/, $new_definition)
	{
		push @{$an->data->{vm}{$vm}{xml}}, $line;
	}
	
	return(0);
}

sub add_vm_to_cluster
{
	my ($an, $skip_scan) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "add_vm_to_cluster" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "skip_scan", value1 => $skip_scan, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If this is being called after provisioning a VM, we'll skip scanning the cluster and we'll not 
	# print the opening header. 
	
	# Two steps needed; Dump the definition and use ccs to add it to the cluster.
	my $cluster    = $an->data->{cgi}{cluster};
	my $vm         = $an->data->{cgi}{name};
	#my $node       = $an->data->{cgi}{node};
	my $node       = $an->data->{new_vm}{host_node} ? $an->data->{new_vm}{host_node} : $an->data->{cgi}{node};
	my $host_node  = $an->data->{new_vm}{host_node};
	my $definition = "/shared/definitions/$vm.xml";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "cluster",    value1 => $cluster,
		name2 => "host_node",  value2 => $host_node,
		name3 => "node",       value3 => $node,
		name4 => "definition", value4 => $definition,
	}, file => $THIS_FILE, line => __LINE__});
	my $peer;
	foreach my $this_node (@{$an->data->{clusters}{$cluster}{nodes}})
	{
		if ($this_node ne $node)
		{
			$peer = $this_node;
			$node = $this_node if not $node;
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node", value1 => $node,
		name2 => "peer", value2 => $peer,
	}, file => $THIS_FILE, line => __LINE__});
	
	# First, find the failover domain...
	my $failover_domain;
	$an->data->{sys}{ignore_missing_vm} = 1;
	
	if ($skip_scan)
	{
		# Table is open.
	}
	else
	{
		AN::Cluster::scan_cluster($an);
		$an->Log->entry({log_level => 2, message_key => "log_0231", file => $THIS_FILE, line => __LINE__});
		print $an->Web->template({file => "server.html", template => "add-server-to-anvil-header"});
	}
	
	# Find the failover domain.
	foreach my $fod (keys %{$an->data->{failoverdomain}})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "fod", value1 => $fod,
		}, file => $THIS_FILE, line => __LINE__});
		if ($fod =~ /primary_(.*?)$/)
		{
			my $node_suffix = $1;
			my $alt_suffix  = (($node_suffix eq "n01") || ($node_suffix eq "n1")) ? "node01" : "node02";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "node_suffix", value1 => $node_suffix,
				name2 => "alt_suffix",  value2 => $alt_suffix,
			}, file => $THIS_FILE, line => __LINE__});
			
			# If the user has named their nodes 'nX' or 'nodeX',
			# the 'n0X'/'node0X' won't match, so we fudge it here.
			my $say_node = $node;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "say_node", value1 => $say_node,
			}, file => $THIS_FILE, line => __LINE__});
			if (($node !~ /node0\d/) && ($node !~ /n0\d/))
			{
				if ($node =~ /node(\d)/)
				{
					my $integer = $1;
					$say_node = "node0".$integer;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "say_node", value1 => $say_node,
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($node =~ /n(\d)/)
				{
					my $integer = $1;
					$say_node = "n0".$integer;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "say_node", value1 => $say_node,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
				name1 => "node",        value1 => $node,
				name2 => "say_node",    value2 => $say_node,
				name3 => "node_suffix", value3 => $node_suffix,
				name4 => "alt_suffix",  value4 => $alt_suffix,
			}, file => $THIS_FILE, line => __LINE__});
			if (($say_node =~ /$node_suffix/) || ($say_node =~ /$alt_suffix/))
			{
				$failover_domain = $fod;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "failover_domain", value1 => $failover_domain,
				}, file => $THIS_FILE, line => __LINE__});
				last;
			}
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "Using failover domain", value1 => $failover_domain,
	}, file => $THIS_FILE, line => __LINE__});
	
	# How I print the next message depends on whether I'm doing a 
	# stand-alone addition or on the heels of a new provisioning.
	if ($skip_scan)
	{
		# Running on the heels of a server provision, so the table is already opened.
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
				row	=>	"#!string!row_0281!#",
				message	=>	"#!string!message_0090!#",
			}});
		my $message = $an->String->get({key => "title_0033", variables => { 
				server		=>	$vm,
				failover_domain	=>	$failover_domain,
			}});
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
				row	=>	"#!string!row_0092!#",
				message	=>	$message,
			}});
	}
	else
	{
		# Doing a stand-alone addition of a server to the Anvil!, so we need a title.
		my $title = $an->String->get({key => "title_0033", variables => { 
			server		=>	$vm,
			failover_domain	=>	$failover_domain,
		}});
		print $an->Web->template({file => "server.html", template => "add-server-to-anvil-header-detail", replace => { title => $title }});
	}
	
	# If there is no password set, abort.
	if (not $an->data->{clusters}{$cluster}{ricci_pw})
	{
		# No ricci user, so we can't add it. Tell the user and give 
		# them a link to the config for this Anvil!.
		print $an->Web->template({file => "server.html", template => "general-error-message", replace => { 
			row	=>	"#!string!row_0090!#",
			message	=>	$an->String->get({key => "message_0087", variables => { server => $vm }}),
		}});
		print $an->Web->template({file => "server.html", template => "general-error-message", replace => { 
			row	=>	"#!string!row_0091!#",
			message	=>	$an->String->get({key => "message_0088", variables => { manage_url => "?config=true&anvil=$cluster" }}),
		}});
		return(1);
	}

	if (not $failover_domain)
	{
		# No failover domain found
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
			row	=>	"#!string!row_0096!#",
			message	=>	"#!string!message_0089!#",
		}});
		return (1);
	}
	
	### Lets get started!
	# On occasion, the installed VM will power off, not reboot. So this checks to see if the VM needs to
	# be kicked awake.
	my ($host) = find_vm_host($an, $node, $peer, $vm);
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "vm",   value1 => $vm,
		name2 => "host", value2 => $host,
	}, file => $THIS_FILE, line => __LINE__});
	if ($host eq "none")
	{
		# Server isn't running yet.
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
				row	=>	"#!string!row_0280!#",
				message	=>	"#!string!message_0091!#",
			}});
		$an->Log->entry({log_level => 2, message_key => "log_0232", message_variables => { server => $vm }, file => $THIS_FILE, line => __LINE__});
		my $virsh_exit_code;
		my $shell_call = "/usr/bin/virsh start $vm; echo virsh:\$?";
		my $password   = $an->data->{sys}{root_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			next if not $line;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /virsh:(\d+)/)
			{
				$virsh_exit_code = $1;
			}
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "virsh exit code", value1 => $virsh_exit_code,
		}, file => $THIS_FILE, line => __LINE__});
		if ($virsh_exit_code eq "0")
		{
			# Server has booted.
			print $an->Web->template({file => "server.html", template => "general-message", replace => { 
				row	=>	"&nbsp;",
				message	=>	"#!string!message_0092!#",
			}});
		}
		else
		{
			# If something undefined the VM already and the server is not running, this will 
			# fail. Try to start the server using the definition file before giving up.
			print $an->Web->template({file => "server.html", template => "general-message", replace => { 
				row	=>	"&nbsp;",
				message	=>	"#!string!message_0093!#",
			}});
			$an->Log->entry({log_level => 2, message_key => "log_0233", message_variables => {
				server  => $vm, 
				file    => "/shared/definitions/${vm}.xml", 
			}, file => $THIS_FILE, line => __LINE__});
			my $virsh_exit_code;
			my $shell_call = "/usr/bin/virsh create /shared/definitions/${vm}.xml; echo virsh:\$?";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "node",       value2 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$node,
				port		=>	$an->data->{node}{$node}{port}, 
				password	=>	$password,
				ssh_fh		=>	"",
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				next if not $line;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /virsh:(\d+)/)
				{
					$virsh_exit_code = $1;
				}
			}
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "virsh exit code", value1 => $virsh_exit_code,
			}, file => $THIS_FILE, line => __LINE__});
			if ($virsh_exit_code eq "0")
			{
				# Should now be booting.
				print $an->Web->template({file => "server.html", template => "general-message", replace => { 
					row	=>	"&nbsp;",
					message	=>	"#!string!message_0092!#",
				}});
			}
			else
			{
				# Failed to boot.
				my $say_message = $an->String->get({key => "message_0094", variables => { 
						server		=>	$vm,
						virsh_exit_code	=>	$virsh_exit_code,
					}});
				print $an->Web->template({file => "server.html", template => "general-error-message", replace => { 
					row	=>	"#!string!row_0044!#",
					message	=>	$say_message,
				}});
				return (1);
			}
		}
	}
	elsif ($host eq $node)
	{
		# Already running
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
			row	=>	"&nbsp;",
			message	=>	"#!string!message_0095!#",
		}});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "The VM is now running on this node", value1 => $node,
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Already running, but on the peer.
		$node = $host;
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
			row	=>	"&nbsp;",
			message	=>	"#!string!message_0096!#",
		}});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node", value1 => $node,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Dump the VM's XML definition.
	print $an->Web->template({file => "server.html", template => "general-message", replace => { 
		row	=>	"#!string!row_0093!#",
		message	=>	"#!string!message_0097!#",
	}});
	if (not $vm)
	{
		# No server name... wth?
		print $an->Web->template({file => "server.html", template => "general-error-message", replace => { 
			row	=>	"#!string!row_0044!#",
			message	=>	"#!string!message_0098!#",
		}});
		return (1);
	}
	my @new_vm_xml;
	my $virsh_exit_code;
	my $shell_call = "/usr/bin/virsh dumpxml $vm; echo virsh:\$?";
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		next if not $line;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /virsh:(\d+)/)
		{
			$virsh_exit_code = $1;
		}
		else
		{
			push @new_vm_xml, $line;
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "virsh exit code", value1 => $virsh_exit_code,
	}, file => $THIS_FILE, line => __LINE__});
	if ($virsh_exit_code eq "0")
	{
		# Wrote the definition.
		my $say_message = $an->String->get({key => "message_0099", variables => { definition => $definition }});
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
			row	=>	"&nbsp;",
			message	=>	$say_message,
		}});
	}
	else
	{
		# Failed to write the definition file.
		my $say_error = $an->String->get({key => "message_0100", variables => { virsh_exit_code	=> $virsh_exit_code }});
		print $an->Web->template({file => "server.html", template => "general-error-message", replace => { 
			row	=>	"&nbsp;",
			message	=>	$say_error,
		}});
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
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
	$new_xml = update_network_driver($an, $new_xml);
	
	# Now write out the XML.
	$shell_call = "cat > $definition << EOF\n$new_xml\nEOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
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
	print $an->Web->template({file => "server.html", template => "general-message", replace => { 
		row	=>	"#!string!row_0094!#",
		message	=>	"#!string!message_0101!#",
	}});

	   $virsh_exit_code = "";
	my $undefine_ok     = 0;
	   $shell_call      = "/usr/bin/virsh undefine $vm; echo virsh:\$?";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "virsh exit code", value1 => $virsh_exit_code,
		name2 => "undefine_ok",     value2 => $undefine_ok,
	}, file => $THIS_FILE, line => __LINE__});
	$virsh_exit_code = "0" if $undefine_ok;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "virsh exit code", value1 => $virsh_exit_code,
	}, file => $THIS_FILE, line => __LINE__});
	if ($virsh_exit_code eq "0")
	{
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
			row	=>	"&nbsp;",
			message	=>	"#!string!message_0102!#",
		}});
	}
	else
	{
		$virsh_exit_code = "--" if not $virsh_exit_code;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "virsh exit code", value1 => $virsh_exit_code,
		}, file => $THIS_FILE, line => __LINE__});
		my $say_error = $an->String->get({key => "message_0103", variables => { virsh_exit_code	=> $virsh_exit_code }});
		print $an->Web->template({file => "server.html", template => "general-warning-message", replace => { 
			row	=>	"#!string!row_0044!#",
			message	=>	$say_error,
		}});
	}
	
	# If I've made it this far, I am ready to add it to the cluster configuration.
	print $an->Web->template({file => "server.html", template => "general-message", replace => { 
		row	=>	"#!string!row_0095!#",
		message	=>	"#!string!message_0105!#",
	}});
	
	my $ccs_exit_code;
	   $shell_call =  "ccs ";
	   $shell_call .= "-h localhost --activate --sync --password \"".$an->data->{clusters}{$cluster}{ricci_pw}."\" --addvm $vm ";
	   $shell_call .= "domain=\"$failover_domain\" ";
	   $shell_call .= "path=\"/shared/definitions/\" ";
	   $shell_call .= "autostart=\"0\" ";
	   $shell_call .= "exclusive=\"0\" ";
	   $shell_call .= "recovery=\"restart\" ";
	   $shell_call .= "max_restarts=\"2\" ";
	   $shell_call .= "restart_expire_time=\"600\" ";
	   $shell_call .= "migrate_options=\"--unsafe\" ";	# This is required when using 4kn based disks and it is OK if the cache policy is "writethrough".
	   $shell_call .= "; echo ccs:\$?";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /ccs:(\d+)/)
		{
			$ccs_exit_code = $1;
		}
		else
		{
			if ($line =~ /make sure the ricci server is started/)
			{
				# Tell the user that 'ricci' isn't running.
				print $an->Web->template({file => "server.html", template => "general-message", replace => { 
					row	=>	"#!string!row_0044!#",
					message	=>	$an->String->get({key => "message_0108", variables => { node => $node }}),
				}});
				print $an->Web->template({file => "server.html", template => "general-message", replace => { 
					row	=>	"&nbsp;",
					message	=>	"#!string!message_0109!#",
				}});
				print $an->Web->template({file => "server.html", template => "general-message", replace => { 
					row	=>	"&nbsp;",
					message	=>	"#!string!message_0110!#",
				}});
			}
			else
			{
				# Show any output from the call.
				$line = parse_text_line($an, $line);
				print $an->Web->template({file => "server.html", template => "general-message", replace => { 
					row	=>	"#!string!row_0127!#",
					message	=>	"<span class=\"fixed_width\">$line</span>",
				}});
			}
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ccs exit code", value1 => $ccs_exit_code,
	}, file => $THIS_FILE, line => __LINE__});
	$ccs_exit_code = "--" if not defined $ccs_exit_code;
	if ($ccs_exit_code eq "0")
	{
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
			row	=>	"#!string!row_0083!#",
			message	=>	"#!string!message_0111!#",
		}});
		
		### TODO: Make this watch 'clustat' for the VM to appear.
		sleep 10;
	}
	else
	{
		# ccs call failed
		print $an->Web->template({file => "server.html", template => "general-error-message", replace => { 
			row	=>	"#!string!row_0096!#",
			message	=>	$an->String->get({key => "message_0112", variables => { ccs_exit_code => $ccs_exit_code }}),
		}});
		return (1);
	}
	# Enable/boot the server.
	print $an->Web->template({file => "server.html", template => "general-message", replace => { 
		row	=>	"#!string!row_0097!#",
		message	=>	"#!string!message_0113!#",
	}});
	
	### TODO: Get the cluster's idea of the node name and use '-m ...'.
	# Tell the cluster to start the VM. I don't bother to check for readiness because I confirmed it was
	# running on this node earlier.
	my $clusvcadm_exit_code = "";
	   $shell_call          = "clusvcadm -e vm:$vm; echo clusvcadm:\$?";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /clusvcadm:(\d+)/)
		{
			$clusvcadm_exit_code = $1;
		}
		else
		{
			$line = parse_text_line($an, $line);
			print $an->Web->template({file => "server.html", template => "general-message", replace => { 
				row	=>	"#!string!row_0127!#",
				message	=>	"<span class=\"fixed_width\">$line</span>",
			}});
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "clusvcadm exit code", value1 => $clusvcadm_exit_code,
	}, file => $THIS_FILE, line => __LINE__});
	if ($clusvcadm_exit_code eq "0")
	{
		# Server added succcessfully.
		print $an->Web->template({file => "server.html", template => "general-message", replace => { 
			row	=>	"#!string!row_0083!#",
			message	=>	"#!string!message_0114!#",
		}});
	}
	else
	{
		# Appears to have failed.
		my $say_instruction = $an->String->get({key => "message_0088", variables => { manage_url => "?config=true&anvil=$cluster" }});
		my $say_message     = $an->String->get({key => "message_0115", variables => { 
				clusvcadm_exit_code	=>	$clusvcadm_exit_code,
				instructions		=>	$say_instruction,
			}});
		print $an->Web->template({file => "server.html", template => "general-error-message", replace => { 
			row	=>	"#!string!row_0096!#",
			message	=>	$say_message,
		}});
		return (1);
	}
	# Done!
	print $an->Web->template({file => "server.html", template => "add-server-to-anvil-footer"});

	return (0);
}

# This inserts, updates or removes a network interface driver in the passed-in XML definition file.
sub update_network_driver
{
	my ($an, $new_xml) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "update_network_driver" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "new_xml", value1 => $new_xml, 
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "sys::server::bcn_nic_driver", value1 => $an->data->{sys}{server}{bcn_nic_driver},
		name2 => "sys::server::sn_nic_driver",  value2 => $an->data->{sys}{server}{sn_nic_driver},
		name3 => "sys::server::ifn_nic_driver", value3 => $an->data->{sys}{server}{ifn_nic_driver},
	}, file => $THIS_FILE, line => __LINE__});
	
	# Clear out the old array and refill it with the possibly-edited 'new_xml'.
	my @new_vm_xml;
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /<interface type='bridge'>/)
		{
			$in_interface = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "in_interface", value1 => $in_interface,
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($in_interface)
		{
			if ($line =~ /<source bridge='(.*?)_bridge1'\/>/)
			{
				$this_network = $1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "this_network", value1 => $this_network,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /<driver name='(.*?)'\/>/)
			{
				$this_driver = $1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "this_driver", value1 => $this_driver,
				}, file => $THIS_FILE, line => __LINE__});
				
				# See if I need to update it.
				if ($this_network)
				{
					my $key = $this_network."_nic_driver";
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "key",               value1 => $key,
						name2 => "sys::server::$key", value2 => $an->data->{sys}{server}{$key},
					}, file => $THIS_FILE, line => __LINE__});
					if ($an->data->{sys}{server}{$key})
					{
						$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
							name1 => "this_driver",       value1 => $this_driver,
							name2 => "sys::server::$key", value2 => $an->data->{sys}{server}{$key},
						}, file => $THIS_FILE, line => __LINE__});
						if ($this_driver ne $an->data->{sys}{server}{$key})
						{
							# Change the driver
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => ">> line", value1 => $line,
							}, file => $THIS_FILE, line => __LINE__});
							$line =~ s/driver name='.*?'/driver name='$an->data->{sys}{server}{$key}'/;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "<< line", value1 => $line,
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
					else
					{
						# Delete the driver
						$an->Log->entry({log_level => 2, message_key => "log_0234", message_variables => {
							line => $line, 
						}, file => $THIS_FILE, line => __LINE__});
						next;
					}
				}
			}
			if ($line =~ /<\/interface>/)
			{
				# Insert the driver, if needed.
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "this_driver", value1 => $this_driver,
				}, file => $THIS_FILE, line => __LINE__});
				if (not $this_driver)
				{
					my $key = $this_network."_nic_driver";
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "key",               value1 => $key,
						name2 => "sys::server::$key", value2 => $an->data->{sys}{server}{$key},
					}, file => $THIS_FILE, line => __LINE__});
					if ($an->data->{sys}{server}{$key})
					{
						# Insert it
						$new_xml .= "      <driver name='$an->data->{sys}{server}{$key}'/>\n";
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "sys::server::$key", value1 => $an->data->{sys}{server}{$key}, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				
				$in_interface = 0;
				$this_network = "";
				$this_driver  = "";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "in_interface", value1 => $in_interface,
					name2 => "this_network", value2 => $this_network,
					name3 => "this_driver",  value3 => $this_driver,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		$new_xml .= "$line\n";
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "new_xml", value1 => $new_xml,
	}, file => $THIS_FILE, line => __LINE__});
	return($new_xml);
}

# This looks for a VM on the cluster and returns the current host node, if any. If the VM is not running, 
# then "none" is returned.
sub find_vm_host
{
	my ($an, $node, $peer, $vm) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "find_vm_host" }, message_key => "an_variables_0003", message_variables => { 
		name1 => "node", value1 => $node, 
		name2 => "peer", value2 => $peer, 
		name3 => "vm",   value3 => $vm, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $host       = "none";
	my $shell_call = "/usr/bin/virsh list --all";
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /\s$vm\s/)
		{
			# Found it
			$an->Log->entry({log_level => 2, message_key => "log_0235", message_variables => {
				server => $vm, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /^-/)
			{
				# It looks off... We have to go deeper!
				$an->Log->entry({log_level => 2, message_key => "log_0236", message_variables => {
					server => $vm, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# It's running.
				$host = $node;
				$an->Log->entry({log_level => 2, message_key => "log_0237", message_variables => {
					server => $vm, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	if ($host eq "none")
	{
		# Look on the peer.
		$an->Log->entry({log_level => 2, message_key => "log_0238", message_variables => {
			server => $vm, 
			peer   => $peer, 
		}, file => $THIS_FILE, line => __LINE__});
		my $on_peer    = 0;
		my $found      = 0;
		my $shell_call = "/usr/bin/virsh list --all";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$peer,
			port		=>	$an->data->{node}{$peer}{port}, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			next if not $line;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /\s$vm\s/)
			{
				# Found it on the peer node. Checking if it's running there.
				$an->Log->entry({log_level => 2, message_key => "log_0239", message_variables => {
					server => $vm, 
					peer   => $peer, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($line =~ /^\d/)
				{
					# Found it.
					$found   = 1;
					$on_peer = 1;
					$node    = $peer;
					$host    = $peer;
					$an->Log->entry({log_level => 2, message_key => "log_0225", file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Not found.
					$found = 0;
					$an->Log->entry({log_level => 2, message_key => "log_0240", file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		if (($found) && (not $on_peer))
		{
			# Did not find it on the peer.
			$an->Log->entry({log_level => 2, message_key => "log_0241", file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "host", value1 => $host,
	}, file => $THIS_FILE, line => __LINE__});
	return ($host);
}

# This gets the name of the bridge on the target node.
sub get_bridge_name
{
	my ($an, $node) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_bridge_name" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $bridge     = "";
	my $shell_call = "brctl show";
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
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
		
		if ($line =~ /^(.*?)\s+\d/)
		{
			$bridge = $1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "found bridge", value1 => $bridge,
			}, file => $THIS_FILE, line => __LINE__});
			last;
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "bridge", value1 => $bridge,
	}, file => $THIS_FILE, line => __LINE__});
	return($bridge);
}

# This actually kicks off the VM.
sub provision_vm
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "provision_vm" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $say_title = $an->String->get({key => "title_0115", variables => { server => $an->data->{new_vm}{name} }});
	print $an->Web->template({file => "server.html", template => "provision-server-header", replace => { title => $say_title }});
	
	# I need to know what the bridge is called.
	my $node   = $an->data->{new_vm}{host_node};
	my $bridge = get_bridge_name($an, $node);
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "new_vm::host_node", value1 => $an->data->{new_vm}{host_node},
	}, file => $THIS_FILE, line => __LINE__});
	
	# Create the LVs
	my $provision = "";
	my @logical_volumes;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "new_vm::vg", value1 => $an->data->{new_vm}{vg},
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $vg (keys %{$an->data->{new_vm}{vg}})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "vg", value1 => $vg,
		}, file => $THIS_FILE, line => __LINE__});
		for (my $i = 0; $i < @{$an->data->{new_vm}{vg}{$vg}{lvcreate_size}}; $i++)
		{
			my $lv_size   = $an->data->{new_vm}{vg}{$vg}{lvcreate_size}->[$i];
			my $lv_device = "/dev/$vg/".$an->data->{new_vm}{name}."_$i";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
				name1 => "i",         value1 => $i,
				name2 => "vg",        value2 => $vg,
				name3 => "lv_size",   value3 => $lv_size,
				name4 => "lv_device", value4 => $lv_device,
			}, file => $THIS_FILE, line => __LINE__});
			$provision .= "if [ ! -e '/dev/$vg/".$an->data->{new_vm}{name}."_$i' ];\n";
			$provision .= "then\n";
			if (lc($lv_size) eq "all")
			{
				$provision .= "    lvcreate -l 100\%FREE -n $an->data->{new_vm}{name}_$i $vg\n";
			}
			elsif ($lv_size =~ /^(\d+\.?\d+?)%$/)
			{
				my $size = $1;
				$provision .= "    lvcreate -l $size\%FREE -n $an->data->{new_vm}{name}_$i $vg\n";
			}
			else
			{
				$provision .= "    lvcreate -L ${lv_size}GiB -n $an->data->{new_vm}{name}_$i $vg\n";
			}
			$provision .= "fi\n";
			push @logical_volumes, $lv_device;
		}
	}
	
	# Setup the 'virt-install' call.
	$provision .= "virt-install --connect qemu:///system \\\\\n";
	$provision .= "  --name ".$an->data->{new_vm}{name}." \\\\\n";
	$provision .= "  --ram ".$an->data->{new_vm}{ram}." \\\\\n";
	$provision .= "  --arch x86_64 \\\\\n";
	$provision .= "  --vcpus ".$an->data->{new_vm}{cpu_cores}." \\\\\n";
	$provision .= "  --cpu host \\\\\n";
	$provision .= "  --cdrom '/shared/files/".$an->data->{new_vm}{install_iso}."' \\\\\n";
	$provision .= "  --boot menu=on \\\\\n";
	if ($an->data->{cgi}{driver_iso})
	{
		$provision .= "  --disk path='/shared/files/".$an->data->{new_vm}{driver_iso}."',device=cdrom --force\\\\\n";
	}
	$provision .= "  --os-variant ".$an->data->{cgi}{os_variant}." \\\\\n";
	
	# Connect to the discovered bridge
	my $nic_driver = "virtio";
	if (not $an->data->{new_vm}{virtio}{nic})
	{
		$nic_driver = $an->data->{sys}{server}{alternate_nic_model} ? $an->data->{sys}{server}{alternate_nic_model} : "e1000";
	}
	$an->data->{sys}{server}{nic_count} = 1 if not $an->data->{sys}{server}{nic_count};
	for (1..$an->data->{sys}{server}{nic_count})
	{
		$provision .= "  --network bridge=$bridge,model=$nic_driver \\\\\n";
	}
	
	foreach my $lv_device (@logical_volumes)
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "lv_device",  value1 => $lv_device,
			name2 => "use virtio", value2 => $an->data->{new_vm}{virtio}{disk},
		}, file => $THIS_FILE, line => __LINE__});
		$provision .= "  --disk path=$lv_device";
		if ($an->data->{new_vm}{virtio}{disk})
		{
			### NOTE: Not anymore.
			# The 'cache=writeback' is required to support systems built on 4kb native sector 
			# size disks.
			$provision .= ",bus=virtio,cache=writethrough";
		}
		$provision .= " \\\\\n";
	}
	$provision .= "  --graphics spice \\\\\n";
	# See https://www.redhat.com/archives/virt-tools-list/2014-August/msg00078.html
	# for why we're using '--noautoconsole --wait -1'.
	$provision .= "  --noautoconsole --wait -1 > /var/log/an-install_".$an->data->{new_vm}{name}.".log &\n";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "provision", value1 => $provision,
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: Make sure the desired node is up and, if not, use the one good node.
	
	# Push the provision script into a file.
	my $shell_script = "/shared/provision/".$an->data->{new_vm}{name}.".sh";
	my $message      = $an->String->get({key => "message_0118", variables => { script => $shell_script }});
	print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $message }});
	
	my $shell_call = "echo \"$provision\" > $shell_script && chmod 755 $shell_script";
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
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
		
	}
	$message = $an->String->get({key => "message_0119", variables => { server => $an->data->{new_vm}{name} }});
	print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $message }});
	
	### NOTE: Don't try to redirect output (2>&1 |), it causes errors I've not yet solved.
	# Run the script.
	$shell_call = $shell_script;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		next if $line =~ /One or more specified logical volume\(s\) not found./;
		if ($line =~ /No such file or directory/i)
		{
			 # Failed to write the provision file.
			$error = $an->String->get({key => "message_0330", variables => { provision_script => $shell_script }});
		}
		if ($line =~ /Unable to read from monitor/i)
		{
			### TODO: Delete the just-created LV
			# This can be caused by insufficient free RAM
			$error = $an->String->get({key => "message_0437", variables => { 
					server		=>	$an->data->{new_vm}{name},
					node		=>	$node,
				}});
		}
		if ($line =~ /syntax error/i)
		{
			# Something is wrong with the provision script
			$error = $an->String->get({key => "message_0438", variables => { 
					provision_script	=>	$shell_script,
					error			=>	$line,
				}});
		}
		### Supressing output to clean-up what the user sees.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		#$an->Web->template({file => "server.html", template => "one-line-message-fixed-width", replace => { message => $line }});
	}
	if ($error)
	{
		print $an->Web->template({file => "server.html", template => "provision-server-problem", replace => { message => $error }});
	}
	else
	{
		print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => "#!string!message_0120!#" }});
		
		# Verify that the new VM is running.
		my $shell_call = "sleep 3; virsh list | grep -q '$an->data->{new_vm}{name}'; echo rc:\$?";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /^rc:(\d+)/)
			{
				# 0 == found
				# 1 == not found
				my $rc = $1;
				if ($rc eq "1")
				{
					# Server wasn't created, it seems.
					print $an->Web->template({file => "server.html", template => "provision-server-problem", replace => { message => "#!string!message_0434!#" }});
					$error = 1;
				}
			}
		}
	}
	
	# Done!
	#print $an->Web->template({file => "server.html", template => "provision-server-footer"});
	
	# Add the server to the cluster if no errors exist.
	if (not $error)
	{
		# Add it and then change the boot device to 'hd'.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "host_node", value1 => $an->data->{new_vm}{host_node},
		}, file => $THIS_FILE, line => __LINE__});
		add_vm_to_cluster($an, 1);
	}
	
	return (0);
}

# This sanity-checks the requested VM config prior to creating the VM itself.
sub verify_vm_config
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "verify_vm_config" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# First, get a current view of the cluster.
	my $proceed = 1;
	AN::Cluster::scan_cluster($an);
	AN::Cluster::read_files_on_shared($an);
	
	# If we connected, start parsing.
	my $cluster = $an->data->{cgi}{cluster};
	my @errors;
	if ($an->data->{sys}{up_nodes})
	{
		# Did the user name the VM?
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::name", value1 => $an->data->{cgi}{name},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{name})
		{
			# Normally, it's safer to only allow a subset of
			# characters, but it would be nice to allow users to 
			# name their servers using non-latin characters, so for
			# now, we look for bad characters only.
			$an->data->{cgi}{name} =~ s/^\s+//;
			$an->data->{cgi}{name} =~ s/\s+$//;
			if ($an->data->{cgi}{name} =~ /\s/)
			{
				# Bad name, no spaces allowed.
				my $say_row     = $an->String->get({key => "row_0102"});
				my $say_message = $an->String->get({key => "message_0127"});
				push @errors, "$say_row#!#$say_message";
			}
			# If this changes, remember to update message_0127!
			elsif (($an->data->{cgi}{name} =~ /;/) || 
			       ($an->data->{cgi}{name} =~ /&/) || 
			       ($an->data->{cgi}{name} =~ /\|/) || 
			       ($an->data->{cgi}{name} =~ /\$/) || 
			       ($an->data->{cgi}{name} =~ />/) || 
			       ($an->data->{cgi}{name} =~ /</) || 
			       ($an->data->{cgi}{name} =~ /\[/) || 
			       ($an->data->{cgi}{name} =~ /\]/) || 
			       ($an->data->{cgi}{name} =~ /\(/) || 
			       ($an->data->{cgi}{name} =~ /\)/) || 
			       ($an->data->{cgi}{name} =~ /}/) || 
			       ($an->data->{cgi}{name} =~ /{/) || 
			       ($an->data->{cgi}{name} =~ /!/) || 
			       ($an->data->{cgi}{name} =~ /\^/))
			{
				# Illegal characters.
				my $say_row     = $an->String->get({key => "row_0102"});
				my $say_message = $an->String->get({key => "message_0127"});
				push @errors, "$say_row#!#$say_message";
			}
			else
			{
				my $vm     = $an->data->{cgi}{name};
				my $vm_key = "vm:$vm";
				if (exists $an->data->{vm}{$vm_key})
				{
					# Duplicate name
					my $say_row     = $an->String->get({key => "row_0103"});
					my $say_message = $an->String->get({key => "message_0128", variables => { server => $vm }});
					push @errors, "$say_row#!#$say_message";
				}
				else
				{
					# Name is OK
					$an->data->{new_vm}{name} = $vm;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "new_vm::name", value1 => $an->data->{new_vm}{name},
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		else
		{
			# Missing server name
			my $say_row     = $an->String->get({key => "row_0104"});
			my $say_message = $an->String->get({key => "message_0129"});
			push @errors, "$say_row#!#$say_message";
		}
		
		# Did the user ask for too many cores?
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "cgi::cpu_cores",           value1 => $an->data->{cgi}{cpu_cores},
			name2 => "resources::total_threads", value2 => $an->data->{resources}{total_threads},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{cpu_cores} =~ /\D/)
		{
			# Not a digit.
			my $say_row     = $an->String->get({key => "row_0105", variables => {  }});
			my $say_message = $an->String->get({key => "message_0130", variables => { cpu_cores => $an->data->{cgi}{cpu_cores} }});
			push @errors, "$say_row#!#$say_message";
		}
		elsif ($an->data->{cgi}{cpu_cores} > $an->data->{resources}{total_threads})
		{
			# Not enough cores
			my $say_row     = $an->String->get({key => "row_0106"});
			my $say_message = $an->String->get({key => "message_0131", variables => { 
					total_threads	=>	$an->data->{resources}{total_threads},
					cpu_cores	=>	$an->data->{cgi}{cpu_cores},
				}});
			push @errors, "$say_row#!#$say_message";
		}
		else
		{
			$an->data->{new_vm}{cpu_cores} = $an->data->{cgi}{cpu_cores};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "new_vm::cpu_cores", value1 => $an->data->{new_vm}{cpu_cores},
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Now what about RAM?
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::ram", value1 => $an->data->{cgi}{ram},
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{cgi}{ram} =~ /\D/) && ($an->data->{cgi}{ram} !~ /^\d+\.\d+$/))
		{
			# RAM amount isn't a digit...
			my $say_row     = $an->String->get({key => "row_0107"});
			my $say_message = $an->String->get({key => "message_0132", variables => { ram => $an->data->{cgi}{ram} }});
			push @errors, "$say_row#!#$say_message";
		}
		my $requested_ram = $an->Readable->hr_to_bytes({size => $an->data->{cgi}{ram}, type => $an->data->{cgi}{ram_suffix} });
		my $diff          = $an->data->{resources}{total_ram} % (1024 ** 3);
		my $available_ram = $an->data->{resources}{total_ram} - $diff - $an->data->{sys}{unusable_ram};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "requested_ram", value1 => $requested_ram,
			name2 => "available_ram", value2 => $available_ram,
		}, file => $THIS_FILE, line => __LINE__});
		if ($requested_ram > $available_ram)
		{
			# Requested too much RAM.
			my $say_free_ram  = $an->Readable->bytes_to_hr({'bytes' => $available_ram });
			my $say_requested = $an->Readable->bytes_to_hr({'bytes' => $requested_ram });
			my $say_row       = $an->String->get({key => "row_0108"});
			my $say_message   = $an->String->get({key => "message_0133", variables => { 
					free_ram	=>	$say_free_ram,
					requested_ram	=>	$say_requested,
				}});
			push @errors, "$say_row#!#$say_message";
		}
		else
		{
			# RAM is specified as a number of MiB.
			my $say_ram = sprintf("%.0f", ($requested_ram /= (2 ** 20)));
			$an->data->{new_vm}{ram} = $say_ram;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "new_vm::ram", value1 => $an->data->{new_vm}{ram},
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Look at the selected storage. if VGs named for two separate
		# nodes are defined, error.
		$an->data->{new_vm}{host_node} = "";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "host_node", value1 => $an->data->{new_vm}{host_node},
			name2 => "vg_list",   value2 => $an->data->{cgi}{vg_list},
		}, file => $THIS_FILE, line => __LINE__});
		foreach my $vg (split /,/, $an->data->{cgi}{vg_list})
		{
			my $short_vg   = $vg;
			my $short_node = $vg;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "short_vg",   value1 => $short_vg,
				name2 => "short_node", value2 => $short_node,
				name3 => "vg",         value3 => $vg,
			}, file => $THIS_FILE, line => __LINE__});
			if ($vg =~ /^(.*?)_(vg\d+)$/)
			{
				$short_node = $1;
				$short_vg   = $2;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "short_vg",   value1 => $short_vg,
					name2 => "short_node", value2 => $short_node,
				}, file => $THIS_FILE, line => __LINE__});
			}
			my $say_node      = $short_node;
			my $vg_key        = "vg_$vg";
			my $vg_suffix_key = "vg_suffix_$vg";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "say_node",      value1 => $say_node,
				name2 => "vg_key",        value2 => $vg_key,
				name3 => "vg_suffix_key", value3 => $vg_suffix_key,
			}, file => $THIS_FILE, line => __LINE__});
			next if not $an->data->{cgi}{$vg_key};
			foreach my $node (sort {$a cmp $b} @{$an->data->{clusters}{$cluster}{nodes}})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node",       value1 => $node,
					name2 => "short_node", value2 => $short_node,
				}, file => $THIS_FILE, line => __LINE__});
				if ($node =~ /$short_node/)
				{
					$say_node = $node;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "say_node", value1 => $say_node,
					}, file => $THIS_FILE, line => __LINE__});
					last;
				}
			}
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "host_node", value1 => $an->data->{new_vm}{host_node},
			}, file => $THIS_FILE, line => __LINE__});
			if (not $an->data->{new_vm}{host_node})
			{
				$an->data->{new_vm}{host_node} = $say_node;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "host_node", value1 => $an->data->{new_vm}{host_node},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($an->data->{new_vm}{host_node} ne $say_node)
			{
				# Conflicting Storage
				my $say_row     = $an->String->get({key => "row_0109"});
				my $say_message = $an->String->get({key => "message_0134"});
				push @errors, "$say_row#!#$say_message";
			}
			
			# Setup the 'lvcreate' call
			foreach my $lv_size (split/:/, $an->data->{cgi}{$vg_key})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "lv_size", value1 => $lv_size,
				}, file => $THIS_FILE, line => __LINE__});
				if ($lv_size eq "all")
				{
					push @{$an->data->{new_vm}{vg}{$vg}{lvcreate_size}}, "all";
				}
				elsif ($an->data->{cgi}{$vg_suffix_key} eq "%")
				{
					push @{$an->data->{new_vm}{vg}{$vg}{lvcreate_size}}, "${lv_size}%";
				}
				else
				{
					# Make to lvcreate command a GiB value.
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "cgi::${vg_key}",        value1 => $lv_size,
						name2 => "cgi::${vg_suffix_key}", value2 => $an->data->{cgi}{$vg_suffix_key},
					}, file => $THIS_FILE, line => __LINE__});
					
					my $lv_size = $an->Readable->hr_to_bytes({size => $lv_size, type => $an->data->{cgi}{$vg_suffix_key} });
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "> lv_size", value1 => $lv_size,
					}, file => $THIS_FILE, line => __LINE__});
					$lv_size    = sprintf("%.0f", ($lv_size /= (2 ** 30)));
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "< lv_size", value1 => $lv_size,
					}, file => $THIS_FILE, line => __LINE__});
					
					push @{$an->data->{new_vm}{vg}{$vg}{lvcreate_size}}, "$lv_size";
				}
			}
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "host_node", value1 => $an->data->{new_vm}{host_node},
		}, file => $THIS_FILE, line => __LINE__});
		
		# Make sure the user specified an install disc.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::install_iso", value1 => $an->data->{cgi}{install_iso},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{install_iso})
		{
			my $file_name = $an->data->{cgi}{install_iso};
			if (exists $an->data->{files}{shared}{$file_name})
			{
				$an->data->{new_vm}{install_iso} = $an->data->{cgi}{install_iso};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "new_vm::install_iso", value1 => $an->data->{new_vm}{install_iso},
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Dude, where's my ISO?
				my $say_row     = $an->String->get({key => "row_0110"});
				my $say_message = $an->String->get({key => "message_0135"});
				push @errors, "$say_row#!#$say_message";
			}
		}
		else
		{
			# The user needs an install source...
			my $say_row     = $an->String->get({key => "row_0110"});
			my $say_message = $an->String->get({key => "message_0136"});
			push @errors, "$say_row#!#$say_message";
		}
		
		# A few OSes we set don't match a real os-variant. Swap them here.
		if ($an->data->{cgi}{os_variant} eq "debianjessie")
		{
			# Debian is modern enough so we'll use the 'rhel7' variant.
			$an->data->{cgi}{os_variant} = "rhel7";
		}
		
		### TODO: Find a better way to determine this.
		# Look at the OS type to try and determine if 'e1000' or
		# 'virtio' should be used by the network.
		$an->data->{new_vm}{virtio}{nic}  = 0;
		$an->data->{new_vm}{virtio}{disk} = 0;
		if (($an->data->{cgi}{os_variant} =~ /fedora1\d/) || 
		    ($an->data->{cgi}{os_variant} =~ /virtio/) || 
		    ($an->data->{cgi}{os_variant} =~ /ubuntu/) || 
		    ($an->data->{cgi}{os_variant} =~ /sles11/) || 
		    ($an->data->{cgi}{os_variant} =~ /rhel5/) || 
		    ($an->data->{cgi}{os_variant} =~ /rhel6/) || 
		    ($an->data->{cgi}{os_variant} =~ /rhel7/))
		{
			$an->data->{new_vm}{virtio}{disk} = 1;
			$an->data->{new_vm}{virtio}{nic}  = 1;
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "new_vm::virtio::disk", value1 => $an->data->{new_vm}{virtio}{disk},
			name2 => "new_vm::virtio::nic",  value2 => $an->data->{new_vm}{virtio}{nic},
		}, file => $THIS_FILE, line => __LINE__});
		
		# Optional driver disk, enables virtio when appropriate
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::driver_iso", value1 => $an->data->{cgi}{driver_iso},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{driver_iso})
		{
			my $file_name = $an->data->{cgi}{driver_iso};
			if (exists $an->data->{files}{shared}{$file_name})
			{
				$an->data->{new_vm}{driver_iso} = $an->data->{cgi}{driver_iso};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "new_vm::driver_iso", value1 => $an->data->{new_vm}{driver_iso},
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Install media no longer exists.
				my $say_row     = $an->String->get({key => "row_0111"});
				my $say_message = $an->String->get({key => "message_0137"});
				push @errors, "$say_row#!#$say_message";
			}
			
			if (lc($file_name) =~ /virtio/)
			{
				$an->data->{new_vm}{virtio}{disk} = 1;
				$an->data->{new_vm}{virtio}{nic}  = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "new_vm::virtio::disk", value1 => $an->data->{new_vm}{virtio}{disk},
					name2 => "new_vm::virtio::nic",  value2 => $an->data->{new_vm}{virtio}{nic},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Make sure a valid os-variant was passed.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::os_variant", value1 => $an->data->{cgi}{os_variant},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{os_variant})
		{
			my $match = 0;
			foreach my $os_variant (@{$an->data->{sys}{os_variant}})
			{
				my ($short_name, $desc) = ($os_variant =~ /^(.*?)#!#(.*)$/);
				if ($an->data->{cgi}{os_variant} eq $short_name)
				{
					$match = 1;
				}
			}
			if (not $match)
			{
				# OS variant specified but invalid
				my $say_row     = $an->String->get({key => "row_0112"});
				my $say_message = $an->String->get({key => "message_0138"});
				push @errors, "$say_row#!#$say_message";
			}
		}
		else
		{
			# No OS variant specified.
			my $say_row     = $an->String->get({key => "row_0113"});
			my $say_message = $an->String->get({key => "message_0139"});
			push @errors, "$say_row#!#$say_message";
		}
		
		# If there were errors, push the user back to the form.
		if (@errors > 0)
		{
			$proceed = 0;
			print $an->Web->template({file => "server.html", template => "verify-server-header"});
			
			foreach my $error (@errors)
			{
				my ($title, $body) = ($error =~ /^(.*?)#!#(.*)$/);
				print $an->Web->template({file => "server.html", template => "verify-server-error", replace => { 
					title	=>	$title,
					body	=>	$body,
				}});
			}
			print $an->Web->template({file => "server.html", template => "verify-server-footer"});
		}
	}
	else
	{
		# Failed to connect to the cluster, errors should already be reported to the user.
	}
	# Check the currently available resources on the cluster.
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "proceed", value1 => $proceed,
	}, file => $THIS_FILE, line => __LINE__});
	return ($proceed);
}

# This doesn't so much confirm as it does ask the user how they want to build the VM.
sub confirm_provision_vm
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_provision_vm" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my ($node) = AN::Cluster::read_files_on_shared($an);
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "read file list from node", value1 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	return if not $node;
	
	my $cluster = $an->data->{cgi}{cluster};
	my $images  = [];
	foreach my $file (sort {$a cmp $b} keys %{$an->data->{files}{shared}})
	{
		next if $file !~ /iso$/i;
		push @{$images}, $file;
	}
	my $cpu_cores = [];
	foreach my $core_num (1..$an->data->{cgi}{max_cores})
	{
		if ($an->data->{cgi}{max_cores} > 9)
		{
			#push @{$cpu_cores}, sprintf("%.2d", $core_num);
			push @{$cpu_cores}, $core_num;
		}
		else
		{
			push @{$cpu_cores}, $core_num;
		}
	}
	$an->data->{cgi}{cpu_cores}  = 2 if not $an->data->{cgi}{cpu_cores};
	my $select_cpu_cores     = AN::Cluster::build_select($an, "cpu_cores", 0, 0, 60, $an->data->{cgi}{cpu_cores}, $cpu_cores);
	foreach my $storage (sort {$a cmp $b} split/,/, $an->data->{cgi}{max_storage})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "storage", value1 => $storage,
		}, file => $THIS_FILE, line => __LINE__});
		my ($vg, $space)             =  ($storage =~ /^(.*?):(\d+)$/);
		my $say_max_storage          =  $an->Readable->bytes_to_hr({'bytes' => $space });
		$say_max_storage             =~ s/\.(\d+)//;
		$an->data->{cgi}{vg_list}        .= "$vg,";
		my $vg_key                   =  "vg_$vg";
		my $vg_suffix_key            =  "vg_suffix_$vg";
		$an->data->{cgi}{$vg_key}        =  ""    if not $an->data->{cgi}{$vg_key};
		$an->data->{cgi}{$vg_suffix_key} =  "GiB" if not $an->data->{cgi}{$vg_suffix_key};
		my $select_vg_suffix         =  AN::Cluster::build_select($an, "$vg_suffix_key", 0, 0, 60, $an->data->{cgi}{$vg_suffix_key}, ["MiB", "GiB", "TiB", "%"]);
		if ($space < (2 ** 30))
		{
			# Less than a Terabyte
			$select_vg_suffix            = AN::Cluster::build_select($an, "$vg_suffix_key", 0, 0, 60, $an->data->{cgi}{$vg_suffix_key}, ["MiB", "GiB", "%"]);
			$an->data->{cgi}{$vg_suffix_key} = "GiB" if not $an->data->{cgi}{$vg_suffix_key};
		}
		elsif ($space < (2 ** 20))
		{
			# Less than a Gigabyte
			$select_vg_suffix            = AN::Cluster::build_select($an, "$vg_suffix_key", 0, 0, 60, $an->data->{cgi}{$vg_suffix_key}, ["MiB", "%"]);
			$an->data->{cgi}{$vg_suffix_key} = "MiB" if not $an->data->{cgi}{$vg_suffix_key};
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
		foreach my $node (sort {$a cmp $b} @{$an->data->{clusters}{$cluster}{nodes}})
		{
			if ($node =~ /$short_node/)
			{
				$say_node = $node;
				last;
			}
		}
		
		$an->data->{vg_selects}{$vg}{space}         = $space;
		$an->data->{vg_selects}{$vg}{say_storage}   = $say_max_storage;
		$an->data->{vg_selects}{$vg}{select_suffix} = $select_vg_suffix;
		$an->data->{vg_selects}{$vg}{say_node}      = $say_node;
		$an->data->{vg_selects}{$vg}{short_vg}      = $short_vg;
	}
	my $say_selects;
	my $say_or      = $an->Web->template({file => "server.html", template => "provision-server-storage-pool-or-message"});
	foreach my $vg (sort {$a cmp $b} keys %{$an->data->{vg_selects}})
	{
		my $space            =  $an->data->{vg_selects}{$vg}{space};
		my $say_max_storage  =  $an->data->{vg_selects}{$vg}{say_storage};
		my $select_vg_suffix =  $an->data->{vg_selects}{$vg}{select_suffix};
		my $say_node         =  $an->data->{vg_selects}{$vg}{say_node};
		   $say_node         =~ s/\..*$//;
		my $short_vg         =  $an->data->{vg_selects}{$vg}{short_vg};
		my $vg_key           =  "vg_$vg";
		   $say_selects      .= $an->Web->template({file => "server.html", template => "provision-server-selects", replace => { 
				node			=>	$say_node,
				short_vg		=>	$short_vg,
				max_storage		=>	$say_max_storage,
				vg_key			=>	$vg_key,
				vg_key_value		=>	$an->data->{cgi}{$vg_key},
				select_vg_suffix	=>	$select_vg_suffix,
			}});
		$say_selects .= "$say_or";
	}
	$say_selects =~ s/$say_or$//m;
	$say_selects .= $an->Web->template({file => "server.html", template => "provision-server-vg-list-hidden-input", replace => { vg_list => $an->data->{cgi}{vg_list} }});
	my $say_max_ram          = $an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{max_ram} });
	$an->data->{cgi}{ram}        = 2 if not $an->data->{cgi}{ram};
	$an->data->{cgi}{ram_suffix} = "GiB" if not $an->data->{cgi}{ram_suffix};
	my $select_ram_suffix    = AN::Cluster::build_select($an, "ram_suffix", 0, 0, 60, $an->data->{cgi}{ram_suffix}, ["MiB", "GiB"]);
	$an->data->{cgi}{os_variant} = "generic" if not $an->data->{cgi}{os_variant};
	my $select_install_iso   = AN::Cluster::build_select($an, "install_iso", 1, 1, 300, $an->data->{cgi}{install_iso}, $images);
	my $select_driver_iso    = AN::Cluster::build_select($an, "driver_iso", 1, 1, 300, $an->data->{cgi}{driver_iso}, $images);
	my $select_os_variant    = AN::Cluster::build_select($an, "os_variant", 1, 0, 300, $an->data->{cgi}{os_variant}, $an->data->{sys}{os_variant});
	
	my $say_title = $an->String->get({key => "message_0142", variables => { 
			anvil	=>	$an->data->{cgi}{cluster},
		}});
	print $an->Web->template({file => "server.html", template => "provision-server-questions", replace => { 
		title			=>	$say_title,
		name			=>	$an->data->{cgi}{name},
		select_os_variant	=>	$select_os_variant,
		media_library_url	=>	"mediaLibrary?cluster=".$an->data->{cgi}{cluster},
		select_install_iso	=>	$select_install_iso,
		select_driver_iso	=>	$select_driver_iso,
		say_max_ram		=>	$say_max_ram,
		ram			=>	$an->data->{cgi}{ram},
		select_ram_suffix	=>	$select_ram_suffix,
		select_cpu_cores	=>	$select_cpu_cores,
		selects			=>	$say_selects,
		anvil			=>	$an->data->{cgi}{cluster},
		task			=>	$an->data->{cgi}{task},
		max_ram			=>	$an->data->{cgi}{max_ram},
		max_cores		=>	$an->data->{cgi}{max_cores},
		max_storage		=>	$an->data->{cgi}{max_storage},
	}});
	
	return (0);
}

# Confirm that the user wants to join both nodes to the cluster.
sub confirm_withdraw_node
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_withdraw_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_title = $an->String->get({key => "title_0035", variables => { 
			node_anvil_name	=>	$an->data->{cgi}{node_cluster_name},
			anvil		=>	$an->data->{cgi}{cluster},
		}});
	my $say_message = $an->String->get({key => "message_0145", variables => { node_anvil_name => $an->data->{cgi}{node_cluster_name} }});
	print $an->Web->template({file => "server.html", template => "confirm-withdrawl", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});
	
	return (0);
}

# Confirm that the user wants to join a node to the cluster.
sub confirm_join_cluster
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_join_cluster" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_title = $an->String->get({key => "title_0036", variables => { 
			node_anvil_name	=>	$an->data->{cgi}{node_cluster_name},
			anvil		=>	$an->data->{cgi}{cluster},
		}});
	my $say_message = $an->String->get({key => "message_0147", variables => { node_anvil_name => $an->data->{cgi}{node_cluster_name} }});
	print $an->Web->template({file => "server.html", template => "confirm-join-anvil", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});

	return (0);
}

# Confirm that the user wants to join both nodes to the cluster.
sub confirm_dual_join
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_dual_join" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_title   = $an->String->get({key => "title_0037", variables => { anvil => $an->data->{cgi}{cluster} }});
	my $say_message = $an->String->get({key => "message_0150", variables => { anvil => $an->data->{cgi}{cluster} }});
	print $an->Web->template({file => "server.html", template => "confirm-dual-join-anvil", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});
	
	return (0);
}

# Confirm that the user wants to fence a nodes.
sub confirm_fence_node
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_fence_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_title               =  $an->String->get({key => "title_0038", variables => { node_anvil_name => $an->data->{cgi}{node_cluster_name} }});
	my $say_message             =  $an->String->get({key => "message_0151", variables => { node_anvil_name => $an->data->{cgi}{node_cluster_name} }});
	my $expire_time             =  time + $an->data->{sys}{actime_timeout};
	   $an->data->{sys}{cgi_string} =~ s/expire=(\d+)/expire=$expire_time/;
	print $an->Web->template({file => "server.html", template => "confirm-fence-node", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});

	return (0);
}

# Confirm that the user wants to power-off a nodes.
sub confirm_poweroff_node
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_poweroff_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_title               =  $an->String->get({key => "title_0039", variables => { node_anvil_name => $an->data->{cgi}{node_cluster_name} }});
	my $say_message             =  $an->String->get({key => "message_0156", variables => { node_anvil_name => $an->data->{cgi}{node_cluster_name} }});
	my $expire_time             =  time + $an->data->{sys}{actime_timeout};
	   $an->data->{sys}{cgi_string} =~ s/expire=(\d+)/expire=$expire_time/;
	print $an->Web->template({file => "server.html", template => "confirm-poweroff-node", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});
	
	return (0);
}

# Confirm that the user wants to boot a nodes.
sub confirm_poweron_node
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_poweron_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_title   = $an->String->get({key => "title_0040", variables => { node_anvil_name => $an->data->{cgi}{node_cluster_name} }});
	my $say_message = $an->String->get({key => "message_0160", variables => { node_anvil_name => $an->data->{cgi}{node_cluster_name} }});
	print $an->Web->template({file => "server.html", template => "confirm-poweron-node", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});

	return (0);
}

# Confirm that the user wants to boot both nodes.
sub confirm_dual_boot
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_dual_boot" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_message = $an->String->get({key => "message_0161", variables => { anvil => $an->data->{cgi}{cluster} }});
	print $an->Web->template({file => "server.html", template => "confirm-dual-poweron-node", replace => { 
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});

	return (0);
}

# Confirm that the user wants to cold-stop the Anvil!.
sub confirm_cold_stop_anvil
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_cold_stop_anvil" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_message = $an->String->get({key => "message_0418", variables => { anvil => $an->data->{cgi}{cluster} }});
	
	# If there is a subtype, use a different warning.
	if ($an->data->{cgi}{subtask} eq "power_cycle")
	{
		$say_message = $an->String->get({key => "message_0439", variables => { anvil => $an->data->{cgi}{cluster} }});
	}
	elsif($an->data->{cgi}{subtask} eq "power_off")
	{
		$say_message = $an->String->get({key => "message_0440", variables => { anvil => $an->data->{cgi}{cluster} }});
	}
	
	my $expire_time             =  time + $an->data->{sys}{actime_timeout};
	   $an->data->{sys}{cgi_string} =~ s/expire=(\d+)/expire=$expire_time/;
	print $an->Web->template({file => "server.html", template => "confirm-cold-stop", replace => { 
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});

	return (0);
}

# Confirm that the user wants to start a VM.
sub confirm_start_vm
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_start_vm" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_title = $an->String->get({key => "title_0042", variables => { 
			server		=>	$an->data->{cgi}{vm},
			node_anvil_name	=>	$an->data->{cgi}{node_cluster_name},
		}});
	my $say_message = $an->String->get({key => "message_0163", variables => { 
			server		=>	$an->data->{cgi}{vm},
			node_anvil_name	=>	$an->data->{cgi}{node_cluster_name},
		}});
	print $an->Web->template({file => "server.html", template => "confirm-start-server", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});

	return (0);
}	

# Confirm that the user wants to stop a VM.
sub confirm_stop_vm
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_stop_vm" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_title   = $an->String->get({key => "title_0043", variables => { server => $an->data->{cgi}{vm} }});
	my $say_message = $an->String->get({key => "message_0165", variables => { 
			server		=>	$an->data->{cgi}{vm},
			node_anvil_name	=>	$an->data->{cgi}{node_cluster_name},
		}});
	my $say_warning             =  $an->String->get({key => "message_0166", variables => { server => $an->data->{cgi}{vm} }});
	my $say_precaution          =  $an->String->get({key => "message_0167", variables => { node_anvil_name => $an->data->{cgi}{node_cluster_name} }});
	my $expire_time             =  time + $an->data->{sys}{actime_timeout};
	   $an->data->{sys}{cgi_string} =~ s/expire=(\d+)/expire=$expire_time/;
	print $an->Web->template({file => "server.html", template => "confirm-stop-server", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		warning		=>	$say_warning,
		precaution	=>	$say_precaution,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});

	return (0);
}

# Confirm that the user wants to force-off a VM.
sub confirm_force_off_vm
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_force_off_vm" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Ask the user to confirm
	my $say_title   = $an->String->get({key => "title_0044", variables => { server => $an->data->{cgi}{vm} }});
	my $say_message = $an->String->get({key => "message_0168", variables => { 
			server	=>	$an->data->{cgi}{vm},
			host	=>	$an->data->{cgi}{host},
		}});
	my $expire_time             =  time + $an->data->{sys}{actime_timeout};
	   $an->data->{sys}{cgi_string} =~ s/expire=(\d+)/expire=$expire_time/;
	print $an->Web->template({file => "server.html", template => "confirm-force-off-server", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});
	
	return (0);
}

# Confirm that the user wants to migrate a VM.
sub confirm_delete_vm
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_delete_vm" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});

	# Ask the user to confirm
	my $say_title   = $an->String->get({key => "title_0045", variables => { server => $an->data->{cgi}{vm} }});
	my $say_message = $an->String->get({key => "message_0178", variables => { server => $an->data->{cgi}{vm} }});
	print $an->Web->template({file => "server.html", template => "confirm-delete-server", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});
	
	return (0);
}

# Confirm that the user wants to migrate a VM.
sub confirm_migrate_vm
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "confirm_migrate_vm" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Calculate roughly how long the migration will take.
	my $migration_time_estimate = $an->data->{cgi}{vm_ram} / 1073741824; # Get # of GB.
	$migration_time_estimate *= 10; # ~10s / GB

	# Ask the user to confirm
	my $say_title = $an->String->get({key => "title_0047", variables => { 
			server	=>	$an->data->{cgi}{vm},
			target	=>	$an->data->{cgi}{target},
		}});
	my $say_message = $an->String->get({key => "message_0177", variables => { 
			server			=>	$an->data->{cgi}{vm},
			target			=>	$an->data->{cgi}{target},
			ram			=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{vm_ram} }),
			migration_time_estimate	=>	$migration_time_estimate,
		}});
	print $an->Web->template({file => "server.html", template => "confirm-migrate-server", replace => { 
		title		=>	$say_title,
		message		=>	$say_message,
		confirm_url	=>	$an->data->{sys}{cgi_string}."&confirm=true",
	}});
	
	return (0);
}

# This boots a VM on a target node.
sub start_vm
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "start_vm" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node              = $an->data->{cgi}{node};
	my $cluster           = $an->data->{cgi}{cluster};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	my $vm                = $an->data->{cgi}{vm};
	my $say_vm            = $vm =~ /^vm:/ ? ($vm =~ /vm:(.*)/)[0] : $vm;
	my $remote_message    = "";
	my $remote_icon       = "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "vm",                value1 => $vm,
		name2 => "say_vm",            value2 => $say_vm,
		name3 => "node",              value3 => $node,
		name4 => "node_cluster_name", value4 => $node_cluster_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Make sure the node is still ready to take this VM.
	AN::Cluster::scan_cluster($an);
	my $vm_key = "vm:$vm";
	my $ready = check_node_readiness($an, $vm_key, $node);
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node",  value1 => $node,
		name2 => "ready", value2 => $ready,
	}, file => $THIS_FILE, line => __LINE__});
	if ($ready)
	{
		my $say_title = $an->String->get({key => "title_0046", variables => { 
				server		=>	$say_vm,
				node_anvil_name	=>	$node_cluster_name,
			}});
		print $an->Web->template({file => "server.html", template => "start-server-header", replace => { title => $say_title }});
		
		my $server_started           = 0;
		my $show_remote_desktop_link = 0;
		my $shell_call = "clusvcadm -e vm:$vm -m $node_cluster_name";
		my $password   = $an->data->{sys}{root_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /Success/i)
			{
				# Set the host manually as the server wasn't
				# running when the cluster was last scanned.
				my $vm_key = "vm:$vm";
				$an->data->{vm}{$vm_key}{current_host} = $node;
				$show_remote_desktop_link      = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
					name1 => "vm",                          value1 => $vm,
					name2 => "vm_key",                      value2 => $vm_key,
					name3 => "node",                        value3 => $node,
					name4 => "vm::${vm_key}::current_host", value4 => $an->data->{vm}{$vm_key}{current_host},
				}, file => $THIS_FILE, line => __LINE__});
				$server_started = 1;
			}
			elsif ($line =~ /Service is already running/i)
			{
				$show_remote_desktop_link = 2;
				$line = "";
				print $an->Web->template({file => "server.html", template => "start-server-already-running"});
			}
			elsif ($line =~ /Fail/i)
			{
				# The VM failed to start. Call a stop against it.
				print $an->Web->template({file => "server.html", template => "start-server-failed"});
				my $shell_call = "clusvcadm -d vm:$vm";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
					name2 => "node",       value2 => $node,
				}, file => $THIS_FILE, line => __LINE__});
				my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$node,
					port		=>	$an->data->{node}{$node}{port}, 
					password	=>	$password,
					ssh_fh		=>	"",
					'close'		=>	0,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
					
					$line = parse_text_line($an, $line);
					my $message = ($line =~ /^(.*)\[/)[0];
					my $status  = ($line =~ /(\[.*)$/)[0];
					if (not $message)
					{
						$message = $line;
						$status  = "";
					}
					print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
						status	=>	$status,
						message	=>	$message,
					}});
				}
				print $an->Web->template({file => "server.html", template => "start-server-failed-trying-again"});
				$shell_call = "clusvcadm -e vm:$vm -m $node_cluster_name";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
					name2 => "node",       value2 => $node,
				}, file => $THIS_FILE, line => __LINE__});
				($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$node,
					port		=>	$an->data->{node}{$node}{port}, 
					password	=>	$password,
					ssh_fh		=>	"",
					'close'		=>	0,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
					
					$line = parse_text_line($an, $line);
					if ($line =~ /Fail/i)
					{
						# The VM failed to start. Call a stop against it.
						print $an->Web->template({file => "server.html", template => "start-server-failed-again"});
					}
					elsif ($line =~ /Success/i)
					{
						# Worked.
						$server_started = 1;
					}
					my $message = ($line =~ /^(.*)\[/)[0];
					my $status  = ($line =~ /(\[.*)$/)[0];
					if (not $message)
					{
						$message = $line;
						$status  = "";
					}
					print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
						status	=>	$status,
						message	=>	$message,
					}});
				}
			}
			   $line    = parse_text_line($an, $line);
			my $message = ($line =~ /^(.*)\[/)[0];
			my $status  = ($line =~ /(\[.*)$/)[0];
			if (not $message)
			{
				$message = $line;
				$status  = "";
			}
			print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
				status	=>	$status,
				message	=>	$message,
			}});
		}
		
		# Clear the 'clean' off state if we have a DB connection.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "server_started",      value1 => $server_started,
			name2 => "sys::db_connections", value2 => $an->data->{sys}{db_connections},
		}, file => $THIS_FILE, line => __LINE__});
		if (($server_started) && ($an->data->{sys}{db_connections}))
		{
			my $return = $an->Get->server_data({
				server => $say_vm, 
				anvil  => $cluster, 
			});
			my $server_uuid = $return->{uuid};
			
			my $query = "
UPDATE 
    servers 
SET 
    server_stop_reason = '', 
    modified_date      = ".$an->data->{sys}{use_db_fh}->quote($an->data->{sys}{db_timestamp})." 
WHERE 
    server_uuid = ".$an->data->{sys}{use_db_fh}->quote($server_uuid)."
;";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "query", value1 => $query
			}, file => $THIS_FILE, line => __LINE__});
			$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
		}
		
		print $an->Web->template({file => "server.html", template => "start-server-output-footer"});
		if ($show_remote_desktop_link)
		{
			### Disabled
		}
		print $an->Web->template({file => "server.html", template => "start-server-footer"});
	}
	else
	{
		# The target node is not ready to run a server.
		my $say_title = $an->String->get({key => "title_0048", variables => { 
				server		=>	$vm,
				node_anvil_name	=>	$node_cluster_name,
			}});
		my $say_message = $an->String->get({key => "message_0184", variables => { 
				node_anvil_name	=>	$node_cluster_name,
				server		=>	$vm,
			}});
		print $an->Web->template({file => "server.html", template => "start-server-node-not-ready", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});
	}
	
	return(0);
}

# This tries to parse lines coming back from a shell call to add highlighting and what-not.
sub parse_text_line
{
	my ($an, $line) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "parse_text_line" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "line", value1 => $line, 
	}, file => $THIS_FILE, line => __LINE__});
	
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
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "line", value1 => $line,
	}, file => $THIS_FILE, line => __LINE__});
	return($line);
}

# This migrates a VM to the target node.
sub migrate_vm
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "migrate_vm" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $server = $an->data->{cgi}{vm};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "server", value1 => $server,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $output = $an->Cman->migrate_server({server => $server});
	
	foreach my $line (split/\n/, $output)
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		$line = parse_text_line($an, $line);
		my $message = ($line =~ /^(.*)\[/)[0];
		my $status  = ($line =~ /(\[.*)$/)[0];
		if (not $message)
		{
			$message = $line;
			$status  = "";
		}
		print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
			status	=>	$status,
			message	=>	$message,
		}});
		
	}
	
	return(0);
}

# This sttempts to shut down a VM on a target node.
sub stop_vm
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "stop_vm" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $server = $an->data->{cgi}{vm};
	my $reason = $an->data->{sys}{stop_reason} ? $an->data->{sys}{stop_reason} : "";
	
	if (time > $an->data->{cgi}{expire})
	{
		# Abort!
		my $say_title   = $an->String->get({key => "title_0185"});
		my $say_message = $an->String->get({key => "message_0444", variables => { server => $an->data->{cgi}{vm} }});
		print $an->Web->template({file => "server.html", template => "request-expired", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});
		return(1);
	}
	
	my $output = $an->Cman->stop_server({
			server => $server, 
			reason => $reason,
		});
	foreach my $line (split/\n/, $output)
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		#$line =~ s/Local machine/$say_node/;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$line = parse_text_line($an, $line);
		my $message = ($line =~ /^(.*)\[/)[0];
		my $status  = ($line =~ /(\[.*)$/)[0];
		if (not $message)
		{
			$message = $line;
			$status  = "";
		}
		print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
			status	=>	$status,
			message	=>	$message,
		}});
	}
	print $an->Web->template({file => "server.html", template => "stop-server-footer"});
	
	return(0);
}

# This sttempts to shut down a VM on a target node.
sub join_cluster
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "join_cluster" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	my $proceed           = 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "in join_cluster(), node", value1 => $node,
		name2 => "node_cluster_name",       value2 => $node_cluster_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# This, more than 
	AN::Cluster::scan_cluster($an);
	
	# Proceed only if all of the storage components, cman and rgmanager are
	# off.
	if (($an->data->{node}{$node}{daemon}{cman}{exit_code} ne "0") ||
	($an->data->{node}{$node}{daemon}{rgmanager}{exit_code} ne "0") ||
	($an->data->{node}{$node}{daemon}{drbd}{exit_code} ne "0") ||
	($an->data->{node}{$node}{daemon}{clvmd}{exit_code} ne "0") ||
	($an->data->{node}{$node}{daemon}{gfs2}{exit_code} ne "0") ||
	($an->data->{node}{$node}{daemon}{libvirtd}{exit_code} ne "0"))
	{
		$proceed = 1;
	}
	if ($proceed)
	{
		my $say_title = $an->String->get({key => "title_0052", variables => { 
				node_anvil_name	=>	$node_cluster_name,
				anvil		=>	$an->data->{cgi}{cluster},
			}});
		print $an->Web->template({file => "server.html", template => "join-anvil-header", replace => { title => $say_title }});
		my $shell_call = "/etc/init.d/cman start && /etc/init.d/rgmanager start";
		my $password   = $an->data->{sys}{root_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			$line = parse_text_line($an, $line);
			my $message = ($line =~ /^(.*)\[/)[0];
			my $status  = ($line =~ /(\[.*)$/)[0];
			if (not $message)
			{
				$message = $line;
				$status  = "";
			}
			print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
				status	=>	$status,
				message	=>	$message,
			}});
		}
		print $an->Web->template({file => "server.html", template => "join-anvil-footer"});
	}
	else
	{
		# Node is already in the Anvil!
		my $say_title = $an->String->get({key => "title_0053", variables => { 
				node_anvil_name	=>	$node_cluster_name,
				anvil		=>	$an->data->{cgi}{cluster},
			}});
		print $an->Web->template({file => "server.html", template => "join-anvil-aborted", replace => { title => $say_title }});
	}
	
	return(0);
}

# This sttempts to start the cluster stack on both nodes simultaneously.
sub dual_join
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "dual_join" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $cluster = $an->data->{cgi}{cluster};
	my $proceed = 1;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "in dual_join(), cluster", value1 => $cluster,
	}, file => $THIS_FILE, line => __LINE__});
	
	# This, more than 
	AN::Cluster::scan_cluster($an);
	
	# Proceed only if all of the storage components, cman and rgmanager are off.
	my @abort_reason;
	foreach my $node (sort {$a cmp $b} @{$an->data->{clusters}{$cluster}{nodes}})
	{
		if (($an->data->{node}{$node}{daemon}{cman}{exit_code} eq "0") ||
		($an->data->{node}{$node}{daemon}{rgmanager}{exit_code} eq "0") ||
		($an->data->{node}{$node}{daemon}{drbd}{exit_code} eq "0") ||
		($an->data->{node}{$node}{daemon}{clvmd}{exit_code} eq "0") ||
		($an->data->{node}{$node}{daemon}{gfs2}{exit_code} eq "0"))
		{
			$proceed = 0;
			# Already joined the Anvil!
			my $reason = $an->String->get({key => "message_0190", variables => { node => $node }});
			push @abort_reason, $reason;
		}
	}
	if ($proceed)
	{
		my $say_title = $an->String->get({key => "title_0054", variables => { anvil => $an->data->{cgi}{cluster} }});
		print $an->Web->template({file => "server.html", template => "dual-join-anvil-header", replace => { title => $say_title }});

		# Now call the command against both nodes using '$an->Remote->synchronous_command_run()'.
		my $command         = "/etc/init.d/cman start && /etc/init.d/rgmanager start";
		my ($node1, $node2) = @{$an->data->{clusters}{$cluster}{nodes}};
		my $password        = $an->data->{sys}{root_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "command", value1 => $command,
			name2 => "node1",   value2 => $node1,
			name3 => "node2",   value3 => $node2,
		}, file => $THIS_FILE, line => __LINE__});
		my ($output) = $an->Remote->synchronous_command_run({
			command		=>	$command, 
			node1		=>	$node1, 
			node2		=>	$node2, 
			delay		=>	0,
			password	=>	$password, 
		});
		
		foreach my $node (sort {$a cmp $b} @{$an->data->{clusters}{$cluster}{nodes}})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "node",             value1 => $node,
				name2 => "output->{\$node}", value2 => $output->{$node},
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $line (split/\n/, $output->{$node})
			{
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				$line =~ s/\s+/ /g;
				next if not $line;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				$line = parse_text_line($an, $line);
				my $message = ($line =~ /^(.*)\[/)[0];
				my $status  = ($line =~ /(\[.*)$/)[0];
				if (not $message)
				{
					$message = $line;
					$status  = "";
				}
				print $an->Web->template({file => "server.html", template => "dual-join-anvil-output", replace => { 
					node	=>	$node,
					message	=>	$message,
					status	=>	$status,
				}});
			}
		}
		
		# We're done.
		$an->Log->entry({log_level => 2, message_key => "log_0125", file => $THIS_FILE, line => __LINE__});
		print $an->Web->template({file => "server.html", template => "dual-join-anvil-footer"});
	}
	else
	{
		my $say_title = $an->String->get({key => "title_0055", variables => { anvil => $an->data->{cgi}{cluster} }});
		print $an->Web->template({file => "server.html", template => "dual-join-anvil-aborted-header", replace => { title => $say_title }});
		foreach my $reason (@abort_reason)
		{
			print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $reason }});
		}
		print $an->Web->template({file => "server.html", template => "dual-join-anvil-aborted-footer"});
	}
	
	return(0);
}

# This forcibly shuts down a VM on a target node. The cluster should restart it shortly after.
sub force_off_vm
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "force_off_vm" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node = $an->data->{cgi}{node};
	my $vm   = $an->data->{cgi}{vm};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "in force_off_vm(), vm", value1 => $vm,
		name2 => "node",                  value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Has the timer expired?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "current time", value1 => time,
		name2 => "cgi::expire",  value2 => $an->data->{cgi}{expire},
	}, file => $THIS_FILE, line => __LINE__});
	if (time > $an->data->{cgi}{expire})
	{
		# Abort!
		my $say_title   = $an->String->get({key => "title_0186"});
		my $say_message = $an->String->get({key => "message_0445", variables => { server => $an->data->{cgi}{vm} }});
		print $an->Web->template({file => "server.html", template => "request-expired", replace => { 
			title		=>	$say_title,
			message		=>	$say_message,
		}});
		return(1);
	}
	
	AN::Cluster::scan_cluster($an);
	my $say_title = $an->String->get({key => "title_0056", variables => { server => $vm }});
	print $an->Web->template({file => "server.html", template => "force-off-server-header", replace => { title => $say_title }});
	my $shell_call = "/usr/bin/virsh destroy $vm";
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$line = parse_text_line($an, $line);
		my $message = ($line =~ /^(.*)\[/)[0];
		my $status  = ($line =~ /(\[.*)$/)[0];
		if (not $message)
		{
			$message = $line;
			$status  = "";
		}
		print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
			status	=>	$status,
			message	=>	$message,
		}});
	}
	print $an->Web->template({file => "server.html", template => "force-off-server-footer"});
	
	return(0);
}

# This stops the VM, if it's running, edits the cluster.conf to remove the VM's entry, pushes the changed 
# cluster out, deletes the VM's definition file and finally deletes the LV.
sub delete_vm
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "delete_vm" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $cluster = $an->data->{cgi}{cluster};
	my $say_vm  = $an->data->{cgi}{vm};
	my $vm      = "vm:$an->data->{cgi}{vm}";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "in delete_vm(), vm", value1 => $vm,
		name2 => "cluster",            value2 => $cluster,
	}, file => $THIS_FILE, line => __LINE__});
	
	# This, more than ... what? what was I going to say here?!
	AN::Cluster::scan_cluster($an);
	my $proceed      = 1;
	my $stop_vm      = 0;
	my $say_host     = "";
	my $host         = "";
	my $abort_reason = "";
	my $node         = $an->data->{sys}{cluster}{node1_name};
	my $node1        = $an->data->{sys}{cluster}{node1_name};
	my $node2        = $an->data->{sys}{cluster}{node2_name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "vm::${vm}::host", value1 => $an->data->{vm}{$vm}{host},
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->data->{vm}{$vm}{host})
	{
		$proceed      = 0;
		# Failed to read the server's details.
		my $sat_problem  = $an->String->get({key => "message_0195", variables => { server => $say_vm }});
		   $abort_reason = "<b>$sat_problem!</b><br />#!string!message_0194!#<br />#!string!explain_0035!#<br />#!string!brand_0011!#<br />";
	}
	elsif ($an->data->{vm}{$vm}{host} ne "none")
	{
		$stop_vm  = 1;
		$say_host = $an->data->{vm}{$vm}{host};
		$host     = long_host_name_to_node_name($an, $an->data->{vm}{$vm}{host});
	}
	else
	{
		# Pick the first up node to use.
		if ($an->data->{node}{$node1}{up})
		{
			$host = $node1;
		}
		elsif ($an->data->{node}{$node2}{up})
		{
			$host = $node2;
		}
		else
		{
			$proceed      = 0;
			# Neither node is online.
			$abort_reason = $an->String->get({key => "message_0196", variables => { server => $say_vm }});
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "proceed", value1 => $proceed,
		name2 => "host",    value2 => $host,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Get to work!
	my $say_title = $an->String->get({key => "title_0057", variables => { server => $vm }});
	print $an->Web->template({file => "server.html", template => "delete-server-header", replace => { title => $say_title }});
	
	# We have to remove the server from the cluster *before* we force it off. Otherwise, the cluster will
	# boot it right back up.
	if ($proceed)
	{
		print $an->Web->template({file => "server.html", template => "delete-server-start"});
		### Note: I don't use 'path' for these calls as the location of a program on the cluster may
		###       differ from the local copy. Further, I will have $PATH on the far side of the ssh
		###       call anyway. 
		# First, delete the VM from the cluster.
		my $ccs_exit_code;
		   $proceed = 0;
		my $shell_call = "ccs -h localhost --activate --sync --password \"".$an->data->{clusters}{$cluster}{ricci_pw}."\" --rmvm $an->data->{cgi}{vm}; echo ccs:\$?";
		my $password   = $an->data->{sys}{root_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			next if not $line;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /ccs:(\d+)/)
			{
				$ccs_exit_code = $1;
			}
			else
			{
				$line = parse_text_line($an, $line);
				print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
			}
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "ccs exit code", value1 => $ccs_exit_code,
		}, file => $THIS_FILE, line => __LINE__});
		if ($ccs_exit_code eq "0")
		{
			print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => "#!string!message_0197!#" }});
			$proceed = 1;
		}
		else
		{
			my $say_error = $an->String->get({key => "message_0198", variables => { ccs_exit_code => $ccs_exit_code }});
			print $an->Web->template({file => "server.html", template => "delete-server-bad-exit-code", replace => { error => $say_error }});
		}
		print $an->Web->template({file => "server.html", template => "delete-server-start-footer"});
		
		my $stop_exit_code;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "stop_vm",       value1 => $stop_vm,
			name2 => "ccs_exit_code", value2 => $ccs_exit_code,
		}, file => $THIS_FILE, line => __LINE__});
		if (($stop_vm) && ($ccs_exit_code eq "0"))
		{
			# Server is still running, kill it.
			print $an->Web->template({file => "server.html", template => "delete-server-force-off-header"});
			
			   $proceed = 0;
			my $virsh_exit_code;
			my $shell_call = "/usr/bin/virsh destroy $say_vm; echo virsh:\$?";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "node",       value2 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$node,
				port		=>	$an->data->{node}{$node}{port}, 
				password	=>	$password,
				ssh_fh		=>	"",
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				next if not $line;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /virsh:(\d+)/)
				{
					$virsh_exit_code = $1;
				}
				else
				{
					$line = parse_text_line($an, $line);
					print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
				}
			}
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "virsh exit code", value1 => $virsh_exit_code,
			}, file => $THIS_FILE, line => __LINE__});
			if ($virsh_exit_code eq "0")
			{
				print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => "#!string!message_0199!#" }});
				$proceed = 1;
			}
			else
			{
				# This is fatal
				my $say_error = $an->String->get({key => "message_0200", variables => { virsh_exit_code => $virsh_exit_code }});
				print $an->Web->template({file => "server.html", template => "delete-server-bad-exit-code", replace => { error => $say_error }});
				$proceed = 0;
			}
			print $an->Web->template({file => "server.html", template => "delete-server-force-off-footer"});
		}
		
		# Now delete the backing LVs
		if ($proceed)
		{
			# Free up the storage
			print $an->Web->template({file => "server.html", template => "delete-server-remove-lv-header"});
			foreach my $lv (keys %{$an->data->{vm}{$vm}{node}{$node}{lv}})
			{
				my $message = $an->String->get({key => "message_0201", variables => { lv => $lv }});
				print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $message }});
				my $lvremove_exit_code;
				my $shell_call = "lvremove -f $lv; echo lvremove:\$?";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
					name2 => "node",       value2 => $node,
				}, file => $THIS_FILE, line => __LINE__});
				my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$node,
					port		=>	$an->data->{node}{$node}{port}, 
					password	=>	$password,
					ssh_fh		=>	"",
					'close'		=>	0,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					next if not $line;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
					
					if ($line =~ /lvremove:(\d+)/)
					{
						$lvremove_exit_code = $1;
					}
					else
					{
						print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
					}
				}
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "lvremove exit code", value1 => $lvremove_exit_code,
				}, file => $THIS_FILE, line => __LINE__});
				if ($lvremove_exit_code eq "0")
				{
					print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => "#!string!message_0202!#" }});
				}
				else
				{
					my $say_error = $an->String->get({key => "message_0204", variables => { lvremove_exit_code => $lvremove_exit_code }});
					print $an->Web->template({file => "server.html", template => "delete-server-bad-exit-code", replace => { error => $say_error }});
				}
			}
			
			# Regardless of whether the removal succeeded, archive
			# and then delete the definition file.
			my $file = $an->data->{vm}{$vm}{definition_file};
			archive_file($an, $host, $file, 0, "hidden_table");
			remove_vm_definition($an, $host, $file);
			
			# Remove it from the database now if we have a database connection.
			if ($an->data->{sys}{db_connections})
			{
				# Mark it as deleted.
				my $return = $an->Get->server_data({
					server => $say_vm, 
					anvil  => $cluster, 
				});
				my $server_uuid = $return->{uuid};
				my $query       = "
UPDATE 
    servers 
SET 
    server_name = 'DELETED' 
WHERE 
    server_uuid = ".$an->data->{sys}{use_db_fh}->quote($server_uuid)."
;";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "query", value1 => $query
				}, file => $THIS_FILE, line => __LINE__});
				$an->DB->do_db_write({query => $query, source => $THIS_FILE, line => __LINE__});
			}
			
			my $message = $an->String->get({key => "message_0205", variables => { server => $say_vm }});
			print $an->Web->template({file => "server.html", template => "delete-server-success", replace => { message => $message }});
		}
	}
	else
	{
		print $an->Web->template({file => "server.html", template => "delete-server-abort-reason", replace => { abort_reason => $abort_reason }});
	}
	print $an->Web->template({file => "server.html", template => "delete-server-footer"});
	
	return(0);
}

# This deletes a VM definition file.
sub remove_vm_definition
{
	my ($an, $node, $file) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "remove_vm_definition" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node", value1 => $node, 
		name2 => "file", value2 => $file, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# We only delete server definition files.
	if ($file !~ /^\/shared\/definitions\/.*?\.xml/)
	{
		# We will only touch files in /shared/definitions.
		my $message = $an->String->get({key => "message_0207", variables => { file => $file }});
		print $an->Web->template({file => "server.html", template => "remove-vm-definition-wrong-definition-file", replace => { message => $message }});
		return (1);
	}
	
	# 'rm' seems to return '0' no matter what. So I use the 'ls' to ensure
	# the file is gone. 'ls' will return '2' on file not found.
	my $ls_exit_code;
	my $shell_call = "rm -f $file; ls $file; echo ls:\$?";
	my $password   = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /ls:(\d+)/)
		{
			$ls_exit_code = $1;
		}
		else
		{
			### There will be output, I don't care about it.
			#$line = parse_text_line($an, $line);
			#print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ls exit code", value1 => $ls_exit_code,
	}, file => $THIS_FILE, line => __LINE__});
	if ($ls_exit_code eq "2")
	{
		# File deleted successfully.
		my $message = $an->String->get({key => "message_0209", variables => { file => $file }});
		print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $message }});
	}
	else
	{
		# Delete seems to have failed
		my $message = $an->String->get({key => "message_0210", variables => { 
			file		=>	$file,
			ls_exit_code	=>	$ls_exit_code,
		}});
		print $an->Web->template({file => "server.html", template => "remove-vm-definition-failed", replace => { message => $message }});
	}
	
	return (0);
}

# This copies the passed file to 'node:/shared/archive'
sub archive_file
{
	my ($an, $node, $file, $quiet, $table_type) = @_;
	$table_type = "hidden_table" if not $table_type;
	$quiet      = 0 if not defined $quiet;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "archive_file" }, message_key => "an_variables_0004", message_variables => { 
		name1 => "node",       value1 => $node, 
		name2 => "file",       value2 => $file, 
		name3 => "quiet",      value3 => $quiet, 
		name4 => "table_type", value4 => $table_type, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: Check/create the archive directory.
	
	my ($directory, $file_name) =  ($file =~ /^(.*)\/(.*?)$/);
	my ($date)                  =  $an->Get->date_and_time({split_date_time => 0});
	my $destination             =  "/shared/archive/$file_name.$date";
	   $destination             =~ s/ /_/;

	my $cp_exit_code;
	my $header_printed = 0;
	my $shell_call     = "cp $file $destination; echo cp:\$?";
	my $password       = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		next if not $line;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /cp:(\d+)/)
		{
			$cp_exit_code = $1;
		}
		else
		{
			if (not $header_printed)
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "table_type", value1 => $table_type,
				}, file => $THIS_FILE, line => __LINE__});
				if ($table_type eq "hidden_table")
				{
					print $an->Web->template({file => "server.html", template => "one-line-message-header-hidden"});
				}
				else
				{
					print $an->Web->template({file => "server.html", template => "one-line-message-header"});
				}
				$header_printed = 1;
			}
			$line = parse_text_line($an, $line);
			print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
		}
	}
	if ($header_printed)
	{
		print $an->Web->template({file => "server.html", template => "one-line-message-footer"});
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cp exit code", value1 => $cp_exit_code,
	}, file => $THIS_FILE, line => __LINE__});
	if ($cp_exit_code eq "0")
	{
		# Success
		if (not $quiet)
		{
			if ($table_type eq "hidden_table")
			{
				print $an->Web->template({file => "server.html", template => "one-line-message-header-hidden"});
			}
			else
			{
				print $an->Web->template({file => "server.html", template => "one-line-message-header"});
			}
			my $message = $an->String->get({key => "message_0211", variables => { 
					file		=>	$file,
					destination	=>	$destination,
				}});
			print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $message }});
			print $an->Web->template({file => "server.html", template => "one-line-message-footer"});
		}
		$an->Log->entry({log_level => 2, message_key => "log_0242", message_variables => {
			file        => $file, 
			destination => $destination, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Failure
		my $message = $an->String->get({key => "message_0212", variables => { 
			file		=>	$file,
			destination	=>	$destination,
			cp_exit_code	=>	$cp_exit_code,
		}});
		print $an->Web->template({file => "server.html", template => "archive-file-failed", replace => { message => $message }});
		$destination = 0;
	}
	
	return ($destination);
}

# This makes an ssh call to the node and sends a simple 'poweroff' command.
sub poweroff_node
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "poweroff_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make sure no VMs are running.
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	
	# Has the timer expired?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "current time", value1 => time,
		name2 => "cgi::expire",  value2 => $an->data->{cgi}{expire},
	}, file => $THIS_FILE, line => __LINE__});
	if (time > $an->data->{cgi}{expire})
	{
		# Abort!
		my $say_title   = $an->String->get({key => "title_0187"});
		my $say_message = $an->String->get({key => "message_0446", variables => { node => $an->data->{cgi}{node_cluster_name} }});
		print $an->Web->template({file => "server.html", template => "request-expired", replace => { 
			title		=>	$say_title,
			message		=>	$say_message,
		}});
		return(1);
	}
	
	# Scan the cluster, then confirm that withdrawl is still enabled.
	AN::Cluster::scan_cluster($an);
	my $proceed = $an->data->{node}{$node}{enable_poweroff};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "in poweroff_node(), node", value1 => $node,
		name2 => "proceed",                  value2 => $proceed,
	}, file => $THIS_FILE, line => __LINE__});
	if ($proceed)
	{
		# Call the 'poweroff'.
		my $say_title   = $an->String->get({key => "title_0061", variables => { node_anvil_name => $node_cluster_name }});
		my $say_message = $an->String->get({key => "message_0213", variables => { node_anvil_name => $node_cluster_name }});
		print $an->Web->template({file => "server.html", template => "poweroff-node-header", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});
		
		# Tell ScanCore that we're cleanly shutting down so we don't auto-reboot the node.
		$an->Striker->mark_node_as_clean_off({node_uuid => $an->data->{sys}{name_to_uuid}{$node}});
		
		my $shell_call = "poweroff && echo \"Power down initiated. Please return to the main page now.\"";
		my $password   = $an->data->{sys}{root_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			$line = parse_text_line($an, $line);
			my $message = ($line =~ /^(.*)\[/)[0];
			my $status  = ($line =~ /(\[.*)$/)[0];
			if (not $message)
			{
				$message = $line;
				$status  = "";
			}
			print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
				status	=>	$status,
				message	=>	$message,
			}});
		}
		print $an->Web->template({file => "server.html", template => "poweroff-node-footer"});
	}
	else
	{
		# Aborted, in use now.
		my $say_title   = $an->String->get({key => "title_0062", variables => { node_anvil_name => $an->data->{cgi}{node_cluster_name} }});
		my $say_message = $an->String->get({key => "message_0214", variables => { node_anvil_name => $an->data->{cgi}{node_cluster_name} }});
		print $an->Web->template({file => "server.html", template => "poweroff-node-aborted", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});
	}
	
	AN::Cluster::footer($an);
	return(0);
}

# This sequentially stops all servers, withdraws both nodes and powers down the Anvil!.
sub cold_stop_anvil
{
	my ($an, $cancel_ups) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "cold_stop_anvil" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "cancel_ups", value1 => $cancel_ups, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $anvil   = $an->data->{cgi}{cluster};
	my $proceed = 1;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil", value1 => $anvil,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Has the timer expired?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "current time", value1 => time,
		name2 => "cgi::expire",  value2 => $an->data->{cgi}{expire},
	}, file => $THIS_FILE, line => __LINE__});
	if (time > $an->data->{cgi}{expire})
	{
		# Abort!
		my $say_title   = $an->String->get({key => "title_0184"});
		my $say_message = $an->String->get({key => "message_0443", variables => { anvil => $an->data->{cgi}{cluster} }});
		print $an->Web->template({file => "server.html", template => "request-expired", replace => { 
			title		=>	$say_title,
			message		=>	$say_message,
		}});
		return(1);
	}
	
	# Make sure we've got an up-to-date view of the cluster.
	AN::Cluster::scan_cluster($an);
	
	# If the system is already down, the user may be asking to power cycle/ power off the rack anyway.
	# So if the Anvil! is down, we'll instead perform the requested sub-task using our local copy of the
	# kick script.
	if ($an->data->{sys}{up_nodes} > 0)
	{
		my $say_title = $an->String->get({key => "title_0181", variables => { anvil => $anvil }});
		print $an->Web->template({file => "server.html", template => "cold-stop-header", replace => { title => $say_title }});
		
		# Pick a node to use to stop servers.
		my $node = $an->data->{up_nodes}->[0];
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node", value1 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Now find and stop all servers.
		foreach my $server (sort {$a cmp $b} keys %{$an->data->{vm}})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "server", value1 => $server,
				name2 => "host",   value2 => $an->data->{vm}{$server}{host},
				name3 => "state",  value3 => $an->data->{vm}{$server}{'state'},
			}, file => $THIS_FILE, line => __LINE__});
			if ($an->data->{vm}{$server}{'state'} eq "started")
			{
				# Stop the server
				my $say_server  =  $server;
				   $say_server  =~ s/^vm://;
				my $say_message =  $an->String->get({key => "message_0420", variables => { server => $say_server }});
				print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
					row_class	=>	"highlight_detail_bold",
					row		=>	"#!string!row_0270!#",
					message_class	=>	"td_hidden_white",
					message		=>	"$say_message",
				}});
				
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "server", value1 => $server,
				}, file => $THIS_FILE, line => __LINE__});
				my $shell_output = "";
				my $shell_call   = $an->data->{path}{clusvcadm}." -d $server";
				my $password     = $an->data->{sys}{root_password};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
					name2 => "node",       value2 => $node,
				}, file => $THIS_FILE, line => __LINE__});
				my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$node,
					port		=>	$an->data->{node}{$node}{port}, 
					password	=>	$password,
					ssh_fh		=>	"",
					'close'		=>	0,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					$line =~ s/Local machine/$node/;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
					
					$line =  parse_text_line($an, $line);
					$shell_output .= "$line<br />\n";
					if ($line =~ /success/i)
					{
						$an->data->{vm}{$server}{'state'} = "disabled";
					}
				}
				$shell_output =~ s/\n$//;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "shell_output", value1 => $shell_output,
				}, file => $THIS_FILE, line => __LINE__});
				print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
					row_class	=>	"code",
					row		=>	"#!string!row_0127!#",
					message_class	=>	"quoted_text",
					message		=>	$shell_output,
				}});
			}
		}
		
		# Servers down?
		my $proceed = 1;
		foreach my $server (sort {$a cmp $b} keys %{$an->data->{vm}})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "server", value1 => $server,
				name2 => "host",   value2 => $an->data->{vm}{$server}{host},
				name3 => "state",  value3 => $an->data->{vm}{$server}{'state'},
			}, file => $THIS_FILE, line => __LINE__});
			if ($an->data->{vm}{$server}{'state'} eq "started")
			{
				# Well crap...
				$an->Log->entry({log_level => 2, message_key => "log_0243", message_variables => {
					server => $server, 
				}, file => $THIS_FILE, line => __LINE__});
				   $proceed     =  0;
				my $say_server  =  $server;
				   $say_server  =~ s/^vm://;
				my $say_message =  $an->String->get({key => "message_0421", variables => { server => $say_server }});
				print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
					row_class	=>	"highlight_detail_bold",
					row		=>	"#!string!row_0270!#",
					message_class	=>	"td_hidden_white",
					message		=>	"$say_message",
				}});
			}
			else
			{
				# Server is down. 
				# https://www.youtube.com/watch?v=O4gqsuww6lw
				$an->Log->entry({log_level => 2, message_key => "log_0248", message_variables => {
					server => $server, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		if ($proceed)
		{
			# All servers are down.
			print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
				row_class	=>	"highlight_good_bold",
				row		=>	"#!string!row_0083!#",
				message_class	=>	"td_hidden_white",
				message		=>	"#!string!message_0422!#",
			}});
			
			# Now withdraw both nodes from the cluster, if they're up.
			foreach my $node (@{$an->data->{up_nodes}})
			{
				# rc == 0 -> up
				$an->Log->entry({log_level => 2, message_key => "log_0244", message_variables => {
					node        => $node, 
					return_code => $an->data->{node}{$node}{daemon}{cman}{exit_code}, 
				}, file => $THIS_FILE, line => __LINE__});
				if ($an->data->{node}{$node}{daemon}{cman}{exit_code})
				{
					# Was already withdrawn.
					$an->Log->entry({log_level => 2, message_key => "log_0245", message_variables => {
						node => $node, 
					}, file => $THIS_FILE, line => __LINE__});
					my $say_message = $an->String->get({key => "message_0424", variables => { node => $node }});
					print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
						row_class	=>	"highlight_good_bold",
						row		=>	"#!string!row_0271!#",
						message_class	=>	"td_hidden_white",
						message		=>	"$say_message",
					}});
				}
				else
				{
					# Withdraw
					$an->Log->entry({log_level => 2, message_key => "log_0246", file => $THIS_FILE, line => __LINE__});
					my $say_message = $an->String->get({key => "message_0425", variables => { node => $node }});
					print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
						row_class	=>	"highlight_good_bold",
						row		=>	"#!string!row_0271!#",
						message_class	=>	"td_hidden_white",
						message		=>	"$say_message",
					}});

					# Disable
					$an->Log->entry({log_level => 2, message_key => "log_0247", message_variables => {
						node => $node, 
					}, file => $THIS_FILE, line => __LINE__});
					my $shell_output = "";
					my $shell_call   = "/etc/init.d/rgmanager stop && /etc/init.d/cman stop; echo rc:\$?";
					my $password     = $an->data->{sys}{root_password};
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "shell_call", value1 => $shell_call,
						name2 => "node",       value2 => $node,
					}, file => $THIS_FILE, line => __LINE__});
					my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
						target		=>	$node,
						port		=>	$an->data->{node}{$node}{port}, 
						password	=>	$password,
						ssh_fh		=>	"",
						'close'		=>	0,
						shell_call	=>	$shell_call,
					});
					foreach my $line (@{$return})
					{
						$line =~ s/^\s+//;
						$line =~ s/\s+$//;
						$line =~ s/\s+/ /g;
						$line =~ s/Local machine/$node/;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line, 
						}, file => $THIS_FILE, line => __LINE__});
						
						if ($line =~ /rc:(\d+)/i)
						{
							my $rc = $1;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "rc", value1 => $rc,
							}, file => $THIS_FILE, line => __LINE__});
							if ($rc)
							{
								# Unexpected return code
								$an->Log->entry({log_level => 1, message_key => "log_0249", message_variables => {
									node        => $node, 
									return_code => $rc, 
								}, file => $THIS_FILE, line => __LINE__});
								$proceed = 0;
							}
						}
						else
						{
							$line =  parse_text_line($an, $line);
							$shell_output .= "$line<br />\n";
						}
					}
					$shell_output =~ s/\n$//;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "shell_output", value1 => $shell_output,
					}, file => $THIS_FILE, line => __LINE__});
					print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
						row_class	=>	"code",
						row		=>	"#!string!row_0127!#",
						message_class	=>	"quoted_text",
						message		=>	$shell_output,
					}});
				}
			}
			
			# Safe to power off?
			if ($proceed)
			{
				### Yup!
				# Tell ScanCore that we're cleanly shutting down so we don't auto-reboot the 
				# node. If we're powering off or power cycling the system, tell 
				# $an->Striker->mark_node_as_clean_off()' to set a delay instead of "clean"
				# (off).
				my $delay = 0;
				if (($an->data->{cgi}{subtask} eq "power_cycle") or ($an->data->{cgi}{subtask} eq "power_off"))
				{
					# Set the delay. This will set the hosts -> host_stop_reason
					# to be time + sys::power_off_delay.
					$delay = 1;
				}
				
				print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
					row_class	=>	"highlight_good_bold",
					row		=>	"#!string!row_0083!#",
					message_class	=>	"td_hidden_white",
					message		=>	"#!string!message_0427!#",
				}});
				
				# Now withdraw both nodes from the cluster, if they're up.
				foreach my $node (@{$an->data->{up_nodes}})
				{
					# Mark it as clean-off
					$an->Log->entry({log_level => 2, message_key => "log_0250", message_variables => {
						node  => $node, 
						delay => $delay, 
					}, file => $THIS_FILE, line => __LINE__});
					$an->Striker->mark_node_as_clean_off({node_uuid => $an->data->{sys}{name_to_uuid}{$node}, delay => $delay});
					
					# Power it off
					$an->Log->entry({log_level => 1, message_key => "log_0251", message_variables => {
						node => $node, 
					}, file => $THIS_FILE, line => __LINE__});
					my $say_message = $an->String->get({key => "message_0430", variables => { node => $node }});
					print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
						row_class	=>	"highlight_good_bold",
						row		=>	"#!string!row_0272!#",
						message_class	=>	"td_hidden_white",
						message		=>	"$say_message",
					}});
					$an->Log->entry({log_level => 2, message_key => "log_0247", message_variables => {
						node => $node, 
					}, file => $THIS_FILE, line => __LINE__});
					
					# If 'cancel_ups' is '1' or '2', I will stop the UPS timer. In '2', 
					# We'll call the poweroff from here once the nodes are down.
					my $shell_call = "poweroff";
					if ($cancel_ups)
					{
						$shell_call = "
if [ -e '$an->data->{path}{nodes}{'anvil-kick-apc-ups'}' ]
then
    echo 'Cancelling APC UPS watchdog timer.'
    $an->data->{path}{nodes}{'anvil-kick-apc-ups'} --cancel --force
fi;
poweroff";
					}
					my $password   = $an->data->{sys}{root_password};
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "shell_call", value1 => $shell_call,
						name2 => "node",       value2 => $node,
					}, file => $THIS_FILE, line => __LINE__});
					my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
						target		=>	$node,
						port		=>	$an->data->{node}{$node}{port}, 
						password	=>	$password,
						ssh_fh		=>	"",
						'close'		=>	0,
						shell_call	=>	$shell_call,
					});
					foreach my $line (@{$return})
					{
						# Only output should be from the stopping of the APC UPS 
						# watchdog app.
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line, 
						}, file => $THIS_FILE, line => __LINE__});
					}
					my $message = "#!string!message_0436!#";
					if ($cancel_ups eq "1")
					{
						$message = "#!string!message_0428!#";
					}
					print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
						row_class	=>	"highlight_detail_bold",
						row		=>	"#!string!row_0273!#",
						message_class	=>	"td_hidden_white",
						message		=>	$message,
					}});
				}
				# All done!
				print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
					row_class	=>	"highlight_good_bold",
					row		=>	"#!string!row_0083!#",
					message_class	=>	"td_hidden_white",
					message		=>	"#!string!message_0429!#",
				}});
			}
			else
			{
				# Nope. :(
				print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
					row_class	=>	"highlight_warning_bold",
					row		=>	"#!string!row_0129!#",
					message_class	=>	"td_hidden_white",
					message		=>	"#!string!message_0426!#",
				}});
			}
		}
		else
		{
			# One or more nodes are still up...
			print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
				row_class	=>	"highlight_warning_bold",
				row		=>	"#!string!row_0129!#",
				message_class	=>	"td_hidden_white",
				message		=>	"#!string!message_0423!#",
			}});
		}
	}
	elsif ($an->data->{cgi}{note} eq "no_abort")
	{
		# The user called this while the Anvil! was down, so don't throw a warning.
		my $say_subtask = $an->data->{cgi}{subtask} eq "power_cycle" ? "#!string!button_0065!#" : "#!string!button_0066!#";
		my $say_title   = $an->String->get({key => "title_0153", variables => { subtask => $say_subtask }});
		print $an->Web->template({file => "server.html", template => "cold-stop-header", replace => { title => $say_title }});
	}
	else
	{
		# Already down, abort.
		my $say_title   = $an->String->get({key => "title_0180", variables => { anvil => $anvil }});
		my $say_message = $an->String->get({key => "message_0419", variables => { anvil => $anvil }});
		print $an->Web->template({file => "server.html", template => "cold-stop-aborted", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});
	}
	
	# If I have a sub-task, perform it now.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::subtask", value1 => $an->data->{cgi}{subtask},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{cgi}{subtask} eq "power_cycle")
	{
		# Tell the user
		print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
			row_class	=>	"highlight_warning_bold",
			row		=>	"#!string!row_0044!#",
			message_class	=>	"td_hidden_white",
			message		=>	"#!string!explain_0154!#",
		}});
		
		# Nighty night, see you in the morning!
		my $shell_call = $an->data->{path}{'call_anvil-kick-apc-ups'}." --reboot --force";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
		}
		close $file_handle;
	}
	elsif($an->data->{cgi}{subtask} eq "power_off")
	{
		# Tell the user
		print $an->Web->template({file => "server.html", template => "cold-stop-entry", replace => { 
			row_class	=>	"highlight_warning_bold",
			row		=>	"#!string!row_0044!#",
			message_class	=>	"td_hidden_white",
			message		=>	"#!string!explain_0155!#",
		}});
		
		# Do eet!
		my $shell_call = $an->data->{path}{'call_anvil-kick-apc-ups'}." --shutdown --force";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
		}
		close $file_handle;
	}
	
	# All done.
	print $an->Web->template({file => "server.html", template => "cold-stop-footer"});
	
	AN::Cluster::footer($an);
	return(0);
}

# This uses the local machine to call "power on" against both nodes in the cluster.
sub dual_boot
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "dual_boot" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $proceed      = 1;
	my $cluster      = $an->data->{cgi}{cluster};
	my $shell_call   = "";
	my $booted_nodes = [];
	# TODO: Provide an option to boot just one node if one node fails for
	# some reason but the other node is fine.
	AN::Cluster::scan_cluster($an);
	my @abort_reasons;
	foreach my $node (sort {$a cmp $b} @{$an->data->{clusters}{$cluster}{nodes}})
	{
		# Read the cache files.
		AN::Cluster::read_node_cache($an, $node);
		if (not $an->data->{node}{$node}{info}{power_check_command})
		{
			# No cache
			my $reason = $an->String->get({key => "message_0215", variables => { node => $node }});
			push @abort_reasons, "$reason\n";
			$proceed = 0;
		}
		
		# Confirm the node is off still.
		AN::Cluster::check_if_on($an, $node);
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node}::is_on", value1 => $an->data->{node}{$node}{is_on},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{node}{$node}{is_on} == 1)
		{
			# Already on.
			my $reason = $an->String->get({key => "message_0216", variables => { node => $node }});
			push @abort_reasons, "$reason\n";
			$proceed = 0;
		}
		elsif ($an->data->{node}{$node}{is_on} == 2)
		{
			# Can't reach IPMI interface
			my ($target_host) = ($an->data->{node}{$node}{info}{power_check_command} =~ /-a\s(.*?)\s/)[0];
			my $reason        = $an->String->get({key => "message_0217", variables => { 
					node		=>	$node,
					target_host	=>	$target_host,
				}});
			push @abort_reasons, "$reason\n";
			$proceed = 0;
		}
		elsif ($an->data->{node}{$node}{is_on} == 3)
		{
			# Not on the IPMI interface's subnet
			my ($target_host) = ($an->data->{node}{$node}{info}{power_check_command} =~ /-a\s(.*?)\s/)[0];
			my $reason        = $an->String->get({key => "message_0218", variables => { 
					node		=>	$node,
					target_host	=>	$target_host,
				}});
			push @abort_reasons, "$reason\n";
			$proceed = 0;
		}
		elsif ($an->data->{node}{$node}{is_on} == 4)
		{
			# Cache found, but no power command recorded
			my ($target_host) = ($an->data->{node}{$node}{info}{power_check_command} =~ /-a\s(.*?)\s/)[0];
			my $reason        = $an->String->get({key => "message_0219", variables => { 
					node		=>	$node,
					target_host	=>	$target_host,
				}});
			push @abort_reasons, "$reason\n";
			$proceed = 0;
		}
		
		# Still alive?
		$shell_call .= $an->data->{node}{$node}{info}{power_check_command}." -o on; ";
		push @{$booted_nodes}, $node;
	}
	
	# Let's go
	if ($proceed)
	{
		my $say_message = $an->String->get({key => "message_0220", variables => { anvil => $an->data->{cgi}{cluster} }});
		print $an->Web->template({file => "server.html", template => "dual-boot-header", replace => { message => $say_message }});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			
			# If I can't contact the peer's database, I will get an error message. 
			
			$line = parse_text_line($an, $line);
			my $message = ($line =~ /^(.*)\[/)[0];
			my $status  = ($line =~ /(\[.*)$/)[0];
			if (not $message)
			{
				$message = $line;
				$status  = "";
			}
			print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
				status	=>	$status,
				message	=>	$message,
			}});
		}
		close $file_handle;
		
		# Update ScanCore to tell it that the nodes should now be booted if they're found to be off.
		foreach my $node (sort {$a cmp $b} @{$booted_nodes})
		{
			$an->Striker->mark_node_as_clean_on({node_uuid => $an->data->{sys}{name_to_uuid}{$node}});
		}
		
		print $an->Web->template({file => "server.html", template => "dual-boot-footer"});
	}
	else
	{
		# Abort, abort!
		my $say_title= $an->String->get({key => "title_0064", variables => { anvil => $an->data->{cgi}{cluster} }});
		print $an->Web->template({file => "server.html", template => "dual-boot-aborted-header", replace => { title => $say_title }});
		foreach my $reason (@abort_reasons)
		{
			print $an->Web->template({file => "server.html", template => "dual-boot-abort-reason", replace => { reason => $reason }});
		}
		print $an->Web->template({file => "server.html", template => "dual-boot-aborted-footer"});
	}
	
	return(0);
}

# This uses the IPMI (or similar) to try and power on the node.
sub poweron_node
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "poweron_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make sure no VMs are running.
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node",              value1 => $node,
		name2 => "node_cluster_name", value2 => $node_cluster_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Scan the cluster, then confirm that withdrawl is still enabled.
	AN::Cluster::scan_cluster($an);
	AN::Cluster::check_if_on($an, $node);
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node::${node}::is_on",  value1 => $an->data->{node}{$node}{is_on},
	}, file => $THIS_FILE, line => __LINE__});
	
	my $proceed = 0;
	# Unknown error is the default.
	my $abort_reason = $an->String->get({key => "message_0224", variables => { node => $node }});
	if ($an->data->{node}{$node}{is_on} == 0)
	{
		$proceed = 1;
	}
	elsif ($an->data->{node}{$node}{is_on} == 1)
	{
		# Already on
		$abort_reason = $an->String->get({key => "message_0225", variables => { node_anvil_name => $node_cluster_name }});
	}
	elsif ($an->data->{node}{$node}{is_on} == 2)
	{
		# Unable to contact the IPMI BMC
		$abort_reason = $an->String->get({key => "message_0226", variables => { node_anvil_name => $node_cluster_name }});
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node",    value1 => $node,
		name2 => "proceed", value2 => $proceed,
	}, file => $THIS_FILE, line => __LINE__});
	if ($proceed)
	{
		# It is still off.
		my $say_title   = $an->String->get({key => "title_0065", variables => { node_anvil_name => $node_cluster_name }});
		my $say_message = $an->String->get({key => "message_0222", variables => { node_anvil_name => $node_cluster_name }});
		print $an->Web->template({file => "server.html", template => "poweron-node-header", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});

		# The node is still off. Now can I call it from it's peer?
		my $peer  = "";
		my $is_on = 2;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::up_nodes", value1 => $an->data->{sys}{up_nodes},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{sys}{up_nodes} == 1)
		{
			# It has to be the peer of this node.
			$peer = @{$an->data->{up_nodes}}[0];
		}
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node", value1 => $node,
			name2 => "peer", value2 => $peer,
		}, file => $THIS_FILE, line => __LINE__});
		if ($peer)
		{
			# It's peer is up, use it.
			if (not $an->data->{node}{$node}{info}{power_check_command})
			{
				# Can't find the power command on the peer
				my $error = $an->String->get({key => "message_0227", variables => { 
						node	=>	$node,
						peer	=>	$peer,
					}});
				AN::Cluster::error($an, "$error\n");
			}
			my $shell_call = $an->data->{node}{$node}{info}{power_check_command}." -o on";
			my $password   = $an->data->{sys}{root_password};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "peer",       value2 => $peer,
			}, file => $THIS_FILE, line => __LINE__});
			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$peer,
				port		=>	$an->data->{node}{$peer}{port}, 
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
				
				print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
			}
			
			# Update ScanCore to tell it that the nodes should now be booted.
			$an->Striker->mark_node_as_clean_on({node_uuid => $an->data->{sys}{name_to_uuid}{$node}});
			print $an->Web->template({file => "server.html", template => "poweron-node-close-tr"});
		}
		else
		{
			# Try to boot the node locally.
			if ($an->data->{node}{$node}{info}{power_check_command})
			{
				my ($target_host) = ($an->data->{node}{$node}{info}{power_check_command} =~ /-a\s(.*?)\s/)[0];
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "node",                value1 => $node,
					name2 => "target host",         value2 => $target_host,
					name3 => "power check command", value3 => $an->data->{node}{$node}{info}{power_check_command},
				}, file => $THIS_FILE, line => __LINE__});
				my ($local_access, $target_ip) = AN::Cluster::on_same_network($an, $target_host, $node);
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node",         value1 => $node,
					name2 => "local access", value2 => $local_access,
				}, file => $THIS_FILE, line => __LINE__});
				if ($local_access)
				{
					# I can reach it directly
					my $shell_call = $an->data->{node}{$node}{info}{power_check_command}." -o on";
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "shell_call", value1 => $shell_call,
					}, file => $THIS_FILE, line => __LINE__});
					open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
					while(<$file_handle>)
					{
						chomp;
						my $line = $_;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
							name1 => "node", value1 => $node,
							name2 => "line", value2 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
					}
					close $file_handle;
					print $an->Web->template({file => "server.html", template => "poweron-node-close-tr"});
				}
				else
				{
					# I can't reach it from here.
					$an->Log->entry({log_level => 2, message_key => "log_0252", message_variables => {
						node        => $node, 
						target_host => $target_host, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			else
			{
				# Can't check the power.
				my $say_title   = $an->String->get({key => "title_0066", variables => { node_anvil_name => $node_cluster_name }});
				my $say_message = $an->String->get({key => "message_0228", variables => { node_anvil_name => $node_cluster_name }});
				print $an->Web->template({file => "server.html", template => "poweron-node-failed", replace => { 
					title	=>	$say_title,
					message	=>	$say_message,
				}});
			}
		}
	}
	else
	{
		# Poweron aborted
		my $say_title = $an->String->get({key => "title_0067", variables => { node_anvil_name => $node_cluster_name }});
		print $an->Web->template({file => "server.html", template => "poweron-node-aborted", replace => { 
			title	=>	$say_title,
			message	=>	$abort_reason,
		}});
	}
	print $an->Web->template({file => "server.html", template => "poweron-node-footer"});
	AN::Cluster::footer($an);
	
	return(0);
}

# This uses the fence methods, as defined in cluster.conf and in the proper order, to fence the target node.
sub fence_node
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "fence_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make sure no VMs are running.
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	my $peer              = $an->Cman->peer_hostname({node => $node});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "in poweron_node(), node", value1 => $node,
		name2 => "peer",                    value2 => $peer,
		name3 => "cluster name",            value3 => $node_cluster_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Has the timer expired?
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "current time", value1 => time,
		name2 => "cgi::expire",  value2 => $an->data->{cgi}{expire},
	}, file => $THIS_FILE, line => __LINE__});
	if (time > $an->data->{cgi}{expire})
	{
		# Abort!
		my $say_title   = $an->String->get({key => "title_0188"});
		my $say_message = $an->String->get({key => "message_0447", variables => { node => $an->data->{cgi}{node_cluster_name} }});
		print $an->Web->template({file => "server.html", template => "request-expired", replace => { 
			title		=>	$say_title,
			message		=>	$say_message,
		}});
		return(1);
	}
	
	# Scan the cluster, then confirm that withdrawl is still enabled.
	AN::Cluster::scan_cluster($an);
	my $proceed      = 1;
	my @abort_reason = "";
	
	my $fence_string = "";
	# See if I already have the fence string. If not, load it from cache.
	if ($an->data->{node}{$node}{info}{fence_methods})
	{
		$fence_string = $an->data->{node}{$node}{info}{fence_methods};
	}
	else
	{
		AN::Cluster::read_node_cache($an, $node);
		if ($an->data->{node}{$node}{info}{fence_methods})
		{
			$fence_string = $an->data->{node}{$node}{info}{fence_methods};
		}
		else
		{
			   $proceed = 0;
			my $reason  = $an->String->get({key => "message_0231", variables => { node => $node }});
			push @abort_reason, "$reason\n";
		}
	}
	
	# If the peer node is up, use the fence command as compiled by it. 
	# Otherwise, read the cache. If the fence command(s) are still not
	# available, abort.
	if ($proceed)
	{
		if (not $an->data->{node}{$peer}{up})
		{
			# See if this machine can reach each '-a ...' fence device
			# address.
			foreach my $address ($fence_string =~ /-a\s(.*?)\s/g)
			{
				my ($local_access, $target_ip) = AN::Cluster::on_same_network($an, $address, $node);
				if (not $local_access)
				{
					   $proceed = 0;
					my $reason  = $an->String->get({key => "message_0232", variables => { 
							node	=>	$node,
							peer	=>	$peer,
							address	=>	$address,
						}});
					push @abort_reason, "$reason\n";
				}
			}
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node",    value1 => $node,
		name2 => "proceed", value2 => $proceed,
	}, file => $THIS_FILE, line => __LINE__});
	if ($proceed)
	{
		my $say_title   = $an->String->get({key => "title_0068", variables => { node_anvil_name => $node_cluster_name }});
		my $say_message = $an->String->get({key => "message_0233", variables => { node_anvil_name => $node_cluster_name }});
		print $an->Web->template({file => "server.html", template => "fence-node-header", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});

		# This loops for each method, which may have multiple device calls. I parse each call into an
		# 'off' and 'on' call. If the 'off' call fails, I go to the next method until there are no
		# methods left. If the 'off' works, I call the 'on' call from the same method to (try to) 
		# boot the node back up (or simply unfence it in the case of PDUs and the like).
		my $fence_success   = 0;
		my $unfence_success = 0;
		foreach my $line ($fence_string =~ /\d+:.*?;\./g)
		{
			print $an->Web->template({file => "server.html", template => "fence-node-output-header"});
			my ($method_num, $method_name, $command) = ($line =~ /(\d+):(.*?): (.*?;)\./);
			my $off_command = $command;
			my $on_command  = $command;
			my $off_success = 1;
			my $on_success  = 1;
			
			# If the peer is up, set the command to run through it.
			if ($an->data->{node}{$peer}{up})
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
				my $node       = $1;
				my $shell_call = $2;
				my $password   = $an->data->{sys}{root_password};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
					name2 => "node",       value2 => $node,
				}, file => $THIS_FILE, line => __LINE__});
				my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$node,
					port		=>	$an->data->{node}{$node}{port}, 
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
				}
			}
			else
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
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
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node", value1 => $node,
					name2 => "line", value2 => $line,
				}, file => $THIS_FILE, line => __LINE__});
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
					print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
				}
			}
			print $an->Web->template({file => "server.html", template => "fence-node-output-footer"});
			if ($off_success)
			{
				# Fence succeeded!
				$an->Log->entry({log_level => 2, message_key => "log_0253", message_variables => {
					method_name => $method_name, 
				}, file => $THIS_FILE, line => __LINE__});
				my $say_message = $an->String->get({key => "message_0234", variables => { method_name => $method_name }});
				print $an->Web->template({file => "server.html", template => "fence-node-message", replace => { message => $say_message }});
				$fence_success = 1;
			}
			else
			{
				# Fence failed!
				$an->Log->entry({log_level => 2, message_key => "log_0254", message_variables => {
					method_name => $method_name, 
				}, file => $THIS_FILE, line => __LINE__});
				my $say_message = $an->String->get({key => "message_0235", variables => { method_name => $method_name }});
				print $an->Web->template({file => "server.html", template => "fence-node-message", replace => { message => $say_message }});
				next;
			}
			
			# If I'm here, I can try the unfence command.
			print $an->Web->template({file => "server.html", template => "fence-node-unfence-header"});
			$shell_call = "$on_command";
			if ($shell_call =~ /ssh:(.*?),(.*)$/)
			{
				my $node       = $1;
				my $shell_call = $2;
				my $password   = $an->data->{sys}{root_password};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
					name2 => "node",       value2 => $node,
				}, file => $THIS_FILE, line => __LINE__});
				my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$node,
					port		=>	$an->data->{node}{$node}{port}, 
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
				}
			}
			else
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
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
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node", value1 => $node,
					name2 => "line", value2 => $line,
				}, file => $THIS_FILE, line => __LINE__});
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
					print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
				}
			}
			print $an->Web->template({file => "server.html", template => "fence-node-unfence-footer"});
			if ($on_success)
			{
				# Unfence succeeded!
				$an->Log->entry({log_level => 2, message_key => "log_0254", message_variables => {
					method_name => $method_name, 
				}, file => $THIS_FILE, line => __LINE__});
				my $say_message = $an->String->get({key => "message_0236", variables => { method_name => $method_name }});
				print $an->Web->template({file => "server.html", template => "fence-node-message", replace => { message => $say_message }});
				$unfence_success = 1;
				last;
			}
			else
			{
				# Unfence failed!
				# This is allowed to go to the next fence method because some servers may 
				# hang their IPMI interface after a fence call, requiring power to be cut in
				# order to reset the BMC. HP, I'm looking at you and your DL1** G7 line...
				my $say_message = $an->String->get({key => "message_0237", variables => { method_name => $method_name }});
				print $an->Web->template({file => "server.html", template => "fence-node-message", replace => { message => $say_message }});
			}
		}
	}
	else
	{
		my $say_title = $an->String->get({key => "title_0069", variables => { node_anvil_name => $node_cluster_name }});
		print $an->Web->template({file => "server.html", template => "fence-node-aborted-header", replace => { title => $say_title }});
		foreach my $reason (@abort_reason)
		{
			print $an->Web->template({file => "server.html", template => "fence-node-abort-reason", replace => { reason => $reason }});
		}
	}
	print $an->Web->template({file => "server.html", template => "fence-node-footer"});
	AN::Cluster::footer($an);
	
	return(0);
}

### TODO: Switch this to '$an->Cman->withdraw_node()' and process the returned output in one go.
# This does a final check of the target node then withdraws it from the cluster.
sub withdraw_node
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "withdraw_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make sure no VMs are running.
	my $node              = $an->data->{cgi}{node};
	my $node_cluster_name = $an->data->{cgi}{node_cluster_name};
	
	# Scan the cluster, then confirm that withdrawl is still enabled.
	AN::Cluster::scan_cluster($an);
	my $proceed = $an->data->{node}{$node}{enable_withdraw};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node",    value1 => $node,
		name2 => "proceed", value2 => $proceed,
	}, file => $THIS_FILE, line => __LINE__});
	if ($proceed)
	{
		# Stop rgmanager and then check it's status.
		my $say_title = $an->String->get({key => "title_0070", variables => { node_anvil_name => $node_cluster_name }});
		print $an->Web->template({file => "server.html", template => "withdraw-node-header", replace => { title => $say_title }});
		
		# Sometimes rgmanager gets stuck waiting for gfs2 and/or clvmd2 to stop. So to help with 
		# these cases, we'll call '$an->Remote->delayed_run()' for at least 60 seconds in the future.
		# This usually gives rgmanager the kick it needs to actually stop.
		my $password = $an->data->{sys}{root_password};
		my ($token, $output, $problem) = $an->Remote->delayed_run({
			command  => "/etc/init.d/gfs2 stop && /etc/init.d/clvmd stop",
			delay    => 60,
			target   => $node,
			password => $password,
			port     => $an->data->{node}{$node}{port},
		});
		
		my $rgmanager_stop = 1;
		my $shell_call     = "/etc/init.d/rgmanager stop";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /failed/i)
			{
				$rgmanager_stop = 0;
			}
			$line = parse_text_line($an, $line);
			my $message = ($line =~ /^(.*)\[/)[0];
			my $status  = ($line =~ /(\[.*)$/)[0];
			if (not $message)
			{
				$message = $line;
				$status  = "";
			}
			print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
				status	=>	$status,
				message	=>	$message,
			}});
		}
		print $an->Web->template({file => "server.html", template => "withdraw-node-close-output"});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "rgmanager_stop", value1 => $rgmanager_stop, 
			name2 => "token",          value2 => $token, 
		}, file => $THIS_FILE, line => __LINE__});
		if (($rgmanager_stop) && ($token))
		{
			# Stop the gfs2/clvmd stop call
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "token", value1 => $token,
			}, file => $THIS_FILE, line => __LINE__});
			if ($token)
			{
				my $shell_call = $an->data->{path}{'anvil-run-jobs'}." --abort $token";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
					name2 => "node",       value2 => $node,
				}, file => $THIS_FILE, line => __LINE__});
				my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$node,
					port		=>	$an->data->{node}{$node}{port}, 
					password	=>	$password,
					ssh_fh		=>	"",
					'close'		=>	0,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			
			print $an->Web->template({file => "server.html", template => "withdraw-node-resource-manager-stopped"});
			my $cman_stop  = 1;
			my $shell_call = "/etc/init.d/cman stop";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "node",       value2 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$node,
				port		=>	$an->data->{node}{$node}{port}, 
				password	=>	$password,
				ssh_fh		=>	"",
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				$line =~ s/\s+/ /g;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /failed/i)
				{
					$cman_stop = 0;
				}
				$line = parse_text_line($an, $line);
				my $message = ($line =~ /^(.*)\[/)[0];
				my $status  = ($line =~ /(\[.*)$/)[0];
				if (not $message)
				{
					$message = $line;
					$status  = "";
				}
				print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
					status	=>	$status,
					message	=>	$message,
				}});
			}
			print $an->Web->template({file => "server.html", template => "withdraw-node-close-output"});

			if (not $cman_stop)
			{
				# Crap...
				print $an->Web->template({file => "server.html", template => "withdraw-node-membership-withdrawl-failed"});
				my $cman_start = 1;
				my $shell_call = "/etc/init.d/cman start";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
					name2 => "node",       value2 => $node,
				}, file => $THIS_FILE, line => __LINE__});
				my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$node,
					port		=>	$an->data->{node}{$node}{port}, 
					password	=>	$password,
					ssh_fh		=>	"",
					'close'		=>	0,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
					
					if ($line =~ /failed/i)
					{
						$cman_start = 0;
					}
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
					$line = parse_text_line($an, $line);
					my $message = ($line =~ /^(.*)\[/)[0];
					my $status  = ($line =~ /(\[.*)$/)[0];
					if (not $message)
					{
						$message = $line;
						$status  = "";
					}
					print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
						status	=>	$status,
						message	=>	$message,
					}});
				}
				print $an->Web->template({file => "server.html", template => "withdraw-node-close-output"});
				if ($cman_start)
				{
					# and we're back
					print $an->Web->template({file => "server.html", template => "withdraw-node-membership-restarted-successfully"});
					recover_rgmanager($an, $node);
					
				}
				else
				{
					# Failed, call support.
					print $an->Web->template({file => "server.html", template => "withdraw-node-membership-restarted-failed"});
				}
			}
		}
		else
		{
			# Recover rgmanager
			print $an->Web->template({file => "server.html", template => "withdraw-node-resource-manager-failed-to-stop"});
			recover_rgmanager($an, $node);
		}
		print $an->Web->template({file => "server.html", template => "withdraw-node-footer"});
	}
	else
	{
		my $say_title   = $an->String->get({key => "title_0071", variables => { node_anvil_name => $node_cluster_name }});
		my $say_message = $an->String->get({key => "message_0249", variables => { node_anvil_name => $node_cluster_name }});
		print $an->Web->template({file => "server.html", template => "withdraw-node-aborted", replace => { 
			title	=>	$say_title,
			message	=>	$say_message,
		}});
	}
	
	AN::Cluster::footer($an);
	
	return(0);
}

# This restarts rgmanager and, if necessary, disables and re-enables the storage service.
sub recover_rgmanager
{
	my ($an, $node) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "recover_rgmanager" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Tell the user we're recovering rgmanager
	print $an->Web->template({file => "server.html", template => "recover-resource-manager-header"});
	my $rgmanager_start = 1;
	my $shell_call      = "/etc/init.d/rgmanager start";
	my $password        = $an->data->{sys}{root_password};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$an->data->{node}{$node}{port}, 
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /failed/i)
		{
			$rgmanager_start = 0;
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		print $an->Web->template({file => "server.html", template => "one-line-message", replace => { message => $line }});
	}
	print $an->Web->template({file => "server.html", template => "recover-resource-manager-output-footer"});

	if ($rgmanager_start)
	{
		my $storage_service = $an->data->{node}{$node}{info}{storage_name};
		print $an->Web->template({file => "server.html", template => "recover-resource-manager-successful"});
		if ($storage_service)
		{
			# Need to rescan the Anvil!...
			my $message = $an->String->get({key => "message_0251", variables => { storage_service => $storage_service }});
			print $an->Web->template({file => "server.html", template => "recover-resource-manager-check-storage", replace => { message => $message }});
			
			# I need to sleep for ~ten seconds to give time for 'clustat' to start showing the 
			# service section again.
			$an->Log->entry({log_level => 2, message_key => "log_0256", message_variables => {
				node => $node, 
			}, file => $THIS_FILE, line => __LINE__});
			sleep 10;
			AN::Cluster::check_node_status($an);
			my $storage_state = $an->data->{node}{$node}{info}{storage_state};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "node",            value1 => $node,
				name2 => "storage service", value2 => $storage_service,
				name3 => "storage state",   value3 => $storage_state,
			}, file => $THIS_FILE, line => __LINE__});
			if ($storage_state =~ /Failed/i) 
			{
				my $say_failed = $an->String->get({key => "message_0253", variables => { storage_service => $storage_service }});
				my $say_cycle  = $an->String->get({key => "message_0254", variables => { storage_service => $storage_service }});
				print $an->Web->template({file => "server.html", template => "recover-resource-manager-cycle-storage-service", replace => { 
					failed	=>	$say_failed,
					cycle	=>	$say_cycle,
				}});

				# NOTE: This will return 'Warning' because of whatever is holding open the 
				#       storage. This is fine, as the goal is to enable, not stop.
				my $storage_stop = 1;
				my $shell_call   = $an->data->{path}{clusvcadm}." -d $storage_service";
				my $password     = $an->data->{sys}{root_password};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
					name2 => "node",       value2 => $node,
				}, file => $THIS_FILE, line => __LINE__});
				my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$node,
					port		=>	$an->data->{node}{$node}{port}, 
					password	=>	$password,
					ssh_fh		=>	"",
					'close'		=>	0,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					$line =~ s/^\s+//;
					$line =~ s/\s+$//;
					$line =~ s/\s+/ /g;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
					
					if ($line =~ /failed/i)
					{
						$storage_stop = 0;
					}
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line,
					}, file => $THIS_FILE, line => __LINE__});
					$line = parse_text_line($an, $line);
					my $message = ($line =~ /^(.*)\[/)[0];
					my $status  = ($line =~ /(\[.*)$/)[0];
					if (not $message)
					{
						$message = $line;
						$status  = "";
					}
					print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
						status	=>	$status,
						message	=>	$message,
					}});
				}
				print $an->Web->template({file => "server.html", template => "recover-resource-manager-close-output"});

				if ($storage_stop)
				{
					my $say_stopped = $an->String->get({key => "message_0255", variables => { storage_service => $storage_service }});
					print $an->Web->template({file => "server.html", template => "recover-resource-manager-storage-service-stopped", replace => { stopped => $say_stopped }});
					
					my $storage_start = 1;
					my $shell_call    = $an->data->{path}{clusvcadm}." -e $storage_service";
					my $password      = $an->data->{sys}{root_password};
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "shell_call", value1 => $shell_call,
						name2 => "node",       value2 => $node,
					}, file => $THIS_FILE, line => __LINE__});
					my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
						target		=>	$node,
						port		=>	$an->data->{node}{$node}{port}, 
						password	=>	$password,
						ssh_fh		=>	"",
						'close'		=>	0,
						shell_call	=>	$shell_call,
					});
					foreach my $line (@{$return})
					{
						$line =~ s/^\s+//;
						$line =~ s/\s+$//;
						$line =~ s/\s+/ /g;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line, 
						}, file => $THIS_FILE, line => __LINE__});
						
						if ($line =~ /failed/i)
						{
							$storage_start = 0;
						}
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						$line = parse_text_line($an, $line);
						my $message = ($line =~ /^(.*)\[/)[0];
						my $status  = ($line =~ /(\[.*)$/)[0];
						if (not $message)
						{
							$message = $line;
							$status  = "";
						}
						print $an->Web->template({file => "server.html", template => "start-server-shell-output", replace => { 
							status	=>	$status,
							message	=>	$message,
						}});
					}
					print $an->Web->template({file => "server.html", template => "recover-resource-manager-close-output"});
					
					if ($storage_start)
					{
						# Hoozah!
						my $say_restarted = $an->String->get({key => "message_0257", variables => { storage_service => $storage_service }});
						my $say_advice    = $an->String->get({key => "message_0259", variables => { node => $node }});
						print $an->Web->template({file => "server.html", template => "recover-resource-manager-storage-service-recovered", replace => { 
							restarted	=>	$say_restarted,
							advice		=>	$say_advice,
						}});
					}
					else
					{
						# We're boned.
						my $say_failed = $an->String->get({key => "message_0262", variables => { storage_service => $storage_service }});
						print $an->Web->template({file => "server.html", template => "recover-resource-manager-storage-service-unrecovered", replace => { failed => $say_failed }});
					}
				}
				else
				{
					# Failed to disable.
					my $say_failed = $an->String->get({key => "message_0263", variables => { storage_service => $storage_service }});
					print $an->Web->template({file => "server.html", template => "recover-resource-manager-failed-to-disable", replace => { failed => $say_failed }});
				}
			}
			else
			{
				# Storage service is running, recovery unneeded.
				# TODO: Check each individual storage service and restart each if needed.
				my $say_abort = $an->String->get({key => "message_0264", variables => { storage_service => $storage_service }});
				print $an->Web->template({file => "server.html", template => "recover-resource-manager-abort-storage-recovery", replace => { abort => $say_abort }});
			}
		}
		else
		{
			# Unable to identify the storage service
			print $an->Web->template({file => "server.html", template => "recover-resource-manager-cant-find-storage"});
		}
	}
	else
	{
		# Failed. :(
		print $an->Web->template({file => "server.html", template => "recover-resource-manager-failed"});
	}
	
	return(0);
}

# This creates the summary page after a cluster has been selected.
sub display_details
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "display_details" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	#print $an->Web->template({file => "server.html", template => "display-details-header"});
	# Display the status of each node's daemons
	my $up_nodes = @{$an->data->{up_nodes}};
	
	# TODO: Rework this, I always show nodes now so that the 'fence_...' calls are available. IE: enable 
	#       this when the cache exists and the fence command addresses are reachable.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "sys::show_nodes", value1 => $an->data->{sys}{show_nodes},
		name2 => "sys::up_nodes",   value2 => $an->data->{sys}{up_nodes},
		name3 => "up_nodes",        value3 => $up_nodes,
	}, file => $THIS_FILE, line => __LINE__});
#	if ($an->data->{sys}{show_nodes})
	if (1)
	{
		my $node_control_panel = display_node_controls($an);
		#print $node_control_panel;
		
		my $anvil_safe_start_notice    = "";
		my $vm_state_and_control_panel = "";
		my $node_details_panel         = "";
		my $server_details_panel       = "";
		my $gfs2_details_panel         = "";
		my $drbd_details_panel         = "";
		my $free_resources_panel       = "";
		my $no_access_panel            = "";
		my $watchdog_panel             = "";

		# I don't show below here unless at least one node is up.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "sys::up_nodes", value1 => $an->data->{sys}{up_nodes},
			name2 => "up_nodes",      value2 => $up_nodes,
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{sys}{up_nodes} > 0)
		{
			# Displays a notice if anvil-safe-start is running on either node.
			$anvil_safe_start_notice = display_anvil_safe_start_notice($an);
			
			# Show the user the current VM states and the control buttons.
			$vm_state_and_control_panel = display_vm_state_and_controls($an);
			
			# Show the state of the daemons.
			$node_details_panel = display_node_details($an);
			
			# Show the details about each VM.
			$server_details_panel = display_vm_details($an);
			
			# Show the status of each node's GFS2 share(s)
			$gfs2_details_panel = display_gfs2_details($an);
			
			# This shows the status of each DRBD resource in the cluster.
			$drbd_details_panel = display_drbd_details($an);
			
			# Show the free resources available for new VMs.
			$free_resources_panel = display_free_resources($an);
			
			# This generates a panel below 'Available Resources' 
			# *if* the user has enabled 'tools::anvil-kick-apc-ups::enabled'
			$watchdog_panel = display_watchdog_panel($an, "");
		}
		else
		{
			# Was able to confirm the nodes are off.
			$no_access_panel = $an->Web->template({file => "server.html", template => "display-details-nodes-unreachable", replace => { message => "#!string!message_0268!#" }});
			
			# This generates a panel below 'Available Resources' *if* the user has enabled 
			# 'tools::anvil-kick-apc-ups::enabled'
			$watchdog_panel = display_watchdog_panel($an, "no_abort");
		}
		
		print $an->Web->template({file => "server.html", template => "main-page", replace => { 
			anvil_safe_start_notice		=>	$anvil_safe_start_notice, 
			node_control_panel		=>	$node_control_panel,
			vm_state_and_control_panel	=>	$vm_state_and_control_panel,
			node_details_panel		=>	$node_details_panel,
			server_details_panel		=>	$server_details_panel,
			gfs2_details_panel		=>	$gfs2_details_panel,
			drbd_details_panel		=>	$drbd_details_panel,
			free_resources_panel		=>	$free_resources_panel,
			no_access_panel			=>	$no_access_panel,
			watchdog_panel			=>	$watchdog_panel,
		}});
	}
	
	return (0);
}

# This returns a panel for controlling hard-resets via the 'APC UPS Watchdog' tools
sub display_watchdog_panel
{
	my ($an, $note) = @_;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "display_watchdog_panel" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "note", value1 => $note, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $expire_time      =  time + $an->data->{sys}{actime_timeout};
	my $power_cycle_link = "?cluster=".$an->data->{cgi}{cluster}."&expire=$expire_time&task=cold_stop&subtask=power_cycle";
	my $power_off_link   = "?cluster=".$an->data->{cgi}{cluster}."&expire=$expire_time&task=cold_stop&subtask=power_off";
	my $watchdog_panel   = "";
	my $use_node         = "";
	my $this_cluster     = $an->data->{cgi}{cluster};
	my $enable           = 0;
	foreach my $node (sort {$a cmp $b} @{$an->data->{clusters}{$this_cluster}{nodes}})
	{
		if ($an->data->{node}{$node}{up})
		{
			$use_node = $node;
			last;
		}
	}
	
	### TODO: If not 'use_node', use our local copy of the watchdog script if we can reach the UPSes.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "tools::anvil-kick-apc-ups::enabled", value1 => $an->data->{tools}{'anvil-kick-apc-ups'}{enabled},
		name2 => "use_node",                           value2 => $use_node,
	}, file => $THIS_FILE, line => __LINE__});
	if ($use_node)
	{
		# Check that 'anvil-kick-apc-ups' exists.
		my $node       = $use_node;
		my $shell_call = "
if \$($an->data->{path}{nodes}{'grep'} -q '^tools::anvil-kick-apc-ups::enabled\\s*=\\s*1' $an->data->{path}{nodes}{striker_config});
then 
    echo enabled; 
else 
    echo disabled;
fi";
		my $password = $an->data->{sys}{root_password};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line eq "enabled")
			{
				$enable = 1;
			}
		}
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "enable", value1 => $enable,
		}, file => $THIS_FILE, line => __LINE__});
		if ($enable)
		{
			# It exists, load the template
			$watchdog_panel = $an->Web->template({file => "server.html", template => "watchdog_panel", replace => { 
					power_cycle	=>	$power_cycle_link,
					power_off	=>	$power_off_link,
				}});
			$watchdog_panel =~ s/\n$//;
		}
	}
	else
	{
		# Anvil! is down, try to use our own copy.
		my $shell_call = "
if \$(".$an->data->{path}{'grep'}." -q '^tools::anvil-kick-apc-ups::enabled\\s*=\\s*1' ".$an->data->{path}{striker_config}.");
then 
    echo enabled; 
else 
    echo disabled;
fi
";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
		while(<$file_handle>)
		{
			chomp;
			my $line = $_;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line eq "enabled")
			{
				$enable = 1;
			}
		}
		close $file_handle;
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "enable", value1 => $enable,
		}, file => $THIS_FILE, line => __LINE__});
		if ($enable)
		{
			# It exists, load the template
			$power_cycle_link .= "&note=$note";
			$power_off_link   .= "&note=$note";
			$watchdog_panel   =  $an->Web->template({file => "server.html", template => "watchdog_panel", replace => { 
					power_cycle	=>	$power_cycle_link,
					power_off	=>	$power_off_link,
				}});
			$watchdog_panel =~ s/\n$//;
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "watchdog_panel", value1 => $watchdog_panel,
	}, file => $THIS_FILE, line => __LINE__});
	return($watchdog_panel);
}

# This shows the free resources available to be assigned to new VMs.
sub display_free_resources
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "display_free_resources" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $free_resources_panel .= $an->Web->template({file => "server.html", template => "display-details-free-resources-header"});
	
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
	foreach my $vg (sort {$a cmp $b} keys %{$an->data->{resources}{vg}})
	{
		# If it's not a clustered VG, I don't care about it.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "vg",        value1 => $vg,
			name2 => "clustered", value2 => $an->data->{resources}{vg}{$vg}{clustered},
		}, file => $THIS_FILE, line => __LINE__});
		next if not $an->data->{resources}{vg}{$vg}{clustered};
		push @vg,      $vg;
		push @vg_size, $an->data->{resources}{vg}{$vg}{size};
		push @vg_used, $an->data->{resources}{vg}{$vg}{used_space};
		push @vg_free, $an->data->{resources}{vg}{$vg}{free_space};
		push @pv_name, $an->data->{resources}{vg}{$vg}{pv_name};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
			name1 => "vg",         value1 => $vg,
			name2 => "size",       value2 => $an->data->{resources}{vg}{$vg}{size},
			name3 => "used space", value3 => $an->data->{resources}{vg}{$vg}{used_space},
			name4 => "free space", value4 => $an->data->{resources}{vg}{$vg}{free_space},
			name5 => "pv name",    value5 => $an->data->{resources}{vg}{$vg}{pv_name},
		}, file => $THIS_FILE, line => __LINE__});
		
		# If there is at least a GiB free, mark free storage as
		# sufficient.
		if (not $an->data->{sys}{clvmd_down})
		{
			$enough_storage =  1 if $an->data->{resources}{vg}{$vg}{free_space} > (2**30);
			$vg_link        .= "$vg:$an->data->{resources}{vg}{$vg}{free_space},";
		}
	}
	$vg_link =~ s/,$//;
	
	# Count how much RAM and CPU cores have been allocated.
	my $allocated_cores = 0;
	my $allocated_ram   = 0;
	foreach my $vm (sort {$a cmp $b} keys %{$an->data->{vm}})
	{
		next if $vm !~ /^vm/;
		# I check GFS2 because, without it, I can't read the VM's details.
		if ($an->data->{sys}{gfs2_down})
		{
			$allocated_ram   = "#!string!symbol_0011!#";
			$allocated_cores = "#!string!symbol_0011!#";
		}
		else
		{
			$allocated_ram   += $an->data->{vm}{$vm}{details}{ram};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "allocated_ram", value1 => $allocated_ram,
				name2 => "vm",            value2 => $vm,
				name3 => "ram",           value3 => $an->data->{vm}{$vm}{details}{ram},
			}, file => $THIS_FILE, line => __LINE__});
			$allocated_cores += $an->data->{vm}{$vm}{details}{cpu_count};
		}
	}
	
	# Always knock off some RAM for the host OS.
	my $real_total_ram            =  $an->Readable->bytes_to_hr({'bytes' => $an->data->{resources}{total_ram} });
	# Reserved RAM and BIOS memory holes rarely leave us with an even GiB of total RAM. So we modulous 
	# off the difference, then subtract that plus the reserved RAM to get an even left-over amount of 
	# memory for the user to allocate to their servers.
	my $diff                      = $an->data->{resources}{total_ram} % (1024 ** 3);
	$an->data->{resources}{total_ram} = $an->data->{resources}{total_ram} - $diff - $an->data->{sys}{unusable_ram};
	$an->data->{resources}{total_ram} =  0 if $an->data->{resources}{total_ram} < 0;
	my $free_ram                  =  $an->data->{sys}{gfs2_down}  ? 0    : $an->data->{resources}{total_ram} - $allocated_ram;
	my $say_free_ram              =  $an->data->{sys}{gfs2_down}  ? "--" : $an->Readable->bytes_to_hr({'bytes' => $free_ram });
	my $say_total_ram             =  $an->Readable->bytes_to_hr({'bytes' => $an->data->{resources}{total_ram} });
	my $say_allocated_ram         =  $an->data->{sys}{gfs2_down}  ? "--" : $an->Readable->bytes_to_hr({'bytes' => $allocated_ram });
	my $say_vg_size               =  $an->data->{sys}{clvmd_down} ? "--" : $an->Readable->bytes_to_hr({'bytes' => $vg_size[0] });
	my $say_vg_used               =  $an->data->{sys}{clvmd_down} ? "--" : $an->Readable->bytes_to_hr({'bytes' => $vg_used[0] });
	my $say_vg_free               =  $an->data->{sys}{clvmd_down} ? "--" : $an->Readable->bytes_to_hr({'bytes' => $vg_free[0] });
	my $say_vg                    =  $an->data->{sys}{clvmd_down} ? "--" : $vg[0];
	my $say_pv_name               =  $an->data->{sys}{clvmd_down} ? "--" : $pv_name[0];
	
	# Show the main info.
	$free_resources_panel .= $an->Web->template({file => "server.html", template => "display-details-free-resources-entry", replace => { 
		total_cores		=>	$an->data->{resources}{total_cores},
		total_threads		=>	$an->data->{resources}{total_threads},
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
	}});

	if (@vg > 0)
	{
		for (my $i=1; $i < @vg; $i++)
		{
			my $say_vg_size          =  $an->Readable->bytes_to_hr({'bytes' => $vg_size[$i] });
			my $say_vg_used          =  $an->Readable->bytes_to_hr({'bytes' => $vg_used[$i] });
			my $say_vg_free          =  $an->Readable->bytes_to_hr({'bytes' => $vg_free[$i] });
			my $say_pv_name          =  $pv_name[$i];
			   $free_resources_panel .= $an->Web->template({file => "server.html", template => "display-details-free-resources-entry-extra-storage", replace => { 
				vg		=>	$vg[$i],
				pv_name		=>	$pv_name[$i],
				say_vg_size	=>	$say_vg_size,
				say_vg_used	=>	$say_vg_used,
				say_vg_free	=>	$say_vg_free,
			}});
		}
	}
	
	### NOTE: Disabled in this release.
	# If I found enough free disk space, have at least 1 GiB of free RAM  and both nodes are up, enable 
	# the "provision new server" button.
	my $node1   = $an->data->{sys}{cluster}{node1_name};
	my $node2   = $an->data->{sys}{cluster}{node2_name};
	#my $say_bns = "<span class=\"disabled_button\">#!string!button_0022!#</span>";
	#my $say_mc  = "<span class=\"disabled_button\">#!string!button_0023!#</span>";
	my $say_bns = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0022!#" }});
	my $say_mc  = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0023!#" }});
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "enough_storage", value1 => $enough_storage,
		name2 => "free_ram",       value2 => $free_ram,
		name3 => "node1 cman",     value3 => $an->data->{node}{$node1}{daemon}{cman}{exit_code},
		name4 => "node2 cman",     value4 => $an->data->{node}{$node2}{daemon}{cman}{exit_code},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node1}{daemon}{cman}{exit_code} eq "0") && 
	    ($an->data->{node}{$node2}{daemon}{cman}{exit_code} eq "0"))
	{
		# The cluster is running, so enable the media library link.
		$say_mc = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	"/cgi-bin/mediaLibrary?cluster=".$an->data->{cgi}{cluster},
				button_text	=>	"#!string!button_0023!#",
				id		=>	"media_library_$an->data->{cgi}{cluster}",
			}});
		
		# Enable the "New Server" button if there is enough free memory and storage space.
		if (($enough_storage) && ($free_ram > $an->data->{sys}{server}{minimum_ram}))
		{
			$say_bns = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&task=provision&max_ram=$free_ram&max_cores=".$an->data->{resources}{total_cores}."&max_storage=$vg_link",
					button_text	=>	"#!string!button_0022!#",
					id		=>	"provision",
				}});
		}
	}
	$free_resources_panel .= $an->Web->template({file => "server.html", template => "display-details-bottom-button-bar", replace => { 
			say_bns	=>	$say_bns,
			say_mc	=>	$say_mc,
		}});
	$free_resources_panel .= $an->Web->template({file => "server.html", template => "display-details-footer"});

	return ($free_resources_panel);
}

# Simply converts a full domain name back to the node name used in the main hash.
sub long_host_name_to_node_name
{
	my ($an, $host) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "long_host_name_to_node_name" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "host", value1 => $host, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $cluster   = $an->data->{cgi}{cluster};
	my $node_name = "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cluster", value1 => $cluster,
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $node (sort {$a cmp $b} @{$an->data->{clusters}{$cluster}{nodes}})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node", value1 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my $short_host =  $host;
		   $short_host =~ s/\..*$//;
		my $short_node =  $node;
		   $short_node =~ s/\..*$//;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "short_host", value1 => $short_host,
			name2 => "short_node", value2 => $short_node,
		}, file => $THIS_FILE, line => __LINE__});
		if ($short_host eq $short_node)
		{
			$node_name = $node;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "node name", value1 => $node_name,
			}, file => $THIS_FILE, line => __LINE__});
			last;
		}
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "node name", value1 => $node_name,
	}, file => $THIS_FILE, line => __LINE__});
	return ($node_name);
}

# Simply converts a node name to the full domain name.
sub node_name_to_long_host_name
{
	my ($an, $host) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "node_name_to_long_host_name" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "host", value1 => $host, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $node_name = $an->data->{node}{$host}{me}{name};

	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "node name", value1 => $node_name,
	}, file => $THIS_FILE, line => __LINE__});
	return ($node_name);
}

# This just shows the details of the server (no controls)
sub display_vm_details
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "display_vm_details" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1 = $an->data->{sys}{cluster}{node1_name};
	my $node2 = $an->data->{sys}{cluster}{node2_name};
	my $server_details_panel = $an->Web->template({file => "server.html", template => "display-server-details-header"});
	
	# Pull up the server details.
	foreach my $vm (sort {$a cmp $b} keys %{$an->data->{vm}})
	{
		next if $vm !~ /^vm/;
		
		my $say_vm  = ($vm =~ /^vm:(.*)/)[0];
		my $say_ram = $an->data->{sys}{gfs2_down} ? "#!string!symbol_0011!#" : $an->Readable->bytes_to_hr({'bytes' => $an->data->{vm}{$vm}{details}{ram} });
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "vm",      value1 => $vm,
			name2 => "say_ram", value2 => $say_ram,
			name3 => "ram",     value3 => $an->data->{vm}{$vm}{details}{ram},
		}, file => $THIS_FILE, line => __LINE__});
		
		# Get the LV arrays populated.
		my @lv_path;
		my @lv_size;
		my $host = $an->data->{vm}{$vm}{host};
		
		# If the host is "none", read the details from one of the "up"
		# nodes.
		if ($host eq "none")
		{
			# If the first node is running, use it. Otherwise use
			# the second node.
			my $node1_daemons_running = check_node_daemons($an, $node1);
			my $node2_daemons_running = check_node_daemons($an, $node2);
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
			$node = long_host_name_to_node_name($an, $host);
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "vm",   value1 => $vm,
				name2 => "host", value2 => $host,
				name3 => "node", value3 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			
			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
				name1 => "vm",               value1 => $vm,
				name2 => "host",             value2 => $host,
				name3 => "node",             value3 => $node,
				name4 => "lv hash on node1", value4 => $an->data->{vm}{$vm}{node}{$node1}{lv},
				name5 => "lv hash on node2", value5 => $an->data->{vm}{$vm}{node}{$node2}{lv},
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $lv (sort {$a cmp $b} keys %{$an->data->{vm}{$vm}{node}{$node}{lv}})
			{
				#record ($an, "$THIS_FILE ".__LINE__."; lv: [$lv], size: [$an->data->{vm}{$vm}{node}{$node}{lv}{$lv}{size}]\n");
				push @lv_path, $lv;
				push @lv_size, $an->data->{vm}{$vm}{node}{$node}{lv}{$lv}{size};
			}
			
			# Get the network arrays built.
			foreach my $current_bridge (sort {$a cmp $b} keys %{$an->data->{vm}{$vm}{details}{bridge}})
			{
				push @bridge, $current_bridge;
				push @device, $an->data->{vm}{$vm}{details}{bridge}{$current_bridge}{device};
				push @mac,    uc($an->data->{vm}{$vm}{details}{bridge}{$current_bridge}{mac});
				push @type,   $an->data->{vm}{$vm}{details}{bridge}{$current_bridge}{type};
			}
			
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "vm",   value1 => $vm,
				name2 => "host", value2 => $an->data->{vm}{$vm}{host},
			}, file => $THIS_FILE, line => __LINE__});
			if ($an->data->{vm}{$vm}{host} ne "none")
			{
				$say_host     =  $an->data->{vm}{$vm}{host};
				$say_host     =~ s/\..*//;
				$say_net_host =  $an->Web->template({file => "server.html", template => "display-server-details-network-entry", replace => { 
						host	=>	$say_host,
						bridge	=>	$bridge[0],
						device	=>	$device[0],
					}});
			}
		}
		
		# If there is no host, only the device type and MAC address are valid.
		$an->data->{vm}{$vm}{details}{cpu_count} = "#!string!symbol_0011!#" if $an->data->{sys}{gfs2_down};
		$lv_path[0]                          = "#!string!symbol_0011!#" if $an->data->{sys}{gfs2_down};
		$lv_size[0]                          = "#!string!symbol_0011!#" if $an->data->{sys}{gfs2_down};
		$type[0]                             = "#!string!symbol_0011!#" if $an->data->{sys}{gfs2_down};
		$mac[0]                              = "#!string!symbol_0011!#" if $an->data->{sys}{gfs2_down};
		$an->data->{vm}{$vm}{details}{cpu_count} = "--" if not defined $an->data->{vm}{$vm}{details}{cpu_count};
		$say_ram                             = "--" if ((not $say_ram) or ($say_ram =~ /^0 /));
		$lv_path[0]                          = "--" if not defined $lv_path[0];
		$lv_size[0]                          = "--" if not defined $lv_size[0];
		$type[0]                             = "--" if not defined $type[0];
		$mac[0]                              = "--" if not defined $mac[0];
		$server_details_panel .= $an->Web->template({file => "server.html", template => "display-server-details-resources", replace => { 
				say_vm		=>	$say_vm,
				cpu_count	=>	$an->data->{vm}{$vm}{details}{cpu_count},
				say_ram		=>	$say_ram,
				lv_path		=>	$lv_path[0],
				lv_size		=>	$lv_size[0],
				say_net_host	=>	$say_net_host,
				type		=>	$type[0],
				mac		=>	$mac[0],
			}});

		my $lv_count   = @lv_path;
		my $nic_count  = @bridge;
		my $loop_count = $lv_count >= $nic_count ? $lv_count : $nic_count;
		if ($loop_count > 0)
		{
			for (my $i=1; $loop_count > $i; $i++)
			{
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "vm",          value1 => $vm,
					name2 => "lv_path[$i]", value2 => $lv_path[$i],
					name3 => "lv_size[$i]", value3 => $lv_size[$i],
				}, file => $THIS_FILE, line => __LINE__});
				my $say_lv_path = $lv_path[$i] ? $lv_path[$i] : "&nbsp;";
				my $say_lv_size = $lv_size[$i] ? $lv_size[$i] : "&nbsp;";
				my $say_network = "&nbsp;";
				if ($bridge[$i])
				{
					my $say_net_host = "";
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "vm",   value1 => $vm,
						name2 => "host", value2 => $an->data->{vm}{$vm}{host},
					}, file => $THIS_FILE, line => __LINE__});
					if ($an->data->{vm}{$vm}{host} ne "none")
					{
						my $say_host     =  $an->data->{vm}{$vm}{host};
						   $say_host     =~ s/\..*//;
						   $say_net_host =  $an->Web->template({file => "server.html", template => "display-server-details-entra-nics", replace => { 
								say_host	=>	$say_host,
								bridge		=>	$bridge[$i],
								device		=>	$device[$i],
							}});
					}
					$say_network = "$say_net_host <span class=\"highlight_detail\">$type[$i]</span> / <span class=\"highlight_detail\">$mac[$i]</span>";
				}
				
				# Show extra LVs and/or networks.
				$server_details_panel .= $an->Web->template({file => "server.html", template => "display-server-details-entra-storage", replace => { 
						say_lv_path	=>	$say_lv_path,
						say_lv_size	=>	$say_lv_size,
						say_network	=>	$say_network,
					}});
			}
		}
	}
	$server_details_panel .= $an->Web->template({file => "server.html", template => "display-server-details-footer"});

	return ($server_details_panel);
}

# This reads a VM's definition file and pulls out information about the system.
sub read_vm_definition
{
	my ($an, $node, $vm) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "read_vm_definition" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node", value1 => $node, 
		name2 => "vm",   value2 => $vm, 
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $vm)
	{
		AN::Cluster::error($an, "I was asked to look at a server's definition file, but no server was specified.", 1);
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
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "vm",     value1 => $vm,
		name2 => "say_vm", value2 => $say_vm,
	}, file => $THIS_FILE, line => __LINE__});
	$an->data->{vm}{$vm}{definition_file} = "" if not defined $an->data->{vm}{$vm}{definition_file};
	$an->data->{vm}{$vm}{xml}             = "" if not defined $an->data->{vm}{$vm}{xml};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "vm",              value1 => $vm,
		name2 => "say_vm",          value2 => $say_vm,
		name3 => "definition_file", value3 => $an->data->{vm}{$vm}{definition_file},
	}, file => $THIS_FILE, line => __LINE__});

	# Here I want to parse the VM definition XML. Hopefully it was already
	# read in, but if not, I'll make a specific SSH call to get it.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "vm",  value1 => $vm,
		name2 => "XML", value2 => $an->data->{vm}{$vm}{xml},
		name3 => "def", value3 => $an->data->{vm}{$vm}{definition_file},
	}, file => $THIS_FILE, line => __LINE__});
	if ((not ref($an->data->{vm}{$vm}{xml}) eq "ARRAY") && ($an->data->{vm}{$vm}{definition_file}))
	{
		$an->data->{vm}{$vm}{raw_xml} = [];
		$an->data->{vm}{$vm}{xml}     = [];
		my $shell_call = "cat $an->data->{vm}{$vm}{definition_file}";
		my $password   = $an->data->{sys}{root_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$an->data->{node}{$node}{port}, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			push @{$an->data->{vm}{$vm}{raw_xml}}, $line;
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			push @{$an->data->{vm}{$vm}{xml}}, $line;
		}
	}
	
	my $fill_raw_xml = 0;
	my $in_disk      = 0;
	my $in_interface = 0;
	my $current_bridge;
	my $current_device;
	my $current_mac_address;
	my $current_interface_type;
	if (not $an->data->{vm}{$vm}{xml})
	{
		# XML definition not found on the node.
		$an->Log->entry({log_level => 2, message_key => "log_0257", message_variables => {
			node   => $node, 
			server => $vm, 
		}, file => $THIS_FILE, line => __LINE__});
		return (0);
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "vm::${vm}::raw_xml", value1 => $an->data->{vm}{$vm}{raw_xml},
	}, file => $THIS_FILE, line => __LINE__});
	if (not ref($an->data->{vm}{$vm}{raw_xml}) eq "ARRAY")
	{
		$an->data->{vm}{$vm}{raw_xml} = [];
		$fill_raw_xml                 = 1;
	}
	foreach my $line (@{$an->data->{vm}{$vm}{xml}})
	{
		next if not $line;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "vm",           value1 => $vm,
			name2 => "line",         value2 => $line,
			name3 => "fill_raw_xml", value3 => $fill_raw_xml,
		}, file => $THIS_FILE, line => __LINE__});
		push @{$an->data->{vm}{$vm}{raw_xml}}, $line if $fill_raw_xml;
		
		# Pull out RAM amount.
		if ($line =~ /<memory>(\d+)<\/memory>/)
		{
			# Record the memory, multiple by 1024 to get bytes.
			$an->data->{vm}{$vm}{details}{ram} =  $1;
			$an->data->{vm}{$vm}{details}{ram} *= 1024;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "vm",  value1 => $vm,
				name2 => "ram", value2 => $an->data->{vm}{$vm}{details}{ram},
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /<memory unit='(.*?)'>(\d+)<\/memory>/)
		{
			# Record the memory, multiple by 1024 to get bytes.
			my $units                      =  $1;
			my $ram                        =  $2;
			$an->data->{vm}{$vm}{details}{ram} = $an->Readable->hr_to_bytes({size => $ram, type => $units });
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "vm",  value1 => $vm,
				name2 => "ram", value2 => $an->data->{vm}{$vm}{details}{ram},
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# TODO: Support pinned cores.
		# Pull out the CPU details
		if ($line =~ /<vcpu>(\d+)<\/vcpu>/)
		{
			$an->data->{vm}{$vm}{details}{cpu_count} = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "vm",        value1 => $vm,
				name2 => "cpu count", value2 => $an->data->{vm}{$vm}{details}{cpu_count},
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /<vcpu placement='(.*?)'>(\d+)<\/vcpu>/)
		{
			my $cpu_type                         = $1;
			$an->data->{vm}{$vm}{details}{cpu_count} = $2;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "vm",        value1 => $vm,
				name2 => "cpu count", value2 => $an->data->{vm}{$vm}{details}{cpu_count},
				name3 => "type",      value3 => $cpu_type,
			}, file => $THIS_FILE, line => __LINE__});
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
			$an->data->{vm}{$vm}{details}{bridge}{$current_bridge}{device} = $current_device         ? $current_device         : "unknown";
			$an->data->{vm}{$vm}{details}{bridge}{$current_bridge}{mac}    = $current_mac_address    ? $current_mac_address    : "unknown";
			$an->data->{vm}{$vm}{details}{bridge}{$current_bridge}{type}   = $current_interface_type ? $current_interface_type : "unknown";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
				name1 => "vm",     value1 => $vm,
				name2 => "bride",  value2 => $current_bridge,
				name3 => "device", value3 => $an->data->{vm}{$vm}{details}{bridge}{$current_bridge}{device},
				name4 => "mac",    value4 => $an->data->{vm}{$vm}{details}{bridge}{$current_bridge}{mac},
				name5 => "type",   value5 => $an->data->{vm}{$vm}{details}{bridge}{$current_bridge}{type},
			}, file => $THIS_FILE, line => __LINE__});
			$current_bridge         = "";
			$current_device         = "";
			$current_mac_address    = "";
			$current_interface_type = "";
			$in_interface           = 0;
			next;
		}
		if ($in_interface)
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "vm",             value1 => $vm,
				name2 => "interface line", value2 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /source bridge='(.*?)'/)
			{
				$current_bridge = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "vm",     value1 => $vm,
					name2 => "bridge", value2 => $current_bridge,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /mac address='(.*?)'/)
			{
				$current_mac_address = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "vm",  value1 => $vm,
					name2 => "mac", value2 => $current_mac_address,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /target dev='(.*?)'/)
			{
				$current_device = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "vm",     value1 => $vm,
					name2 => "device", value2 => $current_device,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /model type='(.*?)'/)
			{
				$current_interface_type = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "vm",   value1 => $vm,
					name2 => "type", value2 => $current_interface_type,
				}, file => $THIS_FILE, line => __LINE__});
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
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "vm",          value1 => $vm,
					name2 => "checking LV", value2 => $lv,
				}, file => $THIS_FILE, line => __LINE__});
				check_lv($an, $node, $vm, $lv);
			}
		}
		
		# Record what graphics we're using for remote connection.
		if ($line =~ /^<graphics /)
		{
			my ($port)   = ($line =~ / port='(\d+)'/);
			my ($type)   = ($line =~ / type='(.*?)'/);
			my ($listen) = ($line =~ / listen='(.*?)'/);
			$an->Log->entry({log_level => 2, message_key => "log_0230", message_variables => {
				server  => $say_vm, 
				type    => $type,
				address => $listen, 
				port    => $port, 
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{vm}{$vm}{graphics}{type}     = $type;
			$an->data->{vm}{$vm}{graphics}{port}     = $port;
			$an->data->{vm}{$vm}{graphics}{'listen'} = $listen;
		}
	}
	my $xml_line_count = @{$an->data->{vm}{$vm}{raw_xml}};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "xml_line_count", value1 => $xml_line_count,
	}, file => $THIS_FILE, line => __LINE__});
	
	return (0);
}

# This shows a banner asking for patience in anvil-safe-start is running on either node.
sub display_anvil_safe_start_notice
{
	my ($an) = @_;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "display_anvil_safe_start_notice" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_safe_start_notice = "";
	
	my $display_notice = 0;
	my $this_cluster   = $an->data->{cgi}{cluster};
	foreach my $node (sort {$a cmp $b} @{$an->data->{clusters}{$this_cluster}{nodes}})
	{
		$display_notice = 1 if $an->data->{node}{$node}{'anvil-safe-start'};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node}::anvil-safe-start", value1 => $an->data->{node}{$node}{'anvil-safe-start'},
			name2 => "display_notice",                  value2 => $display_notice,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "display_notice", value1 => $display_notice,
	}, file => $THIS_FILE, line => __LINE__});
	if ($display_notice)
	{
		$anvil_safe_start_notice = $an->Web->template({file => "server.html", template => "anvil_safe_start_notice"});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil_safe_start_notice", value1 => $anvil_safe_start_notice,
	}, file => $THIS_FILE, line => __LINE__});
	return($anvil_safe_start_notice)
}

# This shows the current state of the VMs as well as the available control buttons.
sub display_vm_state_and_controls
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "display_vm_state_and_controls" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make it a little easier to print the name of each node
	my $node1 = $an->data->{sys}{cluster}{node1_name};
	my $node2 = $an->data->{sys}{cluster}{node2_name};
	my $node1_long = $an->data->{node}{$node1}{info}{host_name};
	my $node2_long = $an->data->{node}{$node2}{info}{host_name};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node1",      value1 => $node1,
		name2 => "node1_long", value2 => $node1_long,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node2",      value1 => $node2,
		name2 => "node2_long", value2 => $node2_long,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $vm_state_and_control_panel = $an->Web->template({file => "server.html", template => "display-server-state-and-control-header", replace => { 
			anvil			=>	$an->data->{cgi}{cluster},
			node1_short_host_name	=>	$an->data->{node}{$node1}{info}{short_host_name},
			node2_short_host_name	=>	$an->data->{node}{$node2}{info}{short_host_name},
		}});

	foreach my $vm (sort {$a cmp $b} keys %{$an->data->{vm}})
	{
		# Break the name out of the hash key.
		my ($say_vm) = ($vm =~ /^vm:(.*)/);
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "vm",     value1 => $vm,
			name2 => "say vm", value2 => $say_vm,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Use the node's short name for the buttons.
		my $say_start_target     =  $an->data->{vm}{$vm}{boot_target} ? $an->data->{vm}{$vm}{boot_target} : "--";
		$say_start_target        =~ s/\..*?$//;
		my $start_target_long    = $node1_long =~ /$say_start_target/ ? $an->data->{node}{$node1}{info}{host_name} : $an->data->{node}{$node2}{info}{host_name};
		my $start_target_name    = $node1      =~ /$say_start_target/ ? $node1 : $node2;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "say_start_target",       value1 => $say_start_target,
			name2 => "vm::${vm}::boot_target", value2 => $an->data->{vm}{$vm}{boot_target},
			name3 => "start_target_long",      value3 => $start_target_long,
		}, file => $THIS_FILE, line => __LINE__});
		
		my $prefered_host        =  find_prefered_host($an, $vm);
		$prefered_host           =~ s/\..*$//;
		if ($an->data->{vm}{$vm}{boot_target})
		{
			$prefered_host = "<span class=\"highlight_ready\">$prefered_host</span>";
		}
		else
		{
			my $on_host =  $an->data->{vm}{$vm}{host};
			   $on_host =~ s/\..*$//;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "on_host",       value1 => $on_host,
				name2 => "prefered_host", value2 => $prefered_host,
			}, file => $THIS_FILE, line => __LINE__});
			if (($on_host eq $prefered_host) || ($on_host eq "none"))
			{
				$prefered_host = "<span class=\"highlight_good\">$prefered_host</span>";
			}
			else
			{
				$prefered_host = "<span class=\"highlight_warning\">$prefered_host</span>";
			}
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "prefered_host", value1 => $prefered_host,
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		my $say_migration_target =  $an->data->{vm}{$vm}{migration_target};
		$say_migration_target    =~ s/\..*?$//;
		#my $migrate_button = "<span class=\"disabled_button\">#!string!button_0024!#</span>";
		my $migrate_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0024!#" }});
		if ($an->data->{vm}{$vm}{can_migrate})
		{
			# If we're doing a cold migration, ask for confirmation. If this would be a live 
			# migration, just do it.
			my $button_link = "?cluster=".$an->data->{cgi}{cluster}."&vm=$say_vm&task=migrate_vm&target=".$an->data->{vm}{$vm}{migration_target}."&vm_ram=".$an->data->{vm}{$vm}{details}{ram};
			my $server_data = $an->Get->server_data({
				server   => $say_vm, 
				anvil    => $an->data->{cgi}{cluster}, 
			});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "button_link",                 value1 => $button_link,
				name2 => "server_data->migration_type", value2 => $server_data->{migration_type},
			}, file => $THIS_FILE, line => __LINE__});
			if ($server_data->{migration_type} eq "live")
			{
				$button_link .= "&confirm=true";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "button_link",                 value1 => $button_link,
					name2 => "server_data->migration_type", value2 => $server_data->{migration_type},
				}, file => $THIS_FILE, line => __LINE__});
			}
			my $say_target     = $an->String->get({key => "button_0025", variables => { migration_target => $say_migration_target }});
			   $migrate_button = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	$button_link,
					button_text	=>	$say_target,
					id		=>	"migrate_vm_$vm",
				}});
		}
		my $host_node        = $an->data->{vm}{$vm}{host};
		#my $stop_button      = "<span class=\"disabled_button\">#!string!button_0033!#</span>";
		#my $force_off_button = "<span class=\"disabled_button\">#!string!button_0027!#</span>";
		my $stop_button      = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0033!#" }});
		my $force_off_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0027!#" }});
		if ($an->data->{vm}{$vm}{can_stop})
		{
			$host_node        = long_host_name_to_node_name($an, $an->data->{vm}{$vm}{host});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "vm",        value1 => $vm,
				name2 => "host node", value2 => $host_node,
				name3 => "vm host",   value3 => $an->data->{vm}{$vm}{host},
			}, file => $THIS_FILE, line => __LINE__});
			my $expire_time = time + $an->data->{sys}{actime_timeout};
			   $stop_button = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&expire=$expire_time&task=stop_vm&vm=$say_vm&node=$host_node",
					button_text	=>	"#!string!button_0028!#",
					id		=>	"stop_vm_$vm",
				}});
			$force_off_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
					button_class	=>	"highlight_dangerous",
					button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&expire=$expire_time&task=force_off_vm&vm=$say_vm&node=$host_node&host=".$an->data->{vm}{$vm}{host},
					button_text	=>	"#!string!button_0027!#",
					id		=>	"force_off_vm_$say_vm",
				}});
		}
		my $start_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0029!#" }});

		if ($an->data->{vm}{$vm}{boot_target})
		{
			$start_button = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
					button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&task=start_vm&vm=$say_vm&node=$start_target_name&node_cluster_name=$start_target_long&confirm=true",
					button_text	=>	"#!string!button_0029!#",
					id		=>	"start_vm_$vm",
				}});
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "start_button",           value1 => $start_button,
			name2 => "vm::${vm}::boot_target", value2 => $an->data->{vm}{$vm}{boot_target},
		}, file => $THIS_FILE, line => __LINE__});
		
		# I need both nodes up to delete a VM.
		my $say_delete_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0030!#" }});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "node::${node1}::daemon::cman::exit_code", value1 => $an->data->{node}{$node1}{daemon}{cman}{exit_code},
			name2 => "node::${node2}::daemon::cman::exit_code", value2 => $an->data->{node}{$node2}{daemon}{cman}{exit_code},
			name3 => "prefered_host",                           value3 => $prefered_host,
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{node}{$node1}{daemon}{cman}{exit_code} eq "0") && ($an->data->{node}{$node2}{daemon}{cman}{exit_code} eq "0") && ($prefered_host !~ /--/))
		{
			$say_delete_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
					button_class	=>	"highlight_dangerous",
					button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&vm=$say_vm&task=delete_vm",
					button_text	=>	"#!string!button_0030!#",
					id		=>	"delete_vm_$say_vm",
				}});
		}
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "vm::${vm}::say_node1", value1 => $an->data->{vm}{$vm}{say_node1},
			name2 => "vm::${vm}::say_node2", value2 => $an->data->{vm}{$vm}{say_node2},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{vm}{$vm}{node1_ready} == 2)
		{
			$an->data->{vm}{$vm}{say_node1} = "<span class=\"highlight_good\">#!string!state_0003!#</span>";
		}
		elsif ($an->data->{vm}{$vm}{node1_ready} == 1)
		{
			$an->data->{vm}{$vm}{say_node1} = "<span class=\"highlight_ready\">#!string!state_0009!#</span>";
		}
		if ($an->data->{vm}{$vm}{node2_ready} == 2)
		{
			$an->data->{vm}{$vm}{say_node2} = "<span class=\"highlight_good\">#!string!state_0003!#</span>";
		}
		elsif ($an->data->{vm}{$vm}{node2_ready} == 1)
		{
			$an->data->{vm}{$vm}{say_node2} = "<span class=\"highlight_ready\">#!string!state_0009!#</span>";
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "vm::${vm}::say_node1", value1 => $an->data->{vm}{$vm}{say_node1},
			name2 => "vm::${vm}::say_node2", value2 => $an->data->{vm}{$vm}{say_node2},
		}, file => $THIS_FILE, line => __LINE__});
		
		# I don't want to make the VM editable until the cluster is
		# runnong on at least one node.
		my $dual_join   = (($an->data->{node}{$node1}{enable_join}) && ($an->data->{node}{$node2}{enable_join})) ? 1 : 0;
		my $say_vm_link = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
			button_class	=>	"fixed_width_button",
			button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&vm=$vm&task=manage_vm",
			button_text	=>	"$say_vm",
			id		=>	"manage_vm_$say_vm",
		}});
		if ($dual_join)
		{
			my $say_vm_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => $say_vm }});
			   $say_vm_link            = $say_vm_disabled_button;
		}
		
		$vm_state_and_control_panel .= $an->Web->template({file => "server.html", template => "display-server-details-entry", replace => { 
				vm_link			=>	$say_vm_link,
				say_node1		=>	$an->data->{vm}{$vm}{say_node1},
				say_node2		=>	$an->data->{vm}{$vm}{say_node2},
				prefered_host		=>	$prefered_host,
				start_button		=>	$start_button,
				migrate_button		=>	$migrate_button,
				stop_button		=>	$stop_button,
				force_off_button	=>	$force_off_button,
				delete_button		=>	$say_delete_button,
			}});
	}
	
	# When enabling the "Start" button, be sure to start on the highest 
	# priority host in the failover domain, when possible.
	$vm_state_and_control_panel .= $an->Web->template({file => "server.html", template => "display-server-state-and-control-footer"});
	
	return ($vm_state_and_control_panel);
}

# This shows the status of each DRBD resource in the cluster.
sub display_drbd_details
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "display_drbd_details" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make it a little easier to print the name of each node
	my $node1 = $an->data->{sys}{cluster}{node1_name};
	my $node2 = $an->data->{sys}{cluster}{node2_name};
	my $say_node1 = "<span class=\"fixed_width\">".$an->data->{node}{$node1}{info}{short_host_name}."</span>";
	my $say_node2 = "<span class=\"fixed_width\">".$an->data->{node}{$node2}{info}{short_host_name}."</span>";
	my $drbd_details_panel = $an->Web->template({file => "server.html", template => "display-replicated-storage-header", replace => { 
			say_node1	=>	$say_node1,
			say_node2	=>	$say_node2,
		}});

	foreach my $res (sort {$a cmp $b} keys %{$an->data->{drbd}})
	{
		next if not $res;
		# If the DRBD daemon is stopped, I will use the values from the resource files.
		my $say_n1_dev  = "--";
		my $say_n2_dev  = "--";
		my $say_n1_cs   = "--";
		my $say_n2_cs   = "--";
		my $say_n1_ro   = "--";
		my $say_n2_ro   = "--";
		my $say_n1_ds   = "--";
		my $say_n2_ds   = "--";
		
		# Check if node 1 is online.
		if ($an->data->{node}{$node1}{up})
		{
			# It is, but is DRBD running?
			if ($an->data->{node}{$node1}{daemon}{drbd}{exit_code} eq "0")
			{
				# It is. 
				$say_n1_dev = $an->data->{drbd}{$res}{node}{$node1}{device}           if $an->data->{drbd}{$res}{node}{$node1}{device};
				$say_n1_cs  = $an->data->{drbd}{$res}{node}{$node1}{connection_state} if $an->data->{drbd}{$res}{node}{$node1}{connection_state};
				$say_n1_ro  = $an->data->{drbd}{$res}{node}{$node1}{role}             if $an->data->{drbd}{$res}{node}{$node1}{role};
				$say_n1_ds  = $an->data->{drbd}{$res}{node}{$node1}{disk_state}       if $an->data->{drbd}{$res}{node}{$node1}{disk_state};
				if (($an->data->{drbd}{$res}{node}{$node1}{disk_state} eq "Inconsistent") && ($an->data->{drbd}{$res}{node}{$node1}{resync_percent} =~ /^\d/))
				{
					$say_n1_ds .= " <span class=\"subtle_text\" style=\"font-style: normal;\">($an->data->{drbd}{$res}{node}{$node1}{resync_percent}%)</span>";
				}
			}
			else
			{
				# It is not, use the {res_file} values.
				$say_n1_dev = $an->data->{drbd}{$res}{node}{$node1}{res_file}{device}           if $an->data->{drbd}{$res}{node}{$node1}{res_file}{device};
				$say_n1_cs  = $an->data->{drbd}{$res}{node}{$node1}{res_file}{connection_state} if $an->data->{drbd}{$res}{node}{$node1}{res_file}{connection_state};
				$say_n1_ro  = $an->data->{drbd}{$res}{node}{$node1}{res_file}{role}             if $an->data->{drbd}{$res}{node}{$node1}{res_file}{role};
				$say_n1_ds  = $an->data->{drbd}{$res}{node}{$node1}{res_file}{disk_state}       if $an->data->{drbd}{$res}{node}{$node1}{res_file}{disk_state};
			}
		}
		# Check if node 2 is online.
		if ($an->data->{node}{$node2}{up})
		{
			# It is, but is DRBD running?
			if ($an->data->{node}{$node2}{daemon}{drbd}{exit_code} eq "0")
			{
				# It is. 
				$say_n2_dev = $an->data->{drbd}{$res}{node}{$node2}{device}           if $an->data->{drbd}{$res}{node}{$node2}{device};
				$say_n2_cs  = $an->data->{drbd}{$res}{node}{$node2}{connection_state} if $an->data->{drbd}{$res}{node}{$node2}{connection_state};
				$say_n2_ro  = $an->data->{drbd}{$res}{node}{$node2}{role}             if $an->data->{drbd}{$res}{node}{$node2}{role};
				$say_n2_ds  = $an->data->{drbd}{$res}{node}{$node2}{disk_state}       if $an->data->{drbd}{$res}{node}{$node2}{disk_state};
				if (($an->data->{drbd}{$res}{node}{$node2}{disk_state} eq "Inconsistent") && ($an->data->{drbd}{$res}{node}{$node2}{resync_percent} =~ /^\d/))
				{
					$say_n2_ds .= " <span class=\"subtle_text\" style=\"font-style: normal;\">($an->data->{drbd}{$res}{node}{$node2}{resync_percent}%)</span>";
				}
			}
			else
			{
				# It is not, use the {res_file} values.
				$say_n2_dev = $an->data->{drbd}{$res}{node}{$node2}{res_file}{device}           if $an->data->{drbd}{$res}{node}{$node2}{res_file}{device};
				$say_n2_cs  = $an->data->{drbd}{$res}{node}{$node2}{res_file}{connection_state} if $an->data->{drbd}{$res}{node}{$node2}{res_file}{connection_state};
				$say_n2_ro  = $an->data->{drbd}{$res}{node}{$node2}{res_file}{role}             if $an->data->{drbd}{$res}{node}{$node2}{res_file}{role};
				$say_n2_ds  = $an->data->{drbd}{$res}{node}{$node2}{res_file}{disk_state}       if $an->data->{drbd}{$res}{node}{$node2}{res_file}{disk_state};
			}
		}
		
		my $class_n1_cs        =  "highlight_unavailable";
		   $class_n1_cs        =  "highlight_good"    if $say_n1_cs eq "Connected";
		   $class_n1_cs        =  "highlight_good"    if $say_n1_cs eq "SyncSource";
		   $class_n1_cs        =  "highlight_ready"   if $say_n1_cs eq "WFConnection";
		   $class_n1_cs        =  "highlight_ready"   if $say_n1_cs eq "PausedSyncS";
		   $class_n1_cs        =  "highlight_warning" if $say_n1_cs eq "PausedSyncT";
		   $class_n1_cs        =  "highlight_warning" if $say_n1_cs eq "SyncTarget";
		my $class_n2_cs        =  "highlight_unavailable";
		   $class_n2_cs        =  "highlight_good"    if $say_n2_cs eq "Connected";
		   $class_n2_cs        =  "highlight_good"    if $say_n2_cs eq "SyncSource";
		   $class_n2_cs        =  "highlight_ready"   if $say_n2_cs eq "WFConnection";
		   $class_n2_cs        =  "highlight_ready"   if $say_n2_cs eq "PausedSyncS";
		   $class_n2_cs        =  "highlight_warning" if $say_n2_cs eq "PausedSyncT";
		   $class_n2_cs        =  "highlight_warning" if $say_n2_cs eq "SyncTarget";
		my $class_n1_ro        =  "highlight_unavailable";
		   $class_n1_ro        =  "highlight_good"    if $say_n1_ro eq "Primary";
		   $class_n1_ro        =  "highlight_warning" if $say_n1_ro eq "Secondary";
		my $class_n2_ro        =  "highlight_unavailable";
		   $class_n2_ro        =  "highlight_good"    if $say_n2_ro eq "Primary";
		   $class_n2_ro        =  "highlight_warning" if $say_n2_ro eq "Secondary";
		my $class_n1_ds        =  "highlight_unavailable";
		   $class_n1_ds        =  "highlight_good"    if $say_n1_ds eq "UpToDate";
		   $class_n1_ds        =  "highlight_warning" if $say_n1_ds       = ~ /Inconsistent/;
		   $class_n1_ds        =  "highlight_warning" if $say_n1_ds eq "Outdated";
		   $class_n1_ds        =  "highlight_bad"     if $say_n1_ds eq "Diskless";
		my $class_n2_ds        =  "highlight_unavailable";
		   $class_n2_ds        =  "highlight_good"    if $say_n2_ds eq "UpToDate";
		   $class_n2_ds        =  "highlight_warning" if $say_n2_ds       = ~ /Inconsistent/;
		   $class_n2_ds        =  "highlight_warning" if $say_n2_ds eq "Outdated";
		   $class_n2_ds        =  "highlight_bad"     if $say_n2_ds eq "Diskless";
		   $drbd_details_panel .= $an->Web->template({file => "server.html", template => "display-replicated-storage-entry", replace => { 
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
			}});
	}
	$drbd_details_panel .= $an->Web->template({file => "server.html", template => "display-replicated-storage-footer"});
	
	return ($drbd_details_panel);
}

# This shows the details on each node's GFS2 mount(s)
sub display_gfs2_details
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "display_gfs2_details" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Make it a little easier to print the name of each node
	my $node1              = $an->data->{sys}{cluster}{node1_name};
	my $node2              = $an->data->{sys}{cluster}{node2_name};
	my $say_node1          = "<span class=\"fixed_width\">".$an->data->{node}{$node1}{info}{short_host_name}."</span>";
	my $say_node2          = "<span class=\"fixed_width\">".$an->data->{node}{$node2}{info}{short_host_name}."</span>";
	my $gfs2_details_panel = $an->Web->template({file => "server.html", template => "display-cluster-storage-header", replace => { 
			say_node1	=>	$say_node1,
			say_node2	=>	$say_node2,
		}});

	my $gfs2_hash = "";
	my $node      = "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node1 - cman exit code", value1 => $an->data->{node}{$node1}{daemon}{cman}{exit_code},
		name2 => "gfs2 exit code",         value2 => $an->data->{node}{$node1}{daemon}{gfs2}{exit_code},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node2 - cman exit code", value1 => $an->data->{node}{$node2}{daemon}{cman}{exit_code},
		name2 => "gfs2 exit code",         value2 => $an->data->{node}{$node2}{daemon}{gfs2}{exit_code},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node1}{daemon}{cman}{exit_code} eq "0") && ($an->data->{node}{$node1}{daemon}{gfs2}{exit_code} eq "0") && (ref($an->data->{node}{$node1}{gfs}) eq "HASH"))
	{
		$gfs2_hash = $an->data->{node}{$node1}{gfs};
		$node      = $node1;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "using node1's gfs2 hash", value1 => $gfs2_hash,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif (($an->data->{node}{$node2}{daemon}{cman}{exit_code} eq "0") && ($an->data->{node}{$node2}{daemon}{gfs2}{exit_code} eq "0") && (ref($an->data->{node}{$node2}{gfs}) eq "HASH"))
	{
		$gfs2_hash = $an->data->{node}{$node2}{gfs};
		$node      = $node2;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "using node2's gfs2 hash", value1 => $gfs2_hash,
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Neither node has the GFS2 partition mounted. Use the data from /etc/fstab. This is what
		# will be stored in either node's hash. So pick a node that's online and use it.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "up nodes", value1 => $an->data->{sys}{up_nodes},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{sys}{up_nodes} == 1)
		{
			# Neither node has the GFS2 partition mounted.
			$an->Log->entry({log_level => 2, message_key => "log_0259", file => $THIS_FILE, line => __LINE__});
			$node      = @{$an->data->{up_nodes}}[0];
			$gfs2_hash = $an->data->{node}{$node}{gfs};
		}
		else
		{
			# Neither node is online at all.
			$gfs2_details_panel .= $an->Web->template({file => "server.html", template => "display-cluster-storage-not-online"});
		}
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "gfs2_hash",  value1 => $gfs2_hash,
		name2 => "node1 hash", value2 => ref($an->data->{node}{$node1}{gfs}),
		name3 => "node2 hash", value3 => ref($an->data->{node}{$node2}{gfs}),
	}, file => $THIS_FILE, line => __LINE__});
	if (ref($gfs2_hash) eq "HASH")
	{
		foreach my $mount_point (sort {$a cmp $b} keys %{$gfs2_hash})
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "node::${node1}::gfs::${mount_point}::mounted", value1 => $an->data->{node}{$node1}{gfs}{$mount_point}{mounted},
				name2 => "node::${node2}::gfs::${mount_point}::mounted", value2 => $an->data->{node}{$node2}{gfs}{$mount_point}{mounted},
			}, file => $THIS_FILE, line => __LINE__});
			my $say_node1_mounted = $an->data->{node}{$node1}{gfs}{$mount_point}{mounted} ? "<span class=\"highlight_good\">#!string!state_0010!#</span>" : "<span class=\"highlight_bad\">#!string!state_0011!#</span>";
			my $say_node2_mounted = $an->data->{node}{$node2}{gfs}{$mount_point}{mounted} ? "<span class=\"highlight_good\">#!string!state_0010!#</span>" : "<span class=\"highlight_bad\">#!string!state_0011!#</span>";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "say_node1_mounted", value1 => $say_node1_mounted,
				name2 => "say_node2_mounted", value2 => $say_node2_mounted,
			}, file => $THIS_FILE, line => __LINE__});
			my $say_size         = "--";
			my $say_used         = "--";
			my $say_used_percent = "--%";
			my $say_free         = "--";
			
			# This is to avoid the "undefined variable" errors in
			# the log from when a node isn't online.
			$an->data->{node}{$node1}{gfs}{$mount_point}{total_size} = "" if not defined $an->data->{node}{$node1}{gfs}{$mount_point}{total_size};
			$an->data->{node}{$node2}{gfs}{$mount_point}{total_size} = "" if not defined $an->data->{node}{$node2}{gfs}{$mount_point}{total_size};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "node1 total size", value1 => $an->data->{node}{$node1}{gfs}{$mount_point}{total_size},
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "node2 total size", value1 => $an->data->{node}{$node2}{gfs}{$mount_point}{total_size},
			}, file => $THIS_FILE, line => __LINE__});
			if ($an->data->{node}{$node1}{gfs}{$mount_point}{total_size} =~ /^\d/)
			{
				$say_size         = $an->data->{node}{$node1}{gfs}{$mount_point}{total_size};
				$say_used         = $an->data->{node}{$node1}{gfs}{$mount_point}{used_space};
				$say_used_percent = $an->data->{node}{$node1}{gfs}{$mount_point}{percent_used};
				$say_free         = $an->data->{node}{$node1}{gfs}{$mount_point}{free_space};
			}
			elsif ($an->data->{node}{$node2}{gfs}{$mount_point}{total_size} =~ /^\d/)
			{
				$say_size         = $an->data->{node}{$node2}{gfs}{$mount_point}{total_size};
				$say_used         = $an->data->{node}{$node2}{gfs}{$mount_point}{used_space};
				$say_used_percent = $an->data->{node}{$node2}{gfs}{$mount_point}{percent_used};
				$say_free         = $an->data->{node}{$node2}{gfs}{$mount_point}{free_space};
			}
			$gfs2_details_panel .= $an->Web->template({file => "server.html", template => "display-cluster-storage-entry", replace => { 
					mount_point		=>	$mount_point,
					say_node1_mounted	=>	$say_node1_mounted,
					say_node2_mounted	=>	$say_node2_mounted,
					say_size		=>	$say_size,
					say_used		=>	$say_used,
					say_used_percent	=>	$say_used_percent,
					say_free		=>	$say_free,
				}});
		}
	}
	else
	{
		# No gfs2 FSes found
		$gfs2_details_panel .= $an->Web->template({file => "server.html", template => "display-cluster-storage-no-entries-found"});
	}
	$gfs2_details_panel .= $an->Web->template({file => "server.html", template => "display-cluster-storage-footer"});

	return ($gfs2_details_panel);
}

# This shows the user the state of the nodes and their daemons.
sub display_node_details
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "display_node_details" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $this_cluster = $an->data->{cgi}{cluster};
	my $node1 = $an->data->{sys}{cluster}{node1_name};
	my $node2 = $an->data->{sys}{cluster}{node2_name};
	my $node1_long = $an->data->{node}{$node1}{info}{host_name};
	my $node2_long = $an->data->{node}{$node2}{info}{host_name};
	
	my $i = 0;
	my @host_name;
	my @cman;
	my @rgmanager;
	my @drbd;
	my @clvmd;
	my @gfs2;
	my @libvirtd;
	
	foreach my $node (sort {$a cmp $b} @{$an->data->{clusters}{$this_cluster}{nodes}})
	{
		# Get the cluster's node name.
		my $say_short_name =  $node;
		$say_short_name    =~ s/\..*//;
		my $node_long_name =  $node1_long =~ /$say_short_name/ ? $an->data->{node}{$node1}{info}{host_name} : $an->data->{node}{$node2}{info}{host_name};
		
		$host_name[$i] = $an->data->{node}{$node}{info}{short_host_name};
		$cman[$i]      = $an->data->{node}{$node}{daemon}{cman}{status};
		$rgmanager[$i] = $an->data->{node}{$node}{daemon}{rgmanager}{status};
		$drbd[$i]      = $an->data->{node}{$node}{daemon}{drbd}{status};
		$clvmd[$i]     = $an->data->{node}{$node}{daemon}{clvmd}{status};
		$gfs2[$i]      = $an->data->{node}{$node}{daemon}{gfs2}{status};
		$libvirtd[$i]  = $an->data->{node}{$node}{daemon}{libvirtd}{status};
		$i++;
	}
	
	my $node_details_panel = $an->Web->template({file => "server.html", template => "display-node-details-full", replace => { 
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
		}});

	return ($node_details_panel);
}

# This shows the controls for the nodes.
sub display_node_controls
{
	my ($an) = @_;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "display_node_controls" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});

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
	my $expire_time = time + $an->data->{sys}{actime_timeout};
	my $disable_join = 0;
	my $this_cluster = $an->data->{cgi}{cluster};
	my $node1 = $an->data->{sys}{cluster}{node1_name};
	my $node2 = $an->data->{sys}{cluster}{node2_name};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node1", value1 => $node1,
		name2 => "node2", value2 => $node2,
	}, file => $THIS_FILE, line => __LINE__});
	my $node1_long = $an->data->{node}{$node1}{info}{host_name};
	my $node2_long = $an->data->{node}{$node2}{info}{host_name};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_long", value1 => $node1_long,
		name2 => "node2_long", value2 => $node2_long,
	}, file => $THIS_FILE, line => __LINE__});
	my $rowspan    = 2;
	my $dual_boot  = (($an->data->{node}{$node1}{enable_poweron}) && ($an->data->{node}{$node2}{enable_poweron})) ? 1 : 0;
	my $dual_join  = (($an->data->{node}{$node1}{enable_join})    && ($an->data->{node}{$node2}{enable_join}))    ? 1 : 0;
	my $cold_stop  = ($an->data->{sys}{up_nodes} > 0)                                                         ? 1 : 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "sys::up_nodes", value1 => $an->data->{sys}{up_nodes},
		name2 => "dual_boot",     value2 => $dual_boot,
		name3 => "dual_join",     value3 => $dual_join,
		name4 => "cold_stop",     value4 => $cold_stop,
	}, file => $THIS_FILE, line => __LINE__});
	
	foreach my $node (sort {$a cmp $b} @{$an->data->{clusters}{$this_cluster}{nodes}})
	{
		# Get the cluster's node name.
		my $say_short_name =  $node;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "say_short_name", value1 => $say_short_name,
		}, file => $THIS_FILE, line => __LINE__});
		$say_short_name    =~ s/\..*//;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "say_short_name",                  value1 => $say_short_name,
			name2 => "node::${node1}::info::host_name", value2 => $an->data->{node}{$node1}{info}{host_name},
			name3 => "node::${node2}::info::host_name", value3 => $an->data->{node}{$node2}{info}{host_name},
		}, file => $THIS_FILE, line => __LINE__});
		my $node_long_name = "";
		if ($node1_long =~ /$say_short_name/)
		{
			$node_long_name = $an->data->{node}{$node1}{info}{host_name};
		}
		elsif ($node2_long =~ /$say_short_name/)
		{
			$node_long_name = $an->data->{node}{$node2}{info}{host_name};
		}
		else
		{
			# The name in the config doesn't match the name in the cluster.
			$node_long_name = "??";
			$an->Log->entry({log_level => 3, message_key => "log_0260", message_variables => {
				node => $say_short_name, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "node_long_name", value1 => $node_long_name,
		}, file => $THIS_FILE, line => __LINE__});
		$an->data->{node}{$node}{enable_withdraw} = 0 if not defined $an->data->{node}{$node}{enable_withdraw};
		
		# Join button.
		my $say_join_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0031!#" }});
		
		### TODO: See if the peer is online already and, if so, add 'confirm=true' as the join is safe.
		my $say_join_enabled_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
				button_class	=>	"bold_button",
				button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&task=join_cluster&node=$node&node_cluster_name=$node_long_name",
				button_text	=>	"#!string!button_0031!#",
				id		=>	"join_cluster_$node",
			}});
		$say_join[$i] = $an->data->{node}{$node}{enable_join} ? $say_join_enabled_button : $say_join_disabled_button;
		$say_join[$i] = $say_join_disabled_button if $disable_join;
		   
		# Withdraw button
		my $say_withdraw_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0032!#" }});
		my $say_withdraw_enabled_button  = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&task=withdraw&node=$node&node_cluster_name=$node_long_name",
				button_text	=>	"#!string!button_0032!#",
				id		=>	"withdraw_$node",
			}});
		$say_withdraw[$i] = $an->data->{node}{$node}{enable_withdraw} ? $say_withdraw_enabled_button : $say_withdraw_disabled_button;
		
		# Shutdown button
		my $say_shutdown_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0033!#" }});
		my $say_shutdown_enabled_button  = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
				button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&expire=$expire_time&task=poweroff_node&node=$node&node_cluster_name=$node_long_name",
				button_text	=>	"#!string!button_0033!#",
				id		=>	"poweroff_node_$node",
			}});
		$say_shutdown[$i] = $an->data->{node}{$node}{enable_poweroff} ? $say_shutdown_enabled_button : $say_shutdown_disabled_button;
		
		# Boot button
		my $say_boot_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0034!#" }});
		my $say_boot_enabled_button  = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
				button_class	=>	"bold_button",
				button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&task=poweron_node&node=$node&node_cluster_name=$node_long_name&confirm=true",
				button_text	=>	"#!string!button_0034!#",
				id		=>	"poweron_node_$node",
			}});
		$say_boot[$i] = $an->data->{node}{$node}{enable_poweron} ? $say_boot_enabled_button : $say_boot_disabled_button;
		
		# Fence button
		# If the node is already confirmed off, no need to fence.
		my $say_fence_node_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0037!#" }});
		my $expire_time                    = time + $an->data->{sys}{actime_timeout};
		# &expire=$expire_time
		my $say_fence_node_enabled_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
				button_class	=>	"highlight_dangerous",
				button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&expire=$expire_time&task=fence_node&node=$node&node_cluster_name=$node_long_name",
				button_text	=>	"#!string!button_0037!#",
				id		=>	"fence_node_$node",
			}});
		$say_fence[$i] = $an->data->{node}{$node}{enable_poweron} ? $say_fence_node_disabled_button : $say_fence_node_enabled_button;
		
		# Dual-boot/Cold-Stop button.
		if ($i == 0)
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "i", value1 => $i,
			}, file => $THIS_FILE, line => __LINE__});
			my $say_boot_or_stop_disabled_button =  $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0035!#" }});
			   $say_boot_or_stop_disabled_button =~ s/\n$//;
			   $say_boot_or_stop                 =  $say_boot_or_stop_disabled_button;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "say_boot_or_stop", value1 => $say_boot_or_stop,
			}, file => $THIS_FILE, line => __LINE__});
			
			# If either node is up, offer the 'Cold-Stop Anvil!'
			# button.
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "cold_stop", value1 => $cold_stop,
			}, file => $THIS_FILE, line => __LINE__});
			if ($cold_stop)
			{
				my $expire_time      = time + $an->data->{sys}{actime_timeout};
				   $say_boot_or_stop = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
						button_class	=>	"bold_button",
						button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&expire=$expire_time&task=cold_stop",
						button_text	=>	"#!string!button_0062!#",
						id		=>	"dual_boot",
					}});
				$say_boot_or_stop =~ s/\n$//;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "say_boot_or_stop", value1 => $say_boot_or_stop,
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			# Dual-Join button
			my $say_dual_join_disabled_button =  $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0036!#" }});
			   $say_dual_join_disabled_button =~ s/\n$//;
			   $say_dual_join                 =  $say_dual_join_disabled_button;
			if ($rowspan)
			{
				# First row.
				if ($dual_boot)
				{
					$say_boot_or_stop = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
							button_class	=>	"bold_button",
							button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&task=dual_boot&confirm=true",
							button_text	=>	"#!string!button_0035!#",
							id		=>	"dual_boot",
						}});
					$say_boot_or_stop =~ s/\n$//;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "say_boot_or_stop", value1 => $say_boot_or_stop,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($dual_join)
				{
					$say_dual_join = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
							button_class	=>	"bold_button",
							button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&task=dual_join&confirm=true",
							button_text	=>	"#!string!button_0036!#",
							id		=>	"dual_join",
						}});
					# Disable the per-node "join" options".
					$say_join[$i] = $say_join_disabled_button;
					$disable_join = 1;
				}
			}
		}
		
		# Make the node names click-able to show the hardware states.
		$say_node_name[$i] = $an->data->{node}{$node}{info}{host_name};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "i",                              value1 => $i,
			name2 => "node::${node}::info::host_name", value2 => $an->data->{node}{$node}{info}{host_name},
			name3 => "say_node_name",                  value3 => $say_node_name[$i],
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{node}{$node}{connected})
		{
			$say_node_name[$i] = $an->Web->template({file => "common.html", template => "enabled-button-new-tab", replace => { 
					button_class	=>	"fixed_width_button",
					button_link	=>	"?cluster=".$an->data->{cgi}{cluster}."&task=display_health&node=$node&node_cluster_name=$node_long_name",
					button_text	=>	$an->data->{node}{$node}{info}{host_name},
					id		=>	"display_health_$node",
				}});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "i",             value1 => $i,
				name2 => "say_node_name", value2 => $say_node_name[$i],
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			$say_node_name[$i] = $an->Web->template({file => "common.html", template => "disabled-button-with-class", replace => { 
					button_class	=>	"highlight_offline_fixed_width_button",
					button_text	=>	$an->data->{node}{$node}{info}{host_name},
				}});
		}
		$rowspan = 0;
		$i++;
	}
	
	my $boot_or_stop = "";
	my $hard_reset   = "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "say_boot_or_stop", value1 => $say_boot_or_stop,
		name2 => "say_hard_reset",   value2 => $say_hard_reset,
	}, file => $THIS_FILE, line => __LINE__});
	if ($say_hard_reset)
	{
		$boot_or_stop = $an->Web->template({file => "server.html", template => "boot-or-stop-two-buttons", replace => { button => $say_boot_or_stop }});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "boot_or_stop", value1 => $boot_or_stop,
		}, file => $THIS_FILE, line => __LINE__});
		$hard_reset = $an->Web->template({file => "server.html", template => "boot-or-stop-two-buttons", replace => { button => $say_hard_reset }});
	}
	else
	{
		$boot_or_stop = $an->Web->template({file => "server.html", template => "boot-or-stop-one-button", replace => { button => $say_boot_or_stop }});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "boot_or_stop", value1 => $boot_or_stop,
		}, file => $THIS_FILE, line => __LINE__});
	}
	my $node_control_panel = $an->Web->template({file => "server.html", template => "display-node-controls-full", replace => { 
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
		}});
	
	return ($node_control_panel);
}

1;
