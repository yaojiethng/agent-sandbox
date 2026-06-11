#!/usr/bin/env bash
# tests/test_run_agent.sh — Tests for scripts/run_agent.sh path resolution.
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
echo "-- Provider file existence --"

RP="$REPO_ROOT"
for PROVIDER_DIR in "$RP/src/reasoning/providers/"*/; do
  [[ -d "$PROVIDER_DIR" ]] || continue
  PROVIDER_NAME="$(basename "$PROVIDER_DIR")"

  expected_setup="$RP/src/reasoning/providers/$PROVIDER_NAME/setup.sh"
  expected_overlay="$RP/src/reasoning/providers/$PROVIDER_NAME/docker-compose.${PROVIDER_NAME}.yml"
  expected_serve="$RP/src/reasoning/providers/$PROVIDER_NAME/docker-compose.serve.yml"

  if [[ -f "$expected_setup" ]]; then
    pass "$PROVIDER_NAME: setup.sh exists at expected path"
  else
    skip "$PROVIDER_NAME: no setup.sh (optional)"
  fi

  if [[ -f "$expected_overlay" ]]; then
    pass "$PROVIDER_NAME: compose overlay exists at expected path"
  else
    skip "$PROVIDER_NAME: no compose overlay (optional)"
  fi

  if [[ -f "$expected_serve" ]]; then
    pass "$PROVIDER_NAME: serve overlay exists at expected path"
  else
    skip "$PROVIDER_NAME: no serve overlay (optional)"
  fi
done
echo ""
echo "-- Compose template file existence --"

if [[ -f "$REPO_ROOT/src/build/docker-compose.yml" ]]; then
  pass "compose template exists"
else
  fail "compose template missing: $REPO_ROOT/src/build/docker-compose.yml"
fi

if [[ -f "$REPO_ROOT/src/build/docker-compose.dry-run.yml" ]]; then
  pass "dry-run overlay exists"
else
  fail "dry-run overlay missing: $REPO_ROOT/src/build/docker-compose.dry-run.yml"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"

# Exit with non-zero if any test failed
[[ "$FAIL" -eq 0 ]]
