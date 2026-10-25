#!/usr/bin/env bash
# tests/test_dispatch_machine.sh
# TEST_DEADLINE: 120
# The Node/TypeScript suite of the dispatch library (src/libs/dispatch): the
# declared classification patterns, the route availability machine and its
# transition table, the resolution selector, the session memory, the role table
# and its argv shapes, and the mapping check that holds the suite to the table.
#
# The suite has its own runner (`node --test`); this file wires it into the
# harness so it cannot rot under `make test`. A test file that exists but is
# not registered below fails the registration case, so a new file cannot sit
# unrun while everyone believes the suite covers it.

source "$(dirname "${BASH_SOURCE[0]}")/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MACHINE_TESTS="$REPO_ROOT/tests/dispatch/machine"

NODE_TEST_FILES=(
  classify.test.ts
  machine.test.ts
  mapping.test.ts
  mutation.test.ts
  state.test.ts
  table.test.ts
)

test_node_suite() {
  local out rc
  local -a args=()
  local f
  for f in "${NODE_TEST_FILES[@]}"; do args+=("$MACHINE_TESTS/$f"); done
  out="$(node --test "${args[@]}" 2>&1)"
  rc=$?
  assert_rc "$rc" 0 "the dispatch machine suite passes"
  assert_contains "$out" "# fail 0" "no case fails"
}

test_registration_covers_the_directory() {
  local on_disk registered f missing=""
  on_disk="$(cd "$MACHINE_TESTS" && ls *.test.ts | sort)"
  registered="$(printf '%s\n' "${NODE_TEST_FILES[@]}" | sort)"
  if [[ "$on_disk" != "$registered" ]]; then
    missing="$(comm -23 <(printf '%s\n' "$on_disk") <(printf '%s\n' "$registered"))"
  fi
  assert_empty "$missing" "every test file in the directory is registered"
}

run_test test_node_suite
run_test test_registration_covers_the_directory

test_done
