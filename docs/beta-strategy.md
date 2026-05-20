# ATLAZES OS — Public Beta Strategy

## Publication Order

### Week 1 — Technical communities first

**Day 1: GitHub**
Publish the repository and release. This is the anchor.
All other posts link here. Without this live, nothing else matters.

Checklist before publishing:
- [ ] README has beta badge and warning section
- [ ] CHANGELOG.md updated to beta.1
- [ ] BETA.md present at root
- [ ] Issue templates in .github/ISSUE_TEMPLATE/
- [ ] CONTRIBUTING.md present
- [ ] Release tagged: v1.0.0-beta.1
- [ ] ISOs attached to release with SHA256SUMS and .asc signatures
- [ ] Pinned issue: Hardware Compatibility Tracker

**Day 2: r/linux**
Largest Linux audience. Expect critical feedback — that is useful.
Use the r/linux announcement text from docs/launch-announcement.md.

**Day 3: r/privacy**
Directly relevant audience. Privacy-conscious users who will test the
privacy features specifically.

**Day 4: r/debian**
Technical Debian users who understand the base system and can give
informed feedback on the build configuration.

**Day 5: r/netsec**
Security professionals who will test the security claims critically.
Valuable for credibility. Be prepared for hard questions — answer them honestly.

### Week 2 — Broader reach

**Hacker News — Show HN**
Technical audience, high signal-to-noise feedback.
Use the Show HN text from docs/launch-announcement.md.
Post on a Tuesday or Wednesday morning (UTC) for best visibility.

**Mastodon / Fediverse**
Privacy-conscious community. No algorithm. Direct reach to target users.
Post on infosec.exchange and fosstodon.org.

**DistroWatch**
Submit for listing at: https://distrowatch.com/dwres.php?resource=submit
Even a "waiting" status drives discovery traffic.
Required: website URL, description, base distro, desktop, architecture.

### Do Not Post Yet
- YouTube (no video content ready)
- General tech news sites (wait for stable release)
- Paid promotion of any kind

---

## Feedback Management

### GitHub Issues — Primary Channel

Label everything consistently:

| Label | Use for |
|-------|---------|
| `bug` | Something does not work |
| `hardware` | Hardware compatibility report |
| `feedback` | Suggestions and impressions |
| `confirmed` | Bug reproduced and confirmed |
| `needs-info` | Waiting for more details from reporter |
| `known-issue` | Acknowledged, fix planned |
| `wontfix` | Will not be fixed (with explanation) |
| `beta.2` | Targeted for next beta |

### Pinned Issues

Pin two issues immediately after publishing:

1. **Hardware Compatibility Tracker** — community-maintained table
2. **Beta.1 Known Issues** — list of confirmed bugs with status

### Response Commitment

- Acknowledge every bug report within 48 hours
- Label it (confirmed / needs-info / wontfix)
- If you cannot fix it for beta.2, say so clearly with a reason
- Never leave a report with no response

### Weekly Update

Post a brief update comment on the Hardware Tracker issue every week:
- How many reports received
- What was confirmed
- What is being worked on
- ETA for beta.2

---

## Beta Cycle Timeline

```
Week 1–2:   beta.1 published, collect reports
Week 3–4:   Triage all reports, fix confirmed bugs
Week 5:     beta.2 published with fixes
Week 6–7:   Collect remaining reports
Week 8:     beta.3 if needed, or move to stable
Week 9–10:  v1.0.0 stable release
```

---

## Success Metrics for Beta

The beta is successful if:

- At least 10 hardware compatibility reports submitted
- All P1 (boot failure, installer crash) bugs identified and fixed
- No security claims found to be inaccurate
- Community feedback is net positive on honesty and documentation quality

The beta is not measured by download count or stars.
It is measured by the quality of feedback received and acted on.

---

## The One Rule

Respond to every report.

A beta that ignores feedback destroys trust faster than any bug.
A beta where the maintainer responds, acknowledges, and fixes things
builds a community that will support the stable release.
