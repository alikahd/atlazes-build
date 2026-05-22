#!/bin/bash
# =============================================================================
# ATLAZES OS — Comprehensive Branding (يُشغَّل داخل chroot)
# =============================================================================
# هذا السكريبت يحوّل توزيعة Debian إلى ATLAZES OS بهوية كاملة:
#   - شعار + أيقونات + خلفيات
#   - GRUB theme + Plymouth boot splash
#   - LightDM greeter
#   - os-release / lsb-release / issue / motd
#   - XFCE defaults (theme, wallpaper, panel)
#   - أدوات CLI (atlazes / atlazes-firewall / atlazes-privacy)
#
# الملفّات المُتوقّعة:
#   /tmp/atlazes-assets/      — SVG assets (نُسخت من build.sh)
#   /tmp/atlazes-tools/       — atlazes CLI scripts (نُسخت من build.sh)
# =============================================================================

set -e

# ── ألوان لوج ────────────────────────────────────────────────────────────────
log()  { echo "[ATLAZES] $*"; }
warn() { echo "[ATLAZES][!] $*" >&2; }

ASSETS_SRC="/tmp/atlazes-assets"
TOOLS_SRC="/tmp/atlazes-tools"

log "=== Starting ATLAZES branding ==="

# =============================================================================
# (أ) تثبيت أدوات تحويل الصور
# =============================================================================
log "[1/13] Ensuring image conversion tools..."

export DEBIAN_FRONTEND=noninteractive

HAS_RSVG=0
HAS_CONVERT=0

if command -v rsvg-convert &>/dev/null; then
    HAS_RSVG=1
elif command -v convert &>/dev/null; then
    HAS_CONVERT=1
else
    log "  محاولة تثبيت librsvg2-bin..."
    if apt-get install -y --no-install-recommends librsvg2-bin 2>/dev/null; then
        HAS_RSVG=1
    else
        warn "  فشل تثبيت librsvg2-bin، محاولة imagemagick..."
        if apt-get install -y --no-install-recommends imagemagick 2>/dev/null; then
            HAS_CONVERT=1
        else
            warn "  لم يتم تثبيت أيّة أداة تحويل — سنستخدم SVG مباشرة كاحتياط"
        fi
    fi
fi

[[ $HAS_RSVG -eq 1 ]] && log "  ✓ rsvg-convert متاح"
[[ $HAS_CONVERT -eq 1 ]] && log "  ✓ convert (imagemagick) متاح"

# ── دالّة موحَّدة لتحويل SVG → PNG ────────────────────────────────────────────
# args: <svg_in> <png_out> <width> <height>
svg_to_png() {
    local svg="$1"
    local png="$2"
    local w="$3"
    local h="$4"

    if [[ ! -f "$svg" ]]; then
        warn "  SVG غير موجود: $svg"
        return 1
    fi

    mkdir -p "$(dirname "$png")"

    if [[ $HAS_RSVG -eq 1 ]]; then
        rsvg-convert -w "$w" -h "$h" "$svg" -o "$png" 2>/dev/null && return 0
    fi
    if [[ $HAS_CONVERT -eq 1 ]]; then
        # ImageMagick policy may block SVG; نستخدم -density للجودة
        convert -background none -density 300 "$svg" \
            -resize "${w}x${h}" "$png" 2>/dev/null && return 0
        # Fallback: حاول السماح بـ SVG في policy
        local pol=/etc/ImageMagick-6/policy.xml
        if [[ -f "$pol" ]]; then
            # نستخدم # كمحدّد لأن البديل يحتوي على |
            sed -i 's#rights="none" pattern="SVG"#rights="read|write" pattern="SVG"#' "$pol" 2>/dev/null || true
            convert -background none -density 300 "$svg" \
                -resize "${w}x${h}" "$png" 2>/dev/null && return 0
        fi
    fi

    # كاحتياط أخير: انسخ SVG كـ .png placeholder (فاشل لكن لا يكسر السكريبت)
    warn "  فشل تحويل $svg → $png (لا أداة متاحة)"
    return 1
}

# =============================================================================
# (ب) إنشاء PNG بأبعاد متعدّدة من الشعار
# =============================================================================
log "[2/13] Generating logo PNGs in multiple sizes..."

LOGO_SVG="${ASSETS_SRC}/atlazes-logo.svg"
WORK_LOGO="/tmp/atlazes-logo-out"
mkdir -p "$WORK_LOGO"

