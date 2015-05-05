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
# 
# TODO:
# - Add a hidden option to the install manifest for auto-adding RSA keys to
#   /root/.ssh/known_hosts
# - Make the map NIC removal prompt order configurable.
# - Check with fragmentless ping if the MTU is >1500 and error out if the 
#   packet fails. Otherwise, DRBD will blow up.
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
	
	print AN::Common::template($conf, "common.html", "scanning-message");
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-header");
	
	# Some variables we'll need.
	$conf->{packages}{to_install} = {
		acpid				=>	0,
		'bridge-utils'			=>	0,
		ccs				=>	0,
		cman 				=>	0,
		'compat-libstdc++-33.i686'	=>	0,
		corosync			=>	0,
		'cyrus-sasl'			=>	0,
		'cyrus-sasl-plain'		=>	0,
		dmidecode			=>	0,
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
		'kernel-headers'		=>	0,
		'kernel-devel'			=>	0,
		'libstdc++.i686' 		=>	0,
		'libstdc++-devel.i686'		=>	0,
		libvirt				=>	0,
		'lvm2-cluster'			=>	0,
		mailx				=>	0,
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
		pciutils			=>	0,
		perl				=>	0,
		'perl-DBD-Pg'			=>	0,
		'perl-Digest-SHA'		=>	0,
		'perl-TermReadKey'		=>	0,
		'perl-Time-HiRes'		=>	0,
		'perl-Net-SSH2'			=>	0,
		'perl-XML-Simple'		=>	0,
		'policycoreutils-python'	=>	0,
		postgresql			=>	0,
		postfix				=>	0,
		'python-virtinst'		=>	0,
		rgmanager			=>	0,
		ricci				=>	0,
		rsync				=>	0,
		Scanner				=>	0,
		screen				=>	0,
		syslinux			=>	0,
		sysstat				=>	0,
		'vim-enhanced'			=>	0,
		'virt-viewer'			=>	0,
		wget				=>	0,
		
		# These should be more selectively installed based on lspci (or
		# similar) output.
		MegaCli				=>	0,
		storcli				=>	0,
	};
	$conf->{scancore}{scan_agents} = {
		bonding			=>	{
			configuration_body	=>	"
# Bonding Agent config file
# 
# Each config file uses a unique prefix for data. Specify what that
# prefix is, so a single reading routine can handle all the different
# files.
#
name = bond

# Agent metadata
#
bond::db::table::summary	= bonding
bond::db::table::other		= bonding
bond::db::table::alerts		= alerts
bond::host			= #!conf!long_hostname!#
bond::ip			= #!conf!bcn_ip!#
bond::type			= Ethernet Channel Bonding Driver

# The agent will analyze all '*bond1' files in this directory.
bond::dir			= /proc/net/bonding

# specifications for the summary data & various attributes
#
bond::summary::max		= 100
bond::summary::ok		= 0
bond::summary::warn		= 4
bond::summary::hysteresis	= 0

# ----------------------------------------------------------------------
# End of file.
",
			configuration_file	=>	"bonding.conf",
			enabled			=>	1,
		},
		db			=>	{
			configuration_body	=>	"
db::1::name		= $conf->{cgi}{anvil_striker1_database}
db::1::db_type		= Pg
db::1::host		= $conf->{cgi}{anvil_striker1_bcn_ip}
db::1::port		= 5432
db::1::user		= $conf->{cgi}{anvil_striker1_user}
db::1::password		= $conf->{cgi}{anvil_striker1_password}

db::2::name		= $conf->{cgi}{anvil_striker2_database}
db::2::db_type		= Pg
db::2::host		= $conf->{cgi}{anvil_striker2_bcn_ip}
db::2::port		= 5432
db::2::user		= $conf->{cgi}{anvil_striker2_user}
db::2::password		= $conf->{cgi}{anvil_striker2_password}
",
			configuration_file	=>	"db.conf",
			enabled			=>	1,
		},
		ipmi			=>	{
			configuration_body	=>	"
# IPMI config file
#
# Each config file uses a unique prefix for data. Specify what that
# prefix is, so a single reading routine can handle all the different
# files.
#
name					= ipmi

# Agent metadata
#
ipmi::db::table::summary		= ipmi_temperatures
ipmi::db::table::Ambient		= ipmi_temperatures
ipmi::db::table::Systemboard 1		= ipmi_temperatures
ipmi::db::table::Systemboard 2		= ipmi_temperatures
ipmi::db::table::VR CPU1		= ipmi_temperatures
ipmi::db::table::VR MEM AB		= ipmi_temperatures
ipmi::db::table::VR MEM CD		= ipmi_temperatures
ipmi::db::table::VR CPU2		= ipmi_temperatures
ipmi::db::table::VR MEM EF		= ipmi_temperatures
ipmi::db::table::VR MEM GH		= ipmi_temperatures
ipmi::db::table::CPU1			= ipmi_temperatures
ipmi::db::table::CPU2			= ipmi_temperatures
ipmi::db::table::MEM A			= ipmi_temperatures
ipmi::db::table::MEM B			= ipmi_temperatures
ipmi::db::table::MEM C			= ipmi_temperatures
ipmi::db::table::MEM D			= ipmi_temperatures
ipmi::db::table::MEM E			= ipmi_temperatures
ipmi::db::table::MEM F			= ipmi_temperatures
ipmi::db::table::MEM G			= ipmi_temperatures
ipmi::db::table::MEM H			= ipmi_temperatures
ipmi::db::table::PSU1 Inlet		= ipmi_temperatures
ipmi::db::table::PSU2 Inlet		= ipmi_temperatures
ipmi::db::table::PSU1			= ipmi_temperatures
ipmi::db::table::PSU2			= ipmi_temperatures
ipmi::db::table::BBU			= ipmi_temperatures
ipmi::db::table::RAID Controller	= ipmi_temperatures
ipmi::db::table::summary		= ipmi_temperatures
ipmi::db::table::other			= ipmi_temperatures

ipmi::db::table::alerts			= alerts

ipmi::host				= #!conf!long_hostname!#
ipmi::ip				= #!conf!bcn_ip!#
ipmi::type				= server node

# Name of the setuid c-wrapper that calls ipmitool.
ipmi::query				= wipmi

# specifications for the various attributes
#
ipmi::summary::max			= 100
ipmi::summary::ok			= 0
ipmi::summary::warn			= 4
ipmi::summary::hysteresis		= 0


ipmi::Ambient::ok			= 45
ipmi::Ambient::warn			= 55
ipmi::Ambient::hysteresis		= 1
ipmi::Ambient::units			= degrees C

ipmi::Systemboard 1::ok			= 45
ipmi::Systemboard 1::warn		= 55
ipmi::Systemboard 1::hysteresis		= 1
ipmi::Systemboard 1::units		= degrees C

ipmi::Systemboard 2::ok			= 45
ipmi::Systemboard 2::warn		= 55
ipmi::Systemboard 2::hysteresis		= 1
ipmi::Systemboard 2::units		= degrees C

ipmi::VR CPU1::ok			= 45
ipmi::VR CPU1::warn			= 55
ipmi::VR CPU1::hysteresis		=  1
ipmi::VR CPU1::units			= degrees C

ipmi::VR MEM AB::ok			= 45
ipmi::VR MEM AB::warn			= 55
ipmi::VR MEM AB::hysteresis		=  1
ipmi::VR MEM AB::units			= degrees C

ipmi::VR MEM CD::ok			= 45
ipmi::VR MEM CD::warn			= 55
ipmi::VR MEM CD::hysteresis		= 1
ipmi::VR MEM CD::units			= degrees C

ipmi::VR CPU2::ok			= 45
ipmi::VR CPU2::warn			= 55
ipmi::VR CPU2::hysteresis		=  1
ipmi::VR CPU2::units			= degrees C

ipmi::VR MEM EF::ok			= 45
ipmi::VR MEM EF::warn			= 55
ipmi::VR MEM EF::hysteresis		=  1
ipmi::VR MEM EF::units			= degrees C

ipmi::VR MEM GH::ok			= 45
ipmi::VR MEM GH::warn			= 55
ipmi::VR MEM GH::hysteresis		=  1
ipmi::VR MEM GH::units			= degrees C

ipmi::CPU1::ok				= 45
ipmi::CPU1::warn			= 55
ipmi::CPU1::hysteresis			=  1
ipmi::CPU1::units			= degrees C

ipmi::CPU2::ok				= 45
ipmi::CPU2::warn			= 55
ipmi::CPU2::hysteresis			=  1
ipmi::CPU2::units			= degrees C

ipmi::MEM A::ok				= 45
ipmi::MEM A::warn			= 55
ipmi::MEM A::hysteresis			=  1
ipmi::MEM A::units			= degrees C

ipmi::MEM B::ok				= 45
ipmi::MEM B::warn			= 55
ipmi::MEM B::hysteresis			=  1
ipmi::MEM B::units			= degrees C

ipmi::MEM C::ok				= 45
ipmi::MEM C::warn			= 55
ipmi::MEM C::hysteresis			=  1
ipmi::MEM C::units			= degrees C

ipmi::MEM D::ok				= 45
ipmi::MEM D::warn			= 55
ipmi::MEM D::hysteresis			=  1
ipmi::MEM D::units			= degrees C

ipmi::MEM E::ok				= 45
ipmi::MEM E::warn			= 55
ipmi::MEM E::hysteresis			=  1
ipmi::MEM E::units			= degrees C

ipmi::MEM F::ok				= 45
ipmi::MEM F::warn			= 55
ipmi::MEM F::hysteresis			=  1
ipmi::MEM F::units			= degrees C

ipmi::MEM G::ok				= 45
ipmi::MEM G::warn			= 55
ipmi::MEM G::hysteresis			=  1
ipmi::MEM G::units			= degrees C

ipmi::MEM H::ok				= 45
ipmi::MEM H::warn			= 55
ipmi::MEM H::hysteresis			=  1
ipmi::MEM H::units			= degrees C

ipmi::PSU1 Inlet::ok			= 45
ipmi::PSU1 Inlet::warn			= 55
ipmi::PSU1 Inlet::hysteresis		=  1
ipmi::PSU1 Inlet::units			= degrees C

ipmi::PSU2 Inlet::ok			= 45
ipmi::PSU2 Inlet::warn			= 55
ipmi::PSU2 Inlet::hysteresis		=  1
ipmi::PSU2 Inlet::units			= degrees C

ipmi::PSU1::ok				= 65
ipmi::PSU1::warn			= 75
ipmi::PSU1::hysteresis			=  1
ipmi::PSU1::units			= degrees C

ipmi::PSU2::ok				= 65
ipmi::PSU2::warn			= 75
ipmi::PSU2::hysteresis			=  1
ipmi::PSU2::units			= degrees C

ipmi::BBU::ok				= 45
ipmi::BBU::warn				= 55
ipmi::BBU::hysteresis			=  1
ipmi::BBU::units			= degrees C

ipmi::RAID Controller::ok		= 60
ipmi::RAID Controller::warn		= 70
ipmi::RAID Controller::hysteresis	=  1
ipmi::RAID Controller::units		= degrees C

# ----------------------------------------------------------------------
# End of file.
",
			configuration_file	=>	"ipmi.conf",
			enabled			=>	1,
		},
		raid			=>	{
			configuration_body	=>	"
# RAID config file
#
# Each config file uses a unique prefix for data. Specify what that
# prefix is, so a single reading routine can handle all the different
# files.
#
name = raid

# Agent metadata
#
raid::db::table::ROC temperature	= raid_controllers
raid::db::table::Drive Temperature	= raid_drives
raid::db::table::summary		= raid_controllers
raid::db::table::other			= raid_controllers
raid::db::table::alerts			= alerts

raid::host				= #!conf!long_hostname!#
raid::ip				= #!conf!bcn_ip!#
raid::type				= RAID subsystem
raid::query				= wstorcli

# specifications for the summary data & various attributes
#
raid::summary::max			= 100
raid::summary::ok			= 0
raid::summary::warn			= 4
raid::summary::hysteresis		= 0


raid::Drive Temperature::ok		=  40
raid::Drive Temperature::warn		=  50
raid::Drive Temperature::hysteresis	=   1
raid::Drive Temperature::units		= degrees C


raid::ROC temperature::ok		=  50
raid::ROC temperature::warn		=  60
raid::ROC temperature::hysteresis	=   1
raid::ROC temperature::units		= degrees C


# ----------------------------------------------------------------------
# End of file.
",
			configuration_file	=>	"raid.conf",
			enabled			=>	1,
		},
		scanner			=>	{
			configuration_body	=>	"
# scanner config file
#
# Each config file uses a unique prefix for data. Specify what that
# prefix is, so a single reading routine can handle all the different
# files.
#
name = scanner

# Agent metadata
#
scanner::db::table::alerts	= alerts

# This is the local machine's full host name, used to help users identify this
# node when parsing database data.
scanner::host			= #!conf!long_hostname!#

# This is the local machine's IP addressed, used to help users identify this
# node when parsing database data.
scanner::ip			= #!conf!bcn_ip!#

# 
scanner::type			= scanCore

# Each node records it's health to this file. The other node consults this file
# when it is in an emergency shutdown-state to decide whether it should migrate
# or power down servers.
scanner::healthfile		= /shared/status/.#!conf!short_hostname!#

# This is a setuid c-wrapper that calls /var/www/tools/safe_anvil_stop to
# initiate the shutdown of the node in an emergency.
scanner::shutdown		= /var/www/tools/wshutdown 

# This is a list of agents (or other files) in /usr/share/striker/agents/ to
# ignore. Any hardware, service or resource you do not have should be listed
# here. Alternatively, delete the files you don't want from that directory.
scanner::ignorefile		= MegaSAS.log nodemonitor snmp_brocade_switch snmp_apc_pdu

# How important are the various agents in determining a shutdown?
#
scanner::weight::snmp_apc_ups	= 1
scanner::weight::snmp_apc_pdu	= 1
scanner::weight::ipmi		= 1
scanner::weight::raid		= 1

# specifications for the summary data & various attributes
#
scanner::summary::max		= 100
scanner::summary::ok		= 1
scanner::summary::warn		= 5

# ----------------------------------------------------------------------
# End of file.
",
			configuration_file	=>	"scanner.conf",
			enabled			=>	1,
		},
		snmp_apc_ups		=>	{
			configuration_body	=>	"
# SNMP Configuration for APC UPSes.
#
# Global data should be tagged with 'global' at the second level, or
# equivalenty, with 'default'. The oid to determine the battery
# temperature is always the same, if we are querying an APC UPS, so
# OIDs are tagged as global.
#
# Data which is different for various entities should be tagged with a
# number. The appearance of a number rather than letter at the second
# level indicates characteristics which are unique to a single
# instance. While names for the multiple instances could in theory be
# meaningful, the existing code searaches for digits to differentiate
# global and local data.
#
# It is also possible to set a global characteristic and then override
# it on a local level. To test and demonstrate this, UPS 1 has it's
# own definition for snmp::reason for last transfer::values::1 ...
# Instead of 'No events', it uses 'Nothing happened' ... clearly a
# meaningless and insignificant difference. But using the debugger, we
# can display the snmp_apc_ups object and see the separate values.
#

# Each config file uses a unique prefix for data. Specify what that
# prefix is, so a single reading routine can handle all the different
# files.
#
name = snmp

# Agent metadata
#
snmp::db::table::battery capacity		= snmp_apc_ups
snmp::db::table::battery temperature		= snmp_apc_ups
snmp::db::table::battery runtime remaining	= snmp_apc_ups
snmp::db::table::battery replace		= snmp_apc_ups
snmp::db::table::input voltage			= snmp_apc_ups
snmp::db::table::input frequency		= snmp_apc_ups
snmp::db::table::reason for last transfer	= snmp_apc_ups
snmp::db::table::output voltage			= snmp_apc_ups
snmp::db::table::output frequency		= snmp_apc_ups
snmp::db::table::output load			= snmp_apc_ups
snmp::db::table::output current			= snmp_apc_ups
snmp::db::table::comms				= snmp_apc_ups
snmp::db::table::last self test result		= snmp_apc_ups
snmp::db::table::last self test date		= snmp_apc_ups
snmp::db::table::other				= snmp_apc_ups
snmp::db::table::alerts				= alerts

snmp::1::name					= $conf->{cgi}{anvil_ups1_name}
snmp::1::type					= APC UPS
snmp::1::ip					= $conf->{cgi}{anvil_ups1_ip}
snmp::1::community				= public

snmp::2::name					= $conf->{cgi}{anvil_ups2_name}
snmp::2::type					= APC UPS
snmp::2::ip					= $conf->{cgi}{anvil_ups2_ip}
snmp::2::community				= public

# specifications for the summary data & various attributes
#
snmp::global::summary::max			= 100
snmp::global::summary::ok			= 0
snmp::global::summary::warn			= 4
snmp::global::summary::hysteresis		= 0

#snmp::global::oid::ups  type			= .1.3.6.1.4.1.318.1.1.1.1.1.1.0
snmp::global::oid::battery capacity		= .1.3.6.1.4.1.318.1.1.1.2.2.1.0
snmp::global::oid::battery temperature		= .1.3.6.1.4.1.318.1.1.1.2.2.2.0
snmp::global::oid::battery runtime remaining	= .1.3.6.1.4.1.318.1.1.1.2.2.3.0
snmp::global::oid::battery replace		= .1.3.6.1.4.1.318.1.1.1.2.2.4.0
snmp::global::oid::input voltage		= .1.3.6.1.4.1.318.1.1.1.3.2.1.0
snmp::global::oid::input frequency		= .1.3.6.1.4.1.318.1.1.1.3.2.4.0
snmp::global::oid::reason for last transfer	= .1.3.6.1.4.1.318.1.1.1.3.2.5.0
snmp::global::oid::output voltage		= .1.3.6.1.4.1.318.1.1.1.4.2.1.0
snmp::global::oid::output frequency		= .1.3.6.1.4.1.318.1.1.1.4.2.2.0
snmp::global::oid::output load			= .1.3.6.1.4.1.318.1.1.1.4.2.3.0
snmp::global::oid::output current		= .1.3.6.1.4.1.318.1.1.1.4.2.4.0
snmp::global::oid::comms			= .1.3.6.1.4.1.318.1.1.1.8.1.0
snmp::global::oid::last self test result	= .1.3.6.1.4.1.318.1.1.1.7.2.3.0
snmp::global::oid::last self test date		= .1.3.6.1.4.1.318.1.1.1.7.2.4.0

# Dummy entry so 'last self test date' has SOME config file entry.
#
snmp::global::last self test date::hysteresis	= 0.0

snmp::global::battery capacity::units		= %
snmp::global::battery capacity::min		= 0
snmp::global::battery capacity::max		= 100
snmp::global::battery capacity::ok		= 25
snmp::global::battery capacity::warn		= 10
snmp::global::battery capacity::hysteresis	= 1
snmp::global::battery capacity::weight		= 1
snmp::global::battery capacity::compare		= greater

# http://koninkx.net/index.php/howtos/snmp/8-usefull-oids-for-apc says
# this can be F or C depending on configuration, but APC MIB file says
# it is Celsius.
#
snmp::global::battery temperature::units	= degrees C
snmp::global::battery temperature::min		= 0
snmp::global::battery temperature::max		= 100
snmp::global::battery temperature::ok		= 20
snmp::global::battery temperature::warn		= 25
snmp::global::battery temperature::hysteresis	= 1
snmp::global::battery temperature::weight	= 1
snmp::global::battery temperature::compare	= lesser

snmp::global::battery runtime remaining::units		= minutes?
snmp::global::battery runtime remaining::min		= 0
snmp::global::battery runtime remaining::max		= 50
snmp::global::battery runtime remaining::ok		= 20
snmp::global::battery runtime remaining::warn		= 05
snmp::global::battery runtime remaining::hysteresis	= 1
snmp::global::battery runtime remaining::weight		= 1
snmp::global::battery runtime remaining::compare	= greater

snmp::global::battery replace::values::1	= unneeded
snmp::global::battery replace::values::2	= needed
snmp::global::battery replace::weight		= 1
 
snmp::global::input voltage::units		= V
snmp::global::input voltage::min		= 90
snmp::global::input voltage::max		= 150
snmp::global::input voltage::ok_min		= 105
snmp::global::input voltage::ok_max		= 125
snmp::global::input voltage::warn_min		= 95
snmp::global::input voltage::warn_max		= 140
snmp::global::input voltage::crisis_min		= 90
snmp::global::input voltage::crisis_max		= 150
snmp::global::input voltage::hysteresis		= 1
snmp::global::input voltage::weight		= 1

snmp::global::input frequency::units		= Hz
snmp::global::input frequency::min		= 55
snmp::global::input frequency::max		= 65
snmp::global::input frequency::ok_min		= 58
snmp::global::input frequency::ok_max		= 62
snmp::global::input frequency::warn_min		= 56
snmp::global::input frequency::warn_max		= 64
snmp::global::input frequency::crisis_min	= 55
snmp::global::input frequency::crisis_max	= 65
snmp::global::input frequency::hysteresis	= 1
snmp::global::input frequency::weight		= 1

snmp::global::reason for last transfer::values::1	= No events
snmp::global::reason for last transfer::values::2	= High line voltage
snmp::global::reason for last transfer::values::3	= Brownout
snmp::global::reason for last transfer::values::4	= Los of mains power
snmp::global::reason for last transfer::values::5	= Small temporary power drop
snmp::global::reason for last transfer::values::6	= Large temporary power drop
snmp::global::reason for last transfer::values::7	= Small spike
snmp::global::reason for last transfer::values::8	= Large spike
snmp::global::reason for last transfer::values::9	= UPS self test
snmp::global::reason for last transfer::values::10	= Excessive input voltage fluctuation
snmp::global::reason for last transfer::weight		= 1

# test/demonstrate local override of global setting
#
snmp::1::reason for last transfer::values::1  = Nothing happened.

snmp::global::output voltage::units		= V
snmp::global::output voltage::min		= 90
snmp::global::output voltage::max		= 150
snmp::global::output voltage::ok_min		= 115
snmp::global::output voltage::ok_max		= 130
snmp::global::output voltage::warn_min		= 110
snmp::global::output voltage::warn_max		= 135
snmp::global::output voltage::crisis_min	= 90
snmp::global::output voltage::crisis_max	= 150
snmp::global::output voltage::hysteresis	= 1
snmp::global::output voltage::weight		= 1

snmp::global::output frequency::units		= Hz
snmp::global::output frequency::min		= 55
snmp::global::output frequency::max		= 65
snmp::global::output frequency::ok_min		= 58
snmp::global::output frequency::ok_max		= 62
snmp::global::output frequency::warn_min	= 56
snmp::global::output frequency::warn_max	= 64
snmp::global::output frequency::crisis_min	= 55
snmp::global::output frequency::crisis_max	= 65
snmp::global::output frequency::hysteresis	= 1
snmp::global::output frequency::weight		= 1

snmp::global::output load::units		= %
snmp::global::output load::min			= 0
snmp::global::output load::max			= 100
snmp::global::output load::ok			= 75
snmp::global::output load::warn			= 95
snmp::global::output load::hysteresis		= 1
snmp::global::output load::weight		= 1

snmp::global::output current::units		= A
snmp::global::output current::min		= 0
snmp::global::output current::max		= 5
snmp::global::output current::ok		= 4
snmp::global::output current::warn		= 4.7
snmp::global::output current::hysteresis	= 0.1
snmp::global::output current::weight		= 1

snmp::global::comms::label			= Communicating
snmp::global::comms::values::1			= yes
snmp::global::comms::values::2			= no
snmp::global::comms::weight			= 5
",
			configuration_file	=>	"snmp_apc_ups.conf",
			enabled			=>	1,
		},
	};
	
	if ($conf->{sys}{use_drbd} eq "8.3")
	{
		$conf->{packages}{to_install}{'kmod-drbd83'}  = 0;
		$conf->{packages}{to_install}{'drbd83-utils'} = 0;
	}
	elsif ($conf->{sys}{use_drbd} eq "8.4")
	{
		$conf->{packages}{to_install}{'kmod-drbd84'}  = 0;
		$conf->{packages}{to_install}{'drbd84-utils'} = 0;
	}
	
	$conf->{url}{'anvil-map-network'}  = "https://raw.githubusercontent.com/digimer/striker/master/tools/anvil-map-network";
	$conf->{path}{'anvil-map-network'} = "/sbin/striker/anvil-map-network";
	
	if ($conf->{perform_install})
	{
		# OK, GO!
		print AN::Common::template($conf, "install-manifest.html", "install-beginning");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::update_manifest: [$conf->{cgi}{update_manifest}]\n");
		if ($conf->{cgi}{update_manifest})
		{
			# Write the updated manifest and switch to using it.
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> cgi::run: [$conf->{cgi}{run}].\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << cgi::run: [$conf->{cgi}{run}].\n");
		}
	}
	
	# If the node(s) are not online, we'll set up a repo pointing at this
	# maching *if* we're configured to be a repo.
	check_local_repo($conf);
	
	# Make sure we can log into both nodes.
	check_connection($conf) or return(1);
	
	# Make sure both nodes are EL6 nodes.
	verify_os($conf) or return(1);
	
	# Make sure both nodes can get online. We'll try to install even
	# without Internet access.
	verify_internet_access($conf);
	
	### NOTE: I might want to move the addition of the an-repo up here.
	# Beyond here, perl is needed.
	verify_perl_is_installed($conf);
	
	# This checks the disks out and selects the largest disk on each node.
	# It doesn't sanity check much yet.
	check_storage($conf);
	
	# See if the node is in a cluster already. If so, we'll set a flag to
	# block reboots if needed.
	check_if_in_cluster($conf);
	
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::perform_install: [$conf->{cgi}{perform_install}].\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::update_manifest: [$conf->{cgi}{update_manifest}]\n");
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
		add_user_repositories($conf);
		
		# If not online, and if the local dashboard is a compatible
		# repository, this will add the repo to the node.
		add_local_repo($conf);
		
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
		
		# Configure storage stage 1 (partitioning.
		configure_storage_stage1($conf) or return(1);
		
		# Set the root user's passwords as the last step to ensure
		# reloading the browser works for as long as possible.
		set_root_password($conf) or return(1);
		
		# If a reboot is needed, now is the time to do it. This will
		# switch the CGI nodeX IPs to the new ones, too.
		reboot_nodes($conf) or return(1);
		
		# Configure storage stage 2 (drbd)
		configure_storage_stage2($conf) or return(1);
		
		# Start cman up
		start_cman($conf) or return(1);
		
		### TODO: Test migration! After rebuilding node 1, migration 
		###       from 2 -> 1 failed because ~/.ssh/known_hosts wasn't
		###       properly populated.
		# Live migration won't work until we've populated
		#  ~/.ssh/known_hosts, so do so now.
		configure_ssh($conf) or return(1);
		
		# This manually starts DRBD, forcing one to primary if needed,
		# configures clvmd, sets up the PVs and VGs, creates the
		# /shared LV, creates the GFS2 partition and configures fstab.
		configure_storage_stage3($conf) or return(1);
		
		# This sets up the various Striker tools like safe_anvil_start
		# and so on.
		configure_striker_tools($conf);
		
		### If we're not dead, it's time to celebrate!
		# Is this Anvil! already in the config file?
		my ($anvil_configured) = check_config_for_anvil($conf);
		
		# Do we need to show the link for adding the Anvil! to the config?
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; anvil_configured: [$anvil_configured]\n");
		my $message = AN::Common::get_string($conf, {key => "message_0286", variables => { url => "?cluster=$conf->{cgi}{cluster}" }});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; message: [$message]\n");
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

# 
sub configure_striker_tools
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_striker_tools()\n");
	
	# If requested, enable safe_anvil_start.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sys::install_manifest::use_safe_anvil_start: [$conf->{sys}{install_manifest}{use_safe_anvil_start}]\n");
	if ($conf->{sys}{install_manifest}{use_safe_anvil_start})
	{
		# Don't fail on this, yet. Maybe later.
		enable_safe_anvil_start($conf);
	}
	
	# If requested, enable anvil-kick-apc-ups
	if ($conf->{sys}{install_manifest}{'use_anvil-kick-apc-ups'})
	{
		# Don't fail on this, yet. Maybe later.
		enable_anvil_kick_apc_ups($conf);
	}
	
	# Configure Scancore.
	#configure_scancore($conf);
	
	return(0);
}

# This does the actual work of configuring ScanCore on a given node.
sub configure_scancore_on_node
{
	my ($conf, $node, $password, $node_name) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_scancore_on_node(); node: [$node], node_name: [$node_name]\n");
	
	my $ok = 1;
	### TODO: Each scan agent has a config file, most of which may not be
	###       useful to the client. For now, we'll configure them all. 
	###       Later, these will be configured via Install Manifest.
	my $node_short_name = $node_name;
	   $node_short_name = s/^(.*?)\..*$/$1/;
	my $node_bcn_ip     = $node;
	foreach my $agent (sort {$a cmp $b} keys %{$conf->{scancore}{scan_agents}})
	{
		next if not $conf->{scancore}{scan_agents}{$agent}{enabled};
		my $config_file       = "$conf->{path}{nodes}{scan_agents}/$conf->{scancore}{scan_agents}{$agent}{configuration_file}";
		my $node_config_body = $conf->{scancore}{scan_agents}{$agent}{configuration_body};
		
		# Substitute variables.
		$node_config_body =~ s/#!conf!bcn_ip!#/$node_bcn_ip/gs;
		$node_config_body =~ s/#!conf!long_hostname!#/$node_name/gs;
		$node_config_body =~ s/#!conf!short_hostname!#/$node_short_name/gs;
		
		### TODO: Backup any existing files.
		# Write out the config
		my $shell_call =  "cat > $config_file << EOF\n";
		   $shell_call .= "$node_config_body\n";
		   $shell_call .= "EOF";
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
		my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	22,
			user		=>	"root",
			password	=>	$password,
			ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
		foreach my $line (@{$return})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n");
		}
	}
	
	# Now make sure scan core is set to start on boot.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Enabling ScanCore on boot.\n");
	my $shell_call = "
if [ ! -e '$conf->{path}{nodes}{cron_root}' ]
then
	echo 'creating empty crontab for root.'
	touch $conf->{path}{nodes}{cron_root}
	chown root:root $conf->{path}{nodes}{cron_root}
	chmod 600 $conf->{path}{nodes}{cron_root}
fi
grep -q scanner /var/spool/cron/root
if [ \"\$?\" -eq '0' ];
then
	echo 'exits'
else
	echo '*/5 * * * * /usr/share/striker/bin/scanner' >> $conf->{path}{nodes}{cron_root}
fi";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	11,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n");
	}
	
	return($ok);
}


# This sets up scancore to run on the nodes. It expects the database(s) to be
# on the node(s).
sub configure_scancore
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_scancore()\n");
	
	my ($node1_ok) = configure_scancore_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $conf->{cgi}{anvil_node1_name});
	my ($node2_ok) = configure_scancore_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $conf->{cgi}{anvil_node2_name});
	
	# TODO: Show the user the results.
	
	return(0);
}

# This creates the run-level 3 link to enable anvil-kick-apc-ups.
sub enable_anvil_kick_apc_ups_on_node
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; enable_anvil_kick_apc_ups_on_node(); node: [$node]\n");
	
	my $return_code = 0;
	my $shell_call = "
