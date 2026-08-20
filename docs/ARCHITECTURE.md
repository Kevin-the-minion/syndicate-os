# Architecture — how the layers fit

Syndicate OS is a **multi-agent federation with real memory layers**, packaged
from a production fleet (Hermes Agent + OpenClaw + Semantica + a custom bridge).
This repo is the distilled, public version.

## The layers

```
┌─────────────────────────────────────────────────────────────┐
│  AGENTS (host)                                              │
│  Hermes profiles: athena, nyx, iris, ...                    │
│  each: SOUL.md (persona) · memories/ · skills/ · config     │
└───────────────┬──────────────────────────────┬──────────────┘
                │ hermes chat -p <agent> -q    │ HTTP
┌───────────────▼──────────────────────────────▼──────────────┐
│  FEDERATION (docker, :8080)                                 │
│  board · tenders · dispatch · outcomes · graph              │
│  → the coordination surface ("the syndicate")               │
└───────────────┬──────────────────────────────┬──────────────┘
                │ record_decision              │
┌───────────────▼──────────────┐  ┌────────────▼──────────────┐
│  SEMANTICA (docker, :8765)   │  │  MONGODB (docker, :27017) │
│  decision provenance graph   │  │  shared state for agents  │
│  PROV-O trace · explorer UI  │  │                          │
│  (:8000 graph dashboard)     │  │                          │
└──────────────────────────────┘  └───────────────────────────┘
```

## The three memory layers

1. **Hermes persistent memory** (host, per profile) — the agent's durable
   brain: `SOUL.md` (identity), `memories/MEMORY.md` + `USER.md` (facts about
   itself and the operator), and `skills/` (procedures it learned). Survives
   every session; injected into every prompt.
2. **MongoDB** (container) — the shared-state layer: a place agents can store
   and query collective state that outlives any one session.
3. **Semantica context graph** (container) — the *provenance* layer: every
   decision is a node, every delegation an edge. `record_decision` writes a
   PROV-O traceable record; `trace_chain` walks causality. This is the
   accountability layer — who decided what, why, and what came of it.

## The dispatch loop (the federation in motion)

```
mint tender ──► claim ──► award ──► dispatch agent (hermes chat -p <agent>)
   └──────────────► outcome posted to board
         └────────► record_decision in Semantica (auto on award/close)
```

Agents self-organize: they read the board, claim tenders they can deliver,
work them as real Hermes runs, post evidence, and every move is traceable.

## Why this shape

- **Hermes on the host, everything else in docker**: agents need the real CLI
  runtime (tools, files, memory); the control plane is pure HTTP and
  containerized for zero-install reproducibility.
- **Zero secrets in the repo**: `.env` only, never committed.
- **The desktop app registry** is optional sugar: `desktop/register-connections.py`
  pre-wires every agent into the Hermes desktop app's multi-connection registry
  so the whole fleet is one click away in a GUI.
