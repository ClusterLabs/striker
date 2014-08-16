#!/usr/bin/perl
#

use strict;
use warnings;
use IO::Handle;

$| = 1;

my $conf = {
	answers		=>	{
		customer_prefix	=>	"xx",
		customer_domain	=>	"example.com",
		cluster_id	=>	"01",
		node_id		=>	"01",
		bcn_ip		=>	"10.20.",
		bcn_netmask	=>	"255.255.0.0",
		sn_ip		=>	"10.10.",
		sn_netmask	=>	"255.255.0.0",
		ifn_ip		=>	"10.255.",
		ifn_netmask	=>	"255.255.0.0",
		ifn_gateway	=>	"10.255.255.254",
		ifn_dg		=>	"yes",
		ifn2_ip		=>	"10.254.",
		ifn2_netmask	=>	"255.255.0.0",
		ifn2_gateway	=>	"10.254.255.254",
		ifn2_dg		=>	"no",
		ipmi_ip		=>	"10.20.",
		ipmi_netmask	=>	"255.255.0.0",
		dns1		=>	"8.8.8.8",
		dns2		=>	"8.8.4.4",
	},
	apps		=>	{
		install		=>	[
			"cman",
			"corosync",
			"rgmanager",
			"ricci",
			"freeipmi",
			"freeipmi-bmc-watchdog",
			"freeipmi-ipmidetectd",
			"gd",
			"gfs2-utils",
			"gpm",
			"ntp",
			"libvirt",
			"lvm2-cluster",
			"OpenIPMI",
			"OpenIPMI-libs",
			"OpenIPMI-perl",
			"OpenIPMI-tools",
			"qemu-kvm",
			"qemu-kvm-tools",
			"virt-install",
			"virt-viewer",
			"syslinux", 
			"wget",
			"gpm",
			"rsync",
			"screen",
		],
		remove		=>	[
			"NetworkManager",
		],
		enable		=>	[
			"ipmi",
			"iptables",
			"ntpd",
			"ricci",
			"modclusterd",
			"gpm",
		],
		disable		=>	[
			"kdump",
			"NetworkManager",
			"ip6tables",
			"drbd",
			"clvmd",
			"gfs2",
			"cman",
			"rgmanager",
		],
		from_http	=>	{
			apcupsd		=>	"https://alteeve.ca/cluster/apcupsd-latest.el6.x86_64.rpm",
		},
		repos		=>	{
			elrepo		=>	{
				key		=>	"http://elrepo.org/RPM-GPG-KEY-elrepo.org",
				rpm		=>	"http://elrepo.org/elrepo-release-6-4.el6.elrepo.noarch.rpm",
				install		=>	["drbd83-utils", "kmod-drbd83"],
			},
		},
	},
	'system'	=>	{
		ntp_server	=>	"tick.redhat.com",
	},
	commands	=>	{
		'ssh-keygen'	=>	"ssh-keygen -t rsa -N \"\" -b 4095 -f ~/.ssh/id_rsa",
	},
	files		=>	{
		answers		=>	"an-cluster_setup.txt",
	},
	nic		=>	{
		count		=>	0,
		ifn_count	=>	1,
	},
};

print "\n-=] AN!Cluster Configuration\n\n";

### TODO: If this is a RHEL box, ask the user to authenticate before
###       proceeding.

collect_data($conf);
ask_questions($conf);
#disable_selinux($conf);
setup_ssh($conf);
install_apps($conf);
setup_ntpd($conf);
disable_libvirt_bridge($conf);
install_acpupsd($conf);
modify_daemons($conf);
set_text_boot($conf);

print "Initial configuration is complete!\n";
print "Manual tasks remaining;\n\n";
print " - Manually create the ~/.ssh/authorized_keys file.\n";
print " - Merge /etc/hosts and add foundation pack devices.\n";
print " - Create the DRBD partition(s)\n";
print " - Reboot and run the following;\n";
print "passwd\n";
print "passwd ricci\n";
print "modprobe drbd\n";
print "drbdadm create-md r{0,1}\n";
print "drbdadm attach r{0,1}\n";
print "drbdadm connect r{0,1}\n";
print "On one node only:\n";
print "drbdadm -- --clear-bitmap new-current-uuid r{0,1}\n";
print "On both:\n";
print "drbdadm primary r{0,1}\n";
print "
pvcreate /dev/drbd{0,1}
vgcreate -c y n01_vg0 /dev/drbd0
vgcreate -c y n02_vg0 /dev/drbd1
lvcreate -L 40G -n shared n01_vg0
mkfs.gfs2 -p lock_dlm -j 2 -t $conf->{answers}{customer_prefix}-cluster-$conf->{answers}{cluster_id}:shared /dev/n01_vg0/shared
mkdir /shared
mount /dev/n01_vg0/shared /shared/
echo `gfs2_tool sb /dev/n01_vg0/shared uuid | awk '/uuid =/ { print $4; }' | sed -e \"s/\(.*\)/UUID=\\L\1\\E \/shared\\t\\tgfs2\\tdefaults,noatime,nodiratime\\t0 0/\"` >> /etc/fstab
/etc/init.d/gfs2 status
";

###############################################################################
# Functions                                                                   #
###############################################################################