if [ -e '$conf->{path}{nodes}{'anvil-kick-apc-ups'}' ];
then 
	echo '$conf->{path}{nodes}{'anvil-kick-apc-ups'} exists, creating symlink';
	if [ -e '$conf->{path}{nodes}{'anvil-kick-apc-ups_link'}' ];
	then
		echo '$conf->{path}{nodes}{'anvil-kick-apc-ups_link'} already exists.'
	else
		ln -s $conf->{path}{nodes}{'anvil-kick-apc-ups'} $conf->{path}{nodes}{'anvil-kick-apc-ups_link'}
		if [ -e '$conf->{path}{nodes}{'anvil-kick-apc-ups_link'}' ];
		then
			echo '$conf->{path}{nodes}{'anvil-kick-apc-ups_link'} link created.'
		else
			echo 'Failed to create $conf->{path}{nodes}{'anvil-kick-apc-ups_link'}.'
		fi
	fi
else 
	echo '$conf->{path}{nodes}{'anvil-kick-apc-ups'} not found'
fi";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /already exists/i)
		{
			$return_code = 1;
		}
		if ($line =~ /link created/i)
		{
			$return_code = 0;
		}
		if ($line =~ /Failed to create/i)
		{
			$return_code = 2;
		}
		if ($line =~ /not found/i)
		{
			$return_code = 3;
		}
	}
	
	# 0 = Link created.
	# 1 = Symlink already exists
	# 2 = Failed to create link.
	# 3 = anvil-kick-apc-ups not found
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code]\n");
	return($return_code);
} 

# This creates the run-level 3 link to enable safe_anvil_start.
sub enable_safe_anvil_start_on_node
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; enable_safe_anvil_start_on_node(); node: [$node]\n");
	
	my $return_code = 0;
	
	# Make sure the '/shared' directory exists.
	my $shell_call = "
if [ -e '$conf->{path}{nodes}{safe_anvil_start}' ];
then 
	echo '$conf->{path}{nodes}{safe_anvil_start} exists, creating symlink';
	if [ -e '$conf->{path}{nodes}{safe_anvil_start_link}' ];
	then
		echo '$conf->{path}{nodes}{safe_anvil_start_link} already exists.'
	else
		ln -s $conf->{path}{nodes}{safe_anvil_start} $conf->{path}{nodes}{safe_anvil_start_link}
		if [ -e '$conf->{path}{nodes}{safe_anvil_start_link}' ];
		then
			echo '$conf->{path}{nodes}{safe_anvil_start_link} link created.'
		else
			echo 'Failed to create $conf->{path}{nodes}{safe_anvil_start_link}.'
		fi
	fi
else 
	echo '$conf->{path}{nodes}{safe_anvil_start} not found'
fi";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /already exists/i)
		{
			$return_code = 1;
		}
		if ($line =~ /link created/i)
		{
			$return_code = 0;
		}
		if ($line =~ /Failed to create/i)
		{
			$return_code = 2;
		}
		if ($line =~ /not found/i)
		{
			$return_code = 3;
		}
	}
	
	# 0 = Link created.
	# 1 = Symlink already exists
	# 2 = Failed to create link.
	# 3 = safe_anvil_start not found
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code]\n");
	return($return_code);
} 

# This creates a symlink in run-level 3 to run anvil-kick-apc-ups on boot.
sub enable_anvil_kick_apc_ups
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; enable_anvil_kick_apc_ups()\n");
	
	my $ok = 1;
	my ($node1_rc) = enable_anvil_kick_apc_ups_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_rc) = enable_anvil_kick_apc_ups_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_rc: [$node1_rc], node2_rc: [$node2_rc]\n");
	# 0 = Link created.
	# 1 = Symlink already exists
	# 2 = Failed to create link.
	# 3 = anvil-kick-apc-ups not found
	
	# Report
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0106!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0106!#";
	# Node 1
	if ($node1_rc eq "1")
	{
		# Symlink already exists
		$node1_message = "#!string!state_0107!#";
	}
	elsif ($node1_rc eq "2")
	{
		# Failed to create link
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0109!#";
		$ok            = 0;
	}
	elsif ($node1_rc eq "3")
	{
		# anvil-kick-apc-ups not found
		$node1_class   = "highlight_warning_bold";
		$node1_message = AN::Common::get_string($conf, {key => "state_0108", variables => { file => "$conf->{path}{nodes}{'anvil-kick-apc-ups'}" }});
		$ok            = 0;
	}
	# Node 2
	if ($node2_rc eq "1")
	{
		# Symlink already exists
		$node2_message = "#!string!state_0107!#";
	}
	elsif ($node2_rc eq "2")
	{
		# Failed to create link
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0109!#";
		$ok            = 0;
	}
	elsif ($node2_rc eq "3")
	{
		# anvil-kick-apc-ups not found
		$node2_class   = "highlight_warning_bold";
		$node2_message = AN::Common::get_string($conf, {key => "state_0108", variables => { file => "$conf->{path}{nodes}{'anvil-kick-apc-ups'}" }});
		$ok            = 0;
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0283!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This creates a symlink in run-level 3 to run safe_anvil_start on boot.
sub enable_safe_anvil_start
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; enable_safe_anvil_start()\n");
	
	my $ok = 1;
	my ($node1_rc) = enable_safe_anvil_start_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_rc) = enable_safe_anvil_start_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_rc: [$node1_rc], node2_rc: [$node2_rc]\n");
	# 0 = Link created.
	# 1 = Symlink already exists
	# 2 = Failed to create link.
	# 3 = safe_anvil_start not found
	
	# Report
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0106!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0106!#";
	# Node 1
	if ($node1_rc eq "1")
	{
		# Symlink already exists
		$node1_message = "#!string!state_0107!#";
	}
	elsif ($node1_rc eq "2")
	{
		# Failed to create link
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0109!#";
		$ok            = 0;
	}
	elsif ($node1_rc eq "3")
	{
		# safe_anvil_start not found
		$node1_class   = "highlight_warning_bold";
		$node1_message = AN::Common::get_string($conf, {key => "state_0108", variables => { file => "$conf->{path}{nodes}{safe_anvil_start}" }});
		$ok            = 0;
	}
	# Node 2
	if ($node2_rc eq "1")
	{
		# Symlink already exists
		$node2_message = "#!string!state_0107!#";
	}
	elsif ($node2_rc eq "2")
	{
		# Failed to create link
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0109!#";
		$ok            = 0;
	}
	elsif ($node2_rc eq "3")
	{
		# safe_anvil_start not found
		$node2_class   = "highlight_warning_bold";
		$node2_message = AN::Common::get_string($conf, {key => "state_0108", variables => { file => "$conf->{path}{nodes}{safe_anvil_start}" }});
		$ok            = 0;
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0282!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This takes the current install manifest up rewrites it to record the user's
# MAC addresses selected during the network remap.
sub update_install_manifest
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; update_install_manifest()\n");
	
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1: [$node1]; node1_bcn_link2: [$node1_bcn_link1], node1_bcn_link2: [$node1_bcn_link2], node1_sn_link1: [$node1_sn_link1], node1_sn_link2: [$node1_sn_link2], node1_ifn_link1: [$node1_ifn_link1], node1_ifn_link2: [$node1_ifn_link2].\n");
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node2: [$node2]; node2_bcn_link2: [$node2_bcn_link1], node2_bcn_link2: [$node2_bcn_link2], node2_sn_link1: [$node2_sn_link1], node2_sn_link2: [$node2_sn_link2], node2_ifn_link1: [$node2_ifn_link1], node2_ifn_link2: [$node2_ifn_link2].\n");
	
	my $save       = 0;
	my $in_node1   = 0;
	my $in_node2   = 0;
	my $raw_file   = "";
	my $shell_call = "$conf->{path}{apache_manifests_dir}/$conf->{cgi}{run}";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
	open (my $file_handle, "<", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
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
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in_node1: [$in_node1], in_node2: [$in_node2]\n");
			}
			elsif (($this_node =~ /node02/) ||
			       ($this_node =~ /node2/)  ||
			       ($this_node =~ /n02/)    ||
			       ($this_node =~ /n2/))
			{
				$in_node1 = 0;
				$in_node2 = 1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in_node1: [$in_node1], in_node2: [$in_node2]\n");
			}
		}
		if ($line =~ /<\/node>/)
		{
			$in_node1 = 0;
			$in_node2 = 0;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in_node1: [$in_node1], in_node2: [$in_node2]\n");
		}
		
		# See if we have a NIC.
		if ($line =~ /<interface /)
		{
			# OK, get the name and MAC.
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in_node1: [$in_node1], in_node2: [$in_node2], interface line: [$line]\n");
			my $this_nic = ($line =~ /name="(.*?)"/)[0];
			my $this_mac = ($line =~ /mac="(.*?)"/)[0];
				$this_mac = "" if not $this_mac;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in_node1: [$in_node1], in_node2: [$in_node2], this_nic: [$this_nic], this_mac: [$this_mac]\n");
			
			if ($in_node1)
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node 1 nic: [$this_nic], this_mac: [$this_mac]\n");
				if ($this_nic eq "bcn_link1")
				{ 
					if ($this_mac ne $node1_bcn_link1)
					{
						$save =  1;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> node1; line: [$line]\n");
						$line =~ s/mac=".*?"/mac="$node1_bcn_link1"/;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << node1; line: [$line]\n");
					}
				}
				elsif ($this_nic eq "bcn_link2")
				{ 
					if ($this_mac ne $node1_bcn_link2)
					{
						$save =  1;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> node1; line: [$line]\n");
						$line =~ s/mac=".*?"/mac="$node1_bcn_link2"/;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << node1; line: [$line]\n");
					}
				}
				elsif ($this_nic eq "sn_link1")
				{ 
					if ($this_mac ne $node1_sn_link1)
					{
						$save =  1;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> node1; line: [$line]\n");
						$line =~ s/mac=".*?"/mac="$node1_sn_link1"/;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << node1; line: [$line]\n");
					}
				}
				elsif ($this_nic eq "sn_link2")
				{ 
					if ($this_mac ne $node1_sn_link2)
					{
						$save =  1;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> node1; line: [$line]\n");
						$line =~ s/mac=".*?"/mac="$node1_sn_link2"/;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << node1; line: [$line]\n");
					}
				}
				elsif ($this_nic eq "ifn_link1")
				{ 
					if ($this_mac ne $node1_ifn_link1)
					{
						$save =  1;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> node1; line: [$line]\n");
						$line =~ s/mac=".*?"/mac="$node1_ifn_link1"/;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << node1; line: [$line]\n");
					}
				}
				elsif ($this_nic eq "ifn_link2")
				{ 
					if ($this_mac ne $node1_ifn_link2)
					{
						$save =  1;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> node1; line: [$line]\n");
						$line =~ s/mac=".*?"/mac="$node1_ifn_link2"/;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << node1; line: [$line]\n");
					}
				}
				else
				{
					# Unknown NIC.
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; [ Warning ] - node1 has an unknown NIC: [$this_nic] (line: [$line])\n");
				}
			}
			elsif ($in_node2)
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node 2 nic: [$this_nic], this_mac: [$this_mac]\n");
				if ($this_nic eq "bcn_link1")
				{ 
					if ($this_mac ne $node2_bcn_link1)
					{
						$save =  1;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> node2; line: [$line]\n");
						$line =~ s/mac=".*?"/mac="$node2_bcn_link1"/;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << node2; line: [$line]\n");
					}
				}
				elsif ($this_nic eq "bcn_link2")
				{ 
					if ($this_mac ne $node2_bcn_link2)
					{
						$save =  1;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> node2; line: [$line]\n");
						$line =~ s/mac=".*?"/mac="$node2_bcn_link2"/;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << node2; line: [$line]\n");
					}
				}
				elsif ($this_nic eq "sn_link1")
				{ 
					if ($this_mac ne $node2_sn_link1)
					{
						$save =  1;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> node2; line: [$line]\n");
						$line =~ s/mac=".*?"/mac="$node2_sn_link1"/;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << node2; line: [$line]\n");
					}
				}
				elsif ($this_nic eq "sn_link2")
				{ 
					if ($this_mac ne $node2_sn_link2)
					{
						$save =  1;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> node2; line: [$line]\n");
						$line =~ s/mac=".*?"/mac="$node2_sn_link2"/;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << node2; line: [$line]\n");
					}
				}
				elsif ($this_nic eq "ifn_link1")
				{ 
					if ($this_mac ne $node2_ifn_link1)
					{
						$save =  1;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> node2; line: [$line]\n");
						$line =~ s/mac=".*?"/mac="$node2_ifn_link1"/;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << node2; line: [$line]\n");
					}
				}
				elsif ($this_nic eq "ifn_link2")
				{ 
					if ($this_mac ne $node2_ifn_link2)
					{
						$save =  1;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> node2; line: [$line]\n");
						$line =~ s/mac=".*?"/mac="$node2_ifn_link2"/;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << node2; line: [$line]\n");
					}
				}
				else
				{
					# Unknown NIC.
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; [ Warning ] - node2 has an unknown NIC: [$this_nic] (line: [$line])\n");
				}
			}
			else
			{
				# failed to determine the node...
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; [ Warning ] - Saw an interface without first determining if we're in node 1 or 2's element. Are the node names using 'n0X', 'nX', 'node0X' or 'nodeX' (where 'X' is 1 or 2)?\n");
			}
		}
		$raw_file .= "$line\n";
	}
	close $file_handle;
	
	# Write out new raw file, if changes were made.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; save: [$save]\n");
	if ($save)
	{
		### TODO: Make a backup directory and save a pre-modified
		###       backup to it.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Updated manifest:\n========\n$raw_file\n========\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Writing out update manifest file: [$conf->{cgi}{run}]\n");
		my $shell_call = "$conf->{path}{apache_manifests_dir}/$conf->{cgi}{run}";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		open (my $file_handle, ">", "$shell_call") or die "$THIS_FILE ".__LINE__."; Failed to write: [$shell_call], error was: $!\n";
		print $file_handle $raw_file;
		close $file_handle;
		
		# Tell the user.
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message-wide", {
			row	=>	"#!string!title_0157!#",
			class	=>	"body",
			message	=>	"#!string!message_0376!#",
		});
	}
	
	return(0);
}

# This checks to see if we're configured to be a repo for RHEL and/or CentOS.
# If so, it gets the local IPs to be used later when setting up the repos on
# the nodes.
sub check_local_repo
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; check_local_repo()\n");
	
	# Call the gather system info tool to get the BCN and IFN IPs.
	my $shell_call = "$conf->{path}{'call_gather-system-info'}";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sc: [$shell_call]\n");
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /hostname,(.*)$/)
		{
			$conf->{sys}{'local'}{hostname} = $1;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; hostname: [$conf->{sys}{'local'}{hostname}]\n");
		}
		elsif ($line =~ /interface,(.*?),(.*?),(.*?)$/)
		{
			my $interface = $1;
			my $variable  = $2;
			my $value     = $3;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; interface: [$interface], variable: [$variable], value: [$value]\n");
			next if not $value;
			
			# For now, I'm only looking for IPs and subnets.
			if (($variable eq "ip") && ($interface =~ /ifn/))
			{
				$conf->{sys}{'local'}{ifn}{ip} = $value;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Found IFN IP: [$conf->{sys}{'local'}{ifn}{ip}]\n");
			}
			if (($variable eq "ip") && ($interface =~ /bcn/))
			{
				$conf->{sys}{'local'}{bcn}{ip} = $value;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Found BCN IP: [$conf->{sys}{'local'}{bcn}{ip}]\n");
			}
		}
	}
	close $file_handle;
	
	# Now see if we have RHEL, CentOS and/or generic repos setup.
	$conf->{sys}{'local'}{repo}{centos}  = 0;
	$conf->{sys}{'local'}{repo}{generic} = 0;
	$conf->{sys}{'local'}{repo}{rhel}    = 0;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Looking for: [$conf->{path}{repo_centos}]\n");
	if (-e $conf->{path}{repo_centos})
	{
		$conf->{sys}{'local'}{repo}{centos} = 1;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Found local CentOS repo.\n");
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Looking for: [$conf->{path}{repo_generic}]\n");
	if (-e $conf->{path}{repo_generic})
	{
		$conf->{sys}{'local'}{repo}{generic} = 1;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Found local generic repo.\n");
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Looking for: [$conf->{path}{repo_rhel}]\n");
	if (-e $conf->{path}{repo_rhel})
	{
		$conf->{sys}{'local'}{repo}{rhel} = 1;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Found local RHEL repo.\n");
	}
	
	return(0);
}

# See if the node is in a cluster already. If so, we'll set a flag to block
# reboots if needed.
sub check_if_in_cluster
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; check_config_for_anvil()\n");
	
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
		
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
		my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
			node		=>	$conf->{cgi}{anvil_node1_current_ip},
			port		=>	22,
			user		=>	"root",
			password	=>	$conf->{cgi}{anvil_node1_current_password},
			ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
		foreach my $line (@{$return})
		{
			if ($line =~ /rc:(\d+)/)
			{
				my $rc = $1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$conf->{cgi}{anvil_node1_current_ip}], rc: [$rc]\n");
				if ($rc eq "0")
				{
					# It's in a cluster.
					$conf->{node}{$node}{in_cluster} = 1;
				}
			}
			else
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$conf->{cgi}{anvil_node1_current_ip}], line: [$line]\n");
			}
		}
	}
	# Node 2
	if (1)
	{
		my $node                            = $conf->{cgi}{anvil_node2_current_ip};
		   $conf->{node}{$node}{in_cluster} = 0;
		
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
		my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
			node		=>	$conf->{cgi}{anvil_node2_current_ip},
			port		=>	22,
			user		=>	"root",
			password	=>	$conf->{cgi}{anvil_node2_current_password},
			ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
		foreach my $line (@{$return})
		{
			if ($line =~ /rc:(\d+)/)
			{
				my $rc = $1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$conf->{cgi}{anvil_node2_current_ip}], rc: [$rc]\n");
				if ($rc eq "0")
				{
					# It's in a cluster.
					$conf->{node}{$node}{in_cluster} = 1;
				}
			}
			else
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$conf->{cgi}{anvil_node2_current_ip}], line: [$line]\n");
			}
		}
	}
	
	return(0);
}

# Check to see if the created Anvil! is in the configuration yet.
sub check_config_for_anvil
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; check_config_for_anvil()\n");
	
	my $anvil_configured = 0;
	foreach my $cluster (sort {$a cmp $b} keys %{$conf->{cluster}})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_name: [$conf->{cgi}{anvil_name}], cluster::${cluster}::name: [$conf->{cluster}{$cluster}{name}]\n");
		if ($conf->{cgi}{anvil_name} eq $conf->{cluster}{$cluster}{name})
		{
			$anvil_configured = 1;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Match!\n");
			last;
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; anvil_configured: [$anvil_configured]\n");
	return($anvil_configured);
}

# This manually starts DRBD, forcing one to primary if needed, configures
# clvmd, sets up the PVs and VGs, creates the /shared LV, creates the GFS2
# partition and configures fstab.
sub configure_storage_stage3
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_storage_stage3()\n");
	
	my $ok = 1;
	
	# Bring up DRBD
	my ($drbd_ok) = drbd_first_start($conf);
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; drbd_ok: [$drbd_ok]\n");
	
	# Start clustered LVM
	my $lvm_ok = 0;
	if ($drbd_ok)
	{
		# This will create the /dev/drbd{0,1} PVs and create the VGs on
		# them, if needed.
		($lvm_ok) = setup_lvm_pv_and_vgs($conf);
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lvm_ok: [$lvm_ok]\n");
		
		# Create GFS2 partition
		my $gfs2_ok = 0;
		if ($lvm_ok)
		{
			($gfs2_ok) = setup_gfs2($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; gfs2_ok: [$gfs2_ok]\n");
			# Create /shared, mount partition
			# Appeand gfs2 entry to fstab
			# Check that /etc/init.d/gfs2 status works
			
			if ($gfs2_ok)
			{
				# Start gfs2 on both nodes, including
				# subdirectories and SELinux contexts on
				# /shared.
				my ($configure_ok) = configure_gfs2($conf);
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_ok: [$configure_ok]\n");
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	if ($ok)
	{
		# Start rgmanager, making sure it comes up
		my ($node1_rc) = start_rgmanager_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
		my ($node2_rc) = start_rgmanager_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_rc: [$node1_rc], node2_rc: [$node2_rc]\n");
		
		# Go into a loop waiting for the rgmanager services to either
		# start or fail.
		my ($clustat_ok) = watch_clustat($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; clustat_ok: [$clustat_ok]\n");
		if (not $clustat_ok)
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; One or more services failed to start.\n");
			$ok = 0;
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This watches clustat for up to 300 seconds for the storage and libvirt
# services to start (or fail)
sub watch_clustat
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; watch_clustat(); node: [$node]\n");
	
	# If a service comes up 'failed', we will try to restart it because, if
	# it failed in a previous run, it will stay failed until it is disabled
	# so this provides something of an ability to self-heal.
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; time: [".time."], abort_time: [$abort_time].\n");
	until ($services_seen)
	{
		# Call and parse 'clustat'
		my $shell_call = "clustat | grep service";
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /service:(.*?) .*? (.*)?/)
			{
				my $service = $1;
				my $state   = $2;
				# If it's not started or failed, I am not
				# interested in it.
				next if (($state ne "failed") && ($state ne "disabled") && ($state ne "started"));
				if ($service eq "libvirtd_n01")
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; service: [$service], state: [$state], restarted_n01_libvirtd: [$restarted_n01_libvirtd]\n");
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
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; service: [$service], state: [$state], restarted_n02_libvirtd: [$restarted_n02_libvirtd]\n");
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
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; service: [$service], state: [$state], restarted_n01_storage: [$restarted_n01_storage]\n");
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
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; service: [$service], state: [$state], restarted_n02_storage: [$restarted_n02_storage]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; services_seen: [$services_seen]\n");
			last;
		}
		
		if (time > $abort_time)
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Timed out waiting for clustat to show services.\n");
			last;
		}
		sleep 2;
	}
	
	my $ok = 1;
	# Report on the storage as one line and then libvirtd as a second.
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This will call disable -> enable on a given service to try and recover if
# from a 'failed' state.
sub restart_rgmanager_service
{
	my ($conf, $node, $password, $service, $do) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; restart_rgmanager_service(); node: [$node], service: [$service], do: [$do]\n");
	
	# This is something of a 'hail mary' pass, so not much sanity checking
	# is done (yet).
	my $shell_call = "clusvcadm -d $service && sleep 2 && clusvcadm -F -e $service";
	if ($do eq "start")
	{
		$shell_call = "clusvcadm -F -e $service";
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
	}
	
	return(0);
}


# This starts rgmanager on both a node
sub start_rgmanager_on_node
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; start_rgmanager_on_node(); node: [$node]\n");
	
	my $ok = 1;
	my $shell_call = "/etc/init.d/rgmanager start; echo rc:\$?";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			if ($rc eq "0")
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Started rgmanager successfully.\n");
			}
			else
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to start rgmanager. The return code was: [$?]\n");
				$ok = 0;
			}
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This handles starting (and configuring) GFS2 on the nodes.
sub configure_gfs2
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_gfs2()\n");
	
	my $ok = 1;
	my ($node1_rc) = setup_gfs2_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_rc) = setup_gfs2_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_rc: [$node1_rc], node2_rc: [$node2_rc]\n");
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This will manually mount the GFS2 partition on the node, configuring
# /etc/fstab in the process if needed.
sub setup_gfs2_on_node
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; setup_gfs2_on_node(); node: [$node]\n");
	
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
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
		($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /failed to add/)
			{
				# Failed to append to fstab
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to append: [$fstab_string] to '/etc/fstab'.\n");
				$return_code = 1;
			}
		}
		
		# Test mount using the 'mount' command
		if ($return_code ne "1")
		{
			my $shell_call = "mount /shared; echo \$?";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
				if ($line =~ /^rc:(\d+)/)
				{
					my $rc = $1;
					if ($rc eq "0")
					{
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Successfuly mounted '/shared'.\n");
					}
					else
					{
						# Failed to mount
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to mount '/shared', return code was: [$rc].\n");
						$return_code = 2;
					}
				}
			}
			
			# Finally, test '/etc/init.d/gfs2 status'
			if ($return_code ne "2")
			{
				my $shell_call = "/etc/init.d/gfs2 status; echo \$?";
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
					if ($line =~ /^rc:(\d+)/)
					{
						my $rc = $1;
						if ($rc eq "0")
						{
							AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The GFS2 LSB script sees that '/shared' is mounted.\n");
						}
						else
						{
							AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The GFS2 LSB script failed to see the '/shared' file system. The return code was: [$rc].\n");
							$return_code = 3;
						}
					}
				}
			}
		}
		
		# Create the subdirectories if asked
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code].\n");
		if (not $return_code)
		{
			foreach my $directory (@{$conf->{path}{nodes}{shared_subdirectories}})
			{
				next if not $directory;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; directory: [$directory].\n");
				my $shell_call = "
if [ -e '/shared/$directory' ]
then
	echo '/shared/$directory already exists'
else
	mkdir /shared/$directory; echo rc:\$?
fi";
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
					if ($line =~ /^rc:(\d+)/)
					{
						my $rc = $1;
						if ($rc eq "0")
						{
							AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Created '/shared/$directory' subdirectory.\n");
						}
						else
						{
							AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to create the '/shared/$directory' subdirectory. The return code was: [$rc].\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
				if ($line =~ /context updated/)
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; SElinux context on '/shared' updated.\n");
				}
				if ($line =~ /context ok/)
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; SElinux context on '/shared' was already ok.\n");
				}
				if ($line =~ /failed to update/)
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to update SElinux context on '/shared'.\n");
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code]\n");
	return($return_code);
} 

# This checks for and creates the GFS2 /shared partition if necessary
sub setup_gfs2
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; setup_gfs2(); node: [$node]\n");
	
	my ($lv_ok) = create_shared_lv($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lv_ok: [$lv_ok]\n");
	
	# Now create the partition if the LV was OK
	my $ok          = 1;
	my $create_gfs2 = 1;
	my $return_code = 0;
	if ($lv_ok)
	{
		# Check if the LV already has a GFS2 FS
		my $shell_call = "gfs2_tool sb /dev/$conf->{sys}{vg_pool1_name}/shared uuid; echo rc:\$?";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /current uuid = (.*)$/)
			{
				# This will be useful later in the fstab stage
				$conf->{sys}{shared_fs_uuid} = $1;
				$conf->{sys}{shared_fs_uuid} = lc($conf->{sys}{shared_fs_uuid});
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; GFS2 partition exists on: [/dev/$conf->{sys}{vg_pool1_name}/shared] with UUID: [$conf->{sys}{shared_fs_uuid}]!\n");
				$create_gfs2 = 0;
				$return_code = 1;
			}
			if ($line =~ /^rc:(\d+)/)
			{
				my $rc = $1;
				if ($rc eq "0")
				{
					# GFS2 FS exists
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; GFS2 partition exists!\n");
					$create_gfs2 = 0;
				}
				else
				{
					# Doesn't appear to exist
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; GFS2 partition doesn't exist, will create it.\n");
					$create_gfs2 = 1;
				}
			}
		}
		
		# Create the partition if needed.
		if (($create_gfs2) && (not $conf->{sys}{shared_fs_uuid}))
		{
			my $shell_call = "mkfs.gfs2 -p lock_dlm -j 2 -t $conf->{cgi}{anvil_name}:shared /dev/$conf->{sys}{vg_pool1_name}/shared -O; echo rc:\$?";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
				if ($line =~ /UUID:\s+(.*)$/)
				{
					# This will be useful later in the fstab stage
					$conf->{sys}{shared_fs_uuid} = $1;
					$conf->{sys}{shared_fs_uuid} = lc($conf->{sys}{shared_fs_uuid});
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; GFS2 partition created on: [/dev/$conf->{sys}{vg_pool1_name}/shared] with UUID: [$conf->{sys}{shared_fs_uuid}]!\n");
					$create_gfs2 = 0;
				}
				if ($line =~ /^rc:(\d+)/)
				{
					my $rc = $1;
					if ($rc eq "0")
					{
						# GFS2 FS created
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; GFS2 partition created!\n");
					}
					else
					{
						# Format appears to have failed.
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; GFS2 format of: [/dev/$conf->{sys}{vg_pool1_name}/shared] appears to have failed. The return code was: [$rc]\n");
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# The checks and, if needed, creates the LV for the GFS2 /shared partition
sub create_shared_lv
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; create_shared_lv(); node: [$node]\n");
	
	my $return_code = 0;
	my $create_lv   = 1;
	my $shell_call  = "lvs --noheadings --separator ,; echo rc:\$?";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			if ($rc ne "0")
			{
				# pvs failed...
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Unable to check LVs. The 'lvs' call exited with return code: [$rc]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The LV for the shared GFS2 partition already exists on VG: [$conf->{sys}{vg_pool1_name}].\n");
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code], create_lv: [$create_lv]\n");
	if (($return_code ne "2") && ($create_lv))
	{
		# Create the LV
		my $lv_size    =  AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_media_library_byte_size});
		   $lv_size    =~ s/ //;
		my $shell_call = "lvcreate -L $lv_size -n shared $conf->{sys}{vg_pool1_name}; echo rc:\$?";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /^rc:(\d+)/)
			{
				my $rc = $1;
				if ($rc eq "0")
				{
					# lvcreate succeeded
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Successfully create the logical volume for the '/shared' GFS2 partition.\n");
				}
				else
				{
					# lvcreate failed
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Creating the logical volume for the '/shared' GFS2 partition failed. The 'lvcreate' return code was: [$rc]\n");
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# The checks to see if either PV or VG needs to be created and does so if
# needed.
sub setup_lvm_pv_and_vgs
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; setup_lvm_pv_and_vgs()\n");
	
	# Start 'clvmd' on both nodes.
	my $return_code = 0;
	my ($node1_rc) = start_clvmd_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_rc) = start_clvmd_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_rc: [$node1_rc], node2_rc: [$node2_rc]\n");
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
		$node1_message = "#!string!state_0079!#";
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
		$node2_message = "#!string!state_0079!#";
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pv_rc: [$pv_rc]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; vg_rc: [$vg_rc]\n");
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This creates the VGs if needed
sub create_lvm_vgs
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; create_lvm_vgs(); node: [$node]\n");
	
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			if ($rc ne "0")
			{
				# pvs failed...
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Unable to check which LVM PVs exist. The 'pvs' call exited with return code: [$rc]\n");
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
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The VG for pool 1 needs to be created.\n");
			}
			elsif ($line =~ /\/dev\/drbd0,(.*?),/)
			{
				# VG on r0 doesn't exist, create it.
				$conf->{sys}{vg_pool1_name} = $1;
				$create_vg0                 = 0;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The VG for pool 1 was found, called: [$conf->{sys}{vg_pool1_name}].\n");
			}
			if ($line =~ /\/dev\/drbd1,,/)
			{
				# VG on r0 doesn't exist, create it.
				$create_vg1 = 1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The VG for pool 2 needs to be created.\n");
			}
			elsif ($line =~ /\/dev\/drbd1,(.*?),/)
			{
				# VG on r0 doesn't exist, create it.
				$conf->{sys}{vg_pool2_name} = $1;
				$create_vg1                 = 0;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The VG for pool 2 was found, called: [$conf->{sys}{vg_pool2_name}].\n");
			}
		}
	}
	
	# Create the PVs if needed.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; create_vg0: [$create_vg0], create_vg1: [$create_vg1]\n");
	# PV for pool 1
	if ($create_vg0)
	{
		my $shell_call = "vgcreate $conf->{sys}{vg_pool1_name} /dev/drbd0; echo rc:\$?";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /^rc:(\d+)/)
			{
				my $rc = $1;
				if ($rc eq "0")
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Successfully created the pool 1 volume group: [$conf->{sys}{vg_pool1_name}] using the '/dev/drbd0' PV.\n");
				}
				else
				{
					# Created
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Unable to create the pool 1 volume group: [$conf->{sys}{vg_pool1_name}] on the '/dev/drbd0' PVs. The 'vgcreate' call exited with return code: [$rc]\n");
					$return_code = 2;
				}
			}
		}
	}
	# PV for pool 2
	if (($conf->{cgi}{anvil_storage_pool2_byte_size}) && ($create_vg1))
	{
		my $shell_call = "vgcreate $conf->{sys}{vg_pool2_name} /dev/drbd1; echo rc:\$?";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /^rc:(\d+)/)
			{
				my $rc = $1;
				if ($rc eq "0")
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Successfully created the pool 2 volume group: [$conf->{sys}{vg_pool2_name}] using the '/dev/drbd1' PV.\n");
				}
				else
				{
					# Created
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Unable to create the pool 2 volume group: [$conf->{sys}{vg_pool2_name}] on the '/dev/drbd1' PVs. The 'vgcreate' call exited with return code: [$rc]\n");
					$return_code = 2;
				}
			}
		}
	}
	if (($return_code ne "2") && (not $create_vg0) && (not $create_vg1))
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Both LVM VGs already existed.\n");
		$return_code = 1;
	}
	
	# 0 == OK
	# 1 == already existed
	# 2 == Failed
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code]\n");
	return($return_code);
}

