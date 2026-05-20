#!/bin/bash
# NikVPN XHTTP Installer — Bootstrap
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
