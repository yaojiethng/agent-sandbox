# Agent Handover

**Session date:** 2026-04-17
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Complete

## Objective

Implement extensions to Change 1 as specified in the planning handover `20260417-01-plan-session_identity_and_harness_versioning.md`: Worktree namespacing for checkpoint tags, timestamp parity, detached HEAD handling for `SESSION_NAME`, and `REPO_COMMIT` capture.

## Scope

**Change 1 Extensions (two handoff specs combined):**

1. **Timestamp parity:** Ensure `CHECKPOINT_TS` is the single source of truth for all session timestamps (checkpoint tag, `SESSION_NAME`, artefact directory, future image labels). No downstream step re-calls `date`.

2. **Detached HEAD handling:** When `git rev-parse --abbrev-ref HEAD` returns the literal string `HEAD`, substitute `git rev-parse --short HEAD` (short commit SHA) as the branch component of `SESSION_NAME`.

3. **WORKTREE_ID derivation:** Export `WORKTREE_ID` derived from `PROJECT_DIR` absolute path as an 8-character hex hash (`sha1sum | head -c8`). Stable across runs for the same worktree, requires no operator input.

4. **Checkpoint tag namespace:** Change tag format from `agent-checkpoint/YYYYMMDD-HHMMSS` to `agent-checkpoint/<worktree-id>/YYYYMMDD-HHMMSS`. Update pruning logic to scope to `agent-checkpoint/${WORKTREE_ID}/*`.

5. **REPO_COMMIT capture:** Export `REPO_COMMIT=$(git -C "$PROJECT_DIR" rev-parse HEAD)` alongside `SESSION_NAME`. Not consumed by anything in Change 1 but establishes the primitive for image labels in a later sub-milestone (M2.7).

## Acceptance Criteria

Met all requirements from the planning handover:

| AC | Description | Result |
|----|-------------|--------|
| AC-1.1 | `CHECKPOINT_TS` is the single source of truth; no downstream `date` calls | ✅ |
| AC-1.2 | `SESSION_NAME` handles detached HEAD by using short SHA | ✅ |
| AC-1.3 | `WORKTREE_ID` is stable and derived from project path | ✅ |
| AC-1.4 | Checkpoint tags are namespaced by `WORKTREE_ID` | ✅ |
| AC-1.5 | Pruning is scoped to the current worktree namespace | ✅ |
| AC-1.6 | `REPO_COMMIT` (full 40-char SHA) is exported | ✅ |

## Hot Files

| File | Why in scope |
|------|--------------|
| [`scripts/start_agent.sh`](../../../scripts/start_agent.sh) | Core implementation: `WORKTREE_ID` derivation, namespaced checkpoint tags, `REPO_COMMIT` capture, detached HEAD guard |
| [`tests/test_start_agent.sh`](../../../tests/test_start_agent.sh) | 7 new tests added (19 total) covering all new functionality |
| [`docs/architecture/sandbox_lifecycle.md`](../../../docs/architecture/sandbox_lifecycle.md) | Documented namespaced checkpoint tags in lifecycle |
| [`docs/development/quickstart.md`](../../../docs/development/quickstart.md) | Added "Recovery" section explaining checkpoint tag usage |
| [`docs/operations/project_onboarding_guide.md`](../../../docs/operations/project_onboarding_guide.md) | Added "Session checkpointing" section |
| [`docs/devlog/discussions/design_git_workflow_improvements.md`](../../../docs/devlog/discussions/design_git_workflow_improvements.md) | Updated Change 1 spec with worktree namespace details |
| [`docs/devlog/roadmap.md`](../../../docs/devlog/roadmap.md) | Updated M2.3 Change 1 status and refined M2.7 scope |

## Decisions Made This Session

| Decision | Rationale | Where recorded |
|----------|-----------|----------------|
| Use `sha1sum | head -c8` for `WORKTREE_ID` | Collision-resistant enough for local namespacing; simple to derive from path; stable across runs | `start_agent.sh` |
| Keep `CHECKPOINT_TS` variable name (not `SESSION_TS`) | Avoided broad rename to keep this Change 1 extension focused; `SESSION_TS` is the preferred name in future stories but unnecessary churn here | This handover |
| Scope pruning via `git tag --list "agent-checkpoint/${WORKTREE_ID}/*"` | Robust way to ensure one worktree doesn't delete another's checkpoints; prevents cross-session interference | `start_agent.sh` |
| Detached HEAD guard: check for literal `HEAD` string | `rev-parse --abbrev-ref HEAD` returns `HEAD` in detached state; substituting short SHA maintains session name uniqueness and readability | `start_agent.sh` |
| `REPO_COMMIT` captures full HEAD SHA (not short) | Full 40-character SHA is required for image labeling primitives; short SHA could collide across repositories | `start_agent.sh` |

