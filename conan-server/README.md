# Conan Exiles Enhanced dedicated server (Apple Silicon)

Image: [`sonroyaalmerol/steamcmd-arm64`](https://hub.docker.com/r/sonroyaalmerol/steamcmd-arm64) (ARM64 + Box64, **no Wine** — Enhanced ships a Linux x86_64 dedicated server).  
Steam app: `443030` (free tool; anonymous SteamCMD). Game client is `440900`.  
Ports in this repo: **UDP `7787`** (game), **UDP `7788`** (peer = game+1), **UDP `27019`** (query). Defaults `7777`/`27015` collide with ARK and V Rising. Query is **not** `27018` — Steam’s Game Server API already grabs that port.

On 16 GB this is the **only** heavy server. Give Docker Desktop **12 GB** RAM before the first start. `./serverctl.sh start` refuses if Enshrouded, V Rising, or ARK is already up. After world load the process sits near **10–11 GB**.

## Start

```bash
cd conan-server
cp .env.example .env
mkdir -p persistentdata/Config/LinuxServer mods
cp examples/emulators.rc persistentdata/emulators.rc
cp examples/Engine.ini examples/ServerSettings.ini \
   persistentdata/Config/LinuxServer/
# set ServerName in Engine.ini
# set ServerPassword / AdminPassword in ServerSettings.ini
./serverctl.sh update         # first install: SteamCMD (daily start skips it)
./serverctl.sh logs
```

Ready in the log looks like `LogServerStats: Startup report` or `Engine is initialized`.  
Stop with `./serverctl.sh stop` (SIGINT). Do not force-kill: the world is SQLite (`game_0.db`).

SteamCMD **must** force the Linux depot (`@sSteamCmdForcePlatformType linux`). A plain `app_update 443030` can exit 0 with no Linux binary. This repo’s `update` checks that `ConanSandboxServer-Linux-Shipping` exists.

Daily `start` does **not** run SteamCMD.

## Clients

Everyone needs **Conan Exiles: Enhanced** (the current Steam default). The UE4 legacy client cannot join. There is no beta branch to flip.

Passworded servers: in-game **Direct Connect** `IP:7787` (the port is required — without it the client uses **7777**), or the in-game browser. Not Steam overlay Join. Launch the client **without BattlEye** if the server has `IsBattlEyeEnabled=False`.

The wrapper starts Steam OSS (`linux64/steamclient.so` + client AppId `440900`) so joins get a real UniqueId. `Engine.ini` keeps **IpNetDriver** and `bUseSteamNetworking=false`. Leaving SteamSockets in charge under Box64 fails the UDP bind (`NetDriverListenFailure`) while the process still looks “alive”.

## M4-tuned defaults

Example configs are a 2-player PvE private server:

- `MaxPlayers: 2`, `PVPEnabled=False`
- `IsBattlEyeEnabled=False` (both clients then skip BattlEye)
- `serverRegion=2` (Asia)
- harvest ×2.5, XP ×2, crafting ×2 (Funcom typo key: `ItemConvertionMultiplier`)
- purge off (`PurgeLevel=0`)
- Exiled Lands map

Edit `ServerSettings.ini` only while the container is **stopped**. Conan rewrites the file on a clean shutdown.

## Maps (already in the dedicated package)

One process = one map. Switch `MAP=` in `.env` (and the matching `ServerDefaultMap` in `Engine.ini` if you edit by hand).

| Map | `MAP=` | Engine.ini `ServerDefaultMap` | Notes |
|---|---|---|---|
| Exiled Lands | `ExiledLands` | `/Game/Maps/ConanSandbox/ConanSandbox` | Default. Start here. |
| Isle of Siptah | `Siptah` | `/Game/DLC_EXT/DLC_Siptah/Maps/DLC_Isle_of_Siptah` | In the DS package. More RAM. Clients need the DLC. |

Do not run two maps at once on 16 GB.

## Mods (later)

Vanilla first. When you add Workshop mods:

1. Subscribe / download the `.pak` files.
2. Put one absolute path per line in `mods/modlist.txt` (bind-mounted to `ConanSandbox/Mods/`).
3. Clients need the same mods. A mismatch refuses the join.

Vanilla join is confirmed on M4 / 16 GB. Mods still raise RAM and Box64 risk — add them only after a clean session.

## How players join

Like Enshrouded (UDP), not V Rising’s Steam GameServer ID.

- Same house → Mac **LAN IP**:`7787`
- From the internet → **public IP**:`7787`
- Steam / in-game browser uses query **`IP:27019`**

NAT hairpin: from home Wi-Fi the public IP often times out. See [docs/networking.md](../docs/networking.md).

Dedicated worlds **do not pause** when empty. Stopping the container is the equivalent of “pause”.

## Day-to-day

```
./serverctl.sh stop | restart | status | logs
./serverctl.sh update
./serverctl.sh backup
./serverctl.sh health-check | doctor
./serverctl.sh launchd-install
```

## Files

| Path | Git | Role |
|---|---|---|
| `compose.yml` | yes | ARM64 image, ports, bind mounts |
| `.env.example` | yes | name, map, ports |
| `.env` | no | your name / timezone |
| `scripts/start-wrapper.sh` | yes | Box64 launch; SteamCMD off on daily start |
| `examples/Engine.ini` | yes | server name + map (empty of secrets) |
| `examples/ServerSettings.ini` | yes | 2-player PvE, empty passwords, BattlEye off |
| `examples/emulators.rc` | yes | Box64 profile |
| `persistentdata/` | no | `Config/LinuxServer/`, `game_0.db`, logs |
| `mods/` | no | `modlist.txt` + paks |
| `server/` | no | Steam files |
| `backups/auto/` | no | tar.gz of persistentdata only |

## Network

Forward **UDP** `7787`, `7788`, and `27019` to the Mac LAN IP. Do not reuse `7777` (ARK) or `27015` (V Rising).
