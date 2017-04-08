package AN::Tools::HardwareLSI;
# 
# This module contains methods used to manage hardware LSI RAID controllers via Striker's WebUI.
# 

use strict;
use warnings;
use Data::Dumper;

our $VERSION  = "0.1.001";
my $THIS_FILE = "HardwareLSI.pm";

### Methods;
# _add_disk_to_array
# _control_disk_id_led
# _clear_foreign_state
# _display_node_health
# _get_missing_disks
# _get_rebuild_progress
# _get_storage_data
# _make_disk_good
# _make_disk_hot_spare
# _mark_disk_missing
# _put_disk_offline
# _put_disk_online
# _spin_disk_down
# _spin_disk_up
# _unmake_disk_as_hot_spare

#############################################################################################################
# House keeping methods                                                                                     #
#############################################################################################################

sub new
{
	my $class = shift;
	
	my $self  = {};
	
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

# This adds an "Unconfigured Good" disk to the specified array.
sub _add_disk_to_array
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_add_disk_to_array" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target   = defined $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = defined $parameter->{port}     ? $parameter->{port}     : "";
	my $password = defined $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target,
		name2 => "port",   value2 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $success           = 0;
	my $return_string     = "";
	
	my $shell_call = $an->data->{path}{megacli64}." PdReplaceMissing PhysDrv [".$an->data->{cgi}{disk_address}."] -array".$an->data->{cgi}{logical_disk}." -row".$an->data->{cgi}{row}." -a".$an->data->{cgi}{adapter};
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
		# This will do the rescan when done.
		$an->HardwareLSI->_put_disk_online({
			target   => $target, 
			port     => $port, 
			password => $password, 
		});
	}
	
	return(0);
}

# This turns on or off the "locate" LED on the hard drives.
sub _control_disk_id_led
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_control_disk_id_led" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $action   = defined $parameter->{action}   ? $parameter->{action}   : "";
	my $target   = defined $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = defined $parameter->{port}     ? $parameter->{port}     : "";
	my $password = defined $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "action", value1 => $action,
		name2 => "target", value2 => $target,
		name3 => "port",   value3 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $success           = 0;
	my $return_string     = "";
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
	
	my $shell_call = $an->data->{path}{megacli64}." PdLocate $action physdrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
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

# Thus clears a disk's foreign state
sub _clear_foreign_state
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_clear_foreign_state" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target   = defined $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = defined $parameter->{port}     ? $parameter->{port}     : "";
	my $password = defined $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target,
		name2 => "port",   value2 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Mark the disk as a global hot-spare.
	my $success       = 0;
	my $return_string = "";
	my $shell_call    = $an->data->{path}{megacli64}." CfgForeign Clear -a".$an->data->{cgi}{adapter};
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

