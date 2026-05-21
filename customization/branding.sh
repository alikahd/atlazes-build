#!/bin/bash
# =============================================================================
# ATLAZES OS - Branding
# os-release + hostname + MOTD + wallpaper + theme
# يُشغَّل داخل chroot
# =============================================================================

set -e

echo "[ATLAZES] Applying branding..."

# ── os-release ────────────────────────────────────────────────────────────────
echo "[ATLAZES] Setting os-release..."

cat > /etc/os-release << 'OSRELEASE'
PRETTY_NAME="ATLAZES OS 2.0 (Trixie)"
NAME="ATLAZES OS"
VERSION_ID="2.0"
VERSION="2.0 (Trixie)"
VERSION_CODENAME=trixie
ID=atlazes
ID_LIKE=debian
HOME_URL="https://github.com/atlazes"
SUPPORT_URL="https://github.com/atlazes/atlazes-os/issues"
BUG_REPORT_URL="https://github.com/atlazes/atlazes-os/issues"
PRIVACY_POLICY_URL="https://github.com/atlazes/atlazes-os/blob/main/PRIVACY.md"
OSRELEASE

# نسخة إضافية
cat > /etc/atlazes-release << 'RELEASE'
ATLAZES OS 2.0
Base: Debian 13 (Trixie)
Build Method: ISO Remastering
Focus: Security & Privacy
RELEASE

echo "[ATLAZES] os-release configured."

# ── Hostname ──────────────────────────────────────────────────────────────────
echo "[ATLAZES] Setting hostname..."

echo "atlazes" > /etc/hostname

cat > /etc/hosts << 'HOSTS'
127.0.0.1	localhost
127.0.1.1	atlazes

# IPv6
::1		localhost ip6-localhost ip6-loopback
ff02::1		ip6-allnodes
ff02::2		ip6-allrouters
HOSTS

echo "[ATLAZES] Hostname set to 'atlazes'."

# ── MOTD ──────────────────────────────────────────────────────────────────────
echo "[ATLAZES] Setting MOTD..."

cat > /etc/motd << 'MOTD'

    ╔══════════════════════════════════════════════════╗
    ║              ATLAZES OS v2.0                     ║
    ║        Secure · Private · Professional           ║
    ╠══════════════════════════════════════════════════╣
    ║  Base: Debian 13 (Trixie)                        ║
    ║  Security: AppArmor + UFW + Firejail             ║
    ║  Privacy: MAC random + DNS privacy + Tor ready   ║
    ╚══════════════════════════════════════════════════╝

MOTD

echo "[ATLAZES] MOTD configured."

# ── Issue (login screen message) ──────────────────────────────────────────────
cat > /etc/issue << 'ISSUE'
ATLAZES OS 2.0 \n \l

ISSUE

cat > /etc/issue.net << 'ISSUENET'
ATLAZES OS 2.0
ISSUENET

# ── Desktop Wallpaper ─────────────────────────────────────────────────────────
echo "[ATLAZES] Setting up wallpaper..."

mkdir -p /usr/share/backgrounds/atlazes

# إنشاء wallpaper بسيط (SVG) إذا لم يكن موجوداً
if [[ ! -f /usr/share/backgrounds/atlazes/default.svg ]]; then
    cat > /usr/share/backgrounds/atlazes/default.svg << 'SVG'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1a1a2e"/>
      <stop offset="50%" style="stop-color:#16213e"/>
      <stop offset="100%" style="stop-color:#0f3460"/>
    </linearGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#bg)"/>
  <text x="960" y="540" font-family="sans-serif" font-size="72" font-weight="bold"
        fill="#e94560" text-anchor="middle" opacity="0.3">ATLAZES</text>
  <text x="960" y="620" font-family="sans-serif" font-size="24"
        fill="#ffffff" text-anchor="middle" opacity="0.5">Secure · Private · Professional</text>
</svg>
SVG
fi

# تحويل SVG إلى PNG إذا rsvg-convert متوفر
if command -v rsvg-convert &>/dev/null; then
    rsvg-convert -w 1920 -h 1080 \
        /usr/share/backgrounds/atlazes/default.svg \
        -o /usr/share/backgrounds/atlazes/default.png 2>/dev/null || true
fi

echo "[ATLAZES] Wallpaper configured."

# ── XFCE Default Settings ────────────────────────────────────────────────────
echo "[ATLAZES] Setting XFCE defaults..."

# إعداد خلفية افتراضية لـ XFCE (skeleton)
mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml

cat > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'XFCEDESKTOP'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorVirtual-1" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/atlazes/default.png"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
    </property>
  </property>
</channel>
XFCEDESKTOP

echo "[ATLAZES] XFCE defaults configured."

# ── Desktop Shortcuts ─────────────────────────────────────────────────────────
echo "[ATLAZES] Creating desktop shortcuts..."

mkdir -p /usr/share/applications

# Calamares installer shortcut
cat > /usr/share/applications/install-atlazes.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=Install ATLAZES OS
Comment=Install ATLAZES OS to disk
Exec=pkexec calamares
Icon=calamares
Terminal=false
Categories=System;
Keywords=install;installer;calamares;
DESKTOP

# ATLAZES Security Tools shortcut
cat > /usr/share/applications/atlazes-security.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=ATLAZES Security
Comment=Security tools and status
Exec=xfce4-terminal -e "sudo lynis audit system"
Icon=security-high
Terminal=false
Categories=System;Security;
Keywords=security;audit;lynis;
DESKTOP

echo "[ATLAZES] Desktop shortcuts created."

# ── Plymouth/Boot Splash (optional) ──────────────────────────────────────────
# لا نُعدّل Plymouth — نستخدم الافتراضي من Debian

echo "[ATLAZES] Branding complete."
