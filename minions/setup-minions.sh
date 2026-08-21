#!/usr/bin/env bash
# ── setup-minions.sh — spin up an OpenClaw minion fleet ────────────────────
# "Parallel OpenClaw agents": a parallel OpenClaw agent fleet, each minion with its
# own isolated workspace + gateway token (no shared runtime), exactly like the
# production fleet. Minions complement the Hermes agents (different harness =
# different blind spots — anti-monoculture by construction).
#
# Usage:
#   MINION_NAMES="grunt,scribe,skeptic" MINION_MODEL="ollama/llama3.2:3b" ./setup-minions.sh
#
# Requires: Node.js >= 20 (npm), OpenClaw installs via npm.
set -euo pipefail
cd "$(dirname "$0")"

NAMES="${MINION_NAMES:-grunt,scribe,skeptic}"
MODEL="${MINION_MODEL:-ollama/llama3.2:3b}"
WORKSPACE_ROOT="${OPENCLAW_WORKSPACE_ROOT:-$HOME/.openclaw/workspace}"

echo "==> [1/3] OpenClaw"
if ! command -v openclaw >/dev/null 2>&1; then
  echo "  installing OpenClaw via npm (needs Node >= 20)..."
  npm install -g openclaw
fi
openclaw --version | head -1

echo "==> [2/3] Create minions"
IFS=',' read -ra MINIONS <<< "$NAMES"
for name in "${MINIONS[@]}"; do
  name="${name// /}"
  [ -z "$name" ] && continue
  ws="$WORKSPACE_ROOT/$name"
  if openclaw agents list --json 2>/dev/null | grep -q "\"id\": \"$name\""; then
    echo "  minion $name exists — skip"
  else
    echo "  creating minion: $name (model: $MODEL)"
    openclaw agents add "$name" \
      --model "$MODEL" \
      --workspace "$ws" \
      --agent-dir "$HOME/.openclaw/agents/$name/agent" \
      --non-interactive
  fi
done
openclaw agents list

echo "==> [3/3] Gateway"
echo "  start each minion's gateway on its own port, e.g.:"
echo "    openclaw gateway --port 18789 --auth token  (one per minion)"
echo "  or run: openclaw gateway start --agent <name>"
echo
echo "✅ Minion fleet ready. Wake a minion with:"
echo "    openclaw agent --agent grunt --message-file brief.txt"
echo "  Per-minion tokens live under ~/.openclaw (gateway auth) — keep them"
echo "  private; the federation dispatch can call openclaw the same way."
