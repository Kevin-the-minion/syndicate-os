#!/usr/bin/env bash
# ── Syndicate OS bootstrap — one-shot: Hermes + agents + docker stack ──────
set -euo pipefail
cd "$(dirname "$0")"

echo "==> [1/6] Docker check"
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required. Install it, e.g.:"
  echo "  Debian/Ubuntu: sudo apt-get install -y docker.io docker-compose-v2 && sudo systemctl enable --now docker"
  echo "  or: https://docs.docker.com/engine/install/"
  exit 1
fi

echo "==> [2/6] .env"
if [ ! -f .env ]; then
  cp .env.example .env
  echo "  .env created from example. Set LLM_API_KEY (and tweak AGENT_NAMES), then re-run."
  exit 1
fi
set -a; source .env; set +a
if [ -z "${LLM_API_KEY:-}" ] || [ "$LLM_API_KEY" = "sk-your-key-here" ]; then
  echo "  Set LLM_API_KEY in .env first."
  exit 1
fi

echo "==> [3/6] Hermes Agent"
if ! command -v hermes >/dev/null 2>&1; then
  echo "  installing Hermes Agent (official installer)..."
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
fi
hermes --version | head -1

echo "==> [4/6] Seed agents"
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

echo "==> [5/6] Docker stack"
docker compose up -d --build
sleep 5

echo "==> [6/6] Paperclip control plane (optional)"
if [ "${PAPERCLIP_ENABLE:-0}" = "1" ] && [ -n "${PAPERCLIP_API_URL:-}" ]; then
  ./paperclip/provision-agents.sh
else
  echo "  skipped — set PAPERCLIP_ENABLE=1 + PAPERCLIP_API_URL to provision agents"
  echo "  into a Paperclip control plane (see paperclip/README.md)"
fi

echo
echo "✅ Syndicate OS is up:"
echo "  Board UI:      http://localhost:${FEDERATION_PORT:-8080}"
echo "  Semantica API: http://localhost:${SEMANTICA_PORT:-8765}"
echo "  Explorer:      http://localhost:${EXPLORER_PORT:-8000}"
echo "  MongoDB:       localhost:${MONGO_PORT:-27017}"
echo "  Paperclip:     ${PAPERCLIP_API_URL:-not configured}"
echo "  Agents:        ${AGENT_NAMES:-athena,nyx,iris}"
echo
echo "Smoke test: ./verify.sh"
echo "Optional desktop wiring: python3 desktop/register-connections.py -"
