#!/bin/bash

# Server Security Hardening Script

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

log "Starting Server Security Hardening"

# 1. System Updates
log "Applying security updates..."
apt update
apt upgrade -y
apt autoremove -y

# 2. Install security tools
log "Installing security tools..."
apt install -y \
    fail2ban \
    rkhunter \
    chkrootkit \
    lynis \
    auditd \
    acct

# 3. Configure auditd
log "Configuring audit system..."
cat > /etc/audit/audit.rules << EOF
# First rule - delete all
-D

# Increase the buffers to survive stress events.
-b 8192

# Failure mode
-f 1

# Make the configuration immutable
-e 2

# Log all sudo commands
-a exit,always -F arch=b64 -S execve -F path=/usr/bin/sudo

# Log file deletions
-a exit,always -F arch=b64 -S unlink -S unlinkat -S rename -S renameat

# Log system administration actions
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k identity

# Log file system mounts
-w /etc/fstab -p wa -k mounts
-w /etc/mtab -p wa -k mounts

# Monitor SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd

# Monitor web configuration
-w /etc/nginx -p wa -k nginx
-w /etc/mysql -p wa -k mysql
EOF

systemctl enable auditd
systemctl start auditd

# 4. Configure sysctl security
log "Configuring kernel security parameters..."
cat > /etc/sysctl.d/99-security.conf << EOF
# Network security
net.ipv4.ip_forward=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.default.log_martians=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_max_syn_backlog=2048
net.ipv4.tcp_synack_retries=2
net.ipv4.tcp_syn_retries=5

# IPv6 security
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_source_route=0

# System security
kernel.dmesg_restrict=1
kernel.kptr_restrict=2
kernel.yama.ptrace_scope=1
net.core.bpf_jit_enable=0

# Memory protection
vm.mmap_rnd_bits=32
vm.mmap_rnd_compat_bits=16
vm.swappiness=10
EOF

sysctl -p /etc/sysctl.d/99-security.conf

# 5. Configure AppArmor
log "Configuring AppArmor..."
apt install -y apparmor apparmor-utils
aa-enforce /etc/apparmor.d/*

# 6. Harden SSH configuration
log "Hardening SSH configuration..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)

cat >> /etc/ssh/sshd_config << EOF

# Security enhancements
LoginGraceTime 60
MaxStartups 2:50:10
MaxSessions 10
Compression no
TCPKeepAlive no
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
EOF

# 7. Configure file permissions
log "Setting secure file permissions..."
chmod 600 /etc/shadow
chmod 644 /etc/passwd
chmod 600 /root/.ssh/authorized_keys 2>/dev/null || true

# 8. Set up intrusion detection
log "Configuring intrusion detection..."
rkhunter --update
rkhunter --propupd

# Create rkhunter cron job
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/bin/rkhunter --cronjob --update --quiet") | crontab -

# 9. Configure log monitoring
log "Setting up log monitoring..."
apt install -y logwatch
cat > /etc/logwatch/conf/logwatch.conf << EOF
Output = mail
Format = html
MailTo = root
Range = yesterday
Detail = High
Service = All
EOF

# 10. Create security monitoring script
cat > /root/security-check.sh << 'EOF'
#!/bin/bash
echo "=== Security Check - $(date) ==="
echo ""
echo "1. Failed SSH attempts:"
grep "Failed password" /var/log/auth.log | wc -l
echo ""
echo "2. Current connections:"
netstat -tunlp
echo ""
echo "3. Failed logins:"
lastb | head -20
echo ""
echo "4. Suspicious processes:"
ps aux | grep -E "(ssh|ftp|telnet)" | grep -v grep
echo ""
echo "5. File system changes:"
auditctl -l
EOF

chmod +x /root/security-check.sh

# 11. Configure automatic security updates
log "Configuring automatic security updates..."
apt install -y unattended-upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESM:\${distro_codename}";
};
Unattended-Upgrade::Package-Blacklist {
    // Add packages to exclude from updates
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

# 12. Harden MySQL
log "Hardening MySQL..."
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP USER IF EXISTS ''@'localhost';"
mysql -e "DROP USER IF EXISTS ''@'$(hostname)';"
mysql -e "FLUSH PRIVILEGES;"

# 13. Harden PHP
log "Hardening PHP..."
PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
sed -i 's/^display_errors = On/display_errors = Off/' /etc/php/$PHP_VERSION/fpm/php.ini
sed -i 's/^expose_php = On/expose_php = Off/' /etc/php/$PHP_VERSION/fpm/php.ini

# 14. Configure firewall rules
log "Configuring additional firewall rules..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# 15. Create security report
log "Generating security report..."
lynis audit system --quick > /root/security-report.txt 2>/dev/null || true

log "Server Security Hardening Completed!"
echo ""
echo "=== SECURITY CHECKS ==="
echo "✅ System updates applied"
echo "✅ Security tools installed"
echo "✅ Audit system configured"
echo "✅ Kernel parameters secured"
echo "✅ SSH hardened"
echo "✅ Automatic updates enabled"
echo "✅ Firewall configured"
echo ""
echo "Run '/root/security-check.sh' for ongoing monitoring"
echo "Security report: /root/security-report.txt"