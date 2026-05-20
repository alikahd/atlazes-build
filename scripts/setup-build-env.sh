#!/bin/bash
# =============================================================================
# ATLAZES OS - Build Environment Setup
# Run this ONCE on a fresh Debian/Ubuntu system to prepare for building
# Usage: sudo ./scripts/setup-build-env.sh
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}[+]${NC} $*"; }
section() { echo -e "\n${CYAN}${BOLD}── $* ──${NC}\n"; }

[[ $EUID -ne 0 ]] && { echo "Run as root: sudo ./scripts/setup-build-env.sh"; exit 1; }

section "Setting Up ATLAZES OS Build Environment"

# ─── Update system ────────────────────────────────────────────────────────────
section "Updating System"
apt-get update -qq
apt-get upgrade -y

# ─── Install build dependencies ───────────────────────────────────────────────
section "Installing Build Dependencies"
apt-get install -y \
    live-build \
    debootstrap \
    squashfs-tools \
    xorriso \
    isolinux \
    syslinux-efi \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-amd64-signed \
    mtools \
    dosfstools \
    git \
    curl \
    wget \
    rsync \
    imagemagick \
    python3 \
    python3-pip \
    debian-archive-keyring \
    apt-transport-https \
    ca-certificates \
    gnupg

log "Build dependencies installed."

# ─── Make scripts executable ──────────────────────────────────────────────────
section "Setting Permissions"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

chmod +x "${SCRIPT_DIR}/build.sh"
chmod +x "${SCRIPT_DIR}/scripts/"*.sh 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/scripts/hardening/"*.sh 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/scripts/privacy/"*.sh 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/branding/assets/create-assets.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/config/includes.chroot/usr/local/bin/atlazes-tools" 2>/dev/null || true

log "Permissions set."

# ─── Generate branding assets ─────────────────────────────────────────────────
section "Generating Branding Assets"
bash "${SCRIPT_DIR}/branding/assets/create-assets.sh" 2>/dev/null || true

# Copy wallpapers to includes.chroot
mkdir -p "${SCRIPT_DIR}/config/includes.chroot/usr/share/atlazes/wallpapers"
mkdir -p "${SCRIPT_DIR}/config/includes.chroot/usr/share/atlazes/icons"

if [[ -f "${SCRIPT_DIR}/branding/assets/wallpaper-1920x1080.png" ]]; then
    cp "${SCRIPT_DIR}/branding/assets/wallpaper-1920x1080.png" \
       "${SCRIPT_DIR}/config/includes.chroot/usr/share/atlazes/wallpapers/atlazes-default.png"
    cp "${SCRIPT_DIR}/branding/assets/wallpaper-login.png" \
       "${SCRIPT_DIR}/config/includes.chroot/usr/share/atlazes/wallpapers/atlazes-login.png" 2>/dev/null || true
    log "Wallpapers copied."
fi

if [[ -f "${SCRIPT_DIR}/branding/assets/logo.png" ]]; then
    cp "${SCRIPT_DIR}/branding/assets/logo.png" \
       "${SCRIPT_DIR}/config/includes.chroot/usr/share/atlazes/icons/atlazes-logo.png"
    log "Logo copied."
fi

# Copy Calamares branding assets
mkdir -p "${SCRIPT_DIR}/calamares/branding/atlazes"
if [[ -f "${SCRIPT_DIR}/branding/assets/logo.png" ]]; then
    cp "${SCRIPT_DIR}/branding/assets/logo.png" \
       "${SCRIPT_DIR}/calamares/branding/atlazes/logo.png"
    cp "${SCRIPT_DIR}/branding/assets/logo-128.png" \
       "${SCRIPT_DIR}/calamares/branding/atlazes/icon.png" 2>/dev/null || true
    cp "${SCRIPT_DIR}/branding/assets/wallpaper-1920x1080.png" \
       "${SCRIPT_DIR}/calamares/branding/atlazes/welcome.png" 2>/dev/null || true
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   Build Environment Ready!                   ║"
echo "  ╠══════════════════════════════════════════════╣"
echo "  ║  Run the build:                              ║"
echo "  ║    sudo ./build.sh                           ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"
