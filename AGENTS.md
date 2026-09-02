# GameServers M4 — Agent Context

Public context for agents working on this repo. Read this first.
If `AGENTS.local.md` exists, read it second — that file is **local-only** (gitignored) and may contain host IPs, passwords, and SteamIDs.

This repository is a working tree **and** a public template: ship guides + compose + scripts, never live saves or personal server settings.

---

## 1. Why this stack exists

Game dedicated servers here are **x86 Windows/Linux**. Apple Silicon is ARM64:

```
Docker (bridge) → image with Wine (Windows) + Box64/FEX (x86→ARM)
```

- **Box64/FEX** is the main source of instability and tick-time issues.
- **Never** set `platform: linux/amd64` in compose. That adds Docker’s own emulation on top of Box64.
- Conservative Box64 profile (stability over raw FPS), proven on V Rising:

```
BOX64_DYNAREC_STRONGMEM=1
BOX64_DYNAREC_BIGBLOCK=0
BOX64_DYNAREC_SAFEFLAGS=1
BOX64_DYNAREC_FASTNAN=0
BOX64_DYNAREC_FASTROUND=0
BOX64_DYNAREC_X87DOUBLE=1
BOX64_DYNAREC_BLEEDING_EDGE=0
```

Docker Desktop on macOS may be stopped — run `docker info` before compose operations.

---

## 2. Layout of each game

```
<game>-server/
  README.md              # how to run this game on M4
  compose.yml
  serverctl.sh           # start|stop|restart|status|logs|update|backup|doctor
  scripts/backup.sh
  scripts/install-launchd.sh
  examples/              # sanitized configs to copy into persistentdata
  backups/auto/          # gitignored
  <steam files>/         # gitignored (SteamCMD)
  <persistentdata>/      # gitignored (saves + live settings)
```

Rules:

- Backup **only** persistentdata/saves, never Steam binaries.
- Default backup retention: 14 days (`BACKUP_RETENTION_DAYS`).
- `update` = stop → pull image → SteamCMD `app_update <id> validate` → start.

---

## 3. Public vs private (hard rule)

**Commit / push:**

- Guides (`README.md`, `docs/`, per-game `README.md`)
- `compose.yml`, `serverctl.sh`, `run.sh`, `scripts/`
- `examples/` and `.env.example` (placeholders only)
- CI, LICENSE

**Never commit (see `.gitignore`):**

- `AGENTS.local.md`
- `.env`
- `persistentdata/` (saves, passwords, live JSON)
- `backups/`
- SteamCMD game trees (`EnshroudedServer/`, `vrising/server/`)
- Real IPs, passwords, SteamIDs, personal home paths

Before every commit, scan the staged diff for secrets.

---

## 4. serverctl.sh

```
./serverctl.sh start | stop | restart | status | logs
./serverctl.sh update
./serverctl.sh backup | backup-prune
./serverctl.sh health-check | doctor
./serverctl.sh launchd-install
```

Enshrouded also has `cron-install`.

---

## 5. Games in this repo

| Game | Folder | Image | Steam DS app | Notes |
|---|---|---|---|---|
| Enshrouded | `enshrouded-server/` | `tsxcloud/enshrouded-arm:latest` | `2278520` | ARM image, still Wine+Box64 inside. Heavy simulation. |
| V Rising | `vrising-server/` | `tsxcloud/vrising-ntsync:latest` | download `1829350`, runtime `1604030` | After update, force `steam_appid.txt` to `1604030`. |

Planned (same pattern): Valheim `896660`, The Forest `556450` (rebind ports — conflicts with V Rising `27015`), ARK SE `376030` (RAM/CPU heavy).

---

## 6. Networking (generic)

- Forward **UDP** game + query ports to the Mac’s LAN IP.
- NAT hairpin: from the same LAN, connect via **LAN IP**, not the public WAN IP.
- Passworded servers often need the **in-game server browser**, not Steam overlay Join.
- Dedicated worlds usually **cannot pause**; stop the container instead.

---

## 7. Granite facts

- Do not use `platform: linux/amd64`.
- Backup persistentdata only.
- V Rising `update` overwrites `steam_appid.txt` → force `1604030`.
- Port conflicts between games are easy (V Rising and The Forest both like 27015).
- If the data volume is an external SSD, do not eject it while Docker or servers run.
- Docker Desktop UI “move disk image” can SIGKILL on a large sparse `Docker.raw`; move it with `rsync -aS` while Docker is stopped.
