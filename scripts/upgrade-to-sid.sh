#!/bin/bash
set -euo pipefail

# Upgrade from Debian 13.8.0 (trixie) to Debian sid/forky

if [[ $EUID -ne 0 ]]; then
    echo "Run as root (su -): bash $0"
    exit 1
fi

echo "⚠️  Upgrading to Debian sid (unstable)"
read -p "Continue? (yes/no): " confirm
[[ "$confirm" == "yes" ]] || exit 0

# Backup current sources.list
cp /etc/apt/sources.list /etc/apt/sources.list.backup

# Update to sid
cat > /etc/apt/sources.list << 'SOURCES'
deb http://deb.debian.org/debian sid main contrib non-free non-free-firmware
SOURCES

echo "Updating packages..."
apt update
apt upgrade -y
apt full-upgrade -y
apt autoremove -y

echo "✓ Done. Verify with: grep VERSION_CODENAME /etc/os-release"
