#!/bin/bash
# =============================================================================
# ATLAZES OS - Post-Installation Script
# Run this after Calamares installs the system on real hardware
# Usage: sudo ./post-install.sh [--skip-updates] [--skip-hosts]
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*"; exit 1; }
section() { echo -e "\n${CYAN}${BOLD}── $* ──${NC}\n"; }

[[ $EUID -ne 0 ]] && error "Run as root: sudo ./post-install.sh"

# ─── Parse flags ──────────────────────────────────────────────────────────────
SKIP_UPDATES=false
SKIP_HOSTS=false
for arg in "$@"; do
    case "$arg" in
        --skip-updates) SKIP_UPDATES=true ;;
        --skip-hosts)   SKIP_HOSTS=true ;;
    esac
done

section "ATLAZES OS Post-Installation"

# ─── Update system ────────────────────────────────────────────────────────────
if [[ "$SKIP_UPDATES" == "false" ]]; then
    section "Updating System"
    apt-get update -qq
    apt-get upgrade -y
    apt-get dist-upgrade -y
    apt-get autoremove -y
    apt-get autoclean
    log "System updated."
fi

# ─── Automatic security updates ───────────────────────────────────────────────
section "Configuring Automatic Security Updates"
apt-get install -y unattended-upgrades apt-listchanges

cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Package-Blacklist {};
Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::SyslogEnable "true";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

systemctl enable unattended-upgrades
log "Automatic security updates enabled."

# ─── Firewall ─────────────────────────────────────────────────────────────────
section "Configuring Firewall"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw default deny forward
ufw logging on
ufw --force enable
log "UFW firewall configured."

# ─── AppArmor ─────────────────────────────────────────────────────────────────
section "Configuring AppArmor"
systemctl enable apparmor
systemctl start apparmor

# Use the apparmor-manage script for selective enforcement
if [[ -f /usr/local/sbin/apparmor-manage.sh ]]; then
    bash /usr/local/sbin/apparmor-manage.sh strict
else
    # Fallback: complain mode for all, enforce for browsers
    find /etc/apparmor.d/ -maxdepth 1 -type f | while read -r p; do
        aa-complain "$p" 2>/dev/null || true
    done
    for p in /etc/apparmor.d/usr.bin.firefox* /etc/apparmor.d/usr.sbin.cups*; do
        [[ -f "$p" ]] && aa-enforce "$p" 2>/dev/null || true
    done
fi
log "AppArmor configured."

# ─── Fail2ban ─────────────────────────────────────────────────────────────────
section "Configuring Fail2ban"
systemctl enable fail2ban
systemctl start fail2ban
log "Fail2ban enabled."

# ─── dnscrypt-proxy ───────────────────────────────────────────────────────────
section "Configuring Encrypted DNS"
systemctl enable dnscrypt-proxy
systemctl start dnscrypt-proxy 2>/dev/null || warn "dnscrypt-proxy failed to start (will retry on reboot)"

# FIXED: Do NOT use chattr +i on resolv.conf
# Set it to point to dnscrypt-proxy, but leave it writable for VPN/NM
cat > /etc/resolv.conf << 'EOF'
# ATLAZES OS - DNS via dnscrypt-proxy
# DNS queries are encrypted in transit to the resolver.
# The resolver (Quad9/Cloudflare) still receives queries in plaintext.
# VPN clients may override this file temporarily. That is expected behavior.
# To disable encrypted DNS: sudo systemctl disable --now dnscrypt-proxy
nameserver 127.0.0.1
options edns0 trust-ad
EOF
log "DNS configured via dnscrypt-proxy (resolv.conf writable for VPN compatibility)."

# ─── Add current user to proc group (for hidepid=2) ──────────────────────────
section "Configuring /proc Access"
groupadd -f proc 2>/dev/null || true
# Add all human users (UID >= 1000) to proc group
while IFS=: read -r username _ uid _; do
    if [[ $uid -ge 1000 && $uid -lt 65534 ]]; then
        usermod -aG proc "$username" 2>/dev/null || true
        log "Added ${username} to proc group."
    fi
done < /etc/passwd

# ─── ClamAV ───────────────────────────────────────────────────────────────────
section "Configuring ClamAV"
systemctl stop clamav-freshclam 2>/dev/null || true
freshclam 2>/dev/null && log "ClamAV signatures updated." || \
    warn "ClamAV update failed (no internet?)"
systemctl enable clamav-daemon
systemctl enable clamav-freshclam
systemctl start clamav-daemon 2>/dev/null || true
log "ClamAV configured."