# This is the old health page that only displayed the health status of the LSI controller and its 
# devices/arrays.
sub _display_node_health
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_display_node_health" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_uuid = $an->data->{sys}{anvil}{uuid};
	my $anvil_name = $an->data->{sys}{anvil}{name};
	my $node_name  = $an->data->{cgi}{node_name};
	my $target     = defined $parameter->{target}   ? $parameter->{target}   : "";
	my $port       = defined $parameter->{port}     ? $parameter->{port}     : "";
	my $password   = defined $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "anvil_uuid", value1 => $anvil_uuid,
		name2 => "anvil_name", value2 => $anvil_name,
		name3 => "node_name",  value3 => $node_name,
		name4 => "target",     value4 => $target,
		name5 => "port",       value5 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Open up the table.
	my $message = $an->String->get({key => "lsi_0046", variables => { node_name => $node_name }});
	print $an->Web->template({file => "lsi-storage.html", template => "lsi-adapter-health-header", replace => { 
		anvil		=>	$anvil_name,
		node_name	=>	$node_name,
		message		=>	$message,
	}});
	
	# Display results.
	if ($an->data->{path}{megacli64})
	{
		# Displaying storage
		$an->Log->entry({log_level => 2, message_key => "log_0218", file => $THIS_FILE, line => __LINE__});
		foreach my $this_adapter (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "this_adapter", value1 => $this_adapter,
			}, file => $THIS_FILE, line => __LINE__});
			
			foreach my $this_logical_disk (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "this_logical_disk", value1 => $this_logical_disk,
				}, file => $THIS_FILE, line => __LINE__});
				
				foreach my $this_enclosure_device_id (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}})
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "this_enclosure_device_id", value1 => $this_enclosure_device_id,
					}, file => $THIS_FILE, line => __LINE__});
					
					foreach my $this_slot_number (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}})
					{
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "this_slot_number", value1 => $this_slot_number,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
			}
			my $say_bbu                        = $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu_is}                        ? "Present" : "Not Installed";
			my $say_flash                      = $an->data->{storage}{lsi}{adapter}{$this_adapter}{flash_is}                      ? "Present" : "Not Installed";
			my $say_restore_hotspare_on_insert = $an->data->{storage}{lsi}{adapter}{$this_adapter}{restore_hotspare_on_insertion} ? "Yes"     : "No";
			my $say_title                      = $an->String->get({key => "lsi_0040", variables => { adapter => $this_adapter }});

			print $an->Web->template({file => "lsi-storage.html", template => "lsi-adapter-state", replace => { 
				title				=>	$say_title,
				model				=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{product_name},
				cache_size			=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{cache_size},
				bbu				=>	$say_bbu,
				flash_module			=>	$say_flash,
				restore_hotspare_on_insert	=>	$say_restore_hotspare_on_insert,
			}});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "storage::lsi::adapter::${this_adapter}::bbu_is", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{bbu_is},
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
				my $say_bad_blocks =          $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{bad_blocks_exist} ? "Yes" : "No";
				my $say_size       =  defined $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{size} ? $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{size} : 0;
				   $say_size       =~ s/(\w)B/$1iB/;	# They use 'GB' when it should be 'GiB'.
				my $logical_disk_state_class = "highlight_good";
				my $say_missing    = "";
				my $allow_offline  = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::state", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'},
				}, file => $THIS_FILE, line => __LINE__});
				if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'} =~ /Degraded/i)
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::state", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'},
					}, file => $THIS_FILE, line => __LINE__});
					
					$an->HardwareLSI->_get_missing_disks({
						adapter      => $this_adapter, 
						logical_disk => $this_logical_disk,
						target       => $target, 
						port         => $port, 
						password     => $password, 
					});
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
					# Unconfigured disks, show the list header in the place of the logic
					# disk state.
					print $an->Web->template({file => "lsi-storage.html", template => "lsi-unassigned-disks"});
				}
				else
				{
					# Real logical disk
					next if not $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'};
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::state", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'},
					}, file => $THIS_FILE, line => __LINE__});
					my $title = $an->String->get({key => "title_0021", variables => { logical_disk => $this_logical_disk }});
					my $url   = $an->String->get({key => "url_0009", variables => { raid_level => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{primary_raid_level} }});
					print $an->Web->template({file => "lsi-storage.html", template => "lsi-logical-disk-state", replace => { 
						title				=>	$title,
						logical_disk_state		=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'},
						logical_disk_state_class	=>	$logical_disk_state_class,
						missing				=>	$say_missing,
						bad_blocks_exist		=>	$say_bad_blocks,
						primary_raid_level		=>	$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{primary_raid_level},
						raid_url			=>	$url,
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
						
						my $say_offline_disabled_button = $an->Web->template({file => "common.html", template => "disabled-button", replace => { button_text => "#!string!button_0075!#" }});
						my $offline_button              = $say_offline_disabled_button;
						if ($allow_offline)
						{
							$offline_button = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
									button_link	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&node_name=".$an->data->{cgi}{node_name}."&task=display_health&do=put_disk_offline&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter&logical_disk=$this_logical_disk",
									button_text	=>	"#!string!button_0006!#",
									id		=>	"put_disk_offline_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
								}});
							if ($this_logical_disk == 9999)
							{
								$offline_button = $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
										button_link	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&node_name=".$an->data->{cgi}{node_name}."&task=display_health&do=spin_disk_down&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter&logical_disk=$this_logical_disk",
										button_text	=>	"#!string!button_0007!#",
										id		=>	"spin_disk_down_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
									}});
							}
						}
						
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::firmware_state", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state},
						}, file => $THIS_FILE, line => __LINE__});
						my $disk_state_class = "highlight_good";
						my $say_disk_action  = "";
						if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Unconfigured(bad)")
						{
							$disk_state_class =  "highlight_bad";
							$say_disk_action  .= $an->Web->template({file => "common.html", template => "new_line"});
							$say_disk_action  .= $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
									button_class	=>	"highlight_warning",
									button_link	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&node_name=".$an->data->{cgi}{node_name}."&task=display_health&do=make_disk_good&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
									button_text	=>	"#!string!button_0008!#",
									id		=>	"make_disk_good_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
								}});
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "say_disk_action", value1 => $say_disk_action,
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Offline")
						{
							$disk_state_class = "highlight_detail";
							my $say_put_disk_online_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
									button_class	=>	$disk_state_class,
									button_link	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&node_name=".$an->data->{cgi}{node_name}."&task=display_health&do=put_disk_online&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
									button_text	=>	"#!string!button_0009!#",
									id		=>	"put_disk_online__${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
								}});
							my $say_spin_disk_down_button = $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
									button_class	=>	$disk_state_class,
									button_link	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&node_name=".$an->data->{cgi}{node_name}."&task=display_health&do=spin_disk_down&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
									button_text	=>	"#!string!button_0007!#",
									id		=>	"spin_disk_down",
								}});
							$say_disk_action .= " - $say_put_disk_online_button - $say_spin_disk_down_button";
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "say_disk_action", value1 => $say_disk_action,
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Rebuild")
						{
							# Array is rebuilding, read the progress.
							my ($rebuild_percent, $time_to_complete) = $an->HardwareLSI->_get_rebuild_progress({
									target	     => $target, 
									port         => $port, 
									password     => $password,
									disk_address => "$this_enclosure_device_id:$this_slot_number",
									adapter      => $this_adapter
								});
							$disk_state_class =  "highlight_warning";
							$say_disk_action  .= $an->String->get({key => "lsi_0042", variables => { 
									rebuild_percent		=>	$rebuild_percent,
									time_to_complete	=>	$time_to_complete,
								}});
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "say_disk_action", value1 => $say_disk_action,
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Unconfigured(good), Spun Up")
						{
							$disk_state_class = "highlight_detail";
							foreach my $this_logical_disk (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}})
							{
								$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
									name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::state", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'},
								}, file => $THIS_FILE, line => __LINE__});
								next if $this_logical_disk eq "";
								if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'} =~ /Degraded/i)
								{
									# NOTE: I only loop once because if 
									#       two drives are missing from a
									#       RAID 6 array, the 'Add to 
									#       this_logical_disk' will print
									#       twice, once for each row. So
									#       we exit the loop after the 
									#       first run and thus will 
									#       always add disks to the first
									#       open row.
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
											
											$say_disk_action .= $an->Web->template({file => "common.html", template => "new_line"}) if not $say_disk_action;
											$say_disk_action .= $an->Web->template({file => "common.html", template => "enabled-button", replace => { 
												button_class	=>	"bold_button",
												button_link	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&node_name=".$an->data->{cgi}{node_name}."&task=display_health&do=add_disk_to_array&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter&row=$this_row&logical_disk=$this_logical_disk",
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
									$say_disk_action .= $an->Web->template({file => "common.html", template => "new_line"}) if not $say_disk_action;
									$say_disk_action .= $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
											button_link	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&node_name=".$an->data->{cgi}{node_name}."&task=display_health&do=make_disk_hot_spare&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
											button_text	=>	"#!string!button_0011!#",
											id		=>	"make_disk_hot_spare_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
										}});
									$say_disk_action .= $an->Web->template({file => "common.html", template => "new_line"});
									$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
										name1 => "say_disk_action", value1 => $say_disk_action,
									}, file => $THIS_FILE, line => __LINE__});
								}
							}
						}
						elsif ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Unconfigured(good), Spun down")
						{
							$disk_state_class =  "highlight_detail";
							$say_disk_action  .= $an->Web->template({file => "common.html", template => "new_line"});
							$say_disk_action  .= $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
									button_link	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&node_name=".$an->data->{cgi}{node_name}."&task=display_health&do=spin_disk_up&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
									button_text	=>	"#!string!button_0012!#",
									id		=>	"spin_disk_up_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
								}});
							$say_temperature  = "<span class=\"highlight_unavailable\">".$an->String->get({key => "message_0055"})."</a>";
							$offline_button   = $an->String->get({key => "message_0054"});
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "say_disk_action", value1 => $say_disk_action,
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Hotspare, Transition")
						{
							$disk_state_class =  "highlight_detail";
							$say_disk_action  .= $an->Web->template({file => "common.html", template => "new_line"});
							$say_disk_action  .= $an->String->get({key => "message_0056"});
							$say_temperature  =  "<span class=\"highlight_unavailable\">".$an->String->get({key => "message_0057"})."</span>";
							$offline_button   =  $an->String->get({key => "message_0058"});
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "say_disk_action", value1 => $say_disk_action,
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} eq "Hotspare, Spun Up")
						{
							$disk_state_class =  "highlight_detail";
							$say_disk_action  .= "";
							$offline_button   =  $an->Web->template({file => "common.html", template => "enabled-button-no-class", replace => { 
									button_link	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&node_name=".$an->data->{cgi}{node_name}."&task=display_health&do=unmake_disk_as_hot_spare&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter&logical_disk=$this_logical_disk",
									button_text	=>	"#!string!button_0013!#",
									id		=>	"unmake_disk_as_hot_spare_${this_adapter}_${this_enclosure_device_id}_${this_slot_number}",
								}});
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "say_disk_action", value1 => $say_disk_action,
							}, file => $THIS_FILE, line => __LINE__});
						}
						### TODO: 'Copyback' state is when a drive has been inserted 
						###       into an array after a hot-spare took over a failed 
						###       disk. This state is where the hot-spare's data gets
						###       copied to the replaced drive, then the old hot 
						###       spare reverts again to being a hot spare.
						my $disk_icon    = $an->data->{url}{skins}."/".$an->data->{sys}{skin}."/images/hard-drive_128x128.png";
						my $id_led_url   = "?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&node_name=".$an->data->{cgi}{node_name}."&task=display_health&do=start_id_disk&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter";
						my $say_identify = $an->String->get({key => "button_0014"});
						if ($an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit})
						{
							$disk_icon    = $an->data->{url}{skins}."/".$an->data->{sys}{skin}."/images/hard-drive-with-led_128x128.png";
							$id_led_url   = "?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&node_name=".$an->data->{cgi}{node_name}."&task=display_health&do=stop_id_disk&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter";
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
									button_link	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&node_name=".$an->data->{cgi}{node_name}."&task=display_health&do=clear_foreign_state&disk_address=$this_enclosure_device_id:$this_slot_number&adapter=$this_adapter",
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

# This looks ip the missing disk(s) in a given degraded array
sub _get_missing_disks
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_get_missing_disks" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $this_adapter      = defined $parameter->{adapter}      ? $parameter->{adapter}      : "";
	my $this_logical_disk = defined $parameter->{logical_disk} ? $parameter->{logical_disk} : "";
	my $target            = defined $parameter->{target}       ? $parameter->{target}       : "";
	my $port              = defined $parameter->{port}         ? $parameter->{port}         : "";
	my $password          = defined $parameter->{password}     ? $parameter->{password}     : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "this_adapter",      value1 => $this_adapter,
		name2 => "this_logical_disk", value2 => $this_logical_disk,
		name3 => "target",            value3 => $target,
		name4 => "port",              value4 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $shell_call = $an->data->{path}{megacli64}." PdGetMissing a$this_adapter";
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
		elsif ($line =~ /No Missing Drive/i)
		{
			# 
		}
	}
	
	return(0);
}

