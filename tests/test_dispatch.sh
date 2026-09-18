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
  AGENT_SANDBOX_REPO="$REPO_ROOT"

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

  if [[ "$output" == *"Valid subcommands"* ]]; then
    pass "help (no args): prints subcommand list"
  else
    fail "help (no args): expected subcommand list, got: $output"
  fi
}

test_help_apply() {
  setup
  dispatch_and_capture help apply

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"apply.sh"* ]] && [[ "$c" == *"--help"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "help apply: execs apply.sh --help"
  else
    fail "help apply: expected exec apply.sh --help, got: ${CAPTURED[*]}"
  fi
}

test_help_draft() {
  setup
  dispatch_and_capture help draft

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"draft.sh"* ]] && [[ "$c" == *"--help"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "help draft: execs draft.sh --help"
  else
    fail "help draft: expected exec draft.sh --help, got: ${CAPTURED[*]}"
  fi
}

test_help_build() {
  setup
  dispatch_and_capture help build

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"build.sh"* ]] && [[ "$c" == *"--help"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "help build: execs build.sh --help"
  else
    fail "help build: expected exec build.sh --help, got: ${CAPTURED[*]}"
  fi
}

test_help_unknown() {
  setup
  local output
  output=$(main help nonexistent 2>&1) || true

  if [[ "$output" == *"Unknown subcommand"* ]]; then
    pass "help nonexistent: prints error"
  else
    fail "help nonexistent: expected error, got: $output"
  fi
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

  if [[ "$output" == *"Valid subcommands"* ]]; then
    pass "help --help: shows the subcommand list (help's own page)"
  else
    fail "help --help: expected subcommand list, got: $output"
  fi
}

# =============================================================================
# Tests  --  apply subcommand (exec's workflows/apply.sh)
# =============================================================================

test_apply_with_diff() {
  setup
  dispatch_and_capture apply --project=/tmp/p --sandbox=/tmp/s --diff=/tmp/mydiff.diff

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/apply.sh"* ]] && [[ "$c" == *"--diff"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "apply --diff=<path>: execs apply.sh with --diff flag"
  else
    fail "apply --diff=<path>: expected exec apply.sh, got: ${CAPTURED[*]}"
  fi
}

test_apply_with_branch() {
  setup
  dispatch_and_capture apply --project=/tmp/p --sandbox=/tmp/s --diff=/tmp/mydiff.diff --branch=feature-x

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/apply.sh"* ]] && [[ "$c" == *"--branch=feature-x"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "apply --diff --branch: passes --branch flag through"
  else
    fail "apply --diff --branch: expected --branch in exec, got: ${CAPTURED[*]}"
  fi
}

test_apply_with_force() {
  setup
  dispatch_and_capture apply --project=/tmp/p --sandbox=/tmp/s --diff=/tmp/mydiff.diff --force

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/apply.sh"* ]] && [[ "$c" == *"--force"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "apply --diff --force: passes --force flag through"
  else
    fail "apply --diff --force: expected --force in exec, got: ${CAPTURED[*]}"
  fi
}

# =============================================================================
# Tests  --  draft subcommand (exec's workflows/draft.sh)
# =============================================================================

test_draft_noninteractive() {
  setup
  # Non-interactive draft resolves via router  --  will fail without session dirs.
  # We just verify it execs draft.sh rather than exploding.
  dispatch_and_capture draft --project=/tmp/p --sandbox=/tmp/s

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/draft.sh"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "draft: execs draft.sh"
  else
    fail "draft: expected exec draft.sh, got: ${CAPTURED[*]}"
  fi
}

test_draft_with_bundle() {
  setup
  dispatch_and_capture draft --project=/tmp/p --sandbox=/tmp/s --bundle=my-session

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/draft.sh"* ]] && [[ "$c" == *"--bundle"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "draft --bundle: passes --bundle flag through"
  else
    fail "draft --bundle: expected --bundle in exec, got: ${CAPTURED[*]}"
  fi
}

test_draft_with_force() {
  setup
  dispatch_and_capture draft --project=/tmp/p --sandbox=/tmp/s --force

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/draft.sh"* ]] && [[ "$c" == *"--force"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "draft --force: passes --force flag through"
  else
    fail "draft --force: expected --force in exec, got: ${CAPTURED[*]}"
  fi
}

test_draft_with_permissive() {
  setup
  dispatch_and_capture draft --project=/tmp/p --sandbox=/tmp/s --permissive

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/draft.sh"* ]] && [[ "$c" == *"--permissive"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "draft --permissive: passes --permissive flag through"
  else
    fail "draft --permissive: expected --permissive in exec, got: ${CAPTURED[*]}"
  fi
}

# =============================================================================
# Tests  --  confirm / reject (exec's workflows/confirm.sh, workflows/reject.sh)
# =============================================================================

test_confirm_default() {
  setup
  dispatch_and_capture confirm --project=/tmp/p --sandbox=/tmp/s

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/confirm.sh"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "confirm: execs confirm.sh"
  else
    fail "confirm: expected exec confirm.sh, got: ${CAPTURED[*]}"
  fi
}

test_confirm_with_target() {
  setup
  dispatch_and_capture confirm --project=/tmp/p --sandbox=/tmp/s --target=main

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/confirm.sh"* ]] && [[ "$c" == *"--target"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "confirm --target: passes --target flag through"
  else
    fail "confirm --target: expected --target in exec, got: ${CAPTURED[*]}"
  fi
}

test_reject_default() {
  setup
  dispatch_and_capture reject --project=/tmp/p --sandbox=/tmp/s

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"workflows/reject.sh"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "reject: execs reject.sh"
  else
    fail "reject: expected exec reject.sh, got: ${CAPTURED[*]}"
  fi
}

# =============================================================================
# Tests  --  stop / onboard / package-* (exec'd scripts)
# =============================================================================

test_stop() {
  setup
  dispatch_and_capture stop --name=test --project=/tmp/p --sandbox=/tmp/s

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"stop.sh"* ]] && [[ "$c" == *"--name=test"* ]] \
      && [[ "$c" == *"--sandbox=/tmp/s"* ]] && [[ "$c" == *"--project=/tmp/p"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "stop: execs stop.sh with name, sandbox, and project"
  else
    fail "stop: expected exec stop.sh, got: ${CAPTURED[*]}"
  fi
}

test_onboard() {
  setup
  dispatch_and_capture onboard --name=test --project=/tmp/p --sandbox=/tmp/s

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"onboard.sh"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "onboard: execs onboard.sh"
  else
    fail "onboard: expected exec onboard.sh, got: ${CAPTURED[*]}"
  fi
}

test_prune_dispatch() {
  setup
  dispatch_and_capture prune --name=test --project=/tmp/p --sandbox=/tmp/s --stale=sandbox

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"prune.sh"* ]] && [[ "$c" == *"--name=test"* ]] \
      && [[ "$c" == *"--sandbox=/tmp/s"* ]] && [[ "$c" == *"--project=/tmp/p"* ]] \
      && [[ "$c" == *"--stale=sandbox"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "prune: execs prune.sh with name, project, sandbox, and passthrough flags"
  else
    fail "prune: expected exec prune.sh, got: ${CAPTURED[*]}"
  fi
}

test_package_branch() {
  setup
  dispatch_and_capture package-branch --sandbox=/tmp/s

  local found=false
  for c in "${CAPTURED[@]}"; do
    [[ "$c" == "exec"*"package_branch.sh"* ]] \
      && [[ "$c" == *"--sandbox=/tmp/s"* ]] && found=true
  done

  if [[ "$found" == true ]]; then
    pass "package-branch: execs package_branch.sh with --sandbox forwarded"
  else
    fail "package-branch: expected exec package_branch.sh with --sandbox, got: ${CAPTURED[*]}"
  fi
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

  if [[ "$output" == *"Usage: agent-sandbox"* ]]; then
    pass "missing subcommand: prints usage"
  else
    fail "missing subcommand: expected usage, got: $output"
  fi
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

# =============================================================================
# Run
# =============================================================================

source_harness
setup_mocks

run_test test_build_default_all
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
run_test test_start_rebuild_passthrough
run_test test_start_refresh_passthrough
run_test test_apply_with_diff
run_test test_apply_with_branch
run_test test_apply_with_force
run_test test_draft_noninteractive
run_test test_draft_with_bundle
run_test test_draft_with_force
run_test test_draft_with_permissive
run_test test_confirm_default
run_test test_confirm_with_target
run_test test_reject_default
run_test test_stop
run_test test_prune_dispatch
run_test test_onboard
run_test test_package_branch
run_test test_help_no_args
run_test test_help_apply
run_test test_help_draft
run_test test_help_build
run_test test_help_unknown
run_test test_help_flag_routes_run_modes_to_start_agent
run_test test_help_start_subcommand
run_test test_help_every_subcommand_no_base_args
run_test test_help_flag_shows_list
run_test test_unknown_subcommand
run_test test_missing_subcommand
run_test test_build_missing_args

# Cleanup
rm -rf "$MOCK_SCRIPTS_DIR"

echo ""
echo "${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
[[ "$FAIL" -eq 0 ]]
