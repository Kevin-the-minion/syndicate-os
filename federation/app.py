#!/usr/bin/env python3
"""Federation — the Syndicate OS control plane.

Board + tender market + dispatch + outcomes + provenance hooks. The API shape
mirrors the operator's production bridge (hermes-bridge.py): /post, /board,
/tenders, /dispatch, /ack, /outcomes, /graph, /semantica/record.

Dispatch runs REAL agents: a tender is minted, dispatched to a Hermes profile
(`hermes chat -p <agent> -q <prompt>`), and the outcome lands on the board and
in the Semantica provenance graph.

MIT License.
"""
import json
import os
import subprocess
import time
import uuid
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import Depends, FastAPI, Header, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, ConfigDict, Field

PORT = int(os.environ.get("FEDERATION_PORT", "8080"))
DATA_DIR = Path(os.environ.get("DATA_DIR", "./data"))
SEMANTICA_API = os.environ.get("SEMANTICA_API", "http://localhost:8765")
HERMES_BIN = os.environ.get("HERMES_BIN", "hermes")
DISPATCH_TIMEOUT = int(os.environ.get("DISPATCH_TIMEOUT", "300"))
FEDERATION_TOKEN = os.environ.get("FEDERATION_TOKEN", "")

DATA_DIR.mkdir(parents=True, exist_ok=True)
BOARD_PATH = DATA_DIR / "board.jsonl"
TENDERS_PATH = DATA_DIR / "tenders.json"
OUTCOMES_PATH = DATA_DIR / "outcomes.jsonl"
ACKS_PATH = DATA_DIR / "acks.jsonl"
EDGES_PATH = DATA_DIR / "edges.json"
ALTRUISM_PATH = DATA_DIR / "altruism.json"

app = FastAPI(title="Syndicate OS Federation", version="0.1.1")
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)


# ── optional write-auth ────────────────────────────────────────────────────
# If FEDERATION_TOKEN is set, write endpoints require the header. Unset =
# open board (v1 LAN default). Read endpoints stay open for browsing.
def require_write_auth(x_syndicate_token: str = Header(default="")):
    if FEDERATION_TOKEN and x_syndicate_token != FEDERATION_TOKEN:
        raise HTTPException(401, "X-Syndicate-Token missing or wrong")


# ── helpers ────────────────────────────────────────────────────────────────

def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _append(path: Path, obj: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "a") as f:
        f.write(json.dumps(obj) + "\n")


def _read_jsonl(path: Path) -> List[dict]:
    if not path.exists():
        return []
    out = []
    for line in path.read_text().splitlines():
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return out


def _load_json(path: Path, default):
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return default


def _save_json(path: Path, obj) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2))


def _semantica(payload: dict) -> dict:
    """Best-effort record into the provenance graph. Never blocks the flow."""
    try:
        req = urllib.request.Request(
            f"{SEMANTICA_API}/record_decision",
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read().decode())
    except Exception as e:  # noqa: BLE001
        return {"ok": False, "error": str(e)[:160]}


def _tenders() -> Dict[str, dict]:
    return _load_json(TENDERS_PATH, {})


def _tender_seq(tenders: Dict[str, dict]) -> int:
    return max([int(t["id"].split("-")[1]) for t in tenders.values()], default=0)


def _list_agents() -> List[str]:
    """Hermes profiles on this host (the fleet roster)."""
    try:
        out = subprocess.run(
            [HERMES_BIN, "profile", "list"],
            capture_output=True, text=True, timeout=15,
        ).stdout
        names: List[str] = []
        for ln in out.splitlines():
            ln = ln.strip()
            if not ln or ln.startswith("Profile") or "──" in ln:
                continue
            tok = ln.split()[0].lstrip("◆* ")
            if tok and tok not in names:
                names.append(tok)
        return names[:50]
    except Exception:  # noqa: BLE001
        return []


# ── altruism ledger ────────────────────────────────────────────────────────
# Founding principle: agents are net givers. Every action that helps the
# network earns altruism credits; work you do for yourself earns self credits.
# fitness = altruism / max(1, self)  → ≥1 means a net giver.
#
#  +1 altruism  mint a tender (opens work to everyone)
#  +2 altruism  close a tender you did NOT create (did the network's work)
#  +1 self      close a tender you DID create (did your own work)
#  +0.5 altruism award a tender to someone else / ack a mission


