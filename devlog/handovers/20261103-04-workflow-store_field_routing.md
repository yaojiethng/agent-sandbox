---
date: 2026-11-03
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the store's field decision is on the path

## Objective

Stop an agent proposing a store field the pipeline already covers, by putting the decision that settles it where an edge is written, instead of adding a reminder beside a gap.

## Scope

Raised by the operator at the close of `20261103-03`: the agent proposed `absent`, a schema field that restated the local diff the bump already computes, and `principle-delegation-over-machinery` was in context and did not fire.

Diagnosed from the record, per the method: this session's tool-call log at `~/.pi/agent/sessions/--home-agentuser-sandbox--/2026-11-03T00-50-53-935Z_01a19ee3-396f-7581-9812-80cd76f1c1cf.jsonl`, 231 tool calls, every file and line range in order.

## The read-set, from the log

| Read | Range | What it decided |
|---|---|---|
| `scripts/skill_store.mjs` | 40-50, 120-200, 198-215, 319-340 | the field set, so a field looked like one more key |
| `scripts/check_skill_sources.sh`, `scripts/lint/skill_sources.mjs` | gate body, 20 lines | where a finding goes |
| `.agents/skills/skill-fork/SKILL.md` | all 40 lines | vendored vs installed, and the routing table |
| `vendor-bump.md` `## Register an edge` | the section only | the edge's shape |
| `docs/adr/skill_source_catalog.md` | `grep -n anchor` only | nothing: R3 and the field decision were never opened |
| `vendor-bump.md` steps 1-9 | first read at call 222, after the mistake | that the diff is the fact and step 7 re-derives it |

The coverage matrix: of the nine rules that bear on adding a store field, three were on the path and the two that decide it were not. `fork-and-strip.md` - the procedure that registers an edge, steps 1 and 5 - was never opened, because the artifact was already vendored and no routing row names that task.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The routing table names the task the agent was doing | `.agents/skills/skill-fork/SKILL.md` `## Which half` has a row for a fork already in the tree with no edge | Agent [x] |
| `## Register an edge` states what the record is against, and that the field set is decided elsewhere | the read-back sentence and the ADR link under the field table | Agent [x] |
| A cold agent given the narrow task reaches the deciding files | `pi -p` "Register the store edge for the vendored runbook ... say which files you read": `cursor-plugins.json`, `vendor-bump.md`, `skill-fork/SKILL.md`, `skill_source_catalog.md`, `source_tracking.md`, `skill_store.mjs` | Agent [x] |
| The recurrence is recorded on the entry that owns the class | `devlog/AGENT_FEEDBACK.md` 2026-10-29 entry | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The gap is routing, not wording | A cold agent asked to catch a stale record found R3 and rejected a hash on it; the failure was a long session's narrow goal skipping the ADR, so a reminder was compensating for a missing path | this record, the probes |
| One row and one sentence, no new check | The store's own gate already decides the fields; what was missing was where a writer meets that decision | `## Which half`, `## Register an edge` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `skill_source_catalog.md` R3 ("no derived data") and its rejected hash alternative already answer "catch a stale record", and the ADR's field decision is the file that settles whether an edge may gain a field | measured | a store writer who never opens the ADR re-proposes what it rejected | the pointer from `## Register an edge` |
| `fork-and-strip.md` steps 1 and 5 own edge registration, and no routing row names the task "a fork is already in the tree and the store has no edge" | defect | the task has no home, so it is resolved by search and lands on the shape section of a bump document | the new row in `## Which half` |
| The probe on the unpatched tree already rejected a redundant field, so the failure is not reproducible from a cold start | measured | the evidence for the fix is the read-set gap, not a wording failure; a stronger reminder would have been unfalsifiable | recorded here rather than defended |
| `absent` was reverted on the operator's reading that the bump's three-way merge already derives additions and removals | decision | a field that restates a computed diff is a second mechanism | recorded in `## Register an edge` |

## Completed

| File | Change |
|---|---|
| `.agents/skills/skill-fork/SKILL.md` | `## Which half` gains the row for a fork already in the tree with no edge |
| `.agents/skills/skill-fork/patterns/vendor-bump.md` | `## Register an edge` states the diff as the fact, the read-back against it, and that the field set is the ADR's |
| `devlog/AGENT_FEEDBACK.md` | the 2026-10-29 entry records this recurrence, with what the probes showed |
| `devlog/roadmap.md` | the row for this unit |
