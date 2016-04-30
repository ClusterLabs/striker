package AN::Tools::InstallManifest;
# 
# This package is used for things specific to RHEL 6's cman + rgmanager cluster stack.
# 

use strict;
use warnings;
use IO::Handle;

our $VERSION  = "0.1.001";
my $THIS_FILE = "InstallManifest.pm";

### NOTE: There are all deprecated
### Methods;
# calculate_storage_pool_sizes
# check_connection
# check_if_in_cluster
# check_local_repo
# check_storage
# get_node_os_version
# get_partition_data
# get_storage_pool_partitions
# map_network
# parse_script_line
# read_drbd_resource_files
# run_new_install_manifest
# summarize_build_plan
# test_internet_connection
# update_install_manifest
# verify_internet_access
# verify_os
# verify_perl_is_installed
# verify_perl_is_installed_on_node

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
# This calculates the sizes of the partitions to create, or selects the size based on existing partitions if 
# found.
sub calculate_storage_pool_sizes
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "calculate_storage_pool_sizes" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# These will be set to the lower of the two nodes.
	my $node1      = $an->data->{cgi}{anvil_node1_current_ip};
	my $node2      = $an->data->{cgi}{anvil_node2_current_ip};
	my $pool1_size = "";
	my $pool2_size = "";
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node1}::pool1::existing_size", value1 => $an->data->{node}{$node1}{pool1}{existing_size},
		name2 => "node::${node2}::pool1::existing_size", value2 => $an->data->{node}{$node2}{pool1}{existing_size},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node1}{pool1}{existing_size}) || ($an->data->{node}{$node2}{pool1}{existing_size}))
	{
		# See which I have.
		if (($an->data->{node}{$node1}{pool1}{existing_size}) && ($an->data->{node}{$node2}{pool1}{existing_size}))
		{
			# Both, OK. Are they the same?
			if ($an->data->{node}{$node1}{pool1}{existing_size} eq $an->data->{node}{$node2}{pool1}{existing_size})
			{
				# Golden
				$pool1_size = $an->data->{node}{$node1}{pool1}{existing_size};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "pool1_size", value1 => $pool1_size,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Nothing we can do but warn the user.
				$pool1_size = $an->data->{node}{$node1}{pool1}{existing_size};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "pool1_size", value1 => $pool1_size,
				}, file => $THIS_FILE, line => __LINE__});
				if ($an->data->{node}{$node1}{pool1}{existing_size} < $an->data->{node}{$node2}{pool1}{existing_size})
				{
					$pool1_size = $an->data->{node}{$node2}{pool1}{existing_size};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "pool1_size", value1 => $pool1_size,
					}, file => $THIS_FILE, line => __LINE__});
				}
				my $say_node1_size = $an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node1}{pool1}{existing_size} })." (".$an->data->{node}{$node1}{pool1}{existing_size}." #!string!suffix_0009!#)";
				my $say_node2_size = $an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node2}{pool1}{existing_size} })." (".$an->data->{node}{$node2}{pool1}{existing_size}." #!string!suffix_0009!#)";
				my $message = $an->String->get({key => "message_0394", variables => { 
						node1		=>	$node1,
						node1_device	=>	$an->data->{node}{$node1}{pool1}{partition},
						node1_size	=>	$say_node1_size,
						node2		=>	$node2,
						node2_device	=>	$an->data->{node}{$node1}{pool1}{partition},
						node1_size	=>	$say_node2_size,
					}});
				print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
					message	=>	$message,
					row	=>	"#!string!state_0052!#",
				}});
			}
		}
		elsif ($an->data->{node}{$node1}{pool1}{existing_size})
		{
			# Node 2 isn't partitioned yet but node 1 is.
			$pool1_size                                     = $an->data->{node}{$node1}{pool1}{existing_size};
			$an->data->{cgi}{anvil_storage_pool1_byte_size} = $an->data->{node}{$node1}{pool1}{existing_size};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "pool1_size", value1 => $pool1_size,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($an->data->{node}{$node2}{pool1}{existing_size})
		{
			# Node 1 isn't partitioned yet but node 2 is.
			$pool1_size                                    = $an->data->{node}{$node2}{pool1}{existing_size};
			$an->data->{cgi}{anvil_storage_pool1_byte_size} = $an->data->{node}{$node2}{pool1}{existing_size};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "pool1_size", value1 => $pool1_size,
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		$an->data->{cgi}{anvil_storage_pool1_byte_size} = $pool1_size;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_storage_pool1_byte_size", value1 => $an->data->{cgi}{anvil_storage_pool1_byte_size},
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		$pool1_size = "calculate";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "pool1_size", value1 => $pool1_size,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node1}::pool2::existing_size", value1 => $an->data->{node}{$node1}{pool2}{existing_size},
		name2 => "node::${node2}::pool2::existing_size", value2 => $an->data->{node}{$node2}{pool2}{existing_size},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node1}{pool2}{existing_size}) || ($an->data->{node}{$node2}{pool2}{existing_size}))
	{
		# See which I have.
		if (($an->data->{node}{$node1}{pool2}{existing_size}) && ($an->data->{node}{$node2}{pool2}{existing_size}))
		{
			# Both, OK. Are they the same?
			if ($an->data->{node}{$node1}{pool2}{existing_size} eq $an->data->{node}{$node2}{pool2}{existing_size})
			{
				# Golden
				$pool2_size = $an->data->{node}{$node1}{pool2}{existing_size};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "pool2_size", value1 => $pool2_size,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Nothing we can do but warn the user.
				$pool2_size = $an->data->{node}{$node1}{pool2}{existing_size};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "pool2_size", value1 => $pool2_size,
				}, file => $THIS_FILE, line => __LINE__});
				if ($an->data->{node}{$node1}{pool2}{existing_size} < $an->data->{node}{$node2}{pool2}{existing_size})
				{
					$pool2_size = $an->data->{node}{$node2}{pool2}{existing_size};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "pool2_size", value1 => $pool2_size,
					}, file => $THIS_FILE, line => __LINE__});
				}
				my $say_node1_size = $an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node1}{pool2}{existing_size} })." (".$an->data->{node}{$node1}{pool2}{existing_size}." #!string!suffix_0009!#)";
				my $say_node2_size = $an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node2}{pool2}{existing_size} })." (".$an->data->{node}{$node2}{pool2}{existing_size}." #!string!suffix_0009!#)";
				my $message = $an->String->get({key => "message_0394", variables => { 
						node1		=>	$node1,
						node1_device	=>	$an->data->{node}{$node1}{pool2}{partition},
						node1_size	=>	$say_node1_size,
						node2		=>	$node2,
						node2_device	=>	$an->data->{node}{$node1}{pool2}{partition},
						node1_size	=>	$say_node2_size,
					}});
				print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
					message	=>	$message,
					row	=>	"#!string!state_0052!#",
				}});
			}
		}
		elsif ($an->data->{node}{$node1}{pool2}{existing_size})
		{
			# Node 2 isn't partitioned yet but node 1 is.
			$pool2_size                                     = $an->data->{node}{$node1}{pool2}{existing_size};
			$an->data->{cgi}{anvil_storage_pool2_byte_size} = $an->data->{node}{$node1}{pool2}{existing_size};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "pool2_size", value1 => $pool2_size,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($an->data->{node}{$node2}{pool2}{existing_size})
		{
			# Node 1 isn't partitioned yet but node 2 is.
			$pool2_size                                     = $an->data->{node}{$node2}{pool2}{existing_size};
			$an->data->{cgi}{anvil_storage_pool2_byte_size} = $an->data->{node}{$node2}{pool2}{existing_size};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "pool2_size", value1 => $pool2_size,
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		$an->data->{cgi}{anvil_storage_pool2_byte_size} = $pool2_size;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_storage_pool2_byte_size", value1 => $an->data->{cgi}{anvil_storage_pool2_byte_size},
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		$pool2_size = "calculate";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "pool2_size", value1 => $pool2_size,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# These are my minimums. I'll use these below for final sanity checks.
	my $media_library_size      = $an->data->{cgi}{anvil_media_library_size};
	my $media_library_unit      = $an->data->{cgi}{anvil_media_library_unit};
	my $media_library_byte_size = $an->Readable->hr_to_bytes({size => $media_library_size, type => $media_library_unit });
	my $minimum_space_needed    = $media_library_byte_size;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "media_library_byte_size", value1 => $media_library_byte_size,
		name2 => "minimum_space_needed",    value2 => $minimum_space_needed,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $minimum_pool_size  = $an->Readable->hr_to_bytes({size => 8, type => "GiB" });
	my $pool1_minimum_size = $minimum_space_needed + $minimum_pool_size;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "minimum_pool_size",  value1 => $minimum_pool_size,
		name2 => "pool1_minimum_size", value2 => $pool1_minimum_size,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Knowing the smallest This will be useful in a few places.
	my $node1_disk = $an->data->{node}{$node1}{pool1}{disk};
	my $node2_disk = $an->data->{node}{$node2}{pool1}{disk};
	
	my $smallest_free_size = $an->data->{node}{$node1}{disk}{$node1_disk}{free_space}{size};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "smallest_free_size", value1 => $smallest_free_size,
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{node}{$node1}{disk}{$node1_disk}{free_space}{size} > $an->data->{node}{$node2}{disk}{$node2_disk}{free_space}{size})
	{
		$smallest_free_size = $an->data->{node}{$node2}{disk}{$node2_disk}{free_space}{size};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "smallest_free_size", value1 => $smallest_free_size,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# If both are "calculate", do so. If only one is "calculate", use the available free size.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "pool1_size", value1 => $pool1_size,
		name2 => "pool2_size", value2 => $pool2_size,
	}, file => $THIS_FILE, line => __LINE__});
	if (($pool1_size eq "calculate") || ($pool2_size eq "calculate"))
	{
		# At least one of them is calculate.
		if (($pool1_size eq "calculate") && ($pool2_size eq "calculate"))
		{
			my $pool1_byte_size  = 0;
			my $pool2_byte_size  = 0;
			my $total_free_space = $smallest_free_size;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "total_free_space", value1 => $total_free_space,
			}, file => $THIS_FILE, line => __LINE__});
			
			# Now to start calculating the requested sizes.
			my $storage_pool1_size = $an->data->{cgi}{anvil_storage_pool1_size};
			my $storage_pool1_unit = $an->data->{cgi}{anvil_storage_pool1_unit};
			
			### Ok, both are. Then we do our normal math.
			# If pool1 is '100%', then this is easy.
			if (($storage_pool1_size eq "100") && ($storage_pool1_unit eq "%"))
			{
				# All to pool 1.
				$pool1_size                                     = $smallest_free_size;
				$pool2_size                                     = 0;
				$an->data->{cgi}{anvil_storage_pool1_byte_size} = $pool1_size;
				$an->data->{cgi}{anvil_storage_pool2_byte_size} = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "pool1_size", value1 => $pool1_size,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# OK, so we actually need two pools.
				my $storage_pool1_byte_size = 0;
				my $storage_pool2_byte_size = 0;
				if ($storage_pool1_unit eq "%")
				{
					# Percentage, make sure there is at least 16 GiB free (8 GiB for each
					# pool)
					$minimum_space_needed += ($minimum_pool_size * 2);
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "minimum_space_needed", value1 => $minimum_space_needed,
					}, file => $THIS_FILE, line => __LINE__});
					
					# If the new minimum is too big, dump pool 2.
					if ($minimum_space_needed > $smallest_free_size)
					{
						$pool1_size = $smallest_free_size;
						$pool2_size = 0;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "pool1_size", value1 => $pool1_size,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				else
				{
					$storage_pool1_byte_size =  $an->Readable->hr_to_bytes({size => $storage_pool1_size, type => $storage_pool1_unit });
					$minimum_space_needed    += $storage_pool1_byte_size;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "storage_pool1_byte_size", value1 => $storage_pool1_byte_size,
						name2 => "minimum_space_needed",    value2 => $minimum_space_needed,
					}, file => $THIS_FILE, line => __LINE__});
				}

				# Things are good, so calculate the static sizes of our pool for display in 
				# the summary/confirmation later. Make sure the storage pool is an even MiB.
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "media_library_byte_size", value1 => $media_library_byte_size,
				}, file => $THIS_FILE, line => __LINE__});
				my $media_library_difference = $media_library_byte_size % 1048576;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "media_library_difference", value1 => $media_library_difference,
				}, file => $THIS_FILE, line => __LINE__});
				if ($media_library_difference)
				{
					# Round up
					my $media_library_balance   =  1048576 - $media_library_difference;
					   $media_library_byte_size += $media_library_balance;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "media_library_byte_size", value1 => $media_library_byte_size,
						name2 => "media_library_balance",   value2 => $media_library_balance,
					}, file => $THIS_FILE, line => __LINE__});
				}
				$an->data->{cgi}{anvil_media_library_byte_size} = $media_library_byte_size;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "cgi::anvil_media_library_byte_size", value1 => $an->data->{cgi}{anvil_media_library_byte_size},
				}, file => $THIS_FILE, line => __LINE__});
				
				my $free_space_left = $total_free_space - $media_library_byte_size;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "free_space_left", value1 => $free_space_left,
				}, file => $THIS_FILE, line => __LINE__});
				
				# If the user has asked for a percentage, divide the free space by the 
				# percentage.
				if ($storage_pool1_unit eq "%")
				{
					my $percent = $storage_pool1_size / 100;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "percent",            value1 => $percent, 
						name2 => "storage_pool1_size", value2 => $storage_pool1_size, 
						name3 => "storage_pool1_unit", value3 => $storage_pool1_unit, 
					}, file => $THIS_FILE, line => __LINE__});
					
					# Round up to the closest even MiB
					$pool1_byte_size = $percent * $free_space_left;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "pool1_byte_size", value1 => $pool1_byte_size,
					}, file => $THIS_FILE, line => __LINE__});
					my $pool1_difference = $pool1_byte_size % 1048576;
					if ($pool1_difference)
					{
						# Round up
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "pool1_difference", value1 => $pool1_difference,
						}, file => $THIS_FILE, line => __LINE__});
						my $pool1_balance   =  1048576 - $pool1_difference;
						   $pool1_byte_size += $pool1_balance;
					}
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "pool1_byte_size", value1 => $pool1_byte_size,
					}, file => $THIS_FILE, line => __LINE__});
					
					# Round down to the closest even MiB (left over space will be 
					# unallocated on disk)
					my $pool2_byte_size = $free_space_left - $pool1_byte_size;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "pool2_byte_size", value1 => $pool2_byte_size,
					}, file => $THIS_FILE, line => __LINE__});
					if ($pool2_byte_size < 0)
					{
						# Well then...
						$pool2_byte_size = 0;
					}
					else
					{
						my $pool2_difference = $pool2_byte_size % 1048576;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "pool2_difference", value1 => $pool1_difference,
						}, file => $THIS_FILE, line => __LINE__});
						if ($pool2_difference)
						{
							# Round down
							$pool2_byte_size -= $pool2_difference;
						}
					}
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "pool2_byte_size", value1 => $pool2_byte_size,
					}, file => $THIS_FILE, line => __LINE__});
					
					# Final sanity check; Add up the three calculated sizes and make sure
					# I'm not trying to ask for more space than is available.
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "media_library_byte_size", value1 => $media_library_byte_size,
						name2 => "pool1_byte_size",         value2 => $pool1_byte_size,
						name3 => "pool2_byte_size",         value3 => $pool2_byte_size,
					}, file => $THIS_FILE, line => __LINE__});
					my $total_allocated = ($media_library_byte_size + $pool1_byte_size + $pool2_byte_size);
					
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "total_allocated",  value1 => $total_allocated,
						name2 => "total_free_space", value2 => $total_free_space,
					}, file => $THIS_FILE, line => __LINE__});
					if ($total_allocated > $total_free_space)
					{
						my $too_much = $total_allocated - $total_free_space;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "too_much", value1 => $too_much,
						}, file => $THIS_FILE, line => __LINE__});
						
						# Take the overage from pool 2, if used.
						if ($pool2_byte_size > $too_much)
						{
							# Reduce!
							$pool2_byte_size -= $too_much;
							$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
								name1 => "pool2_byte_size", value1 => $pool2_byte_size,
							}, file => $THIS_FILE, line => __LINE__});
							my $pool2_difference =  $pool2_byte_size % 1048576;
							if ($pool2_difference)
							{
								# Round down
								$pool2_byte_size -= $pool2_difference;
								if ($pool2_byte_size < 0)
								{
									$pool2_byte_size = 0;
								}
							}
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "pool2_byte_size", value1 => $pool2_byte_size,
							}, file => $THIS_FILE, line => __LINE__});
						}
						else
						{
							# Take the pound of flesh from pool 1
							$pool1_byte_size -= $too_much;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "pool1_byte_size", value1 => $pool1_byte_size,
							}, file => $THIS_FILE, line => __LINE__});
							my $pool1_difference =  $pool1_byte_size % 1048576;
							if ($pool1_difference)
							{
								# Round down
								$pool1_byte_size -= $pool1_difference;
								if ($pool1_byte_size < 0)
								{
									$pool1_byte_size = 0;
								}
							}
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "pool1_byte_size", value1 => $pool1_byte_size,
							}, file => $THIS_FILE, line => __LINE__});
						}
						
						# Check again.
						$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
							name1 => "media_library_byte_size", value1 => $media_library_byte_size,
							name2 => "pool1_byte_size",         value2 => $pool1_byte_size,
							name3 => "pool2_byte_size",         value3 => $pool2_byte_size,
						}, file => $THIS_FILE, line => __LINE__});
						$total_allocated = ($media_library_byte_size + $pool1_byte_size + $pool2_byte_size);
						$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
							name1 => "total_allocated",  value1 => $total_allocated,
							name2 => "total_free_space", value2 => $total_free_space,
						}, file => $THIS_FILE, line => __LINE__});
						if ($total_allocated > $total_free_space)
						{
							# OK, WTF? Failed to divide free space.
							$an->Log->entry({log_level => 1, message_key => "log_0202", file => $THIS_FILE, line => __LINE__});
						}
					}
					
					# Old
					$an->data->{cgi}{anvil_storage_pool1_byte_size} = $pool1_byte_size + $media_library_byte_size;
					$an->data->{cgi}{anvil_storage_pool2_byte_size} = $pool2_byte_size;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "cgi::anvil_storage_pool1_byte_size", value1 => $an->data->{cgi}{anvil_storage_pool1_byte_size},
						name2 => "cgi::anvil_storage_pool2_byte_size", value2 => $an->data->{cgi}{anvil_storage_pool2_byte_size},
					}, file => $THIS_FILE, line => __LINE__});
					
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "pool1_byte_size", value1 => $pool1_byte_size,
						name2 => "pool2_byte_size", value2 => $pool2_byte_size,
					}, file => $THIS_FILE, line => __LINE__});
					$pool1_size = $pool1_byte_size + $media_library_byte_size;
					$pool2_size = $pool2_byte_size;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "pool1_size", value1 => $pool1_size,
						name2 => "pool2_size", value2 => $pool2_size,
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Pool 1 is static, so simply round to an even MiB.
					$pool1_byte_size = $storage_pool1_byte_size;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "pool1_byte_size", value1 => $pool1_byte_size,
					}, file => $THIS_FILE, line => __LINE__});
					
					# If pool1's requested size is larger than is available, shrink it.
					if ($pool1_byte_size > $free_space_left)
					{
						# Round down a meg, as the next stage will round up a bit if 
						# needed.
						$pool1_byte_size = ($free_space_left - 1048576);
						$an->Log->entry({log_level => 2, message_key => "log_0262", message_variables => {
							pool         => "1", 
							pool_size    => $pool1_byte_size, 
							hr_pool_size => $an->Readable->bytes_to_hr({'bytes' => $pool1_byte_size }), 
						}, file => $THIS_FILE, line => __LINE__});
						$an->data->{sys}{pool1_shrunk} = 1;
					}
						
					my $pool1_difference = $pool1_byte_size % 1048576;
					if ($pool1_difference)
					{
						# Round up
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "pool1_difference", value1 => $pool1_difference,
						}, file => $THIS_FILE, line => __LINE__});
						my $pool1_balance   =  1048576 - $pool1_difference;
						   $pool1_byte_size += $pool1_balance;
					}
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "pool1_byte_size", value1 => $pool1_byte_size,,
					}, file => $THIS_FILE, line => __LINE__});
					
					$pool2_byte_size = $free_space_left - $pool1_byte_size;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "pool2_byte_size", value1 => $pool2_byte_size,
					}, file => $THIS_FILE, line => __LINE__});
					if ($pool2_byte_size < 0)
					{
						# Well then...
						$pool2_byte_size = 0;
					}
					else
					{
						my $pool2_difference = $pool2_byte_size % 1048576;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "pool2_difference", value1 => $pool1_difference,
						}, file => $THIS_FILE, line => __LINE__});
						if ($pool2_difference)
						{
							# Round down
							$pool2_byte_size -= $pool2_difference;
						}
					}
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "pool2_byte_size", value1 => $pool2_byte_size,
					}, file => $THIS_FILE, line => __LINE__});
					
					$an->data->{cgi}{anvil_storage_pool1_byte_size} = $pool1_byte_size + $media_library_byte_size;
					$an->data->{cgi}{anvil_storage_pool2_byte_size} = $pool2_byte_size;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "cgi::anvil_storage_pool1_byte_size", value1 => $an->data->{cgi}{anvil_storage_pool1_byte_size},
						name2 => "cgi::anvil_storage_pool2_byte_size", value2 => $an->data->{cgi}{anvil_storage_pool2_byte_size},
					}, file => $THIS_FILE, line => __LINE__});
					
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "pool1_byte_size", value1 => $pool1_byte_size,
						name2 => "pool2_byte_size", value2 => $pool2_byte_size,
					}, file => $THIS_FILE, line => __LINE__});
					$pool1_size = $pool1_byte_size + $media_library_byte_size;
					$pool2_size = $pool2_byte_size;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "pool1_size", value1 => $pool1_size,
						name2 => "pool2_size", value2 => $pool2_size,
					}, file => $THIS_FILE, line => __LINE__});
				}
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "cgi::anvil_media_library_byte_size", value1 => $an->data->{cgi}{anvil_media_library_byte_size},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		elsif ($pool1_size eq "calculate")
		{
			# OK, Pool 1 is calculate, just use all the free space (or the lower of the two if 
			# they don't match.
			$pool1_size = $smallest_free_size;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "pool1_size", value1 => $pool1_size,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($pool2_size eq "calculate")
		{
			# OK, Pool 1 is calculate, just use all the free space (or the lower of the two if 
			# they don't match.
			$pool2_size = $smallest_free_size;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "pool2_size", value1 => $pool2_size,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# We no longer use pool 2.
	$an->data->{cgi}{anvil_storage_pool2_byte_size} = 0;
	return(0);
}

# This makes sure we have access to both nodes.
sub check_connection
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_connection" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my ($node1_access) = $an->Check->access({target => $an->data->{cgi}{anvil_node1_current_ip}, password => $an->data->{cgi}{anvil_node1_current_password}});
	my ($node2_access) = $an->Check->access({target => $an->data->{cgi}{anvil_node2_current_ip}, password => $an->data->{cgi}{anvil_node2_current_password}});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_access", value1 => $node1_access,
		name2 => "node2_access", value2 => $node2_access,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $node1_class   = "highlight_good_bold";
	my $node1_message = $an->String->get({key => "state_0017"});
	my $node2_class   = "highlight_good_bold";
	my $node2_message = $an->String->get({key => "state_0017"});
	if (not $node1_access)
	{
		$node1_class   = "highlight_bad_bold";
		$node1_message = $an->String->get({key => "state_0018"});
	}
	if (not $node2_access)
	{
		$node2_class   = "highlight_bad_bold";
		$node2_message = $an->String->get({key => "state_0018"});
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0219!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	my $access = 1;
	if ((not $node1_access) || (not $node2_access))
	{
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-failed", replace => { message => "#!string!message_0361!#" }});
		$access = 0;
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "access", value1 => $access,
	}, file => $THIS_FILE, line => __LINE__});
	return($access);
}

# See if the node is in a cluster already. If so, we'll set a flag to block reboots if needed.
sub check_if_in_cluster
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_if_in_cluster" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $shell_call = "
if [ -e '".$an->data->{path}{initd}."/cman' ];
then 
    ".$an->data->{path}{initd}."/cman status; ".$an->data->{path}{echo}." rc:\$?; 
else 
    ".$an->data->{path}{echo}." 'not in a cluster'; 
fi";
	# rc == 0; in a cluster
	# rc == 3; NOT in a cluster
	# Node 1
	if (1)
	{
		my $node                                = $an->data->{cgi}{anvil_node1_current_ip};
		   $an->data->{node}{$node}{in_cluster} = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "cgi::anvil_node1_current_ip", value1 => $an->data->{cgi}{anvil_node1_current_ip},
			name2 => "shell_call",                  value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$an->data->{cgi}{anvil_node1_current_ip},
			port		=>	$an->data->{node}{$node}{port}, 
			password	=>	$an->data->{cgi}{anvil_node1_current_password},
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /rc:(\d+)/)
			{
				my $rc = $1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node", value1 => $an->data->{cgi}{anvil_node1_current_ip},
					name2 => "rc",   value2 => $rc,
				}, file => $THIS_FILE, line => __LINE__});
				if ($rc eq "0")
				{
					# It's in a cluster.
					$an->data->{node}{$node}{in_cluster} = 1;
				}
			}
			else
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node", value1 => $an->data->{cgi}{anvil_node1_current_ip},
					name2 => "line", value2 => $line,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	# Node 2
	if (1)
	{
		my $node                                = $an->data->{cgi}{anvil_node2_current_ip};
		   $an->data->{node}{$node}{in_cluster} = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "cgi::anvil_node2_current_ip", value1 => $an->data->{cgi}{anvil_node2_current_ip},
			name2 => "shell_call",                  value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$an->data->{cgi}{anvil_node2_current_ip},
			port		=>	$an->data->{node}{$node}{port}, 
			password	=>	$an->data->{cgi}{anvil_node2_current_password},
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /rc:(\d+)/)
			{
				my $rc = $1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node", value1 => $an->data->{cgi}{anvil_node2_current_ip},
					name2 => "rc",   value2 => $rc,
				}, file => $THIS_FILE, line => __LINE__});
				if ($rc eq "0")
				{
					# It's in a cluster.
					$an->data->{node}{$node}{in_cluster} = 1;
				}
			}
			else
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node", value1 => $an->data->{cgi}{anvil_node2_current_ip},
					name2 => "line", value2 => $line,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return(0);
}

# This checks to see if we're configured to be a repo for RHEL and/or CentOS. If so, it gets the local IPs to
# be used later when setting up the repos on the nodes.
sub check_local_repo
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_local_repo" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Call the gather system info tool to get the BCN and IFN IPs.
	my $shell_call = $an->data->{path}{'call_gather-system-info'};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /hostname,(.*)$/)
		{
			$an->data->{sys}{'local'}{hostname} = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "sys::local::hostname", value1 => $an->data->{sys}{'local'}{hostname},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /interface,(.*?),(.*?),(.*?)$/)
		{
			my $interface = $1;
			my $variable  = $2;
			my $value     = $3;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "interface", value1 => $interface,
				name2 => "variable",  value2 => $variable,
				name3 => "value",     value3 => $value,
			}, file => $THIS_FILE, line => __LINE__});
			next if not $value;
			
			# For now, I'm only looking for IPs and subnets.
			if (($variable eq "ip") && ($interface =~ /ifn/))
			{
				next if $value eq "?";
				$an->data->{sys}{'local'}{ifn}{ip} = $value;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "sys::local::ifn::ip", value1 => $an->data->{sys}{'local'}{ifn}{ip},
				}, file => $THIS_FILE, line => __LINE__});
			}
			if (($variable eq "ip") && ($interface =~ /bcn/))
			{
				next if $value eq "?";
				$an->data->{sys}{'local'}{bcn}{ip} = $value;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "sys::local::bcn::ip", value1 => $an->data->{sys}{'local'}{bcn}{ip},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	close $file_handle;
	
	# Now see if we have RHEL, CentOS and/or generic repos setup.
	$an->data->{sys}{'local'}{repo}{centos}  = 0;
	$an->data->{sys}{'local'}{repo}{generic} = 0;
	$an->data->{sys}{'local'}{repo}{rhel}    = 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "path::repo_centos", value1 => $an->data->{path}{repo_centos},
	}, file => $THIS_FILE, line => __LINE__});
	if (-e $an->data->{path}{repo_centos})
	{
		$an->data->{sys}{'local'}{repo}{centos} = 1;
		$an->Log->entry({log_level => 3, message_key => "log_0040", message_variables => {
			type => "CentOS", 
		}, file => $THIS_FILE, line => __LINE__});
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "path::repo_generic", value1 => $an->data->{path}{repo_generic},
	}, file => $THIS_FILE, line => __LINE__});
	if (-e $an->data->{path}{repo_generic})
	{
		$an->data->{sys}{'local'}{repo}{generic} = 1;
		$an->Log->entry({log_level => 3, message_key => "log_0040", message_variables => {
			type => "generic", 
		}, file => $THIS_FILE, line => __LINE__});
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "path::repo_rhel", value1 => $an->data->{path}{repo_rhel},
	}, file => $THIS_FILE, line => __LINE__});
	if (-e $an->data->{path}{repo_rhel})
	{
		$an->data->{sys}{'local'}{repo}{rhel} = 1;
		$an->Log->entry({log_level => 3, message_key => "log_0040", message_variables => {
			type => "RHEL", 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return(0);
}

# This checks to see if both nodes have the same amount of unallocated space.
sub check_storage
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_storage" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ok    = 1;
	my $node1 = $an->data->{cgi}{anvil_node1_current_ip};
	my $node2 = $an->data->{cgi}{anvil_node2_current_ip};
	my ($node1_disk) = $an->InstallManifest->get_partition_data({
			target   => $an->data->{cgi}{anvil_node1_current_ip}, 
			port     => $an->data->{node}{$node1}{port}, 
			password => $an->data->{cgi}{anvil_node1_current_password},
		});
	my ($node2_disk) = $an->InstallManifest->get_partition_data({
			target   => $an->data->{cgi}{anvil_node2_current_ip}, 
			port     => $an->data->{node}{$node2}{port}, 
			password => $an->data->{cgi}{anvil_node2_current_password},
		});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_disk", value1 => $node1_disk,
		name2 => "node2_disk", value2 => $node2_disk,
	}, file => $THIS_FILE, line => __LINE__});
	
	# How much space do I have?
	my $node1_disk_size = $an->data->{node}{$node1}{disk}{$node1_disk}{size};
	my $node2_disk_size = $an->data->{node}{$node2}{disk}{$node2_disk}{size};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node1",           value1 => $node1,
		name2 => "node2",           value2 => $node2,
		name3 => "node1_disk_size", value3 => $node1_disk_size,
		name4 => "node2_disk_size", value4 => $node2_disk_size,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Now I need to know which partitions I will use for pool 1 and 2. Only then can I sanity check space
	# needed. If one node has the partitions already in place, then that will determine the other node's
	# partition size regardless of anything else. This will set:
	$an->InstallManifest->get_storage_pool_partitions();
	
	# Now we can calculate partition sizes.
	$an->InstallManifest->calculate_storage_pool_sizes();
	
	if ($an->data->{sys}{pool1_shrunk})
	{
		my $requested_byte_size = $an->Readable->hr_to_bytes({size => $an->data->{cgi}{anvil_storage_pool1_size}, type => $an->data->{cgi}{anvil_storage_pool1_unit} });
		my $say_requested_size  = $an->Readable->bytes_to_hr({'bytes' => $requested_byte_size });
		my $byte_difference     = $requested_byte_size - $an->data->{cgi}{anvil_storage_pool1_byte_size};
		my $say_difference      = $an->Readable->bytes_to_hr({'bytes' => $byte_difference });
		my $say_new_size        = $an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool1_byte_size} });
		my $message             = $an->String->get({key => "message_0375", variables => { 
				say_requested_size	=>	$say_requested_size,
				say_new_size		=>	$say_new_size,
				say_difference		=>	$say_difference,
			}});
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
			message	=>	$message,
			row	=>	"#!string!state_0043!#",
		}});
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::anvil_storage_pool1_byte_size", value1 => $an->data->{cgi}{anvil_storage_pool1_byte_size},
		name2 => "cgi::anvil_storage_pool2_byte_size", value2 => $an->data->{cgi}{anvil_storage_pool2_byte_size},
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $an->data->{cgi}{anvil_storage_pool1_byte_size}) && (not $an->data->{cgi}{anvil_storage_pool2_byte_size}))
	{
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
			message	=>	"#!string!message_0397!#",
			row	=>	"#!string!state_0043!#",
		}});
		$ok = 0;
	}
	
	# Message stuff
	if (not $an->data->{cgi}{anvil_media_library_byte_size})
	{
		$an->data->{cgi}{anvil_media_library_byte_size} = $an->Readable->hr_to_bytes({size => $an->data->{cgi}{anvil_media_library_size}, type => $an->data->{cgi}{anvil_media_library_unit} });
	}
	my $node1_class   = "highlight_good_bold";
	my $node1_message = $an->String->get({key => "state_0054", variables => { 
			pool1_device	=>	$an->data->{node}{$node1}{pool1}{disk}.$an->data->{node}{$node1}{pool1}{partition},
			pool1_size	=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool1_byte_size} }),
			pool2_device	=>	$an->data->{cgi}{anvil_storage_pool2_byte_size} ? $an->data->{node}{$node1}{pool2}{disk}.$an->data->{node}{$node1}{pool2}{partition}        : "--",
			pool2_size	=>	$an->data->{cgi}{anvil_storage_pool2_byte_size} ? $an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool2_byte_size} }) : "--",
			media_size	=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_media_library_byte_size} }),
		}});
	my $node2_class   = "highlight_good_bold";
	my $node2_message = $an->String->get({key => "state_0054", variables => { 
			pool1_device	=>	$an->data->{node}{$node2}{pool1}{disk}.$an->data->{node}{$node2}{pool1}{partition},
			pool1_size	=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool1_byte_size} }),
			pool2_device	=>	$an->data->{cgi}{anvil_storage_pool2_byte_size} ? $an->data->{node}{$node2}{pool2}{disk}.$an->data->{node}{$node2}{pool2}{partition}        : "--",
			pool2_size	=>	$an->data->{cgi}{anvil_storage_pool2_byte_size} ? $an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool2_byte_size} }) : "--",
			media_size	=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_media_library_byte_size} }),
		}});
	if (not $ok)
	{
		$node1_class = "highlight_warning_bold";
		$node2_class = "highlight_warning_bold";
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0222!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	return($ok);
}

