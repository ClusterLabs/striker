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


# This function simply holds all the potential CGI variable names.
sub read_in_cgi_variables
{
	my ($conf) = @_;
	
	AN::Cluster::get_cgi_vars($conf, [
		"adapter",
		"anvil",
		"anvil_bcn_ethtool_opts",
		"anvil_bcn_network",
		"anvil_bcn_subnet",
		"anvil_dns1",
		"anvil_dns2",
		"anvil_domain",
		"anvil_drbd_disk_disk-barrier", 
		"anvil_drbd_disk_disk-flushes", 
		"anvil_drbd_disk_md-flushes", 
		"anvil_drbd_options_cpu-mask", 
		"anvil_drbd_net_max-buffers", 
		"anvil_drbd_net_sndbuf-size", 
		"anvil_drbd_net_rcvbuf-size", 
		"anvil_fence_order",
		"anvil_id",
		"anvil_ifn_ethtool_opts",
		"anvil_ifn_gateway",
		"anvil_ifn_network",
		"anvil_ifn_subnet",
		"anvil_media_library_size",
		"anvil_media_library_unit",
		"anvil_mtu_size",
		"anvil_name",
		"anvil_node1_bcn_ip",
		"anvil_node1_bcn_link1_mac",
		"anvil_node1_bcn_link2_mac",
		"anvil_node1_current_ip",
		"anvil_node1_current_password",
		"anvil_node1_ifn_ip",
		"anvil_node1_ifn_link1_mac",
		"anvil_node1_ifn_link2_mac",
		"anvil_node1_ipmi_ip",
		"anvil_node1_ipmi_gateway",
		"anvil_node1_ipmi_netmask",
		"anvil_node1_ipmi_password",
		"anvil_node1_ipmi_user",
		"anvil_node1_name",
		"anvil_node1_pdu1_outlet",
		"anvil_node1_pdu2_outlet",
		"anvil_node1_pdu3_outlet",
		"anvil_node1_pdu4_outlet",
		"anvil_node1_sn_ip",
		"anvil_node1_sn_link1_mac",
		"anvil_node1_sn_link2_mac",
		"anvil_node1_uuid",
		"anvil_node2_bcn_ip",
		"anvil_node2_bcn_link1_mac",
		"anvil_node2_bcn_link2_mac",
		"anvil_node2_current_ip",
		"anvil_node2_current_password",
		"anvil_node2_ifn_ip",
		"anvil_node2_ifn_link1_mac",
		"anvil_node2_ifn_link2_mac",
		"anvil_node2_ipmi_ip",
		"anvil_node1_ipmi_gateway",
		"anvil_node2_ipmi_netmask",
		"anvil_node2_ipmi_password",
		"anvil_node2_ipmi_user",
		"anvil_node2_name",
		"anvil_node2_pdu1_outlet",
		"anvil_node2_pdu2_outlet",
		"anvil_node2_pdu3_outlet",
		"anvil_node2_pdu4_outlet",
		"anvil_node2_sn_ip",
		"anvil_node2_sn_link1_mac",
		"anvil_node2_sn_link2_mac",
		"anvil_node2_uuid",
		"anvil_ntp1", 
		"anvil_ntp2", 
		"anvil_open_vnc_ports",
		"anvil_password",
		"anvil_pdu1_ip",
		"anvil_pdu1_name",
		"anvil_pdu1_agent",
		"anvil_pdu2_ip",
		"anvil_pdu2_name",
		"anvil_pdu2_agent",
		"anvil_pdu3_ip",
		"anvil_pdu3_name",
		"anvil_pdu3_agent",
		"anvil_pdu4_ip",
		"anvil_pdu4_name",
		"anvil_pdu4_agent",
		"anvil_prefix",
		"anvil_repositories",
		"anvil_ricci_password",
		"anvil_root_password",
		"anvil_sequence",
		"anvil_ssh_keysize",
		"anvil_sn_ethtool_opts",
		"anvil_sn_network",
		"anvil_sn_subnet",
		"anvil_storage_partition_1_byte_size",
		"anvil_storage_partition_2_byte_size",
		"anvil_storage_pool1_size",
		"anvil_storage_pool1_unit",
		"anvil_striker1_bcn_ip",
		"anvil_striker1_database",
		"anvil_striker1_ifn_ip",
		"anvil_striker1_name",
		"anvil_striker1_user",
		"anvil_striker1_uuid",
		"anvil_striker1_password",
		"anvil_striker2_bcn_ip",
		"anvil_striker2_database",
		"anvil_striker2_ifn_ip",
		"anvil_striker2_name",
		"anvil_striker2_user",
		"anvil_striker2_uuid",
		"anvil_striker2_password",
		"anvil_switch1_ip",
		"anvil_switch1_name",
		"anvil_switch2_ip",
		"anvil_switch2_name",
		"anvil_ups1_ip",
		"anvil_ups1_name",
		"anvil_ups2_ip",
		"anvil_ups2_name",
		"boot_device",
		"change",
		"cluster",
		"config",	# This is used by various things
		"configure",	# This controls the WebUI based Striker Configurator
		"confirm",
		"cpu_cores",
		"delete",
		"device",
		"device_keys",
		"disk_address",
		"do",
		"driver_iso",
		"expire",
		"file",
		"generate",
		"host",
		"insert",
		"install_iso",
		"install_target",
		"load",
		"logical_disk",
		"logo",
		"mail_data__to",
		"mail_data__sending_domain",
		"make_disk_good",
		"max_cores",
		"max_ram",
		"max_storage",
		"name",
		"node",
		"node_cluster_name",
		"os_variant",
		"perform_install", 
		"ram",
		"ram_suffix",
		"remap_network",
		"rhn_user",
		"rhn_password",
		"row",
		"run",
		"save",
		"section",
		"server_note", 
		"server_migration_type", 
		"server_pre_migration_script", 
		"server_pre_migration_arguments", 
		"server_post_migration_script", 
		"server_post_migration_arguments", 
		"server_start_delay", 
		"server_start_after", 
		"smtp__server", 
		"smtp__port",
		"smtp__username",
		"smtp__password",
		"smtp__helo_domain",
		"smtp__encrypt_pass",
		"smtp__security",
		"save",
		"storage",
		"striker_database",
		"striker_user",
		"system",
		"target",
		"task",
		"subtask",
		"update_manifest",
		"vg_list",
		"vm",
		"vm_ram",
	]);
	
	return(0);
}

