#!/bin/bash
set -euo pipefail

# Run on a Dell PowerEdge R720 (iDRAC7): install a small fan controller that sets fan speed from
# CPU/GPU/inlet temperatures through IPMI, and hands control back to the iDRAC when it stops or gets hot.
# Also make sure BIOS System Profile is "Performance Per Watt (OS)" so the OS governor is honoured.
#
# Revert at any time: systemctl disable --now dell-fan-control; ipmitool raw 0x30 0x30 0x01 0x01

if [[ $EUID -ne 0 ]]; then
    echo "Run as root (su -): bash $0"
    exit 1
fi

apt update
apt install -y ipmitool lm-sensors dmidecode pciutils

model=$(dmidecode -s system-product-name)
if [[ "$model" != "PowerEdge R720" ]]; then
    echo "This script targets the PowerEdge R720 (found: $model); the IPMI fan commands differ on other models."
    exit 1
fi

echo "ipmi_si
ipmi_devintf" > /etc/modules-load.d/ipmi.conf
modprobe ipmi_si
modprobe ipmi_devintf

cat > /etc/dell-fan-control.conf <<'EOF'
# Fan speed percent by hottest temperature (CPU, or GPU minus GPU_OFFSET), degrees C
T1=50; P1=20
T2=60; P2=30
T3=70; P3=45
T4=80; P4=65
# Above T4, or if the inlet gets this warm, the iDRAC automatic control takes over
INLET_AUTO_ABOVE=32
GPU_OFFSET=0
INTERVAL=15
EOF

cat > /usr/local/sbin/dell-fan-control <<'EOF'
#!/bin/bash
set -u
source /etc/dell-fan-control.conf

auto() { ipmitool raw 0x30 0x30 0x01 0x01 >/dev/null 2>&1 || true; }
manual() {
    printf -v hex '0x%02x' "$1"
    ipmitool raw 0x30 0x30 0x01 0x00 >/dev/null 2>&1 && ipmitool raw 0x30 0x30 0x02 0xff "$hex" >/dev/null 2>&1
}
trap 'auto; exit 0' TERM INT

while true; do
    sdr=$(ipmitool sdr type Temperature 2>/dev/null) || { auto; sleep "$INTERVAL"; continue; }

    cpu=$(awk -F'|' '$1 ~ /^Temp *$/ { gsub(/[^0-9]/, "", $5); if ($5 + 0 > m) m = $5 + 0 } END { print m + 0 }' <<<"$sdr")
    inlet=$(awk -F'|' '$1 ~ /^Inlet Temp/ { gsub(/[^0-9]/, "", $5); print $5 + 0; exit }' <<<"$sdr")

    t=$cpu
    if lspci -d 10de: 2>/dev/null | grep -q .; then
        gpu=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | sort -n | tail -1)
        # A passively cooled GPU is fitted but not readable, so leave cooling to the iDRAC
        [[ -n "$gpu" ]] || { auto; sleep "$INTERVAL"; continue; }
        gpu=$(( gpu - GPU_OFFSET ))
        (( gpu > t )) && t=$gpu
    fi

    # No CPU reading means parsing failed; do not run blind
    if (( cpu == 0 )) || (( ${inlet:-0} >= INLET_AUTO_ABOVE )) || (( t > T4 )); then
        auto
    elif (( t <= T1 )); then manual "$P1"
    elif (( t <= T2 )); then manual "$P2"
    elif (( t <= T3 )); then manual "$P3"
    else manual "$P4"
    fi
    sleep "$INTERVAL"
done
EOF
chmod 755 /usr/local/sbin/dell-fan-control

cat > /etc/systemd/system/dell-fan-control.service <<'EOF'
[Unit]
Description=Dell R720 temperature-based fan control
After=multi-user.target

[Service]
ExecStart=/usr/local/sbin/dell-fan-control
ExecStopPost=/usr/bin/ipmitool raw 0x30 0x30 0x01 0x01
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now dell-fan-control

echo "✓ Fan control running. Watch it with: ipmitool sdr type Fan; journalctl -u dell-fan-control"
echo "If the OS hangs or loses power the iDRAC keeps the last manual speed until it is reset; the curve never goes below ${P1:-20}%."
