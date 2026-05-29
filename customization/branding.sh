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
# (أ) تثبيت أدوات تحويل الصور أولاً + إصلاح APT
# =============================================================================
log "[1] Fixing APT and installing tools..."

# إصلاح مشكلة sqv "Not live until" — استخدام gnupg الكلاسيكي
apt-get install -y --no-install-recommends gnupg debian-archive-keyring 2>/dev/null || true

# إعداد APT لتجاوز مشكلة sqv
mkdir -p /etc/apt/apt.conf.d
cat > /etc/apt/apt.conf.d/99-atlazus-apt << 'APTCONF'
APT::Key::Assert-Pubkey-Algo ">=rsa1024";
APTCONF

# تحديث sources.list بمصادر صحيحة
cat > /etc/apt/sources.list << 'SOURCES'
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
SOURCES

apt-get update -qq 2>/dev/null || apt-get update -qq --allow-insecure-repositories 2>/dev/null || true

apt-get install -y --no-install-recommends librsvg2-bin 2>/dev/null \
    || apt-get install -y --no-install-recommends imagemagick 2>/dev/null \
    || warn "No image converter available"

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

# Apply the same desktop branding to root, because some users log in as root.
ROOT_XFCE="/root/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$ROOT_XFCE"
cp "${XFCE_CFG_DIR}/xfce4-desktop.xml" "$ROOT_XFCE/" 2>/dev/null || true

# =============================================================================
# (و) حذف "Install Debian" وإضافة "Install ATLAZUS OS"
# =============================================================================
log "[6] Fixing desktop shortcuts..."

# حذف كل اختصارات Debian من كل مكان ممكن
find /usr/share/applications /etc/xdg/autostart /etc/skel /home /root \
    -maxdepth 5 -type f -name "*.desktop" 2>/dev/null | while read -r f; do
    if grep -qi "debian\|install.*debian\|calamares.*debian" "$f" 2>/dev/null; then
        # تحقق أنه ليس اختصار ATLAZUS
        if ! grep -qi "atlazus" "$f" 2>/dev/null; then
            rm -f "$f"
            log "  Removed: $f"
        fi
    fi
done

# حذف بالاسم مباشرة
rm -f /usr/share/applications/debian-*.desktop 2>/dev/null || true
rm -f /usr/share/applications/install-debian.desktop 2>/dev/null || true
rm -f /usr/share/applications/calamares.desktop 2>/dev/null || true

