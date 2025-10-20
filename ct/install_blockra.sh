#!/usr/bin/env bash
set -euo pipefail
APP_HOME="/opt/blockra"
PORT=3000
echo "[Blockra] Starting in-container installer..."
export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y curl gnupg ca-certificates build-essential sqlite3 libsqlite3-dev
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
if ! id -u blockra >/dev/null 2>&1; then
  useradd -m -s /bin/bash blockra
fi
chown -R blockra:blockra ${APP_HOME} || true
CONFIG_FILE="/opt/blockra/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
  cat > "$CONFIG_FILE" <<'CFG'
{ "user": "admin", "pass": "admin" }
CFG
  chown blockra:blockra "$CONFIG_FILE"
fi
if [ -f "${APP_HOME}/package.json" ]; then
  su - blockra -c "cd ${APP_HOME} && npm install --production --silent || true" || true
fi
if [ -d "${APP_HOME}/client" ]; then
  su - blockra -c "cd ${APP_HOME}/client && npm install --silent && npm run build || true" || true
fi
mkdir -p /opt/blockra/uploads /opt/blockra/data
chown -R blockra:blockra /opt/blockra/uploads /opt/blockra/data
DB_FILE="/opt/blockra/data/blockra.db"
if [ ! -f "$DB_FILE" ]; then
  sqlite3 "$DB_FILE" "CREATE TABLE pages (id INTEGER PRIMARY KEY, name TEXT, content TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP);"
  chown blockra:blockra "$DB_FILE"
fi
cat > /etc/systemd/system/blockra.service <<'SERVICE'
[Unit]
Description=Blockra Node App
After=network.target
[Service]
Type=simple
User=blockra
WorkingDirectory=/opt/blockra
Environment=NODE_ENV=production
ExecStart=/usr/bin/node /opt/blockra/server/index.js
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
SERVICE
systemctl daemon-reload
systemctl enable --now blockra.service || true
echo "[Blockra] Service started, listening on port ${PORT} (if server is up)." 
echo "[Blockra] If the service failed, check: journalctl -u blockra.service -b"
