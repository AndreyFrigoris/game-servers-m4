# Architecture

## The problem

Most dedicated servers for survival games are **x86_64 Linux or Windows**. Apple Silicon is **ARM64**. There is no supported native Enshrouded/V Rising/Valheim dedicated server for macOS ARM.

## The stack

```
macOS (Apple Silicon)
  └─ Docker Desktop (linux/arm64 VM)
       └─ container image (tsxcloud/*-arm, ntsync, …)
            ├─ SteamCMD  (downloads the x86 dedicated server)
            ├─ Wine      (Windows .exe servers)
            └─ Box64/FEX (translates x86 → ARM)
                 └─ game server process
```

Two rules that follow from this:

1. **Keep the container ARM64.** Do not set `platform: linux/amd64`. That asks Docker to emulate x86, and then Box64 emulates x86 again. Double emulation is slow and crashy.
2. **Treat Box64 as the CPU.** Tick time, “hosting load”, and `illegal instruction` crashes come from dynarec, not from missing RAM.

Wine is only needed for **Windows** dedicated servers (Enshrouded, The Forest, V Rising). A Linux x86_64 server (Valheim, ARK) still needs Box64, but not Wine.

## Repository layout

The git root is a host directory that you actually run from (`GameServers/` on this project). Each game is a sibling folder with the same interface:

```
<game>-server/
  compose.yml
  serverctl.sh
  scripts/backup.sh
  scripts/install-launchd.sh
  examples/                 # sanitized; copy into persistentdata
  persistentdata/           # gitignored — live world
  backups/auto/             # gitignored
  <steam install dir>/      # gitignored
```

`serverctl.sh` is the only command you should need day-to-day. It wraps `docker compose` and SteamCMD `app_update`.

## Data that matters

| Kind | Example | Backup? | Git? |
|---|---|---|---|
| Glue | `compose.yml`, `serverctl.sh` | no (it’s in git) | yes |
| Live settings + saves | `persistentdata/` | **yes** | no |
| Steam binaries | `EnshroudedServer/`, `vrising/server/`, `ark-server/server/` | no — re-download | no |

If a container image updates SteamCMD files on every start, that can fight you: V Rising’s stock entrypoint re-downloads Burst SIMD that Box64 cannot run. Override with a wrapper (`start-wrapper.sh`) and keep SteamCMD on `./serverctl.sh update`, not on every boot. Saves must never live only inside the image.

## Images used here

These are community ARM64 images, not official publisher images:

- Enshrouded: [`tsxcloud/enshrouded-arm`](https://hub.docker.com/r/tsxcloud/enshrouded-arm)
- V Rising: [`tsxcloud/vrising-ntsync`](https://hub.docker.com/r/tsxcloud/vrising-ntsync) (Wine + Box64 + NTsync). Compose overrides the entrypoint with `scripts/start-wrapper.sh` so Unity Burst is disabled and SteamCMD does not run on every boot.
- ARK: Survival Evolved: [`sonroyaalmerol/steamcmd-arm64`](https://hub.docker.com/r/sonroyaalmerol/steamcmd-arm64) (Box64, no Wine — Linux dedicated server). Compose entrypoint is `scripts/start-wrapper.sh`; SteamCMD is `./serverctl.sh update` only (`-beta preaquatica` by default).

Pinning a digest is safer for a family server that already works. `latest` is convenient and is what this repo’s compose files use.
