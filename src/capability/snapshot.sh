#!/usr/bin/env bash
# libs/snapshot.sh
# Snapshot pipeline functions  --  sourced by start_agent.sh (host side)
# and sandbox-entrypoint.sh (capability layer side).
#
# Host-side functions:
#   snapshot_seed_tar         SOURCE_DIR  OUT_TAR   [primary -- git-enumerated seed tar]
#   snapshot_copy_worktree    SOURCE_DIR  DEST_DIR   [rsync-based; mount delivery]
#   snapshot_archive_head     SOURCE_DIR  DEST_DIR   [produces baseline.tar for container]
#
# Container-side functions:
#   snapshot_init_git         SANDBOX_DIR   SEED_DIR   [SEED_DIR carries baseline.tar + worktree/]

# -------------------------
# filesystem_tracks_exec_bits
# -------------------------
# Returns 0 if the current filesystem reliably persists the executable bit
# (native Linux/macOS), 1 if not (Windows/macOS Docker Desktop, some 9p and
# network mounts). Used to decide core.fileMode so exec bits are tracked where
# they are real (Linux container) and ignored where they are unreliable.
filesystem_tracks_exec_bits() {
  local probe_dir probe mode
  probe_dir="$(mktemp -d 2>/dev/null)" || return 1
  probe="$probe_dir/.mode-probe"
  : > "$probe"
  chmod 700 "$probe" 2>/dev/null
  mode="$(stat -c %a "$probe" 2>/dev/null || stat -f %Lp "$probe" 2>/dev/null || echo "")"
  rm -rf "$probe_dir"
  # Octal owner perms, e.g. 700; bit 0 of the first digit is owner-exec.
  [[ -n "$mode" && $(( 0${mode:0:1} & 1 )) -eq 1 ]]
}

# -------------------------
# snapshot_copy_worktree
# -------------------------
# Copies the working tree from SOURCE_DIR into DEST_DIR using rsync.
# Enumerates from the filesystem directly  --  not from the git index.
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
    EXCLUDE_TMPFILE=$(mktemp /tmp/snapshot-exclude.XXXXXX)
    # Expansion now is intentional: EXCLUDE_TMPFILE is local to this
    # function, so it must be baked into the trap body before return.
    # shellcheck disable=SC2064
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
    # Dry-run A: local .gitignore rules only  --  what rsync would copy without global rules
    local LIST_A
    LIST_A=$("${BASE_ARGS[@]}" --dry-run --list-only "$SOURCE_DIR/" /dev/null 2>/dev/null \
      | awk '{print $NF}' | sort)

    # Dry-run B: all rules  --  what rsync will actually copy
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
    echo "Error: SOURCE_DIR has no commits  --  git archive requires at least one commit." >&2
    echo "  Run: git -C '$SOURCE_DIR' commit --allow-empty -m 'initial'" >&2
    return 1
  fi

  mkdir -p "$DEST_DIR"
  snapshot_check_case_mismatch "$SOURCE_DIR"
  git -C "$SOURCE_DIR" archive HEAD > "$DEST_DIR/baseline.tar" \
    || { echo "Error: git archive failed in $SOURCE_DIR" >&2; return 1; }
}

