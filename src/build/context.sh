#!/usr/bin/env bash
# build/context.sh
# Build context preparation — assembles temp directories with files
# required for docker build.
# Sourced by scripts/build.sh.
#
# Provides:
#   _build_context_copy   - copy a single file into the build context
#   build_context_sandbox - populate a temp dir with sandbox build context files
#   build_context_agent   - populate a temp dir with agent build context files

# -------------------------
# Build context
# -------------------------

# _build_context_copy <src> <dst>
# Copies a single file into the build context. Hard error if src is missing.
_build_context_copy() {
  local src="$1"
  local dst_dir="$2"
  if [[ ! -f "$src" ]]; then
    echo "Error: build context file not found: $src" >&2
    return 1
  fi
  cp "$src" "$dst_dir/"
}

# build_context_sandbox <repo_root>
# Creates and populates a temp dir with files required for a sandbox image build.
# Prints the temp dir path to stdout. Caller is responsible for cleanup.
build_context_sandbox() {
  local repo_root="${1:?build_context_sandbox requires repo_root}"
  local context_dir=""
  context_dir=$(mktemp -d)
  trap '[[ -n "$context_dir" ]] && rm -rf "$context_dir"' ERR

  _build_context_copy "$repo_root/src/capability/entrypoint.sh"     "$context_dir/" || return 1
  _build_context_copy "$repo_root/src/libs/dirs.sh"                 "$context_dir/" || return 1
  _build_context_copy "$repo_root/src/libs/diff_export.sh"                 "$context_dir/" || return 1
  _build_context_copy "$repo_root/src/libs/session_state.sh"        "$context_dir/" || return 1
  _build_context_copy "$repo_root/src/capability/snapshot.sh"       "$context_dir/" || return 1
  _build_context_copy "$repo_root/src/libs/routing.sh"              "$context_dir/" || return 1
  _build_context_copy "$repo_root/src/libs/package_diff.sh"         "$context_dir/" || return 1
  _build_context_copy "$repo_root/src/libs/package_branch.sh"       "$context_dir/" || return 1 || return 1

  # docs/
  mkdir -p "$context_dir/docs" || return 1
  cp -r "$repo_root/docs/architecture" "$context_dir/docs/architecture" || return 1
  cp -r "$repo_root/docs/concepts"     "$context_dir/docs/concepts"     || return 1

  echo "$context_dir"
}

# build_context_agent <repo_root> <provider>
# Creates and populates a temp dir with files required for an agent image build.
build_context_agent() {
  local repo_root="${1:?build_context_agent requires repo_root}"
  local provider="${2:?build_context_agent requires provider}"
  local context_dir=""
  context_dir=$(mktemp -d)
  trap '[[ -n "$context_dir" ]] && rm -rf "$context_dir"' ERR

  # Harness-owned files - required for all providers.
  _build_context_copy "$repo_root/src/reasoning/entrypoint.sh"      "$context_dir/" || return 1
  _build_context_copy "$repo_root/src/libs/dirs.sh"                 "$context_dir/" || return 1
  _build_context_copy "$repo_root/src/libs/diff_export.sh"                 "$context_dir/" || return 1
  _build_context_copy "$repo_root/src/libs/session_state.sh"        "$context_dir/" || return 1
  _build_context_copy "$repo_root/src/libs/routing.sh"              "$context_dir/" || return 1
  _build_context_copy "$repo_root/src/libs/package_diff.sh"         "$context_dir/" || return 1
  _build_context_copy "$repo_root/src/libs/package_branch.sh"       "$context_dir/" || return 1
  # docs/
  mkdir -p "$context_dir/docs" || return 1
  cp -r "$repo_root/docs/architecture" "$context_dir/docs/architecture" || return 1
  cp -r "$repo_root/docs/concepts"     "$context_dir/docs/concepts"     || return 1

  # Agent workflow files — prompts and skills the agent uses at runtime
  mkdir -p "$context_dir/agent" || return 1
  cp -r "$repo_root/agent/skills"  "$context_dir/agent/skills"  || return 1
  cp -r "$repo_root/agent/prompts" "$context_dir/agent/prompts" || return 1

  # Provider config template
  if [[ -d "$repo_root/providers/$provider/config" ]]; then
    cp -r "$repo_root/providers/$provider/config" "$context_dir/agent/config" || return 1
  fi

  # Provider-specific pre-flight script (optional)
  local _provider_preflight="$repo_root/providers/$provider/preflight.sh"
  if [[ -f "$_provider_preflight" ]]; then
    cp "$_provider_preflight" "$context_dir/provider-preflight.sh" || return 1
  fi
  unset _provider_preflight

  echo "$context_dir"
}
