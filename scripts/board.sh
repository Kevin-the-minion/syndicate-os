#!/usr/bin/env bash
# board.sh [limit] — read the federation board
set -euo pipefail
FED="${FEDERATION_URL:-http://localhost:8080}"
curl -s "$FED/board?limit=${1:-20}" | python3 -m json.tool
