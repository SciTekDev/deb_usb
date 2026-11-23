#!/bin/bash
set -euo pipefail

# Run on each node after setting its hostname: switch every NIC from DHCP to its static IP.
# NIC 0 is the one holding the default route and gets the cluster (primary) IP, gateway and DNS;
# the remaining physical NICs follow in name order with the extra IPs from NODE_NIC_IPS.
# Supports NetworkManager and ifupdown. Takes effect on reboot so an SSH session is not cut mid-script.

if [[ $EUID -ne 0 ]]; then
    echo "Run as root (su -): bash $0"
    exit 1
fi

source "$(dirname "${BASH_SOURCE[0]}")/cluster.env"

name=$(hostname -s)
[[ -n "${NODE_NIC_IPS[$name]:-}" ]] || { echo "Hostname '$name' is not one of: ${!NODE_NIC_IPS[*]}"; exit 1; }
read -r -a ips <<< "${NODE_NIC_IPS[$name]}"

primary_nic=$(ip -o -4 route show default | awk '{print $5; exit}')
[[ -n "$primary_nic" ]] || { echo "No default route; cannot detect the network interface"; exit 1; }

mapfile -t others < <(
    for d in /sys/class/net/*; do
        n=${d##*/}
        [[ -e "$d/device" && ! -e "$d/wireless" && "$n" != "$primary_nic" ]] && echo "$n"
    done | sort
)
nics=("$primary_nic" "${others[@]}")

if (( ${#nics[@]} < ${#ips[@]} )); then
    echo "Found ${#nics[@]} NICs (${nics[*]}), expected ${#ips[@]}; only the first ${#nics[@]} IPs will be assigned"
fi

echo "Host: $name  gateway $GATEWAY  dns $DNS_SERVERS  search $SEARCH_DOMAIN"
for i in "${!nics[@]}"; do
    echo "  ${nics[$i]} -> ${ips[$i]}/$PREFIX$([[ $i -eq 0 ]] && echo '  (primary, default route)')"
done
read -p "Continue? (yes/no): " confirm
[[ "$confirm" == "yes" ]] || exit 0

# Same-subnet NICs: answer ARP only on the owning interface and use loose reverse-path filtering
cat > /etc/sysctl.d/98-multi-nic.conf <<EOF
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
EOF

if command -v nmcli >/dev/null && nmcli -t -f RUNNING general 2>/dev/null | grep -q running; then
    old_conn=$(nmcli -t -f NAME,DEVICE connection show --active | awk -F: -v d="$primary_nic" '$2==d {print $1; exit}')
    [[ -z "$old_conn" ]] || nmcli connection modify "$old_conn" connection.autoconnect no
    for i in "${!nics[@]}"; do
        nic="${nics[$i]}"
        nmcli connection delete "k8s-$nic" >/dev/null 2>&1 || true
        if [[ $i -eq 0 ]]; then
            nmcli connection add type ethernet ifname "$nic" con-name "k8s-$nic" \
                ipv4.method manual ipv4.addresses "${ips[$i]}/$PREFIX" \
                ipv4.gateway "$GATEWAY" ipv4.dns "${DNS_SERVERS// /,}" ipv4.dns-search "$SEARCH_DOMAIN" \
                ipv6.method ignore >/dev/null
        else
            nmcli connection add type ethernet ifname "$nic" con-name "k8s-$nic" \
                ipv4.method manual ipv4.addresses "${ips[$i]}/$PREFIX" ipv4.never-default yes \
                ipv6.method ignore >/dev/null
        fi
    done
elif [[ -f /etc/network/interfaces ]] && grep -qs '^source.*interfaces.d' /etc/network/interfaces; then
    cp /etc/network/interfaces /etc/network/interfaces.backup
    for nic in "${nics[@]}"; do
        sed -i "/^\(auto\|allow-hotplug\) $nic\$/d; /^iface $nic inet dhcp/d" /etc/network/interfaces
    done
    {
        for i in "${!nics[@]}"; do
            echo "auto ${nics[$i]}"
            echo "iface ${nics[$i]} inet static"
            echo "    address ${ips[$i]}/$PREFIX"
            if [[ $i -eq 0 ]]; then
                echo "    gateway $GATEWAY"
                echo "    dns-nameservers $DNS_SERVERS"
                echo "    dns-search $SEARCH_DOMAIN"
            fi
            echo
        done
    } > /etc/network/interfaces.d/k8s-nics
    # Static config no longer gets DNS from DHCP
    if [[ ! -L /etc/resolv.conf ]] && ! command -v resolvconf >/dev/null; then
        { echo "search $SEARCH_DOMAIN"; for ns in $DNS_SERVERS; do echo "nameserver $ns"; done; } > /etc/resolv.conf
    fi
else
    echo "Neither NetworkManager nor an ifupdown setup with interfaces.d was found; set the addresses manually."
    exit 1
fi

echo "✓ Static IPs configured. Reboot to apply, then check: ip -4 -br addr"
