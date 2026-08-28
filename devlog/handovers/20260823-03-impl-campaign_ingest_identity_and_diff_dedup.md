# Agent Handover

**Date:** 2026-08-23
**Milestone:** M2.6 — Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Ingest pass 3b of the 2026-08-21 campaigns (campaign `loc-reduction-20260821`): single-source the session-identity derivation (3 copies → 1) and the verbatim-diff contract (2 copies → 1), completing the `STRICT` removal at the `diff.sh` leaf. No behavior change — formulas byte-identical.

## Scope

From saved session `20260821-184841-3c49e7`: `session_env.sh` gains `sandbox_id_derive`/`session_id_derive`; `start_agent.sh`/`resume_agent.sh` call them; `diff.sh` gets `_diff_stage_untracked`/`_diff_restore_untracked`/`_write_git_diff` and drops the leaf `STRICT` parameter; `test_checkpoint.sh` rewritten from a tautology suite into a spec-conformance suite of the new helpers plus a regression guard against inline formula reappearance.

## Carried forward

| Item | From handover |
|---|---|
| Passes 2–3 ingestion series | `20260823-02` |

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | Exactly one definition of each identity formula; start/resume call the helpers | Inspect; `test_checkpoint.sh` green incl. no-inline-pipelines guard | accepted |
| AC2 | Verbatim-diff write path single-sourced; byte-exact round-trip tests still green | `tests/test_diff_workflow.sh`, `test_diff_rename.sh` green | accepted |
| AC3 | Suite green | `scripts/run_tests.sh`: 524/0 failed | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`src/libs/session_env.sh`](../../src/libs/session_env.sh) | New canonical home for identity derivation |
| [`src/libs/diff.sh`](../../src/libs/diff.sh) | Untracked-stage/restore + diff-write deduped; leaf `STRICT` param removed |
| [`tests/test_checkpoint.sh`](../../tests/test_checkpoint.sh) | Tautology suite → spec-conformance + anti-reappearance guard |

## Decisions

| Decision | Rationale |
|---|---|
| Sandbox-dir-hash fallback duplication (`compose.sh`/`run_agent.sh`) NOT extracted | Would force build layer to source host session layer for two lines; cost > benefit (campaign's own deferred call, upheld) |
| `diff.sh` taken whole into this commit rather than hunk-split with commit 2 | Leaf `STRICT` param is inert while unused; whole-file grouping keeps both intermediate states green and reviewable |

## Deferred items

| Item | Reason | Goes next |
|---|---|---|
| Coverage-campaign test suites | Commit 4 of series | Commit 4 |

## What's Next

Commit 4: coverage campaign test suites + roadmap registration of flagged findings.