# This creates an 'expect' script for an rsync call.
sub create_rsync_wrapper
{
	my ($conf, $node, $password) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "create_rsync_wrapper" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "node", value1 => $node, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $cluster = $conf->{cgi}{cluster};
	my $root_pw = $password ? $password : $conf->{clusters}{$cluster}{root_pw};
	my $shell_call = "
echo '#!/usr/bin/expect' > ~/rsync.$node
echo 'set timeout 3600' >> ~/rsync.$node
echo 'eval spawn rsync \$argv' >> ~/rsync.$node
echo 'expect \"password:\" \{ send \"$root_pw\\n\" \}' >> ~/rsync.$node
echo 'expect eof' >> ~/rsync.$node
chmod 755 ~/rsync.$node;";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		print $_;
	}
	close $file_handle;
	
	return(0);
}

# This checks to see if we've see the peer before and if not, add it's ssh fingerprint to known_hosts.
sub test_ssh_fingerprint
{
	my ($conf, $node, $silent) = @_;
	my $an = $conf->{handle}{an};
	$silent = 0 if not defined $silent;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "test_ssh_fingerprint" }, message_key => "an_variables_0002", message_variables => { 
		name1 => "node",   value1 => $node, 
		name2 => "silent", value2 => $silent, 
	}, file => $THIS_FILE, line => __LINE__});
	
	### NOTE: If the node is rebuilt, this will fail. We can't automate recovery because that would open
	###       up a significant security vulnerability.
	my $failed     = 0;
	my $cluster    = $conf->{cgi}{cluster};
	my $root_pw    = $conf->{clusters}{$cluster}{root_pw};
	my $shell_call = "grep ^\"$node\[, \]\" ~/.ssh/known_hosts -q; echo rc:\$?";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		   $line =~ s/\n/ /g;
		   $line =~ s/\r/ /g;
		   $line =~ s/\s+$//;
		$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
			name1 => "line", value1 => $line,
		}, file => $THIS_FILE, line => __LINE__});
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			if ($rc eq "0")
			{
				$an->Log->entry({log_level => 2, message_key => "log_0029", message_variables => {
					node => $node, 
				}, file => $THIS_FILE, line => __LINE__});
				last;
			}
			elsif (($rc eq "1") or ($rc eq "2"))
			{
				if ($rc eq "1")
				{
					# Add it
					$an->Log->entry({log_level => 2, message_key => "log_0030", message_variables => {
						node => $node, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				else
				{
					# Add it and create ~/.ssh/known_hosts at the same time
					$an->Log->entry({log_level => 2, message_key => "log_0031", message_variables => {
						node => $node, 
					}, file => $THIS_FILE, line => __LINE__});
				}
				# Add fingerprint to known_hosts
				$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
					name1 => "silent", value1 => $silent,
				}, file => $THIS_FILE, line => __LINE__});
				if (not $silent)
				{
					my $message = get_string($conf, {key => "message_0279", variables => {
						node	=>	$node,
					}});
					print template($conf, "common.html", "generic-note", {
						message	=>	$message,
					});
					#print "Trying to add the node: <span class=\"fixed_width\">$node</span>'s ssh fingerprint to my list of known hosts...<br />";
					#print template($conf, "common.html", "shell-output-header");
				}
				my $shell_call = "$conf->{path}{'ssh-keyscan'} $node 2>&1 >> ~/.ssh/known_hosts";
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
				sleep 5;
			}
		}
	}
	close $file_handle;
	
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "failed", value1 => $failed,
	}, file => $THIS_FILE, line => __LINE__});
	return($failed);
}