# This calls the specified node and (tries to) read and parse '/etc/redhat-release'
sub get_node_os_version
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_node_os_version" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### NOTE: Called 'node' for compatibility
	my $node     = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node", value1 => $node, 
		name2 => "port", value2 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $brand      = "";
	my $major      = 0;
	my $minor      = 0;
	my $shell_call = $an->data->{path}{cat}." /etc/redhat-release";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node",       value1 => $node,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^(.*?) release (\d+)\.(.*)/)
		{
			$brand = $1;
			$major = $2;
			$minor = $3;
			# CentOS uses 'CentOS Linux release 7.0.1406 (Core)', 
			# so I need to parse off the second '.' and whatever 
			# is after it.
			$minor =~ s/\..*$//;
			
			# Some have 'x.y (Final)', this strips that last bit off.
			$minor =~ s/\ \(.*?\)$//;
			$an->data->{node}{$node}{os}{brand}   = $brand;
			$an->data->{node}{$node}{os}{version} = "$major.$minor";
		}
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "node",  value1 => $node,
		name2 => "major", value2 => $major,
		name3 => "minor", value3 => $minor,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If it's RHEL, see if it's registered.
	if ($an->data->{node}{$node}{os}{brand} =~ /Red Hat Enterprise Linux Server/i)
	{
		# See if it's been registered already.
		$an->data->{node}{$node}{os}{registered} = 0;
		my $shell_call = $an->data->{path}{rhn_check}."; ".$an->data->{path}{echo}." exit:\$?";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node",       value1 => $node,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /^exit:(\d+)$/)
			{
				my $rc = $1;
				if ($rc eq "0")
				{
					$an->data->{node}{$node}{os}{registered} = 1;
				}
			}
		}
		$an->Log->entry({log_level => 2, message_key => "log_0213", message_variables => {
			node => $node, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	return($major, $minor);
}

# This checks for free space on the target node.
sub get_partition_data
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_partition_data" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### NOTE: Called 'node' for compatibility
	my $node     = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node", value1 => $node, 
		name2 => "port", value2 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my @disks;
	my $name       = "";
	my $type       = "";
	my $device     = "";
	my $shell_call = $an->data->{path}{lsblk}." --all --bytes --noheadings --pairs";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node",       value1 => $node,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# The order appears consistent, but I'll pull values out one at a time to be safe.
		if ($line =~ /TYPE="(.*?)"/i)
		{
			$type = $1;
		}
		if ($line =~ /NAME="(.*?)"/i)
		{
			$name = $1;
		}
		next if $type ne "disk";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node", value1 => $node,
			name2 => "name", value2 => $name,
			name3 => "type", value3 => $type,
		}, file => $THIS_FILE, line => __LINE__});
		
		push @disks, $name;
	}

	# Get the details on each disk now.
	my $disk_count = @disks;
	$an->Log->entry({log_level => 2, message_key => "log_0204", message_variables => {
		node       => $node, 
		disk_count => $disk_count, 
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $disk (@disks)
	{
		# We need to count how many existing partitions there are as we go.
		$an->data->{node}{$node}{disk}{$disk}{partition_count} = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node}::disk::${disk}::partition_count", value1 => $an->data->{node}{$node}{disk}{$disk}{partition_count},
		}, file => $THIS_FILE, line => __LINE__});
		
		my $shell_call = "
if [ ! -e ".$an->data->{path}{parted}." ]; 
then 
    ".$an->data->{path}{yum}." --quiet -y install parted;
    if [ ! -e ".$an->data->{path}{parted}." ]; 
    then 
        ".$an->data->{path}{echo}." parted not installed
    else
        ".$an->data->{path}{echo}." parted installed;
        ".$an->data->{path}{parted}." /dev/$disk unit B print free;
    fi
else
    ".$an->data->{path}{parted}." /dev/$disk unit B print free
fi";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node",       value1 => $node,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
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
			
			if ($line eq "parted not installed")
			{
				$device = "--";
				print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
					message	=>	"#!string!message_0368!#",
					row	=>	"#!string!state_0042!#",
				}});
				last;
			}
			elsif ($line eq "parted installed")
			{
				$an->Log->entry({log_level => 2, message_key => "log_0205", message_variables => {
					node      => $node, 
					'package' => "parted", 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Disk \/dev\/$disk: (\d+)B/)
			{
				$an->data->{node}{$node}{disk}{$disk}{size} = $1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node}::disk::${disk}::size", value1 => $an->data->{node}{$node}{disk}{$disk}{size},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Partition Table: (.*)/)
			{
				$an->data->{node}{$node}{disk}{$disk}{label} = $1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node}::disk::${disk}::label", value1 => $an->data->{node}{$node}{disk}{$disk}{label},
				}, file => $THIS_FILE, line => __LINE__});
			}
			#              part  start end   size  type  - don't care about the rest.
			elsif ($line =~ /^(\d+) (\d+)B (\d+)B (\d+)B(.*)$/)
			{
				# Existing partitions
				my $partition       =  $1;
				my $partition_start =  $2;
				my $partition_end   =  $3;
				my $partition_size  =  $4;
				my $partition_type  =  $5;
				   $partition_type  =~ s/\s+(\S+).*$/$1/;	# cuts off 'extended lba' to 'extended'
				$an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{start} = $partition_start;
				$an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{end}   = $partition_end;
				$an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{size}  = $partition_size;
				$an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{type}  = $partition_type;
				$an->data->{node}{$node}{disk}{$disk}{partition_count}++;
				# For our logs...
				my $say_partition_start = $an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{start}});
				my $say_partition_end   = $an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{end}});
				my $say_partition_size  = $an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{size}});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0008", message_variables => {
					name1 => "node::${node}::disk::${disk}::partition::${partition}::start", value1 => $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{start},
					name2 => "node::${node}::disk::${disk}::partition::${partition}::end",   value2 => $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{end},
					name3 => "node::${node}::disk::${disk}::partition::${partition}::size",  value3 => $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{size},
					name4 => "node::${node}::disk::${disk}::partition::${partition}::type",  value4 => $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{type},
					name5 => "node::${node}::disk::${disk}::partition_count",                value5 => $an->data->{node}{$node}{disk}{$disk}{partition_count},
					name6 => "say_partition_start",                                          value6 => $say_partition_start,
					name7 => "say_partition_end",                                            value7 => $say_partition_end,
					name8 => "say_partition_size",                                           value8 => $say_partition_size,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /^(\d+)B (\d+)B (\d+)B Free Space/)
			{
				# If there was some space left because of optimal alignment, it will be 
				# overwritten.
				my $free_space_start  = $1;
				my $free_space_end    = $2;
				my $free_space_size   = $3;
				$an->data->{node}{$node}{disk}{$disk}{free_space}{start} = $free_space_start;
				$an->data->{node}{$node}{disk}{$disk}{free_space}{end}   = $free_space_end;
				$an->data->{node}{$node}{disk}{$disk}{free_space}{size}  = $free_space_size;
				# For our logs...
				my $say_free_space_start = $an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node}{disk}{$disk}{free_space}{start}});
				my $say_free_space_end   = $an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node}{disk}{$disk}{free_space}{end}});
				my $say_free_space_size  = $an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node}{disk}{$disk}{free_space}{size}});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
					name1 => "node::${node}::disk::${disk}::free_space::start", value1 => $an->data->{node}{$node}{disk}{$disk}{free_space}{start},
					name2 => "node::${node}::disk::${disk}::free_space::end",   value2 => $an->data->{node}{$node}{disk}{$disk}{free_space}{end},
					name3 => "node::${node}::disk::${disk}::free_space::size",  value3 => $an->data->{node}{$node}{disk}{$disk}{free_space}{size},
					name4 => "say_free_space_start",                            value4 => $say_free_space_start,
					name5 => "say_free_space_end",                              value5 => $say_free_space_end,
					name6 => "say_free_space_size",                             value6 => $say_free_space_size,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Find which disk is bigger
	my $biggest_disk = "";
	my $biggest_size = 0;
	foreach my $disk (sort {$a cmp $b} keys %{$an->data->{node}{$node}{disk}})
	{
		my $size = $an->data->{node}{$node}{disk}{$disk}{size};
		if ($size > $biggest_size)
		{
			   $biggest_disk                          = $disk;
			   $biggest_size                          = $size;
			my $say_biggest_size                      = $an->Readable->bytes_to_hr({'bytes' => $biggest_size});
			   $an->data->{node}{$node}{biggest_disk} = $biggest_disk;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
				name1 => "biggest_disk",                value1 => $biggest_disk,
				name2 => "biggest_size",                value2 => $biggest_size,
				name3 => "say_biggest_size",            value3 => $say_biggest_size,
				name4 => "node::${node}::biggest_disk", value4 => $an->data->{node}{$node}{biggest_disk},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node",         value1 => $node,
		name2 => "biggest_disk", value2 => $biggest_disk,
	}, file => $THIS_FILE, line => __LINE__});
	return($biggest_disk);
}

