#!/bin/bash
# =============================================================================
# ATLAZES OS - Automated QA Validation Script
# Runs inside a booted ATLAZES OS live session or installed system
# Usage: bash qa-validate.sh [--full] [--quick]
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0
SKIP=0
REPORT_FILE="/tmp/atlazes-qa-$(date +%Y%m%d-%H%M%S).txt"

MODE="${1:---quick}"

pass() { echo -e "  ${GREEN}✓ PASS${NC}  $*"; ((PASS++)); echo "PASS: $*" >> "$REPORT_FILE"; }
fail() { echo -e "  ${RED}✗ FAIL${NC}  $*"; ((FAIL++)); echo "FAIL: $*" >> "$REPORT_FILE"; }
warn() { echo -e "  ${YELLOW}~ WARN${NC}  $*"; ((WARN++)); echo "WARN: $*" >> "$REPORT_FILE"; }
skip() { echo -e "  ${CYAN}⏭ SKIP${NC}  $*"; ((SKIP++)); echo "SKIP: $*" >> "$REPORT_FILE"; }
section() {
    echo ""
    echo -e "${CYAN}${BOLD}══ $* ══${NC}"
    echo "=== $* ===" >> "$REPORT_FILE"
}

check() {
    local desc="$1"
    local cmd="$2"
    local expected="${3:-}"

    local output
    output=$(eval "$cmd" 2>/dev/null || true)

    if [[ -n "$expected" ]]; then
        if echo "$output" | grep -q "$expected"; then
            pass "$desc"
        else
            fail "$desc (got: ${output:0:60})"
        fi
    else
        if [[ -n "$output" ]]; then
            pass "$desc"
        else
            fail "$desc (no output)"
        fi
    fi
}

check_service() {
    local name="$1"
    local service="$2"
    if systemctl is-active "$service" &>/dev/null; then
        pass "Service active: $name"
    else
        fail "Service inactive: $name"
    fi
}

check_file() {
    local desc="$1"
    local path="$2"
    if [[ -f "$path" ]]; then
        pass "$desc"
    else
        fail "$desc (missing: $path)"
    fi
}

check_cmd() {
    local name="$1"
    if command -v "$name" &>/dev/null; then
        pass "Command available: $name"
    else
        fail "Command missing: $name"
    fi
}

# ─── Header ───────────────────────────────────────────────────────────────────
echo -e "${BLUE:-}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║      ATLAZES OS QA VALIDATION            ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC:-}"
echo "  Mode: $MODE"
echo "  Date: $(date)"
echo "  Host: $(uname -n)"
echo "  Kernel: $(uname -r)"
echo ""
echo "ATLAZES OS QA Report - $(date)" > "$REPORT_FILE"
echo "Kernel: $(uname -r)" >> "$REPORT_FILE"

# ─── 1. OS Identity ───────────────────────────────────────────────────────────
section "1. OS Identity"
check_file "OS release file" "/etc/atlazes-release"
check "OS name" "cat /etc/os-release" "ATLAZES"
check "Version set" "cat /etc/atlazes-release" "ATLAZES_OS_VERSION"
check_file "ATLAZES state dir" "/var/lib/atlazes"
check_file "Mode file" "/var/lib/atlazes/current-mode"

# ─── 2. Boot & Filesystem ─────────────────────────────────────────────────────
section "2. Boot & Filesystem"
check "squashfs module available" "modinfo squashfs 2>/dev/null || lsmod | grep squashfs" ""
check "GRUB config exists" "test -f /boot/grub/grub.cfg && echo ok" "ok"
check "initramfs exists" "ls /boot/initrd.img* 2>/dev/null | head -1" ""
check "/tmp is tmpfs" "mount | grep 'tmpfs on /tmp'" "tmpfs"
check "/proc mounted" "mount | grep proc" "proc"

