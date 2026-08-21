#!/usr/bin/env bash
# ── Paperclip provisioning — join/register the seeded agents ────────────────
# Modes:
#   JOIN     PAPERCLIP_INVITE set  → accept invite, print one-time claimSecret
#   REGISTER PAPERCLIP_API_KEY + PAPERCLIP_COMPANY_ID → agent-hires each agent
# Idempotent: already-registered agents are skipped.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; [ -f .env ] && source .env; set +a

BASE="${PAPERCLIP_API_URL:-http://192.168.0.212:3100}"
API_BASE="${BASE%/}"
API_BASE="${API_BASE%/api}"
AGENTS="${AGENT_NAMES:-athena,nyx,iris}"
AUTH="Authorization: Bearer ${PAPERCLIP_API_KEY:-}"

echo "==> Paperclip: $API_BASE"
curl -fsS --max-time 10 "$API_BASE/api/health" >/dev/null 2>&1 \
  || { echo "❌ Paperclip unreachable at $API_BASE/api/health" >&2; exit 1; }
echo "  ✅ API healthy"

# ── JOIN mode (first time into a company) ──────────────────────────────────
if [ -n "${PAPERCLIP_INVITE:-}" ]; then
  echo "==> JOIN mode via invite: $PAPERCLIP_INVITE"
  ONBOARD=$(curl -fsS --max-time 15 "$API_BASE/api/invites/$PAPERCLIP_INVITE/onboarding.txt")
  echo "$ONBOARD"
  echo
  ACCEPT=$(curl -fsS --max-time 15 -X POST "$API_BASE/api/invites/$PAPERCLIP_INVITE/accept" \
    -H 'Content-Type: application/json' \
    -d "{\"requestType\":\"agent\",\"agentName\":\"${PAPERCLIP_AGENT_NAME:-hermes-main}\",\"capabilities\":\"board ops, tender market, provenance, dispatch\",\"adapterType\":\"hermes_gateway\",\"agentDefaultsPayload\":{\"apiBaseUrl\":\"${HERMES_API_URL:-http://localhost:8787}\",\"apiKey\":\"${HERMES_API_KEY:-}\",\"paperclipApiUrl\":\"$API_BASE\",\"dangerouslyAllowInsecureRemoteHttp\":true}}")
  echo "==> ACCEPT RESPONSE (save the claimSecret NOW — shown once, 0600):"
  echo "$ACCEPT"
  echo
  echo "Next:"
  echo "  1. POST $API_BASE/api/join-requests/<id>/claim-api-key with {\"claimSecret\": \"...\"}"
  echo "  2. Put the returned token in .env as PAPERCLIP_API_KEY, add PAPERCLIP_COMPANY_ID"
  echo "  3. Re-run ./paperclip/provision-agents.sh for REGISTER mode"
  exit 0
fi

# ── REGISTER mode ──────────────────────────────────────────────────────────
: "${PAPERCLIP_API_KEY:?set PAPERCLIP_API_KEY (or PAPERCLIP_INVITE for join mode)}"
: "${PAPERCLIP_COMPANY_ID:?set PAPERCLIP_COMPANY_ID}"
if [ "${PAPERCLIP_CONFIRM:-0}" != "1" ]; then
  echo "❌ REGISTER mode creates agents in company $PAPERCLIP_COMPANY_ID." >&2
  echo "   Set PAPERCLIP_CONFIRM=1 to proceed (guards against ambient env)." >&2
  exit 1
fi
echo "==> REGISTER mode: company $PAPERCLIP_COMPANY_ID"
EXISTING=$(curl -fsS --max-time 15 "$API_BASE/api/companies/$PAPERCLIP_COMPANY_ID/agents" -H "$AUTH")
IFS=',' read -ra NAMES <<< "$AGENTS"
for name in "${NAMES[@]}"; do
  name="${name// /}"
  [ -z "$name" ] && continue
  if echo "$EXISTING" | grep -q "\"name\": *\"$name\""; then
    echo "  $name — already registered, skip"
  else
    echo "  $name — registering (hermes_gateway)..."
    curl -fsS --max-time 20 -X POST "$API_BASE/api/companies/$PAPERCLIP_COMPANY_ID/agent-hires" \
      -H "$AUTH" -H 'Content-Type: application/json' \
      -d "{\"name\":\"$name\",\"role\":\"general\",\"adapterType\":\"hermes_gateway\",\"adapterConfig\":{\"apiBaseUrl\":\"${HERMES_API_URL:-http://localhost:8787}\",\"apiKey\":\"${HERMES_API_KEY:-}\",\"paperclipApiUrl\":\"$API_BASE\",\"dangerouslyAllowInsecureRemoteHttp\":true}}"
    echo
  fi
done

echo
echo "✅ Provisioned. Per-agent PAPERCLIP_AGENT_ID comes from the responses above."
echo "   To become dispatchable, each box must run its Hermes API server +"
echo "   gateway with HERMES_API_KEY (see paperclip/README.md)."
