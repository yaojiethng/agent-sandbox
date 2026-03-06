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

mkdir -p "$SANDBOX_DIR" "$CHANGES_DIR"

# -------------------------
# Copy project/ into sandbox/
# Copies all mounted content except .workspace (already rw, no copy needed)
# -------------------------

# Subdirectories
for ITEM in "$PROJECT_DIR"/*/; do
  NAME="$(basename "$ITEM")"
  [[ "$NAME" == ".workspace" ]] && continue
  cp -r "$ITEM" "$SANDBOX_DIR/$NAME"
done

# Root-level files
for ITEM in "$PROJECT_DIR"/*; do
  [[ -f "$ITEM" ]] || continue
  cp "$ITEM" "$SANDBOX_DIR/$(basename "$ITEM")"
done

# Copy brief into sandbox root so the agent can read it from its working directory
if [[ -f "$PROJECT_DIR/.workspace/brief.md" ]]; then
  cp "$PROJECT_DIR/.workspace/brief.md" "$SANDBOX_DIR/brief.md"
fi

# -------------------------
# Git Init
# -------------------------
cd "$SANDBOX_DIR"

if [[ ! -d ".git" ]]; then
  git init -b development >/dev/null 2>&1

  # Commit the initial sandbox state as the baseline.
  # git diff --cached compares against HEAD — without this commit, HEAD
  # does not exist and the diff is always empty.
  git config user.email "agent@sandbox" >/dev/null
  git config user.name "agent-sandbox" >/dev/null
  git add -A
  git commit -m "sandbox: initial state" --quiet

  git checkout -b agent_branch --quiet
fi

# -------------------------
# Diff Staging Function
# -------------------------
stage_diffs() {
  echo "Staging diffs..."

  cd "$SANDBOX_DIR"
  git add -A || true

  if ! git diff --cached --quiet; then
    git diff --cached > "$CHANGES_DIR/patch.diff" || true
    echo "Diff written to .workspace/changes/patch.diff"
  else
    echo "No changes detected."
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
