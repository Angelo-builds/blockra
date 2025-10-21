#!/usr/bin/env bash
# =========================================================
# 🧱 Blockra LXC Installer for Proxmox VE
# Author: Angelo-builds
# =========================================================

set -e

APP="Blockra"
var_os="debian"
var_ver="13"
REPO_URL="https://github.com/Angelo-builds/blockra.git"
INSTALL_SCRIPT="https://raw.githubusercontent.com/Angelo-builds/blockra/main/ct/install_blockra.sh"

source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
header_info
echo -e "  🧩 Installing ${APP} on Proxmox VE using Community Framework...\n"

start
build_container

msg_info "Fetching full Blockra project..."
pct exec ${CTID} -- bash -c "apt-get update -y && apt-get install -y curl git tar >/dev/null"
pct exec ${CTID} -- bash -c "mkdir -p /opt/blockra && curl -L https://github.com/Angelo-builds/blockra/archive/refs/heads/main.tar.gz | tar -xz --strip-components=1 -C /opt/blockra"
msg_ok "Project files ready in /opt/blockra"

msg_info "Running installer..."
pct exec ${CTID} -- bash -c "curl -fsSL ${INSTALL_SCRIPT} | bash"
msg_ok "Installation script executed."

clear
msg_ok "Blockra installation completed successfully!"
REAL_IP=$(pct exec ${CTID} -- hostname -I | awk '{print $1}')
echo ""
echo "  💡 Access your ${APP} app at:"
echo "   🌍  http://${REAL_IP}:3000"
echo ""
cat <<'EOF'
    ____  __           __        
   / __ )/ /___  _____/ /__ _________ _
  / __  / / __ \/ ___/ //_// ___/ __ `/ 
 / /_/ / / /_/ / /__/ ,<  / /  / /_/ / 
/_____/_/\____/\___/_/|_|/_/   \__,_/
EOF
msg_ok "[Blockra] Deployment complete — Have a great day!"
