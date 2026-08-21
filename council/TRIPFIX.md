# Council Trip-Fix Discipline — v4.5

> The full audit-and-repair loop: debate before fix, skeptic first, verifier
> after fixes, TRIO quorum, minimum five participants, cost tracing from day
> one. Genericized from a production fleet's council playbook.

## When to use

When the operator says any of:
- "Audit [project] and fix what you find"
- "Deep dive [X] with the council"
- "Trip on this and then fix it"
- "Full council audit + fix blitz"

## 🔴 Hard rules

1. **Minimum 5 agents per council.** Never below 5. No exception.
2. **Never auto-skip the trip phase.** Always ask the operator: "Trip on these findings?"
3. **TRIO mandatory.** Every council convening includes the skeptic, the
   verifier, and a UX voice. Minimum 5 participants.
4. **Skeptic mandatory in Phase 1.** Not optional, not Phase 3. Phase 1.
5. **Verifier mandatory after fixes.** Every fix must have a live verification command.
6. **Debate before fix.** Audit → Debate → Fix → Verify. Not Audit → Fix → Debate.
7. **Pre-Phase 0 non-negotiable.** Verify old fixes before auditing new code.
8. **Phase 0 non-negotiable.** Historical context in every brief.
9. **Phase 2.5 non-negotiable.** Strategic harvest before any fixes.
10. **Shared swarm state for parallel work.** No blind parallel swarms.
11. **Council agents are first-class agents.** Convene them as themselves —
    via their inboxes or your harness's agent-wake mechanism — never as
    anonymous sub-processes wearing an impersonation label. A stand-in that
    cannot receive messages, reply, or be held accountable is not a council
    member.
12. **Cost tracing from day 1.** Log tokens and spend per phase, per agent.
13. **Secret rotation protocol.** Never change secrets without announcing to
    all consumers first.

## Before anything: three questions for the operator

1. **How many agents?** (minimum 5; a full council is ~10)
2. **What kind of audit?** — business, code, architecture, security,
   performance, infrastructure, UX, data, network, config, or full council.
   TRIO included regardless.
3. **How deep should the trip go?** — microdose (3–4 frames), standard (5–8),
   heroic (8–12).

## Convening conventions

- **Historical context first.** The first ~1000 tokens of every brief are the
  project's history: prior fixes, prior directives, prior audits, current
  backlog, current live state. An agent that re-discovers what the fleet
  already knows is burning tokens, not adding value.
- **Board as primary communication.** Debates, challenges, and verdicts post
  to the board, by name, with references. Inbox is for routing; the board is
  the record.
- **Verify context landed.** Before Phase 1 proceeds, the lead confirms each
  agent actually engaged with the historical pack.

## 🔄 Cross-swarm coordination

When two swarms touch the same repo concurrently, both MUST share state via
`.swarm-state.json` at the repo root:

```json
{
  "active_swarms": [
    {"id": "swarm-a", "files": ["src/decide.py"], "started": "2026-08-09T21:00:00Z"}
  ],
  "file_locks": {"src/decide.py": "swarm-a"}
}
```

Rules:
1. Check `.swarm-state.json` before modifying any file.
2. If another swarm owns the file, post to the board and wait.
3. No response in 5 minutes → proceed, flagged as POTENTIAL CONFLICT.
4. Release locks when done. Both swarms post to the SAME board.

