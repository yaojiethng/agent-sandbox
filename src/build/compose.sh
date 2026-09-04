#!/usr/bin/env bash
# libs/compose.sh
#
# Shared Docker Compose primitives for provider run scripts.
# Source this file after containers.sh.
#
# Functions:
#   compose_generate      Merges one or more compose files via
#                         `docker compose config --no-interpolate`, applies
#                         {{VAR}} substitutions, and writes the result to a
#                         caller-supplied output path. Image names and other
#                         harness-derived values are baked in; .env secrets
#                         and path variables are preserved as ${VAR} for
#                         Docker Compose to resolve at runtime.
#
#                         The input file set is assembled by the caller
#                         (run_agent.sh): base template + delivery overlay
#                         (docker-compose.copy.yml / .mount.yml, selected by
#                         SANDBOX_TYPE) + provider overlay (if present) + mode
#                         overlay (dry-run/serve).
#
#   compose_args          Sets COMPOSE_ARGS in the caller's scope from a
#                         single pre-generated compose file and project name.
#
#   compose_dry_run       Full dry-run sequence against COMPOSE_ARGS:
#                         up, exec, down. Overlay already merged  --  no extra
#                         file args needed.
#
#   session_teardown     docker compose down (ends session; preserves named volumes)
#   session_destroy      docker compose down -v (ends session; removes named volumes)
#
#   compose_sandbox_wait  Polls until sandbox container reports healthy.

source "$(dirname "${BASH_SOURCE[0]}")/../libs/dry_run_record.sh"

# -------------------------
# compose_generate
#
# Merges compose files, substitutes {{VAR}} placeholders, preserves ${VAR}
# for Docker Compose runtime resolution. Writes merged output to a file.
#
# Substitutions applied here (baked into generated file):
#   {{PROJECT_NAME}}        -> project name
#   {{PROJECT_DIR}}         -> absolute path to project directory
#   {{REPO_ROOT}}           -> absolute path to the harness repo (bind-mounts
#                              the seeder script + session_state lib at current source)
#   {{SANDBOX_IMAGE_NAME}}  -> derived image name
#   {{AGENT_IMAGE_NAME}}    -> derived image name
#   {{PROVIDER_NAME}}       -> provider name
#   {{SANDBOX_CONTAINER_NAME}}      -> sandbox container name (sandbox-<project>-<session_id>)
#   {{AGENT_CONTAINER_NAME}} -> agent container name (<provider>-<project>-<session_id>)
#   {{SESSION_ID}}          -> session ID (6-char hex, from start_agent.sh)
#   {{SANITIZED_HOST_BRANCH}} -> host branch name, sanitised (replaces former SESSION_NAME)
#   {{DRY_RUN_CAPABILITY_SCRIPT}} -> absolute path to dry_run_capability.sh (dry-run mode only)
#   {{DRY_RUN_SCRIPT}}             -> absolute path to dry_run_reasoning.sh (reasoning layer, dry-run mode only)
#   ${SANDBOX_DIR}          -> host sandbox path (from .env, exported by start_agent.sh)
#   ${WORKTREE_DIR}         -> host worktree path (mount delivery only; default
#                             ${SANDBOX_DIR}/.worktree, set by run_agent.sh)
#   ${CHANGES_DIR}          -> host changes path (from .env, exported by start_agent.sh)
#   ${INPUT_DIR}            -> host input path (from .env, exported by start_agent.sh)
#   ${OUTPUT_DIR}           -> host output path (from .env, exported by start_agent.sh)
#
# Preserved as ${VAR} for Docker Compose runtime resolution (operator-set):
#   ${SERVE_PORT}           -> port for serve mode
#   ${AUTOSAVE_INTERVAL}    -> autosave interval
#   ${OPENCODE_SERVER_PASSWORD} -> OpenCode serve mode credential
#   Any other provider-specific secrets
#
# Args:
#   $1       output_file       --  absolute path to write merged compose file
#   $2       project_name      --  value for {{PROJECT_NAME}}
#   $3       provider_name     --  used to derive {{AGENT_IMAGE_NAME}}
#   $4...$N  input_files       --  compose files to merge, in order
#
# Requires: containers.sh sourced (sandbox_image_name, agent_image_name)
# -------------------------
compose_generate() {
  local output_file="$1"
  local project_name="$2"
  local provider_name="$3"
  shift 3
  local input_files=("$@")

  if [[ ${#input_files[@]} -eq 0 ]]; then
    echo "compose_generate: at least one input file is required" >&2
    return 1
  fi

  # Derive image names  --  baked into generated file.
  local sandbox_image agent_image
  sandbox_image="$(sandbox_image_name "$project_name")"
  agent_image="$(agent_image_name "$provider_name" "$project_name")"

  # Image content identity (image ID digest -- content-addresses config +
  # layers; the only docker-native digest available for locally built,
  # never-pushed images). Read post-build, so the recorded digest is exact
  # for this session. A missing digest is a hard error (ADR
  # harness_versioning.md: no unknown-fallback).
  local agent_image_digest sandbox_image_digest
  if ! command -v docker >/dev/null 2>&1; then
    echo "compose_generate: docker is required to stamp image digests into the record" >&2
    return 1
  fi
  agent_image_digest="$(image_digest "$agent_image")"
  sandbox_image_digest="$(image_digest "$sandbox_image")"
  if [[ -z "$agent_image_digest" || -z "$sandbox_image_digest" ]]; then
    echo "compose_generate: image digest unavailable (agent: ${agent_image_digest:-missing}, sandbox: ${sandbox_image_digest:-missing}) -- build the images first" >&2
    return 1
  fi

  # Apply {{VAR}} substitutions to each input file into a temp staging dir,
  # then run docker compose config --no-interpolate to merge them.
  local staging_dir
  staging_dir="$(mktemp -d)"
  trap 'rm -rf "$staging_dir"' RETURN

  local staged_files=()
  local i=0
  for src in "${input_files[@]}"; do
    if [[ ! -f "$src" ]]; then
      echo "compose_generate: input file not found: $src" >&2
      return 1
    fi
    local dst
    dst="$staging_dir/$(printf '%02d' "$i")-$(basename "$src")"
    sed \
      -e "s|{{PROJECT_NAME}}|${project_name}|g" \
      -e "s|{{PROJECT_DIR}}|${PROJECT_DIR:-}|g" \
      -e "s|{{REPO_ROOT}}|${REPO_ROOT:-}|g" \
      -e "s|{{SANDBOX_IMAGE_NAME}}|${sandbox_image}|g" \
      -e "s|{{AGENT_IMAGE_NAME}}|${agent_image}|g" \
      -e "s|{{PROVIDER_NAME}}|${provider_name}|g" \
      -e "s|{{SANDBOX_CONTAINER_NAME}}|${SANDBOX_CONTAINER_NAME:-}|g" \
      -e "s|{{AGENT_CONTAINER_NAME}}|${AGENT_CONTAINER_NAME:-}|g" \
      -e "s|{{SESSION_TS}}|${SESSION_TS:-}|g" \
      -e "s|{{SESSION_ID}}|${SESSION_ID:-}|g" \
      -e "s|{{HOST_HEAD_SHA}}|${HOST_HEAD_SHA:-}|g" \
      -e "s|{{AGENT_IMAGE_DIGEST}}|${agent_image_digest:-}|g" \
      -e "s|{{SANDBOX_IMAGE_DIGEST}}|${sandbox_image_digest:-}|g" \
      -e "s|{{SANITIZED_HOST_BRANCH}}|${SANITIZED_HOST_BRANCH:-}|g" \
      -e "s|{{DRY_RUN_CAPABILITY_SCRIPT}}|${DRY_RUN_CAPABILITY_SCRIPT:-}|g" \
      -e "s|{{DRY_RUN_SCRIPT}}|${DRY_RUN_SCRIPT:-}|g" \
      -e "s|\${SANDBOX_DIR}|${SANDBOX_DIR:-}|g" \
      -e "s|\${WORKTREE_DIR}|${WORKTREE_DIR:-}|g" \
      -e "s|\${CHANGES_DIR}|${CHANGES_DIR:-}|g" \
      -e "s|\${INPUT_DIR}|${INPUT_DIR:-}|g" \
      -e "s|\${OUTPUT_DIR}|${OUTPUT_DIR:-}|g" \
      "$src" > "$dst"
    staged_files+=(-f "$dst")
    (( i++ )) || true
  done

  # Merge via docker compose config. --no-interpolate preserves ${VAR}
  # references so Docker Compose resolves them from the environment at
  # runtime. Two injected fields are stripped:
  #   name:              --  top-level project name (set via --project-name in compose_args)
  #   networks.default.name:  --  Compose injects the staging dir name; we want the
  #                            project-scoped default, set at runtime by --project-name
  docker compose "${staged_files[@]}" config --no-interpolate \
    | grep -v '^[[:space:]]*name:' \
    > "$output_file"
}

# -------------------------
# compose_file_from_args
#
# Prints the generated compose file path from the caller's COMPOSE_ARGS (the
# value of the last -f flag set by compose_args). Empty when COMPOSE_ARGS is
# unset or carries no -f.
compose_file_from_args() {
  local i n=0
  [[ -n "${COMPOSE_ARGS+x}" ]] && n=${#COMPOSE_ARGS[@]}
  for (( i=n-1; i>=0; i-- )); do
    if [[ "${COMPOSE_ARGS[$i]}" == "-f" ]]; then
      [[ $(( i + 1 )) -lt ${#COMPOSE_ARGS[@]} ]] && { echo "${COMPOSE_ARGS[$(( i + 1 ))]}"; return 0; }
    fi
  done
  return 0
}

# compose_args
#
# Sets COMPOSE_ARGS in the caller's scope from a pre-generated compose file.
# The project name is normalised and incorporates SESSION_ID so each session
# gets its own compose namespace (volume, network, containers).
#
# Args:
#   $1  project_name    --  used for --project-name
#   $2  sandbox_dir     --  passed as --project-directory
#   $3  compose_file    --  absolute path to the generated compose file
#   $4  session_id      --  SESSION_ID from session identity
# -------------------------
compose_args() {
  local project_name="$1"
  local sandbox_dir="$2"
  local compose_file="$3"
  local session_id="${4:-}"

  local normalised
  normalised="$(echo "$project_name" | tr '[:upper:]' '[:lower:]')"
  normalised="${normalised//[^a-z0-9-]/-}"

  # Incorporate SESSION_ID into the compose project name so each session
  # gets its own namespace. Falls back to sandbox_dir hash if SESSION_ID
  # is not available (e.g., dry-run before identity computation).
  if [[ -n "$session_id" ]]; then
    normalised="${normalised}-${session_id}"
  else
    local sandbox_hash
    sandbox_hash="$(echo "$sandbox_dir" | sha256sum | cut -c1-6)"
    normalised="${normalised}-${sandbox_hash}"
  fi

  # Assign to caller's COMPOSE_ARGS (no local  --  intentional).
  COMPOSE_ARGS=(
    --project-name "$normalised"
    --project-directory "$sandbox_dir"
    -f "$compose_file"
  )
}

# -------------------------
# compose_dry_run
#
# Runs the three-phase dry-run sequence against COMPOSE_ARGS and exits.
# The dry-run overlay is already merged into the compose file  --  no extra
# file args needed here.
#
# Phases:
#   1. Capability layer  --  dry_run_capability.sh inside sandbox container (start-up command)
#   2. Reasoning layer   --  dry_run_reasoning.sh inside agent container (start-up command)
#   3. Host-side         --  verify records on host filesystem
#
# Composes dry-run: starts the bearer containers (full init via the normal
# entrypoint on `up -d`), each container runs its own self-checks at start-up
# (a `command:` override in the dry-run overlay; the sandbox runs its probe as
# a prelude then stays alive, the agent runs its probe then exits), then
# consumes the per-container diagnostics records to assert the correct
# container was started. Record verification replaces interactive exec-RC /
# stdout judgement (see dry_run_record.sh).
#
# Args:
#   $1  dry_run_script   --  absolute path to dry_run_reasoning.sh (reasoning layer script) on the host
#   $2  dry_run_capability_script   --  path to dry_run_capability.sh (optional, skip phase 1 if empty)
#   $3  sandbox_dir      --  host-side SANDBOX_DIR (locates the output-mount records)
#   $4  remove_volumes   --  "true" to remove named volumes on teardown (default: false)
# -------------------------
compose_dry_run() {
  local dry_run_script="$1"
  local dry_run_capability_script="${2:-}"
  local _sandbox_dir="${3:-}"
  local _remove_volumes="${4:-false}"

  # Select the compose teardown function based on remove_volumes flag
  local _compose_down
  _compose_down="session_teardown"
  [[ "$_remove_volumes" == "true" ]] && _compose_down="session_destroy"

  # Expected container identities (image names) for the correct-container check.
  # Baked into each bearer's environment via DRY_RUN_IDENTITY (set in the dry-run
  # compose overlay); each probe echoes it into its diagnostics record so
  # orchestration can verify the correct container was started.
  local _identity_sandbox="${SANDBOX_IMAGE_NAME:-unknown}"
  local _identity_agent="${AGENT_IMAGE_NAME:-unknown}"

  local _cap_record="$_sandbox_dir/.workspace/output/dryrun.capability.record"
  local _rea_record="$_sandbox_dir/.workspace/output/dryrun.reasoning.record"

  # Start the bearer containers. Full init runs via the normal entrypoint on
  # `up -d`; the dry-run overlay sets a `command:` override (the sandbox runs
  # its probe as a prelude then stays alive; the agent runs its probe and
  # exits) so each bearer's self-checks run at container start-up -- no exec.
  rm -f "$_cap_record" "$_rea_record" 2>/dev/null || true
  echo "Starting containers (bearer probes run at start-up)..."
  DRY_RUN_SCRIPT="$dry_run_script" \
    DRY_RUN_CAPABILITY_SCRIPT="$dry_run_capability_script" \
    docker compose "${COMPOSE_ARGS[@]}" up -d 2>&1 | grep -vE '^ ?Container |^ ?Network |^ ?Volume |^ ?$' || true

  # Wait for both bearer containers to finish their start-up probes and write
  # their diagnostics records. The capability record is only expected when a
  # capability probe was supplied; the reasoning record is always expected.
  echo "Waiting for per-container diagnostics records..."
  local _deadline=$(( $(date +%s) + ${DRY_RUN_RECORD_TIMEOUT:-180} ))
  local _need_cap=1
  [[ -z "$dry_run_capability_script" ]] && _need_cap=0
  while (( $(date +%s) < _deadline )); do
    local _cap_ok=1 _rea_ok=1
    [[ -f "$_cap_record" ]] && _cap_ok=0
    [[ "$_need_cap" -eq 0 ]] && _cap_ok=0
    [[ -f "$_rea_record" ]] && _rea_ok=0
    (( _cap_ok == 0 && _rea_ok == 0 )) && break
    sleep 2
  done
  if (( _need_cap == 1 )) && [[ ! -f "$_cap_record" ]]; then
    echo "RECORD-VERIFY FAIL: timed out waiting for capability record" >&2
  fi
  if [[ ! -f "$_rea_record" ]]; then
    echo "RECORD-VERIFY FAIL: timed out waiting for reasoning record" >&2
  fi

  # Phase 3: orchestration correct-container verification from the records.
  # The bearer wrote one diagnostics record per container; orchestration reads
  # them (not stdout) and asserts the correct container was started (identity
  # echo-back == expected) and readiness per layer.
  echo ""
  echo "=== Phase 3: record verification (correct container) ==="

  local _verify_fails=0
  if [[ -z "$_sandbox_dir" ]]; then
    echo "RECORD-VERIFY SKIP: no sandbox dir provided" >&2
    _verify_fails=1
  else
    _verify_record() {
      dry_run_record_verify "$1" "$2" "$3" || _verify_fails=$(( _verify_fails + 1 ))
    }

    _verify_record "sandbox(capability)" "$_identity_sandbox" "$_cap_record"
    _verify_record "agent(reasoning)"   "$_identity_agent"   "$_rea_record"

    # Digest roundtrip hard gate (ADR harness_versioning.md): the image that
    # will run must be the exact image whose digest compose_generate stamped
    # into the generated compose file. Same label source as make start -- the
    # probes' records stay readiness-only (identity + layer status).
    local _compose_file
    _compose_file="$(compose_file_from_args)"
    dry_run_image_verify "$_identity_sandbox" "$_compose_file" "sandbox" \
      || _verify_fails=$(( _verify_fails + 1 ))
    dry_run_image_verify "$_identity_agent" "$_compose_file" "agent" \
      || _verify_fails=$(( _verify_fails + 1 ))

    if [[ "$_verify_fails" -eq 0 ]]; then
      echo "Phase 3 PASSED (correct container linked and ready)."
    else
      echo "Phase 3 FAILED  --  $_verify_fails record check(s) failed." >&2
    fi
  fi

  # Cleanup containers
  echo ""
  echo "Cleaning up containers..."
  $_compose_down

  if [[ "$_verify_fails" -eq 0 ]]; then
    echo ""
    echo "=== dry-run: ALL PHASES PASSED ==="
    return 0
  fi
  echo ""
  echo "=== dry-run: FAILED  --  $_verify_fails check(s) failed ===" >&2
  return 1
}

# -------------------------
# session_teardown
#
# Ends the session for COMPOSE_ARGS: removes containers + network, keeps named
# volumes. Must be called after compose_args has set COMPOSE_ARGS.
# -------------------------
session_teardown() {
  # docker compose down: end the session, keep named volumes.
  # Removes containers + network (frees the default address pool); the
  # SESSION_ID-scoped named volume persists so resume still works. The container
  # is disposable  --  durable state lives in the named volume + bind mounts
  # (see docs/architecture/execution_model.md  --  Container State Contract).
  docker compose "${COMPOSE_ARGS[@]}" down 2>/dev/null || true
}

# -------------------------
# session_destroy
#
# Ends the session for COMPOSE_ARGS and removes named volumes.
# Must be called after compose_args has set COMPOSE_ARGS.
# -------------------------
session_destroy() {
  docker compose "${COMPOSE_ARGS[@]}" down -v 2>/dev/null || true
}

# -------------------------
# compose_sandbox_wait
#
# Polls until the sandbox container reports healthy.
# Fails fast if the container exits before becoming healthy.
# Times out after SANDBOX_WAIT_TIMEOUT seconds (default: 120).
#
# Args:
#   $1  project_name
# -------------------------
compose_sandbox_wait() {
  local project_name="$1"
  local container
  container="$SANDBOX_CONTAINER_NAME"
 
  local timeout="${SANDBOX_WAIT_TIMEOUT:-120}"
  local elapsed=0
 
  echo "+ waiting for $container to be healthy..."
  until [[ "$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null)" == "healthy" ]]; do
    local state
    state="$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null)"
    if [[ "$state" == "exited" || "$state" == "dead" || -z "$state" ]]; then
      echo "Error: sandbox container exited before becoming healthy." >&2
      echo "  Check logs: docker logs $container" >&2
      return 1
    fi
    if [[ "$elapsed" -ge "$timeout" ]]; then
      echo "Error: sandbox container did not become healthy within ${timeout}s." >&2
      echo "  Check logs: docker logs $container" >&2
      return 1
    fi
    sleep 1
    (( elapsed++ )) || true
  done
  echo "+ sandbox healthy."
}