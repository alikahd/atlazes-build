#!/bin/bash
# =============================================================================
# ATLAZUS OS — Comprehensive Branding
# يُشغَّل داخل chroot
# =============================================================================

set -e

log()  { echo "[ATLAZUS] $*"; }
warn() { echo "[ATLAZUS][!] $*" >&2; }

ASSETS_SRC="/tmp/atlazus-assets"
TOOLS_SRC="/tmp/atlazus-tools"

log "=== Starting ATLAZUS branding ==="

export DEBIAN_FRONTEND=noninteractive

# =============================================================================
# (أ) تثبيت أدوات تحويل الصور أولاً
# =============================================================================
log "[1] Installing image conversion tools..."

apt-get install -y --no-install-recommends librsvg2-bin 2>/dev/null \
    || apt-get install -y --no-install-recommends imagemagick 2>/dev/null \
    || warn "No image converter available — will use SVG directly"

HAS_RSVG=0
HAS_CONVERT=0
command -v rsvg-convert &>/dev/null && HAS_RSVG=1
command -v convert      &>/dev/null && HAS_CONVERT=1

svg_to_png() {
    local svg="$1" png="$2" w="$3" h="$4"
    [[ -f "$svg" ]] || { warn "SVG not found: $svg"; return 1; }
    mkdir -p "$(dirname "$png")"
    if [[ $HAS_RSVG -eq 1 ]]; then
        rsvg-convert -w "$w" -h "$h" "$svg" -o "$png" 2>/dev/null && return 0
    fi
    if [[ $HAS_CONVERT -eq 1 ]]; then
        convert -background none -density 300 "$svg" -resize "${w}x${h}" "$png" 2>/dev/null && return 0
    fi
    warn "Cannot convert $svg → $png"
    return 1
}

# =============================================================================
# (ب) توليد PNG من الشعار
# =============================================================================
log "[2] Generating logo PNGs..."

LOGO_SVG="${ASSETS_SRC}/atlazus-logo.svg"
WORK_LOGO="/tmp/atlazus-logo-out"
mkdir -p "$WORK_LOGO"

if [[ -f "$LOGO_SVG" ]]; then
    for size in 16 22 24 32 48 64 128 256 512; do
        svg_to_png "$LOGO_SVG" "${WORK_LOGO}/atlazus-${size}.png" "$size" "$size" || true
    done
fi

# =============================================================================
# (ج) تثبيت الشعار
# =============================================================================
log "[3] Installing logo..."

mkdir -p /usr/share/atlazus
[[ -f "$LOGO_SVG" ]] && cp "$LOGO_SVG" /usr/share/atlazus/logo.svg
[[ -f "${WORK_LOGO}/atlazus-256.png" ]] && cp "${WORK_LOGO}/atlazus-256.png" /usr/share/atlazus/logo.png

[[ -f "${WORK_LOGO}/atlazus-256.png" ]] && install -Dm644 "${WORK_LOGO}/atlazus-256.png" /usr/share/pixmaps/atlazus.png
[[ -f "$LOGO_SVG" ]] && install -Dm644 "$LOGO_SVG" /usr/share/pixmaps/atlazus.svg

for size in 16 22 24 32 48 64 128 256 512; do
    src="${WORK_LOGO}/atlazus-${size}.png"
    [[ -f "$src" ]] && install -Dm644 "$src" "/usr/share/icons/hicolor/${size}x${size}/apps/atlazus.png"
done
[[ -f "$LOGO_SVG" ]] && install -Dm644 "$LOGO_SVG" /usr/share/icons/hicolor/scalable/apps/atlazus.svg
command -v gtk-update-icon-cache &>/dev/null && gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true

# =============================================================================
# (د) خلفيات الشاشة
# =============================================================================
log "[4] Installing wallpapers..."

mkdir -p /usr/share/backgrounds/atlazus

