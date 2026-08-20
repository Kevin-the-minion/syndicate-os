#!/usr/bin/env bash
# ── Syndicate OS verify — smoke test everything ────────────────────────────
set -uo pipefail
cd "$(dirname "$0")"
set -a; [ -f .env ] && source .env; set +a

FED="${FEDERATION_URL:-http://localhost:${FEDERATION_PORT:-8080}}"
SEM="${SEMANTICA_API:-http://localhost:${SEMANTICA_PORT:-8765}}"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
bad(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "== Hermes =="
if command -v hermes >/dev/null 2>&1 && hermes --version >/dev/null 2>&1; then ok "hermes CLI"; else bad "hermes CLI"; fi
for name in $(echo "${AGENT_NAMES:-athena,nyx,iris}" | tr ',' ' '); do
  if hermes profile list 2>/dev/null | grep -qw "$name"; then ok "profile $name"; else bad "profile $name"; fi
done

echo "== Services =="
curl -sf "$SEM/health" >/dev/null 2>&1 && ok "semantica :${SEMANTICA_PORT:-8765}" || bad "semantica"
curl -sf "$FED/health" >/dev/null 2>&1 && ok "federation :${FEDERATION_PORT:-8080}" || bad "federation"
(exec 3<>/dev/tcp/localhost/"${MONGO_PORT:-27017}") 2>/dev/null && ok "mongodb :${MONGO_PORT:-27017}" || bad "mongodb"

echo "== Round trips =="
R=$(curl -sf -X POST "$FED/post" -H 'Content-Type: application/json' -d '{"from":"verify","message":"verify.sh round-trip"}') && echo "$R" | grep -q posted && ok "board post" || bad "board post"
curl -sf "$FED/board?limit=5" | grep -q verify && ok "board read" || bad "board read"
T=$(curl -sf -X POST "$FED/tenders" -H 'Content-Type: application/json' -d '{"title":"verify-tender","lane":"test"}')
TID=$(echo "$T" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])" 2>/dev/null)
if [ -n "${TID:-}" ]; then
  curl -sf -X POST "$FED/tenders/$TID/claim" -H 'Content-Type: application/json' -d '{"agent":"verify"}' | grep -q claimed && ok "tender claim" || bad "tender claim"
  curl -sf -X POST "$FED/tenders/$TID/award"  -H 'Content-Type: application/json' -d '{"agent":"verify"}' | grep -q awarded && ok "tender award" || bad "tender award"
  curl -sf -X POST "$FED/tenders/$TID/close"  -H 'Content-Type: application/json' -d '{"agent":"verify","evidence":"verify.sh"}' | grep -q closed && ok "tender close" || bad "tender close"
else
  bad "tender mint"
fi
curl -sf -X POST "$SEM/record_decision" -H 'Content-Type: application/json' -d '{"category":"test","scenario":"verify.sh","outcome":"ok"}' | grep -qiE 'ok|recorded|node' && ok "semantica record" || bad "semantica record"
curl -sf "$FED/graph" | grep -q nodes && ok "graph endpoint" || bad "graph endpoint"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
