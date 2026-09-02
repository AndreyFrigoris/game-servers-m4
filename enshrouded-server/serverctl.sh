#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$PROJECT_ROOT/compose.yml}"
SERVICE_NAME="${SERVICE_NAME:-enshrouded}"
IMAGE_NAME="${IMAGE_NAME:-tsxcloud/enshrouded-arm:latest}"
ENSHROUDED_APP_ID="${ENSHROUDED_APP_ID:-2278520}"

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

status() {
  compose ps
}

logs() {
  compose logs -f --tail=200 "$SERVICE_NAME"
}

update() {
  echo "[update] stopping server..."
  compose down

  echo "[update] pulling latest container image..."
  docker pull "$IMAGE_NAME"

  echo "[update] updating dedicated server files (Steam app $ENSHROUDED_APP_ID)..."
  docker run --rm \
    -v "$PROJECT_ROOT/EnshroudedServer:/mnt/enshrouded/server" \
    -v "$PROJECT_ROOT/persistentdata:/mnt/enshrouded/persistentdata" \
    "$IMAGE_NAME" \
    /bin/bash -lc "steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir /mnt/enshrouded/server +login anonymous +app_update $ENSHROUDED_APP_ID validate +quit"

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

cron_install() {
  "$PROJECT_ROOT/scripts/install-cron.sh"
}

launchd_install() {
  "$PROJECT_ROOT/scripts/install-launchd.sh"
}

health_check() {
  local container_state latest_backup backup_age log_size ports_ok
  local log_file="$PROJECT_ROOT/persistentdata/logs/enshrouded_server.log"
  local backup_dir="$PROJECT_ROOT/backups/auto"

  echo "== Enshrouded Health Check =="
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
  else
    echo "[WARN] Container '$SERVICE_NAME' does not exist"
  fi

  if [[ -f "$log_file" ]]; then
    log_size="$(du -h "$log_file" | awk '{print $1}')"
    echo "[OK] Log file exists: $log_file ($log_size)"
  else
    echo "[WARN] Log file not found: $log_file"
  fi

  latest_backup="$(ls -1t "$backup_dir"/enshrouded-backup-*.tar.gz 2>/dev/null | awk 'NR==1')"
  if [[ -n "${latest_backup:-}" ]]; then
    backup_age="$(find "$latest_backup" -mtime -1 -print | wc -l | tr -d ' ')"
    if [[ "$backup_age" == "1" ]]; then
      echo "[OK] Latest backup is fresh (<24h): $latest_backup"
    else
      echo "[WARN] Latest backup is older than 24h: $latest_backup"
    fi
  else
    echo "[WARN] No backup archives found in $backup_dir"
  fi

  ports_ok="unknown"
  if command -v nc >/dev/null 2>&1; then
    if nc -uz 127.0.0.1 15636 >/dev/null 2>&1 && nc -uz 127.0.0.1 15637 >/dev/null 2>&1; then
      ports_ok="yes"
      echo "[OK] UDP ports 15636/15637 respond locally"
    else
      ports_ok="no"
      echo "[WARN] UDP ports 15636/15637 do not respond locally"
    fi
  else
    echo "[WARN] nc is unavailable, skipping UDP probe"
  fi

  echo
  if [[ "$container_state" == "running" && -n "${latest_backup:-}" ]]; then
    echo "Result: HEALTHY (basic checks passed)"
    return 0
  fi
  echo "Result: NEEDS ATTENTION (see WARN/FAIL lines)"
  return 1
}

doctor() {
  echo "== Enshrouded Doctor =="
  echo
  health_check || true
  echo
  echo "== Docker Compose Status =="
  compose ps || true
  echo
  echo "== Last 30 log lines =="
  compose logs --tail=30 "$SERVICE_NAME" || true
}

help_msg() {
  cat <<'EOF'
Usage:
  ./serverctl.sh <command>

Commands:
  start          Start server in background
  stop           Stop server
  restart        Restart server
  status         Show container status
  logs           Tail server logs
  update         One-command update (steamcmd validate + restart)
  backup         Create backup archive now + prune old backups
  backup-prune   Prune old backups only
  health-check   Quick health check (container/logs/backup/ports)
  doctor         Extended diagnostics (health + status + logs)
  cron-install   Install daily backup cron job
  launchd-install Install daily backup launchd job (macOS)
  help           Show this help

Environment overrides:
  COMPOSE_FILE         Default: ./compose.yml
  SERVICE_NAME         Default: enshrouded
  IMAGE_NAME           Default: tsxcloud/enshrouded-arm:latest
  ENSHROUDED_APP_ID    Default: 2278520
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
    logs) logs "$@" ;;
    update) update "$@" ;;
    backup) backup "$@" ;;
    backup-prune) backup_prune "$@" ;;
    health-check) health_check "$@" ;;
    doctor) doctor "$@" ;;
    cron-install) cron_install "$@" ;;
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
