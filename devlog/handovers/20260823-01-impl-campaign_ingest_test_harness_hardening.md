# Agent Handover

**Date:** 2026-08-23
**Milestone:** M2.6 — Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Ingest the saved work of the operator-directed quality campaigns (2026-08-21) into the repo baseline. This iteration rolls in **pass 1 of 3** (campaign `test-run-20260821`): harness contract hardening and replacement of silent/source-string tests with behavioral contracts. Production code untouched.

## Scope

Files under `tests/`, plus `devlog/AGENT_FEEDBACK.md` entries and campaign handover `20260821-13`. Source save: `session-diffs/session/20260821-164826-d57774` (output mount). The two pi-provider dockerfile hunks present in the save are excluded — that state is already reflected in HEAD and was explicitly excluded by the campaign itself as operator-owned.

## Carried forward

| Item | From handover |
|---|---|
| None — `20260821-12` closed with no deferred items | — |

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | A test completing without pass/fail/skip counts as FAIL | Inspect `run_test` no-assertion guard; suite green | accepted |
| AC2 | Suite green after ingest | `scripts/run_tests.sh`: expected ~524 tests / 32 files, 0 failed | accepted |
| AC3 | No production code changed | `git show --stat` limited to `tests/` + devlog | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/libs/test_common.sh`](../../tests/libs/test_common.sh) | No-assertion guard in `run_test`; single-sourced `FAIL:` marker |
| [`tests/test_start_agent.sh`](../../tests/test_start_agent.sh) | String-grep tests → behavioral stub-run tests |
| [`tests/test_diff_workflow.sh`](../../tests/test_diff_workflow.sh) | Zombie rewrite; `apply_preview` contracts |

## Findings

| Finding | Disposition |
|---|---|
| Fixture-name collision between this pass's new `resolve_latest_dir` test (`latest_base`) and the pre-existing lexicographic-pin test using the same dir — shared-fixture order dependence | Resolved here: renamed this pass's fixture to `latest_base_dated` (deviation from raw save, required for green) |
| Campaign-flagged production findings (empty-diff apply failure, dual-use guards, lock-message contradiction, image-name header lie) | Registered on roadmap at series close (commit 4), not fixed here |

## Deferred items

| Item | Reason | Goes next |
|---|---|---|
| Passes 2–3 ingestion | Sequential commits of the same approved series | Commits 2–4 |

## What's Next

Commit 2: dead-code removal refactor (pass 3a).
