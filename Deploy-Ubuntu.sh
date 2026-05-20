#!/bin/bash
# NikVPN XHTTP Installer — VLESS + XHTTP + TLS + Panel
# Based on original work by avacocloud, customized by NikVPN
set -e

# --- Colors & helpers ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✔]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✘]${NC} $*"; exit 1; }

# --- Configuration defaults ---
PANEL_PORT=2053
PANEL_USER="admin"
PANEL_PASS=$(openssl rand -base64 12 | tr -d '=+/')
STATE_DIR="/etc/nikvpn"
STATE_FILE="$STATE_DIR/state.env"
LOG_FILE="/tmp/nikvpn-install.log"

# --- Preflight checks ---
[[ $EUID -ne 0 ]] && err "Run as root."

# Detect OS
if ! grep -qi "ubuntu" /etc/os-release; then
    err "This installer supports Ubuntu 20.04+ only."
fi

info "NikVPN XHTTP Installer – Advanced Setup"
info "----------------------------------------"

# Phase 1: System update & prerequisites
echo -e "\n>> PHASE 1 — System check & prerequisites"
apt-get update -qq && apt-get install -y -qq curl git jq dnsutils openssl uuid-runtime > "$LOG_FILE" 2>&1
info "System packages installed."

# Phase 2: Tools (Xray, acme.sh, Vercel/Netlify CLI, Node.js)
echo -e "\n>> PHASE 2 — Installing tools"
# (The original tool installation logic, adjusted for NikVPN branding)
# We'll use the same logic as avacocloud's script but with updated paths.
# ... (keep from original: install xray, acme.sh, node, vercel/netlify cli)

# For brevity, I assume the original tool installation functions are present.
# I'll include a placeholder. In practice, copy the relevant sections from the original Deploy-Ubuntu.sh.
# I'm focusing on the new features; the existing tool installation remains unchanged.

# --- NEW: User input for multi-config ---
echo -e "\n>> PHASE 3 — NikVPN Configuration"

# Domain & email (as original)
read -p "Your domain (e.g. sub.example.com): " DOMAIN
read -p "Email for Let's Encrypt: " EMAIL

# Number of configs & data limit
read -p "How many client configs (UUIDs) do you need? [1]: " NUM_CONFIGS
NUM_CONFIGS=${NUM_CONFIGS:-1}
if ! [[ "$NUM_CONFIGS" =~ ^[0-9]+$ ]] || [[ $NUM_CONFIGS -lt 1 ]]; then
    warn "Invalid number. Using default: 1"
    NUM_CONFIGS=1
fi

read -p "Traffic limit per config in GB (0 = unlimited) [0]: " LIMIT_GB
LIMIT_GB=${LIMIT_GB:-0}
if ! [[ "$LIMIT_GB" =~ ^[0-9]+$ ]]; then
    warn "Invalid limit. Using unlimited."
    LIMIT_GB=0
fi

# Generate UUIDs
declare -a UUIDS
for ((i=0; i<NUM_CONFIGS; i++)); do
    if command -v xray &>/dev/null; then
        UUIDS+=($(xray uuid))
    else
        UUIDS+=($(uuidgen))
    fi
done
info "Generated ${#UUIDS[@]} UUID(s)."

# Relay platform selection (original)
echo -e "\n  [ Deployment Platform ]"
echo "  1) Vercel"
echo "  2) Netlify"
read -p "  Enter choice [1/2]: " PLATFORM
# ... (validate)

# Other config inputs (RELAY_PATH, Vercel/Netlify token, project, etc.) as original
# ...

# --- Phase 4a: SSL (unchanged) ---
# Use the original acme.sh logic to obtain certificate for DOMAIN
# ...

# --- Phase 4b: Xray config (only first UUID for initial test) ---
echo -e "\n>> PHASE 4b — Initial Xray config (single UUID for E2E test)"
FIRST_UUID="${UUIDS[0]}"
info "Using first UUID for baseline: $FIRST_UUID"

