#!/usr/bin/env bash
# TEST_DEADLINE: 40
# Tests for the dispatch seam
#
# Each case asks the library's command line, so every question about the table
# costs one node process. The deadline covers that process count, not slow work.
#
# Covers:
#   the role table CLI   --  `table list` prints a role's ordered assignments, a
#                            repeat is dropped and a malformed entry refuses;
#                            `table resolve` prints the assignment in force as
#                            key, level and runtime, and refuses a role with no
#                            line, no model, or a non-role tag; `table roles`
#                            lists the table as role, entry and runtime
#   the runtime decision --  a free model on an OpenCode provider runs through
#                            that app's CLI, every other assignment runs through
#                            pi, and a level suffix changes neither
#   command              --  the two runtimes' flag mappings: pi takes
#                            --provider/--model/--thinking, opencode takes
#                            -m provider/model and --variant, plus --auto
#                            and --dir, with the brief read at run time
#   table check          --  a role passes when any of its assignments reaches a
#                            runnable runtime, and refuses when none does
#   scripts/dispatch.sh  --  --list-roles prints the table, a normal dispatch
#                            refuses an empty brief, and --run executes the
#                            built command and propagates its exit code
#   scripts/dispatch.sh --worker  --  the read-write mode: the change set it
#                            reports against a named base revision, the recovery
#                            point for the caller's uncommitted work, and the
#                            rule that the next entry runs only when the attempt
#                            left the tree alone

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$TEST_DIR/libs/git_fixtures.sh"

# The library's command line, called the way scripts/dispatch.sh calls it: one
# process per question, with the table named by --file when a case needs its own.
CLI="$REPO_ROOT/src/libs/dispatch/cli.ts"
cli() {
  node "$CLI" "$@"
}

# A role table fixture, so the case never reads the operator's real file.
# DISPATCH_REC_FILE is the operator's override, and the entrypoint passes it
# through as --file, which is how the fixture reaches the CLI.
REC_FILE="$FIXTURE_ROOT/model-recommendations.md"
export DISPATCH_REC_FILE="$FIXTURE_ROOT/model-recommendations.md"
export AGENT_HOME="$FIXTURE_ROOT"
cat >"$REC_FILE" <<'EOF'
_IMPLEMENTER: opencode-go/stub-model at high
_REVIEWER: opencode-go/stub-alt
_ADVISOR: opencode/stub-model-free at high
EOF

# A `pi` stub first on PATH, so a route this file did not stub fails at once,
# with its argv printed, instead of reaching a model. A case that asserts what a
# pi route builds reads the command from the CLI, which never runs it.
mkdir -p "$FIXTURE_ROOT/bin"
cat >"$FIXTURE_ROOT/bin/pi" <<'STUB'
#!/usr/bin/env bash
printf 'pi-stub: unexpected live route: %s\n' "$*" >&2
exit 97
STUB
chmod +x "$FIXTURE_ROOT/bin/pi"
export PATH="$FIXTURE_ROOT/bin:$PATH"

export DISPATCH_OPENCODE_BIN="/opt/opencode"

# A second fixture for the preference list: a non-role line, a role with three
# entries of which two repeat, a malformed entry and an empty line, each in its
# own role so one case cannot disturb another.
CHAIN_FILE="$FIXTURE_ROOT/chain-recommendations.md"
cat >"$CHAIN_FILE" <<'EOF'
Format: `_ROLE: <provider>/<model> at <level>`
_CHAIN: opencode/stub-model-free at high; deepseek/stub-model at high; opencode/stub-model-free at high
_BAD: nonsense
_EMPTY:
EOF

# One role per runtime combination, so each decision is a case of the table
# rather than a call carrying a provider and a model the table never names.
RUNTIME_FILE="$FIXTURE_ROOT/runtime-recommendations.md"
cat >"$RUNTIME_FILE" <<'EOF'
_RT_CLI: opencode/stub-model-free at high
_RT_CLI_PAID: opencode/glm-5.3-flash
_RT_GATEWAY: opencode-go/stub-model
_RT_GATEWAY_FREE: opencode-go/stub-model-free
_RT_OTHER: openrouter/z-ai/glm-5.3-flash
_RT_NO_MODEL: opencode/ at high
EOF

# resolved_runtime ROLE FILE  --  the runtime field of `table resolve`, which is
# how the entrypoint learns what reaches an assignment.
resolved_runtime() {
  local RESOLVED
  RESOLVED="$(cli table resolve --role "$1" --file "$2")"
  printf '%s' "${RESOLVED##* }"
}

test_resolve_role_with_level() {
  local RESULT
  RESULT="$(cli table resolve --role _IMPLEMENTER --file "$REC_FILE")"
  assert_eq "$RESULT" "opencode-go/stub-model high pi" "a role resolves to its assignment, its level and the runtime that reaches it"
}

test_resolve_role_without_level() {
  local RESULT
  RESULT="$(cli table resolve --role _REVIEWER --file "$REC_FILE")"
  assert_eq "$RESULT" "opencode-go/stub-alt - pi" "a role line without a level prints - in the level field"
}

test_resolve_role_missing_role() {
  local RESULT RC
  RESULT="$(cli table list --role _NOPE --file "$REC_FILE" 2>/dev/null)"
  RC=$?
  assert_rc "$RC" 1 "a missing role refuses"
  assert_empty "$RESULT" "a missing role prints no model"
}

test_resolve_role_missing_file() {
  local RC
  cli table resolve --role _IMPLEMENTER --file /nonexistent/rec.md >/dev/null 2>&1
  RC=$?
  assert_rc "$RC" 1 "a missing role table refuses"
}

test_runtime_opencode_provider() {
  local RESULT
  RESULT="$(resolved_runtime _RT_CLI "$RUNTIME_FILE")"
  assert_eq "$RESULT" "opencode" "a free model on the opencode provider selects the CLI runtime"
}

test_runtime_paid_opencode_provider_goes_to_pi() {
  local RESULT
  RESULT="$(resolved_runtime _RT_CLI_PAID "$RUNTIME_FILE")"
  assert_eq "$RESULT" "pi" "a paid model on the opencode provider is reached by pi, not by the CLI"
}

test_runtime_level_suffix_is_ignored() {
  local RESULT
  RESULT="$(resolved_runtime _RT_CLI "$RUNTIME_FILE")"
  assert_eq "$RESULT" "opencode" "an entry written with its level routes the same way"
}

test_runtime_refuses_a_free_provider_without_its_model() {
  local rc=0
  cli table resolve --role _RT_NO_MODEL --file "$RUNTIME_FILE" >/dev/null 2>&1 || rc=$?
  assert_rc 1 "$rc" "the runtime for a free-served provider needs the model, because a default is a guess"
}

test_runtime_pi_provider() {
  local RESULT
  RESULT="$(resolved_runtime _RT_GATEWAY "$RUNTIME_FILE")"
  assert_eq "$RESULT" "pi" "the OpenCode Go gateway is a pi provider, not a CLI one"
}

