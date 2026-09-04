#!/usr/bin/env bash
# seed_volume.sh
# --------------
# Helper-container seed transport. Runs INSIDE the one-shot seeder service
# (sandbox image) with the operator project mounted read-only at /src and the
# session volume mounted at the sandbox service's own target path (see DEST
# below). Wire-up: run_agent.sh ->
# docker compose run --rm seeder.
#
# Contract (ADR docs/adr/sandbox_delivery_model.md, 2026-09-04 entry):
#   - git decides what crosses: tracked + untracked-non-ignored, resolved by
#     git's own ignore sources (negation patterns included)
#   - the repository crosses natively (cp -a .git); no reset runs, so git
#     status in the volume is porcelain-identical to the project, staging
#     state included
#   - tracked paths deleted from disk are absent from the volume by
#     construction (existence filter), so deletions show in status
#   - the seed self-verifies: git status --porcelain must match /src vs /dest
#   - every failure exits nonzero with a readable message; the host aborts
#     the start and discards the volume
#
# Edge cases (ADR edge-case table): linked worktrees, unborn HEAD, empty
# worktrees, submodules, tracked sentinel -- each fails closed below.
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

die() { echo "Error: seed_volume: $*" >&2; exit 1; }

# enumerate <src>
# Git-enumerated, existence-filtered NUL-delimited file list of the working
# tree. The filter drops tracked paths absent from the disk (unstaged
# deletions); it cannot drop ignored content, because every filtered path was
# tracked. An `if` (not `&&`) keeps the loop's exit status 0 under pipefail
# when the last path is filtered out.
enumerate() {
  local src="$1"
  git -C "$src" ls-files -z --cached --others --exclude-standard \
    | while IFS= read -r -d '' f; do
        if [[ -e "$src/$f" || -L "$src/$f" ]]; then printf '%s\0' "$f"; fi
      done
}

# verify_parity <src> <dest>
# Fail-closed seed verification: git status --porcelain must be identical.
# Compares sorted NUL streams with cmp (bash variables cannot hold NUL bytes,
# so the comparison must stay in files).
verify_parity() {
  local src="$1" dest="$2"
  local s1 s2
  s1="$(mktemp /tmp/seed-status-src.XXXXXX)"
  s2="$(mktemp /tmp/seed-status-dest.XXXXXX)"
  git -C "$src" status --porcelain=v1 -uall -z | sort -z > "$s1"
  git -C "$dest" status --porcelain=v1 -uall -z | sort -z > "$s2"
  if ! cmp -s "$s1" "$s2"; then
    echo "Error: seed verification failed -- git status diverges between source and volume." >&2
    diff <(tr '\0' '\n' < "$s1" | sed '/^$/d') \
         <(tr '\0' '\n' < "$s2" | sed '/^$/d') \
         | head -20 >&2 || true
    rm -f "$s1" "$s2"
    return 1
  fi
  rm -f "$s1" "$s2"
}

main() {
  [[ -d "$SRC/.git" ]] || die "no git repository at $SRC -- is the project mounted?"

  # Linked worktree: /src/.git is a gitfile pointing at a host-side git
  # directory; copying it would produce a broken repository (ADR edge case).
  if [[ -f "$SRC/.git" ]]; then
    die "$SRC is a linked git worktree (its .git is a file). Seed the main working tree instead."
  fi

  # Unborn HEAD: no commits to carry or verify against (ADR edge case).
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

  # Layer 1: the repository crosses natively. The seeder runs as the host uid
  # (compose user), so volume ownership matches the sandbox service.
  cp -a "$SRC/.git" "$DEST/.git" || die "copying $SRC/.git into the volume failed"

  # Layer 2: worktree content. Empty enumeration -> skip tar (tar refuses an
  # empty archive; the volume needs nothing beyond .git in that case).
  local list count
  list="$(mktemp /tmp/seed-list.XXXXXX)"
  enumerate "$SRC" > "$list" || die "enumerating $SRC failed"
  count="$(tr -cd '\0' < "$list" | wc -c)"
  if (( count > 0 )); then
    tar -C "$SRC" --null -T "$list" -cf - | tar -C "$DEST" -xf - \
      || die "copying the working tree into the volume failed (tar pipeline)"
  fi
  rm -f "$list"

  # SESSION_STATE: identity + the init reference for the diff pipeline.
  # init_sha is the HEAD the volume was seeded from.
  # shellcheck disable=SC1091  # path is a mount point, resolved at runtime
  source "$LIB_DIR/session_state.sh"
  session_state_write "$DEST" "init_sha"      "$(git -C "$SRC" rev-parse HEAD)"
  session_state_write "$DEST" "session_ts"    "${SESSION_TS:-}"
  session_state_write "$DEST" "session_id"    "${SESSION_ID:-}"
  session_state_write "$DEST" "host_head_sha" "${HOST_HEAD_SHA:-}"

  # Layer 3: self-verification. Any divergence aborts before a session
  # container exists.
  verify_parity "$SRC" "$DEST" || die "the volume was not seeded correctly; the host will discard it"

  echo "Seed complete: $(git -C "$DEST" ls-files | wc -l) tracked files in volume, git status parity verified."
}

# Executed directly (default) or sourced by tests when SEED_VOLUME_NO_MAIN is set.
[[ -n "${SEED_VOLUME_NO_MAIN:-}" ]] || main "$@"
