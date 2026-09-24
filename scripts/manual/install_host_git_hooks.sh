#!/usr/bin/env bash
# scripts/manual/install_host_git_hooks.sh
# Install the pre-commit hook into the host checkout, operator-initiated.
#
# The container never writes the host .git. Copy delivery installs a hook
# into the session volume's .git from the capability entrypoint; mount
# delivery installs none (docs/adr/git_hooks.md, entry 2026-09-20: an
# agent-writable host hook is a host code-execution vector). This script
# gives the host checkout the same commit-time backpressure WITHOUT that
# constraint change: you run it on the host, from the agent-sandbox
# checkout, and only that checkout's .git is touched. The agent never
# touches it, so the hook content stays the reviewed source file for the
# checkout's life.
#
# The hook (src/capability/git-hooks/pre-commit.sh) is delivery-agnostic:
# it resolves the repo root with git and note-and-allows when a lint tool
# is absent. This script enforces a loud tool floor so a host hook is never
# a silent no-op, and --check confirms an installed hook still matches the
# source (re-run after a branch update that changed the hook).
#
# Run on the host checkout, not inside a container:
#   bash scripts/manual/install_host_git_hooks.sh             -- install
#   bash scripts/manual/install_host_git_hooks.sh --check      -- report drift
#   bash scripts/manual/install_host_git_hooks.sh --skip-tool-check
#                                                              -- install without
#                                                                the lint-tool gate
#
# Scope: the agent-sandbox checkout. The script copies THIS repo's hook, so
# a project checkout would receive the harness hook, not the project's own
# lint policy -- do not run it against arbitrary repositories.
#
# Bash 3.2 compatible (macOS system /usr/bin/bash): no associative arrays,
# no readlink -f (use git rev-parse --show-toplevel / pwd -P).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
HOOK_SRC="$REPO_ROOT/src/capability/git-hooks/pre-commit.sh"

CHECK_ONLY=false
SKIP_TOOLS=false
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=true ;;
    --skip-tool-check) SKIP_TOOLS=true ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "usage: $0 [--check] [--skip-tool-check]" >&2; exit 2 ;;
  esac
done

# git-dir may be relative to the repo root (a bare or linked layout).
GIT_DIR="$(git -C "$REPO_ROOT" rev-parse --git-dir 2>/dev/null)" || {
  echo "error: not a git checkout: $REPO_ROOT" >&2
  exit 1
}
case "$GIT_DIR" in
  /*) GIT_DIR_ABS="$GIT_DIR" ;;
  *)  GIT_DIR_ABS="$REPO_ROOT/$GIT_DIR" ;;
esac
DEST="$GIT_DIR_ABS/hooks/pre-commit"

# The hook itself note-and-allows a missing tool; a host hook must not
# degrade silently, so the installer fails closed unless told otherwise.
tool_present() {
  command -v "$1" >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/$1" ]]
}
if ! $SKIP_TOOLS; then
  missing=""
  tool_present markdownlint-cli2 || missing="$missing markdownlint-cli2"
  tool_present shellcheck || missing="$missing shellcheck"
  if [[ -n "$missing" ]]; then
    echo "error: missing lint tool(s):$missing" >&2
    echo "  install them on the host, or re-run with --skip-tool-check" >&2
    echo "  (a host hook without its tools note-and-allows: a silent no-op)" >&2
    exit 1
  fi
fi

[[ -f "$HOOK_SRC" ]] || {
  echo "error: hook source missing: $HOOK_SRC" >&2
  exit 1
}

if $CHECK_ONLY; then
  if [[ -f "$DEST" ]]; then
    if cmp -s "$DEST" "$HOOK_SRC"; then
      echo "hook installed and matches source: $DEST"
      exit 0
    fi
    echo "hook installed but DRIFTS from source: $DEST" >&2
    echo "re-install with: bash $0" >&2
    exit 1
  fi
  echo "no hook installed: $DEST" >&2
  echo "install with: bash $0" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
install -m 0755 "$HOOK_SRC" "$DEST"
echo "installed: $DEST"
echo "the hook gates staged Markdown and shell files; bypass a check with: git commit --no-verify"
echo "re-run with --check after a branch update that changed the hook."