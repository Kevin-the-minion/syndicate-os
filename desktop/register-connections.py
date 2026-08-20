#!/usr/bin/env python3
"""register-connections.py — pre-wire agents into the Hermes desktop app.

Writes ~/.config/Hermes/connections.json (the desktop multi-connection
registry) from a simple file, one agent per line:

    name|http://host:port|session-token

The token column is optional. If present it is stored as a hand-editable
plaintext envelope — the desktop app's documented fallback for hand-edited
configs. Run this BEFORE the first launch of the desktop app (or while it is
closed), then launch `hermes desktop`: every agent appears as a gateway.

Usage:
    python3 register-connections.py <agents.txt>
    # or with a tokenless file to register only:
    echo "athena|http://localhost:9119" | python3 register-connections.py -
"""
import json
import os
import sys
from pathlib import Path

def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    src = sys.argv[1]
    if src == "-":
        lines = sys.stdin.read().splitlines()
    else:
        lines = Path(src).read_text().splitlines()

    connections = [{"id": "local", "kind": "local", "label": "Local"}]
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.split("|")]
        if len(parts) < 2:
            print(f"skip malformed: {line!r}")
            continue
        name, url = parts[0], parts[1]
        token = parts[2] if len(parts) > 2 and parts[2] else None
        entry = {
            "id": name.lower().replace(" ", "-"),
            "kind": "remote",
            "label": name,
            "url": url,
            "authMode": "token",
        }
        if token:
            entry["token"] = {"encoding": "plain", "value": token}
        connections.append(entry)

    registry = {
        "version": 2,
        "primary": "local",
        "launchMode": "primary",
        "lastUsed": "local",
        "connections": connections,
    }

    home = Path.home()
    dest = home / ".config" / "Hermes" / "connections.json"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(registry, indent=2))
    os.chmod(dest, 0o600)

    authed = sum(1 for c in connections if c.get("token"))
    print(f"wrote {dest}")
    print(f"registered {len(connections)} connections ({authed} with tokens): "
          + ", ".join(c["label"] for c in connections))
    return 0

if __name__ == "__main__":
    sys.exit(main())
