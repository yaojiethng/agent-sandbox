---
date: 2026-11-14
milestone: M3.7.2 - The change model and its refinements
type: Workflow
status: Closed
---

# Handover - The fold, the slice and the stack are one method

## Objective

State the fold, the slice and the stack once, at their own grains, so the convention stops carrying a second name for the protocol's split.

## Scope

Continues the parent row *The convention leads from history as a commons and owns the primitives* in M3.7.2, from [`20261114-05`](20261114-05-workflow-working_tree_rule.md).

One row: *The fold, the slice and the stack are one method*. The convention carries `## The fold` and `## The delivery commit and the slice`; the protocol already states one-iteration-one-delivery-commit and defines split and consolidate; the change model already states the early change and the stack. The convention's slice is the protocol's split under a second name.

The row says the delivery-commit section moves to the protocol. Reading the protocol first shows the move is a deletion: the section restates what the protocol and the change model already own, and adds only the name. Nothing is lost by removing it, and a move would add a third copy of the split.

Out of scope: the commit-mechanics row (`/commit`'s three operations and autosquash), which reuses the fold section but owns the prompt.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The convention carries no `## The delivery commit and the slice` section. | `grep -c 'The delivery commit and the slice' .agents/skills/git-discipline/SKILL.md` returns 0 | Agent [x] |
| The convention uses the change model's term: no *slice* outside a pointer to that document. | `grep -c 'slice' .agents/skills/git-discipline/SKILL.md` | Agent [x] |
| The fold section states the one method at three grains and points at the protocol and the change model. | Read `## The fold`. | Agent [x] |
| The delivery-commit rule is stated once, in the protocol; the convention points at it. | the convention holds no rule sentence of its own for it | Agent [x] |
| The citation record names the four tools and carries the fields `source_tracking.md` states. | read `.agents/registry/citations/stacked-diffs.json` | Agent [x] |
| Links resolve and the gates pass. | `bash scripts/lint.sh` | Agent [x] |
| The roadmap row closes with its outcome. | `git diff HEAD -- devlog/roadmap.md` at pre-close | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The delivery-commit section is deleted, not moved. | The protocol states the invariant and the split, and the change model states the early change and the stack; a move would have copied the split into a third document. | this handover |
| The convention adopts the change model's term, *the early change*, and drops *slice*. | One object, one word; the change model already names the flow's event. | the convention |
| The fold section carries one sentence naming all three grains, then the correction rules. | The three are one method at different grains, and a reader meeting the fold needs to know the other two exist and where they live. | the convention |
| The citation is one record naming the four tools. | The four publish the same method under different names; four files would pin four documents to support one sentence. | `.agents/registry/citations/stacked-diffs.json` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row says the section moves; the protocol already owns it, so the move is a deletion. | record | a move would create the third copy the row exists to remove | this iteration |
| The change model already names the slice *the early change* and defines the stack. | record | the convention's second name for it | this iteration |
| The citation's URL cannot be fetched in this container; the record states that and the version is not claimed as read. | record | a citation whose pin is honest rather than checked | the citation record |

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/git-discipline/SKILL.md` | the delivery/slice section deleted; the fold names the three grains and points at the protocol and the change model |
| `.agents/registry/citations/stacked-diffs.json` | the four tools, the method kept, the tool declined |
| `devlog/roadmap.md` | the row closes, compacted |
| (maintenance) | `roadmap-maintenance`: 0 findings; the working-tree row compacted last iteration, and no closed row carries open work. |
