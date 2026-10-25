#!/usr/bin/env bash
# tests/test_pi_model_recommendations.sh
# The model recommendations live in an operator-owned file, mounted into pi's
# config home, seeded as a slug-free skeleton, and read by role tag.
#
# Tests:
#   - setup.sh creates the skeleton when absent, leaves it when present, and
#     replaces it from the project copy when the project has one
#   - onboard.sh creates the skeleton
#   - the skeleton, the initialization skill, the project layer, the eval harness
#     and the dispatch skill bind no role to a model, so no file names a model
#     the operator did not write into the table
#   - every role line in the committed table resolves through the library, so a
#     rule edit that breaks a line fails here rather than at a dispatch
#   - .pi/ is gitignored
#   - the pi compose overlay mounts the file at $AGENT_HOME/model-recommendations.md
#   - the project and provider AGENTS.md name the file
#   - run_case.sh resolves _ORCHESTRATOR and takes the provider from the same
#     value as the model
#
# Run:   bash tests/test_pi_model_recommendations.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

PROVIDER_DIR="$REPO_ROOT/src/reasoning/providers/pi"
SETUP="$PROVIDER_DIR/setup.sh"
ONBOARD="$PROVIDER_DIR/onboard.sh"
SKELETON="$PROVIDER_DIR/model-recommendations.skeleton.md"
SKILL="$PROVIDER_DIR/config/agent/skills/setup-model-recommendations/SKILL.md"
COMPOSE="$PROVIDER_DIR/docker-compose.pi.yml"
RUN_CASE="$REPO_ROOT/workflow/coding-agent/skills/eval/scripts/run_case.sh"
TABLE="$REPO_ROOT/.agents/model-recommendations.md"
DISPATCH_SKILL="$PROVIDER_DIR/config/agent/skills/dispatch/SKILL.md"

