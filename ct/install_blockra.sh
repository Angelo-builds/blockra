#!/usr/bin/env bash
# ==============================================================================
# 🧱 Blockra In-Container Installer (Stable)
# Works inside LXC created by blockra.sh
# Maintainer: Angelo-builds
# ==============================================================================

set -e
APP_HOME="/opt/blockra"
APP_ENTRY="${APP_HOME}/app/server/index.js"

echo "[INIT] Installing Blockra inside container..."

# ---------------------------------------------------------
# 🧩 Base dependencies
# ---------------------------------------------------------
apt-get update -y >/dev/null
apt-get install -y curl git nodejs npm locales >/dev/null

# ---------------------------------------------------------
# 🌍 Fix locale issues (Debian minimal containers)
# ---------------------------------------------------------
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen en_US.UTF-8 >/dev/null 2>&1
update-locale LANG=en_US.UTF-8 >/dev/null 2>&1

# ---------------------------------------------------------
# 👤 Create dedicated service user
# ---------------------------------------------------------
id -u blockra >/dev/null 2>&1 || useradd -r -s /bin/bash blockra
mkdir -p ${APP_HOME}
chown -R blockra:blockra ${APP_HOME}

# ---------------------------------------------------------
# 📦 Install server + client dependencies
# ---------------------------------------------------------
msg="[npm install]"
echo "[INFO] Installing server dependencies..."
cd ${APP_HOME}/app/server
npm install --silent || npm ci --omit=dev || true

echo "[INFO] Installing client dependencies..."
cd ${APP_HOME}/app/client
npm install --silent || npm ci --omit=dev || true
npm run build || true

# ---------------------------------------------------------
# 🛠️ Ensure backend listens on all interfaces
# ---------------------------------------------------------
if grep -q "app.listen" "${APP_ENTRY}" 2>/dev/null; then
  sed -i 's/app\.listen(3000[^)]*/app.listen(3000, "0.0.0.0"/' "${APP_ENTRY}" || true
fi

# ---------------------------------------------------------
# 🧩 Fix permissions (important for unprivileged LXC)
# ---------------------------------------------------------
chown -R blockra:blockra ${APP_HOME}
chmod -R 755 ${APP_HOME}

# ---------------------------------------------------------
# 🧪 Test Node app manually before service creation
# ---------------------------------------------------------
echo "[DEBUG] Testing Node app before enabling systemd..."
if su - blockra -c "node ${APP_ENTRY} >/dev/null 2>&1 &"; then
  sleep 3
  pkill -f "node ${APP_ENTRY}" || true
  echo "[DEBUG] Node test passed."
else
  echo "[WARN] Node test failed — check ${APP_ENTRY} syntax or dependencies."
fi

# ---------------------------------------------------------
# ⚙️ Create systemd service
# ---------------------------------------------------------
cat <<EOF >/etc/systemd/system/blockra.service
[Unit]
Description=Blockra Node App
After=network-online.target

[Service]
Type=simple
User=blockra
WorkingDirectory=${APP_HOME}/app/server
ExecStart=/usr/bin/node ${APP_ENTRY}
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# ---------------------------------------------------------
# 🚀 Enable & start service
# ---------------------------------------------------------
systemctl daemon-reload
systemctl enable blockra.service
systemctl restart blockra.service
sleep 5

# ---------------------------------------------------------
# ✅ Final output
# ---------------------------------------------------------
clear
echo "  ✔️   Blockra installation completed successfully!"
REAL_IP=$(hostname -I | awk '{print $1}')

if ss -tulpn | grep -q ":3000"; then
  echo ""
  echo "  💡   Access your Blockra app at:"
  echo "   🌍  http://${REAL_IP}:3000"
else
  echo ""
  echo "  ⚠️   Blockra service not listening."
  echo "       Check logs with: journalctl -u blockra.service -b | tail -30"
fi
