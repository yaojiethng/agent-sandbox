# Agent Handover

**Session date:** 2026-04-23
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective

Implement Unit F0 — path and timestamp audit. Normalise all path constructions, timestamp derivations, and session identifiers to the locked spec.

## Scope

Unit F0 from the M2.3 task list — all 9 steps from the prior design handover.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | `SESSION_TS` derived exactly once in `start_agent.sh` as `$(date -u +%Y%m%d-%H%M%S)` with delimiter | ✅ |
| 2 | `SANITIZED_HOST_BRANCH` derived once in `start_agent.sh` after `SESSION_TS`, both exported | ✅ |
| 3 | `SESSION_NAME` removed as an exported variable; all references replaced with primitives or removed | ✅ |
| 4 | `diff_on_exit`/`diff_on_autosave` accept `SESSION_TS` and `SANITIZED_HOST_BRANCH`; generate `EXPORT_TIME` internally; output path `$CHANGES_DIR/<EXPORT_TIME>-<SANITIZED_HOST_BRANCH>-<SESSION_TS>/` | ✅ |
| 5 | `package_branch` accepts `SESSION_SUMMARY` as optional arg; generates `EXPORT_TIME` internally | ✅ (standalone `bundles/` path deferred — container-side path unchanged) |
| 6 | `package_diff` accepts `SESSION_SUMMARY` as optional arg; generates `EXPORT_TIME` internally; output path `diffs/<EXPORT_TIME>-<SESSION_SUMMARY>-<SESSION_TS>/` | ✅ |
| 7 | Container names use delimiter format (already correct — `SESSION_TS` already had delimiter) | ✅ verified |
| 8 | `docker-compose.yml` injects `SESSION_TS` and `SANITIZED_HOST_BRANCH` into environment; `SESSION_NAME` removed | ✅ |
| 9 | `libs/compose.sh` substitutes `SESSION_TS` and `SANITIZED_HOST_BRANCH` in compose generation; removes `SESSION_NAME` | ✅ |
| 10 | `apply_workspace.sh` `SESSION_NAME` references removed; label lookups updated | ✅ |
| 11 | Zero `SESSION_NAME` non-comment references in `scripts/` and `libs/` | ✅ |
| 12 | All tests pass: `test_diff.sh` (40/40), `test_start_agent.sh` (21/21), `test_apply_workspace.sh` (37/37) | ✅ |

## Hot files

| File | Change | Status |
|---|---|---|
| [`scripts/start_agent.sh`](scripts/start_agent.sh) | Replace `SESSION_NAME` derivation with `SANITIZED_HOST_BRANCH`; export both primitives; update echo statements | ✅ done |
| [`libs/compose.sh`](libs/compose.sh) | Replace `{{SESSION_NAME}}` with `{{SESSION_TS}}` and `{{SANITIZED_HOST_BRANCH}}`; update comment | ✅ done |
| [`libs/docker-compose.yml`](libs/docker-compose.yml) | Replace `agent-sandbox.session-name` label with `agent-sandbox.session-ts` and `agent-sandbox.host-branch`; replace `SESSION_NAME` env var with `SESSION_TS` and `SANITIZED_HOST_BRANCH` | ✅ done |
| [`libs/diff.sh`](libs/diff.sh) | `diff_on_exit`/`diff_on_autosave`: replace `SESSION_NAME` arg with `SESSION_TS` + `SANITIZED_HOST_BRANCH`; generate `EXPORT_TIME`; output path `$CHANGES_DIR/<EXPORT_TIME>-<SANITIZED_HOST_BRANCH>-<SESSION_TS>/` | ✅ done |
| [`libs/package_branch.sh`](libs/package_branch.sh) | Add `SESSION_SUMMARY` optional 5th arg to `package_branch`; update header docs | ✅ done |
| [`libs/package_diff.sh`](libs/package_diff.sh) | Add `--session-summary` and `--session-ts` flags; replace auto-derived `LABEL` with `SESSION_SUMMARY`; generate `EXPORT_TIME`; output path `diffs/<EXPORT_TIME>-<SESSION_SUMMARY>-<SESSION_TS>/` | ✅ done |
| [`libs/sandbox-entrypoint.sh`](libs/sandbox-entrypoint.sh) | Update `diff_on_exit`/`diff_on_autosave` call signatures from `SESSION_NAME` to `SESSION_TS` + `SANITIZED_HOST_BRANCH` | ✅ done |
| [`scripts/apply_workspace.sh`](scripts/apply_workspace.sh) | Remove `SESSION_NAME` references; update container label lookups to `session-ts` and `host-branch` | ✅ done |
| [`libs/_templates/Makefile.template`](libs/_templates/Makefile.template) | Verified — no `SESSION_NAME` references found | ✅ verified |
| [`libs/dirs.sh`](libs/dirs.sh) | Verified — no changes needed | ✅ verified |
| [`libs/containers.sh`](libs/containers.sh) | Verified — container names derived in `start_agent.sh` | ✅ verified |
| [`tests/test_diff.sh`](tests/test_diff.sh) | Update all `diff_on_exit`/`diff_on_autosave` calls to new 5-arg signature; use `find_session_dir` helper for dynamic `EXPORT_TIME` prefix; add missing-args failure tests | ✅ done |
| [`tests/test_start_agent.sh`](tests/test_start_agent.sh) | Replace `SESSION_NAME` tests with `SANITIZED_HOST_BRANCH` tests; update sanitization pattern from `tr '/' '-'` to `sed 's/[^a-zA-Z0-9._-]/-/g'`; update test runner and section header | ✅ done |
| [`tests/test_apply_workspace.sh`](tests/test_apply_workspace.sh) | Verified — already uses `SESSION_TS`, no `SESSION_NAME` references | ✅ verified |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| `SESSION_NAME` never passed as composed variable — only primitives `SESSION_TS` and `SANITIZED_HOST_BRANCH` cross boundaries | Operator clarification: avoid indirection layer, pass raw values that can be locally recomposed | This handover |
| `EXPORT_TIME` uses `date -u` (UTC) to match `SESSION_TS` | Avoids timezone mismatches between session start and export times | This handover |
| `package_branch` container-side output path not changed to `bundles/` in F0 | `diff_on_exit` calls `package_branch` with `CHANGES_DIR` as destination — this is the container-side path. The `bundles/` path convention is for host-side standalone invocations, which is a minor formatting change deferred to the packaging command update (F1 or G) | This handover |
| `SANITIZED_HOST_BRANCH` uses `sed 's/[^a-zA-Z0-9._-]/-/g'` in `start_agent.sh` | Per design spec: preserves dots, underscores, and dashes in branch names; only slashes and other non-alphanumeric characters are replaced | This handover |
| `apply_workspace.sh` label checks use `agent-sandbox.session-ts` and `agent-sandbox.host-branch` | Replaces single `agent-sandbox.session-name` label with two primitive labels; validates that the container session identity matches | This handover |

