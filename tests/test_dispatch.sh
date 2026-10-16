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
#   dispatch_roles       --  the table lists as role, pair and backend
#   dispatch_check       --  a runnable backend passes, a missing one refuses
#   scripts/dispatch.sh  --  --list-roles prints the table, a normal dispatch
#                            refuses an empty brief, and --run executes the
#                            built command and propagates its exit code

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/dispatch.sh"

# A role table fixture, so the case never reads the operator's real file.
# AGENT_HOME points at the fixture directory, so dispatch_command's default
# resolution reads the fixture rather than the live table. FIXTURE_ROOT is
# set by test_setup; the allocator behind get_test_dir is not live until
# run_test, so a file-scope call would leak a redirection error.
REC_FILE="$FIXTURE_ROOT/model-recommendations.md"
export AGENT_HOME="$FIXTURE_ROOT"
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

test_roles_lists_table() {
  local RESULT EXPECTED
  EXPECTED="$(printf '%s\n' \
    '_IMPLEMENTER opencode-go/cat-jam-free pi' \
    '_REVIEWER openrouter/z-ai/glm-5.3-flash pi' \
    '_ADVISOR opencode/cat-jam-free opencode')"
  RESULT="$(dispatch_roles "$REC_FILE")"
  assert_eq "$RESULT" "$EXPECTED" "dispatch_roles prints every role in file order"
}

test_check_opencode_success() {
  local BIN RC
  BIN="$FIXTURE_DIR/opencode-stub"
  printf '#!/bin/sh\n' > "$BIN"
  chmod +x "$BIN"
  DISPATCH_OPENCODE_BIN="$BIN" dispatch_check _ADVISOR "$REC_FILE" 2>/dev/null
  RC=$?
  assert_rc "$RC" 0 "dispatch_check passes when the opencode binary is runnable"
}

test_check_opencode_failure() {
  local RC
  DISPATCH_OPENCODE_BIN="$FIXTURE_DIR/no-such-opencode" dispatch_check _ADVISOR "$REC_FILE" 2>/dev/null
  RC=$?
  assert_rc "$RC" 1 "dispatch_check fails when the opencode binary is missing"
}

test_cli_list_roles() {
  local RESULT EXPECTED
  EXPECTED="$(printf '%s\n' \
    '_IMPLEMENTER opencode-go/cat-jam-free pi' \
    '_REVIEWER openrouter/z-ai/glm-5.3-flash pi' \
    '_ADVISOR opencode/cat-jam-free opencode')"
  RESULT="$(bash "$REPO_ROOT/scripts/dispatch.sh" --list-roles)"
  assert_eq "$RESULT" "$EXPECTED" "the CLI --list-roles prints the fixture roles"
}

test_cli_empty_brief_refuses() {
  local EMPTY RC
  EMPTY="$FIXTURE_DIR/empty-brief.md"
  : > "$EMPTY"
  bash "$REPO_ROOT/scripts/dispatch.sh" --role _IMPLEMENTER --brief "$EMPTY" >/dev/null 2>&1
  RC=$?
  assert_rc "$RC" 2 "the CLI refuses an empty brief"
}

# The stub journals its argv so the case can assert what --run executed without
# a real opencode. Recording every argument, not a joined string, keeps a
# space-bearing argument distinguishable from two arguments.
test_cli_run_executes_built_command() {
  local BIN LOG BRIEF ARGV RC EXPECTED
  BIN="$FIXTURE_DIR/opencode-run-stub"
  LOG="$FIXTURE_DIR/run-argv.log"
  BRIEF="$FIXTURE_DIR/run-brief.md"
  printf 'the run brief\n' > "$BRIEF"
  cat > "$BIN" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$LOG"
exit 7
EOF
  chmod +x "$BIN"
  DISPATCH_OPENCODE_BIN="$BIN" bash "$REPO_ROOT/scripts/dispatch.sh" \
    --role _ADVISOR --brief "$BRIEF" --dir /work --run >/dev/null 2>&1
  RC=$?
  ARGV="$(cat "$LOG")"
  EXPECTED="$(printf '%s\n' \
    run --auto --dir /work -m opencode/cat-jam-free --variant high 'the run brief')"
  assert_eq "$ARGV" "$EXPECTED" "the run path hands the stub the built argv"
  assert_contains "$ARGV" "the run brief" "the stub received the brief's text, so the brief was read at run time"
  assert_rc 7 "$RC" "the stub's exit code propagates through --run"
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
run_test test_roles_lists_table
run_test test_check_opencode_success
run_test test_check_opencode_failure
run_test test_cli_list_roles
run_test test_cli_empty_brief_refuses
run_test test_cli_run_executes_built_command

test_done
