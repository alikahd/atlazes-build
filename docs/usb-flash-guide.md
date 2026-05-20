# ATLAZES OS - USB Flash Guide

## Method 1: dd (Linux/macOS) — Recommended

### Find your USB drive

```bash
# List all drives
lsblk

# Or use
sudo fdisk -l

# Example output:
# /dev/sda  — your hard drive (DO NOT USE)
# /dev/sdb  — your USB drive (use this)
```

> ⚠️ **WARNING:** Double-check the device name. Writing to the wrong device will destroy data.

### Flash the ISO

```bash
# Replace /dev/sdX with your actual USB device (e.g., /dev/sdb)
sudo dd if=output/atlazes-os-1.0.0-amd64.iso \
        of=/dev/sdX \
        bs=4M \
        status=progress \
        oflag=sync

# Wait for completion (may take 5-15 minutes)
# Then safely eject:
sudo eject /dev/sdX
```

### Verify the flash

```bash
# Compare checksums
sha256sum output/atlazes-os-1.0.0-amd64.iso
sha256sum /dev/sdX | head -c 64
# First 64 characters should match
```

---

## Method 2: Balena Etcher (GUI — Windows/macOS/Linux)

1. Download from: https://etcher.balena.io
2. Open Etcher
3. **Flash from file** → Select `atlazes-os-1.0.0-amd64.iso`
4. **Select target** → Select your USB drive
5. **Flash!**
6. Wait for flashing and verification to complete

---

## Method 3: Ventoy (Multi-boot USB)

Ventoy lets you put multiple ISOs on one USB drive.

```bash
# Install Ventoy on USB (replace /dev/sdX)
wget https://github.com/ventoy/Ventoy/releases/latest/download/ventoy-linux.tar.gz
tar xf ventoy-linux.tar.gz
cd ventoy-*/
sudo ./Ventoy2Disk.sh -i /dev/sdX

# Then simply copy the ISO to the USB drive
cp output/atlazes-os-1.0.0-amd64.iso /media/username/Ventoy/
```

---

## Method 4: Rufus (Windows)

1. Download Rufus from: https://rufus.ie
2. Open Rufus (run as Administrator)
3. **Device:** Select your USB drive
4. **Boot selection:** Select `atlazes-os-1.0.0-amd64.iso`
5. **Partition scheme:**
   - For UEFI systems: **GPT**
   - For BIOS/legacy: **MBR**
6. **File system:** FAT32
7. Click **START**
8. If asked about ISO mode vs DD mode, select **DD Image mode**

---

## Booting from USB

### BIOS/UEFI Boot Menu

Most computers use one of these keys to open the boot menu:

| Manufacturer | Boot Menu Key |
|-------------|---------------|
| Dell        | F12           |
| HP          | F9 or Esc     |
| Lenovo      | F12 or F11    |
| ASUS        | F8 or Esc     |
| Acer        | F12           |
| MSI         | F11           |
| Gigabyte    | F12           |
| ASRock      | F11           |
| Apple Mac   | Option (⌥)    |

1. Insert USB drive
2. Restart computer
3. Press the boot menu key repeatedly during startup
4. Select your USB drive from the list
5. ATLAZES OS GRUB menu will appear

### If UEFI Secure Boot blocks the USB

1. Enter UEFI settings (usually F2, Del, or F10 during startup)
2. Find **Secure Boot** setting
3. Set to **Disabled**
4. Save and exit
5. Try booting again

---

## USB Persistence Mode

Persistence allows you to save changes between live sessions.

### Create a persistence partition

After flashing with `dd`, add a persistence partition:

```bash
# Check current USB partition layout
sudo fdisk -l /dev/sdX

# Create persistence partition with GParted or fdisk
# Label it "persistence" (ext4 filesystem)

# Create persistence.conf
sudo mkdir -p /mnt/persistence
sudo mount /dev/sdX3 /mnt/persistence  # adjust partition number
echo "/ union" | sudo tee /mnt/persistence/persistence.conf
sudo umount /mnt/persistence
```

### Boot with persistence

In the GRUB menu, select **"ATLAZES OS - Live Session"** and add `persistence` to the boot parameters, or edit the GRUB entry with `e` and add `persistence` to the linux line.

---

## Minimum USB Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| Capacity    | 4 GB    | 16 GB+      |
| Speed       | USB 2.0 | USB 3.0+    |
| Type        | Any     | USB 3.1 Gen1|

A faster USB drive significantly improves live session performance.
