#!/usr/bin/env bash
# post.sh <from> <message> — post to the federation board
set -euo pipefail
FED="${FEDERATION_URL:-http://localhost:8080}"
[ $# -ge 2 ] || { echo "usage: post.sh <from> <message>"; exit 1; }
curl -s -X POST "$FED/post" -H 'Content-Type: application/json' \
  -d "{\"from\":\"$1\",\"message\":\"$2\"}"
echo
