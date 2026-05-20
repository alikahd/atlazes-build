# ATLAZES OS - Technical Roadmap

## Architecture Decision: Why Debian 12 (Bookworm)?

| Factor | Debian 12 | Ubuntu LTS | Arch |
|--------|-----------|------------|------|
| Stability | ★★★★★ | ★★★★☆ | ★★☆☆☆ |
| live-build support | Native | Good | Manual |
| Security updates | 5 years | 5 years | Rolling |
| Hardware support | Excellent | Excellent | Excellent |
| Non-free firmware | Yes | Yes | Yes |
| Community | Huge | Huge | Large |
| **Verdict** | **✓ Best choice** | Good | Not suitable |

**Decision: Debian 12 Bookworm** — most stable, best live-build support, longest LTS.

---

## Version 1.0 — Horizon (Current)

ATLAZES OS is a privacy-focused, hardened Linux daily driver based on Debian 12.
It reduces passive surveillance and disables telemetry. It is not an anonymity system.

### Goals
- [x] Bootable Live USB
- [x] Calamares graphical installer
- [x] LUKS2 full disk encryption (optional, chosen at install)
- [x] XFCE4 desktop with dark theme
- [x] AppArmor selective enforcement (stable profiles only)
- [x] UFW firewall
- [x] Encrypted DNS (dnscrypt-proxy, port 53)
- [x] MAC address randomization (local network only)
- [x] Firefox ESR hardened (telemetry off, uBlock Origin)
- [x] Security tools (ClamAV, rkhunter, Lynis, AIDE)
- [x] Privacy tools (mat2, BleachBit, Firejail)
- [x] Developer tools (VSCodium, Node.js, Python, Docker) — Dev edition only
- [x] BIOS + UEFI boot support
- [x] Wide hardware support (non-free firmware)
- [x] Custom branding (GRUB, LightDM, desktop)
- [x] atlazes CLI
- [x] Three privacy modes (normal / private / paranoid)
- [x] Edition system (core / dev / security)

---

## Version 1.1 — Planned

### Security
- [ ] Secure Boot support (signed shim + GRUB)
- [ ] Measured boot with TPM2
- [ ] Automatic AIDE checks via systemd timer
- [ ] Intrusion detection alerts (desktop notifications)
- [ ] Sandboxed browser (Firejail profile for Firefox)

### Privacy
- [ ] Tor Browser pre-installed (not just launcher)
- [ ] I2P integration
- [ ] OnionShare pre-installed
- [ ] Automatic metadata stripping on file save
- [ ] Privacy dashboard GUI

### Desktop
- [ ] Custom XFCE4 panel layout with security indicators
- [ ] System tray: VPN status, Tor status, firewall status
- [ ] Welcome wizard on first boot
- [ ] ATLAZES Control Center (GUI for all settings)

### Hardware
- [ ] NVIDIA proprietary driver installer (GUI)
- [ ] Better touchpad gestures
- [ ] HiDPI support improvements

---

## Version 2.0 — Future

### Major Features
- [ ] Custom kernel with additional hardening patches (grsecurity-inspired)
- [ ] Immutable root filesystem option (read-only / overlayfs)
- [ ] Verified boot chain
- [ ] Container-based app isolation (Flatpak/Bubblewrap)
- [ ] Network namespace isolation per application
- [ ] Hardware security key support (YubiKey, etc.)
- [ ] Encrypted DNS with DNSSEC validation
- [ ] Built-in VPN client with kill switch
- [ ] Automatic threat intelligence updates

### Infrastructure
- [ ] Official package repository (APT)
- [ ] Automatic ISO updates (delta updates)
- [ ] Community portal
- [ ] Bug tracker

---

## Build System Architecture

```
ATLAZES OS Build Pipeline
═══════════════════════════════════════════════════════════

  build.sh
     │
     ├── lb config (live-build initialization)
     │     ├── Debian Bookworm base
     │     ├── amd64 architecture
     │     ├── BIOS + UEFI bootloaders
     │     └── non-free firmware enabled
     │
     ├── lb bootstrap (debootstrap)
     │     └── Minimal Debian base system
     │
     ├── lb chroot (package installation)
     │     ├── 01-base.list.chroot
     │     ├── 02-desktop.list.chroot
     │     ├── 03-security.list.chroot
     │     ├── 04-privacy.list.chroot
     │     ├── 05-development.list.chroot
     │     ├── 06-hardware.list.chroot
     │     └── 07-installer.list.chroot
     │
     ├── lb hooks (configuration)
     │     ├── 0010-system-setup.hook.chroot
     │     ├── 0020-security-hardening.hook.chroot
     │     ├── 0030-privacy-config.hook.chroot
     │     ├── 0040-branding.hook.chroot
     │     ├── 0050-nodejs-vscode.hook.chroot
     │     └── 0060-grub-theme.hook.binary
     │
     ├── lb binary (ISO assembly)
     │     ├── squashfs compression
     │     ├── GRUB BIOS + EFI
     │     └── ISO hybrid image
     │
     └── output/atlazes-os-1.0.0-amd64.iso
```

---

## Security Architecture

```
ATLAZES OS Security Layers
═══════════════════════════════════════════════════════════

  Layer 7: Application
    └── Firejail sandboxing, AppArmor profiles per app

  Layer 6: Browser
    └── Firefox ESR + uBlock Origin + hardened policies

  Layer 5: User Space
    └── Restricted umask, no core dumps, AIDE monitoring

  Layer 4: System Services
    └── UFW firewall, Fail2ban, ClamAV, rkhunter

  Layer 3: Network
    └── MAC randomization, encrypted DNS, no telemetry

  Layer 2: Kernel
    └── Hardened sysctl, module blacklist, ASLR, PTI

  Layer 1: Boot
    └── GRUB with hardened kernel parameters, LUKS2 encryption
```

---

## Privacy Architecture

```
ATLAZES OS Privacy Layers
═══════════════════════════════════════════════════════════

  DNS:      dnscrypt-proxy → Encrypted DNS-over-HTTPS
            (resolver trust is contractual, not technical)
  Network:  MAC randomization (local network only, not internet-level)
  Browser:  Firefox ESR hardened, DuckDuckGo default
  Files:    mat2 metadata cleaner, BleachBit
  Storage:  LUKS2 full disk encryption (optional, chosen at install)
  Tracking: Hosts-based blocker (~35 domains default;
            ~75,000 after post-install.sh with internet)
  Telemetry: OS and browser telemetry disabled

  Note: IP address remains visible to websites visited.
  ATLAZES OS reduces passive surveillance — it is not an anonymity system.
```
