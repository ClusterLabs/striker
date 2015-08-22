### Alteeve's Niche! Inc. - Anvil! High Availability Platform
# License: GPLv2
# Built:   2015-08-22 03:16:40
# Target:  Optical Media (DVD)
# OS:      RHEL
# Machine: Striker Dashboard #01

### Setup values.
# Run a text-based install
install
text

# Installing from DVD.
cdrom

# Set the language and keyboard type.
lang en_CA.UTF-8
keyboard us

# Set the system clock to UTC and then define the timezone.
timezone --utc America/Toronto

# This sets the (first) ethernet device. There is currently no way to map
# device names to physical interfaces. For this reason, we use DHCP for install
# and configure the network manually post-install.
network --device eth0 --bootproto dhcp --onboot yes --hostname new-striker01.alteeve.ca

# This is the root user's password. The one below should be taken as an example
# and changed as it is a terrible password.
authconfig --enableshadow --passalgo=sha512 --enablefingerprint
rootpw Initial1

# Default admin user account.
user --name=admin --plaintext --password=Initial1

# At this time, Striker does not yet work with SELinux in enforcing mode. This
# is expected to change in a (near) future release.
firewall --service=ssh
selinux --permissive

# There is no need for the 'first boot' menu system to run, so we will disable
# it.
firstboot --disable

# Set the installation logging level.
logging --level=debug

# Enable httpd so that the local repo is available on boot.
services --enabled httpd,gpm,iptables
services --disabled kdump

# Reboot when the install is finished.
reboot

# This runs a script (below) that generates the partitioning information
# depending on a rudamentary test for available storage devices.
%include /tmp/part-include


# This is a fairly minimal installation. It is enough for 'striker-installer'
# to run properly later
%packages
@core
@server-policy
-kdump
acpid
alteeve-repo
createrepo
gcc
glibc-devel
gpm
httpd 
perl
perl-Crypt-SSLeay
perl-libwww-perl
rsync
screen 
syslinux 
syslinux-tftpboot
xinetd
yum-plugin-priorities

### Needed to keep virt-manager from complaining. Will be removed when NoVNC
### support is completed.
augeas-libs
dnsmasq
ebtables
glusterfs
glusterfs-api
glusterfs-libs
gpxe-roms-qemu
iscsi-initiator-utils
keyutils
libgssglue
libtirpc
libevent
libvirt
lzop
netcf-libs
nfs-utils
nfs-utils-lib
numad
qemu-img
qemu-kvm
radvd
rpcbind
seabios
sgabios-bin
spice-server
vgabios
%end


# First non-chroot steps
%post --nochroot --log=/tmp/nochroot-post-install.log
#!/bin/bash

# Create the install repo and PXE boot directories.
echo 'Creating the apache docroot and PXE directories.'

# Apache directories
mkdir -p /mnt/sysimage/var/www/html/rhel6/x86_64/{img,iso,ks,files}

# PXE/tftp directories
mkdir -p /mnt/sysimage/var/lib/tftpboot/boot/rhel6/x86_64/
mkdir /mnt/sysimage/var/lib/tftpboot/pxelinux.cfg

# Create the source mount point.
mkdir /mnt/source;

# Make sure the optical drive is mounted.
mount /dev/cdrom /mnt/source;

# Create a copy of the install ISO on Striker.
echo 'Copying the install iso image using dd. Be patient'
dd if=/dev/cdrom of=/mnt/sysimage/var/www/html/rhel6/x86_64/iso/Anvil_m2_RHEL-v6.7_alpha.iso


# Copy the raritan fence agent into place.
echo 'Copying fence_raritan_snmp into /usr/sbin/'
cp /mnt/source/Tools/fence/fence_raritan_snmp /mnt/sysimage/usr/sbin/

