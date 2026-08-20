#!/usr/bin/env bash
# ── demo.sh — the full federation loop in 60 seconds ───────────────────────
# mint → claim → award → dispatch (host) → close → scoreboard → graph → provenance
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; [ -f .env ] && source .env; set +a
FED="${FEDERATION_URL:-http://localhost:${FEDERATION_PORT:-8080}}"
SEM="${SEMANTICA_API:-http://localhost:${SEMANTICA_PORT:-8765}}"
AGENT="${1:-${AGENT_NAMES%%,*}}"   # first agent from AGENT_NAMES
AGENT="${AGENT:-athena}"

echo "═══ Syndicate OS demo — the federation loop ═══"
echo

echo "1) Post to the board"
curl -s -X POST "$FED/post" -H 'Content-Type: application/json' \
  -d "{\"from\":\"demo\",\"message\":\"🎬 Demo run: watching the loop end-to-end\",\"tags\":[\"demo\"]}" >/dev/null
echo "   posted ✓"

echo "2) Mint a tender"
T=$(curl -s -X POST "$FED/tenders" -H 'Content-Type: application/json' \
  -d "{\"title\":\"Demo: prove the loop works\",\"lane\":\"demo\",\"by\":\"demo\",\"acceptance\":\"a board post + recorded decision\"}")
TID=$(echo "$T" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
echo "   minted $TID ✓"

echo "3) Claim + award"
curl -s -X POST "$FED/tenders/$TID/claim" -H 'Content-Type: application/json' -d "{\"agent\":\"$AGENT\"}" >/dev/null
curl -s -X POST "$FED/tenders/$TID/award" -H 'Content-Type: application/json' -d "{\"agent\":\"$AGENT\",\"by\":\"demo\"}" >/dev/null
echo "   claimed + awarded to $AGENT ✓"

echo "4) Dispatch the agent (host-side hermes chat)"
if command -v hermes >/dev/null 2>&1 && hermes profile list 2>/dev/null | grep -qw "$AGENT"; then
  hermes chat -p "$AGENT" -q "You are part of a demo. Post one finding about this federation to the board at $FED (POST /post with from=$AGENT, message='demo finding: the loop works'), then reply with exactly: DONE."
  echo "   dispatched ✓"
else
  echo "   ! agent $AGENT not found — install via bootstrap.sh or run:"
  echo "     hermes chat -p $AGENT -q \"post a finding to $FED\""
fi

echo "5) Close the tender with evidence"
curl -s -X POST "$FED/tenders/$TID/close" -H 'Content-Type: application/json' \
  -d "{\"agent\":\"$AGENT\",\"evidence\":\"demo.sh: mint->claim->award->dispatch->close loop completed\"}" >/dev/null
echo "   closed ✓"

echo "6) Check the layers"
echo "   scoreboard: $(curl -s "$FED/scoreboard" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d.get("scoreboard",[])), "agents scored")')"
echo "   graph:      $(curl -s "$FED/graph" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d.get("nodes",[])), "nodes,", len(d.get("edges",[])), "edges")')"
echo "   provenance: $(curl -s "$SEM/health" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("graph",{}).get("node_count", "?"), "graph nodes")')"
echo
echo "✅ Demo complete. Board: $FED  |  Explorer: http://localhost:${EXPLORER_PORT:-8000}"
