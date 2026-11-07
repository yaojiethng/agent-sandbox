#!/usr/bin/env bash
# scripts/build.sh
# Build orchestration  --  builds Docker images for agent and sandbox layers.
# Sourced by host scripts (start_agent.sh, run_agent.sh, agent-sandbox.sh).
#
# Sources:
#   src/build/image.sh   --  image naming
#   libs/interface_contract.sh   --  interface-contract version (authoritative)
#   libs/cli.sh          --  flag parsing
#
# Provides:
#   build_image    - run docker build using repo root as context
#   build_agent    - three-tier build (shared -> provider-base -> provider-image)
#   build_sandbox  - build the capability layer image for a given project
#   preflight      - verify both images exist; build if missing

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$_self_dir/.." && pwd)"

# quiet keeps the harness log to one line per image; the probe passes plain.
BUILD_PROGRESS="quiet"

source "$REPO_ROOT/src/build/image.sh"
source "$REPO_ROOT/src/libs/interface_contract.sh"
source "$REPO_ROOT/src/libs/cli.sh"


# -------------------------
# Build execution
# -------------------------

# build_image <image_name> <dockerfile> <repo_root> <contract_label> <no_cache> [extra_label] [docker build args...]
# contract_label is the interface-contract version (ADR
# interface_contract_compatibility.md), or empty for a shared tier. The repo
# root is the docker build context.
build_image() {
  local image_name="${1:?build_image requires image_name}"
  local dockerfile="${2:?build_image requires dockerfile}"
  local repo_root="${3:?build_image requires repo_root}"
  local contract_label="${4:-}"
  local no_cache="${5:-}"
  local extra_label="${6:-}"
  shift 6

  local build_cmd=(docker build)
  if [[ "${BUILD_PROGRESS:-quiet}" == "quiet" ]]; then
    build_cmd+=(--quiet)
  else
    build_cmd+=(--progress="$BUILD_PROGRESS")
  fi
  [[ -n "$no_cache" ]] && build_cmd+=(--no-cache)
  build_cmd+=(-t "$image_name" -f "$dockerfile")
  [[ -n "$contract_label" ]] && build_cmd+=(--label "agent-sandbox.interface-contract-version=$contract_label")
  [[ -n "$extra_label" ]] && build_cmd+=(--label "$extra_label")
  build_cmd+=("$@" "$repo_root")

  local _build_rc=0
  echo "Building image: $image_name"
  "${build_cmd[@]}" || _build_rc=$?
  [[ $_build_rc -eq 0 ]] && echo "  Build complete: $image_name"

  if [[ $_build_rc -ne 0 ]]; then
    echo "build_image: ERROR build FAILED for $image_name (exit $_build_rc)." >&2
    exit 1
  fi
}

# build_agent <provider> <project_name> <repo_root> [--no-cache] [--uid UID] [--gid GID]
# Builds the provider's three tiers; --no-cache rebuilds every tier, and
# --uid/--gid thread the host UID/GID.
build_agent() {
  local provider="${1:?build_agent requires provider}"
  local project="${2:?build_agent requires project name}"
  local repo_root="${3:?build_agent requires repo root}"
  local no_cache="${4:-}"
  local host_uid="${5:-}"
  local host_gid="${6:-}"

  local cache_flag=""
  if [[ -n "$no_cache" ]]; then
    cache_flag="--no-cache"
  fi

  local uid_args=()
  if [[ -n "$host_uid" ]]; then
    uid_args+=(--build-arg "HOST_UID=$host_uid")
  fi
  if [[ -n "$host_gid" ]]; then
    uid_args+=(--build-arg "HOST_GID=$host_gid")
  fi

  local shared_base; shared_base="$(shared_base_image_name)"
  local shared_dockerfile="$repo_root/src/reasoning/base.dockerfile"

  local tier2_image tier2_dockerfile
  local provider_base_dockerfile="$repo_root/src/reasoning/agent-runtime/$provider/base.dockerfile"
  if [[ -f "$provider_base_dockerfile" ]]; then
    tier2_image="$(agent_base_image_name "$provider")"
    tier2_dockerfile="$provider_base_dockerfile"
  else
    tier2_image="$(runtimes_base_image_name)"
    tier2_dockerfile="$repo_root/src/reasoning/runtimes.dockerfile"
  fi

  local provider_image; provider_image="$(agent_image_name "$provider" "$project")"
  local provider_dockerfile="$repo_root/src/reasoning/agent-runtime/$provider/provider.dockerfile"

  if [[ ! -f "$shared_dockerfile" ]]; then
    echo "build_agent: ERROR: shared base Dockerfile not found: $shared_dockerfile" >&2
    exit 1
  fi
  if [[ ! -f "$tier2_dockerfile" ]]; then
    echo "build_agent: ERROR: agent-runtime tier Dockerfile not found: $tier2_dockerfile" >&2
    exit 1
  fi
  if [[ ! -f "$provider_dockerfile" ]]; then
    echo "build_agent: ERROR: provider Dockerfile not found: $provider_dockerfile" >&2
    exit 1
  fi

  build_image "$shared_base" "$shared_dockerfile" "$repo_root" "" "$cache_flag" "" \
    "${uid_args[@]+${uid_args[@]}}"

  build_image "$tier2_image" "$tier2_dockerfile" "$repo_root" "" "$cache_flag" "" \
    --build-arg "BASE_IMAGE=$shared_base" \
    "${uid_args[@]+${uid_args[@]}}"

  build_image "$provider_image" "$provider_dockerfile" "$repo_root" "$(interface_contract_version)" "$cache_flag" "" \
    --build-arg "BASE_IMAGE=$tier2_image" \
    "${uid_args[@]+${uid_args[@]}}"
}

