package AN::InstallManifest;

#
# This contains functions related to configuring node(s) via the Install
# Manifest tool.
# 
# Note: 
# * All remote calls set the port to '22', but this will be overridden if the
#   node name ends in :xx
# 

use strict;
use warnings;

use AN::Cluster;
use AN::Common;

# Set static variables.
my $THIS_FILE = "AN::InstallManifest.pm";

# This runs the install manifest against both nodes.
sub run_new_install_manifest
{
	my ($conf) = @_;
	
	print AN::Common::template($conf, "common.html", "scanning-message");
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-header");
	
	# Some variables we'll need.
	$conf->{packages}{to_install} = {
		apcupsd				=>	0,
		acpid				=>	0,
		'bridge-utils'			=>	0,
		ccs				=>	0,
		cman 				=>	0,
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
		gd				=>	0,
		'gfs2-utils'			=>	0,
		gpm				=>	0,
		ipmitool			=>	0,
		'kmod-drbd84'			=>	0,
		libvirt				=>	0,
		'lvm2-cluster'			=>	0,
		man				=>	0,
		mlocate				=>	0,
		ntp				=>	0,
		OpenIPMI			=>	0,
		'OpenIPMI-libs'			=>	0,
		'openssh-clients'		=>	0,
		'openssl-devel'			=>	0,
		'qemu-kvm'			=>	0,
		'qemu-kvm-tools'		=>	0,
		parted				=>	0,
		perl				=>	0,
		'perl-TermReadKey'		=>	0,
		'perl-Time-HiRes'		=>	0,
		'perl-Net-SSH2'			=>	0,
		'perl-XML-Simple'		=>	0,
		'policycoreutils-python'	=>	0,
		postfix				=>	0,
		'python-virtinst'		=>	0,
		rgmanager			=>	0,
		ricci				=>	0,
		rsync				=>	0,
		screen				=>	0,
		syslinux			=>	0,
		'vim-enhanced'			=>	0,
		'virt-viewer'			=>	0,
		wget				=>	0,
		
		# These should be more selectively installed based on lspci (or
		# similar) output.
		MegaCli				=>	0,
	};
	$conf->{url}{'anvil-map-network'}  = "https://raw.githubusercontent.com/digimer/striker/master/tools/anvil-map-network";
	$conf->{path}{'anvil-map-network'} = "/root/anvil-map-network";
	
	# Make sure we can log into both nodes.
	check_connection($conf) or return(1);
	
	# Make sure both nodes are EL6 nodes.
	verify_os($conf) or return(1);
	
	# Make sure there isn't already a running cluster
	verify_node_is_not_in_a_cluster($conf) or return(1);
	
	# Make sure both nodes can get online. We'll try to install even
	# without Internet access.
	verify_internet_access($conf);
	
	# Make sure both nodes have the same amount of free space.
	verify_matching_free_space($conf) or return(1);
	
	# Get a map of the physical network interfaces for later remapping to
	# device names.
	my ($node1_remap_required, $node2_remap_required) = map_network($conf);
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_remap_required: [$node1_remap_required], node2_remap_required: [$node2_remap_required].\n");
	
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_rc: [$node1_rc], node2_rc: [$node2_rc].\n");
	if (($node1_rc) || ($node2_rc))
	{
		# Something went wrong
		if (($node1_rc eq "4") || ($node2_rc eq "4"))
		{
			# Not enough NICs (or remap program failure)
			print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed", {
				message		=>	"#!string!message_0380!#",
			});
		}
		if (($node1_rc eq "7") || ($node2_rc eq "7"))
		{
			# Didn't recognize the node
			print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed", {
				message		=>	"#!string!message_0383!#",
			});
		}
		if (($node1_rc eq "8") || ($node2_rc eq "8"))
		{
			# SSH handle didn't exist, though it should have.
			print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed", {
				message		=>	"#!string!message_0382!#",
			});
		}
		if (($node1_rc eq "9") || ($node2_rc eq "9"))
		{
			# Failed to download the anvil-map-network script
			print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed", {
				message		=>	"#!string!message_0381!#",
			});
		}
		print AN::Common::template($conf, "install-manifest.html", "close-table");
		return(1);
	}
	
	if (not $conf->{cgi}{perform_install})
	{
		# Now summarize and ask the user to confirm.
		summarize_build_plan($conf);
		
		# Now ask the user to confirm the storage and networm mapping. If the
		# OS is 'Red Hat Enterprise Linux Server' and it is unregistered,
		# provide input fields for RHN registration.
		### if (not $conf->{node}{$node1}{os}{registered})...
		return(0);
	}
	
	# If we're here, we're ready to start!
	print AN::Common::template($conf, "install-manifest.html", "sanity-checks-complete");
	
	# Configure the network
	configure_network($conf);
	
	# Add the an-repo
	add_an_repo($conf);
	
	# Install needed RPMs.
	install_programs($conf) or return(1);
	
	# Update the OS on each node.
	update_nodes($conf);
	
	### TODO: Break here and ask the user to confirm the storage and
	###       network configuration before actually rewriting the network
	###       config and partitioning the drive.
	
	# If a reboot is needed, now is the time to do it.
	foreach my $node ($conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node2_current_ip})
	{
		if ($conf->{node}{$node}{reboot_needed})
		{
			# Reboot...
		}
	}
	
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-footer");
	
	return(0);
}

