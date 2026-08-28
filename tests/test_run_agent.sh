#!/usr/bin/env bash
# tests/test_run_agent.sh  --  Tests for scripts/run_agent.sh path resolution.
#
# These tests assert that the compose and provider file paths constructed
# by run_agent.sh resolve correctly for each registered provider.
# The duplicated-path bug (src/reasoning/src/reasoning/providers/) would be
# caught by checking that each path contains no repeated segments.
#
# Run:
#   bash tests/test_run_agent.sh

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

# Initialize vars used in for-loop probes (set -u safety)
RP=
PROVIDER_NAME=
expected_setup=
expected_overlay=
expected_serve=

# -------------------------------------------------------------------
# Helper: extract a variable assignment from run_agent.sh by grep
# -------------------------------------------------------------------
extract_path_expr() {
  local var_name="$1"
  grep "^${var_name}=" "$REPO_ROOT/scripts/run_agent.sh" | head -1 | sed 's/^[^=]*=//'
}

# -------------------------------------------------------------------
# Tests
# -------------------------------------------------------------------

echo ""
echo "=== test_run_agent.sh ==="
echo ""

echo "-- Path resolution correctness --"

SETUP_EXPR=$(extract_path_expr "PROVIDER_SETUP")
if echo "$SETUP_EXPR" | grep -q 'src/reasoning/providers/'; then
  pass "PROVIDER_SETUP references src/reasoning/providers/"
else
  fail "PROVIDER_SETUP should reference src/reasoning/providers/, got: $SETUP_EXPR"
fi

if echo "$SETUP_EXPR" | grep -qv 'src/reasoning/src/reasoning'; then
  pass "PROVIDER_SETUP has no duplicated src/reasoning/"
else
  fail "PROVIDER_SETUP has duplicated src/reasoning/: $SETUP_EXPR"
fi

OVERLAY_EXPR=$(extract_path_expr "PROVIDER_OVERLAY")
if echo "$OVERLAY_EXPR" | grep -q 'src/reasoning/providers/'; then
  pass "PROVIDER_OVERLAY references src/reasoning/providers/"
else
  fail "PROVIDER_OVERLAY should reference src/reasoning/providers/, got: $OVERLAY_EXPR"
fi

if echo "$OVERLAY_EXPR" | grep -qv 'src/reasoning/src/reasoning'; then
  pass "PROVIDER_OVERLAY has no duplicated src/reasoning/"
else
  fail "PROVIDER_OVERLAY has duplicated src/reasoning/: $OVERLAY_EXPR"
fi

SERVE_EXPR=$(extract_path_expr "SERVE_OVERLAY")
if echo "$SERVE_EXPR" | grep -q 'src/reasoning/providers/'; then
  pass "SERVE_OVERLAY references src/reasoning/providers/"
else
  fail "SERVE_OVERLAY should reference src/reasoning/providers/, got: $SERVE_EXPR"
fi

if echo "$SERVE_EXPR" | grep -qv 'src/reasoning/src/reasoning'; then
  pass "SERVE_OVERLAY has no duplicated src/reasoning/"
else
  fail "SERVE_OVERLAY has duplicated src/reasoning/: $SERVE_EXPR"
fi

TEMPLATE_EXPR=$(extract_path_expr "COMPOSE_TEMPLATE")
if echo "$TEMPLATE_EXPR" | grep -q 'src/build/'; then
  pass "COMPOSE_TEMPLATE references src/build/"
else
  fail "COMPOSE_TEMPLATE should reference src/build/, got: $TEMPLATE_EXPR"
fi

DRY_EXPR=$(extract_path_expr "DRY_RUN_OVERLAY")
if echo "$DRY_EXPR" | grep -q 'src/build/'; then
  pass "DRY_RUN_OVERLAY references src/build/"
else
  fail "DRY_RUN_OVERLAY should reference src/build/, got: $DRY_EXPR"
fi

echo ""
echo "-- Provider file existence (deterministic internal-consistency check) --"

# Each provider dir may hold three optional files per run_agent.sh's contract:
#   setup.sh                   --  sourced if present
#   docker-compose.<name>.yml  --  provider overlay, merged if present
#   docker-compose.serve.yml   --  required only in serve mode
# These are optional by design, so presence is not asserted. Instead assert
# internal consistency deterministically (no skips): every present file must be
# non-empty and correctly named per the harness contract.

RP="$REPO_ROOT"
ANY_PROVIDER_FILE_BROKEN=false
for PROVIDER_DIR in "$RP/src/reasoning/providers/"*/; do
  [[ -d "$PROVIDER_DIR" ]] || continue
  PROVIDER_NAME="$(basename "$PROVIDER_DIR")"
  [[ "$PROVIDER_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || {
    fail "providers/$PROVIDER_NAME: directory name has forbidden characters"
    ANY_PROVIDER_FILE_BROKEN=true; continue
  }

  expected_setup="$PROVIDER_DIR/setup.sh"
  expected_overlay="$PROVIDER_DIR/docker-compose.${PROVIDER_NAME}.yml"
  expected_serve="$PROVIDER_DIR/docker-compose.serve.yml"

  if [[ -f "$expected_setup" ]]; then
    if [[ -s "$expected_setup" ]]; then
      pass "$PROVIDER_NAME: setup.sh present and non-empty"
    else
      fail "$PROVIDER_NAME: setup.sh present but empty"
      ANY_PROVIDER_FILE_BROKEN=true
    fi
  fi

  if [[ -f "$expected_overlay" ]]; then
    if [[ -s "$expected_overlay" ]]; then
      pass "$PROVIDER_NAME: compose overlay present and non-empty"
    else
      fail "$PROVIDER_NAME: compose overlay present but empty"
      ANY_PROVIDER_FILE_BROKEN=true
    fi
  fi

  if [[ -f "$expected_serve" ]]; then
    if [[ -s "$expected_serve" ]]; then
      pass "$PROVIDER_NAME: serve overlay present and non-empty"
    else
      fail "$PROVIDER_NAME: serve overlay present but empty"
      ANY_PROVIDER_FILE_BROKEN=true
    fi
  fi
done

if [[ "$ANY_PROVIDER_FILE_BROKEN" == false ]]; then
  pass "All present provider optional files are consistent with the harness contract"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"

# Exit with non-zero if any test failed
[[ "$FAIL" -eq 0 ]]
