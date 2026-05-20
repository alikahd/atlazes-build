# ATLAZES OS - Testing Guide (VirtualBox / VMware)

## Testing in VirtualBox

### Step 1: Create a New VM

1. Open VirtualBox → **New**
2. Settings:
   - **Name:** ATLAZES OS
   - **Type:** Linux
   - **Version:** Debian (64-bit)
   - **RAM:** 4096 MB (minimum 2048 MB)
   - **CPU:** 2 cores
   - **Storage:** 30 GB (dynamically allocated)
   - **Video Memory:** 128 MB
   - **Enable 3D Acceleration:** Yes (optional)

### Step 2: Configure VM for UEFI (optional)

1. VM Settings → **System** → **Motherboard**
2. Check **Enable EFI (special OSes only)**

### Step 3: Attach the ISO

1. VM Settings → **Storage**
2. Click the empty optical drive
3. Click the disk icon → **Choose a disk file**
4. Select `output/atlazes-os-1.0.0-amd64.iso`

### Step 4: Boot

1. Start the VM
2. Select **"ATLAZES OS - Live Session"** from GRUB menu
3. Wait for desktop to load (auto-login as `atlazes`)

### Step 5: Test Live Session

```bash
# Open terminal and run:
atlazes-tools status

# Expected output:
# Firewall (UFW):     ✓ Active
# AppArmor:           ✓ Active
# Encrypted DNS:      ✓ Active
# Fail2ban:           ✓ Active
```

### Step 6: Test Installation

1. Double-click **"Install ATLAZES OS"** on desktop
2. Follow Calamares installer:
   - Language → English
   - Location → Your timezone
   - Keyboard → Your layout
   - Partitions → **Erase disk** (check "Encrypt system")
   - Set encryption passphrase
   - Users → Create your account
   - Summary → **Install**
3. Wait for installation (~10 minutes in VM)
4. Reboot when prompted

---

## Testing in VMware Workstation / Player

### Step 1: Create VM

1. **File → New Virtual Machine**
2. Select **Custom (advanced)**
3. Hardware compatibility: Latest
4. **Installer disc image file (iso):** Select your ISO
5. Guest OS: **Linux → Debian 11.x 64-bit**
6. VM Name: ATLAZES OS
7. Processors: 2, Cores: 2
8. Memory: 4096 MB
9. Network: NAT
10. Disk: 30 GB, single file

### Step 2: Enable UEFI (optional)

Edit the `.vmx` file and add:
```
firmware = "efi"
```

### Step 3: Boot and Test

Same as VirtualBox steps above.

---

## Verification Checklist

After booting the live session, verify:

### Security
```bash
# Firewall active
sudo ufw status
# Expected: Status: active, Default: deny (incoming)

# AppArmor enforcing
sudo aa-status | head -5
# Expected: X profiles are in enforce mode

# Kernel hardening
sysctl kernel.kptr_restrict
# Expected: kernel.kptr_restrict = 2

sysctl net.ipv4.tcp_syncookies
# Expected: net.ipv4.tcp_syncookies = 1

# No unnecessary services
systemctl list-units --state=active --type=service | grep -E "avahi|whoopsie|apport"
# Expected: no output (these should be disabled)
```

### Privacy
```bash
# DNS encrypted
cat /etc/resolv.conf
# Expected: nameserver 127.0.0.1

systemctl status dnscrypt-proxy
# Expected: active (running)

# MAC randomization configured
cat /etc/NetworkManager/conf.d/99-atlazes-mac-random.conf
# Expected: wifi.cloned-mac-address=random

# Tracker blocking
grep -c "^0.0.0.0" /etc/hosts
# Expected: > 0 (tracker entries)
```

### Browser
```bash
# Firefox policies applied
cat /usr/lib/firefox-esr/distribution/policies.json | python3 -m json.tool | head -20
# Expected: DisableTelemetry: true, etc.
```

### Hardware
```bash
# Check hardware detection
inxi -Fxz
lspci
lsusb
```

---

## Performance Notes

- Live session in VM may be slower than bare metal
- For best performance, allocate 4+ GB RAM and 2+ CPU cores
- Enable VirtualBox Guest Additions or VMware Tools for better display/clipboard
- The installed system will be significantly faster than the live session

---

## Known VM Issues

| Issue | Solution |
|-------|----------|
| Black screen on boot | Add `nomodeset` to GRUB boot options |
| No network in VM | Check VM network adapter is set to NAT or Bridged |
| Slow display | Install guest additions / VMware tools |
| UEFI boot fails | Disable Secure Boot in VM settings |
| Low resolution | Set display to 1280x720 in VM settings |
