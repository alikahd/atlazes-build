#!/bin/bash
# =============================================================================
# ATLAZUS OS - User Setup
# إنشاء المستخدم atlazus + autologin في Live session
# يُشغَّل داخل chroot
# =============================================================================

set -e

echo "[ATLAZUS] Setting up user..."

USERNAME="atlazus"
PASSWORD="atlazus"

# ── تعيين hostname ────────────────────────────────────────────────────────────
echo "atlazus" > /etc/hostname
cat > /etc/hosts << 'HOSTS'
127.0.0.1   localhost
127.0.1.1   atlazus
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
HOSTS

# ── حذف المستخدم الافتراضي لـ Debian Live ────────────────────────────────────
# Debian Live ينشئ مستخدم "user" افتراضياً — نحذفه ونستبدله بـ atlazus
for old_user in user debian live; do
    if id "$old_user" &>/dev/null; then
        echo "[ATLAZUS] Removing default user '$old_user'..."
        # إيقاف أي عمليات للمستخدم
        pkill -u "$old_user" 2>/dev/null || true
        # حذف المستخدم وملفاته
        userdel -r "$old_user" 2>/dev/null || true
        echo "[ATLAZUS] User '$old_user' removed."
    fi
done

# ── إنشاء المستخدم atlazus ───────────────────────────────────────────────────
if id "$USERNAME" &>/dev/null; then
    echo "[ATLAZUS] User '$USERNAME' already exists, updating password..."
    echo "${USERNAME}:${PASSWORD}" | chpasswd
else
    echo "[ATLAZUS] Creating user '$USERNAME'..."
    useradd -m -s /bin/bash \
        -c "ATLAZUS OS User" \
        -G sudo,adm,cdrom,dip,plugdev,lpadmin \
        "$USERNAME"
    echo "${USERNAME}:${PASSWORD}" | chpasswd
fi

# تعيين كلمة مرور root أيضاً
echo "root:${PASSWORD}" | chpasswd

# إضافة للمجموعات الإضافية
for group in audio video netdev bluetooth scanner; do
    if getent group "$group" &>/dev/null; then
        usermod -aG "$group" "$USERNAME" 2>/dev/null || true
    fi
done

echo "[ATLAZUS] User '$USERNAME' configured."

# ── Sudo بدون كلمة مرور ───────────────────────────────────────────────────────
cat > /etc/sudoers.d/atlazus-live << 'SUDO'
atlazus ALL=(ALL) NOPASSWD: ALL
SUDO
chmod 440 /etc/sudoers.d/atlazus-live

# ── Autologin ─────────────────────────────────────────────────────────────────
mkdir -p /etc/lightdm/lightdm.conf.d

cat > /etc/lightdm/lightdm.conf.d/90-atlazus-autologin.conf << 'LIGHTDM'
[Seat:*]
autologin-user=atlazus
autologin-user-timeout=0
user-session=xfce
LIGHTDM

# مجموعة autologin
groupadd -f autologin 2>/dev/null || true
usermod -aG autologin "$USERNAME" 2>/dev/null || true

echo "[ATLAZUS] Autologin configured."

# ── نسخ إعدادات skeleton ─────────────────────────────────────────────────────
if [[ -d /etc/skel/.config ]]; then
    cp -r /etc/skel/.config "/home/${USERNAME}/" 2>/dev/null || true
    chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.config" 2>/dev/null || true
fi

# ── إنشاء مجلدات المستخدم الأساسية ──────────────────────────────────────────
for dir in Desktop Documents Downloads Music Pictures Videos; do
    mkdir -p "/home/${USERNAME}/${dir}"
done
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}"

# ── Thunar Bookmarks ──────────────────────────────────────────────────────────
mkdir -p "/home/${USERNAME}/.config/gtk-3.0"
cat > "/home/${USERNAME}/.config/gtk-3.0/bookmarks" << 'BOOKMARKS'
file:///home/atlazus/Documents Documents
file:///home/atlazus/Downloads Downloads
file:///home/atlazus/Pictures Pictures
file:///home/atlazus/Music Music
file:///home/atlazus/Videos Videos
BOOKMARKS
chown "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.config/gtk-3.0/bookmarks"

