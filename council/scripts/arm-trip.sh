#!/usr/bin/env bash
# arm-trip.sh — trip-arm bridge for the A/B harness.
# The bash `trip` script dies silently under set -u on some bash 5.2 builds
# (unbound-variable exit inside the role loop, no error surfaced). This bridge
# runs the same frames through council-run.py (portable python) and emits the
# synthesis — the distilled, ranked findings — on stdout, which is what the
# A/B harness expects from the trip arm.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBLEM="$1"

TMP="$(mktemp -d /tmp/arm-trip.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

OLLAMA_API="${OLLAMA_HOST:-http://localhost:11434}" \
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.1:8b}" \
COUNCIL_RUNS_DIR="$TMP" \
  python3 "$SCRIPT_DIR/council-run.py" --dose standard "$PROBLEM" >/dev/null 2>&1

if compgen -G "$TMP"/*/synthesis.md >/dev/null; then
  cat "$TMP"/*/synthesis.md
else
  cat "$TMP"/*/all-roles.md 2>/dev/null
fi
