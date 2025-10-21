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

# --- Load community framework -------------------------------------------------
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
header_info
echo -e "  🧩 Installing ${APP} on Proxmox VE using Community Framework...\n"

# --- Start installer ----------------------------------------------------------
start
build_container

# --- Safety fallback defaults for Advanced Mode -------------------------------
var_hostname=${var_hostname:-blockra}
var_cpu=${var_cpu:-2}
var_ram=${var_ram:-2048}
var_disk=${var_disk:-8}
var_bridge=${var_bridge:-vmbr0}
var_ip=${var_ip:-dhcp}
var_gw=${var_gw:-192.168.1.1}
var_unprivileged=${var_unprivileged:-1}
var_tags=${var_tags:-blockra}

# --- Template absolute path (Fix for Proxmox VE 9) ----------------------------
TEMPLATE_PATH="/var/lib/vz/template/cache/debian-${var_ver}-standard_${var_ver}-1_amd64.tar.zst"
if [[ ! -f "${TEMPLATE_PATH}" ]]; then
  msg_info "Downloading Debian ${var_ver} LXC template..."
  pveam update >/dev/null
  pveam download local debian-${var_ver}-standard_${var_ver}-1_amd64.tar.zst >/dev/null
  msg_ok "Template Debian ${var_ver} downloaded."
fi
TEMPLATE="${TEMPLATE_PATH}"

# --- Manual container creation (works on all Proxmox versions) ----------------
msg_info "Creating LXC container for ${APP}..."
CTID=$(pvesh get /cluster/nextid)
pct create ${CTID} ${TEMPLATE} \
  --hostname ${var_hostname} \
  --arch amd64 \
  --cores ${var_cpu} \
  --memory ${var_ram} \
  --swap 512 \
  --rootfs ${STORAGE}:${var_disk} \
  --net0 name=eth0,bridge=${var_bridge},ip=${var_ip},gw=${var_gw} \
  --unprivileged ${var_unprivileged} \
  --features nesting=1 \
  --tags ${var_tags}
msg_ok "LXC Container ${CTID} created."

# --- Start container ----------------------------------------------------------
msg_info "Starting LXC container..."
pct start ${CTID}
sleep 5
msg_ok "Container started successfully."

# --- Verify network -----------------------------------------------------------
msg_info "Checking network connectivity..."
for i in {1..10}; do
  if pct exec ${CTID} -- ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
    msg_ok "Network is reachable."
    break
  fi
  sleep 2
done

# --- Fetch Blockra project ----------------------------------------------------
msg_info "Fetching Blockra project files..."
pct exec ${CTID} -- bash -c "apt-get update -y && apt-get install -y curl git tar >/dev/null"
pct exec ${CTID} -- bash -c "mkdir -p /opt/blockra && curl -L https://github.com/Angelo-builds/blockra/archive/refs/heads/main.tar.gz | tar -xz --strip-components=1 -C /opt/blockra"
msg_ok "Project files ready in /opt/blockra."

# --- Run installer ------------------------------------------------------------
msg_info "Running Blockra installer..."
pct exec ${CTID} -- bash -c "curl -fsSL ${INSTALL_SCRIPT} | bash"
msg_ok "Installation script executed."

# --- Health check -------------------------------------------------------------
msg_info "Checking Blockra service..."
sleep 5
if pct exec ${CTID} -- bash -c "ss -tulpn | grep -q ':3000'"; then
  msg_ok "${APP} is running and listening on port 3000"
else
  msg_warn "${APP} service not listening. Check logs with: pct exec ${CTID} -- journalctl -u blockra.service -b | tail -30"
fi

# --- Retrieve IP --------------------------------------------------------------
REAL_IP=$(pct exec ${CTID} -- hostname -I 2>/dev/null | awk '{print $1}')

# --- Final output -------------------------------------------------------------
clear
msg_ok "Blockra installation completed successfully!"
echo ""
if [[ -n "${REAL_IP}" ]]; then
  echo "  💡  Access your Blockra app at:"
  echo "   🌍  http://${REAL_IP}:3000"
else
  echo "  💡  Access your Blockra app at: (IP via DHCP, check with: pct exec ${CTID} -- ip a)"
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