# This simply sorts out the current directory the program is running in.
sub get_current_directory
{
	my ($conf) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_current_directory" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $current_dir = "/var/www/html/";
	if ($ENV{DOCUMENT_ROOT})
	{
		$current_dir = $ENV{DOCUMENT_ROOT};
	}
	elsif ($ENV{CONTEXT_DOCUMENT_ROOT})
	{
		$current_dir = $ENV{CONTEXT_DOCUMENT_ROOT};
	}
	elsif ($ENV{PWD})
	{
		$current_dir = $ENV{PWD};
	}
	
	return($current_dir);
}

# This takes a string key and returns the string for the currently active language.
sub get_string
{
	my ($conf, $vars) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "get_string" }, message_key => "tools_log_0002", file => $THIS_FILE, line => __LINE__});
	
	my $key       = $vars->{key};
	my $language  = $vars->{language}  ? $vars->{language}  : $conf->{sys}{language};
	my $variables = $vars->{variables} ? $vars->{variables} : "";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0003", message_variables => {
		name1 => "key",       value1 => $key,
		name2 => "language",  value2 => $language,
		name3 => "variables", value3 => $variables,
	}, file => $THIS_FILE, line => __LINE__});
	
	if (not $key)
	{
		hard_die($conf, $THIS_FILE, __LINE__, 2, "No string key was passed into common.lib's 'get_string()' function.\n");
	}
	if (not $language)
	{
		hard_die($conf, $THIS_FILE, __LINE__, 3, "No language key was set when trying to build a string in common.lib's 'get_string()' function.\n");
	}
	elsif (not exists $conf->{strings}{lang}{$language})
	{
		hard_die($conf, $THIS_FILE, __LINE__, 4, "The language key: [$language] does not exist in the 'strings.xml' file.\n");
	}
	my $say_language = $language;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "say_language", value1 => $say_language,
	}, file => $THIS_FILE, line => __LINE__});
	if ($conf->{strings}{lang}{$language}{lang}{long_name})
	{
		$say_language = "$language ($conf->{strings}{lang}{$language}{lang}{long_name})";
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "2. say_language", value1 => $say_language,
		}, file => $THIS_FILE, line => __LINE__});
	}
	if (($variables) && (ref($variables) ne "HASH"))
	{
		hard_die($conf, $THIS_FILE, __LINE__, 5, "The 'variables' string passed into common.lib's 'get_string()' function is not a hash reference. The string's data is: [$variables].\n");
	}
	
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "string::lang::${language}::key::${key}::content", value1 => $conf->{strings}{lang}{$language}{key}{$key}{content},
	}, file => $THIS_FILE, line => __LINE__});
	if (not exists $conf->{strings}{lang}{$language}{key}{$key}{content})
	{
		#use Data::Dumper; print Dumper %{$conf->{strings}{lang}{$language}};
		hard_die($conf, $THIS_FILE, __LINE__, 6, "The 'string' generated by common.lib's 'get_string()' function is undefined.<br />This passed string key: '$key' for the language: '$say_language' may not exist in the 'strings.xml' file.\n");
	}
	
	# Grab the string and start cleaning it up.
	my $string = $conf->{strings}{lang}{$language}{key}{$key}{content};
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "1. string", value1 => $string,
	}, file => $THIS_FILE, line => __LINE__});
	
	# This clears off the new-line and trailing white-spaces caused by the
	# indenting of the '</key>' field in the words XML file when printing
	# to the command line.
	$string =~ s/^\n//;
	$string =~ s/\n(\s+)$//;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "2. string", value1 => $string,
	}, file => $THIS_FILE, line => __LINE__});
	
	# Process all the #!...!# escape variables.
	($string) = process_string($conf, $string, $variables);
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "3. string", value1 => $string,
	}, file => $THIS_FILE, line => __LINE__});
	
	return($string);
}

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
	
	# First thing first, initialize the web session.
	initialize_http($conf) if $initialize_http;

	# First up, read in the default strings file.
	read_strings($conf, $conf->{path}{common_strings});
	read_strings($conf, $conf->{path}{striker_strings});
	read_strings($conf, $conf->{path}{scancore_strings});

	# Read in the configuration file. If the file doesn't exist, initial 
	# setup will be triggered.
	read_configuration_file($conf);
	
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
			'striker-delayed-run'	=>	"/sbin/striker/striker-delayed-run",
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
					"numad",	# LSB compliant
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
	
	# TODO: Make this smarter... For now, just check the SMTP username to
	# see if it is default.
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

