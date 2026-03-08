#!/usr/bin/env bash
# container-entrypoint.sh
# Sandbox setup + diff staging + autosave

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

# -------------------------
# Copy project into sandbox
# -------------------------
# Uses git ls-files to enumerate files, so .gitignore is respected.
# Copies both tracked files (--cached) and untracked non-ignored files (--others).
# .workspace is excluded — it is the output channel, not agent input.
echo "Copying project files into sandbox..."

cd "$PROJECT_DIR"

git ls-files --cached --others --exclude-standard -z \
  | grep -zv '^\.workspace/' \
  | (cd "$PROJECT_DIR" && xargs -0 -r cp --parents -t "$SANDBOX_DIR/")

# -------------------------
# Initialise sandbox git repo
# -------------------------
# A local git repo in sandbox/ produces the patch.diff on exit.
# The initial commit records the baseline state before the agent runs.
cd "$SANDBOX_DIR"

git init --quiet
git config user.email "agent@sandbox"
git config user.name "agent-sandbox"
git config core.fileMode false

git add -A
git commit -m "agent-sandbox: baseline" --quiet

echo "Sandbox ready."

# -------------------------
# Copy brief into sandbox root
# -------------------------
if [[ -f "$WORKSPACE_DIR/brief.md" ]]; then
  cp -p "$WORKSPACE_DIR/brief.md" "$SANDBOX_DIR/brief.md"
fi

# -------------------------
# Diff staging function
# -------------------------
stage_diffs() {
  echo "Staging diffs..."

  cd "$SANDBOX_DIR"

  # Commit any uncommitted agent changes so they appear in the diff.
  if ! git diff --quiet || ! git diff --cached --quiet; then
    git add -A
    git commit -m "agent-sandbox: uncommitted changes on exit" --quiet || true
  fi

  BASELINE=$(git rev-list --max-parents=0 HEAD)

  if git diff --quiet "$BASELINE"..HEAD; then
    echo "No changes detected."
  else
    git diff "$BASELINE"..HEAD > "$CHANGES_DIR/patch.diff" || true
    echo "Diff written to .workspace/changes/patch.diff"
  fi
}

# Always stage diffs on exit
trap stage_diffs EXIT

# -------------------------
# Optional autosave
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