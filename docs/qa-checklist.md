# ATLAZES OS v1.0.0 — QA Testing Checklist

> Complete this checklist before every release candidate.
> Mark each item: ✅ PASS | ❌ FAIL | ⚠️ PARTIAL | ⏭️ SKIP (with reason)

---

## 0. Pre-Test Setup

```bash
# On the build machine (Debian 12 host):
sudo ./build.sh clean
sudo ./build.sh build --edition=core
sudo ./build.sh build --edition=dev
sudo ./build.sh build --edition=security

# Verify ISOs exist
ls -lh output/
# Expected:
#   atlazes-os-1.0.0-core-amd64.iso     ~1.5 GB
#   atlazes-os-1.0.0-dev-amd64.iso      ~3.0 GB
#   atlazes-os-1.0.0-security-amd64.iso ~2.0 GB

# Verify checksums
sha256sum -c output/*.sha256
```

---

## 1. BUILD VALIDATION

| # | Test | Command | Expected | Result |
|---|------|---------|----------|--------|
| 1.1 | Core build completes | `sudo ./build.sh --edition=core` | Exit 0, ISO created | |
| 1.2 | Dev build completes | `sudo ./build.sh --edition=dev` | Exit 0, ISO created | |
| 1.3 | Security build completes | `sudo ./build.sh --edition=security` | Exit 0, ISO created | |
| 1.4 | Core ISO size | `ls -lh output/*core*` | 1.2–1.8 GB | |
| 1.5 | Dev ISO size | `ls -lh output/*dev*` | 2.5–3.5 GB | |
| 1.6 | SHA256 checksums valid | `sha256sum -c output/*.sha256` | All OK | |
| 1.7 | ISO is hybrid (USB bootable) | `file output/*core*.iso` | "ISO 9660 ... MBR" | |
| 1.8 | No missing packages in log | `grep -i "unable to locate\|no installation candidate" build/build-core.log` | No output | |
| 1.9 | Clean build works | `sudo ./build.sh clean && sudo ./build.sh` | Succeeds | |

---

## 2. LIVE BOOT — VIRTUALBOX

**Setup:** VirtualBox 7.x, 4GB RAM, 2 CPU, 128MB VRAM, EFI enabled

| # | Test | Steps | Expected | Result |
|---|------|-------|----------|--------|
| 2.1 | UEFI boot | Attach ISO, boot with EFI | GRUB menu appears | |
| 2.2 | BIOS boot | Disable EFI, boot | GRUB menu appears | |
| 2.3 | GRUB menu items | Count entries | 4 entries visible | |
| 2.4 | Live session boots | Select "Live Session" | Desktop loads in <90s | |
| 2.5 | Auto-login works | Boot live | Logged in as `atlazes` | |
| 2.6 | Desktop loads | After boot | XFCE4 desktop visible | |
| 2.7 | Dark theme applied | Check desktop | Arc-Dark theme active | |
| 2.8 | Panel visible | Check bottom/top | Panel with apps visible | |
| 2.9 | Terminal opens | Click terminal icon | xfce4-terminal opens | |
| 2.10 | Safe mode boots | Select "Safe Mode" | Desktop loads (nomodeset) | |
| 2.11 | Forensic mode boots | Select "Forensic Mode" | Boots, no disk mounts | |

---

## 3. LIVE BOOT — VMWARE

**Setup:** VMware Workstation/Player, 4GB RAM, 2 CPU

| # | Test | Steps | Expected | Result |
|---|------|-------|----------|--------|
| 3.1 | UEFI boot | Boot with EFI | GRUB menu appears | |
| 3.2 | BIOS boot | Boot without EFI | GRUB menu appears | |
| 3.3 | Desktop loads | Boot live | XFCE4 desktop visible | |
| 3.4 | VMware tools | Check after boot | `open-vm-tools` active | |

---

## 4. DNS VALIDATION

Run these inside the live session terminal:

