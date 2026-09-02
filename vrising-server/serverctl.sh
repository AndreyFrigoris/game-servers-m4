#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$PROJECT_ROOT/compose.yml}"
SERVICE_NAME="${SERVICE_NAME:-vrising}"
IMAGE_NAME="${IMAGE_NAME:-tsxcloud/vrising-ntsync:latest}"
VRISING_APP_ID="${VRISING_APP_ID:-1829350}"
VRISING_RUNTIME_APP_ID="${VRISING_RUNTIME_APP_ID:-1604030}"

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker is not installed or not in PATH" >&2
    exit 1
  fi
}

start() {
  compose up -d
}

stop() {
  compose down
}

restart() {
  compose down
  compose up -d
}

print_gameserver_steamid() {
  local sid="" latest="" log_dir="$PROJECT_ROOT/vrising/persistentdata/logs"
  if docker inspect -f '{{.State.Status}}' "$SERVICE_NAME" 2>/dev/null | rg -q '^running$'; then
    sid="$(docker logs "$SERVICE_NAME" 2>&1 | rg -o 'Game server SteamID: [0-9]+' | tail -1 | rg -o '[0-9]+$' || true)"
  fi
  if [[ -z "$sid" && -d "$log_dir" ]]; then
    latest="$(ls -t "$log_dir"/*.log 2>/dev/null | head -1 || true)"
    if [[ -n "$latest" ]]; then
      sid="$(rg -o 'Game server SteamID: [0-9]+' "$latest" | tail -1 | rg -o '[0-9]+$' || true)"
    fi
  fi
  if [[ -n "$sid" ]]; then
    echo "[OK] Steam GameServer ID (Direct Connect / ServerID): $sid"
    echo "     Valid only for the process that logged it. Changes on every container start."
    echo "     In-game: Play → Online → Direct Connect."
  else
    echo "[WARN] Steam GameServer ID not in logs yet (still booting, or Steam login failed)"
  fi
}

status() {
  compose ps
  echo
  print_gameserver_steamid
}

logs() {
  compose logs -f --tail=200 "$SERVICE_NAME"
}

update() {
  echo "[update] stopping server..."
  compose down

  echo "[update] pulling latest container image..."
  docker pull "$IMAGE_NAME"

  echo "[update] updating dedicated server files (Steam app $VRISING_APP_ID)..."
  docker run --rm \
    -v "$PROJECT_ROOT/vrising/server:/mnt/vrising/server" \
    -v "$PROJECT_ROOT/vrising/persistentdata:/mnt/vrising/persistentdata" \
    "$IMAGE_NAME" \
    /bin/bash -lc "steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir /mnt/vrising/server +login anonymous +app_update $VRISING_APP_ID validate +quit"

  # Some broken updates may leave wrong app id in steam_appid.txt.
  if [[ -f "$PROJECT_ROOT/vrising/server/steam_appid.txt" ]]; then
    printf "%s\n" "$VRISING_RUNTIME_APP_ID" > "$PROJECT_ROOT/vrising/server/steam_appid.txt"
  fi

  echo "[update] starting server..."
  compose up -d
  compose ps
}

backup() {
  "$PROJECT_ROOT/scripts/backup.sh"
}

backup_prune() {
  BACKUP_CREATE_ARCHIVE=0 "$PROJECT_ROOT/scripts/backup.sh"
}

launchd_install() {
  "$PROJECT_ROOT/scripts/install-launchd.sh"
}

