#!/usr/bin/env bash
# seed_volume.sh
# --------------
# Helper-container seed transport. Runs INSIDE the one-shot seeder service
# (sandbox image) with the operator project mounted read-only at /src and the
# session volume mounted at the sandbox service's own target path (see DEST
# below). Wire-up: run_agent.sh ->
# docker compose run --rm seeder.
#
# Contract: the shared delivery dispatcher (ADR sandbox_delivery_model.md,
# 2026-09-12 entry) transports both seed modes; the full-mode parity contract
# derives from the 2026-09-04 entry:
#   - git decides what crosses: tracked + untracked-non-ignored, resolved by
#     git's own ignore sources (negation patterns included)
#   - full seed: the repository crosses natively (cp -a .git); no reset runs,
#     so git status in the volume is porcelain-identical to the project,
#     staging state included
#   - flatten seed: no history crosses; the worktree is git-init'd as a fresh
#     baseline commit (no host history, no staging state)
#   - tracked paths deleted from disk are absent from the volume by
#     construction (existence filter), so deletions show in status
#   - the seed self-verifies: full -> git status --porcelain must match
#     /src vs /dest; flatten -> the baseline must hold every enumerated path
#   - every failure exits nonzero with a readable message; the host aborts
#     the start and discards the volume
#
# Edge cases (ADR edge-case table): linked worktrees, submodules, tracked
# sentinel, unborn HEAD (both modes -- the session-env gate requires commits
# for every session) fail closed below; empty worktrees no-op (an empty
# enumeration is a no-op for rsync, and the parity/baseline check still runs).
set -euo pipefail

SRC="${SEED_SRC:-/src}"
# The volume must be mounted at the sandbox service's own target path: a fresh
# empty named volume is initialized -- content and ownership -- from the image's
# directory at the mount point. That path is agentuser-owned in the image, so
# the unprivileged seeder can write; any other target leaves the volume root
# root-owned and cp fails with Permission denied (observed live, 20260904-05).
DEST="${SEED_DEST:-/home/agentuser/sandbox}"
# session_state.sh comes from the harness libs bind mount (compose sets both).
LIB_DIR="${SEED_LIB_DIR:-/opt/harness-libs}"
# FLATTEN is set by the seeder service environment from the session record.
# false/empty = full (native .git copy); true = flattened (git-init baseline).
FLATTEN="${SEED_FLATTEN:-false}"

die() { echo "Error: seed_volume: $*" >&2; exit 1; }

# _nul_streams_equal LEFT_FILE RIGHT_FILE MESSAGE
# Compares two NUL-delimited sorted streams held in files. On mismatch,
# prints MESSAGE to stderr, then a readable head-20 diff. Removes both files
# in all cases. Shared by verify_parity and verify_baseline.
_nul_streams_equal() {
  local lhs="$1" rhs="$2" msg="$3"
  if cmp -s "$lhs" "$rhs"; then
    rm -f "$lhs" "$rhs"
    return 0
  fi
  echo "Error: $msg" >&2
  diff <(tr '\0' '\n' < "$lhs" | sed '/^$/d') \
       <(tr '\0' '\n' < "$rhs" | sed '/^$/d') \
       | head -20 >&2 || true
  rm -f "$lhs" "$rhs"
  return 1
}

# verify_parity <src> <dest>
# Fail-closed seed verification: git status --porcelain must be identical.
# Compares sorted NUL streams with cmp (bash variables cannot hold NUL bytes,
# so the comparison must stay in files).
#
# Full seed only. A flattened seed inits a fresh baseline, so its worktree is
# clean by construction and status parity against the host has no meaning; it
# verifies the baseline instead (see verify_baseline).
verify_parity() {
  local src="$1" dest="$2"
  local s1 s2
  s1="$(mktemp /tmp/seed-status-src.XXXXXX)"
  s2="$(mktemp /tmp/seed-status-dest.XXXXXX)"
  git -C "$src" status --porcelain=v1 -uall -z | sort -z > "$s1"
  git -C "$dest" status --porcelain=v1 -uall -z | sort -z > "$s2"
  if ! _nul_streams_equal "$s1" "$s2" \
      "seed verification failed -- git status diverges between source and volume."; then
    return 1
  fi
}

# verify_baseline <src> <dest>
# Fail-closed flatten seed verification: the baseline commit must exist, the
# worktree must be clean, and the committed file set must equal the source
# enumeration. A flattened seed inits a fresh repo, so every enumerated path
# is committed in one baseline; status parity against the host has no meaning
# (no staging state crosses), but coverage is measured directly: exactly the
# enumerated set, nothing extra, nothing dropped.
verify_baseline() {
  local src="$1" dest="$2"
  if ! git -C "$dest" rev-parse HEAD >/dev/null 2>&1; then
    echo "Error: flatten seed produced no baseline commit in $dest" >&2
    return 1
  fi
  if [[ -n "$(git -C "$dest" status --porcelain)" ]]; then
    echo "Error: flatten seed verification failed -- the volume worktree is not clean." >&2
    return 1
  fi
  local s1 s2
  s1="$(mktemp /tmp/seed-baseline-src.XXXXXX)"
  s2="$(mktemp /tmp/seed-baseline-dest.XXXXXX)"
  snapshot_enumerate_worktree "$src" | sort -z > "$s1"
  git -C "$dest" ls-files -z | sort -z > "$s2"
  if ! _nul_streams_equal "$s1" "$s2" \
      "flatten seed verification failed -- the volume file set diverges from the source enumeration."; then
    return 1
  fi
}

