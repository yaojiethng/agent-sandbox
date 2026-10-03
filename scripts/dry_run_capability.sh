#!/usr/bin/env bash
# dry_run_capability.sh
# Bearer self-check run inside the sandbox (capability layer) container during a dry-run.
# Bind-mounted at /dry_run_capability.sh via the dry-run compose overlay.
#
# Responsibility (bearer): assert the capability container is complete/ready per
# the readiness model (design devlog/discussions/20260828-design-settled-dry_run_phase_split.md),
# then write a per-container diagnostics record to the output mount for
# orchestration to validate (correct-container check). Checks are listed in
# readiness-layer order: docker_image -> workspace_mounts -> session_state ->
# session_data -> container_network -> agent_runtime. A closing sandbox_init
# section reports seed diagnostics; it is not a readiness layer. Checks the
# container preflight guarantees on every start (baked-lib presence, mount
# presence, SESSION_STATE presence) are NOT re-asserted here -- this probe owns
# the readiness DEPTH (session_state validity, session_data data plane,
# container_network cross-component) plus the workspace_mounts ro/rw semantics the
# container preflight deliberately leaves out.
#
# Exit codes:
#   0  --  all CRITICAL checks passed (warnings may exist)
#   1  --  one or more CRITICAL checks failed

# Intentionally no set -e: all checks must run even when some fail.
# Intentionally no set -u: env vars are checked explicitly with guards.
set -o pipefail

# The two probes share one preamble: each locates the harness by its
# conventional lib path, then dry_run_bootstrap resolves the paths the compose
# template passes as absolute env vars, falling back to dirs.sh when a probe
# runs without them.
LIBS_DIR="${LIBS_DIR:-/opt/sandbox/lib}"
# shellcheck source=/dev/null
source "$LIBS_DIR/dry_run_harness.sh"
dry_run_bootstrap
# shellcheck source=/dev/null
source "$LIBS_DIR/diff_export.sh"
# shellcheck source=/dev/null
source "$LIBS_DIR/routing.sh"

# ---------------------------------------------------------------------------
# docker_image - image
# ---------------------------------------------------------------------------
# Deliberately omitted: baked-library/image-file presence is guaranteed by the
# container preflight on every start (dedup). L1 readiness here is implicit in
# this probe successfully sourcing the container libs above.

# ---------------------------------------------------------------------------
# workspace_mounts - link-up (workspace channels, ro/rw semantics)
# ---------------------------------------------------------------------------

section "workspace_mounts link-up"
# Readability is an access check, not an existence check: a mode-000 input
# directory is present but unusable. The input mount is read-only, so the probe
# asserts that half of the ro/rw contract too.
_dir_readable() { [[ -d "$1" && -r "$1" ]]; }
warn_check "INPUT_DIR readable" _dir_readable "$INPUT_DIR"
warn_check "INPUT_DIR is read-only" _is_readonly "$INPUT_DIR"
warn_check "OUTPUT_DIR writable" _is_writable "$OUTPUT_DIR"

# ---------------------------------------------------------------------------
# session_state - state/identity (validity depth; presence is CP-owned)
# ---------------------------------------------------------------------------

section "session_state identity"
critical "SESSION_STATE.init_sha is a valid commit" init_sha_is_valid "$SANDBOX_DIR"

# ---------------------------------------------------------------------------
# session_data - data plane
# ---------------------------------------------------------------------------

section "session_data data plane"
# Verify the diff pipeline can be invoked without error.
# Uses a temp directory so no artifacts pollute the session.
# A failed precondition ends this subsection; the probe still writes the
# record below, so the failure is reported rather than masked by a downstream
# error against an empty directory.
run_diff_export_check() {
  local _diff_test_dir
  _diff_test_dir=$(mktemp -d 2>/dev/null) || {
    _fail "diff_export: could not create temp directory"
    return 0
  }
  if diff_export "$SANDBOX_DIR" "$_diff_test_dir" 2>/dev/null; then
    _pass "diff_export: completed without error"
    local _diff_files
    _diff_files=$(find "$_diff_test_dir" -name "*.diff" -type f 2>/dev/null | wc -l)
    if [[ "$_diff_files" -gt 0 ]]; then
      _pass "diff_export: produced $_diff_files diff file(s)"
    else
      _warn "diff_export: no .diff files produced (baseline may be empty)"
    fi
  else
    _fail "diff_export: command failed"
  fi

  warn_check "diff_export: .export-status exists after successful export" \
    test -f "$_diff_test_dir/.export-status"
  warn_check "diff_export: .export-status reports SUCCESS" \
    export_status_is_success "$_diff_test_dir"
  rm -rf "$_diff_test_dir"
}
run_diff_export_check

