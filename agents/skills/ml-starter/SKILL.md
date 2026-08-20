---
name: ml-starter
description: Use when working with local ML — inference, embeddings, evaluation.
---

# ML Starter — local inference + evaluation

The Syndicate runs its ML stack locally by default. Ollama is the fast path;
llama.cpp is the raw path; lm-eval-harness is the measurement path.

## Local inference (Ollama)
```bash
# one-time
curl -fsSL https://ollama.com/install.sh | sh
ollama pull nomic-embed-text      # embeddings for memory search
ollama pull llama3.2              # general chat
ollama pull qwen2.5-coder:7b      # coding
# chat
ollama run llama3.2 "explain attention in one paragraph"
# embeddings (used by memory-search)
curl -s http://localhost:11434/api/embeddings -d '{"model":"nomic-embed-text","prompt":"query"}' | python3 -m json.tool
```

## Raw inference (llama.cpp, GGUF)
```bash
# download a GGUF (e.g. from HuggingFace), then:
llama-cli -m model.gguf -p "prompt" -n 256
# quantize: llama-quantize model.gguf model-Q4_K_M.gguf Q4_K_M
```

## Evaluation (lm-eval-harness)
```bash
pip install lm-eval
lm_eval --model local-completions --model_args model=ollama/llama3.2 \
  --tasks mmlu --num_fewshot 5 --limit 20
```
Gate: baseline the local model BEFORE trusting its output for council work.

## Embeddings math
`memory-search` uses cosine similarity over nomic-embed-text vectors. A score
below ~0.3 is noise; 0.5+ is a real hit. Never quote a retrieval score as a
probability.

## Pitfalls
- Local 3b models confabulate confidently — verify every factual claim.
- `ollama pull` needs ~2-4 GB per model; disk is the constraint on small boxes.
- Ollama on the LAN: bind to 0.0.0.0, but never expose it to the internet.
