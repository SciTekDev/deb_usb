#!/bin/bash
set -euo pipefail

# Run on westwoods: NVIDIA driver + container toolkit configured for containerd.
# Debian non-free repos must be enabled (see upgrade-to-sid.sh / sources).

if [[ $EUID -ne 0 ]]; then
    echo "Run as root (su -): bash $0"
    exit 1
fi

source "$(dirname "${BASH_SOURCE[0]}")/cluster.env"
require_node_ip
require_role gpu

echo "Installing NVIDIA driver..."
apt update
# Kepler (K80) is only supported by the 470 legacy branch, which Debian ships in sid
if lspci -d 10de: | grep -qiE 'GK210|Tesla K80'; then
    apt-cache show nvidia-tesla-470-driver >/dev/null 2>&1 || {
        echo "nvidia-tesla-470-driver not found; the K80 needs Debian sid with contrib and non-free enabled"
        exit 1
    }
    drivers="nvidia-tesla-470-driver nvidia-tesla-470-smi"
else
    drivers="nvidia-driver"
fi
apt install -y linux-headers-amd64 $drivers firmware-misc-nonfree
# Debian's nvidia-persistenced (550) cannot manage the legacy 470 driver, so set persistence mode with nvidia-smi at boot
cat > /etc/systemd/system/nvidia-persistence.service <<EOF
[Unit]
Description=Enable NVIDIA persistence mode
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/nvidia-smi -pm 1
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable nvidia-persistence.service

echo "Installing NVIDIA container toolkit..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    > /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt update
apt install -y nvidia-container-toolkit

nvidia-ctk runtime configure --runtime=containerd --set-as-default
# Toolkit 'auto' mode misses Debian's relocated 470 libraries (no libnvidia-ml in containers); legacy mode finds them
sed -i 's/^mode = "auto"/mode = "legacy"/' /etc/nvidia-container-runtime/config.toml
systemctl restart containerd

echo "✓ Reboot, then verify with nvidia-smi."
echo "Then on northwoods: kubectl apply -f k8s/manifests/nvidia-device-plugin.yaml"
