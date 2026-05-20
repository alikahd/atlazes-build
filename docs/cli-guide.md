# ATLAZES OS — CLI Reference Guide

The `atlazes` command is the unified control tool for ATLAZES OS.

```
atlazes <command> [options]
```

---

## Security Commands

### `atlazes status`
Shows the current state of security and privacy components.

```bash
atlazes status
```

Reports the active/inactive state of: UFW firewall, AppArmor, dnscrypt-proxy,
Fail2ban, ClamAV, Tor, MAC randomization, DNS resolver, tracker blocking count,
kernel hardening parameters, and current privacy mode.

---

### `atlazes scan [path]`
Runs a ClamAV signature-based malware scan. Defaults to your home directory.

```bash
atlazes scan                    # Scan home directory
atlazes scan /home              # Scan all home directories
atlazes scan /media/usb-drive   # Scan a USB drive
atlazes scan /tmp               # Scan temp directory
```

Updates ClamAV signatures before scanning if run as root. ClamAV detects known
malware signatures — it does not detect zero-day or unknown threats.

---

### `atlazes secure`
Checks security component states and restarts any that are inactive.

```bash
sudo atlazes secure
```

Checks: UFW, AppArmor, dnscrypt-proxy, Fail2ban, kernel hardening parameters,
ClamAV signatures, rkhunter. Fixes inactive services by restarting them.
Does not modify configuration — only restores running state.

---

### `atlazes sandbox <app> [args]`
Launches an application inside a Firejail sandbox using Linux namespaces and
seccomp filtering. This restricts filesystem and syscall access. It is not
equivalent to container or VM isolation.

```bash
atlazes sandbox firefox
atlazes sandbox firefox https://example.com
atlazes sandbox thunderbird
atlazes sandbox vlc /path/to/video.mp4
atlazes sandbox evince document.pdf
atlazes sandbox keepassxc
```

Uses a dedicated Firejail profile if one exists in `/etc/firejail/`, otherwise
uses `--private` mode (isolated home directory).

```bash
atlazes sandbox    # List available profiles
```

---

### `atlazes logs`
Shows recent entries from security-relevant logs.

```bash
atlazes logs
```

Shows: last 20 lines of auth log, last 10 UFW blocks, last 10 Fail2ban entries.

---

## Privacy Commands

### `atlazes mode`
Shows or changes the privacy posture.

```bash
atlazes mode                    # Show current mode
sudo atlazes mode normal        # Switch to normal mode
sudo atlazes mode private       # Switch to private mode
sudo atlazes mode paranoid      # Switch to paranoid mode
```

**Mode comparison:**

| Feature | Normal | Private | Paranoid |
|---------|--------|---------|----------|
| Firewall | Deny incoming | Deny all incoming | Deny all, Tor+HTTPS only |
| DNS | Encrypted (dnscrypt-proxy) | Encrypted (forced) | Via Tor |
| MAC | Random per connection | Randomized immediately | Randomized immediately |
| IPv6 | Enabled | Disabled | Disabled |
| Tor | Off | Off | On |
| Bluetooth | On | On | Off |

**Normal** — for daily use. Encrypted DNS, MAC randomization, firewall active.
IP address is visible to websites you visit.

**Private** — for untrusted networks. Adds immediate MAC randomization, disables
IPv6, enforces browser AppArmor profiles. IP address still visible.

**Paranoid** — routes traffic through Tor, blocks most outgoing traffic, disables
Bluetooth. Significantly increases anonymity but is not a guarantee. Most
applications will not work — use Tor Browser. Not suitable for general daily use.

**Paranoid mode limitations:**
- Package updates will fail (apt cannot reach Debian mirrors)
- Email clients, most desktop apps, and VPNs will not work
- To update packages: switch to normal mode, update, switch back

---

### `atlazes clean`
Cleans temporary files, browser cache, and optionally bash history.

```bash
atlazes clean
```

Cleans: system cache, temporary files, trash, Firefox ESR cache/cookies/forms,
rotated logs. Prompts before clearing bash history.

---

### `atlazes dns`
Shows DNS configuration and runs a basic leak test.

```bash
atlazes dns
```

Shows: current `/etc/resolv.conf`, dnscrypt-proxy service status, DNS test result.

The DNS test queries `whoami.ds.akahelp.net` to show which resolver is responding.
This confirms dnscrypt-proxy is active but does not verify the resolver's
no-log policy.

---

### `atlazes tor <start|stop|status>`
Controls the Tor service.

```bash
sudo atlazes tor start    # Start Tor daemon
sudo atlazes tor stop     # Stop Tor daemon
sudo atlazes tor status   # Show Tor service status
```

When Tor is running, it provides a SOCKS5 proxy on `127.0.0.1:9050`.
Configure individual applications to use this proxy, or use Tor Browser
which is pre-configured for Tor.

For anonymous browsing, use Tor Browser rather than configuring a regular
browser to use the Tor proxy — regular browsers leak identifying information
that Tor Browser is specifically hardened against.

```bash
torbrowser-launcher    # Download and launch Tor Browser
```

---

## System Commands

### `atlazes update`
Updates all system packages.

```bash
sudo atlazes update
```

Runs: `apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y && apt-get autoremove -y`

---

### `atlazes info`
Shows system information.

```bash
atlazes info
```

---

## AppArmor Management

```bash
# Show all profile states
sudo /usr/local/sbin/apparmor-manage.sh status

# Enforce stable profiles, complain for others (default)
sudo /usr/local/sbin/apparmor-manage.sh strict

# Set all profiles to complain mode (logs but does not block)
sudo /usr/local/sbin/apparmor-manage.sh relaxed

# Enforce a specific profile
sudo /usr/local/sbin/apparmor-manage.sh enforce usr.bin.firefox-esr

# Set a specific profile to complain
sudo /usr/local/sbin/apparmor-manage.sh complain usr.bin.thunderbird
```

---

## Metadata Cleaning

Strip metadata from files before sharing. Metadata can include GPS coordinates,
author names, software versions, and editing history.

```bash
mat2 document.pdf          # Clean PDF metadata
mat2 photo.jpg             # Clean JPEG EXIF data (including GPS)
mat2 presentation.docx     # Clean Office metadata
mat2 --inplace video.mp4   # Clean video metadata in-place
mat2 --show document.pdf   # Show what metadata exists before cleaning
```

---

## File Deletion Notes

```bash
# On HDDs: shred overwrites file data before deletion
shred -vzu -n 3 sensitive-file.txt

# On SSDs and NVMe: shred does NOT reliably work
# Wear leveling and journaling mean data may persist elsewhere
# Use full-disk encryption (LUKS2) from the start instead

# Wipe entire drive (DESTRUCTIVE — use with caution)
sudo nwipe /dev/sdX
```

---

## Quick Reference

```
atlazes status          Security and privacy overview
atlazes scan            ClamAV malware scan
atlazes clean           Clean temp files and cache
sudo atlazes secure     Check and restore security services
atlazes sandbox <app>   Launch app in Firejail sandbox
sudo atlazes mode X     Switch privacy posture (normal/private/paranoid)
atlazes dns             Show DNS config and test
sudo atlazes tor start  Start Tor daemon
sudo atlazes update     Update system packages
atlazes info            System information
atlazes logs            Recent security log entries
atlazes help            Show all commands
```
