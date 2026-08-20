#!/usr/bin/env python3
"""
Semantica Bridge — REST Facade for Council Decision Provenance
P1 per Athena's design + P1.5 infrastructure entity ingestion (Kevin, 2026-08-13)

Endpoints:
  POST /record_decision   — record a council decision with PROV-O trace
  POST /ingest_entities   — ingest typed infra nodes + edges (hosts/CTs/services/network)
  GET  /nodes             — list nodes by type (verification)
  GET  /find_similar      — find precedent decisions by scenario
  GET  /trace_chain/:id   — trace causal chain for a decision
  GET  /health            — health check (KG + provenance + uptime)
  POST /export            — export PROV-O in Turtle/JSON-LD format
"""
import os
import sys
import json
import time
import logging
from datetime import datetime, timezone
from pathlib import Path

import uvicorn
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, PlainTextResponse
from pydantic import BaseModel
from typing import Optional, List, Dict, Any

# ── Semantica imports ──────────────────────────────────────────────
from semantica import __version__ as semantica_version
from semantica.context import ContextGraph
from semantica.provenance import ProvenanceManager

# ── Config ─────────────────────────────────────────────────────────
PORT = int(os.environ.get("SEMANTICA_PORT", "8765"))
DATA_DIR = Path(os.environ.get("SEMANTICA_DATA_DIR", "/home/chris/semantica-bridge-data"))
OUTBOX_PATH = DATA_DIR / "decisions-outbox.jsonl"
GRAPH_PATH = DATA_DIR / "context-graph.json"
START_TIME = time.time()

# ── Init ───────────────────────────────────────────────────────────
DATA_DIR.mkdir(parents=True, exist_ok=True)

cg = ContextGraph()
pm = ProvenanceManager()

if GRAPH_PATH.exists():
    try:
        cg.load_from_file(str(GRAPH_PATH))
        logging.info(f"Loaded persisted graph ({cg.stats()['node_count']} nodes)")
    except Exception as e:
        logging.warning(f"Could not load graph: {e} — starting fresh")

# Replay the outbox ONLY when there is no persisted graph snapshot.
# _persist() runs synchronously after every write, so the graph file is the
# single source of truth; replaying on top of it would double-count.
if not GRAPH_PATH.exists() and OUTBOX_PATH.exists():
    replayed = 0
    try:
        with open(OUTBOX_PATH) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    cg.record_decision(**entry)
                    replayed += 1
                except Exception:
                    pass
        if replayed:
            OUTBOX_PATH.rename(OUTBOX_PATH.with_suffix(".jsonl.replayed"))
            logging.info(f"Replayed {replayed} decisions from outbox")
    except Exception as e:
        logging.warning(f"Outbox replay error: {e}")



# ── Decision index rebuild (KEV — TENDER-25 fix) ───────────────────
# Semantica v0.6.5 load_from_file() restores nodes/edges but does NOT
# repopulate the in-memory _decisions index (only record_decision() does).
# After a restart, find_similar_decisions() -> find_precedents_by_scenario()
# bails with [] because _decisions is empty. Rebuild the index from the
# persisted decision nodes + involves edges. Idempotent and non-fatal.
def _rebuild_decision_index() -> None:
    from collections import defaultdict

    involves = defaultdict(list)      # decision_id -> [entity, ...]
    for e in cg.edges:
        if getattr(e, "edge_type", None) == "involves":
            involves[getattr(e, "source_id", None)].append(getattr(e, "target_id", None))

    PROTECTED = {
        "category", "scenario", "reasoning", "outcome", "confidence",
        "timestamp", "decision_maker", "content", "valid_from", "valid_until",
    }

    decisions = {}
    decision_index = defaultdict(set)
    entity_index = defaultdict(set)
    temporal_index = []

    for nid, node in cg.nodes.items():
        if getattr(node, "node_type", None) != "decision":
            continue
        props = dict(getattr(node, "properties", None) or getattr(node, "metadata", None) or {})
        category = props.get("category") or ""
        entities = list(involves.get(nid, []))
        timestamp = props.get("timestamp")
        decisions[nid] = {
            "id": nid,
            "category": category,
            "scenario": props.get("scenario") or getattr(node, "content", None) or "",
            "reasoning": props.get("reasoning", ""),
            "outcome": props.get("outcome", ""),
            "confidence": props.get("confidence", 0.5),
            "entities": entities,
            "decision_maker": props.get("decision_maker", ""),
            "timestamp": timestamp,
            "valid_from": props.get("valid_from"),
            "valid_until": props.get("valid_until"),
            "metadata": {k: v for k, v in props.items() if k not in PROTECTED},
        }
        decision_index[category].add(nid)
        for ent in entities:
            entity_index[ent].add(nid)
        if timestamp is not None:
            try:
                temporal_index.append((nid, float(timestamp)))
            except (TypeError, ValueError):
                temporal_index.append((nid, 0.0))

    temporal_index.sort(key=lambda x: x[1], reverse=True)

    cg._decisions = decisions
    cg._decision_index = decision_index
    cg._entity_index = entity_index
    cg._temporal_index = temporal_index
    logging.info(f"Rebuilt decision index: {len(decisions)} decisions "
                 f"({len(involves)} with entities)")


