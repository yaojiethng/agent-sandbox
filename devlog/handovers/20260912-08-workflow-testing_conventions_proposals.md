# Agent Handover

**Date:** 2026-09-12
**Milestone:** M2.6 - Session Persistence (general cross-cutting track)
**Type:** Workflow
**Status:** Closed

## Objective
Review the test-quality campaign's five proposed testing-policy/conventions rules (from the campaign report, handover `20260912-05` deferred item) and land the accepted ones in `docs/development/testing-conventions.md` / `testing_policy.md`, plus any agreed `test_common.sh` helper additions. Per documentation_policy, policy changes are proposed ONE SECTION AT A TIME in chat; the operator approves each before it is written.

## Context (needed after context compaction -- read no further records)
- Campaign report: `/home/agentuser/workspace/output/test-campaign-20260912-095419-272390/FINAL_REVIEW.md`, section 5 "Bash Conventions and Testing Policy Gaps". The campaign's INVARIANTS.md (same directory) is the prototype for proposal 3's known-gaps record.
- The campaign itself was accepted and folded into `561dba7`; only its RULE PROPOSALS remain unlanded.
- Current files: `docs/development/testing-conventions.md` (fixture patterns, anti-patterns, templates), `docs/development/testing_policy.md` (rules; mechanical content moved out), `tests/libs/test_common.sh` (pass/fail/skip, `run_test` with no-assertion detection, `test_setup`, `test_done`).
- Operator has NOT seen or approved the five proposals as policy text yet -- they arrive as campaign recommendations only.

## The five proposals (verbatim from the campaign report)
1. Never inline production source into a test. Extract at runtime or drive the real entry point; state the extraction pattern in a prerequisite gate. (Anti-Pattern 7 candidate: "Test-the-copy".)
2. Structural template is mandatory, not advisory: one registration block, one `test_done`, nothing after it. (A 5-line liveness extension would flag any `run_test` after the first `echo "Results:` line.)
3. Every documented branch of a sourced lib function requires either a test or an entry in a known-gaps record; make the known-gaps record a file (campaign INVARIANTS.md is the prototype).
4. Tests that pin output strings must cite the deciding record (roadmap item, ADR, handover).
5. `test_common.sh`: add `assert_subshell_rc` (run a function in a subshell, capture rc) and `source_function_from FILE NAME` helper.

## Scope
1. For each proposal 1-4: present the proposed convention/policy text in chat (one at a time), get operator approval, then write into `testing-conventions.md` (or `testing_policy.md` where rule-grade). Reject/amend as the operator decides.
2. Proposal 5 is code, not prose: if approved, add the helpers to `tests/libs/test_common.sh` with tests exercising them.
3. Proposal 2's liveness extension (flag `run_test` after the results line): propose as part of item 2's section or as a separate small impl task; operator decides.
4. Roadmap write-back for this iteration's rows per the canonical timing rule.

## Design notes
- Proposal 1 and 2 fix concrete rot found in this repo (the inlined `_provision_agent_home` copy; the broken `test_dry_run_record.sh` structure) -- both have real catch-evidence.
- Proposal 3 creates a NEW standing artifact (known-gaps file). Confirm the operator wants the maintenance burden; INVARIANTS.md from the campaign is the candidate seed, but it lives in the output mount (ephemeral) -- decide whether to promote it into the repo or start fresh.
- Proposal 4 is already de facto; its section will be short.
- The campaign report itself is ephemeral (output mount); if any proposal cites it, the citation should name the handover (`20260912-05`) rather than the mount path, per record-not-session-history.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | Each of proposals 1-4 individually presented in chat and operator-approved/amended/rejected | chat log | pass -- 1 accepted (Anti-Pattern 7), 2 accepted (mandatory structure + runner liveness scan, option b), 3 rejected (no file; comment convention codified as one sentence), 4 accepted (citation rule added to Anti-Pattern 6) |
| AC2 | Accepted rules landed in the correct file with one-terms-one-meaning style | offline read | pass -- all in `testing-conventions.md` (structure rule, gap-note sentence, Anti-Pattern 7, Anti-Pattern 6 citation sentence) |
| AC3 | Proposal 5 accepted: helpers exist in `test_common.sh`, used by tests, suite green | suite | pass -- `assert_subshell_rc` + `source_function_from` with 4 self-tests in `test_common_lib.sh` |
| AC4 | Full test suite passes | suite | pass -- 752/0/0 (43 files) |

## Completed

| File | Change |
|---|---|
| `docs/development/testing-conventions.md` | Anti-Pattern 7 (Test-the-Copy); mandatory structure rule + retired inline template tail; gap-note sentence (proposal 3, rejected-file form); pin-citation sentence in Anti-Pattern 6 |
| `scripts/run_tests.sh` | `check_liveness`: static scan flagging `run_test` registered after `test_done` (in-process guard impossible -- `test_done` exits) |
| `tests/test_runner_selftest.sh` | Case 12: dead-registration detection |
| `tests/libs/test_common.sh` | `assert_subshell_rc` + `source_function_from` helpers |
| `tests/test_common_lib.sh` | 4 self-tests for the new helpers (mismatch probe runs in a captured subshell so its deliberate FAIL marker never reaches the runner grep) |

## Deferred items
- None. Proposal 2's liveness extension landed in this iteration (runner scan + selftest), not as a separate impl iteration.
