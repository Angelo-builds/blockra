#!/usr/bin/env bash
set -e

echo "🔧 Installing Blockra dependencies..."
apt-get update -y
apt-get install -y curl git nodejs npm locales >/dev/null
locale-gen en_US.UTF-8 >/dev/null || true

echo "📦 Cloning Blockra repository..."
mkdir -p /opt/blockra
cd /opt/blockra
git clone https://github.com/Angelo-builds/blockra.git . >/dev/null 2>&1 || true

echo "📁 Installing Node packages..."
cd /opt/blockra
npm install >/dev/null 2>&1 || true

# --- Create systemd service for backend --------------------------------------
cat <<EOF >/etc/systemd/system/blockra.service
[Unit]
Description=Blockra Node App
After=network.target

[Service]
WorkingDirectory=/opt/blockra
ExecStart=/usr/bin/node /opt/blockra/index.js
Restart=always
User=root
Environment=NODE_ENV=production
StandardOutput=inherit
StandardError=inherit

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable blockra.service
systemctl restart blockra.service

echo "✔️  Blockra installed and service started."
