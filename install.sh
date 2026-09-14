#!/usr/bin/env bash
set -Eeuo pipefail

# Sn-ai — one-command LibreChat installer for Ubuntu VPS
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/SnckBoy/Sn-ai/admin/retention-mode/install.sh)

REPO="https://github.com/SnckBoy/Sn-ai.git"
BRANCH="admin/retention-mode"
APP_DIR="/opt/sn-ai"
PORT="3080"

log()  { printf '\033[1;36m[Sn-ai]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

trap 'fail "Installation stopped near line $LINENO. Check the message above."' ERR

[[ $EUID -eq 0 ]] || fail "Run this installer as root: sudo bash ..."

if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]] || fail "This installer supports Ubuntu. Detected: ${PRETTY_NAME:-unknown}"
else
  fail "Cannot detect the Linux distribution."
fi

log "Updating Ubuntu packages..."
apt-get update -y
apt-get install -y ca-certificates curl git

if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker Engine and Docker Compose plugin..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  log "Docker is already installed."
fi

systemctl enable --now docker
command -v docker >/dev/null 2>&1 || fail "Docker installation failed."
docker compose version >/dev/null 2>&1 || fail "Docker Compose plugin is missing."

if [[ -d "${APP_DIR}/.git" ]]; then
  log "Existing Sn-ai installation found; updating it..."
  git -C "$APP_DIR" fetch --depth=1 origin "$BRANCH"
  git -C "$APP_DIR" checkout -q "$BRANCH"
  git -C "$APP_DIR" reset --hard -q "origin/$BRANCH"
else
  if [[ -e "$APP_DIR" ]]; then
    fail "$APP_DIR exists but is not a Git repository. Move/remove it and run the installer again."
  fi
  log "Cloning Sn-ai / LibreChat..."
  git clone --depth=1 --branch "$BRANCH" "$REPO" "$APP_DIR"
fi

cd "$APP_DIR"

if [[ ! -f .env ]]; then
  cp .env.example .env
  chmod 600 .env
  ok "Created .env from .env.example"
else
  log ".env already exists; keeping your existing configuration."
fi

# Generate a strong JWT secret when the template still contains its placeholder.
if grep -qE '^JWT_SECRET=replace_me' .env 2>/dev/null; then
  JWT_SECRET="$(openssl rand -hex 32 2>/dev/null || true)"
  if [[ -n "$JWT_SECRET" ]]; then
    sed -i "s/^JWT_SECRET=.*/JWT_SECRET=$JWT_SECRET/" .env
  fi
fi

# Generate a strong session secret when the template still contains its placeholder.
if grep -qE '^SESSION_SECRET=replace_me' .env 2>/dev/null; then
  SESSION_SECRET="$(openssl rand -hex 32 2>/dev/null || true)"
  if [[ -n "$SESSION_SECRET" ]]; then
    sed -i "s/^SESSION_SECRET=.*/SESSION_SECRET=$SESSION_SECRET/" .env
  fi
fi

log "Starting LibreChat containers..."
docker compose pull
# Compose's default configuration is the supported LibreChat deployment path.
docker compose up -d

docker compose ps

SERVER_IP="$(hostname -I | awk '{print $1}')"

echo
echo "============================================================"
echo "  Sn-ai / LibreChat installation complete"
echo "============================================================"
echo "  URL:      http://${SERVER_IP}:${PORT}"
echo "  Directory: ${APP_DIR}"
echo
echo "  First account: the first account registered in a"
echo "  single-tenant deployment becomes the admin account."
echo
echo "  Useful commands:"
echo "    cd ${APP_DIR}"
echo "    docker compose ps"
echo "    docker compose logs -f api"
echo "    docker compose restart"
echo "    docker compose down"
echo "============================================================"
