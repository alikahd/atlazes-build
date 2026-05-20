# ATLAZES OS — Security Transparency

---

## What ATLAZES OS Protects Against

**Passive DNS surveillance**
DNS queries are encrypted in transit using dnscrypt-proxy. A passive observer on your
local network or at your ISP cannot read which domains you look up.

**OS-level telemetry**
All background reporting is disabled: popularity-contest, apport crash reporting,
whoopsie, and Mozilla telemetry. No data is sent from the OS itself.

**Browser telemetry**
Firefox ESR is configured via policy to disable all telemetry, studies, Pocket,
and sponsored content. uBlock Origin is pre-installed.

**Local network device tracking**
MAC address randomization changes your device's local network identifier per
connection, reducing the ability of local networks to profile your device across visits.

**Application-level exploits reaching sensitive files**
Firejail sandboxes Firefox, Thunderbird, and VLC using Linux namespaces and seccomp
filtering. AppArmor enforces access restrictions for Firefox and CUPS.

**Data at rest on a powered-off device**
LUKS2 full-disk encryption (optional, chosen during installation) makes stored data
unreadable without the passphrase.

**Common malware and rootkits**
ClamAV provides signature-based malware detection. rkhunter checks for known rootkit
indicators. Neither tool prevents infection — they detect it.

**File tampering**
AIDE monitors file integrity and reports changes. It detects tampering after the fact.

**Brute-force login attacks**
Fail2ban blocks repeated failed authentication attempts.

**Kernel information leaks**
sysctl hardening restricts kernel pointer exposure, dmesg access, and BPF usage
by unprivileged users.

**Unnecessary attack surface**
Unused kernel modules (uncommon network protocols, Firewire) are blacklisted.
Unnecessary services are disabled at boot.

---

## What ATLAZES OS Does Not Protect Against

**Your public IP address**
Every website, server, and service you connect to sees your real IP address.
ATLAZES OS does not hide your IP. Use a VPN or Tor for IP-level privacy.

**IP-to-domain correlation by your ISP**
DNS queries are encrypted, but your ISP observes the IP addresses you connect to.
Reverse DNS and BGP routing tables make IP-to-domain mapping straightforward for
most major services.

**TLS SNI leakage**
Without Encrypted Client Hello (ECH), the hostname is visible in the TLS ClientHello
to network observers. ECH is not configured in this release.

**DNS resolver observation**
Quad9 and Cloudflare receive your DNS queries in plaintext on their end. Their
no-log policies are contractual commitments, not technical guarantees. Both are
US-based entities subject to US law and legal process.

**Browser fingerprinting**
Even without cookies, websites can identify your browser by its configuration,
fonts, screen resolution, and other characteristics. `privacy.resistFingerprinting`
in Firefox reduces but does not eliminate this.

**Kernel exploits**
Kernel hardening raises the bar for exploitation but does not prevent attacks
against unknown kernel vulnerabilities.

**Firejail escape via kernel vulnerabilities**
Firejail uses Linux namespaces and seccomp. A sufficiently privileged kernel exploit
can escape this sandbox. Firejail is not equivalent to VM or container isolation.

**Physical access to a running, unlocked machine**
LUKS2 protects data at rest. It does not protect a machine that is powered on
and logged in.

**Targeted attacks by well-resourced adversaries**
ATLAZES OS is not designed to protect against nation-state actors, targeted
surveillance, or advanced persistent threats.

**User behavior**
Logging into personal accounts, reusing passwords, clicking phishing links, and
installing untrusted software are not technical problems that an OS can solve.

**Supply chain attacks**
ATLAZES OS uses Debian packages and trusts the Debian signing infrastructure.
Individual packages are not independently audited.

**Secure file deletion on SSDs**
`shred` does not reliably overwrite all copies of data on SSDs, NVMe drives,
or filesystems with journaling or copy-on-write (ext4, btrfs). For SSDs, use
full-disk encryption from the start — encrypted data is effectively unrecoverable
without the key even without explicit wiping.

