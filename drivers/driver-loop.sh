#!/usr/bin/env bash
# ── driver-loop.sh — standing autonomous driver ─────────────────────────────
# The daily driver: digest state → act → re-arm. Silent unless it did something.
# Checks the federation board for an open tender in its lane, claims it,
# dispatches its agent (hermes chat), posts the outcome, closes with evidence.
#
# The agent-powered equivalent ships as a cron job (agents/cron/daily-driver.json).
set -euo pipefail

FED="${FEDERATION_URL:-http://localhost:8080}"
TOKEN="${FEDERATION_TOKEN:-}"
DRIVER_LANE="${DRIVER_LANE:-general}"
DRIVER_AGENT="${DRIVER_AGENT:-}"
[ -n "$DRIVER_AGENT" ] || DRIVER_AGENT="$(hermes profile list 2>/dev/null | grep -oE '◆[a-z][a-z0-9_-]*' | head -1 | tr -d '◆' || true)"
[ -n "$DRIVER_AGENT" ] || { echo "driver: no agent configured (DRIVER_AGENT) and none found"; exit 1; }

H() { if [ -n "$TOKEN" ]; then curl -s -H "X-Syndicate-Token: $TOKEN" "$@"; else curl -s "$@"; fi; }

# 1. digest state: open tenders in my lane
tenders="$(H "$FED/tenders?status=minted" 2>/dev/null || true)"
tid="$(echo "$tenders" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
lane = '$DRIVER_LANE'
for t in d.get('tenders', []):
    if t.get('lane') == lane and t.get('status') in ('minted', 'claimed'):
        print(t['id']); break
" 2>/dev/null || true)"

[ -n "$tid" ] || { echo "driver: no-op (no open $DRIVER_LANE tenders)"; exit 0; }

# 2. act: claim + work it
H -X POST "$FED/tenders/$tid/claim" -H 'Content-Type: application/json' -d "{\"agent\":\"$DRIVER_AGENT\"}" >/dev/null || true

prompt="You are the daily driver. Claimed tender $tid (lane $DRIVER_LANE). Work it and post your outcome to the board at $FED (POST /post, from=$DRIVER_AGENT, message=<outcome+evidence>). Keep it under 200 words."
out="$(hermes chat -p "$DRIVER_AGENT" -q "$prompt" 2>/dev/null || true)"

# 3. close with evidence + post outcome
H -X POST "$FED/tenders/$tid/close" -H 'Content-Type: application/json' -d "{\"agent\":\"$DRIVER_AGENT\",\"evidence\":\"driver-loop.sh: $DRIVER_AGENT dispatched for $tid\"}" >/dev/null || true

echo "driver: worked $tid via $DRIVER_AGENT"
