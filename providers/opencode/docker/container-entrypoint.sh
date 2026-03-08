#!/usr/bin/env bash
# container-entrypoint.sh
# Sandbox + Git staging + autosave

set -euo pipefail

shopt -s nullglob

# Redirect all entrypoint output to stderr so it doesn't pollute the TUI.
# View with: docker logs <container_name>
exec 1>&2

ROOT="/home/agentuser"

PROJECT_DIR="$ROOT/project"
SANDBOX_DIR="$ROOT/sandbox"
WORKSPACE_DIR="$PROJECT_DIR/.workspace"
CHANGES_DIR="$WORKSPACE_DIR/changes"

AUTOSAVE_INTERVAL="${AUTOSAVE_INTERVAL:-60}"  # 0 disables

mkdir -p "$CHANGES_DIR"

BUNDLE_FILE="$WORKSPACE_DIR/repo.bundle"

# -------------------------
# Clone from bundle
# -------------------------
if [[ ! -f "$BUNDLE_FILE" ]]; then
  echo "Error: repo.bundle not found in .workspace — was start_agent.sh run correctly?"
  exit 1
fi

echo "Cloning from bundle..."
git clone --quiet "$BUNDLE_FILE" "$SANDBOX_DIR"

cd "$SANDBOX_DIR"

git config user.email "agent@sandbox"
git config user.name "agent-sandbox"
git config core.fileMode false

# -------------------------
# Record bundle root hash
# -------------------------
# The bundle contains 1 commit (clean HEAD) or 2 commits (HEAD + temp snapshot).
# In both cases the bundle root is the oldest commit — this is the common
# ancestor used for diffing at exit.
BUNDLE_ROOT=$(git rev-list --max-parents=0 HEAD)
echo "Bundle root: $BUNDLE_ROOT"

# -------------------------
# Reset to expose uncommitted changes
# -------------------------
# If the bundle has 2 commits, the tip is the temp snapshot commit.
# Reset HEAD~1 so the agent sees the original working tree state:
# bundle root (patch C) as HEAD + uncommitted changes as dirty working tree.
COMMIT_COUNT=$(git rev-list --count HEAD)
if [[ "$COMMIT_COUNT" -gt 1 ]]; then
  echo "Resetting temp snapshot commit to restore working tree state..."
  git reset HEAD~1 --mixed --quiet
fi

# -------------------------
# Remove gitignored files
# -------------------------
# The bundle captured everything including files that would normally be
# gitignored (e.g. .env). Remove them so the agent cannot read secrets.
git clean -fdX --quiet
echo "Gitignored files removed from sandbox."

# -------------------------
# Copy brief into sandbox root
# -------------------------
if [[ -f "$WORKSPACE_DIR/brief.md" ]]; then
  cp -p "$WORKSPACE_DIR/brief.md" "$SANDBOX_DIR/brief.md"
fi

# -------------------------
# Checkout working branch
# -------------------------
# Branch name is 'development'. Parameterisation for multi-agent workflows
# is deferred to M4.
git checkout -b development --quiet
echo "Checked out branch: development"

# -------------------------
# Diff Staging Function
# -------------------------
stage_diffs() {
  echo "Staging diffs..."

  cd "$SANDBOX_DIR"

  # Commit any uncommitted agent changes so they appear in the diff.
  if ! git diff --quiet || ! git diff --cached --quiet; then
    git add -A
    git commit -m "agent-sandbox: uncommitted changes on exit" --quiet || true
  fi

  if git diff --quiet "$BUNDLE_ROOT"..HEAD; then
    echo "No changes detected."
  else
    git diff "$BUNDLE_ROOT"..HEAD > "$CHANGES_DIR/patch.diff" || true
    echo "Diff written to .workspace/changes/patch.diff"
  fi
}

# Always stage diffs on exit
trap stage_diffs EXIT

# -------------------------
# Optional Autosave
# -------------------------
if [[ "$AUTOSAVE_INTERVAL" -gt 0 ]]; then
  (
    while true; do
      sleep "$AUTOSAVE_INTERVAL"
      stage_diffs
    done
  ) &
fi

# -------------------------
# Execute OpenCode
# -------------------------
# Run without exec so the EXIT trap fires in this shell when OpenCode exits.
"$@"
