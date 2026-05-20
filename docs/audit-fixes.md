# ATLAZES OS - Audit & Fix Report

## Critical Bugs Fixed

### 1. DNS Broken (resolv.conf locked + wrong port)
**Problem:** `chattr +i /etc/resolv.conf` hard-locked the file. VPN clients, NetworkManager, and captive portal detection all need to write to this file. Additionally, dnscrypt-proxy was configured to listen on port 5300, but `/etc/resolv.conf` pointed to `127.0.0.1` (port 53) — DNS would silently fail.

**Fix:**
- Removed `chattr +i` from all scripts
- dnscrypt-proxy now listens on port 53 (standard)
- systemd-resolved stub listener disabled to avoid port conflict
- Added NM dispatcher script to restore DNS after VPN disconnect
- resolv.conf is writable but defaults to `127.0.0.1`

---

### 2. squashfs Blacklisted (breaks live boot)
**Problem:** `install squashfs /bin/false` in the module blacklist. The live ISO uses squashfs for the root filesystem. Blacklisting it makes the system unbootable.

**Fix:** Removed `squashfs` from the blacklist. Also removed `udf` (needed for DVDs) and `hfsplus` (needed to read macOS drives).

---

### 3. AppArmor Enforce-All (breaks apps)
**Problem:** `aa-enforce /etc/apparmor.d/*` enforces every profile including abstractions, tunables, and profiles for apps that have incomplete/broken profiles. This breaks Thunderbird, VLC, LibreOffice, and others.

**Fix:** Selective enforcement strategy:
- All profiles default to **complain mode** (logs but does not block)
- Only stable, well-tested profiles are **enforced**: Firefox, CUPS, evince, ping, tcpdump
- `scripts/hardening/apparmor-manage.sh` provides `strict`/`relaxed` toggle

---

### 4. Dangerous GRUB Kernel Parameters
**Problem:** Several boot parameters were either dangerous or broke usability:
- `nosmt=force` — disables all but one CPU core on every machine
- `lockdown=confidentiality` — breaks suspend, hibernate, and many drivers
- `oops=panic` — one kernel oops crashes the entire system
- `loglevel=0` — hides all kernel messages (impossible to debug)
- `mce=0` — disables machine check exceptions (dangerous on hardware errors)
- `module.sig_enforce=1` — breaks NVIDIA, VirtualBox, and any unsigned driver

**Fix:** Removed all six. Kept: `pti=on`, `spectre_v2=on`, `tsx=off`, `mds=full`, `init_on_alloc=1`, `page_alloc.shuffle=1`, `vsyscall=none`, `randomize_kstack_offset=on`.

---

### 5. Non-Existent Packages (build-breaking)
**Problem:** Several packages in the lists do not exist in Debian 12 Bookworm repos and would cause `lb build` to fail:

| Package | Issue | Fix |
|---------|-------|-----|
| `signal-desktop` | Not in Debian repos | Removed |
| `enigmail` | Merged into Thunderbird ≥78 | Removed |
| `i2p` | Not in Bookworm | Removed |
| `onionshare` | Not in Bookworm | Removed |
| `pdf-redact-tools` | Not in Bookworm | Removed |
| `network-manager-wireguard` | Not a real package | Removed (NM handles WG natively) |
| `objdump`, `readelf`, `strings` | Not standalone packages | Replaced with `binutils` |
| `exa` | Renamed to `eza` in Bookworm | Fixed |
| `yq` | Not in Debian repos | Removed |
| `tldr` | Use `tealdeer` package | Fixed |
| `exiftool` | Package is `libimage-exiftool-perl` | Fixed |
| `cloud-amd64` | Not a valid live-build kernel flavour | Removed from `--linux-flavours` |

---

### 6. /proc hidepid Without proc Group
**Problem:** `hidepid=2` was added to `/etc/fstab` without creating the `proc` group or adding users to it. This makes `ps`, `top`, `htop` show nothing for non-root users.

**Fix:** `groupadd -f proc` + `usermod -aG proc <user>` added to all relevant scripts.

---

### 7. StevenBlack Hosts Download During Build
**Problem:** The build hook tried to download 100,000+ hosts entries from GitHub during `lb build`. This fails if the build machine has no internet, and bloats the ISO with a massive hosts file.

