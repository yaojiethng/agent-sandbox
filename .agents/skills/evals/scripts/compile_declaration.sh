#!/usr/bin/env bash
# compile_declaration.sh -- build a run declaration from a case and an experiment.
#
# usage: compile_declaration.sh <case.json> <experiment.json> --out=<declaration.json>
#
# The case holds what the task is: its subject, its instruction and its rubric.
# The experiment holds how the run is built and judged: the fixture, the
# configurations, the measure, the decision and the design. The declaration is
# the generated union the runner reads, with the fixture hashes computed here so
# no hash is hand-maintained. The runner's --check validates the result.
set -uo pipefail

CASE="${1:?usage: compile_declaration.sh <case.json> <experiment.json> --out=<declaration.json>}"
EXP="${2:?usage: compile_declaration.sh <case.json> <experiment.json> --out=<declaration.json>}"
OUT=""
shift 2
for arg in "$@"; do
  case "$arg" in
  --out=*) OUT="${arg#*=}" ;;
  *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done
[[ -n "$OUT" ]] || { echo "--out is required" >&2; exit 2; }
[[ -f "$CASE" ]] || { echo "case not found: $CASE" >&2; exit 2; }
[[ -f "$EXP" ]] || { echo "experiment not found: $EXP" >&2; exit 2; }
jq -e '.harness | type == "object"' "$EXP" >/dev/null 2>&1 \
  || { echo "experiment carries no harness object: $EXP" >&2; exit 2; }

expand_home() {
  local v="$1"
  v="${v/#\~/$HOME}"
  v="${v/#\$HOME/$HOME}"
  printf '%s\n' "$v"
}

fixture_root="$(jq -r '.harness.fixture_root // empty' "$EXP")"
[[ -n "$fixture_root" ]] || { echo "experiment harness.fixture_root is missing" >&2; exit 2; }
fixture_root="$(expand_home "$fixture_root")"

hash_of() { # <value> -> the hash of fixture_root/value, or fail
  local rel base
  rel="$(expand_home "$1")"
  case "$rel" in
  /*) base="$rel" ;;
  *) base="${fixture_root%/}/$rel" ;;
  esac
  [[ -f "$base" ]] || { echo "fixture file does not resolve: $base" >&2; return 1; }
  sha256sum "$base" | awk '{print $1}'
}

bundle_sha="$(hash_of "$(jq -r '.harness.bundle // empty' "$EXP")")" || exit 2
patch_sha="$(hash_of "$(jq -r '.harness.patch // empty' "$EXP")")" || exit 2

tmp="${OUT}.tmp.$$"
trap 'rm -f "$tmp"' EXIT
jq -s '.[0] + {harness: .[1].harness}' "$CASE" "$EXP" \
  | jq --arg b "$bundle_sha" --arg p "$patch_sha" \
    '.harness.fixture_sha256 = {bundle: $b, patch: $p}' >"$tmp" \
  || { echo "could not merge the case and the experiment" >&2; exit 2; }
mv "$tmp" "$OUT"
printf 'declaration: %s\n' "$OUT"