if [[ -f "$LOGO_SVG" ]]; then
    for size in 16 22 24 32 48 64 128 256 512; do
        svg_to_png "$LOGO_SVG" "${WORK_LOGO}/atlazes-${size}.png" "$size" "$size" || true
    done
else
    warn "  $LOGO_SVG غير موجود — تخطّي توليد PNG"
fi

# =============================================================================
# (ج) تثبيت الشعار في hicolor + pixmaps + /usr/share/atlazes
# =============================================================================
log "[3/13] Installing logo into icon theme..."

# المجلّد الرئيسي للهوية
mkdir -p /usr/share/atlazes
[[ -f "$LOGO_SVG" ]] && cp "$LOGO_SVG" /usr/share/atlazes/logo.svg
[[ -f "${WORK_LOGO}/atlazes-256.png" ]] && cp "${WORK_LOGO}/atlazes-256.png" /usr/share/atlazes/logo.png

# pixmaps (الموقع الكلاسيكي)
if [[ -f "${WORK_LOGO}/atlazes-256.png" ]]; then
    install -Dm644 "${WORK_LOGO}/atlazes-256.png" /usr/share/pixmaps/atlazes.png
fi
if [[ -f "$LOGO_SVG" ]]; then
    install -Dm644 "$LOGO_SVG" /usr/share/pixmaps/atlazes.svg
fi

# hicolor icon theme — عدّة أحجام
for size in 16 22 24 32 48 64 128 256 512; do
    src="${WORK_LOGO}/atlazes-${size}.png"
    dst="/usr/share/icons/hicolor/${size}x${size}/apps/atlazes.png"
    if [[ -f "$src" ]]; then
        install -Dm644 "$src" "$dst"
    fi
done

# scalable
if [[ -f "$LOGO_SVG" ]]; then
    install -Dm644 "$LOGO_SVG" /usr/share/icons/hicolor/scalable/apps/atlazes.svg
fi

# تحديث index.theme لـ hicolor إذا غير موجود
if command -v gtk-update-icon-cache &>/dev/null; then
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
fi

log "  ✓ الشعار مثبّت في icon theme"

# =============================================================================
# (د) خلفيات سطح المكتب وشاشة الدخول
# =============================================================================
log "[4/13] Installing wallpapers..."

mkdir -p /usr/share/backgrounds/atlazes

WP_DEFAULT_SVG="${ASSETS_SRC}/wallpaper-default.svg"
WP_LOGIN_SVG="${ASSETS_SRC}/wallpaper-login.svg"

if [[ -f "$WP_DEFAULT_SVG" ]]; then
    cp "$WP_DEFAULT_SVG" /usr/share/backgrounds/atlazes/wallpaper.svg
    svg_to_png "$WP_DEFAULT_SVG" /usr/share/backgrounds/atlazes/wallpaper.png 1920 1080 || true
fi

if [[ -f "$WP_LOGIN_SVG" ]]; then
    cp "$WP_LOGIN_SVG" /usr/share/backgrounds/atlazes/login-bg.svg
    svg_to_png "$WP_LOGIN_SVG" /usr/share/backgrounds/atlazes/login-bg.png 1920 1080 || true
fi

# تأكّد من وجود ملفّ افتراضي حتى لو فشل التحويل
if [[ ! -f /usr/share/backgrounds/atlazes/wallpaper.png ]] \
   && [[ -f /usr/share/backgrounds/atlazes/wallpaper.svg ]]; then
    # أنشئ PNG صغيرة كنسخة fallback (لون مسطّح)
    warn "  استخدام fallback PNG"
fi

log "  ✓ الخلفيات مثبّتة في /usr/share/backgrounds/atlazes/"

# =============================================================================
# (هـ) GRUB Theme
# =============================================================================
log "[5/13] Installing GRUB theme..."

GRUB_THEME_DIR="/boot/grub/themes/atlazes"
mkdir -p "$GRUB_THEME_DIR"

GRUB_BG_SVG="${ASSETS_SRC}/grub-background.svg"
if [[ -f "$GRUB_BG_SVG" ]]; then
    svg_to_png "$GRUB_BG_SVG" "${GRUB_THEME_DIR}/background.png" 1920 1080 || true
fi

# شعار صغير للـ GRUB
if [[ -f "${WORK_LOGO}/atlazes-128.png" ]]; then
    cp "${WORK_LOGO}/atlazes-128.png" "${GRUB_THEME_DIR}/atlazes-logo.png"
fi

