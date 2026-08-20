#!/usr/bin/env bash
# ── install-drivers.sh — scripted drivers via crontab (zero-LLM variant) ────
# For the agent-powered variant, the cron jobs ship with the profile
# distribution (agents/cron/*.json) — nothing to do here.
set -euo pipefail
cd "$(dirname "$0")/.."

CRON_TAB="$(crontab -l 2>/dev/null || true)"
LINE1="0 9 * * * $(pwd)/drivers/driver-loop.sh >> $(pwd)/drivers/driver.log 2>&1"
LINE2="0 2 * * * $(pwd)/drivers/librarian.sh >> $(pwd)/drivers/librarian.log 2>&1"

for L in "$LINE1" "$LINE2"; do
  if ! grep -qF "$L" <<<"$CRON_TAB"; then
    CRON_TAB="$(printf '%s\n%s\n' "$CRON_TAB" "$L")"
    echo "added: $L"
  else
    echo "already present: ${L%% *} ${L%% *}"
  fi
done
printf '%s\n' "$CRON_TAB" | crontab -
echo "drivers installed: driver-loop 09:00 daily · librarian 02:00 daily"