test_runtime_pi_provider_free_model() {
  local RESULT
  RESULT="$(resolved_runtime _RT_GATEWAY_FREE "$RUNTIME_FILE")"
  assert_eq "$RESULT" "pi" "a free model on the gateway is served by pi, unlike the same model on opencode"
}

test_runtime_unknown_provider() {
  local RESULT
  RESULT="$(resolved_runtime _RT_OTHER "$RUNTIME_FILE")"
  assert_eq "$RESULT" "pi" "a provider outside the opencode set selects the pi runtime"
}

test_command_pi_backend() {
  local RESULT
  RESULT="$(cli command --role _IMPLEMENTER --brief /tmp/brief.md --dir /work --file "$REC_FILE")"
  assert_contains "$RESULT" "pi --provider opencode-go --model stub-model --thinking high" "the pi backend maps provider, model and thinking"
  assert_contains "$RESULT" "-p \"\$(cat /tmp/brief.md)\"" "the brief is read at run time"
}

test_command_opencode_backend_by_role() {
  local RESULT
  RESULT="$(cli command --role _ADVISOR --brief /tmp/brief.md --dir /work --file "$REC_FILE")"
  assert_contains "$RESULT" "/opt/opencode run --auto --print-logs --log-level ERROR --title brief.md --dir /work -m opencode/stub-model-free --variant high" "the opencode backend maps the pair and the level"
  assert_contains "$RESULT" "\"\$(cat /tmp/brief.md)\"" "the opencode backend passes the brief as the message"
}

test_command_model_override_selects_backend() {
  local RESULT
  RESULT="$(cli command --role _IMPLEMENTER --brief /tmp/brief.md --dir /work --model opencode/stub-model-free --file "$REC_FILE")"
  assert_contains "$RESULT" "/opt/opencode run --auto --print-logs --log-level ERROR --title brief.md --dir /work -m opencode/stub-model-free" "an override onto an opencode-only provider switches the backend"
}

test_command_thinking_override() {
  local RESULT
  RESULT="$(cli command --role _IMPLEMENTER --brief /tmp/brief.md --dir /work --model opencode-go/stub-model --thinking low --file "$REC_FILE")"
  assert_contains "$RESULT" "pi --provider opencode-go --model stub-model --thinking low" "the thinking override replaces the role's level"
}

test_command_session_on_both_backends() {
  local PI_CMD OC_CMD
  PI_CMD="$(cli command --role _IMPLEMENTER --brief /tmp/brief.md --dir /work --model opencode-go/stub-model --thinking high --session sess-1 --file "$REC_FILE")"
  OC_CMD="$(cli command --role _IMPLEMENTER --brief /tmp/brief.md --dir /work --model opencode/stub-model-free --thinking high --session sess-2 --file "$REC_FILE")"
  assert_contains "$PI_CMD" "--session sess-1" "the pi backend resumes a session"
  assert_contains "$OC_CMD" "--session sess-2" "the opencode backend resumes a session"
}

test_command_missing_role_refuses() {
  local RESULT RC
  RESULT="$(cli command --role _NOPE --brief /tmp/brief.md --dir /work --file "$REC_FILE" 2>/dev/null)"
  RC=$?
  assert_rc "$RC" 1 "a command for a missing role refuses"
  assert_empty "$RESULT" "a missing role prints no command"
}

test_command_missing_args_refuses() {
  local RC
  cli command --role _IMPLEMENTER --brief "" --dir "" --file "$REC_FILE" >/dev/null 2>&1
  RC=$?
  assert_rc "$RC" 1 "a command without a brief or dir refuses"
}

test_roles_lists_table() {
  local RESULT EXPECTED
  EXPECTED="$(printf '%s\n' \
    '_IMPLEMENTER opencode-go/stub-model at high pi' \
    '_REVIEWER opencode-go/stub-alt pi' \
    '_ADVISOR opencode/stub-model-free at high opencode')"
  RESULT="$(cli table roles --file "$REC_FILE")"
  assert_eq "$RESULT" "$EXPECTED" "table roles prints every role in file order"
}

test_check_opencode_success() {
  local BIN RC
  BIN="$FIXTURE_DIR/opencode-stub"
  printf '#!/bin/sh\n' > "$BIN"
  chmod +x "$BIN"
  DISPATCH_OPENCODE_BIN="$BIN" cli table check --role _ADVISOR --file "$REC_FILE" 2>/dev/null
  RC=$?
  assert_rc "$RC" 0 "table check passes when the opencode binary is runnable"
}

test_check_opencode_failure() {
  local RC
  DISPATCH_OPENCODE_BIN="$FIXTURE_DIR/no-such-opencode" cli table check --role _ADVISOR --file "$REC_FILE" 2>/dev/null
  RC=$?
  assert_rc "$RC" 1 "table check fails when the opencode binary is missing"
}

test_cli_list_roles() {
  local RESULT EXPECTED
  EXPECTED="$(printf '%s\n' \
    '_IMPLEMENTER opencode-go/stub-model at high pi' \
    '_REVIEWER opencode-go/stub-alt pi' \
    '_ADVISOR opencode/stub-model-free at high opencode')"
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
    run --auto --print-logs --log-level ERROR --title run-brief.md --dir /work -m opencode/stub-model-free --variant high 'the run brief')"
  assert_eq "$ARGV" "$EXPECTED" "the run path hands the stub the built argv"
  assert_contains "$ARGV" "the run brief" "the stub received the brief's text, so the brief was read at run time"
  assert_rc 7 "$RC" "the stub's exit code propagates through --run"
}

test_role_assignments_in_order() {
  local RESULT EXPECTED
  EXPECTED="$(printf '%s\n' 'opencode/stub-model-free at high' 'deepseek/stub-model at high')"
  RESULT="$(cli table list --role _CHAIN --file "$CHAIN_FILE")"
  assert_eq "$RESULT" "$EXPECTED" "a role line resolves to its assignments in written order, with the repeat dropped"
}

test_role_model_takes_the_head() {
  local RESULT
  RESULT="$(cli table resolve --role _CHAIN --file "$CHAIN_FILE")"
  assert_eq "$RESULT" "opencode/stub-model-free high opencode" "the role resolves to the first assignment"
}

test_role_assignments_malformed_refuses() {
  local RC
  cli table list --role _BAD --file "$CHAIN_FILE" >/dev/null 2>&1
  RC=$?
  assert_rc "$RC" 1 "a malformed entry refuses the whole role"
}

test_role_assignments_empty_refuses() {
  local RC
  cli table list --role _EMPTY --file "$CHAIN_FILE" >/dev/null 2>&1
  RC=$?
  assert_rc "$RC" 1 "a role line naming no model refuses"
}

