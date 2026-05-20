# ATLAZES OS - Build Guide

## Prerequisites

You need a **Debian 12 (Bookworm)** or **Ubuntu 22.04/24.04** host system to build ATLAZES OS.
Building inside a VM is fine. Minimum 20 GB free disk space, 4 GB RAM recommended.

---

## Step 1: Install Build Dependencies

```bash
sudo apt update
sudo apt install -y \
  live-build \
  debootstrap \
  squashfs-tools \
  xorriso \
  isolinux \
  syslinux-efi \
  grub-pc-bin \
  grub-efi-amd64-bin \
  mtools \
  dosfstools \
  git \
  curl \
  wget \
  rsync
```

---

## Step 2: Clone the Repository

```bash
git clone https://github.com/yourusername/atlazes-os.git
cd atlazes-os
```

---

## Step 3: Run the Build

```bash
chmod +x build.sh
sudo ./build.sh
```

The build process:
1. Initializes live-build with Debian Bookworm base
2. Copies all package lists and configuration
3. Runs `lb build` which:
   - Bootstraps a minimal Debian system
   - Installs all packages from the lists
   - Runs all hooks (security hardening, privacy config, branding)
   - Assembles the squashfs filesystem
   - Creates the bootable ISO

**Expected time:** 20–60 minutes depending on internet speed and CPU.

---

## Step 4: Find the ISO

```bash
ls -lh output/
# atlazes-os-1.0.0-amd64.iso
# atlazes-os-1.0.0-amd64.iso.sha256
```

---

## Build Options

```bash
# Full build (default)
sudo ./build.sh build

# Clean previous build
sudo ./build.sh clean

# Install dependencies only
sudo ./build.sh deps
```

---

## Customizing the Build

### Add/Remove Packages

Edit files in `config/package-lists/`:
- `01-base.list.chroot` — Core system
- `02-desktop.list.chroot` — Desktop environment
- `03-security.list.chroot` — Security tools
- `04-privacy.list.chroot` — Privacy tools
- `05-development.list.chroot` — Developer tools
- `06-hardware.list.chroot` — Hardware support

### Modify Security Settings

Edit `config/hooks/0020-security-hardening.hook.chroot`

### Modify Privacy Settings

Edit `config/hooks/0030-privacy-config.hook.chroot`

### Change Branding

Edit `config/hooks/0040-branding.hook.chroot`

---

## Troubleshooting

### Build fails with "debootstrap error"

```bash
# Check internet connectivity
ping -c 3 deb.debian.org

# Try a different mirror in build.sh
MIRROR="http://ftp.us.debian.org/debian"
```

### "No space left on device"

```bash
# Check disk space
df -h
# Need at least 15 GB free in /tmp or build directory
```

### Package not found

```bash
# Check if package exists
apt-cache search <package-name>
# Remove it from the package list if unavailable
```

### Clean and retry

```bash
sudo ./build.sh clean
sudo ./build.sh build
```

---

## Build on Ubuntu

If building on Ubuntu, you may need to add the Debian Bookworm keyring:

```bash
sudo apt install debian-archive-keyring
```

And set the mirror in `build.sh` to a Debian mirror (not Ubuntu).
