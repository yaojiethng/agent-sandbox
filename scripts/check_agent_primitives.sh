#!/usr/bin/env bash
# scripts/check_agent_primitives.sh
# The branch-preparation gate: the prepare runbook exists, the retirements
# (the two change prompts and the scheduler prompt) are gone, and no live
# file still names them. Historical records under devlog/ and
# docs/adr/archive/ are excluded.
#
#   check_agent_primitives.sh [--root=DIR]

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for arg in "$@"; do
  case "$arg" in
    --root=*) ROOT="${arg#--root=}" ;;
    *) echo "usage: check_agent_primitives.sh [--root=DIR]" >&2; exit 2 ;;
  esac
done

fail=0
runbook="$ROOT/.agents/skills/git-discipline/references/prepare.md"
if [ ! -f "$runbook" ]; then
  echo "agent primitives: missing $runbook" >&2
  fail=1
fi

for name in prepare-rebase accept-fast-forward merge-queue; do
  path="$ROOT/workflow/coding-agent/prompts/$name.md"
  if [ -e "$path" ]; then
    echo "agent primitives: retired prompt present: $path" >&2
    fail=1
  fi
done

hits="$(grep -rlE 'prepare-rebase|accept-fast-forward|merge-queue' "$ROOT" \
  --exclude-dir=.git --exclude-dir=devlog --exclude-dir=archive \
  --exclude-dir=tests --exclude-dir=scripts --exclude-dir=.scratchpad 2>/dev/null || true)"
if [ -n "$hits" ]; then
  echo "agent primitives: live files still name a retired prompt:" >&2
  printf '%s\n' "$hits" >&2
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "agent primitives: clean"
fi
exit "$fail"
