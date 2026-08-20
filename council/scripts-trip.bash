#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  🍄  PSYCHEDELIC COUNCIL — altered-frame problem solving     ║
# ║  v2 — parameters are real or they are not mentioned          ║
# ╚══════════════════════════════════════════════════════════════╝
#
# TWO MODES:
#   print  (default) — emits a prompt to paste into any chat UI.
#                      No sampling parameters are claimed, because a chat UI
#                      cannot set them. Dose still works: it changes the prompt.
#   api              — actually calls a model API, one request per role, with a
#                      real per-role temperature. Then synthesises, then runs a
#                      mandatory verification pass. Writes everything to a run dir.
#
# BACKENDS (api mode):  anthropic (default) | ollama
#
# Requires bash 4+. api mode additionally requires curl and jq.

set -euo pipefail

if (( BASH_VERSINFO[0] < 4 )); then
    echo "ERROR: bash 4+ required (you have ${BASH_VERSION})." >&2
    echo "macOS ships bash 3.2. Install a newer one: brew install bash" >&2
    echo "Then run with: /opt/homebrew/bin/bash scripts/trip ..." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="${SCRIPT_DIR}/../prompts"
RUNS_DIR="${TRIP_RUNS_DIR:-${SCRIPT_DIR}/../runs}"

ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-claude-sonnet-5}"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.1:8b}"
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
MAX_TOKENS="${TRIP_MAX_TOKENS:-2000}"

# ═══════════════════════════════════════════════════════════════
# ROLE REGISTRY
# match = whole-word regex, anchored on word boundaries.
# ═══════════════════════════════════════════════════════════════
declare -A ROLE_DESC ROLE_MATCH ROLE_EMOJI

ROLE_EMOJI[architect]="🏗️"
ROLE_DESC[architect]="Codebase as a living city. Classes are buildings, dependencies are roads. Spots urban-planning disasters from 10,000ft."
ROLE_MATCH[architect]="architect|architecture|design|refactor|refactoring|monolith|coupling|modular|structure|technical debt|tech debt"

ROLE_EMOJI[security]="🛡️"
ROLE_DESC[security]="Embodies the system. Vulnerabilities as physical pain, trust boundaries as membranes."
ROLE_MATCH[security]="security|secure|auth|authentication|authorisation|authorization|secret|secrets|credential|credentials|token|vulnerability|vulnerabilities|exploit|breach|leak|permission|permissions|encrypt|encryption|firewall"

ROLE_EMOJI[data]="🧠"
ROLE_DESC[data]="Latent space as a physical landscape. Tastes loss functions, walks through embeddings."
ROLE_MATCH[data]="machine learning|model|models|embedding|embeddings|training|fine-tune|finetune|inference|llm|neural|dataset|prompt|token|tokens|overfit|quantis|quantiz"

ROLE_EMOJI[strategist]="🍄"
ROLE_DESC[strategist]="Mycelial network. Rhizomatic — no centre, no hierarchy, only connections."
ROLE_MATCH[strategist]="strategy|strategic|roadmap|priorit|trade-off|tradeoff|distributed|decentral|scaling|scale|business|product|why are we"

ROLE_EMOJI[timekeeper]="⏳"
ROLE_DESC[timekeeper]="Sees all of time at once. Incident timelines as geological strata."
ROLE_MATCH[timekeeper]="incident|outage|ops|operations|reliability|root cause|postmortem|post-mortem|debug|debugging|intermittent|flaky|race condition|regression|downtime|restart|restarts"

ROLE_EMOJI[embodiment]="💀"
ROLE_DESC[embodiment]="Becomes the hardware. CPU cycles as heartbeat, disk I/O as breathing."
ROLE_MATCH[embodiment]="hardware|server|servers|cpu|memory|ram|disk|thermal|power|embedded|iot|sensor|sensors|device|devices|raspberry|esp32|firmware"

ROLE_EMOJI[ecologist]="🌿"
ROLE_DESC[ecologist]="System as ecosystem. Components are creatures with territory and relationships."
ROLE_MATCH[ecologist]="network|networking|dependency|dependencies|microservice|microservices|mesh|cascade|cascading|integration|coupling|dns|dhcp|routing|topology"