# Copy the node KS into place
echo 'Copying the KS scripts into place.'
cp /mnt/source/ks/pxe-new-node01_from-striker01.ks /mnt/sysimage/var/www/html/rhel6/x86_64/ks/pxe-new-node01.ks
cp /mnt/source/ks/pxe-new-node02_from-striker01.ks /mnt/sysimage/var/www/html/rhel6/x86_64/ks/pxe-new-node02.ks
cp /mnt/source/ks/pxe-new-striker01.ks             /mnt/sysimage/var/www/html/rhel6/x86_64/ks/
cp /mnt/source/ks/pxe-new-striker02.ks             /mnt/sysimage/var/www/html/rhel6/x86_64/ks/

# A little flair...
echo 'Setting the PXE wallpaper.'
cp /mnt/source/syslinux/splash.jpg /mnt/sysimage/var/lib/tftpboot/

# I'll need this later for the admin-owned setuid wrapper
echo "Copying the 'admin' user's copy of 'populate_remote_authorized_keys' into place."
cp /mnt/source/Striker/striker-master/tools/populate_remote_authorized_keys /mnt/sysimage/home/admin/

# Copy the Striker source files and installer into place
echo 'Copying the Striker installer and source code into place.'
cp      /mnt/source/Striker/master.zip                             /mnt/sysimage/root/
cp -Rvp /mnt/source/Striker/striker-master                         /mnt/sysimage/root/
cp      /mnt/source/Striker/striker-master/tools/striker-installer /mnt/sysimage/root/

echo "Copying 'Tools' into /mnt/sysimage/var/www/html/rhel6/x86_64/files/"
rsync -av /mnt/source/Tools /mnt/sysimage/var/www/html/rhel6/x86_64/files/

echo 'Configuring /etc/fstab to mount the ISO on boot.'
echo '/var/www/html/rhel6/x86_64/iso/Anvil_m2_RHEL-v6.7_alpha.iso	/var/www/html/rhel6/x86_64/img	iso9660	loop	0 0' >> /mnt/sysimage/etc/fstab

echo 'Copying isolinux to /var/lib/tftpboot/boot/rhel6/x86_64/'
rsync -av /mnt/source/isolinux/* /mnt/sysimage/var/lib/tftpboot/boot/rhel6/x86_64/
# */ # Ignore me, I am unbreaking syntax highlighting in vim...
%end


# Now it's time for the first chroot'ed configuration steps.
%post --log=/tmp/post-install_chroot.log


# Tell the machine to save downloaded RPM updates (for possible distribution to
# other machines for low-bandwidth users). It also makes sure all NICs start on
# boot.
echo 'Configuring yum to keep its cache.'
sed -i 's/keepcache=0/keepcache=1/g' /etc/yum.conf

# Disable DNS lookup for SSH so that logins are quick when there is not Internet
# access.
echo 'Configuring sshd to not use DNS or GSSAPI authentication for fast logins without internet connections.'
sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config 
sed -i 's/#GSSAPIAuthentication no/GSSAPIAuthentication no/' /etc/ssh/sshd_config
sed -i 's/GSSAPIAuthentication yes/#GSSAPIAuthentication yes/' /etc/ssh/sshd_config

# Show details on boot.
echo 'Setting plymouth to use detailed boot screen'
plymouth-set-default-theme details --rebuild-initrd
sed -i 's/ rhgb//'  /boot/grub/grub.conf
sed -i 's/ quiet//' /boot/grub/grub.conf


echo 'Writing out local yum repository config'
cat > /etc/yum.repos.d/striker01.repo << EOF
[striker01-rhel6]
name=Striker 01 rhel6 v6.7 + Custom Repository
baseurl=http://localhost/rhel6/x86_64/img/
enabled=1
gpgcheck=0
priority=1
EOF

