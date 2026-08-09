# Agent Handover

**Session date:** 2026-08-09
**Milestone:** M2.6.5 — Copy Model: Volume-backed Sandbox
**Session type:** Implementation
**Status:** Closed

## Objective

Harden `package_branch.sh`: write `init_sha` into every bundle so the host-side `make draft` can resolve the baseline commit. Remove the unused `--baseline` override.

## Scope

1. Write `${OUTPUT_DIR}/init_sha` containing the baseline commit SHA
2. Remove `--baseline` flag, `BASELINE_ARG`, and `INIT_SHA_OVERRIDE` from both `package_commits()` and `package_branch()` — `init_sha` is always read from `SESSION_STATE` and is mandatory
3. Clean up usage text and comments

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by |
|---|---|---|
| 1 | Running `package_branch.sh` writes `init_sha` file into the bundle directory | `cat bundles/*/init_sha` — 40-char SHA |
| 2 | No `OVERRIDE`, `BASELINE_ARG`, or `--baseline` references remain in `package_branch.sh` | `grep -c` == 0 |
| 3 | `package_branch.sh` exits non-zero if `init_sha` is missing from `SESSION_STATE` | Already the case — logic unchanged, just no override bypass |
| 4 | `bash -n` passes | `bash -n src/libs/package_branch.sh` |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/test_package_branch.sh`](../../tests/test_package_branch.sh) | Update artefact count + add `.init_sha` check |
| [`docs/architecture/sandbox_lifecycle.md`](../../docs/architecture/sandbox_lifecycle.md) | Add `.init_sha` to bundle layout |
| [`docs/concepts/sandbox_host_correspondence_model.md`](../../docs/concepts/sandbox_host_correspondence_model.md) | Add `.init_sha` to output description |
| [`docs/development/cli-standards.md`](../../docs/development/cli-standards.md) | Remove `--baseline` from usage |

## Decisions made this session

| # | Decision | Rationale |
|---|---|---|
| 1 | Remove `--baseline` override entirely | Dead code — never called by any caller in the codebase. Simplifies the hardening: baseline is always from SESSION_STATE, no bypass possible |
| 2 | Write `init_sha` as a plain file (not JSON or key=value) | Simplest format; single consumer (`make draft`) reads one line |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| `package_branch.sh` has been reading `init_sha` internally for diff generation but never writing it to the bundle output | bug | `make draft` on host has no way to know which baseline commit to apply patches against — causes `fatal: Failed to resolve '' as a valid ref` |

## Completed this session

| File | Change |
|---|---|
| `src/libs/package_branch.sh` | Writes `.init_sha` into every bundle; removed `--baseline` flag and `INIT_SHA_OVERRIDE` parameter; `init_sha` mandatory from `SESSION_STATE` |
| `tests/test_package_branch.sh` | Updated artefact count to 6; added `.init_sha` check in `test_dispatcher_creates_all_artefacts` |
| `docs/architecture/sandbox_lifecycle.md` | Added `.init_sha` to bundle layout listing |
| `docs/concepts/sandbox_host_correspondence_model.md` | Added `.init_sha` to `package-branch` output description; consolidated duplicate row |
| `docs/development/cli-standards.md` | Removed `--baseline` from usage example |

## Deferred items

| # | Item | Reason |
|---|---|---|
| 1 | Consolidate `.init_sha`, `EXPORT-TIME.txt`, and `.export-status` into a single `.export-status` key=value file | `EXPORT-TIME.txt` is redundant with `TIMESTAMP` in `.export-status`; adding `INIT_SHA` there would give a single metadata file. Touches `diff_export.sh`, `draft.sh`, knowledge tests, test fixtures. Separate session. |

## Next session

Sub-milestone: M2.6.6 — Mount Model: Host-backed Sandbox

Blocking design questions: host-side `make draft` must read `init_sha` from bundle and pass as `--branch-from`.

Post-close bookkeeping: not applicable.

**Conclusions from this session:** The `init_sha` value exists in the container (`SESSION_STATE`) and was always read correctly for diff generation — it just was never written to the bundle. The host-side `fatal: Failed to resolve '' as a valid ref` error is caused by `BRANCH_FROM=""` bypassing the `${BRANCH_FROM_ARG:-HEAD}` default in `draft.sh`. Both sides need fixing: container now writes `init_sha`; host must consume it.
