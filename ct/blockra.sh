#!/usr/bin/env bash
# =========================================================
# 🚀 Blockra LXC Auto-Deploy Script for Proxmox VE
# Author: Angelo-builds
# Compatible with Debian 12 / 13 Templates
# =========================================================

set -e

APP="Blockra"
REPO_URL="https://github.com/Angelo-builds/blockra.git"
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/Angelo-builds/blockra/main/ct/install_blockra.sh"
TEMPLATE_OS="debian"
TEMPLATE_VER="13"
DEFAULT_BRIDGE="vmbr0"

# ---------------------------------------------------------
# 🧩 Settings (defaults)
# ---------------------------------------------------------
var_cpu=2
var_ram=2048
var_disk=8
var_os="${TEMPLATE_OS}"
var_ver="${TEMPLATE_VER}"
var_bridge="${DEFAULT_BRIDGE}"
var_unprivileged=1
var_tags="blockra"

# ---------------------------------------------------------
# 🎛️ Advanced Configuration (optional)
# ---------------------------------------------------------
read -p "Use Advanced Options? (y/N): " adv
if [[ "$adv" =~ ^[Yy]$ ]]; then
  echo "🧩  Using Advanced Settings on node $(hostname)"
  read -p "IPv4 Address (e.g. 192.168.1.250/24): " var_ip
  read -p "Gateway IP Address (default 192.168.1.1): " var_gw
  read -p "Hostname (default blockra): " var_host
  read -p "Disk Size (GB, default 8): " var_disk
  read -p "CPU Cores (default 2): " var_cpu
  read -p "RAM (MB, default 2048): " var_ram
else
  echo "⚙️  Using Default Settings on node $(hostname)"
  var_host="blockra"
  var_ip=""
  var_gw="192.168.1.1"
fi

STORAGE=$(pvesm status -content rootdir | awk 'NR==2 {print $1}')
TEMPLATE="local:vztmpl/debian-${var_ver}-standard_${var_ver}-1_amd64.tar.zst"
CTID=$(pvesh get /cluster/nextid)

# ---------------------------------------------------------
# 🧱 Summary
# ---------------------------------------------------------
echo ""
echo "  🆔  Container ID: ${CTID}"
echo "  🖥️  Operating System: ${var_os} (${var_ver})"
echo "  💾  Disk Size: ${var_disk} GB"
echo "  🧠  CPU Cores: ${var_cpu}"
echo "  🛠️  RAM Size: ${var_ram} MiB"
echo "  🌉  Bridge: ${var_bridge}"
[[ -n "$var_ip" ]] && echo "  📡  IPv4 Address: ${var_ip}" || echo "  📡  IPv4 Address: DHCP"
echo "  🌐  Gateway: ${var_gw}"
echo "  🚀  Creating a ${APP} LXC using the above settings"
echo ""

# ---------------------------------------------------------
# 🧩 Ensure Debian template exists
# ---------------------------------------------------------
if ! pveam list local | grep -q "debian-${var_ver}-standard"; then
  echo "⬇️  Downloading Debian ${var_ver} template..."
  pveam update >/dev/null
  pveam download local debian-${var_ver}-standard_${var_ver}-1_amd64.tar.zst >/dev/null
else
  echo "✔️   Debian ${var_ver} template already available."
fi

# ---------------------------------------------------------
# 🧩 Create the LXC container
# ---------------------------------------------------------
echo "⏳   Creating ${APP} LXC container..."
pct create ${CTID} ${TEMPLATE} \
  --hostname ${var_host} \
  --arch amd64 \
  --cores ${var_cpu} \
  --memory ${var_ram} \
  --swap 512 \
  --rootfs ${STORAGE}:${var_disk} \
  --net0 name=eth0,bridge=${var_bridge},ip=${var_ip:-dhcp},gw=${var_gw} \
  --unprivileged ${var_unprivileged} \
  --features nesting=1 \
  --tags ${var_tags} >/dev/null

echo "✔️   LXC Container ${CTID} created and started."
pct start ${CTID}

# ---------------------------------------------------------
# 🧩 Apply static IP fix at host level (if user specified)
# ---------------------------------------------------------
if [[ -n "$var_ip" ]]; then
  CONF_PATH="/etc/pve/lxc/${CTID}.conf"
  echo "[Network] Forcing static IP (${var_ip}) inside host config (${CONF_PATH})"
  sed -i "s|ip=.*|ip=${var_ip},gw=${var_gw:-192.168.1.1}|" "$CONF_PATH" || true
fi

# ---------------------------------------------------------
# 🧩 Clone repo + prepare environment
# ---------------------------------------------------------
echo "⏳   Cloning ${APP} repository..."
pct exec ${CTID} -- bash -c "apt-get update -y >/dev/null && apt-get install -y git >/dev/null"
pct exec ${CTID} -- bash -c "git clone ${REPO_URL} /opt/blockra >/dev/null"

# Inject variables into container
pct exec ${CTID} -- bash -c "echo VAR_IP='${var_ip%/*}' >> /etc/environment"
pct exec ${CTID} -- bash -c "echo VAR_GW='${var_gw}' >> /etc/environment"

# ---------------------------------------------------------
# 🧩 Run installer inside container
# ---------------------------------------------------------
echo "⏳   Running ${APP} in-container installer..."
pct exec ${CTID} -- bash -c "curl -fsSL ${INSTALL_SCRIPT_URL} | bash"

# ---------------------------------------------------------
# 🧩 Optional health check
# ---------------------------------------------------------
if [[ -n "$var_ip" ]]; then
  echo "🩺  Checking HTTP response on http://${var_ip%/*}:3000 ..."
  sleep 5
  if curl -fsI "http://${var_ip%/*}:3000" | grep -q "200"; then
    echo "✔️   ${APP} is up and responding on ${var_ip%/*}:3000"
  else
    echo "⚠️   ${APP} not responding (yet). Check logs inside container."
  fi
fi

# ---------------------------------------------------------
# 🎉 Final banner
# ---------------------------------------------------------
clear
echo "  ✔️   ${APP} installation completed successfully!"
echo ""
echo "  💡   Access your ${APP} app at:"
if [[ -n "$var_ip" ]]; then
  echo "   🌍  http://${var_ip%/*}:3000"
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
echo "[Blockra] Deployment complete — Have a great day!"