## Completed This Session

| File | Change |
|------|--------|
| `scripts/start_agent.sh` | Added `WORKTREE_ID` derivation (line ~190); namespaced checkpoint tag format; worktree-scoped pruning; `REPO_COMMIT` export; detached HEAD guard in `SESSION_NAME` derivation |
| `tests/test_start_agent.sh` | Added 7 tests: `session_name_detached_head`, `worktree_id_derived_from_path`, `worktree_id_stable_across_runs`, `worktree_id_different_for_different_paths`, `repo_commit_captured`, `repo_commit_is_full_sha`; updated existing checkpoint tests to use worktree namespace |
| `docs/architecture/sandbox_lifecycle.md` | Updated checkpoint tag documentation to reflect `agent-checkpoint/<worktree-id>/YYYYMMDD-HHMMSS` format |
| `docs/development/quickstart.md` | Added "Recovery" section with commands for checkpoint-based recovery |
| `docs/operations/project_onboarding_guide.md` | Added "Session checkpointing" section explaining checkpoint tags and recovery |
| `docs/devlog/discussions/design_git_workflow_improvements.md` | Updated Change 1 spec with worktree ID and namespace details |
| `docs/devlog/roadmap.md` | Updated Change 1 implementation status; refined M2.7 scope to remove completed primitives |

## Verification Results

**Test suite execution:**
```
=== start_agent.sh tests (Change 1: checkpoint + Change 2: SESSION_NAME) ===

[ checkpoint_tag_created ]
  PASS: checkpoint tag created with correct naming convention
[ checkpoint_tag_points_to_correct_commit ]
  PASS: checkpoint tag points to current HEAD
[ checkpoint_ref_file_written ]
  PASS: checkpoint-latest.ref contains correct tag name
[ checkpoint_ref_file_creates_workspace_dir ]
  PASS: checkpoint-latest.ref created with workspace directory
[ checkpoint_pruning_keeps_five ]
  PASS: pruning keeps exactly 5 most recent tags
[ checkpoint_pruning_keeps_newest ]
  PASS: pruning keeps the 5 newest tags (oldest deleted)
[ checkpoint_no_pruning_when_under_limit ]
  PASS: no pruning occurs when under limit (3 tags remain)
[ session_name_from_master_branch ]
  PASS: SESSION_NAME correct for master branch
[ session_name_from_main_branch ]
  PASS: SESSION_NAME correct for main branch
[ session_name_sanitizes_feature_branch ]
  PASS: SESSION_NAME sanitizes slashes in branch name
[ session_name_sanitizes_nested_branch ]
  PASS: SESSION_NAME sanitizes nested branch names
[ session_name_exported ]
  PASS: SESSION_NAME is exported and available to subshells
[ session_name_detached_head ]
  PASS: SESSION_NAME uses short SHA for detached HEAD
[ worktree_id_derived_from_path ]
  PASS: WORKTREE_ID is 8 characters
  PASS: WORKTREE_ID is valid hex
[ worktree_id_stable_across_runs ]
  PASS: WORKTREE_ID is stable across multiple derivations
[ worktree_id_different_for_different_paths ]
  PASS: WORKTREE_ID differs for different paths
[ repo_commit_captured ]
  PASS: REPO_COMMIT matches current HEAD
[ repo_commit_is_full_sha ]
  PASS: REPO_COMMIT is full 40-character SHA

Results: 19 passed, 0 failed
```

## Next Session

**Change 2 — Format-patch + session-scoped artefact directory**

This session completed the Change 1 extensions identified in the planning handover. The next step is to proceed with the core M2.3 Change 2 implementation:

- Add `diff_format_patch` function to `libs/diff.sh`
- Generate per-commit `.patch` files under `.workspace/changes/<session-name>/patches/`
- Move `staged.diff` into the session-scoped directory
- Ensure `SESSION_NAME` is exported to docker-compose for container injection

Context for Change 2: [`20260412-02-m2_3_onhold.md`](20260412-02-m2_3_onhold.md) (frozen design), [`docs/devlog/discussions/design_git_workflow_improvements.md`](../discussions/design_git_workflow_improvements.md) (current spec).

---

**Status:** Change 1 Extensions complete. Ready for Change 2.
