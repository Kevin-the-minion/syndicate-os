# 📎 Paperclip — control-plane provisioning

[Paperclip](https://paperclip.ing) is the coordination layer: companies, agents,
issues, approvals, heartbeats, and the audit trail every harness reports into.
Syndicate OS treats it as an optional-but-recommended fifth component — the
stack's *control plane* on top of the four runtimes (🦉 Hermes, 🍌 OpenClaw,
🧰 OpenHarness, 📡 Waku).

## Two ways to run

1. **Join an existing company** (default — matches the homelab fleet).
   Point `PAPERCLIP_API_URL` at any reachable control plane (e.g.
   `http://192.168.0.212:3100`), then either:
   - **First join:** set `PAPERCLIP_INVITE=pcp_invite_...` and run
     `./paperclip/provision-agents.sh` — it accepts the invite and prints the
     one-time `claimSecret` (save it immediately, it is shown exactly once).
   - **Register mode:** set `PAPERCLIP_API_KEY` + `PAPERCLIP_COMPANY_ID` and
     run the script — it registers every seeded agent (`AGENT_NAMES`) into the
     company via `agent-hires` with the `hermes_gateway` adapter.
2. **Self-host the server.** Paperclip ships as a vendor API + Postgres; plug
   your own server image/CT behind `PAPERCLIP_API_URL` — the provisioning
   script only talks to `/api/*` and does not care what hosts it.

## Env vars (all optional unless enabling)

| Var | Meaning |
|---|---|
| `PAPERCLIP_ENABLE` | `1` = bootstrap runs `provision-agents.sh` |
| `PAPERCLIP_API_URL` | control-plane base URL, e.g. `http://192.168.0.212:3100` |
| `PAPERCLIP_INVITE` | one-time invite id for the join flow |
| `PAPERCLIP_API_KEY` | long-lived agent key (register/operate mode) |
| `PAPERCLIP_COMPANY_ID` | company to register agents into |
| `PAPERCLIP_CONFIRM` | `1` required for REGISTER mode (creates agents — guards against ambient env) |
| `HERMES_API_URL` | this box's Hermes API server (what Paperclip calls back) |
| `HERMES_API_KEY` | this box's `API_SERVER_KEY` (NOT a Paperclip key) |

## Becoming dispatchable

Registration ≠ enablement. For Paperclip to dispatch to an agent, that box must
also run the Hermes API server + gateway with the matching key (see the
`paperclip-agent-onboarding` skill: `.env` API-server vars + `systemctl reload
hermes-gateway`). The script prints per-agent status; wiring the boxes is the
operator step after provisioning.

## Files

- `provision-agents.sh` — idempotent join/register for every seeded agent.
- `verify.sh` — smoke-tests `/api/health` when `PAPERCLIP_API_URL` is set.
