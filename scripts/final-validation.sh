#!/bin/bash
# =============================================================================
# ATLAZES OS - Final Pre-Release Validation
# Run inside a booted live session or installed system
# Usage: bash final-validation.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0; FAIL=0; WARN=0
BLOCKING=()
MINOR=()

ok()      { echo -e "  ${GREEN}✓${NC} $*"; ((PASS+=1)); }
fail()    { echo -e "  ${RED}✗${NC} $*"; ((FAIL+=1)); BLOCKING+=("$*"); }
warn()    { echo -e "  ${YELLOW}~${NC} $*"; ((WARN+=1)); MINOR+=("$*"); }
section() { echo -e "\n${CYAN}${BOLD}── $* ──${NC}"; }

echo -e "${CYAN}${BOLD}"
echo "  ATLAZES OS - Final Validation"
echo "  $(date)"
echo -e "${NC}"

# ─── 1. Boot & System ─────────────────────────────────────────────────────────
section "1. Boot & System"

[[ -f /etc/atlazes-release ]] && ok "atlazes-release file present" || fail "atlazes-release missing"
[[ -f /var/lib/atlazes/current-mode ]] && ok "Mode state present" || fail "Mode state missing"
[[ -x /usr/local/bin/atlazes ]] && ok "atlazes CLI executable" || fail "atlazes CLI not executable"

# Check /tmp is not noexec (breaks Firejail)
if mount | grep "on /tmp " | grep -q "noexec"; then
    fail "/tmp is noexec — breaks Firejail and some installers"
else
    ok "/tmp is exec-allowed (required for Firejail)"
fi

# Check /dev/shm is not noexec (breaks Firefox/Chromium sandbox)
if mount | grep "on /dev/shm " | grep -q "noexec"; then
    fail "/dev/shm is noexec — breaks Firefox and Chromium sandbox"
else
    ok "/dev/shm is exec-allowed (required for browser sandbox)"
fi

# Check squashfs is not blacklisted
if grep -v '^#' /etc/modprobe.d/atlazes-blacklist.conf 2>/dev/null | grep -q "install squashfs"; then
    fail "squashfs is blacklisted — breaks live boot"
else
    ok "squashfs not blacklisted"
fi

# ─── 2. DNS ───────────────────────────────────────────────────────────────────
section "2. DNS"

if command -v dnscrypt-proxy &>/dev/null; then
    systemctl is-active dnscrypt-proxy &>/dev/null && ok "dnscrypt-proxy running" || warn "dnscrypt-proxy installed but not running"
    ss -ulnp 2>/dev/null | grep -q "127.0.0.1:53" && ok "dnscrypt-proxy listening on 127.0.0.1:53" || warn "dnscrypt-proxy not listening on 127.0.0.1:53"
else
    warn "dnscrypt-proxy not installed in lightweight profile"
    [[ -f /etc/resolv.conf.atlazes ]] && ok "ATLAZES privacy DNS preset present" || warn "ATLAZES privacy DNS preset missing"
fi

# resolv.conf must NOT be immutable
if lsattr /etc/resolv.conf 2>/dev/null | grep -q "\-i\-"; then
    fail "resolv.conf is immutable (chattr +i) — breaks VPN and captive portals"
else
    ok "resolv.conf is writable (VPN compatible)"
fi

# DNS resolution test
if dig +short +time=5 debian.org 2>/dev/null | grep -qE "^[0-9]"; then
    ok "DNS resolves correctly"
else
    warn "DNS resolution failed (no internet?)"
fi

# ─── 3. Security Services ─────────────────────────────────────────────────────
section "3. Security Services"

systemctl is-active ufw &>/dev/null && ok "UFW active" || fail "UFW inactive"
ufw status 2>/dev/null | grep -q "deny (incoming)" && ok "UFW denies incoming" || warn "UFW incoming policy not deny"
systemctl is-active apparmor &>/dev/null && ok "AppArmor active" || fail "AppArmor inactive"
if systemctl list-unit-files fail2ban.service &>/dev/null; then
    systemctl is-active fail2ban &>/dev/null && ok "Fail2ban active" || warn "Fail2ban installed but inactive"
else
    warn "Fail2ban not installed in lightweight profile"
fi

# AppArmor must not enforce-all (breaks apps)
ENFORCED_COUNT=$(aa-status 2>/dev/null | grep "profiles are in enforce mode" | awk '{print $1}' || echo "0")
if [[ "$ENFORCED_COUNT" -gt 50 ]]; then
    fail "AppArmor enforcing $ENFORCED_COUNT profiles — likely enforce-all (breaks apps)"
elif [[ "$ENFORCED_COUNT" -gt 0 ]]; then
    ok "AppArmor enforcing $ENFORCED_COUNT stable profiles"
else
    warn "AppArmor enforcing 0 profiles"
fi

# ─── 4. Kernel Hardening ──────────────────────────────────────────────────────
section "4. Kernel Hardening"

