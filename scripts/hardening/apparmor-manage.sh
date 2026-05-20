#!/bin/bash
# =============================================================================
# ATLAZES OS - AppArmor Management Script
# Provides strict/relaxed mode toggling and profile management
# Usage: sudo ./apparmor-manage.sh [strict|relaxed|status|enforce <profile>|complain <profile>]
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
section() { echo -e "\n${CYAN}${BOLD}── $* ──${NC}\n"; }

[[ $EUID -ne 0 ]] && { echo "Run as root: sudo $0"; exit 1; }

# ── Profiles known to be stable for enforce mode ──────────────────────────────
STABLE_ENFORCE_PROFILES=(
    "usr.bin.firefox"
    "usr.bin.firefox-esr"
    "usr.sbin.cups"
    "usr.sbin.cupsd"
    "usr.bin.evince"
    "usr.bin.man"
    "usr.sbin.tcpdump"
    "usr.bin.ping"
    "usr.sbin.ntpd"
    "usr.sbin.chronyd"
    "usr.lib.snapd.snap-confine.real"
)

# ── Profiles that should stay in complain mode (may break if enforced) ────────
COMPLAIN_PROFILES=(
    "usr.bin.thunderbird"
    "usr.bin.vlc"
    "usr.bin.gimp"
    "usr.bin.inkscape"
    "usr.bin.libreoffice"
    "usr.bin.keepassxc"
)

cmd_status() {
    section "AppArmor Status"
    aa-status 2>/dev/null || echo "AppArmor not available."
    echo ""
    echo "Profiles in enforce mode:"
    aa-status 2>/dev/null | grep "enforce" | head -30 || true
    echo ""
    echo "Profiles in complain mode:"
    aa-status 2>/dev/null | grep "complain" | head -30 || true
}

cmd_strict() {
    section "Switching to STRICT AppArmor Mode"
    echo "Enforcing stable profiles, setting others to complain..."
    echo ""

    # First: set all to complain (safe baseline)
    find /etc/apparmor.d/ -maxdepth 1 -type f ! -name "*.dpkg-new" ! -name "*.dpkg-old" | \
    while read -r profile; do
        aa-complain "$profile" 2>/dev/null || true
    done
    log "All profiles set to complain mode."

    # Then: enforce stable profiles
    for profile_name in "${STABLE_ENFORCE_PROFILES[@]}"; do
        local path="/etc/apparmor.d/${profile_name}"
        if [[ -f "$path" ]]; then
            aa-enforce "$path" 2>/dev/null && log "Enforced: ${profile_name}" || \
                warn "Could not enforce: ${profile_name}"
        fi
    done

    log "Strict mode active."
    echo ""
    echo "To check status: sudo $0 status"
    echo "To relax:        sudo $0 relaxed"
}

cmd_relaxed() {
    section "Switching to RELAXED AppArmor Mode"
    echo "Setting all profiles to complain mode (logs but does not block)..."
    echo ""

    find /etc/apparmor.d/ -maxdepth 1 -type f ! -name "*.dpkg-new" ! -name "*.dpkg-old" | \
    while read -r profile; do
        aa-complain "$profile" 2>/dev/null && log "Complain: $(basename "$profile")" || true
    done

    log "Relaxed mode active. All violations are logged but not blocked."
    warn "This reduces security. Use strict mode for production."
}

cmd_enforce() {
    local profile_name="${1:-}"
    [[ -z "$profile_name" ]] && { echo "Usage: sudo $0 enforce <profile-name>"; exit 1; }

    local path="/etc/apparmor.d/${profile_name}"
    if [[ ! -f "$path" ]]; then
        # Try with full path
        path="$profile_name"
    fi

    [[ -f "$path" ]] || { echo "Profile not found: ${profile_name}"; exit 1; }

    aa-enforce "$path"
    log "Profile enforced: ${profile_name}"
}

cmd_complain() {
    local profile_name="${1:-}"
    [[ -z "$profile_name" ]] && { echo "Usage: sudo $0 complain <profile-name>"; exit 1; }

    local path="/etc/apparmor.d/${profile_name}"
    [[ -f "$path" ]] || path="$profile_name"
    [[ -f "$path" ]] || { echo "Profile not found: ${profile_name}"; exit 1; }

    aa-complain "$path"
    log "Profile set to complain: ${profile_name}"
}

cmd_disable() {
    local profile_name="${1:-}"
    [[ -z "$profile_name" ]] && { echo "Usage: sudo $0 disable <profile-name>"; exit 1; }

    local path="/etc/apparmor.d/${profile_name}"
    [[ -f "$path" ]] || path="$profile_name"
    [[ -f "$path" ]] || { echo "Profile not found: ${profile_name}"; exit 1; }

    aa-disable "$path"
    warn "Profile disabled: ${profile_name}"
}

cmd_help() {
    echo "ATLAZES OS - AppArmor Management"
    echo ""
    echo "Usage: sudo $0 <command> [profile]"
    echo ""
    echo "Commands:"
    echo "  status              Show all profile states"
    echo "  strict              Enforce stable profiles, complain for others"
    echo "  relaxed             Set all profiles to complain mode"
    echo "  enforce <profile>   Enforce a specific profile"
    echo "  complain <profile>  Set a specific profile to complain mode"
    echo "  disable <profile>   Disable a specific profile"
    echo ""
    echo "Examples:"
    echo "  sudo $0 strict"
    echo "  sudo $0 enforce usr.bin.firefox-esr"
    echo "  sudo $0 complain usr.bin.thunderbird"
    echo "  sudo $0 status"
}

case "${1:-help}" in
    status)   cmd_status ;;
    strict)   cmd_strict ;;
    relaxed)  cmd_relaxed ;;
    enforce)  cmd_enforce "${2:-}" ;;
    complain) cmd_complain "${2:-}" ;;
    disable)  cmd_disable "${2:-}" ;;
    help|--help|-h) cmd_help ;;
    *)
        echo "Unknown command: $1"
        cmd_help
        exit 1
        ;;
esac
