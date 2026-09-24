#!/usr/bin/env bash
# tests/test_lib_contract.sh
# Behavioural tests for scripts/check_lib_contract.sh -- the sourced-library
# contract gate over src/libs/ and src/build/.
#
# Covers:
#   clean lib            --  functions use return; rc 0
#   function exit        --  exit in a function body fails, naming the file
#   exec-guard exit      --  top-level exit inside the BASH_SOURCE[0] guard
#                            passes (main flow may exit)
#   quoted exit          --  an `exit` inside an echo string is not a finding
#   unguarded read       --  `done < "$f"` without a guard fails
#   guarded read         --  `[[ -f "$f" ]] || return 0` before the read passes
#   missing scan root    --  fails closed
#   real tree guard      --  the current tree carries zero findings
#
# Fixtures live under the LIB_CONTRACT_SCAN_ROOT seam; the gate reads
# <root>/src/libs and <root>/src/build. The real-tree guard runs without the
# seam, so a regression in src/libs or src/build fails this test.
#
# Run:   bash tests/test_lib_contract.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_lib_contract.sh"
GATE_RC=0
GATE_OUT=""

# make_scan DIR  --  an empty fixture scan tree (src/libs + src/build dirs).
make_scan() {
  local dir="$1"
  mkdir -p "$dir/src/libs" "$dir/src/build"
}

# run_gate DIR  --  run the real gate against the fixture scan root.
run_gate() {
  local dir="$1"
  GATE_RC=0
  GATE_OUT="$(LIB_CONTRACT_SCAN_ROOT="$dir" bash "$GATE" 2>&1)" || GATE_RC=$?
}

test_gate_passes_clean_lib() {
  local dir="$FIXTURE_DIR/clean"
  make_scan "$dir"
  cat > "$dir/src/libs/good.sh" <<'EOF'
#!/usr/bin/env bash
read_state() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  return 1
}
EOF

  run_gate "$dir"
  assert_rc 0 "$GATE_RC" "a conforming lib passes the gate"
  assert_contains "$GATE_OUT" "Clean" "gate reports Clean"
}

test_function_exit_fails() {
  local dir="$FIXTURE_DIR/bad_exit"
  make_scan "$dir"
  cat > "$dir/src/libs/bad.sh" <<'EOF'
#!/usr/bin/env bash
fail_hard() {
  echo "boom" >&2
  exit 1
}
EOF

  run_gate "$dir"
  assert_ne "$GATE_RC" "0" "a function exit fails the gate"
  assert_contains "$GATE_OUT" "bad.sh:4" "gate names the file and line"
  assert_contains "$GATE_OUT" "return" "gate points at the return convention"
}

test_exec_guard_exit_passes() {
  local dir="$FIXTURE_DIR/guard"
  make_scan "$dir"
  cat > "$dir/src/libs/main.sh" <<'EOF'
#!/usr/bin/env bash
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  parse_args -- "$@"
  [ $? -eq 2 ] && exit 0
  exit 1
fi
EOF

  run_gate "$dir"
  assert_rc 0 "$GATE_RC" "a top-level exit inside the exec guard passes"
}

test_quoted_exit_not_flagged() {
  local dir="$FIXTURE_DIR/quoted"
  make_scan "$dir"
  cat > "$dir/src/libs/msg.sh" <<'EOF'
#!/usr/bin/env bash
report() {
  echo "the process ended (exit $?)" >&2
  return 0
}
EOF

  run_gate "$dir"
  assert_rc 0 "$GATE_RC" "an exit inside a quoted string is not a finding"
}

test_unguarded_read_fails() {
  local dir="$FIXTURE_DIR/bad_read"
  make_scan "$dir"
  cat > "$dir/src/libs/load.sh" <<'EOF'
#!/usr/bin/env bash
load_file() {
  local file="$1"
  while IFS='=' read -r k v; do
    echo "$k"
  done < "$file"
}
EOF

  run_gate "$dir"
  assert_ne "$GATE_RC" "0" "an unguarded while-read redirect fails the gate"
  assert_contains "$GATE_OUT" "load.sh:6" "gate names the file and line"
  assert_contains "$GATE_OUT" '$file' "gate names the guarded variable"
}

test_guarded_read_passes() {
  local dir="$FIXTURE_DIR/good_read"
  make_scan "$dir"
  cat > "$dir/src/libs/load.sh" <<'EOF'
#!/usr/bin/env bash
load_file() {
  local file="$1"
  [[ ! -f "$file" ]] && return 0
  while IFS='=' read -r k v; do
    echo "$k"
  done < "$file"
  return 0
}
EOF

  run_gate "$dir"
  assert_rc 0 "$GATE_RC" "a -f-guarded while-read redirect passes"
}

test_missing_scan_root_fails_closed() {
  local dir="$FIXTURE_DIR/missing"
  mkdir -p "$dir/src"
  GATE_RC=0
  GATE_OUT="$(LIB_CONTRACT_SCAN_ROOT="$dir" bash "$GATE" 2>&1)" || GATE_RC=$?
  assert_ne "$GATE_RC" "0" "a missing libs dir fails the gate closed"
  assert_contains "$GATE_OUT" "missing" "gate explains the missing directory"
}

test_real_tree_is_clean() {
  GATE_RC=0
  GATE_OUT="$(bash "$GATE" 2>&1)" || GATE_RC=$?
  assert_rc 0 "$GATE_RC" "the current src/libs and src/build carry zero contract findings"
}

run_test test_gate_passes_clean_lib
run_test test_function_exit_fails
run_test test_exec_guard_exit_passes
run_test test_quoted_exit_not_flagged
run_test test_unguarded_read_fails
run_test test_guarded_read_passes
run_test test_missing_scan_root_fails_closed
run_test test_real_tree_is_clean

test_done