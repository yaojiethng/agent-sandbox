#!/usr/bin/env bash
# Audits a rewritten range: the eight checks `history-cleanup` names.
#
#   bash scripts/audit.sh <base> [tip] [options]
#
# Options:
#   --reference=<ref>   the tip the rewrite must reproduce; check 4 is skipped without it
#   --gate=<path>       the gate to run per commit (default scripts/lint.sh)
#   --records=<dir>     the record root (default devlog/handovers)
#   --manifest=<file>   rows of "sha<TAB>subject<TAB>paths"; check 7 is skipped without it
#   --gate=<path>       the gate to run per commit (default scripts/lint.sh); it always runs
#
# Exit: 0 = no finding, 1 = a finding. Inversions are reported, never counted as
# findings: a rewrite collapses them by construction and the caller classifies each.
#
# A check that has never failed is not a check. Run this against a range that
# violates one before trusting a clean result.

set -uo pipefail

BASE="${1:-}"
[[ -n "$BASE" ]] || { echo "audit: usage: audit.sh <base> [tip] [options]" >&2; exit 2; }
shift
TIP="HEAD"
REF=""
GATE="scripts/lint.sh"
RECORDS="devlog/handovers"
MANIFEST=""
ADDITIONS=()
for arg in "$@"; do
  case "$arg" in
  --reference=*) REF="${arg#*=}" ;;
  --gate=*) GATE="${arg#*=}" ;;
  --records=*) RECORDS="${arg#*=}" ;;
  --manifest=*) MANIFEST="${arg#*=}" ;;
  --addition=*) ADDITIONS+=("${arg#*=}") ;;
  --*) echo "audit: unknown option: $arg" >&2; exit 2 ;;
  *) TIP="$arg" ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel)" || exit 2
cd "$ROOT" || exit 2
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
findings=0
note() { echo "  note   $*"; }
finding() { echo "  FIND   $*"; findings=$((findings + 1)); }
check() { echo "$*"; }

COMMITS=$(git rev-list --reverse "$BASE".."$TIP")

check "1. record added once"
added=$(git log --diff-filter=A --name-only --format= "$BASE".."$TIP" -- "$RECORDS" | sort -u)
for p in $added; do
  n=$(git log --diff-filter=A --format=%H "$BASE".."$TIP" -- "$p" | wc -l)
  [[ "$n" -eq 1 ]] || finding "record added $n times: $p"
  birth=$(git log --diff-filter=A --format=%H "$BASE".."$TIP" -- "$p" | tail -1)
  if git cat-file -e "$TIP:$p" 2>/dev/null; then
    [[ "$(git rev-parse "$birth:$p")" == "$(git rev-parse "$TIP:$p")" ]] || finding "record rewritten after birth: $p"
  fi
done
[[ -n "$added" ]] || note "no record added in the range"

check "2. citation resolves at its commit"
for f in devlog/roadmap.md devlog/roadmap_future.md; do
  for c in $(git log --format=%H "$BASE".."$TIP" -- "$f"); do
    for t in $(git show "$c:$f" 2>/dev/null | grep -oE '\]\([^)]*2026[0-9]{4}-[0-9]{2}[^)]*\.md\)' | sed -e 's/^](//' -e 's/)$//' -e 's/#.*//' | sort -u); do
      case "$t" in http*) continue ;; esac
      git cat-file -e "$c:devlog/$t" 2>/dev/null || finding "citation does not resolve at ${c:0:8}: $t"
    done
  done
done

check "3. nothing born and buried"
for p in $(git log --diff-filter=A --name-only --format= "$BASE".."$TIP" | sort -u); do
  git cat-file -e "$TIP:$p" 2>/dev/null || finding "added then deleted inside the range: $p"
done

check "4. tip content identity"
if [[ -n "$REF" ]]; then
  skip=""
  for a in "${ADDITIONS[@]:-}"; do [ -n "$a" ] && skip="$skip|$a"; done
  delta=$(diff <(git ls-tree -r "$REF" | grep -v "/$RECORDS/" | grep -vE "${skip:-^$}") <(git ls-tree -r "$TIP" | grep -v "/$RECORDS/" | grep -vE "${skip:-^$}"))
  if [[ -n "$delta" ]]; then
    finding "non-record content differs from $REF"
    echo "$delta" | sed 's/^/         /' | head -20
  fi
else
  note "skipped: pass --reference=<ref> to compare against the tip being reproduced"
fi

check "5. each commit passes its own gate"
wt=$(mktemp -d)
git worktree add -q --detach "$wt" "$BASE" 2>/dev/null
for c in $COMMITS; do
  git -C "$wt" checkout -q --detach "$c" 2>/dev/null
  if ( cd "$wt" && bash "$GATE" >/dev/null 2>&1 ); then :; else finding "gate fails at ${c:0:8} $(git log -1 --format=%s "$c" | cut -c1-50)"; fi
done
git worktree remove --force "$wt" 2>/dev/null

check "6. no silent empty unit"
for c in $COMMITS; do
  changed=$(git diff --name-only "$c^" "$c")
  [[ -n "$changed" ]] || finding "empty commit ${c:0:8}"
  if [[ -n "$changed" ]] && [[ -z "$(echo "$changed" | grep -v "^$RECORDS/")" ]]; then
    note "record-only commit ${c:0:8} -- the manifest must declare it"
  fi
done

check "7. manifest conformance"
if [[ -n "$MANIFEST" ]]; then
  while IFS=$'\t' read -r sha subject paths; do
    [[ -n "$sha" ]] || continue
    git cat-file -e "$sha^{commit}" 2>/dev/null || { finding "manifest names a missing commit: $sha"; continue; }
    actual=$(git log -1 --format=%s "$sha")
    [[ "$actual" == "$subject" ]] || finding "manifest subject differs at ${sha:0:8}: '$actual'"
    for p in ${paths//,/ }; do
      git cat-file -e "$sha:$p" 2>/dev/null || finding "manifest path absent at ${sha:0:8}: $p"
    done
  done <"$MANIFEST"
else
  note "skipped: pass --manifest=<file> to check the series against the approved manifest"
fi

check "8. inversions (reported, not counted)"
node "$HERE/inversions.mjs" "$BASE" "$TIP" 2>/dev/null | sed -n '/^none$/p;/^total /p' | sed 's/^/  /'

echo
if [[ "$findings" -eq 0 ]]; then
  echo "audit: clean across 8 checks"
  exit 0
fi
echo "audit: $findings finding(s)"
exit 1