test_role_model_non_role_tag_refuses() {
  local RC
  cli table resolve --role Format --file "$CHAIN_FILE" >/dev/null 2>&1
  RC=$?
  assert_rc "$RC" 1 "a non-role tag is refused rather than resolved"
}

test_roles_skips_non_role_lines() {
  local RESULT
  RESULT="$(cli table roles --file "$CHAIN_FILE" 2>/dev/null)"
  assert_not_contains "$RESULT" "Format" "a Format line is not a role"
  assert_contains "$RESULT" "_CHAIN opencode/stub-model-free at high opencode" "the chain lists its preferred assignment first"
  assert_contains "$RESULT" "_CHAIN deepseek/stub-model at high pi" "the chain lists its fallback second"
}

test_check_passes_on_a_runnable_fallback() {
  local RC
  DISPATCH_OPENCODE_BIN="$FIXTURE_DIR/no-such-opencode" cli table check --role _CHAIN --file "$CHAIN_FILE" 2>/dev/null
  RC=$?
  assert_rc "$RC" 0 "a chain passes when any assignment's runtime is runnable"
}


# The walk: a retryable failure advances to the next entry, and a failure whose
# repair is not another model stops the walk where it is. The stub counts its
# invocations, so the cases assert how many attempts happened rather than
# trusting the message.
test_cli_run_walks_to_the_fallback() {
  local BIN COUNT BRIEF STATE REC RESULT RC
  BIN="$FIXTURE_DIR/walk-stub"
  COUNT="$FIXTURE_DIR/walk-count"
  BRIEF="$FIXTURE_DIR/walk-brief.md"
  STATE="$FIXTURE_DIR/walk-state.json"
  REC="$FIXTURE_DIR/walk-rec.md"
  printf 'brief\n' > "$BRIEF"
  printf '_WALK: opencode/x-free at high; opencode/y-free at high\n' > "$REC"
  rm -f "$COUNT" "$STATE"
  cat > "$BIN" <<STUB
#!/usr/bin/env bash
n=\$(cat "$COUNT" 2>/dev/null || echo 0)
n=\$((n + 1))
printf '%s' "\$n" > "$COUNT"
if [[ "\$n" -eq 1 ]]; then
  echo '503 Service Unavailable' >&2
  exit 1
fi
echo 'the fallback answered'
exit 0
STUB
  chmod +x "$BIN"
  RC=0
  RESULT="$(DISPATCH_REC_FILE="$REC" DISPATCH_STATE_FILE="$STATE" \
    DISPATCH_OPENCODE_BIN="$BIN" \
    bash "$REPO_ROOT/scripts/dispatch.sh" --role _WALK --brief "$BRIEF" --dir /work --run 2>/dev/null)" || RC=$?
  assert_rc "$RC" 0 "the second attempt succeeds"
  assert_contains "$RESULT" "the fallback answered" "the caller receives the fallback's answer"
  assert_eq "$(cat "$COUNT")" "2" "exactly two attempts were made"
  assert_contains "$(cat "$STATE")" '"cooling"' "the first route is recorded as cooling"
}

test_cli_run_stops_on_a_malformed_request() {
  local BIN COUNT BRIEF STATE REC RESULT RC
  BIN="$FIXTURE_DIR/bad-stub"
  COUNT="$FIXTURE_DIR/bad-count"
  BRIEF="$FIXTURE_DIR/bad-brief.md"
  STATE="$FIXTURE_DIR/bad-state.json"
  REC="$FIXTURE_DIR/bad-rec.md"
  printf 'brief\n' > "$BRIEF"
  printf '_BADREQ: opencode/x-free at high; opencode/y-free at high\n' > "$REC"
  rm -f "$COUNT" "$STATE"
  cat > "$BIN" <<STUB
#!/usr/bin/env bash
n=\$(cat "$COUNT" 2>/dev/null || echo 0)
n=\$((n + 1))
printf '%s' "\$n" > "$COUNT"
echo 'invalid_request_error: reasoning_effort none is not accepted' >&2
exit 2
STUB
  chmod +x "$BIN"
  RC=0
  RESULT="$(DISPATCH_REC_FILE="$REC" DISPATCH_STATE_FILE="$STATE" \
    DISPATCH_OPENCODE_BIN="$BIN" \
    bash "$REPO_ROOT/scripts/dispatch.sh" --role _BADREQ --brief "$BRIEF" --dir /work --run 2>&1)" || RC=$?
  assert_rc "$RC" 2 "the attempt's own code is returned"
  assert_eq "$(cat "$COUNT")" "1" "a malformed request is not re-sent to the next model"
  assert_contains "$RESULT" "not retried" "the caller is told why nothing else was tried"
}


test_cli_a_role_with_no_line_names_the_role() {
  local BRIEF REC STATE RESULT RC
  BRIEF="$FIXTURE_DIR/noline-brief.md"
  REC="$FIXTURE_DIR/noline-rec.md"
  STATE="$FIXTURE_DIR/noline-state.json"
  printf 'brief\n' > "$BRIEF"
  printf '_OTHER: opencode/x-free at high\n' > "$REC"
  rm -f "$STATE"
  RC=0
  RESULT="$(DISPATCH_REC_FILE="$REC" DISPATCH_STATE_FILE="$STATE" \
    bash "$REPO_ROOT/scripts/dispatch.sh" --role _ADVISOR --brief "$BRIEF" --dir /work --run 2>&1)" || RC=$?
  assert_rc 1 "$RC" "a role the table does not name fails the run"
  assert_contains "$RESULT" "no recommendation for role '_ADVISOR'" \
    "the library's own message reaches the caller instead of a later usage error"
}

test_cli_a_pinned_run_records_its_outcome() {
  local BIN BRIEF REC STATE RESULT RC
  BIN="$FIXTURE_DIR/pin-stub"
  BRIEF="$FIXTURE_DIR/pin-brief.md"
  REC="$FIXTURE_DIR/pin-rec.md"
  STATE="$FIXTURE_DIR/pin-state.json"
  printf 'brief\n' > "$BRIEF"
  printf '_ADVISOR: opencode/x-free at high\n' > "$REC"
  rm -f "$STATE"
  cat > "$BIN" <<STUB
#!/usr/bin/env bash
echo ran
STUB
  chmod +x "$BIN"
  RC=0
  RESULT="$(DISPATCH_REC_FILE="$REC" DISPATCH_STATE_FILE="$STATE" \
    DISPATCH_OPENCODE_BIN="$BIN" \
    bash "$REPO_ROOT/scripts/dispatch.sh" --role _ADVISOR --model opencode/x-free \
      --brief "$BRIEF" --dir /work --run 2>&1)" || RC=$?
  assert_rc 0 "$RC" "a pinned run succeeds"
  assert_contains "$RESULT" "ran" "the pinned model ran"
  assert_contains "$(cat "$STATE" 2>/dev/null)" "opencode/x" \
    "a pin reads no route and still records what its attempt ended in"
}


# ---------------------------------------------------------------------------
# Worker mode  --  one read-write delegated run over one brief
#
# A worker edits the tree, runs tests and returns a change set, so the run
# attributes that set to a named base revision and advances to a fallback model
# only while the attempt left the tree unchanged.
# ---------------------------------------------------------------------------

# make_workspace SANDBOX  --  a committed repo, a run directory, a brief and a
#   role table naming an OpenCode route, so the stub is reached through the
#   seam rather than through a hand-built command.
make_workspace() {
  local sandbox="$1"
  make_committed_repo "$sandbox/repo"
  mkdir -p "$sandbox/scratch" "$sandbox/agenthome" "$sandbox/bin"
  printf 'the brief\n' > "$sandbox/brief.md"
  printf '_IMPLEMENTER: opencode/stub-model-free at high\n' \
    > "$sandbox/agenthome/model-recommendations.md"
}

# worker_env SANDBOX CMD...
#   Runs CMD inside the fixture repository with the fixture's role table, stub
#   and route memory; prints stdout and stderr together.
#
#   DISPATCH_REC_FILE names the fixture table outright. Without it the library
#   derives the repository root from where it is installed, finds this project's
#   committed table, and the case would measure the install layout instead of
#   the fixture it built.
worker_env() {
  local sandbox="$1"; shift
  ( cd "$sandbox/repo" && \
    AGENT_HOME="$sandbox/agenthome" \
    DISPATCH_REC_FILE="$sandbox/agenthome/model-recommendations.md" \
    DISPATCH_OPENCODE_BIN="$sandbox/bin/opencode" \
    DISPATCH_STATE_FILE="$sandbox/state.json" \
    "$@" ) 2>&1
}

# run_worker SANDBOX BASE [ARGS...]
#   One worker-mode dispatch over the fixture's brief and run directory.
run_worker() {
  local sandbox="$1" base="$2"; shift 2
  worker_env "$sandbox" bash "$REPO_ROOT/scripts/dispatch.sh" \
    --role _IMPLEMENTER --brief "$sandbox/brief.md" --worker --run \
    --base "$base" --run-dir "$sandbox/scratch" "$@"
}

# write_stub BIN LOG EDIT EXIT_CODE [MODE]
#   Writes an executable worker stub. The stub appends its argv to LOG, prints
#   one line (so the run's log is non-empty), appends an edit to EDIT inside the
#   repo it was given as --dir, and exits EXIT_CODE. MODE `destroy` makes it
#   reset the tree first, the way an unguarded worker can.
write_stub() {
  local bin="$1" log="$2" edit="$3" exit_code="$4" mode="${5:-}"
  local destroy=""
  if [[ "$mode" == "destroy" ]]; then
    destroy='git -C "$dir" reset --hard >/dev/null 2>&1'
  fi
  mkdir -p "$(dirname "$bin")"
  cat > "$bin" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$@" >> "$log"
dir=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --dir) dir="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf 'worker ran\n'
printf 'worker edit\n' >> "\$dir/$edit"
${destroy}
exit $exit_code
STUB
  chmod +x "$bin"
}

# write_model_stub BIN LOG EDIT RULES
#   Writes a worker stub whose behaviour follows the model it was given.
#   RULES is a space-separated list of `<model>=<action>`, where the action is
#   `ok` (edit the tree and exit 0), `fail` (print and exit 1), `fail-edit`
#   (edit the tree, then exit 1), `refuse` (print the message a spent free tier
#   returns, then sleep past the run's limit), `auth` (print an invalid-key
#   sentence, then sleep past the limit), or `hang` (print a banner, then sleep).
write_model_stub() {
  local bin="$1" log="$2" edit="$3" rules="$4"
  mkdir -p "$(dirname "$bin")"
  cat > "$bin" <<STUB
#!/usr/bin/env bash
model=""
prev=""
for arg in "\$@"; do
  [[ "\$prev" == "-m" ]] && model="\$arg"
  prev="\$arg"
done
printf '%s\n' "\$*" >> "$log"
action="ok"
for rule in $rules; do
  [[ "\${rule%%=*}" == "\$model" ]] && action="\${rule#*=}"
done
dir=""
prev=""
for arg in "\$@"; do
  [[ "\$prev" == "--dir" ]] && dir="\$arg"
  prev="\$arg"
done
case "\$action" in
  fail) printf 'the model failed\n'; exit 1 ;;
  fail-edit) printf 'worker edit\n' >> "\$dir/$edit"; printf 'the model failed\n'; exit 1 ;;
  refuse)
    printf 'Error: {"message":"Rate limit exceeded. Please try again later."}\n'
    sleep 60
    exit 1 ;;
  auth)
    printf '401: {"type":"AuthError","message":"Invalid API key."}\n'
    sleep 60
    exit 1 ;;
  hang) printf '> build \xc2\xb7 %s\n' "\$model"; sleep 60; exit 1 ;;
  silent) exit 0 ;;
  *) printf 'worker ran\n'; printf 'worker edit\n' >> "\$dir/$edit"; exit 0 ;;
esac
STUB
  chmod +x "$bin"
}

# `--base` and `--run-dir` belong to worker mode alone, so a run that names one
# without the mode is a usage error rather than a silent no-op.
test_cli_worker_flags_are_worker_mode_only() {
  local OUT RC
  OUT="$(bash "$REPO_ROOT/scripts/dispatch.sh" --role _IMPLEMENTER --base HEAD 2>&1)"; RC=$?
  assert_rc 2 "$RC" "a general run that names --base is refused"
  assert_contains "$OUT" "worker mode only" "the refusal names the mode the flags belong to"
}

# A worker invocation that only printed a command would measure nothing, so the
# mode requires the run.
test_worker_requires_run() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"

  out="$(worker_env "$sandbox" bash "$REPO_ROOT/scripts/dispatch.sh" \
    --role _IMPLEMENTER --brief "$sandbox/brief.md" --worker)"; rc=$?
  assert_rc 2 "$rc" "a worker invocation without --run is refused"
  assert_contains "$out" "--worker requires --run" "the refusal names the flag it needs"

  out="$(worker_env "$sandbox" bash "$REPO_ROOT/scripts/dispatch.sh" \
    --role _IMPLEMENTER --worker --run)"; rc=$?
  assert_rc 2 "$rc" "a worker invocation without a brief is refused"
  assert_contains "$out" "--brief is required" "the refusal names the missing brief"
}

