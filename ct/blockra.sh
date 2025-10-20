#!/usr/bin/env bash
# Blockra installer for Proxmox VE
# Creates an LXC, installs dependencies, clones repo and starts Blockra as systemd service.
set -euo pipefail
APP="Blockra"
GITHUB_RAW="https://raw.githubusercontent.com/Angelo-builds/blockra/main"
CTEMPLATE="debian-12-standard_12.0-1_amd64.tar.zst"
DISK_SIZE="${DISK_SIZE:-8}"
RAM_SIZE="${RAM_SIZE:-2048}"
CPU_CORES="${CPU_CORES:-2}"
CT_ID=$(pvesh get /cluster/nextid)

header() {
  echo
  echo "======================================"
  echo " Blockra LXC installer"
  echo "======================================"
  echo
}

header

read -p "Hostname for container (default: blockra): " HOSTNAME
HOSTNAME=${HOSTNAME:-blockra}

read -p "Use DHCP or Static IP? (d/s, default d): " IPMODE
IPMODE=${IPMODE:-d}
if [[ "$IPMODE" == "s" ]]; then
  read -p "Enter static IP with mask (e.g. 192.168.1.50/24): " STATIC_IP
  read -p "Enter gateway (e.g. 192.168.1.1): " GATEWAY
  NETCFG="name=eth0,bridge=vmbr0,ip=${STATIC_IP},gw=${GATEWAY}"
else
  NETCFG="name=eth0,bridge=vmbr0,ip=dhcp"
fi

echo "Will create container ID: $CT_ID"
read -p "Proceed? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "Aborted."
  exit 1
fi

# Ensure template exists or download
if ! pveam available | grep -q "debian-12-standard"; then
  echo "Updating templates and downloading Debian 12 template..."
  pveam update
  pveam download local ${CTEMPLATE}
fi

echo "Creating LXC..."
pct create $CT_ID local:vztmpl/${CTEMPLATE}   --cores ${CPU_CORES}   --memory ${RAM_SIZE}   --hostname ${HOSTNAME}   --rootfs local-lvm:${DISK_SIZE}G   --net0 ${NETCFG}   --unprivileged 1   --features nesting=1   --start 0

echo "Starting container..."
pct start $CT_ID
sleep 3

echo "Copying repository and installer into container..."
pct exec $CT_ID -- mkdir -p /opt/blockra
# Use curl inside container to fetch entire repo tarball and extract (handled in container)
pct exec $CT_ID -- bash -lc "apt update && apt install -y curl gnupg ca-certificates"

pct exec $CT_ID -- bash -lc "cd /opt/blockra && curl -fsSL https://codeload.github.com/Angelo-builds/blockra/tar.gz/main | tar -xz --strip-components=1"

echo "Running inside-container install script..."
pct exec $CT_ID -- bash -lc "bash /opt/blockra/ct/install_in_container.sh"

echo
echo "======================================"
echo " Blockra should be installed and running."
echo " Find it on the container IP at port 3000."
echo " To get container IP run on Proxmox: pct exec $CT_ID -- hostname -I"
echo "======================================"
