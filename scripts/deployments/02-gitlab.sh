#!/bin/bash
set -euo pipefail

# Deploy GitLab CE (omnibus, single pod) on the web node

source "$(dirname "${BASH_SOURCE[0]}")/deployments.env"
export DOMAIN GITLAB_DATA_PATH

envsubst '${DOMAIN} ${GITLAB_DATA_PATH}' < "$(dirname "${BASH_SOURCE[0]}")/manifests/gitlab.yaml" | kubectl apply -f -

echo "Waiting for GitLab (first start takes several minutes)..."
kubectl -n gitlab rollout status deploy/gitlab --timeout=15m

echo "✓ http://gitlab.$DOMAIN  (ssh on node port 30022)"
echo "Initial root password (valid 24h):"
kubectl -n gitlab exec deploy/gitlab -- grep '^Password:' /etc/gitlab/initial_root_password