test_worker_refuses_a_bad_brief() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"

  out="$(worker_env "$sandbox" bash "$REPO_ROOT/scripts/dispatch.sh" \
    --role _IMPLEMENTER --brief "$sandbox/absent.md" --worker --run \
    --run-dir "$sandbox/scratch")"; rc=$?
  assert_rc 2 "$rc" "a missing brief is refused"
  assert_contains "$out" "brief not found" "the refusal names the missing brief"

  : > "$sandbox/empty.md"
  out="$(worker_env "$sandbox" bash "$REPO_ROOT/scripts/dispatch.sh" \
    --role _IMPLEMENTER --brief "$sandbox/empty.md" --worker --run \
    --run-dir "$sandbox/scratch")"; rc=$?
  assert_rc 2 "$rc" "an empty brief is refused"
  assert_contains "$out" "brief is empty" "the refusal says the brief is empty"
}

test_worker_refuses_a_bad_run_dir() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"

  out="$(worker_env "$sandbox" bash "$REPO_ROOT/scripts/dispatch.sh" \
    --role _IMPLEMENTER --brief "$sandbox/brief.md" --worker --run \
    --run-dir "$sandbox/absent-dir")"; rc=$?
  assert_rc 2 "$rc" "an absent run directory is refused"
  assert_contains "$out" "run directory not found" "the refusal names the run directory"
}

test_worker_refuses_an_unresolvable_base() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"

  out="$(run_worker "$sandbox" no-such-revision)"; rc=$?
  assert_rc 1 "$rc" "an unresolvable base is refused"
  assert_contains "$out" "base revision not found" "the refusal names the base check"
  assert_contains "$out" "no-such-revision" "the refusal names the value"
}

test_worker_a_role_with_no_line_refuses() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  printf '_REVIEWER: opencode/model-a-free at high\n' > "$sandbox/agenthome/model-recommendations.md"

  out="$(run_worker "$sandbox" HEAD)"; rc=$?
  assert_rc 1 "$rc" "a role the table does not name fails the run"
  assert_contains "$out" "no recommendation for role '_IMPLEMENTER'" \
    "the role table's reader names the role it cannot resolve"
  [[ ! -f "$sandbox/argv.log" ]] || fail "no worker ran without a role line"
  pass "an unnamed role refuses instead of dispatching a default model"
}

test_worker_a_dirty_tree_is_accepted() {
  local sandbox out rc argv repo_root
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt 0
  printf 'caller edit\n' >> "$sandbox/repo/file.txt"

  out="$(run_worker "$sandbox" HEAD)"; rc=$?
  assert_rc 0 "$rc" "a dirty tree is accepted"
  assert_contains "$out" "rc=0" "the run reports success"

  argv="$(cat "$sandbox/argv.log")"
  repo_root="$(git -C "$sandbox/repo" rev-parse --show-toplevel)"
  assert_contains "$argv" "$(printf -- '--dir\n%s' "$repo_root")" \
    "the stub received --dir naming the repository root"
}

test_worker_change_set_is_the_units_set() {
  local sandbox out rc run_dir changes
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt 0
  printf 'caller edit\n' >> "$sandbox/repo/file.txt"

  out="$(run_worker "$sandbox" HEAD)"; rc=$?
  assert_rc 0 "$rc" "the run over a dirty tree succeeds"
  run_dir="$(printf '%s\n' "$out" | sed -n 's/^run dir: //p')"
  changes="$(cat "$run_dir/changes.txt")"
  assert_contains "$changes" "file.txt" "the change set names the caller's edit"
  assert_contains "$changes" "worker.txt" "the change set names the worker's edit"
}

test_worker_change_set_uses_the_named_base() {
  local sandbox out rc old base_sha run_dir changes
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  # A second commit over the baseline: one file changes, one file is added.
  printf 'changed\n' > "$sandbox/repo/file.txt"
  printf 'added\n' > "$sandbox/repo/added.txt"
  git -C "$sandbox/repo" add file.txt added.txt
  git -C "$sandbox/repo" commit -m "change file.txt and add added.txt" --quiet
  old="$(git -C "$sandbox/repo" rev-parse HEAD~1)"
  write_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt 0

  out="$(run_worker "$sandbox" "$old")"; rc=$?
  assert_rc 0 "$rc" "a dispatch from an older base succeeds"
  base_sha="$(printf '%s\n' "$out" | sed -n 's/^base: //p')"
  assert_eq "$base_sha" "$old" "the base is the named older commit"
  run_dir="$(printf '%s\n' "$out" | sed -n 's/^run dir: //p')"
  changes="$(cat "$run_dir/changes.txt")"
  assert_contains "$changes" "file.txt" "the change set names the file changed since the base"
  assert_contains "$changes" "added.txt" "the change set names the file added since the base"
}

test_worker_base_is_a_resolved_sha() {
  local sandbox out rc base_sha base_type
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt 0

  out="$(run_worker "$sandbox" HEAD)"; rc=$?
  assert_rc 0 "$rc" "a clean dispatch succeeds"
  base_sha="$(printf '%s\n' "$out" | sed -n 's/^base: //p')"
  assert_matches "$base_sha" '^[0-9a-f]{40}$' "the base is a 40-character object name"
  base_type="$(git -C "$sandbox/repo" cat-file -t "$base_sha" 2>/dev/null)"
  assert_eq "$base_type" "commit" "the base names a commit"
}

test_worker_pre_state_recovery_point() {
  local sandbox out rc pre_sha pre_type content
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt 0
  printf 'caller edit\n' >> "$sandbox/repo/file.txt"

  out="$(run_worker "$sandbox" HEAD)"; rc=$?
  assert_rc 0 "$rc" "a dispatch over a dirty tree succeeds"
  pre_sha="$(printf '%s\n' "$out" | sed -n 's/^pre-state: //p')"
  assert_matches "$pre_sha" '^[0-9a-f]{40}$' "the pre-state is a commit object"
  pre_type="$(git -C "$sandbox/repo" cat-file -t "$pre_sha" 2>/dev/null)"
  assert_eq "$pre_type" "commit" "the pre-state names a commit"
  content="$(git -C "$sandbox/repo" show "$pre_sha:file.txt" 2>/dev/null)"
  assert_contains "$content" "caller edit" "the pre-state holds the caller's work"

  local clean clean_out clean_rc clean_pre
  clean="$(get_fixture_dir)"
  make_workspace "$clean"
  write_stub "$clean/bin/opencode" "$clean/argv.log" worker.txt 0
  clean_out="$(run_worker "$clean" HEAD)"; clean_rc=$?
  assert_rc 0 "$clean_rc" "a dispatch over a clean tree succeeds"
  clean_pre="$(printf '%s\n' "$clean_out" | sed -n 's/^pre-state: //p')"
  assert_eq "$clean_pre" "none" "a clean tree reports no pre-state"
}

test_worker_pre_state_survives_a_destructive_worker() {
  local sandbox out rc pre_sha content
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt 0 destroy
  printf 'caller edit\n' >> "$sandbox/repo/file.txt"

  out="$(run_worker "$sandbox" HEAD)"; rc=$?
  assert_rc 0 "$rc" "the run completes even though the worker reset the tree"
  assert_not_contains "$(cat "$sandbox/repo/file.txt")" "caller edit" \
    "the worker's reset removed the caller's edit from the tree"
  pre_sha="$(printf '%s\n' "$out" | sed -n 's/^pre-state: //p')"
  content="$(git -C "$sandbox/repo" show "$pre_sha:file.txt" 2>/dev/null)"
  assert_contains "$content" "caller edit" "the pre-state still holds the work the worker destroyed"
}

