package AN::Tools::InstallManifest;
# 
# This package is used for things specific to RHEL 6's cman + rgmanager cluster stack.
# 
# TODO: 
# - Migrate all of the;
# target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
# port     => $an->data->{sys}{anvil}{node1}{use_port}, 
# password => $an->data->{sys}{anvil}{node1}{password},
# - to;
# target   => $an->data->{sys}{anvil}{$node_key}{use_ip}, 
# port     => $an->data->{sys}{anvil}{$node_key}{use_port}, 
# password => $an->data->{sys}{anvil}{$node_key}{use_password}, 
# - Update these as the password is changed and the node is rebooted.

use strict;
use warnings;
use IO::Handle;

our $VERSION  = "0.1.001";
my $THIS_FILE = "InstallManifest.pm";

### NOTE: There are all deprecated
### Methods;
# backup_files
# backup_files_on_node
# calculate_storage_pool_sizes
# check_blkid_partition
# check_config_for_anvil
# check_connection
# check_drbd_if_force_primary_is_needed
# check_device_for_drbd_metadata
# check_fencing_on_node
# check_for_drbd_metadata
# check_if_in_cluster
# check_local_repo
# check_storage
# configure_clvmd
# configure_cman
# configure_daemons
# configure_daemons_on_node
# configure_gfs2
# configure_ipmi
# configure_ipmi_on_node
# configure_network
# configure_network_on_node
# configure_ntp
# configure_ntp_on_node
# configure_scancore
# configure_scancore_on_node
# configure_selinux
# configure_selinux_on_node
# configure_ssh
# configure_storage_stage1
# configure_storage_stage2
# configure_storage_stage3
# confirm_install_manifest_run
# connect_to_node
# create_lvm_vgs
# create_lvm_pvs
# create_partition_on_node
# create_shared_lv
# do_drbd_attach_on_node
# do_drbd_connect_on_node
# do_drbd_primary_on_node
# do_node_reboot
# drbd_first_start
# enable_tools
# enable_tools_on_node
# generate_cluster_conf
# generate_drbd_config_files
# generate_lvm_conf
# get_chkconfig_data
# get_daemon_state
# get_installed_package_list
# get_node_os_version
# get_node_rsa_public_key
# get_partition_data
# get_partition_data_from_node
# get_storage_pool_partitions
# install_programs
# install_programs_on_node
# map_network
# map_network_on_node
# parse_script_line
# populate_authorized_keys_on_node
# populate_known_hosts_on_node
# read_cluster_conf
# read_drbd_config_on_node
# read_drbd_resource_files
# reboot_nodes
# read_lvm_conf_on_node
# register_with_rhn
# register_node_with_rhn
# remove_priority_from_node
# restart_rgmanager_service
# run_new_install_manifest
# sanity_check_manifest_answers
# set_chkconfig
# set_daemon_state
# set_password_on_node
# set_ricci_password
# set_root_password
# setup_drbd_on_node
# setup_gfs2
# setup_gfs2_on_node
# setup_lvm_pv_and_vgs
# show_existing_install_manifests
# show_summary_manifest
# summarize_build_plan
# start_clvmd_on_node
# start_cman
# start_cman_on_node
# stop_drbd
# stop_drbd_on_node
# stop_service_on_node
# test_internet_connection
# update_install_manifest
# update_target_node
# update_nodes
# verify_drbd_resources_are_connected
# verify_internet_access
# verify_os
# verify_perl_is_installed
# verify_perl_is_installed_on_node
# watch_clustat
# write_cluster_conf
# write_lvm_conf_on_node
# _do_os_update

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

# This creates a backup of various original things into /root/backups.
sub backup_files
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "backup_files" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	$an->InstallManifest->backup_files_on_node({
			node     => $an->data->{sys}{anvil}{node1}{name},
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		}) if not $an->data->{node}{node1}{has_servers};
	$an->InstallManifest->backup_files_on_node({
			node     => $an->data->{sys}{anvil}{node2}{name},
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
		}) if not $an->data->{node}{node2}{has_servers};
	
	# There are no failure modes yet.
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0073!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0073!#";
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0254!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	return(0);
}

# This does the work of actually backing up files on a node.
sub backup_files_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "backup_files_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Create the backup directory if it doesn't exist yet.
	my $shell_call = "
if [ -e '".$an->data->{path}{nodes}{backups}."' ];
then 
    ".$an->data->{path}{echo}." \"Backup directory exist\";
else 
    ".$an->data->{path}{'mkdir'}." -p ".$an->data->{path}{nodes}{backups}."; 
fi";
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
	
	# Backup the original network config
	$shell_call = "
if [ -e '".$an->data->{path}{nodes}{backups}."/network-scripts' ];
then 
    ".$an->data->{path}{echo}." \"Network configuration files previously backed up\";
else 
    ".$an->data->{path}{rsync}." -av ".$an->data->{path}{nodes}{network_scripts}." ".$an->data->{path}{nodes}{backups}."/;
fi";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Backup the original SSH config
	$shell_call = "
if [ -e '".$an->data->{path}{nodes}{backups}."/.ssh' ];
then 
    ".$an->data->{path}{echo}." \"SSH configuration files previously backed up\";
else 
    ".$an->data->{path}{rsync}." -av /root/.ssh ".$an->data->{path}{nodes}{backups}."/;
fi";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	# Backup DRBD if it exists.
	$shell_call = "
if [ -e '".$an->data->{path}{nodes}{drbd}."' ] && [ ! -e '".$an->data->{path}{nodes}{backups}."/drbd.d' ];
then 
    ".$an->data->{path}{rsync}." -av ".$an->data->{path}{nodes}{drbd}." ".$an->data->{path}{nodes}{backups}."/; 
else 
    ".$an->data->{path}{echo}." \"DRBD backup not needed\"; 
fi";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	# Backup lvm.conf.
	$shell_call = "
if [ ! -e '".$an->data->{path}{nodes}{backups}."/lvm.conf' ];
then 
    ".$an->data->{path}{rsync}." -av ".$an->data->{path}{nodes}{lvm_conf}." ".$an->data->{path}{nodes}{backups}."/; 
else 
    ".$an->data->{path}{echo}." \"LVM previously backed up, skipping.\"; 
fi";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	# Backup cluster.conf.
	$shell_call = "
if [ ! -e '".$an->data->{path}{nodes}{backups}."/cluster.conf' ];
then 
    ".$an->data->{path}{rsync}." -av ".$an->data->{path}{nodes}{cluster_conf}." ".$an->data->{path}{nodes}{backups}."/; 
else 
    ".$an->data->{path}{echo}." \"cman previously backed up, skipping.\"; 
fi";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	# Backup fstab.
	$shell_call = "
if [ ! -e '".$an->data->{path}{nodes}{backups}."/fstab' ];
then 
    ".$an->data->{path}{rsync}." -av ".$an->data->{path}{nodes}{fstab}." ".$an->data->{path}{nodes}{backups}."/; 
else 
    ".$an->data->{path}{echo}." \"fstab previously backed up, skipping.\"; 
fi";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	# Backup shadow.
	$shell_call = "
if [ ! -e '".$an->data->{path}{nodes}{backups}."/shadow' ];
then 
    ".$an->data->{path}{rsync}." -av ".$an->data->{path}{nodes}{shadow}." ".$an->data->{path}{nodes}{backups}."/; 
else 
    ".$an->data->{path}{echo}." \"shadow previously backed up, skipping.\"; 
fi";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	return(0);
}

# This calculates the sizes of the partitions to create, or selects the size based on existing partitions if 
# found.
sub calculate_storage_pool_sizes
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "calculate_storage_pool_sizes" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# These will be set to the lower of the two nodes.
	my $node1      = $an->data->{sys}{anvil}{node1}{name};
	my $node2      = $an->data->{sys}{anvil}{node2}{name};
	my $pool1_size = "";
	my $pool2_size = "";
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node1}::pool1::existing_size", value1 => $an->data->{node}{$node1}{pool1}{existing_size}." (".$an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node1}{pool1}{existing_size} }).")",
		name2 => "node::${node2}::pool1::existing_size", value2 => $an->data->{node}{$node2}{pool1}{existing_size}." (".$an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node2}{pool1}{existing_size} }).")",
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node1}{pool1}{existing_size}) or ($an->data->{node}{$node2}{pool1}{existing_size}))
	{
		# See which I have.
		if (($an->data->{node}{$node1}{pool1}{existing_size}) && ($an->data->{node}{$node2}{pool1}{existing_size}))
		{
			# Both, OK. Are they the same?
			if ($an->data->{node}{$node1}{pool1}{existing_size} eq $an->data->{node}{$node2}{pool1}{existing_size})
			{
				# Golden
				$pool1_size = $an->data->{node}{$node1}{pool1}{existing_size};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "pool1_size", value1 => $pool1_size,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Nothing we can do but warn the user.
				$pool1_size = $an->data->{node}{$node1}{pool1}{existing_size};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "pool1_size", value1 => $pool1_size,
				}, file => $THIS_FILE, line => __LINE__});
				if ($an->data->{node}{$node1}{pool1}{existing_size} < $an->data->{node}{$node2}{pool1}{existing_size})
				{
					$pool1_size = $an->data->{node}{$node2}{pool1}{existing_size};
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "pool1_size", value1 => $pool1_size,
					}, file => $THIS_FILE, line => __LINE__});
				}
				my $message = $an->String->get({key => "message_0387", variables => { 
						node1_name	=>	$an->data->{sys}{anvil}{node1}{short_name},
						node1_hr_size	=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node1}{pool1}{existing_size} }),
						node1_byte_size	=>	$an->Readable->comma($an->data->{node}{$node1}{pool1}{existing_size}),
						node2_name	=>	$an->data->{sys}{anvil}{node2}{short_name},
						node2_hr_size	=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node2}{pool1}{existing_size} }),
						node2_byte_size	=>	$an->Readable->comma($an->data->{node}{$node2}{pool1}{existing_size}),
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "pool1_size",                         value1 => $pool1_size,
				name2 => "cgi::anvil_storage_pool1_byte_size", value2 => $an->data->{cgi}{anvil_storage_pool1_byte_size},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($an->data->{node}{$node2}{pool1}{existing_size})
		{
			# Node 1 isn't partitioned yet but node 2 is.
			$pool1_size                                    = $an->data->{node}{$node2}{pool1}{existing_size};
			$an->data->{cgi}{anvil_storage_pool1_byte_size} = $an->data->{node}{$node2}{pool1}{existing_size};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "pool1_size",                         value1 => $pool1_size,
				name2 => "cgi::anvil_storage_pool1_byte_size", value2 => $an->data->{cgi}{anvil_storage_pool1_byte_size},
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		$an->data->{cgi}{anvil_storage_pool1_byte_size} = $pool1_size;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
	if (($an->data->{node}{$node1}{pool2}{existing_size}) or ($an->data->{node}{$node2}{pool2}{existing_size}))
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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

	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node1}::disk::${node1_disk}::free_space::size", value1 => $an->data->{node}{$node1}{disk}{$node1_disk}{free_space}{size}." (".$an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node1}{disk}{$node1_disk}{free_space}{size} }).")",
		name2 => "node::${node2}::disk::${node2_disk}::free_space::size", value2 => $an->data->{node}{$node2}{disk}{$node2_disk}{free_space}{size}." (".$an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node2}{disk}{$node2_disk}{free_space}{size} }).")",
	}, file => $THIS_FILE, line => __LINE__});

	
	my $smallest_free_size = $an->data->{node}{$node1}{disk}{$node1_disk}{free_space}{size};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "smallest_free_size", value1 => $smallest_free_size." (".$an->Readable->bytes_to_hr({'bytes' => $smallest_free_size }).")",
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{node}{$node1}{disk}{$node1_disk}{free_space}{size} > $an->data->{node}{$node2}{disk}{$node2_disk}{free_space}{size})
	{
		$smallest_free_size = $an->data->{node}{$node2}{disk}{$node2_disk}{free_space}{size};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "smallest_free_size", value1 => $smallest_free_size,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# If both are "calculate", do so. If only one is "calculate", use the available free size.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "pool1_size", value1 => $pool1_size,
		name2 => "pool2_size", value2 => $pool2_size,
	}, file => $THIS_FILE, line => __LINE__});
	if (($pool1_size eq "calculate") or ($pool2_size eq "calculate"))
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
					name1 => "pool1_size", value1 => $pool1_size." (".$an->Readable->bytes_to_hr({'bytes' => $pool1_size }).")",
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
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
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
						# Round down a MiB, as the next stage will round up a bit if 
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

# This calls 'blkid' and parses the output for the given device, if returned.
sub check_blkid_partition
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "check_blkid_partition" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $device   = $parameter->{device}   ? $parameter->{device}   : "";
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "device", value1 => $device, 
		name2 => "node",   value2 => $node, 
		name3 => "target", value3 => $target, 
		name4 => "port",   value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $uuid       = "";
	my $type       = "";
	my $shell_call = $an->data->{path}{blkid}." -c /dev/null $device";
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
		
		if ($line =~ /^$device: /)
		{
			$uuid  = ($line =~ /UUID="(.*?)"/)[0];
			$type  = ($line =~ /TYPE="(.*?)"/)[0];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "uuid", value1 => $uuid,
				name2 => "type", value2 => $type,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "type", value1 => $type,
	}, file => $THIS_FILE, line => __LINE__});
	return($type);
}

# Check to see if the created Anvil! is in the configuration yet.
sub check_config_for_anvil
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "check_config_for_anvil" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_configured = 0;
	my $anvil_uuid       = "";
	my $anvil_data       = $an->ScanCore->get_anvils();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil_data", value1 => $anvil_data,
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $hash_ref (@{$anvil_data})
	{
		# Pull out the name and UUID.
		my $this_anvil_name = $hash_ref->{anvil_name};
		my $this_anvil_uuid = $hash_ref->{anvil_uuid};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "cgi::anvil_name", value1 => $an->data->{cgi}{anvil_name},
			name2 => "this_anvil_name", value2 => $this_anvil_name,
			name3 => "this_anvil_uuid", value3 => $this_anvil_uuid,
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{anvil_name} eq $this_anvil_name)
		{
			# Match!
			$anvil_configured = 1;
			$anvil_uuid       = $this_anvil_uuid;
			$an->Log->entry({log_level => 2, message_key => "log_0041", file => $THIS_FILE, line => __LINE__});
			last;
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "anvil_configured", value1 => $anvil_configured,
		name2 => "anvil_uuid",       value2 => $anvil_uuid,
	}, file => $THIS_FILE, line => __LINE__});
	return($anvil_configured, $anvil_uuid);
}

# This makes sure we have access to both nodes.
sub check_connection
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "check_connection" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my ($node1_access) = $an->Check->access({
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		});
	my ($node2_access) = $an->Check->access({
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
		});
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
	if ((not $node1_access) or (not $node2_access))
	{
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-failed", replace => { message => "#!string!message_0361!#" }});
		$access = 0;
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "access", value1 => $access,
	}, file => $THIS_FILE, line => __LINE__});
	return($access);
}

# This uses node 1 to check the Connected disk states of the resources are both Inconsistent.
sub check_drbd_if_force_primary_is_needed
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "check_drbd_if_force_primary_is_needed" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return_code = 0;
	my $found_r0    = 0;
	my $force_r0    = 0;
	my $force_r1    = 0;
	my $found_r1    = 0;
	my $shell_call  = $an->data->{path}{cat}." ".$an->data->{path}{proc_drbd};
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^0: /)
		{
			# Resource found, check disk state, but unless it is "Diskless", we're already 
			# attached because unattached disks cause the entry
			if ($line =~ /ds:(.*?)\/(.*?)\s/)
			{
				my $node1_ds = $1;
				my $node2_ds = $2;
				   $found_r0 = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node1_ds", value1 => $node1_ds,
					name2 => "node2_ds", value2 => $node2_ds,
				}, file => $THIS_FILE, line => __LINE__});
				if (($node1_ds =~ /Inconsistent/i) && ($node2_ds =~ /Inconsistent/i))
				{
					# Force
					$force_r0 = 1;
					$an->Log->entry({log_level => 2, message_key => "log_0087", message_variables => { resource => "r0" }, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Don't force
					$an->Log->entry({log_level => 2, message_key => "log_0088", message_variables => { resource => "r0" }, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		if ($line =~ /^1: /)
		{
			# Resource found, check disk state, but unless it is "Diskless", we're already 
			# attached because unattached disks cause the entry
			if ($line =~ /ds:(.*?)\/(.*?)\s/)
			{
				my $node1_ds = $1;
				my $node2_ds = $2;
				   $found_r1 = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node1_ds", value1 => $node1_ds,
					name2 => "node2_ds", value2 => $node2_ds,
				}, file => $THIS_FILE, line => __LINE__});
				if (($node1_ds =~ /Inconsistent/i) && ($node2_ds =~ /Inconsistent/i))
				{
					# Force
					$force_r0 = 1;
					$an->Log->entry({log_level => 2, message_key => "log_0087", message_variables => { resource => "r1" }, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Don't force
					$an->Log->entry({log_level => 2, message_key => "log_0088", message_variables => { resource => "r1" }, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "found_r0", value1 => $found_r0,
		name2 => "found_r1", value2 => $found_r1,
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $found_r0) or (($an->data->{cgi}{anvil_storage_pool2_byte_size}) && (not $found_r1)))
	{
		# One or both of the resources was not found.
		$return_code = 1;
		$an->Log->entry({log_level => 1, message_key => "log_0089", file => $THIS_FILE, line => __LINE__});
	}
	
	# 0 == Both resources found, safe to proceed
	# 1 == One or both of the resources not found
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "force_r0", value1 => $force_r0,
		name2 => "force_r1", value2 => $force_r1,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code, $force_r0, $force_r1);
}

# This looks on a given device for DRBD metadata
sub check_device_for_drbd_metadata
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "check_device_for_drbd_metadata" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $device   = $parameter->{device}   ? $parameter->{device}   : "";
	my $resource = $parameter->{resource} ? $parameter->{resource} : "";
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "device",   value1 => $device, 
		name2 => "resource", value2 => $resource, 
		name3 => "node",     value3 => $node, 
		name4 => "target",   value4 => $target, 
		name5 => "port",     value5 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $is_drbd    = 0;
	my $shell_call = $an->data->{path}{drbdmeta}." --force 0 v08 $device internal dump-md; ".$an->data->{path}{echo}." return_code:\$?";
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
		
		if ($line =~ /^return_code:(\d+)/)
		{
			my $return_code = $1;
			# 0   == drbd md found
			# 10  == too small for DRBD
			# 20  == device not found
			# 255 == device exists but has no metadata
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($return_code eq "0")
			{
				# Metadata found.
				$is_drbd = 1;
				$an->Log->entry({log_level => 2, message_key => "log_0165", message_variables => {
					node   => $node, 
					device => $device, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# If we need to, wipe the MD.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "is_drbd",                             value1 => $is_drbd,
		name2 => "node::${node}::wipe-md::${resource}", value2 => $an->data->{node}{$node}{'wipe-md'}{$resource},
	}, file => $THIS_FILE, line => __LINE__});
	if (($is_drbd) eq ($an->data->{node}{$node}{'wipe-md'}{$resource}))
	{
		# Set 'is_drbd' back to 0 so that a new MD is force-created.
		$is_drbd = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "is_drbd", value1 => $is_drbd, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "is_drbd", value1 => $is_drbd,
	}, file => $THIS_FILE, line => __LINE__});
	return($is_drbd);
}

# This calls 'check_fence' on the node to verify if fencing is working.
sub check_fencing_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "check_fencing_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $message = "";
	my $ok      = 1;
	my $shell_call = $an->data->{path}{fence_check}." -f; ".$an->data->{path}{echo}." return_code:\$?";
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
		
		if ($line =~ /return_code:(\d+)/)
		{
			# 0 == OK
			# 5 == Failed
			my $return_code = $1;
			if ($return_code eq "0")
			{
				# Passed
				$an->Log->entry({log_level => 2, message_key => "log_0118", file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Failed
				$an->Log->entry({log_level => 1, message_key => "log_0119", message_variables => { return_code => $return_code }, file => $THIS_FILE, line => __LINE__});
				$ok = 0;
			}
		}
		else
		{
			$message .= "$line<br />\n";
		}
	}
	$message =~ s/<br \/>\n$//;
	
	# If it failed, sleep for a minute and try again.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok, 
	}, file => $THIS_FILE, line => __LINE__});
	if (not $ok)
	{
		sleep 60;
		$message = "";
		$ok      = 1;
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
			
			if ($line =~ /return_code:(\d+)/)
			{
				# 0 == OK
				# 5 == Failed
				my $return_code = $1;
				if ($return_code eq "0")
				{
					# Passed
					$an->Log->entry({log_level => 2, message_key => "log_0118", file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Failed
					$an->Log->entry({log_level => 1, message_key => "log_0119", message_variables => { return_code => $return_code }, file => $THIS_FILE, line => __LINE__});
					$ok = 0;
				}
			}
			else
			{
				$message .= "$line<br />\n";
			}
		}
		$message =~ s/<br \/>\n$//;
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok, $message);
}

# This checks the disk for DRBD metadata
sub check_for_drbd_metadata
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "check_for_drbd_metadata" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $device   = $parameter->{device}   ? $parameter->{device}   : "";
	my $resource = $parameter->{resource} ? $parameter->{resource} : "";
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "device",   value1 => $device, 
		name2 => "resource", value2 => $resource, 
		name3 => "node",     value3 => $node, 
		name4 => "target",   value4 => $target, 
		name5 => "port",     value5 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	return(3) if not $device;
	
	# I do both checks because blkid tells me what's on the partition, but if there is something on top 
	# of DRBD, it will report that instead, so it can't be entirely trusted. If the 'blkid' returns type
	# 'LVM2_member' but it is also 'is_drbd', then it is already setup.
	my ($type) = $an->InstallManifest->check_blkid_partition({
			node     => $node, 
			target   => $target, 
			port     => $port, 
			password => $password,
			device   => $device,
		});
	my ($is_drbd) = $an->InstallManifest->check_device_for_drbd_metadata({
			node     => $node, 
			target   => $target, 
			port     => $port, 
			password => $password,
			device   => $device,
			resource => $resource,
		});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "type",    value1 => $type,
		name2 => "is_drbd", value2 => $is_drbd,
	}, file => $THIS_FILE, line => __LINE__});
	my $return_code = 255;
	### blkid now returns no type for DRBD.
	if (($type eq "drbd") or ($is_drbd))
	{
		# Already has meta-data, nothing else to do.
		$return_code = 1;
		$an->Log->entry({log_level => 2, message_key => "log_0165", message_variables => {
			node   => $node, 
			device => $device, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($type)
	{
		# WHAT? Not safe to proceed...
		$return_code = 4;
		$an->Log->entry({log_level => 1, message_key => "log_0166", message_variables => {
			node   => $node, 
			device => $device, 
			type   => $type, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# These variables will be used in the 'message_0433' string.
		$an->data->{drive_signature_found}{device} = $device;
		$an->data->{drive_signature_found}{type}   = $type;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "drive_signature_found::device", value1 => $an->data->{drive_signature_found}{device},
			name2 => "drive_signature_found::type",   value2 => $an->data->{drive_signature_found}{type},
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Make sure there is a device at all
		$an->Log->entry({log_level => 2, message_key => "log_0167", message_variables => {
			node   => $node, 
			device => $device
		}, file => $THIS_FILE, line => __LINE__});
		my ($disk, $partition) = ($device =~ /\/dev\/(\D+)(\d)/);
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node}::disk::${disk}::partition::${partition}::size", value1 => $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{size},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{size})
		{
			# It exists, so we can assume it has no DRBD metadata or anything else.
			$an->Log->entry({log_level => 2, message_key => "log_0168", file => $THIS_FILE, line => __LINE__});
			my $resource = "";
			if ($device eq $an->data->{node}{$node}{pool1}{device})
			{
				$resource = "r0";
			}
			elsif ($device eq $an->data->{node}{$node}{pool2}{device})
			{
				$resource = "r1";
			}
			else
			{
				# The device doesn't match either resource...
				$return_code = 5;
			}
			if ($resource)
			{
				$an->Log->entry({log_level => 2, message_key => "log_0171", message_variables => {
					node     => $node, 
					device   => $device, 
					resource => $resource, 
				}, file => $THIS_FILE, line => __LINE__});
				my $return_code = 255;
				my $shell_call  = $an->data->{path}{nodes}{drbdadm}." -- --force create-md $resource; ".$an->data->{path}{echo}." return_code:\$?";
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
					
					if ($line =~ /^return_code:(\d+)/)
					{
						# 0 == Success
						# 3 == Configuration not found.
						$return_code = $1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "return_code", value1 => $return_code,
						}, file => $THIS_FILE, line => __LINE__});
						if (not $return_code)
						{
							$return_code = 0;
						}
						elsif ($return_code eq "3")
						{
							# Metadata creation failed.
							$an->Log->entry({log_level => 1, message_key => "log_0169", message_variables => {
								node     => $node, 
								resource => $resource
							}, file => $THIS_FILE, line => __LINE__});
							$return_code = 6;
						}
					}
					if ($line =~ /drbd meta data block successfully created/)
					{
						$an->Log->entry({log_level => 2, message_key => "log_0170", file => $THIS_FILE, line => __LINE__});
						$return_code = 0;
					}
				}
			}
		}
		else
		{
			# Partition wasn't found at all.
			$return_code = 2;
		}
	}
	
	# 0 = Created
	# 1 = Already had meta-data, nothing done
	# 2 = Partition not found
	# 3 = No device passed.
	# 4 = Foreign signature found on device
	# 5 = Device doesn't match to a DRBD resource
	# 6 = DRBD resource not defined
	# 7 = N/A (no pool 2), set by the caller
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# See if the node is in a cluster already. If so, we'll set a flag to block reboots if needed.
sub check_if_in_cluster
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "check_if_in_cluster" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $shell_call = "
if [ -e '".$an->data->{path}{initd}."/cman' ];
then 
    ".$an->data->{path}{initd}."/cman status; ".$an->data->{path}{echo}." return_code:\$?; 
else 
    ".$an->data->{path}{echo}." 'not in a cluster'; 
fi";
	# return_code == 0; in a cluster
	# return_code == 3; NOT in a cluster
	foreach my $node_key ("node1", "node2")
	{
		my $node                                     = $an->data->{sys}{anvil}{$node_key}{name};
		my $target                                   = $an->data->{sys}{anvil}{$node_key}{use_ip};
		my $port                                     = $an->data->{sys}{anvil}{$node_key}{use_port};
		my $password                                 = $an->data->{sys}{anvil}{$node_key}{password};
		   $an->data->{node}{$node}{in_cluster}      = 0;
		   $an->data->{node}{$node}{has_servers}     = 0;
		   $an->data->{node}{$node_key}{has_servers} = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
			name1 => "node_key",   value1 => $node_key,
			name2 => "node",       value2 => $node,
			name3 => "target",     value3 => $target,
			name4 => "port",       value4 => $port,
			name5 => "shell_call", value5 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
			name1 => "password", value1 => $password,
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
			
			if ($line =~ /return_code:(\d+)/)
			{
				my $return_code = $1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node",        value1 => $an->data->{sys}{anvil}{$node_key}{use_ip},
					name2 => "return_code", value2 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
				if ($return_code eq "0")
				{
					# It is in a cluster.
					$an->data->{node}{$node}{in_cluster} = 1;
				}
			}
			else
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node", value1 => $an->data->{sys}{anvil}{$node_key}{use_ip},
					name2 => "line", value2 => $line,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# If we're in a cluster, see if any servers are runnning. If there are any on this node, 
		# we'll not touch this machine.
		if ($an->data->{node}{$node}{in_cluster})
		{
			my $shell_call = $an->data->{path}{virsh}." list --all";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "target",     value1 => $target,
				name2 => "port",       value2 => $port,
				name3 => "shell_call", value3 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
				name1 => "password", value1 => $password,
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
				
				if ($line =~ /^(\d+) (\S.*?) running/)
				{
					# Server is running, don't touch this node!
					$an->data->{node}{$node}{has_servers}     = 1;
					$an->data->{node}{$node_key}{has_servers} = 1;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "node::${node}::has_servers",     value1 => $an->data->{node}{$node}{has_servers}, 
						name2 => "node::${node_key}::has_servers", value2 => $an->data->{node}{$node_key}{has_servers}, 
					}, file => $THIS_FILE, line => __LINE__});
					last;
				}
			}
		}
	}
	
	# If either are running a server, report to the user that we won't touch that node.
	if (($an->data->{node}{node1}{has_servers}) or ($an->data->{node}{node1}{has_servers}))
	{
		my $node1_class   = "highlight_good_bold";
		my $node1_message = $an->String->get({key => "state_0131"});
		my $node2_class   = "highlight_good_bold";
		my $node2_message = $an->String->get({key => "state_0131"});
		if ($an->data->{node}{node1}{has_servers})
		{
			$node1_class   = "highlight_warning_bold";
			$node1_message = $an->String->get({key => "state_0132"});
		}
		if ($an->data->{node}{node2}{has_servers})
		{
			$node2_class   = "highlight_warning_bold";
			$node2_message = $an->String->get({key => "state_0132"});
		}
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
			row		=>	"#!string!row_0333!#",
			node1_class	=>	$node1_class,
			node1_message	=>	$node1_message,
			node2_class	=>	$node2_class,
			node2_message	=>	$node2_message,
		}});
		
		# Show a note reminding the user to update their manifest, if needed, before proceeding.
		if (not $an->data->{cgi}{perform_install})
		{
			print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
				row     => "#!string!row_0334!#",
				message => "#!string!explain_0238!#",
			}});
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
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "check_local_repo" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Call the gather system info tool to get the BCN and IFN IPs.
	my $shell_call = $an->data->{path}{'call_gather-system-info'};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or $an->Alert->error({title_key => "error_title_0020", message_key => "error_message_0022", message_variables => { shell_call => $shell_call, error => $! }, code => 30, file => $THIS_FILE, line => __LINE__});
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
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "check_storage" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ok    = 1;
	my $node1 = $an->data->{sys}{anvil}{node1}{name};
	my $node2 = $an->data->{sys}{anvil}{node2}{name};
	my ($node1_disk) = $an->InstallManifest->get_partition_data({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		});
	my ($node2_disk) = $an->InstallManifest->get_partition_data({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
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
		name3 => "node1_disk_size", value3 => $node1_disk_size." (".$an->Readable->bytes_to_hr({'bytes' => $node1_disk_size }).")",
		name4 => "node2_disk_size", value4 => $node2_disk_size." (".$an->Readable->bytes_to_hr({'bytes' => $node2_disk_size }).")",
	}, file => $THIS_FILE, line => __LINE__});
	
	# Now I need to know which partitions I will use for pool 1 and 2. Only then can I sanity check space
	# needed. If one node has the partitions already in place, then that will determine the other node's
	# partition size regardless of anything else. This will set:
	$an->InstallManifest->get_storage_pool_partitions();
	
	# Now we can calculate partition sizes.
	$an->InstallManifest->calculate_storage_pool_sizes();
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::pool1_shrunk", value1 => $an->data->{sys}{pool1_shrunk},
	}, file => $THIS_FILE, line => __LINE__});
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
		name1 => "cgi::anvil_storage_pool1_byte_size", value1 => $an->data->{cgi}{anvil_storage_pool1_byte_size}." (".$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool1_byte_size} }).")",
		name2 => "cgi::anvil_storage_pool2_byte_size", value2 => $an->data->{cgi}{anvil_storage_pool2_byte_size}." (".$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool2_byte_size} }).")",
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
			pool1_size	=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool1_byte_size}}),
			pool2_device	=>	$an->data->{cgi}{anvil_storage_pool2_byte_size} ? $an->data->{node}{$node1}{pool2}{disk}.$an->data->{node}{$node1}{pool2}{partition}        : "--",
			pool2_size	=>	$an->data->{cgi}{anvil_storage_pool2_byte_size} ? $an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool2_byte_size} }) : "--",
			media_size	=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_media_library_byte_size} }),
		}});
	my $node2_class   = "highlight_good_bold";
	my $node2_message = $an->String->get({key => "state_0054", variables => { 
			pool1_device	=>	$an->data->{node}{$node2}{pool1}{disk}.$an->data->{node}{$node2}{pool1}{partition},
			pool1_size	=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool1_byte_size}}),
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

# This configures clustered LVM on each node.
sub configure_clvmd
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_clvmd" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# This will read in the existing lvm.conf on both nodes and, if either has a custom filter, preserve
	# it and use it on the peer. If this '1', then a custom filter was found on both nodes and the do not
	# match.
	my $ok = 1;
	my ($generate_return_code) = $an->InstallManifest->generate_lvm_conf();
	# Return codes:
	# 0 = OK
	# 1 = Both nodes have different and custom filter lines.
	# 2 = Read failed.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "generate_return_code", value1 => $generate_return_code,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "lvm.conf", value1 => $an->data->{sys}{lvm_conf},
	}, file => $THIS_FILE, line => __LINE__});
	
	# Now we'll write out the config.
	if (not $generate_return_code)
	{
		$an->InstallManifest->write_lvm_conf_on_node({
				node     => $an->data->{sys}{anvil}{node1}{name}, 
				target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node1}{use_port}, 
				password => $an->data->{sys}{anvil}{node1}{password},
			}) if not $an->data->{node}{node1}{has_servers};
		$an->InstallManifest->write_lvm_conf_on_node({
				node     => $an->data->{sys}{anvil}{node2}{name}, 
				target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node2}{use_port}, 
				password => $an->data->{sys}{anvil}{node2}{password},
			}) if not $an->data->{node}{node2}{has_servers};
	}
	
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0026!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0026!#";
	# Was there a conflict?
	if ($generate_return_code eq "2")
	{
		# Failed to read/prepare lvm.conf data.
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0072!#";
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0072!#";
		$ok            = 0;
	}
	elsif ($generate_return_code eq "1")
	{
		# Duplicate, unmatched filters
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0061!#";
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0061!#";
		$ok            = 0;
	}
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0251!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	return($ok);
}

# This checks to see if /etc/cluster/cluster.conf is available and aborts if so.
sub configure_cman
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_cman" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Generate a new cluster.conf, then check to see if one already exists.
	$an->InstallManifest->generate_cluster_conf();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::cluster_conf", value1 => $an->data->{sys}{cluster_conf},
	}, file => $THIS_FILE, line => __LINE__});
	
	my $ok                         = 1;
	my $node1                      = $an->data->{sys}{anvil}{node1}{name};
	my $node2                      = $an->data->{sys}{anvil}{node2}{name};
	my $node1_cluster_conf_version = 0;
	my $node2_cluster_conf_version = 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1", value1 => $node1,
		name2 => "node2", value2 => $node2,
	}, file => $THIS_FILE, line => __LINE__});
	($node1_cluster_conf_version) = $an->InstallManifest->read_cluster_conf({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		});
	($node2_cluster_conf_version) = $an->InstallManifest->read_cluster_conf({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
		});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_cluster_conf_version", value1 => $node1_cluster_conf_version,
		name2 => "node2_cluster_conf_version", value2 => $node2_cluster_conf_version,
	}, file => $THIS_FILE, line => __LINE__});
	
	# This will set if a node's cluster.conf is (re)written or not.
	my $write_node1 = 0;
	my $write_node2 = 0;
	
	# If either node is hosting servers, use its cluster.conf. Otherwise, if a node's cluster.conf in > 
	# 1, use it.
	$an->Log->entry({log_level => 2, message_key => "log_0206", file => $THIS_FILE, line => __LINE__});
	if ($an->data->{node}{node1}{has_servers})
	{
		# Use node1's cluster.conf
		$an->Log->entry({log_level => 2, message_key => "log_0270", message_variables => { 
			active_node => $an->data->{sys}{anvil}{node1}{name},
			file        => "cluster.conf",
		}, file => $THIS_FILE, line => __LINE__});
		$an->data->{node}{$node2}{cluster_conf} = $an->data->{node}{$node1}{cluster_conf};
		$write_node2                            = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node2}::cluster_conf", value1 => $an->data->{node}{$node2}{cluster_conf},
			name2 => "write_node2",                  value2 => $write_node2,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($an->data->{node}{node2}{has_servers})
	{
		# Use node2's cluster.conf
		$an->Log->entry({log_level => 2, message_key => "log_0270", message_variables => {
			active_node => $an->data->{sys}{anvil}{node2}{name},
			file        => "cluster.conf",
		}, file => $THIS_FILE, line => __LINE__});
		$an->data->{node}{$node1}{cluster_conf} = $an->data->{node}{$node2}{cluster_conf};
		$write_node1                            = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node1}::cluster_conf", value1 => $an->data->{node}{$node1}{cluster_conf},
			name2 => "write_node1",                  value2 => $write_node2,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($node1_cluster_conf_version > 1)
	{
		$an->Log->entry({log_level => 2, message_key => "log_0207", message_variables => {
			node1_cluster_conf_version => $node1_cluster_conf_version, 
			node2_cluster_conf_version => $node2_cluster_conf_version, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($node1_cluster_conf_version eq $node2_cluster_conf_version)
		{
			# Both are the same and both are > 1, do nothing.
			$an->Log->entry({log_level => 2, message_key => "log_0208", file => $THIS_FILE, line => __LINE__});
		}
		elsif ($node1_cluster_conf_version > $node2_cluster_conf_version)
		{
			# Node 1 is newer
			$an->Log->entry({log_level => 2, message_key => "log_0209", message_variables => {
				newer => "1", 
				older => "2", 
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{node}{$node2}{cluster_conf} = $an->data->{node}{$node1}{cluster_conf};
			$write_node2                            = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "node::${node2}::cluster_conf", value1 => $an->data->{node}{$node2}{cluster_conf},
				name2 => "write_node2",                  value2 => $write_node2,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($node1_cluster_conf_version < $node2_cluster_conf_version)
		{
			# Node 2 is newer
			$an->Log->entry({log_level => 2, message_key => "log_0209", message_variables => {
				newer => "2", 
				older => "1", 
			}, file => $THIS_FILE, line => __LINE__});
			$an->data->{node}{$node1}{cluster_conf} = $an->data->{node}{$node2}{cluster_conf};
			$write_node1                            = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "node::${node1}::cluster_conf", value1 => $an->data->{node}{$node1}{cluster_conf},
				name2 => "write_node1",                  value2 => $write_node1,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	elsif ($node2_cluster_conf_version > 1)
	{
		# Node 2's version is >1 while node 1's isn't, so use node 2.
		$an->Log->entry({log_level => 2, message_key => "log_0209", message_variables => {
			newer_node    => "2", 
			newer_version => $node2_cluster_conf_version, 
			older_node    => "1",
			older_version => $node1_cluster_conf_version, 
		}, file => $THIS_FILE, line => __LINE__});
		$an->data->{node}{$node1}{cluster_conf} = $an->data->{node}{$node2}{cluster_conf};
		$write_node1                            = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node1}::cluster_conf", value1 => $an->data->{node}{$node1}{cluster_conf},
			name2 => "write_node1",                  value2 => $write_node1,
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Neither node has an existing cluster.conf, using the default generated one.
		$an->Log->entry({log_level => 2, message_key => "log_0210", file => $THIS_FILE, line => __LINE__});
		$an->data->{node}{$node1}{cluster_conf} = $an->data->{sys}{cluster_conf};
		$an->data->{node}{$node2}{cluster_conf} = $an->data->{sys}{cluster_conf};
		$write_node1                            = 1;
		$write_node2                            = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "node::${node1}::cluster_conf", value1 => $an->data->{node}{$node1}{cluster_conf},
			name2 => "node::${node2}::cluster_conf", value2 => $an->data->{node}{$node2}{cluster_conf},
			name3 => "write_node1",                  value3 => $write_node1,
			name4 => "write_node2",                  value4 => $write_node2,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Write them out now.
	my $node1_return_code    = "";
	my $node1_return_message = "";
	my $node2_return_code    = "";
	my $node2_return_message = "";
	if (($write_node1) && (not $an->data->{node}{node1}{has_servers}))
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node1", value1 => $node1,
		}, file => $THIS_FILE, line => __LINE__});
		($node1_return_code, $node1_return_message) = $an->InstallManifest->write_cluster_conf({
				node     => $node1, 
				target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node1}{use_port}, 
				password => $an->data->{sys}{anvil}{node1}{password},
			});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node1_return_code",    value1 => $node1_return_code,
			name2 => "node1_return_message", value2 => $node1_return_message,
		}, file => $THIS_FILE, line => __LINE__});
	}
	if (($write_node2) && (not $an->data->{node}{node2}{has_servers}))
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node2", value1 => $node2,
		}, file => $THIS_FILE, line => __LINE__});
		($node2_return_code, $node2_return_message) = $an->InstallManifest->write_cluster_conf({
				node     => $node2, 
				target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node2}{use_port}, 
				password => $an->data->{sys}{anvil}{node2}{password},
			});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node2_return_code",    value1 => $node2_return_code,
			name2 => "node2_return_message", value2 => $node2_return_message,
		}, file => $THIS_FILE, line => __LINE__});
	}
	# 0 = Written and validated
	# 1 = ccs_config_validate failed
	
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0028!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0028!#";
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif ($node1_return_code eq "1")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = $an->String->get({key => "state_0076", variables => { message => $node1_return_message }});
		$ok            = 0;
	}
	elsif ($write_node1)
	{
		$node1_message = "#!string!state_0029!#";
	}
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif ($node2_return_code eq "1")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = $an->String->get({key => "state_0076", variables => { message => $node2_return_message }});
		$ok            = 0;
	}
	elsif ($write_node2)
	{
		$node2_message = "#!string!state_0029!#";
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0221!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	if (not $ok)
	{
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-failed", replace => { message => "#!string!message_0363!#" }});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This sets nodes to start or stop on boot.
sub configure_daemons
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_daemons" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1_ok       = 1; 
	my $node1_messages = "";
	my $node2_ok       = 1;
	my $node2_messages = "";
	($node1_ok, $node1_messages) = $an->InstallManifest->configure_daemons_on_node({
			node     => $an->data->{sys}{anvil}{node1}{name},
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		}) if not $an->data->{node}{node1}{has_servers};
	($node2_ok, $node2_messages) = $an->InstallManifest->configure_daemons_on_node({
			node     => $an->data->{sys}{anvil}{node2}{name},
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
		}) if not $an->data->{node}{node2}{has_servers};
	
	# If there was a problem on either node, the message will be set.
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0029!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0029!#";
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif (not $node1_ok)
	{
		# Something went wrong...
		$node1_class   = "highlight_warning_bold";
		$node1_message = "";
		$ok            = 0;
		foreach my $error (split/,/, $node1_messages)
		{
			if ($error =~ /failed to enable:(.*)/)
			{
				my $daemon = $1;
				$node1_message .= $an->String->get({key => "state_0062", variables => { daemon => $daemon }});
			}
			elsif ($error =~ /failed to start:(.*)/)
			{
				my $daemon = $1;
				$node1_message .= $an->String->get({key => "state_0063", variables => { daemon => $daemon }});
			}
			elsif ($error =~ /failed to disable:(.*)/)
			{
				my $daemon = $1;
				$node1_message .= $an->String->get({key => "state_0064", variables => { daemon => $daemon }});
			}
			elsif ($error =~ /failed to stop:(.*)/)
			{
				my $daemon = $1;
				$node1_message .= $an->String->get({key => "state_0065", variables => { daemon => $daemon }});
			}
		}
	}
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif (not $node2_ok)
	{
		# Something went wrong...
		$node2_class   = "highlight_warning_bold";
		$node2_message = "";
		$ok            = 0;
		foreach my $error (split/,/, $node2_messages)
		{
			if ($error =~ /failed to enable:(.*)/)
			{
				my $daemon = $1;
				$node2_message .= $an->String->get({key => "state_0062", variables => { daemon => $daemon }});
			}
			elsif ($error =~ /failed to start:(.*)/)
			{
				my $daemon = $1;
				$node2_message .= $an->String->get({key => "state_0063", variables => { daemon => $daemon }});
			}
			elsif ($error =~ /failed to disable:(.*)/)
			{
				my $daemon = $1;
				$node2_message .= $an->String->get({key => "state_0064", variables => { daemon => $daemon }});
			}
			elsif ($error =~ /failed to stop:(.*)/)
			{
				my $daemon = $1;
				$node2_message .= $an->String->get({key => "state_0065", variables => { daemon => $daemon }});
			}
		}
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0252!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This enables and disables daemons on boot for a node.
sub configure_daemons_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_daemons_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $ok     = 1;
	my $return = "";
	
	# Enable daemons
	foreach my $daemon (sort {$a cmp $b} @{$an->data->{sys}{daemons}{enable}})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "node",   value1 => $node,
			name2 => "daemon", value2 => $daemon,
		}, file => $THIS_FILE, line => __LINE__});
		
		my ($init3, $init5) = $an->InstallManifest->get_chkconfig_data({
				node     => $node,
				target   => $target, 
				port     => $port, 
				password => $password,
				daemon   => $daemon,
			});
		
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "init3", value1 => $init3,
			name2 => "init5", value2 => $init5,
		}, file => $THIS_FILE, line => __LINE__});
		if (($init3 eq "1") && ($init5 eq "1"))
		{
			# Already enabled.
			$an->Log->entry({log_level => 2, message_key => "log_0138", message_variables => {
				node   => $node, 
				daemon => $daemon,
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Enable it.
			$an->InstallManifest->set_chkconfig({
				node     => $node, 
				target   => $target, 
				port     => $port, 
				password => $password,
				daemon   => $daemon,
				'state'  => "on",
			});
			
			my ($init3, $init5) = $an->InstallManifest->get_chkconfig_data({
					node     => $node, 
					target   => $target, 
					port     => $port, 
					password => $password,
					daemon   => $daemon,
				});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "init3", value1 => $init3,
				name2 => "init5", value2 => $init5,
			}, file => $THIS_FILE, line => __LINE__});
			if (($init3 eq "1") && ($init5 eq "1"))
			{
				# Success
				$an->Log->entry({log_level => 2, message_key => "log_0139", message_variables => {
					node   => $node, 
					daemon => $daemon,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# failed. :(
				$an->Log->entry({log_level => 1, message_key => "log_0140", message_variables => {
					node   => $node, 
					daemon => $daemon,
				}, file => $THIS_FILE, line => __LINE__});
				$return .= "failed to enable:$daemon,";
				$ok = 0;
			}
		}
		
		# Now check/start the daemon if needed
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "ok", value1 => $ok,
		}, file => $THIS_FILE, line => __LINE__});
		if ($ok)
		{
			my ($state) = $an->InstallManifest->get_daemon_state({
					node     => $node, 
					target   => $target, 
					port     => $port, 
					password => $password,
					daemon   => $daemon
				});
			
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "node",   value1 => $node,
				name2 => "daemon", value2 => $daemon,
				name3 => "state",  value3 => $state,
			}, file => $THIS_FILE, line => __LINE__});
			if ($state eq "1")
			{
				# Already running.
				$an->Log->entry({log_level => 2, message_key => "log_0141", message_variables => {
					node   => $node, 
					daemon => $daemon,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($state eq "0")
			{
				# Start it.
				$an->InstallManifest->set_daemon_state({
					node     => $node, 
					target   => $target, 
					port     => $port, 
					password => $password,
					daemon   => $daemon,
					'state'  => "start",
				});
				my ($state) = $an->InstallManifest->get_daemon_state({
						node     => $node, 
						target   => $target, 
						port     => $port, 
						password => $password,
						daemon   => $daemon
					});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "node",   value1 => $node,
					name2 => "daemon", value2 => $daemon,
					name3 => "state",  value3 => $state,
				}, file => $THIS_FILE, line => __LINE__});
				if ($state eq "1")
				{
					# Now running.
					$an->Log->entry({log_level => 2, message_key => "log_0142", message_variables => {
						node   => $node, 
						daemon => $daemon,
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($state eq "0")
				{
					# Failed to start
					$an->Log->entry({log_level => 1, message_key => "log_0143", message_variables => {
						node   => $node, 
						daemon => $daemon,
					}, file => $THIS_FILE, line => __LINE__});
					$return .= "failed to start:$daemon,";
				}
			}
		}
	}
	
	# Now disable daemons.
	foreach my $daemon (sort {$a cmp $b} @{$an->data->{sys}{daemons}{disable}})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node",   value1 => $node,
			name2 => "daemon", value2 => $daemon,
		}, file => $THIS_FILE, line => __LINE__});
		
		my ($init3, $init5) = $an->InstallManifest->get_chkconfig_data({
				node     => $node, 
				target   => $target, 
				port     => $port, 
				password => $password,
				daemon   => $daemon,
			});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "init3", value1 => $init3,
			name2 => "init5", value2 => $init5,
		}, file => $THIS_FILE, line => __LINE__});
		if (($init3 eq "0") && ($init5 eq "0"))
		{
			# Already disabled.
			$an->Log->entry({log_level => 2, message_key => "log_0144", message_variables => {
				node   => $node, 
				daemon => $daemon,
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Disable it.
			$an->InstallManifest->set_chkconfig({
				node     => $node, 
				target   => $target, 
				port     => $port, 
				password => $password,
				daemon   => $daemon,
				'state'  => "off",
			});
			
			my ($init3, $init5) = $an->InstallManifest->get_chkconfig_data({
					node     => $node, 
					target   => $target, 
					port     => $port, 
					password => $password,
					daemon   => $daemon,
				});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "init3", value1 => $init3,
				name2 => "init5", value2 => $init5,
			}, file => $THIS_FILE, line => __LINE__});
			if (($init3 eq "0") && ($init5 eq "0"))
			{
				# Success
				$an->Log->entry({log_level => 2, message_key => "log_0145", message_variables => {
					node   => $node, 
					daemon => $daemon,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# failed. :(
				$an->Log->entry({log_level => 1, message_key => "log_0146", message_variables => {
					node   => $node, 
					daemon => $daemon,
				}, file => $THIS_FILE, line => __LINE__});
				$return .= "failed to disable:$daemon,";
				$ok = 0;
			}
		}
		
		# Now check/stop the daemon if needed
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "ok", value1 => $ok,
		}, file => $THIS_FILE, line => __LINE__});
		if ($ok)
		{
			my ($state) = $an->InstallManifest->get_daemon_state({
					node     => $node, 
					target   => $target, 
					port     => $port, 
					password => $password,
					daemon   => $daemon
				});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "node",   value1 => $node,
				name2 => "daemon", value2 => $daemon,
				name3 => "state",  value3 => $state,
			}, file => $THIS_FILE, line => __LINE__});
			if ($state eq "0")
			{
				# Already stopped.
				$an->Log->entry({log_level => 2, message_key => "log_0147", message_variables => {
					node   => $node, 
					daemon => $daemon,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($state eq "0")
			{
				# stop it.
				$an->InstallManifest->set_daemon_state({
					node     => $node, 
					target   => $target, 
					port     => $port, 
					password => $password,
					daemon   => $daemon,
					'state'  => "stop",
				});
				my ($state) = $an->InstallManifest->get_daemon_state({
						node     => $node, 
						target   => $target, 
						port     => $port, 
						password => $password,
						daemon   => $daemon
					});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "node",   value1 => $node,
					name2 => "daemon", value2 => $daemon,
					name3 => "state",  value3 => $state,
				}, file => $THIS_FILE, line => __LINE__});
				if ($state eq "0")
				{
					# Now stopped.
					$an->Log->entry({log_level => 2, message_key => "log_0148", message_variables => {
						node   => $node, 
						daemon => $daemon,
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($state eq "1")
				{
					# Failed to stop
					$an->Log->entry({log_level => 1, message_key => "log_0149", message_variables => {
						node   => $node, 
						daemon => $daemon,
					}, file => $THIS_FILE, line => __LINE__});
					$return .= "failed to stop:$daemon,";
				}
			}
		}
	}
	$return =~ s/,$//;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "ok",     value1 => $ok,
		name2 => "return", value2 => $return,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok, $return);
}

# This handles starting (and configuring) GFS2 on the nodes.
sub configure_gfs2
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_gfs2" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ok    = 1;
	my $node1 = $an->data->{sys}{anvil}{node1}{name};
	my $node2 = $an->data->{sys}{anvil}{node2}{name};
	my ($node1_return_code) = $an->InstallManifest->setup_gfs2_on_node({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		}) if not $an->data->{node}{node1}{has_servers};
	my ($node2_return_code) = $an->InstallManifest->setup_gfs2_on_node({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
		}) if not $an->data->{node}{node2}{has_servers};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_return_code", value1 => $node1_return_code,
		name2 => "node2_return_code", value2 => $node2_return_code,
	}, file => $THIS_FILE, line => __LINE__});
	# 0 = OK
	# 1 = Failed to append to fstab
	# 2 = Failed to mount
	# 3 = GFS2 LBS status check failed.
	# 4 = Failed to create subdirectories
	# 5 = SELinux configuration failed.
	# 6 = UUID for GFS2 partition not recorded
	
	# Report
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0029!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0029!#";
	# Node 1
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif ($node1_return_code eq "1")
	{
		$node1_message = "#!string!state_0028!#";
	}
	elsif ($node1_return_code eq "2")
	{
		# Failed to mount /shared
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0091!#";
		$ok            = 0;
	}
	elsif ($node1_return_code eq "3")
	{
		# GFS2 LSB check failed
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0092!#";
		$ok            = 0;
	}
	elsif ($node1_return_code eq "4")
	{
		# Failed to create subdirectory/ies
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0093!#";
		$ok            = 0;
	}
	elsif ($node1_return_code eq "5")
	{
		# Failed to update SELinux context
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0094!#";
		$ok            = 0;
	}
	elsif ($node1_return_code eq "6")
	{
		# Failed to update SELinux context
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0095!#";
		$ok            = 0;
	}
	
	# Node 2
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif ($node2_return_code eq "1")
	{
		$node2_message = "#!string!state_0028!#";
	}
	elsif ($node2_return_code eq "2")
	{
		# Failed to mount /shared
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0091!#";
		$ok            = 0;
	}
	elsif ($node2_return_code eq "3")
	{
		# GFS2 LSB check failed
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0092!#";
		$ok            = 0;
	}
	elsif ($node2_return_code eq "4")
	{
		# Failed to create subdirectory/ies
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0093!#";
		$ok            = 0;
	}
	elsif ($node2_return_code eq "5")
	{
		# Failed to update SELinux context
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0094!#";
		$ok            = 0;
	}
	elsif ($node2_return_code eq "6")
	{
		# Failed to update SELinux context
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0095!#";
		$ok            = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0268!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This configures IPMI
sub configure_ipmi
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_ipmi" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ok                = 1;
	my $node1_return_code = 0;
	my $node2_return_code = 0;
	($node1_return_code) = $an->InstallManifest->configure_ipmi_on_node({
			node          => $an->data->{sys}{anvil}{node1}{name}, 
			target        => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port          => $an->data->{sys}{anvil}{node1}{use_port}, 
			password      => $an->data->{sys}{anvil}{node1}{password},
			ipmi_ip       => $an->data->{cgi}{anvil_node1_ipmi_ip},
			ipmi_netmask  => $an->data->{cgi}{anvil_node1_ipmi_netmask},
			ipmi_password => $an->data->{cgi}{anvil_node1_ipmi_password},
			ipmi_user     => $an->data->{cgi}{anvil_node1_ipmi_user}, 
			ipmi_gateway  => $an->data->{cgi}{anvil_node1_ipmi_gateway},
		}) if not $an->data->{node}{node1}{has_servers};
	($node2_return_code) = $an->InstallManifest->configure_ipmi_on_node({
			node          => $an->data->{sys}{anvil}{node2}{name}, 
			target        => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port          => $an->data->{sys}{anvil}{node2}{use_port}, 
			password      => $an->data->{sys}{anvil}{node2}{password},
			ipmi_ip       => $an->data->{cgi}{anvil_node2_ipmi_ip},
			ipmi_netmask  => $an->data->{cgi}{anvil_node2_ipmi_netmask},
			ipmi_password => $an->data->{cgi}{anvil_node2_ipmi_password},
			ipmi_user     => $an->data->{cgi}{anvil_node2_ipmi_user}, 
			ipmi_gateway  => $an->data->{cgi}{anvil_node2_ipmi_gateway},
		}) if not $an->data->{node}{node2}{has_servers};
	# 0 = Configured
	# 1 = Failed to set the IPMI user password
	# 2 = No IPMI device found
	# 3 = LAN channel not found
	# 4 = User ID not found
	# 5 = IPMI address not static
	# 6 = IPMI IP is not correct
	# 7 = IPMI subnet is not correct
	
	### Not having IPMI is not, itself fatal.
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0029!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0029!#";
	# Node 1
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif ($node1_return_code eq "1")
	{
		# No IPMI device found.
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0071!#",
		$ok            = 0;
	}
	elsif ($node1_return_code eq "2")
	{
		# No IPMI device found.
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0019!#",
	}
	elsif ($node1_return_code eq "3")
	{
		# IPMI LAN channel not found
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0066!#",
		$ok            = 0;
	}
	elsif ($node1_return_code eq "4")
	{
		# User ID not found
		$node1_class   = "highlight_warning_bold";
		$node1_message = $an->String->get({key => "state_0067", variables => { user => $an->data->{cgi}{anvil_node1_ipmi_user} }});
		$ok            = 0;
	}
	elsif ($node1_return_code eq "5")
	{
		# Failed to set to static IP
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0068!#",
		$ok            = 0;
	}
	elsif ($node1_return_code eq "6")
	{
		# Failed to set IP address
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0069!#",
		$ok            = 0;
	}
	elsif ($node1_return_code eq "7")
	{
		# Failed to set netmask
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0070!#",
		$ok            = 0;
	}
	
	# Node 2
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif ($node2_return_code eq "1")
	{
		# No IPMI device found.
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0071!#",
		$ok            = 0;
	}
	elsif ($node2_return_code eq "2")
	{
		# No IPMI device found.
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0019!#",
	}
	elsif ($node2_return_code eq "3")
	{
		# IPMI LAN channel not found
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0066!#",
		$ok            = 0;
	}
	elsif ($node2_return_code eq "4")
	{
		# User ID not found
		$node2_class   = "highlight_warning_bold";
		$node2_message = $an->String->get({key => "state_0067", variables => { user => $an->data->{cgi}{anvil_node2_ipmi_user} }});
		$ok            = 0;
	}
	elsif ($node2_return_code eq "5")
	{
		# Failed to set to static IP
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0068!#",
		$ok            = 0;
	}
	elsif ($node2_return_code eq "6")
	{
		# Failed to set IP address
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0069!#",
		$ok            = 0;
	}
	elsif ($node2_return_code eq "7")
	{
		# Failed to set netmask
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0070!#",
		$ok            = 0;
	}
	
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0253!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	return($ok);
}

# This does the work of actually configuring IPMI on a node
sub configure_ipmi_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_ipmi_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ipmi_ip       = $parameter->{ipmi_ip}       ? $parameter->{ipmi_ip}       : "";
	my $ipmi_netmask  = $parameter->{ipmi_netmask}  ? $parameter->{ipmi_netmask}  : "";
	my $ipmi_password = $parameter->{ipmi_password} ? $parameter->{ipmi_password} : "";
	my $ipmi_user     = $parameter->{ipmi_user}     ? $parameter->{ipmi_user}     : "";
	my $ipmi_gateway  = $parameter->{ipmi_gateway}  ? $parameter->{ipmi_gateway}  : "";
	my $node          = $parameter->{node}          ? $parameter->{node}          : "";
	my $target        = $parameter->{target}        ? $parameter->{target}        : "";
	my $port          = $parameter->{port}          ? $parameter->{port}          : "";
	my $password      = $parameter->{password}      ? $parameter->{password}      : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
		name1 => "ipmi_ip",       value1 => $ipmi_ip, 
		name2 => "ipmi_netmask",  value2 => $ipmi_netmask, 
		name3 => "ipmi_user",     value3 => $ipmi_user, 
		name4 => "ipmi_gateway",  value4 => $ipmi_gateway, 
		name5 => "node",          value5 => $node, 
		name6 => "target",        value6 => $target, 
		name7 => "port",          value7 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "ipmi_password", value1 => $ipmi_password, 
		name2 => "password",      value2 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return_code = 255;
	# 0 = Configured
	# 1 = Failed to set the IPMI password
	# 2 = No IPMI device found
	# 3 = LAN channel not found
	# 4 = User ID not found
	# 5 = IPMI address not static
	# 6 = IPMI IP is not correct
	# 7 = IPMI subnet is not correct
	
	# Is there an IPMI device?
	my ($state) = $an->InstallManifest->get_daemon_state({
			node     => $node, 
			target   => $target, 
			port     => $port, 
			password => $password,
			daemon   => "ipmi", 
		});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "state", value1 => $state,
	}, file => $THIS_FILE, line => __LINE__});
	if ($state eq "7")
	{
		# IPMI not found
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node", value1 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		$return_code = 2;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "return_code", value1 => $return_code, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# If we're still alive, then it is safe to say IPMI is running. Find the LAN channel
		my $lan_found = 0;
		my $channel   = 0;
		while (not $lan_found)
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "channel", value1 => $channel,
			}, file => $THIS_FILE, line => __LINE__});
			if ($channel > 10)
			{
				# Give up...
				$an->Log->entry({log_level => 1, message_key => "log_0127", file => $THIS_FILE, line => __LINE__});
				$channel = "";
				last;
			}
			
			# check to see if this is the write channel
			my $shell_call = $an->data->{path}{ipmitool}." lan print $channel; ".$an->data->{path}{echo}." return_code:\$?";
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
				
				if ($line =~ /Invalid channel: /)
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "channel", value1 => $channel,
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($line =~ "return_code:0")
				{
					# Found it!
					$lan_found = 1;
					$an->Log->entry({log_level => 2, message_key => "log_0128", message_variables => {
						channel => $channel, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			$channel++ if not $lan_found;
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "channel", value1 => $channel,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Now find the admin user ID number
		my $user_id   = 0;
		my $uid_found = 0;
		if ($lan_found)
		{
			while (not $uid_found)
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "user_id", value1 => $user_id,
				}, file => $THIS_FILE, line => __LINE__});
				if ($user_id > 20)
				{
					# Give up...
					$an->Log->entry({log_level => 1, message_key => "log_0129", file => $THIS_FILE, line => __LINE__});
					$user_id = "";
					last;
				}
				
				# check to see if this is the write channel
				my $shell_call = $an->data->{path}{ipmitool}." user list $channel";
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
					$line =~ s/\s+/ /g;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
					
					if ($line =~ /^(\d+) $ipmi_user /)
					{
						# Found it.
						$user_id   = $1;
						$uid_found = 1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "user_id", value1 => $user_id,
						}, file => $THIS_FILE, line => __LINE__});
						last;
					}
				}
				$user_id++ if not $uid_found;
			}
			
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "ipmi_user", value1 => $ipmi_user,
				name2 => "user_id",   value2 => $user_id,
			}, file => $THIS_FILE, line => __LINE__});
			if ($uid_found)
			{
				# Set the password.
				my $shell_call = $an->data->{path}{ipmitool}." user set password $user_id '$ipmi_password'";
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
				
				# Test the password. If this fails with '16', try '20'.
				my $password_ok = 0;
				my $try_20      = 0;
				   $shell_call  = $an->data->{path}{ipmitool}." user test $user_id 16 '$ipmi_password'";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "target",     value1 => $target,
					name2 => "shell_call", value2 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
				($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
					
					if ($line =~ /Success/i)
					{
						# Woo!
						$an->Log->entry({log_level => 2, message_key => "log_0130", message_variables => { target => $channel }, file => $THIS_FILE, line => __LINE__});
					}
					elsif ($line =~ /wrong password size/i)
					{
						# Try size 20.
						$try_20 = 1;
						$an->Log->entry({log_level => 2, message_key => "log_0131", file => $THIS_FILE, line => __LINE__});
					}
					elsif ($line =~ /password incorrect/i)
					{
						# Password didn't take. :(
						$return_code = 1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "return_code", value1 => $return_code, 
						}, file => $THIS_FILE, line => __LINE__});
						$an->Log->entry({log_level => 1, message_key => "log_0132", message_variables => { target => $channel }, file => $THIS_FILE, line => __LINE__});
					}
				}
				if ($try_20)
				{
					my $shell_call  = $an->data->{path}{ipmitool}." user test $user_id 20 '$ipmi_password'";
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
						
						if ($line =~ /Success/i)
						{
							# Woo!
							$an->Log->entry({log_level => 2, message_key => "log_0133", message_variables => { target => $channel }, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($line =~ /password incorrect/i)
						{
							# Password didn't take. :(
							$return_code = 1;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "return_code", value1 => $return_code, 
							}, file => $THIS_FILE, line => __LINE__});
							$an->Log->entry({log_level => 1, message_key => "log_0132", message_variables => { target => $channel }, file => $THIS_FILE, line => __LINE__});
						}
					}
				}
			}
		}
		
		# If I am missing either the channel or the user ID, we're done.
		if (not $lan_found)
		{
			$return_code = 3;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (not $uid_found)
		{
			$return_code = 4;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($return_code ne "1")
		{
			### Still alive!
			# Setup the IPMI IP to static
			my $shell_call = $an->data->{path}{ipmitool}." lan set $channel ipsrc static";
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
			
			# Now set the IP
			$shell_call = $an->data->{path}{ipmitool}." lan set $channel ipaddr $ipmi_ip";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "target",     value1 => $target,
				name2 => "shell_call", value2 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
			
			# Now the netmask
			$shell_call = $an->data->{path}{ipmitool}." lan set $channel netmask $ipmi_netmask";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "target",     value1 => $target,
				name2 => "shell_call", value2 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
			
			# If the user has specified a gateway, set it
			if ($ipmi_gateway)
			{
				my $shell_call = $an->data->{path}{ipmitool}." lan set $channel defgw ipaddr $ipmi_gateway";
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
			
			### Now read it back.
			# Now the netmask
			$shell_call = $an->data->{path}{ipmitool}." lan print $channel";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "target",     value1 => $target,
				name2 => "shell_call", value2 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
				
				if ($line =~ /IP Address Source/i)
				{
					if ($line =~ /Static/i)
					{
						# Now set to static
						$an->Log->entry({log_level => 2, message_key => "log_0134", message_variables => {
							node => $node, 
						}, file => $THIS_FILE, line => __LINE__});
					}
					else
					{
						# Failed to set to static.
						$an->Log->entry({log_level => 1, message_key => "log_0135", message_variables => {
							node => $node, 
						}, file => $THIS_FILE, line => __LINE__});
						$return_code = 5;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "return_code", value1 => $return_code, 
						}, file => $THIS_FILE, line => __LINE__});
						last;
					}
				}
				if ($line =~ /IP Address :/i)	# Needs the ' :' to not match 'IP Address Source'
				{
					my $ip = ($line =~ /(\d+\.\d+\.\d+\.\d+)$/)[0];
					if ($ip eq $ipmi_ip)
					{
						# Success!
						$return_code = 0;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
							name1 => "return_code", value1 => $return_code, 
							name2 => "ipmi_ip",     value2 => $ipmi_ip,
						}, file => $THIS_FILE, line => __LINE__});
					}
					else
					{
						# Reported IP doesn't match desired IP.
						$an->Log->entry({log_level => 1, message_key => "log_0136", message_variables => {
							current_ip => $ip, 
							desired_ip => $ipmi_ip, 
							node       => $node, 
						}, file => $THIS_FILE, line => __LINE__});
						$return_code = 6;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "return_code", value1 => $return_code, 
						}, file => $THIS_FILE, line => __LINE__});
						last;
					}
				}
				if ($line =~ /Subnet Mask/i)
				{
					my $ip = ($line =~ /(\d+\.\d+\.\d+\.\d+)$/)[0];
					if ($ip eq $ipmi_netmask)
					{
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "ipmi_netmask", value1 => $ipmi_netmask,
						}, file => $THIS_FILE, line => __LINE__});
					}
					else
					{
						# Subnet mismatch
						$an->Log->entry({log_level => 1, message_key => "log_0137", message_variables => {
							current_subnet => $ip, 
							desired_subnet => $ipmi_netmask, 
							node           => $node, 
						}, file => $THIS_FILE, line => __LINE__});
						$return_code = 7;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "return_code", value1 => $return_code, 
						}, file => $THIS_FILE, line => __LINE__});
						last;
					}
				}
			}
		}
	}
	
	# HP Proliants will report that their IP address changed, but not actually update until the BMC is 
	# reset. 
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($return_code eq "0")
	{
		my $reset_bmc   = "";
		my $reset_delay = 60;
		my $shell_call  = $an->data->{path}{dmidecode}." --string system-manufacturer";
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
			
			if (lc($line) eq "hp")
			{
				$reset_bmc = "warm";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "reset_bmc", value1 => $reset_bmc, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /dell/i)
			{
				$reset_bmc = "cold";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "reset_bmc", value1 => $reset_bmc, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "reset_bmc", value1 => $reset_bmc, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($reset_bmc)
		{
			# Tell the user that we're resetting the BMC.
			$an->Log->entry({log_level => 1, message_key => "log_0004", file => $THIS_FILE, line => __LINE__});
			
			# Do the reset.
			my $shell_call = $an->data->{path}{ipmitool}." bmc reset ".$reset_bmc;
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
			
			# Sleep for a minute to give time for the BMC to reset.
			$an->Log->entry({log_level => 1, message_key => "log_0005", message_variables => { 'sleep' => $reset_delay }, file => $THIS_FILE, line => __LINE__});
			sleep $reset_delay;
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This configures the network.
sub configure_network
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_network" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# The 'ethtool' options can include variables, so we'll need to escape '$' if found.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "cgi::anvil_ifn_ethtool_opts", value1 => $an->data->{cgi}{anvil_ifn_ethtool_opts},
		name2 => "cgi::anvil_sn_ethtool_opts",  value2 => $an->data->{cgi}{anvil_sn_ethtool_opts},
		name3 => "cgi::anvil_ifn_ethtool_opts", value3 => $an->data->{cgi}{anvil_ifn_ethtool_opts},
	}, file => $THIS_FILE, line => __LINE__});
	$an->data->{cgi}{anvil_bcn_ethtool_opts} =~ s/\$/\\\$/g;
	$an->data->{cgi}{anvil_sn_ethtool_opts}  =~ s/\$/\\\$/g;
	$an->data->{cgi}{anvil_ifn_ethtool_opts} =~ s/\$/\\\$/g;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "cgi::anvil_ifn_ethtool_opts", value1 => $an->data->{cgi}{anvil_ifn_ethtool_opts},
		name2 => "cgi::anvil_sn_ethtool_opts",  value2 => $an->data->{cgi}{anvil_sn_ethtool_opts},
		name3 => "cgi::anvil_ifn_ethtool_opts", value3 => $an->data->{cgi}{anvil_ifn_ethtool_opts},
	}, file => $THIS_FILE, line => __LINE__});
	
	my $node1_ok = 0;
	my $node2_ok = 0;
	($node1_ok) = $an->InstallManifest->configure_network_on_node({
			node        => $an->data->{sys}{anvil}{node1}{name}, 
			target      => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port        => $an->data->{sys}{anvil}{node1}{use_port}, 
			password    => $an->data->{sys}{anvil}{node1}{password},
			node_number => 1,
		}) if not $an->data->{node}{node1}{has_servers};
	($node2_ok) = $an->InstallManifest->configure_network_on_node({
			node        => $an->data->{sys}{anvil}{node2}{name}, 
			target      => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port        => $an->data->{sys}{anvil}{node2}{use_port}, 
			password    => $an->data->{sys}{anvil}{node2}{password},
			node_number => 2,
		}) if not $an->data->{node}{node2}{has_servers};
	# 0 = OK
	# 1 = A MAC address was missing when preparing to write udev
	# 2 = A string (or something) was found in the variable where the MAC should have been.
	
	# The above functions always return '1' at this point.
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0029!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0029!#";
	my $message       = "";
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif ($node1_ok eq "1")
	{
		# Missing a MAC address
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0075!#",
		$ok            = 0;
	}
	elsif ($node1_ok eq "2")
	{
		# Malformed MAC address
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0110!#",
		$ok            = 0;
	}
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif ($node1_ok eq "1")
	{
		# Missing a MAC address
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0075!#",
		$ok            = 0;
	}
	elsif ($node2_ok eq "2")
	{
		# Malformed MAC address
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0110!#",
		$ok            = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0228!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	return($ok);
}

# This handles the actual configuration of the network files.
sub configure_network_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_network_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node_number = $parameter->{node_number} ? $parameter->{node_number} : "";
	my $node        = $parameter->{node}        ? $parameter->{node}     : "";
	my $target      = $parameter->{target}      ? $parameter->{target}   : "";
	my $port        = $parameter->{port}        ? $parameter->{port}        : "";
	my $password    = $parameter->{password}    ? $parameter->{password}    : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node_number", value1 => $node_number, 
		name2 => "node",        value2 => $node, 
		name3 => "target",      value3 => $target, 
		name4 => "port",        value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# I need to make the node keys.
	my $return_code       = 0;
	my $name_key          = "anvil_node".$node_number."_name";
	my $bcn_ip_key        = "anvil_node".$node_number."_bcn_ip";
	my $bcn_link1_mac_key = "anvil_node".$node_number."_bcn_link1_mac";
	my $bcn_link2_mac_key = "anvil_node".$node_number."_bcn_link2_mac";
	my $sn_ip_key         = "anvil_node".$node_number."_sn_ip";
	my $sn_link1_mac_key  = "anvil_node".$node_number."_sn_link1_mac";
	my $sn_link2_mac_key  = "anvil_node".$node_number."_sn_link2_mac";
	my $ifn_ip_key        = "anvil_node".$node_number."_ifn_ip";
	my $ifn_link1_mac_key = "anvil_node".$node_number."_ifn_link1_mac";
	my $ifn_link2_mac_key = "anvil_node".$node_number."_ifn_link2_mac";
	
	# The MTU to use, blanked if 1500 as that is default.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::anvil_mtu_size",                 value1 => $an->data->{cgi}{anvil_mtu_size},
		name2 => "sys::install_manifest::default::mtu", value2 => $an->data->{sys}{install_manifest}{'default'}{mtu},
	}, file => $THIS_FILE, line => __LINE__});
	
	my $mtu = $an->data->{cgi}{anvil_mtu_size} ? $an->data->{cgi}{anvil_mtu_size} : $an->data->{sys}{install_manifest}{'default'}{mtu};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "mtu", value1 => $mtu,
	}, file => $THIS_FILE, line => __LINE__});
	
	$mtu = "" if $mtu eq "1500"; 
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "mtu", value1 => $mtu,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Here we're going to write out all the network and udev configuration details per node.
	my $hostname =  "NETWORKING=yes\n";
	   $hostname .= "HOSTNAME=".$an->data->{cgi}{$name_key};
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0012", message_variables => {
		name1  => "bcn_link1_mac_key",       value1  => $bcn_link1_mac_key,
		name2  => "cgi::$bcn_link1_mac_key", value2  => $an->data->{cgi}{$bcn_link1_mac_key},
		name3  => "bcn_link2_mac_key",       value3  => $bcn_link2_mac_key,
		name4  => "cgi::$bcn_link2_mac_key", value4  => $an->data->{cgi}{$bcn_link2_mac_key},
		name5  => "sn_link1_mac_key",        value5  => $sn_link1_mac_key,
		name6  => "cgi::$sn_link1_mac_key",  value6  => $an->data->{cgi}{$sn_link1_mac_key},
		name7  => "sn_link2_mac_key",        value7  => $sn_link2_mac_key,
		name8  => "cgi::$sn_link2_mac_key",  value8  => $an->data->{cgi}{$sn_link2_mac_key},
		name9  => "ifn_link1_mac_key",       value9  => $ifn_link1_mac_key,
		name10 => "cgi::$ifn_link1_mac_key", value10 => $an->data->{cgi}{$ifn_link1_mac_key},
		name11 => "ifn_link2_mac_key",       value11 => $ifn_link2_mac_key,
		name12 => "cgi::$ifn_link2_mac_key", value12 => $an->data->{cgi}{$ifn_link2_mac_key},
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $an->data->{cgi}{$bcn_link1_mac_key}) or 
	    (not $an->data->{cgi}{$bcn_link2_mac_key}) or 
	    (not $an->data->{cgi}{$sn_link2_mac_key})  or 
	    (not $an->data->{cgi}{$sn_link2_mac_key})  or 
	    (not $an->data->{cgi}{$ifn_link2_mac_key}) or 
	    (not $an->data->{cgi}{$ifn_link2_mac_key}))
	{
		# Wtf?
		$return_code = 1;
		return($return_code);
	}
	
	# Make sure the values are actually MAC addresses
	if (($an->data->{cgi}{$bcn_link1_mac_key} !~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i) or 
	    ($an->data->{cgi}{$bcn_link2_mac_key} !~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i) or 
	    ($an->data->{cgi}{$sn_link2_mac_key}  !~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i) or 
	    ($an->data->{cgi}{$sn_link2_mac_key}  !~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i) or 
	    ($an->data->{cgi}{$ifn_link2_mac_key} !~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i) or 
	    ($an->data->{cgi}{$ifn_link2_mac_key} !~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i))
	{
		# >_<
		$return_code = 2;
		return($return_code);
	}
	
	### udev rules file to map MAC to interface names
	my $udev_net_rules =  "# Generated by: [$THIS_FILE] on: [".$an->Get->date_and_time({split_date_time => 0})."].\n\n";
	   $udev_net_rules .= "# Back-Channel Network, Link 1\n";
	   $udev_net_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"".$an->data->{cgi}{$bcn_link1_mac_key}."\", NAME=\"bcn_link1\"\n\n";
	   $udev_net_rules .= "# Back-Channel Network, Link 2\n";
	   $udev_net_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"".$an->data->{cgi}{$bcn_link2_mac_key}."\", NAME=\"bcn_link2\"\n\n";
	   $udev_net_rules .= "# Storage Network, Link 1\n";
	   $udev_net_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"".$an->data->{cgi}{$sn_link1_mac_key}."\", NAME=\"sn_link1\"\n\n";
	   $udev_net_rules .= "# Storage Network, Link 2\n";
	   $udev_net_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"".$an->data->{cgi}{$sn_link2_mac_key}."\", NAME=\"sn_link2\"\n\n";
	   $udev_net_rules .= "# Internet-Facing Network, Link 1\n";
	   $udev_net_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"".$an->data->{cgi}{$ifn_link1_mac_key}."\", NAME=\"ifn_link1\"\n\n";
	   $udev_net_rules .= "# Internet-Facing Network, Link 2\n";
	   $udev_net_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"".$an->data->{cgi}{$ifn_link2_mac_key}."\", NAME=\"ifn_link2\"\n";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "udev_net_rules", value1 => $udev_net_rules,
	}, file => $THIS_FILE, line => __LINE__});
	
	### Back-Channel Network
	my $ifcfg_bcn_link1 =  "# Generated by: [$THIS_FILE] on: [".$an->Get->date_and_time({split_date_time => 0})."].\n";
	   $ifcfg_bcn_link1 .= "# Back-Channel Network - Link 1\n";
	   $ifcfg_bcn_link1 .= "DEVICE=\"bcn_link1\"\n";
	   $ifcfg_bcn_link1 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_bcn_link1 .= "NM_CONTROLLED=\"no\"\n";
	   $ifcfg_bcn_link1 .= "BOOTPROTO=\"none\"\n";
	   $ifcfg_bcn_link1 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_bcn_link1 .= "SLAVE=\"yes\"\n";
	   $ifcfg_bcn_link1 .= "MASTER=\"bcn_bond1\"";
	if ($an->data->{cgi}{anvil_bcn_ethtool_opts})
	{
		$ifcfg_bcn_link1 .= "\nETHTOOL_OPTS=\"".$an->data->{cgi}{anvil_bcn_ethtool_opts}."\"";
	}
	my $ifcfg_bcn_link2 =  "# Generated by: [$THIS_FILE] on: [".$an->Get->date_and_time({split_date_time => 0})."].\n";
	   $ifcfg_bcn_link2 .= "# Back-Channel Network - Link 2\n";
	   $ifcfg_bcn_link2 .= "DEVICE=\"bcn_link2\"\n";
	   $ifcfg_bcn_link2 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_bcn_link2 .= "NM_CONTROLLED=\"no\"\n";
	   $ifcfg_bcn_link2 .= "BOOTPROTO=\"none\"\n";
	   $ifcfg_bcn_link2 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_bcn_link2 .= "SLAVE=\"yes\"\n";
	   $ifcfg_bcn_link2 .= "MASTER=\"bcn_bond1\"";
	if ($an->data->{cgi}{anvil_bcn_ethtool_opts})
	{
		$ifcfg_bcn_link2 .= "\nETHTOOL_OPTS=\"".$an->data->{cgi}{anvil_bcn_ethtool_opts}."\"";
	}
	my $ifcfg_bcn_bond1 =  "# Generated by: [$THIS_FILE] on: [".$an->Get->date_and_time({split_date_time => 0})."].\n";
	   $ifcfg_bcn_bond1 .= "# Back-Channel Network - Bond 1\n";
	   $ifcfg_bcn_bond1 .= "DEVICE=\"bcn_bond1\"\n";
	   $ifcfg_bcn_bond1 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_bcn_bond1 .= "BOOTPROTO=\"static\"\n";
	   $ifcfg_bcn_bond1 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_bcn_bond1 .= "BONDING_OPTS=\"mode=1 miimon=100 use_carrier=1 updelay=120000 downdelay=0 primary=bcn_link1 primary_reselect=always\"\n";
	   $ifcfg_bcn_bond1 .= "IPADDR=\"".$an->data->{cgi}{$bcn_ip_key}."\"\n";
	   $ifcfg_bcn_bond1 .= "NETMASK=\"".$an->data->{cgi}{anvil_bcn_subnet}."\"\n";
	   $ifcfg_bcn_bond1 .= "DEFROUTE=\"no\"";
	
	### Storage Network
	my $ifcfg_sn_link1 =  "# Generated by: [$THIS_FILE] on: [".$an->Get->date_and_time({split_date_time => 0})."].\n";
	   $ifcfg_sn_link1 .= "# Storage Network - Link 1\n";
	   $ifcfg_sn_link1 .= "DEVICE=\"sn_link1\"\n";
	   $ifcfg_sn_link1 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_sn_link1 .= "NM_CONTROLLED=\"no\"\n";
	   $ifcfg_sn_link1 .= "BOOTPROTO=\"none\"\n";
	   $ifcfg_sn_link1 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_sn_link1 .= "SLAVE=\"yes\"\n";
	   $ifcfg_sn_link1 .= "MASTER=\"sn_bond1\"";
	if ($an->data->{cgi}{anvil_sn_ethtool_opts})
	{
		$ifcfg_sn_link1 .= "\nETHTOOL_OPTS=\"".$an->data->{cgi}{anvil_sn_ethtool_opts}."\"";
	}
	my $ifcfg_sn_link2 =  "# Generated by: [$THIS_FILE] on: [".$an->Get->date_and_time({split_date_time => 0})."].\n";
	   $ifcfg_sn_link2 .= "# Storage Network - Link 2\n";
	   $ifcfg_sn_link2 .= "DEVICE=\"sn_link2\"\n";
	   $ifcfg_sn_link2 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_sn_link2 .= "NM_CONTROLLED=\"no\"\n";
	   $ifcfg_sn_link2 .= "BOOTPROTO=\"none\"\n";
	   $ifcfg_sn_link2 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_sn_link2 .= "SLAVE=\"yes\"\n";
	   $ifcfg_sn_link2 .= "MASTER=\"sn_bond1\"";
	if ($an->data->{cgi}{anvil_sn_ethtool_opts})
	{
		$ifcfg_sn_link2 .= "\nETHTOOL_OPTS=\"".$an->data->{cgi}{anvil_sn_ethtool_opts}."\"";
	}
	my $ifcfg_sn_bond1 =  "# Generated by: [$THIS_FILE] on: [".$an->Get->date_and_time({split_date_time => 0})."].\n";
	   $ifcfg_sn_bond1 .= "# Storage Network - Bond 1\n";
	   $ifcfg_sn_bond1 .= "DEVICE=\"sn_bond1\"\n";
	   $ifcfg_sn_bond1 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_sn_bond1 .= "BOOTPROTO=\"static\"\n";
	   $ifcfg_sn_bond1 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_sn_bond1 .= "BONDING_OPTS=\"mode=1 miimon=100 use_carrier=1 updelay=120000 downdelay=0 primary=sn_link1 primary_reselect=always\"\n";
	   $ifcfg_sn_bond1 .= "IPADDR=\"".$an->data->{cgi}{$sn_ip_key}."\"\n";
	   $ifcfg_sn_bond1 .= "NETMASK=\"".$an->data->{cgi}{anvil_sn_subnet}."\"\n";
	   $ifcfg_sn_bond1 .= "DEFROUTE=\"no\"";
	
	### Internet-Facing Network
	my $ifcfg_ifn_link1 =  "# Generated by: [$THIS_FILE] on: [".$an->Get->date_and_time({split_date_time => 0})."].\n";
	   $ifcfg_ifn_link1 .= "# Internet-Facing Network - Link 1\n";
	   $ifcfg_ifn_link1 .= "DEVICE=\"ifn_link1\"\n";
	   $ifcfg_ifn_link1 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_ifn_link1 .= "NM_CONTROLLED=\"no\"\n";
	   $ifcfg_ifn_link1 .= "BOOTPROTO=\"none\"\n";
	   $ifcfg_ifn_link1 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_ifn_link1 .= "SLAVE=\"yes\"\n";
	   $ifcfg_ifn_link1 .= "MASTER=\"ifn_bond1\"";
	if ($an->data->{cgi}{anvil_ifn_ethtool_opts})
	{
		$ifcfg_ifn_link1 .= "\nETHTOOL_OPTS=\"".$an->data->{cgi}{anvil_ifn_ethtool_opts}."\"";
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ifcfg_ifn_link1", value1 => $ifcfg_ifn_link1,
	}, file => $THIS_FILE, line => __LINE__});
	my $ifcfg_ifn_link2 =  "# Generated by: [$THIS_FILE] on: [".$an->Get->date_and_time({split_date_time => 0})."].\n";
	   $ifcfg_ifn_link2 .= "# Internet-Facing Network - Link 2\n";
	   $ifcfg_ifn_link2 .= "DEVICE=\"ifn_link2\"\n";
	   $ifcfg_ifn_link2 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_ifn_link2 .= "NM_CONTROLLED=\"no\"\n";
	   $ifcfg_ifn_link2 .= "BOOTPROTO=\"none\"\n";
	   $ifcfg_ifn_link2 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_ifn_link2 .= "SLAVE=\"yes\"\n";
	   $ifcfg_ifn_link2 .= "MASTER=\"ifn_bond1\"";
	if ($an->data->{cgi}{anvil_ifn_ethtool_opts})
	{
		$ifcfg_ifn_link2 .= "\nETHTOOL_OPTS=\"".$an->data->{cgi}{anvil_ifn_ethtool_opts}."\"";
	}
	my $ifcfg_ifn_bond1 =  "# Generated by: [$THIS_FILE] on: [".$an->Get->date_and_time({split_date_time => 0})."].\n";
	   $ifcfg_ifn_bond1 .= "# Internet-Facing Network - Bond 1\n";
	   $ifcfg_ifn_bond1 .= "DEVICE=\"ifn_bond1\"\n";
	   $ifcfg_ifn_bond1 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_ifn_bond1 .= "BRIDGE=\"ifn_bridge1\"\n";
	   $ifcfg_ifn_bond1 .= "BOOTPROTO=\"none\"\n";
	   $ifcfg_ifn_bond1 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_ifn_bond1 .= "BONDING_OPTS=\"mode=1 miimon=100 use_carrier=1 updelay=120000 downdelay=0 primary=ifn_link1 primary_reselect=always\"";
	
	### NOTE: We don't set the MTU here because the bridge will ignore it. Bridges always take the MTU of
	###       the connected device with the lowest MTU.
	my $ifcfg_ifn_bridge1 =  "# Generated by: [$THIS_FILE] on: [".$an->Get->date_and_time({split_date_time => 0})."].\n";
	   $ifcfg_ifn_bridge1 .= "# Internet-Facing Network - Bridge 1\n";
	   $ifcfg_ifn_bridge1 .= "DEVICE=\"ifn_bridge1\"\n";
	   $ifcfg_ifn_bridge1 .= "TYPE=\"Bridge\"\n";
	   $ifcfg_ifn_bridge1 .= "BOOTPROTO=\"static\"\n";
	   $ifcfg_ifn_bridge1 .= "IPADDR=\"".$an->data->{cgi}{$ifn_ip_key}."\"\n";
	   $ifcfg_ifn_bridge1 .= "NETMASK=\"".$an->data->{cgi}{anvil_ifn_subnet}."\"\n";
	   $ifcfg_ifn_bridge1 .= "GATEWAY=\"".$an->data->{cgi}{anvil_ifn_gateway}."\"\n" if $an->data->{cgi}{anvil_ifn_gateway};
	   $ifcfg_ifn_bridge1 .= "DNS1=\"".$an->data->{cgi}{anvil_dns1}."\"\n"           if $an->data->{cgi}{anvil_dns1};
	   $ifcfg_ifn_bridge1 .= "DNS2=\"".$an->data->{cgi}{anvil_dns2}."\"\n"           if $an->data->{cgi}{anvil_dns2};
	   $ifcfg_ifn_bridge1 .= "DEFROUTE=\"yes\"";
	   
	# Create the 'anvil-adjust-vnet' udev rules file.
	my $udev_vnet_rules =  "# Generated by: [$THIS_FILE] on: [".$an->Get->date_and_time({split_date_time => 0})."].\n\n";
	   $udev_vnet_rules .= "# This calls '".$an->data->{path}{nodes}{'anvil-adjust-vnet'}."' when a network devices are created.\n";
	   $udev_vnet_rules .= "\n";
	   $udev_vnet_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", RUN+=\"".$an->data->{path}{nodes}{'anvil-adjust-vnet'}."\"\n";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "udev_vnet_rules", value1 => $udev_vnet_rules,
	}, file => $THIS_FILE, line => __LINE__});
	
	### NOTE: If this changes, be sure to update the expected number of lines needed to determine if a 
	###       reboot is needed! (search for '$lines < 13', about 500 lines down from here)
	# Setup the fireall now. (Temporarily; the new multiport based and old state based versions are here.
	# The old one will be removed once this one is confirmed to be good.)
	my $iptables  = "";
	my $vnc_range = 5900 + $an->data->{cgi}{anvil_open_vnc_ports};
	$iptables .= "
# Generated by: [$THIS_FILE] on: [".$an->Get->date_and_time({split_date_time => 0})."].
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]

# Allow SSH on all nets
-A INPUT -p tcp -m conntrack --ctstate NEW -m tcp --dport 22 -j ACCEPT

# Allow sctp on the BCN and SN
-A INPUT -s ".$an->data->{cgi}{anvil_bcn_network}."/".$an->data->{cgi}{anvil_bcn_subnet}." -p sctp -j ACCEPT
-A INPUT -s ".$an->data->{cgi}{anvil_sn_network}."/".$an->data->{cgi}{anvil_sn_subnet}." -p sctp -j ACCEPT

# Allow UDP-multicast based clusters on the BCN and SN
-I INPUT -m addrtype --dst-type MULTICAST -m conntrack --ctstate NEW -m multiport -p udp -s ".$an->data->{cgi}{anvil_bcn_network}."/".$an->data->{cgi}{anvil_bcn_subnet}." --dports 5404,5405 -j ACCEPT
-I INPUT -m addrtype --dst-type MULTICAST -m conntrack --ctstate NEW -m multiport -p udp -s ".$an->data->{cgi}{anvil_sn_network}."/".$an->data->{cgi}{anvil_sn_subnet}." --dports 5404,5405 -j ACCEPT

# Allow UDP-unicast based clusters on the BCN and SN
-A INPUT -m conntrack --ctstate NEW -m multiport -p udp -s ".$an->data->{cgi}{anvil_bcn_network}."/".$an->data->{cgi}{anvil_bcn_subnet}." -d ".$an->data->{cgi}{anvil_bcn_network}."/".$an->data->{cgi}{anvil_bcn_subnet}." --dports 5404,5405 -j ACCEPT
-A INPUT -m conntrack --ctstate NEW -m multiport -p udp -s ".$an->data->{cgi}{anvil_sn_network}."/".$an->data->{cgi}{anvil_sn_subnet}." -d ".$an->data->{cgi}{anvil_sn_network}."/".$an->data->{cgi}{anvil_sn_subnet}." --dports 5404,5405 -j ACCEPT

# Allow NTP, VNC, ricci, modclusterd, dlm and KVM live migration on the BCN
-A INPUT -m conntrack --ctstate NEW -m multiport -p tcp -s ".$an->data->{cgi}{anvil_bcn_network}."/".$an->data->{cgi}{anvil_bcn_subnet}." -d ".$an->data->{cgi}{anvil_bcn_network}."/".$an->data->{cgi}{anvil_bcn_subnet}." --dports 123,5800,5900:$vnc_range,11111,16851,21064,49152:49216 -j ACCEPT 

# Allow DRBD (11 resources) and, as backups, ricci, modclusterd and DLM on the SN
-A INPUT -m conntrack --ctstate NEW -m multiport -p tcp -s ".$an->data->{cgi}{anvil_sn_network}."/".$an->data->{cgi}{anvil_sn_subnet}." -d ".$an->data->{cgi}{anvil_sn_network}."/".$an->data->{cgi}{anvil_sn_subnet}." --dports 7788:7799,11111,16851,21064 -j ACCEPT 

# Allow NTP and VNC on the IFN
-A INPUT -m conntrack --ctstate NEW -m multiport -p tcp -s ".$an->data->{cgi}{anvil_ifn_network}."/".$an->data->{cgi}{anvil_ifn_subnet}." -d ".$an->data->{cgi}{anvil_ifn_network}."/".$an->data->{cgi}{anvil_ifn_subnet}." --dports 123,5800,5900:$vnc_range -j ACCEPT 

# Allow IGMP for UDP-multicast based clusters.
-A INPUT -p igmp -j ACCEPT

# Allow all traffic back in that we initiated
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow pings and other ICMP traffic on all nets
-A INPUT -p icmp -j ACCEPT

# Allow everything on localhost
-A INPUT -i lo -j ACCEPT

# Reject everything else
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited

COMMIT";
	
	### Generate the hosts file
	# Break up hostsnames
	my  $node1_short_name     = $an->data->{sys}{anvil}{node1}{short_name};
	my  $node2_short_name     = $an->data->{sys}{anvil}{node2}{short_name};
	my ($switch1_short_name)  = ($an->data->{cgi}{anvil_switch1_name}  =~ /^(.*?)\./);
	my ($switch2_short_name)  = ($an->data->{cgi}{anvil_switch2_name}  =~ /^(.*?)\./);
	my ($pdu1_short_name)     = ($an->data->{cgi}{anvil_pdu1_name}     =~ /^(.*?)\./);
	my ($pdu2_short_name)     = ($an->data->{cgi}{anvil_pdu2_name}     =~ /^(.*?)\./);
	my ($pdu3_short_name)     = ($an->data->{cgi}{anvil_pdu3_name}     =~ /^(.*?)\./);
	my ($pdu4_short_name)     = ($an->data->{cgi}{anvil_pdu4_name}     =~ /^(.*?)\./);
	my ($ups1_short_name)     = ($an->data->{cgi}{anvil_ups1_name}     =~ /^(.*?)\./);
	my ($ups2_short_name)     = ($an->data->{cgi}{anvil_ups2_name}     =~ /^(.*?)\./);
	my ($striker1_short_name) = ($an->data->{cgi}{anvil_striker1_name} =~ /^(.*?)\./);
	my ($striker2_short_name) = ($an->data->{cgi}{anvil_striker2_name} =~ /^(.*?)\./);
	
	# now generate the hosts body.
	my $hosts =  "# Generated by: [$THIS_FILE] on: [".$an->Get->date_and_time({split_date_time => 0})."]\n";
	   $hosts .= "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4\n";
	   $hosts .= "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6\n";
	   $hosts .= "\n";
	   $hosts .= "# Anvil! ".$an->data->{cgi}{anvil_sequence}.", Node 01\n";
	   $hosts .= $an->data->{cgi}{anvil_node1_bcn_ip}."	$node1_short_name.bcn $node1_short_name ".$an->data->{sys}{anvil}{node1}{name}."\n";
	   $hosts .= $an->data->{cgi}{anvil_node1_ipmi_ip}."	$node1_short_name.ipmi\n";
	   $hosts .= $an->data->{cgi}{anvil_node1_sn_ip}."	$node1_short_name.sn\n";
	   $hosts .= $an->data->{cgi}{anvil_node1_ifn_ip}."	$node1_short_name.ifn\n";
	   $hosts .= "\n";
	   $hosts .= "# Anvil! ".$an->data->{cgi}{anvil_sequence}.", Node 02\n";
	   $hosts .= $an->data->{cgi}{anvil_node2_bcn_ip}."	$node2_short_name.bcn $node2_short_name ".$an->data->{sys}{anvil}{node2}{name}."\n";
	   $hosts .= $an->data->{cgi}{anvil_node2_ipmi_ip}."	$node2_short_name.ipmi\n";
	   $hosts .= $an->data->{cgi}{anvil_node2_sn_ip}."	$node2_short_name.sn\n";
	   $hosts .= $an->data->{cgi}{anvil_node2_ifn_ip}."	$node2_short_name.ifn\n";
	   $hosts .= "\n";
	   $hosts .= "# Network switches\n";
	   $hosts .= $an->data->{cgi}{anvil_switch1_ip}."	$switch1_short_name ".$an->data->{cgi}{anvil_switch1_name}."\n";
	   $hosts .= $an->data->{cgi}{anvil_switch2_ip}."	$switch2_short_name ".$an->data->{cgi}{anvil_switch2_name}."\n";
	   $hosts .= "\n";
	   $hosts .= "# Switched PDUs\n";
	   $hosts .= $an->data->{cgi}{anvil_pdu1_ip}."	$pdu1_short_name ".$an->data->{cgi}{anvil_pdu1_name}."\n";
	   $hosts .= $an->data->{cgi}{anvil_pdu2_ip}."	$pdu2_short_name ".$an->data->{cgi}{anvil_pdu2_name}."\n";
	   $hosts .= $an->data->{cgi}{anvil_pdu3_ip}."	$pdu3_short_name ".$an->data->{cgi}{anvil_pdu3_name}."\n" if $an->data->{cgi}{anvil_pdu3_ip};
	   $hosts .= $an->data->{cgi}{anvil_pdu4_ip}."	$pdu4_short_name ".$an->data->{cgi}{anvil_pdu4_name}."\n" if $an->data->{cgi}{anvil_pdu4_ip};
	   $hosts .= "\n";
	   $hosts .= "# UPSes\n";
	   $hosts .= $an->data->{cgi}{anvil_ups1_ip}."	$ups1_short_name ".$an->data->{cgi}{anvil_ups1_name}."\n";
	   $hosts .= $an->data->{cgi}{anvil_ups2_ip}."	$ups2_short_name ".$an->data->{cgi}{anvil_ups2_name}."\n";
	   $hosts .= "\n";
	   $hosts .= "# Striker dashboards\n";
	   $hosts .= $an->data->{cgi}{anvil_striker1_bcn_ip}."	$striker1_short_name.bcn $striker1_short_name ".$an->data->{cgi}{anvil_striker1_name}."\n";
	   $hosts .= $an->data->{cgi}{anvil_striker1_ifn_ip}."	$striker1_short_name.ifn\n";
	   $hosts .= $an->data->{cgi}{anvil_striker2_bcn_ip}."	$striker2_short_name.bcn $striker2_short_name ".$an->data->{cgi}{anvil_striker2_name}."\n";
	   $hosts .= $an->data->{cgi}{anvil_striker2_ifn_ip}."	$striker2_short_name.ifn\n";
	   $hosts .= "\n";
	
	# This will be used later when populating ~/.ssh/known_hosts
	$an->data->{sys}{node_names} = [
		$an->data->{sys}{anvil}{node1}{name}, 
		$node1_short_name, 
		"$node1_short_name.bcn", 
		"$node1_short_name.sn", 
		"$node1_short_name.ifn", 
		$an->data->{sys}{anvil}{node2}{name}, 
		$node2_short_name, 
		"$node2_short_name.bcn", 
		"$node2_short_name.sn", 
		"$node2_short_name.ifn"];
	
	### If we bail out between here and the end of this method, the user may lose access to their 
	### machines, so BE CAREFUL! :D
	# Delete any existing ifcfg-eth* files
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node", value1 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	
	# This removes all existing configuration files except for ifcfg-lo.
	my $shell_call = "
for iface in \$(".$an->data->{path}{ls}." /etc/sysconfig/network-scripts/ifcfg-* | ".$an->data->{path}{'grep'}." -v ifcfg-lo);
do
    echo \"Removing: \$iface\";
    ".$an->data->{path}{rm}." -f \$iface;
done
echo \"Remaining interface configuration files:\"
".$an->data->{path}{ls}." /etc/sysconfig/network-scripts/
";
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
	
	### Start writing!
	### Internet-Facing Network
	# IFN Bridge 1
	$shell_call =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{ifn_bridge1_config}." << EOF\n";
	$shell_call .= "$ifcfg_ifn_bridge1\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	# IFN Bond 1
	$shell_call =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{ifn_bond1_config}." << EOF\n";
	$shell_call .= "$ifcfg_ifn_bond1\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	# IFN Link 1
	$shell_call =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{ifn_link1_config}." << EOF\n";
	$shell_call .= "$ifcfg_ifn_link1\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	# IFN Link 2
	$shell_call =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{ifn_link2_config}." << EOF\n";
	$shell_call .= "$ifcfg_ifn_link2\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	### Storage Network
	# SN Bond 1
	$shell_call =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{sn_bond1_config}." << EOF\n";
	$shell_call .= "$ifcfg_sn_bond1\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	# SN Link 1
	$shell_call =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{sn_link1_config}." << EOF\n";
	$shell_call .= "$ifcfg_sn_link1\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	# SN Link 2
	$shell_call =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{sn_link2_config}." << EOF\n";
	$shell_call .= "$ifcfg_sn_link2\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	### Back-Channel Network
	# BCN Bond 1
	$shell_call =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{bcn_bond1_config}." << EOF\n";
	$shell_call .= "$ifcfg_bcn_bond1\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	# BCN Link 1
	$shell_call =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{bcn_link1_config}." << EOF\n";
	$shell_call .= "$ifcfg_bcn_link1\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	# BCN Link 2
	$shell_call =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{bcn_link2_config}." << EOF\n";
	$shell_call .= "$ifcfg_bcn_link2\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	### Now write the net udev rules file.
	$shell_call = $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{udev_net_rules}." << EOF\n";
	$shell_call .= "$udev_net_rules\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	### Now write the vnet udev rules file.
	$shell_call = $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{udev_vnet_rules}." << EOF\n";
	$shell_call .= "$udev_vnet_rules\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	# Hosts file.
	$shell_call =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{hosts}." << EOF\n";
	$shell_call .= "$hosts\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	### Now write the hostname file and set the hostname for the current session.
	$shell_call =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{hostname}." << EOF\n";
	$shell_call .= "$hostname\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	$shell_call = $an->data->{path}{hostname}." ".$an->data->{cgi}{$name_key};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	### And finally, iptables. 
	### NOTE: DON'T restart iptables! It could break the connection as the rules are for the new network
	###       config, which may differ from the active one.
	# First, get a word count on the current iptables in-memory config. If it is smaller than 13 lines,
	# it is probably the original one and we'll need a reboot.
	$shell_call = $an->data->{path}{echo}." \"lines:\$(".$an->data->{path}{'iptables-save'}." | ".$an->data->{path}{wc}." -l)\"\n";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
		
		if ($line =~ /^lines:(\d+)$/)
		{
			my $lines = $1;
			if ($lines < 15)
			{
				# Reboot needed
				$an->Log->entry({log_level => 1, message_key => "log_0180", message_variables => {
					node  => $node, 
					lines => $lines, 
				}, file => $THIS_FILE, line => __LINE__});
				$an->data->{node}{$node}{reboot_needed} = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node}::reboot_needed", value1 => $an->data->{node}{$node}{reboot_needed},
				}, file => $THIS_FILE, line => __LINE__}); 
			}
			else
			{
				# Reboot probably not needed.
				$an->Log->entry({log_level => 1, message_key => "log_0181", message_variables => {
					node  => $node, 
					lines => $lines, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Now write the new one.
	$shell_call =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{iptables}." << EOF\n";
	$shell_call .= "$iptables\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	# If there is not an ifn_bridge1, assume we need to reboot.
	my $bridge_found = 0;
	   $shell_call   = $an->data->{path}{brctl}." show";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
		
		if ($line =~ /ifn_bridge1/)
		{
			$bridge_found = 1;
		}
	}
	if (not $bridge_found)
	{
		# Reboot needed.
		$an->data->{node}{$node}{reboot_needed} = 1;
		$an->Log->entry({log_level => 2, message_key => "log_0182", message_variables => {
			node => $node, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# If NTP servers are set, this will read in each node's '/etc/ntp.conf' and look to see if the defined NTP 
# servers need to be added. It will add any that are missing.
sub configure_ntp
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_ntp" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ok = 1;
	
	# Only proceed if at least one NTP server is defined.
	if (($an->data->{cgi}{anvil_ntp1}) or ($an->data->{cgi}{anvil_ntp2}))
	{
		my $node1_ok = 1;
		my $node2_ok = 1;
		($node1_ok) = $an->InstallManifest->configure_ntp_on_node({
				node     => $an->data->{sys}{anvil}{node1}{name}, 
				target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node1}{use_port}, 
				password => $an->data->{sys}{anvil}{node1}{password},
			}) if not $an->data->{node}{node1}{has_servers};
		($node2_ok) = $an->InstallManifest->configure_ntp_on_node({
				node     => $an->data->{sys}{anvil}{node2}{name}, 
				target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node2}{use_port}, 
				password => $an->data->{sys}{anvil}{node2}{password},
			}) if not $an->data->{node}{node2}{has_servers};
		# 0 = NTP server(s) already defined.
		# 1 = Added OK
		# 2 = problem adding NTP server
		
		# Default was "already added"
		my $node1_class   = "highlight_good_bold";
		my $node1_message = "#!string!state_0028!#";
		my $node2_class   = "highlight_good_bold";
		my $node2_message = "#!string!state_0028!#";
		my $message       = "";
		if ($an->data->{node}{node1}{has_servers})
		{
			$node1_class   = "highlight_note_bold";
			$node1_message = "#!string!state_0133!#";
		}
		elsif ($node1_ok eq "1")
		{
			# One or both added
			$node1_message = "#!string!state_0029!#",
		}
		if ($node1_ok eq "2")
		{
			# Failed to add.
			$node1_class   = "highlight_note_bold";
			$node1_message = "#!string!state_0018!#",
			$ok            = 0;
		}
		if ($an->data->{node}{node2}{has_servers})
		{
			$node2_class   = "highlight_note_bold";
			$node2_message = "#!string!state_0133!#";
		}
		elsif ($node2_ok eq "1")
		{
			# One or both added
			$node2_message = "#!string!state_0029!#",
		}
		if ($node2_ok eq "2")
		{
			# Failed to add.
			$node2_class   = "highlight_note_bold";
			$node2_message = "#!string!state_0018!#",
			$ok            = 0;
		}
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
			row		=>	"#!string!row_0275!#",
			node1_class	=>	$node1_class,
			node1_message	=>	$node1_message,
			node2_class	=>	$node2_class,
			node2_message	=>	$node2_message,
		}});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This reads in the /etc/ntp.conf file and adds custom NTP server if they aren't already there.
sub configure_ntp_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_ntp_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# We're going to do a grep for each defined NTP IP and, if the IP isn't found, it will be added.
	my $return_code = 0;
	my @ntp_servers;
	push @ntp_servers, $an->data->{cgi}{anvil_ntp1} if $an->data->{cgi}{anvil_ntp1};
	push @ntp_servers, $an->data->{cgi}{anvil_ntp2} if $an->data->{cgi}{anvil_ntp2};
	foreach my $ntp_server (@ntp_servers)
	{
		# Look for/add NTP server
		my $shell_call = "
if \$(".$an->data->{path}{'grep'}." -q 'server $ntp_server iburst' ".$an->data->{path}{nodes}{ntp_conf}."); 
then 
    ".$an->data->{path}{echo}." exists; 
else 
    ".$an->data->{path}{echo}." adding $ntp_server;
    ".$an->data->{path}{echo}." 'server $ntp_server iburst' >> ".$an->data->{path}{nodes}{ntp_conf}."
    if \$(".$an->data->{path}{'grep'}." -q 'server $ntp_server iburst' ".$an->data->{path}{nodes}{ntp_conf}.");
    then
        ".$an->data->{path}{echo}." added OK
    else
        ".$an->data->{path}{echo}." failed to add!
    fi;
fi";
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
			
			if ($line =~ /OK/i)
			{
				$return_code = 1;
			}
			elsif ($line =~ /failed/i)
			{
				$return_code = 2;
				last;
			}
		}
	}
	
	# 0 = NTP server(s) already defined.
	# 1 = Added OK
	# 2 = problem adding NTP server
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This sets up scancore to run on the nodes. It expects the database(s) to be on the node(s).
sub configure_scancore
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_scancore" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1_return_code         = 0;
	my $node1_return_code_message = "";
	my $node2_return_code         = 0;
	my $node2_return_code_message = "";
	($node1_return_code, $node1_return_code_message) = $an->InstallManifest->configure_scancore_on_node({
			host_uuid => $an->data->{cgi}{anvil_node1_uuid}, 
			node      => $an->data->{sys}{anvil}{node1}{name}, 
			target    => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port      => $an->data->{sys}{anvil}{node1}{use_port}, 
			password  => $an->data->{sys}{anvil}{node1}{password},
			node_name => $an->data->{sys}{anvil}{node1}{name},
		}) if not $an->data->{node}{node1}{has_servers};
	($node2_return_code, $node2_return_code_message) = $an->InstallManifest->configure_scancore_on_node({
			host_uuid => $an->data->{cgi}{anvil_node2_uuid}, 
			node      => $an->data->{sys}{anvil}{node2}{name}, 
			target    => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port      => $an->data->{sys}{anvil}{node2}{use_port}, 
			password  => $an->data->{sys}{anvil}{node2}{password},
			node_name => $an->data->{sys}{anvil}{node2}{name},
		}) if not $an->data->{node}{node2}{has_servers};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "node1_return_code",         value1 => $node1_return_code,
		name2 => "node2_return_code",         value2 => $node2_return_code,
		name3 => "node1_return_code_message", value3 => $node1_return_code_message,
		name4 => "node2_return_code_message", value4 => $node2_return_code_message,
	}, file => $THIS_FILE, line => __LINE__});
	# 0 == Success
	# 1 == Failed to download
	# 2 == Failed to extract
	# 3 == Base striker.conf not found.
	# 4 == Failed to create the striker.conf file.
	# 5 == Failed to add to root's crontab
	# 6 == ...free...
	# 7 == Host UUID is invalid
	# 8 == Target's ssh fingerprint changed.
	
	my $ok = 1;
	# Report
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0005!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0005!#";
	# Node 1
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif ($node1_return_code eq "1")
	{
		# Failed to download
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0111!#";
		$ok            = 0;
	}
	elsif ($node1_return_code eq "2")
	{
		# Failed to extract
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0112!#";
		$ok            = 0;
	}
	elsif ($node1_return_code eq "3")
	{
		# Base striker.conf not found
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0113!#";
		$ok            = 0;
	}
	elsif ($node1_return_code eq "4")
	{
		# Failed to create striker.conf
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0114!#";
		$ok            = 0;
	}
	elsif ($node1_return_code eq "5")
	{
		# Failed to add ScanCore to root's crontab
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0116!#";
		$ok            = 0;
	}
	elsif ($node1_return_code eq "7")
	{
		# The UUID in the host file is invalid.
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0118!#";
		$ok            = 0;
	}
	elsif ($node1_return_code eq "8")
	{
		# The node's ssh fingerprint has changed.
		$node1_class   = "highlight_warning_bold";
		$node1_message = $node1_return_code_message;
		$ok            = 0;
	}
	
	# Node 2
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif ($node2_return_code eq "1")
	{
		# Failed to download
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0111!#";
		$ok            = 0;
	}
	elsif ($node2_return_code eq "2")
	{
		# Failed to extract
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0112!#";
		$ok            = 0;
	}
	elsif ($node2_return_code eq "3")
	{
		# Base striker.conf not found
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0113!#";
		$ok            = 0;
	}
	elsif ($node2_return_code eq "4")
	{
		# Failed to create striker.conf
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0114!#";
		$ok            = 0;
	}
	elsif ($node2_return_code eq "5")
	{
		# Failed to add ScanCore to root's crontab
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0116!#";
		$ok            = 0;
	}
	elsif ($node2_return_code eq "7")
	{
		# The UUID in the host file is invalid.
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0118!#";
		$ok            = 0;
	}
	elsif ($node2_return_code eq "8")
	{
		# The node's ssh fingerprint has changed.
		$node2_class   = "highlight_warning_bold";
		$node2_message = $node2_return_code_message;
		$ok            = 0;
	}
	
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0286!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This does the actual work of configuring ScanCore on a given node.
sub configure_scancore_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_scancore_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $host_uuid = $parameter->{host_uuid} ? $parameter->{host_uuid} : $an->Get->uuid();
	my $node      = $parameter->{node}      ? $parameter->{node}      : "";
	my $target    = $parameter->{target}    ? $parameter->{target}    : "";
	my $port      = $parameter->{port}      ? $parameter->{port}      : "";
	my $password  = $parameter->{password}  ? $parameter->{password}  : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "host_uuid", value1 => $host_uuid, 
		name2 => "node",      value2 => $node, 
		name3 => "target",    value3 => $target, 
		name4 => "port",      value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return_code = 255;
	my $message     = "";
	
	# Delete these so that there isn't data from a previous node's run.
	$an->data->{used_db_id}   = {};
	$an->data->{used_db_host} = {};
	
	# Setup to host UUID.
	$host_uuid = $an->Storage->prep_uuid({
			node      => $node, 
			target    => $target, 
			port      => $port, 
			password  => $password, 
			host_uuid => $host_uuid, 
		});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "host_uuid", value1 => $host_uuid, 
	}, file => $THIS_FILE, line => __LINE__});
	
	if ($host_uuid !~ /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/)
	{
		$return_code = 7;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "return_code", value1 => $return_code, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# First, copy the ScanCore files into place. Create the striker config directory if needed, as well.
	my $generate_config  = 0;
	my ($path, $tarball) = ($an->data->{path}{nodes}{striker_tarball} =~ /^(.*)\/(.*)/);
	my $download_1       = "http://".$an->data->{cgi}{anvil_striker1_bcn_ip}."/files/$tarball";
	my $download_2       = "http://".$an->data->{cgi}{anvil_striker2_bcn_ip}."/files/$tarball";
	my $shell_call       = "
if [ -e '".$an->data->{path}{nodes}{striker_tarball}."' ];
then
    ".$an->data->{path}{echo}." 'removing previously downloaded source'
    ".$an->data->{path}{rm}." -f ".$an->data->{path}{nodes}{striker_tarball}."
fi;
".$an->data->{path}{echo}." download source;
if [ ! -e '$path' ];
then
    ".$an->data->{path}{'mkdir'}." -p $path
fi
".$an->data->{path}{wget}." -c $download_1 -O ".$an->data->{path}{nodes}{striker_tarball}."
if [ -s '".$an->data->{path}{nodes}{striker_tarball}."' ];
then
    ".$an->data->{path}{echo}." 'downloaded from $download_1 successfully'
else
    ".$an->data->{path}{echo}." 'download from $download_1 failed, trying alternate.'
    if [ -e '".$an->data->{path}{nodes}{striker_tarball}."' ];
    then
        ".$an->data->{path}{echo}." 'Deleting zero-size file'
        ".$an->data->{path}{rm}." -f ".$an->data->{path}{nodes}{striker_tarball}."
    fi;
    ".$an->data->{path}{wget}." -c $download_2 -O ".$an->data->{path}{nodes}{striker_tarball}."
    if [ -e '".$an->data->{path}{nodes}{striker_tarball}."' ];
    then
        ".$an->data->{path}{echo}." 'downloaded from $download_2 successfully'
    else
        ".$an->data->{path}{echo}." 'download from $download_2 failed, giving up.'
    fi;
fi;

if [ -e '".$an->data->{path}{nodes}{striker_tarball}."' ];
then
    if [ -e '$path/ScanCore/ScanCore' ];
    then
        ".$an->data->{path}{echo}." 'install already completed'
    else
        ".$an->data->{path}{echo}." 'Extracting tarball'
        ".$an->data->{path}{nodes}{tar}." -xvjf ".$an->data->{path}{nodes}{striker_tarball}." -C $path/ .
        ".$an->data->{path}{mv}." $path/Data $path/
        ".$an->data->{path}{mv}." $path/AN ".$an->data->{path}{nodes}{perl_library}."/
        if [ -e '$path/ScanCore/ScanCore' ];
        then
            ".$an->data->{path}{echo}." 'install succeeded'
        else
            ".$an->data->{path}{echo}." 'install failed'
        fi;
    fi;
fi;

if [ ! -e '/etc/striker' ];
then
    ".$an->data->{path}{'mkdir'}." /etc/striker
    ".$an->data->{path}{echo}." 'Striker configuration directory created.'
fi;

if [ -e '".$an->data->{path}{nodes}{striker_config}."' ];
then
    ".$an->data->{path}{echo}." 'striker config exists'
else
    ".$an->data->{path}{echo}." 'striker config needs to be generated'
fi;
";
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /failed, giving up/)
		{
			$return_code = 1;
		}
		if ($line =~ /install failed/)
		{
			$return_code = 2;
		}
		if (($line =~ /install succeeded/) or ($line =~ /install already completed/))
		{
			$return_code = 0;
		}
		if ($line =~ /config needs to be generated/)
		{
			$generate_config = 1;
		}
	}
	
	# Setup striker.conf if we've not hit a problem and if it doesn't exist already.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "return_code",     value1 => $return_code,
		name2 => "generate_config", value2 => $generate_config,
	}, file => $THIS_FILE, line => __LINE__});
	if (($return_code eq "0") && ($generate_config))
	{
		# Read in the base striker.conf from /sbin/striker/
		$an->Log->entry({log_level => 2, message_key => "log_0034", file => $THIS_FILE, line => __LINE__});
		my $base_striker_config_file = "$path/striker.conf";
		my $striker_config           = "";
		my $skip_db                  = "";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "base_striker_config_file", value1 => $base_striker_config_file,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Read in the base striker.conf
		if (-e $base_striker_config_file)
		{
			# Excellent, read it in.
			my $shell_call = $an->data->{path}{cat}." $base_striker_config_file";
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
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /^scancore::db::(\d+)::host\s+=\s+localhost/)
				{
					$skip_db = $1;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "skip_db", value1 => $skip_db,
					}, file => $THIS_FILE, line => __LINE__});
				}
				next if ($line =~ /^scancore::db::(\d+)::/);
				
				# Find DB IDs already used so I don't duplicate later when I inject the 
				# strikers.
				if ($line =~ /^scancore::db::(\d+)::host\s+=\s+(.*)$/)
				{
					my $db_id                              = $1;
					my $db_host                            = $2;
					   $an->data->{used_db_id}{$db_id}     = $db_host;
					   $an->data->{used_db_host}{$db_host} = $db_id;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "used_db_id::$db_id",     value1 => $an->data->{used_db_id}{$db_id},
						name2 => "used_db_host::$db_host", value2 => $an->data->{used_db_host}{$db_host},
					}, file => $THIS_FILE, line => __LINE__});
				}
				
				$striker_config .= "$line\n";
			}
			
			# Loop through again and inject the striker DBs.
			my $striker_1_bcn_ip = $an->data->{cgi}{anvil_striker1_bcn_ip};
			my $striker_1_db_id  = 0;
			my $add_striker_1    = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "used_db_host::$striker_1_bcn_ip", value1 => $an->data->{used_db_host}{$striker_1_bcn_ip},
			}, file => $THIS_FILE, line => __LINE__});
			if (not $an->data->{used_db_host}{$striker_1_bcn_ip})
			{
				# Find the first free DB ID.
				my $id = 1;
				while (not $striker_1_db_id)
				{
					if ($an->data->{used_db_id}{$id})
					{
						$id++;
					}
					else
					{
						$striker_1_db_id                             = $id;
						$add_striker_1                               = 1;
						$an->data->{used_db_id}{$striker_1_db_id}    = $striker_1_bcn_ip;
						$an->data->{used_db_host}{$striker_1_bcn_ip} = $striker_1_db_id; 
						$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
							name1 => "used_db_id::$striker_1_db_id",    value1 => $an->data->{used_db_id}{$striker_1_db_id},
							name2 => "used_db_host::$striker_1_bcn_ip", value2 => $an->data->{used_db_host}{$striker_1_bcn_ip},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "striker_1_db_id", value1 => $striker_1_db_id,
				}, file => $THIS_FILE, line => __LINE__});
			}
			my $striker_2_bcn_ip = $an->data->{cgi}{anvil_striker2_bcn_ip};
			my $striker_2_db_id  = 0;
			my $add_striker_2    = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "used_db_host::$striker_2_bcn_ip", value1 => $an->data->{used_db_host}{$striker_2_bcn_ip},
			}, file => $THIS_FILE, line => __LINE__});
			if (not $an->data->{used_db_host}{$striker_2_bcn_ip})
			{
				# Find the first free DB ID.
				my $id = 1;
				while (not $striker_2_db_id)
				{
					if ($an->data->{used_db_id}{$id})
					{
						$id++;
					}
					else
					{
						$striker_2_db_id                             = $id;
						$add_striker_2                               = 1;
						$an->data->{used_db_id}{$striker_2_db_id}    = $striker_2_bcn_ip;
						$an->data->{used_db_host}{$striker_2_bcn_ip} = $striker_2_db_id;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
							name1 => "used_db_id::$striker_2_db_id",    value1 => $an->data->{used_db_id}{$striker_2_db_id},
							name2 => "used_db_host::$striker_2_bcn_ip", value2 => $an->data->{used_db_host}{$striker_2_bcn_ip},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "striker_2_db_id", value1 => $striker_2_db_id,
				}, file => $THIS_FILE, line => __LINE__});
			}
			
			# Inject if needed.
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "add_striker_1", value1 => $add_striker_1,
				name2 => "add_striker_2", value2 => $add_striker_2,
			}, file => $THIS_FILE, line => __LINE__});
			if (($add_striker_1) or ($add_striker_2))
			{
				# Loop through the striker config and inject one or both of the striker DBs.
				my $new_striker_config = "";
				foreach my $line (split/\n/, $striker_config)
				{
					$new_striker_config .= "$line\n";
					if ($line =~ /#scancore::db::2::password\s+=\s+/)
					{
						# Inject
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "add_striker_1", value1 => $add_striker_1,
						}, file => $THIS_FILE, line => __LINE__});
						
						# NOTE: We need to use the DB passwords.
						my $striker_1_password = $an->data->{sys}{anvil}{password};
						my $striker_2_password = $an->data->{sys}{anvil}{password};
						foreach my $id (sort {$a cmp $b} keys %{$an->data->{scancore}{db}})
						{
							my $host     = $an->data->{scancore}{db}{$id}{host};
							my $password = $an->data->{scancore}{db}{$id}{password};
							$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
								name1 => "id",   value1 => $id,
								name2 => "host", value2 => $host,
							}, file => $THIS_FILE, line => __LINE__});
							$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
								name1 => "password", value1 => $password,
							}, file => $THIS_FILE, line => __LINE__});
							next if not $host;
							
							# Convert the hostname to an IP, if it isn't already,
							# as that is what we use in the nodes.
							if (not $an->Validate->is_ipv4({ip => $host}))
							{
								$host = $an->Get->ip_from_hostname({host_name => $host});
								$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
									name1 => "host", value1 => $host,
								}, file => $THIS_FILE, line => __LINE__});
							}
							
							if ($host eq $striker_1_bcn_ip)
							{
								$striker_1_password = $password;
								$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
									name1 => "striker_1_password", value1 => $striker_1_password,
								}, file => $THIS_FILE, line => __LINE__});
							}
							if ($host eq $striker_2_bcn_ip)
							{
								$striker_2_password = $password;
								$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
									name1 => "striker_2_password", value1 => $striker_2_password,
								}, file => $THIS_FILE, line => __LINE__});
							}
						}
						if ($add_striker_1)
						{
							my $db_host = $striker_1_bcn_ip;
							my $db_id   = $striker_1_db_id;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
								name1 => "db_host", value1 => $db_host,
								name2 => "db_id",   value2 => $db_id,
							}, file => $THIS_FILE, line => __LINE__});
							$new_striker_config .= "scancore::db::${db_id}::host			=	$db_host\n";
							$new_striker_config .= "scancore::db::${db_id}::port			=	5432\n";
							$new_striker_config .= "scancore::db::${db_id}::name			=	".$an->data->{sys}{scancore_database}."\n";
							$new_striker_config .= "scancore::db::${db_id}::user			=	".$an->data->{sys}{striker_user}."\n";
							$new_striker_config .= "scancore::db::${db_id}::password		=	".$striker_1_password."\n\n";
						}
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "add_striker_2", value1 => $add_striker_2,
						}, file => $THIS_FILE, line => __LINE__});
						if ($add_striker_2)
						{
							my $db_host = $striker_2_bcn_ip;
							my $db_id   = $striker_2_db_id;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
								name1 => "db_host", value1 => $db_host,
								name2 => "db_id",   value2 => $db_id,
							}, file => $THIS_FILE, line => __LINE__});
							$new_striker_config .= "scancore::db::${db_id}::host			=	$db_host\n";
							$new_striker_config .= "scancore::db::${db_id}::port			=	5432\n";
							$new_striker_config .= "scancore::db::${db_id}::name			=	".$an->data->{sys}{scancore_database}."\n";
							$new_striker_config .= "scancore::db::${db_id}::user			=	".$an->data->{sys}{striker_user}."\n";
							$new_striker_config .= "scancore::db::${db_id}::password		=	".$striker_2_password."\n\n";
						}
					}
				}
				
				# Copy new over old.
				$striker_config = $new_striker_config;
			}
			
			# This is going to be too big, so we need to write the config to a file and rsync it
			# to the node.
			my $temp_file  = "/tmp/${node}_striker_".time.".conf";
			   $shell_call = $temp_file;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			open (my $file_handle, ">", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to write: [$shell_call], error was: $!\n";
			print $file_handle $striker_config;
			close $file_handle;
			
			# If the target's keys are known, delete them in case we're rebuilding the taget.
			$an->Remote->add_target_to_known_hosts({
				target          => $target, 
				delete_if_found => 1,
			});
			
			# Now rsync it to the node (using an 'expect' wrapper).
			my $bad_file = "";
			my $bad_line = "";
			$return_code = $an->Storage->rsync({
				node        => $node,
				target      => $target,
				port        => $port, 
				password    => $password,
				source      => $temp_file,
				destination => "root\@$target:".$an->data->{path}{striker_config},
				switches    => $an->data->{args}{rsync},
			});
			
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
			if (not $return_code)
			{
				# Write out the striker.conf file now.
				my $generated_ok = 0;
				   $shell_call   = "
if [ -s '".$an->data->{path}{striker_config}."' ];
then
    ".$an->data->{path}{echo}." 'config exists'
else
    ".$an->data->{path}{echo}." 'config does not exist'
fi
";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "target",     value1 => $target,
					name2 => "shell_call", value2 => $shell_call,
				}, file => $THIS_FILE, line => __LINE__});
				($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
					
					if ($line =~ /config exists/)
					{
						$generated_ok = 1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "generated_ok", value1 => $generated_ok,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				if ($generated_ok)
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "path::striker_config", value1 => $an->data->{path}{striker_config},
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Failed 
					$return_code = 4;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "return_code", value1 => $return_code,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		else
		{
			# Template striker.conf doesn't exist. Oops.
			$return_code = 3;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	else
	{
		# Config already exists
		$an->Log->entry({log_level => 2, message_key => "log_0036", message_variables => {
			node => $node, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $return_code)
	{
		# Add it to root's crontab.
		my $shell_call = "
if [ ! -e '".$an->data->{path}{nodes}{cron_root}."' ]
then
    ".$an->data->{path}{echo}." 'creating empty crontab for root.'
    ".$an->data->{path}{echo}." 'MAILTO=\"\"' > ".$an->data->{path}{nodes}{cron_root}."
    ".$an->data->{path}{echo}." \"# Disable these by calling them with the '--disable' switch. Do not comment them out.\"
    ".$an->data->{path}{'chown'}." root:root ".$an->data->{path}{nodes}{cron_root}."
    ".$an->data->{path}{'chmod'}." 600 ".$an->data->{path}{nodes}{cron_root}."
fi

".$an->data->{path}{'grep'}." -q ScanCore ".$an->data->{path}{nodes}{cron_root}."
if [ \"\$?\" -eq '0' ];
then
    ".$an->data->{path}{echo}." 'ScanCore exits'
else
    ".$an->data->{path}{echo}." \"Adding ScanCore to root's cron table.\"
    ".$an->data->{path}{echo}." '*/1 * * * * ".$an->data->{path}{nodes}{scancore}."' >> ".$an->data->{path}{nodes}{cron_root}."
fi

".$an->data->{path}{'grep'}." -q anvil-safe-start ".$an->data->{path}{nodes}{cron_root}."
if [ \"\$?\" -eq '0' ];
then
    ".$an->data->{path}{echo}." 'anvil-safe-start exits'
else
    ".$an->data->{path}{echo}." \"Adding 'anvil-safe-start' to root's cron table.\"
    ".$an->data->{path}{echo}." '*/1 * * * * ".$an->data->{path}{nodes}{'anvil-safe-start'}."' >> ".$an->data->{path}{nodes}{cron_root}."
fi

".$an->data->{path}{'grep'}." -q anvil-kick-apc-ups ".$an->data->{path}{nodes}{cron_root}."
if [ \"\$?\" -eq '0' ];
then
    ".$an->data->{path}{echo}." 'anvil-kick-apc-ups exits'
else
    ".$an->data->{path}{echo}." \"Adding 'anvil-kick-apc-ups' to root's cron table.\"
    ".$an->data->{path}{echo}." '*/1 * * * * ".$an->data->{path}{nodes}{'anvil-kick-apc-ups'}."' >> ".$an->data->{path}{nodes}{cron_root}."
fi
".$an->data->{path}{'grep'}." -q anvil-run-jobs ".$an->data->{path}{nodes}{cron_root}."
if [ \"\$?\" -eq '0' ];
then
    ".$an->data->{path}{echo}." 'anvil-run-jobs exits'
else
    ".$an->data->{path}{echo}." \"Adding 'anvil-run-jobs' to root's cron table.\"
    ".$an->data->{path}{echo}." '*/1 * * * * ".$an->data->{path}{'anvil-run-jobs'}."' >> ".$an->data->{path}{nodes}{cron_root}."
fi
";
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
	
	# Delete this so it doesn't interfere with node2
	delete $an->data->{used_db_host};
	
	# 0 == Success
	# 1 == Failed to download
	# 2 == Failed to extract
	# 3 == Base striker.conf not found.
	# 4 == Failed to create the striker.conf file.
	# 5 == Failed to add to root's crontab
	# 6 == ...free...
	# 7 == Host UUID is invalid
	# 8 == Target's ssh fingerprint changed.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "return_code", value1 => $return_code,
		name2 => "message",     value2 => $message,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code, $message);
}

# This does any needed SELinux configuration that is needed.
sub configure_selinux
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_selinux" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# For now, this always returns "success".
	my $ok                = 1;
	my $node1_return_code = 0;
	my $node2_return_code = 0;
	($node1_return_code) = $an->InstallManifest->configure_selinux_on_node({
			node     => $an->data->{sys}{anvil}{node1}{name}, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		}) if not $an->data->{node}{node1}{has_servers};
	($node2_return_code) = $an->InstallManifest->configure_selinux_on_node({
			node     => $an->data->{sys}{anvil}{node2}{name}, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
		}) if not $an->data->{node}{node2}{has_servers};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_return_code", value1 => $node1_return_code,
		name2 => "node2_return_code", value2 => $node2_return_code,
	}, file => $THIS_FILE, line => __LINE__});
	# 0 == Success
	# 1 == Failed
	
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0073!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0073!#";
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif ($node1_return_code eq "1")
	{
		$ok            = 0;
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0018!#";
	}
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif ($node2_return_code eq "1")
	{
		$ok            = 0;
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0018!#";
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0290!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This does the work of actually configuring SELinux on a node.
sub configure_selinux_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_selinux_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Create the backup directory if it doesn't exist yet.
	my $return_code = 0;
	my $shell_call  = "
if \$(".$an->data->{path}{nodes}{getsebool}." fenced_can_ssh | ".$an->data->{path}{nodes}{'grep'}." -q on); 
then 
    ".$an->data->{path}{echo}." 'Already allowed';
else 
    ".$an->data->{path}{echo}." \"Off, enabling 'fenced_can_ssh' now...\";
    ".$an->data->{path}{nodes}{setsebool}." -P fenced_can_ssh on
    if \$(".$an->data->{path}{nodes}{getsebool}." fenced_can_ssh | ".$an->data->{path}{nodes}{'grep'}." -q on); 
    then 
        ".$an->data->{path}{echo}." 'Now allowed.'
    else
        ".$an->data->{path}{echo}." \"Failed to allowe 'fenced_can_ssh'.\"
    fi
fi
";
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
		
		if ($line =~ /Failed/i)
		{
			$return_code = 1;
		}
	}
	
	# 0 == Success
	# 1 == Failed
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This creates the root user's id_rsa keys and then populates ~/.ssh/known_hosts on both nodes.
sub configure_ssh
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_ssh" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### NOTE: We run this on both nodes, regardless of whether they're hosting servers, because the 
	###       existing node needs to update for the new peer's fingerprint.
	# Three steps; 
	# 1. Get/generate RSA keys
	# 2. Populate known_hosts
	# 3. Add RSA keys to authorized_keys
	
	# Get/Generate RSA keys
	my $node1 = $an->data->{sys}{anvil}{node1}{name};
	my $node2 = $an->data->{sys}{anvil}{node2}{name};

	my ($node1_rsa) = $an->InstallManifest->get_node_rsa_public_key({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		});
	my ($node2_rsa) = $an->InstallManifest->get_node_rsa_public_key({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
		});
	
	# Populate known_hosts
	my ($node1_kh_ok) = $an->InstallManifest->populate_known_hosts_on_node({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		});
	my ($node2_kh_ok) = $an->InstallManifest->populate_known_hosts_on_node({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
		});
	
	# Add the rsa keys to the node's root user's authorized_keys file.
	my $node1_ak_ok = 255;
	my $node2_ak_ok = 255;
	if (($node1_rsa) && ($node2_rsa))
	{
		# Have RSA keys, check nodes.
		$an->Log->entry({log_level => 2, message_key => "log_0103", file => $THIS_FILE, line => __LINE__});
		($node1_ak_ok) = $an->InstallManifest->populate_authorized_keys_on_node({
				node      => $node1, 
				target    => $an->data->{sys}{anvil}{node1}{use_ip}, 
				port      => $an->data->{sys}{anvil}{node1}{use_port}, 
				password  => $an->data->{sys}{anvil}{node1}{password},
				node1_rsa => $node1_rsa,
				node2_rsa => $node2_rsa,
			});
		($node2_ak_ok) = $an->InstallManifest->populate_authorized_keys_on_node({
				node      => $node2, 
				target    => $an->data->{sys}{anvil}{node2}{use_ip}, 
				port      => $an->data->{sys}{anvil}{node2}{use_port}, 
				password  => $an->data->{sys}{anvil}{node2}{password},
				node1_rsa => $node1_rsa,
				node2_rsa => $node2_rsa,
			});
	}
	
	my $ok = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0029!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0029!#";
	# Node 1 
	if (not $node1_rsa)
	{
		# Failed to read/generate RSA key
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0079!#";
		$ok            = 0;
	}
	elsif (not $node1_kh_ok)
	{
		# Failed to populate known_hosts
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0080!#";
		$ok            = 0;
	}
	elsif (not $node1_ak_ok)
	{
		# Failed to populate authorized_keys
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0081!#";
		$ok            = 0;
	}
	# Node 2
	if (not $node2_rsa)
	{
		# Failed to read/generate RSA key
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0079!#";
		$ok            = 0;
	}
	elsif (not $node2_kh_ok)
	{
		# Failed to populate known_hosts
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0080!#";
		$ok            = 0;
	}
	elsif (not $node2_ak_ok)
	{
		# Failed to populate authorized_keys
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0081!#";
		$ok            = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0257!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This does the first stage of the storage configuration. Specifically, it partitions the drives. Systems 
# using one disk will need to reboot after this.
sub configure_storage_stage1
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_storage_stage1" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ok    = 1;
	my $node1 = $an->data->{sys}{anvil}{node1}{name};
	my $node2 = $an->data->{sys}{anvil}{node2}{name};
	
	# Make things a little easier to follow...
	my $node1_pool1_disk      = $an->data->{node}{$node1}{pool1}{disk};
	my $node1_pool1_partition = $an->data->{node}{$node1}{pool1}{partition};
	my $node1_pool2_disk      = $an->data->{node}{$node1}{pool2}{disk};
	my $node1_pool2_partition = $an->data->{node}{$node1}{pool2}{partition};
	my $node2_pool1_disk      = $an->data->{node}{$node2}{pool1}{disk};
	my $node2_pool1_partition = $an->data->{node}{$node2}{pool1}{partition};
	my $node2_pool2_disk      = $an->data->{node}{$node2}{pool2}{disk};
	my $node2_pool2_partition = $an->data->{node}{$node2}{pool2}{partition};
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
	
	# Before I start, I need to know if the partitions I plan to create already exist or not. They may
	# well exist if the install was restarted.
	$an->InstallManifest->get_partition_data_from_node({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
			disk     => $node1_pool1_disk,
		});
	$an->InstallManifest->get_partition_data_from_node({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
			disk     => $node2_pool1_disk,
		});
	
	# If an extended partition is needed on either node, create it/them now.
	my $node1_partition_type = "primary";
	my $node2_partition_type = "primary";
	# Node 1 extended.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node::${node1}::pool1::create_extended", value1 => $an->data->{node}{$node1}{pool1}{create_extended},
	}, file => $THIS_FILE, line => __LINE__});
	if (($an->data->{node}{$node1}{pool1}{create_extended}) && (not $an->data->{node}{node1}{has_servers}))
	{
		$node1_partition_type = "logical";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node1}::disk::${node1_pool1_disk}::partition::4::type", value1 => $an->data->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{4}{type},
			name2 => "node::${node1}::partition::4::type",                            value2 => $an->data->{node}{$node1}{partition}{4}{type},
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{4}{type}) && ($an->data->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{4}{type} eq "extended"))
		{
			# Already exists.
			$an->Log->entry({log_level => 2, message_key => "log_0173", message_variables => {
				node => $node1, 
				disk => $node1_pool1_disk, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (($an->data->{node}{$node1}{partition}{4}{type}) && ($an->data->{node}{$node1}{partition}{4}{type} eq "extended"))
		{
			# Extended partition already exists
			$an->Log->entry({log_level => 2, message_key => "log_0174", file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			my ($return_code) = $an->InstallManifest->create_partition_on_node({
					node           => $node1, 
					target         => $an->data->{sys}{anvil}{node1}{use_ip}, 
					port           => $an->data->{sys}{anvil}{node1}{use_port}, 
					password       => $an->data->{sys}{anvil}{node1}{password},
					disk           => $node1_pool1_disk, 
					type           => "extended", 
					partition_size => "all", 
				});
			
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
			if ($return_code eq "0")
			{
				# Failed
				$ok = 0;
				$an->Log->entry({log_level => 1, message_key => "log_0175", message_variables => {
					node => $node1, 
					disk => $node1_pool1_disk, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($return_code eq "2")
			{
				# Success. 
				$an->Log->entry({log_level => 2, message_key => "log_0176", message_variables => {
					node => $node1, 
					disk => $node1_pool1_disk, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	# Node 2 extended.
	if (($an->data->{node}{$node2}{pool1}{create_extended}) && (not $an->data->{node}{node2}{has_servers}))
	{
		$node2_partition_type = "logical";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node2}::disk::${node2_pool1_disk}::partition::4::type", value1 => $an->data->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{4}{type},
			name2 => "node::${node2}::partition::4::type",                            value2 => $an->data->{node}{$node2}{partition}{4}{type},
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{4}{type}) && ($an->data->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{4}{type} eq "extended"))
		{
			# Already exists.
			$an->Log->entry({log_level => 2, message_key => "log_0173", message_variables => {
				node => $node2, 
				disk => $node2_pool1_disk, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (($an->data->{node}{$node2}{partition}{4}{type}) && ($an->data->{node}{$node2}{partition}{4}{type} eq "extended"))
		{
			# Extended partition already exists
			$an->Log->entry({log_level => 2, message_key => "log_0174", file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			my ($return_code) = $an->InstallManifest->create_partition_on_node({
					node           => $node2, 
					target         => $an->data->{sys}{anvil}{node2}{use_ip}, 
					port           => $an->data->{sys}{anvil}{node2}{use_port}, 
					password       => $an->data->{sys}{anvil}{node2}{password},
					disk           => $node2_pool1_disk, 
					type           => "extended", 
					partition_size => "all", 
				});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
			if ($return_code eq "0")
			{
				# Failed
				$ok = 0;
				$an->Log->entry({log_level => 1, message_key => "log_0175", message_variables => {
					node => $node2, 
					disk => $node2_pool1_disk, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($return_code eq "2")
			{
				# Success
				$an->Log->entry({log_level => 2, message_key => "log_0176", message_variables => {
					node => $node1, 
					disk => $node1_pool1_disk, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	### Now on to real partitions.
	# Node 1
	my $node1_pool1_created = 0;
	my $node1_pool2_created = 0;
	my $node2_pool1_created = 0;
	my $node2_pool2_created = 0;
	
	# Node 1
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node::node1::has_servers", value1 => $an->data->{node}{node2}{has_servers},
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->data->{node}{node1}{has_servers})
	{
		# Pool 1.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node1}::disk::${node1_pool1_disk}::partition::${node1_pool1_partition}::size", value1 => $an->data->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{$node1_pool1_partition}{size},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{$node1_pool1_partition}{size})
		{
			# Already exists
			$node1_pool1_created = 2;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node1_pool1_created", value1 => $node1_pool1_created,
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Create node 1, pool 1.
			my ($return_code) = $an->InstallManifest->create_partition_on_node({
					node           => $node1, 
					target         => $an->data->{sys}{anvil}{node1}{use_ip}, 
					port           => $an->data->{sys}{anvil}{node1}{use_port}, 
					password       => $an->data->{sys}{anvil}{node1}{password},
					disk           => $node1_pool1_disk, 
					type           => $node1_partition_type, 
					partition_size => $an->data->{cgi}{anvil_storage_pool1_byte_size}, 
				});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
			if ($return_code eq "0")
			{
				# Failed
				$ok = 0;
				$an->Log->entry({log_level => 1, message_key => "log_0177", message_variables => {
					type    => $node1_partition_type, 
					pool    => "1", 
					node    => $node1, 
					disk    => $node1_pool1_disk, 
					size    => $an->data->{cgi}{anvil_storage_pool1_byte_size}, 
					hr_size => $an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool1_byte_size}}), 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($return_code eq "2")
			{
				# Succcess
				$node1_pool1_created = 1;
				$an->Log->entry({log_level => 1, message_key => "log_0178", message_variables => {
					type    => $node1_partition_type, 
					pool    => "1", 
					node    => $node1, 
					disk    => $node1_pool1_disk, 
					size    => $an->data->{cgi}{anvil_storage_pool1_byte_size}, 
					hr_size => $an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool1_byte_size}}), 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		# Pool 2.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_storage_pool2_byte_size", value1 => $an->data->{cgi}{anvil_storage_pool2_byte_size},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{anvil_storage_pool2_byte_size})
		{
			if ($an->data->{node}{$node1}{disk}{$node1_pool2_disk}{partition}{$node1_pool2_partition}{size})
			{
				# Already exists
				$node1_pool2_created = 2;
			}
			else
			{
				### TODO: Determine if it is better to always make the size of pool 2 "all".
				# Create node 1, pool 2.0
				my ($return_code) = $an->InstallManifest->create_partition_on_node({
						node           => $node1, 
						target         => $an->data->{sys}{anvil}{node1}{use_ip}, 
						port           => $an->data->{sys}{anvil}{node1}{use_port}, 
						password       => $an->data->{sys}{anvil}{node1}{password},
						disk           => $node1_pool2_disk, 
						type           => $node1_partition_type, 
						partition_size => $an->data->{cgi}{anvil_storage_pool2_byte_size}, 
					});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
				if ($return_code eq "0")
				{
					# Failed
					$ok = 0;
					$an->Log->entry({log_level => 1, message_key => "log_0177", message_variables => {
						type    => $node1_partition_type, 
						pool    => "2", 
						node    => $node1, 
						disk    => $node1_pool2_disk, 
						size    => $an->data->{cgi}{anvil_storage_pool2_byte_size}, 
						hr_size => $an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool2_byte_size} }), 
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($return_code eq "2")
				{
					# Succcess
					$node1_pool2_created = 1;
					$an->Log->entry({log_level => 2, message_key => "log_0178", message_variables => {
						type    => $node1_partition_type, 
						pool    => "2", 
						node    => $node1, 
						disk    => $node1_pool2_disk, 
						size    => $an->data->{cgi}{anvil_storage_pool2_byte_size}, 
						hr_size => $an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool2_byte_size} }), 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		else
		{
			$node1_pool2_created = 3;
		}
	}
	
	# Node 2
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node::node2::has_servers", value1 => $an->data->{node}{node2}{has_servers},
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->data->{node}{node2}{has_servers})
	{
		# Pool 1.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node2}::disk::${node2_pool1_disk}::partition::${node2_pool1_partition}::size", value1 => $an->data->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{$node2_pool1_partition}{size},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{$node2_pool1_partition}{size})
		{
			# Already exists
			$node2_pool1_created = 2;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node2_pool1_created", value1 => $node2_pool1_created,
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Create node 2, pool 1.
			my ($return_code) = $an->InstallManifest->create_partition_on_node({
					node           => $node2, 
					target         => $an->data->{sys}{anvil}{node2}{use_ip}, 
					port           => $an->data->{sys}{anvil}{node2}{use_port}, 
					password       => $an->data->{sys}{anvil}{node2}{password},
					disk           => $node2_pool1_disk, 
					type           => $node2_partition_type, 
					partition_size => $an->data->{cgi}{anvil_storage_pool1_byte_size}, 
				});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
			if ($return_code eq "0")
			{
				# Failed
				$ok = 0;
				$an->Log->entry({log_level => 1, message_key => "log_0177", message_variables => {
					type    => $node2_partition_type, 
					pool    => "1", 
					node    => $node2, 
					disk    => $node2_pool1_disk, 
					size    => $an->data->{cgi}{anvil_storage_pool1_byte_size}, 
					hr_size => $an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool1_byte_size}}), 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($return_code eq "2")
			{
				# Succcess
				$node2_pool1_created = 1;
				$an->Log->entry({log_level => 2, message_key => "log_0178", message_variables => {
					type    => $node2_partition_type, 
					pool    => "1", 
					node    => $node2, 
					disk    => $node2_pool1_disk, 
					size    => $an->data->{cgi}{anvil_storage_pool1_byte_size}, 
					hr_size => $an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool1_byte_size}}), 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		# Node 2, Pool 2.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_storage_pool2_byte_size", value1 => $an->data->{cgi}{anvil_storage_pool2_byte_size},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{cgi}{anvil_storage_pool2_byte_size})
		{
			if ($an->data->{node}{$node2}{disk}{$node2_pool2_disk}{partition}{$node2_pool2_partition}{size})
			{
				# Already exists
				$node2_pool2_created = 2;
			}
			else
			{
				### TODO: Determine if it is better to always make the size of pool 2 "all".
				# Create node 2, pool 2.
				my ($return_code) = $an->InstallManifest->create_partition_on_node({
						node           => $node2,
						target         => $an->data->{sys}{anvil}{node2}{use_ip}, 
						port           => $an->data->{sys}{anvil}{node2}{use_port}, 
						password       => $an->data->{sys}{anvil}{node2}{password},
						disk           => $node2_pool2_disk, 
						type           => $node2_partition_type, 
						partition_size => $an->data->{cgi}{anvil_storage_pool2_byte_size}, 
					});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
				if ($return_code eq "0")
				{
					# Failed
					$ok = 0;
					$an->Log->entry({log_level => 1, message_key => "log_0177", message_variables => {
						type    => $node2_partition_type, 
						pool    => "2", 
						node    => $node2, 
						disk    => $node2_pool2_disk, 
						size    => $an->data->{cgi}{anvil_storage_pool2_byte_size}, 
						hr_size => $an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool2_byte_size} }), 
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($return_code eq "2")
				{
					# Succcess
					$node2_pool2_created = 1;
					$an->Log->entry({log_level => 2, message_key => "log_0178", message_variables => {
						type    => $node2_partition_type, 
						pool    => "2", 
						node    => $node2, 
						disk    => $node2_pool2_disk, 
						size    => $an->data->{cgi}{anvil_storage_pool2_byte_size}, 
						hr_size => $an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool2_byte_size} }), 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		else
		{
			$node2_pool2_created = 3;
		}
	}
	
	# Default to 'created'.
	my $node1_pool1_class   = "highlight_good_bold";
	my $node1_pool1_message = "#!string!state_0045!#";
	my $node2_pool1_class   = "highlight_good_bold";
	my $node2_pool1_message = "#!string!state_0045!#";
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_pool1_class   = "highlight_note_bold";
		$node1_pool1_message = "#!string!state_0133!#";
	}
	elsif ($node1_pool1_created eq "0")
	{
		# Failed
		$node1_pool1_class   = "highlight_warning_bold";
		$node1_pool1_message = "#!string!state_0018!#",
		$ok                  = 0;
	}
	elsif ($node1_pool1_created eq "2")
	{
		# Already existed.
		$node1_pool1_message = "#!string!state_0020!#",
	}
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_pool1_class   = "highlight_note_bold";
		$node2_pool1_message = "#!string!state_0133!#";
	}
	elsif ($node2_pool1_created eq "0")
	{
		# Failed
		$node2_pool1_class   = "highlight_warning_bold";
		$node2_pool1_message = "#!string!state_0018!#",
		$ok                  = 0;
	}
	elsif ($node2_pool1_created eq "2")
	{
		# Already existed.
		$node2_pool1_message = "#!string!state_0020!#",
	}
	# Pool 1 message
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0246!#",
		node1_class	=>	$node1_pool1_class,
		node1_message	=>	$node1_pool1_message,
		node2_class	=>	$node2_pool1_class,
		node2_message	=>	$node2_pool1_message,
	}});
	
	return($ok);
}

sub configure_storage_stage2
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_storage_stage2" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1 = $an->data->{sys}{anvil}{node1}{name};
	my $node2 = $an->data->{sys}{anvil}{node2}{name};
	
	# Create the DRBD config files which will be stored in:
	# * $an->data->{drbd}{global_common}
	# * $an->data->{drbd}{r0}
	# * $an->data->{drbd}{r1}
	# If the config file(s) exist already on one of the nodes, they will be used instead.
	
	my ($return_code) = $an->InstallManifest->generate_drbd_config_files();
	# 0 = OK
	# 1 = Failed to determine the DRBD backing device(s);
	# 2 = Failed to determine the SN IPs.
	
	# Now setup DRBD on the nods.
	my $node1_pool1_return_code = 1;
	my $node1_pool2_return_code = 7;
	my $node2_pool1_return_code = 1;
	my $node2_pool2_return_code = 7;
	($node1_pool1_return_code, $node1_pool2_return_code) = $an->InstallManifest->setup_drbd_on_node({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		}) if not $an->data->{node}{node1}{has_servers};
	($node2_pool1_return_code, $node2_pool2_return_code) = $an->InstallManifest->setup_drbd_on_node({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
		}) if not $an->data->{node}{node2}{has_servers};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node1_pool1_return_code", value1 => $node1_pool1_return_code,
		name2 => "node1_pool2_return_code", value2 => $node1_pool2_return_code,
		name3 => "node2_pool1_return_code", value3 => $node2_pool1_return_code,
		name4 => "node2_pool2_return_code", value4 => $node2_pool2_return_code,
	}, file => $THIS_FILE, line => __LINE__});
	# 0 = Created
	# 1 = Already had meta-data, nothing done
	# 2 = Partition not found
	# 3 = No device passed.
	# 4 = Foreign signature found on device
	# 5 = Device doesn't match to a DRBD resource
	# 6 = DRBD resource not defined
	# 7 = N/A (no pool 2)
	
	### Tell the user how it went
	## Pool 1
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0045!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0045!#";
	my $show_lvm_note = 0;
	my $message       = "";
	# Node 1, Pool 1
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif ($node1_pool1_return_code eq "1")
	{
		# Already existed
		$node1_message = "#!string!state_0020!#";
	}
	elsif ($node1_pool1_return_code eq "2")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = $an->String->get({key => "state_0055", variables => { device => $an->data->{node}{$node1}{pool1}{device} }});
		$ok            = 0;
	}
	elsif ($node1_pool1_return_code eq "3")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0056!#";
		$ok            = 0;
	}
	elsif ($node1_pool1_return_code eq "4")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = $an->String->get({key => "state_0057", variables => { device => $an->data->{node}{$node1}{pool1}{device} }});
		$ok            = 0;
		$show_lvm_note = 1;
	}
	elsif ($node1_pool1_return_code eq "5")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = $an->String->get({key => "state_0058", variables => { device => $an->data->{node}{$node1}{pool1}{device} }});
		$ok            = 0;
	}
	elsif ($node1_pool1_return_code eq "6")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0059!#";
		$ok            = 0;
	}
	# Node 2, Pool 1
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif ($node2_pool1_return_code eq "1")
	{
		# Already existed
		$node2_message = "#!string!state_0020!#";
	}
	elsif ($node2_pool1_return_code eq "2")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = $an->String->get({key => "state_0055", variables => { device => $an->data->{node}{$node2}{pool1}{device} }});
		$ok            = 0;
	}
	elsif ($node2_pool1_return_code eq "3")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0056!#";
		$ok            = 0;
	}
	elsif ($node2_pool1_return_code eq "4")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = $an->String->get({key => "state_0057", variables => { device => $an->data->{node}{$node2}{pool1}{device} }});
		$show_lvm_note = 1;
		$ok            = 0;
	}
	elsif ($node2_pool1_return_code eq "5")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = $an->String->get({key => "state_0058", variables => { device => $an->data->{node}{$node2}{pool1}{device} }});
		$ok            = 0;
	}
	elsif ($node2_pool1_return_code eq "6")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0059!#";
		$ok            = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0249!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	if (not $ok)
	{
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
			message	=>	"#!string!message_0398!#",
			row	=>	"#!string!state_0034!#",
		}});
	}
	
	# Tell the user they may need to 'dd' the partition, if needed.
	if ($show_lvm_note)
	{
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-note-message", replace => { 
			message	=>	"#!string!message_0433!#",
			row	=>	"#!string!row_0032!#",
		}});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

### BUG: This tries to stop a node that was in the cluster when the run started! Fix it.

# This manually starts DRBD, forcing one to primary if needed, configures clvmd, sets up the PVs and VGs, 
# creates the /shared LV, creates the GFS2 partition and configures fstab.
sub configure_storage_stage3
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "configure_storage_stage3" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ok    = 1;
	my $node1 = $an->data->{sys}{anvil}{node1}{name};
	my $node2 = $an->data->{sys}{anvil}{node2}{name};
	
	# Bring up DRBD
	my ($drbd_ok) = $an->InstallManifest->drbd_first_start();
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "drbd_ok", value1 => $drbd_ok,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Start clustered LVM
	my $lvm_ok = 0;
	if ($drbd_ok)
	{
		# This will create the /dev/drbd{0,1} PVs and create the VGs on them, if needed.
		($lvm_ok) = $an->InstallManifest->setup_lvm_pv_and_vgs();
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "lvm_ok", value1 => $lvm_ok,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Create GFS2 partition
		my $gfs2_ok = 0;
		if ($lvm_ok)
		{
			($gfs2_ok) = $an->InstallManifest->setup_gfs2({
					node     => $node1, 
					target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
					port     => $an->data->{sys}{anvil}{node1}{use_port}, 
					password => $an->data->{sys}{anvil}{node1}{password},
				});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "gfs2_ok", value1 => $gfs2_ok,
			}, file => $THIS_FILE, line => __LINE__});
			# Create /shared, mount partition Appeand gfs2 entry to fstab Check that 
			# /etc/init.d/gfs2 status works
			
			if ($gfs2_ok)
			{
				# Start gfs2 on both nodes, including subdirectories and SELinux contexts on
				# /shared.
				my ($configure_ok) = $an->InstallManifest->configure_gfs2();
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "configure_ok", value1 => $configure_ok,
				}, file => $THIS_FILE, line => __LINE__});
				
				### Stop everything now.
				# gfs2
				my $gfs2_node1_return_code = 0;
				my $gfs2_node2_return_code = 0;
				($gfs2_node1_return_code) = $an->InstallManifest->stop_service_on_node({
						node     => $node1, 
						target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
						port     => $an->data->{sys}{anvil}{node1}{use_port}, 
						password => $an->data->{sys}{anvil}{node1}{password},
						service  => "gfs2",
					}) if not $an->data->{node}{node1}{has_servers};
				($gfs2_node2_return_code) = $an->InstallManifest->stop_service_on_node({
						node     => $node2, 
						target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
						port     => $an->data->{sys}{anvil}{node2}{use_port}, 
						password => $an->data->{sys}{anvil}{node2}{password},
						service  => "gfs2",
					}) if not $an->data->{node}{node2}{has_servers};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "gfs2_node1_return_code", value1 => $gfs2_node1_return_code, 
					name2 => "gfs2_node2_return_code", value2 => $gfs2_node2_return_code, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# clvmd
				my $clvmd_node1_return_code = 0;
				my $clvmd_node2_return_code = 0;
				($clvmd_node1_return_code) = $an->InstallManifest->stop_service_on_node({
						node     => $node1, 
						target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
						port     => $an->data->{sys}{anvil}{node1}{use_port}, 
						password => $an->data->{sys}{anvil}{node1}{password},
						service  => "clvmd",
					}) if not $an->data->{node}{node1}{has_servers};
				($clvmd_node2_return_code) = $an->InstallManifest->stop_service_on_node({
						node     => $node2, 
						target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
						port     => $an->data->{sys}{anvil}{node2}{use_port}, 
						password => $an->data->{sys}{anvil}{node2}{password},
						service  => "clvmd",
					}) if not $an->data->{node}{node2}{has_servers};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "clvmd_node1_return_code", value1 => $clvmd_node1_return_code, 
					name2 => "clvmd_node2_return_code", value2 => $clvmd_node2_return_code, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# This looks at the Disk State and stops the resources intelligently 
				# (SyncTarget before SyncSource).
				$ok = $an->InstallManifest->stop_drbd();
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "ok", value1 => $ok, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# das failed ;_;
				$ok = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "ok", value1 => $ok, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		else
		{
			# Oh the huge manatee!
			$ok = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "ok", value1 => $ok, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	else
	{
		$ok = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "ok", value1 => $ok, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	if ($ok)
	{
		# Start rgmanager, making sure it comes up
		my $node1_return_code = 2;
		my $node2_return_code = 2;
		($node1_return_code) = $an->InstallManifest->set_daemon_state({
				node     => $node1, 
				target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node1}{use_port}, 
				password => $an->data->{sys}{anvil}{node1}{password},
				daemon   => "rgmanager",
				'state'  => "start",
			}) if not $an->data->{node}{node1}{has_servers};
		($node2_return_code) = $an->InstallManifest->set_daemon_state({
				node     => $node2, 
				target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node2}{use_port}, 
				password => $an->data->{sys}{anvil}{node2}{password},
				daemon   => "rgmanager",
				'state'  => "start",
			}) if not $an->data->{node}{node2}{has_servers};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node1_return_code", value1 => $node1_return_code,
			name2 => "node2_return_code", value2 => $node2_return_code,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Go into a loop waiting for the rgmanager services to either start or fail.
		my $node_key = "node1";
		if ($an->data->{node}{node1}{has_servers})
		{
			$node_key = "node2";
		}
		my ($clustat_ok) = $an->InstallManifest->watch_clustat({
				node     => $an->data->{sys}{anvil}{$node_key}{name}, 
				target   => $an->data->{sys}{anvil}{$node_key}{use_ip}, 
				port     => $an->data->{sys}{anvil}{$node_key}{use_port}, 
				password => $an->data->{sys}{anvil}{$node_key}{password},
			});
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "clustat_ok", value1 => $clustat_ok,
		}, file => $THIS_FILE, line => __LINE__});
		if (not $clustat_ok)
		{
			$an->Log->entry({log_level => 1, message_key => "log_0268", file => $THIS_FILE, line => __LINE__});
			
			my $rgmanager_node1_return_code = 0;
			my $rgmanager_node2_return_code = 0;
			($rgmanager_node1_return_code) = $an->InstallManifest->stop_service_on_node({
					node     => $node1, 
					target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
					port     => $an->data->{sys}{anvil}{node1}{use_port}, 
					password => $an->data->{sys}{anvil}{node1}{password},
					service  => "rgmanager",
				}) if not $an->data->{node}{node1}{has_servers};
			($rgmanager_node2_return_code) = $an->InstallManifest->stop_service_on_node({
					node     => $node2, 
					target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
					port     => $an->data->{sys}{anvil}{node2}{use_port}, 
					password => $an->data->{sys}{anvil}{node2}{password},
					service  => "rgmanager",
				}) if not $an->data->{node}{node2}{has_servers};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "rgmanager_node1_return_code", value1 => $rgmanager_node1_return_code, 
				name2 => "rgmanager_node2_return_code", value2 => $rgmanager_node2_return_code, 
			}, file => $THIS_FILE, line => __LINE__});
			
			sleep 10;
			
			my $node1_return_code = 0;
			my $node2_return_code = 0;
			($node1_return_code) = $an->InstallManifest->set_daemon_state({
					node     => $node1, 
					target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
					port     => $an->data->{sys}{anvil}{node1}{use_port}, 
					password => $an->data->{sys}{anvil}{node1}{password},
					daemon   => "rgmanager",
					'state'  => "start",
				}) if not $an->data->{node}{node1}{has_servers};
			($node2_return_code) = $an->InstallManifest->set_daemon_state({
					node     => $node2, 
					target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
					port     => $an->data->{sys}{anvil}{node2}{use_port}, 
					password => $an->data->{sys}{anvil}{node2}{password},
					daemon   => "rgmanager",
					'state'  => "start",
				}) if not $an->data->{node}{node2}{has_servers};
			
			# Go into a loop waiting for the rgmanager services to either start or fail.
			my ($clustat_ok) = $an->InstallManifest->watch_clustat({
					node     => $an->data->{sys}{anvil}{$node_key}{name}, 
					target   => $an->data->{sys}{anvil}{$node_key}{use_ip}, 
					port     => $an->data->{sys}{anvil}{$node_key}{use_port}, 
					password => $an->data->{sys}{anvil}{$node_key}{password},
				});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "clustat_ok", value1 => $clustat_ok,
			}, file => $THIS_FILE, line => __LINE__});
			if ($clustat_ok)
			{
				# \o/
				$an->Log->entry({log_level => 1, message_key => "log_0269", file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				$an->Log->entry({log_level => 1, message_key => "log_0042", file => $THIS_FILE, line => __LINE__});
				$ok = 0;
			}
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This shows a summary of the install manifest and asks the user to choose a node to run it against 
# (verifying they want to do it in the process).
sub confirm_install_manifest_run
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "confirm_install_manifest_run" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Show the manifest form.
	$an->data->{cgi}{anvil_node1_bcn_link1_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node1_bcn_link1_mac};
	$an->data->{cgi}{anvil_node1_bcn_link2_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node1_bcn_link2_mac};
	$an->data->{cgi}{anvil_node1_sn_link1_mac}  = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node1_sn_link1_mac};
	$an->data->{cgi}{anvil_node1_sn_link2_mac}  = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node1_sn_link2_mac};
	$an->data->{cgi}{anvil_node1_ifn_link1_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node1_ifn_link1_mac};
	$an->data->{cgi}{anvil_node1_ifn_link2_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node1_ifn_link2_mac};
	$an->data->{cgi}{anvil_node2_bcn_link1_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node2_bcn_link1_mac};
	$an->data->{cgi}{anvil_node2_bcn_link2_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node2_bcn_link2_mac};
	$an->data->{cgi}{anvil_node2_sn_link1_mac}  = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node2_sn_link1_mac};
	$an->data->{cgi}{anvil_node2_sn_link2_mac}  = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node2_sn_link2_mac};
	$an->data->{cgi}{anvil_node2_ifn_link1_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node2_ifn_link1_mac};
	$an->data->{cgi}{anvil_node2_ifn_link2_mac} = "<span class=\"highlight_unavailable\">#!string!message_0352!#</span>" if not $an->data->{cgi}{anvil_node2_ifn_link2_mac};
	
	$an->data->{cgi}{anvil_node1_pdu1_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_node1_pdu1_outlet};
	$an->data->{cgi}{anvil_node1_pdu2_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_node1_pdu2_outlet};
	$an->data->{cgi}{anvil_node1_pdu3_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_node1_pdu3_outlet};
	$an->data->{cgi}{anvil_node1_pdu4_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_node1_pdu4_outlet};
	$an->data->{cgi}{anvil_node2_pdu1_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_node2_pdu1_outlet};
	$an->data->{cgi}{anvil_node2_pdu2_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_node2_pdu2_outlet};
	$an->data->{cgi}{anvil_node2_pdu3_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_node2_pdu3_outlet};
	$an->data->{cgi}{anvil_node2_pdu4_outlet}   = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_node2_pdu4_outlet};
	$an->data->{cgi}{anvil_dns1}                = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_dns1};
	$an->data->{cgi}{anvil_dns2}                = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_dns2};
	$an->data->{cgi}{anvil_ntp1}                = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_ntp1};
	$an->data->{cgi}{anvil_ntp2}                = "<span class=\"highlight_unavailable\">--</span>" if not $an->data->{cgi}{anvil_ntp2};
	
	# If the first storage pool is a percentage, calculate the percentage of the second. Otherwise, set
	# storage pool 2 to just same 'remainder'.
	my $say_storage_pool_1 = $an->data->{cgi}{anvil_storage_pool1_size}." ".$an->data->{cgi}{anvil_storage_pool1_unit};
	my $say_storage_pool_2 = "<span class=\"highlight_unavailable\">#!string!message_0357!#</span>";
	if ($an->data->{cgi}{anvil_storage_pool1_unit} eq "%")
	{
		$say_storage_pool_2 = (100 - $an->data->{cgi}{anvil_storage_pool1_size})." %";
	}
	
	# If this is the first load, the use the current IP and password.
	$an->data->{sys}{anvil}{node1}{use_ip}       = $an->data->{cgi}{anvil_node1_bcn_ip} if not $an->data->{sys}{anvil}{node1}{use_ip};;
	$an->data->{sys}{anvil}{node1}{password} = $an->data->{sys}{anvil}{password}     if not $an->data->{sys}{anvil}{node1}{password};
	$an->data->{sys}{anvil}{node2}{use_ip}       = $an->data->{cgi}{anvil_node2_bcn_ip} if not $an->data->{sys}{anvil}{node2}{use_ip};
	$an->data->{sys}{anvil}{node2}{password} = $an->data->{sys}{anvil}{password}     if not $an->data->{sys}{anvil}{node2}{password};
	
	# I don't ask the user for the port range at this time, so it is possible the number of ports to open
	# isn't in the manifest.
	$an->data->{cgi}{anvil_open_vnc_ports} = $an->data->{sys}{install_manifest}{open_vnc_ports} if not $an->data->{cgi}{anvil_open_vnc_ports};
	
	# NOTE: Dropping support for repos.
	my $say_repos = "<input type=\"hidden\" name=\"anvil_repositories\" id=\"anvil_repositories\" value=\"".$an->data->{cgi}{anvil_repositories}."\" />";
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::anvil_node1_name", value1 => $an->data->{cgi}{anvil_node1_name},
		name2 => "cgi::anvil_node2_name", value2 => $an->data->{cgi}{anvil_node2_name},
	}, file => $THIS_FILE, line => __LINE__});
	print $an->Web->template({file => "config.html", template => "confirm-anvil-manifest-run", replace => { 
		form_file			=>	"/cgi-bin/configure",
		manifest_uuid			=>	$an->data->{cgi}{manifest_uuid},
		say_storage_pool_1		=>	$say_storage_pool_1,
		say_storage_pool_2		=>	$say_storage_pool_2,
		anvil_node1_current_ip		=>	$an->data->{cgi}{anvil_node1_bcn_ip},
		anvil_node1_current_password	=>	$an->data->{cgi}{anvil_password},
		anvil_node1_uuid		=>	$an->data->{cgi}{anvil_node1_uuid},
		anvil_node2_current_ip		=>	$an->data->{cgi}{anvil_node2_bcn_ip},
		anvil_node2_current_password	=>	$an->data->{cgi}{anvil_password},
		anvil_node2_uuid		=>	$an->data->{cgi}{anvil_node2_uuid},
		anvil_password			=>	$an->data->{cgi}{anvil_password},
		anvil_bcn_ethtool_opts		=>	$an->data->{cgi}{anvil_bcn_ethtool_opts}, 
		anvil_bcn_network		=>	$an->data->{cgi}{anvil_bcn_network},
		anvil_bcn_subnet		=>	$an->data->{cgi}{anvil_bcn_subnet},
		anvil_sn_ethtool_opts		=>	$an->data->{cgi}{anvil_sn_ethtool_opts}, 
		anvil_sn_network		=>	$an->data->{cgi}{anvil_sn_network},
		anvil_sn_subnet			=>	$an->data->{cgi}{anvil_sn_subnet},
		anvil_ifn_ethtool_opts		=>	$an->data->{cgi}{anvil_ifn_ethtool_opts}, 
		anvil_ifn_network		=>	$an->data->{cgi}{anvil_ifn_network},
		anvil_ifn_subnet		=>	$an->data->{cgi}{anvil_ifn_subnet},
		anvil_media_library_size	=>	$an->data->{cgi}{anvil_media_library_size},
		anvil_media_library_unit	=>	$an->data->{cgi}{anvil_media_library_unit},
		anvil_storage_pool1_size	=>	$an->data->{cgi}{anvil_storage_pool1_size},
		anvil_storage_pool1_unit	=>	$an->data->{cgi}{anvil_storage_pool1_unit},
		anvil_name			=>	$an->data->{cgi}{anvil_name},
		anvil_node1_name		=>	$an->data->{cgi}{anvil_node1_name},
		anvil_node1_bcn_ip		=>	$an->data->{cgi}{anvil_node1_bcn_ip},
		anvil_node1_bcn_link1_mac	=>	$an->data->{cgi}{anvil_node1_bcn_link1_mac},
		anvil_node1_bcn_link2_mac	=>	$an->data->{cgi}{anvil_node1_bcn_link2_mac},
		anvil_node1_ipmi_ip		=>	$an->data->{cgi}{anvil_node1_ipmi_ip},
		anvil_node1_sn_ip		=>	$an->data->{cgi}{anvil_node1_sn_ip},
		anvil_node1_sn_link1_mac	=>	$an->data->{cgi}{anvil_node1_sn_link1_mac},
		anvil_node1_sn_link2_mac	=>	$an->data->{cgi}{anvil_node1_sn_link2_mac},
		anvil_node1_ifn_ip		=>	$an->data->{cgi}{anvil_node1_ifn_ip},
		anvil_node1_ifn_link1_mac	=>	$an->data->{cgi}{anvil_node1_ifn_link1_mac},
		anvil_node1_ifn_link2_mac	=>	$an->data->{cgi}{anvil_node1_ifn_link2_mac},
		anvil_node1_pdu1_outlet		=>	$an->data->{cgi}{anvil_node1_pdu1_outlet},
		anvil_node1_pdu2_outlet		=>	$an->data->{cgi}{anvil_node1_pdu2_outlet},
		anvil_node1_pdu3_outlet		=>	$an->data->{cgi}{anvil_node1_pdu3_outlet},
		anvil_node1_pdu4_outlet		=>	$an->data->{cgi}{anvil_node1_pdu4_outlet},
		anvil_node2_name		=>	$an->data->{cgi}{anvil_node2_name},
		anvil_node2_bcn_ip		=>	$an->data->{cgi}{anvil_node2_bcn_ip},
		anvil_node2_bcn_link1_mac	=>	$an->data->{cgi}{anvil_node2_bcn_link1_mac},
		anvil_node2_bcn_link2_mac	=>	$an->data->{cgi}{anvil_node2_bcn_link2_mac},
		anvil_node2_ipmi_ip		=>	$an->data->{cgi}{anvil_node2_ipmi_ip},
		anvil_node2_sn_ip		=>	$an->data->{cgi}{anvil_node2_sn_ip},
		anvil_node2_sn_link1_mac	=>	$an->data->{cgi}{anvil_node2_sn_link1_mac},
		anvil_node2_sn_link2_mac	=>	$an->data->{cgi}{anvil_node2_sn_link2_mac},
		anvil_node2_ifn_ip		=>	$an->data->{cgi}{anvil_node2_ifn_ip},
		anvil_node2_ifn_link1_mac	=>	$an->data->{cgi}{anvil_node2_ifn_link1_mac},
		anvil_node2_ifn_link2_mac	=>	$an->data->{cgi}{anvil_node2_ifn_link2_mac},
		anvil_node2_pdu1_outlet		=>	$an->data->{cgi}{anvil_node2_pdu1_outlet},
		anvil_node2_pdu2_outlet		=>	$an->data->{cgi}{anvil_node2_pdu2_outlet},
		anvil_node2_pdu3_outlet		=>	$an->data->{cgi}{anvil_node2_pdu3_outlet},
		anvil_node2_pdu4_outlet		=>	$an->data->{cgi}{anvil_node2_pdu4_outlet},
		anvil_ifn_gateway		=>	$an->data->{cgi}{anvil_ifn_gateway},
		anvil_dns1			=>	$an->data->{cgi}{anvil_dns1},
		anvil_dns2			=>	$an->data->{cgi}{anvil_dns2},
		anvil_ntp1			=>	$an->data->{cgi}{anvil_ntp1},
		anvil_ntp2			=>	$an->data->{cgi}{anvil_ntp2},
		anvil_pdu1_name			=>	$an->data->{cgi}{anvil_pdu1_name},
		anvil_pdu2_name			=>	$an->data->{cgi}{anvil_pdu2_name},
		anvil_pdu3_name			=>	$an->data->{cgi}{anvil_pdu3_name},
		anvil_pdu4_name			=>	$an->data->{cgi}{anvil_pdu4_name},
		anvil_open_vnc_ports		=>	$an->data->{cgi}{anvil_open_vnc_ports},
		say_anvil_repos			=>	$say_repos,
		run				=>	$an->data->{cgi}{run},
		striker_user			=>	$an->data->{cgi}{striker_user},
		striker_database		=>	$an->data->{cgi}{striker_database},
		anvil_striker1_user		=>	$an->data->{cgi}{anvil_striker1_user},
		anvil_striker1_password		=>	$an->data->{cgi}{anvil_striker1_password},
		anvil_striker1_database		=>	$an->data->{cgi}{anvil_striker1_database},
		anvil_striker2_user		=>	$an->data->{cgi}{anvil_striker2_user},
		anvil_striker2_password		=>	$an->data->{cgi}{anvil_striker2_password},
		anvil_striker2_database		=>	$an->data->{cgi}{anvil_striker2_database},
		anvil_mtu_size			=>	$an->data->{cgi}{anvil_mtu_size},
	}});
	
	return(0);
}

# This function first tries to ping a node. If the ping is successful, it will try to log into the node..
sub connect_to_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "connect_to_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# 0 = Successfully logged in
	# 1 = Could ping, but couldn't log in
	# 2 = Couldn't ping.
	my $return_code = 2;
	
	# 1 == pinged, 0 == failed.
	my ($ping) = $an->Check->ping({ping => $target, count => 3});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ping", value1 => $ping, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($ping)
	{
		# Pingable! Can we log in?
		$an->Log->entry({log_level => 2, message_key => "log_0162", message_variables => { node => "$node ($target)" }, file => $THIS_FILE, line => __LINE__});
		   $return_code = 1;
		my ($access)    = $an->Check->access({
				target   => $target, 
				port     => $port,
				password => $password,
			});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "access", value1 => $access, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($access)
		{
			# We're in!
			$return_code = 0;
			$an->Log->entry({log_level => 2, message_key => "log_0163", message_variables => {
				node => $node, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Pingable, but not accessible yet.
			$an->Log->entry({log_level => 1, message_key => "log_0164", message_variables => {
				node => $node, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This creates the VGs if needed
sub create_lvm_vgs
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "create_lvm_vgs" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If a VG name exists, use it. Otherwise, use the generated names below.
	my ($node1_short_name)             = ($an->data->{sys}{anvil}{node1}{name} =~ /^(.*?)\./);
	my ($node2_short_name)             = ($an->data->{sys}{anvil}{node2}{name} =~ /^(.*?)\./);
	   $an->data->{sys}{vg_pool1_name} = "${node1_short_name}_vg0";
	   $an->data->{sys}{vg_pool2_name} = "${node2_short_name}_vg0";
	
	# Check which, if any, VGs exist.
	my $return_code = 0;
	my $create_vg0  = 1;
	my $create_vg1  = $an->data->{cgi}{anvil_storage_pool2_byte_size} ? 1 : 0;
	
	# Calling 'pvs' again, but this time we're digging out the VG name
	my $shell_call   = $an->data->{path}{pvs}." --noheadings --separator ,; ".$an->data->{path}{echo}." return_code:\$?";
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^return_code:(\d+)/)
		{
			my $return_code = $1;
			if ($return_code ne "0")
			{
				# pvs failed...
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
				$create_vg0  = 0;
				$create_vg1  = 0;
				$return_code = 2;
			}
		}
		if ($return_code ne "2")
		{
			if ($line =~ /\/dev\/drbd0,,/)
			{
				# VG on r0 doesn't exist, create it.
				$create_vg0 = 1;
				$an->Log->entry({log_level => 2, message_key => "log_0064", message_variables => {
					pool   => "1",
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /\/dev\/drbd0,(.*?),/)
			{
				# VG on r0 doesn't exist, create it.
				$an->data->{sys}{vg_pool1_name} = $1;
				$create_vg0                 = 0;
				$an->Log->entry({log_level => 2, message_key => "log_0065", message_variables => {
					pool   => "1",
					device => $an->data->{sys}{vg_pool1_name}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /\/dev\/drbd1,,/)
			{
				# VG on r0 doesn't exist, create it.
				$create_vg1 = 1;
				$an->Log->entry({log_level => 2, message_key => "log_0064", message_variables => {
					pool   => "2",
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /\/dev\/drbd1,(.*?),/)
			{
				# VG on r0 doesn't exist, create it.
				$an->data->{sys}{vg_pool2_name} = $1;
				$create_vg1                 = 0;
				$an->Log->entry({log_level => 2, message_key => "log_0065", message_variables => {
					pool   => "2",
					device => $an->data->{sys}{vg_pool1_name}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Create the PVs if needed.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "create_vg0", value1 => $create_vg0,
		name2 => "create_vg1", value2 => $create_vg1,
	}, file => $THIS_FILE, line => __LINE__});
	# PV for pool 1
	if ($create_vg0)
	{
		my $shell_call = $an->data->{path}{vgcreate}." ".$an->data->{sys}{vg_pool1_name}." /dev/drbd0; ".$an->data->{path}{echo}." return_code:\$?";
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
			
			if ($line =~ /^return_code:(\d+)/)
			{
				my $return_code = $1;
				if ($return_code eq "0")
				{
					# Success
					$an->Log->entry({log_level => 2, message_key => "log_0066", message_variables => {
						pool   => "1", 
						device => $an->data->{sys}{vg_pool1_name}, 
						pv     => "/dev/drbd0",
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Failed
					$an->Log->entry({log_level => 1, message_key => "log_0067", message_variables => {
						pool        => "1", 
						device      => $an->data->{sys}{vg_pool1_name}, 
						pv          => "/dev/drbd0",
						return_code => $return_code, 
					}, file => $THIS_FILE, line => __LINE__});
					$return_code = 2;
				}
			}
		}
	}
	# PV for pool 2
	if (($an->data->{cgi}{anvil_storage_pool2_byte_size}) && ($create_vg1))
	{
		my $shell_call = $an->data->{path}{vgcreate}." ".$an->data->{sys}{vg_pool2_name}." /dev/drbd1; ".$an->data->{path}{echo}." return_code:\$?";
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
			
			if ($line =~ /^return_code:(\d+)/)
			{
				my $return_code = $1;
				if ($return_code eq "0")
				{
					# Success
					$an->Log->entry({log_level => 2, message_key => "log_0066", message_variables => {
						pool   => "2", 
						device => $an->data->{sys}{vg_pool1_name}, 
						pv     => "/dev/drbd1",
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Failed
					$an->Log->entry({log_level => 1, message_key => "log_0067", message_variables => {
						pool        => "2", 
						device      => $an->data->{sys}{vg_pool1_name}, 
						pv          => "/dev/drbd1",
						return_code => $return_code, 
					}, file => $THIS_FILE, line => __LINE__});
					$return_code = 2;
				}
			}
		}
	}
	if (($return_code ne "2") && (not $create_vg0) && (not $create_vg1))
	{
		# Both LVM VGs already existed.
		$an->Log->entry({log_level => 2, message_key => "log_0068", file => $THIS_FILE, line => __LINE__});
		$return_code = 1;
	}
	
	# 0 == OK
	# 1 == already existed
	# 2 == Failed
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This creates the PVs if needed
sub create_lvm_pvs
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "create_lvm_pvs" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: This seems to occassionally see only the first PV despite both existing. Unable to 
	###       reproduce on the shell.
	# Check which, if any, PVs exist.
	my $return_code  = 0;
	my $found_drbd0  = 0;
	my $create_drbd0 = 1;
	my $found_drbd1  = 0;
	my $create_drbd1 = $an->data->{cgi}{anvil_storage_pool2_byte_size} ? 1 : 0;
	my $shell_call   = $an->data->{path}{pvscan}."; ".$an->data->{path}{echo}." return_code:\$?";
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^return_code:(\d+)/)
		{
			my $return_code = $1;
			if ($return_code ne "0")
			{
				# pvs failed...
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
				$create_drbd0 = 0;
				$create_drbd1 = 0;
				$return_code  = 2;
			}
		}
		if ($line =~ /\/dev\/drbd0 /)
		{
			# Already a PV
			$found_drbd0  = 1;
			$create_drbd0 = 0;
			$an->Log->entry({log_level => 2, message_key => "log_0069", message_variables => {
				device => "/dev/drbd0", 
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /\/dev\/drbd1 /)
		{
			# Already a PV
			$found_drbd1  = 1;
			$create_drbd1 = 0;
			$an->Log->entry({log_level => 2, message_key => "log_0069", message_variables => {
				device => "/dev/drbd1", 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Create the PVs if needed.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "found_drbd0", value1 => $found_drbd0,
		name2 => "found_drbd1", value2 => $found_drbd1,
	}, file => $THIS_FILE, line => __LINE__});
	# PV for pool 1
	if ($create_drbd0)
	{
		my $shell_call = $an->data->{path}{pvcreate}." /dev/drbd0; ".$an->data->{path}{echo}." return_code:\$?";
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
			
			if ($line =~ /^return_code:(\d+)/)
			{
				my $return_code = $1;
				if ($return_code eq "0")
				{
					# Success
					$an->Log->entry({log_level => 2, message_key => "log_0070", message_variables => {
						device => "/dev/drbd0", 
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Failed
					$an->Log->entry({log_level => 1, message_key => "log_0071", message_variables => {
						device      => "/dev/drbd0", 
						return_code => $return_code, 
					}, file => $THIS_FILE, line => __LINE__});
					$return_code = 2;
				}
			}
		}
	}
	# PV for pool 2
	if (($an->data->{cgi}{anvil_storage_pool2_byte_size}) && ($create_drbd1))
	{
		my $shell_call = $an->data->{path}{pvcreate}." /dev/drbd1; ".$an->data->{path}{echo}." return_code:\$?";
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
			
			if ($line =~ /^return_code:(\d+)/)
			{
				my $return_code = $1;
				if ($return_code eq "0")
				{
					# Success
					$an->Log->entry({log_level => 2, message_key => "log_0070", message_variables => {
						device => "/dev/drbd1", 
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Failed
					$an->Log->entry({log_level => 1, message_key => "log_0071", message_variables => {
						device      => "/dev/drbd1", 
						return_code => $return_code, 
					}, file => $THIS_FILE, line => __LINE__});
					$return_code = 2;
				}
			}
		}
	}
	if (($found_drbd0) && ($found_drbd1))
	{
		# Both already exist
		$an->Log->entry({log_level => 2, message_key => "log_0072", file => $THIS_FILE, line => __LINE__});
		$return_code = 1;
	}
	elsif (($found_drbd0) && (not $an->data->{cgi}{anvil_storage_pool2_byte_size}))
	{
		# Pool 1 already exists and pool 2 isn't used.
		$an->Log->entry({log_level => 2, message_key => "log_0073", file => $THIS_FILE, line => __LINE__});
		$return_code = 1;
	}
	
	# 0 == OK
	# 1 == already existed
	# 2 == Failed
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This performs an actual partition creation
sub create_partition_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "create_partition_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $disk           = $parameter->{disk}           ? $parameter->{disk}           : "";
	my $type           = $parameter->{type}           ? $parameter->{type}           : "";
	my $partition_size = $parameter->{partition_size} ? $parameter->{partition_size} : "";
	my $node           = $parameter->{node}           ? $parameter->{node}           : "";
	my $target         = $parameter->{target}         ? $parameter->{target}         : "";
	my $port           = $parameter->{port}           ? $parameter->{port}           : "";
	my $password       = $parameter->{password}       ? $parameter->{password}       : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "disk",           value1 => $disk, 
		name2 => "type",           value2 => $type, 
		name3 => "partition_size", value3 => $partition_size, 
		name4 => "node",           value4 => $node, 
		name5 => "target",         value5 => $target, 
		name6 => "port",           value6 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Just for logging...
	if ($partition_size =~ /^\d+$/)
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "partition_size", value1 => $partition_size." (".$an->Readable->bytes_to_hr({'bytes' => $partition_size }).")", 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	my $created = 0;
	my $ok      = 1;
	my $start   = 0;
	my $end     = 0;
	my $size    = 0;
	### NOTE: Parted, in its infinite wisdom, doesn't show the partition type when called with --machine
	#my $shell_call = "parted --machine /dev/$disk unit GiB print free";
	my $shell_call = $an->data->{path}{parted}." /dev/$disk unit GiB print free";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target     => $target,
		port       => $port, 
		password   => $password,
		shell_call => $shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node",   value1 => $node,
			name2 => "disk",   value2 => $disk,
			name3 => "return", value3 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		
		# If I am creating a logical partition, then I want to find the start of the free space 
		# inside 'extended'. Otherwise, I want the actual free space.
		if ($type eq "logical")
		{
			# I want to use the start of the extended partition, *unless* there is already a 
			# logical partition. If there is a logical partition, we will use it's end as the new
			# partition's start.
			if ($line =~ /([\d\.]+)GiB ([\d\.]+)GiB ([\d\.]+)GiB extended/)
			{
				$start = $1;
				$end   = $2;
				$size  = $3;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "start", value1 => $start,
					name2 => "end",   value2 => $end,
					name3 => "size",  value3 => $size,
				}, file => $THIS_FILE, line => __LINE__});
			}
			if ($line =~ /([\d\.]+)GiB ([\d\.]+)GiB ([\d\.]+)GiB logical/)
			{
				my $logical_start = $1;
				my $logical_end   = $2;
				my $logical_size  = $3;
				   $start         = $logical_end;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
					name1 => "logical_start", value1 => $logical_start,
					name2 => "logical_end",   value2 => $logical_end,
					name3 => "logical_size",  value3 => $logical_size,
					name4 => "start",         value4 => $start,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		else
		{
			if ($line =~ /([\d\.]+)GiB ([\d\.]+)GiB ([\d\.]+)GiB Free/i)
			{
				$start = $1;
				$end   = $2;
				$size  = $3;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "start", value1 => $start,
					name2 => "end",   value2 => $end,
					name3 => "size",  value3 => $size,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Hard to proceed if I don't have the start and end sizes.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node",  value1 => $node,
		name2 => "disk",  value2 => $disk,
		name3 => "start", value3 => $start,
		name4 => "end",   value4 => $end,
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $start) or (not $end))
	{
		# :(
		$ok = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "node",           value1 => $node,
			name2 => "disk",           value2 => $disk,
			name3 => "type",           value3 => $type,
			name4 => "partition_size", value4 => $partition_size,
		}, file => $THIS_FILE, line => __LINE__});
		my $message = $an->String->get({key => "message_0389", variables => { 
				node       => $node, 
				disk       => $disk,
				type       => $type,
				size       => $an->Readable->bytes_to_hr({'bytes' => $partition_size })." ($partition_size #!string!suffix_0009!#)",
				shell_call => $shell_call,
			}});
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
			message	=>	$message,
			row	=>	"#!string!state_0042!#",
		}});
	}
	else
	{
		# If the size is 'all', then this is easy.
		my $use_end = $end;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "node",           value1 => $node,
			name2 => "disk",           value2 => $disk,
			name3 => "type",           value3 => $type,
			name4 => "partition_size", value4 => $partition_size,
		}, file => $THIS_FILE, line => __LINE__});
		if ($partition_size eq "all")
		{
			$use_end = "100%";
		}
		else
		{
			my $gib_size = sprintf("%.0f", ($partition_size /= (2 ** 30)));
			   $use_end  = $start + $gib_size;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
				name1 => "node",    value1 => $node,
				name2 => "disk",    value2 => $disk,
				name3 => "use_end", value3 => $use_end,
				name4 => "end",     value4 => $end,
			}, file => $THIS_FILE, line => __LINE__});
			if ($use_end > $end)
			{
				# Make sure this isn't a fraction of a GiB difference before we warn the user
				my $int_use_end =  $use_end;
				   $int_use_end =~ s/\..*$//;
				my $int_end     =  $end;
				   $int_end     =~ s/\..*$//;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "int_use_end", value1 => $int_use_end,
					name2 => "int_end",     value2 => $int_end,
				}, file => $THIS_FILE, line => __LINE__});
				
				if (($int_use_end) && ($int_use_end ne $int_end))
				{
					# Warn the user and then shrink the end.
					my $message = $an->String->get({key => "message_0391", variables => { 
							node       => $node, 
							disk       => $disk,
							type       => $type,
							old_end    => $use_end." #!string!suffix_0006!#",
							new_end    => $end." #!string!suffix_0006!#",
							shell_call => $shell_call,
						}});
					print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
						message => $message,
						row     => "#!string!state_0043!#",
					}});
				}
				
				# Update the 'use_end'
				$use_end = $end;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "use_end", value1 => $use_end,
				}, file => $THIS_FILE, line => __LINE__});
				
			}
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
			name1 => "snode",                          value1 => $node,
			name2 => "disk",                           value2 => $disk,
			name3 => "type",                           value3 => $type,
			name4 => "start (#!string!suffix_0006!#)", value4 => $start,
			name5 => "end (#!string!suffix_0006!#)",   value5 => $end,
		}, file => $THIS_FILE, line => __LINE__});
		
		my $shell_call = $an->data->{path}{parted}." -a opt /dev/$disk mkpart $type ${start}GiB ${use_end}GiB";
		if ($use_end eq "100%")
		{
			$shell_call = $an->data->{path}{parted}." -a opt /dev/$disk mkpart $type ${start}GiB 100%";
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
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /Error/i)
			{
				$ok = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
					name1 => "node",  value1 => $node,
					name2 => "disk",  value2 => $disk,
					name3 => "start", value3 => $start,
					name4 => "end",   value4 => $end,
				}, file => $THIS_FILE, line => __LINE__});
				my $message = $an->String->get({key => "message_0390", variables => { 
						node       => $node, 
						disk       => $disk,
						type       => $type,
						start      => $an->Readable->bytes_to_hr({'bytes' => $start })." ($start #!string!suffix_0009!#)",
						end        => $an->Readable->bytes_to_hr({'bytes' => $end })." ($end #!string!suffix_0009!#)",
						shell_call => $shell_call,
					}});
				print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
					message => $message,
					row     => "#!string!state_0042!#",
				}});
			}
			if ($line =~ /not properly aligned/i)
			{
				# This will mess with performance... =/
				$ok = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
					name1 => "node",  value1 => $node,
					name2 => "disk",  value2 => $disk,
					name3 => "start", value3 => $start,
					name4 => "end",   value4 => $end,
				}, file => $THIS_FILE, line => __LINE__});
				my $message = $an->String->get({key => "message_0431", variables => { 
						node       => $node, 
						disk       => $disk,
						type       => $type,
						start      => $an->Readable->bytes_to_hr({'bytes' => $start })." ($start #!string!suffix_0009!#)",
						end        => $an->Readable->bytes_to_hr({'bytes' => $end })." ($end #!string!suffix_0009!#)",
						shell_call => $shell_call,
					}});
				print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
					message => $message,
					row     => "#!string!state_0099!#",
				}});
			}
			if ($line =~ /reboot/)
			{
				# Reboot needed.
				$an->Log->entry({log_level => 1, message_key => "log_0159", message_variables => { node => $node }, file => $THIS_FILE, line => __LINE__});
				$an->data->{node}{$node}{reboot_needed} = 1;
			}
		}
		$created = 1 if $ok;
	}
	
	# Set 'ok' to 2 if we created a partition.
	if (($ok) && ($created))
	{
		$ok = 2;
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# The checks and, if needed, creates the LV for the GFS2 /shared partition
sub create_shared_lv
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "create_shared_lv" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return_code = 0;
	my $create_lv   = 1;
	my $shell_call  = $an->data->{path}{lvs}." --noheadings --separator ,; ".$an->data->{path}{echo}." return_code:\$?";
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^return_code:(\d+)/)
		{
			my $return_code = $1;
			if ($return_code ne "0")
			{
				# pvs failed...
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
				$create_lv   = 0;
				$return_code = 2;
			}
		}
		if ($line =~ /^shared,/)
		{
			# Found the LV, pull out the VG
			$an->data->{sys}{vg_pool1_name} = ($line =~ /^shared,(.*?),/)[0];
			$create_lv                      = 0;
			$return_code                    = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "sys::vg_pool1_name", value1 => $an->data->{sys}{vg_pool1_name},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "return_code", value1 => $return_code,
		name2 => "create_lv",   value2 => $create_lv,
	}, file => $THIS_FILE, line => __LINE__});
	if (($return_code ne "2") && ($create_lv))
	{
		# Create the LV
		my $lv_size    =  $an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_media_library_byte_size} });
		   $lv_size    =~ s/ //;
		my $shell_call = $an->data->{path}{lvcreate}." -L $lv_size -n shared ".$an->data->{sys}{vg_pool1_name}."; ".$an->data->{path}{echo}." return_code:\$?";
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /^return_code:(\d+)/)
			{
				my $return_code = $1;
				if ($return_code eq "0")
				{
					# lvcreate succeeded
					$an->Log->entry({log_level => 2, message_key => "log_0062", file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# lvcreate failed
					$an->Log->entry({log_level => 1, message_key => "log_0063", message_variables => { return_code => $return_code }, file => $THIS_FILE, line => __LINE__});
					$return_code = 2;
				}
			}
		}
	}
	
	# Report
	my $ok = 1;
	my $class   = "highlight_good_bold";
	my $message = "#!string!state_0045!#";
	if ($return_code == "1")
	{
		# Already existed
		$message = "#!string!state_0020!#";
	}
	elsif ($return_code == "2")
	{
		# Failed to create the LV
		$class   = "highlight_warning_bold";
		$message = "#!string!state_0018!#";
		$ok      = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message-wide", replace => { 
		row	=>	"#!string!row_0262!#",
		class	=>	$class,
		message	=>	$message,
	}});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This attaches the backing devices on each node, modprobe'ing drbd if needed.
sub do_drbd_attach_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "do_drbd_attach_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $message     = "";
	my $return_code = 0;
	# First up, is the DRBD kernel module loaded and is the wait init.d
	# script in place?
	my $shell_call = "
if [ -e '".$an->data->{path}{proc_drbd}."' ]; 
then 
    ".$an->data->{path}{echo}." 'DRBD already loaded'; 
else 
    ".$an->data->{path}{modprobe}." drbd; 
    if [ -e '".$an->data->{path}{proc_drbd}."' ]; 
    then 
        ".$an->data->{path}{echo}." 'loaded DRBD kernel module'; 
    else 
        ".$an->data->{path}{echo}." 'failed to load drbd' 
    fi;
fi;
if [ ! -e '".$an->data->{path}{nodes}{'wait-for-drbd_initd'}."' ];
then
    if [ -e '".$an->data->{path}{nodes}{'wait-for-drbd'}."' ];
    then
        ".$an->data->{path}{echo}." \"need to copy 'wait-for-drbd'\"
        ".$an->data->{path}{cp}." ".$an->data->{path}{nodes}{'wait-for-drbd'}." ".$an->data->{path}{nodes}{'wait-for-drbd_initd'}.";
        if [ ! -e '".$an->data->{path}{nodes}{'wait-for-drbd_initd'}."' ];
        then
           ".$an->data->{path}{echo}." \"Failed to copy 'wait-for-drbd' from: [".$an->data->{path}{nodes}{'wait-for-drbd'}."] to: [".$an->data->{path}{nodes}{'wait-for-drbd_initd'}."]\"
        else
           ".$an->data->{path}{echo}." \"copied 'wait-for-drbd' successfully.\"
        fi
    else
        ".$an->data->{path}{echo}." \"Failed to copy 'wait-for-drbd' from: [".$an->data->{path}{nodes}{'wait-for-drbd'}."], source doesn't exist.\"
    fi
fi;
";
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
		
		if ($line =~ /failed to load/i)
		{
			$return_code = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "Failed to load 'drbd' kernel module on node", value1 => $node,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /already loaded/i)
		{
			# 'drbd' already loaded.
			$an->Log->entry({log_level => 2, message_key => "log_0095", message_variables => {
				node => $node, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /loaded DRBD/i)
		{
			# Loaded the module.
			$an->Log->entry({log_level => 2, message_key => "log_0096", message_variables => {
				node => $node, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /Failed to copy 'wait-for-drbd'/i)
		{
			# wait-for-drbd isn't installed
			$an->Log->entry({log_level => 1, message_key => "log_0097", message_variables => {
				node => $node, 
			}, file => $THIS_FILE, line => __LINE__});
			$return_code = 4;
		}
	}
	
	# If the module loaded, attach!
	if (not $return_code)
	{
		foreach my $resource ("0", "1")
		{
			if (($resource eq "1") && (not $an->data->{cgi}{anvil_storage_pool2_byte_size}))
			{
				next;
			}
			
			# We may not find the resource in /proc/drbd is the resource wasn't started before.
			my $attached = 0;
			my $shell_call = $an->data->{path}{cat}." ".$an->data->{path}{proc_drbd};
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
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /^$resource: /)
				{
					# Resource found, check disk state, but unless it is "Diskless", 
					# we're already attached because unattached disks cause the entry.
					my $disk_state = ($line =~ /ds:(.*?)\//)[0];
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "node",       value1 => $node,
						name2 => "resource",   value2 => "r".$resource,
						name3 => "disk_state", value3 => $disk_state,
					}, file => $THIS_FILE, line => __LINE__});
					if ($disk_state =~ /Diskless/i)
					{
						# Failed disk/array?
						$an->Log->entry({log_level => 1, message_key => "log_0098", message_variables => {
							node     => $node, 
							resource => "r".$resource,
						}, file => $THIS_FILE, line => __LINE__});
						$message .= $an->String->get({key => "message_0399", variables => { resource => "r".$resource, node => $node }});
						$attached = 2;
					}
					elsif ($disk_state)
					{
						# Already attached
						$an->Log->entry({log_level => 2, message_key => "log_0099", message_variables => {
							node     => $node, 
							resource => "r".$resource,
						}, file => $THIS_FILE, line => __LINE__});
						$attached = 1;
					}
				}
			}
			
			# Now attach if needed.
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "node",     value1 => $node,
				name2 => "resource", value2 => "r".$resource,
				name3 => "attached", value3 => $attached,
			}, file => $THIS_FILE, line => __LINE__});
			if (not $attached)
			{
				my $no_metadata = 0;
				my $shell_call  = $an->data->{path}{nodes}{drbdadm}." up r$resource; ".$an->data->{path}{echo}." return_code:\$?";
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
					
					if ($line =~ /No valid meta-data signature found/i)
					{
						# No metadata found
						my $pool     = $resource eq "0" ? "pool1" : "pool2";
						my $device   = $an->data->{node}{$node}{$pool}{device};
						$an->Log->entry({log_level => 1, message_key => "log_0100", message_variables => {
							node     => $node, 
							resource => "r".$resource,
							pool     => $pool, 
							device   => $device, 
						}, file => $THIS_FILE, line => __LINE__});
						$no_metadata = 1;
						$return_code = 3;
						$message .= $an->String->get({key => "message_0403", variables => { device => $device, resource => "r".$resource, node => $node }});
					}
					if ($line =~ /^return_code:(\d+)/)
					{
						my $return_code = $1;
						if ($return_code eq "0")
						{
							# Success!
							$an->Log->entry({log_level => 2, message_key => "log_0101", message_variables => {
								node     => $node, 
								resource => "r".$resource,
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif (not $no_metadata)
						{
							# I skip this if '$no_metadata' is set as I've already generated a message for the user.
							$an->Log->entry({log_level => 1, message_key => "log_0102", message_variables => {
								node     => $node, 
								resource => "r".$resource,
							}, file => $THIS_FILE, line => __LINE__});
							$message .= $an->String->get({key => "message_0400", variables => { resource => "r".$resource, node => $node }});
							$return_code = 3;
						}
					}
				}
			}
		}
	}
	
	# 0 == Success
	# 1 == Failed to load kernel module
	# 2 == One of the resources is Diskless
	# 3 == Attach failed.
	# 4 == Failed to install 'wait-for-drbd'.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "return_code", value1 => $return_code,
		name2 => "message",     value2 => $message,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code, $message);
}

# This calls 'connect' of each resource on a node.
sub do_drbd_connect_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "do_drbd_connect_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $message     = "";
	my $return_code = 0;
	foreach my $resource ("0", "1")
	{
		# Skip r1 if no pool 2.
		if (($resource eq "1") && (not $an->data->{cgi}{anvil_storage_pool2_byte_size}))
		{
			next;
		}
		# See if the resource is already 'Connected' or 'WFConnection'
		my $connected  = 0;
		my $shell_call = $an->data->{path}{cat}." ".$an->data->{path}{proc_drbd};
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /^$resource: /)
			{
				# Try to connect the resource.
				my $connection_state = ($line =~ /cs:(.*?)\//)[0];
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "node",             value1 => $node,
					name2 => "resource",         value2 => "r".$resource,
					name3 => "connection state", value3 => $connection_state,
				}, file => $THIS_FILE, line => __LINE__});
				if ($connection_state =~ /StandAlone/i)
				{
					# StandAlone, connect it.
					$an->Log->entry({log_level => 2, message_key => "log_0090", message_variables => {
						node     => $node, 
						resource => "r".$resource, 
					}, file => $THIS_FILE, line => __LINE__});
					$connected = 0;
				}
				elsif ($connection_state)
				{
					# Already connected
					$an->Log->entry({log_level => 2, message_key => "log_0091", message_variables => {
						node             => $node, 
						resource         => "r".$resource, 
						connection_state => $connection_state, 
					}, file => $THIS_FILE, line => __LINE__});
					$connected = 1;
				}
			}
		}
		
		# Now connect if needed.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node",      value1 => $node,
			name2 => "resource",  value2 => "r".$resource,
			name3 => "connected", value3 => $connected,
		}, file => $THIS_FILE, line => __LINE__});
		if (not $connected)
		{
			my $shell_call = $an->data->{path}{nodes}{drbdadm}." connect r$resource; ".$an->data->{path}{echo}." return_code:\$?";
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
				
				if ($line =~ /^return_code:(\d+)/)
				{
					my $return_code = $1;
					if ($return_code eq "0")
					{
						# Success!
						$an->Log->entry({log_level => 2, message_key => "log_0092", message_variables => {
							node     => $node, 
							resource => "r".$resource, 
						}, file => $THIS_FILE, line => __LINE__});
					}
					else
					{
						# Failed to connect.
						$an->Log->entry({log_level => 1, message_key => "log_0093", message_variables => {
							node     => $node, 
							resource => "r".$resource, 
						}, file => $THIS_FILE, line => __LINE__});
						$message .= $an->String->get({key => "message_0401", variables => { resource => "r".$resource, node => $node }});
						$return_code = 1;
					}
				}
			}
		}
	
		# If requested by 'sys::install_manifest::default::immediate-uptodate', and if both nodes are
		# 'Inconsistent', force both nodes to be UpToDate/UpToDate.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::install_manifest::default::immediate-uptodate", value1 => $an->data->{sys}{install_manifest}{'default'}{'immediate-uptodate'},
		}, file => $THIS_FILE, line => __LINE__});
		if ($an->data->{sys}{install_manifest}{'default'}{'immediate-uptodate'})
		{
			# This will loop for a maximum of 30 seconds waiting for the peer to connect. Once 
			# connected, it will check the disk state and decide it if can force both nodes to
			# UpToDate immediately.
			my $ready          = 0;
			my $force_uptodate = 0;
			for (1..6)
			{
				# Check to see if we're connected.
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "ready", value1 => $ready,
				}, file => $THIS_FILE, line => __LINE__});
				last if $ready;
				
				sleep 5;
				my $shell_call = $an->data->{path}{cat}." ".$an->data->{path}{proc_drbd};
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
					
					if ($line =~ /^(\d+): cs:(.*?) .*? ds:(.*?)\/(.*?) /)
					{
						my $resource_minor   = $1;
						my $connection_state = $2;
						my $my_disk_state    = $3;
						my $peer_disk_state  = $4;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
							name1 => "resource_minor",   value1 => $resource_minor,
							name2 => "connection_state", value2 => $connection_state,
							name3 => "my_disk_state",    value3 => $my_disk_state,
							name4 => "peer_disk_state",  value4 => $peer_disk_state,
						}, file => $THIS_FILE, line => __LINE__});
						if (($connection_state =~ /connected/i) or ($connection_state =~ /sync/i))
						{
							# Connected... What are the disk states?
							$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
								name1 => "resource_minor",  value1 => $resource_minor,
								name2 => "my_disk_state",   value2 => $my_disk_state,
								name3 => "peer_disk_state", value3 => $peer_disk_state,
							}, file => $THIS_FILE, line => __LINE__});
							if ((($my_disk_state   =~ /Inconsistent/i) or ($my_disk_state   =~ /Outdated/i) or ($my_disk_state   =~ /Consistent/i) or ($my_disk_state   =~ /UpToDate/i) or ($my_disk_state   =~ /Sync/i)) &&
							    (($peer_disk_state =~ /Inconsistent/i) or ($peer_disk_state =~ /Outdated/i) or ($peer_disk_state =~ /Consistent/i) or ($peer_disk_state =~ /UpToDate/i)))
							{
								# We're ready.
								$ready = 1;
								$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
									name1 => "ready", value1 => $ready,
								}, file => $THIS_FILE, line => __LINE__});
							}
							if (($my_disk_state =~ /Inconsistent/i) && ($peer_disk_state =~ /Inconsistent/i))
							{
								$force_uptodate = 1;
								$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
									name1 => "force_uptodate", value1 => $force_uptodate,
								}, file => $THIS_FILE, line => __LINE__});
							}
						}
					}
				}
			}
			if (not $ready)
			{
				# Problem connecting a resource.
				$an->Log->entry({log_level => 1, message_key => "log_0094", message_variables => {
					node     => $node, 
					resource => "r".$resource, 
				}, file => $THIS_FILE, line => __LINE__});
				$message .= $an->String->get({key => "message_0450", variables => { resource => "r".$resource, node => $node }});
				$return_code = 1;
			}
			elsif ($force_uptodate)
			{
				my $shell_call = "
".$an->data->{path}{echo}." \"Forcing r".$resource." to 'UpToDate' on both nodes; 'sys::install_manifest::default::immediate-uptodate' set and both are currently Inconsistent.\"
".$an->data->{path}{nodes}{drbdadm}." new-current-uuid --clear-bitmap r$resource/0
".$an->data->{path}{'sleep'}." 2
if \$(".$an->data->{path}{cat}." ".$an->data->{path}{proc_drbd}." | ".$an->data->{path}{nodes}{'grep'}." '$resource: cs' | ".$an->data->{path}{awk}." '{print \$4}' | ".$an->data->{path}{nodes}{'grep'}." -q 'UpToDate/UpToDate'); 
then 
    ".$an->data->{path}{echo}." success
else
    ".$an->data->{path}{echo}." failed.
fi
";
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
					# I don't analyze this because it isn't critical if it doesn't work and the output
					# will explain what happened to anyone who cares to look.
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
	}
	
	# 0 == OK
	# 1 == Failed to connect
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "return_code", value1 => $return_code,
		name2 => "message",     value2 => $message,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code, $message);
}

# This promotes the DRBD resources to Primary, forcing if needed.
sub do_drbd_primary_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "do_drbd_primary_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $force_r0 = $parameter->{force_r0} ? $parameter->{force_r0} : "";
	my $force_r1 = $parameter->{force_r1} ? $parameter->{force_r1} : "";
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "force_r0", value1 => $force_r0, 
		name2 => "force_r1", value2 => $force_r1, 
		name3 => "node",     value3 => $node, 
		name4 => "target",   value4 => $target, 
		name5 => "port",     value5 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Resource 0
	my $return_code = 0;
	my $message     = "";
	my $shell_call  = $an->data->{path}{nodes}{drbdadm}." primary r0; ".$an->data->{path}{echo}." return_code:\$?";
	if ($force_r0)
	{
		$an->Log->entry({log_level => 2, message_key => "log_0084", message_variables => { resource => "r0" }, file => $THIS_FILE, line => __LINE__});
		$shell_call = $an->data->{path}{nodes}{drbdadm}." primary r0 --force; ".$an->data->{path}{echo}." return_code:\$?";
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
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^return_code:(\d+)/)
		{
			my $return_code = $1;
			if ($return_code eq "0")
			{
				# Success!
				$an->Log->entry({log_level => 2, message_key => "log_0085", message_variables => {
					node     => $node,
					resource => "r0", 
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Failed to promote.
				$an->Log->entry({log_level => 1, message_key => "log_0086", message_variables => {
					node     => $node,
					resource => "r0", 
				}, file => $THIS_FILE, line => __LINE__});
				$message .= $an->String->get({key => "message_0400", variables => { resource => "r0", node => $node }});
				$return_code = 1;
			}
		}
	}
	
	# Resource 1
	if ($an->data->{cgi}{anvil_storage_pool2_byte_size})
	{
		$shell_call  = $an->data->{path}{nodes}{drbdadm}." primary r1; ".$an->data->{path}{echo}." return_code:\$?";
		if ($force_r0)
		{
			$an->Log->entry({log_level => 2, message_key => "log_0084", message_variables => { resource => "r1" }, file => $THIS_FILE, line => __LINE__});
			$shell_call = $an->data->{path}{nodes}{drbdadm}." primary r1 --force; ".$an->data->{path}{echo}." return_code:\$?";
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
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /^return_code:(\d+)/)
			{
				my $return_code = $1;
				if ($return_code eq "0")
				{
					# Success!
					$an->Log->entry({log_level => 2, message_key => "log_0085", message_variables => {
						node     => $node,
						resource => "r1", 
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Failed to promote.
					$an->Log->entry({log_level => 1, message_key => "log_0086", message_variables => {
						node     => $node,
						resource => "r1", 
					}, file => $THIS_FILE, line => __LINE__});
					$message .= $an->String->get({key => "message_0400", variables => { resource => "r0", node => $node }});
					$return_code = 1;
				}
			}
		}
	}
	
	# If we're OK, call 'drbdadm adjust all' to make sure the requested sync rate takes effect.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $return_code)
	{
		my $shell_call = $an->data->{path}{nodes}{drbdadm}." adjust all";
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
	
	# 0 == OK
	# 1 == Failed to make primary
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "return_code", value1 => $return_code,
		name2 => "message",     value2 => $message,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code, $message);
}

# This handles the actual rebooting of the node
sub do_node_reboot
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "do_node_reboot" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $new_bcn_ip = $parameter->{new_bcn_ip} ? $parameter->{new_bcn_ip} : "";
	my $node       = $parameter->{node}       ? $parameter->{node}       : "";
	my $target     = $parameter->{target}     ? $parameter->{target}     : "";
	my $port       = $parameter->{port}       ? $parameter->{port}       : "";
	my $password   = $parameter->{password}   ? $parameter->{password}   : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "new_bcn_ip", value1 => $new_bcn_ip, 
		name2 => "node",       value2 => $node, 
		name3 => "target",     value3 => $target, 
		name4 => "port",       value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return_code = 255;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node::${node}::reboot_needed", value1 => $an->data->{node}{$node}{reboot_needed},
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->data->{node}{$node}{reboot_needed})
	{
		# Reboot not needed
		$return_code = 1;
		$an->Log->entry({log_level => 2, message_key => "log_0157", message_variables => {
			node => $node, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($an->data->{node}{$node}{in_cluster})
	{
		# Reboot needed, but the user has to do it.
		$return_code = 5;
		$an->Log->entry({log_level => 1, message_key => "log_0158", message_variables => { node => $node }, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		### NOTE: We can't use 'anvil-safe-stop' here because a new node won't be in the database yet.
		# Reboot... Close the SSH FH as well.
		$an->Log->entry({log_level => 1, message_key => "log_0159", message_variables => { node => $node }, file => $THIS_FILE, line => __LINE__});
		my $shell_call = $an->data->{path}{reboot};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
			shell_call	=>	$shell_call,
			'close'		=>	1,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# Update the IP address if needed.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target, 
			name2 => "new_bcn_ip", value2 => $new_bcn_ip, 
		}, file => $THIS_FILE, line => __LINE__});
		if ($target ne $new_bcn_ip)
		{
			$target = $new_bcn_ip;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "target", value1 => $target, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		# We need to give the system time to shut down.
		my $has_shutdown = 0;
		my $time_limit   = $an->data->{sys}{reboot_timeout};
		my $uptime_max   = $time_limit + 60;
		my $timeout      = time + $time_limit;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
			name1 => "time",                value1 => time,
			name2 => "sys::reboot_timeout", value2 => $an->data->{sys}{reboot_timeout},
			name3 => "time_limit",          value3 => $time_limit,
			name4 => "timeout",             value4 => $timeout,
			name5 => "uptime_max",          value5 => $uptime_max,
		}, file => $THIS_FILE, line => __LINE__});
		while (not $has_shutdown)
		{
			sleep 3;
			
			# 1 == pinged, 0 == failed.
			my ($ping) = $an->Check->ping({ping => $target, count => 3});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "target", value1 => $target,
				name2 => "ping",   value2 => $ping,
			}, file => $THIS_FILE, line => __LINE__});
			if ($ping)
			{
				# We can ping it, so log in and see if the uptime is short. Failure to log in
				# will cause the uptime to return '0'.
				my $uptime = $an->System->get_uptime({
						target   => $target,
						port     => $port, 
						password => $password,
					});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "uptime",     value1 => $uptime, 
					name2 => "uptime_max", value2 => $uptime_max, 
				}, file => $THIS_FILE, line => __LINE__});
				if (($uptime) && ($uptime < $uptime_max))
				{
					# We rebooted and missed it.
					$has_shutdown = 1;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "has_shutdown", value1 => $has_shutdown, 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "time",    value1 => time,
				name2 => "timeout", value2 => $timeout,
			}, file => $THIS_FILE, line => __LINE__});
			if (time > $timeout)
			{
				$return_code = 4;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
				last;
			}
		}
		
		# Now loop for 'sys::reboot_timeout' seconds waiting to see if the node recovers.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "has_shutdown", value1 => $has_shutdown,
		}, file => $THIS_FILE, line => __LINE__});
		if ($has_shutdown)
		{
			my $give_up_time      = time + $an->data->{sys}{reboot_timeout};
			my $wait              = 1;
			my $wait_return_code  = 255;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "time",      value1 => time,
				name2 => "give_up_time", value2 => $give_up_time,
			}, file => $THIS_FILE, line => __LINE__});
			while ($wait)
			{
				my $time      = time;
				my $will_wait = ($give_up_time - $time);
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "will_wait", value1 => $will_wait,
				}, file => $THIS_FILE, line => __LINE__});
				if ($time > $give_up_time)
				{
					last;
				}
				($wait_return_code) = $an->InstallManifest->connect_to_node({
						node     => $node,
						target   => $target, 
						port     => $port, 
						password => $password,
					});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "target",           value1 => $target,
					name2 => "wait_return_code", value2 => $wait_return_code,
				}, file => $THIS_FILE, line => __LINE__});
				
				# Return codes:
				# 0 = Successfully logged in
				# 1 = Could ping, but couldn't log in
				# 2 = Couldn't ping.
				if ($wait_return_code == 0)
				{
					# Woot!
					$wait = 0;
					
					# Update the 'use_ip'.
					my $node_key                                  = $an->data->{sys}{node_name}{$node}{node_key};
					   $an->data->{sys}{anvil}{$node_key}{use_ip} = $new_bcn_ip;
					   $target                                    = $an->data->{sys}{anvil}{$node_key}{use_ip};
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "node_key",                        value1 => $node_key,
						name2 => "sys::anvil::${node_key}::use_ip", value2 => $an->data->{sys}{anvil}{$node_key}{use_ip},
						name3 => "target",                          value3 => $target,
					}, file => $THIS_FILE, line => __LINE__});
				}
				sleep 3;
			}
			
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "wait_return_code", value1 => $wait_return_code,
			}, file => $THIS_FILE, line => __LINE__});
			if ($wait_return_code == 0)
			{
				# Success! Rescan storage.
				$return_code = 0;
				$an->Log->entry({log_level => 2, message_key => "log_0161", file => $THIS_FILE, line => __LINE__});
				
				# Rescan its (new) partition data.
				my ($node_disk) = $an->InstallManifest->get_partition_data({
						node     => $node, 
						target   => $target, 
						port     => $port, 
						password => $password,
					});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node", value1 => $node,
					name2 => "disk", value2 => $node_disk,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($wait_return_code == 1)
			{
				$return_code = 2;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($wait_return_code == 2)
			{
				$return_code = 3;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This is used by the stage-3 storage function to bring up DRBD
sub drbd_first_start
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "drbd_first_start" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $return_code = 255;
	my $node1       = $an->data->{sys}{anvil}{node1}{name};
	my $node2       = $an->data->{sys}{anvil}{node2}{name};
	
	# Start DRBD manually and if both nodes are Inconsistent for a given resource, run;
	# drbdadm -- --overwrite-data-of-peer primary <res>
	my $node1_attach_return_code = 0;
	my $node1_attach_message     = "";
	my $node2_attach_return_code = 0;
	my $node2_attach_message     = "";
	($node1_attach_return_code, $node1_attach_message) = $an->InstallManifest->do_drbd_attach_on_node({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		}) if not $an->data->{node}{node1}{has_servers};
	($node2_attach_return_code, $node2_attach_message) = $an->InstallManifest->do_drbd_attach_on_node({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
		}) if not $an->data->{node}{node2}{has_servers};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node1_attach_return_code", value1 => $node1_attach_return_code,
		name2 => "node1_attach_message",     value2 => $node1_attach_message,
		name3 => "node2_attach_return_code", value3 => $node2_attach_return_code,
		name4 => "node2_attach_message",     value4 => $node2_attach_message,
	}, file => $THIS_FILE, line => __LINE__});
	# 0 == Success
	# 1 == Failed to load kernel module
	# 2 == One of the resources is Diskless
	# 3 == Attach failed.
	# 4 == Failed to install 'wait-for-drbd'
	
	# Call 'wait-for-drbd' on node 1 (or node 2, if node 1 has servers) so that we don't move on to clvmd before DRBD (its PV) is ready.
	my $node_key = "node1";
	if ($an->data->{node}{node1}{has_servers})
	{
		$node_key = "node2";
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node::node1::has_servers", value1 => $an->data->{node}{node1}{has_servers},
		name2 => "node_key",                 value2 => $node_key,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $node       = $an->data->{sys}{anvil}{$node_key}{name};
	my $target     = $an->data->{sys}{anvil}{$node_key}{use_ip};
	my $port       = $an->data->{sys}{anvil}{$node_key}{use_port};
	my $password   = $an->data->{sys}{anvil}{$node_key}{password};
	my $shell_call = $an->data->{path}{nodes}{'wait-for-drbd_initd'}." start";
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
	
	# Ping variables
	my $node1_ping_ok = "";
	my $node2_ping_ok = "";
	
	# Connect variables
	my $node1_connect_return_code = 255;
	my $node1_connect_message     = "";
	my $node2_connect_return_code = 255;
	my $node2_connect_message     = "";
	
	# Primary variables
	my $node1_primary_return_code = 255;
	my $node1_primary_message     = "";
	my $node2_primary_return_code = 255;
	my $node2_primary_message     = "";
	
	# Time to work
	if (($node1_attach_return_code eq "0") && ($node2_attach_return_code eq "0"))
	{
		# Make sure we can ping the peer node over the SN
		my ($node1_ping) = $an->Check->ping({
			ping		=>	$an->data->{cgi}{anvil_node2_sn_ip}, 
			count		=>	3,
			target		=>	$an->data->{sys}{anvil}{node1}{use_ip},
			port		=>	$an->data->{sys}{anvil}{node1}{use_port}, 
			password	=>	$an->data->{sys}{anvil}{node1}{password},
		});
		my ($node2_ping) = $an->Check->ping({
			ping		=>	$an->data->{cgi}{anvil_node1_sn_ip}, 
			count		=>	3,
			target		=>	$an->data->{sys}{anvil}{node2}{use_ip},
			port		=>	$an->data->{sys}{anvil}{node2}{use_port}, 
			password	=>	$an->data->{sys}{anvil}{node2}{password},
		});
		# 1 == Ping success
		# 0 == Ping failed
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node1_ping", value1 => $node1_ping,
			name2 => "node2_ping", value2 => $node2_ping,
		}, file => $THIS_FILE, line => __LINE__});
		if (($node1_ping) && ($node2_ping))
		{
			### NOTE: We run this on both nodes because it is possible that the surviving node is StandAlone
			# Both nodes have both of their resources attached and are pingable on the SN, 
			# Make sure they're not 'StandAlone' and, if so, tell them to connect.
			($node1_connect_return_code, $node1_connect_message) = $an->InstallManifest->do_drbd_connect_on_node({
					node     => $node1,
					target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
					port     => $an->data->{sys}{anvil}{node1}{use_port}, 
					password => $an->data->{sys}{anvil}{node1}{password},
				});
			($node2_connect_return_code, $node2_connect_message) = $an->InstallManifest->do_drbd_connect_on_node({
					node     => $node2,
					target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
					port     => $an->data->{sys}{anvil}{node2}{use_port}, 
					password => $an->data->{sys}{anvil}{node2}{password},
				});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
				name1 => "node1_connect_return_code", value1 => $node1_connect_return_code,
				name2 => "node1_connect_message",     value2 => $node1_connect_message,
				name3 => "node2_connect_return_code", value3 => $node2_connect_return_code,
				name4 => "node2_connect_message",     value4 => $node2_connect_message,
			}, file => $THIS_FILE, line => __LINE__});
			# 0 == OK
			# 1 == Failed to connect
			
			# Finally, make primary
			if ((not $node1_connect_return_code) or (not $node2_connect_return_code))
			{
				# Make sure both nodes are, indeed, connected.
				my ($return_code) = $an->InstallManifest->verify_drbd_resources_are_connected({
						node     => $node1, 
						target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
						port     => $an->data->{sys}{anvil}{node1}{use_port}, 
						password => $an->data->{sys}{anvil}{node1}{password},
					});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
				# 0 == OK
				# 1 == Failed to connect
				
				if (not $return_code)
				{
					# Check to see if both nodes are 'Inconsistent'. If so, force node 1
					# to be primary to begin the initial sync.
					my ($return_code, $force_node1_r0, $force_node1_r1) = $an->InstallManifest->check_drbd_if_force_primary_is_needed({
							node     => $node1,
							target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
							port     => $an->data->{sys}{anvil}{node1}{use_port}, 
							password => $an->data->{sys}{anvil}{node1}{password},
						});
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "return_code",    value1 => $return_code,
						name2 => "force_node1_r0", value2 => $force_node1_r0,
						name3 => "force_node1_r1", value3 => $force_node1_r1,
					}, file => $THIS_FILE, line => __LINE__});
					# 0 == Both resources found, safe to proceed
					# 1 == One or both of the resources not found
					
					# This RC check is just a little paranoia before doing a potentially
					# destructive call.
					if (not $return_code)
					{
						# Promote to primary!
						($node1_primary_return_code, $node1_primary_message) = $an->InstallManifest->do_drbd_primary_on_node({
								node     => $node1, 
								target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
								port     => $an->data->{sys}{anvil}{node1}{use_port}, 
								password => $an->data->{sys}{anvil}{node1}{password},
								force_r0 => $force_node1_r0,
								force_r1 => $force_node1_r1,
							}) if not $an->data->{node}{node1}{has_servers};
						($node2_primary_return_code, $node2_primary_message) = $an->InstallManifest->do_drbd_primary_on_node({
								node     => $node2, 
								target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
								port     => $an->data->{sys}{anvil}{node2}{use_port}, 
								password => $an->data->{sys}{anvil}{node2}{password},
								force_r0 => 0,
								force_r1 => 0,
							}) if not $an->data->{node}{node2}{has_servers};
						
						$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
							name1 => "node1_primary_return_code", value1 => $node1_primary_return_code,
							name2 => "node1_primary_message",     value2 => $node1_primary_message,
							name3 => "node2_primary_return_code", value3 => $node2_primary_return_code,
							name4 => "node2_primary_message",     value4 => $node2_primary_message,
						}, file => $THIS_FILE, line => __LINE__});
						# 0 == OK
						# 1 == Failed to make primary
						if ((not $node1_primary_return_code) or (($an->data->{cgi}{anvil_storage_pool2_byte_size}) && (not $node2_primary_return_code)))
						{
							# Woohoo!
							$an->Log->entry({log_level => 2, message_key => "log_0074", file => $THIS_FILE, line => __LINE__});
						}
						else
						{
							# Failed
							$return_code = 5;
							$an->Log->entry({log_level => 1, message_key => "log_0075", file => $THIS_FILE, line => __LINE__});
						}
					}
				}
				else
				{
					# Failed to connect
					$return_code = 4;
					$an->Log->entry({log_level => 1, message_key => "log_0076", file => $THIS_FILE, line => __LINE__});
				}
			}
			else
			{
				# Failed to enter WFConnection
				$return_code = 3;
				$an->Log->entry({log_level => 1, message_key => "log_0077", file => $THIS_FILE, line => __LINE__});
			}
		}
		else
		{
			# Failed to ping peer on SN
			$return_code = 2;
			$an->Log->entry({log_level => 1, message_key => "log_0078", file => $THIS_FILE, line => __LINE__});
		}
	}
	elsif (($node1_attach_return_code eq "4") or ($node2_attach_return_code eq "4"))
	{
		# Failed to install 'wait-for-drbd'
		$return_code = 6;
		$an->Log->entry({log_level => 1, message_key => "log_0079", file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Failed to attach.
		$return_code = 1;
		$an->Log->entry({log_level => 1, message_key => "log_0080", file => $THIS_FILE, line => __LINE__});
	}
	
	# 0 == OK
	# 1 == Attach failed
	# 2 == Can't ping on SN
	# 3 == Connect failed
	# 4 == Both nodes entered connencted state but didn't actually connect
	# 5 == Promotion to 'Primary' failed.
	# 6 == Failed to install 'wait-for-drbd'.
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0014!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0014!#";
	# Node messages are interleved
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	if ($return_code eq "1")
	{
		# Attach failed
		if ($node1_attach_message)
		{
			$node1_class   = "highlight_warning_bold";
			$node1_message = $an->String->get({key => "state_0083", variables => { message => $node1_attach_message }});
		}
		if ($node2_attach_message)
		{
			$node2_class   = "highlight_warning_bold";
			$node2_message = $an->String->get({key => "state_0083", variables => { message => $node2_attach_message }});
		}
		if ((not $node1_attach_message) && (not $node2_attach_message))
		{
			# Neither node had an attach error, so set both to
			# generic error state.
			$node1_class   = "highlight_warning_bold";
			$node1_message = "#!string!state_0088!#";
			$node2_class   = "highlight_warning_bold";
			$node2_message = "#!string!state_0088!#";
			if ($return_code eq "6")
			{
				# Unless we failed to install 'wait-for-drbd'.
				if ($node1_attach_return_code eq "4")
				{
					$node1_message = "#!string!state_0116!#";
				}
				if ($node2_attach_return_code eq "4")
				{
					$node2_message = "#!string!state_0116!#";
				}
			}
		}
		$ok = 0;
	}
	elsif ($return_code eq "2")
	{
		# Ping failed
		if (not $node1_ping_ok)
		{
			$node1_class   = "highlight_warning_bold";
			$node1_message = "#!string!state_0084!#";
		}
		if (not $node2_ping_ok)
		{
			$node2_class   = "highlight_warning_bold";
			$node2_message = "#!string!state_0084!#";
		}
		if (($node1_ping_ok) && ($node2_ping_ok))
		{
			# Neither node had a ping error, so set both to
			# generic error state.
			$node1_class   = "highlight_warning_bold";
			$node1_message = "#!string!state_0088!#";
			$node2_class   = "highlight_warning_bold";
			$node2_message = "#!string!state_0088!#";
		}
		$ok = 0;
	}
	elsif ($return_code eq "3")
	{
		# Connect failed
		if ($node1_connect_message)
		{
			$node1_class   = "highlight_warning_bold";
			$node1_message = $an->String->get({key => "state_0085", variables => { message => $node1_connect_message }});
		}
		if ($node2_connect_message)
		{
			$node2_class   = "highlight_warning_bold";
			$node2_message = $an->String->get({key => "state_0085", variables => { message => $node2_connect_message }});
		}
		if ((not $node1_connect_message) && (not $node2_connect_message))
		{
			# Neither node had a connection error, so set both to generic error state.
			$node1_class   = "highlight_warning_bold";
			$node1_message = "#!string!state_0088!#";
			$node2_class   = "highlight_warning_bold";
			$node2_message = "#!string!state_0088!#";
		}
		$ok = 0;
	}
	elsif ($return_code eq "4")
	{
		# Entered 'Connect' state but didn't actually connect.
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0086!#";
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0086!#";
		$ok            = 0;
	}
	elsif ($return_code eq "5")
	{
		# Failed to promote.
		if ($node1_primary_message)
		{
			$node1_class   = "highlight_warning_bold";
			$node1_message = $an->String->get({key => "state_0087", variables => { message => $node1_primary_message }});
		}
		if ($node2_primary_message)
		{
			$node2_class   = "highlight_warning_bold";
			$node2_message = $an->String->get({key => "state_0087", variables => { message => $node2_primary_message }});
		}
		if ((not $node1_primary_message) && (not $node2_primary_message))
		{
			# Neither node had a promotion error, so set both to generic error state.
			$node1_class   = "highlight_warning_bold";
			$node1_message = "#!string!state_0088!#";
			$node2_class   = "highlight_warning_bold";
			$node2_message = "#!string!state_0088!#";
		}
		$ok = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0258!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	# Things seem a little racy, so we'll sleep here a touch if things are OK just to be sure DRBD is 
	# really ready.
	if ($ok)
	{
		sleep 5;
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This enables (or disables) selected tools by flipping their enable variables to '1' (or '0') i striker.conf.
sub enable_tools
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "enable_tools" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1 = $an->data->{sys}{anvil}{node1}{name};
	my $node2 = $an->data->{sys}{anvil}{node2}{name};
	
	# sas_return_code  == anvil-safe-start, return code
	# akau_return_code == anvil-kick-apc-ups, return code
	my $node1_sas_return_code  = 0;
	my $node1_akau_return_code = 0;
	my $node1_sc_return_code   = 0;
	my $node2_sas_return_code  = 0;
	my $node2_akau_return_code = 0;
	my $node2_sc_return_code   = 0;
	($node1_sas_return_code, $node1_akau_return_code, $node1_sc_return_code) = $an->InstallManifest->enable_tools_on_node({
			node      => $node1, 
			target    => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port      => $an->data->{sys}{anvil}{node1}{use_port}, 
			password  => $an->data->{sys}{anvil}{node1}{password},
			node_name => $node1,
		}) if not $an->data->{node}{node1}{has_servers};
	($node2_sas_return_code, $node2_akau_return_code, $node2_sc_return_code) = $an->InstallManifest->enable_tools_on_node({
			node      => $node2, 
			target    => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port      => $an->data->{sys}{anvil}{node2}{use_port}, 
			password  => $an->data->{sys}{anvil}{node2}{password},
			node_name => $node2,
		}) if not $an->data->{node}{node2}{has_servers};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "node1_sas_return_code",  value1 => $node1_sas_return_code,
		name2 => "node1_akau_return_code", value2 => $node1_akau_return_code,
		name3 => "node1_sc_return_code",   value3 => $node1_sc_return_code,
		name4 => "node2_sas_return_code",  value4 => $node2_sas_return_code,
		name5 => "node2_akau_return_code", value5 => $node2_akau_return_code,
		name6 => "node2_sc_return_code",   value6 => $node2_sc_return_code,
	}, file => $THIS_FILE, line => __LINE__});
	# 0 == No changes made
	# 1 == Enabled successfully
	# 2 == Disabled successfully
	# 3 == Failed to enable
	# 4 == Failed to disable
	
	my $ok = 1;
	
	# Report on anvil-safe-start, first.
	my $node1_class   = "highlight_warning_bold";
	my $node1_message = "#!string!state_0001!#";
	my $node2_class   = "highlight_warning_bold";
	my $node2_message = "#!string!state_0001!#";
	# Node 1
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif ($node1_sas_return_code eq "0")
	{
		# Unknown state.
		$ok = 0;
	}
	elsif ($node1_sas_return_code eq "1")
	{
		# Enabled successfully.
		$node1_class   = "highlight_good_bold";
		$node1_message = "#!string!state_0119!#";
	}
	elsif ($node1_sas_return_code eq "2")
	{
		# Disabled successfully.
		$node1_class   = "highlight_good_bold";
		$node1_message = "#!string!state_0120!#";
	}
	elsif ($node1_sas_return_code eq "3")
	{
		# Failed to enabled!
		$node1_message = "#!string!state_0121!#";
		$ok            = 0;
	}
	elsif ($node1_sas_return_code eq "4")
	{
		# Failed to disable!
		$node1_message = "#!string!state_0122!#";
		$ok            = 0;
	}
	
	# Node 2
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif ($node2_sas_return_code eq "0")
	{
		# Unknown state.
		$ok = 0;
	}
	elsif ($node2_sas_return_code eq "1")
	{
		# Enabled successfully.
		$node2_class   = "highlight_good_bold";
		$node2_message = "#!string!state_0119!#";
	}
	elsif ($node2_sas_return_code eq "2")
	{
		# Disabled successfully.
		$node2_class   = "highlight_good_bold";
		$node2_message = "#!string!state_0120!#";
	}
	elsif ($node2_sas_return_code eq "3")
	{
		# Failed to enabled!
		$node2_message = "#!string!state_0121!#";
		$ok            = 0;
	}
	elsif ($node2_sas_return_code eq "4")
	{
		# Failed to disable!
		$node2_message = "#!string!state_0122!#";
		$ok            = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0287!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
		
	}});
	
	# Next, anvil-kick-apc-ups
	$node1_class   = "highlight_warning_bold";
	$node1_message = "#!string!state_0001!#";
	$node2_class   = "highlight_warning_bold";
	$node2_message = "#!string!state_0001!#";
	# Node 1
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif ($node1_akau_return_code eq "0")
	{
		# Unknown state.
		$ok = 0;
	}
	elsif ($node1_akau_return_code eq "1")
	{
		# Enabled successfully.
		$node1_class   = "highlight_good_bold";
		$node1_message = "#!string!state_0119!#";
	}
	elsif ($node1_akau_return_code eq "2")
	{
		# Disabled successfully.
		$node1_class   = "highlight_good_bold";
		$node1_message = "#!string!state_0120!#";
	}
	elsif ($node1_akau_return_code eq "3")
	{
		# Failed to enabled!
		$node1_message = "#!string!state_0121!#";
		$ok            = 0;
	}
	elsif ($node1_akau_return_code eq "4")
	{
		# Failed to disable!
		$node1_message = "#!string!state_0122!#";
		$ok            = 0;
	}
	
	# Node 2
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif ($node2_akau_return_code eq "0")
	{
		# Unknown state.
		$ok = 0;
	}
	elsif ($node2_akau_return_code eq "1")
	{
		# Enabled successfully.
		$node2_class   = "highlight_good_bold";
		$node2_message = "#!string!state_0119!#";
	}
	elsif ($node2_akau_return_code eq "2")
	{
		# Disabled successfully.
		$node2_class   = "highlight_good_bold";
		$node2_message = "#!string!state_0120!#";
	}
	elsif ($node2_akau_return_code eq "3")
	{
		# Failed to enabled!
		$node2_message = "#!string!state_0121!#";
		$ok            = 0;
	}
	elsif ($node2_akau_return_code eq "4")
	{
		# Failed to disable!
		$node2_message = "#!string!state_0122!#";
		$ok            = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0288!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	# And finally, ScanCore
	$node1_class   = "highlight_warning_bold";
	$node1_message = "#!string!state_0001!#";
	$node2_class   = "highlight_warning_bold";
	$node2_message = "#!string!state_0001!#";
	# Node 1
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif ($node1_sc_return_code eq "0")
	{
		# Unknown state.
		$ok = 0;
	}
	elsif ($node1_sc_return_code eq "1")
	{
		# Enabled successfully.
		$node1_class   = "highlight_good_bold";
		$node1_message = "#!string!state_0119!#";
	}
	elsif ($node1_sc_return_code eq "2")
	{
		# Disabled successfully.
		$node1_class   = "highlight_good_bold";
		$node1_message = "#!string!state_0120!#";
	}
	elsif ($node1_sc_return_code eq "3")
	{
		# Failed to enabled!
		$node1_message = "#!string!state_0121!#";
		$ok            = 0;
	}
	elsif ($node1_sc_return_code eq "4")
	{
		# Failed to disable!
		$node1_message = "#!string!state_0122!#";
		$ok            = 0;
	}
	
	# Node 2
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif ($node2_sc_return_code eq "0")
	{
		# Unknown state.
		$ok = 0;
	}
	elsif ($node2_sc_return_code eq "1")
	{
		# Enabled successfully.
		$node2_class   = "highlight_good_bold";
		$node2_message = "#!string!state_0119!#";
	}
	elsif ($node2_sc_return_code eq "2")
	{
		# Disabled successfully.
		$node2_class   = "highlight_good_bold";
		$node2_message = "#!string!state_0120!#";
	}
	elsif ($node2_sc_return_code eq "3")
	{
		# Failed to enabled!
		$node2_message = "#!string!state_0121!#";
		$ok            = 0;
	}
	elsif ($node2_sc_return_code eq "4")
	{
		# Failed to disable!
		$node2_message = "#!string!state_0122!#";
		$ok            = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0289!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This handles enabling/disabling tools on a given node.
sub enable_tools_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "enable_tools_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### anvil-safe-start
	# If requested, enable anvil-safe-start, otherwise, disable it.
	my $sas_return_code = 0;
	my $shell_call      = $an->data->{path}{nodes}{'anvil-safe-start'}." --disable\n";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::install_manifest::use_anvil-safe-start", value1 => $an->data->{sys}{install_manifest}{'use_anvil-safe-start'},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{install_manifest}{'use_anvil-safe-start'})
	{
		$shell_call = $an->data->{path}{nodes}{'anvil-safe-start'}." --enable\n";
	}
	$shell_call .= "
if \$(".$an->data->{path}{'grep'}." ^tools::anvil-safe-start::enabled ".$an->data->{path}{striker_config}." | ".$an->data->{path}{'grep'}." -q 1\$); 
then
    ".$an->data->{path}{echo}." enabled; 
else 
    ".$an->data->{path}{echo}." disabled;
fi
";
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
		
		if ($line eq "enabled")
		{
			if ($an->data->{sys}{install_manifest}{'use_anvil-safe-start'})
			{
				# Good.
				$sas_return_code = 1;
			}
			else
			{
				# Not good... should have been disabled.
				$sas_return_code = 3;
			}
		}
		elsif ($line eq "disabled")
		{
			if ($an->data->{sys}{install_manifest}{'use_anvil-safe-start'})
			{
				# Not good, should have been disabled
				$sas_return_code = 4;
			}
			else
			{
				# Good
				$sas_return_code = 2;
			}
		}
	}

	### anvil-kick-apc-ups
	# If requested, enable anvil-kick-apc-ups, otherwise, disable it.
	my $akau_return_code = 0;
	   $shell_call       = $an->data->{path}{nodes}{'anvil-kick-apc-ups'}." --disable\n";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::install_manifest::use_anvil-kick-apc-ups", value1 => $an->data->{sys}{install_manifest}{'use_anvil-kick-apc-ups'},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{install_manifest}{'use_anvil-kick-apc-ups'})
	{
		$shell_call = $an->data->{path}{nodes}{'anvil-kick-apc-ups'}." --enable\n";
	}
	$shell_call .= "
if \$(".$an->data->{path}{'grep'}." -q '^tools::anvil-kick-apc-ups::enabled\\s*=\\s*1' /etc/striker/striker.conf);
then 
    ".$an->data->{path}{echo}." enabled; 
else 
    ".$an->data->{path}{echo}." disabled;
fi
";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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

		if ($line eq "enabled")
		{
			if ($an->data->{sys}{install_manifest}{'use_anvil-kick-apc-ups'})
			{
				# Good.
				$akau_return_code = 1;
			}
			else
			{
				# Not good... should have been disabled.
				$akau_return_code = 3;
			}
		}
		elsif ($line eq "disabled")
		{
			if ($an->data->{sys}{install_manifest}{'use_anvil-kick-apc-ups'})
			{
				# Not good, should have been disabled
				$akau_return_code = 4;
			}
			else
			{
				# Good
				$akau_return_code = 2;
			}
		}
	}
	
	### ScanCore
	# If requested, enable ScanCore, otherwise, disable it.
	my $sc_return_code = 0;
	   $shell_call     = $an->data->{path}{nodes}{scancore}." --disable\n";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::install_manifest::use_scancore", value1 => $an->data->{sys}{install_manifest}{use_scancore},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{install_manifest}{use_scancore})
	{
		$shell_call = $an->data->{path}{nodes}{scancore}." --enable\n";
	}
	$shell_call .= "
if \$(".$an->data->{path}{'grep'}." -q '^scancore::enabled\\s*=\\s*1' /etc/striker/striker.conf);
then 
    ".$an->data->{path}{echo}." enabled; 
else 
    ".$an->data->{path}{echo}." disabled;
fi
";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
		
		if ($line eq "enabled")
		{
			if ($an->data->{sys}{install_manifest}{use_scancore})
			{
				# Good.
				$sc_return_code = 1;
			}
			else
			{
				# Not good... should have been disabled.
				$sc_return_code = 3;
			}
		}
		elsif ($line eq "disabled")
		{
			if ($an->data->{sys}{install_manifest}{use_scancore})
			{
				# Not good, should have been disabled
				$sc_return_code = 4;
			}
			else
			{
				# Good
				$sc_return_code = 2;
			}
		}
	}
	
	# Now we will run post_install, if it exists. This is a user script so we don't analyze it, we just 
	# run it.
	$shell_call .= "
if [ -e '".$an->data->{path}{nodes}{post_install}."' ];
then 
    ".$an->data->{path}{nodes}{post_install}." 
fi
";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	# Configure logrotate.
	my $logrotate = "compress";
	foreach my $log_file (sort {$a cmp $b} keys %{$an->data->{sys}{logrotate}})
	{
		my $count     =  $an->data->{sys}{logrotate}{$log_file}{count}     ? $an->data->{sys}{logrotate}{$log_file}{count}     : 5;
		my $frequency =  $an->data->{sys}{logrotate}{$log_file}{frequency} ? $an->data->{sys}{logrotate}{$log_file}{frequency} : "weekly";
		my $maxsize   =  $an->data->{sys}{logrotate}{$log_file}{maxsize}   ? $an->data->{sys}{logrotate}{$log_file}{maxsize}   : "100M";
		   $logrotate .= "
/var/log/$log_file {
    rotate $count
    $frequency
    maxsize $maxsize
}
";
	}
	$shell_call = "
".$an->data->{path}{cat}." > ".$an->data->{path}{logrotate_config}." << EOF
$logrotate
EOF
";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	# 0 == No changes made
	# 1 == Enabled successfully
	# 2 == Disabled successfully
	# 3 == Failed to enable
	# 4 == Failed to disable
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "sas_return_code",  value1 => $sas_return_code,
		name2 => "akau_return_code", value2 => $akau_return_code,
		name3 => "sc_return_code",   value3 => $sc_return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($sas_return_code, $akau_return_code, $sc_return_code);
}

# This generates the default 'cluster.conf' file.
sub generate_cluster_conf
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "generate_cluster_conf" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1_short_name = $an->data->{sys}{anvil}{node1}{short_name};
	my $node1_full_name  = $an->data->{sys}{anvil}{node1}{name};
	my $node2_short_name = $an->data->{sys}{anvil}{node2}{short_name};
	my  $node2_full_name = $an->data->{sys}{anvil}{node2}{name};
	my  $shared_lv       = "/dev/${node1_short_name}_vg0".$an->data->{path}{shared};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "node1_short_name", value1 => $node1_short_name,
		name2 => "node1_full_name",  value2 => $node1_full_name,
		name3 => "node2_short_name", value3 => $node2_short_name,
		name4 => "node2_full_name",  value4 => $node2_full_name,
		name5 => "shared_lv",        value5 => $shared_lv,
	}, file => $THIS_FILE, line => __LINE__});
	
	# NOTE: According to:
	#       - https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Cluster_Administration/s1-config-network-conga-CA.html
	#       - https://access.redhat.com/solutions/162193
	#       Unicast is not recommended in general, and in particular with GFS2. However, the primary
	#       concern is overhead/performance. Given that the Anvil! is strictly a 2-node setup and given
	#       that performance on the gfs2 partition is of minimal concern, the benefit of wider network 
	#       support of unicast wins out, so we're using UDP-unicast instead of UDP-multicast.
	#       
	# NOTE: RRP can't be used because SCTP is not compatible/reliable with DLM.
	# 
	### NOTE: To future me; <?xml...> MUST start at the top of the file, don't move it down (again...)
	$an->data->{sys}{cluster_conf} = "<?xml version=\"1.0\"?>
<cluster name=\"".$an->data->{cgi}{anvil_name}."\" config_version=\"1\">
	<cman expected_votes=\"1\" two_node=\"1\" transport=\"udpu\" />
	<clusternodes>
		<clusternode name=\"".$an->data->{sys}{anvil}{node1}{name}."\" nodeid=\"1\">
			<fence>\n";
	# Fence methods for node 1
	foreach my $i (sort {$a cmp $b} keys %{$an->data->{fence}{node}{$node1_full_name}{order}})
	{
		foreach my $method (keys %{$an->data->{fence}{node}{$node1_full_name}{order}{$i}{method}})
		{
			$an->data->{sys}{cluster_conf} .= "\t\t\t\t<method name=\"$method\">\n";
			
			# Count how many devices we have.
			my $device_count = 0;
			foreach my $j (keys %{$an->data->{fence}{node}{$node1_full_name}{order}{$i}{method}{$method}{device}})
			{
				$device_count++;
			}
			
			# If there are multiple methods, we need to say 'off', then additional entries for 
			# 'on'. Otherwise, 'reboot' is fine.
			if ($device_count == 1)
			{
				# Reboot.
				foreach my $j (keys %{$an->data->{fence}{node}{$node1_full_name}{order}{$i}{method}{$method}{device}})
				{
					$an->data->{sys}{cluster_conf} .= "\t\t\t\t\t".$an->data->{fence}{node}{$node1_full_name}{order}{$i}{method}{$method}{device}{$j}{string}."\n";
				}
			}
			else
			{
				# Off
				foreach my $j (keys %{$an->data->{fence}{node}{$node1_full_name}{order}{$i}{method}{$method}{device}})
				{
					my $say_string =  $an->data->{fence}{node}{$node1_full_name}{order}{$i}{method}{$method}{device}{$j}{string};
					   $say_string =~ s/reboot/off/;
					$an->data->{sys}{cluster_conf} .= "\t\t\t\t\t$say_string\n";
				}
				# On
				foreach my $j (keys %{$an->data->{fence}{node}{$node1_full_name}{order}{$i}{method}{$method}{device}})
				{
					my $say_string =  $an->data->{fence}{node}{$node1_full_name}{order}{$i}{method}{$method}{device}{$j}{string};
					   $say_string =~ s/reboot/on/;
					$an->data->{sys}{cluster_conf} .= "\t\t\t\t\t$say_string\n";
				}
			}
			$an->data->{sys}{cluster_conf} .= "\t\t\t\t</method>\n";
		}
	}
	$an->data->{sys}{cluster_conf} .= "\t\t\t\t<method name=\"delay\">
					<device name=\"delay\" port=\"".$node1_short_name."\" action=\"off\"/>
				</method>
			</fence>
		</clusternode>
		<clusternode name=\"".$an->data->{sys}{anvil}{node2}{name}."\" nodeid=\"2\">
			<fence>\n";
	# Fence methods for node 2
	foreach my $i (sort {$a cmp $b} keys %{$an->data->{fence}{node}{$node2_full_name}{order}})
	{
		foreach my $method (keys %{$an->data->{fence}{node}{$node2_full_name}{order}{$i}{method}})
		{
			$an->data->{sys}{cluster_conf} .= "\t\t\t\t<method name=\"$method\">\n";
			
			# Count how many devices we have.
			my $device_count = 0;
			foreach my $j (keys %{$an->data->{fence}{node}{$node2_full_name}{order}{$i}{method}{$method}{device}})
			{
				$device_count++;
			}
			
			# If there are multiple methods, we need to say 'off', then additional entries for 
			# 'on'. Otherwise, 'reboot' is fine.
			if ($device_count == 1)
			{
				# Reboot.
				foreach my $j (keys %{$an->data->{fence}{node}{$node2_full_name}{order}{$i}{method}{$method}{device}})
				{
					$an->data->{sys}{cluster_conf} .= "\t\t\t\t\t".$an->data->{fence}{node}{$node2_full_name}{order}{$i}{method}{$method}{device}{$j}{string}."\n";
				}
			}
			else
			{
				# Off
				foreach my $j (keys %{$an->data->{fence}{node}{$node2_full_name}{order}{$i}{method}{$method}{device}})
				{
					my $say_string =  $an->data->{fence}{node}{$node2_full_name}{order}{$i}{method}{$method}{device}{$j}{string};
					   $say_string =~ s/reboot/off/;
					$an->data->{sys}{cluster_conf} .= "\t\t\t\t\t$say_string\n";
				}
				# On
				foreach my $j (keys %{$an->data->{fence}{node}{$node2_full_name}{order}{$i}{method}{$method}{device}})
				{
					my $say_string =  $an->data->{fence}{node}{$node2_full_name}{order}{$i}{method}{$method}{device}{$j}{string};
					   $say_string =~ s/reboot/on/;
					$an->data->{sys}{cluster_conf} .= "\t\t\t\t\t$say_string\n";
				}
			}
			$an->data->{sys}{cluster_conf} .= "\t\t\t\t</method>\n";
		}
	}
	$an->data->{sys}{cluster_conf} .= "\t\t\t\t<method name=\"delay\">
					<device name=\"delay\" port=\"".$node2_short_name."\" action=\"off\" />
				</method>
			</fence>
		</clusternode>
	</clusternodes>
	<fencedevices>\n";
	foreach my $device (sort {$a cmp $b} keys %{$an->data->{fence}{device}})
	{
		foreach my $name (sort {$a cmp $b} keys %{$an->data->{fence}{device}{$device}{name}})
		{
			$an->data->{sys}{cluster_conf} .= "\t\t".$an->data->{fence}{device}{$device}{name}{$name}{string}."\n";
		}
	}
	$an->data->{sys}{cluster_conf} .= "\t\t<fencedevice agent=\"fence_delay\" name=\"delay\"/>
	</fencedevices>
	<fence_daemon post_join_delay=\"".$an->data->{sys}{post_join_delay}."\" />
	<totem rrp_mode=\"none\" secauth=\"off\"/>
	<rm log_level=\"5\">
		<resources>
			<script file=\"".$an->data->{path}{initd}."/libvirtd\" name=\"libvirtd\"/>
			<script file=\"".$an->data->{path}{initd}."/drbd\" name=\"drbd\"/>
			<script file=\"".$an->data->{path}{initd}."/wait-for-drbd\" name=\"wait-for-drbd\"/>
			<script file=\"".$an->data->{path}{initd}."/clvmd\" name=\"clvmd\"/>
			<clusterfs device=\"$shared_lv\" force_unmount=\"1\" self_fence=\"1\" fstype=\"gfs2\" mountpoint=\"".$an->data->{path}{shared}."\" name=\"sharedfs\" />
		</resources>
		<failoverdomains>
			<failoverdomain name=\"only_n01\" nofailback=\"1\" ordered=\"0\" restricted=\"1\">
				<failoverdomainnode name=\"".$an->data->{sys}{anvil}{node1}{name}."\"/>
			</failoverdomain>
			<failoverdomain name=\"only_n02\" nofailback=\"1\" ordered=\"0\" restricted=\"1\">
				<failoverdomainnode name=\"".$an->data->{sys}{anvil}{node2}{name}."\"/>
			</failoverdomain>
			<failoverdomain name=\"primary_n01\" nofailback=\"1\" ordered=\"1\" restricted=\"1\">
				<failoverdomainnode name=\"".$an->data->{sys}{anvil}{node1}{name}."\" priority=\"1\"/>
				<failoverdomainnode name=\"".$an->data->{sys}{anvil}{node2}{name}."\" priority=\"2\"/>
			</failoverdomain>
			<failoverdomain name=\"primary_n02\" nofailback=\"1\" ordered=\"1\" restricted=\"1\">
				<failoverdomainnode name=\"".$an->data->{sys}{anvil}{node1}{name}."\" priority=\"2\"/>
				<failoverdomainnode name=\"".$an->data->{sys}{anvil}{node2}{name}."\" priority=\"1\"/>
			</failoverdomain>
		</failoverdomains>
		<service name=\"storage_n01\" autostart=\"1\" domain=\"only_n01\" exclusive=\"0\" recovery=\"restart\">
			<script ref=\"drbd\">
				<script ref=\"wait-for-drbd\">
					<script ref=\"clvmd\">
						<clusterfs ref=\"sharedfs\"/>
					</script>
				</script>
			</script>
		</service>
		<service name=\"storage_n02\" autostart=\"1\" domain=\"only_n02\" exclusive=\"0\" recovery=\"restart\">
			<script ref=\"drbd\">
				<script ref=\"wait-for-drbd\">
					<script ref=\"clvmd\">
						<clusterfs ref=\"sharedfs\"/>
					</script>
				</script>
			</script>
		</service>
		<service name=\"libvirtd_n01\" autostart=\"1\" domain=\"only_n01\" exclusive=\"0\" recovery=\"restart\">
			<script ref=\"libvirtd\"/>
		</service>
		<service name=\"libvirtd_n02\" autostart=\"1\" domain=\"only_n02\" exclusive=\"0\" recovery=\"restart\">
			<script ref=\"libvirtd\"/>
		</service>
	</rm>
</cluster>";
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::cluster_conf", value1 => $an->data->{sys}{cluster_conf},
	}, file => $THIS_FILE, line => __LINE__});
	return(0);
}

# This generates the DRBD config files to later be written on the nodes.
sub generate_drbd_config_files
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "generate_drbd_config_files" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1 = $an->data->{sys}{anvil}{node1}{name};
	my $node2 = $an->data->{sys}{anvil}{node2}{name};
	
	### TODO: Detect if the SN is on a 10 Gbps network and, if so, bump up
	###       the resync rate to 300M;
	# Generate the config files we'll use if we don't find existing configs
	# on one of the servers.
	$an->data->{drbd}{global_common} = "
# These are options to set for the DRBD daemon sets the default values for
# resources.
global {
	# This tells DRBD that you allow it to report this installation to 
	# LINBIT for statistical purposes. If you have privacy concerns, set
	# this to 'no'. The default is 'ask' which will prompt you each time
	# DRBD is updated. Set to 'yes' to allow it without being prompted.
	usage-count yes;
 
	# minor-count dialog-refresh disable-ip-verification
}

common {
	handlers {
		# pri-on-incon-degr \"/usr/lib/drbd/notify-pri-on-incon-degr.sh; /usr/lib/drbd/notify-emergency-reboot.sh; echo b > /proc/sysrq-trigger ; reboot -f\";
		# pri-lost-after-sb \"/usr/lib/drbd/notify-pri-lost-after-sb.sh; /usr/lib/drbd/notify-emergency-reboot.sh; echo b > /proc/sysrq-trigger ; reboot -f\";
		# local-io-error \"/usr/lib/drbd/notify-io-error.sh; /usr/lib/drbd/notify-emergency-shutdown.sh; echo o > /proc/sysrq-trigger ; halt -f\";
		# split-brain \"/usr/lib/drbd/notify-split-brain.sh root\";
		# out-of-sync \"/usr/lib/drbd/notify-out-of-sync.sh root\";
		# before-resync-target \"/usr/lib/drbd/snapshot-resync-target-lvm.sh -p 15 -- -c 16k\";
		# after-resync-target /usr/lib/drbd/unsnapshot-resync-target-lvm.sh;
 
		# Hook into cman's fencing.
		fence-peer \"".$an->data->{path}{striker_tools}."/rhcs_fence\";
	}
 
	# NOTE: this is not required or even recommended with pacemaker. remove
	# 	this options as soon as pacemaker is setup.
	startup {
		# This tells DRBD to promote both nodes to 'primary' when this
		# resource starts. However, we will let pacemaker control this
		# so we comment it out, which tells DRBD to leave both nodes
		# as secondary when drbd starts.
		become-primary-on both;
	}
 
	options {
		# cpu-mask on-no-data-accessible\n";
	if ($an->data->{cgi}{'anvil_drbd_options_cpu-mask'})
	{
		$an->data->{drbd}{global_common} .= "		cpu-mask ".$an->data->{cgi}{'anvil_drbd_options_cpu-mask'}.";\n";
	}
	$an->data->{drbd}{global_common} .= "		# Regarding LINBIT Ticket# 2015110642000184; Setting this to 
		# 'suspend-io' is safest given the risk of data divergence in
		# some corner cases.
		on-no-data-accessible suspend-io;
	}
 
	disk {
		# size max-bio-bvecs on-io-error fencing disk-barrier disk-flushes
		# disk-drain md-flushes resync-rate resync-after al-extents
		# c-plan-ahead c-delay-target c-fill-target c-max-rate
		# c-min-rate disk-timeout
		fencing resource-and-stonith;
		
		### Set a somewhat more aggressive resync rate. See: 
		### - https://blogs.linbit.com/p/443/drbd-sync-rate-controller-2/
		### Also, from Matt Kereczman of LINBIT (in #drbd on 2016-06-20);
		# For rtt < 50ms, you may want to reduce c-plan-ahead to 10 or 7 (or even 5), and use 
		# 'c-fill-target' 1M to 10M; For rtt >= 100ms, c-plan-ahead 20 is usually a good choice 
		# already. Use c-fill-target = c-max-rate * rtt (rounded up to multiple of 100ms) c-min-rate:
		# pick whatever you think is acceptable without impacting performance c-max-rate: theoretical
		# limit of your hardware. For rtt in the range of 50ms <= rtt < 100ms, you can see which 
		# gives better results.
		# 
		# For 1 Gbps with fast storage/low latency;
		# - For two machines sitting next to each other connected via 1Gbe crossover, I would set: 
		#   c-plan-ahead 7; c-fill-target 1M; c-min-rate 30M; c-max-rate 110M;
		#   
		# For the same, but on 10 Gbps
		# - c-plan-ahead 7; c-fill-target 1M; c-min-rate 300M; c-max-rate 1000M;
		# 
		# In both cases, manually test different 'c-fill-target' rates on a per-deployement basis.
		
		# variable sync speed; 0 = disabled, 5+ = enabled (the number is x*0.1s and should be at 
		# least 10x RTT on the SN). 20 is the recommended default, under 5 is useless.
		c-plan-ahead ".$an->data->{cgi}{'anvil_drbd_disk_c-plan-ahead'}.";
		
		# This should be ~100% of maximum supported speed.
		c-max-rate ".$an->data->{cgi}{'anvil_drbd_disk_c-max-rate'}.";
		
		# Set a target (but not guaranteed) minimum resync rate.
		c-min-rate ".$an->data->{cgi}{'anvil_drbd_disk_c-min-rate'}.";
		
		# This is how much data you want to have in-flight (on the wire). 
		c-fill-target ".$an->data->{cgi}{'anvil_drbd_disk_c-fill-target'}.";
		\n";
	if ($an->data->{cgi}{'anvil_drbd_disk_disk-barrier'})
	{
		$an->data->{drbd}{global_common} .= "		disk-barrier ".$an->data->{cgi}{'anvil_drbd_disk_disk-barrier'}.";\n";
	}
	if ($an->data->{cgi}{'anvil_drbd_disk_disk-flushes'})
	{
		$an->data->{drbd}{global_common} .= "		disk-flushes ".$an->data->{cgi}{'anvil_drbd_disk_disk-flushes'}.";\n";
	}
	if ($an->data->{cgi}{'anvil_drbd_disk_md-flushes'})
	{
		$an->data->{drbd}{global_common} .= "		md-flushes ".$an->data->{cgi}{'anvil_drbd_disk_md-flushes'}.";\n";
	}
	$an->data->{drbd}{global_common} .= "	}
 
	net {
		# protocol timeout max-epoch-size max-buffers unplug-watermark
		# connect-int ping-int sndbuf-size rcvbuf-size ko-count
		# allow-two-primaries cram-hmac-alg shared-secret after-sb-0pri
		# after-sb-1pri after-sb-2pri always-asbp rr-conflict
		# ping-timeout data-integrity-alg tcp-cork on-congestion
		# congestion-fill congestion-extents csums-alg verify-alg
		# use-rle
 
		# Protocol \"C\" tells DRBD not to tell the operating system that
		# the write is complete until the data has reach persistent
		# storage on both nodes. This is the slowest option, but it is
		# also the only one that guarantees consistency between the
		# nodes. It is also required for dual-primary, which we will 
		# be using.
		protocol C;
 
		# Tell DRBD to allow dual-primary. This is needed to enable 
		# live-migration of our servers.
		allow-two-primaries yes;
 
		# This tells DRBD what to do in the case of a split-brain when
		# neither node was primary, when one node was primary and when
		# both nodes are primary. In our case, we'll be running
		# dual-primary, so we can not safely recover automatically. The
		# only safe option is for the nodes to disconnect from one
		# another and let a human decide which node to invalidate. Of 
		after-sb-0pri discard-zero-changes;
		after-sb-1pri discard-secondary;
		after-sb-2pri disconnect;
		
		# Set the network timeout to '10' seconds (10 == 1 second) to
		# match corosync's default timeout.
		ping-timeout 100;
		timeout 100;
		
		### TODO: Experiment with 'max-buffers' of 20 ~ 40k.
		\n";
	if ($an->data->{cgi}{'anvil_drbd_net_max-buffers'})
	{
		$an->data->{drbd}{global_common} .= "		max-buffers ".$an->data->{cgi}{'anvil_drbd_net_max-buffers'}.";\n";
	}
	if ($an->data->{cgi}{'anvil_drbd_net_sndbuf-size'})
	{
		$an->data->{drbd}{global_common} .= "		sndbuf-size ".$an->data->{cgi}{'anvil_drbd_net_sndbuf-size'}.";\n";
	}
	if ($an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'})
	{
		$an->data->{drbd}{global_common} .= "		rcvbuf-size ".$an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'}.";\n";
	}
	$an->data->{drbd}{global_common} .= "	}
}
";
	
	### TODO: Make sure these are updated if we use a read-in resource
	###  file.
	my $node1_pool1_partition = $an->data->{node}{$node1}{pool1}{device};
	my $node1_pool2_partition = $an->data->{node}{$node1}{pool2}{device};
	my $node2_pool1_partition = $an->data->{node}{$node2}{pool1}{device};
	my $node2_pool2_partition = $an->data->{node}{$node2}{pool2}{device};
	if ((not $node1_pool1_partition) or
	    (not $node1_pool2_partition) or
	    (not $node2_pool1_partition) or
	    (not $node2_pool2_partition))
	{
		# Failed to determine DRBD resource backing devices!
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "node1_pool1_partition", value1 => $node1_pool1_partition,
			name2 => "node1_pool2_partition", value2 => $node1_pool2_partition,
			name3 => "node2_pool1_partition", value3 => $node2_pool1_partition,
			name4 => "node2_pool2_partition", value4 => $node2_pool2_partition,
		}, file => $THIS_FILE, line => __LINE__});
		return(1);
	}
	
	my $node1_sn_ip_key = "anvil_node1_sn_ip";
	my $node2_sn_ip_key = "anvil_node2_sn_ip";
	my $node1_sn_ip     = $an->data->{cgi}{$node1_sn_ip_key};
	my $node2_sn_ip     = $an->data->{cgi}{$node2_sn_ip_key};
	if ((not $node1_sn_ip) or (not $node2_sn_ip))
	{
		# Failed to determine Storage Network IPs!
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node1_sn_ip", value1 => $node1_sn_ip,
			name2 => "node2_sn_ip", value2 => $node2_sn_ip,
		}, file => $THIS_FILE, line => __LINE__});
		return(2);
	}
	
	# Still alive? Yay us!
	$an->data->{drbd}{r0} = "
# This is the first DRBD resource. It will store the shared file systems and
# the servers designed to run on node 01.
resource r0 {
	on ".$an->data->{sys}{anvil}{node1}{name}." {
		volume 0 {
			# This sets the device name of this DRBD resouce.
			device       /dev/drbd0 minor 0;
			
			# This tells DRBD what the backing device is for this
			# resource.
			disk         $node1_pool1_partition;
			
			# This controls the location of the metadata. When 
			# 'internal' is used, as we use here, a little space at
			# the end of the backing devices is set aside (roughly
			# 32 MiB per 1 TiB of raw storage). 
			meta-disk    internal;
		}
		
		# This is the address and port to use for DRBD traffic on this
		# node. Multiple resources can use the same IP but the ports
		# must differ. By convention, the first resource uses 7788, the
		# second uses 7789 and so on, incrementing by one for each
		# additional resource. 
		address          ipv4 $node1_sn_ip:7788;
	}
	on ".$an->data->{sys}{anvil}{node2}{name}." {
		volume 0 {
			device       /dev/drbd0 minor 0;
			disk         $node1_pool1_partition;
			meta-disk    internal;
		}
		address          ipv4 $node2_sn_ip:7788;
	}
	disk {
		# TODO: Test the real-world performance differences gained with
		#       these options.
		# This tells DRBD not to bypass the write-back caching on the
		# RAID controller. Normally, DRBD forces the data to be flushed
		# to disk, rather than allowing the write-back cachine to 
		# handle it. Normally this is dangerous, but with 
		# BBU/FBU-backed caching, it is safe. The first option disables
		# disk flushing and the second disabled metadata flushes.
		disk-flushes      no;
		md-flushes        no;
	}
}
";

	$an->data->{drbd}{r1} = "
# This is the resource used for the servers designed to run on node 02.
resource r1 {
	on ".$an->data->{sys}{anvil}{node1}{name}." {
		volume 0 {
			# This sets the device name of this DRBD resouce.
			device       /dev/drbd1 minor 1;
			
			# This tells DRBD what the backing device is for this
			# resource.
			disk         $node1_pool2_partition;
			
			# This controls the location of the metadata. When 
			# 'internal' is used, as we use here, a little space at
			# the end of the backing devices is set aside (roughly
			# 32 MiB per 1 TiB of raw storage). 
			meta-disk    internal;
		}
		
		# This is the address and port to use for DRBD traffic on this
		# node. Multiple resources can use the same IP but the ports
		# must differ. By convention, the first resource uses 7788, the
		# second uses 7789 and so on, incrementing by one for each
		# additional resource. 
		address          ipv4 $node1_sn_ip:7789;
	}
	on ".$an->data->{sys}{anvil}{node2}{name}." {
		volume 0 {
			device       /dev/drbd1 minor 1;
			disk         $node1_pool2_partition;
			meta-disk    internal;
		}
		address          ipv4 $node2_sn_ip:7789;
	}
	disk {
		# TODO: Test the real-world performance differences gained with
		#       these options.
		# This tells DRBD not to bypass the write-back caching on the
		# RAID controller. Normally, DRBD forces the data to be flushed
		# to disk, rather than allowing the write-back cachine to 
		# handle it. Normally this is dangerous, but with 
		# BBU/FBU-backed caching, it is safe. The first option disables
		# disk flushing and the second disabled metadata flushes.
		disk-flushes      no;
		md-flushes        no;
	}
}
";
	
	# Unlike 'read_drbd_resource_files()' which only reads the 'rX.res' files and parses their contents, 
	# this function just slurps in the data from the resource and global common configs.
	$an->InstallManifest->read_drbd_config_on_node({
		node     => $node1, 
		target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
		port     => $an->data->{sys}{anvil}{node1}{use_port}, 
		password => $an->data->{sys}{anvil}{node1}{password},
	});
	$an->InstallManifest->read_drbd_config_on_node({
		node     => $node2, 
		target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
		port     => $an->data->{sys}{anvil}{node2}{use_port}, 
		password => $an->data->{sys}{anvil}{node2}{password},
	});
	
	### Now push over the files I read in, if any.
	if ($an->data->{node}{node1}{has_servers})
	{
		# Node 1 has servers, so use its config data
		$an->data->{drbd}{global_common} = $an->data->{node}{$node1}{drbd_file}{global_common};
		$an->data->{drbd}{r0}            = $an->data->{node}{$node1}{drbd_file}{r0};
		$an->data->{drbd}{r1}            = $an->data->{node}{$node1}{drbd_file}{r1};
	}
	elsif ($an->data->{node}{node2}{has_servers})
	{
		# Node 2 has servers, so use its config data
		$an->data->{drbd}{global_common} = $an->data->{node}{$node2}{drbd_file}{global_common};
		$an->data->{drbd}{r0}            = $an->data->{node}{$node2}{drbd_file}{r0};
		$an->data->{drbd}{r1}            = $an->data->{node}{$node2}{drbd_file}{r1};
	}
	else
	{
		# Global common
		if ($an->data->{node}{$node1}{drbd_file}{global_common})
		{
			$an->data->{drbd}{global_common} = $an->data->{node}{$node1}{drbd_file}{global_common};
		}
		elsif ($an->data->{node}{$node2}{drbd_file}{global_common})
		{
			$an->data->{drbd}{global_common} = $an->data->{node}{$node2}{drbd_file}{global_common};
		}
		# r0.res
		if ($an->data->{node}{$node1}{drbd_file}{r0})
		{
			$an->data->{drbd}{r0} = $an->data->{node}{$node1}{drbd_file}{r0};
		}
		elsif ($an->data->{node}{$node2}{drbd_file}{r0})
		{
			$an->data->{drbd}{r0} = $an->data->{node}{$node2}{drbd_file}{r0};
		}
		# r1.res
		if ($an->data->{node}{$node1}{drbd_file}{r1})
		{
			$an->data->{drbd}{r1} = $an->data->{node}{$node1}{drbd_file}{r1};
		}
		elsif ($an->data->{node}{$node2}{drbd_file}{r1})
		{
			$an->data->{drbd}{r1} = $an->data->{node}{$node2}{drbd_file}{r1};
		}
	}
	
	return (0);
}

# This reads in node 1's lvm.conf, makes sure it is configured for clvmd and stores in.
sub generate_lvm_conf
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "generate_lvm_conf" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Read the /etc/lvm/lvm.conf file on both nodes and look for a custom filter line. The rest of the 
	# config will be loaded into memory and, if one node is found to have a custom filter, it will be 
	# used to on the other node. If neither have a custom filter, then node 1's base config will be 
	# modified and loaded on both nodes.
	my $return_code = 0;
	my $node1       = $an->data->{sys}{anvil}{node1}{name};
	my $node2       = $an->data->{sys}{anvil}{node2}{name};
	$an->InstallManifest->read_lvm_conf_on_node({
		node     => $node1, 
		target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
		port     => $an->data->{sys}{anvil}{node1}{use_port}, 
		password => $an->data->{sys}{anvil}{node1}{password},
	});
	$an->InstallManifest->read_lvm_conf_on_node({
		node     => $node2, 
		target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
		port     => $an->data->{sys}{anvil}{node2}{use_port}, 
		password => $an->data->{sys}{anvil}{node2}{password},
	});
	
	# Now decide what lvm.conf to use.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "sys::filter",            value1 => $an->data->{sys}{lvm_filter},
		name2 => "node::${node1}::filter", value2 => $an->data->{node}{$node1}{lvm_filter},
		name3 => "node::${node2}::filter", value3 => $an->data->{node}{$node2}{lvm_filter},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{node}{node1}{has_servers})
	{
		# Node 1 is active, use its lvm.conf.
		$an->data->{sys}{lvm_conf} = $an->data->{node}{$node1}{lvm_conf};
		$an->Log->entry({log_level => 2, message_key => "log_0270", message_variables => { 
			active_node => $an->data->{sys}{anvil}{node1}{name},
			file        => "lvm.conf",
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($an->data->{node}{node2}{has_servers})
	{
		# Node 2 is active, use its lvm.conf.
		$an->data->{sys}{lvm_conf} = $an->data->{node}{$node2}{lvm_conf};
		$an->Log->entry({log_level => 2, message_key => "log_0270", message_variables => { 
			active_node => $an->data->{sys}{anvil}{node2}{name},
			file        => "lvm.conf",
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif (($an->data->{node}{$node1}{lvm_filter} ne $an->data->{sys}{lvm_filter}) && ($an->data->{node}{$node2}{lvm_filter} ne $an->data->{sys}{lvm_filter}))
	{
		# Both are custom, do they match?
		if ($an->data->{node}{$node1}{lvm_filter} eq $an->data->{node}{$node2}{lvm_filter})
		{
			# We're good. We'll use node 1
			$an->data->{sys}{lvm_conf} = $an->data->{node}{$node1}{lvm_conf};
			$an->Log->entry({log_level => 2, message_key => "log_0152", file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Both are custom and they don't match, time to bail out.
			$return_code = 1;
			$an->Log->entry({log_level => 1, message_key => "log_0153", file => $THIS_FILE, line => __LINE__});
		}
	}
	elsif ($an->data->{node}{$node1}{lvm_filter} ne $an->data->{sys}{lvm_filter})
	{
		# Node 1 has a custom filter, we'll use it
		$an->data->{sys}{lvm_conf} = $an->data->{node}{$node1}{lvm_conf};
		$an->Log->entry({log_level => 2, message_key => "log_0154", message_variables => {
			node => $node1, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($an->data->{node}{$node2}{lvm_filter} ne $an->data->{sys}{lvm_filter})
	{
		# Node 2 has a custom filter, we'll use it
		$an->data->{sys}{lvm_conf} = $an->data->{node}{$node2}{lvm_conf};
		$an->Log->entry({log_level => 2, message_key => "log_0154", message_variables => {
			node => $node2, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Neither are custom, so pick one that looks sane.
		if (length($an->data->{node}{$node1}{lvm_conf}) > 256)
		{
			# Node 1's copy seems sane, use it.
			$an->data->{sys}{lvm_conf} = $an->data->{node}{$node1}{lvm_conf};
			$an->Log->entry({log_level => 2, message_key => "log_0155", message_variables => {
				node => $node1,  
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (length($an->data->{node}{$node1}{lvm_conf}) > 256)
		{
			# Node 2's copy seems sane, use it.
			$an->data->{sys}{lvm_conf} = $an->data->{node}{$node2}{lvm_conf};
			$an->Log->entry({log_level => 2, message_key => "log_0155", message_variables => {
				node => $node2, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Neither are sane?!
			$return_code = 2;
			$an->Log->entry({log_level => 1, message_key => "log_0156", message_variables => {
				node => $node2, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "length(sys::lvm_conf)", value1 => length($an->data->{sys}{lvm_conf}),
	}, file => $THIS_FILE, line => __LINE__});
	
	# Return codes:
	# 0 = OK
	# 1 = Both nodes have different and custom filter lines.
	# 2 = Read failed.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This calls 'chkconfig' and return '1' or '0' based on whether the daemon is set to run on boot or not.
sub get_chkconfig_data
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_chkconfig_data" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $daemon   = $parameter->{daemon}   ? $parameter->{daemon}   : "";
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "daemon", value1 => $daemon, 
		name2 => "node",   value2 => $node, 
		name3 => "target", value3 => $target, 
		name4 => "port",   value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $init3 = 255;
	my $init5 = 255;

	my $shell_call = $an->data->{path}{chkconfig}." --list $daemon";
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^$daemon/)
		{
			$init3 = ($line =~ /3:(.*?)\s/)[0];
			$init5 = ($line =~ /5:(.*?)\s/)[0];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "init3", value1 => $init3,
				name2 => "init5", value2 => $init5,
			}, file => $THIS_FILE, line => __LINE__});
			
			$init3 = $init3 eq "off" ? 0 : 1;
			$init5 = $init5 eq "off" ? 0 : 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "init3", value1 => $init3,
				name2 => "init5", value2 => $init5,
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /No such file or directory/i)
		{
			# That's a form of 'off'
			$init3 = 0;
			$init5 = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "init3", value1 => $init3,
				name2 => "init5", value2 => $init5,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "return; init3", value1 => $init3,
		name2 => "init5",         value2 => $init5,
	}, file => $THIS_FILE, line => __LINE__});
	return($init3, $init5);
}

### NOTE: Deprecated, using System->get_daemon_state()
# This checks to see if a daemon is running or not.
sub get_daemon_state
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_daemon_state" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $daemon   = $parameter->{daemon}   ? $parameter->{daemon}   : "";
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "daemon", value1 => $daemon, 
		name2 => "node",   value2 => $node, 
		name3 => "target", value3 => $target, 
		name4 => "port",   value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# LSB says
	# 0 == running
	# 3 == stopped
	# Reality;
	# * ipmi;
	#   0 == running
	#   6 == stopped
	# * network
	#   0 == running
	#   0 == stopped   o_O
	# 
	my $running_return_code = 0;
	my $stopped_return_code = 3;
	if ($daemon eq "ipmi")
	{
		$stopped_return_code = 6;
	}
	
	# This will store the state.
	my $state = "";
	
	# Check if the daemon is running currently.
	$an->Log->entry({log_level => 3, message_key => "log_0150", message_variables => {
		target => $node, 
		daemon => $daemon,
	}, file => $THIS_FILE, line => __LINE__});
	my $shell_call = $an->data->{path}{initd}."/$daemon status; ".$an->data->{path}{echo}." return_code:\$?";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /No such file or directory/i)
		{
			# Not installed, pretend it is off.
			$an->Log->entry({log_level => 3, message_key => "log_0151", message_variables => {
				node   => $node, 
				daemon => $daemon,
			}, file => $THIS_FILE, line => __LINE__});
			$state = 0;
			last;
		}
		if ($line =~ /^return_code:(\d+)/)
		{
			my $return_code = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "return_code",         value1 => $return_code,
				name2 => "stopped_return_code", value2 => $stopped_return_code,
				name3 => "running_return_code", value3 => $running_return_code,
			}, file => $THIS_FILE, line => __LINE__});
			if ($return_code eq $running_return_code)
			{
				$state = 1;
			}
			elsif ($return_code eq $stopped_return_code)
			{
				$state = 0;
			}
			else
			{
				$state = "undefined:$return_code";
			}
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "return_code", value1 => $return_code,
				name2 => "state",       value2 => $state,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "state", value1 => $state,
	}, file => $THIS_FILE, line => __LINE__});
	return($state);
}

# This calls 'yum list installed', parses the output and checks to see if the needed packages are installed.
sub get_installed_package_list
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_installed_package_list" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $ok         = 0;
	my $shell_call = $an->data->{path}{yum}." list installed";
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
		next if $line =~ /^Loaded plugins/;
		next if $line =~ /^Loading mirror/;
		next if $line =~ /^Installed Packages/;
		next if $line =~ /^\s/;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^(.*?)\.(.*?)\s+(.*?)\s+\@/)
		{
			my $package   = $1;
			my $arch      = $2;
			my $version   = $3;
			
			# Some packages are defined with the arch to ensure other versions than the active 
			# arch of libraries are installed. To be sure we see that they're installed, we 
			# record the package with arch as '1'.
			my $package_with_arch = "$package.$arch";
			
			# NOTE: Someday record the version.
			$an->data->{node}{$node}{packages}{installed}{$package}           = 1;
			$an->data->{node}{$node}{packages}{installed}{$package_with_arch} = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "Package", value1 => $package,
				name2 => "arch",    value2 => $arch,
				name3 => "version", value3 => $version,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /^(.*?)\.(.*?)\s+(.*)/)
		{
			my $package   = $1;
			my $arch      = $2;
			my $version   = $3;
			
			# Some packages are defined with the arch to ensure other versions than the active 
			# arch of libraries are installed. To be sure we see that they're installed, we 
			# record the package with arch as '1'.
			my $package_with_arch = "$package.$arch";
			
			# NOTE: Someday record the version.
			$an->data->{node}{$node}{packages}{installed}{$package}           = 1;
			$an->data->{node}{$node}{packages}{installed}{$package_with_arch} = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "Package", value1 => $package,
				name2 => "arch",    value2 => $arch,
				name3 => "version", value3 => $version,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /^(.*?)\.(\S*)$/)
		{
			my $package   = $1;
			my $arch      = $2;
			
			# Some packages are defined with the arch to ensure other versions than the active 
			# arch of libraries are installed. To be sure we see that they're installed, we 
			# record the package with arch as '1'.
			my $package_with_arch = "$package.$arch";
			
			$an->data->{node}{$node}{packages}{installed}{$package}           = 1;
			$an->data->{node}{$node}{packages}{installed}{$package_with_arch} = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "Package", value1 => $package,
				name2 => "arch",    value2 => $arch,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

# This calls the specified node and (tries to) read and parse '/etc/redhat-release'
sub get_node_os_version
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_node_os_version" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $brand      = "";
	my $major      = 0;
	my $minor      = 0;
	my $shell_call = $an->data->{path}{cat}." ".$an->data->{path}{'redhat-release'};
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
		
		if ($line =~ /^(.*?) release (\d+)\.(.*)/)
		{
			$brand = $1;
			$major = $2;
			$minor = $3;
			# CentOS uses 'CentOS Linux release 7.0.1406 (Core)', so I need to parse off the 
			# second '.' and whatever is after it.
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
	
	# If it is RHEL, see if it is registered.
	if ($an->data->{node}{$node}{os}{brand} =~ /Red Hat Enterprise Linux Server/i)
	{
		# Example output:
# +-------------------------------------------+
#    System Status Details
# +-------------------------------------------+
# Overall Status: Unknown
# 
# exit:1
# ====
# +-------------------------------------------+
#    System Status Details
# +-------------------------------------------+
# Overall Status: Current
# 
# exit:0
		# See if it has been registered already.
		$an->data->{node}{$node}{os}{registered} = 0;
		my $shell_call = $an->data->{path}{'subscription-manager'}." status; ".$an->data->{path}{echo}." exit:\$?";
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
			
			if ($line =~ /^exit:(\d+)$/)
			{
				my $return_code = $1;
				if ($return_code eq "0")
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

# Read in the RSA public key from a node, creating the RSA keys if needed.
sub get_node_rsa_public_key
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_node_rsa_public_key" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $rsa_key = "";
	#ssh-keygen -t rsa -N "" -b 8191 -f ~/.ssh/id_rsa
	#ssh-keygen -l -f ~/.ssh/id_rsa
	$an->data->{cgi}{anvil_ssh_keysize} = "8191" if not $an->data->{cgi}{anvil_ssh_keysize};
	my $shell_call = "
if [ -e '/root/.ssh/id_rsa.pub' ]; 
then 
    ".$an->data->{path}{cat}." /root/.ssh/id_rsa.pub; 
else 
    ".$an->data->{path}{'ssh-keygen'}." -t rsa -N \"\" -b ".$an->data->{cgi}{anvil_ssh_keysize}." -f ~/.ssh/id_rsa;
    if [ -e '/root/.ssh/id_rsa.pub' ];
    then 
        ".$an->data->{path}{cat}." /root/.ssh/id_rsa.pub; 
    else 
        ".$an->data->{path}{echo}." 'keygen failed';
    fi;
fi";
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
		
		if ($line =~ /^ssh-rsa /)
		{
			$rsa_key = $line;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "node",    value1 => $node,
				name2 => "rsa_key", value2 => $rsa_key,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /has been saved/i)
		{
			# Generated successfully.
			$an->Log->entry({log_level => 2, message_key => "log_0109", message_variables => {
				node => $node, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "rsa_key", value1 => $rsa_key,
	}, file => $THIS_FILE, line => __LINE__});
	return($rsa_key);
}

# This checks for free space on the target node.
sub get_partition_data
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_partition_data" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
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
		
		# A DRBD disk will have an unrecoginized disk label, so skip it. We'll see this when running
		# against a node that is already an existing Anvil! node.
		next if $name =~ /^drbd\d+/;
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "name", value1 => $name,
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
		# We need to count how many existing partitions there are as we go. We'll also start the free
		# size off at 0 so that we can do numerical comparison later.
		$an->data->{node}{$node}{disk}{$disk}{partition_count}  = 0;
		$an->data->{node}{$node}{disk}{$disk}{free_space}{size} = 0;
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
				my $partition                                                          =  $1;
				   $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{start} =  $2;
				   $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{end}   =  $3;
				   $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{size}  =  $4;
				   $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{type}  =  $5;
				   $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{type}  =~ s/\s+(\S+).*$/$1/;	# cuts off 'extended lba' to 'extended'
				   $an->data->{node}{$node}{disk}{$disk}{partition_count}++;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
					name1 => "node::${node}::disk::${disk}::partition::${partition}::start", value1 => $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{start}." (".$an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{start} }).")",
					name2 => "node::${node}::disk::${disk}::partition::${partition}::end",   value2 => $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{end}." (".$an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{end} }).")",
					name3 => "node::${node}::disk::${disk}::partition::${partition}::size",  value3 => $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{size}." (".$an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{size} }).")",
					name4 => "node::${node}::disk::${disk}::partition::${partition}::type",  value4 => $an->data->{node}{$node}{disk}{$disk}{partition}{$partition}{type},
					name5 => "node::${node}::disk::${disk}::partition_count",                value5 => $an->data->{node}{$node}{disk}{$disk}{partition_count},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /^(\d+)B (\d+)B (\d+)B Free Space/)
			{
				# In some cases, there will be two or more "Free Space" entries. We'll watch
				# for the largest and ignore any under 100 MiB to avoid small bits of space 
				# left over from aligned partitions.
				my $free_space_start  = $1;
				my $free_space_end    = $2;
				my $free_space_size   = $3;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
					name1 => "free_space_start",                               value1 => $free_space_start,
					name2 => "free_space_end",                                 value2 => $free_space_end,
					name3 => "free_space_size",                                value3 => $free_space_size,
					name4 => "node::${node}::disk::${disk}::free_space::size", value4 => $an->data->{node}{$node}{disk}{$disk}{free_space}{size},
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($free_space_size <= 268435456)
				{
					# Small amount of space, ignore it.
					$an->Log->entry({log_level => 2, message_key => "log_0172", file => $THIS_FILE, line => __LINE__});
					next;
				}
				
				# If it is the first free space, or larger than ones seen before, record it.
				if (($free_space_size =~ /^\d+$/) && ($free_space_size > $an->data->{node}{$node}{disk}{$disk}{free_space}{size}))
				{
					# This is bigger than any free space we saw before...
					$an->data->{node}{$node}{disk}{$disk}{free_space}{start} = $free_space_start;
					$an->data->{node}{$node}{disk}{$disk}{free_space}{end}   = $free_space_end;
					$an->data->{node}{$node}{disk}{$disk}{free_space}{size}  = $free_space_size;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "node::${node}::disk::${disk}::free_space::start", value1 => $an->data->{node}{$node}{disk}{$disk}{free_space}{start}." (".$an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node}{disk}{$disk}{free_space}{start}}).")",
						name2 => "node::${node}::disk::${disk}::free_space::end",   value2 => $an->data->{node}{$node}{disk}{$disk}{free_space}{end}." (".$an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node}{disk}{$disk}{free_space}{end}}).")",
						name3 => "node::${node}::disk::${disk}::free_space::size",  value3 => $an->data->{node}{$node}{disk}{$disk}{free_space}{size}." (".$an->Readable->bytes_to_hr({'bytes' => $an->data->{node}{$node}{disk}{$disk}{free_space}{size}}).")",
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
	}
	
	# Find which disk is bigger
	my $biggest_disk = "";
	my $biggest_size = 0;
	foreach my $disk (sort {$a cmp $b} keys %{$an->data->{node}{$node}{disk}})
	{
		my $size = $an->data->{node}{$node}{disk}{$disk}{size} ? $an->data->{node}{$node}{disk}{$disk}{size} : 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node}::disk::${disk}::size", value1 => $an->data->{node}{$node}{disk}{$disk}{size},
			name2 => "size",                               value2 => $size,
		}, file => $THIS_FILE, line => __LINE__});
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

### This is a duplication of effort, in part, of get_storage_pool_partitions()...
# This uses 'parted' to gather the existing partition data on a node.
sub get_partition_data_from_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_partition_data_from_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $disk     = $parameter->{disk}     ? $parameter->{disk}     : "";
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "disk",   value1 => $disk, 
		name2 => "node",   value2 => $node, 
		name3 => "target", value3 => $target, 
		name4 => "port",   value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### NOTE: Parted, in its infinite wisdom, doesn't show the partition type when called with --machine
	my $shell_call = $an->data->{path}{parted}." /dev/$disk unit B print free";
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node", value1 => $node,
			name2 => "disk", value2 => $disk,
			name3 => "line", value3 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /(\d+)B (\d+)B (\d+)B Free/i)
		{
			my $start = $1;
			my $end   = $2;
			my $size  = $3;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "start", value1 => $start,
				name2 => "end",   value2 => $end,
				name3 => "size",  value3 => $size." (".$an->Readable->bytes_to_hr({'bytes' => $size}).")",
			}, file => $THIS_FILE, line => __LINE__});
			
			# Sometimes there is a tiny bit of free space in some places, like the start of a 
			# disk. Ignore anything with less that 256 MiB of space.
			if ((not $size) or ($size <= 268435456))
			{
				# Small amount of space, ignore it.
				$an->Log->entry({log_level => 2, message_key => "log_0172", file => $THIS_FILE, line => __LINE__});
				next;
			}
			
			### NOTE: This will miss multiple sizable free chunks.
			# Record the free space info.
			$an->data->{node}{$node}{partition}{free_space}{start} = $start;
			$an->data->{node}{$node}{partition}{free_space}{end}   = $end;
			$an->data->{node}{$node}{partition}{free_space}{size}  = $size;
		}
		elsif ($line =~ /(\d+) (\d+)B (\d+)B (\d+)B(.*)$/)
		{
			my $partition = $1;
			my $start     = $2;
			my $end       = $3;
			my $size      = $4;
			my $details   = $5;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
				name1 => "partition", value1 => $partition,
				name2 => "start",     value2 => $start,
				name3 => "end",       value3 => $end,
				name4 => "size",      value4 => $size." (".$an->Readable->bytes_to_hr({'bytes' => $size}).")",
				name5 => "details",   value5 => $details,
			}, file => $THIS_FILE, line => __LINE__});
			
			# See if I have any details to pull out.
			my $type = "";
			if ($details =~ /^ (\w+)/)
			{
				$type = $1;
			}
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "type", value1 => $type,
			}, file => $THIS_FILE, line => __LINE__});
			
			$an->data->{node}{$node}{partition}{$partition}{start} = $start;
			$an->data->{node}{$node}{partition}{$partition}{end}   = $end;
			$an->data->{node}{$node}{partition}{$partition}{size}  = $size;
			$an->data->{node}{$node}{partition}{$partition}{type}  = $type;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
				name1 => "node::${node}::partition::${partition}::start", value1 => $an->data->{node}{$node}{partition}{$partition}{start},
				name2 => "node::${node}::partition::${partition}::end",   value2 => $an->data->{node}{$node}{partition}{$partition}{end},
				name3 => "node::${node}::partition::${partition}::size",  value3 => $an->data->{node}{$node}{partition}{$partition}{size},
				name4 => "node::${node}::partition::${partition}::type",  value4 => $an->data->{node}{$node}{partition}{$partition}{type},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

# This determines which partitions to use for storage pool 1 and 2. Existing partitions override anything
# else for determining sizes.
sub get_storage_pool_partitions
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_storage_pool_partitions" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### TODO: Determine if I still need this function at all...
	# First up, check for /etc/drbd.d/r{0,1}.res on both nodes.
	my $node1 = $an->data->{sys}{anvil}{node1}{name};
	my $node2 = $an->data->{sys}{anvil}{node2}{name};

	my ($node1_r0_device, $node1_r1_device) = $an->InstallManifest->read_drbd_resource_files({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
			hostname => $an->data->{sys}{anvil}{node1}{name},
		});
	my ($node2_r0_device, $node2_r1_device) = $an->InstallManifest->read_drbd_resource_files({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
			hostname => $an->data->{sys}{anvil}{node2}{name},
		});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node1_r0_device", value1 => $node1_r0_device,
		name2 => "node1_r1_device", value2 => $node1_r1_device,
		name3 => "node2_r0_device", value3 => $node2_r0_device,
		name4 => "node2_r1_device", value4 => $node2_r1_device,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Next, decide what devices I will use if DRBD doesn't exist.
	foreach my $node ($node1, $node2)
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
			### NOTE: The code for a second storage pool remains, but is not actually used.
			# I need to know the label type to determine the partition numbers to use:
			# * If it is 'msdos', I need an extended partition and then a logical partitions. 
			#   (4 for extended, 5 for logical)
			# * If it is 'gpt', I just use one logical partition. (4).
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node}::disk::${disk}::label", value1 => $an->data->{node}{$node}{disk}{$disk}{label},
			}, file => $THIS_FILE, line => __LINE__});
			if ($an->data->{node}{$node}{disk}{$disk}{label} eq "msdos")
			{
				$create_extended_partition = 1;
				$pool1_partition           = 5;
				$pool2_partition           = 6;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "node::${node}::disk::${disk}::partition_count", value1 => $an->data->{node}{$node}{disk}{$disk}{partition_count},
					name2 => "create_extended_partition",                     value2 => $create_extended_partition,
					name3 => "pool1_partition",                               value3 => $pool1_partition,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($an->data->{node}{$node}{disk}{$disk}{partition_count} >= 4)
			{
				# This is either a UEFI system and partition 4 will be /, or we failed on a 
				# previous install between when we partitioned the node and wrote the DRBD 
				# resource config. To tell the difference, we'll look to see what partition
				# type partition 4 is. If nothing, we'll use it. Otherwise it's UEFI and 
				# we'll use partitions 5 and 6 (well, '5').
				my $target   = $an->data->{sys}{anvil}{node1}{use_ip};
				my $port     = $an->data->{sys}{anvil}{node1}{use_port};
				my $password = $an->data->{sys}{anvil}{node1}{password};
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "sys::anvil::node1::name", value1 => $an->data->{sys}{anvil}{node1}{name},
					name2 => "node1",                   value2 => $node1,
				}, file => $THIS_FILE, line => __LINE__});
				if ($an->data->{sys}{anvil}{node2}{name} eq $node)
				{
					$target     = $an->data->{sys}{anvil}{node1}{use_ip};
					$port       = $an->data->{sys}{anvil}{node1}{use_port};
					$password   = $an->data->{sys}{anvil}{node1}{password};
				}
				
				my $use_4      = 1;
				my $shell_call = $an->data->{path}{blkid}." -c /dev/null /dev/".$disk."4";
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
					
					if ($line =~ /UUID=/)
					{
						$use_4 = 0;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "use_4", value1 => $use_4,
						}, file => $THIS_FILE, line => __LINE__});
						last;
					}
				}
				
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "use_4", value1 => $use_4,
				}, file => $THIS_FILE, line => __LINE__});
				if ($use_4)
				{
					# It's a blank partition, we'll use it.
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "sys::anvil::node1::name", value1 => $an->data->{sys}{anvil}{node1}{name},
						name2 => "node1",                   value2 => $node1,
					}, file => $THIS_FILE, line => __LINE__});
					if ($an->data->{sys}{anvil}{node1}{name} eq $node)
					{
						$node1_r0_device = "/dev/".$disk."4";
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "node1_r0_device", value1 => $node1_r0_device,
						}, file => $THIS_FILE, line => __LINE__});
					}
					else
					{
						$node2_r0_device = "/dev/".$disk."4";
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "node2_r0_device", value1 => $node2_r0_device,
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				else
				{
					$pool1_partition = 5;
					$pool2_partition = 6;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "pool1_partition", value1 => $pool1_partition,
						name2 => "pool2_partition", value2 => $pool2_partition,
					}, file => $THIS_FILE, line => __LINE__});
				}
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
	my ($node2_pool1_disk, $node2_pool1_partition) = ($an->data->{node}{$node2}{pool1}{device} =~ /\/dev\/(.*?)(\d)/);
	my $node1_pool2_disk      = "";
	my $node1_pool2_partition = "";
	my $node2_pool2_disk      = "";
	my $node2_pool2_partition = "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node1_pool1_disk",      value1 => $node1_pool1_disk,
		name2 => "node1_pool1_partition", value2 => $node1_pool1_partition,
		name3 => "node1_pool2_disk",      value3 => $node1_pool2_disk,
		name4 => "node1_pool2_partition", value4 => $node1_pool2_partition,
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{cgi}{anvil_storage_pool2_byte_size})
	{
		($node1_pool2_disk, $node1_pool2_partition) = ($an->data->{node}{$node1}{pool2}{device} =~ /\/dev\/(.*?)(\d)/);
		($node2_pool2_disk, $node2_pool2_partition) = ($an->data->{node}{$node2}{pool2}{device} =~ /\/dev\/(.*?)(\d)/);
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "node2_pool1_disk",      value1 => $node2_pool1_disk,
			name2 => "node2_pool1_partition", value2 => $node2_pool1_partition,
			name3 => "node2_pool2_disk",      value3 => $node2_pool2_disk,
			name4 => "node2_pool2_partition", value4 => $node2_pool2_partition,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->data->{node}{$node1}{pool1}{disk}      = $node1_pool1_disk;
	$an->data->{node}{$node1}{pool1}{partition} = $node1_pool1_partition;
	$an->data->{node}{$node2}{pool1}{disk}      = $node2_pool1_disk;
	$an->data->{node}{$node2}{pool1}{partition} = $node2_pool1_partition;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node::${node1}::pool1::disk",      value1 => $an->data->{node}{$node1}{pool1}{disk},
		name2 => "node::${node1}::pool1::partition", value2 => $an->data->{node}{$node1}{pool1}{partition},
		name3 => "node::${node2}::pool1::disk",      value3 => $an->data->{node}{$node2}{pool1}{disk},
		name4 => "node::${node2}::pool1::partition", value4 => $an->data->{node}{$node2}{pool1}{partition},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{cgi}{anvil_storage_pool2_byte_size})
	{
		$an->data->{node}{$node1}{pool2}{disk}      = $node1_pool2_disk;
		$an->data->{node}{$node1}{pool2}{partition} = $node1_pool2_partition;
		$an->data->{node}{$node2}{pool2}{disk}      = $node2_pool2_disk;
		$an->data->{node}{$node2}{pool2}{partition} = $node2_pool2_partition;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "node::${node1}::pool2::disk",      value1 => $an->data->{node}{$node1}{pool2}{disk},
			name2 => "node::${node1}::pool2::partition", value2 => $an->data->{node}{$node1}{pool2}{partition},
			name3 => "node::${node2}::pool2::disk",      value3 => $an->data->{node}{$node2}{pool2}{disk},
			name4 => "node::${node2}::pool2::partition", value4 => $an->data->{node}{$node2}{pool2}{partition},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->data->{node}{$node1}{pool1}{existing_size} = $an->data->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{$node1_pool1_partition}{size} ? $an->data->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{$node1_pool1_partition}{size} : 0;
	$an->data->{node}{$node2}{pool1}{existing_size} = $an->data->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{$node2_pool1_partition}{size} ? $an->data->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{$node2_pool1_partition}{size} : 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node1}::pool1::existing_size", value1 => $an->data->{node}{$node1}{pool1}{existing_size},
		name2 => "node::${node2}::pool1::existing_size", value2 => $an->data->{node}{$node2}{pool1}{existing_size},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{cgi}{anvil_storage_pool2_byte_size})
	{
		$an->data->{node}{$node1}{pool2}{existing_size} = $an->data->{node}{$node1}{disk}{$node1_pool2_disk}{partition}{$node1_pool2_partition}{size} ? $an->data->{node}{$node1}{disk}{$node1_pool2_disk}{partition}{$node1_pool2_partition}{size} : 0;
		$an->data->{node}{$node2}{pool2}{existing_size} = $an->data->{node}{$node2}{disk}{$node2_pool2_disk}{partition}{$node2_pool2_partition}{size} ? $an->data->{node}{$node2}{disk}{$node2_pool2_disk}{partition}{$node2_pool2_partition}{size} : 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node1}::pool2::existing_size", value1 => $an->data->{node}{$node1}{pool2}{existing_size},
			name2 => "node::${node2}::pool2::existing_size", value2 => $an->data->{node}{$node2}{pool2}{existing_size},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return(0);
}

# This checks to see which, if any, packages need to be installed.
sub install_programs
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "install_programs" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# This could take a while
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-be-patient-message", replace => { message => "#!string!explain_0129!#" }});
	
	my $node1    = $an->data->{sys}{anvil}{node1}{name};
	my $node2    = $an->data->{sys}{anvil}{node2}{name};
	my $node1_ok = 1;
	my $node2_ok = 1;
	($node1_ok) = $an->InstallManifest->install_programs_on_node({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		}) if not $an->data->{node}{node1}{has_servers};
	($node2_ok) = $an->InstallManifest->install_programs_on_node({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
		}) if not $an->data->{node}{node2}{has_servers};
	
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0024!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0024!#";
	my $message       = "";
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif (not $node1_ok)
	{
		$node1_class   = "highlight_bad_bold";
		$node1_message = $an->String->get({key => "state_0025", variables => { 
				missing	=>	$an->data->{node}{$node1}{missing_rpms},
				node	=>	$node1,
			}});
		$ok            = 0;
	}
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif (not $node2_ok)
	{
		$node2_class   = "highlight_bad_bold";
		$node2_message = $an->String->get({key => "state_0025", variables => { 
				missing	=>	$an->data->{node}{$node2}{missing_rpms},
				node	=>	$node2,
			}});
		$ok            = 0;
	}

	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0226!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	if (not $ok)
	{
		if ((not $an->data->{node}{$node1}{internet}) or (not $an->data->{node}{$node2}{internet}))
		{
			print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-failed", replace => { message => "#!string!message_0370!#" }});
		}
		elsif (($an->data->{node}{$node1}{os}{brand} =~ /Red Hat/) or ($an->data->{node}{$node2}{os}{brand} =~ /Red Hat/))
		{
			print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-failed", replace => { message => "#!string!message_0369!#" }});
		}
		else
		{
			print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-failed", replace => { message => "#!string!message_0369!#" }});
		}
	}
	
	return($ok);
}

# This builds a list of missing packages and installs any that are missing.
sub install_programs_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "install_programs_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $ok = 1;
	$an->InstallManifest->get_installed_package_list({
		node     => $node, 
		target   => $target, 
		port     => $port, 
		password => $password,
	});
	
	# Figure out which are missing.
	my $to_install = "";
	foreach my $package (sort {$a cmp $b} keys %{$an->data->{packages}{to_install}})
	{
		# Watch for autovivication...
		if ((exists $an->data->{node}{$node}{packages}{installed}{$package}) && ($an->data->{node}{$node}{packages}{installed}{$package} == 1))
		{
			# Already installed
			$an->data->{packages}{to_install}{$package} = 1;
			$an->Log->entry({log_level => 3, message_key => "log_0187", message_variables => {
				node      => $node, 
				'package' => $package, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Needed
			$an->data->{packages}{to_install}{$package} = 1;
			$an->Log->entry({log_level => 2, message_key => "log_0188", message_variables => {
				node      => $node, 
				'package' => $package, 
			}, file => $THIS_FILE, line => __LINE__});
			$to_install .= "$package ";
		}
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node",       value1 => $node,
		name2 => "to_install", value2 => $to_install,
	}, file => $THIS_FILE, line => __LINE__});
	
	if ($to_install)
	{
		# Clear the old cache and install missing packages.
		my $shell_call = $an->data->{path}{yum}." clean expire-cache && ".$an->data->{path}{yum}." ".$an->data->{sys}{yum_switches}." install $to_install";
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
			if (($line =~ /-->/) or (not $line))
			{
				# This is a lot of less than useful output
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# More likely to be of interest.
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Now make sure everything is installed.
	$an->InstallManifest->get_installed_package_list({
		node     => $node, 
		target   => $target, 
		port     => $port, 
		password => $password,
	});
	
	my $missing = "";
	foreach my $package (sort {$a cmp $b} keys %{$an->data->{packages}{to_install}})
	{
		# Watch for autovivication...
		if ((exists $an->data->{node}{$node}{packages}{installed}{$package}) && ($an->data->{node}{$node}{packages}{installed}{$package} == 1))
		{
			# Already installed
			$an->data->{packages}{to_install}{$package} = 1;
			$an->Log->entry({log_level => 3, message_key => "log_0187", message_variables => {
				node      => $node, 
				'package' => $package, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Needed
			$an->Log->entry({log_level => 2, message_key => "log_0188", message_variables => {
				node      => $node, 
				'package' => $package, 
			}, file => $THIS_FILE, line => __LINE__});
			$missing .= "$package ";
		}
	}
	$missing =~ s/\s+$//;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node",    value1 => $node,
		name2 => "missing", value2 => $missing,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If anything is missing, we're toast.
	if ($missing)
	{
		$ok                                    = 0;
		$an->data->{node}{$node}{missing_rpms} = $missing;
	}
	else
	{
		# Make sure the libvirtd bridge is gone.
		my $shell_call = "
if [ -e ".$an->data->{path}{proc_virbr0}." ]; 
then 
    ".$an->data->{path}{virsh}." net-destroy default;
    ".$an->data->{path}{virsh}." net-autostart default --disable;
    ".$an->data->{path}{virsh}." net-undefine default;
else 
    ".$an->data->{path}{cat}." /dev/null > ".$an->data->{path}{etc_virbr0}.";
fi;
if [ -e ".$an->data->{path}{proc_virbr0}." ]; 
then 
    ".$an->data->{path}{echo}." failed;
else
    ".$an->data->{path}{echo}." bridge gone;
fi";
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
			
			if ($line eq "failed")
			{
				# Failed to delete the bridge.
				$ok = 0;
				$an->Log->entry({log_level => 1, message_key => "log_0189", message_variables => {
					node => $node, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line eq "bridge gone")
			{
				# Success
				$an->Log->entry({log_level => 2, message_key => "log_0190", message_variables => {
					node => $node, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# If the MegaCli64 binary exists, make sure there is a symlink to it.
		$shell_call = "
if [ -e '".$an->data->{path}{nodes}{MegaCli64}."' ]; 
then 
    if [ -e '".$an->data->{path}{megacli64}."' ]
    then
        ".$an->data->{path}{echo}." '".$an->data->{path}{megacli64}." symlink exists';
    else
        ".$an->data->{path}{ln}." -s ".$an->data->{path}{nodes}{MegaCli64}." /sbin/
        if [ -e '".$an->data->{path}{megacli64}."' ]
        then
            ".$an->data->{path}{echo}." '".$an->data->{path}{megacli64}." symlink created';
        else
            ".$an->data->{path}{echo}." 'Failed to create ".$an->data->{path}{megacli64}." symlink';
        fi
    fi
else
    ".$an->data->{path}{echo}." 'MegaCli64 not installed.'
fi";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
			
			if ($line =~ /Failed/i)
			{
				# Failed, source exist?
				$ok = 0;
				$an->Log->entry({log_level => 1, message_key => "log_0191", message_variables => {
					program => "MegaCli64", 
					path    => $an->data->{path}{nodes}{MegaCli64}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /exists/i)
			{
				# Already exists.
				$an->Log->entry({log_level => 2, message_key => "log_0192", message_variables => {
					program => "MegaCli64", 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /created/i)
			{
				# Created
				$an->Log->entry({log_level => 2, message_key => "log_0193", message_variables => {
					program => "MegaCli64", 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Now make sure we have the storcli symlink.
		$shell_call = "
if [ -e '".$an->data->{path}{nodes}{storcli64}."' ]; 
then 
    if [ -e '".$an->data->{path}{storcli64}."' ]
    then
        ".$an->data->{path}{echo}." '".$an->data->{path}{storcli64}." symlink exists';
    else
        ".$an->data->{path}{ln}." -s ".$an->data->{path}{nodes}{storcli64}." /sbin/
        if [ -e '".$an->data->{path}{storcli64}."' ]
        then
            ".$an->data->{path}{echo}." '".$an->data->{path}{storcli64}." symlink created';
        else
            ".$an->data->{path}{echo}." 'Failed to create ".$an->data->{path}{storcli64}." symlink';
        fi
    fi
else
    ".$an->data->{path}{echo}." 'storcli64 not installed.'
fi";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
			
			if ($line =~ /Failed/i)
			{
				# Failed, symlink exist?
				$ok = 0;
				$an->Log->entry({log_level => 1, message_key => "log_0191", message_variables => {
					program => "storcli64", 
					path    => $an->data->{path}{nodes}{storcli64}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /exists/i)
			{
				# Already exists.
				$an->Log->entry({log_level => 2, message_key => "log_0192", message_variables => { program => "storcli64" }, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /created/i)
			{
				# Created
				$an->Log->entry({log_level => 2, message_key => "log_0193", message_variables => { program => "storcli64" }, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		### TEMPORARY (Remove once https://bugzilla.redhat.com/show_bug.cgi?id=1285921 has a new resource-agents RPM).
		# Not checking is done for this given it is temporary.
		# Copy the /root/vm.sh to /usr/share/cluster/vm.sh, if it exists.
		$shell_call .= "
if [ -e '/root/vm.sh' ];
then 
    ".$an->data->{path}{echo}." \"# Fix for rhbz#1285921\"
    ".$an->data->{path}{echo}." \"copying fixed vm.sh to /usr/share/cluster/\"
    if [ -e '/usr/share/cluster/vm.sh' ];
    then
        if [ -e '/root/vm.sh.anvil' ];
        then
            ".$an->data->{path}{echo}." \"Backup of vm.sh already exists at /root/vm.sh.anvil. Deleting /usr/share/cluster/vm.sh\"
            ".$an->data->{path}{rm}." -f /usr/share/cluster/vm.sh
        else
            ".$an->data->{path}{echo}." \"Backing up /usr/share/cluster/vm.sh to /root/vm.sh.anvil\"
            ".$an->data->{path}{mv}." /usr/share/cluster/vm.sh /root/vm.sh.anvil
        fi
    fi
    ".$an->data->{path}{cp}." /root/vm.sh /usr/share/cluster/vm.sh 
    ".$an->data->{path}{'chown'}." root:root /usr/share/cluster/vm.sh
    ".$an->data->{path}{'chmod'}." 755 /usr/share/cluster/vm.sh
    ".$an->data->{path}{'sleep'}." 5
    ".$an->data->{path}{initd}."/ricci restart
else
    ".$an->data->{path}{echo}." \"/root/vm.sh doesn't exist.\"
fi
";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	
	return($ok);
}

# This asks the user to unplug and then plug back in all network interfaces in order to map the physical 
# interfaces to MAC addresses.
sub map_network
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "map_network" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1 = $an->data->{sys}{anvil}{node1}{name};
	my $node2 = $an->data->{sys}{anvil}{node2}{name};
	my ($node1_return_code) = $an->InstallManifest->map_network_on_node({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
			remap    => 0, 
			say_node => "#!string!device_0005!#",
		});
	my ($node2_return_code) = $an->InstallManifest->map_network_on_node({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
			remap    => 0, 
			say_node => "#!string!device_0006!#",
		});
	
	# Loop through the MACs seen and see if we've got a match for all already. If any are missing, we'll
	# need to remap.
	# These will be all populated *if*;
	# * The MACs seen on each node match MACs passed in from CGI (or 
	# * Loaded from manifest
	# * If the existing network appears complete already.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0012", message_variables => {
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
	
	# If any are missing, a remap will be needed.
	# Node 1
	$an->data->{conf}{node}{$node1}{set_nic}{bcn_link1} = "" if not defined $an->data->{conf}{node}{$node1}{set_nic}{bcn_link1};
	$an->data->{conf}{node}{$node1}{set_nic}{bcn_link2} = "" if not defined $an->data->{conf}{node}{$node1}{set_nic}{bcn_link2};
	$an->data->{conf}{node}{$node1}{set_nic}{sn_link1}  = "" if not defined $an->data->{conf}{node}{$node1}{set_nic}{sn_link1};
	$an->data->{conf}{node}{$node1}{set_nic}{sn_link2}  = "" if not defined $an->data->{conf}{node}{$node1}{set_nic}{sn_link2};
	$an->data->{conf}{node}{$node1}{set_nic}{ifn_link1} = "" if not defined $an->data->{conf}{node}{$node1}{set_nic}{ifn_link1};
	$an->data->{conf}{node}{$node1}{set_nic}{ifn_link2} = "" if not defined $an->data->{conf}{node}{$node1}{set_nic}{ifn_link2};
	# Node 2
	$an->data->{conf}{node}{$node2}{set_nic}{bcn_link1} = "" if not defined $an->data->{conf}{node}{$node2}{set_nic}{bcn_link1};
	$an->data->{conf}{node}{$node2}{set_nic}{bcn_link2} = "" if not defined $an->data->{conf}{node}{$node2}{set_nic}{bcn_link2};
	$an->data->{conf}{node}{$node2}{set_nic}{sn_link1}  = "" if not defined $an->data->{conf}{node}{$node2}{set_nic}{sn_link1};
	$an->data->{conf}{node}{$node2}{set_nic}{sn_link2}  = "" if not defined $an->data->{conf}{node}{$node2}{set_nic}{sn_link2};
	$an->data->{conf}{node}{$node2}{set_nic}{ifn_link1} = "" if not defined $an->data->{conf}{node}{$node2}{set_nic}{ifn_link1};
	$an->data->{conf}{node}{$node2}{set_nic}{ifn_link2} = "" if not defined $an->data->{conf}{node}{$node2}{set_nic}{ifn_link2};
	foreach my $nic (sort {$a cmp $b} keys %{$an->data->{conf}{node}{$node1}{current_nic}})
	{
		my $mac = $an->data->{conf}{node}{$node1}{current_nic}{$nic};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0009", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::bcn_link1", value1 => $an->data->{conf}{node}{$node1}{set_nic}{bcn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node1_bcn_link2_mac})
		{
			$an->data->{conf}{node}{$node1}{set_nic}{bcn_link2} = $mac;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::bcn_link2", value1 => $an->data->{conf}{node}{$node1}{set_nic}{bcn_link2},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node1_sn_link1_mac})
		{
			$an->data->{conf}{node}{$node1}{set_nic}{sn_link1} = $mac;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::sn_link1", value1 => $an->data->{conf}{node}{$node1}{set_nic}{sn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node1_sn_link2_mac})
		{
			$an->data->{conf}{node}{$node1}{set_nic}{sn_link2} = $mac;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::sn_link2", value1 => $an->data->{conf}{node}{$node1}{set_nic}{sn_link2},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node1_ifn_link1_mac})
		{
			$an->data->{conf}{node}{$node1}{set_nic}{ifn_link1} = $mac;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::ifn_link1", value1 => $an->data->{conf}{node}{$node1}{set_nic}{ifn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node1_ifn_link2_mac})
		{
			$an->data->{conf}{node}{$node1}{set_nic}{ifn_link2} = $mac;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0009", message_variables => {
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::bcn_link1", value1 => $an->data->{conf}{node}{$node2}{set_nic}{bcn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node2_bcn_link2_mac})
		{
			$an->data->{conf}{node}{$node2}{set_nic}{bcn_link2} = $mac;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::bcn_link2", value1 => $an->data->{conf}{node}{$node2}{set_nic}{bcn_link2},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node2_sn_link1_mac})
		{
			$an->data->{conf}{node}{$node2}{set_nic}{sn_link1} = $mac;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::sn_link1", value1 => $an->data->{conf}{node}{$node2}{set_nic}{sn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node2_sn_link2_mac})
		{
			$an->data->{conf}{node}{$node2}{set_nic}{sn_link2} = $mac;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::sn_link2", value1 => $an->data->{conf}{node}{$node2}{set_nic}{sn_link2},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node2_ifn_link1_mac})
		{
			$an->data->{conf}{node}{$node2}{set_nic}{ifn_link1} = $mac;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::ifn_link1", value1 => $an->data->{conf}{node}{$node2}{set_nic}{ifn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $an->data->{cgi}{anvil_node2_ifn_link2_mac})
		{
			$an->data->{conf}{node}{$node2}{set_nic}{ifn_link2} = $mac;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
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
	
	# Now determine if a remap is needed. If ifn_bridge1 exists, assume it is configured and skip.
	my $node1_remap_needed = 0;
	my $node2_remap_needed = 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_remap_needed", value1 => $node1_remap_needed,
		name2 => "node2_remap_needed", value2 => $node2_remap_needed,
	}, file => $THIS_FILE, line => __LINE__});
	
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
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "conf::node::${node}::set_nic::${nic}", value1 => $an->data->{conf}{node}{$node}{set_nic}{$nic},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	else
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
			name1 => "conf::node::${node1}::set_nic::bcn_link1", value1 => $an->data->{conf}{node}{$node1}{set_nic}{bcn_link1},
			name2 => "conf::node::${node1}::set_nic::bcn_link2", value2 => $an->data->{conf}{node}{$node1}{set_nic}{bcn_link2},
			name3 => "conf::node::${node1}::set_nic::sn_link1",  value3 => $an->data->{conf}{node}{$node1}{set_nic}{sn_link1},
			name4 => "conf::node::${node1}::set_nic::sn_link2",  value4 => $an->data->{conf}{node}{$node1}{set_nic}{sn_link2},
			name5 => "conf::node::${node1}::set_nic::ifn_link1", value5 => $an->data->{conf}{node}{$node1}{set_nic}{ifn_link1},
			name6 => "conf::node::${node1}::set_nic::ifn_link2", value6 => $an->data->{conf}{node}{$node1}{set_nic}{ifn_link2},
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $an->data->{conf}{node}{$node1}{set_nic}{bcn_link1}) or 
		    (not $an->data->{conf}{node}{$node1}{set_nic}{bcn_link2}) or
		    (not $an->data->{conf}{node}{$node1}{set_nic}{sn_link1})  or
		    (not $an->data->{conf}{node}{$node1}{set_nic}{sn_link2})  or
		    (not $an->data->{conf}{node}{$node1}{set_nic}{ifn_link1}) or
		    (not $an->data->{conf}{node}{$node1}{set_nic}{ifn_link2}))
		{
			$node1_remap_needed = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node1_remap_needed", value1 => $node1_remap_needed,
			}, file => $THIS_FILE, line => __LINE__});
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
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "conf::node::${node}::set_nic::${nic}", value1 => $an->data->{conf}{node}{$node}{set_nic}{$nic},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	else
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
			name1 => "conf::node::${node2}::set_nic::bcn_link1", value1 => $an->data->{conf}{node}{$node2}{set_nic}{bcn_link1},
			name2 => "conf::node::${node2}::set_nic::bcn_link2", value2 => $an->data->{conf}{node}{$node2}{set_nic}{bcn_link2},
			name3 => "conf::node::${node2}::set_nic::sn_link1",  value3 => $an->data->{conf}{node}{$node2}{set_nic}{sn_link1},
			name4 => "conf::node::${node2}::set_nic::sn_link2",  value4 => $an->data->{conf}{node}{$node2}{set_nic}{sn_link2},
			name5 => "conf::node::${node2}::set_nic::ifn_link1", value5 => $an->data->{conf}{node}{$node2}{set_nic}{ifn_link1},
			name6 => "conf::node::${node2}::set_nic::ifn_link2", value6 => $an->data->{conf}{node}{$node2}{set_nic}{ifn_link2},
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $an->data->{conf}{node}{$node2}{set_nic}{bcn_link1}) or 
		    (not $an->data->{conf}{node}{$node2}{set_nic}{bcn_link2}) or
		    (not $an->data->{conf}{node}{$node2}{set_nic}{sn_link1})  or
		    (not $an->data->{conf}{node}{$node2}{set_nic}{sn_link2})  or
		    (not $an->data->{conf}{node}{$node2}{set_nic}{ifn_link1}) or
		    (not $an->data->{conf}{node}{$node2}{set_nic}{ifn_link2}))
		{
			$node2_remap_needed = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node2_remap_needed", value1 => $node2_remap_needed,
			}, file => $THIS_FILE, line => __LINE__});
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
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_remap_needed", value1 => $node1_remap_needed,
		name2 => "node2_remap_needed", value2 => $node2_remap_needed,
	}, file => $THIS_FILE, line => __LINE__});
	return($node1_remap_needed, $node2_remap_needed);
}

# This downloads and runs the 'anvil-map-network' script
sub map_network_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "map_network_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### TODO: Why are we not using $an->Remote->remote_call() ?
	my $remap      = $parameter->{remap}    ? $parameter->{remap}    : "";
	my $say_node   = $parameter->{say_node} ? $parameter->{say_node} : "";
	my $node       = $parameter->{node}     ? $parameter->{node}     : "";
	my $target     = $parameter->{target}   ? $parameter->{target}   : "";
	my $port       = $parameter->{port}     ? $parameter->{port}     : 22;
	my $ssh_fh_key = $target.":".$port;
	my $password   = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "remap",    value1 => $remap, 
		name2 => "say_node", value2 => $say_node, 
		name3 => "node",     value3 => $node, 
		name4 => "target",   value4 => $target, 
		name5 => "port",     value5 => $port, 
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "proceed",                     value1 => $proceed,
		name2 => "return_code",                 value2 => $return_code,
		name3 => "ssh_fh",                      value3 => $ssh_fh,
		name4 => "node::${ssh_fh_key}::ssh_fh", value4 => $an->data->{target}{$ssh_fh_key}{ssh_fh},
	}, file => $THIS_FILE, line => __LINE__});
	
	my $nics_seen = 0;
	if ($return_code)
	{
		if ($remap)
		{
			print $an->String->get({key => "message_0378"});
		}
	}
	elsif ($an->data->{target}{$ssh_fh_key}{ssh_fh} !~ /^Net::SSH2/)
	{
		# Invalid or broken SSH handle.
		$an->Log->entry({log_level => 1, message_key => "log_0186", message_variables => {
			node   => $node, 
			ssh_fh => $an->data->{target}{$ssh_fh_key}{ssh_fh}, 
		}, file => $THIS_FILE, line => __LINE__});
		$return_code = 8;
	}
	else
	{
		### WARNING: Don't use 'remote_call()'! We need input from the user, so we need to call the 
		###          target directly
		my $ssh_fh = $an->data->{target}{$ssh_fh_key}{ssh_fh};
		my $close  = 0;
		
		### Build the shell call
		# Figure out the hash keys to use
		my $i;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node",                    value1 => $node,
			name2 => "sys::anvil::node1::name", value2 => $an->data->{sys}{anvil}{node1}{name},
			name3 => "sys::anvil::node2::name", value3 => $an->data->{sys}{anvil}{node2}{name},
		}, file => $THIS_FILE, line => __LINE__});
		if ($node eq $an->data->{sys}{anvil}{node1}{name})
		{
			# Node is 1
			$i = 1;
		}
		elsif ($node eq $an->data->{sys}{anvil}{node2}{name})
		{
			# Node is 2
			$i = 2;
		}
		else
		{
			# wat?
			$return_code = 7;
			$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0159", code => 159, file => $THIS_FILE, line => __LINE__});
			return("");
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "channel",              value1 => $channel,
			name2 => "cgi::update_manifest", value2 => $an->data->{cgi}{update_manifest},
			name3 => "shell_call",           value3 => $shell_call,
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
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "nics_seen",                               value1 => $nics_seen,
						name2 => "conf::node::${node}::current_nics::$nic", value2 => $an->data->{conf}{node}{$node}{current_nic}{$nic},
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					print $an->InstallManifest->parse_script_line({
						source => "STDOUT", 
						node   => $node, 
						line   => $line,
					});
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
				print $an->InstallManifest->parse_script_line({
					source => "STDERR", 
					node   => $node, 
					line   => $line,
				});
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
			name1 => "conf::node::${node}::set_nic::bcn_link1", value1 => $an->data->{conf}{node}{$node}{set_nic}{bcn_link1},
			name2 => "conf::node::${node}::set_nic::bcn_link2", value2 => $an->data->{conf}{node}{$node}{set_nic}{bcn_link2},
			name3 => "conf::node::${node}::set_nic::sn_link1",  value3 => $an->data->{conf}{node}{$node}{set_nic}{sn_link1},
			name4 => "conf::node::${node}::set_nic::sn_link2",  value4 => $an->data->{conf}{node}{$node}{set_nic}{sn_link2},
			name5 => "conf::node::${node}::set_nic::ifn_link1", value5 => $an->data->{conf}{node}{$node}{set_nic}{ifn_link1},
			name6 => "conf::node::${node}::set_nic::ifn_link2", value6 => $an->data->{conf}{node}{$node}{set_nic}{ifn_link2},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This parses a line coming back from one of our shell scripts to convert string keys and possible variables
# into the current user's language.
sub parse_script_line
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "parse_script_line" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $source = $parameter->{source} ? $parameter->{source} : "";
	my $node   = $parameter->{node}   ? $parameter->{node}   : "";
	my $line   = $parameter->{line}   ? $parameter->{line}   : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "source", value1 => $source, 
		name2 => "node",   value2 => $node, 
		name3 => "line",   value3 => $line, 
	}, file => $THIS_FILE, line => __LINE__});

	return($line) if $line eq "";
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
		$line = "
<!-- start AN::Tools::InstallManifest->parse_script_line() output -->
".$an->String->get({key => $key, variables => $vars})."
<!--end AN::Tools::InstallManifest->parse_script_line() output -->
";
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "line", value1 => $line,
	}, file => $THIS_FILE, line => __LINE__});
	
	return($line);
}

# This adds each node's RSA public key to the node's ~/.ssh/authorized_keys file if needed.
sub populate_authorized_keys_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "populate_authorized_keys_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1_rsa = $parameter->{node1_rsa} ? $parameter->{node1_rsa} : "";
	my $node2_rsa = $parameter->{node2_rsa} ? $parameter->{node2_rsa} : "";
	my $node      = $parameter->{node}      ? $parameter->{node}      : "";
	my $target    = $parameter->{target}    ? $parameter->{target}    : "";
	my $port      = $parameter->{port}      ? $parameter->{port}      : "";
	my $password  = $parameter->{password}  ? $parameter->{password}  : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "node1_rsa", value1 => $node1_rsa, 
		name2 => "node2_rsa", value2 => $node2_rsa, 
		name3 => "node",      value3 => $node, 
		name4 => "target",    value4 => $target, 
		name5 => "port",      value5 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If a node is being rebuilt, its old keys will no longer be valid. To deal with this, we simply 
	# remove existing keys and re-add them.
	my $ok = 1;
	foreach my $name (@{$an->data->{sys}{node_names}})
	{
		my $shell_call = "
if [ -e '/root/.ssh/authorized_keys' ]
then
    if \$(".$an->data->{path}{'grep'}." -q $name ~/.ssh/authorized_keys);
    then 
        ".$an->data->{path}{echo}." 'RSA key exists, removing it.'
        ".$an->data->{path}{sed}." -i '/ root\@$name$/d' /root/.ssh/authorized_keys
    fi;
else
    ".$an->data->{path}{echo}." 'no file'
fi";
	}
	
	### Now add the keys.
	# Node 1
	if (1)
	{
		my $shell_call = $an->data->{path}{echo}." \"$node1_rsa\" >> /root/.ssh/authorized_keys";
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
		
		# Verify it was added.
		$shell_call = "
if \$(".$an->data->{path}{'grep'}." -q \"$node1_rsa\" /root/.ssh/authorized_keys)
then
    ".$an->data->{path}{echo}." added
else
    ".$an->data->{path}{echo}." failed
fi";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
			
			if ($line =~ /added/)
			{
				# Success
				$an->Log->entry({log_level => 2, message_key => "log_0104", message_variables => {
					key_owner => "1", 
					node      => $node, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /failed/)
			{
				# Failed to add.
				$ok = 0;
				$an->Log->entry({log_level => 1, message_key => "log_0105", message_variables => {
					key_owner => "1", 
					node      => $node, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Node 2.
	if (1)
	{
		my $shell_call = $an->data->{path}{echo}." \"$node2_rsa\" >> /root/.ssh/authorized_keys";
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
		
		# Verify it was added.
		$shell_call = "
if \$(".$an->data->{path}{'grep'}." -q \"$node2_rsa\" /root/.ssh/authorized_keys)
then
    ".$an->data->{path}{echo}." added
else
    ".$an->data->{path}{echo}." failed
fi";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target",     value1 => $target,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
			
			if ($line =~ /added/)
			{
				# Success
				$an->Log->entry({log_level => 2, message_key => "log_0104", message_variables => {
					key_owner => "2", 
					node      => $node, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /failed/)
			{
				# Failed to add.
				$ok = 0;
				$an->Log->entry({log_level => 1, message_key => "log_0105", message_variables => {
					key_owner => "2", 
					node      => $node, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return($ok);
}

# This adds any missing ssh fingerprints to a node
sub populate_known_hosts_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "populate_known_hosts_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $ok = 1;
	foreach my $name (@{$an->data->{sys}{node_names}})
	{
		### TODO: How safe/stupid is this?
		# If a node is being replaced, the old entries will no longer match. So as a precaution, 
		# existing keys are removed if found.
		next if not $name;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "name", value1 => $name,
		}, file => $THIS_FILE, line => __LINE__});
		my $try_again  = 0;
		my $shell_call = "
if \$(".$an->data->{path}{'grep'}." -q $name ~/.ssh/known_hosts);
then 
    ".$an->data->{path}{echo}." 'fingerprint exists, removing it.'
    ".$an->data->{path}{sed}." -i '/^$name /d' /root/.ssh/known_hosts
fi
".$an->data->{path}{'ssh-keyscan'}." $name >> ~/.ssh/known_hosts;
if \$(".$an->data->{path}{'grep'}." -q $name ~/.ssh/known_hosts);
then 
    ".$an->data->{path}{echo}." 'fingerprint added';
else
    ".$an->data->{path}{echo}." 'failed to record fingerprint for $node.';
fi;";
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
			
			if ($line =~ /fingerprint recorded/)
			{
				# Already recorded
				$an->Log->entry({log_level => 3, message_key => "log_0106", message_variables => {
					node => $node, 
					name => $name, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /fingerprint added/)
			{
				# Added
				$an->Log->entry({log_level => 2, message_key => "log_0107", message_variables => {
					node => $node, 
					name => $name, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /failed to record/)
			{
				# Failed
				$an->Log->entry({log_level => 1, message_key => "log_0108", message_variables => {
					node => $node, 
					name => $name, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# One time, it failed for no apparent reasons and worked later. so if this 
				# failed, sleep a few seconds and try a second time.
				$try_again = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "try_again", value1 => $try_again,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "try_again", value1 => $try_again,
		}, file => $THIS_FILE, line => __LINE__});
		if ($try_again)
		{
			sleep 5;
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
				
				if ($line =~ /fingerprint recorded/)
				{
					# Already recorded
					$an->Log->entry({log_level => 3, message_key => "log_0106", message_variables => {
						node => $node, 
						name => $name, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($line =~ /fingerprint added/)
				{
					# Added
					$an->Log->entry({log_level => 2, message_key => "log_0107", message_variables => {
						node => $node, 
						name => $name, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($line =~ /failed to record/)
				{
					# Failed
					$an->Log->entry({log_level => 1, message_key => "log_0108", message_variables => {
						node => $node, 
						name => $name, 
					}, file => $THIS_FILE, line => __LINE__});
					
					# OK, now we give up
					$ok = 0;
				}
			}
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This reads in /etc/cluster/cluster.conf and returns '0' if not found.
sub read_cluster_conf
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "read_cluster_conf" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $node)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0160", code => 160, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	# Later, this will use XML::Simple to parse the contents. For now, I only care if the file exists at 
	# all.
	$an->data->{node}{$node}{cluster_conf_version} = 0;
	$an->data->{node}{$node}{cluster_conf}         = "";
	my $shell_call = "
if [ -e '".$an->data->{path}{nodes}{cluster_conf}."' ]
then
    ".$an->data->{path}{cat}." ".$an->data->{path}{nodes}{cluster_conf}."
else
    ".$an->data->{path}{echo}." not found
fi";
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
		
		last if $line eq "not found";
		$an->data->{node}{$node}{cluster_conf} .= "$line\n";
		
		# If the version is > 1, we'll use it no matter what.
		if ($line =~ /config_version="(\d+)"/)
		{
			$an->data->{node}{$node}{cluster_conf_version} = $1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node}::cluster_conf_version", value1 => $an->data->{node}{$node}{cluster_conf_version},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node::${node}::cluster_conf_version", value1 => $an->data->{node}{$node}{cluster_conf_version},
	}, file => $THIS_FILE, line => __LINE__});
	return($an->data->{node}{$node}{cluster_conf_version})
}

# Unlike 'read_drbd_resource_files()' which only reads the 'rX.res' files and parses their contents, this 
# function just slurps in the data from the resource and global common configs.
sub read_drbd_config_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "read_drbd_config_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# DRBD ships with 'global_common.conf', so we need to tell if the one we read was stock or not. If it
	# was stock, delete it from the variable so that our generated one gets used.
	my $generic_global_common = 1;
	
	# These will contain the contents of the file.
	$an->data->{node}{$node}{drbd_file}{global_common} = "";
	$an->data->{node}{$node}{drbd_file}{r0}            = "";
	$an->data->{node}{$node}{drbd_file}{r1}            = "";
	
	# And these tell us which file we're looking at.
	my $in_global = 0;
	my $in_r0     = 0;
	my $in_r1     = 0;
	
	# Some variables to use in the bash call...
	my $global_common = $an->data->{path}{nodes}{drbd_global_common};
	my $r0            = $an->data->{path}{nodes}{drbd_r0};
	my $r1            = $an->data->{path}{nodes}{drbd_r1};
	my $shell_call = "
if [ -e '$global_common' ]; 
then 
    ".$an->data->{path}{echo}." start:$global_common; 
    ".$an->data->{path}{cat}." $global_common; 
    ".$an->data->{path}{echo}." end:$global_common; 
else 
    ".$an->data->{path}{echo}." not_found:$global_common; 
fi;
if [ -e '$r0' ]; 
then 
    ".$an->data->{path}{echo}." start:$r0; 
    ".$an->data->{path}{cat}." $r0; 
    ".$an->data->{path}{echo}." end:$r0; 
else 
    ".$an->data->{path}{echo}." not_found:$r0; 
fi;
if [ -e '$r1' ]; 
then 
    ".$an->data->{path}{echo}." start:$r1; 
    ".$an->data->{path}{cat}." $r1; 
    ".$an->data->{path}{echo}." end:$r1; 
else 
    ".$an->data->{path}{echo}." not_found:$r1; 
fi;";
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		# Detect the start and end of files.
		if ($line eq "start:$global_common") { $in_global = 1; next; }
		if ($line eq "end:$global_common")   { $in_global = 0; next; }
		if ($line eq "start:$r0")            { $in_r0     = 1; next; }
		if ($line eq "end:$r0")              { $in_r0     = 0; next; }
		if ($line eq "start:$r1")            { $in_r1     = 1; next; }
		if ($line eq "end:$r1")              { $in_r1     = 0; next; }
		
		### TODO: Make sure the storage pool devices are updated if we use a read-in resource file.
		# Record lines if we're in a file.
		if ($in_global)
		{
			$an->data->{node}{$node}{drbd_file}{global_common} .= "$line\n";
			my $test_line = $line;
			   $test_line =~ s/^\s+//;
			   $test_line =~ s/\s+$//;
			   $test_line =~ s/\s+/ /g;
			if (($test_line =~ /^fence-peer/) or ($test_line =~ /^allow-two-primaries/))
			{
				# These are not set by default, so we're _not_ looking at a stock config.
				$generic_global_common = 0;
			}
		}
		if ($in_r0) { $an->data->{node}{$node}{drbd_file}{r0} .= "$line\n"; }
		if ($in_r1) { $an->data->{node}{$node}{drbd_file}{r1} .= "$line\n"; }
	}
	
	# Wipe out the global_common if it is generic.
	$an->data->{node}{$node}{drbd_file}{global_common} = "" if $generic_global_common;
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "node::${node}::drbd_file::global_common", value1 => $an->data->{node}{$node}{drbd_file}{global_common}, 
		name2 => "node::${node}::drbd_file::r0",            value2 => $an->data->{node}{$node}{drbd_file}{r0}, 
		name3 => "node::${node}::drbd_file::r1",            value3 => $an->data->{node}{$node}{drbd_file}{r1},
	}, file => $THIS_FILE, line => __LINE__});
	
	return(0);
}

# This looks for the two DRBD resource files and, if found, pulls the partitions to use out of them.
sub read_drbd_resource_files
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "read_drbd_resource_files" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $hostname = $parameter->{hostname} ? $parameter->{hostname} : "";
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "hostname", value1 => $hostname, 
		name2 => "node",     value2 => $node, 
		name3 => "target",   value3 => $target, 
		name4 => "port",     value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $r0_device = "";
	my $r1_device = "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "path::nodes::drbd_r0", value1 => $an->data->{path}{nodes}{drbd_r0}, 
		name2 => "path::nodes::drbd_r1", value2 => $an->data->{path}{nodes}{drbd_r1}, 
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $file ($an->data->{path}{nodes}{drbd_r0}, $an->data->{path}{nodes}{drbd_r1})
	{
		### TODO: This used to skip all files in pool1 and node pool2 size, but I think this was a 
		###       mistake and I only meant to skip r1.res.
		# Skip if no pool1
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "path::nodes::drbd_r1",               value1 => $an->data->{path}{nodes}{drbd_r1}, 
			name2 => "cgi::anvil_storage_pool2_byte_size", value2 => $an->data->{cgi}{anvil_storage_pool2_byte_size}, 
		}, file => $THIS_FILE, line => __LINE__});
		if (($file eq $an->data->{path}{nodes}{drbd_r1}) && (not $an->data->{cgi}{anvil_storage_pool2_byte_size}))
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

# Reboots the nodes and updates the IPs we're using to connect to them if needed.
sub reboot_nodes
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "reboot_nodes" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# If neither node needs a reboot, don't print the lengthy message.
	my $node1 = $an->data->{sys}{anvil}{node1}{name};
	my $node2 = $an->data->{sys}{anvil}{node2}{name};
	if ((($an->data->{node}{$node1}{reboot_needed}) && (not $an->data->{node}{node1}{has_servers})) or 
	    (($an->data->{node}{$node2}{reboot_needed}) && (not $an->data->{node}{node2}{has_servers})))
	{
		# This could take a while
		my $message = $an->String->get({key => "explain_0141", variables => { url => "?task=manifests&do=new&run=".$an->data->{cgi}{run} }});
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-be-patient-message", replace => { message => $message }});
	}
	
	# We do this sequentially, so that if one fails, the other should still be up and hopefully provide a
	# route into the lost one for debugging.
	my $ok                = 1;
	my $node1_return_code = 1;
	my $node2_return_code = 255;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_node1_bcn_ip", value1 => $an->data->{cgi}{anvil_node1_bcn_ip},
	}, file => $THIS_FILE, line => __LINE__});
	($node1_return_code) = $an->InstallManifest->do_node_reboot({
			node       => $node1, 
			target     => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port       => $an->data->{sys}{anvil}{node1}{use_port}, 
			password   => $an->data->{sys}{anvil}{node1}{password},
			new_bcn_ip => $an->data->{cgi}{anvil_node1_bcn_ip},
		}) if not $an->data->{node}{node1}{has_servers};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node1_return_code", value1 => $node1_return_code,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Update 'cgi::anvil_node1_current_ip' if the reboot was good.
	if ($node1_return_code eq "0")
	{
		$an->data->{cgi}{anvil_node1_current_ip} = $an->data->{cgi}{anvil_node1_bcn_ip};
		$an->data->{sys}{anvil}{node1}{use_ip}   = $an->data->{cgi}{anvil_node1_bcn_ip};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "cgi::anvil_node1_current_ip", value1 => $an->data->{cgi}{anvil_node1_current_ip},
			name2 => "sys::anvil::node1::use_ip",   value2 => $an->data->{sys}{anvil}{node1}{use_ip},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Now reboot node 2, if appropriate and node 1 didn't fail to come up.
	if ((not $node1_return_code) or ($node1_return_code eq "1") or ($node1_return_code eq "5"))
	{
		$node2_return_code = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_node2_bcn_ip", value1 => $an->data->{cgi}{anvil_node2_bcn_ip},
		}, file => $THIS_FILE, line => __LINE__});
		($node2_return_code) = $an->InstallManifest->do_node_reboot({
				node       => $node2, 
				target     => $an->data->{sys}{anvil}{node2}{use_ip}, 
				port       => $an->data->{sys}{anvil}{node2}{use_port}, 
				password   => $an->data->{sys}{anvil}{node2}{password},
				new_bcn_ip => $an->data->{cgi}{anvil_node2_bcn_ip},
			}) if not $an->data->{node}{node2}{has_servers};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node1_return_code", value1 => $node1_return_code,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Update 'cgi::anvil_node2_current_ip' if the reboot was good.
		if ($node2_return_code eq "0")
		{
			$an->data->{cgi}{anvil_node2_current_ip} = $an->data->{cgi}{anvil_node2_bcn_ip};
			$an->data->{sys}{anvil}{node2}{use_ip}   = $an->data->{cgi}{anvil_node2_bcn_ip};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "cgi::anvil_node2_current_ip", value1 => $an->data->{cgi}{anvil_node2_current_ip},
				name2 => "sys::anvil::node2::use_ip",   value2 => $an->data->{sys}{anvil}{node2}{use_ip},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Return codes:
	# 0 = Node was rebooted successfully.
	# 1 = Reboot wasn't needed
	# 2 = Reboot failed, but node is pingable.
	# 3 = Reboot failed, node is not pingable.
	# 4 = Reboot failed, server didn't shut down before timeout.
	# 5 = Reboot needed, but manual reboot required.
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0046!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0046!#";
	# Node 1
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif (not $node1_return_code)
	{
		# Node rebooted, change the IP we're using for it now.
		$an->data->{sys}{anvil}{node1}{use_ip} = $an->data->{cgi}{anvil_node1_bcn_ip};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::anvil::node1::use_ip", value1 => $an->data->{sys}{anvil}{node1}{use_ip},
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($node1_return_code eq "1")
	{
		$node1_message = "#!string!state_0047!#",
	}
	elsif ($node1_return_code == 2)
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0048!#",
		$ok            = 0;
	}
	elsif ($node1_return_code == 3)
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0049!#",
		$ok            = 0;
	}
	elsif ($node1_return_code == 4)
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0051!#",
		$ok            = 0;
	}
	elsif ($node1_return_code == 5)
	{
		# Manual reboot needed, exit.
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0097!#",
		$ok            = 0;
	}
	
	# Node 2
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif ($node2_return_code == 255)
	{
		# Aborted.
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0050!#",
		$ok            = 0;
	}
	elsif (not $node2_return_code)
	{
		# Node rebooted, change the IP we're using for it now.
		$an->data->{sys}{anvil}{node2}{use_ip} = $an->data->{cgi}{anvil_node2_bcn_ip};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::anvil::node2::use_ip", value1 => $an->data->{sys}{anvil}{node2}{use_ip},
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($node2_return_code eq "1")
	{
		$node2_message = "#!string!state_0047!#",
	}
	elsif ($node2_return_code == 2)
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0048!#",
		$ok            = 0;
	}
	elsif ($node2_return_code == 3)
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0049!#",
		$ok            = 0;
	}
	elsif ($node2_return_code == 4)
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0051!#",
		$ok            = 0;
	}
	elsif ($node1_return_code == 5)
	{
		# Manual reboot needed, exit.
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0097!#",
		$ok            = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0247!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	return($ok);
}

# This reads in the actual lvm.conf from the node, updating the config in the process, storing a version 
# suitable for clustered LVM.
sub read_lvm_conf_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "read_lvm_conf_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# I need to read this in two passes. The first pass looks for an existing 'filter = []' rule and, if 
	# found, uses it.
	$an->data->{node}{$node}{lvm_filter} = $an->data->{sys}{lvm_filter};
	
	# Read it in
	my $shell_call = "
if [ -e '".$an->data->{path}{nodes}{lvm_conf}."' ]
then
    ".$an->data->{path}{cat}." ".$an->data->{path}{nodes}{lvm_conf}."
else
    ".$an->data->{path}{echo}." \"not found\"
fi";
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if (($line =~ /^filter = \[.*\]/) or ($line =~ /^\s+filter = \[.*\]/))
		{
			$an->data->{node}{$node}{lvm_filter} =  $line;
			$an->data->{node}{$node}{lvm_filter} =~ s/^\s+//;
			$an->data->{node}{$node}{lvm_filter} =~ s/\s+$//;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node}::lvm_filter", value1 => $an->data->{node}{$node}{lvm_filter},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	### TODO: Make this smart enough to *NOT* change the lvm.conf file unless something actually needs to
	###       be changed and, if so, use sed to maintain the file's comments.
	# There is no default filter entry, but it is referenced as comments many times. So we'll inject it 
	# when we see the first comment and then skip any 
	my $filter_injected = 0;
	$an->data->{node}{$node}{lvm_conf} =  "# Generated by: [$THIS_FILE] on: [".$an->Get->date_and_time({split_date_time => 0})."].\n\n";
	$an->data->{node}{$node}{lvm_conf} .= "# Sorry for the lack of comments... Ran into a buffer issue with Net::SSH2 that\n";
	$an->data->{node}{$node}{lvm_conf} .= "# I wasn't able to fix in time. Fixing it is on the TODO though, and patches\n";
	$an->data->{node}{$node}{lvm_conf} .= "# are welcomed. :)\n\n";
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		last if $line =~ /not found/;
		
		# Any line that starts with a '#' is passed on as-is.
		if ((not $filter_injected) && ($line =~ /filter = \[/))
		{
			#$an->data->{node}{$node}{lvm_conf} .= "$line\n";
			$an->data->{node}{$node}{lvm_conf} .= "    ".$an->data->{node}{$node}{lvm_filter}."\n";
			$filter_injected               =  1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "Filter injected", value1 => $an->data->{node}{$node}{lvm_filter},
			}, file => $THIS_FILE, line => __LINE__});
			next;
		}
		elsif (($line =~ /^filter = \[/) or ($line =~ /^\s+filter = \[/))
		{
			# Skip existing filter entries
		}
		# Test skip comments
		elsif ((not $line) or (($line =~ /^#/) or ($line =~ /^\s+#/)) or ($line =~ /^\s+$/))
		{
			### TODO: Fix Net::SSH2 so that we can write out larger files.
			# Skip comments
			next;
		}
		# Alter the locking type:
		if (($line =~ /^locking_type = /) or ($line =~ /^\s+locking_type = /))
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => ">> line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			$line =~ s/locking_type = .*/locking_type = 3/;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "<< line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
		}
		# Alter the fall-back locking
		if (($line =~ /^fallback_to_local_locking = /) or ($line =~ /^\s+fallback_to_local_locking = /))
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => ">> line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
			$line =~ s/fallback_to_local_locking = .*/fallback_to_local_locking = 0/;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "<< line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
		}
		# And record.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		$an->data->{node}{$node}{lvm_conf} .= "$line\n";
		if ($line eq "}")
		{
			# Add an extra blank line to make things more readible.
			$an->data->{node}{$node}{lvm_conf} .= "\n";
		}
	}
	
	return(0);
}

# This will register the nodes with RHN, if needed. Otherwise it just returns without doing anything.
sub register_with_rhn
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "register_with_rhn" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	if (not $an->data->{sys}{install_manifest}{show}{rhn_checks})
	{
		# User has skipped RHN check
		$an->Log->entry({log_level => 2, message_key => "log_0179", file => $THIS_FILE, line => __LINE__});
		return(0);
	}
	
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::rhn_user",     value1 => $an->data->{cgi}{rhn_user},
		name2 => "cgi::rhn_password", value2 => $an->data->{cgi}{rhn_password},
	}, file => $THIS_FILE, line => __LINE__});
	
	my $node1 = $an->data->{sys}{anvil}{node1}{name};
	my $node2 = $an->data->{sys}{anvil}{node2}{name};
	
	# If I am going to register, I should warn the user of the delay.
	if ((($an->data->{node}{$node1}{os}{brand} =~ /Red Hat Enterprise Linux Server/) && (not $an->data->{node}{$node1}{os}{registered}) && ($an->data->{node}{$node1}{internet})) or
	    (($an->data->{node}{$node2}{os}{brand} =~ /Red Hat Enterprise Linux Server/) && (not $an->data->{node}{$node2}{os}{registered}) && ($an->data->{node}{$node2}{internet})))
	{
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-be-patient-message", replace => { 
			message	=>	"#!string!explain_0138!#",
		}});
	}
	
	# If it is not RHEL, no sense going further.
	if (($an->data->{node}{$node1}{os}{brand} !~ /Red Hat Enterprise Linux Server/) && ($an->data->{node}{$node2}{os}{brand} !~ /Red Hat Enterprise Linux Server/))
	{
		return(1);
	}
	
	# No credentials? No sense going further...
	if ((not $an->data->{cgi}{rhn_user}) or (not $an->data->{cgi}{rhn_password}))
	{
		# No sense going further
		if ((not $an->data->{node}{$node1}{os}{registered}) or (not $an->data->{node}{$node2}{os}{registered}))
		{
			print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
				row	=>	"#!string!row_0242!#",
				message	=>	"#!string!message_0385!#",
			}});
			return(0);
		}
		return(1);
	}
	
	my $node1_ok = 1;
	my $node2_ok = 1;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node1}::os::brand", value1 => $an->data->{node}{$node1}{os}{brand},
		name2 => "node::${node2}::os::brand", value2 => $an->data->{node}{$node2}{os}{brand},
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{node}{$node1}{os}{brand} =~ /Red Hat Enterprise Linux Server/)
	{
		# See if it has been registered already.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node1}::os::registered", value1 => $an->data->{node}{$node1}{os}{registered},
			name2 => "node::${node1}::internet",       value2 => $an->data->{node}{$node1}{internet},
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $an->data->{node}{$node1}{os}{registered}) && ($an->data->{node}{$node1}{internet}))
		{
			# We're good.
			($node1_ok) = $an->InstallManifest->register_node_with_rhn({
					node     => $node1, 
					target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
					port     => $an->data->{sys}{anvil}{node1}{use_port}, 
					password => $an->data->{sys}{anvil}{node1}{password},
					name     => $an->data->{sys}{anvil}{node1}{name},
				}) if not $an->data->{node}{node1}{has_servers};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node1_ok", value1 => $node1_ok,
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			$node1_ok = "skip";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node1_ok", value1 => $node1_ok,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	else
	{
		$node1_ok = "skip";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node1_ok", value1 => $node1_ok,
		}, file => $THIS_FILE, line => __LINE__});
	}
	if ($an->data->{node}{$node2}{os}{brand} =~ /Red Hat Enterprise Linux Server/)
	{
		# See if it has been registered already.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node2}::os::registered", value1 => $an->data->{node}{$node2}{os}{registered},
			name2 => "node::${node2}::internet",       value2 => $an->data->{node}{$node2}{internet},
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $an->data->{node}{$node2}{os}{registered}) && ($an->data->{node}{$node2}{internet}))
		{
			# We're good.
			($node2_ok) = $an->InstallManifest->register_node_with_rhn({
					node     => $node2, 
					target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
					port     => $an->data->{sys}{anvil}{node2}{use_port}, 
					password => $an->data->{sys}{anvil}{node2}{password},
					name     => $an->data->{sys}{anvil}{node2}{name},
				}) if not $an->data->{node}{node2}{has_servers};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node2_ok", value1 => $node2_ok,
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			$node2_ok = "skip";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node2_ok", value1 => $node2_ok,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	else
	{
		$node2_ok = "skip";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node2_ok", value1 => $node2_ok,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Return if registration not needed.
	if (($node1 eq "skip") && ($node2 eq "skip"))
	{
		return(1);
	}
	
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0033!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0033!#";
	my $message       = "";
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif (not $node1_ok)
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0034!#";
		$ok            = 0;
	}
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif (not $node2_ok)
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0034!#";
		$ok            = 0;
	}

	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0234!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	if (not $ok)
	{
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
			message	=>	"#!string!message_0384!#",
			row	=>	"#!string!state_0021!#",
		}});
	}
	
	return($ok);
}

# This does the actual registration
sub register_node_with_rhn
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "register_node_with_rhn" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $name     = $parameter->{name}     ? $parameter->{name}     : "";
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "name",   value1 => $name, 
		name2 => "node",   value2 => $node, 
		name3 => "target", value3 => $target, 
		name4 => "port",   value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# First, make sure the script is downloaded and ready to run.
	my $base              =  0;
	my $resilient_storage =  0;
	my $optional          =  0;
	my $return_code       =  0;
	my $shell_call        =  "
".$an->data->{path}{'subscription-manager'}." register --username \"".$an->data->{cgi}{rhn_user}."\" --password \"".$an->data->{cgi}{rhn_password}."\" --name=$name --auto-attach && 
".$an->data->{path}{'subscription-manager'}." repos --enable=rhel-6-server-optional-rpms && 
".$an->data->{path}{'subscription-manager'}." repos --enable=rhel-rs-for-rhel-6-server-rpms && 
".$an->data->{path}{'subscription-manager'}." repos --list-enabled";
	# Exposes the RHN password, so log level 4.
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
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
		
		if ($line =~ /rhel-6-server-rpms/)
		{
			$base = 1;
		}
		if ($line =~ /rhel-6-server-optional-rpms/)
		{
			$resilient_storage = 1;
		}
		if ($line =~ /rhel-rs-for-rhel-6-server-rpms/)
		{
			$optional = 1;
		}
	}
	if ((not $base) or (not $resilient_storage) or ($optional))
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "node",              value1 => $node,
			name2 => "base",              value2 => $base,
			name3 => "resilient_storage", value3 => $resilient_storage,
			name4 => "optional",          value4 => $optional,
		}, file => $THIS_FILE, line => __LINE__});
		$return_code = 1;
	}
	
	return($return_code);
}

# This sed's out the 'priority=' from the striker repos.
sub remove_priority_from_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "remove_priority_from_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Remove the 'priority=' line from our repos so that the update hits the web.
	my $shell_call = "
for repo in \$(".$an->data->{path}{ls}." ".$an->data->{path}{yum_repos}."/);
do 
    ".$an->data->{path}{sed}." -i '/priority=/d' ".$an->data->{path}{yum_repos}."/\${repo};
done
";
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
	
	return(0);
}

# This will call disable -> enable on a given service to try and recover if from a 'failed' state.
sub restart_rgmanager_service
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "restart_rgmanager_service" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $service  = $parameter->{service}  ? $parameter->{service}  : "";
	my $do       = $parameter->{'do'}     ? $parameter->{'do'}     : "";
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "service", value1 => $service, 
		name2 => "do",      value2 => $do, 
		name3 => "node",    value3 => $node, 
		name4 => "target",  value4 => $target, 
		name5 => "port",    value5 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### NOTE: See - https://bugzilla.redhat.com/show_bug.cgi?id=1349755
	###       This can hang. For normal users, the only sane option is to reboot both nodes. So we might
	###       want to add a 'timeout' call that exists and warns the user to reboot both nodes and try 
	###       again. At least until we get the underlying problem solved.
	# This is something of a 'hail mary' pass, so not much sanity checking is done (yet).
	my $shell_call = $an->data->{path}{clusvcadm}." -d $service; ".$an->data->{path}{'sleep'}." 10; ".$an->data->{path}{clusvcadm}." -F -e $service";
	if ($do eq "start")
	{
		$shell_call = $an->data->{path}{clusvcadm}." -F -e $service";
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
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return(0);
}

# This runs the install manifest against both nodes.
sub run_new_install_manifest
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "run_new_install_manifest" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $manifest_uuid = $an->data->{cgi}{manifest_uuid};
	my $anvil_uuid    = $an->data->{cgi}{anvil_uuid};
	my $anvil_name    = $an->data->{cgi}{anvil_name};
	my $node1_name    = $an->data->{cgi}{anvil_node1_name};
	my $node2_name    = $an->data->{cgi}{anvil_node2_name};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "manifest_uuid", value1 => $manifest_uuid,
		name2 => "anvil_uuid",    value2 => $anvil_uuid,
		name3 => "anvil_name",    value3 => $anvil_name,
		name4 => "node1_name",    value4 => $node1_name,
		name5 => "node2_name",    value5 => $node2_name,
	}, file => $THIS_FILE, line => __LINE__});
	
	# We can't "load an Anvil!" in the traditional sense, so we fudge it here so that the remote_call() 
	# method calls work the same as usual. Some of these CGI values were actually set when the install
	# manifest was parsed.
	$an->data->{sys}{anvil}{name}                           =  $an->data->{cgi}{anvil_name};
	$an->data->{sys}{anvil}{password}                       =  $an->data->{cgi}{anvil_password};
	# Node 1
	$an->data->{sys}{anvil}{node1}{uuid}                    =  $an->data->{cgi}{anvil_node1_uuid};
	$an->data->{sys}{anvil}{node1}{name}                    =  $an->data->{cgi}{anvil_node1_name};
	$an->data->{sys}{anvil}{node1}{short_name}              =  $an->data->{sys}{anvil}{node1}{name};
	$an->data->{sys}{anvil}{node1}{short_name}              =~ s/\..*//;
	$an->data->{sys}{anvil}{node1}{bcn_ip}                  =  $an->data->{cgi}{anvil_node1_bcn_ip};
	$an->data->{sys}{anvil}{node1}{sn_ip}                   =  $an->data->{cgi}{anvil_node1_sn_ip};
	$an->data->{sys}{anvil}{node1}{ifn_ip}                  =  $an->data->{cgi}{anvil_node1_ifn_ip};
	$an->data->{sys}{anvil}{node1}{use_ip}                  =  $an->data->{cgi}{anvil_node1_current_ip};
	$an->data->{sys}{anvil}{node1}{use_port}                =  22;	# The port is not setable during install, so it must be 22.
	$an->data->{sys}{anvil}{node1}{password}                =  $an->data->{cgi}{anvil_node1_current_password};
	$an->data->{sys}{node_name}{$node1_name}{uuid}          =  $an->data->{sys}{anvil}{node1}{uuid};
	$an->data->{sys}{node_name}{$node1_name}{node_key}      =  "node1";
	$an->data->{sys}{node_name}{$node1_name}{peer_node_key} =  "node2";
	# Node 2
	$an->data->{sys}{anvil}{node2}{uuid}                    =  $an->data->{cgi}{anvil_node2_uuid};
	$an->data->{sys}{anvil}{node2}{name}                    =  $an->data->{cgi}{anvil_node2_name};
	$an->data->{sys}{anvil}{node2}{short_name}              =  $an->data->{sys}{anvil}{node2}{name};
	$an->data->{sys}{anvil}{node2}{short_name}              =~ s/\..*//;
	$an->data->{sys}{anvil}{node2}{bcn_ip}                  =  $an->data->{cgi}{anvil_node2_bcn_ip};
	$an->data->{sys}{anvil}{node2}{sn_ip}                   =  $an->data->{cgi}{anvil_node2_sn_ip};
	$an->data->{sys}{anvil}{node2}{ifn_ip}                  =  $an->data->{cgi}{anvil_node2_ifn_ip};
	$an->data->{sys}{anvil}{node2}{use_ip}                  =  $an->data->{cgi}{anvil_node2_current_ip};
	$an->data->{sys}{anvil}{node2}{use_port}                =  22;	# The port is not setable during install, so it must be 22.
	$an->data->{sys}{anvil}{node2}{password}                =  $an->data->{cgi}{anvil_node2_current_password};
	$an->data->{sys}{node_name}{$node2_name}{uuid}          =  $an->data->{sys}{anvil}{node2}{uuid};
	$an->data->{sys}{node_name}{$node2_name}{node_key}      =  "node2";
	$an->data->{sys}{node_name}{$node2_name}{peer_node_key} =  "node1";
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0023", message_variables => {
		name1  => "sys::anvil::name",                             value1  => $an->data->{sys}{anvil}{name},
		name2  => "sys::anvil::node1::uuid",                      value2  => $an->data->{sys}{anvil}{node1}{uuid},
		name3  => "sys::anvil::node1::name",                      value3  => $an->data->{sys}{anvil}{node1}{name},
		name4  => "sys::anvil::node1::short_name",                value4  => $an->data->{sys}{anvil}{node1}{short_name},
		name5  => "sys::anvil::node1::bcn_ip",                    value5  => $an->data->{sys}{anvil}{node1}{bcn_ip},
		name6  => "sys::anvil::node1::sn_ip",                     value6  => $an->data->{sys}{anvil}{node1}{sn_ip},
		name7  => "sys::anvil::node1::ifn_ip",                    value7  => $an->data->{sys}{anvil}{node1}{ifn_ip},
		name8  => "sys::anvil::node1::use_ip",                    value8  => $an->data->{sys}{anvil}{node1}{use_ip},
		name9  => "sys::anvil::node1::use_port",                  value9  => $an->data->{sys}{anvil}{node1}{use_port},
		name10 => "sys::anvil::node2::uuid",                      value10 => $an->data->{sys}{anvil}{node2}{uuid},
		name11 => "sys::anvil::node2::name",                      value11 => $an->data->{sys}{anvil}{node2}{name},
		name12 => "sys::anvil::node2::short_name",                value12 => $an->data->{sys}{anvil}{node2}{short_name},
		name13 => "sys::anvil::node2::bcn_ip",                    value13 => $an->data->{sys}{anvil}{node2}{bcn_ip},
		name14 => "sys::anvil::node2::sn_ip",                     value14 => $an->data->{sys}{anvil}{node2}{sn_ip},
		name15 => "sys::anvil::node2::ifn_ip",                    value15 => $an->data->{sys}{anvil}{node2}{ifn_ip},
		name16 => "sys::anvil::node2::use_ip",                    value16 => $an->data->{sys}{anvil}{node2}{use_ip},
		name17 => "sys::anvil::node2::use_port",                  value17 => $an->data->{sys}{anvil}{node2}{use_port},
		name18 => "sys::node_name::${node1_name}::uuid",          value18 => $an->data->{sys}{node_name}{$node1_name}{uuid},
		name19 => "sys::node_name::${node1_name}::node_key",      value19 => $an->data->{sys}{node_name}{$node1_name}{node_key},
		name20 => "sys::node_name::${node1_name}::peer_node_key", value20 => $an->data->{sys}{node_name}{$node1_name}{peer_node_key},
		name21 => "sys::node_name::${node2_name}::uuid",          value21 => $an->data->{sys}{node_name}{$node2_name}{uuid},
		name22 => "sys::node_name::${node2_name}::node_key",      value22 => $an->data->{sys}{node_name}{$node2_name}{node_key},
		name23 => "sys::node_name::${node2_name}::peer_node_key", value23 => $an->data->{sys}{node_name}{$node2_name}{peer_node_key},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0003", message_variables => {
		name1 => "sys::anvil::password",        value1 => $an->data->{sys}{anvil}{password},
		name2 => "sys::anvil::node1::password", value2 => $an->data->{sys}{anvil}{node1}{password},
		name3 => "sys::anvil::node2::password", value3 => $an->data->{sys}{anvil}{node2}{password},
	}, file => $THIS_FILE, line => __LINE__});
	
	my $message = $an->String->get({key => "message_0501", variables => { anvil => $anvil_name }});
	print $an->Web->template({file => "common.html", template => "scanning-message", replace => {
		anvil_message	=>	$message,
	}});
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-header"});
	
	# Some packages we'll need.
	$an->data->{packages}{to_install} = {
		acpid				=>	0,
		'alteeve-repo'			=>	0,
		'bash-completion'		=>	0,
		'bridge-utils'			=>	0,
		ccs				=>	0,
		'cim-schema'			=>	0,
		cman 				=>	0,
		'compat-libstdc++-33.i686'	=>	0,
		corosync			=>	0,
		'cyrus-sasl'			=>	0,
		'cyrus-sasl-plain'		=>	0,
		dmidecode			=>	0,
		dos2unix			=>	0,
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
		'perl-Net-Telnet'		=>	0,
		'perl-Mail-RFC822-Address'	=>	0,
		'perl-Sys-Virt'			=>	0,
		'perl-XML-SAX'			=>	0,
		'perl-XML-Simple'		=>	0,
		'policycoreutils-python'	=>	0,
		postgresql95			=>	0,
		postfix				=>	0,
		'python-virtinst'		=>	0,
		rgmanager			=>	0,
		ricci				=>	0,
		rsync				=>	0,
		screen				=>	0,
		sharutils			=>	0,
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
	my $node1             = $an->data->{sys}{anvil}{node1}{name};
	my $node2             = $an->data->{sys}{anvil}{node2}{name};
	my $node1_return_code = 0;
	my $node2_return_code = 0;
	if (($node1_remap_required) && (not $an->data->{node}{node1}{has_servers}))
	{
		($node1_return_code) = $an->InstallManifest->map_network_on_node({
				node     => $node1, 
				target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node1}{use_port}, 
				password => $an->data->{sys}{anvil}{node1}{password},
				remap    => 1, 
				say_node => "#!string!device_0005!#",
			});
	}
	if (($node2_remap_required) && (not $an->data->{node}{node2}{has_servers}))
	{
		($node2_return_code) = $an->InstallManifest->map_network_on_node({
				node     => $node2, 
				target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node2}{use_port}, 
				password => $an->data->{sys}{anvil}{node2}{password},
				remap    => 1, 
				say_node => "#!string!device_0006!#",
			});
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_return_code", value1 => $node1_return_code,
		name2 => "node2_return_code", value2 => $node2_return_code,
	}, file => $THIS_FILE, line => __LINE__});
	# 0 == OK
	# 1 == remap tool not found.
	# 4 == Too few NICs found.
	# 7 == Unknown node.
	# 8 == SSH file handle broken.
	# 9 == Failed to download (empty file)
	if (($node1_return_code) or ($node2_return_code))
	{
		# Something went wrong
		if (($node1_return_code eq "1") or ($node2_return_code eq "1"))
		{
			### Message already printed.
			# remap tool not found.
			#print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-failed-inline", replace => { message => "#!string!message_0378!#" }});
		}
		if (($node1_return_code eq "4") or ($node2_return_code eq "4"))
		{
			# Not enough NICs (or remap program failure)
			print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-failed-inline", replace => { message => "#!string!message_0380!#" }});
		}
		if (($node1_return_code eq "7") or ($node2_return_code eq "7"))
		{
			# Didn't recognize the node
			print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-failed-inline", replace => { message => "#!string!message_0383!#" }});
		}
		if (($node1_return_code eq "8") or ($node2_return_code eq "8"))
		{
			# SSH handle didn't exist, though it should have.
			print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-failed-inline", replace => { message => "#!string!message_0382!#" }});
		}
		if (($node1_return_code eq "9") or ($node2_return_code eq "9"))
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
		$an->InstallManifest->backup_files();
		
		# Register the nodes with RHN, if needed.
		$an->InstallManifest->register_with_rhn();
		
		# Configure the network
		$an->InstallManifest->configure_network() or return(1);
		
		# Configure the NTP on the servers, if set.
		$an->InstallManifest->configure_ntp() or return(1);
		
		# Install needed RPMs.
		$an->InstallManifest->install_programs() or return(1);
		
		# Update the OS on each node.
		$an->InstallManifest->update_nodes();
		
		# Configure daemons
		$an->InstallManifest->configure_daemons() or return(1);
		
		# Set the ricci password
		$an->InstallManifest->set_ricci_password() or return(1);
		
		# Write out the cluster configuration file
		$an->InstallManifest->configure_cman() or return(1);
		
		# Write out the clustered LVM configuration files
		$an->InstallManifest->configure_clvmd() or return(1);
		
		# This configures IPMI, if IPMI is set as a fence device.
		if ($an->data->{cgi}{anvil_fence_order} =~ /ipmi/)
		{
			$an->InstallManifest->configure_ipmi() or return(1);
		}
		
		# Configure storage stage 1 (partitioning).
		$an->InstallManifest->configure_storage_stage1() or return(1);
		
		# This handles configuring SELinux.
		$an->InstallManifest->configure_selinux() or return(1); 
		
		# Set the root user's passwords as the last step to ensure reloading the browser works for 
		# as long as possible.
		$an->InstallManifest->set_root_password() or return(1);
		
		# This sets up the various Striker tools and ScanCore. It must run before storage stage2 
		# because DRBD will need it.
		$an->InstallManifest->configure_scancore() or return(1);
		
		# If a reboot is needed, now is the time to do it. This will switch the CGI nodeX IPs to the 
		# new ones, too.
		$an->InstallManifest->reboot_nodes() or return(1);
		
		# Configure storage stage 2 (drbd)
		$an->InstallManifest->configure_storage_stage2() or return(1);
		
		# Start cman up
		$an->InstallManifest->start_cman() or return(1);
		
		# Live migration won't work until we've populated ~/.ssh/known_hosts, so do so now.
		$an->InstallManifest->configure_ssh() or return(1);
		
		# This manually starts DRBD, forcing one to primary if needed, configures clvmd, sets up the 
		# PVs and VGs, creates the /shared LV, creates the GFS2 partition and configures fstab.
		$an->InstallManifest->configure_storage_stage3() or return(1);
		
		# Enable (or disable) tools.
		$an->InstallManifest->enable_tools() or return(1);
		
		### If we're not dead, it is time to celebrate!
		# Is this Anvil! already in the database?
		my ($anvil_configured, $anvil_uuid) = $an->InstallManifest->check_config_for_anvil();
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "anvil_configured", value1 => $anvil_configured,
			name2 => "anvil_uuid",       value2 => $anvil_uuid,
		}, file => $THIS_FILE, line => __LINE__});
		
		# If the 'anvil_configured' is 1, run 'configure_ssh_local()'
		if ($anvil_configured)
		{
			# Setup ssh locally
			$an->Striker->configure_ssh_local({anvil_name => $an->data->{cgi}{anvil_name}});
			
			# Sync with the peer, if we can.
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "cgi::anvil_name", value1 => $an->data->{cgi}{anvil_name},
			}, file => $THIS_FILE, line => __LINE__});
			my $peers = $an->Striker->update_peers({anvil_name => $an->data->{cgi}{anvil_name}});
			
			# Log the peers that were updated.
			foreach my $peer (sort {$a cmp $b} @{$peers})
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "peer", value1 => $peer,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Do we need to show the link for adding the Anvil! to the config?
		my $message = $an->String->get({key => "message_0286", variables => { url => "/cgi-bin/striker?anvil_uuid=".$anvil_uuid }});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "message", value1 => $message,
		}, file => $THIS_FILE, line => __LINE__});
		if (not $anvil_configured)
		{
			# Nope
			my $say_node1_access = $an->data->{sys}{anvil}{node1}{use_ip};
			if (($an->data->{sys}{anvil}{node1}{use_port}) && ($an->data->{sys}{anvil}{node1}{use_port} ne "22"))
			{
				$say_node1_access .= ":".$an->data->{sys}{anvil}{node1}{use_port};
			}
			my $say_node2_access = $an->data->{sys}{anvil}{node2}{use_ip};
			if (($an->data->{sys}{anvil}{node2}{use_port}) && ($an->data->{sys}{anvil}{node2}{use_port} ne "22"))
			{
				$say_node2_access .= ":".$an->data->{sys}{anvil}{node2}{use_port};
			}
			
			# NOTE: Don't pass the password. It will be read in from the manifest.
			my $url =  "?task=anvil&";
			   $url .= "manifest_uuid=".$an->data->{cgi}{manifest_uuid}."&";
			   $url .= "anvil_uuid=new&";
			   $url .= "node1_access=$say_node1_access&";
			   $url .= "node2_access=$say_node2_access";
			
			# Now the string.
			$message = $an->String->get({key => "message_0402", variables => { url => $url }});
		}
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-success", replace => { message => $message }});
	}
	
	return(0);
}

# This sanity-checks the user's answers.
sub sanity_check_manifest_answers
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "sanity_check_manifest_answers" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Clear all variables.
	my $problem = 0;
	
	# Make sure the sequence number is valid.
	if (not $an->data->{cgi}{anvil_sequence})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_sequence_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0161!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif ($an->data->{cgi}{anvil_sequence} =~ /\D/)
	{
		$an->data->{form}{anvil_sequence_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0102", variables => { field => "#!string!row_0161!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Now check the domain
	if (not $an->data->{cgi}{anvil_domain})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_domain_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0160!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_domain}}))
	{
		$an->data->{form}{anvil_domain_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0103", variables => { field => "#!string!row_0160!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# The password can not be blank, that's all we check for though.
	if (not $an->data->{cgi}{anvil_password})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_password_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0194!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	### Start testing common stuff.
	# BCN network block and subnet mask
	if (not $an->data->{cgi}{anvil_bcn_network})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_bcn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0116", variables => { field => "#!string!row_0162!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_bcn_network}}))
	{
		$an->data->{form}{anvil_bcn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0118", variables => { field => "#!string!row_0162!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_bcn_subnet})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_bcn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0117", variables => { field => "#!string!row_0162!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_bcn_subnet}}))
	{
		$an->data->{form}{anvil_bcn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0119", variables => { field => "#!string!row_0162!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# SN network block and subnet mask
	if (not $an->data->{cgi}{anvil_sn_network})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_sn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0116", variables => { field => "#!string!row_0163!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_sn_network}}))
	{
		$an->data->{form}{anvil_sn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0118", variables => { field => "#!string!row_0163!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_sn_subnet})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_sn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0117", variables => { field => "#!string!row_0163!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_sn_subnet}}))
	{
		$an->data->{form}{anvil_sn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0119", variables => { field => "#!string!row_0163!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# IFN network block and subnet mask
	if (not $an->data->{cgi}{anvil_ifn_network})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_ifn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0116", variables => { field => "#!string!row_0164!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_ifn_network}}))
	{
		$an->data->{form}{anvil_ifn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0118", variables => { field => "#!string!row_0164!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_ifn_subnet})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_ifn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0117", variables => { field => "#!string!row_0164!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_ifn_subnet}}))
	{
		$an->data->{form}{anvil_ifn_network_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0119", variables => { field => "#!string!row_0164!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# MTU
	$an->data->{cgi}{anvil_mtu_size} =~ s/,//g;
	$an->data->{cgi}{anvil_mtu_size} =~ s/\s+//g;
	if (not $an->data->{cgi}{anvil_mtu_size})
	{
		$an->data->{cgi}{anvil_mtu_size} = $an->data->{sys}{install_manifest}{'default'}{mtu_size};
	}
	else
	{
		# Defined, sane?
		if ($an->data->{cgi}{anvil_mtu_size} =~ /\D/)
		{
			$an->data->{form}{anvil_mtu_size_star} = "#!string!symbol_0012!#";
			my $message = $an->String->get({key => "explain_0102", variables => { field => "#!string!row_0291!#" }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
		# Is the MTU too small or too big? - https://tools.ietf.org/html/rfc879
		elsif ($an->data->{cgi}{anvil_mtu_size} < 576)
		{
			$an->data->{form}{anvil_mtu_size_star} = "#!string!symbol_0012!#";
			my $message = $an->String->get({key => "explain_0157", variables => { field => "#!string!row_0291!#" }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
	}
	
	### TODO: Worth checking the select box values?
	# Check the /shared and node 1 storage sizes.
	if (not $an->data->{cgi}{anvil_media_library_size})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_media_library_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0191!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_integer_or_unsigned_float({number => $an->data->{cgi}{anvil_media_library_size}}))
	{
		$an->data->{form}{anvil_media_library_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0121", variables => { field => "#!string!row_0191!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Check the size of the node 1 storage pool.
	if (not $an->data->{cgi}{anvil_storage_pool1_size})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_storage_pool1_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0199!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_integer_or_unsigned_float({number => $an->data->{cgi}{anvil_storage_pool1_size}}))
	{
		$an->data->{form}{anvil_storage_pool1_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0121", variables => { field => "#!string!row_0199!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	} # Make sure the percentage is between 0 and 100.
	elsif (($an->data->{cgi}{anvil_storage_pool1_unit} eq "%") && (($an->data->{cgi}{anvil_storage_pool1_size} < 0) or ($an->data->{cgi}{anvil_storage_pool1_size} > 100)))
	{
		$an->data->{form}{anvil_storage_pool1_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0120", variables => { field => "#!string!row_0199!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Check the repositor{y,ies} if passed.
	if ($an->data->{cgi}{anvil_repositories})
	{
		foreach my $url (split/,/, $an->data->{cgi}{anvil_repositories})
		{
			$url =~ s/^\s+//;
			$url =~ s/\s+$//;
			if (not $an->Validate->is_url({url => $url}))
			{
				$an->data->{form}{anvil_repositories_star} = "#!string!symbol_0012!#";
				my $message = $an->String->get({key => "explain_0140", variables => { field => "#!string!row_0244!#" }});
				print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
				$problem = 1;
			}
		}
	}

	# Check the anvil!'s cluster name.
	if (not $an->data->{cgi}{anvil_name})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0005!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	} # cman only allows 1-15 characters
	elsif (length($an->data->{cgi}{anvil_name}) > 15)
	{
		$an->data->{form}{anvil_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0122", variables => { field => "#!string!row_0005!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif ($an->data->{cgi}{anvil_name} =~ /[^a-zA-Z0-9\-]/)
	{
		$an->data->{form}{anvil_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0123", variables => { field => "#!string!row_0005!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	### Convery anything with the value '--' to ''.
	$an->data->{cgi}{anvil_ifn_gateway}     = "" if $an->data->{cgi}{anvil_ifn_gateway}     eq "--";
	$an->data->{cgi}{anvil_dns1}            = "" if $an->data->{cgi}{anvil_dns1}            eq "--";
	$an->data->{cgi}{anvil_dns2}            = "" if $an->data->{cgi}{anvil_dns2}            eq "--";
	$an->data->{cgi}{anvil_ntp1}            = "" if $an->data->{cgi}{anvil_ntp1}            eq "--";
	$an->data->{cgi}{anvil_ntp2}            = "" if $an->data->{cgi}{anvil_ntp2}            eq "--";
	$an->data->{cgi}{anvil_switch1_name}    = "" if $an->data->{cgi}{anvil_switch1_name}    eq "--";
	$an->data->{cgi}{anvil_switch1_ip}      = "" if $an->data->{cgi}{anvil_switch1_ip}      eq "--";
	$an->data->{cgi}{anvil_switch2_name}    = "" if $an->data->{cgi}{anvil_switch2_name}    eq "--";
	$an->data->{cgi}{anvil_switch2_ip}      = "" if $an->data->{cgi}{anvil_switch2_ip}      eq "--";
	$an->data->{cgi}{anvil_pdu1_name}       = "" if $an->data->{cgi}{anvil_pdu1_name}       eq "--";
	$an->data->{cgi}{anvil_pdu1_ip}         = "" if $an->data->{cgi}{anvil_pdu1_ip}         eq "--";
	$an->data->{cgi}{anvil_pdu2_name}       = "" if $an->data->{cgi}{anvil_pdu2_name}       eq "--";
	$an->data->{cgi}{anvil_pdu2_ip}         = "" if $an->data->{cgi}{anvil_pdu2_ip}         eq "--";
	$an->data->{cgi}{anvil_pdu3_name}       = "" if $an->data->{cgi}{anvil_pdu3_name}       eq "--";
	$an->data->{cgi}{anvil_pdu3_ip}         = "" if $an->data->{cgi}{anvil_pdu3_ip}         eq "--";
	$an->data->{cgi}{anvil_pdu4_name}       = "" if $an->data->{cgi}{anvil_pdu4_name}       eq "--";
	$an->data->{cgi}{anvil_pdu4_ip}         = "" if $an->data->{cgi}{anvil_pdu4_ip}         eq "--";
	$an->data->{cgi}{anvil_ups1_name}       = "" if $an->data->{cgi}{anvil_ups1_name}       eq "--";
	$an->data->{cgi}{anvil_ups1_ip}         = "" if $an->data->{cgi}{anvil_ups1_ip}         eq "--";
	$an->data->{cgi}{anvil_ups2_name}       = "" if $an->data->{cgi}{anvil_ups2_name}       eq "--";
	$an->data->{cgi}{anvil_ups2_ip}         = "" if $an->data->{cgi}{anvil_ups2_ip}         eq "--";
	$an->data->{cgi}{anvil_striker1_name}   = "" if $an->data->{cgi}{anvil_striker1_name}   eq "--";
	$an->data->{cgi}{anvil_striker1_bcn_ip} = "" if $an->data->{cgi}{anvil_striker1_bcn_ip} eq "--";
	$an->data->{cgi}{anvil_striker1_ifn_ip} = "" if $an->data->{cgi}{anvil_striker1_ifn_ip} eq "--";
	$an->data->{cgi}{anvil_striker2_name}   = "" if $an->data->{cgi}{anvil_striker2_name}   eq "--";
	$an->data->{cgi}{anvil_striker2_bcn_ip} = "" if $an->data->{cgi}{anvil_striker2_bcn_ip} eq "--";
	$an->data->{cgi}{anvil_striker2_ifn_ip} = "" if $an->data->{cgi}{anvil_striker2_ifn_ip} eq "--";
	$an->data->{cgi}{anvil_node1_ipmi_ip}   = "" if $an->data->{cgi}{anvil_node1_ipmi_ip}   eq "--";
	$an->data->{cgi}{anvil_node1_ipmi_user} = "" if $an->data->{cgi}{anvil_node1_ipmi_user} eq "--";
	$an->data->{cgi}{anvil_node2_ipmi_ip}   = "" if $an->data->{cgi}{anvil_node2_ipmi_ip}   eq "--";
	$an->data->{cgi}{anvil_node2_ipmi_user} = "" if $an->data->{cgi}{anvil_node2_ipmi_user} eq "--";
	$an->data->{cgi}{anvil_open_vnc_ports}  = "" if $an->data->{cgi}{anvil_open_vnc_ports}  eq "--";
	
	## Check the common IFN values.
	# Check the gateway and DNS server(s). They are allowed to be blank for air-gapped systems). So we 
	# only check that they are valid, if set.
	if (($an->data->{cgi}{anvil_ifn_gateway}) && (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_ifn_gateway}})))
	{
		$an->data->{form}{anvil_ifn_gateway_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0188!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# Check DNS 1
	if (($an->data->{cgi}{anvil_dns1}) && (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_dns1}})))
	{
		$an->data->{form}{anvil_dns1_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0189!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Check DNS 2
	if (($an->data->{cgi}{anvil_dns2}) && (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_dns2}})))
	{
		$an->data->{form}{anvil_dns2_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0190!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	### NTP is allowed to be blank, but if it is set, if must be IPv4 or a domain name.
	# Check NTP 1
	if ($an->data->{cgi}{anvil_ntp1})
	{
		# it is defined, so it has to be either a domain name or an IPv4 IP.
		if ((not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_ntp1}})) && (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_ntp1}})))
		{
			$an->data->{form}{anvil_ntp1_star} = "#!string!symbol_0012!#";
			my $message = $an->String->get({key => "explain_0099", variables => { field => "#!string!row_0192!#" }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
	}
	
	# Check NTP 2
	if ($an->data->{cgi}{anvil_ntp2})
	{
		# it is defined, so it has to be either a domain name or an IPv4 IP.
		if ((not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_ntp2}})) && (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_ntp2}})))
		{
			$an->data->{form}{anvil_ntp2_star} = "#!string!symbol_0012!#";
			my $message = $an->String->get({key => "explain_0099", variables => { field => "#!string!row_0193!#" }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
	}
	
	### Foundation Pack
	# Check that switch #1's host name and IP are sane, if set. The switches are allowed to be blank in 
	# case the user has unmanaged switches.
	if (not $an->data->{cgi}{anvil_switch1_name})
	{
		# Set it to '--' provided that the IP is also blank.
		if (($an->data->{cgi}{anvil_switch1_ip}) && ($an->data->{cgi}{anvil_switch1_ip} ne "--"))
		{
			# IP set, so host name is needed.
			$an->data->{form}{anvil_switch1_name_star} = "#!string!symbol_0012!#";
			my $message = $an->String->get({key => "explain_0111", variables => { field => "#!string!row_0178!#" }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
		else
		{
			# Is OK
			$an->data->{cgi}{anvil_switch1_name} = "--";
		}
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_switch1_name}}))
	{
		$an->data->{form}{anvil_switch1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0103", variables => { field => "#!string!row_0178!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_switch1_ip})
	{
		# Set it to '--' provided that the IP is also blank.
		if (($an->data->{cgi}{anvil_switch1_name}) && ($an->data->{cgi}{anvil_switch1_name} ne "--"))
		{
			# Host name set, so IP is needed.
			$an->data->{form}{anvil_switch1_ip_star} = "#!string!symbol_0012!#";
			my $message = $an->String->get({key => "explain_0112", variables => { field => "#!string!row_0179!#" }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
		else
		{
			# Is OK
			$an->data->{cgi}{anvil_switch1_ip} = "--";
		}
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_switch1_ip}}))
	{
		$an->data->{form}{anvil_switch1_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0179!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Check that switch #2's host name and IP are sane.
	if (not $an->data->{cgi}{anvil_switch2_name})
	{
		# Set it to '--' provided that the IP is also blank.
		if (($an->data->{cgi}{anvil_switch2_ip}) && ($an->data->{cgi}{anvil_switch2_ip} ne "--"))
		{
			# IP set, so host name is needed.
			$an->data->{form}{anvil_switch2_name_star} = "#!string!symbol_0012!#";
			my $message = $an->String->get({key => "explain_0111", variables => { field => "#!string!row_0178!#" }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
		else
		{
			# Is OK
			$an->data->{cgi}{anvil_switch2_name} = "--";
		}
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_switch2_name}}))
	{
		$an->data->{form}{anvil_switch2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0103", variables => { field => "#!string!row_0180!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_switch2_ip})
	{
		# Set it to '--' provided that the IP is also blank.
		if (($an->data->{cgi}{anvil_switch2_name}) && ($an->data->{cgi}{anvil_switch2_name} ne "--"))
		{
			# Host name set, so IP is needed.
			$an->data->{form}{anvil_switch2_ip_star} = "#!string!symbol_0012!#";
			my $message = $an->String->get({key => "explain_0112", variables => { field => "#!string!row_0181!#" }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
		else
		{
			# Is OK
			$an->data->{cgi}{anvil_switch2_ip} = "--";
		}
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_switch2_ip}}))
	{
		$an->data->{form}{anvil_switch2_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0181!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	### At least two PDUs must be defined.
	# Check that PDU #1's host name and IP are sane.
	my $defined_pdus = 0;
	my $pdus         = [0, 0, 0, 0];
	$an->Log->entry({log_level => 3, message_key => "an_variables_0006", message_variables => {
		name1 => "defined_pdus", value1 => $defined_pdus,
		name2 => "pdus",         value2 => $pdus,
		name3 => "pdus->[0]",    value3 => $pdus->[0],
		name4 => "pdus->[1]",    value4 => $pdus->[1],
		name5 => "pdus->[2]",    value5 => $pdus->[2],
		name6 => "pdus->[3]",    value6 => $pdus->[3],
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $i (1..4)
	{
		my $name_key      = "anvil_pdu${i}_name";
		my $ip_key        = "anvil_pdu${i}_ip";
		my $name_star_key = "anvil_pdu${i}_name_star";
		my $ip_star_key   = "anvil_pdu${i}_ip_star";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0005", message_variables => {
			name1 => "i",             value1 => $i,
			name2 => "name_key",      value2 => $name_key,
			name3 => "ip_key",        value3 => $ip_key,
			name4 => "name_star_key", value4 => $name_star_key,
			name5 => "ip_star_key",   value5 => $ip_star_key,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Some clients/users want PDUs name '1,2,3,4', others 
		# '1A,1B,2A,2B'. This allows for that.
		my $say_pdu = "";
		if ($i == 1)    { $say_pdu = $an->data->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0011!#" : "#!string!device_0007!#"; }
		elsif ($i == 2) { $say_pdu = $an->data->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0012!#" : "#!string!device_0008!#"; }
		elsif ($i == 3) { $say_pdu = "#!string!device_0009!#"; }
		elsif ($i == 4) { $say_pdu = "#!string!device_0010!#"; }
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "i",       value1 => $i,
			name2 => "say_pdu", value2 => $say_pdu,
		}, file => $THIS_FILE, line => __LINE__});
		my $say_pdu_name = $an->String->get({key => "row_0174", variables => { say_pdu => $say_pdu }});
		my $say_pdu_ip   = $an->String->get({key => "row_0175", variables => { say_pdu => $say_pdu }});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "i",            value1 => $i,
			name2 => "say_pdu_name", value2 => $say_pdu_name,
			name3 => "say_pdu_ip",   value3 => $say_pdu_ip,
		}, file => $THIS_FILE, line => __LINE__});
		
		# If either the IP or name is set, validate.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "i",              value1 => $i,
			name2 => "cgi::$name_key", value2 => $an->data->{cgi}{$name_key},
			name3 => "cgi::$ip_key",   value3 => $an->data->{cgi}{$ip_key},
		}, file => $THIS_FILE, line => __LINE__});
		if (($an->data->{cgi}{$name_key}) or ($an->data->{cgi}{$ip_key}))
		{
			$defined_pdus++;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "i",            value1 => $i,
				name2 => "defined_pdus", value2 => $defined_pdus,
				name3 => "pdus",         value3 => $pdus,
			}, file => $THIS_FILE, line => __LINE__});
			$pdus->[$i] = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "pdus->[$i]", value1 => $pdus->[$i],
			}, file => $THIS_FILE, line => __LINE__});
			if (not $an->data->{cgi}{$name_key})
			{
				# Not allowed to be blank.
				$an->data->{form}{$name_star_key} = "#!string!symbol_0012!#";
				my $message = $an->String->get({key => "explain_0142", variables => { 
						field 		=>	$say_pdu_name,
						dependent_field	=>	$say_pdu_ip,
					}});
				print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
				$problem = 1;
			}
			elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{$name_key}}))
			{
				$an->data->{form}{$name_star_key} = "#!string!symbol_0012!#";
				my $message = $an->String->get({key => "explain_0103", variables => { field => $say_pdu_name }});
				print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
				$problem = 1;
			}
			if (not $an->data->{cgi}{$ip_key})
			{
				# Not allowed to be blank.
				$an->data->{form}{$ip_star_key} = "#!string!symbol_0012!#";
				my $message = $an->String->get({key => "explain_0142", variables => { 
						field 		=>	$say_pdu_ip,
						dependent_field	=>	$say_pdu_name,
					}});
				print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
				$problem = 1;
			}
			elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{$ip_key}}))
			{
				$an->data->{form}{$ip_star_key} = "#!string!symbol_0012!#";
				my $message = $an->String->get({key => "explain_0104", variables => { field => $say_pdu_ip }});
				print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
				$problem = 1;
			}
		}
	}
	
	# Each node has to have an outlet defined for at least two PDUs.
	foreach my $j (1, 2)
	{
		my $node_pdu_count = 0;
		my $say_node       = $an->String->get({key => "title_0156", variables => { node_number => $j }});
		foreach my $i (1..4)
		{
			my $outlet_key      = "anvil_node${j}_pdu${i}_outlet";
			my $outlet_star_key = "anvil_node${j}_pdu${i}_outlet_star";
			my $say_pdu         = "";
			if ($i == 1)    { $say_pdu = $an->data->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0011!#" : "#!string!device_0007!#"; }
			elsif ($i == 2) { $say_pdu = $an->data->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0012!#" : "#!string!device_0008!#"; }
			elsif ($i == 3) { $say_pdu = "#!string!device_0009!#"; }
			elsif ($i == 4) { $say_pdu = "#!string!device_0010!#"; }
			my $say_pdu_name = $an->String->get({key => "row_0174", variables => { say_pdu => $say_pdu }});
			if ($an->data->{cgi}{$outlet_key})
			{
				$node_pdu_count++;
				if ($an->data->{cgi}{$outlet_key} =~ /\D/)
				{
					$an->data->{form}{$outlet_star_key} = "#!string!symbol_0012!#";
					my $message = $an->String->get({key => "explain_0108", variables => { 
							node	=>	$say_node,
							field	=>	$say_pdu_name,
						}});
					print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
					$problem = 1;
				}
				# Make sure this PDU is defined.
				if (not $pdus->[$i])
				{
					# it is not.
					$an->data->{form}{$outlet_star_key} = "#!string!symbol_0012!#";
					my $message = $an->String->get({key => "explain_0144", variables => { 
							node	=>	$say_node,
							field	=>	$say_pdu_name,
						}});
					print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
					$problem = 1;
				}
			}
		}
		
		# If there isn't at least 2 outlets defined, bail.
		if ($node_pdu_count < 2)
		{
			my $message = $an->String->get({key => "explain_0145", variables => { node => $say_node }});
			print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
			$problem = 1;
		}
	}
	
	# Make sure at least two PDUs were defined.
	if ($defined_pdus < 2)
	{
		# Not allowed!
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => "#!string!explain_0143!#" }});
		$problem = 1;
	}
	
	# Check that UPS #1's host name and IP are sane.
	if (not $an->data->{cgi}{anvil_ups1_name})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_ups1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0170!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_ups1_name}}))
	{
		$an->data->{form}{anvil_ups1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0103", variables => { field => "#!string!row_0170!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_ups1_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_ups1_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0171!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_ups1_ip}}))
	{
		$an->data->{form}{anvil_ups1_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0171!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Check that UPS #2's host name and IP are sane.
	if (not $an->data->{cgi}{anvil_ups2_name})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_ups2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0172!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_ups2_name}}))
	{
		$an->data->{form}{anvil_ups2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0103", variables => { field => "#!string!row_0172!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_ups2_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_ups2_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0173!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_ups2_ip}}))
	{
		$an->data->{form}{anvil_ups2_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0173!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Check that Striker #1's host name and BCN and IFN IPs are sane.
	if (not $an->data->{cgi}{anvil_striker1_name})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_striker1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0182!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_striker1_name}}))
	{
		$an->data->{form}{anvil_striker1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0103", variables => { field => "#!string!row_0182!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif ($an->data->{cgi}{anvil_striker1_name} !~ /\./)
	{
		# Must be a FQDN
		$an->data->{form}{anvil_striker1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0042", variables => { field => "#!string!row_0182!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_striker1_bcn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_striker1_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0183!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_striker1_bcn_ip}}))
	{
		$an->data->{form}{anvil_striker1_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0183!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_striker1_ifn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_striker1_ifn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0184!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_striker1_bcn_ip}}))
	{
		$an->data->{form}{anvil_striker1_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0184!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Check that Striker #2's host name and BCN and IFN IPs are sane.
	if (not $an->data->{cgi}{anvil_striker2_name})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_striker2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0185!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_striker2_name}}))
	{
		$an->data->{form}{anvil_striker2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0103", variables => { field => "#!string!row_0185!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif ($an->data->{cgi}{anvil_striker2_name} !~ /\./)
	{
		# Must be a FQDN
		$an->data->{form}{anvil_striker2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0042", variables => { field => "#!string!row_0182!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_striker2_bcn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_striker2_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0186!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_striker2_bcn_ip}}))
	{
		$an->data->{form}{anvil_striker2_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0186!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	if (not $an->data->{cgi}{anvil_striker2_ifn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_striker2_ifn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0187!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_striker2_bcn_ip}}))
	{
		$an->data->{form}{anvil_striker2_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0104", variables => { field => "#!string!row_0187!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	### Node specific values.
	# Node 1
	# Host name
	if (not $an->data->{cgi}{anvil_node1_name})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0165!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_node1_name}}))
	{
		$an->data->{form}{anvil_node1_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0107", variables => { 
				field	=>	"#!string!row_0165!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif ($an->data->{cgi}{anvil_node2_name} !~ /\./)
	{
		# Must be a FQDN
		$an->data->{form}{anvil_node2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0042", variables => { field => "#!string!row_0182!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# BCN IP address
	if (not $an->data->{cgi}{anvil_node1_bcn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node1_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0166!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_node1_bcn_ip}}))
	{
		$an->data->{form}{anvil_node1_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0109", variables => { 
				field	=>	"#!string!row_0166!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# IPMI IP address
	if (not $an->data->{cgi}{anvil_node1_ipmi_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node1_ipmi_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0168!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_node1_ipmi_ip}}))
	{
		$an->data->{form}{anvil_node1_ipmi_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0109", variables => { 
				field	=>	"#!string!row_0168!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# IPMI user has to be set.
	if (not $an->data->{cgi}{anvil_node1_ipmi_user})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node1_ipmi_user_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0001!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# SN IP address
	if (not $an->data->{cgi}{anvil_node1_sn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node1_sn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0167!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_node1_sn_ip}}))
	{
		$an->data->{form}{anvil_node1_sn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0109", variables => { 
				field	=>	"#!string!row_0167!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# IFN IP address
	if (not $an->data->{cgi}{anvil_node1_ifn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node1_ifn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0167!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_node1_ifn_ip}}))
	{
		$an->data->{form}{anvil_node1_ifn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0109", variables => { 
				field	=>	"#!string!row_0167!#", 
				node	=>	"#!string!title_0156!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	# Node 2
	# Host name
	if (not $an->data->{cgi}{anvil_node2_name})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0165!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_domain_name({name => $an->data->{cgi}{anvil_node2_name}}))
	{
		$an->data->{form}{anvil_node2_name_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0107", variables => { 
				field	=>	"#!string!row_0165!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# BCN IP address
	if (not $an->data->{cgi}{anvil_node2_bcn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node2_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0166!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_node2_bcn_ip}}))
	{
		$an->data->{form}{anvil_node2_bcn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0109", variables => { 
				field	=>	"#!string!row_0166!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# IPMI IP address
	if (not $an->data->{cgi}{anvil_node2_ipmi_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node2_ipmi_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0168!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_node2_ipmi_ip}}))
	{
		$an->data->{form}{anvil_node2_ipmi_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0109", variables => { 
				field	=>	"#!string!row_0168!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# IPMI user has to be set.
	if (not $an->data->{cgi}{anvil_node2_ipmi_user})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node2_ipmi_user_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0100", variables => { field => "#!string!row_0001!#" }});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# SN IP address
	if (not $an->data->{cgi}{anvil_node2_sn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node2_sn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0167!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_node2_sn_ip}}))
	{
		$an->data->{form}{anvil_node2_sn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0109", variables => { 
				field	=>	"#!string!row_0167!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	# IFN IP address
	if (not $an->data->{cgi}{anvil_node2_ifn_ip})
	{
		# Not allowed to be blank.
		$an->data->{form}{anvil_node2_ifn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0106", variables => { 
				field	=>	"#!string!row_0167!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	elsif (not $an->Validate->is_ipv4({ip => $an->data->{cgi}{anvil_node2_ifn_ip}}))
	{
		$an->data->{form}{anvil_node2_ifn_ip_star} = "#!string!symbol_0012!#";
		my $message = $an->String->get({key => "explain_0109", variables => { 
				field	=>	"#!string!row_0167!#", 
				node	=>	"#!string!title_0157!#",
			}});
		print $an->Web->template({file => "config.html", template => "form-error", replace => { message => $message }});
		$problem = 1;
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "problem", value1 => $problem, 
	}, file => $THIS_FILE, line => __LINE__});
	return($problem);
}

# This calls 'chkconfig' and enables or disables the daemon on boot.
sub set_chkconfig
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "set_chkconfig" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $daemon   = $parameter->{daemon}   ? $parameter->{daemon}   : "";
	my $state    = $parameter->{'state'}  ? $parameter->{'state'}  : "";
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "daemon", value1 => $daemon, 
		name2 => "state",  value2 => $state, 
		name3 => "node",   value3 => $node, 
		name4 => "target", value4 => $target, 
		name5 => "port",   value5 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});

	my $shell_call = $an->data->{path}{chkconfig}." $daemon $state";
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
	
	return(0);
}

# This starts or stops a daemon on a node.
sub set_daemon_state
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "set_daemon_state" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $daemon   = $parameter->{daemon}   ? $parameter->{daemon}   : "";
	my $state    = $parameter->{'state'}  ? $parameter->{'state'}  : "";
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
		name1 => "daemon", value1 => $daemon, 
		name2 => "state",  value2 => $state, 
		name3 => "node",   value3 => $node, 
		name4 => "target", value4 => $target, 
		name5 => "port",   value5 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return_code = "";
	my $shell_call  = $an->data->{path}{initd}."/$daemon $state; ".$an->data->{path}{echo}." return_code:\$?";
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
		
		if ($line =~ /^return_code:(\d+)/)
		{
			$return_code = $1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This updates the ricci and root passwords, and closes the connection after 'root' is changed. After this 
# function, the next login will be a new one.
sub set_password_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "set_password_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $user         = $parameter->{user}         ? $parameter->{user}         : "";
	my $node         = $parameter->{node}         ? $parameter->{node}         : "";
	my $target       = $parameter->{target}       ? $parameter->{target}       : "";
	my $port         = $parameter->{port}         ? $parameter->{port}         : "";
	my $password     = $parameter->{password}     ? $parameter->{password}     : "";
	my $new_password = $parameter->{new_password} ? $parameter->{new_password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "user",   value1 => $user, 
		name2 => "node",   value2 => $node, 
		name3 => "target", value3 => $target, 
		name4 => "port",   value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "password",     value1 => $password, 
		name2 => "new_password", value2 => $new_password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Set the new password first.
	my $shell_call = $an->data->{path}{echo}." '$new_password' | ".$an->data->{path}{passwd}." $user --stdin";
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
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
	
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "new_password", value1 => $new_password,
	}, file => $THIS_FILE, line => __LINE__});
	return($new_password);
}

# This sets the 'ricci' user's passwords.
sub set_ricci_password
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "set_ricci_password" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### NOTE: For now, ricci and root passwords are set to the same thing. This might change later, so 
	###       this method is designed to support different passwords.
	# Set the passwords on the nodes.
	my $ok             = 1;
	my $node1_ricci_pw = "";
	my $node2_ricci_pw = "";
	if (not $an->data->{node}{node1}{has_servers})
	{
		($node1_ricci_pw) = $an->InstallManifest->set_password_on_node({
				node         => $an->data->{sys}{anvil}{node1}{name}, 
				target       => $an->data->{sys}{anvil}{node1}{use_ip}, 
				port         => $an->data->{sys}{anvil}{node1}{use_port}, 
				password     => $an->data->{sys}{anvil}{node1}{password},
				user         => "ricci",
				new_password => $an->data->{sys}{anvil}{password},
			});
	}
	if (not $an->data->{node}{node2}{has_servers})
	{
		($node2_ricci_pw) = $an->InstallManifest->set_password_on_node({
				node         => $an->data->{sys}{anvil}{node2}{name}, 
				target       => $an->data->{sys}{anvil}{node2}{use_ip}, 
				port         => $an->data->{sys}{anvil}{node2}{use_port}, 
				password     => $an->data->{sys}{anvil}{node2}{password},
				user         => "ricci",
				new_password => $an->data->{sys}{anvil}{password},
			});
	}
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_ricci_pw", value1 => $node1_ricci_pw,
		name2 => "node2_ricci_pw", value2 => $node2_ricci_pw,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Test the new password.
	my $node1_access = "";
	my $node2_access = "";
	($node1_access) = $an->Check->access({
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		}) if not $an->data->{node}{node1}{has_servers};
	($node2_access) = $an->Check->access({
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
		}) if not $an->data->{node}{node2}{has_servers};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_access", value1 => $node1_access,
		name2 => "node2_access", value2 => $node2_access,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If both nodes are accessible, we're golden.
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0073!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0073!#";
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif (not $node1_access)
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0074!#",
		$ok            = 0;
	}
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif (not $node2_access)
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0074!#",
		$ok            = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0267!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This sets the 'root' user's passwords.
sub set_root_password
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "set_root_password" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### NOTE: For now, ricci and root passwords are set to the same thing. This might change later, so 
	###       this function is designed to support different passwords.
	# Set the passwords on the nodes.
	my $ok           = 1;
	my $node1_access = 1;
	my $node2_access = 1;
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::anvil_node1_current_password", value1 => $an->data->{sys}{anvil}{node1}{password},
		name2 => "cgi::anvil_node2_current_password", value2 => $an->data->{sys}{anvil}{node2}{password},
	}, file => $THIS_FILE, line => __LINE__});
	if (not $an->data->{node}{node1}{has_servers})
	{
		($an->data->{sys}{anvil}{node1}{password}) = $an->InstallManifest->set_password_on_node({
				node         => $an->data->{sys}{anvil}{node1}{name}, 
				target       => $an->data->{sys}{anvil}{node1}{use_ip}, 
				port         => $an->data->{sys}{anvil}{node1}{use_port}, 
				password     => $an->data->{sys}{anvil}{node1}{password},
				user         => "root",
				new_password => $an->data->{sys}{anvil}{password},
			});
		
		# Set the CGI variable in case we abort and have to start over.
		$an->data->{cgi}{anvil_node1_current_password} = $an->data->{sys}{anvil}{node1}{password}; 
		$an->data->{sys}{anvil}{node1}{password}       = $an->data->{sys}{anvil}{password};
		$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
			name1 => "cgi::anvil_node1_current_password", value1 => $an->data->{cgi}{anvil_node1_current_password},
			name2 => "sys::anvil::node1::password",       value2 => $an->data->{sys}{anvil}{node1}{password},
		}, file => $THIS_FILE, line => __LINE__});
	}
	if (not $an->data->{node}{node2}{has_servers})
	{
		($an->data->{sys}{anvil}{node2}{password}) = $an->InstallManifest->set_password_on_node({
				node         => $an->data->{sys}{anvil}{node2}{name}, 
				target       => $an->data->{sys}{anvil}{node2}{use_ip}, 
				port         => $an->data->{sys}{anvil}{node2}{use_port}, 
				password     => $an->data->{sys}{anvil}{node2}{password},
				user         => "root",
				new_password => $an->data->{sys}{anvil}{password},
			});
		
		# Set the CGI variable in case we abort and have to start over.
		$an->data->{cgi}{anvil_node2_current_password} = $an->data->{sys}{anvil}{node2}{password}; 
		$an->data->{sys}{anvil}{node2}{password}       = $an->data->{sys}{anvil}{password};
		$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
			name1 => "cgi::anvil_node2_current_password", value1 => $an->data->{cgi}{anvil_node2_current_password},
			name2 => "sys::anvil::node2::password",       value2 => $an->data->{sys}{anvil}{node2}{password},
		}, file => $THIS_FILE, line => __LINE__});
	}
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::anvil_node1_current_password", value1 => $an->data->{sys}{anvil}{node1}{password},
		name2 => "cgi::anvil_node2_current_password",    value2 => $an->data->{sys}{anvil}{node2}{password},
	}, file => $THIS_FILE, line => __LINE__});
	
	# Test the new password.
	($node1_access) = $an->Check->access({
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		}) if not $an->data->{node}{node1}{has_servers};
	($node2_access) = $an->Check->access({
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
		}) if not $an->data->{node}{node2}{has_servers};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_access", value1 => $node1_access,
		name2 => "node2_access", value2 => $node2_access,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If both nodes are accessible, we're golden.
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0073!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0073!#";
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif (not $node1_access)
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0074!#",
		$ok            = 0;
	}
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif (not $node2_access)
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0074!#",
		$ok            = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0255!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This does the work of creating a metadata on each DRBD backing device. It checks first to see if there 
# already is a metadata and, if so, does nothing.
sub setup_drbd_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "setup_drbd_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### Write out the config files if missing.
	# Global common file
	if (not $an->data->{node}{$node}{drbd_file}{global_common})
	{
		my $shell_call =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{drbd_global_common}." << EOF\n";
		   $shell_call .= $an->data->{drbd}{global_common}."\n";
		   $shell_call .= "EOF";
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
	
	# If either node has no resource config file but does have metadata, wipe the MD.
	$an->data->{node}{$node}{'wipe-md'}{r0} = 0;
	$an->data->{node}{$node}{'wipe-md'}{r1} = 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node}::wipe-md::r0", value1 => $an->data->{node}{$node}{'wipe-md'}{r0},
		name2 => "node::${node}::wipe-md::r1", value2 => $an->data->{node}{$node}{'wipe-md'}{r1},
	}, file => $THIS_FILE, line => __LINE__});
	
	# r0.res
	if (not $an->data->{node}{$node}{drbd_file}{r0})
	{
		$an->data->{node}{$node}{'wipe-md'}{r0} = 1;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node}::wipe-md::r0", value1 => $an->data->{node}{$node}{'wipe-md'}{r0},
		}, file => $THIS_FILE, line => __LINE__});
		
		# Resource 0 config
		my $shell_call = $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{drbd_r0}." << EOF\n";
		   $shell_call .= $an->data->{drbd}{r0}."\n";
		   $shell_call .= "EOF";
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
	
	# r1.res
	if ($an->data->{cgi}{anvil_storage_pool2_byte_size})
	{
		if (not $an->data->{node}{$node}{drbd_file}{r1})
		{
			$an->data->{node}{$node}{'wipe-md'}{r1} = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node}::wipe-md::r1", value1 => $an->data->{node}{$node}{'wipe-md'}{r1},
			}, file => $THIS_FILE, line => __LINE__});
			
			# Resource 0 config
			my $shell_call =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{drbd_r1}." << EOF\n";
			   $shell_call .= $an->data->{drbd}{r1}."\n";
			   $shell_call .= "EOF";
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
	}
	
	### Now setup the meta-data, if needed. Start by reading 'blkid' to see
	### if the partitions already are drbd.
	# Check if the meta-data exists already
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node}::pool1_partition", value1 => $an->data->{node}{$node}{pool1}{partition},
		name2 => "node::${node}::pool2_partition", value2 => $an->data->{node}{$node}{pool2}{partition},
	}, file => $THIS_FILE, line => __LINE__});
	my ($pool1_return_code) = $an->InstallManifest->check_for_drbd_metadata({
			node     => $node,
			target   => $target, 
			port     => $port, 
			password => $password,
			device   => $an->data->{node}{$node}{pool1}{device},
			resource => "r0",
		});
	my  $pool2_return_code  = 7;
	if ($an->data->{cgi}{anvil_storage_pool2_byte_size})
	{
		($pool2_return_code) = $an->InstallManifest->check_for_drbd_metadata({
				node     => $node,
				target   => $target, 
				port     => $port, 
				password => $password,
				device   => $an->data->{node}{$node}{pool2}{device},
				resource => "r1",
			});
	}
	
	# 0 = Created
	# 1 = Already had meta-data, nothing done
	# 2 = Partition not found
	# 3 = No device passed.
	# 4 = Foreign signature found on device
	# 5 = Device doesn't match to a DRBD resource
	# 6 = DRBD resource not defined
	# 7 = N/A (no pool 2), set by the caller
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "pool1_return_code", value1 => $pool1_return_code,
		name2 => "pool2_return_code", value2 => $pool2_return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($pool1_return_code, $pool2_return_code);
}

# This checks for and creates the GFS2 /shared partition if necessary
sub setup_gfs2
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "setup_gfs2" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my ($lv_ok) = $an->InstallManifest->create_shared_lv({
			node     => $node, 
			target   => $target, 
			port     => $port, 
			password => $password, 
		});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "lv_ok", value1 => $lv_ok,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Now create the partition if the LV was OK
	my $ok          = 1;
	my $create_gfs2 = 1;
	my $return_code = 0;
	if ($lv_ok)
	{
		# Check if the LV already has a GFS2 FS
		my $shell_call = $an->data->{path}{gfs2_tool}." sb /dev/".$an->data->{sys}{vg_pool1_name}.$an->data->{path}{shared}." uuid; ".$an->data->{path}{echo}." return_code:\$?";
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
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /current uuid = (.*)$/)
			{
				# This will be useful later in the fstab stage
				$an->data->{sys}{shared_fs_uuid} = $1;
				$an->data->{sys}{shared_fs_uuid} = lc($an->data->{sys}{shared_fs_uuid});
				$an->Log->entry({log_level => 2, message_key => "log_0056", message_variables => {
					device => "/dev/".$an->data->{sys}{vg_pool1_name}.$an->data->{path}{shared}, 
					uuid   => $an->data->{sys}{shared_fs_uuid}, 
				}, file => $THIS_FILE, line => __LINE__});
				$create_gfs2 = 0;
				$return_code = 1;
			}
			if ($line =~ /^return_code:(\d+)/)
			{
				my $return_code = $1;
				if ($return_code eq "0")
				{
					# GFS2 FS exists
					$an->Log->entry({log_level => 2, message_key => "log_0057", file => $THIS_FILE, line => __LINE__});
					$create_gfs2 = 0;
				}
				else
				{
					# Doesn't appear to exist
					$an->Log->entry({log_level => 2, message_key => "log_0058", file => $THIS_FILE, line => __LINE__});
					$create_gfs2 = 1;
				}
			}
		}
		
		# Create the partition if needed.
		if (($create_gfs2) && (not $an->data->{sys}{shared_fs_uuid}))
		{
			my $shell_call = $an->data->{path}{'mkfs.gfs2'}." -p lock_dlm -j 2 -t ".$an->data->{cgi}{anvil_name}.":shared /dev/".$an->data->{sys}{vg_pool1_name}.$an->data->{path}{shared}." -O; ".$an->data->{path}{echo}." return_code:\$?";
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
				
				if ($line =~ /UUID:\s+(.*)$/)
				{
					# This will be useful later in the fstab stage
					$an->data->{sys}{shared_fs_uuid} = $1;
					$an->data->{sys}{shared_fs_uuid} = lc($an->data->{sys}{shared_fs_uuid});
					$an->Log->entry({log_level => 2, message_key => "log_0059", message_variables => {
						device => "/dev/".$an->data->{sys}{vg_pool1_name}.$an->data->{path}{shared}, 
						uuid   => $an->data->{sys}{shared_fs_uuid}, 
					}, file => $THIS_FILE, line => __LINE__});
					$create_gfs2 = 0;
				}
				if ($line =~ /^return_code:(\d+)/)
				{
					my $return_code = $1;
					if ($return_code eq "0")
					{
						# GFS2 FS created
						$an->Log->entry({log_level => 2, message_key => "log_0060", file => $THIS_FILE, line => __LINE__});
					}
					else
					{
						# Format appears to have failed.
						$an->Log->entry({log_level => 1, message_key => "log_0061", message_variables => {
							device      => "/dev/".$an->data->{sys}{vg_pool1_name}.$an->data->{path}{shared}, 
							return_code => $return_code, 
						}, file => $THIS_FILE, line => __LINE__});
						$return_code = 2;
					}
				}
			}
		}
		
		# 0 == created
		# 1 == Exists
		# 2 == Format failed
		my $ok = 1;
		my $class   = "highlight_good_bold";
		my $message = "#!string!state_0045!#";
		if ($return_code == "1")
		{
			# Already existed
			$message = "#!string!state_0020!#";
		}
		elsif ($return_code == "2")
		{
			# Format failed
			$class   = "highlight_warning_bold";
			$message = "#!string!state_0089!#";
			$ok      = 0;
		}
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message-wide", replace => { 
			row	=>	"#!string!row_0263!#",
			class	=>	$class,
			message	=>	$message,
		}});
	}
	else
	{
		# LV failed to create
		$ok = 0;
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This will manually mount the GFS2 partition on the node, configuring /etc/fstab in the process if needed.
sub setup_gfs2_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "setup_gfs2_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If I have the UUID, then check/set fstab
	my $return_code = 0;
	
	# Make sure the '/shared' directory exists.
	my $shell_call = "
if [ -e '".$an->data->{path}{shared}."' ];
then 
	".$an->data->{path}{echo}." '".$an->data->{path}{shared}." exists';
else 
	".$an->data->{path}{'mkdir'}." ".$an->data->{path}{shared}.";
	".$an->data->{path}{echo}." '".$an->data->{path}{shared}." created'
fi";
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

	# Append the gfs2 partition to /etc/fstab if needed.
	if ($an->data->{sys}{shared_fs_uuid})
	{
		my $append_ok    = 0;
		my $fstab_string = "UUID=".$an->data->{sys}{shared_fs_uuid}." ".$an->data->{path}{shared}." gfs2 defaults,noatime,nodiratime 0 0";
		$shell_call   = "
if \$(".$an->data->{path}{'grep'}." -q shared /etc/fstab)
then
    ".$an->data->{path}{echo}." 'shared exists'
else
    ".$an->data->{path}{echo}." \"$fstab_string\" >> /etc/fstab
    if \$(".$an->data->{path}{'grep'}." -q shared /etc/fstab)
    then
        ".$an->data->{path}{echo}." 'shared added'
    else
        ".$an->data->{path}{echo}." 'failed to add shared'
    fi
fi";
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
			
			if ($line =~ /failed to add/)
			{
				# Failed to append to fstab
				$an->Log->entry({log_level => 1, message_key => "log_0046", message_variables => {
					string => $fstab_string, 
				}, file => $THIS_FILE, line => __LINE__});
				$return_code = 1;
			}
		}
		
		# Test mount using the 'mount' command
		if ($return_code ne "1")
		{
			my $already_mounted = 0;
			my $shell_call      = $an->data->{path}{mount}." ".$an->data->{path}{shared}."; ".$an->data->{path}{echo}." return_code:\$?";
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
				
				if ($line =~ /already mounted/)
				{
					$already_mounted = 1;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "already_mounted", value1 => $already_mounted, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				
				if ($line =~ /^return_code:(\d+)/)
				{
					my $return_code = $1;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "return_code",     value1 => $return_code, 
						name2 => "already_mounted", value2 => $already_mounted, 
					}, file => $THIS_FILE, line => __LINE__});
					
					if (($return_code eq "0") or (($return_code eq "1") && ($already_mounted)))
					{
						# Success
						$return_code = 0;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "return_code", value1 => $return_code, 
						}, file => $THIS_FILE, line => __LINE__});
						$an->Log->entry({log_level => 2, message_key => "log_0047", file => $THIS_FILE, line => __LINE__});
					}
					else
					{
						# Failed to mount
						$an->Log->entry({log_level => 1, message_key => "log_0048", message_variables => { return_code => $return_code }, file => $THIS_FILE, line => __LINE__});
						$return_code = 2;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "return_code", value1 => $return_code, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
			}
			
			# Finally, test '/etc/init.d/gfs2 status'
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($return_code ne "2")
			{
				my $shell_call = $an->data->{path}{initd}."/gfs2 status; ".$an->data->{path}{echo}." return_code:\$?";
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
					
					if ($line =~ /^return_code:(\d+)/)
					{
						my $return_code = $1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "return_code", value1 => $return_code, 
						}, file => $THIS_FILE, line => __LINE__});
						if ($return_code eq "0")
						{
							# Success
							$an->Log->entry({log_level => 2, message_key => "log_0049", file => $THIS_FILE, line => __LINE__});
						}
						else
						{
							# The GFS2 LSB script failed to see the '/shared' file system.
							$an->Log->entry({log_level => 1, message_key => "log_0050", message_variables => { return_code => $return_code }, file => $THIS_FILE, line => __LINE__});
							$return_code = 3;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "return_code", value1 => $return_code, 
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
				}
			}
		}
		
		# Create the subdirectories if asked
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "return_code", value1 => $return_code,
		}, file => $THIS_FILE, line => __LINE__});
		if (not $return_code)
		{
			foreach my $directory (@{$an->data->{path}{nodes}{shared_subdirectories}})
			{
				next if not $directory;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "directory", value1 => $directory,
				}, file => $THIS_FILE, line => __LINE__});
				my $shell_call = "
if [ -e '".$an->data->{path}{shared}."/$directory' ]
then
    ".$an->data->{path}{echo}." '".$an->data->{path}{shared}."/$directory already exists'
else
    ".$an->data->{path}{'mkdir'}." ".$an->data->{path}{shared}."/$directory; ".$an->data->{path}{echo}." return_code:\$?
fi";
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
					
					if ($line =~ /^return_code:(\d+)/)
					{
						my $return_code = $1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "return_code", value1 => $return_code, 
						}, file => $THIS_FILE, line => __LINE__});
						if ($return_code eq "0")
						{
							# Success
							$an->Log->entry({log_level => 2, message_key => "log_0051", message_variables => {
								directory => $directory, 
							}, file => $THIS_FILE, line => __LINE__});
						}
						else
						{
							# Failed
							$an->Log->entry({log_level => 1, message_key => "log_0052", message_variables => {
								directory   => $directory, 
								return_code => $return_code, 
							}, file => $THIS_FILE, line => __LINE__});
							$return_code = 4;
							$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
								name1 => "return_code", value1 => $return_code, 
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
				}
			}
		}
		
		# Setup SELinux context on /shared
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "return_code", value1 => $return_code, 
		}, file => $THIS_FILE, line => __LINE__});
		if (not $return_code)
		{
			my $shell_call = "
context=\$(".$an->data->{path}{ls}." -laZ ".$an->data->{path}{shared}." | ".$an->data->{path}{'grep'}." ' .\$' | ".$an->data->{path}{awk}." '{print \$4}' | ".$an->data->{path}{awk}." -F : '{print \$3}');
if [ \$context == 'file_t' ];
then
    ".$an->data->{path}{semanage}." fcontext -a -t virt_etc_t '".$an->data->{path}{shared}."(/.*)?' 
    ".$an->data->{path}{restorecon}." -r ".$an->data->{path}{shared}."
    context=\$(".$an->data->{path}{ls}." -laZ ".$an->data->{path}{shared}." | ".$an->data->{path}{'grep'}." ' .\$' | ".$an->data->{path}{awk}." '{print \$4}' | ".$an->data->{path}{awk}." -F : '{print \$3}');
    if [ \$context == 'virt_etc_t' ];
    then
        ".$an->data->{path}{echo}." 'context updated'
    else
        ".$an->data->{path}{echo}." \"context failed to update, still: \$context.\"
    fi
else 
    ".$an->data->{path}{echo}." 'context ok';
fi";
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
				
				if ($line =~ /context updated/)
				{
					# Updated
					$an->Log->entry({log_level => 2, message_key => "log_0053", file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /context ok/)
				{
					# Was already OK.
					$an->Log->entry({log_level => 2, message_key => "log_0054", file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /failed to update/)
				{
					# Failed for some reason.
					$an->Log->entry({log_level => 1, message_key => "log_0055", file => $THIS_FILE, line => __LINE__});
					$return_code = 5;
				}
			}
		}
	}
	else
	{
		# Somehow got here without a UUID.
		$return_code = 6;
	}
	
	# 0 = OK
	# 1 = Failed to append to fstab
	# 2 = Failed to mount
	# 3 = GFS2 LBS status check failed.
	# 4 = Failed to create subdirectories
	# 5 = SELinux configuration failed.
	# 6 = UUID for GFS2 partition not recorded
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
} 

# The checks to see if either PV or VG needs to be created and does so if needed.
sub setup_lvm_pv_and_vgs
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "setup_lvm_pv_and_vgs" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Start 'clvmd' on both nodes.
	my $return_code       = 0;
	my $node1             = $an->data->{sys}{anvil}{node1}{name};
	my $node2             = $an->data->{sys}{anvil}{node2}{name};
	my $node1_return_code = 1;
	my $node2_return_code = 1;
	($node1_return_code) = $an->InstallManifest->start_clvmd_on_node({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		}) if not $an->data->{node}{node1}{has_servers};
	($node2_return_code) = $an->InstallManifest->start_clvmd_on_node({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
		}) if not $an->data->{node}{node2}{has_servers};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_return_code", value1 => $node1_return_code,
		name2 => "node2_return_code", value2 => $node2_return_code,
	}, file => $THIS_FILE, line => __LINE__});
	# 0 = Started
	# 1 = Already running
	# 2 = Failed
	
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0014!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0014!#";
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif ($node1_return_code eq "1")
	{
		$node1_message = "#!string!state_0078!#";
	}
	elsif ($node1_return_code eq "2")
	{
		# Failed to start clvmd
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0123!#";
		$ok            = 0;
	}
	
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif ($node2_return_code eq "1")
	{
		$node2_message = "#!string!state_0078!#";
	}
	elsif ($node2_return_code eq "2")
	{
		# Failed to start clvmd
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0123!#";
		$ok            = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0259!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	### Below here, commands only need to be run on one node
	# PV messages
	if (($node1_return_code ne "2") && ($node2_return_code ne "2"))
	{
		# Excellent, create the PVs if needed.
		my ($pv_return_code) = $an->InstallManifest->create_lvm_pvs({
				node     => $node1, 
				target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node1}{use_port}, 
				password => $an->data->{sys}{anvil}{node1}{password},
			});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "pv_return_code", value1 => $pv_return_code,
		}, file => $THIS_FILE, line => __LINE__});
		# 0 == OK
		# 1 == already existed
		# 2 == Failed
		
		my $class   = "highlight_good_bold";
		my $message = "#!string!state_0045!#";
		if ($pv_return_code == "1")
		{
			# Already existed
			$message = "#!string!state_0020!#";
		}
		elsif ($pv_return_code == "2")
		{
			# Failed create PV
			$class   = "highlight_warning_bold";
			$message = "#!string!state_0018!#";
			$ok      = 0;
		}
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message-wide", replace => { 
			row	=>	"#!string!row_0260!#",
			class	=>	$class,
			message	=>	$message,
		}});

		# Now create the VGs
		my $vg_return_code = 0;
		if ($pv_return_code ne "2")
		{
			# Create the VGs
			($vg_return_code) = $an->InstallManifest->create_lvm_vgs({
					node     => $node1, 
					target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
					port     => $an->data->{sys}{anvil}{node1}{use_port}, 
					password => $an->data->{sys}{anvil}{node1}{password},
				});
			
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "vg_return_code", value1 => $vg_return_code,
			}, file => $THIS_FILE, line => __LINE__});
			# 0 == OK
			# 1 == already existed
			# 2 == Failed
			
			my $ok      = 1;
			my $class   = "highlight_good_bold";
			my $message = "#!string!state_0045!#";
			if ($vg_return_code == "1")
			{
				# Already existed
				$message = "#!string!state_0020!#";
			}
			elsif ($vg_return_code == "2")
			{
				# Failed create PV
				$class   = "highlight_warning_bold";
				$message = "#!string!state_0018!#";
				$ok      = 0;
			}
			print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message-wide", replace => { 
				row	=>	"#!string!row_0261!#",
				class	=>	$class,
				message	=>	$message,
			}});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This looks for existing install manifest files and displays those it finds.
sub show_existing_install_manifests
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "show_existing_install_manifests" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $header_printed = 0;
	my $return         = $an->ScanCore->get_manifests();
	foreach my $hash_ref (@{$return})
	{
		my $manifest_uuid = $hash_ref->{manifest_uuid};
		my $manifest_data = $hash_ref->{manifest_data};
		my $manifest_note = $hash_ref->{manifest_note};
		my $modified_date = $hash_ref->{modified_date};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
			name1 => "manifest_uuid", value1 => $manifest_uuid,
			name2 => "manifest_data", value2 => $manifest_data,
			name3 => "manifest_note", value3 => $manifest_note,
			name4 => "modified_date", value4 => $modified_date,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Parse this and pull out the details
		$an->ScanCore->parse_install_manifest({uuid => $manifest_uuid});
		
		# This isn't actually passed by CGI, but 'parse_install_manifest' sets it as if it were, so 
		# that is how we'll grab it.
		my $anvil_name =  $an->data->{cgi}{anvil_name};
		my $edit_date  =  $modified_date;
		   $edit_date  =~ s/(:\d\d)\..*/$1/;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "anvil_name", value1 => $anvil_name,
			name2 => "edit_date",  value2 => $edit_date,
		}, file => $THIS_FILE, line => __LINE__});
		$an->data->{manifest_file}{$manifest_uuid}{anvil} = $an->String->get({key => "message_0460", variables => { 
				anvil	=>	$anvil_name,
				date	=>	$edit_date,
				raw	=>	"/cgi-bin/configure?task=manifests&raw=true&manifest_uuid=$manifest_uuid",
			}});
		
		if (not $header_printed)
		{
			print $an->Web->template({file => "config.html", template => "install-manifest-header"});
			$header_printed = 1;
		}
	}
	
	foreach my $manifest_uuid (sort {$b cmp $a} keys %{$an->data->{manifest_file}})
	{
		print $an->Web->template({file => "config.html", template => "install-manifest-entry", replace => { 
			description	=>	$an->data->{manifest_file}{$manifest_uuid}{anvil},
			load		=>	"/cgi-bin/configure?task=manifests&load=true&manifest_uuid=$manifest_uuid",
			run		=>	"/cgi-bin/configure?task=manifests&run=true&manifest_uuid=$manifest_uuid",
			'delete'	=>	"/cgi-bin/configure?task=manifests&delete=true&manifest_uuid=$manifest_uuid",
		}});
	}
	if ($header_printed)
	{
		print $an->Web->template({file => "config.html", template => "install-manifest-footer"});
	}
	
	return(0);
}

# This shows a summary of what the user selected and asks them to confirm that they are happy.
sub show_summary_manifest
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "show_summary_manifest" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Show the manifest form.
	my $say_repos =  $an->data->{cgi}{anvil_repositories};
	   $say_repos =~ s/,/<br \/>/;
	   $say_repos = "#!string!symbol_0011!#" if not $say_repos;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::anvil_node1_name", value1 => $an->data->{cgi}{anvil_node1_name},
		name2 => "cgi::anvil_node2_name", value2 => $an->data->{cgi}{anvil_node2_name},
	}, file => $THIS_FILE, line => __LINE__});

	# Open the table.
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-header", replace => { form_file => "/cgi-bin/configure" }});
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-title", replace => { title => "#!string!title_0159!#" }});
	
	# Node colum header.
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-column-header", replace => { 
		column1		=>	"#!string!header_0001!#",
		column2		=>	"#!string!header_0002!#",
	}});
	
	# Node names
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0165!#",
		column1		=>	$an->data->{cgi}{anvil_node1_name},
		column2		=>	$an->data->{cgi}{anvil_node2_name},
	}});
	
	# Node BCN IPs
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0166!#",
		column1		=>	$an->data->{cgi}{anvil_node1_bcn_ip},
		column2		=>	$an->data->{cgi}{anvil_node2_bcn_ip},
	}});
	
	# Node IPMI BMC IPs
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0168!#",
		column1		=>	$an->data->{cgi}{anvil_node1_ipmi_ip},
		column2		=>	$an->data->{cgi}{anvil_node2_ipmi_ip},
	}});
	
	# Node IPMI User
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0001!#",
		column1		=>	$an->data->{cgi}{anvil_node1_ipmi_user},
		column2		=>	$an->data->{cgi}{anvil_node2_ipmi_user},
	}});
	
	# Node IPMI Lanplus
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0003!#",
		column1		=>	$an->data->{cgi}{anvil_node1_ipmi_lanplus} eq "true" ? "#!string!state_0038!#" : "#!string!state_0102!#",
		column2		=>	$an->data->{cgi}{anvil_node2_ipmi_lanplus} eq "true" ? "#!string!state_0038!#" : "#!string!state_0102!#",
	}});
	
	# Node SN IPs
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0167!#",
		column1		=>	$an->data->{cgi}{anvil_node1_sn_ip},
		column2		=>	$an->data->{cgi}{anvil_node2_sn_ip},
	}});
	
	# Node IFN IPs
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0169!#",
		column1		=>	$an->data->{cgi}{anvil_node1_ifn_ip},
		column2		=>	$an->data->{cgi}{anvil_node2_ifn_ip},
	}});
	
	### PDUs are a little more complicated.
	foreach my $i (1..$an->data->{sys}{install_manifest}{pdu_count})
	{
		my $say_pdu = "";
		if ($i == 1)    { $say_pdu = $an->data->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0011!#" : "#!string!device_0007!#"; }
		elsif ($i == 2) { $say_pdu = $an->data->{sys}{install_manifest}{pdu_count} == 2 ? "#!string!device_0012!#" : "#!string!device_0008!#"; }
		elsif ($i == 3) { $say_pdu = "#!string!device_0009!#"; }
		elsif ($i == 4) { $say_pdu = "#!string!device_0010!#"; }
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "i",       value1 => $i,
			name2 => "say_pdu", value2 => $say_pdu,
		}, file => $THIS_FILE, line => __LINE__});
		
		my $say_pdu_name         = $an->String->get({key => "row_0176", variables => { say_pdu => $say_pdu }});
		my $node1_pdu_outlet_key = "anvil_node1_pdu${i}_outlet";
		my $node2_pdu_outlet_key = "anvil_node2_pdu${i}_outlet";
		
		# PDUs
		print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
			row		=>	"$say_pdu_name",
			column1		=>	$an->data->{cgi}{$node1_pdu_outlet_key} ? $an->data->{cgi}{$node1_pdu_outlet_key} : "#!string!symbol_0011!#",
			column2		=>	$an->data->{cgi}{$node2_pdu_outlet_key} ? $an->data->{cgi}{$node2_pdu_outlet_key} : "#!string!symbol_0011!#",
		}});
	}
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-spacer"});
	
	# Strikers header
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-title", replace => { title => "#!string!title_0161!#" }});
	
	# Striker colum header.
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-column-header", replace => { 
		column1		=>	"#!string!header_0014!#",
		column2		=>	"#!string!header_0015!#",
	}});
	
	# Striker names
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0165!#",
		column1		=>	$an->data->{cgi}{anvil_striker1_name},
		column2		=>	$an->data->{cgi}{anvil_striker2_name},
	}});
	
	# Striker BCN IP
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0166!#",
		column1		=>	$an->data->{cgi}{anvil_striker1_bcn_ip},
		column2		=>	$an->data->{cgi}{anvil_striker2_bcn_ip},
	}});
	
	# Striker IFN IP
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0169!#",
		column1		=>	$an->data->{cgi}{anvil_striker1_ifn_ip},
		column2		=>	$an->data->{cgi}{anvil_striker2_ifn_ip},
	}});
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-spacer"});
	
	# Foundation Pack Header
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-title", replace => { title => "#!string!title_0160!#" }});
	
	# Striker 2 colum header.
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-column-header", replace => { 
		column1		=>	"#!string!header_0003!#",
		column2		=>	"#!string!header_0004!#",
	}});
	
	# Striker 4 column header.
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-four-column-header", replace => { 
		column1		=>	"#!string!header_0006!#",
		column2		=>	"#!string!header_0007!#",
		column3		=>	"#!string!header_0006!#",
		column4		=>	"#!string!header_0007!#",
	}});
	
	# Switches
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-four-column-entry", replace => { 
		row		=>	"#!string!row_0195!#",
		column1		=>	$an->data->{cgi}{anvil_switch1_name},
		column2		=>	$an->data->{cgi}{anvil_switch1_ip},
		column3		=>	$an->data->{cgi}{anvil_switch2_name},
		column4		=>	$an->data->{cgi}{anvil_switch2_ip},
	}});
	
	# UPSes
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-four-column-entry", replace => { 
		row		=>	"#!string!row_0197!#",
		column1		=>	$an->data->{cgi}{anvil_ups1_name},
		column2		=>	$an->data->{cgi}{anvil_ups1_ip},
		column3		=>	$an->data->{cgi}{anvil_ups2_name},
		column4		=>	$an->data->{cgi}{anvil_ups2_ip},
	}});
	
	### PDUs are, surprise, a little more complicated.
	my $say_apc_snmp    = $an->String->get({key => "brand_0017"});
	my $say_raritan     = $an->String->get({key => "brand_0018"});
	my $say_apc_alteeve = $an->String->get({key => "brand_0021"});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "cgi::anvil_pdu1_agent", value1 => $an->data->{cgi}{anvil_pdu1_agent},
		name2 => "cgi::anvil_pdu2_agent", value2 => $an->data->{cgi}{anvil_pdu2_agent},
		name3 => "cgi::anvil_pdu3_agent", value3 => $an->data->{cgi}{anvil_pdu3_agent},
		name4 => "cgi::anvil_pdu4_agent", value4 => $an->data->{cgi}{anvil_pdu4_agent},
	}, file => $THIS_FILE, line => __LINE__});
	
	# Which agent?
	my $say_pdu1_brand = $say_apc_snmp;
	if ($an->data->{cgi}{anvil_pdu1_agent} eq "fence_raritan_snmp")
	{
		 $say_pdu1_brand = $say_raritan;
	}
	elsif ($an->data->{cgi}{anvil_pdu1_agent} eq "fence_apc_alteeve")
	{
		 $say_pdu1_brand = $say_apc_snmp;
	}
	my $say_pdu2_brand = $say_apc_snmp;
	if ($an->data->{cgi}{anvil_pdu2_agent} eq "fence_raritan_snmp")
	{
		 $say_pdu2_brand = $say_raritan;
	}
	elsif ($an->data->{cgi}{anvil_pdu2_agent} eq "fence_apc_alteeve")
	{
		 $say_pdu2_brand = $say_apc_snmp;
	}
	my $say_pdu3_brand = $say_apc_snmp;
	if ($an->data->{cgi}{anvil_pdu3_agent} eq "fence_raritan_snmp")
	{
		 $say_pdu3_brand = $say_raritan;
	}
	elsif ($an->data->{cgi}{anvil_pdu3_agent} eq "fence_apc_alteeve")
	{
		 $say_pdu3_brand = $say_apc_snmp;
	}
	my $say_pdu4_brand = $say_apc_snmp;
	if ($an->data->{cgi}{anvil_pdu4_agent} eq "fence_raritan_snmp")
	{
		 $say_pdu4_brand = $say_raritan;
	}
	elsif ($an->data->{cgi}{anvil_pdu4_agent} eq "fence_apc_alteeve")
	{
		 $say_pdu4_brand = $say_apc_snmp;
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "say_pdu1_brand", value1 => $say_pdu1_brand,
		name2 => "say_pdu2_brand", value2 => $say_pdu2_brand,
		name3 => "say_pdu3_brand", value3 => $say_pdu3_brand,
		name4 => "say_pdu4_brand", value4 => $say_pdu4_brand,
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{install_manifest}{pdu_count} == 2)
	{
		### Two PDU setup 
		# PDUs
		print $an->Web->template({file => "config.html", template => "install-manifest-summay-four-column-entry", replace => { 
			row		=>	"#!string!row_0196!#",
			column1		=>	$an->data->{cgi}{anvil_pdu1_name} ? $an->data->{cgi}{anvil_pdu1_name}." ($say_pdu1_brand)" : "--",
			column2		=>	$an->data->{cgi}{anvil_pdu1_ip}   ? $an->data->{cgi}{anvil_pdu1_ip}                       : "--",
			column3		=>	$an->data->{cgi}{anvil_pdu2_name} ? $an->data->{cgi}{anvil_pdu2_name}." ($say_pdu2_brand)" : "--",
			column4		=>	$an->data->{cgi}{anvil_pdu2_ip}   ? $an->data->{cgi}{anvil_pdu2_ip}                       : "--",
		}});
	}
	else
	{
		### Four PDU setup
		# 'PDU 1' will be for '1A' and '1B'.
		print $an->Web->template({file => "config.html", template => "install-manifest-summay-four-column-entry", replace => { 
			row		=>	"#!string!row_0276!#",
			column1		=>	$an->data->{cgi}{anvil_pdu1_name} ? $an->data->{cgi}{anvil_pdu1_name}." ($say_pdu1_brand)" : "--",
			column2		=>	$an->data->{cgi}{anvil_pdu1_ip}   ? $an->data->{cgi}{anvil_pdu1_ip}                       : "--",
			column3		=>	$an->data->{cgi}{anvil_pdu3_name} ? $an->data->{cgi}{anvil_pdu3_name}." ($say_pdu3_brand)" : "--",
			column4		=>	$an->data->{cgi}{anvil_pdu3_ip}   ? $an->data->{cgi}{anvil_pdu3_ip}                       : "--",
		}});
		
		# 'PDU 2' will be for '2A' and '2B'.
		print $an->Web->template({file => "config.html", template => "install-manifest-summay-four-column-entry", replace => { 
			row		=>	"#!string!row_0277!#",
			column1		=>	$an->data->{cgi}{anvil_pdu2_name} ? $an->data->{cgi}{anvil_pdu2_name}." ($say_pdu2_brand)" : "--",
			column2		=>	$an->data->{cgi}{anvil_pdu2_ip}   ? $an->data->{cgi}{anvil_pdu2_ip}                       : "--",
			column3		=>	$an->data->{cgi}{anvil_pdu4_name} ? $an->data->{cgi}{anvil_pdu4_name}." ($say_pdu4_brand)" : "--",
			column4		=>	$an->data->{cgi}{anvil_pdu4_ip}   ? $an->data->{cgi}{anvil_pdu4_ip}                       : "--",
		}});
	}
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-spacer"});
	
	# Shared Variables Header
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-title", replace => { title => "#!string!title_0154!#" }});
	
	# Anvil! name
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0005!#",
		column1		=>	$an->data->{cgi}{anvil_name},
		column2		=>	"&nbsp;",
	}});
	
	# Anvil! Password
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0194!#",
		column1		=>	$an->data->{cgi}{anvil_password},
		column2		=>	"&nbsp;",
	}});
	
	# Media Library size
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0191!#",
		column1		=>	$an->data->{cgi}{anvil_media_library_size}." ".$an->data->{cgi}{anvil_media_library_unit},
		column2		=>	"&nbsp;",
	}});
	
	### NOTE: Disabled now, always 100% to pool 1.
	# Storage Pool 1 size
	if (0)
	{
		print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
			row		=>	"#!string!row_0199!#",
			column1		=>	$an->data->{cgi}{anvil_storage_pool1_size}." ".$an->data->{cgi}{anvil_storage_pool1_unit},
			column2		=>	"&nbsp;",
		}});
	}
	
	# BCN Network Mask
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0200!#",
		column1		=>	$an->data->{cgi}{anvil_bcn_subnet},
		column2		=>	"&nbsp;",
	}});
	
	# SN Network Mask
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0201!#",
		column1		=>	$an->data->{cgi}{anvil_sn_subnet},
		column2		=>	"&nbsp;",
	}});
	
	# IFN Network Mask
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0202!#",
		column1		=>	$an->data->{cgi}{anvil_ifn_subnet},
		column2		=>	"&nbsp;",
	}});
	
	# Default Gateway
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0188!#",
		column1		=>	$an->data->{cgi}{anvil_ifn_gateway} ? $an->data->{cgi}{anvil_ifn_gateway} : "#!string!symbol_0011!#",
		column2		=>	"&nbsp;",
	}});
	
	# DNS 1
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0189!#",
		column1		=>	$an->data->{cgi}{anvil_dns1} ? $an->data->{cgi}{anvil_dns1} : "#!string!symbol_0011!#",
		column2		=>	"&nbsp;",
	}});
	
	# DNS 2
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0189!#",
		column1		=>	$an->data->{cgi}{anvil_dns2} ? $an->data->{cgi}{anvil_dns2} : "#!string!symbol_0011!#",
		column2		=>	"&nbsp;",
	}});
	
	# NTP 1
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0192!#",
		column1		=>	$an->data->{cgi}{anvil_ntp1} ? $an->data->{cgi}{anvil_ntp1} : "#!string!symbol_0011!#",
		column2		=>	"&nbsp;",
	}});
	
	# NTP 2
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-entry", replace => { 
		row		=>	"#!string!row_0193!#",
		column1		=>	$an->data->{cgi}{anvil_ntp2} ? $an->data->{cgi}{anvil_ntp2} : "#!string!symbol_0011!#",
		column2		=>	"&nbsp;",
	}});
	
	### Disabled now.
	# Repositories.
# 	print $an->Web->template({file => "config.html", template => "install-manifest-summay-one-column-entry", replace => { 
# 		row		=>	"#!string!row_0244!#",
# 		column1		=>	"$say_repos",
# 	}});
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-spacer"});
	
	# The footer has all the values recorded as hidden values for the form.
	print $an->Web->template({file => "config.html", template => "install-manifest-summay-footer", replace => { 
		anvil_prefix			=>	$an->data->{cgi}{anvil_prefix},
		anvil_sequence			=>	$an->data->{cgi}{anvil_sequence},
		anvil_domain			=>	$an->data->{cgi}{anvil_domain},
		anvil_password			=>	$an->data->{cgi}{anvil_password},
		anvil_bcn_ethtool_opts		=>	$an->data->{cgi}{anvil_bcn_ethtool_opts}, 
		anvil_bcn_network		=>	$an->data->{cgi}{anvil_bcn_network},
		anvil_bcn_subnet		=>	$an->data->{cgi}{anvil_bcn_subnet},
		anvil_sn_ethtool_opts		=>	$an->data->{cgi}{anvil_sn_ethtool_opts}, 
		anvil_sn_network		=>	$an->data->{cgi}{anvil_sn_network},
		anvil_sn_subnet			=>	$an->data->{cgi}{anvil_sn_subnet},
		anvil_ifn_ethtool_opts		=>	$an->data->{cgi}{anvil_ifn_ethtool_opts}, 
		anvil_ifn_network		=>	$an->data->{cgi}{anvil_ifn_network},
		anvil_ifn_subnet		=>	$an->data->{cgi}{anvil_ifn_subnet},
		anvil_media_library_size	=>	$an->data->{cgi}{anvil_media_library_size},
		anvil_media_library_unit	=>	$an->data->{cgi}{anvil_media_library_unit},
		anvil_storage_pool1_size	=>	$an->data->{cgi}{anvil_storage_pool1_size},
		anvil_storage_pool1_unit	=>	$an->data->{cgi}{anvil_storage_pool1_unit},
		anvil_name			=>	$an->data->{cgi}{anvil_name},
		anvil_node1_name		=>	$an->data->{cgi}{anvil_node1_name},
		anvil_node1_bcn_ip		=>	$an->data->{cgi}{anvil_node1_bcn_ip},
		anvil_node1_bcn_link1_mac	=>	$an->data->{cgi}{anvil_node1_bcn_link1_mac},
		anvil_node1_bcn_link2_mac	=>	$an->data->{cgi}{anvil_node1_bcn_link2_mac},
		anvil_node1_ipmi_ip		=>	$an->data->{cgi}{anvil_node1_ipmi_ip},
		anvil_node1_ipmi_user		=>	$an->data->{cgi}{anvil_node1_ipmi_user},
		anvil_node1_ipmi_lanplus	=>	$an->data->{cgi}{anvil_node1_ipmi_lanplus},
		anvil_node1_sn_ip		=>	$an->data->{cgi}{anvil_node1_sn_ip},
		anvil_node1_sn_link1_mac	=>	$an->data->{cgi}{anvil_node1_sn_link1_mac},
		anvil_node1_sn_link2_mac	=>	$an->data->{cgi}{anvil_node1_sn_link2_mac},
		anvil_node1_ifn_ip		=>	$an->data->{cgi}{anvil_node1_ifn_ip},
		anvil_node1_ifn_link1_mac	=>	$an->data->{cgi}{anvil_node1_ifn_link1_mac},
		anvil_node1_ifn_link2_mac	=>	$an->data->{cgi}{anvil_node1_ifn_link2_mac},
		anvil_node1_pdu1_outlet		=>	$an->data->{cgi}{anvil_node1_pdu1_outlet},
		anvil_node1_pdu2_outlet		=>	$an->data->{cgi}{anvil_node1_pdu2_outlet},
		anvil_node1_pdu3_outlet		=>	$an->data->{cgi}{anvil_node1_pdu3_outlet},
		anvil_node1_pdu4_outlet		=>	$an->data->{cgi}{anvil_node1_pdu4_outlet},
		anvil_node2_name		=>	$an->data->{cgi}{anvil_node2_name},
		anvil_node2_bcn_ip		=>	$an->data->{cgi}{anvil_node2_bcn_ip},
		anvil_node2_bcn_link1_mac	=>	$an->data->{cgi}{anvil_node2_bcn_link1_mac},
		anvil_node2_bcn_link2_mac	=>	$an->data->{cgi}{anvil_node2_bcn_link2_mac},
		anvil_node2_ipmi_ip		=>	$an->data->{cgi}{anvil_node2_ipmi_ip},
		anvil_node2_ipmi_user		=>	$an->data->{cgi}{anvil_node2_ipmi_user},
		anvil_node2_ipmi_lanplus	=>	$an->data->{cgi}{anvil_node2_ipmi_lanplus},
		anvil_node2_sn_ip		=>	$an->data->{cgi}{anvil_node2_sn_ip},
		anvil_node2_sn_link1_mac	=>	$an->data->{cgi}{anvil_node2_sn_link1_mac},
		anvil_node2_sn_link2_mac	=>	$an->data->{cgi}{anvil_node2_sn_link2_mac},
		anvil_node2_ifn_ip		=>	$an->data->{cgi}{anvil_node2_ifn_ip},
		anvil_node2_ifn_link1_mac	=>	$an->data->{cgi}{anvil_node2_ifn_link1_mac},
		anvil_node2_ifn_link2_mac	=>	$an->data->{cgi}{anvil_node2_ifn_link2_mac},
		anvil_node2_pdu1_outlet		=>	$an->data->{cgi}{anvil_node2_pdu1_outlet},
		anvil_node2_pdu2_outlet		=>	$an->data->{cgi}{anvil_node2_pdu2_outlet},
		anvil_node2_pdu3_outlet		=>	$an->data->{cgi}{anvil_node2_pdu3_outlet},
		anvil_node2_pdu4_outlet		=>	$an->data->{cgi}{anvil_node2_pdu4_outlet},
		anvil_ifn_gateway		=>	$an->data->{cgi}{anvil_ifn_gateway},
		anvil_dns1			=>	$an->data->{cgi}{anvil_dns1},
		anvil_dns2			=>	$an->data->{cgi}{anvil_dns2},
		anvil_ntp1			=>	$an->data->{cgi}{anvil_ntp1},
		anvil_ntp2			=>	$an->data->{cgi}{anvil_ntp2},
		anvil_ups1_name			=>	$an->data->{cgi}{anvil_ups1_name},
		anvil_ups1_ip			=>	$an->data->{cgi}{anvil_ups1_ip},
		anvil_ups2_name			=>	$an->data->{cgi}{anvil_ups2_name},
		anvil_ups2_ip			=>	$an->data->{cgi}{anvil_ups2_ip},
		anvil_pdu1_name			=>	$an->data->{cgi}{anvil_pdu1_name},
		anvil_pdu1_ip			=>	$an->data->{cgi}{anvil_pdu1_ip},
		anvil_pdu1_agent		=>	$an->data->{cgi}{anvil_pdu1_agent},
		anvil_pdu2_name			=>	$an->data->{cgi}{anvil_pdu2_name},
		anvil_pdu2_ip			=>	$an->data->{cgi}{anvil_pdu2_ip},
		anvil_pdu2_agent		=>	$an->data->{cgi}{anvil_pdu2_agent},
		anvil_pdu3_name			=>	$an->data->{cgi}{anvil_pdu3_name},
		anvil_pdu3_ip			=>	$an->data->{cgi}{anvil_pdu3_ip},
		anvil_pdu3_agent		=>	$an->data->{cgi}{anvil_pdu3_agent},
		anvil_pdu4_name			=>	$an->data->{cgi}{anvil_pdu4_name},
		anvil_pdu4_ip			=>	$an->data->{cgi}{anvil_pdu4_ip},
		anvil_pdu4_agent		=>	$an->data->{cgi}{anvil_pdu4_agent},
		anvil_switch1_name		=>	$an->data->{cgi}{anvil_switch1_name},
		anvil_switch1_ip		=>	$an->data->{cgi}{anvil_switch1_ip},
		anvil_switch2_name		=>	$an->data->{cgi}{anvil_switch2_name},
		anvil_switch2_ip		=>	$an->data->{cgi}{anvil_switch2_ip},
		anvil_striker1_name		=>	$an->data->{cgi}{anvil_striker1_name},
		anvil_striker1_bcn_ip		=>	$an->data->{cgi}{anvil_striker1_bcn_ip},
		anvil_striker1_ifn_ip		=>	$an->data->{cgi}{anvil_striker1_ifn_ip},
		anvil_striker2_name		=>	$an->data->{cgi}{anvil_striker2_name},
		anvil_striker2_bcn_ip		=>	$an->data->{cgi}{anvil_striker2_bcn_ip},
		anvil_striker2_ifn_ip		=>	$an->data->{cgi}{anvil_striker2_ifn_ip},
		anvil_repositories		=>	$an->data->{cgi}{anvil_repositories},
		anvil_mtu_size			=>	$an->data->{cgi}{anvil_mtu_size},
		say_anvil_repositories		=>	$say_repos,
		'anvil_drbd_disk_disk-barrier'	=>	$an->data->{cgi}{'anvil_drbd_disk_disk-barrier'},
		'anvil_drbd_disk_disk-flushes'	=>	$an->data->{cgi}{'anvil_drbd_disk_disk-flushes'},
		'anvil_drbd_disk_md-flushes'	=>	$an->data->{cgi}{'anvil_drbd_disk_md-flushes'},
		'anvil_drbd_disk_c-plan-ahead'	=>	$an->data->{cgi}{'anvil_drbd_disk_c-plan-ahead'},
		'anvil_drbd_disk_c-max-rate'	=>	$an->data->{cgi}{'anvil_drbd_disk_c-max-rate'},
		'anvil_drbd_disk_c-min-rate'	=>	$an->data->{cgi}{'anvil_drbd_disk_c-min-rate'},
		'anvil_drbd_disk_c-fill-target'	=>	$an->data->{cgi}{'anvil_drbd_disk_c-fill-target'},
		'anvil_drbd_options_cpu-mask'	=>	$an->data->{cgi}{'anvil_drbd_options_cpu-mask'},
		'anvil_drbd_net_max-buffers'	=>	$an->data->{cgi}{'anvil_drbd_net_max-buffers'},
		'anvil_drbd_net_sndbuf-size'	=>	$an->data->{cgi}{'anvil_drbd_net_sndbuf-size'},
		'anvil_drbd_net_rcvbuf-size'	=>	$an->data->{cgi}{'anvil_drbd_net_rcvbuf-size'},
		manifest_uuid			=>	$an->data->{cgi}{manifest_uuid},
	}});
	
	return(0);
}

# This summarizes the install plan and gives the use a chance to tweak it or re-run the cable mapping.
sub summarize_build_plan
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "summarize_build_plan" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1                = $an->data->{sys}{anvil}{node1}{name};
	my $node2                = $an->data->{sys}{anvil}{node2}{name};
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
		# See if it has been registered already.
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
		# See if it has been registered already.
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
		form_file			=>	"/cgi-bin/configure",
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
		media_library_size		=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_media_library_byte_size}}),
		pool1_size			=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool1_byte_size}}),
		pool2_size			=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_pool2_byte_size}}),
		partition1_size			=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_partition_1_byte_size}}),
		partition2_size			=>	$an->Readable->bytes_to_hr({'bytes' => $an->data->{cgi}{anvil_storage_partition_2_byte_size}}),
		edit_manifest_url		=>	"?task=manifests&manifest_uuid=".$an->data->{cgi}{manifest_uuid},
		remap_network_url		=>	$an->data->{sys}{cgi_string}."&remap_network=true",
		anvil_node1_current_ip		=>	$an->data->{sys}{anvil}{node1}{use_ip},
		anvil_node1_current_ip		=>	$an->data->{sys}{anvil}{node1}{use_ip},
		anvil_node1_current_password	=>	$an->data->{sys}{anvil}{node1}{password},
		anvil_node2_current_ip		=>	$an->data->{sys}{anvil}{node2}{use_ip},
		anvil_node2_current_password	=>	$an->data->{sys}{anvil}{node2}{password},
		config				=>	$an->data->{cgi}{config},
		confirm				=>	$an->data->{cgi}{confirm},
		'do'				=>	$an->data->{cgi}{'do'},
		run				=>	$an->data->{cgi}{run},
		task				=>	$an->data->{cgi}{task},
		manifest_uuid			=>	$an->data->{cgi}{manifest_uuid}, 
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

# This starts 'clvmd' on a node if it is not already running.
sub start_clvmd_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "start_clvmd_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return_code = 255;
	my $shell_call  = "
".$an->data->{path}{initd}."/clvmd status &>/dev/null; 
if [ \$? == 3 ];
then 
    ".$an->data->{path}{initd}."/clvmd start; ".$an->data->{path}{echo}." return_code:\$?;
else 
    ".$an->data->{path}{echo}." 'clvmd already running';
fi";
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
		
		if ($line =~ /^return_code:(\d+)/)
		{
			my $return_code = $1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code,
			}, file => $THIS_FILE, line => __LINE__});
			if ($return_code eq "0")
			{
				# clvmd was started
				$return_code = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				$return_code = 2;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		if ($line =~ /already running/i)
		{
			$return_code = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "clvmd was already running on", value1 => $node,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# 0 = Started
	# 1 = Already running
	# 2 = Failed
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This checks that the nodes are ready to start cman and, if so, does so.
sub start_cman
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "start_cman" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1             = $an->data->{sys}{anvil}{node1}{name};
	my $node2             = $an->data->{sys}{anvil}{node2}{name};
	my $node1_return_code = 0;
	my $node2_return_code = 0;
	
	# See if cman is running already.
	my ($node1_cman_state) = $an->InstallManifest->get_daemon_state({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
			daemon   => "cman", 
		});
	my ($node2_cman_state) = $an->InstallManifest->get_daemon_state({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
			daemon   => "cman",
		});
	# 1 == running, 0 == stopped.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_cman_state", value1 => $node1_cman_state,
		name2 => "node2_cman_state", value2 => $node2_cman_state,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If either node has servers but cman is stopped, bail out.
	if ((($an->data->{node}{node1}{has_servers}) && (not $node1_cman_state)) or 
	    (($an->data->{node}{node2}{has_servers}) && (not $node2_cman_state)))
	{
		# WHAT?
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
			row     => "#!string!row_0256!#",
			message => "#!string!explain_0239!#",
		}});
		return(0);
	}

	# First thing, make sure each node can talk to the other on the BCN.
	my ($node1_ping) = $an->Check->ping({
		ping		=>	$an->data->{cgi}{anvil_node2_bcn_ip}, 
		count		=>	3,
		target		=>	$an->data->{sys}{anvil}{node1}{use_ip},
		port		=>	$an->data->{sys}{anvil}{node1}{use_port}, 
		password	=>	$an->data->{sys}{anvil}{node1}{password},
	});
	my ($node2_ping) = $an->Check->ping({
		ping		=>	$an->data->{cgi}{anvil_node1_bcn_ip}, 
		count		=>	3,
		target		=>	$an->data->{sys}{anvil}{node2}{use_ip},
		port		=>	$an->data->{sys}{anvil}{node2}{use_port}, 
		password	=>	$an->data->{sys}{anvil}{node2}{password},
	});
	# 1 == Ping success
	# 0 == Ping failed
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_ping", value1 => $node1_ping,
		name2 => "node2_ping", value2 => $node2_ping,
	}, file => $THIS_FILE, line => __LINE__});
	
	# No sense proceeding if the nodes can't talk to each other.
	if ((not $node1_ping) or (not $node2_ping))
	{
		# Both can ping the other on their BCN, so we can try to start cman now.
		$node1_return_code = 1;
		$node2_return_code = 1;
	}
	if ((not $node1_cman_state) && (not $node2_cman_state))
	{
		# Start cman on both nodes at the same time.
		my $command  = $an->data->{path}{initd}."/cman start";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "command", value1 => $command,
		}, file => $THIS_FILE, line => __LINE__});
		
		$an->System->synchronous_command_run({
			command => $command, 
			delay   => 30,
		});
		
		# We sleep for a bit to give time for cman to be actually up. In rare cases, on slow 
		# hardware, cman will exit from being asked to start without yet being started.
		sleep 10;
		
		# Now see if that succeeded.
		$an->Log->entry({log_level => 2, message_key => "log_0110", file => $THIS_FILE, line => __LINE__});
		my ($node1_cman_state) = $an->InstallManifest->get_daemon_state({
				node     => $node1, 
				target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node1}{use_port}, 
				password => $an->data->{sys}{anvil}{node1}{password},
				daemon   => "cman", 
			});
		my ($node2_cman_state) = $an->InstallManifest->get_daemon_state({
				node     => $node2, 
				target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node2}{use_port}, 
				password => $an->data->{sys}{anvil}{node2}{password},
				daemon   => "cman",
			});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node1_cman_state", value1 => $node1_cman_state,
			name2 => "node2_cman_state", value2 => $node2_cman_state,
		}, file => $THIS_FILE, line => __LINE__});
		### NOTE: The returned value is NOT the RC of the status call. It is normalized by the 
		###       'get_daemon_state()' method.
		# 1 == running, 0 == stopped.
		
		# Node RCs;
		# 1 == Can't ping peer
		# 2 == Started 
		# 3 == Already running (not used anymore)
		# 4 == Failed
		if ((not $node1_cman_state) && (not $node2_cman_state))
		{
			# Well crap...
			$node1_return_code = 4;
			$node2_return_code = 4;
			$an->Log->entry({log_level => 2, message_key => "log_0114", file => $THIS_FILE, line => __LINE__});
		}
		elsif (not $node2_cman_state)
		{
			# Only node 1 started... node 2 was probably fenced.
			$node1_return_code = 2;
			$node2_return_code = 4;
			$an->Log->entry({log_level => 1, message_key => "log_0112", message_variables => {
				node1 => $an->data->{sys}{anvil}{node1}{use_ip}, 
				node2 => $an->data->{sys}{anvil}{node2}{use_ip}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (not $node1_cman_state)
		{
			# Only node 2 started... node 1 was probably fenced.
			$node1_return_code = 4;
			$node2_return_code = 2;
			$an->Log->entry({log_level => 1, message_key => "log_0113", message_variables => {
				node1 => $an->data->{sys}{anvil}{node1}{use_ip}, 
				node2 => $an->data->{sys}{anvil}{node2}{use_ip}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# \o/ - Successfully started cman on both nodes.
			$node1_return_code = 2;
			$node2_return_code = 2;
			$an->Log->entry({log_level => 1, message_key => "log_0111", file => $THIS_FILE, line => __LINE__});
		}
	}
	elsif (not $node1_cman_state)
	{
		# Node 2 is running, node 1 isn't, start it.
		$an->InstallManifest->start_cman_on_node({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		});
		my ($node1_cman_state) = $an->InstallManifest->get_daemon_state({
				node     => $node1, 
				target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node1}{use_port}, 
				password => $an->data->{sys}{anvil}{node1}{password},
				daemon   => "cman", 
			});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node1_cman_state", value1 => $node1_cman_state,
		}, file => $THIS_FILE, line => __LINE__});
		if ($node1_cman_state)
		{
			# Started!
			$node2_return_code = 2;
			$an->Log->entry({log_level => 2, message_key => "log_0115", message_variables => {
				node_number  => "1", 
				node_address => $an->data->{sys}{anvil}{node1}{use_ip}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Failed to start.
			$node1_return_code = 4;
			$an->Log->entry({log_level => 1, message_key => "log_0116", message_variables => {
				node_number  => "1", 
				node_address => $an->data->{sys}{anvil}{node1}{use_ip}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	elsif (not $node2_cman_state)
	{
		# Node 1 is running, node 2 isn't, start it.
		$an->InstallManifest->start_cman_on_node({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
		});
		my ($node2_cman_state) = $an->InstallManifest->get_daemon_state({
				node     => $node2, 
				target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node2}{use_port}, 
				password => $an->data->{sys}{anvil}{node2}{password},
				daemon   => "cman",
			});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node2_cman_state", value1 => $node2_cman_state,
		}, file => $THIS_FILE, line => __LINE__});
		if ($node2_cman_state)
		{
			# Started!
			$node2_return_code = 2;
			$an->Log->entry({log_level => 2, message_key => "log_0115", message_variables => {
				node_number  => "2", 
				node_address => $an->data->{sys}{anvil}{node2}{use_ip}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Failed to start.
			$node2_return_code = 4;
			$an->Log->entry({log_level => 1, message_key => "log_0116", message_variables => {
				node_number  => "2", 
				node_address => $an->data->{sys}{anvil}{node2}{use_ip}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	else
	{
		# Both are already running
		$node1_return_code = 3;
		$node2_return_code = 3;
		$an->Log->entry({log_level => 2, message_key => "log_0117", file => $THIS_FILE, line => __LINE__});
	}
	
	# Check fencing if cman is running
	my $node1_fence_ok       = 255;
	my $node1_return_message = "";
	my $node2_fence_ok       = 255;
	my $node2_return_message = "";
	if ((($node1_return_code eq "2") or ($node1_return_code eq "3")) && (($node2_return_code eq "2") or ($node2_return_code eq "3")))
	{
		($node1_fence_ok, $node1_return_message) = $an->InstallManifest->check_fencing_on_node({
				node     => $node1,
				target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node1}{use_port}, 
				password => $an->data->{sys}{anvil}{node1}{password},
			});
		($node2_fence_ok, $node2_return_message) = $an->InstallManifest->check_fencing_on_node({
				node     => $node2,
				target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node2}{use_port}, 
				password => $an->data->{sys}{anvil}{node2}{password},
			});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "node1_fence_ok",       value1 => $node1_fence_ok,
			name2 => "node1_return_message", value2 => $node1_return_message,
			name3 => "node2_fence_ok",       value3 => $node2_fence_ok,
			name4 => "node2_return_message", value4 => $node2_return_message,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# 1 = Can't ping peer on BCN
	# 2 = Started
	# 3 = Already running
	# 4 = Failed to start
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0014!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0014!#";
	# Node 1
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif ($node1_return_code eq "1")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0077!#",
		$ok            = 0;
	}
	elsif ($node1_return_code eq "4")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0018!#",
		$ok            = 0;
	}
	elsif (not $node1_fence_ok)
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = $an->String->get({key => "state_0082", variables => { message => $node1_return_message }});
		$ok            = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "ok", value1 => $ok,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($node1_return_code eq "3")
	{
		$node1_message = "#!string!state_0078!#",
	}
	
	# Node 2
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif ($node2_return_code eq "1")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0077!#",
		$ok            = 0;
	}
	elsif ($node2_return_code eq "4")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0018!#",
		$ok            = 0;
	}
	elsif (not $node2_fence_ok)
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = $an->String->get({key => "state_0082", variables => { message => $node2_return_message }});
		$ok            = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "ok", value1 => $ok,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($node2_return_code eq "3")
	{
		$node2_message = "#!string!state_0078!#",
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0256!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# Start cluster communications on a single node.
sub start_cman_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "start_cman_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $shell_call = $an->data->{path}{initd}."/cman start";
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
	
	return(0)
}

### TODO: Don't stop until both nodes show their storage service as 'started'
# This looks at the disk states for r0 and if one node is Inconsistent, it is stopped first. Otherwise, we'll
# stop node 1, then node 2.
sub stop_drbd
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "stop_drbd" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# get the current disk states from node 1's perspective. We'll need to stop the Inconsistent node 
	# first, if a sync is underway.
	my $node1      = $an->data->{sys}{anvil}{node1}{name};
	my $node2      = $an->data->{sys}{anvil}{node2}{name};
	my $stop_first = "node1";
	my $target     = $an->data->{sys}{anvil}{node1}{use_ip};
	my $port       = $an->data->{sys}{anvil}{node1}{use_port};
	my $password   = $an->data->{sys}{anvil}{node1}{password};
	my $shell_call = $an->data->{path}{cat}." ".$an->data->{path}{proc_drbd};
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^0: /)
		{
			my $connected_state = ($line =~ /cs:(.*?)\s/)[0];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "connected_state", value1 => $connected_state, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($connected_state =~ /SyncSource/i)
			{
				# Stop node 2 first
				$stop_first = "node2";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "stop_first", value1 => $stop_first, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	my $ok = 1;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "stop_first", value1 => $stop_first, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($stop_first eq "node2")
	{
		# Stop 2 -> 1
		my $drbd_node1_ok = 2;
		my $drbd_node2_ok = 2;
		($drbd_node2_ok) = $an->InstallManifest->stop_drbd_on_node({
				node     => $node2, 
				target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node2}{use_port}, 
				password => $an->data->{sys}{anvil}{node2}{password},
			}) if not $an->data->{node}{node2}{has_servers};
		($drbd_node1_ok) = $an->InstallManifest->stop_drbd_on_node({
				node     => $node1, 
				target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node1}{use_port}, 
				password => $an->data->{sys}{anvil}{node1}{password},
			}) if not $an->data->{node}{node1}{has_servers};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "drbd_node1_ok", value1 => $drbd_node1_ok, 
			name2 => "drbd_node2_ok", value2 => $drbd_node2_ok, 
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $drbd_node1_ok) or (not $drbd_node2_ok))
		{
			$ok = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "ok", value1 => $ok, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	else
	{
		# Stop 1 -> 2
		my $drbd_node1_ok = 2;
		my $drbd_node2_ok = 2;
		($drbd_node1_ok) = $an->InstallManifest->stop_drbd_on_node({
				node     => $node1, 
				target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node1}{use_port}, 
				password => $an->data->{sys}{anvil}{node1}{password},
			}) if not $an->data->{node}{node1}{has_servers};
		($drbd_node2_ok) = $an->InstallManifest->stop_drbd_on_node({
				node     => $node2, 
				target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
				port     => $an->data->{sys}{anvil}{node2}{use_port}, 
				password => $an->data->{sys}{anvil}{node2}{password},
			}) if not $an->data->{node}{node2}{has_servers};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "drbd_node1_ok", value1 => $drbd_node1_ok, 
			name2 => "drbd_node2_ok", value2 => $drbd_node2_ok, 
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $drbd_node1_ok) or (not $drbd_node2_ok))
		{
			$ok = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "ok", value1 => $ok, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok, 
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This stops DRBD by first demoting to Secondary, then 'down'ing the resource and finally stopping the DRBD 
# daemon itself.
sub stop_drbd_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "stop_drbd_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Find the up resources
	my $stop       = {};
	my $shell_call = $an->data->{path}{cat}." ".$an->data->{path}{proc_drbd};
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^(\d+): /)
		{
			my $minor    = $1;
			my $resource = "r".$minor;
			$stop->{$resource} = 1;
		}
	}
	$return = "";
	
	# Demote.
	foreach my $resource (sort {$a cmp $b} keys %{$stop})
	{
		my $shell_call  = $an->data->{path}{drbdadm}." secondary $resource; ".$an->data->{path}{echo}." return_code:\$?";
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
	
	my $ok = 1;
	
	# Verify they're all Secondary
	$shell_call = $an->data->{path}{cat}." ".$an->data->{path}{proc_drbd};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
		shell_call	=>	$shell_call,
	});
	foreach my $line (@{$return})
	{
		$line =~ s/^\s+//;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if (($line =~ /^(\d+): /) && ($line =~ /ro:Primary/i))
		{
			$ok = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "ok", value1 => $ok, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If we're OK, stop
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($ok)
	{
		# Down
		foreach my $resource (sort {$a cmp $b} keys %{$stop})
		{
			my $shell_call  = $an->data->{path}{drbdadm}." down $resource; ".$an->data->{path}{echo}." return_code:\$?";
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
		
		# Stop
		foreach my $resource (sort {$a cmp $b} keys %{$stop})
		{
			my $shell_call  = $an->data->{path}{initd}."/drbd stop; ".$an->data->{path}{echo}." return_code:\$?";
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
	}
	
	return($ok);
}

# This stops the named service on the named node.
sub stop_service_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "stop_service_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $service  = $parameter->{service}  ? $parameter->{service}  : "";
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "service", value1 => $service, 
		name2 => "node",    value2 => $node, 
		name3 => "target",  value3 => $target, 
		name4 => "port",    value4 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return_code = 127;
	my $shell_call  = $an->data->{path}{initd}."/".$service." stop; ".$an->data->{path}{echo}." return_code:\$?";
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
		
		if ($line =~ /^return_code:(\d+)/)
		{
			$return_code = $1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "return_code", value1 => $return_code, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code, 
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This pings a website to check for an internet connection. Will clean up routes that conflict with the 
# default one as well.
sub test_internet_connection
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "test_internet_connection" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Default to no connection
	$an->data->{node}{$node}{internet} = 0;
	
	### Before we do anything complicated, see if we can ping 8.8.8.8.
	# 1 == pingable, 0 == failed.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target", value1 => $target,
		name2 => "port",   value2 => $port,
	}, file => $THIS_FILE, line => __LINE__});
	my ($ping) = $an->Check->ping({
		ping		=>	"8.8.8.8", 
		count		=>	3,
		target		=>	$target,
		port		=>	$port, 
		password	=>	$password,
	});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ping", value1 => $ping,
	}, file => $THIS_FILE, line => __LINE__});
	my $ok = 0;
	if ($ping)
	{
		$ok                                = 1;
		$an->data->{node}{$node}{internet} = 1;
	}
	else
	{
		### No connection, lets see if we need to clean up routes.
		# After installing, sometimes/often the system will come up with multiple interfaces on the 
		# same subnet, causing default route problems. So the first thing to do is look for the 
		# interface the IP we're using to connect is on, see its subnet and see if anything else is 
		# on the same subnet. If so, delete the other interface(s) from the route table.
		my $dg_device  = "";
		my $shell_call = $an->data->{path}{route}." -n";
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
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /UG/)
			{
				$dg_device = ($line =~ /.* (.*?)$/)[0];
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "dg_device", value1 => $dg_device,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /^(\d+\.\d+\.\d+\.\d+) .*? (\d+\.\d+\.\d+\.\d+) .*? \d+ \d+ \d+ (.*?)$/)
			{
				my $network   = $1;
				my $netmask   = $2;
				my $interface = $3;
				$an->data->{conf}{node}{$node}{routes}{interface}{$interface} = "$network/$netmask";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "conf::node::${node}::routes::interface::${interface}", value1 => $an->data->{conf}{node}{$node}{routes}{interface}{$interface},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		# Now look for offending devices 
		$an->Log->entry({log_level => 2, message_key => "log_0198", message_variables => { node => $node }, file => $THIS_FILE, line => __LINE__});
		
		my ($dg_network, $dg_netmask) = ($an->data->{conf}{node}{$node}{routes}{interface}{$dg_device} =~ /^(\d+\.\d+\.\d+\.\d+)\/(\d+\.\d+\.\d+\.\d+)/);
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "dg_device",  value1 => $dg_device,
			name2 => "dg_network", value2 => $dg_network,
			name3 => "dg_netmask", value3 => $dg_netmask,
		}, file => $THIS_FILE, line => __LINE__});
		
		foreach my $interface (sort {$a cmp $b} keys %{$an->data->{conf}{node}{$node}{routes}{interface}})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "interface", value1 => $interface,
				name2 => "dg_device", value2 => $dg_device,
			}, file => $THIS_FILE, line => __LINE__});
			next if $interface eq $dg_device;
			
			my ($network, $netmask) = ($an->data->{conf}{node}{$node}{routes}{interface}{$interface} =~ /^(\d+\.\d+\.\d+\.\d+)\/(\d+\.\d+\.\d+\.\d+)/);
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "conf::node::${node}::routes::interface::${interface}", value1 => $an->data->{conf}{node}{$node}{routes}{interface}{$interface},
				name2 => "network",                                              value2 => $network,
				name3 => "netmask",                                              value3 => $netmask,
			}, file => $THIS_FILE, line => __LINE__});
			if (($dg_network eq $network) && ($dg_netmask eq $netmask))
			{
				# Conflicting route
				$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
					name1 => "interface", value1 => $interface,
					name2 => "network",   value2 => $network,
					name3 => "netmask",   value3 => $netmask,
				}, file => $THIS_FILE, line => __LINE__});
				
				my $shell_call = $an->data->{path}{route}." del -net $network netmask $netmask dev $interface; ".$an->data->{path}{echo}." return_code:\$?";
				my $password   = $an->data->{sys}{root_password};
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
					
					if ($line =~ /^return_code:(\d+)/)
					{
						my $return_code = $1;
						if ($return_code eq "0")
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
								return_code => $return_code, 
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
		
		### Try pinging again...
		# 1 == pingable, 0 == failed.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "target", value1 => $target,
			name2 => "port",   value2 => $port,
		}, file => $THIS_FILE, line => __LINE__});
		my ($ping) = $an->Check->ping({
			ping		=>	"8.8.8.8", 
			count		=>	3,
			target		=>	$target,
			port		=>	$port, 
			password	=>	$password,
		});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "ping", value1 => $ping,
		}, file => $THIS_FILE, line => __LINE__});
		if ($ping)
		{
			$ok                                = 1;
			$an->data->{node}{$node}{internet} = 1;
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
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
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "update_install_manifest" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1           = $an->data->{sys}{anvil}{node1}{name};
	my $node1_bcn_link1 = $an->data->{conf}{node}{$node1}{set_nic}{bcn_link1};
	my $node1_bcn_link2 = $an->data->{conf}{node}{$node1}{set_nic}{bcn_link2};
	my $node1_sn_link1  = $an->data->{conf}{node}{$node1}{set_nic}{sn_link1};
	my $node1_sn_link2  = $an->data->{conf}{node}{$node1}{set_nic}{sn_link2};
	my $node1_ifn_link1 = $an->data->{conf}{node}{$node1}{set_nic}{ifn_link1};
	my $node1_ifn_link2 = $an->data->{conf}{node}{$node1}{set_nic}{ifn_link2};
	my $node2           = $an->data->{sys}{anvil}{node2}{name};
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
			if (($this_node =~ /node01/) or
			    ($this_node =~ /node1/)  or
			    ($this_node =~ /n01/)    or
			    ($this_node =~ /n1/))
			{
				$in_node1 = 1;
				$in_node2 = 0;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "in_node1", value1 => $in_node1,
					name2 => "in_node2", value2 => $in_node2,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif (($this_node =~ /node02/) or
			       ($this_node =~ /node2/)  or
			       ($this_node =~ /n02/)    or
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

# This calls the yum update and flags the node for a reboot if the kernel is updated.
sub update_target_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "update_target_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Skip if the user has decided not to run OS updates.
	my $return = 1;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::update_os", value1 => $an->data->{sys}{update_os}, 
	}, file => $THIS_FILE, line => __LINE__});
	if ($an->data->{sys}{update_os})
	{
		# We now do two update calls... First with priority on the striker dashboards, then again 
		# without. This ensures any locally available updates are downloaded and installed before
		# burning data updating from external repos.
		$an->InstallManifest->_do_os_update({
				node     => $node, 
				target   => $target, 
				port     => $port, 
				password => $password,
			});
		$return = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "return", value1 => $return, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# Remove the priority= from the nodes. We don't care about the output.
	$an->InstallManifest->remove_priority_from_node({
			node     => $node, 
			target   => $target, 
			port     => $port, 
			password => $password,
		});
	
	if ($an->data->{sys}{update_os})
	{
		# Call the update again. This time, external updates will be installed.
		$an->InstallManifest->_do_os_update({
				node     => $node, 
				target   => $target, 
				port     => $port, 
				password => $password,
			});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return", value1 => $return, 
	}, file => $THIS_FILE, line => __LINE__});
	return($return);
}

# This calls yum update against both nodes.
sub update_nodes
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "update_nodes" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# This could take a while
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-be-patient-message", replace => { message => "#!string!explain_0130!#" }});
	
	my $node1             = $an->data->{sys}{anvil}{node1}{name};
	my $node2             = $an->data->{sys}{anvil}{node2}{name};
	my $node1_return_code = 0;
	my $node2_return_code = 0;
	
	# The OS update is good, but not fatal if it fails.
	$an->data->{node}{$node2}{os_updated} = 0;
	$an->data->{node}{$node1}{os_updated} = 0;
	   
	($node1_return_code) = $an->InstallManifest->update_target_node({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		}) if not $an->data->{node}{node1}{has_servers};
	($node2_return_code) = $an->InstallManifest->update_target_node({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
		}) if not $an->data->{node}{node2}{has_servers};
	# 0 = update attempted
	# 1 = OS updates disabled in manifest
	
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0026!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0026!#";
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	elsif ($node1_return_code)
	{
		$node1_message = "#!string!state_0060!#",
	}
	elsif (not $an->data->{node}{$node1}{os_updated})
	{
		$node1_message = "#!string!state_0027!#",
	}
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	elsif ($node2_return_code)
	{
		$node2_message = "#!string!state_0060!#",
	}
	elsif (not $an->data->{node}{$node2}{os_updated})
	{
		$node2_message = "#!string!state_0027!#",
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0227!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	return(0);
}

# This connects to node 1 and checks to ensure both resource are in the 'Connected' state.
sub verify_drbd_resources_are_connected
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "verify_drbd_resources_are_connected" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Give the previous start call a few seconds to take effect.
	sleep 5;
	
	# Ok, go.
	my $return_code  = 0;
	my $r0_connected = 0;
	my $r1_connected = 0;
	my $shell_call   = $an->data->{path}{cat}." ".$an->data->{path}{proc_drbd};
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
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^0: /)
		{
			my $connected_state = ($line =~ /cs:(.*?)\s/)[0];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "connected_state", value1 => $connected_state, 
			}, file => $THIS_FILE, line => __LINE__});
			if (($connected_state =~ /Connected/i) or ($connected_state =~ /Sync/i))
			{
				# Connected
				$r0_connected = 1;
				$an->Log->entry({log_level => 2, message_key => "log_0081", message_variables => { resource => "r0" }, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Failed to connect.
				$an->Log->entry({log_level => 1, message_key => "log_0082", message_variables => {
					resource         => "r0", 
					connection_state => $connected_state, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		if ($line =~ /^1: /)
		{
			my $connected_state = ($line =~ /cs:(.*?)\s/)[0];
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "connected_state", value1 => $connected_state, 
			}, file => $THIS_FILE, line => __LINE__});
			if (($connected_state =~ /Connected/i) or ($connected_state =~ /Sync/i))
			{
				# Connected
				$r1_connected = 1;
				$an->Log->entry({log_level => 2, message_key => "log_0081", message_variables => { resource => "r1" }, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Failed to connect.
				$an->Log->entry({log_level => 1, message_key => "log_0082", message_variables => {
					resource         => "r1", 
					connection_state => $connected_state, 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "r0_connected", value1 => $r0_connected,
		name2 => "r1_connected", value2 => $r1_connected,
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $r0_connected) or (($an->data->{cgi}{anvil_storage_pool2_byte_size}) && (not $r1_connected)))
	{
		# Something isn't connected.
		$return_code = 1;
		$an->Log->entry({log_level => 1, message_key => "log_0083", file => $THIS_FILE, line => __LINE__});
	}
	
	# 0 == Both resources found, safe to proceed
	# 1 == One or both of the resources not found
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This pings alteeve.com to check for internet access.
sub verify_internet_access
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "verify_internet_access" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# If the user knows they will never be online, they may have set to hide the Internet check. In this
	# case, don't waste time checking.
	my $node1 = $an->data->{sys}{anvil}{node1}{name};
	my $node2 = $an->data->{sys}{anvil}{node2}{name};
	if (not $an->data->{sys}{install_manifest}{show}{internet_check})
	{
		# User has disabled checking for an internet connection, mark that there is no connection.
		$an->Log->entry({log_level => 2, message_key => "log_0196", file => $THIS_FILE, line => __LINE__});
		$an->data->{node}{$node1}{internet} = 0;
		$an->data->{node}{$node2}{internet} = 0;
		return(0);
	}
	
	my ($node1_online) = $an->InstallManifest->test_internet_connection({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password}
		});
	my ($node2_online) = $an->InstallManifest->test_internet_connection({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password}
		});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_online", value1 => $node1_online,
		name2 => "node2_online", value2 => $node2_online,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If the node is not online, we'll call yum with the switches to  disable all but our local repos.
	if ((not $node1_online) or (not $node2_online))
	{
		# No internet, restrict access to local only.
		$an->data->{sys}{yum_switches} = "-y --disablerepo=* --enablerepo=*striker*";
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
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "verify_os" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ok    = 1;
	my $node1 = $an->data->{sys}{anvil}{node1}{name};
	my $node2 = $an->data->{sys}{anvil}{node2}{name};
	my ($node1_major_version, $node1_minor_version) = $an->InstallManifest->get_node_os_version({
			node     => $node1,
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_major_version", value1 => $node1_major_version,
		name2 => "node1_minor_version", value2 => $node1_minor_version,
	}, file => $THIS_FILE, line => __LINE__});
	my ($node2_major_version, $node2_minor_version) = $an->InstallManifest->get_node_os_version({
			node     => $node2,
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port},
			password => $an->data->{sys}{anvil}{node2}{password},
		});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node2_major_version", value1 => $node2_major_version,
		name2 => "node2_minor_version", value2 => $node2_minor_version,
	}, file => $THIS_FILE, line => __LINE__});
	$node1_major_version = 0 if not defined $node1_major_version;
	$node1_minor_version = 0 if not defined $node1_minor_version;
	$node2_major_version = 0 if not defined $node2_major_version;
	$node2_minor_version = 0 if not defined $node2_minor_version;
	
	my $say_node1_os = $an->data->{node}{$node1}{os}{brand} =~ /Red Hat Enterprise Linux Server/ ? "RHEL" : $an->data->{node}{$node1}{os}{brand};
	my $say_node2_os = $an->data->{node}{$node2}{os}{brand} =~ /Red Hat Enterprise Linux Server/ ? "RHEL" : $an->data->{node}{$node2}{os}{brand};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "say_node1_os", value1 => $say_node1_os,
		name2 => "say_node2_os", value2 => $say_node2_os,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "$say_node1_os ".$an->data->{node}{$node1}{os}{version};
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "$say_node2_os ".$an->data->{node}{$node2}{os}{version};
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
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "verify_perl_is_installed" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1      = $an->data->{sys}{anvil}{node1}{name};
	my $node2      = $an->data->{sys}{anvil}{node2}{name};
	my ($node1_ok) = $an->InstallManifest->verify_perl_is_installed_on_node({
			node     => $node1, 
			target   => $an->data->{sys}{anvil}{node1}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node1}{use_port}, 
			password => $an->data->{sys}{anvil}{node1}{password},
		});
	my ($node2_ok) = $an->InstallManifest->verify_perl_is_installed_on_node({
			node     => $node2, 
			target   => $an->data->{sys}{anvil}{node2}{use_ip}, 
			port     => $an->data->{sys}{anvil}{node2}{use_port}, 
			password => $an->data->{sys}{anvil}{node2}{password},
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
	
	# Now only print this if there was a problem.
	if (not $ok)
	{
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
			row		=>	"#!string!row_0243!#",
			node1_class	=>	$node1_class,
			node1_message	=>	$node1_message,
			node2_class	=>	$node2_class,
			node2_message	=>	$node2_message,
		}});
		
		print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-warning", replace => { 
			message	=>	"#!string!message_0386!#",
			row	=>	"#!string!state_0037!#",
		}});
	}
	
	return($ok);
}

# This will check to see if perl is installed and, if it is not, it will try to install it.
sub verify_perl_is_installed_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "verify_perl_is_installed_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
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

# This watches clustat for up to 300 seconds for the storage and libvirt services to start (or fail).
sub watch_clustat
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "watch_clustat" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If a service comes up 'failed', we will try to restart it because, if it failed in a previous run,
	# it will stay failed until it is disabled so this provides something of an ability to self-heal.
	my $restarted_n01_storage  = 0;
	my $restarted_n02_storage  = 0;
	my $restarted_n01_libvirtd = 0;
	my $restarted_n02_libvirtd = 0;
	
	# These will be set when parsing clustat output.
	my $services_seen = 0;
	my $n01_storage   = "";
	my $n02_storage   = "";
	my $n01_libvirtd  = "";
	my $n02_libvirtd  = "";
	my $abort_time    = time + $an->data->{sys}{clustat_timeout};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "time",       value1 => time,
		name2 => "abort_time", value2 => $abort_time,
	}, file => $THIS_FILE, line => __LINE__});
	until ($services_seen)
	{
		# Call and parse 'clustat'
		my $shell_call = $an->data->{path}{clustat}." | ".$an->data->{path}{'grep'}." service";
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
			
			if ($line =~ /service:(.*?) .*? (.*)?/)
			{
				my $service = $1;
				my $state   = $2;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "service", value1 => $service, 
					name2 => "state",   value2 => $state, 
				}, file => $THIS_FILE, line => __LINE__});
				
				# If it is not started, disabled or failed, I am not interested in it.
				next if (($state ne "failed") && ($state ne "started") && ($state ne "stopped"));
				if (($state eq "stopped") or ($state eq "disabled"))
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "service", value1 => $service, 
						name2 => "node",    value2 => $node, 
					}, file => $THIS_FILE, line => __LINE__});
					$an->InstallManifest->restart_rgmanager_service({
						node     => $node, 
						target   => $target, 
						port     => $port, 
						password => $password,
						service  => $service,
						'do'     => "start",
					});
				}
				elsif ($service eq "libvirtd_n01")
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "service",                value1 => $service,
						name2 => "state",                  value2 => $state,
						name3 => "restarted_n01_libvirtd", value3 => $restarted_n01_libvirtd,
					}, file => $THIS_FILE, line => __LINE__});
					if (($state eq "failed") && (not $restarted_n01_libvirtd))
					{
						$restarted_n01_libvirtd = 1;
						$an->InstallManifest->restart_rgmanager_service({
							node     => $node, 
							target   => $target, 
							port     => $port, 
							password => $password,
							service  => $service,
							'do'     => "restart",
						});
					}
					elsif (($state eq "disabled") && (not $restarted_n01_libvirtd))
					{
						$restarted_n01_libvirtd = 1;
						$an->InstallManifest->restart_rgmanager_service({
							node     => $node, 
							target   => $target, 
							port     => $port, 
							password => $password,
							service  => $service,
							'do'     => "start",
						});
					}
					elsif (($state eq "started") or ($restarted_n01_libvirtd))
					{
						$n01_libvirtd = $state;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "n01_libvirtd", value1 => $n01_libvirtd, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($service eq "libvirtd_n02")
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "service",                value1 => $service,
						name2 => "state",                  value2 => $state,
						name3 => "restarted_n02_libvirtd", value3 => $restarted_n02_libvirtd,
					}, file => $THIS_FILE, line => __LINE__});
					if (($state eq "failed") && (not $restarted_n02_libvirtd))
					{
						$restarted_n02_libvirtd = 1;
						$an->InstallManifest->restart_rgmanager_service({
							node     => $node, 
							target   => $target, 
							port     => $port, 
							password => $password,
							service  => $service,
							'do'     => "restart",
						});
					}
					elsif (($state eq "disabled") && (not $restarted_n02_libvirtd))
					{
						$restarted_n02_libvirtd = 1;
						$an->InstallManifest->restart_rgmanager_service({
							node     => $node, 
							target   => $target, 
							port     => $port, 
							password => $password,
							service  => $service,
							'do'     => "start",
						});
					}
					elsif (($state eq "started") or ($restarted_n02_libvirtd))
					{
						$n02_libvirtd = $state;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "n02_libvirtd", value1 => $n02_libvirtd, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($service eq "storage_n01")
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "service",               value1 => $service,
						name2 => "state",                 value2 => $state,
						name3 => "restarted_n01_storage", value3 => $restarted_n01_storage,
					}, file => $THIS_FILE, line => __LINE__});
					if (($state eq "failed") && (not $restarted_n01_storage))
					{
						$restarted_n01_storage = 1;
						$an->InstallManifest->restart_rgmanager_service({
							node     => $node, 
							target   => $target, 
							port     => $port, 
							password => $password,
							service  => $service,
							'do'     => "restart",
						});
					}
					elsif (($state eq "disabled") && (not $restarted_n01_storage))
					{
						$restarted_n01_storage = 1;
						$an->InstallManifest->restart_rgmanager_service({
							node     => $node, 
							target   => $target, 
							port     => $port, 
							password => $password,
							service  => $service,
							'do'     => "start",
						});
					}
					elsif (($state eq "started") or ($restarted_n01_storage))
					{
						$n01_storage = $state;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "n01_storage", value1 => $n01_storage, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				elsif ($service eq "storage_n02")
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "service",               value1 => $service,
						name2 => "state",                 value2 => $state,
						name3 => "restarted_n02_storage", value3 => $restarted_n02_storage,
					}, file => $THIS_FILE, line => __LINE__});
					if (($state eq "failed") && (not $restarted_n02_storage))
					{
						$restarted_n02_storage = 1;
						$an->InstallManifest->restart_rgmanager_service({
							node     => $node, 
							target   => $target, 
							port     => $port, 
							password => $password,
							service  => $service,
							'do'     => "restart",
						});
					}
					elsif (($state eq "disabled") && (not $restarted_n02_storage))
					{
						$restarted_n02_storage = 1;
						$an->InstallManifest->restart_rgmanager_service({
							node     => $node, 
							target   => $target, 
							port     => $port, 
							password => $password,
							service  => $service,
							'do'     => "start",
						});
					}
					elsif (($state eq "started") or ($restarted_n02_storage))
					{
						$n02_storage = $state;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "n02_storage", value1 => $n02_storage, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
			}
		}
		
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "n01_libvirtd", value1 => $n01_libvirtd, 
			name2 => "n02_libvirtd", value2 => $n02_libvirtd, 
			name3 => "n01_storage",  value3 => $n01_storage, 
			name4 => "n02_storage",  value4 => $n02_storage, 
		}, file => $THIS_FILE, line => __LINE__});
		if (($n01_libvirtd) && ($n02_libvirtd) && ($n01_storage) && ($n02_storage))
		{
			# Seen them all, exit and then analyze
			$services_seen = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "services_seen", value1 => $services_seen,
			}, file => $THIS_FILE, line => __LINE__});
			last;
		}
		
		if (time > $abort_time)
		{
			# Timed out.
			$an->Log->entry({log_level => 3, message_key => "log_0043", file => $THIS_FILE, line => __LINE__});
			last;
		}
		sleep 2;
	}
	
	my $ok = 1;
	### Report on the storage as one line and then libvirtd as a second.
	# Storage first
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0014!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0014!#";
	# Node 1
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	if ($services_seen)
	{
		if (($n01_storage =~ /failed/) or ($n01_storage =~ /disabled/))
		{
			$node1_class   = "highlight_warning_bold";
			$node1_message = "#!string!state_0018!#";
			$ok            = 0;
		}
		if (($n02_storage =~ /failed/) or ($n02_storage =~ /disabled/))
		{
			$node2_class   = "highlight_warning_bold";
			$node2_message = "#!string!state_0018!#";
			$ok            = 0;
		}
	}
	else
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0096!#";
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0096!#";
		$ok            = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0264!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	# And now libvirtd
	$node1_class   = "highlight_good_bold";
	$node1_message = "#!string!state_0014!#";
	$node2_class   = "highlight_good_bold";
	$node2_message = "#!string!state_0014!#";
	if ($an->data->{node}{node1}{has_servers})
	{
		$node1_class   = "highlight_note_bold";
		$node1_message = "#!string!state_0133!#";
	}
	if ($an->data->{node}{node2}{has_servers})
	{
		$node2_class   = "highlight_note_bold";
		$node2_message = "#!string!state_0133!#";
	}
	if ($services_seen)
	{
		if ($n01_libvirtd =~ /failed/)
		{
			$node1_class   = "highlight_warning_bold";
			$node1_message = "#!string!state_0018!#";
			$ok            = 0;
		}
		if ($n02_libvirtd =~ /failed/)
		{
			$node2_class   = "highlight_warning_bold";
			$node2_message = "#!string!state_0018!#";
			$ok            = 0;
		}
	}
	else
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0096!#";
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0096!#";
		$ok            = 0;
	}
	print $an->Web->template({file => "install-manifest.html", template => "new-anvil-install-message", replace => { 
		row		=>	"#!string!row_0265!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	}});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This writes out the cluster configuration file
sub write_cluster_conf
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "write_cluster_conf" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $node)
	{
		$an->Alert->error({title_key => "tools_title_0003", message_key => "error_message_0161", code => 161, file => $THIS_FILE, line => __LINE__});
		return("");
	}
	
	my $message     = "";
	my $return_code = 255;
	my $shell_call  =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{cluster_conf}." << EOF\n";
	   $shell_call  .= $an->data->{node}{$node}{cluster_conf}."\n";
	   $shell_call  .= "EOF\n";
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
	
	# Now run 'ccs_config_validate' to ensure it is sane.
	$shell_call = $an->data->{path}{ccs_config_validate}."; ".$an->data->{path}{echo}." return_code:\$?";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "target",     value1 => $target,
		name2 => "shell_call", value2 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
		
		if ($line =~ /^return_code:(\d+)/)
		{
			my $return_code = $1;
			if ($return_code eq "0")
			{
				# Validated
				$return_code = 0;
			}
			elsif ($return_code eq "3")
			{
				# Failed to validate
				$return_code = 1;
			}
		}
		else
		{
			$message .= "$line\n";
		}
	}
	
	# 0 = OK
	# 1 = Failed to validate
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "return_code", value1 => $return_code,
		name2 => "message",     value2 => $message,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code, $message);
}

# This (re)writes the lvm.conf file on a node.
sub write_lvm_conf_on_node
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "write_lvm_conf_on_node" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $shell_call =  $an->data->{path}{cat}." > ".$an->data->{path}{nodes}{lvm_conf}." << EOF\n";
	   $shell_call .= $an->data->{sys}{lvm_conf}."\n";
	   $shell_call .= "EOF";
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
	
	return(0);
}

#############################################################################################################
# Internal methods                                                                                          #
#############################################################################################################

# This does the actual OS Update.
sub _do_os_update
{
	my $self      = shift;
	my $parameter = shift;
	my $an        = $self->parent;
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "_do_os_update" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node     = $parameter->{node}     ? $parameter->{node}     : "";
	my $target   = $parameter->{target}   ? $parameter->{target}   : "";
	my $port     = $parameter->{port}     ? $parameter->{port}     : "";
	my $password = $parameter->{password} ? $parameter->{password} : "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",   value1 => $node, 
		name2 => "target", value2 => $target, 
		name3 => "port",   value3 => $port, 
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "password", value1 => $password, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $shell_call = $an->data->{path}{yum}." ".$an->data->{sys}{yum_switches}." update";
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
		$line =~ s/\n//g;
		$line =~ s/\r//g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /Installing : kernel/)
		{
			# New kernel, we'll need to reboot.
			$an->data->{node}{$node}{reboot_needed} = 1;
			$an->Log->entry({log_level => 1, message_key => "log_0194", message_variables => { node => $node }, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /Total download size/)
		{
			# Updated packages
			$an->data->{node}{$node}{os_updated} = 1;
			$an->Log->entry({log_level => 1, message_key => "log_0195", message_variables => { node => $node }, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

1;
