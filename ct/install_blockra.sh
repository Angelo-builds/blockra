#!/usr/bin/env bash
set -e

APP_HOME="/opt/blockra"
APP_ENTRY="${APP_HOME}/app/server/index.js"

echo "[INIT] Installing Blockra inside container..."

# ---------------------------------------------------------
# 🧩 Dependencies
# ---------------------------------------------------------
apt-get update -y >/dev/null
apt-get install -y curl git nodejs npm locales >/dev/null

# ---------------------------------------------------------
# 🌍 Locale fix
# ---------------------------------------------------------
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen en_US.UTF-8 >/dev/null 2>&1
update-locale LANG=en_US.UTF-8 >/dev/null 2>&1

# ---------------------------------------------------------
# 🧱 Setup service user
# ---------------------------------------------------------
id -u blockra >/dev/null 2>&1 || useradd -r -s /bin/bash blockra
chown -R blockra:blockra ${APP_HOME}

# ---------------------------------------------------------
# ⚙️ Install dependencies (client + server)
# ---------------------------------------------------------
cd ${APP_HOME}/app/server
npm install --silent || true

cd ${APP_HOME}/app/client
npm install --silent || true
npm run build || true

# ---------------------------------------------------------
# 🛠️ Ensure backend listens on 0.0.0.0
# ---------------------------------------------------------
if grep -q "app.listen" "${APP_ENTRY}" 2>/dev/null; then
  sed -i 's/app\.listen(3000[^)]*/app.listen(3000, "0.0.0.0"/' "${APP_ENTRY}"
fi

# ---------------------------------------------------------
# 🛠️ Create Systemd service
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
# 🚀 Enable + start
# ---------------------------------------------------------
systemctl daemon-reload
systemctl enable blockra.service
systemctl restart blockra.service
sleep 5

clear
echo "  ✔️   Blockra installation completed successfully!"
REAL_IP=$(hostname -I | awk '{print $1}')

if ss -tulpn | grep -q ":3000"; then
  echo "  💡   Access your Blockra app at:"
  echo "   🌍  http://${REAL_IP}:3000"
else
  echo "  ⚠️   Blockra service not listening. Check with:"
  echo "       journalctl -u blockra.service -b | tail -30"
fi
