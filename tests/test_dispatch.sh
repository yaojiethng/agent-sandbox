#!/usr/bin/env bash
# Tests for libs/dispatch.sh
#
# Covers:
#   dispatch_role_model  --  a role resolves to provider/model and its level,
#                            and a missing role refuses rather than guessing
#   dispatch_backend     --  the opencode-only set selects the CLI backend,
#                            every other provider selects the pi backend
#   dispatch_command     --  the two backends' flag mappings: pi takes
#                            --provider/--model/--thinking, opencode takes
#                            -m provider/model and --variant, plus --auto
#                            and --dir, with the brief read at run time

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/dispatch.sh"

# A role table fixture, so the case never reads the operator's real file.
# AGENT_HOME points at the fixture directory, so dispatch_command's default
# resolution reads the fixture rather than the live table.
TEST_DIR="$(get_test_dir)"
REC_FILE="$TEST_DIR/model-recommendations.md"
export AGENT_HOME="$TEST_DIR"
cat >"$REC_FILE" <<'EOF'
_IMPLEMENTER: opencode-go/cat-jam-free at high
_REVIEWER: openrouter/z-ai/glm-5.3-flash
_ADVISOR: opencode/cat-jam-free at high
EOF

export DISPATCH_OPENCODE_BIN="/opt/opencode"

test_role_model_with_level() {
  local RESULT
  RESULT="$(dispatch_role_model _IMPLEMENTER "$REC_FILE")"
  assert_eq "$RESULT" "opencode-go/cat-jam-free high" "a role resolves to provider/model and level"
}

test_role_model_without_level() {
  local RESULT
  RESULT="$(dispatch_role_model _REVIEWER "$REC_FILE")"
  assert_eq "$RESULT" "openrouter/z-ai/glm-5.3-flash" "a role line without a level resolves to the pair alone"
}

test_role_model_missing_role() {
  local RESULT RC
  RESULT="$(dispatch_role_model _NOPE "$REC_FILE" 2>/dev/null)"
  RC=$?
  assert_rc "$RC" 1 "a missing role refuses"
  assert_empty "$RESULT" "a missing role prints no model"
}

test_role_model_missing_file() {
  local RC
  dispatch_role_model _IMPLEMENTER "/nonexistent/rec.md" >/dev/null 2>&1
  RC=$?
  assert_rc "$RC" 1 "a missing role table refuses"
}

test_backend_opencode_provider() {
  local RESULT
  RESULT="$(dispatch_backend opencode)"
  assert_eq "$RESULT" "opencode" "the opencode-only provider selects the CLI backend"
}

test_backend_pi_provider() {
  local RESULT
  RESULT="$(dispatch_backend opencode-go)"
  assert_eq "$RESULT" "pi" "a pi-served provider selects the pi backend"
}

test_backend_multi_slash_provider() {
  local RESULT
  RESULT="$(dispatch_backend openrouter)"
  assert_eq "$RESULT" "pi" "a provider outside the opencode set selects the pi backend"
}

test_command_pi_backend() {
  local RESULT
  RESULT="$(dispatch_command _IMPLEMENTER /tmp/brief.md /work)"
  assert_contains "$RESULT" "pi --provider opencode-go --model cat-jam-free --thinking high" "the pi backend maps provider, model and thinking"
  assert_contains "$RESULT" "-p \"\$(cat /tmp/brief.md)\"" "the brief is read at run time"
}

test_command_opencode_backend_by_role() {
  local RESULT
  RESULT="$(dispatch_command _ADVISOR /tmp/brief.md /work)"
  assert_contains "$RESULT" "/opt/opencode run --auto --dir /work -m opencode/cat-jam-free --variant high" "the opencode backend maps the pair and the level"
  assert_contains "$RESULT" "\"\$(cat /tmp/brief.md)\"" "the opencode backend passes the brief as the message"
}

test_command_model_override_selects_backend() {
  local RESULT
  RESULT="$(dispatch_command _IMPLEMENTER /tmp/brief.md /work opencode/cat-jam-free)"
  assert_contains "$RESULT" "/opt/opencode run --auto --dir /work -m opencode/cat-jam-free" "an override onto an opencode-only provider switches the backend"
}

test_command_thinking_override() {
  local RESULT
  RESULT="$(dispatch_command _IMPLEMENTER /tmp/brief.md /work opencode-go/cat-jam-free low)"
  assert_contains "$RESULT" "pi --provider opencode-go --model cat-jam-free --thinking low" "the thinking override replaces the role's level"
}

test_command_session_on_both_backends() {
  local PI_CMD OC_CMD
  PI_CMD="$(dispatch_command _IMPLEMENTER /tmp/brief.md /work opencode-go/cat-jam-free high sess-1)"
  OC_CMD="$(dispatch_command _IMPLEMENTER /tmp/brief.md /work opencode/cat-jam-free high sess-2)"
  assert_contains "$PI_CMD" "--session sess-1" "the pi backend resumes a session"
  assert_contains "$OC_CMD" "--session sess-2" "the opencode backend resumes a session"
}

test_command_missing_role_refuses() {
  local RESULT RC
  RESULT="$(dispatch_command _NOPE /tmp/brief.md /work 2>/dev/null)"
  RC=$?
  assert_rc "$RC" 1 "a command for a missing role refuses"
  assert_empty "$RESULT" "a missing role prints no command"
}

test_command_missing_args_refuses() {
  local RC
  dispatch_command _IMPLEMENTER "" "" >/dev/null 2>&1
  RC=$?
  assert_rc "$RC" 1 "a command without a brief or dir refuses"
}

run_test test_role_model_with_level
run_test test_role_model_without_level
run_test test_role_model_missing_role
run_test test_role_model_missing_file
run_test test_backend_opencode_provider
run_test test_backend_pi_provider
run_test test_backend_multi_slash_provider
run_test test_command_pi_backend
run_test test_command_opencode_backend_by_role
run_test test_command_model_override_selects_backend
run_test test_command_thinking_override
run_test test_command_session_on_both_backends
run_test test_command_missing_role_refuses
run_test test_command_missing_args_refuses

test_done
