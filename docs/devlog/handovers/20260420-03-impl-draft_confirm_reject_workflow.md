# Agent Handover

**Session date:** 2026-04-20
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Complete

## Objective

Implement Change 3 — the draft/confirm/reject apply workflow in `scripts/apply_workspace.sh`
and `Makefile.template`, incorporating two targeted fixes over the candidate implementation.
Also fix `make apply` to read from `OUTPUT_DIR` (reasoning layer output channel) instead
of `CHANGES_DIR` (capability layer diff channel).

## Scope

- `scripts/apply_workspace.sh` — two fixes to candidate: `git am --abort` + draft branch
  cleanup on patch application failure; `SANDBOX_DIR` existence check; **plus** rewrite
  legacy `apply` block to read from `OUTPUT_DIR` with `changes.diff`
- `Makefile.template` — `make draft`, `make confirm`, `make reject` targets; `make sync`
  stub (target exists, body deferred to Change 6); update `make apply` comment block
- `tests/test_apply_workspace.sh` — tests for draft/confirm/reject and failure cleanup;
  **plus** tests for `make apply` OUTPUT_DIR behaviour
- `tests/test_start_agent.sh` — remove `checkpoint-latest.ref` test references
- `docs/discussions/design_apply_workflow_and_baseline_advancement.md` — document `make apply`
  OUTPUT_DIR channel in Apply Workflow section
- `docs/devlog/roadmap.md` — update Change 3 description to include `make apply` fix
- `docs/devlog/handovers/20260420-03-impl-draft_confirm_reject_workflow.md` — this handover

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
- [x] `make apply` with no `SESSION=` applies `changes.diff` from lexicographically latest directory in `OUTPUT_DIR/`
- [x] `make apply SESSION=<name>` applies from that named directory
- [x] `make apply` with empty `OUTPUT_DIR` exits with clear error
- [x] `make apply` where resolved directory has no `changes.diff` exits with clear error
- [x] `make apply` prints path to `migration-guide.md` before applying if present
- [x] `make apply --mode=apply` exits with clear deprecation notice — old flag removed
- [x] `make draft` is unaffected — still reads from `session-diffs/`
- [x] Cleanup policy documented in script header: `OUTPUT_DIR` is not cleared automatically
- [x] All above covered by tests — `tests/test_apply_workspace.sh` (19 tests)
- [x] `tests/test_start_agent.sh` contains no references to `checkpoint-latest.ref` — removed

## Hot files

| File | Why in scope | Status |
|---|---|---|
| [`scripts/apply_workspace.sh`](scripts/apply_workspace.sh) | Change 3 primary target; legacy apply rewrite | ✓ Implemented |
| [`libs/_templates/Makefile.template`](libs/_templates/Makefile.template) | draft/confirm/reject/apply targets; comment updates | ✓ Implemented |
| [`tests/test_apply_workspace.sh`](tests/test_apply_workspace.sh) | Tests for draft/confirm/reject and apply (OUTPUT_DIR) | ✓ Implemented (19 tests) |
| [`tests/test_start_agent.sh`](tests/test_start_agent.sh) | Remove `checkpoint-latest.ref` test references | ✓ Updated |
| [`docs/discussions/design_apply_workflow_and_baseline_advancement.md`](docs/discussions/design_apply_workflow_and_baseline_advancement.md) | Document `make apply` OUTPUT_DIR channel | ✓ Updated |
| [`docs/devlog/roadmap.md`](docs/devlog/roadmap.md) | Update Change 3 description | ✓ Updated |

## Decisions made this session

None.

## Completed this session

- `scripts/apply_workspace.sh` — fully implemented with draft/confirm/reject commands; legacy apply rewritten to read from `OUTPUT_DIR` with `changes.diff`
- `libs/_templates/Makefile.template` — draft/confirm/reject/apply targets added (invoke `agent-sandbox` CLI); comment block updated
- `tests/test_apply_workspace.sh` — 19 tests covering draft, confirm, reject, and apply (OUTPUT_DIR) workflows
- `tests/test_start_agent.sh` — removed `checkpoint-latest.ref` test references (superseded by Change 5 container label lookup)
- `docs/discussions/design_apply_workflow_and_baseline_advancement.md` — documented `make apply` OUTPUT_DIR channel in Apply Workflow section
- `docs/devlog/roadmap.md` — updated Change 3 description to include `make apply` fix
- `docs/devlog/handovers/20260420-03-impl-draft_confirm_reject_workflow.md` — this handover updated with scope, acceptance criteria, and hot files

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
