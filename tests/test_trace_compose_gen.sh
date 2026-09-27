#!/usr/bin/env bash
# tests/test_trace_compose_gen.sh
# Trace test: compose_generate output must not contain injected name: lines.
# Pins cite: roadmap "CLI surface" (l.94); code-owner: src/build/compose.sh
#             compose_generate (template + substitutions only).

# Verifies the compose project name leak fix.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

STUB_DIR="$TEST_DIR/../tests/stubs"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

setup_fixture() {
  local FIXTURE_DIR="$1"
  export PROJECT_NAME="test-project"
  export PROVIDER_NAME="pi"
  export SANDBOX_DIR="$FIXTURE_DIR/sandbox"
  export WORKTREE_DIR="$SANDBOX_DIR/.worktree"
  export CHANGES_DIR="$SANDBOX_DIR/.workspace/session-diffs"
  export INPUT_DIR="$SANDBOX_DIR/.workspace/input"
  export OUTPUT_DIR="$SANDBOX_DIR/.workspace/output"
  export HOST_UID="1000"
  export HOST_GID="1000"
  export SESSION_TS="20260730-000000"
  export HOST_HEAD_SHA="abc123def456"
  export SESSION_ID="test01"
  export SANITIZED_HOST_BRANCH="master"
  export SANDBOX_IMAGE_NAME="agent-sandbox-sandbox:test-project"
  export AGENT_IMAGE_NAME="agent-sandbox-pi:test-project"
  export SANDBOX_CONTAINER_NAME="sandbox-test-project-${SESSION_ID}"
  export AGENT_CONTAINER_NAME="pi-test-project-${SESSION_ID}"
  export DOCKER_TRACE_LOG="$FIXTURE_DIR/docker-trace.log"

  mkdir -p "$SANDBOX_DIR" "$CHANGES_DIR" "$INPUT_DIR" "$OUTPUT_DIR" "$SANDBOX_DIR/.pi"

  :> "$DOCKER_TRACE_LOG"
}

# Source compose.sh functions and run compose_generate against the stub
run_compose_generate() {
  local output_file="$1"
  local delivery="${2:-copy}"
  (
    source "$REPO_ROOT/src/build/image.sh"
    source "$REPO_ROOT/scripts/build.sh"
    source "$REPO_ROOT/src/build/compose.sh"
    export PATH="$STUB_DIR:$PATH"

    local compose_files=("$REPO_ROOT/src/build/docker-compose.yml")
    if [[ "$delivery" == "copy" ]]; then
      compose_files+=("$REPO_ROOT/src/build/docker-compose.copy.yml")
    else
      compose_files+=("$REPO_ROOT/src/build/docker-compose.mount.yml")
    fi
    local provider_overlay="$REPO_ROOT/src/reasoning/providers/pi/docker-compose.pi.yml"
    [[ -f "$provider_overlay" ]] && compose_files+=("$provider_overlay")

    compose_generate "$output_file" "$PROJECT_NAME" "$PROVIDER_NAME" "${compose_files[@]}"
  ) > /dev/null 2>&1 || true
}

