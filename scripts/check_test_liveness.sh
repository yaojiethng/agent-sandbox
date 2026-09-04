#!/usr/bin/env bash
# scripts/check_test_liveness.sh
# Mechanical liveness checks for the unit test suite (tests/test_*.sh):
#
#   1. Registration liveness  --  every `test_*()` function defined in a test
#      file has a `run_test` registration in the same file; every `run_test`
#      target resolves to a function defined in that file. A defined-but-
#      unregistered test never executes (silent rot); a registration without
#      a definition fails at runtime with an unrelated error.
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
FINDINGS=0
COUNT=0

# --- 1. Registration liveness, per test file ---
for F in "$REPO_ROOT"/tests/test_*.sh; do
  [[ -e "$F" ]] || continue
  NAME="${F#$REPO_ROOT/}"
  COUNT=$((COUNT + 1))

  # Defined test functions: `test_something() {` at line start.
  mapfile -t DEFINED < <(grep -oE '^test_[A-Za-z0-9_]+\(\)' "$F" | sed 's/()$//; s/^test_//' | sort -u)
  # Registered targets: run_test <name> at line start.
  mapfile -t REGISTERED < <(grep -oE '^\s*run_test\s+test_[A-Za-z0-9_]+' "$F" | awk '{print $2}' | sed 's/^test_//' | sort -u)

  # Defined but never registered -> never executes.
  for fn in "${DEFINED[@]}"; do
    if ! printf '%s\n' "${REGISTERED[@]:-}" | grep -qxF "$fn"; then
      echo "UNREGISTERED: $NAME: test_$fn() is defined but never registered via run_test" >&2
      FINDINGS=$((FINDINGS + 1))
    fi
  done

  # Registered but not defined -> runtime failure when the file runs.
  for fn in "${REGISTERED[@]}"; do
    if ! printf '%s\n' "${DEFINED[@]:-}" | grep -qxF "$fn"; then
      echo "DANGLING: $NAME: run_test test_$fn has no matching function definition" >&2
      FINDINGS=$((FINDINGS + 1))
    fi
  done
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