# At this point in time, all this does is print the content type needed for printing to browsers. '$an' is 
# not set yet here.
sub initialize_http
{
	my ($conf) = @_;
	
	print "Content-type: text/html; charset=utf-8\n\n";
	
	return(0);
}

# This takes a completed string and inserts variables into it as needed.
sub insert_variables_into_string
{
	my ($conf, $string, $variables) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "insert_variables_into_string" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "string", value1 => $string, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $i = 0;
	#print "$THIS_FILE ".__LINE__."; string: [$string], variables: [$variables]\n";
	while ($string =~ /#!variable!(.+?)!#/s)
	{
		my $variable = $1;
		#print "$THIS_FILE ".__LINE__."; variable [$variable]: [$variables->{$variable}]\n";
		if (not defined $variables->{$variable})
		{
			# I can't expect there to always be a defined value in
			# the variables array at any given position so if it's
			# blank I blank the key.
			$string =~ s/#!variable!$variable!#//;
		}
		else
		{
			my $value = $variables->{$variable};
			chomp $value;
			$string =~ s/#!variable!$variable!#/$value/;
		}
		
		# Die if I've looped too many times.
		if ($i > $conf->{sys}{error_limit})
		{
			hard_die($conf, $THIS_FILE, __LINE__, 7, "Infitie loop detected will inserting variables into the string: [$string]. If this is triggered erroneously, increase the 'sys::error_limit' value.\n");
		}
		$i++;
	}
	
	#print "$THIS_FILE ".__LINE__."; << string: [$string]\n";
	return($string);
}

# This reads in the configuration file. '$an' is not set yet here.
sub read_configuration_file
{
	my ($conf) = @_;
	
	my $return_code = 1;
	if (-e $conf->{path}{config_file})
	{
		   $conf->{raw}{config_file} = [];
		   $return_code              = 0;
		my $shell_call               = "$conf->{path}{config_file}";
		open (my $file_handle, "<$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to read: [$shell_call], error was: $!\n";
		#binmode $file_handle, ":utf8:";
		while (<$file_handle>)
		{
			chomp;
			my $line = $_;
			push @{$conf->{raw}{config_file}}, $line;
			next if not $line;
			next if $line !~ /=/;
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			next if $line =~ /^#/;
			next if not $line;
			my ($variable, $value) = (split/=/, $line, 2);
			$variable =~ s/^\s+//;
			$variable =~ s/\s+$//;
			$value    =~ s/^\s+//;
			$value    =~ s/\s+$//;
			next if (not $variable);
			_make_hash_reference($conf, $variable, $value);
		}
		close $file_handle;
	}
	
	return($return_code);
}

# This takes the name of a template file, the name of a template section within the file, an optional hash
# containing replacement variables to feed into the template and an optional hash containing variables to
# pass into strings, and generates a page to display formatted according to the page.
sub template
{
	my ($conf, $file, $template, $replace, $variables, $hide_template_name) = @_;
	my $an = $conf->{handle}{an};
	$replace            = {} if not defined $replace;
	$variables          = {} if not defined $variables;
	$hide_template_name = 0 if not defined $hide_template_name;
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "template" }, message_key => "an_variables_0003", message_variables => { 
		name1 => "file",               value1 => $file, 
		name2 => "template",           value2 => $template, 
		name3 => "hide_template_name", value3 => $hide_template_name, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my @contents;
	# Down the road, I may want to have different suffixes depending on the
	# user's environment. For now, it'll always be ".html".
	my $current_dir   = get_current_directory($conf);
	my $template_file = $current_dir."/".$conf->{path}{skins}."/".$conf->{sys}{skin}."/".$file;
	
	# Make sure the file exists.
	if (not -e $template_file)
	{
		hard_die($conf, $THIS_FILE, __LINE__, 10, "The template file: [$template_file] does not appear to exist.\n");
	}
	elsif (not -r $template_file)
	{
		my $user  = getpwuid($<);
		hard_die($conf, $THIS_FILE, __LINE__, 11, "The template file: [$template_file] is not readable by the user this program is running as the user: [$user]. Please check the permissions on the template file and it's parent directory.\n");
	}
	
	# Read in the raw template.
	my $in_template = 0;
	my $shell_call  = "$template_file";
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__});
	open (my $file_handle, "<$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to read: [$shell_call], error was: $!\n";
	#binmode $file_handle, ":utf8:";
	while (<$file_handle>)
	{
		chomp;
		my $line = $_;
		
		if ($line =~ /<!-- start $template -->/)
		{
			$in_template = 1;
			next;
		}
		if ($line =~ /<!-- end $template -->/)
		{
			# Once I hit this, I am done.
			$in_template = 0;
			last;
		}
		if ($in_template)
		{
			# Read in the template.
			push @contents, $line;
		}
	}
	close $file_handle;
	
	# Now parse the contents for replacement keys.
	my $page = "";
	if (not $hide_template_name)
	{
		$page .= "<!-- Start template: [$template] from file: [$file] -->\n";
	}
	foreach my $string (@contents)
	{
		# Replace the '#!replace!...!#' substitution keys.
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => ">> string", value1 => $string,
		}, file => $THIS_FILE, line => __LINE__});
		($string) = process_string_replace($conf, $string, $replace, $template_file, $template);
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "<< string", value1 => $string,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Process all the #!...!# escape variables.
		#print "$THIS_FILE ".__LINE__."; >> string: [$string]\n";
		#print __LINE__."; >> file: [$file], template: [$template], string: [$string]\n";
		($string) = process_string($conf, $string, $variables);
		#print __LINE__."; << file: [$file], template: [$template], string: [$string\n";
		#print "$THIS_FILE ".__LINE__."; << string: [$string]\n";
		$page .= "$string\n";
	}
	if (not $hide_template_name)
	{
		$page .= "<!-- End template: [$template] from file: [$file] -->\n\n";
	}
	
	return($page);
}

