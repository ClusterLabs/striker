#!/bin/sh
#
# This script was create by an anonumous Anvil! community member. It was 
# graciously released back to the community under the GPL v2+ license.
# 

# Need to run as root
if [[ $EUID -ne 0 ]]; then
   echo "$0 must be run as root" 1>&2
   exit 1
fi

# Need a USB device name
if [ "$#" -ne 2 ]; then
   echo "Usage: $0 <usb_dev> <iso_image_file>"
   echo "Note: Specify the full path of usb_dev and not a partition on it."
   echo "i.e. /dev/sdc and not /dev/sdc1"
   echo "Ex: $0 /dev/sdc dashboard-Alpha-RHEL-6.iso"
   exit 1
fi

USBDEV=$1
ISOIMG=$2
# We want only one partition
USBDEVPART=${USBDEV}1

USBMNT=/media/bootstick
ISOMNT=/media/iso

# Umount any remaining mounts from a previous run
umount -l ${USBMNT}
umount -l ${ISOMNT}

echo "USB Device existing partition table:"
parted -s $USBDEV --script unit MB print

# Unmount all USB devices
#for usb_dev in /dev/disk/by-id/usb-*; do
#  dev=$(readlink -f $usb_dev)
#  echo "Unmounting $dev"
#  grep -q ^$dev /proc/mounts && umount -l $dev
#done

# Just lazy umount the device in question
umount -l ${USBDEVPART}

while true; do
  read -p "$USBDEV will be formatted. Are you OK with this? " yn
  case $yn in
      [Yy]* ) break;;
      [Nn]* ) exit;;
      * ) echo "Please answer yes or no";;
  esac
done

echo "Formatting $USBDEV   ... Please wait"

# Partition and format the usb thumbdrive.
# Partition it with a single partition, and be sure to set the partition as "active" or bootable in your partitioning tool.
# Format it with the fat32 filesystem.

# Remove existing partitions
echo "Removing all existing partitions, if any. Ignore any errors"
parted $USBDEV --script rm 1
parted $USBDEV --script rm 2
parted $USBDEV --script rm 3
parted $USBDEV --script rm 4
parted $USBDEV --script rm 5

echo "Making a single active partition on $USBDEV"

parted $USBDEV --script -- mklabel msdos

# The negative number makes mkpart use all of the space on the device
parted $USBDEV --script -- mkpart primary fat32 4MiB -1s

parted $USBDEV --script -- set 1 boot on

echo "USB Device new partition info:"
parted $USBDEV --script unit MB print

echo "Formatting ${USBDEVPART} as vfat"
mkfs.vfat -F 32 ${USBDEVPART}

# Copy the master boot record to the USB device
echo "Copying MBR to $USBDEV"
dd bs=440 count=1 conv=notrunc if=/usr/share/syslinux/mbr.bin of=$USBDEV

# Install syslinux to the USB device
echo "Installing syslinux on ${USBDEVPART}"
syslinux -i ${USBDEVPART}

mkdir -p ${USBMNT}
mkdir -p ${ISOMNT}

# Mount the USB device and the iso file
echo "Mounting ${USBDEVPART} on ${USBMNT}"
mount ${USBDEVPART} ${USBMNT}

echo "Mounting ${ISOIMG} on ${ISOMNT}" 
mount -o loop ${ISOIMG} ${ISOMNT}

# Copy the contents of the iso file to the thumbdrive.

# Check if any files are more than 2G in size
echo ""
echo "Checking to see if any of the files in the ISO are more than 2G in size"
echo "If you see any output from the find command, the USB drive will be unusable"
echo "Running: find ${ISOMNT} -type f -size +2g -exec ls -lh {} \;"
echo ""

find ${ISOMNT} -type f -size +2G -exec ls -lh {} \;


# Note: vfat does not support owners, groups or permissions
# fat represents times with a 2-second resolution
# vfat does not support symbolic links
# Also note that vfat does not support filenames containing "%" or ":"
 
echo "Note that any files with a '%' or ':' character in their names will NOT be copied"

echo "Copying the files from ${ISOIMG} to the USB device"
rsync -a --no-o --no-p --no-g --safe-links --modify-window 1 --stats ${ISOMNT}/ ${USBMNT}/

# Copy the iso file itself (small enough for FAT32 that a split is not necessary)
# Check size of the ISO (should not be more than 2 GB)
iso_size=$(stat -c %s ${ISOIMG})
echo "The ISO size is: $iso_size bytes"
if [[ ($iso_size > 2*1024*1024*1024) ]]; then
   echo "The ISO image is greater than 2GB. Cannot copy to a FAT file system"
else
   echo "Copying the raw image to the USB device"
   cp -v ${ISOIMG} ${USBMNT}/`basename ${ISOIMG}`
fi

# Copy the needed *.c32 files
if grep -q "Twenty One" /etc/redhat-release;
then 
	echo "Fedora 21 found, copying additional .c32 files to USB's 'syslinux' directory"
	rsync -av /usr/share/syslinux/ldlinux.c32   ${USBMNT}/syslinux/
	rsync -av /usr/share/syslinux/libcom32.c32  ${USBMNT}/syslinux/
	rsync -av /usr/share/syslinux/libutil.c32   ${USBMNT}/syslinux/
	rsync -av /usr/share/syslinux/vesamenu.c32  ${USBMNT}/syslinux/
fi

echo "************************************************************"
echo "Completed copying ISO content to the USB device."
echo "Syncing the USB device will take some time (around 10 minutes)"
echo "Do NOT unplug device yet! Please WAIT."
echo "***********************************************************"

umount -l ${USBMNT}
umount -l ${ISOMNT}

# Sleep 20s as an extra measure for things to settle down
sync
sleep 2s

echo "USB bootable image preparation is complete. USB device can be unplugged now."

