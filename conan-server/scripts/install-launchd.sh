#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="${LAUNCHD_LABEL:-com.gameservers.conan.backup}"
HOUR="${BACKUP_HOUR:-6}"
MINUTE="${BACKUP_MINUTE:-0}"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$HOME/Library/LaunchAgents" "$PROJECT_ROOT/backups/auto"

cat >"$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-lc</string>
    <string>cd "$PROJECT_ROOT" && ./serverctl.sh backup</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>$HOUR</integer>
    <key>Minute</key>
    <integer>$MINUTE</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>$PROJECT_ROOT/backups/auto/backup-launchd.log</string>
  <key>StandardErrorPath</key>
  <string>$PROJECT_ROOT/backups/auto/backup-launchd.err.log</string>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
launchctl enable "gui/$(id -u)/$LABEL"

echo "LaunchAgent installed: $PLIST_PATH"
echo "Schedule: ${HOUR}:$(printf '%02d' "$MINUTE") daily"