# This determines which partitions to use for storage pool 1 and 2. Existing partitions override anything
# else for determining sizes.
sub get_storage_pool_partitions
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_storage_pool_partitions" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### TODO: Determine if I still need this function at all...
	# First up, check for /etc/drbd.d/r{0,1}.res on both nodes.
	my $node1 = $an->data->{cgi}{anvil_node1_current_ip};
	my $node2 = $an->data->{cgi}{anvil_node2_current_ip};

	my ($node1_r0_device, $node1_r1_device) = $an->InstallManifest->read_drbd_resource_files({
			target   => $an->data->{cgi}{anvil_node1_current_ip}, 
			port     => $an->data->{node}{$node1}{port}, 
			password => $an->data->{cgi}{anvil_node1_current_password},
			hostname => $an->data->{cgi}{anvil_node1_name},
		});
	my ($node2_r0_device, $node2_r1_device) = $an->InstallManifest->read_drbd_resource_files({
			target   => $an->data->{cgi}{anvil_node2_current_ip}, 
			port     => $an->data->{node}{$node2}{port}, 
			password => $an->data->{cgi}{anvil_node2_current_password},
			hostname => $an->data->{cgi}{anvil_node2_name},
		});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node1_r0_device", value1 => $node1_r0_device,
		name2 => "node1_r1_device", value2 => $node1_r1_device,
		name3 => "node2_r0_device", value3 => $node2_r0_device,
		name4 => "node2_r1_device", value4 => $node2_r1_device,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Next, decide what devices I will use if DRBD doesn't exist.
	foreach my $node ($an->data->{cgi}{anvil_node1_current_ip}, $an->data->{cgi}{anvil_node2_current_ip})
	{
		# If the disk to use is 'Xda', skip the first three partitions as they will be for the OS.
		my $disk = $an->data->{node}{$node}{biggest_disk};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node", value1 => $node,
			name2 => "disk", value2 => $disk,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Default to logical partitions.
		my $create_extended_partition = 0;
		my $pool1_partition           = 4;
		my $pool2_partition           = 5;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node::${node}::disk::${disk}::partition_count", value1 => $an->data->{node}{$node}{disk}{$disk}{partition_count},
			name2 => "pool1_partition",                               value2 => $pool1_partition,
			name3 => "pool2_partition",                               value3 => $pool2_partition,
		}, file => $THIS_FILE, line => __LINE__});
		if ($disk =~ /da$/)
		{
			# I need to know the label type to determine the partition numbers to use:
			# * If it's 'msdos', I need an extended partition and then two logical partitions. 
			#   (4, 5 and 6)
			# * If it's 'gpt', I just use two logical partition. (4 and 5).
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node}::disk::${disk}::label", value1 => $an->data->{node}{$node}{disk}{$disk}{label},
			}, file => $THIS_FILE, line => __LINE__});
			if ($an->data->{node}{$node}{disk}{$disk}{label} eq "msdos")
			{
				$create_extended_partition = 1;
				$pool1_partition           = 5;
				$pool2_partition           = 6;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
					name1 => "node::${node}::disk::${disk}::partition_count", value1 => $an->data->{node}{$node}{disk}{$disk}{partition_count},
					name2 => "create_extended_partition",                     value2 => $create_extended_partition,
					name3 => "pool1_partition",                               value3 => $pool1_partition,
					name4 => "pool2_partition",                               value4 => $pool2_partition,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($an->data->{node}{$node}{disk}{$disk}{partition_count} >= 4)
			{
				# This is probably a UEFI system, so there will be 4 partitions.
				$pool1_partition = 5;
				$pool2_partition = 6;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "pool1_partition", value1 => $pool1_partition,
					name2 => "pool2_partition", value2 => $pool2_partition,
				}, file => $THIS_FILE, line => __LINE__});
			}
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "create_extended_partition", value1 => $create_extended_partition,
				name2 => "pool1_partition",           value2 => $pool1_partition,
				name3 => "pool2_partition",           value3 => $pool2_partition,
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# I'll use the full disk, so the partition numbers will be the same regardless.
			$create_extended_partition = 0;
			$pool1_partition           = 1;
			$pool2_partition           = 2;
		}
		$an->data->{node}{$node}{pool1}{create_extended} = $create_extended_partition;
		$an->data->{node}{$node}{pool1}{device}          = "/dev/${disk}${pool1_partition}";
		$an->data->{node}{$node}{pool2}{device}          = "/dev/${disk}${pool2_partition}";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node",                         value1 => $node,
			name2 => "node::${node}::pool1::device", value2 => $an->data->{node}{$node}{pool1}{device},
			name3 => "node::${node}::pool2::device", value3 => $an->data->{node}{$node}{pool2}{device},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# OK, if we found a device in DRBD, override the values from the loop.
	my $node1 = $an->data->{cgi}{anvil_node1_current_ip};
	my $node2 = $an->data->{cgi}{anvil_node2_current_ip};
	
	$an->data->{node}{$node1}{pool1}{device} = $node1_r0_device ? $node1_r0_device : $an->data->{node}{$node1}{pool1}{device};
	$an->data->{node}{$node1}{pool2}{device} = $node1_r1_device ? $node1_r1_device : $an->data->{node}{$node1}{pool2}{device};
	$an->data->{node}{$node2}{pool1}{device} = $node2_r0_device ? $node2_r0_device : $an->data->{node}{$node2}{pool1}{device};
	$an->data->{node}{$node2}{pool2}{device} = $node2_r1_device ? $node2_r1_device : $an->data->{node}{$node2}{pool2}{device};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node::${node1}::pool1::device", value1 => $an->data->{node}{$node1}{pool1}{device},
		name2 => "node::${node1}::pool2::device", value2 => $an->data->{node}{$node1}{pool2}{device},
		name3 => "node::${node2}::pool1::device", value3 => $an->data->{node}{$node2}{pool1}{device},
		name4 => "node::${node2}::pool2::device", value4 => $an->data->{node}{$node2}{pool2}{device},
	}, file => $THIS_FILE, line => __LINE__});
	
	# Now, if either partition exists on either node, use that size to force the other node's size.
	my ($node1_pool1_disk, $node1_pool1_partition) = ($an->data->{node}{$node1}{pool1}{device} =~ /\/dev\/(.*?)(\d)/);
	my ($node1_pool2_disk, $node1_pool2_partition) = ($an->data->{node}{$node1}{pool2}{device} =~ /\/dev\/(.*?)(\d)/);
	my ($node2_pool1_disk, $node2_pool1_partition) = ($an->data->{node}{$node2}{pool1}{device} =~ /\/dev\/(.*?)(\d)/);
	my ($node2_pool2_disk, $node2_pool2_partition) = ($an->data->{node}{$node2}{pool2}{device} =~ /\/dev\/(.*?)(\d)/);
	$an->Log->entry({log_level => 2, message_key => "an_variables_0008", message_variables => {
		name1 => "node1_pool1_disk",      value1 => $node1_pool1_disk,
		name2 => "node1_pool1_partition", value2 => $node1_pool1_partition,
		name3 => "node1_pool2_disk",      value3 => $node1_pool2_disk,
		name4 => "node1_pool2_partition", value4 => $node1_pool2_partition,
		name5 => "node2_pool1_disk",      value5 => $node2_pool1_disk,
		name6 => "node2_pool1_partition", value6 => $node2_pool1_partition,
		name7 => "node2_pool2_disk",      value7 => $node2_pool2_disk,
		name8 => "node2_pool2_partition", value8 => $node2_pool2_partition,
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->data->{node}{$node1}{pool1}{disk}      = $node1_pool1_disk;
	$an->data->{node}{$node1}{pool1}{partition} = $node1_pool1_partition;
	$an->data->{node}{$node1}{pool2}{disk}      = $node1_pool2_disk;
	$an->data->{node}{$node1}{pool2}{partition} = $node1_pool2_partition;
	$an->data->{node}{$node2}{pool1}{disk}      = $node2_pool1_disk;
	$an->data->{node}{$node2}{pool1}{partition} = $node2_pool1_partition;
	$an->data->{node}{$node2}{pool2}{disk}      = $node2_pool2_disk;
	$an->data->{node}{$node2}{pool2}{partition} = $node2_pool2_partition;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0008", message_variables => {
		name1 => "node::${node1}::pool1::disk",      value1 => $an->data->{node}{$node1}{pool1}{disk},
		name2 => "node::${node1}::pool1::partition", value2 => $an->data->{node}{$node1}{pool1}{partition},
		name3 => "node::${node1}::pool2::disk",      value3 => $an->data->{node}{$node1}{pool2}{disk},
		name4 => "node::${node1}::pool2::partition", value4 => $an->data->{node}{$node1}{pool2}{partition},
		name5 => "node::${node2}::pool1::disk",      value5 => $an->data->{node}{$node2}{pool1}{disk},
		name6 => "node::${node2}::pool1::partition", value6 => $an->data->{node}{$node2}{pool1}{partition},
		name7 => "node::${node2}::pool2::disk",      value7 => $an->data->{node}{$node2}{pool2}{disk},
		name8 => "node::${node2}::pool2::partition", value8 => $an->data->{node}{$node2}{pool2}{partition},
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->data->{node}{$node1}{pool1}{existing_size} = $an->data->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{$node1_pool1_partition}{size} ? $an->data->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{$node1_pool1_partition}{size} : 0;
	$an->data->{node}{$node1}{pool2}{existing_size} = $an->data->{node}{$node1}{disk}{$node1_pool2_disk}{partition}{$node1_pool2_partition}{size} ? $an->data->{node}{$node1}{disk}{$node1_pool2_disk}{partition}{$node1_pool2_partition}{size} : 0;
	$an->data->{node}{$node2}{pool1}{existing_size} = $an->data->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{$node2_pool1_partition}{size} ? $an->data->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{$node2_pool1_partition}{size} : 0;
	$an->data->{node}{$node2}{pool2}{existing_size} = $an->data->{node}{$node2}{disk}{$node2_pool2_disk}{partition}{$node2_pool2_partition}{size} ? $an->data->{node}{$node2}{disk}{$node2_pool2_disk}{partition}{$node2_pool2_partition}{size} : 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node::${node1}::pool1::existing_size", value1 => $an->data->{node}{$node1}{pool1}{existing_size},
		name2 => "node::${node1}::pool2::existing_size", value2 => $an->data->{node}{$node1}{pool2}{existing_size},
		name3 => "node::${node2}::pool1::existing_size", value3 => $an->data->{node}{$node2}{pool1}{existing_size},
		name4 => "node::${node2}::pool2::existing_size", value4 => $an->data->{node}{$node2}{pool2}{existing_size},
	}, file => $THIS_FILE, line => __LINE__});
	
	return(0);
}

