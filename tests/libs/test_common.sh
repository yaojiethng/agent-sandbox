#!/usr/bin/env bash
# tests/libs/test_common.sh
# Shared test helpers. Source this file, do not execute directly.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: test_common.sh must be sourced, not executed." >&2
  exit 1
fi

: "${PASS:=0}"
: "${FAIL:=0}"
: "${SKIP:=0}"
FAILURES=()
SKIPS=()

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); FAILURES+=("$1"); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); SKIPS+=("$1"); }

# ---------------------------------------------------------------------------
# Docker-trace assertions  --  the standard way to assert on the recorded
# docker stub invocations. DOCKER_TRACE_LOG must be set by the fixture.
#
#   trace_grep PATTERN       --  lines matching PATTERN (or empty)
#   trace_count [--] PATTERN --  count of matching lines (numeric, 0-safe)
#   trace_has PATTERN        --  true when at least one line matches
# ---------------------------------------------------------------------------
trace_grep() {
  grep "$1" "$DOCKER_TRACE_LOG" 2>/dev/null || true
}

trace_count() {
  [[ "$1" == "--" ]] && shift
  local c
  c=$(grep -c "$1" "$DOCKER_TRACE_LOG" 2>/dev/null) || c=0
  echo "$c"
}

trace_has() {
  grep -q "$1" "$DOCKER_TRACE_LOG" 2>/dev/null
}
# run_test NAME
#   Invokes a test function. A test that returns without calling pass/fail/skip
#   is counted as a failure: a silent test proves nothing.
run_test() {
  local _bp=$PASS _bf=$FAIL _bs=$SKIP
  echo "[ $1 ]"
  $1 || true
  if (( PASS + FAIL + SKIP == _bp + _bf + _bs )); then
    echo "  NO-ASSERTION: $1 completed without calling pass/fail/skip" >&2
    FAIL=$((FAIL + 1)); FAILURES+=("$1 (no assertion)")
  fi
}

# ---------------------------------------------------------------------------
# test_setup  --  call at file scope after source lines to get standard vars
# and automatic temp-dir cleanup.
#
# Sets: TEST_DIR, REPO_ROOT, FIXTURE_DIR (mktemp -d)
# Registers: trap 'rm -rf "$FIXTURE_DIR"' EXIT
# ---------------------------------------------------------------------------
# shellcheck disable=SC2034  # REPO_ROOT is consumed by test files after they call test_setup
test_setup() {
  if [[ -z "${BASH_SOURCE[1]:-}" ]]; then
    echo "Error: test_setup must be called from a sourced file, not interactively." >&2
    return 1
  fi
  TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
  FIXTURE_DIR="$(mktemp -d /tmp/XXXXXX)"
  trap 'rm -rf "$FIXTURE_DIR"' EXIT
}

# make_envfile DIR [NAME] [PROJECT_DIR] [SANDBOX_DIR]
#   Writes an identity .env into DIR naming PROJECT_NAME/PROJECT_DIR/SANDBOX_DIR
#   so a test can inject a .env and let the resolver/loader read it, exactly as a
#   real sandbox's .env. One shared fixture helper for every env test.
make_envfile() {
  local dir="$1" name="${2:-envname}" proj="${3:-/tmp/envproj}" sbx="${4:-}"
  mkdir -p "$dir"
  sbx="${sbx:-$dir}"
  printf 'PROJECT_NAME=%s\nPROJECT_DIR=%s\nSANDBOX_DIR=%s\n' "$name" "$proj" "$sbx" > "$dir/.env"
}

