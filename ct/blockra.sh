#!/usr/bin/env bash
# ==============================================================================
# 🚀 Blockra LXC Installer for Proxmox VE
# Maintainer: Angelo-builds
# ==============================================================================

set -e

APP="Blockra"
var_os="debian"
var_ver="13"
REPO_URL="https://github.com/Angelo-builds/blockra.git"
INSTALL_SCRIPT="https://raw.githubusercontent.com/Angelo-builds/blockra/main/ct/install_blockra.sh"

# --- Load the community build framework --------------------------------------
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

# --- Define App Metadata ------------------------------------------------------
header_info
echo -e "  🧩 Installing ${APP} on Proxmox VE using Community Framework...\n"

# --- Defaults ---------------------------------------------------------------
var_tags="blockra"
var_disk="8"
var_cpu="2"
var_ram="2048"
var_unprivileged="1"
var_os_release="${var_os}-${var_ver}-standard_${var_ver}-1_amd64.tar.zst"
TEMPLATE="local:vztmpl/${var_os_release}"

# --- Prompt user with standard/advanced menu ---------------------------------
start
build_container

# --- Static IP fix (host-side) -----------------------------------------------
if [[ -n "${var_ip}" && "${var_ip}" != "dhcp" ]]; then
  CONF_PATH="/etc/pve/lxc/${CTID}.conf"
  msg_info "Applying static IP configuration to ${CONF_PATH}"
  sed -i "s|ip=.*|ip=${var_ip},gw=${var_gw:-192.168.1.1}|" "$CONF_PATH" || true
  msg_ok "Static IP ${var_ip} set successfully."
fi

# --- Clone repository inside container --------------------------------------
msg_info "Cloning ${APP} repository..."
pct exec ${CTID} -- bash -c "apt-get update -y >/dev/null && apt-get install -y git >/dev/null"
pct exec ${CTID} -- bash -c "git clone ${REPO_URL} /opt/blockra >/dev/null"
msg_ok "Repository cloned."

# --- Export variables for installer -----------------------------------------
pct exec ${CTID} -- bash -c "echo VAR_IP='${var_ip%/*}' >> /etc/environment"
pct exec ${CTID} -- bash -c "echo VAR_GW='${var_gw}' >> /etc/environment"

# --- Run installer inside container -----------------------------------------
msg_info "Running ${APP} installer..."
pct exec ${CTID} -- bash -c "curl -fsSL ${INSTALL_SCRIPT} | bash"
msg_ok "Installation script executed."

# --- Health Check -----------------------------------------------------------
msg_info "Performing health check..."
sleep 5
if [[ -n "${var_ip}" ]]; then
  if pct exec ${CTID} -- bash -c "ss -tulpn | grep -q ':3000'"; then
    msg_ok "${APP} is running and listening on port 3000"
  else
    msg_warn "${APP} did not start automatically. Check logs with: journalctl -u blockra.service -b"
  fi
fi

# --- Final Message ----------------------------------------------------------
clear
msg_ok "Blockra installation completed successfully!"
echo ""

# Recupera IP reale dal container
REAL_IP=$(pct exec ${CTID} -- hostname -I 2>/dev/null | awk '{print $1}')

echo "  💡 Access your ${APP} app at:"
if [[ -n "${REAL_IP}" ]]; then
  echo "   🌍  http://${REAL_IP}:3000"
else
  echo "   🌍  (Check DHCP IP with: pct exec ${CTID} -- ip a show eth0)"
fi
echo ""
cat <<'EOF'
    ____  __           __        
   / __ )/ /___  _____/ /__ _________ _
  / __  / / __ \/ ___/ //_// ___/ __ `/ 
 / /_/ / / /_/ / /__/ ,<  / /  / /_/ / 
/_____/_/\____/\___/_/|_|/_/   \__,_/

EOF
msg_ok "[Blockra] Deployment complete — Have a great day!"
