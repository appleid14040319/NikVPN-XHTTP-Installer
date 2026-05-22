#!/bin/bash
# NikVPN XHTTP Installer — VLESS + XHTTP + TLS + 3X-UI Panel
# Copyright (C) 2026 nikvpn-iran
# Based on XHTTP-Installer by avacocloud (GPL-3.0)
# License: GPL-3.0-only
# Repo: https://github.com/nikvpn-iran/NikVPN-xhttp-installer
# NikVPN build ID: nkv-2026-010-nikvpn
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
XRAY_CONFIG="/usr/local/etc/xray/config.json"
SSL_BASE="/etc/ssl/xhttp"

# --- Preflight checks ---
[[ $EUID -ne 0 ]] && err "This script must be run as root."
if ! grep -qi "ubuntu" /etc/os-release; then
    err "This installer supports Ubuntu 20.04+ only."
fi

# ==============================================
#  SCREEN PERSISTENCE (prevent SSH drop)
# ==============================================
if [[ -z "${STY:-}" && -z "${TMUX:-}" ]]; then
    echo ""
    echo -e "${YELLOW}⚠ You are NOT inside screen/tmux.${NC}"
    echo -e "${YELLOW}  If your SSH disconnects, the installation will die mid-way.${NC}"
    echo -e "${YELLOW}  Recommended: run inside screen so you can reattach later.${NC}"
    echo ""
    read -p "  Auto-launch inside screen? [Y/n]: " USE_SCREEN
    USE_SCREEN=${USE_SCREEN:-y}

    if [[ "$USE_SCREEN" =~ ^[Yy] ]]; then
        if ! command -v screen &>/dev/null; then
            apt-get update -qq && apt-get install -y -qq screen
        fi

        SESSION_NAME="nikvpn"
        SCRIPT_PATH=$(realpath "$0")

        if screen -list | grep -q "\.${SESSION_NAME}\s"; then
            echo ""
            echo -e "  ${YELLOW}⚠ Existing screen session '${SESSION_NAME}' found.${NC}"
            echo "  1) Reattach to it     (continue what was running)"
            echo "  2) Kill it & start fresh"
            echo "  3) Cancel"
            read -p "  Choose [1/2/3]: " RESUME_CHOICE
            case "$RESUME_CHOICE" in
                1)
                    exec screen -r "$SESSION_NAME"
                    ;;
                2)
                    screen -S "$SESSION_NAME" -X quit
                    exec screen -S "$SESSION_NAME" bash "$SCRIPT_PATH"
                    ;;
                *)
                    err "Installation cancelled."
                    ;;
            esac
        else
            exec screen -S "$SESSION_NAME" bash "$SCRIPT_PATH"
        fi
    fi
fi

# ==============================================
#  BANNER & PLATFORM SELECTION
# ==============================================
clear
cat <<'BANNER'
   ███╗   ██╗██╗██╗  ██╗██╗   ██╗██████╗ ███╗   ██╗
   ████╗  ██║██║██║ ██╔╝██║   ██║██╔══██╗████╗  ██║
   ██╔██╗ ██║██║█████╔╝ ██║   ██║██████╔╝██╔██╗ ██║
   ██║╚██╗██║██║██╔═██╗ ╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║
   ██║ ╚████║██║██║  ██╗ ╚████╔╝ ██║     ██║ ╚████║
   ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝     ╚═╝  ╚═══╝

   ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗
   ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗
   ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝
   ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██╔══╝  ██╔══██╗
   ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║
   ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝

          ★  N I K V P N   I N S T A L L E R  ★
          ─────────────────────────────────
          VLESS + XHTTP + TLS
          Ubuntu Auto-Installer
          Relay: Vercel / Netlify
          github.com/nikvpn-iran/NikVPN-xhttp-installer

  Important: Make sure your domain DNS A-record points to this server IP before continuing.
  Tip: Press Ctrl+C at any time to abort.

BANNER

echo "  [ Deployment Platform ]"
echo "  Choose relay platform:"
echo "    1) Vercel"
echo "    2) Netlify"
read -p "  Enter choice [1/2]: " PLATFORM_CHOICE