sub install_acpupsd
{
	my ($conf) = @_;
	
	my $apcupsd_rpm    = $conf->{apps}{from_http}{apcupsd};
	
	# UPS 0
	my $aps0_name      = "an-u01";
	my $ups0_addr      = "10.20.3.1";
	my $ups0_port      = "161";
	my $ups0_vendor    = "APC_NOTRAP";
	my $ups0_community = "private";
	my $ups0_polltime  = "30";
	my $ups0_nisport   = "6551";
	my $ups0_events    = "/var/log/apcupsd.0.events";
	
	# UPS 1
	my $aps1_name      = "an-u02";
	my $ups1_addr      = "10.20.3.2";
	my $ups1_port      = "161";
	my $ups1_vendor    = "APC_NOTRAP";
	my $ups1_community = "private";
	my $ups1_polltime  = "30";
	my $ups1_nisport   = "6552";
	my $ups1_events    = "/var/log/apcupsd.1.events";
=pod
	rpm -Uvh $apcupsd_rpm
	mkdir /etc/apcupsd/null
	cp /etc/apcupsd/apcupsd.conf      /etc/apcupsd/apcupsd.conf.orig
	mv /etc/apcupsd/apcupsd.conf      /etc/apcupsd/apcupsd.ups0.conf
	cp /etc/apcupsd/apcupsd.ups0.conf /etc/apcupsd/apcupsd.ups1.conf
	cp /etc/init.d/apcupsd            /root/apcupsd.init.orig
	
	### Modify ups 0
	#UPSNAME				->	UPSNAME $aps0_name
	UPSTYPE apcsmart			->	UPSTYPE snmp
	DEVICE /dev/ttyS0			->	DEVICE $ups0_addr:$ups0_port:$ups0_vendor:$ups0_community
	#POLLTIME 60				->	POLLTIME $ups0_polltime
	BATTERYLEVEL 5				->	BATTERYLEVEL 0
	MINUTES 3				->	MINUTES 0
	SCRIPTDIR /etc/apcupsd			->	SCRIPTDIR /etc/apcupsd/null
	PWRFAILDIR /etc/apcupsd			->	PWRFAILDIR /etc/apcupsd/null
	NOLOGINDIR /etc				->	NOLOGINDIR /etc/apcupsd/null
	NISPORT 3551				->	NISPORT $ups0_nisport
	EVENTSFILE /var/log/apcupsd.events	->	EVENTSFILE $ups0_events
	
	### modify ups 1
	#UPSNAME				->	UPSNAME $aps1_name
	UPSTYPE apcsmart			->	UPSTYPE snmp
	DEVICE /dev/ttyS0			->	DEVICE $ups1_addr:$ups1_port:$ups1_vendor:$ups1_community
	#POLLTIME 60				->	POLLTIME $ups1_polltime
	BATTERYLEVEL 5				->	BATTERYLEVEL 0
	MINUTES 3				->	MINUTES 0
	SCRIPTDIR /etc/apcupsd			->	SCRIPTDIR /etc/apcupsd/null
	PWRFAILDIR /etc/apcupsd			->	PWRFAILDIR /etc/apcupsd/null
	NOLOGINDIR /etc				->	NOLOGINDIR /etc/apcupsd/null
	NISPORT 3551				->	NISPORT $ups1_nisport
	EVENTSFILE /var/log/apcupsd.events	->	EVENTSFILE $ups1_events
	
	### Modify the init.d script
	rm -f /etc/init.d/apcupsd
	wget https://alteeve.ca/files/apcupsd -O /etc/init.d/apcupsd
	chmod 755 /etc/init.d/apcupsd
	/etc/init.d/apcupsd start
	chkconfig apcupsd on
	
	### Verify that both UPSes are accessible
	apcaccess status localhost:$ups0_nisport
		# grep for;
		
=cut
	
	return(0);
}

sub disable_selinux
{
	my ($conf) = @_;
	
	print "Disabling SELinux\n";
	my $sc = "setenforce 0 && sed -i 's/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config";
	my $fh = IO::Handle->new();
	open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
	while(<$fh>)
	{
		chomp;
		my $line = $_;
		print " - $line\n";
	}
	$fh->close();
	print "Done.\n";
	
	return (0);
}

sub disable_libvirt_bridge
{
	my ($conf) = @_;
	
	print "Disabling the libvirtd default bridge\n";
	
	# First see if the bridge is up
	my $up = 0;
	my $sc = "ifconfig -a";
	my $fh = IO::Handle->new();
	open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
	while(<$fh>)
	{
		chomp;
		my $line = $_;
		if ($line =~ /^virbr\d+:/)
		{
			$up = 1;
			last;
		}
	}
	$fh->close();
	
	if ($up)
	{
		print " - The libvirtd bridge appears to be up, disabling it.\n";
		my $sc = "virsh net-destroy default && virsh net-autostart default --disable && virsh net-undefine default && /etc/init.d/iptables stop";
		my $fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
			print " - $line\n";
		}
		$fh->close();
	}
	else
	{
		print " - The libvirtd bridge appears to not be up, deleting it.\n";
		my $sc = "cat /dev/null >/etc/libvirt/qemu/networks/default.xml";
		my $fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
			print " - $line\n";
		}
		$fh->close();
	}
	
	print "Done.\n";
	
	
	return(0);
}

sub set_text_boot
{
	my ($conf) = @_;
	
	print "Configuring the operating system for textual booting.\n";
	print "This can take a minute, please be patient.\n";
	my $sc = "plymouth-set-default-theme details -R";
	my $fh = IO::Handle->new();
	open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
	while(<$fh>)
	{
		chomp;
		my $line = $_;
		#print " - $line\n"
	}
	$fh->close();
	print "Done.\n";
	
	return(0);
}

sub modify_daemons
{
	my ($conf) = @_;
	
	# Disable daemons
	foreach my $daemon (sort {$a cmp $b} @{$conf->{apps}{disable}})
	{
		next if not $daemon;
		print "Disabling: [$daemon]";
		my $sc = "chkconfig $daemon off && /etc/init.d/$daemon stop";
		my $fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
			print " - $line\n"
		}
		$fh->close();
		print "Done.\n";
	}
	
	# Enable daemons
	foreach my $daemon (sort {$a cmp $b} @{$conf->{apps}{enable}})
	{
		next if not $daemon;
		print "Enabling: [$daemon]";
		my $sc = "chkconfig $daemon on && /etc/init.d/$daemon start";
		my $fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
			print " - $line\n"
		}
		$fh->close();
		print "Done.\n";
	}
	
	return(0);
}

sub setup_ntpd
{
	my ($conf) = @_;
	
	# If the NTP server IP is already in the file, skip.
	print "This next step will configure the network time server.\n";
	my $ntp_server = $conf->{'system'}{ntp_server};
	my $done = 0;
	my $sc = "/etc/ntp.conf";
	my $fh = IO::Handle->new();
	open ($fh, "<$sc") or die "Failed to read: [$sc], error: $!\n";
	while(<$fh>)
	{
		chomp;
		my $line = $_;
		if ($line =~ /$ntp_server/)
		{
			$done = 1;
			last;
		}
	}
	$fh->close();
	
	if ($done)
	{
		print "The NTP server: [$ntp_server] is already in: [/etc/ntpd.conf], skipping.\n";
		return (0);
	}
	
	# Ask the user before proceeding.
	print "Proceed? [y/N] ";
	my $proceed = <STDIN>;
	#my $proceed = "y";
	chomp($proceed);
	if ((lc($proceed) eq "y") or (lc($proceed) eq "yes"))
	{
		print "Proceeding... ";
		my $sc = "echo \"server $ntp_server\" >> /etc/ntp.conf && echo \"restrict $ntp_server mask 255.255.255.255 nomodify notrap noquery\" >> /etc/ntp.conf";
		my $fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
			#print "| $line\n"
		}
		$fh->close();
		print "Done.\n";
	}
	else
	{
		print "Skipping\n";
	}
	
	return(0);
}

