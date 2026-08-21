#!/usr/bin/env bash
# libs/container_sig.sh
#
# Shared container-signature computation and staleness predicate for the
# `agent-sandbox.container-sig` label. Consumed by both `scripts/build.sh`
# (build-time injection + preflight warning) and `scripts/prune.sh`
# (image-staleness selection, `STALE=image`), so the image-staleness criterion
# lives in exactly one place.
#
# Functions:
#   _sandbox_sig_sources     — source paths for the sandbox image (/opt/sandbox)
#   _agent_sig_sources       — source paths for an agent image (/opt/workflow + provider)
#   container_sig            — deterministic SHA-256 of the source-file set
#   image_is_stale           — baked container-sig vs recomputed -> fresh|stale|unknown
#   record_image_stale       — session-record image staleness (agent + sandbox)
#
# Terminology: image staleness (see docs/concepts/terminology.md `## staleness`)
# means the baked label differs from a recomputation of the current source,
# i.e. even resuming the session carries an incomplete/outdated feature set.

# Source paths for the sandbox image (maps to /opt/sandbox/). Emits each path
# on its own line. Callers load them into a bash array (`mapfile`) and expand
# with `"${arr[@]}"` — they are NOT a space-joined string to word-split.
_sandbox_sig_sources() {
  printf '%s\n' \
    "src/libs" \
    "src/capability/entrypoint.sh" \
    "src/capability/snapshot.sh" \
    "docs/architecture" \
    "docs/concepts"
}

# _agent_sig_sources <repo_root> <provider>
# Source paths for an agent image (maps to /opt/sandbox/ + /opt/workflow/).
# Provider-specific paths (config/, preflight.sh) included only when they exist.
_agent_sig_sources() {
  local repo_root="$1"
  local provider="$2"
  printf '%s\n' \
    "src/libs" \
    "src/reasoning/entrypoint.sh" \
    "docs/architecture" \
    "docs/concepts" \
    "src/reasoning/agent/skills" \
    "src/reasoning/agent/prompts"
  if [[ -d "$repo_root/src/reasoning/providers/$provider/config" ]]; then
    printf '%s\n' "src/reasoning/providers/$provider/config"
  fi
  if [[ -f "$repo_root/src/reasoning/providers/$provider/preflight.sh" ]]; then
    printf '%s\n' "src/reasoning/providers/$provider/preflight.sh"
  fi
}

# container_sig <repo_root> <source_path...>
# Computes a deterministic SHA-256 hash of all files under the given source
# directories. The source paths are repo-relative (e.g. src/libs) and are
# passed positionally as individual arguments (typically via "${arr[@]}").
# Returns a hex string suitable for use as a Docker label value.
container_sig() {
  local repo_root="${1:?container_sig requires repo_root}"
  shift 1
  local sources=("$@")
  local find_args=()
  local src
  for src in "${sources[@]}"; do
    find_args+=("$repo_root/$src")
  done

  # Fail-closed guard: every source path must exist. `find` on a missing path
  # returns non-zero, which under `set -e`/`pipefail` inside this command
  # substitution would abort the whole script with no output. Surface it
  # explicitly instead of hashing an empty set or failing silently.
  local base
  for base in "${find_args[@]}"; do
    if [[ ! -e "$base" ]]; then
      echo "container_sig: ERROR: source path not found: $base" >&2
      return 1
    fi
  done

  find "${find_args[@]}" -type f -print0 2>/dev/null \
    | sort -z \
    | xargs -0 sha256sum \
    | sha256sum \
    | awk '{print $1}'
}

# image_is_stale <image_name> <type: sandbox|agent> <repo_root> [provider]
# Prints the image-staleness of an existing image: "stale" when its baked
# `agent-sandbox.container-sig` label differs from a recomputation of the
# current source, "fresh" when they match, "unknown" when the image is missing,
# has no container-sig label, or its sources cannot be recomputed. Always
# returns 0 (best-effort; no caller is aborted by a missing image).
image_is_stale() {
  local image_name="${1:?image_is_stale requires image name}"
  local type="${2:?image_is_stale requires image type (sandbox|agent)}"
  local repo_root="${3:?image_is_stale requires repo_root}"
  local provider="${4:-}"

  local baked_sig
  baked_sig="$(docker image inspect \
    --format '{{ index .Config.Labels "agent-sandbox.container-sig" }}' \
    "$image_name" 2>/dev/null || true)"

  if [[ -z "$baked_sig" ]]; then
    echo "unknown"
    return 0
  fi

  local sources=()
  case "$type" in
    sandbox)
      mapfile -t sources < <(_sandbox_sig_sources)
      ;;
    agent)
      [[ -n "$provider" ]] || { echo "unknown"; return 0; }
      mapfile -t sources < <(_agent_sig_sources "$repo_root" "$provider")
      ;;
    *)
      echo "unknown"
      return 0
      ;;
  esac

  local current_sig
  current_sig="$(container_sig "$repo_root" "${sources[@]}" 2>/dev/null || true)"
  [[ -n "$current_sig" ]] || { echo "unknown"; return 0; }

  if [[ "$baked_sig" == "$current_sig" ]]; then echo "fresh"; else echo "stale"; fi
}

# record_image_stale FILE REPO_ROOT
# Image-staleness of a session record: "stale" when either referenced image
# (agent / sandbox) is image-stale, "fresh" when both are fresh, "unknown"
# when not determinable. The images are derived from the record's agent image
# line (`image: <provider>-agent-<lower-project>`): the agent image references
# the provider layer, and the capability layer is `sandbox-<lower-project>`.
record_image_stale() {
  local file="$1"
  local repo_root="$2"
  local agent_img provider lower_proj sandbox_img as ss
  agent_img="$(grep -m1 -E 'image:[[:space:]]*[^[:space:]]+-agent-[^[:space:]]+' "$file" \
    | sed -E 's/.*image:[[:space:]]*([^[:space:]]+).*/\1/' || true)"
  [[ -n "$agent_img" ]] || { echo "unknown"; return 0; }
  provider="${agent_img%%-agent-*}"
  lower_proj="${agent_img#*-agent-}"
  sandbox_img="sandbox-${lower_proj}"

  as="$(image_is_stale "$agent_img" agent "$repo_root" "$provider")"
  ss="$(image_is_stale "$sandbox_img" sandbox "$repo_root")"

  if [[ "$as" == "stale" || "$ss" == "stale" ]]; then echo "stale"
  elif [[ "$as" == "fresh" && "$ss" == "fresh" ]]; then echo "fresh"
  else echo "unknown"; fi
}