ROLE_EMOJI[librarian]="📚"
ROLE_DESC[librarian]="All knowledge as a multi-dimensional library. Contradictions glow red."
ROLE_MATCH[librarian]="documentation|docs|knowledge|research|literature|review|taxonomy|catalog|catalogue|archive|inconsistent|contradiction|spec|specification"

ROLE_EMOJI[skeptic]="💎"
ROLE_DESC[skeptic]="Every truth claim is a crystal — diamond or glass, visible by internal structure."
ROLE_MATCH[skeptic]="audit|verify|verification|validate|evidence|claim|claims|assumption|assumptions|test|testing|quality|qa|proof|unproven"

ROLE_EMOJI[wordsmith]="📝"
ROLE_DESC[wordsmith]="Language as physical architecture. Words have mass, sentences are load-bearing."
ROLE_MATCH[wordsmith]="content|copy|writing|wording|readme|messaging|marketing|ux|onboarding|naming|communication|pitch|landing page"

ROLE_EMOJI[leader]="🌀"
ROLE_DESC[leader]="Non-linear time. The whole state space at once — all inputs, branches, crash states."
ROLE_MATCH[leader]="synthesis|holistic|fundamental|systemic|stuck|overall|big picture|everything|root of"

ROLE_EMOJI[perf]="🌊"
ROLE_DESC[perf]="Data as an ocean. Latency is viscosity, throughput is current."
ROLE_MATCH[perf]="performance|latency|slow|throughput|optimis|optimiz|bottleneck|queue|timeout|timeouts|benchmark|metric|metrics|profiling|load|p95|p99"

ALL_ROLES="architect security data strategist timekeeper embodiment ecologist librarian skeptic wordsmith leader perf"

# ═══════════════════════════════════════════════════════════════
# DOSE — changes the PROMPT (always) and the TEMPERATURE (api mode only)
# Anthropic's temperature range is 0.0–1.0. Nothing here exceeds it.
# ═══════════════════════════════════════════════════════════════
dose_temp() {
    # base + jitter, using $RANDOM so there is no python dependency
    local base jitter
    case "${1}" in
        micro)    base=20; jitter=$(( RANDOM % 16 )) ;;   # 0.20–0.35
        light)    base=40; jitter=$(( RANDOM % 16 )) ;;   # 0.40–0.55
        standard) base=60; jitter=$(( RANDOM % 21 )) ;;   # 0.60–0.80
        heroic)   base=85; jitter=$(( RANDOM % 16 )) ;;   # 0.85–1.00
        *)        base=60; jitter=$(( RANDOM % 21 )) ;;
    esac
    local pct=$(( base + jitter ))
    printf '0.%02d' "$pct"
    [[ $pct -eq 100 ]] && printf '\b\b\b1.00' # never happens; guard only
}

dose_modifier() {
    case "${1}" in
        micro)
            cat <<'EOF'
**Frame intensity: light.** Hold the frame as a lens, not an identity. Let it
guide where you look, then write in plain engineering language. Minimal sensory
prose — one image per finding at most.
EOF
            ;;
        light)
            cat <<'EOF'
**Frame intensity: moderate.** Inhabit the frame while analysing, but stay
recognisably an engineer. The metaphor should earn its place by pointing
somewhere non-obvious, not by decorating what you already thought.
EOF
            ;;
        standard)
            cat <<'EOF'
**Frame intensity: full.** Fully adopt the frame. Let it restructure what counts
as salient — things that would be background noise in normal analysis may be the
loudest signal here. Follow that signal, then cash it out under the contract.
EOF
            ;;
        heroic)
            cat <<'EOF'
**Frame intensity: maximum.** Fully adopt the frame and push past your first
three interpretations — those are the normal-mode answers wearing a costume.
You are required to surface at least one proposal that sounds wrong on first
hearing, and then to argue for it on technical grounds under the contract. If
everything you produce is comfortable, you have not left baseline.
EOF
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
# ROLE MATCHING — whole-word, scored, with a sane fallback
# ═══════════════════════════════════════════════════════════════
match_roles() {
    local problem="${1,,}"
    local scored=()
    local role score
    for role in $ALL_ROLES; do
        # grep exits 1 on no match; with pipefail that would abort the loop
        score=$( { grep -oiE "\\b(${ROLE_MATCH[$role]})" <<<"$problem" || true; } | sort -u | wc -l )
        scored+=("${score} ${role}")
    done
    local picked
    picked=$(printf '%s\n' "${scored[@]}" | sort -rn -k1,1 | awk '$1 > 0 {print $2}' | head -4)
    if [[ -z "$picked" ]]; then
        printf '%s\n' leader architect skeptic
    else
        printf '%s\n' "$picked"
    fi
}

