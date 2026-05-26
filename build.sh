#!/bin/bash
# =============================================================================
# ATLAZES OS - Build Script (ISO Remaster Method)
# Version: 2.0.0
# Base: Debian 13 (Trixie) Live XFCE Official ISO
#
# الطريقة: تحميل ISO الرسمي → استخراج squashfs → تطبيق تخصيصات → إعادة بناء ISO
# هذا يضمن أن النظام يعمل 100% لأن القاعدة هي ISO رسمي مُختبر
# =============================================================================

set -euo pipefail

# ── ألوان ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── متغيرات ──────────────────────────────────────────────────────────────────
OS_NAME="ATLAZES OS"
OS_VERSION="2.0.0"
DEBIAN_VERSION="13"
DEBIAN_CODENAME="trixie"
ARCH="amd64"

PROJECT_DIR="$(dirname "$(realpath "$0")")"
WORK_DIR="${PROJECT_DIR}/work"
OUTPUT_DIR="${PROJECT_DIR}/output"
CUSTOM_DIR="${PROJECT_DIR}/customization"
CALAMARES_DIR="${PROJECT_DIR}/calamares"

# ISO source — Debian Live XFCE
ISO_URL="https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/"
ISO_PATTERN="debian-live-.*-amd64-xfce.iso"
ISO_CACHE="${PROJECT_DIR}/cache"

ISO_NAME="atlazes-os-${OS_VERSION}-amd64.iso"

LOG_FILE="${PROJECT_DIR}/build.log"

# ── دوال مساعدة ──────────────────────────────────────────────────────────────
log()     { echo -e "${GREEN}[+]${NC} $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_FILE"; exit 1; }
section() {
    echo -e "\n${CYAN}${BOLD}══════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}${BOLD}  $*${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════${NC}\n" | tee -a "$LOG_FILE"
}

cleanup() {
    log "تنظيف mount points..."
    umount "${WORK_DIR}/squashfs-mnt" 2>/dev/null || true
    umount "${WORK_DIR}/overlay/merged/proc" 2>/dev/null || true
    umount "${WORK_DIR}/overlay/merged/sys" 2>/dev/null || true
    umount "${WORK_DIR}/overlay/merged/dev/pts" 2>/dev/null || true
    umount "${WORK_DIR}/overlay/merged/dev" 2>/dev/null || true
    umount "${WORK_DIR}/overlay/merged" 2>/dev/null || true
}

trap cleanup EXIT

# ── 1. التحقق من المتطلبات ────────────────────────────────────────────────────
check_requirements() {
    section "التحقق من المتطلبات"

    [[ $EUID -eq 0 ]] || error "يجب تشغيل السكريبت كـ root: sudo ./build.sh"

    local deps=(wget xorriso squashfs-tools mksquashfs unsquashfs mount)
    local missing=()

    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log "تثبيت التبعيات المفقودة..."
        apt-get update -qq
        apt-get install -y \
            wget xorriso squashfs-tools \
            grub-pc-bin grub-efi-amd64-bin \
            mtools dosfstools isolinux syslinux-common \
            rsync curl 2>&1 | tee -a "$LOG_FILE"
    fi

    log "جميع المتطلبات متوفرة."
}

# ── 2. تحميل ISO الرسمي ──────────────────────────────────────────────────────
download_iso() {
    section "تحميل Debian Live XFCE ISO"

    mkdir -p "$ISO_CACHE"

    # البحث عن اسم الملف الحالي
    log "البحث عن أحدث ISO..."
    local iso_filename
    iso_filename=$(wget -q -O - "$ISO_URL" 2>/dev/null | \
        grep -oP "debian-live-[0-9.]+-amd64-xfce\.iso" | \
        sort -V | tail -1)

    if [[ -z "$iso_filename" ]]; then
        error "لم يتم العثور على ISO في ${ISO_URL}"
    fi

    log "اسم الملف: ${iso_filename}"
    local iso_path="${ISO_CACHE}/${iso_filename}"

    if [[ -f "$iso_path" ]]; then
        log "ISO موجود بالفعل في الكاش: ${iso_path}"
    else
        log "تحميل ISO... (قد يستغرق وقتاً)"
        wget -c "${ISO_URL}${iso_filename}" -O "$iso_path" 2>&1 | tee -a "$LOG_FILE"
    fi

    # تحميل checksum والتحقق
    local sha_file="${ISO_CACHE}/SHA256SUMS"
    wget -q "${ISO_URL}SHA256SUMS" -O "$sha_file" 2>/dev/null || true
    if [[ -f "$sha_file" ]]; then
        log "التحقق من checksum..."
        cd "$ISO_CACHE"
        if grep "$iso_filename" "$sha_file" | sha256sum -c --status 2>/dev/null; then
            log "Checksum صحيح ✓"
        else
            warn "لم يتم التحقق من checksum — متابعة..."
        fi
        cd "$PROJECT_DIR"
    fi

    export SOURCE_ISO="$iso_path"
    log "ISO جاهز: ${SOURCE_ISO}"
}