# Process all the other #!...!# escape variables.
sub process_string
{
	my ($conf, $string, $variables) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "process_string" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "string", value1 => $string, 
	}, file => $THIS_FILE, line => __LINE__});
	
	# Insert variables into #!variable!x!# 
	my $i = 0;
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => ">> string", value1 => $string,
	}, file => $THIS_FILE, line => __LINE__});
	($string) = insert_variables_into_string($conf, $string, $variables);
	$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
		name1 => "<< string", value1 => $string,
	}, file => $THIS_FILE, line => __LINE__});
	
	while ($string =~ /#!(.+?)!#/s)
	{
		# Insert strings that are referenced in this string.
		($string) = process_string_insert_strings($conf, $string, $variables);
		
		# Protect unmatchable keys.
		($string) = process_string_protect_escape_variables($conf, $string, "string");

		# Inject any 'conf' values.
		($string) = process_string_conf_escape_variables($conf, $string);
		
		# Die if I've looped too many times.
		if ($i > $conf->{sys}{error_limit})
		{
			hard_die($conf, $THIS_FILE, __LINE__, 8, "Infitie loop detected will processing escape variables in the string: [$string]. If this is triggered erroneously, increase the 'sys::error_limit' value. If you are a developer or translator, did you use '#!replace!...!#' when you meant to use '#!variable!...!#' in a string key?\n");
		}
		$i++;
	}

	# Restore and unrecognized substitution values.
	($string) = process_string_restore_escape_variables($conf, $string);
	
	if ($string =~ /Etc\/GMT\+0/)
	{
		$conf->{i}++;
		die if $conf->{i} > 10;
	}
	
	return($string);
}

# This looks for #!string!...!# substitution variables.
sub process_string_insert_strings
{
	my ($conf, $string, $variables) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "process_string_insert_strings" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "string", value1 => $string, 
	}, file => $THIS_FILE, line => __LINE__});
	
	#print __LINE__."; A. string: [$string], variables: [$variables]\n";
	while ($string =~ /#!string!(.+?)!#/)
	{
		my $key        = $1;
		#print __LINE__."; B. key: [$key]\n";
		# I don't insert variables into strings here. If a complex
		# string is needed, the user should process it and pass the
		# completed string to the template function as a
		# #!replace!...!# substitution variable.
		#print __LINE__."; >>> string: [$string]\n";
		my $say_string = get_string($conf, {key => $key, variables => $variables});
		#print __LINE__."; C. say_string: [$key]\n";
		if ($say_string eq "")
		{
			$string =~ s/#!string!$key!#/!! [$key] !!/;
		}
		else
		{
			$string =~ s/#!string!$key!#/$say_string/;
		}
		#print __LINE__."; <<< string: [$string]\n";
	}
	
	return($string);
}

