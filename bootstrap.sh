#!/usr/bin/env bash
# ── Syndicate OS bootstrap — Hermes + agents + docker stack ───────────────
# Usage:
#   ./bootstrap.sh                 # single host (everything, default)
#   ./bootstrap.sh control         # cluster: federation + memory-search + agents
#   ./bootstrap.sh data            # cluster: mongodb + semantica + explorer
#   ./bootstrap.sh inference       # cluster: Ollama only (host-side, GPU)
# Role also comes from NODE_ROLE in .env (cluster mode). Full runbook:
# docs/CLUSTER.md
set -euo pipefail
cd "$(dirname "$0")"

ROLE="${1:-${NODE_ROLE:-all}}"
case "$ROLE" in
  all|control|data|inference) ;;
  *) echo "Unknown role '$ROLE' — use all|control|data|inference"; exit 1 ;;
esac
echo "==> role: $ROLE"

needs_docker() { [ "$ROLE" = "all" ] || [ "$ROLE" = "control" ] || [ "$ROLE" = "data" ]; }

echo "==> [1/7] Runtime check"
if needs_docker; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required. Run scripts/cluster-node-prep.sh $ROLE (or install docker):"
    echo "  Debian/Ubuntu: sudo apt-get install -y docker.io docker-compose-v2 && sudo systemctl enable --now docker"
    echo "  or: https://docs.docker.com/engine/install/"
    exit 1
  fi
  docker compose version >/dev/null 2>&1 || { echo "docker compose v2 plugin required"; exit 1; }
else
  if ! command -v ollama >/dev/null 2>&1; then
    echo "Ollama is required on the inference node. Run scripts/cluster-node-prep.sh inference"
    echo "  (or: curl -fsSL https://ollama.com/install.sh | sh)"
    exit 1
  fi
  ollama --version
fi

echo "==> [2/7] .env"
if [ ! -f .env ]; then
  cp .env.example .env
  echo "  .env created from example. Set LLM_API_KEY (and tweak AGENT_NAMES), then re-run."
  exit 1
fi
set -a; source .env; set +a
if [ "$ROLE" = "all" ] || [ "$ROLE" = "control" ]; then
  if [ -z "${LLM_API_KEY:-}" ] || [ "$LLM_API_KEY" = "«redacted:sk-…»" ]; then
    echo "  Set LLM_API_KEY in .env first."
    exit 1
  fi
fi

echo "==> [3/7] Preflight (reachability)"
port_open() { # host port
  (exec 3<>/dev/tcp/"$1"/"$2") 2>/dev/null && return 0 || return 1
}
if [ "$ROLE" = "control" ]; then
  [ -n "${DATA_HOST:-}" ] || { echo "  DATA_HOST unset in .env — set it for cluster mode"; exit 1; }
  [ -n "${INFERENCE_HOST:-}" ] || { echo "  INFERENCE_HOST unset in .env — set it for cluster mode"; exit 1; }
  echo "  -> data $DATA_HOST:27017"; port_open "$DATA_HOST" "${MONGO_PORT:-27017}" || echo "    ⚠ mongo not reachable yet (data node may still be booting)"
  echo "  -> data $DATA_HOST:8765";  port_open "$DATA_HOST" "${SEMANTICA_PORT:-8765}" || echo "    ⚠ semantica not reachable yet"
  echo "  -> inference $INFERENCE_HOST:11434"; port_open "$INFERENCE_HOST" 11434 || echo "    ⚠ ollama not reachable yet"
fi

