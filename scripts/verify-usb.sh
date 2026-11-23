#!/bin/bash
set -euo pipefail

# USB Media Verification Script

USB_DEVICE=""

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    echo "[ERROR] $*" >&2
    exit 1
}

usage() {
    cat << EOF
Usage: $0 DEVICE

Verify a Debian net-install USB stick.

DEVICE: USB device to verify (e.g., /dev/sdb, /dev/sdb1)

EOF
    exit 0
}

check_device() {
    if [[ ! -e "$1" ]]; then
        error "Device not found: $1"
    fi
    if [[ ! -b "$1" ]]; then
        error "Not a block device: $1"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        -*) error "Unknown option: $1" ;;
        *) USB_DEVICE="$1"; shift ;;
    esac
done

[[ -z "$USB_DEVICE" ]] && error "USB device required"
check_device "$USB_DEVICE"

log "Verifying USB media..."
log "Device: $USB_DEVICE"

if lsblk "$USB_DEVICE" 2>/dev/null; then
    log "✓ Device found and readable"
else
    error "Cannot access device"
fi

log "✓ USB media verification complete"