# build_sandbox <project_name> <repo_root> [--uid UID] [--gid GID]
build_sandbox() {
  local project="${1:?build_sandbox requires project name}"
  local repo_root="${2:?build_sandbox requires repo root}"
  local host_uid="${3:-}"
  local host_gid="${4:-}"

  local dockerfile="$repo_root/src/capability/dockerfile"
  if [[ ! -f "$dockerfile" ]]; then
    echo "build_sandbox: ERROR: Dockerfile not found: $dockerfile" >&2
    exit 1
  fi

  local image; image="$(sandbox_image_name "$project")"

  local uid_args=()
  if [[ -n "$host_uid" ]]; then
    uid_args+=(--build-arg "HOST_UID=$host_uid")
  fi
  if [[ -n "$host_gid" ]]; then
    uid_args+=(--build-arg "HOST_GID=$host_gid")
  fi

  build_image "$image" "$dockerfile" "$repo_root" "$(interface_contract_version)" "" "" "${uid_args[@]+${uid_args[@]}}"
}

# -------------------------
# Preflight
# -------------------------

# check_pin_drift <repo_root> -- the fast local nudge. A pin the Dockerfile and
# src/build/pins.json disagree on is a warning here and a failure in
# scripts/check_pins.sh: the gate belongs in the lint umbrella, and a build that
# stopped for it would be a second blocking check in a slower place.
check_pin_drift() {
  local repo_root="$1"
  command -v node >/dev/null 2>&1 || return 0
  local findings rc=0
  findings="$(node "$repo_root/src/build/pins.mjs" check --root "$repo_root" 2>/dev/null)" || rc=$?
  (( rc == 0 )) && return 0
  echo "preflight: WARNING: a build input's pin disagrees with src/build/pins.json:" >&2
  printf '%s\n' "$findings" >&2
  echo "preflight: run 'bash scripts/check_pins.sh' for the gate; the build continues." >&2
}

# preflight <provider> <project_name> <repo_root>
preflight() {
  local provider="${1:?preflight requires provider}"
  local project="${2:?preflight requires project name}"
  local repo_root="${3:?preflight requires repo root}"
  local build_missing="${4:-true}"  # resume passes false  --  a resume must not rebuild

  check_pin_drift "$repo_root"

  local sandbox_image; sandbox_image=$(sandbox_image_name "$project")
  local agent_image;   agent_image=$(agent_image_name "$provider" "$project")
  local missing=false

  if ! docker image inspect "$sandbox_image" >/dev/null 2>&1; then
    echo "Image not found: $sandbox_image"
    missing=true
  fi
  if ! docker image inspect "$agent_image" >/dev/null 2>&1; then
    echo "Image not found: $agent_image"
    missing=true
  fi

  if [[ "$missing" == true ]]; then
    if [[ "$build_missing" == "true" ]]; then
      echo "One or more required images are missing. Building them now."
      build_sandbox "$project" "$repo_root"
      build_agent   "$provider" "$project" "$repo_root"
      # Staleness check skipped for fresh builds
      return 0
    else
      echo "Error: required images are missing and resume does not build." >&2
      echo "  Run 'make start' (or 'make build') to build them first." >&2
      return 1
    fi
  fi

  # The contract is authoritative (ADR interface_contract_compatibility.md).
  _check_interface_contract "$sandbox_image" || return 1
  _check_interface_contract "$agent_image"   || return 1
}

