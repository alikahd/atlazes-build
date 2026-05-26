#!/bin/bash
# =============================================================================
# ATLAZES OS - Release Signing & Packaging Script
# Generates checksums, GPG signatures, and release manifest
# Usage: ./release-sign.sh [--gpg-key <key-id>] [--no-gpg]
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
section() { echo -e "\n${CYAN}${BOLD}── $* ──${NC}\n"; }

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${PROJECT_DIR}/output"
VERSION="2.0.0"
CODENAME="Horizon"
GPG_KEY=""
NO_GPG=false

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --gpg-key) GPG_KEY="$2"; shift ;;
        --no-gpg)  NO_GPG=true ;;
        *) warn "Unknown arg: $1" ;;
    esac
    shift
done

[[ -d "$OUTPUT_DIR" ]] || { echo "Output dir not found: $OUTPUT_DIR"; exit 1; }

section "ATLAZES OS Release Signing — v${VERSION} (${CODENAME})"

# ─── Find ISOs ────────────────────────────────────────────────────────────────
mapfile -t ISOS < <(find "$OUTPUT_DIR" -name "*.iso" -type f | sort)

if [[ ${#ISOS[@]} -eq 0 ]]; then
    echo "No ISO files found in $OUTPUT_DIR"
    echo "Run: sudo ./build.sh first"
    exit 1
fi

log "Found ${#ISOS[@]} ISO(s):"
for iso in "${ISOS[@]}"; do
    echo "  $(basename "$iso")  ($(du -sh "$iso" | cut -f1))"
done

# ─── Generate checksums ───────────────────────────────────────────────────────
section "Generating Checksums"
cd "$OUTPUT_DIR"

for iso in "${ISOS[@]}"; do
    name=$(basename "$iso")
    sha256sum "$name" > "${name}.sha256"
    md5sum    "$name" > "${name}.md5"
    log "Checksums: ${name}"
done

# Combined SHA256 file for all ISOs
sha256sum atlazes-os-*.iso > "SHA256SUMS" 2>/dev/null || true
log "Combined SHA256SUMS written."

# ─── GPG signing ──────────────────────────────────────────────────────────────
if [[ "$NO_GPG" == "false" ]]; then
    section "GPG Signing"

    if ! command -v gpg &>/dev/null; then
        warn "GPG not found. Skipping signing."
    elif [[ -z "$GPG_KEY" ]]; then
        warn "No GPG key specified. Use --gpg-key <key-id> to sign."
        warn "To create a key: gpg --full-generate-key"
        warn "To list keys:    gpg --list-secret-keys"
    else
        # Sign each ISO
        for iso in "${ISOS[@]}"; do
            name=$(basename "$iso")
            gpg --armor --detach-sign --local-user "$GPG_KEY" "$name"
            log "Signed: ${name}.asc"
        done

        # Sign the combined checksum file
        gpg --armor --detach-sign --local-user "$GPG_KEY" SHA256SUMS
        log "Signed: SHA256SUMS.asc"

        # Export public key
        gpg --armor --export "$GPG_KEY" > "atlazes-os-signing-key.asc"
        log "Public key exported: atlazes-os-signing-key.asc"
    fi
fi

# ─── Release manifest ─────────────────────────────────────────────────────────
section "Generating Release Manifest"
cat > "${OUTPUT_DIR}/RELEASE.txt" << EOF
ATLAZES OS v${VERSION} (${CODENAME})
Release Date: $(date -u +"%Y-%m-%d")
Base: Debian 13 (Trixie)
Architecture: amd64

EDITIONS:
$(for iso in "${ISOS[@]}"; do
    name=$(basename "$iso")
    size=$(du -sh "$iso" | cut -f1)
    sha=$(sha256sum "$iso" | cut -d' ' -f1)
    echo "  $name"
    echo "    Size:   $size"
    echo "    SHA256: $sha"
    echo ""
done)

VERIFICATION:
  sha256sum -c SHA256SUMS
  gpg --verify SHA256SUMS.asc SHA256SUMS

FLASH TO USB:
  sudo dd if=<iso-file> of=/dev/sdX bs=4M status=progress oflag=sync

DEFAULT CREDENTIALS (Live Session):
  Username: atlazes
  Password: atlazes
  (Change immediately after installation)

SECURITY FEATURES:
  - Full disk encryption (LUKS2) available during install
  - AppArmor mandatory access control
  - UFW firewall (deny all incoming by default)
  - Privacy DNS preset (Quad9 + Cloudflare)
  - MAC address randomization
  - Hardened kernel parameters
  - Firejail application sandboxing
  - Lightweight default package profile

DOCUMENTATION:
  README.md
  GitHub Releases

SUPPORT:
  https://github.com/atlazes/atlazes-os/issues
EOF

log "Release manifest: RELEASE.txt"

# ─── Summary ──────────────────────────────────────────────────────────────────
section "Release Package Complete"
echo ""
echo "Files in $OUTPUT_DIR:"
ls -lh "$OUTPUT_DIR"
echo ""
log "Release v${VERSION} ready."
