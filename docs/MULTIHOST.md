# Multi-host — from one box to a fleet of boxes

The repo's default is **single-host**: agents + federation + memory on one
machine. The production fleet this was distilled from spans **ten-plus hosts**
(sisters on separate Proxmox containers, minions on their own boxes). This
document is the pattern for going multi-host without breaking the model.

## The invariant: the federation is the only shared thing

Nothing else is shared. Each host runs its own agents (Hermes profiles) and,
optionally, its own minions (OpenClaw). The federation (board/tenders/inbox/
provenance) is the single coordination surface, reachable over the LAN.

```
host A (athena, nyx) ──┐
host B (iris, hestia) ─┼──► federation (:8080) + semantica (:8765) on host 0
host C (minions)     ──┘
```

## The pattern (genericized from the fleet's sister provisioning)

1. **Designate host 0** — runs the docker stack (federation, semantica,
   memory-search, mongo). Everything else points at it.
2. **Install Hermes on each host** (`curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash`).
3. **Seed agents per host** — same `agents/` distribution:
   `hermes profile install ./agents --name athena`, etc. Give each host the
   agents it can actually run (CPU/RAM budget per host).
4. **Point every host at the federation** — set `FEDERATION_URL` /
   `SEMANTICA_API` in each host's `.env` to host 0's address
   (`http://<host0>:8080`, `http://<host0>:8765`). The agents don't care where
   the board lives.
5. **Dispatch across hosts** — dispatch is `hermes chat -p <agent>` on the
   host that owns the agent. From host 0, either:
   - SSH to the owning host and run the command, or
   - keep a per-host helper: `ssh hostB 'hermes chat -p iris -q "<prompt>"'`
   The federation's `/dispatch` stays single-host by design; multi-host
   dispatch is a thin SSH wrapper (the fleet's actual pattern).
6. **Per-host watchdogs** — run `drivers/watchdog.sh` on every host with
   `WATCH_URLS="http://<host0>:8080/health http://<host0>:8765/health"` so a
   host that loses the federation alerts instead of silently degrading.

## What NOT to do

- Don't run multiple federation instances and try to sync them — there's one
  board, one truth. If you need HA later, that's a separate design.
- Don't share agent profiles across hosts (each agent is owned by its host).
- Don't expose the federation beyond your LAN; multi-host means LAN-multi-host
  (or a VPN), not internet-multi-host.

## Remote agent note

If you want the desktop-app experience of "all agents everywhere in one UI",
the fleet uses the Hermes desktop app's multi-connection registry pointed at
each host's dashboard (see `desktop/register-connections.py` for the pattern).
