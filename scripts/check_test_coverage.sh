#!/usr/bin/env bash
# scripts/check_test_coverage.sh
# Given changed file paths, prints which test files reference each.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/../tests"

usage() {
  echo "Usage: bash scripts/check_test_coverage.sh <file> [<file> ...]"
  exit 1
}

check_file() {
  local FILE="$1"
  local BASENAME
  BASENAME="$(basename "$FILE")"
  echo "$FILE:"

  local MATCHES
  MATCHES=$(grep -rl "$BASENAME" "$TEST_DIR" 2>/dev/null | grep -v "^$TEST_DIR/libs/" || true)

  if [[ -z "$MATCHES" ]]; then
    echo "  (no test files found — review whether coverage is needed)"
  else
    while IFS= read -r MATCH; do
      [[ -n "$MATCH" ]] || continue
      local REL
      REL="${MATCH#$TEST_DIR/}"
      echo "  $REL"
    done <<< "$MATCHES"
  fi
  echo ""
}

main() {
  if [[ $# -eq 0 ]]; then
    usage
  fi

  for FILE in "$@"; do
    check_file "$FILE"
  done
}

main "$@"