sub install_apps
{
	my ($conf) = @_;
	
	# Read all currently installed packages.
	read_installed_rpms($conf);
	
	# First, install
	my $install = "";
	foreach my $install_app (sort {$a cmp $b} @{$conf->{apps}{install}})
	{
		# Is the app already installed?
		next if not $install_app;
		if (ref($conf->{installed_apps}) ne "HASH")
		{
			# No, add it.
			$install .= "$install_app ";
		}
	}
	
	# Proceed with the install if any packages are not yet installed.
	if ($install)
	{
		print "Installing missing applications.\n";
		my $sc = "yum -y install $install";
		my $fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
		print "/----------\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
			print "| $line\n"
		}
		$fh->close();
		print "\\----------\n";
		print "Done.\n";
	}
	
	# Now add repos and install their packages.
	foreach my $repo (sort {$a cmp $b} keys %{$conf->{apps}{repos}})
	{
		my $key           = $conf->{apps}{repos}{$repo}{key};
		my $rpm           = $conf->{apps}{repos}{$repo}{rpm};
		my $install_array = $conf->{apps}{repos}{$repo}{install};
		
		print "Installing the: [$repo] repository key.\n";
		my $sc = "rpm --import $key";
		print "Calling: [$sc]\n";
		my $fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
			print " - $line\n"
		}
		$fh->close();
		print "Done.\n";
		
		print "Installing the: [$repo] repository RPM.\n";
		$sc = "rpm -Uvh $rpm";
		print "Calling: [$sc]\n";
		$fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
		print "/----------\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
			print "| $line\n"
		}
		$fh->close();
		print "\\----------\n";
		print "Done.\n";
	
		# First, install
		$install = "";
		foreach my $install_app (sort {$a cmp $b} @{$install_array})
		{
			next if not $install_app;
			$install .= "$install_app ";
		}
		if ($install)
		{
			print "Installing the: [$repo] repository package(s).\n";
			my $sc = "yum -y install $install";
			print "Calling: [$sc]\n";
			my $fh = IO::Handle->new();
			open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
			print "/----------\n";
			while(<$fh>)
			{
				chomp;
				my $line = $_;
				print "| $line\n"
			}
			$fh->close();
			print "\\----------\n";
			print "Done.\n";
		}
	}
	
	# Update the OS
	print "Updating the operating system.\n";
	my $sc = "yum -y update";
	my $fh = IO::Handle->new();
	open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
	print "/----------\n";
	while(<$fh>)
	{
		chomp;
		my $line = $_;
		print "| $line\n"
	}
	$fh->close();
	print "\\----------\n";
	print "Done.\n";
	
	# Grab the DRBD fence agent.
	if (not -e "/sbin/rhcs_fence")
	{
		print "Installing the DRBD fence handler\n";
		my $sc = "wget -c https://raw.github.com/digimer/rhcs_fence/master/rhcs_fence -O /sbin/rhcs_fence && chmod 755 /sbin/rhcs_fence && ls -lah /sbin/rhcs_fence";
		my $fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
		print "/----------\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
			print "| $line\n"
		}
		$fh->close();
		print "\\----------\n";
		print "Done.\n";
	}
	
	### TODO: Update this to edit the default files. Create a downloadable
	###       version with substitution keys.
	# Grab the default DRBD config files
	if (not -e "/etc/drbd.d/global_common.conf.orig")
	{
		print "Installing the DRBD initial config files.\n";
		my $sc = "mv /etc/drbd.d/global_common.conf /etc/drbd.d/global_common.conf.orig && wget -c https://alteeve.ca/files/global_common.conf -O /etc/drbd.d/global_common.conf && wget -c https://alteeve.ca/files/r0.res -O /etc/drbd.d/r0.res";
		my $fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
		print "/----------\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
			print "| $line\n"
		}
		$fh->close();
		print "\\----------\n";
		print "Done.\n";
	}
	
	# Setup clustered LVM.
	if (not -e "/etc/lvm/lvm.conf.orig")
	{
		print "Installing the clustered LVM configuration file.\n";
		my $sc = "mv /etc/lvm/lvm.conf /etc/lvm/lvm.conf.orig && wget -c https://alteeve.ca/files/lvm.conf -O /etc/lvm/lvm.conf";
		my $fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
		print "/----------\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
			print "| $line\n"
		}
		$fh->close();
		print "\\----------\n";
		print "Done.\n";
	}
	
	return (0);
}

sub read_installed_rpms
{
	my ($conf) = @_;
	
	my $sc = "yum list installed";
	my $fh = IO::Handle->new();
	open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
	while(<$fh>)
	{
		chomp;
		my $line = $_;
		if ($line =~ /^(\S+)\s+(\S+)\s+(\@.*)/)
		{
			my $rpm  = $1;
			my $ver  = $2;
			my $repo = $3;
			
			my ($app, $arch) = ($rpm =~ /^(.*?)\.(.*)/);
			
			$conf->{installed_apps}{$app}{arch} = $arch;
			$conf->{installed_apps}{$app}{ver}  = $ver;
			$conf->{installed_apps}{$app}{repo} = $repo;
		}
	}
	$fh->close();
	
	return (0);
}

