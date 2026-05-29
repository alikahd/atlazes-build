#!/bin/bash
# =============================================================================
# ATLAZUS OS - Security Hardening
# Kernel hardening (sysctl) + AppArmor + Audit rules
# يُشغَّل داخل chroot
# =============================================================================

set -e

echo "[ATLAZUS] Applying security hardening..."

# ── Kernel Hardening (sysctl) ─────────────────────────────────────────────────
cat > /etc/sysctl.d/99-atlazus-hardening.conf << 'SYSCTL'
# =============================================================================
# ATLAZUS OS - Kernel Hardening
# =============================================================================

# ── Network Security ──────────────────────────────────────────────────────────
# Disable IP forwarding
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Enable SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Enable reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log martian packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP broadcasts
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Disable IPv6 router advertisements
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

# ── Kernel Security ───────────────────────────────────────────────────────────
# Restrict dmesg access
kernel.dmesg_restrict = 1

# Restrict kernel pointer exposure
kernel.kptr_restrict = 2

# Disable magic SysRq key (except sync+reboot)
kernel.sysrq = 176

# Restrict ptrace
kernel.yama.ptrace_scope = 1

# Restrict unprivileged user namespaces
kernel.unprivileged_userns_clone = 0

# Restrict perf events
kernel.perf_event_paranoid = 3

# ── Memory Security ───────────────────────────────────────────────────────────
# Randomize memory layout (ASLR)
kernel.randomize_va_space = 2

# Restrict core dumps
fs.suid_dumpable = 0

# Protect hardlinks and symlinks
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
SYSCTL

echo "[ATLAZUS] Kernel hardening applied."

# ── AppArmor ─────────────────────────────────────────────────────────────────
echo "[ATLAZUS] Configuring AppArmor..."

# تفعيل AppArmor عند الإقلاع
if command -v systemctl &>/dev/null; then
    systemctl enable apparmor.service 2>/dev/null || true
fi

# تحميل profiles الافتراضية
if command -v aa-enforce &>/dev/null; then
    # enforce profiles المتوفرة
    find /etc/apparmor.d -maxdepth 1 -type f ! -name "*.dpkg*" | while read -r profile; do
        aa-enforce "$profile" 2>/dev/null || true
    done
fi

echo "[ATLAZUS] AppArmor configured."

# ── Audit Rules ───────────────────────────────────────────────────────────────
echo "[ATLAZUS] Setting up audit rules..."

mkdir -p /etc/audit/rules.d

cat > /etc/audit/rules.d/atlazus.rules << 'AUDIT'
# ATLAZUS OS - Audit Rules

# Monitor authentication
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity

# Monitor sudo usage
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers

# Monitor SSH config
-w /etc/ssh/sshd_config -p wa -k sshd

# Monitor cron
-w /etc/crontab -p wa -k cron
-w /etc/cron.d/ -p wa -k cron
-w /var/spool/cron/ -p wa -k cron

# Monitor network config
-w /etc/hosts -p wa -k network
-w /etc/network/ -p wa -k network

# Monitor kernel modules
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules

# Monitor time changes
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change

# Monitor file deletions
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
AUDIT

# تفعيل auditd
if command -v systemctl &>/dev/null; then
    systemctl enable auditd.service 2>/dev/null || true
fi

echo "[ATLAZUS] Audit rules configured."

# ── UFW Firewall ──────────────────────────────────────────────────────────────
echo "[ATLAZUS] Configuring UFW..."

if command -v ufw &>/dev/null; then
    # إعداد القواعد الافتراضية
    ufw default deny incoming 2>/dev/null || true
    ufw default allow outgoing 2>/dev/null || true

    # تفعيل UFW عند الإقلاع (بدون تفعيله الآن في chroot)
    if command -v systemctl &>/dev/null; then
        systemctl enable ufw.service 2>/dev/null || true
    fi
fi

echo "[ATLAZUS] UFW configured."

# ── Firejail Profiles ─────────────────────────────────────────────────────────
echo "[ATLAZUS] Setting up Firejail..."

if command -v firejail &>/dev/null; then
    # إنشاء symlinks لتطبيقات شائعة
    mkdir -p /usr/local/bin

    for app in firefox-esr thunderbird; do
        if [[ -f "/usr/bin/${app}" ]] && [[ ! -L "/usr/local/bin/${app}" ]]; then
            ln -sf /usr/bin/firejail "/usr/local/bin/${app}" 2>/dev/null || true
        fi
    done

    # إعداد Firejail global config
    if [[ -f /etc/firejail/firejail.config ]]; then
        sed -i 's/# browser-disable-u2f yes/browser-disable-u2f no/' /etc/firejail/firejail.config 2>/dev/null || true
    fi
fi

echo "[ATLAZUS] Firejail configured."

# ── Disable Unnecessary Services ──────────────────────────────────────────────
echo "[ATLAZUS] Disabling unnecessary services..."

# خدمات لا نحتاجها في نظام أمني
for svc in avahi-daemon cups; do
    if systemctl list-unit-files "${svc}.service" &>/dev/null 2>&1; then
        systemctl disable "${svc}.service" 2>/dev/null || true
    fi
done

echo "[ATLAZUS] Security hardening complete."