# This creates the PVs if needed
sub create_lvm_pvs
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; create_lvm_pvs(); node: [$node]\n");
	
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			if ($rc ne "0")
			{
				# pvs failed...
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Unable to check which LVM PVs exist. The 'pvs' call exited with return code: [$rc]\n");
				$create_drbd0 = 0;
				$create_drbd1 = 0;
				$return_code  = 2;
			}
		}
		if ($line =~ /\/dev\/drbd0 /)
		{
			$found_drbd0  = 1;
			$create_drbd0 = 0;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The DRBD device '/dev/drbd0' is already a PV.\n");
		}
		if ($line =~ /\/dev\/drbd1 /)
		{
			$found_drbd1  = 1;
			$create_drbd1 = 0;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The DRBD device '/dev/drbd1' is already a PV.\n");
		}
	}
	
	# Create the PVs if needed.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; found_drbd0: [$found_drbd0], found_drbd1: [$found_drbd1]\n");
	# PV for pool 1
	if ($create_drbd0)
	{
		my $shell_call = "pvcreate /dev/drbd0; echo rc:\$?";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /^rc:(\d+)/)
			{
				my $rc = $1;
				if ($rc eq "0")
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Successfully created the '/dev/drbd0' LVM PV.\n");
				}
				else
				{
					# Created
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Unable to create the '/dev/drbd0' LVM PVs. The 'pvcreate' call exited with return code: [$rc]\n");
					$return_code = 2;
				}
			}
		}
	}
	# PV for pool 2
	if (($conf->{cgi}{anvil_storage_pool2_byte_size}) && ($create_drbd1))
	{
		my $shell_call = "pvcreate /dev/drbd1; echo rc:\$?";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /^rc:(\d+)/)
			{
				my $rc = $1;
				if ($rc eq "0")
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Successfully created the '/dev/drbd1' LVM PV.\n");
				}
				else
				{
					# Created
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Unable to create the '/dev/drbd1' LVM PVs. The 'pvcreate' call exited with return code: [$rc]\n");
					$return_code = 2;
				}
			}
		}
	}
	if (($found_drbd0) && ($found_drbd1))
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Both LVM PVs already existed.\n");
		$return_code = 1;
	}
	elsif (($found_drbd0) && (not $conf->{cgi}{anvil_storage_pool2_byte_size}))
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LVM PV was already existed (pool 2 not used).\n");
		$return_code = 1;
	}
	
	# 0 == OK
	# 1 == already existed
	# 2 == Failed
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code]\n");
	return($return_code);
}

# This starts 'clvmd' on a node if it's not already running.
sub start_clvmd_on_node
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; start_clvmd_on_node(); node: [$node]\n");
	
	my $return_code = 255;
	my $shell_call  = "
/etc/init.d/clvmd status &>/dev/null; 
if [ \$? == 3 ];
then 
	/etc/init.d/clvmd start; echo rc:\$?;
else 
	echo 'clvmd already running';
fi";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			if ($rc eq "0")
			{
				# clvmd was started
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Started clvmd on: [$node]\n");
				$return_code = 0;
			}
			else
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to start clvmd on: [$node]\n");
				$return_code = 2;
			}
		}
		if ($line =~ /already running/i)
		{
			$return_code = 1;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; clvmd was already running on: [$node]\n");
		}
	}
	
	# 0 = Started
	# 1 = Already running
	# 2 = Failed
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code]\n");
	return($return_code);
}

# This is used by the stage-3 storage function to bring up DRBD
sub drbd_first_start
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; drbd_first_start()\n");
	
	my $return_code = 255;
	
	# Start DRBD manually and if both nodes are Inconsistent for a given resource, run;
	# drbdadm -- --overwrite-data-of-peer primary <res>
	my ($node1_attach_rc, $node1_attach_message) = do_drbd_attach_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_attach_rc, $node2_attach_message) = do_drbd_attach_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_attach_rc: [$node1_attach_rc], node1_attach_message: [$node1_attach_message], node2_attach_rc: [$node2_attach_rc], node2_attach_message: [$node2_attach_message]\n");
	# 0 == Success
	# 1 == Failed to load kernel module
	# 2 == One of the resources is Diskless
	# 3 == Attach failed.
	
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_ping_ok: [$node1_ping_ok], node2_ping_ok: [$node2_ping_ok]\n");
		if (($node1_ping_ok) && ($node2_ping_ok))
		{
			# Both nodes have both of their resources attached and
			# are pingable on the SN, connect them now.
			($node1_connect_rc, $node1_connect_message) = do_drbd_connect_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
			($node2_connect_rc, $node2_connect_message) = do_drbd_connect_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_connect_rc: [$node1_connect_rc], node1_connect_message: [$node1_connect_message], node2_connect_rc: [$node2_connect_rc], node2_connect_message: [$node2_connect_message]\n");
			# 0 == OK
			# 1 == Failed to connect
			
			# Finally, make primary
			if ((not $node1_connect_rc) || (not $node2_connect_rc))
			{
				# Make sure both nodes are, indeed, connected.
				my ($rc) = verify_drbd_resources_are_connected($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc]\n");
				# 0 == OK
				# 1 == Failed to connect
				
				if (not $rc)
				{
					# Check to see if both nodes are 
					# 'Inconsistent'. If so, force node 1 to be
					# primary to begin the initial sync.
					my ($rc, $force_node1_r0, $force_node1_r1) = check_drbd_if_force_primary_is_needed($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc], force_node1_r0: [$force_node1_r0], force_node1_r1: [$force_node1_r1]\n");
					# 0 == Both resources found, safe to proceed
					# 1 == One or both of the resources not found
					
					# This RC check is just a little paranoia
					# before doing a potentially destructive call.
					if (not $rc)
					{
						# Promote to primary!
						($node1_primary_rc, $node1_primary_message) = do_drbd_primary_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $force_node1_r0, $force_node1_r1);
						($node2_primary_rc, $node2_primary_message) = do_drbd_primary_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, "0", "0");
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_primary_rc: [$node1_primary_rc], node1_primary_message: [$node1_primary_message], node2_primary_rc: [$node2_primary_rc], node2_primary_message: [$node2_primary_message]\n");
						# 0 == OK
						# 1 == Failed to make primary
						if ((not $node1_primary_rc) || (($conf->{cgi}{anvil_storage_pool2_byte_size}) && (not $node2_primary_rc)))
						{
							# Woohoo!
							AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; DRBD promoted to 'Primary' on both nodes.\n");
						}
						else
						{
							$return_code = 5;
							AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; One or more resources failed to promote to 'Primary'.\n");
						}
					}
				}
				else
				{
					$return_code = 4;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; One or both resource failed to connect.\n");
				}
			}
			else
			{
				$return_code = 3;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; One or more resources failed to enter connecting state.\n");
			}
		}
		else
		{
			$return_code = 2;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to ping peer on SN.\n");
		}
	}
	else
	{
		$return_code = 1;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; One or more resources failed to attach.\n");
	}
	
	# 0 == OK
	# 1 == Attach failed
	# 2 == Can't ping on SN
	# 3 == Connect failed
	# 4 == Both nodes entered connencted state but didn't actually connect
	# 5 == Promotion to 'Primary' failed.
	my $ok = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0014!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0014!#";
	# Node messages are interleved
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code]\n");
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This connects to node 1 and checks to ensure both resource are in the
# 'Connected' state
sub verify_drbd_resources_are_connected
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; verify_drbd_resources_are_connected()\n");
	
	# Give the previous start call a few seconds to take effect.
	sleep 5;
	
	# Ok, go.
	my $return_code  = 0;
	my $r0_connected = 0;
	my $r1_connected = 0;
	my $shell_call   = "cat /proc/drbd";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /^0: /)
		{
			my $connected_state = ($line =~ /cs:(.*?)\s/)[0];
			if (($connected_state =~ /Connected/i) || ($connected_state =~ /Sync/i))
			{
				$r0_connected = 1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; resource 'r0' is connected.\n");
			}
			else
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; resource 'r0' is NOT connected! The connection state is: [$connected_state].\n");
			}
		}
		if ($line =~ /^1: /)
		{
			my $connected_state = ($line =~ /cs:(.*?)\s/)[0];
			if (($connected_state =~ /Connected/i) || ($connected_state =~ /Sync/i))
			{
				$r1_connected = 1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; resource 'r1' is connected.\n");
			}
			else
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; resource 'r1' is NOT connected! The connection state is: [$connected_state].\n");
			}
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; r0_connected: [$r0_connected], r1_connected: [$r1_connected]\n");
	if ((not $r0_connected) || (($conf->{cgi}{anvil_storage_pool2_byte_size}) && (not $r1_connected)))
	{
		$return_code = 1;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; One or both of the resources is not connected.\n");
	}
	
	# 0 == Both resources found, safe to proceed
	# 1 == One or both of the resources not found
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code]\n");
	return($return_code);
}

# This promotes the DRBD resources to Primary, forcing if needed.
sub do_drbd_primary_on_node
{
	my ($conf, $node, $password, $force_r0, $force_r1) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; do_drbd_primary_on_node(); force_r0: [$force_r0], force_r1: [$force_r1]\n");
	
	# Resource 0
	my $return_code = 0;
	my $message     = "";
	my $shell_call  = "drbdadm primary r0; echo rc:\$?";
	if ($force_r0)
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Forcing 'r0' to 'Primary' and overwriting data on peer!\n");
		$shell_call = "drbdadm -- --overwrite-data-of-peer primary r0; echo rc:\$?";
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			if ($rc eq "0")
			{
				# Success!
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource 'r0' promoted to 'Primary' successfully.\n");
			}
			else
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to promote resource 'r0' on node: [$node] to 'Primary'!\n");
				$message .= AN::Common::get_string($conf, {key => "message_0400", variables => { resource => "r0", node => $node }});
				$return_code = 1;
			}
		}
	}
	
	# Resource 1
	if ($conf->{cgi}{anvil_storage_pool2_byte_size})
	{
		$shell_call  = "drbdadm primary r1; echo rc:\$?";
		if ($force_r0)
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Forcing 'r1' to 'Primary' and overwriting data on peer!\n");
			$shell_call = "drbdadm -- --overwrite-data-of-peer primary r1; echo rc:\$?";
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
		($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /^rc:(\d+)/)
			{
				my $rc = $1;
				if ($rc eq "0")
				{
					# Success!
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource 'r1' promoted to 'Primary' successfully.\n");
				}
				else
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to promote resource 'r1' on node: [$node] to 'Primary'!\n");
					$message .= AN::Common::get_string($conf, {key => "message_0400", variables => { resource => "r0", node => $node }});
					$return_code = 1;
				}
			}
		}
	}
	
	# If we're OK, call 'drbdadm adjust all' to make sure the requested
	# sync rate takes effect.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code]\n");
	if (not $return_code)
	{
		my $shell_call = "drbdadm adjust all";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		}
	}
	
	# 0 == OK
	# 1 == Failed to make primary
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code], message: [$message]\n");
	return($return_code, $message);
}

# This uses node 1 to check the Connected disk states of the resources are both
# Inconsistent.
sub check_drbd_if_force_primary_is_needed
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; check_drbd_if_force_primary_is_needed(); node: [$node]\n");
	
	my $return_code = 0;
	my $found_r0    = 0;
	my $force_r0    = 0;
	my $force_r1    = 0;
	my $found_r1    = 0;
	my $shell_call  = "cat /proc/drbd";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
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
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; resource 'r0' disk states; node1: [$node1_ds], node2: [$node2_ds]\n");
				if (($node1_ds =~ /Inconsistent/i) && ($node2_ds =~ /Inconsistent/i))
				{
					$force_r0 = 1;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; resource 'r0' needs to be forced to primary.\n");
				}
				else
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Will NOT force 'r0' to primary.\n");
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
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; resource 'r1' disk states; node1: [$node1_ds], node2: [$node2_ds]\n");
				if (($node1_ds =~ /Inconsistent/i) && ($node2_ds =~ /Inconsistent/i))
				{
					$force_r0 = 1;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; resource 'r1' needs to be forced to primary.\n");
				}
				else
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Will NOT force 'r1' to primary.\n");
				}
			}
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; found_r0: [$found_r0], found_r1: [$found_r1]\n");
	if ((not $found_r0) || (($conf->{cgi}{anvil_storage_pool2_byte_size}) && (not $found_r1)))
	{
		$return_code = 1;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; One or both of the resources was not found.\n");
	}
	
	# 0 == Both resources found, safe to proceed
	# 1 == One or both of the resources not found
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; force_r0: [$force_r0], force_r1: [$force_r1]\n");
	return($return_code, $force_r0, $force_r1);
}

# This calls 'connect' of each resource on a node.
sub do_drbd_connect_on_node
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; do_drbd_connect_on_node(); node: [$node]\n");
	
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /^$resource: /)
			{
				# Try to connect the resource.
				my $connection_state = ($line =~ /cs:(.*?)\//)[0];
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [r$resource], connection state: [$connection_state]\n");
				if ($connection_state =~ /StandAlone/i)
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [r$resource], is stand-alone, will connect it.\n");
					$connected = 0;
				}
				elsif ($connection_state)
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [r$resource], is already in connection state: [$connection_state].\n");
					$connected = 1;
				}
			}
		}
		
		# Now connect if needed.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [r$resource], connected: [$connected]\n");
		if (not $connected)
		{
			my $shell_call = "drbdadm connect r$resource; echo rc:\$?";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
				if ($line =~ /^rc:(\d+)/)
				{
					my $rc = $1;
					if ($rc eq "0")
					{
						# Success!
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [r$resource] connected successfully.\n");
					}
					else
					{
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to connect resource: [r$resource] on node: [$node]!\n");
						$message .= AN::Common::get_string($conf, {key => "message_0401", variables => { resource => "r$resource", node => $node }});
						$return_code = 1;
					}
				}
			}
		}
	}
	
	# 0 == OK
	# 1 == Failed to connect
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code], message: [$message]\n");
	return($return_code, $message);
}

# This attaches the backing devices on each node, modprobe'ing drbd if needed.
sub do_drbd_attach_on_node
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; do_drbd_attach_on_node(); node: [$node]\n");
	
	my $message     = "";
	my $return_code = 0;
	# First up, is the DRBD kernel module loaded?
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
fi;";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /failed to load/i)
		{
			$return_code = 1;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to load 'drbd' kernel module on node: [$node]\n");
		}
		elsif ($line =~ /already loaded/i)
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Node: [$node] 'drbd' kernel module already loaded.\n");
		}
		elsif ($line =~ /loaded DRBD/i)
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Node: [$node] 'drbd' kernel was loaded.\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
				if ($line =~ /^$resource: /)
				{
					# Resource found, check disk state, but
					# unless it's "Diskless", we're already
					# attached because unattached disks
					# cause the entry
					my $disk_state = ($line =~ /ds:(.*?)\//)[0];
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [r$resource], disk state: [$disk_state]\n");
					if ($disk_state =~ /Diskless/i)
					{
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [r$resource], is diskless! This might be the sign of a failed array or disk.\n");
						$message .= AN::Common::get_string($conf, {key => "message_0399", variables => { resource => "r$resource", node => $node }});
						$attached = 2;
					}
					elsif ($disk_state)
					{
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [r$resource], is already attached.\n");
						$attached = 1;
					}
				}
			}
			
			# Now attach if needed.
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [r$resource], attached: [$attached]\n");
			if (not $attached)
			{
				my $no_metadata = 0;
				my $shell_call  = "drbdadm attach r$resource; echo rc:\$?";
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
					if ($line =~ /No valid meta-data signature found/i)
					{
						# resource 0 == poo1 1, 1 == pool 2
						my $pool     = $resource eq "0" ? "pool1" : "pool2";
						my $device   = $conf->{node}{$node}{$pool}{device};
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [r$resource], pool: [$pool], device: [$device] - No metadata found!\n");
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
							AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], resource: [r$resource] attached successfully.\n");
						}
						elsif (not $no_metadata)
						{
							# I skip this if '$no_metadata' is set as I've already generated a message for the user.
							AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to attach resource: [r$resource] on node: [$node]!\n");
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code], message: [$message]\n");
	return($return_code, $message);
}

# This creates the root user's id_rsa keys and then populates
# ~/.ssh/known_hosts on both nodes.
sub configure_ssh
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_ssh()\n");
	
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; I have both node's RSA keys, checking/populating /root/.ssh/authorized_keys\n");
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This adds each node's RSA public key to the node's ~/.ssh/authorized_keys
# file if needed.
sub populate_authorized_keys_on_node
{
	my ($conf, $node, $password, $node1_rsa, $node2_rsa) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; populate_authorized_keys_on_node(); node: [$node]\n");
	
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		}
		
		# Verify it was added.
		$shell_call = "
if \$(grep -q \"$node1_rsa\" /root/.ssh/authorized_keys)
then
	echo added
else
	echo failed
fi";
		($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /added/)
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Node 1 RSA key added to node: [$node].\n");
			}
			elsif ($line =~ /failed/)
			{
				$ok = 0;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to add Node 1's RSA key to node: [$node]!\n");
			}
		}
	}
	
	# Node 2.
	if (1)
	{
		my $shell_call = "echo \"$node2_rsa\" >> /root/.ssh/authorized_keys";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		}
		
		# Verify it was added.
		$shell_call = "
if \$(grep -q \"$node2_rsa\" /root/.ssh/authorized_keys)
then
	echo added
else
	echo failed
fi";
		($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /added/)
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Node 2 RSA key added to node: [$node].\n");
			}
			elsif ($line =~ /failed/)
			{
				$ok = 0;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to add Node 2's RSA key to node: [$node]!\n");
			}
		}
	}
	
	return($ok);
}

# This adds any missing ssh fingerprints to a node
sub populate_known_hosts_on_node
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; populate_known_hosts_on_node(); node: [$node]\n");
	
	my $ok = 1;
	foreach my $name (@{$conf->{sys}{node_names}})
	{
		# If a node is being replaced, the old entries will no longer
		# match. So as a precaution, existing keys are removed if
		# found.
		next if not $name;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; checking/adding fingerprint for: [$name]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			if ($line =~ /fingerprint recorded/)
			{
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node] name: [$name] previously recorded.\n");
			}
			elsif ($line =~ /fingerprint added/)
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node] name: [$name] added.\n");
			}
			elsif ($line =~ /failed to record/)
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to record name: [$name]'s fingerprint on node: [$node]!\n");
				$ok = 0;
			}
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]!\n");
	return($ok);
}

# Read in the RSA public key from a node, creating the RSA keys if needed.
sub get_node_rsa_public_key
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; get_node_rsa_public_key(); node: [$node]\n");
	
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
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /^ssh-rsa /)
		{
			$rsa_key = $line;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node] root RSA key: [$rsa_key]\n");
		}
		elsif ($line =~ /Your public key has been saved in/i)
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node] root RSA key was generated.\n");
		}
	}
	
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rsa_key: [$rsa_key]\n");
	return($rsa_key);
}

# This checks that the nodes are ready to start cman and, if so, does so.
sub start_cman
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; start_cman()\n");
	
	my $node1_rc = 0;
	my $node2_rc = 0;
	# See if cman is running already.
	my ($node1_cman_state) = get_daemon_state($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, "cman");
	my ($node2_cman_state) = get_daemon_state($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, "cman");
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_cman_state: [$node1_cman_state], node2_cman_state: [$node2_cman_state]\n");
	# 1 == running, 0 == stopped.

	# First thing, make sure each node can talk to the other on the BCN.
	my ($node1_ok) = ping_node_from_other($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $conf->{cgi}{anvil_node2_bcn_ip});
	my ($node2_ok) = ping_node_from_other($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $conf->{cgi}{anvil_node1_bcn_ip});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_ok: [$node1_ok], node2_ok: [$node2_ok]\n");
	
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
		# Start on both (this uses a fork to start them at the same
		# time)
		start_cman_on_both_nodes($conf);
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Checking is cman started on both nodes.\n");
		
		my ($node1_cman_state) = get_daemon_state($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, "cman");
		my ($node2_cman_state) = get_daemon_state($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, "cman");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_cman_state: [$node1_cman_state], node2_cman_state: [$node2_cman_state]\n");
		# 1 == running, 0 == stopped.
		
		if (($node1_cman_state) && ($node2_cman_state))
		{
			# \o/
			$node1_rc = 2;
			$node2_rc = 2;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Successfully started cman on both nodes.\n");
		}
		elsif ($node1_cman_state)
		{
			# Only node 1 started... node 2 was probably fenced.
			$node1_rc = 2;
			$node2_rc = 4;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Only started cman on node 1: [$conf->{cgi}{anvil_node1_current_ip}], failed on node 2: [$conf->{cgi}{anvil_node1_current_password}].\n");
		}
		elsif ($node2_cman_state)
		{
			# Only node 2 started... node 1 was probably fenced.
			$node1_rc = 4;
			$node2_rc = 2;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Only started cman on node 2: [$conf->{cgi}{anvil_node2_current_ip}], failed on node 1: [$conf->{cgi}{anvil_node2_current_password}].\n");
		}
		else
		{
			# Well crap...
			$node1_rc = 4;
			$node2_rc = 4;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to start cman both nodes!\n");
		}
	}
	elsif (not $node1_cman_state)
	{
		# Node 2 is running, node 1 isn't, start it.
		start_cman_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
		my ($node1_cman_state) = get_daemon_state($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, "cman");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_cman_state: [$node1_cman_state], node2_cman_state: [$node2_cman_state]\n");
		if ($node1_cman_state)
		{
			# Started!
			$node2_rc = 2;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Successfully startes cman on node 1: [$conf->{cgi}{anvil_node1_current_ip}].\n");
		}
		else
		{
			# Failed to start.
			$node1_rc = 4;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to start cman on node 1: [$conf->{cgi}{anvil_node1_current_ip}].\n");
		}
	}
	elsif (not $node2_cman_state)
	{
		# Node 1 is running, node 2 isn't, start it.
		start_cman_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
		my ($node2_cman_state) = get_daemon_state($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, "cman");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node2_cman_state: [$node2_cman_state], node2_cman_state: [$node2_cman_state]\n");
		if ($node2_cman_state)
		{
			# Started!
			$node2_rc = 2;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Successfully startes cman on node 2: [$conf->{cgi}{anvil_node2_current_ip}].\n");
		}
		else
		{
			# Failed to start.
			$node2_rc = 4;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to start cman on node 2: [$conf->{cgi}{anvil_node2_current_ip}].\n");
		}
	}
	else
	{
		# Both are already running
		$node1_rc = 3;
		$node2_rc = 3;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cman was already running on both nodes.\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_fence_ok: [$node1_fence_ok], node2_fence_ok: [$node2_fence_ok]\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_return_message: [$node1_return_message]\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node2_return_message: [$node2_return_message]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_fence_ok bad, setting 'ok': [$ok]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_fence_ok bad, setting 'ok': [$ok]\n");
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This calls 'check_fence' on the node to verify if fencing is working.
sub check_fencing_on_node
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; check_fencing_on_node(); node: [$node]\n");
	
	my $message = "";
	my $ok      = 1;
	my $shell_call = "fence_check -f; echo rc:\$?";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /rc:(\d+)/)
		{
			# 0 == OK
			# 5 == Failed
			my $rc = $1;
			if ($rc eq "0")
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Fence check passed!\n");
			}
			else
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Fence check appears to have reported failures! Return code: [$rc]\n");
				$ok = 0;
			}
		}
		else
		{
			$message .= "$line<br />\n";
		}
	}
	$message =~ s/<br \/>\n$//;
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok, $message);
}

# This is like start_cman_on_both_nodes(), except it doesn't fork.
sub start_cman_on_node
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; start_cman_on_node(); node: [$node]\n");
	
	my $shell_call = "/etc/init.d/cman start";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
	}
	
	return(0)
}
	

# This forks to start cman on both nodes at the same time.
sub start_cman_on_both_nodes
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; start_cman_on_both_nodes()\n");
	
	my $ok = 1;
	### NOTE: This is heavily based on AN::Striker::dual_join, but stripped
	###       down.
	# I need to fork here because the calls won't return until cman
	# either talks to it's peer or fences it.
	my $parent_pid = $$;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Parent process has PID: [$parent_pid]. Spawning a child process for each node.\n");
	my %pids;
	my $node_count = 2;
	foreach my $node (sort {$a cmp $b} ($conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node2_current_ip}))
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
			### NOTE: The password on both nodes should be the same
			###       now so I just use node 1's root password for
			###       both child processes.
			# This is the child thread, so do the call.
			# Note that, without the 'die', we could end
			# up here if the fork() failed.
			my ($error, $ssh_fh, $output) = AN::Cluster::remote_call($conf, {
				node		=>	$node,
				port		=>	22,
				user		=>	"root",
				password	=>	$conf->{cgi}{anvil_node1_current_password},
				ssh_fh		=>	"",
				'close'		=>	1,
				shell_call	=>	"/etc/init.d/cman start",
			});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; PID: [$$], error: [$error], ssh_fh: [$ssh_fh], output: [$output (".@{$output}." lines)]\n");
			foreach my $line (@{$output})
			{
				next if not $line;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; PID: [$$], node: [$node], line: [$line]\n");
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
			if ($saw_reaped > ($node_count + 1))
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Parent process reaped: [$saw_reaped] children when only two were spawned.\n");
			}
		}
		while $pid > 0;	# This re-enters the do() loop for as
				# long as the PID returned by wait()
				# was >0.
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; All child processes reaped, exiting threaded execution.\n");
	
	# Wipe out the file SSH handles as the fork clobbers them anyway so the
	# next call will have to reconnect fresh.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Resetting SSH session handles.\n");
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	$conf->{node}{$node1}{ssh_fh} = "";
	$conf->{node}{$node2}{ssh_fh} = "";
	
	return(0);
}

# This doesn a simple ping test from one node to the other.
sub ping_node_from_other
{
	my ($conf, $node, $password, $target_ip) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ping_node_from_other(); node: [$node], target_ip: [$target_ip]\n");
	
	my $success    = 0;
	my $ping_rc    = 255;
	my $shell_call = "ping -n $target_ip -c 1; echo ping:\$?";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /(\d+) packets transmitted, (\d+) received/)
		{
			# This isn't really needed, but might help folks
			# watching the logs.
			my $pings_sent     = $1;
			my $pings_received = $2;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; target_ip: [$target_ip], pings_sent: [$pings_sent], pings_received: [$pings_received]\n");
		}
		if ($line =~ /ping:(\d+)/)
		{
			$ping_rc = $1;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ping_rc: [$ping_rc] (0 == pingable)\n");
			$success = 1 if not $ping_rc;
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; success: [$success]\n");
	return($success);
}

# This sets the 'ricci' user's passwords.
sub set_ricci_password
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; set_ricci_password()\n");
	
	### NOTE: For now, ricci and root passwords are set to the same thing.
	###       This might change later, so this function is designed to
	###       support different passwords.
	# Set the passwords on the nodes.
	my $ok = 1;
	my ($node1_ricci_pw) = set_password_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, "ricci", $conf->{cgi}{anvil_password});
	my ($node2_ricci_pw) = set_password_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, "ricci", $conf->{cgi}{anvil_password});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_ricci_pw: [$node1_ricci_pw], node2_ricci_pw: [$node2_ricci_pw]\n");
	
	# Test the new password.
	my ($node1_access) = check_node_access($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_access) = check_node_access($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_access: [$node1_access], node2_access: [$node2_access]\n");
	
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This sets the 'root' user's passwords.
sub set_root_password
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; set_root_password()\n");
	
	### NOTE: For now, ricci and root passwords are set to the same thing.
	###       This might change later, so this function is designed to
	###       support different passwords.
	# Set the passwords on the nodes.
	my $ok = 1;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> cgi::anvil_node1_current_password: [$conf->{cgi}{anvil_node1_current_password}], cgi::anvil_node2_current_password: [$conf->{cgi}{anvil_node2_current_password}]\n");
	($conf->{cgi}{anvil_node1_current_password}) = set_password_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, "root", $conf->{cgi}{anvil_password});
	($conf->{cgi}{anvil_node2_current_password}) = set_password_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, "root", $conf->{cgi}{anvil_password});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << cgi::anvil_node1_current_password: [$conf->{cgi}{anvil_node1_current_password}], cgi::anvil_node2_current_password: [$conf->{cgi}{anvil_node2_current_password}]\n");
	
	# Test the new password.
	my ($node1_access) = check_node_access($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_access) = check_node_access($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_access: [$node1_access], node2_access: [$node2_access]\n");
	
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This updates the ricci and root passwords, and closes the connection after
# 'root' is changed. After this function, the next login will be a new one.
sub set_password_on_node
{
	my ($conf, $node, $password, $user, $new_password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; set_password_on_node(); node: [$node], user: [$user], new_password: [$new_password]\n");
	
	# Set the 'ricci' password first.
	my $shell_call = "echo '$new_password' | passwd $user --stdin";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
	#foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n"); }
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; new_password: [$new_password]\n");
	return($new_password);
}

# This creates a backup of /etc/sysconfig/network-scripts into /root/backups
# and then creates a .anvil copy of lvm.conf and, if it exists, the DRBD and
# cman config files
sub backup_files
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; backup_files()\n");
	
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
	
	# Create the backup directory if it doesn't exist yet.
	my $shell_call = "
if [ -e '$conf->{path}{nodes}{backups}' ];
then 
	echo \"Backup directory exist\";
else 
	mkdir -p $conf->{path}{nodes}{backups}; 
fi";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
	#foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n"); }
	
	# Backup the original network config
	$shell_call = "
if [ -e '$conf->{path}{nodes}{backups}/network-scripts' ];
then 
	echo \"Network configuration files previously backed up\";
else 
	rsync -av $conf->{path}{nodes}{network_scripts} $conf->{path}{nodes}{backups}/;
fi";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	#foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n"); }
	
	# Backup the original SSH config
	$shell_call = "
if [ -e '$conf->{path}{nodes}{backups}/.ssh' ];
then 
	echo \"SSH configuration files previously backed up\";
else 
	rsync -av /root/.ssh $conf->{path}{nodes}{backups}/;
fi";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	#foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n"); }
	
	# Backup DRBD if it exists.
	$shell_call = "
if [ -e '$conf->{path}{nodes}{drbd}' ] && [ ! -e '$conf->{path}{nodes}{backups}/drbd.d' ];
then 
	rsync -av $conf->{path}{nodes}{drbd} $conf->{path}{nodes}{backups}/; 
else 
	echo \"DRBD backup not needed\"; 
fi";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	#foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n"); }
	
	# Backup lvm.conf.
	$shell_call = "