| # | Test | Command | Expected | Result |
|---|------|---------|----------|--------|
| 4.1 | dnscrypt-proxy running | `systemctl status dnscrypt-proxy` | active (running) | |
| 4.2 | Listening on port 53 | `ss -ulnp \| grep :53` | 127.0.0.1:53 | |
| 4.3 | resolv.conf correct | `cat /etc/resolv.conf` | nameserver 127.0.0.1 | |
| 4.4 | DNS resolves | `dig +short google.com` | IP address returned | |
| 4.5 | DNSSEC works | `dig +dnssec sigok.verteiltesysteme.net` | ad flag present | |
| 4.6 | Encrypted resolver | `dig +short TXT whoami.ds.akahelp.net` | Shows resolver info | |
| 4.7 | resolv.conf NOT locked | `lsattr /etc/resolv.conf` | No `i` flag | |
| 4.8 | DNS fallback (stop service) | `sudo systemctl stop dnscrypt-proxy && dig google.com` | Resolves via fallback | |
| 4.9 | DNS restores after restart | `sudo systemctl start dnscrypt-proxy && dig google.com` | Resolves encrypted | |
| 4.10 | No port 5300 | `ss -ulnp \| grep :5300` | No output | |

**VPN DNS test (on installed system):**
```bash
# Connect OpenVPN, check DNS changes
sudo openvpn --config test.ovpn &
sleep 10
cat /etc/resolv.conf   # Should show VPN DNS
# Disconnect VPN
cat /etc/resolv.conf   # Should restore to 127.0.0.1
```

**Captive portal test:**
```bash
# Connect to public WiFi with captive portal
# Expected: browser opens captive portal page
# After login: DNS should work normally
```

---

## 5. SECURITY VALIDATION

| # | Test | Command | Expected | Result |
|---|------|---------|----------|--------|
| 5.1 | UFW active | `sudo ufw status` | Status: active | |
| 5.2 | UFW default deny | `sudo ufw status verbose` | Default: deny (incoming) | |
| 5.3 | AppArmor active | `systemctl status apparmor` | active (running) | |
| 5.4 | AppArmor profiles | `sudo aa-status \| head -5` | Profiles loaded | |
| 5.5 | No enforce-all | `sudo aa-status \| grep "enforce mode"` | <20 profiles enforced | |
| 5.6 | Firefox enforced | `sudo aa-status \| grep firefox` | enforce mode | |
| 5.7 | Fail2ban active | `systemctl status fail2ban` | active (running) | |
| 5.8 | No open ports | `sudo ss -tlnp` | Only expected ports | |
| 5.9 | Kernel hardening | `sysctl kernel.kptr_restrict` | = 2 | |
| 5.10 | ASLR enabled | `sysctl kernel.randomize_va_space` | = 2 | |
| 5.11 | SYN cookies | `sysctl net.ipv4.tcp_syncookies` | = 1 | |
| 5.12 | No IP forwarding | `sysctl net.ipv4.ip_forward` | = 0 | |
| 5.13 | No ICMP redirects | `sysctl net.ipv4.conf.all.accept_redirects` | = 0 | |
| 5.14 | squashfs loads | `lsmod \| grep squashfs` | squashfs listed | |
| 5.15 | Core dumps disabled | `ulimit -c` | 0 | |
| 5.16 | Firejail installed | `firejail --version` | Version shown | |
| 5.17 | Firefox sandboxed | `ps aux \| grep firefox` | firejail in cmdline | |
| 5.18 | atlazes status | `atlazes status` | All green checks | |
| 5.19 | atlazes secure | `sudo atlazes secure` | 0 issues found | |

---

## 6. PRIVACY VALIDATION

