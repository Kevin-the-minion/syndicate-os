# Drivers — standing automation

The fleet doesn't wait to be told. It runs **standing loops** — drivers that
wake on schedule, digest state, act, re-arm, and stay **silent unless they
changed something**. Two daily loops ship by default, exactly like the
production fleet's:

## 1. The daily driver (`driver-loop.sh` / `agents/cron/daily-driver.json`)

A standing lane-watcher: reads the federation board, picks an open tender in
its lane, claims it, dispatches its agent (`hermes chat -p <agent>`), posts
the outcome, and closes the tender with evidence. No open work → **silent
no-op** (watchdog discipline: no token spend, no noise).

## 2. The librarian (`librarian.sh` / `agents/cron/librarian.json`)

Daily memory pruning, the fleet's memory hygiene:

- **Prune** stale daily notes (`memories/YYYY-MM-DD.md`) beyond retention (30d)
- **Dedupe** repeated lines across memory files
- **Compact** oversized entries (truncate middle with a `[… pruned N chars …]` marker)
- **Consolidate** the week into `WEEKLY-<year>-W<week>.md` on the configured day
- **Re-index** the local memory search (`POST /index` on :7878) so pruning
  never leaves the search index stale
- Writes `memories/<date>.md` as today's sweep note

## How they ship

Two ways, pick one (or run both):

- **Agent-powered (recommended):** the profile distribution includes
  `agents/cron/daily-driver.json` and `agents/cron/librarian.json` — `hermes
  profile install` stages them as cron jobs automatically. The agent itself
  does the work with judgment.
- **Scripted:** run `drivers/driver-loop.sh` / `drivers/librarian.sh` from
  crontab (or `scripts/install-drivers.sh`), for zero-LLM operation.

## Driver discipline (from the production fleet)

1. **Digest state → act → re-arm.** Never act without reading the board first.
2. **Silent watchdogs.** No change, no output, no tokens. Noise is a bug.
3. **Evidence on every close.** A tender closed without evidence is a lie.
4. **Cost governance.** Local models by default; the librarian is deliberately
   cheap (pure shell unless the agent variant is used).
5. **Post to the board.** Coordination is public — if it didn't hit the board,
   it didn't happen.
