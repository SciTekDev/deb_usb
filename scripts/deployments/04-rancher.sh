#!/bin/bash
set -euo pipefail

# Deploy Rancher (cluster UI) via helm; requires 01-platform.sh

source "$(dirname "${BASH_SOURCE[0]}")/deployments.env"

helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

# Bootstrap password is generated and stored in a secret, not on the command line history
password=$(openssl rand -base64 18)

helm upgrade --install rancher rancher-stable/rancher \
    --namespace cattle-system --create-namespace \
    --set hostname="rancher.$DOMAIN" \
    --set ingress.ingressClassName=nginx \
    --set replicas=1 \
    --set bootstrapPassword="$password" \
    --set nodeSelector.role=web

kubectl -n cattle-system rollout status deploy/rancher --timeout=15m

echo "✓ https://rancher.$DOMAIN (self-signed cert)"
echo "Bootstrap password: $password"
