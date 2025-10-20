#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Blockra LXC Installer for Proxmox VE (community-scripts style)
# ----------------------------------------------------------------------------------
# Source helper functions from community-scripts
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# License: MIT (see LICENSE in repo)
APP="Blockra"
var_tags="${var_tags:-site-builder}"
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

function update_script() {
  header_info
  msg_error "No update implemented for Blockra script."
  exit
}

start
build_container
description

msg_info "Copying installer files into the container..."
pct exec $CTID -- mkdir -p /opt/blockra
pct exec $CTID -- bash -lc "apt update >/dev/null 2>&1 || true; apt install -y curl >/dev/null 2>&1 || true"
pct exec $CTID -- bash -lc "cd /opt/blockra && curl -fsSL https://codeload.github.com/Angelo-builds/blockra/tar.gz/main | tar -xz --strip-components=1"
pct exec $CTID -- bash -lc "bash /opt/blockra/ct/install_blockra.sh" || true

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"\n
IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')
if [[ -z "$IP" ]]; then
  IP="<container-ip>"
fi
echo -e "${INFO}${YW} Access it using the following URL:${CL}"\n
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"\n

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

exit 0