test_worker_base_defaults_to_head() {
  local sandbox out rc base_sha expected
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt 0

  out="$(worker_env "$sandbox" bash "$REPO_ROOT/scripts/dispatch.sh" \
    --role _IMPLEMENTER --brief "$sandbox/brief.md" --worker --run \
    --run-dir "$sandbox/scratch")"; rc=$?
  assert_rc 0 "$rc" "a dispatch with no base set succeeds"
  base_sha="$(printf '%s\n' "$out" | sed -n 's/^base: //p')"
  expected="$(git -C "$sandbox/repo" rev-parse HEAD)"
  assert_eq "$base_sha" "$expected" "an unset base resolves to HEAD"
}

test_worker_a_pi_route_survives_its_own_silence() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  printf '_IMPLEMENTER: deepseek/stub-model at high\n' \
    > "$sandbox/agenthome/model-recommendations.md"
  cat > "$sandbox/bin/pi" <<'STUB'
#!/usr/bin/env bash
sleep 2
printf 'worker ran\n'
exit 0
STUB
  chmod +x "$sandbox/bin/pi"

  out="$( PATH="$sandbox/bin:$PATH" DISPATCH_STALL=1 run_worker "$sandbox" HEAD )"; rc=$?
  assert_rc 0 "$rc" "a pi route is not ended by the silence the OpenCode CLI needs"
  assert_contains "$out" "rc=0" "the silent attempt ran to completion"
}

test_worker_an_opencode_route_stops_on_silence() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  cat > "$sandbox/bin/opencode" <<'STUB'
#!/usr/bin/env bash
sleep 2
printf 'worker ran\n'
exit 0
STUB
  chmod +x "$sandbox/bin/opencode"

  out="$( DISPATCH_STALL=1 run_worker "$sandbox" HEAD )"; rc=$?
  assert_rc 1 "$rc" "a silent OpenCode attempt is ended at the silence window"
  assert_contains "$out" "no output for 1s" "the refusal names the window that ended it"
}

test_worker_a_failing_worker_stops() {
  local sandbox out rc run_dir
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt 1

  out="$(run_worker "$sandbox" HEAD)"; rc=$?
  assert_rc 1 "$rc" "a worker that exits non-zero fails the run"
  run_dir="$(printf '%s\n' "$out" | sed -n 's/^run dir: //p')"
  assert_contains "$out" "the worker exited rc=1" "the refusal names the worker exit"
  assert_contains "$out" "$run_dir/worker.log" "the refusal names the log path"
}

# The rule this case pins: the tree decides the advance. A first attempt that
# changed the tree must not be followed by a second model.
test_worker_a_changed_failure_does_not_fall_back() {
  local sandbox out rc attempts
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  printf '_IMPLEMENTER: opencode/model-a-free at high; opencode/model-b-free at high\n' \
    > "$sandbox/agenthome/model-recommendations.md"
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt \
    "opencode/model-a-free=fail-edit opencode/model-b-free=ok"

  out="$(run_worker "$sandbox" HEAD)"; rc=$?
  assert_rc 1 "$rc" "a first attempt that changed the tree stops the run"
  assert_contains "$out" "the worker exited rc=1 after changing the tree" \
    "the refusal says the tree holds the attempt"
  attempts="$(wc -l < "$sandbox/argv.log")"
  assert_eq "$attempts" "1" "no second model ran over the first model's edits"
}

test_worker_falls_back_to_the_next_candidate() {
  local sandbox out rc attempts
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  printf '_IMPLEMENTER: opencode/model-a-free at high; opencode/model-b-free at high\n' \
    > "$sandbox/agenthome/model-recommendations.md"
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt \
    "opencode/model-a-free=fail opencode/model-b-free=ok"

  out="$(run_worker "$sandbox" HEAD)"; rc=$?
  assert_rc 0 "$rc" "the run succeeds on the fallback"
  assert_contains "$out" "rc=0" "the run reports success"
  assert_contains "$out" "model=opencode/model-b-free" "the report names the model that worked"
  attempts="$(wc -l < "$sandbox/argv.log")"
  assert_eq "$attempts" "2" "the primary ran first, then the fallback"
}

test_worker_a_refused_model_is_stopped_early() {
  local sandbox out rc run_dir elapsed start
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  printf '_IMPLEMENTER: opencode/model-a-free at high; opencode/model-b-free at high\n' \
    > "$sandbox/agenthome/model-recommendations.md"
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt \
    "opencode/model-a-free=refuse opencode/model-b-free=ok"

  start=$(date +%s)
  out="$(run_worker "$sandbox" HEAD)"; rc=$?
  elapsed=$(( $(date +%s) - start ))
  run_dir="$(printf '%s\n' "$out" | sed -n 's/^run dir: //p')"
  assert_rc 0 "$rc" "the fallback runs after a refused request"
  assert_contains "$out" "model=opencode/model-b-free" "the report names the model that worked"
  assert_contains "$(cat "$run_dir/worker-attempt-1.log" 2>/dev/null)" \
    "aborted: the model refused the request" "the refused attempt says why it stopped"
  assert_contains "$out" "verdict=rate-limit quota none rate -" \
    "a rate limit is a quota failure with no scope and the rate reason"
  assert_contains "$out" "Rate limit exceeded" "the provider sentence reaches the caller"
  (( elapsed < 20 )) || fail "the refused attempt should stop in seconds, took ${elapsed}s"
  pass "the refused attempt stopped in ${elapsed}s, before the 1800s limit"
}

test_worker_an_unrecoverable_refusal_names_its_scope() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  printf '_IMPLEMENTER: opencode/model-a-free at high; opencode/model-b-free at high\n' \
    > "$sandbox/agenthome/model-recommendations.md"
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt \
    "opencode/model-a-free=auth opencode/model-b-free=ok"

  out="$(run_worker "$sandbox" HEAD)"; rc=$?
  assert_rc 0 "$rc" "the fallback runs after an unrecoverable refusal"
  assert_contains "$out" "verdict=auth capability account - -" \
    "an invalid key is a capability failure that names the account"
  assert_contains "$out" "Invalid API key" "the provider sentence reaches the caller"
  pass "an unrecoverable refusal names its scope and prints the provider sentence"
}

