#!/usr/bin/env bash
# tests/test_pi_model_recommendations.sh
# The model recommendations live in an operator-owned file, mounted into pi's
# config home, seeded as a slug-free skeleton, and read by role tag.
#
# Tests:
#   - setup.sh creates the skeleton when absent and leaves it when present
#   - onboard.sh creates the skeleton
#   - the skeleton and the initialization skill carry no model slug
#   - .pi/ is gitignored
#   - the pi compose overlay mounts the file at $AGENT_HOME/model-recommendations.md
#   - the project and provider AGENTS.md name the file
#   - run_case.sh resolves _ORCHESTRATOR and names no literal slug
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

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_setup_creates_skeleton_when_absent() {
  local sandbox; sandbox="$(get_fixture_dir)/sandbox"
  mkdir -p "$sandbox"
  (
    export SANDBOX_DIR="$sandbox"
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
    export SANDBOX_DIR="$sandbox"
    # shellcheck disable=SC1090
    source "$SETUP" >/dev/null 2>&1
  )
  assert_eq "$(cat "$sandbox/.pi/model-recommendations.md")" '_ORCHESTRATOR: example/model at high' "setup never overwrites an existing file"
}

test_onboard_creates_skeleton() {
  local sandbox; sandbox="$(get_fixture_dir)/sandbox"
  mkdir -p "$sandbox"
  SANDBOX_DIR="$sandbox" bash "$ONBOARD" >/dev/null 2>&1
  assert_file_exists "$sandbox/.pi/model-recommendations.md" "onboard creates the skeleton"
}

test_skeleton_and_skill_carry_no_slug() {
  assert_empty "$(grep -nE 'opencode-go/|step-5|deepseek|glm-5|space-bunny' "$SKELETON" || true)" "skeleton names no model slug"
  assert_empty "$(grep -nE 'opencode-go/|step-5|deepseek|glm-5|space-bunny' "$SKILL" || true)" "skill names no model slug"
  assert_file_exists "$SKILL" "the initialization skill exists"
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
  assert_empty "$(grep -nE 'opencode-go/|space-bunny|deepseek-v4|glm-5' "$REPO_ROOT/AGENTS.md" || true)" "the project layer names no model slug"
}

test_run_case_uses_the_orchestrator_role() {
  assert_contains "$(cat "$RUN_CASE")" '_ORCHESTRATOR' "run_case reads the _ORCHESTRATOR role"
  assert_empty "$(grep -n 'step-5-preview-free' "$RUN_CASE" || true)" "run_case hardcodes no model slug"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

echo "Pi model recommendations tests"
echo "=============================="

run_test test_setup_creates_skeleton_when_absent
run_test test_setup_leaves_existing_file
run_test test_onboard_creates_skeleton
run_test test_skeleton_and_skill_carry_no_slug
run_test test_pi_is_gitignored
run_test test_compose_mounts_the_file
run_test test_agents_layers_name_the_file
run_test test_run_case_uses_the_orchestrator_role

test_done
