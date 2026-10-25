#!/usr/bin/env bash
# tests/test_model_failover.sh
# TEST_DEADLINE: 300
# The Node/TypeScript suite of the model-failover pi-extension
# (src/reasoning/providers/pi/config/agent/extensions/model-failover): the
# route health machine and its transitions, the dispatch walk and its tiers,
# the declarations loader, the error classification, the report, the pi
# wiring, the invariant report, the diagram-to-suite mapping check, and the
# mutation gate that replays a catalog of deliberate breaks. The extension
# has its own runner (`node --test`); this file wires it into the harness so
# the suite cannot rot under `make test`.
#
# One harness unit runs every registered node test file in a single node
# process. A node test file that is not registered here fails the coverage
# guard, so a new file cannot rot while everyone believes the suite runs it.
#
# The extension writes its ledger beside itself; point MODEL_FAILOVER_LEDGER
# at a temp file so the suite never writes into the repository tree. The
# mutation gate copies the extension and the suite into a temp mirror per row
# and runs a child process per row, so the deadline above leaves room for it
# on a busy host.

source "$(dirname "${BASH_SOURCE[0]}")/libs/test_common.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MF_DIR="$REPO_ROOT/tests/extensions/pi/model-failover"

# The registered node test files of the extension suite. Two of them are gates
# over the suite rather than cases in it: `mapping.test.ts` is the
# diagram-to-suite mapping check, and `mutation.test.ts` replays a catalog of
# deliberate breaks and fails unless the suite turns red against each one.
NODE_TEST_FILES=(
  adaptor.test.ts
  classify.test.ts
  config.test.ts
  edge-ledger.test.ts
  edges.test.ts
  invariants.test.ts
  ledger.test.ts
  mapping.test.ts
  mutation.test.ts
  pinned-fetch.test.ts
  replay.test.ts
  report.test.ts
  router.test.ts
  wire.test.ts
)

# test_model_failover_node_suite
#   Runs the whole node suite and reports its passing tests as harness units. A
#   failing suite is one failing unit with the node output attached, so the
#   failure names its file in the subtest list.
test_model_failover_node_suite() {
  local out rc pass fail skipped ledger_file
  ledger_file="$(mktemp -t model-failover-ledger.XXXXXX)"
  rm -f "$ledger_file"
  out="$(cd "$REPO_ROOT" && MODEL_FAILOVER_ENABLED=1 MODEL_FAILOVER_LEDGER="$ledger_file" node --test "$MF_DIR"/*.test.ts 2>&1)"
  rc=$?
  rm -f "$ledger_file"
  pass="$(printf '%s\n' "$out" | sed -n 's/^# pass \([0-9][0-9]*\)$/\1/p' | tail -1)"
  fail="$(printf '%s\n' "$out" | sed -n 's/^# fail \([0-9][0-9]*\)$/\1/p' | tail -1)"
  skipped="$(printf '%s\n' "$out" | sed -n 's/^# skipped \([0-9][0-9]*\)$/\1/p' | tail -1)"
  pass="${pass:-0}"
  fail="${fail:-0}"
  skipped="${skipped:-0}"
  if [[ $rc -eq 0 && $fail -eq 0 && $pass -gt 0 ]]; then
    pass "model-failover node suite ($pass tests)"
  elif [[ $rc -eq 0 && $fail -eq 0 && $pass -eq 0 && $skipped -gt 0 ]]; then
    skip "model-failover node suite (${skipped} tests skipped)"
  else
    printf '%s\n' "$out" >&2
    fail "model-failover node suite (node rc=$rc)"
  fi
}

# test_model_failover_node_coverage
#   Registration guard: every node test file under the extension's test folder
#   must be named in NODE_TEST_FILES above, so a new file cannot rot while
#   everyone believes the suite runs it.
test_model_failover_node_coverage() {
  local f base registered=0
  for f in "$MF_DIR"/*.test.ts; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f")"
    if printf '%s\n' "${NODE_TEST_FILES[@]}" | grep -qxF "$base"; then
      registered=$((registered + 1))
    else
      fail "no wrapper unit in test_model_failover.sh for $base"
    fi
  done
  pass "every node test file has a wrapper unit ($registered files)"
}

run_test test_model_failover_node_suite
run_test test_model_failover_node_coverage

test_done
