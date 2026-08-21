#!/usr/bin/env bash
# expose-tools.sh — expose one minion's gateway over MCP (OpenClaw native).
# Usage:  ./expose-tools.sh <agent-id> [gateway-url] [token-file]
set -euo pipefail

AGENT_ID="${1:?usage: expose-tools.sh <agent-id> [gateway-url] [token-file]}"
GATEWAY_URL="${2:-${GATEWAY_URL:-wss://127.0.0.1:18789}}"
TOKEN_FILE="${3:-${TOKEN_FILE:-$HOME/.openclaw/gateway.token}}"

[ -f "$TOKEN_FILE" ] || { echo "ERROR: gateway token not found at $TOKEN_FILE" >&2; exit 1; }

echo "exposing minion '${AGENT_ID}' over MCP (stdio) via ${GATEWAY_URL}" >&2
exec openclaw mcp serve --url "$GATEWAY_URL" --token-file "$TOKEN_FILE"
