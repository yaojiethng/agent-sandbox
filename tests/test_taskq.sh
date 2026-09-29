#!/usr/bin/env bash
# tests/test_taskq.sh
# TEST_DEADLINE: 180
# The Node/TypeScript conformance suite of the task-queue pi-extension
# (src/reasoning/providers/pi/config/agent/extensions/task-queue): the queue
# invariants I1-I13, the transition table, the ownership lock, the
# persistence and journal, the git-backed fork and bring-back, and the wired
# tool surface, all held against real repositories. The extension has its
# own runner (node --test); this file wires it into the harness so the suite
# cannot rot under `make test`.
#
# One harness unit runs every registered node test file in a single node
# process. A node test file that is not registered here fails the coverage
# guard, so a new file cannot rot while everyone believes the suite runs it.

source "$(dirname "${BASH_SOURCE[0]}")/libs/test_common.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTSQ_DIR="$REPO_ROOT/tests/taskq"

# The registered node test files of the conformance suite.
NODE_TEST_FILES=(
  bench.test.ts
  extension-load.test.ts
  join.test.ts
  lifecycle.test.ts
  lock.test.ts
  merge.test.ts
  ops.test.ts
  protocol.test.ts
  queue.test.ts
  state.test.ts
  transitions.test.ts
  wired.test.ts
  worktree.test.ts
)

# test_taskq_node_suite
#   Runs the whole node conformance suite and reports its passing tests as
#   harness units. A failing suite is one failing unit with the node output
#   attached, so the failure names its file in the subtest list.
test_taskq_node_suite() {
  local out rc pass fail skipped
  out="$(cd "$REPO_ROOT" && node --test "$TESTSQ_DIR"/*.test.ts 2>&1)"
  rc=$?
  pass="$(printf '%s\n' "$out" | sed -n 's/^# pass \([0-9][0-9]*\)$/\1/p' | tail -1)"
  fail="$(printf '%s\n' "$out" | sed -n 's/^# fail \([0-9][0-9]*\)$/\1/p' | tail -1)"
  skipped="$(printf '%s\n' "$out" | sed -n 's/^# skipped \([0-9][0-9]*\)$/\1/p' | tail -1)"
  pass="${pass:-0}"
  fail="${fail:-0}"
  skipped="${skipped:-0}"
  if [[ "$rc" -eq 0 && "$fail" -eq 0 && "$pass" -gt 0 ]]; then
    pass "taskq node conformance ($pass tests)"
  elif [[ "$rc" -eq 0 && "$fail" -eq 0 && "$pass" -eq 0 && "$skipped" -gt 0 ]]; then
    skip "taskq node conformance (${skipped} tests skipped)"
  else
    printf '%s\n' "$out" >&2
    fail "taskq node conformance (node rc=$rc)"
  fi
}

# test_taskq_node_coverage
#   Registration guard: every node test file under tests/taskq/ must be
#   named in NODE_TEST_FILES above, so a new file cannot rot while everyone
#   believes the suite runs it.
test_taskq_node_coverage() {
  local f base registered=0
  for f in "$TESTSQ_DIR"/*.test.ts; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f")"
    if printf '%s\n' "${NODE_TEST_FILES[@]}" | grep -qxF "$base"; then
      registered=$((registered + 1))
    else
      fail "no wrapper unit in test_taskq.sh for $base"
    fi
  done
  pass "every node test file has a wrapper unit ($registered files)"
}

run_test test_taskq_node_suite
run_test test_taskq_node_coverage

test_done