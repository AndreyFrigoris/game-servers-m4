# Backups

Backup **saves and live settings** only. SteamCMD can download the dedicated server again; it cannot download your world.

## What `./serverctl.sh backup` does

- Enshrouded: `persistentdata/savegame` + `persistentdata/settings` → `backups/auto/enshrouded-backup-<timestamp>.tar.gz`
- V Rising: `vrising/persistentdata` → `backups/auto/vrising-backup-<timestamp>.tar.gz`

Retention defaults to **14 days** (`BACKUP_RETENTION_DAYS`). `./serverctl.sh backup-prune` only deletes old archives.

`backups/` is gitignored. Keep a copy off the box (another disk, NAS, or a tarball you actually download) if the world matters.

## macOS: launchd (recommended)

```bash
./serverctl.sh launchd-install
```

Default: 06:00 local time. Override hour/minute:

```bash
BACKUP_HOUR=3 BACKUP_MINUTE=30 ./serverctl.sh launchd-install
```

Logs land in `backups/auto/backup-launchd.log`. The LaunchAgent lives in `~/Library/LaunchAgents/`.

If you already installed an agent under an old label, reinstalling with a new default label will create a **second** job. Set `LAUNCHD_LABEL` to the existing label to refresh in place.

## Linux / cron (Enshrouded)

```bash
./serverctl.sh cron-install
```

## Restore

1. `./serverctl.sh stop`
2. Extract the archive back over `persistentdata/` (Enshrouded) or `vrising/persistentdata/` (V Rising).
3. `./serverctl.sh start`

Do not restore Steam binaries from a backup unless you have a reason — `./serverctl.sh update` is cleaner.
