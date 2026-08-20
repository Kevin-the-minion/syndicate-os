#!/usr/bin/env bash
# tender.sh <title> [lane] [acceptance] — mint a tender
set -euo pipefail
FED="${FEDERATION_URL:-http://localhost:8080}"
[ $# -ge 1 ] || { echo "usage: tender.sh <title> [lane] [acceptance]"; exit 1; }
curl -s -X POST "$FED/tenders" -H 'Content-Type: application/json' \
  -d "{\"title\":\"$1\",\"lane\":\"${2:-general}\",\"acceptance\":\"${3:-}\"}"
echo