**Fix:** Build hook uses a curated minimal list (~35 entries). Full StevenBlack list is downloaded by `post-install.sh` after installation when internet is available.

---

### 8. Dev Tools in Core ISO
**Problem:** Node.js, VSCodium, Docker, Wireshark, and 60+ dev packages were installed in the base ISO, adding ~2GB and unnecessary attack surface.

**Fix:** Edition system:
- `sudo ./build.sh` → **Core** (no dev tools, ~1.5GB ISO)
- `sudo ./build.sh --edition=dev` → **Dev** (includes all dev tools)
- `sudo ./build.sh --edition=security` → **Security** (extended security tools)

---

## Enhancements Added

### New `atlazes` CLI
Replaces `atlazes-tools` with a unified command:

```
atlazes status          # Full security + privacy status
atlazes scan [path]     # ClamAV scan
atlazes clean           # Privacy cleanup
atlazes secure          # Check and fix all security settings
atlazes sandbox <app>   # Launch app in Firejail
atlazes mode normal     # Balanced mode
atlazes mode private    # Enhanced privacy (MAC random, encrypted DNS, IPv6 off)
atlazes mode paranoid   # Maximum privacy (Tor, strict firewall)
atlazes tor start|stop  # Control Tor
atlazes dns             # Show DNS config
atlazes update          # System update
atlazes info            # System info
atlazes logs            # Security logs
```

### Privacy Modes
Three modes managed by `atlazes mode`:

| Feature | Normal | Private | Paranoid |
|---------|--------|---------|----------|
| Firewall | Deny incoming | Deny all incoming | Deny all, allow Tor+HTTPS only |
| DNS | dnscrypt-proxy | dnscrypt-proxy (forced) | Via Tor |
| MAC | Random per connection | Randomized now | Randomized now |
| IPv6 | Enabled | Disabled | Disabled |
| Tor | Off | Off | On |
| Bluetooth | On | On | Off |

### Firejail Auto-Sandboxing
- `firecfg` creates symlinks for automatic sandboxing
- Firefox ESR, Thunderbird, VLC auto-sandboxed via desktop file wrappers
- Custom Firefox ESR profile with home directory restrictions
- `atlazes sandbox <app>` for manual sandboxing

### AppArmor Management Script
`scripts/hardening/apparmor-manage.sh`:
- `strict` — enforce stable profiles, complain for others
- `relaxed` — all profiles in complain mode
- `enforce <profile>` — enforce specific profile
- `complain <profile>` — set specific profile to complain

---

## Files Changed

| File | Change |
|------|--------|
| `build.sh` | Edition support, fixed `--linux-flavours`, fixed LOG_FILE init |
| `config/package-lists/01-base.list.chroot` | Added microcode packages |
| `config/package-lists/03-security.list.chroot` | Removed non-existent packages, fixed names |
| `config/package-lists/04-privacy.list.chroot` | Removed signal/enigmail/i2p/onionshare |
| `config/package-lists/05-development.list.chroot` | Fixed exa→eza, removed yq/objdump/readelf |
| `config/package-lists/06-hardware.list.chroot` | Cleaned up duplicates |
| `config/hooks/0020-security-hardening.hook.chroot` | Fixed sysctl, AppArmor, GRUB params, /proc |
| `config/hooks/0030-privacy-config.hook.chroot` | Fixed DNS port, removed chattr+i, minimal hosts |
| `config/hooks/0035-firejail-setup.hook.chroot` | **NEW** — Firejail auto-sandbox setup |
| `config/hooks/0050-nodejs-vscode.hook.chroot` | Edition-aware (dev only) |
| `config/includes.chroot/etc/modprobe.d/atlazes-blacklist.conf` | Removed squashfs/udf/hfsplus |
| `config/includes.chroot/usr/local/bin/atlazes` | **NEW** — Full CLI with all commands |
| `config/includes.chroot/usr/local/bin/atlazes-tools` | Now a shim → atlazes |
| `scripts/hardening/apparmor-manage.sh` | **NEW** — AppArmor strict/relaxed toggle |
| `scripts/hardening/kernel-hardening.sh` | Removed dangerous GRUB params |
| `scripts/privacy/privacy-setup.sh` | Removed chattr+i, fixed hosts download |
| `scripts/post-install.sh` | Removed chattr+i, fixed AppArmor, proc group, AIDE timer |
