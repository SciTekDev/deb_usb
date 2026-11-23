#!/bin/bash
set -euo pipefail

# Run on northwoods only: kubeadm init, CNI (flannel), and print the join command
# Usage: 02-init-control-plane.sh [username]  (user who gets ~/.kube/config; default: $SUDO_USER)

if [[ $EUID -ne 0 ]]; then
    echo "Run as root (su -): bash $0 [username]"
    exit 1
fi

source "$(dirname "${BASH_SOURCE[0]}")/cluster.env"
require_node_ip
[[ "$(hostname -s)" == "$CONTROL_PLANE_HOST" ]] || { echo "Run this on $CONTROL_PLANE_HOST"; exit 1; }

kubeadm init \
    --apiserver-advertise-address="$CONTROL_PLANE_IP" \
    --apiserver-cert-extra-sans="$CONTROL_PLANE_HOST,$CONTROL_PLANE_HOST.$SEARCH_DOMAIN" \
    --pod-network-cidr="$POD_CIDR"

export KUBECONFIG=/etc/kubernetes/admin.conf

echo "Installing flannel CNI..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Root keeps admin.conf; copy it for the chosen non-root user too
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config

kube_user="${1:-${SUDO_USER:-}}"
if [[ -n "$kube_user" ]]; then
    user_home=$(getent passwd "$kube_user" | cut -d: -f6)
    [[ -n "$user_home" ]] || { echo "Unknown user: $kube_user"; exit 1; }
    mkdir -p "$user_home/.kube"
    cp /etc/kubernetes/admin.conf "$user_home/.kube/config"
    chown -R "$kube_user:" "$user_home/.kube"
else
    echo "No user given; kubectl works as root only. Re-run the copy with: install -D -o USER -m 600 /etc/kubernetes/admin.conf ~USER/.kube/config"
fi

echo ""
echo "✓ Control plane ready. Run this on eastwoods and westwoods via 03-join-node.sh:"
kubeadm token create --print-join-command