# This asks the user to unplug and then plug back in all network interfaces in
# order to map the physical interfaces to MAC addresses.
sub map_network
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "map_network" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1 = $an->data->{cgi}{anvil_node1_current_ip};
	my $node2 = $an->data->{cgi}{anvil_node2_current_ip};
	my ($node1_rc) = $an->InstallManifest->map_network_on_node({
			target   => $an->data->{cgi}{anvil_node1_current_ip}, 
			port     => $an->data->{node}{$node1}{port}, 
			password => $an->data->{cgi}{anvil_node1_current_password},
			remap    => 1, 
			say_node => "#!string!device_0005!#",
		});
	my ($node2_rc) = $an->InstallManifest->map_network_on_node({
			target   => $an->data->{cgi}{anvil_node2_current_ip}, 
			port     => $an->data->{node}{$node2}{port}, 
			password => $an->data->{cgi}{anvil_node2_current_password},
			remap    => 1, 
			say_node => "#!string!device_0006!#",
		});
	
	# Loop through the MACs seen and see if we've got a match for all
	# already. If any are missing, we'll need to remap.
	my $node1 = $an->data->{cgi}{anvil_node1_current_ip};
	my $node2 = $an->data->{cgi}{anvil_node2_current_ip};
	
	# These will be all populated *if*;
	# * The MACs seen on each node match MACs passed in from CGI (or 
	# * Loaded from manifest
	# * If the existing network appears complete already.
	# If any are missing, a remap will be needed.
	# Node 1
	$an->data->{conf}{node}{$node1}{set_nic}{bcn_link1} = "";
	$an->data->{conf}{node}{$node1}{set_nic}{bcn_link2} = "";
	$an->data->{conf}{node}{$node1}{set_nic}{sn_link1}  = "";
	$an->data->{conf}{node}{$node1}{set_nic}{sn_link2}  = "";
	$an->data->{conf}{node}{$node1}{set_nic}{ifn_link1} = "";
	$an->data->{conf}{node}{$node1}{set_nic}{ifn_link2} = "";
	# Node 2
	$an->data->{conf}{node}{$node2}{set_nic}{bcn_link1} = "";
	$an->data->{conf}{node}{$node2}{set_nic}{bcn_link2} = "";
	$an->data->{conf}{node}{$node2}{set_nic}{sn_link1}  = "";
	$an->data->{conf}{node}{$node2}{set_nic}{sn_link2}  = "";
	$an->data->{conf}{node}{$node2}{set_nic}{ifn_link1} = "";
	$an->data->{conf}{node}{$node2}{set_nic}{ifn_link2} = "";
	foreach my $nic (sort {$a cmp $b} keys %{$an->data->{conf}{node}{$node1}{current_nic}})
	{
		my $mac = $an->data->{conf}{node}{$node1}{current_nic}{$nic};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0009", message_variables => {
			name1 => "node",                           value1 => $node1,
			name2 => "nic",                            value2 => $nic,
			name3 => "mac",                            value3 => $mac,
			name4 => "cgi::anvil_node1_bcn_link1_mac", value4 => $an->data->{cgi}{anvil_node1_bcn_link1_mac},
			name5 => "cgi::anvil_node1_bcn_link2_mac", value5 => $an->data->{cgi}{anvil_node1_bcn_link2_mac},
			name6 => "cgi::anvil_node1_sn_link1_mac",  value6 => $an->data->{cgi}{anvil_node1_sn_link1_mac},
			name7 => "cgi::anvil_node1_sn_link2_mac",  value7 => $an->data->{cgi}{anvil_node1_sn_link2_mac},
			name8 => "cgi::anvil_node1_ifn_link1_mac", value8 => $an->data->{cgi}{anvil_node1_ifn_link1_mac},
			name9 => "cgi::anvil_node1_ifn_link2_mac", value9 => $an->data->{cgi}{anvil_node1_ifn_link2_mac},
		}, file => $THIS_FILE, line => __LINE__});
		if ($mac eq $an->data->{cgi}{anvil_node1_bcn_link1_mac})
		{
			$an->data->{conf}{node}{$node1}{set_nic}{bcn_link1} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::bcn_link1", value1 => $an->data->{conf}{node}{$node1}{set_nic}{bcn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node1_bcn_link2_mac})
		{
			$an->data->{conf}{node}{$node1}{set_nic}{bcn_link2} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::bcn_link2", value1 => $an->data->{conf}{node}{$node1}{set_nic}{bcn_link2},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node1_sn_link1_mac})
		{
			$an->data->{conf}{node}{$node1}{set_nic}{sn_link1} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::sn_link1", value1 => $an->data->{conf}{node}{$node1}{set_nic}{sn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node1_sn_link2_mac})
		{
			$an->data->{conf}{node}{$node1}{set_nic}{sn_link2} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::sn_link2", value1 => $an->data->{conf}{node}{$node1}{set_nic}{sn_link2},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node1_ifn_link1_mac})
		{
			$an->data->{conf}{node}{$node1}{set_nic}{ifn_link1} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::ifn_link1", value1 => $an->data->{conf}{node}{$node1}{set_nic}{ifn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node1_ifn_link2_mac})
		{
			$an->data->{conf}{node}{$node1}{set_nic}{ifn_link2} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::ifn_link2", value1 => $an->data->{conf}{node}{$node1}{set_nic}{ifn_link2},
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Unknown NIC.
			$an->Log->entry({log_level => 1, message_key => "log_0183", message_variables => {
				node => $node1, 
				nic  => $nic, 
				mac  => $mac, 
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{conf}{node}{$node1}{unknown_nic}{$nic} = $mac;
		}
	}
	foreach my $nic (sort {$a cmp $b} keys %{$an->data->{conf}{node}{$node2}{current_nic}})
	{
		my $mac = $an->data->{conf}{node}{$node2}{current_nic}{$nic};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0009", message_variables => {
			name1 => "node",                           value1 => $node2,
			name2 => "nic",                            value2 => $nic,
			name3 => "mac",                            value3 => $mac,
			name4 => "cgi::anvil_node2_bcn_link1_mac", value4 => $an->data->{cgi}{anvil_node2_bcn_link1_mac},
			name5 => "cgi::anvil_node2_bcn_link2_mac", value5 => $an->data->{cgi}{anvil_node2_bcn_link2_mac},
			name6 => "cgi::anvil_node2_sn_link1_mac",  value6 => $an->data->{cgi}{anvil_node2_sn_link1_mac},
			name7 => "cgi::anvil_node2_sn_link2_mac",  value7 => $an->data->{cgi}{anvil_node2_sn_link2_mac},
			name8 => "cgi::anvil_node2_ifn_link1_mac", value8 => $an->data->{cgi}{anvil_node2_ifn_link1_mac},
			name9 => "cgi::anvil_node2_ifn_link2_mac", value9 => $an->data->{cgi}{anvil_node2_ifn_link2_mac},
		}, file => $THIS_FILE, line => __LINE__});
		if ($mac eq $an->data->{cgi}{anvil_node2_bcn_link1_mac})
		{
			$an->data->{conf}{node}{$node2}{set_nic}{bcn_link1} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::bcn_link1", value1 => $an->data->{conf}{node}{$node2}{set_nic}{bcn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node2_bcn_link2_mac})
		{
			$an->data->{conf}{node}{$node2}{set_nic}{bcn_link2} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::bcn_link2", value1 => $an->data->{conf}{node}{$node2}{set_nic}{bcn_link2},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node2_sn_link1_mac})
		{
			$an->data->{conf}{node}{$node2}{set_nic}{sn_link1} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::sn_link1", value1 => $an->data->{conf}{node}{$node2}{set_nic}{sn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node2_sn_link2_mac})
		{
			$an->data->{conf}{node}{$node2}{set_nic}{sn_link2} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::sn_link2", value1 => $an->data->{conf}{node}{$node2}{set_nic}{sn_link2},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node2_ifn_link1_mac})
		{
			$an->data->{conf}{node}{$node2}{set_nic}{ifn_link1} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::ifn_link1", value1 => $an->data->{conf}{node}{$node2}{set_nic}{ifn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node2_ifn_link2_mac})
		{
			$an->data->{conf}{node}{$node2}{set_nic}{ifn_link2} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::ifn_link2", value1 => $an->data->{conf}{node}{$node2}{set_nic}{ifn_link2},
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Unknown NIC
			$an->Log->entry({log_level => 1, message_key => "log_0183", message_variables => {
				node => $node2, 
				nic  => $nic, 
				mac  => $mac, 
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{conf}{node}{$node2}{unknown_nic}{$nic} = $mac;
		}
	}
	
	# Now determine if a remap is needed. If ifn_bridge1 exists, assume it's configured and skip.
	my $node1_remap_needed = 0;
	my $node2_remap_needed = 0;
	
	# Check node1
	if ((exists $an->data->{conf}{node}{$node1}{current_nic}{ifn_bridge1}) && (exists $an->data->{conf}{node}{$node1}{current_nic}{ifn_bridge1}))
	{
		# Remap not needed, system already configured.
		$an->Log->entry({log_level => 2, message_key => "log_0184", file => $THIS_FILE, line => __LINE__});
		
		# To make the summary look better, we'll take the NICs we thought we didn't recognize and 
		# feed them into 'set_nic'.
		foreach my $node (sort {$a cmp $b} keys %{$an->data->{conf}{node}})
		{
			$an->Log->entry({log_level => 2, message_key => "log_0185", message_variables => { node => $node }, file => $THIS_FILE, line => __LINE__});
			foreach my $nic (sort {$a cmp $b} keys %{$an->data->{conf}{node}{$node}{unknown_nic}})
			{
				my $mac = $an->data->{conf}{node}{$node}{unknown_nic}{$nic};
				$an->data->{conf}{node}{$node}{set_nic}{$nic} = $mac;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "conf::node::${node}::set_nic::${nic}",  value1 => $an->data->{conf}{node}{$node}{set_nic}{$nic},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	else
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
			name1 => "node1",     value1 => $node1,
			name2 => "bcn_link1", value2 => $an->data->{conf}{node}{$node1}{set_nic}{bcn_link1},
			name3 => "bcn_link2", value3 => $an->data->{conf}{node}{$node1}{set_nic}{bcn_link2},
			name4 => "sn_link1",  value4 => $an->data->{conf}{node}{$node1}{set_nic}{sn_link1},
			name5 => "sn_link2",  value5 => $an->data->{conf}{node}{$node1}{set_nic}{sn_link2},
			name6 => "ifn_link1", value6 => $an->data->{conf}{node}{$node1}{set_nic}{ifn_link1},
			name7 => "ifn_link2", value7 => $an->data->{conf}{node}{$node1}{set_nic}{ifn_link2},
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $an->data->{conf}{node}{$node1}{set_nic}{bcn_link1}) || 
		    (not $an->data->{conf}{node}{$node1}{set_nic}{bcn_link2}) ||
		    (not $an->data->{conf}{node}{$node1}{set_nic}{sn_link1})  ||
		    (not $an->data->{conf}{node}{$node1}{set_nic}{sn_link2})  ||
		    (not $an->data->{conf}{node}{$node1}{set_nic}{ifn_link1}) ||
		    (not $an->data->{conf}{node}{$node1}{set_nic}{ifn_link2}))
		{
			$node1_remap_needed = 1;
		}
	}
	# Check node 2
	if ((exists $an->data->{conf}{node}{$node2}{current_nic}{ifn_bridge1}) && (exists $an->data->{conf}{node}{$node2}{current_nic}{ifn_bridge1}))
	{
		# Remap not needed, system already configured.
		$an->Log->entry({log_level => 2, message_key => "log_0184", file => $THIS_FILE, line => __LINE__});
		
		# To make the summary look better, we'll take the NICs we thought we didn't recognize and 
		# feed them into 'set_nic'.
		foreach my $node (sort {$a cmp $b} keys %{$an->data->{conf}{node}})
		{
			$an->Log->entry({log_level => 2, message_key => "log_0185", message_variables => { node => $node }, file => $THIS_FILE, line => __LINE__});
			foreach my $nic (sort {$a cmp $b} keys %{$an->data->{conf}{node}{$node}{unknown_nic}})
			{
				my $mac = $an->data->{conf}{node}{$node}{unknown_nic}{$nic};
				$an->data->{conf}{node}{$node}{set_nic}{$nic} = $mac;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name3 => "conf::node::${node}::set_nic::${nic}",  value3 => $an->data->{conf}{node}{$node}{set_nic}{$nic},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	else
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
			name1 => "node2",     value1 => $node2,
			name2 => "bcn_link1", value2 => $an->data->{conf}{node}{$node2}{set_nic}{bcn_link1},
			name3 => "bcn_link2", value3 => $an->data->{conf}{node}{$node2}{set_nic}{bcn_link2},
			name4 => "sn_link1",  value4 => $an->data->{conf}{node}{$node2}{set_nic}{sn_link1},
			name5 => "sn_link2",  value5 => $an->data->{conf}{node}{$node2}{set_nic}{sn_link2},
			name6 => "ifn_link1", value6 => $an->data->{conf}{node}{$node2}{set_nic}{ifn_link1},
			name7 => "ifn_link2", value7 => $an->data->{conf}{node}{$node2}{set_nic}{ifn_link2},
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $an->data->{conf}{node}{$node2}{set_nic}{bcn_link1}) || 
		    (not $an->data->{conf}{node}{$node2}{set_nic}{bcn_link2}) ||
		    (not $an->data->{conf}{node}{$node2}{set_nic}{sn_link1})  ||
		    (not $an->data->{conf}{node}{$node2}{set_nic}{sn_link2})  ||
		    (not $an->data->{conf}{node}{$node2}{set_nic}{ifn_link1}) ||
		    (not $an->data->{conf}{node}{$node2}{set_nic}{ifn_link2}))
		{
			$node2_remap_needed = 1;
		}
	}
	
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0030!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0030!#";
	my $message       = "";
	if ($node1_remap_needed)
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0031!#",
	}
	if ($node2_remap_needed)
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0031!#",
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::remap_network", value1 => $an->data->{cgi}{remap_network},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{cgi}{remap_network})
	{
		$node1_class        = "highlight_note_bold";
		$node1_message      = "#!string!state_0032!#",
		$node2_class        = "highlight_note_bold";
		$node2_message      = "#!string!state_0032!#",
		$node1_remap_needed = 1;
		$node2_remap_needed = 1;
	}

	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0229!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	return($node1_remap_needed, $node2_remap_needed);
}

# This downloads and runs the 'anvil-map-network' script
sub map_network_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "map_network_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### NOTE: Called 'node' for compatibility
	my $remap    = $parameter->{remap}    ? $parameter->{remap}    : "";
	my $say_node = $parameter->{say_node} ? $parameter->{say_node} : "";
	my $node     = $parameter->{target}   ? $parameter->{target}   : "";
	my $node     = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "remap",    value1 => $remap, 
		name2 => "say_node", value2 => $say_node, 
		name3 => "node",     value3 => $node, 
		name4 => "port",     value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	$an->data->{cgi}{update_manifest} = 0 if not $an->data->{cgi}{update_manifest};
	if ($remap)
	{
		my $title = $an->String->get({key => "title_0174", variables => { node => $say_node }});
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-start-network-config", replace => { title => $title }});
	}
	my $return_code = 0;
	
	# First, make sure the script is downloaded and ready to run.
	my $proceed    = 0;
	my $shell_call = "
if [ ! -e \"".$an->data->{path}{'anvil-map-network'}."\" ];
then
    ".$an->data->{path}{echo}." 'not found'
else
    if [ ! -s \"".$an->data->{path}{'anvil-map-network'}."\" ];
    then
        ".$an->data->{path}{echo}." 'blank file';
        if [ -e \"".$an->data->{path}{'anvil-map-network'}."\" ]; 
        then
            ".$an->data->{path}{rm}." -f ".$an->data->{path}{'anvil-map-network'}.";
        fi;
    else
        ".$an->data->{path}{'chmod'}." 755 ".$an->data->{path}{'anvil-map-network'}.";
        ".$an->data->{path}{echo}." ready;
    fi
fi";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->data->{node}{$node}{internet_access})
	{
		# No net, so no sense trying to download.
		$shell_call = "
if [ ! -e \"".$an->data->{path}{'anvil-map-network'}."\" ];
then
    ".$an->data->{path}{echo}." 'not found'
else
    if [ ! -e '".$an->data->{path}{striker_tools}."' ]
    then
        ".$an->data->{path}{echo}." 'directory: [".$an->data->{path}{striker_tools}."] not found'
    else
        ".$an->data->{path}{'chmod'}." 755 $an->data->{path}{'anvil-map-network'};
    fi
fi";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node",       value1 => $node,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ "ready")
		{
			# Downloaded (or already existed), ready to go.
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "proceed", value1 => $proceed,
			}, file => $THIS_FILE, line => __LINE__});
			$proceed = 1;
		}
		elsif ($line =~ /not found/i)
		{
			# Wasn't found and couldn't be downloaded.
			$return_code = 1;
		}
		elsif ($line =~ /No such file/i)
		{
			# Wasn't found and couldn't be downloaded.
			$return_code = 2;
		}
		elsif ($line =~ /blank file/i)
		{
			# Failed to download
			$return_code = 9;
		}
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "proceed",     value1 => $proceed,
		name2 => "return_code", value2 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $nics_seen = 0;
	if ($return_code)
	{
		if ($remap)
		{
			print $an->String->get({key => "message_0378"});
		}
	}
	elsif ($an->data->{node}{$node}{ssh_fh} !~ /^Net::SSH2/)
	{
		# Invalid or broken SSH handle.
		$an->Log->entry({log_level => 1, message_key => "log_0186", message_variables => {
			node   => $node, 
			ssh_fh => $an->data->{node}{$node}{ssh_fh}, 
		}, file => $THIS_FILE, line => __LINE__});
		$return_code = 8;
	}
	else
	{
		### WARNING: Don't use 'remote_call()'! We need input from the user, so we need to call the 
		###          target directly
		my $cluster = $an->data->{cgi}{cluster};
		my $ssh_fh  = $an->data->{node}{$node}{ssh_fh};
		my $close   = 0;
		
		### Build the shell call
		# Figure out the hash keys to use
		my $i;
		if ($node eq $an->data->{cgi}{anvil_node1_current_ip})
		{
			# Node is 1
			$i = 1;
		}
		elsif ($node eq $an->data->{cgi}{anvil_node2_current_ip})
		{
			# Node is 2
			$i = 2;
		}
		else
		{
			# wat?
			$return_code = 7;
		}
		
		my $shell_call = $an->data->{path}{'anvil-map-network'}." --script --summary";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "remap", value1 => $remap,
		}, file => $THIS_FILE, line => __LINE__});
		if ($remap)
		{
			$an->data->{cgi}{update_manifest} = 1;
			$shell_call = $an->data->{path}{'anvil-map-network'}." --script";
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call",           value1 => $shell_call,
			name2 => "cgi::update_manifest", value2 => $an->data->{cgi}{update_manifest},
		}, file => $THIS_FILE, line => __LINE__});
		
		### Start the call
		my $state;
		my $error;

		# We need to open a channel every time for 'exec' calls. We want to keep blocking off, but we
		# need to enable it for the channel() call.
		$ssh_fh->blocking(1);
		my $channel = $ssh_fh->channel();
		$ssh_fh->blocking(0);
		
		# Make the shell call
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "channel",    value1 => $channel,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		$channel->exec("$shell_call");
		
		# This keeps the connection open when the remote side is slow to return data.
		my @poll = {
			handle => $channel,
			events => [qw/in err/],
		};
		
		# We'll store the STDOUT and STDERR data here.
		my $stdout = "";
		my $stderr = "";
		
		# Not collect the data.
		while(1)
		{
			$ssh_fh->poll(250, \@poll);
			
			# Read in anything from STDOUT
			while($channel->read(my $chunk, 80))
			{
				$stdout .= $chunk;
			}
			while ($stdout =~ s/^(.*)\n//)
			{
				my $line = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "STDOUT", value1 => $line,
				}, file => $THIS_FILE, line => __LINE__});
				if ($line =~ /nic=(.*?),,mac=(.*)$/)
				{
					my $nic                                              = $1;
					my $mac                                              = $2;
					   $an->data->{conf}{node}{$node}{current_nic}{$nic} = $mac;
					$nics_seen++;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
						name1 => "nics_seen",                               value1 => $nics_seen,
						name2 => "conf::node::${node}::current_nics::$nic", value2 => $an->data->{conf}{node}{$node}{current_nic}{$nic},
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					print $an->InstallManifest->parse_script_line({source => "STDOUT", node => $node, line => $line});
				}
			}
			
			# Read in anything from STDERR
			while($channel->read(my $chunk, 80, 1))
			{
				$stderr .= $chunk;
			}
			while ($stderr =~ s/^(.*)\n//)
			{
				my $line = $1;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "STDERR", value1 => $line,
				}, file => $THIS_FILE, line => __LINE__});
				print $an->InstallManifest->parse_script_line({source => "STDERR", node => $node, line => $line});
			}
			
			# Exit when we get the end-of-file.
			last if $channel->eof;
		}
	}
	
	if (($remap) && (not $return_code))
	{
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-end-network-config"});
		
		# We should now know this info.
		$an->data->{conf}{node}{$node}{set_nic}{bcn_link1} = $an->data->{conf}{node}{$node}{current_nic}{bcn_link1};
		$an->data->{conf}{node}{$node}{set_nic}{bcn_link2} = $an->data->{conf}{node}{$node}{current_nic}{bcn_link2};
		$an->data->{conf}{node}{$node}{set_nic}{sn_link1}  = $an->data->{conf}{node}{$node}{current_nic}{sn_link1};
		$an->data->{conf}{node}{$node}{set_nic}{sn_link2}  = $an->data->{conf}{node}{$node}{current_nic}{sn_link2};
		$an->data->{conf}{node}{$node}{set_nic}{ifn_link1} = $an->data->{conf}{node}{$node}{current_nic}{ifn_link1};
		$an->data->{conf}{node}{$node}{set_nic}{ifn_link2} = $an->data->{conf}{node}{$node}{current_nic}{ifn_link2};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
			name1 => "conf::node::${node}::set_nic::bcn_link1", value1 => $an->data->{conf}{node}{$node}{set_nic}{bcn_link1},
			name2 => "conf::node::${node}::set_nic::bcn_link2", value2 => $an->data->{conf}{node}{$node}{set_nic}{bcn_link2},
			name3 => "conf::node::${node}::set_nic::sn_link1",  value3 => $an->data->{conf}{node}{$node}{set_nic}{sn_link1},
			name4 => "conf::node::${node}::set_nic::sn_link2",  value4 => $an->data->{conf}{node}{$node}{set_nic}{sn_link2},
			name5 => "conf::node::${node}::set_nic::ifn_link1", value5 => $an->data->{conf}{node}{$node}{set_nic}{ifn_link1},
			name6 => "conf::node::${node}::set_nic::ifn_link2", value6 => $an->data->{conf}{node}{$node}{set_nic}{ifn_link2},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "nics_seen",   value1 => $nics_seen,
		name2 => "return_code", value2 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	if (($nics_seen < 6) && (not $return_code))
	{
		$return_code = 4;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "return_code", value1 => $return_code,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# 0 == OK
	# 1 == remap tool not found.
	# 4 == Too few NICs found.
	# 7 == Unknown node.
	# 8 == SSH file handle broken.
	# 9 == Failed to download (empty file)
	return($return_code);
}

# This parses a line coming back from one of our shell scripts to convert string keys and possible variables
# into the current user's language.
sub parse_script_line
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "parse_script_line" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### NOTE: Called 'node' for compatibility
	my $source = $parameter->{source} ? $parameter->{source} : "";
	my $node   = $parameter->{node}   ? $parameter->{node}   : "";
	my $line   = $parameter->{line}   ? $parameter->{line}   : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "source", value1 => $source, 
		name2 => "node",   value2 => $node, 
		name3 => "line",   value3 => $line, 
	}, file => $THIS_FILE, line => __LINE__});

	return($line) if $line eq "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "$source", value1 => $line,
	}, file => $THIS_FILE, line => __LINE__});
	if ($line =~ /#!exit!(.*?)!#/)
	{
		# Program exited, reboot?
		my $reboot = $1;
		$an->data->{node}{$node}{reboot_needed} = $reboot eq "reboot" ? 1 : 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node}::reboot_needed", value1 => $an->data->{node}{$node}{reboot_needed},
		}, file => $THIS_FILE, line => __LINE__});
		return("<br />\n");
	}
	elsif ($line =~ /#!string!(.*?)!#$/)
	{
		# Simple string
		my $key  = $1;
		   $line = $an->String->get({key => $key});
	}
	elsif ($line =~ /#!string!(.*?)!#,,(.*)$/)
	{
		# String with variables.
		my $key   = $1;
		my $pairs = $2;
		my $vars  = {};
		foreach my $pair (split/,,/, $pairs)
		{
			if ($pair =~ /^(.*?)=$/)
			{
				my $variable = $1;
				my $value    = "";
				$vars->{$variable} = "";
			}
			elsif ($pair =~ /^(.*?)=(.*)$/)
			{
				my $variable = $1;
				my $value    = $2;
				$vars->{$variable} = $value;
			}
		}
		$line = $an->String->get({key => $key, variables => $vars});
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "line", value1 => $line,
	}, file => $THIS_FILE, line => __LINE__});
	
	return($line);
}

