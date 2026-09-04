#!/usr/bin/env bash
# libs/snapshot.sh
# Snapshot pipeline functions  --  sourced by start_agent.sh (host side),
# sandbox-entrypoint.sh (capability layer side), and seed_volume.sh (seeder).
#
# Functions:
#   snapshot_copy_worktree    SOURCE_DIR  DEST_DIR   [mount-delivery worktree materialization]
#   snapshot_check_case_mismatch SOURCE_DIR        [case-collision preflight; also used by seed_volume.sh]
#
# The copy-delivery seed is the helper-container transport in
# src/capability/seed_volume.sh (ADR docs/adr/sandbox_delivery_model.md,
# 2026-09-04 entry). The legacy docker cp machinery (snapshot_seed_tar,
# snapshot_init_git, snapshot_archive_head) was removed with it.

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
# Mount-delivery worktree materialization: copies the working tree from
# SOURCE_DIR into DEST_DIR as git enumerates it -- tracked files still on
# disk plus untracked non-ignored files, resolved by git's own ignore
# sources (local .gitignore, global core.excludesFile, .git/info/exclude,
# negation patterns included). The existence filter drops tracked paths
# absent from the disk (unstaged deletions), so the copy matches the
# operator's on-disk state by construction.
#
# rsync receives the enumerated list via --from0 --files-from. There is no
# --delete pass: materialization targets a fresh destination on a fresh mount
# (an existing worktree with .git is reused directly, never re-copied).
#
# Replaces the previous hand-built rsync exclude lists, which silently
# ignored negation patterns in global excludes (R1 leak; ADR
# sandbox_delivery_model.md, mount-path entry 2026-09-04).
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

  # --- Enumerate and copy ---
  mkdir -p "$DEST_DIR"
  git -C "$SOURCE_DIR" ls-files -z --cached --others --exclude-standard \
    | while IFS= read -r -d '' f; do
        if [[ -e "$SOURCE_DIR/$f" || -L "$SOURCE_DIR/$f" ]]; then printf '%s\0' "$f"; fi
      done \
    | rsync -a --from0 --files-from=- "$SOURCE_DIR/" "$DEST_DIR/" \
    || { echo "Error: worktree copy failed ($SOURCE_DIR -> $DEST_DIR)" >&2; return 1; }
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
