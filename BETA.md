# ATLAZES OS v1.0.0-beta.1 — Public Beta

## Beta Disclaimer

ATLAZES OS v1.0.0-beta.1 is a public beta release.

The system has been built, audited, and tested in virtual machines and on a limited
set of hardware configurations. It is functional and stable in tested environments.

**Before you download, understand the following:**

- Real-world hardware compatibility has not been fully verified across all devices
- Some WiFi adapters, GPUs, and touchpads may not work out of the box
- The Calamares installer has not been tested on all partition layouts
- Suspend and resume behavior varies by hardware and has not been fully tested
- Some security tool interactions may behave differently on untested configurations
- This release is **not recommended** for production systems or mission-critical use

**This is a beta because we need your testing.** The system works. We need to know
where it breaks on hardware we have not tested.

---

## Who Should Use This Beta

**Good fit:**
- Linux users comfortable with troubleshooting
- Privacy-conscious developers and researchers
- Security enthusiasts who want to evaluate the configuration
- People willing to report bugs with hardware details and logs

**Not a good fit:**
- Users with no Linux experience
- Anyone using this as their only machine for critical work
- Users who cannot afford downtime if something breaks
- People who need a guaranteed-stable system today

---

## What We Need From You

1. **Boot the live session** and run `atlazes status`
2. **Try the installer** (in a VM is fine)
3. **Test your specific hardware** — WiFi, Bluetooth, suspend, GPU
4. **Report anything that does not work** with hardware details and logs
5. **Tell us what does work** — hardware compatibility reports are equally valuable

---

## How to Report

**Bug:** https://github.com/atlazes-os/atlazes-os/issues/new?template=bug_report.md

**Hardware report:** https://github.com/atlazes-os/atlazes-os/issues/new?template=hardware_report.md

**General feedback:** https://github.com/atlazes-os/atlazes-os/issues/new?template=feedback.md

Include in every report:
```bash
cat /etc/atlazes-release   # ATLAZES version
uname -r                   # Kernel version
inxi -Fxz                  # Hardware info
atlazes logs               # Recent security logs
journalctl -xe | tail -30  # System logs
```

---

## Beta Cycle

```
1.0.0-beta.1  →  Now. Collect hardware reports and bug reports.
1.0.0-beta.2  →  Fix confirmed bugs. Re-test.
1.0.0-beta.3  →  Final polish if needed.
1.0.0         →  Stable release.
```

We will respond to every bug report. We will update the known issues list as
reports come in. We will publish beta.2 when the most critical issues are resolved.

---

## Known Issues in beta.1

See the live list: https://github.com/atlazes-os/atlazes-os/issues?label=known-issue

---

## Thank You

Every person who tests this beta and reports what they find is directly contributing
to the stable release. We appreciate it.
