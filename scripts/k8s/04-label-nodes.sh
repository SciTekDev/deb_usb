#!/bin/bash
set -euo pipefail

# Run on northwoods with kubectl access: label nodes by role and taint the GPU node

source "$(dirname "${BASH_SOURCE[0]}")/cluster.env"

for node in "${!NODE_ROLES[@]}"; do
    role="${NODE_ROLES[$node]}"
    kubectl label node "$node" "role=$role" --overwrite
    [[ "$role" == gpu ]] && kubectl taint node "$node" nvidia.com/gpu=present:NoSchedule --overwrite
done

# The control plane host also runs workloads
kubectl taint node "$CONTROL_PLANE_HOST" node-role.kubernetes.io/control-plane:NoSchedule- || true

kubectl get nodes --show-labels
