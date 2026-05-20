# ATLAZES OS — Troubleshooting Guide

---

## Boot Issues

### Black screen after selecting Live Session
**Cause:** GPU driver incompatibility (common with NVIDIA)

**Fix:**
1. Reboot and select **"ATLAZES OS - Live (Safe Mode)"** from GRUB
2. This adds `nomodeset` which disables GPU acceleration
3. After booting, install the correct driver:
   ```bash
   # For NVIDIA (proprietary)
   sudo apt install nvidia-driver
   # For AMD (open source, usually works without nomodeset)
   sudo apt install firmware-amd-graphics
   ```

---

### GRUB menu doesn't appear
**Cause:** Fast boot or wrong boot device

**Fix:**
- Hold `Shift` during boot (BIOS) or `Esc` (UEFI) to force GRUB menu
- In UEFI settings, disable "Fast Boot"
- Ensure USB is first in boot order

---

### System boots to GRUB rescue prompt
**Cause:** GRUB can't find the filesystem

**Fix:**
```bash
# At grub rescue prompt:
ls                          # List partitions
ls (hd0,gpt2)/              # Check if this has /boot
set root=(hd0,gpt2)
set prefix=(hd0,gpt2)/boot/grub
insmod normal
normal
# Then reinstall GRUB after booting
sudo grub-install /dev/sda
sudo update-grub
```

---

### LUKS passphrase not accepted
**Cause:** Keyboard layout at LUKS prompt may differ from desktop

**Fix:**
- Try typing slowly
- Check if Caps Lock is on
- The LUKS prompt uses US keyboard layout by default
- To fix permanently: `sudo dpkg-reconfigure keyboard-configuration`

---

## Network Issues

### WiFi not detected
**Cause:** Missing firmware

**Fix:**
```bash
# Check what WiFi adapter you have
lspci | grep -i wireless
lsusb | grep -i wireless

# Install firmware for common adapters
sudo apt install firmware-iwlwifi        # Intel WiFi
sudo apt install firmware-atheros        # Atheros
sudo apt install firmware-realtek        # Realtek
sudo apt install firmware-brcm80211      # Broadcom
sudo apt install firmware-b43-installer  # Broadcom b43

# Reload the driver
sudo modprobe -r iwlwifi && sudo modprobe iwlwifi
```

---

### DNS not resolving
**Cause:** dnscrypt-proxy not running or port conflict

**Diagnose:**
```bash
systemctl status dnscrypt-proxy
ss -ulnp | grep :53
cat /etc/resolv.conf
```

**Fix:**
```bash
# Restart dnscrypt-proxy
sudo systemctl restart dnscrypt-proxy

# If port 53 is taken by systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
sudo systemctl restart dnscrypt-proxy

# Test DNS
dig +short google.com
```

---

### VPN breaks DNS after disconnect
**Cause:** VPN client overwrote resolv.conf and didn't restore it

**Fix:**
```bash
# Restore encrypted DNS
cat > /etc/resolv.conf << 'EOF'
nameserver 127.0.0.1
options edns0 trust-ad
EOF
sudo systemctl restart dnscrypt-proxy
```

---

### Captive portal (hotel/airport WiFi) not working
**Cause:** dnscrypt-proxy blocks the captive portal redirect

**Fix:**
```bash
# Temporarily stop dnscrypt-proxy
sudo systemctl stop dnscrypt-proxy

# Connect to the captive portal in browser
# After login, restart dnscrypt-proxy
sudo systemctl start dnscrypt-proxy
```

---

## Security Tool Issues

### AppArmor breaking an application
**Symptom:** App crashes or behaves strangely

**Diagnose:**
```bash
sudo dmesg | grep -i apparmor | tail -20
sudo journalctl -xe | grep apparmor | tail -20
sudo aa-status | grep <appname>
```

**Fix:**
```bash
# Set the app's profile to complain mode (logs but doesn't block)
sudo aa-complain /etc/apparmor.d/usr.bin.<appname>

# Or use the management script
sudo /path/to/scripts/hardening/apparmor-manage.sh complain usr.bin.<appname>
```

---

### UFW blocking legitimate traffic
**Diagnose:**
```bash
sudo ufw status verbose
sudo tail -20 /var/log/ufw.log
```

**Fix:**
```bash
# Allow a specific port
sudo ufw allow 8080/tcp

# Allow a specific application
sudo ufw allow 'Nginx HTTP'

# Allow from a specific IP
sudo ufw allow from 192.168.1.100

# Check what's being blocked
sudo journalctl -k | grep UFW | tail -20
```

---

### Firejail breaking an application
**Symptom:** App won't start or missing features when sandboxed

**Fix:**
```bash
# Run without sandbox to confirm it's Firejail
/usr/bin/firefox  # Direct path, bypasses Firejail symlink

# Or use a less restrictive profile
firejail --noprofile firefox

# Check Firejail output
firejail --debug firefox 2>&1 | head -50
```

---

## Performance Issues

### High RAM usage at idle (>800MB)
**Diagnose:**
```bash
free -m
ps aux --sort=-%mem | head -15
systemctl list-units --state=active --type=service
```

**Fix:**
```bash
# Run the optimization script
sudo ./scripts/optimize-boot.sh

# Disable unused services
sudo systemctl disable <service-name>

# Check for memory leaks
sudo smem -r | head -10
```

---

### Slow boot time (>45 seconds in VM)
**Diagnose:**
```bash
systemd-analyze
systemd-analyze blame | head -15
systemd-analyze critical-chain
```

**Fix:**
```bash
sudo ./scripts/optimize-boot.sh
```

---

### Firefox slow to start
**Cause:** Firejail sandbox startup overhead

**Fix:**
```bash
# Check if Firejail is adding delay
time firejail firefox &
time /usr/bin/firefox &

# If Firejail is the cause, use a lighter profile
# Edit /etc/firejail/firefox-esr.profile
```

---

## Display Issues

### Wrong screen resolution
**Fix:**
```bash
# List available resolutions
xrandr

# Set resolution
xrandr --output HDMI-1 --mode 1920x1080

# Make permanent: add to ~/.config/autostart/
```

---

### External monitor not detected
**Fix:**
```bash
# Check if monitor is seen
xrandr --query

# Force detection
xrandr --auto

# For NVIDIA (if using nouveau)
sudo apt install xserver-xorg-video-nouveau
```

---

## Installer Issues

### Calamares crashes during partitioning
**Fix:**
- Ensure target disk has no mounted partitions: `sudo umount /dev/sdX*`
- Check disk health: `sudo smartctl -a /dev/sdX`
- Try manual partitioning instead of automatic

---

### Installation fails with "Failed to install bootloader"
**Fix:**
```bash
# After failed install, boot live session
# Mount the installed system
sudo mount /dev/sdX2 /mnt
sudo mount /dev/sdX1 /mnt/boot/efi  # UEFI only
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys
sudo chroot /mnt

# Reinstall GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi  # UEFI
# or
grub-install /dev/sdX  # BIOS
update-grub
exit
sudo reboot
```

---

## Getting More Help

```bash
# System logs
journalctl -xe --no-pager | tail -50

# Hardware info
inxi -Fxz

# ATLAZES version
cat /etc/atlazes-release

# Run QA validation
bash /path/to/scripts/qa-validate.sh

# Security audit
sudo lynis audit system 2>/dev/null | tail -30
```
