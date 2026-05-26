# Agent Handover

**Session date:** 2026-04-16
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Complete

## Objective

Implement Change 1 (checkpoint tag) for M2.3, plus SESSION_NAME derivation as a preparatory step for Change 2.

## Scope

**Change 1 — Pre-session checkpoint tag** (`scripts/start_agent.sh`):
- Create lightweight tag `agent-checkpoint/YYYYMMDD-HHMMSS` before each session
- Prune to keep only 5 most recent checkpoint tags
- Write tag name to `.workspace/checkpoint-latest.ref` for operator recovery

**Bonus — SESSION_NAME derivation** (prepares for Change 2):
- Derive `SESSION_NAME` as `<sanitized-branch>-<timestamp>`
- Export for docker-compose injection (to be added in Change 2)

## Acceptance Criteria

All acceptance criteria from `20260412-02-m2_3_onhold.md` (AC-1) met:

| AC | Description | Result |
|----|-------------|--------|
| AC-1.1 | Tag created with correct naming | ✅ |
| AC-1.2 | Ref file written with correct content | ✅ |
| AC-1.3 | Pruning keeps 5 most recent tags | ✅ |

## Hot Files

| File | Why in scope |
|------|--------------|
| [`scripts/start_agent.sh`](../../../scripts/start_agent.sh) | Checkpoint tag creation, pruning, SESSION_NAME derivation |
| [`tests/test_start_agent.sh`](../../../tests/test_start_agent.sh) | **New** — 12 tests covering checkpoint and SESSION_NAME |

## Decisions Made This Session

| Decision | Rationale | Where recorded |
|----------|-----------|----------------|
| Include SESSION_NAME derivation in Change 1 | Small isolated change (4 lines); enables simpler Change 2; no downside | This handover |
| Place checkpoint logic after git validation, before snapshot | Ensures repo is valid before tagging; tag represents pre-session state | `start_agent.sh` |
| Use `mapfile` + `sort` for pruning | Chronological ordering via timestamp in tag name; simple and reliable | `start_agent.sh` |

## Completed This Session

| File | Change |
|------|--------|
| `scripts/start_agent.sh` | Added checkpoint tag creation (lines 181-200); added SESSION_NAME derivation (lines 203-208) |
| `tests/test_start_agent.sh` | **New file** — 12 tests: 7 checkpoint tests, 5 SESSION_NAME tests |

## Implementation Details

### Checkpoint Tag Creation

```bash
CHECKPOINT_TS=$(date -u +%Y%m%d-%H%M%S)
CHECKPOINT_TAG="agent-checkpoint/${CHECKPOINT_TS}"

git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG"
echo "Checkpoint tag created: $CHECKPOINT_TAG"
```

### Tag Pruning (Keep 5 Most Recent)

```bash
mapfile -t _ALL_CHECKPOINT_TAGS < <(git -C "$PROJECT_DIR" tag --list 'agent-checkpoint/*' | sort)
_KEEP=5
if [[ "${#_ALL_CHECKPOINT_TAGS[@]}" -gt "$_KEEP" ]]; then
  _DELETE_COUNT=$(( ${#_ALL_CHECKPOINT_TAGS[@]} - _KEEP ))
  for (( _i=0; _i<_DELETE_COUNT; _i++ )); do
    git -C "$PROJECT_DIR" tag -d "${_ALL_CHECKPOINT_TAGS[$_i]}" >/dev/null
    echo "Pruned checkpoint tag: ${_ALL_CHECKPOINT_TAGS[$_i]}"
  done
fi
unset _ALL_CHECKPOINT_TAGS _KEEP _DELETE_COUNT _i
```

### Ref File for Operator Recovery

```bash
mkdir -p "$SANDBOX_DIR/.workspace"
echo "$CHECKPOINT_TAG" > "$SANDBOX_DIR/.workspace/checkpoint-latest.ref"
```

### SESSION_NAME Derivation

```bash
_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)
_SANITIZED=$(echo "$_BRANCH" | tr '/' '-')
export SESSION_NAME="${_SANITIZED}-${CHECKPOINT_TS}"
unset _BRANCH _SANITIZED
echo "Session name: $SESSION_NAME"
```

## Test Coverage

**New test file:** `tests/test_start_agent.sh` (12 tests)

**Checkpoint tests (7):**
- `test_checkpoint_tag_created` — tag exists with correct naming
- `test_checkpoint_tag_points_to_correct_commit` — tag points to HEAD
- `test_checkpoint_ref_file_written` — ref file contains correct tag
- `test_checkpoint_ref_file_creates_workspace_dir` — workspace dir created
- `test_checkpoint_pruning_keeps_five` — exactly 5 tags after pruning
- `test_checkpoint_pruning_keeps_newest` — oldest deleted, newest kept
- `test_checkpoint_no_pruning_when_under_limit` — no pruning when < 5 tags

**SESSION_NAME tests (5):**
- `test_session_name_from_master_branch` — correct for master
- `test_session_name_from_main_branch` — correct for main
- `test_session_name_sanitizes_feature_branch` — slashes → dashes
- `test_session_name_sanitizes_nested_branch` — nested branches handled
- `test_session_name_exported` — available to subshells (docker-compose)

**All tests pass:** 12 passed, 0 failed

## Regression Testing

All existing tests still pass:

```
test_snapshot_host.sh:     20 passed, 0 failed
test_snapshot_container:   28 passed, 0 failed
test_diff.sh:              13 passed, 0 failed
test_start_agent.sh:       12 passed, 0 failed
───────────────────────────────────────
Total:                      73 passed, 0 failed
```

## Rebuild Behaviour

| File | Location | Rebuild needed? |
|------|----------|-----------------|
| `scripts/start_agent.sh` | Host-side only | **No** |
| `tests/test_start_agent.sh` | Host-side only | **No** |

No capability layer changes — no rebuild required.

## Next Session

**Change 2 — Format-patch + session-scoped artefact directory**

Files to modify:
- `libs/docker-compose.yml` — add `SESSION_NAME` to sandbox container environment
- `libs/diff.sh` — add `diff_format_patch` function; update `diff_on_exit` and `diff_on_autosave` for session-scoped directories

Context handover: [`20260412-02-m2_3_onhold.md`](20260412-02-m2_3_onhold.md) (frozen design)
Current spec: [`docs/devlog/discussions/design_git_workflow_improvements.md`](../discussions/design_git_workflow_improvements.md) (Change 2 section)

---

## Notes

**SESSION_NAME is exported but not yet used in container.** The docker-compose environment injection is part of Change 2. This is intentional — the variable is available but harmless until consumed.

**Checkpoint tags are lightweight tags.** They point to commits, not annotated tags with metadata. This is correct for the use case (point-in-time markers, not signed releases).

**Pruning uses lexicographic sort.** The `YYYYMMDD-HHMMSS` format ensures chronological ordering matches lexicographic ordering, making `sort` reliable for identifying oldest tags.

---

## Verification Commands

After running a session, verify:

```bash
# Checkpoint tag exists
git -C "$PROJECT_DIR" tag --list 'agent-checkpoint/*'

# Ref file matches latest tag
cat "$SANDBOX_DIR/.workspace/checkpoint-latest.ref"

# SESSION_NAME is derived correctly (check start_agent.sh logs)
# Output: "Session name: <branch>-<timestamp>"
```

---

**Status:** Change 1 complete. Ready for Change 2.
