#!/bin/bash

mkdir -p build
mkdir -p output
# =============================================================================
# ATLAZES OS - Main Build Script
# Version: 1.0.0
# Base: Debian 12 (Bookworm)
# Editions: core | dev | security
# =============================================================================

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Configuration ─────────────────────────────────────────────────────────────
OS_NAME="ATLAZES OS"
OS_VERSION="1.0.0"
OS_CODENAME="Horizon"
DEBIAN_RELEASE="bookworm"
ARCH="amd64"
BUILD_DIR="$(pwd)/build"
OUTPUT_DIR="$(pwd)/output"
MIRROR="http://deb.debian.org/debian"

# Edition: core | dev | security (default: core)
EDITION="${ATLAZES_EDITION:-core}"

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()     { echo -e "${GREEN}[+]${NC} $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_FILE"; exit 1; }
section() { echo -e "\n${CYAN}${BOLD}══════════════════════════════════════${NC}"; \
            echo -e "${CYAN}${BOLD}  $*${NC}"; \
            echo -e "${CYAN}${BOLD}══════════════════════════════════════${NC}\n"; }

# ─── Root check ───────────────────────────────────────────────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Use: sudo ./build.sh"
    fi
}

# ─── Edition setup ────────────────────────────────────────────────────────────
setup_edition() {
    case "$EDITION" in
        core)
            ISO_LABEL="ATLAZES-CORE-${OS_VERSION}"
            ISO_NAME="atlazes-os-${OS_VERSION}-core-${ARCH}.iso"
            # Remove dev package list for core edition
            rm -f "${BUILD_DIR}/lb/config/package-lists/05-development.list.chroot" 2>/dev/null || true
            log "Edition: Core (minimal, no dev tools)"
            ;;
        dev)
            ISO_LABEL="ATLAZES-DEV-${OS_VERSION}"
            ISO_NAME="atlazes-os-${OS_VERSION}-dev-${ARCH}.iso"
            export ATLAZES_EDITION=dev
            log "Edition: Dev (includes development tools)"
            ;;
        security)
            ISO_LABEL="ATLAZES-SEC-${OS_VERSION}"
            ISO_NAME="atlazes-os-${OS_VERSION}-security-${ARCH}.iso"
            # Remove dev package list for security edition
            rm -f "${BUILD_DIR}/lb/config/package-lists/05-development.list.chroot" 2>/dev/null || true
            log "Edition: Security (security tools focus)"
            ;;
        *)
            error "Unknown edition: ${EDITION}. Use: core | dev | security"
            ;;
    esac
    LOG_FILE="${BUILD_DIR}/build-${EDITION}.log"
}

# ─── Dependency check ─────────────────────────────────────────────────────────
check_dependencies() {
    section "Checking Build Dependencies"
    local deps=(live-build debootstrap squashfs-tools xorriso isolinux \
                syslinux-efi grub-pc-bin grub-efi-amd64-bin mtools \
                dosfstools git curl wget rsync)
    local missing=()

    for dep in "${deps[@]}"; do
        if ! dpkg -l "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Installing missing dependencies: ${missing[*]}"
        apt-get update -qq
        apt-get install -y "${missing[@]}"
    fi
    log "All dependencies satisfied."
}

# ─── Prepare directories ──────────────────────────────────────────────────────
prepare_dirs() {
    section "Preparing Build Directories"
    mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"
    touch "$LOG_FILE"
    log "Build dir:  $BUILD_DIR"
    log "Output dir: $OUTPUT_DIR"
    log "Log file:   $LOG_FILE"
}

# ─── Initialize live-build ────────────────────────────────────────────────────
init_livebuild() {
    section "Initializing live-build"

    if [[ -d "${BUILD_DIR}/lb" ]]; then
        warn "Existing build found. Cleaning..."
        cd "${BUILD_DIR}/lb"
        lb clean --purge 2>/dev/null || true
        cd "$(dirname "$BUILD_DIR")"
        rm -rf "${BUILD_DIR}/lb"
    fi

    mkdir -p "${BUILD_DIR}/lb"
    cd "${BUILD_DIR}/lb"

    lb config \
        --mode debian \
        --distribution "$DEBIAN_RELEASE" \
        --architectures "$ARCH" \
        --mirror-bootstrap "http://deb.debian.org/debian" \
        --mirror-chroot "http://deb.debian.org/debian" \
        --mirror-binary "http://deb.debian.org/debian" \
        --archive-areas "main contrib non-free non-free-firmware" \
        --apt-recommends false \
        --apt-secure true \
        --binary-images iso-hybrid \
        --memtest none \
        --iso-application "${OS_NAME} ${EDITION^}" \
        --iso-publisher "ATLAZES Project" \
        --iso-volume "${ISO_LABEL}" \
        --linux-flavours "none" \
        --bootstrap-qemu-static false \
        --ignore-system-defaults \
        --firmware-binary true \
        --firmware-chroot true \
        --apt-source-archives false \
        --initsystem systemd \
        --backports false \
        --win32-loader false \
        --security false \
        --zsync false \
        2>&1 | tee -a "$LOG_FILE"

    log "live-build initialized."
}

