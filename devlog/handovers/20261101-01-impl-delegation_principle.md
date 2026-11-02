---
date: 2026-11-01
milestone: M3.3.3 - The skill maintenance pipeline
type: Implementation
status: Closed
---

# Handover - the delegation principle lands in the provider skill root

## Objective

State the delegation judgement as a principle skill so a later agent meets it while sizing a change, rather than rebuilding a party's guarantee beside it.

## Scope

The roadmap row `State the delegation judgement as a principle`, whose content the draft handoff `.agents/drafts/delegation-principle-handoff.md` had settled. The draft is consumed and deleted with this record.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill and its maintenance record exist in the provider root | `ls src/reasoning/providers/pi/config/agent/skills/principle-delegation-over-machinery/` | accepted |
| The corpus shape holds: the pattern leads, the named parts sit between `**Why.**` and `**The test.**`, and the test closes | `bash scripts/check_document_shape.sh` | accepted, clean across 28 principle skills |
| The record gate accepts a home-grown record | `bash scripts/check_skill_sources.sh` | accepted |
| The tree passes its gates | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | accepted, 17 gates clean and 1412 of 1412 tests |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `delegation` is the leitwort, not `reuse` | reuse names an artifact; delegation names a responsibility, which is what the judgement turns on | the record's `## Name` |
| The bare `principle-` form, no domain prefix | the judgement holds wherever a task reaches for machinery, not on one surface | the record's `## Name` |
| The three exceptions are named parts, not a list under the pattern | each answers a different situation, and the shape gives a part to a situation | `SKILL.md` |
| The test asks for two names per added mechanism | a guarantee the owner lacks, and a failure the owner's mechanism would miss; two empty answers are the deletion signal | `SKILL.md` `**The test.**` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| none | -- | -- |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The provider root's skills carry a `MAINTENANCE.md` only when they are vendored, while the record gate reads every skill directory in the agent and provider layers | correction | the draft's "every one has a record" was wrong; the new record took the home-grown form the gate accepts | this handover, Decisions |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/principle-delegation-over-machinery/SKILL.md` | the principle: the parties table, the tell, the three exceptions, the neighbouring judgement and the test |
| `src/reasoning/providers/pi/config/agent/skills/principle-delegation-over-machinery/MAINTENANCE.md` | the home-grown record, with the milestone that produced the judgement and its four-part adaptation form |
| `.agents/drafts/delegation-principle-handoff.md` | deleted, its task landed |
| `devlog/roadmap.md` | the row closed, its handoff link replaced by this record |
