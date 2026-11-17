---
date: 2026-11-16
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - A principle records its operator's intent and mechanism

## Objective

Materialize the operator's intent and mechanism judgement at the skill, so the agent reads the family instead of re-deriving it from the body, and the judgement keeps its provenance.

## Scope

The five reader-context principles, the convention's field rule, the shape record's decision and the survey map's note. In scope: `metadata.intent` and `metadata.mechanism` on the five, the operator's values, the convention paragraph, the ADR entry and the map note.

Out of scope: the remaining 20 values, the gate that holds presence, and the survey's families. The 20 await the operator's ratification.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The five reader-context skills carry the operator's `metadata.intent` and `metadata.mechanism`. | Read the five `SKILL.md` frontmatter blocks. | Agent [x] |
| `skill-conventions.md` states the fields are operator-led, defines `mechanism`, and names the provenance and the legacy rollout. | Read `## Frontmatter`. | Agent [x] |
| The shape record holds the decision, its rationale and the rejected alternatives. | Read the 2026-11-16 entry in `docs/adr/principle_skill_shape.md`. | Agent [x] |
| The remaining 20 principles carry the fields with the operator's values. | The operator's ratification. | Operator |
| A gate holds presence once the corpus is filled. | The roadmap row's close. | Open |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A principle declares `metadata.intent` and `metadata.mechanism`, both operator-led. | The intent is obvious to the operator and not to the agent, and the agent re-derives it wrong. The operator authors the value; the agent reads it. | The ADR; the convention |
| `mechanism` is the way the judgement expresses itself, or the specific way the principle exerts influence on the workflow. | The name is qualified. A task's `Mechanism:` is its delivery mode; the skill's field is read in its own context. | The ADR; the convention |
| The admission record that holds the case is the provenance. No third field. | The record already holds the decision, and a second pointer drifts. | The ADR |
| The five reader-context skills are the pilot; the remaining 20 are ratified incrementally, with no baseline. | The field is operator-led, so the values arrive with the operator. A baseline would hide a missing field. | The ADR; the convention; the roadmap row |
| `write-for-the-reader` and `link-what-the-reader-can-open` share the intent and differ in the mechanism. | The intent is the family and the mechanism is the axis. The shared value is the finding, not a duplicate. | This record; the survey map |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| The 20 remaining intent and mechanism values. | The corpus-wide unified read. | The operator supplies them in batches, or the survey's map is the proposal for ratification. |
| The gate's form and the cutover. | The presence check. | A presence gate that lands when the corpus is filled, or a per-skill check at admission. The row's close decides. |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Two skills can share an intent and differ only in mechanism. | record | The intent is the family; the mechanism is the axis. The field pair carries both without a merge. | This record; the survey map |
| `single-train-of-thought` carries its own intent. | record | It is a neighbour of the context family, not a member, consistent with the earlier RT resolution. | This record; the survey map |
| The field is not `metadata.claim` because the operator authors the value. | record | The removed field was agent-led and gauntlet-free. This one records a decision, not a guess. | The ADR |
| The operator's wording is edited only on the operator's ruling. | record | The rewrite-syntax skill now covers a field value and names the disagreement method; a silent edit is the failure it prevents. | The skill; the AGENTS.md index |

## Completed

| File | One-line change summary |
|---|---|
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-define-terminology-before-use/SKILL.md` | Adds the operator's intent and mechanism. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-attach-as-you-read/SKILL.md` | Adds the operator's intent and mechanism. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-single-train-of-thought/SKILL.md` | Adds the operator's intent and mechanism. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md` | Adds the operator's intent and mechanism. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-link-what-the-reader-can-open/SKILL.md` | Adds the operator's intent and mechanism. |
| `.agents/skills/instruction-authoring/references/skill-conventions.md` | Defines the two fields, the provenance and the legacy rollout. |
| `docs/adr/principle_skill_shape.md` | Records the decision, the rationale, the alternatives and the edge cases. |
| `src/reasoning/agent-runtime/pi/config/agent/AGENTS.md` | Names the raise-and-wait rule in the rewrite-syntax entry. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-rewrite-syntax-never-semantics/SKILL.md` | Widens the scope to text a person wrote or approved and makes the disagreement method imperative. |
| `devlog/discussions/20261116-report-concluded-principle_corpus_map.md` | Notes the pilot values and the shared-intent finding. |
| `devlog/roadmap.md` | Adds the field row, open for the remaining 20. |
| `devlog/handovers/M3.3.7/20261116-13-impl-principle_intent_mechanism_fields.md` | This record. |
