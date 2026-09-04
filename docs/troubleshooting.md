# Troubleshooting

## Docker daemon is not reachable

Docker Desktop on macOS is an app. `docker info` failing usually means it is quit.

```bash
open -a Docker
# wait until docker info works
```

## `platform: linux/amd64` made it worse

Remove it. The container should be ARM64; Box64 inside the image handles x86.

## Players on the LAN time out using the public IP

NAT hairpin. From home, use the Mac’s **LAN IP**. From outside, use the public IP. Details: [networking.md](networking.md).

**V Rising:** LAN/WAN `IP:port` may still time out. Play → Online → Direct Connect → Steam GameServer ID from `./serverctl.sh steam-id`. The ID changes every container start.

## Passworded server is invisible / join fails from Steam

Use the in-game dedicated browser, not Steam overlay Join.

## Enshrouded: `SERVER OVERLOADED` / hosting load pegged

CPU/Box64 tick budget, not RAM. Lower slots, spawners, weather. See [box64.md](box64.md) and the Enshrouded example config.

## V Rising: crash loop, `illegal instruction`

Almost always Unity Burst (`lib_burst_generated.dll`) under Box64, during engine init — **before** the world loads. The save is usually fine.

This repo’s `vrising-server/scripts/start-wrapper.sh` (compose entrypoint) hides that DLL on every start and **skips SteamCMD** on a normal boot. Stock image `start.sh` runs `app_update validate` every time, which restores the DLL and can also fail with SteamCMD `state is 0x6`.

```bash
./serverctl.sh stop          # restart: unless-stopped will otherwise loop
# do not restore lib_burst_generated.dll
./serverctl.sh start
```

Game file updates: `./serverctl.sh update` only. After update the wrapper hides Burst again and rewrites `steam_appid.txt` to `1604030`. Box64 checklist: [box64.md](box64.md).

## External SSD / Docker disk

If Steam files or `Docker.raw` live on an external APFS volume:

- Do not eject it while Docker or a server is running.
- Docker Desktop’s UI “change disk image location” can die with SIGKILL on a large sparse `Docker.raw`. Quit Docker, copy with `rsync -aS`, point the original path at the copy with a symlink (and/or `DataFolder` in Docker’s `settings-store.json`).

## Disk filled up by Steam or Docker

- Steam trees are not backed up and can be deleted, then `./serverctl.sh update`.
- Docker images you no longer use: `docker image ls` then `docker image rm`. Do this only when no server needs that image.
- Docker’s virtual disk size is independent of the physical SSD size. Raise it in Docker Desktop after the VM disk already lives on the big volume.

## ARK: version mismatch / “incompatible”

This repo’s dedicated server tracks Steam beta **`preaquatica`**. Clients on the live/Aquatica build will not stay connected. Steam → ARK → Properties → Betas → `preaquatica`.

## ARK: do not start next to Enshrouded / V Rising

`ark-server/serverctl.sh start` refuses if those containers are running. 16 GB is not enough for two heavy worlds. Stop the others first.

First boot of The Island under Box64 can sit for a long time before it listens. Watch `./serverctl.sh logs` for a startup-complete line before you assume it is dead.

## World pause

Dedicated servers generally **do not pause** when nobody is online (unlike a listen/private host). The equivalent is `./serverctl.sh stop`.