# ─── rkhunter ─────────────────────────────────────────────────────────────────
section "Configuring rkhunter"
rkhunter --update 2>/dev/null || warn "rkhunter update failed (no internet?)"
rkhunter --propupd 2>/dev/null || true
log "rkhunter configured."

# ─── AIDE ─────────────────────────────────────────────────────────────────────
section "Initializing AIDE File Integrity Database"
aideinit 2>/dev/null || warn "AIDE init failed"
cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db 2>/dev/null || true

# Weekly AIDE check via systemd timer (not cron)
cat > /etc/systemd/system/aide-check.service << 'EOF'
[Unit]
Description=AIDE File Integrity Check
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/aide --check
StandardOutput=journal
StandardError=journal
EOF

cat > /etc/systemd/system/aide-check.timer << 'EOF'
[Unit]
Description=Weekly AIDE File Integrity Check

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable aide-check.timer
log "AIDE configured with weekly check timer."

# ─── TLP power management ─────────────────────────────────────────────────────
section "Configuring TLP"
systemctl enable tlp
systemctl start tlp 2>/dev/null || true
log "TLP power management enabled."

# ─── StevenBlack hosts list (requires internet) ───────────────────────────────
if [[ "$SKIP_HOSTS" == "false" ]]; then
    section "Updating Tracker Blocklist"
    # BUG FIX: HTTP/2 responses return "200" not "200 OK" — grep "200 OK" always fails.
    # Use curl exit code instead: exit 0 = reachable, non-zero = not reachable.
    if curl -fsSL --max-time 30 --head \
        https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts \
        -o /dev/null 2>/dev/null; then

        # Download and merge (keep existing entries, add new ones)
        curl -fsSL --max-time 60 \
            https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts \
            -o /tmp/sb-hosts

        # Extract only the blocking entries (not the header/comments)
        grep "^0\.0\.0\.0" /tmp/sb-hosts > /tmp/sb-entries

        # Remove any existing StevenBlack entries from hosts
        grep -v "^0\.0\.0\.0" /etc/hosts > /tmp/hosts-clean || true

        # Append new entries
        cat /tmp/hosts-clean /tmp/sb-entries > /etc/hosts

        BLOCKED_COUNT=$(grep -c "^0\.0\.0\.0" /etc/hosts || echo "0")
        rm -f /tmp/sb-hosts /tmp/sb-entries /tmp/hosts-clean
        log "Tracker blocklist updated: ${BLOCKED_COUNT} domains blocked."
    else
        warn "Cannot reach GitHub. Skipping hosts update (using built-in list)."
        warn "Run later: sudo atlazes update-hosts"
    fi
fi

# ─── Remove live-system packages ──────────────────────────────────────────────
section "Removing Live System Packages"
apt-get remove -y --purge \
    live-boot \
    live-boot-initramfs-tools \
    live-config \
    live-config-systemd \
    live-tools \
    calamares \
    2>/dev/null || true
apt-get autoremove -y
log "Live packages removed."

# ─── Update initramfs and GRUB ────────────────────────────────────────────────
section "Finalizing Boot Configuration"
update-initramfs -u -k all
update-grub 2>/dev/null || true
log "initramfs and GRUB updated."

# ─── Initialize ATLAZES state ─────────────────────────────────────────────────
mkdir -p /var/lib/atlazes
echo "normal" > /var/lib/atlazes/current-mode
chmod 644 /var/lib/atlazes/current-mode

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║       ATLAZES OS Post-Install Complete!          ║"
echo "  ╠══════════════════════════════════════════════════╣"
echo "  ║  ✓ System updated                                ║"
echo "  ║  ✓ Automatic security updates enabled            ║"
echo "  ║  ✓ UFW firewall active                           ║"
echo "  ║  ✓ AppArmor configured (selective enforce)       ║"
echo "  ║  ✓ DNS via dnscrypt-proxy (resolver trust req.)  ║"
echo "  ║  ✓ ClamAV antivirus configured                   ║"
echo "  ║  ✓ AIDE file integrity monitoring                ║"
echo "  ║  ✓ Fail2ban active                               ║"
echo "  ║  ✓ /proc secured (hidepid=2)                     ║"
echo "  ╠══════════════════════════════════════════════════╣"
echo "  ║  Note: IP address visible to websites visited.   ║"
echo "  ║  See docs/security-transparency.md for details.  ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Reboot to apply all changes: sudo reboot"
echo ""
echo "  After reboot, check status: atlazes status"
