# 20260919-16-workflow-task_type_boundary_reframe

- **Handover:** 20260919-16
- **Type:** Workflow
- **Milestone:** M2.6 - Session Persistence (governance)
- **Dates:** 2026-09-19
- **Status:** Closed

## What this iteration does

Reframes the task-type taxonomy so the handover type and the git commit type
are decoupled. The handover type is set at scope time and names the
deliverable; the commit type is set at close and names the landed diff, decided
from the diff alone. This resolves the feature-vs-workflow ambiguity recorded in
AGENT_FEEDBACK session 20260919-15.

Handover types split into an active set (impl, discussion, plan, design, docs,
workflow, chore, audit) and a deprecated set (story, study, spec). The
minor-loop-step framing is removed because one minor loop equals one handover,
so scoping routes a type to a step is wrong from the start.

Commit types keep their set (feat, fix, refactor, docs, chore, workflow, test,
build). `impl` is the catch-all handover for behaviour work; the commit type
disambiguates the subclass (feat for new capability, fix for a correction,
refactor for a restructure) at close. The commit type is decided from the diff
alone, independent of the handover type.

## Scope

- Rewrite the `## Types` table in `docs/operations/handover_policy.md`: the
  active set (impl, discussion, plan, design, docs, workflow, chore, audit) and
  the deprecated set (story, study, spec), each with its deliverable and commit
  mapping.
- Update the `**Type:**` field enumeration in `docs/operations/handover_policy.md`.
- Remove the handover-mapping column from the Active Types table of
  `docs/operations/git_policy.md`; the commit type is decided from the diff,
  independent of the handover type.
- Amend the `## Iteration Lifecycle` guard paragraph in the project-root
  `AGENTS.md` to add the sole carveout: a chore commit may land with no
  handover when the operator explicitly requires it.
- Close the AGENT_FEEDBACK `[A] 2026-09-19 Task-type classification is
  ambiguous between feature and workflow` entry.
- Create ADR `docs/adr/task_type_taxonomy.md` recording the decoupling
  principle, the boundary rules, and the removal of the handover-git link.

## Decisions

- Decouple the handover type from the commit type. They answer different
  questions at different times: the handover type is the deliverable at scope
  time, the commit type is the diff makeup at close.
- Keep `impl` as the catch-all for behaviour work, because at scope time it
  may not be clear whether a requested change is a fix or a new capability.
- Restore `design` as an active type (option Y): design is the jump-right-in
  decision and evaluation work (ADRs, investigations, option evaluation, ADR
  maintenance), often interleaved with `impl` commits. `plan` is the
  administrative major-loop framing: a large task list and milestone scoping.
  Calling interleaved design+impl work a plan would misread as badly ordered
  delivery.
- Roll `study` and `spec` into `design`. Roll `story` into `discussion`.
  Three deprecated types are still declared so historical handovers remain
  readable.
- `chore` is the small, administrative, or cosmetic case. A change that is not
  mostly administrative or cosmetic is `refactor` or `audit`.
- `audit` is a compliance or review sweep. It usually produces a report or a
  non-content reordering sweep. Code changes from a sweep are `refactor`.
- The commit type is decided from the diff alone, independent of the handover
  type. No cross-table mapping couples the two policy documents.

## Acceptance criteria

| # | Criterion |
|---|---|
| AC1 | The handover Types table lists the active set (impl, discussion, plan, design, docs, workflow, chore, audit) and the deprecated set (story, study, spec), each with a deliverable and commit mapping |
| AC2 | The git_policy Active Types table carries no handover-mapping column; the commit type is decided from the diff |
| AC3 | The AGENTS.md guard text carries the chore carveout with no other exception |
| AC4 | The AGENT_FEEDBACK ambiguity finding is closed with a mitigation pointing at this reframe |
| AC5 | ADR `docs/adr/task_type_taxonomy.md` records the decoupling principle, the boundary rules, and the removal of the handover-git link |
| AC6 | No code or test behaviour changes; the taxonomy is documentation-only |
| AC7 | Changes follow documentation-policy prose rules (one paragraph per physical line, plain ASCII) |