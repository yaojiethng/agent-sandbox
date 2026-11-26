---
date: 2026-11-26
milestone: M3.5.6 - The discussion record corpus
type: Implementation
status: Closed
---

# Handover - The cutover exemption is deleted

## Objective

Delete the record cutover constant and the exemption it carried, so both record gates hold every live discussion record rather than the ones written after a date.

## Scope

Row 5 of `M3.5.6`. One constant file deleted, two gate imports and their exemption branches removed, the two shell wrappers' cutover seams removed, two test cases deleted with the feature, and four stale comments corrected.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The constant and every reference to it are gone. | `grep -rn 'RECORD_CUTOVER\|record-cutover' scripts/ tests/` answers nothing | Agent [x] |
| Both gates read every live record. | `bash scripts/check_record_names.sh` and `bash scripts/check_record_lifecycle.sh` clean across 12 records | Agent [x] |
| The tests that exercised the exemption are deleted with it. | `bash tests/test_record_names_gate.sh` 7 passed; `bash tests/test_record_lifecycle_gate.sh` 8 passed | Agent [x] |
| No comment still promises an exemption or names the row that was to end it. | `grep -rn 'T5 cleanup\|before the cutover is exempt' scripts/` answers nothing | Agent [x] |
| The gates pass. | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Delete the constant file rather than set it to an empty date. | A sentinel date would keep the machine alive with nothing to drive it; the exemption is gone, so its switch goes. | `scripts/lint/record-cutover.mjs` removed |
| Delete the cutover test cases instead of rewriting them. | Each one asserted an exemption that no longer exists, so keeping it would assert a feature the gate no longer has. | both gate test files |
| The handover format gate keeps its own cutover. | It judges a different record kind against a different date rule, and row 5 named the record cutover alone. | this record |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The record cutover constant was cited in five comments as the thing `T5` would delete; `T5` never owned the row, and `M3.5.6` did. | record | a reader following the comment reached a milestone that could not act on it | corrected in both wrappers and both gates |
| `dateOf` survived in both gates only to feed the exemption, so deleting the exemption left it dead. | code | dead code accumulating beside the rule it served | removed |
| The name gate's `--force` flag existed only to bypass the exemption, and the wrapper passed it on the named-file path. | code | a flag with no meaning after the exemption, silently swallowing the argument | removed |