# ═══════════════════════════════════════════════════════════════
# PROMPT ASSEMBLY
# ═══════════════════════════════════════════════════════════════
role_system_prompt() {
    local role="$1" dose="$2"
    local file="${PROMPTS_DIR}/${role}-trip.md"
    [[ -f "$file" ]] || { echo "ERROR: missing prompt: $file" >&2; return 1; }
    cat "$file"
    echo
    dose_modifier "$dose"
    echo
    cat "${PROMPTS_DIR}/_contract.md"
}

role_user_prompt() {
    cat <<EOF
THE PROBLEM
$1

Analyse this from your frame. Then report under the Output Contract.
EOF
}

# ═══════════════════════════════════════════════════════════════
# PRINT MODE — for pasting into a chat UI
# ═══════════════════════════════════════════════════════════════
generate_print() {
    local problem="$1" dose="$2"; shift 2
    local roles=("$@") role

    cat <<EOF
# 🍄 Psychedelic Council — paste everything below into your LLM
# dose: ${dose} | roles: ${#roles[@]} | generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
#
# NOTE: chat UIs cannot set sampling parameters. In this mode the dose changes
# the prompt only. For real per-role temperature, use:  trip --api

You will run several analysis passes over ONE problem, each from a different
cognitive frame, then synthesise, then verify. Do them in order. Do not blend the
frames together — each pass is independent, and disagreement between passes is
signal, not a problem to smooth over.

THE PROBLEM: ${problem}

EOF

    local n=0
    for role in "${roles[@]}"; do
        n=$(( n + 1 ))
        echo "═══════════════════════════════════════════════════════════"
        echo "PASS ${n} — ${ROLE_EMOJI[$role]} ${role}"
        echo "═══════════════════════════════════════════════════════════"
        echo
        role_system_prompt "$role" "$dose"
        echo
        role_user_prompt "$problem"
        echo
    done

    echo "═══════════════════════════════════════════════════════════"
    echo "PASS $(( n + 1 )) — SYNTHESIS"
    echo "═══════════════════════════════════════════════════════════"
    echo
    cat "${PROMPTS_DIR}/_synthesis.md"
    echo
    echo "═══════════════════════════════════════════════════════════"
    echo "PASS $(( n + 2 )) — VERIFICATION (do not skip)"
    echo "═══════════════════════════════════════════════════════════"
    echo
    cat "${PROMPTS_DIR}/_verify.md"
}

# ═══════════════════════════════════════════════════════════════
# API CALLS
# ═══════════════════════════════════════════════════════════════
require_api_deps() {
    command -v curl >/dev/null || { echo "ERROR: api mode needs curl" >&2; exit 1; }
    command -v jq   >/dev/null || { echo "ERROR: api mode needs jq" >&2; exit 1; }
}

call_anthropic() {
    local system="$1" user="$2" temp="$3"
    [[ -n "${ANTHROPIC_API_KEY:-}" ]] || { echo "ERROR: ANTHROPIC_API_KEY not set" >&2; return 1; }
    local body
    body=$(jq -n \
        --arg model "$ANTHROPIC_MODEL" \
        --arg system "$system" \
        --arg user "$user" \
        --argjson temp "$temp" \
        --argjson max "$MAX_TOKENS" \
        '{model:$model, max_tokens:$max, temperature:$temp, system:$system,
          messages:[{role:"user", content:$user}]}')
    local resp
    resp=$(curl -sS https://api.anthropic.com/v1/messages \
        -H "x-api-key: ${ANTHROPIC_API_KEY}" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "$body")
    if jq -e '.error' >/dev/null 2>&1 <<<"$resp"; then
        echo "API ERROR: $(jq -r '.error.message' <<<"$resp")" >&2
        return 1
    fi
    jq -r '[.content[] | select(.type=="text") | .text] | join("\n")' <<<"$resp"
}