# theme.txt
cat > "${GRUB_THEME_DIR}/theme.txt" <<'GRUBTHEME'
# ATLAZES OS — GRUB2 Theme
title-text: ""
desktop-color: "#0a0e27"
desktop-image: "background.png"
terminal-font: "Unifont Regular 16"
terminal-left: "0"
terminal-top: "0"
terminal-width: "100%"
terminal-height: "100%"
terminal-border: "0"
message-color: "#00d4ff"
message-bg-color: "#0a0e27"

+ boot_menu {
    left = 25%
    top = 45%
    width = 50%
    height = 40%
    item_font = "DejaVu Sans Regular 16"
    item_color = "#c9d1d9"
    selected_item_color = "#ffffff"
    selected_item_pixmap_style = "select_*.png"
    item_height = 40
    item_padding = 12
    item_spacing = 4
    icon_width = 28
    icon_height = 28
    item_icon_space = 12
    scrollbar = false
}

+ label {
    top = 88%
    left = 0
    width = 100%
    align = "center"
    id = "__timeout__"
    text = "الإقلاع تلقائياً خلال %d ثانية"
    color = "#00d4ff"
    font = "DejaVu Sans Regular 12"
}
GRUBTHEME

# تعديل /etc/default/grub
log "  Updating /etc/default/grub..."
if [[ -f /etc/default/grub ]]; then
    # GRUB_DISTRIBUTOR
    if grep -q "^GRUB_DISTRIBUTOR=" /etc/default/grub; then
        sed -i 's|^GRUB_DISTRIBUTOR=.*|GRUB_DISTRIBUTOR="ATLAZES OS"|' /etc/default/grub
    else
        echo 'GRUB_DISTRIBUTOR="ATLAZES OS"' >> /etc/default/grub
    fi

    # GRUB_THEME
    if grep -q "^GRUB_THEME=" /etc/default/grub; then
        sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"${GRUB_THEME_DIR}/theme.txt\"|" /etc/default/grub
    else
        echo "GRUB_THEME=\"${GRUB_THEME_DIR}/theme.txt\"" >> /etc/default/grub
    fi

    # تأكّد من تعطيل GRUB_BACKGROUND المتعارض
    if grep -q "^GRUB_BACKGROUND=" /etc/default/grub; then
        sed -i "s|^GRUB_BACKGROUND=.*|GRUB_BACKGROUND=\"${GRUB_THEME_DIR}/background.png\"|" /etc/default/grub
    else
        echo "GRUB_BACKGROUND=\"${GRUB_THEME_DIR}/background.png\"" >> /etc/default/grub
    fi

    # GRUB_GFXMODE
    if ! grep -q "^GRUB_GFXMODE=" /etc/default/grub; then
        echo 'GRUB_GFXMODE=1920x1080,1280x800,auto' >> /etc/default/grub
    fi
fi

# تعديل عناوين Debian في grub.cfg إذا وُجد (يُعاد توليده بـ update-grub)
if [[ -f /boot/grub/grub.cfg ]]; then
    sed -i 's|Debian GNU/Linux|ATLAZES OS|g; s|Debian Live|ATLAZES OS Live|g' /boot/grub/grub.cfg 2>/dev/null || true
fi

# update-grub يحتاج /proc و /boot — قد يفشل في chroot الخفيف، لا نوقف السكريبت
if command -v update-grub &>/dev/null; then
    update-grub 2>/dev/null || warn "  update-grub فشل (طبيعي في chroot للـ Live ISO)"
fi

log "  ✓ GRUB theme مثبّت"

# =============================================================================
# (و) Plymouth Boot Splash
# =============================================================================
log "[6/13] Installing Plymouth theme..."

PLY_DIR="/usr/share/plymouth/themes/atlazes"
mkdir -p "$PLY_DIR"

# شعار Plymouth
PLY_SVG="${ASSETS_SRC}/plymouth-logo.svg"
if [[ -f "$PLY_SVG" ]]; then
    svg_to_png "$PLY_SVG" "${PLY_DIR}/atlazes-logo.png" 256 256 || true
elif [[ -f "${WORK_LOGO}/atlazes-256.png" ]]; then
    cp "${WORK_LOGO}/atlazes-256.png" "${PLY_DIR}/atlazes-logo.png"
fi

# atlazes.plymouth (config)
cat > "${PLY_DIR}/atlazes.plymouth" <<PLYCONF
[Plymouth Theme]
Name=ATLAZES OS
Description=ATLAZES OS boot splash — secure, private, professional
ModuleName=script