sub read_answers
{
	my ($conf) = @_;
	
	return if not -e $conf->{files}{answers};
	
	my $sc = "$conf->{files}{answers}";
	my $fh = IO::Handle->new();
	open ($fh, "<$sc") or die "Failed to read: [$sc], error: $!\n";
	while(<$fh>)
	{
		chomp;
		my $line = $_;
		if ($line =~ /answer:(.*?)#!#(.*)/)
		{
			my $var = $1;
			my $val = $2;
			$conf->{answers}{$var} = $val;
		}
	}
	$fh->close();
	
	return(0);
}

sub write_answers
{
	my ($conf) = @_;
	
	my $sc = "$conf->{files}{answers}";
	my $fh = IO::Handle->new();
	open ($fh, ">$sc") or die "Failed to write: [$sc], error: $!\n";
	foreach my $var (sort {$a cmp $b} keys %{$conf->{answers}})
	{
		print $fh "answer:$var#!#$conf->{answers}{$var}\n";
	}
	$fh->close();
	
	return(0);
}

sub ask_questions
{
	my ($conf) = @_;
	read_answers($conf);
	
	print "\nNOTE: There is _no_ sanity checking of answers yet. Please answer carefully.\n\n";
	
	print "What is the customer's two or three letter prefix?\n - [$conf->{answers}{customer_prefix}] ";
	my $customer_prefix = <STDIN>;
	chomp($customer_prefix);
	$conf->{answers}{customer_prefix} = $customer_prefix if $customer_prefix;
	write_answers($conf);
	
	print "What is the customer's domain?\n - [$conf->{answers}{customer_domain}] ";
	my $customer_domain = <STDIN>;
	chomp($customer_domain);
	$conf->{answers}{customer_domain} = $customer_domain if $customer_domain;
	write_answers($conf);
	
	print "What is the cluster sequence ID number?\n - [$conf->{answers}{cluster_id}] ";
	my $cluster_id = <STDIN>;
	chomp($cluster_id);
	if ($cluster_id)
	{
		$cluster_id = sprintf("%02d", $cluster_id);
	}
	$conf->{answers}{cluster_id} = $cluster_id if $cluster_id;
	write_answers($conf);
	
	print "What is the node's sequence ID number?\n - [$conf->{answers}{node_id}] ";
	my $node_id = <STDIN>;
	chomp($node_id);
	if ($node_id)
	{
		$node_id = sprintf("%02d", $node_id);
	}
	$conf->{answers}{node_id} = $node_id if $node_id;
	write_answers($conf);
	
	# IP addresses. If the IPs is only two octals, use the cluster ID to
	# set the third octal.
	my $third_octal  =  $conf->{answers}{cluster_id};
	   $third_octal  =~ s/^0+//;
	   $third_octal  .= "0";
	my $fourth_octal =  $conf->{answers}{node_id};
	   $fourth_octal =~ s/^0+//;
	if ($conf->{answers}{bcn_ip} =~ /^\d+\.\d+\.$/)
	{
		$conf->{answers}{bcn_ip} .= "${third_octal}.${fourth_octal}";
	}
	if ($conf->{answers}{ipmi_ip} =~ /^\d+\.\d+\.$/)
	{
		my $this_third_octal = $third_octal + 1;
		$conf->{answers}{ipmi_ip} .= "${this_third_octal}.${fourth_octal}";
	}
	if ($conf->{answers}{sn_ip} =~ /^\d+\.\d+\.$/)
	{
		$conf->{answers}{sn_ip} .= "${third_octal}.${fourth_octal}";
	}
	if ($conf->{answers}{ifn_ip} =~ /^\d+\.\d+\.$/)
	{
		$conf->{answers}{ifn_ip} .= "${third_octal}.${fourth_octal}";
	}
	if ($conf->{answers}{ifn2_ip} =~ /^\d+\.\d+\.$/)
	{
		$conf->{answers}{ifn2_ip} .= "${third_octal}.${fourth_octal}";
	}
	
	# Back-Channel Network
	print "What IP address would you like to use for the BCN?\n - [$conf->{answers}{bcn_ip}] ";
	my $bcn_ip = <STDIN>;
	chomp($bcn_ip);
	$conf->{answers}{bcn_ip} = $bcn_ip if $bcn_ip;
	write_answers($conf);
	
	print "What subnet mask would you like to use for the BCN?\n - [$conf->{answers}{bcn_netmask}] ";
	my $bcn_netmask = <STDIN>;
	chomp($bcn_netmask);
	$conf->{answers}{bcn_netmask} = $bcn_netmask if $bcn_netmask;
	write_answers($conf);
	
	# IPMI Interface
	print "What IP address would you like to use for the IPMI BMC?\n - [$conf->{answers}{ipmi_ip}] ";
	my $ipmi_ip = <STDIN>;
	chomp($ipmi_ip);
	$conf->{answers}{ipmi_ip} = $ipmi_ip if $ipmi_ip;
	write_answers($conf);
	
	print "What subnet mask would you like to use for the IPMI BMC?\n - [$conf->{answers}{ipmi_netmask}] ";
	my $ipmi_netmask = <STDIN>;
	chomp($ipmi_netmask);
	$conf->{answers}{ipmi_netmask} = $ipmi_netmask if $ipmi_netmask;
	write_answers($conf);
	
	# Storage Network
	print "What IP address would you like to use for the SN?\n - [$conf->{answers}{sn_ip}] ";
	my $sn_ip = <STDIN>;
	chomp($sn_ip);
	$conf->{answers}{sn_ip} = $sn_ip if $sn_ip;
	write_answers($conf);
	
	print "What subnet mask would you like to use for the SN?\n - [$conf->{answers}{sn_netmask}] ";
	my $sn_netmask = <STDIN>;
	chomp($sn_netmask);
	$conf->{answers}{sn_netmask} = $sn_netmask if $sn_netmask;
	write_answers($conf);
	
	### TODO: Add "first" to "IFN"
	# Internet-Facing Network
	print "What IP address would you like to use for the IFN?\n - [$conf->{answers}{ifn_ip}] ";
	my $ifn_ip = <STDIN>;
	chomp($ifn_ip);
	$conf->{answers}{ifn_ip} = $ifn_ip if $ifn_ip;
	write_answers($conf);
	
	print "What subnet mask would you like to use for the IFN?\n - [$conf->{answers}{ifn_netmask}] ";
	my $ifn_netmask = <STDIN>;
	chomp($ifn_netmask);
	$conf->{answers}{ifn_netmask} = $ifn_netmask if $ifn_netmask;
	write_answers($conf);
	
	print "What gateway would you like to use for the IFN?\n - [$conf->{answers}{ifn_gateway}] ";
	my $ifn_gateway = <STDIN>;
	chomp($ifn_gateway);
	$conf->{answers}{ifn_gateway} = $ifn_gateway if $ifn_gateway;
	write_answers($conf);
	
	print "Will the IFN be the default gateway?\n - [$conf->{answers}{ifn_dg}] ";
	my $ifn_dg = <STDIN>;
	chomp($ifn_dg);
	$conf->{answers}{ifn_dg} = $ifn_dg if $ifn_dg;
	write_answers($conf);
	
	print "What will be the first DNS server?\n - [$conf->{answers}{dns1}] ";
	my $dns1 = <STDIN>;
	chomp($dns1);
	$conf->{answers}{dns1} = $dns1 if $dns1;
	write_answers($conf);
	
	print "What will be the second DNS server?\n - [$conf->{answers}{dns2}] ";
	my $dns2 = <STDIN>;
	chomp($dns2);
	$conf->{answers}{dns2} = $dns2 if $dns2;
	write_answers($conf);
	
	### TODO: More sensibly support a second IFN.
	my $two_ifn = 0;
	if ($two_ifn)
	{
		# Internet-Facing Network B
		print "What IP address would you like to use for the second IFN?\n - [$conf->{answers}{ifn2_ip}] ";
		my $ifn2_ip = <STDIN>;
		chomp($ifn2_ip);
		$conf->{answers}{ifn2_ip} = $ifn2_ip if $ifn2_ip;
		write_answers($conf);
		
		print "What subnet mask would you like to use for the second IFN?\n - [$conf->{answers}{ifn2_netmask}] ";
		my $ifn2_netmask = <STDIN>;
		chomp($ifn2_netmask);
		$conf->{answers}{ifn2_netmask} = $ifn2_netmask if $ifn2_netmask;
		write_answers($conf);
		
		print "What gateway would you like to use for the second IFN?\n - [$conf->{answers}{ifn2_gateway}] ";
		my $ifn2_gateway = <STDIN>;
		chomp($ifn2_gateway);
		$conf->{answers}{ifn2_gateway} = $ifn2_gateway if $ifn2_gateway;
		write_answers($conf);
		
		print "Will the second IFN be the default gateway?\n - [$conf->{answers}{ifn2_dg}] ";
		my $ifn2_dg = <STDIN>;
		chomp($ifn2_dg);
		$conf->{answers}{ifn2_dg} = $ifn2_dg if $ifn2_dg;
		write_answers($conf);
	}
	
	$conf->{answers}{hostname} = "$conf->{answers}{customer_prefix}-c".$conf->{answers}{cluster_id}."n".$conf->{answers}{node_id}.".".$conf->{answers}{customer_domain};;
	write_answers($conf);
	print "\nSummary;\n";
	print " - Customer prefix: [$conf->{answers}{customer_prefix}]\n";
	print " - Customer domain: [$conf->{answers}{customer_domain}]\n";
	print " - Cluster ID:      [$conf->{answers}{cluster_id}]\n";
	print " - Node ID:         [$conf->{answers}{node_id}]\n";
	print " - Host Name:       [$conf->{answers}{hostname}]\n";
	print " - BCN Network:     [".sprintf("%-15s", $conf->{answers}{bcn_ip})." / $conf->{answers}{bcn_netmask}]\n";
	print " - IPMI Network:    [".sprintf("%-15s", $conf->{answers}{ipmi_ip})." / $conf->{answers}{ipmi_netmask}]\n";
	print " - SN Network:      [".sprintf("%-15s", $conf->{answers}{sn_ip})." / $conf->{answers}{sn_netmask}]\n";
	print " - IFN Network:     [".sprintf("%-15s", $conf->{answers}{ifn_ip})." / $conf->{answers}{ifn_netmask}]\n";
	if ($two_ifn)
	{
		print " - IFN B Network:   [$conf->{answers}{ifn2_ip} / $conf->{answers}{ifn2_netmask}]\n";
	}
	
	print "Proceed? [y/N] ";
	my $proceed = <STDIN>;
	#my $proceed = "y";
	chomp($proceed);
	if ((lc($proceed) eq "y") or (lc($proceed) eq "yes"))
	{
		print "Proceeding.\n";
	}
	else
	{
		print "Returning to questions.\n";
		ask_questions($conf);
	}
	
	if (1)
	{
		# Write the file and then set the active hostname.
		print "Recording and setting the host name... ";
		my $file = "/etc/sysconfig/network";
		my $sc = $file;
		my $fh = IO::Handle->new();
		open ($fh, ">$file") or die "Failed to write: [$sc], error: $!\n";
		print $fh "NETWORKING=yes\n";
		print $fh "HOSTNAME=$conf->{answers}{hostname}\n";
		$fh->close();
		
		$sc = "hostname $conf->{answers}{hostname}";
		$fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
		}
		$fh->close();
		print "Done.\n";
	}
	
	configure_nics($conf);
	
	write_hosts($conf);
	
	return(0);
}

