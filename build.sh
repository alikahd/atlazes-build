#!/bin/bash
# =============================================================================
# ATLAZES OS - Main Build Script
# Version: 1.0.0-beta.1
# Base: Debian 12 (Bookworm)
#
# الطريقة الصحيحة حسب التوثيق الرسمي لـ live-build:
# lb config يُنشئ مجلد config/ في المجلد الحالي
# lb build يُشغَّل من نفس المجلد
# لذلك نُشغّل كل شيء من BUILD_DIR مباشرة
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

OS_NAME="ATLAZES OS"
OS_VERSION="1.0.0"
DEBIAN_RELEASE="bookworm"
ARCH="amd64"

# مجلد المشروع — حيث يوجد build.sh
PROJECT_DIR="$(dirname "$(realpath "$0")")"

# مجلد البناء — حيث يُشغَّل lb config و lb build
BUILD_DIR="${PROJECT_DIR}/build/lb"
OUTPUT_DIR="${PROJECT_DIR}/output"

MIRROR="${ATLAZES_MIRROR:-http://deb.debian.org/debian}"
EDITION="${ATLAZES_EDITION:-core}"

mkdir -p "${PROJECT_DIR}/build" 2>/dev/null || true
LOG_FILE="${PROJECT_DIR}/build/build-${EDITION}.log"
touch "$LOG_FILE"

log()     { echo -e "${GREEN}[+]${NC} $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_FILE"; exit 1; }
section() {
    echo -e "\n${CYAN}${BOLD}══════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}${BOLD}  $*${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════${NC}\n" | tee -a "$LOG_FILE"
}

check_root() {
    [[ $EUID -eq 0 ]] || error "يجب تشغيل السكريبت كـ root: sudo ./build.sh"
}

setup_edition() {
    case "$EDITION" in
        core)
            ISO_LABEL="ATLAZES-CORE-${OS_VERSION}"
            ISO_NAME="atlazes-os-${OS_VERSION}-core-${ARCH}.iso"
            log "الإصدار: Core"
            ;;
        dev)
            ISO_LABEL="ATLAZES-DEV-${OS_VERSION}"
            ISO_NAME="atlazes-os-${OS_VERSION}-dev-${ARCH}.iso"
            export ATLAZES_EDITION=dev
            log "الإصدار: Dev"
            ;;
        security)
            ISO_LABEL="ATLAZES-SEC-${OS_VERSION}"
            ISO_NAME="atlazes-os-${OS_VERSION}-security-${ARCH}.iso"
            log "الإصدار: Security"
            ;;
        *)
            error "إصدار غير معروف: ${EDITION}"
            ;;
    esac
    LOG_FILE="${PROJECT_DIR}/build/build-${EDITION}.log"
    touch "$LOG_FILE"
}

install_livebuild() {
    section "تثبيت live-build"
    local LB_VERSION
    LB_VERSION=$(dpkg -l live-build 2>/dev/null | grep "^ii" | awk '{print $3}' || echo "none")
    log "نسخة live-build الحالية: ${LB_VERSION}"

    if dpkg --compare-versions "$LB_VERSION" lt "20230101" 2>/dev/null || [[ "$LB_VERSION" == "none" ]]; then
        warn "تثبيت live-build الحديث من Debian..."
        local URL="http://deb.debian.org/debian/pool/main/l/live-build"
        local DEB
        DEB=$(curl -fsSL "${URL}/" 2>/dev/null | grep -oP 'live-build_[0-9]+_all\.deb' | sort -V | tail -1 || echo "")
        if [[ -n "$DEB" ]]; then
            curl -fsSL "${URL}/${DEB}" -o "/tmp/${DEB}"
            dpkg -i "/tmp/${DEB}" || apt-get install -f -y
            rm -f "/tmp/${DEB}"
        fi
    fi
    log "live-build: $(lb --version 2>/dev/null || echo 'unknown')"
}

check_dependencies() {
    section "تثبيت التبعيات"
    apt-get update -qq
    apt-get install -y \
        debootstrap squashfs-tools xorriso \
        isolinux syslinux-efi \
        grub-pc-bin grub-efi-amd64-bin \
        mtools dosfstools \
        curl wget rsync \
        librsvg2-bin ca-certificates \
        debian-archive-keyring 2>&1 | tee -a "$LOG_FILE"
    install_livebuild
    log "جميع التبعيات جاهزة."
}

prepare_dirs() {
    section "تحضير مجلدات البناء"
    mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"
    log "مجلد البناء:  $BUILD_DIR"
    log "مجلد الإخراج: $OUTPUT_DIR"
}

