---
date: 2026-10-27
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - the reference-staleness runbook replaces the documentation audit

## Objective

Retire the stale documentation-audit material into one `prose-review` runbook for reference documentation staleness, and make that runbook consume the claim-verification pass rather than duplicate it.

## Scope

M3.2.2's `The documentation-audit prompt` row, and the three files it names: `.agents/audits/documentation-audit-comparison.md`, `.agents/audits/architecture-doc-reviewer.skill.md` and the `documentation-pass` checklist. The third was already retired into `doc-maintenance` before this unit opened, so the row resolved to one live carrier and one settled record.

Out of scope: the three remaining files in `.agents/audits/`, which `surface-area-report.md` disposes of separately, and the two designs taken from the dieted cleanup prompt, which land as their own unit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One runbook answers documentation staleness, in the `prose-review` family | `workflow/coding-agent/skills/prose-review/runbooks/reference-staleness/SKILL.md` | Agent [x] |
| The carrier is absorbed and deleted in the same unit | `grep -rn architecture-doc-reviewer` returns no live citation of the deleted file | Agent [x] |
| No carrier asserts the old state | four carriers repointed: the `doc-maintenance` provenance comment, the roadmap row, `SOURCES.md`, `surface-area-report.md` | Agent [x] |
| The settled record is removed once its items are discharged | `documentation-audit-comparison.md` deleted; its method is `doc-maintenance`'s `## Procedure`, its findings closed at `20261006-07` | Agent [x] |
| The two passes compose rather than overlap | the claim ledger is a scope input; both files state which owns what | Agent [x] |
| The runbook accepts one scope form | `## Scope accepted` states a set, and names no delta or third form | Agent [x] |
| The verdict vocabulary is the family's | `HOLD` / `APPROVE`, stated once in `code-review/references/authoring.md`; the runbook states only its condition | Agent [x] |
| The runbook holds the shape the family requires | it names no model, role, provider, seat count, project path or tool | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The runbook accepts one scope form, a set | Staleness is a property of what is on disk now, so a review of what changed reads the wrong thing; a delta's resolution is the caller's single step, and the ledger is an input rather than a scope. It also matches `writing-for-agents`, the family's other runbook | `reference-staleness` `## Scope accepted` |
| The claim ledger is an input the review judges | Stating the division in each file did not survive its own trial: all six findings were claim-checkable, so the overlap was real. Composing them removes the duplication by construction: `doc-maintenance` owns coverage, the review owns judgement | both files, and `## Does not judge` |
| `HOLD` / `APPROVE` is the family's verdict vocabulary | Operator direction, restated on 2026-10-27 after a first pass standardized on `BLOCK`: parity with the two code runbooks wins, so the authoring guide states `HOLD` once and the new runbook follows it. Nothing else in the family changed | `code-review/references/authoring.md` |
| The audit reviewer is absorbed, not rewritten | Its 166 lines carried a policy restatement already stale inside the file that reviewed for staleness: `reference/` listed twice, `docs/operations/` and `docs/discussions/` both gone. The four fault classes, the closing test and two output rules survived | this record, and the runbook |
| The comparison report is deleted | A report is reference-durable and subsumable once the implementation it describes is over. Both files it named as drop candidates are gone, its method is `doc-maintenance`, its thirteen findings closed at `20261006-07` | this record |
| The trial run is not kept as a draft | it was consumed only by this record; a run with no roadmap row and no consumer is an orphan draft, and its result is stated in Findings | this record |
| The runbook carries no `Focus` | the family's shell never passes one, so the section described an unreachable case | this record |

## Decisions pending

None.

## Findings

- **The tree did not say `BLOCK`, it said `HOLD`.** The direction was to standardize on `BLOCK` "same as `code-review`"; both code runbooks say `HOLD`. The vocabulary now lives in the authoring guide rather than in each runbook.
- **The two procedures overlapped in output, not in method.** The trial returned six findings and every one was checkable against a source, which is `doc-maintenance`'s job. That is why the fix is the ledger input rather than a sentence in each file claiming the other owns it.
- **The trial run is the runbook's only evidence, and it is a single run.** One seat, one model, two documents, 238 seconds; its six findings verify against the tree.
- **The persona question has a second rule-based instance.** `reference-staleness` ships rule-based with no persona, joining `code-review-bash`.
- **The original roadmap line said `BLOCK`.** It was corrected to `HOLD` in this port, so the row and the vocabulary agree.

## Completed

| File | Change |
|---|---|
| [`reference-staleness/SKILL.md`](../../workflow/coding-agent/skills/prose-review/runbooks/reference-staleness/SKILL.md) | new: the four fault classes, the closing test, one scope form, the ledger input, `HOLD` / `APPROVE` |
| [`prose-review/SKILL.md`](../../workflow/coding-agent/skills/prose-review/SKILL.md) | the runbook row added; the empty "not yet accepted" section removed |
| `architecture-doc-reviewer.skill.md`, `documentation-audit-comparison.md` | deleted, absorbed and subsumed |
| [`doc-maintenance/SKILL.md`](../../workflow/coding-agent/skills/doc-maintenance/SKILL.md) | the provenance comment repointed; the division against the review stated in `## Non-goals` |
| [`authoring.md`](../../workflow/coding-agent/skills/code-review/references/authoring.md) | the verdict vocabulary, stated once |
| [`surface-area-report.md`](../../.agents/audits/surface-area-report.md) | the reviewer's disposition row marked done |
| [`SOURCES.md`](../../tests/eval/instruction-cleanup/SOURCES.md), [`roadmap.md`](../roadmap.md) | repointed at what the deleted records became |