# This summarizes the install plan and gives the use a chance to tweak it or
# re-run the cable mapping.
sub summarize_build_plan
{
	my ($conf) = @_;
	
	my $node1                = $conf->{cgi}{anvil_node1_current_ip};
	my $node2                = $conf->{cgi}{anvil_node2_current_ip};
	my $say_node1_registered = "#!string!message_0376!#";
	my $say_node2_registered = "#!string!message_0376!#";
	my $say_node1_class      = "highlight_detail";
	my $say_node2_class      = "highlight_detail";
	my $enable_rhn           = 0;
	if ($conf->{node}{$node1}{os}{brand} =~ /Red Hat Enterprise Linux Server/)
	{
		# See if it's been registered already.
		if ($conf->{node}{$node1}{os}{registered})
		{
			# Already registered.
			$say_node1_registered = "#!string!message_0377!#";
			$say_node1_class      = "highlight_good";
		}
		else
		{
			# Registration required, but do we have internet
			# access?
			if ($conf->{node}{$node1}{internet})
			{
				# We're good.
				$say_node1_registered = "#!string!message_0378!#";
				$say_node1_class      = "highlight_warning";
				$enable_rhn           = 1;
			}
			else
			{
				# Lets hope they have the DVD image...
				$say_node1_registered = "#!string!message_0379!#";
				$say_node1_class      = "highlight_warning";
			}
		}
	}
	if ($conf->{node}{$node2}{os}{brand} =~ /Red Hat Enterprise Linux Server/)
	{
		# See if it's been registered already.
		if ($conf->{node}{$node2}{os}{registered})
		{
			# Already registered.
			$say_node2_registered = "#!string!message_0377!#";
			$say_node2_class      = "highlight_good";
		}
		else
		{
			# Registration required, but do we have internet
			# access?
			if ($conf->{node}{$node2}{internet})
			{
				# We're good.
				$say_node2_registered = "#!string!message_0378!#";
				$say_node2_class      = "highlight_warning";
				$enable_rhn           = 1;
			}
			else
			{
				# Lets hope they have the DVD image...
				$say_node2_registered = "#!string!message_0379!#";
				$say_node2_class      = "highlight_warning";
			}
		}
	}
	
	my $say_node1_os = $conf->{node}{$node1}{os}{brand} =~ /Red Hat Enterprise Linux Server/ ? "RHEL" : $conf->{node}{$node1}{os}{brand};
	my $say_node2_os = $conf->{node}{$node2}{os}{brand} =~ /Red Hat Enterprise Linux Server/ ? "RHEL" : $conf->{node}{$node2}{os}{brand};
	my $rhn_template = "";
	if ($enable_rhn)
	{
		$rhn_template = AN::Common::template($conf, "install-manifest.html", "rhn-credential-form", {
			rhn_user	=>	$conf->{cgi}{rhn_user},
			rhn_password	=>	$conf->{cgi}{rhn_password},
		});
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1: [$node1], node2: [$node2].\n");
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1: [$node1]: bcn-link1: [$conf->{conf}{node1}{$node1}{set_nic}{'bcn-link1'}], bcn-link2: [$conf->{conf}{node1}{$node1}{set_nic}{'bcn-link2'}], sn-link1: [$conf->{conf}{node1}{$node1}{set_nic}{'sn-link1'}], sn-link2: [$conf->{conf}{node1}{$node1}{set_nic}{'sn-link2'}], ifn-link1: [$conf->{conf}{node1}{$node1}{set_nic}{'ifn-link1'}], ifn-link2: [$conf->{conf}{node1}{$node1}{set_nic}{'ifn-link2'}]\n");
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node2: [$node2]: bcn-link1: [$conf->{conf}{node2}{$node2}{set_nic}{'bcn-link1'}], bcn-link2: [$conf->{conf}{node2}{$node2}{set_nic}{'bcn-link2'}], sn-link1: [$conf->{conf}{node2}{$node2}{set_nic}{'sn-link1'}], sn-link2: [$conf->{conf}{node2}{$node2}{set_nic}{'sn-link2'}], ifn-link1: [$conf->{conf}{node2}{$node2}{set_nic}{'ifn-link1'}], ifn-link2: [$conf->{conf}{node2}{$node2}{set_nic}{'ifn-link2'}]\n");
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-summary-and-confirm", {
		form_file			=>	"/cgi-bin/striker",
		title				=>	"#!string!title_0177!#",
		bcn_link1_name			=>	AN::Common::get_string($conf, {key => "script_0059", variables => { number => "1" }}),
		bcn_link1_node1_mac		=>	$conf->{conf}{node}{$node1}{set_nic}{'bcn-link1'},
		bcn_link1_node2_mac		=>	$conf->{conf}{node}{$node2}{set_nic}{'bcn-link1'},
		bcn_link2_name			=>	AN::Common::get_string($conf, {key => "script_0059", variables => { number => "2" }}),
		bcn_link2_node1_mac		=>	$conf->{conf}{node}{$node1}{set_nic}{'bcn-link2'},
		bcn_link2_node2_mac		=>	$conf->{conf}{node}{$node2}{set_nic}{'bcn-link2'},
		sn_link1_name			=>	AN::Common::get_string($conf, {key => "script_0061", variables => { number => "1" }}),
		sn_link1_node1_mac		=>	$conf->{conf}{node}{$node1}{set_nic}{'sn-link1'},
		sn_link1_node2_mac		=>	$conf->{conf}{node}{$node2}{set_nic}{'sn-link1'},
		sn_link2_name			=>	AN::Common::get_string($conf, {key => "script_0061", variables => { number => "2" }}),
		sn_link2_node1_mac		=>	$conf->{conf}{node}{$node1}{set_nic}{'sn-link2'},
		sn_link2_node2_mac		=>	$conf->{conf}{node}{$node2}{set_nic}{'sn-link2'},
		ifn_link1_name			=>	AN::Common::get_string($conf, {key => "script_0063", variables => { number => "1" }}),
		ifn_link1_node1_mac		=>	$conf->{conf}{node}{$node1}{set_nic}{'ifn-link1'},
		ifn_link1_node2_mac		=>	$conf->{conf}{node}{$node2}{set_nic}{'ifn-link1'},
		ifn_link2_name			=>	AN::Common::get_string($conf, {key => "script_0063", variables => { number => "2" }}),
		ifn_link2_node1_mac		=>	$conf->{conf}{node}{$node1}{set_nic}{'ifn-link2'},
		ifn_link2_node2_mac		=>	$conf->{conf}{node}{$node2}{set_nic}{'ifn-link2'},
		media_library_size		=>	AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_media_library_byte_size}),
		pool1_size			=>	AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}),
		pool2_size			=>	AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}),
		partition1_size			=>	AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_partition_1_byte_size}),
		partition2_size			=>	AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_partition_2_byte_size}),
		edit_manifest_url		=>	"?config=true&task=create-install-manifest&load=$conf->{cgi}{run}",   
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
		rhn_template			=>	$rhn_template,
	});
	
	return(0);
}

# This downloads and runs the 'anvil-configure-network' script
sub configure_network_on_node
{
	my ($conf, $node, $password) = @_;
	
	# Here we're going to write out all the network and udev configuration
	# details per node.
	
	
	
	print "<pre>\n";
	
	
	print "</pre>\n";
	
	return(0);
}

# This configures the network.
sub configure_network
{
	my ($conf) = @_;
	
	my ($node1_rc) = configure_network_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, 0, "#!string!device_0005!#");
	my ($node2_rc) = configure_network_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, 0, "#!string!device_0006!#");
	
	
	return(0);
}