try:
    _rebuild_decision_index()
except Exception as e:
    logging.warning(f"Decision index rebuild failed (search will be empty): {e}")


# ── FastAPI app ────────────────────────────────────────────────────
app = FastAPI(
    title="Semantica Bridge — Council Decision Provenance",
    version="0.2.0",
    description="Thin REST facade for Semantica ContextGraph + ProvenanceManager (Athena P1 + Kevin infra ingestion)"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


# ── Pydantic models ────────────────────────────────────────────────
class DecisionRequest(BaseModel):
    category: str
    scenario: str
    reasoning: str
    outcome: str
    confidence: float = 0.5
    entities: Optional[List[str]] = None
    decision_maker: Optional[str] = "system"
    metadata: Optional[Dict[str, Any]] = None
    dissent: Optional[List[str]] = None


class ExportRequest(BaseModel):
    format: str = "turtle"  # turtle | json-ld


class EntityNode(BaseModel):
    id: str
    type: str = "entity"
    content: Optional[str] = None
    properties: Optional[Dict[str, Any]] = None


class EntityEdge(BaseModel):
    source: str
    target: str
    type: str = "related_to"
    weight: float = 1.0
    properties: Optional[Dict[str, Any]] = None


class IngestRequest(BaseModel):
    nodes: List[EntityNode] = []
    edges: List[EntityEdge] = []
    source: Optional[str] = "kevin"


# ── Helpers ────────────────────────────────────────────────────────
def _persist():
    try:
        cg.save_to_file(str(GRAPH_PATH))
    except Exception as e:
        logging.error(f"Persist failed: {e}")


def _outbox(entry: dict):
    try:
        with open(OUTBOX_PATH, "a") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception as e:
        logging.error(f"Outbox write failed: {e}")


# ── Endpoints ──────────────────────────────────────────────────────

@app.get("/health")
async def health():
    try:
        stats = cg.stats()
        chain = pm.verify_chain()
        return {
            "status": "ok",
            "semantica_version": semantica_version,
            "bridge_uptime_seconds": int(time.time() - START_TIME),
            "graph": stats,
            "provenance": chain,
            "python": sys.version,
        }
    except Exception as e:
        return JSONResponse(status_code=500, content={"status": "error", "error": str(e)})


@app.post("/record_decision")
async def record_decision(req: DecisionRequest):
    try:
        meta = req.metadata or {}
        if req.dissent:
            meta["dissent"] = req.dissent

        decision_id = cg.record_decision(
            category=req.category,
            scenario=req.scenario,
            reasoning=req.reasoning,
            outcome=req.outcome,
            confidence=req.confidence,
            entities=req.entities,
            decision_maker=req.decision_maker,
            metadata=meta,
        )

        pm.track_entity(
            entity_id=decision_id,
            source=req.decision_maker,
            metadata={
                "category": req.category,
                "scenario": req.scenario,
                "outcome": req.outcome,
                "confidence": req.confidence,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                **(meta),
            }
        )

        for entity in (req.entities or []):
            pm.track_entity(
                entity_id=entity,
                source=req.decision_maker,
                metadata={"linked_to_decision": decision_id}
            )

        _persist()
        _outbox({
            "category": req.category,
            "scenario": req.scenario,
            "reasoning": req.reasoning,
            "outcome": req.outcome,
            "confidence": req.confidence,
            "entities": req.entities,
            "decision_maker": req.decision_maker,
            "metadata": meta,
        })

        return {
            "status": "recorded",
            "decision_id": decision_id,
            "provenance": pm.verify_chain(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/ingest_entities")
async def ingest_entities(req: IngestRequest):
    """Ingest typed infrastructure nodes + edges into the graph."""
    added_nodes = 0
    added_edges = 0
    try:
        for n in req.nodes:
            props = dict(n.properties or {})
            ok = cg.add_node(node_id=n.id, node_type=n.type, content=n.content or n.id, **props)
            if ok:
                added_nodes += 1
        for e in req.edges:
            props = dict(e.properties or {})
            ok = cg.add_edge(source_id=e.source, target_id=e.target, edge_type=e.type, weight=e.weight, **props)
            if ok:
                added_edges += 1
        _persist()
        return {
            "status": "ok",
            "source": req.source,
            "added_nodes": added_nodes,
            "added_edges": added_edges,
            "graph": cg.stats(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/nodes")
async def list_nodes(node_type: Optional[str] = Query(None)):
    """List nodes, optionally filtered by type."""
    try:
        nodes = cg.nodes  # dict node_id -> ContextNode
        out = []
        for nid, node in nodes.items():
            t = getattr(node, "node_type", None)
            if node_type and t != node_type:
                continue
            out.append({
                "id": nid,
                "type": t,
                "content": getattr(node, "content", None),
                "properties": getattr(node, "properties", None) or getattr(node, "metadata", None),
            })
        out.sort(key=lambda x: (x["type"] or "", x["id"]))
        return {"status": "ok", "count": len(out), "nodes": out}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/find_similar")
async def find_similar(
    scenario: str = Query(...),
    category: Optional[str] = Query(None),
    max_results: int = Query(10, ge=1, le=50),
    min_similarity: float = Query(0.0, ge=0.0, le=1.0),
):
    try:
        results = cg.find_similar_decisions(
            scenario=scenario,
            category=category,
            max_results=max_results,
            min_similarity=min_similarity,
        )
        return {
            "status": "ok",
            "query": {"scenario": scenario, "category": category},
            "count": len(results),
            "results": results,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/trace_chain/{decision_id}")
async def trace_chain(decision_id: str, max_steps: int = Query(5, ge=1, le=20)):
    try:
        chain = cg.trace_decision_chain(decision_id, max_steps=max_steps)
        return {
            "status": "ok",
            "decision_id": decision_id,
            "chain_length": len(chain),
            "chain": chain,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/export")
async def export_prov(req: ExportRequest):
    try:
        prov = pm.export_prov(format=req.format)
        if req.format in ("json-ld", "jsonld"):
            return JSONResponse(content=json.loads(prov) if isinstance(prov, str) else prov)
        else:
            return PlainTextResponse(content=prov, media_type="text/turtle")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/stats")
async def stats():
    return {
        "graph": cg.stats(),
        "provenance": pm.get_statistics(),
        "graph_summary": cg.get_graph_summary(),
        "bridge_uptime_seconds": int(time.time() - START_TIME),
    }


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    logging.info(f"Semantica Bridge v{semantica_version} starting on :{PORT}")
    logging.info(f"Data dir: {DATA_DIR}  |  Graph: {GRAPH_PATH}")
    uvicorn.run(app, host="0.0.0.0", port=PORT, log_level="info")