# -------------------------
# snapshot_check_case_mismatch SOURCE_DIR
# -------------------------
# Detects tracked files whose git tree-object name differs from the filesystem
# name in case only. Common on case-insensitive hosts (Windows, macOS) that
# run case-sensitive Linux containers: git mv on a case-insensitive FS does
# not update the tree object, so git archive (which reads the tree) produces
# the old case, while rsync (which reads the filesystem) copies the new case.
#
# Compares every path from `git ls-tree -r HEAD --name-only` against the
# filesystem. If a filesystem entry exists with a case-different name and the
# git blob hash matches, it is a case mismatch.
#
# Writes warnings to stderr. Returns 0 always (non-blocking).
# For the host-side fix, run: git mv <old> <tmp> && git mv <tmp> <new> && git commit
snapshot_check_case_mismatch() {
  local SOURCE_DIR="$1"

  if [[ ! -d "$SOURCE_DIR" ]]; then
    return 0
  fi

  local -a MISMATCHES=()
  local tree_path

  while IFS= read -r tree_path; do
    [[ -z "$tree_path" ]] && continue

    local dir fs_entry
    dir=$(dirname "$tree_path")
    # Find the actual filesystem entry for this directory+basename, case-insensitively
    fs_entry=$(find "$SOURCE_DIR/$dir" -maxdepth 1 -iname "$(basename "$tree_path")" -printf '%f\n' 2>/dev/null | head -1)

    [[ -z "$fs_entry" ]] && continue  # file not on disk

    local tree_basename
    tree_basename=$(basename "$tree_path")

    # Same name -> no mismatch
    [[ "$fs_entry" == "$tree_basename" ]] && continue

    # Different case -> check if blob matches
    local tree_blob fs_blob
    tree_blob=$(git -C "$SOURCE_DIR" ls-tree HEAD -- "$tree_path" | awk '{print $3}') 2>/dev/null
    fs_blob=$(git -C "$SOURCE_DIR" hash-object "$SOURCE_DIR/$dir/$fs_entry") 2>/dev/null

    if [[ -n "$tree_blob" && "$tree_blob" == "$fs_blob" ]]; then
      MISMATCHES+=("$tree_path -> $dir/$fs_entry (same blob $tree_blob)")
    fi
  done < <(git -C "$SOURCE_DIR" ls-tree -r HEAD --name-only 2>/dev/null)

  if [[ "${#MISMATCHES[@]}" -gt 0 ]]; then
    echo "[snapshot] WARNING: case mismatch detected between git tree and filesystem:" >&2
    for m in "${MISMATCHES[@]}"; do
      echo "[snapshot]   $m" >&2
    done
    echo "[snapshot]   These files have the same content but different casing." >&2
    echo "[snapshot]   The git tree object has the OLD case (from git archive)." >&2
    echo "[snapshot]   The filesystem has the NEW case (from rsync, visible in the sandbox)." >&2
    echo "[snapshot]   This is caused by git mv on a case-insensitive filesystem." >&2
    echo "[snapshot]   To fix on the host, rename through an intermediate name:" >&2
    for m in "${MISMATCHES[@]}"; do
      local oldpath newpath
      oldpath=$(echo "$m" | awk '{print $1}')
      newpath=$(echo "$m" | awk '{print $3}')
      echo "[snapshot]     git mv $oldpath ${oldpath}.tmp && git mv ${oldpath}.tmp $newpath && git commit" >&2
    done
  fi

  return 0
}

# -------------------------
# snapshot_seed_tar
# -------------------------
# Builds the copy-delivery seed tar from SOURCE_DIR (the operator's project):
#
#   worktree/      the operator's working tree as git enumerates it: tracked
#                  files still on disk (from the index) plus untracked
#                  non-ignored files (`git ls-files --others
#                  --exclude-standard`). Deleted-from-worktree tracked files
#                  are absent by construction. All ignore sources (local
#                  .gitignore, global core.excludesFile, .git/info/exclude)
#                  are honored by git's own rules -- including negation
#                  patterns, which rsync-based exclusion mishandled.
#                  Members are packed under a worktree/ prefix.
#   baseline.tar   exactly HEAD (`git archive`), consumed by snapshot_init_git
#                  to build the baseline commit (index = HEAD).
#
# The tar is extracted directly into the sandbox volume root. Its members
# are git-ignored by snapshot_init_git for the duration of init and removed
# after the overlay, so only project content remains.
#
# GNU tar's --transform rewrites symlink targets as well as member names;
# since the worktree/ member prefix requires a transform, the pack uses the
# unique sentinel prefix .agent-sandbox-seed/ and snapshot_init_git repairs
# symlink targets by stripping that prefix after the overlay (a project
# path can never collide with the sentinel).
#
# Edge cases: symlinks, exec bits, and binary content are carried by tar.
# Empty directories are not carried (git cannot represent them; accepted
# behavior change vs the rsync pipeline). Submodules are rejected. Known
# rsync-era limitation resolved: negation patterns in global/exclude files.
#
# Known limitation (inherited from the rsync pipeline): staged-but-uncommitted
# index state is not carried -- the sandbox index always reflects HEAD.
#
# Prints progress to stderr. Exits non-zero on any failure.
snapshot_seed_tar() {
  local SOURCE_DIR="$1"
  local OUT_TAR="$2"

  if [[ -z "$SOURCE_DIR" || -z "$OUT_TAR" ]]; then
    echo "Error: snapshot_seed_tar requires SOURCE_DIR and OUT_TAR" >&2; return 1
  fi

  # Submodules are not supported by the seed pipeline (same as the rsync path).
  if git -C "$SOURCE_DIR" ls-files --stage | grep -q '^160000'; then
    echo "Error: submodules detected in $SOURCE_DIR." >&2
    echo "  Submodules are not supported by the snapshot pipeline." >&2
    echo "  Deinitialise submodules before running the harness:" >&2
    echo "    git -C '$SOURCE_DIR' submodule deinit --all" >&2
    return 1
  fi

  if ! git -C "$SOURCE_DIR" rev-parse HEAD &>/dev/null; then
    echo "Error: SOURCE_DIR has no commits  --  the seed tar requires HEAD." >&2
    echo "  Run: git -C '$SOURCE_DIR' commit --allow-empty -m 'initial'" >&2
    return 1
  fi

  snapshot_check_case_mismatch "$SOURCE_DIR"

  # Component 1: baseline.tar (committed state at HEAD).
  local tmpdir
  tmpdir=$(mktemp -d) || { echo "Error: mktemp failed" >&2; return 1; }
  if ! git -C "$SOURCE_DIR" archive HEAD > "$tmpdir/baseline.tar" 2>/dev/null; then
    echo "Error: git archive failed in $SOURCE_DIR" >&2
    rm -rf "$tmpdir"
    return 1
  fi

  # Component 2: worktree/ -- git-enumerated file list packed under the
  # .agent-sandbox-seed/ sentinel prefix (see the function header for why a
  # transform is required and how symlink targets are repaired).
  local list_z="$tmpdir/seed-list.z"
  (
    { git -C "$SOURCE_DIR" ls-files --cached -z; git -C "$SOURCE_DIR" ls-files --others --exclude-standard -z; } \
      | while IFS= read -r -d '' f; do [[ -e "$SOURCE_DIR/$f" || -L "$SOURCE_DIR/$f" ]] && printf '%s\0' "$f"; done
  ) | sort -z > "$list_z"

  if ! tar -C "$SOURCE_DIR" --null -T "$list_z" --transform "s|^|.agent-sandbox-seed/worktree/|" -cf "$OUT_TAR"; then
    echo "Error: seed tar (worktree) failed for $SOURCE_DIR" >&2
    rm -rf "$tmpdir"
    return 1
  fi
  if ! tar -rf "$OUT_TAR" --transform "s|^|.agent-sandbox-seed/|" -C "$tmpdir" baseline.tar; then
    echo "Error: seed tar (baseline append) failed for $SOURCE_DIR" >&2
    rm -rf "$tmpdir"
    return 1
  fi

  rm -rf "$tmpdir"
  echo "[snapshot] seed tar ready: $(tar -tf "$OUT_TAR" | wc -l) member(s)" >&2
}