[[ "$(sysctl -n kernel.kptr_restrict 2>/dev/null)" == "2" ]] && ok "kptr_restrict=2" || warn "kptr_restrict not 2"
[[ "$(sysctl -n kernel.randomize_va_space 2>/dev/null)" == "2" ]] && ok "ASLR=2" || fail "ASLR not enabled"
[[ "$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null)" == "1" ]] && ok "SYN cookies=1" || warn "SYN cookies not enabled"
[[ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)" == "0" ]] && ok "IP forwarding disabled" || warn "IP forwarding enabled"
[[ "$(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null)" == "0" ]] && ok "ICMP redirects disabled" || warn "ICMP redirects not disabled"

# GRUB must not have nosmt=force
if grep -q "nosmt=force" /etc/default/grub 2>/dev/null; then
    fail "GRUB has nosmt=force — disables all CPU cores except one"
else
    ok "GRUB does not have nosmt=force"
fi

# GRUB must not have lockdown=confidentiality
if grep -q "lockdown=confidentiality" /etc/default/grub 2>/dev/null; then
    fail "GRUB has lockdown=confidentiality — breaks suspend/hibernate"
else
    ok "GRUB does not have lockdown=confidentiality"
fi

# ─── 5. Firejail ──────────────────────────────────────────────────────────────
section "5. Firejail"

if command -v firejail &>/dev/null; then
    ok "Firejail installed"

    # Test basic sandbox launch
    if firejail --quiet --private echo "test" &>/dev/null; then
        ok "Firejail basic sandbox works"
    else
        fail "Firejail basic sandbox failed"
    fi

    # Check global config does not have restrict-namespaces
    if grep -q "^restrict-namespaces yes" /etc/firejail/firejail.config 2>/dev/null; then
        fail "firejail.config has restrict-namespaces yes — breaks Firejail on restricted kernels"
    else
        ok "firejail.config: restrict-namespaces not set globally"
    fi

    # Check global config does not have apparmor yes
    if grep -q "^apparmor yes" /etc/firejail/firejail.config 2>/dev/null; then
        fail "firejail.config has apparmor yes globally — crashes when profile missing"
    else
        ok "firejail.config: apparmor not set globally"
    fi
else
    warn "Firejail not installed"
fi

# ─── 6. Network ───────────────────────────────────────────────────────────────
section "6. Network"

if ip link show | grep -qE "^[0-9]+: (eth|wlan|enp|wlp|eno)"; then
    ok "Network interfaces detected"
else
    warn "No standard network interfaces found"
fi

# Check NM MAC randomization configured
if grep -q "wifi.cloned-mac-address=random" /etc/NetworkManager/conf.d/*.conf 2>/dev/null; then
    ok "MAC randomization configured"
else
    warn "MAC randomization not configured"
fi

# Check NM dispatcher for DNS restore
if [[ -x /etc/NetworkManager/dispatcher.d/99-atlazes-dns-restore ]]; then
    ok "NM DNS restore dispatcher present"
else
    warn "NM DNS restore dispatcher missing"
fi

# ─── 7. Desktop ───────────────────────────────────────────────────────────────
section "7. Desktop"

dpkg -l xfce4 &>/dev/null && ok "XFCE4 installed" || fail "XFCE4 not installed"
dpkg -l lightdm &>/dev/null && ok "LightDM installed" || fail "LightDM not installed"
dpkg -l firefox-esr &>/dev/null && ok "Firefox ESR installed" || fail "Firefox ESR not installed"

# Check wallpaper file exists (either PNG or SVG)
if [[ -f /usr/share/backgrounds/atlazes/wallpaper.png ]] || \
   [[ -f /usr/share/backgrounds/atlazes/wallpaper.svg ]]; then
    ok "Wallpaper file present"
else
    fail "Wallpaper file missing — desktop will show broken image"
fi

# Check Firefox policies
if [[ -f /usr/lib/firefox-esr/distribution/policies.json ]]; then
    ok "Firefox ESR policies present"
else
    warn "Firefox ESR policies missing"
fi

# ─── 8. CLI Tool ──────────────────────────────────────────────────────────────
section "8. atlazes CLI"

atlazes help &>/dev/null && ok "atlazes help works" || fail "atlazes help failed"
atlazes status &>/dev/null && ok "atlazes status works" || fail "atlazes status failed"
[[ -f /var/lib/atlazes/current-mode ]] && ok "atlazes mode state readable" || warn "atlazes mode state missing"

# ─── 9. Package Integrity ─────────────────────────────────────────────────────
section "9. Package Integrity"

# Check no broken packages
BROKEN=$(dpkg -l 2>/dev/null | grep "^[^ih]" | grep -v "^|" | grep -v "^+" | grep -v "^Desired" | wc -l || echo "0")
if [[ "$BROKEN" -eq 0 ]]; then
    ok "No broken packages"
else
    warn "$BROKEN packages in unexpected state"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}══ VALIDATION SUMMARY ══${NC}"
echo ""
echo -e "  ${GREEN}✓ PASS:${NC}  $PASS"
echo -e "  ${RED}✗ FAIL:${NC}  $FAIL"
echo -e "  ${YELLOW}~ WARN:${NC}  $WARN"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo -e "  ${RED}${BOLD}BLOCKING ISSUES (must fix before release):${NC}"
    for issue in "${BLOCKING[@]}"; do
        echo -e "    ${RED}✗${NC} $issue"
    done
    echo ""
fi

if [[ $WARN -gt 0 ]]; then
    echo -e "  ${YELLOW}${BOLD}MINOR ISSUES (fix if possible):${NC}"
    for issue in "${MINOR[@]}"; do
        echo -e "    ${YELLOW}~${NC} $issue"
    done
    echo ""
fi

if [[ $FAIL -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}RESULT: READY FOR RELEASE${NC}"
else
    echo -e "  ${RED}${BOLD}RESULT: NOT READY — Fix blocking issues first${NC}"
fi
echo ""

exit $FAIL