| # | Test | Command | Expected | Result |
|---|------|---------|----------|--------|
| 6.1 | MAC randomization configured | `cat /etc/NetworkManager/conf.d/99-atlazes-privacy.conf` | random entries present | |
| 6.2 | No telemetry services | `systemctl status whoopsie apport popularity-contest 2>&1` | All inactive/not-found | |
| 6.3 | Firefox policies applied | `cat /usr/lib/firefox-esr/distribution/policies.json \| python3 -m json.tool \| grep Telemetry` | DisableTelemetry: true | |
| 6.4 | Tracker blocking | `grep -c "^0.0.0.0" /etc/hosts` | ≥ 30 entries | |
| 6.5 | Avahi restricted | `cat /etc/avahi/avahi-daemon.conf \| grep publish-workstation` | publish-workstation=no | |
| 6.6 | Bluetooth auto-off | `cat /etc/bluetooth/main.conf \| grep AutoEnable` | AutoEnable=false | |
| 6.7 | /proc hidepid | `mount \| grep proc` | hidepid=2 | |
| 6.8 | ps works for user | `ps aux \| grep bash` | Shows own processes | |
| 6.9 | ps hides other users | `ps aux \| grep root` | No root processes visible | |

---

## 7. PRIVACY MODES

| # | Test | Command | Expected | Result |
|---|------|---------|----------|--------|
| 7.1 | Default mode | `atlazes mode` | Shows: normal | |
| 7.2 | Switch to private | `sudo atlazes mode private` | Completes without error | |
| 7.3 | Private mode DNS | `cat /etc/resolv.conf` | nameserver 127.0.0.1 | |
| 7.4 | Private mode IPv6 | `sysctl net.ipv6.conf.all.disable_ipv6` | = 1 | |
| 7.5 | Switch to paranoid | `sudo atlazes mode paranoid` | Completes without error | |
| 7.6 | Paranoid mode Tor | `systemctl status tor` | active (running) | |
| 7.7 | Paranoid firewall | `sudo ufw status` | deny outgoing default | |
| 7.8 | Return to normal | `sudo atlazes mode normal` | Completes without error | |
| 7.9 | Normal mode Tor off | `systemctl status tor` | inactive | |
| 7.10 | Normal mode IPv6 | `sysctl net.ipv6.conf.all.disable_ipv6` | = 0 | |
| 7.11 | Mode persists reboot | `sudo atlazes mode private && sudo reboot` | After reboot: mode=private | |

---

## 8. HARDWARE COMPATIBILITY

Test on real hardware (at minimum one Intel laptop + one AMD machine):

| # | Test | Steps | Expected | Result |
|---|------|-------|----------|--------|
| 8.1 | WiFi detected | Boot live, check NM | WiFi networks visible | |
| 8.2 | WiFi connects | Connect to WPA2 network | Internet works | |
| 8.3 | Ethernet works | Plug in cable | IP assigned, internet works | |
| 8.4 | Audio works | Play test sound | Sound heard | |
| 8.5 | Bluetooth detected | `bluetoothctl show` | Controller found | |
| 8.6 | Touchpad works | Move finger | Cursor moves | |
| 8.7 | Touchpad gestures | Two-finger scroll | Page scrolls | |
| 8.8 | External display | Plug in HDMI/DP | Display detected | |
| 8.9 | USB drive mounts | Plug in USB drive | Appears in file manager | |
| 8.10 | Suspend works | Close lid / suspend | System suspends | |
| 8.11 | Resume works | Open lid / press key | System resumes | |
| 8.12 | Webcam works | `guvcview` | Camera image shown | |
| 8.13 | Printer detected | Connect printer | Appears in CUPS | |
| 8.14 | Intel GPU | Boot on Intel system | No graphical glitches | |
| 8.15 | AMD GPU | Boot on AMD system | No graphical glitches | |
| 8.16 | NVIDIA (nouveau) | Boot on NVIDIA system | Desktop loads | |
| 8.17 | Low-end (4GB RAM) | Boot on 4GB machine | Desktop loads, <800MB RAM | |

---

## 9. INSTALLER (CALAMARES)

