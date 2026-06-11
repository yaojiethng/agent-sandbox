# Agent Handover

**Session date:** 2026-04-28
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective
Execute Change 5 from the apply_workspace refactor spec: switch `agent-sandbox.sh` to call workflow libs directly.

## Scope
Change 5 from `docs/devlog/discussions/spec_apply_workspace_refactor.md`:

- Add `libs/draft_workflow.sh` and `libs/diff_workflow.sh` source calls to `scripts/agent-sandbox.sh`
- Add missing `--force` and `--diff=*` cases to `parse_flags` in `agent-sandbox.sh`
- Replace `apply`, `draft`, `confirm`, `reject` case branches with direct calls to `apply_run`, `draft_run`, `confirm_run`, `reject_run`
- Keep `apply_workspace.sh` functional as rollback path
- Verify every flag currently passed to `apply_workspace.sh` is present in the corresponding `*_run` parameter list
- Manual end-to-end verification of each subcommand

## Carried forward
None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | `scripts/agent-sandbox.sh` sources `libs/draft_workflow.sh` and `libs/diff_workflow.sh` | Accepted |
| 2 | `--diff=*` and `--force` cases added to `parse_flags`; `DIFF_ARG`, `FORCE`, `BRANCH_FROM`, `DIFFS`, `BRANCH_SUMMARY` initialized | Accepted |
| 3 | `apply` branch calls `apply_run` with correct parameter list | Accepted |
| 4 | `draft` branch calls `draft_run` with correct parameter list | Accepted |
| 5 | `confirm` branch calls `confirm_run` with correct parameter list | Accepted |
| 6 | `reject` branch calls `reject_run` with correct parameter list | Accepted |
| 7 | `bash -n` passes on `scripts/agent-sandbox.sh` | Accepted |
| 8 | End-to-end verification: `apply`, `draft`, `confirm`, `reject` all route correctly through `agent-sandbox.sh` | Accepted |
| 9 | `--force` flag works through new routing (`make apply FORCE=1` applies with `--reject`) | Accepted |
| 10 | `--diff` flag works through new routing (`make apply DIFF=/path` applies specific diff) | Accepted |
| 11 | `scripts/apply_workspace.sh` remains untouched and functional as rollback path | Accepted |

## Hot files
| File | Why in scope |
|---|---|
| [`scripts/agent-sandbox.sh`](scripts/agent-sandbox.sh) | Change 5 complete — verify no regression during Change 6 |
| [`libs/draft_workflow.sh`](libs/draft_workflow.sh) | Sourced by agent-sandbox.sh |
| [`libs/diff_workflow.sh`](libs/diff_workflow.sh) | Sourced by agent-sandbox.sh |
| [`scripts/apply_workspace.sh`](scripts/apply_workspace.sh) | Rollback path — deleted in Change 7 |
| [`Makefile`](Makefile) | Change 6 target — update to call `agent-sandbox` directly |
| [`libs/_templates/Makefile.template`](libs/_templates/Makefile.template) | Change 6 target — update to call `agent-sandbox` directly |
| [`docs/devlog/discussions/spec_apply_workspace_refactor.md`](docs/devlog/discussions/spec_apply_workspace_refactor.md) | Spec reference |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Prior handover status was `Active` — treated as completed | All AC satisfied, Next session present; status field not updated to Closed | This handover |
| Keep empty-string guards in case branches | UX is better than `validate_project_dir` with empty path | This handover |
| Source workflow libs via `"$AGENT_SANDBOX_REPO/libs/..."` | Consistent with existing `containers.sh` source pattern | This handover |

## Bugs found during implementation

Two pre-existing bugs in `scripts/agent-sandbox.sh` exposed while verifying flag coverage for Change 5:

| Flag | Makefile sends | `parse_flags` handles | Forwarded to `apply_workspace.sh` | Status |
|---|---|---|---|---|
| `--force` | Yes (bare flag via `$(if $(FORCE),--force,)`) | **No** — falls to `PASSTHROUGH` | No (`FORCE` never set) | **Bug** |
| `--diff=*` | Yes (valued via `$(if $(DIFF),--diff=$(DIFF),)`) | Yes → `DIFF_ARG` | **No** — missing from apply branch | **Bug** |

- `make apply FORCE=1` is silently a no-op: `--force` is parsed into `PASSTHROUGH` but never into `FORCE`, and the apply branch's `${FORCE:+--force}` expands to nothing.
- `make apply DIFF=/path/to/file.diff` is silently ignored: `DIFF_ARG` is set by `parse_flags` but the apply branch omits it from the `apply_workspace.sh` invocation.

Both bugs are resolved naturally by Change 5 because `apply_run` receives `DIFF_ARG` and `FORCE` as direct parameters.

## Completed this session

| File | Change |
|---|---|
| `scripts/agent-sandbox.sh` | Added source calls for `libs/draft_workflow.sh` and `libs/diff_workflow.sh`; added `--diff=*` and `--force` to `parse_flags`; initialized `DIFF_ARG`, `FORCE`, `BRANCH_FROM`, `DIFFS`, `BRANCH_SUMMARY`; replaced `apply_workspace.sh` invocations with direct `apply_run`, `draft_run`, `confirm_run`, `reject_run` calls; updated usage comment to include `[--diff=<path>]` |

## Deferred items

| Item | Reason | Next destination |
|---|---|---|
| Change 6 — Patch remaining `apply_workspace.sh` callers / Makefile update | Depends on Change 5 verification | Next session |
| Change 7 — Delete old files (`apply_workspace.sh`, `draft.sh`, `test_apply.sh`, `test_apply_workspace.sh`, `test_session.sh`) | Depends on Change 6 (zero references) | Following session |
| `SESSION_STATE` file / `$SESSION_TS` persistence bug | Not in scoped task group | M2.3 roadmap — pending |
| `package-branch` skill amendments | Depends on `SESSION_STATE` | M2.3 roadmap — pending |
| Interactive confirmation flag | Not in scoped task group | M2.3 roadmap — pending |

## Trigger B check

Trigger B does not apply. M2.3 has five pending task groups: Change 6 (caller patching), Change 7 (deletions), `SESSION_STATE` file, `package-branch` skill amendments, and interactive confirmation flag.

## Next session

**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Task:** Change 6 — Grep and patch all remaining callers of `apply_workspace.sh`; update Makefile targets to call `agent-sandbox` directly

Run `grep -rn "apply_workspace" .` from the repo root. For each caller found:
- If it is `Makefile.template` or `Makefile`: update the target to call `agent-sandbox` with equivalent flags
- If it is a script, runbook, or CI file: update it to call `agent-sandbox` with equivalent flags, or flag to operator if non-trivial
- If it is `apply_workspace.sh` itself (self-references in comments): leave it — deleted in Change 7

After patching, re-run the grep. The only remaining results must be within `apply_workspace.sh` itself. Do not proceed to Change 7 until this condition holds.

**Files to read at session start:**
- `Makefile` (repo root)
- `libs/_templates/Makefile.template`
- Any other files with `apply_workspace` references

**Watch-outs:**
- `apply_workspace.sh` must remain functional as rollback path throughout Change 6
- Verify `make apply`, `make draft`, `make confirm`, `make reject` still work end-to-end after Makefile updates