# run_compose_generate_with_docker OUTPUT [INPUT...]
#   Sources the build libs and runs compose_generate in a subshell. The caller
#   defines a `docker` shell function before calling; the subshell inherits it
#   and it shadows the PATH stub. Returns compose_generate's status.
run_compose_generate_with_docker() {
  local out="$1"; shift
  (
    source "$REPO_ROOT/src/build/image.sh"
    source "$REPO_ROOT/scripts/build.sh"
    source "$REPO_ROOT/src/build/compose.sh"
    compose_generate "$out" "$PROJECT_NAME" "$PROVIDER_NAME" "$@"
  )
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

# Given: a docker double whose compose config emits a top-level name: line, as real Compose does
# When:  compose_generate runs
# Then:  the injected name: line is absent from the generated file
# Asserts: the strip of the name: line Compose injects from the staging directory
test_no_name_lines_in_output() {
  local FIXTURE_DIR="$FIXTURE_DIR/nonames"
  mkdir -p "$FIXTURE_DIR"
  setup_fixture "$FIXTURE_DIR"

  local out="$FIXTURE_DIR/compose-output.yml"
  docker() {
    if [[ "${1:-}" == "compose" ]]; then
      local prev="" a
      for a in "$@"; do
        [[ "$prev" == "-f" ]] && { cat "$a"; break; }
        prev="$a"
      done
      echo "name: injected-by-compose"
    elif [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
      echo "sha256:stub"
    fi
  }
  run_compose_generate_with_docker "$out" \
    "$REPO_ROOT/src/build/docker-compose.yml" \
    "$REPO_ROOT/src/build/docker-compose.copy.yml"

  if [[ ! -f "$out" ]]; then
    fail "compose_generate did not produce output file"
    return
  fi

  local name_lines
  name_lines=$(grep -c '^name:' "$out" 2>/dev/null) || name_lines=0

  if [[ "$name_lines" -eq 0 ]]; then
    pass "generated compose file has no top-level 'name:' key (template + substitutions only)"
  else
    fail "generated compose file has $name_lines top-level 'name:' line(s) (expected 0)"
    grep '^name:' "$out" >&2
  fi
}

# Given: the real file set and the docker stub
# When:  compose_generate runs
# Then:  the output still carries services: and x-session-labels:
# Asserts: the substitutions plus the stub's first-file echo keep the template shape
test_output_is_valid_yaml() {
  local FIXTURE_DIR="$FIXTURE_DIR/validyaml"
  mkdir -p "$FIXTURE_DIR"
  setup_fixture "$FIXTURE_DIR"

  local out="$FIXTURE_DIR/compose-output.yml"
  run_compose_generate "$out"

  if [[ ! -f "$out" ]]; then
    fail "compose_generate did not produce output file"
    return
  fi

  # Check that key sections are present. The stub's compose config returns
  # the first input file (the base template), so the named sandbox volume
  # (declared in the copy overlay) is not part of the stub-merged output  -- 
  # the volumes section is asserted statically against the overlay files.
  if grep -q 'services:' "$out" && grep -q 'x-session-labels:' "$out"; then
    pass "generated compose file contains services and session-labels sections"
  else
    fail "generated compose file missing expected sections"
  fi
}

# Given: a staged copy of the base template and the docker stub
# When:  docker compose config runs with --no-interpolate
# Then:  rc is 0 and the output carries no name: line, including no false match on container_name:
# Asserts: the double's output shape that the surrounding units rely on
test_stub_docker_config_preserves_structure() {
  local FIXTURE_DIR="$FIXTURE_DIR/configstruct"
  mkdir -p "$FIXTURE_DIR"
  setup_fixture "$FIXTURE_DIR"

  # Verify the stub's compose config output doesn't have name: lines either
  # (the stub returns the first input file, which shouldn't have name: lines)
  local staging_dir
  staging_dir=$(get_fixture_dir)
  cp "$REPO_ROOT/src/build/docker-compose.yml" "$staging_dir/00-test.yml"

  # A failed compose config is a failure, not an empty-output blessing: the
  # rc is asserted before the grep, or an empty out would satisfy name_lines=0.
  local out RC=0
  out=$(PATH="$STUB_DIR:$PATH" docker compose -f "$staging_dir/00-test.yml" config --no-interpolate 2>&1) || RC=$?
  assert_rc 0 "$RC" "stub docker compose config succeeds"

  # Stub returns the file directly; source templates have no name: lines
  # But container_name: has "name:" as a substring  --  confirm grep doesn't match it
  local name_lines
  name_lines=$(echo "$out" | grep -c '^[[:space:]]*name:') || name_lines=0

  assert_eq_num "$name_lines" "0" "stub compose config output has no 'name:' lines"
}

# ---------------------------------------------------------------------------
# Delivery overlay file-set tests
# ---------------------------------------------------------------------------

# The base template must not carry copy-only wiring: the named sandbox volume
# lives in the copy overlay so bind-mount compose never inherits it.
# Given: the base template src/build/docker-compose.yml
# When:  it is grepped for SNAPSHOT_DIR, sandbox-data, and the snapshot path
# Then:  none is present
# Asserts: the base template carries no copy-only wiring (the named volume lives in the copy overlay)
test_base_template_has_no_copy_only_wiring() {
  local base="$REPO_ROOT/src/build/docker-compose.yml"
  local copy_only=0
  grep -q 'SNAPSHOT_DIR' "$base" && copy_only=1
  grep -q 'sandbox-data' "$base" && copy_only=1
  grep -q '/home/agentuser/.snapshot' "$base" && copy_only=1

  assert_eq_num "$copy_only" "0" "base template free of copy-only wiring (SNAPSHOT_DIR, named sandbox volume)"
}

# The copy overlay carries the named volume and copy delivery type, and no
# snapshot mount (content is host-side seeded by the helper-container seeder).
# Given: the copy overlay docker-compose.copy.yml
# When:  it is grepped for its delivery markers
# Then:  sandbox-data, SANDBOX_TYPE=copy and {{FLATTEN}} are present, and the snapshot mount is absent
# Asserts: the copy overlay owns the named volume and the copy delivery type
test_copy_overlay_carries_volume_no_snapshot_mount() {
  local overlay="$REPO_ROOT/src/build/docker-compose.copy.yml"

  if grep -q 'sandbox-data' "$overlay" \
      && grep -q 'SANDBOX_TYPE=copy' "$overlay" \
      && grep -q '{{FLATTEN}}' "$overlay" \
      && ! grep -q 'SNAPSHOT_DIR' "$overlay" \
      && ! grep -q '/home/agentuser/.snapshot' "$overlay"; then
    pass "copy overlay carries named volume + SANDBOX_TYPE=copy + FLATTEN, no snapshot mount"
  else
    fail "copy overlay missing volume wiring, carries stale snapshot mount, or missing SANDBOX_TYPE=copy/FLATTEN"
  fi
}

# The mount overlay carries the worktree bind mount and no copy wiring.
# Given: the mount overlay docker-compose.mount.yml
# When:  it is grepped for its delivery markers
# Then:  WORKTREE_DIR, the container sandbox path, SANDBOX_TYPE=mount and {{FLATTEN}} are present, and copy wiring is absent
# Asserts: the mount overlay owns the worktree bind mount and nothing copy-specific
test_mount_overlay_carries_worktree_not_copy_wiring() {
  local overlay="$REPO_ROOT/src/build/docker-compose.mount.yml"
  local copy_only=0
  if ! grep -q 'WORKTREE_DIR' "$overlay" || ! grep -q '/home/agentuser/sandbox' "$overlay"; then
    copy_only=1
  fi
  grep -q 'SNAPSHOT_DIR' "$overlay" && copy_only=1
  grep -q 'sandbox-data' "$overlay" && copy_only=1
  grep -q 'SANDBOX_TYPE=mount' "$overlay" || copy_only=1
  grep -q '{{FLATTEN}}' "$overlay" || copy_only=1

  assert_eq_num "$copy_only" "0" "mount overlay carries worktree mount + SANDBOX_TYPE=mount + FLATTEN only"
}

# The stub's compose config cats only the first staged input, so delivery
# overlay content never reaches the merged output under the stub. To assert
# the FLATTEN stamping contract (the literal resume consumes), feed a mini
# overlay as the FIRST input: compose_generate's sed substitutes {{FLATTEN}}
# into every staged file, and the stub then cats the substituted first file.
# Given: a mini overlay carrying FLATTEN={{FLATTEN}} as the first input, run once with FLATTEN=true and once with false
# When:  compose_generate runs for each
# Then:  each output carries its own stamped literal and no placeholder remains
# Asserts: the sed stamp for the literal the resume path consumes
test_compose_generate_stamps_flatten_literal() {
  local FIXTURE_DIR="$FIXTURE_DIR/flattenstamp"
  mkdir -p "$FIXTURE_DIR"
  setup_fixture "$FIXTURE_DIR"

  cat > "$FIXTURE_DIR/mini.yml" <<'EOF'
services:
  sandbox:
    image: mini
    environment:
      - SANDBOX_TYPE=copy
      - FLATTEN={{FLATTEN}}
EOF

  local out_true="$FIXTURE_DIR/out-true.yml"
  local out_false="$FIXTURE_DIR/out-false.yml"
  (
    source "$REPO_ROOT/src/build/image.sh"
    source "$REPO_ROOT/scripts/build.sh"
    source "$REPO_ROOT/src/build/compose.sh"
    export PATH="$STUB_DIR:$PATH"
    export FLATTEN=true
    compose_generate "$out_true" "$PROJECT_NAME" "$PROVIDER_NAME" "$FIXTURE_DIR/mini.yml"
    export FLATTEN=false
    compose_generate "$out_false" "$PROJECT_NAME" "$PROVIDER_NAME" "$FIXTURE_DIR/mini.yml"
  ) > /dev/null 2>&1 || true

  if [[ -f "$out_true" ]] && grep -q 'FLATTEN=true' "$out_true" && ! grep -q '{{FLATTEN}}' "$out_true"; then
    pass "flatten stamp: FLATTEN=true stamped into generated compose, no placeholder left"
  else
    fail "flatten stamp (true): FLATTEN=true missing or placeholder left (file=$out_true)"
  fi
  if [[ -f "$out_false" ]] && grep -q 'FLATTEN=false' "$out_false"; then
    pass "flatten stamp: FLATTEN=false stamped for full default"
  else
    fail "flatten stamp (false): FLATTEN=false missing (file=$out_false)"
  fi
}

# The mount-mode merged output (stub-limited) still contains no copy wiring.
# Given: the real file set with the mount overlay
# When:  compose_generate runs
# Then:  the merged output carries no SNAPSHOT_DIR and no sandbox-data
# Asserts: mount mode inherits no copy-only wiring through the merge
test_mount_output_has_no_snapshot_dir() {
  local FIXTURE_DIR="$FIXTURE_DIR/mountoutput"
  mkdir -p "$FIXTURE_DIR"
  setup_fixture "$FIXTURE_DIR"

  local out="$FIXTURE_DIR/compose-mount-output.yml"
  run_compose_generate "$out" mount

  if [[ ! -f "$out" ]]; then
    fail "compose_generate (mount) did not produce output file"
    return
  fi

  local copy_only=0
  grep -q 'SNAPSHOT_DIR' "$out" && copy_only=1
  grep -q 'sandbox-data' "$out" && copy_only=1

  assert_eq_num "$copy_only" "0" "mount-mode merged output free of copy-only wiring"
}

# compose_generate stamps the built images' ID digests into the record's
# `agent-sandbox.agent-image-digest` / `agent-sandbox.sandbox-image-digest`
# labels (read via docker inspect post-build), which the dry-run roundtrip
# gate and resume identity checks consume docker-free.
# Given: a stub digest map carrying a digest for each of the two images
# When:  compose_generate runs
# Then:  both image-digest labels and the interface-contract version are stamped into the record
# Asserts: the roundtrip gate and the resume identity check have a docker-free record source
test_record_bakes_image_digests() {
  local FIXTURE_DIR="$FIXTURE_DIR/imagesig"
  mkdir -p "$FIXTURE_DIR"
  setup_fixture "$FIXTURE_DIR"

  local out="$FIXTURE_DIR/compose-output.yml"
  DOCKER_STUB_IMAGE_DIGESTS="pi-agent-test-project:sha256:agentdigest sandbox-test-project:sha256:sandboxdigest" \
    run_compose_generate "$out"

  if [[ ! -f "$out" ]]; then
    fail "compose_generate (digests) did not produce output file"
    return
  fi
  if grep -q 'agent-sandbox.agent-image-digest: sha256:agentdigest' "$out" \
     && grep -q 'agent-sandbox.sandbox-image-digest: sha256:sandboxdigest' "$out"; then
    pass "compose_generate stamps both image digest labels into the record"
  else
    fail "compose_generate did not stamp image digest labels, got:"
    grep 'image-digest' "$out" >&2 || true
  fi
  if grep -q "agent-sandbox.interface-contract-version: $(interface_contract_version)" "$out"; then
    pass "compose_generate stamps the interface-contract version into the record"
  else
    fail "compose_generate did not stamp the interface-contract version, got:"
    grep 'interface-contract' "$out" >&2 || true
  fi
}

# Given: a docker double whose compose config interpolates ${VAR} unless --no-interpolate is passed
# When:  compose_generate runs on an input carrying ${SERVE_PORT}
# Then:  the output keeps the literal reference for runtime resolution
# Asserts: the flag's property -- generation does not resolve operator-set variables
test_compose_generate_preserves_runtime_var() {
  local FIXTURE_DIR="$FIXTURE_DIR/runtimevar"
  mkdir -p "$FIXTURE_DIR"
  setup_fixture "$FIXTURE_DIR"

  cat > "$FIXTURE_DIR/mini.yml" <<'EOF'
services:
  sandbox:
    image: mini
    environment:
      - SERVE_PORT=${SERVE_PORT}
EOF

  local out="$FIXTURE_DIR/compose-output.yml"
  docker() {
    if [[ "${1:-}" == "compose" ]]; then
      local prev="" a f="" no_interp=0 seen_f=0
      for a in "$@"; do
        [[ "$a" == "--no-interpolate" ]] && no_interp=1
        if [[ "$prev" == "-f" && "$seen_f" -eq 0 ]]; then f="$a"; seen_f=1; fi
        prev="$a"
      done
      if (( no_interp == 1 )); then
        cat "$f"
      else
        sed "s|\${SERVE_PORT}|${SERVE_PORT:-}|g" "$f"
      fi
    elif [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
      echo "sha256:stub"
    fi
  }
  export SERVE_PORT=9999
  run_compose_generate_with_docker "$out" "$FIXTURE_DIR/mini.yml"

  if [[ -f "$out" ]] && grep -q 'SERVE_PORT=${SERVE_PORT}' "$out" && ! grep -q 'SERVE_PORT=9999' "$out"; then
    pass "compose_generate preserves the \${VAR} reference for runtime resolution"
  else
    fail "compose_generate did not preserve the runtime variable; got: $(grep SERVE_PORT "$out" 2>/dev/null)"
  fi
}

# Given: an input set with no input files
# When:  compose_generate runs
# Then:  it returns non-zero and names the required input
test_compose_generate_rejects_no_inputs() {
  local FIXTURE_DIR="$FIXTURE_DIR/cg_noinput"
  mkdir -p "$FIXTURE_DIR"
  setup_fixture "$FIXTURE_DIR"
  local out="$FIXTURE_DIR/out.yml" rc=0
  (
    source "$REPO_ROOT/src/build/image.sh"
    source "$REPO_ROOT/scripts/build.sh"
    source "$REPO_ROOT/src/build/compose.sh"
    compose_generate "$out" "$PROJECT_NAME" "$PROVIDER_NAME"
  ) > "$FIXTURE_DIR/log" 2>&1 || rc=$?
  assert_ne "$rc" "0" "compose_generate rejects an empty input set"
  assert_contains "$(cat "$FIXTURE_DIR/log")" "at least one input file is required" \
    "compose_generate names the required input"
}

# Given: a PATH without a docker command
# When:  compose_generate runs
# Then:  it returns non-zero and names the missing docker dependency
test_compose_generate_rejects_absent_docker() {
  local FIXTURE_DIR="$FIXTURE_DIR/cg_nodocker"
  mkdir -p "$FIXTURE_DIR/minbin"
  setup_fixture "$FIXTURE_DIR"
  ln -s "$(command -v tr)" "$FIXTURE_DIR/minbin/tr"
  ln -s "$(command -v dirname)" "$FIXTURE_DIR/minbin/dirname"
  echo "services: {}" > "$FIXTURE_DIR/mini.yml"
  local out="$FIXTURE_DIR/out.yml" rc=0
  (
    # PATH is intentionally narrowed to a bin without docker; the unit asserts
    # compose_generate refuses to run without the dependency.
    # shellcheck disable=SC2123
    PATH="$FIXTURE_DIR/minbin"
    source "$REPO_ROOT/src/build/image.sh"
    source "$REPO_ROOT/scripts/build.sh"
    source "$REPO_ROOT/src/build/compose.sh"
    compose_generate "$out" "$PROJECT_NAME" "$PROVIDER_NAME" "$FIXTURE_DIR/mini.yml"
  ) > "$FIXTURE_DIR/log" 2>&1 || rc=$?
  assert_ne "$rc" "0" "compose_generate refuses to run without docker"
  assert_contains "$(cat "$FIXTURE_DIR/log")" "docker is required" \
    "compose_generate names the missing docker dependency"
}

# Given: a docker double that reports no digest for the images
# When:  compose_generate runs
# Then:  it returns non-zero and reports the missing digest
# Asserts: the ADR's hard error with no unknown-fallback for image identity
test_compose_generate_rejects_missing_digest() {
  local FIXTURE_DIR="$FIXTURE_DIR/cg_nodigest"
  mkdir -p "$FIXTURE_DIR"
  setup_fixture "$FIXTURE_DIR"
  echo "services: {}" > "$FIXTURE_DIR/mini.yml"
  docker() { return 0; }
  local out="$FIXTURE_DIR/out.yml" rc=0
  run_compose_generate_with_docker "$out" "$FIXTURE_DIR/mini.yml" > "$FIXTURE_DIR/log" 2>&1 || rc=$?
  assert_ne "$rc" "0" "compose_generate refuses an empty image digest"
  assert_contains "$(cat "$FIXTURE_DIR/log")" "image digest unavailable" \
    "compose_generate names the missing image digest"
}

# Given: an input set naming a file that does not exist
# When:  compose_generate runs
# Then:  it returns non-zero, names the missing file, and removes its staging dir
# Asserts: the input-not-found failure return and the staging cleanup it owns
test_compose_generate_rejects_missing_input_file() {
  local FIXTURE_DIR="$FIXTURE_DIR/cg_missinginput"
  mkdir -p "$FIXTURE_DIR/tmp"
  setup_fixture "$FIXTURE_DIR"
  echo "services: {}" > "$FIXTURE_DIR/real.yml"
  docker() {
    if [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
      echo "sha256:stub"
    fi
  }
  local out="$FIXTURE_DIR/out.yml" rc=0
  TMPDIR="$FIXTURE_DIR/tmp" run_compose_generate_with_docker "$out" \
    "$FIXTURE_DIR/real.yml" "$FIXTURE_DIR/absent.yml" > "$FIXTURE_DIR/log" 2>&1 || rc=$?
  assert_ne "$rc" "0" "compose_generate rejects a missing input file"
  assert_contains "$(cat "$FIXTURE_DIR/log")" "input file not found" \
    "compose_generate names the missing input file"
  assert_empty "$(ls -A "$FIXTURE_DIR/tmp")" "compose_generate removes its staging dir on the input-not-found return"
}

# Given: a docker double whose compose config merge fails
# When:  compose_generate runs
# Then:  it returns non-zero and removes its staging dir
# Asserts: the merge failure return propagates under the suite's pipefail and the staging dir does not leak
test_compose_generate_propagates_merge_failure() {
  local FIXTURE_DIR="$FIXTURE_DIR/cg_mergefail"
  mkdir -p "$FIXTURE_DIR/tmp"
  setup_fixture "$FIXTURE_DIR"
  echo "services: {}" > "$FIXTURE_DIR/real.yml"
  docker() {
    if [[ "${1:-}" == "image" ]]; then echo "sha256:stub"; return 0; fi
    if [[ "${1:-}" == "compose" ]]; then return 3; fi
  }
  local out="$FIXTURE_DIR/out.yml" rc=0
  TMPDIR="$FIXTURE_DIR/tmp" run_compose_generate_with_docker "$out" \
    "$FIXTURE_DIR/real.yml" > /dev/null 2>&1 || rc=$?
  assert_ne "$rc" "0" "compose_generate propagates a failed merge"
  assert_empty "$(ls -A "$FIXTURE_DIR/tmp")" "compose_generate removes its staging dir on the merge-failure return"
}

# Given: a successful compose_generate run and a fixture TMPDIR
# When:  compose_generate returns
# Then:  its staging dir is removed
# Asserts: the final staging cleanup runs on the success path
test_compose_generate_cleans_staging_on_success() {
  local FIXTURE_DIR="$FIXTURE_DIR/cg_cleanup"
  mkdir -p "$FIXTURE_DIR/tmp"
  setup_fixture "$FIXTURE_DIR"
  export TMPDIR="$FIXTURE_DIR/tmp"
  run_compose_generate "$FIXTURE_DIR/out.yml"
  assert_empty "$(ls -A "$FIXTURE_DIR/tmp")" "compose_generate removes its staging dir on success"
}

# compose_file_from_args recovers the generated compose file path from
# COMPOSE_ARGS (last -f value), so compose_dry_run can pass the generation-time
# stamp source to the roundtrip gate.
# Given: COMPOSE_ARGS carrying one -f flag
# When:  compose_file_from_args runs
# Then:  it prints that file path
# Asserts: the -f value is recovered
test_compose_file_from_args_extracts_f_value() {
  (
    source "$REPO_ROOT/src/build/compose.sh"
    COMPOSE_ARGS=(--project-name p --project-directory /tmp -f /gen/session.yml)
    [[ "$(compose_file_from_args)" == "/gen/session.yml" ]]
  )
  if [[ $? -eq 0 ]]; then
    pass "compose_file_from_args extracts the -f value"
  else
    fail "compose_file_from_args did not extract the -f value"
  fi
}

# Given: COMPOSE_ARGS carrying two -f flags
# When:  compose_file_from_args runs
# Then:  it prints the last -f value
# Asserts: the generated record is the last file, which the digest roundtrip reads
test_compose_file_from_args_returns_last_f() {
  (
    source "$REPO_ROOT/src/build/compose.sh"
    COMPOSE_ARGS=(--project-name p --project-directory /tmp -f /gen/first.yml -f /gen/last.yml)
    [[ "$(compose_file_from_args)" == "/gen/last.yml" ]]
  )
  if [[ $? -eq 0 ]]; then
    pass "compose_file_from_args returns the last -f value"
  else
    fail "compose_file_from_args did not return the last -f value"
  fi
}

# Given: COMPOSE_ARGS whose final element is a bare -f with no value
# When:  compose_file_from_args runs
# Then:  it returns the earlier -f value without reading past the array
# Asserts: the bounds guard keeps a trailing bare -f from an out-of-range read
test_compose_file_from_args_handles_trailing_bare_f() {
  (
    source "$REPO_ROOT/src/build/compose.sh"
    COMPOSE_ARGS=(--project-name p -f /gen/first.yml -f)
    [[ "$(compose_file_from_args)" == "/gen/first.yml" ]]
  )
  if [[ $? -eq 0 ]]; then
    pass "compose_file_from_args ignores a trailing bare -f"
  else
    fail "compose_file_from_args mishandled a trailing bare -f"
  fi
}

# Given: COMPOSE_ARGS carrying no -f flag
# When:  compose_file_from_args runs
# Then:  it prints nothing and returns 0
# Asserts: an absent -f is an empty answer, not a failure
test_compose_file_from_args_empty_without_f() {
  (
    source "$REPO_ROOT/src/build/compose.sh"
    # COMPOSE_ARGS is read by compose_file_from_args in the sourced
    # compose.sh; ShellCheck cannot trace the cross-source read.
    # shellcheck disable=SC2034
    COMPOSE_ARGS=(--project-name p)
    [[ -z "$(compose_file_from_args)" ]]
  )
  if [[ $? -eq 0 ]]; then
    pass "compose_file_from_args returns empty without -f"
  else
    fail "compose_file_from_args non-empty without -f"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run_test test_no_name_lines_in_output
run_test test_output_is_valid_yaml
run_test test_stub_docker_config_preserves_structure
run_test test_base_template_has_no_copy_only_wiring
run_test test_copy_overlay_carries_volume_no_snapshot_mount
run_test test_mount_overlay_carries_worktree_not_copy_wiring
run_test test_compose_generate_stamps_flatten_literal
run_test test_mount_output_has_no_snapshot_dir
run_test test_record_bakes_image_digests
run_test test_compose_generate_preserves_runtime_var
run_test test_compose_generate_rejects_no_inputs
run_test test_compose_generate_rejects_absent_docker
run_test test_compose_generate_rejects_missing_digest
run_test test_compose_generate_rejects_missing_input_file
run_test test_compose_generate_propagates_merge_failure
run_test test_compose_generate_cleans_staging_on_success
run_test test_compose_file_from_args_extracts_f_value
run_test test_compose_file_from_args_returns_last_f
run_test test_compose_file_from_args_handles_trailing_bare_f
run_test test_compose_file_from_args_empty_without_f
test_done test_trace_compose_gen
