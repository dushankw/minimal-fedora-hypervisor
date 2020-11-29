#!/bin/bash
set -euo pipefail

# Abort handler
function die() {
    echo "$1" > /dev/stderr
    exit 1
}

# Get the name of the VM
NAME=''
read -rp 'Enter desired name for VM (if you are restoring from an existing disk image, name the VM as per the image): ' NAME
if ! [[ "$NAME" =~ ^[a-zA-Z0-9\-]{1,20}$ ]] ; then
    die 'Invalid VM name'
fi

# Get the OS type
OS=''
read -rp 'Enter the OS type in libosinfo format (eg: fedora33): ' OS
if ! [[ "$OS" =~ ^[a-zA-Z0-9\-]{1,20}$ ]] ; then
    die 'Invalid OS name'
fi

# Constants
CPUS=2
MEMORY=4096 # MiB
DISK_SIZE=25000 # MiB
VGAMEM=65536 # KiB
BRIDGE='virbr10'
DISK_PATH="/var/lib/libvirt/images/$NAME.img" # We assume every VM will have its disk called NAME.img
BOOT_DISK=
ISO=''

# Work out how we are booting
if ! [ -f "$DISK_PATH" ] ; then
    # No existing disk, we need to make one and prompt the user for the path to an iso image to install from
    read -rp 'Enter the full path to the installer ISO (eg: /var/lib/libvirt/images/Fedora-Workstation-Live-x86_64-33-1.2.iso): ' ISO

    # Validate that it is a legal path and aim to prevent shell injection
    if ! [[ "$ISO" =~ ^\/var\/lib\/libvirt\/images\/[a-zA-Z0-9_.\-]+(.iso)$ ]] ; then
        die 'Invalid ISO path'
    fi

    # Validate the file actually exists
    if ! [ -f "$ISO" ] ; then
        die 'ISO file does not exist or can not be read'
    fi

    # Allocate the virtual machines disk image (since it does not exist) and set the first boot to be from the provided iso
    echo 'Allocating Disk Image'
    time sudo dd if=/dev/zero of="$DISK_PATH" bs=1M count="$DISK_SIZE" status=progress
    BOOT_DISK="--cdrom $ISO"
else
    # This will cause the VM to boot off the existing disk and no install will be attempted, assumption is that existing disks are bootable
    echo 'Disk image already exists, using it'
    BOOT_DISK='--import'
fi

# Make the VM
sudo virt-install \
    --connect qemu:///system \
    --name "$NAME" \
    --machine q35 \
    --sysinfo emulate \
    --vcpus "$CPUS" \
    --memory "$MEMORY" \
    --os-variant detect=on,name="$OS" \
    --disk "$DISK_PATH,driver.discard=unmap" \
    --network bridge="$BRIDGE",model=virtio,filterref.filter=clean-traffic \
    --sound default \
    --graphics spice,listen=none \
    --channel 'spicevmc,target.type=virtio,target.name=com.redhat.spice.0' \
    --channel 'unix,target.type=virtio,target.name=org.qemu.guest_agent.0' \
    --video qxl,model.vgamem="$VGAMEM" \
    --autoconsole none \
    $BOOT_DISK

# To Do:
# 0. Option to share filesystem from host (--filesystem)
# 1. Option to share usb device from host such as Yubikey (--hostdev)
# 2. Option to supply kickstart for use during install (--extra-args "ks=https://myserver/my.ks")
# 3. Option to make throwaway VM (no disk, destroyed on poweroff)
# 4. Evaluate security implications of enabling guest agent by default
