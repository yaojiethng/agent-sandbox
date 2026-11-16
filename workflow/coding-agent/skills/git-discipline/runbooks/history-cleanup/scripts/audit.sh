#!/usr/bin/env bash
# Audits a rewritten range: the seven checks `history-cleanup` names.
#
#   bash scripts/audit.sh <base> [tip] [options]
#
# Options:
#   --reference=<ref>   the tip the rewrite must reproduce; check 3 is skipped without it
#   --gate=<path>       the gate to run per commit (default scripts/lint.sh)
#   --records=<dir>     the record root (default: empty; check 1 is skipped)
#   --record-paths=<p>  comma-separated record paths for check 3 (default: empty; excludes none)
#   --manifest=<file>   rows of "sha<TAB>subject<TAB>paths"; check 6 is skipped without it
#   --addition=<path>   a path check 3 excludes as an approved addition
#
# Exit: 0 = no finding, 1 = a finding. Inversions are reported, never counted as
# findings: a rewrite collapses them by construction and the caller classifies each.
#
# Citation resolution is the project's gate, run at each commit by check 4; the
# audit does not parse a record's link syntax.

set -uo pipefail

BASE="${1:-}"
[[ -n "$BASE" ]] || { echo "audit: usage: audit.sh <base> [tip] [options]" >&2; exit 2; }
shift
TIP="HEAD"
REF=""
GATE="scripts/lint.sh"
RECORDS=""
RECORD_PATHS=""
MANIFEST=""
ADDITIONS=()
for arg in "$@"; do
  case "$arg" in
  --reference=*) REF="${arg#*=}" ;;
  --gate=*) GATE="${arg#*=}" ;;
  --records=*) RECORDS="${arg#*=}" ;;
  --record-paths=*) RECORD_PATHS="${arg#*=}" ;;
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

escape_re() { printf '%s' "$1" | sed 's/[.[\*^$()+?{}|]/\\&/g'; }

# Check 3 holds content fixed and lets records move. The record set is the
# caller's: the root plus the listed record paths.
record_paths_regex() {
  local rp esc out="" extra=()
  local -a paths=()
  [[ -n "$RECORDS" ]] && paths+=("$RECORDS")
  if [[ -n "$RECORD_PATHS" ]]; then
    IFS=',' read -r -a extra <<< "$RECORD_PATHS"
    paths+=("${extra[@]}")
  fi
  if [[ ${#paths[@]} -gt 0 ]]; then
    for rp in "${paths[@]}"; do
      [[ -n "$rp" ]] || continue
      esc=$(escape_re "$rp")
      out="${out:+$out|}$esc"
    done
  fi
  printf '%s' "$out"
}

COMMITS=$(git rev-list --reverse "$BASE".."$TIP")

check "1. record added once"
if [[ -n "$RECORDS" ]]; then
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
else
  note "skipped: no record root (--records=)"
fi

check "2. nothing born and buried"
for p in $(git log --diff-filter=A --name-only --format= "$BASE".."$TIP" | sort -u); do
  git cat-file -e "$TIP:$p" 2>/dev/null || finding "added then deleted inside the range: $p"
done

check "3. tip content identity"
if [[ -n "$REF" ]]; then
  record_re=$(record_paths_regex)
  add_re=""
  for a in "${ADDITIONS[@]:-}"; do
    [[ -n "$a" ]] || continue
    esc=$(escape_re "$a")
    add_re="${add_re:+$add_re|}$esc"
  done
  exclude_record() { if [[ -n "$record_re" ]]; then grep -vE "(^|[[:space:]])($record_re)(/|$)"; else cat; fi; }
  exclude_add() { if [[ -n "$add_re" ]]; then grep -vE "(^|[[:space:]])($add_re)(/|$)"; else cat; fi; }
  delta=$(diff <(git ls-tree -r "$REF" | exclude_record | exclude_add) <(git ls-tree -r "$TIP" | exclude_record | exclude_add))
  if [[ -n "$delta" ]]; then
    finding "non-record content differs from $REF"
    echo "$delta" | sed 's/^/         /' | head -20
  fi
else
  note "skipped: pass --reference=<ref> to compare against the tip being reproduced"
fi

check "4. each commit passes its own gate"
wt=$(mktemp -d)
git worktree add -q --detach "$wt" "$BASE" 2>/dev/null
for c in $COMMITS; do
  git -C "$wt" checkout -q --detach "$c" 2>/dev/null
  if ( cd "$wt" && bash "$GATE" >/dev/null 2>&1 ); then :; else finding "gate fails at ${c:0:8} $(git log -1 --format=%s "$c" | cut -c1-50)"; fi
done
git worktree remove --force "$wt" 2>/dev/null

check "5. no silent empty unit"
for c in $COMMITS; do
  changed=$(git diff --name-only "$c^" "$c")
  [[ -n "$changed" ]] || finding "empty commit ${c:0:8}"
  if [[ -n "$RECORDS" ]] && [[ -n "$changed" ]] && [[ -z "$(echo "$changed" | grep -v "^$RECORDS/")" ]]; then
    note "record-only commit ${c:0:8} -- the manifest must declare it"
  fi
done

check "6. manifest conformance"
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

check "7. inversions (reported, not counted)"
node "$HERE/inversions.mjs" "$BASE" "$TIP" 2>/dev/null | sed -n '/^none$/p;/^total /p' | sed 's/^/  /'

echo
if [[ "$findings" -eq 0 ]]; then
  echo "audit: clean across 7 checks"
  exit 0
fi
echo "audit: $findings finding(s)"
exit 1
