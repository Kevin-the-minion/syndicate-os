#!/usr/bin/env bash
# ── watchdog.sh — silent service monitor ────────────────────────────────────
# The fleet's watchdog discipline: check, and ONLY output when the state
# CHANGED. No change = silence = no noise, no alert fatigue.
#
# Usage: WATCH_URLS="http://localhost:8080/health http://localhost:8765/health" \
#          ./watchdog.sh
# State file keeps the previous snapshot; first run always reports (baseline).
set -euo pipefail

WATCH_URLS="${WATCH_URLS:-http://localhost:8080/health http://localhost:8765/health http://localhost:7878/health}"
STATE_FILE="${WATCHDOG_STATE_FILE:-/tmp/syndicate-watchdog.state}"

snapshot=""
for url in $WATCH_URLS; do
  code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$url" 2>/dev/null || echo 000)"
  [ -n "$snapshot" ] && snapshot+=$'\n'
  snapshot+="${url}=${code}"
done

prev=""
[ -f "$STATE_FILE" ] && prev="$(cat "$STATE_FILE" 2>/dev/null || true)"

if [ "$snapshot" == "$prev" ]; then
  exit 0            # silent — no change
fi

printf '%s\n' "$snapshot" > "$STATE_FILE"

if [ -z "$prev" ]; then
  echo "watchdog: baseline"
  echo "$snapshot"
  exit 0
fi

echo "⚠ WATCHDOG: service state changed"
diff <(printf '%s' "$prev") <(printf '%s' "$snapshot") || true
