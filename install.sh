#!/usr/bin/env bash
set -Eeuo pipefail

# Snck — one-command AI Platform installer for Ubuntu VPS
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/SnckBoy/Sn-ai/admin/retention-mode/install.sh)

REPO="https://github.com/SnckBoy/Sn-ai.git"
BRANCH="admin/retention-mode"
APP_DIR="/opt/sn-ai"
COMPOSE_PROJECT="sn-ai"
PORT="3080"

log(){ printf '\033[1;36m[Snck]\033[0m %s\n' "$*"; }
ok(){ printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
fail(){ printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }
trap 'fail "Operation stopped near line $LINENO. Check the message above."' ERR

require_root(){ [[ $EUID -eq 0 ]] || fail "Run this installer as root (for example: sudo bash install.sh)."; }
check_ubuntu(){
  [[ -r /etc/os-release ]] || fail "Cannot detect the operating system."
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]] || fail "Snck supports Ubuntu only. Detected: ${PRETTY_NAME:-unknown}"
}

install_prereqs(){
  log "Installing required Ubuntu packages..."
  apt-get update -y
  apt-get install -y ca-certificates curl git openssl
}

install_docker(){
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    systemctl enable --now docker
    ok "Docker Engine and Compose are ready."
    return
  fi

  log "Installing Docker Engine and Compose plugin..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  . /etc/os-release
  printf '%s\n' "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  command -v docker >/dev/null 2>&1 || fail "Docker installation failed."
  docker compose version >/dev/null 2>&1 || fail "Docker Compose plugin installation failed."
  ok "Docker installed successfully."
}

clone_or_update(){
  if [[ -d "${APP_DIR}/.git" ]]; then
    log "Updating existing Snck installation..."
    git -C "$APP_DIR" fetch --depth=1 origin "$BRANCH"
    git -C "$APP_DIR" checkout -q "$BRANCH"
    git -C "$APP_DIR" reset --hard -q "origin/$BRANCH"
  elif [[ -e "$APP_DIR" ]]; then
    fail "$APP_DIR exists but is not a Git repository. Move or remove it, then retry."
  else
    log "Downloading Snck..."
    git clone --depth=1 --branch "$BRANCH" "$REPO" "$APP_DIR"
  fi
}

prepare_env(){
  cd "$APP_DIR"
  [[ -f .env.example ]] || fail ".env.example is missing from the Snck repository."

  if [[ ! -f .env ]]; then
    cp .env.example .env
    chmod 600 .env
    ok "Created .env from .env.example."
  else
    chmod 600 .env
    log "Keeping existing .env configuration."
  fi

  if grep -qE '^JWT_SECRET=replace_me$' .env 2>/dev/null; then
    sed -i "s/^JWT_SECRET=.*/JWT_SECRET=$(openssl rand -hex 32)/" .env
  fi
  if grep -qE '^SESSION_SECRET=replace_me$' .env 2>/dev/null; then
    sed -i "s/^SESSION_SECRET=.*/SESSION_SECRET=$(openssl rand -hex 32)/" .env
  fi

  # The bundled admin panel requires a session secret. Generate one when the
  # template is empty, but never overwrite an existing user-provided value.
  if grep -qE '^ADMIN_PANEL_SESSION_SECRET=$' .env 2>/dev/null; then
    sed -i "s/^ADMIN_PANEL_SESSION_SECRET=.*/ADMIN_PANEL_SESSION_SECRET=$(openssl rand -hex 32)/" .env
  fi

  # Keep the local Ollama service address explicit for both the API and admin routes.
  if grep -qE '^OLLAMA_BASE_URL=' .env 2>/dev/null; then
    sed -i 's#^OLLAMA_BASE_URL=.*#OLLAMA_BASE_URL=http://ollama:11434#' .env
  else
    printf '\nOLLAMA_BASE_URL=http://ollama:11434\n' >> .env
  fi
}

validate_compose(){
  cd "$APP_DIR"
  log "Validating Docker Compose configuration..."
  docker compose -p "$COMPOSE_PROJECT" config >/dev/null
  ok "Docker Compose configuration is valid."
}