# export_path is called in this shell, not through bash -c: a child bash
# inherits no function definitions, so the previous form could never pass in
# production.
_export_path_resolves() {
  local p
  p=$(export_path "$CHANGES_DIR" session "${SESSION_ID:-}" 2>/dev/null)
  [[ -n "$p" ]]
}

section "session_data autosave"
warn_check "CHANGES_DIR/autosave/ exists" test -d "${CHANGES_DIR}/autosave"
warn_check "export_path: resolves with available env vars" _export_path_resolves
warn_check "wait_git_lockfile: returns 0 when no lockfile present" \
  wait_git_lockfile "$SANDBOX_DIR"

# Session-export decision: the exit-time durable record must not be suppressed
# by an autosave that already captured the state. Build an isolated fixture so
# the decision runs against real git state; the live CHANGES_DIR is never
# touched. The fixture seeds a branch point, makes a committed and an
# uncommitted change, and leaves a current autosave dir in place, then asserts
# the session export still runs. A failed fixture precondition ends the
# subsection and still writes the record.
section "session_data session-export decision"
run_session_export_decision() {
  local _fixture_dir
  _fixture_dir=$(mktemp -d 2>/dev/null) || {
    _fail "session-export: could not create fixture directory"
    return 0
  }
  local _fx="$_fixture_dir/sandbox"
  mkdir -p "$_fx"
  if git -C "$_fx" init -q 2>/dev/null; then
    git -C "$_fx" config user.email dryrun@agent-sandbox 2>/dev/null
    git -C "$_fx" config user.name dryrun 2>/dev/null
    echo base > "$_fx/base.txt"
    git -C "$_fx" add -A 2>/dev/null && git -C "$_fx" commit -qm base 2>/dev/null
    local _init
    _init=$(git -C "$_fx" rev-parse HEAD 2>/dev/null)
    session_state_write_set "$_fx" "$_init"
    # real work: one committed change, one uncommitted change
    echo c2 >> "$_fx/base.txt"
    git -C "$_fx" add -A 2>/dev/null && git -C "$_fx" commit -qm c2 2>/dev/null
    echo dirty >> "$_fx/base.txt"
    # a current autosave dir that already carries the state
    mkdir -p "$_fixture_dir/changes/autosave/s-x"
    echo base > "$_fixture_dir/changes/autosave/s-x/change.diff"
    local _fx_rc=0
    session_export_needed "$_fx" || _fx_rc=$?
    if [[ "$_fx_rc" -eq 0 ]]; then
      _pass "session-export: runs when work exists relative to the branch point (committed + uncommitted, autosave present)"
    else
      _fail "session-export: suppressed despite real work (rc=$_fx_rc)"
    fi
    # inverse: a clean tree at the branch point must skip
    local _fx2="$_fixture_dir/clean"
    mkdir -p "$_fx2"
    git -C "$_fx2" init -q 2>/dev/null
    git -C "$_fx2" config user.email dryrun@agent-sandbox 2>/dev/null
    git -C "$_fx2" config user.name dryrun 2>/dev/null
    echo base > "$_fx2/base.txt"
    git -C "$_fx2" add -A 2>/dev/null && git -C "$_fx2" commit -qm base 2>/dev/null
    local _init2
    _init2=$(git -C "$_fx2" rev-parse HEAD 2>/dev/null)
    session_state_write_set "$_fx2" "$_init2"
    _fx_rc=0
    session_export_needed "$_fx2" || _fx_rc=$?
    if [[ "$_fx_rc" -eq 1 ]]; then
      _pass "session-export: skips a clean tree at the branch point"
    else
      _fail "session-export: should skip a clean tree at the branch point (rc=$_fx_rc)"
    fi
  else
    _fail "session-export: could not init fixture repository"
  fi
  rm -rf "$_fixture_dir"
}
run_session_export_decision

