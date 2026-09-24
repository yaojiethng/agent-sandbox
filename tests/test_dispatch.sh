#!/usr/bin/env bash
# tests/test_dispatch.sh  (exec-based dispatch oracle)
#
# Pins cite: roadmap "CLI surface" (l.94);
#             devlog/discussions/design-dispatch-cleanup-and-help-system.md.

# Dispatch oracle tests for the exec-based dispatch model. Asserts that
# agent-sandbox.sh main() routes flags and subcommands to the correct
# exec'd scripts with the correct arguments.
#
# Uses mock scripts on a temp SCRIPTS dir to capture invocations.
# No Docker, no git, no filesystem fixtures needed.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

# =============================================================================
# Mock infrastructure
# =============================================================================

CAPTURED=()

# mock_exec  --  capture exec calls without executing
mock_exec() { echo "capture: exec $*"; }

# =============================================================================
# Setup: source agent-sandbox.sh with mocks
# =============================================================================

setup() {
  CAPTURED=()
}

MOCK_SCRIPTS_DIR=""
setup_mocks() {
  MOCK_SCRIPTS_DIR=$(mktemp -d /tmp/test_dispatch_mocks_XXXXXX)

  # Create mock scripts for every subcommand that gets exec'd
  local scripts=(
    "onboard.sh"
    "stop.sh"
    "start_agent.sh"
  )
  local workflows=(
    "apply.sh"
    "draft.sh"
    "confirm.sh"
    "reject.sh"
  )
  local libs=(
    "package_branch.sh"
  )

  for s in "${scripts[@]}"; do
    cat > "$MOCK_SCRIPTS_DIR/$s" << SCRIPT
echo "capture: MOCK $s \$@"
SCRIPT
    chmod +x "$MOCK_SCRIPTS_DIR/$s"
  done

  for s in "${workflows[@]}"; do
    mkdir -p "$MOCK_SCRIPTS_DIR/workflows"
    cat > "$MOCK_SCRIPTS_DIR/workflows/$s" << SCRIPT
echo "capture: MOCK workflows/$s \$@"
SCRIPT
    chmod +x "$MOCK_SCRIPTS_DIR/workflows/$s"
  done

  for s in "${libs[@]}"; do
    mkdir -p "$MOCK_SCRIPTS_DIR/libs"
    cat > "$MOCK_SCRIPTS_DIR/libs/$s" << SCRIPT
echo "capture: MOCK libs/$s \$@"
SCRIPT
    chmod +x "$MOCK_SCRIPTS_DIR/libs/$s"
  done

  # build.sh gets a mock too  --  it will be exec'd by agent-sandbox build
  cat > "$MOCK_SCRIPTS_DIR/build.sh" << SCRIPT
echo "capture: MOCK build.sh \$@"
SCRIPT
  chmod +x "$MOCK_SCRIPTS_DIR/build.sh"

  # Note: no SCRIPTS override here. exec is replaced by mock_exec (see
  # source_harness), so the harness's dispatch never touches the real
  # script directory; a SCRIPTS assignment would be dead in this file.
}

source_harness() {
  # The dispatcher self-locates AGENT_SANDBOX_REPO only when it is unset; preset
  # it here so its top-level `source $AGENT_SANDBOX_REPO/src/libs/...` resolves
  # the real common.sh and env_resolve.sh. Source the real dispatcher directly
  # (no temp render: there is no @@AGENT_SANDBOX_REPO@@ placeholder anymore).
  export AGENT_SANDBOX_REPO="$REPO_ROOT"

  # Override exec to capture: the dispatcher's exec'd leaves are mocked.
  exec() { mock_exec "$@"; }

  source "$REPO_ROOT/scripts/agent-sandbox.sh"
}

# =============================================================================
# Helper: run main and capture
# =============================================================================

dispatch_and_capture() {
  CAPTURED=()
  local stdout
  stdout=$(main "$@" 2>/dev/null) || true
  while IFS= read -r line; do
    if [[ "$line" == capture:* ]]; then
      CAPTURED+=("${line#capture: }")
    fi
  done <<< "$stdout"
}