# This parses a line coming back from one of our shell scripts to convert
# string keys and possible variables into the current user's language.
sub parse_script_line
{
	my ($conf, $source, $node, $line) = @_;

	return($line) if $line eq "";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; $source: [$line].\n");
	if ($line =~ /#!exit!(.*?)!#/)
	{
		# Program exited, reboot?
		my $reboot = $1;
		$conf->{node}{$node}{reboot_needed} = $reboot eq "reboot" ? 1 : 0;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node}::reboot_needed: [$conf->{node}{$node}{reboot_needed}].\n");
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
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line].\n");
	#$line .= "<br />\n";
	
	return($line);
}

# This asks the user to unplug and then plug back in all network interfaces in
# order to map the physical interfaces to MAC addresses.
sub map_network
{
	my ($conf) = @_;
	
	my ($node1_rc) = map_network_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, 0, "#!string!device_0005!#");
	my ($node2_rc) = map_network_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, 0, "#!string!device_0006!#");
	
	# Loop through the MACs seen and see if we've got a match for all
	# already. Of any are missing, we'll need to remap.
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	
	# These will be all populated *if* the MACs seen on each node match
	# MACs passed in fronm CGI (or loaded from manifest). If any are
	# missing, a remap will be needed.
	# Node 1
	$conf->{conf}{node}{$node1}{set_nic}{'bcn-link1'} = "";
	$conf->{conf}{node}{$node1}{set_nic}{'bcn-link2'} = "";
	$conf->{conf}{node}{$node1}{set_nic}{'sn-link1'}  = "";
	$conf->{conf}{node}{$node1}{set_nic}{'sn-link2'}  = "";
	$conf->{conf}{node}{$node1}{set_nic}{'ifn-link1'} = "";
	$conf->{conf}{node}{$node1}{set_nic}{'ifn-link2'} = "";
	# Node 2
	$conf->{conf}{node}{$node2}{set_nic}{'bcn-link1'} = "";
	$conf->{conf}{node}{$node2}{set_nic}{'bcn-link2'} = "";
	$conf->{conf}{node}{$node2}{set_nic}{'sn-link1'}  = "";
	$conf->{conf}{node}{$node2}{set_nic}{'sn-link2'}  = "";
	$conf->{conf}{node}{$node2}{set_nic}{'ifn-link1'} = "";
	$conf->{conf}{node}{$node2}{set_nic}{'ifn-link2'} = "";
	foreach my $nic (sort {$a cmp $b} keys %{$conf->{conf}{node}{$node1}{current_nic}})
	{
		my $mac = $conf->{conf}{node}{$node1}{current_nic}{$nic};
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Checking node1: [$node1]'s: nic: [$nic], mac: [$mac].\n");
		if ($mac eq $conf->{cgi}{anvil_node1_bcn_link1_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{'bcn-link1'} = $mac;
		}
		elsif ($mac eq $conf->{cgi}{anvil_node1_bcn_link2_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{'bcn-link2'} = $mac;
		}
		elsif ($mac eq $conf->{cgi}{anvil_node1_sn_link1_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{'sn-link1'} = $mac;
		}
		elsif ($mac eq $conf->{cgi}{anvil_node1_sn_link2_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{'sn-link2'} = $mac;
		}
		elsif ($mac eq $conf->{cgi}{anvil_node1_ifn_link1_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{'ifn-link1'} = $mac;
		}
		elsif ($mac eq $conf->{cgi}{anvil_node1_ifn_link2_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{'ifn-link2'} = $mac;
		}
		else
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Unrecognized interface; node1: [$node1]: nic: [$nic], mac: [$mac].\n");
		}
	}
	foreach my $nic (sort {$a cmp $b} keys %{$conf->{conf}{node}{$node2}{current_nic}})
	{
		my $mac = $conf->{conf}{node}{$node2}{current_nic}{$nic};
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Checking node2: [$node2]'s: nic: [$nic], mac: [$mac].\n");
		if ($mac eq $conf->{cgi}{anvil_node2_bcn_link1_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{'bcn-link1'} = $mac;
		}
		elsif ($mac eq $conf->{cgi}{anvil_node2_bcn_link2_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{'bcn-link2'} = $mac;
		}
		elsif ($mac eq $conf->{cgi}{anvil_node2_sn_link1_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{'sn-link1'} = $mac;
		}
		elsif ($mac eq $conf->{cgi}{anvil_node2_sn_link2_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{'sn-link2'} = $mac;
		}
		elsif ($mac eq $conf->{cgi}{anvil_node2_ifn_link1_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{'ifn-link1'} = $mac;
		}
		elsif ($mac eq $conf->{cgi}{anvil_node2_ifn_link2_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{'ifn-link2'} = $mac;
		}
		else
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Unrecognized interface; node2: [$node2]: nic: [$nic], mac: [$mac].\n");
		}
	}
	
	# Now determine if a remap is needed.
	my $node1_remap_needed = 0;
	my $node2_remap_needed = 0;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Set node1: [$node1]'s interfaces to; bcn-link1: [$conf->{conf}{node}{$node1}{set_nic}{'bcn-link1'}], bcn-link2: [$conf->{conf}{node}{$node1}{set_nic}{'bcn-link2'}], sn-link1: [$conf->{conf}{node}{$node1}{set_nic}{'sn-link1'}], sn-link2: [$conf->{conf}{node}{$node1}{set_nic}{'sn-link2'}], ifn-link1: [$conf->{conf}{node}{$node1}{set_nic}{'ifn-link1'}], ifn-link2: [$conf->{conf}{node}{$node1}{set_nic}{'ifn-link2'}].\n");
	if ((not $conf->{conf}{node}{$node1}{set_nic}{'bcn-link1'}) || 
	    (not $conf->{conf}{node}{$node1}{set_nic}{'bcn-link2'}) ||
	    (not $conf->{conf}{node}{$node1}{set_nic}{'sn-link1'})  ||
	    (not $conf->{conf}{node}{$node1}{set_nic}{'sn-link2'})  ||
	    (not $conf->{conf}{node}{$node1}{set_nic}{'ifn-link1'}) ||
	    (not $conf->{conf}{node}{$node1}{set_nic}{'ifn-link2'}))
	{
		$node1_remap_needed = 1;
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Set node2: [$node2]'s interfaces to; bcn-link1: [$conf->{conf}{node}{$node2}{set_nic}{'bcn-link1'}], bcn-link2: [$conf->{conf}{node}{$node2}{set_nic}{'bcn-link2'}], sn-link1: [$conf->{conf}{node}{$node2}{set_nic}{'sn-link1'}], sn-link2: [$conf->{conf}{node}{$node2}{set_nic}{'sn-link2'}], ifn-link1: [$conf->{conf}{node}{$node2}{set_nic}{'ifn-link1'}], ifn-link2: [$conf->{conf}{node}{$node2}{set_nic}{'ifn-link2'}].\n");
	if ((not $conf->{conf}{node}{$node2}{set_nic}{'bcn-link1'}) || 
	    (not $conf->{conf}{node}{$node2}{set_nic}{'bcn-link2'}) ||
	    (not $conf->{conf}{node}{$node2}{set_nic}{'sn-link1'})  ||
	    (not $conf->{conf}{node}{$node2}{set_nic}{'sn-link2'})  ||
	    (not $conf->{conf}{node}{$node2}{set_nic}{'ifn-link1'}) ||
	    (not $conf->{conf}{node}{$node2}{set_nic}{'ifn-link2'}))
	{
		$node2_remap_needed = 1;
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
	if ($conf->{cgi}{remap_network})
	{
		$node1_class        = "highlight_note_bold";
		$node1_message      = "#!string!state_0032!#",
		$node2_class        = "highlight_note_bold";
		$node2_message      = "#!string!state_0032!#",
		$node1_remap_needed = 1;
		$node2_remap_needed = 2;
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
	
	### TODO: This will fail when there isn't an internet connection! We
	###       check that, so write an rsync function to move the script
	###       under docroot and then wget from this machine.
	# First, make sure the script is downloaded and ready to run.
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	"if [ ! -e \"$conf->{path}{'anvil-map-network'}\" ]; 
					then
						wget $conf->{url}{'anvil-map-network'} -O $conf->{path}{'anvil-map-network'};
					fi;
					if [ -e \"$conf->{path}{'anvil-map-network'}\" ]; 
					then
						chmod 755 $conf->{path}{'anvil-map-network'};
						echo ready;
					else
						echo failed;
					fi;",
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }

	my $proceed = 0;
	foreach my $line (@{$return})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
		if ($line =~ "ready")
		{
			# Downloaded (or already existed), ready to go.
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; proceed: [$proceed]\n");
			$proceed = 1;
		}
		elsif ($line =~ "failed")
		{
			# Downloaded (or already existed), ready to go.
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed: [$return_code]\n");
			$return_code = 9;
		}
	}
	
	my $nics_seen = 0;
	if ($conf->{node}{$node}{ssh_fh} !~ /^Net::SSH2/)
	{
		# Downloaded (or already existed), ready to go.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; SSH File handle: [$conf->{node}{$node}{ssh_fh}] for node: [$node] doesn't exist, but it should. \n");
		$return_code = 8;
	}
	else
	{
		# I need input from the user, so I need to call the client directly
		my $cluster    = $conf->{cgi}{cluster};
		my $port       = 22;
		my $user       = "root";
		my $ssh_fh     = $conf->{node}{$node}{ssh_fh};
		my $close      = 0;
		
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
		if ($remap)
		{
			$shell_call = "$conf->{path}{'anvil-map-network'} --script";
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		
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
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; channel: [$channel], shell_call: [$shell_call]\n");
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
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; STDOUT: [$line].\n");
				if ($line =~ /nic=(.*?),,mac=(.*)$/)
				{
					my $nic = $1;
					my $mac = $2;
					$conf->{conf}{node}{$node}{current_nic}{$nic} = $mac;
					$nics_seen++;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; conf::node::${node}::current_nics::$nic: [$conf->{conf}{node}{$node}{current_nic}{$nic}].\n");
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
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; STDERR: [$line].\n");
				print parse_script_line($conf, "STDERR", $node, $line);
			}
			
			# Exit when we get the end-of-file.
			last if $channel->eof;
		}
	}
	if ($remap)
	{
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-end-network-config");
		
		# We should now know this info.
		$conf->{conf}{node}{$node}{set_nic}{'bcn-link1'} = $conf->{conf}{node}{$node}{current_nic}{'bcn-link1'};
		$conf->{conf}{node}{$node}{set_nic}{'bcn-link2'} = $conf->{conf}{node}{$node}{current_nic}{'bcn-link2'};
		$conf->{conf}{node}{$node}{set_nic}{'sn-link1'}  = $conf->{conf}{node}{$node}{current_nic}{'sn-link1'};
		$conf->{conf}{node}{$node}{set_nic}{'sn-link2'}  = $conf->{conf}{node}{$node}{current_nic}{'sn-link2'};
		$conf->{conf}{node}{$node}{set_nic}{'ifn-link1'} = $conf->{conf}{node}{$node}{current_nic}{'ifn-link1'};
		$conf->{conf}{node}{$node}{set_nic}{'ifn-link2'} = $conf->{conf}{node}{$node}{current_nic}{'ifn-link2'};
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node]: bcn-link1: [$conf->{conf}{node}{$node}{set_nic}{'bcn-link1'}], bcn-link2: [$conf->{conf}{node}{$node}{set_nic}{'bcn-link2'}], sn-link1: [$conf->{conf}{node}{$node}{set_nic}{'sn-link1'}], sn-link2: [$conf->{conf}{node}{$node}{set_nic}{'sn-link2'}], ifn-link1: [$conf->{conf}{node}{$node}{set_nic}{'ifn-link1'}], ifn-link2: [$conf->{conf}{node}{$node}{set_nic}{'ifn-link2'}]\n");
	}
	
	if ($nics_seen < 6)
	{
		$return_code = 4;
	}
	
	return($return_code);
}

# This checks to see which, if any, packages need to be installed.
sub install_programs
{
	my ($conf) = @_;
	
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
		}});
		$ok            = 0;
	}
	if (not $node2_ok)
	{
		$node2_class   = "highlight_bad_bold";
		$node2_message = AN::Common::get_string($conf, {key => "state_0025", variables => {
			missing	=>	$conf->{node}{$node2}{missing_rpms},
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
	
	my $ok = 1;
	get_installed_package_list($conf, $node, $password);
	
	# Figure out which are missing.
	my $to_install = "";
	foreach my $package (sort {$a cmp $b} keys %{$conf->{packages}{to_install}})
	{
		# Watch for autovivication...
		if ((exists $conf->{node}{$node}{packages}{installed}{$package}) && ($conf->{node}{$node}{packages}{installed}{$package} == 1))
		{
			$conf->{packages}{to_install}{$package} = 1;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], package: [$package] already installed.\n");
		}
		else
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], package: [$package] needed.\n");
			$to_install .= "$package ";
		}
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], to_install: [$to_install]");
	
	if ($to_install)
	{
		my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	22,
			user		=>	"root",
			password	=>	$password,
			ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
			'close'		=>	0,
			shell_call	=>	"yum -y install $to_install",
		});
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
		$conf->{node}{$node}{internet} = 0;
		foreach my $line (@{$return})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
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
			$conf->{packages}{to_install}{$package} = 1;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], package: [$package] installed.\n");
		}
		else
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], package: [$package] missing.\n");
			$missing .= "$package ";
		}
	}
	$missing =~ s/\s+$//;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], missing: [$missing]\n");
	
	# If anything is missing, we're toast.
	if ($missing)
	{
		$ok = 0;
		$conf->{node}{$node}{missing_rpms} = $missing;
	}
	else
	{
		# Make sure the libvirtd bridge is gone.
		my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	22,
			user		=>	"root",
			password	=>	$password,
			ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
			'close'		=>	0,
			shell_call	=>	"if [ -e /proc/sys/net/ipv4/conf/virbr0 ]; 
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
						fi",
		});
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
		$conf->{node}{$node}{internet} = 0;
		foreach my $line (@{$return})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
			if ($line eq "failed")
			{
				$ok = 0;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to delete the 'virbr0' bridge.\n");
			}
			elsif ($line eq "bridge gone")
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The bridge 'virbr0' is gone.\n");
			}
		}
	}
	
	return($ok);
}