# This gets the rebuild status of a drive
sub _get_rebuild_progress
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_get_rebuild_progress" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $adapter      = defined $parameter->{adapter}      ? $parameter->{adapter}      : "";
	my $disk_address = defined $parameter->{disk_address} ? $parameter->{disk_address} : "";
	my $target       = defined $parameter->{target}       ? $parameter->{target}       : "";
	my $port         = defined $parameter->{port}         ? $parameter->{port}         : "";
	my $password     = defined $parameter->{password}     ? $parameter->{password}     : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "adapter",      value1 => $adapter,
		name2 => "disk_address", value2 => $disk_address,
		name3 => "target",       value3 => $target,
		name4 => "port",         value4 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $rebuild_percent  = "";
	my $time_to_complete = "";
	my $shell_call       = $an->data->{storage}{is}{lsi}." PDRbld ShowProg PhysDrv [$disk_address] a$adapter";
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


# This uses the 'MegaCli64' program to gather information about the LSI-based storage of a node.
sub _get_storage_data
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_get_storage_data" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target   = defined $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = defined $parameter->{port}     ? $parameter->{port}     : "";
	my $password = defined $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target,
		name2 => "port",   value2 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
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
	
	# This is set to 1 once all the discovered physical drives have been found and their ID LED statuses
	# set to '0'.
	my $initial_led_state_set = 0;
	
	# Now call.
	my $in_section     =  0;
	my $megacli64_path =  $an->data->{path}{megacli64};
	my $shell_call     =  $an->data->{path}{echo}." '==] Start adapter_info'; $megacli64_path AdpAllInfo aAll; ";
	   $shell_call     .= $an->data->{path}{echo}." '==] Start bbu_info'; $megacli64_path AdpBbuCmd aAll; ";
	   $shell_call     .= $an->data->{path}{echo}." '==] Start logical_disk_info'; $megacli64_path LDInfo Lall aAll; ";
	   $shell_call     .= $an->data->{path}{echo}." '==] Start physical_disk_info'; $megacli64_path PDList aAll; ";
	   $shell_call     .= $an->data->{path}{echo}." '==] Start pd_id_led_state'; ".$an->data->{path}{'grep'}." \"PD Locate\" /root/MegaSAS.log;";
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
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		next if not $line;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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
			### TODO: Get the amount of cache allocated to write-back vs. read caching and make 
			###       it adjustable.
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
			### TODO: Confirm that 'Disk Group' in fact relates to the logical disk ID.
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
				name1 => "this_adapter",             value1 => $this_adapter,
				name2 => "this_logical_disk",        value2 => $this_logical_disk,
				name3 => "this_enclosure_device_id", value3 => $this_enclosure_device_id,
				name4 => "this_slot_number",         value4 => $this_slot_number,
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /Enclosure Device ID\s*:\s*(\d+)/)
			{
				$this_enclosure_device_id = $1;
				# New device, clear the old logical disk, span and arm.
				$this_logical_disk = "";
				$this_span         = "";
				$this_arm          = "";
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_adapter",             value1 => $this_adapter,
					name2 => "this_enclosure_device_id", value2 => $this_enclosure_device_id,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			if ($line =~ /Slot Number\s*:\s*(\d+)/)
			{
				$this_slot_number = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "this_adapter",     value1 => $this_adapter,
					name2 => "this_slot_number", value2 => $this_slot_number,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			if ($line =~ /Drive's position: DiskGroup: (\d+), Span: (\d+), Arm: (\d+)/)
			{
				$this_logical_disk = $1;
				$this_span         = $2;
				$this_arm          = $3;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
					name1 => "this_adapter",             value1 => $this_adapter,
					name2 => "this_logical_disk",        value2 => $this_logical_disk,
					name3 => "this_enclosure_device_id", value3 => $this_enclosure_device_id,
					name4 => "this_slot_number",         value4 => $this_slot_number,
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
					name1 => "this_adapter",             value1 => $this_adapter,
					name2 => "this_logical_disk",        value2 => $this_logical_disk,
					name3 => "this_enclosure_device_id", value3 => $this_enclosure_device_id,
					name4 => "this_slot_number",         value4 => $this_slot_number,
				}, file => $THIS_FILE, line => __LINE__});
				next;
			}
			next if (($this_enclosure_device_id eq "") or ($this_slot_number eq "") or ($this_logical_disk eq ""));
			
			if (not exists $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{span})
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{span} = $this_span;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",             value1 => $this_adapter,
					name2 => "this_logical_disk",        value2 => $this_logical_disk,
					name3 => "this_enclosure_device_id", value3 => $this_enclosure_device_id,
					name4 => "this_slot_number",         value4 => $this_slot_number,
					name5 => "this_span",                value5 => $this_span,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if (not exists $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{arm})
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{arm} = $this_arm;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
					name1 => "this_adapter",             value1 => $this_adapter,
					name2 => "this_logical_disk",        value2 => $this_logical_disk,
					name3 => "this_enclosure_device_id", value3 => $this_enclosure_device_id,
					name4 => "this_slot_number",         value4 => $this_slot_number,
					name5 => "this_arm",                 value5 => $this_arm,
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			# Record the slot number.
			if ($line =~ /Device Id\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_id} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::device_id", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_id},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /WWN\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{wwn} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::wwn", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{wwn},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Sequence Number\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sequence_number} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::sequence_number", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sequence_number},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Media Error Count\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{media_error_count} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::media_error_count", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{media_error_count},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Other Error Count\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{other_error_count} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::other_error_count", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{other_error_count},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Predictive Failure Count\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{predictive_failure_count} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::predictive_failure_count", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{predictive_failure_count},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /PD Type\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{pd_type} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::pd_type", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{pd_type},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Raw Size: .*? \[0x(.*?) Sectors\]/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{raw_sector_count_in_hex} = "0x".$1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::raw_sector_count_in_hex", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{raw_sector_count_in_hex},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Sector Size\s*:\s*(.*)/)
			{
				# NOTE: Some drives report 0. If this is the case, we'll use the logical disk
				#       sector size, if available. If not, we'll assume 512 bytes.
				my $sector_size = $1;
				if (not $sector_size)
				{
					$sector_size = $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{sector_size} ? $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{sector_size} : 512;
				}
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sector_size} = $sector_size ? $sector_size : 512;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::sector_size", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sector_size},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Firmware state\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::firmware_state", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{firmware_state},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /SAS Address\(0\)\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_0} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::sas_address_0", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_0},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /SAS Address\(1\)\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_1} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::sas_address_1", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{sas_address_1},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Connected Port Number\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{connected_port_number} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::connected_port_number", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{connected_port_number},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Inquiry Data\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{inquiry_data} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::inquiry_data", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{inquiry_data},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Device Speed\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_speed} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::device_speed", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{device_speed},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Link Speed\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{link_speed} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::link_speed", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{link_speed},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Media Type\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{media_type} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::media_type", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{media_type},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Foreign State\s*:\s*(.*)/)
			{
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{foreign_state} = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::foreign_state", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{foreign_state},
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
				$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::drive_temp_c", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_c},
					name2 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::drive_temp_f", value2 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{drive_temp_f},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Drive has flagged a S.M.A.R.T alert\s*:\s*(.*)/)
			{
				my $alert = $1;
				$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{smart_alert} = $alert eq "Yes" ? 1 : 0;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::smart_alert", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{smart_alert},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		elsif ($in_section eq "pd_id_led_state")
		{
			### TODO: Verify this catches/tracks unconfigured PDs.
			# Assume all physical drives have their ID LEDs off. Not great, but there is no way 
			# to check the state directly.
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
							name1 => "this_logical_disk", value1 => $this_logical_disk,
						}, file => $THIS_FILE, line => __LINE__});
						foreach my $this_enclosure_device_id (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}})
						{
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => "this_enclosure_device_id", value1 => $this_enclosure_device_id,
							}, file => $THIS_FILE, line => __LINE__});
							foreach my $this_slot_number (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}})
							{
								#print __LINE__.";      - Slot ID: [$this_slot_number]\n");
								$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit} = 0;
								$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
									name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::id_led_lit", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit},
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
					name1 => "this_adapter",             value1 => $this_adapter,
					name2 => "this_logical_disk",        value2 => $this_logical_disk,
					name3 => "this_enclosure_device_id", value3 => $this_enclosure_device_id,
					name4 => "this_slot_number",         value4 => $this_slot_number,
					name5 => "this_action",              value5 => $this_action,
					name6 => "set_state",                value6 => $set_state,
				}, file => $THIS_FILE, line => __LINE__});
				
				# the log doesn't reference the disk's logic drive, so we loop through all 
				# looking for a match.
				foreach my $this_adapter (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}})
				{
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "this_adapter", value1 => $this_adapter,
					}, file => $THIS_FILE, line => __LINE__});
					foreach my $this_logical_disk (sort {$a cmp $b} keys %{$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}})
					{
						$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
							name1 => "this_logical_disk",        value1 => $this_logical_disk,
							name2 => "this_logical_disk",        value2 => $this_logical_disk,
							name3 => "this_enclosure_device_id", value3 => $this_enclosure_device_id,
							name4 => "this_slot_number",         value4 => $this_slot_number,
						}, file => $THIS_FILE, line => __LINE__});
						if (exists $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number})
						{
							$an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit} = $set_state;
							# Exists
							$an->Log->entry({log_level => 2, message_key => "log_0219", file => $THIS_FILE, line => __LINE__});
							$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
								name1 => "this_adapter",             value1 => $this_adapter,
								name2 => "this_logical_disk",        value2 => $this_logical_disk,
								name3 => "this_enclosure_device_id", value3 => $this_enclosure_device_id,
								name4 => "this_slot_number",         value4 => $this_slot_number,
								name5 => "id_led_lit",               value5 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit},
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
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::enclosure_device_id::${this_enclosure_device_id}::slot_number::${this_slot_number}::id_led_lit", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{enclosure_device_id}{$this_enclosure_device_id}{slot_number}{$this_slot_number}{id_led_lit},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
			}
		}
	}
	
	return(0);
}