# This looks for the two DRBD resource files and, if found, pulls the partitions to use out of them.
sub read_drbd_resource_files
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "read_drbd_resource_files" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### NOTE: Called 'node' for compatibility
	my $hostname = $parameter->{hostname} ? $parameter->{hostname} : "";
	my $node     = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "hostname", value1 => $hostname, 
		name2 => "node",     value2 => $node, 
		name3 => "port",     value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $r0_device = "";
	my $r1_device = "";
	foreach my $file ($an->data->{path}{nodes}{drbd_r0}, $an->data->{path}{nodes}{drbd_r1})
	{
		# Skip if no pool1
		if (($an->data->{path}{nodes}{drbd_r1}) && (not $an->data->{cgi}{anvil_storage_pool2_byte_size}))
		{
			next;
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "file", value1 => $file,
		}, file => $THIS_FILE, line => __LINE__});
		my $in_host    = 0;
		my $shell_call = "
if [ -e '$file' ];
then
    ".$an->data->{path}{cat}." $file;
else
    ".$an->data->{path}{echo}." \"not found\"
fi";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node",       value1 => $node,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line eq "not found")
			{
				# Not found
				$an->Log->entry({log_level => 2, message_key => "log_0203", message_variables => {
					node => $node, 
					file => $file, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /on $hostname {/)
			{
				$in_host = 1;
				$an->Log->entry({log_level => 2, message_key => "log_0203", message_variables => {
					node => $node, 
					file => $file, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			if (($in_host) && ($line =~ /disk\s+(\/dev\/.*?);/))
			{
				my $device = $1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "device", value1 => $device,
				}, file => $THIS_FILE, line => __LINE__});
				if ($file =~ /r0/)
				{
					$r0_device = $device;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "r0_device", value1 => $r0_device,
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					$r1_device = $device;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "r1_device", value1 => $r1_device,
					}, file => $THIS_FILE, line => __LINE__});
				}
				last;
			}
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "r0_device", value1 => $r0_device,
		name2 => "r1_device", value2 => $r1_device,
	}, file => $THIS_FILE, line => __LINE__});
	return($r0_device, $r1_device);
}

# This runs the install manifest against both nodes.
sub run_new_install_manifest
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "run_new_install_manifest" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	print $an->Web->template({file => "common.html", template => "scanning-message", replace => {
		anvil_message	=>	$an->String->get({key => "message_0272", variables => { anvil => $an->data->{cgi}{cluster} }}),
	}});
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-header"});
	
	# Some variables we'll need.
	$an->data->{packages}{to_install} = {
		acpid				=>	0,
		'alteeve-repo'			=>	0,
		'bash-completion'		=>	0,
		'bridge-utils'			=>	0,
		ccs				=>	0,
		cman 				=>	0,
		'compat-libstdc++-33.i686'	=>	0,
		corosync			=>	0,
		'cyrus-sasl'			=>	0,
		'cyrus-sasl-plain'		=>	0,
		dmidecode			=>	0,
		'drbd84-utils'			=>	0,
		expect				=>	0,
		'fence-agents'			=>	0,
		freeipmi			=>	0,
		'freeipmi-bmc-watchdog'		=>	0,
		'freeipmi-ipmidetectd'		=>	0,
		gcc 				=>	0,
		'gcc-c++'			=>	0,
		gd				=>	0,
		'gfs2-utils'			=>	0,
		gpm				=>	0,
		ipmitool			=>	0,
		irqbalance			=>	0,
		'kernel-headers'		=>	0,
		'kernel-devel'			=>	0,
		'kmod-drbd84'			=>	0,
		'libstdc++.i686' 		=>	0,
		'libstdc++-devel.i686'		=>	0,
		libvirt				=>	0,
		'lvm2-cluster'			=>	0,
		mailx				=>	0,
		man				=>	0,
		mlocate				=>	0,
		mtr				=>	0,
		'net-snmp'			=>	0,
		ntp				=>	0,
		OpenIPMI			=>	0,
		'OpenIPMI-libs'			=>	0,
		'openssh-clients'		=>	0,
		'openssl-devel'			=>	0,
		'qemu-kvm'			=>	0,
		'qemu-kvm-tools'		=>	0,
		parted				=>	0,
		pciutils			=>	0,
		pcp				=>	0,
		perl				=>	0,
		'perl-CGI'			=>	0,
		'perl-DBD-Pg'			=>	0,
		'perl-Digest-SHA'		=>	0,
		'perl-TermReadKey'		=>	0,
		'perl-Text-Diff'		=>	0,
		'perl-Time-HiRes'		=>	0,
		'perl-Net-SSH2'			=>	0,
		'perl-Sys-Virt'			=>	0,
		'perl-XML-Simple'		=>	0,
		'policycoreutils-python'	=>	0,
		postgresql95			=>	0,
		postfix				=>	0,
		'python-virtinst'		=>	0,
		rgmanager			=>	0,
		ricci				=>	0,
		rsync				=>	0,
		screen				=>	0,
		syslinux			=>	0,
		sysstat				=>	0,
		tuned				=>	0,
		'util-linux-ng'			=>	0,
		'vim-enhanced'			=>	0,
		'virt-viewer'			=>	0,
		wget				=>	0,
		
		# These should be more selectively installed based on lspci (or
		# similar) output.
		MegaCli				=>	0,
		storcli				=>	0,
	};
	
	if ($an->data->{perform_install})
	{
		# OK, GO!
		print $an->Web->template({file => "install-manifest.html", template => "install-beginning"});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::update_manifest", value1 => $an->data->{cgi}{update_manifest},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{update_manifest})
		{
			# Write the updated manifest and reload it.
			$an->ScanCore->save_install_manifest();
			$an->ScanCore->parse_install_manifest({uuid => $an->data->{cgi}{manifest_uuid}});
			print $an->Web->template({file => "install-manifest.html", template => "manifest-created", replace => { message => $an->String->get({key => "message_0464"}) }});
		}
	}
	
	# If the node(s) are not online, we'll set up a repo pointing at this maching *if* we're configured
	# to be a repo.
	$an->InstallManifest->check_local_repo();
	
	# Make sure we can log into both nodes.
	$an->InstallManifest->check_connection() or return(1);
	
	# Make sure both nodes can get online. We'll try to install even without Internet access.
	$an->InstallManifest->verify_internet_access();
	
	# Make sure both nodes are EL6 nodes.
	$an->InstallManifest->verify_os() or return(1);
	
	# Beyond here, perl is needed in the targets.
	$an->InstallManifest->verify_perl_is_installed();
	
	# This checks the disks out and selects the largest disk on each node. It doesn't sanity check much
	# yet.
	$an->InstallManifest->check_storage();
	
	# See if the node is in a cluster already. If so, we'll set a flag to block reboots if needed.
	$an->InstallManifest->check_if_in_cluster();
	
	# Get a map of the physical network interfaces for later remapping to device names.
	my ($node1_remap_required, $node2_remap_required) = $an->InstallManifest->map_network();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_remap_required", value1 => $node1_remap_required,
		name2 => "node2_remap_required", value2 => $node2_remap_required,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If either/both nodes need a remap done, do it now.
	my $node1    = $an->data->{cgi}{anvil_node1_current_ip};
	my $node2    = $an->data->{cgi}{anvil_node2_current_ip};
	my $node1_rc = 0;
	my $node2_rc = 0;
	if ($node1_remap_required)
	{
		($node1_rc) = $an->InstallManifest->map_network_on_node({
				target   => $an->data->{cgi}{anvil_node1_current_ip}, 
				port     => $an->data->{node}{$node1}{port}, 
				password => $an->data->{cgi}{anvil_node1_current_password},
				remap    => 1, 
				say_node => "#!string!device_0005!#",
			});
	}
	if ($node2_remap_required)
	{
		($node2_rc) = $an->InstallManifest->map_network_on_node({
				target   => $an->data->{cgi}{anvil_node2_current_ip}, 
				port     => $an->data->{node}{$node2}{port}, 
				password => $an->data->{cgi}{anvil_node2_current_password},
				remap    => 1, 
				say_node => "#!string!device_0006!#",
			});
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_rc", value1 => $node1_rc,
		name2 => "node2_rc", value2 => $node2_rc,
	}, file => $THIS_FILE, line => __LINE__});
	# 0 == OK
	# 1 == remap tool not found.
	# 4 == Too few NICs found.
	# 7 == Unknown node.
	# 8 == SSH file handle broken.
	# 9 == Failed to download (empty file)
	if (($node1_rc) || ($node2_rc))
	{
		# Something went wrong
		if (($node1_rc eq "1") || ($node2_rc eq "1"))
		{
			### Message already printed.
			# remap tool not found.
			#print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-failed-inline", replace => { message => "#!string!message_0378!#" }});
		}
		if (($node1_rc eq "4") || ($node2_rc eq "4"))
		{
			# Not enough NICs (or remap program failure)
			print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-failed-inline", replace => { message => "#!string!message_0380!#" }});
		}
		if (($node1_rc eq "7") || ($node2_rc eq "7"))
		{
			# Didn't recognize the node
			print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-failed-inline", replace => { message => "#!string!message_0383!#" }});
		}
		if (($node1_rc eq "8") || ($node2_rc eq "8"))
		{
			# SSH handle didn't exist, though it should have.
			print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-failed-inline", replace => { message => "#!string!message_0382!#" }});
		}
		if (($node1_rc eq "9") || ($node2_rc eq "9"))
		{
			# Failed to download the anvil-map-network script
			print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-failed-inline", replace => { message => "#!string!message_0381!#" }});
		}
		print $an->Web->template({file => "install-manifest.html", template => "close-table"});
		return(2);
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::perform_install", value1 => $an->data->{cgi}{perform_install},
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->data->{cgi}{perform_install})
	{
		# Now summarize and ask the user to confirm.
		$an->InstallManifest->summarize_build_plan();
		return(0);
	}
	else
	{
		# If we're here, we're ready to start!
		print $an->Web->template({file => "install-manifest.html", template => "sanity-checks-complete"});
		
		# Rewrite the install manifest if need be.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::update_manifest", value1 => $an->data->{cgi}{update_manifest},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{update_manifest})
		{
			# Update the running install manifest to record the MAC addresses the user selected.
			$an->InstallManifest->update_install_manifest();
		}
		
		# Back things up.
		backup_files($an);
		
		# Register the nodes with RHN, if needed.
		register_with_rhn($an);
		
		# Configure the network
		configure_network($an) or return(1);
		
		# Configure the NTP on the servers, if set.
		configure_ntp($an) or return(1);
		
		# Add user-specified repos
		#add_user_repositories($an);
		
		# Install needed RPMs.
		install_programs($an) or return(1);
		
		# Update the OS on each node.
		update_nodes($an);
		
		# Configure daemons
		configure_daemons($an) or return(1);
		
		# Set the ricci password
		set_ricci_password($an) or return(1);
		
		# Write out the cluster configuration file
		configure_cman($an) or return(1);
		
		# Write out the clustered LVM configuration files
		configure_clvmd($an) or return(1);
		
		# This configures IPMI, if IPMI is set as a fence device.
		if ($an->data->{cgi}{anvil_fence_order} =~ /ipmi/)
		{
			configure_ipmi($an) or return(1);
		}
		
		# Configure storage stage 1 (partitioning).
		configure_storage_stage1($an) or return(1);
		
		# This handles configuring SELinux.
		configure_selinux($an) or return(1); 
		
		# Set the root user's passwords as the last step to ensure reloading the browser works for 
		# as long as possible.
		set_root_password($an) or return(1);
		
		# This sets up the various Striker tools and ScanCore. It must run before storage stage2 
		# because DRBD will need it.
		configure_striker_tools($an) or return(1);
		
		# If a reboot is needed, now is the time to do it. This will switch the CGI nodeX IPs to the 
		# new ones, too.
		reboot_nodes($an) or return(1);
		
		# Configure storage stage 2 (drbd)
		configure_storage_stage2($an) or return(1);
		
		# Start cman up
		start_cman($an) or return(1);
		
		# Live migration won't work until we've populated ~/.ssh/known_hosts, so do so now.
		configure_ssh($an) or return(1);
		
		# This manually starts DRBD, forcing one to primary if needed, configures clvmd, sets up the 
		# PVs and VGs, creates the /shared LV, creates the GFS2 partition and configures fstab.
		configure_storage_stage3($an) or return(1);
		
		# Enable (or disable) tools.
		enable_tools($an) or return(1);
		
		### If we're not dead, it's time to celebrate!
		# Is this Anvil! already in the config file?
		my ($anvil_configured) = check_config_for_anvil($an);
		
		# If the 'anvil_configured' is 1, run 'configure_ssh_local()'
		if ($anvil_configured)
		{
			# Setup ssh locally
			AN::Cluster::configure_ssh_local($an, $an->data->{cgi}{anvil_name});
			
			# Sync with the peer, if we can.
			my $peer = AN::Cluster::sync_with_peer($an);
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "peer", value1 => $peer,
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Do we need to show the link for adding the Anvil! to the config?
		my $message = $an->String->get({key => "message_0286", variables => { url => "?cluster=".$an->data->{cgi}{cluster} }});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "message", value1 => $message,
		}, file => $THIS_FILE, line => __LINE__});
		if (not $anvil_configured)
		{
			# Nope
			my $url .= "?anvil=new";
			   $url .= "&anvil_id=new";
			   $url .= "&config=new";
			   $url .= "&section=global";
			   $url .= "&cluster__new__name=".$an->data->{cgi}{anvil_name};
			   $url .= "&cluster__new__ricci_pw=".$an->data->{cgi}{anvil_password};
			   $url .= "&cluster__new__root_pw=".$an->data->{cgi}{anvil_password};
			   $url .= "&cluster__new__nodes_1_name=".$an->data->{cgi}{anvil_node1_name};
			   $url .= "&cluster__new__nodes_1_ip=".$an->data->{cgi}{anvil_node1_bcn_ip};
			   $url .= "&cluster__new__nodes_2_name=".$an->data->{cgi}{anvil_node2_name};
			   $url .= "&cluster__new__nodes_2_ip=".$an->data->{cgi}{anvil_node2_bcn_ip};
			# see what these value are, relative to global values.
			
			# Now the string.
			$message = $an->String->get({key => "message_0402", variables => { url => $url }});
		}
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-succes", replace => { message => $message }});
		
		# Enough of that, now everyone go home.
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-footer"});
	}
	
	return(0);
}

