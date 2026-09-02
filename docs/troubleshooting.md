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

## Passworded server is invisible / join fails from Steam

Use the in-game dedicated browser, not Steam overlay Join.

## Enshrouded: `SERVER OVERLOADED` / hosting load pegged

CPU/Box64 tick budget, not RAM. Lower slots, spawners, weather. See [box64.md](box64.md) and the Enshrouded example config.

## V Rising: crash loop, `illegal instruction`

Stop the container so it cannot restart forever:

```bash
./serverctl.sh stop
```

Then the Box64 checklist in [box64.md](box64.md). After `./serverctl.sh update`, rewrite `vrising/server/steam_appid.txt` to `1604030` (the script does this).

## External SSD / Docker disk

If Steam files or `Docker.raw` live on an external APFS volume:

- Do not eject it while Docker or a server is running.
- Docker Desktop’s UI “change disk image location” can die with SIGKILL on a large sparse `Docker.raw`. Quit Docker, copy with `rsync -aS`, point the original path at the copy with a symlink (and/or `DataFolder` in Docker’s `settings-store.json`).

## Disk filled up by Steam or Docker

- Steam trees are not backed up and can be deleted, then `./serverctl.sh update`.
- Docker images you no longer use: `docker image ls` then `docker image rm`. Do this only when no server needs that image.
- Docker’s virtual disk size is independent of the physical SSD size. Raise it in Docker Desktop after the VM disk already lives on the big volume.

## World pause

Dedicated servers generally **do not pause** when nobody is online (unlike a listen/private host). The equivalent is `./serverctl.sh stop`.
