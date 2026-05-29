#!/bin/bash
# =============================================================================
# ATLAZUS OS - First Boot Fixes
# يُشغَّل داخل chroot — يُصلح مشاكل تظهر عند الإقلاع الأول
# =============================================================================

set -e

log() { echo "[ATLAZUS] $*"; }

log "Applying first-boot fixes..."

# =============================================================================
# إصلاح APT signature (مشكلة sqv "Not live until")
# =============================================================================
log "Fixing APT GPG configuration..."

# إعداد APT لاستخدام gpg الكلاسيكي بدلاً من sqv
mkdir -p /etc/apt/apt.conf.d
cat > /etc/apt/apt.conf.d/99-atlazus-apt << 'APTCONF'
// ATLAZUS OS - APT configuration
// Fixes sqv signature verification issues
APT::Key::Assert-Pubkey-Algo ">=rsa1024";
Acquire::Languages "none";
APTCONF

# تأكد من وجود debian-archive-keyring
if ! dpkg -l debian-archive-keyring 2>/dev/null | grep -q "^ii"; then
    apt-get install -y --no-install-recommends debian-archive-keyring 2>/dev/null || true
fi

# تحديث sources.list بمصادر صحيحة ونظيفة
cat > /etc/apt/sources.list << 'SOURCES'
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
SOURCES

# حذف أي sources.list.d قديمة
rm -f /etc/apt/sources.list.d/*.list 2>/dev/null || true
rm -f /etc/apt/sources.list.d/*.sources 2>/dev/null || true

log "APT configuration fixed."

# =============================================================================
# إصلاح الوقت (مشكلة "Not live until" تحدث أحياناً بسبب خطأ في الساعة)
# =============================================================================
log "Ensuring time sync service is enabled..."

if command -v systemctl &>/dev/null; then
    systemctl enable systemd-timesyncd.service 2>/dev/null || true
fi

# إعداد NTP servers
mkdir -p /etc/systemd
cat > /etc/systemd/timesyncd.conf << 'NTP'
[Time]
NTP=0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org
FallbackNTP=time.cloudflare.com time.google.com
NTP

log "Time sync configured."

# =============================================================================
# إصلاح net-tools (ifconfig)
# =============================================================================
log "Ensuring net-tools is installed..."

if ! command -v ifconfig &>/dev/null; then
    apt-get install -y --no-install-recommends net-tools 2>/dev/null || true
fi

log "net-tools check done."

# =============================================================================
# إصلاح خلفية root
# =============================================================================
log "Fixing root desktop wallpaper..."

ROOT_XFCE="/root/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$ROOT_XFCE"

cat > "${ROOT_XFCE}/xfce4-desktop.xml" << 'XFCEDESK'
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
    </property>
  </property>
</channel>
XFCEDESK

log "Root wallpaper fixed."

# =============================================================================
# حذف "Install Debian" من سطح المكتب
# =============================================================================
log "Removing Debian installer shortcuts..."

for d in /home/*/Desktop /root/Desktop /etc/skel/Desktop; do
    [[ -d "$d" ]] || continue
    find "$d" -maxdepth 1 -name "*.desktop" | while read -r f; do
        if grep -qi "debian" "$f" 2>/dev/null && ! grep -qi "atlazus" "$f" 2>/dev/null; then
            rm -f "$f"
            log "  Removed: $f"
        fi
    done
done

# حذف من applications
rm -f /usr/share/applications/debian-*.desktop 2>/dev/null || true
rm -f /usr/share/applications/install-debian.desktop 2>/dev/null || true

log "Debian shortcuts removed."

# =============================================================================
# إنشاء systemd service لتشغيل firstboot-fixes عند الإقلاع
# =============================================================================
log "Installing firstboot systemd service..."

cat > /etc/systemd/system/atlazus-firstboot-fixes.service << 'SVC'
[Unit]
Description=ATLAZUS OS First Boot Fixes
After=network.target
ConditionPathExists=!/var/lib/atlazus/.firstboot-done

[Service]
Type=oneshot
ExecStart=/usr/local/bin/atlazus-firstboot-run
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVC

cat > /usr/local/bin/atlazus-firstboot-run << 'SCRIPT'
#!/bin/bash
/bin/bash /usr/local/bin/atlazus-firstboot-fixes 2>/var/log/atlazus-firstboot.log
mkdir -p /var/lib/atlazus
touch /var/lib/atlazus/.firstboot-done
SCRIPT
chmod +x /usr/local/bin/atlazus-firstboot-run

# نسخ هذا السكريبت نفسه
cp "$0" /usr/local/bin/atlazus-firstboot-fixes 2>/dev/null || true
chmod +x /usr/local/bin/atlazus-firstboot-fixes 2>/dev/null || true

systemctl enable atlazus-firstboot-fixes.service 2>/dev/null || true

log "First-boot fixes complete."
