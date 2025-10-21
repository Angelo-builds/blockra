#!/usr/bin/env bash
# ==============================================================================
# 🚀 Blockra LXC Installer for Proxmox VE
# Author: Angelo-builds
# ==============================================================================

set -e

APP="Blockra"
var_os="debian"
var_ver="13"
REPO_URL="https://github.com/Angelo-builds/blockra.git"
INSTALL_SCRIPT="https://raw.githubusercontent.com/Angelo-builds/blockra/main/ct/install_blockra.sh"

# --- Load community-scripts framework -----------------------------------------
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
header_info
start

# --- Force defaults if blank (Advanced mode failsafes) ------------------------
var_hostname=${var_hostname:-blockra}
var_cpu=${var_cpu:-2}
var_ram=${var_ram:-2048}
var_disk=${var_disk:-8}
var_bridge=${var_bridge:-vmbr0}
var_ip=${var_ip:-dhcp}
var_gw=${var_gw:-192.168.1.1}
var_unprivileged=${var_unprivileged:-1}
var_tags=${var_tags:-blockra}
var_storage=${STORAGE:-local-lvm}

# --- Make sure Debian 13 template exists -------------------------------------
msg_info "Checking Debian ${var_ver} LXC template..."
if ! pveam list local | grep -q "debian-${var_ver}-standard"; then
  pveam update >/dev/null
  pveam download local debian-${var_ver}-standard_${var_ver}.0-1_amd64.tar.zst >/dev/null
fi
msg_ok "Template Debian ${var_ver} ready."

TEMPLATE="local:vztmpl/debian-${var_ver}-standard_${var_ver}.0-1_amd64.tar.zst"

# --- Create container --------------------------------------------------------
msg_info "Creating LXC container for ${APP}..."
CTID=$(pvesh get /cluster/nextid)
pct create ${CTID} ${TEMPLATE} \
  --hostname ${var_hostname} \
  --arch amd64 \
  --cores ${var_cpu} \
  --memory ${var_ram} \
  --swap 512 \
  --rootfs ${var_storage}:${var_disk} \
  --net0 name=eth0,bridge=${var_bridge},ip=${var_ip},gw=${var_gw} \
  --unprivileged ${var_unprivileged} \
  --features nesting=1 \
  --tags ${var_tags} \
  >/dev/null
msg_ok "LXC Container ${CTID} created."

# --- Start container ---------------------------------------------------------
msg_info "Starting LXC container..."
pct start ${CTID}
sleep 5
msg_ok "Container started."

# --- Network check -----------------------------------------------------------
msg_info "Checking network connectivity..."
for i in {1..10}; do
  if pct exec ${CTID} -- ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
    msg_ok "Network reachable."
    break
  fi
  sleep 2
done

# --- Run installer inside ----------------------------------------------------
msg_info "Installing Blockra inside container..."
pct exec ${CTID} -- bash -c "apt-get update -y && apt-get install -y curl git >/dev/null"
pct exec ${CTID} -- bash -c "curl -fsSL ${INSTALL_SCRIPT} | bash"
msg_ok "Blockra installed."

# --- Detect container IP -----------------------------------------------------
REAL_IP=$(pct exec ${CTID} -- hostname -I 2>/dev/null | awk '{print $1}')

# --- Clean output ------------------------------------------------------------
clear
msg_ok "✔️  Blockra installation completed successfully!"
echo ""
if [[ -n "${REAL_IP}" ]]; then
  echo "  💡  Access your Blockra app at:"
  echo "   🌍  http://${REAL_IP}:3000"
else
  echo "  💡  Check DHCP IP via: pct exec ${CTID} -- ip a show eth0"
fi
echo ""
cat <<'EOF'
    ____  __           __        
   / __ )/ /___  _____/ /__ _________ _
  / __  / / __ \/ ___/ //_// ___/ __ `/ 
 / /_/ / / /_/ / /__/ ,<  / /  / /_/ / 
/_____/_/\____/\___/_/|_|/_/   \__,_/
EOF
msg_ok "[Blockra] Deployment complete — Enjoy!"