# ── 3. استخراج ISO ───────────────────────────────────────────────────────────
extract_iso() {
    section "استخراج ISO"

    # تنظيف مجلد العمل
    rm -rf "$WORK_DIR"
    mkdir -p "${WORK_DIR}/iso-extract"
    mkdir -p "${WORK_DIR}/squashfs-mnt"
    mkdir -p "${WORK_DIR}/overlay/upper"
    mkdir -p "${WORK_DIR}/overlay/work"
    mkdir -p "${WORK_DIR}/overlay/merged"
    mkdir -p "${WORK_DIR}/new-iso"

    # استخراج محتويات ISO
    log "استخراج محتويات ISO..."
    xorriso -osirrox on -indev "$SOURCE_ISO" -extract / "${WORK_DIR}/iso-extract" 2>&1 | tee -a "$LOG_FILE"

    # البحث عن squashfs
    local squashfs_path
    squashfs_path=$(find "${WORK_DIR}/iso-extract" -name "filesystem.squashfs" | head -1)
    if [[ -z "$squashfs_path" ]]; then
        error "لم يتم العثور على filesystem.squashfs"
    fi
    log "squashfs: ${squashfs_path}"

    # mount squashfs (read-only)
    log "Mount squashfs..."
    mount -o loop,ro "$squashfs_path" "${WORK_DIR}/squashfs-mnt"

    # إنشاء overlay writable
    log "إنشاء overlay filesystem..."
    mount -t overlay overlay \
        -o lowerdir="${WORK_DIR}/squashfs-mnt",upperdir="${WORK_DIR}/overlay/upper",workdir="${WORK_DIR}/overlay/work" \
        "${WORK_DIR}/overlay/merged"

    log "تم استخراج وتجهيز النظام للتعديل."
}