# This calls 'yum list installed', parses the output and checks to see if the
# needed packages are installed.
sub get_installed_package_list
{
	my ($conf, $node, $password) = @_;
	
	my $ok = 0;
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	"yum list installed",
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	$conf->{node}{$node}{internet} = 0;
	foreach my $line (@{$return})
	{
		next if $line =~ /^Loaded plugins/;
		next if $line =~ /^Loading mirror/;
		next if $line =~ /^Installed Packages/;
		next if $line =~ /^\s/;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
		if ($line =~ /^(.*?)\.(.*?)\s+(.*?)\s+\@/)
		{
			my $package   = $1;
			my $arch      = $2;
			my $version   = $3;
			# NOTE: Someday record the arch and version, but for
			#       now, we don't care.
			$conf->{node}{$node}{packages}{installed}{$package} = 1;
		}
		elsif ($line =~ /^(.*?)\.(.*?)\s+(.*)/)
		{
			my $package   = $1;
			my $arch      = $2;
			my $version   = $3;
			$conf->{node}{$node}{packages}{installed}{$package} = 1;
		}
		elsif ($line =~ /^(.*?)\.(\S*)$/)
		{
			my $package   = $1;
			my $arch      = $2;
			$conf->{node}{$node}{packages}{installed}{$package} = 1;
		}
	}
	
	return(0);
}

