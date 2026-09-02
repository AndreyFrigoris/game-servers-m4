# V Rising dedicated server (Apple Silicon)

Image: [`tsxcloud/vrising-ntsync:latest`](https://hub.docker.com/r/tsxcloud/vrising-ntsync) (ARM64, Wine, Box64, NTsync).  
Steam download app: `1829350`. Runtime app id that must stay in `steam_appid.txt`: **`1604030`**.  
Ports: **UDP `27015`** (game), **UDP `27016`** (query). TCP `25575` only if you enable RCON.

## Start

```bash
cd vrising-server
cp .env.example .env          # server name, timezone — not committed
mkdir -p vrising/persistentdata/Settings
cp examples/emulators.rc examples/ServerHostSettings.json \
   vrising/persistentdata/Settings/
# set Name / Password in ServerHostSettings.json
./serverctl.sh update         # first install: SteamCMD (daily start skips it)
./serverctl.sh logs
```

Daily `start` does **not** run SteamCMD (set `RUN_STEAMCMD=1` only if you mean it). `./serverctl.sh update` is the path that validates game files, then the wrapper hides Burst again and **rewrites** `vrising/server/steam_appid.txt` to `1604030`.

## Box64 / Unity Burst

Copy `examples/emulators.rc` into `vrising/persistentdata/Settings/emulators.rc` (the image loads it at start). Use the conservative profile; do not turn on bleeding-edge dynarec on a world you care about. Details: [docs/box64.md](../docs/box64.md).

Unity Burst (`lib_burst_generated.dll`) triggers a Box64 `illegal instruction` crash on Apple Silicon during engine init — **before** the world loads. `scripts/start-wrapper.sh` hides that DLL after every SteamCMD validate (validate would restore it). Simulation falls back to non-Burst code; the world still loads.

If you ever restore the DLL by hand, the crash loop comes back.

Recommended host settings on M4 (already in the example JSON):

- `MaxConnectedUsers: 2`
- `ServerFps: 20`
- autosave `120` seconds × `20` copies

## How players join

V Rising uses **Steam sockets**, not a plain UDP connect like Enshrouded. Steam overlay Join does not work on a passworded dedicated server.

1. **In-game list (best from the internet):** Play → Online Play → Find Servers → show passworded servers → search the name.
2. **Direct Connect:** Play → Online → Direct Connect. The field accepts `IP:port` **or** the Steam GameServer ID.
3. **Same LAN as the host:** `IP:port` often times out (Steam publishes the WAN address; NAT hairpin). Paste the GameServer ID instead. Print it with `./serverctl.sh steam-id` / `./serverctl.sh status`. It **changes every container start**, not every player join.

UDP `27015`/`27016` still need to be forwarded for listing and for clients that do connect by IP.

## Crash loop (`illegal instruction`)

The stock image crashes in Unity Burst on M4. `compose.yml` already runs `scripts/start-wrapper.sh`, which disables `lib_burst_generated.dll` after SteamCMD. If you bypass the wrapper, the loop comes back.

```bash
./serverctl.sh stop          # compose restart policy will otherwise loop
# confirm emulators.rc is the conservative profile
rm -rf vrising/persistentdata/Saves/*/.TEMP
./serverctl.sh start
```

Dedicated worlds **do not pause** when empty. Stopping the container is the equivalent of “pause”.

## Day-to-day

```
./serverctl.sh stop | restart | status | logs
./serverctl.sh steam-id        # Steam GameServer ID for Direct Connect
./serverctl.sh update
./serverctl.sh backup
./serverctl.sh health-check | doctor
./serverctl.sh launchd-install
```

## Files

| Path | Git | Role |
|---|---|---|
| `compose.yml` | yes | binds `vrising/server` + `vrising/persistentdata` |
| `.env.example` | yes | `TZ`, `SERVERNAME` |
| `.env` | no | your name / timezone |
| `examples/emulators.rc` | yes | Box64 profile |
| `examples/ServerHostSettings.json` | yes | M4 template, empty password |
| `vrising/persistentdata/` | no | settings + `Saves/` |
| `vrising/server/` | no | Steam files |
| `backups/auto/` | no | tar.gz of persistentdata |

## Network

Forward UDP `27015` and `27016` to the Mac LAN IP. From the internet, join via the in-game list (or Direct Connect). From the same Wi-Fi, prefer the Steam GameServer ID, not `IP:port`. See [docs/networking.md](../docs/networking.md).
