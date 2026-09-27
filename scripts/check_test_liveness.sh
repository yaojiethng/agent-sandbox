#!/usr/bin/env bash
# scripts/check_test_liveness.sh
# Mechanical liveness checks for the unit test suite (tests/test_*.sh):
#
#   1. Registration liveness  --  every `test_*()` function defined in a test
#      file has a `run_test` registration in the same file; every `run_test`
#      target resolves to a function defined in that file; and no `run_test`
#      appears after `test_done` (a registration there is dead code). A
#      defined-but-unregistered test never executes (silent rot); a
#      registration without a definition fails at runtime with an unrelated
#      error; a registration after test_done never runs.
#   2. Prerequisite liveness  --  the docker stub exists, is executable, and
#      answers a smoke invocation; stub libs referenced by test files exist.
#
# Rationale: the runner warns on zero-assertion files but cannot see a test
# function that was defined and never registered (it simply never runs), and
# a renamed function leaves a dangling registration that only surfaces as a
# confusing runtime failure. Following check_lib_liveness.sh for the same
# reason that script exists: orphaning must be loud the day it happens
# (AGENT_FEEDBACK: knowledge/diagnostic tests rot silently).
#
# Exit 0 when all checks pass; exit 1 listing findings.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# TESTS_DIR names the directory of test_*.sh files to check; it defaults to
# the real suite and is overridable so the runner self-test can point the gate
# at a synthetic fixture directory.
TESTS_DIR="${1:-$REPO_ROOT/tests}"
FINDINGS=0
COUNT=0

# --- 1. Registration liveness, per test file ---
for F in "$TESTS_DIR"/test_*.sh; do
  [[ -e "$F" ]] || continue
  NAME="${F#$REPO_ROOT/}"
  COUNT=$((COUNT + 1))

  # Defined test functions: `test_something() {` at line start.
  mapfile -t DEFINED < <(grep -oE '^test_[A-Za-z0-9_]+\(\)' "$F" | sed 's/()$//; s/^test_//' | sort -u)
  # Registered targets: run_test <name> at line start.
  mapfile -t REGISTERED < <(grep -oE '^\s*run_test\s+test_[A-Za-z0-9_]+' "$F" | awk '{print $2}' | sed 's/^test_//' | sort -u)

  # Membership is a bash set test, not a pipe into grep -q: under
  # `set -o pipefail` an early-exiting grep -q makes the pipeline status
  # non-zero when the producer takes SIGPIPE, which reads as not-found. A
  # false not-found here aborts the whole suite, so the check must not depend
  # on a consumer's exit timing.
  declare -A DEFINED_SET=() REGISTERED_SET=()
  for fn in "${DEFINED[@]}"; do DEFINED_SET[$fn]=1; done
  for fn in "${REGISTERED[@]}"; do REGISTERED_SET[$fn]=1; done

  # Defined but never registered -> never executes.
  for fn in "${DEFINED[@]}"; do
    if [[ -z "${REGISTERED_SET[$fn]:-}" ]]; then
      echo "UNREGISTERED: $NAME: test_$fn() is defined but never registered via run_test" >&2
      FINDINGS=$((FINDINGS + 1))
    fi
  done

  # Registered but not defined -> runtime failure when the file runs.
  for fn in "${REGISTERED[@]}"; do
    if [[ -z "${DEFINED_SET[$fn]:-}" ]]; then
      echo "DANGLING: $NAME: run_test test_$fn has no matching function definition" >&2
      FINDINGS=$((FINDINGS + 1))
    fi
  done

  # A run_test registered after test_done is dead code: test_done exits the
  # process, so the test never runs and never fails, and a file cannot self-
  # guard it in-process. The scan anchors on the registration shape (column-0
  # run_test naming a test_ function); a registration-shaped word inside a
  # quoted payload is not flagged.
  if ! awk '
    /^[[:space:]]*test_done([[:space:]]|$)/ { seen = 1 }
    /^[[:space:]]*run_test[[:space:]]+test_[A-Za-z0-9_]+([[:space:]]|$)/ { if (seen) exit 1 }
  ' "$F"; then
    echo "DEAD-REGISTRATION: $NAME: run_test registered after test_done -- the registration is dead code (testing-conventions.md, Test Structure Template)" >&2
    FINDINGS=$((FINDINGS + 1))
  fi
done

# --- 2. Prerequisite liveness: docker stub + stub libs ---
STUB="$REPO_ROOT/tests/stubs/docker"
if [[ ! -x "$STUB" ]]; then
  echo "PREREQ: tests/stubs/docker is missing or not executable" >&2
  FINDINGS=$((FINDINGS + 1))
else
  # Smoke invocation: the stub must answer a basic call with rc 0.
  if ! DOCKER_TRACE_LOG="$(mktemp -u)" bash "$STUB" version > /dev/null 2>&1; then
    echo "PREREQ: tests/stubs/docker does not answer a smoke invocation" >&2
    FINDINGS=$((FINDINGS + 1))
  fi
fi

# Stub libs referenced by test files must exist. Consumers reference
# tests/stubs/libs/<name>.sh paths or source the lib basename from STUB_LIBS.
for LIB in "$REPO_ROOT"/tests/stubs/libs/*.sh; do
  [[ -e "$LIB" ]] || continue
  LNAME="$(basename "$LIB")"
  # Liveness = some test file references the lib basename.
  if ! grep -rqlF "$LNAME" "$REPO_ROOT"/tests/*.sh 2>/dev/null; then
    echo "ORPHANED: tests/stubs/libs/$LNAME  --  no test file references it" >&2
    FINDINGS=$((FINDINGS + 1))
  fi
done

# Referenced-but-missing stub libs: any tests/stubs/libs/<name> path a test
# file mentions must exist on disk.
while IFS= read -r -d '' ref; do
  if [[ ! -e "$REPO_ROOT/tests/stubs/libs/$ref" ]]; then
    echo "PREREQ: tests reference tests/stubs/libs/$ref which does not exist" >&2
    FINDINGS=$((FINDINGS + 1))
  fi
done < <(grep -rhoE 'stubs/libs/[A-Za-z0-9_.-]+\.sh' "$REPO_ROOT"/tests/*.sh 2>/dev/null | sed 's|^stubs/libs/||' | sort -u | tr '\n' '\0')

echo "check_test_liveness: $COUNT test file(s) checked, $FINDINGS finding(s)."
(( FINDINGS == 0 ))
