package AN::Common;
#
# This will store general purpose functions.
# 
# 
# NOTE: The '$an' file handle has been added to all functions to enable the transition to using AN::Tools.
# 

use strict;
use warnings;
use IO::Handle;
use Encode;
use CGI;
use utf8;
use Term::ReadKey;
use XML::Simple qw(:strict);
use AN::Cluster;

# Set static variables.
my $THIS_FILE = 'AN::Common.pm';


# This funtion does not try to parse anything, use templates or what have you. It's very close to a simple
# 'die'. This should be used as rarely as possible as translations can't be used.
sub hard_die
{
	my ($conf, $file, $line, $exit_code, $message) = @_;
	
	$file      = "--" if not defined $file;
	$line      = 0    if not defined $line;
	$exit_code = 999  if not defined $exit_code;
	$message   = "?"  if not defined $message;
	
	# This can't be skinned or translated. :(
	print "
	<div name=\"hard_die\">
	Fatal error: [<span class=\"code\">$exit_code</span>] in file: [<span class=\"code\">$file</span>] at line: [<span class=\"code\">$line</span>]!<br />
	$message<br />
	Exiting.<br />
	</div>
	";
	
	exit ($exit_code);
}

# This initializes a call; reads variables, etc. In this function, '$an' is not yet defined.
sub initialize
{
	my ($caller, $initialize_http) = @_;
	
	# Set default configuration variable values
	my ($conf) = initialize_conf();
	
	# Open my handle to AN::Tools, use the $conf hash ref for $an->data and set '$an's default log file.
	my $an = AN::Tools->new({data => $conf});
	$conf->{handle}{an} = $an;
	
	# First thing first, initialize the web session.
	$an->Web->initialize_http() if $initialize_http;

	# First up, read in the default strings file.
	$an->Storage->read_words({file => $an->data->{path}{common_strings}});
	$an->Storage->read_words({file => $an->data->{path}{scancore_strings}});
	$an->Storage->read_words({file => $an->data->{path}{striker_strings}});

	# Read in the configuration file. If the file doesn't exist, initial setup will be triggered.
	$an->Storage->read_conf({file => $an->data->{path}{striker_config}});
	
	return($conf);
}

# Set default configuration variable values. In this function, '$an' is not yet defined.
sub initialize_conf
{
	# Setup (sane) defaults
	my $conf = {
		nodes			=>	"",
		check_using_node	=>	"",
		up_nodes		=>	[],
		online_nodes		=>	[],
		handles			=>	{
			'log'			=>	"",
		},
		path			=>	{
			agents_directory	=>	"/var/www/ScanCore/ScanCore/agents",
			apache_manifests_dir	=>	"/var/www/html/manifests",
			apache_manifests_url	=>	"/manifests",
			backup_config		=>	"/var/www/html/striker-backup_#!hostname!#_#!date!#.txt",	# Remember to update the sys::backup_url value below if you change this
			'call_anvil-kick-apc-ups' =>	"/sbin/striker/call_anvil-kick-apc-ups",
			'call_gather-system-info' =>	"/sbin/striker/call_gather-system-info",
			'call_striker-push-ssh'	=>	"/sbin/striker/call_striker-push-ssh",
			'call_striker-configure-vmm' =>	"/sbin/striker/call_striker-configure-vmm",
			'call_striker-delete-anvil' =>	"/sbin/striker/call_striker-delete-anvil",
			'call_striker-merge-dashboards' => "/sbin/striker/call_striker-merge-dashboards",
			'striker-configure-vmm'	=>	"/sbin/striker/striker-configure-vmm",
			'striker-delete-anvil'	=>	"/sbin/striker/striker-delete-anvil",
			'striker-merge-dashboards' =>	"/sbin/striker/striker-merge-dashboards",
			cat			=>	"/bin/cat",
			ccs			=>	"/usr/sbin/ccs",
			check_dvd		=>	"/sbin/striker/check_dvd",
			cluster_conf		=>	"/etc/cluster/cluster.conf",
			clusvcadm		=>	"/usr/sbin/clusvcadm",
			common_strings		=>	"Data/common.xml",
			config_file		=>	"/etc/striker/striker.conf",	# TODO: Phase this out in favour of 'striker_config' below.
			control_dhcpd		=>	"/sbin/striker/control_dhcpd",
			control_iptables	=>	"/sbin/striker/control_iptables",
			control_libvirtd	=>	"/sbin/striker/control_libvirtd",
			control_shorewall	=>	"/sbin/striker/control_shorewall",
			cp			=>	"/bin/cp",
			default_striker_manifest =>	"/var/www/html/manifests/striker-default.xml",
			dhcpd_conf		=>	"/etc/dhcp/dhcpd.conf",
			do_dd			=>	"/sbin/striker/do_dd",
			docroot			=>	"/var/www/html/",
			echo			=>	"/bin/echo",
			expect			=>	"/usr/bin/expect",
			fence_ipmilan		=>	"/sbin/fence_ipmilan",
			gethostip		=>	"/bin/gethostip",
			'grep'			=>	"/bin/grep",
			home			=>	"/var/www/home/",
			# This stores this node's UUID. It is used to track all our sensor data in the 
			# database. If you change this here, change it in the agents, too.
			host_uuid		=>	"/etc/striker/host.uuid",
			hostname		=>	"/bin/hostname",
			hosts			=>	"/etc/hosts",
			ifconfig		=>	"/sbin/ifconfig",
			initd_iptables		=>	"/etc/init.d/iptables",
			initd_libvirtd		=>	"/etc/init.d/libvirtd",
			initd_shorewall		=>	"/etc/init.d/shorewall",
			ip			=>	"/sbin/ip",
			log_file		=>	"/var/log/striker.log",
			lvdisplay		=>	"/sbin/lvdisplay",
			mailx			=>	"/bin/mailx",
			media			=>	"/var/www/home/media/",
			mv			=>	"/bin/mv",
			perl_library		=>	"/usr/share/perl5",
			perl_source		=>	"/sbin/striker/AN",
			ping			=>	"/usr/bin/ping",
			postfix_init		=>	"/etc/init.d/postfix",
			postfix_main		=>	"/etc/postfix/main.cf",
			postfix_relay_file	=>	"/etc/postfix/relay_password",
			postmap			=>	"/usr/sbin/postmap",
			'redhat-release'	=>	"/etc/redhat-release",
			repo_centos		=>	"/var/www/html/centos6/x86_64/img/repodata",
			repo_centos_path	=>	"/centos6/x86_64/img/",
			repo_generic		=>	"/var/www/html/repo/repodata",
			repo_generic_path	=>	"/repo/",
			repo_rhel		=>	"/var/www/html/rhel6/x86_64/img/repodata",
			repo_rhel_path		=>	"/rhel6/x86_64/img/",
			rhn_check		=>	"/usr/sbin/rhn_check",
			rhn_file		=>	"/etc/sysconfig/rhn/systemid",
			rsync			=>	"/usr/bin/rsync",
			scancore_strings	=>	"/sbin/striker/ScanCore/ScanCore.xml",
			scancore_sql		=>	"/sbin/striker/ScanCore/ScanCore.sql",
			screen			=>	"/usr/bin/screen",
			shared			=>	"/shared/files/",	# This is hard-coded in the file delete function.
			shorewall_init		=>	"/etc/init.d/shorewall",
			skins			=>	"../html/skins/",
			ssh_config		=>	"/etc/ssh/ssh_config",
			'ssh-keyscan'		=>	"/usr/bin/ssh-keyscan",
			status			=>	"/var/www/home/status/",
			striker_cache		=>	"/var/www/home/cache",
			striker_config		=>	"/etc/striker/striker.conf",
			striker_files		=>	"/var/www/home",
			'striker-push-ssh'	=>	"/sbin/striker/striker-push-ssh",
			striker_strings		=>	"/sbin/striker/Data/strings.xml",
			sync			=>	"/bin/sync",
			tools_directory		=>	"/sbin/striker/",
			'touch_striker.log'	=>	"/sbin/striker/touch_striker.log",
			tput			=>	"/usr/bin/tput",
			uuidgen			=>	"/usr/bin/uuidgen",
			virsh			=>	"/usr/bin/virsh",
			'virt-manager'		=>	"/usr/bin/virt-manager",
			
			# These are the tools that will be copied to 'docroot' if either node doesn't have 
			# an internet connection.
			tools			=>	[
				"anvil-map-network",
				"anvil-self-destruct",
			],
			
			# These are files on nodes, not on the dashboard machin itself.
			nodes			=>	{
				'anvil-adjust-vnet'	=>	"/sbin/striker/anvil-adjust-vnet",
				'anvil-kick-apc-ups'	=>	"/sbin/striker/anvil-kick-apc-ups",
				'anvil-safe-start'	=>	"/sbin/striker/anvil-safe-start",
				# This is the actual DRBD wait script
				'anvil-wait-for-drbd'	=>	"/sbin/striker/anvil-wait-for-drbd",
				backups			=>	"/root/backups",
				bcn_bond1_config	=>	"/etc/sysconfig/network-scripts/ifcfg-bcn_bond1",
				bcn_link1_config	=>	"/etc/sysconfig/network-scripts/ifcfg-bcn_link1",
				bcn_link2_config	=>	"/etc/sysconfig/network-scripts/ifcfg-bcn_link2",
				cat			=>	"/bin/cat",
				cluster_conf		=>	"/etc/cluster/cluster.conf",
				cron_root		=>	"/var/spool/cron/root",
				drbd			=>	"/etc/drbd.d",
				drbd_global_common	=>	"/etc/drbd.d/global_common.conf",
				drbd_r0			=>	"/etc/drbd.d/r0.res",
				drbd_r1			=>	"/etc/drbd.d/r1.res",
				drbdadm			=>	"/sbin/drbdadm",
				fstab			=>	"/etc/fstab",
				getsebool		=>	"/usr/sbin/getsebool",
				'grep'			=>	"/bin/grep",
				# This stores this node's UUID. It is used to track all our sensor data in the 
				# database. If you change this here, change it in the ScanCore, too.
				host_uuid		=>	"/etc/striker/host.uuid",
				hostname		=>	"/etc/sysconfig/network",
				hosts			=>	"/etc/hosts",
				ifcfg_directory		=>	"/etc/sysconfig/network-scripts/",
				ifn_bond1_config	=>	"/etc/sysconfig/network-scripts/ifcfg-ifn_bond1",
				ifn_bridge1_config	=>	"/etc/sysconfig/network-scripts/ifcfg-ifn_bridge1",
				ifn_link1_config	=>	"/etc/sysconfig/network-scripts/ifcfg-ifn_link1",
				ifn_link2_config	=>	"/etc/sysconfig/network-scripts/ifcfg-ifn_link2",
				iptables		=>	"/etc/sysconfig/iptables",
				lvm_conf		=>	"/etc/lvm/lvm.conf",
				MegaCli64		=>	"/opt/MegaRAID/MegaCli/MegaCli64",
				network_scripts		=>	"/etc/sysconfig/network-scripts",
				ntp_conf		=>	"/etc/ntp.conf",
				perl_library		=>	"/usr/share/perl5",
				post_install		=>	"/root/post_install",
				'anvil-safe-start'	=>	"/sbin/striker/anvil-safe-start",
				# Used to verify it was enabled properly.
				'anvil-safe-start_link'	=>	"/etc/rc3.d/S99_anvil-safe-start",
				scancore		=>	"/sbin/striker/ScanCore/ScanCore",
				sed			=>	"/bin/sed",
				setsebool		=>	"/usr/sbin/setsebool",
				shadow			=>	"/etc/shadow",
				shared_subdirectories	=>	["definitions", "provision", "archive", "files", "status"],
				sn_bond1_config		=>	"/etc/sysconfig/network-scripts/ifcfg-sn_bond1",
				sn_link1_config		=>	"/etc/sysconfig/network-scripts/ifcfg-sn_link1",
				sn_link2_config		=>	"/etc/sysconfig/network-scripts/ifcfg-sn_link2",
				storcli64		=>	"/opt/MegaRAID/storcli/storcli64",
				striker_config		=>	"/etc/striker/striker.conf",
				striker_tarball		=>	"/sbin/striker/striker_tools.tar.bz2",
				tar			=>	"/bin/tar",
				udev_net_rules		=>	"/etc/udev/rules.d/70-persistent-net.rules",
				udev_vnet_rules		=>	"/etc/udev/rules.d/99-anvil-adjust-vnet.rules",
				# This is the LSB wrapper.
				'wait-for-drbd'		=>	"/sbin/striker/wait-for-drbd",
				'wait-for-drbd_initd'	=>	"/etc/init.d/wait-for-drbd",
			},
		},
		args			=>	{
			check_dvd		=>	"--dvd --no-cddb --no-device-info --no-disc-mode --no-vcd",
			rsync			=>	"-av --partial",
		},
		# Things set here are meant to be overwritable by the user in striker.conf.
		scancore			=>	{
			language		=>	"en_CA",
			log_level		=>	2,
			log_language		=>	"en_CA",
		},
		sys			=>	{
			# Some actions, like powering off servers and nodes, have a timeout set so that 
			# later, reloading the page doesn't reload a previous confirmation URL and reinitiate
			# the power off when it wasn't desired. This defines that timeout in seconds.
			actime_timeout		=>	180,
			### NOTE: If you change these, also change in anvil-kick-apc-ups!
			apc			=>	{
				reboot			=>	{
					power_off_delay		=>	60,
					sleep_time		=>	60,
				},
				'shutdown'		=>	{
					power_off_delay		=>	60,
				},
			},
			auto_populate_ssh_users	=>	"",
			backup_url		=>	"/striker-backup_#!hostname!#_#!date!#.txt",
			clustat_timeout		=>	120,
			cluster_conf		=>	"",
			config_read		=>	0,
			daemons			=>	{
				enable			=>	[
					"gpm",		# LSB compliant
					"ipmi",		# NOT LSB compliant! 0 == running, 6 == stopped
					"iptables",	# LSB compliant
					"irqbalance",	# LSB compliant
					#"ksmtuned",	# LSB compliant
					"ktune",	# LSB compliant
					"modclusterd",	# LSB compliant
					"network",	# Does NOT appear to be LSB compliant; returns '0' for 'stopped'
					"ntpd",		# LSB compliant
					"ntpdate", 
					"ricci",	# LSB compliant
					"snmpd",
					"tuned",	# LSB compliant
				],
				disable		=>	[
					"acpid",
					"clvmd",	# Appears to be LSB compliant
					"cman",		# 
					"drbd",		# 
					"gfs2",		# 
					"ip6tables",	# 
					"ipmidetectd",	# Not needed on the Anvil!
					"numad",	# LSB compliant
					"rgmanager",	# 
					"snmptrapd",	# 
					"systemtap",	# 
				],
			},
			date_seperator		=>	"-",			# Should put these in the strings.xml file
			dd_block_size		=>	"1M",
			debug			=>	1,
			# When set to '1', (almost) all external links will be disabled. Useful for sites 
			# without an Internet connection.
			disable_links		=>	0,
			error_limit		=>	10000,
			# This will significantly cut down on the text shown on the screen to make 
			# information more digestable for experts.
			expert_ui		=>	0,
			footer_printed		=>	0,
			html_lang		=>	"en",
			ignore_missing_vm	=>	0,
			# These options control some of the Install Manifest options. They can be overwritten
			# by adding matching  entries is striker.conf.
			install_manifest	=>	{
				'default'		=>	{
					bcn_ethtool_opts		=>	"",
					bcn_network			=>	"10.20.0.0",
					bcn_subnet			=>	"255.255.0.0",
					bcn_defroute			=>	"no",
					cluster_name			=>	"anvil",
					'anvil_drbd_disk_disk-barrier'	=>	"false", 
					'anvil_drbd_disk_disk-flushes'	=>	"false", 
					'anvil_drbd_disk_md-flushes'	=>	"false", 
					'anvil_drbd_options_cpu-mask'	=>	"", 
					'anvil_drbd_net_max-buffers'	=>	"", 
					'anvil_drbd_net_sndbuf-size'	=>	"", 
					'anvil_drbd_net_rcvbuf-size'	=>	"", 
					dns1				=>	"8.8.8.8",
					dns2				=>	"8.8.4.4",
					domain				=>	"",
					ifn_ethtool_opts		=>	"",
					ifn_gateway			=>	"",
					ifn_network			=>	"10.255.0.0",
					ifn_subnet			=>	"255.255.0.0",
					ifn_defroute			=>	"yes",
					'immediate-uptodate'		=>	0,
					library_size			=>	"40",
					library_unit			=>	"GiB",
					mtu_size			=>	1500,
					name				=>	"",
					node1_bcn_ip			=>	"",
					node1_ifn_ip			=>	"",
					node1_ipmi_ip			=>	"",
					node1_name			=>	"",
					node1_sn_ip			=>	"",
					node2_bcn_ip			=>	"",
					node2_ifn_ip			=>	"",
					node2_ipmi_ip			=>	"",
					node2_name			=>	"",
					node2_sn_ip			=>	"",
					node1_pdu1_outlet		=>	"",
					node1_pdu2_outlet		=>	"",
					node1_pdu3_outlet		=>	"",
					node1_pdu4_outlet		=>	"",
					node2_pdu1_outlet		=>	"",
					node2_pdu2_outlet		=>	"",
					node2_pdu3_outlet		=>	"",
					node2_pdu4_outlet		=>	"",
					ntp1				=>	"",
					ntp2				=>	"",
					open_vnc_ports			=>	100,
					password			=>	"Initial1",
					pdu1_name			=>	"",
					pdu1_ip				=>	"",
					pdu1_agent			=>	"",
					pdu2_name			=>	"",
					pdu2_ip				=>	"",
					pdu2_agent			=>	"",
					pdu3_name			=>	"",
					pdu3_ip				=>	"",
					pdu3_agent			=>	"",
					pdu4_name			=>	"",
					pdu4_ip				=>	"",
					pdu4_agent			=>	"",
					pool1_size			=>	"100",
					pool1_unit			=>	"%",
					prefix				=>	"",
					pts1_ip				=>	"",
					pts1_name			=>	"",
					pts2_ip				=>	"",
					pts2_name			=>	"",
					repositories			=>	"",
					sequence			=>	"01",
					ssh_keysize			=>	8191,
					sn_ethtool_opts			=>	"",
					sn_network			=>	"10.10.0.0",
					sn_subnet			=>	"255.255.0.0",
					sn_defroute			=>	"no",
					striker_database		=>	"scancore",
					striker_user			=>	"striker",
					striker1_bcn_ip			=>	"",
					striker1_ifn_ip			=>	"",
					striker1_name			=>	"",
					striker1_user			=>	"",	# Defaults to 'striker_user' if not set
					striker2_bcn_ip			=>	"",
					striker2_ifn_ip			=>	"",
					striker2_name			=>	"",
					striker2_user			=>	"",	# Defaults to 'striker_user' if not set
					switch1_ip			=>	"",
					switch1_name			=>	"",
					switch2_ip			=>	"",
					switch2_name			=>	"",
					ups1_ip				=>	"",
					ups1_name			=>	"",
					ups2_ip				=>	"",
					ups2_name			=>	"",
					'use_anvil-kick-apc-ups'	=>	0,
					'use_anvil-safe-start'		=>	1,
					use_scancore			=>	0,
				},
				# If the user wants to build install manifests for environments with 4 PDUs,
				# this will be set to '4'.
				pdu_count		=>	2,
				# This sets the default fence agent to use for the PDUs.
				pdu_fence_agent		=>	"fence_apc_snmp",
				# These variables control whether certain fields are displayed or not when 
				# generating Install Manifests. If you set any of these to '0', please be 
				# sure to have an appropriate default set above.
				show			=>	{
					### Primary
					prefix_field		=>	1,
					sequence_field		=>	1,
					domain_field		=>	1,
					password_field		=>	1,
					bcn_network_fields	=>	1,
					sn_network_fields	=>	1,
					ifn_network_fields	=>	1,
					library_fields		=>	1,
					pool1_fields		=>	1,
					repository_field	=>	1,
					
					### Shared
					name_field		=>	1,
					dns_fields		=>	1,
					ntp_fields		=>	1,
					
					### Foundation pack
					switch_fields		=>	1,
					ups_fields		=>	1,
					pdu_fields		=>	1,
					pts_fields		=>	1,
					dashboard_fields	=>	1,
					
					### Nodes
					nodes_name_field	=>	1,
					nodes_bcn_field		=>	1,
					nodes_ipmi_field	=>	1,
					nodes_sn_field		=>	1,
					nodes_ifn_field		=>	1,
					nodes_pdu_fields	=>	1,
					
					# Control tests/output shown when the install runs. Mainly useful 
					# when a site will never have Internet access.
					internet_check		=>	1,
					rhn_checks		=>	1,
				},
				# This sets anvil-kick-apc-ups to start on boot
				'use_anvil-kick-apc-ups' =>	0,
				# This controls whether anvil-safe-start is enabled or not.
				'use_anvil-safe-start'	=>	1,
				# This controls whether ScanCore will run on boot or not.
				use_scancore		=>	1,
			},
			language		=>	"en_CA",
			log_language		=>	"en_CA",
			log_level		=>	2,
			lvm_conf		=>	"",
			lvm_filter		=>	"filter = [ \"a|/dev/drbd*|\", \"r/.*/\" ]",
			# This allows for custom MTU sizes in an Install Manifest
			mtu_size		=>	1500,
			# This tells the install manifest generator how many ports to open on the IFN for 
			# incoming VNC connections
			node_names		=>	[],
			online_nodes		=>	0,
			os_variant		=>	[
				"win7#!#Microsoft Windows 7",
				"win7#!#Microsoft Windows 8",
				"vista#!#Microsoft Windows Vista",
				"winxp64#!#Microsoft Windows XP (x86_64)",
				"winxp#!#Microsoft Windows XP",
				"win2k#!#Microsoft Windows 2000",
				"win2k8#!#Microsoft Windows Server 2008 (R2)",
				"win2k8#!#Microsoft Windows Server 2012 (R2)",
				"win2k3#!#Microsoft Windows Server 2003",
				"openbsd4#!#OpenBSD 4.x",
				"freebsd8#!#FreeBSD 8.x",
				"freebsd7#!#FreeBSD 7.x",
				"freebsd6#!#FreeBSD 6.x",
				"solaris9#!#Sun Solaris 9",
				"solaris10#!#Sun Solaris 10",
				"opensolaris#!#Sun OpenSolaris",
				"netware6#!#Novell Netware 6",
				"netware5#!#Novell Netware 5",
				"netware4#!#Novell Netware 4",
				"msdos#!#MS-DOS",
				"generic#!#Generic",
				"debianjessie#!#Debian Jessie",
				"debianwheezy#!#Debian Wheezy",
				"debiansqueeze#!#Debian Squeeze",
				"debianlenny#!#Debian Lenny",
				"debianetch#!#Debian Etch",
				"fedora18#!#Fedora 23",
				"fedora18#!#Fedora 22",
				"fedora18#!#Fedora 21",
				"fedora18#!#Fedora 20",
				"fedora18#!#Fedora 19",
				"fedora18#!#Fedora 18",
				"fedora17#!#Fedora 17",
				"fedora16#!#Fedora 16",
				"fedora15#!#Fedora 15",
				"fedora14#!#Fedora 14",
				"fedora13#!#Fedora 13",
				"fedora12#!#Fedora 12",
				"fedora11#!#Fedora 11",
				"fedora10#!#Fedora 10",
				"fedora9#!#Fedora 9",
				"fedora8#!#Fedora 8",
				"fedora7#!#Fedora 7",
				"fedora6#!#Fedora Core 6",
				"fedora5#!#Fedora Core 5",
				"mageia1#!#Mageia 1 and later",
				"mes5.1#!#Mandriva Enterprise Server 5.1 and later",
				"mes5#!#Mandriva Enterprise Server 5.0",
				"mandriva2010#!#Mandriva Linux 2010 and later",
				"mandriva2009#!#Mandriva Linux 2009 and earlier",
				"rhel7#!#Red Hat Enterprise Linux 7",
				"rhel6#!#Red Hat Enterprise Linux 6",
				"rhel5.4#!#Red Hat Enterprise Linux 5.4 or later",
				"rhel5#!#Red Hat Enterprise Linux 5",
				"rhel4#!#Red Hat Enterprise Linux 4",
				"rhel3#!#Red Hat Enterprise Linux 3",
				"rhel2.1#!#Red Hat Enterprise Linux 2.1",
				"sles11#!#Suse Linux Enterprise Server 11",
				"sles10#!#Suse Linux Enterprise Server",
				"opensuse12#!#openSuse 12",
				"opensuse11#!#openSuse 11",
				"ubuntuquantal#!#Ubuntu 12.10 (Quantal Quetzal)",
				"ubuntuprecise#!#Ubuntu 12.04 LTS (Precise Pangolin)",
				"ubuntuoneiric#!#Ubuntu 11.10 (Oneiric Ocelot)",
				"ubuntunatty#!#Ubuntu 11.04 (Natty Narwhal)",
				"ubuntumaverick#!#Ubuntu 10.10 (Maverick Meerkat)",
				"ubuntulucid#!#Ubuntu 10.04 LTS (Lucid Lynx)",
				"ubuntukarmic#!#Ubuntu 9.10 (Karmic Koala)",
				"ubuntujaunty#!#Ubuntu 9.04 (Jaunty Jackalope)",
				"ubuntuintrepid#!#Ubuntu 8.10 (Intrepid Ibex)",
				"ubuntuhardy#!#Ubuntu 8.04 LTS (Hardy Heron)",
				"virtio26#!#Generic 2.6.25 or later kernel with virtio",
				"generic26#!#Generic 2.6.x kernel",
				"generic24#!#Generic 2.4.x kernel",
			],
			output			=>	"web",
			pool1_shrunk		=>	0,
			# When shutting down the nodes prior to power-cycling or powering off the entire
			# rack, instead of the nodes being marked 'clean' off (which would leave them off
			# until a human turned them on), the 'host_stop_reason' is set to unix-time + this
			# number of seconds. When the dashboard sees this time set, it will not boot the
			# nodes until time > host_stop_reason. This way, the nodes will not be powered on
			# before the UPS shuts off.
			# NOTE: Be sure that this time is greater than the UPS shutdown delay!
			power_off_delay		=>	300,
			reboot_timeout		=>	600,
			root_password		=>	"",
			# Set this to an integer to have the main Striker page and the hardware status pages 
			# automatically reload.
			reload_page_timer	=>	0,
			# These options allow customization of newly provisioned servers.
			### If you change these, change the matching values in striker-installer so that it 
			### stays in sync.
			scancore_database	=>	"scancore",
			striker_user		=>	"admin",
			server			=>	{
				nic_count		=>	1,
				alternate_nic_model	=>	"e1000",
				minimum_ram		=>	67108864,
				bcn_nic_driver		=>	"",
				sn_nic_driver		=>	"",
				ifn_nic_driver		=>	"",
			},
			shared_fs_uuid		=>	"",
			show_nodes		=>	0,
			show_refresh		=>	1,
			skin			=>	"alteeve",
			striker_uid		=>	$<,
			system_timezone		=>	"America/Toronto",
			time_seperator		=>	":",
			# ~3 GiB, but in practice more because it will round down the available RAM before 
			# subtracting this to leave the user with an even number of GiB of RAM to allocate to
			# servers.
			unusable_ram		=>	(3 * (1024 ** 3)),
			up_nodes		=>	0,
			update_os		=>	1,
			use_24h			=>	1,			# Set to 0 for am/pm time, 1 for 24h time
			username		=>	getpwuid( $< ),
			# If a user wants to use spice + qxl for video in VMs, set this to '1'. NOTE: This 
			# disables web-based VNC!
# 			use_spice_graphics	=>	1,
			version			=>	"2.0.0a",
			# Adds: [--disablerepo='*' --enablerepo='striker*'] if
			# no internet connection found.
			yum_switches		=>	"-y",		
		},
		# Tools default valies
		tools				=>	{
			'anvil-kick-apc-ups'	=>	{
				enabled			=>	0,
			},
			'anvil-safe-start'	=>	{
				enabled			=>	0,
			},
			'striker-push-ssh'	=>	{
				enabled			=>	0,
			},
		},
		# Config values needed to managing strings
		strings				=>	{
			encoding			=>	"",
			force_utf8			=>	1,
			xml_version			=>	"",
		},
		# The actual strings
		string				=>	{},
		url				=>	{
			skins				=>	"/skins",
			cgi				=>	"/cgi-bin",
		},
	};
	
	return($conf);
}

# Check to see if the global settings have been setup.
sub check_global_settings
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "check_global_settings" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $global_set = 1;
	
	# Pull out the current config.
	my $smtp__server              = $conf->{smtp}{server}; 			# mail.alteeve.ca
	my $smtp__port                = $conf->{smtp}{port};			# 587
	my $smtp__username            = $conf->{smtp}{username};		# example@alteeve.ca
	my $smtp__password            = $conf->{smtp}{password};		# Initial1
	my $smtp__security            = $conf->{smtp}{security};		# STARTTLS
	my $smtp__encrypt_pass        = $conf->{smtp}{encrypt_pass};		# 1
	my $smtp__helo_domain         = $conf->{smtp}{helo_domain};		# example.com
	my $mail_data__to             = $conf->{mail_data}{to};			# you@example.com
	my $mail_data__sending_domain = $conf->{mail_data}{sending_domain};	# example.com
	
	# TODO: Make this smarter... For now, just check the SMTP username to see if it is default.
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "smtp__username", value1 => $smtp__username,
	}, file => $THIS_FILE, line => __LINE__});
	if ((not $smtp__username) or ($smtp__username =~ /example\.com/))
	{
		# Not configured yet.
		$global_set = 0;
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "global_set", value1 => $global_set,
	}, file => $THIS_FILE, line => __LINE__});
	return($global_set);
}

1;
