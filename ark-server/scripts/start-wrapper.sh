#!/usr/bin/env bash
# Production entrypoint for ARK: Survival Evolved (Linux x86_64 via Box64).
# SteamCMD stays off on a normal boot — use ./serverctl.sh update.
set -euo pipefail

SERVER=/mnt/ark/server
SAVED="$SERVER/ShooterGame/Saved"
BIN="$SERVER/ShooterGame/Binaries/Linux"
BINARY="$BIN/ShooterGameServer"
EMU_RC="$SAVED/emulators.rc"

MAP="${MAP:-TheIsland}"
SESSION_NAME="${SESSION_NAME:-My ARK Server}"
GAME_PORT="${GAME_PORT:-7777}"
QUERY_PORT="${QUERY_PORT:-27017}"
MAX_PLAYERS="${MAX_PLAYERS:-2}"

SERVER_PID=""

term_handler() {
  echo "Shutting down ARK dedicated server..."
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill -INT "$SERVER_PID" || true
    wait "$SERVER_PID" || true
  fi
  echo "Fin"
  exit 0
}

trap 'term_handler' SIGTERM SIGINT

if [[ -f "$EMU_RC" ]]; then
  echo "Loading Box64 settings from $EMU_RC"
  set -a
  # shellcheck disable=SC1090
  source "$EMU_RC"
  set +a
fi

if [[ "${RUN_STEAMCMD:-0}" == "1" ]]; then
  echo "Updating ARK dedicated server files via SteamCMD (RUN_STEAMCMD=1)"
  STEAMCMD_BIN="${STEAMCMD_BIN:-/home/steam/steamcmd/linux32/steamcmd}"
  if [[ ! -f "$STEAMCMD_BIN" ]]; then
    echo "steamcmd binary not found at $STEAMCMD_BIN" >&2
    exit 1
  fi
  box64 "$STEAMCMD_BIN" \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir "$SERVER" \
    +login anonymous \
    +app_update 376030 -beta preaquatica validate \
    +quit
else
  echo "Skipping SteamCMD on start (set RUN_STEAMCMD=1 to enable). Use ./serverctl.sh update for game files."
fi

if [[ ! -f "$BINARY" ]]; then
  echo "ARK server binary not found at $BINARY" >&2
  echo "Run ./serverctl.sh update first (Steam app 376030, beta preaquatica)." >&2
  exit 1
fi

mkdir -p "$SAVED/Config/LinuxServer" "$SAVED/SavedArks" "$SAVED/Logs"

if command -v box64 >/dev/null 2>&1; then
  BOX64_BIN="$(command -v box64)"
elif [[ -x /usr/local/bin/box64 ]]; then
  BOX64_BIN=/usr/local/bin/box64
else
  echo "box64 not found in PATH or /usr/local/bin/box64" >&2
  exit 1
fi

cd "$BIN"
export LD_LIBRARY_PATH="${BIN}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Passwords live in GameUserSettings.ini (persistentdata), not on the command line.
CMD="${MAP}?listen?SessionName=${SESSION_NAME}?Port=${GAME_PORT}?QueryPort=${QUERY_PORT}?MaxPlayers=${MAX_PLAYERS}"

echo "Starting ARK: $CMD via $BOX64_BIN"
"$BOX64_BIN" "$BINARY" "$CMD" -NoBattlEye -server -log &
SERVER_PID=$!
wait "$SERVER_PID"