# Now setup the script for the user to call once booted.
echo 'Writing out the sample striker-installer script'
cat > /root/example_striker-installer.txt << EOF
# This is an example 'striker-installer' call. Feel free to edit this file
# here and then call it with 'sh /root/example_striker-installer.txt' to
# save typing all this out.
# 
# To understand what all these switches do, run './striker-installer --help' 
# and the help will be displayed.
# 
./striker-installer \\
 -c "Alteeve's Niche!" \\
 -n "an-striker01.alteeve.ca" \\
 -e "admin@alteeve.ca:Initial1" \\
 -m mail.alteeve.ca:587 \\
 -u "admin:Initial1" \\
 -i 10.255.4.1/16,dg=10.255.255.254,dns1=8.8.8.8,dns2=8.8.4.4 \\
 -b 10.20.4.1/16 \\
 -p 10.20.10.200:10.20.10.209 \\
 --peer-dashboard hostname=an-striker02.alteeve.ca,bcn_ip=10.20.4.2 \\
 --router-mode \\
 --gui \\
 -d git \\
 --rhn "rhn_admin:rhn_Initial1"
EOF


# This writes out the custom PXE menu used when installing nodes and dashboard
# from this system.
echo 'Writing out the default PXE menu'
cat > /var/lib/tftpboot/pxelinux.cfg/default << EOF
# Use the high-colour menu system.
UI vesamenu.c32
 
# Time out and use the default menu option. Defined as tenths of a second.
TIMEOUT 600
 
# Prompt the user. Set to '1' to automatically choose the default option. This
# is really meant for files matched to MAC addresses.
PROMPT 0
 
# Set the boot menu to be 1024x768 with a nice background image. Be careful to
# ensure that all your user's can see this resolution! Default is 640x480.
MENU RESOLUTION 1024 768

# The background image
MENU BACKGROUND splash.jpg
 
# These do not need to be set. I set them here to show how you can customize or
# localize your PXE server's dialogue.
MENU TITLE    Anvil! Node and Striker Dashboard Install Server

# Below, the hash (#) character is replaced with the countdown timer. The
# '{,s}' allows for pluralizing a word and is used when the value is >= '2'.
MENU AUTOBOOT Will boot the next device as configured in your BIOS in # second{,s}.
MENU TABMSG   Press the <tab> key to edit the boot parameters of the highlighted option.
MENU NOTABMSG Editing of this option is disabled.
 
# The following options set the various colours used in the menu. All possible
# options are specified except for F# help options. The colour is expressed as
# two hex characters between '00' and 'ff' for alpha, red, green and blue
# respectively (#AARRGGBB).
# Format is: MENU COLOR <Item> <ANSI Seq.> <foreground> <background> <shadow type>
MENU COLOR screen      0  #80ffffff #00000000 std      # background colour not covered by the splash image
MENU COLOR border      0  #ffffffff #ee000000 std      # The wire-frame border
MENU COLOR title       0  #ffff3f7f #ee000000 std      # Menu title text
MENU COLOR sel         0  #ff00dfdf #ee000000 std      # Selected menu option
MENU COLOR hotsel      0  #ff7f7fff #ee000000 std      # The selected hotkey (set with ^ in MENU LABEL)
MENU COLOR unsel       0  #ffffffff #ee000000 std      # Unselected menu options
MENU COLOR hotkey      0  #ff7f7fff #ee000000 std      # Unselected hotkeys (set with ^ in MENU LABEL)
MENU COLOR tabmsg      0  #c07f7fff #00000000 std      # Tab text
MENU COLOR timeout_msg 0  #8000dfdf #00000000 std      # Timout text
MENU COLOR timeout     0  #c0ff3f7f #00000000 std      # Timout counter
MENU COLOR disabled    0  #807f7f7f #ee000000 std      # Disabled menu options, including SEPARATORs
MENU COLOR cmdmark     0  #c000ffff #ee000000 std      # Command line marker - The '> ' on the left when editing an option
MENU COLOR cmdline     0  #c0ffffff #ee000000 std      # Command line - The text being edited
# Options below haven't been tested, descriptions may be lacking.
MENU COLOR scrollbar   0  #407f7f7f #00000000 std      # Scroll bar
MENU COLOR pwdborder   0  #80ffffff #20ffffff std      # Password box wire-frame border
MENU COLOR pwdheader   0  #80ff8080 #20ffffff std      # Password box header
MENU COLOR pwdentry    0  #80ffffff #20ffffff std      # Password entry field
MENU COLOR help        0  #c0ffffff #00000000 std      # Help text, if set via 'TEXT HELP ... ENDTEXT'
 
