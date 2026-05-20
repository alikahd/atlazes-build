# ATLAZES OS - Maintenance & Update Guide

## Maintaining an Installed ATLAZES OS System

### Daily / Automatic

Automatic security updates are enabled by default via `unattended-upgrades`.
They run daily and install security patches without user intervention.

Check the log:
```bash
cat /var/log/unattended-upgrades/unattended-upgrades.log
```

---

### Manual System Update

```bash
# Full system update
sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y

# Or use the ATLAZES tools shortcut
atlazes-tools update
```

---

### Security Maintenance

#### Update ClamAV signatures (daily via cron)
```bash
sudo freshclam
```

#### Update rkhunter database
```bash
sudo rkhunter --update
sudo rkhunter --propupd  # update file properties database
```

#### Run security audit
```bash
sudo lynis audit system
```

#### Check file integrity (AIDE)
```bash
sudo aide --check
# If system was intentionally changed, update the database:
sudo aide --update
sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

#### Check firewall rules
```bash
sudo ufw status verbose
```

#### Check AppArmor status
```bash
sudo aa-status
```

---

### Privacy Maintenance

#### Update tracker blocklist
```bash
# Download latest StevenBlack hosts list
sudo bash -c 'grep -v "^0.0.0.0" /etc/hosts > /tmp/hosts.clean'
sudo bash -c 'curl -s https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts | grep "^0.0.0.0" >> /tmp/hosts.clean'
sudo cp /tmp/hosts.clean /etc/hosts
```

#### Clean temporary files
```bash
atlazes-tools clean
# Or manually:
sudo bleachbit --clean system.cache system.tmp system.trash
```

#### Strip metadata from files before sharing
```bash
mat2 document.pdf
mat2 photo.jpg
mat2 --inplace video.mp4
```

---

## Building a New Release

### Update the version

1. Edit `build.sh` — change `OS_VERSION`
2. Edit `config/hooks/0040-branding.hook.chroot` — update version strings
3. Edit `calamares/branding/atlazes/branding.desc` — update version
4. Update `README.md`

### Rebuild

```bash
sudo ./build.sh clean
sudo ./build.sh build
```

### Test before release

1. Test in VirtualBox (see test-guide.md)
2. Test on real hardware if possible
3. Verify all security features work
4. Test the installer end-to-end

### Release checklist

- [ ] Version number updated everywhere
- [ ] Changelog written
- [ ] ISO tested in VM
- [ ] ISO tested on real hardware
- [ ] SHA256 checksum generated
- [ ] GPG signature created
- [ ] Release notes written

### Sign the ISO

```bash
# Generate GPG key if you don't have one
gpg --full-generate-key

# Sign the ISO
gpg --armor --detach-sign output/atlazes-os-1.0.0-amd64.iso

# Verify
gpg --verify output/atlazes-os-1.0.0-amd64.iso.asc output/atlazes-os-1.0.0-amd64.iso
```

---

## Adding New Software

### Add to a package list (included in ISO)

Edit the appropriate file in `config/package-lists/` and rebuild.

### Add a new external repository

Create a hook in `config/hooks/` that adds the repo and installs the package:

```bash
#!/bin/bash
# Example: Add Signal Desktop
wget -qO- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor \
    > /usr/share/keyrings/signal-desktop-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] \
    https://updates.signal.org/desktop/apt xenial main" \
    > /etc/apt/sources.list.d/signal-xenial.list
apt-get update -qq
apt-get install -y signal-desktop
```

---

## Kernel Updates

When a new kernel is available:

```bash
# Check current kernel
uname -r

# Update
sudo apt update
sudo apt install linux-image-amd64 linux-headers-amd64

# Update initramfs
sudo update-initramfs -u -k all

# Update GRUB
sudo update-grub

# Reboot
sudo reboot
```

After reboot, verify the new kernel:
```bash
uname -r
# Re-apply hardening if needed
sudo /path/to/scripts/hardening/kernel-hardening.sh
```

---

## Backup Strategy

### System backup with rsync

```bash
sudo rsync -aAXv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} \
    / /mnt/backup/
```

### Encrypted backup with VeraCrypt

1. Create a VeraCrypt container
2. Mount it
3. Copy important files
4. Unmount and store securely

### Home directory backup

```bash
# Encrypted tar archive
tar czf - /home/username | gpg --symmetric --cipher-algo AES256 \
    -o /mnt/backup/home-$(date +%Y%m%d).tar.gz.gpg
```

---

## Reporting Issues

When reporting a bug or issue, include:

```bash
# System info
inxi -Fxz

# ATLAZES version
cat /etc/atlazes-release

# Kernel version
uname -a

# Relevant logs
sudo journalctl -xe --no-pager | tail -50
```