WP_SVG="${ASSETS_SRC}/wallpaper-default.svg"
LOGIN_SVG="${ASSETS_SRC}/wallpaper-login.svg"

if [[ -f "$WP_SVG" ]]; then
    cp "$WP_SVG" /usr/share/backgrounds/atlazus/wallpaper.svg
    svg_to_png "$WP_SVG" /usr/share/backgrounds/atlazus/wallpaper.png 1920 1080 || true
fi

if [[ -f "$LOGIN_SVG" ]]; then
    cp "$LOGIN_SVG" /usr/share/backgrounds/atlazus/login-bg.svg
    svg_to_png "$LOGIN_SVG" /usr/share/backgrounds/atlazus/login-bg.png 1920 1080 || true
fi

# إذا فشل التحويل، أنشئ PNG بسيط بلون ATLAZUS كـ fallback
if [[ ! -f /usr/share/backgrounds/atlazus/wallpaper.png ]]; then
    log "  Creating fallback wallpaper PNG..."
    if [[ $HAS_CONVERT -eq 1 ]]; then
        convert -size 1920x1080 gradient:"#0a0e27-#1a2148" \
            /usr/share/backgrounds/atlazus/wallpaper.png 2>/dev/null || true
    fi
fi

# =============================================================================
# (هـ) حذف خلفية Debian وتعيين ATLAZUS كافتراضية
# =============================================================================
log "[5] Replacing Debian wallpaper..."

