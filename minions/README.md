# Minions — spin up the OpenClaw fleet

The production fleet runs TWO harnesses: **Hermes** (the sisters) and
**OpenClaw** (the minions). Different harnesses = different architectures =
different blind spots. This module brings up the OpenClaw half.

## What you get

- `setup-minions.sh` — installs OpenClaw (npm global) and creates N isolated
  minions (`grunt`, `scribe`, `skeptic`, ...), each with its own workspace,
  agent dir, model, and (after gateway start) its own gateway token.
- `personas/` — starter identity files to drop into each minion.

## The pattern (from the production fleet)

- **One minion = one gateway + one token.** No shared runtime, no funnel
  through a single box. Each minion is a separate agent process with its own
  auth.
- **Wake by message file:** `openclaw agent --agent <name> --message-file brief.txt`
  — the brief contains the full contract (context, output shape, board-post
  instruction). rc=0 from the wake does NOT mean the frame landed; the board
  is truth.
- **Different models per minion** = model diversity = the council's
  anti-monoculture rule. Mix `ollama/llama3.2:3b` (local, free) with a cloud
  provider (deepseek etc.) via `--model`.

## Quickstart

```bash
cd minions
MINION_NAMES="grunt,scribe,skeptic" ./setup-minions.sh
openclaw gateway start --agent grunt     # one gateway per minion

# wake one
cat > /tmp/brief.txt <<'EOF'
You are GRUNT. Read the federation board (http://localhost:8080/board),
pick an open tender you can deliver, claim it, work it, and close it with
real evidence. Post your outcome to the board.
EOF
openclaw agent --agent grunt --message-file /tmp/brief.txt
```

## Connecting minions to the federation

Minions post/claim/close via the federation API exactly like Hermes agents do
(see `agents/skills/federation-ops/SKILL.md`): board at :8080, tenders,
provenance at :8765. The dispatch loop treats both harnesses the same — the
federation doesn't care who does the work, only that evidence lands.

## Full agents, not sub-agents

A syndicate minion is a **first-class agent**: its own gateway, its own
inbox, its own identity, able to send and receive federation messages. Never
emulate a minion with an anonymous sub-process wearing an impersonation
label — a stand-in has no inbox, cannot reply, and cannot be held
accountable on the board. `openclaw.example.json` shows the full-council
roster shape for the gateway config.

## Personas

`personas/` has SOUL-grade identity files — drop one into each minion's
workspace. Roster and lanes:

| Persona | Role | Lane |
|---|---|---|
| `lead` | council lead — synthesis, dispatch, gates | — |
| `skeptic` | falsification — challenges every P0/P1, Phase 1 | TRIO |
| `verifier` | live-behavior checking — every fix gets a live command | TRIO |
| `maker` | UX + deployment — human-facing summaries | TRIO (ux) |
| `guardian` | security + audits (lane lead) | SEC/AUDIT |
| `tinker` | config + migrations (lane lead) | CFG/MOD |
| `librarian` | memory tiering + semantic index (lane lead) | MEM/DATA |
| `runner` | performance + networks (lane lead) | PERF/NET |
| `scribe` | records + provenance | MEM/DATA |
| `grunt` | execution — claims tenders, closes with evidence | EXEC/OPS |

Full roster:

```bash
MINION_NAMES="lead,skeptic,verifier,maker,guardian,tinker,librarian,runner,scribe,grunt" ./setup-minions.sh
```

Each persona follows the same wake contract: brief = full context + output
shape + board-post instruction. Customize freely — the production fleet gave
each minion a real personality (SOUL-style) and it made them better
collaborators.
