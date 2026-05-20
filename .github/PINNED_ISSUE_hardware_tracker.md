# Beta Hardware Compatibility Tracker — v1.0.0-beta.1

This issue tracks hardware compatibility reports from the community.
**If you tested ATLAZES OS on your hardware, please add a comment using the template below.**

---

## How to Add Your Report

Run this in a terminal and include the output in your comment:

```bash
echo "=== ATLAZES Version ===" && cat /etc/atlazes-release
echo "=== Kernel ===" && uname -r
echo "=== Hardware ===" && inxi -Fxz 2>/dev/null || inxi -F
```

Then fill in the table:

```
Machine: [model]
CPU: 
RAM: 
GPU: 
WiFi: 

| Boot BIOS  | ✅/❌/⚠️ |
| Boot UEFI  | ✅/❌/⚠️ |
| WiFi       | ✅/❌/⚠️ |
| Ethernet   | ✅/❌/⚠️ |
| Audio      | ✅/❌/⚠️ |
| Bluetooth  | ✅/❌/⚠️ |
| Touchpad   | ✅/❌/⚠️ |
| Suspend    | ✅/❌/⚠️ |
| Ext. display | ✅/❌/⚠️ |
| Installer  | ✅/❌/⚠️ |

Overall: Works well / Works with issues / Does not work
Notes:
```

---

## Confirmed Working Hardware

| Machine | CPU | GPU | WiFi | Suspend | Installer | Reported by |
|---------|-----|-----|------|---------|-----------|-------------|
| *(add your hardware)* | | | | | | |

---

## Known Issues by Hardware

| Hardware | Issue | Status |
|----------|-------|--------|
| *(populated as reports come in)* | | |

---

## Legend
- ✅ Works correctly
- ⚠️ Works with issues or workaround needed
- ❌ Does not work
- ❓ Not tested
