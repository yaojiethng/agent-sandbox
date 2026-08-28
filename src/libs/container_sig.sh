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
#   current_sig              — current sig for a layer type
#   image_is_stale           — baked container-sig vs recomputed -> fresh|stale|unknown
#
# (record_image_stale — the record-level aggregation — lives in
# src/libs/session_inventory.sh, which sources this lib.)
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

  if (( ${#find_args[@]} == 0 )); then
    echo "container_sig: ERROR: no source paths given" >&2
    return 1
  fi

  find "${find_args[@]}" -type f -print0 2>/dev/null \
    | sort -z \
    | xargs -0 -r sha256sum \
    | sha256sum \
    | awk '{print $1}'
}

# current_sig <type: sandbox|agent> <repo_root> [provider]
# Computes the current container-sig for a layer type (the value an up-to-date
# image would carry in `agent-sandbox.container-sig`). Pure function of
# (type, repo_root, provider): recomputes on every call and reflects live tree
# state. Prints the sig, or nothing + non-zero when the type is unknown or its
# sources cannot be resolved.
current_sig() {
  local type="$1"
  local repo_root="${2:?current_sig requires repo_root}"
  local provider="${3:-}"
  local -a sources=()
  case "$type" in
    sandbox)
      mapfile -t sources < <(_sandbox_sig_sources)
      ;;
    agent)
      [[ -n "$provider" ]] || return 1
      mapfile -t sources < <(_agent_sig_sources "$repo_root" "$provider")
      ;;
    *)
      return 1
      ;;
  esac

  local sig
  sig="$(container_sig "$repo_root" "${sources[@]}" 2>/dev/null || true)"
  [[ -n "$sig" ]] || return 1
  echo "$sig"
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

  local baked_sig current_s
  baked_sig="$(docker image inspect \
    --format '{{ index .Config.Labels "agent-sandbox.container-sig" }}' \
    "$image_name" 2>/dev/null || true)"
  [[ -n "$baked_sig" ]] || { echo "unknown"; return 0; }

  current_s="$(current_sig "$type" "$repo_root" "$provider")" || { echo "unknown"; return 0; }

  if [[ "$baked_sig" == "$current_s" ]]; then echo "fresh"; else echo "stale"; fi
}
