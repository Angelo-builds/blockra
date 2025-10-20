#!/usr/bin/env bash
set -euo pipefail
# This script runs inside the LXC container to install Blockra app

APP_HOME="/opt/blockra"
PORT=3000

echo "[Blockra] Installing system packages..."
export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y curl git build-essential sqlite3 libsqlite3-dev

# Install Node.js 20.x (Nodesource)
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Create a user for running the app
if ! id -u blockra >/dev/null 2>&1; then
  useradd -m -s /bin/bash blockra
fi

echo "[Blockra] Installing app dependencies..."
cd ${APP_HOME}
chown -R blockra:blockra ${APP_HOME}

su - blockra -c "cd ${APP_HOME} && npm install --production --silent || true"
# Build frontend (if present)
su - blockra -c "cd ${APP_HOME}/client && npm install --silent && npm run build || true"

echo "[Blockra] Prepare uploads and DB..."
mkdir -p /opt/blockra/uploads
chown -R blockra:blockra /opt/blockra/uploads

# Create simple SQLite DB if not exists
DB_FILE="/opt/blockra/data/blockra.db"
mkdir -p /opt/blockra/data
if [ ! -f "$DB_FILE" ]; then
  sqlite3 "$DB_FILE" "CREATE TABLE pages (id INTEGER PRIMARY KEY, name TEXT, content TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP);"
  chown blockra:blockra "$DB_FILE"
fi

echo "[Blockra] Create systemd service..."
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
systemctl enable --now blockra.service

echo "[Blockra] Installation finished. Server should be listening on port ${PORT}."
