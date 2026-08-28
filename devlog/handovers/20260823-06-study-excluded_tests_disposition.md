# Agent Handover

**Date:** 2026-08-23
**Milestone:** M2.6 — Session Persistence
**Type:** Study
**Status:** Closed

## Objective

Audit the tests outside the discovered suite (`tests/knowledge/`, `tests/integration/`, `tests/eval/`) plus runtime `skip` usage: determine whether each is out-of-date, flaky, or valuable; subsume what the seams allow; state whether further testing infrastructure is needed.

## Scope

`tests/knowledge/`, `tests/eval/`, `tests/test_*.sh` skip/skip-defect sites. Audit-first per the test-campaign-20260821 guidelines; production code untouched — every change below is inside `tests/`.

## Method

Every excluded script was syntax-checked (`bash -n`, all passed) **and executed**; failures were root-caused before disposition. Overlap with existing unit suites was checked per candidate rather than assumed.

## Disposition table

| File | Execution result | Root cause / rationale | Disposition |
|---|---|---|---|
| `workflow_draft_then_confirm.sh` | rc=127 | Sources dead pre-M1.5 paths (`libs/draft_workflow.sh`, `libs/session.sh`) | **Deleted** — fully subsumed by `test_confirm_*` in `tests/test_draft_workflow.sh` |
| `workflow_draft_then_reject.sh` | rc=127 | Same dead paths | **Deleted** — subsumed by `test_reject_*` |
| `workflow_draft_confirm_after_rebase.sh` | rc=1 | Same dead paths | **Subsumed** — unique scenario (confirm after draft branch tip moved past `.draft-state`) rewritten as unit test `test_confirm_after_draft_branch_advances`; original deleted |
| `knowledge_draft_confirm_lock_trace.sh` | rc=1 | Stale inline simulation of old `draft_run` internals; trips on the empty-patch artifact ("No valid patches"); lock conclusions already absorbed into `wait_git_lockfile` + lock tests | **Deleted** — investigation work-product, conclusions landed |
| `knowledge_binary_diff_apply.sh` | Green 19/19 | Deterministic git-only seams → belongs in suite per placement policy | **Promoted** → `tests/test_binary_roundtrip.sh` (same 19 assertions; sections 1–2 kept as external-git canaries) |
| `knowledge_diff_rename.sh` | Green 12/12 | Already harness-style (`run_test`); deterministic | **Promoted** → `tests/test_rename_apply.sh` |
| `knowledge_pi_config_cycle.sh` | Green 6/6 | Documents pi-specific config format assumptions (external tool seam) | **Kept** as knowledge |
| `diagnose_*.sh` ×4 | Not executed (container-oriented diagnostics) | Correct category per policy | **Kept** |
| `eval_commit3.sh` | 19 PASS / 16 FAIL | One-off governance AC greps from a May session; failures reflect policy evolution since, not regressions — actively misleading | **Deleted** |
| `eval_templates.sh` | 8 PASS / 1 FAIL | Same class | **Deleted** |
| `eval_new_session.sh` | Broken — references never-committed working files (`agent/prompts/new-session*.md`; since renamed to `new-iteration.md`) | Its decision ("promote v2") was executed long ago | **Deleted**; `eval_protocol.md` kept (active story work-product) |
| `tests/integration/` (README only) | n/a | Policy-defined home, currently empty | **Kept** |
| `tests/test_onboard.sh:114` | Latent `skip()` | Policy: skip in suite is a defect; repo always has provider configs so the branch was dead anyway | **Fixed** — no-provider-configs now fails loudly |

## Findings

| Finding | Type | Impact |
|---|---|---|
| 3 of 4 broken excluded tests broke by **sourcing dead paths** — exactly the rot the open AGENT_FEEDBACK entry predicts; nothing would have flagged them | rot | Validates the roadmap's non-gating `bash -n` smoke-target item; recommend implementing it next |
| None of the failures were **flakiness** — all deterministic breakage from layout/policy drift | classification | No isolation/quarantine infra needed |
| `eval_*` scripts were session-scoped acceptance checks parked in a test directory — they outlived their verdict and now report false failures | misplacement | Governance AC checks should live with their iteration's handover, not `tests/eval/` |
| `confirm_run` contract nuance pinned by the new test: must run FROM the draft branch; `.draft-state` located by message via `from_hash..branch --grep`, tolerating non-tip position after rebase | documentation | First direct regression test for the relocated-state scenario |

## Infra conclusion

No new testing infrastructure required. The excluded set needed triage, not machinery: two files were promotable as-is, one scenario warranted a real unit test, and the rest were stale work-product. The only recommended tooling remains the already-roadmapped non-gating syntax/lint smoke target for whatever stays outside the suite (now just `diagnose_*` + `knowledge_pi_config_cycle.sh`).

## Completed

| File | Change |
|---|---|
| [`tests/test_binary_roundtrip.sh`](../../tests/test_binary_roundtrip.sh) | New — 19 binary-diff pipeline assertions promoted from knowledge |
| [`tests/test_rename_apply.sh`](../../tests/test_rename_apply.sh) | Promoted from knowledge; adapted to harness conventions |
| [`tests/test_draft_workflow.sh`](../../tests/test_draft_workflow.sh) | +`test_confirm_after_draft_branch_advances`; stale `false false` args removed from two wrappers |
| [`tests/test_onboard.sh`](../../tests/test_onboard.sh) | Skip defect → deterministic failure branch |
| `tests/knowledge/*`, `tests/eval/*` | 8 files deleted per disposition table |

Suite: 587 → **620 tests / 37 files, 0 failed, 0 skipped, deterministic ×2**.

## Deferred items

| Item | Reason | Goes next |
|---|---|---|
| Non-gating `bash -n` + shellcheck smoke target for remaining excluded scripts | Touches Makefile (production surface) — operator call | Roadmap harness-hardening item |

## What's Next

M2.6 continues per roadmap.
