---
name: evidence-based-verification
description: Use when a claim, fix, or audit finding needs proof — verify with byte-level evidence.
---

# Evidence-Based Verification

A fix isn't done when it looks right in the tool display. It's done when the
artifact proves it. Adapted from the fleet's verification discipline.

## The gate

Before declaring anything done, run a check that produces **external
evidence**:

- **Files:** `stat` the mtime/size, `read` the content back, hash it.
- **Services:** hit the health endpoint, watch the HTTP status code.
- **APIs:** make the call and show the response body (not just "it worked").
- **Git:** `git log` / `git show` the commit that carries the change.

## The three questions

1. **Did it run?** Show the command and its exit code.
2. **Did it land?** Show the artifact on disk / in the API / in the repo.
3. **Did it survive?** Show it still works after a restart/re-run.

## Anti-patterns

- "I ran it and it worked" with no output — show the output.
- "The file was written" without reading it back.
- Trusting the tool's own summary instead of the underlying artifact.
- Reporting a remote operation's success from the local script's exit code —
  verify on the remote side.

## Minimum viable evidence

| Claim | Minimum evidence |
|---|---|
| "I changed X" | `git diff` + `git log -1` |
| "Service is up" | `curl -sf <health> -w '%{http_code}'` |
| "Data was written" | read it back from the store |
| "Deployed" | fetch the URL / check the process on the target |

If you cannot produce evidence for a claim, say so instead of implying success.
Blocked with evidence beats done with vibes.
