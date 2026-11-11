---
date: 2026-11-11
milestone: M3.3.5 - The eval pipeline
type: Housekeeping
status: Closed
---

# Handover - The stale instruction-cleanup case is retired

## Objective

Retire the instruction-cleanup case, its fixture and its census discussions, record the operator's acceptance of the `/gm` A/B as the separating case, and leave M3.3.5 with no open rows.

## Scope

The `tests/eval/instruction-cleanup/` fixture and the four census reports inside its payload; the M3.3.5 instruction-cleanup row and its ruling-table sub-row; the milestone's acceptance criteria; the deferred eval section in `roadmap_future.md`; and the instruction-authoring row, which landed in `20261111-04`.

Out of scope: building a new case for the current `instruction-cleanup` runbook, which is re-filed as post-close work.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The stale fixture and its discussions are gone. | `test ! -e tests/eval/instruction-cleanup` | Agent [x] |
| The M3.3.5 row and its prefactor are gone. | `grep -c 'instruction-cleanup case, the harness' devlog/roadmap.md` -> 0; `grep -c 'ground-truth ruling table' devlog/roadmap.md` -> 0 | Agent [x] |
| The operator's acceptance is recorded. | `grep -n 'Operator ruling (2026-11-11)' devlog/roadmap.md` | Agent [x] |
| The case is re-filed as a requirement, not an artifact path. | `grep -n 'separating case for the current instruction-cleanup runbook' devlog/roadmap_future.md` | Agent [x] |
| The instruction-authoring row is marked done. | `grep -c 'A skill edit reads the instruction-authoring rules' devlog/roadmap.md` -> one `[x]` row | Agent [x] |
| The eval fixture gate and lint stay clean. | `bash scripts/check_eval_fixtures.sh`; `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The fixture is retired rather than rebuilt. | It freezes a 168-line prompt and six carriers that no longer exist, and the current runbook returns a cleaned surface and a ruling log rather than a fault list. | this record; the deleted fixture |
| The case is re-filed as a requirement. | A future row names the requirement, not a path for an artifact that has not shipped. | `devlog/roadmap_future.md` |
| The `/gm` A/B is accepted as the separating case by operator ruling. | The case is treatment-versus-control rather than a must-lose contrast, so the acceptance is an override and is recorded as one. | `devlog/roadmap.md` |
| The instruction-authoring row is marked done. | `AGENTS.md` gained the row in `20261111-04`; the mark now rides a commit. | `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The census's owner row, **The corpus census over every review-instruction carrier**, no longer exists in the live roadmap; the fixture's reports were its only copy. | record | A fresh agent could read the census as current when it describes a prompt and carriers that are gone. | retired with the fixture |
| The old case's expected output was a fault list, while the current runbook's contract is a cleaned surface and a ruling log. | record | Grading the current runbook against the old fault list would measure the wrong output. | `devlog/roadmap_future.md` |

## Completed

| File | One-line change summary |
|---|---|
| `tests/eval/instruction-cleanup/` | Deleted: the README, `SOURCES.md`, `SHA256SUMS`, the payload and the four census reports inside it. |
| `devlog/roadmap.md` | Deletes the case and prefactor rows, records the operator ruling, and marks the instruction-authoring row done. |
| `devlog/roadmap_future.md` | Re-files the requirement for a case against the current runbook. |
| `devlog/handovers/M3.3.5/20261111-08-chore-retire_the_stale_instruction_cleanup_case.md` | This record. |