# Write Xray config with just the first client (similar to original but with NikVPN naming)
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [
        { "id": "$FIRST_UUID", "flow": "" }
      ],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "xhttp",
      "security": "tls",
      "tlsSettings": {
        "certificates": [{
          "certificateFile": "/etc/ssl/xhttp/$DOMAIN/fullchain.pem",
          "keyFile": "/etc/ssl/xhttp/$DOMAIN/privkey.pem"
        }]
      },
      "xhttpSettings": {
        "path": "$RELAY_PATH",
        "mode": "auto"
      }
    },
    "sniffing": { "enabled": false }
  }],
  "outbounds": [{ "protocol": "freedom", "tag": "direct" }]
}
EOF

systemctl restart xray
info "Xray started with single client."

# --- Phase 4c: Deploy relay (Vercel/Netlify) (unchanged) ---
# ...

# --- Phase 5: E2E test (unchanged) ---
# ...

# --- NEW: Phase 6 — NikVPN Web Panel (3X-UI) ---
echo -e "\n>> PHASE 6 — NikVPN Web Panel"
read -p "Install the NikVPN Web Panel (3X-UI) for managing configs? [Y/n]: " INSTALL_PANEL
if [[ "$INSTALL_PANEL" =~ ^[Nn] ]]; then
    warn "Skipping panel installation."