# This add the AN!Repo if needed to each node.
sub add_an_repo
{
	my ($conf) = @_;
	
	my ($node1_rc) = add_an_repo_to_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_rc) = add_an_repo_to_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	
	# 1 == Repo already exists, 
	# 2 == Repo was added and yum cache was cleaned
	# 9 == Something went wrong.
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0020!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0020!#";
	my $message       = "";
	if ($node1_rc eq "2")
	{
		$node1_message = "#!string!state_0023!#",
	}
	elsif ($node1_rc eq "9")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0018!#",
		$ok            = 0;
	}
	if ($node2_rc eq "2")
	{
		$node2_message = "#!string!state_0023!#",
	}
	elsif ($node2_rc eq "9")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0018!#",
		$ok            = 0;
	}

	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0225!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	if (not $ok)
	{
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
			message		=>	"#!string!message_0367!#",
		});
	}
	
	return(0);
}

# This does the actual work of adding the AN!Repo to a specifc node.
sub add_an_repo_to_node
{
	my ($conf, $node, $password) = @_;
	
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	"if [ -e '/etc/yum.repos.d/an.repo' ]; then echo 1; else curl --silent https://alteeve.ca/repo/el6/an.repo --output /etc/yum.repos.d/an.repo; if [ -e '/etc/yum.repos.d/an.repo' ]; then yum clean all --quiet; echo 2; else echo 9; fi; fi",
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	my $rc = 0;
	foreach my $line (@{$return})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
		$rc = $line;
	}
	
	return($rc);
}

# This calls yum update against both nodes.
sub update_nodes
{
	my ($conf) = @_;
	
	# This could take a while
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-be-patient-message", {
		message	=>	"#!string!explain_0130!#",
	});
	
	# The OS update is good, but not fatal if it fails.
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	$conf->{node}{$node1}{reboot_needed} = 0;
	$conf->{node}{$node1}{os_updated}    = 0;
	$conf->{node}{$node2}{reboot_needed} = 0;
	$conf->{node}{$node2}{os_updated}    = 0;
	update_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	update_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvi2_node1_current_password});
	
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0026!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0026!#";
	if ($conf->{node}{$node1}{os_updated})
	{
		$node1_message = "#!string!state_0027!#",
	}
	if ($conf->{node}{$node2}{os_updated})
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

# This calls the yum update and flags the node for a reboot if the kernel is
# updated.
sub update_node
{
	my ($conf, $node, $password) = @_;
	
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	"yum -y update",
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	$conf->{node}{$node}{internet} = 0;
	foreach my $line (@{$return})
	{
		$line =~ s/\n//g;
		$line =~ s/\r//g;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], line: [$line]\n");
		if ($line =~ /Installing : kernel/)
		{
			$conf->{node}{$node}{reboot_needed} = 1;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], reboot needed.\n");
		}
		if ($line =~ /Total download size/)
		{
			$conf->{node}{$node}{os_updated} = 1;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], packages updated.\n");
		}
	}
	
	return(0);
}

# This pings alteeve.ca to check for internet access.
sub verify_internet_access
{
	my ($conf) = @_;
	
	### TODO: If there is no internet access, see if there is a disk in
	###       /dev/sr0 and, if so, mount it and if it has packages, make
	###       sure/create a yum repo file for it. Don't abort the install.
	
	my ($node1_online) = ping_website($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_online) = ping_website($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	
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
			message		=>	"#!string!message_0366!#",
		});
	}
	
	return(1);
}

