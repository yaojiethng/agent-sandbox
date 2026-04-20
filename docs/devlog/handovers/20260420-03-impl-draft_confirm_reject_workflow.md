# Agent Handover

**Session date:** 2026-04-20
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Complete

## Objective

Implement Change 3 — the draft/confirm/reject apply workflow in `scripts/apply_workspace.sh`
and `Makefile.template`, incorporating two targeted fixes over the candidate implementation.

## Scope

- `scripts/apply_workspace.sh` — two fixes to candidate: `git am --abort` + draft branch
  cleanup on patch application failure; `SANDBOX_DIR` existence check
- `Makefile.template` — `make draft`, `make confirm`, `make reject` targets; `make sync`
  stub (target exists, body deferred to Change 6)
- `tests/test_apply_workspace.sh` — tests for draft/confirm/reject and failure cleanup
- `tests/test_start_agent.sh` — remove `checkpoint-latest.ref` test references

Explicitly out of scope: `SYNC=1` flag, `make sync` body, container label lookup,
`checkpoint.sh` — all Change 5/6.

## Carried forward

None.

## Acceptance criteria

- [x] `make draft` with no `SESSION=` applies patches from most recent session directory
- [x] `make draft SESSION=<n>` applies patches from named session directory
- [x] Failed patch application leaves repo in pre-draft state — no partial branch, no stale `draft-state`
- [x] `make confirm` rebases draft onto source branch, fast-forward merges, deletes draft branch, clears `draft-state`
- [x] `make confirm TARGET=<branch>` merges to named branch instead
- [x] `make reject` returns to source branch, deletes draft branch, clears `draft-state`
- [x] `make draft` while `draft-state` exists exits with clear error
- [x] `make confirm` / `make reject` with no `draft-state` exits with clear error
- [x] `make apply` (legacy) applies `staged.diff` with `git apply --3way`; falls back to most recent session `staged.diff`
- [x] All above covered by tests — `tests/test_apply_workspace.sh` (22 tests)
- [x] `tests/test_start_agent.sh` contains no references to `checkpoint-latest.ref` — removed

## Hot files

| File | Why in scope | Status |
|---|---|---|
| [`scripts/apply_workspace.sh`](scripts/apply_workspace.sh) | Change 3 primary target | ✓ Implemented |
| [`libs/_templates/Makefile.template`](libs/_templates/Makefile.template) | draft/confirm/reject/sync targets | ✓ Implemented |
| [`tests/test_apply_workspace.sh`](tests/test_apply_workspace.sh) | New test file for Change 3 | ✓ Implemented (22 tests) |
| [`tests/test_start_agent.sh`](tests/test_start_agent.sh) | Remove `checkpoint-latest.ref` test references | ✓ Updated |

## Decisions made this session

None.

## Completed this session

- `scripts/apply_workspace.sh` — fully implemented with draft/confirm/reject commands and legacy apply fallback
- `libs/_templates/Makefile.template` — draft/confirm/reject/apply targets added (invoke `agent-sandbox` CLI)
- `tests/test_apply_workspace.sh` — 22 tests covering draft, confirm, reject, and legacy apply workflows
- `tests/test_start_agent.sh` — removed `checkpoint-latest.ref` test references (superseded by Change 5 container label lookup)

## Deferred items

None.

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Next task:** Change 5 — container naming redesign + Docker labels + `scripts/checkpoint.sh`.

**Files to upload:**
- This handover
- `roadmap.md`
- `design_apply_workflow_and_baseline_advancement.md`
- `scripts/apply_workspace.sh` (implemented)
- `libs/_templates/Makefile.template` (updated)
- `tests/test_apply_workspace.sh` (implemented)
- `tests/test_start_agent.sh` (updated)
