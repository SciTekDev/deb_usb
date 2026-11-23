#!/bin/bash
set -euo pipefail

# Create dual-partition USB:
# Partition 1: 4GB - Debian installer (bootable)
# Partition 2: 4GB - Post-install scripts

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$scriptdir/.."

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /dev/sdX"
    echo "Example: $0 /dev/sdb"
    exit 1
fi

device="$1"
iso="debian-13.8.0-amd64-netinst.iso"

if [[ ! -e "$device" ]]; then
    echo "Device not found: $device"
    exit 1
fi

if [[ ! -f "$iso" ]]; then
    echo "ISO not found: $iso"
    exit 1
fi

echo "⚠️  WARNING: This will erase all data on $device"
echo "ISO: $iso"
echo "Device: $device"
read -p "Continue? (yes/no): " confirm
[[ "$confirm" == "yes" ]] || exit 0

echo "Unmounting ${device}* ..."
sudo -A umount "${device}"* 2>/dev/null || true

echo "Creating partitions..."
# Create partition table and two 4GB partitions
sudo -A parted -s "$device" mklabel msdos
sudo -A parted -s "$device" mkpart primary fat32 1MB 4GB
sudo -A parted -s "$device" mkpart primary fat32 4GB 8GB
sudo -A parted -s "$device" set 1 boot on

sleep 2

echo "Writing ISO to partition 1..."
sudo -A dd if="$iso" of="${device}1" bs=4M status=progress conv=fsync

echo ""
echo "Formatting partition 2 as FAT32..."
sudo -A mkfs.vfat -n "SCRIPTS" "${device}2"

sleep 1

# Mount and copy scripts
tmpdir=$(mktemp -d)
sudo -A mount "${device}2" "$tmpdir"
sudo -A cp scripts/post-install.sh scripts/upgrade-to-sid.sh "$tmpdir/"
sudo -A cp -r scripts/k8s scripts/deployments "$tmpdir/"
sudo -A chmod +x "$tmpdir"/*.sh "$tmpdir"/k8s/*.sh "$tmpdir"/deployments/*.sh
sudo -A umount "$tmpdir"
rmdir "$tmpdir"

echo ""
echo "✓ USB stick ready"
echo "Partition 1: Debian installer (4GB, bootable)"
echo "Partition 2: Post-install scripts (4GB)"
echo ""
echo "After installation, mount partition 2 to access scripts:"
echo "  sudo mount /dev/sdX2 /mnt"
echo "  sudo bash /mnt/post-install.sh"
