---
date: 2026-11-26
milestone: M3.5.6 - The discussion record corpus
type: Implementation
status: Closed
---

# Handover - The corpus takes one shape and the live vocabulary

## Objective

Bring every live discussion record to the current status vocabulary and one status shape, state the permission that makes a corpus review an edit, and make the lifecycle gate count a deferred owner.

## Scope

Row 4 of `M3.5.6`. Nine records renamed, one frontmatter folded, every inbound citation re-pointed, one convention clause added, one gate read widened with a test, one closed row's link stripped.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No live record carries a retired state token. | `RECORD_CUTOVER=19700101 bash scripts/check_record_names.sh` clean across 12 records | Agent [x] |
| No live record carries frontmatter where the corpus puts `**Status:**`. | `head -3 devlog/discussions/*.md` shows no `---` block | Agent [x] |
| Every inbound citation follows the renamed record. | `bash scripts/lint.sh` clean; `bash scripts/check_record_citations.sh` clean | Agent [x] |
| A record owned only by a deferred row is not a deletion. | `tests/test_record_lifecycle_gate.sh` passes with `test_record_owned_by_a_future_row_passes` | Agent [x] |
| At a forced cutover, no live record is orphaned or linked from a closed row. | `RECORD_CUTOVER=19700101 bash scripts/check_record_lifecycle.sh` clean across 12 records | Agent [x] |
| `work-log` states that a corpus review is the edit that permits a rename. | `grep -n 'reviews the corpus is such an edit' .agents/skills/work-log/SKILL.md` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `draft` and `active` become `open`; `settled` becomes `concluded`. | The vocabulary has three states, and each retired token maps to exactly one of them. | The nine names and their status lines |
| The one YAML record is folded to `**Status:**`, not the reverse. | Fifteen records use the body line and the convention names that line as where the state is read. | `20261025-design-open-counterparty_check_scope.md` |
| The lifecycle gate reads `roadmap_future.md` as well as `roadmap.md`. | A record owned only by a deferred row is owned; the gate called that a deletion. | `scripts/lint/record-lifecycle.mjs`; its test |
| The closed churn-study row drops its record link and points at the open row that now owns the record. | A closed row carries no discussion link, and the record's tenancy was already the open parent row. | `devlog/roadmap.md` |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The orphan rule keys on the filename's state being `concluded` or `rejected`, so the retired tokens made it blind to every orphan the milestone set out to find. | gate | the rename is a precondition of the check, not a cosmetic tail | this record; the gate now reads conforming names |
| The gate read `devlog/roadmap.md` alone, so the one record owned only by a deferred future row would have become a false deletion. | gate | tenancy was incomplete by one file | `scripts/lint/record-lifecycle.mjs`; one test case |
| The closed churn-study row named the record its open parent row already owns. | record | a closed row carried a link the convention forbids | `devlog/roadmap.md` |
| Two `docs/adr/` and `roadmap_future.md` links to deleted records were found by the link gate, not by the citation gate. | gate | the two gates cover different surfaces, and the plan measured the surface in files | handover `20261126-02` already carries the measurement finding |