# ── 4. تطبيق التخصيصات (chroot) ──────────────────────────────────────────────
apply_customizations() {
    section "تطبيق تخصيصات ATLAZES"

    local CHROOT="${WORK_DIR}/overlay/merged"

    # mount filesystems للـ chroot
    mount --bind /dev "$CHROOT/dev"
    mount --bind /dev/pts "$CHROOT/dev/pts"
    mount -t proc proc "$CHROOT/proc"
    mount -t sysfs sysfs "$CHROOT/sys"

    # نسخ resolv.conf للإنترنت
    cp /etc/resolv.conf "$CHROOT/etc/resolv.conf"

    # نسخ سكريبتات التخصيص
    mkdir -p "$CHROOT/tmp/customization"
    cp -r "${CUSTOM_DIR}/"* "$CHROOT/tmp/customization/"

    # نسخ assets الهوية (شعارات + خلفيات SVG)
    if [[ -d "${PROJECT_DIR}/assets" ]]; then
        log "نسخ assets إلى chroot..."
        mkdir -p "$CHROOT/tmp/atlazes-assets"
        cp -r "${PROJECT_DIR}/assets/"* "$CHROOT/tmp/atlazes-assets/" 2>/dev/null || true
    else
        warn "مجلد assets غير موجود — سيتم تخطّي شعارات/خلفيات SVG"
    fi

    # نسخ أدوات atlazes CLI
    if [[ -d "${CUSTOM_DIR}/atlazes-tools" ]]; then
        log "نسخ atlazes-tools إلى chroot..."
        mkdir -p "$CHROOT/tmp/atlazes-tools"
        cp -r "${CUSTOM_DIR}/atlazes-tools/"* "$CHROOT/tmp/atlazes-tools/" 2>/dev/null || true
        chmod +x "$CHROOT/tmp/atlazes-tools/atlazes" 2>/dev/null || true
        chmod +x "$CHROOT/tmp/atlazes-tools/atlazes-firewall" 2>/dev/null || true
        chmod +x "$CHROOT/tmp/atlazes-tools/atlazes-privacy" 2>/dev/null || true
    fi

    # نسخ إعدادات Calamares
    if [[ -d "$CALAMARES_DIR" ]]; then
        mkdir -p "$CHROOT/tmp/calamares"
        cp -r "${CALAMARES_DIR}/"* "$CHROOT/tmp/calamares/"
    fi

    # ── تشغيل التخصيصات داخل chroot ──────────────────────────────────────────
    log "تثبيت الحزم الإضافية..."
    chroot "$CHROOT" /bin/bash -c '
        set -e
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq

        # تثبيت الحزم من packages.txt. لا نخفي الفشل هنا حتى لا ينتج ISO ناقص.
        if [[ -f /tmp/customization/packages.txt ]]; then
            mapfile -t packages < <(grep -Ev "^[[:space:]]*(#|$)" /tmp/customization/packages.txt)
            if [[ ${#packages[@]} -gt 0 ]]; then
                apt-get install -y --no-install-recommends "${packages[@]}"
            fi
        fi

        apt-get clean
        rm -rf /var/lib/apt/lists/*
    '

    log "تطبيق security hardening..."
    if [[ -f "${CUSTOM_DIR}/security-hardening.sh" ]]; then
        chmod +x "$CHROOT/tmp/customization/security-hardening.sh"
        chroot "$CHROOT" /bin/bash /tmp/customization/security-hardening.sh
    fi

    log "تطبيق privacy config..."
    if [[ -f "${CUSTOM_DIR}/privacy-config.sh" ]]; then
        chmod +x "$CHROOT/tmp/customization/privacy-config.sh"
        chroot "$CHROOT" /bin/bash /tmp/customization/privacy-config.sh
    fi

    log "تطبيق branding..."
    if [[ -f "${CUSTOM_DIR}/branding.sh" ]]; then
        chmod +x "$CHROOT/tmp/customization/branding.sh"
        chroot "$CHROOT" /bin/bash /tmp/customization/branding.sh
    fi

    log "إعداد المستخدم..."
    if [[ -f "${CUSTOM_DIR}/user-setup.sh" ]]; then
        chmod +x "$CHROOT/tmp/customization/user-setup.sh"
        chroot "$CHROOT" /bin/bash /tmp/customization/user-setup.sh
    fi

    # ── إعداد Calamares ───────────────────────────────────────────────────────
    if [[ -d "$CHROOT/tmp/calamares" ]]; then
        log "إعداد Calamares installer..."
        chroot "$CHROOT" /bin/bash -c '
            # نسخ إعدادات Calamares
            mkdir -p /etc/calamares/branding/atlazes
            mkdir -p /etc/calamares/modules

            if [[ -f /tmp/calamares/settings.conf ]]; then
                cp /tmp/calamares/settings.conf /etc/calamares/
            fi
            if [[ -d /tmp/calamares/modules ]]; then
                cp /tmp/calamares/modules/* /etc/calamares/modules/ 2>/dev/null || true
            fi
            if [[ -d /tmp/calamares/branding/atlazes ]]; then
                cp -r /tmp/calamares/branding/atlazes/* /etc/calamares/branding/atlazes/ 2>/dev/null || true
            fi
            if [[ -f /usr/share/atlazes/logo.png ]]; then
                cp -f /usr/share/atlazes/logo.png /etc/calamares/branding/atlazes/logo.png 2>/dev/null || true
                cp -f /usr/share/atlazes/logo.png /etc/calamares/branding/atlazes/icon.png 2>/dev/null || true
            fi
            if [[ -f /usr/share/atlazes/logo.svg ]]; then
                cp -f /usr/share/atlazes/logo.svg /etc/calamares/branding/atlazes/logo.svg 2>/dev/null || true
            fi
            if [[ -f /usr/share/backgrounds/atlazes/wallpaper.png ]]; then
                cp -f /usr/share/backgrounds/atlazes/wallpaper.png /etc/calamares/branding/atlazes/welcome.png 2>/dev/null || true
            fi
        '
    fi

    # ── تنظيف ─────────────────────────────────────────────────────────────────
    log "تنظيف chroot..."
    rm -rf "$CHROOT/tmp/customization"
    rm -rf "$CHROOT/tmp/calamares"
    rm -rf "$CHROOT/tmp/atlazes-assets"
    rm -rf "$CHROOT/tmp/atlazes-tools"

    # unmount chroot filesystems
    umount "$CHROOT/proc" 2>/dev/null || true
    umount "$CHROOT/sys" 2>/dev/null || true
    umount "$CHROOT/dev/pts" 2>/dev/null || true
    umount "$CHROOT/dev" 2>/dev/null || true

    log "تم تطبيق جميع التخصيصات."
}

# ── 5. إعادة ضغط squashfs ────────────────────────────────────────────────────
repack_squashfs() {
    section "إعادة ضغط squashfs"

    local CHROOT="${WORK_DIR}/overlay/merged"
    local new_squashfs="${WORK_DIR}/new-iso/live/filesystem.squashfs"

    # نسخ محتويات ISO الأصلية
    log "نسخ محتويات ISO..."
    rsync -a "${WORK_DIR}/iso-extract/" "${WORK_DIR}/new-iso/" --exclude="live/filesystem.squashfs"

    # إنشاء مجلد live إذا لم يكن موجوداً
    mkdir -p "${WORK_DIR}/new-iso/live"

    # ضغط squashfs جديد
    log "ضغط filesystem.squashfs... (قد يستغرق وقتاً)"
    mksquashfs "$CHROOT" "$new_squashfs" \
        -comp xz -b 1M -Xdict-size 100% \
        -noappend \
        -e boot/grub \
        2>&1 | tee -a "$LOG_FILE"

    # حساب حجم filesystem
    local fs_size
    fs_size=$(du -sb "$CHROOT" | awk '{print $1}')
    echo "$fs_size" > "${WORK_DIR}/new-iso/live/filesystem.size"

    # unmount overlay
    umount "${WORK_DIR}/overlay/merged" 2>/dev/null || true
    umount "${WORK_DIR}/squashfs-mnt" 2>/dev/null || true

    log "تم ضغط squashfs بنجاح."
    log "حجم squashfs: $(du -sh "$new_squashfs" | awk '{print $1}')"
}

sanitize_boot_branding() {
    local boot_dir="$1"

    [[ -d "$boot_dir" ]] || return 0

    find "$boot_dir" -type f \( -name "*.cfg" -o -name "*.conf" -o -name "*.txt" \) -exec \
        sed -i \
            -e "s|Debian GNU/Linux|ATLAZES OS|g" \
            -e "s|Debian Live|ATLAZES OS Live|g" \
            -e "s|Debian|ATLAZES OS|g" \
            -e "s|debian-live|atlazes-os|g" \
            -e "s|debian|atlazes|g" {} \; 2>/dev/null || true
}

inject_efi_branding() {
    local efi_image="$1"
    local theme_dir="$2"
    local tmp_dir="${WORK_DIR}/efi-branding"

    [[ -f "$efi_image" ]] || return 0
    command -v mcopy &>/dev/null || {
        warn "mcopy غير متوفر؛ سيتم تخطي حقن هوية ATLAZES داخل EFI image"
        return 0
    }

    log "حقن هوية ATLAZES داخل EFI image..."
    mkdir -p "$tmp_dir"

    if [[ -d "$theme_dir" ]]; then
        mmd -i "$efi_image" ::/boot 2>/dev/null || true
        mmd -i "$efi_image" ::/boot/grub 2>/dev/null || true
        mmd -i "$efi_image" ::/boot/grub/themes 2>/dev/null || true
        mmd -i "$efi_image" ::/boot/grub/themes/atlazes 2>/dev/null || true
        mcopy -o -s -i "$efi_image" "${theme_dir}/"* ::/boot/grub/themes/atlazes/ 2>/dev/null || true
    fi

    local cfg_path cfg_name tmp_cfg
    for cfg_path in ::/boot/grub/grub.cfg ::/EFI/BOOT/grub.cfg ::/efi/boot/grub.cfg; do
        cfg_name="$(basename "$cfg_path")"
        tmp_cfg="${tmp_dir}/${cfg_name}"
        rm -f "$tmp_cfg"
        if mcopy -i "$efi_image" "$cfg_path" "$tmp_cfg" 2>/dev/null; then
            sed -i \
                -e "s|Debian GNU/Linux|ATLAZES OS|g" \
                -e "s|Debian Live|ATLAZES OS Live|g" \
                -e "s|Debian|ATLAZES OS|g" \
                -e "s|debian-live|atlazes-os|g" \
                -e "s|debian|atlazes|g" "$tmp_cfg" 2>/dev/null || true
            if ! grep -q "themes/atlazes" "$tmp_cfg" && [[ -d "$theme_dir" ]]; then
                sed -i '1i set theme=/boot/grub/themes/atlazes/theme.txt\nexport theme' "$tmp_cfg" 2>/dev/null || true
            fi
            mcopy -o -i "$efi_image" "$tmp_cfg" "$cfg_path" 2>/dev/null || true
        fi
    done
}

# ── 6. بناء ISO جديد ─────────────────────────────────────────────────────────
build_iso() {
    section "بناء ISO جديد"

    mkdir -p "$OUTPUT_DIR"

    local iso_output="${OUTPUT_DIR}/${ISO_NAME}"
    local new_iso_dir="${WORK_DIR}/new-iso"

    # تحديث GRUB config لـ ATLAZES branding (استبدالات محدّدة وآمنة)
    if [[ -f "${new_iso_dir}/boot/grub/grub.cfg" ]]; then
        log "تحديث GRUB config..."
        sed -i "s|Debian GNU/Linux|ATLAZES OS|g" "${new_iso_dir}/boot/grub/grub.cfg"
        sed -i "s|debian-live|atlazes-os|g" "${new_iso_dir}/boot/grub/grub.cfg"
        sed -i "s|Debian Live|ATLAZES OS Live|g" "${new_iso_dir}/boot/grub/grub.cfg"
        # عناوين القائمة الشائعة في Debian Live
        sed -i 's|menuentry "Debian|menuentry "ATLAZES OS|g' "${new_iso_dir}/boot/grub/grub.cfg"
    fi

    # تحديث GRUB configs الفرعية
    find "${new_iso_dir}/boot/grub" -name "*.cfg" -exec \
        sed -i "s|Debian GNU/Linux|ATLAZES OS|g; s|Debian Live|ATLAZES OS Live|g" {} \; 2>/dev/null || true
    sanitize_boot_branding "${new_iso_dir}/boot"

    # نسخ ATLAZES GRUB theme إلى ISO نفسه (للقائمة عند الإقلاع من ISO)
    # الملفات موجودة في overlay/upper بعد تطبيق branding.sh (قبل/بعد unmount)
    local THEME_SRC=""
    for candidate in \
        "${WORK_DIR}/overlay/merged/boot/grub/themes/atlazes" \
        "${WORK_DIR}/overlay/upper/boot/grub/themes/atlazes"; do
        if [[ -d "$candidate" ]] && [[ -n "$(ls -A "$candidate" 2>/dev/null)" ]]; then
            THEME_SRC="$candidate"
            break
        fi
    done

    if [[ -n "$THEME_SRC" ]]; then
        log "نسخ GRUB theme من ${THEME_SRC} إلى ISO..."
        mkdir -p "${new_iso_dir}/boot/grub/themes/atlazes"
        cp -rf "${THEME_SRC}/"* \
            "${new_iso_dir}/boot/grub/themes/atlazes/" 2>/dev/null || true

        # إضافة set theme في grub.cfg إن لم يكن موجوداً
        if [[ -f "${new_iso_dir}/boot/grub/grub.cfg" ]] \
           && ! grep -q "themes/atlazes" "${new_iso_dir}/boot/grub/grub.cfg"; then
            sed -i '1i set theme=/boot/grub/themes/atlazes/theme.txt\nexport theme' \
                "${new_iso_dir}/boot/grub/grub.cfg" 2>/dev/null || true
        fi
    else
        warn "GRUB theme غير موجود في overlay — سيتم تخطّي theme في ISO"
    fi

    # استبدال خلفية GRUB القديمة (إن وُجدت) بخلفيتنا
    if [[ -f "${new_iso_dir}/boot/grub/themes/atlazes/background.png" ]]; then
        for old_bg in "${new_iso_dir}/boot/grub/splash.png" \
                      "${new_iso_dir}/boot/grub/debian.png" \
                      "${new_iso_dir}/isolinux/splash.png" \
                      "${new_iso_dir}/isolinux/debian.png"; do
            if [[ -f "$old_bg" ]]; then
                cp -f "${new_iso_dir}/boot/grub/themes/atlazes/background.png" "$old_bg"
            fi
        done
    fi

    # تحديث isolinux config
    if [[ -f "${new_iso_dir}/isolinux/isolinux.cfg" ]]; then
        log "تحديث isolinux config..."
        sed -i "s/Debian GNU\/Linux/ATLAZES OS/g" "${new_iso_dir}/isolinux/isolinux.cfg"
    fi
    # تحديث menu.cfg إذا وُجد
    find "${new_iso_dir}/isolinux" -name "*.cfg" -exec \
        sed -i "s/Debian GNU\/Linux/ATLAZES OS/g" {} \; 2>/dev/null || true
    sanitize_boot_branding "${new_iso_dir}/isolinux"

    # بناء ISO
    log "بناء ISO بـ xorriso..."

    # تحديد ملف isolinux.bin
    local isolinux_bin=""
    if [[ -f "${new_iso_dir}/isolinux/isolinux.bin" ]]; then
        isolinux_bin="isolinux/isolinux.bin"
    fi

    # تحديد EFI image
    local efi_img=""
    if [[ -f "${new_iso_dir}/boot/grub/efi.img" ]]; then
        efi_img="boot/grub/efi.img"
    elif [[ -f "${new_iso_dir}/EFI/boot/efiboot.img" ]]; then
        efi_img="EFI/boot/efiboot.img"
    fi

    if [[ -n "$efi_img" ]]; then
        inject_efi_branding "${new_iso_dir}/${efi_img}" "${new_iso_dir}/boot/grub/themes/atlazes"
    fi

    # بناء ISO مع دعم BIOS + UEFI
    local xorriso_opts=(
        -as mkisofs
        -o "$iso_output"
        -V "ATLAZES_OS"
        -J -joliet-long -l
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin
    )

    if [[ -n "$isolinux_bin" ]]; then
        xorriso_opts+=(
            -b "$isolinux_bin"
            -c isolinux/boot.cat
            -no-emul-boot
            -boot-load-size 4
            -boot-info-table
        )
    fi

    if [[ -n "$efi_img" ]]; then
        xorriso_opts+=(
            -eltorito-alt-boot
            -e "$efi_img"
            -no-emul-boot
            -isohybrid-gpt-basdat
        )
    fi

    xorriso "${xorriso_opts[@]}" "$new_iso_dir" 2>&1 | tee -a "$LOG_FILE"

    log "تم بناء ISO: ${iso_output}"
    log "حجم ISO: $(du -sh "$iso_output" | awk '{print $1}')"
}

# ── 7. Checksums ──────────────────────────────────────────────────────────────
generate_checksums() {
    section "توليد Checksums"

    cd "$OUTPUT_DIR"
    sha256sum "$ISO_NAME" > "${ISO_NAME}.sha256"
    md5sum "$ISO_NAME" > "${ISO_NAME}.md5"
    cd "$PROJECT_DIR"

    log "SHA256: $(cat "${OUTPUT_DIR}/${ISO_NAME}.sha256")"
}

# ── 8. تنظيف ─────────────────────────────────────────────────────────────────
clean() {
    section "تنظيف مجلد العمل"
    cleanup
    rm -rf "$WORK_DIR"
    log "تم التنظيف. (الكاش محفوظ في ${ISO_CACHE})"
}

# ── ملخص ──────────────────────────────────────────────────────────────────────
print_summary() {
    section "اكتمل البناء"
    echo -e "${GREEN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║         ATLAZES OS BUILD COMPLETE                ║"
    echo "  ╠══════════════════════════════════════════════════╣"
    printf "  ║  Version : %-37s║\n" "${OS_VERSION}"
    printf "  ║  Base    : %-37s║\n" "Debian ${DEBIAN_VERSION} (${DEBIAN_CODENAME}) Live XFCE"
    printf "  ║  ISO     : %-37s║\n" "${ISO_NAME}"
    printf "  ║  Size    : %-37s║\n" "$(du -sh "${OUTPUT_DIR}/${ISO_NAME}" 2>/dev/null | awk '{print $1}')"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BLUE}${BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║           ATLAZES OS BUILDER v2          ║"
    echo "  ║     Secure · Private · Professional      ║"
    echo "  ║   Method: Debian Live ISO Remastering    ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"

    local cmd="${1:-build}"

    case "$cmd" in
        build)
            check_requirements
            download_iso
            extract_iso
            apply_customizations
            repack_squashfs
            build_iso
            generate_checksums
            print_summary
            ;;
        clean)
            clean
            ;;
        clean-all)
            clean
            rm -rf "$ISO_CACHE"
            log "تم حذف الكاش أيضاً."
            ;;
        download)
            check_requirements
            download_iso
            ;;
        *)
            echo "الاستخدام: sudo ./build.sh [build|clean|clean-all|download]"
            echo ""
            echo "  build     — بناء ISO كامل"
            echo "  clean     — حذف مجلد العمل (يحتفظ بالكاش)"
            echo "  clean-all — حذف كل شيء بما فيه ISO المُحمَّل"
            echo "  download  — تحميل ISO الرسمي فقط"
            exit 1
            ;;
    esac
}

main "$@"
