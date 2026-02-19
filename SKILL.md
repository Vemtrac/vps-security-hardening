---
name: vps-security-hardening
description: Harden OpenClaw security on Ubuntu/Debian VPS. SSH hardening, UFW firewall, fail2ban, automatic updates, Docker security, credential rotation, and security audits.
---

# VPS Security Hardening for OpenClaw

Secure your OpenClaw deployment on a Ubuntu/Debian VPS with industry-standard hardening practices.

## What This Skill Does

- **SSH hardening** - Disable root login, enforce key-only authentication, change default port
- **Firewall configuration** - UFW rules allowing only required OpenClaw ports
- **Automatic security updates** - unattended-upgrades to keep system patches current
- **Intrusion prevention** - Fail2ban to block brute-force attacks
- **Docker security** - Non-root containers, network isolation, resource limits
- **Credential rotation** - Reminders and procedures for rotating API keys
- **Security audits** - Scan current system and report hardening status

## Quick Start

### Run a Security Audit

```bash
bash scripts/audit.sh
```

Reports current security posture across all hardening areas. No changes made.

### Apply All Hardening Steps

```bash
bash scripts/harden.sh
```

Interactive script with confirmations before each major step. Safe to re-run.

### Specific Hardening Areas

See `references/hardening-guide.md` for detailed instructions on:
- SSH hardening (manual commands, configuration explanation)
- UFW firewall rules
- Fail2ban setup and tuning
- Unattended-upgrades configuration
- Docker security best practices
- Credential rotation procedures

## Prerequisites

- Ubuntu 20.04+ or Debian 11+
- Root or sudo access
- SSH access to the VPS
- OpenClaw already installed

## Key Concepts

### Risk Postures

Three recommended security profiles:

1. **Balanced (Default)** - SSH on custom port, firewall, fail2ban, auto-updates
2. **Hardened** - SSH key-only, UFW strict, fail2ban aggressive, auto-updates, Docker non-root
3. **Developer** - SSH on standard port (easier access), firewall, fail2ban lenient, auto-updates

### Port Configuration

By default, UFW is configured to allow:
- SSH (port 2222 for Balanced/Hardened, 22 for Developer)
- OpenClaw gateway (port 9999, localhost-only)
- HTTPS (port 443, if reverse proxy used)

All other inbound traffic is denied.

### Automatic Updates

Unattended-upgrades will automatically:
- Download and install security patches daily
- Reboot the system if kernel updates require it
- Email root with a summary of changes

You can adjust frequency and reboot behavior in `/etc/apt/apt.conf.d/50unattended-upgrades`.

## Workflow

### 1. Run Audit First

```bash
bash scripts/audit.sh
```

Understand current state before making changes. Shows:
- SSH configuration status
- Firewall rules (if UFW enabled)
- Fail2ban status
- Update configuration
- Docker security settings
- Recent security events

### 2. Choose Risk Posture

Decide which profile fits your use case:
- **Production/Business** → Hardened
- **Small team/Stable system** → Balanced
- **Development/Testing** → Developer

### 3. Run Hardening Script

```bash
bash scripts/harden.sh
```

Interactive prompts for each step. You control what gets applied.

### 4. Verify Changes

Re-run audit to confirm hardening was applied:

```bash
bash scripts/audit.sh
```

## Maintenance

### Monthly

- Review firewall logs: `sudo ufw status verbose`
- Check fail2ban activity: `sudo fail2ban-client status`
- Verify auto-updates are running

### Quarterly

- Rotate OpenClaw API credentials
- Review SSH key permissions: `ls -la ~/.ssh/`
- Update OS and packages (triggered by unattended-upgrades)

### Annually

- Full security audit of VPS infrastructure
- Review and update firewall rules if needed
- Rotate SSH keys if stale

## Troubleshooting

### SSH Locked Out After Hardening

If you lose SSH access after changing the port:

1. Connect via VPS provider's console (web-based)
2. Check SSH config: `sudo cat /etc/ssh/sshd_config | grep Port`
3. Restore original port or add new port temporarily
4. Restart SSH: `sudo systemctl restart ssh`
5. Try connecting to correct port

### UFW Blocking OpenClaw Gateway

If OpenClaw becomes unreachable after firewall changes:

1. SSH into VPS
2. Check UFW status: `sudo ufw status`
3. Review gateway port: Check OpenClaw config for actual listening port
4. Add rule: `sudo ufw allow 9999/tcp`
5. Reload: `sudo ufw reload`

### Fail2ban False Positives

If legitimate traffic gets blocked:

1. Check fail2ban jails: `sudo fail2ban-client status`
2. Whitelist your IP: Edit `/etc/fail2ban/jail.local`, add `ignoreip = 1.2.3.4/32`
3. Restart fail2ban: `sudo systemctl restart fail2ban`

## Security Considerations

### What This Skill Covers

✅ Host OS hardening (SSH, firewall, updates, intrusion prevention)  
✅ Container security (Docker)  
✅ Credential rotation procedures  
✅ Audit and monitoring setup  

### What This Skill Does NOT Cover

❌ Application-level security (OpenClaw configuration itself)  
❌ TLS certificate management  
❌ Data backup and recovery  
❌ DDoS mitigation (beyond basic firewall rules)  
❌ Compliance frameworks (PCI-DSS, HIPAA, SOC2)  

For these, consult additional resources or a security professional.

## Scripts Included

### audit.sh

Check current security posture. Non-destructive. Reports:
- SSH hardening status
- Firewall configuration
- Fail2ban status
- Update configuration
- Docker security settings
- Last login attempts
- Security warnings

Usage:
```bash
bash scripts/audit.sh
```

### harden.sh

Apply hardening steps interactively. Each step requires confirmation.

Usage:
```bash
bash scripts/harden.sh
```

Prompts for:
1. Risk posture (Balanced/Hardened/Developer)
2. SSH port to use (default 2222 for Balanced, 22 for Developer)
3. Whether to enable UFW firewall
4. Whether to install and configure fail2ban
5. Whether to enable automatic security updates
6. Whether to configure Docker security

All changes are logged to `/var/log/vps-hardening.log`.

## Reference Files

- **hardening-guide.md** - Detailed procedures for each hardening area
- **firewall-rules.md** - UFW rules reference and customization
- **docker-security.md** - Docker hardening best practices
- **credential-rotation.md** - How to rotate API keys and secrets

See these files for deep-dive information on specific topics.

## By Vemtrac

This skill is maintained by [Vemtrac](https://vemtrac.com). For questions or improvements, contact hello@vemtrac.com.