# ── Desktop icons ─────────────────────────────────────────────────────────────
mkdir -p "/home/${USERNAME}/Desktop"

cat > "/home/${USERNAME}/Desktop/install-atlazus.desktop" << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=Install ATLAZUS OS
Comment=Install ATLAZUS OS to your hard drive
Exec=pkexec calamares
Icon=calamares
Terminal=false
Categories=System;
DESKTOP
chmod +x "/home/${USERNAME}/Desktop/install-atlazus.desktop"

# Control Center
cat > "/home/${USERNAME}/Desktop/atlazus-control.desktop" << 'DESKTOP2'
[Desktop Entry]
Type=Application
Name=ATLAZUS Control Center
Comment=Security and Privacy Control Center
Exec=/usr/local/bin/atlazus-control
Icon=atlazus
Terminal=false
Categories=System;
DESKTOP2
chmod +x "/home/${USERNAME}/Desktop/atlazus-control.desktop"

# App Store
cat > "/home/${USERNAME}/Desktop/atlazus-apps.desktop" << 'DESKTOP3'
[Desktop Entry]
Type=Application
Name=ATLAZUS App Store
Comment=Install recommended applications
Exec=/usr/local/bin/atlazus-apps
Icon=system-software-install
Terminal=false
Categories=System;
DESKTOP3
chmod +x "/home/${USERNAME}/Desktop/atlazus-apps.desktop"

# Security Tools
cat > "/home/${USERNAME}/Desktop/atlazus-security-tools.desktop" << 'DESKTOP4'
[Desktop Entry]
Type=Application
Name=Security Tools
Comment=Install security and pentesting tools
Exec=/usr/local/bin/atlazus-security-tools
Icon=security-high
Terminal=false
Categories=System;Security;
DESKTOP4
chmod +x "/home/${USERNAME}/Desktop/atlazus-security-tools.desktop"

# Dashboard
cat > "/home/${USERNAME}/Desktop/atlazus-dashboard.desktop" << 'DESKTOP5'
[Desktop Entry]
Type=Application
Name=ATLAZUS Dashboard
Comment=Security Dashboard
Exec=/usr/local/bin/atlazus-dashboard
Icon=atlazus
Terminal=false
Categories=System;
DESKTOP5
chmod +x "/home/${USERNAME}/Desktop/atlazus-dashboard.desktop"

cat > "/home/${USERNAME}/Desktop/README.txt" << 'README'
═══════════════════════════════════════════════════
           Welcome to ATLAZUS OS 2.0
═══════════════════════════════════════════════════

Live mode — changes lost on reboot.
Login: atlazus / atlazus

── Desktop Icons ───────────────────────────────────
  Install ATLAZUS OS    → Install to hard drive
  ATLAZUS Control Center → Security & Privacy GUI
  ATLAZUS App Store     → Install applications
  Security Tools        → Pentesting tools installer

── CLI Commands ────────────────────────────────────
  atlazus info              System status
  atlazus mode privacy      Enable privacy mode
  atlazus mode stealth      Enable stealth (Tor) mode
  atlazus security          Security tools installer
  atlazus security wifi     Install WiFi tools
  atlazus security web      Install web tools
  atlazus security passwords Install password tools
  atlazus security network  Install network tools
  atlazus security all      Install everything

── Keyboard Shortcuts ──────────────────────────────
  Super             Open application menu
  Ctrl+Alt+T        Open terminal
  Ctrl+Alt+F        Open file manager
  Print             Screenshot
  Super+Left/Right  Tile window

── Privacy Modes ───────────────────────────────────
  normal   Default settings
  privacy  MAC random + DNS Quad9
  stealth  Privacy + Tor routing

⚠️  Security tools are for authorized use only!
═══════════════════════════════════════════════════
README

chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/Desktop"

echo "[ATLAZUS] User setup complete."