# -------------------------
# snapshot_init_git
# -------------------------
# Initialises a git repository in SANDBOX_DIR with the correct two-layer state:
#
#   Layer 1  --  baseline commit: unpacked from SEED_DIR/baseline.tar, which
#   contains exactly HEAD from PROJECT_DIR (produced by snapshot_seed_tar on
#   the host). The baseline commit represents the committed state only  -- 
#   no working tree changes, no untracked files.
#
#   Layer 2  --  working tree overlay: SEED_DIR/worktree/ (the git-enumerated
#   copy of the operator's working tree) is overlaid onto SANDBOX_DIR with
#   --delete. The git index is NOT updated after this step.
#
# SEED_DIR is the directory the seed tar was extracted into. For copy
# delivery the seed tar lands at $SANDBOX_DIR/.seed inside the sandbox
# volume (the tar carries the .agent-sandbox-seed/ prefix), so the caller
# passes SEED_DIR = $SANDBOX_DIR/.agent-sandbox-seed. The seed members are
# registered in .git/info/exclude before the baseline staging so they never
# enter the index, and are removed after the overlay (the exclude line with
# them).
#
# Result: the sandbox git index reflects HEAD; the sandbox working tree
# reflects the operator's current on-disk state. git status in the sandbox
# matches what the operator sees in PROJECT_DIR.
#
# Working tree states handled correctly:
#   Tracked, no changes          -> clean
#   Tracked, unstaged edits      -> M file (unstaged)
#   Tracked, staged edits        -> M file (staged, shown as unstaged  --  see note)
#   Tracked, deleted (no git rm) -> D file (unstaged)
#   Tracked, staged deletion     -> D file (staged, shown as unstaged  --  see note)
#   Untracked, not gitignored    -> ?? file
#   Untracked, gitignored        -> not visible
#   New file, staged (git add)   -> ?? file (shown as untracked  --  see note)
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
  local SEED_DIR="$2"

  if [[ -z "$SANDBOX_DIR" ]]; then
    echo "Error: SANDBOX_DIR is required" >&2; return 1
  fi
  if [[ -z "$SEED_DIR" ]]; then
    echo "Error: SEED_DIR is required" >&2; return 1
  fi
  if [[ ! -f "$SEED_DIR/baseline.tar" ]]; then
    echo "Error: seed content missing in $SEED_DIR: baseline.tar not found" >&2
    echo "  The sandbox volume must be seeded (snapshot_seed_tar + docker cp) before init." >&2
    return 1
  fi

  # --- Step 1: initialise repo and commit the HEAD state from baseline.tar ---
  git -C "$SANDBOX_DIR" init --quiet \
    || { echo "Error: git init failed in $SANDBOX_DIR" >&2; return 1; }

  git -C "$SANDBOX_DIR" config user.email "agent@sandbox"
  git -C "$SANDBOX_DIR" config user.name "agent-sandbox"
  # Track exec bits only where the filesystem preserves them. In the Linux
  # container they are real, so an agent-made `chmod +x` is captured in the
  # exported diff ("changes start with correct bits"); on filesystems that do
  # not reliably persist exec bits, tracking would only produce spurious
  # mode-only churn, so it is disabled. See filesystem_tracks_exec_bits.
  #
  # KNOWN ISSUE (windows-style filesystems): on filesystems that cannot reliably
  # persist exec bits (Windows/macOS Docker Desktop, some 9p/network mounts),
  # core.fileMode is false here and a fresh checkout will NOT carry +x on
  # executables. If you return here because exec bits are missing after a
  # checkout: the fs does not store them -- do not force fileMode=true; instead
  # re-assert the one-time modes with `chmod +x` + `git update-index
  # --chmod=+x` on the shebang scripts and test/stubs/docker (the "track harness
  # script exec bits" chore), and prefer `chmod +x` at point of use (Dockerfiles)
  # over relying on tracked/checkout modes.
  if filesystem_tracks_exec_bits; then
    git -C "$SANDBOX_DIR" config core.fileMode true
  else
    git -C "$SANDBOX_DIR" config core.fileMode false
  fi

  # Unpack baseline.tar  --  contains exactly the committed state at HEAD.
  # This is the only content that belongs in the baseline commit.
  # Extract baseline.tar directly into the sandbox directory.
  # baseline.tar is produced by `git archive HEAD`  --  it contains working tree
  # files only (no .git/). Safe to extract on top of the git init skeleton.
  # Previously this used an intermediate mktemp directory + cp -a, which
  # failed when TMPDIR resolved to /opt/provider-config/ inside the
  # container, because cp -a preserved read-only git object permissions.
  tar -x -C "$SANDBOX_DIR" < "$SEED_DIR/baseline.tar" \
    || { echo "Error: failed to unpack baseline.tar into sandbox" >&2; return 1; }

  # The seed members live inside the sandbox volume during init; keep them
  # out of the index. The exclude line is removed after the overlay so the
  # session's git status is not filtered by init-time artifacts.
  printf '/.agent-sandbox-seed\n' >> "$SANDBOX_DIR/.git/info/exclude"

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

  # Write init_sha, session_ts, and host_head_sha to .git/SESSION_STATE for future diff packaging
  session_state_write "$SANDBOX_DIR" "init_sha" "$sha"
  session_state_write "$SANDBOX_DIR" "session_ts" "${SESSION_TS:-}"
  session_state_write "$SANDBOX_DIR" "host_head_sha" "${HOST_HEAD_SHA:-}"
  session_state_write "$SANDBOX_DIR" "session_id" "${SESSION_ID:-}"

  # --- Step 2: overlay the working tree without touching the index ---
  # SEED_DIR/worktree/ is the git-enumerated copy of the operator's working
  # tree (from the seed tar). --delete ensures files absent from the working
  # tree (unstaged deletions) are also absent from the sandbox working tree.
  # The seed members themselves are excluded from the overlay and removed
  # afterwards so only project content remains in the sandbox.
  #
  # The git index is not updated after this step. The index reflects HEAD
  # (the baseline commit). The working tree reflects the operator's on-disk
  # state. git status correctly shows the diff between the two.
  mkdir -p "$SEED_DIR/worktree"
  rsync -a --delete \
    --exclude='.git' \
    --exclude='/.agent-sandbox-seed' \
    "$SEED_DIR/worktree/" "$SANDBOX_DIR/" \
    || { echo "Error: rsync overlay failed" >&2; return 1; }

  # Repair symlink targets: the pack-time --transform rewrote every symlink
  # target with the .agent-sandbox-seed/worktree/ prefix; strip it back.
  # The sentinel cannot collide with project content.
  while IFS= read -r -d '' link; do
    local tgt
    tgt=$(readlink "$link")
    if [[ "$tgt" == ".agent-sandbox-seed/worktree/"* ]]; then
      ln -sfn "${tgt#.agent-sandbox-seed/worktree/}" "$link"
    fi
  done < <(find "$SANDBOX_DIR" -path "$SANDBOX_DIR/.git" -prune -o -path "$SANDBOX_DIR/.agent-sandbox-seed" -prune -o -type l -print0)

  rm -rf "$SEED_DIR"
  sed -i '/^\/.agent-sandbox-seed$/d' "$SANDBOX_DIR/.git/info/exclude"

  snapshot_check_case_mismatch "$SANDBOX_DIR"

  echo "$sha"
}
