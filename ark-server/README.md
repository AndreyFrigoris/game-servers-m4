# ARK: Survival Evolved dedicated server (Apple Silicon)

Image: [`sonroyaalmerol/steamcmd-arm64`](https://hub.docker.com/r/sonroyaalmerol/steamcmd-arm64) (ARM64 + Box64, **no Wine** — the dedicated server is Linux x86_64).  
Steam app: `376030`. Default branch in this repo: **`preaquatica`** (mod-friendly; clients must match).  
Ports: **UDP `7777`** (game), **UDP `7778`** (peer = game+1), **UDP `27017`** (Steam query). Query is **not** `27015` so it does not collide with V Rising.

On 16 GB this is the **only** heavy server. `./serverctl.sh start` refuses to run if Enshrouded or V Rising is already up.

## Start

```bash
cd ark-server
cp .env.example .env          # session name, timezone, map — not committed
mkdir -p persistentdata/Config/LinuxServer
cp examples/emulators.rc persistentdata/emulators.rc
cp examples/GameUserSettings.ini examples/Game.ini \
   persistentdata/Config/LinuxServer/
# set SessionName / ServerPassword / ServerAdminPassword in GameUserSettings.ini
./serverctl.sh update         # first install: SteamCMD (daily start skips it)
./serverctl.sh logs
```

First `update` downloads ~18 GB. SteamCMD on ARM self-updates once into `ark-server/.steamcmd/` (gitignored); the next run is the real `app_update`. The Island empty world is roughly 4–5 GB RAM on x86; add Box64 overhead. Genesis 2 is too heavy for 16 GB — do not start with `MAP=Gen2`.

Daily `start` does **not** run SteamCMD. `./serverctl.sh update` is the path that validates game files (`376030` + `-beta preaquatica` unless you clear `ARK_BETA`).

## Clients (preaquatica)

Everyone who joins must use the same branch as the server:

Steam → ARK: Survival Evolved → Properties → Betas → `preaquatica` (ASE: Pre-Aquatica).

Live/Aquatica clients will fail to join with a version mismatch.

## M4-tuned defaults (do not “fix” these back to official 1x)

The example configs are a 2-player PvE unofficial:

- `MaxPlayers: 2`, `ServerPVE=True`
- harvest ×2.5, tame ×3, XP ×2.5
- slightly fewer wild dinos (`DinoCountMultiplier=0.8`) for the Box64 tick
- baby/hatch/crop in `Game.ini` in the same 2–3× band
- `-NoBattlEye` (private server; both clients should not require BE)

Raise simulation (wild dino count, extra maps, a pile of mods) only after a vanilla join works.

## Maps and DLC

The dedicated server package **already contains official maps**. You do not install Scorched Earth / Ragnarok / etc. as extra Steam apps on the host. Switch maps by changing `MAP=` in `.env` (and forwarding the same ports). One process = one map. A cluster of several maps is several processes — not realistic on 16 GB.

Players still need the matching **client** DLC to join a paid map. Free maps: The Island, The Center, Ragnarok, Valguero, Crystal Isles, Lost Island, Fjordur.

| Map | `MAP=` value |
|---|---|
| The Island | `TheIsland` |
| The Center | `TheCenter` |
| Ragnarok | `Ragnarok` |
| Scorched Earth | `ScorchedEarth_P` |
| Aberration | `Aberration_P` |
| Extinction | `Extinction` |
| Valguero | `Valguero_P` |
| Genesis 1 | `Genesis` |
| Crystal Isles | `CrystalIsles` |
| Genesis 2 | `Gen2` (too much RAM here) |
| Lost Island | `LostIsland` |
| Fjordur | `Fjordur` |

Workshop maps are mods: install them like any other Workshop ID, then set `MAP=` to the map’s internal name.

## Mods (later)

Vanilla first. When you add Workshop mods:

1. Put IDs in `GameUserSettings.ini` as `ActiveMods=123,456`.
2. Add `-automanagedmods` to the wrapper launch line (or ask the operator docs in this repo to grow that flag).
3. Clients subscribe to the same mods.
4. Stay on `preaquatica` until you know the live branch is fine for those mods.

## How players join

ARK uses **UDP** like Enshrouded (not V Rising’s Steam GameServer ID). Passworded servers: use the **in-game** unofficial / dedicated browser, not Steam overlay Join.

- Same house / same LAN → Mac **LAN IP**:`7777`
- From the internet → **public IP**:`7777`
- Steam server browser (if it lists you) uses the **query** port: `IP:27017`

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
| `.env.example` | yes | session name, map, ports, `ARK_BETA` |
| `.env` | no | your name / timezone |
| `scripts/start-wrapper.sh` | yes | Box64 launch; SteamCMD off on daily start |
| `examples/GameUserSettings.ini` | yes | 2-player PvE template, empty passwords |
| `examples/Game.ini` | yes | baby / crop multipliers |
| `examples/emulators.rc` | yes | Box64 profile |
| `persistentdata/` | no | `Config/LinuxServer/`, `SavedArks/`, logs |
| `server/` | no | Steam files |
| `backups/auto/` | no | tar.gz of persistentdata only |

## Network

Forward **UDP** `7777`, `7778`, and `27017` to the Mac LAN IP. Do not reuse V Rising’s `27015`/`27016`. From the same Wi-Fi, connect via LAN IP (NAT hairpin). See [docs/networking.md](../docs/networking.md).