if [ ! -e '$conf->{path}{nodes}{backups}/lvm.conf' ];
then 
	rsync -av $conf->{path}{nodes}{lvm_conf} $conf->{path}{nodes}{backups}/; 
else 
	echo \"LVM previously backed up, skipping.\"; 
fi";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	#foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n"); }
	
	# Backup cluster.conf.
	$shell_call = "
if [ ! -e '$conf->{path}{nodes}{backups}/cluster.conf' ];
then 
	rsync -av $conf->{path}{nodes}{cluster_conf} $conf->{path}{nodes}{backups}/; 
else 
	echo \"cman previously backed up, skipping.\"; 
fi";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	#foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n"); }
	
	# Backup fstab.
	$shell_call = "
if [ ! -e '$conf->{path}{nodes}{backups}/fstab' ];
then 
	rsync -av $conf->{path}{nodes}{fstab} $conf->{path}{nodes}{backups}/; 
else 
	echo \"fstab previously backed up, skipping.\"; 
fi";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	#foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n"); }
	
	# Backup shadow.
	$shell_call = "
if [ ! -e '$conf->{path}{nodes}{backups}/shadow' ];
then 
	rsync -av $conf->{path}{nodes}{shadow} $conf->{path}{nodes}{backups}/; 
else 
	echo \"shadow previously backed up, skipping.\"; 
fi";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	#foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n"); }
	
	return(0);
}

# This configures IPMI
sub configure_ipmi
{
	my ($conf) = @_;
	
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_ipmi_on_node(); node: [$node], ipmi_ip: [$ipmi_ip], ipmi_netmask: [$ipmi_netmask], ipmi_password: [$ipmi_password], ipmi_user: [$ipmi_user], ipmi_gateway: [$ipmi_gateway]\n");
	
	if ($conf->{sys}{ipmi}{$node}{password})
	{
		$ipmi_password = $conf->{sys}{ipmi}{$node}{password};
	}
	
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; state: [$state]\n");
	if ($state eq "7")
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; IPMI not found on node: [$node]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; channel: [$channel]\n");
			if ($channel > 10)
			{
				# Give up...
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to find the IPMI LAN channel!\n");
				$channel = "";
				last;
			}
			
			# check to see if this is the write channel
			my $rc         = "";
			my $shell_call = "ipmitool lan print $channel; echo rc:\$?";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
				if ($line =~ /Invalid channel: /)
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Wrong lan channel: [$channel]\n");
				}
				elsif ($line =~ "rc:0")
				{
					# Found it!
					$lan_found = 1;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Found the lan channel: [$channel]!\n");
				}
			}
			$channel++ if not $lan_found;
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; LAN channel: [$channel]!\n");
		
		# Now find the admin user ID number
		my $user_id   = "";
		my $uid_found = 0;
		if ($lan_found)
		{
			while (not $uid_found)
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; user_id: [$user_id]\n");
				if ($user_id > 10)
				{
					# Give up...
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to find the IPMI admin user ID!\n");
					$user_id = "";
					last;
				}
				
				# check to see if this is the write channel
				my $rc         = "";
				my $shell_call = "ipmitool user list $channel";
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
				my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
					node		=>	$node,
					port		=>	22,
					user		=>	"root",
					password	=>	$password,
					ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
					'close'		=>	0,
					shell_call	=>	$shell_call,
				});
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
				foreach my $line (@{$return})
				{
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
					$line =~ s/\s+/ /g;
					if ($line =~ /^(\d+) $ipmi_user /)
					{
						$user_id   = $1;
						$uid_found = 1;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Found user ID: [$user_id]\n");
					}
				}
				$user_id++ if not $uid_found;
			}
			
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; User: [$ipmi_user] has ID: [$user_id]\n");
			if ($uid_found)
			{
				# Set the password.
				my $shell_call = "ipmitool user set password $user_id '$ipmi_password'";
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
				my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
					node		=>	$node,
					port		=>	22,
					user		=>	"root",
					password	=>	$password,
					ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
					'close'		=>	0,
					shell_call	=>	$shell_call,
				});
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
				foreach my $line (@{$return})
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
				}
				
				# Test the password. If this fails with '16',
				# try '20'.
				my $password_ok = 0;
				my $try_20      = 0;
				   $shell_call  = "ipmitool user test $user_id 16 '$ipmi_password'";
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
				($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
					node		=>	$node,
					port		=>	22,
					user		=>	"root",
					password	=>	$password,
					ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
					'close'		=>	0,
					shell_call	=>	$shell_call,
				});
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
				foreach my $line (@{$return})
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
					if ($line =~ /Success/i)
					{
						# Woo!
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], IPMI password set successfully as a 16-byte string!\n");
					}
					elsif ($line =~ /wrong password size/i)
					{
						$try_20 = 1;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; IPMI password is not a 16-byte string, will try 20-byte.\n");
					}
					elsif ($line =~ /password incorrect/i)
					{
						# Password didn't take. :(
						$return_code = 1;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; IPMI password failed to be set properly.\n");
					}
				}
				if ($try_20)
				{
					my $shell_call  = "ipmitool user test $user_id 20 '$ipmi_password'";
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
					my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
						node		=>	$node,
						port		=>	22,
						user		=>	"root",
						password	=>	$password,
						ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
						'close'		=>	0,
						shell_call	=>	$shell_call,
					});
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
					foreach my $line (@{$return})
					{
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
						if ($line =~ /Success/i)
						{
							# Woo!
							AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], IPMI password set successfully as a 20-byte string!\n");
						}
						elsif ($line =~ /password incorrect/i)
						{
							# Password didn't take. :(
							$return_code = 1;
							AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; IPMI password failed to be set properly.\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
			my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
				node		=>	$node,
				port		=>	22,
				user		=>	"root",
				password	=>	$password,
				ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
			foreach my $line (@{$return})
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
			}
			
			# Now set the IP
			$shell_call = "ipmitool lan set $channel ipaddr $ipmi_ip";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
			($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
				node		=>	$node,
				port		=>	22,
				user		=>	"root",
				password	=>	$password,
				ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
			foreach my $line (@{$return})
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
			}
			
			# Now the netmask
			$shell_call = "ipmitool lan set $channel netmask $ipmi_netmask";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
			($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
				node		=>	$node,
				port		=>	22,
				user		=>	"root",
				password	=>	$password,
				ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
			foreach my $line (@{$return})
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
			}
			
			# If the user has specified a gateway, set it
			if ($ipmi_gateway)
			{
				my $shell_call = "ipmitool lan set $channel defgw ipaddr $ipmi_gateway";
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
				my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
					node		=>	$node,
					port		=>	22,
					user		=>	"root",
					password	=>	$password,
					ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
					'close'		=>	0,
					shell_call	=>	$shell_call,
				});
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
				foreach my $line (@{$return})
				{
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
				}
			}
			
			### Now read it back.
			# Now the netmask
			$shell_call = "ipmitool lan print $channel";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
			($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
				node		=>	$node,
				port		=>	22,
				user		=>	"root",
				password	=>	$password,
				ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
				'close'		=>	0,
				shell_call	=>	$shell_call,
			});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
			foreach my $line (@{$return})
			{
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> return line: [$line]\n");
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				$line =~ s/\s+/ /g;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << return line: [$line]\n");
				if ($line =~ /IP Address Source/i)
				{
					if ($line =~ /Static/i)
					{
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; IPMI IP is static now.\n");
					}
					else
					{
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; IPMI IP is NOT static!\n");
						$return_code = 5;
						last;
					}
				}
				if ($line =~ /IP Address :/i)	# Needs the ' :' to not match 'IP Address Source'
				{
					my $ip = ($line =~ /(\d+\.\d+\.\d+\.\d+)$/)[0];
					if ($ip eq $ipmi_ip)
					{
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; IPMI IP is now: [$ipmi_ip]\n");
					}
					else
					{
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; IPMI reported IP: [$ip] doesn't match desired IP: [$ipmi_ip]!\n");
						$return_code = 6;
						last;
					}
				}
				if ($line =~ /Subnet Mask/i)
				{
					my $ip = ($line =~ /(\d+\.\d+\.\d+\.\d+)$/)[0];
					if ($ip eq $ipmi_netmask)
					{
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; IPMI subnet is now: [$ipmi_netmask]\n");
					}
					else
					{
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; IPMI reported subnet: [$ip] doesn't match desired subnet: [$ipmi_netmask]!\n");
						$return_code = 7;
						last;
					}
				}
			}
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code]\n");
	return($return_code);
}

# This sets nodes to start or stop on boot.
sub configure_daemons
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_daemons()\n");
	
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This enables and disables daemons on boot for a node.
sub configure_daemons_on_node
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_daemons_on_node(); node: [$node]\n");
	
	my $ok     = 1;
	my $return = "";
	
	# Enable daemons
	foreach my $daemon (sort {$a cmp $b} @{$conf->{sys}{daemons}{enable}})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], enabling daemon: [$daemon]\n");
		
		my ($init3, $init5) = get_chkconfig_data($conf, $node, $password, $daemon);
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; init3: [$init3], init5: [$init5].\n");
		if (($init3 eq "1") && ($init5 eq "1"))
		{
			# Already enabled.
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], daemon: [$daemon], already enabled on boot.\n");
		}
		else
		{
			# Enable it.
			set_chkconfig($conf, $node, $password, $daemon, "on");
			my ($init3, $init5) = get_chkconfig_data($conf, $node, $password, $daemon);
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; init3: [$init3], init5: [$init5].\n");
			if (($init3 eq "1") && ($init5 eq "1"))
			{
				# Success
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], daemon: [$daemon], now enabled on boot.\n");
			}
			else
			{
				# failed. :(
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to enable daemon: [$daemon] on node: [$node]!\n");
				$return .= "failed to enable:$daemon,";
				$ok = 0;
			}
		}
		
		# Now check/start the daemon if needed
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok].\n");
		if ($ok)
		{
			
			my ($state) = get_daemon_state($conf, $node, $password, $daemon);
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], daemon: [$daemon], state: [$state].\n");
			if ($state eq "1")
			{
				# Already running.
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], daemon: [$daemon] is already running.\n");
			}
			elsif ($state eq "0")
			{
				# Enable it.
				set_daemon_state($conf, $node, $password, $daemon, "start");
				my ($state) = get_daemon_state($conf, $node, $password, $daemon);
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], daemon: [$daemon], state: [$state].\n");
				if ($state eq "1")
				{
					# Now running.
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], daemon: [$daemon] was started.\n");
				}
				elsif ($state eq "0")
				{
					# Failed to start
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to start daemon: [$daemon] on node: [$node]!\n");
					$return .= "failed to start:$daemon,";
				}
			}
		}
	}
	
	# Now disable daemons.
	foreach my $daemon (sort {$a cmp $b} @{$conf->{sys}{daemons}{disable}})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disabling daemon: [$daemon]\n");
		
		my ($init3, $init5) = get_chkconfig_data($conf, $node, $password, $daemon);
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; init3: [$init3], init5: [$init5].\n");
		if (($init3 eq "0") && ($init5 eq "0"))
		{
			# Already enabled.
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], daemon: [$daemon], already disabled on boot.\n");
		}
		else
		{
			# Enable it.
			set_chkconfig($conf, $node, $password, $daemon, "off");
			my ($init3, $init5) = get_chkconfig_data($conf, $node, $password, $daemon);
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; init3: [$init3], init5: [$init5].\n");
			if (($init3 eq "0") && ($init5 eq "0"))
			{
				# Success
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], daemon: [$daemon], now disabled on boot.\n");
			}
			else
			{
				# failed. :(
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to disable daemon: [$daemon] on node: [$node]!\n");
				$return .= "failed to disable:$daemon,";
				$ok = 0;
			}
		}
		
		# Now check/stop the daemon if needed
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok].\n");
		if ($ok)
		{
			my ($state) = get_daemon_state($conf, $node, $password, $daemon);
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], daemon: [$daemon], state: [$state].\n");
			if ($state eq "0")
			{
				# Already stopped.
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], daemon: [$daemon] is already stopped.\n");
			}
			elsif ($state eq "0")
			{
				# Enable it.
				set_daemon_state($conf, $node, $password, $daemon, "stop");
				my ($state) = get_daemon_state($conf, $node, $password, $daemon);
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], daemon: [$daemon], state: [$state].\n");
				if ($state eq "0")
				{
					# Now running.
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], daemon: [$daemon] was stopped.\n");
				}
				elsif ($state eq "1")
				{
					# Failed to start
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to stop daemon: [$daemon] on node: [$node]!\n");
					$return .= "failed to stop:$daemon,";
				}
			}
		}
	}
	$return =~ s/,$//;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok], return: [$return]\n");
	return($ok, $return);
}

# This starts or stops a daemon on a node.
sub set_daemon_state
{
	my ($conf, $node, $password, $daemon, $state) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; set_daemon_state(); node: [$node], daemon: [$daemon] setting state: [$state]\n");
	
	my $rc         = "";
	my $shell_call = "/etc/init.d/$daemon $state; echo rc:\$?";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
		if ($line =~ /^rc:(\d+)/)
		{
			$rc = $1;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc]\n");
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc]\n");
	return($rc);
}

# This checks to see if a daemon is running or not.
sub get_daemon_state
{
	my ($conf, $node, $password, $daemon) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; get_daemon_state(); node: [$node], daemon: [$daemon]\n");
	
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
	
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], checking if daemon: [$daemon] is running\n");
	my $shell_call = "/etc/init.d/$daemon status; echo rc:\$?";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
		if ($line =~ /No such file or directory/i)
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; daemon not installed, pretending it is off.\n");
			$state = 0;
			last;
		}
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc] (stopped: [$stopped_rc], running: [$running_rc]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc], state: [$state]\n");
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; state: [$state]\n");
	return($state);
}

# This calls 'chkconfig' and enables or disables the daemon on boot.
sub set_chkconfig
{
	my ($conf, $node, $password, $daemon, $state) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; set_chkconfig(); node: [$node], daemon: [$daemon], state: [$state]\n");

	my $shell_call = "chkconfig $daemon $state";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
	}
	
	return(0);
}


# This calls 'chkconfig' and return '1' or '0' based on whether the daemon is
# set to run on boot or not
sub get_chkconfig_data
{
	my ($conf, $node, $password, $daemon) = @_;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; get_chkconfig_data(); node: [$node], daemon: [$daemon]\n");
	
	my $init3 = 255;
	my $init5 = 255;

	my $shell_call = "chkconfig --list $daemon";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
		if ($line =~ /^$daemon/)
		{
			$init3 = ($line =~ /3:(.*?)\s/)[0];
			$init5 = ($line =~ /5:(.*?)\s/)[0];
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; init3: [$init3], init5: [$init5]\n");
			$init3 = $init3 eq "off" ? 0 : 1;
			$init5 = $init5 eq "off" ? 0 : 1;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; init3: [$init3], init5: [$init5]\n");
		}
	}
	
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return; init3: [$init3], init5: [$init5]\n");
	return($init3, $init5);
}

# This configures clustered LVM on each node.
sub configure_clvmd
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_clvmd()\n");
	
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; generate_rc: [$generate_rc]\n");
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; lvm.conf:\n================\n$conf->{sys}{lvm_conf}\n================\n");
	
	# Now we'll write out the config.
	my $node1_rc = 255;
	my $node2_rc = 255;
	if (not $generate_rc)
	{
		($node1_rc) = write_lvm_conf_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
		($node2_rc) = write_lvm_conf_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_rc: [$node1_rc], node2_rc: [$node2_rc]\n");
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

# This reads in node 1's lvm.conf, makes sure it's configured for clvmd and
# stores in.
sub generate_lvm_conf
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; generate_lvm_conf()\n");
	
	# Read the /etc/lvm/lvm.conf file on both nodes and look for a custom
	# filter line. The rest of the config will be loaded into memory and,
	# if one node is found to have a custom filter, it will be used to on
	# the other node. If neither have a custom filter, then node 1's base
	# config will be modified and loaded on both nodes.
	my $return_code = 0;
	read_lvm_conf_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	read_lvm_conf_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	
	# Now decide what lvm.conf to use.
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Default filter:         [$conf->{sys}{lvm_filter}]\n");
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1: [$node1] filter: [$conf->{node}{$node1}{lvm_filter}]\n");
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node2: [$node2] filter: [$conf->{node}{$node2}{lvm_filter}]\n");
	if (($conf->{node}{$node1}{lvm_filter} ne $conf->{sys}{lvm_filter}) && ($conf->{node}{$node2}{lvm_filter} ne $conf->{sys}{lvm_filter}))
	{
		# Both are custom, do they match?
		if ($conf->{node}{$node1}{lvm_filter} eq $conf->{node}{$node2}{lvm_filter})
		{
			# We're good. We'll use node 1
			$conf->{sys}{lvm_conf} = $conf->{node}{$node1}{lvm_conf};
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Matching custom filters.\n");
		}
		else
		{
			# Both are custom and they don't match, time to bail out.
			$return_code = 1;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Different custom filters!\n");
		}
	}
	elsif ($conf->{node}{$node1}{lvm_filter} ne $conf->{sys}{lvm_filter})
	{
		$conf->{sys}{lvm_conf} = $conf->{node}{$node1}{lvm_conf};
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Custom filter; Using node 1's lvm.conf\n");
	}
	elsif ($conf->{node}{$node2}{lvm_filter} ne $conf->{sys}{lvm_filter})
	{
		$conf->{sys}{lvm_conf} = $conf->{node}{$node2}{lvm_conf};
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Custom filter; Using node 2's lvm.conf\n");
	}
	else
	{
		if (length($conf->{node}{$node1}{lvm_conf}) > 256)
		{
			# Node 1's copy seems sane, use it.
			$conf->{sys}{lvm_conf} = $conf->{node}{$node1}{lvm_conf};
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Stock filter; Using node 1's lvm.conf\n");
		}
		elsif (length($conf->{node}{$node1}{lvm_conf}) > 256)
		{
			# Node 2's copy seems sane, use it.
			$conf->{sys}{lvm_conf} = $conf->{node}{$node2}{lvm_conf};
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Stock filter; Using node 2's lvm.conf\n");
		}
		else
		{
			# Neither are sane?!
			$return_code = 2;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Neither of the read lvm.conf files appear to be sane!\n");
		}
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; size of lvm.conf to write is: [".length($conf->{sys}{lvm_conf})."]\n");
	
	# Return codes:
	# 0 = OK
	# 1 = Both nodes have different and custom filter lines.
	# 2 = Read failed.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code]\n");
	return($return_code);
}

# This (re)writes the lvm.conf file on a node.
sub write_lvm_conf_on_node
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; write_lvm_conf_on_node(); node: [$node]\n");
	
	my $rc = 0;
	my $shell_call =  "cat > $conf->{path}{nodes}{lvm_conf} << EOF\n";
	   $shell_call .= "$conf->{sys}{lvm_conf}\n";
	   $shell_call .= "EOF";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n");
	}
	
	return($rc);
}

# This reads in the actual lvm.conf from the node, updating the config in the
# process, storing a version suitable for clustered LVM.
sub read_lvm_conf_on_node
{
	my ($conf, $node, $password) = @_;
	
	# Read it in
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	"if [ -e '$conf->{path}{nodes}{lvm_conf}' ]
					then
						cat $conf->{path}{nodes}{lvm_conf}
					else
						echo \"not found\"
					fi",
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	
	# I need to read this in two passes. The first pass looks for an
	# existing 'filter = []' rule and, if found, uses it.
	$conf->{node}{$node}{lvm_filter} = $conf->{sys}{lvm_filter};
	foreach my $line (@{$return})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> return line: [$line]\n");
		#$line =~ s/^\s+//;
		#$line =~ s/\s+$//;
		if (($line =~ /^filter = \[.*\]/) || ($line =~ /^\s+filter = \[.*\]/))
		{
			$conf->{node}{$node}{lvm_filter} = $line;
			$conf->{node}{$node}{lvm_filter} =~ s/^\s+//;
			$conf->{node}{$node}{lvm_filter} =~ s/\s+$//;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Custom filter found: [$conf->{node}{$node}{lvm_filter}]\n");
		}
	}
	
	### TODO: Make this smart enough to *NOT* change the lvm.conf file
	###       unless something actually needs to be changed and, if so, use
	###       sed to maintain the file's comments.
	# There is no default filter entry, but it is referenced as comments
	# many times. So we'll inject it when we see the first comment and then
	# skip any 
	my $filter_injected = 0;
	$conf->{node}{$node}{lvm_conf} =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n\n";
	$conf->{node}{$node}{lvm_conf} .= "# Sorry for the lack of comments... Ran into a buffer issue with Net::SSH2 that\n";
	$conf->{node}{$node}{lvm_conf} .= "# I wasn't able to fix in time. Fixing it is on the TODO though, and patches\n";
	$conf->{node}{$node}{lvm_conf} .= "# are welcomed. :)\n\n";
	foreach my $line (@{$return})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> line: [$line]\n");
		last if $line =~ /not found/;
		
		# Any line that starts with a '#' is passed on as-is.
		if ((not $filter_injected) && ($line =~ /filter = \[/))
		{
			#$conf->{node}{$node}{lvm_conf} .= "$line\n";
			$conf->{node}{$node}{lvm_conf} .= "    $conf->{node}{$node}{lvm_filter}\n";
			$filter_injected               =  1;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Filter injected: [$conf->{node}{$node}{lvm_filter}]\n");
			next;
		}
		elsif (($line =~ /^filter = \[/) || ($line =~ /^\s+filter = \[/))
		{
			# Skip existing filter entries
		}
		# Test skip comments
		elsif ((not $line) || (($line =~ /^#/) || ($line =~ /^\s+#/)) || ($line =~ /^\s+$/))
		{
			### TODO: Fix Net::SSH2 so that we can write out larger
			###       files.
			# Skip comments
			next;
		}
		# Alter the locking type:
		if (($line =~ /^locking_type = /) || ($line =~ /^\s+locking_type = /))
		{
			$line =~ s/locking_type = .*/locking_type = 3/;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Locking type set to 3: [$line]\n");
		}
		# Alter the fall-back locking
		if (($line =~ /^fallback_to_local_locking = /) || ($line =~ /^\s+fallback_to_local_locking = /))
		{
			$line =~ s/fallback_to_local_locking = .*/fallback_to_local_locking = 0/;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Fallback to local locking set to 0: [$line]\n");
		}
		# And record.
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << line: [$line]\n");
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; do_node_reboot(); node: [$node], password: [$password], new_bcn_ip: [$new_bcn_ip]\n");
	
	my $return_code = 255;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node}::reboot_needed: [$conf->{node}{$node}{reboot_needed}]\n");
	if (not $conf->{node}{$node}{reboot_needed})
	{
		$return_code = 1;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node] reboot NOT needed.\n");
	}
	elsif ($conf->{node}{$node}{in_cluster})
	{
		# Reboot needed, but the user has to do it.
		$return_code = 5;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node] reboot MUST be performed manually!\n");
	}
	else
	{
		# Reboot... Close the SSH FH as well.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node] reboot needed.\n");
		my $shell_call = "reboot";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
		my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	22,
			user		=>	"root",
			password	=>	$password,
			ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
			'close'		=>	1,
			shell_call	=>	$shell_call,
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
		foreach my $line (@{$return})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
		}
		
		# We need to give the system time to shut down.
		my $has_shutdown = 0;
		my $timeout      = time + 120;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; time: [".time."], timeout: [$timeout]\n");
		while (not $has_shutdown)
		{
			if (not ping_ip($conf, $node))
			{
				$has_shutdown = 1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; has_shutdown: [$has_shutdown]\n");
			}
			if (time > $timeout)
			{
				$return_code = 4;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code]\n");
				last;
			}
			sleep 1;
		}
		
		# Now loop for $conf->{sys}{reboot_timeout} seconds waiting to
		# see if the node recovers.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; has_shutdown: [$has_shutdown]\n");
		if ($has_shutdown)
		{
			my $give_up_time = time + $conf->{sys}{reboot_timeout};
			my $wait         = 1;
			my $rc           = 255;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> time: [".time."], give_up_time: [$give_up_time]\n");
			while ($wait)
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << time: [".time."], give_up_time: [$give_up_time], will wait: [".($give_up_time - time)."] more second(s).\n");
				if (time > $give_up_time)
				{
					last;
				}
				($rc) = connect_to_node($conf, $new_bcn_ip, $password);
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; new_bcn_ip: [$new_bcn_ip], rc: [$rc]\n");
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
						# Copy the hash reference to
						# the new IP.
						$conf->{node}{$new_bcn_ip} = $conf->{node}{$node};
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; copying hash from: [$node] to: [$new_bcn_ip]\n");
					}
				}
				sleep 1;
			}
			
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc]\n");
			if ($rc == 0)
			{
				# Success!
				$return_code = 0;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Node rebooted, rescanning storage.\n");
				
				# Rescan it's (new) partition data.
				my ($node_disk) = get_partition_data($conf, $new_bcn_ip, $password);
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$new_bcn_ip], disk: [$node_disk]\n");
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code]\n");
	return($return_code);
}

# This pings the target and returns 1 if reached, 0 if not.
sub ping_ip
{
	my ($conf, $ip) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ping_ip(); ip: [$ip]\n");
	
	my $success    = 0;
	my $ping_rc    = 255;
	my $shell_call = "$conf->{path}{ping} -n $ip -c 1; echo ping:\$?";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sc: [$shell_call]\n");
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /(\d+) packets transmitted, (\d+) received/)
		{
			# This isn't really needed, but might help folks
			# watching the logs.
			my $pings_sent     = $1;
			my $pings_received = $2;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ip: [$ip], pings_sent: [$pings_sent], pings_received: [$pings_received]\n");
		}
		if ($line =~ /ping:(\d+)/)
		{
			$ping_rc = $1;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ping_rc: [$ping_rc] (0 == pingable)\n");
			$success = 1 if not $ping_rc;
		}
	}
	close $file_handle;
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; success: [$success] (1 == pingable)\n");
	return($success);
}

# This function first tries to ping a node. If the ping is successful, it will
# try to log into the node.
sub connect_to_node
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; connect_to_node(); node: [$node]\n");
	
	# 0 = Successfully logged in
	# 1 = Could ping, but couldn't log in
	# 2 = Couldn't ping.
	
	my $rc = 2;
	if (ping_ip($conf, $node))
	{
		# Pingable! Can we log in?
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node] pingable\n");
		$rc = 1;
		if (check_node_access($conf, $node, $password))
		{
			# We're in!
			$rc = 0;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The node: [$node] is accessible!\n");
		}
		else
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; I can ping: [$node], but I can not log into the node yet.\n");
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc]\n");
	return($rc);
}

# This does the work of adding a specific repo to a node.
sub add_repo_to_node
{
	my ($conf, $node, $password, $url) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; add_repo_to_node(); node: [$node], url: [$url]\n");
	
	my $rc = 0;
	my $repo_file = ($url =~ /^.*\/(.*?)$/)[0];
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; repo_file: [$repo_file]\n");
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
	local_file=\$(grep gpgkey /etc/yum.repos.d/an-el6.repo | sed 's/gpgkey=file:\\/\\/\\(.*\\)/\\1/');
	file=\$(grep gpgkey /etc/yum.repos.d/an-el6.repo | sed 's/gpgkey=file:\\/\\/\\/etc\\/pki\\/rpm-gpg\\/\\(.*\\)/\\1/')
	url=\$(grep baseurl /etc/yum.repos.d/an-el6.repo | sed 's/baseurl=//');
	echo 'Downloading the GPG key: [curl \$url/\$file > \$local_file]'
	curl \$url/\$file > \$local_file
fi";
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
		my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	22,
			user		=>	"root",
			password	=>	$password,
			ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
		foreach my $line (@{$return})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
			$rc = $line;
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc], repo_file: [$repo_file]\n");
	return ($rc, $repo_file);
}