call_ollama() {
    local system="$1" user="$2" temp="$3"
    # Ollama does support a seed, so here it is real.
    local seed=$(( RANDOM * 32768 + RANDOM ))
    local body
    body=$(jq -n \
        --arg model "$OLLAMA_MODEL" \
        --arg system "$system" \
        --arg user "$user" \
        --argjson temp "$temp" \
        --argjson seed "$seed" \
        '{model:$model, stream:false,
          messages:[{role:"system",content:$system},{role:"user",content:$user}],
          options:{temperature:$temp, seed:$seed}}')
    local resp
    resp=$(curl -sS "${OLLAMA_HOST}/api/chat" -H 'content-type: application/json' -d "$body")
    if jq -e '.error' >/dev/null 2>&1 <<<"$resp"; then
        echo "OLLAMA ERROR: $(jq -r '.error' <<<"$resp")" >&2
        return 1
    fi
    jq -r '.message.content' <<<"$resp"
}

call_model() {
    case "$BACKEND" in
        anthropic) call_anthropic "$@" ;;
        ollama)    call_ollama "$@" ;;
        *) echo "ERROR: unknown backend: $BACKEND" >&2; return 1 ;;
    esac
}

run_api() {
    local problem="$1" dose="$2" do_verify="$3"; shift 3
    local roles=("$@") role temp
    require_api_deps

    local stamp run_dir
    stamp=$(date -u +%Y%m%dT%H%M%SZ)
    run_dir="${RUNS_DIR}/${stamp}"
    mkdir -p "$run_dir"

    {
        echo "problem: ${problem}"
        echo "dose: ${dose}"
        echo "backend: ${BACKEND}"
        echo "model: $([[ $BACKEND == anthropic ]] && echo "$ANTHROPIC_MODEL" || echo "$OLLAMA_MODEL")"
        echo "roles: ${roles[*]}"
        echo "started: ${stamp}"
    } > "${run_dir}/run.meta"

    echo "🍄 trip: ${#roles[@]} roles, dose=${dose}, backend=${BACKEND}" >&2
    echo "   run dir: ${run_dir}" >&2

    local combined="${run_dir}/all-roles.md"
    : > "$combined"

    for role in "${roles[@]}"; do
        temp=$(dose_temp "$dose")
        echo "   → ${ROLE_EMOJI[$role]} ${role} (temperature=${temp})" >&2
        local out="${run_dir}/role-${role}.md"
        if role_system_prompt "$role" "$dose" > "${run_dir}/.sys.$$" &&
           call_model "$(cat "${run_dir}/.sys.$$")" "$(role_user_prompt "$problem")" "$temp" > "$out"; then
            {
                echo "## ${ROLE_EMOJI[$role]} ${role}  (temperature=${temp})"
                echo
                cat "$out"
                echo
            } >> "$combined"
        else
            echo "   ! ${role} failed — continuing" >&2
        fi
        rm -f "${run_dir}/.sys.$$"
    done

    if [[ ! -s "$combined" ]]; then
        echo "ERROR: no role produced output. Nothing to synthesise." >&2
        exit 1
    fi

    echo "   → synthesis" >&2
    call_model "$(cat "${PROMPTS_DIR}/_synthesis.md")" \
        "$(printf 'THE PROBLEM\n%s\n\n---\n\n%s\n' "$problem" "$(cat "$combined")")" \
        "0.20" > "${run_dir}/synthesis.md"

    if [[ "$do_verify" == "true" ]]; then
        echo "   → verification gate" >&2
        call_model "$(cat "${PROMPTS_DIR}/_verify.md")" \
            "$(printf 'THE PROBLEM\n%s\n\n---\n\nTHE SYNTHESIS\n%s\n' "$problem" "$(cat "${run_dir}/synthesis.md")")" \
            "0.10" > "${run_dir}/verified.md"
    fi

    echo >&2
    echo "── SYNTHESIS ──────────────────────────────────────────────"
    cat "${run_dir}/synthesis.md"
    if [[ "$do_verify" == "true" ]]; then
        echo
        echo "── VERIFICATION ───────────────────────────────────────────"
        cat "${run_dir}/verified.md"
    fi
    echo >&2
    echo "saved: ${run_dir}" >&2
}

# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════
usage() {
    cat <<'HELP'
🍄 PSYCHEDELIC COUNCIL — altered-frame problem solving

USAGE
  trip [OPTIONS] "YOUR PROBLEM"

MODES
  (default)              Print a prompt to paste into any chat UI.
  --api                  Actually call a model. Real per-role temperature.
                         Runs roles → synthesis → verification, saves a run dir.
  --output claude        Emit a task file for Claude Code.

OPTIONS
  --dose micro|light|standard|heroic   Frame intensity (default: standard).
                                       Changes the prompt always; changes
                                       temperature in --api mode.
  --roles a,b,c          Specific roles.
  --auto                 Pick roles from the problem text (whole-word matching).
  --backend anthropic|ollama           API backend (default: anthropic).
  --no-verify            Skip the verification gate. Not recommended.
  --list-roles           Show all roles.
  --role-prompt NAME     Print one role's frame.
  --help

ENVIRONMENT
  ANTHROPIC_API_KEY      Required for --backend anthropic.
  ANTHROPIC_MODEL        Default: claude-sonnet-5
  OLLAMA_HOST            Default: http://localhost:11434
  OLLAMA_MODEL           Default: llama3.1:8b
  TRIP_MAX_TOKENS        Default: 2000
  TRIP_RUNS_DIR          Where --api writes runs. Default: ../runs

EXAMPLES
  trip "Why does auth fail under load?"
  trip --auto --dose heroic "Our deploys keep half-failing and nobody knows why"
  trip --api --roles security,ecologist "Audit this network design"
  trip --api --backend ollama --dose light "Why is the NAS unreachable at night?"

NOTE ON TEMPERATURE
  Anthropic's valid range is 0.0–1.0 and there is no seed parameter. This tool
  stays inside that range. Sampling parameters are only claimed in --api mode,
  because that is the only mode that can set them.
HELP
}

main() {
    local dose="standard" roles="" auto=false output_mode="print" problem=""
    local do_verify=true
    BACKEND="anthropic"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dose)     dose="${2:?--dose needs a value}"; shift 2 ;;
            --roles)    roles="${2:?--roles needs a value}"; shift 2 ;;
            --auto)     auto=true; shift ;;
            --api)      output_mode="api"; shift ;;
            --backend)  BACKEND="${2:?--backend needs a value}"; shift 2 ;;
            --no-verify) do_verify=false; shift ;;
            --output)   output_mode="${2:?--output needs a value}"; shift 2 ;;
            --list-roles)
                printf "%-12s %s\n" "ROLE" "FRAME"
                for r in $ALL_ROLES; do
                    printf "%s %-11s %s\n" "${ROLE_EMOJI[$r]}" "$r" "${ROLE_DESC[$r]}"
                done
                exit 0 ;;
            --role-prompt)
                local rp="${2:?--role-prompt needs a role name}"
                if [[ -f "${PROMPTS_DIR}/${rp}-trip.md" ]]; then
                    cat "${PROMPTS_DIR}/${rp}-trip.md"
                else
                    echo "Unknown role: $rp (see --list-roles)" >&2; exit 1
                fi
                exit 0 ;;
            --help|-h)  usage; exit 0 ;;
            -*)         echo "Unknown option: $1 (see --help)" >&2; exit 1 ;;
            *)          problem="$1"; shift ;;
        esac
    done

    case "$dose" in micro|light|standard|heroic) ;;
        *) echo "ERROR: dose must be micro, light, standard or heroic" >&2; exit 1 ;;
    esac

    if [[ -z "$problem" ]]; then
        echo "ERROR: problem statement required" >&2
        echo "Usage: trip [OPTIONS] \"PROBLEM\"  (see --help)" >&2
        exit 1
    fi

    local role_array=()
    if [[ -n "$roles" ]]; then
        IFS=',' read -ra role_array <<< "$roles"
        for r in "${role_array[@]}"; do
            [[ -n "${ROLE_DESC[$r]:-}" ]] || { echo "ERROR: unknown role '$r' (see --list-roles)" >&2; exit 1; }
        done
    elif $auto; then
        readarray -t role_array < <(match_roles "$problem")
    else
        role_array=(leader architect security strategist)
    fi

    case "$output_mode" in
        api)
            run_api "$problem" "$dose" "$do_verify" "${role_array[@]}" ;;
        claude)
            echo "# Run each PASS below in order as a separate analysis, then report the final verification output."
            echo
            generate_print "$problem" "$dose" "${role_array[@]}" ;;
        print|*)
            generate_print "$problem" "$dose" "${role_array[@]}" ;;
    esac
}

main "$@"