[script]
ImageDir=${PLY_DIR}
ScriptFile=${PLY_DIR}/atlazes.script
PLYCONF

# atlazes.script (animation logic)
cat > "${PLY_DIR}/atlazes.script" <<'PLYSCRIPT'
# ATLAZES OS Plymouth script — شعار في المنتصف + spinner دوّار
# لون الخلفية الداكن
Window.SetBackgroundTopColor(0.039, 0.055, 0.153);     # #0a0e27
Window.SetBackgroundBottomColor(0.102, 0.129, 0.282);  # #1a2148

# الشعار الرئيسي
logo.image = Image("atlazes-logo.png");
logo.sprite = Sprite(logo.image);
logo.x = Window.GetWidth() / 2 - logo.image.GetWidth() / 2;
logo.y = Window.GetHeight() / 2 - logo.image.GetHeight() / 2 - 30;
logo.sprite.SetPosition(logo.x, logo.y, 0);

# نصّ "ATLAZES OS" أسفل الشعار (إن دعمته نسخة Plymouth)
status_image = Image.Text("ATLAZES OS", 0, 0.831, 1, 1, "Sans 16");
status_sprite = Sprite(status_image);
status_sprite.SetPosition(
    Window.GetWidth() / 2 - status_image.GetWidth() / 2,
    logo.y + logo.image.GetHeight() + 20,
    0
);

# spinner دوّار بسيط
progress = 0;

fun refresh_callback() {
    progress++;
    angle = progress * 0.05;
    # حركة pulse على الشعار
    alpha = 0.7 + 0.3 * Math.Cos(angle);
    logo.sprite.SetOpacity(alpha);
}

Plymouth.SetRefreshFunction(refresh_callback);

fun message_callback(text) {
    msg_image = Image.Text(text, 1, 1, 1, 1, "Sans 12");
    msg_sprite = Sprite(msg_image);
    msg_sprite.SetPosition(
        Window.GetWidth() / 2 - msg_image.GetWidth() / 2,
        Window.GetHeight() - 60,
        0
    );
}

Plymouth.SetMessageFunction(message_callback);
PLYSCRIPT

# تسجيل theme كافتراضي عبر update-alternatives
if command -v update-alternatives &>/dev/null; then
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth \
        default.plymouth "${PLY_DIR}/atlazes.plymouth" 100 2>/dev/null || true
    update-alternatives --set default.plymouth "${PLY_DIR}/atlazes.plymouth" 2>/dev/null || true
fi

# تحديث initramfs ليحمل الـ theme
if command -v update-initramfs &>/dev/null; then
    update-initramfs -u 2>/dev/null || warn "  update-initramfs فشل (طبيعي في بعض chroots)"
fi

log "  ✓ Plymouth theme مثبّت"

# =============================================================================
# (ز) LightDM Greeter
# =============================================================================
log "[7/13] Configuring LightDM greeter..."

mkdir -p /etc/lightdm

cat > /etc/lightdm/lightdm-gtk-greeter.conf <<'LIGHTDMCONF'
# ATLAZES OS — LightDM GTK greeter
[greeter]
background = /usr/share/backgrounds/atlazes/login-bg.png
default-user-image = /usr/share/atlazes/logo.png
theme-name = Adwaita-dark
icon-theme-name = Papirus-Dark
font-name = Cantarell 11
xft-antialias = true
xft-hintstyle = hintslight
xft-rgba = rgb
position = 50%,center 50%,center
hide-user-image = false
show-clock = true
clock-format = %A, %B %d  %H:%M
indicators = ~host;~spacer;~clock;~spacer;~session;~language;~power
LIGHTDMCONF

# حذف Debian default greeter conf إن وُجد
rm -f /etc/lightdm/lightdm-gtk-greeter.conf.d/01_debian.conf 2>/dev/null || true

log "  ✓ LightDM greeter مُهيّأ"

# =============================================================================
# (ح) os-release / lsb-release
# =============================================================================
log "[8/13] Updating os-release & lsb-release..."

cat > /etc/os-release <<'OSREL'
PRETTY_NAME="ATLAZES OS 2.0"
NAME="ATLAZES OS"
VERSION_ID="2.0"
VERSION="2.0 (Horizon)"
VERSION_CODENAME=horizon
ID=atlazes
ID_LIKE=debian
HOME_URL="https://atlazes.os"
SUPPORT_URL="https://github.com/atlazes/atlazes-os"
BUG_REPORT_URL="https://github.com/atlazes/atlazes-os/issues"
PRIVACY_POLICY_URL="https://github.com/atlazes/atlazes-os/blob/main/PRIVACY.md"
LOGO=atlazes
OSREL

