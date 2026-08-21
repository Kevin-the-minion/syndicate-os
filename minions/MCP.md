# MCP — how minions expose and consume tools

OpenClaw gives the fleet two native MCP modes. This file is the reference for both.

## Direction 1 — EXPOSE (minion as an MCP server)

A minion (full OpenClaw agent with its own gateway) exposes itself over MCP with
`openclaw mcp serve`. The external MCP client (Codex, Claude Code, another agent,
or a colleague's tool) spawns the bridge, and the minion's gateway-backed
conversations become MCP tools:

- `conversations_list` — list routed conversations
- `messages_read` — read transcript history
- `messages_send` — reply through the stored route
- `events_poll` / `events_wait` — live inbound events
- `permissions_list_open` / `permissions_respond` — approval requests

```bash
# on a minion: expose its gateway over stdio MCP
openclaw mcp serve --url wss://<minion-ip>:<port> --token-file ~/.openclaw/gateway.token
```

**Implication:** the federation becomes a *capability platform* — external tools
call *into* a minion. Cost: you open a surface; auth is the minion's existing
gateway token (no new secrets), and `messages_send` only ever replies through an
existing stored route (it cannot invent new routing).

## Direction 2 — CONSUME (minion as an MCP client)

A minion registers third-party MCP servers (memory-search, semantica, or anything
else) and its runtimes consume them as tools:

```bash
openclaw mcp add memory-search --url http://<host>:7878/mcp --transport streamable-http
openclaw mcp add semantica     --url http://<host>:8765/mcp --transport streamable-http
openclaw mcp probe memory-search --json   # prove it lists tools
```

**Implication:** minions gain capabilities by plugging into tools. Cost: external
deps + trust. This is what `agents/mcp.json` already sketches.

## Recommendation (v1)

Expose first (it is the differentiator), consume second (already demoed by
memory-search/semantica). Start read-only and high-value; no destructive tools in
v1. Auth = each minion's existing gateway token; external clients get a scoped
read-only token.
