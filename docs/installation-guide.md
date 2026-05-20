# ATLAZES OS — Installation Guide

## Before You Begin

**Minimum requirements:**
- 64-bit CPU (Intel or AMD)
- 2 GB RAM (4 GB recommended)
- 20 GB free disk space (40 GB recommended)
- USB drive (4 GB minimum, 8 GB+ recommended)
- BIOS or UEFI firmware

**Backup your data first.** Installation will erase the target disk.

---

## Step 1: Download

Download the ISO from the official release page.

Verify the checksum before flashing:
```bash
sha256sum atlazes-os-1.0.0-core-amd64.iso
# Compare with the value in SHA256SUMS
```

---

## Step 2: Flash to USB

**Linux/macOS:**
```bash
# Find your USB device
lsblk
# Flash (replace /dev/sdX with your USB device)
sudo dd if=atlazes-os-1.0.0-core-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

**Windows:** Use [Balena Etcher](https://etcher.balena.io) or [Rufus](https://rufus.ie) (select DD mode).

**Multi-boot:** Use [Ventoy](https://ventoy.net) — copy the ISO to the Ventoy USB drive.

---

## Step 3: Boot from USB

1. Insert the USB drive
2. Restart your computer
3. Press the boot menu key during startup:

| Brand | Key |
|-------|-----|
| Dell | F12 |
| HP | F9 or Esc |
| Lenovo | F12 |
| ASUS | F8 or Esc |
| Acer | F12 |
| MSI | F11 |

4. Select your USB drive from the boot menu

**If UEFI Secure Boot blocks the USB:**
- Enter UEFI settings (F2, Del, or F10)
- Disable Secure Boot
- Save and exit

---

## Step 4: Try the Live Session

The GRUB menu offers:
- **ATLAZES OS - Live Session** — try without installing
- **ATLAZES OS - Live (Safe Mode)** — for hardware compatibility issues
- **ATLAZES OS - Install** — direct to installer
- **ATLAZES OS - Forensic Mode** — no disk mounts (for forensic use)

Select **Live Session** to try ATLAZES OS before installing.

Live session credentials:
- Username: `atlazes`
- Password: `atlazes`

---

## Step 5: Install

1. Double-click **"Install ATLAZES OS"** on the desktop
2. The Calamares installer will open

### Language & Location
- Select your language
- Select your timezone

### Keyboard
- Select your keyboard layout
- Test it in the text field

### Partitions

**Option A — Erase entire disk (recommended for new installs):**
1. Select "Erase disk"
2. Check "Encrypt system" for full disk encryption
3. Enter a strong passphrase (you will need this every boot)
4. Click Next

**Option B — Manual partitioning:**

For UEFI systems:
| Mount | Size | Type | Filesystem |
|-------|------|------|------------|
| /boot/efi | 512 MB | EFI System | FAT32 |
| / | 20 GB+ | Linux | ext4 |
| swap | 2–4 GB | Linux swap | swap |

For BIOS systems:
| Mount | Size | Type | Filesystem |
|-------|------|------|------------|
| / | 20 GB+ | Linux | ext4 |
| swap | 2–4 GB | Linux swap | swap |

### Users
- Enter your full name
- Choose a username (lowercase, no spaces)
- Set a strong password
- Set the same password for root (or a different one)

### Summary
- Review all settings
- Click **Install**

### Installation
- Takes 10–20 minutes
- Watch the slideshow
- Do not power off

### Finish
- Click **Restart Now**
- Remove the USB drive when prompted

---

## Step 6: First Boot

1. If you enabled encryption: enter your passphrase at the LUKS prompt
2. The LightDM login screen appears
3. Enter your username and password
4. XFCE4 desktop loads

---

## Step 7: Post-Installation Setup

Open a terminal and run:
```bash
sudo ./post-install.sh
```

This will:
- Update all packages
- Enable automatic security updates
- Configure encrypted DNS
- Update the tracker blocklist (requires internet)
- Initialize AIDE file integrity database
- Configure ClamAV signatures

After it completes:
```bash
sudo reboot
```

---

## Step 8: Verify Security Status

After reboot:
```bash
atlazes status
```

This shows the active/inactive state of each security component. Green checkmarks
indicate the service is running. Note that "all green" means services are active —
it does not mean you are anonymous or fully protected. See
[docs/security-transparency.md](security-transparency.md) for what ATLAZES OS
does and does not protect against.

---

## Troubleshooting Installation

**Black screen after boot:**
- Reboot and select "Safe Mode" from GRUB
- This uses `nomodeset` which disables GPU acceleration

**WiFi not detected:**
- Most WiFi adapters work out of the box (firmware included)
- For Broadcom: `sudo apt install firmware-b43-installer`
- For some Intel: `sudo apt install firmware-iwlwifi`

**LUKS passphrase not accepted:**
- Check keyboard layout (may differ at LUKS prompt vs desktop)
- Try typing slowly

**Installer crashes:**
- Check RAM: minimum 2 GB required
- Try Safe Mode boot
- Check `~/.local/share/calamares/session.log`

**No boot after install:**
- Boot from USB, select "Boot from Hard Drive"
- Or reinstall GRUB: `sudo grub-install /dev/sda && sudo update-grub`