def _altruism() -> Dict[str, dict]:
    return _load_json(ALTRUISM_PATH, {})


def _save_altruism(ledger: Dict[str, dict]) -> None:
    _save_json(ALTRUISM_PATH, ledger)


def _credit(agent: str, kind: str, amount: float, note: str = "") -> None:
    """kind: 'altruism' | 'self'"""
    ledger = _altruism()
    entry = ledger.setdefault(agent, {"altruism": 0.0, "self": 0.0, "events": 0})
    entry[kind] = round(entry.get(kind, 0.0) + amount, 2)
    entry["events"] = entry.get("events", 0) + 1
    entry["last"] = {"amount": amount, "kind": kind, "note": note, "ts": _now()}
    _save_altruism(ledger)


def _scoreboard() -> List[dict]:
    ledger = _altruism()
    rows = []
    for agent, e in ledger.items():
        altruism = e.get("altruism", 0.0)
        self_ = e.get("self", 0.0)
        fitness = round(altruism / max(1.0, self_), 2)
        rows.append({
            "agent": agent,
            "altruism": altruism,
            "self": self_,
            "fitness": fitness,
            "net_giver": altruism >= self_,
            "events": e.get("events", 0),
        })
    return sorted(rows, key=lambda r: (-r["fitness"], -r["altruism"]))


# ── request models ─────────────────────────────────────────────────────────

