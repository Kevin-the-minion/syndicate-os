#!/usr/bin/env bash
# ── librarian.sh — daily memory pruning + consolidation ─────────────────────
# The librarian's sweep: prune stale daily notes, dedupe repeated lines,
# compact oversized entries, write today's note, consolidate the week,
# re-index the local memory search.
#
# Silent unless it changed something. Run daily via cron (agents/cron/librarian.json
# ships the agent-powered version; this is the scripted variant).
set -euo pipefail

MEMORY_ROOTS="${MEMORY_ROOTS:-$HOME/.hermes/profiles/*/memories $HOME/.hermes/memories}"
MEMORY_LIB="${MEMORY_LIB:-$HOME/.hermes/memories}"
DAILY_RETENTION="${DAILY_RETENTION:-30}"        # days of daily notes to keep
MAX_ENTRY_CHARS="${MAX_ENTRY_CHARS:-4000}"        # compact entries above this
MEMORY_SEARCH_API="${MEMORY_SEARCH_API:-http://localhost:7878}"
CONSOLIDATE_DOW="${CONSOLIDATE_DOW:-0}"           # 0=Sunday weekly consolidation

NOW="$(date +%F)"
CHANGES=0
mkdir -p "$MEMORY_LIB"

# 1. prune stale daily notes (memory/YYYY-MM-DD.md) beyond retention
cutoff="$(date -d "-${DAILY_RETENTION} days" +%F 2>/dev/null || date +%F)"
for root in $MEMORY_ROOTS; do
  [ -d "$root" ] || continue
  while IFS= read -r f; do
    base="$(basename "$f" .md)"
    if [[ "$base" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ "$base" < "$cutoff" ]]; then
      rm -f "$f" && echo "  pruned stale note: $f" && CHANGES=$((CHANGES+1))
    fi
  done < <(find "$root" -maxdepth 1 -name '????-??-??.md' 2>/dev/null)

  # 2. dedupe consecutive duplicate lines + compact oversized entries
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    awk 'NR==1 || $0 != prev { print; prev=$0 }' "$f" > "$f.tmp" || continue
    if [ -s "$f.tmp" ]; then mv "$f.tmp" "$f"; else rm -f "$f.tmp"; fi
  done < <(find "$root" -maxdepth 1 -name '*.md' 2>/dev/null)
done

# 3. compact oversized entries (truncate middle with a marker)
for root in $MEMORY_ROOTS; do
  [ -d "$root" ] || continue
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    size=$(wc -c < "$f" 2>/dev/null || echo 0)
    if [ "$size" -gt "$MAX_ENTRY_CHARS" ]; then
      head -c $((MAX_ENTRY_CHARS / 2)) "$f" > "$f.tmp"
      echo -e "\n[… pruned $(($size - MAX_ENTRY_CHARS)) chars by librarian …]\n" >> "$f.tmp"
      tail -c $((MAX_ENTRY_CHARS / 2)) "$f" >> "$f.tmp"
      mv "$f.tmp" "$f"
      echo "  compacted: $f ($size -> $MAX_ENTRY_CHARS)" && CHANGES=$((CHANGES+1))
    fi
  done < <(find "$root" -maxdepth 1 -name '*.md' 2>/dev/null)
done

# 4. weekly consolidation (consolidate yesterday's week on CONSOLIDATE_DOW)
dow="$(date +%u)"   # 1=Mon .. 7=Sun
if [ "$dow" -eq $((CONSOLIDATE_DOW + 1)) ]; then
  week="$(date +%G-W%V)"
  weekly="$MEMORY_LIB/WEEKLY-$week.md"
  touch "$weekly"
  for f in "$MEMORY_LIB"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md; do
    [ -f "$f" ] || continue
    cat "$f" >> "$weekly" && echo "" >> "$weekly"
    rm -f "$f" && CHANGES=$((CHANGES+1))
  done
  [ "$(wc -l < "$weekly")" -gt 0 ] && echo "  consolidated week $week -> WEEKLY-$week.md"
fi

# 5. write today's note
if [ "$CHANGES" -gt 0 ]; then
  note="$MEMORY_LIB/$NOW.md"
  {
    echo "# $NOW — librarian sweep"
    echo "- pruned/compacted/consolidated: $CHANGES item(s)"
    echo "- retention: ${DAILY_RETENTION}d · max entry: ${MAX_ENTRY_CHARS} chars"
  } > "$note"
fi

# 6. re-index local memory search if reachable
if curl -sf -m 5 -X POST "$MEMORY_SEARCH_API/index" >/dev/null 2>&1; then
  echo "  memory-search index rebuilt"
  CHANGES=$((CHANGES+1))
fi

if [ "$CHANGES" -gt 0 ]; then
  echo "librarian: $CHANGES change(s) — $NOW"
else
  echo "librarian: no-op"
fi