# This downloads user-specified repositories to the nodes
sub add_user_repositories
{
	my ($conf) = @_;
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; anvil_repositories: [$conf->{cgi}{anvil_repositories}]\n");
	if ($conf->{cgi}{anvil_repositories})
	{
		# Add repos to nodes
		foreach my $url (split/,/, $conf->{cgi}{anvil_repositories})
		{
			my ($node1_rc, $repo_file) = add_repo_to_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $url);
			my ($node2_rc)             = add_repo_to_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $url);
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_rc: [$node1_rc], node2_rc: [$node2_rc], repo_file: [$repo_file]\n");
			
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

# This partitions the drive.
sub create_partitions_on_node
{
	my ($conf, $node, $password, $disk, $pool1_size, $pool2_size) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; create_partitions_on_node(); node: [$node], password: [$password], disk: [$disk], pool1_size: [$pool1_size], pool2_size: [$pool2_size]\n");
	
	# If the disk to use is 'Xda', skip the first three partitions
	# as they will be for the OS.
	my $ok                        = 1;
	my $partition_created         = 0;
	my $create_extended_partition = 0;
	my $pool1_partition           = 4;
	my $pool2_partition           = 5;
	if ($disk =~ /da$/)
	{
		# I need to know the label type to determine the partition numbers to
		# use:
		# * If it's 'msdos', I need an extended partition and then two logical
		#   partitions. (4, 5 and 6)
		# * If it's 'gpt', I just use two logical partition. (4 and 5).
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node}::disk::${disk}::label: [$conf->{node}{$node}{disk}{$disk}{label}]\n");
		if ($conf->{node}{$node}{disk}{$disk}{label} eq "msdos")
		{
			$create_extended_partition = 1;
			$pool1_partition   = 5;
			$pool2_partition   = 6;
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; create_extended_partition: [$create_extended_partition], pool1_partition: [$pool1_partition], pool2_partition: [$pool2_partition]\n");
	}
	else
	{
		$create_extended_partition = 0;
		$pool1_partition   = 1;
		$pool2_partition   = 2;
	}
	$conf->{node}{$node}{pool1}{device} = "/dev/${disk}${pool1_partition}";
	$conf->{node}{$node}{pool2}{device} = "/dev/${disk}${pool2_partition}";
	
	# If there is no disk label on the disk at all, we'll need to
	# start with 'mklabel' and we'll know for sure we need to
	# create the partitions.
	my $label_disk   = 0;
	my $create_pool1 = 1;
	my $create_pool2 = 1;
	if (not $conf->{node}{$node}{disk}{$disk}{label})
	{
		$label_disk   = 1;
		$create_pool1 = 1;
		$create_pool2 = 1;
	}
	else
	{
		# Check to see if the partitions I want to use already
		# exist. If they don't, create them. If they do, look
		# for a DRBD signature.
		if (exists $conf->{node}{$node}{disk}{$disk}{partition}{$pool1_partition}{start})
		{
			# Pool 1 exists, check for a signature.
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; On node: [$node], the disk: [$disk] already has partition number: [$pool1_partition] which I want to use for pool 1.\n");
			$create_pool1    = 0;
		}
		if (exists $conf->{node}{$node}{disk}{$disk}{partition}{$pool2_partition}{start})
		{
			# Pool 2 exists, check for a signature.
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; On node: [$node], the disk: [$disk] already has partition number: [$pool2_partition] which I want to use for pool 2.\n");
			$create_pool2    = 0;
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; create_pool1: [$create_pool1], create_pool2: [$create_pool2]\n");
	}
	
	# If I need to make an extended partition, do so now unless it already
	# exists.
	if ($create_extended_partition)
	{
		if (($conf->{node}{$node}{disk}{$disk}{partition}{4}{type}) && ($conf->{node}{$node}{disk}{$disk}{partition}{4}{type} eq "extended"))
		{
			# Already exists.
			$conf->{node}{$node}{pool1}{create_extended} = 0;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], extended partition already exists.\n");
		}
		else
		{
			# Create it.
			my ($rc) = create_partition_on_node($conf, $node, $password, $disk, "extended", "all");
			$partition_created = 1 if $rc == 2;
		}
	}
	
	# Create the pools, if needed.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], create_pool1: [$create_pool1], create_pool2: [$create_pool2].\n");
	if (($create_pool1) && ($create_pool2))
	{
		# Create both partitions
		my $free_space_needed    = $pool1_size + $pool2_size;
		my $free_space_available = $conf->{node}{$node}{disk}{$disk}{free_space}{size};
		
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], free_space_needed: [$free_space_needed], free_space_available: [$free_space_available].\n");
		if ($free_space_needed > $free_space_available)
		{
			# Why wasn't this caught earlier? Oh well, we'll shrink
			# the last partition.
			print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
				message	=>	AN::Common::get_string($conf, {key => "message_0392", variables => { 
					node		=>	$node, 
					disk		=>	$disk,
					free_space	=>	AN::Cluster::bytes_to_hr($conf, $free_space_available)." ($free_space_available #!string!suffix_0009!#)",
					space_needed	=>	AN::Cluster::bytes_to_hr($conf, $free_space_needed)." ($free_space_needed #!string!suffix_0009!#)",
				}}),
				row	=>	"#!string!state_0042!#",
			});
		}
		
		# Proceed!
		my $type = "primary";
		if ($create_extended_partition)
		{
			$type = "logical";
		}
		my ($rc) = create_partition_on_node($conf, $node, $password, $disk, $type, $pool1_size);
		   $partition_created = 1 if $rc == 2;
		   ($rc) = create_partition_on_node($conf, $node, $password, $disk, $type, $pool2_size);
		   $partition_created = 1 if $rc == 2;
	}
	elsif ($create_pool1)
	{
		# What? How could partition 2 exist but not 1?
		$ok = 0;
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
			message	=>	AN::Common::get_string($conf, {key => "message_0393", variables => { 
				node		=>	$node, 
				disk		=>	$disk,
			}}),
			row	=>	"#!string!state_0042!#",
		});
	}
	elsif ($create_pool2)
	{
		my $free_space_available = $conf->{node}{$node}{disk}{$disk}{free_space}{size};
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], free_space_available: [$free_space_available], pool2_size: [$pool2_size].\n");
		if ($pool2_size > $free_space_available)
		{
			# Why wasn't this caught earlier? Oh well, we'll shrink
			# the last partition.
			print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
				message	=>	AN::Common::get_string($conf, {key => "message_0392", variables => { 
					node		=>	$node, 
					disk		=>	$disk,
					free_space	=>	AN::Cluster::bytes_to_hr($conf, $free_space_available)." ($free_space_available #!string!suffix_0009!#)",
					space_needed	=>	AN::Cluster::bytes_to_hr($conf, $pool2_size)." ($pool2_size #!string!suffix_0009!#)",
				}}),
				row	=>	"#!string!state_0042!#",
			});
		}
		
		my $type = "primary";
		if ($create_extended_partition)
		{
			$type = "logical";
		}
		my ($rc) = create_partition_on_node($conf, $node, $password, $disk, $type, $pool2_size);
		$partition_created = 1 if $rc == 2;
	}
	else
	{
		# Partitions already exist, nothing to do.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Node: [$node], disk: [$disk], both pools \n");
	}
	
	if (($ok) && ($partition_created))
	{
		$ok = 2;
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This performs an actual partition creation
sub create_partition_on_node
{
	my ($conf, $node, $password, $disk, $type, $partition_size) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; create_partition_on_node(); node: [$node], disk: [$disk], type: [$type], partition_size: [$partition_size]\n");
	
	my $created = 0;
	my $ok      = 1;
	my $start   = 0;
	my $end     = 0;
	my $size    = 0;
	### NOTE: Parted, in it's infinite wisdom, doesn't show the partition
	###       type when called with --machine
	#my $shell_call = "parted --machine /dev/$disk unit GiB print free";
	my $shell_call = "parted /dev/$disk unit GiB print free";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
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
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> node: [$node], disk: [$disk], return: [$line]\n");
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << return: [$line]\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], return: [$line]\n");
		if ($line =~ /([\d\.]+)GiB ([\d\.]+)GiB ([\d\.]+)GiB Free/i)
		{
			$start = $1;
			$end   = $2;
			$size  = $3;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; start: [$start], end: [$end], size: [$size]\n");
		}
	}
	
	# Hard to proceed if I don't have the start and end sizes.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], start: [$start], end: [$end].\n");
	if ((not $start) || (not $end))
	{
		# :(
		$ok = 0;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], type: [$type], partition_size: [$partition_size].\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], type: [$type], partition_size: [$partition_size]\n");
		if ($partition_size eq "all")
		{
			$use_end = "100%";
		}
		else
		{
			my $gib_size = sprintf("%.0f", ($partition_size /= (2 ** 30)));
			   $use_end  = $start + $gib_size;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], use_end: [$use_end], end: [$end].\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; snode: [$node], disk: [$disk], type: [$type], start: [$start GiB], end: [$end GiB]\n");
		
		my $shell_call = "parted -a opt /dev/$disk mkpart $type ${start}GiB ${use_end}GiB";
		if ($use_end eq "100%")
		{
			$shell_call = "parted -a opt /dev/$disk mkpart $type ${start}GiB 100%";
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n");
			if ($line =~ /Error/i)
			{
				$ok = 0;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], start: [$start], end: [$end].\n");
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
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], start: [$start], end: [$end].\n");
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
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], reboot needed.\n");
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This looks on a given device for DRBD metadata
sub check_device_for_drbd_metadata
{
	my ($conf, $node, $password, $device) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; check_device_for_drbd_metadata(); node: [$node], device: [$device].\n");
	
	my $is_drbd    = 0;
	my $shell_call = "drbdmeta --force 0 v08 $device internal dump-md; echo rc:\$?";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n");
		if ($line =~ /^rc:(\d+)/)
		{
			my $rc = $1;
			# 0   == drbd md found
			# 10  == too small for DRBD
			# 20  == device not found
			# 255 == device exists but has no metadata
			if ($rc eq "0")
			{
				$is_drbd = 1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], device: [$device] has DRBD metadata.\n");
			}
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; is_drbd: [$is_drbd].\n");
	return($is_drbd);
}

# This calls 'blkid' and parses the output for the given device, if returned.
sub check_blkid_partition
{
	my ($conf, $node, $password, $device) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; check_blkid_partition(); node: [$node], device: [$device].\n");
	
	my $uuid       = "";
	my $type       = "";
	my $shell_call = "blkid -c /dev/null $device";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n");
		if ($line =~ /^$device: /)
		{
			$uuid  = ($line =~ /UUID="(.*?)"/)[0];
			$type  = ($line =~ /TYPE="(.*?)"/)[0];
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; uuid: [$uuid], type: [$type].\n");
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; type: [$type].\n");
	return($type);
}

# This checks the disk for DRBD metadata
sub check_for_drbd_metadata
{
	my ($conf, $node, $password, $device) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; check_for_drbd_metadata(); node: [$node], device: [$device].\n");
	
	return(3) if not $device;
	
	# I do both checks because blkid tells me what's on the partition, but
	# if there is something on top of DRBD, it will report that instead, so
	# it can't be entirely trusted. If the 'blkid' returns type
	# 'LVM2_member' but it is also 'is_drbd', then it is already setup.
	my ($type)    = check_blkid_partition($conf, $node, $password, $device);
	my ($is_drbd) = check_device_for_drbd_metadata($conf, $node, $password, $device);
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; type: [$type], is_drbd: [$is_drbd].\n");
	my $return_code = 255;
	if (($type eq "drbd") || (($type eq "LVM2_member") && ($is_drbd)))
	{
		# Already has meta-data, nothing else to do.
		$return_code = 1;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; DRBD meta-data already found on node: [$node], device: [$device].\n");
	}
	elsif ($type)
	{
		# WHAT?
		$return_code = 4;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; A non-DRBD signature was found on node: [$node], device: [$device] or type: [$type]. Aborting!\n");
	}
	else
	{
		# Make sure there is a device at all
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Checking to ensure that node: [$node]'s device: [$device] exists.\n");
		my ($disk, $partition) = ($device =~ /\/dev\/(\D+)(\d)/);
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; disk: [$disk], partition: [$partition], node::${node}::disk::${disk}::partition::${partition}::size: [$conf->{node}{$node}{disk}{$disk}{partition}{$partition}{size}]\n");
		if ($conf->{node}{$node}{disk}{$disk}{partition}{$partition}{size})
		{
			# It exists, so we can assume it has no DRBD metadata or
			# anything else.
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; it exists, safe to create meta-data.\n");
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
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node]'s device: [$device] belongs to DRBD resource: [$resource].\n");
				my $rc         = 255;
				my $shell_call = "drbdadm -- --force create-md $resource; echo rc:\$?";
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n");
					if ($line =~ /^rc:(\d+)/)
					{
						# 0 == Success
						# 3 == Configuration not found.
						$rc = $1;
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; DRBD meta-data creation return code: [$rc]\n");
						if (not $rc)
						{
							$return_code = 0;
						}
						elsif ($rc eq "3")
						{
							AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The requested DRBD resource: [$resource] on node: [$node] isn't configured! Creation of meta-data failed.\n");
							$return_code = 6;
						}
					}
					if ($line =~ /drbd meta data block successfully created/)
					{
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; DRBD meta-data created successfully!\n");
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code]\n");
	return($return_code);
}

# This does the first stage of the storage configuration. Specifically, it 
# partitions the drives. Systems using one disk will need to reboot after this.
sub configure_storage_stage1
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_storage_stage1()\n");
	
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_pool1_disk: [$node1_pool1_disk], node1_pool1_partition: [$node1_pool1_partition], node1_pool2_disk: [$node1_pool2_disk], node1_pool2_partition: [$node1_pool2_partition], node2_pool1_disk: [$node2_pool1_disk], node2_pool1_partition: [$node2_pool1_partition], node2_pool2_disk: [$node2_pool2_disk], node2_pool2_partition: [$node2_pool2_partition]\n");

	# If an extended partition is needed on either node, create it/them
	# now.
	my $node1_partition_type = "primary";
	my $node2_partition_type = "primary";
	# Node 1 extended.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node1}::pool1::create_extended: [$conf->{node}{$node1}{pool1}{create_extended}]\n");
	if ($conf->{node}{$node1}{pool1}{create_extended})
	{
		$node1_partition_type = "logical";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node1}::disk::${node1_pool1_disk}::partition::4::type: [$conf->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{4}{type}]\n");
		if (($conf->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{4}{type}) && ($conf->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{4}{type} eq "extended"))
		{
			# Already exists.
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node1], disk: [$node1_pool1_disk], extended partition already exists.\n");
		}
		else
		{
			my ($rc) = create_partition_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $node1_pool1_disk, "extended", "all");
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc].\n");
			if ($rc eq "0")
			{
				$ok = 0;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to an extended partition on node: [$node1], disk: [$node1_pool1_disk].\n");
			}
			elsif ($rc eq "2")
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Created an extended partition on node: [$node1], disk: [$node1_pool1_disk].\n");
			}
		}
	}
	# Node 2 extended.
	if ($conf->{node}{$node2}{pool1}{create_extended})
	{
		$node2_partition_type = "logical";
		if (($conf->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{4}{type}) && ($conf->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{4}{type} eq "extended"))
		{
			# Already exists.
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node2], disk: [$node2_pool1_disk], extended partition already exists.\n");
		}
		else
		{
			my ($rc) = create_partition_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $node2_pool1_disk, "extended", "all");
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc].\n");
			if ($rc eq "0")
			{
				$ok = 0;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to create an extended partition on node: [$node2], disk: [$node2_pool1_disk].\n");
			}
			elsif ($rc eq "2")
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Created an extended partition on node: [$node2], disk: [$node2_pool1_disk].\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc].\n");
		if ($rc eq "0")
		{
			$ok = 0;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to a: [$node1_partition_type] partition for pool 1on node: [$node2], disk: [$node2_pool1_disk], size: [$conf->{cgi}{anvil_storage_pool1_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}).")].\n");
		}
		elsif ($rc eq "2")
		{
			$node1_pool1_created = 1;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Successfully created a: [$node1_partition_type] partition for pool 1 on node: [$node2], disk: [$node2_pool1_disk], size: [$conf->{cgi}{anvil_storage_pool1_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}).")].\n");
		}
	}
	# Node 1, Pool 2.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_storage_pool2_byte_size: [$conf->{cgi}{anvil_storage_pool2_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}).")].\n");
	if ($conf->{cgi}{anvil_storage_pool2_byte_size})
	{
		if ($conf->{node}{$node1}{disk}{$node1_pool2_disk}{partition}{$node1_pool2_partition}{size})
		{
			# Already exists
			$node1_pool2_created = 2;
		}
		else
		{
			### TODO: Determine if it's better to always make the size of
			###       pool 2 "all".
			# Create node 1, pool 1.
			my ($rc) = create_partition_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $node1_pool2_disk, $node1_partition_type, $conf->{cgi}{anvil_storage_pool2_byte_size});
			#my ($rc) = create_partition_on_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $node1_pool2_disk, $node1_partition_type, "all");
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc].\n");
			if ($rc eq "0")
			{
				$ok = 0;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to a: [$node1_partition_type] partition for pool 2 on node: [$node2], disk: [$node2_pool1_disk], size: [$conf->{cgi}{anvil_storage_pool1_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}).")].\n");
			}
			elsif ($rc eq "2")
			{
				$node1_pool2_created = 1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Successfully created a: [$node1_partition_type] partition for pool 2 on node: [$node2], disk: [$node2_pool2_disk], size: [$conf->{cgi}{anvil_storage_pool2_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}).")].\n");
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
		# Create node 1, pool 1.
		my ($rc) = create_partition_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $node2_pool1_disk, $node2_partition_type, $conf->{cgi}{anvil_storage_pool1_byte_size});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc].\n");
		if ($rc eq "0")
		{
			$ok = 0;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to a: [$node2_partition_type] partition for pool 1on node: [$node2], disk: [$node2_pool1_disk], size: [$conf->{cgi}{anvil_storage_pool1_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}).")].\n");
		}
		elsif ($rc eq "2")
		{
			$node2_pool1_created = 1;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Successfully created a: [$node2_partition_type] partition for pool 1 on node: [$node2], disk: [$node2_pool1_disk], size: [$conf->{cgi}{anvil_storage_pool1_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}).")].\n");
		}
	}
	# Node 2, Pool 2.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_storage_pool2_byte_size: [$conf->{cgi}{anvil_storage_pool2_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}).")].\n");
	if ($conf->{cgi}{anvil_storage_pool2_byte_size})
	{
		if ($conf->{node}{$node2}{disk}{$node2_pool2_disk}{partition}{$node2_pool2_partition}{size})
		{
			# Already exists
			$node2_pool2_created = 2;
		}
		else
		{
			### TODO: Determine if it's better to always make the size of
			###       pool 2 "all".
			# Create node 1, pool 1.
			my ($rc) = create_partition_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $node2_pool2_disk, $node2_partition_type, $conf->{cgi}{anvil_storage_pool2_byte_size});
			#my ($rc) = create_partition_on_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $node2_pool2_disk, $node2_partition_type, "all");
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; rc: [$rc].\n");
			if ($rc eq "0")
			{
				$ok = 0;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to a: [$node2_partition_type] partition for pool 2 on node: [$node2], disk: [$node2_pool1_disk], size: [$conf->{cgi}{anvil_storage_pool1_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}).")].\n");
			}
			elsif ($rc eq "2")
			{
				$node2_pool2_created = 1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Successfully created a: [$node2_partition_type] partition for pool 2 on node: [$node2], disk: [$node2_pool2_disk], size: [$conf->{cgi}{anvil_storage_pool2_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}).")].\n");
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
	
	# Pool 2 message
	# Default to 'created'.
	my $node1_pool2_class   = "highlight_good_bold";
	my $node1_pool2_message = "#!string!state_0045!#";
	my $node2_pool2_class   = "highlight_good_bold";
	my $node2_pool2_message = "#!string!state_0045!#";
	if ($node1_pool2_created eq "0")
	{
		# Failed
		$node1_pool2_class   = "highlight_warning_bold";
		$node1_pool2_message = "#!string!state_0018!#",
		$ok                  = 0;
	}
	elsif ($node1_pool2_created eq "2")
	{
		# Already existed.
		$node1_pool2_message = "#!string!state_0020!#",
	}
	elsif ($node1_pool2_created eq "3")
	{
		# Not needed..
		$node1_pool2_message = "#!string!state_0047!#",
	}
	if ($node2_pool2_created eq "0")
	{
		# Failed
		$node2_pool2_class   = "highlight_warning_bold";
		$node2_pool2_message = "#!string!state_0018!#",
		$ok                  = 0;
	}
	elsif ($node2_pool2_created eq "2")
	{
		# Already existed.
		$node2_pool2_message = "#!string!state_0020!#",
	}
	elsif ($node2_pool2_created eq "3")
	{
		# Not needed..
		$node2_pool2_message = "#!string!state_0047!#",
	}
	# Pool 1 message
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0248!#",
		node1_class	=>	$node1_pool2_class,
		node1_message	=>	$node1_pool2_message,
		node2_class	=>	$node2_pool2_class,
		node2_message	=>	$node2_pool2_message,
	});
	
	return($ok);
}

sub configure_storage_stage2
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_storage_stage2()\n");
	
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_pool1_rc: [$node1_pool1_rc], node1_pool2_rc: [$node1_pool2_rc], node2_pool1_rc: [$node2_pool1_rc], node2_pool2_rc: [$node2_pool2_rc]\n");
	
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
	
	## Now Pool 2
	$node1_class   = "highlight_good_bold";
	$node1_message = "#!string!state_0045!#";
	$node2_class   = "highlight_good_bold";
	$node2_message = "#!string!state_0045!#";
	$message       = "";
	# Node 1, Pool 1
	if ($node1_pool2_rc eq "1")
	{
		# Already existed
		$node1_message = "#!string!state_0020!#";
	}
	elsif ($node1_pool2_rc eq "2")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = AN::Common::get_string($conf, {key => "state_0055", variables => { device => $conf->{node}{$node1}{pool2}{device} }});
		$ok            = 0;
	}
	elsif ($node1_pool2_rc eq "3")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0056!#";
		$ok            = 0;
	}
	elsif ($node1_pool2_rc eq "4")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = AN::Common::get_string($conf, {key => "state_0057", variables => { device => $conf->{node}{$node1}{pool2}{device} }});
		$show_lvm_note = 1;
		$ok            = 0;
	}
	elsif ($node1_pool2_rc eq "5")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = AN::Common::get_string($conf, {key => "state_0058", variables => { device => $conf->{node}{$node1}{pool2}{device} }});
		$ok            = 0;
	}
	elsif ($node1_pool2_rc eq "6")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0059!#";
		$ok            = 0;
	}
	elsif ($node1_pool2_rc eq "7")
	{
		$node1_class   = "highlight_good_bold";
		$node1_message = "#!string!state_0047!#";
	}
	# Node 2, Pool 1
	if ($node2_pool2_rc eq "1")
	{
		# Already existed
		$node2_message = "#!string!state_0020!#";
	}
	elsif ($node2_pool2_rc eq "2")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = AN::Common::get_string($conf, {key => "state_0055", variables => { device => $conf->{node}{$node2}{pool2}{device} }});
		$ok            = 0;
	}
	elsif ($node2_pool2_rc eq "3")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0056!#";
		$ok            = 0;
	}
	elsif ($node2_pool2_rc eq "4")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = AN::Common::get_string($conf, {key => "state_0057", variables => { device => $conf->{node}{$node2}{pool2}{device} }});
		$show_lvm_note = 1;
		$ok            = 0;
	}
	elsif ($node2_pool2_rc eq "5")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = AN::Common::get_string($conf, {key => "state_0058", variables => { device => $conf->{node}{$node2}{pool2}{device} }});
		$ok            = 0;
	}
	elsif ($node2_pool2_rc eq "6")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0059!#";
		$ok            = 0;
	}
	elsif ($node2_pool2_rc eq "7")
	{
		$node2_class   = "highlight_good_bold";
		$node2_message = "#!string!state_0047!#";
	}
	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0250!#",
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This generates the DRBD config files to later be written on the nodes.
sub generate_drbd_config_files
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; generate_drbd_config_files()\n");
	
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	
	if ($conf->{sys}{use_drbd} eq "8.3")
	{
		### TODO: Detect if the SN is on a 10 Gbps network and, if so, bump up
		###       the resync rate to 300M;
		# Generate the config files we'll use if we don't find existing configs
		# on one of the servers.
		$conf->{drbd}{global_common} = "
global {
	usage-count no;
	# minor-count dialog-refresh disable-ip-verification
}

common {
	protocol C;

	handlers {
		pri-on-incon-degr \"/usr/lib/drbd/notify-pri-on-incon-degr.sh; /usr/lib/drbd/notify-emergency-reboot.sh; echo b > /proc/sysrq-trigger ; reboot -f\";
		pri-lost-after-sb \"/usr/lib/drbd/notify-pri-lost-after-sb.sh; /usr/lib/drbd/notify-emergency-reboot.sh; echo b > /proc/sysrq-trigger ; reboot -f\";
		local-io-error \"/usr/lib/drbd/notify-io-error.sh; /usr/lib/drbd/notify-emergency-shutdown.sh; echo o > /proc/sysrq-trigger ; halt -f\";
		# fence-peer \"/usr/lib/drbd/crm-fence-peer.sh\";
		# split-brain \"/usr/lib/drbd/notify-split-brain.sh root\";
		# out-of-sync \"/usr/lib/drbd/notify-out-of-sync.sh root\";
		# before-resync-target \"/usr/lib/drbd/snapshot-resync-target-lvm.sh -p 15 -- -c 16k\";
		# after-resync-target /usr/lib/drbd/unsnapshot-resync-target-lvm.sh;
		#fence-peer		\"/sbin/obliterate-peer.sh\";
		fence-peer		\"/usr/lib/drbd/rhcs_fence\";
	}

	startup {
		# wfc-timeout degr-wfc-timeout outdated-wfc-timeout wait-after-sb
		become-primary-on	both;
		wfc-timeout		300;
		degr-wfc-timeout	120;
		outdated-wfc-timeout    120;
	}

	disk {
		# on-io-error fencing use-bmbv no-disk-barrier no-disk-flushes
		# no-disk-drain no-md-flushes max-bio-bvecs
		fencing			resource-and-stonith;
	}

	net {
		# sndbuf-size rcvbuf-size timeout connect-int ping-int ping-timeout max-buffers
		# max-epoch-size ko-count allow-two-primaries cram-hmac-alg shared-secret
		# after-sb-0pri after-sb-1pri after-sb-2pri data-integrity-alg no-tcp-cork
		allow-two-primaries;
		after-sb-0pri		discard-zero-changes;
		after-sb-1pri		discard-secondary;
		after-sb-2pri		disconnect;
	}

	syncer {
		# rate after al-extents use-rle cpu-mask verify-alg csums-alg
		rate			30M;
	}
}
";
	}
	elsif ($conf->{sys}{use_drbd} eq "8.4")
	{
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
		fence-peer \"/sbin/rhcs_fence\";
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
		# cpu-mask on-no-data-accessible
	}
 
	disk {
		# size max-bio-bvecs on-io-error fencing disk-barrier disk-flushes
		# disk-drain md-flushes resync-rate resync-after al-extents
		# c-plan-ahead c-delay-target c-fill-target c-max-rate
		# c-min-rate disk-timeout
		fencing resource-and-stonith;
	}
 
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
	}
}
";
	}
	
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to determine DRBD resource backing devices!; node1_pool1_partition: [$node1_pool1_partition], node1_pool2_partition: [$node1_pool2_partition], node2_pool1_partition: [$node2_pool1_partition], node2_pool2_partition: [$node2_pool2_partition]\n");
		return(1);
	}
	
	my $node1_sn_ip_key = "anvil_node1_sn_ip";
	my $node2_sn_ip_key = "anvil_node2_sn_ip";
	my $node1_sn_ip     = $conf->{cgi}{$node1_sn_ip_key};
	my $node2_sn_ip     = $conf->{cgi}{$node2_sn_ip_key};
	if ((not $node1_sn_ip) || (not $node2_sn_ip))
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to determine Storage Network IPs!; node1_sn_ip: [$node1_sn_ip], node2_sn_ip: [$node2_sn_ip]\n");
		return(2);
	}
	
	# Still alive? Yay us!
	if ($conf->{sys}{use_drbd} eq "8.3")
	{
		$conf->{drbd}{r0} = "
# This is the resource used for the shared GFS2 partition and servers designed
# to run on node 01.
resource r0 {
	# This is the block device path.
	device		/dev/drbd0;
 
	# We'll use the normal internal metadisk (takes about 32MB/TB)
	meta-disk	internal;
 
	# This is the `uname -n` of the first node
	on $conf->{cgi}{anvil_node1_name} {
		# The 'address' has to be the IP, not a hostname. This is the
		# node's SN (bond1) IP. The port number must be unique amoung
		# resources.
		address		$node1_sn_ip:7788;
 
		# This is the block device backing this resource on this node.
		disk		$node1_pool1_partition;
	}
	# Now the same information again for the second node.
	on $conf->{cgi}{anvil_node2_name} {
		address		$node2_sn_ip:7788;
		disk		$node2_pool1_partition;
	}
}
";

		$conf->{drbd}{r1} = "
# This is the resource used for the servers designed to run on node 02.
resource r1 {
	# This is the block device path.
	device		/dev/drbd1;
 
	# We'll use the normal internal metadisk (takes about 32MB/TB)
	meta-disk	internal;
 
	# This is the `uname -n` of the first node
	on $conf->{cgi}{anvil_node1_name} {
		# The 'address' has to be the IP, not a hostname. This is the
		# node's SN (bond1) IP. The port number must be unique amoung
		# resources.
		address		$node1_sn_ip:7789;
 
		# This is the block device backing this resource on this node.
		disk		$node1_pool2_partition;
	}
	# Now the same information again for the second node.
	on $conf->{cgi}{anvil_node2_name} {
		address		$node2_sn_ip:7789;
		disk		$node2_pool2_partition;
	}
}
";
	}
	elsif ($conf->{sys}{use_drbd} eq "8.4")
	{
		$conf->{drbd}{r0} = "
# This is the first DRBD resource. It will store the shared file systems and
# the servers designed to run on node 01.
resource r0 {
	# These options here are common to both nodes. If for some reason you
	# need to set unique values per node, you can move these to the
	# 'on <name> { ... }' section.
 
	# This sets the device name of this DRBD resouce.
	device /dev/drbd0;
 
	# This tells DRBD what the backing device is for this resource.
	disk /dev/sda4;
 
	# This controls the location of the metadata. When 'internal' is used,
	# as we use here, a little space at the end of the backing devices is
	# set aside (roughly 32 MB per 1 TB of raw storage). External metadata
	# can be used to put the metadata on another partition when converting
	# existing file systems to be DRBD backed, when there is no extra space
	# available for the metadata.
	meta-disk internal;
 
	# NOTE: Later, make it an option in the dashboard to trigger a manual
	# 	verify and/or schedule periodic automatic runs
	net {
		# TODO: Test performance differences between sha1 and md5
		# This tells DRBD how to do a block-by-block verification of
		# the data stored on the backing devices. Any verification
		# failures will result in the effected block being marked
		# out-of-sync.
		#verify-alg md5;
 
		# TODO: Test the performance hit of this being enabled.
		# This tells DRBD to generate a checksum for each transmitted
		# packet. If the data received data doesn't generate the same
		# sum, a retransmit request is generated. This protects against
		# otherwise-undetected errors in transmission, like 
		# bit-flipping. See:
		# http://www.drbd.org/users-guide/s-integrity-check.html
		#data-integrity-alg md5;
	}
 
	# WARNING: Confirm that these are safe when the controller's BBU is
	#          depleted/failed and the controller enters write-through 
	#          mode.
	disk {
		# TODO: Test the real-world performance differences gained with
		#       these options.
		# This tells DRBD not to bypass the write-back caching on the
		# RAID controller. Normally, DRBD forces the data to be flushed
		# to disk, rather than allowing the write-back cachine to 
		# handle it. Normally this is dangerous, but with BBU-backed
		# caching, it is safe. The first option disables disk flushing
		# and the second disabled metadata flushes.
		disk-flushes no;
		md-flushes no;
	}
 
	# This sets up the resource on node 01. The name used below must be the
	# named returned by 'uname -n'.
	on node1.ccrs.bcn {
		# This is the address and port to use for DRBD traffic on this
		# node. Multiple resources can use the same IP but the ports
		# must differ. By convention, the first resource uses 7788, the
		# second uses 7789 and so on, incrementing by one for each
		# additional resource. 
		address 10.10.10.1:7788;
	}
	on node2.ccrs.bcn {
		address 10.10.10.2:7788;
	}
}
";

		$conf->{drbd}{r1} = "
";
	}
	
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
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
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
	
	# DRBD ships with 'global_common.conf', so we need to tell if the one
	# we read was stock or not. If it was stock, delete it from the
	# variable so that our generated one gets used.
	my $generic_global_common = 1;
	
	# These will contain the contents of the file.
	$conf->{node}{$node}{drbd_file}{global_common} = "";
	$conf->{node}{$node}{drbd_file}{r0}				   = "";
	$conf->{node}{$node}{drbd_file}{r1}				   = "";
	
	# And these tell us which file we're looking at.
	my $in_global = 0;
	my $in_r0     = 0;
	my $in_r1     = 0;
	foreach my $line (@{$return})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n");
		# Detect the start and end of files.
		if ($line eq "start:$global_common") { $in_global = 1; next; }
		if ($line eq "end:$global_common")   { $in_global = 0; next; }
		if ($line eq "start:$r0")            { $in_r0     = 1; next; }
		if ($line eq "end:$r0")              { $in_r0     = 0; next; }
		if ($line eq "start:$r1")            { $in_r1     = 1; next; }
		if ($line eq "end:$r1")              { $in_r1     = 0; next; }
		
		### TODO: Make sure the storage pool devices are updated if we
		###       use a read-in resource file.
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
	
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], global_common:\n====\n$conf->{node}{$node}{drbd_file}{global_common}\n====\nr0\n====\n$conf->{node}{$node}{drbd_file}{r0}\n====\nr1\n====\n$conf->{node}{$node}{drbd_file}{r1}\n====\n");
	
	return(0);
}

# This does the work of creating a metadata on each DRBD backing device. It
# checks first to see if there already is a metadata and, if so, does nothing.
sub setup_drbd_on_node
{
	my ($conf, $node, $password) = @_;
	
	### Write out the config files if missing.
	# Global common file
	if (not $conf->{node}{$node}{drbd_file}{global_common})
	{
		my $shell_call =  "cat > $conf->{path}{nodes}{drbd_global_common} << EOF\n";
		   $shell_call .= "$conf->{drbd}{global_common}\n";
		   $shell_call .= "EOF";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
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
		foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	}
	
	# r0.res
	if (not $conf->{node}{$node}{drbd_file}{r0})
	{
		# Resource 0 config
		my $shell_call =  "cat > $conf->{path}{nodes}{drbd_r0} << EOF\n";
		   $shell_call .= "$conf->{drbd}{r0}\n";
		   $shell_call .= "EOF";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
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
		foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	}
	
	# r1.res
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_storage_pool2_byte_size: [$conf->{cgi}{anvil_storage_pool2_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}).")].\n");
	if ($conf->{cgi}{anvil_storage_pool2_byte_size})
	{
		if (not $conf->{node}{$node}{drbd_file}{r1})
		{
			# Resource 0 config
			my $shell_call =  "cat > $conf->{path}{nodes}{drbd_r1} << EOF\n";
			   $shell_call .= "$conf->{drbd}{r1}\n";
			   $shell_call .= "EOF";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
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
			foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
		}
	}
	
	### Now setup the meta-data, if needed. Start by reading 'blkid' to see
	### if the partitions already are drbd.
	# Check if the meta-data exists already
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], node::${node}::pool1_partition: [$conf->{node}{$node}{pool1}{partition}], node::${node}::pool2_partition: [$conf->{node}{$node}{pool2}{partition}]\n");
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

	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_rc: [$pool1_rc], pool2_rc: [$pool2_rc]\n");
	return($pool1_rc, $pool2_rc);
}

