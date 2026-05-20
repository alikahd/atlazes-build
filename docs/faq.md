# ATLAZES OS — Frequently Asked Questions

---

## General

**Q: What is ATLAZES OS?**
A: ATLAZES OS is a Debian 12-based Linux distribution that reduces passive surveillance, disables telemetry, encrypts DNS queries, and hardens the system against common threats. It is a privacy-focused daily driver — not an anonymity system. Your IP address remains visible to websites you visit.

---

**Q: Is ATLAZES OS legal to use?**
A: Yes. ATLAZES OS is designed for legitimate privacy, security research, and data protection. It must not be used for illegal activities. All included tools are open-source and legal.

---

**Q: Which edition should I choose?**

| Edition | Who it's for |
|---------|-------------|
| **Core** | Most users — privacy and security tools, no dev bloat |
| **Dev** | Developers — adds Node.js, VSCodium, Docker, Python tools |
| **Security** | Security professionals — adds extended auditing tools |

Start with Core. You can install additional packages later with `sudo apt install`.

---

**Q: How is ATLAZES OS different from Tails, Kali, or Ubuntu?**

- **Tails**: Amnesic (no persistence), all traffic through Tor, designed for strong anonymity. ATLAZES OS is a persistent daily driver with weaker anonymity but better usability.
- **Kali Linux**: Penetration testing toolkit, not a daily driver. ATLAZES OS is not for offensive security work.
- **Ubuntu**: General-purpose OS with telemetry enabled by default. ATLAZES OS disables all telemetry and adds privacy and security hardening.

---

**Q: Can I install ATLAZES OS alongside Windows (dual boot)?**
A: Yes. During installation, choose "Manual partitioning" and create a separate partition for ATLAZES OS. GRUB will detect Windows and add it to the boot menu. Back up your data first.

---

**Q: Does ATLAZES OS support 32-bit systems?**
A: No. ATLAZES OS is 64-bit (amd64) only.

---

## Privacy & Security

**Q: Does ATLAZES OS send any data to anyone?**
A: All OS-level telemetry is disabled: Mozilla telemetry, popularity-contest, apport crash reporting, and whoopsie are turned off. DNS queries are sent to Quad9 and Cloudflare — both with published no-log policies. ClamAV downloads signature updates from ClamAV servers (only the update request is sent, no file data).

---

**Q: Is my DNS traffic private?**
A: DNS queries are encrypted in transit using dnscrypt-proxy, which prevents passive interception by your ISP or local network. However, the DNS resolver (Quad9 or Cloudflare) receives your queries in plaintext on their end — you are trusting their published no-log policies. Your ISP can still observe the IP addresses you connect to. TLS SNI may also reveal hostnames to network observers.

---

**Q: Can I change the DNS resolver?**
A: Yes. Edit `/etc/dnscrypt-proxy/dnscrypt-proxy.toml` and change the `server_names` list. The full list of available resolvers is at https://dnscrypt.info/public-servers. You can also disable dnscrypt-proxy entirely:
```bash
sudo systemctl stop dnscrypt-proxy
sudo systemctl disable dnscrypt-proxy
```

---

**Q: What happens to DNS when I use a VPN?**
A: The VPN client will temporarily update `/etc/resolv.conf` to use the VPN's DNS. When you disconnect, a NetworkManager dispatcher script automatically restores dnscrypt-proxy as the DNS resolver.

---

**Q: What is the difference between the three privacy modes?**

| Feature | Normal | Private | Paranoid |
|---------|--------|---------|----------|
| Firewall | Deny incoming | Deny all incoming | Deny all, Tor+HTTPS only |
| DNS | Encrypted (dnscrypt-proxy) | Encrypted (forced) | Via Tor |
| MAC | Random per connection | Randomized immediately | Randomized immediately |
| IPv6 | Enabled | Disabled | Disabled |
| Tor | Off | Off | On |
| Bluetooth | On | On | Off |

**Normal**: For daily use. Encrypted DNS, MAC randomization, firewall active. IP address visible to websites.

**Private**: For untrusted networks. Adds immediate MAC randomization, disables IPv6, enforces browser AppArmor profiles. IP address still visible.

**Paranoid**: Routes traffic through Tor. Blocks most outgoing traffic. Most applications will not work — use Tor Browser. Not suitable for general daily use.

Switch with: `sudo atlazes mode <normal|private|paranoid>`

---

**Q: Does Paranoid mode make me anonymous?**
A: Paranoid mode routes traffic through Tor, which significantly increases anonymity. It does not guarantee anonymity. Tor has known limitations including traffic correlation attacks, malicious exit nodes, and timing analysis. For strong anonymity, use Tails OS.

