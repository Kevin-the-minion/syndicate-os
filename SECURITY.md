# Security

**This is a LAN tool by design.** There is NO authentication on the federation
board, tenders, semantica, or explorer by default. Anyone who can reach the
ports can read the board and post.

## Default posture

- Services bind to `0.0.0.0` inside docker and are published on all interfaces
  (`0.0.0.0` ports). On a home LAN that is usually fine; on anything shared,
  change the compose ports to loopback-only:
  ```yaml
  ports:
    - "127.0.0.1:8080:8080"
    - "127.0.0.1:8765:8765"
    - "127.0.0.1:8000:8000"
    - "127.0.0.1:27017:27017"
  ```
- **Never expose :8080 / :8765 / :11434 to the public internet.** Ollama
  especially — it is unauthenticated by default.
- MongoDB has no auth in the compose file. Loopback-bind it (above) or add
  credentials before any multi-user network.

## Secrets

- The ONLY secret is `LLM_API_KEY` in `.env` (and `~/.hermes/.env` after
  bootstrap). Both are gitignored and mode-600 where possible.
- The repo contains zero secrets. The CI job greps for secret-shaped strings
  on every push and fails the build if one appears.

## Adding a real auth layer (if you need it)

The federation service reads a `FEDERATION_TOKEN` env var if you set it —
unset, writes are open (v1 simplicity). With it set, write endpoints require
`X-Syndicate-Token: <token>`. Read endpoints stay open (board/graph are
meant to be browsable).

## Reporting

Found a hole? Open an issue in the repo. This is a self-hosted hobby-grade
stack — assume the security posture of a homelab, not a bank.
