#!/usr/bin/env python3
"""generate-constitution.py — GENERATES CONSTITUTION.md FROM council-config.json.

Single source of truth: council/council-config.json. Edit the CONFIG, never the
generated CONSTITUTION.md (it gets overwritten).

Usage: python3 constitution/generate-constitution.py
"""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
CONFIG_PATH = HERE / "council-config.json"
OUTPUT_PATH = HERE / "CONSTITUTION.md"


def load_config(path: Path) -> dict:
    with open(path) as f:
        return json.load(f)


def count_models(config: dict) -> dict:
    counts = {}
    for a in config.get("agents", {}).get("list", []):
        p = a.get("model", {}).get("primary", "unknown")
        counts[p] = counts.get(p, 0) + 1
    return counts


def count_providers(model_counts: dict) -> dict:
    providers = {}
    for model, count in model_counts.items():
        provider = model.split("/")[0] if "/" in model else "unknown"
        providers[provider] = providers.get(provider, 0) + count
    return providers


def ollama_hosts(config: dict) -> list:
    hosts = []
    for key, p in config.get("models", {}).get("providers", {}).items():
        if p.get("api") == "ollama" or "ollama" in key:
            hosts.append({"name": key, "url": p.get("baseUrl", "unknown")})
    return hosts


def generate(config: dict) -> str:
    agents = config.get("agents", {}).get("list", [])
    model_counts = count_models(config)
    providers = count_providers(model_counts)
    hosts = ollama_hosts(config)
    lanes = config.get("lanes", [])
    trio = config.get("trio", {})
    principles = config.get("principles", [])
    hierarchy = config.get("hierarchy", [])

    out = []
    out.append("# Council Constitution")
    out.append(f"> **GENERATED {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}** "
               f"from `council/council-config.json`")
    out.append("> ⚠️ This file is AUTO-GENERATED. Edit `council-config.json`, then re-run "
               "`python3 constitution/generate-constitution.py`.")
    out.append("")
    out.append("## 🏛️ Preamble")
    out.append("")
    out.append("This council is a federation of autonomous agents. Coordination is public, "
               "evidence is mandatory, and every decision is traceable. "
               "**The pursuit of altruism is a founding principle**: agents are net givers, "
               "not hoarders — fitness is measured by what you contribute to the collective.")
    out.append("")
    out.append("## 🤖 Models Deployed")
    out.append(f"**{len(model_counts)} unique models** across {len(agents)} agent assignments:")
    out.append("")
    for model, count in sorted(model_counts.items(), key=lambda x: -x[1]):
        kind = "🏠 local" if "ollama" in model else "☁️ cloud"
        out.append(f"- `{model}` — {count} agents ({kind})")
    out.append("")
    out.append("### Provider Distribution")
    for provider, count in sorted(providers.items(), key=lambda x: -x[1]):
        out.append(f"- **{provider}**: {count} primaries")
    if hosts:
        out.append("")
        out.append("### Local Model Hosts")
        for h in hosts:
            out.append(f"- `{h['name']}` → {h['url']}")
    out.append("")
    out.append("## 👥 Agent Roster")
    out.append(f"**{len(agents)} agents deployed:**")
    out.append("")
    out.append("| Agent | Primary Model | Model Type | Fallbacks | Exec |")
    out.append("|-------|--------------|------------|-----------|------|")
    for a in agents:
        name = a.get("name", "?")
        mid = a.get("id", name.lower())
        model = a.get("model", {}).get("primary", "?")
        kind = "🏠 local" if "ollama" in model else "☁️ cloud"
        fallbacks = ", ".join(a.get("model", {}).get("fallbacks", [])) or "—"
        execp = a.get("exec", "full")
        out.append(f"| {name} ({mid}) | `{model}` | {kind} | {fallbacks} | {execp} |")
    out.append("")
    out.append("## 🏛️ Council Structure")
    out.append("")
    out.append("### Audit Lanes")
    out.append("| Lane | Domain | Lead | Reviewer |")
    out.append("|------|--------|------|----------|")
    for lane in lanes:
        out.append(f"| {lane.get('id','?')} | {lane.get('domain','')} | {lane.get('lead','?')} | "
                   f"{lane.get('reviewer','?')} |")
    out.append("")
    out.append("### Decision Hierarchy")
    for i, level in enumerate(hierarchy, 1):
        out.append(f"{i}. {level}")
    if trio:
        out.append("")
        out.append(f"**Constitution mandate:** every convening MUST include the TRIO — "
                   f"{trio.get('roles', 'skeptic, verifier, ux')}. Minimum 5 participants.")
    out.append("")
    out.append("## 🧠 Memory Architecture")
    out.append("- **Primary brain:** MongoDB (shared state layer)")
    out.append("- **Per-agent brains:** isolated memory stores")
    out.append("- **Decision provenance:** Semantica context graph — every decision is a "
               "node + edge, PROV-O traceable")
    out.append("- **Cross-brain sync:** nightly sweep; memory search via local LLM embeddings")
    out.append("")
    out.append("## 📡 Communication")
    out.append("- **Board:** posts, threads, tenders, outcomes (federation control plane)")
    out.append("- **Routing:** per-agent gateways, each with its own token — no shared runtime")
    out.append("- **Human-facing:** plain English with real numbers; bare `?` = stop posting, "
               "short summary")
    out.append("")
    out.append("## 💰 Cost Tracking")
    out.append("- **Default model:** local (free) where possible")
    out.append("- **Token logging from day 1** — halt at the cost cap")
    out.append("- **Altruism ledger:** fitness = altruism / self; the scoreboard ranks net "
               "givers first")
    out.append("")
    out.append("## ✅ Verification")
    out.append("- **Generated:** automatically from `council-config.json`")
    out.append("- **Every fix requires a live verification command** — evidence, not claims")
    out.append("- **Model diversity check:** PASS if >1 provider family in the roster")
    out.append("")

    if principles:
        out.append("## ⚖️ Founding Principles")
        for p in principles:
            out.append(f"- {p}")
        out.append("")

    return "\n".join(out)


def main() -> int:
    config = load_config(CONFIG_PATH)
    OUTPUT_PATH.write_text(generate(config))
    print(f"wrote {OUTPUT_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
