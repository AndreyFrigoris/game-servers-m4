#!/usr/bin/env bash
# Production entrypoint for Conan Exiles Enhanced (Linux x86_64 via Box64).
# SteamCMD stays off on a normal boot — use ./serverctl.sh update.
set -euo pipefail

SERVER=/mnt/conan/server
SAVED="$SERVER/ConanSandbox/Saved"
BIN="$SERVER/ConanSandbox/Binaries/Linux"
BINARY="$BIN/ConanSandboxServer-Linux-Shipping"
EMU_RC="$SAVED/emulators.rc"
ENGINE_INI="$SAVED/Config/LinuxServer/Engine.ini"

SERVER_NAME="${SERVER_NAME:-My Conan Server}"
MAP="${MAP:-ExiledLands}"
GAME_PORT="${GAME_PORT:-7787}"
QUERY_PORT="${QUERY_PORT:-27019}"
MAX_PLAYERS="${MAX_PLAYERS:-2}"

SERVER_PID=""

map_path() {
  case "$MAP" in
    Siptah|siptah|IsleOfSiptah|DLC_Isle_of_Siptah)
      echo "/Game/DLC_EXT/DLC_Siptah/Maps/DLC_Isle_of_Siptah"
      ;;
    ExiledLands|exiled|ConanSandbox|*)
      echo "/Game/Maps/ConanSandbox/ConanSandbox"
      ;;
  esac
}

term_handler() {
  echo "Shutting down Conan dedicated server (SIGINT so SQLite can flush)..."
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
  echo "Updating Conan dedicated server files via SteamCMD (RUN_STEAMCMD=1)"
  STEAMCMD_BIN="${STEAMCMD_BIN:-/home/steam/steamcmd/linux32/steamcmd}"
  if [[ ! -f "$STEAMCMD_BIN" ]]; then
    echo "steamcmd binary not found at $STEAMCMD_BIN" >&2
    exit 1
  fi
  box64 "$STEAMCMD_BIN" \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir "$SERVER" \
    +login anonymous \
    +app_info_update 1 \
    +app_update 443030 validate \
    +quit
else
  echo "Skipping SteamCMD on start (set RUN_STEAMCMD=1 to enable). Use ./serverctl.sh update for game files."
fi

if [[ ! -x "$BINARY" && ! -f "$BINARY" ]]; then
  echo "Conan server binary not found at $BINARY" >&2
  echo "Run ./serverctl.sh update first (Steam app 443030, force linux depot)." >&2
  exit 1
fi

mkdir -p "$SAVED/Config/LinuxServer" "$SAVED/Logs" "$SERVER/ConanSandbox/Mods" \
  /home/steam/.steam/sdk64

# UE Steam OSS looks here. Without it: "SteamSockets: Disabled due to no Steam OSS"
# and joins die with UniqueId INVALID (client then lies: "password not valid").
if [[ -f "$SERVER/linux64/steamclient.so" ]]; then
  ln -sfn "$SERVER/linux64/steamclient.so" /home/steam/.steam/sdk64/steamclient.so
  echo "Linked steamclient.so for Steam OSS"
else
  echo "WARN: $SERVER/linux64/steamclient.so missing — Steam UniqueId will stay INVALID" >&2
fi
# Client app id, not the dedicated-server tool (443030).
printf '440900\n' >"$BIN/steam_appid.txt"
printf '440900\n' >"$SERVER/steam_appid.txt"
export SteamAppId=440900
export SteamAppID=440900

# Name / map live in Engine.ini — the process never creates this file itself.
if [[ ! -f "$ENGINE_INI" ]]; then
  cat >"$ENGINE_INI" <<EOF
[OnlineSubsystemSteam]
bEnabled=true
SteamDevAppId=440900
bUseSteamNetworking=false
ServerName=${SERVER_NAME}

[/Script/Engine.Engine]
!NetDriverDefinitions=ClearArray
+NetDriverDefinitions=(DefName="GameNetDriver",DriverClassName="/Script/OnlineSubsystemUtils.IpNetDriver",DriverClassNameFallback="/Script/OnlineSubsystemUtils.IpNetDriver")

[/Script/Engine.GameEngine]
!NetDriverDefinitions=ClearArray
+NetDriverDefinitions=(DefName="GameNetDriver",DriverClassName="/Script/OnlineSubsystemUtils.IpNetDriver",DriverClassNameFallback="/Script/OnlineSubsystemUtils.IpNetDriver")

[/Script/Engine.GameSession]
MaxPlayers=${MAX_PLAYERS}

[/Script/EngineSettings.GameMapsSettings]
ServerDefaultMap=$(map_path)
EOF
fi
# Steam OSS is required for UniqueId; SteamSockets under Box64 fails to bind
# (SO_BROADCAST) and the process then reports Startup report with no listener.
if ! grep -q 'bUseSteamNetworking=false' "$ENGINE_INI"; then
  printf '\n[OnlineSubsystemSteam]\nbUseSteamNetworking=false\n' >>"$ENGINE_INI"
fi
if ! grep -q 'OnlineSubsystemUtils.IpNetDriver' "$ENGINE_INI"; then
  cat >>"$ENGINE_INI" <<'EOF'

[/Script/Engine.Engine]
!NetDriverDefinitions=ClearArray
+NetDriverDefinitions=(DefName="GameNetDriver",DriverClassName="/Script/OnlineSubsystemUtils.IpNetDriver",DriverClassNameFallback="/Script/OnlineSubsystemUtils.IpNetDriver")
EOF
fi

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
chmod +x "$BINARY" || true

echo "Starting Conan Exiles Enhanced: name=$SERVER_NAME map=$MAP port=$GAME_PORT query=$QUERY_PORT via $BOX64_BIN"
# BattlEye / PvE live in ServerSettings.ini. Password also on the line so the
# process cannot boot with an empty in-memory password after an ini rewrite.
# -nullrhi: dedicated, no GPU. SIGINT on stop — do not SIGKILL (SQLite world).
PW_ARGS=()
if [[ -n "${SERVER_PASSWORD:-}" ]]; then
  PW_ARGS+=(-ServerPassword="${SERVER_PASSWORD}")
fi
"$BOX64_BIN" "$BINARY" \
  -MULTIHOME=0.0.0.0 \
  -Port="${GAME_PORT}" \
  -QueryPort="${QUERY_PORT}" \
  -MaxPlayers="${MAX_PLAYERS}" \
  -nullrhi \
  -log \
  "${PW_ARGS[@]}" &
SERVER_PID=$!
wait "$SERVER_PID"
