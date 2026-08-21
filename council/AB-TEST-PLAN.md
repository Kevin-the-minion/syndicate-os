# A/B Test Run Plan — does the trip actually beat plain analysis?

The whole council toolkit rests on one claim: **forcing a model through an
alien representational frame surfaces correct findings that a straight expert
prompt misses.** The `ab-test` harness exists to settle it. This document is
the ready-to-execute run plan: the problem set, the judge protocol, and the
pass criteria. The operator green-lights the run; everything here is prepared.

## The question, precisely

> Does the trip arm produce more **non-obvious-and-correct** findings than a
> baseline expert prompt on the same problem, **without producing more false
> alarms?**

If yes → real result, write it up with numbers, replace the UNTESTED caveat
in `council/README.md`.
If no → this is a prompt pack, and a fine one. Say so and stop claiming a
mechanism.
If the trip produces more findings but no more *correct* ones → we built a
machine for generating plausible text. That is the outcome to watch for.

## Mechanics

The harness already does the right things:

- Both arms run on the same problem; arms are labelled A/B at random; the
  key (`.key`) is sealed until scoring is done.
- Per-finding scoring: correct / actionable / non-obvious / would-you-act-on-it,
  plus a false-alarm count per arm.
- `--reveal` only after the score sheet is filled in.

Run rules (non-negotiable):

1. **Same model both arms.** Default setup already does this: baseline and
   trip both default to Anthropic `claude-sonnet-5` in `--api` mode. If you
   change one arm's model, change both.
2. **Fresh context per arm.** Run each arm in a fresh session — a shared
   history leaks the first arm's answers into the second and voids the run.
3. **Score blind, reveal last.** Fill the entire score sheet before `--reveal`.
4. **Same dose for all 10 problems** — `standard` (5–8 frames). Dose is part
   of the treatment; don't vary it mid-run.
5. **One run per problem, no cherry-picking.** A run that errors gets redone
   with the same settings; a run you don't like gets reported anyway.

Commands:

```bash
cd council
ANTHROPIC_API_KEY=… ./scripts/ab-test --api --dose standard "<problem>"
# score arm-A.md vs arm-B.md blind…
./scripts/ab-test --reveal runs/ab-<stamp>
```

(Print mode works too: `./scripts/ab-test --dose standard "<problem>"` emits
two prompt files to run manually — still blind-score and reveal last.)

## The 10-problem set

Diverse lanes, each a small self-contained system with seeded defects. Use
these statements verbatim — they are written so findings can be judged
true/false against the seeded ground truth (below, sealed section).

1. **Auth endpoint** — "A service exposes POST /auth/token that returns a
   session token for valid credentials. The service runs behind a reverse
   proxy. Nothing else is known. Audit this design for security problems."
2. **Webhook retries** — "A delivery service retries failed webhook calls to
   partner systems. Partners are complaining about storms of duplicate
   deliveries after their brief outages. Audit the retry design."
3. **Config migration** — "A migration script rewrites a service's YAML
   config in place when the schema version changes. After a migration, two
   operators report their hand-set tuning values disappeared. Audit the
   script design."
4. **SQLite concurrency** — "An ingestion worker writes to a SQLite database
   from 8 threads; reads come from a web API. Under load the API starts
   timing out. Audit the storage design."
5. **Embedding cache** — "A memory-search service caches document embeddings
   keyed by document ID. The embedding model was upgraded, and search
   quality dropped. Audit the cache design."
6. **Container limits** — "A docker-compose stack runs 6 services on one
   host, none with resource limits. A periodic batch job occasionally makes
   the API unresponsive. Audit the deployment config."
7. **Import-time cost** — "A CLI tool takes 4 seconds to print --help. The
   codebase imports a web framework at module load. Audit the startup
   design."
8. **Deferred imports** — "A Python package uses function-level imports to
   'solve' a circular import between its core and plugin layers. New
   contributors keep reintroducing the cycle. Audit the architecture."
9. **Env parsing** — "A deploy script reads a HOST=host:port value from a
   dotenv file and passes it to a tool that resolves DNS. Sometimes the
   tool reports 'name or service not known' for a host that pings fine.
   Audit the parsing."
10. **Unbounded logs** — "A long-running worker appends to a single log file
    with no rotation. After 90 days the host disk fills and the app dies.
    Audit the logging design."

## Judge protocol

Two judges, both blind to the arm labels:

- **Human judge (required):** the operator. The human's per-finding verdicts
  are the final authority.
- **Model judge (recommended):** a capable model from a **different family**
  than the arms' model (e.g., if arms run on Anthropic, judge with a strong
  OpenAI or DeepSeek model). Same score sheet, scored independently.

Protocol:

