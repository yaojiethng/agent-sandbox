---
status: Closed
milestone: M3.2.2
type: Workflow
date: 2026-10-29
---

# Handover - the instruction surface conventions, cleaned

## Objective

Take the document that states how the two instruction layers and their gates work, and remove what its readers cannot act on: prose that narrates how the rules were arrived at, a claim about a gate that the gate does not make, and paragraphs that carry several rules at once.

## Scope

One document, `docs/development/instruction-surface-conventions.md`, run through the `instruction-cleanup` runbook of `prose-review`. The pass follows the two rows closed before it: the communication index made the instruction surfaces readable, and reading them turned up this document's lapses.

Not in scope: the gates the document describes. The row filed for the layer copy's missing comparison is gate upkeep, and nothing here builds it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The claim that a gate compares the layer's source with its installed copy is gone | `grep -c 'prove they match'` returns nothing | Agent [x] Agent run: none |
| The prose that narrates how a rule was arrived at is gone | `grep -c 'rejected alternative'` returns nothing | Agent [x] Agent run: none |
| Each rule in the layer section stands in its own paragraph | read the section: the layer split, what a layer may say, where the rule lives, and editing a layer are four rules in four paragraphs | Agent [x] Agent run: as split |
| No rule the document stated before is lost | the previous revision read against the cleaned one, rule by rule | Agent [x] Agent run: every cut sentence ruled on, and its rule named in the decisions table |
| The document describes the surfaces the tree builds | the provider layer's index is described as an index of the principle skills, which is what the layer holds | Agent [x] Agent run: the layer lists sixteen family skills and the terminology principle, which now carries the prefix |
| Every decision recorded here is realized in the file | each row of the decisions table read against the document | Agent [x] Agent run: each row edits the site it names |
| The links still resolve | `bash scripts/check_reach.sh` and the linking gate | Agent [x] Agent run: both clean |
| The roadmap row names the pass and closes with this handover | the row cites this record | Agent [x] Agent run: filed; ticked in the commit that closes this record |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Rewrite "the model behind them" as "the schema behind them" | A reader meets "model" in this repository as the language model, and the sentence means the manifest's shape | this record |
| Split the paragraph that carries the runtime-path rule from the one that carries the module's payload | Two rules in one paragraph, and the second is the one a reader arrives for | this record |
| Cut the narration of what the framing file states, keeping the pointer | The reader can open the file; the sentence narrating its contents answers a question the pointer already answers | this record |
| Rewrite the layer section's opening as a list of what each layer holds | "carry the same claim one level up" names a relation to a claim the reader has not been shown, and the paragraph then describes two different things under one subject | this record |
| Cut the rejection history from the layer section, keeping the rule it defends | The rule survives as "a rule about where sections belong lives here, not in either layer", and the history is in the handovers that made the decision | this record |
| Correct the installed-copy sentence to the procedure only | The convention told a maintainer to let a gate prove the two copies match, and that gate does not read the copy. The gap is filed under gate upkeep rather than described as closed | this record |
| Cut the closing summary from the gates section | It restates the failure modes the paragraph above enumerates, and adds a claim about drift that the gate descriptions already carry | this record |
| Split the module payload paragraph at the harness roots | The paragraph runs from a module's package entry to the harness's own roots, which is a second subject | this record |
| Merge the working-surface test into one sentence | It restated the paragraph above it, then applied it twice | this record |
| Cut the record of the reverted attempts from the project-tree section | The rule and its reason survive; the attempts are in the handovers | this record |
| Cut the second statement of the layer-table split | The gates section states the same check | this record |
| Cut the subject table's restatement of its own gate | The gates section enumerates the same failures twenty lines below | this record |

## Decisions pending

None.

## Findings

- **The document's text shrank while its line count rose.** A prose paragraph is one physical line here, so the only thing that adds a line is a new paragraph, and the four splits add four. Measured against the previous revision, the pass removed more words than it added.
- **The convention's installed-copy procedure has no check.** Corrected in the document, and filed as gate upkeep: `scripts/check_instruction_surfaces.sh` never reads `$AGENT_HOME/agent/AGENTS.md`.
- **The document's nine sections under `## The layers` are not one subject.** The cleanup split the prose, and the shape stays: the heading governs the layer split, the subject table, the ruling classes and the layer's copy procedure. Restructuring the headings is a larger change than this pass and is not proposed.
- **`## Scope` is a heading of this document and also the name of a section in each layer.** A reader searching the document for the layer's scope section meets the surface-scope section first. Flagged, not changed.

## Completed

| File | Change |
|---|---|
| `docs/development/instruction-surface-conventions.md` | Eight rulings applied |
| `devlog/roadmap.md` | Row filed |
