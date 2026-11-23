#!/bin/bash
set -euo pipefail

# Debian USB Net-Install ISO Downloader
# Downloads the latest Debian net-install ISO for x86_64 architecture
# Or uses the pre-downloaded debian-13.8.0-amd64-netinst.iso

# Configuration
DEBIAN_VERSION="${DEBIAN_VERSION:-13.8.0}"  # Default to pre-downloaded 13.8.0
ARCH="amd64"
MIRROR="${DEBIAN_MIRROR:-https://cdimage.debian.org}"
OUTPUT_DIR="${OUTPUT_DIR:-.}"

# Functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    echo "[ERROR] $*" >&2
    exit 1
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Create a Debian net-install ISO download for x86_64 servers.

NOTE: Pre-downloaded ISO available: debian-13.8.0-amd64-netinst.iso (758MB)
This script can download other versions if needed.

Options:
  -v, --version VERSION    Debian version (default: 13.8.0 - uses pre-downloaded)
                           Supported: forky, sid, testing, stable,
                                     11, 12, 13, 13.8.0
  -o, --output DIR         Output directory for ISO (default: current dir)
  -m, --mirror URL         Debian mirror URL (default: cdimage.debian.org)
  -h, --help               Show this help message

Examples:
  $0                              # Uses pre-downloaded debian-13.8.0-amd64-netinst.iso
  $0 -v 12                        # Download Debian 12 (Bookworm)
  $0 -v testing -o /tmp           # Download Debian testing to /tmp

EOF
    exit 0
}

find_iso() {
    local search_version="$1"
    
    # First check for exact match in current directory
    if [[ -f "debian-${search_version}-${ARCH}-netinst.iso" ]]; then
        echo "debian-${search_version}-${ARCH}-netinst.iso"
        return 0
    fi
    
    # For 13.8.0, also check for pre-downloaded version
    if [[ "$search_version" == "13.8.0" ]] && [[ -f "debian-13.8.0-${ARCH}-netinst.iso" ]]; then
        echo "debian-13.8.0-${ARCH}-netinst.iso"
        return 0
    fi
    
    # Search for any matching ISO with wildcards
    find . -maxdepth 1 -name "debian-${search_version}*${ARCH}-netinst.iso" -type f 2>/dev/null | head -1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--version) DEBIAN_VERSION="$2"; shift 2 ;;
        -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
        -m|--mirror) MIRROR="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) error "Unknown option: $1" ;;
    esac
done

# Validate output directory
if [[ ! -d "$OUTPUT_DIR" ]]; then
    mkdir -p "$OUTPUT_DIR" || error "Cannot create output directory: $OUTPUT_DIR"
fi

# Check if ISO already exists (for pre-downloaded versions)
if ISO_PATH=$(find_iso "$DEBIAN_VERSION"); then
    log "✓ ISO already exists: $ISO_PATH"
    log "File size: $(du -h "$ISO_PATH" | cut -f1)"
    log "Ready to use with: ./scripts/create-usb.sh /dev/sdX"
    exit 0
fi

log "Downloading Debian $DEBIAN_VERSION net-install ISO..."
log "Output directory: $OUTPUT_DIR"
log "Architecture: $ARCH"

# Construct URLs - support all Debian versions
ISO_NAME="debian-${DEBIAN_VERSION}-netinst-${ARCH}.iso"
ISO_PATH="${OUTPUT_DIR}/${ISO_NAME}"

log "Attempting to download ISO from official Debian mirrors..."

# For forky/sid/testing, use daily builds or current
# For stable/numbered releases, use release images
if [[ "$DEBIAN_VERSION" == "forky" ]] || [[ "$DEBIAN_VERSION" == "sid" ]]; then
    # Try daily builds first for unstable
    if wget -q --show-progress -O "$ISO_PATH" "https://cdimage.debian.org/cdimage/daily-builds/daily/current/$ARCH/iso-cd/debian-daily-*.0-$ARCH-netinst.iso" 2>/dev/null && [[ -s "$ISO_PATH" ]]; then
        log "Downloaded daily build"
    elif wget -q --show-progress -O "$ISO_PATH" "https://cdimage.debian.org/cdimage/release/current/$ARCH/iso-cd/debian-*-$ARCH-netinst.iso" 2>/dev/null && [[ -s "$ISO_PATH" ]]; then
        log "Downloaded from release archive"
    else
        error "Failed to find Debian $DEBIAN_VERSION net-install ISO"
    fi
elif [[ "$DEBIAN_VERSION" == "testing" ]]; then
    # Testing branch
    if wget -q --show-progress -O "$ISO_PATH" "https://cdimage.debian.org/cdimage/release/current/$ARCH/iso-cd/debian-*-$ARCH-netinst.iso" 2>/dev/null && [[ -s "$ISO_PATH" ]]; then
        log "Downloaded testing branch"
    else
        error "Failed to find Debian testing net-install ISO"
    fi
else
    # Stable/numbered releases (11, 12, 13, stable, 13.8.0)
    if wget -q --show-progress -O "$ISO_PATH" "https://cdimage.debian.org/debian-cd/current/$ARCH/iso-cd/debian-*.0-$ARCH-netinst.iso" 2>/dev/null && [[ -s "$ISO_PATH" ]]; then
        log "Downloaded stable/current release"
    elif wget -q --show-progress -O "$ISO_PATH" "https://cdimage.debian.org/debian-cd/${DEBIAN_VERSION}*/$ARCH/iso-cd/debian-${DEBIAN_VERSION}*-$ARCH-netinst.iso" 2>/dev/null && [[ -s "$ISO_PATH" ]]; then
        log "Downloaded version-specific release"
    else
        error "Failed to find Debian $DEBIAN_VERSION net-install ISO"
    fi
fi

if [[ ! -f "$ISO_PATH" ]] || [[ ! -s "$ISO_PATH" ]]; then
    error "ISO download failed or incomplete: $ISO_PATH"
fi

log "✓ ISO downloaded: $ISO_PATH"
log "File size: $(du -h "$ISO_PATH" | cut -f1)"
log "Debian version: $DEBIAN_VERSION"
log "Next step: Run './scripts/create-usb.sh /dev/sdX' to create USB media"