# The library's command line, called once per role, with the committed table named
# explicitly so the case reads it even where DISPATCH_REC_FILE points elsewhere.
CLI="$REPO_ROOT/src/libs/dispatch/cli.ts"
cli() {
  node "$CLI" "$@"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_setup_creates_skeleton_when_absent() {
  local sandbox; sandbox="$(get_fixture_dir)/sandbox"
  mkdir -p "$sandbox"
  (
    export SANDBOX_DIR="$sandbox" PROJECT_DIR="$sandbox/project"
    # shellcheck disable=SC1090  # script path is fixed by the test
    source "$SETUP" >/dev/null 2>&1
  )
  assert_file_exists "$sandbox/.pi/model-recommendations.md" "setup creates the skeleton"
  assert_eq "$(cat "$sandbox/.pi/model-recommendations.md")" "$(cat "$SKELETON")" "the skeleton is the committed template"
}

test_setup_leaves_existing_file() {
  local sandbox; sandbox="$(get_fixture_dir)/sandbox"
  mkdir -p "$sandbox/.pi"
  printf '_ORCHESTRATOR: example/model at high\n' >"$sandbox/.pi/model-recommendations.md"
  (
    export SANDBOX_DIR="$sandbox" PROJECT_DIR="$sandbox/project"
    # shellcheck disable=SC1090
    source "$SETUP" >/dev/null 2>&1
  )
  assert_eq "$(cat "$sandbox/.pi/model-recommendations.md")" '_ORCHESTRATOR: example/model at high' \
    "with no project copy, setup never overwrites an existing file"
}

test_setup_refreshes_from_the_project_copy() {
  local sandbox; sandbox="$(get_fixture_dir)/sandbox"
  mkdir -p "$sandbox/.pi" "$sandbox/project/.agents"
  printf '_ORCHESTRATOR: example/stale at high\n' >"$sandbox/.pi/model-recommendations.md"
  printf '_ORCHESTRATOR: example/canonical at low\n' >"$sandbox/project/.agents/model-recommendations.md"
  (
    export SANDBOX_DIR="$sandbox" PROJECT_DIR="$sandbox/project"
    # shellcheck disable=SC1090
    source "$SETUP" >/dev/null 2>&1
  )
  assert_eq "$(cat "$sandbox/.pi/model-recommendations.md")" '_ORCHESTRATOR: example/canonical at low' \
    "the project copy replaces the container's copy, so a session reading the fallback path reads the authority"
}

test_onboard_creates_skeleton() {
  local sandbox; sandbox="$(get_fixture_dir)/sandbox"
  mkdir -p "$sandbox"
  SANDBOX_DIR="$sandbox" PROJECT_DIR="$sandbox/project" bash "$ONBOARD" >/dev/null 2>&1
  assert_file_exists "$sandbox/.pi/model-recommendations.md" "onboard creates the skeleton"
}

test_no_file_pins_a_role_to_a_model() {
  local shape='^[[:space:]]*_[A-Z][A-Z0-9_]*:[[:space:]]*[a-zA-Z0-9._-]+/'
  assert_empty "$(grep -nE "$shape" "$SKELETON" || true)" "the skeleton binds no role to a model"
  assert_empty "$(grep -nE "$shape" "$SKILL" || true)" "the initialization skill binds no role to a model"
  assert_empty "$(grep -nE "$shape" "$REPO_ROOT/AGENTS.md" || true)" "the project layer binds no role to a model"
  assert_empty "$(grep -nE "$shape" "$RUN_CASE" || true)" "the eval harness binds no role to a model"
  assert_empty "$(grep -nE "$shape" "$DISPATCH_SKILL" || true)" "the dispatch skill binds no role to a model"
  assert_file_exists "$SKILL" "the initialization skill exists"
}


test_every_committed_role_line_resolves() {
  # The tag lines are read from the file rather than from `table roles`, because a
  # role whose line does not resolve is absent from that listing: a walk over the
  # listing would pass on exactly the defect this case exists to catch.
  local tags tag rc out
  tags="$(grep -oE '^_[A-Z][A-Z0-9_]*:' "$TABLE" | tr -d ':' | sort -u)"
  assert_not_empty "$tags" "the committed table names at least one role"
  for tag in $tags; do
    rc=0
    out="$(cli table resolve --role "$tag" --file "$TABLE" 2>&1)" || rc=$?
    assert_rc 0 "$rc" "the committed table resolves '$tag'"
    assert_not_empty "$out" "the committed table gives '$tag' an assignment"
  done
}

test_pi_is_gitignored() {
  local rc=0
  git -C "$REPO_ROOT" check-ignore -q .pi/model-recommendations.md || rc=$?
  assert_rc 0 "$rc" ".pi/model-recommendations.md is ignored by git"
}

test_compose_mounts_the_file() {
  assert_contains "$(cat "$COMPOSE")" 'source: ${SANDBOX_DIR}/.{{PROVIDER_NAME}}/model-recommendations.md' "the overlay names the host source"
  assert_contains "$(cat "$COMPOSE")" 'target: /home/agentuser/.pi/model-recommendations.md' "the overlay names the AGENT_HOME target"
}

test_agents_layers_name_the_file() {
  assert_contains "$(cat "$REPO_ROOT/AGENTS.md")" 'model-recommendations.md' "the project layer names the file"
  assert_contains "$(cat "$PROVIDER_DIR/config/agent/AGENTS.md")" 'model-recommendations.md' "the provider layer names the file"
}

test_run_case_uses_the_orchestrator_role() {
  assert_contains "$(cat "$RUN_CASE")" '_ORCHESTRATOR' "run_case reads the _ORCHESTRATOR role"
  assert_contains "$(cat "$RUN_CASE")" 'scripts/dispatch.sh' "run_case takes its command from the entrypoint"
  assert_empty "$(grep -nE -- '--provider[ =]' "$RUN_CASE" || true)" "run_case composes no provider of its own"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

echo "Pi model recommendations tests"
echo "=============================="

run_test test_setup_creates_skeleton_when_absent
run_test test_setup_leaves_existing_file
run_test test_setup_refreshes_from_the_project_copy
run_test test_onboard_creates_skeleton
run_test test_no_file_pins_a_role_to_a_model
run_test test_every_committed_role_line_resolves
run_test test_pi_is_gitignored
run_test test_compose_mounts_the_file
run_test test_agents_layers_name_the_file
run_test test_run_case_uses_the_orchestrator_role

test_done
