#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAVE_DIR="$PROJECT_ROOT/persistentdata/savegame"
SETTINGS_DIR="$PROJECT_ROOT/persistentdata/settings"
BACKUP_ROOT="$PROJECT_ROOT/backups/auto"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
BACKUP_CREATE_ARCHIVE="${BACKUP_CREATE_ARCHIVE:-1}"

mkdir -p "$BACKUP_ROOT"

prune_old_backups() {
  # shellcheck disable=SC2016
  find "$BACKUP_ROOT" -type f -name "enshrouded-backup-*.tar.gz" -mtime "+$BACKUP_RETENTION_DAYS" -delete
}

create_backup() {
  local now archive
  now="$(date +"%Y-%m-%dT%H-%M-%S")"
  archive="$BACKUP_ROOT/enshrouded-backup-$now.tar.gz"

  if [[ ! -d "$SAVE_DIR" ]]; then
    echo "Save directory not found: $SAVE_DIR" >&2
    exit 1
  fi

  tar -czf "$archive" \
    -C "$PROJECT_ROOT" \
    persistentdata/savegame \
    persistentdata/settings

  echo "Backup created: $archive"
}

if [[ "$BACKUP_CREATE_ARCHIVE" == "1" ]]; then
  create_backup
fi

prune_old_backups
echo "Old backups pruned (>${BACKUP_RETENTION_DAYS} days)"
