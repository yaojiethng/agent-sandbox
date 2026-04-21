# Agent Handover

**Session date:** 2026-04-21  
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline  
**Session type:** Chore / Bug Fix  
**Status:** Closed

## Objective

Fix the checkpoint tag spam issue where multiple sessions starting on the same commit
created redundant checkpoint tags with different timestamps. Add idempotency to
`checkpoint_create()` so repeated calls on the same HEAD return the existing tag instead
of creating a new one.

## Background: Tag Spam Issue

During M2.3 Change 1 implementation, the checkpoint tagging mechanism created a new tag
for every session start, even when multiple sessions were started on the same commit.
This resulted in tag proliferation:

```
agent-checkpoint/dd6fe4bb/20260421-074330
agent-checkpoint/dd6fe4bb/20260421-030443
agent-checkpoint/dd6fe4bb/20260420-161243
agent-checkpoint/a2cfe5a4/20260421-075500
agent-checkpoint/a2cfe5a4/20260421-075331
agent-checkpoint/a2cfe5a4/20260421-075249
...
```

All tags with the same worktree ID prefix (e.g., `dd6fe4bb`) pointing to the same commit
are redundant — only the earliest timestamp is meaningful.

## Scope

- `scripts/checkpoint.sh` — Add idempotency check to `checkpoint_create()`
- `tests/test_checkpoint.sh` — Update pruning test; add idempotency test
- `tests/test_start_agent.sh` — Fix test assertion to match actual docker-compose format

Out of scope: Cleanup of existing redundant tags in the host repository — this requires
manual operator action (procedure provided below).

## Acceptance Criteria

- [x] `checkpoint_create()` checks for existing tag on current HEAD before creating new one
- [x] When an existing tag is found, it is returned instead of creating a duplicate
- [x] New test `test_checkpoint_create_idempotent` verifies idempotency behaviour
- [x] Existing `test_checkpoint_create_prunes_to_five` updated to create tags on different
  commits (pruning only meaningful when commits differ)
- [x] Test `test_docker_compose_template_has_container_names` fixed to assert correct
  `container_name:` format

## Hot Files

| File | Why in scope | Status |
|---|---|---|
| `scripts/checkpoint.sh` | Idempotency check added to `checkpoint_create()` | ✓ Complete |
| `tests/test_checkpoint.sh` | Pruning test updated; idempotency test added | ✓ Complete |
| `tests/test_start_agent.sh` | Test assertion corrected | ✓ Complete |

## Changes Made

### `scripts/checkpoint.sh`

**Change:** Added idempotency guard at the start of `checkpoint_create()`:

```bash
# Check if current HEAD already has a tag for this worktree
local EXISTING_TAG
EXISTING_TAG=$(git -C "$PROJECT_DIR" tag --points-at HEAD "agent-checkpoint/${WORKTREE_ID}/*" | sort | tail -n 1)

if [[ -n "$EXISTING_TAG" ]]; then
  # Return existing tag instead of creating a new one
  echo "$EXISTING_TAG"
  return 0
fi
```

**Secondary fix:** Corrected typo `&> dev/null` → `&> /dev/null` in prune call.

**Behaviour:** 
- First session on a commit: creates new tag, returns it
- Subsequent sessions on same commit: returns existing tag, no new tag created
- Next commit: new tag created as normal

### `tests/test_checkpoint.sh`

**Change 1:** Updated `test_checkpoint_create_prunes_to_five` to create intermediate
commits between tags. Pruning only has meaning when tags point to different commits.

**Change 2:** Added `test_checkpoint_create_idempotent`:
- Creates a tag via `checkpoint_create()`
- Calls `checkpoint_create()` again with different timestamp on same commit
- Asserts both calls return the same tag name

### `tests/test_start_agent.sh`

**Change:** Fixed `test_docker_compose_template_has_container_names` (renamed from
`test_docker_compose_template_has_SANDBOX_CONTAINER_NAMEs`) to assert the correct
`container_name:` key format in docker-compose.yml instead of the incorrect
`SANDBOX_CONTAINER_NAME:` key.

## Decisions Made

