#!/bin/bash
# =============================================================================
# ATLAZES OS - User Setup
# إنشاء المستخدم atlazes + autologin في Live session
# يُشغَّل داخل chroot
# =============================================================================

set -e

echo "[ATLAZES] Setting up user..."

# ── إنشاء المستخدم atlazes ───────────────────────────────────────────────────
USERNAME="atlazes"
PASSWORD="atlazes"

# التحقق إذا المستخدم موجود
if id "$USERNAME" &>/dev/null; then
    echo "[ATLAZES] User '$USERNAME' already exists, updating..."
    echo "${USERNAME}:${PASSWORD}" | chpasswd
else
    echo "[ATLAZES] Creating user '$USERNAME'..."
    useradd -m -s /bin/bash \
        -c "ATLAZES User" \
        -G sudo,adm,cdrom,dip,plugdev,lpadmin \
        "$USERNAME"
    echo "${USERNAME}:${PASSWORD}" | chpasswd
fi

# إضافة للمجموعات الإضافية (إذا وُجدت)
for group in audio video netdev bluetooth scanner; do
    if getent group "$group" &>/dev/null; then
        usermod -aG "$group" "$USERNAME" 2>/dev/null || true
    fi
done

echo "[ATLAZES] User '$USERNAME' configured."

# ── Sudo بدون كلمة مرور (Live session فقط) ───────────────────────────────────
echo "[ATLAZES] Configuring sudo..."

cat > /etc/sudoers.d/atlazes-live << 'SUDO'
# ATLAZES OS - Live session sudo (passwordless)
# يُحذف هذا الملف عند التثبيت بواسطة Calamares
atlazes ALL=(ALL) NOPASSWD: ALL
SUDO
chmod 440 /etc/sudoers.d/atlazes-live

echo "[ATLAZES] Sudo configured."

# ── Autologin (Live session) ──────────────────────────────────────────────────
echo "[ATLAZES] Configuring autologin..."

# LightDM autologin — الطريقة الصحيحة لـ Debian Live
mkdir -p /etc/lightdm/lightdm.conf.d

cat > /etc/lightdm/lightdm.conf.d/90-atlazes-autologin.conf << 'LIGHTDM'
[Seat:*]
autologin-user=atlazes
autologin-user-timeout=0
LIGHTDM

# إضافة المستخدم لمجموعة autologin
groupadd -f autologin
usermod -aG autologin "$USERNAME"

echo "[ATLAZES] Autologin configured for '$USERNAME'."

# ── نسخ إعدادات skeleton ─────────────────────────────────────────────────────
echo "[ATLAZES] Copying skeleton to user home..."

# نسخ إعدادات XFCE من skeleton
if [[ -d /etc/skel/.config ]]; then
    cp -r /etc/skel/.config "/home/${USERNAME}/" 2>/dev/null || true
    chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.config" 2>/dev/null || true
fi

# ── Desktop icons for live session ────────────────────────────────────────────
echo "[ATLAZES] Setting up desktop icons..."

mkdir -p "/home/${USERNAME}/Desktop"

# اختصار التثبيت على سطح المكتب
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

# ملف README
cat > "/home/${USERNAME}/Desktop/README.txt" << 'README'
═══════════════════════════════════════════
        Welcome to ATLAZES OS 2.0
═══════════════════════════════════════════

You are running ATLAZES OS in Live mode.
All changes will be lost on reboot.

To install permanently:
  → Double-click "Install ATLAZES OS" on desktop
  → Or run: sudo calamares

Default credentials:
  User: atlazes
  Password: atlazes

Security features enabled:
  ✓ UFW Firewall (deny incoming)
  ✓ AppArmor (enforce mode)
  ✓ Firejail (Firefox sandboxed)
  ✓ MAC randomization
  ✓ Kernel hardening

For more info: https://github.com/atlazes
═══════════════════════════════════════════
README

chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/Desktop"

echo "[ATLAZES] User setup complete."