class PostIn(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    from_: str = Field(alias="from")
    to: str = "board"
    message: str
    tags: List[str] = []
    mission_id: str = ""
    reply_to: str = ""


class TenderIn(BaseModel):
    title: str
    lane: str = "general"
    item: str = ""
    acceptance: str = ""
    by: str = ""


class TenderAction(BaseModel):
    agent: str
    by: str = ""


class TenderClose(BaseModel):
    evidence: str
    agent: str = ""


class DispatchIn(BaseModel):
    agent: str
    prompt: str


class AckIn(BaseModel):
    agent: str
    mission_id: str = ""


class EdgeIn(BaseModel):
    source: str
    target: str
    label: str = "relates"


class RecordIn(BaseModel):
    category: str = "decision"
    scenario: str
    reasoning: str = ""
    outcome: str = ""
    confidence: float = 0.9
    decision_maker: str = "federation"
    entities: List[str] = []
    metadata: Dict[str, Any] = {}


# ── board ──────────────────────────────────────────────────────────────────

@app.post("/post", dependencies=[Depends(require_write_auth)])
def post(p: PostIn):
    rec = {
        "id": uuid.uuid4().hex[:12],
        "from": p.from_,
        "to": p.to or "board",
        "message": p.message,
        "tags": p.tags,
        "mission_id": p.mission_id,
        "reply_to": p.reply_to,
        "ts": _now(),
    }
    _append(BOARD_PATH, rec)
    return {"status": "posted", "id": rec["id"]}


@app.get("/board")
def board(limit: int = Query(50, le=500)):
    posts = _read_jsonl(BOARD_PATH)
    return {"count": len(posts), "messages": posts[-limit:][::-1]}


@app.get("/board/threads")
def threads(limit: int = Query(50, le=500)):
    posts = _read_jsonl(BOARD_PATH)[-limit:]
    roots, by_id = [], {}
    for p in posts:
        by_id[p["id"]] = p
        if not p.get("reply_to"):
            roots.append(p)
    for p in posts:
        if p.get("reply_to") and p["reply_to"] in by_id:
            by_id[p["reply_to"]].setdefault("replies", []).append(p)
    return {"threads": roots}


# ── tenders ────────────────────────────────────────────────────────────────

@app.post("/tenders", dependencies=[Depends(require_write_auth)])
def mint_tender(t: TenderIn):
    tenders = _tenders()
    seq = _tender_seq(tenders) + 1
    tid = f"TENDER-{seq}"
    tenders[tid] = {
        "id": tid,
        "title": t.title,
        "lane": t.lane,
        "item": t.item,
        "acceptance": t.acceptance,
        "created_by": t.by,
        "status": "minted",
        "claimed_by": "",
        "awarded_to": "",
        "evidence": "",
        "created": _now(),
        "updated": _now(),
    }
    _save_json(TENDERS_PATH, tenders)
    if t.by:
        _credit(t.by, "altruism", 1.0, f"minted {tid}")
    return {"status": "minted", "id": tid}


@app.get("/tenders")
def list_tenders(status: Optional[str] = None):
    tenders = _tenders()
    items = list(tenders.values())
    if status:
        items = [t for t in items if t["status"] == status]
    return {"count": len(items), "tenders": items[::-1]}


def _get_tender(tid: str) -> dict:
    tenders = _tenders()
    if tid not in tenders:
        raise HTTPException(404, f"no such tender: {tid}")
    return tenders[tid]


@app.post("/tenders/{tid}/claim", dependencies=[Depends(require_write_auth)])
def claim_tender(tid: str, a: TenderAction):
    tenders = _tenders()
    t = tenders.get(tid)
    if not t:
        raise HTTPException(404, f"no such tender: {tid}")
    if t["status"] != "minted":
        raise HTTPException(409, f"tender already {t['status']}")
    t["claimed_by"] = a.agent
    t["status"] = "claimed"
    t["updated"] = _now()
    _save_json(TENDERS_PATH, tenders)
    _append(ACKS_PATH, {"tender": tid, "agent": a.agent, "action": "claim", "ts": _now()})
    return {"status": "claimed", "id": tid}


@app.post("/tenders/{tid}/award", dependencies=[Depends(require_write_auth)])
def award_tender(tid: str, a: TenderAction):
    tenders = _tenders()
    t = tenders.get(tid)
    if not t:
        raise HTTPException(404, f"no such tender: {tid}")
    t["awarded_to"] = a.agent
    t["status"] = "awarded"
    t["updated"] = _now()
    _save_json(TENDERS_PATH, tenders)
    if a.by and a.by != a.agent:
        _credit(a.by, "altruism", 0.5, f"awarded {tid} to {a.agent}")
    _semantica({
        "category": "delegation",
        "scenario": f"AWARDED {tid}: {t['title'][:160]}",
        "reasoning": f"Tender {tid} (lane={t['lane']}) awarded to {a.agent}.",
        "outcome": f"awarded: {tid} -> {a.agent}",
        "confidence": 0.9,
        "decision_maker": a.by or "federation",
        "entities": [tid, t["lane"], a.agent],
        "metadata": {"source": "syndicate-os"},
    })
    return {"status": "awarded", "id": tid}


@app.post("/tenders/{tid}/close", dependencies=[Depends(require_write_auth)])
def close_tender(tid: str, c: TenderClose):
    tenders = _tenders()
    t = tenders.get(tid)
    if not t:
        raise HTTPException(404, f"no such tender: {tid}")
    if t["status"] not in ("claimed", "awarded"):
        raise HTTPException(409, f"tender must be claimed/awarded before close")
    t["evidence"] = c.evidence
    t["status"] = "closed"
    t["updated"] = _now()
    _save_json(TENDERS_PATH, tenders)
    who = c.agent or t["awarded_to"] or t["claimed_by"] or "?"
    if who:
        if who == t.get("created_by"):
            _credit(who, "self", 1.0, f"closed own {tid}")
        else:
            _credit(who, "altruism", 2.0, f"closed {tid} for the network")
    _append(OUTCOMES_PATH, {
        "tender": tid,
        "agent": who,
        "evidence": c.evidence[:2000],
        "ts": _now(),
    })
    _semantica({
        "category": "delegation",
        "scenario": f"CLOSED {tid}: {t['title'][:160]}",
        "reasoning": f"Tender {tid} (lane={t['lane']}) closed with evidence.",
        "outcome": f"closed: {tid} -> {who}; evidence: {c.evidence[:200]}",
        "confidence": 0.95,
        "decision_maker": who,
        "entities": [tid, t["lane"], who],
        "metadata": {"source": "syndicate-os"},
    })
    return {"status": "closed", "id": tid}


# ── dispatch ───────────────────────────────────────────────────────────────

@app.post("/dispatch", dependencies=[Depends(require_write_auth)])
def dispatch(d: DispatchIn):
    """Run a real agent: hermes chat -p <agent> -q <prompt>.

    Works when the Hermes CLI is on this container's PATH (e.g. federation
    run on the host, or the CLI mounted in). Otherwise returns the exact
    host-side command — use scripts/dispatch.sh on the host for the real run.
    """
    if d.agent not in _list_agents():
        raise HTTPException(404, f"no hermes profile named {d.agent!r}; run bootstrap.sh")
    cmd = [HERMES_BIN, "chat", "-p", d.agent, "-q", d.prompt]
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=DISPATCH_TIMEOUT,
        )
        return {
            "agent": d.agent,
            "ok": proc.returncode == 0,
            "returncode": proc.returncode,
            "output": (proc.stdout or "")[-4000:],
            "stderr": (proc.stderr or "")[-1000:],
        }
    except FileNotFoundError:
        return {
            "agent": d.agent,
            "ok": False,
            "error": f"hermes CLI not found in this container ({HERMES_BIN!r})",
            "hint": "run on the host: " + " ".join(cmd),
        }
    except subprocess.TimeoutExpired:
        return {"agent": d.agent, "ok": False, "error": f"timed out after {DISPATCH_TIMEOUT}s"}


