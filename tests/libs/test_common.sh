#!/usr/bin/env bash
# tests/libs/test_common.sh
# Shared test helpers. Source this file, do not execute directly.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: test_common.sh must be sourced, not executed." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Per-test accounting  --  one unit per test, accumulated once per run_test
# in the file's own shell.
#   PASS -- passing test units
#   FAIL -- failing test units
#   FAILURES -- names of the failing tests, for the test_done summary
# ---------------------------------------------------------------------------
: "${PASS:=0}"
: "${FAIL:=0}"
FAILURES=()

# _IN_TEST marks the current test subshell. Inside it fail() exits the
# subshell non-zero (fail-fast); outside it fail() accumulates so a stray
# top-level assertion cannot kill the file mid-way.
_IN_TEST=0

# ---------------------------------------------------------------------------
# Untyped per-test allocator.
#   get_fixture_dir / get_test_dir  --  the same backend, a fresh directory
#   on every call, never reused across tests. The current test's allocated
#   directories are removed when that test's subshell exits (run_test's EXIT
#   trap); nothing is guaranteed after that point.
#
# Allocations are journaled to a file, not an array: the allocator is called
# inside command substitution, whose array writes are lost to a sub-subshell.
# A file append survives it, and _cleanup_alloc reads one journal per test.
# ---------------------------------------------------------------------------
_alloc_log=""

get_fixture_dir() {
  local _d
  _d="$(mktemp -d /tmp/XXXXXX)"
  printf '%s\n' "$_d" >> "$_alloc_log" 2>/dev/null || true
  printf '%s\n' "$_d"
}
get_test_dir() { get_fixture_dir; }

# _cleanup_alloc  --  remove everything the current test allocated. Always
# returns 0 so a removal hiccup cannot flip a passing test to a failure.
_cleanup_alloc() {
  [[ -s "${_alloc_log:-}" ]] || return 0
  local _d
  while IFS= read -r _d; do
    rm -rf -- "$_d" 2>/dev/null || true
  done < "$_alloc_log"
  rm -f -- "$_alloc_log"
  return 0
}

# pass LABEL / fail LABEL
#   Emit an assertion result. Assertion detail lines use the "  ok: " /
#   "  not ok: " prefixes; the runner-visible unit markers ("  PASS: " /
#   "  FAIL: ") are emitted once per test by run_test. Inside a test,
#   fail() exits the test subshell non-zero (fail-fast).
pass() {
  if (( _IN_TEST )); then
    echo "  ok: $1"
    _ANY=1
  else
    echo "  PASS: $1"
    PASS=$((PASS + 1))
  fi
}
fail() {
  if (( _IN_TEST )); then
    echo "  not ok: $1"
    _ANY=1
    exit 1
  else
    echo "  FAIL: $1"
    FAIL=$((FAIL + 1))
    FAILURES+=("$1")
  fi
}

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
#   Runs the test function NAME in its own subshell: per-test isolation of
#   environment, cwd, globals, and traps. A fresh FIXTURE_DIR is allocated
#   for the test (its default root) and removed on exit; the test allocates
#   extras via get_fixture_dir as needed.
#
#   Unit result: rc 0 + at least one assertion -> one PASS unit. rc non-zero
#   (a fail() exit or a crash) or zero assertions -> one FAIL unit. The unit
#   marker ("  PASS: NAME" / "  FAIL: NAME") is what scripts/run_tests.sh
#   counts.
# shellcheck disable=SC2034  # rc carries the subshell result to the unit branch
run_test() {
  local name="$1" rc=0
  echo "[ $name ]"
  # set +e: the design's fail-fast is fail() (controlled exit), not errexit.
  # A shell that sourced a script running `set -e` (start_agent.sh does) must
  # still let a test capture `out=$(cmd); rc=$?` where cmd fails, and the
  # `|| rc=$?` below keeps the unit capture errexit-safe in the file shell.
  ( set +e
    _alloc_log="$(mktemp /tmp/tc_alloc_XXXXXX)"
    : > "$_alloc_log"
    # Preserve the would-be exit status: the EXIT trap's own final command
    # otherwise overrides it (a fail() exit 1 becomes exit 0 and the unit
    # flips to PASS). Save $? first, clean up, re-exit with it.
    trap '_trap_rc=$?; _cleanup_alloc; exit "$_trap_rc"' EXIT
    FIXTURE_DIR="$(get_fixture_dir)"
    _IN_TEST=1
    local _ANY=0
    local _trap_rc=0
    "$name"
    rc=$?
    if (( rc != 0 )); then
      exit 1
    fi
    if (( _ANY == 0 )); then
      echo "  not ok: $name completed without an assertion"
      exit 1
    fi
    exit 0
  ) || rc=$?
  if (( rc == 0 )); then
    PASS=$((PASS + 1))
    echo "  PASS: $name"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$name")
    echo "  FAIL: $name"
  fi
}

# ---------------------------------------------------------------------------
# test_setup  --  call at file scope after source lines to get standard vars
# and the file-scope scaffold root.
#
# Sets: TEST_DIR, REPO_ROOT, FIXTURE_ROOT (file-scope scaffold root),
#       FIXTURE_DIR (per-test default root; reallocated fresh by run_test)
# Registers: trap 'rm -rf "$FIXTURE_ROOT"' EXIT
# ---------------------------------------------------------------------------
# shellcheck disable=SC2034  # REPO_ROOT/SC, FIXTURE_DIR are consumed by test files
test_setup() {
  if [[ -z "${BASH_SOURCE[1]:-}" ]]; then
    echo "Error: test_setup must be called from a sourced file, not interactively." >&2
    return 1
  fi
  TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
  FIXTURE_ROOT="$(mktemp -d /tmp/XXXXXX)"
  FIXTURE_DIR="$FIXTURE_ROOT"
  local _trap_rc=0
  trap '_trap_rc=$?; rm -rf "$FIXTURE_ROOT"; exit "$_trap_rc"' EXIT
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

# test_done NAME
#   Prints the file's per-test-unit results and exits with the failing-unit
#   count (0 on green). The failing names were already emitted as unit
#   markers by run_test; the list below is a human-friendly reprint.
test_done() {
  local NAME="${1:-}"
  if [[ -n "$NAME" ]]; then
    echo "=== $NAME ==="
    echo
  fi
  echo "Results: $PASS passed, $FAIL failed"
  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo "Failed:"
    for f in "${FAILURES[@]}"; do echo "  - $f"; done
  fi
  exit "$FAIL"
}

# ---------------------------------------------------------------------------
# Assertion helpers  --  the standard way to assert inside a test function.
# Each calls pass or fail itself, so a test body can be one to three lines
# and can never be assertion-less.
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