#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Blockra LXC Installer for Proxmox VE
# ----------------------------------------------------------------------------------

source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
APP="Blockra"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors
start

# --- CONFIG ---
OSTYPE="${var_os}-${var_version}"
TEMPLATE="local:vztmpl/${OSTYPE}-standard_12-1_amd64.tar.zst"
STORAGE=${STORAGE:-local-lvm}
CTID=$(pvesh get /cluster/nextid)

msg_info "Checking template..."
if ! pveam list local | grep -q "${OSTYPE}"; then
    msg_info "Downloading template ${OSTYPE}..."
    pveam download local ${OSTYPE}-standard_12-1_amd64.tar.zst >/dev/null 2>&1
    msg_ok "Template ${OSTYPE} downloaded."
fi

msg_info "Creating LXC container for Blockra..."
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
  --tags blockra >/dev/null

msg_ok "Container ${CTID} created successfully."

msg_info "Starting LXC container..."
pct start ${CTID}
sleep 5
msg_ok "Container started."

msg_info "Installing Blockra inside the container..."
pct exec ${CTID} -- bash -c "apt update >/dev/null 2>&1 || true; apt install -y curl >/dev/null 2>&1 || true"
pct exec ${CTID} -- mkdir -p /opt/blockra
pct exec ${CTID} -- bash -lc "cd /opt/blockra && curl -fsSL https://codeload.github.com/Angelo-builds/blockra/tar.gz/main | tar -xz --strip-components=1"
pct exec ${CTID} -- bash -lc "bash /opt/blockra/ct/install_blockra.sh"

msg_ok "Blockra installation complete!"

IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')
echo -e "\\nAccess Blockra at: http://${IP}:3000\\n"

cat <<'BANNER'

 ____   _            _            
| __ ) | | ___   ___| | ____ __    ____
|  _ \ | |/ _ \ / __| |/ /|  '__| /    \
| |_) || | (_) | (__|   < |  |   | /__\ |
|____(_)_|\___/ \___|_|\_\|__|   |_|  |_|

  /---------------------------------------------\
  |  Blockra installation complete!             |
  |  Visit: http://$IP:3000                     |
  \---------------------------------------------/
BANNER

exit 0
