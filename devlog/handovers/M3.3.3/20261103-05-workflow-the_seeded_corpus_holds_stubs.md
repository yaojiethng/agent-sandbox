---
date: 2026-11-03
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the seeded corpus holds stubs, so the gap is the answer

## Objective

Close the seeded-corpus question on its second ending -- the gap is stated -- and say why the first ending is not available, so no later unit re-opens a seeding that the corpus's own contract forbids.

## Scope

The roadmap row **An instruction-authoring convention joins the seeded corpus, or the gap is stated**, filed by `20261102-04` when the obligation landed in a project-local skill.

Raised by the operator at the close of `20261103-04`: the skill exists under `.agents/skills/instruction-authoring/`, so the question is whether the row still has work. It does not, and the reason is structural rather than a matter of effort.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The gap is stated where a provisioned project reads the corpus contract | `sed -n '87p' docs/development/instruction-surface-conventions.md` names a stated convention as the project's own and `instruction-authoring` as the case | Agent [x] |
| The row closes with the reason the seeding option is unavailable | `devlog/roadmap.md`, the row, which cites `initialize`'s `## Boundaries` | Agent [x] |
| The finding that filed the row points at its close | `grep -n "closed in \`20261103-05\`" devlog/handovers/20261102-04-*.md` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The row closes on "the gap is stated", and seeding is ruled out rather than deferred | `initialize` ships stubs -- "a failure mode for the agent to reason over rather than a default convention" -- and its `## Boundaries` says the workflow imposes nothing and the stubs answer nothing. A stated bar is the opposite artifact, so seeding it would impose this project's instruction standard on every project, and seeding a stub instead ships a second artifact under one name | the row, the contract doc |
| The statement lives in the contract document, not in `initialize` | `initialize` already restates the corpus contract in its `## Purpose`, and a second copy is the drift this milestone keeps removing; the skill points a reader at the contract, which is where the fact belongs | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row's first option ("seed it as an eighth convention") contradicts `initialize`'s own boundaries, so it was never available as stated | defect in the row | a row offering three options where one breaks the contract invites a later unit to take it | corrected in the row's close |
| `instruction-authoring` cites `docs/adr/principle_skill_shape.md` and `docs/reference/documentation_taxonomy.md`, which a provisioned project does not carry | measured | the skill is not portable as it stands, independent of the stub question | recorded here; a project that wants the bar writes its own |

## Completed

| File | Change |
|---|---|
| `docs/development/instruction-surface-conventions.md` | the corpus paragraph states that a stated convention is the project's own, naming `instruction-authoring` |
| `devlog/roadmap.md` | the row closes with the reason |
| `devlog/handovers/20261102-04-workflow-instruction_modality.md` | its finding points at the close |