sub write_hosts
{
	my ($conf) = @_;
	
	print "Writing the hosts file... ";
	if (not -e "/etc/hosts.an")
	{
		print " - Backing up the original /etc/hosts as /etc/hosts.an: \n";
		my $sc = "rsync -av /etc/hosts /etc/hosts.an";
		my $fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
			print "."
		}
		$fh->close();
		print " Done.\n";
	}
	
	my $say_bcn_ip     = $conf->{answers}{bcn_ip};
	my $say_ipmi_ip    = $conf->{answers}{ipmi_ip};
	my $say_sn_ip      = $conf->{answers}{sn_ip};
	my $say_ifn_ip     = $conf->{answers}{ifn_ip};
	my $say_hostname   = $conf->{answers}{hostname};
	my $short_hostname = ($say_hostname =~ /^(.*?)\./)[0];
	
	my $file = "/etc/hosts";
	my $sc = $file;
	my $fh = IO::Handle->new();
	open ($fh, ">>$file") or die "Failed to append: [$sc], error: $!\n";
	print $fh "\n";
	print $fh "# Cluster $conf->{answers}{cluster_id}, Node $conf->{answers}{node_id}\n";
	print $fh "$say_bcn_ip\t$short_hostname ${short_hostname}.bcn $say_hostname\n";
	print $fh "$say_ipmi_ip\t${short_hostname}.ipmi\n";
	print $fh "$say_sn_ip\t${short_hostname}.sn\n";
	print $fh "$say_ifn_ip\t${short_hostname}.ifn\n";
	$fh->close();
	
	$sc = "hostname $say_hostname";
	$fh = IO::Handle->new();
	open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
	while(<$fh>)
	{
		chomp;
		my $line = $_;
	}
	$fh->close();
	print "Done.\n";
	
	return(0);
}

