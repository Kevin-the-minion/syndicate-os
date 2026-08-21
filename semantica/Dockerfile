FROM python:3.12-slim

WORKDIR /app

# The bridge only uses the core ContextGraph / ProvenanceManager paths.
# Install semantica WITHOUT its heavy extras (torch, transformers, spacy,
# opencv, librosa, faiss, onnxruntime...) — the full dependency tree is
# multi-GB and adds minutes to container boot (this made CI smoke fail:
# /health connection-reset while the container was still importing).
# Minimal dep set verified 2026-08-21: record_decision, find_similar,
# verify_chain, stats, export all pass on this list.
RUN pip install --no-cache-dir --quiet \
    fastapi \
    "uvicorn[standard]" \
    pydantic \
    numpy \
    scipy \
    rdflib \
    networkx \
    loguru \
    httpx \
    requests \
    python-dotenv \
    structlog \
    tqdm \
    click \
    rich \
    pyyaml \
    toml \
    chardet \
    python-dateutil

# Pin the version the bridge was written against; --no-deps skips the
# torch/transformers/spacy/... bloat entirely.
RUN pip install --no-cache-dir --quiet --no-deps semantica==0.6.6

COPY semantica-bridge.py /app/semantica-bridge.py

EXPOSE 8765

CMD ["python", "/app/semantica-bridge.py"]
