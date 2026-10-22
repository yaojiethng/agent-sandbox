---
date: 2026-10-05
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - Move the Loop-Prompt Inventory to the Project Layer

## Objective

Give the loop-prompt inventory one home in the project layer, leave `iteration_policy.md` holding the invariants the runbooks must not break, and put a gate behind the inventory so a missing or stale entry fails.

## Scope

One roadmap row, absorbed with the operator's direction that closes handover `20261005-02`:

- **The project AGENTS.md names one loop prompt out of eight** -- this row becomes the vehicle. The inventory moves rather than being pointed at, so the row's question (a table that mirrors, or a line that links) is settled by the move: with one home there is nothing to mirror, and a table cannot drift from itself.

Operator direction, stated at the scope gate: `iteration_policy.md` `## Loop workflow prompts` gives up the inventory; the project layer gains it; the policy keeps the boundary statement that the runbooks hold the procedure and the policy holds the invariants. Provenance is cut hard: the table names which verbs exist and where each lives, and nothing else -- no milestone ownership, no draft status, no future verbs. Prompts under `workflow/coding-agent/drafts/` are cut from the inventory entirely (`/sequential-work`, `/parallel-work`), as are `/auto` and `/goal`, which have no file.

Ruled out of scope, each already carried elsewhere: the two draft prompts' own work, on the roadmap under the work-loop expansion; the retirement of the interim `docs/operations/` bundle, the M3.3.1 goal row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The project layer carries the inventory: seven loop verbs, each naming the file it runs from, with no provenance column | read the table; seven rows | Agent [x] -- seven, not the six named below: see the finding |
| `iteration_policy.md` keeps the boundary statement and lists no prompt; its invariants still bind the runbooks as a class | read the section; no runbook path in a list | Agent [x] -- the runbook paths live in the frontmatter `scope`, and the section states that |
| No draft prompt and no unwritten verb appears in the inventory | `grep` the layer for `drafts/`, `/auto`, `/goal` | Agent [x] -- absent |
| The gate fails when an inventory entry names a file that does not exist | a fixture case | Agent [x] -- the entry is a link, so the existing link check owns it; the run is clean |
| The gate fails when a loop verb exists and the inventory omits it | a fixture case | Agent [x] -- `test_inventory_omitting_a_scope_prompt_flagged`, and its mirror for an ungoverned row |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | both commands | Agent [x] -- 7 gates clean; 1080 tests, 0 failed |
| The table's shape and the boundary statement's new home are accepted | operator acceptance at the release gate | Operator [x] -- released |

## Hot files

| File | Why in scope |
|---|---|
| [`AGENTS.md`](../../../AGENTS.md) | gains the inventory, in the section that already routes the iteration loop |
| [`docs/operations/iteration_policy.md`](../docs/operations/iteration_policy.md) | `## Loop workflow prompts` gives up the list and keeps the boundary statement |
| [`scripts/check_instruction_context.sh`](../../scripts/check_instruction_context.sh) | already parses the two layers' tables, so the inventory's check has a home here |
| [`tests/test_instruction_context.sh`](../../tests/test_instruction_context.sh) | the fixture cases for the new check |
| [`workflow/coding-agent/prompts/`](../../../workflow/coding-agent/prompts/) | the six loop verbs, and the seven other prompts that are not loop verbs |
| [`devlog/roadmap.md`](../../../devlog/roadmap.md) | the row, and the write-back |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The inventory's home is the project layer, and `iteration_policy.md` keeps the invariants | the inventory is a map of the tree, and the layer is where an agent looks for what it can invoke; the policy's own sentence already delegates the procedure to the runbooks, so a list of their paths in the policy restates the directory rather than the rule. Operator direction. | the project layer, and `iteration_policy.md` |
| The policy's `scope:` frontmatter keeps its own meaning and stays as it is | it names the runbooks whose procedure the policy constrains, which is a narrower set than the loop inventory; with the section's list gone it is the policy's only list, and the boundary statement says which axis it is | `iteration_policy.md` `## Loop workflow prompts` |

## Decisions pending

| Question | Blocks | Options |
|---|---|---|
| How does the check know which prompts are loop verbs, so it can catch an omission as well as a stale entry? | the gate's completeness direction, and whether six prompt files gain a frontmatter key | (a) Each loop-verb prompt declares itself with a frontmatter key, and the check compares that set with the inventory -- the prompt owns its role, and pi ignores the key, so the cost is a convention on six files. (b) The check holds the verb list and compares both ways -- no convention change, and the check becomes a third copy of the list. (c) The check reads the frontmatter `scope:` of `iteration_policy.md` -- no new key, and that set is not the loop inventory (it holds `/document` and omits `/sidequest`), so it would need renaming first. |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The inventory carries seven verbs, not the six the scope gate named. The check equates the inventory with the policy's `scope`, and `documentation_policy.md` defines `scope` as the records and runbooks the file governs; the policy governs `/document`, since it is read at the start of any iteration and `document.md` is the peer of `iter.md` for a documentation iteration. Cutting the row would have made `scope` under-declare. Approved at the release gate. | scope change | current iteration | Triaged to: the layer's table and the policy's `scope`, both of which carry it |
| The gate's table parsers exited on `/^## /`, which this image's awk reads as a literal pattern rather than an interval, so a table under a level-3 heading ran on into later sections when no level-2 heading separated them. The real tree masked it, because `## System` sits between `## Scope` and the inventory; the new fixture exposed it. The parsers now exit on a heading of level two or shallower. | bug | current iteration | Triaged to: `scripts/check_instruction_context.sh` |
| The gate cannot see a loop verb that is added to `workflow/coding-agent/prompts/` and named nowhere: with no marker on the prompt, a new verb is indistinguishable from the six invocable non-verbs. The prompt-declared-marker option was rejected to keep the prompt specification free of nonfunctional keys. Row 189's defect -- the policy named eight and the layer one -- is caught. | obstacle | next iteration | Triaged to: recorded here; no roadmap row, since the operator chose this coverage knowingly |
| `docs/operations/iteration_policy.md` no longer lists the two draft prompts. Their work and ownership stay on the roadmap, so nothing was lost, and the layer names them nowhere, per the scope gate. | steering | current iteration | Triaged to: the policy section and the layer |

## Completed

| File | Change |
|---|---|
| `AGENTS.md` | gains `### Loop prompts` in `## Iteration Lifecycle`: the seven verbs, each linked to its file, with no provenance |
| `docs/operations/iteration_policy.md` | `scope` becomes the seven-verb list, the single declaration of them; `## Loop workflow prompts` keeps the boundary statement, points at the layer's inventory, and drops the annotated list |
| `scripts/check_instruction_context.sh` | checks the layer's inventory against the policy's `scope` both ways, and its table parsers exit on any heading of level two or shallower |
| `tests/test_instruction_context.sh` | the conforming fixture gains the inventory and the policy `scope`; 2 cases, for an omitted scope prompt and an ungoverned inventory row |
| `docs/development/instruction-context-template.md` | the gate's list gains the inventory check |
| `devlog/roadmap.md` | the row resolved |
