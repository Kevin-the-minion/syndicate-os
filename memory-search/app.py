#!/usr/bin/env python3
"""memory-search — semantic search over agent memories + the provenance graph,
powered by a LOCAL LLM (Ollama). Nothing leaves the machine.

- Embeddings: Ollama /api/embeddings (default nomic-embed-text — a small,
  free, local embedding model).
- Generation:  Ollama /api/generate (default llama3.2:3b — local RAG answers).
- Sources:     markdown memory files under MEMORY_ROOTS (e.g. Hermes profile
  memories/) + the Semantica provenance graph (nodes/decisions).

Endpoints:
  POST /index            rebuild the index (scan roots + pull semantica graph)
  GET  /search?q=&k=     cosine top-k over chunks -> [{path, score, snippet}]
  GET  /search/llm?q=    retrieve top-k, local LLM answers with sources
  GET  /health           ollama + index state

GPL-3.0 License.
"""
import json
import math
import os
import re
import urllib.request
from pathlib import Path
from typing import List, Optional

from fastapi import FastAPI, Query
from pydantic import BaseModel

OLLAMA_API = os.environ.get("OLLAMA_API", "http://localhost:11434")
EMBED_MODEL = os.environ.get("EMBED_MODEL", "nomic-embed-text")
LLM_MODEL = os.environ.get("LLM_MODEL", "llama3.2:3b")
DATA_DIR = Path(os.environ.get("DATA_DIR", "./data"))
MEMORY_ROOTS = [p for p in os.environ.get("MEMORY_ROOTS", "").split(",") if p]
SEMANTICA_API = os.environ.get("SEMANTICA_API", "")  # optional graph source

INDEX_PATH = DATA_DIR / "memory-index.json"
CHUNK_CHARS = 800

app = FastAPI(title="Syndicate OS Memory Search", version="0.1.0")


# ── ollama helpers ─────────────────────────────────────────────────────────

def _ollama(path: str, payload: dict, timeout: int = 120) -> dict:
    req = urllib.request.Request(
        f"{OLLAMA_API}{path}",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def _embed(text: str) -> List[float]:
    return _ollama("/api/embeddings", {"model": EMBED_MODEL, "prompt": text})["embedding"]


def _generate(prompt: str) -> str:
    return _ollama("/api/generate", {"model": LLM_MODEL, "prompt": prompt, "stream": False})["response"]


def _cosine(a: List[float], b: List[float]) -> float:
    if len(a) != len(b) or not a:
        return 0.0
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    return dot / (na * nb) if na and nb else 0.0


# ── indexing ───────────────────────────────────────────────────────────────

def _chunk_text(text: str) -> List[str]:
    text = re.sub(r"\s+", " ", text)
    return [text[i:i + CHUNK_CHARS] for i in range(0, len(text), CHUNK_CHARS)] if text else []


def _scan_files() -> List[dict]:
    chunks = []
    for root in MEMORY_ROOTS:
        base = Path(root)
        if not base.exists():
            continue
        for p in sorted(base.rglob("*.md")):
            try:
                text = p.read_text(errors="replace")
            except OSError:
                continue
            for i, chunk in enumerate(_chunk_text(text)):
                chunks.append({"path": str(p), "text": chunk, "idx": i})
    return chunks


def _scan_semantica() -> List[dict]:
    if not SEMANTICA_API:
        return []
    try:
        req = urllib.request.Request(f"{SEMANTICA_API}/nodes", timeout=10)
        with urllib.request.urlopen(req) as r:
            nodes = json.loads(r.read().decode())
        chunks = []
        if isinstance(nodes, dict):
            nodes = nodes.get("nodes", nodes.get("results", []))
        for n in nodes if isinstance(nodes, list) else []:
            label = f"{n.get('id', '')} {n.get('scenario', n.get('label', n.get('type', '')))} {n.get('reasoning', '')} {n.get('outcome', '')}"
            for i, chunk in enumerate(_chunk_text(str(label))):
                chunks.append({"path": f"semantica:{n.get('id', '?')}", "text": chunk, "idx": i})
        return chunks
    except Exception:  # noqa: BLE001
        return []


def _build_index() -> dict:
    chunks = _scan_files() + _scan_semantica()
    index = {"model": EMBED_MODEL, "chunks": []}
    for c in chunks:
        try:
            c["vec"] = _embed(c["text"])
            index["chunks"].append(c)
        except Exception:  # noqa: BLE001
            continue
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    INDEX_PATH.write_text(json.dumps(index))
    return index


def _load_index() -> dict:
    if INDEX_PATH.exists():
        try:
            return json.loads(INDEX_PATH.read_text())
        except json.JSONDecodeError:
            pass
    return {"model": EMBED_MODEL, "chunks": []}


def _retrieve(qvec: List[float], k: int) -> List[dict]:
    scored = sorted(
        ((_cosine(qvec, c["vec"]), c) for c in _load_index().get("chunks", [])),
        key=lambda x: -x[0],
    )
    out = []
    for score, c in scored[:k]:
        if score <= 0:
            break
        snippet = c["text"][:400]
        out.append({"path": c["path"], "score": round(score, 4), "snippet": snippet})
    return out


# ── API ────────────────────────────────────────────────────────────────────

class IndexResult(BaseModel):
    chunks: int
    sources: int


@app.post("/index")
def index():
    idx = _build_index()
    sources = len({c["path"] for c in idx["chunks"]})
    return IndexResult(chunks=len(idx["chunks"]), sources=sources)


@app.get("/search")
def search(q: str = Query(..., min_length=1), k: int = Query(5, le=20)):
    qvec = _embed(q)
    return {"query": q, "results": _retrieve(qvec, k)}


@app.get("/search/llm")
def search_llm(q: str = Query(..., min_length=1), k: int = Query(5, le=20)):
    qvec = _embed(q)
    hits = _retrieve(qvec, k)
    ctx = "\n\n".join(f"[{i+1}] ({h['path']}) {h['snippet']}" for i, h in enumerate(hits))
    prompt = (
        "You are the memory layer of a self-hosted agent federation. Answer the "
        "question using ONLY the retrieved context. If the context does not answer "
        "it, say so plainly.\n\n"
        f"QUESTION: {q}\n\nCONTEXT:\n{ctx}\n\nANSWER:"
    )
    try:
        answer = _generate(prompt)
    except Exception as e:  # noqa: BLE001
        answer = f"local LLM unavailable: {e}"
    return {"query": q, "answer": answer, "sources": hits}


@app.get("/health")
def health():
    try:
        _ollama("/api/tags", {}, timeout=5)
        ollama = True
    except Exception:  # noqa: BLE001
        ollama = False
    idx = _load_index()
    return {
        "ok": True,
        "ollama": ollama,
        "embed_model": EMBED_MODEL,
        "llm_model": LLM_MODEL,
        "chunks": len(idx.get("chunks", [])),
        "sources": len({c["path"] for c in idx.get("chunks", [])}),
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("MEMORY_SEARCH_PORT", "7878")), log_level="info")
