# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Housekeeping
**Status:** Closed

## Objective

Correct the stale record states the check-in survey found and reconcile the open and probation feedback entries against the tree.

## Scope

Three record corrections, one unit of approval: the coverage row's count, the feedback record's stale path and entry states, and a closed handover's verification evidence. No product code and no tests.

## Carried forward

| Item | From handover |
|---|---|
| Row 83's count and the open feedback entries | the check-in inventory (no handover; surfaced during the gm survey) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The coverage row's count is the register's own computed count | `jq` over the register's `status` and `action_kind` fields | Agent [x] (128 open, one blocked, of 312) |
| Every path named in the feedback record and the roadmap resolves on disk | a path sweep over both files | Agent [x] |
| Each flipped entry names the artefact that resolved it | reading the entry | Agent [x] (five flips) |
| The jq acceptance criterion carries runtime evidence, not a reading | `jq --version` in the reasoning container | Agent [x] (`jq-1.6` at `/usr/bin/jq`) |
| Lint clean | `bash scripts/lint.sh` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | the coverage row's stale count |
| [`devlog/AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md) | a stale path and five entry states |
| [`devlog/handovers/archive/20260925-07-refactor-structured_findings_and_json_tooling.md`](20260925-07-refactor-structured_findings_and_json_tooling.md) | the jq criterion's evidence |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Flip only entries whose mitigation names an artefact that exists on disk | the landed artefact is checkable; a judgement about whether an entry is resolved is operator-owned | this handover's Findings |
| Keep the historical path in the incident entry and annotate the merge | the entry narrates a past state, so rewriting the path alone would make the narrative false | the entry itself |
| Derive the count from the register's fields rather than restate a number | the previous figure could not be reproduced, and a field-derived count can be recomputed after every batch | the roadmap row |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The coverage row's count was not reproducible: the register reports 128 open and one blocked by `action_kind`, which is 129 test-class rows in total, so the row's "129 open, one blocked" read as 130. The row now states the field-derived figure. | contradiction | current iteration |
| Five entries flipped to `mitigated`, each naming its artefact: the circular-sourcing entry (`src/libs/export_status.sh`), the library-return entry (`scripts/check_lib_contract.sh` in the gate set), the shellcheck-prose entry (the shell gate flags it), the doc-format entry (the `doc-wrap` rule is live), and the heavy-file deadline entry (the runner reads `TEST_DEADLINE` and three files declare one). | bug | current iteration |
| Twelve entries were reviewed and left unchanged because their fix is a behaviour rule or waits on other work: the review-pass framing, verification discipline, record write-back, close-milestone discipline, gate-release, edit-tool family, install staleness, library migrations, the `[[ ]]` false trap, the mechanical-edit guard, the design-document rule, the scope-to-unit rule, git-operation reverts, multi-question turns, reasoning-trace drafts, unmeasured review passes, the probe-shell exports, the duplicate-row rule, the vacuous-assertion family, and the campaign-prompt scope entry. | steering | next iteration |
| The lint gate's gate list is `check_shell.sh`, `check_lib_contract.sh`, `check_markdown.sh` - three gates - which confirms the lint-gate ADR's drift recorded as register row 290. | contradiction | next iteration |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | the coverage row's count restated from the register's fields |
| `devlog/AGENT_FEEDBACK.md` | five entries flipped to `mitigated` with the resolving artefact named; the incident entry's merged path annotated |
| `devlog/handovers/archive/20260925-07-refactor-structured_findings_and_json_tooling.md` | the jq criterion's verification evidence upgraded from reading the apt list to the runtime check |

## Deferred items

None. The unflipped entries are recorded in Findings for the operator's confirmation.

## What's Next

The next unit is the documentation iteration: the lint-gate ADR's gate set and the flag-parsing ADR's bare-value contract.

**Conclusions from this iteration:** the feedback record's states can be reconciled mechanically wherever an entry's own mitigation names a file, which is five of seventeen; the rest need a judgement about whether a behaviour rule is now habitual.