health_check() {
  local container_state latest_backup
  local backup_dir="$PROJECT_ROOT/backups/auto"
  local host_settings="$PROJECT_ROOT/vrising/persistentdata/Settings/ServerHostSettings.json"
  local appid_file="$PROJECT_ROOT/vrising/server/steam_appid.txt"
  local has_warnings=0

  echo "== V Rising Health Check =="
  echo "Project: $PROJECT_ROOT"
  echo "Time: $(date)"
  echo

  if ! docker info >/dev/null 2>&1; then
    echo "[FAIL] Docker daemon is not reachable"
    return 1
  fi
  echo "[OK] Docker daemon is reachable"

  container_state="$(docker inspect -f '{{.State.Status}}' "$SERVICE_NAME" 2>/dev/null || true)"
  if [[ "$container_state" == "running" ]]; then
    echo "[OK] Container '$SERVICE_NAME' is running"
  elif [[ -n "$container_state" ]]; then
    echo "[WARN] Container '$SERVICE_NAME' state: $container_state"
    has_warnings=1
  else
    echo "[WARN] Container '$SERVICE_NAME' does not exist"
    has_warnings=1
  fi

  if [[ -f "$host_settings" ]]; then
    echo "[OK] Host settings exist: $host_settings"
  else
    echo "[WARN] Host settings not found yet: $host_settings"
    has_warnings=1
  fi

  if [[ -f "$appid_file" ]]; then
    if rg -q "^${VRISING_RUNTIME_APP_ID}$" "$appid_file"; then
      echo "[OK] steam_appid.txt is ${VRISING_RUNTIME_APP_ID}"
    else
      echo "[WARN] steam_appid.txt is unexpected (should be ${VRISING_RUNTIME_APP_ID})"
      has_warnings=1
    fi
  else
    echo "[WARN] steam_appid.txt not found yet"
    has_warnings=1
  fi

  latest_backup="$(ls -1t "$backup_dir"/vrising-backup-*.tar.gz 2>/dev/null | awk 'NR==1' || true)"
  if [[ -n "${latest_backup:-}" ]]; then
    if find "$latest_backup" -mtime -1 -print | rg -q .; then
      echo "[OK] Latest backup is fresh (<24h): $latest_backup"
    else
      echo "[WARN] Latest backup is older than 24h: $latest_backup"
      has_warnings=1
    fi
  else
    echo "[WARN] No backup archives found in $backup_dir"
    has_warnings=1
  fi

  print_gameserver_steamid

  if command -v nc >/dev/null 2>&1; then
    if nc -uz 127.0.0.1 27015 >/dev/null 2>&1 && nc -uz 127.0.0.1 27016 >/dev/null 2>&1; then
      echo "[OK] UDP ports 27015/27016 respond locally"
    else
      echo "[WARN] UDP ports 27015/27016 do not respond locally"
      has_warnings=1
    fi
  else
    echo "[WARN] nc is unavailable, skipping UDP probe"
    has_warnings=1
  fi

  echo
  if [[ "$container_state" == "running" && "$has_warnings" == "0" ]]; then
    echo "Result: HEALTHY (basic checks passed)"
    return 0
  fi
  echo "Result: NEEDS ATTENTION (see WARN/FAIL lines)"
  return 1
}

doctor() {
  echo "== V Rising Doctor =="
  echo
  health_check || true
  echo
  echo "== Docker Compose Status =="
  compose ps || true
  echo
  echo "== Last 40 log lines =="
  compose logs --tail=40 "$SERVICE_NAME" || true
}

help_msg() {
  cat <<'EOF'
Usage:
  ./serverctl.sh <command>

Commands:
  start           Start server in background
  stop            Stop server
  restart         Restart server
  status          Show container status + current Steam GameServer ID
  steam-id        Print Steam GameServer ID for in-game Direct Connect
  logs            Tail server logs
  update          One-command update (steamcmd validate + restart)
  backup          Create backup archive now + prune old backups
  backup-prune    Prune old backups only
  health-check    Quick health check
  doctor          Extended diagnostics
  launchd-install Install daily backup launchd job (macOS)
  help            Show this help

Environment overrides:
  COMPOSE_FILE          Default: ./compose.yml
  SERVICE_NAME          Default: vrising
  IMAGE_NAME            Default: tsxcloud/vrising-ntsync:latest
  VRISING_APP_ID        Default: 1829350
  VRISING_RUNTIME_APP_ID Default: 1604030
EOF
}

main() {
  require_docker
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    start) start "$@" ;;
    stop) stop "$@" ;;
    restart) restart "$@" ;;
    status) status "$@" ;;
    steam-id) print_gameserver_steamid ;;
    logs) logs "$@" ;;
    update) update "$@" ;;
    backup) backup "$@" ;;
    backup-prune) backup_prune "$@" ;;
    health-check) health_check "$@" ;;
    doctor) doctor "$@" ;;
    launchd-install) launchd_install "$@" ;;
    help|-h|--help) help_msg ;;
    *)
      echo "Unknown command: $cmd" >&2
      help_msg
      exit 1
      ;;
  esac
}

main "$@"
