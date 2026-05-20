# ATLAZES OS — First Boot Guide

> ⚠️ **Public Beta Notice:** This is v1.0.0-beta.1. If something does not work,
> please [report it](https://github.com/atlazes-os/atlazes-os/issues/new).
> Your report directly improves the next release.

Welcome to ATLAZES OS. This guide covers everything you need to do after your first login.

---

## 1. Check Security Status

Open a terminal (`Ctrl+Alt+T` or click the terminal icon) and run:

```bash
atlazes status
```

You should see all green checkmarks. If anything shows red, run:

```bash
sudo atlazes secure
```

---

## 2. Run Post-Install Setup

If you haven't already:

```bash
sudo ./post-install.sh
```

This takes 5–10 minutes and requires internet. It updates packages, downloads the full tracker blocklist, and initializes security tools.

---

## 3. Change the Default Password

The live session uses `atlazes:atlazes`. On an installed system, you set your own password during installation. Verify it's strong:

```bash
passwd
```

---

## 4. Update the System

```bash
sudo atlazes update
# or
sudo apt update && sudo apt upgrade -y
```

---

## 5. Choose Your Privacy Posture

ATLAZES OS has three privacy modes. Each adjusts firewall rules, DNS, MAC
randomization, IPv6, and Tor. None of them hide your IP address from websites
you visit — for that, use a VPN or Tor Browser.

```bash
# See current mode
atlazes mode

# Normal (default) — encrypted DNS, MAC randomization, firewall active
sudo atlazes mode normal

# Private — adds immediate MAC randomization, disables IPv6
# Use on untrusted networks (coffee shops, hotels)
sudo atlazes mode private

# Paranoid — Tor routing, strict outgoing firewall
# Most applications will not work. Use Tor Browser only.
# Not suitable for general daily use.
sudo atlazes mode paranoid
```

For most users, **normal** mode is the right choice for daily use.
Switch to **private** on untrusted networks.

---

## 6. Configure WiFi

Click the network icon in the panel → select your network → enter password.

MAC address is automatically randomized per connection.

---

## 7. Set Your Timezone

```bash
sudo timedatectl set-timezone America/New_York
# Replace with your timezone. List all: timedatectl list-timezones
```

---

## 8. Set Your Locale

```bash
sudo dpkg-reconfigure locales
# Select your locale (e.g., en_US.UTF-8)
```

---

## 9. Install Additional Software

```bash
# Update package list first
sudo apt update

# Examples:
sudo apt install vlc          # Media player
sudo apt install gimp         # Image editor
sudo apt install libreoffice  # Office suite
sudo apt install signal-desktop  # (from Signal's own repo)
```

---

## 10. Explore the atlazes CLI

```bash
atlazes help
```

Key commands:
```bash
atlazes status              # Security overview
atlazes sandbox firefox     # Launch Firefox in sandbox
sudo atlazes scan           # Virus scan
atlazes clean               # Clean temp files
atlazes dns                 # Check DNS
sudo atlazes tor start      # Start Tor
```

---

## 11. Desktop Customization

**Change wallpaper:** Right-click desktop → Desktop Settings

**Change theme:** Applications → Settings → Appearance

**Add panel items:** Right-click panel → Panel → Add New Items

**Dark mode is on by default** (Arc-Dark theme + Papirus-Dark icons)

---

## 12. Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Alt+T` | Open terminal |
| `Super` (Win key) | Open Whisker Menu |
| `Alt+F2` | Run dialog |
| `Print Screen` | Screenshot |
| `Ctrl+Alt+L` | Lock screen |
| `Alt+F4` | Close window |

---

## 13. Encrypted Storage

To create an encrypted container with VeraCrypt:
```bash
# Install VeraCrypt (not in Debian repos, download from veracrypt.fr)
# Or use LUKS directly:
sudo cryptsetup luksFormat /dev/sdXY
sudo cryptsetup luksOpen /dev/sdXY my-encrypted-drive
sudo mkfs.ext4 /dev/mapper/my-encrypted-drive
```

---

## 14. Tor Browser

Tor Browser is the correct tool for anonymous browsing. It is specifically
hardened against browser fingerprinting and routes all traffic through Tor.
Configuring a regular browser to use the Tor SOCKS proxy does not provide
the same protection.

```bash
torbrowser-launcher
# First run downloads and installs Tor Browser
```

---

## 15. Verify Everything Works

```bash
# Full automated check
bash scripts/qa-validate.sh

# Manual check
atlazes status
sudo ufw status
sudo aa-status | head -5
systemctl status dnscrypt-proxy
```

---

## 16. Report Issues (Beta)

If anything does not work as expected, please report it.
Every report helps improve the next release.

```bash
# Collect system info for your report
cat /etc/atlazes-release
uname -r
inxi -Fxz
atlazes logs
```

Report at: https://github.com/atlazes-os/atlazes-os/issues/new

---

## What's Running by Default

| Service | Purpose | Status |
|---------|---------|--------|
| NetworkManager | Network management | Active |
| dnscrypt-proxy | Encrypted DNS | Active |
| UFW | Firewall | Active |
| AppArmor | Mandatory access control | Active |
| Fail2ban | Brute-force protection | Active |
| TLP | Power management | Active |
| auditd | System auditing | Active |
| ClamAV | Antivirus | Active |

---

## Getting Help

```bash
# CLI help
atlazes help

# System logs
atlazes logs

# Security audit
sudo lynis audit system

# Check for rootkits
sudo rkhunter --check
```
