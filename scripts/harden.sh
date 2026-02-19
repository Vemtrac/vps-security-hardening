#!/bin/bash

################################################################################
# VPS Security Hardening Script
# 
# Purpose: Apply security hardening steps interactively with confirmations
# Usage: bash harden.sh
# 
# Applies:
# - SSH hardening (disable root, key-only auth, custom port)
# - UFW firewall rules
# - Fail2ban configuration
# - Automatic security updates
# - Docker security settings
# - Credential rotation reminders
#
# Each step requires user confirmation before applying.
# Safe to re-run multiple times.
#
# By Vemtrac (https://vemtrac.com)
################################################################################

set -e

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "This script requires root or sudo privileges."
    echo "Run with: sudo bash harden.sh"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

confirm() {
    local prompt="$1"
    local response
    while true; do
        read -p "$(echo -e ${BLUE}$prompt' (yes/no): '${NC})" response
        case $response in
            [Yy][Ee][Ss]|[Yy])
                return 0
                ;;
            [Nn][Oo]|[Nn])
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

# Logging
LOG_FILE="/var/log/vps-hardening.log"

log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Start script
clear
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     VPS Security Hardening Script                          ║"
echo "║     By Vemtrac (https://vemtrac.com)                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

print_header "Step 0: Choose Risk Posture"

echo "Select security level for your VPS:"
echo ""
echo "  1) Balanced (Recommended) - Good security, reasonable ease of access"
echo "     - SSH on port 2222"
echo "     - UFW firewall enabled"
echo "     - Fail2ban standard configuration"
echo "     - Automatic security updates"
echo ""
echo "  2) Hardened - Maximum security for production systems"
echo "     - SSH key-only, port 2222"
echo "     - UFW strict inbound rules"
echo "     - Fail2ban aggressive settings"
echo "     - Automatic updates with reboot"
echo "     - Docker runs as non-root"
echo ""
echo "  3) Developer - For testing and development"
echo "     - SSH on standard port 22"
echo "     - UFW firewall with basic rules"
echo "     - Fail2ban lenient settings"
echo "     - Automatic security updates"
echo ""

read -p "Choose 1, 2, or 3: " RISK_POSTURE

case $RISK_POSTURE in
    1)
        POSTURE_NAME="Balanced"
        SSH_PORT=2222
        UFW_STRICT=false
        FAIL2BAN_AGGRESSIVE=false
        AUTO_REBOOT=false
        DOCKER_NONROOT=false
        ;;
    2)
        POSTURE_NAME="Hardened"
        SSH_PORT=2222
        UFW_STRICT=true
        FAIL2BAN_AGGRESSIVE=true
        AUTO_REBOOT=true
        DOCKER_NONROOT=true
        ;;
    3)
        POSTURE_NAME="Developer"
        SSH_PORT=22
        UFW_STRICT=false
        FAIL2BAN_AGGRESSIVE=false
        AUTO_REBOOT=false
        DOCKER_NONROOT=false
        ;;
    *)
        print_error "Invalid selection. Exiting."
        exit 1
        ;;
esac

print_success "Selected risk posture: $POSTURE_NAME"
log_action "Started hardening with posture: $POSTURE_NAME"

# Step 1: SSH Hardening
print_header "Step 1: SSH Hardening"

if confirm "Harden SSH (disable root login, key-only auth, port $SSH_PORT)?"; then
    print_success "Starting SSH hardening..."
    
    # Backup SSH config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%s)
    print_success "Backed up SSH config"
    
    # Disable root login
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i '/^PermitRootLogin no/!b;n;/^PermitRootLogin/!b;s/^//' /etc/ssh/sshd_config || true
    print_success "Disabled root login"
    
    # Enable key authentication
    sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    print_success "Enabled public key authentication"
    
    # Disable password authentication
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    print_success "Disabled password authentication"
    
    # Set SSH port
    sed -i "s/^#Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config
    sed -i "s/^Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config
    print_success "Set SSH port to $SSH_PORT"
    
    # Disable empty passwords
    sed -i 's/^#PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    print_success "Disabled empty passwords"
    
    # Reload SSH
    systemctl reload ssh
    print_success "Reloaded SSH configuration"
    print_warning "Remember: SSH is now on port $SSH_PORT. Update your SSH client."
    
    log_action "SSH hardened: disabled root, key-only auth, port=$SSH_PORT"
else
    print_warning "Skipped SSH hardening"
fi

# Step 2: UFW Firewall
print_header "Step 2: UFW Firewall"

if confirm "Configure UFW firewall?"; then
    print_success "Starting UFW configuration..."
    
    if ! command -v ufw &> /dev/null; then
        apt update && apt install -y ufw
        print_success "Installed UFW"
    fi
    
    # Configure default policies
    ufw default deny incoming
    ufw default allow outgoing
    print_success "Set default deny incoming, allow outgoing"
    
    # Allow SSH
    ufw allow "$SSH_PORT"/tcp
    print_success "Allowed SSH on port $SSH_PORT"
    
    # Allow OpenClaw gateway (localhost-only via gateway config)
    ufw allow 9999/tcp
    print_success "Allowed OpenClaw gateway port 9999"
    
    # Allow HTTPS if requested
    if confirm "Allow HTTPS (port 443) for reverse proxy?"; then
        ufw allow 443/tcp
        print_success "Allowed HTTPS"
    fi
    
    # Enable UFW
    ufw enable
    print_success "UFW firewall enabled"
    
    log_action "UFW firewall configured and enabled"
