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

# --- Default fallback values (for Advanced or missing vars) -------------------
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

# --- Ensure Debian 13 template exists ----------------------------------------
msg_info "Checking Debian ${var_ver} LXC template..."
TEMPLATE_PATH=""
TEMPLATE_FILE=$(pveam list local | awk '/debian-13/ {print $2}' | tail -n 1)

if [[ -z "$TEMPLATE_FILE" ]]; then
  msg_warn "Debian ${var_ver} template not found — downloading latest..."
  pveam update >/dev/null 2>&1 || true
  LATEST_TEMPLATE=$(pveam available | grep "debian-${var_ver}-standard" | sort -r | head -n 1 | awk '{print $2}')
  if [[ -n "$LATEST_TEMPLATE" ]]; then
    pveam download local "$LATEST_TEMPLATE" >/dev/null 2>&1 || {
      msg_error "Failed to download template: ${LATEST_TEMPLATE}"
      exit 1
    }
    TEMPLATE_PATH="local:vztmpl/${LATEST_TEMPLATE##*/}"
  else
    msg_error "No Debian ${var_ver} template found online!"
    exit 1
  fi
else
  TEMPLATE_PATH="local:vztmpl/${TEMPLATE_FILE}"
fi
msg_ok "Template Debian ${var_ver} ready: ${TEMPLATE_PATH}"

# --- Create container --------------------------------------------------------
msg_info "Creating LXC container for ${APP}..."
CTID=$(pvesh get /cluster/nextid)
if ! pct create ${CTID} ${TEMPLATE_PATH} \
  --hostname ${var_hostname} \
  --arch amd64 \
  --cores ${var_cpu} \
  --memory ${var_ram} \
  --swap 512 \
  --rootfs ${var_storage}:${var_disk} \
  --net0 name=eth0,bridge=${var_bridge},ip=${var_ip},gw=${var_gw} \
  --unprivileged ${var_unprivileged} \
  --features nesting=1 \
  --tags ${var_tags} >/dev/null 2>&1; then
  msg_error "Container creation failed — check your template or Proxmox version."
  exit 1
fi
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

# --- Final summary -----------------------------------------------------------
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
