#!/usr/bin/env bash
# scripts/check_record_citations.sh
# The record citation gate: every dated record citation in a roadmap resolves
# in the tree that carries it. The roadmap paths and the Markdown link form are
# this project's task-list convention's; the history-cleanup audit applies this
# gate at each commit through its per-commit gate loop.
#
# Usage: bash scripts/check_record_citations.sh [--root=DIR]
# Exit:  0 = no finding, 1 = a finding. A missing roadmap is skipped.

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$REPO_ROOT"
for arg in "$@"; do
  case "$arg" in
  --root=*) ROOT="${arg#*=}" ;;
  *)
    echo "Record citation gate: unknown option: $arg" >&2
    exit 2
    ;;
  esac
done

if [[ ! -d "$ROOT" ]]; then
  echo "Record citation gate: $ROOT is not a directory; cannot run." >&2
  exit 1
fi

ROADMAPS=("devlog/roadmap.md" "devlog/roadmap_future.md")
findings=0

for f in "${ROADMAPS[@]}"; do
  [[ -f "$ROOT/$f" ]] || continue
  while IFS= read -r target; do
    [[ -n "$target" ]] || continue
    case "$target" in http*) continue ;; esac
    if [[ ! -e "$ROOT/devlog/$target" ]]; then
      echo "citation does not resolve: $f -> $target"
      findings=$((findings + 1))
    fi
  done < <(grep -oE '\]\([^)]*2026[0-9]{4}-[0-9]{2}[^)]*\.md\)' "$ROOT/$f" | sed -e 's/^](//' -e 's/)$//' -e 's/#.*//' | sort -u)
done

if ((findings > 0)); then
  echo "Record citation gate: $findings finding(s)"
  exit 1
fi

echo "Clean (${SECONDS}s)"
