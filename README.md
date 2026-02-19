# VPS Security Hardening Skill

**By Vemtrac** — https://vemtrac.com

A comprehensive security hardening skill for OpenClaw deployments on Ubuntu/Debian VPS.

## What It Does

This skill provides production-ready security hardening for OpenClaw instances running on a VPS:

- **SSH Hardening** - Disable root login, key-only authentication, configurable port
- **Firewall Setup** - UFW with rules allowing only necessary ports (SSH, OpenClaw gateway)
- **Automatic Updates** - Unattended-upgrades for timely security patches
- **Intrusion Prevention** - Fail2ban to protect against brute-force attacks
- **Docker Security** - Non-root containers, network isolation, resource limits
- **Credential Rotation** - Procedures and reminders for API key rotation
- **Security Audits** - Bash script to audit current security posture

## Who It's For

- **OpenClaw Operators** - Anyone running OpenClaw on a VPS (AWS, DigitalOcean, Linode, Hetzner, etc.)
- **Security-Conscious Users** - Teams that need hardened deployments
- **Small Businesses** - Affordable hardening without hiring a security consultant
- **Developers** - Who want production-grade security practices

## Installation

### Option 1: Add to Your OpenClaw Skills Directory

```bash
git clone https://github.com/vemtrac/vps-security-hardening.git ~/.openclaw/skills/vps-security-hardening
```

### Option 2: Copy Scripts Only

If you can't modify the skills directory, copy the scripts directly:

```bash
mkdir -p ~/hardening-scripts
cp vps-security-hardening/scripts/*.sh ~/hardening-scripts/
chmod +x ~/hardening-scripts/*.sh
```

## Quick Start

### 1. Audit Current Security

```bash
bash scripts/audit.sh
```

Shows your current security posture without making changes.

### 2. Apply Hardening

```bash
bash scripts/harden.sh
```

Interactive script that guides you through each hardening step. You approve each change.

### 3. Verify Results

```bash
bash scripts/audit.sh
```

Confirm that hardening was applied successfully.

## How It Works

### Risk Postures

Choose one of three security profiles:

**1. Balanced (Recommended for most users)**
- SSH on custom port (2222)
- UFW firewall enabled
- Fail2ban with standard sensitivity
- Automatic security updates
- Standard Docker security

**2. Hardened (For production/sensitive data)**
- SSH key-only, custom port (2222)
- UFW with strict inbound rules
- Fail2ban with aggressive settings
- Automatic security updates with auto-reboot
- Docker containers run as non-root
- Credential rotation every 90 days

**3. Developer (For testing/development)**
- SSH on standard port (22)
- UFW firewall enabled (basic rules)
- Fail2ban with lenient settings
- Automatic security updates
- Standard Docker security

### What Gets Hardened

#### SSH

```bash
# Disable root login
PermitRootLogin no

# Require key-only authentication
PubkeyAuthentication yes
PasswordAuthentication no

# Change default port
Port 2222  # (or your choice)
```

#### Firewall (UFW)

```bash
# Allow only SSH and OpenClaw gateway
ufw default deny incoming
ufw allow 2222/tcp        # SSH
ufw allow 9999/tcp        # OpenClaw (localhost-only)
ufw allow 443/tcp         # HTTPS (optional)
ufw enable
```

#### Fail2ban

```bash
# Protect SSH from brute-force
[sshd]
enabled = true
port = 2222
maxretry = 5
findtime = 600
bantime = 3600
```

#### Automatic Updates

```bash
# Install unattended-upgrades
apt install unattended-upgrades

# Automatic reboot after kernel updates (optional)
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Update-Package-Lists "1";
```

#### Docker Security

```bash
# Run containers as non-root
# Use named volumes instead of host paths
# Isolate networks per application
# Set resource limits (CPU, memory)
```

## Files in This Skill

```
vps-security-hardening/
├── SKILL.md                      # Main skill definition (OpenClaw format)
├── README.md                     # This file
├── scripts/
│   ├── audit.sh                  # Check current security status
│   └── harden.sh                 # Apply hardening steps interactively
└── references/
    ├── hardening-guide.md        # Detailed hardening procedures
    ├── firewall-rules.md         # UFW rules reference
    ├── docker-security.md        # Docker hardening guide
    └── credential-rotation.md    # API key rotation procedures
```

## Troubleshooting

### Locked Out of SSH After Hardening

1. Use your VPS provider's web console to access the server
2. Check SSH config: `sudo cat /etc/ssh/sshd_config | grep Port`
3. Restore port temporarily or add your IP to the firewall
4. Restart SSH: `sudo systemctl restart ssh`

### UFW Blocking OpenClaw

1. Check firewall rules: `sudo ufw status`
2. Add rule for OpenClaw gateway: `sudo ufw allow 9999/tcp`
3. Reload: `sudo ufw reload`

### Can't SSH With Key

1. Check permissions: `ls -la ~/.ssh/`
2. Verify key is authorized: `cat ~/.ssh/authorized_keys | grep <your_key>`
3. Restart SSH: `sudo systemctl restart ssh`

## Security Notes

### What's Covered

✅ Host OS hardening (SSH, firewall, updates)  
✅ Intrusion detection (Fail2ban)  
✅ Container security (Docker)  
✅ Credential management basics  

### What's NOT Covered

❌ TLS certificates (use Let's Encrypt separately)  
❌ Data encryption at rest  
❌ Backups and disaster recovery  
❌ Compliance (PCI-DSS, HIPAA, SOC2)  
❌ DDoS mitigation (beyond firewall)  

For these, consult additional tools or a security professional.

## Maintenance

### Monthly

- Check firewall logs: `sudo ufw status verbose`
- Monitor fail2ban: `sudo fail2ban-client status`
- Verify updates are being applied

### Quarterly

- Rotate API credentials and SSH keys
- Review firewall rules
- Update OS packages manually: `sudo apt update && sudo apt upgrade`

### Annually

- Full security audit
- Review and update all hardening rules
- Plan for major OS upgrades

## Getting Help

- **Questions?** Contact hello@vemtrac.com
- **Issues?** Report to https://github.com/vemtrac/vps-security-hardening/issues
- **Want to contribute?** Pull requests welcome!

## License

MIT License. See LICENSE file.

---

**Made by Vemtrac** — AI automation for boring industries.  
https://vemtrac.com | hello@vemtrac.com