# This tells the controller to make the flagged disk "Good"
sub _make_disk_good
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_make_disk_good" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target   = defined $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = defined $parameter->{port}     ? $parameter->{port}     : "";
	my $password = defined $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target,
		name2 => "port",   value2 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $success       = 0;
	my $return_string = "";
	my $shell_call    = $an->data->{path}{megacli64}." PDMakeGood PhysDrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
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

# This marks a disk as a hot spare.
sub _make_disk_hot_spare
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_make_disk_hot_spare" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target   = defined $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = defined $parameter->{port}     ? $parameter->{port}     : "";
	my $password = defined $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target,
		name2 => "port",   value2 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Mark the disk as a global hot-spare.
	my $success       = 0;
	my $return_string = "";
	my $shell_call    = $an->data->{path}{megacli64}." PDHSP Set PhysDrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
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
sub _mark_disk_missing
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_mark_disk_missing" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target   = defined $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = defined $parameter->{port}     ? $parameter->{port}     : "";
	my $password = defined $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target,
		name2 => "port",   value2 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $success       = 0;
	my $return_string = "";
	my $shell_call    = $an->data->{path}{megacli64}." PDMarkMissing PhysDrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
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
		$message_body  = $an->String->get({key => "lsi_0008", variables => { 
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
		$an->HardwareLSI->_spin_disk_down({
			target   => $target, 
			port     => $port, 
			password => $password, 
		});
	}

	return(0);
}

# This puts an "Online, Spun Up" disk into "Offline" state.
sub _put_disk_offline
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_put_disk_offline" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target   = defined $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = defined $parameter->{port}     ? $parameter->{port}     : "";
	my $password = defined $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target,
		name2 => "port",   value2 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	### NOTE: I don't think I need this function. For now, I simply redirect to the "prepare for removal"
	###       function.   .... or not
	#$an->HardwareLSI->_mark_disk_missing();
	
	my $success           = 0;
	my $return_string     = "";
	my $this_adapter      = $an->data->{cgi}{adapter};
	my $this_logical_disk = $an->data->{cgi}{logical_disk};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "storage::lsi::adapter::${this_adapter}::logical_disk::${this_logical_disk}::state", value1 => $an->data->{storage}{lsi}{adapter}{$this_adapter}{logical_disk}{$this_logical_disk}{'state'},
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
				confirm_url	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&node_name=".$an->data->{cgi}{node_name}."&task=display_health&do=put_disk_offline&disk_address=".$an->data->{cgi}{disk_address}."&adapter=$this_adapter&logical_disk=$this_logical_disk&confirm=true",
				cancel_url	=>	"?anvil_uuid=".$an->data->{cgi}{anvil_uuid}."&node_name=".$an->data->{cgi}{node_name}."&task=display_health",
			}});
		print $an->Web->template({file => "lsi-storage.html", template => "lsi-complete-table-message", replace => { 
			title		=>	"#!string!title_0018!#",
			row		=>	$alert,
			row_class	=>	$alert_class,
			message		=>	$message,
		}});
		return (0);
	}
	
	my $shell_call = $an->data->{path}{megacli64}." PDOffline PhysDrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
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
		$an->HardwareLSI->_mark_disk_missing({
			target   => $target, 
			port     => $port, 
			password => $password, 
		});
	}

	return(0);
}

