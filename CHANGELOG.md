# ATLAZES OS — Changelog

All notable changes to ATLAZES OS are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0-beta.1] — 2025-01-01 — "Horizon" — Public Beta

> ⚠️ This is a public beta release. Not recommended for production use.
> Report issues at: https://github.com/atlazes-os/atlazes-os/issues

### Base System
- Debian 12 (Bookworm) stable base
- Linux kernel 6.1 (amd64)
- XFCE4 desktop environment with Arc-Dark theme
- LightDM display manager with custom branding
- GRUB2 bootloader with custom theme (BIOS + UEFI)
- Live USB mode with auto-login (atlazes / atlazes)
- Calamares graphical installer

### Editions
- `core` — Privacy and security tools, no dev bloat (~1.5 GB ISO)
- `dev` — Core + developer tools (~3.0 GB ISO)
- `security` — Core + extended security and auditing tools (~2.0 GB ISO)

### Security
- AppArmor mandatory access control (selective enforce — stable profiles only)
- UFW firewall (deny all incoming by default)
- Fail2ban brute-force protection
- Firejail application sandboxing (Firefox, Thunderbird, VLC auto-sandboxed)
- ClamAV antivirus with daily signature updates
- rkhunter rootkit detection
- Lynis security auditing
- AIDE file integrity monitoring (weekly systemd timer)
- auditd system call auditing
- Full disk encryption (LUKS2) via Calamares installer (optional)
- Hardened sysctl parameters (production-safe, verified)
- Kernel module blacklist (unused protocols and filesystems)
- CPU microcode updates (Intel + AMD)

### Privacy
- dnscrypt-proxy DNS encryption (port 53, resolv.conf writable for VPN)
- MAC address randomization per connection (NetworkManager)
- Firefox ESR hardened policies (no telemetry, HTTPS-only, DuckDuckGo)
- uBlock Origin pre-installed in Firefox
- Tracker blocking via /etc/hosts (~35 domains default; ~75,000 after post-install)
- All OS telemetry disabled (popularity-contest, apport, whoopsie)
- Avahi publishing restricted
- Bluetooth auto-enable disabled

### Privacy Modes
- `normal` — Encrypted DNS, MAC randomization, firewall. IP visible to websites.
- `private` — Adds immediate MAC randomization, IPv6 off. IP still visible.
- `paranoid` — Tor routing, strict firewall. Increased anonymity, not a guarantee.

### atlazes CLI
- `atlazes status` — Security and privacy component status
- `atlazes scan [path]` — ClamAV signature-based malware scan
- `atlazes clean` — Privacy cleanup
- `atlazes secure` — Check and restore inactive security services
- `atlazes sandbox <app>` — Firejail sandbox launcher
- `atlazes mode <normal|private|paranoid>` — Privacy posture switcher
- `atlazes tor <start|stop|status>` — Tor daemon control
- `atlazes dns` — DNS configuration and resolver test
- `atlazes update` — System update
- `atlazes info` — System information
- `atlazes logs` — Recent security log entries

### Hardware Support
- Intel, AMD, NVIDIA (nouveau) GPU drivers
- Non-free firmware: iwlwifi, atheros, realtek, broadcom, amd-graphics
- Intel and AMD CPU microcode
- Touchpad (libinput + synaptics)
- Bluetooth (bluez)
- Printing (CUPS + hplip)
- Scanning (SANE)
- USB, Thunderbolt, SD card support
- VirtualBox and VMware guest tools

### Developer Tools (Dev Edition only)
- VSCodium (VS Code without telemetry)
- Node.js LTS
- Python 3 + pip + venv
- Git, Docker, Podman
- Build tools (gcc, make, cmake)
- Shell tools (fzf, ripgrep, bat, eza, tmux)

### Bug Fixes Applied During Development
- Fixed: dnscrypt-proxy port mismatch (5300 → 53)
- Fixed: resolv.conf hard-locked with chattr+i (removed — breaks VPN)
- Fixed: squashfs blacklisted in modprobe (breaks live boot)
- Fixed: AppArmor enforce-all (breaks Thunderbird, VLC, LibreOffice)
- Fixed: 6 dangerous GRUB params (nosmt=force, lockdown=confidentiality, oops=panic, loglevel=0, mce=0, module.sig_enforce=1)
- Fixed: 12 non-existent packages in package lists
- Fixed: /proc hidepid=2 without proc group (breaks ps/top for users)
- Fixed: StevenBlack hosts download during build (fails without internet)
- Fixed: Dev tools in core ISO (added edition system)

### Known Issues in beta.1
- Hardware compatibility not fully verified on all WiFi adapters and GPUs
- Installer edge cases on unusual partition layouts not fully tested
- Suspend/resume behavior varies by hardware
- See: https://github.com/atlazes-os/atlazes-os/issues?label=known-issue

---

## Versioning Policy

- **Major** (X.0.0): New base system, major architecture changes
- **Minor** (1.X.0): New features, new editions, significant package updates
- **Patch** (1.0.X): Bug fixes, security patches, package updates
- **Pre-release** (1.0.0-beta.N): Public beta iterations

## Beta Cycle Plan

```
1.0.0-beta.1  →  Public beta, collect hardware reports (2–4 weeks)
1.0.0-beta.2  →  Fix confirmed bugs, re-test
1.0.0-beta.3  →  Final polish if needed
1.0.0         →  Stable release
```

## Support Policy

| Version | Status | Notes |
|---------|--------|-------|
| 1.0.0-beta.1 | Active beta | Report bugs, not for production |