# This replaces "conf" escape variables using variables 
sub process_string_conf_escape_variables
{
	my ($conf, $string) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "process_string_conf_escape_variables" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "string", value1 => $string, 
	}, file => $THIS_FILE, line => __LINE__});

	while ($string =~ /#!conf!(.+?)!#/)
	{
		my $key   = $1;
		my $value = "";
		
		# If the key has double-colons, I need to break it up and make
		# each one a key in the multi-dimensional hash.
		if ($key =~ /::/)
		{
			($value) = _get_hash_value_from_string($conf, $key);
		}
		else
		{
			# First dimension
			($value) = defined $conf->{$key} ? $conf->{$key} : "!!Undefined config variable: [$key]!!";
		}
		$string =~ s/#!conf!$key!#/$value/;
	}
	
	# AN::Tools uses '#!data!x!#' instead of '#!conf!x!#', support both.
	while ($string =~ /#!data!(.+?)!#/)
	{
		my $key   = $1;
		my $value = "";
		
		# If the key has double-colons, I need to break it up and make
		# each one a key in the multi-dimensional hash.
		if ($key =~ /::/)
		{
			($value) = _get_hash_value_from_string($conf, $key);
		}
		else
		{
			# First dimension
			($value) = defined $conf->{$key} ? $conf->{$key} : "!!Undefined config variable: [$key]!!";
		}
		$string =~ s/#!data!$key!#/$value/;
	}

	return($string);
}

# Protect unrecognized or unused replacement keys by flipping '#!...!#' to
# '_!|...|!_'. This gets reversed in 'process_string_restore_escape_variables()'.
sub process_string_protect_escape_variables
{
	my ($conf, $string) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "process_string_protect_escape_variables" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "string", value1 => $string, 
	}, file => $THIS_FILE, line => __LINE__});

	foreach my $check ($string =~ /#!(.+?)!#/)
	{
		if (
			($check !~ /^free/)    &&
			($check !~ /^replace/) &&
			($check !~ /^conf/)    &&
			($check !~ /^var/)
		)
		{
			$string =~ s/#!($check)!#/_!\|$1\|!_/g;
		}
	}

	return($string);
}

# This is used by the 'template()' function to insert '#!replace!...!#' replacement variables in templates.
sub process_string_replace
{
	my ($conf, $string, $replace, $template_file, $template) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "process_string_replace" }, message_key => "an_variables_0004", message_variables => { 
		name1 => "string",        value1 => $string, 
		name2 => "replace",       value2 => $replace, 
		name3 => "template_file", value3 => $template_file, 
		name4 => "template",      value4 => $template, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my $i = 0;
	while ($string =~ /#!replace!(.+?)!#/)
	{
		my $key   =  $1;
		my $value =  defined $replace->{$key} ? $replace->{$key} : "!! Undefined replacement key: [$key] !!\n";
		$string   =~ s/#!replace!$key!#/$value/;
		$an->Log->entry({log_level => 3, message_key => "an_variables_0001", message_variables => {
			name1 => "string", value1 => $string,
		}, file => $THIS_FILE, line => __LINE__});
		
		# Die if I've looped too many times.
		if ($i > $conf->{sys}{error_limit})
		{
			hard_die($conf, $THIS_FILE, __LINE__, 12, "Infitie loop detected while replacing '#!replace!...!#' replacement variables in the template file: [$template_file] in the template: [$template]. If this is triggered erroneously, increase the 'sys::error_limit' value.\n");
		}
		$i++;
	}
	
	return($string);
}

# This restores the original escape variable format for escape variables that
# were protected by the 'process_string_protect_escape_variables()' function.
sub process_string_restore_escape_variables
{
	my ($conf, $string)=@_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "process_string_restore_escape_variables" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "string", value1 => $string, 
	}, file => $THIS_FILE, line => __LINE__});

	# Restore and unrecognized substitution values.
	my $i = 0;
	while ($string =~ /_!\|(.+?)\|!_/s)
	{
		my $check  =  $1;
		   $string =~ s/_!\|$check\|!_/#!$check!#/g;
		
		# Die if I've looped too many times.
		if ($i > $conf->{sys}{error_limit})
		{
			hard_die($conf, $THIS_FILE, __LINE__, 9, "Infitie loop detected will restoring protected escape variables in the string: [$string]. If this is triggered erroneously, increase the 'sys::error_limit' value.\n");
		}
		$i++;
	}

	return($string);
}

