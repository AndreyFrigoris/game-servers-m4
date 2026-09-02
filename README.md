# Game Servers on Apple Silicon M4

Templates and runbooks for **self-hosted dedicated game servers** on a Mac mini M4 (and other Apple Silicon).

x86 Windows/Linux dedicated servers do not run natively on ARM. This repo is the pattern that does work:

```
Docker (linux/arm64) → Wine + Box64/FEX → game dedicated server
```

It is a real working tree, not a gist: clone it, copy the example configs, start with `./serverctl.sh`.

**What is in git:** compose files, scripts, guides, sanitized examples.  
**What is not:** your saves, passwords, `.env`, Steam game files, backup archives. See [`.gitignore`](.gitignore).

---

## Games

| Game | Status | Folder | Default ports | Disk (install + saves) | RAM (rough) |
|---|---|---|---|---|---|
| [Enshrouded](enshrouded-server/) | Working (CPU-bound under Box64) | `enshrouded-server/` | UDP `15636`, `15637` | ~8–12 GB | 4–6 GB |
| [V Rising](vrising-server/) | Working, Box64-sensitive | `vrising-server/` | UDP `27015`, `27016` | ~3–5 GB | 4–6 GB |
| ARK: Survival Evolved | Planned | — | (map-dependent; avoid `27015` if V Rising is up) | **30–60 GB** | 8–12 GB |
| The Forest | Planned | — | UDP `27015` — **conflicts with V Rising** | ~6–10 GB | 4–6 GB |
| Valheim | Planned | — | UDP `2456–2457` | ~3–5 GB | 2–4 GB |

---

## Requirements

- Apple Silicon Mac (M-series). This repo is tuned on **M4 / 16 GB**.
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) for Mac. The engine is not always running — check with `docker info`.
- Router port-forwards to the Mac’s **LAN** address (UDP).
- Disk: keep Steam binaries and Docker’s VM disk on a fast volume. An external NVMe SSD is fine; do not eject it while Docker is up.

**Do not** add `platform: linux/amd64` to compose. That turns on Docker’s own x86 emulation *on top of* Box64 and makes everything slower and less stable.

---

## Quick start

```bash
git clone https://github.com/AndreyFrigoris/game-servers-m4.git
cd game-servers-m4/<game>-server
cp examples/*  # see the game README for the exact destination
# edit passwords / server name in the copied files (never commit them)
./serverctl.sh start
./serverctl.sh logs
```

Common commands (every game):

```
./serverctl.sh start | stop | restart | status | logs
./serverctl.sh update              # pull image + SteamCMD validate
./serverctl.sh backup              # archive persistentdata only
./serverctl.sh health-check | doctor
./serverctl.sh launchd-install     # daily backup on macOS (default 06:00)
```

First install downloads the dedicated server through SteamCMD (`./serverctl.sh update`, or the image’s first start — V Rising skips SteamCMD on a normal `start`, so run `update` once). That can take several minutes and several gigabytes.

---

## Docs

| Topic | |
|---|---|
| [Architecture](docs/architecture.md) | Why Wine + Box64, directory layout, `serverctl.sh` |
| [Networking](docs/networking.md) | Port forwards, NAT hairpin, in-game vs Steam Join |
| [Box64](docs/box64.md) | Conservative dynarec profile, hosting-load / tick budget |
| [Backups](docs/backups.md) | What to archive, launchd, retention |
| [Troubleshooting](docs/troubleshooting.md) | Crash loops, overloaded servers, disk, Docker |

---

## Public vs private

Clone this onto the machine that will host. Your live world stays next to the templates and is gitignored:

| Path | Git |
|---|---|
| `compose.yml`, `serverctl.sh`, `scripts/`, `examples/` | public |
| `README.md`, `docs/` | public |
| Host operator notes (`AGENTS.md`), `.env`, `AGENTS.local.md` | **ignored** |
| `persistentdata/` (saves + live settings + passwords) | **ignored** |
| `backups/` | **ignored** |
| SteamCMD trees (`EnshroudedServer/`, `vrising/server/`) | **ignored** |

If you fork this, keep the same split. A leaked `persistentdata/settings/*.json` is a leaked server password.

---

## Hardware notes (M4 / 16 GB)

The bottleneck is almost always **CPU time inside Box64**, not RAM. Enshrouded’s “hosting load” bar is a tick-budget indicator; two players can trip `SERVER OVERLOADED` even with free memory. Turn down simulation (slots, spawners, weather) before you buy RAM.

ARK on 16 GB is realistic only as the **only** heavy server. Stop Enshrouded / V Rising before starting it. A fast SSD helps: ARK writes large save files in bursts.

---

## License

[MIT](LICENSE). Game binaries stay on Steam; this repo only ships glue and documentation.
