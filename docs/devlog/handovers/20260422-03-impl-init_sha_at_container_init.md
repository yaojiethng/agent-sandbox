# Agent Handover

**Session date:** 2026-04-22
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective

Implement Unit A of M2.3 diff packaging unification: write `INIT_SHA` at container init and remove `BASELINE_SHA` write/update logic.

## Scope

Unit A from the M2.3 pending task list:

- In `snapshot_init_git` (`libs/snapshot.sh`), write `git rev-list --max-parents=0 HEAD` to `sandbox/.git/INIT_SHA` after baseline commit
- Remove `.git/BASELINE_SHA` file fallback from `libs/package-diff.sh`
- Add test case for `INIT_SHA` file creation in `tests/test_snapshot_container.sh`

**Confirmed:** No `BASELINE_SHA` file write logic exists to remove — only stdout echo. No existing tests need updating; only new test for `INIT_SHA` file.

## Carried forward

None.

## Acceptance criteria

1. **`INIT_SHA` file written at container init** — Run `snapshot_init_git` and verify `.git/INIT_SHA` exists with the first commit SHA. ✓ Accepted
2. **Tests pass** — Run `bash tests/test_snapshot_container.sh` and observe `30 passed, 0 failed`. ✓ Accepted
3. **No `BASELINE_SHA` file fallback** — Verify `libs/package-diff.sh` references `.git/INIT_SHA` instead of `.git/BASELINE_SHA`. ✓ Accepted

## Hot files

| File | Why in scope | Status |
|---|---|---|
| [`libs/snapshot.sh`](libs/snapshot.sh) | `snapshot_init_git` function — add `INIT_SHA` file write | ✓ Complete |
| [`libs/package-diff.sh`](libs/package-diff.sh) | Remove `.git/BASELINE_SHA` file fallback | ✓ Complete |
| [`tests/test_snapshot_container.sh`](tests/test_snapshot_container.sh) | Add test case for `INIT_SHA` file creation | ✓ Complete |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| No `BASELINE_SHA` file write to remove — only stdout echo | Investigation confirmed no file write exists; only updated `package-diff.sh` fallback | N/A — investigation finding |
| Added test case for `INIT_SHA` file creation | Tests should verify new file is created with correct content | `tests/test_snapshot_container.sh` |

## Completed this session

| File | Change summary |
|---|---|
| `libs/snapshot.sh` | Added `INIT_SHA` file write in `snapshot_init_git` after baseline commit |
| `libs/package-diff.sh` | Changed `.git/BASELINE_SHA` fallback to `.git/INIT_SHA`; updated comments |
| `tests/test_snapshot_container.sh` | Added `test_init_git_creates_init_sha` test case (3 assertions) |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline.
**Session type:** Implementation.
**Trigger B:** Not pending — mid-milestone.

Next task is Unit B (Remove checkpoint tags). Read the roadmap M2.3 pending section for the full unit list and dependency order. Implement Unit B only.

**Watch-outs:**
- Unit B is independent of Unit A (can be done in any order with B)
- Check `start_agent.sh` and `scripts/checkpoint.sh` for checkpoint tag creation/pruning/lookup
- Container labels may reference `agent-sandbox.checkpoint-tag`

Context handover: [`20260422-02-workflow-propagation_discipline_and_prompt_templates.md`](handovers/20260422-02-workflow-propagation_discipline_and_prompt_templates.md)
