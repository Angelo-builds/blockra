#!/usr/bin/env bash
# =========================================================
# 🧱 Blockra In-Container Installer (final)
# =========================================================
set -e

APP_HOME="/opt/blockra"

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
# ⚙️ Install dependencies
# ---------------------------------------------------------
cd ${APP_HOME}
npm install --silent || true

if grep -q '"vite"' "${APP_HOME}/package.json" 2>/dev/null; then
  su - blockra -c "cd ${APP_HOME} && npm run build || true"
fi

# ---------------------------------------------------------
# 🛠️ Ensure backend listens on 0.0.0.0
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
After=network-online.target

[Service]
Type=simple
User=blockra
WorkingDirectory=${APP_HOME}
ExecStart=/usr/bin/node ${APP_HOME}/index.js
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
echo ""
if ss -tulpn | grep -q ":3000"; then
  IP=$(hostname -I | awk '{print $1}')
  echo "  💡   Access your Blockra app at:"
  echo "   🌍  http://${IP}:3000"
else
  echo "  ⚠️   Blockra service not listening. Check with:"
  echo "       journalctl -u blockra.service -b | tail -30"
fi
