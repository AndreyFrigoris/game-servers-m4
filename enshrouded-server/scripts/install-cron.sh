#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRON_SCHEDULE="${CRON_SCHEDULE:-0 6 * * *}"
CRON_LINE="$CRON_SCHEDULE cd \"$PROJECT_ROOT\" && BACKUP_RETENTION_DAYS=\${BACKUP_RETENTION_DAYS:-14} ./serverctl.sh backup >> \"$PROJECT_ROOT/backups/auto/backup-cron.log\" 2>&1"

mkdir -p "$PROJECT_ROOT/backups/auto"

current_cron="$(crontab -l 2>/dev/null || true)"

if printf '%s\n' "$current_cron" | rg -F "$PROJECT_ROOT/serverctl.sh backup" >/dev/null; then
  echo "Cron backup entry already exists."
  exit 0
fi

{
  printf '%s\n' "$current_cron"
  printf '%s\n' "$CRON_LINE"
} | crontab -

echo "Installed cron backup job:"
echo "$CRON_LINE"
