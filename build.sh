#!/bin/bash
# =============================================================================
# ATLAZES OS - Main Build Script
# Version: 1.0.0-beta.1
# Base: Debian 12 (Bookworm)
# Editions: core | dev | security
# =============================================================================

set -euo pipefail

# ─── ألوان ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── إعدادات البناء ───────────────────────────────────────────────────────────
OS_NAME="ATLAZES OS"
OS_VERSION="1.0.0"
DEBIAN_RELEASE="bookworm"
ARCH="amd64"
BUILD_DIR="$(pwd)/build"
OUTPUT_DIR="$(pwd)/output"
MIRROR="${ATLAZES_MIRROR:-http://deb.debian.org/debian}"
EDITION="${ATLAZES_EDITION:-core}"

# تهيئة LOG_FILE مبكراً
mkdir -p "${BUILD_DIR}" 2>/dev/null || true
LOG_FILE="${BUILD_DIR}/build-${EDITION}.log"
touch "$LOG_FILE"

# ─── دوال مساعدة ──────────────────────────────────────────────────────────────
log()     { echo -e "${GREEN}[+]${NC} $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_FILE"; exit 1; }
section() {
    echo -e "\n${CYAN}${BOLD}══════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}${BOLD}  $*${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════${NC}\n" | tee -a "$LOG_FILE"
}

# ─── التحقق من الصلاحيات ──────────────────────────────────────────────────────
check_root() {
    [[ $EUID -eq 0 ]] || error "يجب تشغيل السكريبت كـ root: sudo ./build.sh"
}

# ─── إعداد الإصدار ────────────────────────────────────────────────────────────
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
            error "إصدار غير معروف: ${EDITION}. استخدم: core | dev | security"
            ;;
    esac
    LOG_FILE="${BUILD_DIR}/build-${EDITION}.log"
    touch "$LOG_FILE"
}

# ─── تثبيت live-build الحديث من Debian ───────────────────────────────────────
# نسخة Ubuntu 22.04 من live-build (20190311) قديمة جداً ولا تدعم
# --bootloaders و --uefi-secure-boot و --updates
# الحل: تثبيت النسخة الحديثة مباشرة من مستودع Debian bookworm
install_livebuild() {
    section "تثبيت live-build الحديث من Debian"

    local LB_VERSION
    LB_VERSION=$(dpkg -l live-build 2>/dev/null | grep "^ii" | awk '{print $3}' || echo "none")
    log "نسخة live-build الحالية: ${LB_VERSION}"

    # إذا كانت النسخة أقدم من 20230101 نثبت الأحدث
    if dpkg --compare-versions "$LB_VERSION" lt "20230101" 2>/dev/null || [[ "$LB_VERSION" == "none" ]]; then
        warn "نسخة live-build قديمة. جاري تثبيت النسخة الحديثة من Debian..."

        # إضافة مفتاح Debian وإضافة المستودع مؤقتاً
        apt-get install -y debian-archive-keyring 2>/dev/null || true

        # تحميل live-build مباشرة من Debian bookworm
        local LB_DEB_URL="http://deb.debian.org/debian/pool/main/l/live-build"
        local LB_DEB_FILE="live-build_20230131_all.deb"

        # محاولة تحميل نسخة محددة
        if curl -fsSL --max-time 60 \
            "${LB_DEB_URL}/${LB_DEB_FILE}" \
            -o "/tmp/${LB_DEB_FILE}" 2>/dev/null; then
            dpkg -i "/tmp/${LB_DEB_FILE}" 2>/dev/null || apt-get install -f -y
            rm -f "/tmp/${LB_DEB_FILE}"
            log "تم تثبيت live-build من Debian."
        else
            # بديل: إضافة مستودع Debian مؤقتاً
            warn "فشل التحميل المباشر. جاري إضافة مستودع Debian مؤقتاً..."
            echo "deb http://deb.debian.org/debian bookworm main" \
                > /etc/apt/sources.list.d/debian-bookworm-temp.list
            apt-get update -qq 2>/dev/null || true
            apt-get install -y -t bookworm live-build 2>/dev/null || \
                apt-get install -y live-build
            rm -f /etc/apt/sources.list.d/debian-bookworm-temp.list
            apt-get update -qq 2>/dev/null || true
        fi
    else
        log "live-build حديث بما يكفي: ${LB_VERSION}"
    fi

    local NEW_VERSION
    NEW_VERSION=$(dpkg -l live-build 2>/dev/null | grep "^ii" | awk '{print $3}' || echo "unknown")
    log "نسخة live-build المستخدمة: ${NEW_VERSION}"
}