# This pings as website to check for an internet connection.
sub ping_website
{
	my ($conf, $node, $password) = @_;
	
	# Ya, I know 8.8.8.8 isn't a website...
	my $ok = 0;
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	"ping 8.8.8.8 -c 3 -q",
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	$conf->{node}{$node}{internet} = 0;
	foreach my $line (@{$return})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
		if ($line =~ /(\d+) packets transmitted, (\d+) received/)
		{
			my $pings_sent     = $1;
			my $pings_received = $2;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], pings_sent: [$pings_sent], pings_received: [$pings_received]\n");
			if ($pings_received > 0)
			{
				$ok = 1;
				$conf->{node}{$node}{internet} = 1;
			}
		}
	}
	
	# If there is no internet connection, add a yum repo for the cdrom
	if (not $conf->{node}{$node}{internet})
	{
		# Make sure the DVD repo exists.
		create_dvd_repo($conf, $node, $password);
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], ok: [$ok]\n");
	return($ok);
}

# This checks to see if the DVD repo has been added to the node yet. If not,
# and if there is a disk in the drive, it will mount sr0, check that it's got
# RPMs and, if so, create the repo. If not, it unmounts the DVD.
sub create_dvd_repo
{
	my ($conf, $node, $password) = @_;
	
	# A wee bit of bash in this one...
	my $mount_name = "optical";
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	"
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
        if $(mount | grep -q sr0)
        then
                echo \"Optical drive already mounted.\"
        else
                echo \"Optical drive not mounted.\"
                mount /dev/sr0 /mnt/$mount_name
                if ! $(mount | grep -q sr0)
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
fi
",
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	my $return_code = -1;
	foreach my $line (@{$return})
	{
		if ($line =~ /exit:(\d+)/)
		{
			$return_code = $1;
		}
		else
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
		}
	}
	
	return($return_code);
}