sub configure_nics
{
	my ($conf) = @_;
	
	print "\n-=] NIC configuration\n\n";
	if ($conf->{nic}{count} > 6)
	{
		$conf->{nic}{ifn_count} = 2;
	}
	if (0)
	{
		foreach my $nic (sort {$a cmp $b} keys %{$conf->{nic}})
		{
			# Skip entries that aren't actually NICs.
			#print "NIC: [$nic] (".ref($conf->{nic}{$nic}).")\n";
			next if ref($conf->{nic}{$nic}) ne "HASH";
			#print " - NIC: [$nic]\n";
			my $say_mac = uc($conf->{nic}{$nic}{mac});
			my $say_ip  = $conf->{nic}{$nic}{ip} ? $conf->{nic}{$nic}{ip} : "--";
			my $say_nm  = $conf->{nic}{$nic}{nm} ? $conf->{nic}{$nic}{nm} : "--";
			print " - nic: [$nic], MAC: [$say_mac], current IP: [$say_ip / $say_nm]\n";
		}
	}
	
	### TODO: If the file exists, ask if the user wants to re-run the
	###       network config. If so, pull down and remove the bonds and
	###       bridges.
	# Here I check for one of the bond files. If I don't see it, I assume
	# the configuration tool has not been run yet, so I will ask the user
	# to un/plug each NIC.
	if (not -e "/etc/sysconfig/network-scripts/ifcfg-bond0")
	{
		# First, re-write all of the network configuration files to
		# the initial format.
		print "I found: [$conf->{nic}{count}] NICs; IFN Count: [$conf->{nic}{ifn_count}].\n";
		if (backup_ifcfg_files($conf))
		{
			foreach my $nic (sort {$a cmp $b} keys %{$conf->{nic}})
			{
				next if ref($conf->{nic}{$nic}) ne "HASH";
				my $file = "/etc/sysconfig/network-scripts/ifcfg-$nic";
				print "Re-writing the config for: [$nic]... ";
				my $say_mac = uc($conf->{nic}{$nic}{mac});
				my $say_ip  = $conf->{nic}{$nic}{ip} ? $conf->{nic}{$nic}{ip} : "";
				my $proto = "none";
				if ($say_ip)
				{
					# configure for dhcp.
					$proto = "dhcp";
				}
				my $sc = $file;
				my $fh = IO::Handle->new();
				open ($fh, ">$file") or die "Failed to write: [$sc], error: $!\n";
				print $fh "# Temporary configuration written by AN!Cluster Setup.\n";
				print $fh "# Original copy stored as: /root/network-scripts.orig/ifcfg-$nic.\n";
				print $fh "HWADDR=\"$say_mac\"\n";
				print $fh "DEVICE=\"$nic\"\n";
				print $fh "NM_CONTROLLED=\"no\"\n";
				print $fh "ONBOOT=\"yes\"\n";
				print $fh "BOOTPROTO=\"$proto\"\n";
				$fh->close();
				print "Done.\n";
			}
		
			# Now restart networking to ensure all NICs are currently up.
			restart_network($conf);
		}
		else
		{
			print "It looks like the original interface configuration files were backed up and rewritten already. Skipping.\n";
		}
		
		# Read the last line in the syslog file.
		my ($last_line) = read_syslog($conf, "");
		
		print "It appears that we have not reordered the NICs yet.\n";
		for (my $i = 0; $i < $conf->{nic}{count}; $i++)
		{
			my $current_nic    = "";
			my $desired_nic = "eth$i";
			my $done        = 0;
			print "Please unplug the interface you wish to make: [$desired_nic]\n";
			while (not $done)
			{
				sleep 1;
				my ($this_last_line) = read_syslog($conf, $last_line);
				#print "Does: old last line: [$last_line]\n";
				#print "and: new last line:  [$this_last_line] differ?\n";
				if ($this_last_line ne $last_line)
				{
					#print "New data, parsing: [".@{$conf->{syslog}{new_lines}}."] new lines.\n";
					# Parse the new lines looking for interface notes.
					foreach my $line (@{$conf->{syslog}{new_lines}})
					{
						#print "new line: [$line]\n";
						if ($line =~ /\s(\S+?) NIC Link is Down/)
						{
							$current_nic = $1;
							print " - That appears to be: [$current_nic]. Shall I move this to: [$desired_nic]? [Y/n] ";
							my $proceed = <STDIN>;
							#my $proceed = "y";
							chomp($proceed);
							if ((lc($proceed) eq "n") or (lc($proceed) eq "no"))
							{
								print " - Skipping. Please unplug the interface you wish to make: [$desired_nic]\n";
							}
							else
							{
								print " - Selected. Please plug the cable back in.\n";
								$conf->{map_nic}{$desired_nic} = $current_nic;
								$done = 1;
								last;
							}
						}
					}
					$last_line = $this_last_line;
				}
				else
				{
					#print "Same. NEXT!\n";
				}
			}
		}
		
		foreach my $desired_nic (sort {$a cmp $b} keys %{$conf->{map_nic}})
		{
			my $current_nic = $conf->{map_nic}{$desired_nic};
			my $desired_mac = uc($conf->{nic}{$current_nic}{mac});
			print "Moving interface with MAC: [$desired_mac] from: [$current_nic] to: [$desired_nic]\n";
			$conf->{new_nic}{$desired_nic} = $desired_mac;
		}
		
		# Shut down the network and delete udev file.
		print "\n##############################################################################\n";
		print "The next step will take down the network and (likely) change the IP address.\n";
		print "If you are running this via ssh, be sure to be running in 'screen'. Otherwise,\n";
		print "this program will die in the middle of modifying the network and likely leave\n";
		print "you with no remote access at all!\n";
		print "##############################################################################\n\n";
		print "Proceed? [y/N] ";
		my $proceed = <STDIN>;
		#my $proceed = "y";
		chomp($proceed);
		if ((lc($proceed) eq "y") or (lc($proceed) eq "yes"))
		{
			print "Proceeding... ";
			my $sc = "/etc/init.d/network stop && rm -f /etc/udev/rules.d/70-persistent-net.rules";
			my $fh = IO::Handle->new();
			open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
			while(<$fh>)
			{
				chomp;
				my $line = $_;
			}
			$fh->close();
			print "Done.\n";
		}
		else
		{
			print "Aborting. Please restart at your leisure and re-run this program.\n";
			exit(1);
		}
		
		foreach my $nic (sort {$a cmp $b} keys %{$conf->{new_nic}})
		{
			my $file = "/etc/sysconfig/network-scripts/ifcfg-$nic";
			print "Re-writing the config for: [$nic]... ";
			my $say_mac = uc($conf->{new_nic}{$nic});
			my $say_ip  = $conf->{nic}{$nic}{ip} ? $conf->{nic}{$nic}{ip} : "";
			my $proto = "none";
			if ($say_ip)
			{
				# configure for dhcp.
				$proto = "dhcp";
			}
			my $comment = "";
			my $bond    = "";
			if ($conf->{nic}{ifn_count} == 1)
			{
				if ($nic eq "eth0")    { $bond = "bond0"; $comment = "Back-Channel Network - Link 1"; }
				elsif ($nic eq "eth1") { $bond = "bond1"; $comment = "Storage Network - Link 1"; }
				elsif ($nic eq "eth2") { $bond = "bond2"; $comment = "Internet-Facing Network - Link 1"; }
				elsif ($nic eq "eth3") { $bond = "bond0"; $comment = "Back-Channel Network - Link 2"; }
				elsif ($nic eq "eth4") { $bond = "bond1"; $comment = "Storage Network - Link 2"; }
				elsif ($nic eq "eth5") { $bond = "bond2"; $comment = "Internet-Facing Network - Link 2"; }
				else { die "Unknown NIC: [$nic]\n"; }
			}
			elsif ($conf->{nic}{ifn_count} == 2)
			{
				if ($nic eq "eth0")    { $bond = "bond0"; $comment = "Back-Channel Network - Link 1"; }
				elsif ($nic eq "eth1") { $bond = "bond1"; $comment = "Storage Network - Link 1"; }
				elsif ($nic eq "eth2") { $bond = "bond2"; $comment = "Internet-Facing Network A - Link 1"; }
				elsif ($nic eq "eth3") { $bond = "bond3"; $comment = "Internet-Facing Network B - Link 1"; }
				elsif ($nic eq "eth4") { $bond = "bond0"; $comment = "Back-Channel Network - Link 2"; }
				elsif ($nic eq "eth5") { $bond = "bond1"; $comment = "Storage Network - Link 2"; }
				elsif ($nic eq "eth6") { $bond = "bond2"; $comment = "Internet-Facing Network A - Link 2"; }
				elsif ($nic eq "eth7") { $bond = "bond3"; $comment = "Internet-Facing Network B - Link 2"; }
				else { die "Unknown NIC: [$nic]\n"; }
			}
			else
			{
				die "Unknown number of IFNs: [$conf->{nic}{ifn_count}]\n";
			}
			my $sc = $file;
			my $fh = IO::Handle->new();
			open ($fh, ">$file") or die "Failed to write: [$sc], error: $!\n";
			print $fh "# $comment\n";
			print $fh "HWADDR=\"$say_mac\"\n";
			print $fh "DEVICE=\"$nic\"\n";
			print $fh "NM_CONTROLLED=\"no\"\n";
			print $fh "ONBOOT=\"yes\"\n";
			print $fh "BOOTPROTO=\"$proto\"\n";
			print $fh "MASTER=\"$bond\"\n";
			print $fh "SLAVE=\"yes\"\n";
			$fh->close();
			print "Done.\n";
		}
		
		if ($conf->{nic}{ifn_count} == 1)
		{
			# One bridge, three bonds.
			for (my $i = 0; $i < 3; $i++)
			{
				my $device = "bond".$i;
				my $file   = "/etc/sysconfig/network-scripts/ifcfg-$device";
				print "Writing the config for: [$device]... ";
				my $sc = $file;
				my $fh = IO::Handle->new();
				open ($fh, ">$file") or die "Failed to write: [$sc], error: $!\n";
				my $primary = "eth0";
				my $comment = "Back-Channel Network - Bond";
				my $bridge  = "";
				my $proto   = "static";
				my $ip      = $conf->{answers}{bcn_ip};
				my $nm      = $conf->{answers}{bcn_netmask};
				if ($i == 1) 
				{
					$primary = "eth1";
					$comment = "Storage Network - Bond";
					$ip      = $conf->{answers}{sn_ip};
					$nm      = $conf->{answers}{sn_netmask};
				}
				elsif ($i == 2)
				{
					$primary = "eth2";
					$comment = "Internet-Facing Network - Bond";
					$ip      = "";
					$nm      = "";
					$proto   = "none";
					$bridge  = "vbr2";
				}
				print $fh "# $comment\n";
				print $fh "DEVICE=\"$device\"\n";
				if ($bridge)
				{
					print $fh "BRIDGE=\"$bridge\"\n";
				}
				print $fh "BOOTPROTO=\"$proto\"\n";
				print $fh "NM_CONTROLLED=\"no\"\n";
				print $fh "ONBOOT=\"yes\"\n";
				print $fh "BONDING_OPTS=\"mode=1 miimon=100 use_carrier=1 updelay=120000 downdelay=0 primary=$primary\"\n";
				if (not $bridge)
				{
					print $fh "IPADDR=\"$ip\"\n";
					print $fh "NETMASK=\"$nm\"\n";
				}
				$fh->close();
				print "Done.\n";
			}
			
			# Write the bridge.
			my $device = "vbr2";
			my $file   = "/etc/sysconfig/network-scripts/ifcfg-$device";
			print "Writing the config for: [$device]... ";
			my $sc = $file;
			my $fh = IO::Handle->new();
			open ($fh, ">$file") or die "Failed to write: [$sc], error: $!\n";
			print $fh "# Internet-Facing Network - Bridge\n";
			print $fh "DEVICE=\"vbr2\"\n";
			print $fh "TYPE=\"Bridge\"\n";
			print $fh "BOOTPROTO=\"static\"\n";
			print $fh "IPADDR=\"$conf->{answers}{ifn_ip}\"\n";
			print $fh "NETMASK=\"$conf->{answers}{ifn_netmask}\"\n";
			print $fh "GATEWAY=\"$conf->{answers}{ifn_gateway}\"\n";
			print $fh "DNS1=\"$conf->{answers}{dns1}\"\n";
			print $fh "DNS2=\"$conf->{answers}{dns2}\"\n";
			print $fh "DEFROUTE=\"$conf->{answers}{ifn_dg}\"\n";
			$fh->close();
			print "Done.\n";
		}
		elsif ($conf->{nic}{ifn_count} == 2)
		{
			# Two bridges, four bonds.
			print "Two IFNs not yet implemented...\n";
		}
		else
		{
			die "Unknown number of IFNs: [$conf->{nic}{ifn_count}]\n";
		}
		
		# Rewrite udev and start the network.
		print "Note: You may safely ignore any errors like:\n";
		print " - \"bonding: cannot add bond bondX; already exists\"\n";
		my $sc = "start_udev && /etc/init.d/network start";
		my $fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
		}
		$fh->close();
		print "Done.\n";
	}
	
	print "The network should now be configured.\n";
	
	return(0);
}

