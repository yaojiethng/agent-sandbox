#!/usr/bin/env bash
# tests/test_resume.sh
# Command-shape tests for scripts/resume_agent.sh — the split-out resume command
# (F2 two-command design, design session `20260821-02`, impl `20260821-03`).

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

RESUME="$REPO_ROOT/scripts/resume_agent.sh"

# Build a minimal fixture sandbox with a .env and a .compose/<session-id>.yml
# registry record (the unified inventory, D7). The record embeds the provider
# via the agent image line and the session labels — the identity the resume
# path recovers (ID 06).
build_fixture() {
  local FIXTURE_ID="$1"
  local dir="$FIXTURE_DIR/$FIXTURE_ID"
  mkdir -p "$dir/sandbox/.compose" "$dir/sandbox/.workspace/session-diffs" \
           "$dir/sandbox/.workspace/input" "$dir/sandbox/.workspace/output" \
           "$dir/project"

  cat > "$dir/sandbox/.env" <<EOF
SANDBOX_DIR=$dir/sandbox
PROJECT_DIR=$dir/project
EOF

  cat > "$dir/sandbox/.compose/abc123.yml" <<'EOF'
x-session-labels:
  agent-sandbox.host-head-sha: deadbeef
  agent-sandbox.host-branch: main
  agent-sandbox.session-ts: 20260821-000000
  agent-sandbox.session-id: abc123
services:
  sandbox:
    image: agent-sandbox-abc123
  agent:
    image: pi-agent-test-project
EOF

  echo "$dir/sandbox"
}

# --list renders the registry record filenames (primitive, non-resuming).
test_list_renders_filenames() {
  local sandbox
  sandbox="$(build_fixture "list")"
  local out
  out="$(bash "$RESUME" --name=test --project="$FIXTURE_DIR/list/project" --sandbox="$sandbox" --list)"
  if echo "$out" | grep -q "abc123"; then
    pass "resume --list: renders the .compose record filename"
  else
    fail "resume --list: expected 'abc123' in output, got: $out"
  fi
}

# Bare resume (no target flags) → help hinting --list / --interactive, non-zero.
test_bare_resume_prints_help() {
  local out rc
  out="$(bash "$RESUME" 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] \
     && echo "$out" | grep -q -- "--list" \
     && echo "$out" | grep -q -- "--interactive"; then
    pass "resume (bare): prints help hinting --list and --interactive, non-zero exit"
  else
    fail "resume (bare): expected non-zero + help hinting --list/--interactive, got rc=$rc: $out"
  fi
}

# Unknown flag → help + non-zero (D2).
test_unknown_flag_prints_help() {
  local out rc
  out="$(bash "$RESUME" --bogus 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] && echo "$out" | grep -q -- "--list"; then
    pass "resume: unknown flag prints help, non-zero exit"
  else
    fail "resume: expected non-zero + help on unknown flag, got rc=$rc: $out"
  fi
}

# --interactive is routed but not-yet-implemented (ID 05).
test_interactive_not_implemented() {
  local out rc
  out="$(bash "$RESUME" --interactive 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] && echo "$out" | grep -qi "not yet implemented"; then
    pass "resume --interactive: routed, not-yet-implemented error, non-zero exit"
  else
    fail "resume --interactive: expected not-yet-implemented error, got rc=$rc: $out"
  fi
}

# --provider is routed but not-yet-implemented (ID 05).
test_provider_not_implemented() {
  local out rc
  out="$(bash "$RESUME" --provider=pi 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] && echo "$out" | grep -qi "not yet implemented"; then
    pass "resume --provider: routed, not-yet-implemented error, non-zero exit"
  else
    fail "resume --provider: expected not-yet-implemented error, got rc=$rc: $out"
  fi
}

# --session-id with a missing record → clear error, non-zero.
test_session_id_missing_record() {
  local dir="$FIXTURE_DIR/missing"
  mkdir -p "$dir/sandbox/.compose" "$dir/project/.git"
  git -C "$dir/project" init -q >/dev/null 2>&1
  git -C "$dir/project" -c user.email=t@t -c user.name=t commit --allow-empty -q -m init >/dev/null 2>&1
  cat > "$dir/sandbox/.env" <<EOF
SANDBOX_DIR=$dir/sandbox
PROJECT_DIR=$dir/project
EOF
  local out rc
  out="$(bash "$RESUME" --name=test --project="$dir/project" --sandbox="$dir/sandbox" --session-id=nope 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] && echo "$out" | grep -qi "no session record"; then
    pass "resume --session-id: missing record → clear error, non-zero"
  else
    fail "resume --session-id: expected 'no session record', got rc=$rc: $out"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_list_renders_filenames
run_test test_bare_resume_prints_help
run_test test_unknown_flag_prints_help
run_test test_interactive_not_implemented
run_test test_provider_not_implemented
run_test test_session_id_missing_record

echo ""
echo "Test complete: $PASS passed, $FAIL failed."
[[ $FAIL -eq 0 ]] && exit 0 || exit 1