# This checks to see if both nodes have the same amount of unallocated space.
sub verify_matching_free_space
{
	my ($conf) = @_;
	
	### TODO: When the drive is partitioned, write a file out indicating
	###       which partitions we created so that we don't error out for
	###       lack of free space on re-runs on the program.
	
	my $ok = 1;
	my ($node1_use_device, $node1_free_space) = get_partition_data($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_use_device, $node2_free_space) = get_partition_data($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_free_space: [$node1_free_space], node2_free_space: [$node2_free_space]\n");
	
	# Message stuff
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "$node1_use_device:".AN::Cluster::bytes_to_hr($conf, $node1_free_space);
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "$node2_use_device:".AN::Cluster::bytes_to_hr($conf, $node2_free_space);
	my $message       = "";
	
	# Space needed by the media library is always a static size
	my $total_free_space = $node1_free_space;
	if ($node2_free_space < $node1_free_space)
	{
		$total_free_space = $node2_free_space;
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; total_free_space: [$total_free_space]\n");
	
	my $media_library_size      = $conf->{cgi}{anvil_media_library_size};
	my $media_library_unit      = $conf->{cgi}{anvil_media_library_unit};
	my $media_library_byte_size = AN::Cluster::hr_to_bytes($conf, $media_library_size, $media_library_unit, 1);
	my $minimum_space_needed    = $media_library_byte_size;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; media_library_byte_size: [$media_library_byte_size], minimum_space_needed: [$minimum_space_needed]\n");
	
	my $minimum_pool_size = AN::Cluster::hr_to_bytes($conf, 8, "GiB", 1);
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; minimum_pool_size: [$minimum_pool_size]\n");
	# Space needed by storage pool 1 could be a static size or a
	# percentage. If it's a percentage, we'll need a minimum of 8 GiB free.
	# If a static size, then we just want to make sure there is enough for
	# the first pool. If there is 8 GiB or more extra, it will be allocated
	# to 
	my $storage_pool1_size      = $conf->{cgi}{anvil_storage_pool1_size};
	my $storage_pool1_unit      = $conf->{cgi}{anvil_storage_pool1_unit};
	my $storage_pool1_byte_size = 0;
	my $storage_pool2_byte_size = 0;
	if ($storage_pool1_unit eq "%")
	{
		# Percentage, make sure there is at least 16 GiB free (8 GiB
		# for each pool)
		$minimum_space_needed += ($minimum_pool_size * 2);
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; minimum_space_needed: [$minimum_space_needed]\n");
	}
	else
	{
		$storage_pool1_byte_size =  AN::Cluster::hr_to_bytes($conf, $storage_pool1_size, $storage_pool1_unit, 1);
		$minimum_space_needed    += $storage_pool1_byte_size;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; storage_pool1_byte_size: [$storage_pool1_byte_size], minimum_space_needed: [$minimum_space_needed]\n");
	}
	
	# Now check things.
	if (($node1_use_device eq "--") || ($node2_use_device eq "--"))
	{
		# parted not installed and no internet connection.
		$node1_class   = "highlight_bad_bold";
		$node2_class   = "highlight_bad_bold";
		$ok            = 0;
		$message       = "#!string!message_0368!#",
	}
	elsif (not $node1_free_space)
	{
		# No free space, can't proceed.
		$node1_class   = "highlight_bad_bold";
		$node2_class   = "highlight_bad_bold";
		$ok            = 0;
		$message       = "#!string!message_0364!#",
	}
	elsif ($node1_free_space ne $node2_free_space)
	{
		# Free space doesn't match
		$node1_class   = "highlight_warning_bold";
		$node2_class   = "highlight_warning_bold";
		$ok            = 0;
		$message       = "#!string!message_0365!#",
	}
	
	# Now check that we have enough space and, if so, put hard numbers to 
	# the sizes from the install manifest.
	if ($minimum_space_needed > $total_free_space)
	{
		$node1_class   = "highlight_bad_bold";
		$node2_class   = "highlight_bad_bold";
		$ok            = 0;
		$message       = AN::Common::get_string($conf, {key => "message_0374", variables => {
			size	=>	AN::Cluster::bytes_to_hr($conf, $minimum_space_needed),
		}});
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0222!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	if ($ok)
	{
		# Things are good, so calculate the static sizes of our pool
		# for display in the summary/confirmation later.
		# Make sure the storage pool is an even MiB.
		my $media_library_difference = $media_library_byte_size % 1048576;
		if ($media_library_difference)
		{
			# Round up
			my $media_library_balance   =  1048576 - $media_library_difference;
			   $media_library_byte_size += $media_library_balance;
		}
		$conf->{cgi}{anvil_media_library_byte_size} = $media_library_byte_size;
		my $free_space_left = $total_free_space - $media_library_byte_size;
		
		# If the user has asked for a percentage, divide the free space
		# by the percentage.
		if ($storage_pool1_unit eq "%")
		{
			my $percent = $storage_pool1_size / 100;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; percent: [$percent]\n");
			
			# Round up to the closest even MiB
			my $pool1_byte_size  = $percent * $free_space_left;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> pool1_byte_size: [$pool1_byte_size]\n");
			my $pool1_difference = $pool1_byte_size % 1048576;
			if ($pool1_difference)
			{
				# Round up
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_difference: [$pool1_difference]\n");
				my $pool1_balance   =  1048576 - $pool1_difference;
				   $pool1_byte_size += $pool1_balance;
			}
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << pool1_byte_size: [$pool1_byte_size]\n");
			
			# Round down to the closest even MiB (left over space
			# will be unallocated on disk)
			my $pool2_byte_size = $free_space_left - $pool1_byte_size;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> pool2_byte_size: [$pool2_byte_size]\n");
			if ($pool2_byte_size < 0)
			{
				# Well then...
				$pool2_byte_size = 0;
			}
			else
			{
				my $pool2_difference = $pool2_byte_size % 1048576;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool2_difference: [$pool1_difference]\n");
				if ($pool2_difference)
				{
					# Round down
					$pool2_byte_size -= $pool2_difference;
				}
			}
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << pool2_byte_size: [$pool2_byte_size]\n");
			
			# Final sanity check; Add up the three calculated sizes
			# and make sure I'm not trying to ask for more space
			# than is available.
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; media_library_byte_size: [$media_library_byte_size] + pool1_byte_size: [$pool1_byte_size] + pool2_byte_size: [$pool2_byte_size]\n");
			my $total_allocated = ($media_library_byte_size + $pool1_byte_size + $pool2_byte_size);
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; total_allocated: [$total_allocated], total_free_space: [$total_free_space]\n");
			if ($total_allocated > $total_free_space)
			{
				my $too_much = $total_allocated - $total_free_space;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; too_much: [$too_much]\n");
				
				# Take the overage from pool 2, if used.
				if ($pool2_byte_size > $too_much)
				{
					# Reduce!
					$pool2_byte_size -= $too_much;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> pool2_byte_size: [$pool2_byte_size]\n");
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
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << pool2_byte_size: [$pool2_byte_size]\n");
				}
				else
				{
					# Take the pound of flesh from pool 1
					$pool1_byte_size -= $too_much;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> pool1_byte_size: [$pool1_byte_size]\n");
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
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << pool1_byte_size: [$pool1_byte_size]\n");
				}
				
				# Check again.
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; media_library_byte_size: [$media_library_byte_size] + pool1_byte_size: [$pool1_byte_size] + pool2_byte_size: [$pool2_byte_size]\n");
				$total_allocated = ($media_library_byte_size + $pool1_byte_size + $pool2_byte_size);
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; total_allocated: [$total_allocated], total_free_space: [$total_free_space]\n");
				if ($total_allocated > $total_free_space)
				{
					# OK, WTF?
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to divide free space!\n");
					$ok = 0;
				}
			}
			
			$conf->{cgi}{anvil_storage_pool1_byte_size} = $pool1_byte_size;
			$conf->{cgi}{anvil_storage_pool2_byte_size} = $pool2_byte_size;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_storage_pool1_byte_size: [$conf->{cgi}{anvil_storage_pool1_byte_size}], cgi::anvil_storage_pool2_byte_size: [$conf->{cgi}{anvil_storage_pool2_byte_size}]\n");
		}
		else
		{
			# Pool 1 is static, so simply round to an even MiB.
			my $pool1_byte_size = $storage_pool1_byte_size;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> pool1_byte_size: [$pool1_byte_size]\n");
			my $pool1_difference = $pool1_byte_size % 1048576;
			if ($pool1_difference)
			{
				# Round up
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_difference: [$pool1_difference]\n");
				my $pool1_balance   =  1048576 - $pool1_difference;
				   $pool1_byte_size += $pool1_balance;
			}
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << pool1_byte_size: [$pool1_byte_size]\n");
			
			my $pool2_byte_size = $free_space_left - $pool1_byte_size;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> pool2_byte_size: [$pool2_byte_size]\n");
			if ($pool2_byte_size < 0)
			{
				# Well then...
				$pool2_byte_size = 0;
			}
			else
			{
				my $pool2_difference = $pool2_byte_size % 1048576;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool2_difference: [$pool1_difference]\n");
				if ($pool2_difference)
				{
					# Round down
					$pool2_byte_size -= $pool2_difference;
				}
			}
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << pool2_byte_size: [$pool2_byte_size]\n");
			
			$conf->{cgi}{anvil_storage_pool1_byte_size} = $pool1_byte_size;
			$conf->{cgi}{anvil_storage_pool2_byte_size} = $pool2_byte_size;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_storage_pool1_byte_size: [$conf->{cgi}{anvil_storage_pool1_byte_size}], cgi::anvil_storage_pool2_byte_size: [$conf->{cgi}{anvil_storage_pool2_byte_size}]\n");
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_media_library_byte_size: [$conf->{cgi}{anvil_media_library_byte_size}]\n");
	}
	else
	{
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-failed", {
			message		=>	$message,
		});
	}
	my $say_media_library = AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_media_library_byte_size});
	my $say_pool1         = AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size});
	my $say_pool2         = AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_media_library_byte_size: [$conf->{cgi}{anvil_media_library_byte_size} ($say_media_library)], cgi::anvil_storage_pool1_byte_size: [$conf->{cgi}{anvil_storage_pool1_byte_size} ($say_pool1)], cgi::anvil_storage_pool2_byte_size: [$conf->{cgi}{anvil_storage_pool2_byte_size} ($say_pool2)]\n");
	
	$conf->{cgi}{anvil_storage_partition_1_byte_size} = $conf->{cgi}{anvil_media_library_byte_size} + $conf->{cgi}{anvil_storage_pool1_byte_size};
	$conf->{cgi}{anvil_storage_partition_2_byte_size} = $conf->{cgi}{anvil_storage_pool2_byte_size};
	my $say_partition_1 = AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_partition_1_byte_size});
	my $say_partition_2 = AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_partition_2_byte_size});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_storage_partition_1_byte_size: [$conf->{cgi}{anvil_storage_partition_1_byte_size} ($say_partition_1)], cgi::anvil_storage_partition_2_byte_size: [$conf->{cgi}{anvil_storage_partition_2_byte_size} ($say_partition_2)]\n");
	
	return($ok);
}