# _check_interface_contract <image_name>
# Refuses when the baked interface-contract label is missing or differs from the
# host's constant (ADR interface_contract_compatibility.md).
_check_interface_contract() {
  local image_name="${1:?}"

  local baked current
  baked="$(image_contract_version "$image_name")"
  if [[ -z "$baked" ]]; then
    echo "ERROR: $image_name has no interface-contract-version label (built before the interface-contract check)." >&2
    echo "  The image predates the interface contract; rebuild with --rebuild." >&2
    return 1
  fi
  current="$(interface_contract_version)"
  if [[ "$baked" != "$current" ]]; then
    echo "ERROR: $image_name interface-contract version $baked differs from current source ($current)." >&2
    echo "  Rebuild with --rebuild to align the container with the current contract." >&2
    return 1
  fi
}

# =============================================================================
# main  --  entry point when exec'd by agent-sandbox build
# =============================================================================

# Parses the operator flags and builds the selected targets; --help lists them.

usage() {
  cat <<EOF
Usage: agent-sandbox build --name=<name> --project=<path> [options]

Builds Docker images for the sandbox and/or agent providers.

or, from a sandbox Makefile: make build [TARGETS=<p>] [REBUILD=1]

Required:
  --name=<name>       Project name (used for image tags)
  --project=<path>    Path to the project directory

Options:
  --sandbox=<path>    Accepted for CLI uniformity; build does not read it
  --targets=<list>    Comma-separated targets: all, sandbox, <provider>[,<provider>] (default: all)
  --rebuild           Force a full rebuild from scratch
  --progress=<mode>   docker build progress: quiet (default) or a docker mode
                      such as plain, which prints the per-step timings
EOF
}

main() {
  parse_args usage \
    --name=PROJECT_NAME \
    --project=PROJECT_DIR \
    --sandbox=SANDBOX_DIR \
    --targets=BUILD_TARGETS \
    --progress=BUILD_PROGRESS \
    --rebuild \
    -- "$@"
  local rc=$?
  if [[ $rc -eq 2 ]]; then exit 0; fi
  [[ $rc -eq 0 ]] || exit 1
  local REBUILD_FLAG=""
  [[ "$REBUILD" == true ]] && REBUILD_FLAG="--no-cache"

  if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" ]]; then
    usage >&2
    exit 1
  fi

  local _build_self
  _build_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local REPO_ROOT
  REPO_ROOT="$(cd "$_build_self/.." && pwd)"

  if [[ -z "$BUILD_TARGETS" || "$BUILD_TARGETS" == "all" ]]; then
    build_sandbox "$PROJECT_NAME" "$REPO_ROOT"
    for PROVIDER_DOCKERFILE in "$REPO_ROOT/src/reasoning/agent-runtime/"*/provider.dockerfile; do
      [[ -f "$PROVIDER_DOCKERFILE" ]] || continue
      local DISCOVERED_PROVIDER
      DISCOVERED_PROVIDER="$(basename "$(dirname "$PROVIDER_DOCKERFILE")")"
      build_agent "$DISCOVERED_PROVIDER" "$PROJECT_NAME" "$REPO_ROOT" $REBUILD_FLAG
    done
  else
    IFS=',' read -ra TARGET_LIST <<< "$BUILD_TARGETS"
    local WANT_SANDBOX=false
    local -a PROVIDER_TARGETS=()
    for T in "${TARGET_LIST[@]}"; do
      if [[ "$T" == "sandbox" ]]; then
        WANT_SANDBOX=true
      else
        PROVIDER_TARGETS+=("$T")
      fi
    done
    if [[ "$WANT_SANDBOX" == true ]]; then
      build_sandbox "$PROJECT_NAME" "$REPO_ROOT"
    fi
    for P in "${PROVIDER_TARGETS[@]}"; do
      build_agent "$P" "$PROJECT_NAME" "$REPO_ROOT" $REBUILD_FLAG
    done
  fi
}

# Standalone runs use the same fail-abort options as production.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  main "$@"
fi