# This puts an "Offline" disk into "Online" state.
sub _put_disk_online
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_put_disk_online" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target   = defined $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = defined $parameter->{port}     ? $parameter->{port}     : "";
	my $password = defined $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target,
		name2 => "port",   value2 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $success       = 0;
	my $return_string = "";
	my $shell_call    = $an->data->{path}{megacli64}." PDRbld Start PhysDrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
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
	print $an->Web->template({file => "lsi-storage.html", template => "lsi-complete-table-message", replace => { 
		title		=>	"#!string!lsi_0030!#",
		row		=>	$title_message,
		row_class	=>	$title_class,
	}});

	return(0);
}

# This spins down an "Offline" disk, Preparing it for removal.
sub _spin_disk_down
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_spin_disk_down" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target   = defined $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = defined $parameter->{port}     ? $parameter->{port}     : "";
	my $password = defined $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target,
		name2 => "port",   value2 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $success       = 0;
	my $return_string = "";
	my $shell_call    = $an->data->{path}{megacli64}." PDPrpRmv PhysDrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
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
		my $success = $an->HardwareLSI->_make_disk_good({
				target   => $target, 
				port     => $port, 
				password => $password, 
			});
		if ($success)
		{
			$an->HardwareLSI->_spin_disk_down({
				target   => $target, 
				port     => $port, 
				password => $password, 
			});
		}
	}
	
	return(0);
}

# This spins up an "Unconfigured, spun down" disk, making it available again.
sub _spin_disk_up
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_spin_disk_up" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target   = defined $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = defined $parameter->{port}     ? $parameter->{port}     : "";
	my $password = defined $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target,
		name2 => "port",   value2 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	# This spins the drive back up.
	my $success       = 0;
	my $return_string = "";
	my $shell_call    = $an->data->{path}{megacli64}." PDPrpRmv Undo PhysDrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
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

# This unmarks a disk as a hot spare.
sub _unmake_disk_as_hot_spare
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_unmake_disk_as_hot_spare" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $target   = defined $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = defined $parameter->{port}     ? $parameter->{port}     : "";
	my $password = defined $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target,
		name2 => "port",   value2 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Mark the disk as a global hot-spare.
	my $success       = 0;
	my $return_string = "";
	my $shell_call    = $an->data->{path}{megacli64}." PDHSP Rmv PhysDrv [".$an->data->{cgi}{disk_address}."] -a".$an->data->{cgi}{adapter};
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

1;
