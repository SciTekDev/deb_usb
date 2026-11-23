#!/bin/bash
set -euo pipefail

# Run on northwoods as your normal user (kubectl configured).
# Installs ingress-nginx (hostNetwork on the web node), cert-manager,
# and an NFS-backed default StorageClass. Needs helm: run 00-install-helm.sh as root first.

source "$(dirname "${BASH_SOURCE[0]}")/deployments.env"

if ! command -v helm >/dev/null; then
    echo "helm is not installed. As root (su -) on northwoods run: bash 00-install-helm.sh"
    exit 1
fi

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo add nfs-subdir https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update

echo "Installing NFS provisioner..."
helm upgrade --install nfs-provisioner nfs-subdir/nfs-subdir-external-provisioner \
    --namespace kube-system \
    --set nfs.server="$NFS_SERVER" \
    --set nfs.path="$NFS_PATH" \
    --set storageClass.name=nfs \
    --set storageClass.defaultClass=true \
    --set nodeSelector.role=storage

echo "Installing ingress-nginx on the web node..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --set controller.kind=DaemonSet \
    --set controller.hostNetwork=true \
    --set controller.dnsPolicy=ClusterFirstWithHostNet \
    --set controller.service.type=ClusterIP \
    --set controller.nodeSelector.role=web \
    --set controller.admissionWebhooks.enabled=false

echo "Installing cert-manager..."
helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace \
    --set crds.enabled=true

echo "✓ Platform ready. Next: 02-gitlab.sh"
