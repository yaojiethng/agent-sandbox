#!/usr/bin/env bash
# libs/snapshot.sh
# Snapshot pipeline functions — sourced by start_agent.sh (host side)
# and sandbox-entrypoint.sh (capability layer side).
#
# Host-side functions:
#   snapshot_enumerate_files  SOURCE_DIR
#   snapshot_copy_files       SOURCE_DIR  DEST_DIR
#   snapshot_validate         SNAPSHOT_DIR
#
# Container-side functions:
#   snapshot_copy_to_sandbox  SNAPSHOT_DIR  SANDBOX_DIR
#   snapshot_init_git         SANDBOX_DIR

# -------------------------
# snapshot_enumerate_files
# -------------------------
# Enumerates files in SOURCE_DIR using git ls-files.
# Respects .gitignore — gitignored files are excluded.
# Writes null-delimited file list to stdout.
# Emits a warning if no .gitignore is present.
# Aborts if submodules are detected — submodules are not supported.
snapshot_enumerate_files() {
  local SOURCE_DIR="$1"

  if [[ ! -f "$SOURCE_DIR/.gitignore" ]]; then
    echo "Warning: no .gitignore found in $SOURCE_DIR — all untracked files will be included in snapshot." >&2
  fi

  if git -C "$SOURCE_DIR" ls-files --stage | grep -q '^160000'; then
    echo "Error: submodules detected in $SOURCE_DIR." >&2
    echo "  Submodules are not supported by the snapshot pipeline." >&2
    echo "  Deinitialise submodules before running the harness:" >&2
    echo "    git -C '$SOURCE_DIR' submodule deinit --all" >&2
    return 1
  fi

  git -C "$SOURCE_DIR" ls-files --cached --others --exclude-standard -z
}

# -------------------------
# snapshot_copy_files
# -------------------------
# Reads null-delimited file list from stdin.
# Copies files from SOURCE_DIR into DEST_DIR preserving directory structure.
# Processes one file at a time so failures identify the offending path.
# Symlinks are skipped — they are untracked tooling, not project content.
snapshot_copy_files() {
  local SOURCE_DIR="$1"
  local DEST_DIR="$2"

  mkdir -p "$DEST_DIR"

  local file
  local failed=0
  while IFS= read -r -d '' file; do
    if [[ -L "$SOURCE_DIR/$file" ]]; then
      echo "Skipping symlink: $file" >&2
      continue
    fi
    if ! cp --parents -- "$file" "$DEST_DIR/" 2>/dev/null; then
      echo "Error: failed to copy: $file" >&2
      failed=1
    fi
  done

  if [[ "$failed" -eq 1 ]]; then
    echo "Error: snapshot copy failed — see above for offending paths." >&2
    return 1
  fi
}

# -------------------------
# snapshot_validate
# -------------------------
# Structural integrity check for a snapshot directory.
# Used as gate 1 (host, after copy) and gate 2 (capability layer, after mount).
# Exits non-zero with a message on any failure.
snapshot_validate() {
  local SNAPSHOT_DIR="$1"

  if [[ ! -d "$SNAPSHOT_DIR" ]]; then
    echo "Error: snapshot directory does not exist: $SNAPSHOT_DIR" >&2
    return 1
  fi

  if [[ -z "$(ls -A "$SNAPSHOT_DIR")" ]]; then
    echo "Error: snapshot directory is empty: $SNAPSHOT_DIR" >&2
    return 1
  fi
}

# -------------------------
# snapshot_copy_to_sandbox
# -------------------------
# Copies SNAPSHOT_DIR into SANDBOX_DIR (shared Docker volume, writable).
# SANDBOX_DIR is created if it does not exist.
snapshot_copy_to_sandbox() {
  local SNAPSHOT_DIR="$1"
  local SANDBOX_DIR="$2"

  mkdir -p "$SANDBOX_DIR"
  cp -a "$SNAPSHOT_DIR/." "$SANDBOX_DIR/"
}

# -------------------------
# snapshot_init_git
# -------------------------
# Initialises a git repository in SANDBOX_DIR and records a baseline commit.
# Prints the baseline SHA to stdout.
# Owns container readiness — exits non-zero if initialisation fails.
snapshot_init_git() {
  local SANDBOX_DIR="$1"

  cd "$SANDBOX_DIR" || { echo "Error: cannot cd into SANDBOX_DIR: $SANDBOX_DIR" >&2; return 1; }

  git init --quiet || { echo "Error: git init failed in $SANDBOX_DIR" >&2; return 1; }

  git config user.email "agent@sandbox"
  git config user.name "agent-sandbox"
  git config core.fileMode false

  git add -A || { echo "Error: git add failed in $SANDBOX_DIR" >&2; return 1; }

  local staged
  staged=$(git diff --cached --name-only | wc -l)
  echo "Staging $staged file(s) for baseline commit." >&2

  # --allow-empty ensures the baseline commit is always created even if the
  # working tree is clean.
  git commit --allow-empty -m "agent-sandbox: baseline" --quiet \
    || { echo "Error: git commit failed in $SANDBOX_DIR" >&2; return 1; }

  local sha
  sha=$(git rev-list --max-parents=0 HEAD) \
    || { echo "Error: could not retrieve baseline SHA in $SANDBOX_DIR" >&2; return 1; }

  echo "$sha"
}
