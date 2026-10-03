#!/usr/bin/env bash
# tests/test_model_refresh.sh
# TEST_DEADLINE: 600
# The Node/TypeScript suite of the model-refresh pi-extension
# (src/reasoning/providers/pi/config/agent/extensions/model-refresh): the
# catalog union and its source model, the store gate, the fetch paths, the
# thinking-level map and the built request payload, the invariant report, and
# the mutation gate that replays a catalog of deliberate breaks. The extension
# has its own runner (`node --test`); this file wires it into the harness so the
# suite cannot rot under `make test`.
#
# One harness unit runs every registered node test file in a single node
# process. A node test file that is not registered here fails the coverage
# guard, so a new file cannot rot while everyone believes the suite runs it.
#
# The mutation gate copies the extension and the suite into a temp mirror per
# row and runs a child process per row, so the deadline above leaves room for it
# on a busy host.

source "$(dirname "${BASH_SOURCE[0]}")/libs/test_common.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MR_DIR="$REPO_ROOT/tests/extensions/pi/model-refresh"

# The registered node test files of the extension suite. Two of them are gates
# over the suite rather than cases in it: `invariants.test.ts` is the named
# invariant report, and `mutation.test.ts` replays a catalog of deliberate
# breaks and fails unless the suite turns red against each one.
NODE_TEST_FILES=(
  catalog.test.ts
  composition.test.ts
  gather.test.ts
  invariants.test.ts
  load.test.ts
  mutation.test.ts
  report.test.ts
  thinking.test.ts
  wire.test.ts
)

# test_model_refresh_node_suite
#   Runs the whole node suite and reports its passing tests as harness units. A
#   failing suite is one failing unit with the node output attached, so the
#   failure names its file in the subtest list.
test_model_refresh_node_suite() {
  local out rc pass fail skipped
  out="$(cd "$REPO_ROOT" && node --test "$MR_DIR"/*.test.ts 2>&1)"
  rc=$?
  pass="$(printf '%s\n' "$out" | sed -n 's/^# pass \([0-9][0-9]*\)$/\1/p' | tail -1)"
  fail="$(printf '%s\n' "$out" | sed -n 's/^# fail \([0-9][0-9]*\)$/\1/p' | tail -1)"
  skipped="$(printf '%s\n' "$out" | sed -n 's/^# skipped \([0-9][0-9]*\)$/\1/p' | tail -1)"
  pass="${pass:-0}"
  fail="${fail:-0}"
  skipped="${skipped:-0}"
  if [[ "$rc" -eq 0 && "$fail" -eq 0 && "$pass" -gt 0 ]]; then
    pass "model-refresh node suite ($pass tests)"
  elif [[ "$rc" -eq 0 && "$fail" -eq 0 && "$pass" -eq 0 && "$skipped" -gt 0 ]]; then
    skip "model-refresh node suite (${skipped} tests skipped)"
  else
    printf '%s\n' "$out" >&2
    fail "model-refresh node suite (node rc=$rc)"
  fi
}

# test_model_refresh_node_coverage
#   Registration guard: every node test file under the extension's test folder
#   must be named in NODE_TEST_FILES above, so a new file cannot rot while
#   everyone believes the suite runs it.
test_model_refresh_node_coverage() {
  local f base registered=0
  for f in "$MR_DIR"/*.test.ts; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f")"
    if printf '%s\n' "${NODE_TEST_FILES[@]}" | grep -qxF "$base"; then
      registered=$((registered + 1))
    else
      fail "no wrapper unit in test_model_refresh.sh for $base"
    fi
  done
  pass "every node test file has a wrapper unit ($registered files)"
}

run_test test_model_refresh_node_suite
run_test test_model_refresh_node_coverage

test_done