start_snck(){
  cd "$APP_DIR"
  validate_compose

  log "Building the Snck API with the integrated features..."
  docker compose -p "$COMPOSE_PROJECT" build api

  log "Starting Snck and local Ollama services..."
  docker compose -p "$COMPOSE_PROJECT" up -d --remove-orphans

  log "Waiting for the API container..."
  for _ in {1..30}; do
    if docker compose -p "$COMPOSE_PROJECT" ps --status running --services | grep -qx 'api'; then
      break
    fi
    sleep 2
  done

  docker compose -p "$COMPOSE_PROJECT" ps

  if ! docker compose -p "$COMPOSE_PROJECT" ps --status running --services | grep -qx 'api'; then
    docker compose -p "$COMPOSE_PROJECT" logs --tail=120 api >&2 || true
    fail "Snck API did not stay running."
  fi

  if curl -fsS --max-time 10 "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
    ok "Snck web service is responding on port ${PORT}."
  else
    warn "Containers are running, but the HTTP health check is not ready yet."
    warn "Run: cd ${APP_DIR} && docker compose -p ${COMPOSE_PROJECT} logs --tail=100 api"
  fi
}

install_snck(){
  require_root
  check_ubuntu
  install_prereqs
  install_docker
  clone_or_update
  prepare_env
  start_snck

  SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
  SERVER_IP="${SERVER_IP:-127.0.0.1}"
  echo
  ok "Snck installation complete."
  echo "URL: http://${SERVER_IP}:${PORT}"
  echo "Directory: ${APP_DIR}"
  echo "Local AI: Snck Local (Ollama)"
}

uninstall_snck(){
  require_root
  if [[ ! -d "$APP_DIR" ]]; then
    warn "Snck is not installed at ${APP_DIR}."
    return
  fi

  cd "$APP_DIR"
  if docker compose -p "$COMPOSE_PROJECT" config >/dev/null 2>&1; then
    log "Stopping Snck containers..."
    docker compose -p "$COMPOSE_PROJECT" down --remove-orphans
  fi

  rm -rf "$APP_DIR"
  ok "Snck application files and containers removed."
  echo "Docker itself was left installed for other VPS workloads."
  echo "The named Ollama volume is preserved; remove it manually if you also want to delete downloaded models."
}

update_snck(){
  require_root
  check_ubuntu
  install_docker

  if [[ ! -d "${APP_DIR}/.git" ]]; then
    warn "Snck is not installed at ${APP_DIR}; starting a fresh installation."
    install_snck
    return
  fi

  clone_or_update
  prepare_env
  start_snck
  ok "Snck update complete."
}

status_snck(){
  require_root
  if [[ ! -d "$APP_DIR" ]]; then
    echo "Snck is not installed."
    return
  fi
  cd "$APP_DIR"
  docker compose -p "$COMPOSE_PROJECT" ps || true
}

logs_snck(){
  require_root
  if [[ ! -d "$APP_DIR" ]]; then
    echo "Snck is not installed."
    return
  fi
  cd "$APP_DIR"
  docker compose -p "$COMPOSE_PROJECT" logs --tail=150
}

show_menu(){
  clear 2>/dev/null || true
  echo "============================================================"
  echo "                 Snck — AI Platform"
  echo "============================================================"
  echo "  1) Install / Repair Snck + Local AI"
  echo "  2) Uninstall Snck"
  echo "  3) Update Snck"
  echo "  4) Status"
  echo "  5) Logs"
  echo "  0) Exit"
  echo "============================================================"
  printf "Select an option [0-5]: "
}

main(){
  require_root
  while true; do
    show_menu
    read -r choice
    case "$choice" in
      1) install_snck; read -r -p "Press Enter to return to menu..." _ ;;
      2) uninstall_snck; read -r -p "Press Enter to return to menu..." _ ;;
      3) update_snck; read -r -p "Press Enter to return to menu..." _ ;;
      4) status_snck; read -r -p "Press Enter to return to menu..." _ ;;
      5) logs_snck; read -r -p "Press Enter to return to menu..." _ ;;
      0) exit 0 ;;
      *) echo "Invalid option. Choose 0-5."; sleep 1 ;;
    esac
  done
}

main "$@"