## Completed this session

| Change | Files |
|---|---|
| Remove `SESSION_NAME`, add `SANITIZED_HOST_BRANCH` derivation | `scripts/start_agent.sh` |
| Replace `{{SESSION_NAME}}` with `{{SESSION_TS}}` and `{{SANITIZED_HOST_BRANCH}}` | `libs/compose.sh` |
| Replace `session-name` label with `session-ts` and `host-branch`; replace `SESSION_NAME` env | `libs/docker-compose.yml` |
| `diff_on_exit`/`diff_on_autosave` new signatures and output paths | `libs/diff.sh` |
| `package_branch` gains `SESSION_SUMMARY` parameter | `libs/package_branch.sh` |
| `package_diff` new output path format with `SESSION_SUMMARY` + `SESSION_TS` | `libs/package_diff.sh` |
| Update EXIT trap and autosave call signatures | `libs/sandbox-entrypoint.sh` |
| Remove `SESSION_NAME` references, update label lookups | `scripts/apply_workspace.sh` |
| All test files updated | `tests/test_diff.sh`, `tests/test_start_agent.sh` |

## Deferred items

| Item | Reason |
|---|---|
| `package_branch` host-side standalone `bundles/` output path | Container-side path unchanged (`CHANGES_DIR/<branch>/`). The `bundles/` layout convention is for host-side packaging, can be added in F1 or G without breaking anything |
| `apply_workspace.sh` `make apply` default path still reads from `$OUTPUT_DIR/diffs/` by lexicographic sort | Already correct per spec — no change needed in F0 |

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline.
**Session type:** Implementation — Unit F1 (`.draft-state` + finish `make draft`).
**Interface note:** See design doc at `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md`.

### Orientation

Unit F1 depends on F0 (now complete). It completes the `make draft` workflow by:

1. **Resolving the target export folder** from `$CHANGES_DIR/` by lexicographic sort (latest `EXPORT_TIME`). The folder name pattern is `<EXPORT_TIME>-<SANITIZED_HOST_BRANCH>-<SESSION_TS>`.
2. **Parsing `EXPORT_TIME`, `SANITIZED_HOST_BRANCH`, and `SESSION_TS`** from the resolved folder name — these are not shell variables on the host, they are read from the folder name.
3. **Draft branch name**: `draft/<EXPORT_TIME>-<SESSION_TS>-<BRANCH_SUMMARY or SANITIZED_HOST_BRANCH>-<sha6>`.
4. **First commit on branch is `.draft-state`** with fields: `source_branch`, `from_hash`, `author`, `session_ts`, `host_branch`, `diff_count`, `exported-at`, `drafted-at`.
5. **`.draft-state` committed to branch** before any diffs are applied.
6. **Operator hint** printed on completion showing `git rebase -i` and `make confirm`.

Files to change:
- `scripts/apply_workspace.sh` — `make draft` command rewrite
- `scripts/agent-sandbox.sh` — may need `BRANCH_SUMMARY` argument passthrough
- `libs/_templates/Makefile.template` — `make draft` target update
- `tests/test_apply_workspace.sh` — test fixtures for new draft branch naming and `.draft-state` commit