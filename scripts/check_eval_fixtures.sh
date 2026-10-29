#!/usr/bin/env bash
# scripts/check_eval_fixtures.sh
# Holds a frozen eval fixture to its manifest: every file a `SHA256SUMS` names
# must still hash to the value it names, and every file in the fixture must be
# named by it.
#
# Why a gate. A fixture is a copy of text that was live somewhere else, kept so
# that an eval grades against one revision forever. Nothing about a copied
# Markdown file announces that it is frozen, so a find and replace across the
# tree rewrites it and leaves every test green: the fixture is then a different
# subject than the one the case was built on, and the failure surfaces much
# later, as an eval that measures something nobody chose. The manifest is the
# only thing that can notice, and nothing reads a manifest unless a check does.
#
# Both directions are checked, within a fixture's subdirectories: a changed file
# is a corrupted fixture, and a file the manifest does not name is one that
# arrived without provenance, which is how a fixture stops being frozen while
# keeping its name. A fixture's own root files describe it rather than freeze it.
#
# A fixture holding no manifest is reported rather than passed: a frozen copy
# with no hash is a claim that nothing will ever change it.
#
# Usage: bash scripts/check_eval_fixtures.sh [root]
# Exit:  0 = every fixture matches its manifest, 1 = a finding

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="${1:-${EVAL_FIXTURE_ROOT:-$REPO_ROOT/tests/eval}}"

if [[ ! -d "$ROOT" ]]; then
  echo "check_eval_fixtures: no such fixture root: $ROOT" >&2
  exit 2
fi

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

findings=0
fixtures=0

while IFS= read -r manifest; do
  dir="$(dirname "$manifest")"
  fixtures=$((fixtures + 1))
  rel="${dir#"$ROOT"/}"

  declare -A named=()

  while read -r want name; do
    [[ -z "${want:-}" || "${want:0:1}" == "#" ]] && continue
    name="${name#\*}"
    named["$name"]=1
    if [[ ! -f "$dir/$name" ]]; then
      echo "MISSING  $rel/$name  named by the manifest and not on disk"
      findings=$((findings + 1))
      continue
    fi
    got="$(hash_file "$dir/$name")"
    if [[ "$got" != "$want" ]]; then
      echo "CHANGED  $rel/$name  hash $got, manifest says $want"
      findings=$((findings + 1))
    fi
  done <"$manifest"

  while IFS= read -r path; do
    name="${path#"$dir"/}"
    if [[ -z "${named[$name]:-}" ]]; then
      echo "UNNAMED  $rel/$name  present and not in the manifest"
      findings=$((findings + 1))
    fi
  done < <(find "$dir" -mindepth 2 -type f | sort)
done < <(find "$ROOT" -mindepth 2 -maxdepth 2 -name SHA256SUMS | sort)

# A fixture directory with no manifest at all.
while IFS= read -r dir; do
  [[ -f "$dir/SHA256SUMS" ]] && continue
  echo "NOMANIFEST  ${dir#"$ROOT"/}  a frozen fixture holds no SHA256SUMS, so nothing can report it changing"
  findings=$((findings + 1))
done < <(find "$ROOT" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ "$findings" -gt 0 ]]; then
  echo "Eval-fixture gate: $findings finding(s) across $fixtures fixture(s) with a manifest."
  exit 1
fi

echo "Eval-fixture gate: clean across $fixtures fixture(s)."