sub read_syslog
{
	my ($conf, $previous_last_line) = @_;
	my $last_line = "";
	
	my $show_message = 1;
	my $record = 0;
	$conf->{syslog}{new_lines} = [];
	
	my $sc = "/var/log/messages";
	my $fh = IO::Handle->new();
	open ($fh, "<$sc") or die "Failed to read: [$sc], error: $!\n";
	while(<$fh>)
	{
		chomp;
		my $line = $_;
		#print "syslog line: [$line]\n";
		if (not $previous_last_line)
		{
			#print "No previous last syslog line. Keeping array empty.\n" if $show_message;
			$show_message = 0;
		}
		elsif ($line eq $previous_last_line)
		{
			#print "Found the last line: [$line], beginning recording.\n";
			$record = 1;
		}
		elsif ($record)
		{
			# I don't want to fill the entire array on first read
			# or else the interface detection code will fire on 
			# every entry.
			push @{$conf->{syslog}{new_lines}}, $line;
		}
		$last_line = $line;
	}
	$fh->close();
	
	#print "Last syslog line: [$last_line]\n";
	return($last_line);
}

sub restart_network
{
	my ($conf) = @_;
	
	print "Restarting the network. This may close ssh sessions. Proceed? [y/N] ";
	my $proceed = <STDIN>;
	#my $proceed = "y";
	chomp($proceed);
	if ((lc($proceed) eq "y") or (lc($proceed) eq "yes"))
	{
		print "Proceeding... ";
	}
	else
	{
		print "Aborting. Please restart at your leisure and re-run this program.\n";
		exit(1);
	}
	
	# Disable network manager
	my $sc = "chkconfig NetworkManager off && chkconfig network on && /etc/init.d/network restart";
	if (not -e "/etc/init.d/NetworkManager")
	{
		$sc = "chkconfig network on && /etc/init.d/network restart";
	}
	my $fh = IO::Handle->new();
	open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
	while(<$fh>)
	{
		chomp;
		my $line = $_;
		print "."
	}
	$fh->close();
	sleep 5;	# Give the NICs time to come up
	print "Done.\n";
	
	return(0);
}

