#!/bin/bash
# Nightly backup of configs and databases.
# Keeps 14 days of backups, auto-prunes older ones.

set -euo pipefail

BASE_DIR="$HOME/Media"
BACKUP_ROOT="$BASE_DIR/backups"
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$BACKUP_ROOT/$TS"

mkdir -p "$OUT"/{configs,dbs,state}

# Backup compose and env
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cp "$SCRIPT_DIR/docker-compose.yml" "$OUT/" 2>/dev/null || true

# Backup config files
find "$BASE_DIR/config" -maxdepth 2 -type f \( -name 'config.xml' -o -name 'config.yml' -o -name 'settings.json' -o -name '*.conf' \) -print0 | while IFS= read -r -d '' f; do
    rel="${f#$BASE_DIR/config/}"
    mkdir -p "$OUT/configs/$(dirname "$rel")"
    cp "$f" "$OUT/configs/$rel"
done

# Backup databases
find "$BASE_DIR/config" -maxdepth 2 -type f -name '*.db' -print0 | while IFS= read -r -d '' f; do
    rel="${f#$BASE_DIR/config/}"
    mkdir -p "$OUT/dbs/$(dirname "$rel")"
    cp "$f" "$OUT/dbs/$rel"
done

# Snapshot container status
if ! docker compose -f "$SCRIPT_DIR/docker-compose.yml" ps > "$OUT/state/compose-ps.txt" 2>/dev/null; then
    echo "$(date '+%F %T') WARN: could not capture docker compose status snapshot" >> "$BASE_DIR/logs/backup.log"
fi

# Prune old backups (14 days)
find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime +14 -exec rm -rf {} +