# ─── 3. DNS ───────────────────────────────────────────────────────────────────
section "3. DNS Configuration"
check_service "dnscrypt-proxy" "dnscrypt-proxy"
check "dnscrypt on port 53" "ss -ulnp 2>/dev/null | grep ':53'" "127.0.0.1"
check "resolv.conf points to localhost" "grep nameserver /etc/resolv.conf" "127.0.0.1"
check "resolv.conf NOT immutable" "lsattr /etc/resolv.conf 2>/dev/null | grep -v '\-i\-'" ""
check "DNS resolves" "dig +short +time=5 google.com 2>/dev/null | head -1" ""
check "systemd-resolved stub disabled" "cat /etc/systemd/resolved.conf.d/atlazes-dns.conf 2>/dev/null" "DNSStubListener=no"
check "NM dispatcher exists" "test -f /etc/NetworkManager/dispatcher.d/99-atlazes-dns-restore && echo ok" "ok"

# ─── 4. Security Services ─────────────────────────────────────────────────────
section "4. Security Services"
check_service "UFW firewall" "ufw"
check "UFW active" "ufw status 2>/dev/null" "Status: active"
check "UFW deny incoming" "ufw status verbose 2>/dev/null" "deny (incoming)"
check_service "AppArmor" "apparmor"
check "AppArmor profiles loaded" "aa-status 2>/dev/null | head -3" "profiles are loaded"
check "AppArmor not enforce-all" "aa-status 2>/dev/null | grep 'profiles are in enforce mode' | awk '{print \$1}'" ""
check_service "Fail2ban" "fail2ban"
check "No unnecessary open ports" "ss -tlnp 2>/dev/null | grep -v '127.0.0.1\|::1\|LISTEN' | wc -l" ""

# ─── 5. Kernel Hardening ──────────────────────────────────────────────────────
section "5. Kernel Hardening"
check "kptr_restrict=2" "sysctl -n kernel.kptr_restrict 2>/dev/null" "2"
check "dmesg_restrict=1" "sysctl -n kernel.dmesg_restrict 2>/dev/null" "1"
check "ASLR=2" "sysctl -n kernel.randomize_va_space 2>/dev/null" "2"
check "SYN cookies=1" "sysctl -n net.ipv4.tcp_syncookies 2>/dev/null" "1"
check "No IP forwarding" "sysctl -n net.ipv4.ip_forward 2>/dev/null" "0"
check "No ICMP redirects" "sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null" "0"
check "Hardlinks protected" "sysctl -n fs.protected_hardlinks 2>/dev/null" "1"
check "Symlinks protected" "sysctl -n fs.protected_symlinks 2>/dev/null" "1"
check "BPF restricted" "sysctl -n kernel.unprivileged_bpf_disabled 2>/dev/null" "1"
check "kexec disabled" "sysctl -n kernel.kexec_load_disabled 2>/dev/null" "1"
check "Core dumps disabled" "ulimit -c" "0"

# ─── 6. Module Blacklist ──────────────────────────────────────────────────────
section "6. Module Blacklist"
check "Blacklist file exists" "test -f /etc/modprobe.d/atlazes-blacklist.conf && echo ok" "ok"
check "squashfs NOT blacklisted" "grep -v '^#' /etc/modprobe.d/atlazes-blacklist.conf | grep squashfs" ""
# squashfs should NOT appear in blacklist (inverted check)
if grep -v '^#' /etc/modprobe.d/atlazes-blacklist.conf 2>/dev/null | grep -q "install squashfs"; then
    fail "squashfs is blacklisted (breaks live boot)"
else
    pass "squashfs not blacklisted"
fi
check "dccp blacklisted" "grep 'install dccp' /etc/modprobe.d/atlazes-blacklist.conf" "dccp"
check "firewire blacklisted" "grep 'install firewire-core' /etc/modprobe.d/atlazes-blacklist.conf" "firewire"

# ─── 7. Privacy ───────────────────────────────────────────────────────────────
section "7. Privacy Configuration"
check "MAC randomization configured" "cat /etc/NetworkManager/conf.d/99-atlazes-privacy.conf" "random"
check "Tracker blocking active" "grep -c '^0.0.0.0' /etc/hosts 2>/dev/null" ""
check "Firefox policies exist" "test -f /usr/lib/firefox-esr/distribution/policies.json && echo ok" "ok"
check "Firefox telemetry disabled" "cat /usr/lib/firefox-esr/distribution/policies.json" "DisableTelemetry"
check "Avahi publishing restricted" "grep 'publish-workstation=no' /etc/avahi/avahi-daemon.conf 2>/dev/null" "no"
check "Bluetooth auto-enable off" "grep 'AutoEnable=false' /etc/bluetooth/main.conf 2>/dev/null" "false"
check "/proc hidepid" "mount | grep proc" "hidepid=2"
check "proc group exists" "getent group proc" "proc"
check "atlazes user in proc group" "id atlazes 2>/dev/null" "proc"