# حذف خلفيات Debian
rm -rf /usr/share/backgrounds/desktop-base 2>/dev/null || true
rm -f /usr/share/backgrounds/*.png /usr/share/backgrounds/*.jpg 2>/dev/null || true

# تعيين خلفية ATLAZUS كافتراضية في xfconf
XFCE_DEFAULTS_DIR="/usr/share/xfce4/backdrops"
mkdir -p "$XFCE_DEFAULTS_DIR"
if [[ -f /usr/share/backgrounds/atlazus/wallpaper.png ]]; then
    ln -sf /usr/share/backgrounds/atlazus/wallpaper.png "$XFCE_DEFAULTS_DIR/atlazus.png"
fi

# تعيين في /etc/skel (للمستخدمين الجدد)
XFCE_CFG_DIR="/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$XFCE_CFG_DIR"

cat > "${XFCE_CFG_DIR}/xfce4-desktop.xml" << 'XFCEDESK'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/atlazus/wallpaper.png"/>
        </property>
      </property>
      <property name="monitorVirtual-1" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/atlazus/wallpaper.png"/>
        </property>
      </property>
      <property name="monitorVirtual1" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/atlazus/wallpaper.png"/>
        </property>
      </property>
    </property>
  </property>
</channel>
XFCEDESK

# نسخ لمستخدم atlazus مباشرة
if id atlazus &>/dev/null; then
    USER_XFCE="/home/atlazus/.config/xfce4/xfconf/xfce-perchannel-xml"
    mkdir -p "$USER_XFCE"
    cp "${XFCE_CFG_DIR}/xfce4-desktop.xml" "$USER_XFCE/"
    chown -R atlazus:atlazus /home/atlazus/.config 2>/dev/null || true
fi

# =============================================================================
# (و) حذف "Install Debian" وإضافة "Install ATLAZUS OS"
# =============================================================================
log "[6] Fixing desktop shortcuts..."

# حذف كل اختصارات Debian
rm -f /usr/share/applications/debian-*.desktop 2>/dev/null || true
rm -f /usr/share/applications/install-debian.desktop 2>/dev/null || true
rm -f /usr/share/applications/calamares-debian.desktop 2>/dev/null || true

# حذف من سطح مكتب المستخدمين
for user_home in /home/* /root; do
    rm -f "${user_home}/Desktop/install-debian.desktop" 2>/dev/null || true
    rm -f "${user_home}/Desktop/Install Debian.desktop" 2>/dev/null || true
done

# إنشاء اختصار ATLAZUS
cat > /usr/share/applications/install-atlazus.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=Install ATLAZUS OS
Comment=Install ATLAZUS OS to your hard drive
Exec=pkexec calamares
Icon=calamares
Terminal=false
Categories=System;
DESKTOP

# نسخ لسطح مكتب atlazus
if id atlazus &>/dev/null; then
    mkdir -p /home/atlazus/Desktop
    cp /usr/share/applications/install-atlazus.desktop /home/atlazus/Desktop/
    chmod +x /home/atlazus/Desktop/install-atlazus.desktop
    chown atlazus:atlazus /home/atlazus/Desktop/install-atlazus.desktop
fi

# =============================================================================
# (ز) دعم اللغات المتعددة
# =============================================================================
log "[7] Installing multi-language support..."

# تثبيت حزم اللغات
apt-get install -y --no-install-recommends \
    locales \
    language-pack-gnome-ar \
    language-pack-gnome-fr \
    language-pack-gnome-de \
    language-pack-gnome-es \
    language-pack-gnome-zh-hans \
    language-pack-gnome-ru \
    2>/dev/null || true

# تثبيت حزم اللغات البديلة إذا فشلت الأولى
apt-get install -y --no-install-recommends \
    locales-all \
    2>/dev/null || true

# توليد locales شائعة
cat >> /etc/locale.gen << 'LOCALES'
ar_SA.UTF-8 UTF-8
ar_MA.UTF-8 UTF-8
fr_FR.UTF-8 UTF-8
de_DE.UTF-8 UTF-8
es_ES.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8
ru_RU.UTF-8 UTF-8
pt_BR.UTF-8 UTF-8
it_IT.UTF-8 UTF-8
ja_JP.UTF-8 UTF-8
LOCALES

locale-gen 2>/dev/null || true

# تثبيت ibus لتبديل لوحة المفاتيح
apt-get install -y --no-install-recommends \
    ibus \
    ibus-gtk3 \
    2>/dev/null || true

# تثبيت xfce4-keyboard-plugin لتبديل اللغة من الـ panel
apt-get install -y --no-install-recommends \
    xfce4-xkb-plugin \
    2>/dev/null || true

log "  Multi-language support installed."

# =============================================================================
# (ح) دعم Bluetooth
# =============================================================================
log "[8] Installing Bluetooth support..."

apt-get install -y --no-install-recommends \
    bluez \
    blueman \
    pulseaudio-module-bluetooth \
    2>/dev/null || true

# تفعيل bluetooth service
systemctl enable bluetooth.service 2>/dev/null || true

log "  Bluetooth support installed."

# =============================================================================
# (ط) GRUB Theme
# =============================================================================
log "[9] Installing GRUB theme..."

GRUB_THEME_DIR="/boot/grub/themes/atlazus"
mkdir -p "$GRUB_THEME_DIR"

GRUB_BG_SVG="${ASSETS_SRC}/grub-background.svg"
[[ -f "$GRUB_BG_SVG" ]] && svg_to_png "$GRUB_BG_SVG" "${GRUB_THEME_DIR}/background.png" 1920 1080 || true
[[ -f "${WORK_LOGO}/atlazus-128.png" ]] && cp "${WORK_LOGO}/atlazus-128.png" "${GRUB_THEME_DIR}/atlazus-logo.png"

cat > "${GRUB_THEME_DIR}/theme.txt" << 'GRUBTHEME'
title-text: ""
desktop-color: "#0a0e27"
desktop-image: "background.png"
terminal-font: "Unifont Regular 16"
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
    item_height = 40
    item_padding = 12
    item_spacing = 4
    scrollbar = false
}

+ label {
    top = 88%
    left = 0
    width = 100%
    align = "center"
    id = "__timeout__"
    text = "Auto boot in %d seconds"
    color = "#00d4ff"
    font = "DejaVu Sans Regular 12"
}
GRUBTHEME

if [[ -f /etc/default/grub ]]; then
    sed -i 's|^GRUB_DISTRIBUTOR=.*|GRUB_DISTRIBUTOR="ATLAZUS OS"|' /etc/default/grub 2>/dev/null || \
        echo 'GRUB_DISTRIBUTOR="ATLAZUS OS"' >> /etc/default/grub
    grep -q "^GRUB_THEME=" /etc/default/grub \
        && sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"${GRUB_THEME_DIR}/theme.txt\"|" /etc/default/grub \
        || echo "GRUB_THEME=\"${GRUB_THEME_DIR}/theme.txt\"" >> /etc/default/grub
fi

update-grub 2>/dev/null || true

# =============================================================================
# (ي) Plymouth Boot Splash
# =============================================================================
log "[10] Installing Plymouth theme..."

PLY_DIR="/usr/share/plymouth/themes/atlazus"
mkdir -p "$PLY_DIR"

PLY_SVG="${ASSETS_SRC}/plymouth-logo.svg"
if [[ -f "$PLY_SVG" ]]; then
    svg_to_png "$PLY_SVG" "${PLY_DIR}/atlazus-logo.png" 256 256 || true
elif [[ -f "${WORK_LOGO}/atlazus-256.png" ]]; then
    cp "${WORK_LOGO}/atlazus-256.png" "${PLY_DIR}/atlazus-logo.png"
fi

cat > "${PLY_DIR}/atlazus.plymouth" << PLYCONF
[Plymouth Theme]
Name=ATLAZUS OS
Description=ATLAZUS OS boot splash
ModuleName=script

[script]
ImageDir=${PLY_DIR}
ScriptFile=${PLY_DIR}/atlazus.script
PLYCONF

cat > "${PLY_DIR}/atlazus.script" << 'PLYSCRIPT'
Window.SetBackgroundTopColor(0.039, 0.055, 0.153);
Window.SetBackgroundBottomColor(0.102, 0.129, 0.282);

logo.image = Image("atlazus-logo.png");
logo.sprite = Sprite(logo.image);
logo.x = Window.GetWidth() / 2 - logo.image.GetWidth() / 2;
logo.y = Window.GetHeight() / 2 - logo.image.GetHeight() / 2 - 30;
logo.sprite.SetPosition(logo.x, logo.y, 0);

progress = 0;
fun refresh_callback() {
    progress++;
    logo.sprite.SetOpacity(0.7 + 0.3 * Math.Cos(progress * 0.05));
}
Plymouth.SetRefreshFunction(refresh_callback);
PLYSCRIPT

update-alternatives --install /usr/share/plymouth/themes/default.plymouth \
    default.plymouth "${PLY_DIR}/atlazus.plymouth" 100 2>/dev/null || true
update-alternatives --set default.plymouth "${PLY_DIR}/atlazus.plymouth" 2>/dev/null || true
update-initramfs -u 2>/dev/null || true

# =============================================================================
# (ك) LightDM Greeter
# =============================================================================
log "[11] Configuring LightDM greeter..."

mkdir -p /etc/lightdm

cat > /etc/lightdm/lightdm-gtk-greeter.conf << 'LIGHTDMCONF'
[greeter]
background=/usr/share/backgrounds/atlazus/login-bg.png
default-user-image=/usr/share/atlazus/logo.png
theme-name=Adwaita-dark
icon-theme-name=Papirus-Dark
font-name=Cantarell 11
position=50%,center 50%,center
hide-user-image=false
show-clock=true
clock-format=%A, %B %d  %H:%M
indicators=~host;~spacer;~clock;~spacer;~session;~language;~power
LIGHTDMCONF

rm -f /etc/lightdm/lightdm-gtk-greeter.conf.d/01_debian.conf 2>/dev/null || true

# =============================================================================
# (ل) os-release / lsb-release / hostname
# =============================================================================
log "[12] Updating system identity..."

# ── Hostname ──────────────────────────────────────────────────────────────────
echo "atlazus" > /etc/hostname

cat > /etc/hosts << 'HOSTS'
127.0.0.1   localhost
127.0.1.1   atlazus
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
HOSTS

# منع live-config من تغيير الـ hostname
mkdir -p /etc/live
cat > /etc/live/config.conf << 'LIVECONF'
# ATLAZUS OS - live-config
LIVE_HOSTNAME="atlazus"
LIVE_USERNAME="atlazus"
LIVECONF

mkdir -p /etc/live/config.conf.d
cat > /etc/live/config.conf.d/atlazus.conf << 'LIVECONF2'
LIVE_HOSTNAME="atlazus"
LIVE_USERNAME="atlazus"
LIVECONF2

# ── os-release ────────────────────────────────────────────────────────────────

cat > /etc/os-release << 'OSREL'
PRETTY_NAME="ATLAZUS OS 2.0"
NAME="ATLAZUS OS"
VERSION_ID="2.0"
VERSION="2.0 (Horizon)"
VERSION_CODENAME=horizon
ID=atlazus
ID_LIKE=debian
HOME_URL="https://atlazus.os"
SUPPORT_URL="https://github.com/atlazus/atlazus-os"
BUG_REPORT_URL="https://github.com/atlazus/atlazus-os/issues"
LOGO=atlazus
OSREL

cat > /etc/lsb-release << 'LSB'
DISTRIB_ID=ATLAZUS
DISTRIB_RELEASE=2.0
DISTRIB_CODENAME=horizon
DISTRIB_DESCRIPTION="ATLAZUS OS 2.0 (Horizon)"
LSB

cat > /etc/motd << 'MOTD'

   ╔══════════════════════════════════════════════╗
   ║              A T L A Z U S   O S             ║
   ║      Secure  ·  Private  ·  Professional     ║
   ╚══════════════════════════════════════════════╝
   Version 2.0 (Horizon)  ·  Base: Debian 13

MOTD

# =============================================================================
# (م) XFCE Settings (theme + icons + panel)
# =============================================================================
log "[13] Applying XFCE settings..."

cat > "${XFCE_CFG_DIR}/xsettings.xml" << 'XSETTINGS'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Arc-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Cantarell 10"/>
    <property name="MonospaceFontName" type="string" value="DejaVu Sans Mono 10"/>
  </property>
</channel>
XSETTINGS

cat > "${XFCE_CFG_DIR}/xfwm4.xml" << 'XFWM'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Arc-Dark"/>
    <property name="title_font" type="string" value="Cantarell Bold 10"/>
  </property>
</channel>
XFWM

# نسخ لمستخدم atlazus
if id atlazus &>/dev/null; then
    USER_XFCE="/home/atlazus/.config/xfce4/xfconf/xfce-perchannel-xml"
    mkdir -p "$USER_XFCE"
    cp "${XFCE_CFG_DIR}/"*.xml "$USER_XFCE/" 2>/dev/null || true
    chown -R atlazus:atlazus /home/atlazus/.config 2>/dev/null || true
fi

# =============================================================================
# (ن) أدوات atlazus CLI
# =============================================================================
log "[14] Installing atlazus CLI tools..."

if [[ -d "$TOOLS_SRC" ]]; then
    for tool in atlazus atlazus-firewall atlazus-privacy; do
        [[ -f "${TOOLS_SRC}/${tool}" ]] && install -Dm755 "${TOOLS_SRC}/${tool}" "/usr/local/bin/${tool}"
    done
    [[ -f "${TOOLS_SRC}/atlazus-tools.desktop" ]] && \
        install -Dm644 "${TOOLS_SRC}/atlazus-tools.desktop" /usr/share/applications/atlazus-tools.desktop
fi

# =============================================================================
# تنظيف
# =============================================================================
rm -rf "$WORK_LOGO" 2>/dev/null || true
apt-get clean 2>/dev/null || true

log "=== ATLAZUS branding complete ==="
