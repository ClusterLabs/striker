#!/bin/bash

mkdir /root/base
cd /root/base
mkdir /root/base/root
mkdir -p /root/base/etc/sysconfig/network-scripts
mkdir -p /root/base/etc/udev/rules.d
mkdir -p /root/base/etc/init.d
mkdir -p /root/base/var/spool/cron
 
# Root user
rsync -av /root/.bashrc   /root/base/root/
rsync -av /root/.ssh      /root/base/root/
rsync -av /root/an-cm*    /root/base/root/
rsync -av /root/archive_* /root/base/root/
 
# Directories
rsync -av /etc/ssh     /root/base/etc/
rsync -av /etc/apcupsd /root/base/etc/
rsync -av /etc/cluster /root/base/etc/
rsync -av /etc/drbd.*  /root/base/etc/
rsync -av /etc/an      /root/base/etc/
rsync -av /etc/yum     /root/base/etc/
rsync -av /etc/pki     /root/base/etc/
rsync -av --exclude 'archive' --exclude 'cache' --exclude 'backup' /etc/lvm /root/base/etc/
 
# Specific files.
rsync -av /etc/sysconfig/network-scripts/ifcfg-{eth*,bond*,vbr*} /root/base/etc/sysconfig/network-scripts/
rsync -av /etc/udev/rules.d/70-persistent-net.rules              /root/base/etc/udev/rules.d/
rsync -av /etc/sysconfig/network /root/base/etc/sysconfig/
rsync -av /etc/hosts             /root/base/etc/
rsync -av /etc/ntp.conf          /root/base/etc/
rsync -av /etc/init.d/apcupsd    /root/base/etc/init.d/
rsync -av /var/spool/cron/root   /root/base/var/spool/cron/
 
# Save recreating user accounts.
rsync -av /etc/passwd            /root/base/etc/
rsync -av /etc/group             /root/base/etc/
rsync -av /etc/shadow            /root/base/etc/
rsync -av /etc/gshadow           /root/base/etc/
 
# If you have the cluster built and want to backup it's configs.
mkdir /root/base/etc/cluster
mkdir /root/base/etc/lvm
rsync -av /etc/cluster/cluster.conf /root/base/etc/cluster/
 
# NOTE: DRBD won't work until you've manually created the partitions.
rsync -av /etc/drbd.d /root/base/etc/
 
# If you're running RHEL and want to backup your registration info;
if [ -e "/etc/sysconfig/rhn" ]
then
	rsync -av /etc/sysconfig/rhn /root/base/etc/sysconfig/
fi
 
# Back up the logical and extended partition structure
for d in $(fdisk -l | grep 'Disk /dev' | grep -v mapper | sed 's/Disk \(.*\):.*/\1/')
do
        echo "#!/bin/bash" > /root/base/root/partition_drives.sh
        for i in $(parted -m -s -a opt $d "print free" | grep '^[4-9]')
        do
                if [ `echo $i | grep '^4:'` ]
                then
                        echo "$d:$i" | perl -pe 's/^(.*?):(\d+):(.*?):(.*?):.*/parted -s -a opt \1 "mkpart extended \3 \4"/'
                else
                        echo "$d:$i" | perl -pe 's/^(.*?):(\d+):(.*?):(.*?):.*/parted -s -a opt \1 "mkpart logical \3 \4"/'
                fi
        done
done >> /root/base/root/partition_drives.sh
chmod 755 /root/base/root/partition_drives.sh
 
# Pack it up
# NOTE: Change the name to suit your node.
cd /root/
tar -cvf base_$(hostname -s).tar /root/base/etc /root/base/root /root/base/var

echo "
Backup configuration script saved as: [/root/base_$(hostname -s).tar] created.
Please copy this file to another system, like a PXE[1] server.
If you are using a kickstart[2] script to automate recovery, you can add a 
section like this to your '%post':

====
%post
# Download the backup files and load them.
cd ~
wget http://10.255.255.250/rhel6/x86_64/files/base_$(hostname -s).tar
cp base_$(hostname -s).tar /mnt/sysimage/root/
/etc/init.d/network stop
tar -xvf base_$(hostname -s).tar -C /
rm -f /etc/udev/rules.d/70-persistent-net.rules
start_udev
/etc/init.d/network start
/mnt/systemroot/root/partition_drives.sh
====

Replace the 'wget' URL with the location of your node's backup file.

If your node was registered with the Red Hat Network, the node should pick up
it's old registration right away. All SSH keys and configuration, network
configuration and so on should also be recovered.

If you don't have a PXE server, then once the node's OS has been reinstalled,
copy [base_$(hostname -s).tar] to the node and then run:

====
/etc/init.d/network stop
tar -xvf base_$(hostname -s).tar -C /
rm -f /etc/udev/rules.d/70-persistent-net.rules
start_udev
/etc/init.d/network start
/mnt/systemroot/root/partition_drives.sh
====

1. https://alteeve.ca/w/Setting_Up_a_PXE_Server_on_an_RPM-based_OS
2. https://alteeve.ca/w/Kickstart"