### Now define the menu options

# It is safest to return booting to the client as the first and default option.
# This entry below will do just that.
LABEL next
	MENU LABEL ^A) Boot the next device as configured in your BIOS
	MENU DEFAULT
	localboot -1

LABEL pxe-new-node01
	MENU LABEL ^1) New Anvil! Node 01 - rhel6 v6.7 - PXE - Deletes All Existing Data!
	TEXT HELP

		/------------------------------------------------------------------\
		| WARNING: This install will appear to stall at first! BE PATIENT! |
	        ------------------------------------------------------------------/

	            To prevent traces of previous installs interrupting the 
		    Install Manifest run, this boot option starts by 'zeroing
		    out' the first 100 GiB of the drive. There is no output
		    while this runs.

		Installs a new Anvil! Node 01 using rhel6 v6.7. Will create a traditional 
		/boot + MBR install for systems with traditional BIOSes. Partition 
		will be 0.5 GiB /boot, 4 GiB <swap>, 40 GiB /.
	ENDTEXT
	KERNEL boot/rhel6/x86_64/vmlinuz
	IPAPPEND 2
	APPEND initrd=boot/rhel6/x86_64/initrd.img ks=http://10.20.4.1/rhel6/x86_64/ks/pxe-new-node01.ks ksdevice=bootif

LABEL pxe-new-node02
	MENU LABEL ^2) New Anvil! Node 02 - rhel6 v6.7 - PXE - Deletes All Existing Data!
	TEXT HELP

		/------------------------------------------------------------------\
		| WARNING: This install will appear to stall at first! BE PATIENT! |
	        ------------------------------------------------------------------/

	            To prevent traces of previous installs interrupting the 
		    Install Manifest run, this boot option starts by 'zeroing
		    out' the first 100 GiB of the drive. There is no output
		    while this runs.

		Installs a new Anvil! Node 02 using rhel6 v6.7. Will create a traditional 
		/boot + MBR install for systems with traditional BIOSes. Partition 
		will be 0.5 GiB /boot, 4 GiB <swap>, 40 GiB /.
	ENDTEXT
	KERNEL boot/rhel6/x86_64/vmlinuz
	IPAPPEND 2
	APPEND initrd=boot/rhel6/x86_64/initrd.img ks=http://10.20.4.1/rhel6/x86_64/ks/pxe-new-node02.ks ksdevice=bootif

LABEL pxe-new-striker01
	MENU LABEL ^3) New Striker 01 dashboard - rhel6 v6.7 - PXE - Deletes All Existing Data!
	TEXT HELP
	
		Installs a new Striker 01 using rhel6 v6.7. Will create a traditional
		/boot + MBR install for systems with traditional BIOSes. Partition will 
		be 0.5 GiB /boot, 4 GiB <swap>, remainder for /.
	ENDTEXT
	KERNEL boot/rhel6/x86_64/vmlinuz
	IPAPPEND 2
	APPEND initrd=boot/rhel6/x86_64/initrd.img ks=http://10.20.4.1/rhel6/x86_64/ks/pxe-new-striker01.ks ksdevice=bootif
	
LABEL pxe-new-striker02
	MENU LABEL ^4) New Striker 02 dashboard - rhel6 v6.7 - PXE - Deletes All Existing Data!
	TEXT HELP

		Installs a new Striker 02 using rhel6 v6.7. Will create a traditional
		/boot + MBR install for systems with traditional BIOSes. Partition will 
		be 0.5 GiB /boot, 4 GiB <swap>, remainder for /.
	ENDTEXT
	KERNEL boot/rhel6/x86_64/vmlinuz
	IPAPPEND 2
	APPEND initrd=boot/rhel6/x86_64/initrd.img ks=http://10.20.4.1/rhel6/x86_64/ks/pxe-new-striker02.ks ksdevice=bootif

