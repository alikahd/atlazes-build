#!/bin/bash
# =============================================================================
# ATLAZES OS - Standalone Kernel Hardening Script
# Can be run on any installed Debian/Ubuntu system
# Usage: sudo ./kernel-hardening.sh
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

section "ATLAZES OS Kernel Hardening"

# ─── sysctl hardening ─────────────────────────────────────────────────────────
cat > /etc/sysctl.d/99-atlazes-hardening.conf << 'SYSCTL'
# ════════════════════════════════════════════════════════════════════════════
# ATLAZES OS - Production-Safe Kernel Hardening
# All rules documented and verified safe for desktop/laptop use
# ════════════════════════════════════════════════════════════════════════════

# ── Kernel information leaks ──────────────────────────────────────────────────
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.perf_event_paranoid = 3

# ── Process tracing ───────────────────────────────────────────────────────────
# 1 = only parent can ptrace (safe for debuggers, blocks cross-process ptrace)
kernel.yama.ptrace_scope = 1

# ── SysRq ─────────────────────────────────────────────────────────────────────
kernel.sysrq = 0

# ── User namespaces ───────────────────────────────────────────────────────────
# 1 = allow (required for Chrome sandbox, Docker rootless, Flatpak)
kernel.unprivileged_userns_clone = 1

# ── Core dumps ────────────────────────────────────────────────────────────────
fs.suid_dumpable = 0

# ── ASLR ──────────────────────────────────────────────────────────────────────
kernel.randomize_va_space = 2

# ── BPF ───────────────────────────────────────────────────────────────────────
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2

# ── kexec ─────────────────────────────────────────────────────────────────────
kernel.kexec_load_disabled = 1

# ── Filesystem protections ────────────────────────────────────────────────────
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2

# ── Network: IP forwarding ────────────────────────────────────────────────────
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# ── Network: SYN flood protection ────────────────────────────────────────────
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_max_syn_backlog = 4096

# ── Network: ICMP redirects ───────────────────────────────────────────────────
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# ── Network: Source routing ───────────────────────────────────────────────────
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# ── Network: Reverse path filtering ──────────────────────────────────────────
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# ── Network: ICMP ─────────────────────────────────────────────────────────────
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# ── Network: TCP ──────────────────────────────────────────────────────────────
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_timestamps = 0

# ── Network: IPv6 ─────────────────────────────────────────────────────────────
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

# ── Memory ────────────────────────────────────────────────────────────────────
vm.mmap_min_addr = 65536
vm.swappiness = 10
SYSCTL

sysctl --system 2>/dev/null || true
log "sysctl rules applied."

# ─── GRUB kernel parameters ───────────────────────────────────────────────────
# FIXED: Removed params that break usability:
#   nosmt=force     → kills all but one CPU core (huge performance loss)
#   lockdown=confidentiality → breaks suspend/hibernate/some drivers
#   oops=panic      → one kernel oops = full system crash
#   loglevel=0      → hides all kernel messages
#   mce=0           → disables machine check exceptions (dangerous)
#   module.sig_enforce=1 → breaks NVIDIA, VirtualBox, custom drivers
GRUB_FILE="/etc/default/grub"
HARDENED_PARAMS="apparmor=1 security=apparmor lsm=lockdown,yama,apparmor init_on_alloc=1 init_on_free=1 page_alloc.shuffle=1 pti=on vsyscall=none debugfs=off spectre_v2=on spec_store_bypass_disable=on tsx=off tsx_async_abort=full mds=full randomize_kstack_offset=on"

if [[ -f "$GRUB_FILE" ]]; then
    cp "$GRUB_FILE" "${GRUB_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash ${HARDENED_PARAMS}\"|" \
        "$GRUB_FILE"
    update-grub 2>/dev/null || true
    log "GRUB kernel parameters updated."
fi

# ─── Kernel module blacklist ──────────────────────────────────────────────────
cat > /etc/modprobe.d/atlazes-blacklist.conf << 'EOF'
# ATLAZES OS - Kernel Module Blacklist
# Disables unused/dangerous protocols and filesystems

# Uncommon network protocols
install dccp    /bin/false
install sctp    /bin/false
install rds     /bin/false
install tipc    /bin/false
install n-hdlc  /bin/false
install ax25    /bin/false
install netrom  /bin/false
install x25     /bin/false
install rose    /bin/false
install decnet  /bin/false
install econet  /bin/false
install af_802154 /bin/false
install ipx     /bin/false
install appletalk /bin/false
install can     /bin/false
install atm     /bin/false

# Uncommon filesystems (squashfs, udf, hfsplus kept for usability)
install cramfs  /bin/false
install freevxfs /bin/false
install jffs2   /bin/false
install hfs     /bin/false

# Firewire (DMA attack vector)
install firewire-core /bin/false
install firewire-ohci /bin/false
install firewire-sbp2 /bin/false
EOF

log "Kernel module blacklist applied."
log "Kernel hardening complete. Reboot to apply GRUB changes."