| # | Test | Steps | Expected | Result |
|---|------|-------|----------|--------|
| 9.1 | Installer launches | Double-click install icon | Calamares opens | |
| 9.2 | Branding correct | Check installer title | "ATLAZES OS" shown | |
| 9.3 | Slideshow plays | Watch during install | Slides advance every 5s | |
| 9.4 | Locale selection | Select language | Proceeds to next step | |
| 9.5 | Keyboard selection | Select layout | Proceeds to next step | |
| 9.6 | Partition — erase | Select "Erase disk" | Partition created | |
| 9.7 | Partition — encrypt | Enable encryption, set passphrase | LUKS option shown | |
| 9.8 | Partition — manual | Select manual partitioning | Partition editor opens | |
| 9.9 | User creation | Enter username/password | Proceeds to summary | |
| 9.10 | Summary screen | Review summary | All settings shown | |
| 9.11 | Installation completes | Click Install | Completes without error | |
| 9.12 | Reboot after install | Click Restart | System reboots | |
| 9.13 | Installed system boots | Boot from HDD | GRUB menu appears | |
| 9.14 | LUKS prompt | Boot encrypted install | Passphrase prompt shown | |
| 9.15 | Login screen | After LUKS unlock | LightDM login shown | |
| 9.16 | Login works | Enter credentials | Desktop loads | |
| 9.17 | Post-install script | `sudo ./post-install.sh` | Completes without error | |

---

## 10. ATLAZES CLI

| # | Test | Command | Expected | Result |
|---|------|---------|----------|--------|
| 10.1 | Help works | `atlazes help` | Usage shown | |
| 10.2 | Status works | `atlazes status` | Status table shown | |
| 10.3 | Info works | `atlazes info` | neofetch output | |
| 10.4 | DNS works | `atlazes dns` | DNS config shown | |
| 10.5 | Logs works | `atlazes logs` | Log output shown | |
| 10.6 | Scan works | `atlazes scan /tmp` | Scan completes | |
| 10.7 | Clean works | `atlazes clean` | Cleanup runs | |
| 10.8 | Secure works | `sudo atlazes secure` | Security check runs | |
| 10.9 | Sandbox works | `atlazes sandbox firefox` | Firefox in firejail | |
| 10.10 | Mode shows | `atlazes mode` | Current mode shown | |
| 10.11 | Update works | `sudo atlazes update` | apt update runs | |
| 10.12 | Tor toggle | `sudo atlazes tor start` | Tor starts | |
| 10.13 | atlazes-tools shim | `atlazes-tools status` | Same as atlazes status | |
| 10.14 | Unknown command | `atlazes foobar` | Error + help shown | |

---

## 11. PERFORMANCE

| # | Test | Command | Expected | Result |
|---|------|---------|----------|--------|
| 11.1 | Boot time (VM) | Time from GRUB to desktop | < 45 seconds | |
| 11.2 | Boot time (hardware) | Time from GRUB to desktop | < 30 seconds | |
| 11.3 | RAM at idle | `free -m` after boot | < 800 MB used | |
| 11.4 | CPU at idle | `top` after 2 min | < 5% CPU | |
| 11.5 | Disk usage | `df -h /` | < 8 GB used | |
| 11.6 | Firefox launch | Time to open Firefox | < 5 seconds | |
| 11.7 | No zombie services | `systemctl list-units --failed` | 0 failed units | |

---

## 12. EDITION VALIDATION

| # | Test | Command | Expected | Result |
|---|------|---------|----------|--------|
| 12.1 | Core: no Node.js | Boot core, `node --version` | command not found | |
| 12.2 | Core: no VSCodium | Boot core, `codium --version` | command not found | |
| 12.3 | Core: no Docker | Boot core, `docker --version` | command not found | |
| 12.4 | Dev: Node.js present | Boot dev, `node --version` | Version shown | |
| 12.5 | Dev: VSCodium present | Boot dev, `codium --version` | Version shown | |
| 12.6 | Dev: git present | Boot dev, `git --version` | Version shown | |
| 12.7 | Security: lynis present | Boot security, `lynis --version` | Version shown | |
| 12.8 | Security: no Node.js | Boot security, `node --version` | command not found | |

---

## SIGN-OFF

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Build Engineer | | | |
| QA Lead | | | |
| Security Reviewer | | | |
| Release Manager | | | |

**Release Decision:** ☐ GO  ☐ NO-GO  ☐ CONDITIONAL GO

**Blocking issues:**
_List any ❌ FAIL items that must be resolved before release_

---
*ATLAZES OS v1.0.0 QA Checklist — Generated for release cycle*
