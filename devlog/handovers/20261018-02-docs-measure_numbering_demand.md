---
date: 2026-10-18
milestone: M3.3.4 - The prose standards as principles
type: Documentation
status: Closed
---

# Handover - Measure numbering demand before choosing a rule

## Objective

Measure what the corpus actually references, and how much churn numbering would cost, so the numbering rule is chosen from evidence rather than from a standard adopted whole.

## Scope

This iteration lands the measurement only. The same iteration first produced a naming scheme, a gate, a baseline and a principle skill; all of it was rejected on operator review as misaligned and is removed here. The rejected work is not recorded as a design, because its central choice, an identity name in place of a number, contradicts the operator's stated requirement.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The unit census is reproducible | `node .scratchpad/analysis/census.mjs .` regenerates the class and in-degree tables | Accepted |
| The churn and renumber counts are reproducible | `node .scratchpad/analysis/churn.mjs` | Accepted |
| The chat ordering rate is reproducible | `node .scratchpad/analysis/transcripts.mjs` over 475 sessions | Accepted |
| The move cost is priced | 1,150 dead links, of which 797 recover by local name and 273 do not | Accepted |
| No mechanism is left in the tree | `scripts/lint.sh` holds 9 gates; no naming check, baseline or scheme document exists | Accepted |
| The gates are clean | `bash scripts/lint.sh` | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The identity-name scheme is rejected | The operator asked for numbers because numbers are shorter to type, applied per document class, consistent with the taxonomy and the reference flow. A name replaces the number, and a resolver, an allocator and a baseline add the maintenance surface the operator ruled out. | this record; the operator's review |
| The numbering rule must follow the reference-flow direction | A derived record cites its source, so only the derived record writes a qualified reference, and a durable record never cites a transient unit. The direction already exists in the promotion topology. | the census record, `## Resolution` |
| Cost moves to the commit, not the draft | Writing a number and renumbering inside a document are free. A committed cross-document reference that no longer resolves is the expensive error, and one cheap lint at commit is where it is caught. | the census record, `## Resolution` |
| Figures stay out of the rule | Six diagram blocks in 989 documents, none captioned, no figure references. A counter with no units serves nothing. | the census record, `## Findings` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Which unit kinds in each class get a number? | the rule's table of counted namespaces | findings, questions, decisions, requirements, steps; sections in policies and ADRs only; a narrower set |
| Does a durable record ever cite a transient unit? | whether the reference-flow rule is absolute or admits one direction back | absolute; one exception with a marker |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `Step N` carries the highest in-degree of any positional scheme, 349 references at a median of 30 per step id, and it lives in `workflow/coding-agent/prompts/`. | measurement | The one place where numbering already works is prompt steps, and it is also the place where a prompt edit breaks the most references. |
| 1,150 of 2,302 Markdown links are dead; 1,065 sit in the trees `record-links` exempts at `.markdownlint-cli2.mjs:24`. | measurement | The break is silent by configuration. Any numbering rule that produces cross-document references inherits this gap. |
| One insertion at position 2 of every document would relabel 9,533 headings, and 44 anchored references embed an ordinal. | measurement | Renumbering is real churn, which is why it belongs on the hot path inside one document and never across committed documents. |
| The operator points at items by index in 83 of 6,889 messages, and by bare digit in 7. | measurement | The habit is real but rare. The rule must cost nothing when it is not used, which rules out any per-write tool. |
| The previous iteration's gate flagged 254 references to state-bearing file names before the subject was corrected to the name itself. | diagnosis | The check taxed the ordinary act of linking a record. Any new check is judged by what it costs on the compliant path. |

## Completed

| File | Change |
|---|---|
| `20261018-study-draft-numbering_scheme_census.md` | the census, the in-degree table, the churn and transcript measurements, and the constraints the rule must satisfy |
| [`AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md) | one missing blank line before a heading, which failed the blocking Markdown gate |
