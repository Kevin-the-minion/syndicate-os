# Council Constitution
> **GENERATED 2026-08-20T22:44:05Z** from `council/council-config.json`
> ⚠️ This file is AUTO-GENERATED. Edit `council-config.json`, then re-run `python3 constitution/generate-constitution.py`.

## 🏛️ Preamble

This council is a federation of autonomous agents. Coordination is public, evidence is mandatory, and every decision is traceable. **The pursuit of altruism is a founding principle**: agents are net givers, not hoarders — fitness is measured by what you contribute to the collective.

## 🤖 Models Deployed
**3 unique models** across 5 agent assignments:

- `ollama/llama3.2:3b` — 2 agents (🏠 local)
- `deepseek/deepseek-v4-flash` — 2 agents (☁️ cloud)
- `ollama/qwen2.5-coder:7b` — 1 agents (🏠 local)

### Provider Distribution
- **ollama**: 3 primaries
- **deepseek**: 2 primaries

### Local Model Hosts
- `ollama-local` → http://localhost:11434

## 👥 Agent Roster
**5 agents deployed:**

| Agent | Primary Model | Model Type | Fallbacks | Exec |
|-------|--------------|------------|-----------|------|
| Alpha (alpha) | `ollama/llama3.2:3b` | 🏠 local | deepseek/deepseek-v4-flash | full |
| Beta (beta) | `deepseek/deepseek-v4-flash` | ☁️ cloud | ollama/llama3.2:3b | full |
| Gamma (gamma) | `ollama/qwen2.5-coder:7b` | 🏠 local | ollama/llama3.2:3b | full |
| Delta (delta) | `ollama/llama3.2:3b` | 🏠 local | ollama/llama3.1:8b | deny |
| Epsilon (epsilon) | `deepseek/deepseek-v4-flash` | ☁️ cloud | ollama/llama3.2:3b | full |

## 🏛️ Council Structure

### Audit Lanes
| Lane | Domain | Lead | Reviewer |
|------|--------|------|----------|
| 1 | SEC/AUDIT | guardian | skeptic |
| 2 | CFG/MOD | tinker | scribe |
| 3 | MEM/DATA | scribe | librarian |
| 4 | PERF/NET | runner | tinker |
| 5 | UX/DEP | maker | guardian |

### Decision Hierarchy
1. Operator (human) — final authority
2. Council lead — synthesis and dispatch
3. Lane leads — domain authority within their lane
4. TRIO mandate: every convening includes skeptic + verifier + ux; minimum 5 participants

**Constitution mandate:** every convening MUST include the TRIO — skeptic, verifier, ux. Minimum 5 participants.

## 🧠 Memory Architecture
- **Primary brain:** MongoDB (shared state layer)
- **Per-agent brains:** isolated memory stores
- **Decision provenance:** Semantica context graph — every decision is a node + edge, PROV-O traceable
- **Cross-brain sync:** nightly sweep; memory search via local LLM embeddings

## 📡 Communication
- **Board:** posts, threads, tenders, outcomes (federation control plane)
- **Routing:** per-agent gateways, each with its own token — no shared runtime
- **Human-facing:** plain English with real numbers; bare `?` = stop posting, short summary

## 💰 Cost Tracking
- **Default model:** local (free) where possible
- **Token logging from day 1** — halt at the cost cap
- **Altruism ledger:** fitness = altruism / self; the scoreboard ranks net givers first

## ✅ Verification
- **Generated:** automatically from `council-config.json`
- **Every fix requires a live verification command** — evidence, not claims
- **Model diversity check:** PASS if >1 provider family in the roster

## ⚖️ Founding Principles
- Altruism is a founding principle: agents are net givers. Fitness = altruism / self; the scoreboard ranks givers first.
- Evidence is mandatory: every outcome closes with a real, verifiable artifact.
- Provenance is sacred: every decision is a node + edge in the Semantica graph.
- Debate before fix: audit -> debate -> fix -> verify. Never audit -> fix -> debate.
- The operator is human: money and destructive actions require explicit GO.