1. Both judges fill the score sheet without seeing `.key`.
2. Compare verdicts per finding. On disagreement for the **non-obvious**
   column (the column the hypothesis lives on), the human re-reads the
   finding and settles it.
3. Record inter-judge agreement on the correct/non-obvious columns in the
   run notes — if judges disagree wildly, the score sheet itself needs work.

## Pass criteria

For each problem, count the trip arm's win or loss on the primary metric:

- **Primary metric:** number of findings that are **both correct and
  non-obvious** (the "would a competent engineer get there in minutes" test).

Verdict after 10 problems:

- **Claim SUPPORTED:** trip wins the primary metric on **≥ 8 of 10**
  problems **and** the trip arm's total false alarms are no more than
  baseline + 1. (8/10 with n=10 is the practical threshold; 9/10 is
  formally significant at p ≈ 0.01 under a fair coin.)
- **Claim REJECTED:** trip fails to beat baseline on total correct findings
  across all problems.
- **Plausible-text outcome:** trip produces more findings but fewer/no more
  correct ones, or false alarms exceed baseline by 2+ total → the frames add
  verbosity, not truth. Write that up honestly.

Anything between SUPPORTED and REJECTED (e.g., 6–7/10) → **MIXED**: report
per-lane results (which domains the frames help on) and say so in the
README. Partial results are results.

## Confounds to declare in the write-up

- **Temperature:** baseline runs at 0.60; the trip varies temperature per
  role by design. Declare it as part of the treatment.
- **Prompt length:** frame prompts are longer than the baseline prompt.
  Length alone can improve output; a strict follow-up can pad the baseline.
- **Effort:** both arms get the same max tokens.

## After the run

- Aggregate the 10 score sheets into one table: per-problem winner on the
  primary metric, per-arm correct / non-obvious / false-alarm totals.
- Replace the "UNTESTED hypothesis" caveat in `council/README.md` with the
  verdict and the numbers, whichever way it lands.
- Keep the raw runs in `council/runs/` — the sealed keys make them
  auditable.

---

**Sealed section — DO NOT READ BEFORE SCORING.** The seeded defects below
are the ground truth for judging "correct". The human judge may consult
them only after filling in the score sheet (before `--reveal` is acceptable
for correctness settling; after scoring is cleaner).

1. Auth: no rate limit on the token endpoint; token not tied to a client
   fingerprint; no max-token count. Non-obvious angle: the reverse proxy
   forwards raw client IPs only on a non-default header, so naive rate
   limiting would throttle the proxy, not the attacker.
2. Webhooks: fixed-interval retry without exponential backoff or jitter;
   retries are not idempotent-keyed. Non-obvious angle: partners' "brief
   outage" means their load balancer held connections open, so the service's
   timeouts fired while the partner still processed the request — retries
   duplicate work that was never actually lost.
3. Migration: the script writes a fresh default config over the old file
   instead of merging; backup is made only if a flag is passed. Non-obvious
   angle: schema version is stored inside the same file, so a partially
   written file on crash leaves the version claiming "migrated" while the
   body is defaults.
4. SQLite: default journal mode (no WAL) — writers block readers; no busy
   timeout; connection-per-thread without a write queue. Non-obvious angle:
   the API's read timeouts are caused by writer locks, not the queries.
5. Cache: keyed by document ID only — model version not in the key, so stale
   embeddings from the old model survive. Non-obvious angle: the upgrade
   also changed vector dimension, and mixed-dimension vectors degrade
   similarity scores silently instead of erroring.
6. Compose: no mem/cpu limits → the batch job drives the kernel into memory
   pressure and OOM-kills API workers. Non-obvious angle: adding limits to
   one service can shift the OOM victim to another; the fix is limits +
   health-based restart policies.
7. Imports: heavy framework imported at module scope for one optional
   subcommand. Non-obvious angle: lazy imports fix startup but hide
   dependency errors until first use — needs an import smoke test in CI.
8. Deferred imports: masking a real layering violation; the plugin layer
   imports core and core imports plugin at call time. Non-obvious angle: the
   "right" fix is dependency inversion (interfaces in a third module), not
   more deferred imports.
9. Env: values are read with surrounding quotes intact ("host:port"), so DNS
   receives the quoted literal; ping works because the shell strips quotes,
   masking the bug. Non-obvious angle: the same dotenv is consumed by two
   parsers with different quoting semantics — the fix is stripping once at
   load, not at each consumer.
10. Logs: unbounded append, no rotation/size cap. Non-obvious angle: the
    real fix is structured logs shipped off-box or logrotate with copytruncate
    — naive `truncate` in place corrupts the in-flight write and loses the
    very lines that diagnose the outage.
