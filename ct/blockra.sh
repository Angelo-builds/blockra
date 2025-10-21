#!/usr/bin/env bash
# =========================================================
# 🧱 Blockra LXC Installer for Proxmox
# Author: Angelo-builds
# =========================================================

source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

APP="Blockra"
var_tags="${var_tags:-site-builder}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"  
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors
start

# ---------------------------------------------------------
# 🔍 Detect default storage automatically
# ---------------------------------------------------------
if [[ -z "${STORAGE:-}" ]]; then
  STORAGE=$(pvesm status -content rootdir | awk 'NR==2{print $1}')
  [[ -z "$STORAGE" ]] && STORAGE="local"
fi

# ---------------------------------------------------------
# 🧩 Ensure Debian template exists (+ auto-download)
# ---------------------------------------------------------
if ! pveam list local | grep -q "debian-${var_version}-standard"; then
  msg_info "Downloading Debian ${var_version} template..."
  pveam download local "debian-${var_version}-standard_${var_version}-1_amd64.tar.zst" >/dev/null 2>&1
  msg_ok "Template downloaded successfully."
else
  msg_ok "Debian ${var_version} template already available."
fi

# ---------------------------------------------------------
# 📦 Select correct Debian template file dynamically
# ---------------------------------------------------------
TEMPLATE_FILE=$(pveam list local | grep "debian-${var_version}-standard" | awk '{print $1}' | sed 's/local:vztmpl\///' | tail -n 1)
if [[ -z "$TEMPLATE_FILE" ]]; then
  msg_error "Template Debian ${var_version} non trovato. Esegui: pveam download local debian-${var_version}-standard_*.tar.zst"
  exit 1
fi
TEMPLATE="local:vztmpl/${TEMPLATE_FILE}"

# ---------------------------------------------------------
# 🚀 Custom build_container (no community installer)
# ---------------------------------------------------------
function build_container() {
  msg_info "Creating ${APP} LXC container..."
  CTID=$(pvesh get /cluster/nextid)

  pct create ${CTID} ${TEMPLATE} \
    --hostname blockra \
    --arch amd64 \
    --cores ${var_cpu} \
    --memory ${var_ram} \
    --swap 512 \
    --rootfs ${STORAGE}:${var_disk} \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp \
    --unprivileged ${var_unprivileged} \
    --features nesting=1 \
    --tags ${var_tags} \
    >/dev/null

  pct start ${CTID}
  msg_ok "LXC Container ${CTID} created and started."
}

# ---------------------------------------------------------
# 🚀 Build the container
# ---------------------------------------------------------
build_container
description

# ---------------------------------------------------------
# 📂 Copy installer + run inside container
# ---------------------------------------------------------
msg_info "Copying installer files into the container..."
pct exec $CTID -- mkdir -p /opt/blockra
pct exec $CTID -- bash -lc "apt update >/dev/null 2>&1 || true; apt install -y curl >/dev/null 2>&1 || true"
pct exec $CTID -- bash -lc "cd /opt/blockra && curl -fsSL https://codeload.github.com/Angelo-builds/blockra/tar.gz/main | tar -xz --strip-components=1"

msg_info "Running Blockra in-container installer..."
pct exec $CTID -- bash -lc "bash /opt/blockra/ct/install_blockra.sh" || true
msg_ok "Blockra installation completed successfully!"

# ---------------------------------------------------------
# 🌐 Show connection info
# ---------------------------------------------------------
IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')
[[ -z "$IP" ]] && IP="<container-ip>"

echo -e "\n${INFO} Access your Blockra app at:${CL}"
echo -e "   🌍  http://${IP}:3000\n"

cat <<'BANNER'
	____  __           __        
   / __ )/ /___  _____/ /__ _________ _
  / __  / / __ \/ ___/ //_// ___/ __ `/ 
 / /_/ / / /_/ / /__/ ,<  / /  / /_/ / 
/_____/_/\____/\___/_/|_|/_/   \__,_/

BANNER
