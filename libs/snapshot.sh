#!/usr/bin/env bash
# libs/snapshot.sh
# Snapshot pipeline functions — sourced by start_agent.sh (host side)
# and sandbox-entrypoint.sh (capability layer side).
#
# Host-side functions:
#   snapshot_copy_worktree    SOURCE_DIR  DEST_DIR   [primary — rsync-based]
#   snapshot_archive_head     SOURCE_DIR  DEST_DIR   [produces baseline.tar for container]
#   snapshot_enumerate_files  SOURCE_DIR             [deprecated — index-driven]
#   snapshot_copy_files       SOURCE_DIR  DEST_DIR   [deprecated — index-driven]
#   snapshot_validate         SNAPSHOT_DIR
#
# Container-side functions:
#   snapshot_copy_to_sandbox  SNAPSHOT_DIR  SANDBOX_DIR
#   snapshot_init_git         SANDBOX_DIR   SNAPSHOT_DIR

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
# snapshot_archive_head
# -------------------------
# Produces baseline.tar in DEST_DIR containing exactly the committed state
# at HEAD in SOURCE_DIR. No working tree changes, untracked files, or index
# state are included.
#
# This tar is consumed by snapshot_init_git inside the container to construct
# the baseline commit. Separating archive production (host, where PROJECT_DIR
# is available) from baseline commit creation (container) keeps all host-side
# git operations on the host side.
#
# Aborts if SOURCE_DIR has no commits (git archive requires at least one).
snapshot_archive_head() {
  local SOURCE_DIR="$1"
  local DEST_DIR="$2"

  if ! git -C "$SOURCE_DIR" rev-parse HEAD &>/dev/null; then
    echo "Error: SOURCE_DIR has no commits — git archive requires at least one commit." >&2
    echo "  Run: git -C '$SOURCE_DIR' commit --allow-empty -m 'initial'" >&2
    return 1
  fi

  mkdir -p "$DEST_DIR"
  git -C "$SOURCE_DIR" archive HEAD > "$DEST_DIR/baseline.tar" \
    || { echo "Error: git archive failed in $SOURCE_DIR" >&2; return 1; }
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

  if [[ ! -f "$SNAPSHOT_DIR/baseline.tar" ]]; then
    echo "Error: baseline.tar missing from snapshot: $SNAPSHOT_DIR" >&2
    echo "  snapshot_archive_head must run before snapshot_validate." >&2
    return 1
  fi
}

# -------------------------
# snapshot_copy_to_sandbox
# -------------------------
# Copies baseline.tar from SNAPSHOT_DIR into SANDBOX_DIR.
# Only baseline.tar is needed at this stage — snapshot_init_git unpacks it
# to form the baseline commit, then overlays the full working tree from
# SNAPSHOT_DIR in a second step. Copying the full working tree here would
# cause untracked and modified files to land in sandbox before the baseline
# commit is made, including them in the baseline commit.
# SANDBOX_DIR is created if it does not exist.
snapshot_copy_to_sandbox() {
  local SNAPSHOT_DIR="$1"
  local SANDBOX_DIR="$2"

  mkdir -p "$SANDBOX_DIR"
  cp "$SNAPSHOT_DIR/baseline.tar" "$SANDBOX_DIR/baseline.tar" \
    || { echo "Error: failed to copy baseline.tar from $SNAPSHOT_DIR" >&2; return 1; }
}

