---
date: 2026-10-19
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - prose standards split and retirement carry-over

## Objective

Close the M3.3.4 lead row by proving the principle template on two more judgements, and close its sub-row by reconciling the two retired policies section by section.

## Scope

The lead row **Settle the split criterion and prove the template** and its sub-row **Reconcile the two closed retirements, section by section** in [`devlog/roadmap.md`](../roadmap.md). The criterion was already settled by `20261017-design-settled-the_judgement_kind.md` and the norm-ownership ledger; this iteration states where it lives, proves the template by filing two judgements, and produces the reconciliation.

Out of scope: the two plan rows (`Plan the communication standard into principle specs`, `Plan the prompt-authoring conventions into principle specs`) and the dedupe row stay open; they enumerate the remaining judgement rows. The `disable-model-invocation` row stays open. The remaining six policy-retirement slices, the maintenance-surface declaration and the policy-bundle drop are M3.3.2's.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The split criterion is stated once and the ledger resolves every prose line of both source documents to one kind | `bash scripts/check_norm_ownership.sh --check`, 166 rows | Agent [x] |
| The carry-over matrix covers every section of `handover_policy` and `roadmap_policy` with a verdict | read `devlog/discussions/20261019-report-settled-retirement_carry_over.md` | Operator [ ] |
| Two new principles share the exemplar's shape and are filed in the repository source and the installed copy | `diff -q` each source against its `$AGENT_HOME` copy; read each `SKILL.md` | Agent [x] |
| Each moved judgement leaves the source document and the document points at the skill | `grep -n "No magic constants in a snippet\|No-ops\|Stale accumulation" docs/development/prompt-authoring-conventions.md` returns the pointer lines; `grep -n "Delete test" docs/policies/documentation_policy.md` returns the pointer line | Agent [x] |
| The gates are clean | `bash scripts/check_frontmatter.sh`, `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The two proving principles are `communication-principle-cut-what-carries-nothing` and `communication-principle-name-the-value-not-a-literal` | each is a judgement row in one or both source documents, distinct from the three existing principles, and carries a clean instead-of/give table | the two `SKILL.md` files; the roadmap |
| The delete test and the no-op are one judgement, not two | both ask whether a sentence changes the reader's action, so a second skill would state the same test twice | `communication-principle-cut-what-carries-nothing` `**The test.**` |
| The reconciliation is a report, not a design | it audits a completed operation and reaches a verdict per row; it decides nothing new | `20261019-report-settled-retirement_carry_over.md` |
| The report marks `## Brevity` and `## Purpose` as transformed, not landed | their shape survives in the handover template and their rationale is distributed; no rule is lost, because a rationale is not a rule | the report's Findings |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| Every section of both retired policies resolves to a live carrier, a transformed form, or a stated drop. No rule is unaccounted for. | result | the reconciliation excludes a lost rule for these two slices |
| The `## Brevity` bullets survive only as the template's shape, not as named rules. | observation | a writer meets the shape they fill; this is by design |
| The source documents carried the same judgement in three places; one home in a skill is the first consolidation the principle tranche performs. | result | the pattern for the remaining plan rows is now worked |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/20261019-report-settled-retirement_carry_over.md` | new report; the section-by-section carry-over matrix over `handover_policy` and `roadmap_policy` |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-cut-what-carries-nothing/SKILL.md` | new principle; the delete test and the no-op |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-name-the-value-not-a-literal/SKILL.md` | new principle; name the value the reader must set |
| `docs/policies/documentation_policy.md` | the `Delete test` bullet becomes a pointer to the principle |
| `docs/development/prompt-authoring-conventions.md` | the `No magic constants in a snippet` paragraph and the `No-ops`/`Stale accumulation` bullets become pointers |
| `scripts/lint/norm-ownership.tsv` | regenerated; three pointer lines classified `model` |
| `devlog/roadmap.md` | the lead row and its sub-row marked `[x]`; two sub-rows added for the new principles |
