#!/usr/bin/env python3
"""council-run.py — run a psychedelic-council audit against any OpenAI-compatible
endpoint (Ollama, vLLM, DeepSeek, ...).

Same machinery as scripts/trip --api but portable: reads the REAL frame prompts
from ../prompts, applies the IMAGE/PLAIN/TEST contract, runs per-role model
calls with per-role temperature, then the synthesis + adversarial verification
gate (prompts/_synthesis.md + prompts/_verify.md).

Usage:
  OLLAMA_API=http://localhost:11434 OLLAMA_MODEL=llama3.2:3b \\
      python3 council-run.py --dose heroic "audit the repo"
  # any OpenAI-compatible endpoint:
  COUNCIL_API=https://api.deepseek.com/v1 COUNCIL_KEY=sk-... COUNCIL_MODEL=deepseek-v4-flash \\
      python3 council-run.py --dose standard "…"

Output: ./runs/<timestamp>/  (role-*.md, all-roles.md, synthesis.md, verified.md)
"""
import argparse
import json
import os
import random
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROMPTS = HERE / ".." / "prompts"
RUNS = Path(os.environ.get("COUNCIL_RUNS_DIR", str(HERE / ".." / "runs")))

DOSE_TEMP = {"micro": 0.55, "light": 0.65, "standard": 0.75, "heroic": 0.90}
ROLES_BY_DOSE = {
    "micro": ["skeptic"],
    "light": ["architect", "skeptic"],
    "standard": ["leader", "architect", "security", "strategist"],
    "heroic": ["leader", "architect", "security", "strategist", "skeptic", "embodiment"],
}

FRAME_FILES = {
    "leader": "leader-trip.md",
    "architect": "architect-trip.md",
    "security": "security-trip.md",
    "strategist": "strategist-trip.md",
    "skeptic": "skeptic-trip.md",
    "embodiment": "embodiment-trip.md",
}


def call_model(system: str, user: str, temp: float, max_tokens: int = 2500) -> str:
    api = os.environ.get("COUNCIL_API", os.environ.get("OLLAMA_API", "http://localhost:11434"))
    key = os.environ.get("COUNCIL_KEY", "")
    model = os.environ.get("COUNCIL_MODEL", os.environ.get("OLLAMA_MODEL", "llama3.2:3b"))
    headers = {"Content-Type": "application/json"}
    if "ollama" in api:
        payload = {
            "model": model, "stream": False,
            "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}],
            "options": {"temperature": temp, "seed": random.randint(0, 2**31)},
        }
        url = api.rstrip("/") + "/api/chat"
    else:
        if key:
            headers["Authorization"] = f"Bearer {key}"
        payload = {
            "model": model, "stream": False,
            "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}],
            "temperature": temp, "max_tokens": max_tokens,
        }
        url = api.rstrip("/")
        url = url if url.endswith("/v1") else url + "/v1"
        url += "/chat/completions"
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=headers)
    with urllib.request.urlopen(req, timeout=600) as r:
        data = json.loads(r.read().decode())
    if "choices" in data:
        return data["choices"][0]["message"]["content"]
    return data.get("message", {}).get("content", "")


def frame_prompt(role: str) -> str:
    fname = FRAME_FILES.get(role)
    if not fname:
        raise SystemExit(f"unknown role: {role}")
    return (PROMPTS / fname).read_text()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("problem")
    ap.add_argument("--dose", choices=DOSE_TEMP, default="standard")
    ap.add_argument("--roles", help="comma-separated override")
    ap.add_argument("--verify", action="store_true", default=True, help="run verification gate")
    args = ap.parse_args()

    roles = [r.strip() for r in args.roles.split(",")] if args.roles else ROLES_BY_DOSE[args.dose]
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = RUNS / stamp
    run_dir.mkdir(parents=True, exist_ok=True)

    contract = (PROMPTS / "_contract.md").read_text()
    combined = []
    for role in roles:
        temp = DOSE_TEMP[args.dose] + random.uniform(-0.1, 0.1)
        temp = max(0.2, min(1.0, temp))
        print(f"  → {role} (temperature={temp:.2f})", flush=True)
        system = frame_prompt(role) + "\n\n" + contract
        user = (f"THE PROBLEM\n{args.problem}\n\nFollow the output contract exactly.\n\n"
                "IMPORTANT: You have NO tools. You cannot read files, run commands, or "
                "inspect anything. Reason purely from the information in THE PROBLEM and "
                "your frame. Respond in plain markdown text only — no XML, no tool_calls, "
                "no code fences. If you cannot ground a claim in the problem statement, "
                "mark it speculative.")
        try:
            out = call_model(system, user, temp)
        except Exception as e:  # noqa: BLE001
            print(f"  ! {role} failed: {e}", flush=True)
            continue
        (run_dir / f"role-{role}.md").write_text(out)
        combined.append(f"## {role}  (temperature={temp:.2f})\n\n{out}\n")

    if not combined:
        print("ERROR: no role produced output", file=sys.stderr)
        return 1

    all_roles = "\n".join(combined)
    (run_dir / "all-roles.md").write_text(all_roles)

    print("  → synthesis", flush=True)
    synth_prompt = f"THE PROBLEM\n{args.problem}\n\n---\n\n{all_roles}\n\nIMPORTANT: You have NO tools. Reason from the text above only. Respond in plain markdown — no XML, no tool_calls."
    synth = call_model((PROMPTS / "_synthesis.md").read_text(), synth_prompt, 0.2)
    (run_dir / "synthesis.md").write_text(synth)

    if args.verify:
        print("  → verification gate", flush=True)
        verify_prompt = f"THE PROBLEM\n{args.problem}\n\n---\n\nTHE SYNTHESIS\n{synth}\n\nIMPORTANT: You have NO tools. Reason from the text above only. Respond in plain markdown — no XML, no tool_calls."
        verified = call_model((PROMPTS / "_verify.md").read_text(), verify_prompt, 0.1)
        (run_dir / "verified.md").write_text(verified)

    print("\n── SYNTHESIS ──\n" + synth)
    if args.verify:
        print("\n── VERIFICATION ──\n" + (run_dir / "verified.md").read_text())
    print(f"\nsaved: {run_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
