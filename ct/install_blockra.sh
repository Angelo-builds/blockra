#!/usr/bin/env bash
# =========================================================
# 🧱 Blockra In-Container Installer (Node + Systemd)
# =========================================================

set -e

APP_HOME="/opt/blockra"

# ---------------------------------------------------------
# 🧩 Dependencies
# ---------------------------------------------------------
apt-get update -y >/dev/null
apt-get install -y curl git nodejs npm >/dev/null

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

# ---------------------------------------------------------
# 🧠 Fallback build for Vite/React root projects
# ---------------------------------------------------------
if grep -q '"vite"' "${APP_HOME}/package.json" 2>/dev/null; then
  su - blockra -c "cd ${APP_HOME} && npm install --silent && npm run build || true"
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

echo ""
echo "[Blockra] If the service failed, check: journalctl -u blockra.service -b"