if [[ "$PLATFORM_CHOICE" == "1" ]]; then
    PLATFORM="vercel"
elif [[ "$PLATFORM_CHOICE" == "2" ]]; then
    PLATFORM="netlify"
else
    err "Invalid choice. Run the script again."
fi

info "Platform: $PLATFORM"
echo ""
read -p "  Press Enter to start installation..."

# ==============================================
# PHASE 1 – System update & base packages
# ==============================================
echo -e "\n>> PHASE 1 — System check & prerequisites"
apt-get update -qq
apt-get install -y -qq curl git jq dnsutils openssl uuid-runtime ca-certificates gnupg2 software-properties-common > "$LOG_FILE" 2>&1
info "Base dependencies installed."

# ==============================================
# PHASE 2 – Tools installation
# ==============================================
echo -e "\n>> PHASE 2 — Installing tools"

# --- Xray ---
if ! command -v xray &>/dev/null; then
    info "Installing Xray..."
    bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --beta 2>&1 | tee -a "$LOG_FILE"
    info "Xray installed: $(xray version | head -1)"
else
    info "Xray already present: $(xray version | head -1)"
fi

# --- acme.sh ---
if ! command -v acme.sh &>/dev/null; then
    info "Installing acme.sh..."
    curl -sL https://get.acme.sh | sh -s email=admin@nikvpn.local 2>&1 | tee -a "$LOG_FILE"
    source ~/.bashrc 2>/dev/null || true
    export PATH="$HOME/.acme.sh:$PATH"
    info "acme.sh installed."
else
    info "acme.sh already installed."
fi

# --- Node.js (LTS) ---
if ! command -v node &>/dev/null; then
    info "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - 2>&1 | tee -a "$LOG_FILE"
    apt-get install -y -qq nodejs 2>&1 | tee -a "$LOG_FILE"
    info "Node.js $(node -v) installed."
else
    info "Node.js $(node -v) already present."
fi

# --- Vercel CLI ---
if ! command -v vercel &>/dev/null; then
    info "Installing Vercel CLI..."
    npm install -g vercel@latest 2>&1 | tee -a "$LOG_FILE"
    info "Vercel CLI installed: $(vercel --version)"
else
    info "Vercel CLI already present: $(vercel --version)"
fi

# --- Netlify CLI ---
if ! command -v netlify &>/dev/null; then
    info "Installing Netlify CLI..."
    npm install -g netlify-cli@latest 2>&1 | tee -a "$LOG_FILE"
    info "Netlify CLI installed: $(netlify --version)"
else
    info "Netlify CLI already present: $(netlify --version)"
fi

# --- xray-knife (for testing) ---
if ! command -v xray-knife &>/dev/null; then
    info "Installing xray-knife..."
    arch=$(uname -m)
    case $arch in
        x86_64)  knf="xray-knife-linux-64" ;;
        aarch64) knf="xray-knife-linux-arm64" ;;
        *) err "Unsupported architecture for xray-knife" ;;
    esac
    curl -sL "https://github.com/lilendian0x00/xray-knife/releases/latest/download/${knf}" -o /usr/local/bin/xray-knife
    chmod +x /usr/local/bin/xray-knife
    info "xray-knife installed."
else
    info "xray-knife already present."
fi

# ==============================================
# PHASE 3 – User input
# ==============================================
echo -e "\n>> PHASE 3 — NikVPN Configuration"
echo "  Important: Make sure your domain DNS A-record points to this server IP before continuing."

# Domain & email
read -p "Your domain (e.g. sub.example.com): " DOMAIN
read -p "Email for Let's Encrypt (real address): " EMAIL

# Number of configs & traffic limit
read -p "How many client configs (UUIDs) do you need? [1]: " NUM_CONFIGS
NUM_CONFIGS=${NUM_CONFIGS:-1}
[[ "$NUM_CONFIGS" =~ ^[0-9]+$ ]] && [[ $NUM_CONFIGS -ge 1 ]] || NUM_CONFIGS=1

