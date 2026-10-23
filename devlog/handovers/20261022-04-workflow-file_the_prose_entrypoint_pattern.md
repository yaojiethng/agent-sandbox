---
date: 2026-10-22
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - File the prose-entrypoint pattern

## Objective

File the capability-exposure pattern as a skill-writing pattern under `skill-scaffolder`, indexed from its `SKILL.md`, so an author writing a skill that wraps a script meets the judgement where the skill is shaped.

## Scope

Continues the interrupted iteration [`20261022-02-workflow-testing_policy_into_the_skill.md`](20261022-02-workflow-testing_policy_into_the_skill.md) at its pre-close gate.

A second operator-directed sidequest, sourced from the operator's handoff at `~/workspace/output/handoff-prose-entrypoint-pattern.md`. The handoff was written without visibility into this session and proposed a principle skill in the config-home corpus. The operator redirected it: this project's skill-writing mechanism is a pattern under `skill-scaffolder`, the same shape the previous sidequest filed. The judgement and its criteria are in the installed copy at `$AGENT_HOME/agent/skills/principle-prose-entrypoint-over-mechanism/SKILL.md`; this session carries them into the pattern.

In scope: the pattern file and the `skill-scaffolder` index row and dispatch sentence.

Out of scope: creating a principle skill or a `claim`; the installed copy (it is outside the repo and the config home reseeds at every start, so it is transient); the authoring-convention paragraph and the norm ledger the handoff proposed; correcting the seven principle skills that set `disable-model-invocation` (recorded as a finding); the dispatch-mechanism run's files and commit `119c9201`; and `docs/reference/dispatch.md`, which does not exist.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The pattern carries the table, the why, the three conditions, the five withholding cases, the boundary and the test | `grep -n '^## '` over the new file names all six | Agent [x] |
| The scaffolder dispatches at intent and indexes the pattern with its situation | `grep -c 'patterns/prose-entrypoint.md' .agents/skills/skill-scaffolder/SKILL.md` prints 2 | Agent [x] |
| The pattern names the dispatch instance in prose and links no project path | `grep -in 'dispatch'` names it; `grep -c 'docs/'` prints 0 | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| File it as a pattern under `skill-scaffolder`, not as a config-home principle skill | Operator direction: the handoff predates this session's pattern mechanism. The pattern reaches the author where a skill is shaped, and it needs no claim, no ledger row and no shipped-corpus policy | this record; the operator's direction |
| The pattern carries the criteria, not a link to them | The installed skill is transient; the pattern is the durable copy, and its criteria are the substance | this record |
| No ADR | The operator rejected one in the handoff; this is a skill design pattern, not a settled architecture decision | the handoff |
| The `disable-model-invocation` finding is recorded, not fixed | The convention's rule stands and the seven holders are a pre-existing corpus defect; correcting them is outside this sidequest's one slice | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The handoff routed the pattern to the config-home principle corpus, written before the pattern mechanism existed; the installed copy is the only copy and the config home reseeds at every start | process | the pattern would have been filed in the wrong form and the criteria would have lived in a corpus the shape gate requires a claim for. The pattern is the durable home | the operator's redirect; this record |
| Seven principle skills set `disable-model-invocation: true` against the convention's rule that a judgement skill must not, measured across the three instruction roots | defect | the field hides a judgement from the model, so the writer who needs it cannot find it; the corpus disagrees with its own rule | roadmap row `The judgement corpus disagrees with its own disable-model-invocation rule` |

## Completed

| File | Change |
|---|---|
| [`.agents/skills/skill-scaffolder/patterns/prose-entrypoint.md`](../../.agents/skills/skill-scaffolder/patterns/prose-entrypoint.md) | the prose-entrypoint pattern, carried from the installed copy's criteria |
| [`.agents/skills/skill-scaffolder/SKILL.md`](../../.agents/skills/skill-scaffolder/SKILL.md) | the step-1 dispatch and the index row |
