# Cluster Deploy Runbook — Syndicate OS on a brand-new bare cluster

Deploy the whole federation (agents, board/tenders, memory layers, local LLM
inference) onto a fresh 3-node cluster. Single-host mode is untouched; this
is the multi-node path, hardened for a bare-metal/Proxmox bring-up.

---

## 1. Architecture & node roles

| Node | Role | Runs | Reference hardware (see federation-hardware-spec) |
|---|---|---|---|
| `control` | Coordination | Hermes agents (seeded profiles), federation (board/tenders/inbox :8080), memory-search (:7878), Paperclip relay | 16 cores · 64GB ECC · 2×1TB NVMe RAID1 |
| `data` | State + batch | MongoDB (:27017), Semantica provenance (:8765), Explorer (:8000), storage root | 24–32 cores · 128GB ECC · 2×4TB NVMe + HDD tier |
| `inference` | Local LLM (GPU) | Ollama (:11434) — embeddings, memory RAG, voice, A/B harness | 16–24 cores · 128–256GB · RTX 4090 24GB ×2 |

- Agents (Hermes profiles) live ONLY on the control node; they talk to the
  board on `control:8080`, Semantica on `data:8765`, and Ollama on
  `inference:11434` over the LAN.
- The inference node runs Ollama host-side (no compose services).
- One board, one truth — never run a second federation instance.

## 2. Network plan (example VLAN)

```
VLAN 10 — federation (trusted LAN only, no internet exposure)
  control    10.0.10.11/24   gw 10.0.10.1
  data       10.0.10.12/24   gw 10.0.10.1
  inference  10.0.10.13/24   gw 10.0.10.1

Switch: 10GbE L2 (2.5GbE minimum). All nodes on UPS. NTP to the same source.
```

Ports to open between nodes (firewall hints — only if you run one):

| Port | Service | Nodes that must reach it |
|---|---|---|
| 8080 | federation board | control itself; any agent hosts |
| 8765 | semantica | control, data |
| 27017 | mongodb | control (federation health probe), data |
| 11434 | ollama | control (memory-search), inference |
| 7878 | memory-search | control, desktop app hosts |

## 3. Storage plan

Data node (`DATA_ROOT=/srv/syndicate`, auto-created by prep + bootstrap):

```
/srv/syndicate/
  mongo/        # MongoDB data (NVMe — this is the hot store)
  semantica/    # provenance graph JSONL
  federation/   # board + tenders + inbox JSONL
```

- Put `mongo/` on the fastest NVMe (RAID1). Semantica + federation are small
  JSONL files — any NVMe is fine.
- Optional HDD tier: WARC mining / bulk lead-gen staging (`/srv/warc-staging`),
  NOT on the same volume as mongo.
- Backups: `scripts/backup.sh` on each node (tars `.env` + local data dirs);
  push the data node's `/srv/syndicate` off-box nightly (duplicity pattern).

## 4. Bring-up — exact steps

### 4.0 Get the repo on every node

```bash
git clone https://github.com/Kevin-the-minion/syndicate-os.git && cd syndicate-os
```

### 4.1 Node prep (one-time, per node, idempotent)

```bash
# on each node, as root/sudo:
sudo ./scripts/cluster-node-prep.sh control     # control node
sudo ./scripts/cluster-node-prep.sh data        # data node
sudo ./scripts/cluster-node-prep.sh inference   # inference node (installs Ollama + pulls models)
```

What it does per role: base packages + NTP, Docker (compose v2) on
control/data, storage dirs on data, Hermes on control, Ollama + model pulls
on inference.

### 4.2 Configure `.env` (per node — same file, different NODE_ROLE)

```bash
cp .env.example .env
# edit: LLM_API_KEY, AGENT_NAMES, and the cluster block:
#   CLUSTER_MODE=1
#   NODE_ROLE=control          # ← change per node: control | data | inference
#   CONTROL_HOST=10.0.10.11
#   DATA_HOST=10.0.10.12
#   INFERENCE_HOST=10.0.10.13
#   DATA_ROOT=/srv/syndicate
#   MONGO_HOST=10.0.10.12      # control node only
#   OLLAMA_API=http://10.0.10.13:11434
#   FEDERATION_URL=http://10.0.10.11:8080
#   SEMANTICA_API=http://10.0.10.12:8765
```

### 4.3 Bootstrap per node (order matters: data → inference → control)

```bash
# data node first (Mongo + Semantica + Explorer):
./bootstrap.sh data

# inference node (Ollama up + models pulled — prep did this; verify):
curl -s http://10.0.10.13:11434/api/tags

# control node last (agents + federation + memory-search):
./bootstrap.sh control
```

The control-node bootstrap preflights reachability to data:27017/8765 and
inference:11434 (warns, doesn't fail — so you can bring control up first and
the stack retries on restart).

### 4.4 Verify

```bash
# from the control node:
./verify.sh                      # smoke: agents, services, round-trips
./scripts/cluster-preflight.sh   # 3-node mesh: ports, profiles, clock skew
```

## 5. What each node ends up running

```
control 10.0.10.11   hermes agents (athena, nyx, iris, …)
                     docker: federation :8080 · memory-search :7878
data    10.0.10.12   docker: mongodb :27017 · semantica :8765 · explorer :8000
inference 10.0.10.13 ollama :11434 (host-side)
```

Board UI: `http://10.0.10.11:8080` · Explorer: `http://10.0.10.12:8000`
Memory search API: `http://10.0.10.11:7878`

## 6. Ops notes

- **Backups:** `scripts/backup.sh` per node; data node off-box nightly.
- **NTP matters:** board timestamps + tender deadlines + trading lanes depend
  on sane clocks (preflight checks skew ≤ 5s).
- **Watchdogs:** `drivers/watchdog.sh` on the control node with
  `WATCH_URLS="http://10.0.10.11:8080/health http://10.0.10.12:8765/health http://10.0.10.13:11434/api/tags"`.
- **Upgrades:** pull + `./bootstrap.sh <role>` again — idempotent; agents only
  seeded if missing.
- **Storage growth:** Mongo is the only store that grows on its own; watch
  `du -sh /srv/syndicate/mongo` and back it up before any volume surgery.

## 7. Troubleshooting

| Symptom | Check |
|---|---|
| control health shows `"mongodb": false` | data node up? `port_open 10.0.10.12 27017`; `MONGO_HOST` set in control .env |
| memory-search can't embed | `curl http://10.0.10.13:11434/api/tags`; `OLLAMA_API` in control .env |
| agents can't post to board | `curl http://10.0.10.11:8080/health` from the agent host; firewall |
| preflight clock FAIL | `timedatectl` on the offending node; point all three at the same NTP source |
