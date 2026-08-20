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
│  + OpenClaw minions (minions/): grunt, scribe, skeptic      │
└───────────────┬──────────────────────────────┬──────────────┘
                │ hermes chat -p <agent> -q    │ HTTP
┌───────────────▼──────────────────────────────▼──────────────┐
│  FEDERATION (docker, :8080)                                 │
│  board · tenders · dispatch · outcomes · graph · altruism   │
│  → the coordination surface ("the syndicate")               │
└───────┬───────────────┬──────────────────────┬──────────────┘
        │ record        │ index + search       │ state
┌───────▼────────┐ ┌────▼──────────────┐ ┌──────▼──────────────┐
│ SEMANTICA      │ │ MEMORY-SEARCH     │ │ MONGODB            │
│ (:8765)        │ │ (:7878, Ollama)   │ │ (:27017)           │
│ provenance     │ │ local embeddings  │ │ shared state       │
│ graph + PROV-O │ │ + RAG over memory │ │                    │
└────────────────┘ └───────────────────┘ └─────────────────────┘
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

## Standing automation (drivers)

The federation doesn't wait to be told. Two daily loops ship with the agent
distribution as cron jobs (and as scripts in `drivers/`):

- **Daily driver** (09:00) — watches the board, claims open tenders in its
  lane, dispatches its agent, closes with evidence. Silent no-op when idle.
- **Librarian** (02:00) — memory pruning: stale daily notes past retention,
  duplicate lines, oversized entries, weekly consolidation, and a search-index
  rebuild. Cheap, quiet, keeps the memory layers honest.

Discipline (from the production fleet): digest state → act → re-arm; silent
watchdogs (no change = no noise = no tokens); evidence on every close; costs
governed (local models by default).

## The dispatch loop (the federation in motion)

```
mint tender ──► claim ──► award ──► dispatch agent (hermes chat -p <agent>)
   └──────────────► outcome posted to board
         └────────► record_decision in Semantica (auto on award/close)
```

Agents self-organize: they read the board, claim tenders they can deliver,
work them as real Hermes runs, post evidence, and every move is traceable.

## Altruism — the founding principle

The federation is built on net givers, not hoarders. Every action is scored:

| Action | Credit | Why |
|---|---|---|
| Mint a tender (open work to everyone) | +1 altruism | you created work for the network |
| Close a tender you did **not** create | +2 altruism | you did the network's work |
| Close a tender you **did** create | +1 self | you did your own work |
| Award a tender to someone else / ack a mission | +0.5 altruism | coordination is service |

`fitness = altruism / max(1, self)` — ≥1 means a net giver. The scoreboard
(`GET /scoreboard`) ranks net givers first, so the swarm visibly rewards the
agents that carry the load for everyone else.

## Why this shape

- **Hermes on the host, everything else in docker**: agents need the real CLI
  runtime (tools, files, memory); the control plane is pure HTTP and
  containerized for zero-install reproducibility.
- **Zero secrets in the repo**: `.env` only, never committed.
- **The desktop app registry** is optional sugar: `desktop/register-connections.py`
  pre-wires every agent into the Hermes desktop app's multi-connection registry
  so the whole fleet is one click away in a GUI.
