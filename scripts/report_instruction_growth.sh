#!/usr/bin/env bash
# scripts/report_instruction_growth.sh
# Reports how each instruction artifact has grown, and how much of that growth
# was appending: a commit that added lines and deleted none.
#
# This is a report, not a gate. It refuses nothing and sets no threshold, because
# a threshold chosen before a baseline exists is how a gate gets bypassed. What
# it prints is the sentence that changes the next edit: a file that grew in most
# of its recent commits, none of which removed anything.
#
# Why appending is the number. Instruction text accumulates because keeping a
# line is free and the line a fix supersedes is never named.
#
# Usage:
#   bash scripts/report_instruction_growth.sh [path ...] [--detail] [--root <dir>]
#
# With no path it reads the instruction artifacts: both `AGENTS.md` layers, every
# skill `SKILL.md` that ships, and every prompt.
#
# Columns: lines now, commits touching it, commits that grew it, commits that
# deleted nothing, and the newest commit that made it smaller.
#
# Environment:
#   INSTRUCTION_GROWTH_ROOT   read another repository's history; the test seam.

set -uo pipefail

ROOT="${INSTRUCTION_GROWTH_ROOT:-}"
DETAIL=0
TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --detail) DETAIL=1 ;;
    --root) shift; ROOT="${1:-}" ;;
    -h|--help) sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) TARGETS+=("$1") ;;
  esac
  shift
done

if [[ -z "$ROOT" ]]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi

if [[ -z "$ROOT" || ! -d "$ROOT/.git" ]]; then
  echo "report_instruction_growth: not a git repository: ${ROOT:-<none>}" >&2
  exit 2
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  mapfile -t TARGETS < <(
    printf '%s\n' AGENTS.md src/reasoning/providers/pi/config/agent/AGENTS.md
    git -C "$ROOT" ls-files \
      'src/reasoning/agent/skills/*/SKILL.md' \
      'src/reasoning/providers/pi/config/agent/skills/*/SKILL.md' \
      'workflow/coding-agent/skills/*/SKILL.md' \
      'workflow/coding-agent/prompts/*.md' \
      '.agents/skills/*/SKILL.md'
  )
fi

printf 'instruction-artifact growth\nroot: %s\n\n' "$ROOT"
printf '%-58s %6s %8s %6s %7s  %s\n' artifact lines commits grew append last-shrank

status=0
for target in "${TARGETS[@]}"; do
  path="$ROOT/$target"
  if [[ ! -e "$path" ]]; then
    printf '%-58s %6s\n' "$target" absent
    status=1
    continue
  fi

  lines=$(wc -l < "$path" | tr -d ' ')

  # Counted from the numstat fields alone: an added or a deleted count is a bare
  # decimal, and a commit subject may begin with one, so the hash line is the
  # branch that carries no decimal pair.
  history=$(git -C "$ROOT" log --numstat --pretty=format:'%h %s' -- "$target" 2>/dev/null |
    awk -v detail="$DETAIL" '
      NF == 0 { next }
      $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {
        commits++
        if ($1 + 0 > $2 + 0) grew++
        if ($2 + 0 == 0 && $1 + 0 > 0) { append++; if (detail) print "append\t" commit "\t+" $1 }
        if ($2 + 0 > $1 + 0) shrank = commit
        next
      }
      { commit = $1 }
      END { print "SUMMARY\t" commits + 0 "\t" grew + 0 "\t" append + 0 "\t" (shrank == "" ? "-" : shrank) }
    ')

  summary=$(printf '%s\n' "$history" | grep '^SUMMARY')
  read -r _ commits grew append last_shrank <<<"$(printf '%s' "$summary" | tr '\t' ' ')"

  if [[ -z "${commits:-}" || "$commits" == "0" ]]; then
    printf '%-58s %6s %8s\n' "$target" "$lines" "no history"
    continue
  fi

  printf '%-58s %6s %8s %6s %7s  %s\n' "$target" "$lines" "$commits" "$grew" "$append" "$last_shrank"

  if [[ "$DETAIL" == "1" ]]; then
    printf '%s\n' "$history" | awk -F'\t' '$1 == "append" { printf "    append  %s  %s\n", $2, $3 }'
  fi
done

printf '\nreport only: nothing is refused, and no threshold is set.\n'
exit "$status"