main() {
  [[ -d "$SRC/.git" ]] || die "no git repository at $SRC -- is the project mounted?"

  # Linked worktree: /src/.git is a gitfile pointing at a host-side git
  # directory; copying it would produce a broken repository (ADR edge case).
  if [[ -f "$SRC/.git" ]]; then
    die "$SRC is a linked git worktree (its .git is a file). Seed the main working tree instead."
  fi

  # Unborn HEAD: no commits to carry or verify against (ADR edge case). The
  # harness session-env gate already requires commits for every session before
  # delivery dispatch; this guard is the delivery-layer statement of the same
  # invariant for direct invocation of the seeder.
  if ! git -C "$SRC" rev-parse HEAD >/dev/null 2>&1; then
    die "repository at $SRC has no commits. Make an initial commit before starting a session."
  fi

  # Submodules: the gitlink crosses but module content does not (ADR edge case).
  if git -C "$SRC" ls-files --stage | grep -q '^160000'; then
    die "submodules detected in $SRC. Not supported by the seed. Deinitialise them on the host: git -C '$SRC' submodule deinit --all"
  fi

  # Polluted legacy repo: a tracked sentinel is harness staging state captured
  # by a host commit (the 2026-09-03 incident). Refuse rather than seed it as
  # project content.
  if [[ -n "$(git -C "$SRC" ls-files -- .agent-sandbox-seed 2>/dev/null)" ]]; then
    die "$SRC tracks .agent-sandbox-seed/ -- harness staging state from a previous harness version. Remove it from the index on the host, commit the removal, then retry."
  fi

  # Case-collision preflight (non-blocking warnings; retained from the legacy
  # pipeline). snapshot.sh lives next to this script in the bind mount.
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck disable=SC1090,SC1091  # mount-point path by design
  source "$script_dir/snapshot.sh"
  snapshot_check_case_mismatch "$SRC"

  # Shared delivery dispatcher routes both modes through one primitive set:
  # full (default) copies .git natively then syncs the worktree; flatten syncs
  # the worktree then inits a fresh baseline. The mode-specific tails below
  # handle the cleanup responsibilities that genuinely diverge.
  snapshot_deliver "$SRC" "$DEST" "$FLATTEN" || die "seed delivery failed"

  # shellcheck disable=SC1091  # path is a mount point, resolved at runtime
  source "$LIB_DIR/session_state.sh"

  if [[ "$FLATTEN" == "true" ]]; then
    # SESSION_STATE: identity + the init reference for the diff pipeline.
    # init_sha is the baseline root commit -- the flat snapshot the session
    # started from.
    local init_sha
    init_sha="$(git -C "$DEST" rev-list --max-parents=0 HEAD)" \
      || die "reading the flatten baseline root commit failed"
    session_state_write_set "$DEST" "$init_sha"

    # Self-verification: the baseline must hold every enumerated path and
    # nothing extra, and the worktree must be clean.
    verify_baseline "$SRC" "$DEST" || die "the volume was not seeded correctly; the host will discard it"

    echo "Seed complete: flatten baseline in volume, $(git -C "$DEST" ls-files | wc -l) tracked files."
    return 0
  fi

  # Stash clear (ADR sandbox_delivery_model.md, 2026-09-11 entry): the native
  # .git copy carries the host stash stack (refs/stash, logs/refs/stash). The
  # sandbox baseline is the seeded HEAD, not host session state; an in-session
  # stash pop would import host WIP into the diff pipeline. The clear runs on
  # the volume copy only -- the host stack is untouched.
  git -C "$DEST" stash clear || die "clearing the host stash stack in the volume failed"

  # Object-store prune (study 20260911-study-seed_object_store_cleanliness.md,
  # ADR 2026-09-11 entry): the native .git copy carries unreachable host data
  # (stash objects, reflog-anchored history). The sandbox baseline is the
  # seeded HEAD -- no archaeology crosses. The prune runs only when the probe
  # finds something, so a clean host repo pays only the fsck probe.
  local unreachable
  unreachable="$(git -C "$DEST" fsck --unreachable 2>/dev/null)" \
    || die "probing the volume object store failed"
  if [[ -n "$unreachable" ]]; then
    git -C "$DEST" reflog expire --expire=now --all \
      || die "expiring the volume reflogs failed"
    git -C "$DEST" gc --prune=now --quiet \
      || die "pruning the volume object store failed"
  fi
  unreachable="$(git -C "$DEST" fsck --unreachable 2>/dev/null)" \
    || die "verifying the volume object store failed"
  if [[ -n "$unreachable" ]]; then
    die "the volume still carries unreachable objects after the prune"
  fi

  # SESSION_STATE: identity + the init reference for the diff pipeline.
  # init_sha is the HEAD the volume was seeded from.
  session_state_write_set "$DEST" "$(git -C "$SRC" rev-parse HEAD)"

  # Layer 3: self-verification. Any divergence aborts before a session
  # container exists.
  verify_parity "$SRC" "$DEST" || die "the volume was not seeded correctly; the host will discard it"

  # Tripwire: the stash clear must hold. Read failures die (they must not
  # read as an empty stack); a surviving entry fails the seed.
  local stash_list
  stash_list="$(git -C "$DEST" stash list 2>/dev/null)" \
    || die "reading the volume stash stack failed"
  if [[ -n "$stash_list" ]]; then
    die "the volume still carries stash entries after the stash clear"
  fi

  echo "Seed complete: $(git -C "$DEST" ls-files | wc -l) tracked files in volume, git status parity verified."
}

# Executed directly (default) or sourced by tests when SEED_VOLUME_NO_MAIN is set.
[[ -n "${SEED_VOLUME_NO_MAIN:-}" ]] || main "$@"
