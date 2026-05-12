#!/usr/bin/env bash
# tests/libs/mock_repo_fixtures.sh
# Shared mock agent-sandbox repo fixture for build context tests.
# Source this file, do not execute directly.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: mock_repo_fixtures.sh must be sourced, not executed." >&2
  exit 1
fi

# make_mock_repo [--no-docs] [--no-agent-dir]
#   Creates a temp directory with a minimal agent-sandbox repo layout,
#   suitable as a repo_root for build_context_sandbox and build_context_agent.
#   Options allow callers to request only the sub-tree they need.
#   Prints the temp dir path to stdout.
#   Caller is responsible for cleanup (via rm -rf).
make_mock_repo() {
  local skip_docs=false
  local skip_agent_dir=false
  for arg in "$@"; do
    case "$arg" in
      --no-docs)       skip_docs=true ;;
      --no-agent-dir)  skip_agent_dir=true ;;
    esac
  done

  local dir
  dir=$(mktemp -d /tmp/XXXXXX)

  mkdir -p "$dir/libs"
  echo "dirs-content"        > "$dir/libs/dirs.sh"
  echo "snapshot-content"   > "$dir/libs/snapshot.sh"
  echo "diff-content"       > "$dir/libs/diff.sh"
  echo "package_branch-content" > "$dir/libs/package_branch.sh"
  echo "package_diff-content"   > "$dir/libs/package_diff.sh"
  echo "session-content"        > "$dir/libs/session.sh"
  echo "routing-content"        > "$dir/libs/routing.sh"

  mkdir -p "$dir/scripts"
  echo "entrypoint-content" > "$dir/libs/sandbox-entrypoint.sh"
  echo "provider-entrypoint-content" > "$dir/libs/provider-entrypoint.sh"

  if [[ "$skip_docs" == false ]]; then
    mkdir -p "$dir/docs/architecture"
    echo "arch-content" > "$dir/docs/architecture/test.md"
    mkdir -p "$dir/docs/concepts"
    echo "concept-content" > "$dir/docs/concepts/test.md"
  fi

  if [[ "$skip_agent_dir" == false ]]; then
    mkdir -p "$dir/agent/skills"
    echo "skill-content" > "$dir/agent/skills/test.md"
    mkdir -p "$dir/agent/prompts"
    echo "prompt-content" > "$dir/agent/prompts/test.md"
  fi

  echo "$dir"
}
