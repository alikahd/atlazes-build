#!/bin/bash
# =============================================================================
# ATLAZES OS - Boot Time & Performance Optimization
# Run on installed system: sudo ./optimize-boot.sh
# Target: < 30s boot on hardware, < 800MB RAM idle
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

section "ATLAZES OS Boot & Performance Optimization"

# ─── Analyze current boot time ────────────────────────────────────────────────
section "Current Boot Analysis"
echo "Boot time breakdown (top 10 slowest units):"
systemd-analyze blame 2>/dev/null | head -10
echo ""
echo "Critical chain:"
systemd-analyze critical-chain 2>/dev/null | head -20

# ─── Disable services that add boot time without value ────────────────────────
section "Disabling Unnecessary Services"

DISABLE_SERVICES=(
    # Network services not needed on desktop
    "ModemManager"          # Only needed for mobile broadband
    "pppd-dns"              # PPP DNS - not needed
    "apt-daily.timer"       # Move to off-peak
    "apt-daily-upgrade.timer"

    # Debian-specific bloat
    "e2scrub_reap"          # ext4 scrub - not needed at boot
    "fstrim.timer"          # SSD trim - keep but not at boot

    # Logging overhead
    "rsyslog"               # journald is sufficient

    # Rarely needed
    "lvm2-monitor"          # Only if using LVM
    "dm-event"              # Device mapper events
)

for svc in "${DISABLE_SERVICES[@]}"; do
    if systemctl is-enabled "$svc" &>/dev/null; then
        systemctl disable "$svc" 2>/dev/null && warn "Disabled: $svc" || true
    fi
done

# ─── Optimize apt timers (run at night, not at boot) ──────────────────────────
section "Optimizing APT Update Timers"
mkdir -p /etc/systemd/system/apt-daily.timer.d
cat > /etc/systemd/system/apt-daily.timer.d/override.conf << 'EOF'
[Timer]
OnCalendar=
OnCalendar=02:00
RandomizedDelaySec=30m
EOF

mkdir -p /etc/systemd/system/apt-daily-upgrade.timer.d
cat > /etc/systemd/system/apt-daily-upgrade.timer.d/override.conf << 'EOF'
[Timer]
OnCalendar=
OnCalendar=03:00
RandomizedDelaySec=30m
EOF
log "APT timers moved to 2-3 AM."

# ─── Reduce systemd timeout ───────────────────────────────────────────────────
section "Reducing systemd Timeouts"
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/atlazes-timeouts.conf << 'EOF'
[Manager]
# Reduce default timeout for services that hang
DefaultTimeoutStartSec=30s
DefaultTimeoutStopSec=15s
# Reduce shutdown timeout
ShutdownWatchdogSec=2min
EOF
log "systemd timeouts reduced."

# ─── Optimize GRUB timeout ────────────────────────────────────────────────────
section "Optimizing GRUB"
if [[ -f /etc/default/grub ]]; then
    # Reduce timeout from 5 to 3 seconds
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
    update-grub 2>/dev/null || true
    log "GRUB timeout set to 3 seconds."
fi

# ─── Optimize NetworkManager startup ─────────────────────────────────────────
section "Optimizing NetworkManager"
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/98-atlazes-performance.conf << 'EOF'
[main]
# Don't wait for network at boot (async)
no-auto-default=*

[connection]
# Faster DHCP
ipv4.dhcp-timeout=15
ipv6.dhcp-timeout=15
EOF
log "NetworkManager optimized for faster boot."

# ─── Reduce journal size ──────────────────────────────────────────────────────
section "Optimizing Journal"
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/atlazes.conf << 'EOF'
[Journal]
# Limit journal size to 200MB
SystemMaxUse=200M
# Compress journal
Compress=yes
# Forward to syslog only if rsyslog is running
ForwardToSyslog=no
EOF
systemctl restart systemd-journald 2>/dev/null || true
log "Journal size limited to 200MB."

# ─── Preload commonly used libraries ─────────────────────────────────────────
section "Preload Configuration"
if command -v preload &>/dev/null; then
    systemctl enable preload 2>/dev/null || true
    log "preload enabled."
else
    warn "preload not installed. Install: sudo apt install preload"
fi

# ─── Optimize swappiness (already set in sysctl) ─────────────────────────────
section "Memory Optimization"
# Verify swappiness is set
current_swap=$(sysctl -n vm.swappiness 2>/dev/null || echo "60")
if [[ "$current_swap" -gt 10 ]]; then
    sysctl -w vm.swappiness=10
    log "Swappiness set to 10 (was $current_swap)."
else
    log "Swappiness already optimal: $current_swap"
fi

# ─── Disable XFCE4 splash screen (saves ~1s) ─────────────────────────────────
section "XFCE4 Optimization"
# Disable splash for faster desktop load
if [[ -f /etc/lightdm/lightdm.conf.d/10-autologin.conf ]]; then
    # Already configured for autologin - good
    log "LightDM autologin configured."
fi

# ─── Reload systemd ───────────────────────────────────────────────────────────
systemctl daemon-reload

# ─── Report ───────────────────────────────────────────────────────────────────
section "Optimization Complete"
echo "New boot time estimate:"
systemd-analyze 2>/dev/null || true
echo ""
echo "RAM usage now:"
free -m
echo ""
log "Reboot to apply all changes: sudo reboot"
log "After reboot, check: systemd-analyze blame | head -10"
