---
status: Closed
milestone: M3.2.2
type: Workflow
date: 2026-10-29
---

# Handover - the milestone's tail, in one batch

## Objective

Close the last construction work in M3.2.2 and discharge the five items the previous close left as notes: the policy note that names where a language-agnostic code-shape rule lives, an index entry that appeared twice, an ADR that still names a retired surface, and three rows that had been raised in chat and never filed.

## Scope

Six edits over four files and the roadmap. The batch is one unit because each item is a record or an instruction surface that names a state the tree no longer has, and none needs a design decision.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No principle appears twice in the communication index | `grep -c 'one-addressing-axis'` over the provider layer returns one line | Agent [x] one bullet |
| The installed copy equals the source | `diff -q` reports nothing | Agent [x] identical |
| The conventions state where a rule that holds in every language belongs | read the policy note: it names the two `When writing code` sections | Agent [x] present |
| The ADR names no retired surface as a live one | read the 2026-10-14 decision: four surfaces, and `document` is named only as retired | Agent [x] corrected |
| The persona row is out of the task list and in the milestone's Not in scope | `grep -c 'persona'` finds no `- [ ]` row | Agent [x] moved |
| The flaky test is filed under M3.1.2 | the row sits under `##### M3.1.2` | Agent [x] filed |
| The feedback record's ownership is parked under M3.5 | the row sits under `#### M3.5` | Agent [x] filed |
| Both consolidation rows are ticked with this record | the parent and the general-plane child carry `[x]` and cite a handover | Agent [x] ticked |
| The gates and the suite are clean | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] both clean |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The persona row moves to Not in scope rather than being ticked and left in the task list | The task-list convention puts an indefinitely deferred item under the milestone's Not in scope section, and a ticked row would read as work that landed | this record, roadmap `:208` |
| The duplicate index entry is removed from the prose, not from the bullet list | The bullet carries the rule text and the prose line carried only the name, so the prose was the copy | this record |
| The ADR is corrected in place with the retirement dated | The record is current and edited in place, and the enumeration is a claim about the tree rather than a history of it | this record |
| The conventions note names the two layer sections rather than adding a category | A code-shape rule that holds in every language has no subject of its own; the layers already state the ladder, so a category would duplicate it | this record |
| The flaky test and the feedback record are filed rather than fixed | Neither is a single edit, and the milestone that owns the gates and the milestone that owns records are named | this record |

## Decisions pending

None.

## Findings

- **The campaign against one-off defects does not stop the next one.** Three of this batch's items were raised in chat during earlier iterations and noted in handovers rather than filed, which is what the task-list convention calls a single-edit defect that a sweep produces as one commit. They survived because the note was written where the next iteration reads records, not the roadmap.
- **Only one carrier named the retired `document` surface.** The sweep for it found the ADR and nothing else; the statechart's "drafting a document" line describes a document, not the prompt.

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | The duplicate `one-addressing-axis` line removed from the prose block |
| `$AGENT_HOME/agent/AGENTS.md` | Installed copy refreshed |
| `docs/development/conventions.md` | The policy note for a language-agnostic code-shape rule |
| `docs/adr/coding_agent_project_bindings.md` | The maintenance-surface enumeration names four skills and dates `document`'s retirement |
| `devlog/roadmap.md` | The persona row moved to Not in scope, the two consolidation rows ticked, the flaky test filed under M3.1.2 and the feedback record under M3.5 |
