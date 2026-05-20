# ATLAZES OS

[![Status](https://img.shields.io/badge/status-public%20beta-orange)](https://github.com/atlazes-os/atlazes-os/releases)
[![Version](https://img.shields.io/badge/version-1.0.0--beta.1-blue)](https://github.com/atlazes-os/atlazes-os/releases)
[![Base](https://img.shields.io/badge/base-Debian%2012-red)](https://www.debian.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

> A privacy-focused, hardened Linux daily driver based on Debian 12.

---

## ⚠️ Public Beta

**This is v1.0.0-beta.1.** The system is functional and has been tested in virtual
machines and on a limited set of hardware configurations. The purpose of this release
is real-world testing on diverse hardware.

**Not recommended for:** production systems, mission-critical machines, or users who
cannot troubleshoot Linux issues independently.

**If you find a bug:** please [open an issue](https://github.com/atlazes-os/atlazes-os/issues/new).
That is the most valuable contribution you can make right now.

---

## What ATLAZES OS Is

ATLAZES OS is a Debian 12-based Linux distribution that reduces passive surveillance,
disables OS and browser telemetry, encrypts DNS queries, and hardens the system against
common threats. It is designed for daily use by people who want meaningful privacy
improvements over a default Linux installation.

**ATLAZES OS is not an anonymity system.** Your IP address remains visible to websites
you visit. For strong anonymity, use Tails OS or Tor Browser.

---

## What ATLAZES OS Does

- Encrypts DNS queries in transit (dnscrypt-proxy → Quad9/Cloudflare)
- Randomizes MAC address per network connection
- Disables all OS-level and browser telemetry
- Enforces AppArmor profiles for Firefox and CUPS
- Sandboxes Firefox, Thunderbird, and VLC via Firejail
- Blocks ~35 tracking domains by default (~75,000 after post-install)
- Hardens kernel parameters (ASLR, PTI, Spectre mitigations)
- Provides full-disk encryption via LUKS2 (optional, chosen at install)
- Three configurable privacy postures: normal / private / paranoid

## What ATLAZES OS Does Not Do

- Does not hide your IP address from websites you visit
- Does not provide anonymity (use Tails for that)
- Does not prevent tracking by websites you log into
- Does not guarantee DNS privacy (resolver trust is contractual, not technical)
- Does not protect against targeted attacks by well-resourced adversaries

---

## Editions

| Edition | Size | Contents |
|---------|------|----------|
| Core | ~1.5 GB | Privacy + security tools, Firefox ESR, daily use |
| Dev | ~3.0 GB | Core + VSCodium, Node.js, Python, Docker |
| Security | ~2.0 GB | Core + extended security and auditing tools |

---

## Quick Start

```bash
# 1. Verify the download
sha256sum atlazes-os-1.0.0-beta.1-core-amd64.iso
# Compare with SHA256SUMS

# 2. Flash to USB
sudo dd if=atlazes-os-1.0.0-beta.1-core-amd64.iso \
        of=/dev/sdX bs=4M status=progress oflag=sync

# 3. Boot — live session auto-logs in as: atlazes / atlazes

# 4. Check security status
atlazes status

# 5. Install (optional)
# Double-click "Install ATLAZES OS" on the desktop
# Run post-install after first boot:
sudo ./post-install.sh
```

---

## Key Features

- DNS query encryption via dnscrypt-proxy (Quad9 + Cloudflare, published no-log policies)
- MAC address randomization per connection (NetworkManager)
- AppArmor selective enforcement (stable profiles only — no app breakage)
- Firejail application sandboxing (namespace + seccomp, not container-level isolation)
- Three privacy modes: normal / private / paranoid
- LUKS2 full-disk encryption (optional, via Calamares installer)
- Hardened sysctl parameters (production-safe, verified)
- UFW firewall (deny all incoming by default)
- Zero OS and browser telemetry
- Calamares graphical installer (BIOS + UEFI)
- Live USB with persistence support

---

## Project Structure

```
ATLAZES/
├── build.sh                    # Main build script
├── README.md                   # This file
├── CHANGELOG.md                # Release history
├── config/                     # live-build configuration
│   ├── package-lists/          # Package lists per edition
│   ├── hooks/                  # Build-time configuration hooks
│   ├── includes.chroot/        # Files placed into the live system
│   └── preseed/                # Debian preseed files
├── scripts/                    # Post-install and maintenance scripts
│   ├── hardening/              # Kernel and AppArmor hardening
│   ├── privacy/                # Privacy configuration
│   └── post-install.sh         # Run after installation
├── branding/                   # Logos, wallpapers, GRUB theme
├── calamares/                  # Installer configuration
└── docs/                       # Documentation
```

---

## Build from Source

### Prerequisites (Debian 12 host)

```bash
sudo apt update
sudo apt install -y live-build debootstrap squashfs-tools xorriso \
  isolinux syslinux-efi grub-pc-bin grub-efi-amd64-bin \
  mtools dosfstools git curl
```

### Build

```bash
git clone https://github.com/atlazes-os/atlazes-os.git
cd atlazes-os
sudo ./build.sh                        # Core edition
sudo ./build.sh --edition=dev          # Dev edition
sudo ./build.sh --edition=security     # Security edition
```

**Note on reproducibility:** Two builds from the same source on different days will
produce different SHA256 hashes due to Debian package updates and build timestamps.
We publish checksums for official releases. Bit-for-bit reproducibility with pinned
packages is planned for a future release.

---

## Documentation

- [Installation Guide](docs/installation-guide.md)
- [First Boot Guide](docs/first-boot-guide.md)
- [CLI Reference](docs/cli-guide.md)
- [Troubleshooting](docs/troubleshooting.md)
- [FAQ](docs/faq.md)
- [Security Transparency](docs/security-transparency.md)
- [QA Checklist](docs/qa-checklist.md)
- [Build Guide](docs/build-guide.md)

---

## Reporting Bugs (Beta)

Open an issue with:
- ATLAZES version: `cat /etc/atlazes-release`
- Hardware: `inxi -Fxz`
- What happened and steps to reproduce

[→ Bug Report](https://github.com/atlazes-os/atlazes-os/issues/new?template=bug_report.md) |
[→ Hardware Report](https://github.com/atlazes-os/atlazes-os/issues/new?template=hardware_report.md) |
[→ General Feedback](https://github.com/atlazes-os/atlazes-os/issues/new?template=feedback.md)

---

## Security Transparency

All security claims are documented with their limitations.
See [docs/security-transparency.md](docs/security-transparency.md) for the full
threat model, DNS trust model, sandboxing limitations, and privacy vs anonymity.

---

## License

Build scripts, hooks, and configuration: MIT License
Included packages: their respective open-source licenses

---

## Disclaimer

ATLAZES OS is designed for legitimate privacy, security, and data protection.
It must not be used for illegal activities, hacking, fraud, or bypassing law enforcement.