echo "==> [4/7] Hermes Agent (control/all only)"
if [ "$ROLE" = "all" ] || [ "$ROLE" = "control" ]; then
  if ! command -v hermes >/dev/null 2>&1; then
    echo "  installing Hermes Agent (official installer)..."
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
    export PATH="$HOME/.local/bin:$PATH"
  fi
  hermes --version | head -1

  echo "==> [5/7] Seed agents"
  IFS=',' read -ra AGENTS <<< "${AGENT_NAMES:-athena,nyx,iris}"
  mkdir -p "$HOME/.hermes"
  if ! grep -q "^LLM_API_KEY=" "$HOME/.hermes/.env" 2>/dev/null; then
    echo "LLM_API_KEY=$LLM_API_KEY" >> "$HOME/.hermes/.env"
    chmod 600 "$HOME/.hermes/.env"
    echo "  wrote LLM_API_KEY to ~/.hermes/.env"
  fi
  [ -z "${MODEL_PROVIDER:-}" ] || hermes config set model.provider "$MODEL_PROVIDER" >/dev/null 2>&1 || true
  [ -z "${MODEL_NAME:-}" ] || hermes config set model.default "$MODEL_NAME" >/dev/null 2>&1 || true
  for name in "${AGENTS[@]}"; do
    name="${name// /}"
    [ -z "$name" ] && continue
    if hermes profile list 2>/dev/null | grep -qw "$name"; then
      echo "  profile $name exists — skip"
    else
      echo "  seeding profile: $name"
      hermes profile install ./agents --name "$name" -y
    fi
  done
  echo "  profiles: $(hermes profile list | tr '\n' ' ')"
else
  echo "  skipped (role $ROLE has no agents)"
fi

echo "==> [6/7] Docker stack"
if needs_docker; then
  if [ "$ROLE" = "all" ]; then
    docker compose up -d --build
  else
    docker compose -f docker-compose.yml -f docker-compose.cluster.yml --profile "$ROLE" up -d --build
  fi
  sleep 5
else
  echo "  skipped (inference node runs Ollama host-side, no compose services)"
fi

echo "==> [7/7] Paperclip control plane (optional, control/all only)"
if { [ "$ROLE" = "all" ] || [ "$ROLE" = "control" ]; }; then
  if [ "${PAPERCLIP_ENABLE:-0}" = "1" ] && [ -n "${PAPERCLIP_API_URL:-}" ]; then
    ./paperclip/provision-agents.sh
  else
    echo "  skipped — set PAPERCLIP_ENABLE=1 + PAPERCLIP_API_URL to provision agents"
    echo "  into a Paperclip control plane (see paperclip/README.md)"
  fi
else
  echo "  skipped (role $ROLE)"
fi

echo
case "$ROLE" in
  all)
    echo "✅ Syndicate OS is up (single host):"
    echo "  Board UI:      http://localhost:${FEDERATION_PORT:-8080}"
    echo "  Semantica API: http://localhost:${SEMANTICA_PORT:-8765}"
    echo "  Explorer:      http://localhost:${EXPLORER_PORT:-8000}"
    echo "  MongoDB:       localhost:${MONGO_PORT:-27017}"
    ;;
  control)
    echo "✅ Control node is up:"
    echo "  Board UI:      http://${CONTROL_HOST:-localhost}:${FEDERATION_PORT:-8080}"
    echo "  Memory search: http://${CONTROL_HOST:-localhost}:${MEMORY_SEARCH_PORT:-7878}"
    echo "  Agents:        ${AGENT_NAMES:-athena,nyx,iris}"
    echo "  (Semantica/Explorer live on the data node, Ollama on the inference node)"
    ;;
  data)
    echo "✅ Data node is up:"
    echo "  MongoDB:       ${DATA_HOST:-localhost}:${MONGO_PORT:-27017}"
    echo "  Semantica API: http://${DATA_HOST:-localhost}:${SEMANTICA_PORT:-8765}"
    echo "  Explorer:      http://${DATA_HOST:-localhost}:${EXPLORER_PORT:-8000}"
    echo "  Storage root:  ${DATA_ROOT:-./data}"
    ;;
  inference)
    echo "✅ Inference node ready (Ollama host-side):"
    echo "  Ollama API:    http://${INFERENCE_HOST:-localhost}:11434"
    ;;
esac
echo
echo "Smoke test (control/all): ./verify.sh"
echo "Cluster checks (from control): ./scripts/cluster-preflight.sh"
echo "Optional desktop wiring: python3 desktop/register-connections.py -"