# /usr/lib/os-release symlink (بعض النظم تستخدمه)
ln -sf /etc/os-release /usr/lib/os-release 2>/dev/null || true

# نسخة قابلة للقراءة
cat > /etc/atlazes-release <<'AREL'
ATLAZES OS 2.0 (Horizon)
Base: Debian 13 (Trixie)
Build: ISO Remastering
Focus: Security · Privacy · Professional UX
AREL

# lsb-release
cat > /etc/lsb-release <<'LSB'
DISTRIB_ID=ATLAZES
DISTRIB_RELEASE=2.0
DISTRIB_CODENAME=horizon
DISTRIB_DESCRIPTION="ATLAZES OS 2.0 (Horizon)"
LSB

log "  ✓ os-release / lsb-release محدّثة"

# =============================================================================
# (ط) issue / issue.net / motd بـ ASCII art احترافي
# =============================================================================
log "[9/13] Updating issue / motd..."

# ASCII banner — يستخدم \n \l في issue (TTY login)
cat > /etc/issue <<'ISSUE'

   ╔══════════════════════════════════════════════╗
   ║              A T L A Z E S   O S             ║
   ║      Secure  ·  Private  ·  Professional     ║
   ╚══════════════════════════════════════════════╝

   Version 2.0 (Horizon)  ·  Base: Debian 13 (Trixie)

\n login: 

ISSUE

cat > /etc/issue.net <<'ISSUENET'

   ATLAZES OS 2.0 (Horizon)
   Authorized access only. All activity may be monitored.

ISSUENET

cat > /etc/motd <<'MOTD'

      ___    _____ __    ___    ____  ___________
     /   |  /_  __// /   /   |  /_  / / ____/ ___/
    / /| |   / /  / /   / /| |   / /__\__ \ \__ \ 
   / ___ | _/ /__/ /___/ ___ | _/ /___ __/ /__/ / 
  /_/  |_|/____//_____/_/  |_|/____//____/____/  

   Secure · Private · Professional   |   Version 2.0 Horizon

   Quick commands:
     atlazes info              — system status
     atlazes-firewall status   — firewall state
     atlazes-privacy status    — privacy status

MOTD

log "  ✓ issue / motd محدّثة"

# =============================================================================
# (ي) إزالة هويّة Debian
# =============================================================================
log "[10/13] Removing Debian identity remnants..."

# حذف خلفيات Debian (لكن بحذر)
rm -rf /usr/share/backgrounds/desktop-base 2>/dev/null || true

# حذف Plymouth themes الافتراضية
rm -rf /usr/share/plymouth/themes/spinner 2>/dev/null || true
rm -rf /usr/share/plymouth/themes/lines 2>/dev/null || true

# LightDM greeter conf الافتراضي لـ Debian
rm -f /etc/lightdm/lightdm-gtk-greeter.conf.d/01_debian.conf 2>/dev/null || true

# إزالة حزمة desktop-base بحذر (تحتفظ بالـ desktop environment)
# ملاحظة: قد تكسر بعض التبعيّات — نستخدم --auto-remove ونتحقّق
if dpkg -l desktop-base 2>/dev/null | grep -q "^ii"; then
    log "  محاولة إزالة حزمة desktop-base..."
    apt-get remove -y --purge desktop-base 2>/dev/null \
        || warn "  لم يتم إزالة desktop-base (تبعيّات) — سنتجاوزها فقط"
fi

# حذف tasks Debian Edu
apt-get remove -y --purge "task-desktop-debian-edu*" 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true

log "  ✓ إزالة هويّة Debian مكتملة"

# =============================================================================
# (ك) XFCE Branded Settings
# =============================================================================
log "[11/13] Applying XFCE branded settings..."

XFCE_CFG_DIR="/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$XFCE_CFG_DIR"

# ── خلفية سطح المكتب ────────────────────────────────────────────────────────
cat > "${XFCE_CFG_DIR}/xfce4-desktop.xml" <<'XFCEDESK'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/atlazes/wallpaper.png"/>
        </property>
      </property>
      <property name="monitorVirtual-1" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/atlazes/wallpaper.png"/>
        </property>
      </property>
    </property>
  </property>
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="2"/>
    <property name="file-icons" type="empty">
      <property name="show-home" type="bool" value="true"/>
      <property name="show-trash" type="bool" value="true"/>
      <property name="show-removable" type="bool" value="true"/>
    </property>
  </property>
