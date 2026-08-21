#!/usr/bin/env bash
# ── backup.sh — snapshot the federation state ───────────────────────────────
# Tars the data that matters: .env (credentials), federation/semantica/
# memory-search data dirs (dev runs), and prints the docker-volume command
# for containerized runs. Keeps BACKUP_ROTATION (default 7) snapshots.
set -euo pipefail
cd "$(dirname "$0")/.."

BACKUP_DIR="${BACKUP_DIR:-./backups}"
BACKUP_ROTATION="${BACKUP_ROTATION:-7}"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

targets=()
[ -f .env ] && targets+=(.env)
for d in federation/data semantica/data memory-search/data; do
  [ -d "$d" ] && targets+=("$d")
done

OUT="$BACKUP_DIR/syndicate-$STAMP.tar.gz"
if [ "${#targets[@]}" -gt 0 ]; then
  tar -czf "$OUT" "${targets[@]}"
  echo "backup: $OUT ($(du -h "$OUT" | cut -f1))"
else
  echo "no local data dirs found — containerized run. Snapshot the volumes with:"
  echo "  docker run --rm -v syndicate_federation-data:/data -v \$PWD/$BACKUP_DIR:/backup \\
        alpine tar -czf /backup/syndicate-$STAMP.tar.gz -C /data ."
fi

# rotate
ls -1t "$BACKUP_DIR"/syndicate-*.tar.gz 2>/dev/null | tail -n +$((BACKUP_ROTATION + 1)) | while read -r old; do
  rm -f "$old" && echo "rotated out: $old"
done