# This will register the nodes with RHN, if needed. Otherwise it just returns
# without doing anything.
sub register_with_rhn
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; register_with_rhn();\n");
	
	if (not $conf->{sys}{install_manifest}{show}{rhn_checks})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; User has skipped RHN checks.\n");
		return(0);
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::rhn_user: [$conf->{cgi}{rhn_user}], cgi::rhn_password: [$conf->{cgi}{rhn_password}]\n");
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node1}::os::brand: [$conf->{node}{$node1}{os}{brand}], node::${node2}::os::brand: [$conf->{node}{$node2}{os}{brand}]\n");
	if ($conf->{node}{$node1}{os}{brand} =~ /Red Hat Enterprise Linux Server/)
	{
		# See if it's been registered already.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node1}::os::registered: [$conf->{node}{$node1}{os}{registered}], node::${node1}::internet: [$conf->{node}{$node1}{internet}]\n");
		if ((not $conf->{node}{$node1}{os}{registered}) && ($conf->{node}{$node1}{internet}))
		{
			# We're good.
			($node1_ok) = register_node_with_rhn($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $conf->{cgi}{anvil_node1_name});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_ok: [$node1_ok]\n");
		}
		else
		{
			$node1_ok = "skip";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_ok: [$node1_ok]\n");
		}
	}
	else
	{
		$node1_ok = "skip";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_ok: [$node1_ok]\n");
	}
	if ($conf->{node}{$node2}{os}{brand} =~ /Red Hat Enterprise Linux Server/)
	{
		# See if it's been registered already.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node2}::os::registered: [$conf->{node}{$node2}{os}{registered}], node::${node2}::internet: [$conf->{node}{$node2}{internet}]\n");
		if ((not $conf->{node}{$node2}{os}{registered}) && ($conf->{node}{$node2}{internet}))
		{
			# We're good.
			($node2_ok) = register_node_with_rhn($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $conf->{cgi}{anvil_node2_name});
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node2_ok: [$node2_ok]\n");
		}
		else
		{
			$node2_ok = "skip";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node2_ok: [$node2_ok]\n");
		}
	}
	else
	{
		$node2_ok = "skip";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node2_ok: [$node2_ok]\n");
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Registration failed; node: [$node], base: [$base], resilient_storage: [$resilient_storage], optional: [$optional]\n");
		$return_code = 1;
	}
	
	return($return_code);
}

# This summarizes the install plan and gives the use a chance to tweak it or
# re-run the cable mapping.
sub summarize_build_plan
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; summarize_build_plan()\n");
	
	my $node1                = $conf->{cgi}{anvil_node1_current_ip};
	my $node2                = $conf->{cgi}{anvil_node2_current_ip};
	my $say_node1_registered = "#!string!state_0047!#";
	my $say_node2_registered = "#!string!state_0047!#";
	my $say_node1_class      = "highlight_detail";
	my $say_node2_class      = "highlight_detail";
	my $enable_rhn           = 0;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node1}::os::brand: [$conf->{node}{$node1}{os}{brand}]\n");
	if ($conf->{node}{$node1}{os}{brand} =~ /Red Hat Enterprise Linux Server/)
	{
		# See if it's been registered already.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node1}::os::registered: [$conf->{node}{$node1}{os}{registered}]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node1}::internet: [$conf->{node}{$node1}{internet}]\n");
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node2}::os::brand: [$conf->{node}{$node2}{os}{brand}]\n");
	if ($conf->{node}{$node2}{os}{brand} =~ /Red Hat Enterprise Linux Server/)
	{
		# See if it's been registered already.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node2}::os::registered: [$conf->{node}{$node2}{os}{registered}]\n");
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
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node2}::internet: [$conf->{node}{$node2}{internet}]\n");
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
				$say_node2_class      = "highlight_warning";
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; say_node1_os: [$say_node1_os], say_node2_os: [$say_node2_os]\n");
	my $rhn_template = "";
	if ($enable_rhn)
	{
		$rhn_template = AN::Common::template($conf, "install-manifest.html", "rhn-credential-form", {
			rhn_user	=>	$conf->{cgi}{rhn_user},
			rhn_password	=>	$conf->{cgi}{rhn_password},
		});
	}
	
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1: [$node1], node2: [$node2].\n");
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1: [$node1]: bcn_link1: [$conf->{conf}{node}{$node1}{set_nic}{bcn_link1}], bcn_link2: [$conf->{conf}{node}{$node1}{set_nic}{bcn_link2}], sn_link1: [$conf->{conf}{node}{$node1}{set_nic}{sn_link1}], sn_link2: [$conf->{conf}{node}{$node1}{set_nic}{sn_link2}], ifn_link1: [$conf->{conf}{node}{$node1}{set_nic}{ifn_link1}], ifn_link2: [$conf->{conf}{node}{$node1}{set_nic}{ifn_link2}]\n");
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node2: [$node2]: bcn_link1: [$conf->{conf}{node}{$node2}{set_nic}{bcn_link1}], bcn_link2: [$conf->{conf}{node}{$node2}{set_nic}{bcn_link2}], sn_link1: [$conf->{conf}{node}{$node2}{set_nic}{sn_link1}], sn_link2: [$conf->{conf}{node}{$node2}{set_nic}{sn_link2}], ifn_link1: [$conf->{conf}{node}{$node2}{set_nic}{ifn_link1}], ifn_link2: [$conf->{conf}{node}{$node2}{set_nic}{ifn_link2}]\n");
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_storage_partition_1_byte_size: [$conf->{cgi}{anvil_storage_partition_1_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_partition_1_byte_size}).")], cgi::anvil_storage_partition_2_byte_size: [$conf->{cgi}{anvil_storage_partition_2_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_partition_2_byte_size}).")]\n");
	if (not $conf->{cgi}{anvil_storage_partition_1_byte_size})
	{
		$conf->{cgi}{anvil_storage_partition_1_byte_size} = $conf->{cgi}{anvil_media_library_byte_size} + $conf->{cgi}{anvil_storage_pool1_byte_size};
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_storage_partition_1_byte_size: [$conf->{cgi}{anvil_storage_partition_1_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_partition_1_byte_size}).")] == cgi::anvil_media_library_byte_size: [$conf->{cgi}{anvil_media_library_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_media_library_byte_size}).")] + cgi::anvil_storage_pool1_byte_size: [$conf->{cgi}{anvil_storage_pool1_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}).")]\n");
	}
	if (not $conf->{cgi}{anvil_storage_partition_2_byte_size})
	{
		$conf->{cgi}{anvil_storage_partition_2_byte_size} = $conf->{cgi}{anvil_storage_pool2_byte_size};
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_storage_partition_2_byte_size: [$conf->{cgi}{anvil_storage_partition_2_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_partition_2_byte_size}).")] == cgi::anvil_storage_pool2_byte_size: [$conf->{cgi}{anvil_storage_pool2_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}).")]\n");
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

# This reads in the /etc/ntp.conf file and adds custom NTP server if they
# aren't already there.
sub configure_ntp_on_node
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_ntp_on_node(); node: [$node]\n");
	
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		$conf->{node}{$node}{internet} = 0;
		foreach my $line (@{$return})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code]\n");
	return($return_code);
}

# This handles the actual configuration of the network files.
sub configure_network_on_node
{
	my ($conf, $node, $password, $node_number) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_network_on_node(); node: [$node], node_number: [$node_number]\n");
	
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_mtu_size: [$conf->{cgi}{anvil_mtu_size}], sys::install_manifest::default::mtu: [$conf->{sys}{install_manifest}{'default'}{mtu}]\n");
	my $mtu = $conf->{cgi}{anvil_mtu_size} ? $conf->{cgi}{anvil_mtu_size} : $conf->{sys}{install_manifest}{'default'}{mtu};
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; mtu: [$mtu]\n");
	   $mtu = "" if $mtu eq "1500"; 
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; mtu: [$mtu]\n");
	
	# Here we're going to write out all the network and udev configuration
	# details per node.
	#$conf->{path}{nodes}{hostname};
	my $hostname =  "NETWORKING=yes\n";
	   $hostname .= "HOSTNAME=$conf->{cgi}{$name_key}";
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; bcn_link1_mac_key: [$bcn_link1_mac_key], cgi::$bcn_link1_mac_key: [$conf->{cgi}{$bcn_link1_mac_key}]\n");
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; bcn_link2_mac_key: [$bcn_link2_mac_key], cgi::$bcn_link2_mac_key: [$conf->{cgi}{$bcn_link2_mac_key}]\n");
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sn_link1_mac_key: [$sn_link1_mac_key], cgi::$sn_link1_mac_key: [$conf->{cgi}{$sn_link1_mac_key}]\n");
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sn_link2_mac_key: [$sn_link2_mac_key], cgi::$sn_link2_mac_key: [$conf->{cgi}{$sn_link2_mac_key}]\n");
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ifn_link1_mac_key: [$ifn_link1_mac_key], cgi::$ifn_link1_mac_key: [$conf->{cgi}{$ifn_link1_mac_key}]\n");
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ifn_link2_mac_key: [$ifn_link2_mac_key], cgi::$ifn_link2_mac_key: [$conf->{cgi}{$ifn_link2_mac_key}]\n");
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
	my $udev_rules =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n\n";
	   $udev_rules .= "# Back-Channel Network, Link 1\n";
	   $udev_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$conf->{cgi}{$bcn_link1_mac_key}\", NAME=\"bcn_link1\"\n\n";
	   $udev_rules .= "# Back-Channel Network, Link 2\n";
	   $udev_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$conf->{cgi}{$bcn_link2_mac_key}\", NAME=\"bcn_link2\"\n\n";
	   $udev_rules .= "# Storage Network, Link 1\n";
	   $udev_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$conf->{cgi}{$sn_link1_mac_key}\", NAME=\"sn_link1\"\n\n";
	   $udev_rules .= "# Storage Network, Link 2\n";
	   $udev_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$conf->{cgi}{$sn_link2_mac_key}\", NAME=\"sn_link2\"\n\n";
	   $udev_rules .= "# Internet-Facing Network, Link 1\n";
	   $udev_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$conf->{cgi}{$ifn_link1_mac_key}\", NAME=\"ifn_link1\"\n\n";
	   $udev_rules .= "# Internet-Facing Network, Link 2\n";
	   $udev_rules .= "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$conf->{cgi}{$ifn_link2_mac_key}\", NAME=\"ifn_link2\"\n";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; udev_rules: \n====\n$udev_rules\n====\n");
	
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
	
	#$conf->{path}{nodes}{bcn_bond1_config};
	my $ifcfg_bcn_bond1 =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n";
	   $ifcfg_bcn_bond1 .= "# Back-Channel Network - Bond 1\n";
	   $ifcfg_bcn_bond1 .= "DEVICE=\"bcn_bond1\"\n";
	   $ifcfg_bcn_bond1 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_bcn_bond1 .= "BOOTPROTO=\"static\"\n";
	   $ifcfg_bcn_bond1 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_bcn_bond1 .= "BONDING_OPTS=\"mode=1 miimon=100 use_carrier=1 updelay=120000 downdelay=0 primary=bcn_link1\"\n";
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
	
	#$conf->{path}{nodes}{sn_bond1_config};
	my $ifcfg_sn_bond1 =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n";
	   $ifcfg_sn_bond1 .= "# Storage Network - Bond 1\n";
	   $ifcfg_sn_bond1 .= "DEVICE=\"sn_bond1\"\n";
	   $ifcfg_sn_bond1 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_sn_bond1 .= "BOOTPROTO=\"static\"\n";
	   $ifcfg_sn_bond1 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_sn_bond1 .= "BONDING_OPTS=\"mode=1 miimon=100 use_carrier=1 updelay=120000 downdelay=0 primary=sn_link1\"\n";
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
	
	#$conf->{path}{nodes}{ifn_bond1_config};
	my $ifcfg_ifn_bond1 =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n";
	   $ifcfg_ifn_bond1 .= "# Internet-Facing Network - Bond 1\n";
	   $ifcfg_ifn_bond1 .= "DEVICE=\"ifn_bond1\"\n";
	   $ifcfg_ifn_bond1 .= "MTU=\"$mtu\"\n" if $mtu;
	   $ifcfg_ifn_bond1 .= "BRIDGE=\"ifn_bridge1\"\n";
	   $ifcfg_ifn_bond1 .= "BOOTPROTO=\"none\"\n";
	   $ifcfg_ifn_bond1 .= "ONBOOT=\"yes\"\n";
	   $ifcfg_ifn_bond1 .= "BONDING_OPTS=\"mode=1 miimon=100 use_carrier=1 updelay=120000 downdelay=0 primary=ifn_link1\"";
	
	#$conf->{path}{nodes}{ifn_bridge1_config};
	### NOTE: We don't set the MTU here because the bridge will ignore it.
	###       Bridges always take the MTU of the connected device with the
	###       lowest MTU.
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
	
	my $vnc_range = 5900 + $conf->{cgi}{anvil_open_vnc_ports};
	my $iptables =  "# Generated by: [$THIS_FILE] on: [".AN::Cluster::get_date($conf)."].\n";
	   $iptables .= "*filter\n";
	   $iptables .= ":INPUT ACCEPT [0:0]\n";
	   $iptables .= ":FORWARD ACCEPT [0:0]\n";
	   $iptables .= ":OUTPUT ACCEPT [0:0]\n";
	   $iptables .= "-A INPUT -s $conf->{cgi}{anvil_ifn_network}/$conf->{cgi}{anvil_ifn_subnet} -d $conf->{cgi}{anvil_ifn_network}/$conf->{cgi}{anvil_ifn_subnet} -p tcp -m state --state NEW -m tcp --dport 5900:$vnc_range -j ACCEPT \n";
	   $iptables .= "-A INPUT -s $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -d $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -p tcp -m state --state NEW -m tcp --dport 5900:5999 -j ACCEPT \n";
	   $iptables .= "-A INPUT -s $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -d $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -p tcp -m tcp --dport 49152:49216 -j ACCEPT \n";
	   $iptables .= "-A INPUT -s $conf->{cgi}{anvil_sn_network}/$conf->{cgi}{anvil_sn_subnet} -d $conf->{cgi}{anvil_sn_network}/$conf->{cgi}{anvil_sn_subnet} -p tcp -m state --state NEW -m tcp --dport 7789 -j ACCEPT \n";
	   $iptables .= "-A INPUT -s $conf->{cgi}{anvil_sn_network}/$conf->{cgi}{anvil_sn_subnet} -d $conf->{cgi}{anvil_sn_network}/$conf->{cgi}{anvil_sn_subnet} -p tcp -m state --state NEW -m tcp --dport 7788 -j ACCEPT \n";
	   $iptables .= "-A INPUT -p igmp -j ACCEPT \n";
	   $iptables .= "-A INPUT -s $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -d $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -p tcp -m state --state NEW -m tcp --dport 16851 -j ACCEPT \n";
	   $iptables .= "-A INPUT -s $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -d $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -p tcp -m state --state NEW -m tcp --dport 11111 -j ACCEPT \n";
	   $iptables .= "-A INPUT -s $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -d $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -p tcp -m state --state NEW -m tcp --dport 21064 -j ACCEPT \n";
	   $iptables .= "-A INPUT -s $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -p udp -m addrtype --dst-type MULTICAST -m state --state NEW -m multiport --dports 5404,5405 -j ACCEPT \n";
	   $iptables .= "-A INPUT -s $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -d $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -p udp -m state --state NEW -m multiport --dports 5404,5405 -j ACCEPT \n";
	   $iptables .= "-A INPUT -s $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -d $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -p udp -m state --state NEW -m udp --dport 123 -j ACCEPT \n";
	   $iptables .= "-A INPUT -s $conf->{cgi}{anvil_ifn_network}/$conf->{cgi}{anvil_ifn_subnet} -d $conf->{cgi}{anvil_ifn_network}/$conf->{cgi}{anvil_ifn_subnet} -p udp -m state --state NEW -m udp --dport 123 -j ACCEPT \n";
	   # TODO: Open up VNC now, but make it an option later.
	   $iptables .= "-A INPUT -s $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -d $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -p tcp -m state --state NEW -m tcp --dport 5900 -j ACCEPT \n";
	   $iptables .= "-A INPUT -s $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -d $conf->{cgi}{anvil_bcn_network}/$conf->{cgi}{anvil_bcn_subnet} -p tcp -m state --state NEW -m tcp --dport 5800 -j ACCEPT \n";
	   $iptables .= "-A INPUT -s $conf->{cgi}{anvil_ifn_network}/$conf->{cgi}{anvil_ifn_subnet} -d $conf->{cgi}{anvil_ifn_network}/$conf->{cgi}{anvil_ifn_subnet} -p tcp -m state --state NEW -m tcp --dport 5900 -j ACCEPT \n";
	   $iptables .= "-A INPUT -s $conf->{cgi}{anvil_ifn_network}/$conf->{cgi}{anvil_ifn_subnet} -d $conf->{cgi}{anvil_ifn_network}/$conf->{cgi}{anvil_ifn_subnet} -p tcp -m state --state NEW -m tcp --dport 5800 -j ACCEPT \n";
	   $iptables .= "-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT \n";
	   $iptables .= "-A INPUT -p icmp -j ACCEPT \n";
	   $iptables .= "-A INPUT -i lo -j ACCEPT \n";
	   $iptables .= "-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT \n";
	   $iptables .= "-A INPUT -j REJECT --reject-with icmp-host-prohibited \n";
	   $iptables .= "-A FORWARD -j REJECT --reject-with icmp-host-prohibited \n";
	   $iptables .= "COMMIT\n";
	
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
	my ($ups1_short_name)     = ($conf->{cgi}{anvil_ups1_name}     =~ /^(.*?)\./);
	my ($ups2_short_name)     = ($conf->{cgi}{anvil_ups2_name}     =~ /^(.*?)\./);
	my ($striker1_short_name) = ($conf->{cgi}{anvil_striker1_name} =~ /^(.*?)\./);
	my ($striker2_short_name) = ($conf->{cgi}{anvil_striker1_name} =~ /^(.*?)\./);
	
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
	   $hosts .= "$conf->{cgi}{anvil_pdu3_ip}	$pdu3_short_name $conf->{cgi}{anvil_pdu3_name}\n";
	   $hosts .= "$conf->{cgi}{anvil_pdu4_ip}	$pdu4_short_name $conf->{cgi}{anvil_pdu4_name}\n";
	   $hosts .= "\n";
	   $hosts .= "# UPSes\n";
	   $hosts .= "$conf->{cgi}{anvil_ups1_ip}	$ups1_short_name $conf->{cgi}{anvil_ups1_name}\n";
	   $hosts .= "$conf->{cgi}{anvil_ups2_ip}	$ups2_short_name $conf->{cgi}{anvil_ups2_name}\n";
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Deleting any existing ifcfg-eth* files on: [$node]\n");
	### TODO: Make this smarter so that it deletes everything ***EXCEPT*** ifcfg-lo
	my $shell_call = "rm -f $conf->{path}{nodes}{ifcfg_directory}/ifcfg-eth*";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
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
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	### Start writing!
	### Internet-Facing Network
	# IFN Bridge 1
	$shell_call =  "cat > $conf->{path}{nodes}{ifn_bridge1_config} << EOF\n";
	$shell_call .= "$ifcfg_ifn_bridge1\n";
	$shell_call .= "EOF";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	# IFN Bond 1
	$shell_call =  "cat > $conf->{path}{nodes}{ifn_bond1_config} << EOF\n";
	$shell_call .= "$ifcfg_ifn_bond1\n";
	$shell_call .= "EOF";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	# IFN Link 1
	$shell_call =  "cat > $conf->{path}{nodes}{ifn_link1_config} << EOF\n";
	$shell_call .= "$ifcfg_ifn_link1\n";
	$shell_call .= "EOF";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	# IFN Link 2
	$shell_call =  "cat > $conf->{path}{nodes}{ifn_link2_config} << EOF\n";
	$shell_call .= "$ifcfg_ifn_link2\n";
	$shell_call .= "EOF";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	### Storage Network
	# SN Bond 1
	$shell_call =  "cat > $conf->{path}{nodes}{sn_bond1_config} << EOF\n";
	$shell_call .= "$ifcfg_sn_bond1\n";
	$shell_call .= "EOF";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	# SN Link 1
	$shell_call =  "cat > $conf->{path}{nodes}{sn_link1_config} << EOF\n";
	$shell_call .= "$ifcfg_sn_link1\n";
	$shell_call .= "EOF";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	# SN Link 2
	$shell_call =  "cat > $conf->{path}{nodes}{sn_link2_config} << EOF\n";
	$shell_call .= "$ifcfg_sn_link2\n";
	$shell_call .= "EOF";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	### Back-Channel Network
	# BCN Bond 1
	$shell_call =  "cat > $conf->{path}{nodes}{bcn_bond1_config} << EOF\n";
	$shell_call .= "$ifcfg_bcn_bond1\n";
	$shell_call .= "EOF";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	# BCN Link 1
	$shell_call =  "cat > $conf->{path}{nodes}{bcn_link1_config} << EOF\n";
	$shell_call .= "$ifcfg_bcn_link1\n";
	$shell_call .= "EOF";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	# BCN Link 2
	$shell_call =  "cat > $conf->{path}{nodes}{bcn_link2_config} << EOF\n";
	$shell_call .= "$ifcfg_bcn_link2\n";
	$shell_call .= "EOF";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	### Now write the udev rules file.
	$shell_call = "cat > $conf->{path}{nodes}{udev_net_rules} << EOF\n";
	$shell_call .= "$udev_rules\n";
	$shell_call .= "EOF";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	$shell_call =  "cat > $conf->{path}{nodes}{hosts} << EOF\n";
	$shell_call .= "$hosts\n";
	$shell_call .= "EOF";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	### Now write the hostname file and set the hostname for the current
	### session.
	$shell_call =  "cat > $conf->{path}{nodes}{hostname} << EOF\n";
	$shell_call .= "$hostname\n";
	$shell_call .= "EOF";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	$shell_call = "hostname $conf->{cgi}{$name_key}";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	### And finally, iptables. 
	### NOTE: DON'T restart iptables! It could break the connection as the
	###       rules are for the new network config, which may differ from
	###       the active one.
	# First, get a word count on the current iptables in-memory config. If
	# it's smaller than 15 lines, it's probably the original one and we'll
	# need a reboot.
	$shell_call = "echo \"lines:\$(iptables-save | wc -l)\"\n";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
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
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); 
		if ($line =~ /^lines:(\d+)$/)
		{
			my $lines = $1;
			if ($lines < 15)
			{
				# Reboot needed
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; iptables file has: [$lines]; node: [$node] Reboot needed.\n"); 
				$conf->{node}{$node}{reboot_needed} = 1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node}::reboot_needed: [$conf->{node}{$node}{reboot_needed}]\n"); 
			}
			else
			{
				# Reboot probably not needed.
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; iptables file has: [$lines]; node: [$node] Reboot NOT needed.\n"); 
			}
		}
	}
	
	# Now write the new one.
	$shell_call =  "cat > $conf->{path}{nodes}{iptables} << EOF\n";
	$shell_call .= "$iptables\n";
	$shell_call .= "EOF";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	### TODO: Add sanity checks.
	# If there is not an ifn_bridge1, assume we need to reboot.
	my $bridge_found = 0;
	   $shell_call   = "brctl show";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
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
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n");
		if ($line =~ /ifn_bridge1/)
		{
			$bridge_found = 1;
		}
	}
	if (not $bridge_found)
	{
		$conf->{node}{$node}{reboot_needed} = 1;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node] needs a reboot.\n");
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code]\n");
	return($return_code);
}

# If NTP servers are set, this will read in each node's '/etc/ntp.conf' and
# look to see if the defined NTP servers need to be added. It will add any that
# are missing.
sub configure_ntp
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_ntp()\n");
	
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This configures the network.
sub configure_network
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_network()\n");
	
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Checking node1: [$node1]'s: nic: [$nic], mac: [$mac].\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node1_bcn_link1_mac: [$conf->{cgi}{anvil_node1_bcn_link1_mac}].\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node1_bcn_link2_mac: [$conf->{cgi}{anvil_node1_bcn_link2_mac}].\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node1_sn_link1_mac:  [$conf->{cgi}{anvil_node1_sn_link1_mac}].\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node1_sn_link2_mac:  [$conf->{cgi}{anvil_node1_sn_link2_mac}].\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node1_ifn_link1_mac: [$conf->{cgi}{anvil_node1_ifn_link1_mac}].\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node1_ifn_link2_mac: [$conf->{cgi}{anvil_node1_ifn_link2_mac}].\n");
		if ($mac eq $conf->{cgi}{anvil_node1_bcn_link1_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{bcn_link1} = $mac;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; conf::node::${node1}::set_nic::bcn_link1: [$conf->{conf}{node}{$node1}{set_nic}{bcn_link1}].\n");
		}
		elsif ($mac eq $conf->{cgi}{anvil_node1_bcn_link2_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{bcn_link2} = $mac;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; conf::node::${node1}::set_nic::bcn_link2: [$conf->{conf}{node}{$node1}{set_nic}{bcn_link2}].\n");
		}
		elsif ($mac eq $conf->{cgi}{anvil_node1_sn_link1_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{sn_link1} = $mac;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; conf::node::${node1}::set_nic::sn_link1: [$conf->{conf}{node}{$node1}{set_nic}{sn_link1}].\n");
		}
		elsif ($mac eq $conf->{cgi}{anvil_node1_sn_link2_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{sn_link2} = $mac;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; conf::node::${node1}::set_nic::sn_link2: [$conf->{conf}{node}{$node1}{set_nic}{sn_link2}].\n");
		}
		elsif ($mac eq $conf->{cgi}{anvil_node1_ifn_link1_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{ifn_link1} = $mac;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; conf::node::${node1}::set_nic::ifn_link1: [$conf->{conf}{node}{$node1}{set_nic}{ifn_link1}].\n");
		}
		elsif ($mac eq $conf->{cgi}{anvil_node1_ifn_link2_mac})
		{
			$conf->{conf}{node}{$node1}{set_nic}{ifn_link2} = $mac;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; conf::node::${node1}::set_nic::ifn_link2: [$conf->{conf}{node}{$node1}{set_nic}{ifn_link2}].\n");
		}
		else
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Unrecognized interface; node1: [$node1]: nic: [$nic], mac: [$mac].\n");
			$conf->{conf}{node}{$node1}{unknown_nic}{$nic} = $mac;
		}
	}
	foreach my $nic (sort {$a cmp $b} keys %{$conf->{conf}{node}{$node2}{current_nic}})
	{
		my $mac = $conf->{conf}{node}{$node2}{current_nic}{$nic};
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Checking node2: [$node2]'s: nic: [$nic], mac: [$mac].\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node2_bcn_link1_mac: [$conf->{cgi}{anvil_node2_bcn_link1_mac}].\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node2_bcn_link2_mac: [$conf->{cgi}{anvil_node2_bcn_link2_mac}].\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node2_sn_link1_mac:  [$conf->{cgi}{anvil_node2_sn_link1_mac}].\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node2_sn_link2_mac:  [$conf->{cgi}{anvil_node2_sn_link2_mac}].\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node2_ifn_link1_mac: [$conf->{cgi}{anvil_node2_ifn_link1_mac}].\n");
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_node2_ifn_link2_mac: [$conf->{cgi}{anvil_node2_ifn_link2_mac}].\n");
		if ($mac eq $conf->{cgi}{anvil_node2_bcn_link1_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{bcn_link1} = $mac;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; conf::node::${node2}::set_nic::bcn_link1: [$conf->{conf}{node}{$node2}{set_nic}{bcn_link1}].\n");
		}
		elsif ($mac eq $conf->{cgi}{anvil_node2_bcn_link2_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{bcn_link2} = $mac;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; conf::node::${node2}::set_nic::bcn_link2: [$conf->{conf}{node}{$node2}{set_nic}{bcn_link2}].\n");
		}
		elsif ($mac eq $conf->{cgi}{anvil_node2_sn_link1_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{sn_link1} = $mac;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; conf::node::${node2}::set_nic::sn_link1: [$conf->{conf}{node}{$node2}{set_nic}{sn_link1}].\n");
		}
		elsif ($mac eq $conf->{cgi}{anvil_node2_sn_link2_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{sn_link2} = $mac;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; conf::node::${node2}::set_nic::sn_link2: [$conf->{conf}{node}{$node2}{set_nic}{sn_link2}].\n");
		}
		elsif ($mac eq $conf->{cgi}{anvil_node2_ifn_link1_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{ifn_link1} = $mac;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; conf::node::${node2}::set_nic::ifn_link1: [$conf->{conf}{node}{$node2}{set_nic}{ifn_link1}].\n");
		}
		elsif ($mac eq $conf->{cgi}{anvil_node2_ifn_link2_mac})
		{
			$conf->{conf}{node}{$node2}{set_nic}{ifn_link2} = $mac;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; conf::node::${node2}::set_nic::ifn_link2: [$conf->{conf}{node}{$node2}{set_nic}{ifn_link2}].\n");
		}
		else
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Unrecognized interface; node2: [$node2]: nic: [$nic], mac: [$mac].\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The ifn_bridge1 device exists on both nodes already, remap not needed.\n");
		
		# To make the summary look better, we'll take the NICs we
		# thought we didn't recognize and feed them into 'set_nic'.
		foreach my $node (sort {$a cmp $b} keys %{$conf->{conf}{node}})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Recording 'unknown' NICs for node: [$node].\n");
			foreach my $nic (sort {$a cmp $b} keys %{$conf->{conf}{node}{$node}{unknown_nic}})
			{
				my $mac = $conf->{conf}{node}{$node}{unknown_nic}{$nic};
				$conf->{conf}{node}{$node}{set_nic}{$nic} = $mac;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Node: [$node], nic: [$nic], mac: [$conf->{conf}{node}{$node}{set_nic}{$nic}].\n");
			}
		}
	}
	else
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Set node1: [$node1]'s interfaces to; bcn_link1: [$conf->{conf}{node}{$node1}{set_nic}{bcn_link1}], bcn_link2: [$conf->{conf}{node}{$node1}{set_nic}{bcn_link2}], sn_link1: [$conf->{conf}{node}{$node1}{set_nic}{sn_link1}], sn_link2: [$conf->{conf}{node}{$node1}{set_nic}{sn_link2}], ifn_link1: [$conf->{conf}{node}{$node1}{set_nic}{ifn_link1}], ifn_link2: [$conf->{conf}{node}{$node1}{set_nic}{ifn_link2}].\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The ifn_bridge1 device exists on both nodes already, remap not needed.\n");
		
		# To make the summary look better, we'll take the NICs we
		# thought we didn't recognize and feed them into 'set_nic'.
		foreach my $node (sort {$a cmp $b} keys %{$conf->{conf}{node}})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Recording 'unknown' NICs for node: [$node].\n");
			foreach my $nic (sort {$a cmp $b} keys %{$conf->{conf}{node}{$node}{unknown_nic}})
			{
				my $mac = $conf->{conf}{node}{$node}{unknown_nic}{$nic};
				$conf->{conf}{node}{$node}{set_nic}{$nic} = $mac;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Node: [$node], nic: [$nic], mac: [$conf->{conf}{node}{$node}{set_nic}{$nic}].\n");
			}
		}
	}
	else
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Set node2: [$node2]'s interfaces to; bcn_link1: [$conf->{conf}{node}{$node2}{set_nic}{bcn_link1}], bcn_link2: [$conf->{conf}{node}{$node2}{set_nic}{bcn_link2}], sn_link1: [$conf->{conf}{node}{$node2}{set_nic}{sn_link1}], sn_link2: [$conf->{conf}{node}{$node2}{set_nic}{sn_link2}], ifn_link1: [$conf->{conf}{node}{$node2}{set_nic}{ifn_link1}], ifn_link2: [$conf->{conf}{node}{$node2}{set_nic}{ifn_link2}].\n");
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::remap_network: [$conf->{cgi}{remap_network}]\n");
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; map_network_on_node(); node: [$node], remap: [$remap], say_node: [$say_node]\n");
	
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
	my $shell_call = "
if [ ! -e \"$conf->{path}{'anvil-map-network'}\" ]; 
then
	if [ ! -e '/sbin/striker' ]
	then
		mkdir /sbin/striker
	fi
	curl $conf->{url}{'anvil-map-network'} > $conf->{path}{'anvil-map-network'};
fi;
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
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
	my $proceed = 0;
	foreach my $line (@{$return})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ "ready")
		{
			# Downloaded (or already existed), ready to go.
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; proceed: [$proceed]\n");
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; proceed: [$proceed], return_code: [$return_code]\n");
	
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; SSH File handle: [$conf->{node}{$node}{ssh_fh}] for node: [$node] doesn't exist, but it should. \n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; remap: [$remap]\n");
		if ($remap)
		{
			$conf->{cgi}{update_manifest} = 1;
			$shell_call = "$conf->{path}{'anvil-map-network'} --script";
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call], cgi::update_manifest: [$conf->{cgi}{update_manifest}]\n");
		
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; channel: [$channel], shell_call: [$shell_call]\n");
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
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; STDOUT: [$line].\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node]: bcn_link1: [$conf->{conf}{node}{$node}{set_nic}{bcn_link1}], bcn_link2: [$conf->{conf}{node}{$node}{set_nic}{bcn_link2}], sn_link1: [$conf->{conf}{node}{$node}{set_nic}{sn_link1}], sn_link2: [$conf->{conf}{node}{$node}{set_nic}{sn_link2}], ifn_link1: [$conf->{conf}{node}{$node}{set_nic}{ifn_link1}], ifn_link2: [$conf->{conf}{node}{$node}{set_nic}{ifn_link2}]\n");
	}
	
	if (($nics_seen < 6) && (not $return_code))
	{
		$return_code = 4;
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], to_install: [$to_install]\n");
	
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
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
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
		
		# If the MegaCli64 binary exists, make sure there is a symlink
		# to it.
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	22,
			user		=>	"root",
			password	=>	$password,
			ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
		$conf->{node}{$node}{internet} = 0;
		foreach my $line (@{$return})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
			if ($line =~ /Failed/i)
			{
				$ok = 0;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to create the 'MegaCli64' symlink! Does: [$conf->{path}{nodes}{MegaCli64}] exist?.\n");
			}
			elsif ($line =~ /exists/i)
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The 'MegaCli64' symlink already exists.\n");
			}
			elsif ($line =~ /created/i)
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The 'MegaCli64' symlink was created.\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	22,
			user		=>	"root",
			password	=>	$password,
			ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
		$conf->{node}{$node}{internet} = 0;
		foreach my $line (@{$return})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
			if ($line =~ /Failed/i)
			{
				$ok = 0;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to create the 'storcli64' symlink! Does: [$conf->{path}{nodes}{storcli64}] exist?.\n");
			}
			elsif ($line =~ /exists/i)
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The 'storcli64' symlink already exists.\n");
			}
			elsif ($line =~ /created/i)
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The 'storcli64' symlink was created.\n");
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
			
			# Some packages are defined with the arch to ensure
			# other versions than the active arch of libraries are
			# installed. To be sure we see that they're installed,
			# we record the package with arch as '1'.
			my $package_with_arch = "$package.$arch";
			
			# NOTE: Someday record the version.
			$conf->{node}{$node}{packages}{installed}{$package}           = 1;
			$conf->{node}{$node}{packages}{installed}{$package_with_arch} = 1;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Package: [$package], arch: [$arch], version: [$version]\n");
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
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Package: [$package], arch: [$arch], version: [$version]\n");
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
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Package: [$package], arch: [$arch], version: [$version]\n");
		}
	}
	
	return(0);
}