test_done() {
  local NAME="${1:-}"
  if [[ -n "$NAME" ]]; then
    echo "=== $NAME ==="
    echo
  fi
  echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo "Failed:"
    # FAIL: prefix  --  scripts/run_tests.sh counts failures by grepping this
    # exact marker from captured output.
    for f in "${FAILURES[@]}"; do echo "  FAIL: $f"; done
  fi
  if [[ ${#SKIPS[@]} -gt 0 ]]; then
    echo "Skipped:"
    for s in "${SKIPS[@]}"; do echo "  - $s"; done
  fi
  exit "$FAIL"
}

# ---------------------------------------------------------------------------
# Assertion helpers  --  the standard way to assert inside a test function.
# Each calls pass/fail itself, so a test body can be one to three lines and
# can never be assertion-less.
#
#   assert_eq ACTUAL EXPECTED [LABEL]       --  string equality
#   assert_ne ACTUAL UNEXPECTED [LABEL]     --  string inequality
#   assert_rc EXPECTED_RC ACTUAL_RC [LABEL]  --  exit-code comparison (integers)
#   assert_contains HAYSTACK NEEDLE [LABEL]  --  substring match (literal)
#   assert_not_contains HAYSTACK NEEDLE [LABEL]  --  inverted substring match
# ---------------------------------------------------------------------------
assert_eq() {
  local ACTUAL="$1" EXPECTED="$2" LABEL="${3:-values equal}"
  if [[ "$ACTUAL" == "$EXPECTED" ]]; then
    pass "$LABEL"
  else
    fail "$LABEL (expected '$EXPECTED', got '$ACTUAL')"
  fi
}

assert_ne() {
  local ACTUAL="$1" UNEXPECTED="$2" LABEL="${3:-values differ}"
  if [[ "$ACTUAL" != "$UNEXPECTED" ]]; then
    pass "$LABEL"
  else
    fail "$LABEL (both values are '$ACTUAL')"
  fi
}

assert_rc() {
  local EXPECTED_RC="$1" ACTUAL_RC="$2" LABEL="${3:-exit code}"
  if [[ "$ACTUAL_RC" == "$EXPECTED_RC" ]]; then
    pass "$LABEL (rc=$ACTUAL_RC)"
  else
    fail "$LABEL (expected rc=$EXPECTED_RC, got rc=$ACTUAL_RC)"
  fi
}

assert_contains() {
  local HAYSTACK="$1" NEEDLE="$2" LABEL="${3:-contains '$2'}"
  if [[ "$HAYSTACK" == *"$NEEDLE"* ]]; then
    pass "$LABEL"
  else
    fail "$LABEL ('$NEEDLE' not found in output)"
  fi
}

# assert_matches ACTUAL PATTERN [LABEL]  --  extended-regex containment.
assert_matches() {
  local ACTUAL="$1" PATTERN="$2" LABEL="${3:-matches}"
  if [[ "$ACTUAL" =~ $PATTERN ]]; then
    pass "$LABEL"
  else
    fail "$LABEL ('$ACTUAL' does not match '$PATTERN')"
  fi
}

# assert_empty STRING [LABEL] -- true when STRING has length zero.
assert_empty() {
  local ACTUAL="$1" LABEL="${2:-empty}"
  if [[ -z "$ACTUAL" ]]; then pass "$LABEL"; else fail "$LABEL (expected empty, got '$ACTUAL')"; fi
}

# assert_not_empty STRING [LABEL] -- true when STRING is non-empty.
assert_not_empty() {
  local ACTUAL="$1" LABEL="${2:-not-empty}"
  if [[ -n "$ACTUAL" ]]; then pass "$LABEL"; else fail "$LABEL (expected non-empty, got empty)"; fi
}

# assert_file_exists FILE [LABEL] -- true when FILE exists.
assert_file_exists() {
  local FILE="$1" LABEL="${2:-file exists}"
  if [[ -f "$FILE" ]]; then pass "$LABEL"; else fail "$LABEL (missing file: $FILE)"; fi
}

# assert_dir_exists DIR [LABEL] -- true when DIR exists and is a directory.
assert_dir_exists() {
  local DIR="$1" LABEL="${2:-dir exists}"
  if [[ -d "$DIR" ]]; then pass "$LABEL"; else fail "$LABEL (missing dir: $DIR)"; fi
}

# assert_not_contains HAYSTACK NEEDLE [LABEL] -- inverted substring match
assert_not_contains() {
  local HAYSTACK="$1" NEEDLE="$2" LABEL="${3:-not-contains '$2'}"
  if [[ "$HAYSTACK" != *"$NEEDLE"* ]]; then
    pass "$LABEL"
  else
    fail "$LABEL ('$NEEDLE' unexpectedly found in output)"
  fi
}

# assert_eq_num ACTUAL EXPECTED [LABEL]  --  integer equality.
assert_eq_num() {
  local ACTUAL="$1" EXPECTED="$2" LABEL="${3:-integer equal}"
  if [[ "$ACTUAL" -eq "$EXPECTED" ]]; then
    pass "$LABEL (=$EXPECTED)"
  else
    fail "$LABEL (expected $EXPECTED, got $ACTUAL)"
  fi
}

# assert_subshell_rc EXPECTED_RC COMMAND [LABEL]
#   Runs COMMAND in a subshell, compares its exit status to EXPECTED_RC.
#   For functions whose rc is the contract (CLI semantics, exit-on-error).
#   COMMAND is a string evaluated inside the subshell; env assignments
#   belong inside it. Output is discarded -- assert on the rc, not on
#   what the function printed.
assert_subshell_rc() {
  local EXPECTED="$1" CMD="$2"
  local LABEL="${3:-subshell rc $EXPECTED}" RC
  ( eval "$CMD" ) >/dev/null 2>&1
  RC=$?
  if [[ "$RC" == "$EXPECTED" ]]; then
    pass "$LABEL"
  else
    fail "$LABEL (got rc $RC)"
  fi
}

# source_function_from FILE NAME
#   Extracts NAME() from FILE at run time and evals it into the current
#   shell. Fails with a named error when the pattern does not match --
#   the Anti-Pattern 7 prerequisite gate, built in
#   (testing-conventions.md, Anti-Pattern 7: Test-the-Copy).
source_function_from() {
  local FILE="$1" NAME="$2" SRC
  SRC="$(sed -n "/^${NAME}()/,/^}/p" "$FILE")"
  if [[ -z "$SRC" ]]; then
    echo "FATAL: prerequisite missing: ${NAME}() not extractable from $FILE" >&2
    return 1
  fi
  eval "$SRC"
}

# ---------------------------------------------------------------------------
# Captured-argument assertions for the dispatch oracle suite. A capture line
# is a single string (the `capture:` payload). CAPTURED must be set by the
# fixture (dispatch_and_capture).
#
#   captured_has P1 [P2 ...]  --  true when some captured string contains ALL
#   captured_lacks PATTERN    --  true when no captured string contains PATTERN
# ---------------------------------------------------------------------------
captured_has() {
  local c pat
  for c in "${CAPTURED[@]:-}"; do
    local all=true
    for pat in "$@"; do
      [[ "$c" == *"$pat"* ]] || all=false
    done
    [[ "$all" == true ]] && return 0
  done
  return 1
}

captured_lacks() {
  captured_has "$1" && return 1 || return 0
}