# -------------------------
# snapshot_init_git
# -------------------------
# Initialises a git repository in SANDBOX_DIR with the correct two-layer state:
#
#   Layer 1 — baseline commit: unpacked from SNAPSHOT_DIR/baseline.tar, which
#   contains exactly HEAD from PROJECT_DIR (produced by snapshot_archive_head
#   on the host). The baseline commit represents the committed state only —
#   no working tree changes, no untracked files.
#
#   Layer 2 — working tree overlay: SNAPSHOT_DIR (the rsync copy of the
#   operator's working tree) is overlaid onto SANDBOX_DIR with --delete.
#   The git index is NOT updated after this step.
#
# Result: the sandbox git index reflects HEAD; the sandbox working tree
# reflects the operator's current on-disk state. git status in the sandbox
# matches what the operator sees in PROJECT_DIR.
#
# Working tree states handled correctly:
#   Tracked, no changes          → clean
#   Tracked, unstaged edits      → M file (unstaged)
#   Tracked, staged edits        → M file (staged, shown as unstaged — see note)
#   Tracked, deleted (no git rm) → D file (unstaged)
#   Tracked, staged deletion     → D file (staged, shown as unstaged — see note)
#   Untracked, not gitignored    → ?? file
#   Untracked, gitignored        → not visible
#   New file, staged (git add)   → ?? file (shown as untracked — see note)
#
# Note on staged changes: the baseline commit is always HEAD. Staged changes
# in PROJECT_DIR (git add but not committed) are not part of HEAD, so the
# sandbox index does not reflect them. The on-disk content is correct (rsync
# copies the staged version), but the staging state is lost. The agent sees
# the file as modified-unstaged or untracked rather than staged. This is a
# known and documented limitation.
#
# Prints the baseline SHA to stdout.
# Exits non-zero if any step fails.
snapshot_init_git() {
  local SANDBOX_DIR="$1"
  local SNAPSHOT_DIR="$2"

  if [[ -z "$SANDBOX_DIR" ]]; then
    echo "Error: SANDBOX_DIR is required" >&2; return 1
  fi
  if [[ -z "$SNAPSHOT_DIR" ]]; then
    echo "Error: SNAPSHOT_DIR is required" >&2; return 1
  fi
  if [[ ! -f "$SNAPSHOT_DIR/baseline.tar" ]]; then
    echo "Error: baseline.tar not found in SNAPSHOT_DIR: $SNAPSHOT_DIR" >&2
    echo "  snapshot_archive_head must run on the host before the container starts." >&2
    return 1
  fi

  # --- Step 1: initialise repo and commit the HEAD state from baseline.tar ---
  git -C "$SANDBOX_DIR" init --quiet \
    || { echo "Error: git init failed in $SANDBOX_DIR" >&2; return 1; }

  git -C "$SANDBOX_DIR" config user.email "agent@sandbox"
  git -C "$SANDBOX_DIR" config user.name "agent-sandbox"
  git -C "$SANDBOX_DIR" config core.fileMode false

  # Unpack baseline.tar — contains exactly the committed state at HEAD.
  # This is the only content that belongs in the baseline commit.
  local ARCHIVE_TMP
  ARCHIVE_TMP=$(mktemp -d)
  tar -x -C "$ARCHIVE_TMP" < "$SNAPSHOT_DIR/baseline.tar" \
    || { echo "Error: failed to unpack baseline.tar" >&2; rm -rf "$ARCHIVE_TMP"; return 1; }
  cp -a "$ARCHIVE_TMP/." "$SANDBOX_DIR/" \
    || { echo "Error: failed to copy archive contents into sandbox" >&2; rm -rf "$ARCHIVE_TMP"; return 1; }
  rm -rf "$ARCHIVE_TMP"

  git -C "$SANDBOX_DIR" add -A \
    || { echo "Error: git add failed in $SANDBOX_DIR" >&2; return 1; }

  local staged
  staged=$(git -C "$SANDBOX_DIR" diff --cached --name-only | wc -l)
  echo "Staging $staged file(s) for baseline commit." >&2

  # --allow-empty ensures the baseline commit is created even for an empty repo.
  git -C "$SANDBOX_DIR" commit --allow-empty -m "agent-sandbox: baseline" --quiet \
    || { echo "Error: git commit failed in $SANDBOX_DIR" >&2; return 1; }

  local sha
  sha=$(git -C "$SANDBOX_DIR" rev-list --max-parents=0 HEAD) \
    || { echo "Error: could not retrieve baseline SHA" >&2; return 1; }

  # --- Step 2: overlay the working tree without touching the index ---
  # rsync copies the operator's working tree state (from SNAPSHOT_DIR, produced
  # by snapshot_copy_worktree on the host) over the sandbox. --delete ensures
  # files absent from the working tree (unstaged deletions) are also absent
  # from the sandbox working tree.
  #
  # The git index is not updated after this step. The index reflects HEAD
  # (the baseline commit). The working tree reflects the operator's on-disk
  # state. git status correctly shows the diff between the two.
  rsync -a --delete \
    --exclude='.git' \
    --exclude='baseline.tar' \
    "$SNAPSHOT_DIR/" "$SANDBOX_DIR/" \
    || { echo "Error: rsync overlay failed" >&2; return 1; }

  echo "$sha"
}
