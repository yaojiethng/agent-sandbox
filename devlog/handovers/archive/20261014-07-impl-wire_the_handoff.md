---
date: 2026-10-14
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Implementation
status: Closed
---

# Handover - The handoff wired into the steps

## Objective

Make every workflow step read the project's conventions through the settled handoff, so no step carries the workflow's own record layout.

## Scope

The implementation stage of the roadmap row **Wire the handoff into each workflow step**, consuming the contract settled at handover `20261014-06`. The contract: a step names the convention it needs and the path `.agents/skills/<convention>/SKILL.md`, reads that file for the project's structure, and states the failure when the file is absent or holds a stub.

In scope:

- Provision agent-sandbox's convention-skills under `.agents/skills/`, one directory per convention, as **thin files**: each names the structure this project uses (the record paths and formats) and links the workflow's policy document that holds the rule. They are provisioned pointers, not the full conventions; `Retire the policy form` turns each into the full file. They differ in meaning from the shipped corpus stub, which states that nothing is provisioned. The project carries none today, so the status quo lives only inside the shipped prompts; the wiring has nothing to resolve against until they exist.
- Rewire the fourteen prompts and six skills: each step names the conventions it needs and the handoff path, and states the failure.

The boundary with `Retire the policy form`: a convention-skill states the **structure** (where a record lives and its format), while the workflow keeps the **procedure and the rules**. Moving the rules out of the policy documents is that row's work, and it stays out of scope.

Out of scope, each with its row: the rules' move (`Retire the policy form`); the feedback-record convention; the discussion filename sweep; the instruction-root reference gate.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Agent-sandbox's conventions exist under `.agents/skills/`, one per convention, each a thin file naming the structure and linking the rule document | the directory listing, and reading one | Operator [x] |
| Every prompt and skill names its conventions and the handoff path `.agents/skills/<convention>/SKILL.md` | grep for `.agents/skills/`, checked against the mapping table | Operator [x] |
| Each step states the failure when the skill is absent or a stub | reading the changed steps | Operator [x] |
| The thin files state structure and defer the rule; no rule content moves out of the policy documents | reading a thin file against `docs/policies/` | Operator [x] |
| Architecture documents in scope describe the system as built | read the changed sections | Operator [x] |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | run both | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`.agents/skills/`](../../../.agents/skills/) | new: agent-sandbox's convention-skills, one per convention |
| [`workflow/coding-agent/prompts/`](../../../workflow/coding-agent/prompts/) | fourteen prompts rewired to hand off |
| [`workflow/coding-agent/skills/`](../../../workflow/coding-agent/skills/) | six skills rewired to hand off |
| [`workflow/coding-agent/skills/initialize/SKILL.md`](../../../workflow/coding-agent/skills/initialize/SKILL.md) | the installer the handoff depends on |
| [`devlog/discussions/20261014-design-settled-handoff_contract.md`](../../discussions/20261014-design-settled-handoff_contract.md) | the settled contract and the mapping |
| [`devlog/roadmap.md`](../../roadmap.md) | the row write-back at close |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Agent-sandbox's convention-skills are thin pointers: structure named, rule deferred to the policy document | keeps this iteration scoped to the handoff and avoids pre-empting `Retire the policy form`, which turns each into the full convention | this handover |
| Each step carries one `## Project conventions` block naming its conventions and `.agents/skills/<name>/SKILL.md` | one handoff form across the fourteen prompts and six skills; the body's own paths stay as this project's values, which keeps the rewrite minimal | this handover; [`prompt-authoring-conventions.md`](../../../docs/development/prompt-authoring-conventions.md) |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The wiring is coupled to provisioning: the record paths the steps carry are agent-sandbox's conventions, so extracting them needs the conventions to exist first. Surfaced at scope time. | contradiction | current iteration |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | roadmap maintenance check: the roadmap reflects the close of handover `20261014-06`; M3.3.1 is `In progress`. No maintenance edit was needed. |
| [`.agents/skills/`](../../../.agents/skills/) | new: seven thin convention-skills, one per convention, each naming the structure and linking the rule document |
| [`workflow/coding-agent/prompts/`](../../../workflow/coding-agent/prompts/) | fourteen prompts gain the `## Project conventions` block |
| [`workflow/coding-agent/skills/`](../../../workflow/coding-agent/skills/) | five skills gain the block; `initialize` installs the corpus rather than consuming one, so it is excluded |
| [`docs/development/prompt-authoring-conventions.md`](../../../docs/development/prompt-authoring-conventions.md) | the block form is documented in `## Structure of a workflow document` |
| [`devlog/roadmap.md`](../../roadmap.md) | row write-back at close |
