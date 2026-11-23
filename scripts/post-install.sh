#!/bin/bash
set -euo pipefail

# Basic post-install setup after Debian installation

if [[ $EUID -ne 0 ]]; then
    echo "Run as root (su -): bash $0"
    exit 1
fi

cluster_env="$(dirname "${BASH_SOURCE[0]}")/k8s/cluster.env"
if [[ -f "$cluster_env" ]]; then
    source "$cluster_env"
    mapfile -t names < <(printf '%s\n' "${!NODE_IPS[@]}" | sort)
    echo "Select this node:"
    select hostname in "${names[@]}"; do
        [[ -n "$hostname" ]] && break
    done
else
    read -p "Enter hostname: " hostname
fi

echo "Setting hostname to $hostname..."
hostnamectl set-hostname "$hostname"

echo "Installing basic packages..."
apt update
apt install -y curl wget git openssh-server build-essential

echo "Enabling SSH..."
systemctl enable ssh
systemctl start ssh

echo "✓ Done"
echo ""
echo "Next: bash /path/to/upgrade-to-sid.sh, reboot, then k8s/00-set-static-ip.sh"