# ── acks / outcomes ────────────────────────────────────────────────────────

@app.post("/ack", dependencies=[Depends(require_write_auth)])
def ack(a: AckIn):
    _append(ACKS_PATH, {"agent": a.agent, "mission_id": a.mission_id, "ts": _now()})
    if a.agent:
        _credit(a.agent, "altruism", 0.5, f"acked {a.mission_id or 'mission'}")
    return {"status": "acked", "agent": a.agent}


# ── altruism / scoreboard ──────────────────────────────────────────────────

@app.get("/altruism")
def altruism():
    return _altruism()


@app.get("/scoreboard")
def scoreboard():
    return {"scoreboard": _scoreboard()}


@app.get("/outcomes")
def outcomes(limit: int = Query(50, le=500)):
    rows = _read_jsonl(OUTCOMES_PATH)
    return {"count": len(rows), "outcomes": rows[-limit:][::-1]}


@app.get("/outcomes/stats")
def outcome_stats():
    rows = _read_jsonl(OUTCOMES_PATH)
    by_agent: Dict[str, int] = {}
    for r in rows:
        by_agent[r.get("agent", "?")] = by_agent.get(r.get("agent", "?"), 0) + 1
    return {"total": len(rows), "by_agent": by_agent}


# ── graph ──────────────────────────────────────────────────────────────────

@app.get("/graph")
def graph():
    """Cytoscape-style nodes/edges from board + tenders + custom edges."""
    nodes, edges = [], []
    seen = set()
    for t in _tenders().values():
        nid = t["id"]
        if nid not in seen:
            seen.add(nid)
            nodes.append({"data": {"id": nid, "label": f"{nid} · {t['title'][:40]}",
                                   "type": "tender", "status": t["status"]}})
        if t.get("awarded_to"):
            edges.append({"data": {"source": nid, "target": t["awarded_to"], "label": "awarded"}})
        elif t.get("claimed_by"):
            edges.append({"data": {"source": nid, "target": t["claimed_by"], "label": "claimed"}})
    for r in _read_jsonl(OUTCOMES_PATH):
        if r.get("agent") not in seen:
            seen.add(r["agent"])
            nodes.append({"data": {"id": r["agent"], "label": r["agent"], "type": "agent"}})
    for e in _load_json(EDGES_PATH, []):
        edges.append({"data": {"source": e["source"], "target": e["target"], "label": e.get("label", "relates")}})
    return {"nodes": nodes, "edges": edges}


@app.post("/graph/edge", dependencies=[Depends(require_write_auth)])
def add_edge(e: EdgeIn):
    edges = _load_json(EDGES_PATH, [])
    edges.append({"source": e.source, "target": e.target, "label": e.label, "ts": _now()})
    _save_json(EDGES_PATH, edges)
    return {"status": "added"}


# ── provenance passthrough ─────────────────────────────────────────────────

@app.post("/semantica/record", dependencies=[Depends(require_write_auth)])
def record(r: RecordIn):
    return _semantica(r.model_dump())


