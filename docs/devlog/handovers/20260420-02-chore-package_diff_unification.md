# Agent Handover

**Session date:** 2026-04-20
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Housekeeping
**Status:** Closed

## Objective

Complete the `package-diff` unification chore: validate `libs/package-diff.sh` behaviour and confirm `make refresh` + git alias registration work end-to-end. Note: `diff_package` extraction into `libs/diff.sh` was dropped — `package-diff.sh` is standalone; no shared logic with `diff.sh` warrants extraction.

## Scope

- [x] Validate `libs/package-diff.sh` — baseline fallback chain, `--name` flag, label derivation, file enumeration, host enforcement
- [x] Confirm `scripts/onboard.sh` git alias registration path is correct
- [x] Confirm `Makefile.template` `make refresh` target is correct

Explicitly out of scope: Change 3 implementation, any M2.3 architecture changes.

## Carried forward

| Item | From handover |
|---|---|
| Validate `package-diff.sh` behaviour | `20260420-01-plan-m2_3_apply_workflow_design` |

## Acceptance criteria

- [x] `package-diff.sh` run inside container with no `--baseline` flag resolves `BASELINE_SHA` from env var, then `.git/BASELINE_SHA`, then errors
- [x] `package-diff.sh` run on host with no `--baseline` flag exits with clear error
- [x] `package-diff.sh --name=<n>` produces output directory without timestamp prefix
- [x] `package-diff.sh --name=<n> --label=<n>` exits with error — mutually exclusive
- [x] `package-diff.sh --baseline=HEAD` produces `changes.diff` and `changed-files/`
- [x] `make refresh` invokes `agent-sandbox onboard --refresh` with `--project=$(PROJECT_DIR)` — git alias re-registered
- [x] `agent-sandbox onboard` registers `git alias.package-diff` in `PROJECT_DIR/.git/config`

## Hot files

| File | Why in scope |
|---|---|
| [`libs/package-diff.sh`](libs/package-diff.sh) | Validated — baseline fallback, `--name` flag, host enforcement |
| [`scripts/onboard.sh`](scripts/onboard.sh) | Confirmed — alias registration correct |
| [`libs/Makefile.template`](libs/Makefile.template) | Confirmed — `make refresh` passes `--project` |
| [`.skills/package-diff.md`](.skills/package-diff.md) | Confirmed — invocation matches finalised script |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| `diff_package` extraction dropped | `package-diff.sh` operates on uncommitted state; `diff.sh` operates post-commit on sandbox. Different contexts, no shared logic warrants extraction | This handover |

## Completed this session

| File | Change |
|---|---|
| `libs/package-diff.sh` | Validated — `--name` flag, baseline fallback chain, host enforcement, mutual exclusion guard |
| `scripts/onboard.sh` | Validated — alias registration, `.env` fallback for refresh path |
| `libs/Makefile.template` | Validated — `make refresh` with `--project=$(PROJECT_DIR)` |
| `.skills/package-diff.md` | Validated — `--name` guidance, fallback chain documented |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Next task:** Change 3 implementation — `scripts/apply_workspace.sh` and `Makefile.template`.

Context handover: [`20260420-01-plan-m2_3_apply_workflow_design.md`](handovers/20260420-01-plan-m2_3_apply_workflow_design.md)

**Two targeted fixes required before implementing Change 3 as-is:**
1. Add `git am --abort` + draft branch cleanup on patch application failure
2. Add `SANDBOX_DIR` existence check alongside `PROJECT_DIR` check

**Key design constraints:**
- `make confirm` in Change 3 does not include `SYNC=1` — that flag is Change 6
- Checkpoint tag resolved via `checkpoint.sh` — stub inline for Change 3; formalised in Change 5
- Changes 3 and 5 can be implemented in either order or the same session

**Hot files the next session:**
- `roadmap.md`
- `apply_workspace.sh` (candidate)
- `Makefile.template`
- `design_apply_workflow_and_baseline_advancement.md`