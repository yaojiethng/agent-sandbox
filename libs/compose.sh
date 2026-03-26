#!/usr/bin/env bash
# libs/compose.sh
#
# Shared Docker Compose primitives for provider run scripts.
# Source this file after containers.sh — compose_args() depends on
# the PROJECT_NAME variable being set in the caller's scope.
#
# Functions:
#   compose_args          BASE_ARGS array constructor — always includes
#                         --project-name, --project-directory, -f base compose.
#                         Call once after COMPOSE_FILE is resolved; the result
#                         is assigned to COMPOSE_ARGS in the caller's scope.
#
#   compose_dry_run       Full dry-run sequence: up, exec, down.
#                         Exits 0 on pass; exits non-zero on failure.
#
#   compose_teardown      Silent down -v; used before a fresh start.
#
#   compose_sandbox_wait  Polls until sandbox container reports healthy.
#
# Usage pattern in a provider run.sh:
#
#   source "$REPO_ROOT/libs/compose.sh"
#
#   compose_args "$PROJECT_NAME" "$SANDBOX_DIR" "$COMPOSE_FILE"
#   # COMPOSE_ARGS is now set
#
#   COMPOSE_ARGS+=(-f "$SERVE_OVERLAY")   # append overlays as needed
#
#   compose_teardown
#   docker compose "${COMPOSE_ARGS[@]}" up -d

# -------------------------
# compose_args
#
# Sets COMPOSE_ARGS in the caller's scope.
#
# Args:
#   $1  PROJECT_NAME   — used for --project-name; must match the value used
#                        when containers were created, or stop/down will miss them
#   $2  SANDBOX_DIR    — passed as --project-directory and for -f resolution
#   $3  COMPOSE_FILE   — absolute path to the base docker-compose.yml
# -------------------------
compose_args() {
  local project_name="$1"
  local sandbox_dir="$2"
  local compose_file="$3"

  # Derive normalised project name — same rule as stop.sh and Docker Compose:
  # lowercase, chars outside [a-z0-9-] replaced with hyphens.
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
# Runs the standard dry-run sequence and exits.
# Caller is responsible for overlay validation before calling.
#
# Args:
#   $1  PROJECT_NAME
#   $2  SANDBOX_DIR
#   $3  COMPOSE_FILE        — base compose file
#   $4  DRY_RUN_OVERLAY     — dry-run overlay file
#   $5  DRY_RUN_SCRIPT      — absolute path to dry_run.sh on the host
# -------------------------
compose_dry_run() {
  local project_name="$1"
  local sandbox_dir="$2"
  local compose_file="$3"
  local dry_run_overlay="$4"
  local dry_run_script="$5"

  local normalised="${project_name,,}"
  normalised="${normalised//[^a-z0-9-]/-}"

  local args=(
    --project-name "$normalised"
    --project-directory "$sandbox_dir"
    -f "$compose_file"
    -f "$dry_run_overlay"
  )

  DRY_RUN_SCRIPT="$dry_run_script" docker compose "${args[@]}" up -d
  DRY_RUN_SCRIPT="$dry_run_script" docker compose "${args[@]}" exec agent bash /dry_run.sh
  DRY_RUN_SCRIPT="$dry_run_script" docker compose "${args[@]}" down -v

  echo ""
  echo "=== liveness: PASS ==="
}

# -------------------------
# compose_teardown
#
# Silently tears down containers and volumes for COMPOSE_ARGS.
# Must be called after compose_args() has set COMPOSE_ARGS.
# Errors are suppressed — no containers running is not a failure.
# -------------------------
compose_teardown() {
  docker compose "${COMPOSE_ARGS[@]}" down -v 2>/dev/null || true
}

# -------------------------
# compose_sandbox_wait
#
# Polls until the sandbox container reports healthy.
# Container name is resolved via sandbox_container_name() from containers.sh.
#
# Args:
#   $1  PROJECT_NAME
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