build_iso() {
    section "تهيئة live-build وبناء الـ ISO"

    # ── تنظيف البناء السابق ───────────────────────────────────────────────────
    if [[ -d "$BUILD_DIR" ]]; then
        warn "تنظيف البناء السابق..."
        cd "$BUILD_DIR"
        lb clean --purge 2>/dev/null || true
        cd "$PROJECT_DIR"
        rm -rf "$BUILD_DIR"
        mkdir -p "$BUILD_DIR"
    fi

    # ── الانتقال إلى مجلد البناء ──────────────────────────────────────────────
    # حسب التوثيق الرسمي: lb config و lb build يُشغَّلان من نفس المجلد
    # ويُنشئان config/ و binary/ في هذا المجلد
    cd "$BUILD_DIR"
    log "مجلد العمل الحالي: $(pwd)"

    # ── نسخ ملفات الإعداد قبل lb config ─────────────────────────────────────
    # الطريقة الصحيحة: ننسخ config/ من المشروع إلى BUILD_DIR
    # ثم يقرأها lb config و lb build من هنا
    log "نسخ ملفات الإعداد..."
    cp -r "${PROJECT_DIR}/config" .
    log "محتوى config/:"
    ls -la config/ | tee -a "$LOG_FILE"
    log "قوائم الحزم:"
    ls -la config/package-lists/ | tee -a "$LOG_FILE"

    # حذف قائمة dev للإصدارات الأخرى
    if [[ "$EDITION" != "dev" ]]; then
        rm -f config/package-lists/05-development.list.chroot
        log "تم استبعاد قائمة dev"
    fi

    # ── تحديد نسخة live-build ────────────────────────────────────────────────
    local LB_VERSION
    LB_VERSION=$(dpkg -l live-build 2>/dev/null | grep "^ii" | awk '{print $3}' || echo "0")

    # ── تشغيل lb config ───────────────────────────────────────────────────────
    # lb config يقرأ config/ الموجود في المجلد الحالي ويُحدّثه
    section "تشغيل lb config"

    local LB_OPTS=(
        --distribution "$DEBIAN_RELEASE"
        --architectures "$ARCH"
        --mirror-bootstrap "$MIRROR"
        --mirror-chroot "$MIRROR"
        --mirror-binary "$MIRROR"
        --archive-areas "main contrib non-free non-free-firmware"
        --apt-recommends true
        --apt-secure true
        --binary-images iso-hybrid
        --memtest none
        --iso-application "${OS_NAME} ${EDITION^}"
        --iso-publisher "ATLAZES Project"
        --iso-volume "${ISO_LABEL}"
        --linux-flavours "amd64"
        --backports false
        --win32-loader false
        --zsync false
        --bootappend-live "boot=live components nomodeset vga=791 net.ifnames=0 biosdevname=0 apparmor=1 security=apparmor noeject noprompt username=atlazes autologin"
        --bootappend-live-failsafe "boot=live components nomodeset vga=788 noeject noprompt net.ifnames=0 biosdevname=0 username=atlazes autologin"
    )

    if dpkg --compare-versions "$LB_VERSION" ge "20200101" 2>/dev/null; then
        LB_OPTS+=(--bootloaders "grub-efi,syslinux" --uefi-secure-boot disable)
    fi
    if dpkg --compare-versions "$LB_VERSION" ge "20190311" 2>/dev/null; then
        LB_OPTS+=(--security true --updates true)
    fi
    # firmware-binary و firmware-chroot: مدعومان في live-build القديم فقط
    if lb config --help 2>&1 | grep -q "firmware-binary"; then
        LB_OPTS+=(--firmware-binary true --firmware-chroot true)
    fi
    if lb config --help 2>&1 | grep -q "mirror-chroot-security"; then
        LB_OPTS+=(
            --mirror-chroot-security "http://security.debian.org/debian-security"
            --mirror-binary-security "http://security.debian.org/debian-security"
        )
    fi

    lb config "${LB_OPTS[@]}" 2>&1 | tee -a "$LOG_FILE"

    # التحقق من قوائم الحزم بعد lb config
    log "قوائم الحزم بعد lb config:"
    ls -la config/package-lists/ | tee -a "$LOG_FILE"

    # ── تشغيل lb build ────────────────────────────────────────────────────────
    section "بناء الـ ISO (قد يستغرق 20-60 دقيقة)"
    lb build 2>&1 | tee -a "$LOG_FILE"

    # ── نقل الـ ISO ───────────────────────────────────────────────────────────
    local iso_file
    iso_file=$(find "$BUILD_DIR" -maxdepth 1 -name "*.iso" | head -1)
    [[ -z "$iso_file" ]] && error "فشل البناء: لم يُنشأ ملف ISO"

    mv "$iso_file" "${OUTPUT_DIR}/${ISO_NAME}"
    log "تم بناء الـ ISO: ${OUTPUT_DIR}/${ISO_NAME}"
}

generate_checksums() {
    section "توليد Checksums"
    cd "$OUTPUT_DIR"
    sha256sum "$ISO_NAME" > "${ISO_NAME}.sha256"
    md5sum    "$ISO_NAME" > "${ISO_NAME}.md5"
    log "تم كتابة الـ checksums."
}

print_summary() {
    section "اكتمل البناء"
    echo -e "${GREEN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║         ATLAZES OS BUILD COMPLETE                ║"
    echo "  ╠══════════════════════════════════════════════════╣"
    printf "  ║  Edition : %-37s║\n" "${EDITION^}"
    printf "  ║  ISO     : %-37s║\n" "${ISO_NAME}"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

clean_build() {
    section "تنظيف البناء"
    if [[ -d "$BUILD_DIR" ]]; then
        cd "$BUILD_DIR"
        lb clean --purge 2>/dev/null || true
        cd "$PROJECT_DIR"
    fi
    rm -rf "${PROJECT_DIR}/build"
    log "تم التنظيف."
}

parse_args() {
    local cmd="${1:-build}"
    shift || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --edition=*) EDITION="${1#--edition=}" ;;
            --edition)   EDITION="${2:-core}"; shift ;;
            *)           warn "معامل غير معروف: $1" ;;
        esac
        shift
    done
    echo "$cmd"
}

main() {
    echo -e "${BLUE}${BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║           ATLAZES OS BUILDER             ║"
    echo "  ║     Secure · Private · Professional      ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"

    local cmd
    cmd=$(parse_args "$@")

    case "$cmd" in
        build)
            check_root
            check_dependencies
            prepare_dirs
            setup_edition
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
            echo "الاستخدام: sudo ./build.sh [build|clean|deps] [--edition=core|dev|security]"
            exit 1
            ;;
    esac
}

main "$@"