**Secret rotation protocol:** announce to ALL consumers ("rotation in 5
minutes") → wait → rotate → confirm. Never silent.

## 🔍 Pre-Phase 0: fix verification

Before auditing new code, verify that previously-applied fixes are still live.

1. **Inventory:** extract every FIXED/DEPLOYED item from prior audits.
2. **Convene 2–3 verification agents** whose only job is to confirm each fix
   in the running system. Each check includes: what was fixed, what the live
   system actually does, and the command that proves it.
3. **Regression gate:** any P0/P1 fix found regressed → re-deploy BEFORE
   Phase 1. All verified → proceed.

## 🏛️ Phase 0: historical context (mandatory)

Assemble the briefing pack (Pre-Phase 0 results, prior directives, prior audit
syntheses, prior trip convergence maps, backlog, live state) and inject it
into every convening. The lead verifies engagement before proceeding.

## 📋 Phase 1: audit + skeptic + verifier + debate

**1a — Audit.** Convene N agents with assigned frames. Every finding carries
confidence and the IMAGE/PLAIN/TEST contract (a finding whose PLAIN line needs
its metaphor is deleted).

**1b — Skeptic (mandatory, Phase 1).** Reads all findings, challenges every
P0/P1 with evidence, hunts what everyone missed, and challenges claimed fixes
with live data. Show math, not vibes. The skeptic routinely finds more real
bugs than the auditors — that is the point.

**1c — Verifier (mandatory, Phase 1).** Checks LIVE behavior, not code text.
Reports discrepancies: "Agent X claimed Y, live system does Z." Every finding
that can be checked live gets a verification command.

**1d — Debate (before fix).** 3–5 agents read the findings, the skeptic's
challenges, and the verifier's live checks, then debate: which findings are
real, which are false positives, what is the optimal fix. Consensus is
documented; disagreement is documented too — both on the board.

**1e — Report.** The lead compiles findings + challenges + live checks +
debate consensus into a verdict: FIX / SKIP / INVESTIGATE.

### 🚪 Gate 1: present to the operator
> "Audit + debate complete. N findings verified, M challenged. X need fixing.
> Trip on these findings?"

## 🌀 Phase 2: meta-analysis trip

After Gate 1 approval. Standard trip format, dose per operator selection,
frames assigned from the council prompt library.

### 🚪 Gate 2: present to the operator
> "Trip done. N strategic directives, M tactical fixes. Implement?"

## 🎯 Phase 2.5: strategic harvest (mandatory)

Extract strategic directives from the trip synthesis BEFORE any code fixes.
Tactical fixes without the strategic context are motion, not progress.

## 🔧 Phase 3: tactical fixes + verification

**3a — Prioritize** directives with the operator: DO NOW / SCHEDULE / WATCH /
REFERENCE.

**3b — Fix.** Fix agents get full historical context + strategic directives.
File ownership is explicit (one file, one owner, via `.swarm-state.json`).
Board as primary communication.

**3c — Verification round (mandatory).** After ALL fixes, the verifier checks
every fix with a live command. Each fix must have shipped with: what changed,
how to verify (specific command), and the expected output. Verdicts: ✅
verified / ❌ claimed but not working / ⚠️ unverifiable and why.

**3d — Persistence.** Push all reports to the repo; inject key findings into
the fleet memory layer so the next council starts from them.

## Key rules summary

1. Minimum 5 agents. Hard rule.
2. Never auto-skip the trip. Always ask the operator.
3. TRIO mandatory: skeptic + verifier + UX voice.
4. Skeptic mandatory in Phase 1. Not optional.
5. Verifier mandatory after fixes — live behavior, not code claims.
6. Debate before fix. Audit → Debate → Fix → Verify.
7. Pre-Phase 0 non-negotiable: verify old fixes first.
8. Phase 0 non-negotiable: historical context in every brief.
9. Phase 2.5 non-negotiable: strategic harvest before fixes.
10. Shared swarm state for parallel work.
11. Cost tracing from day 1.
12. Secret rotation is announced, never silent.
13. Board as primary communication.
14. Every fix ships with a verification command.
15. Trust but verify. Agents misreport — catch it with live checks.

## Verification checklist

- [ ] Audit type + dose agreed with the operator
- [ ] TRIO + skeptic confirmed; agent count ≥ 5
- [ ] Pre-Phase 0: fix inventory built, regressions checked
- [ ] Phase 0: historical pack injected into all briefs
- [ ] Phase 1a: audit complete (IMAGE/PLAIN/TEST contract enforced)
- [ ] Phase 1b: skeptic challenged all P0/P1 findings
- [ ] Phase 1c: verifier checked live behavior
- [ ] Phase 1d: debate round ran, consensus/disagreement on the board
- [ ] Phase 1e: report compiled
- [ ] 🚪 Gate 1: presented to the operator
- [ ] Phase 2: trip completed
- [ ] 🚪 Gate 2: presented to the operator
- [ ] Phase 2.5: strategic directives extracted
- [ ] Phase 3a: directives prioritized
- [ ] Phase 3b: fixes deployed with file ownership
- [ ] Phase 3c: verifier checked ALL fixes with live commands
- [ ] Phase 3d: reports pushed, memory updated
- [ ] `.swarm-state.json` consistent (parallel swarms only)
- [ ] Cost tracing on (all phases)