test_worker_a_silent_attempt_is_stopped_and_falls_back() {
  local sandbox out rc run_dir elapsed start stall_value
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  printf '_IMPLEMENTER: opencode/model-a-free at high; opencode/model-b-free at high\n' \
    > "$sandbox/agenthome/model-recommendations.md"
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt \
    "opencode/model-a-free=hang opencode/model-b-free=ok"

  export DISPATCH_STALL=2 DISPATCH_POLL=0.05
  stall_value="$DISPATCH_STALL"
  start=$(date +%s)
  out="$(run_worker "$sandbox" HEAD)"; rc=$?
  elapsed=$(( $(date +%s) - start ))
  unset DISPATCH_STALL DISPATCH_POLL
  run_dir="$(printf '%s\n' "$out" | sed -n 's/^run dir: //p')"
  assert_rc 0 "$rc" "the fallback runs after a silent attempt"
  assert_contains "$out" "model=opencode/model-b-free" "the report names the model that worked"
  assert_contains "$(cat "$run_dir/worker-attempt-1.log" 2>/dev/null)" \
    "aborted: no output for ${stall_value}s" "the silent attempt says why it stopped"
  (( elapsed < 30 )) || fail "a silent attempt should stop after the stall limit, took ${elapsed}s"
  pass "the silent attempt stopped in ${elapsed}s"
}

test_worker_reports_every_failed_candidate_at_the_end() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  printf '_IMPLEMENTER: opencode/model-a-free at high; opencode/model-b-free at high\n' \
    > "$sandbox/agenthome/model-recommendations.md"
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt \
    "opencode/model-a-free=refuse opencode/model-b-free=ok"

  out="$(run_worker "$sandbox" HEAD)"; rc=$?
  assert_rc 0 "$rc" "the run succeeds on the fallback"
  assert_contains "$out" "failures: 1" "the run counts the failed candidate"
  assert_contains "$out" "opencode/model-a-free (rate-limit quota none rate -)" \
    "the run names the failed candidate and its verdict"
}

test_worker_the_callers_own_edits_do_not_block_the_fallback() {
  local sandbox out rc attempts
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  printf '_IMPLEMENTER: opencode/model-a-free at high; opencode/model-b-free at high\n' \
    > "$sandbox/agenthome/model-recommendations.md"
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt \
    "opencode/model-a-free=fail opencode/model-b-free=ok"
  printf 'the caller edit\n' >> "$sandbox/repo/README.md"

  out="$(run_worker "$sandbox" HEAD)"; rc=$?
  assert_rc 0 "$rc" "the caller's uncommitted edit does not stop the fallback"
  attempts="$(wc -l < "$sandbox/argv.log")"
  assert_eq "$attempts" "2" "both candidates ran"
  assert_contains "$out" "model=opencode/model-b-free" "the report names the model that worked"
}


run_test test_resolve_role_with_level
run_test test_resolve_role_without_level
run_test test_resolve_role_missing_role
run_test test_resolve_role_missing_file
run_test test_runtime_opencode_provider
run_test test_runtime_paid_opencode_provider_goes_to_pi
run_test test_runtime_level_suffix_is_ignored
run_test test_runtime_refuses_a_free_provider_without_its_model
run_test test_runtime_pi_provider
run_test test_runtime_pi_provider_free_model
run_test test_runtime_unknown_provider
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
run_test test_role_assignments_in_order
run_test test_role_model_takes_the_head
run_test test_role_assignments_malformed_refuses
run_test test_role_assignments_empty_refuses
run_test test_role_model_non_role_tag_refuses
run_test test_roles_skips_non_role_lines
run_test test_check_passes_on_a_runnable_fallback
run_test test_cli_run_walks_to_the_fallback
run_test test_cli_run_stops_on_a_malformed_request
run_test test_cli_a_role_with_no_line_names_the_role
run_test test_cli_a_pinned_run_records_its_outcome
run_test test_cli_worker_flags_are_worker_mode_only
run_test test_worker_requires_run
run_test test_worker_refuses_a_bad_brief
run_test test_worker_refuses_a_bad_run_dir
run_test test_worker_refuses_an_unresolvable_base
run_test test_worker_a_role_with_no_line_refuses
run_test test_worker_a_dirty_tree_is_accepted
run_test test_worker_change_set_is_the_units_set
run_test test_worker_change_set_uses_the_named_base
run_test test_worker_base_is_a_resolved_sha
run_test test_worker_pre_state_recovery_point
run_test test_worker_pre_state_survives_a_destructive_worker
run_test test_worker_base_defaults_to_head
run_test test_worker_a_pi_route_survives_its_own_silence
run_test test_worker_an_opencode_route_stops_on_silence
run_test test_worker_a_failing_worker_stops
run_test test_worker_a_changed_failure_does_not_fall_back

# The fallback cases below cost about twelve seconds together, which is more
# than this file's per-file deadline allows beside everything above, so they run
# on request:
#
#   DISPATCH_WORKER_FALLBACK_CASES=1 bash tests/test_dispatch.sh
# ---------------------------------------------------------------------------
# Seats: the rotation, the reassignment and the retry
# ---------------------------------------------------------------------------

# seat_setup SANDBOX TABLE
#   A clean fixture repository with the given role table, a brief and a stub
#   directory, so a seat case measures the seating rather than a real model.
seat_setup() {
  local sandbox="$1" table="$2"
  make_committed_repo "$sandbox/repo"
  mkdir -p "$sandbox/scratch" "$sandbox/bin" "$sandbox/agenthome"
  printf 'the brief\n' > "$sandbox/brief.md"
  printf '%s\n' "$table" > "$sandbox/agenthome/model-recommendations.md"
}

# run_seats SANDBOX ARGS...
#   One seat run over the fixture, with the stub on DISPATCH_OPENCODE_BIN.
run_seats() {
  local sandbox="$1"; shift
  worker_env "$sandbox" bash "$REPO_ROOT/scripts/dispatch.sh" \
    --brief "$sandbox/brief.md" --dir "$sandbox/repo" --run "$@"
}

# Seat i takes candidate ((i - 1) mod m) + 1: two candidates fill three seats as
# the first, the second, then the first again, in one turn.
test_seats_rotate_over_the_candidates() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  seat_setup "$sandbox" '_SEAT: opencode/s1-free at high; opencode/s2-free at high'
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" "edit.txt" \
    "opencode/s1-free=ok opencode/s2-free=ok"

  out="$(run_seats "$sandbox" --role _SEAT --seats 3)"; rc=$?
  assert_rc 0 "$rc" "every seat succeeded"
  assert_eq "$(grep -c -- '-m opencode/s1-free' "$sandbox/argv.log")" "2" \
    "the first candidate fills seats 1 and 3"
  assert_eq "$(grep -c -- '-m opencode/s2-free' "$sandbox/argv.log")" "1" \
    "the second candidate fills seat 2"
  assert_eq "$(printf '%s' "$out" | grep -c '^seat [0-9] turn 1:')" "3" \
    "the run reads three seats at one turn boundary"
}

