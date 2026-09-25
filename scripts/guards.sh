#!/usr/bin/env bash
# scripts/guards.sh
# Git workflow guard functions  --  validate repo state and clear stale locks.
# Sourced by host-side workflow files (apply, draft, confirm, reject).
#
# Requires lsof on the host: draft_clear_stale_lock uses it to tell a held
# .git/index.lock from a stale one.
#
# Provides:
#   validate_project_dir     --  check PROJECT_DIR exists, is git repo, has commits
#   draft_clear_stale_lock   --  remove stale .git/index.lock
#   require_clean_working_tree --  report whether the working tree is clean
#   clean_tree_hint          --  print the shared dirty-tree remedy
#   clean_tree_hint_unreadable --  print the remedy for an unreadable tree

# validate_project_dir PROJECT_DIR
#   Checks PROJECT_DIR exists, is a git repository, and has at least one commit.
#   Returns 1 with error message to stderr on failure.
validate_project_dir() {
  local PROJECT_DIR="$1"

  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: PROJECT_DIR does not exist: $PROJECT_DIR" >&2
    return 1
  fi

  if ! git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: $PROJECT_DIR is not a git repository" >&2
    return 1
  fi

  if ! git -C "$PROJECT_DIR" rev-parse HEAD >/dev/null 2>&1; then
    echo "Error: $PROJECT_DIR has no commits - cannot apply patch" >&2
    return 1
  fi
}

# require_clean_working_tree PROJECT_DIR
#   Returns 0 when the working tree is clean, 1 when it is dirty, and 2 when
#   git cannot read the tree. Prints nothing: the verdict is the return status
#   and the caller owns the message. An unreadable tree is not clean, and it is
#   not dirty either -- the caller must not tell the operator to stash changes
#   that do not exist (docs/development/bash-coding-conventions.md 3.2).
#   Dirty is a non-empty `status --porcelain`.
require_clean_working_tree() {
  local dir="$1" out
  if ! out=$(git -C "$dir" status --porcelain 2>/dev/null); then
    return 2
  fi
  [[ -z "$out" ]]
}

# clean_tree_hint
#   Prints the shared remedy lines for a dirty working tree. Callers print
#   their own first line (which names the operation), then call this.
clean_tree_hint() {
  echo "  Uncommitted or untracked changes are present." >&2
  echo "  Stash them (git stash) or commit them first." >&2
}

# clean_tree_hint_unreadable
#   Prints the remedy for a tree git cannot read. Distinct from the dirty hint:
#   telling the operator to stash changes that do not exist sends them after a
#   phantom.
clean_tree_hint_unreadable() {
  echo "  The repository state could not be read (corrupt or locked index)." >&2
  echo "  Check 'git status' in the project directory, then retry." >&2
}

# _lock_age LABEL_PATH
#   Prints a human age label for a lock file, or "unknown" when the host tools
#   are unavailable. Portable GNU/BSD stat.
_lock_age() {
  local f="$1" mtime now
  mtime=$(stat -c %Y "$f" 2>/dev/null) || mtime=$(stat -f %m "$f" 2>/dev/null) || { echo "unknown"; return; }
  now=$(date +%s 2>/dev/null) || { echo "unknown"; return; }
  echo "$(( now - mtime ))s"
}

# draft_clear_stale_lock PROJECT_DIR
#   Removes a stale .git/index.lock. A lock is stale only when no live process
#   holds it; the holder probe uses lsof. When lsof is unavailable the function
#   refuses, because removing a lock that is still held corrupts the index.
#   Returns 1 when a holder exists or the probe is unavailable, 0 when a lock
#   with no holder was removed.
draft_clear_stale_lock() {
  local PROJECT_DIR="$1"
  local LOCKFILE="$PROJECT_DIR/.git/index.lock"
  [[ -f "$LOCKFILE" ]] || return 0

  local lock_age
  lock_age="$(_lock_age "$LOCKFILE")"

  if ! command -v lsof >/dev/null 2>&1; then
    echo "Error: cannot tell whether .git/index.lock is held: lsof is not installed." >&2
    echo "  File: $LOCKFILE (age $lock_age)" >&2
    echo "  Install lsof, or remove the lock once no git process is running:" >&2
    echo "    rm -f '$LOCKFILE'" >&2
    return 1
  fi

  local HOLDER
  if HOLDER="$(lsof "$LOCKFILE" 2>/dev/null)"; then
    echo "Error: .git/index.lock is held by another process:" >&2
    printf '%s\n' "$HOLDER" | sed 's/^/  /' >&2
    echo "  File: $LOCKFILE (age $lock_age)" >&2
    echo "  Wait for the holder to finish, or remove the lock once no git process is running:" >&2
    echo "    rm -f '$LOCKFILE'" >&2
    return 1
  fi

  echo "Warning: removing stale .git/index.lock (age $lock_age, no holder)" >&2
  rm -f "$LOCKFILE"
}