---

## Privacy vs Anonymity

These are different properties. ATLAZES OS provides privacy tools, not anonymity.

**Privacy** means reducing what others can observe about your activity.
ATLAZES OS reduces passive surveillance through encrypted DNS, MAC randomization,
and telemetry removal.

**Anonymity** means being unidentifiable even to a determined observer.
ATLAZES OS does not provide anonymity. Your IP address is visible. Your accounts
identify you. Your browser can be fingerprinted.

**Paranoid mode** routes traffic through Tor, which significantly increases
anonymity. Tor has known limitations: traffic correlation attacks, malicious exit
nodes, and timing analysis. Paranoid mode is not equivalent to using Tails OS.

If you need strong anonymity: use **Tails OS**, which leaves no trace on the
machine and routes all traffic through Tor by default.

---

## DNS Trust Model

**What is encrypted:**
DNS queries between your machine and the resolver are encrypted using DNSCrypt
or DNS-over-HTTPS. Passive interception by your ISP or local network is prevented.

**What is not encrypted:**
The resolver (Quad9 or Cloudflare) receives your queries in plaintext. You are
trusting their published no-log policies.

**Resolver trust:**
Quad9 (9.9.9.9) is operated by the Quad9 Foundation, a Swiss non-profit.
Cloudflare (1.1.1.1) is a US commercial company. Both publish no-log policies.
These are contractual commitments audited periodically, not technical guarantees.

**Changing resolvers:**
Edit `/etc/dnscrypt-proxy/dnscrypt-proxy.toml` and change `server_names`.
The full resolver list is at https://dnscrypt.info/public-servers

**Disabling dnscrypt-proxy:**
```bash
sudo systemctl stop dnscrypt-proxy
sudo systemctl disable dnscrypt-proxy
```
NetworkManager will then manage DNS using your network's default settings.

---

## Sandboxing Limitations

**Firejail** uses Linux namespaces and seccomp filtering to restrict application
access to the filesystem and system calls. This reduces the impact of
application-level exploits.

Firejail is not:
- Docker or Podman container isolation
- Virtual machine isolation
- Hardware-enforced separation

A kernel exploit can escape Firejail. AppArmor profiles add a second layer but
are also bypassable via kernel vulnerabilities.

**AppArmor** enforces access restrictions for Firefox and CUPS. Other profiles
run in complain mode (logging only, no blocking). Complain mode does not restrict
application behavior.

---

## Reproducible Builds

The build configuration, hooks, and package lists are fully open source and
documented. Anyone can inspect and reproduce the build environment.

**Current status:** Builds are not bit-for-bit reproducible by default.
Two builds from the same source on different days will produce different SHA256
hashes because:
- Debian package versions change as the mirror updates
- Build timestamps are embedded in the squashfs filesystem
- Package metadata includes installation timestamps

**What you can verify:**
- The build configuration matches what we publish
- The package lists contain what we claim
- The hooks apply the settings we document

**Planned:** Pinned package versions for reproducible builds in a future release.

---

## Threat Model

ATLAZES OS is designed for users facing:
- Passive commercial surveillance (ISPs, advertisers, data brokers)
- Opportunistic malware and phishing
- Local network monitoring (public WiFi, corporate networks)
- Physical theft of a powered-off device

ATLAZES OS is not designed for users facing:
- Targeted government surveillance
- Physical coercion or legal compulsion
- Advanced persistent threats (APT)
- Situations requiring strong anonymity

---

## Open Source

Build scripts, hooks, and configuration: MIT License
Source: https://github.com/atlazes-os/atlazes-os

All included packages are open source. Package licenses are available via
`dpkg -L <package>` and the Debian package tracker.

---

## Security Reports

Found a vulnerability? Report responsibly.
Email: security@atlazes.os

We commit to:
- Acknowledge within 48 hours
- Fix critical issues within 7 days
- Credit reporters unless they prefer anonymity
