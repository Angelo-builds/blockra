# Blockra - Proxmox LXC installer + Self-hosted Drag&Drop Site Builder

This repository contains:
- `ct/blockra.sh` : Proxmox LXC installer script. Run on Proxmox host:
  ```
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Angelo-builds/blockra/main/ct/blockra.sh)"
  ```
- `app/` : Node.js application (Express backend + React frontend built with Vite).
- `LICENSE` : MIT

The installer will:
- create a Debian 12 unprivileged LXC,
- install Node.js, npm, build tools,
- clone this repo into `/opt/blockra` inside the container,
- run the app as a systemd service on port 3000.

The app:
- simple drag & drop page builder (blocks: text, image, container),
- saves pages to SQLite DB,
- images uploaded are stored on disk (`/opt/blockra/uploads`).

This is a minimal, extendable prototype meant to be improved and hardened before production use.