read -p "Traffic limit per config in GB (0 = unlimited) [0]: " LIMIT_GB
LIMIT_GB=${LIMIT_GB:-0}
[[ "$LIMIT_GB" =~ ^[0-9]+$ ]] || LIMIT_GB=0

# Generate UUIDs
declare -a UUIDS
for ((i=0; i<NUM_CONFIGS; i++)); do
    UUIDS+=($(xray uuid))
done
info "Generated ${#UUIDS[@]} UUID(s)."

# ── Relay paths & performance settings (platform already selected above) ──
read -p "RELAY_PATH (inbound path, e.g. /api) [/api]: " RELAY_PATH
RELAY_PATH=${RELAY_PATH:-/api}
read -p "PUBLIC_RELAY_PATH (public path) [/api]: " PUBLIC_RELAY_PATH
PUBLIC_RELAY_PATH=${PUBLIC_RELAY_PATH:-/api}
read -p "MAX_INFLIGHT [128]: " MAX_INFLIGHT
MAX_INFLIGHT=${MAX_INFLIGHT:-128}
read -p "MAX_UP_BPS [2621440]: " MAX_UP_BPS
MAX_UP_BPS=${MAX_UP_BPS:-2621440}
read -p "MAX_DOWN_BPS [2621440]: " MAX_DOWN_BPS
MAX_DOWN_BPS=${MAX_DOWN_BPS:-2621440}
read -p "UPSTREAM_TIMEOUT_MS [50000]: " UPSTREAM_TIMEOUT_MS
UPSTREAM_TIMEOUT_MS=${UPSTREAM_TIMEOUT_MS:-50000}
read -p "SUCCESS_LOG_SAMPLE_RATE [0]: " SUCCESS_LOG_SAMPLE_RATE
SUCCESS_LOG_SAMPLE_RATE=${SUCCESS_LOG_SAMPLE_RATE:-0}
read -p "SUCCESS_LOG_MIN_DURATION_MS [3000]: " SUCCESS_LOG_MIN_DURATION_MS
SUCCESS_LOG_MIN_DURATION_MS=${SUCCESS_LOG_MIN_DURATION_MS:-3000}
read -p "ERROR_LOG_MIN_INTERVAL_MS [5000]: " ERROR_LOG_MIN_INTERVAL_MS
ERROR_LOG_MIN_INTERVAL_MS=${ERROR_LOG_MIN_INTERVAL_MS:-5000}

# Platform-specific inputs
if [[ "$PLATFORM" == "vercel" ]]; then
    read -p "Vercel API token: " VERCEL_TOKEN
    read -p "Vercel project name [nikvpn-relay]: " VERCEL_PROJECT
    VERCEL_PROJECT=${VERCEL_PROJECT:-nikvpn-relay}
    read -p "Vercel scope/team slug (leave blank for personal): " VERCEL_SCOPE
else
    read -p "Netlify personal access token: " NETLIFY_TOKEN
    read -p "Netlify site name [nikvpn-relay]: " NETLIFY_SITE
    NETLIFY_SITE=${NETLIFY_SITE:-nikvpn-relay}
fi

# Summary and confirmation
cat <<EOF

  ────────────── SUMMARY ──────────────
  Platform        : $PLATFORM
  Domain          : $DOMAIN
  Inbound port    : 443
  RELAY_PATH      : $RELAY_PATH
  PUBLIC_PATH     : $PUBLIC_RELAY_PATH
  Configs/UUIDs   : $NUM_CONFIGS
  Traffic limit   : ${LIMIT_GB} GB per config
  MAX_INFLIGHT    : $MAX_INFLIGHT
  MAX_UP_BPS      : $MAX_UP_BPS
  MAX_DOWN_BPS    : $MAX_DOWN_BPS
  TIMEOUT_MS      : $UPSTREAM_TIMEOUT_MS
  SUCCESS_LOG     : $SUCCESS_LOG_SAMPLE_RATE
  SUCCESS_DUR_MS  : $SUCCESS_LOG_MIN_DURATION_MS
  ERROR_INT_MS    : $ERROR_LOG_MIN_INTERVAL_MS
  ─────────────────────────────────────