# =============================================================================
# Tests  --  build subcommand (exec's build.sh with --targets)
# =============================================================================

test_build_default_all() {
  setup
  dispatch_and_capture build --name=test --project=/tmp/p --sandbox=/tmp/s

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"build.sh"* ]] && [[ "$c" != *"MOCK"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "build (default): execs build.sh"
  else
    fail "build (default): expected exec build.sh, got: ${CAPTURED[*]}"
  fi
}

test_build_resolves_identity_from_env_file() {
  # Thin CLI: build with only --env (<sandbox>/.env path) and no identity flags
  # must resolve name/project/sandbox from that .env and forward them.
  setup
  local ENVDIR="$FIXTURE_DIR/dispatch_env"
  make_envfile "$ENVDIR"

  dispatch_and_capture build --env="$ENVDIR/.env"

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"build.sh"* ]] \
      && [[ "$c" == *"--name=envname"* ]] \
      && [[ "$c" == *"--project=/tmp/envproj"* ]] \
      && [[ "$c" == *"--sandbox=$ENVDIR"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "build resolves identity from --env (.env path) when no identity flags are given"
  else
    fail "build --env resolution not forwarded: ${CAPTURED[*]}"
  fi
}

test_build_resolves_identity_from_relative_env() {
  # Relative --env is a name relative to the sandbox dir (one contract across
  # resolver and leaf). build with --sandbox given and --env=custom.env resolves
  # name/dir from that relative file.
  setup
  local SBX="$FIXTURE_DIR/rel_env_sbx"
  mkdir -p "$SBX"
  printf 'PROJECT_NAME=relname\nPROJECT_DIR=/tmp/relproj\nSANDBOX_DIR=%s\n' "$SBX" > "$SBX/custom.env"

  dispatch_and_capture build --sandbox="$SBX" --env=custom.env

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"build.sh"* ]] \
      && [[ "$c" == *"--name=relname"* ]] \
      && [[ "$c" == *"--project=/tmp/relproj"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "build resolves identity from a sandbox-relative --env name"
  else
    fail "build relative --env not resolved sandbox-relative: ${CAPTURED[*]}"
  fi
}

test_build_with_targets() {
  setup
  dispatch_and_capture build --name=test --project=/tmp/p --sandbox=/tmp/s --targets=pi

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"build.sh"* ]] && [[ "$c" == *"--targets"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "build --targets=pi: passes --targets flag through"
  else
    fail "build --targets=pi: expected --targets in exec, got: ${CAPTURED[*]}"
  fi
}

test_build_with_rebuild() {
  setup
  dispatch_and_capture build --name=test --project=/tmp/p --sandbox=/tmp/s --rebuild

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"build.sh"* ]] && [[ "$c" == *"--rebuild"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "build --rebuild: passes --rebuild flag through"
  else
    fail "build --rebuild: expected --rebuild in exec, got: ${CAPTURED[*]}"
  fi
}

# =============================================================================
# Tests  --  start / serve / dry-run (call start_agent.sh as subprocess)
# =============================================================================

test_start_default() {
  setup
  dispatch_and_capture start --name=test --project=/tmp/p --sandbox=/tmp/s --provider=hermes

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"start_agent.sh"* ]] && [[ "$c" == *"standard"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "start: calls start_agent.sh in standard mode"
  else
    fail "start: expected exec bash start_agent.sh standard, got: ${CAPTURED[*]}"
  fi
}

test_start_forwards_env_to_leaf() {
  # The dispatcher consumes --env to resolve identity but must ALSO forward it
  # to start_agent.sh so a custom .env's runtime values reach the run (a
  # silently-dropped flag would rot the contract).
  setup
  local ENVDIR="$FIXTURE_DIR/dispatch_env_leaf"
  make_envfile "$ENVDIR"

  dispatch_and_capture start --env="$ENVDIR/.env" --provider=hermes

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"start_agent.sh"* ]] \
      && [[ "$c" == *"--name=envname"* ]] \
      && [[ "$c" == *"--project=/tmp/envproj"* ]] \
      && [[ "$c" == *"--sandbox=$ENVDIR"* ]] \
      && [[ "$c" == *"--env=$ENVDIR/.env"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "start: resolves identity from --env and forwards --env to the leaf"
  else
    fail "start --env not resolved+forwarded: ${CAPTURED[*]}"
  fi
}

test_resume_sandbox_and_env_forwarded() {
  # resume with only --env (no --sandbox): the dispatcher resolves SANDBOX_DIR
  # from the named .env and forwards both it and --env to the leaf, mirroring
  # the start contract so a custom.env session can be resumed with the same
  # pointer.
  setup
  local ENVDIR="$FIXTURE_DIR/dispatch_env_resume"
  make_envfile "$ENVDIR"

  dispatch_and_capture resume --env="$ENVDIR/.env" --list

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"resume_agent.sh"* ]] \
      && [[ "$c" == *"--sandbox=$ENVDIR"* ]] \
      && [[ "$c" == *"--env=$ENVDIR/.env"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "resume: resolves sandbox from --env and forwards --env to the leaf"
  else
    fail "resume --env not resolved+forwarded: ${CAPTURED[*]}"
  fi
}

test_serve_mode() {
  setup
  # serve is no longer a subcommand: it is a toggle on start. The dispatcher
  # forwards --serve through PASSTHROUGH; start_agent.sh maps it to MODE=serve.
  dispatch_and_capture start --name=test --project=/tmp/p --sandbox=/tmp/s --provider=hermes --serve

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"start_agent.sh"* ]] && [[ "$c" == *"--serve"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "serve toggle: start forwards --serve to start_agent.sh"
  else
    fail "serve toggle: expected exec bash start_agent.sh standard --serve, got: ${CAPTURED[*]}"
  fi
}

test_removed_serve_subcommand_is_unknown() {
  setup
  local output rc=0
  output=$(main serve --name=test --project=/tmp/p --sandbox=/tmp/s --provider=hermes 2>&1) || rc=$?

  if [[ "$rc" -ne 0 && "$output" == *"Unknown subcommand"* ]]; then
    pass "removed serve verb falls through to unknown-subcommand error"
  else
    fail "expected unknown-subcommand failure for 'serve', got rc=$rc: $output"
  fi
}

test_dry_run_mode() {
  setup
  dispatch_and_capture dry-run --name=test --project=/tmp/p --sandbox=/tmp/s --provider=hermes

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"start_agent.sh"* ]] && [[ "$c" == *"dry-run"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "dry-run: calls start_agent.sh in dry-run mode"
  else
    fail "dry-run: expected exec bash start_agent.sh dry-run, got: ${CAPTURED[*]}"
  fi
}

test_start_with_passthrough() {
  setup
  dispatch_and_capture start --name=test --project=/tmp/p --sandbox=/tmp/s --provider=hermes --extra-flag

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"start_agent.sh"* ]] && [[ "$c" == *"extra-flag"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "start: passes through extra flags"
  else
    fail "start: expected extra-flag in passthrough, got: ${CAPTURED[*]}"
  fi
}

test_start_passthrough_order_and_unknown_forms() {
  setup
  # Collect mode forwards every non-identity argument in order, including
  # unknown value-form flags and positional tokens, never erroring.
  dispatch_and_capture start --name=test --project=/tmp/p --sandbox=/tmp/s \
      --provider=hermes --bogus=1 --flag two three

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"start_agent.sh"* ]] \
      && [[ "$c" == *"--bogus=1 --flag two three"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "start: unknown value-form flags and positionals forwarded in order"
  else
    fail "start: expected --bogus=1 --flag two three in start_agent.sh args, got: ${CAPTURED[*]}"
  fi
}

# =============================================================================
# Tests  --  --rebuild / --refresh passthrough (via start subcommand)
# =============================================================================

test_start_rebuild_passthrough() {
  setup
  dispatch_and_capture start --name=test --project=/tmp/p --sandbox=/tmp/s --provider=hermes --rebuild

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"start_agent.sh"* ]] && [[ "$c" == *"--rebuild"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "start --rebuild: --rebuild flag forwarded to start_agent.sh via PASSTHROUGH"
  else
    fail "start --rebuild: expected --rebuild in start_agent.sh args, got: ${CAPTURED[*]}"
  fi
}

test_start_refresh_passthrough() {
  setup
  dispatch_and_capture start --name=test --project=/tmp/p --sandbox=/tmp/s --provider=hermes --refresh

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"start_agent.sh"* ]] && [[ "$c" == *"--refresh"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "start --refresh: --refresh flag forwarded to start_agent.sh via PASSTHROUGH"
  else
    fail "start --refresh: expected --refresh in start_agent.sh args, got: ${CAPTURED[*]}"
  fi
}

# =============================================================================
# Tests  --  help subcommand
# =============================================================================

test_help_no_args() {
  setup
  local output
  output=$(main help 2>&1) || true

  assert_contains "$output" "Valid subcommands" "help (no args): prints subcommand list"
}

# help for a leaf subcommand execs the leaf with --help. One data-driven
# test keeps the three per-leaf cases in a table instead of three copies.
test_help_leaf_subcommands() {
  local leaf
  for leaf in apply draft build; do
    setup
    dispatch_and_capture help "$leaf"

    if captured_has "exec" "${leaf}.sh" "--help"; then
      pass "help $leaf: execs ${leaf}.sh --help"
    else
      fail "help $leaf: expected exec ${leaf}.sh --help, got: ${CAPTURED[*]}"
    fi
  done
}

test_help_unknown() {
  setup
  local output
  output=$(main help nonexistent 2>&1) || true

  assert_contains "$output" "Unknown subcommand" "help nonexistent: prints error"
}

# --help/-h on any subcommand routes to the child's own help via route_help,
# WITHOUT requiring base args (they are absent on a bare --help invocation).
test_help_flag_routes_run_modes_to_start_agent() {
  # serve was removed as a verb; only start and dry-run route to start_agent.
  for mode in start dry-run; do
    setup
    dispatch_and_capture "$mode" --help

    local found=false
    for c in "${CAPTURED[@]}"; do
      [[ "$c" == "exec bash"*"start_agent.sh --help" ]] && found=true
    done

    if [[ "$found" == true ]]; then
      pass "$mode --help: routes to start_agent.sh --help without requiring base args"
    else
      fail "$mode --help: expected exec bash start_agent.sh --help, got: ${CAPTURED[*]}"
    fi
  done
}

test_help_start_subcommand() {
  setup
  dispatch_and_capture help start

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec bash"*"start_agent.sh"* ]] && [[ "$c" == *"--help"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "help start: execs start_agent.sh --help"
  else
    fail "help start: expected exec bash start_agent.sh --help, got: ${CAPTURED[*]}"
  fi
}

# <sub> --help must route to the child's own help for EVERY subcommand, and it
# must do so WITHOUT requiring the subcommand's required args (the latent
# Finding-A bug: required-arg validation used to run before help delegation).
test_help_every_subcommand_no_base_args() {
  # subcommand -> the marker that appears in the captured exec path
  local -A expected=(
    [onboard]="onboard.sh --help"
    [build]="build.sh --help"
    [start]="start_agent.sh --help"
    [dry-run]="start_agent.sh --help"
    [stop]="stop.sh --help"
    [prune]="prune.sh --help"
    [apply]="apply.sh --help"
    [draft]="draft.sh --help"
    [confirm]="confirm.sh --help"
    [reject]="reject.sh --help"
    [package-branch]="package_branch.sh --help"
  )

  for sub in "${!expected[@]}"; do
    setup
    dispatch_and_capture "$sub" --help

    local marker="${expected[$sub]}"
    local found=false
    for c in "${CAPTURED[@]}"; do
      [[ "$c" == "exec bash"*"$marker" ]] && found=true
    done

    if [[ "$found" == true ]]; then
      pass "$sub --help: routes to $marker without requiring base args"
    else
      fail "$sub --help: expected exec bash ... $marker, got: ${CAPTURED[*]}"
    fi
  done
}

# help is itself a subcommand; its --help shows the subcommand list (not a
# routed child script). No recursion.
test_help_flag_shows_list() {
  setup
  local output
  output=$(main help --help 2>&1) || true

  assert_contains "$output" "Valid subcommands" "help --help: shows the subcommand list (help's own page)"
}

# =============================================================================
# Tests  --  apply subcommand (exec's workflows/apply.sh)
# =============================================================================

# A subcommand dispatches to its leaf script with the flags passed through.
# One data-driven test replaces the per-flag copies: <sub>|<args>|<expected
# capture substring>|<label>.
test_workflow_subcommand_dispatch() {
  local row sub args expect label
  local rows=(
    'apply|--project=/tmp/p --sandbox=/tmp/s --diff=/tmp/mydiff.diff|workflows/apply.sh|apply --diff=<path>'
    'apply|--project=/tmp/p --sandbox=/tmp/s --diff=/tmp/mydiff.diff --branch=feature-x|--branch=feature-x|apply --diff --branch'
    'apply|--project=/tmp/p --sandbox=/tmp/s --diff=/tmp/mydiff.diff --force|--force|apply --diff --force'
    'draft|--project=/tmp/p --sandbox=/tmp/s|workflows/draft.sh|draft'
    'draft|--project=/tmp/p --sandbox=/tmp/s --bundle=my-session|--bundle|draft --bundle'
    'draft|--project=/tmp/p --sandbox=/tmp/s --force|--force|draft --force'
    'draft|--project=/tmp/p --sandbox=/tmp/s --permissive|--permissive|draft --permissive'
    'confirm|--project=/tmp/p --sandbox=/tmp/s|workflows/confirm.sh|confirm'
    'confirm|--project=/tmp/p --sandbox=/tmp/s --target=main|--target|confirm --target'
    'reject|--project=/tmp/p --sandbox=/tmp/s|workflows/reject.sh|reject'
    'stop|--name=test --project=/tmp/p --sandbox=/tmp/s|--project=/tmp/p|stop: execs stop.sh with name, sandbox, and project'
    'onboard|--name=test --project=/tmp/p --sandbox=/tmp/s|onboard.sh|onboard'
    'prune|--name=test --project=/tmp/p --sandbox=/tmp/s --stale=sandbox|--stale=sandbox|prune: execs prune.sh with name, project, sandbox, and passthrough flags'
    'package-branch|--sandbox=/tmp/s|package_branch.sh|package-branch: execs package_branch.sh with --sandbox forwarded'
  )
  for row in "${rows[@]}"; do
    IFS='|' read -r sub args expect label <<< "$row"
    setup
    # shellcheck disable=SC2086  # args is a deliberately pre-split flag string
    dispatch_and_capture "$sub" $args

    if captured_has "exec" "$expect"; then
      pass "$label: execs $expect"
    else
      fail "$label: expected $expect, got: ${CAPTURED[*]}"
    fi
  done
}

# =============================================================================
# Tests  --  error handling
# =============================================================================

test_unknown_subcommand() {
  setup
  local output
  output=$(main unknown-command --sandbox=/tmp/s 2>&1) || true

  if [[ "$output" == *"Unknown subcommand"* ]] && [[ "$output" == *"Valid subcommands"* ]]; then
    pass "unknown subcommand: prints error with valid subcommands list"
  else
    fail "unknown subcommand: expected error message, got: $output"
  fi
}

test_missing_subcommand() {
  setup
  local output
  output=$(main 2>&1) || true

  assert_contains "$output" "Usage: agent-sandbox" "missing subcommand: prints usage"
}

test_build_missing_args() {
  setup
  local output
  # Resolve from an empty fixture dir so the CWD .env fallback cannot silently
  # satisfy the identity (the hard-error path must stay honest even if the suite
  # ever runs from a directory that contains a .env).
  output=$( ( cd "$FIXTURE_DIR" && main build ) 2>&1) || true

  # After the thin-CLI change: build no longer requires flags up front; the
  # resolver emits a single hard-requirement error (no flag, no AGENT_SANDBOX_*,
  # no .env via --env/CWD) with the onboard hint.
  if [[ "$output" == *"is not set"* ]] || [[ "$output" == *"required"* ]]; then
    pass "build without identity: prints a hard identity-requirement error (thin CLI)"
  else
    fail "build without identity: expected a resolution/required error, got: $output"
  fi
}

# Every make-reachable command's usage() must present the make-style invocation
# alongside the direct CLI form, so a `make <target>` user hitting an error is
# told a make-style remedy, not only an agent-sandbox CLI one (report intent:
# make-vs-cli hint inconsistency; see session 20260919-15 finding).
test_make_form_in_usage_first_help_leaf() {
  # subcommand -> <script>|<make-form needle>
  # The needle pins the make variable name too, where the command has one: a
  # hint naming a variable the target ignores is worse than no hint. `confirm`
  # takes TARGET_BRANCH, not TARGET (TARGET drives the build target).
  local row script needle
  local rows=(
    'build|scripts/build.sh|make build'
    'prune|scripts/prune.sh|make prune'
    'onboard|scripts/onboard.sh|make onboard'
    'apply|scripts/workflows/apply.sh|make apply'
    'draft|scripts/workflows/draft.sh|make draft'
    'confirm|scripts/workflows/confirm.sh|make confirm [TARGET_BRANCH='
    'package-branch|src/libs/package_branch.sh|make package-branch'
  )
  for row in "${rows[@]}"; do
    IFS='|' read -r sub script needle <<< "$row"
    local output
    output=$(bash "$REPO_ROOT/$script" --help 2>&1) || true
    assert_contains "$output" "$needle" "$sub --help: usage shows the make-style invocation"
  done
}

# The same variable rule applies everywhere a make-confirm hint appears -- in
# docs, prompts, and discussion records, not just the help text. A hint that
# names TARGET sends the operator to the build variable the confirm target
# ignores. This guards the whole tree so the drift cannot come back.
test_confirm_hints_never_name_target() {
  local hits
  hits=$(cd "$REPO_ROOT" && grep -rn 'make confirm TARGET=' \
           --include='*.md' --include='*.sh' . 2>/dev/null \
         | grep -v '^./devlog/handovers/' \
         | grep -v '^./tests/test_dispatch.sh' || true)
  if [[ -z "$hits" ]]; then
    pass "no live make-confirm hint names TARGET instead of TARGET_BRANCH"
  else
    fail "make-confirm hint names TARGET (the confirm target ignores it): $hits"
  fi
}

# =============================================================================
# Run
# =============================================================================

source_harness
setup_mocks

run_test test_build_default_all
run_test test_confirm_hints_never_name_target
run_test test_build_resolves_identity_from_env_file
run_test test_build_resolves_identity_from_relative_env
run_test test_build_with_targets
run_test test_build_with_rebuild
run_test test_start_default
run_test test_start_forwards_env_to_leaf
run_test test_resume_sandbox_and_env_forwarded
run_test test_serve_mode
run_test test_removed_serve_subcommand_is_unknown
run_test test_dry_run_mode
run_test test_start_with_passthrough
run_test test_start_passthrough_order_and_unknown_forms
run_test test_start_rebuild_passthrough
run_test test_start_refresh_passthrough
run_test test_workflow_subcommand_dispatch
run_test test_help_no_args
run_test test_help_leaf_subcommands
run_test test_help_unknown
run_test test_help_flag_routes_run_modes_to_start_agent
run_test test_help_start_subcommand
run_test test_help_every_subcommand_no_base_args
run_test test_help_flag_shows_list
run_test test_unknown_subcommand
run_test test_missing_subcommand
run_test test_build_missing_args
run_test test_make_form_in_usage_first_help_leaf

# Cleanup
rm -rf "$MOCK_SCRIPTS_DIR"

echo ""
echo "${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
[[ "$FAIL" -eq 0 ]]

