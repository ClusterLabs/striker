package AN::InstallManifest;

#
# This contains functions related to configuring node(s) via the Install
# Manifest tool.
# 
# Note: 
# * All remote calls set the port to '22', but this will be overridden if the
#   node name ends in :xx
# 
# BUG:
# - Install Manifests can be created with IFN networks not matching the per-node/
#   striker IFN IPs assigned...
# - Back-button doesn't work after creating a new manifest.
# - keys are being added in duplicate to ~/.ssh/authorized_keys
# - Failed to add local repo... Didn't install the PGP key
# - Saving the mail data fails to record the target email addresses
# - The vnetX data comes from the /shared/definitions, this is wrong when the
#   VM is on and useless when it is off.
# 
# TODO:
# - Add a hidden option to the install manifest for auto-adding RSA keys to
#   /root/.ssh/known_hosts
# - Make the map NIC removal prompt order configurable.
# - Check with fragmentless ping if the MTU is >1500 and error out if the 
#   packet fails. Otherwise, DRBD will blow up.
# - Add 'skip_if_unavailable=1' to all repos.
# - Make DG default to low IP range if the first octet is 192.x.x.x
# - Make it easier to identify which node is being worked on when doing things
#   like managing a node's Storage (ie; <b>Node X</b> in the top right)
# 
# - When assembling DRBD, watch syslog for "Sep 28 23:44:34 node2 kernel: block drbd0: The peer's disk size is too small!"
#   This is likely caused by the replacement machine having a smaller disk.
# - 
# 
# NOTE: The '$an' file handle has been added to all functions to enable the transition to using AN::Tools.
# 

use strict;
use warnings;
use AN::Cluster;
use AN::Common;
use IO::Handle;

# Set static variables.
my $THIS_FILE = "AN::InstallManifest.pm";

# This runs the install manifest against both nodes.
sub run_new_install_manifest
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "run_new_install_manifest" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	print AN::Common::template($conf, "common.html", "scanning-message");
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-header");
	
	# Some variables we'll need.
	$conf->{packages}{to_install} = {
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
	$conf->{path}{'anvil-map-network'} = "/sbin/striker/anvil-map-network";
	
	if ($conf->{perform_install})
	{
		# OK, GO!
		print AN::Common::template($conf, "install-manifest.html", "install-beginning");
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::update_manifest", value1 => $conf->{cgi}{update_manifest},
		}, file => $THIS_FILE, line => __LINE__});
		if ($conf->{cgi}{update_manifest})
		{
			# Write the updated manifest and switch to using it.
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "cgi::run", value1 => $conf->{cgi}{run},
			}, file => $THIS_FILE, line => __LINE__});
			my ($target_url, $xml_file) = AN::Cluster::generate_install_manifest($conf);
			print AN::Common::template($conf, "install-manifest.html", "manifest-created", {
				message	=>	AN::Common::get_string($conf, {
					key => "explain_0136", variables => {
						url		=>	"$target_url",
						file		=>	"$xml_file",
						old_manifest	=>	$conf->{cgi}{run},
					}
				}),
			});
			$conf->{cgi}{run} = $xml_file;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "cgi::run", value1 => $conf->{cgi}{run},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# If the node(s) are not online, we'll set up a repo pointing at this maching *if* we're configured
	# to be a repo.
	check_local_repo($conf);
	
	# Make sure we can log into both nodes.
	check_connection($conf) or return(1);
	
	# Make sure both nodes can get online. We'll try to install even without Internet access.
	verify_internet_access($conf);
	
	# Make sure both nodes are EL6 nodes.
	verify_os($conf) or return(1);
	
	### NOTE: I might want to move the addition of the an-repo up here.
	# Beyond here, perl is needed.
	verify_perl_is_installed($conf);
	
	# This checks the disks out and selects the largest disk on each node. It doesn't sanity check much
	# yet.
	check_storage($conf);
	
	# See if the node is in a cluster already. If so, we'll set a flag to block reboots if needed.
	check_if_in_cluster($conf);
	
	# Get a map of the physical network interfaces for later remapping to device names.
	my ($node1_remap_required, $node2_remap_required) = map_network($conf);
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_remap_required", value1 => $node1_remap_required,
		name2 => "node2_remap_required", value2 => $node2_remap_required,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If either/both nodes need a remap done, do it now.
	my $node1_rc = 0;
	my $node2_rc = 0;
	if ($node1_remap_required)
	{
		($node1_rc) = map_network_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, 1, "#!string!device_0005!#");
	}
	if ($node2_remap_required)
	{
		($node2_rc) = map_network_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, 1, "#!string!device_0006!#");
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
			#print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed-inline", {
			#	message		=>	"#!string!message_0378!#",
			#});
		}
		if (($node1_rc eq "4") || ($node2_rc eq "4"))
		{
			# Not enough NICs (or remap program failure)
			print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed-inline", {
				message		=>	"#!string!message_0380!#",
			});
		}
		if (($node1_rc eq "7") || ($node2_rc eq "7"))
		{
			# Didn't recognize the node
			print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed-inline", {
				message		=>	"#!string!message_0383!#",
			});
		}
		if (($node1_rc eq "8") || ($node2_rc eq "8"))
		{
			# SSH handle didn't exist, though it should have.
			print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed-inline", {
				message		=>	"#!string!message_0382!#",
			});
		}
		if (($node1_rc eq "9") || ($node2_rc eq "9"))
		{
			# Failed to download the anvil-map-network script
			print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed-inline", {
				message		=>	"#!string!message_0381!#",
			});
		}
		print AN::Common::template($conf, "install-manifest.html", "close-table");
		return(2);
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::perform_install", value1 => $conf->{cgi}{perform_install},
	}, file => $THIS_FILE, line => __LINE__});
	if (not $conf->{cgi}{perform_install})
	{
		# Now summarize and ask the user to confirm.
		summarize_build_plan($conf);
		return(0);
	}
	else
	{
		# If we're here, we're ready to start!
		print AN::Common::template($conf, "install-manifest.html", "sanity-checks-complete");
		
		# Rewrite the install manifest if need be.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::update_manifest", value1 => $conf->{cgi}{update_manifest},
		}, file => $THIS_FILE, line => __LINE__});
		if ($conf->{cgi}{update_manifest})
		{
			# Update the running install manifest to record the MAC
			# addresses the user selected.
			update_install_manifest($conf);
		}
		
		# Back things up.
		backup_files($conf);
		
		# Register the nodes with RHN, if needed.
		register_with_rhn($conf);
		
		# Configure the network
		configure_network($conf) or return(1);
		
		# Configure the NTP on the servers, if set.
		configure_ntp($conf) or return(1);
		
		# Add user-specified repos
		#add_user_repositories($conf);
		
		# Install needed RPMs.
		install_programs($conf) or return(1);
		
		# Update the OS on each node.
		update_nodes($conf);
		
		# Configure daemons
		configure_daemons($conf) or return(1);
		
		# Set the ricci password
		set_ricci_password($conf) or return(1);
		
		# Write out the cluster configuration file
		configure_cman($conf) or return(1);
		
		# Write out the clustered LVM configuration files
		configure_clvmd($conf) or return(1);
		
		# This configures IPMI, if IPMI is set as a fence device.
		if ($conf->{cgi}{anvil_fence_order} =~ /ipmi/)
		{
			configure_ipmi($conf) or return(1);
		}
		
		# Configure storage stage 1 (partitioning).
		configure_storage_stage1($conf) or return(1);
		
		# This handles configuring SELinux.
		configure_selinux($conf) or return(1); 
		
		# Set the root user's passwords as the last step to ensure reloading the browser works for 
		# as long as possible.
		set_root_password($conf) or return(1);
		
		# This sets up the various Striker tools and ScanCore. It must run before storage stage2 
		# because DRBD will need it.
		configure_striker_tools($conf) or return(1);
		
		# If a reboot is needed, now is the time to do it. This will switch the CGI nodeX IPs to the 
		# new ones, too.
		reboot_nodes($conf) or return(1);
		
		# Configure storage stage 2 (drbd)
		configure_storage_stage2($conf) or return(1);
		
		# Start cman up
		start_cman($conf) or return(1);
		
		# Live migration won't work until we've populated ~/.ssh/known_hosts, so do so now.
		configure_ssh($conf) or return(1);
		
		# This manually starts DRBD, forcing one to primary if needed, configures clvmd, sets up the 
		# PVs and VGs, creates the /shared LV, creates the GFS2 partition and configures fstab.
		configure_storage_stage3($conf) or return(1);
		
		# Enable (or disable) tools.
		enable_tools($conf) or return(1);
		
		### If we're not dead, it's time to celebrate!
		# Is this Anvil! already in the config file?
		my ($anvil_configured) = check_config_for_anvil($conf);
		
		# Do we need to show the link for adding the Anvil! to the config?
		my $message = AN::Common::get_string($conf, {key => "message_0286", variables => { url => "?cluster=$conf->{cgi}{cluster}" }});
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
			   $url .= "&cluster__new__name=$conf->{cgi}{anvil_name}";
			   $url .= "&cluster__new__ricci_pw=$conf->{cgi}{anvil_password}";
			   $url .= "&cluster__new__root_pw=$conf->{cgi}{anvil_password}";
			   $url .= "&cluster__new__nodes_1_name=$conf->{cgi}{anvil_node1_name}";
			   $url .= "&cluster__new__nodes_1_ip=$conf->{cgi}{anvil_node1_bcn_ip}";
			   $url .= "&cluster__new__nodes_2_name=$conf->{cgi}{anvil_node2_name}";
			   $url .= "&cluster__new__nodes_2_ip=$conf->{cgi}{anvil_node2_bcn_ip}";
			# see what these value are, relative to global values.
			
			# Now the string.
			$message = AN::Common::get_string($conf, {key => "message_0402", variables => { url => $url }});
		}
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-success", {
			message	=>	$message,
		});
		
		# Enough of that, now everyone go home.
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-footer");
	}
	
	return(0);
}

# This enables (or disables) selected tools by flipping their enable variables to '1' (or '0') i striker.conf.
sub enable_tools
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "enable_tools" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# sas_rc  == anvil-safe-start, return code
	# akau_rc == anvil-kick-apc-ups, return code
	my ($node1_sas_rc, $node1_akau_rc, $node1_sc_rc) = enable_tools_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $conf->{cgi}{anvil_node1_name});
	my ($node2_sas_rc, $node2_akau_rc, $node2_sc_rc) = enable_tools_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $conf->{cgi}{anvil_node2_name});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0006", message_variables => {
		name1 => "node1_sas_rc",  value1 => $node1_sas_rc,
		name2 => "node1_akau_rc", value2 => $node1_akau_rc,
		name3 => "node1_sc_rc",   value3 => $node1_sc_rc,
		name4 => "node2_sas_rc",  value4 => $node2_sas_rc,
		name5 => "node2_akau_rc", value5 => $node2_akau_rc,
		name6 => "node2_sc_rc",   value6 => $node2_sc_rc,
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
	if ($node1_sas_rc eq "0")
	{
		# Unknown state.
		$ok = 0;
	}
	elsif ($node1_sas_rc eq "1")
	{
		# Enabled successfully.
		$node1_class   = "highlight_good_bold";
		$node1_message = "#!string!state_0119!#";
	}
	elsif ($node1_sas_rc eq "2")
	{
		# Disabled successfully.
		$node1_class   = "highlight_good_bold";
		$node1_message = "#!string!state_0120!#";
	}
	elsif ($node1_sas_rc eq "3")
	{
		# Failed to enabled!
		$node1_message = "#!string!state_0121!#";
		$ok            = 0;
	}
	elsif ($node1_sas_rc eq "4")
	{
		# Failed to disable!
		$node1_message = "#!string!state_0122!#";
		$ok            = 0;
	}
	# Node 2
	if ($node2_sas_rc eq "0")
	{
		# Unknown state.
		$ok = 0;
	}
	elsif ($node2_sas_rc eq "1")
	{
		# Enabled successfully.
		$node2_class   = "highlight_good_bold";
		$node2_message = "#!string!state_0119!#";
	}
	elsif ($node2_sas_rc eq "2")
	{
		# Disabled successfully.
		$node2_class   = "highlight_good_bold";
		$node2_message = "#!string!state_0120!#";
	}
	elsif ($node2_sas_rc eq "3")
	{
		# Failed to enabled!
		$node2_message = "#!string!state_0121!#";
		$ok            = 0;
	}
	elsif ($node2_sas_rc eq "4")
	{
		# Failed to disable!
		$node2_message = "#!string!state_0122!#";
		$ok            = 0;
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0287!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	# Next, anvil-kick-apc-ups
	$node1_class   = "highlight_warning_bold";
	$node1_message = "#!string!state_0001!#";
	$node2_class   = "highlight_warning_bold";
	$node2_message = "#!string!state_0001!#";
	# Node 1
	if ($node1_akau_rc eq "0")
	{
		# Unknown state.
		$ok = 0;
	}
	elsif ($node1_akau_rc eq "1")
	{
		# Enabled successfully.
		$node1_class   = "highlight_good_bold";
		$node1_message = "#!string!state_0119!#";
	}
	elsif ($node1_akau_rc eq "2")
	{
		# Disabled successfully.
		$node1_class   = "highlight_good_bold";
		$node1_message = "#!string!state_0120!#";
	}
	elsif ($node1_akau_rc eq "3")
	{
		# Failed to enabled!
		$node1_message = "#!string!state_0121!#";
		$ok            = 0;
	}
	elsif ($node1_akau_rc eq "4")
	{
		# Failed to disable!
		$node1_message = "#!string!state_0122!#";
		$ok            = 0;
	}
	# Node 2
	if ($node2_akau_rc eq "0")
	{
		# Unknown state.
		$ok = 0;
	}
	elsif ($node2_akau_rc eq "1")
	{
		# Enabled successfully.
		$node2_class   = "highlight_good_bold";
		$node2_message = "#!string!state_0119!#";
	}
	elsif ($node2_akau_rc eq "2")
	{
		# Disabled successfully.
		$node2_class   = "highlight_good_bold";
		$node2_message = "#!string!state_0120!#";
	}
	elsif ($node2_akau_rc eq "3")
	{
		# Failed to enabled!
		$node2_message = "#!string!state_0121!#";
		$ok            = 0;
	}
	elsif ($node2_akau_rc eq "4")
	{
		# Failed to disable!
		$node2_message = "#!string!state_0122!#";
		$ok            = 0;
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0288!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	# And finally, ScanCore
	$node1_class   = "highlight_warning_bold";
	$node1_message = "#!string!state_0001!#";
	$node2_class   = "highlight_warning_bold";
	$node2_message = "#!string!state_0001!#";
	# Node 1
	if ($node1_sc_rc eq "0")
	{
		# Unknown state.
		$ok = 0;
	}
	elsif ($node1_sc_rc eq "1")
	{
		# Enabled successfully.
		$node1_class   = "highlight_good_bold";
		$node1_message = "#!string!state_0119!#";
	}
	elsif ($node1_sc_rc eq "2")
	{
		# Disabled successfully.
		$node1_class   = "highlight_good_bold";
		$node1_message = "#!string!state_0120!#";
	}
	elsif ($node1_sc_rc eq "3")
	{
		# Failed to enabled!
		$node1_message = "#!string!state_0121!#";
		$ok            = 0;
	}
	elsif ($node1_sc_rc eq "4")
	{
		# Failed to disable!
		$node1_message = "#!string!state_0122!#";
		$ok            = 0;
	}
	# Node 2
	if ($node2_sc_rc eq "0")
	{
		# Unknown state.
		$ok = 0;
	}
	elsif ($node2_sc_rc eq "1")
	{
		# Enabled successfully.
		$node2_class   = "highlight_good_bold";
		$node2_message = "#!string!state_0119!#";
	}
	elsif ($node2_sc_rc eq "2")
	{
		# Disabled successfully.
		$node2_class   = "highlight_good_bold";
		$node2_message = "#!string!state_0120!#";
	}
	elsif ($node2_sc_rc eq "3")
	{
		# Failed to enabled!
		$node2_message = "#!string!state_0121!#";
		$ok            = 0;
	}
	elsif ($node2_sc_rc eq "4")
	{
		# Failed to disable!
		$node2_message = "#!string!state_0122!#";
		$ok            = 0;
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0289!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This handles enabling/disabling tools on a given node.
sub enable_tools_on_node
{
	my ($conf, $node, $password, $node_name) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "enable_tools_on_node" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node",      value1 => $node, 
		name2 => "node_name", value2 => $node_name, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### anvil-safe-start
	# If requested, enable anvil-safe-start, otherwise, disable it.
	my $sas_rc     = 0;
	my $shell_call = "$conf->{path}{nodes}{'anvil-safe-start'} --disable\n";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::install_manifest::use_anvil-safe-start", value1 => $conf->{sys}{install_manifest}{'use_anvil-safe-start'},
	}, file => $THIS_FILE, line => __LINE__});
	if ($conf->{sys}{install_manifest}{'use_anvil-safe-start'})
	{
		$shell_call = "$conf->{path}{nodes}{'anvil-safe-start'} --enable\n";
	}
	$shell_call .= "
if [ -e $conf->{path}{nodes}{'anvil-safe-start_link'} ];
then 
    echo enabled; 
else 
    echo disabled;
fi
";
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
		
		if ($line eq "enabled")
		{
			if ($conf->{sys}{install_manifest}{'use_anvil-safe-start'})
			{
				# Good.
				$sas_rc = 1;
			}
			else
			{
				# Not good... should have been disabled.
				$sas_rc = 3;
			}
		}
		elsif ($line eq "disabled")
		{
			if ($conf->{sys}{install_manifest}{'use_anvil-safe-start'})
			{
				# Not good, should have been disabled
				$sas_rc = 4;
			}
			else
			{
				# Good
				$sas_rc = 2;
			}
		}
	}

	### anvil-kick-apc-ups
	# If requested, enable anvil-kick-apc-ups, otherwise, disable it.
	my $akau_rc    = 0;
	   $shell_call = "$conf->{path}{nodes}{'anvil-kick-apc-ups'} --disable\n";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::install_manifest::use_anvil-kick-apc-ups", value1 => $conf->{sys}{install_manifest}{'use_anvil-kick-apc-ups'},
	}, file => $THIS_FILE, line => __LINE__});
	if ($conf->{sys}{install_manifest}{'use_anvil-kick-apc-ups'})
	{
		$shell_call = "$conf->{path}{nodes}{'anvil-kick-apc-ups'} --enable\n";
	}
	$shell_call .= "
if \$(grep -q '^tools::anvil-kick-apc-ups::enabled\\s*=\\s*1' /etc/striker/striker.conf);
then 
    echo enabled; 
else 
    echo disabled;
fi
";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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

		if ($line eq "enabled")
		{
			if ($conf->{sys}{install_manifest}{'use_anvil-kick-apc-ups'})
			{
				# Good.
				$akau_rc = 1;
			}
			else
			{
				# Not good... should have been disabled.
				$akau_rc = 3;
			}
		}
		elsif ($line eq "disabled")
		{
			if ($conf->{sys}{install_manifest}{'use_anvil-kick-apc-ups'})
			{
				# Not good, should have been disabled
				$akau_rc = 4;
			}
			else
			{
				# Good
				$akau_rc = 2;
			}
		}
	}
	
	### ScanCore
	# If requested, enable ScanCore, otherwise, disable it.
	my $sc_rc      = 0;
	   $shell_call = "$conf->{path}{nodes}{scancore} --disable\n";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::install_manifest::use_scancore", value1 => $conf->{sys}{install_manifest}{use_scancore},
	}, file => $THIS_FILE, line => __LINE__});
	if ($conf->{sys}{install_manifest}{use_scancore})
	{
		$shell_call = "$conf->{path}{nodes}{scancore} --enable\n";
	}
	$shell_call .= "
if \$(grep -q '^scancore::enabled\\s*=\\s*1' /etc/striker/striker.conf);
then 
    echo enabled; 
else 
    echo disabled;
fi
";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
		
		if ($line eq "enabled")
		{
			if ($conf->{sys}{install_manifest}{use_scancore})
			{
				# Good.
				$sc_rc = 1;
			}
			else
			{
				# Not good... should have been disabled.
				$sc_rc = 3;
			}
		}
		elsif ($line eq "disabled")
		{
			if ($conf->{sys}{install_manifest}{use_scancore})
			{
				# Not good, should have been disabled
				$sc_rc = 4;
			}
			else
			{
				# Good
				$sc_rc = 2;
			}
		}
	}
	
	# 0 == No changes made
	# 1 == Enabled successfully
	# 2 == Disabled successfully
	# 3 == Failed to enable
	# 4 == Failed to disable
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "sas_rc",  value1 => $sas_rc,
		name2 => "akau_rc", value2 => $akau_rc,
		name3 => "sc_rc",   value3 => $sc_rc,
	}, file => $THIS_FILE, line => __LINE__});
	return($sas_rc, $akau_rc, $sc_rc);
}

# This downloads the '/sbin/striker' tools from one of the dashboards and
# copies them (Striker tools and ScanCore) into place.
sub configure_striker_tools
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_striker_tools" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Configure Striker tools and Scancore.
	my ($ok) = configure_scancore($conf);
	
	return($ok);
}

# This does the actual work of configuring ScanCore on a given node.
sub configure_scancore_on_node
{
	my ($conf, $node, $password, $node_name) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_scancore_on_node" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node",      value1 => $node, 
		name2 => "node_name", value2 => $node_name, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return_code = 255;
	my $message     = "";
	
	my $uuid = "";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node",                        value1 => $node,
		name2 => "cgi::anvil_node1_current_ip", value2 => $conf->{cgi}{anvil_node1_current_ip},
	}, file => $THIS_FILE, line => __LINE__});
	if ($node eq $conf->{cgi}{anvil_node1_current_ip})
	{
		$uuid = $conf->{cgi}{anvil_node1_uuid} ? $conf->{cgi}{anvil_node1_uuid} : AN::Cluster::generate_uuid($conf);
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "uuid",                  value1 => $uuid,
			name2 => "cgi::anvil_node1_uuid", value2 => $conf->{cgi}{anvil_node1_uuid},
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		$uuid = $conf->{cgi}{anvil_node2_uuid} ? $conf->{cgi}{anvil_node2_uuid} : AN::Cluster::generate_uuid($conf);
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "uuid",                  value1 => $uuid,
			name2 => "cgi::anvil_node2_uuid", value2 => $conf->{cgi}{anvil_node2_uuid},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# First, copy the ScanCore files into place. Create the striker config
	# directory if needed, as well.
	my $generate_config  = 0;
	my ($path, $tarball) = ($conf->{path}{nodes}{striker_tarball} =~ /^(.*)\/(.*)/);
	my $download_1       = "http://$conf->{cgi}{anvil_striker1_bcn_ip}/files/$tarball";
	my $download_2       = "http://$conf->{cgi}{anvil_striker2_bcn_ip}/files/$tarball";
	my $shell_call       = "
if [ ! -e '$conf->{path}{nodes}{striker_tarball}' ]; 
then 
    echo download needed;
    if [ ! -e '$path' ];
    then
        mkdir -p $path
    fi
    wget -c $download_1 -O $conf->{path}{nodes}{striker_tarball}
    if [ -s '$conf->{path}{nodes}{striker_tarball}' ];
    then
        echo 'downloaded from $download_1 successfully'
    else
        echo 'download from $download_1 failed, trying alternate.'
        if [ -e '$conf->{path}{nodes}{striker_tarball}' ];
        then
            echo 'Deleting zero-size file'
            rm -f $conf->{path}{nodes}{striker_tarball}
        fi;
        wget -c $download_2 -O $conf->{path}{nodes}{striker_tarball}
        if [ -e '$conf->{path}{nodes}{striker_tarball}' ];
        then
            echo 'downloaded from $download_2 successfully'
        else
            echo 'download from $download_2 failed, giving up.'
        fi;
    fi;
fi;

if [ -e '$conf->{path}{nodes}{striker_tarball}' ];
then
    if [ -e '$path/ScanCore/ScanCore' ];
    then
        echo 'install already completed'
    else
        echo 'Extracting tarball'
        $conf->{path}{nodes}{tar} -xvjf $conf->{path}{nodes}{striker_tarball} -C $path/ .
        mv $path/Data $path/
        mv $path/AN $conf->{path}{nodes}{perl_library}/
        if [ -e '$path/ScanCore/ScanCore' ];
        then
            echo 'install succeeded'
        else
            echo 'install failed'
        fi;
    fi;
fi;

if [ ! -e '/etc/striker' ];
then
    mkdir /etc/striker
    echo 'Striker configuration directory created.'
fi;

if [ -e '$conf->{path}{nodes}{striker_config}' ];
then
    echo 'striker config exists'
else
    echo 'striker config needs to be generated'
fi;

if [ ! -e '$conf->{path}{nodes}{host_uuid}' ]
then
    echo 'Recording the host UUID'
    echo $uuid > $conf->{path}{nodes}{host_uuid}
    if [ -e '$conf->{path}{nodes}{host_uuid}' ]
    then
        echo -n 'host_uuid = '; cat /etc/striker/host.uuid 
    else
        echo 'failed to create host uuid file'
    fi
fi
";
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
		if ($line =~ /failed to create host uuid file/)
		{
			$return_code = 6;
		}
		if ($line =~ /host_uuid = (.*)/)
		{
			my $uuid = $1;
			if ($uuid !~ /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/)
			{
				$return_code = 7;
			}
		}
	}
	
	# Setup striker.conf if we've not hit a problem and if it doesn't exist already.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
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
			my $shell_call = "cat $base_striker_config_file";
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
				
				# Find DB IDs already used so I don't duplicate
				# later when I inject the strikers.
				if ($line =~ /^scancore::db::(\d+)::host\s+=\s+(.*)$/)
				{
					my $db_id   = $1;
					my $db_host = $2;
					$conf->{used_db_id}{$db_id}     = $db_host;
					$conf->{used_db_host}{$db_host} = $db_id;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "used_db_id::$db_id",     value1 => $conf->{used_db_id}{$db_id},
						name2 => "used_db_host::$db_host", value2 => $conf->{used_db_host}{$db_host},
					}, file => $THIS_FILE, line => __LINE__});
				}
				
				$striker_config .= "$line\n";
			}
			
			# Loop through again and inject the striker DBs.
			my $striker_1_bcn_ip = $conf->{cgi}{anvil_striker1_bcn_ip};
			my $striker_1_db_id  = 0;
			my $add_striker_1    = 0;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "used_db_host::$striker_1_bcn_ip", value1 => $conf->{used_db_host}{$striker_1_bcn_ip},
			}, file => $THIS_FILE, line => __LINE__});
			if (not $conf->{used_db_host}{$striker_1_bcn_ip})
			{
				# Find the first free DB ID.
				my $id = 1;
				while (not $striker_1_db_id)
				{
					if ($conf->{used_db_id}{$id})
					{
						$id++;
					}
					else
					{
						$striker_1_db_id                         = $id;
						$add_striker_1                           = 1;
						$conf->{used_db_id}{$striker_1_db_id}    = $striker_1_bcn_ip;
						$conf->{used_db_host}{$striker_1_bcn_ip} = $striker_1_db_id; 
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "used_db_id::$striker_1_db_id",    value1 => $conf->{used_db_id}{$striker_1_db_id},
							name2 => "used_db_host::$striker_1_bcn_ip", value2 => $conf->{used_db_host}{$striker_1_bcn_ip},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "striker_1_db_id", value1 => $striker_1_db_id,
				}, file => $THIS_FILE, line => __LINE__});
			}
			my $striker_2_bcn_ip = $conf->{cgi}{anvil_striker2_bcn_ip};
			my $striker_2_db_id  = 0;
			my $add_striker_2    = 0;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "used_db_host::$striker_2_bcn_ip", value1 => $conf->{used_db_host}{$striker_2_bcn_ip},
			}, file => $THIS_FILE, line => __LINE__});
			if (not $conf->{used_db_host}{$striker_2_bcn_ip})
			{
				# Find the first free DB ID.
				my $id = 1;
				while (not $striker_2_db_id)
				{
					if ($conf->{used_db_id}{$id})
					{
						$id++;
					}
					else
					{
						$striker_2_db_id                         = $id;
						$add_striker_2                           = 1;
						$conf->{used_db_id}{$striker_2_db_id}    = $striker_2_bcn_ip;
						$conf->{used_db_host}{$striker_2_bcn_ip} = $striker_2_db_id;
						$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
							name1 => "used_db_id::$striker_2_db_id",    value1 => $conf->{used_db_id}{$striker_2_db_id},
							name2 => "used_db_host::$striker_2_bcn_ip", value2 => $conf->{used_db_host}{$striker_2_bcn_ip},
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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
					if ($line =~ /#scancore::db::2::password\s+=\s+Initial1/)
					{
						# Inject
						$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
							name1 => "add_striker_1", value1 => $add_striker_1,
						}, file => $THIS_FILE, line => __LINE__});
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
							$new_striker_config .= "scancore::db::${db_id}::name			=	$conf->{sys}{scancore_database}\n";
							$new_striker_config .= "scancore::db::${db_id}::user			=	$conf->{sys}{striker_user}\n";
							$new_striker_config .= "scancore::db::${db_id}::password		=	$conf->{cgi}{anvil_password}\n\n";
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
							$new_striker_config .= "scancore::db::${db_id}::name			=	$conf->{sys}{scancore_database}\n";
							$new_striker_config .= "scancore::db::${db_id}::user			=	$conf->{sys}{striker_user}\n";
							$new_striker_config .= "scancore::db::${db_id}::password		=	$conf->{cgi}{anvil_password}\n\n";
						}
					}
				}
				
				# Copy new over old.
				$striker_config = $new_striker_config;
			}
			
			# This is going to be too big, so we need to write the
			# config to a file and rsync it to the node.
			my $temp_file  = "/tmp/${node}_striker_".time.".conf";
			   $shell_call = $temp_file;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			open (my $file_handle, ">", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to write: [$shell_call], error was: $!\n";
			print $file_handle $striker_config;
			close $file_handle;
			
			# Now rsync it to the node (using an 'expect' wrapper).
			my $bad_file = "";
			my $bad_line = "";
			$an->Log->entry({log_level => 2, message_key => "log_0035", message_variables => {
				node => $node, 
			}, file => $THIS_FILE, line => __LINE__});
			AN::Common::test_ssh_fingerprint($conf, $node, 1);	# 1 == silent
			
			$an->Log->entry({log_level => 2, message_key => "log_0035", message_variables => {
				node => $node, 
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 2, message_key => "log_0009", file => $THIS_FILE, line => __LINE__});
			AN::Common::create_rsync_wrapper($conf, $node, $password);
			
			$shell_call = "~/rsync.$node $conf->{args}{rsync} $temp_file root\@$node:$conf->{path}{striker_config}";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "Calling", value1 => $shell_call,
			}, file => $THIS_FILE, line => __LINE__});
			open ($file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
			my $no_key = 0;
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line,
				}, file => $THIS_FILE, line => __LINE__});
				
				# If the user is re-running the install, this could fail because the target's
				# key changed. We won't clear it because that would open up a security 
				# vulnerability... Sorry users. :(
				if ($line =~ /REMOTE HOST IDENTIFICATION HAS CHANGED/i)
				{
					$return_code = 8;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "return_code", value1 => $return_code,
					}, file => $THIS_FILE, line => __LINE__});
				}
				if ($line =~ /Offending key in (\/.*?\/known_hosts):(\d+)/)
				{
					$bad_file = $1;
					$bad_line = $2;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "bad_file", value1 => $bad_file,
						name2 => "bad_line", value2 => $bad_line,
					}, file => $THIS_FILE, line => __LINE__});
					$message  = AN::Common::get_string($conf, {key => "message_0448", variables => {
						bad_file	=>	$bad_file,
						bad_line	=>	$bad_line,
					}});
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "message", value1 => $message,
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
			close $file_handle;
			
			if (not $return_code)
			{
				# Write out the striker.conf file now.
				my $generated_ok = 0;
				   $shell_call   = "
if [ -s '$conf->{path}{striker_config}' ];
then
    echo 'config exists'
else
    echo 'config does not exist'
fi
";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
					name2 => "node",       value2 => $node,
				}, file => $THIS_FILE, line => __LINE__});
				($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
					
					if ($line =~ /config exists/)
					{
						$generated_ok = 1;
					}
				}
				if ($generated_ok)
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "path::striker_config", value1 => $conf->{path}{striker_config},
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Failed 
					$return_code = 4;
				}
			}
		}
		else
		{
			# Template striker.conf doesn't exist. Oops.
			$return_code = 3;
		}
	}
	else
	{
		# Config already exists
		$an->Log->entry({log_level => 2, message_key => "log_0036", message_variables => {
			node => $node, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	if (not $return_code)
	{
		# Add it to root's crontab.
		my $shell_call = "
if [ ! -e '$conf->{path}{nodes}{cron_root}' ]
then
    echo 'creating empty crontab for root.'
    echo 'MAILTO=\"\"' > $conf->{path}{nodes}{cron_root}
    echo \"# Disable these by calling them with the '--disable' switch. Do not comment them out.\"
    chown root:root $conf->{path}{nodes}{cron_root}
    chmod 600 $conf->{path}{nodes}{cron_root}
fi
grep -q ScanCore $conf->{path}{nodes}{cron_root}
if [ \"\$?\" -eq '0' ];
then
    echo 'ScanCore exits'
else
    echo \"Adding ScanCore to root's cron table.\"
    echo '*/1 * * * * $conf->{path}{nodes}{scancore}' >> $conf->{path}{nodes}{cron_root}
fi
grep -q anvil-safe-start $conf->{path}{nodes}{cron_root}
if [ \"\$?\" -eq '0' ];
then
    echo 'anvil-safe-start exits'
else
    echo \"Adding 'anvil-safe-start' to root's cron table.\"
    echo '*/1 * * * * $conf->{path}{nodes}{'anvil-safe-start'}' >> $conf->{path}{nodes}{cron_root}
fi
grep -q anvil-kick-apc-ups $conf->{path}{nodes}{cron_root}
if [ \"\$?\" -eq '0' ];
then
    echo 'anvil-kick-apc-ups exits'
else
    echo \"Adding 'anvil-kick-apc-ups' to root's cron table.\"
    echo '*/1 * * * * $conf->{path}{nodes}{'anvil-kick-apc-ups'}' >> $conf->{path}{nodes}{cron_root}
fi
";
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
		}
	}
	
	# Delete this so it doesn't interfere with node2
	delete $conf->{used_db_host};
	
	# 0 == Success
	# 1 == Failed to download
	# 2 == Failed to extract
	# 3 == Base striker.conf not found.
	# 4 == Failed to create the striker.conf file.
	# 5 == Failed to add to root's crontab
	# 6 == Failed to generate the host UUID file
	# 7 == Host UUID is invalid
	# 8 == Target's ssh fingerprint changed.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "return_code", value1 => $return_code,
		name2 => "message",     value2 => $message,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code, $message);
}


# This sets up scancore to run on the nodes. It expects the database(s) to be
# on the node(s).
sub configure_scancore
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_scancore" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my ($node1_rc, $node1_rc_message) = configure_scancore_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $conf->{cgi}{anvil_node1_name});
	my ($node2_rc, $node2_rc_message) = configure_scancore_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $conf->{cgi}{anvil_node2_name});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "node1_rc",         value1 => $node1_rc,
		name2 => "node2_rc",         value2 => $node2_rc,
		name3 => "node1_rc_message", value3 => $node1_rc_message,
		name4 => "node2_rc_message", value4 => $node2_rc_message,
	}, file => $THIS_FILE, line => __LINE__});
	# 0 == Success
	# 1 == Failed to download
	# 2 == Failed to extract
	# 3 == Base striker.conf not found.
	# 4 == Failed to create the striker.conf file.
	# 5 == Failed to add to root's crontab
	# 6 == Failed to generate the host UUID file
	# 7 == Host UUID is invalid
	# 8 == Target's ssh fingerprint changed.
	
	my $ok = 1;
	# Report
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0005!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0005!#";
	# Node 1
	if ($node1_rc eq "1")
	{
		# Failed to download
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0111!#";
		$ok            = 0;
	}
	elsif ($node1_rc eq "2")
	{
		# Failed to extract
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0112!#";
		$ok            = 0;
	}
	elsif ($node1_rc eq "3")
	{
		# Base striker.conf not found
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0113!#";
		$ok            = 0;
	}
	elsif ($node1_rc eq "4")
	{
		# Failed to create striker.conf
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0114!#";
		$ok            = 0;
	}
	elsif ($node1_rc eq "5")
	{
		# Failed to add ScanCore to root's crontab
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0116!#";
		$ok            = 0;
	}
	elsif ($node1_rc eq "6")
	{
		# Failed to generate the host UUID file
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0117!#";
		$ok            = 0;
	}
	elsif ($node1_rc eq "7")
	{
		# The UUID in the host file is invalid.
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0118!#";
		$ok            = 0;
	}
	elsif ($node1_rc eq "8")
	{
		# The node's ssh fingerprint has changed.
		$node1_class   = "highlight_warning_bold";
		$node1_message = $node1_rc_message;
		$ok            = 0;
	}
	
	# Node 2
	if ($node2_rc eq "1")
	{
		# Failed to download
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0111!#";
		$ok            = 0;
	}
	elsif ($node2_rc eq "2")
	{
		# Failed to extract
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0112!#";
		$ok            = 0;
	}
	elsif ($node2_rc eq "3")
	{
		# Base striker.conf not found
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0113!#";
		$ok            = 0;
	}
	elsif ($node2_rc eq "4")
	{
		# Failed to create striker.conf
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0114!#";
		$ok            = 0;
	}
	elsif ($node2_rc eq "5")
	{
		# Failed to add ScanCore to root's crontab
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0116!#";
		$ok            = 0;
	}
	elsif ($node2_rc eq "6")
	{
		# Failed to generate the host UUID file
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0117!#";
		$ok            = 0;
	}
	elsif ($node2_rc eq "7")
	{
		# The UUID in the host file is invalid.
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0118!#";
		$ok            = 0;
	}
	elsif ($node2_rc eq "8")
	{
		# The node's ssh fingerprint has changed.
		$node2_class   = "highlight_warning_bold";
		$node2_message = $node2_rc_message;
		$ok            = 0;
	}
	
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0286!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This takes the current install manifest up rewrites it to record the user's MAC addresses selected during 
# the network remap.
sub update_install_manifest
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "update_install_manifest" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1           = $conf->{cgi}{anvil_node1_current_ip};
	my $node1_bcn_link1 = $conf->{conf}{node}{$node1}{set_nic}{bcn_link1};
	my $node1_bcn_link2 = $conf->{conf}{node}{$node1}{set_nic}{bcn_link2};
	my $node1_sn_link1  = $conf->{conf}{node}{$node1}{set_nic}{sn_link1};
	my $node1_sn_link2  = $conf->{conf}{node}{$node1}{set_nic}{sn_link2};
	my $node1_ifn_link1 = $conf->{conf}{node}{$node1}{set_nic}{ifn_link1};
	my $node1_ifn_link2 = $conf->{conf}{node}{$node1}{set_nic}{ifn_link2};
	my $node2           = $conf->{cgi}{anvil_node2_current_ip};
	my $node2_bcn_link1 = $conf->{conf}{node}{$node2}{set_nic}{bcn_link1};
	my $node2_bcn_link2 = $conf->{conf}{node}{$node2}{set_nic}{bcn_link2};
	my $node2_sn_link1  = $conf->{conf}{node}{$node2}{set_nic}{sn_link1};
	my $node2_sn_link2  = $conf->{conf}{node}{$node2}{set_nic}{sn_link2};
	my $node2_ifn_link1 = $conf->{conf}{node}{$node2}{set_nic}{ifn_link1};
	my $node2_ifn_link2 = $conf->{conf}{node}{$node2}{set_nic}{ifn_link2};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
		name1 => "node1",           value1 => $node1,
		name2 => "node1_bcn_link2", value2 => $node1_bcn_link1,
		name3 => "node1_bcn_link2", value3 => $node1_bcn_link2,
		name4 => "node1_sn_link1",  value4 => $node1_sn_link1,
		name5 => "node1_sn_link2",  value5 => $node1_sn_link2,
		name6 => "node1_ifn_link1", value6 => $node1_ifn_link1,
		name7 => "node1_ifn_link2", value7 => $node1_ifn_link2,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
		name1 => "node2",           value1 => $node2,
		name2 => "node2_bcn_link2", value2 => $node2_bcn_link1,
		name3 => "node2_bcn_link2", value3 => $node2_bcn_link2,
		name4 => "node2_sn_link1",  value4 => $node2_sn_link1,
		name5 => "node2_sn_link2",  value5 => $node2_sn_link2,
		name6 => "node2_ifn_link1", value6 => $node2_ifn_link1,
		name7 => "node2_ifn_link2", value7 => $node2_ifn_link2,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $save       = 0;
	my $in_node1   = 0;
	my $in_node2   = 0;
	my $raw_file   = "";
	my $shell_call = "$conf->{path}{apache_manifests_dir}/$conf->{cgi}{run}";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "<", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
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
		$raw_file .= "$line\n";
	}
	close $file_handle;
	
	# Write out new raw file, if changes were made.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "save", value1 => $save,
	}, file => $THIS_FILE, line => __LINE__});
	if ($save)
	{
		### TODO: Make a backup directory and save a pre-modified
		###       backup to it.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "raw_file", value1 => $raw_file,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 2, message_key => "log_0039", message_variables => {
			file => $conf->{cgi}{run}, 
		}, file => $THIS_FILE, line => __LINE__});
		my $shell_call = "$conf->{path}{apache_manifests_dir}/$conf->{cgi}{run}";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		open (my $file_handle, ">", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to write: [$shell_call], error was: $!\n";
		print $file_handle $raw_file;
		close $file_handle;
		
		# Tell the user.
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message-wide", {
			row	=>	"#!string!title_0157!#",
			class	=>	"body",
			message	=>	"#!string!message_0376!#",
		});
		
		# Sync with the peer
		my $peer = AN::Cluster::sync_with_peer($conf);
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "peer", value1 => $peer,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return(0);
}

# This checks to see if we're configured to be a repo for RHEL and/or CentOS.
# If so, it gets the local IPs to be used later when setting up the repos on
# the nodes.
sub check_local_repo
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_local_repo" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Call the gather system info tool to get the BCN and IFN IPs.
	my $shell_call = "$conf->{path}{'call_gather-system-info'}";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "sc", value1 => $shell_call,
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
			$conf->{sys}{'local'}{hostname} = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "hostname", value1 => $conf->{sys}{'local'}{hostname},
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
				$conf->{sys}{'local'}{ifn}{ip} = $value;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "Found IFN IP", value1 => $conf->{sys}{'local'}{ifn}{ip},
				}, file => $THIS_FILE, line => __LINE__});
			}
			if (($variable eq "ip") && ($interface =~ /bcn/))
			{
				next if $value eq "?";
				$conf->{sys}{'local'}{bcn}{ip} = $value;
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "Found BCN IP", value1 => $conf->{sys}{'local'}{bcn}{ip},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	close $file_handle;
	
	# Now see if we have RHEL, CentOS and/or generic repos setup.
	$conf->{sys}{'local'}{repo}{centos}  = 0;
	$conf->{sys}{'local'}{repo}{generic} = 0;
	$conf->{sys}{'local'}{repo}{rhel}    = 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "Looking for", value1 => $conf->{path}{repo_centos},
	}, file => $THIS_FILE, line => __LINE__});
	if (-e $conf->{path}{repo_centos})
	{
		$conf->{sys}{'local'}{repo}{centos} = 1;
		$an->Log->entry({log_level => 3, message_key => "log_0040", message_variables => {
			type => "CentOS", 
		}, file => $THIS_FILE, line => __LINE__});
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "Looking for", value1 => $conf->{path}{repo_generic},
	}, file => $THIS_FILE, line => __LINE__});
	if (-e $conf->{path}{repo_generic})
	{
		$conf->{sys}{'local'}{repo}{generic} = 1;
		$an->Log->entry({log_level => 3, message_key => "log_0040", message_variables => {
			type => "generic", 
		}, file => $THIS_FILE, line => __LINE__});
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "Looking for", value1 => $conf->{path}{repo_rhel},
	}, file => $THIS_FILE, line => __LINE__});
	if (-e $conf->{path}{repo_rhel})
	{
		$conf->{sys}{'local'}{repo}{rhel} = 1;
		$an->Log->entry({log_level => 3, message_key => "log_0040", message_variables => {
			type => "RHEL", 
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	return(0);
}

# See if the node is in a cluster already. If so, we'll set a flag to block reboots if needed.
sub check_if_in_cluster
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_if_in_cluster" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $shell_call = "
if [ -e '/etc/init.d/cman' ];
then 
    /etc/init.d/cman status; echo rc:\$?; 
else 
    echo 'not in a cluster'; 
fi";
	# rc == 0; in a cluster
	# rc == 3; NOT in a cluster
	# Node 1
	if (1)
	{
		my $node                            = $conf->{cgi}{anvil_node1_current_ip};
		   $conf->{node}{$node}{in_cluster} = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call",                  value1 => $shell_call,
			name2 => "cgi::anvil_node1_current_ip", value2 => $conf->{cgi}{anvil_node1_current_ip},
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$conf->{cgi}{anvil_node1_current_ip},
			port		=>	$conf->{node}{$node}{port}, 
			password	=>	$conf->{cgi}{anvil_node1_current_password},
			ssh_fh		=>	"",
			'close'		=>	0,
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
					name1 => "node", value1 => $conf->{cgi}{anvil_node1_current_ip},
					name2 => "rc",   value2 => $rc,
				}, file => $THIS_FILE, line => __LINE__});
				if ($rc eq "0")
				{
					# It's in a cluster.
					$conf->{node}{$node}{in_cluster} = 1;
				}
			}
			else
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node", value1 => $conf->{cgi}{anvil_node1_current_ip},
					name2 => "line", value2 => $line,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	# Node 2
	if (1)
	{
		my $node                            = $conf->{cgi}{anvil_node2_current_ip};
		   $conf->{node}{$node}{in_cluster} = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call",                  value1 => $shell_call,
			name2 => "cgi::anvil_node2_current_ip", value2 => $conf->{cgi}{anvil_node2_current_ip},
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$conf->{cgi}{anvil_node2_current_ip},
			port		=>	$conf->{node}{$node}{port}, 
			password	=>	$conf->{cgi}{anvil_node2_current_password},
			ssh_fh		=>	"",
			'close'		=>	0,
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
					name1 => "node", value1 => $conf->{cgi}{anvil_node2_current_ip},
					name2 => "rc",   value2 => $rc,
				}, file => $THIS_FILE, line => __LINE__});
				if ($rc eq "0")
				{
					# It's in a cluster.
					$conf->{node}{$node}{in_cluster} = 1;
				}
			}
			else
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node", value1 => $conf->{cgi}{anvil_node2_current_ip},
					name2 => "line", value2 => $line,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	return(0);
}

# Check to see if the created Anvil! is in the configuration yet.
sub check_config_for_anvil
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_config_for_anvil" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $anvil_configured = 0;
	foreach my $cluster (sort {$a cmp $b} keys %{$conf->{cluster}})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "cgi::anvil_name",           value1 => $conf->{cgi}{anvil_name},
			name2 => "cluster::${cluster}::name", value2 => $conf->{cluster}{$cluster}{name},
		}, file => $THIS_FILE, line => __LINE__});
		if ($conf->{cgi}{anvil_name} eq $conf->{cluster}{$cluster}{name})
		{
			# Match!
			$anvil_configured = 1;
			$an->Log->entry({log_level => 3, message_key => "log_0041", file => $THIS_FILE, line => __LINE__});
			last;
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil_configured", value1 => $anvil_configured,
	}, file => $THIS_FILE, line => __LINE__});
	return($anvil_configured);
}

# This manually starts DRBD, forcing one to primary if needed, configures clvmd, sets up the PVs and VGs, 
# creates the /shared LV, creates the GFS2 partition and configures fstab.
sub configure_storage_stage3
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_storage_stage3" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ok = 1;
	
	# Bring up DRBD
	my ($drbd_ok) = drbd_first_start($conf);
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "drbd_ok", value1 => $drbd_ok,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Start clustered LVM
	my $lvm_ok = 0;
	if ($drbd_ok)
	{
		# This will create the /dev/drbd{0,1} PVs and create the VGs on
		# them, if needed.
		($lvm_ok) = setup_lvm_pv_and_vgs($conf);
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "lvm_ok", value1 => $lvm_ok,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Create GFS2 partition
		my $gfs2_ok = 0;
		if ($lvm_ok)
		{
			($gfs2_ok) = setup_gfs2($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "gfs2_ok", value1 => $gfs2_ok,
			}, file => $THIS_FILE, line => __LINE__});
			# Create /shared, mount partition
			# Appeand gfs2 entry to fstab
			# Check that /etc/init.d/gfs2 status works
			
			if ($gfs2_ok)
			{
				# Start gfs2 on both nodes, including
				# subdirectories and SELinux contexts on
				# /shared.
				my ($configure_ok) = configure_gfs2($conf);
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "configure_ok", value1 => $configure_ok,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# das failed ;_;
				$ok = 0;
			}
		}
		else
		{
			# Oh the huge manatee!
			$ok = 0;
		}
	}
	else
	{
		$ok = 0;
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	if ($ok)
	{
		# Start rgmanager, making sure it comes up
		my ($node1_rc) = start_rgmanager_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
		my ($node2_rc) = start_rgmanager_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node1_rc", value1 => $node1_rc,
			name2 => "node2_rc", value2 => $node2_rc,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Go into a loop waiting for the rgmanager services to either
		# start or fail.
		my ($clustat_ok) = watch_clustat($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "clustat_ok", value1 => $clustat_ok,
		}, file => $THIS_FILE, line => __LINE__});
		if (not $clustat_ok)
		{
			$an->Log->entry({log_level => 1, message_key => "log_0042", file => $THIS_FILE, line => __LINE__});
			$ok = 0;
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This watches clustat for up to 300 seconds for the storage and libvirt services to start (or fail).
sub watch_clustat
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "watch_clustat" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
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
	my $abort_time    = time + $conf->{sys}{clustat_timeout};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "time",       value1 => ".time.",
		name2 => "abort_time", value2 => $abort_time,
	}, file => $THIS_FILE, line => __LINE__});
	until ($services_seen)
	{
		# Call and parse 'clustat'
		my $shell_call = "clustat | grep service";
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
				# If it's not started or failed, I am not
				# interested in it.
				next if (($state ne "failed") && ($state ne "disabled") && ($state ne "started"));
				if ($service eq "libvirtd_n01")
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "service",                value1 => $service,
						name2 => "state",                  value2 => $state,
						name3 => "restarted_n01_libvirtd", value3 => $restarted_n01_libvirtd,
					}, file => $THIS_FILE, line => __LINE__});
					if (($state eq "failed") && (not $restarted_n01_libvirtd))
					{
						$restarted_n01_libvirtd = 1;
						restart_rgmanager_service($conf, $node, $password, $service, "restart");
					}
					elsif (($state eq "disabled") && (not $restarted_n01_libvirtd))
					{
						$restarted_n01_libvirtd = 1;
						restart_rgmanager_service($conf, $node, $password, $service, "start");
					}
					elsif (($state eq "started") || ($restarted_n01_libvirtd))
					{
						$n01_libvirtd = $state;
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
						restart_rgmanager_service($conf, $node, $password, $service, "restart");
					}
					elsif (($state eq "disabled") && (not $restarted_n02_libvirtd))
					{
						$restarted_n02_libvirtd = 1;
						restart_rgmanager_service($conf, $node, $password, $service, "start");
					}
					elsif (($state eq "started") || ($restarted_n02_libvirtd))
					{
						$n02_libvirtd = $state;
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
						restart_rgmanager_service($conf, $node, $password, $service, "restart");
					}
					elsif (($state eq "disabled") && (not $restarted_n01_storage))
					{
						$restarted_n01_storage = 1;
						restart_rgmanager_service($conf, $node, $password, $service, "start");
					}
					elsif (($state eq "started") || ($restarted_n01_storage))
					{
						$n01_storage = $state;
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
						restart_rgmanager_service($conf, $node, $password, $service, "restart");
					}
					elsif (($state eq "disabled") && (not $restarted_n02_storage))
					{
						$restarted_n02_storage = 1;
						restart_rgmanager_service($conf, $node, $password, $service, "start");
					}
					elsif (($state eq "started") || ($restarted_n02_storage))
					{
						$n02_storage = $state;
					}
				}
			}
		}
		
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
	if ($services_seen)
	{
		if (($n01_storage =~ /failed/) || ($n01_storage =~ /disabled/))
		{
			$node1_class   = "highlight_warning_bold";
			$node1_message = "#!string!state_0018!#";
			$ok            = 0;
		}
		if (($n02_storage =~ /failed/) || ($n02_storage =~ /disabled/))
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
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0264!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	# And now libvirtd
	$node1_class   = "highlight_good_bold";
	$node1_message = "#!string!state_0014!#";
	$node2_class   = "highlight_good_bold";
	$node2_message = "#!string!state_0014!#";
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
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0265!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This will call disable -> enable on a given service to try and recover if from a 'failed' state.
sub restart_rgmanager_service
{
	my ($conf, $node, $password, $service, $do) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "restart_rgmanager_service" }, message_key => "an_variables_0003", message_variables => { 
		name1 => "node",    value1 => $node, 
		name2 => "service", value2 => $service, 
		name3 => "do",      value3 => $do, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# This is something of a 'hail mary' pass, so not much sanity checking
	# is done (yet).
	my $shell_call = "clusvcadm -d $service && sleep 2 && clusvcadm -F -e $service";
	if ($do eq "start")
	{
		$shell_call = "clusvcadm -F -e $service";
	}
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
	}
	
	return(0);
}

# This starts rgmanager on both a node
sub start_rgmanager_on_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "start_rgmanager_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $ok = 1;
	my $shell_call = "/etc/init.d/rgmanager start; echo rc:\$?";
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
		
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			if ($rc eq "0")
			{
				$an->Log->entry({log_level => 2, message_key => "log_0044", message_variables => {
					service     => "rgmanager", 
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				$an->Log->entry({log_level => 1, message_key => "log_0045", message_variables => {
					service     => "rgmanager", 
					return_code => $?, 
				}, file => $THIS_FILE, line => __LINE__});
				$ok = 0;
			}
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This handles starting (and configuring) GFS2 on the nodes.
sub configure_gfs2
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_gfs2" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ok = 1;
	my ($node1_rc) = setup_gfs2_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_rc) = setup_gfs2_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_rc", value1 => $node1_rc,
		name2 => "node2_rc", value2 => $node2_rc,
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
	if ($node1_rc eq "1")
	{
		$node1_message = "#!string!state_0028!#";
	}
	elsif ($node1_rc eq "2")
	{
		# Failed to mount /shared
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0091!#";
		$ok            = 0;
	}
	elsif ($node1_rc eq "3")
	{
		# GFS2 LSB check failed
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0092!#";
		$ok            = 0;
	}
	elsif ($node1_rc eq "4")
	{
		# Failed to create subdirectory/ies
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0093!#";
		$ok            = 0;
	}
	elsif ($node1_rc eq "5")
	{
		# Failed to update SELinux context
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0094!#";
		$ok            = 0;
	}
	elsif ($node1_rc eq "6")
	{
		# Failed to update SELinux context
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0095!#";
		$ok            = 0;
	}
	# Node 2
	if ($node2_rc eq "1")
	{
		$node2_message = "#!string!state_0028!#";
	}
	elsif ($node2_rc eq "2")
	{
		# Failed to mount /shared
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0091!#";
		$ok            = 0;
	}
	elsif ($node2_rc eq "3")
	{
		# GFS2 LSB check failed
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0092!#";
		$ok            = 0;
	}
	elsif ($node2_rc eq "4")
	{
		# Failed to create subdirectory/ies
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0093!#";
		$ok            = 0;
	}
	elsif ($node2_rc eq "5")
	{
		# Failed to update SELinux context
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0094!#";
		$ok            = 0;
	}
	elsif ($node2_rc eq "6")
	{
		# Failed to update SELinux context
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0095!#";
		$ok            = 0;
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0268!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This will manually mount the GFS2 partition on the node, configuring /etc/fstab in the process if needed.
sub setup_gfs2_on_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "setup_gfs2_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If I have the UUID, then check/set fstab
	my $return_code = 0;
	
	# Make sure the '/shared' directory exists.
	my $shell_call = "
if [ -e '/shared' ];
then 
	echo '/shared exists';
else 
	mkdir /shared;
	echo '/shared created'
fi";
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
	}

	# Append the gfs2 partition to /etc/fstab if needed.
	if ($conf->{sys}{shared_fs_uuid})
	{
		my $append_ok    = 0;
		my $fstab_string = "UUID=$conf->{sys}{shared_fs_uuid} /shared gfs2 defaults,noatime,nodiratime 0 0";
		$shell_call   = "
if \$(grep -q shared /etc/fstab)
then
    echo 'shared exists'
else
    echo \"$fstab_string\" >> /etc/fstab
    if \$(grep -q shared /etc/fstab)
    then
        echo 'shared added'
    else
        echo 'failed to add shared'
    fi
fi";
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
			my $shell_call = "mount /shared; echo \$?";
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
				
				if ($line =~ /^rc:(\d+)/)
				{
					my $rc = $1;
					if ($rc eq "0")
					{
						# Success
						$an->Log->entry({log_level => 2, message_key => "log_0047", file => $THIS_FILE, line => __LINE__});
					}
					else
					{
						# Failed to mount
						$an->Log->entry({log_level => 1, message_key => "log_0048", message_variables => {
							return_code => $rc, 
						}, file => $THIS_FILE, line => __LINE__});
						$return_code = 2;
					}
				}
			}
			
			# Finally, test '/etc/init.d/gfs2 status'
			if ($return_code ne "2")
			{
				my $shell_call = "/etc/init.d/gfs2 status; echo \$?";
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
					
					if ($line =~ /^rc:(\d+)/)
					{
						my $rc = $1;
						if ($rc eq "0")
						{
							# Success
							$an->Log->entry({log_level => 2, message_key => "log_0049", file => $THIS_FILE, line => __LINE__});
						}
						else
						{
							# The GFS2 LSB script failed to see the '/shared' file system.
							$an->Log->entry({log_level => 1, message_key => "log_0050", message_variables => {
								return_code => $rc, 
							}, file => $THIS_FILE, line => __LINE__});
							$return_code = 3;
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
			foreach my $directory (@{$conf->{path}{nodes}{shared_subdirectories}})
			{
				next if not $directory;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "directory", value1 => $directory,
				}, file => $THIS_FILE, line => __LINE__});
				my $shell_call = "
if [ -e '/shared/$directory' ]
then
    echo '/shared/$directory already exists'
else
    mkdir /shared/$directory; echo rc:\$?
fi";
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
					
					if ($line =~ /^rc:(\d+)/)
					{
						my $rc = $1;
						if ($rc eq "0")
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
								return_code => $rc, 
							}, file => $THIS_FILE, line => __LINE__});
							$return_code = 4;
						}
					}
				}
			}
		}
		
		# Setup SELinux context on /shared
		if (not $return_code)
		{
			my $shell_call = "
context=\$(ls -laZ /shared | grep ' .\$' | awk '{print \$4}' | awk -F : '{print \$3}');
if [ \$context == 'file_t' ];
then
    semanage fcontext -a -t virt_etc_t '/shared(/.*)?' 
    restorecon -r /shared
    context=\$(ls -laZ /shared | grep ' .\$' | awk '{print \$4}' | awk -F : '{print \$3}');
    if [ \$context == 'virt_etc_t' ];
    then
        echo 'context updated'
    else
        echo \"context failed to update, still: \$context.\"
    fi
else 
    echo 'context ok';
fi";
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

# This checks for and creates the GFS2 /shared partition if necessary
sub setup_gfs2
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "setup_gfs2" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my ($lv_ok) = create_shared_lv($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
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
		my $shell_call = "gfs2_tool sb /dev/$conf->{sys}{vg_pool1_name}/shared uuid; echo rc:\$?";
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
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($line =~ /current uuid = (.*)$/)
			{
				# This will be useful later in the fstab stage
				$conf->{sys}{shared_fs_uuid} = $1;
				$conf->{sys}{shared_fs_uuid} = lc($conf->{sys}{shared_fs_uuid});
				$an->Log->entry({log_level => 2, message_key => "log_0056", message_variables => {
					device => "/dev/$conf->{sys}{vg_pool1_name}/shared", 
					uuid   => "$conf->{sys}{shared_fs_uuid}", 
				}, file => $THIS_FILE, line => __LINE__});
				$create_gfs2 = 0;
				$return_code = 1;
			}
			if ($line =~ /^rc:(\d+)/)
			{
				my $rc = $1;
				if ($rc eq "0")
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
		if (($create_gfs2) && (not $conf->{sys}{shared_fs_uuid}))
		{
			my $shell_call = "mkfs.gfs2 -p lock_dlm -j 2 -t $conf->{cgi}{anvil_name}:shared /dev/$conf->{sys}{vg_pool1_name}/shared -O; echo rc:\$?";
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
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				$line =~ s/\s+/ /g;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /UUID:\s+(.*)$/)
				{
					# This will be useful later in the fstab stage
					$conf->{sys}{shared_fs_uuid} = $1;
					$conf->{sys}{shared_fs_uuid} = lc($conf->{sys}{shared_fs_uuid});
					$an->Log->entry({log_level => 2, message_key => "log_0059", message_variables => {
						device => "/dev/$conf->{sys}{vg_pool1_name}/shared", 
						uuid   => "$conf->{sys}{shared_fs_uuid}", 
					}, file => $THIS_FILE, line => __LINE__});
					$create_gfs2 = 0;
				}
				if ($line =~ /^rc:(\d+)/)
				{
					my $rc = $1;
					if ($rc eq "0")
					{
						# GFS2 FS created
						$an->Log->entry({log_level => 2, message_key => "log_0060", file => $THIS_FILE, line => __LINE__});
					}
					else
					{
						# Format appears to have failed.
						$an->Log->entry({log_level => 1, message_key => "log_0061", message_variables => {
							device      => "/dev/$conf->{sys}{vg_pool1_name}/shared", 
							return_code => $rc, 
						}, file => $THIS_FILE, line => __LINE__});
						$return_code = 2;
					}
				}
			}
		}
		
		# Back to working on both nodes.
		
		
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
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message-wide", {
			row	=>	"#!string!row_0263!#",
			class	=>	$class,
			message	=>	$message,
		});
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

# The checks and, if needed, creates the LV for the GFS2 /shared partition
sub create_shared_lv
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "create_shared_lv" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return_code = 0;
	my $create_lv   = 1;
	my $shell_call  = "lvs --noheadings --separator ,; echo rc:\$?";
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
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			if ($rc ne "0")
			{
				# pvs failed...
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "Unable to check LVs. The 'lvs' call exited with return code", value1 => $rc,
				}, file => $THIS_FILE, line => __LINE__});
				$create_lv   = 0;
				$return_code = 2;
			}
		}
		if ($line =~ /^shared,/)
		{
			# Found the LV, pull out the VG
			$conf->{sys}{vg_pool1_name} = ($line =~ /^shared,(.*?),/)[0];
			$create_lv   = 0;
			$return_code = 1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "The LV for the shared GFS2 partition already exists on VG", value1 => $conf->{sys}{vg_pool1_name},
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
		my $lv_size    =  AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_media_library_byte_size});
		   $lv_size    =~ s/ //;
		my $shell_call = "lvcreate -L $lv_size -n shared $conf->{sys}{vg_pool1_name}; echo rc:\$?";
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
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line =~ /^rc:(\d+)/)
			{
				my $rc = $1;
				if ($rc eq "0")
				{
					# lvcreate succeeded
					$an->Log->entry({log_level => 2, message_key => "log_0062", file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# lvcreate failed
					$an->Log->entry({log_level => 1, message_key => "log_0063", message_variables => {
						return_code => $rc, 
					}, file => $THIS_FILE, line => __LINE__});
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
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message-wide", {
		row	=>	"#!string!row_0262!#",
		class	=>	$class,
		message	=>	$message,
	});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# The checks to see if either PV or VG needs to be created and does so if
# needed.
sub setup_lvm_pv_and_vgs
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "setup_lvm_pv_and_vgs" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Start 'clvmd' on both nodes.
	my $return_code = 0;
	my ($node1_rc) = start_clvmd_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_rc) = start_clvmd_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_rc", value1 => $node1_rc,
		name2 => "node2_rc", value2 => $node2_rc,
	}, file => $THIS_FILE, line => __LINE__});
	# 0 = Started
	# 1 = Already running
	# 2 = Failed
	
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0014!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0014!#";
	if ($node1_rc eq "1")
	{
		$node1_message = "#!string!state_0078!#";
	}
	elsif ($node1_rc eq "2")
	{
		# Failed to start clvmd
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0123!#";
		$ok            = 0;
	}
	if ($node2_rc eq "1")
	{
		$node2_message = "#!string!state_0078!#";
	}
	elsif ($node2_rc eq "2")
	{
		# Failed to start clvmd
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0123!#";
		$ok            = 0;
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0259!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	# =======
	# Below here, we switch to displaying one status per line
	
	# PV messages
	if (($node1_rc ne "2") && ($node2_rc ne "2"))
	{
		# Excellent, create the PVs if needed.
		my ($pv_rc) = create_lvm_pvs($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "pv_rc", value1 => $pv_rc,
		}, file => $THIS_FILE, line => __LINE__});
		# 0 == OK
		# 1 == already existed
		# 2 == Failed
		
		my $class   = "highlight_good_bold";
		my $message = "#!string!state_0045!#";
		if ($pv_rc == "1")
		{
			# Already existed
			$message = "#!string!state_0020!#";
		}
		elsif ($pv_rc == "2")
		{
			# Failed create PV
			$class   = "highlight_warning_bold";
			$message = "#!string!state_0018!#";
			$ok      = 0;
		}
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message-wide", {
			row	=>	"#!string!row_0260!#",
			class	=>	$class,
			message	=>	$message,
		});

		# Now create the VGs
		my $vg_rc = 0;
		if ($pv_rc ne "2")
		{
			# Create the VGs
			($vg_rc) = create_lvm_vgs($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "vg_rc", value1 => $vg_rc,
			}, file => $THIS_FILE, line => __LINE__});
			# 0 == OK
			# 1 == already existed
			# 2 == Failed
			
			my $ok      = 1;
			my $class   = "highlight_good_bold";
			my $message = "#!string!state_0045!#";
			if ($vg_rc == "1")
			{
				# Already existed
				$message = "#!string!state_0020!#";
			}
			elsif ($vg_rc == "2")
			{
				# Failed create PV
				$class   = "highlight_warning_bold";
				$message = "#!string!state_0018!#";
				$ok      = 0;
			}
			print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message-wide", {
				row	=>	"#!string!row_0261!#",
				class	=>	$class,
				message	=>	$message,
			});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This creates the VGs if needed
sub create_lvm_vgs
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "create_lvm_vgs" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If a VG name exists, use it. Otherwise, use the generated names
	# below.
	my ($node1_short_name)      = ($conf->{cgi}{anvil_node1_name} =~ /^(.*?)\./);
	my ($node2_short_name)      = ($conf->{cgi}{anvil_node2_name} =~ /^(.*?)\./);
	$conf->{sys}{vg_pool1_name} = "${node1_short_name}_vg0";
	$conf->{sys}{vg_pool2_name} = "${node2_short_name}_vg0";
	
	# Check which, if any, VGs exist.
	my $return_code = 0;
	my $create_vg0  = 1;
	my $create_vg1  = $conf->{cgi}{anvil_storage_pool2_byte_size} ? 1 : 0;
	
	# Calling 'pvs' again, but this time we're digging out the VG name
	my $shell_call   = "pvs --noheadings --separator ,; echo rc:\$?";
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
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			if ($rc ne "0")
			{
				# pvs failed...
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "Unable to check which LVM PVs exist. The 'pvs' call exited with return code", value1 => $rc,
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
				$conf->{sys}{vg_pool1_name} = $1;
				$create_vg0                 = 0;
				$an->Log->entry({log_level => 2, message_key => "log_0065", message_variables => {
					pool   => "1",
					device => $conf->{sys}{vg_pool1_name}, 
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
				$conf->{sys}{vg_pool2_name} = $1;
				$create_vg1                 = 0;
				$an->Log->entry({log_level => 2, message_key => "log_0065", message_variables => {
					pool   => "2",
					device => $conf->{sys}{vg_pool1_name}, 
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
		my $shell_call = "vgcreate $conf->{sys}{vg_pool1_name} /dev/drbd0; echo rc:\$?";
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
			
			if ($line =~ /^rc:(\d+)/)
			{
				my $rc = $1;
				if ($rc eq "0")
				{
					# Success
					$an->Log->entry({log_level => 2, message_key => "log_0066", message_variables => {
						pool   => "1", 
						device => $conf->{sys}{vg_pool1_name}, 
						pv     => "/dev/drbd0",
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Failed
					$an->Log->entry({log_level => 1, message_key => "log_0067", message_variables => {
						pool        => "1", 
						device      => $conf->{sys}{vg_pool1_name}, 
						pv          => "/dev/drbd0",
						return_code => $rc, 
					}, file => $THIS_FILE, line => __LINE__});
					$return_code = 2;
				}
			}
		}
	}
	# PV for pool 2
	if (($conf->{cgi}{anvil_storage_pool2_byte_size}) && ($create_vg1))
	{
		my $shell_call = "vgcreate $conf->{sys}{vg_pool2_name} /dev/drbd1; echo rc:\$?";
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
			
			if ($line =~ /^rc:(\d+)/)
			{
				my $rc = $1;
				if ($rc eq "0")
				{
					# Success
					$an->Log->entry({log_level => 2, message_key => "log_0066", message_variables => {
						pool   => "2", 
						device => $conf->{sys}{vg_pool1_name}, 
						pv     => "/dev/drbd1",
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Failed
					$an->Log->entry({log_level => 1, message_key => "log_0067", message_variables => {
						pool        => "2", 
						device      => $conf->{sys}{vg_pool1_name}, 
						pv          => "/dev/drbd1",
						return_code => $rc, 
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
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "create_lvm_pvs" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: This seems to occassionally see only the first PV despite
	###       both existing. Unable to reproduce on the shell.
	# Check which, if any, PVs exist.
	my $return_code  = 0;
	my $found_drbd0  = 0;
	my $create_drbd0 = 1;
	my $found_drbd1  = 0;
	my $create_drbd1 = $conf->{cgi}{anvil_storage_pool2_byte_size} ? 1 : 0;

	#my $shell_call   = "pvs --noheadings --separator ,; echo rc:\$?";
	my $shell_call   = "pvscan; echo rc:\$?";
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
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			if ($rc ne "0")
			{
				# pvs failed...
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "Unable to check which LVM PVs exist. The 'pvs' call exited with return code", value1 => $rc,
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
		my $shell_call = "pvcreate /dev/drbd0; echo rc:\$?";
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
			
			if ($line =~ /^rc:(\d+)/)
			{
				my $rc = $1;
				if ($rc eq "0")
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
						return_code => $rc, 
					}, file => $THIS_FILE, line => __LINE__});
					$return_code = 2;
				}
			}
		}
	}
	# PV for pool 2
	if (($conf->{cgi}{anvil_storage_pool2_byte_size}) && ($create_drbd1))
	{
		my $shell_call = "pvcreate /dev/drbd1; echo rc:\$?";
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
			
			if ($line =~ /^rc:(\d+)/)
			{
				my $rc = $1;
				if ($rc eq "0")
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
						return_code => $rc, 
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
	elsif (($found_drbd0) && (not $conf->{cgi}{anvil_storage_pool2_byte_size}))
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

# This starts 'clvmd' on a node if it's not already running.
sub start_clvmd_on_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "start_clvmd_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return_code = 255;
	my $shell_call  = "
/etc/init.d/clvmd status &>/dev/null; 
if [ \$? == 3 ];
then 
    /etc/init.d/clvmd start; echo rc:\$?;
else 
    echo 'clvmd already running';
fi";
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
		
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			if ($rc eq "0")
			{
				# clvmd was started
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "Started clvmd on", value1 => $node,
				}, file => $THIS_FILE, line => __LINE__});
				$return_code = 0;
			}
			else
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "Failed to start clvmd on", value1 => $node,
				}, file => $THIS_FILE, line => __LINE__});
				$return_code = 2;
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

# This is used by the stage-3 storage function to bring up DRBD
sub drbd_first_start
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "drbd_first_start" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $return_code = 255;
	
	# Start DRBD manually and if both nodes are Inconsistent for a given resource, run;
	# drbdadm -- --overwrite-data-of-peer primary <res>
	my ($node1_attach_rc, $node1_attach_message) = do_drbd_attach_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_attach_rc, $node2_attach_message) = do_drbd_attach_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node1_attach_rc",      value1 => $node1_attach_rc,
		name2 => "node1_attach_message", value2 => $node1_attach_message,
		name3 => "node2_attach_rc",      value3 => $node2_attach_rc,
		name4 => "node2_attach_message", value4 => $node2_attach_message,
	}, file => $THIS_FILE, line => __LINE__});
	# 0 == Success
	# 1 == Failed to load kernel module
	# 2 == One of the resources is Diskless
	# 3 == Attach failed.
	# 4 == Failed to install 'wait-for-drbd'
	
	# Call 'wait-for-drbd' on node 1 so that we don't move on to clvmd before DRBD (its PV) is ready.
	my $node       = $conf->{cgi}{anvil_node1_current_ip};
	my $password   = $conf->{cgi}{anvil_node1_current_password};
	my $shell_call = "$conf->{path}{nodes}{'wait-for-drbd_initd'} start";
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
	}
	
	# Ping variables
	my $node1_ping_ok = "";
	my $node2_ping_ok = "";
	
	# Connect variables
	my $node1_connect_rc      = 255;
	my $node1_connect_message = "";
	my $node2_connect_rc      = 255;
	my $node2_connect_message = "";
	
	# Primary variables
	my $node1_primary_rc      = 255;
	my $node1_primary_message = "";
	my $node2_primary_rc      = 255;
	my $node2_primary_message = "";
	
	# Time to work
	if (($node1_attach_rc eq "0") && ($node2_attach_rc eq "0"))
	{
		# Make sure we can ping the peer node over the SN
		($node1_ping_ok) = ping_node_from_other($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $conf->{cgi}{anvil_node2_sn_ip});
		($node2_ping_ok) = ping_node_from_other($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $conf->{cgi}{anvil_node1_sn_ip});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node1_ping_ok", value1 => $node1_ping_ok,
			name2 => "node2_ping_ok", value2 => $node2_ping_ok,
		}, file => $THIS_FILE, line => __LINE__});
		if (($node1_ping_ok) && ($node2_ping_ok))
		{
			# Both nodes have both of their resources attached and are pingable on the SN, 
			# Make sure they're not 'StandAlone' and, if so, tell them to connect.
			($node1_connect_rc, $node1_connect_message) = do_drbd_connect_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
			($node2_connect_rc, $node2_connect_message) = do_drbd_connect_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
				name1 => "node1_connect_rc",      value1 => $node1_connect_rc,
				name2 => "node1_connect_message", value2 => $node1_connect_message,
				name3 => "node2_connect_rc",      value3 => $node2_connect_rc,
				name4 => "node2_connect_message", value4 => $node2_connect_message,
			}, file => $THIS_FILE, line => __LINE__});
			# 0 == OK
			# 1 == Failed to connect
			
			# Finally, make primary
			if ((not $node1_connect_rc) || (not $node2_connect_rc))
			{
				# Make sure both nodes are, indeed, connected.
				my ($rc) = verify_drbd_resources_are_connected($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "rc", value1 => $rc,
				}, file => $THIS_FILE, line => __LINE__});
				# 0 == OK
				# 1 == Failed to connect
				
				if (not $rc)
				{
					# Check to see if both nodes are 'Inconsistent'. If so, force node 1
					# to be primary to begin the initial sync.
					my ($rc, $force_node1_r0, $force_node1_r1) = check_drbd_if_force_primary_is_needed($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "rc",             value1 => $rc,
						name2 => "force_node1_r0", value2 => $force_node1_r0,
						name3 => "force_node1_r1", value3 => $force_node1_r1,
					}, file => $THIS_FILE, line => __LINE__});
					# 0 == Both resources found, safe to proceed
					# 1 == One or both of the resources not found
					
					# This RC check is just a little paranoia before doing a potentially
					# destructive call.
					if (not $rc)
					{
						# Promote to primary!
						($node1_primary_rc, $node1_primary_message) = do_drbd_primary_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $force_node1_r0, $force_node1_r1);
						($node2_primary_rc, $node2_primary_message) = do_drbd_primary_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, "0", "0");
						$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
							name1 => "node1_primary_rc",      value1 => $node1_primary_rc,
							name2 => "node1_primary_message", value2 => $node1_primary_message,
							name3 => "node2_primary_rc",      value3 => $node2_primary_rc,
							name4 => "node2_primary_message", value4 => $node2_primary_message,
						}, file => $THIS_FILE, line => __LINE__});
						# 0 == OK
						# 1 == Failed to make primary
						if ((not $node1_primary_rc) || (($conf->{cgi}{anvil_storage_pool2_byte_size}) && (not $node2_primary_rc)))
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
	elsif (($node1_attach_rc eq "4") or ($node2_attach_rc eq "4"))
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
	my $ok = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0014!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0014!#";
	# Node messages are interleved
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	if ($return_code eq "1")
	{
		# Attach failed
		if ($node1_attach_message)
		{
			$node1_class   = "highlight_warning_bold";
			$node1_message = AN::Common::get_string($conf, {key => "state_0083", variables => { message => "$node1_attach_message" }});
		}
		if ($node2_attach_message)
		{
			$node2_class   = "highlight_warning_bold";
			$node2_message = AN::Common::get_string($conf, {key => "state_0083", variables => { message => "$node2_attach_message" }});
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
				if ($node1_attach_rc eq "4")
				{
					$node1_message = "#!string!state_0116!#";
				}
				if ($node2_attach_rc eq "4")
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
			$node1_message = AN::Common::get_string($conf, {key => "state_0085", variables => { message => "$node1_connect_message" }});
		}
		if ($node2_connect_message)
		{
			$node2_class   = "highlight_warning_bold";
			$node2_message = AN::Common::get_string($conf, {key => "state_0085", variables => { message => "$node2_connect_message" }});
		}
		if ((not $node1_connect_message) && (not $node2_connect_message))
		{
			# Neither node had a connection error, so set both to
			# generic error state.
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
			$node1_message = AN::Common::get_string($conf, {key => "state_0087", variables => { message => "$node1_primary_message" }});
		}
		if ($node2_primary_message)
		{
			$node2_class   = "highlight_warning_bold";
			$node2_message = AN::Common::get_string($conf, {key => "state_0087", variables => { message => "$node2_primary_message" }});
		}
		if ((not $node1_primary_message) && (not $node2_primary_message))
		{
			# Neither node had a promotion error, so set both to
			# generic error state.
			$node1_class   = "highlight_warning_bold";
			$node1_message = "#!string!state_0088!#";
			$node2_class   = "highlight_warning_bold";
			$node2_message = "#!string!state_0088!#";
		}
		$ok = 0;
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0258!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	# Things seem a little racy, so we'll sleep here a touch if things are
	# OK just to be sure DRBD is really ready.
	if ($ok)
	{
		sleep 5;
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This connects to node 1 and checks to ensure both resource are in the 'Connected' state.
sub verify_drbd_resources_are_connected
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "verify_drbd_resources_are_connected" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Give the previous start call a few seconds to take effect.
	sleep 5;
	
	# Ok, go.
	my $return_code  = 0;
	my $r0_connected = 0;
	my $r1_connected = 0;
	my $shell_call   = "cat /proc/drbd";
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
		$line =~ s/^\s+//;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^0: /)
		{
			my $connected_state = ($line =~ /cs:(.*?)\s/)[0];
			if (($connected_state =~ /Connected/i) || ($connected_state =~ /Sync/i))
			{
				# Connected
				$r0_connected = 1;
				$an->Log->entry({log_level => 2, message_key => "log_0081", message_variables => {
					resource => "r0", 
				}, file => $THIS_FILE, line => __LINE__});
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
			if (($connected_state =~ /Connected/i) || ($connected_state =~ /Sync/i))
			{
				# Connected
				$r1_connected = 1;
				$an->Log->entry({log_level => 2, message_key => "log_0081", message_variables => {
					resource => "r1", 
				}, file => $THIS_FILE, line => __LINE__});
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
	if ((not $r0_connected) || (($conf->{cgi}{anvil_storage_pool2_byte_size}) && (not $r1_connected)))
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

# This promotes the DRBD resources to Primary, forcing if needed.
sub do_drbd_primary_on_node
{
	my ($conf, $node, $password, $force_r0, $force_r1) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "do_drbd_primary_on_node" }, message_key => "an_variables_0003", message_variables => { 
		name1 => "node",     value1 => $node, 
		name2 => "force_r0", value2 => $force_r0, 
		name3 => "force_r1", value3 => $force_r1, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Resource 0
	my $return_code = 0;
	my $message     = "";
	my $shell_call  = "$conf->{path}{nodes}{drbdadm} primary r0; echo rc:\$?";
	if ($force_r0)
	{
		$an->Log->entry({log_level => 2, message_key => "log_0084", message_variables => {
			resource => "r0", 
		}, file => $THIS_FILE, line => __LINE__});
		$shell_call = "$conf->{path}{nodes}{drbdadm} primary r0 --force; echo rc:\$?";
	}
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
		
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			if ($rc eq "0")
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
				$message .= AN::Common::get_string($conf, {key => "message_0400", variables => { resource => "r0", node => $node }});
				$return_code = 1;
			}
		}
	}
	
	# Resource 1
	if ($conf->{cgi}{anvil_storage_pool2_byte_size})
	{
		$shell_call  = "$conf->{path}{nodes}{drbdadm} primary r1; echo rc:\$?";
		if ($force_r0)
		{
			$an->Log->entry({log_level => 2, message_key => "log_0084", message_variables => {
				resource => "r1", 
			}, file => $THIS_FILE, line => __LINE__});
			$shell_call = "$conf->{path}{nodes}{drbdadm} primary r1 --force; echo rc:\$?";
		}
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
			
			if ($line =~ /^rc:(\d+)/)
			{
				my $rc = $1;
				if ($rc eq "0")
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
					$message .= AN::Common::get_string($conf, {key => "message_0400", variables => { resource => "r0", node => $node }});
					$return_code = 1;
				}
			}
		}
	}
	
	# If we're OK, call 'drbdadm adjust all' to make sure the requested
	# sync rate takes effect.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $return_code)
	{
		my $shell_call = "$conf->{path}{nodes}{drbdadm} adjust all";
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

# This uses node 1 to check the Connected disk states of the resources are both Inconsistent.
sub check_drbd_if_force_primary_is_needed
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_drbd_if_force_primary_is_needed" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return_code = 0;
	my $found_r0    = 0;
	my $force_r0    = 0;
	my $force_r1    = 0;
	my $found_r1    = 0;
	my $shell_call  = "cat /proc/drbd";
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
		$line =~ s/^\s+//;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^0: /)
		{
			# Resource found, check disk state, but
			# unless it's "Diskless", we're already
			# attached because unattached disks
			# cause the entry
			if ($line =~ /ds:(.*?)\/(.*?)\s/)
			{
				my $node1_ds = $1;
				my $node2_ds = $2;
				   $found_r0 = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "resource 'r0' disk states; node1", value1 => $node1_ds,
					name2 => "node2",                            value2 => $node2_ds,
				}, file => $THIS_FILE, line => __LINE__});
				if (($node1_ds =~ /Inconsistent/i) && ($node2_ds =~ /Inconsistent/i))
				{
					# Force
					$force_r0 = 1;
					$an->Log->entry({log_level => 2, message_key => "log_0087", message_variables => {
						resource => "r0", 
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Don't force
					$an->Log->entry({log_level => 2, message_key => "log_0088", message_variables => {
						resource => "r0", 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
		if ($line =~ /^1: /)
		{
			# Resource found, check disk state, but
			# unless it's "Diskless", we're already
			# attached because unattached disks
			# cause the entry
			if ($line =~ /ds:(.*?)\/(.*?)\s/)
			{
				my $node1_ds = $1;
				my $node2_ds = $2;
				   $found_r1 = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "resource 'r1' disk states; node1", value1 => $node1_ds,
					name2 => "node2",                            value2 => $node2_ds,
				}, file => $THIS_FILE, line => __LINE__});
				if (($node1_ds =~ /Inconsistent/i) && ($node2_ds =~ /Inconsistent/i))
				{
					# Force
					$force_r0 = 1;
					$an->Log->entry({log_level => 2, message_key => "log_0087", message_variables => {
						resource => "r1", 
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Don't force
					$an->Log->entry({log_level => 2, message_key => "log_0088", message_variables => {
						resource => "r1", 
					}, file => $THIS_FILE, line => __LINE__});
				}
			}
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "found_r0", value1 => $found_r0,
		name2 => "found_r1", value2 => $found_r1,
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $found_r0) || (($conf->{cgi}{anvil_storage_pool2_byte_size}) && (not $found_r1)))
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

# This calls 'connect' of each resource on a node.
sub do_drbd_connect_on_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "do_drbd_connect_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $message     = "";
	my $return_code = 0;
	foreach my $resource ("0", "1")
	{
		# Skip r1 if no pool 2.
		if (($resource eq "1") && (not $conf->{cgi}{anvil_storage_pool2_byte_size}))
		{
			next;
		}
		# See if the resource is already 'Connected' or 'WFConnection'
		my $connected  = 0;
		my $shell_call = "cat /proc/drbd";
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
					name2 => "resource",         value2 => "r$resource",
					name3 => "connection state", value3 => $connection_state,
				}, file => $THIS_FILE, line => __LINE__});
				if ($connection_state =~ /StandAlone/i)
				{
					# StandAlone, connect it.
					$an->Log->entry({log_level => 2, message_key => "log_0090", message_variables => {
						node     => $node, 
						resource => "r$resource", 
					}, file => $THIS_FILE, line => __LINE__});
					$connected = 0;
				}
				elsif ($connection_state)
				{
					# Already connected
					$an->Log->entry({log_level => 2, message_key => "log_0091", message_variables => {
						node             => $node, 
						resource         => "r$resource", 
						connection_state => $connection_state, 
					}, file => $THIS_FILE, line => __LINE__});
					$connected = 1;
				}
			}
		}
		
		# Now connect if needed.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node",      value1 => $node,
			name2 => "resource",  value2 => "r$resource",
			name3 => "connected", value3 => $connected,
		}, file => $THIS_FILE, line => __LINE__});
		if (not $connected)
		{
			my $shell_call = "$conf->{path}{nodes}{drbdadm} connect r$resource; echo rc:\$?";
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
				
				if ($line =~ /^rc:(\d+)/)
				{
					my $rc = $1;
					if ($rc eq "0")
					{
						# Success!
						$an->Log->entry({log_level => 2, message_key => "log_0092", message_variables => {
							node             => $node, 
							resource         => "r$resource", 
						}, file => $THIS_FILE, line => __LINE__});
					}
					else
					{
						# Failed to connect.
						$an->Log->entry({log_level => 1, message_key => "log_0093", message_variables => {
							node             => $node, 
							resource         => "r$resource", 
						}, file => $THIS_FILE, line => __LINE__});
						$message .= AN::Common::get_string($conf, {key => "message_0401", variables => { resource => "r$resource", node => $node }});
						$return_code = 1;
					}
				}
			}
		}
	
		# If requested by 'sys::install_manifest::default::immediate-uptodate', and if both nodes are
		# 'Inconsistent', force both nodes to be UpToDate/UpToDate.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "sys::install_manifest::default::immediate-uptodate", value1 => $conf->{sys}{install_manifest}{'default'}{'immediate-uptodate'},
		}, file => $THIS_FILE, line => __LINE__});
		if ($conf->{sys}{install_manifest}{'default'}{'immediate-uptodate'})
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
				my $shell_call = "cat /proc/drbd";
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
						if (($connection_state =~ /connected/i) || ($connection_state =~ /sync/i))
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
					node             => $node, 
					resource         => "r$resource", 
				}, file => $THIS_FILE, line => __LINE__});
				$message .= AN::Common::get_string($conf, {key => "message_0450", variables => { resource => "r$resource", node => $node }});
				$return_code = 1;
			}
			elsif ($force_uptodate)
			{
				my $shell_call = "
echo \"Forcing r$resource to 'UpToDate' on both nodes; 'sys::install_manifest::default::immediate-uptodate' set and both are currently Inconsistent.\"
$conf->{path}{nodes}{drbdadm} new-current-uuid --clear-bitmap r$resource/0
sleep 2
if \$(cat /proc/drbd | $conf->{path}{nodes}{grep} '$resource: cs' | awk '{print \$4}' | $conf->{path}{nodes}{grep} -q 'UpToDate/UpToDate'); 
then 
    echo success
else
    echo failed.
fi
";
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

# This attaches the backing devices on each node, modprobe'ing drbd if needed.
sub do_drbd_attach_on_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "do_drbd_attach_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $message     = "";
	my $return_code = 0;
	# First up, is the DRBD kernel module loaded and is the wait init.d
	# script in place?
	my $shell_call = "
if [ -e '/proc/drbd' ]; 
then 
    echo 'DRBD already loaded'; 
else 
    modprobe drbd; 
    if [ -e '/proc/drbd' ]; 
    then 
        echo 'loaded DRBD kernel module'; 
    else 
        echo 'failed to load drbd' 
    fi;
fi;
if [ ! -e '$conf->{path}{nodes}{'wait-for-drbd_initd'}' ];
then
    if [ -e '$conf->{path}{nodes}{'wait-for-drbd'}' ];
    then
        echo \"need to copy 'wait-for-drbd'\"
        cp $conf->{path}{nodes}{'wait-for-drbd'} $conf->{path}{nodes}{'wait-for-drbd_initd'};
        if [ ! -e '$conf->{path}{nodes}{'wait-for-drbd_initd'}' ];
        then
           echo \"Failed to copy 'wait-for-drbd' from: [$conf->{path}{nodes}{'wait-for-drbd'}] to: [$conf->{path}{nodes}{'wait-for-drbd_initd'}]\"
        else
           echo \"copied 'wait-for-drbd' successfully.\"
        fi
    else
        echo \"Failed to copy 'wait-for-drbd' from: [$conf->{path}{nodes}{'wait-for-drbd'}], source doesn't exist.\"
    fi
fi;
";
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
			if (($resource eq "1") && (not $conf->{cgi}{anvil_storage_pool2_byte_size}))
			{
				next;
			}
			
			# We may not find the resource in /proc/drbd is the
			# resource wasn't started before.
			my $attached = 0;
			my $shell_call = "cat /proc/drbd";
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
				$line =~ s/^\s+//;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "line", value1 => $line, 
				}, file => $THIS_FILE, line => __LINE__});
				
				if ($line =~ /^$resource: /)
				{
					# Resource found, check disk state, but
					# unless it's "Diskless", we're already
					# attached because unattached disks
					# cause the entry
					my $disk_state = ($line =~ /ds:(.*?)\//)[0];
					$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
						name1 => "node",       value1 => $node,
						name2 => "resource",   value2 => "r$resource",
						name3 => "disk state", value3 => $disk_state,
					}, file => $THIS_FILE, line => __LINE__});
					if ($disk_state =~ /Diskless/i)
					{
						# Failed disk/array?
						$an->Log->entry({log_level => 1, message_key => "log_0098", message_variables => {
							node     => $node, 
							resource => "r$resource",
						}, file => $THIS_FILE, line => __LINE__});
						$message .= AN::Common::get_string($conf, {key => "message_0399", variables => { resource => "r$resource", node => $node }});
						$attached = 2;
					}
					elsif ($disk_state)
					{
						# Already attached
						$an->Log->entry({log_level => 2, message_key => "log_0099", message_variables => {
							node     => $node, 
							resource => "r$resource",
						}, file => $THIS_FILE, line => __LINE__});
						$attached = 1;
					}
				}
			}
			
			# Now attach if needed.
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "node",     value1 => $node,
				name2 => "resource", value2 => "r$resource",
				name3 => "attached", value3 => $attached,
			}, file => $THIS_FILE, line => __LINE__});
			if (not $attached)
			{
				my $no_metadata = 0;
				my $shell_call  = "$conf->{path}{nodes}{drbdadm} up r$resource; echo rc:\$?";
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
					
					if ($line =~ /No valid meta-data signature found/i)
					{
						# No metadata found
						my $pool     = $resource eq "0" ? "pool1" : "pool2";
						my $device   = $conf->{node}{$node}{$pool}{device};
						$an->Log->entry({log_level => 1, message_key => "log_0100", message_variables => {
							node     => $node, 
							resource => "r$resource",
							pool     => $pool, 
							device   => $device, 
						}, file => $THIS_FILE, line => __LINE__});
						$no_metadata = 1;
						$return_code = 3;
						$message .= AN::Common::get_string($conf, {key => "message_0403", variables => { device => $device, resource => "r$resource", node => $node }});
					}
					if ($line =~ /^rc:(\d+)/)
					{
						my $rc = $1;
						if ($rc eq "0")
						{
							# Success!
							$an->Log->entry({log_level => 2, message_key => "log_0101", message_variables => {
								node     => $node, 
								resource => "r$resource",
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif (not $no_metadata)
						{
							# I skip this if '$no_metadata' is set as I've already generated a message for the user.
							$an->Log->entry({log_level => 1, message_key => "log_0102", message_variables => {
								node     => $node, 
								resource => "r$resource",
							}, file => $THIS_FILE, line => __LINE__});
							$message .= AN::Common::get_string($conf, {key => "message_0400", variables => { resource => "r$resource", node => $node }});
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

# This creates the root user's id_rsa keys and then populates
# ~/.ssh/known_hosts on both nodes.
sub configure_ssh
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_ssh" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Three steps; 
	# 1. Get/generate RSA keys
	# 2. Populate known_hosts
	# 3. Add RSA keys to authorized_keys
	
	# Get/Generate RSA keys
	my ($node1_rsa) = get_node_rsa_public_key($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_rsa) = get_node_rsa_public_key($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	
	# Populate known_hosts
	my ($node1_kh_ok) = populate_known_hosts_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_kh_ok) = populate_known_hosts_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	
	# Add the rsa keys to the node's root user's authorized_keys file.
	my $node1_ak_ok = 255;
	my $node2_ak_ok = 255;
	if (($node1_rsa) && ($node2_rsa))
	{
		# Have RSA keys, check nodes.
		$an->Log->entry({log_level => 2, message_key => "log_0103", file => $THIS_FILE, line => __LINE__});
		($node1_ak_ok) = populate_authorized_keys_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $node1_rsa, $node2_rsa);
		($node2_ak_ok) = populate_authorized_keys_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $node1_rsa, $node2_rsa);
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
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0257!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This adds each node's RSA public key to the node's ~/.ssh/authorized_keys file if needed.
sub populate_authorized_keys_on_node
{
	my ($conf, $node, $password, $node1_rsa, $node2_rsa) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "populate_authorized_keys_on_node" }, message_key => "an_variables_0003", message_variables => { 
		name1 => "node",      value1 => $node, 
		name2 => "node1_rsa", value2 => $node1_rsa, 
		name3 => "node2_rsa", value3 => $node2_rsa, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# If a node is being rebuilt, it's old keys will no longer be valid. To
	# deal with this, we simply remove existing keys and re-add them.
	my $ok = 1;
	foreach my $name (@{$conf->{sys}{node_names}})
	{
		my $shell_call = "
if [ -e '/root/.ssh/authorized_keys' ]
then
    if \$(grep -q $name ~/.ssh/authorized_keys);
    then 
        echo 'RSA key exists, removing it.'
        sed -i '/ root\@$name$/d' /root/.ssh/authorized_keys
    fi;
else
    echo 'no file'
fi";
	}
	
	### Now add the keys.
	# Node 1
	if (1)
	{
		my $shell_call = "echo \"$node1_rsa\" >> /root/.ssh/authorized_keys";
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
		}
		
		# Verify it was added.
		$shell_call = "
if \$(grep -q \"$node1_rsa\" /root/.ssh/authorized_keys)
then
    echo added
else
    echo failed
fi";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
		my $shell_call = "echo \"$node2_rsa\" >> /root/.ssh/authorized_keys";
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
		}
		
		# Verify it was added.
		$shell_call = "
if \$(grep -q \"$node2_rsa\" /root/.ssh/authorized_keys)
then
    echo added
else
    echo failed
fi";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "populate_known_hosts_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $ok = 1;
	foreach my $name (@{$conf->{sys}{node_names}})
	{
		# If a node is being replaced, the old entries will no longer
		# match. So as a precaution, existing keys are removed if
		# found.
		next if not $name;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "checking/adding fingerprint for", value1 => $name,
		}, file => $THIS_FILE, line => __LINE__});
		my $shell_call = "
if \$(grep -q $name ~/.ssh/known_hosts);
then 
    echo 'fingerprint exists, removing it.'
    sed -i '/^$name /d' /root/.ssh/known_hosts
fi
ssh-keyscan $name >> ~/.ssh/known_hosts;
if \$(grep -q $name ~/.ssh/known_hosts);
then 
    echo 'fingerprint added';
else
    echo 'failed to record fingerprint for $node.';
fi;";
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
				$ok = 0;
			}
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# Read in the RSA public key from a node, creating the RSA keys if needed.
sub get_node_rsa_public_key
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_node_rsa_public_key" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $rsa_key = "";
	#ssh-keygen -t rsa -N "" -b 8191 -f ~/.ssh/id_rsa
	#ssh-keygen -l -f ~/.ssh/id_rsa
	$conf->{cgi}{anvil_ssh_keysize} = "8191" if not $conf->{cgi}{anvil_ssh_keysize};
	my $shell_call = "
if [ -e '/root/.ssh/id_rsa.pub' ]; 
then 
    cat /root/.ssh/id_rsa.pub; 
else 
    ssh-keygen -t rsa -N \"\" -b $conf->{cgi}{anvil_ssh_keysize} -f ~/.ssh/id_rsa;
    if [ -e '/root/.ssh/id_rsa.pub' ];
    then 
        cat /root/.ssh/id_rsa.pub; 
    else 
        echo 'keygen failed';
    fi;
fi";
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
		
		if ($line =~ /^ssh-rsa /)
		{
			$rsa_key = $line;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "node",    value1 => $node,
				name2 => "rsa_key", value2 => $rsa_key,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($line =~ /Your public key has been saved in/i)
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

# This checks that the nodes are ready to start cman and, if so, does so.
sub start_cman
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "start_cman" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1_rc = 0;
	my $node2_rc = 0;
	# See if cman is running already.
	my ($node1_cman_state) = get_daemon_state($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, "cman");
	my ($node2_cman_state) = get_daemon_state($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, "cman");
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_cman_state", value1 => $node1_cman_state,
		name2 => "node2_cman_state", value2 => $node2_cman_state,
	}, file => $THIS_FILE, line => __LINE__});
	# 1 == running, 0 == stopped.

	# First thing, make sure each node can talk to the other on the BCN.
	my ($node1_ok) = ping_node_from_other($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $conf->{cgi}{anvil_node2_bcn_ip});
	my ($node2_ok) = ping_node_from_other($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $conf->{cgi}{anvil_node1_bcn_ip});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_ok", value1 => $node1_ok,
		name2 => "node2_ok", value2 => $node2_ok,
	}, file => $THIS_FILE, line => __LINE__});
	
	# No sense proceeding if the nodes can't talk to each other.
	if ((not $node1_ok) || (not $node2_ok))
	{
		# Both can ping the other on their BCN, so we can try to start
		# cman now.
		$node1_rc = 1;
		$node2_rc = 1;
	}
	if ((not $node1_cman_state) && (not $node2_cman_state))
	{
		# Start cman on both nodes at the same time. We use node1's password as it has to be the same
		# on both at this point.
		my $command  = "/etc/init.d/cman start";
		my $password = $conf->{cgi}{anvil_node1_current_password};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "command",                     value1 => $command,
			name2 => "cgi::anvil_node1_current_ip", value2 => $conf->{cgi}{anvil_node1_current_ip},
			name3 => "cgi::anvil_node2_current_ip", value2 => $conf->{cgi}{anvil_node2_current_ip},
		}, file => $THIS_FILE, line => __LINE__});
		$an->Remote->synchronous_command_run({
			command		=>	$command, 
			node1		=>	$conf->{cgi}{anvil_node1_current_ip}, 
			node2		=>	$conf->{cgi}{anvil_node2_current_ip}, 
			delay		=>	30,
			password	=>	$password, 
		});
		
		# Now see if that succeeded.
		$an->Log->entry({log_level => 2, message_key => "log_0110", file => $THIS_FILE, line => __LINE__});
		my ($node1_cman_state) = get_daemon_state($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, "cman");
		my ($node2_cman_state) = get_daemon_state($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, "cman");
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node1_cman_state", value1 => $node1_cman_state,
			name2 => "node2_cman_state", value2 => $node2_cman_state,
		}, file => $THIS_FILE, line => __LINE__});
		# 1 == running, 0 == stopped.
		
		if (($node1_cman_state) && ($node2_cman_state))
		{
			# \o/ - Successfully started cman on both nodes.
			$node1_rc = 2;
			$node2_rc = 2;
			$an->Log->entry({log_level => 2, message_key => "log_0111", file => $THIS_FILE, line => __LINE__});
		}
		elsif ($node1_cman_state)
		{
			# Only node 1 started... node 2 was probably fenced.
			$node1_rc = 2;
			$node2_rc = 4;
			$an->Log->entry({log_level => 1, message_key => "log_0112", message_variables => {
				node1 => $conf->{cgi}{anvil_node1_current_ip}, 
				node2 => $conf->{cgi}{anvil_node2_current_ip}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($node2_cman_state)
		{
			# Only node 2 started... node 1 was probably fenced.
			$node1_rc = 4;
			$node2_rc = 2;
			$an->Log->entry({log_level => 1, message_key => "log_0113", message_variables => {
				node1 => $conf->{cgi}{anvil_node1_current_ip}, 
				node2 => $conf->{cgi}{anvil_node2_current_ip}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Well crap...
			$node1_rc = 4;
			$node2_rc = 4;
			$an->Log->entry({log_level => 1, message_key => "log_0111", file => $THIS_FILE, line => __LINE__});
		}
	}
	elsif (not $node1_cman_state)
	{
		# Node 2 is running, node 1 isn't, start it.
		start_cman_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
		my ($node1_cman_state) = get_daemon_state($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, "cman");
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node1_cman_state", value1 => $node1_cman_state,
			name2 => "node2_cman_state", value2 => $node2_cman_state,
		}, file => $THIS_FILE, line => __LINE__});
		if ($node1_cman_state)
		{
			# Started!
			$node2_rc = 2;
			$an->Log->entry({log_level => 2, message_key => "log_0115", message_variables => {
				node_number  => "1", 
				node_address => $conf->{cgi}{anvil_node1_current_ip}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Failed to start.
			$node1_rc = 4;
			$an->Log->entry({log_level => 1, message_key => "log_0116", message_variables => {
				node_number  => "1", 
				node_address => $conf->{cgi}{anvil_node1_current_ip}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	elsif (not $node2_cman_state)
	{
		# Node 1 is running, node 2 isn't, start it.
		start_cman_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
		my ($node2_cman_state) = get_daemon_state($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, "cman");
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node2_cman_state", value1 => $node2_cman_state,
			name2 => "node2_cman_state", value2 => $node2_cman_state,
		}, file => $THIS_FILE, line => __LINE__});
		if ($node2_cman_state)
		{
			# Started!
			$node2_rc = 2;
			$an->Log->entry({log_level => 2, message_key => "log_0115", message_variables => {
				node_number  => "2", 
				node_address => $conf->{cgi}{anvil_node2_current_ip}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Failed to start.
			$node2_rc = 4;
			$an->Log->entry({log_level => 1, message_key => "log_0116", message_variables => {
				node_number  => "2", 
				node_address => $conf->{cgi}{anvil_node2_current_ip}, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	else
	{
		# Both are already running
		$node1_rc = 3;
		$node2_rc = 3;
		$an->Log->entry({log_level => 2, message_key => "log_0117", file => $THIS_FILE, line => __LINE__});
	}
	
	# Check fencing if cman is running
	my $node1_fence_ok       = 255;
	my $node1_return_message = "";
	my $node2_fence_ok       = 255;
	my $node2_return_message = "";
	if ((($node1_rc eq "2") || ($node1_rc eq "3")) && (($node2_rc eq "2") || ($node2_rc eq "3")))
	{
		($node1_fence_ok, $node1_return_message) = check_fencing_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
		($node2_fence_ok, $node2_return_message) = check_fencing_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node1_fence_ok", value1 => $node1_fence_ok,
			name2 => "node2_fence_ok", value2 => $node2_fence_ok,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node1_return_message", value1 => $node1_return_message,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node2_return_message", value1 => $node2_return_message,
		}, file => $THIS_FILE, line => __LINE__});
	}
	# 1 = Can't ping peer on BCN
	# 2 = Started
	# 3 = Already running
	# 4 = Failed to start
	my $ok = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0014!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0014!#";
	# Node 1
	if ($node1_rc eq "1")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0077!#",
		$ok            = 0;
	}
	elsif ($node1_rc eq "4")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0018!#",
		$ok            = 0;
	}
	elsif (not $node1_fence_ok)
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = AN::Common::get_string($conf, {key => "state_0082", variables => { message => "$node1_return_message" }});
		$ok            = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node1_fence_ok bad, setting 'ok'", value1 => $ok,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($node1_rc eq "3")
	{
		$node1_message = "#!string!state_0078!#",
	}
	# Node 2
	if ($node2_rc eq "1")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0077!#",
		$ok            = 0;
	}
	elsif ($node2_rc eq "4")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0018!#",
		$ok            = 0;
	}
	elsif (not $node2_fence_ok)
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = AN::Common::get_string($conf, {key => "state_0082", variables => { message => "$node2_return_message" }});
		$ok            = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node1_fence_ok bad, setting 'ok'", value1 => $ok,
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($node2_rc eq "3")
	{
		$node2_message = "#!string!state_0078!#",
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0256!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This calls 'check_fence' on the node to verify if fencing is working.
sub check_fencing_on_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_fencing_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $message = "";
	my $ok      = 1;
	my $shell_call = "fence_check -f; echo rc:\$?";
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
		
		if ($line =~ /rc:(\d+)/)
		{
			# 0 == OK
			# 5 == Failed
			my $rc = $1;
			if ($rc eq "0")
			{
				# Passed
				$an->Log->entry({log_level => 2, message_key => "log_0118", file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Failed
				$an->Log->entry({log_level => 1, message_key => "log_0119", message_variables => {
					return_code => $rc, 
				}, file => $THIS_FILE, line => __LINE__});
				$ok = 0;
			}
		}
		else
		{
			$message .= "$line<br />\n";
		}
	}
	$message =~ s/<br \/>\n$//;
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok, $message);
}

# Start cluster communications on a single node.
sub start_cman_on_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "start_cman_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $shell_call = "/etc/init.d/cman start";
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
	}
	
	return(0)
}

# This doesn a simple ping test from one node to the other.
sub ping_node_from_other
{
	my ($conf, $node, $password, $target_ip) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "ping_node_from_other" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node",      value1 => $node, 
		name2 => "target_ip", value2 => $target_ip, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $success    = 0;
	my $ping_rc    = 255;
	my $shell_call = "ping -n $target_ip -c 1; echo ping:\$?";
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
		
		if ($line =~ /(\d+) packets transmitted, (\d+) received/)
		{
			# This isn't really needed, but might help folks
			# watching the logs.
			my $pings_sent     = $1;
			my $pings_received = $2;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "target_ip",      value1 => $target_ip,
				name2 => "pings_sent",     value2 => $pings_sent,
				name3 => "pings_received", value3 => $pings_received,
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /ping:(\d+)/)
		{
			$ping_rc = $1;
			$an->Log->entry({log_level => 2, message_key => "log_0115", message_variables => {
				node_number  => "2", 
				node_address => $conf->{cgi}{anvil_node2_current_ip}, 
			}, file => $THIS_FILE, line => __LINE__});
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "ping_rc", value1 => $ping_rc,
			}, file => $THIS_FILE, line => __LINE__});
			$success = 1 if not $ping_rc;
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "success", value1 => $success,
	}, file => $THIS_FILE, line => __LINE__});
	return($success);
}

# This sets the 'ricci' user's passwords.
sub set_ricci_password
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "set_ricci_password" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### NOTE: For now, ricci and root passwords are set to the same thing.
	###       This might change later, so this function is designed to
	###       support different passwords.
	# Set the passwords on the nodes.
	my $ok = 1;
	my ($node1_ricci_pw) = set_password_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, "ricci", $conf->{cgi}{anvil_password});
	my ($node2_ricci_pw) = set_password_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, "ricci", $conf->{cgi}{anvil_password});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_ricci_pw", value1 => $node1_ricci_pw,
		name2 => "node2_ricci_pw", value2 => $node2_ricci_pw,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Test the new password.
	my ($node1_access) = check_node_access($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_access) = check_node_access($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_access", value1 => $node1_access,
		name2 => "node2_access", value2 => $node2_access,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If both nodes are accessible, we're golden.
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0073!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0073!#";
	if (not $node1_access)
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0074!#",
		$ok            = 0;
	}
	if (not $node2_access)
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0074!#",
		$ok            = 0;
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0267!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This does any needed SELinux configuration that is needed.
sub configure_selinux
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_selinux" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# For now, this always returns "success".
	my ($node1_rc) = configure_selinux_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_rc) = configure_selinux_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_rc", value1 => $node1_rc,
		name2 => "node2_rc", value2 => $node2_rc,
	}, file => $THIS_FILE, line => __LINE__});
	# 0 == Success
	# 1 == Failed
	
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0073!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0073!#";
	if ($node1_rc eq "1")
	{
		$ok            = 0;
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0018!#";
	}
	if ($node2_rc eq "1")
	{
		$ok            = 0;
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0018!#";
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0290!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This does the work of actually configuring SELinux on a node.
sub configure_selinux_on_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_selinux_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Create the backup directory if it doesn't exist yet.
	my $return_code = 0;
	my $shell_call  = "
if \$($conf->{path}{nodes}{getsebool} fenced_can_ssh | $conf->{path}{nodes}{grep} -q on); 
then 
    echo 'Already allowed';
else 
    echo \"Off, enabling 'fenced_can_ssh' now...\";
    $conf->{path}{nodes}{setsebool} -P fenced_can_ssh on
    if \$($conf->{path}{nodes}{getsebool} fenced_can_ssh | $conf->{path}{nodes}{grep} -q on); 
    then 
        echo 'Now allowed.'
    else
        echo \"Failed to allowe 'fenced_can_ssh'.\"
    fi
fi
";
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

# This sets the 'root' user's passwords.
sub set_root_password
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "set_root_password" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### NOTE: For now, ricci and root passwords are set to the same thing.
	###       This might change later, so this function is designed to
	###       support different passwords.
	# Set the passwords on the nodes.
	my $ok = 1;
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::anvil_node1_current_password", value1 => $conf->{cgi}{anvil_node1_current_password},
		name2 => "cgi::anvil_node2_current_password",    value2 => $conf->{cgi}{anvil_node2_current_password},
	}, file => $THIS_FILE, line => __LINE__});
	($conf->{cgi}{anvil_node1_current_password}) = set_password_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, "root", $conf->{cgi}{anvil_password});
	($conf->{cgi}{anvil_node2_current_password}) = set_password_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, "root", $conf->{cgi}{anvil_password});
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::anvil_node1_current_password", value1 => $conf->{cgi}{anvil_node1_current_password},
		name2 => "cgi::anvil_node2_current_password",    value2 => $conf->{cgi}{anvil_node2_current_password},
	}, file => $THIS_FILE, line => __LINE__});
	
	# Test the new password.
	my ($node1_access) = check_node_access($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_access) = check_node_access($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_access", value1 => $node1_access,
		name2 => "node2_access", value2 => $node2_access,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If both nodes are accessible, we're golden.
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0073!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0073!#";
	if (not $node1_access)
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0074!#",
		$ok            = 0;
	}
	if (not $node2_access)
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0074!#",
		$ok            = 0;
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0255!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This updates the ricci and root passwords, and closes the connection after 'root' is changed. After this 
# function, the next login will be a new one.
sub set_password_on_node
{
	my ($conf, $node, $password, $user, $new_password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "set_password_on_node" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node", value1 => $node, 
		name2 => "user", value2 => $user, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Set the 'ricci' password first.
	my $shell_call = "echo '$new_password' | passwd $user --stdin";
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
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
	}
	
	$an->Log->entry({log_level => 4, message_key => "an_variables_0001", message_variables => {
		name1 => "new_password", value1 => $new_password,
	}, file => $THIS_FILE, line => __LINE__});
	return($new_password);
}

# This creates a backup of /etc/sysconfig/network-scripts into /root/backups
# and then creates a .anvil copy of lvm.conf and, if it exists, the DRBD and
# cman config files
sub backup_files
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "backup_files" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	backup_files_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	backup_files_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	
	# There are no failure modes yet.
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0073!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0073!#";
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0254!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	return(0);
}

# This does the work of actually backing up files on a node.
sub backup_files_on_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "backup_files_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Create the backup directory if it doesn't exist yet.
	my $shell_call = "
if [ -e '$conf->{path}{nodes}{backups}' ];
then 
    echo \"Backup directory exist\";
else 
    mkdir -p $conf->{path}{nodes}{backups}; 
fi";
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
	}
	
	# Backup the original network config
	$shell_call = "
if [ -e '$conf->{path}{nodes}{backups}/network-scripts' ];
then 
    echo \"Network configuration files previously backed up\";
else 
    rsync -av $conf->{path}{nodes}{network_scripts} $conf->{path}{nodes}{backups}/;
fi";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
		target		=>	$node,
		port		=>	$conf->{node}{$node}{port}, 
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
	}
	
	# Backup the original SSH config
	$shell_call = "
if [ -e '$conf->{path}{nodes}{backups}/.ssh' ];
then 
    echo \"SSH configuration files previously backed up\";
else 
    rsync -av /root/.ssh $conf->{path}{nodes}{backups}/;
fi";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	# Backup DRBD if it exists.
	$shell_call = "
if [ -e '$conf->{path}{nodes}{drbd}' ] && [ ! -e '$conf->{path}{nodes}{backups}/drbd.d' ];
then 
    rsync -av $conf->{path}{nodes}{drbd} $conf->{path}{nodes}{backups}/; 
else 
    echo \"DRBD backup not needed\"; 
fi";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	# Backup lvm.conf.
	$shell_call = "
if [ ! -e '$conf->{path}{nodes}{backups}/lvm.conf' ];
then 
    rsync -av $conf->{path}{nodes}{lvm_conf} $conf->{path}{nodes}{backups}/; 
else 
    echo \"LVM previously backed up, skipping.\"; 
fi";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	# Backup cluster.conf.
	$shell_call = "
if [ ! -e '$conf->{path}{nodes}{backups}/cluster.conf' ];
then 
    rsync -av $conf->{path}{nodes}{cluster_conf} $conf->{path}{nodes}{backups}/; 
else 
    echo \"cman previously backed up, skipping.\"; 
fi";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	# Backup fstab.
	$shell_call = "
if [ ! -e '$conf->{path}{nodes}{backups}/fstab' ];
then 
    rsync -av $conf->{path}{nodes}{fstab} $conf->{path}{nodes}{backups}/; 
else 
    echo \"fstab previously backed up, skipping.\"; 
fi";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	# Backup shadow.
	$shell_call = "
if [ ! -e '$conf->{path}{nodes}{backups}/shadow' ];
then 
    rsync -av $conf->{path}{nodes}{shadow} $conf->{path}{nodes}{backups}/; 
else 
    echo \"shadow previously backed up, skipping.\"; 
fi";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	return(0);
}

# This configures IPMI
sub configure_ipmi
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_ipmi" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ok = 1;
	my ($node1_rc) = configure_ipmi_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $conf->{cgi}{anvil_node1_ipmi_ip}, $conf->{cgi}{anvil_node1_ipmi_netmask}, $conf->{cgi}{anvil_node1_ipmi_password}, $conf->{cgi}{anvil_node1_ipmi_user}, $conf->{cgi}{anvil_node1_ipmi_gateway});
	my ($node2_rc) = configure_ipmi_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $conf->{cgi}{anvil_node2_ipmi_ip}, $conf->{cgi}{anvil_node2_ipmi_netmask}, $conf->{cgi}{anvil_node2_ipmi_password}, $conf->{cgi}{anvil_node2_ipmi_user}, $conf->{cgi}{anvil_node1_ipmi_gateway});
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
	if ($node1_rc eq "1")
	{
		# No IPMI device found.
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0071!#",
		$ok            = 0;
	}
	elsif ($node1_rc eq "2")
	{
		# No IPMI device found.
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0019!#",
	}
	elsif ($node1_rc eq "3")
	{
		# IPMI LAN channel not found
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0066!#",
		$ok            = 0;
	}
	elsif ($node1_rc eq "4")
	{
		# User ID not found
		$node1_class   = "highlight_warning_bold";
		$node1_message = AN::Common::get_string($conf, {key => "state_0067", variables => { user => $conf->{cgi}{anvil_node1_ipmi_user} }}),
		$ok            = 0;
	}
	elsif ($node1_rc eq "5")
	{
		# Failed to set to static IP
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0068!#",
		$ok            = 0;
	}
	elsif ($node1_rc eq "6")
	{
		# Failed to set IP address
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0069!#",
		$ok            = 0;
	}
	elsif ($node1_rc eq "7")
	{
		# Failed to set netmask
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0070!#",
		$ok            = 0;
	}
	
	# Node 2
	if ($node2_rc eq "1")
	{
		# No IPMI device found.
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0071!#",
		$ok            = 0;
	}
	elsif ($node2_rc eq "2")
	{
		# No IPMI device found.
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0019!#",
	}
	elsif ($node2_rc eq "3")
	{
		# IPMI LAN channel not found
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0066!#",
		$ok            = 0;
	}
	elsif ($node2_rc eq "4")
	{
		# User ID not found
		$node2_class   = "highlight_warning_bold";
		$node2_message = AN::Common::get_string($conf, {key => "state_0067", variables => { user => $conf->{cgi}{anvil_node2_ipmi_user} }}),
		$ok            = 0;
	}
	elsif ($node2_rc eq "5")
	{
		# Failed to set to static IP
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0068!#",
		$ok            = 0;
	}
	elsif ($node2_rc eq "6")
	{
		# Failed to set IP address
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0069!#",
		$ok            = 0;
	}
	elsif ($node2_rc eq "7")
	{
		# Failed to set netmask
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0070!#",
		$ok            = 0;
	}
	
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0253!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	
	return($ok);
}

# This does the work of actually configuring IPMI on a node
sub configure_ipmi_on_node
{
	my ($conf, $node, $password, $ipmi_ip, $ipmi_netmask, $ipmi_password, $ipmi_user, $ipmi_gateway) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_ipmi_on_node" }, message_key => "an_variables_0004", message_variables => { 
		name1 => "node",         value1 => $node, 
		name2 => "ipmi_netmask", value2 => $ipmi_netmask, 
		name3 => "ipmi_user",    value3 => $ipmi_user, 
		name4 => "ipmi_gateway", value4 => $ipmi_gateway, 
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
	my ($state) = get_daemon_state($conf, $node, $password, "ipmi");
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "state", value1 => $state,
	}, file => $THIS_FILE, line => __LINE__});
	if ($state eq "7")
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "IPMI not found on node", value1 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		$return_code = 2;
	}
	else
	{
		# If we're still alive, then it's safe to say IPMI is running.
		# Find the LAN channel
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
			my $rc         = "";
			my $shell_call = "ipmitool lan print $channel; echo rc:\$?";
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
				
				if ($line =~ /Invalid channel: /)
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "Wrong lan channel", value1 => $channel,
					}, file => $THIS_FILE, line => __LINE__});
				}
				elsif ($line =~ "rc:0")
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
		my $user_id   = "";
		my $uid_found = 0;
		if ($lan_found)
		{
			while (not $uid_found)
			{
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "user_id", value1 => $user_id,
				}, file => $THIS_FILE, line => __LINE__});
				if ($user_id > 10)
				{
					# Give up...
					$an->Log->entry({log_level => 1, message_key => "log_0129", file => $THIS_FILE, line => __LINE__});
					$user_id = "";
					last;
				}
				
				# check to see if this is the write channel
				my $rc         = "";
				my $shell_call = "ipmitool user list $channel";
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
					$line =~ s/\s+/ /g;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
					
					if ($line =~ /^(\d+) $ipmi_user /)
					{
						$user_id   = $1;
						$uid_found = 1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "Found user ID", value1 => $user_id,
						}, file => $THIS_FILE, line => __LINE__});
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
				my $shell_call = "ipmitool user set password $user_id '$ipmi_password'";
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
				}
				
				# Test the password. If this fails with '16',
				# try '20'.
				my $password_ok = 0;
				my $try_20      = 0;
				   $shell_call  = "ipmitool user test $user_id 16 '$ipmi_password'";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
					name2 => "node",       value2 => $node,
				}, file => $THIS_FILE, line => __LINE__});
				($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
					
					if ($line =~ /Success/i)
					{
						# Woo!
						$an->Log->entry({log_level => 2, message_key => "log_0130", message_variables => {
							channel => $channel, 
						}, file => $THIS_FILE, line => __LINE__});
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
						$an->Log->entry({log_level => 1, message_key => "log_0132", message_variables => {
							channel => $channel, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				if ($try_20)
				{
					my $shell_call  = "ipmitool user test $user_id 20 '$ipmi_password'";
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
						
						if ($line =~ /Success/i)
						{
							# Woo!
							$an->Log->entry({log_level => 2, message_key => "log_0133", message_variables => {
								channel => $channel, 
							}, file => $THIS_FILE, line => __LINE__});
						}
						elsif ($line =~ /password incorrect/i)
						{
							# Password didn't take. :(
							$return_code = 1;
							$an->Log->entry({log_level => 1, message_key => "log_0132", message_variables => {
								channel => $channel, 
							}, file => $THIS_FILE, line => __LINE__});
						}
					}
				}
			}
		}
		
		# If I am missing either the channel or the user ID, we're done.
		if (not $lan_found)
		{
			$return_code = 3;
		}
		elsif (not $uid_found)
		{
			$return_code = 4;
		}
		elsif ($return_code ne "1")
		{
			### Still alive!
			# Setup the IPMI IP to static
			my $shell_call = "ipmitool lan set $channel ipsrc static";
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
			}
			
			# Now set the IP
			$shell_call = "ipmitool lan set $channel ipaddr $ipmi_ip";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "node",       value2 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
			}
			
			# Now the netmask
			$shell_call = "ipmitool lan set $channel netmask $ipmi_netmask";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "node",       value2 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
			}
			
			# If the user has specified a gateway, set it
			if ($ipmi_gateway)
			{
				my $shell_call = "ipmitool lan set $channel defgw ipaddr $ipmi_gateway";
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
				}
			}
			
			### Now read it back.
			# Now the netmask
			$shell_call = "ipmitool lan print $channel";
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "shell_call", value1 => $shell_call,
				name2 => "node",       value2 => $node,
			}, file => $THIS_FILE, line => __LINE__});
			($error, $ssh_fh, $return) = $an->Remote->remote_call({
				target		=>	$node,
				port		=>	$conf->{node}{$node}{port}, 
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
						last;
					}
				}
				if ($line =~ /IP Address :/i)	# Needs the ' :' to not match 'IP Address Source'
				{
					my $ip = ($line =~ /(\d+\.\d+\.\d+\.\d+)$/)[0];
					if ($ip eq $ipmi_ip)
					{
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "ipmi_ip", value1 => $ipmi_ip,
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
						last;
					}
				}
			}
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This sets nodes to start or stop on boot.
sub configure_daemons
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_daemons" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### TODO:
	my ($node1_ok, $node1_messages) = configure_daemons_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_ok, $node2_messages) = configure_daemons_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	
	# If there was a problem on either node, the message will be set.
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0029!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0029!#";
	if (not $node1_ok)
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
				$node1_message .= AN::Common::get_string($conf, {key => "state_0062", variables => { daemon => "$daemon" }}),
			}
			elsif ($error =~ /failed to start:(.*)/)
			{
				my $daemon = $1;
				$node1_message .= AN::Common::get_string($conf, {key => "state_0063", variables => { daemon => "$daemon" }}),
			}
			elsif ($error =~ /failed to disable:(.*)/)
			{
				my $daemon = $1;
				$node1_message .= AN::Common::get_string($conf, {key => "state_0064", variables => { daemon => "$daemon" }}),
			}
			elsif ($error =~ /failed to stop:(.*)/)
			{
				my $daemon = $1;
				$node1_message .= AN::Common::get_string($conf, {key => "state_0065", variables => { daemon => "$daemon" }}),
			}
		}
	}
	if (not $node2_ok)
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
				$node2_message .= AN::Common::get_string($conf, {key => "state_0062", variables => { daemon => "$daemon" }}),
			}
			elsif ($error =~ /failed to start:(.*)/)
			{
				my $daemon = $1;
				$node2_message .= AN::Common::get_string($conf, {key => "state_0063", variables => { daemon => "$daemon" }}),
			}
			elsif ($error =~ /failed to disable:(.*)/)
			{
				my $daemon = $1;
				$node2_message .= AN::Common::get_string($conf, {key => "state_0064", variables => { daemon => "$daemon" }}),
			}
			elsif ($error =~ /failed to stop:(.*)/)
			{
				my $daemon = $1;
				$node2_message .= AN::Common::get_string($conf, {key => "state_0065", variables => { daemon => "$daemon" }}),
			}
		}
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0252!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This enables and disables daemons on boot for a node.
sub configure_daemons_on_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_daemons_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $ok     = 1;
	my $return = "";
	
	# Enable daemons
	foreach my $daemon (sort {$a cmp $b} @{$conf->{sys}{daemons}{enable}})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "node",   value1 => $node,
			name2 => "daemon", value2 => $daemon,
		}, file => $THIS_FILE, line => __LINE__});
		
		my ($init3, $init5) = get_chkconfig_data($conf, $node, $password, $daemon);
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
			set_chkconfig($conf, $node, $password, $daemon, "on");
			my ($init3, $init5) = get_chkconfig_data($conf, $node, $password, $daemon);
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
			
			my ($state) = get_daemon_state($conf, $node, $password, $daemon);
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
				# Enable it.
				set_daemon_state($conf, $node, $password, $daemon, "start");
				my ($state) = get_daemon_state($conf, $node, $password, $daemon);
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
	foreach my $daemon (sort {$a cmp $b} @{$conf->{sys}{daemons}{disable}})
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node",   value1 => $node,
			name2 => "daemon", value2 => $daemon,
		}, file => $THIS_FILE, line => __LINE__});
		
		my ($init3, $init5) = get_chkconfig_data($conf, $node, $password, $daemon);
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
			# Enable it.
			set_chkconfig($conf, $node, $password, $daemon, "off");
			my ($init3, $init5) = get_chkconfig_data($conf, $node, $password, $daemon);
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
			my ($state) = get_daemon_state($conf, $node, $password, $daemon);
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
				# Enable it.
				set_daemon_state($conf, $node, $password, $daemon, "stop");
				my ($state) = get_daemon_state($conf, $node, $password, $daemon);
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

# This starts or stops a daemon on a node.
sub set_daemon_state
{
	my ($conf, $node, $password, $daemon, $state) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "set_daemon_state" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node",   value1 => $node, 
		name2 => "daemon", value2 => $daemon, 
		name3 => "state",  value3 => $state, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $rc         = "";
	my $shell_call = "/etc/init.d/$daemon $state; echo rc:\$?";
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
		
		if ($line =~ /^rc:(\d+)/)
		{
			$rc = $1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "rc", value1 => $rc,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "rc", value1 => $rc,
	}, file => $THIS_FILE, line => __LINE__});
	return($rc);
}

# This checks to see if a daemon is running or not.
sub get_daemon_state
{
	my ($conf, $node, $password, $daemon) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_daemon_state" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node",   value1 => $node, 
		name2 => "daemon", value2 => $daemon, 
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
	my $running_rc = 0;
	my $stopped_rc = 3;
	if ($daemon eq "ipmi")
	{
		$stopped_rc = 6;
	}
	
	# This will store the state.
	my $state = "";
	
	# Check if the daemon is running currently.
	$an->Log->entry({log_level => 2, message_key => "log_0150", message_variables => {
		node   => $node, 
		daemon => $daemon,
	}, file => $THIS_FILE, line => __LINE__});
	my $shell_call = "/etc/init.d/$daemon status; echo rc:\$?";
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /No such file or directory/i)
		{
			# Not installed, pretend it is off.
			$an->Log->entry({log_level => 2, message_key => "log_0151", message_variables => {
				node   => $node, 
				daemon => $daemon,
			}, file => $THIS_FILE, line => __LINE__});
			$state = 0;
			last;
		}
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
				name1 => "rc",      value1 => $rc,
				name2 => "stopped", value2 => $stopped_rc,
				name3 => "running", value3 => $running_rc,
			}, file => $THIS_FILE, line => __LINE__});
			if ($rc eq $running_rc)
			{
				$state = 1;
			}
			elsif ($rc eq $stopped_rc)
			{
				$state = 0;
			}
			else
			{
				$state = "undefined:$rc";
			}
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "rc",    value1 => $rc,
				name2 => "state", value2 => $state,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "state", value1 => $state,
	}, file => $THIS_FILE, line => __LINE__});
	return($state);
}

# This calls 'chkconfig' and enables or disables the daemon on boot.
sub set_chkconfig
{
	my ($conf, $node, $password, $daemon, $state) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "set_chkconfig" }, message_key => "an_variables_0003", message_variables => { 
		name1 => "node",   value1 => $node, 
		name2 => "daemon", value2 => $daemon, 
		name3 => "state",  value3 => $state, 
	}, file => $THIS_FILE, line => __LINE__});

	my $shell_call = "chkconfig $daemon $state";
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
	}
	
	return(0);
}

# This calls 'chkconfig' and return '1' or '0' based on whether the daemon is set to run on boot or not.
sub get_chkconfig_data
{
	my ($conf, $node, $password, $daemon) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_chkconfig_data" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node",   value1 => $node, 
		name2 => "daemon", value2 => $daemon, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $init3 = 255;
	my $init5 = 255;

	my $shell_call = "chkconfig --list $daemon";
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

# This configures clustered LVM on each node.
sub configure_clvmd
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_clvmd" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# This will read in the existing lvm.conf on both nodes and, if either
	# has a custom filter, preserve it and use it on the peer. If this
	# '1', then a custom filter was found on both nodes and the do not
	# match.
	my $ok = 1;
	my ($generate_rc) = generate_lvm_conf($conf);
	# Return codes:
	# 0 = OK
	# 1 = Both nodes have different and custom filter lines.
	# 2 = Read failed.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "generate_rc", value1 => $generate_rc,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "lvm.conf", value1 => $conf->{sys}{lvm_conf},
	}, file => $THIS_FILE, line => __LINE__});
	
	# Now we'll write out the config.
	my $node1_rc = 255;
	my $node2_rc = 255;
	if (not $generate_rc)
	{
		($node1_rc) = write_lvm_conf_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
		($node2_rc) = write_lvm_conf_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node1_rc", value1 => $node1_rc,
			name2 => "node2_rc", value2 => $node2_rc,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0026!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0026!#";
	# Was there a conflict?
	if ($generate_rc eq "2")
	{
		# Failed to read/prepare lvm.conf data.
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0072!#",
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0072!#",
		$ok            = 0;
	}
	elsif ($generate_rc eq "1")
	{
		# Duplicate, unmatched filters
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0061!#",
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0061!#",
		$ok            = 0;
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0251!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	return($ok);
}

# This reads in node 1's lvm.conf, makes sure it's configured for clvmd and stores in.
sub generate_lvm_conf
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "generate_lvm_conf" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Read the /etc/lvm/lvm.conf file on both nodes and look for a custom filter line. The rest of the 
	# config will be loaded into memory and, if one node is found to have a custom filter, it will be 
	# used to on the other node. If neither have a custom filter, then node 1's base config will be 
	# modified and loaded on both nodes.
	my $return_code = 0;
	read_lvm_conf_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	read_lvm_conf_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	
	# Now decide what lvm.conf to use.
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "sys::filter", value1 => $conf->{sys}{lvm_filter},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1",  value1 => $node1,
		name2 => "filter", value2 => $conf->{node}{$node1}{lvm_filter},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node2",  value1 => $node2,
		name2 => "filter", value2 => $conf->{node}{$node2}{lvm_filter},
	}, file => $THIS_FILE, line => __LINE__});
	if (($conf->{node}{$node1}{lvm_filter} ne $conf->{sys}{lvm_filter}) && ($conf->{node}{$node2}{lvm_filter} ne $conf->{sys}{lvm_filter}))
	{
		# Both are custom, do they match?
		if ($conf->{node}{$node1}{lvm_filter} eq $conf->{node}{$node2}{lvm_filter})
		{
			# We're good. We'll use node 1
			$conf->{sys}{lvm_conf} = $conf->{node}{$node1}{lvm_conf};
			$an->Log->entry({log_level => 2, message_key => "log_0152", file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Both are custom and they don't match, time to bail out.
			$return_code = 1;
			$an->Log->entry({log_level => 1, message_key => "log_0153", file => $THIS_FILE, line => __LINE__});
		}
	}
	elsif ($conf->{node}{$node1}{lvm_filter} ne $conf->{sys}{lvm_filter})
	{
		# Node 1 has a custom filter, we'll use it
		$conf->{sys}{lvm_conf} = $conf->{node}{$node1}{lvm_conf};
		$an->Log->entry({log_level => 2, message_key => "log_0154", message_variables => {
			node => $node1, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($conf->{node}{$node2}{lvm_filter} ne $conf->{sys}{lvm_filter})
	{
		# Node 2 has a custom filter, we'll use it
		$conf->{sys}{lvm_conf} = $conf->{node}{$node2}{lvm_conf};
		$an->Log->entry({log_level => 2, message_key => "log_0154", message_variables => {
			node => $node2, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Neither are custom, so pick one that looks sane.
		if (length($conf->{node}{$node1}{lvm_conf}) > 256)
		{
			# Node 1's copy seems sane, use it.
			$conf->{sys}{lvm_conf} = $conf->{node}{$node1}{lvm_conf};
			$an->Log->entry({log_level => 2, message_key => "log_0155", message_variables => {
				node => $node1,  
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (length($conf->{node}{$node1}{lvm_conf}) > 256)
		{
			# Node 2's copy seems sane, use it.
			$conf->{sys}{lvm_conf} = $conf->{node}{$node2}{lvm_conf};
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
		name1 => "length(sys::lvm_conf)", value1 => length($conf->{sys}{lvm_conf}),
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

# This (re)writes the lvm.conf file on a node.
sub write_lvm_conf_on_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "write_lvm_conf_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $rc = 0;
	my $shell_call =  "cat > $conf->{path}{nodes}{lvm_conf} << EOF\n";
	   $shell_call .= "$conf->{sys}{lvm_conf}\n";
	   $shell_call .= "EOF";
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
	}
	
	return($rc);
}

# This reads in the actual lvm.conf from the node, updating the config in the process, storing a version 
# suitable for clustered LVM.
sub read_lvm_conf_on_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "read_lvm_conf_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# I need to read this in two passes. The first pass looks for an existing 'filter = []' rule and,
	# if found, uses it.
	$conf->{node}{$node}{lvm_filter} = $conf->{sys}{lvm_filter};
	
	# Read it in
	my $shell_call = "
if [ -e '$conf->{path}{nodes}{lvm_conf}' ]
then
    cat $conf->{path}{nodes}{lvm_conf}
else
    echo \"not found\"
fi";
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if (($line =~ /^filter = \[.*\]/) || ($line =~ /^\s+filter = \[.*\]/))
		{
			$conf->{node}{$node}{lvm_filter} = $line;
			$conf->{node}{$node}{lvm_filter} =~ s/^\s+//;
			$conf->{node}{$node}{lvm_filter} =~ s/\s+$//;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node}::lvm_filter", value1 => $conf->{node}{$node}{lvm_filter},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	### TODO: Make this smart enough to *NOT* change the lvm.conf file unless something actually needs to
	###       be changed and, if so, use sed to maintain the file's comments.
	# There is no default filter entry, but it is referenced as comments many times. So we'll inject it 
	# when we see the first comment and then skip any 
	my $filter_injected = 0;
	$conf->{node}{$node}{lvm_conf} =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n\n";
	$conf->{node}{$node}{lvm_conf} .= "# Sorry for the lack of comments... Ran into a buffer issue with Net::SSH2 that\n";
	$conf->{node}{$node}{lvm_conf} .= "# I wasn't able to fix in time. Fixing it is on the TODO though, and patches\n";
	$conf->{node}{$node}{lvm_conf} .= "# are welcomed. :)\n\n";
	foreach my $line (@{$return})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		last if $line =~ /not found/;
		
		# Any line that starts with a '#' is passed on as-is.
		if ((not $filter_injected) && ($line =~ /filter = \[/))
		{
			#$conf->{node}{$node}{lvm_conf} .= "$line\n";
			$conf->{node}{$node}{lvm_conf} .= "    $conf->{node}{$node}{lvm_filter}\n";
			$filter_injected               =  1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "Filter injected", value1 => $conf->{node}{$node}{lvm_filter},
			}, file => $THIS_FILE, line => __LINE__});
			next;
		}
		elsif (($line =~ /^filter = \[/) || ($line =~ /^\s+filter = \[/))
		{
			# Skip existing filter entries
		}
		# Test skip comments
		elsif ((not $line) || (($line =~ /^#/) || ($line =~ /^\s+#/)) || ($line =~ /^\s+$/))
		{
			### TODO: Fix Net::SSH2 so that we can write out larger files.
			# Skip comments
			next;
		}
		# Alter the locking type:
		if (($line =~ /^locking_type = /) || ($line =~ /^\s+locking_type = /))
		{
			$line =~ s/locking_type = .*/locking_type = 3/;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "Locking type set to 3", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
		}
		# Alter the fall-back locking
		if (($line =~ /^fallback_to_local_locking = /) || ($line =~ /^\s+fallback_to_local_locking = /))
		{
			$line =~ s/fallback_to_local_locking = .*/fallback_to_local_locking = 0/;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "Fallback to local locking set to 0", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
		}
		# And record.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		$conf->{node}{$node}{lvm_conf} .= "$line\n";
		if ($line eq "}")
		{
			# Add an extra blank line to make things more readible.
			$conf->{node}{$node}{lvm_conf} .= "\n";
		}
	}
	
	return(0);
}

# Reboots the nodes and updates the IPs we're using to connect to them if
# needed.
sub reboot_nodes
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "reboot_nodes" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# If neither node needs a reboot, don't print the lengthy message.
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	if ((($conf->{node}{$node1}{reboot_needed}) && (not $conf->{node}{$node1}{in_cluster})) || 
	    (($conf->{node}{$node2}{reboot_needed}) && (not $conf->{node}{$node2}{in_cluster})))
	{
		# This could take a while
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-be-patient-message", {
			message	=>	AN::Common::get_string($conf, {key => "explain_0141", variables => { url => "?config=true&do=new&run=$conf->{cgi}{run}&task=create-install-manifest" }}),
		});
	}
	
	# I do this sequentially for now, so that if one fails, the other
	# should still be up and hopefully provide a route into the lost one
	# for debugging.
	my $ok         = 1;
	my ($node1_rc) = do_node_reboot($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $conf->{cgi}{anvil_node1_bcn_ip});
	my $node2_rc   = 255;
	if ((not $node1_rc) || ($node1_rc eq "1") || ($node1_rc eq "5"))
	{
		($node2_rc) = do_node_reboot($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $conf->{cgi}{anvil_node2_bcn_ip});
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
	if (not $node1_rc)
	{
		# Node rebooted, change the IP we're using for it now.
		$conf->{cgi}{anvil_node1_current_ip} = $conf->{cgi}{anvil_node1_bcn_ip};
	}
	elsif ($node1_rc eq "1")
	{
		$node1_message = "#!string!state_0047!#",
	}
	elsif ($node1_rc == 2)
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0048!#",
		$ok            = 0;
	}
	elsif ($node1_rc == 3)
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0049!#",
		$ok            = 0;
	}
	elsif ($node1_rc == 4)
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0051!#",
		$ok            = 0;
	}
	elsif ($node1_rc == 5)
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0097!#",
	}
	# Node 2
	if ($node2_rc == 255)
	{
		# Aborted.
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0050!#",
		$ok            = 0;
	}
	elsif (not $node2_rc)
	{
		# Node rebooted, change the IP we're using for it now.
		$conf->{cgi}{anvil_node2_current_ip} = $conf->{cgi}{anvil_node2_bcn_ip};
	}
	elsif ($node2_rc eq "1")
	{
		$node2_message = "#!string!state_0047!#",
	}
	elsif ($node2_rc == 2)
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0048!#",
		$ok            = 0;
	}
	elsif ($node2_rc == 3)
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0049!#",
		$ok            = 0;
	}
	elsif ($node2_rc == 4)
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0051!#",
		$ok            = 0;
	}
	elsif ($node1_rc == 5)
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0097!#",
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0247!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	return($ok);
}

# This handles the actual rebooting of the node
sub do_node_reboot
{
	my ($conf, $node, $password, $new_bcn_ip) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "do_node_reboot" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node",       value1 => $node, 
		name2 => "new_bcn_ip", value2 => $new_bcn_ip, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $return_code = 255;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node::${node}::reboot_needed", value1 => $conf->{node}{$node}{reboot_needed},
	}, file => $THIS_FILE, line => __LINE__});
	if (not $conf->{node}{$node}{reboot_needed})
	{
		$return_code = 1;
		$an->Log->entry({log_level => 2, message_key => "log_0157", message_variables => {
			node => $node, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	elsif ($conf->{node}{$node}{in_cluster})
	{
		# Reboot needed, but the user has to do it.
		$return_code = 5;
		$an->Log->entry({log_level => 1, message_key => "log_0158", message_variables => {
			node => $node, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	else
	{
		# Reboot... Close the SSH FH as well.
		$an->Log->entry({log_level => 1, message_key => "log_0159", message_variables => {
			node => $node, 
		}, file => $THIS_FILE, line => __LINE__});
		my $shell_call = "reboot";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
			target		=>	$node,
			port		=>	$conf->{node}{$node}{port}, 
			password	=>	$password,
			ssh_fh		=>	"",
			'close'		=>	1,
			shell_call	=>	$shell_call,
		});
		foreach my $line (@{$return})
		{
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		### TODO: This can be racey when the server reboots very quickly (like a VM on a fast host)
		###       If the timeout is hit, log in and read the 'uptime'.
		# We need to give the system time to shut down.
		my $has_shutdown = 0;
		my $time_limit   = 120;
		my $uptime_max   = $time_limit + 60;
		my $timeout      = time + $time_limit;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "time",    value1 => time,
			name2 => "timeout", value2 => $timeout,
		}, file => $THIS_FILE, line => __LINE__});
		while (not $has_shutdown)
		{
			# 0 == pinged, 1 == failed.
			my $ping_rc = $an->Check->ping({target => $node, count => 3});
			if ($ping_rc eq "1")
			{
				$has_shutdown = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "has_shutdown", value1 => $has_shutdown,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Log in and see if the uptime is short.
				my $uptime     = 99999999;
				my $shell_call = $an->data->{path}{nodes}{cat}." /proc/uptime";
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "shell_call", value1 => $shell_call,
					name2 => "node",       value2 => $node,
				}, file => $THIS_FILE, line => __LINE__});
				my ($error, $ssh_fh, $return) = $an->Remote->remote_call({
					target		=>	$node,
					port		=>	$conf->{node}{$node}{port}, 
					password	=>	$password,
					ssh_fh		=>	"",
					'close'		=>	1,
					shell_call	=>	$shell_call,
				});
				foreach my $line (@{$return})
				{
					$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
						name1 => "line", value1 => $line, 
					}, file => $THIS_FILE, line => __LINE__});
					
					if ($line =~ /^(\d+)\./)
					{
						$uptime = $1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "uptime", value1 => $uptime, 
						}, file => $THIS_FILE, line => __LINE__});
					}
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "uptime",     value1 => $uptime, 
						name2 => "uptime_max", value2 => $uptime_max, 
					}, file => $THIS_FILE, line => __LINE__});
					if ($uptime < $uptime_max)
					{
						# We rebooted and missed it.
						$has_shutdown = 1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "has_shutdown", value1 => $has_shutdown, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
			}
			if (time > $timeout)
			{
				$return_code = 4;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "return_code", value1 => $return_code,
				}, file => $THIS_FILE, line => __LINE__});
				last;
			}
			sleep 3;
		}
		
		# Now loop for $conf->{sys}{reboot_timeout} seconds waiting to
		# see if the node recovers.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "has_shutdown", value1 => $has_shutdown,
		}, file => $THIS_FILE, line => __LINE__});
		if ($has_shutdown)
		{
			my $give_up_time = time + $conf->{sys}{reboot_timeout};
			my $wait         = 1;
			my $rc           = 255;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "time",      value1 => time,
				name2 => "give_up_time", value2 => $give_up_time,
			}, file => $THIS_FILE, line => __LINE__});
			while ($wait)
			{
				my $time      = time;
				my $will_wait = ($give_up_time - $time);
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "time",         value1 => $time,
					name2 => "give_up_time", value2 => $give_up_time,
					name3 => "will wait",    value3 => $will_wait,
				}, file => $THIS_FILE, line => __LINE__});
				if ($time > $give_up_time)
				{
					last;
				}
				($rc) = connect_to_node($conf, $new_bcn_ip, $password);
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "new_bcn_ip", value1 => $new_bcn_ip,
					name2 => "rc",         value2 => $rc,
				}, file => $THIS_FILE, line => __LINE__});
				# Return codes:
				# 0 = Successfully logged in
				# 1 = Could ping, but couldn't log in
				# 2 = Couldn't ping.
				if ($rc == 0)
				{
					# Woot!
					$wait = 0;
					if ($node ne $new_bcn_ip)
					{
						# Copy the hash reference to the new IP.
						$conf->{node}{$new_bcn_ip} = $conf->{node}{$node};
						$an->Log->entry({log_level => 2, message_key => "log_0160", message_variables => {
							node   => $node, 
							bcn_ip => $new_bcn_ip, 
						}, file => $THIS_FILE, line => __LINE__});
					}
				}
				sleep 1;
			}
			
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "rc", value1 => $rc,
			}, file => $THIS_FILE, line => __LINE__});
			if ($rc == 0)
			{
				# Success! Rescan storage.
				$return_code = 0;
				$an->Log->entry({log_level => 2, message_key => "log_0161", file => $THIS_FILE, line => __LINE__});
				
				# Rescan it's (new) partition data.
				my ($node_disk) = get_partition_data($conf, $new_bcn_ip, $password);
				$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
					name1 => "node", value1 => $new_bcn_ip,
					name2 => "disk", value2 => $node_disk,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($rc == 1)
			{
				$return_code = 2;
			}
			elsif ($rc == 2)
			{
				$return_code = 3;
			}
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "return_code", value1 => $return_code,
	}, file => $THIS_FILE, line => __LINE__});
	return($return_code);
}

# This function first tries to ping a node. If the ping is successful, it will try to log into the node..
sub connect_to_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "connect_to_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# 0 = Successfully logged in
	# 1 = Could ping, but couldn't log in
	# 2 = Couldn't ping.
	my $rc = 2;
	
	# 0 == pinged, 1 == failed.
	my $ping_rc = $an->Check->ping({target => $node, count => 3});
	if ($ping_rc eq "0")
	{
		# Pingable! Can we log in?
		$an->Log->entry({log_level => 2, message_key => "log_0162", message_variables => {
			node => $node, 
		}, file => $THIS_FILE, line => __LINE__});
		$rc = 1;
		if (check_node_access($conf, $node, $password))
		{
			# We're in!
			$rc = 0;
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
		name1 => "rc", value1 => $rc,
	}, file => $THIS_FILE, line => __LINE__});
	return($rc);
}

# This does the work of adding a specific repo to a node.
sub add_repo_to_node
{
	my ($conf, $node, $password, $url) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "add_repo_to_node" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node", value1 => $node, 
		name2 => "url",  value2 => $url, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $rc = 0;
	my $repo_file = ($url =~ /^.*\/(.*?)$/)[0];
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "repo_file", value1 => $repo_file,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $repo_file)
	{
		$rc        = 3;
		$repo_file = $url;
	}
	else
	{
		# Now call the client.
		my $shell_call = "
if [ -e '/etc/yum.repos.d/$repo_file' ];
then
    echo 1;
else
    curl --silent $url --output /etc/yum.repos.d/$repo_file;
    if [ -e '/etc/yum.repos.d/$repo_file' ];
    then
        yum clean all --quiet;
        echo 2;
    else
        echo 9;
    fi;
fi
if grep -q gpgcheck=1 /etc/yum.repos.d/$repo_file;
then 
    local_file=\$(grep gpgkey /etc/yum.repos.d/$repo_file | sed 's/gpgkey=file:\\/\\/\\(.*\\)/\\1/');
    file=\$(grep gpgkey /etc/yum.repos.d/$repo_file | sed 's/gpgkey=file:\\/\\/\\/etc\\/pki\\/rpm-gpg\\/\\(.*\\)/\\1/')
    url=\$(grep baseurl /etc/yum.repos.d/$repo_file | sed 's/baseurl=//');
    echo 'Downloading the GPG key: [curl \$url/\$file > \$local_file]'
    curl \$url/\$file > \$local_file
fi";
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
			$rc = $line;
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "rc",        value1 => $rc,
		name2 => "repo_file", value2 => $repo_file,
	}, file => $THIS_FILE, line => __LINE__});
	return ($rc, $repo_file);
}

# This downloads user-specified repositories to the nodes
sub add_user_repositories
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "add_user_repositories" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "anvil_repositories", value1 => $conf->{cgi}{anvil_repositories},
	}, file => $THIS_FILE, line => __LINE__});
	if ($conf->{cgi}{anvil_repositories})
	{
		# Add repos to nodes
		foreach my $url (split/,/, $conf->{cgi}{anvil_repositories})
		{
			my ($node1_rc, $repo_file) = add_repo_to_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $url);
			my ($node2_rc)             = add_repo_to_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $url);
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "node1_rc",  value1 => $node1_rc,
				name2 => "node2_rc",  value2 => $node2_rc,
				name3 => "repo_file", value3 => $repo_file,
			}, file => $THIS_FILE, line => __LINE__});
			
			# Return codes:
			# 0 = Nothing happened at all, wut?
			# 1 = Already exists
			# 2 = Added successfully
			# 3 = Unable to parse repository file from path: [$url]
			# 9 = Failed to add.
			my $ok            = 1;
			my $node1_class   = "highlight_good_bold";
			my $node1_message = "#!string!state_0020!#";
			my $node2_class   = "highlight_good_bold";
			my $node2_message = "#!string!state_0020!#";
			my $message       = "";
			# Node 1
			if ($node1_rc eq "0")
			{
				$node1_class   = "highlight_warning_bold";
				$node1_message = "#!string!state_0038!#";
				$ok            = 0;
			}
			elsif ($node1_rc eq "2")
			{
				$node1_class   = "highlight_good_bold";
				$node1_message = "#!string!state_0023!#";
			}
			elsif ($node1_rc eq "3")
			{
				$node1_class   = "highlight_warning_bold";
				$node1_message = "#!string!state_0039!#";
				$ok            = 0;
			}
			elsif ($node1_rc eq "9")
			{
				$node1_class   = "highlight_warning_bold";
				$node1_message = "#!string!state_0018!#";
				$ok            = 0;
			}
			# Node 2
			if ($node2_rc eq "0")
			{
				$node2_class   = "highlight_warning_bold";
				$node2_message = "#!string!state_0038!#";
				$ok            = 0;
			}
			elsif ($node2_rc eq "2")
			{
				$node2_class   = "highlight_good_bold";
				$node2_message = "#!string!state_0023!#";
			}
			elsif ($node2_rc eq "3")
			{
				$node2_class   = "highlight_warning_bold";
				$node2_message = "#!string!state_0039!#";
				$ok            = 0;
			}
			elsif ($node2_rc eq "9")
			{
				$node2_class   = "highlight_warning_bold";
				$node2_message = "#!string!state_0018!#";
				$ok            = 0;
			}

			print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
				row		=>	AN::Common::get_string($conf, {key => "row_0245", variables => { repo => "$repo_file" }}),
				node1_class	=>	$node1_class,
				node1_message	=>	$node1_message,
				node2_class	=>	$node2_class,
				node2_message	=>	$node2_message,
			});
			
			if (not $ok)
			{
				print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
					message	=>	"#!string!message_0387!#",
					row	=>	"#!string!state_0040!#",
				});
			}
		}
	}
	
	return(0);
}

# This performs an actual partition creation
sub create_partition_on_node
{
	my ($conf, $node, $password, $disk, $type, $partition_size) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "create_partition_on_node" }, message_key => "an_variables_0004", message_variables => { 
		name1 => "node",           value1 => $node, 
		name2 => "disk",           value2 => $disk, 
		name3 => "type",           value3 => $type, 
		name4 => "partition_size", value4 => $partition_size, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $created = 0;
	my $ok      = 1;
	my $start   = 0;
	my $end     = 0;
	my $size    = 0;
	### NOTE: Parted, in it's infinite wisdom, doesn't show the partition type when called with --machine
	#my $shell_call = "parted --machine /dev/$disk unit GiB print free";
	my $shell_call = "parted /dev/$disk unit GiB print free";
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
	
	# Hard to proceed if I don't have the start and end sizes.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node",  value1 => $node,
		name2 => "disk",  value2 => $disk,
		name3 => "start", value3 => $start,
		name4 => "end",   value4 => $end,
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $start) || (not $end))
	{
		# :(
		$ok = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "node",           value1 => $node,
			name2 => "disk",           value2 => $disk,
			name3 => "type",           value3 => $type,
			name4 => "partition_size", value4 => $partition_size,
		}, file => $THIS_FILE, line => __LINE__});
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
			message	=>	AN::Common::get_string($conf, {key => "message_0389", variables => { 
				node		=>	$node, 
				disk		=>	$disk,
				type		=>	$type,
				size		=>	AN::Cluster::bytes_to_hr($conf, $partition_size)." ($partition_size #!string!suffix_0009!#)",
				shell_call	=>	$shell_call,
			}}),
			row	=>	"#!string!state_0042!#",
		});
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
				# Warn the user and then shrink the end.
				print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
					message	=>	AN::Common::get_string($conf, {key => "message_0391", variables => { 
						node		=>	$node, 
						disk		=>	$disk,
						type		=>	$type,
						old_end		=>	AN::Cluster::bytes_to_hr($conf, $use_end)." ($use_end #!string!suffix_0009!#)",
						new_end		=>	AN::Cluster::bytes_to_hr($conf, $end)." ($end #!string!suffix_0009!#)",
						shell_call	=>	$shell_call,
					}}),
					row	=>	"#!string!state_0043!#",
				});
				$use_end = $end;
			}
		}
		$an->Log->entry({log_level => 2, message_key => "an_variables_0005", message_variables => {
			name1 => "snode",       value1 => $node,
			name2 => "disk",        value2 => $disk,
			name3 => "type",        value3 => $type,
			name4 => "start (GiB)", value4 => $start,
			name5 => "end (GiB)",   value5 => $end,
		}, file => $THIS_FILE, line => __LINE__});
		
		my $shell_call = "parted -a opt /dev/$disk mkpart $type ${start}GiB ${use_end}GiB";
		if ($use_end eq "100%")
		{
			$shell_call = "parted -a opt /dev/$disk mkpart $type ${start}GiB 100%";
		}
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
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
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
				print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
					message	=>	AN::Common::get_string($conf, {key => "message_0390", variables => { 
						node		=>	$node, 
						disk		=>	$disk,
						type		=>	$type,
						start		=>	AN::Cluster::bytes_to_hr($conf, $start)." ($start #!string!suffix_0009!#)",
						end		=>	AN::Cluster::bytes_to_hr($conf, $end)." ($end #!string!suffix_0009!#)",
						shell_call	=>	$shell_call,
					}}),
					row	=>	"#!string!state_0042!#",
				});
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
				print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
					message	=>	AN::Common::get_string($conf, {key => "message_0431", variables => { 
						node		=>	$node, 
						disk		=>	$disk,
						type		=>	$type,
						start		=>	AN::Cluster::bytes_to_hr($conf, $start)." ($start #!string!suffix_0009!#)",
						end		=>	AN::Cluster::bytes_to_hr($conf, $end)." ($end #!string!suffix_0009!#)",
						shell_call	=>	$shell_call,
					}}),
					row	=>	"#!string!state_0099!#",
				});
			}
			if ($line =~ /reboot/)
			{
				# Reboot needed.
				$an->Log->entry({log_level => 2, message_key => "log_0159", message_variables => {
					node => $node, 
				}, file => $THIS_FILE, line => __LINE__});
				$conf->{node}{$node}{reboot_needed} = 1;
			}
		}
		$created = 1 if $ok;
	}
	
	# Set 'ok' to 2 if we created a partition.
	if (($ok) && ($created))
	{
		$ok = 2;
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This looks on a given device for DRBD metadata
sub check_device_for_drbd_metadata
{
	my ($conf, $node, $password, $device) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_device_for_drbd_metadata" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node",   value1 => $node, 
		name2 => "device", value2 => $device, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $is_drbd    = 0;
	my $shell_call = "drbdmeta --force 0 v08 $device internal dump-md; echo rc:\$?";
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			# 0   == drbd md found
			# 10  == too small for DRBD
			# 20  == device not found
			# 255 == device exists but has no metadata
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "rc", value1 => $rc, 
			}, file => $THIS_FILE, line => __LINE__});
			if ($rc eq "0")
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
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "is_drbd", value1 => $is_drbd,
	}, file => $THIS_FILE, line => __LINE__});
	return($is_drbd);
}

# This calls 'blkid' and parses the output for the given device, if returned.
sub check_blkid_partition
{
	my ($conf, $node, $password, $device) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_blkid_partition" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node",   value1 => $node, 
		name2 => "device", value2 => $device, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $uuid       = "";
	my $type       = "";
	my $shell_call = "blkid -c /dev/null $device";
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

# This checks the disk for DRBD metadata
sub check_for_drbd_metadata
{
	my ($conf, $node, $password, $device) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_for_drbd_metadata" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node",   value1 => $node, 
		name2 => "device", value2 => $device, 
	}, file => $THIS_FILE, line => __LINE__});
	
	return(3) if not $device;
	
	# I do both checks because blkid tells me what's on the partition, but
	# if there is something on top of DRBD, it will report that instead, so
	# it can't be entirely trusted. If the 'blkid' returns type
	# 'LVM2_member' but it is also 'is_drbd', then it is already setup.
	my ($type)    = check_blkid_partition($conf, $node, $password, $device);
	my ($is_drbd) = check_device_for_drbd_metadata($conf, $node, $password, $device);
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "type",    value1 => $type,
		name2 => "is_drbd", value2 => $is_drbd,
	}, file => $THIS_FILE, line => __LINE__});
	my $return_code = 255;
	### blkid now returns no type for DRBD.
	if (($type eq "drbd") || ($is_drbd))
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
	}
	else
	{
		# Make sure there is a device at all
		$an->Log->entry({log_level => 2, message_key => "log_0167", message_variables => {
			node   => $node, 
			device => $device
		}, file => $THIS_FILE, line => __LINE__});
		my ($disk, $partition) = ($device =~ /\/dev\/(\D+)(\d)/);
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "disk",                                                        value1 => $disk,
			name2 => "partition",                                                   value2 => $partition,
			name3 => "node::${node}::disk::${disk}::partition::${partition}::size", value3 => $conf->{node}{$node}{disk}{$disk}{partition}{$partition}{size},
		}, file => $THIS_FILE, line => __LINE__});
		if ($conf->{node}{$node}{disk}{$disk}{partition}{$partition}{size})
		{
			# It exists, so we can assume it has no DRBD metadata or anything else.
			$an->Log->entry({log_level => 2, message_key => "log_0168", file => $THIS_FILE, line => __LINE__});
			my $resource = "";
			if ($device eq $conf->{node}{$node}{pool1}{device})
			{
				$resource = "r0";
			}
			elsif ($device eq $conf->{node}{$node}{pool2}{device})
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
				my $rc         = 255;
				my $shell_call = "$conf->{path}{nodes}{drbdadm} -- --force create-md $resource; echo rc:\$?";
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
					
					if ($line =~ /^rc:(\d+)/)
					{
						# 0 == Success
						# 3 == Configuration not found.
						$rc = $1;
						$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
							name1 => "DRBD meta-data creation return code", value1 => $rc,
						}, file => $THIS_FILE, line => __LINE__});
						if (not $rc)
						{
							$return_code = 0;
						}
						elsif ($rc eq "3")
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

### This is a duplication of effort, in part, of get_storage_pool_partitions()...
# This uses 'parted' to gather the existing partition data on a node.
sub get_partition_data_from_node
{
	my ($conf, $node, $disk, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 2, title_key => "tools_log_0001", title_variables => { function => "get_partition_data_from_node" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node", value1 => $node, 
		name2 => "disk", value2 => $disk, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### NOTE: Parted, in it's infinite wisdom, doesn't show the partition type when called with --machine
	my $shell_call = "parted /dev/$disk unit GiB print free";
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
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node", value1 => $node,
			name2 => "disk", value2 => $disk,
			name3 => "line", value3 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /([\d\.]+)GiB ([\d\.]+)GiB ([\d\.]+)GiB Free/i)
		{
			my $start = $1;
			my $end   = $2;
			my $size  = $3;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
				name1 => "start", value1 => $start,
				name2 => "end",   value2 => $end,
				name3 => "size",  value3 => $size,
			}, file => $THIS_FILE, line => __LINE__});
			
			# Sometimes there is a tiny bit of free space in some places, like the start of a 
			# disk. Ignore those.
			if ((not $size) or ($size =~ /^0\./))
			{
				# Small amount of space, ignore it.
				$an->Log->entry({log_level => 2, message_key => "log_0172", file => $THIS_FILE, line => __LINE__});
			}
			
			### NOTE: This will miss multiple sizable free chunks.
			# Record the free space info.
			$conf->{node}{$node}{partition}{free_space}{start} = $start;
			$conf->{node}{$node}{partition}{free_space}{end}   = $end;
			$conf->{node}{$node}{partition}{free_space}{size}  = $size;
		}
		elsif ($line =~ /(\d+) ([\d\.]+)GiB ([\d\.]+)GiB ([\d\.]+)GiB(.*)$/)
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
				name4 => "size",      value4 => $size,
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
			
			$conf->{node}{$node}{partition}{$partition}{start} = $start;
			$conf->{node}{$node}{partition}{$partition}{end}   = $end;
			$conf->{node}{$node}{partition}{$partition}{size}  = $size;
			$conf->{node}{$node}{partition}{$partition}{type}  = $type;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
				name1 => "node::${node}::partition::${partition}::start", value1 => $conf->{node}{$node}{partition}{$partition}{start},
				name2 => "node::${node}::partition::${partition}::end",   value2 => $conf->{node}{$node}{partition}{$partition}{end},
				name3 => "node::${node}::partition::${partition}::size",  value3 => $conf->{node}{$node}{partition}{$partition}{size},
				name4 => "node::${node}::partition::${partition}::type",  value4 => $conf->{node}{$node}{partition}{$partition}{type},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

# This does the first stage of the storage configuration. Specifically, it 
# partitions the drives. Systems using one disk will need to reboot after this.
sub configure_storage_stage1
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_storage_stage1" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ok    = 1;
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	
	# Make things a little easier to follow...
	my $node1_pool1_disk      = $conf->{node}{$node1}{pool1}{disk};
	my $node1_pool1_partition = $conf->{node}{$node1}{pool1}{partition};
	my $node1_pool2_disk      = $conf->{node}{$node1}{pool2}{disk};
	my $node1_pool2_partition = $conf->{node}{$node1}{pool2}{partition};
	my $node2_pool1_disk      = $conf->{node}{$node2}{pool1}{disk};
	my $node2_pool1_partition = $conf->{node}{$node2}{pool1}{partition};
	my $node2_pool2_disk      = $conf->{node}{$node2}{pool2}{disk};
	my $node2_pool2_partition = $conf->{node}{$node2}{pool2}{partition};
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
	my $node1_partition_data = get_partition_data_from_node($conf, $node1, $node1_pool1_disk, $conf->{cgi}{anvil_node1_current_password});
	my $node2_partition_data = get_partition_data_from_node($conf, $node2, $node2_pool1_disk, $conf->{cgi}{anvil_node2_current_password});
	
	# If an extended partition is needed on either node, create it/them now.
	my $node1_partition_type = "primary";
	my $node2_partition_type = "primary";
	# Node 1 extended.
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node::${node1}::pool1::create_extended", value1 => $conf->{node}{$node1}{pool1}{create_extended},
	}, file => $THIS_FILE, line => __LINE__});
	if ($conf->{node}{$node1}{pool1}{create_extended})
	{
		$node1_partition_type = "logical";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node1}::disk::${node1_pool1_disk}::partition::4::type", value1 => $conf->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{4}{type},
			name2 => "node::${node1}::partition::4::type",                            value2 => $conf->{node}{$node1}{partition}{4}{type},
		}, file => $THIS_FILE, line => __LINE__});
		if (($conf->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{4}{type}) && ($conf->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{4}{type} eq "extended"))
		{
			# Already exists.
			$an->Log->entry({log_level => 2, message_key => "log_0173", message_variables => {
				node => $node1, 
				disk => $node1_pool1_disk, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (($conf->{node}{$node1}{partition}{4}{type}) && ($conf->{node}{$node1}{partition}{4}{type} eq "extended"))
		{
			# Extended partition already exists
			$an->Log->entry({log_level => 2, message_key => "log_0174", file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			my ($rc) = create_partition_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $node1_pool1_disk, "extended", "all");
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "rc", value1 => $rc,
			}, file => $THIS_FILE, line => __LINE__});
			if ($rc eq "0")
			{
				# Failed
				$ok = 0;
				$an->Log->entry({log_level => 1, message_key => "log_0175", message_variables => {
					node => $node1, 
					disk => $node1_pool1_disk, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($rc eq "2")
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
	if ($conf->{node}{$node2}{pool1}{create_extended})
	{
		$node2_partition_type = "logical";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node2}::disk::${node2_pool1_disk}::partition::4::type", value1 => $conf->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{4}{type},
			name2 => "node::${node2}::partition::4::type",                            value2 => $conf->{node}{$node2}{partition}{4}{type},
		}, file => $THIS_FILE, line => __LINE__});
		if (($conf->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{4}{type}) && ($conf->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{4}{type} eq "extended"))
		{
			# Already exists.
			$an->Log->entry({log_level => 2, message_key => "log_0173", message_variables => {
				node => $node2, 
				disk => $node2_pool1_disk, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif (($conf->{node}{$node2}{partition}{4}{type}) && ($conf->{node}{$node2}{partition}{4}{type} eq "extended"))
		{
			# Extended partition already exists
			$an->Log->entry({log_level => 2, message_key => "log_0174", file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			my ($rc) = create_partition_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $node2_pool1_disk, "extended", "all");
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "rc", value1 => $rc,
			}, file => $THIS_FILE, line => __LINE__});
			if ($rc eq "0")
			{
				# Failed
				$ok = 0;
				$an->Log->entry({log_level => 1, message_key => "log_0175", message_variables => {
					node => $node2, 
					disk => $node2_pool1_disk, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($rc eq "2")
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
	# Node 1, Pool 1.
	if ($conf->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{$node1_pool1_partition}{size})
	{
		# Already exists
		$node1_pool1_created = 2;
	}
	else
	{
		# Create node 1, pool 1.
		my ($rc) = create_partition_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $node1_pool1_disk, $node1_partition_type, $conf->{cgi}{anvil_storage_pool1_byte_size});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "rc", value1 => $rc,
		}, file => $THIS_FILE, line => __LINE__});
		if ($rc eq "0")
		{
			# Failed
			$ok = 0;
			$an->Log->entry({log_level => 1, message_key => "log_0177", message_variables => {
				type    => $node1_partition_type, 
				pool    => "1", 
				node    => $node1, 
				disk    => $node1_pool1_disk, 
				size    => $conf->{cgi}{anvil_storage_pool1_byte_size}, 
				hr_size => AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}), 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($rc eq "2")
		{
			# Succcess
			$node1_pool1_created = 1;
			$an->Log->entry({log_level => 2, message_key => "log_0178", message_variables => {
				type    => $node1_partition_type, 
				pool    => "1", 
				node    => $node1, 
				disk    => $node1_pool1_disk, 
				size    => $conf->{cgi}{anvil_storage_pool1_byte_size}, 
				hr_size => AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}), 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	# Node 1, Pool 2.
	if ($conf->{cgi}{anvil_storage_pool2_byte_size})
	{
		if ($conf->{node}{$node1}{disk}{$node1_pool2_disk}{partition}{$node1_pool2_partition}{size})
		{
			# Already exists
			$node1_pool2_created = 2;
		}
		else
		{
			### TODO: Determine if it's better to always make the size of pool 2 "all".
			# Create node 1, pool 2.
			my ($rc) = create_partition_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $node1_pool2_disk, $node1_partition_type, $conf->{cgi}{anvil_storage_pool2_byte_size});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "rc", value1 => $rc,
			}, file => $THIS_FILE, line => __LINE__});
			if ($rc eq "0")
			{
				# Failed
				$ok = 0;
				$an->Log->entry({log_level => 1, message_key => "log_0177", message_variables => {
					type    => $node1_partition_type, 
					pool    => "2", 
					node    => $node1, 
					disk    => $node1_pool2_disk, 
					size    => $conf->{cgi}{anvil_storage_pool2_byte_size}, 
					hr_size => AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}), 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($rc eq "2")
			{
				# Succcess
				$node1_pool2_created = 1;
				$an->Log->entry({log_level => 2, message_key => "log_0178", message_variables => {
					type    => $node1_partition_type, 
					pool    => "2", 
					node    => $node1, 
					disk    => $node1_pool2_disk, 
					size    => $conf->{cgi}{anvil_storage_pool2_byte_size}, 
					hr_size => AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}), 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	else
	{
		$node1_pool2_created = 3;
	}
	# Node 2, Pool 1.
	if ($conf->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{$node2_pool1_partition}{size})
	{
		# Already exists
		$node2_pool1_created = 2;
	}
	else
	{
		# Create node 2, pool 1.
		my ($rc) = create_partition_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $node2_pool1_disk, $node2_partition_type, $conf->{cgi}{anvil_storage_pool1_byte_size});
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "rc", value1 => $rc,
		}, file => $THIS_FILE, line => __LINE__});
		if ($rc eq "0")
		{
			# Failed
			$ok = 0;
			$an->Log->entry({log_level => 1, message_key => "log_0177", message_variables => {
				type    => $node2_partition_type, 
				pool    => "1", 
				node    => $node2, 
				disk    => $node2_pool1_disk, 
				size    => $conf->{cgi}{anvil_storage_pool1_byte_size}, 
				hr_size => AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}), 
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($rc eq "2")
		{
			# Succcess
			$node2_pool1_created = 1;
			$an->Log->entry({log_level => 2, message_key => "log_0178", message_variables => {
				type    => $node2_partition_type, 
				pool    => "1", 
				node    => $node2, 
				disk    => $node2_pool1_disk, 
				size    => $conf->{cgi}{anvil_storage_pool1_byte_size}, 
				hr_size => AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}), 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	# Node 2, Pool 2.
	if ($conf->{cgi}{anvil_storage_pool2_byte_size})
	{
		if ($conf->{node}{$node2}{disk}{$node2_pool2_disk}{partition}{$node2_pool2_partition}{size})
		{
			# Already exists
			$node2_pool2_created = 2;
		}
		else
		{
			### TODO: Determine if it's better to always make the size of pool 2 "all".
			# Create node 2, pool 2.
			my ($rc) = create_partition_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $node2_pool2_disk, $node2_partition_type, $conf->{cgi}{anvil_storage_pool2_byte_size});
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "rc", value1 => $rc,
			}, file => $THIS_FILE, line => __LINE__});
			if ($rc eq "0")
			{
				# Failed
				$ok = 0;
				$an->Log->entry({log_level => 1, message_key => "log_0177", message_variables => {
					type    => $node2_partition_type, 
					pool    => "2", 
					node    => $node2, 
					disk    => $node2_pool2_disk, 
					size    => $conf->{cgi}{anvil_storage_pool2_byte_size}, 
					hr_size => AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}), 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($rc eq "2")
			{
				# Succcess
				$node2_pool2_created = 1;
				$an->Log->entry({log_level => 2, message_key => "log_0178", message_variables => {
					type    => $node2_partition_type, 
					pool    => "2", 
					node    => $node2, 
					disk    => $node2_pool2_disk, 
					size    => $conf->{cgi}{anvil_storage_pool2_byte_size}, 
					hr_size => AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}), 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	else
	{
		$node2_pool2_created = 3;
	}
	
	# Default to 'created'.
	my $node1_pool1_class   = "highlight_good_bold";
	my $node1_pool1_message = "#!string!state_0045!#";
	my $node2_pool1_class   = "highlight_good_bold";
	my $node2_pool1_message = "#!string!state_0045!#";
	if ($node1_pool1_created eq "0")
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
	if ($node2_pool1_created eq "0")
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
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0246!#",
		node1_class	=>	$node1_pool1_class,
		node1_message	=>	$node1_pool1_message,
		node2_class	=>	$node2_pool1_class,
		node2_message	=>	$node2_pool1_message,
	});
	
	return($ok);
}

sub configure_storage_stage2
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_storage_stage2" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	# Create the DRBD config files which will be stored in:
	# * $conf->{drbd}{global_common}
	# * $conf->{drbd}{r0}
	# * $conf->{drbd}{r1}
	# If the config file(s) exist already on one of the nodes, they will be
	# used instead.
	my ($rc) = generate_drbd_config_files($conf);
	# 0 = OK
	# 1 = Failed to determine the DRBD backing device(s);
	# 2 = Failed to determine the SN IPs.
	
	# Now setup DRBD on the nods.
	my ($node1_pool1_rc, $node1_pool2_rc) = setup_drbd_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_pool1_rc, $node2_pool2_rc) = setup_drbd_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	# 0 = Created
	# 1 = Already had meta-data, nothing done
	# 2 = Partition not found
	# 3 = No device passed.
	# 4 = Foreign signature found on device
	# 5 = Device doesn't match to a DRBD resource
	# 6 = DRBD resource not defined
	# 7 = N/A (no pool 2)
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node1_pool1_rc", value1 => $node1_pool1_rc,
		name2 => "node1_pool2_rc", value2 => $node1_pool2_rc,
		name3 => "node2_pool1_rc", value3 => $node2_pool1_rc,
		name4 => "node2_pool2_rc", value4 => $node2_pool2_rc,
	}, file => $THIS_FILE, line => __LINE__});
	
	# 0 = Created
	# 1 = Already had meta-data, nothing done
	# 2 = Partition not found
	# 3 = No device passed.
	# 4 = Foreign signature found on device
	# 5 = Device doesn't match to a DRBD resource
	# 6 = DRBD resource not defined

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
	if ($node1_pool1_rc eq "1")
	{
		# Already existed
		$node1_message = "#!string!state_0020!#";
	}
	elsif ($node1_pool1_rc eq "2")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = AN::Common::get_string($conf, {key => "state_0055", variables => { device => $conf->{node}{$node1}{pool1}{device} }});
		$ok            = 0;
	}
	elsif ($node1_pool1_rc eq "3")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0056!#";
		$ok            = 0;
	}
	elsif ($node1_pool1_rc eq "4")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = AN::Common::get_string($conf, {key => "state_0057", variables => { device => $conf->{node}{$node1}{pool1}{device} }});
		$ok            = 0;
		$show_lvm_note = 1;
	}
	elsif ($node1_pool1_rc eq "5")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = AN::Common::get_string($conf, {key => "state_0058", variables => { device => $conf->{node}{$node1}{pool1}{device} }});
		$ok            = 0;
	}
	elsif ($node1_pool1_rc eq "6")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0059!#";
		$ok            = 0;
	}
	# Node 2, Pool 1
	if ($node2_pool1_rc eq "1")
	{
		# Already existed
		$node2_message = "#!string!state_0020!#";
	}
	elsif ($node2_pool1_rc eq "2")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = AN::Common::get_string($conf, {key => "state_0055", variables => { device => $conf->{node}{$node2}{pool1}{device} }});
		$ok            = 0;
	}
	elsif ($node2_pool1_rc eq "3")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0056!#";
		$ok            = 0;
	}
	elsif ($node2_pool1_rc eq "4")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = AN::Common::get_string($conf, {key => "state_0057", variables => { device => $conf->{node}{$node2}{pool1}{device} }});
		$show_lvm_note = 1;
		$ok            = 0;
	}
	elsif ($node2_pool1_rc eq "5")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = AN::Common::get_string($conf, {key => "state_0058", variables => { device => $conf->{node}{$node2}{pool1}{device} }});
		$ok            = 0;
	}
	elsif ($node2_pool1_rc eq "6")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0059!#";
		$ok            = 0;
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0249!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	if (not $ok)
	{
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
			message	=>	"#!string!message_0398!#",
			row	=>	"#!string!state_0034!#",
		});
	}
	
	# Tell the user they may need to 'dd' the partition, if needed.
	if ($show_lvm_note)
	{
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-note-message", {
			message	=>	"#!string!message_0433!#",
			row	=>	"#!string!row_0032!#",
		});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This generates the DRBD config files to later be written on the nodes.
sub generate_drbd_config_files
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "generate_drbd_config_files" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	
	### TODO: Detect if the SN is on a 10 Gbps network and, if so, bump up
	###       the resync rate to 300M;
	# Generate the config files we'll use if we don't find existing configs
	# on one of the servers.
	$conf->{drbd}{global_common} = "
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
		fence-peer \"/sbin/striker/rhcs_fence\";
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
	if ($conf->{cgi}{'anvil_drbd_options_cpu-mask'})
	{
		$conf->{drbd}{global_common} .= "		cpu-mask $conf->{cgi}{'anvil_drbd_options_cpu-mask'};\n";
	}
	$conf->{drbd}{global_common} .= "		# Regarding LINBIT Ticket# 2015110642000184; Setting this to 
		# 'suspend-io' is safest given the risk of data divergence in
		# some corner cases.
		on-no-data-accessible suspend-io;
	}
 
	disk {
		# size max-bio-bvecs on-io-error fencing disk-barrier disk-flushes
		# disk-drain md-flushes resync-rate resync-after al-extents
		# c-plan-ahead c-delay-target c-fill-target c-max-rate
		# c-min-rate disk-timeout
		fencing resource-and-stonith;\n";
	if ($conf->{cgi}{'anvil_drbd_disk_disk-barrier'})
	{
		$conf->{drbd}{global_common} .= "		disk-barrier $conf->{cgi}{'anvil_drbd_disk_disk-barrier'};\n";
	}
	if ($conf->{cgi}{'anvil_drbd_disk_disk-flushes'})
	{
		$conf->{drbd}{global_common} .= "		disk-flushes $conf->{cgi}{'anvil_drbd_disk_disk-flushes'};\n";
	}
	if ($conf->{cgi}{'anvil_drbd_disk_md-flushes'})
	{
		$conf->{drbd}{global_common} .= "		md-flushes $conf->{cgi}{'anvil_drbd_disk_md-flushes'};\n";
	}
	$conf->{drbd}{global_common} .= "	}
 
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
		after-sb-2pri disconnect;\n";
	if ($conf->{cgi}{'anvil_drbd_net_max-buffers'})
	{
		$conf->{drbd}{global_common} .= "		max-buffers $conf->{cgi}{'anvil_drbd_net_max-buffers'};\n";
	}
	if ($conf->{cgi}{'anvil_drbd_net_sndbuf-size'})
	{
		$conf->{drbd}{global_common} .= "		sndbuf-size $conf->{cgi}{'anvil_drbd_net_sndbuf-size'};\n";
	}
	if ($conf->{cgi}{'anvil_drbd_net_rcvbuf-size'})
	{
		$conf->{drbd}{global_common} .= "		rcvbuf-size $conf->{cgi}{'anvil_drbd_net_rcvbuf-size'};\n";
	}
	$conf->{drbd}{global_common} .= "	}
}
";
	
	### TODO: Make sure these are updated if we use a read-in resource
	###  file.
	my $node1_pool1_partition = $conf->{node}{$node1}{pool1}{device};
	my $node1_pool2_partition = $conf->{node}{$node1}{pool2}{device};
	my $node2_pool1_partition = $conf->{node}{$node2}{pool1}{device};
	my $node2_pool2_partition = $conf->{node}{$node2}{pool2}{device};
	if ((not $node1_pool1_partition) ||
	    (not $node1_pool2_partition) ||
	    (not $node2_pool1_partition) ||
	    (not $node2_pool2_partition))
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "Failed to determine DRBD resource backing devices!; node1_pool1_partition", value1 => $node1_pool1_partition,
			name2 => "node1_pool2_partition",                                                     value2 => $node1_pool2_partition,
			name3 => "node2_pool1_partition",                                                     value3 => $node2_pool1_partition,
			name4 => "node2_pool2_partition",                                                     value4 => $node2_pool2_partition,
		}, file => $THIS_FILE, line => __LINE__});
		return(1);
	}
	
	my $node1_sn_ip_key = "anvil_node1_sn_ip";
	my $node2_sn_ip_key = "anvil_node2_sn_ip";
	my $node1_sn_ip     = $conf->{cgi}{$node1_sn_ip_key};
	my $node2_sn_ip     = $conf->{cgi}{$node2_sn_ip_key};
	if ((not $node1_sn_ip) || (not $node2_sn_ip))
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "Failed to determine Storage Network IPs!; node1_sn_ip", value1 => $node1_sn_ip,
			name2 => "node2_sn_ip",                                           value2 => $node2_sn_ip,
		}, file => $THIS_FILE, line => __LINE__});
		return(2);
	}
	
	# Still alive? Yay us!
	$conf->{drbd}{r0} = "
# This is the first DRBD resource. It will store the shared file systems and
# the servers designed to run on node 01.
resource r0 {
	on $conf->{cgi}{anvil_node1_name} {
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
	on $conf->{cgi}{anvil_node2_name} {
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

	$conf->{drbd}{r1} = "
# This is the resource used for the servers designed to run on node 02.
resource r1 {
	on $conf->{cgi}{anvil_node1_name} {
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
	on $conf->{cgi}{anvil_node2_name} {
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
	
	# Unlike 'read_drbd_resource_files()' which only reads the 'rX.res'
	# files and parses their contents, this function just slurps in the
	# data from the resource and global common configs.
	read_drbd_config_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	read_drbd_config_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	
	### Now push over the files I read in, if any.
	# Global common
	if ($conf->{node}{$node1}{drbd_file}{global_common})
	{
		$conf->{drbd}{global_common} = $conf->{node}{$node1}{drbd_file}{global_common};
	}
	elsif ($conf->{node}{$node2}{drbd_file}{global_common})
	{
		$conf->{drbd}{global_common} = $conf->{node}{$node2}{drbd_file}{global_common};
	}
	# r0.res
	if ($conf->{node}{$node1}{drbd_file}{r0})
	{
		$conf->{drbd}{r0} = $conf->{node}{$node1}{drbd_file}{r0};
	}
	elsif ($conf->{node}{$node2}{drbd_file}{r0})
	{
		$conf->{drbd}{r0} = $conf->{node}{$node2}{drbd_file}{r0};
	}
	# r1.res
	if ($conf->{node}{$node1}{drbd_file}{r1})
	{
		$conf->{drbd}{r1} = $conf->{node}{$node1}{drbd_file}{r1};
	}
	elsif ($conf->{node}{$node2}{drbd_file}{r1})
	{
		$conf->{drbd}{r1} = $conf->{node}{$node2}{drbd_file}{r1};
	}
	
	return (0);
}

# Unlike 'read_drbd_resource_files()' which only reads the 'rX.res' files and 
# parses their contents, this function just slurps in the data from the
# resource and global common configs.
sub read_drbd_config_on_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "read_drbd_config_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# DRBD ships with 'global_common.conf', so we need to tell if the one we read was stock or not. If it
	# was stock, delete it from the variable so that our generated one gets used.
	my $generic_global_common = 1;
	
	# These will contain the contents of the file.
	$conf->{node}{$node}{drbd_file}{global_common} = "";
	$conf->{node}{$node}{drbd_file}{r0}            = "";
	$conf->{node}{$node}{drbd_file}{r1}            = "";
	
	# And these tell us which file we're looking at.
	my $in_global = 0;
	my $in_r0     = 0;
	my $in_r1     = 0;
	
	# Some variables to use in the bash call...
	my $global_common = $conf->{path}{nodes}{drbd_global_common};
	my $r0            = $conf->{path}{nodes}{drbd_r0};
	my $r1            = $conf->{path}{nodes}{drbd_r1};
	my $shell_call = "
if [ -e '$global_common' ]; 
then 
    echo start:$global_common; 
    cat $global_common; 
    echo end:$global_common; 
else 
    echo not_found:$global_common; 
fi;
if [ -e '$r0' ]; 
then 
    echo start:$r0; 
    cat $r0; 
    echo end:$r0; 
else 
    echo not_found:$r0; 
fi;
if [ -e '$r1' ]; 
then 
    echo start:$r1; 
    cat $r1; 
    echo end:$r1; 
else 
    echo not_found:$r1; 
fi;";
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
			$conf->{node}{$node}{drbd_file}{global_common} .= "$line\n";
			my $test_line = $line;
			   $test_line =~ s/^\s+//;
			   $test_line =~ s/\s+$//;
			   $test_line =~ s/\s+/ /g;
			if (($test_line =~ /^fence-peer/) || ($test_line =~ /^allow-two-primaries/))
			{
				# These are not set by default, so we're _not_
				# looking at a stock config.
				$generic_global_common = 0;
			}
		}
		if ($in_r0) { $conf->{node}{$node}{drbd_file}{r0} .= "$line\n"; }
		if ($in_r1) { $conf->{node}{$node}{drbd_file}{r1} .= "$line\n"; }
	}
	
	# Wipe out the global_common if it's generic.
	$conf->{node}{$node}{drbd_file}{global_common} = "" if $generic_global_common;
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0004", message_variables => {
		name1 => "node",          value1 => $node,
		name2 => "global_common", value2 => $conf->{node}{$node}{drbd_file}{global_common}, 
		name3 => "r0",            value3 => $conf->{node}{$node}{drbd_file}{r0}, 
		name4 => "r1",            value4 => $conf->{node}{$node}{drbd_file}{r1},
	}, file => $THIS_FILE, line => __LINE__});
	
	return(0);
}

# This does the work of creating a metadata on each DRBD backing device. It checks first to see if there 
# already is a metadata and, if so, does nothing.
sub setup_drbd_on_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "setup_drbd_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### Write out the config files if missing.
	# Global common file
	if (not $conf->{node}{$node}{drbd_file}{global_common})
	{
		my $shell_call =  "cat > $conf->{path}{nodes}{drbd_global_common} << EOF\n";
		   $shell_call .= "$conf->{drbd}{global_common}\n";
		   $shell_call .= "EOF";
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
		}
	}
	
	# r0.res
	if (not $conf->{node}{$node}{drbd_file}{r0})
	{
		# Resource 0 config
		my $shell_call =  "cat > $conf->{path}{nodes}{drbd_r0} << EOF\n";
		   $shell_call .= "$conf->{drbd}{r0}\n";
		   $shell_call .= "EOF";
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
		}
	}
	
	# r1.res
	if ($conf->{cgi}{anvil_storage_pool2_byte_size})
	{
		if (not $conf->{node}{$node}{drbd_file}{r1})
		{
			# Resource 0 config
			my $shell_call =  "cat > $conf->{path}{nodes}{drbd_r1} << EOF\n";
			   $shell_call .= "$conf->{drbd}{r1}\n";
			   $shell_call .= "EOF";
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
			}
		}
	}
	
	### Now setup the meta-data, if needed. Start by reading 'blkid' to see
	### if the partitions already are drbd.
	# Check if the meta-data exists already
	$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
		name1 => "node",                           value1 => $node,
		name2 => "node::${node}::pool1_partition", value2 => $conf->{node}{$node}{pool1}{partition},
		name3 => "node::${node}::pool2_partition", value3 => $conf->{node}{$node}{pool2}{partition},
	}, file => $THIS_FILE, line => __LINE__});
	my ($pool1_rc) = check_for_drbd_metadata($conf, $node, $password, $conf->{node}{$node}{pool1}{device});
	my  $pool2_rc  = 7;
	if ($conf->{cgi}{anvil_storage_pool2_byte_size})
	{
		($pool2_rc) = check_for_drbd_metadata($conf, $node, $password, $conf->{node}{$node}{pool2}{device});
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
		name1 => "pool1_rc", value1 => $pool1_rc,
		name2 => "pool2_rc", value2 => $pool2_rc,
	}, file => $THIS_FILE, line => __LINE__});
	return($pool1_rc, $pool2_rc);
}

# This will register the nodes with RHN, if needed. Otherwise it just returns
# without doing anything.
sub register_with_rhn
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "register_with_rhn" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	if (not $conf->{sys}{install_manifest}{show}{rhn_checks})
	{
		# User has skipped RHN check
		$an->Log->entry({log_level => 2, message_key => "log_0179", file => $THIS_FILE, line => __LINE__});
		return(0);
	}
	
	$an->Log->entry({log_level => 4, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::rhn_user",     value1 => $conf->{cgi}{rhn_user},
		name2 => "cgi::rhn_password", value2 => $conf->{cgi}{rhn_password},
	}, file => $THIS_FILE, line => __LINE__});
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	# If I am going to register, I should warn the user of the delay.
	if ((($conf->{node}{$node1}{os}{brand} =~ /Red Hat Enterprise Linux Server/) && (not $conf->{node}{$node1}{os}{registered}) && ($conf->{node}{$node1}{internet})) ||
	    (($conf->{node}{$node2}{os}{brand} =~ /Red Hat Enterprise Linux Server/) && (not $conf->{node}{$node2}{os}{registered}) && ($conf->{node}{$node2}{internet})))
	{
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-be-patient-message", {
			message	=>	"#!string!explain_0138!#",
		});
	}
	
	# If it's not RHEL, no sense going further.
	if (($conf->{node}{$node1}{os}{brand} !~ /Red Hat Enterprise Linux Server/) && ($conf->{node}{$node2}{os}{brand} !~ /Red Hat Enterprise Linux Server/))
	{
		return(1);
	}
	
	# No credentials? No sense going further...
	if ((not $conf->{cgi}{rhn_user}) || (not $conf->{cgi}{rhn_password}))
	{
		# No sense going further
		if ((not $conf->{node}{$node1}{os}{registered}) || (not $conf->{node}{$node2}{os}{registered}))
		{
			print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
				row	=>	"#!string!row_0242!#",
				message	=>	"#!string!message_0385!#",
			});
			return(0);
		}
		return(1);
	}
	
	my $node1_ok = 1;
	my $node2_ok = 1;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node1}::os::brand", value1 => $conf->{node}{$node1}{os}{brand},
		name2 => "node::${node2}::os::brand", value2 => $conf->{node}{$node2}{os}{brand},
	}, file => $THIS_FILE, line => __LINE__});
	if ($conf->{node}{$node1}{os}{brand} =~ /Red Hat Enterprise Linux Server/)
	{
		# See if it's been registered already.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node1}::os::registered", value1 => $conf->{node}{$node1}{os}{registered},
			name2 => "node::${node1}::internet",       value2 => $conf->{node}{$node1}{internet},
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $conf->{node}{$node1}{os}{registered}) && ($conf->{node}{$node1}{internet}))
		{
			# We're good.
			($node1_ok) = register_node_with_rhn($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $conf->{cgi}{anvil_node1_name});
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
	if ($conf->{node}{$node2}{os}{brand} =~ /Red Hat Enterprise Linux Server/)
	{
		# See if it's been registered already.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node::${node2}::os::registered", value1 => $conf->{node}{$node2}{os}{registered},
			name2 => "node::${node2}::internet",       value2 => $conf->{node}{$node2}{internet},
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $conf->{node}{$node2}{os}{registered}) && ($conf->{node}{$node2}{internet}))
		{
			# We're good.
			($node2_ok) = register_node_with_rhn($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $conf->{cgi}{anvil_node2_name});
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
	if (not $node1_ok)
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0034!#";
		$ok            = 0;
	}
	if (not $node2_ok)
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0034!#";
		$ok            = 0;
	}

	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0234!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	if (not $ok)
	{
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
			message	=>	"#!string!message_0384!#",
			row	=>	"#!string!state_0021!#",
		});
	}
	
	return($ok);
}

# This does the actual registration
sub register_node_with_rhn
{
	my ($conf, $node, $password, $name) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "register_node_with_rhn" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node", value1 => $node, 
		name2 => "name", value2 => $name, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: This will fail when there isn't an internet connection! We
	###       check that, so write an rsync function to move the script
	###       under docroot and then wget from this machine.
	# First, make sure the script is downloaded and ready to run.
	my $base              = 0;
	my $resilient_storage = 0;
	my $optional          = 0;
	my $return_code =  0;
	my $shell_call  =  "rhnreg_ks --username \"$conf->{cgi}{rhn_user}\" --password \"$conf->{cgi}{rhn_password}\" --force --profilename \"$name\" && ";
	   $shell_call  .= "rhn-channel --add --user \"$conf->{cgi}{rhn_user}\" --password \"$conf->{cgi}{rhn_password}\" --channel=rhel-x86_64-server-rs-6 && ";
	   $shell_call  .= "rhn-channel --add --user \"$conf->{cgi}{rhn_user}\" --password \"$conf->{cgi}{rhn_password}\" --channel=rhel-x86_64-server-optional-6 && ";
	   $shell_call  .= "rhn-channel --list --user \"$conf->{cgi}{rhn_user}\" --password \"$conf->{cgi}{rhn_password}\"";
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
		
		if ($line =~ /rhel-x86_64-server-6/)
		{
			$base = 1;
		}
		if ($line =~ /rhel-x86_64-server-optional-6/)
		{
			$resilient_storage = 1;
		}
		if ($line =~ /rhel-x86_64-server-rs-6/)
		{
			$optional = 1;
		}
	}
	if ((not $base) || (not $resilient_storage) || ($optional))
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
			name1 => "Registration failed; node", value1 => $node,
			name2 => "base",                      value2 => $base,
			name3 => "resilient_storage",         value3 => $resilient_storage,
			name4 => "optional",                  value4 => $optional,
		}, file => $THIS_FILE, line => __LINE__});
		$return_code = 1;
	}
	
	return($return_code);
}

# This summarizes the install plan and gives the use a chance to tweak it or re-run the cable mapping.
sub summarize_build_plan
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "summarize_build_plan" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $node1                = $conf->{cgi}{anvil_node1_current_ip};
	my $node2                = $conf->{cgi}{anvil_node2_current_ip};
	my $say_node1_registered = "#!string!state_0047!#";
	my $say_node2_registered = "#!string!state_0047!#";
	my $say_node1_class      = "highlight_detail";
	my $say_node2_class      = "highlight_detail";
	my $enable_rhn           = 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "node::${node1}::os::brand", value1 => $conf->{node}{$node1}{os}{brand},
	}, file => $THIS_FILE, line => __LINE__});
	if ($conf->{node}{$node1}{os}{brand} =~ /Red Hat Enterprise Linux Server/)
	{
		# See if it's been registered already.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node1}::os::registered", value1 => $conf->{node}{$node1}{os}{registered},
		}, file => $THIS_FILE, line => __LINE__});
		if ($conf->{node}{$node1}{os}{registered})
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
				name1 => "node::${node1}::internet", value1 => $conf->{node}{$node1}{internet},
			}, file => $THIS_FILE, line => __LINE__});
			if (not $conf->{sys}{install_manifest}{show}{rhn_checks})
			{
				# User has disabled RHN checks/registration.
				$say_node1_registered = "#!string!state_0102!#";
				$enable_rhn           = 0;
			}
			elsif ($conf->{node}{$node1}{internet})
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
		name1 => "node::${node2}::os::brand", value1 => $conf->{node}{$node2}{os}{brand},
	}, file => $THIS_FILE, line => __LINE__});
	if ($conf->{node}{$node2}{os}{brand} =~ /Red Hat Enterprise Linux Server/)
	{
		# See if it's been registered already.
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node2}::os::registered", value1 => $conf->{node}{$node2}{os}{registered},
		}, file => $THIS_FILE, line => __LINE__});
		if ($conf->{node}{$node2}{os}{registered})
		{
			# Already registered.
			$say_node2_registered = "#!string!state_0105!#";
			$say_node2_class      = "highlight_good";
		}
		else
		{
			# Registration required, but do we have internet
			# access?
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "node::${node2}::internet", value1 => $conf->{node}{$node2}{internet},
			}, file => $THIS_FILE, line => __LINE__});
			if (not $conf->{sys}{install_manifest}{show}{rhn_checks})
			{
				# User has disabled RHN checks/registration.
				$say_node2_registered = "#!string!state_0102!#";
				$enable_rhn           = 0;
			}
			elsif ($conf->{node}{$node2}{internet})
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
	
	my $say_node1_os = $conf->{node}{$node1}{os}{brand} =~ /Red Hat Enterprise Linux Server/ ? "RHEL" : $conf->{node}{$node1}{os}{brand};
	my $say_node2_os = $conf->{node}{$node2}{os}{brand} =~ /Red Hat Enterprise Linux Server/ ? "RHEL" : $conf->{node}{$node2}{os}{brand};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "say_node1_os", value1 => $say_node1_os,
		name2 => "say_node2_os", value2 => $say_node2_os,
	}, file => $THIS_FILE, line => __LINE__});
	my $rhn_template = "";
	if ($enable_rhn)
	{
		$rhn_template = AN::Common::template($conf, "install-manifest.html", "rhn-credential-form", {
			rhn_user	=>	$conf->{cgi}{rhn_user},
			rhn_password	=>	$conf->{cgi}{rhn_password},
		});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node1", value1 => $node1,
		name2 => "node2", value2 => $node2,
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
		name1 => "node1",     value1 => $node1,
		name2 => "bcn_link1", value2 => $conf->{conf}{node}{$node1}{set_nic}{bcn_link1},
		name3 => "bcn_link2", value3 => $conf->{conf}{node}{$node1}{set_nic}{bcn_link2},
		name4 => "sn_link1",  value4 => $conf->{conf}{node}{$node1}{set_nic}{sn_link1},
		name5 => "sn_link2",  value5 => $conf->{conf}{node}{$node1}{set_nic}{sn_link2},
		name6 => "ifn_link1", value6 => $conf->{conf}{node}{$node1}{set_nic}{ifn_link1},
		name7 => "ifn_link2", value7 => $conf->{conf}{node}{$node1}{set_nic}{ifn_link2},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
		name1 => "node2",     value1 => $node2,
		name2 => "bcn_link1", value2 => $conf->{conf}{node}{$node2}{set_nic}{bcn_link1},
		name3 => "bcn_link2", value3 => $conf->{conf}{node}{$node2}{set_nic}{bcn_link2},
		name4 => "sn_link1",  value4 => $conf->{conf}{node}{$node2}{set_nic}{sn_link1},
		name5 => "sn_link2",  value5 => $conf->{conf}{node}{$node2}{set_nic}{sn_link2},
		name6 => "ifn_link1", value6 => $conf->{conf}{node}{$node2}{set_nic}{ifn_link1},
		name7 => "ifn_link2", value7 => $conf->{conf}{node}{$node2}{set_nic}{ifn_link2},
	}, file => $THIS_FILE, line => __LINE__});
	my $anvil_storage_partition_1_hr_size = AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_partition_2_byte_size});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::anvil_storage_partition_1_byte_size", value1 => $conf->{cgi}{anvil_storage_partition_1_byte_size},
		name2 => "anvil_storage_partition_1_hr_size",        value2 => $anvil_storage_partition_1_hr_size,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $conf->{cgi}{anvil_storage_partition_1_byte_size})
	{
		$conf->{cgi}{anvil_storage_partition_1_byte_size} = $conf->{cgi}{anvil_media_library_byte_size} + $conf->{cgi}{anvil_storage_pool1_byte_size};
	}
	if (not $conf->{cgi}{anvil_storage_partition_2_byte_size})
	{
		$conf->{cgi}{anvil_storage_partition_2_byte_size} = $conf->{cgi}{anvil_storage_pool2_byte_size};
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-summary-and-confirm", {
		form_file			=>	"/cgi-bin/striker",
		title				=>	"#!string!title_0177!#",
		bcn_link1_name			=>	AN::Common::get_string($conf, {key => "script_0059", variables => { number => "1" }}),
		bcn_link1_node1_mac		=>	$conf->{conf}{node}{$node1}{set_nic}{bcn_link1},
		bcn_link1_node2_mac		=>	$conf->{conf}{node}{$node2}{set_nic}{bcn_link1},
		bcn_link2_name			=>	AN::Common::get_string($conf, {key => "script_0059", variables => { number => "2" }}),
		bcn_link2_node1_mac		=>	$conf->{conf}{node}{$node1}{set_nic}{bcn_link2},
		bcn_link2_node2_mac		=>	$conf->{conf}{node}{$node2}{set_nic}{bcn_link2},
		sn_link1_name			=>	AN::Common::get_string($conf, {key => "script_0061", variables => { number => "1" }}),
		sn_link1_node1_mac		=>	$conf->{conf}{node}{$node1}{set_nic}{sn_link1},
		sn_link1_node2_mac		=>	$conf->{conf}{node}{$node2}{set_nic}{sn_link1},
		sn_link2_name			=>	AN::Common::get_string($conf, {key => "script_0061", variables => { number => "2" }}),
		sn_link2_node1_mac		=>	$conf->{conf}{node}{$node1}{set_nic}{sn_link2},
		sn_link2_node2_mac		=>	$conf->{conf}{node}{$node2}{set_nic}{sn_link2},
		ifn_link1_name			=>	AN::Common::get_string($conf, {key => "script_0063", variables => { number => "1" }}),
		ifn_link1_node1_mac		=>	$conf->{conf}{node}{$node1}{set_nic}{ifn_link1},
		ifn_link1_node2_mac		=>	$conf->{conf}{node}{$node2}{set_nic}{ifn_link1},
		ifn_link2_name			=>	AN::Common::get_string($conf, {key => "script_0063", variables => { number => "2" }}),
		ifn_link2_node1_mac		=>	$conf->{conf}{node}{$node1}{set_nic}{ifn_link2},
		ifn_link2_node2_mac		=>	$conf->{conf}{node}{$node2}{set_nic}{ifn_link2},
		media_library_size		=>	AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_media_library_byte_size}),
		pool1_size			=>	AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}),
		pool2_size			=>	AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}),
		partition1_size			=>	AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_partition_1_byte_size}),
		partition2_size			=>	AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_partition_2_byte_size}),
		edit_manifest_url		=>	"?config=true&task=create-install-manifest&load=$conf->{cgi}{run}",
		remap_network_url		=>	"$conf->{sys}{cgi_string}&remap_network=true",
		anvil_node1_current_ip		=>	$conf->{cgi}{anvil_node1_current_ip},
		anvil_node1_current_ip		=>	$conf->{cgi}{anvil_node1_current_ip},
		anvil_node1_current_password	=>	$conf->{cgi}{anvil_node1_current_password},
		anvil_node2_current_ip		=>	$conf->{cgi}{anvil_node2_current_ip},
		anvil_node2_current_password	=>	$conf->{cgi}{anvil_node2_current_password},
		config				=>	$conf->{cgi}{config},
		confirm				=>	$conf->{cgi}{confirm},
		'do'				=>	$conf->{cgi}{'do'},
		run				=>	$conf->{cgi}{run},
		task				=>	$conf->{cgi}{task},
		node1_os_name			=>	$say_node1_os,
		node2_os_name			=>	$say_node2_os,
		node1_os_registered		=>	$say_node1_registered,
		node1_os_registered_class	=>	$say_node1_class,
		node2_os_registered		=>	$say_node2_registered,
		node2_os_registered_class	=>	$say_node2_class,
		update_manifest			=>	$conf->{cgi}{update_manifest},
		rhn_template			=>	$rhn_template,
		striker_user			=>	$conf->{cgi}{striker_user},
		striker_database		=>	$conf->{cgi}{striker_database},
		anvil_striker1_user		=>	$conf->{cgi}{anvil_striker1_user},
		anvil_striker1_password		=>	$conf->{cgi}{anvil_striker1_password},
		anvil_striker1_database		=>	$conf->{cgi}{anvil_striker1_database},
		anvil_striker2_user		=>	$conf->{cgi}{anvil_striker2_user},
		anvil_striker2_password		=>	$conf->{cgi}{anvil_striker2_password},
		anvil_striker2_database		=>	$conf->{cgi}{anvil_striker2_database},
	});
	
	return(0);
}

# This reads in the /etc/ntp.conf file and adds custom NTP server if they aren't already there.
sub configure_ntp_on_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_ntp_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# We're going to do a grep for each defined NTP IP and, if the IP isn't
	# found, it will be added.
	my $return_code = 0;
	my @ntp_servers;
	push @ntp_servers, $conf->{cgi}{anvil_ntp1} if $conf->{cgi}{anvil_ntp1};
	push @ntp_servers, $conf->{cgi}{anvil_ntp2} if $conf->{cgi}{anvil_ntp2};
	foreach my $ntp_server (@ntp_servers)
	{
		# Look for/add NTP server
		my $shell_call = "
if \$(grep -q 'server $ntp_server iburst' $conf->{path}{nodes}{ntp_conf}); 
then 
    echo exists; 
else 
    echo adding $ntp_server;
    echo 'server $ntp_server iburst' >> $conf->{path}{nodes}{ntp_conf}
    if \$(grep -q 'server $ntp_server iburst' $conf->{path}{nodes}{ntp_conf});
    then
        echo added OK
    else
        echo failed to add!
    fi;
fi";
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

# This handles the actual configuration of the network files.
sub configure_network_on_node
{
	my ($conf, $node, $password, $node_number) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_network_on_node" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node",        value1 => $node, 
		name1 => "node_number", value1 => $node_number, 
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
		name1 => "cgi::anvil_mtu_size",                 value1 => $conf->{cgi}{anvil_mtu_size},
		name2 => "sys::install_manifest::default::mtu", value2 => $conf->{sys}{install_manifest}{'default'}{mtu},
	}, file => $THIS_FILE, line => __LINE__});
	my $mtu = $conf->{cgi}{anvil_mtu_size} ? $conf->{cgi}{anvil_mtu_size} : $conf->{sys}{install_manifest}{'default'}{mtu};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "mtu", value1 => $mtu,
	}, file => $THIS_FILE, line => __LINE__});
	   $mtu = "" if $mtu eq "1500"; 
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "mtu", value1 => $mtu,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Here we're going to write out all the network and udev configuration details per node.
	#$conf->{path}{nodes}{hostname};
	my $hostname =  "NETWORKING=yes\n";
	   $hostname .= "HOSTNAME=$conf->{cgi}{$name_key}";
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "bcn_link1_mac_key",       value1 => $bcn_link1_mac_key,
		name2 => "cgi::$bcn_link1_mac_key", value2 => $conf->{cgi}{$bcn_link1_mac_key},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "bcn_link2_mac_key",       value1 => $bcn_link2_mac_key,
		name2 => "cgi::$bcn_link2_mac_key", value2 => $conf->{cgi}{$bcn_link2_mac_key},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "sn_link1_mac_key",       value1 => $sn_link1_mac_key,
		name2 => "cgi::$sn_link1_mac_key", value2 => $conf->{cgi}{$sn_link1_mac_key},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "sn_link2_mac_key",       value1 => $sn_link2_mac_key,
		name2 => "cgi::$sn_link2_mac_key", value2 => $conf->{cgi}{$sn_link2_mac_key},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "ifn_link1_mac_key",       value1 => $ifn_link1_mac_key,
		name2 => "cgi::$ifn_link1_mac_key", value2 => $conf->{cgi}{$ifn_link1_mac_key},
	}, file => $THIS_FILE, line => __LINE__});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "ifn_link2_mac_key",       value1 => $ifn_link2_mac_key,
		name2 => "cgi::$ifn_link2_mac_key", value2 => $conf->{cgi}{$ifn_link2_mac_key},
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $conf->{cgi}{$bcn_link1_mac_key}) || 
	    (not $conf->{cgi}{$bcn_link2_mac_key}) || 
	    (not $conf->{cgi}{$sn_link2_mac_key}) || 
	    (not $conf->{cgi}{$sn_link2_mac_key}) || 
	    (not $conf->{cgi}{$ifn_link2_mac_key}) || 
	    (not $conf->{cgi}{$ifn_link2_mac_key}))
	{
		# Wtf?
		$return_code = 1;
		return($return_code);
	}
	
	# Make sure the values are actually MAC addresses
	if (($conf->{cgi}{$bcn_link1_mac_key} !~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i) || 
	    ($conf->{cgi}{$bcn_link2_mac_key} !~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i) || 
	    ($conf->{cgi}{$sn_link2_mac_key}  !~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i) || 
	    ($conf->{cgi}{$sn_link2_mac_key}  !~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i) || 
	    ($conf->{cgi}{$ifn_link2_mac_key} !~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i) || 
	    ($conf->{cgi}{$ifn_link2_mac_key} !~ /^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/i))
	{
		# >_<
		$return_code = 2;
		return($return_code);
	}
	
	#$conf->{path}{nodes}{udev_net_rules};
	my $udev_net_rules =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n\n";
	   $udev_net_rules .= "# Back-Channel Network, Link 1\n";
	   $udev_net_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$conf->{cgi}{$bcn_link1_mac_key}\", NAME=\"bcn_link1\"\n\n";
	   $udev_net_rules .= "# Back-Channel Network, Link 2\n";
	   $udev_net_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$conf->{cgi}{$bcn_link2_mac_key}\", NAME=\"bcn_link2\"\n\n";
	   $udev_net_rules .= "# Storage Network, Link 1\n";
	   $udev_net_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$conf->{cgi}{$sn_link1_mac_key}\", NAME=\"sn_link1\"\n\n";
	   $udev_net_rules .= "# Storage Network, Link 2\n";
	   $udev_net_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$conf->{cgi}{$sn_link2_mac_key}\", NAME=\"sn_link2\"\n\n";
	   $udev_net_rules .= "# Internet-Facing Network, Link 1\n";
	   $udev_net_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$conf->{cgi}{$ifn_link1_mac_key}\", NAME=\"ifn_link1\"\n\n";
	   $udev_net_rules .= "# Internet-Facing Network, Link 2\n";
	   $udev_net_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$conf->{cgi}{$ifn_link2_mac_key}\", NAME=\"ifn_link2\"\n";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "udev_net_rules", value1 => $udev_net_rules,
	}, file => $THIS_FILE, line => __LINE__});
	
	### Back-Channel Network
	#$conf->{path}{nodes}{bcn_link1_config};
	my $ifcfg_bcn_link1 =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n";
	   $ifcfg_bcn_link1 .= "# Back-Channel Network - Link 1\n";
	   $ifcfg_bcn_link1 .= "DEVICE=\"bcn_link1\"\n";
	   $ifcfg_bcn_link1 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_bcn_link1 .= "NM_CONTROLLED=\"no\"\n";
	   $ifcfg_bcn_link1 .= "BOOTPROTO=\"none\"\n";
	   $ifcfg_bcn_link1 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_bcn_link1 .= "SLAVE=\"yes\"\n";
	   $ifcfg_bcn_link1 .= "MASTER=\"bcn_bond1\"";
	if ($conf->{cgi}{anvil_bcn_ethtool_opts})
	{
		$ifcfg_bcn_link1 .= "\nETHTOOL_OPTS=\"$conf->{cgi}{anvil_bcn_ethtool_opts}\"";
	}
	
	#$conf->{path}{nodes}{bcn_link2_config};
	my $ifcfg_bcn_link2 =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n";
	   $ifcfg_bcn_link2 .= "# Back-Channel Network - Link 2\n";
	   $ifcfg_bcn_link2 .= "DEVICE=\"bcn_link2\"\n";
	   $ifcfg_bcn_link2 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_bcn_link2 .= "NM_CONTROLLED=\"no\"\n";
	   $ifcfg_bcn_link2 .= "BOOTPROTO=\"none\"\n";
	   $ifcfg_bcn_link2 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_bcn_link2 .= "SLAVE=\"yes\"\n";
	   $ifcfg_bcn_link2 .= "MASTER=\"bcn_bond1\"";
	if ($conf->{cgi}{anvil_bcn_ethtool_opts})
	{
		$ifcfg_bcn_link2 .= "\nETHTOOL_OPTS=\"$conf->{cgi}{anvil_bcn_ethtool_opts}\"";
	}
	
	#$conf->{path}{nodes}{bcn_bond1_config};
	my $ifcfg_bcn_bond1 =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n";
	   $ifcfg_bcn_bond1 .= "# Back-Channel Network - Bond 1\n";
	   $ifcfg_bcn_bond1 .= "DEVICE=\"bcn_bond1\"\n";
	   $ifcfg_bcn_bond1 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_bcn_bond1 .= "BOOTPROTO=\"static\"\n";
	   $ifcfg_bcn_bond1 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_bcn_bond1 .= "BONDING_OPTS=\"mode=1 miimon=100 use_carrier=1 updelay=120000 downdelay=0 primary=bcn_link1 primary_reselect=better\"\n";
	   $ifcfg_bcn_bond1 .= "IPADDR=\"$conf->{cgi}{$bcn_ip_key}\"\n";
	   $ifcfg_bcn_bond1 .= "NETMASK=\"$conf->{cgi}{anvil_bcn_subnet}\"\n";
	   $ifcfg_bcn_bond1 .= "DEFROUTE=\"no\"";
	
	### Storage Network
	#$conf->{path}{nodes}{sn_link1_config};
	my $ifcfg_sn_link1 =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n";
	   $ifcfg_sn_link1 .= "# Storage Network - Link 1\n";
	   $ifcfg_sn_link1 .= "DEVICE=\"sn_link1\"\n";
	   $ifcfg_sn_link1 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_sn_link1 .= "NM_CONTROLLED=\"no\"\n";
	   $ifcfg_sn_link1 .= "BOOTPROTO=\"none\"\n";
	   $ifcfg_sn_link1 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_sn_link1 .= "SLAVE=\"yes\"\n";
	   $ifcfg_sn_link1 .= "MASTER=\"sn_bond1\"";
	if ($conf->{cgi}{anvil_sn_ethtool_opts})
	{
		$ifcfg_sn_link1 .= "\nETHTOOL_OPTS=\"$conf->{cgi}{anvil_sn_ethtool_opts}\"";
	}
	
	#$conf->{path}{nodes}{sn_link2_config};
	my $ifcfg_sn_link2 =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n";
	   $ifcfg_sn_link2 .= "# Storage Network - Link 2\n";
	   $ifcfg_sn_link2 .= "DEVICE=\"sn_link2\"\n";
	   $ifcfg_sn_link2 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_sn_link2 .= "NM_CONTROLLED=\"no\"\n";
	   $ifcfg_sn_link2 .= "BOOTPROTO=\"none\"\n";
	   $ifcfg_sn_link2 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_sn_link2 .= "SLAVE=\"yes\"\n";
	   $ifcfg_sn_link2 .= "MASTER=\"sn_bond1\"";
	if ($conf->{cgi}{anvil_sn_ethtool_opts})
	{
		$ifcfg_sn_link2 .= "\nETHTOOL_OPTS=\"$conf->{cgi}{anvil_sn_ethtool_opts}\"";
	}
	
	#$conf->{path}{nodes}{sn_bond1_config};
	my $ifcfg_sn_bond1 =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n";
	   $ifcfg_sn_bond1 .= "# Storage Network - Bond 1\n";
	   $ifcfg_sn_bond1 .= "DEVICE=\"sn_bond1\"\n";
	   $ifcfg_sn_bond1 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_sn_bond1 .= "BOOTPROTO=\"static\"\n";
	   $ifcfg_sn_bond1 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_sn_bond1 .= "BONDING_OPTS=\"mode=1 miimon=100 use_carrier=1 updelay=120000 downdelay=0 primary=sn_link1 primary_reselect=better\"\n";
	   $ifcfg_sn_bond1 .= "IPADDR=\"$conf->{cgi}{$sn_ip_key}\"\n";
	   $ifcfg_sn_bond1 .= "NETMASK=\"$conf->{cgi}{anvil_sn_subnet}\"\n";
	   $ifcfg_sn_bond1 .= "DEFROUTE=\"no\"";
	
	### Internet-Facing Network
	#$conf->{path}{nodes}{ifn_link1_config};
	my $ifcfg_ifn_link1 =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n";
	   $ifcfg_ifn_link1 .= "# Internet-Facing Network - Link 1\n";
	   $ifcfg_ifn_link1 .= "DEVICE=\"ifn_link1\"\n";
	   $ifcfg_ifn_link1 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_ifn_link1 .= "NM_CONTROLLED=\"no\"\n";
	   $ifcfg_ifn_link1 .= "BOOTPROTO=\"none\"\n";
	   $ifcfg_ifn_link1 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_ifn_link1 .= "SLAVE=\"yes\"\n";
	   $ifcfg_ifn_link1 .= "MASTER=\"ifn_bond1\"";
	if ($conf->{cgi}{anvil_ifn_ethtool_opts})
	{
		$ifcfg_ifn_link1 .= "\nETHTOOL_OPTS=\"$conf->{cgi}{anvil_ifn_ethtool_opts}\"";
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ifcfg_ifn_link1", value1 => $ifcfg_ifn_link1,
	}, file => $THIS_FILE, line => __LINE__});
	
	#$conf->{path}{nodes}{ifn_link2_config};
	my $ifcfg_ifn_link2 =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n";
	   $ifcfg_ifn_link2 .= "# Internet-Facing Network - Link 2\n";
	   $ifcfg_ifn_link2 .= "DEVICE=\"ifn_link2\"\n";
	   $ifcfg_ifn_link2 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_ifn_link2 .= "NM_CONTROLLED=\"no\"\n";
	   $ifcfg_ifn_link2 .= "BOOTPROTO=\"none\"\n";
	   $ifcfg_ifn_link2 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_ifn_link2 .= "SLAVE=\"yes\"\n";
	   $ifcfg_ifn_link2 .= "MASTER=\"ifn_bond1\"";
	if ($conf->{cgi}{anvil_ifn_ethtool_opts})
	{
		$ifcfg_ifn_link2 .= "\nETHTOOL_OPTS=\"$conf->{cgi}{anvil_ifn_ethtool_opts}\"";
	}
	
	#$conf->{path}{nodes}{ifn_bond1_config};
	my $ifcfg_ifn_bond1 =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n";
	   $ifcfg_ifn_bond1 .= "# Internet-Facing Network - Bond 1\n";
	   $ifcfg_ifn_bond1 .= "DEVICE=\"ifn_bond1\"\n";
	   $ifcfg_ifn_bond1 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_ifn_bond1 .= "BRIDGE=\"ifn_bridge1\"\n";
	   $ifcfg_ifn_bond1 .= "BOOTPROTO=\"none\"\n";
	   $ifcfg_ifn_bond1 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_ifn_bond1 .= "BONDING_OPTS=\"mode=1 miimon=100 use_carrier=1 updelay=120000 downdelay=0 primary=ifn_link1 primary_reselect=better\"";
	
	#$conf->{path}{nodes}{ifn_bridge1_config};
	### NOTE: We don't set the MTU here because the bridge will ignore it. Bridges always take the MTU of
	###       the connected device with the lowest MTU.
	my $ifcfg_ifn_bridge1 =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n";
	   $ifcfg_ifn_bridge1 .= "# Internet-Facing Network - Bridge 1\n";
	   $ifcfg_ifn_bridge1 .= "DEVICE=\"ifn_bridge1\"\n";
	   $ifcfg_ifn_bridge1 .= "TYPE=\"Bridge\"\n";
	   $ifcfg_ifn_bridge1 .= "BOOTPROTO=\"static\"\n";
	   $ifcfg_ifn_bridge1 .= "IPADDR=\"$conf->{cgi}{$ifn_ip_key}\"\n";
	   $ifcfg_ifn_bridge1 .= "NETMASK=\"$conf->{cgi}{anvil_ifn_subnet}\"\n";
	   $ifcfg_ifn_bridge1 .= "GATEWAY=\"$conf->{cgi}{anvil_ifn_gateway}\"\n";
	   $ifcfg_ifn_bridge1 .= "DNS1=\"$conf->{cgi}{anvil_dns1}\"\n" if $conf->{cgi}{anvil_dns1};
	   $ifcfg_ifn_bridge1 .= "DNS2=\"$conf->{cgi}{anvil_dns2}\"\n" if $conf->{cgi}{anvil_dns2};
	   $ifcfg_ifn_bridge1 .= "DEFROUTE=\"yes\"";
	   
	# Create the 'anvil-adjust-vnet' udev rules file.
	#$conf->{path}{nodes}{udev_vnet_rules};
	my $udev_vnet_rules =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n\n";
	   $udev_vnet_rules .= "# This calls '$conf->{path}{nodes}{'anvil-adjust-vnet'}' when a network devices are created.\n";
	   $udev_vnet_rules .= "\n";
	   $udev_vnet_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", RUN+=\"$conf->{path}{nodes}{'anvil-adjust-vnet'}\"\n";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "udev_vnet_rules", value1 => $udev_vnet_rules,
	}, file => $THIS_FILE, line => __LINE__});
	
	### NOTE: If this changes, be sure to update the expected number of lines needed to determine if a 
	###       reboot is needed! (search for '$lines < 13', about 500 lines down from here)
	# Setup the fireall now. (Temporarily; the new multiport based and old state based versions are here.
	# The old one will be removed once this one is confirmed to be good.)
	my $iptables  = "";
	my $vnc_range = 5900 + $conf->{cgi}{anvil_open_vnc_ports};
	$iptables .= "
# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]

# Allow SSH on all nets
-A INPUT -p tcp -m conntrack --ctstate NEW -m tcp --dport 22 -j ACCEPT

# Allow sctp on the BCN and SN
-A INPUT -s $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -p sctp -j ACCEPT
-A INPUT -s $conf->{cgi}{anvil_sn_network}/$conf->{cgi}{anvil_sn_subnet} -p sctp -j ACCEPT

# Allow UDP-multicast based clusters on the BCN and SN
-I INPUT -m addrtype --dst-type MULTICAST -m conntrack --ctstate NEW -m multiport -p udp -s $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} --dports 5404,5405 -j ACCEPT
-I INPUT -m addrtype --dst-type MULTICAST -m conntrack --ctstate NEW -m multiport -p udp -s $conf->{cgi}{anvil_sn_network}/$conf->{cgi}{anvil_sn_subnet} --dports 5404,5405 -j ACCEPT

# Allow UDP-unicast based clusters on the BCN and SN
-A INPUT -m conntrack --ctstate NEW -m multiport -p udp -s $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -d $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} --dports 5404,5405 -j ACCEPT
-A INPUT -m conntrack --ctstate NEW -m multiport -p udp -s $conf->{cgi}{anvil_sn_network}/$conf->{cgi}{anvil_sn_subnet} -d $conf->{cgi}{anvil_sn_network}/$conf->{cgi}{anvil_sn_subnet} --dports 5404,5405 -j ACCEPT

# Allow NTP, VNC, ricci, modclusterd, dlm and KVM live migration on the BCN
-A INPUT -m conntrack --ctstate NEW -m multiport -p tcp -s $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -d $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} --dports 123,5800,5900:$vnc_range,11111,16851,21064,49152:49216 -j ACCEPT 

# Allow DRBD (11 resources) and, as backups, ricci, modclusterd and DLM on the SN
-A INPUT -m conntrack --ctstate NEW -m multiport -p tcp -s $conf->{cgi}{anvil_sn_network}/$conf->{cgi}{anvil_sn_subnet} -d $conf->{cgi}{anvil_sn_network}/$conf->{cgi}{anvil_sn_subnet} --dports 7788:7799,11111,16851,21064 -j ACCEPT 

# Allow NTP and VNC on the IFN
-A INPUT -m conntrack --ctstate NEW -m multiport -p tcp -s $conf->{cgi}{anvil_ifn_network}/$conf->{cgi}{anvil_ifn_subnet} -d $conf->{cgi}{anvil_ifn_network}/$conf->{cgi}{anvil_ifn_subnet} --dports 123,5800,5900:$vnc_range -j ACCEPT 

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
	
	### TODO: When replacing a node, read in the peer's hosts file and
	###       use that instead of the install manifest contents
	### Generate the hosts file
	# Break up hostsnames
	my ($node1_short_name)    = ($conf->{cgi}{anvil_node1_name}    =~ /^(.*?)\./);
	my ($node2_short_name)    = ($conf->{cgi}{anvil_node2_name}    =~ /^(.*?)\./);
	my ($switch1_short_name)  = ($conf->{cgi}{anvil_switch1_name}  =~ /^(.*?)\./);
	my ($switch2_short_name)  = ($conf->{cgi}{anvil_switch2_name}  =~ /^(.*?)\./);
	my ($pdu1_short_name)     = ($conf->{cgi}{anvil_pdu1_name}     =~ /^(.*?)\./);
	my ($pdu2_short_name)     = ($conf->{cgi}{anvil_pdu2_name}     =~ /^(.*?)\./);
	my ($pdu3_short_name)     = ($conf->{cgi}{anvil_pdu3_name}     =~ /^(.*?)\./);
	my ($pdu4_short_name)     = ($conf->{cgi}{anvil_pdu4_name}     =~ /^(.*?)\./);
	my ($pts1_short_name)     = ($conf->{cgi}{anvil_pts1_name}     =~ /^(.*?)\./);
	my ($pts2_short_name)     = ($conf->{cgi}{anvil_pts2_name}     =~ /^(.*?)\./);
	my ($ups1_short_name)     = ($conf->{cgi}{anvil_ups1_name}     =~ /^(.*?)\./);
	my ($ups2_short_name)     = ($conf->{cgi}{anvil_ups2_name}     =~ /^(.*?)\./);
	my ($striker1_short_name) = ($conf->{cgi}{anvil_striker1_name} =~ /^(.*?)\./);
	my ($striker2_short_name) = ($conf->{cgi}{anvil_striker2_name} =~ /^(.*?)\./);
	
	# now generate the hosts body.
	my $hosts =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."]\n";
	   $hosts .= "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4\n";
	   $hosts .= "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6\n";
	   $hosts .= "\n";
	   $hosts .= "# Anvil! $conf->{cgi}{anvil_sequence}, Node 01\n";
	   $hosts .= "$conf->{cgi}{anvil_node1_bcn_ip}	$node1_short_name.bcn $node1_short_name $conf->{cgi}{anvil_node1_name}\n";
	   $hosts .= "$conf->{cgi}{anvil_node1_ipmi_ip}	$node1_short_name.ipmi\n";
	   $hosts .= "$conf->{cgi}{anvil_node1_sn_ip}	$node1_short_name.sn\n";
	   $hosts .= "$conf->{cgi}{anvil_node1_ifn_ip}	$node1_short_name.ifn\n";
	   $hosts .= "\n";
	   $hosts .= "# Anvil! $conf->{cgi}{anvil_sequence}, Node 02\n";
	   $hosts .= "$conf->{cgi}{anvil_node2_bcn_ip}	$node2_short_name.bcn $node2_short_name $conf->{cgi}{anvil_node2_name}\n";
	   $hosts .= "$conf->{cgi}{anvil_node2_ipmi_ip}	$node2_short_name.ipmi\n";
	   $hosts .= "$conf->{cgi}{anvil_node2_sn_ip}	$node2_short_name.sn\n";
	   $hosts .= "$conf->{cgi}{anvil_node2_ifn_ip}	$node2_short_name.ifn\n";
	   $hosts .= "\n";
	   $hosts .= "# Network switches\n";
	   $hosts .= "$conf->{cgi}{anvil_switch1_ip}	$switch1_short_name $conf->{cgi}{anvil_switch1_name}\n";
	   $hosts .= "$conf->{cgi}{anvil_switch2_ip}	$switch2_short_name $conf->{cgi}{anvil_switch2_name}\n";
	   $hosts .= "\n";
	   $hosts .= "# Switched PDUs\n";
	   $hosts .= "$conf->{cgi}{anvil_pdu1_ip}	$pdu1_short_name $conf->{cgi}{anvil_pdu1_name}\n";
	   $hosts .= "$conf->{cgi}{anvil_pdu2_ip}	$pdu2_short_name $conf->{cgi}{anvil_pdu2_name}\n";
	   $hosts .= "$conf->{cgi}{anvil_pdu3_ip}	$pdu3_short_name $conf->{cgi}{anvil_pdu3_name}\n" if $conf->{cgi}{anvil_pdu3_ip};
	   $hosts .= "$conf->{cgi}{anvil_pdu4_ip}	$pdu4_short_name $conf->{cgi}{anvil_pdu4_name}\n" if $conf->{cgi}{anvil_pdu4_ip};
	   $hosts .= "\n";
	   $hosts .= "# UPSes\n";
	   $hosts .= "$conf->{cgi}{anvil_ups1_ip}	$ups1_short_name $conf->{cgi}{anvil_ups1_name}\n";
	   $hosts .= "$conf->{cgi}{anvil_ups2_ip}	$ups2_short_name $conf->{cgi}{anvil_ups2_name}\n";
	   $hosts .= "\n";
	   $hosts .= "# PTSes\n";
	   $hosts .= "$conf->{cgi}{anvil_pts1_ip}	$pts1_short_name $conf->{cgi}{anvil_pts1_name}\n";
	   $hosts .= "$conf->{cgi}{anvil_pts2_ip}	$pts2_short_name $conf->{cgi}{anvil_pts2_name}\n";
	   $hosts .= "\n";
	   $hosts .= "# Striker dashboards\n";
	   $hosts .= "$conf->{cgi}{anvil_striker1_bcn_ip}	$striker1_short_name.bcn $striker1_short_name $conf->{cgi}{anvil_striker1_name}\n";
	   $hosts .= "$conf->{cgi}{anvil_striker1_ifn_ip}	$striker1_short_name.ifn\n";
	   $hosts .= "$conf->{cgi}{anvil_striker2_bcn_ip}	$striker2_short_name.bcn $striker2_short_name $conf->{cgi}{anvil_striker2_name}\n";
	   $hosts .= "$conf->{cgi}{anvil_striker2_ifn_ip}	$striker2_short_name.ifn\n";
	   $hosts .= "\n";
	
	# This will be used later when populating ~/.ssh/known_hosts
	$conf->{sys}{node_names} = [
		"$conf->{cgi}{anvil_node1_name}", 
		"$node1_short_name", 
		"$node1_short_name.bcn", 
		"$node1_short_name.sn", 
		"$node1_short_name.ifn", 
		"$conf->{cgi}{anvil_node2_name}", 
		"$node2_short_name", 
		"$node2_short_name.bcn", 
		"$node2_short_name.sn", 
		"$node2_short_name.ifn"];
	
	### If we bail out between here and the end of this function, the user
	### may lose access to their machines, so BE CAREFUL! :D
	# Delete any existing ifcfg-eth* files
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "Deleting any existing ifcfg-eth* files on", value1 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	
	### TODO: Make this smarter so that it deletes everything ***EXCEPT*** ifcfg-lo
	my $shell_call = "rm -f $conf->{path}{nodes}{ifcfg_directory}/ifcfg-eth*";
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
	}
	
	### Start writing!
	### Internet-Facing Network
	# IFN Bridge 1
	$shell_call =  "cat > $conf->{path}{nodes}{ifn_bridge1_config} << EOF\n";
	$shell_call .= "$ifcfg_ifn_bridge1\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	# IFN Bond 1
	$shell_call =  "cat > $conf->{path}{nodes}{ifn_bond1_config} << EOF\n";
	$shell_call .= "$ifcfg_ifn_bond1\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	# IFN Link 1
	$shell_call =  "cat > $conf->{path}{nodes}{ifn_link1_config} << EOF\n";
	$shell_call .= "$ifcfg_ifn_link1\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	# IFN Link 2
	$shell_call =  "cat > $conf->{path}{nodes}{ifn_link2_config} << EOF\n";
	$shell_call .= "$ifcfg_ifn_link2\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	### Storage Network
	# SN Bond 1
	$shell_call =  "cat > $conf->{path}{nodes}{sn_bond1_config} << EOF\n";
	$shell_call .= "$ifcfg_sn_bond1\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	# SN Link 1
	$shell_call =  "cat > $conf->{path}{nodes}{sn_link1_config} << EOF\n";
	$shell_call .= "$ifcfg_sn_link1\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	# SN Link 2
	$shell_call =  "cat > $conf->{path}{nodes}{sn_link2_config} << EOF\n";
	$shell_call .= "$ifcfg_sn_link2\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	### Back-Channel Network
	# BCN Bond 1
	$shell_call =  "cat > $conf->{path}{nodes}{bcn_bond1_config} << EOF\n";
	$shell_call .= "$ifcfg_bcn_bond1\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	# BCN Link 1
	$shell_call =  "cat > $conf->{path}{nodes}{bcn_link1_config} << EOF\n";
	$shell_call .= "$ifcfg_bcn_link1\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	# BCN Link 2
	$shell_call =  "cat > $conf->{path}{nodes}{bcn_link2_config} << EOF\n";
	$shell_call .= "$ifcfg_bcn_link2\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	### Now write the net udev rules file.
	$shell_call = "cat > $conf->{path}{nodes}{udev_net_rules} << EOF\n";
	$shell_call .= "$udev_net_rules\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	### Now write the vnet udev rules file.
	$shell_call = "cat > $conf->{path}{nodes}{udev_vnet_rules} << EOF\n";
	$shell_call .= "$udev_vnet_rules\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	# Hosts file.
	$shell_call =  "cat > $conf->{path}{nodes}{hosts} << EOF\n";
	$shell_call .= "$hosts\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	### Now write the hostname file and set the hostname for the current session.
	$shell_call =  "cat > $conf->{path}{nodes}{hostname} << EOF\n";
	$shell_call .= "$hostname\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	$shell_call = "hostname $conf->{cgi}{$name_key}";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	### And finally, iptables. 
	### NOTE: DON'T restart iptables! It could break the connection as the rules are for the new network
	###       config, which may differ from the active one.
	# First, get a word count on the current iptables in-memory config. If it's smaller than 13 lines,
	# it's probably the original one and we'll need a reboot.
	$shell_call = "echo \"lines:\$(iptables-save | wc -l)\"\n";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
		
		if ($line =~ /^lines:(\d+)$/)
		{
			my $lines = $1;
			if ($lines < 13)
			{
				# Reboot needed
				$an->Log->entry({log_level => 1, message_key => "log_0180", message_variables => {
					node  => $node, 
					lines => $lines, 
				}, file => $THIS_FILE, line => __LINE__});
				$conf->{node}{$node}{reboot_needed} = 1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node}::reboot_needed", value1 => $conf->{node}{$node}{reboot_needed},
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
	$shell_call =  "cat > $conf->{path}{nodes}{iptables} << EOF\n";
	$shell_call .= "$iptables\n";
	$shell_call .= "EOF";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
	}
	
	### TODO: Add sanity checks.
	# If there is not an ifn_bridge1, assume we need to reboot.
	my $bridge_found = 0;
	   $shell_call   = "brctl show";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
		
		if ($line =~ /ifn_bridge1/)
		{
			$bridge_found = 1;
		}
	}
	if (not $bridge_found)
	{
		# Reboot needed.
		$conf->{node}{$node}{reboot_needed} = 1;
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
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_ntp" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ok = 1;
	# Only proceed if at least one NTP server is defined.
	if (($conf->{cgi}{anvil_ntp1}) || ($conf->{cgi}{anvil_ntp2}))
	{
		my ($node1_ok) = configure_ntp_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
		my ($node2_ok) = configure_ntp_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
		# 0 = NTP server(s) already defined.
		# 1 = Added OK
		# 2 = problem adding NTP server
		
		# Default was "already added"
		my $node1_class   = "highlight_good_bold";
		my $node1_message = "#!string!state_0028!#";
		my $node2_class   = "highlight_good_bold";
		my $node2_message = "#!string!state_0028!#";
		my $message       = "";
		if ($node1_ok eq "1")
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
		if ($node2_ok eq "1")
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
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
			row		=>	"#!string!row_0275!#",
			node1_class	=>	$node1_class,
			node1_message	=>	$node1_message,
			node2_class	=>	$node2_class,
			node2_message	=>	$node2_message,
		});
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This configures the network.
sub configure_network
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_network" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# The 'ethtool' options can include variables, so we'll need to escape '$' if found.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_ifn_ethtool_opts", value1 => $conf->{cgi}{anvil_ifn_ethtool_opts},
	}, file => $THIS_FILE, line => __LINE__});
	$conf->{cgi}{anvil_bcn_ethtool_opts} =~ s/\$/\\\$/g;
	$conf->{cgi}{anvil_sn_ethtool_opts}  =~ s/\$/\\\$/g;
	$conf->{cgi}{anvil_ifn_ethtool_opts} =~ s/\$/\\\$/g;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "cgi::anvil_ifn_ethtool_opts", value1 => $conf->{cgi}{anvil_ifn_ethtool_opts},
	}, file => $THIS_FILE, line => __LINE__});
	
	my ($node1_ok) = configure_network_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, 1, "#!string!device_0005!#");
	my ($node2_ok) = configure_network_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, 2, "#!string!device_0006!#");
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
	if ($node1_ok eq "1")
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
	if ($node1_ok eq "1")
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
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0228!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	return($ok);
}

# This parses a line coming back from one of our shell scripts to convert string keys and possible variables
# into the current user's language.
sub parse_script_line
{
	my ($conf, $source, $node, $line) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "parse_script_line" }, message_key => "an_variables_0003", message_variables => { 
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
		$conf->{node}{$node}{reboot_needed} = $reboot eq "reboot" ? 1 : 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "node::${node}::reboot_needed", value1 => $conf->{node}{$node}{reboot_needed},
		}, file => $THIS_FILE, line => __LINE__});
		return("<br />\n");
	}
	elsif ($line =~ /#!string!(.*?)!#$/)
	{
		# Simple string
		my $key  = $1;
		   $line = AN::Common::get_string($conf, {key => "$key"});
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
		$line = AN::Common::get_string($conf, {key => "$key", variables => $vars});
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "line", value1 => $line,
	}, file => $THIS_FILE, line => __LINE__});
	#$line .= "<br />\n";
	
	return($line);
}

# This asks the user to unplug and then plug back in all network interfaces in
# order to map the physical interfaces to MAC addresses.
sub map_network
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "map_network" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my ($node1_rc) = map_network_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, 0, "#!string!device_0005!#");
	my ($node2_rc) = map_network_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, 0, "#!string!device_0006!#");
	
	# Loop through the MACs seen and see if we've got a match for all
	# already. If any are missing, we'll need to remap.
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	
	# These will be all populated *if*;
	# * The MACs seen on each node match MACs passed in from CGI (or 
	# * Loaded from manifest
	# * If the existing network appears complete already.
	# If any are missing, a remap will be needed.
	# Node 1
	$conf->{conf}{node}{$node1}{set_nic}{bcn_link1} = "";
	$conf->{conf}{node}{$node1}{set_nic}{bcn_link2} = "";
	$conf->{conf}{node}{$node1}{set_nic}{sn_link1}  = "";
	$conf->{conf}{node}{$node1}{set_nic}{sn_link2}  = "";
	$conf->{conf}{node}{$node1}{set_nic}{ifn_link1} = "";
	$conf->{conf}{node}{$node1}{set_nic}{ifn_link2} = "";
	# Node 2
	$conf->{conf}{node}{$node2}{set_nic}{bcn_link1} = "";
	$conf->{conf}{node}{$node2}{set_nic}{bcn_link2} = "";
	$conf->{conf}{node}{$node2}{set_nic}{sn_link1}  = "";
	$conf->{conf}{node}{$node2}{set_nic}{sn_link2}  = "";
	$conf->{conf}{node}{$node2}{set_nic}{ifn_link1} = "";
	$conf->{conf}{node}{$node2}{set_nic}{ifn_link2} = "";
	foreach my $nic (sort {$a cmp $b} keys %{$conf->{conf}{node}{$node1}{current_nic}})
	{
		my $mac = $conf->{conf}{node}{$node1}{current_nic}{$nic};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "node", value1 => $node1,
			name2 => "nic",  value2 => $nic,
			name3 => "mac",  value3 => $mac,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_node1_bcn_link1_mac", value1 => $conf->{cgi}{anvil_node1_bcn_link1_mac},
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_node1_bcn_link2_mac", value1 => $conf->{cgi}{anvil_node1_bcn_link2_mac},
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_node1_sn_link1_mac", value1 => $conf->{cgi}{anvil_node1_sn_link1_mac},
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_node1_sn_link2_mac", value1 => $conf->{cgi}{anvil_node1_sn_link2_mac},
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_node1_ifn_link1_mac", value1 => $conf->{cgi}{anvil_node1_ifn_link1_mac},
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_node1_ifn_link2_mac", value1 => $conf->{cgi}{anvil_node1_ifn_link2_mac},
		}, file => $THIS_FILE, line => __LINE__});
		if ($mac eq $conf->{cgi}{anvil_node1_bcn_link1_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{bcn_link1} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::bcn_link1", value1 => $conf->{conf}{node}{$node1}{set_nic}{bcn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $conf->{cgi}{anvil_node1_bcn_link2_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{bcn_link2} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::bcn_link2", value1 => $conf->{conf}{node}{$node1}{set_nic}{bcn_link2},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $conf->{cgi}{anvil_node1_sn_link1_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{sn_link1} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::sn_link1", value1 => $conf->{conf}{node}{$node1}{set_nic}{sn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $conf->{cgi}{anvil_node1_sn_link2_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{sn_link2} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::sn_link2", value1 => $conf->{conf}{node}{$node1}{set_nic}{sn_link2},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $conf->{cgi}{anvil_node1_ifn_link1_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{ifn_link1} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::ifn_link1", value1 => $conf->{conf}{node}{$node1}{set_nic}{ifn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $conf->{cgi}{anvil_node1_ifn_link2_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{ifn_link2} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node1}::set_nic::ifn_link2", value1 => $conf->{conf}{node}{$node1}{set_nic}{ifn_link2},
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
			$conf->{conf}{node}{$node1}{unknown_nic}{$nic} = $mac;
		}
	}
	foreach my $nic (sort {$a cmp $b} keys %{$conf->{conf}{node}{$node2}{current_nic}})
	{
		my $mac = $conf->{conf}{node}{$node2}{current_nic}{$nic};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
			name1 => "node", value1 => $node2,
			name2 => "nic",  value2 => $nic,
			name3 => "mac",  value3 => $mac,
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_node2_bcn_link1_mac", value1 => $conf->{cgi}{anvil_node2_bcn_link1_mac},
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_node2_bcn_link2_mac", value1 => $conf->{cgi}{anvil_node2_bcn_link2_mac},
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_node2_sn_link1_mac", value1 => $conf->{cgi}{anvil_node2_sn_link1_mac},
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_node2_sn_link2_mac", value1 => $conf->{cgi}{anvil_node2_sn_link2_mac},
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_node2_ifn_link1_mac", value1 => $conf->{cgi}{anvil_node2_ifn_link1_mac},
		}, file => $THIS_FILE, line => __LINE__});
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_node2_ifn_link2_mac", value1 => $conf->{cgi}{anvil_node2_ifn_link2_mac},
		}, file => $THIS_FILE, line => __LINE__});
		if ($mac eq $conf->{cgi}{anvil_node2_bcn_link1_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{bcn_link1} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::bcn_link1", value1 => $conf->{conf}{node}{$node2}{set_nic}{bcn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $conf->{cgi}{anvil_node2_bcn_link2_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{bcn_link2} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::bcn_link2", value1 => $conf->{conf}{node}{$node2}{set_nic}{bcn_link2},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $conf->{cgi}{anvil_node2_sn_link1_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{sn_link1} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::sn_link1", value1 => $conf->{conf}{node}{$node2}{set_nic}{sn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $conf->{cgi}{anvil_node2_sn_link2_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{sn_link2} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::sn_link2", value1 => $conf->{conf}{node}{$node2}{set_nic}{sn_link2},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $conf->{cgi}{anvil_node2_ifn_link1_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{ifn_link1} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::ifn_link1", value1 => $conf->{conf}{node}{$node2}{set_nic}{ifn_link1},
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($mac eq $conf->{cgi}{anvil_node2_ifn_link2_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{ifn_link2} = $mac;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node2}::set_nic::ifn_link2", value1 => $conf->{conf}{node}{$node2}{set_nic}{ifn_link2},
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
			$conf->{conf}{node}{$node2}{unknown_nic}{$nic} = $mac;
		}
	}
	
	# Now determine if a remap is needed. If ifn_bridge1 exists, assume
	# it's configured and skip.
	my $node1_remap_needed = 0;
	my $node2_remap_needed = 0;
	
	### TODO: Check *all* devices, not just ifn_bridge1
	# Check node1
	if ((exists $conf->{conf}{node}{$node1}{current_nic}{ifn_bridge1}) && (exists $conf->{conf}{node}{$node1}{current_nic}{ifn_bridge1}))
	{
		# Remap not needed, system already configured.
		$an->Log->entry({log_level => 2, message_key => "log_0184", file => $THIS_FILE, line => __LINE__});
		
		# To make the summary look better, we'll take the NICs we
		# thought we didn't recognize and feed them into 'set_nic'.
		foreach my $node (sort {$a cmp $b} keys %{$conf->{conf}{node}})
		{
			$an->Log->entry({log_level => 2, message_key => "log_0185", message_variables => {
				node => $node, 
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $nic (sort {$a cmp $b} keys %{$conf->{conf}{node}{$node}{unknown_nic}})
			{
				my $mac = $conf->{conf}{node}{$node}{unknown_nic}{$nic};
				$conf->{conf}{node}{$node}{set_nic}{$nic} = $mac;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "Node", value1 => $node,
					name2 => "nic",  value2 => $nic,
					name3 => "mac",  value3 => $conf->{conf}{node}{$node}{set_nic}{$nic},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	else
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
			name1 => "node",      value1 => $node1,
			name2 => "bcn_link1", value2 => $conf->{conf}{node}{$node1}{set_nic}{bcn_link1},
			name3 => "bcn_link2", value3 => $conf->{conf}{node}{$node1}{set_nic}{bcn_link2},
			name4 => "sn_link1",  value4 => $conf->{conf}{node}{$node1}{set_nic}{sn_link1},
			name5 => "sn_link2",  value5 => $conf->{conf}{node}{$node1}{set_nic}{sn_link2},
			name6 => "ifn_link1", value6 => $conf->{conf}{node}{$node1}{set_nic}{ifn_link1},
			name7 => "ifn_link2", value7 => $conf->{conf}{node}{$node1}{set_nic}{ifn_link2},
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $conf->{conf}{node}{$node1}{set_nic}{bcn_link1}) || 
		    (not $conf->{conf}{node}{$node1}{set_nic}{bcn_link2}) ||
		    (not $conf->{conf}{node}{$node1}{set_nic}{sn_link1})  ||
		    (not $conf->{conf}{node}{$node1}{set_nic}{sn_link2})  ||
		    (not $conf->{conf}{node}{$node1}{set_nic}{ifn_link1}) ||
		    (not $conf->{conf}{node}{$node1}{set_nic}{ifn_link2}))
		{
			$node1_remap_needed = 1;
		}
	}
	# Check node 2
	if ((exists $conf->{conf}{node}{$node2}{current_nic}{ifn_bridge1}) && (exists $conf->{conf}{node}{$node2}{current_nic}{ifn_bridge1}))
	{
		# Remap not needed, system already configured.
		$an->Log->entry({log_level => 2, message_key => "log_0184", file => $THIS_FILE, line => __LINE__});
		
		# To make the summary look better, we'll take the NICs we
		# thought we didn't recognize and feed them into 'set_nic'.
		foreach my $node (sort {$a cmp $b} keys %{$conf->{conf}{node}})
		{
			$an->Log->entry({log_level => 2, message_key => "log_0185", message_variables => {
				node => $node, 
			}, file => $THIS_FILE, line => __LINE__});
			foreach my $nic (sort {$a cmp $b} keys %{$conf->{conf}{node}{$node}{unknown_nic}})
			{
				my $mac = $conf->{conf}{node}{$node}{unknown_nic}{$nic};
				$conf->{conf}{node}{$node}{set_nic}{$nic} = $mac;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
					name1 => "Node", value1 => $node,
					name2 => "nic",  value2 => $nic,
					name3 => "mac",  value3 => $conf->{conf}{node}{$node}{set_nic}{$nic},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	else
	{
		$an->Log->entry({log_level => 2, message_key => "an_variables_0007", message_variables => {
			name1 => "node",      value1 => $node2,
			name2 => "bcn_link1", value2 => $conf->{conf}{node}{$node2}{set_nic}{bcn_link1},
			name3 => "bcn_link2", value3 => $conf->{conf}{node}{$node2}{set_nic}{bcn_link2},
			name4 => "sn_link1",  value4 => $conf->{conf}{node}{$node2}{set_nic}{sn_link1},
			name5 => "sn_link2",  value5 => $conf->{conf}{node}{$node2}{set_nic}{sn_link2},
			name6 => "ifn_link1", value6 => $conf->{conf}{node}{$node2}{set_nic}{ifn_link1},
			name7 => "ifn_link2", value7 => $conf->{conf}{node}{$node2}{set_nic}{ifn_link2},
		}, file => $THIS_FILE, line => __LINE__});
		if ((not $conf->{conf}{node}{$node2}{set_nic}{bcn_link1}) || 
		    (not $conf->{conf}{node}{$node2}{set_nic}{bcn_link2}) ||
		    (not $conf->{conf}{node}{$node2}{set_nic}{sn_link1})  ||
		    (not $conf->{conf}{node}{$node2}{set_nic}{sn_link2})  ||
		    (not $conf->{conf}{node}{$node2}{set_nic}{ifn_link1}) ||
		    (not $conf->{conf}{node}{$node2}{set_nic}{ifn_link2}))
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
		name1 => "cgi::remap_network", value1 => $conf->{cgi}{remap_network},
	}, file => $THIS_FILE, line => __LINE__});
	if ($conf->{cgi}{remap_network})
	{
		$node1_class        = "highlight_note_bold";
		$node1_message      = "#!string!state_0032!#",
		$node2_class        = "highlight_note_bold";
		$node2_message      = "#!string!state_0032!#",
		$node1_remap_needed = 1;
		$node2_remap_needed = 1;
	}

	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0229!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	return($node1_remap_needed, $node2_remap_needed);
}

# This downloads and runs the 'anvil-map-network' script
sub map_network_on_node
{
	my ($conf, $node, $password, $remap, $say_node) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "map_network_on_node" }, message_key => "an_variables_0003", message_variables => { 
		name1 => "node",     value1 => $node, 
		name2 => "remap",    value2 => $remap, 
		name3 => "say_node", value3 => $say_node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	$conf->{cgi}{update_manifest} = 0 if not $conf->{cgi}{update_manifest};
	if ($remap)
	{
		my $title = AN::Common::get_string($conf, {key => "title_0174", variables => {
			node	=>	$say_node,
		}});
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-start-network-config", {
			title	=>	$title,
		});
	}
	my $return_code = 0;
	
	# First, make sure the script is downloaded and ready to run.
	my $proceed    = 0;
	my $shell_call = "
if [ ! -e \"$conf->{path}{'anvil-map-network'}\" ];
then
    echo 'not found'
else
    if [ ! -s \"$conf->{path}{'anvil-map-network'}\" ];
    then
        echo 'blank file';
        if [ -e \"$conf->{path}{'anvil-map-network'}\" ]; 
        then
            rm -f $conf->{path}{'anvil-map-network'};
        fi;
    else
        chmod 755 $conf->{path}{'anvil-map-network'};
        echo ready;
    fi
fi";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	if (not $conf->{node}{$node}{internet_access})
	{
		### TODO: figure out a way to see if either dashboard is online
		###       and, if so, try to download this from them.
		# No net, so no sense trying to download.
		$shell_call = "
if [ ! -e \"$conf->{path}{'anvil-map-network'}\" ];
then
    echo 'not found'
else
    if [ ! -e '/sbin/striker' ]
    then
        echo 'directory: [/sbin/striker] not found'
    else
        chmod 755 $conf->{path}{'anvil-map-network'};
    fi
fi";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
	}
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
			print AN::Common::get_string($conf, {key => "message_0378"});
		}
	}
	elsif ($conf->{node}{$node}{ssh_fh} !~ /^Net::SSH2/)
	{
		# Invalid or broken SSH handle.
		$an->Log->entry({log_level => 1, message_key => "log_0186", message_variables => {
			node   => $node, 
			ssh_fh => $conf->{node}{$node}{ssh_fh}, 
		}, file => $THIS_FILE, line => __LINE__});
		$return_code = 8;
	}
	else
	{
		# I need input from the user, so I need to call the client directly
		my $cluster = $conf->{cgi}{cluster};
		my $port    = 22;
		my $user    = "root";
		my $ssh_fh  = $conf->{node}{$node}{ssh_fh};
		my $close   = 0;
		
		### Build the shell call
		# Figure out the hash keys to use
		my $i;
		if ($node eq $conf->{cgi}{anvil_node1_current_ip})
		{
			# Node is 1
			$i = 1;
		}
		elsif ($node eq $conf->{cgi}{anvil_node2_current_ip})
		{
			# Node is 2
			$i = 2;
		}
		else
		{
			# wat?
			$return_code = 7;
		}
		
		my $shell_call = "$conf->{path}{'anvil-map-network'} --script --summary";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "remap", value1 => $remap,
		}, file => $THIS_FILE, line => __LINE__});
		if ($remap)
		{
			$conf->{cgi}{update_manifest} = 1;
			$shell_call = "$conf->{path}{'anvil-map-network'} --script";
		}
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call",           value1 => $shell_call,
			name2 => "cgi::update_manifest", value2 => $conf->{cgi}{update_manifest},
		}, file => $THIS_FILE, line => __LINE__});
		
		### Start the call
		my $state;
		my $error;

		# We need to open a channel every time for 'exec' calls. We
		# want to keep blocking off, but we need to enable it for the
		# channel() call.
		$ssh_fh->blocking(1);
		my $channel = $ssh_fh->channel();
		$ssh_fh->blocking(0);
		
		# Make the shell call
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "channel",    value1 => $channel,
			name2 => "shell_call", value2 => $shell_call,
		}, file => $THIS_FILE, line => __LINE__});
		$channel->exec("$shell_call");
		
		# This keeps the connection open when the remote side is slow
		# to return data, like in '/etc/init.d/rgmanager stop'.
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
					my $nic = $1;
					my $mac = $2;
					$conf->{conf}{node}{$node}{current_nic}{$nic} = $mac;
					$nics_seen++;
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "conf::node::${node}::current_nics::$nic", value1 => $conf->{conf}{node}{$node}{current_nic}{$nic},
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					print parse_script_line($conf, "STDOUT", $node, $line);
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
				print parse_script_line($conf, "STDERR", $node, $line);
			}
			
			# Exit when we get the end-of-file.
			last if $channel->eof;
		}
	}
	
	if (($remap) && (not $return_code))
	{
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-end-network-config");
		
		# We should now know this info.
		$conf->{conf}{node}{$node}{set_nic}{bcn_link1} = $conf->{conf}{node}{$node}{current_nic}{bcn_link1};
		$conf->{conf}{node}{$node}{set_nic}{bcn_link2} = $conf->{conf}{node}{$node}{current_nic}{bcn_link2};
		$conf->{conf}{node}{$node}{set_nic}{sn_link1}  = $conf->{conf}{node}{$node}{current_nic}{sn_link1};
		$conf->{conf}{node}{$node}{set_nic}{sn_link2}  = $conf->{conf}{node}{$node}{current_nic}{sn_link2};
		$conf->{conf}{node}{$node}{set_nic}{ifn_link1} = $conf->{conf}{node}{$node}{current_nic}{ifn_link1};
		$conf->{conf}{node}{$node}{set_nic}{ifn_link2} = $conf->{conf}{node}{$node}{current_nic}{ifn_link2};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0007", message_variables => {
			name1 => "node",      value1 => $node,
			name2 => "bcn_link1", value2 => $conf->{conf}{node}{$node}{set_nic}{bcn_link1},
			name3 => "bcn_link2", value3 => $conf->{conf}{node}{$node}{set_nic}{bcn_link2},
			name4 => "sn_link1",  value4 => $conf->{conf}{node}{$node}{set_nic}{sn_link1},
			name5 => "sn_link2",  value5 => $conf->{conf}{node}{$node}{set_nic}{sn_link2},
			name6 => "ifn_link1", value6 => $conf->{conf}{node}{$node}{set_nic}{ifn_link1},
			name7 => "ifn_link2", value7 => $conf->{conf}{node}{$node}{set_nic}{ifn_link2},
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

# This checks to see which, if any, packages need to be installed.
sub install_programs
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "install_programs" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# This could take a while
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-be-patient-message", {
		message	=>	"#!string!explain_0129!#",
	});
	
	### TODO: make these run at the same time
	my ($node1_ok) = install_missing_packages($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_ok) = install_missing_packages($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0024!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0024!#";
	my $message       = "";
	if (not $node1_ok)
	{
		$node1_class   = "highlight_bad_bold";
		$node1_message = AN::Common::get_string($conf, {key => "state_0025", variables => {
			missing	=>	$conf->{node}{$node1}{missing_rpms},
			node	=>	$node1,
		}});
		$ok            = 0;
	}
	if (not $node2_ok)
	{
		$node2_class   = "highlight_bad_bold";
		$node2_message = AN::Common::get_string($conf, {key => "state_0025", variables => {
			missing	=>	$conf->{node}{$node2}{missing_rpms},
			node	=>	$node2,
		}});
		$ok            = 0;
	}

	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0226!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	if (not $ok)
	{
		if ((not $conf->{node}{$node1}{internet}) || (not $conf->{node}{$node2}{internet}))
		{
			print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed", {
				message		=>	"#!string!message_0370!#",
			});
		}
		elsif (($conf->{node}{$node1}{os}{brand} =~ /Red Hat/) || ($conf->{node}{$node2}{os}{brand} =~ /Red Hat/))
		{
			print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed", {
				message		=>	"#!string!message_0369!#",
			});
		}
		else
		{
			print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed", {
				message		=>	"#!string!message_0369!#",
			});
		}
	}
	
	return($ok);
}

# This builds a list of missing packages and installs any that are missing.
sub install_missing_packages
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "install_missing_packages" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $ok = 1;
	get_installed_package_list($conf, $node, $password);
	
	# Figure out which are missing.
	my $to_install = "";
	foreach my $package (sort {$a cmp $b} keys %{$conf->{packages}{to_install}})
	{
		# Watch for autovivication...
		if ((exists $conf->{node}{$node}{packages}{installed}{$package}) && ($conf->{node}{$node}{packages}{installed}{$package} == 1))
		{
			# Already installed
			$conf->{packages}{to_install}{$package} = 1;
			$an->Log->entry({log_level => 3, message_key => "log_0187", message_variables => {
				node      => $node, 
				'package' => $package, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		else
		{
			# Needed
			$conf->{packages}{to_install}{$package} = 1;
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
		my $shell_call = "yum $conf->{sys}{yum_switches} install $to_install";
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
	get_installed_package_list($conf, $node, $password);
	
	my $missing = "";
	foreach my $package (sort {$a cmp $b} keys %{$conf->{packages}{to_install}})
	{
		# Watch for autovivication...
		if ((exists $conf->{node}{$node}{packages}{installed}{$package}) && ($conf->{node}{$node}{packages}{installed}{$package} == 1))
		{
			# Already installed
			$conf->{packages}{to_install}{$package} = 1;
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
		$ok = 0;
		$conf->{node}{$node}{missing_rpms} = $missing;
	}
	else
	{
		# Make sure the libvirtd bridge is gone.
		my $shell_call = "
if [ -e /proc/sys/net/ipv4/conf/virbr0 ]; 
then 
    virsh net-destroy default;
    virsh net-autostart default --disable;
    virsh net-undefine default;
else 
    cat /dev/null >/etc/libvirt/qemu/networks/default.xml;
fi;
if [ -e /proc/sys/net/ipv4/conf/virbr0 ]; 
then 
    echo failed;
else
    echo bridge gone;
fi";
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
if [ -e '$conf->{path}{nodes}{MegaCli64}' ]; 
then 
    if [ -e '/sbin/MegaCli64' ]
    then
        echo '/sbin/MegaCli64 symlink exists';
    else
        ln -s $conf->{path}{nodes}{MegaCli64} /sbin/
        if [ -e '/sbin/MegaCli64' ]
        then
            echo '/sbin/MegaCli64 symlink created';
        else
            echo 'Failed to create /sbin/MegaCli64 symlink';
        fi
    fi
else
    echo 'MegaCli64 not installed.'
fi";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
			
			if ($line =~ /Failed/i)
			{
				# Failed, source exist?
				$ok = 0;
				$an->Log->entry({log_level => 1, message_key => "log_0191", message_variables => {
					program => "MegaCli64", 
					path    => $conf->{path}{nodes}{MegaCli64}, 
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
if [ -e '$conf->{path}{nodes}{storcli64}' ]; 
then 
    if [ -e '/sbin/storcli64' ]
    then
        echo '/sbin/storcli64 symlink exists';
    else
        ln -s $conf->{path}{nodes}{storcli64} /sbin/
        if [ -e '/sbin/storcli64' ]
        then
            echo '/sbin/storcli64 symlink created';
        else
            echo 'Failed to create /sbin/storcli64 symlink';
        fi
    fi
else
    echo 'storcli64 not installed.'
fi";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
			
			if ($line =~ /Failed/i)
			{
				# Failed, symlink exist?
				$ok = 0;
				$an->Log->entry({log_level => 1, message_key => "log_0191", message_variables => {
					program => "storcli64", 
					path    => $conf->{path}{nodes}{storcli64}, 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /exists/i)
			{
				# Already exists.
				$an->Log->entry({log_level => 2, message_key => "log_0192", message_variables => {
					program => "storcli64", 
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /created/i)
			{
				# Created
				$an->Log->entry({log_level => 2, message_key => "log_0193", message_variables => {
					program => "storcli64", 
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		
		### TEMPORARY (Remove once https://bugzilla.redhat.com/show_bug.cgi?id=1285921 has a new resource-agents RPM).
		# Not checking is done for this given it is temporary.
		# Copy the /root/vm.sh to /usr/share/cluster/vm.sh, if it exists.
		$shell_call .= "
if [ -e '/root/vm.sh' ];
then 
    echo \"# Fix for rhbz#1285921\"
    echo \"copying fixed vm.sh to /usr/share/cluster/\"
    if [ -e '/usr/share/cluster/vm.sh' ];
    then
        if [ -e '/root/vm.sh.anvil' ];
        then
            echo \"Backup of vm.sh already exists at /root/vm.sh.anvil. Deleting /usr/share/cluster/vm.sh\"
            rm -f /usr/share/cluster/vm.sh
        else
            echo \"Backing up /usr/share/cluster/vm.sh to /root/vm.sh.anvil\"
            mv /usr/share/cluster/vm.sh /root/vm.sh.anvil
        fi
    fi
    cp /root/vm.sh /usr/share/cluster/vm.sh 
    chown root:root /usr/share/cluster/vm.sh
    chmod 755 /usr/share/cluster/vm.sh
    sleep 5
    /etc/init.d/ricci restart
else
    echo \"/root/vm.sh doesn't exist.\"
fi
";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "shell_call", value1 => $shell_call,
			name2 => "node",       value2 => $node,
		}, file => $THIS_FILE, line => __LINE__});
		($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
		}
	}
	
	return($ok);
}

# This calls 'yum list installed', parses the output and checks to see if the
# needed packages are installed.
sub get_installed_package_list
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_installed_package_list" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $ok         = 0;
	my $shell_call = "yum list installed";
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
			
			# Some packages are defined with the arch to ensure
			# other versions than the active arch of libraries are
			# installed. To be sure we see that they're installed,
			# we record the package with arch as '1'.
			my $package_with_arch = "$package.$arch";
			
			# NOTE: Someday record the version.
			$conf->{node}{$node}{packages}{installed}{$package}           = 1;
			$conf->{node}{$node}{packages}{installed}{$package_with_arch} = 1;
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
			
			# Some packages are defined with the arch to ensure
			# other versions than the active arch of libraries are
			# installed. To be sure we see that they're installed,
			# we record the package with arch as '1'.
			my $package_with_arch = "$package.$arch";
			
			# NOTE: Someday record the version.
			$conf->{node}{$node}{packages}{installed}{$package}           = 1;
			$conf->{node}{$node}{packages}{installed}{$package_with_arch} = 1;
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
			
			# Some packages are defined with the arch to ensure
			# other versions than the active arch of libraries are
			# installed. To be sure we see that they're installed,
			# we record the package with arch as '1'.
			my $package_with_arch = "$package.$arch";
			
			$conf->{node}{$node}{packages}{installed}{$package}           = 1;
			$conf->{node}{$node}{packages}{installed}{$package_with_arch} = 1;
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "Package", value1 => $package,
				name2 => "arch",    value2 => $arch,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

# This calls yum update against both nodes.
sub update_nodes
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "update_nodes" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# This could take a while
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-be-patient-message", {
		message	=>	"#!string!explain_0130!#",
	});
	
	# The OS update is good, but not fatal if it fails.
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	   $conf->{node}{$node1}{os_updated} = 0;
	   $conf->{node}{$node2}{os_updated} = 0;
	my ($node1_rc) = update_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_rc) = update_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvi2_node1_current_password});
	# 0 = update attempted
	# 1 = OS updates disabled in manifest
	
	# Remove the priority= from the nodes. We don't care about the output.
	remove_priority_from_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	remove_priority_from_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvi2_node1_current_password});
	
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0026!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0026!#";
	if ($node1_rc)
	{
		$node1_message = "#!string!state_0060!#",
	}
	elsif (not $conf->{node}{$node1}{os_updated})
	{
		$node1_message = "#!string!state_0027!#",
	}
	if ($node2_rc)
	{
		$node2_message = "#!string!state_0060!#",
	}
	elsif (not $conf->{node}{$node2}{os_updated})
	{
		$node2_message = "#!string!state_0027!#",
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0227!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	return(0);
}

# This sed's out the 'priority=' from the striker repos.
sub remove_priority_from_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "remove_priority_from_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Remove the 'priority=' line from our repos so that the update hits the web.
	my $shell_call = "
for repo in \$(ls /etc/yum.repos.d/);
do 
    sed -i '/priority=/d' /etc/yum.repos.d/\${repo};
done
";
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
	}
	
	return(0);
}

# This calls the yum update and flags the node for a reboot if the kernel is updated.
sub update_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "update_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Skip if the user has decided not to run OS updates.
	return(1) if not $conf->{sys}{update_os};
	
	my $shell_call = "yum $conf->{sys}{yum_switches} update";
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
		$line =~ s/\n//g;
		$line =~ s/\r//g;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
		
		if ($line =~ /Installing : kernel/)
		{
			# New kernel, we'll need to reboot.
			$conf->{node}{$node}{reboot_needed} = 1;
			$an->Log->entry({log_level => 2, message_key => "log_0194", message_variables => {
				node => $node, 
			}, file => $THIS_FILE, line => __LINE__});
		}
		if ($line =~ /Total download size/)
		{
			# Updated packages
			$conf->{node}{$node}{os_updated} = 1;
			$an->Log->entry({log_level => 2, message_key => "log_0195", message_variables => {
				node => $node, 
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return(0);
}

# This checks to see if perl is installed on the nodes and installs it if not.
sub verify_perl_is_installed
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "verify_perl_is_installed" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my ($node1_ok) = verify_perl_is_installed_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_ok) = verify_perl_is_installed_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	
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
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0243!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	if (not $ok)
	{
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
			message	=>	"#!string!message_0386!#",
			row	=>	"#!string!state_0037!#",
		});
	}
	
	return($ok);
}

# This will check to see if perl is installed and, if it's not, it will try to install it.
sub verify_perl_is_installed_on_node
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "verify_perl_is_installed_on_node" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Set to '1' if perl was found, '0' if it wasn't found and couldn't be
	# installed, set to '2' if installed successfully.
	my $ok = 1;
	my $shell_call = "
if [ -e '/usr/bin/perl' ]; 
then
    echo striker:ok
else
    yum $conf->{sys}{yum_switches} install perl;
    if [ -e '/usr/bin/perl' ];
    then
        echo striker:installed
    else
        echo striker:failed
    fi
fi";
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

# This pings alteeve.ca to check for internet access.
sub verify_internet_access
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "verify_internet_access" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# If the user knows they will never be online, they may have set to hide the Internet check. In this
	# case, don't waste time checking.
	if (not $conf->{sys}{install_manifest}{show}{internet_check})
	{
		# User has disabled checking for an internet connection, mark that there is no connection.
		$an->Log->entry({log_level => 2, message_key => "log_0196", file => $THIS_FILE, line => __LINE__});
		my $node1 = $conf->{cgi}{anvil_node1_current_ip};
		my $node2 = $conf->{cgi}{anvil_node2_current_ip};
		$conf->{node}{$node1}{internet} = 0;
		$conf->{node}{$node2}{internet} = 0;
		return(0);
	}
	
	my ($node1_online) = ping_website($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_online) = ping_website($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	
	# If the node is not online, we'll call yum with the switches to  disable all but our local repos.
	if ((not $node1_online) or (not $node2_online))
	{
		# No internet, restrict access to local only.
		$conf->{sys}{yum_switches} = "-y --disablerepo='*' --enablerepo='striker*'";
		$an->Log->entry({log_level => 2, message_key => "log_0197", file => $THIS_FILE, line => __LINE__});
	}
	
	# I need to remember if there is Internet access or not for later downloads (web or switch to local).
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	$conf->{node}{$node1}{internet_access} = $node1_online;
	$conf->{node}{$node2}{internet_access} = $node2_online;
	
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
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0223!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	if (not $ok)
	{
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
			message	=>	"#!string!message_0366!#",
			row	=>	"#!string!state_0021!#",
		});
	}
	
	return(1);
}

# This pings as website to check for an internet connection. Will clean up routes that conflict with the
# default one as well.
sub ping_website
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "ping_website" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# After installing, sometimes/often the system will come up with multiple interfaces on the same 
	# subnet, causing default route problems. So the first thing to do is look for the interface the IP
	# we're using to connect is on, see it's subnet and see if anything else is on the same subnet. If 
	# so, delete the other interface(s) from the route table.
	my $dg_device  = "";
	my $shell_call = "route -n";
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
			$conf->{conf}{node}{$node}{routes}{interface}{$interface} = "$network/$netmask";
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "conf::node::${node}::routes::interface::${interface}", value1 => $conf->{conf}{node}{$node}{routes}{interface}{$interface},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# Now look for offending devices 
	$an->Log->entry({log_level => 2, message_key => "log_0198", message_variables => {
		node => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	my ($dg_network, $dg_netmask) = ($conf->{conf}{node}{$node}{routes}{interface}{$dg_device} =~ /^(\d+\.\d+\.\d+\.\d+)\/(\d+\.\d+\.\d+\.\d+)/);
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "dg_device", value1 => $dg_device,
		name2 => "network",   value2 => $dg_network/$dg_netmask,
	}, file => $THIS_FILE, line => __LINE__});
	foreach my $interface (sort {$a cmp $b} keys %{$conf->{conf}{node}{$node}{routes}{interface}})
	{
		$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
			name1 => "interface", value1 => $interface,
			name2 => "dg_device", value2 => $dg_device,
		}, file => $THIS_FILE, line => __LINE__});
		next if $interface eq $dg_device;
		my ($network, $netmask) = ($conf->{conf}{node}{$node}{routes}{interface}{$interface} =~ /^(\d+\.\d+\.\d+\.\d+)\/(\d+\.\d+\.\d+\.\d+)/);
		if (($dg_network eq $network) && ($dg_netmask eq $netmask))
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
				name1 => "Conflicting route! interface", value1 => $interface,
				name2 => "network",                      value2 => $network/$netmask,
			}, file => $THIS_FILE, line => __LINE__});
			my $shell_call = "route del -net $network netmask $netmask dev $interface; echo rc:\$?";
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
	$conf->{node}{$node}{internet} = 0;
	
	### TODO: If a node has two interfaces up on the same subnet, determine which matches the one we're 
	###       coming in on and down the  other(s).
	my $ok = 0;
	
	# Ya, I know 8.8.8.8 isn't a website...
	# 0 == pingable, 1 == failed.
	my $ping_rc = $an->Check->ping({target => "8.8.8.8", count => 3});
	if ($ping_rc eq "0")
	{
		$ok = 1;
		$conf->{node}{$node}{internet} = 1;
	}
	
	# If there is no internet connection, add a yum repo for the cdrom
	if (not $conf->{node}{$node}{internet})
	{
		# Make sure the DVD repo exists.
		create_dvd_repo($conf, $node, $password);
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node", value1 => $node,
		name2 => "ok",   value2 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This checks to see if the DVD repo has been added to the node yet. If not, and if there is a disk in the
# drive, it will mount sr0, check that it's got RPMs and, if so, create the repo. If not, it unmounts the 
# DVD.
sub create_dvd_repo
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "create_dvd_repo" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# A wee bit of bash in this one...
	my $return_code = -1;
	my $mount_name  = "optical";
	my $shell_call  = "
if [ -e \"/dev/sr0\" ];
then
    echo \"DVD drive exists.\"
    if [ -e \"/mnt/$mount_name\" ]
    then
        echo \"Optical drive mount point exists.\"
    else
        echo \"Optical drive mount point does not exist yet.\"
        mkdir /mnt/$mount_name
        if [ ! -e \"/mnt/$mount_name\" ]
        then
            echo \"Creating mountpoint failed.\"
            echo \"exit:2\"
            exit 2
        fi
    fi
    if \$(mount | grep -q sr0)
    then
        echo \"Optical drive already mounted.\"
    else
        echo \"Optical drive not mounted.\"
        mount /dev/sr0 /mnt/$mount_name
        if ! \$(mount | grep -q sr0)
        then
            echo \"Mount failed.\"
            echo \"exit:3\"
            exit 3
        fi
    fi
    if [ -e \"/mnt/$mount_name/Packages\" ]
    then
        echo \"Install media found.\"
    else
        echo \"Install media not found, ejecting disk.\"
        umount /mnt/$mount_name
        echo \"exit:4\"
        exit 4
    fi
    if [ -e \"/etc/yum.repos.d/$mount_name.repo\" ]
    then
        echo \"Repo already exists, skipping.\"
        echo \"exit:0\"
        exit 0
    else
        echo \"Creating optical media repo.\"
        cat > /etc/yum.repos.d/$mount_name.repo << EOF
[$mount_name]
baseurl=file:///mnt/$mount_name/
enabled=1
gpgcheck=0
skip_if_unavailable=1
EOF
        echo \"Cleaning repo data\"
        yum clean all
        echo \"exit:0\"
        exit 0
    fi
else
    echo \"No optical drive found, exiting\"
    echo \"exit:1\"
    exit 1
fi";
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
		
		if ($line =~ /exit:(\d+)/)
		{
			$return_code = $1;
		}
		else
		{
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "return line", value1 => $line,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	return($return_code);
}

# This calculates the sizes of the partitions to create, or selects the size based on existing partitions if 
# found.
sub calculate_storage_pool_sizes
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "calculate_storage_pool_sizes" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# These will be set to the lower of the two nodes.
	my $node1      = $conf->{cgi}{anvil_node1_current_ip};
	my $node2      = $conf->{cgi}{anvil_node2_current_ip};
	my $pool1_size = "";
	my $pool2_size = "";
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node::${node1}::pool1::existing_size", value1 => $conf->{node}{$node1}{pool1}{existing_size},
		name2 => "node::${node2}::pool1::existing_size", value2 => $conf->{node}{$node2}{pool1}{existing_size},
	}, file => $THIS_FILE, line => __LINE__});
	if (($conf->{node}{$node1}{pool1}{existing_size}) || ($conf->{node}{$node2}{pool1}{existing_size}))
	{
		# See which I have.
		if (($conf->{node}{$node1}{pool1}{existing_size}) && ($conf->{node}{$node2}{pool1}{existing_size}))
		{
			# Both, OK. Are they the same?
			if ($conf->{node}{$node1}{pool1}{existing_size} eq $conf->{node}{$node2}{pool1}{existing_size})
			{
				# Golden
				$pool1_size = $conf->{node}{$node1}{pool1}{existing_size};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "pool1_size", value1 => $pool1_size,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Nothing we can do but warn the user.
				$pool1_size = $conf->{node}{$node1}{pool1}{existing_size};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "pool1_size", value1 => $pool1_size,
				}, file => $THIS_FILE, line => __LINE__});
				if ($conf->{node}{$node1}{pool1}{existing_size} < $conf->{node}{$node2}{pool1}{existing_size})
				{
					$pool1_size = $conf->{node}{$node2}{pool1}{existing_size};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "pool1_size", value1 => $pool1_size,
					}, file => $THIS_FILE, line => __LINE__});
				}
				print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
					message	=>	AN::Common::get_string($conf, {key => "message_0394", variables => { 
						node1		=>	$node1,
						node1_device	=>	$conf->{node}{$node1}{pool1}{partition},
						node1_size	=>	AN::Cluster::bytes_to_hr($conf, $conf->{node}{$node1}{pool1}{existing_size})." ($conf->{node}{$node1}{pool1}{existing_size} #!string!suffix_0009!#)",
						node2		=>	$node2,
						node2_device	=>	$conf->{node}{$node1}{pool1}{partition},
						node1_size	=>	AN::Cluster::bytes_to_hr($conf, $conf->{node}{$node2}{pool1}{existing_size})." ($conf->{node}{$node2}{pool1}{existing_size} #!string!suffix_0009!#)",
					}}),
					row	=>	"#!string!state_0052!#",
				});
			}
		}
		elsif ($conf->{node}{$node1}{pool1}{existing_size})
		{
			# Node 2 isn't partitioned yet but node 1 is.
			$pool1_size                                 = $conf->{node}{$node1}{pool1}{existing_size};
			$conf->{cgi}{anvil_storage_pool1_byte_size} = $conf->{node}{$node1}{pool1}{existing_size};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "pool1_size", value1 => $pool1_size,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($conf->{node}{$node2}{pool1}{existing_size})
		{
			# Node 1 isn't partitioned yet but node 2 is.
			$pool1_size                                 = $conf->{node}{$node2}{pool1}{existing_size};
			$conf->{cgi}{anvil_storage_pool1_byte_size} = $conf->{node}{$node2}{pool1}{existing_size};
			$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
				name1 => "pool1_size", value1 => $pool1_size,
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		$conf->{cgi}{anvil_storage_pool1_byte_size} = $pool1_size;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_storage_pool1_byte_size", value1 => $conf->{cgi}{anvil_storage_pool1_byte_size},
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
		name1 => "node::${node1}::pool2::existing_size", value1 => $conf->{node}{$node1}{pool2}{existing_size},
		name2 => "node::${node2}::pool2::existing_size", value2 => $conf->{node}{$node2}{pool2}{existing_size},
	}, file => $THIS_FILE, line => __LINE__});
	if (($conf->{node}{$node1}{pool2}{existing_size}) || ($conf->{node}{$node2}{pool2}{existing_size}))
	{
		# See which I have.
		if (($conf->{node}{$node1}{pool2}{existing_size}) && ($conf->{node}{$node2}{pool2}{existing_size}))
		{
			# Both, OK. Are they the same?
			if ($conf->{node}{$node1}{pool2}{existing_size} eq $conf->{node}{$node2}{pool2}{existing_size})
			{
				# Golden
				$pool2_size = $conf->{node}{$node1}{pool2}{existing_size};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "pool2_size", value1 => $pool2_size,
				}, file => $THIS_FILE, line => __LINE__});
			}
			else
			{
				# Nothing we can do but warn the user.
				$pool2_size = $conf->{node}{$node1}{pool2}{existing_size};
				$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
					name1 => "pool2_size", value1 => $pool2_size,
				}, file => $THIS_FILE, line => __LINE__});
				if ($conf->{node}{$node1}{pool2}{existing_size} < $conf->{node}{$node2}{pool2}{existing_size})
				{
					$pool2_size = $conf->{node}{$node2}{pool2}{existing_size};
					$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
						name1 => "pool2_size", value1 => $pool2_size,
					}, file => $THIS_FILE, line => __LINE__});
				}
				print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
					message	=>	AN::Common::get_string($conf, {key => "message_0394", variables => { 
						node1		=>	$node1,
						node1_device	=>	$conf->{node}{$node1}{pool2}{partition},
						node1_size	=>	AN::Cluster::bytes_to_hr($conf, $conf->{node}{$node1}{pool2}{existing_size})." ($conf->{node}{$node1}{pool2}{existing_size} #!string!suffix_0009!#)",
						node2		=>	$node2,
						node2_device	=>	$conf->{node}{$node1}{pool2}{partition},
						node1_size	=>	AN::Cluster::bytes_to_hr($conf, $conf->{node}{$node2}{pool2}{existing_size})." ($conf->{node}{$node2}{pool2}{existing_size} #!string!suffix_0009!#)",
					}}),
					row	=>	"#!string!state_0052!#",
				});
			}
		}
		elsif ($conf->{node}{$node1}{pool2}{existing_size})
		{
			# Node 2 isn't partitioned yet but node 1 is.
			$pool2_size                                 = $conf->{node}{$node1}{pool2}{existing_size};
			$conf->{cgi}{anvil_storage_pool2_byte_size} = $conf->{node}{$node1}{pool2}{existing_size};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "pool2_size", value1 => $pool2_size,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($conf->{node}{$node2}{pool2}{existing_size})
		{
			# Node 1 isn't partitioned yet but node 2 is.
			$pool2_size                                 = $conf->{node}{$node2}{pool2}{existing_size};
			$conf->{cgi}{anvil_storage_pool2_byte_size} = $conf->{node}{$node2}{pool2}{existing_size};
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "pool2_size", value1 => $pool2_size,
			}, file => $THIS_FILE, line => __LINE__});
		}
		
		$conf->{cgi}{anvil_storage_pool2_byte_size} = $pool2_size;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "cgi::anvil_storage_pool2_byte_size", value1 => $conf->{cgi}{anvil_storage_pool2_byte_size},
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
	my $media_library_size      = $conf->{cgi}{anvil_media_library_size};
	my $media_library_unit      = $conf->{cgi}{anvil_media_library_unit};
	my $media_library_byte_size = AN::Cluster::hr_to_bytes($conf, $media_library_size, $media_library_unit, 1);
	my $minimum_space_needed    = $media_library_byte_size;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "media_library_byte_size", value1 => $media_library_byte_size,
		name2 => "minimum_space_needed",    value2 => $minimum_space_needed,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $minimum_pool_size  = AN::Cluster::hr_to_bytes($conf, 8, "GiB", 1);
	my $pool1_minimum_size = $minimum_space_needed + $minimum_pool_size;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "minimum_pool_size",  value1 => $minimum_pool_size,
		name2 => "pool1_minimum_size", value2 => $pool1_minimum_size,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Knowing the smallest This will be useful in a few places.
	my $node1_disk = $conf->{node}{$node1}{pool1}{disk};
	my $node2_disk = $conf->{node}{$node2}{pool1}{disk};
	
	my $smallest_free_size = $conf->{node}{$node1}{disk}{$node1_disk}{free_space}{size};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "smallest_free_size", value1 => $smallest_free_size,
	}, file => $THIS_FILE, line => __LINE__});
	if ($conf->{node}{$node1}{disk}{$node1_disk}{free_space}{size} > $conf->{node}{$node2}{disk}{$node2_disk}{free_space}{size})
	{
		$smallest_free_size = $conf->{node}{$node2}{disk}{$node2_disk}{free_space}{size};
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "smallest_free_size", value1 => $smallest_free_size,
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# If both are "calculate", do so. If only one is "calculate", use the
	# available free size.
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
			my $storage_pool1_size = $conf->{cgi}{anvil_storage_pool1_size};
			my $storage_pool1_unit = $conf->{cgi}{anvil_storage_pool1_unit};
			
			### Ok, both are. Then we do our normal math.
			# If pool1 is '100%', then this is easy.
			if (($storage_pool1_size eq "100") && ($storage_pool1_unit eq "%"))
			{
				# All to pool 1.
				$pool1_size                                 = $smallest_free_size;
				$pool2_size                                 = 0;
				$conf->{cgi}{anvil_storage_pool1_byte_size} = $pool1_size;
				$conf->{cgi}{anvil_storage_pool2_byte_size} = 0;
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
					$storage_pool1_byte_size =  AN::Cluster::hr_to_bytes($conf, $storage_pool1_size, $storage_pool1_unit, 1);
					$minimum_space_needed    += $storage_pool1_byte_size;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "storage_pool1_byte_size", value1 => $storage_pool1_byte_size,
						name2 => "minimum_space_needed",    value2 => $minimum_space_needed,
					}, file => $THIS_FILE, line => __LINE__});
				}

				# Things are good, so calculate the static sizes of our pool
				# for display in the summary/confirmation later.
				# Make sure the storage pool is an even MiB.
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
				$conf->{cgi}{anvil_media_library_byte_size} = $media_library_byte_size;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "cgi::anvil_media_library_byte_size", value1 => $conf->{cgi}{anvil_media_library_byte_size},
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
					
					# Round down to the closest even MiB (left over space
					# will be unallocated on disk)
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
					$conf->{cgi}{anvil_storage_pool1_byte_size} = $pool1_byte_size + $media_library_byte_size;
					$conf->{cgi}{anvil_storage_pool2_byte_size} = $pool2_byte_size;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "cgi::anvil_storage_pool1_byte_size", value1 => $conf->{cgi}{anvil_storage_pool1_byte_size},
						name2 => "cgi::anvil_storage_pool2_byte_size", value2 => $conf->{cgi}{anvil_storage_pool2_byte_size},
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
							hr_pool_size => AN::Cluster::bytes_to_hr($conf, $pool1_byte_size), 
						}, file => $THIS_FILE, line => __LINE__});
						$conf->{sys}{pool1_shrunk} = 1;
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
					
					$conf->{cgi}{anvil_storage_pool1_byte_size} = $pool1_byte_size + $media_library_byte_size;
					$conf->{cgi}{anvil_storage_pool2_byte_size} = $pool2_byte_size;
					$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
						name1 => "cgi::anvil_storage_pool1_byte_size", value1 => $conf->{cgi}{anvil_storage_pool1_byte_size},
						name2 => "cgi::anvil_storage_pool2_byte_size", value2 => $conf->{cgi}{anvil_storage_pool2_byte_size},
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
					name1 => "cgi::anvil_media_library_byte_size", value1 => $conf->{cgi}{anvil_media_library_byte_size},
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
		elsif ($pool1_size eq "calculate")
		{
			# OK, Pool 1 is calculate, just use all the free space
			# (or the lower of the two if they don't match.
			$pool1_size = $smallest_free_size;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "pool1_size", value1 => $pool1_size,
			}, file => $THIS_FILE, line => __LINE__});
		}
		elsif ($pool2_size eq "calculate")
		{
			# OK, Pool 1 is calculate, just use all the free space
			# (or the lower of the two if they don't match.
			$pool2_size = $smallest_free_size;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "pool2_size", value1 => $pool2_size,
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	# We no longer use pool 2.
	$conf->{cgi}{anvil_storage_pool2_byte_size} = 0;
	return(0);
}

# This checks to see if both nodes have the same amount of unallocated space.
sub check_storage
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_storage" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### TODO: When the drive is partitioned, write a file out indicating
	###       which partitions we created so that we don't error out for
	###       lack of free space on re-runs on the program.
	
	my $ok = 1;
	my ($node1_disk) = get_partition_data($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_disk) = get_partition_data($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_disk", value1 => $node1_disk,
		name2 => "node2_disk", value2 => $node2_disk,
	}, file => $THIS_FILE, line => __LINE__});
	
	# How much space do I have?
	my $node1           = $conf->{cgi}{anvil_node1_current_ip};
	my $node2           = $conf->{cgi}{anvil_node2_current_ip};
	my $node1_disk_size = $conf->{node}{$node1}{disk}{$node1_disk}{size};
	my $node2_disk_size = $conf->{node}{$node2}{disk}{$node2_disk}{size};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node1",           value1 => $node1,
		name2 => "node2",           value2 => $node2,
		name3 => "node1_disk_size", value3 => $node1_disk_size,
		name4 => "node2_disk_size", value4 => $node2_disk_size,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Now I need to know which partitions I will use for pool 1 and 2.
	# Only then can I sanity check space needed. If one node has the
	# partitions already in place, then that will determine the other
	# node's partition size regardless of anything else. This will set:
	get_storage_pool_partitions($conf);
	
	# Now we can calculate partition sizes.
	calculate_storage_pool_sizes($conf);
	
	if ($conf->{sys}{pool1_shrunk})
	{
		my $requested_byte_size = AN::Cluster::hr_to_bytes($conf, $conf->{cgi}{anvil_storage_pool1_size}, $conf->{cgi}{anvil_storage_pool1_unit}, 1);
		my $say_requested_size  = AN::Cluster::bytes_to_hr($conf, $requested_byte_size);
		my $byte_difference     = $requested_byte_size - $conf->{cgi}{anvil_storage_pool1_byte_size};
		my $say_difference      = AN::Cluster::bytes_to_hr($conf, $byte_difference);
		my $say_new_size        = AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size});
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
			message	=>	AN::Common::get_string($conf, {key => "message_0375", variables => {
				say_requested_size	=>	$say_requested_size,
				say_new_size		=>	$say_new_size,
				say_difference		=>	$say_difference,
			}}),
			row	=>	"#!string!state_0043!#",
		});
	}
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "cgi::anvil_storage_pool1_byte_size", value1 => $conf->{cgi}{anvil_storage_pool1_byte_size},
		name2 => "cgi::anvil_storage_pool2_byte_size", value2 => $conf->{cgi}{anvil_storage_pool2_byte_size},
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $conf->{cgi}{anvil_storage_pool1_byte_size}) && (not $conf->{cgi}{anvil_storage_pool2_byte_size}))
	{
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
			message	=>	"#!string!message_0397!#",
			row	=>	"#!string!state_0043!#",
		});
		$ok      = 0;
	}
	
	# Message stuff
	if (not $conf->{cgi}{anvil_media_library_byte_size})
	{
		$conf->{cgi}{anvil_media_library_byte_size} = AN::Cluster::hr_to_bytes($conf, $conf->{cgi}{anvil_media_library_size}, $conf->{cgi}{anvil_media_library_unit}, 1);
	}
	my $node1_class   = "highlight_good_bold";
	my $node1_message = AN::Common::get_string($conf, {key => "state_0054", variables => {
				pool1_device	=>	"$conf->{node}{$node1}{pool1}{disk}$conf->{node}{$node1}{pool1}{partition}",
				pool1_size	=>	AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}),
				pool2_device	=>	$conf->{cgi}{anvil_storage_pool2_byte_size} ? "$conf->{node}{$node1}{pool2}{disk}$conf->{node}{$node1}{pool2}{partition}"  : "--",
				pool2_size	=>	$conf->{cgi}{anvil_storage_pool2_byte_size} ? AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}) : "--",
				media_size	=>	AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_media_library_byte_size}),
			}});
	my $node2_class   = "highlight_good_bold";
	my $node2_message = AN::Common::get_string($conf, {key => "state_0054", variables => {
				pool1_device	=>	"$conf->{node}{$node2}{pool1}{disk}$conf->{node}{$node2}{pool1}{partition}",
				pool1_size	=>	AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}),
				pool2_device	=>	$conf->{cgi}{anvil_storage_pool2_byte_size} ? "$conf->{node}{$node2}{pool2}{disk}$conf->{node}{$node2}{pool2}{partition}"  : "--",
				pool2_size	=>	$conf->{cgi}{anvil_storage_pool2_byte_size} ? AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}) : "--",
				media_size	=>	AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_media_library_byte_size}),
			}});
	if (not $ok)
	{
		$node1_class = "highlight_warning_bold";
		$node2_class = "highlight_warning_bold";
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0222!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	return($ok);
}

# This determines which partitions to use for storage pool 1 and 2. Existing partitions override anything
# else for determining sizes.
sub get_storage_pool_partitions
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_storage_pool_partitions" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	### TODO: Determine if I still need this function at all...
	# First up, check for /etc/drbd.d/r{0,1}.res on both nodes.
	my ($node1_r0_device, $node1_r1_device) = read_drbd_resource_files($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $conf->{cgi}{anvil_node1_name});
	my ($node2_r0_device, $node2_r1_device) = read_drbd_resource_files($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $conf->{cgi}{anvil_node2_name});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node1_r0_device", value1 => $node1_r0_device,
		name2 => "node1_r1_device", value2 => $node1_r1_device,
		name3 => "node2_r0_device", value3 => $node2_r0_device,
		name4 => "node2_r1_device", value4 => $node2_r1_device,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Next, decide what devices I will use if DRBD doesn't exist.
	foreach my $node ($conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node2_current_ip})
	{
		# If the disk to use is 'Xda', skip the first three partitions
		# as they will be for the OS.
		my $disk = $conf->{node}{$node}{biggest_disk};
		$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
			name1 => "node", value1 => $node,
			name2 => "disk", value2 => $disk,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Default to logical partitions.
		my $create_extended_partition = 0;
		my $pool1_partition           = 4;
		my $pool2_partition           = 5;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node::${node}::disk::${disk}::partition_count", value1 => $conf->{node}{$node}{disk}{$disk}{partition_count},
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
				name1 => "node::${node}::disk::${disk}::label", value1 => $conf->{node}{$node}{disk}{$disk}{label},
			}, file => $THIS_FILE, line => __LINE__});
			if ($conf->{node}{$node}{disk}{$disk}{label} eq "msdos")
			{
				$create_extended_partition = 1;
				$pool1_partition           = 5;
				$pool2_partition           = 6;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
					name1 => "node::${node}::disk::${disk}::partition_count", value1 => $conf->{node}{$node}{disk}{$disk}{partition_count},
					name2 => "create_extended_partition",                     value2 => $create_extended_partition,
					name3 => "pool1_partition",                               value3 => $pool1_partition,
					name4 => "pool2_partition",                               value4 => $pool2_partition,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($conf->{node}{$node}{disk}{$disk}{partition_count} >= 4)
			{
				### TODO: Actually parse /etc/fstab to confirm...
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
		$conf->{node}{$node}{pool1}{create_extended} = $create_extended_partition;
		$conf->{node}{$node}{pool1}{device}          = "/dev/${disk}${pool1_partition}";
		$conf->{node}{$node}{pool2}{device}          = "/dev/${disk}${pool2_partition}";
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node",                         value1 => $node,
			name2 => "node::${node}::pool1::device", value2 => $conf->{node}{$node}{pool1}{device},
			name3 => "node::${node}::pool2::device", value3 => $conf->{node}{$node}{pool2}{device},
		}, file => $THIS_FILE, line => __LINE__});
	}
	
	# OK, if we found a device in DRBD, override the values from the loop.
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	
	$conf->{node}{$node1}{pool1}{device} = $node1_r0_device ? $node1_r0_device : $conf->{node}{$node1}{pool1}{device};
	$conf->{node}{$node1}{pool2}{device} = $node1_r1_device ? $node1_r1_device : $conf->{node}{$node1}{pool2}{device};
	$conf->{node}{$node2}{pool1}{device} = $node2_r0_device ? $node2_r0_device : $conf->{node}{$node2}{pool1}{device};
	$conf->{node}{$node2}{pool2}{device} = $node2_r1_device ? $node2_r1_device : $conf->{node}{$node2}{pool2}{device};
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node::${node1}::pool1::device", value1 => $conf->{node}{$node1}{pool1}{device},
		name2 => "node::${node1}::pool2::device", value2 => $conf->{node}{$node1}{pool2}{device},
		name3 => "node::${node2}::pool1::device", value3 => $conf->{node}{$node2}{pool1}{device},
		name4 => "node::${node2}::pool2::device", value4 => $conf->{node}{$node2}{pool2}{device},
	}, file => $THIS_FILE, line => __LINE__});
	
	# Now, if either partition exists on either node, use that size to force the other node's size.
	my ($node1_pool1_disk, $node1_pool1_partition) = ($conf->{node}{$node1}{pool1}{device} =~ /\/dev\/(.*?)(\d)/);
	my ($node1_pool2_disk, $node1_pool2_partition) = ($conf->{node}{$node1}{pool2}{device} =~ /\/dev\/(.*?)(\d)/);
	my ($node2_pool1_disk, $node2_pool1_partition) = ($conf->{node}{$node2}{pool1}{device} =~ /\/dev\/(.*?)(\d)/);
	my ($node2_pool2_disk, $node2_pool2_partition) = ($conf->{node}{$node2}{pool2}{device} =~ /\/dev\/(.*?)(\d)/);
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
	
	$conf->{node}{$node1}{pool1}{disk}      = $node1_pool1_disk;
	$conf->{node}{$node1}{pool1}{partition} = $node1_pool1_partition;
	$conf->{node}{$node1}{pool2}{disk}      = $node1_pool2_disk;
	$conf->{node}{$node1}{pool2}{partition} = $node1_pool2_partition;
	$conf->{node}{$node2}{pool1}{disk}      = $node2_pool1_disk;
	$conf->{node}{$node2}{pool1}{partition} = $node2_pool1_partition;
	$conf->{node}{$node2}{pool2}{disk}      = $node2_pool2_disk;
	$conf->{node}{$node2}{pool2}{partition} = $node2_pool2_partition;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0008", message_variables => {
		name1 => "node::${node1}::pool1::disk",      value1 => $conf->{node}{$node1}{pool1}{disk},
		name2 => "node::${node1}::pool1::partition", value2 => $conf->{node}{$node1}{pool1}{partition},
		name3 => "node::${node1}::pool2::disk",      value3 => $conf->{node}{$node1}{pool2}{disk},
		name4 => "node::${node1}::pool2::partition", value4 => $conf->{node}{$node1}{pool2}{partition},
		name5 => "node::${node2}::pool1::disk",      value5 => $conf->{node}{$node2}{pool1}{disk},
		name6 => "node::${node2}::pool1::partition", value6 => $conf->{node}{$node2}{pool1}{partition},
		name7 => "node::${node2}::pool2::disk",      value7 => $conf->{node}{$node2}{pool2}{disk},
		name8 => "node::${node2}::pool2::partition", value8 => $conf->{node}{$node2}{pool2}{partition},
	}, file => $THIS_FILE, line => __LINE__});
	
	$conf->{node}{$node1}{pool1}{existing_size} = $conf->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{$node1_pool1_partition}{size} ? $conf->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{$node1_pool1_partition}{size} : 0;
	$conf->{node}{$node1}{pool2}{existing_size} = $conf->{node}{$node1}{disk}{$node1_pool2_disk}{partition}{$node1_pool2_partition}{size} ? $conf->{node}{$node1}{disk}{$node1_pool2_disk}{partition}{$node1_pool2_partition}{size} : 0;
	$conf->{node}{$node2}{pool1}{existing_size} = $conf->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{$node2_pool1_partition}{size} ? $conf->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{$node2_pool1_partition}{size} : 0;
	$conf->{node}{$node2}{pool2}{existing_size} = $conf->{node}{$node2}{disk}{$node2_pool2_disk}{partition}{$node2_pool2_partition}{size} ? $conf->{node}{$node2}{disk}{$node2_pool2_disk}{partition}{$node2_pool2_partition}{size} : 0;
	$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
		name1 => "node::${node1}::pool1::existing_size", value1 => $conf->{node}{$node1}{pool1}{existing_size},
		name2 => "node::${node1}::pool2::existing_size", value2 => $conf->{node}{$node1}{pool2}{existing_size},
		name3 => "node::${node2}::pool1::existing_size", value3 => $conf->{node}{$node2}{pool1}{existing_size},
		name4 => "node::${node2}::pool2::existing_size", value4 => $conf->{node}{$node2}{pool2}{existing_size},
	}, file => $THIS_FILE, line => __LINE__});
	
	return(0);
}

# This looks for the two DRBD resource files and, if found, pulls the partitions to use out of them.
sub read_drbd_resource_files
{
	my ($conf, $node, $password, $hostname) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "read_drbd_resource_files" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node",     value1 => $node, 
		name2 => "hostname", value2 => $hostname, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $r0_device = "";
	my $r1_device = "";
	foreach my $file ($conf->{path}{nodes}{drbd_r0}, $conf->{path}{nodes}{drbd_r1})
	{
		# Skip if no pool1
		if (($conf->{path}{nodes}{drbd_r1}) && (not $conf->{cgi}{anvil_storage_pool2_byte_size}))
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
    cat $file;
else
    echo \"not found\"
fi";
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

# This checks for free space on the target node.
sub get_partition_data
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_partition_data" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my @disks;
	my $name       = "";
	my $type       = "";
	my $device     = "";
	my $shell_call = "lsblk --all --bytes --noheadings --pairs";
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
		$conf->{node}{$node}{disk}{$disk}{partition_count} = 0;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0003", message_variables => {
			name1 => "node",                                          value1 => $node,
			name2 => "disk",                                          value2 => $disk,
			name3 => "node::${node}::disk::${disk}::partition_count", value3 => $conf->{node}{$node}{disk}{$disk}{partition_count},
		}, file => $THIS_FILE, line => __LINE__});
		
		my $shell_call = "
if [ ! -e /sbin/parted ]; 
then 
    yum --quiet -y install parted;
    if [ ! -e /sbin/parted ]; 
    then 
        echo parted not installed
    else
        echo parted installed;
        parted /dev/$disk unit B print free;
    fi
else
    parted /dev/$disk unit B print free
fi";
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
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
				name1 => "line", value1 => $line, 
			}, file => $THIS_FILE, line => __LINE__});
			
			if ($line eq "parted not installed")
			{
				$device = "--";
				print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
					message	=>	"#!string!message_0368!#",
					row	=>	"#!string!state_0042!#",
				});
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
				$conf->{node}{$node}{disk}{$disk}{size} = $1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node}::disk::${disk}::size", value1 => $conf->{node}{$node}{disk}{$disk}{size},
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /Partition Table: (.*)/)
			{
				$conf->{node}{$node}{disk}{$disk}{label} = $1;
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "node::${node}::disk::${disk}::label", value1 => $conf->{node}{$node}{disk}{$disk}{label},
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
				$conf->{node}{$node}{disk}{$disk}{partition}{$partition}{start} = $partition_start;
				$conf->{node}{$node}{disk}{$disk}{partition}{$partition}{end}   = $partition_end;
				$conf->{node}{$node}{disk}{$disk}{partition}{$partition}{size}  = $partition_size;
				$conf->{node}{$node}{disk}{$disk}{partition}{$partition}{type}  = $partition_type;
				$conf->{node}{$node}{disk}{$disk}{partition_count}++;
				# For our logs...
				my $say_partition_start = $an->Readable->bytes_to_hr({'bytes' => $conf->{node}{$node}{disk}{$disk}{partition}{$partition}{start}});
				my $say_partition_end   = $an->Readable->bytes_to_hr({'bytes' => $conf->{node}{$node}{disk}{$disk}{partition}{$partition}{end}});
				my $say_partition_size  = $an->Readable->bytes_to_hr({'bytes' => $conf->{node}{$node}{disk}{$disk}{partition}{$partition}{size}});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0011", message_variables => {
					name1  => "node",                                          value1  => $node,
					name2  => "disk",                                          value2  => $disk,
					name3  => "partition",                                     value3  => $partition,
					name4  => "start",                                         value4  => $conf->{node}{$node}{disk}{$disk}{partition}{$partition}{start},
					name5  => "end",                                           value5  => $conf->{node}{$node}{disk}{$disk}{partition}{$partition}{end},
					name6  => "size",                                          value6  => $conf->{node}{$node}{disk}{$disk}{partition}{$partition}{size},
					name7  => "type",                                          value7  => $conf->{node}{$node}{disk}{$disk}{partition}{$partition}{type},
					name8  => "node::${node}::disk::${disk}::partition_count", value8  => $conf->{node}{$node}{disk}{$disk}{partition_count},
					name9  => "say_partition_start",                           value9  => $say_partition_start,
					name10 => "say_partition_end",                             value10 => $say_partition_end,
					name11 => "say_partition_size",                            value11 => $say_partition_size,
				}, file => $THIS_FILE, line => __LINE__});
			}
			elsif ($line =~ /^(\d+)B (\d+)B (\d+)B Free Space/)
			{
				# If there was some space left because of
				# optimal alignment, it will be overwritten.
				my $free_space_start  = $1;
				my $free_space_end    = $2;
				my $free_space_size   = $3;
				$conf->{node}{$node}{disk}{$disk}{free_space}{start} = $free_space_start;
				$conf->{node}{$node}{disk}{$disk}{free_space}{end}   = $free_space_end;
				$conf->{node}{$node}{disk}{$disk}{free_space}{size}  = $free_space_size;
				# For our logs...
				my $say_free_space_start = $an->Readable->bytes_to_hr({'bytes' => $conf->{node}{$node}{disk}{$disk}{free_space}{start}});
				my $say_free_space_end   = $an->Readable->bytes_to_hr({'bytes' => $conf->{node}{$node}{disk}{$disk}{free_space}{end}});
				my $say_free_space_size  = $an->Readable->bytes_to_hr({'bytes' => $conf->{node}{$node}{disk}{$disk}{free_space}{size}});
				$an->Log->entry({log_level => 2, message_key => "an_variables_0008", message_variables => {
					name1 => "node",                                            value1 => $node,
					name2 => "disk",                                            value2 => $disk,
					name3 => "node::${node}::disk::${disk}::free_space::start", value3 => $conf->{node}{$node}{disk}{$disk}{free_space}{start},
					name4 => "node::${node}::disk::${disk}::free_space::end",   value4 => $conf->{node}{$node}{disk}{$disk}{free_space}{end},
					name5 => "node::${node}::disk::${disk}::free_space::size",  value5 => $conf->{node}{$node}{disk}{$disk}{free_space}{size},
					name6 => "say_free_space_start",                            value6 => $say_free_space_start,
					name7 => "say_free_space_end",                              value7 => $say_free_space_end,
					name8 => "say_free_space_size",                             value8 => $say_free_space_size,
				}, file => $THIS_FILE, line => __LINE__});
			}
		}
	}
	
	# Find which disk is bigger
	my $biggest_disk = "";
	my $biggest_size = 0;
	foreach my $disk (sort {$a cmp $b} keys %{$conf->{node}{$node}{disk}})
	{
		my $size = $conf->{node}{$node}{disk}{$disk}{size};
		if ($size > $biggest_size)
		{
			   $biggest_disk                      = $disk;
			   $biggest_size                      = $size;
			my $say_biggest_size                  = $an->Readable->bytes_to_hr({'bytes' => $biggest_size});
			   $conf->{node}{$node}{biggest_disk} = $biggest_disk;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0004", message_variables => {
				name1 => "node",                        value1 => $node,
				name2 => "biggest_disk",                value2 => $biggest_disk,
				name3 => "biggest_size",                value3 => $biggest_size,
				name4 => "node::${node}::biggest_disk", value4 => $conf->{node}{$node}{biggest_disk},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node",         value1 => $node,
		name2 => "biggest_disk", value2 => $biggest_disk,
	}, file => $THIS_FILE, line => __LINE__});
	return($biggest_disk);
}

# This generates the default 'cluster.conf' file.
sub generate_cluster_conf
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "generate_cluster_conf" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my ($node1_short_name) = ($conf->{cgi}{anvil_node1_name} =~ /^(.*?)\./);
	my  $node1_full_name   =  $conf->{cgi}{anvil_node1_name};
	my ($node2_short_name) = ($conf->{cgi}{anvil_node2_name} =~ /^(.*?)\./);
	my  $node2_full_name   =  $conf->{cgi}{anvil_node2_name};
	my  $shared_lv         = "/dev/${node1_short_name}_vg0/shared";
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
	$conf->{sys}{cluster_conf} = "<?xml version=\"1.0\"?>
<cluster name=\"$conf->{cgi}{anvil_name}\" config_version=\"1\">
	<cman expected_votes=\"1\" two_node=\"1\" transport=\"udpu\" />
	<clusternodes>
		<clusternode name=\"$conf->{cgi}{anvil_node1_name}\" nodeid=\"1\">
			<altname name=\"${node1_short_name}.sn\" />
			<fence>\n";
	# Fence methods for node 1
	foreach my $i (sort {$a cmp $b} keys %{$conf->{fence}{node}{$node1_full_name}{order}})
	{
		foreach my $method (keys %{$conf->{fence}{node}{$node1_full_name}{order}{$i}{method}})
		{
			$conf->{sys}{cluster_conf} .= "\t\t\t\t<method name=\"$method\">\n";
			
			# Count how many devices we have.
			my $device_count = 0;
			foreach my $j (keys %{$conf->{fence}{node}{$node1_full_name}{order}{$i}{method}{$method}{device}})
			{
				$device_count++;
			}
			
			# If there are multiple methods, we need to say 'off', then additional entries for 
			# 'on'. Otherwise, 'reboot' is fine.
			if ($device_count == 1)
			{
				# Reboot.
				foreach my $j (keys %{$conf->{fence}{node}{$node1_full_name}{order}{$i}{method}{$method}{device}})
				{
					$conf->{sys}{cluster_conf} .= "\t\t\t\t\t$conf->{fence}{node}{$node1_full_name}{order}{$i}{method}{$method}{device}{$j}{string}\n";
				}
			}
			else
			{
				# Off
				foreach my $j (keys %{$conf->{fence}{node}{$node1_full_name}{order}{$i}{method}{$method}{device}})
				{
					my $say_string =  $conf->{fence}{node}{$node1_full_name}{order}{$i}{method}{$method}{device}{$j}{string};
					   $say_string =~ s/reboot/off/;
					$conf->{sys}{cluster_conf} .= "\t\t\t\t\t$say_string\n";
				}
				# On
				foreach my $j (keys %{$conf->{fence}{node}{$node1_full_name}{order}{$i}{method}{$method}{device}})
				{
					my $say_string =  $conf->{fence}{node}{$node1_full_name}{order}{$i}{method}{$method}{device}{$j}{string};
					   $say_string =~ s/reboot/on/;
					$conf->{sys}{cluster_conf} .= "\t\t\t\t\t$say_string\n";
				}
			}
			$conf->{sys}{cluster_conf} .= "\t\t\t\t</method>\n";
		}
	}
	$conf->{sys}{cluster_conf} .= "\t\t\t</fence>
		</clusternode>
		<clusternode name=\"$conf->{cgi}{anvil_node2_name}\" nodeid=\"2\">
			<altname name=\"${node2_short_name}.sn\" />
			<fence>\n";
	# Fence methods for node 2
	foreach my $i (sort {$a cmp $b} keys %{$conf->{fence}{node}{$node2_full_name}{order}})
	{
		foreach my $method (keys %{$conf->{fence}{node}{$node2_full_name}{order}{$i}{method}})
		{
			$conf->{sys}{cluster_conf} .= "\t\t\t\t<method name=\"$method\">\n";
			
			# Count how many devices we have.
			my $device_count = 0;
			foreach my $j (keys %{$conf->{fence}{node}{$node2_full_name}{order}{$i}{method}{$method}{device}})
			{
				$device_count++;
			}
			
			# If there are multiple methods, we need to say 'off', then additional entries for 
			# 'on'. Otherwise, 'reboot' is fine.
			if ($device_count == 1)
			{
				# Reboot.
				foreach my $j (keys %{$conf->{fence}{node}{$node2_full_name}{order}{$i}{method}{$method}{device}})
				{
					$conf->{sys}{cluster_conf} .= "\t\t\t\t\t$conf->{fence}{node}{$node2_full_name}{order}{$i}{method}{$method}{device}{$j}{string}\n";
				}
			}
			else
			{
				# Off
				foreach my $j (keys %{$conf->{fence}{node}{$node2_full_name}{order}{$i}{method}{$method}{device}})
				{
					my $say_string =  $conf->{fence}{node}{$node2_full_name}{order}{$i}{method}{$method}{device}{$j}{string};
					   $say_string =~ s/reboot/off/;
					$conf->{sys}{cluster_conf} .= "\t\t\t\t\t$say_string\n";
				}
				# On
				foreach my $j (keys %{$conf->{fence}{node}{$node2_full_name}{order}{$i}{method}{$method}{device}})
				{
					my $say_string =  $conf->{fence}{node}{$node2_full_name}{order}{$i}{method}{$method}{device}{$j}{string};
					   $say_string =~ s/reboot/on/;
					$conf->{sys}{cluster_conf} .= "\t\t\t\t\t$say_string\n";
				}
			}
			$conf->{sys}{cluster_conf} .= "\t\t\t\t</method>\n";
		}
	}
	$conf->{sys}{cluster_conf} .= "\t\t\t</fence>
		</clusternode>
	</clusternodes>
	<fencedevices>\n";
	foreach my $device (sort {$a cmp $b} keys %{$conf->{fence}{device}})
	{
		foreach my $name (sort {$a cmp $b} keys %{$conf->{fence}{device}{$device}{name}})
		{
			$conf->{sys}{cluster_conf} .= "\t\t$conf->{fence}{device}{$device}{name}{$name}{string}\n";
		}
	}
	$conf->{sys}{cluster_conf} .= "\t</fencedevices>
	<fence_daemon post_join_delay=\"$conf->{sys}{post_join_delay}\" />
	<totem rrp_mode=\"passive\" secauth=\"off\"/>
	<rm log_level=\"5\">
		<resources>
			<script file=\"/etc/init.d/drbd\" name=\"drbd\"/>
			<script file=\"/etc/init.d/wait-for-drbd\" name=\"wait-for-drbd\"/>
			<script file=\"/etc/init.d/clvmd\" name=\"clvmd\"/>
			<clusterfs device=\"$shared_lv\" force_unmount=\"1\" fstype=\"gfs2\" mountpoint=\"/shared\" name=\"sharedfs\" />
			<script file=\"/etc/init.d/libvirtd\" name=\"libvirtd\"/>
		</resources>
		<failoverdomains>
			<failoverdomain name=\"only_n01\" nofailback=\"1\" ordered=\"0\" restricted=\"1\">
				<failoverdomainnode name=\"$conf->{cgi}{anvil_node1_name}\"/>
			</failoverdomain>
			<failoverdomain name=\"only_n02\" nofailback=\"1\" ordered=\"0\" restricted=\"1\">
				<failoverdomainnode name=\"$conf->{cgi}{anvil_node2_name}\"/>
			</failoverdomain>
			<failoverdomain name=\"primary_n01\" nofailback=\"1\" ordered=\"1\" restricted=\"1\">
				<failoverdomainnode name=\"$conf->{cgi}{anvil_node1_name}\" priority=\"1\"/>
				<failoverdomainnode name=\"$conf->{cgi}{anvil_node2_name}\" priority=\"2\"/>
			</failoverdomain>
			<failoverdomain name=\"primary_n02\" nofailback=\"1\" ordered=\"1\" restricted=\"1\">
				<failoverdomainnode name=\"$conf->{cgi}{anvil_node1_name}\" priority=\"2\"/>
				<failoverdomainnode name=\"$conf->{cgi}{anvil_node2_name}\" priority=\"1\"/>
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
		name1 => "sys::cluster_conf", value1 => $conf->{sys}{cluster_conf},
	}, file => $THIS_FILE, line => __LINE__});
	return(0);
}

# This checks to see if /etc/cluster/cluster.conf is available and aborts if so.
sub configure_cman
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "configure_cman" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	# Generate a new cluster.conf, then check to see if one already exists.
	generate_cluster_conf($conf);
	my ($node1_cluster_conf_version) = read_cluster_conf($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_cluster_conf_version) = read_cluster_conf($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_cluster_conf_version", value1 => $node1_cluster_conf_version,
		name2 => "node2_cluster_conf_version", value2 => $node2_cluster_conf_version,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If one of the nodes has an existing cluster.conf, use it.
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	my $ok    = 1;
	
	# This will set if a node's cluster.conf is (re)written or not.
	my $write_node1 = 0;
	my $write_node2 = 0;
	
	# If either node's cluster.conf in > 1, use it.
	$an->Log->entry({log_level => 2, message_key => "log_0206", file => $THIS_FILE, line => __LINE__});
	if ($node1_cluster_conf_version > 1)
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
			$conf->{node}{$node2}{cluster_conf} = $conf->{node}{$node1}{cluster_conf};
			$write_node2                        = 1;
		}
		elsif ($node1_cluster_conf_version < $node2_cluster_conf_version)
		{
			# Node 2 is newer
			$an->Log->entry({log_level => 2, message_key => "log_0209", message_variables => {
				newer => "2", 
				older => "1", 
			}, file => $THIS_FILE, line => __LINE__});
			$conf->{node}{$node1}{cluster_conf} = $conf->{node}{$node2}{cluster_conf};
			$write_node1                        = 1;
		}
	}
	elsif ($node2_cluster_conf_version > 1)
	{
		# Node 2's version is >1 while node 1's isn't, so use node 2.
		$an->Log->entry({log_level => 2, message_key => "log_0209", message_variables => {
			newer => "2 (v. $node2_cluster_conf_version)", 
			older => "1 (v. $node1_cluster_conf_version)", 
		}, file => $THIS_FILE, line => __LINE__});
		$conf->{node}{$node1}{cluster_conf} = $conf->{node}{$node2}{cluster_conf};
		$write_node1                        = 1;
	}
	elsif ((not $conf->{node}{$node1}{cluster_conf}) && (not $conf->{node}{$node2}{cluster_conf}))
	{
		# Neither node has an existing cluster.conf, using the default generated one.
		$an->Log->entry({log_level => 2, message_key => "log_0210", file => $THIS_FILE, line => __LINE__});
		$conf->{node}{$node1}{cluster_conf} = $conf->{sys}{cluster_conf};
		$conf->{node}{$node2}{cluster_conf} = $conf->{sys}{cluster_conf};
		$write_node1                        = 1;
		$write_node2                        = 1;
	}
	elsif ($conf->{node}{$node1}{cluster_conf})
	{
		# Node 1 has a cluster.conf, node 2 doesn't.
		$an->Log->entry({log_level => 2, message_key => "log_0211", message_variables => {
			newer => "1", 
			older => "2", 
		}, file => $THIS_FILE, line => __LINE__});
		$conf->{node}{$node2}{cluster_conf} = $conf->{node}{$node1}{cluster_conf};
		$write_node2                        = 1;
	}
	elsif ($conf->{node}{$node2}{cluster_conf})
	{
		# Node 2 has a cluster.conf, node 1 doesn't.
		$an->Log->entry({log_level => 2, message_key => "log_0211", message_variables => {
			newer => "2", 
			older => "1", 
		}, file => $THIS_FILE, line => __LINE__});
		$conf->{node}{$node1}{cluster_conf} = $conf->{node}{$node2}{cluster_conf};
		$write_node1                        = 1;
	}
	else
	{
		# wat
		$an->Log->entry({log_level => 2, message_key => "log_0212", message_variables => {
			newer => "2", 
			older => "1", 
		}, file => $THIS_FILE, line => __LINE__});
		$ok = 2;
	}
	
	# Write them out now.
	my $node1_rc             = "";
	my $node1_return_message = "";
	my $node2_rc             = "";
	my $node2_return_message = "";
	if ($ok eq "1")
	{
		if ($write_node1)
		{
			($node1_rc, $node1_return_message) = write_cluster_conf($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
		}
		if ($write_node2)
		{
			($node2_rc, $node2_return_message) = write_cluster_conf($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
		}
		# 0 = Written and validated
		# 1 = ccs_config_validate failed
	}
	
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0028!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0028!#";
	if ($ok eq "2")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0098!#";
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0098!#";
		$ok            = 0;
	}
	else
	{
		if ($node1_rc eq "1")
		{
			$node1_class   = "highlight_warning_bold";
			$node1_message = AN::Common::get_string($conf, {key => "state_0076", variables => { message => "$node1_return_message" }});
			$ok            = 0;
		}
		elsif ($write_node1)
		{
			$node1_message = "#!string!state_0029!#";
		}
		if ($node2_rc eq "1")
		{
			$node2_class   = "highlight_warning_bold";
			$node2_message = AN::Common::get_string($conf, {key => "state_0076", variables => { message => "$node2_return_message" }});
			$ok            = 0;
		}
		elsif ($write_node2)
		{
			$node2_message = "#!string!state_0029!#";
		}
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0221!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	if (not $ok)
	{
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed", {
			message		=>	"#!string!message_0363!#",
		});
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "ok", value1 => $ok,
	}, file => $THIS_FILE, line => __LINE__});
	return($ok);
}

# This writes out the cluster configuration file
sub write_cluster_conf
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "write_cluster_conf" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $message     = "";
	my $return_code = 255;
	my $shell_call  =  "cat > $conf->{path}{nodes}{cluster_conf} << EOF\n";
	   $shell_call  .= "$conf->{node}{$node}{cluster_conf}\n";
	   $shell_call  .= "EOF\n";
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
	}
	
	# Now run 'ccs_config_validate' to ensure it is sane.
	$shell_call  = "ccs_config_validate; echo rc:\$?";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
		name2 => "node",       value2 => $node,
	}, file => $THIS_FILE, line => __LINE__});
	($error, $ssh_fh, $return) = $an->Remote->remote_call({
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
		
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			if ($rc eq "0")
			{
				# Validated
				$return_code = 0;
			}
			elsif ($rc eq "3")
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

# This reads in /etc/cluster/cluster.conf and returns '0' if not found.
sub read_cluster_conf
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "read_cluster_conf" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Later, this will use XML::Simple to parse the contents. For now, I only care if the file exists at 
	# all.
	$conf->{node}{$node}{cluster_conf_version} = 0;
	$conf->{node}{$node}{cluster_conf}         = "";
	my $shell_call = "
if [ -e '$conf->{path}{nodes}{cluster_conf}' ]
then
    cat $conf->{path}{nodes}{cluster_conf}
else
    echo not found
fi";
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
		
		last if $line eq "not found";
		$conf->{node}{$node}{cluster_conf} .= "$line\n";
		
		# If the version is > 1, we'll use it no matter what.
		if ($line =~ /config_version="(\d+)"/)
		{
			$conf->{node}{$node}{cluster_conf_version} = $1;
			$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
				name1 => "node",                 value1 => $node,
				name2 => "cluster.conf version", value2 => $conf->{node}{$node}{cluster_conf_version},
			}, file => $THIS_FILE, line => __LINE__});
		}
	}
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "cluster.conf version", value1 => $conf->{node}{$node}{cluster_conf_version},
	}, file => $THIS_FILE, line => __LINE__});
	return($conf->{node}{$node}{cluster_conf_version})
}

# This checks to make sure both nodes have a compatible OS installed.
sub verify_os
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "verify_os" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $ok = 1;
	my ($node1_major_version, $node1_minor_version) = get_node_os_version($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_major_version, $node2_minor_version) = get_node_os_version($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	$node1_major_version = 0 if not defined $node1_major_version;
	$node1_minor_version = 0 if not defined $node1_minor_version;
	$node2_major_version = 0 if not defined $node2_major_version;
	$node2_minor_version = 0 if not defined $node2_minor_version;
	
	my $say_node1_os = $conf->{node}{$node1}{os}{brand} =~ /Red Hat Enterprise Linux Server/ ? "RHEL" : $conf->{node}{$node1}{os}{brand};
	my $say_node2_os = $conf->{node}{$node2}{os}{brand} =~ /Red Hat Enterprise Linux Server/ ? "RHEL" : $conf->{node}{$node2}{os}{brand};
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "$say_node1_os $conf->{node}{$node1}{os}{version}";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "$say_node2_os $conf->{node}{$node2}{os}{version}";
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
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0220!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	if (not $ok)
	{
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed", {
			message		=>	"#!string!message_0362!#",
		});
	}
	
	return($ok);
}

# This calls the specified node and (tries to) read and parse '/etc/redhat-release'
sub get_node_os_version
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_node_os_version" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $brand      = "";
	my $major      = 0;
	my $minor      = 0;
	my $shell_call = "cat /etc/redhat-release";
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
			$conf->{node}{$node}{os}{brand}   = $brand;
			$conf->{node}{$node}{os}{version} = "$major.$minor";
		}
	}
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "node",  value1 => $node,
		name2 => "major", value2 => $major,
		name3 => "minor", value3 => $minor,
	}, file => $THIS_FILE, line => __LINE__});
	
	# If it's RHEL, see if it's registered.
	if ($conf->{node}{$node}{os}{brand} =~ /Red Hat Enterprise Linux Server/i)
	{
		# See if it's been registered already.
		$conf->{node}{$node}{os}{registered} = 0;
		my $shell_call = "rhn_check; echo exit:\$?";
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
			
			if ($line =~ /^exit:(\d+)$/)
			{
				my $rc = $1;
				if ($rc eq "0")
				{
					$conf->{node}{$node}{os}{registered} = 1;
				}
			}
		}
		$an->Log->entry({log_level => 2, message_key => "log_0213", message_variables => {
			node => $node, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	return($major, $minor);
}

# This makes sure we have access to both nodes.
sub check_connection
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_connection" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my ($node1_access) = check_node_access($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_access) = check_node_access($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
		name1 => "node1_access", value1 => $node1_access,
		name2 => "node2_access", value2 => $node2_access,
	}, file => $THIS_FILE, line => __LINE__});
	
	my $node1_class   = "highlight_good_bold";
	my $node1_message = AN::Common::get_string($conf, {key => "state_0017"});
	my $node2_class   = "highlight_good_bold";
	my $node2_message = AN::Common::get_string($conf, {key => "state_0017"});
	if (not $node1_access)
	{
		$node1_class   = "highlight_bad_bold";
		$node1_message = AN::Common::get_string($conf, {key => "state_0018"});
	}
	if (not $node2_access)
	{
		$node2_class   = "highlight_bad_bold";
		$node2_message = AN::Common::get_string($conf, {key => "state_0018"});
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0219!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	my $access = 1;
	if ((not $node1_access) || (not $node2_access))
	{
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed", {
			message		=>	"#!string!message_0361!#",
		});
		$access = 0;
		
		# Copy the tools the nodes will need into docroot and update
		# the URLs we will tell the nodes to download from.
		#copy_tools_to_docroot($conf);
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "access", value1 => $access,
	}, file => $THIS_FILE, line => __LINE__});
	return($access);
}

# This does nothing more than call 'echo 1' to see if the target is reachable.
sub check_node_access
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_node_access" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $access     = 0;
	my $shell_call = "echo 1";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0002", message_variables => {
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
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line, 
		}, file => $THIS_FILE, line => __LINE__});
	}
	$conf->{node}{$node}{ssh_fh} = $ssh_fh;
	$access = $return->[0] ? $return->[0] : 0;
 	$an->Log->entry({log_level => 2, message_key => "an_variables_0002", message_variables => {
 		name1 => "node",   value1 => $node,
 		name2 => "access", value2 => $access,
 	}, file => $THIS_FILE, line => __LINE__});
	
	return($access);
}

1;
