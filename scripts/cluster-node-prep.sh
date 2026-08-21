#!/usr/bin/env bash
# ── Syndicate OS — per-node prep for a fresh bare cluster ─────────────────
# Idempotent. Run ONCE on each node with its role:
#   sudo ./scripts/cluster-node-prep.sh control
#   sudo ./scripts/cluster-node-prep.sh data
#   sudo ./scripts/cluster-node-prep.sh inference
# Installers assume Debian/Ubuntu (Proxmox VE CT/VM guests or bare metal).
set -euo pipefail
cd "$(dirname "$0")/.."

ROLE="${1:-all}"
case "$ROLE" in all|control|data|inference) ;; *) echo "role: all|control|data|inference"; exit 1 ;; esac
echo "==> node-prep role: $ROLE"

needs_docker() { [ "$ROLE" = "all" ] || [ "$ROLE" = "control" ] || [ "$ROLE" = "data" ]; }

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This prep script targets Debian/Ubuntu. For other distros install docker + hermes manually."
  exit 1
fi

echo "==> [1/5] Base packages + NTP"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl ca-certificates ntpsec >/dev/null 2>&1 \
  || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl ca-certificates chrony >/dev/null 2>&1 \
  || true
timedatectl set-ntp true 2>/dev/null || true
systemctl enable --now ntpsec 2>/dev/null || systemctl enable --now chrony 2>/dev/null || true
echo "  ntp enabled"

if needs_docker; then
  echo "==> [2/5] Docker (compose v2)"
  if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
  fi
  systemctl enable --now docker
  docker compose version
else
  echo "==> [2/5] Docker: skipped for role $ROLE"
fi

echo "==> [3/5] Storage dirs"
if [ "$ROLE" = "data" ] || [ "$ROLE" = "all" ]; then
  set -a; [ -f .env ] && source .env; set +a
  ROOT="${DATA_ROOT:-/srv/syndicate}"
  mkdir -p "$ROOT"/{mongo,semantica,federation}
  chmod 750 "$ROOT" "$ROOT"/* 2>/dev/null || true
  echo "  DATA_ROOT=$ROOT (mongo/semantica/federation)"
else
  echo "  skipped (role $ROLE)"
fi

echo "==> [4/5] Hermes + agents (control/all only)"
if [ "$ROLE" = "all" ] || [ "$ROLE" = "control" ]; then
  if ! command -v hermes >/dev/null 2>&1; then
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
    export PATH="$HOME/.local/bin:$PATH"
  fi
  hermes --version | head -1
else
  echo "  skipped (role $ROLE)"
fi

echo "==> [5/5] Inference node (Ollama)"
if [ "$ROLE" = "inference" ] || [ "$ROLE" = "all" ]; then
  if ! command -v ollama >/dev/null 2>&1; then
    curl -fsSL https://ollama.com/install.sh | sh
  fi
  systemctl enable --now ollama 2>/dev/null || true
  ollama --version
  set -a; [ -f .env ] && source .env; set +a
  for m in ${OLLAMA_PULL_MODELS:-nomic-embed-text llama3.2:3b}; do
    ollama pull "$m" || true
  done
  echo "  Ollama serving on :11434 — bind check: ss -ltnp | grep 11434"
else
  echo "  skipped (role $ROLE)"
fi

echo
echo "✅ node-prep done for $ROLE. Next:"
if [ "$ROLE" = "all" ]; then
  echo "  ./bootstrap.sh"
else
  echo "  copy the repo to this node, set .env (NODE_ROLE=$ROLE), run: ./bootstrap.sh $ROLE"
fi
echo "Firewall hints (only if you run one): allow LAN access to"
echo "  8080 (board) · 8765 (semantica) · 27017 (mongo, data node) · 11434 (ollama, inference node)"
