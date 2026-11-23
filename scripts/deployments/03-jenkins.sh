#!/bin/bash
set -euo pipefail

# Deploy Jenkins LTS alongside GitLab

source "$(dirname "${BASH_SOURCE[0]}")/deployments.env"
export DOMAIN

envsubst '${DOMAIN}' < "$(dirname "${BASH_SOURCE[0]}")/manifests/jenkins.yaml" | kubectl apply -f -

kubectl -n jenkins rollout status deploy/jenkins --timeout=10m

echo "✓ http://jenkins.$DOMAIN"
echo "Initial admin password:"
kubectl -n jenkins exec deploy/jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword
