#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$PROJECT_ROOT/compose.yml}"
SERVICE_NAME="${SERVICE_NAME:-ark}"
IMAGE_NAME="${IMAGE_NAME:-sonroyaalmerol/steamcmd-arm64:latest}"
ARK_APP_ID="${ARK_APP_ID:-376030}"
ARK_BETA="${ARK_BETA:-preaquatica}"
HEAVY_PEERS="${HEAVY_PEERS:-enshrouded vrising}"

if [[ -f "$PROJECT_ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/.env"
  set +a
fi

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker is not installed or not in PATH" >&2
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "Docker daemon is not reachable. Start Docker Desktop and retry." >&2
    exit 1
  fi
}

binary_path() {
  echo "$PROJECT_ROOT/server/ShooterGame/Binaries/Linux/ShooterGameServer"
}

seed_persistentdata() {
  local cfg="$PROJECT_ROOT/persistentdata/Config/LinuxServer"
  mkdir -p "$cfg" "$PROJECT_ROOT/persistentdata/SavedArks" "$PROJECT_ROOT/persistentdata/Logs" "$PROJECT_ROOT/server"

  if [[ ! -f "$PROJECT_ROOT/persistentdata/emulators.rc" ]]; then
    cp "$PROJECT_ROOT/examples/emulators.rc" "$PROJECT_ROOT/persistentdata/emulators.rc"
  fi
  if [[ ! -f "$cfg/GameUserSettings.ini" ]]; then
    cp "$PROJECT_ROOT/examples/GameUserSettings.ini" "$cfg/GameUserSettings.ini"
    echo "[warn] Copied examples/GameUserSettings.ini — set ServerPassword / ServerAdminPassword before playing."
  fi
  if [[ ! -f "$cfg/Game.ini" ]]; then
    cp "$PROJECT_ROOT/examples/Game.ini" "$cfg/Game.ini"
  fi
}

other_heavy_running() {
  local name
  for name in $HEAVY_PEERS; do
    if docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null | grep -qx true; then
      echo "$name"
    fi
  done
}

refuse_if_heavy_peers() {
  local running
  running="$(other_heavy_running)"
  if [[ -n "$running" ]]; then
    echo "Refusing to start ARK while another heavy server is running: $running" >&2
    echo "On 16 GB, ARK is the only heavy process. Stop them first:" >&2
    echo "  ~/GameServers/enshrouded-server/serverctl.sh stop" >&2
    echo "  ~/GameServers/vrising-server/serverctl.sh stop" >&2
    exit 1
  fi
}

start() {
  refuse_if_heavy_peers
  seed_persistentdata
  if [[ ! -f "$(binary_path)" ]]; then
    echo "ARK server files are missing. Run: ./serverctl.sh update" >&2
    exit 1
  fi
  compose up -d
}

stop() {
  compose down
}

restart() {
  stop
  start
}

status() {
  compose ps
}

logs() {
  compose logs -f --tail=200 "$SERVICE_NAME"
}

update() {
  echo "[update] stopping server..."
  compose down || true

  echo "[update] pulling container image..."
  docker pull "$IMAGE_NAME"

  mkdir -p "$PROJECT_ROOT/server" "$PROJECT_ROOT/.steamcmd" "$PROJECT_ROOT/.steam-home"

  # First populate a host copy of SteamCMD so self-updates survive docker run --rm.
  # Without that, every attempt re-downloads the client and exits 42 after relaunch.
  if [[ ! -f "$PROJECT_ROOT/.steamcmd/linux32/steamcmd" ]]; then
    echo "[update] seeding SteamCMD files from the image..."
    docker run --rm \
      --entrypoint /bin/bash \
      -v "$PROJECT_ROOT/.steamcmd:/out" \
      "$IMAGE_NAME" \
      -lc "cp -a /home/steam/steamcmd/. /out/"
  fi

  echo "[update] SteamCMD app_update $ARK_APP_ID ${ARK_BETA:+-beta $ARK_BETA} validate (this is large)..."

  local attempt rc=1 log
  log="$(mktemp)"
  # steamcmd.sh on aarch64 looks for linuxarm64/ after self-update. Drive linux32 via Box64.
  # Attempt 2+ usually works once the persisted client is already current.
  # +app_update 376030 -beta … on one argv is parsed wrong ("Missing configuration");
  # a runscript keeps -beta attached to app_update.
  for attempt in 1 2 3; do
    echo "[update] steamcmd attempt ${attempt}/3"
    : >"$log"
    set +e
    docker run --rm \
      --entrypoint /bin/bash \
      -e ARM64_DEVICE="${ARM64_DEVICE:-generic}" \
      -e BOX64_LOG=0 \
      -e ARK_APP_ID="$ARK_APP_ID" \
      -e ARK_BETA="${ARK_BETA:-}" \
      -v "$PROJECT_ROOT/server:/mnt/ark/server" \
      -v "$PROJECT_ROOT/.steamcmd:/home/steam/steamcmd" \
      -v "$PROJECT_ROOT/.steam-home:/home/steam/Steam" \
      "$IMAGE_NAME" \
      -lc 'set -euo pipefail
script=/tmp/ark_update.txt
{
  echo "@ShutdownOnFailedCommand 1"
  echo "@NoPromptForPassword 1"
  echo "@sSteamCmdForcePlatformType linux"
  echo "force_install_dir /mnt/ark/server"
  echo "login anonymous"
  if [[ -n "${ARK_BETA:-}" ]]; then
    echo "app_update ${ARK_APP_ID} -beta ${ARK_BETA} validate"
  else
    echo "app_update ${ARK_APP_ID} validate"
  fi
  echo "quit"
} >"$script"
box64 /home/steam/steamcmd/linux32/steamcmd +runscript "$script"
' | tee "$log"
    rc=${PIPESTATUS[0]}
    set -e
    if grep -q "ERROR!" "$log"; then
      rc=1
    fi
    if [[ "$rc" -eq 0 ]]; then
      break
    fi
    echo "[update] steamcmd exited $rc"
  done
  rm -f "$log"
  if [[ "$rc" -ne 0 ]]; then
    echo "[update] SteamCMD failed after 3 attempts" >&2
    exit "$rc"
  fi

  echo "[update] starting server..."
  start
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
  local container_state latest_backup has_warnings=0
  local backup_dir="$PROJECT_ROOT/backups/auto"
  local gus="$PROJECT_ROOT/persistentdata/Config/LinuxServer/GameUserSettings.ini"
  local binary
  binary="$(binary_path)"

  echo "== ARK Health Check =="
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

  local peer
  peer="$(other_heavy_running || true)"
  if [[ -n "$peer" ]]; then
    echo "[WARN] Other heavy server(s) also running: $peer (16 GB host)"
    has_warnings=1
  else
    echo "[OK] No other heavy game servers running"
  fi

  if [[ -f "$binary" ]]; then
    echo "[OK] Server binary exists"
  else
    echo "[WARN] Server binary not found (run ./serverctl.sh update)"
    has_warnings=1
  fi

  if [[ -f "$gus" ]]; then
    echo "[OK] GameUserSettings.ini exists"
  else
    echo "[WARN] GameUserSettings.ini not found yet"
    has_warnings=1
  fi

  latest_backup="$(ls -1t "$backup_dir"/ark-backup-*.tar.gz 2>/dev/null | awk 'NR==1' || true)"
  if [[ -n "${latest_backup:-}" ]]; then
    if find "$latest_backup" -mtime -1 -print | grep -q .; then
      echo "[OK] Latest backup is fresh (<24h): $latest_backup"
    else
      echo "[WARN] Latest backup is older than 24h: $latest_backup"
      has_warnings=1
    fi
  else
    echo "[WARN] No backup archives found in $backup_dir"
    has_warnings=1
  fi

  if command -v nc >/dev/null 2>&1; then
    if nc -uz 127.0.0.1 7777 >/dev/null 2>&1 && nc -uz 127.0.0.1 27017 >/dev/null 2>&1; then
      echo "[OK] UDP ports 7777/27017 respond locally"
    else
      echo "[WARN] UDP ports 7777/27017 do not respond locally (server may still be booting)"
      has_warnings=1
    fi
  else
    echo "[WARN] nc is unavailable, skipping UDP probe"
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
  echo "== ARK Doctor =="
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
  status          Show container status
  logs            Tail server logs
  update          Pull image + SteamCMD validate (preaquatica) + start
  backup          Create backup archive now + prune old backups
  backup-prune    Prune old backups only
  health-check    Quick health check
  doctor          Extended diagnostics
  launchd-install Install daily backup launchd job (macOS)
  help            Show this help

Environment overrides:
  COMPOSE_FILE    Default: ./compose.yml
  SERVICE_NAME    Default: ark
  IMAGE_NAME      Default: sonroyaalmerol/steamcmd-arm64:latest
  ARK_APP_ID      Default: 376030
  ARK_BETA        Default: preaquatica (empty = live branch)
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