EOF
read -p "Proceed with these settings? [Y/n]: " CONFIRM
if [[ "$CONFIRM" =~ ^[Nn] ]]; then
    err "Installation aborted by user."
fi

# ==============================================
# PHASE 4a – Obtain SSL certificate
# ==============================================
echo -e "\n>> PHASE 4a — Obtaining SSL certificate for $DOMAIN"
CERT_DIR="$SSL_BASE/$DOMAIN"
mkdir -p "$CERT_DIR"

# Ensure port 80 is free
systemctl stop nginx 2>/dev/null || true
systemctl stop apache2 2>/dev/null || true

info "Issuing certificate via acme.sh standalone mode..."
~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --keylength ec-256 --listen-v4 2>&1 | tee -a "$LOG_FILE"
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
    --cert-file "$CERT_DIR/cert.pem" \
    --key-file "$CERT_DIR/privkey.pem" \
    --fullchain-file "$CERT_DIR/fullchain.pem" \
    --reloadcmd "systemctl restart xray 2>/dev/null || systemctl restart x-ui 2>/dev/null || true" 2>&1 | tee -a "$LOG_FILE"
info "SSL certificate installed → $CERT_DIR/fullchain.pem"

# ==============================================
# PHASE 4b – Initial Xray config (E2E test)
# ==============================================
echo -e "\n>> PHASE 4b — Xray VLESS+XHTTP+TLS inbound (test)"
FIRST_UUID="${UUIDS[0]}"
info "Using first UUID for baseline test: $FIRST_UUID"

cat > "$XRAY_CONFIG" <<EOF
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
          "certificateFile": "$CERT_DIR/fullchain.pem",
          "keyFile": "$CERT_DIR/privkey.pem"
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

# Force xray to run as root (required for port 443)
mkdir -p /etc/systemd/system/xray.service.d
cat > /etc/systemd/system/xray.service.d/override.conf <<EOF
[Service]
User=root
EOF
systemctl daemon-reload
systemctl restart xray
sleep 2
if ! systemctl is-active --quiet xray; then
    err "Xray failed to start. Check logs."
fi
info "Xray running on port 443."

# Quick local test
if curl -sk "https://localhost:443$RELAY_PATH" 2>&1 | grep -q '404'; then
    info "Local Xray endpoint test: OK (expected 404)"
else
    warn "Local endpoint test may have failed, but continuing..."
fi

# ==============================================
# PHASE 4c – Deploy relay (Vercel or Netlify)
# ==============================================
echo -e "\n>> PHASE 4c — Deploying to $PLATFORM"

TARGET_DOMAIN="https://$DOMAIN:443"
cd /root/nikvpn-xhttp-installer/deploy/$PLATFORM 2>/dev/null || cd "$(dirname "$0")/deploy/$PLATFORM"

if [[ "$PLATFORM" == "vercel" ]]; then
    info "Logging in to Vercel..."
    echo "$VERCEL_TOKEN" | vercel login --token --yes 2>&1 | tee -a "$LOG_FILE"
    vercel link --project "$VERCEL_PROJECT" ${VERCEL_SCOPE:+--scope "$VERCEL_SCOPE"} --yes 2>&1 | tee -a "$LOG_FILE"
    info "Disabling Deployment Protection..."
    vercel env rm VERCEL_AUTOMATION_BYPASS_SECRET production -y 2>/dev/null || true
    vercel --prod --confirm --yes \
        --env TARGET_DOMAIN="$TARGET_DOMAIN" \
        --env RELAY_PATH="$RELAY_PATH" \
        --env PUBLIC_RELAY_PATH="$PUBLIC_RELAY_PATH" \
        --env MAX_INFLIGHT="$MAX_INFLIGHT" \
        --env MAX_UP_BPS="$MAX_UP_BPS" \
        --env MAX_DOWN_BPS="$MAX_DOWN_BPS" \
        --env UPSTREAM_TIMEOUT_MS="$UPSTREAM_TIMEOUT_MS" \
        --env SUCCESS_LOG_SAMPLE_RATE="$SUCCESS_LOG_SAMPLE_RATE" \
        --env SUCCESS_LOG_MIN_DURATION_MS="$SUCCESS_LOG_MIN_DURATION_MS" \
        --env ERROR_LOG_MIN_INTERVAL_MS="$ERROR_LOG_MIN_INTERVAL_MS" 2>&1 | tee -a "$LOG_FILE"
    RELAY_URL=$(vercel env ls 2>/dev/null | grep -oP 'https://[^ ]+\.vercel\.app' | head -1 || echo "")
    if [[ -z "$RELAY_URL" ]]; then
        RELAY_URL="https://${VERCEL_PROJECT}.vercel.app"
    fi
