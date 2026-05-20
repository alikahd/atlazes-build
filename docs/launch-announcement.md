# ATLAZES OS — Launch Announcement Texts

Ready-to-post text for each platform. Copy, adjust the GitHub link, and post.

---

## Reddit — r/linux

**Title:**
`ATLAZES OS v1.0.0-beta.1 — A privacy-focused Debian 12 daily driver. Public beta, looking for testers.`

**Body:**

I've been building a Debian 12-based Linux distribution focused on privacy and
security as a daily driver. After several months of development and a full audit
phase, I'm releasing the first public beta to get real-world feedback.

**What it is:**
A hardened Debian 12 system with encrypted DNS, MAC randomization, AppArmor,
Firejail sandboxing, and zero telemetry. Three privacy postures (normal / private /
paranoid). Three editions (core / dev / security).

**What it is NOT:**
Not an anonymity system. Not a Kali replacement. Not Tails.
Your IP address is still visible to websites you visit.
I've been explicit about this in the documentation.

**Why a public beta and not a stable release:**
The system has been tested in VMs and on a limited set of hardware. I need
real-world testing on diverse hardware before calling it stable. WiFi adapters,
GPU drivers, suspend/resume, and installer edge cases are the areas I'm most
uncertain about.

**What I need from you:**
- Boot the live session and run: `atlazes status`
- Try installing it (in a VM is fine)
- Report anything that doesn't work with your hardware details
- Tell me what hardware you tested on — even "it works" reports are useful

**What's technically different from other distros:**
- dnscrypt-proxy on port 53 (not 5300 like most guides show)
- resolv.conf is NOT locked with chattr+i — VPN and captive portals work
- AppArmor uses selective enforcement — only stable profiles enforced, no app breakage
- Dangerous GRUB params removed (nosmt=force, lockdown=confidentiality, oops=panic)
- Honest documentation about what the OS does and does not protect against

**Download + source:** [GitHub link]
SHA256 checksums and GPG signatures included.

I'll respond to every comment and every bug report.

---

## Reddit — r/privacy

**Title:**
`ATLAZES OS v1.0.0-beta.1 — Debian-based daily driver with encrypted DNS, MAC randomization, and zero telemetry. Public beta.`

**Body:**

I built a Linux distribution for people who want meaningful privacy improvements
over a default OS without giving up daily usability.

**Honest about what it does:**
- Encrypts DNS queries in transit (dnscrypt-proxy → Quad9/Cloudflare)
- Randomizes MAC address per connection
- Disables all OS and browser telemetry
- Sandboxes Firefox via Firejail
- Three privacy postures: normal / private / paranoid

**Honest about what it does NOT do:**
- Does not hide your IP address
- Does not provide anonymity
- DNS resolver still receives your queries (trust is contractual, not technical)
- Not a replacement for Tails if you need strong anonymity

I wrote a full security transparency page explaining the threat model, DNS trust
model, sandboxing limitations, and the difference between privacy and anonymity.

This is a public beta. I need real-world testing. If you test it, please report
what works and what doesn't.

**Download + source:** [GitHub link]

---

## Reddit — r/debian

**Title:**
`ATLAZES OS v1.0.0-beta.1 — A hardened Debian 12 live-build distribution. Public beta, feedback welcome.`

**Body:**

Built on Debian 12 Bookworm using live-build. Public beta release looking for
testing feedback, especially on hardware compatibility.

**Technical details:**
- live-build with 7 package lists and 7 chroot hooks
- Calamares installer with LUKS2 encryption support
- AppArmor selective enforcement (complain mode default, enforce for Firefox/CUPS)
- dnscrypt-proxy on port 53 (systemd-resolved stub disabled)
- Three editions: core / dev / security
- Hardened sysctl (production-safe — no nosmt=force, no lockdown=confidentiality)

**Source:** [GitHub link]

Happy to discuss the build configuration. Bug reports and hardware reports welcome.

---

## Hacker News — Show HN

**Title:**
`Show HN: ATLAZES OS – A privacy-focused Debian 12 daily driver (public beta)`

**Body:**

I built a Debian 12-based Linux distribution focused on privacy and security for
daily use. After a full development and audit cycle, I'm releasing the first public
beta.

The project tries to be honest about what it does and does not protect against.
There's a security transparency page that documents the threat model, DNS trust
model (resolver trust is contractual, not technical), sandboxing limitations
(Firejail is not container isolation), and the difference between privacy and
anonymity.

Technical highlights:
- dnscrypt-proxy on port 53, resolv.conf writable (VPN compatible)
- AppArmor selective enforcement — only stable profiles enforced
- Three privacy postures switchable via CLI: normal / private / paranoid
- Edition system: core / dev / security
- Hardened sysctl with dangerous params removed

Looking for feedback on hardware compatibility and any technical issues.

[GitHub link]

---

## Twitter/X Thread

**Tweet 1:**
ATLAZES OS v1.0.0-beta.1 is out for public testing.

Debian 12 base. Privacy-focused daily driver.
Not an anonymity system — the docs say this clearly.

Looking for testers. 🧵

**Tweet 2:**
What it does:
→ Encrypts DNS queries in transit (dnscrypt-proxy)
→ Randomizes MAC per connection
→ Disables all OS + browser telemetry
→ Firejail sandboxes Firefox automatically
→ AppArmor selective enforcement
→ Three privacy modes: normal / private / paranoid

**Tweet 3:**
What it does NOT do:
→ Does not hide your IP address
→ Does not provide anonymity
→ DNS resolver still receives your queries
→ Not a replacement for Tails

I wrote a full security transparency page explaining the limits.
No overclaiming.

**Tweet 4:**
Why beta and not stable?

Tested in VMs. Limited real hardware testing.
Need feedback on:
- WiFi adapters
- GPU drivers
- Suspend/resume
- Installer on unusual setups

**Tweet 5:**
Three editions:
Core     (~1.5GB) — daily use
Dev      (~3.0GB) — + VSCodium, Node.js, Docker
Security (~2.0GB) — + Lynis, AIDE, rkhunter

**Tweet 6:**
If you test it, please report:
- Your hardware
- What worked
- What didn't
- Steps to reproduce any issue

GitHub: [link]
SHA256 + GPG signed.

Feedback welcome. That's the point of a beta.