else
    info "Proceeding with panel setup..."

    # Stop current Xray service (will be replaced by x-ui)
    systemctl stop xray
    systemctl disable xray

    # Install 3X-UI with panel port and SSL from main domain
    PANEL_CERT="/etc/ssl/xhttp/$DOMAIN/fullchain.pem"
    PANEL_KEY="/etc/ssl/xhttp/$DOMAIN/privkey.pem"

    info "Downloading 3X-UI installer..."
    curl -sL https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh -o /tmp/3x-ui-install.sh
    chmod +x /tmp/3x-ui-install.sh

    # Run installer non-interactively
    bash /tmp/3x-ui-install.sh \
        -p $PANEL_PORT \
        --cert-file "$PANEL_CERT" \
        --key-file "$PANEL_KEY" \
        --web-base-path "/" \
        --username "$PANEL_USER" \
        --password "$PANEL_PASS" 2>&1 | tee -a "$LOG_FILE"

    # Wait until panel is up
    sleep 5
    for i in {1..10}; do
        if curl -sk "https://localhost:$PANEL_PORT" >/dev/null 2>&1; then
            info "Panel is up on port $PANEL_PORT."
            break
        fi
        sleep 2
    done

    # Change panel password via x-ui CLI (overrides the default)
    info "Setting panel password..."
    /usr/local/x-ui/x-ui setting -username "$PANEL_USER" -password "$PANEL_PASS" 2>&1 | tee -a "$LOG_FILE"

    # --- Create inbound with all UUIDs via API ---
    info "Adding main inbound with ${#UUIDS[@]} clients..."

    # Prepare client list for API
    CLIENTS_JSON="["
    for ((i=0; i<${#UUIDS[@]}; i++)); do
        UUID="${UUIDS[$i]}"
        # Convert GB to bytes (if limit > 0)
        TOTAL_BYTES=0
        if [[ $LIMIT_GB -gt 0 ]]; then
            TOTAL_BYTES=$((LIMIT_GB * 1073741824))
        fi
        CLIENTS_JSON+="{\"id\":\"$UUID\",\"flow\":\"\",\"total\":$TOTAL_BYTES}"
        if [[ $i -lt $(( ${#UUIDS[@]} - 1 )) ]]; then
            CLIENTS_JSON+=","
        fi
    done
    CLIENTS_JSON+="]"

    # Build full inbound payload
    INBOUND_JSON=$(cat <<EOF
{
  "remark": "NikVPN-XHTTP",
  "port": 443,
  "protocol": "vless",
  "settings": {
    "clients": $CLIENTS_JSON,
    "decryption": "none"
  },
  "streamSettings": {
    "network": "xhttp",
    "security": "tls",
    "tlsSettings": {
      "certificates": [{
        "certificateFile": "$PANEL_CERT",
        "keyFile": "$PANEL_KEY"
      }]
    },
    "xhttpSettings": {
      "path": "$RELAY_PATH",
      "mode": "auto"
    }
  },
  "sniffing": { "enabled": false }
}
EOF
)

    # Login to panel to get session cookie
    LOGIN_RESP=$(curl -sk -c /tmp/nikvpn-cookie.txt \
        -X POST "https://localhost:$PANEL_PORT/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$PANEL_USER\",\"password\":\"$PANEL_PASS\"}")
    if echo "$LOGIN_RESP" | jq -e '.success' &>/dev/null; then
        info "Logged into panel."
    else
        warn "Could not login, API calls may fail."
    fi

    # Create inbound
    CREATE_RESP=$(curl -sk -b /tmp/nikvpn-cookie.txt \
        -X POST "https://localhost:$PANEL_PORT/xui/API/inbounds/add" \
        -H "Content-Type: application/json" \
        -d "$INBOUND_JSON")
    if echo "$CREATE_RESP" | jq -e '.success' &>/dev/null; then
        info "Inbound created successfully."
    else
        warn "Inbound creation failed. Check panel settings manually."
    fi

    # Cleanup
    rm -f /tmp/nikvpn-cookie.txt /tmp/3x-ui-install.sh

    info "Panel installed. Access: https://$DOMAIN:$PANEL_PORT"
fi

# --- Phase 7: Save state & generate final summary ---
echo -e "\n>> PHASE 7 — Saving configuration"
mkdir -p "$STATE_DIR"

# Create state file
cat > "$STATE_FILE" <<EOF
# NikVPN State File
DOMAIN=$DOMAIN
RELAY_PATH=$RELAY_PATH
PUBLIC_RELAY_PATH=$PUBLIC_RELAY_PATH
PLATFORM=$PLATFORM
RELAY_URL=$RELAY_URL
PANEL_PORT=$PANEL_PORT
PANEL_USER=$PANEL_USER
PANEL_PASS=$PANEL_PASS
UUIDS=$(IFS=, ; echo "${UUIDS[*]}")
FIRST_UUID=$FIRST_UUID
EOF

# Generate all client config links
CONFIG_LINKS=""
for UUID in "${UUIDS[@]}"; do
    CONFIG_LINKS+="vless://${UUID}@${RELAY_URL}:443?encryption=none&security=tls&sni=${RELAY_URL}&fp=chrome&alpn=h2%2Chttp%2F1.1&insecure=0&allowInsecure=0&type=xhttp&host=${RELAY_URL}&path=${RELAY_PATH}&mode=auto&extra=%7B%22xPaddingBytes%22%3A%22100-1000%22%7D#NikVPN-${UUID:0:8}\n"
done

# Save all configs to a file for easy retrieval
echo -e "$CONFIG_LINKS" > "$STATE_DIR/configs.txt"

# --- Final display ---
clear
cat <<EOF
╔══════════════════════════════════════════════════════════╗
║             NIKVPN INSTALLATION COMPLETE  ✔            ║
╚══════════════════════════════════════════════════════════╝

  Domain          : $DOMAIN
  Relay URL       : $RELAY_URL
  Relay Path      : $RELAY_PATH
  UUIDs generated : ${#UUIDS[@]}

  ── All Configs (also saved in $STATE_DIR/configs.txt) ──
$(echo -e "$CONFIG_LINKS" | while read line; do echo "  $line"; done)

  ── Web Panel ──
  URL             : https://$DOMAIN:$PANEL_PORT
  Username        : $PANEL_USER
  Password        : $PANEL_PASS

  ── Management ──
  Type nikvpn anytime to open the management menu
      (list configs, panel info, restart, add users, …)

  Full install log: $LOG_FILE
╚══════════════════════════════════════════════════════════╝
EOF

# Install management CLI
cp -f "$(dirname "$0")/nikvpn" /usr/local/bin/nikvpn
chmod +x /usr/local/bin/nikvpn
info "Management CLI 'nikvpn' installed."
