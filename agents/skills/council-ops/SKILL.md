---
name: council-ops
description: Use when running or participating in a council audit (altered-frame review).
---

# Council Ops — altered-frame audits

The Syndicate runs audits through the psychedelic council: deliberately alien
cognitive frames, then every metaphor is cashed out into a plain, falsifiable
claim. The machinery lives in `council/` (this repo): 70+ frame prompts,
`scripts/trip`, and the three contract files.

## The contract (non-negotiable)
Every finding is written three ways:
```
FINDING <n>  [CONFIDENCE: high | medium | speculative]
  IMAGE: <the metaphor, in your frame>
  PLAIN: <flat technical claim that must stand alone>
  TEST:  <the command/observation that would prove it FALSE>
```
Rules: if PLAIN needs the metaphor to survive, delete the finding. No TEST =
mark speculative. Rate severity proportionally — a home lab is not a bank.
Close with THE ONE THING (or "nothing — this frame found no purchase").

## Run a trip
```bash
cd council
./scripts/trip --api --dose heroic "audit the repo for missing features"   # ollama backend
# or: OLLAMA_HOST=http://localhost:11434 OLLAMA_MODEL=llama3.2 ./scripts/trip --api --dose heroic "…"
```
`print` mode emits a prompt to paste into any chat. `api` mode calls a real
model per role (per-role temperature), then synthesises, then runs the
adversarial verification gate. Everything lands in `council/runs/`.

## Participate in a trip (as an agent)
- You get a frame + a scholar/problem. Stay in the frame while you think; the
  contract governs what you write down.
- Post findings to the board with `mission_id`; challengers and verifiers
  thread replies via `reply_to` (challenge -> defense -> ratify/revise/reject).
- Grading: diamond / quartz / glass / mirror / inflated. Cutting is permitted —
  cutting everything is permitted.

## Pitfalls
- The frames are a search strategy, not evidence. PLAIN lines that only make
  sense inside the metaphor are invented findings.
- A confident, vivid report is exactly what a hallucinating model produces.
  The TEST line is the only thing that makes it engineering.
- `scripts/trip --api` needs curl + jq; Ollama backend keeps everything local.
