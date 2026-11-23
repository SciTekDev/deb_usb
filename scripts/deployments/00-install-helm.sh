#!/bin/bash
set -euo pipefail

# Run on northwoods as root (su -): installs helm to /usr/local/bin for the other deployment scripts.

if [[ $EUID -ne 0 ]]; then
    echo "Must run in a root login shell (use 'su -', NOT plain 'su'): bash $0"
    exit 1
fi

if command -v helm >/dev/null; then
    echo "helm already installed: $(helm version --short)"
    exit 0
fi

echo "Installing helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
echo "✓ $(helm version --short). Next, as your normal user: bash 01-platform.sh"
