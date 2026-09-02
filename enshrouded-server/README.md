# Enshrouded dedicated server (Apple Silicon)

Image: [`tsxcloud/enshrouded-arm:latest`](https://hub.docker.com/r/tsxcloud/enshrouded-arm) (ARM64 container, Wine + Box64 inside).  
Steam app: `2278520`. Ports: **UDP `15636`** (game), **UDP `15637`** (query).

## Start

```bash
cd enshrouded-server
./serverctl.sh start
./serverctl.sh logs
```

First launch downloads the dedicated server into `EnshroudedServer/` (gitignored). If `persistentdata/settings/enshrouded_server.json` is missing, `run.sh` copies the image’s example. Prefer copying **this repo’s** M4-tuned example before the first start:

```bash
mkdir -p persistentdata/settings
cp examples/enshrouded_server.json persistentdata/settings/enshrouded_server.json
# set name + group passwords, then start
```

Do not commit that JSON. It contains passwords.

## M4-tuned simulation (do not “fix” these back to defaults)

The hosting-load bar is a **tick budget**, not RAM. Under Box64, even one player is expensive. These values are what made a 2-slot server playable on M4:

- `slotCount: 2`
- `randomSpawnerAmount: "Few"`
- `aggroPoolAmount: "Few"`
- `weatherFrequency: "Rare"`
- `enableDurability: false`
- `enableGliderTurbulences: false`

`SERVER OVERLOADED` with two players is expected if you raise spawners/slots. More RAM will not help.

## Day-to-day

```
./serverctl.sh stop | restart | status | logs
./serverctl.sh update          # pull image + steamcmd app_update 2278520 validate
./serverctl.sh backup
./serverctl.sh health-check | doctor
./serverctl.sh launchd-install # macOS daily backup 06:00
./serverctl.sh cron-install    # optional cron instead of launchd
```

## Files

| Path | Git | Role |
|---|---|---|
| `compose.yml` | yes | image, ports, bind mounts |
| `run.sh` | yes | `wine enshrouded_server.exe --config …` |
| `serverctl.sh` | yes | operator CLI |
| `examples/enshrouded_server.json` | yes | M4 template, placeholder passwords |
| `persistentdata/settings/enshrouded_server.json` | no | live config |
| `persistentdata/savegame/` | no | world |
| `EnshroudedServer/` | no | Steam files |
| `backups/auto/` | no | tar.gz of savegame + settings |

## Network

Forward UDP `15636` and `15637` to the Mac LAN IP. From the same Wi-Fi, connect via LAN IP (NAT hairpin). See [docs/networking.md](../docs/networking.md).
