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
MIN_FREE_MB="6144"

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

check_disk_space(){
  local target="/opt"
  local free_mb
  free_mb="$(df -Pm "$target" | awk 'NR==2 {print $4}')"
  [[ "$free_mb" =~ ^[0-9]+$ ]] || fail "Unable to determine free disk space on ${target}."
  if (( free_mb < MIN_FREE_MB )); then
    fail "Not enough free disk space. Snck needs at least ${MIN_FREE_MB} MB free on ${target}; only ${free_mb} MB is available."
  fi
  ok "Disk space check passed (${free_mb} MB free)."
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
    git -C "$APP_DIR" checkout -q -B "$BRANCH" "origin/$BRANCH"
    git -C "$APP_DIR" reset --hard -q "origin/$BRANCH"
  elif [[ -e "$APP_DIR" ]]; then
    fail "$APP_DIR exists but is not a Git repository. Move or remove it, then retry."
  else
    log "Downloading Snck..."
    git clone --depth=1 --branch "$BRANCH" "$REPO" "$APP_DIR"
  fi
}

set_env_if_blank(){
  local key="$1"
  local value="$2"
  local current=""
  current="$(grep -E "^${key}=" .env | tail -1 | cut -d= -f2- || true)"
  if [[ -z "$current" || "$current" == "replace_me" ]]; then
    if grep -qE "^${key}=" .env; then
      sed -i "s#^${key}=.*#${key}=${value}#" .env
    else
      printf '%s=%s\n' "$key" "$value" >> .env
    fi
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

  # Fixed application port for the Snck installer.
  set_env_if_blank PORT "$PORT"
  set_env_if_blank UID "1000"
  set_env_if_blank GID "1000"

  # Permanent cryptographic credentials for production-safe restarts.
  set_env_if_blank CREDS_KEY "$(openssl rand -hex 32)"
  set_env_if_blank CREDS_IV "$(openssl rand -hex 16)"
  set_env_if_blank JWT_SECRET "$(openssl rand -hex 32)"
  set_env_if_blank JWT_REFRESH_SECRET "$(openssl rand -hex 32)"
  set_env_if_blank SESSION_SECRET "$(openssl rand -hex 32)"
  set_env_if_blank ADMIN_PANEL_SESSION_SECRET "$(openssl rand -hex 32)"
  set_env_if_blank MEILI_MASTER_KEY "$(openssl rand -hex 32)"

  # Keep the local Ollama service address explicit for both the API and admin routes.
  set_env_if_blank OLLAMA_BASE_URL "http://ollama:11434"

  chmod 600 .env
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
  check_disk_space

  log "Building the Snck API with the integrated features..."
  # Use the normal BuildKit cache. A forced --no-cache rebuild can require
  # several GB of temporary storage and caused the previous installation to
  # fail with ENOSPC.
  if ! docker compose -p "$COMPOSE_PROJECT" build api; then
    warn "Docker build failed. Current storage usage:"
    df -h /opt || true
    docker system df || true
    fail "Snck API image build failed. No containers were claimed as healthy."
  fi

  log "Starting Snck and local Ollama services..."
  docker compose -p "$COMPOSE_PROJECT" up -d --remove-orphans

  log "Waiting for the API container to become stable..."
  for _ in {1..45}; do
    if docker compose -p "$COMPOSE_PROJECT" ps --status running --services | grep -qx 'api'; then
      if curl -fsS --max-time 3 "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
        ok "Snck web service is responding on port ${PORT}."
        docker compose -p "$COMPOSE_PROJECT" ps
        return
      fi
    fi
    sleep 2
  done

  docker compose -p "$COMPOSE_PROJECT" ps || true
  docker compose -p "$COMPOSE_PROJECT" logs --tail=160 api >&2 || true
  fail "Snck API did not become healthy on port ${PORT}."
}

install_snck(){
  require_root
  check_ubuntu
  check_disk_space
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

  # Remove only the Snck-built image. Do not remove volumes, databases,
  # Ollama models, or Docker installation data owned by other workloads.
  docker image rm -f snck-ai:local >/dev/null 2>&1 || true
  rm -rf "$APP_DIR"
  ok "Snck application files, containers, and local Snck image removed."
  echo "Docker itself was left installed for other VPS workloads."
  echo "The named Ollama volume is preserved; downloaded models are not deleted."
}

update_snck(){
  require_root
  check_ubuntu
  check_disk_space
  install_prereqs
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
