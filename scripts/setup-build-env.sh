#!/bin/bash
# =============================================================================
# ATLAZES OS - Build Environment Setup
# Run once on a fresh Debian/Ubuntu system before building the ISO.
# Usage: sudo ./scripts/setup-build-env.sh
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}[+]${NC} $*"; }
section() { echo -e "\n${CYAN}${BOLD}-- $* --${NC}\n"; }

[[ $EUID -ne 0 ]] && { echo "Run as root: sudo ./scripts/setup-build-env.sh"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

section "Setting Up ATLAZES OS Build Environment"

section "Updating System"
apt-get update -qq
apt-get upgrade -y

section "Installing Build Dependencies"
apt-get install -y \
    wget \
    curl \
    rsync \
    git \
    xorriso \
    squashfs-tools \
    isolinux \
    syslinux-common \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    dosfstools \
    librsvg2-bin \
    ca-certificates \
    debian-archive-keyring \
    apt-transport-https \
    gnupg

log "Build dependencies installed."

section "Setting Permissions"
chmod +x "${SCRIPT_DIR}/build.sh"
chmod +x "${SCRIPT_DIR}/scripts/"*.sh 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/scripts/hardening/"*.sh 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/scripts/privacy/"*.sh 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/customization/atlazes-tools/atlazes" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/customization/atlazes-tools/atlazes-firewall" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/customization/atlazes-tools/atlazes-privacy" 2>/dev/null || true

log "Permissions set."

section "Branding Assets"
log "Modern SVG assets live in ${SCRIPT_DIR}/assets and are converted during ./build.sh."

echo ""
echo -e "${GREEN}${BOLD}ATLAZES OS build environment is ready.${NC}"
echo "Run: sudo ./build.sh build"
