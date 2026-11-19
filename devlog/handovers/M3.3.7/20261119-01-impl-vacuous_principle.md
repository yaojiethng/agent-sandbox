---
date: 2026-11-19
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - The vacuous statement earns its check

## Objective

Admit `principle-vacuous` as the 27th principle. A statement is vacuous when no observation separates its holding from its not holding, so its predicate carries a check or the sentence goes.

## Scope

The operator's ask: a principle for logically vacuous statements, the unit the logical statement, and the harm padding word count. The operator dictated the leitwort `vacuous`, the granularity, two cases, a predicate with no check and a premise that can never be tested, and then ruled the admission.

The evidence came before the prose. 186 statements were harvested in three strata before any category was proposed, 89 from records, 57 from project prose, 40 from this session's chat turns. A read-only annotator labelled 40 shuffled statements from a withheld sheet. The sample, the labels, the agreement and ten minimal pairs are in `.scratchpad/vacuous-report.md`.

The carriers are the skill, the index leaf under `Grounding`, the two reverse edges, and the installed copy under `$AGENT_HOME`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The criterion is operational, so two readers converge on one set of labels. | A read-only annotator labelled 40 shuffled statements with the criterion and no answer key. | Accepted. 38 of 40, 95 percent. Cohen's kappa is uninformative at two V calls and is not reported as a result. |
| The leaf's central case is the one the material shows, not the one the framing named. | Compare the sample's faces against the leaf. | Accepted. Two unchecked predicates or classifications and zero tautologies across 186 statements. |
| Each of the four faces states its own fix. | Read the faces table against the test. | Accepted. |
| The rule does not cut the vacuous forms that work. | Read the boundary against the sample. | Accepted. The concession, the debate closer and the guard each name what the reader can act on. |
| The blind seat's disagreements are resolved in the file, not left in this record. | Read the test's last clause against the two disagreed items. | Accepted. The test's last clause, written from the two disagreed items. |
| The leaf's edges are reciprocal and the surface gates pass. | `node scripts/principle_inventory.mjs` prints both directions; `scripts/lint.sh` and `scripts/check_instruction_surfaces.sh`. | Accepted. Both directions print in the inventory, and the three gates are clean. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The leaf is admitted rather than folded into `show-dont-describe`. | An instance and a criterion are different handovers, and no existing leaf reaches the tautology or the contradiction. | This record; the skill. |
| The unit is the logical statement and the mechanism is the predicate and its check. | The operator's granularity, and the one test that settles all four faces. | This record; the skill. |
| The predicate with no check is the central case. | Both occurrences in the sample are unchecked predicates or classifications, and the tautology scored zero across 186 reviewed statements. | This record; the skill. |
| Prevalence is stated as low and explained, not argued away. | 11 per thousand in reviewed prose, so the leaf rests on an operational criterion rather than on frequency. | This record. |
| Edges to `show-dont-describe` and `dont-forecast-undone-work`. | One failure at two grains in the first, a claim with nothing behind it in the second. | Both skill files. |
| The operator's prompt was rewritten before the work, and the rewrite is what ran. | The deep version was a sample, a second seat, pairs and a count; the wide version would have been a taxonomy with no measurement. | This record. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The tautology and the contradiction did not occur once in 186 statements of reviewed prose. | Evidence | The defect the operator meets is a drafting defect, and shipped text has already had it removed, so prevalence here measures review rather than drafting. A draft sample from the session logs would measure the other side. | This record; the estimate is stated as a floor. |
| `communication-principle-show-dont-describe` declared `neighbours: []`, which reads as no neighbour rather than as no neighbour declared. | Carrier | The convention says an empty list is a declaration of nothing, so an edge added later changes the field's meaning without recording that it changed. | This record; the edge added in the same edit. |
| The blind seat called two self-reports unfalsifiable where this seat called them checkable. | Criterion | Both statements report the writer's own reasoning, so the criterion had a hole exactly where the writer reports on themselves. | Fixed in this iteration: the test's last clause. |

## Completed

| File | One-line change summary |
|---|---|
| [`principle-vacuous/SKILL.md`](src/reasoning/agent-runtime/pi/config/agent/skills/principle-vacuous/SKILL.md) | The judgement, four faces with their fixes, the test, the forms that earn their vacuity, and three boundary pointers. |
| [`src/reasoning/agent-runtime/pi/config/agent/AGENTS.md`](src/reasoning/agent-runtime/pi/config/agent/AGENTS.md) | The 27th leaf under `Grounding`. |
| [`communication-principle-show-dont-describe/SKILL.md`](src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-show-dont-describe/SKILL.md) | Declares the edge, replacing `[]`. |
| [`communication-principle-dont-forecast-undone-work/SKILL.md`](src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-dont-forecast-undone-work/SKILL.md) | Declares the edge. |
| [`devlog/roadmap.md`](devlog/roadmap.md) | One row closes with its landed summary. |
| `devlog/handovers/M3.3.7/20261119-01-impl-vacuous_principle.md` | This record. |
