#!/usr/bin/env bash
# libs/snapshot.sh
# Snapshot pipeline functions — sourced by start_agent.sh (host side)
# and sandbox-entrypoint.sh (capability layer side).
#
# Host-side functions:
#   snapshot_copy_worktree    SOURCE_DIR  DEST_DIR   [primary — rsync-based]
#   snapshot_enumerate_files  SOURCE_DIR             [deprecated — index-driven]
#   snapshot_copy_files       SOURCE_DIR  DEST_DIR   [deprecated — index-driven]
#   snapshot_validate         SNAPSHOT_DIR
#
# Container-side functions:
#   snapshot_copy_to_sandbox  SNAPSHOT_DIR  SANDBOX_DIR
#   snapshot_init_git         SANDBOX_DIR

# -------------------------
# snapshot_copy_worktree
# -------------------------
# Copies the working tree from SOURCE_DIR into DEST_DIR using rsync.
# Enumerates from the filesystem directly — not from the git index.
# Handles unstaged deletions, moves, and new files correctly by construction.
#
# Exclude sources applied (in addition to per-directory .gitignore files):
#   - Global gitignore: resolved via `git config core.excludesFile`
#   - Repo-level excludes: SOURCE_DIR/.git/info/exclude
#
# Files excluded by global/exclude rules but not by any local .gitignore
# are reported as warnings to stderr so the operator is aware.
#
# Residual limitation: negation patterns (`!foo`) in global gitignore or
# .git/info/exclude are not supported by rsync --exclude-from and are
# silently ignored. Negations in local .gitignore files work correctly.
snap_copy_worktree_cleanup() {
  local tmpfile="$1"
  [[ -n "$tmpfile" && -f "$tmpfile" ]] && rm -f "$tmpfile"
}

snapshot_copy_worktree() {
  local SOURCE_DIR="$1"
  local DEST_DIR="$2"

  # --- Pre-flight: submodule check ---
  if git -C "$SOURCE_DIR" ls-files --stage | grep -q '^160000'; then
    echo "Error: submodules detected in $SOURCE_DIR." >&2
    echo "  Submodules are not supported by the snapshot pipeline." >&2
    echo "  Deinitialise submodules before running the harness:" >&2
    echo "    git -C '$SOURCE_DIR' submodule deinit --all" >&2
    return 1
  fi

  # --- Resolve global exclude sources ---
  local GLOBAL_IGNORE
  GLOBAL_IGNORE=$(git -C "$SOURCE_DIR" config --global core.excludesFile 2>/dev/null || true)
  # Expand leading ~ manually (eval is safe here; value comes from git config)
  if [[ "$GLOBAL_IGNORE" == ~* ]]; then
    GLOBAL_IGNORE="${HOME}${GLOBAL_IGNORE:1}"
  fi

  local REPO_EXCLUDE="$SOURCE_DIR/.git/info/exclude"

  # Build combined exclude temp file if any global source exists
  local EXCLUDE_TMPFILE=""
  local has_global=0

  if [[ -n "$GLOBAL_IGNORE" && -f "$GLOBAL_IGNORE" ]]; then
    has_global=1
  fi
  local has_repo_exclude=0
  if [[ -f "$REPO_EXCLUDE" ]]; then
    has_repo_exclude=1
  fi

  if [[ "$has_global" -eq 1 || "$has_repo_exclude" -eq 1 ]]; then
    EXCLUDE_TMPFILE=$(mktemp)
    trap "snap_copy_worktree_cleanup '$EXCLUDE_TMPFILE'" EXIT

    if [[ "$has_global" -eq 1 ]]; then
      cat "$GLOBAL_IGNORE" >> "$EXCLUDE_TMPFILE"
    fi
    if [[ "$has_repo_exclude" -eq 1 ]]; then
      # Blank line separator between sources
      echo "" >> "$EXCLUDE_TMPFILE"
      cat "$REPO_EXCLUDE" >> "$EXCLUDE_TMPFILE"
    fi
  fi

  # --- Build rsync argument arrays ---
  local BASE_ARGS=(
    rsync -a
    --filter=':- .gitignore'
    --exclude='.git'
  )

  local FULL_ARGS=("${BASE_ARGS[@]}")
  if [[ -n "$EXCLUDE_TMPFILE" ]]; then
    FULL_ARGS+=("--exclude-from=$EXCLUDE_TMPFILE")
  fi

  # --- Warning pass: detect files excluded by global/exclude rules only ---
  if [[ -n "$EXCLUDE_TMPFILE" ]]; then
    # Dry-run A: local .gitignore rules only — what rsync would copy without global rules
    local LIST_A
    LIST_A=$("${BASE_ARGS[@]}" --dry-run --list-only "$SOURCE_DIR/" /dev/null 2>/dev/null \
      | awk '{print $NF}' | sort)

    # Dry-run B: all rules — what rsync will actually copy
    local LIST_B
    LIST_B=$("${FULL_ARGS[@]}" --dry-run --list-only "$SOURCE_DIR/" /dev/null 2>/dev/null \
      | awk '{print $NF}' | sort)

    # Files in A but not B were excluded solely by global/exclude rules
    local GLOBALLY_EXCLUDED
    GLOBALLY_EXCLUDED=$(comm -23 <(echo "$LIST_A") <(echo "$LIST_B") || true)

    if [[ -n "$GLOBALLY_EXCLUDED" ]]; then
      while IFS= read -r filepath; do
        echo "[snapshot] WARNING: $filepath excluded by global gitignore or .git/info/exclude" >&2
      done <<< "$GLOBALLY_EXCLUDED"
    fi
  fi

  # --- Real copy ---
  mkdir -p "$DEST_DIR"
  "${FULL_ARGS[@]}" "$SOURCE_DIR/" "$DEST_DIR/"

  # Cleanup temp file
  snap_copy_worktree_cleanup "$EXCLUDE_TMPFILE"
  trap - EXIT
}

# -------------------------
# snapshot_enumerate_files  [DEPRECATED]
# -------------------------
# Replaced by snapshot_copy_worktree. Retained for reference only.
# Index-driven enumeration fails on unstaged deletions and moves.
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
    mkdir -p "$DEST_DIR/$(dirname "$file")"
    if ! cp -- "$SOURCE_DIR/$file" "$DEST_DIR/$file" 2>/dev/null; then
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