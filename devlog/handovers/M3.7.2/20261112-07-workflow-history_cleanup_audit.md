---
date: 2026-11-12
milestone: M3.7.2 - The change model and its refinements
type: Workflow
status: Closed
---

# Handover - The history-cleanup audit excludes the record path

## Objective

Fix the three defects the history-cleanup run exposed: the audit's record
exclusion never matched, the manifest the audit reads was never written, and the
suite proof ran under the parallel runner's per-file deadlines.

## Scope

Works the child of M3.7.2's *`history-cleanup` is a branch-preparation
primitive*. Out of scope: the convention placement and the `make confirm`
handoff, which keep the parent row open.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A record-only change at the tip is excluded from the audit's content check, and the guard fails before the fix. | `tests/test_history_cleanup_audit.sh` 10/10; the new case failed against the old line | Agent [x] |
| The real model-home range audits clean. | `bash workflow/coding-agent/skills/history-cleanup/scripts/audit.sh 268b2ea3 HEAD --reference=fbdad25a` | Agent [x] |
| The runbook names the manifest file the audit reads. | `grep -n "history-cleanup-manifest.tsv" workflow/coding-agent/skills/history-cleanup/SKILL.md` | Agent [x] |
| The proof step runs the suite serially or records a load-dependent timeout. | `grep -n "TEST_PARALLEL=1" workflow/coding-agent/skills/history-cleanup/SKILL.md` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The record exclusion matches the path field after `git ls-tree`'s tab, not a line-start or leading-slash form. | `git ls-tree -r` prints `mode type sha<TAB>path`; the leading-slash pattern never matched any record, not only a root-level one. | This record; `scripts/audit.sh` |
| The approved manifest is written to `.scratchpad/history-cleanup-manifest.tsv` and passed as `--manifest`. | The manifest lived only in chat, so check 7 was skipped silently; the runbook now names the file the audit reads. | This record; `SKILL.md` |
| The proof suite runs with `TEST_PARALLEL=1`, and a `TIMEOUT` that passes standalone is load-dependent. | A long test trips its per-file deadline under the parallel runner while the code is sound; the serial run is the deterministic proof. | This record; `SKILL.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The first record-exclusion fix (the start-or-slash anchor) was wrong: the path follows a tab in `git ls-tree`, so the exclusion still missed every record. | code | the new regression test failed against the first fix and passed against the tab-aware one | fixed in this iteration; the test is the guard |
| Check 7 was skipped in the history-cleanup run because the manifest was only a chat table. | record | the audit did not verify the approved shape | fixed in the runbook |
| The parallel suite run trips `test_doc_wrap_legacy_gate`'s 45s deadline (24s standalone); the serial run is 1623/1623. | test | a load-dependent timeout reads as a commit failure | fixed in the proof step |

## Completed

| File | One-line change summary |
|---|---|
| `workflow/coding-agent/skills/history-cleanup/scripts/audit.sh` | the record exclusion matches the tab-printed path field |
| `workflow/coding-agent/skills/history-cleanup/SKILL.md` | the manifest file and the serial proof step |
| `tests/test_history_cleanup_audit.sh` | the record-only tip case (new) |
| `devlog/roadmap.md` | the audit child row closed |
| `devlog/handovers/M3.7.2/20261112-07-workflow-history_cleanup_audit.md` | this record |