# ─── تثبيت التبعيات ───────────────────────────────────────────────────────────
check_dependencies() {
    section "تثبيت التبعيات"
    apt-get update -qq

    local deps=(
        debootstrap
        squashfs-tools
        xorriso
        isolinux
        syslinux-efi
        grub-pc-bin
        grub-efi-amd64-bin
        mtools
        dosfstools
        curl
        wget
        rsync
        librsvg2-bin
        ca-certificates
        debian-archive-keyring
    )

    local missing=()
    for dep in "${deps[@]}"; do
        dpkg -l "$dep" 2>/dev/null | grep -q "^ii" || missing+=("$dep")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "تثبيت: ${missing[*]}"
        apt-get install -y "${missing[@]}"
    fi

    # تثبيت live-build الحديث
    install_livebuild

    log "جميع التبعيات جاهزة."
}

# ─── تحضير المجلدات ───────────────────────────────────────────────────────────
prepare_dirs() {
    section "تحضير مجلدات البناء"
    mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"
    touch "$LOG_FILE"
    log "مجلد البناء:  $BUILD_DIR"
    log "مجلد الإخراج: $OUTPUT_DIR"
}

# ─── تهيئة live-build ─────────────────────────────────────────────────────────
init_livebuild() {
    section "تهيئة live-build"

    if [[ -d "${BUILD_DIR}/lb" ]]; then
        warn "يوجد بناء سابق. جاري التنظيف..."
        cd "${BUILD_DIR}/lb"
        lb clean --purge 2>/dev/null || true
        cd "$(dirname "$BUILD_DIR")"
        rm -rf "${BUILD_DIR}/lb"
    fi

    mkdir -p "${BUILD_DIR}/lb"
    cd "${BUILD_DIR}/lb"

    # ── تحديد الخيارات حسب نسخة live-build ──────────────────────────────────
    local LB_VERSION
    LB_VERSION=$(dpkg -l live-build 2>/dev/null | grep "^ii" | awk '{print $3}' || echo "0")

    # الخيارات الأساسية المتوافقة مع جميع النسخ
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
        --firmware-binary true
        --firmware-chroot true
        --backports false
        --win32-loader false
        --zsync false
        --bootappend-live "boot=live components nomodeset vga=791 net.ifnames=0 biosdevname=0 apparmor=1 security=apparmor noeject noprompt username=atlazes"
        --bootappend-live-failsafe "boot=live components nomodeset vga=788 noeject noprompt net.ifnames=0 biosdevname=0 username=atlazes"
    )

    # إضافة خيارات النسخ الحديثة فقط إذا كانت مدعومة
    if dpkg --compare-versions "$LB_VERSION" ge "20200101" 2>/dev/null; then
        LB_OPTS+=(
            --bootloaders "grub-efi,syslinux"
            --uefi-secure-boot disable
        )
        log "إضافة خيارات UEFI (نسخة حديثة: ${LB_VERSION})"
    else
        warn "نسخة live-build قديمة (${LB_VERSION}) — تخطي --bootloaders و --uefi-secure-boot"
    fi

    if dpkg --compare-versions "$LB_VERSION" ge "20190311" 2>/dev/null; then
        LB_OPTS+=(
            --security true
            --updates true
        )
    fi

    # إضافة مرايا الأمان إذا كانت مدعومة
    if lb config --help 2>&1 | grep -q "mirror-chroot-security"; then
        LB_OPTS+=(
            --mirror-chroot-security "http://security.debian.org/debian-security"
            --mirror-binary-security "http://security.debian.org/debian-security"
        )
        log "إضافة مرايا الأمان"
    fi

    log "تشغيل lb config..."
    lb config "${LB_OPTS[@]}" 2>&1 | tee -a "$LOG_FILE"

    log "تمت تهيئة live-build."
}

