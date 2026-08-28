# Agent Handover

**Date:** 2026-08-23
**Milestone:** M2.6 — Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Ingest pass 3a of the 2026-08-21 campaigns (campaign `loc-reduction-20260821`): remove high-confidence dead code. No behavior change.

## Scope

Production files only, from the saved session `20260821-184841-3c49e7` (output mount): deletion of the orphaned `buildkit_progress.sh` library and removal of never-set flags/branches (`STRICT` at call sites, `AUTO_SELECT`) plus trivial dead constructs. The `diff.sh` changes (leaf `STRICT` parameter + verbatim-diff dedup) are grouped with commit 3, which carries their natural companions; call-site removal here leaves that parameter unused-but-harmless in the interim.

## Carried forward

| Item | From handover |
|---|---|
| Passes 2–3 ingestion series | `20260823-01` |

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | `buildkit_progress.sh` deleted (unsourced since `20260821-01`; header claim false) | File absent; no references repo-wide | accepted |
| AC2 | `apply_run`/`draft_apply_patches`/`draft_apply_uncommitted`/`_run_draft_workflow` no longer thread `STRICT`; `interactive_pick` no `AUTO_SELECT` | Inspect signatures | accepted |
| AC3 | Suite green, no behavior change | `scripts/run_tests.sh`: 524/0 failed | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`src/libs/buildkit_progress.sh`](../../src/libs/buildkit_progress.sh) | Deleted — orphaned since the 20260821-01 revert |
| [`scripts/workflows/draft.sh`](../../scripts/workflows/draft.sh) | `STRICT` threading removed from 4 functions |
| [`scripts/workflows/interactive.sh`](../../scripts/workflows/interactive.sh) | Dead `AUTO_SELECT` branch removed |

## Findings

| Finding | Disposition |
|---|---|
| Liveness discipline gap: nothing fails when a lib loses its last source-er (how buildkit_progress rotted) | Registered on roadmap at series close |
| Dead-flag policy: booleans should exist only when a production call site passes them (`STRICT`, `AUTO_SELECT` both violated) | Registered on roadmap at series close |

## Deferred items

| Item | Reason | Goes next |
|---|---|---|
| Identity extraction + diff dedup + leaf `STRICT` removal | Commit 3 of series | Commit 3 |

## What's Next

Commit 3: single-sourcing refactors (identity derivation, verbatim-diff contract).