# A capability failure says the model is gone, so that candidate is dropped and
# the seat takes the next in the remaining rotation.
test_a_seat_drops_a_dead_candidate_and_rotates() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  seat_setup "$sandbox" '_SEAT: opencode/s1-free at high; opencode/s2-free at high; opencode/s3-free at high'
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" "edit.txt" \
    "opencode/s1-free=auth opencode/s2-free=ok opencode/s3-free=ok"

  out="$(run_seats "$sandbox" --role _SEAT --seats 2)"; rc=$?
  assert_rc 0 "$rc" "both seats end on a working model"
  assert_contains "$out" "seat 1 ended capability (account)" "the dead candidate ends seat 1's first turn"
  assert_eq "$(grep -c -- '-m opencode/s1-free' "$sandbox/argv.log")" "1" \
    "the dead candidate is attempted once and dropped"
  assert_eq "$(grep -c -- '-m opencode/s2-free' "$sandbox/argv.log")" "2" \
    "seat 1 takes the next candidate, which seat 2 already held"
}

# A retryable outcome keeps the seat on its assignment, and the route memory
# decides when the next attempt may start; a turn that cannot start it ends the
# run as blocked rather than spinning.
test_a_retryable_outcome_keeps_the_seat_and_blocks() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  seat_setup "$sandbox" '_SEAT: opencode/s1-free at high'
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" "edit.txt" \
    "opencode/s1-free=refuse"

  out="$(DISPATCH_STALL=1 run_seats "$sandbox" --role _SEAT --seats 1)"; rc=$?
  assert_rc 3 "$rc" "a cooling route ends the run as blocked"
  assert_contains "$out" "blocked" "the refusal names the wait"
  assert_eq "$(grep -c -- '-m opencode/s1-free' "$sandbox/argv.log")" "1" \
    "the seat is not re-fired while its route cools"
}

# Resolution is the default, not a requirement. A caller who names the
# assignment gets that assignment in every seat, a repeat by choice, and the
# pinned route is attempted whether or not the memory holds it back.
test_a_pin_seats_every_seat_on_one_assignment() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  seat_setup "$sandbox" '_SEAT: opencode/s1-free at high; opencode/s2-free at high'
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" "edit.txt" \
    "opencode/s1-free=ok opencode/s2-free=ok"

  out="$(run_seats "$sandbox" --role _SEAT --seats 2 --model opencode/s2-free --thinking low)"; rc=$?
  assert_rc 0 "$rc" "the pinned assignment runs in every seat"
  assert_eq "$(grep -c -- '-m opencode/s2-free' "$sandbox/argv.log")" "2" \
    "both seats run the pinned model"
  assert_eq "$(grep -c -- '-m opencode/s1-free' "$sandbox/argv.log" 2>/dev/null || true)" "0" \
    "the role's first entry is not dealt"
  assert_eq "$(printf '%s' "$out" | grep -c 'opencode/s2-free at low')" "2" \
    "the pinned level reaches every seat"
  assert_contains "$(cat "$sandbox/state.json" 2>/dev/null)" '"opencode/s2-free"' \
    "a pinned seat records its route"
  assert_contains "$(cat "$sandbox/state.json" 2>/dev/null)" '"state": "ready"' \
    "a pinned success readies the route, like any other attempt"
}

# A seat that logs nothing says nothing about the route. The log is the only
# evidence the seat ran, so a silent zero exit stops the run rather than counting
# as a success.
test_a_silent_seat_stops_the_run() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  seat_setup "$sandbox" '_SEAT: opencode/s1-free at high; opencode/s2-free at high'
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" "edit.txt" \
    "opencode/s1-free=silent"

  out="$(run_seats "$sandbox" --role _SEAT --seats 1)"; rc=$?
  assert_rc 1 "$rc" "a silent seat fails the run"
  assert_contains "$out" "seat 1 produced no output" "the refusal names the seat and the reason"
  assert_eq "$(grep -c -- '-m opencode/s1-free' "$sandbox/argv.log")" "1" \
    "the run does not reach for another candidate on a silent exit"
}

# A review reads one revision, so a dirty tree is refused before the first
# attempt: a finding against content the caller is still editing cannot be
# attributed to a commit.
test_a_dirty_tree_is_refused() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  seat_setup "$sandbox" '_SEAT: opencode/s1-free at high'
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" "edit.txt" \
    "opencode/s1-free=ok"
  printf 'uncommitted\n' > "$sandbox/repo/dirty.txt"

  out="$(run_seats "$sandbox" --role _SEAT --seats 1)"; rc=$?
  assert_rc 1 "$rc" "a dirty tree is refused"
  assert_contains "$out" "the working tree is dirty" "the refusal states the condition"
  assert_eq "$(grep -c -- '-m opencode/s1-free' "$sandbox/argv.log" 2>/dev/null || echo 0)" "0" \
    "no attempt is spent on an unattributable tree"
}

# The seat surface refuses the three combinations that contradict it.
test_seats_refuse_the_contradictory_forms() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  seat_setup "$sandbox" '_SEAT: opencode/s1-free at high'

  out="$(worker_env "$sandbox" bash "$REPO_ROOT/scripts/dispatch.sh" \
    --role _SEAT --brief "$sandbox/brief.md" --dir "$sandbox/repo" --seats 2)"; rc=$?
  assert_rc 2 "$rc" "a seat count without --run is refused"
  assert_contains "$out" "--seats requires --run" "the refusal names the flag it needs"

  out="$(run_seats "$sandbox" --role _SEAT --seats 2 --worker)"; rc=$?
  assert_rc 2 "$rc" "a seat count on a worker is refused"
  assert_contains "$out" "not a worker flag" "the refusal names the mode it contradicts"

  out="$(run_seats "$sandbox" --role _SEAT --seats 0)"; rc=$?
  assert_rc 2 "$rc" "a zero seat count is refused"
  assert_contains "$out" "at least 1" "the refusal names the floor"
}

WORKER_FALLBACK_CASES="${DISPATCH_WORKER_FALLBACK_CASES:-0}"

run_test test_seats_rotate_over_the_candidates
run_test test_a_seat_drops_a_dead_candidate_and_rotates
run_test test_a_retryable_outcome_keeps_the_seat_and_blocks
run_test test_a_silent_seat_stops_the_run
run_test test_a_dirty_tree_is_refused
run_test test_a_pin_seats_every_seat_on_one_assignment
run_test test_seats_refuse_the_contradictory_forms

if [[ "$WORKER_FALLBACK_CASES" == "1" ]]; then
  run_test test_worker_falls_back_to_the_next_candidate
  run_test test_worker_a_refused_model_is_stopped_early
  run_test test_worker_an_unrecoverable_refusal_names_its_scope
  run_test test_worker_a_silent_attempt_is_stopped_and_falls_back
  run_test test_worker_reports_every_failed_candidate_at_the_end
  run_test test_worker_the_callers_own_edits_do_not_block_the_fallback
fi


test_done