else
    info "Logging in to Netlify..."
    netlify login --auth="$NETLIFY_TOKEN" 2>&1 | tee -a "$LOG_FILE"
    netlify sites:create --name="$NETLIFY_SITE" 2>&1 || true
    netlify link --name="$NETLIFY_SITE" 2>&1 | tee -a "$LOG_FILE"
    netlify env:set TARGET_DOMAIN "$TARGET_DOMAIN" 2>&1
    netlify env:set RELAY_PATH "$RELAY_PATH" 2>&1
    netlify env:set PUBLIC_RELAY_PATH "$PUBLIC_RELAY_PATH" 2>&1
    netlify deploy --prod --dir=. 2>&1 | tee -a "$LOG_FILE"
    RELAY_URL="https://${NETLIFY_SITE}.netlify.app"
fi
info "Relay URL: $RELAY_URL"

# ==============================================
# PHASE 5 – E2E test (VLESS handshake)
# ==============================================
echo -e "\n>> PHASE 5 — End-to-end VLESS+XHTTP test"
info "Starting xray test client on 127.0.0.1:10809..."
cat > /tmp/nikvpn-test-client.json <<EOF
{
  "log": { "loglevel": "none" },
  "inbounds": [{ "port": 10809, "protocol": "socks", "settings": { "udp": true } }],
  "outbounds": [{
    "protocol": "vless",
    "settings": { "vnext": [{ "address": "$RELAY_URL", "port": 443, "users": [{ "id": "$FIRST_UUID", "encryption": "none" }] }] },
    "streamSettings": { "network": "xhttp", "security": "tls", "tlsSettings": { "serverName": "$RELAY_URL" }, "xhttpSettings": { "path": "$RELAY_PATH", "mode": "auto" } },
    "tag": "proxy"
  }]
}
EOF
xray run -c /tmp/nikvpn-test-client.json &>/dev/null &
TEST_PID=$!
sleep 2
if curl -x socks5h://127.0.0.1:10809 -sk "https://www.gstatic.com/generate_204" -o /dev/null -w "%{http_code}" | grep -q 204; then
    info "VLESS+XHTTP WORKS! E2E test passed."
else
    warn "E2E test did not return expected 204. Please check manually."
fi
kill $TEST_PID 2>/dev/null || true
rm -f /tmp/nikvpn-test-client.json

# ==============================================
# PHASE 6 – NikVPN Web Panel (3X-UI)
# ==============================================
echo -e "\n>> PHASE 6 — NikVPN Web Panel (3X-UI)"
read -p "Install the NikVPN Web Panel (3X-UI) for managing configs? [Y/n]: " INSTALL_PANEL
if [[ "$INSTALL_PANEL" =~ ^[Nn] ]]; then
    warn "Skipping panel installation."