### NOTE: In this function, I have to check to see if '$an' is defined because very early on, it isn't.
# This reads in the strings XML file.
sub read_strings
{
	my ($conf, $file) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "read_strings" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "file", value1 => $file, 
	}, file => $THIS_FILE, line => __LINE__}) if defined $an;

	my $string_ref = $conf;

	my $in_comment  = 0;	# Set to '1' when in a comment stanza that spans more than one line.
	my $in_data     = 0;	# Set to '1' when reading data that spans more than one line.
	my $closing_key = "";	# While in_data, look for this key to know when we're done.
	my $xml_version = "";	# The XML version of the strings file.
	my $encoding    = "";	# The encoding used in the strings file. Should only be UTF-8.
	my $data        = "";	# The data being read for the given key.
	my $key_name    = "";	# This is a double-colon list of hash keys used to build each hash element.
	
	my $shell_call  = "$file";
	$an->Log->entry({log_level => 2, message_key => "an_variables_0001", message_variables => {
		name1 => "shell_call", value1 => $shell_call,
	}, file => $THIS_FILE, line => __LINE__}) if defined $an;
	open (my $file_handle, "<$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to read: [$shell_call], error was: $!\n";
	if ($conf->{strings}{force_utf8})
	{
		binmode $file_handle, "encoding(utf8)";
	}
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		
		#print "$THIS_FILE ".__LINE__."; line: [$line]\n";
		### Deal with comments.
		# Look for a closing stanza if I am (still) in a comment.
		if (($in_comment) && ( $line =~ /-->/ ))
		{
			$line       =~ s/^(.*?)-->//;
			$in_comment =  0;
		}
		next if ($in_comment);

		# Strip out in-line comments.
		while ($line =~ /<!--(.*?)-->/)
		{
			$line =~ s/<!--(.*?)-->//;
		}

		# See if there is an comment opening stanza.
		if ($line =~ /<!--/)
		{
			$in_comment =  1;
			$line       =~ s/<!--(.*)$//;
		}
		### Comments dealt with.

		### Parse data
		# XML data
		if ($line =~ /<\?xml version="(.*?)" encoding="(.*?)"\?>/)
		{
			$conf->{strings}{xml_version} = $1;
			$conf->{strings}{encoding}    = $2;
			next;
		}

		# If I am not "in_data" (looking for more data for a currently in use key).
		if (not $in_data)
		{
			# Skip blank lines.
			next if $line =~ /^\s+$/;
			next if $line eq "";
			$line =~ s/^\s+//;
			
			# Look for an inline data-structure.
			if (($line =~ /<(.*?) (.*?)>/) && ($line =~ /<\/$1>/))
			{
				# First, look for CDATA.
				my $cdata = "";
				if ($line =~ /<!\[CDATA\[(.*?)\]\]>/)
				{
					$cdata =  $1;
					$line  =~ s/<!\[CDATA\[$cdata\]\]>/$cdata/;
				}
				
				# Pull out the key and name.
				my ($key) = ($line =~ /^<(.*?) /);
				my ($name, $data) = ($line =~ /^<$key name="(.*?)">(.*?)<\/$key>/);
				$data =  $cdata if $cdata;
				_make_hash_reference($string_ref, "${key_name}::${key}::${name}::content", $data);
				next;
			}

			# Look for a self-contained unkeyed structure.
			if (($line =~ /<(.*?)>/) && ($line =~ /<\/$1>/))
			{
				my $key  =  $line;
				   $key  =~ s/<(.*?)>.*/$1/;
				   $data =  $line;
				   $data =~ s/<$key>(.*?)<\/$key>/$1/;
				_make_hash_reference($string_ref, "${key_name}::${key}", $data);
				next;
			}

			# Look for a line with a closing stanza.
			if ($line =~ /<\/(.*?)>/)
			{
				my $closing_key =  $line;
				   $closing_key =~ s/<\/(\w+)>/$1/;
				   $key_name    =~ s/(.*?)::$closing_key(.*)/$1/;
				next;
			}

			# Look for a key with an embedded value.
			if ($line =~ /^<(\w+) name="(.*?)" (\w+)="(.*?)">/)
			{
				my $key   =  $1;
				my $name  =  $2;
				my $key2  =  $3;
				my $data  =  $4;
				$key_name .= "::${key}::${name}";
				_make_hash_reference($string_ref, "${key_name}::${key}::${key2}", $data);
				next;
			}

			# Look for a contained value.
			if ($line =~ /^<(\w+) name="(.*?)">(.*)/)
			{
				my $key  = $1;
				my $name = $2;
				   $data = $3;	# Don't scope locally in case this data spans lines.

				if ($data =~ /<\/$key>/)
				{
					# Fully contained data.
					$data =~ s/<\/$key>(.*)$//;
					_make_hash_reference($string_ref, "${key_name}::${key}::${name}", $data);
				}
				else
				{
					# Element closes later.
					$in_data     =  1;
					$closing_key =  $key;
					$name        =~ s/^<$key name="(\w+).*/$1/;
					$key_name    .= "::${key}::${name}";
					$data        =~ s/^<$key name="$name">(.*)/$1/;
					$data        .= "\n";
				}
				next;
			}

			# Look for an opening data structure.
			if ($line =~ /<(.*?)>/)
			{
				my $key      =  $1;
				   $key_name .= "::$key";
				next;
			}
		}
		else
		{
			if ($line !~ /<\/$closing_key>/)
			{
				$data .= "$line\n";
			}
			else
			{
				$in_data =  0;
				$line    =~ s/(.*?)<\/$closing_key>/$1/;
				$data    .= "$line";

				# If there is CDATA, set it aside.
				my $save_data = "";
				my @lines     = split/\n/, $data;

				my $in_cdata  = 0;
				foreach my $line (@lines)
				{
					if (($in_cdata == 1) && ($line =~ /]]>$/))
					{
						# CDATA closes here.
						$line      =~ s/]]>$//;
						$save_data .= "\n$line";
						$in_cdata  =  0;
					}
					if (($line =~ /^<\!\[CDATA\[/) && ($line =~ /]]>$/))
					{
						# CDATA opens and closes in this line.
						$line      =~ s/^<\!\[CDATA\[//;
						$line      =~ s/]]>$//;
						$save_data .= "\n$line";
					}
					elsif ($line =~ /^<\!\[CDATA\[/)
					{
						$line     =~ s/^<\!\[CDATA\[//;
						$in_cdata =  1;
					}
					
					if ($in_cdata == 1)
					{
						# Don't analyze, just store.
						$save_data .= "\n$line";
					}
					else
					{
						# Not in CDATA, look for XML data.
						#print "Checking: [$line] for an XML item.\n";
						while (($line =~ /<(.*?)>/) && ($line =~ /<\/$1>/))
						{
							# Found a value.
							my $key  =  $line;
							   $key  =~ s/.*?<(.*?)>.*/$1/;
							   $data =  $line;
							   $data =~ s/.*?<$key>(.*?)<\/$key>/$1/;
							
							#print "Saving: key: [$key], [${key_name}::${key}] -> [$data]\n";
							_make_hash_reference($string_ref, "${key_name}::${key}", $data);
							$line =~ s/<$key>(.*?)<\/$key>//;
						}
						$save_data .= "\n$line";
					}
					#print "$THIS_FILE ".__LINE__."; [$in_cdata] Check: [$line]\n";
				}

				$save_data =~ s/^\n//;
				if ($save_data =~ /\S/s)
				{
					#print "$THIS_FILE ".__LINE__."; save_data: [$save_data]\n";
					_make_hash_reference($string_ref, "${key_name}::content", $save_data);
				}

				$key_name =~ s/(.*?)::$closing_key(.*)/$1/;
			}
		}
		next if $line eq "";
	}
	close $file_handle;
	#use Data::Dumper; print Dumper $conf;
	
	return(0);
}

