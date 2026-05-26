#!/bin/bash
# =============================================================================
# ATLAZES OS - User Setup
# إنشاء المستخدم atlazes + autologin في Live session
# يُشغَّل داخل chroot
# =============================================================================

set -e

echo "[ATLAZES] Setting up user..."

USERNAME="atlazes"
PASSWORD="atlazes"

# ── حذف المستخدم الافتراضي لـ Debian Live ────────────────────────────────────
# Debian Live ينشئ مستخدم "user" افتراضياً — نحذفه ونستبدله بـ atlazes
for old_user in user debian live; do
    if id "$old_user" &>/dev/null; then
        echo "[ATLAZES] Removing default user '$old_user'..."
        # إيقاف أي عمليات للمستخدم
        pkill -u "$old_user" 2>/dev/null || true
        # حذف المستخدم وملفاته
        userdel -r "$old_user" 2>/dev/null || true
        echo "[ATLAZES] User '$old_user' removed."
    fi
done

# ── إنشاء المستخدم atlazes ───────────────────────────────────────────────────
if id "$USERNAME" &>/dev/null; then
    echo "[ATLAZES] User '$USERNAME' already exists, updating password..."
    echo "${USERNAME}:${PASSWORD}" | chpasswd
else
    echo "[ATLAZES] Creating user '$USERNAME'..."
    useradd -m -s /bin/bash \
        -c "ATLAZES OS User" \
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

echo "[ATLAZES] User '$USERNAME' configured."

# ── Sudo بدون كلمة مرور ───────────────────────────────────────────────────────
cat > /etc/sudoers.d/atlazes-live << 'SUDO'
atlazes ALL=(ALL) NOPASSWD: ALL
SUDO
chmod 440 /etc/sudoers.d/atlazes-live

# ── Autologin ─────────────────────────────────────────────────────────────────
mkdir -p /etc/lightdm/lightdm.conf.d

cat > /etc/lightdm/lightdm.conf.d/90-atlazes-autologin.conf << 'LIGHTDM'
[Seat:*]
autologin-user=atlazes
autologin-user-timeout=0
user-session=xfce
LIGHTDM

# مجموعة autologin
groupadd -f autologin 2>/dev/null || true
usermod -aG autologin "$USERNAME" 2>/dev/null || true

echo "[ATLAZES] Autologin configured."

# ── نسخ إعدادات skeleton ─────────────────────────────────────────────────────
if [[ -d /etc/skel/.config ]]; then
    cp -r /etc/skel/.config "/home/${USERNAME}/" 2>/dev/null || true
    chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.config" 2>/dev/null || true
fi

# ── Desktop icons ─────────────────────────────────────────────────────────────
mkdir -p "/home/${USERNAME}/Desktop"

cat > "/home/${USERNAME}/Desktop/install-atlazes.desktop" << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=Install ATLAZES OS
Comment=Install ATLAZES OS to your hard drive
Exec=pkexec calamares
Icon=calamares
Terminal=false
Categories=System;
DESKTOP
chmod +x "/home/${USERNAME}/Desktop/install-atlazes.desktop"

cat > "/home/${USERNAME}/Desktop/README.txt" << 'README'
═══════════════════════════════════════════
        Welcome to ATLAZES OS 2.0
═══════════════════════════════════════════

Live mode — changes lost on reboot.

Login: atlazes / atlazes

Install: double-click "Install ATLAZES OS"

Security: UFW + AppArmor + Firejail active
═══════════════════════════════════════════
README

chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/Desktop"

echo "[ATLAZES] User setup complete."
