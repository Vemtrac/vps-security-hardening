#!/bin/bash

################################################################################
# VPS Security Hardening Audit Script
# 
# Purpose: Check current security posture across all hardening areas
# Usage: bash audit.sh
# 
# Reports on:
# - SSH configuration (root login, key-only auth, port)
# - UFW firewall rules
# - Fail2ban status
# - Automatic updates configuration
# - Docker security settings
# - Recent security events
#
# By Vemtrac (https://vemtrac.com)
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

print_fail() {
    echo -e "${RED}✗${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Start audit
clear
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     VPS Security Hardening Audit                           ║"
echo "║     By Vemtrac (https://vemtrac.com)                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# System Info
print_header "System Information"
print_info "OS: $(lsb_release -d | cut -f2)"
print_info "Kernel: $(uname -r)"
print_info "Hostname: $(hostname)"
print_info "Uptime: $(uptime -p)"

# SSH Configuration
print_header "SSH Configuration"

if [ -f /etc/ssh/sshd_config ]; then
    # Check root login
    if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
        print_pass "Root login disabled"
    else
        print_fail "Root login is enabled (consider disabling)"
    fi
    
    # Check key authentication
    if grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config; then
        print_pass "Public key authentication enabled"
    else
        print_warn "Public key authentication not explicitly enabled"
    fi
    
    # Check password authentication
    if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
        print_pass "Password authentication disabled"
    else
        print_fail "Password authentication is enabled (SSH key-only is more secure)"
    fi
    
    # Check port
    SSH_PORT=$(grep "^Port " /etc/ssh/sshd_config | awk '{print $2}' || echo "22")
    if [ "$SSH_PORT" != "22" ]; then
        print_pass "SSH port changed from default (Port: $SSH_PORT)"
    else
        print_warn "SSH using default port 22 (consider changing to reduce scan attempts)"
    fi
    
    # Check for empty passwords
    if grep -q "^PermitEmptyPasswords no" /etc/ssh/sshd_config; then
        print_pass "Empty passwords disabled"
    else
        print_warn "Empty passwords not explicitly disabled"
    fi
else
    print_fail "SSH config file not found"
fi

# Check authorized keys
AUTHORIZED_KEYS="$HOME/.ssh/authorized_keys"
if [ -f "$AUTHORIZED_KEYS" ]; then
    KEY_COUNT=$(wc -l < "$AUTHORIZED_KEYS")
    print_pass "SSH keys configured ($KEY_COUNT keys)"
else
    print_warn "No SSH authorized_keys file found"
fi

# Firewall Configuration
print_header "Firewall (UFW)"

if command -v ufw &> /dev/null; then
    UFW_STATUS=$(sudo ufw status | head -1)
    if [[ $UFW_STATUS == *"active"* ]]; then
        print_pass "UFW firewall is active"
        echo ""
        echo "Current UFW rules:"
        sudo ufw status | tail -n +3 | sed 's/^/  /'
    else
        print_warn "UFW firewall is not active"
        print_info "To enable: sudo ufw enable"
    fi
else
    print_fail "UFW not installed"
    print_info "To install: sudo apt install ufw"
fi

# Fail2ban Configuration
print_header "Fail2ban (Intrusion Prevention)"

if command -v fail2ban-client &> /dev/null; then
    if sudo systemctl is-active --quiet fail2ban; then
        print_pass "Fail2ban is running"
        
        # Check SSH jail status
        SSH_JAIL=$(sudo fail2ban-client status sshd 2>/dev/null || echo "not found")
        if [[ $SSH_JAIL != *"not found"* ]]; then
            BANNED=$(echo "$SSH_JAIL" | grep "Banned IP list" | awk -F'[' '{print $NF}' | tr -d ']')
            print_info "SSH jail status: $SSH_JAIL" | head -1
            [ -n "$BANNED" ] && print_warn "Currently banned IPs: $BANNED"
        fi
    else
        print_warn "Fail2ban is installed but not running"
        print_info "To start: sudo systemctl start fail2ban"
    fi
else
    print_fail "Fail2ban not installed"
    print_info "To install: sudo apt install fail2ban"
fi

# Automatic Updates
print_header "Automatic Updates"

if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
    print_pass "Unattended-upgrades configuration found"
    
    if grep -q "^APT::Periodic::Update-Package-Lists" /etc/apt/apt.conf.d/20auto-upgrades; then
        print_pass "Automatic update checks enabled"
    else
        print_warn "Automatic update checks may not be enabled"
    fi
    
    if grep -q "^APT::Periodic::Unattended-Upgrade" /etc/apt/apt.conf.d/20auto-upgrades; then
        print_pass "Automatic security upgrades enabled"
    else
        print_warn "Automatic security upgrades may not be enabled"
    fi
else
    print_fail "Unattended-upgrades not configured"
    print_info "To install: sudo apt install unattended-upgrades"
fi

# Docker Security
print_header "Docker Security"

if command -v docker &> /dev/null; then
    if sudo systemctl is-active --quiet docker; then
        print_pass "Docker is installed and running"
        
        # Check if user is in docker group
        if groups | grep -q docker; then
            print_warn "Current user in docker group (can escalate to root)"
        else
            print_pass "Current user not in docker group"
        fi
        
        # Check for rootless docker
        if docker info 2>/dev/null | grep -q "rootless"; then
            print_pass "Docker rootless mode enabled"
        else
            print_warn "Docker running in rootful mode (consider rootless for better security)"
        fi
    else
        print_warn "Docker installed but not running"
    fi
else
    print_info "Docker not installed (optional)"
fi

# System Packages
print_header "System Security Status"

# Check for updates
UPDATE_COUNT=$(apt list --upgradable 2>/dev/null | wc -l)
if [ "$UPDATE_COUNT" -gt 1 ]; then
    print_warn "Updates available: $((UPDATE_COUNT - 1)) packages"
    print_info "Run: sudo apt update && sudo apt upgrade"
else
    print_pass "System is up to date"
fi

# Check for security updates
if [ -f /var/log/apt/history.log ]; then
    LAST_UPDATE=$(stat -c %y /var/log/apt/history.log | cut -d' ' -f1)
    print_info "Last package update: $LAST_UPDATE"
fi

# Recent Security Events
print_header "Recent Security Events"

# Failed SSH attempts
if [ -f /var/log/auth.log ]; then
    FAILED_SSH=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
    if [ "$FAILED_SSH" -gt 0 ]; then
        print_warn "Failed SSH login attempts: $FAILED_SSH (last 24h estimated)"
    else
        print_pass "No failed SSH login attempts detected"
    fi
fi

# Sudo usage
SUDO_USAGE=$(grep "sudo" /var/log/auth.log 2>/dev/null | tail -5 | wc -l)
if [ "$SUDO_USAGE" -gt 0 ]; then
    print_info "Recent sudo usage detected (last few entries)"
fi

# Summary
print_header "Audit Summary"

echo -e "${BLUE}Hardening Status:${NC}"
echo ""
echo "✓ = Hardened (recommended setting applied)"
echo "⚠ = Warning (setting could be more secure)"
echo "✗ = Not hardened (security setting not applied)"
echo ""
echo "For detailed information on each setting, see:"
echo "  - hardening-guide.md (full procedures)"
echo "  - firewall-rules.md (UFW configuration)"
echo "  - docker-security.md (Docker best practices)"
echo ""
echo "To apply hardening automatically, run: bash harden.sh"
echo ""

print_info "Audit completed: $(date)"
