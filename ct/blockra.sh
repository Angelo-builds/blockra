#!/usr/bin/env bash
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

# --- Custom container creation (manual, skip var_install) ---
msg_info "Creating LXC container for $APP..."
create_lxc
description
msg_ok "Container $CTID created successfully."

msg_info "Copying installer files into the container..."
pct exec $CTID -- mkdir -p /opt/blockra
pct exec $CTID -- bash -lc "apt update >/dev/null 2>&1 || true; apt install -y curl >/dev/null 2>&1 || true"
pct exec $CTID -- bash -lc "cd /opt/blockra && curl -fsSL https://codeload.github.com/Angelo-builds/blockra/tar.gz/main | tar -xz --strip-components=1"

msg_info "Running Blockra in-container installer..."
pct exec $CTID -- bash -lc "bash /opt/blockra/ct/install_blockra.sh"

msg_ok "Blockra installation complete."
IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')
echo -e "\\nAccess Blockra at: http://${IP}:3000\\n"

cat <<'BANNER'
  ____  _            _              _
 |  _ \| | ___   ___| | _____ _ __ | |__   ___ _ __
 | |_) | |/ _ \ / __| |/ / _ \ '_ \| '_ \ / _ \ '__|
 |  _ <| | (_) | (__|   <  __/ |_) | | | |  __/ |
 |_| \_\_|\___/ \___|_|\_\___| .__/|_| |_|\___|_|
                             |_|
  /---------------------------------------------\\
  |  Blockra installation complete!             |
  |  Visit: http://$IP:3000                     |
  \\---------------------------------------------/
BANNER
