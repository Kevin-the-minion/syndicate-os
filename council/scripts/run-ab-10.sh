#!/usr/bin/env bash
# 10-problem A/B run: trip arm vs baseline arm, SAME local model, blind + sealed.
# Backend: local Ollama on chris-System (.193). Free, no paid API.
set -u

export OLLAMA_HOST="${OLLAMA_HOST:-http://192.168.0.193:11434}"
export OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.1:8b}"
export BACKEND="ollama"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

PROBLEMS=(
"Audit the federation memory layer (MongoDB, self-hosted Honcho, memory-search) for correctness, freshness, and failure modes."
"Find the single most likely operational failure in the board -> dispatch -> minion loop."
"Where does the 'self-host, no SaaS' positioning claim break under scrutiny?"
"Identify the top three onboarding friction points for a new external contributor."
"What is missing from the repo docs that would block a cold start from scratch?"
"Audit the A/B harness itself for validity threats (confounds, leakage, blind-breaking)."
"Where is the provenance story (Semantica) weakest?"
"Find security risks in the board's exposed HTTP endpoints (/send, /chat, /dispatch, /post)."
"What single change would most improve the council trip's signal-to-noise ratio?"
"Audit the minion provisioning scripts for correctness against the real OpenClaw CLI."
)

echo "=== A/B run: ${#PROBLEMS[@]} problems | backend=${BACKEND} | model=${OLLAMA_MODEL} ==="
for i in "${!PROBLEMS[@]}"; do
    n=$((i+1))
    p="${PROBLEMS[$i]}"
    echo ""
    echo "### [${n}/${#PROBLEMS[@]}] ${p}"
    if ./scripts/ab-test --api "${p}" 2>&1; then
        echo "  [OK] problem ${n} done"
    else
        echo "  [FAIL] problem ${n} (continuing to next)"
    fi
done
echo ""
echo "=== DONE. Run dirs under council/runs/ab-* ==="
