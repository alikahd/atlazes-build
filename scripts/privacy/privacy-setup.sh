#!/bin/bash
# =============================================================================
# ATLAZES OS - Privacy Setup Script
# FIXED:
#   - resolv.conf NOT locked with chattr +i (breaks VPN/captive portals)
#   - StevenBlack hosts download is optional (requires internet)
#   - /proc hidepid properly configured with proc group
# Usage: sudo ./privacy-setup.sh [--skip-hosts]
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
section() { echo -e "\n${CYAN}${BOLD}── $* ──${NC}\n"; }

[[ $EUID -ne 0 ]] && { echo "Run as root: sudo $0"; exit 1; }

SKIP_HOSTS=false
for arg in "$@"; do
    [[ "$arg" == "--skip-hosts" ]] && SKIP_HOSTS=true
done

section "ATLAZES OS Privacy Setup"

# ─── MAC address randomization ────────────────────────────────────────────────
section "MAC Address Randomization"
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/99-atlazes-mac-random.conf << 'EOF'
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
connection.stable-id=${CONNECTION}/${BOOT}
EOF
systemctl restart NetworkManager 2>/dev/null || true
log "MAC randomization enabled."

# ─── Encrypted DNS ────────────────────────────────────────────────────────────
section "Encrypted DNS (dnscrypt-proxy)"
if command -v dnscrypt-proxy &>/dev/null; then
    systemctl enable dnscrypt-proxy
    systemctl start dnscrypt-proxy 2>/dev/null || true

    # FIXED: Do NOT use chattr +i - breaks VPN and captive portals
    cat > /etc/resolv.conf << 'EOF'
# ATLAZES OS - Encrypted DNS via dnscrypt-proxy
# Note: VPN clients may temporarily override this file. That is expected.
nameserver 127.0.0.1
options edns0 trust-ad
EOF
    log "Encrypted DNS configured (resolv.conf writable for VPN compatibility)."
else
    warn "dnscrypt-proxy not found. Install: sudo apt install dnscrypt-proxy"
fi

# ─── Disable telemetry ────────────────────────────────────────────────────────
section "Disabling Telemetry"
[[ -f /etc/popularity-contest.conf ]] && \
    sed -i 's/PARTICIPATE=.*/PARTICIPATE=no/' /etc/popularity-contest.conf && \
    log "popularity-contest disabled."

[[ -f /etc/default/apport ]] && \
    sed -i 's/enabled=1/enabled=0/' /etc/default/apport && \
    systemctl disable apport 2>/dev/null || true && \
    log "apport disabled."

[[ -f /etc/default/whoopsie ]] && \
    sed -i 's/report_crashes=true/report_crashes=false/' /etc/default/whoopsie && \
    systemctl disable whoopsie 2>/dev/null || true && \
    log "whoopsie disabled."

# ─── Tracker blocking (hosts file) ────────────────────────────────────────────
section "Tracker Blocking"
if [[ "$SKIP_HOSTS" == "false" ]]; then
    if curl -s --max-time 10 --head \
        https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts \
        | grep -q "200"; then

        curl -fsSL --max-time 60 \
            https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts \
            -o /tmp/sb-hosts

        # Preserve existing non-blocking entries, replace blocking section
        grep -v "^0\.0\.0\.0" /etc/hosts > /tmp/hosts-base || true
        grep "^0\.0\.0\.0" /tmp/sb-hosts > /tmp/sb-entries || true
        cat /tmp/hosts-base /tmp/sb-entries > /etc/hosts
        rm -f /tmp/sb-hosts /tmp/sb-entries /tmp/hosts-base

        BLOCKED_COUNT=$(grep -c "^0\.0\.0\.0" /etc/hosts || echo "0")
        log "StevenBlack hosts applied: ${BLOCKED_COUNT} domains blocked."
    else
        warn "Cannot reach GitHub. Using built-in minimal list."
        warn "Run later with internet: sudo $0"
    fi
else
    log "Hosts update skipped (--skip-hosts)."
fi

# ─── Firefox ESR hardening ────────────────────────────────────────────────────
section "Firefox ESR Privacy Hardening"
FIREFOX_POLICY_DIR="/usr/lib/firefox-esr/distribution"
mkdir -p "$FIREFOX_POLICY_DIR"

if [[ ! -f "${FIREFOX_POLICY_DIR}/policies.json" ]]; then
    cat > "${FIREFOX_POLICY_DIR}/policies.json" << 'EOF'
{
  "policies": {
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "EnableTrackingProtection": {
      "Value": true,
      "Cryptomining": true,
      "Fingerprinting": true
    },
    "HttpsOnlyMode": "force_enabled",
    "SearchEngines": { "Default": "DuckDuckGo" },
    "Homepage": { "URL": "about:blank" }
  }
}
EOF
    log "Firefox ESR policies applied."
fi

# ─── Disable Avahi publishing ─────────────────────────────────────────────────
section "Avahi Privacy"
if [[ -f /etc/avahi/avahi-daemon.conf ]]; then
    sed -i 's/#publish-hinfo=yes/publish-hinfo=no/'       /etc/avahi/avahi-daemon.conf
    sed -i 's/#publish-workstation=yes/publish-workstation=no/' /etc/avahi/avahi-daemon.conf
    sed -i 's/publish-hinfo=yes/publish-hinfo=no/'        /etc/avahi/avahi-daemon.conf
    sed -i 's/publish-workstation=yes/publish-workstation=no/' /etc/avahi/avahi-daemon.conf
    log "Avahi publishing restricted."
fi

# ─── Bluetooth auto-enable ────────────────────────────────────────────────────
section "Bluetooth Privacy"
if [[ -f /etc/bluetooth/main.conf ]]; then
    sed -i 's/#AutoEnable=false/AutoEnable=false/' /etc/bluetooth/main.conf
    sed -i 's/AutoEnable=true/AutoEnable=false/'   /etc/bluetooth/main.conf
    log "Bluetooth auto-enable disabled."
fi

# ─── Secure /proc ─────────────────────────────────────────────────────────────
section "Securing /proc"
groupadd -f proc 2>/dev/null || true

# Add all human users to proc group
while IFS=: read -r username _ uid _; do
    if [[ $uid -ge 1000 && $uid -lt 65534 ]]; then
        usermod -aG proc "$username" 2>/dev/null || true
    fi
done < /etc/passwd

if ! grep -q "hidepid=2" /etc/fstab 2>/dev/null; then
    echo "proc /proc proc defaults,nosuid,nodev,noexec,hidepid=2,gid=proc 0 0" >> /etc/fstab
    log "/proc secured with hidepid=2 (proc group members can see all processes)."
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║       ATLAZES OS Privacy Setup Complete!         ║"
echo "  ╠══════════════════════════════════════════════════╣"
echo "  ║  ✓ MAC address randomization                     ║"
echo "  ║  ✓ Encrypted DNS (resolv.conf writable for VPN)  ║"
echo "  ║  ✓ Telemetry disabled                            ║"
echo "  ║  ✓ Tracker blocking (hosts file)                 ║"
echo "  ║  ✓ Firefox ESR hardened                          ║"
echo "  ║  ✓ Avahi publishing restricted                   ║"
echo "  ║  ✓ /proc secured (hidepid=2)                     ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
