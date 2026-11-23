#!/bin/bash
set -euo pipefail

# Run on every node: kernel prereqs, containerd, kubeadm/kubelet/kubectl, /etc/hosts

if [[ $EUID -ne 0 ]]; then
    echo "Run as root (su -): bash $0"
    exit 1
fi

source "$(dirname "${BASH_SOURCE[0]}")/cluster.env"
require_node_ip

echo "Disabling swap..."
swapoff -a
sed -i '/\sswap\s/ s/^/#/' /etc/fstab

echo "Loading kernel modules..."
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

cat > /etc/sysctl.d/99-k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system >/dev/null

echo "Updating /etc/hosts..."
# Drop Debian's 127.0.1.1 self-mapping and any stale entries so names resolve to the real IPs
for name in "${!NODE_IPS[@]}"; do
    sed -i "/[[:space:]]$name\$/d" /etc/hosts
    echo "${NODE_IPS[$name]} $name.$SEARCH_DOMAIN $name" >> /etc/hosts
done

echo "Installing containerd..."
apt update
apt install -y containerd apt-transport-https ca-certificates curl gpg nfs-common
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl enable containerd
systemctl restart containerd

echo "Installing kubeadm, kubelet, kubectl ($K8S_VERSION)..."
mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" \
    | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" \
    > /etc/apt/sources.list.d/kubernetes.list
apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

# Pin the cluster IP so a multi-NIC node never registers with one of its extra addresses
echo "KUBELET_EXTRA_ARGS=--node-ip=${NODE_IPS[$(hostname -s)]}" > /etc/default/kubelet

echo "✓ Node prepared. Next: 02-init-control-plane.sh (northwoods) or 03-join-node.sh (others)"
