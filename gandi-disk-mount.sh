#!/bin/bash
#
# Copyright © 2013 Jacques Bodin-Hullin <jacques@bodin-hullin.net>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING file for more details.
#

# Colors
fg_black="$(tput setaf 0)"
fg_red="$(tput setaf 1)"
fg_green="$(tput setaf 2)"
fg_yellow="$(tput setaf 3)"
fg_blue="$(tput setaf 4)"
fg_magenta="$(tput setaf 5)"
fg_cyan="$(tput setaf 6)"
fg_white="$(tput setaf 7)"
fg_reset="$(tput sgr0)"

echo "$fg_green BE CAREFUL! You can break your system."
echo "This programm allows you to mount an attached disk to a specific mount point on the disk."
echo "You can copy files before and remove old files after if you want."
echo ""
echo "Let's go!"
echo "$fg_reset"

# Test root?
if [[ "$USER" != "root" ]]; then
    echo "$fg_red You need to be root ;) $fg_reset"
    exit 1
fi

# Mount -l
echo "$fg_green Your mount table: $fg_reset"
mount -l
echo ""

# Wich disk?
echo "$fg_yellow Wich disk ? (Use label in gandi interface, like \"datadisk01\") $fg_reset"
read disk

if [[ -z "$disk" ]]; then
    echo "$fg_red Disk to mount is required $fg_reset"
    exit 1
fi

realdisk=`mount -l | grep $disk | cut -d" " -f1`
actualMountPoint=`mount -l | grep $disk | cut -d" " -f3`

# Wich directory to mount?
echo "$fg_yellow Wich directory to mount? (starts with /, ends without /) $fg_reset"
read mountDir

if [[ -z "$mountDir" ]]; then
    echo "$fg_yellow Directory to mount is required $fg_reset"
    exit 1
fi

# Copy files before mount?
echo "$fg_yellow Copy files in the original directory before mount? [y/N] $fg_reset"
read copy

if [[ "$copy" == "y" || "$copy" == "Y" ]]; then
    copy=1
elif [[ "$copy" == "n" || "$copy" == "N" || -z "$copy" ]]; then
    copy=0
else
    echo "$fg_red Please enter Y or N. $fg_reset"
    exit 1
fi

# Remove old files?
echo "$fg_yellow Remove old files after mount? [y/N] $fg_reset"
read remove

if [[ "$remove" == "y" || "$remove" == "Y" ]]; then
    remove=1
elif [[ "$remove" == "n" || "$remove" == "N" || -z "$remove" ]]; then
    remove=0
else
    echo "$fg_red Please enter Y or N. $fg_reset"
    exit 1
fi

# Copy files?
if [[ $copy ]]; then
    echo "$fg_green Copy files... $fg_reset"
    rsync -zah $mountDir/ $actualMountPoint/
    echo "$fg_green Files copied $fg_reset"
fi

# We change the udev rules ;)
echo "$fg_green Disable UDEV... $fg_reset"
cat > "/etc/udev/rules.d/86-gandi.rules" <<EOF
#
# mount disk attached to the local system
#

# complete automounting support for virtual disk
#SUBSYSTEMS=="xen", DRIVERS=="vbd", SUBSYSTEM=="block", RUN+="fake_blkid -o udev -p \$tempnode", RUN+="/etc/gandi/manage_data_disk.py", OPTIONS+="last_rule"
# simple notification for virtual disk. no automounting
#SUBSYSTEMS=="xen", DRIVERS=="vbd", SUBSYSTEM=="block", RUN+="fake_blkid -o udev -p \$tempnode", RUN+="/etc/gandi/manage_data_disk.sh"


#
# setup network inteface attached to the local system
#
SUBSYSTEMS=="xen", SUBSYSTEM=="net", KERNEL=="eth?", RUN+="/etc/gandi/manage_iface.sh", OPTIONS+="last_rule"
KERNELS=="xen", SUBSYSTEM=="xen", ATTR{devtype}=="vif", OPTIONS+="ignore_device"


#
# enable CPU when attached to the local system as they are disabled by default
#
KERNELS=="cpu", ATTR{online}=="0", RUN+="cpu_online", OPTIONS+="last_rule"

# newer kernel and/or newer udev (>= 146)
# script cpu_online is using DEVPATH and is installed in /lib/udev
KERNEL=="cpu*", ACTION=="add", SUBSYSTEM=="cpu", RUN+="cpu_online"
EOF
echo "$fg_green UDEV disabled $fg_reset"

# Add mount line into mount file
echo "$gf_green Add mount line into your fstab file... $fg_reset"
echo "$realdisk $mountDir ext3 rw,nosuid,nodev,noatime,user_xattr,acl,barrier=1,nodelalloc,data=ordered 0 0" >> /etc/fstab
echo "$fg_green Mount line added $fg_reset"

# mount
echo "$fg_green Mount the disk... $fg_reset"
mount -t ext3 -o rw,nosuid,nodev,noatime,user_xattr,acl,barrier=1,nodelalloc,data=ordered $realdisk $mountDir
echo "$fg_green Disk detached... $fg_reset"

# umount
echo "$fg_green Unmount the disk... $fg_reset"
umount $actualMountPoint
echo "$fg_green Disk detached... $fg_reset"

# Remove old files?
if [[ $remove ]]; then
    echo "$fg_green Removing old files... $fg_reset"
    tmpdir=/tmp/olddir
    mkdir -p $tmpdir
    mount --bind / $tmpdir
    rm -rf ${tmpdir}${mountDir}/* ${tmpdir}${mountDir}/.* > /dev/null 2> /dev/null
    umount $tmpdir
    echo "$fg_green Old files removed $fg_reset"
fi

echo ""
echo "$fg_green Well done pat! $fg_reset"

exit 0