### NOTE: Unfinished!
# This add the local machine's repo to the node so that this machine can be
# used for the install if there is no internet connection.
sub add_local_repo
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; add_local_repo()\n");
	
	# If I don't know my local IPs and if I don't have any local repos,
	# return.
	my $node1_rc    = 0;
	my $node2_rc    = 0;
	my $repo_target = 1;
	if ((not $conf->{sys}{'local'}{ifn}{ip}) && (not $conf->{sys}{'local'}{bcn}{ip}))
	{
		# I don't know my IPs.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; I don't know my IPs, so I can't setup repos.\n");
		$repo_target = 0;
		$node1_rc    = 3;
		$node2_rc    = 3;
	}
	if ((not $conf->{sys}{'local'}{repo}{centos}) && 
	    (not $conf->{sys}{'local'}{repo}{generic}) &&
	    (not $conf->{sys}{'local'}{repo}{rhel}))
	{
		# I have no repos.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; I do not appear to have any local repositories.\n");
		$repo_target = 0;
		$node1_rc    = 4;
		$node2_rc    = 4;
	}
	if ($repo_target)
	{
		my ($node1_rc) = add_local_repo_to_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
		my ($node2_rc) = add_local_repo_to_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	}
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_rc: [$node1_rc], node2_rc: [$node2_rc].\n");
	
	# 0 == Node online, local repo not needed.  
	# 2 == Repo was added and yum cache was cleaned
	# 3 == (From above) Local IPs now known.
	# 4 == (From above) Not a repo target.
	# 9 == Something went wrong.
	my $ok            = 1;
	my $node1_class   = "highlight_good_bold";
	my $node1_message = "#!string!state_0047!#";
	my $node2_class   = "highlight_good_bold";
	my $node2_message = "#!string!state_0047!#";
	my $message       = "";
	if ($node1_rc eq "1")
	{
		$node1_message = "#!string!state_0020!#",
	}
	elsif ($node1_rc eq "2")
	{
		$node1_message = "#!string!state_0023!#",
	}
	elsif ($node1_rc eq "3")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0100!#",
		$ok            = 0;
	}
	elsif ($node1_rc eq "4")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0101!#",
		$ok            = 0;
	}
	elsif ($node1_rc eq "9")
	{
		$node1_class   = "highlight_warning_bold";
		$node1_message = "#!string!state_0018!#",
		$ok            = 0;
	}
	if ($node2_rc eq "1")
	{
		$node2_message = "#!string!state_0020!#",
	}
	elsif ($node2_rc eq "2")
	{
		$node2_message = "#!string!state_0023!#",
	}
	elsif ($node2_rc eq "3")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0100!#",
		$ok            = 0;
	}
	elsif ($node2_rc eq "4")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0101!#",
		$ok            = 0;
	}
	elsif ($node2_rc eq "9")
	{
		$node2_class   = "highlight_warning_bold";
		$node2_message = "#!string!state_0018!#",
		$ok            = 0;
	}

	print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-message", {
		row		=>	"#!string!row_0245!#",
		node1_class	=>	$node1_class,
		node1_message	=>	$node1_message,
		node2_class	=>	$node2_class,
		node2_message	=>	$node2_message,
	});
	
	if (not $ok)
	{
		print AN::Common::template($conf, "install-manifest.html", "new-anvil-install-warning", {
			message	=>	"#!string!message_0367!#",
			row	=>	"#!string!state_0021!#",
		});
	}
	
	return(0);
}

# This adds the local repo(s) to the node if the node doesn't have an Internet
# connection.
sub add_local_repo_to_node
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; add_local_repo_to_node(); node: [$node]\n");
	
	my $rc = 0;
	if ($conf->{node}{$node}{internet})
	{
		# Online, we don't need to use ourselves as an install target.
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Node is online, skipping.\n");
	}
	else
	{
		### TODO: sanity check that the repos were written properly.
		# For each repo I have locally, add it.
		$rc = 2;
		if (($conf->{sys}{'local'}{repo}{centos}) && ($conf->{node}{$node}{os}{brand} =~ /CentOS/i))
		{
			# Add the CentOS repo.
			my $repo_file = "/etc/yum.repos.d/$conf->{sys}{'local'}{hostname}_centos.repo";
			my $repo =  "[$conf->{sys}{'local'}{hostname}_centos]\n";
			   $repo .= "name=$conf->{sys}{'local'}{hostname} 1's CentOS 6 repository\n";
			   $repo .= "baseurl=http://$conf->{sys}{'local'}{ifn}{ip}$conf->{path}{repo_centos_path}\n" if $conf->{sys}{'local'}{ifn}{ip};
			   $repo .= "baseurl=http://$conf->{sys}{'local'}{bcn}{ip}$conf->{path}{repo_centos_path}\n" if $conf->{sys}{'local'}{bcn}{ip};
			   $repo .= "enabled=1\n";
			   $repo .= "gpgcheck=0\n";
			   $repo .= "skip_if_unavailable=1\n";
			my $shell_call =  "cat > $repo_file << EOF\n";
			   $shell_call .= "$repo\n";
			   $shell_call .= "EOF\n";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
			my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
				node		=>	$node,
				port		=>	22,
				user		=>	"root",
				password	=>	$password,
				ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
				'close'		=>	0,
				shell_call	=>	"$shell_call",
			});
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
			foreach my $line (@{$return})
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
			}
		}
		if (($conf->{sys}{'local'}{repo}{rhel}) && ($conf->{node}{$node}{os}{brand} =~ /Red Hat/i))
		{
			# Add the RHEL repo.
			my $repo_file = "/etc/yum.repos.d/$conf->{sys}{'local'}{hostname}_rhel.repo";
			my $repo =  "[$conf->{sys}{'local'}{hostname}_rhel]\n";
			   $repo .= "name=$conf->{sys}{'local'}{hostname} 1's RHEL 6 repository\n";
			   $repo .= "baseurl=http://$conf->{sys}{'local'}{ifn}{ip}$conf->{path}{repo_rhel_path}\n" if $conf->{sys}{'local'}{ifn}{ip};
			   $repo .= "baseurl=http://$conf->{sys}{'local'}{bcn}{ip}$conf->{path}{repo_rhel_path}\n" if $conf->{sys}{'local'}{bcn}{ip};
			   $repo .= "enabled=1\n";
			   $repo .= "gpgcheck=0\n";
			   $repo .= "skip_if_unavailable=1\n";
			my $shell_call =  "cat > $repo_file << EOF\n";
			   $shell_call .= "$repo\n";
			   $shell_call .= "EOF\n";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
			my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
				node		=>	$node,
				port		=>	22,
				user		=>	"root",
				password	=>	$password,
				ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
				'close'		=>	0,
				shell_call	=>	"$shell_call",
			});
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
			foreach my $line (@{$return})
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
			}
		}
		if ($conf->{sys}{'local'}{repo}{generic})
		{
			# Add the common/generic repo.
			my $repo_file = "/etc/yum.repos.d/$conf->{sys}{'local'}{hostname}.repo";
			my $repo =  "[$conf->{sys}{'local'}{hostname}]\n";
			   $repo .= "name=$conf->{sys}{'local'}{hostname} 1's RPM repository\n";
			   $repo .= "baseurl=http://$conf->{sys}{'local'}{ifn}{ip}$conf->{path}{repo_generic_path}\n" if $conf->{sys}{'local'}{ifn}{ip};
			   $repo .= "baseurl=http://$conf->{sys}{'local'}{bcn}{ip}$conf->{path}{repo_generic_path}\n" if $conf->{sys}{'local'}{bcn}{ip};
			   $repo .= "enabled=1\n";
			   $repo .= "gpgcheck=0\n";
			   $repo .= "skip_if_unavailable=1\n";
			my $shell_call =  "cat > $repo_file << EOF\n";
			   $shell_call .= "$repo\n";
			   $shell_call .= "EOF\n";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
			my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
				node		=>	$node,
				port		=>	22,
				user		=>	"root",
				password	=>	$password,
				ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
				'close'		=>	0,
				shell_call	=>	"$shell_call",
			});
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
			foreach my $line (@{$return})
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
			}
		}
		
		# Make sure the cache is up to date.
		my $shell_call = "yum clean expire-cache\n";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	22,
			user		=>	"root",
			password	=>	$password,
			ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
			'close'		=>	0,
			shell_call	=>	"$shell_call",
		});
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
		foreach my $line (@{$return})
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
		}
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
	$conf->{node}{$node1}{os_updated}    = 0;
	$conf->{node}{$node2}{os_updated}    = 0;
	my ($node1_rc) = update_node($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_rc) = update_node($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvi2_node1_current_password});
	# 0 = update attempted
	# 1 = OS updates disabled in manifest
	
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

# This calls the yum update and flags the node for a reboot if the kernel is
# updated.
sub update_node
{
	my ($conf, $node, $password) = @_;
	
	# Skip if the user has decided not to run OS updates.
	return(1) if not $conf->{sys}{update_os};
	
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	"yum -y update",
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
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

# This checks to see if perl is installed on the nodes and installs it if not.
sub verify_perl_is_installed
{
	my ($conf) = @_;
	
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

# This will check to see if perl is installed and, if it's not, it will try to
# install it.
sub verify_perl_is_installed_on_node
{
	my ($conf, $node, $password) = @_;
	
	# Set to '1' if perl was found, '0' if it wasn't found and couldn't be
	# installed, set to '2' if installed successfully.
	my $ok = 1;
	my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	"if [ -e '/usr/bin/perl' ]; 
					then
						echo striker:ok
					else
						yum -y install perl;
						if [ -e '/usr/bin/perl' ];
						then
							echo striker:installed
						else
							echo striker:failed
						fi
					fi",
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	
	foreach my $line (@{$return})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], ok: [$ok]\n");
	return($ok);
}

# This pings alteeve.ca to check for internet access.
sub verify_internet_access
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; verify_internet_access()\n");
	
	# If the user knows they will never be online, they may have set to
	# hide the Internet check. In this case, don't waste time checking.
	if (not $conf->{sys}{install_manifest}{show}{internet_check})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; User has disabled checking for an internet connection.\n");
		my $node1 = $conf->{cgi}{anvil_node1_current_ip};
		my $node2 = $conf->{cgi}{anvil_node2_current_ip};
		$conf->{node}{$node1}{internet} = 0;
		$conf->{node}{$node2}{internet} = 0;
		return(0);
	}
	
	my ($node1_online) = ping_website($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_online) = ping_website($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	
	# I need to remember if there is Internet access or not for later
	# downloads (web or switch to local).
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

# This pings as website to check for an internet connection. Will clean up
# routes that conflict with the default one as well.
sub ping_website
{
	my ($conf, $node, $password) = @_;
	
	# After installing, sometimes/often the system will come up with
	# multiple interfaces on the same subnet, causing default route
	# problems. So the first thing to do is look for the interface the IP
	# we're using to connect is on, see it's subnet and see if anything
	# else is on the same subnet. If so, delete the other interface(s) from
	# the route table.
	my $dg_device  = "";
	my $shell_call = "route -n";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/ /g;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << return line: [$line]\n");
		if ($line =~ /UG/)
		{
			$dg_device = ($line =~ /.* (.*?)$/)[0];
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; dg_device: [$dg_device]\n");
		}
		elsif ($line =~ /^(\d+\.\d+\.\d+\.\d+) .*? (\d+\.\d+\.\d+\.\d+) .*? \d+ \d+ \d+ (.*?)$/)
		{
			my $network   = $1;
			my $netmask   = $2;
			my $interface = $3;
			$conf->{conf}{node}{$node}{routes}{interface}{$interface} = "$network/$netmask";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; conf::node::${node}::routes::interface::${interface}: [$conf->{conf}{node}{$node}{routes}{interface}{$interface}]\n");
		}
	}
	
	# Now look for offending devices 
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Checking for conflicting routes.\n");
	my ($dg_network, $dg_netmask) = ($conf->{conf}{node}{$node}{routes}{interface}{$dg_device} =~ /^(\d+\.\d+\.\d+\.\d+)\/(\d+\.\d+\.\d+\.\d+)/);
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Default gateway is; dg_device: [$dg_device], network: [$dg_network/$dg_netmask]\n");
	foreach my $interface (sort {$a cmp $b} keys %{$conf->{conf}{node}{$node}{routes}{interface}})
	{
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; interface: [$interface], dg_device: [$dg_device]\n");
		next if $interface eq $dg_device;
		my ($network, $netmask) = ($conf->{conf}{node}{$node}{routes}{interface}{$interface} =~ /^(\d+\.\d+\.\d+\.\d+)\/(\d+\.\d+\.\d+\.\d+)/);
		if (($dg_network eq $network) && ($dg_netmask eq $netmask))
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Conflicting route! interface: [$interface], network: [$network/$netmask]\n");
			my $shell_call = "route del -net $network netmask $netmask dev $interface; echo rc:\$?";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
			$conf->{node}{$node}{internet} = 0;
			foreach my $line (@{$return})
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> return line: [$line]\n");
				if ($line =~ /^rc:(\d+)/)
				{
					my $rc = $1;
					if ($rc eq "0")
					{
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Conflicting route was deleted successfully.\n");
					}
					else
					{
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Conflicting route was NOT deleted; Expected rc '0' but got: [$rc]. Internet access may be flaky\n");
					}
				}
			}
		}
		else
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Route is OK, it is for another network.\n");
		}
	}
	
	### TODO: If a node has two interfaces up on the same subnet, determine
	###       which matches the one we're coming in on and down the 
	###       other(s).
	# Ya, I know 8.8.8.8 isn't a website...
	my $ok         = 0;
	   $shell_call = "ping 8.8.8.8 -c 3 -q";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
		node		=>	$node,
		port		=>	22,
		user		=>	"root",
		password	=>	$password,
		ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
		'close'		=>	0,
		shell_call	=>	$shell_call,
	});
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
	$conf->{node}{$node}{internet} = 0;
	foreach my $line (@{$return})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
		if ($line =~ /(\d+) packets transmitted, (\d+) received/)
		{
			my $pings_sent     = $1;
			my $pings_received = $2;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], pings_sent: [$pings_sent], pings_received: [$pings_received]\n");
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

# This calculates the sizes of the partitions to create, or selects the size
# based on existing partitions if found.
sub calculate_storage_pool_sizes
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; calculate_storage_pool_sizes();\n");
	
	# These will be set to the lower of the two nodes.
	my $node1      = $conf->{cgi}{anvil_node1_current_ip};
	my $node2      = $conf->{cgi}{anvil_node2_current_ip};
	my $pool1_size = "";
	my $pool2_size = "";
	
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node1}::pool1::existing_size: [$conf->{node}{$node1}{pool1}{existing_size}], node::${node2}::pool1::existing_size: [$conf->{node}{$node2}{pool1}{existing_size}]\n");
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
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_size: [$pool1_size]\n");
			}
			else
			{
				# Nothing we can do but warn the user.
				$pool1_size = $conf->{node}{$node1}{pool1}{existing_size};
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_size: [$pool1_size]\n");
				if ($conf->{node}{$node1}{pool1}{existing_size} < $conf->{node}{$node2}{pool1}{existing_size})
				{
					$pool1_size = $conf->{node}{$node2}{pool1}{existing_size};
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_size: [$pool1_size]\n");
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
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_size: [$pool1_size]\n");
		}
		elsif ($conf->{node}{$node2}{pool1}{existing_size})
		{
			# Node 1 isn't partitioned yet but node 2 is.
			$pool1_size                                 = $conf->{node}{$node2}{pool1}{existing_size};
			$conf->{cgi}{anvil_storage_pool1_byte_size} = $conf->{node}{$node2}{pool1}{existing_size};
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_size: [$pool1_size]\n");
		}
		
		$conf->{cgi}{anvil_storage_pool1_byte_size} = $pool1_size;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_storage_pool1_byte_size: [$conf->{cgi}{anvil_storage_pool1_byte_size}]\n");
	}
	else
	{
		$pool1_size = "calculate";
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_size: [$pool1_size]\n");
	}
	
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node1}::pool2::existing_size: [$conf->{node}{$node1}{pool2}{existing_size}], node::${node2}::pool2::existing_size: [$conf->{node}{$node2}{pool2}{existing_size}]\n");
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
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool2_size: [$pool2_size]\n");
			}
			else
			{
				# Nothing we can do but warn the user.
				$pool2_size = $conf->{node}{$node1}{pool2}{existing_size};
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool2_size: [$pool2_size]\n");
				if ($conf->{node}{$node1}{pool2}{existing_size} < $conf->{node}{$node2}{pool2}{existing_size})
				{
					$pool2_size = $conf->{node}{$node2}{pool2}{existing_size};
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool2_size: [$pool2_size]\n");
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
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool2_size: [$pool2_size]\n");
		}
		elsif ($conf->{node}{$node2}{pool2}{existing_size})
		{
			# Node 1 isn't partitioned yet but node 2 is.
			$pool2_size                                 = $conf->{node}{$node2}{pool2}{existing_size};
			$conf->{cgi}{anvil_storage_pool2_byte_size} = $conf->{node}{$node2}{pool2}{existing_size};
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool2_size: [$pool2_size]\n");
		}
		
		$conf->{cgi}{anvil_storage_pool2_byte_size} = $pool2_size;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_storage_pool2_byte_size: [$conf->{cgi}{anvil_storage_pool2_byte_size}]\n");
	}
	else
	{
		$pool2_size = "calculate";
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool2_size: [$pool2_size]\n");
	}
	
	# These are my minimums. I'll use these below for final sanity checks.
	my $media_library_size      = $conf->{cgi}{anvil_media_library_size};
	my $media_library_unit      = $conf->{cgi}{anvil_media_library_unit};
	my $media_library_byte_size = AN::Cluster::hr_to_bytes($conf, $media_library_size, $media_library_unit, 1);
	my $minimum_space_needed    = $media_library_byte_size;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; media_library_byte_size: [$media_library_byte_size], minimum_space_needed: [$minimum_space_needed]\n");
	
	my $minimum_pool_size  = AN::Cluster::hr_to_bytes($conf, 8, "GiB", 1);
	my $pool1_minimum_size = $minimum_space_needed + $minimum_pool_size;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; minimum_pool_size: [$minimum_pool_size], pool1_minimum_size: [$pool1_minimum_size]\n");
	
	# Knowing the smallest This will be useful in a few places.
	my $node1_disk = $conf->{node}{$node1}{pool1}{disk};
	my $node2_disk = $conf->{node}{$node2}{pool1}{disk};
	
	my $smallest_free_size = $conf->{node}{$node1}{disk}{$node1_disk}{free_space}{size};
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; smallest_free_size: [$smallest_free_size]\n");
	if ($conf->{node}{$node1}{disk}{$node1_disk}{free_space}{size} > $conf->{node}{$node2}{disk}{$node2_disk}{free_space}{size})
	{
		$smallest_free_size = $conf->{node}{$node2}{disk}{$node2_disk}{free_space}{size};
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; smallest_free_size: [$smallest_free_size]\n");
	}
	
	# If both are "calculate", do so. If only one is "calculate", use the
	# available free size.
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_size: [$pool1_size], pool2_size: [$pool2_size]\n");
	if (($pool1_size eq "calculate") || ($pool2_size eq "calculate"))
	{
		# At least one of them is calculate.
		if (($pool1_size eq "calculate") && ($pool2_size eq "calculate"))
		{
			my $pool1_byte_size  = 0;
			my $pool2_byte_size  = 0;
			my $total_free_space = $smallest_free_size;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; total_free_space: [$total_free_space (".AN::Cluster::bytes_to_hr($conf, $total_free_space).")]\n");
			
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
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; All to pool 1; pool1_size: [$pool1_size (".AN::Cluster::bytes_to_hr($conf, $pool1_size).")]\n");
			}
			else
			{
				# OK, so we actually need two pools.
				my $storage_pool1_byte_size = 0;
				my $storage_pool2_byte_size = 0;
				if ($storage_pool1_unit eq "%")
				{
					# Percentage, make sure there is at least 16 GiB free (8 GiB
					# for each pool)
					$minimum_space_needed += ($minimum_pool_size * 2);
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; minimum_space_needed: [$minimum_space_needed (".AN::Cluster::bytes_to_hr($conf, $minimum_space_needed).")]\n");
					
					# If the new minimum is too big, dump pool 2.
					if ($minimum_space_needed > $smallest_free_size)
					{
						$pool1_size = $smallest_free_size;
						$pool2_size = 0;
						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_size: [$pool1_size (".AN::Cluster::bytes_to_hr($conf, $pool1_size).")]\n");
					}
				}
				else
				{
					$storage_pool1_byte_size =  AN::Cluster::hr_to_bytes($conf, $storage_pool1_size, $storage_pool1_unit, 1);
					$minimum_space_needed    += $storage_pool1_byte_size;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; storage_pool1_byte_size: [$storage_pool1_byte_size (".AN::Cluster::bytes_to_hr($conf, $storage_pool1_byte_size).")], minimum_space_needed: [$minimum_space_needed (".AN::Cluster::bytes_to_hr($conf, $minimum_space_needed).")]\n");
				}

				# Things are good, so calculate the static sizes of our pool
				# for display in the summary/confirmation later.
				# Make sure the storage pool is an even MiB.
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; media_library_byte_size: [$media_library_byte_size (".AN::Cluster::bytes_to_hr($conf, $media_library_byte_size).")]\n");
				my $media_library_difference = $media_library_byte_size % 1048576;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; media_library_difference: [$media_library_difference (".AN::Cluster::bytes_to_hr($conf, $media_library_difference).")]\n");
				if ($media_library_difference)
				{
					# Round up
					my $media_library_balance   =  1048576 - $media_library_difference;
					   $media_library_byte_size += $media_library_balance;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; media_library_byte_size: [$media_library_byte_size (".AN::Cluster::bytes_to_hr($conf, $media_library_byte_size).")], media_library_balance: [$media_library_balance (".AN::Cluster::bytes_to_hr($conf, $media_library_balance).")]\n");
				}
				$conf->{cgi}{anvil_media_library_byte_size} = $media_library_byte_size;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_media_library_byte_size: [$conf->{cgi}{anvil_media_library_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_media_library_byte_size}).")]\n");
				
				my $free_space_left = $total_free_space - $media_library_byte_size;
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; free_space_left: [$free_space_left (".AN::Cluster::bytes_to_hr($conf, $free_space_left).")]\n");
				
				# If the user has asked for a percentage, divide the free space
				# by the percentage.
				if ($storage_pool1_unit eq "%")
				{
					my $percent = $storage_pool1_size / 100;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; percent: [$percent ($storage_pool1_size $storage_pool1_unit)]\n");
					
					# Round up to the closest even MiB
					$pool1_byte_size = $percent * $free_space_left;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> pool1_byte_size: [$pool1_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool1_byte_size).")]\n");
					my $pool1_difference = $pool1_byte_size % 1048576;
					if ($pool1_difference)
					{
						# Round up
						AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_difference: [$pool1_difference (".AN::Cluster::bytes_to_hr($conf, $pool1_difference).")]\n");
						my $pool1_balance   =  1048576 - $pool1_difference;
						   $pool1_byte_size += $pool1_balance;
					}
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << pool1_byte_size: [$pool1_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool1_byte_size).")]\n");
					
					# Round down to the closest even MiB (left over space
					# will be unallocated on disk)
					my $pool2_byte_size = $free_space_left - $pool1_byte_size;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> pool2_byte_size: [$pool2_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool2_byte_size).")]\n");
					if ($pool2_byte_size < 0)
					{
						# Well then...
						$pool2_byte_size = 0;
					}
					else
					{
						my $pool2_difference = $pool2_byte_size % 1048576;
						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool2_difference: [$pool1_difference (".AN::Cluster::bytes_to_hr($conf, $pool1_difference).")]\n");
						if ($pool2_difference)
						{
							# Round down
							$pool2_byte_size -= $pool2_difference;
						}
					}
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << pool2_byte_size: [$pool2_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool2_byte_size).")]\n");
					
					# Final sanity check; Add up the three calculated sizes
					# and make sure I'm not trying to ask for more space
					# than is available.
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; media_library_byte_size: [$media_library_byte_size (".AN::Cluster::bytes_to_hr($conf, $media_library_byte_size).")] + pool1_byte_size: [$pool1_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool1_byte_size).")] + pool2_byte_size: [$pool2_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool2_byte_size).")]\n");
					my $total_allocated = ($media_library_byte_size + $pool1_byte_size + $pool2_byte_size);
					
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; total_allocated: [$total_allocated (".AN::Cluster::bytes_to_hr($conf, $total_allocated).")], total_free_space: [$total_free_space (".AN::Cluster::bytes_to_hr($conf, $total_free_space).")]\n");
					if ($total_allocated > $total_free_space)
					{
						my $too_much = $total_allocated - $total_free_space;
						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; too_much: [$too_much]\n");
						
						# Take the overage from pool 2, if used.
						if ($pool2_byte_size > $too_much)
						{
							# Reduce!
							$pool2_byte_size -= $too_much;
							#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> pool2_byte_size: [$pool2_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool2_byte_size).")]\n");
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
							#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << pool2_byte_size: [$pool2_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool2_byte_size).")]\n");
						}
						else
						{
							# Take the pound of flesh from pool 1
							$pool1_byte_size -= $too_much;
							#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> pool1_byte_size: [$pool1_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool1_byte_size).")]\n");
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
							#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << pool1_byte_size: [$pool1_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool1_byte_size).")]\n");
						}
						
						# Check again.
						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; media_library_byte_size: [$media_library_byte_size (".AN::Cluster::bytes_to_hr($conf, $media_library_byte_size).")] + pool1_byte_size: [$pool1_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool1_byte_size).")] + pool2_byte_size: [$pool2_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool2_byte_size).")]\n");
						$total_allocated = ($media_library_byte_size + $pool1_byte_size + $pool2_byte_size);
						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; total_allocated: [$total_allocated (".AN::Cluster::bytes_to_hr($conf, $total_allocated).")], total_free_space: [$total_free_space (".AN::Cluster::bytes_to_hr($conf, $total_free_space).")]\n");
						if ($total_allocated > $total_free_space)
						{
							# OK, WTF?
							#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to divide free space!\n");
						}
					}
					
					# Old
					$conf->{cgi}{anvil_storage_pool1_byte_size} = $pool1_byte_size + $media_library_byte_size;
					$conf->{cgi}{anvil_storage_pool2_byte_size} = $pool2_byte_size;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_storage_pool1_byte_size: [$conf->{cgi}{anvil_storage_pool1_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}).")], cgi::anvil_storage_pool2_byte_size: [$conf->{cgi}{anvil_storage_pool2_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}).")]\n");
					
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_byte_size: [$pool1_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool1_byte_size).")], pool2_byte_size: [$pool2_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool2_byte_size).")]\n");
					$pool1_size = $pool1_byte_size + $media_library_byte_size;
					$pool2_size = $pool2_byte_size;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_size: [$pool1_size (".AN::Cluster::bytes_to_hr($conf, $pool1_size).")], pool2_size: [$pool2_size (".AN::Cluster::bytes_to_hr($conf, $pool2_size).")]\n");
				}
				else
				{
					# Pool 1 is static, so simply round to an even MiB.
					$pool1_byte_size = $storage_pool1_byte_size;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> pool1_byte_size: [$pool1_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool1_byte_size).")]\n");
					
					# If pool1's requested size is larger
					# than is available, shrink it.
					if ($pool1_byte_size > $free_space_left)
					{
						# Round down a meg, as the next
						# stage will round up a bit if
						# needed.
						$pool1_byte_size = ($free_space_left - 1048576);
						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Requested pool 1 size was too big! Shrinking to; pool1_byte_size: [$pool1_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool1_byte_size).")]\n");
						$conf->{sys}{pool1_shrunk} = 1;
					}
						
					my $pool1_difference = $pool1_byte_size % 1048576;
					if ($pool1_difference)
					{
						# Round up
						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_difference: [$pool1_difference (".AN::Cluster::bytes_to_hr($conf, $pool1_difference).")]\n");
						my $pool1_balance   =  1048576 - $pool1_difference;
						   $pool1_byte_size += $pool1_balance;
					}
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << pool1_byte_size: [$pool1_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool1_byte_size).")]\n");
					
					$pool2_byte_size = $free_space_left - $pool1_byte_size;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> pool2_byte_size: [$pool2_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool2_byte_size).")]\n");
					if ($pool2_byte_size < 0)
					{
						# Well then...
						$pool2_byte_size = 0;
					}
					else
					{
						my $pool2_difference = $pool2_byte_size % 1048576;
						#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool2_difference: [$pool1_difference (".AN::Cluster::bytes_to_hr($conf, $pool1_difference).")]\n");
						if ($pool2_difference)
						{
							# Round down
							$pool2_byte_size -= $pool2_difference;
						}
					}
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << pool2_byte_size: [$pool2_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool2_byte_size).")]\n");
					
					$conf->{cgi}{anvil_storage_pool1_byte_size} = $pool1_byte_size + $media_library_byte_size;
					$conf->{cgi}{anvil_storage_pool2_byte_size} = $pool2_byte_size;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_storage_pool1_byte_size: [$conf->{cgi}{anvil_storage_pool1_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}).")], cgi::anvil_storage_pool2_byte_size: [$conf->{cgi}{anvil_storage_pool2_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}).")]\n");
					
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_byte_size: [$pool1_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool1_byte_size).")], pool2_byte_size: [$pool2_byte_size (".AN::Cluster::bytes_to_hr($conf, $pool2_byte_size).")]\n");
					$pool1_size = $pool1_byte_size + $media_library_byte_size;
					$pool2_size = $pool2_byte_size;
					#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_size: [$pool1_size (".AN::Cluster::bytes_to_hr($conf, $pool1_size).")], pool2_size: [$pool2_size (".AN::Cluster::bytes_to_hr($conf, $pool2_size).")]\n");
				}
				#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_media_library_byte_size: [$conf->{cgi}{anvil_media_library_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_media_library_byte_size}).")]\n");
			}
		}
		elsif ($pool1_size eq "calculate")
		{
			# OK, Pool 1 is calculate, just use all the free space
			# (or the lower of the two if they don't match.
			$pool1_size = $smallest_free_size;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool1_size: [$pool1_size (".AN::Cluster::bytes_to_hr($conf, $pool1_size).")]\n");
		}
		elsif ($pool2_size eq "calculate")
		{
			# OK, Pool 1 is calculate, just use all the free space
			# (or the lower of the two if they don't match.
			$pool2_size = $smallest_free_size;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; pool2_size: [$pool2_size (".AN::Cluster::bytes_to_hr($conf, $pool2_size).")]\n");
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_storage_pool1_byte_size: [$conf->{cgi}{anvil_storage_pool1_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool1_byte_size}).")], cgi::anvil_storage_pool2_byte_size: [$conf->{cgi}{anvil_storage_pool2_byte_size} (".AN::Cluster::bytes_to_hr($conf, $conf->{cgi}{anvil_storage_pool2_byte_size}).")]\n");
	return(0);
}