# حذف من سطح مكتب كل المستخدمين
for d in /home/*/Desktop /root/Desktop; do
    [[ -d "$d" ]] || continue
    rm -f "$d"/install-debian.desktop \
          "$d"/"Install Debian.desktop" \
          "$d"/debian*.desktop \
          "$d"/calamares.desktop 2>/dev/null || true
done

# إنشاء اختصار ATLAZUS فقط
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

# نسخ لسطح مكتب root
mkdir -p /root/Desktop
cp /usr/share/applications/install-atlazus.desktop /root/Desktop/
chmod +x /root/Desktop/install-atlazus.desktop

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
theme-name=Arc-Dark
icon-theme-name=Papirus-Dark
font-name=Cantarell 12
xft-antialias=true
xft-dpi=96
xft-hintstyle=hintslight
xft-rgba=rgb
position=50%,center 50%,center
hide-user-image=false
show-clock=true
clock-format=<b>%H:%M</b>  %A, %B %d
panel-position=top
indicators=~host;~spacer;~clock;~spacer;~session;~language;~power
reader=
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
    <property name="DoubleClickTime" type="int" value="400"/>
    <property name="CursorBlink" type="bool" value="true"/>
    <property name="CursorBlinkTime" type="int" value="1200"/>
    <property name="EnableEventSounds" type="bool" value="false"/>
    <property name="EnableInputFeedbackSounds" type="bool" value="false"/>
  </property>
  <property name="Xft" type="empty">
    <property name="Antialias" type="int" value="1"/>
    <property name="Hinting" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="string" value="rgb"/>
    <property name="DPI" type="int" value="96"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Cantarell 11"/>
    <property name="MonospaceFontName" type="string" value="DejaVu Sans Mono 11"/>
    <property name="CursorThemeName" type="string" value="Adwaita"/>
    <property name="CursorThemeSize" type="int" value="24"/>
    <property name="ToolbarStyle" type="string" value="icons"/>
    <property name="ButtonImages" type="bool" value="true"/>
    <property name="MenuImages" type="bool" value="true"/>
    <property name="DecorationLayout" type="string" value="menu:minimize,maximize,close"/>
  </property>
</channel>
XSETTINGS

cat > "${XFCE_CFG_DIR}/xfwm4.xml" << 'XFWM'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Arc-Dark"/>
    <property name="title_font" type="string" value="Cantarell Bold 11"/>
    <property name="button_layout" type="string" value="O|HMC"/>
    <property name="use_compositing" type="bool" value="false"/>
    <property name="frame_opacity" type="int" value="100"/>
    <property name="shadow_delta_height" type="int" value="-3"/>
    <property name="shadow_delta_width" type="int" value="0"/>
    <property name="shadow_opacity" type="int" value="50"/>
    <property name="workspace_count" type="int" value="2"/>
    <property name="snap_to_windows" type="bool" value="true"/>
    <property name="snap_to_border" type="bool" value="true"/>
    <property name="snap_width" type="int" value="10"/>
    <property name="wrap_workspaces" type="bool" value="false"/>
    <property name="wrap_windows" type="bool" value="false"/>
  </property>
</channel>
XFWM

# Panel محسّن مع أدوات ATLAZUS
cat > "${XFCE_CFG_DIR}/xfce4-panel.xml" << 'PANEL'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="30"/>
      <property name="background-style" type="uint" value="1"/>
      <property name="background-rgba" type="array">
        <value type="double" value="0.039"/>
        <value type="double" value="0.055"/>
        <value type="double" value="0.153"/>
        <value type="double" value="0.95"/>
      </property>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
        <value type="int" value="6"/>
        <value type="int" value="7"/>
        <value type="int" value="8"/>
        <value type="int" value="9"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="whiskermenu">
      <property name="button-icon" type="string" value="atlazus"/>
      <property name="button-title" type="string" value="ATLAZUS"/>
      <property name="show-button-title" type="bool" value="false"/>
      <property name="show-button-icon" type="bool" value="true"/>
    </property>
    <property name="plugin-2" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-3" type="string" value="tasklist">
      <property name="show-labels" type="bool" value="true"/>
      <property name="grouping" type="uint" value="1"/>
    </property>
    <property name="plugin-4" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-5" type="string" value="systray">
      <property name="size-max" type="uint" value="22"/>
    </property>
    <property name="plugin-6" type="string" value="pulseaudio">
      <property name="enable-keyboard-shortcuts" type="bool" value="true"/>
    </property>
    <property name="plugin-7" type="string" value="power-manager-plugin"/>
    <property name="plugin-8" type="string" value="clock">
      <property name="digital-format" type="string" value="%H:%M  %a %d %b"/>
      <property name="mode" type="uint" value="2"/>
    </property>
    <property name="plugin-9" type="string" value="actions">
      <property name="appearance" type="uint" value="0"/>
      <property name="items" type="array">
        <value type="string" value="-lock-screen"/>
        <value type="string" value="+switch-user"/>
        <value type="string" value="+separator"/>
        <value type="string" value="+suspend"/>
        <value type="string" value="+hibernate"/>
        <value type="string" value="+separator"/>
        <value type="string" value="+shutdown"/>
        <value type="string" value="+restart"/>
        <value type="string" value="+separator"/>
        <value type="string" value="+logout"/>
      </property>
    </property>
  </property>
</channel>
PANEL

# إعدادات Thunar (file manager)
mkdir -p "${XFCE_CFG_DIR}"
cat > "${XFCE_CFG_DIR}/thunar.xml" << 'THUNAR'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="thunar" version="1.0">
  <property name="last-view" type="string" value="ThunarDetailsView"/>
  <property name="last-icon-view-zoom-level" type="string" value="THUNAR_ZOOM_LEVEL_100_PERCENT"/>
  <property name="last-details-view-zoom-level" type="string" value="THUNAR_ZOOM_LEVEL_38_PERCENT"/>
  <property name="last-details-view-column-order" type="string" value="THUNAR_COLUMN_NAME,THUNAR_COLUMN_SIZE,THUNAR_COLUMN_TYPE,THUNAR_COLUMN_DATE_MODIFIED"/>
  <property name="last-details-view-column-widths" type="string" value="50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50"/>
  <property name="last-details-view-fixed-columns" type="bool" value="false"/>
  <property name="last-show-hidden" type="bool" value="false"/>
  <property name="last-window-width" type="int" value="900"/>
  <property name="last-window-height" type="int" value="600"/>
  <property name="last-window-maximized" type="bool" value="false"/>
  <property name="misc-single-click" type="bool" value="false"/>
  <property name="misc-show-delete-action" type="bool" value="true"/>
  <property name="misc-thumbnail-mode" type="string" value="THUNAR_THUMBNAIL_MODE_ALWAYS"/>
</channel>
THUNAR

# إعدادات Terminal
mkdir -p "/etc/skel/.config/xfce4/terminal"
cat > "/etc/skel/.config/xfce4/terminal/terminalrc" << 'TERMRC'
[Configuration]
FontName=DejaVu Sans Mono 11
MiscAlwaysShowTabs=FALSE
MiscBell=FALSE
MiscBordersDefault=TRUE
MiscCursorBlinks=FALSE
MiscCursorShape=TERMINAL_CURSOR_SHAPE_BLOCK
MiscDefaultGeometry=100x30
MiscMenubarDefault=FALSE
MiscMouseAutohide=FALSE
MiscToolbarDefault=FALSE
MiscConfirmClose=TRUE
MiscCycleTabs=TRUE
MiscTabCloseButtons=TRUE
MiscTabPosition=GTK_POS_TOP
MiscHighlightUrls=TRUE
MiscScrollOnOutput=FALSE
MiscScrollOnKeystroke=TRUE
ScrollingBar=TERMINAL_SCROLLBAR_NONE
ScrollingLines=10000
ColorForeground=#d8d8d8
ColorBackground=#0a0e27
ColorCursor=#00d4ff
ColorPalette=#1e1e2e;#f38ba8;#a6e3a1;#f9e2af;#89b4fa;#cba6f7;#89dceb;#cdd6f4;#585b70;#f38ba8;#a6e3a1;#f9e2af;#89b4fa;#cba6f7;#89dceb;#ffffff
ColorBold=#ffffff
ColorBoldUseDefault=FALSE
TERMRC

# نسخ لمستخدم atlazus
if id atlazus &>/dev/null; then
    USER_XFCE="/home/atlazus/.config/xfce4/xfconf/xfce-perchannel-xml"
    mkdir -p "$USER_XFCE"
    cp "${XFCE_CFG_DIR}/"*.xml "$USER_XFCE/" 2>/dev/null || true
    # نسخ terminal config
    mkdir -p /home/atlazus/.config/xfce4/terminal
    cp /etc/skel/.config/xfce4/terminal/terminalrc \
       /home/atlazus/.config/xfce4/terminal/ 2>/dev/null || true
    chown -R atlazus:atlazus /home/atlazus/.config 2>/dev/null || true
fi

# نسخ لـ root أيضاً (لمنع ظهور خلفية Debian عند الدخول كـ root)
ROOT_XFCE="/root/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$ROOT_XFCE"
cp "${XFCE_CFG_DIR}/"*.xml "$ROOT_XFCE/" 2>/dev/null || true
mkdir -p /root/.config/xfce4/terminal
cp /etc/skel/.config/xfce4/terminal/terminalrc \
   /root/.config/xfce4/terminal/ 2>/dev/null || true

# نسخ لـ /etc/skel (لأي مستخدم جديد)
mkdir -p "/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"
cp "${XFCE_CFG_DIR}/"*.xml "/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/" 2>/dev/null || true

# ── Keyboard Shortcuts ────────────────────────────────────────────────────────
log "  Setting keyboard shortcuts..."
cat > "${XFCE_CFG_DIR}/xfce4-keyboard-shortcuts.xml" << 'KBSHORTCUTS'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-keyboard-shortcuts" version="1.0">
  <property name="commands" type="empty">
    <property name="custom" type="empty">
      <property name="Super_L" type="string" value="xfce4-popup-whiskermenu"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;t" type="string" value="xfce4-terminal"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;f" type="string" value="thunar"/>
      <property name="Print" type="string" value="xfce4-screenshooter"/>
      <property name="&lt;Alt&gt;F2" type="string" value="xfce4-appfinder --collapsed"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;l" type="string" value="xflock4"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;Delete" type="string" value="xfce4-session-logout"/>
    </property>
  </property>
  <property name="xfwm4" type="empty">
    <property name="custom" type="empty">
      <property name="&lt;Alt&gt;F4" type="string" value="close_window_key"/>
      <property name="&lt;Alt&gt;F5" type="string" value="maximize_horiz_key"/>
      <property name="&lt;Alt&gt;F6" type="string" value="maximize_vert_key"/>
      <property name="&lt;Alt&gt;F7" type="string" value="move_window_key"/>
      <property name="&lt;Alt&gt;F8" type="string" value="resize_window_key"/>
      <property name="&lt;Alt&gt;F9" type="string" value="hide_window_key"/>
      <property name="&lt;Alt&gt;F10" type="string" value="maximize_window_key"/>
      <property name="&lt;Alt&gt;F11" type="string" value="fullscreen_key"/>
      <property name="&lt;Alt&gt;Tab" type="string" value="cycle_windows_key"/>
      <property name="&lt;Super&gt;d" type="string" value="show_desktop_key"/>
      <property name="&lt;Super&gt;Left" type="string" value="tile_left_key"/>
      <property name="&lt;Super&gt;Right" type="string" value="tile_right_key"/>
      <property name="&lt;Super&gt;Up" type="string" value="maximize_window_key"/>
      <property name="&lt;Super&gt;Down" type="string" value="hide_window_key"/>
    </property>
  </property>
</channel>
KBSHORTCUTS

# نسخ shortcuts لجميع المستخدمين
for dest in \
    "/home/atlazus/.config/xfce4/xfconf/xfce-perchannel-xml" \
    "/root/.config/xfce4/xfconf/xfce-perchannel-xml" \
    "/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"; do
    mkdir -p "$dest"
    cp "${XFCE_CFG_DIR}/xfce4-keyboard-shortcuts.xml" "$dest/" 2>/dev/null || true
done
chown -R atlazus:atlazus /home/atlazus/.config 2>/dev/null || true

# =============================================================================
# (ن) أدوات atlazus CLI + Welcome + Control Center
# =============================================================================
log "[14] Installing atlazus CLI tools..."

# ── Whisker Menu config ───────────────────────────────────────────────────────
mkdir -p /etc/skel/.config/xfce4
cat > /etc/skel/.config/xfce4/whiskermenu-1.rc << 'WHISKER'
button-icon-name=atlazus
button-single-row=false
show-button-title=false
show-button-icon=true
show-recent-by-default=false
show-favorites=true
show-recent=true
show-applications=true
item-icon-size=2
hover-switch-category=false
category-icon-size=1
load-hierarchy=false
position-search-alternate=true
position-commands-alternate=false
position-categories-alternate=true
stay-on-focus-out=false
profile-shape=0
confirm-session-command=true
menu-width=500
menu-height=450
menu-opacity=95
favorites=xfce4-terminal.desktop,thunar.desktop,firefox-esr.desktop,atlazus-control.desktop,atlazus-apps.desktop,install-atlazus.desktop
WHISKER

# ── Notifications config ──────────────────────────────────────────────────────
cat > "${XFCE_CFG_DIR}/xfce4-notifyd.xml" << 'NOTIFYD'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-notifyd" version="1.0">
  <property name="theme" type="string" value="Default"/>
  <property name="notify-location" type="uint" value="3"/>
  <property name="do-fadeout" type="bool" value="true"/>
  <property name="do-slideout" type="bool" value="false"/>
  <property name="expire-timeout" type="int" value="5"/>
  <property name="initial-opacity" type="double" value="0.9"/>
  <property name="log-level" type="uint" value="0"/>
  <property name="log-level-apps" type="uint" value="0"/>
</channel>
NOTIFYD

# ── Power Manager config ──────────────────────────────────────────────────────
cat > "${XFCE_CFG_DIR}/xfce4-power-manager.xml" << 'POWERMGR'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="power-button-action" type="uint" value="4"/>
    <property name="show-tray-icon" type="bool" value="true"/>
    <property name="dpms-enabled" type="bool" value="false"/>
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="dpms-on-ac-sleep" type="uint" value="0"/>
    <property name="dpms-on-ac-off" type="uint" value="0"/>
    <property name="lock-screen-suspend-hibernate" type="bool" value="false"/>
    <property name="brightness-switch" type="int" value="0"/>
    <property name="brightness-switch-restore-on-exit" type="int" value="1"/>
  </property>
</channel>
POWERMGR

# نسخ configs الجديدة لجميع المستخدمين
for dest in \
    "/home/atlazus/.config/xfce4/xfconf/xfce-perchannel-xml" \
    "/root/.config/xfce4/xfconf/xfce-perchannel-xml" \
    "/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"; do
    mkdir -p "$dest"
    cp "${XFCE_CFG_DIR}/xfce4-notifyd.xml" "$dest/" 2>/dev/null || true
    cp "${XFCE_CFG_DIR}/xfce4-power-manager.xml" "$dest/" 2>/dev/null || true
done

# نسخ Whisker Menu config
for dest in /home/atlazus/.config/xfce4 /root/.config/xfce4 /etc/skel/.config/xfce4; do
    mkdir -p "$dest"
    cp /etc/skel/.config/xfce4/whiskermenu-1.rc "$dest/" 2>/dev/null || true
done
chown -R atlazus:atlazus /home/atlazus/.config 2>/dev/null || true

if [[ -d "$TOOLS_SRC" ]]; then
    for tool in atlazus atlazus-firewall atlazus-privacy atlazus-mode atlazus-control atlazus-welcome atlazus-apps atlazus-persist atlazus-security-tools atlazus-dashboard atlazus-vbox-setup atlazus-post-install; do
        if [[ -f "${TOOLS_SRC}/${tool}" ]]; then
            install -Dm755 "${TOOLS_SRC}/${tool}" "/usr/local/bin/${tool}"
            log "  ✓ ${tool}"
        fi
    done

    for desktop in atlazus-tools.desktop atlazus-control.desktop atlazus-welcome.desktop atlazus-apps.desktop atlazus-security-tools.desktop atlazus-dashboard.desktop; do
        [[ -f "${TOOLS_SRC}/${desktop}" ]] && \
            install -Dm644 "${TOOLS_SRC}/${desktop}" "/usr/share/applications/${desktop}"
    done

    if [[ -f "${TOOLS_SRC}/atlazus-welcome.desktop" ]]; then
        mkdir -p /etc/xdg/autostart
        install -Dm644 "${TOOLS_SRC}/atlazus-welcome.desktop" \
            /etc/xdg/autostart/atlazus-welcome.desktop
    fi
fi

# إنشاء مجلد state
mkdir -p /var/lib/atlazus
echo "normal" > /var/lib/atlazus/current-mode
chmod 777 /var/lib/atlazus
chmod 666 /var/lib/atlazus/current-mode

# ── Arabic Language Support ───────────────────────────────────────────────────
log "  Setting up Arabic language support..."

# توليد Arabic locale
if ! grep -q "ar_SA.UTF-8" /etc/locale.gen 2>/dev/null; then
    echo "ar_SA.UTF-8 UTF-8" >> /etc/locale.gen
    echo "ar_MA.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen 2>/dev/null || true
fi

# إعداد ibus للعربية
mkdir -p /etc/skel/.config/ibus
cat > /etc/skel/.config/ibus/bus << 'IBUSCONF'
[ibus]
preload-engines=xkb:us::eng,xkb:ara::ara
IBUSCONF

# إضافة Arabic keyboard في XFCE
cat > "${XFCE_CFG_DIR}/xfce4-xkb-plugin.xml" << 'XKBCONF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-xkb-plugin" version="1.0">
  <property name="settings" type="empty">
    <property name="display-type" type="uint" value="1"/>
    <property name="display-name" type="uint" value="0"/>
    <property name="group-policy" type="uint" value="0"/>
    <property name="default-layout" type="string" value="us"/>
    <property name="layouts" type="string" value="us,ara"/>
    <property name="variants" type="string" value=","/>
    <property name="toggle-option" type="string" value="grp:alt_shift_toggle"/>
  </property>
</channel>
XKBCONF

for dest in \
    "/home/atlazus/.config/xfce4/xfconf/xfce-perchannel-xml" \
    "/root/.config/xfce4/xfconf/xfce-perchannel-xml" \
    "/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"; do
    mkdir -p "$dest"
    cp "${XFCE_CFG_DIR}/xfce4-xkb-plugin.xml" "$dest/" 2>/dev/null || true
done
chown -R atlazus:atlazus /home/atlazus/.config 2>/dev/null || true

log "  Arabic keyboard: Alt+Shift to switch"

# ── VirtualBox Auto-Setup ─────────────────────────────────────────────────────
log "  Setting up VirtualBox auto-detection..."

cat > /etc/systemd/system/atlazus-vbox.service << 'VBOXSVC'
[Unit]
Description=ATLAZUS VirtualBox Guest Setup
After=network.target
ConditionPathExists=!/var/lib/atlazus/.vbox-done

[Service]
Type=oneshot
ExecStart=/usr/local/bin/atlazus-vbox-setup
ExecStartPost=/bin/bash -c 'touch /var/lib/atlazus/.vbox-done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
VBOXSVC

systemctl enable atlazus-vbox.service 2>/dev/null || true

# ── Dashboard autostart ───────────────────────────────────────────────────────
# لا نُشغّل Dashboard تلقائياً — المستخدم يفتحه من سطح المكتب
# لكن نُضيفه لـ Whisker Menu favorites
log "  Dashboard installed — accessible from desktop"

# ── Bash aliases + محسّن ──────────────────────────────────────────────────────
log "  Setting up bash aliases..."
cat > /etc/skel/.bash_aliases << 'ALIASES'
# ATLAZUS OS - Bash Aliases

# Navigation
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias ~='cd ~'

# Safety
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# System
alias update='sudo apt update && sudo apt upgrade -y'
alias install='sudo apt install'
alias remove='sudo apt remove'
alias search='apt search'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ps='ps aux'
alias top='htop'

# Network
alias ip='ip -c'
alias ports='ss -tulpn'
alias myip='curl -s ifconfig.me'

# ATLAZUS shortcuts
alias status='atlazus info'
alias fw='atlazus-firewall'
alias privacy='atlazus-privacy'
alias mode='atlazus mode'
alias control='atlazus-control'
alias apps='atlazus-apps'
ALIASES

# نسخ aliases لجميع المستخدمين
cp /etc/skel/.bash_aliases /home/atlazus/.bash_aliases 2>/dev/null || true
cp /etc/skel/.bash_aliases /root/.bash_aliases 2>/dev/null || true
chown atlazus:atlazus /home/atlazus/.bash_aliases 2>/dev/null || true

# ── Bashrc محسّن مع prompt ملوّن ──────────────────────────────────────────────
cat > /etc/skel/.bashrc << 'BASHRC'
# ATLAZUS OS - Bash Configuration

# Source aliases
[[ -f ~/.bash_aliases ]] && . ~/.bash_aliases

# History
HISTSIZE=5000
HISTFILESIZE=10000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# Window size
shopt -s checkwinsize

# Prompt ملوّن مع اسم ATLAZUS
if [[ $EUID -eq 0 ]]; then
    PS1='\[\033[01;31m\]\u\[\033[00m\]@\[\033[01;36m\]atlazus\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='\[\033[01;32m\]\u\[\033[00m\]@\[\033[01;36m\]atlazus\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
fi

# Auto-complete
if ! shopt -oq posix; then
    if [[ -f /usr/share/bash-completion/bash_completion ]]; then
        . /usr/share/bash-completion/bash_completion
    fi
fi

# ATLAZUS welcome message (terminal)
if [[ -z "$ATLAZUS_GREETED" ]]; then
    export ATLAZUS_GREETED=1
    echo -e "\033[0;36m  ATLAZUS OS 2.0 (Horizon)\033[0m  |  Type \033[1matlazus help\033[0m for commands"
fi
BASHRC

cp /etc/skel/.bashrc /home/atlazus/.bashrc 2>/dev/null || true
cp /etc/skel/.bashrc /root/.bashrc 2>/dev/null || true
chown atlazus:atlazus /home/atlazus/.bashrc 2>/dev/null || true

# ── Neofetch config مخصص ─────────────────────────────────────────────────────
log "  Setting up neofetch..."
mkdir -p /etc/skel/.config/neofetch
cat > /etc/skel/.config/neofetch/config.conf << 'NEOFETCH'
print_info() {
    info title
    info underline
    info "OS" distro
    info "Kernel" kernel
    info "Uptime" uptime
    info "Packages" packages
    info "Shell" shell
    info "Resolution" resolution
    info "DE" de
    info "WM" wm
    info "Theme" theme
    info "Icons" icons
    info "Terminal" term
    info "CPU" cpu
    info "Memory" memory
    info cols
}
title_fqdn="off"
kernel_shorthand="on"
distro_shorthand="off"
os_arch="on"
uptime_shorthand="on"
memory_percent="on"
memory_unit="mib"
package_managers="on"
shell_path="off"
shell_version="on"
cpu_brand="on"
cpu_speed="on"
cpu_cores="logical"
cpu_temp="off"
gpu_brand="on"
gpu_type="all"
refresh_rate="on"
gtk_shorthand="on"
gtk2="on"
gtk3="on"
colors=(distro)
bold="on"
underline_enabled="on"
underline_char="-"
separator=":"
block_range=(0 15)
color_blocks="on"
block_width=3
block_height=1
col_offset="auto"
image_backend="ascii"
image_source="auto"
ascii_distro="Debian"
ascii_colors=(6 6)
ascii_bold="on"
NEOFETCH

cp -r /etc/skel/.config/neofetch /home/atlazus/.config/ 2>/dev/null || true
cp -r /etc/skel/.config/neofetch /root/.config/ 2>/dev/null || true
chown -R atlazus:atlazus /home/atlazus/.config/neofetch 2>/dev/null || true

# =============================================================================
# تنظيف
# =============================================================================
rm -rf "$WORK_LOGO" 2>/dev/null || true
apt-get clean 2>/dev/null || true

log "=== ATLAZUS branding complete ==="