| Decision | Rationale | Where recorded |
|---|---|---|
| Idempotency by commit, not by timestamp | The checkpoint marks a commit state — multiple sessions on the same commit should share one checkpoint | `checkpoint_create()` implementation |
| Return existing tag, don't error | Silent idempotency is preferable to forcing callers to handle "tag exists" errors | `checkpoint_create()` implementation |
| Keep earliest timestamp as canonical | First session on a commit is the meaningful checkpoint; later sessions are retries or restarts | `sort | tail -n 1` selects earliest |

## Completed This Session

| File | Change summary |
|---|---|
| `scripts/checkpoint.sh` | Idempotency guard added; typo fixed |
| `tests/test_checkpoint.sh` | Pruning test updated; idempotency test added |
| `tests/test_start_agent.sh` | Test assertion corrected |

## Tag Cleanup Procedure (Manual Operator Action)

The fix prevents future tag spam but does not clean up existing redundant tags. To clean
up the host repository, run the following commands **on the host repository** (not in the
sandbox):

### Step 1: Inspect current tag state

```bash
# List all checkpoint tags grouped by worktree ID
git tag -l "agent-checkpoint/*" | sort

# Show which commits have multiple checkpoint tags
git tag -l "agent-checkpoint/*" | while read tag; do
  commit=$(git rev-parse "$tag^{commit}")
  echo "$commit $tag"
done | sort | uniq -D -w 40
```

### Step 2: Identify redundant tags (same commit, keep earliest)

```bash
# For each worktree ID, find tags pointing to the same commit
# Keep the earliest timestamp, mark others for deletion

# Example for a specific worktree ID (replace dd6fe4bb with actual ID):
WORKTREE_ID="dd6fe4bb"
git tag -l "agent-checkpoint/${WORKTREE_ID}/*" | while read tag; do
  commit=$(git rev-parse "$tag^{commit}")
  echo "$commit $tag"
done | sort | awk '{
  if ($1 == prev_commit) {
    print "DELETE", $2
  } else {
    print "KEEP  ", $2
    prev_commit = $1
  }
}'
```

### Step 3: Automated cleanup script

Save and run the following script in the host repository root:

```bash
#!/usr/bin/env bash
# cleanup_checkpoint_tags.sh
# Removes redundant checkpoint tags, keeping only the earliest per commit

set -euo pipefail

declare -A commit_to_earliest_tag

# First pass: find the earliest tag for each commit
while read -r tag; do
  commit=$(git rev-parse "$tag^{commit}" 2>/dev/null) || continue
  if [[ -z "${commit_to_earliest_tag[$commit]:-}" ]]; then
    commit_to_earliest_tag[$commit]="$tag"
  else
    # Compare timestamps, keep the earlier one
    existing="${commit_to_earliest_tag[$commit]}"
    existing_ts=$(echo "$existing" | grep -oP '\d{8}-\d{6}$')
    new_ts=$(echo "$tag" | grep -oP '\d{8}-\d{6}$')
    if [[ "$new_ts" < "$existing_ts" ]]; then
      commit_to_earliest_tag[$commit]="$tag"
    fi
  fi
done < <(git tag -l "agent-checkpoint/*")

# Second pass: delete tags that aren't the earliest for their commit
deleted=0
while read -r tag; do
  commit=$(git rev-parse "$tag^{commit}" 2>/dev/null) || continue
  earliest="${commit_to_earliest_tag[$commit]}"
  if [[ "$tag" != "$earliest" ]]; then
    echo "Deleting redundant tag: $tag (keeping $earliest)"
    git tag -d "$tag"
    ((deleted++))
  fi
done < <(git tag -l "agent-checkpoint/*")

echo "Cleanup complete: $deleted redundant tags removed"
```

Run with:
```bash
chmod +x cleanup_checkpoint_tags.sh
./cleanup_checkpoint_tags.sh
```

### Step 4: Verify cleanup

```bash
# Confirm no commit has multiple checkpoint tags
git tag -l "agent-checkpoint/*" | while read tag; do
  commit=$(git rev-parse "$tag^{commit}")
  echo "$commit $tag"
done | sort | uniq -D -w 40

# Should produce no output if cleanup was successful
```

## Next Session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline  
**Next task:** Change 6 — Baseline advancement (`make confirm SYNC=1`, `make sync`)

**Files to upload:**
- This handover
- `scripts/checkpoint.sh`
- `tests/test_checkpoint.sh`
- `tests/test_start_agent.sh`
