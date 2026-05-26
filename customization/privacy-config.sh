#!/bin/bash
# =============================================================================
# ATLAZES OS - Privacy Configuration
# Firefox ESR policies + DNS privacy + MAC randomization
# يُشغَّل داخل chroot
# =============================================================================

set -e

echo "[ATLAZES] Applying privacy configuration..."

# ── Firefox ESR Privacy Policies ──────────────────────────────────────────────
echo "[ATLAZES] Configuring Firefox ESR policies..."

# Firefox policies (enterprise deployment)
mkdir -p /usr/lib/firefox-esr/distribution

cat > /usr/lib/firefox-esr/distribution/policies.json << 'FIREFOX'
{
  "policies": {
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "DisableFirefoxAccounts": false,
    "DisableFormHistory": true,
    "DontCheckDefaultBrowser": true,
    "OfferToSaveLogins": false,
    "PasswordManagerEnabled": false,
    "SearchSuggestEnabled": false,
    "EnableTrackingProtection": {
      "Value": true,
      "Locked": false,
      "Cryptomining": true,
      "Fingerprinting": true
    },
    "Cookies": {
      "Behavior": "reject-tracker-and-partition-foreign",
      "BehaviorPrivateBrowsing": "reject-tracker-and-partition-foreign",
      "Locked": false
    },
    "HttpsOnlyMode": "enabled",
    "DNSOverHTTPS": {
      "Enabled": true,
      "Locked": false
    },
    "SanitizeOnShutdown": {
      "Cache": true,
      "Cookies": false,
      "Downloads": false,
      "FormData": true,
      "History": false,
      "Sessions": false,
      "SiteSettings": false,
      "OfflineApps": true,
      "Locked": false
    },
    "FirefoxHome": {
      "Search": true,
      "TopSites": false,
      "SponsoredTopSites": false,
      "Highlights": false,
      "Pocket": false,
      "SponsoredPocket": false,
      "Snippets": false,
      "Locked": false
    },
    "UserMessaging": {
      "WhatsNew": false,
      "ExtensionRecommendations": false,
      "FeatureRecommendations": false,
      "UrlbarInterventions": false,
      "SkipOnboarding": true,
      "MoreFromMozilla": false
    },
    "Homepage": {
      "URL": "about:blank",
      "Locked": false,
      "StartPage": "previous-session"
    },
    "ExtensionSettings": {
      "uBlock0@raymondhill.net": {
        "installation_mode": "normal_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
      }
    }
  }
}
FIREFOX

echo "[ATLAZES] Firefox policies applied."

# ── DNS Privacy ───────────────────────────────────────────────────────────────
echo "[ATLAZES] Configuring DNS privacy..."

# إعداد resolv.conf للخصوصية (يمكن للمستخدم تغييره)
cat > /etc/resolv.conf.atlazes << 'DNS'
# ATLAZES OS - Privacy-focused DNS
# Quad9 (malware blocking + privacy)
nameserver 9.9.9.9
nameserver 149.112.112.112
# Cloudflare (backup)
nameserver 1.1.1.1
DNS

# سكريبت لتطبيق DNS عند الإقلاع (اختياري)
cat > /usr/local/bin/atlazes-dns << 'DNSSCRIPT'
#!/bin/bash
# ATLAZES OS - Apply privacy DNS
# Usage: sudo atlazes-dns [apply|reset]

case "${1:-apply}" in
    apply)
        cp /etc/resolv.conf.atlazes /etc/resolv.conf
        echo "Privacy DNS applied (Quad9 + Cloudflare)"
        ;;
    reset)
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo "DNS reset to default"
        ;;
    *)
        echo "Usage: sudo atlazes-dns [apply|reset]"
        ;;
esac
DNSSCRIPT
chmod +x /usr/local/bin/atlazes-dns

echo "[ATLAZES] DNS privacy configured."

# ── MAC Address Randomization ─────────────────────────────────────────────────
echo "[ATLAZES] Configuring MAC randomization..."

# NetworkManager MAC randomization
mkdir -p /etc/NetworkManager/conf.d

cat > /etc/NetworkManager/conf.d/99-atlazes-mac-random.conf << 'MAC'
# ATLAZES OS - MAC Address Randomization
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random

[connectivity]
uri=
MAC

echo "[ATLAZES] MAC randomization configured."

# ── Proxychains Configuration ─────────────────────────────────────────────────
echo "[ATLAZES] Configuring proxychains..."

if [[ -f /etc/proxychains4.conf ]]; then
    # تعديل proxychains لاستخدام Tor
    sed -i 's/^socks4.*/socks5 127.0.0.1 9050/' /etc/proxychains4.conf 2>/dev/null || true
    sed -i 's/^#dynamic_chain/dynamic_chain/' /etc/proxychains4.conf 2>/dev/null || true
    sed -i 's/^strict_chain/#strict_chain/' /etc/proxychains4.conf 2>/dev/null || true
fi

echo "[ATLAZES] Proxychains configured."

# ── Tor Configuration ─────────────────────────────────────────────────────────
echo "[ATLAZES] Configuring Tor..."

if [[ -d /etc/tor ]]; then
    # لا نُفعّل Tor تلقائياً — المستخدم يختار
    if command -v systemctl &>/dev/null; then
        systemctl disable tor.service 2>/dev/null || true
    fi
fi

echo "[ATLAZES] Tor configured (disabled by default, user activates)."

# ── Privacy Sysctl ────────────────────────────────────────────────────────────
echo "[ATLAZES] Applying privacy sysctl..."

cat > /etc/sysctl.d/99-atlazes-privacy.conf << 'PRIVACY'
# ATLAZES OS - Privacy sysctl

# Hide kernel pointers from unprivileged users
kernel.kptr_restrict = 2

# Restrict access to dmesg
kernel.dmesg_restrict = 1

# Disable core dumps for SUID programs
fs.suid_dumpable = 0
PRIVACY

echo "[ATLAZES] Privacy configuration complete."