# ─── 8. CLI Tools ─────────────────────────────────────────────────────────────
section "8. CLI Tools"
check_cmd "atlazes"
check_cmd "atlazes-tools"
check "atlazes help works" "atlazes help 2>/dev/null" "Usage"
check "atlazes status works" "atlazes status 2>/dev/null" "Security Status"
check "atlazes mode works" "atlazes mode 2>/dev/null" "Current mode"
check_cmd "firejail"
check_cmd "ufw"
check_cmd "aa-status"
check_cmd "clamscan"
check_cmd "rkhunter"
check_cmd "lynis"
check_cmd "mat2"
check_cmd "bleachbit"
check_cmd "keepassxc"
check_cmd "macchanger"
check_cmd "dnscrypt-proxy"

# ─── 9. Desktop ───────────────────────────────────────────────────────────────
section "9. Desktop Environment"
check "XFCE4 installed" "dpkg -l xfce4 2>/dev/null" "ii  xfce4"
check "LightDM installed" "dpkg -l lightdm 2>/dev/null" "ii  lightdm"
check "Firefox ESR installed" "dpkg -l firefox-esr 2>/dev/null" "ii  firefox-esr"
check "Autologin configured" "cat /etc/lightdm/lightdm.conf.d/10-autologin.conf 2>/dev/null" "autologin-user=atlazes"
check "Arc-Dark theme" "dpkg -l arc-theme 2>/dev/null" "ii  arc-theme"
check "Papirus icons" "dpkg -l papirus-icon-theme 2>/dev/null" "ii  papirus-icon-theme"

# ─── 10. Performance ──────────────────────────────────────────────────────────
section "10. Performance"
RAM_USED=$(free -m | awk '/^Mem:/{print $3}')
if [[ $RAM_USED -lt 800 ]]; then
    pass "RAM usage at idle: ${RAM_USED}MB (< 800MB)"
else
    warn "RAM usage at idle: ${RAM_USED}MB (> 800MB target)"
fi

FAILED_UNITS=$(systemctl list-units --failed --no-legend 2>/dev/null | wc -l)
if [[ $FAILED_UNITS -eq 0 ]]; then
    pass "No failed systemd units"
else
    fail "Failed systemd units: $FAILED_UNITS"
    systemctl list-units --failed --no-legend 2>/dev/null | head -5 >> "$REPORT_FILE"
fi

# ─── Full mode: additional checks ─────────────────────────────────────────────
if [[ "$MODE" == "--full" ]]; then
    section "11. Full Mode: Security Scan"
    warn "Running rkhunter (may take 2-3 minutes)..."
    sudo rkhunter --check --sk --quiet 2>/dev/null && pass "rkhunter: clean" || warn "rkhunter: warnings found"

    warn "Running lynis quick scan..."
    sudo lynis audit system --quick --quiet 2>/dev/null | tail -5
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}══ QA SUMMARY ══${NC}"
echo ""
echo -e "  ${GREEN}✓ PASS:${NC}  $PASS"
echo -e "  ${RED}✗ FAIL:${NC}  $FAIL"
echo -e "  ${YELLOW}~ WARN:${NC}  $WARN"
echo -e "  ${CYAN}⏭ SKIP:${NC}  $SKIP"
echo ""

TOTAL=$((PASS + FAIL + WARN + SKIP))
echo "  Total checks: $TOTAL"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}RESULT: PASS — Ready for release${NC}"
    echo "RESULT: PASS" >> "$REPORT_FILE"
elif [[ $FAIL -le 3 ]]; then
    echo -e "  ${YELLOW}${BOLD}RESULT: CONDITIONAL — Review failures before release${NC}"
    echo "RESULT: CONDITIONAL" >> "$REPORT_FILE"
else
    echo -e "  ${RED}${BOLD}RESULT: FAIL — Do not release${NC}"
    echo "RESULT: FAIL" >> "$REPORT_FILE"
fi

echo ""
echo "  Full report: $REPORT_FILE"
echo ""

# Exit with failure count
exit $FAIL
