#!/usr/bin/env bash
# dispatch.sh <agent> <prompt> — run a real agent on the HOST
# The federation service runs in docker; agents live on the host, so the real
# dispatch happens here. (The board UI prints this same command.)
set -euo pipefail
[ $# -ge 2 ] || { echo "usage: dispatch.sh <agent> <prompt>"; exit 1; }
exec hermes chat -p "$1" -q "$2"
