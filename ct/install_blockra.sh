#!/usr/bin/env bash
# =========================================================
# 🧱 Blockra In-Container Installer (Node + Systemd + Static IP Fix)
# =========================================================

set -e

APP_HOME="/opt/blockra"

# ---------------------------------------------------------
# 🧩 Import static IP vars from /etc/environment (if set)
# ---------------------------------------------------------
VAR_IP=$(grep "^VAR_IP=" /etc/environment | cut -d= -f2 | xargs || true)
VAR_GW=$(grep "^VAR_GW=" /etc/environment | cut -d= -f2 | xargs || true)

# ---------------------------------------------------------
# 🧩 Dependencies
# ---------------------------------------------------------
apt-get update -y >/dev/null
apt-get install -y curl git nodejs npm locales >/dev/null

# ---------------------------------------------------------
# 🌍 Fix locale warnings
# ---------------------------------------------------------
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen en_US.UTF-8 >/dev/null 2>&1
update-locale LANG=en_US.UTF-8 >/dev/null 2>&1

# ---------------------------------------------------------
# 🌐 Force static IP configuration if defined
# ---------------------------------------------------------
if [[ -n "$VAR_IP" ]]; then
  echo "[Network] Applying static IP configuration: ${VAR_IP}"
  cat <<EOF >/etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address ${VAR_IP}/24
    gateway ${VAR_GW:-192.168.1.1}
    dns-nameservers 8.8.8.8
EOF

  # Disable cloud-init/DHCP if active
  systemctl stop systemd-networkd || true
  systemctl disable systemd-networkd || true

  # Restart traditional networking
  systemctl restart networking || true
  sleep 3
fi

# ---------------------------------------------------------
# 🧱 Setup service user
# ---------------------------------------------------------
id -u blockra >/dev/null 2>&1 || useradd -r -s /bin/bash blockra
chown -R blockra:blockra ${APP_HOME}

# ---------------------------------------------------------
# ⚙️ Install dependencies and build frontend (if present)
# ---------------------------------------------------------
cd ${APP_HOME}
npm install --silent || true

if grep -q '"vite"' "${APP_HOME}/package.json" 2>/dev/null; then
  su - blockra -c "cd ${APP_HOME} && npm install --silent && npm run build || true"
fi

# ---------------------------------------------------------
# 🛠️ Patch backend to listen on 0.0.0.0
# ---------------------------------------------------------
if grep -q "app.listen" "${APP_HOME}/index.js" 2>/dev/null; then
  sed -i 's/app\.listen(3000[^)]*/app.listen(3000, "0.0.0.0"/' "${APP_HOME}/index.js"
fi

# ---------------------------------------------------------
# 🛠️ Create Systemd service
# ---------------------------------------------------------
cat <<EOF >/etc/systemd/system/blockra.service
[Unit]
Description=Blockra Node App
After=network.target

[Service]
Type=simple
User=blockra
WorkingDirectory=${APP_HOME}
ExecStart=/usr/bin/node ${APP_HOME}/index.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# ---------------------------------------------------------
# 🚀 Enable and start service
# ---------------------------------------------------------
systemctl daemon-reload
systemctl enable blockra.service
systemctl restart blockra.service

# ---------------------------------------------------------
# ✅ Health check
# ---------------------------------------------------------
sleep 5
if ss -tulpn | grep -q ":3000"; then
  echo "[OK] Blockra service is running on port 3000."
else
  echo "[WARN] Blockra service not detected on port 3000. Check logs:"
  echo "       journalctl -u blockra.service -b | tail -30"
fi

echo ""
echo "[Blockra] If the service failed, check: journalctl -u blockra.service -b"