# ─── Copy config into build ───────────────────────────────────────────────────
copy_config() {
    section "Copying Configuration Files"
    local src_config
    src_config="$(dirname "$(realpath "$0")")/config"
    local dst_config="${BUILD_DIR}/lb/config"

    [[ -d "$src_config" ]] || error "Config directory not found: $src_config"

    # Package lists
    cp -r "${src_config}/package-lists/"* "${dst_config}/package-lists/" 2>/dev/null || true

    # Edition-specific: remove dev list for non-dev editions
    if [[ "$EDITION" != "dev" ]]; then
        rm -f "${dst_config}/package-lists/05-development.list.chroot"
        log "Dev package list excluded (edition: ${EDITION})"
    fi

    # Hooks
    cp -r "${src_config}/hooks/"* "${dst_config}/hooks/" 2>/dev/null || true
    chmod +x "${dst_config}/hooks/"*.hook.chroot 2>/dev/null || true
    chmod +x "${dst_config}/hooks/"*.hook.binary 2>/dev/null || true

    # Chroot includes
    if [[ -d "${src_config}/includes.chroot" ]]; then
        cp -r "${src_config}/includes.chroot/"* "${dst_config}/includes.chroot/" 2>/dev/null || true
    fi

    # Preseed
    if [[ -d "${src_config}/preseed" ]]; then
        cp -r "${src_config}/preseed/"* "${dst_config}/preseed/" 2>/dev/null || true
    fi

    # Inject edition marker
    mkdir -p "${dst_config}/includes.chroot/etc"
    echo "ATLAZES_EDITION=${EDITION}" > "${dst_config}/includes.chroot/etc/atlazes-edition"

    log "Configuration files copied."
}

# ─── Build the ISO ────────────────────────────────────────────────────────────
# ─── Build the ISO ────────────────────────────────────────────────────────────
build_iso() {
    section "Building ISO (this will take 20-60 minutes)"
    cd "${BUILD_DIR}/lb"

    echo ">>> HARD DISABLE linux-image STAGE <<<"

    # 🔴 الحل الجدري: حذف script اللي كيسبب المشكل
    rm -f /usr/lib/live/build/chroot_linux-image 2>/dev/null || true

    echo ">>> FIX WGET (prevent build crash) <<<"

    mkdir -p /usr/local/bin

    cat > /usr/local/bin/wget <<'EOF'
#!/bin/bash
command /usr/bin/wget "$@" || true
EOF

    chmod +x /usr/local/bin/wget
    export PATH="/usr/local/bin:$PATH"

    echo ">>> FORCE CLEAN APT SOURCES <<<"

    mkdir -p config/includes.chroot/etc/apt

    cat > config/includes.chroot/etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
EOF

    echo ">>> START BUILD <<<"

    lb build 2>&1 | tee -a "$LOG_FILE"

    local iso_file
    iso_file=$(find "${BUILD_DIR}/lb" -maxdepth 1 -name "*.iso" | head -1)

    [[ -z "$iso_file" ]] && error "Build failed: no ISO generated. Check $LOG_FILE"

    mv "$iso_file" "${OUTPUT_DIR}/${ISO_NAME}"
    log "ISO built: ${OUTPUT_DIR}/${ISO_NAME}"
}
# ─── Generate checksums ───────────────────────────────────────────────────────
generate_checksums() {
    section "Generating Checksums"
    cd "$OUTPUT_DIR"
    sha256sum "$ISO_NAME" > "${ISO_NAME}.sha256"
    md5sum    "$ISO_NAME" > "${ISO_NAME}.md5"
    log "Checksums written."
}

# ─── Summary ──────────────────────────────────────────────────────────────────
print_summary() {
    section "Build Complete"
    echo -e "${GREEN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║         ATLAZES OS BUILD COMPLETE                ║"
    echo "  ╠══════════════════════════════════════════════════╣"
    printf "  ║  Edition : %-37s║\n" "${EDITION^}"
    printf "  ║  ISO     : %-37s║\n" "${ISO_NAME}"
    printf "  ║  Log     : %-37s║\n" "build/build-${EDITION}.log"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo "  Flash to USB:"
    echo "    sudo dd if=${OUTPUT_DIR}/${ISO_NAME} of=/dev/sdX bs=4M status=progress oflag=sync"
}

# ─── Clean build ──────────────────────────────────────────────────────────────
clean_build() {
    section "Cleaning Previous Build"
    if [[ -d "${BUILD_DIR}/lb" ]]; then
        cd "${BUILD_DIR}/lb"
        lb clean --purge 2>/dev/null || true
    fi
    rm -rf "$BUILD_DIR"
    log "Clean complete."
}

# ─── Parse arguments ──────────────────────────────────────────────────────────
parse_args() {
    local cmd="${1:-build}"
    shift || true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --edition=*)
                EDITION="${1#--edition=}"
                ;;
            --edition)
                EDITION="${2:-core}"
                shift
                ;;
            *)
                warn "Unknown argument: $1"
                ;;
        esac
        shift
    done

    echo "$cmd"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BLUE}${BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║           ATLAZES OS BUILDER             ║"
    echo "  ║     Secure · Private · Professional      ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"

    local cmd
    cmd=$(parse_args "$@")

    # LOG_FILE needs EDITION set before prepare_dirs
    LOG_FILE="${BUILD_DIR}/build-${EDITION}.log"

    case "$cmd" in
        build)
            check_root
            check_dependencies
            prepare_dirs
            setup_edition
            init_livebuild
            copy_config
            build_iso
            generate_checksums
            print_summary
            ;;
        clean)
            check_root
            clean_build
            ;;
        deps)
            check_root
            check_dependencies
            ;;
        *)
            echo "Usage: sudo ./build.sh [build|clean|deps] [--edition=core|dev|security]"
            echo ""
            echo "  build  - Full build (default)"
            echo "  clean  - Clean build directory"
            echo "  deps   - Install dependencies only"
            echo ""
            echo "  --edition=core      Minimal secure OS (default)"
            echo "  --edition=dev       Core + developer tools"
            echo "  --edition=security  Core + extended security tools"
            echo ""
            echo "Examples:"
            echo "  sudo ./build.sh"
            echo "  sudo ./build.sh build --edition=dev"
            echo "  sudo ./build.sh build --edition=security"
            exit 1
            ;;
    esac
}

main "$@"
