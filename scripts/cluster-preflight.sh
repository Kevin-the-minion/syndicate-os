#!/usr/bin/env bash
# ── Syndicate OS — cluster preflight (run from the CONTROL node) ──────────
# Verifies the 3-node mesh: control, data, inference reachable; storage and
# clock sane. Read-only. Exit non-zero on any FAIL.
set -uo pipefail
cd "$(dirname "$0")/.."
set -a; [ -f .env ] && source .env; set +a

CTL="${CONTROL_HOST:-localhost}"
DATA="${DATA_HOST:-localhost}"
INF="${INFERENCE_HOST:-localhost}"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
bad(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }
port_open() { (exec 3<>/dev/tcp/"$1"/"$2") 2>/dev/null; }
http_ok() { curl -sf --max-time 5 "$1" >/dev/null 2>&1; }

echo "== Cluster preflight (control=$CTL data=$DATA inference=$INF) =="

echo "== Control node =="
http_ok "http://$CTL:${FEDERATION_PORT:-8080}/health" && ok "federation :${FEDERATION_PORT:-8080}" || bad "federation"
port_open "$CTL" "${MEMORY_SEARCH_PORT:-7878}" && ok "memory-search :${MEMORY_SEARCH_PORT:-7878}" || bad "memory-search"
command -v hermes >/dev/null 2>&1 && ok "hermes CLI" || bad "hermes CLI"
for name in $(echo "${AGENT_NAMES:-athena,nyx,iris}" | tr ',' ' '); do
  hermes profile list 2>/dev/null | grep -qw "$name" && ok "profile $name" || bad "profile $name"
done

echo "== Data node =="
port_open "$DATA" "${MONGO_PORT:-27017}" && ok "mongodb :${MONGO_PORT:-27017}" || bad "mongodb"
http_ok "http://$DATA:${SEMANTICA_PORT:-8765}/health" && ok "semantica :${SEMANTICA_PORT:-8765}" || bad "semantica"
http_ok "http://$DATA:${EXPLORER_PORT:-8000}" && ok "explorer :${EXPLORER_PORT:-8000}" || bad "explorer"

echo "== Inference node =="
http_ok "http://$INF:11434/api/tags" && ok "ollama :11434" || bad "ollama"

echo "== Clock =="
if command -v timedatectl >/dev/null 2>&1; then
  timedatectl | grep -q "synchronized: yes" && ok "NTP synchronized (local)" || bad "NTP NOT synchronized (local)"
fi
for h in "$CTL" "$DATA" "$INF"; do
  [ "$h" = "localhost" ] && continue
  REMOTE=$(curl -sI --max-time 4 "http://$h:8080/health" | grep -i '^Date:' | sed 's/^[Dd]ate: //' | tr -d '\r')
  if [ -n "$REMOTE" ]; then
    LOCAL=$(date -u '+%a, %d %b %Y %H:%M:%S GMT')
    if command -v date >/dev/null 2>&1 && date -d "$REMOTE" +%s >/dev/null 2>&1; then
      R=$(date -d "$REMOTE" +%s); L=$(date -d "$LOCAL" +%s); SKEW=$((R-L)); [ ${SKEW#-} -le 5 ] && ok "clock skew $h <= 5s" || bad "clock skew $h = ${SKEW}s"
    else
      echo "  ⚠ cannot parse Date header from $h"
    fi
  fi
done

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