sub backup_ifcfg_files
{
	my ($conf) = @_;
	
	if (-e "/root/network-scripts.orig")
	{
		print "Backup already performed, skipping.\n";
		return(0);
	}
	
	print "Archiving the current interface configuration files in /root/network-scripts.orig.\n";
	my $sc = "rsync -av /etc/sysconfig/network-scripts/* /root/network-scripts.orig";
	my $fh = IO::Handle->new();
	open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
	while(<$fh>)
	{
		chomp;
		my $line = $_;
		print "."
	}
	$fh->close();
	print "Done.\n";
	
	return(1);
}

sub setup_ssh
{
	my ($conf) = @_;
	
	print "Configuring the SSH keys.\n";
	if (-e "/root/.ssh/id_rsa")
	{
		print " - Found an existing key, not generating a new one.\n";
	}
	else
	{
		# Generating a new RSA key.
		print "Generating a new RSA key for the root user.\n";
		my $sc = "ssh-keygen -t rsa -N \"\" -b 4095 -f ~/.ssh/id_rsa";
		my $fh = IO::Handle->new();
		open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
		print "/----------\n";
		while(<$fh>)
		{
			chomp;
			my $line = $_;
			print "| $line\n"
		}
		$fh->close();
		print "\\----------\n";
		print "Done.\n";
	}
	
	return(0);
}

sub collect_data
{
	my ($conf) = @_;
	
	# Get the current host name.
	#foreach my $var (sort {$a cmp $b} keys %ENV) { print "var: [$var] -> [$ENV{$var}]\n"; }
	$conf->{collected}{hostname} = $ENV{HOSTNAME};
	
	# Read the number of NICs.
	get_nic_details($conf);
	
	return(0);
}

sub get_nic_details
{
	my ($conf) = @_;
	
	my $this_nic;
	my $this_mac;
	my $sc = "ifconfig -a";
	my $fh = IO::Handle->new();
	open ($fh, "$sc 2>&1 |") or die "Failed to call: [$sc], error: $!\n";
	while(<$fh>)
	{
		chomp;
		my $line = $_;
		#print "line: [$line]\n";

		# New line == new device.
		if (($line eq "") or ($line =~ /^\s+$/))
		{
			$this_nic = "";
			$this_mac = "";
			#print "clear.\n";
		}

		# EL6-style stuff
		if ($line =~ /^(\S+)\s+.*?HWaddr (.*)/)
		{
			$this_nic = $1;
			$this_mac = $2;
			$this_mac =~ s/\s+$//;
			$conf->{nic}{$this_nic}{mac} = $this_mac;
			$conf->{nic}{count}++;
			#print "found nic: [$this_nic] -> MAC: [$conf->{nic}{$this_nic}{mac} ($this_mac)]\n";
		}
		elsif ($this_nic)
		{
			#print "parsing for NIC: [$this_nic]: [$line]\n";
			if ($line =~ /inet addr:(\d+\.\d+\.\d+\.\d+)/)
			{
				$conf->{nic}{$this_nic}{ip} = $1;
				#print " - IP: [$conf->{nic}{$this_nic}{ip}]\n";
			}
			if ($line =~ /Mask:(\d+\.\d+\.\d+\.\d+)/)
			{
				$conf->{nic}{$this_nic}{nm} = $1;
				#print " - NM: [$conf->{nic}{$this_nic}{nm}]\n";
			}
		}
	}
	$fh->close();
	
	return(0);
}