label rescue
	MENU LABEL ^B) Rescue installed system
	TEXT HELP

		Boot the rhel6 v6.7 DVD in rescue mode.
	ENDTEXT
	KERNEL boot/rhel6/x86_64/vmlinuz
	APPEND initrd=boot/rhel6/x86_64/initrd.img rescue

label memtest86
	MENU LABEL ^C) Memory test
	TEXT HELP

		Test the RAM in the system for defects.
	ENDTEXT
	KERNEL memtest
	APPEND -
EOF

### Note: This will go away when NoVNC is integrated.
# Copy the 'populate_remote_authorized_keys' to the 'admin' user's home and make
# a setuid C-wrapper owned by admin so that apache can call it when an Anvil is
# added to a system.
cat > /home/admin/call_populate_remote_authorized_keys.c << EOF
#define REAL_PATH "/home/admin/populate_remote_authorized_keys"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}
EOF
chmod 755     /home/admin
gcc -o        /home/admin/call_populate_remote_authorized_keys /home/admin/call_populate_remote_authorized_keys.c
chown 0:0     /home/admin/call_populate_remote_authorized_keys
chmod 6755    /home/admin/call_populate_remote_authorized_keys
chown 500:500 /home/admin/populate_remote_authorized_keys
chmod 755     /home/admin/populate_remote_authorized_keys

# Disable the libvirtd default bridge.
echo "Disabling the default libvirtd bridge 'virbr0'."
cat /dev/null >/etc/libvirt/qemu/networks/default.xml

echo "'chroot'ed post install script complete."
%end



# This is set to run at the end. It copies all of the kickstart logs into the
# root user's home page.
%post --nochroot
echo 'Copying all the anaconda related log files to /root/install/'

if [ ! -e '/mnt/sysimage/root/install' ]
then
	mkdir /mnt/sysimage/root/install
fi
cp -p /tmp/nochroot*   /mnt/sysimage/root/install/
cp -p /tmp/kernel*     /mnt/sysimage/root/install/
cp -p /tmp/anaconda*   /mnt/sysimage/root/install/
cp -p /tmp/ks*         /mnt/sysimage/root/install/
cp -p /tmp/program.log /mnt/sysimage/root/install/
cp -p /tmp/storage*    /mnt/sysimage/root/install/
cp -p /tmp/yum.log     /mnt/sysimage/root/install/
cp -p /tmp/ifcfg*      /mnt/sysimage/root/install/
cp -p /tmp/syslog      /mnt/sysimage/root/install/
%end



### Script to setup partitions.
%pre --log=/tmp/ks-preinstall.log

#!/bin/sh

# Prepare the disks in the script below. It checks '/proc/partitions' to see
# what configuration to use.

###############################################################################
# Creates a 512 MiB /boot, 4 GiB <swap> and the balance to /                  #
###############################################################################

# Default is to use /dev/sda. At this time, software arrays are not supported.
DRIVE="sda";

# /dev/vda KVM virtual machine
if grep -q vda /proc/partitions; then
	DRIVE="vda"
fi

# /dev/sdb ASUS EeeBox machine
if grep -q sdb /proc/partitions; then
	DRIVE="sdb"
fi

# Now write the partition script
cat >> /tmp/part-include <<END
zerombr
clearpart --all --drives=${DRIVE}
ignoredisk --only-use=${DRIVE}
bootloader --location=mbr --driveorder=${DRIVE}

part     /boot --fstype ext4 --size=512   --asprimary --ondisk=${DRIVE}
part     swap  --fstype swap --size=4096  --asprimary --ondisk=${DRIVE}
part     /     --fstype ext4 --size=100   --asprimary --ondisk=${DRIVE} --grow

END

%end