else
    info "Proceeding with panel setup..."
    systemctl stop xray
    systemctl disable xray

    info "Downloading 3X-UI installer..."
    curl -sL https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh -o /tmp/3x-ui-install.sh
    chmod +x /tmp/3x-ui-install.sh
    bash /tmp/3x-ui-install.sh 2>&1 | tee -a "$LOG_FILE"

    sleep 5
    for i in {1..10}; do
        if curl -sk "https://localhost:$PANEL_PORT" >/dev/null 2>&1; then
            info "Panel is up on port $PANEL_PORT."
            break
        fi
        sleep 2
    done

    # Configure panel credentials
    /usr/local/x-ui/x-ui setting -username "$PANEL_USER" -password "$PANEL_PASS" 2>&1 | tee -a "$LOG_FILE"
    info "Panel credentials set."

    # Create inbound with all UUIDs
    info "Adding main inbound with ${#UUIDS[@]} clients..."
    CLIENTS_JSON="["
    for ((i=0; i<${#UUIDS[@]}; i++)); do
        UUID="${UUIDS[$i]}"
        TOTAL_BYTES=0
        [[ $LIMIT_GB -gt 0 ]] && TOTAL_BYTES=$((LIMIT_GB * 1073741824))
        CLIENTS_JSON+="{\"id\":\"$UUID\",\"flow\":\"\",\"total\":$TOTAL_BYTES}"
        [[ $i -lt $(( ${#UUIDS[@]} - 1 )) ]] && CLIENTS_JSON+=","
    done
    CLIENTS_JSON+="]"

    INBOUND_JSON=$(cat <<EOF
{
  "remark": "NikVPN-XHTTP",
  "port": 443,
  "protocol": "vless",
  "settings": { "clients": $CLIENTS_JSON, "decryption": "none" },
  "streamSettings": {
    "network": "xhttp", "security": "tls",
    "tlsSettings": { "certificates": [{ "certificateFile": "$CERT_DIR/fullchain.pem", "keyFile": "$CERT_DIR/privkey.pem" }] },
    "xhttpSettings": { "path": "$RELAY_PATH", "mode": "auto" }
  },
  "sniffing": { "enabled": false }
}
EOF
)

    # API login
    LOGIN_RESP=$(curl -sk -c /tmp/nikvpn-cookie.txt \
        -X POST "https://localhost:$PANEL_PORT/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$PANEL_USER\",\"password\":\"$PANEL_PASS\"}")
    if echo "$LOGIN_RESP" | jq -e '.success' &>/dev/null; then
        info "Logged into panel."
    else
        warn "Login failed, but trying to create inbound anyway."
    fi

    CREATE_RESP=$(curl -sk -b /tmp/nikvpn-cookie.txt \
        -X POST "https://localhost:$PANEL_PORT/xui/API/inbounds/add" \
        -H "Content-Type: application/json" \
        -d "$INBOUND_JSON")
    if echo "$CREATE_RESP" | jq -e '.success' &>/dev/null; then
        info "Inbound created successfully."
    else
        warn "Inbound creation failed. Check panel settings manually."
    fi

    rm -f /tmp/nikvpn-cookie.txt /tmp/3x-ui-install.sh
    info "Panel installed. Access: https://$DOMAIN:$PANEL_PORT"
fi

# ==============================================
# PHASE 7 – Save state & final summary
# ==============================================
echo -e "\n>> PHASE 7 — Saving configuration"
mkdir -p "$STATE_DIR"
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

# Generate config links
CONFIG_LINKS=""
for UUID in "${UUIDS[@]}"; do
    CONFIG_LINKS+="vless://${UUID}@${RELAY_URL}:443?encryption=none&security=tls&sni=${RELAY_URL}&fp=chrome&alpn=h2%2Chttp%2F1.1&insecure=0&allowInsecure=0&type=xhttp&host=${RELAY_URL}&path=${RELAY_PATH}&mode=auto&extra=%7B%22xPaddingBytes%22%3A%22100-1000%22%7D#NikVPN-${UUID:0:8}\n"
done
echo -e "$CONFIG_LINKS" > "$STATE_DIR/configs.txt"

# Final display
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
cp -f "$(dirname "$0")/nikvpn" /usr/local/bin/nikvpn 2>/dev/null || true
chmod +x /usr/local/bin/nikvpn 2>/dev/null || true
info "Management CLI 'nikvpn' installed (if present)."