# ─── نسخ ملفات الإعداد ────────────────────────────────────────────────────────
copy_config() {
    section "نسخ ملفات الإعداد"
    local src_config
    src_config="$(dirname "$(realpath "$0")")/config"
    local dst_config="${BUILD_DIR}/lb/config"

    [[ -d "$src_config" ]] || error "مجلد الإعداد غير موجود: $src_config"

    # ── قوائم الحزم ───────────────────────────────────────────────────────────
    if [[ -d "${src_config}/package-lists" ]]; then
        cp -rv "${src_config}/package-lists/"* "${dst_config}/package-lists/" 2>&1 | tee -a "$LOG_FILE"
        log "تم نسخ قوائم الحزم:"
        ls -la "${dst_config}/package-lists/" | tee -a "$LOG_FILE"
    else
        error "مجلد package-lists غير موجود: ${src_config}/package-lists"
    fi

    # حذف قائمة dev للإصدارات الأخرى
    if [[ "$EDITION" != "dev" ]]; then
        rm -f "${dst_config}/package-lists/05-development.list.chroot"
        log "تم استبعاد قائمة dev"
    fi

    # ── الـ hooks ─────────────────────────────────────────────────────────────
    if [[ -d "${src_config}/hooks" ]]; then
        cp -rv "${src_config}/hooks/"* "${dst_config}/hooks/" 2>&1 | tee -a "$LOG_FILE"
        find "${dst_config}/hooks/" -name "*.hook.chroot" -exec chmod +x {} \;
        find "${dst_config}/hooks/" -name "*.hook.binary" -exec chmod +x {} \;
        log "تم نسخ الـ hooks:"
        ls -la "${dst_config}/hooks/" | tee -a "$LOG_FILE"
    fi

    # ── الملفات المضمنة ───────────────────────────────────────────────────────
    if [[ -d "${src_config}/includes.chroot" ]]; then
        cp -rv "${src_config}/includes.chroot/"* "${dst_config}/includes.chroot/" 2>&1 | tee -a "$LOG_FILE"
    fi

    # ── preseed ───────────────────────────────────────────────────────────────
    if [[ -d "${src_config}/preseed" ]]; then
        cp -rv "${src_config}/preseed/"* "${dst_config}/preseed/" 2>&1 | tee -a "$LOG_FILE"
    fi

    # ── علامة الإصدار ─────────────────────────────────────────────────────────
    mkdir -p "${dst_config}/includes.chroot/etc"
    echo "ATLAZES_EDITION=${EDITION}" > "${dst_config}/includes.chroot/etc/atlazes-edition"

    log "اكتمل نسخ ملفات الإعداد."
}

# ─── بناء الـ ISO ─────────────────────────────────────────────────────────────
build_iso() {
    section "بناء الـ ISO (قد يستغرق 20-60 دقيقة)"
    cd "${BUILD_DIR}/lb"

    lb build 2>&1 | tee -a "$LOG_FILE"

    local iso_file
    iso_file=$(find "${BUILD_DIR}/lb" -maxdepth 1 -name "*.iso" | head -1)
    [[ -z "$iso_file" ]] && error "فشل البناء: لم يُنشأ ملف ISO. راجع $LOG_FILE"

    mv "$iso_file" "${OUTPUT_DIR}/${ISO_NAME}"
    log "تم بناء الـ ISO: ${OUTPUT_DIR}/${ISO_NAME}"
}

# ─── توليد checksums ──────────────────────────────────────────────────────────
generate_checksums() {
    section "توليد Checksums"
    cd "$OUTPUT_DIR"
    sha256sum "$ISO_NAME" > "${ISO_NAME}.sha256"
    md5sum    "$ISO_NAME" > "${ISO_NAME}.md5"
    log "تم كتابة الـ checksums."
}

# ─── ملخص البناء ──────────────────────────────────────────────────────────────
print_summary() {
    section "اكتمل البناء"
    echo -e "${GREEN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║         ATLAZES OS BUILD COMPLETE                ║"
    echo "  ╠══════════════════════════════════════════════════╣"
    printf "  ║  Edition : %-37s║\n" "${EDITION^}"
    printf "  ║  ISO     : %-37s║\n" "${ISO_NAME}"
    printf "  ║  Log     : %-37s║\n" "build/build-${EDITION}.log"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ─── تنظيف البناء ─────────────────────────────────────────────────────────────
clean_build() {
    section "تنظيف البناء السابق"
    if [[ -d "${BUILD_DIR}/lb" ]]; then
        cd "${BUILD_DIR}/lb"
        lb clean --purge 2>/dev/null || true
    fi
    rm -rf "$BUILD_DIR"
    log "تم التنظيف."
}

# ─── تحليل المعاملات ──────────────────────────────────────────────────────────
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

# ─── الدالة الرئيسية ──────────────────────────────────────────────────────────
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
            echo "الاستخدام: sudo ./build.sh [build|clean|deps] [--edition=core|dev|security]"
            exit 1
            ;;
    esac
}

main "$@"