###############################################################################
### Private functions                                                       ###
###############################################################################

### Contributed by Shaun Fryer and Viktor Pavlenko by way of TPM.
# This is a helper to the below '_make_hash_reference' function. It is called
# each time a new string is to be created as a new hash key in the passed hash
# reference.
sub _add_hash_reference
{
	my ($href1, $href2) = @_;

	for my $key (keys %$href2)
	{
		if (ref $href1->{$key} eq 'HASH')
		{
			_add_hash_reference($href1->{$key}, $href2->{$key});
		}
		else
		{
			$href1->{$key} = $href2->{$key};
		}
	}
}

# This is the reverse of '_make_hash_reference()'. It takes a double-colon separated string, breaks it up and
# returns the value stored in the corosponding $conf hash.
sub _get_hash_value_from_string
{
	my ($conf, $key_string) = @_;
	my $an = $conf->{handle}{an};
	$an->Log->entry({log_level => 3, title_key => "tools_log_0001", title_variables => { function => "_get_hash_value_from_string" }, message_key => "an_variables_0001", message_variables => { 
		name1 => "key_string", value1 => $key_string, 
	}, file => $THIS_FILE, line => __LINE__});
	
	my @keys      = split /::/, $key_string;
	my $last_key  = pop @keys;
	my $this_href = $conf;
	while (my $key = shift @keys)
	{
		$this_href = $this_href->{$key};
	}
	
	my $value = defined $this_href->{$last_key} ? $this_href->{$last_key} : "!!Undefined config variable: [$key_string]!!";
	
	return($value);
}

### Contributed by Shaun Fryer and Viktor Pavlenko by way of TPM.
# This takes a string with double-colon seperators and divides on those
# double-colons to create a hash reference where each element is a hash key.
sub _make_hash_reference
{
	my ($href, $key_string, $value) = @_;

	my @keys            = split /::/, $key_string;
	my $last_key        = pop @keys;
	my $_href           = {};
	$_href->{$last_key} = $value;
	while (my $key = pop @keys)
	{
		my $elem      = {};
		$elem->{$key} = $_href;
		$_href        = $elem;
	}
	_add_hash_reference($href, $_href);
}

1;
