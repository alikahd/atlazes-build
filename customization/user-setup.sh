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

cat > "/home/${USERNAME}/Desktop/README.txt" << 'README'
═══════════════════════════════════════════
        Welcome to ATLAZUS OS 2.0
═══════════════════════════════════════════

Live mode — changes lost on reboot.

Login: atlazus / atlazus

Install: double-click "Install ATLAZUS OS"

Security: UFW + AppArmor + Firejail active
═══════════════════════════════════════════
README

chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/Desktop"

echo "[ATLAZUS] User setup complete."