---

**Q: What breaks in Paranoid mode?**
A: Most applications that are not configured to use Tor will fail because outgoing traffic is blocked except for Tor ports and HTTPS. Package updates, email clients, and most desktop apps will not work. To update packages, switch to normal mode first:
```bash
sudo atlazes mode normal
sudo atlazes update
sudo atlazes mode paranoid
```

---

**Q: Is full disk encryption enabled by default?**
A: No — you choose during installation. Select "Encrypt system" in the Calamares partitioning step. This uses LUKS2 encryption. You will need to enter your passphrase every time you boot.

---

**Q: Does AppArmor break applications?**
A: ATLAZES OS uses selective enforcement — only stable, well-tested profiles are enforced (Firefox, CUPS). All other profiles run in complain mode, which logs violations but does not block anything. If an app behaves strangely, check AppArmor logs:
```bash
sudo journalctl -xe | grep apparmor | tail -20
```
To set a profile to complain mode: `sudo aa-complain /etc/apparmor.d/usr.bin.<appname>`

---

**Q: What does Firejail do, and what are its limits?**
A: Firejail sandboxes applications using Linux namespaces and seccomp filtering, restricting their access to the filesystem and system calls. Firefox, Thunderbird, and VLC are sandboxed automatically. Firejail is not equivalent to container or VM isolation — a kernel exploit can escape it. It reduces the impact of application-level exploits, not kernel-level attacks.

---

**Q: Does shred work on SSDs?**
A: No. `shred` does not reliably overwrite all copies of data on SSDs, NVMe drives, or filesystems with journaling or copy-on-write. For SSDs, use full-disk encryption (LUKS2) from the start — encrypted data is effectively unrecoverable without the key even without explicit wiping.

---

## Hardware

**Q: Will my WiFi work?**
A: Most WiFi adapters work out of the box. ATLAZES OS includes firmware for Intel (iwlwifi), Atheros, Realtek, and Broadcom adapters. If your adapter is not detected, see the troubleshooting guide.

---

**Q: Will NVIDIA graphics work?**
A: The open-source `nouveau` driver is included and works for basic desktop use. For gaming or GPU compute, install the proprietary NVIDIA driver after installation:
```bash
sudo apt install nvidia-driver
```

---

**Q: Does ATLAZES OS work on a laptop with 4GB RAM?**
A: Yes. ATLAZES OS uses less than 800MB RAM at idle with XFCE4.

---

**Q: Does suspend/hibernate work?**
A: Suspend works on most hardware. Hibernate requires a swap partition at least as large as your RAM. ATLAZES OS does not use `lockdown=confidentiality` which would break suspend on many systems.

---

## Software

**Q: Can I install software from the Debian repositories?**
A: Yes. ATLAZES OS is based on Debian 12 (Bookworm). All Debian packages are available:
```bash
sudo apt install <package-name>
```

---

**Q: Can I install Flatpak or Snap apps?**
A: Flatpak works. Install it with `sudo apt install flatpak`. Snap is not pre-installed but can be added. Both require `kernel.unprivileged_userns_clone=1`, which is already set in ATLAZES OS.

---

**Q: Where is Signal Desktop?**
A: Signal is not in Debian repositories. Install it from Signal's official repository:
```bash
wget -qO- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor | \
  sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] \
  https://updates.signal.org/desktop/apt xenial main" | \
  sudo tee /etc/apt/sources.list.d/signal-xenial.list
sudo apt update && sudo apt install signal-desktop
```

---

**Q: How do I install VeraCrypt?**
A: VeraCrypt is not in Debian repositories. Download from [veracrypt.fr](https://veracrypt.fr) and install the `.deb` package:
```bash
sudo dpkg -i veracrypt-*.deb
```

---

## Updates & Maintenance

**Q: How do I update ATLAZES OS?**
A: Security updates are applied automatically via unattended-upgrades. For full updates:
```bash
sudo atlazes update
```

---

**Q: Are builds reproducible?**
A: The build configuration is fully open source. However, two builds from the same source on different days will produce different SHA256 hashes due to Debian package updates and build timestamps. We publish checksums for official releases. Bit-for-bit reproducibility with pinned packages is planned for a future release.

---

**Q: How do I report a bug?**
A: Open an issue at the project repository with:
- ATLAZES OS version: `cat /etc/atlazes-release`
- Kernel version: `uname -r`
- Hardware info: `inxi -Fxz`
- Relevant logs: `journalctl -xe | tail -50`
