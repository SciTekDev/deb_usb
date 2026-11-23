#!/bin/bash
set -euo pipefail

# Run on eastwoods/westwoods. Usage: 03-join-node.sh "<kubeadm join ...>"

if [[ $EUID -ne 0 ]]; then
    echo "Run as root (su -): bash $0 \"<kubeadm join command>\""
    exit 1
fi

source "$(dirname "${BASH_SOURCE[0]}")/cluster.env"
require_node_ip

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 \"kubeadm join $CONTROL_PLANE_IP:6443 --token ... --discovery-token-ca-cert-hash sha256:...\""
    exit 1
fi

# Only accept a join to this cluster's control plane, by IP or hostname
escaped_ip="${CONTROL_PLANE_IP//./\\.}"
escaped_host="${CONTROL_PLANE_HOST//./\\.}"
[[ "$1" =~ ^kubeadm\ join\ ($escaped_ip|$escaped_host(\.${SEARCH_DOMAIN//./\\.})?):6443\ --token\ [a-z0-9.]+\ --discovery-token-ca-cert-hash\ sha256:[a-f0-9]+$ ]] || {
    echo "Unexpected join command (expected target $CONTROL_PLANE_IP or $CONTROL_PLANE_HOST)"
    exit 1
}

read -r -a args <<< "$1"
"${args[@]}"

echo "✓ Joined. Next, on northwoods: 04-label-nodes.sh"
