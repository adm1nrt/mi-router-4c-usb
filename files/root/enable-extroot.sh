#!/bin/sh
# Run AFTER the custom USB-enabled firmware is installed and USB partition 1
# has been formatted ext4 with filesystem label ROOTFS.
set -eu

INFO="$(block info 2>/dev/null | grep 'LABEL="ROOTFS"' | head -n 1 || true)"
[ -n "$INFO" ] || { echo "ERROR: ext4 partition labelled ROOTFS not found"; exit 1; }

DEV="${INFO%%:*}"
UUID="$(printf '%s\n' "$INFO" | sed -n 's/.*UUID="\([^"]*\)".*/\1/p')"
TYPE="$(printf '%s\n' "$INFO" | sed -n 's/.*TYPE="\([^"]*\)".*/\1/p')"

[ "$TYPE" = "ext4" ] || { echo "ERROR: ROOTFS is not ext4 (found: $TYPE)"; exit 1; }
[ -n "$UUID" ] || { echo "ERROR: could not read UUID"; exit 1; }
[ -b "$DEV" ] || { echo "ERROR: $DEV is not a block device"; exit 1; }

mkdir -p /mnt/extroot
mount -t ext4 "$DEV" /mnt/extroot
if [ -n "$(ls -A /mnt/extroot 2>/dev/null)" ]; then
    echo "ERROR: ROOTFS partition is not empty; refusing to overwrite it"
    umount /mnt/extroot
    exit 1
fi

echo "Copying current overlay to $DEV ..."
tar -C /overlay -cf - . | tar -C /mnt/extroot -xf -
sync

uci -q delete fstab.extroot
uci set fstab.extroot='mount'
uci set fstab.extroot.target='/overlay'
uci set fstab.extroot.uuid="$UUID"
uci set fstab.extroot.fstype='ext4'
uci set fstab.extroot.options='rw,noatime'
uci set fstab.extroot.enabled='1'
uci set fstab.extroot.enabled_fsck='0'
uci commit fstab

umount /mnt/extroot
echo "Extroot configured. Rebooting..."
reboot