# ---------------------------------------------------------------------------
# container_network - cross-component (capability half of the marker round-trip)
# ---------------------------------------------------------------------------

section "container_network cross-component"
# Write a capability-layer marker to CHANGES_DIR. The reasoning layer
# (dry_run_reasoning.sh) reads this to verify cross-container communication.
_cap_marker="$CHANGES_DIR/.dryrun_capability_marker"
if mkdir -p "$CHANGES_DIR" 2>/dev/null && echo "CAPABILITY_LAYER_OK" > "$_cap_marker" 2>/dev/null; then
  _readback=$(cat "$_cap_marker" 2>/dev/null) || _readback=""
  if [[ "$_readback" == "CAPABILITY_LAYER_OK" ]]; then
    _pass "capability layer marker: wrote and read back at $CHANGES_DIR"
  else
    _fail "capability layer marker: file empty or unreadable"
    rm -f "$_cap_marker"
  fi
else
  _fail "capability layer marker: could not write to $CHANGES_DIR"
fi

# ---------------------------------------------------------------------------
# agent_runtime - process (terminal/liveness live on the reasoning side)
# ---------------------------------------------------------------------------
# Capability-side runtime concerns (TTY/stdin, liveness write) live on the
# reasoning container; nothing capability-specific to assert here.

# ---------------------------------------------------------------------------
# sandbox_init - initialized project metrics (seed pipeline result)
# ---------------------------------------------------------------------------
# Reports what the seed + init actually produced: where the project landed,
# how many files, and the total content size. Read-only metrics -- a missing
# sandbox is a critical failure surfaced by the session_state checks above,
# so this section never fails on its own.
section "sandbox_init diagnostics"
SANDBOX_INIT_PATH=""
SANDBOX_INIT_FILES=0
SANDBOX_INIT_BYTES=0
if [[ -d "$SANDBOX_DIR/.git" ]]; then
  SANDBOX_INIT_PATH="$SANDBOX_DIR"
  SANDBOX_INIT_FILES=$(find "$SANDBOX_DIR" -path "$SANDBOX_DIR/.git" -prune -o -type f -print 2>/dev/null | wc -l)
  SANDBOX_INIT_BYTES=$(du -sb --exclude=".git" "$SANDBOX_DIR" 2>/dev/null | cut -f1)
  [[ "$SANDBOX_INIT_BYTES" =~ ^[0-9]+$ ]] || SANDBOX_INIT_BYTES=0
  _pass "project initialized at $SANDBOX_INIT_PATH ($SANDBOX_INIT_FILES files, $SANDBOX_INIT_BYTES bytes)"
else
  _fail "sandbox not initialized: no .git at $SANDBOX_DIR"
fi

# ---------------------------------------------------------------------------
# Summary + diagnostics record
# ---------------------------------------------------------------------------

dry_run_write_record "${OUTPUT_DIR}/dryrun.capability.record" \
  "docker_image workspace_mounts session_state session_data container_network agent_runtime sandbox_init" \
  "sandbox_init.path=${SANDBOX_INIT_PATH:-}" \
  "sandbox_init.files=${SANDBOX_INIT_FILES:-}" \
  "sandbox_init.bytes=${SANDBOX_INIT_BYTES:-}"
# A missing record makes orchestration wait out its timeout and then report a
# timeout, which hides the real cause. It is a critical failure here instead.
if [[ ! -f "${OUTPUT_DIR}/dryrun.capability.record" ]]; then
  _fail "diagnostics record not written to ${OUTPUT_DIR}"
fi
dry_run_summary

[[ $CRITICAL_FAILS -eq 0 ]]