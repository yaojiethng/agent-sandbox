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
#   compose_args          Sets COMPOSE_ARGS in the caller's scope from a
#                         single pre-generated compose file and project name.
#
#   compose_dry_run       Full dry-run sequence against COMPOSE_ARGS:
#                         up, exec, down. Overlay already merged — no extra
#                         file args needed.
#
#   compose_teardown      Silent down -v against COMPOSE_ARGS.
#
#   compose_sandbox_wait  Polls until sandbox container reports healthy.

# -------------------------
# compose_generate
#
# Merges compose files, substitutes {{VAR}} placeholders, preserves ${VAR}
# for Docker Compose runtime resolution. Writes merged output to a file.
#
# Substitutions applied here (baked into generated file):
#   {{PROJECT_NAME}}        → project name
#   {{SANDBOX_IMAGE_NAME}}  → derived image name
#   {{AGENT_IMAGE_NAME}}    → derived image name
#   {{DRY_RUN_SCRIPT}}      → absolute path to dry_run.sh (dry-run mode only)
#   ${SNAPSHOT_DIR}         → host snapshot path (from .env, exported by start_agent.sh)
#   ${CHANGES_DIR}          → host changes path (from .env, exported by start_agent.sh)
#   ${INPUT_DIR}            → host input path (from .env, exported by start_agent.sh)
#   ${OUTPUT_DIR}           → host output path (from .env, exported by start_agent.sh)
#
# Preserved as ${VAR} for Docker Compose runtime resolution (operator-set):
#   ${SERVE_PORT}           → port for serve mode
#   ${AUTOSAVE_INTERVAL}    → autosave interval
#   ${OPENCODE_SERVER_PASSWORD} → OpenCode serve mode credential
#   Any other provider-specific secrets
#
# Args:
#   $1       output_file      — absolute path to write merged compose file
#   $2       project_name     — value for {{PROJECT_NAME}}
#   $3       provider_name    — used to derive {{AGENT_IMAGE_NAME}}
#   $4...$N  input_files      — compose files to merge, in order
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

  # Derive image names — baked into generated file.
  local sandbox_image agent_image
  sandbox_image="$(sandbox_image_name "$project_name")"
  agent_image="$(agent_image_name "$provider_name" "$project_name")"

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
    local dst="$staging_dir/$(printf '%02d' $i)-$(basename "$src")"
    sed \
      -e "s|{{PROJECT_NAME}}|${project_name}|g" \
      -e "s|{{SANDBOX_IMAGE_NAME}}|${sandbox_image}|g" \
      -e "s|{{AGENT_IMAGE_NAME}}|${agent_image}|g" \
      -e "s|{{DRY_RUN_SCRIPT}}|${DRY_RUN_SCRIPT:-}|g" \
      -e "s|\${SNAPSHOT_DIR}|${SNAPSHOT_DIR:-}|g" \
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
  #   name:             — top-level project name (set via --project-name in compose_args)
  #   networks.default.name: — Compose injects the staging dir name; we want the
  #                            project-scoped default, set at runtime by --project-name
  docker compose "${staged_files[@]}" config --no-interpolate \
    | grep -v '^name:' \
    | grep -v '^\s*name:.*_default$' \
    > "$output_file"
}

# -------------------------
# compose_args
#
# Sets COMPOSE_ARGS in the caller's scope from a pre-generated compose file.
# The project name is normalised to match Docker Compose conventions.
#
# Args:
#   $1  project_name   — used for --project-name
#   $2  sandbox_dir    — passed as --project-directory
#   $3  compose_file   — absolute path to the generated compose file
# -------------------------
compose_args() {
  local project_name="$1"
  local sandbox_dir="$2"
  local compose_file="$3"

  local normalised="${project_name,,}"
  normalised="${normalised//[^a-z0-9-]/-}"

  # Assign to caller's COMPOSE_ARGS (no local — intentional).
  COMPOSE_ARGS=(
    --project-name "$normalised"
    --project-directory "$sandbox_dir"
    -f "$compose_file"
  )
}

# -------------------------
# compose_dry_run
#
# Runs the standard dry-run sequence against COMPOSE_ARGS and exits.
# The dry-run overlay is already merged into the compose file — no extra
# file args needed here.
#
# Args:
#   $1  dry_run_script  — absolute path to dry_run.sh on the host
# -------------------------
compose_dry_run() {
  local dry_run_script="$1"

  DRY_RUN_SCRIPT="$dry_run_script" docker compose "${COMPOSE_ARGS[@]}" up -d
  DRY_RUN_SCRIPT="$dry_run_script" docker compose "${COMPOSE_ARGS[@]}" exec agent bash /dry_run.sh
  DRY_RUN_SCRIPT="$dry_run_script" docker compose "${COMPOSE_ARGS[@]}" down -v

  echo ""
  echo "=== liveness: PASS ==="
}

# -------------------------
# compose_teardown
#
# Silently tears down containers and volumes for COMPOSE_ARGS.
# Must be called after compose_args has set COMPOSE_ARGS.
# -------------------------
compose_teardown() {
  docker compose "${COMPOSE_ARGS[@]}" down -v 2>/dev/null || true
}

# -------------------------
# compose_sandbox_wait
#
# Polls until the sandbox container reports healthy.
#
# Args:
#   $1  project_name
# -------------------------
compose_sandbox_wait() {
  local project_name="$1"
  local container
  container="$(sandbox_container_name "$project_name")"

  echo "+ waiting for sandbox to be healthy..."
  until [[ "$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null)" == "healthy" ]]; do
    sleep 1
  done
  echo "+ sandbox healthy."
}
