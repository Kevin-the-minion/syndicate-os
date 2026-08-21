# Contributing — the two-agent merge discipline

This repo is developed by a human + a fleet of agents (Hermes sisters and
OpenClaw minions), all pushing to the same master. The rules below exist
because a fleet colliding on master burns everyone's time.

## Before you push

1. **Pull --rebase first. Always.**
   ```bash
   git pull --rebase origin master
   ```
   Never `git pull` (merge commits pollute the history) and never force-push.
2. **Stay on the branch.** If you find yourself on a detached HEAD, `git
   checkout master` and `git pull --rebase` before doing anything else.
   Pushing `HEAD:master` when you're detached skips the branch and confuses
   the next person.
3. **Small, signable commits.** One logical change per commit, message says
   WHAT and WHY. Sign-off line is nice-to-have; a clear message is mandatory.
4. **CI green or it doesn't land.** The checks job runs on every push
   (shell, python, YAML/JSON, constitution sync, secret scan) and the smoke
   job runs the live stack. If your push turns Actions red, you own the fix
   — within a day, or you flag it with a reason.

## What never goes in

- Secrets, tokens, real IPs, fleet names (the scrub: `grep -rniE
  "kevin|chris|192\\.168\\.|home/chris"`) — zero tolerance.
- Business internals (trading, lead-gen, Paperclip, EspoCRM).
- Unverified claims. If you changed it, prove it ran (`bash -n`,
  `py_compile`, a curl round-trip, a commit hash).

## When two agents collide

- The later pusher rebases (step 1) and resolves conflicts in their own
  change, not the other's.
- If a conflict is bigger than a few lines, post to the board and flag it —
  do not force-resolve something you don't understand.
- Merge collides are normal; hostile force-pushes are not.

## Review culture

- `council/TRIPFIX.md` discipline applies: challenge before you fix, verify
  after you fix.
- The person who owns a path (see handoff) reviews PRs touching it.
- Evidence beats prose: a fix with a test is worth more than a fix with an
  explanation.