# This summarizes the install plan and gives the use a chance to tweak it or re-run the cable mapping.
sub summarize_build_plan
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "summarize_build_plan" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1                = $an->data->{cgi}{anvil_node1_current_ip};
	my $node2                = $an->data->{cgi}{anvil_node2_current_ip};
	my $say_node1_registered = "#!string!state_0047!#";
	my $say_node2_registered = "#!string!state_0047!#";
	my $say_node1_class      = "highlight_detail";
	my $say_node2_class      = "highlight_detail";
	my $enable_rhn           = 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node::${node1}::os::brand", value1 => $an->data->{node}{$node1}{os}{brand},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{node}{$node1}{os}{brand} =~ /Red Hat Enterprise Linux Server/)
	{
		# See if it's been registered already.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node1}::os::registered", value1 => $an->data->{node}{$node1}{os}{registered},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{node}{$node1}{os}{registered})
		{
			# Already registered.
			$say_node1_registered = "#!string!state_0105!#";
			$say_node1_class      = "highlight_good";
		}
		else
		{
			# Registration required, but do we have internet
			# access?
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node1}::internet", value1 => $an->data->{node}{$node1}{internet},
			}, file => $THIS_FILE, line => __LINE__});
			if (not $an->data->{sys}{install_manifest}{show}{rhn_checks})
			{
				# User has disabled RHN checks/registration.
				$say_node1_registered = "#!string!state_0102!#";
				$enable_rhn           = 0;
			}
			elsif ($an->data->{node}{$node1}{internet})
			{
				# We're good.
				$say_node1_registered = "#!string!state_0103!#";
				$say_node1_class      = "highlight_detail";
				$enable_rhn           = 1;
			}
			else
			{
				# Lets hope they have the DVD image...
				$say_node1_registered = "#!string!state_0104!#";
				$say_node1_class      = "highlight_warning";
			}
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node::${node2}::os::brand", value1 => $an->data->{node}{$node2}{os}{brand},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{node}{$node2}{os}{brand} =~ /Red Hat Enterprise Linux Server/)
	{
		# See if it's been registered already.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node2}::os::registered", value1 => $an->data->{node}{$node2}{os}{registered},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{node}{$node2}{os}{registered})
		{
			# Already registered.
			$say_node2_registered = "#!string!state_0105!#";
			$say_node2_class      = "highlight_good";
		}
		else
		{
			# Registration required, but do we have internet access?
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node2}::internet", value1 => $an->data->{node}{$node2}{internet},
			}, file => $THIS_FILE, line => __LINE__});
			if (not $an->data->{sys}{install_manifest}{show}{rhn_checks})
			{
				# User has disabled RHN checks/registration.
				$say_node2_registered = "#!string!state_0102!#";
				$enable_rhn           = 0;
			}
			elsif ($an->data->{node}{$node2}{internet})
			{
				# We're good.
				$say_node2_registered = "#!string!state_0103!#";
				$say_node2_class      = "highlight_detail";
				$enable_rhn           = 1;
			}
			else
			{
				# Lets hope they have the DVD image...
				$say_node2_registered = "#!string!state_0104!#";
				$say_node2_class      = "highlight_warning";
			}
		}
	}
	
	my $say_node1_os = $an->data->{node}{$node1}{os}{brand} =~ /Red Hat Enterprise Linux Server/ ? "RHEL" : $an->data->{node}{$node1}{os}{brand};
	my $say_node2_os = $an->data->{node}{$node2}{os}{brand} =~ /Red Hat Enterprise Linux Server/ ? "RHEL" : $an->data->{node}{$node2}{os}{brand};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "say_node1_os", value1 => $say_node1_os,
		name2 => "say_node2_os", value2 => $say_node2_os,
	}, file => $THIS_FILE, line => __LINE__});
	my $rhn_template = "";
	if ($enable_rhn)
	{
		$rhn_template = $an->Web->template({file => "install-manifest.html", template => "rhn-credential-form", replace => { 
			rhn_user	=>	$an->data->{cgi}{rhn_user},
			rhn_password	=>	$an->data->{cgi}{rhn_password},
		}});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0012", message_variables => {
		name1  => "conf::node::${node1}::set_nic::bcn_link1", value1  => $an->data->{conf}{node}{$node1}{set_nic}{bcn_link1},
		name2  => "conf::node::${node1}::set_nic::bcn_link2", value2  => $an->data->{conf}{node}{$node1}{set_nic}{bcn_link2},
		name3  => "conf::node::${node1}::set_nic::sn_link1",  value3  => $an->data->{conf}{node}{$node1}{set_nic}{sn_link1},
		name4  => "conf::node::${node1}::set_nic::sn_link2",  value4  => $an->data->{conf}{node}{$node1}{set_nic}{sn_link2},
		name5  => "conf::node::${node1}::set_nic::ifn_link1", value5  => $an->data->{conf}{node}{$node1}{set_nic}{ifn_link1},
		name6  => "conf::node::${node1}::set_nic::ifn_link2", value6  => $an->data->{conf}{node}{$node1}{set_nic}{ifn_link2},
		name7  => "conf::node::${node2}::set_nic::bcn_link1", value7  => $an->data->{conf}{node}{$node2}{set_nic}{bcn_link1},
		name8  => "conf::node::${node2}::set_nic::bcn_link2", value8  => $an->data->{conf}{node}{$node2}{set_nic}{bcn_link2},
		name9  => "conf::node::${node2}::set_nic::sn_link1",  value9  => $an->data->{conf}{node}{$node2}{set_nic}{sn_link1},
		name10 => "conf::node::${node2}::set_nic::sn_link2",  value10 => $an->data->{conf}{node}{$node2}{set_nic}{sn_link2},
		name11 => "conf::node::${node2}::set_nic::ifn_link1", value11 => $an->data->{conf}{node}{$node2}{set_nic}{ifn_link1},
		name12 => "conf::node::${node2}::set_nic::ifn_link2", value12 => $an->data->{conf}{node}{$node2}{set_nic}{ifn_link2},
	}, file => $THIS_FILE, line => __LINE__});
	
	my $anvil_storage_partition_1_hr_size = $an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_partition_2_byte_size} });
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::anvil_storage_partition_1_byte_size", value1 => $an->data->{cgi}{anvil_storage_partition_1_byte_size},
		name2 => "anvil_storage_partition_1_hr_size",        value2 => $anvil_storage_partition_1_hr_size,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->data->{cgi}{anvil_storage_partition_1_byte_size})
	{
		$an->data->{cgi}{anvil_storage_partition_1_byte_size} = $an->data->{cgi}{anvil_media_library_byte_size} + $an->data->{cgi}{anvil_storage_pool1_byte_size};
	}
	if (not $an->data->{cgi}{anvil_storage_partition_2_byte_size})
	{
		$an->data->{cgi}{anvil_storage_partition_2_byte_size} = $an->data->{cgi}{anvil_storage_pool2_byte_size};
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-summary-and-confirm", replace => { 
		form_file			=>	"/cgi-bin/striker",
		title				=>	"#!string!title_0177!#",
		bcn_link1_name			=>	$an->String->get({key => "script_0059", variables => { number => "1" }}),
		bcn_link1_node1_mac		=>	$an->data->{conf}{node}{$node1}{set_nic}{bcn_link1},
		bcn_link1_node2_mac		=>	$an->data->{conf}{node}{$node2}{set_nic}{bcn_link1},
		bcn_link2_name			=>	$an->String->get({key => "script_0059", variables => { number => "2" }}),
		bcn_link2_node1_mac		=>	$an->data->{conf}{node}{$node1}{set_nic}{bcn_link2},
		bcn_link2_node2_mac		=>	$an->data->{conf}{node}{$node2}{set_nic}{bcn_link2},
		sn_link1_name			=>	$an->String->get({key => "script_0061", variables => { number => "1" }}),
		sn_link1_node1_mac		=>	$an->data->{conf}{node}{$node1}{set_nic}{sn_link1},
		sn_link1_node2_mac		=>	$an->data->{conf}{node}{$node2}{set_nic}{sn_link1},
		sn_link2_name			=>	$an->String->get({key => "script_0061", variables => { number => "2" }}),
		sn_link2_node1_mac		=>	$an->data->{conf}{node}{$node1}{set_nic}{sn_link2},
		sn_link2_node2_mac		=>	$an->data->{conf}{node}{$node2}{set_nic}{sn_link2},
		ifn_link1_name			=>	$an->String->get({key => "script_0063", variables => { number => "1" }}),
		ifn_link1_node1_mac		=>	$an->data->{conf}{node}{$node1}{set_nic}{ifn_link1},
		ifn_link1_node2_mac		=>	$an->data->{conf}{node}{$node2}{set_nic}{ifn_link1},
		ifn_link2_name			=>	$an->String->get({key => "script_0063", variables => { number => "2" }}),
		ifn_link2_node1_mac		=>	$an->data->{conf}{node}{$node1}{set_nic}{ifn_link2},
		ifn_link2_node2_mac		=>	$an->data->{conf}{node}{$node2}{set_nic}{ifn_link2},
		media_library_size		=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_media_library_byte_size} }),
		pool1_size			=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool1_byte_size} }),
		pool2_size			=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool2_byte_size} }),
		partition1_size			=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_partition_1_byte_size} }),
		partition2_size			=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_partition_2_byte_size} }),
		edit_manifest_url		=>	"?config=true&task=create-install-manifest&load=".$an->data->{cgi}{run},
		remap_network_url		=>	$an->data->{sys}{cgi_string}."&remap_network=true",
		anvil_node1_current_ip		=>	$an->data->{cgi}{anvil_node1_current_ip},
		anvil_node1_current_ip		=>	$an->data->{cgi}{anvil_node1_current_ip},
		anvil_node1_current_password	=>	$an->data->{cgi}{anvil_node1_current_password},
		anvil_node2_current_ip		=>	$an->data->{cgi}{anvil_node2_current_ip},
		anvil_node2_current_password	=>	$an->data->{cgi}{anvil_node2_current_password},
		config				=>	$an->data->{cgi}{config},
		confirm				=>	$an->data->{cgi}{confirm},
		'do'				=>	$an->data->{cgi}{'do'},
		run				=>	$an->data->{cgi}{run},
		task				=>	$an->data->{cgi}{task},
		node1_os_name			=>	$say_node1_os,
		node2_os_name			=>	$say_node2_os,
		node1_os_registered		=>	$say_node1_registered,
		node1_os_registered_class	=>	$say_node1_class,
		node2_os_registered		=>	$say_node2_registered,
		node2_os_registered_class	=>	$say_node2_class,
		update_manifest			=>	$an->data->{cgi}{update_manifest},
		rhn_template			=>	$rhn_template,
		striker_user			=>	$an->data->{cgi}{striker_user},
		striker_database		=>	$an->data->{cgi}{striker_database},
		anvil_striker1_user		=>	$an->data->{cgi}{anvil_striker1_user},
		anvil_striker1_password		=>	$an->data->{cgi}{anvil_striker1_password},
		anvil_striker1_database		=>	$an->data->{cgi}{anvil_striker1_database},
		anvil_striker2_user		=>	$an->data->{cgi}{anvil_striker2_user},
		anvil_striker2_password		=>	$an->data->{cgi}{anvil_striker2_password},
		anvil_striker2_database		=>	$an->data->{cgi}{anvil_striker2_database},
	}});
	
	return(0);
}

