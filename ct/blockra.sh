#!/usr/bin/env bash
# ==============================================================================
# 🚀 Blockra LXC Installer for Proxmox VE (Community Scripts Style, FINAL)
# ==============================================================================

set -e

APP="Blockra"
var_os="debian"
var_ver="13"
INSTALL_SCRIPT="https://raw.githubusercontent.com/Angelo-builds/blockra/main/ct/install_blockra.sh"

# --- Load community-scripts framework -----------------------------------------
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
header_info
start

# --- Set sane defaults even if Advanced Mode left them blank ------------------
var_hostname=${var_hostname:-blockra}
var_cpu=${var_cpu:-2}
var_ram=${var_ram:-2048}
var_disk=${var_disk:-8}
var_bridge=${var_bridge:-vmbr0}
var_ip=${var_ip:-dhcp}
var_gw=${var_gw:-192.168.1.1}
var_unprivileged=${var_unprivileged:-1}
var_tags=${var_tags:-blockra}

# --- Detect valid storages ----------------------------------------------------
TEMPLATE_STORAGE=$(pvesm status -content vztmpl | awk 'NR==2 {print $1}')
CONTAINER_STORAGE=$(pvesm status -content rootdir | awk 'NR==2 {print $1}')

if [[ -z "$TEMPLATE_STORAGE" ]]; then
  TEMPLATE_STORAGE="local"
fi
if [[ -z "$CONTAINER_STORAGE" ]]; then
  if pvesm status | awk '{print $1}' | grep -q '^local-lvm$'; then
    CONTAINER_STORAGE="local-lvm"
  else
    CONTAINER_STORAGE="local"
  fi
fi

msg_info "Detected storages:"
echo "  📦 Template Storage: ${TEMPLATE_STORAGE}"
echo "  💾 Container Storage: ${CONTAINER_STORAGE}"

# --- Ensure Debian 13 template exists ----------------------------------------
msg_info "Checking Debian ${var_ver} template..."
TEMPLATE_FILE=$(pveam list ${TEMPLATE_STORAGE} | awk '/debian-13/ {print $2}' | tail -n1)

if [[ -z "$TEMPLATE_FILE" ]]; then
  msg_warn "Debian ${var_ver} template not found, downloading latest..."
  pveam update >/dev/null 2>&1 || true
  LATEST_TEMPLATE=$(pveam available | grep "debian-${var_ver}-standard" | sort -r | head -n1 | awk '{print $2}')
  if [[ -n "$LATEST_TEMPLATE" ]]; then
    pveam download ${TEMPLATE_STORAGE} "$LATEST_TEMPLATE" >/dev/null 2>&1 || {
      msg_error "Failed to download Debian ${var_ver} template."
      exit 1
    }
    TEMPLATE_FILE=$(basename "$LATEST_TEMPLATE")
  else
    msg_error "No Debian ${var_ver} template available online."
    exit 1
  fi
fi

TEMPLATE="${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE_FILE}"
msg_ok "Template Debian ${var_ver} ready: ${TEMPLATE}"

# --- Create container --------------------------------------------------------
msg_info "Creating LXC container for ${APP}..."
CTID=$(pvesh get /cluster/nextid)
if ! pct create ${CTID} ${TEMPLATE} \
  --hostname ${var_hostname} \
  --arch amd64 \
  --cores ${var_cpu} \
  --memory ${var_ram} \
  --swap 512 \
  --rootfs ${CONTAINER_STORAGE}:${var_disk} \
  --net0 name=eth0,bridge=${var_bridge},ip=${var_ip},gw=${var_gw} \
  --unprivileged ${var_unprivileged} \
  --features nesting=1 \
  --tags ${var_tags} >/dev/null 2>&1; then
  msg_error "Container creation failed — verify template and storage."
  exit 1
fi
msg_ok "LXC Container ${CTID} created."

# --- Start container ---------------------------------------------------------
msg_info "Starting container..."
pct start ${CTID}
sleep 5
msg_ok "Container started."

# --- Network test ------------------------------------------------------------
msg_info "Checking network..."
for i in {1..10}; do
  if pct exec ${CTID} -- ping -c1 -W1 8.8.8.8 >/dev/null 2>&1; then
    msg_ok "Network reachable."
    break
  fi
  sleep 2
done

# --- Run installer -----------------------------------------------------------
msg_info "Installing Blockra inside container..."
pct exec ${CTID} -- bash -c "apt-get update -y && apt-get install -y curl git >/dev/null"
pct exec ${CTID} -- bash -c "curl -fsSL ${INSTALL_SCRIPT} | bash"
msg_ok "Blockra installed."

# --- Detect IP ---------------------------------------------------------------
REAL_IP=$(pct exec ${CTID} -- hostname -I 2>/dev/null | awk '{print $1}')

clear
msg_ok "✔️  Blockra installation completed successfully!"
echo ""
if [[ -n "${REAL_IP}" ]]; then
  echo "  💡  Access your Blockra app at:"
  echo "   🌍  http://${REAL_IP}:3000"
else
  echo "  💡  Check DHCP IP via:"
  echo "   pct exec ${CTID} -- ip a show eth0"
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