# This checks to see if both nodes have the same amount of unallocated space.
sub check_storage
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; check_storage()\n");
	
	### TODO: When the drive is partitioned, write a file out indicating
	###       which partitions we created so that we don't error out for
	###       lack of free space on re-runs on the program.
	
	my $ok = 1;
	my ($node1_disk) = get_partition_data($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_disk) = get_partition_data($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_disk: [$node1_disk], node2_disk: [$node2_disk]\n");
	
	# How much space do I have?
	my $node1           = $conf->{cgi}{anvil_node1_current_ip};
	my $node2           = $conf->{cgi}{anvil_node2_current_ip};
	my $node1_disk_size = $conf->{node}{$node1}{disk}{$node1_disk}{size};
	my $node2_disk_size = $conf->{node}{$node2}{disk}{$node2_disk}{size};
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1: [$node1], node2: [$node2], node1_disk_size: [$node1_disk_size], node2_disk_size: [$node2_disk_size]\n");
	
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cgi::anvil_storage_pool1_byte_size: [$conf->{cgi}{anvil_storage_pool1_byte_size}], cgi::anvil_storage_pool2_byte_size: [$conf->{cgi}{anvil_storage_pool2_byte_size}]\n");
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

# This determines which partitions to use for storage pool 1 and 2. Existing
# partitions override anything else for determining sizes.
sub get_storage_pool_partitions
{
	my ($conf) = @_;
	
	### TODO: Determine if I still need this function at all...
	# First up, check for /etc/drbd.d/r{0,1}.res on both nodes.
	my ($node1_r0_device, $node1_r1_device) = read_drbd_resource_files($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password}, $conf->{cgi}{anvil_node1_name});
	my ($node2_r0_device, $node2_r1_device) = read_drbd_resource_files($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password}, $conf->{cgi}{anvil_node2_name});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_r0_device: [$node1_r0_device], node1_r1_device: [$node1_r1_device], node2_r0_device: [$node2_r0_device], node2_r1_device: [$node2_r1_device]\n");
	
	# Next, decide what devices I will use if DRBD doesn't exist.
	foreach my $node ($conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node2_current_ip})
	{
		# If the disk to use is 'Xda', skip the first three partitions
		# as they will be for the OS.
		my $disk = $conf->{node}{$node}{biggest_disk};
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node]: disk: [$disk]\n");
		
		# Default to logical partitions.
		my $create_extended_partition = 0;
		my $pool1_partition           = 4;
		my $pool2_partition           = 5;
		if ($disk =~ /da$/)
		{
			# I need to know the label type to determine the 
			# partition numbers to use:
			# * If it's 'msdos', I need an extended partition and
			#   then two logical partitions. (4, 5 and 6)
			# * If it's 'gpt', I just use two logical partition.
			#   (4 and 5).
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node}::disk::${disk}::label: [$conf->{node}{$node}{disk}{$disk}{label}]\n");
			if ($conf->{node}{$node}{disk}{$disk}{label} eq "msdos")
			{
				$create_extended_partition = 1;
				$pool1_partition           = 5;
				$pool2_partition           = 6;
			}
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; create_extended_partition: [$create_extended_partition], pool1_partition: [$pool1_partition], pool2_partition: [$pool2_partition]\n");
		}
		else
		{
			# I'll use the full disk, so the partition numbers will
			# be the same regardless of the 
			$create_extended_partition = 0;
			$pool1_partition           = 1;
			$pool2_partition           = 2;
		}
		$conf->{node}{$node}{pool1}{create_extended} = $create_extended_partition;
		$conf->{node}{$node}{pool1}{device}          = "/dev/${disk}${pool1_partition}";
		$conf->{node}{$node}{pool2}{device}          = "/dev/${disk}${pool2_partition}";
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], node::${node}::pool1::device: [$conf->{node}{$node}{pool1}{device}], node::${node}::pool2::device: [$conf->{node}{$node}{pool2}{device}]\n");
	}
	
	# OK, if we found a device in DRBD, override the values from the loop.
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	
	$conf->{node}{$node1}{pool1}{device} = $node1_r0_device ? $node1_r0_device : $conf->{node}{$node1}{pool1}{device};
	$conf->{node}{$node1}{pool2}{device} = $node1_r1_device ? $node1_r1_device : $conf->{node}{$node1}{pool2}{device};
	$conf->{node}{$node2}{pool1}{device} = $node2_r0_device ? $node2_r0_device : $conf->{node}{$node2}{pool1}{device};
	$conf->{node}{$node2}{pool2}{device} = $node2_r1_device ? $node2_r1_device : $conf->{node}{$node2}{pool2}{device};
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node1}::pool1::device: [$conf->{node}{$node1}{pool1}{device}], node::${node1}::pool2::device: [$conf->{node}{$node1}{pool2}{device}], node::${node2}::pool1::device: [$conf->{node}{$node2}{pool1}{device}], node::${node2}::pool2::device: [$conf->{node}{$node2}{pool2}{device}]\n");
	
	# Now, if either partition exists on either node, use that size to
	# force the other node's size.
	my ($node1_pool1_disk, $node1_pool1_partition) = ($conf->{node}{$node1}{pool1}{device} =~ /\/dev\/(.*?)(\d)/);
	my ($node1_pool2_disk, $node1_pool2_partition) = ($conf->{node}{$node1}{pool2}{device} =~ /\/dev\/(.*?)(\d)/);
	my ($node2_pool1_disk, $node2_pool1_partition) = ($conf->{node}{$node2}{pool1}{device} =~ /\/dev\/(.*?)(\d)/);
	my ($node2_pool2_disk, $node2_pool2_partition) = ($conf->{node}{$node2}{pool2}{device} =~ /\/dev\/(.*?)(\d)/);
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_pool1_disk: [$node1_pool1_disk], node1_pool1_partition: [$node1_pool1_partition], node1_pool2_disk: [$node1_pool2_disk], node1_pool2_partition: [$node1_pool2_partition], node2_pool1_dis: [$node2_pool1_disk], node2_pool1_partition: [$node2_pool1_partition], node2_pool2_disk: [$node2_pool2_disk], node2_pool2_partition: [$node2_pool2_partition]\n");
	
	$conf->{node}{$node1}{pool1}{disk}      = $node1_pool1_disk;
	$conf->{node}{$node1}{pool1}{partition} = $node1_pool1_partition;
	$conf->{node}{$node1}{pool2}{disk}      = $node1_pool2_disk;
	$conf->{node}{$node1}{pool2}{partition} = $node1_pool2_partition;
	$conf->{node}{$node2}{pool1}{disk}      = $node2_pool1_disk;
	$conf->{node}{$node2}{pool1}{partition} = $node2_pool1_partition;
	$conf->{node}{$node2}{pool2}{disk}      = $node2_pool2_disk;
	$conf->{node}{$node2}{pool2}{partition} = $node2_pool2_partition;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node1}::pool1::disk: [$conf->{node}{$node1}{pool1}{disk}], node::${node1}::pool1::partition: [$conf->{node}{$node1}{pool1}{partition}], node::${node1}::pool2::disk: [$conf->{node}{$node1}{pool2}{disk}], node::${node1}::pool2::partition: [$conf->{node}{$node1}{pool2}{partition}], node::${node2}::pool1::disk: [$conf->{node}{$node2}{pool1}{disk}], node::${node2}::pool1::partition: [$conf->{node}{$node2}{pool1}{partition}], node::${node2}::pool2::disk: [$conf->{node}{$node2}{pool2}{disk}], node::${node2}::pool2::partition: [$conf->{node}{$node2}{pool2}{partition}]\n");
	
	$conf->{node}{$node1}{pool1}{existing_size} = $conf->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{$node1_pool1_partition}{size} ? $conf->{node}{$node1}{disk}{$node1_pool1_disk}{partition}{$node1_pool1_partition}{size} : 0;
	$conf->{node}{$node1}{pool2}{existing_size} = $conf->{node}{$node1}{disk}{$node1_pool2_disk}{partition}{$node1_pool2_partition}{size} ? $conf->{node}{$node1}{disk}{$node1_pool2_disk}{partition}{$node1_pool2_partition}{size} : 0;
	$conf->{node}{$node2}{pool1}{existing_size} = $conf->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{$node2_pool1_partition}{size} ? $conf->{node}{$node2}{disk}{$node2_pool1_disk}{partition}{$node2_pool1_partition}{size} : 0;
	$conf->{node}{$node2}{pool2}{existing_size} = $conf->{node}{$node2}{disk}{$node2_pool2_disk}{partition}{$node2_pool2_partition}{size} ? $conf->{node}{$node2}{disk}{$node2_pool2_disk}{partition}{$node2_pool2_partition}{size} : 0;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node1}::pool1::existing_size: [$conf->{node}{$node1}{pool1}{existing_size}], node::${node1}::pool2::existing_size: [$conf->{node}{$node1}{pool2}{existing_size}], node::${node2}::pool1::existing_size: [$conf->{node}{$node2}{pool1}{existing_size}], node::${node2}::pool2::existing_size: [$conf->{node}{$node2}{pool2}{existing_size}]\n");
	
	return(0);
}

# This looks for the two DRBD resource files and, if found, pulls the
# partitions to use out of them.
sub read_drbd_resource_files
{
	my ($conf, $node, $password, $hostname) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; read_drbd_resource_files(); node: [$node], hostname: [$hostname]\n");
	
	my $r0_device = "";
	my $r1_device = "";
	foreach my $file ($conf->{path}{nodes}{drbd_r0}, $conf->{path}{nodes}{drbd_r1})
	{
		# Skip if no pool1
		if (($conf->{path}{nodes}{drbd_r1}) && (not $conf->{cgi}{anvil_storage_pool2_byte_size}))
		{
			next;
		}
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; file: [$file]\n");
		my $shell_call = "
if [ -e '$file' ];
then
	cat $file;
else
	echo \"not found\"
fi";
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
		my ($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
			node		=>	$node,
			port		=>	22,
			user		=>	"root",
			password	=>	$password,
			ssh_fh		=>	$conf->{node}{$node}{ssh_fh} ? $conf->{node}{$node}{ssh_fh} : "",
			'close'		=>	0,
			shell_call	=>	$shell_call,
		});
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; error: [$error], ssh_fh: [$ssh_fh], return: [$return (".@{$return}." lines)]\n");
		my $in_host = 0;
		foreach my $line (@{$return})
		{
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
			if ($line eq "not found")
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], file: [$file] not found.\n");
			}
			if ($line =~ /on $hostname {/)
			{
				$in_host = 1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in host\n");
			}
			if (($in_host) && ($line =~ /disk\s+(\/dev\/.*?);/))
			{
				my $device = $1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; device: [$device]\n");
				if ($file =~ /r0/)
				{
					$r0_device = $device;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; r0_device: [$r0_device]\n");
				}
				else
				{
					$r1_device = $device;
					AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; r1_device: [$r1_device]\n");
				}
				last;
			}
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; r0_device: [$r0_device], r1_device: [$r1_device]\n");
	return($r0_device, $r1_device);
}

# This checks for free space on the target node.
sub get_partition_data
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; get_partition_data(); node: [$node]\n");
	
	my $device = "";
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
	my $name = "";
	my $type = "";
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], name: [$name], type: [$type]\n");
		
		push @disks, $name;
	}
	
	# Get the details on each disk now.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], Found: [".@disks."] disks.\n");
	foreach my $disk (@disks)
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk]\n");
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], shell_call: [$shell_call]\n");
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
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> node: [$node], disk: [$disk], line: [$line]\n");
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			$line =~ s/\s+/ /g;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << node: [$node], disk: [$disk], line: [$line]\n");
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
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], Installed 'parted' RPM.\n");
			}
			elsif ($line =~ /Disk \/dev\/$disk: (\d+)B/)
			{
				$conf->{node}{$node}{disk}{$disk}{size} = $1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node}::disk::${disk}::size: [$conf->{node}{$node}{disk}{$disk}{size}]\n");
			}
			elsif ($line =~ /Partition Table: (.*)/)
			{
				$conf->{node}{$node}{disk}{$disk}{label} = $1;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node::${node}::disk::${disk}::label: [$conf->{node}{$node}{disk}{$disk}{label}]\n");
			}
			#              part  start end   size  type  - don't care about the rest.
			elsif ($line =~ /^(\d+) (\d+)B (\d+)B (\d+)B (.*)$/)
			{
				# Existing partitions
				my $partition = $1;
				my $partition_start =  $2;
				my $partition_end   =  $3;
				my $partition_size  =  $4;
				my $partition_type  =  $5;
				   $partition_type  =~ s/\s.*$//;	# cuts off 'extended lba' to 'extended'
				$conf->{node}{$node}{disk}{$disk}{partition}{$partition}{start} = $partition_start;
				$conf->{node}{$node}{disk}{$disk}{partition}{$partition}{end}   = $partition_end;
				$conf->{node}{$node}{disk}{$disk}{partition}{$partition}{size}  = $partition_size;
				$conf->{node}{$node}{disk}{$disk}{partition}{$partition}{type}  = $partition_type;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], partition: [$partition], start: [$conf->{node}{$node}{disk}{$disk}{partition}{$partition}{start} (".AN::Cluster::bytes_to_hr($conf, $conf->{node}{$node}{disk}{$disk}{partition}{$partition}{start}).")], end: [$conf->{node}{$node}{disk}{$disk}{partition}{$partition}{end} (".AN::Cluster::bytes_to_hr($conf, $conf->{node}{$node}{disk}{$disk}{partition}{$partition}{end}).")], size: [$conf->{node}{$node}{disk}{$disk}{partition}{$partition}{size} (".AN::Cluster::bytes_to_hr($conf, $conf->{node}{$node}{disk}{$disk}{partition}{$partition}{size}).")], type: [$conf->{node}{$node}{disk}{$disk}{partition}{$partition}{type}]\n");
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
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], disk: [$disk], free space; start: [$conf->{node}{$node}{disk}{$disk}{free_space}{start} (".AN::Cluster::bytes_to_hr($conf, $conf->{node}{$node}{disk}{$disk}{free_space}{start}).")], end: [$conf->{node}{$node}{disk}{$disk}{free_space}{end} (".AN::Cluster::bytes_to_hr($conf, $conf->{node}{$node}{disk}{$disk}{free_space}{end}).")], size: [$conf->{node}{$node}{disk}{$disk}{free_space}{size} (".AN::Cluster::bytes_to_hr($conf, $conf->{node}{$node}{disk}{$disk}{free_space}{size}).")]\n");
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
			$biggest_disk = $disk;
			$biggest_size = $size;
			$conf->{node}{$node}{biggest_disk} = $biggest_disk;
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], biggest_disk: [$biggest_disk]\n");
	return($biggest_disk);
}

# This generates the default 'cluster.conf' file.
sub generate_cluster_conf
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; generate_cluster_conf();\n");
	
	my ($node1_short_name) = ($conf->{cgi}{anvil_node1_name} =~ /^(.*?)\./);
	my  $node1_full_name   =  $conf->{cgi}{anvil_node1_name};
	my ($node2_short_name) = ($conf->{cgi}{anvil_node2_name} =~ /^(.*?)\./);
	my  $node2_full_name   =  $conf->{cgi}{anvil_node2_name};
	my  $shared_lv         = "/dev/${node1_short_name}_vg0/shared";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_short_name: [$node1_short_name], node1_full_name: [$node1_full_name], node2_short_name: [$node2_short_name], node2_full_name: [$node2_full_name], shared_lv: [$shared_lv]\n");
	
	$conf->{sys}{cluster_conf} = "<?xml version=\"1.0\"?>
<cluster name=\"$conf->{cgi}{anvil_name}\" config_version=\"1\">
	<cman expected_votes=\"1\" two_node=\"1\" />
	<clusternodes>
		<clusternode name=\"$conf->{cgi}{anvil_node1_name}\" nodeid=\"1\">
			<fence>\n";
	# Fence methods for node 1
	foreach my $i (sort {$a cmp $b} keys %{$conf->{fence}{node}{$node1_full_name}{order}})
	{
		foreach my $method (keys %{$conf->{fence}{node}{$node1_full_name}{order}{$i}{method}})
		{
			$conf->{sys}{cluster_conf} .= "\t\t\t\t<method name=\"$method\">\n";
			foreach my $j (keys %{$conf->{fence}{node}{$node1_full_name}{order}{$i}{method}{$method}{device}})
			{
				$conf->{sys}{cluster_conf} .= "\t\t\t\t\t$conf->{fence}{node}{$node1_full_name}{order}{$i}{method}{$method}{device}{$j}{string}\n";
			}
			$conf->{sys}{cluster_conf} .= "\t\t\t\t</method>\n";
		}
	}
	$conf->{sys}{cluster_conf} .= "\t\t\t</fence>
		</clusternode>
		<clusternode name=\"$conf->{cgi}{anvil_node2_name}\" nodeid=\"2\">
			<fence>\n";
	# Fence methods for node 2
	foreach my $i (sort {$a cmp $b} keys %{$conf->{fence}{node}{$node2_full_name}{order}})
	{
		foreach my $method (keys %{$conf->{fence}{node}{$node2_full_name}{order}{$i}{method}})
		{
			$conf->{sys}{cluster_conf} .= "\t\t\t\t<method name=\"$method\">\n";
			foreach my $j (keys %{$conf->{fence}{node}{$node2_full_name}{order}{$i}{method}{$method}{device}})
			{
				$conf->{sys}{cluster_conf} .= "\t\t\t\t\t$conf->{fence}{node}{$node2_full_name}{order}{$i}{method}{$method}{device}{$j}{string}\n";
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
	<totem rrp_mode=\"none\" secauth=\"off\"/>
	<rm log_level=\"5\">
		<resources>
			<script file=\"/etc/init.d/drbd\" name=\"drbd\"/>
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
				<script ref=\"clvmd\">
					<clusterfs ref=\"sharedfs\"/>
				</script>
			</script>
		</service>
		<service name=\"storage_n02\" autostart=\"1\" domain=\"only_n02\" exclusive=\"0\" recovery=\"restart\">
			<script ref=\"drbd\">
				<script ref=\"clvmd\">
					<clusterfs ref=\"sharedfs\"/>
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sys::cluster_conf:\n====\n$conf->{sys}{cluster_conf}\n====\n");
	return(0);
}

# This checks to see if /etc/cluster/cluster.conf is available and aborts if
# so.
sub configure_cman
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; configure_cman()\n");
	
	# Generate a new cluster.conf, then check to see if one already exists.
	generate_cluster_conf($conf);
	my ($node1_cluster_conf_version) = read_cluster_conf($conf, $conf->{cgi}{anvil_node1_current_ip}, $conf->{cgi}{anvil_node1_current_password});
	my ($node2_cluster_conf_version) = read_cluster_conf($conf, $conf->{cgi}{anvil_node2_current_ip}, $conf->{cgi}{anvil_node2_current_password});
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1_cluster_conf_version: [$node1_cluster_conf_version], node2_cluster_conf_version: [$node2_cluster_conf_version]\n");
	
	# If one of the nodes has an existing cluster.conf, use it.
	my $node1 = $conf->{cgi}{anvil_node1_current_ip};
	my $node2 = $conf->{cgi}{anvil_node2_current_ip};
	my $ok    = 1;
	
	# This will set if a node's cluster.conf is (re)written or not.
	my $write_node1 = 0;
	my $write_node2 = 0;
	
	# If either node's cluster.conf in > 1, use it.
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Checking if there was an existing cluster.conf configured on either node.\n");
	if ($node1_cluster_conf_version > 1)
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node1's cluster.conf is version: [$node1_cluster_conf_version], checking is node2's matched: [$node2_cluster_conf_version]\n");
		if ($node1_cluster_conf_version eq $node2_cluster_conf_version)
		{
			# Both are the same and both are > 1, do nothing.
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; It does, no further action will be taken.\n");
		}
		elsif ($node1_cluster_conf_version > $node2_cluster_conf_version)
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; It doesn't but it is newer than node2, so using it.\n");
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Node 1's 'cluster.conf': ====\n$conf->{node}{$node1}{cluster_conf}\n====\n");
			$conf->{node}{$node2}{cluster_conf} = $conf->{node}{$node1}{cluster_conf};
			$write_node2                        = 1;
			#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Node 2's 'cluster.conf': ====\n$conf->{node}{$node2}{cluster_conf}\n====\n");
		}
		elsif ($node1_cluster_conf_version < $node2_cluster_conf_version)
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; It doesn't, and node2's version is higher, so using it instead.\n");
			$conf->{node}{$node1}{cluster_conf} = $conf->{node}{$node2}{cluster_conf};
			$write_node1                       = 1;
		}
	}
	elsif ($node2_cluster_conf_version > 1)
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Node 2's cluster.conf: [$node2_cluster_conf_version] is newer than node 1's: [$node1_cluster_conf_version], using it.\n");
		$conf->{node}{$node1}{cluster_conf} = $conf->{node}{$node2}{cluster_conf};
		$write_node1                        = 1;
	}
	elsif ((not $conf->{node}{$node1}{cluster_conf}) && (not $conf->{node}{$node2}{cluster_conf}))
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Neither node has an existing cluster.conf, using the default generated one.\n");
		$conf->{node}{$node1}{cluster_conf} = $conf->{sys}{cluster_conf};
		$conf->{node}{$node2}{cluster_conf} = $conf->{sys}{cluster_conf};
		$write_node1                        = 1;
		$write_node2                        = 1;
	}
	elsif ($conf->{node}{$node1}{cluster_conf})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Node 1 has a version 1 cluster.conf and node 2 has no cluster.conf at all, using node 1's version.\n");
		$conf->{node}{$node2}{cluster_conf} = $conf->{node}{$node1}{cluster_conf};
		$write_node2                        = 1;
	}
	elsif ($conf->{node}{$node2}{cluster_conf})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Node 2 has a version 1 cluster.conf and node 1 has no cluster.conf at all, using node 2's version.\n");
		$conf->{node}{$node1}{cluster_conf} = $conf->{node}{$node2}{cluster_conf};
		$write_node1                        = 1;
	}
	else
	{
		# wat
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; There was an unknown problem checking cluster.conf... No check condition was matched, and that should not be possible.\n");
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
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; ok: [$ok]\n");
	return($ok);
}

# This writes out the cluster configuration file
sub write_cluster_conf
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; write_cluster_conf(); node: [$node]\n");
	
	my $message     = "";
	my $return_code = 255;
	my $shell_call  =  "cat > $conf->{path}{nodes}{cluster_conf} << EOF\n";
	   $shell_call  .= "$conf->{node}{$node}{cluster_conf}\n";
	   $shell_call  .= "EOF\n";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: \n====\n$shell_call\n====\n");
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
	#foreach my $line (@{$return}) { AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n"); }
	
	# Now run 'ccs_config_validate' to ensure it is sane.
	$shell_call  = "ccs_config_validate; echo rc:\$?";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
	($error, $ssh_fh, $return) = AN::Cluster::remote_call($conf, {
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
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return: [$line]\n");
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
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return_code: [$return_code], message: [$message]\n");
	return($return_code, $message);
}

# This reads in /etc/cluster/cluster.conf and returns '0' if not found.
sub read_cluster_conf
{
	my ($conf, $node, $password) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; read_cluster_conf(); node: [$node]\n");
	
	# Later, this will use XML::Simple to parse the contents. For now, I
	# only care if the file exists at all.
	my $shell_call = "
if [ -e '$conf->{path}{nodes}{cluster_conf}' ]
then
	cat $conf->{path}{nodes}{cluster_conf}
else
	echo not found
fi";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; shell_call: [$shell_call]\n");
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
	
	$conf->{node}{$node}{cluster_conf_version} = 0;
	$conf->{node}{$node}{cluster_conf}         = "";
	foreach my $line (@{$return})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; return line: [$line]\n");
		last if $line eq "not found";
		$conf->{node}{$node}{cluster_conf} .= "$line\n";
		
		# If the version is > 1, we'll use it no matter what.
		if ($line =~ /config_version="(\d+)"/)
		{
			$conf->{node}{$node}{cluster_conf_version} = $1;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], cluster.conf version: [$conf->{node}{$node}{cluster_conf_version}]\n");
		}
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; cluster.conf version: [$conf->{node}{$node}{cluster_conf_version}]\n");
	return($conf->{node}{$node}{cluster_conf_version})
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
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is RHEL proper, checking to see if it has been registered already.\n");
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
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; node: [$node], is registered on RHN? [$conf->{node}{$node}{os}{registered}].\n");
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
		
		# Copy the tools the nodes will need into docroot and update
		# the URLs we will tell the nodes to download from.
		copy_tools_to_docroot($conf);
	}
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; access: [$access]\n");
	return($access);
}

# This gets this machine's BCN ip address
sub get_local_bcn_ip
{
	my ($conf) = @_;
	
	my $in_dev     = "";
	my $bcn_ip     = "";
	my $shell_call = "$conf->{path}{ip} addr";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sc: [$shell_call]\n");
	open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> line: [$line]\n");
		$line =~ s/\s+/ /;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << line: [$line]\n");
		if ($line =~ /^\d+: (.*?):/)
		{
			$in_dev = $1;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in_dev: [$in_dev]\n");
		}
		
		# No sense proceeding if I'm not in a device named 'bcn'.
		next if not $in_dev;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in_dev: [$in_dev]\n");
		next if $in_dev !~ /bcn/;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; still alive! line: [$line]\n");
		
		if ($line =~ /inet (\d+\.\d+\.\d+\.\d+)\/\d+ /)
		{
			$bcn_ip = $1;
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; in_dev: [$in_dev], bcn_ip: [$bcn_ip]\n");
			last;
		}
	}
	close $file_handle;
	
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; bcn_ip: [$bcn_ip]\n");
	return($bcn_ip);
}

### Deprecated; Everything should be copied to each node's /sbin/striker/ now.
# If one or both of the nodes failed to connect to the web, this function will
# move tools to our webserver's docroot and then update paths to find the tools
# here. The paths will use the BCN for download.
sub copy_tools_to_docroot
{
	my ($conf) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; copy_tools_to_docroot()\n");
	
	my $docroot         = $conf->{path}{docroot};
	my $tools_directory = $conf->{path}{tools_directory};
	my $bcn_ip          = get_local_bcn_ip($conf);
	
	foreach my $tool (@{$conf->{path}{tools}})
	{
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Copying tool: [$tool] from: [$tools_directory] to: [$docroot]\n");
		my $source      = "$tools_directory/$tool";
		my $destination = "$docroot/$tool";
		if (-e $destination)
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; skipping, already exists: [$destination]\n");
		}
		elsif (-e $source)
		{
			# Copy.
			my $shell_call = "$conf->{path}{rsync} $conf->{args}{rsync} $source $destination";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sc: [$shell_call]\n");
			open (my $file_handle, "$shell_call 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$shell_call]\n";
			while(<$file_handle>)
			{
				chomp;
				my $line = $_;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
			}
			close $file_handle;
			if (-e $destination)
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Copied successfully!\n");
				# No sense changing the URLs if I didn't find
				# my BCN IP...
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> bcn_ip: [$bcn_ip], tool: [$tool], url: [$conf->{url}{$tool}]\n");
				if ($bcn_ip)
				{
					$conf->{url}{$tool} = "http://$bcn_ip/$tool";
				}
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << bcn_ip: [$bcn_ip], tool: [$tool], url: [$conf->{url}{$tool}]\n");
			}
			else
			{
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Failed to copy! Will try to proceed as the nodes may have these files already.\n");
			}
		}
		else
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; The source file: [$source] wasn't found! Will try to proceed as the nodes may have these files already.\n");
		}
	}
	
	return(0);
}

# This does nothing more than call 'echo 1' to see if the target is reachable.
sub check_node_access
{
	my ($conf, $node, $password) = @_;
 	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; check_node_access(); node: [$node]\n");
	
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