# This pings a website to check for an internet connection. Will clean up routes that conflict with the 
# default one as well.
sub test_internet_connection
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "test_internet_connection" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### NOTE: Called 'node' for compatibility
	my $node     = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node", value1 => $node, 
		name2 => "port", value2 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# After installing, sometimes/often the system will come up with multiple interfaces on the same 
	# subnet, causing default route problems. So the first thing to do is look for the interface the IP
	# we're using to connect is on, see it's subnet and see if anything else is on the same subnet. If 
	# so, delete the other interface(s) from the route table.
	my $dg_device  = "";
	my $shell_call = $an->data->{path}{route}." -n";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node",       value1 => $node,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$node, 
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
		
		if ($line =~ /UG/)
		{
			$dg_device = ($line =~ /.* (.*?)$/)[0];
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "dg_device", value1 => $dg_device,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /^(\d+\.\d+\.\d+\.\d+) .*? (\d+\.\d+\.\d+\.\d+) .*? \d+ \d+ \d+ (.*?)$/)
		{
			my $network   = $1;
			my $netmask   = $2;
			my $interface = $3;
			$an->data->{conf}{node}{$node}{routes}{interface}{$interface} = "$network/$netmask";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node}::routes::interface::${interface}", value1 => $an->data->{conf}{node}{$node}{routes}{interface}{$interface},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Now look for offending devices 
	$an->Log->entry({log_level => 2, message_key => "log_0198", message_variables => { node => $node }, file => $THIS_FILE, line => __LINE__});
	
	my ($dg_network, $dg_netmask) = ($an->data->{conf}{node}{$node}{routes}{interface}{$dg_device} =~ /^(\d+\.\d+\.\d+\.\d+)\/(\d+\.\d+\.\d+\.\d+)/);
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "dg_device", value1 => $dg_device,
		name2 => "network",   value2 => $dg_network/$dg_netmask,
	}, file => $THIS_FILE, line => __LINE__});
	
	foreach my $interface (sort {$a cmp $b} keys %{$an->data->{conf}{node}{$node}{routes}{interface}})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "interface", value1 => $interface,
			name2 => "dg_device", value2 => $dg_device,
		}, file => $THIS_FILE, line => __LINE__});
		next if $interface eq $dg_device;
		
		my ($network, $netmask) = ($an->data->{conf}{node}{$node}{routes}{interface}{$interface} =~ /^(\d+\.\d+\.\d+\.\d+)\/(\d+\.\d+\.\d+\.\d+)/);
		if (($dg_network eq $network) && ($dg_netmask eq $netmask))
		{
			# Conflicting route
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "interface", value1 => $interface,
				name2 => "network",   value2 => $network,
				name3 => "netmask",   value3 => $netmask,
			}, file => $THIS_FILE, line => __LINE__});
			
			my $shell_call = $an->data->{path}{route}." del -net $network netmask $netmask dev $interface; ".$an->data->{path}{echo}." rc:\$?";
			my $password   = $an->data->{sys}{root_password};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "node",       value1 => $node,
				name2 => "shell_call", value2 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$node,
				port		=>	$node, 
				password	=>	$password,
				shell_call	=>	$shell_call,
			});
			foreach my $line (@{$return})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /^rc:(\d+)/)
				{
					my $rc = $1;
					if ($rc eq "0")
					{
						# Success
						$an->Log->entry({log_level => 1, message_key => "log_0199", message_variables => {
							network   => $network, 
							netmask   => $netmask, 
							interface => $interface, 
							node      => $node, 
						}, file => $THIS_FILE, line => __LINE__});
					}
					else
					{
						# Failed.
						$an->Log->entry({log_level => 1, message_key => "log_0200", message_variables => {
							network     => $network, 
							netmask     => $netmask, 
							interface   => $interface, 
							node        => $node, 
							return_code => $rc, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
			}
		}
		else
		{
			# Route is OK, for another network.
			$an->Log->entry({log_level => 3, message_key => "log_0201", message_variables => {
				node => $node, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Default to no connection
	$an->data->{node}{$node}{internet} = 0;
	
	# 0 == pingable, 1 == failed.
	my $ping_rc = $an->Check->ping({
		ping		=>	"8.8.8.8", 
		count		=>	3,
		target		=>	$node,
		port		=>	$node, 
		password	=>	$password,
	});
	my $ok = 0;
	if ($ping_rc eq "0")
	{
		$ok = 1;
		$an->data->{node}{$node}{internet} = 1;
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node", value1 => $node,
		name2 => "ok",   value2 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This takes the current install manifest up rewrites it to record the user's MAC addresses selected during 
# the network remap.
sub update_install_manifest
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "update_install_manifest" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1           = $an->data->{cgi}{anvil_node1_current_ip};
	my $node1_bcn_link1 = $an->data->{conf}{node}{$node1}{set_nic}{bcn_link1};
	my $node1_bcn_link2 = $an->data->{conf}{node}{$node1}{set_nic}{bcn_link2};
	my $node1_sn_link1  = $an->data->{conf}{node}{$node1}{set_nic}{sn_link1};
	my $node1_sn_link2  = $an->data->{conf}{node}{$node1}{set_nic}{sn_link2};
	my $node1_ifn_link1 = $an->data->{conf}{node}{$node1}{set_nic}{ifn_link1};
	my $node1_ifn_link2 = $an->data->{conf}{node}{$node1}{set_nic}{ifn_link2};
	my $node2           = $an->data->{cgi}{anvil_node2_current_ip};
	my $node2_bcn_link1 = $an->data->{conf}{node}{$node2}{set_nic}{bcn_link1};
	my $node2_bcn_link2 = $an->data->{conf}{node}{$node2}{set_nic}{bcn_link2};
	my $node2_sn_link1  = $an->data->{conf}{node}{$node2}{set_nic}{sn_link1};
	my $node2_sn_link2  = $an->data->{conf}{node}{$node2}{set_nic}{sn_link2};
	my $node2_ifn_link1 = $an->data->{conf}{node}{$node2}{set_nic}{ifn_link1};
	my $node2_ifn_link2 = $an->data->{conf}{node}{$node2}{set_nic}{ifn_link2};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0014", message_variables => {
		name1  => "node1",           value1  => $node1,
		name2  => "node1_bcn_link2", value2  => $node1_bcn_link1,
		name3  => "node1_bcn_link2", value3  => $node1_bcn_link2,
		name4  => "node1_sn_link1",  value4  => $node1_sn_link1,
		name5  => "node1_sn_link2",  value5  => $node1_sn_link2,
		name6  => "node1_ifn_link1", value6  => $node1_ifn_link1,
		name7  => "node1_ifn_link2", value7  => $node1_ifn_link2,
		name8  => "node2",           value8  => $node2,
		name9  => "node2_bcn_link2", value9  => $node2_bcn_link1,
		name10 => "node2_bcn_link2", value10 => $node2_bcn_link2,
		name11 => "node2_sn_link1",  value11 => $node2_sn_link1,
		name12 => "node2_sn_link2",  value12 => $node2_sn_link2,
		name13 => "node2_ifn_link1", value13 => $node2_ifn_link1,
		name14 => "node2_ifn_link2", value14 => $node2_ifn_link2,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Read in the old one.
	my $save          = 0;
	my $in_node1      = 0;
	my $in_node2      = 0;
	my $manifest_data = $an->Get->manifest_data({manifest_uuid => $an->data->{cgi}{manifest_uuid}});
	my $new_data      = "";
	
	foreach my $line (split/\n/, $manifest_data)
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /<node name="(.*?)">/)
		{
			my $this_node = $1;
			if (($this_node =~ /node01/) ||
			    ($this_node =~ /node1/)  ||
			    ($this_node =~ /n01/)    ||
			    ($this_node =~ /n1/))
			{
				$in_node1 = 1;
				$in_node2 = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "in_node1", value1 => $in_node1,
					name2 => "in_node2", value2 => $in_node2,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif (($this_node =~ /node02/) ||
			       ($this_node =~ /node2/)  ||
			       ($this_node =~ /n02/)    ||
			       ($this_node =~ /n2/))
			{
				$in_node1 = 0;
				$in_node2 = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "in_node1", value1 => $in_node1,
					name2 => "in_node2", value2 => $in_node2,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		if ($line =~ /<\/node>/)
		{
			$in_node1 = 0;
			$in_node2 = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "in_node1", value1 => $in_node1,
				name2 => "in_node2", value2 => $in_node2,
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# See if we have a NIC.
		if ($line =~ /<interface /)
		{
			# OK, get the name and MAC.
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "in_node1",       value1 => $in_node1,
				name2 => "in_node2",       value2 => $in_node2,
				name3 => "interface line", value3 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			my $this_nic = ($line =~ /name="(.*?)"/)[0];
			my $this_mac = ($line =~ /mac="(.*?)"/)[0];
				$this_mac = "" if not $this_mac;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
				name1 => "in_node1", value1 => $in_node1,
				name2 => "in_node2", value2 => $in_node2,
				name3 => "this_nic", value3 => $this_nic,
				name4 => "this_mac", value4 => $this_mac,
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($in_node1)
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node 1 nic", value1 => $this_nic,
					name2 => "this_mac",   value2 => $this_mac,
				}, file => $THIS_FILE, line => __LINE__});
				if ($this_nic eq "bcn_link1")
				{ 
					if ($this_mac ne $node1_bcn_link1)
					{
						$save =  1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						$line =~ s/mac=".*?"/mac="$node1_bcn_link1"/;
						
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($this_nic eq "bcn_link2")
				{ 
					if ($this_mac ne $node1_bcn_link2)
					{
						$save =  1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						$line =~ s/mac=".*?"/mac="$node1_bcn_link2"/;
						
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($this_nic eq "sn_link1")
				{ 
					if ($this_mac ne $node1_sn_link1)
					{
						$save =  1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						$line =~ s/mac=".*?"/mac="$node1_sn_link1"/;
						
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($this_nic eq "sn_link2")
				{ 
					if ($this_mac ne $node1_sn_link2)
					{
						$save =  1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						$line =~ s/mac=".*?"/mac="$node1_sn_link2"/;
						
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($this_nic eq "ifn_link1")
				{ 
					if ($this_mac ne $node1_ifn_link1)
					{
						$save =  1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						$line =~ s/mac=".*?"/mac="$node1_ifn_link1"/;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($this_nic eq "ifn_link2")
				{ 
					if ($this_mac ne $node1_ifn_link2)
					{
						$save =  1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						$line =~ s/mac=".*?"/mac="$node1_ifn_link2"/;
						
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				else
				{
					# Unknown NIC.
					$an->Log->entry({log_level => 1, message_key => "log_0037", message_variables => {
						node     => "1", 
						this_nic => $this_nic, 
						line     => $line, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			elsif ($in_node2)
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node 2 nic", value1 => $this_nic,
					name2 => "this_mac",   value2 => $this_mac,
				}, file => $THIS_FILE, line => __LINE__});
				if ($this_nic eq "bcn_link1")
				{ 
					if ($this_mac ne $node2_bcn_link1)
					{
						$save =  1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						$line =~ s/mac=".*?"/mac="$node2_bcn_link1"/;
						
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($this_nic eq "bcn_link2")
				{ 
					if ($this_mac ne $node2_bcn_link2)
					{
						$save =  1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						$line =~ s/mac=".*?"/mac="$node2_bcn_link2"/;
						
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($this_nic eq "sn_link1")
				{ 
					if ($this_mac ne $node2_sn_link1)
					{
						$save =  1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						$line =~ s/mac=".*?"/mac="$node2_sn_link1"/;
						
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($this_nic eq "sn_link2")
				{ 
					if ($this_mac ne $node2_sn_link2)
					{
						$save =  1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						$line =~ s/mac=".*?"/mac="$node2_sn_link2"/;
						
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($this_nic eq "ifn_link1")
				{ 
					if ($this_mac ne $node2_ifn_link1)
					{
						$save =  1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						$line =~ s/mac=".*?"/mac="$node2_ifn_link1"/;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($this_nic eq "ifn_link2")
				{ 
					if ($this_mac ne $node2_ifn_link2)
					{
						$save =  1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
						$line =~ s/mac=".*?"/mac="$node2_ifn_link2"/;
						
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "line", value1 => $line,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				else
				{
					# Unknown NIC.
					$an->Log->entry({log_level => 1, message_key => "log_0037", message_variables => {
						node     => "2", 
						this_nic => $this_nic, 
						line     => $line, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			else
			{
				# failed to determine the node...
				$an->Log->entry({log_level => 1, message_key => "log_0038", file => $THIS_FILE, line => __LINE__});
			}
		}
		$new_data .= "$line\n";
	}
	
	# Write out new raw file, if changes were made.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "save", value1 => $save,
	}, file => $THIS_FILE, line => __LINE__});
	if ($save)
	{
		# We pretend here that we were passed in raw XML because there is already a facility to save
		# modified manifests this way.
		$an->data->{cgi}{raw}           = "true";
		$an->data->{cgi}{manifest_data} = $new_data;
		$an->ScanCore->save_install_manifest();
		$an->ScanCore->parse_install_manifest({uuid => $an->data->{cgi}{manifest_uuid}});
		
		# Tell the user.
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message-wide", replace => { 
			row	=>	"#!string!title_0157!#",
			class	=>	"body",
			message	=>	"#!string!message_0464!#",
		}});
	}
	
	return(0);
}

# This pings alteeve.ca to check for internet access.
sub verify_internet_access
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "verify_internet_access" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# If the user knows they will never be online, they may have set to hide the Internet check. In this
	# case, don't waste time checking.
	my $node1 = $an->data->{cgi}{anvil_node1_current_ip};
	my $node2 = $an->data->{cgi}{anvil_node2_current_ip};
	if (not $an->data->{sys}{install_manifest}{show}{internet_check})
	{
		# User has disabled checking for an internet connection, mark that there is no connection.
		$an->Log->entry({log_level => 2, message_key => "log_0196", file => $THIS_FILE, line => __LINE__});
		$an->data->{node}{$node1}{internet} = 0;
		$an->data->{node}{$node2}{internet} = 0;
		return(0);
	}
	
	my ($node1_online) = $an->InstallManifest->test_internet_connection({
			target   => $an->data->{cgi}{anvil_node1_current_ip}, 
			port     => $an->data->{node}{$node1}{port}, 
			password => $an->data->{cgi}{anvil_node1_current_password}
		});
	my ($node2_online) = $an->InstallManifest->test_internet_connection({
			target   => $an->data->{cgi}{anvil_node2_current_ip}, 
			port     => $an->data->{node}{$node2}{port}, 
			password => $an->data->{cgi}{anvil_node2_current_password}
		});
	
	# If the node is not online, we'll call yum with the switches to  disable all but our local repos.
	if ((not $node1_online) or (not $node2_online))
	{
		# No internet, restrict access to local only.
		$an->data->{sys}{yum_switches} = "-y --disablerepo='*' --enablerepo='striker*'";
		$an->Log->entry({log_level => 2, message_key => "log_0197", file => $THIS_FILE, line => __LINE__});
	}
	
	# I need to remember if there is Internet access or not for later downloads (web or switch to local).
	$an->data->{node}{$node1}{internet_access} = $node1_online;
	$an->data->{node}{$node2}{internet_access} = $node2_online;
	
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0022!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0022!#";
	my $message       = "";
	if (not $node1_online)
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0021!#",
		$ok            = 0;
	}
	if (not $node2_online)
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0021!#",
		$ok            = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0223!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	if (not $ok)
	{
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
			message	=>	"#!string!message_0366!#",
			row	=>	"#!string!state_0021!#",
		}});
	}
	
	return(1);
}

# This checks to make sure both nodes have a compatible OS installed.
sub verify_os
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "verify_os" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ok    = 1;
	my $node1 = $an->data->{cgi}{anvil_node1_current_ip};
	my $node2 = $an->data->{cgi}{anvil_node2_current_ip};
	my ($node1_major_version, $node1_minor_version) = $an->InstallManifest->get_node_os_version({
			target   => $an->data->{cgi}{anvil_node1_current_ip}, 
			port     => $an->data->{node}{$node1}{port}, 
			password => $an->data->{cgi}{anvil_node1_current_password},
		});
	my ($node2_major_version, $node2_minor_version) = $an->InstallManifest->get_node_os_version({
			target   => $an->data->{cgi}{anvil_node2_current_ip}, 
			port     => $an->data->{node}{$node2}{port},
			password => $an->data->{cgi}{anvil_node2_current_password},
		});
	$node1_major_version = 0 if not defined $node1_major_version;
	$node1_minor_version = 0 if not defined $node1_minor_version;
	$node2_major_version = 0 if not defined $node2_major_version;
	$node2_minor_version = 0 if not defined $node2_minor_version;
	
	my $say_node1_os = $an->data->{node}{$node1}{os}{brand} =~ /Red Hat Enterprise Linux Server/ ? "RHEL" : $an->data->{node}{$node1}{os}{brand};
	my $say_node2_os = $an->data->{node}{$node2}{os}{brand} =~ /Red Hat Enterprise Linux Server/ ? "RHEL" : $an->data->{node}{$node2}{os}{brand};
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "$say_node1_os $an->data->{node}{$node1}{os}{version}";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "$say_node2_os $an->data->{node}{$node2}{os}{version}";
	if ($node1_major_version != 6)
	{
		$node1_class   = "highlight_bad_bold";
		$node1_message = "--" if $node1_message eq "0.0";
		$ok            = 0;
	}
	if ($node2_major_version != 6)
	{
		$node2_class   = "highlight_bad_bold";
		$node2_message = "--" if $node2_message eq "0.0";
		$ok            = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0220!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	if (not $ok)
	{
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-failed", replace => { message => "#!string!message_0362!#" }});
	}
	
	return($ok);
}

# This checks to see if perl is installed on the nodes and installs it if not.
sub verify_perl_is_installed
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "verify_perl_is_installed" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1      = $an->data->{cgi}{anvil_node1_current_ip};
	my $node2      = $an->data->{cgi}{anvil_node2_current_ip};
	my ($node1_ok) = $an->InstallManifest->verify_perl_is_installed_on_node({
			target   => $an->data->{cgi}{anvil_node1_current_ip}, 
			port     => $an->data->{node}{$node1}{port}, 
			password => $an->data->{cgi}{anvil_node1_current_password},
		});
	my ($node2_ok) = $an->InstallManifest->verify_perl_is_installed_on_node({
			target   => $an->data->{cgi}{anvil_node2_current_ip}, 
			port     => $an->data->{node}{$node2}{port}, 
			password => $an->data->{cgi}{anvil_node2_current_password},
		});
	
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0017!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0017!#";
	my $message       = "";
	if ($node1_ok eq "2")
	{
		# Installed
		$node1_message = "#!string!state_0035!#",
	}
	elsif (not $node1_ok)
	{
		# Not installed/couldn't install
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0036!#",
		$ok            = 0;
	}
	if ($node2_ok eq "2")
	{
		# Installed
		$node2_message = "#!string!state_0035!#",
	}
	elsif (not $node2_ok)
	{
		# Not installed/couldn't install
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0036!#",
		$ok            = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0243!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	if (not $ok)
	{
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
			message	=>	"#!string!message_0386!#",
			row	=>	"#!string!state_0037!#",
		}});
	}
	
	return($ok);
}

# This will check to see if perl is installed and, if it's not, it will try to install it.
sub verify_perl_is_installed_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "verify_perl_is_installed_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### NOTE: Called 'node' for compatibility
	my $node     = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node", value1 => $node, 
		name2 => "port", value2 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Set to '1' if perl was found, '0' if it wasn't found and couldn't be
	# installed, set to '2' if installed successfully.
	my $ok = 1;
	my $shell_call = "
if [ -e '".$an->data->{path}{perl}."' ]; 
then
    ".$an->data->{path}{echo}." striker:ok
else
    ".$an->data->{path}{yum}." ".$an->data->{sys}{yum_switches}." install perl;
    if [ -e '".$an->data->{path}{perl}."' ];
    then
        ".$an->data->{path}{echo}." striker:installed
    else
        ".$an->data->{path}{echo}." striker:failed
    fi
fi";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node",       value1 => $node,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line eq "striker:ok")
		{
			$ok = 1;
		}
		if ($line eq "striker:installed")
		{
			$ok = 2;
		}
		if ($line eq "striker:failed")
		{
			$ok = 0;
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node", value1 => $node,
		name2 => "ok",   value2 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

1;

#####################

# 	my $self      = shift;
# 	my $parameter = shift;
# 	my $an        = $self->parent;
# 	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
# 	
# 	### NOTE: Called 'node' for compatibility
# 	my $node     = $parameter->{target}   ? $parameter->{target}   : "";
# 	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
# 	my $password = $parameter->{password} ? $parameter->{password} : "";
# 	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
# 		name1 => "node", value1 => $node, 
# 		name2 => "port", value2 => $port, 
# 	}, file => $THIS_FILE, line => __LINE__});
# 	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
# 		name1 => "password", value1 => $password, 
# 	}, file => $THIS_FILE, line => __LINE__});
	
#####################

# 	my $node1 = $an->data->{cgi}{anvil_node1_current_ip};
# 	my $node2 = $an->data->{cgi}{anvil_node2_current_ip};
# 
# 	my () = $an->InstallManifest->({
# 			target   => $an->data->{cgi}{anvil_node1_current_ip}, 
# 			port     => $an->data->{node}{$node1}{port}, 
# 			password => $an->data->{cgi}{anvil_node1_current_password},
# 		});
# 	my () = $an->InstallManifest->({
# 			target   => $an->data->{cgi}{anvil_node2_current_ip}, 
# 			port     => $an->data->{node}{$node2}{port}, 
# 			password => $an->data->{cgi}{anvil_node2_current_password},
# 		});