# This checks for free space on the target node.
sub get_partition_data
{
	my ($conf, $node, $password) = @_;
	
	my $largest_free_space = 0;
	my $device             = "";
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	"lsblk --all --bytes --noheadings --pairs",
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	
	my @disks;
	my $name  = "";
	my $type  = "";
	foreach my $line (@{$return})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
		# The order appears consistent, but I'll pull values out one at
		# a time to be safe.
		if ($line =~ /TYPE="(.*?)"/i)
		{
			$type = $1;
		}
		if ($line =~ /NAME="(.*?)"/i)
		{
			$name = $1;
		}
		next if $type ne "disk";
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], name: [$name], type: [$type]\n");
		
		push @disks, $name;
	}
	
	# Get the details on each disk now.
	foreach my $disk (@disks)
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk]\n");
		my $shell_call = "if [ ! -e /sbin/parted ]; then yum --quiet -y install parted; echo parted installed; fi && parted /dev/$disk unit B print free";
		if (not $conf->{node}{$node}{internet})
		{
			$shell_call = "if [ ! -e /sbin/parted ]; then echo parted not installed; else parted /dev/$disk unit B print free; fi";
		}
		my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	22,
			user		=>	"root",
			password	=>	$password,
			ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
		foreach my $line (@{$return})
		{
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], line: [$line]\n");
			if ($line eq "parted not installed")
			{
				$device             = "--";
				$largest_free_space = "--";
				last;
			}
			elsif ($line eq "parted installed")
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], Installed 'parted' RPM.\n");
			}
			#              part  start end   size  type  - don't care about the rest.
			elsif ($line =~ /^(\d+) (\d+)B (\d+)B (\d+)B (.*?) /)
			{
				# Existing partitions
				my $partition_number = $1;
				my $partition_start  = $2;
				my $partition_end    = $3;
				my $partition_size   = $4;
				my $partition_type   = $5;
				$conf->{node}{$node}{disk}{$disk}{partition}{$partition_number}{start} = $partition_start;
				$conf->{node}{$node}{disk}{$disk}{partition}{$partition_number}{end}   = $partition_end;
				$conf->{node}{$node}{disk}{$disk}{partition}{$partition_number}{size}  = $partition_size;
				$conf->{node}{$node}{disk}{$disk}{partition}{$partition_number}{type}  = $partition_type;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], partition: [$partition_number], start: [$conf->{node}{$node}{disk}{$disk}{partition}{$partition_number}{start}], end: [$conf->{node}{$node}{disk}{$disk}{partition}{$partition_number}{end}], size: [$conf->{node}{$node}{disk}{$disk}{partition}{$partition_number}{size}], type: [$conf->{node}{$node}{disk}{$disk}{partition}{$partition_number}{type}]\n");
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
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], free space; start: [$conf->{node}{$node}{disk}{$disk}{free_space}{start}], end: [$conf->{node}{$node}{disk}{$disk}{free_space}{end}], size: [$conf->{node}{$node}{disk}{$disk}{free_space}{size}]\n");
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], free_space_size: [$free_space_size] > largest_free_space: [$largest_free_space]?\n");
				if ($free_space_size > $largest_free_space)
				{
					$device             = $disk;
					$largest_free_space = $free_space_size;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], Yes; device: [$device], free_space_size: [$free_space_size]\n");
				}
			}
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], device: [$device], largest_free_space: [$largest_free_space]\n");
	return($device, $largest_free_space);
}

# This checks to see if /etc/cluster/cluster.conf is available and aborts if
# so.
sub verify_node_is_not_in_a_cluster
{
	my ($conf) = @_;
	
	my $ok = 1;
	my ($node1_cluster_conf) = read_cluster_conf($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_cluster_conf) = read_cluster_conf($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	
	my $node1_class   = "highlight_good_bold";
	my $node1_message = AN::Common::get_string($conf, {key => "state_0019"});
	my $node2_class   = "highlight_good_bold";
	my $node2_message = AN::Common::get_string($conf, {key => "state_0019"});
	if ($node1_cluster_conf)
	{
		$node1_class   = "highlight_bad_bold";
		$node1_message = AN::Common::get_string($conf, {key => "state_0020"});
		$ok            = 0;
	}
	if ($node2_cluster_conf)
	{
		$node2_class   = "highlight_bad_bold";
		$node2_message = AN::Common::get_string($conf, {key => "state_0020"});
		$ok            = 0;
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
	
	return($ok);
}

# This reads in /etc/cluster/cluster.conf and returns '0' if not found.
sub read_cluster_conf
{
	my ($conf, $node, $password) = @_;
	
	# Later, this will use XML::Simple to parse the contents. For now, I
	# only care if the file exists at all.
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	"cat /etc/cluster/cluster.conf",
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	
	my $data = 0;
	foreach my $line (@{$return})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
		last if $line =~ /No such file or directory/;
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], data: [$data]\n");
	return($data)
}

# This checks to make sure both nodes have a compatible OS installed.
sub verify_os
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; verify_os()\n");
	
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
	
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	"cat /etc/redhat-release",
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	
	my $brand = "";
	my $major = 0;
	my $minor = 0;
	foreach my $line (@{$return})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
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
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], major: [$major], minor: [$minor]\n");
	
	# If it's RHEL, see if it's registered.
	if ($conf->{node}{$node}{os}{brand} =~ /Red Hat Enterprise Linux Server/)
	{
		# See if it's been registered already.
		$conf->{node}{$node}{os}{registered} = 0;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is RHEL proper, checking to see if it has been registered already.\n");
		my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	22,
			user		=>	"root",
			password	=>	$password,
			ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
			'close'		=>	0,
			shell_call	=>	"rhn_check; echo exit:\$?",
		});
		foreach my $line (@{$return})
		{
			if ($line =~ /^exit:(\d+)$/)
			{
				my $rc = $1;
				if ($rc eq "0")
				{
					$conf->{node}{$node}{os}{registered} = 1;
				}
			}
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is registered on RHN? [$conf->{node}{$node}{os}{registered}].\n");
	}
	return($major, $minor);
}

# This makes sure we have access to both nodes.
sub check_connection
{
	my ($conf) = @_;
	
	my ($node1_access) = check_node_access($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_access) = check_node_access($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_access: [$node1_access], node2_access: [$node2_access]\n");
	
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
	}
	
	return($access);
}

# This does nothing more than call 'echo 1' to see if the target is reachable.
sub check_node_access
{
	my ($conf, $node, $password) = @_;
	
	my $access = 0;
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	"",
		'close'		=>	0,
		shell_call	=>	"echo 1",
	});
	$conf->{node}{$node}{ssh_fh} = $ssh_fh;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	#foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n"); }
	$access = $return->[0] ? $return->[0] : 0;
 	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], access: [$access]\n");
	
	return($access);
}

1;
