#!/bin/bash
# NikVPN XHTTP Installer — Bootstrap
# Copyright (C) 2026 nikvpn-iran
# Based on XHTTP-Installer by avacocloud (GPL-3.0)
# License: GPL-3.0-only
# Repo: https://github.com/nikvpn-iran/NikVPN-xhttp-installer
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✔]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✘]${NC} $*"; exit 1; }

if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root."
fi

info "NikVPN XHTTP Installer — Bootstrap"
info "Cloning repository..."

# Install git if missing
if ! command -v git &>/dev/null; then
    warn "git not found. Installing..."
    apt-get update -qq && apt-get install -y -qq git
fi

REPO_DIR="/root/nikvpn-xhttp-installer"
if [[ -d "$REPO_DIR" ]]; then
    warn "Directory $REPO_DIR already exists. Updating..."
    cd "$REPO_DIR"
    git pull origin main || git pull origin master || true
else
    git clone https://github.com/nikvpn-iran/NikVPN-xhttp-installer.git "$REPO_DIR"
fi

cd "$REPO_DIR"
chmod +x Deploy-Ubuntu.sh
info "Starting main installer..."
./Deploy-Ubuntu.sh

# ============================================================
# Ask to install HiddifyManager panel after main installation
# ============================================================
echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}XHTTP installation completed!${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
echo ""

read -p "$(echo -e "${YELLOW}Do you want to install HiddifyManager panel for user management? (supports XHTTP/Vercel) [y/N]: ${NC}")" -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "Installing HiddifyManager panel..."
    
    apt-get update -qq
    apt-get install -y -qq curl wget ufw socat
    
    bash <(curl -sSL https://raw.githubusercontent.com/hiddify/hiddify-manager/main/install.sh)
    
    if systemctl is-active --quiet hiddify-panel; then
        info "HiddifyManager installed successfully!"
        info "Access panel at: http://$(curl -s ifconfig.me):8080"
        echo ""
        echo -e "${GREEN}⚠️ IMPORTANT:${NC}"
        info "To use with your Vercel XHTTP config, add your Vercel domain as 'Relay Domain' in panel settings."
        info "Default login credentials will be shown after installation completes."
    else
        warn "HiddifyManager installation may have failed. Check manually."
        info "You can install later with: bash <(curl -sSL https://raw.githubusercontent.com/hiddify/hiddify-manager/main/install.sh)"
    fi
else
    info "Skipping HiddifyManager installation. You can install later with:"
    echo "  bash <(curl -sSL https://raw.githubusercontent.com/hiddify/hiddify-manager/main/install.sh)"
fi

info "All done! Type 'xhttp' to manage your XHTTP config."
if [[ $REPLY =~ ^[Yy]$ ]] && systemctl is-active --quiet hiddify-panel; then
    echo ""
    info "HiddifyManager is running. Access it via browser to configure users, traffic limits, and IP restrictions."
fi