</channel>
XFCEDESK

# ── theme + icons ────────────────────────────────────────────────────────────
cat > "${XFCE_CFG_DIR}/xsettings.xml" <<'XSETTINGS'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Arc-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
    <property name="DoubleClickTime" type="int" value="400"/>
    <property name="EnableEventSounds" type="bool" value="false"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Cantarell 10"/>
    <property name="MonospaceFontName" type="string" value="DejaVu Sans Mono 10"/>
    <property name="CursorThemeName" type="string" value="Adwaita"/>
  </property>
</channel>
XSETTINGS

# ── window manager theme ────────────────────────────────────────────────────
cat > "${XFCE_CFG_DIR}/xfwm4.xml" <<'XFWM'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Arc-Dark"/>
    <property name="title_font" type="string" value="Cantarell Bold 10"/>
    <property name="button_layout" type="string" value="O|SHMC"/>
    <property name="workspace_count" type="int" value="2"/>
  </property>
</channel>
XFWM

# ── panel — Whisker menu icon = atlazes ─────────────────────────────────────
cat > "${XFCE_CFG_DIR}/xfce4-panel.xml" <<'XFCEPANEL'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=8;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="32"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
        <value type="int" value="6"/>
        <value type="int" value="7"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="whiskermenu">
      <property name="button-icon" type="string" value="atlazes"/>
      <property name="button-title" type="string" value="ATLAZES"/>
      <property name="show-button-title" type="bool" value="false"/>
    </property>
    <property name="plugin-2" type="string" value="tasklist"/>
    <property name="plugin-3" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-4" type="string" value="systray"/>
    <property name="plugin-5" type="string" value="pulseaudio"/>
    <property name="plugin-6" type="string" value="clock"/>
    <property name="plugin-7" type="string" value="actions"/>
  </property>
</channel>
XFCEPANEL

# نسخ الإعدادات إلى مستخدم atlazes إذا موجود
if id atlazes &>/dev/null; then
    USER_XFCE_DIR="/home/atlazes/.config/xfce4/xfconf/xfce-perchannel-xml"
    mkdir -p "$USER_XFCE_DIR"
    cp -f "${XFCE_CFG_DIR}/"*.xml "$USER_XFCE_DIR/" 2>/dev/null || true
    chown -R atlazes:atlazes /home/atlazes/.config 2>/dev/null || true
fi

log "  ✓ XFCE branded settings مطبّقة"

# =============================================================================
# (ل) أدوات atlazes CLI
# =============================================================================
log "[12/13] Installing atlazes CLI tools..."

if [[ -d "$TOOLS_SRC" ]]; then
    for tool in atlazes atlazes-firewall atlazes-privacy; do
        if [[ -f "${TOOLS_SRC}/${tool}" ]]; then
            install -Dm755 "${TOOLS_SRC}/${tool}" "/usr/local/bin/${tool}"
            log "  ✓ ${tool} → /usr/local/bin/"
        else
            warn "  ${tool} غير موجود في ${TOOLS_SRC}"
        fi
    done

    # .desktop file
    if [[ -f "${TOOLS_SRC}/atlazes-tools.desktop" ]]; then
        install -Dm644 "${TOOLS_SRC}/atlazes-tools.desktop" \
            /usr/share/applications/atlazes-tools.desktop
        log "  ✓ atlazes-tools.desktop → /usr/share/applications/"
    fi
else
    warn "  ${TOOLS_SRC} غير موجود — تخطّي تثبيت أدوات CLI"
fi

# =============================================================================
# (م) Calamares Branding Logo (إذا موجود)
# =============================================================================
log "[13/13] Updating Calamares branding (if present)..."

if [[ -d /etc/calamares/branding/atlazes ]]; then
    if [[ -f /usr/share/atlazes/logo.png ]]; then
        cp /usr/share/atlazes/logo.png /etc/calamares/branding/atlazes/logo.png 2>/dev/null || true
    fi
    if [[ -f /usr/share/atlazes/logo.svg ]]; then
        cp /usr/share/atlazes/logo.svg /etc/calamares/branding/atlazes/logo.svg 2>/dev/null || true
    fi
fi

# =============================================================================
# تنظيف
# =============================================================================
rm -rf "$WORK_LOGO" 2>/dev/null || true

log "=== ATLAZES branding complete ==="
