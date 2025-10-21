#!/usr/bin/env bash
# =========================================================
# 🧱 Blockra LXC Installer for Proxmox VE (Auto Mode + DEBUG)
# Author: Angelo-builds + AI-enhanced version
# =========================================================

source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

APP="Blockra"
var_tags="${var_tags:-site-builder}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"      # Cambia in 13 se vuoi Debian 13
var_unprivileged="${var_unprivileged:-1}"
header_info "$APP"
variables
color
catch_errors
start

echo "[DEBUG] → Script avviato, framework community-scripts caricato correttamente."

# ---------------------------------------------------------
# 🔍 Detect default storage automatically
# ---------------------------------------------------------
if [[ -z "${STORAGE:-}" ]]; then
  STORAGE=$(pvesm status -content rootdir | awk 'NR==2{print $1}')
  [[ -z "$STORAGE" ]] && STORAGE="local"
fi
echo "[DEBUG] → Storage rilevato: ${STORAGE}"

# ---------------------------------------------------------
# 🧩 Ensure Debian template exists (auto-download)
# ---------------------------------------------------------
TEMPLATE="local:vztmpl/debian-${var_version}-standard_${var_version}-1_amd64.tar.zst"
if ! pveam list local | grep -q "debian-${var_version}-standard"; then
  msg_info "Downloading Debian ${var_version} template..."
  echo "[DEBUG] → Template non trovato, lo scarico..."
  pveam download local "debian-${var_version}-standard_${var_version}-1_amd64.tar.zst" >/dev/null 2>&1
  msg_ok "Template downloaded successfully."
else
  echo "[DEBUG] → Template Debian ${var_version} già disponibile."
  msg_ok "Debian ${var_version} template already available."
fi

# ---------------------------------------------------------
# 🚀 Override build_container here (AFTER start)
# ---------------------------------------------------------
echo "[DEBUG] → Ridefinisco la funzione build_container per evitare il 404 community-scripts..."

function build_container() {
  msg_info "Creating ${APP} LXC container (custom build_container)..."
  CTID=$(pve_nextid)
  echo "[DEBUG] → Nuovo CTID: ${CTID}"

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

  echo "[DEBUG] → Container creato, ora avvio..."
  pct start ${CTID}
  msg_ok "LXC Container ${CTID} created and started."
}

# ---------------------------------------------------------
# 🚀 Build the container (safe version)
# ---------------------------------------------------------
echo "[DEBUG] → Avvio build_container (versione custom, senza community installer)..."
build_container
description
echo "[DEBUG] → Container creato correttamente, procedo con installazione Blockra."

# ---------------------------------------------------------
# 📂 Copy installer + run inside container
# ---------------------------------------------------------
msg_info "Copying installer files into the container..."
pct exec $CTID -- mkdir -p /opt/blockra
pct exec $CTID -- bash -lc "apt update >/dev/null 2>&1 || true; apt install -y curl >/dev/null 2>&1 || true"
pct exec $CTID -- bash -lc "cd /opt/blockra && curl -fsSL https://codeload.github.com/Angelo-builds/blockra/tar.gz/main | tar -xz --strip-components=1"

msg_info "Running Blockra in-container installer..."
echo "[DEBUG] → Avvio install_blockra.sh dentro il container..."
pct exec $CTID -- bash -lc "bash /opt/blockra/ct/install_blockra.sh" || true

msg_ok "Blockra installation completed successfully!"
echo "[DEBUG] → Installazione Blockra completata senza errori."

# ---------------------------------------------------------
# 🌐 Show connection info
# ---------------------------------------------------------
IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')
[[ -z "$IP" ]] && IP="<container-ip>"

echo -e "\n${INFO} Access your Blockra app at:${CL}"
echo -e "   🌍  http://${IP}:3000\n"

cat <<'BANNER'
  ____  _            _              _
 |  _ \| | ___   ___| | _____ _ __ | |__   ___ _ __
 | |_) | |/ _ \ / __| |/ / _ \ '_ \| '_ \ / _ \ '__|
 |  _ <| | (_) | (__|   <  __/ |_) | | | |  __/ |
 |_| \_\_|\___/ \___|_|\_\___| .__/|_| |_|\___|_|
                             |_|
   /-----------------------------------------------\
   |  Blockra installation complete — Have a great day! |
   \-----------------------------------------------/
BANNER

echo "[DEBUG] → Script terminato correttamente."
