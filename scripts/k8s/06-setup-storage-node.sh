#!/bin/bash
set -euo pipefail

# Run on northwoods: format and mount data disks, export via NFS.
# Usage: 06-setup-storage-node.sh /dev/sdb [/dev/sdc ...]
# Each disk is formatted ext4 and mounted at /srv/data/diskN. Destroys data on the listed disks.

if [[ $EUID -ne 0 ]]; then
    echo "Run as root (su -): bash $0 /dev/sdX ..."
    exit 1
fi

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 /dev/sdX [/dev/sdY ...]"
    exit 1
fi

source "$(dirname "${BASH_SOURCE[0]}")/cluster.env"
require_node_ip
require_role storage

echo "Disks to ERASE: $*"
read -p "Type 'yes' to continue: " confirm
[[ "$confirm" == "yes" ]] || exit 0

apt update
apt install -y nfs-kernel-server
mkdir -p /etc/exports.d

i=1
for dev in "$@"; do
    [[ -b "$dev" ]] || { echo "Not a block device: $dev"; exit 1; }
    if blkid "$dev" >/dev/null 2>&1; then
        echo "$dev already has a filesystem or signature; run 'wipefs -a $dev' first if you want to reuse it"
        exit 1
    fi
    while [[ -e "/srv/data/disk$i" ]]; do i=$((i + 1)); done
    mnt="/srv/data/disk$i"
    mkfs.ext4 -F -L "data$i" "$dev"
    mkdir -p "$mnt"
    uuid=$(blkid -s UUID -o value "$dev")
    echo "UUID=$uuid $mnt ext4 defaults,noatime,nofail 0 2" >> /etc/fstab
    systemctl daemon-reload
    mount "$mnt"
    echo "$mnt $NETWORK_CIDR(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports.d/k8s-data.exports
    i=$((i + 1))
done

# Directory backing the cluster's NFS storage class
mkdir -p /srv/data/disk1/k8s

exportfs -ra
systemctl enable --now nfs-server

echo "✓ Storage ready. Exports:"
exportfs -v
