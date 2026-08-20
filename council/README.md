# 🍄 Psychedelic Council

**Altered-frame problem solving for LLMs.** Force a model to analyse a problem
through deliberately alien cognitive frames, then make every metaphor cash out
into a plain, falsifiable technical claim.

---

## Status of the core claim

> **Hypothesis (UNTESTED):** forcing a model through a radically different
> representational frame surfaces correct findings that a straight expert prompt
> would miss.

That is a hypothesis, not a result. Nobody has measured it. It is plausible — it
is roughly why humans solve problems on walks — but plausible is not the same as
true, and a tool that produces confident, vivid output is exactly the kind of
thing that feels like it works whether or not it does.

`scripts/ab-test` exists to settle it. Run ten problems through it before
believing anything in this README, including this README.

---

## What the mechanism actually is

Three things, in order of how much work they do:

1. **Frame prompts.** Twelve system prompts that change what the model treats as
   salient. This is where essentially all the effect comes from, if there is one.
2. **The output contract.** Every finding must be written three times: as the
   metaphor (`IMAGE`), as a flat technical claim (`PLAIN`), and as the
   observation that would prove it false (`TEST`). A finding whose PLAIN line
   needs the metaphor to make sense gets deleted. This is the part that stops
   the tool from generating poetry that reads like engineering.
3. **The verification gate.** A mandatory adversarial pass, run on the synthesis
   rather than alongside it, that grades each finding diamond / quartz / glass /
   mirror / inflated and is explicitly permitted to cut everything.

**Temperature is only varied in `--api` mode**, because that is the only mode
that can set it. Anthropic's valid range is 0.0–1.0 and the API has no seed
parameter, so this tool stays inside that range and does not pretend to set a
seed. (Ollama does support seeds; the Ollama backend sets a real one.)

Previous versions printed `temp=1.83, seed=60533` into a prompt destined for a
chat window, where it was read as text and set nothing. If you see that in a
fork, it is decoration.

---

## Quick start

```bash
# Print a prompt to paste into any chat UI
./scripts/trip "Why does our auth system keep failing under load?"

# Pick roles from the problem text
./scripts/trip --auto "Deploys keep half-failing and nobody knows why"

# Push harder
./scripts/trip --dose heroic "What is fundamentally wrong with this architecture?"

# Actually call a model — real per-role temperature, saved run directory
export ANTHROPIC_API_KEY=sk-...
./scripts/trip --api --auto "Why is the NAS unreachable at night?"

# Run it against a local model instead
./scripts/trip --api --backend ollama --dose light "Audit this network design"

# Test whether any of this beats a plain prompt
./scripts/ab-test --auto "Your genuinely stuck problem"
```

Requires **bash 4+** (macOS ships 3.2 — `brew install bash`). `--api` mode also
needs `curl` and `jq`.

---

## Dose

Dose changes the prompt in every mode, and the temperature in `--api` mode.

| Dose | Frame intensity | API temperature |
|------|-----------------|-----------------|
| `micro` | Frame as a lens; plain prose out | 0.20–0.35 |
| `light` | Inhabits the frame, stays recognisably an engineer | 0.40–0.55 |
| `standard` | Full frame; the frame decides what is salient | 0.60–0.80 |
| `heroic` | Full frame, must produce one proposal that sounds wrong | 0.85–1.00 |

The μg dosages are gone. They were a joke that read as false precision to the
technical audience this is aimed at.

---

## The 12 frames

| Role | Frame | Auto-selected for |
|---|---|---|
| 🌀 `leader` | Non-linear time; the whole state space at once | stuck, systemic, fundamental |
| 🏗️ `architect` | Codebase as a living city | architecture, refactoring, tech debt |
| 🛡️ `security` | Embodiment; vulnerabilities as physical pain | auth, secrets, credentials, exploits |
| 🧠 `data` | Synesthetic latent space | models, embeddings, training, inference |
| 🍄 `strategist` | Mycelial network; no centre | strategy, trade-offs, scaling |
| ⏳ `timekeeper` | All of time at once; incidents as strata | outages, root cause, flakiness |
| 💀 `embodiment` | Becomes the hardware | servers, CPU, disk, IoT, firmware |
| 🌿 `ecologist` | System as ecosystem | networks, dependencies, DNS/DHCP, cascades |
| 📚 `librarian` | Multi-dimensional library; contradictions glow | docs, research, specs |
| 💎 `skeptic` | Truth claims as crystals | audits, evidence, assumptions |
| 📝 `wordsmith` | Language as load-bearing architecture | copy, UX, naming, messaging |
| 🌊 `perf` | Data as ocean; latency as viscosity | latency, bottlenecks, p95, queues |

Role auto-selection uses whole-word matching. (The previous version matched
substrings, so `html` selected the ML frame via `ml`, and `company` selected the
generalist via `any`.)

---

## When to use it

**Good candidates:** genuinely stuck after several attempts; architecture reviews
where the obvious findings are already handled; root cause analysis where the
symptom is clear and the cause is not.

**Poor candidates:** simple bugs; live incidents (this adds latency, not speed);
well-understood problems; anything where you already know the answer and want
confirmation — the tool will happily give you five vivid reasons you were right.

---

## The failure mode to watch for

Metaphor compresses, but it also **manufactures**. A frame instructed to feel
pain will report pain whether or not pain exists. Feed that into a summariser
told to extract actionable insights and you get a machine that converts vivid
language into apparent findings — confident, well-organised, and hollow.

Everything defensive in this package exists for that one failure: the PLAIN and
TEST lines, the proportionality rule, the mandatory `Dropped` section in the
synthesis, and the verification gate that can cut the whole report.

If you disable the verification gate (`--no-verify`), you are running the version
that produces the most impressive-looking output and the least trustworthy.

---

## Cost

A 4-role `--api` run is roughly 12k input + 8k output tokens across six requests
(4 roles, synthesis, verification). On a mid-tier frontier model that is cents,
not fractions of a cent. On a local Ollama model it is free and slower.

---

## Layout

```
psychedelic-council/
├── scripts/
│   ├── trip                  # main entry point
│   └── ab-test               # blind A/B harness — run this before believing
├── prompts/
│   ├── _contract.md          # the output contract (IMAGE / PLAIN / TEST)
│   ├── _synthesis.md         # works only from PLAIN and TEST lines
│   ├── _verify.md            # adversarial gate, run on the synthesis
│   ├── _baseline.md          # control arm for A/B
│   └── <12 role frames>.md
├── examples/
└── runs/                     # created by --api and ab-test
```

## License

GPL-3.0. Fork it, improve it, share it back — that's the deal.

---

*"The question is not whether the model can trip. The question is whether
anything it brought back survives being asked to prove itself."*
