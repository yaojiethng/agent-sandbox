# Agent Handover

**Session date:** 2026-04-20
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Active

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

- `make draft` with no `SESSION=` applies patches from most recent session directory
- `make draft SESSION=<n>` applies patches from named session directory
- Failed patch application leaves repo in pre-draft state — no partial branch, no stale `draft-state`
- `make confirm` rebases draft onto source branch, fast-forward merges, deletes draft branch, clears `draft-state`
- `make confirm TARGET=<branch>` merges to named branch instead
- `make reject` returns to source branch, deletes draft branch, clears `draft-state`
- `make draft` while `draft-state` exists exits with clear error
- `make confirm` / `make reject` with no `draft-state` exits with clear error
- `make apply` (legacy) applies `staged.diff` with `git apply --3way`; falls back to most recent session `staged.diff`
- All above covered by tests
- `tests/test_start_agent.sh` contains no references to `checkpoint-latest.ref` — replaced by checkpoint tag lookup

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/apply_workspace.sh`](scripts/apply_workspace.sh) | Change 3 primary target |
| [`libs/Makefile.template`](libs/Makefile.template) | draft/confirm/reject/sync targets |
| [`tests/test_apply_workspace.sh`](tests/test_apply_workspace.sh) | New test file for Change 3 |
| [`tests/test_start_agent.sh`](tests/test_start_agent.sh) | Remove `checkpoint-latest.ref` test references — superseded by label lookup |

## Decisions made this session

None.

## Completed this session

No file changes this session.

## Deferred items

None.

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Next task:** Change 5 — container naming redesign + Docker labels + `scripts/checkpoint.sh`.

**Files to upload:**
- This handover
- `roadmap.md`
- `design_apply_workflow_and_baseline_advancement.md`
- `apply_workspace.sh` (implemented this session)
- `Makefile.template` (updated this session)
