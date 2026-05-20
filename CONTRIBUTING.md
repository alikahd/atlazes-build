# Contributing to ATLAZES OS

Thank you for helping test and improve ATLAZES OS.

---

## During the Public Beta

The most valuable contributions right now are:

### 1. Test on Real Hardware
Boot the live session or install it. Run `atlazes status`. Try your WiFi,
Bluetooth, suspend, and external display. Report what you find.

### 2. Report Bugs
Use the bug report template. Include hardware details and logs.
A report without hardware info and logs is very hard to act on.

```bash
# Collect this before reporting
cat /etc/atlazes-release
uname -r
inxi -Fxz
atlazes logs
journalctl -xe | tail -30
```

[→ Open a bug report](https://github.com/atlazes-os/atlazes-os/issues/new?template=bug_report.md)

### 3. Submit Hardware Compatibility Reports
Even "it works perfectly" reports are useful. They build the compatibility matrix.

[→ Submit hardware report](https://github.com/atlazes-os/atlazes-os/issues/new?template=hardware_report.md)

### 4. Improve Documentation
If something in the docs is unclear, wrong, or missing — open a feedback issue
or submit a pull request.

---

## Code Contributions

### Before submitting a pull request

1. Open an issue first to discuss the change
2. One logical change per PR
3. Test your change in a clean build environment
4. Document what you changed and why

### Rules for package list changes

- Only add packages that exist in Debian 12 (Bookworm) repositories
- Verify with: `apt-cache show <package>`
- No packages requiring external repositories in core lists

### Rules for hook changes

- All hooks must be idempotent (safe to run twice)
- Test in a clean chroot before submitting
- Comment every non-obvious line

### Rules for security changes

- Include a written justification: what it protects against, what it might break
- Include test results
- Security changes that break usability without strong justification will not be merged

### What will not be accepted

- Illegal hacking tools or offensive security tools in core
- Packages that send data to third parties without disclosure
- Changes that break usability without strong justification
- Untested changes
- Absolute privacy or anonymity claims in documentation

---

## Response Time

During the beta period:
- Bug reports: acknowledged within 48 hours
- Hardware reports: added to the compatibility tracker within 48 hours
- Pull requests: reviewed within one week

---

## Code of Conduct

Be direct and technical. Disagree with ideas, not people.
Security professionals are welcome to challenge any claim — that is how trust is built.