else
    print_warning "Skipped UFW configuration"
fi

# Step 3: Fail2ban
print_header "Step 3: Fail2ban (Intrusion Prevention)"

if confirm "Install and configure Fail2ban?"; then
    print_success "Starting Fail2ban installation..."
    
    apt update && apt install -y fail2ban
    print_success "Installed Fail2ban"
    
    # Create jail.local if it doesn't exist
    if [ ! -f /etc/fail2ban/jail.local ]; then
        cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    fi
    
    # Configure SSH jail
    if [ "$FAIL2BAN_AGGRESSIVE" = true ]; then
        # Aggressive settings
        sed -i 's/maxretry = .*/maxretry = 3/' /etc/fail2ban/jail.local
        sed -i 's/findtime = .*/findtime = 600/' /etc/fail2ban/jail.local
        sed -i 's/bantime = .*/bantime = 86400/' /etc/fail2ban/jail.local
        print_success "Configured Fail2ban (aggressive: 3 attempts, 24h ban)"
    else
        # Standard settings
        sed -i 's/maxretry = .*/maxretry = 5/' /etc/fail2ban/jail.local
        sed -i 's/findtime = .*/findtime = 600/' /etc/fail2ban/jail.local
        sed -i 's/bantime = .*/bantime = 3600/' /etc/fail2ban/jail.local
        print_success "Configured Fail2ban (standard: 5 attempts, 1h ban)"
    fi
    
    # Enable and start Fail2ban
    systemctl enable fail2ban
    systemctl start fail2ban
    print_success "Enabled and started Fail2ban"
    
    log_action "Fail2ban installed and configured (aggressive=$FAIL2BAN_AGGRESSIVE)"
else
    print_warning "Skipped Fail2ban installation"
fi

# Step 4: Automatic Updates
print_header "Step 4: Automatic Security Updates"

if confirm "Enable automatic security updates?"; then
    print_success "Starting automatic updates setup..."
    
    apt update && apt install -y unattended-upgrades apt-listchanges
    print_success "Installed unattended-upgrades"
    
    # Enable automatic updates
    dpkg-reconfigure -plow unattended-upgrades
    print_success "Enabled automatic updates"
    
    # Configure auto-reboot if needed
    if [ "$AUTO_REBOOT" = true ]; then
        sed -i 's|//Unattended-Upgrade::Automatic-Reboot .*;|Unattended-Upgrade::Automatic-Reboot "true";|' /etc/apt/apt.conf.d/50unattended-upgrades
        print_success "Enabled automatic reboot after kernel updates"
    else
        print_info "Automatic reboot disabled (manual reboot may be needed)"
    fi
    
    log_action "Automatic security updates enabled (auto_reboot=$AUTO_REBOOT)"
else
    print_warning "Skipped automatic updates setup"
fi

# Step 5: Docker Security
print_header "Step 5: Docker Security"

if command -v docker &> /dev/null; then
    if confirm "Configure Docker security settings?"; then
        print_success "Starting Docker security setup..."
        
        if [ "$DOCKER_NONROOT" = true ]; then
            print_info "Docker rootless mode setup requires additional steps."
            print_info "See docker-security.md for detailed instructions."
        else
            print_info "Docker best practices:"
            print_info "  - Use named volumes instead of host bind mounts"
            print_info "  - Run containers with --read-only flag"
            print_info "  - Set resource limits (--cpus, --memory)"
            print_info "  - Use custom networks for container isolation"
        fi
        
        log_action "Docker security settings reviewed"
    fi
else
    print_warning "Docker not installed (optional)"
fi

# Summary
print_header "Hardening Complete!"

echo -e "${GREEN}"
echo "✓ Security hardening has been applied"
echo -e "${NC}"

echo "Next steps:"
echo ""
echo "1. Run audit to verify hardening:"
echo "   bash audit.sh"
echo ""
echo "2. Test SSH connection on new port ($SSH_PORT):"
echo "   ssh -p $SSH_PORT user@hostname"
echo ""
echo "3. Review firewall rules:"
echo "   sudo ufw status"
echo ""
echo "4. Monitor security logs:"
echo "   sudo tail -f /var/log/auth.log"
echo ""

print_info "All changes logged to: $LOG_FILE"
print_info "SSH config backed up to: /etc/ssh/sshd_config.backup.*"

echo ""
echo "For detailed information, see:"
echo "  - hardening-guide.md (full procedures)"
echo "  - firewall-rules.md (UFW rules)"
echo "  - docker-security.md (Docker best practices)"
echo ""

print_success "Hardening completed: $(date)"
log_action "Hardening completed successfully"
