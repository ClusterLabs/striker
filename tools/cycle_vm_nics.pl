#!/usr/bin/perl
#
# Simple little program that takes the name of VM, parses its XML to find the
# 'vnetx' bridge links, determines which bridge they're connected to and then
# takes the interfaces down, waits a couple seconds, and brings them back up.
# It cycles the interfaces connected to the BCN, then the SN and finally the
# IFN.
#
# The goal of this program is to simplify testing the Striker and Anvil! node
# installer scripts when using KVM/qemu based VMs.
#

use strict;
use warnings;

my $vm = $ARGV[0];
if (not $vm)
{
	print "VM name required. Usage: '$0 <vm>'\n";
	exit 1;
}
print "Searching: [$vm] for 'vnetX' interfaces...\n";

my @bcn_nic;
my @sn_nic;
my @ifn_nic;
my $this_bridge = "";
my $this_device = "";
my $shell_call = "virsh dumpxml $vm";
#print "[ Debug ] - shell_call: [$shell_call]\n";
open (my $file_handle, '-|', "$shell_call 2>&1") || die "Failed to call: [$shell_call], error was: $!\n";
while(<$file_handle>)
{
	chomp;
	my $line = $_;
	$line =~ s/\n//g;
	$line =~ s/\r//g;
	if ($line =~ /error: failed to get domain/)
	{
		print "[ Error ] - VM: [$vm] not found.\n";
		exit 2;
	}
	if ($line =~ /source bridge='(.*?)'/)
	{
		$this_bridge = $1;
		#print "This bridge: [$this_bridge]\n";
	}
	if ($line =~ /source network='(.*?)'/)
	{
		$this_bridge = $1;
		#print "This bridge: [$this_bridge]\n";
	}
	if ($line =~ /target dev='(vnet\d+)'/)
	{
		$this_device = $1;
		#print "This device: [$this_device]\n";
	}
	if ($line =~ /<\/interface>/)
	{
		#print "This bridge: [$this_bridge], This device: [$this_device]\n";
		if (($this_bridge) && ($this_device))
		{
			#print "this_bridge: [$this_bridge], bcn_bridge: [bcn_bridge1], sn_bridge: [sn_bridge1], ifn_bridge: [ifn_bridge1]\n";
			if    (($this_bridge =~ /bcn_bridge\d/) || ($this_bridge =~ /bcn-bridge\d/)) { push @bcn_nic, $this_device; }
			elsif (($this_bridge =~ /sn_bridge\d/)  || ($this_bridge =~ /sn-bridge\d/))  { push @sn_nic, $this_device; }
			elsif (($this_bridge eq "ifn_bridge1") || ($this_bridge eq "ifn-bridge1")) { push @ifn_nic, $this_device; }
			else
			{
				print "[ Error ] - Interface: [$this_device] on unknown bridge: [$this_bridge]\n";
				print "[ Error ]   Expected bridge names;\n";
				print "[ Error ]   - Back-Channel Network:    [bcn_bridge1]\n";
				print "[ Error ]   - Storage Network:         [sn_bridge1]\n";
				print "[ Error ]   - Internet-Facing Network: [ifn_bridge1]\n";
				exit 3;
			}
		}
	}
	#print "- Output: [$line]\n";
}
close $file_handle;
print "- Done.\n\n";

foreach my $nic (sort {$a cmp $b} @bcn_nic)
{
	print "Cycling BCN NIC: [$nic]\n";
	cycle_nic($vm, $nic);
}
foreach my $nic (sort {$a cmp $b} @sn_nic)
{
	print "Cycling SN NIC: [$nic]\n";
	cycle_nic($vm, $nic);
}
foreach my $nic (sort {$a cmp $b} @ifn_nic)
{
	print "Cycling IFN NIC: [$nic]\n";
	cycle_nic($vm, $nic);
}


exit;

sub cycle_nic
{
	my ($vm, $nic) = @_;

	my $shell_call = "virsh domif-setlink $vm $nic down; echo down; sleep 5; virsh domif-setlink $vm $nic up; echo up; sleep 3";
	print "[ Debug ] - shell_call: [$shell_call]\n";
	open (my $file_handle, '-|', "$shell_call 2>&1") || die "Failed to call: [$shell_call], error was: $!\n";
	while(<$file_handle>)
	{
		chomp;
		my $line = $_;
		next if not $line;
		if ($line eq "down")
		{
			print "- Down.\n";
		}
		if ($line eq "up")
		{
			print "- Back up.\n";
		}
		else
			{
			#print "- Output: [$line]\n";
		}
	}
	close $file_handle;
}