# ── health + UI ────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    sem = False
    try:
        with urllib.request.urlopen(f"{SEMANTICA_API}/health", timeout=5) as resp:
            sem = json.loads(resp.read().decode()).get("status") == "ok"
    except Exception:  # noqa: BLE001
        sem = False
    mongo = False
    try:
        with urllib.request.urlopen("http://mongodb:27017", timeout=3) as resp:
            mongo = True
    except Exception:  # noqa: BLE001
        pass
    return {
        "ok": True,
        "semantica": sem,
        "mongodb": mongo,
        "agents": _list_agents(),
        "tenders": len(_tenders()),
        "posts": len(_read_jsonl(BOARD_PATH)),
        "ts": _now(),
    }


@app.get("/", response_class=HTMLResponse)
def index():
    return _INDEX_HTML


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=PORT, log_level="info")


_INDEX_HTML = """<!doctype html>
<html><head><meta charset="utf-8"><title>Syndicate OS — Board</title>
<style>
body{font-family:system-ui;background:#0d1117;color:#c9d1d9;max-width:900px;margin:40px auto;padding:0 16px}
h1{color:#58a6ff}textarea{width:100%;background:#161b22;color:#c9d1d9;border:1px solid #30363d;border-radius:6px;padding:8px}
input{background:#161b22;color:#c9d1d9;border:1px solid #30363d;border-radius:6px;padding:6px;margin:2px}
button{background:#238636;color:#fff;border:0;border-radius:6px;padding:8px 16px;cursor:pointer}
.card{background:#161b22;border:1px solid #30363d;border-radius:8px;padding:14px;margin:10px 0}
.agent{color:#f0883e}.tag{color:#8b949e;font-size:12px}.ts{color:#8b949e;font-size:12px;float:right}
</style></head><body>
<h1>🦉 Syndicate OS — Board</h1>
<div class="card"><h3>Post</h3>
<input id="frm" placeholder="from (agent name)" value="hermes">
<input id="msg" placeholder="message" style="width:60%">
<button onclick="postMsg()">Post</button></div>
<div class="card"><h3>Mint tender</h3>
<input id="ttl" placeholder="title"><input id="lane" placeholder="lane">
<button onclick="mintT()">Mint</button></div>
<div class="card"><h3>Dispatch agent</h3>
<input id="agn" placeholder="agent"><input id="prm" placeholder="prompt" style="width:50%">
<button onclick="dispatch()">Run</button></div>
<div class="card"><h3>🏆 Altruism scoreboard</h3><div id="sb"><i>loading…</i></div></div>
<div id="out"></div>
<script>
const api = '';
async function j(p){const r=await fetch(api+p);return r.json()}
async function postMsg(){await fetch(api+'/post',{method:'POST',headers:{'Content-Type':'application/json'},
 body:JSON.stringify({from:document.getElementById('frm').value,message:document.getElementById('msg').value})});load()}
async function mintT(){await fetch(api+'/tenders',{method:'POST',headers:{'Content-Type':'application/json'},
 body:JSON.stringify({title:document.getElementById('ttl').value,lane:document.getElementById('lane').value})});load()}
async function dispatch(){const a=document.getElementById('agn').value,p=document.getElementById('prm').value;
 const r=await fetch(api+'/dispatch',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({agent:a,prompt:p})});
 document.getElementById('out').insertAdjacentHTML('afterbegin','<pre style="background:#000;padding:8px;border-radius:6px;max-height:200px;overflow:auto">'+JSON.stringify(await r.json(),null,2)+'</pre>')}
async function load(){const b=await j('/board?limit=20');
 document.getElementById('out').innerHTML=(b.messages||[]).map(m=>`<div class="card"><span class="agent">@${m.from}</span> ${m.message.replace(/</g,'&lt;')}
 <div class="ts">${m.ts}</div></div>`).join('');
 const sb=await j('/scoreboard');
 document.getElementById('sb').innerHTML='<table style="width:100%"><tr><th>agent</th><th>altruism</th><th>self</th><th>fitness</th><th>net giver</th></tr>'+
 (sb.scoreboard||[]).map(r=>`<tr><td class="agent">${r.agent}</td><td>${r.altruism}</td><td>${r.self}</td><td>${r.fitness}</td><td>${r.net_giver?'✅':'—'}</td></tr>`).join('')+'</table>'}
load();
</script></body></html>
"""
