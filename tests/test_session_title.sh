#!/usr/bin/env bash
# tests/test_session_title.sh
# TEST_DEADLINE: 120
# The Node/TypeScript suite of the session-title pi-extension
# (src/reasoning/agent-runtime/pi/config/agent/extensions/session-title): the
# title format and its empty cases, and the pi wiring that re-asserts the title
# after pi's own writes.
#
# The extension has its own runner (`node --test`); this file wires it into the
# harness so the suite cannot rot under `make test`. A node test file that is
# not registered here fails the coverage guard below.

source "$(dirname "${BASH_SOURCE[0]}")/libs/test_common.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ST_DIR="$REPO_ROOT/tests/extensions/pi/session-title"

# The registered node test files of the extension suite.
NODE_TEST_FILES=(
  title.test.ts
  wire.test.ts
)

# test_session_title_node_suite
#   Runs the whole node suite and reports its passing tests as harness units. A
#   failing suite is one failing unit with the node output attached, so the
#   failure names its file in the subtest list.
test_session_title_node_suite() {
  local out rc pass fail skipped
  out="$(cd "$REPO_ROOT" && node --test "$ST_DIR"/*.test.ts 2>&1)"
  rc=$?
  pass="$(printf '%s\n' "$out" | sed -n 's/^# pass \([0-9][0-9]*\)$/\1/p' | tail -1)"
  fail="$(printf '%s\n' "$out" | sed -n 's/^# fail \([0-9][0-9]*\)$/\1/p' | tail -1)"
  skipped="$(printf '%s\n' "$out" | sed -n 's/^# skipped \([0-9][0-9]*\)$/\1/p' | tail -1)"
  pass="${pass:-0}"
  fail="${fail:-0}"
  skipped="${skipped:-0}"
  if [[ "$rc" -eq 0 && "$fail" -eq 0 && "$pass" -gt 0 ]]; then
    pass "session-title node suite ($pass tests)"
  elif [[ "$rc" -eq 0 && "$fail" -eq 0 && "$pass" -eq 0 && "$skipped" -gt 0 ]]; then
    skip "session-title node suite (${skipped} tests skipped)"
  else
    printf '%s\n' "$out" >&2
    fail "session-title node suite (node rc=$rc)"
  fi
}

# test_session_title_node_coverage
#   Registration guard: every node test file under the extension's test folder
#   must be named in NODE_TEST_FILES above, so a new file cannot rot while
#   everyone believes the suite runs it.
test_session_title_node_coverage() {
  local f base registered=0
  for f in "$ST_DIR"/*.test.ts; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f")"
    if printf '%s\n' "${NODE_TEST_FILES[@]}" | grep -qxF "$base"; then
      registered=$((registered + 1))
    else
      fail "no wrapper unit in test_session_title.sh for $base"
    fi
  done
  pass "every node test file has a wrapper unit ($registered files)"
}

run_test test_session_title_node_suite
run_test test_session_title_node_coverage

test_done
