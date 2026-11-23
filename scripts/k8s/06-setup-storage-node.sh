#!/bin/bash
set -euo pipefail

# Run on northwoods: export the existing /mnt/storage volume over NFS and create the k8s directory.
# Usage: 06-setup-storage-node.sh
# Formats nothing; /mnt/storage must already be mounted (LVM volume).

if [[ $EUID -ne 0 ]]; then
    echo "Must run in a root login shell (use 'su -', NOT plain 'su'): bash $0"
    exit 1
fi

source "$(dirname "${BASH_SOURCE[0]}")/cluster.env"
require_node_ip
require_role storage

STORAGE_DIR="/mnt/storage"

mountpoint -q "$STORAGE_DIR" || { echo "$STORAGE_DIR is not a mount point; mount it first"; exit 1; }

apt update
apt install -y nfs-kernel-server

mkdir -p /etc/exports.d
echo "$STORAGE_DIR $NETWORK_CIDR(rw,sync,no_subtree_check,no_root_squash)" > /etc/exports.d/k8s-data.exports

# Directory backing the cluster's NFS storage class
mkdir -p "$STORAGE_DIR/k8s"

exportfs -ra
systemctl enable --now nfs-server

echo "✓ Storage ready. Exports:"
exportfs -v
