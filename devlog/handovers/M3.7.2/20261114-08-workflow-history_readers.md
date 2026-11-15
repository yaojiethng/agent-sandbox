---
date: 2026-11-14
milestone: M3.7.2 - The change model and its refinements
type: Workflow
status: Closed
---

# Handover - The convention names who the history is for

## Objective

Open the convention on the four properties a series must hold, in the field's words, so a rule can be told from a preference.

## Scope

Continues the parent row *The convention leads from history as a commons and owns the primitives* in M3.7.2, from [`20261114-07`](20261114-07-workflow-commit_prompt_operations.md), and serves row 755a with the brief [`.agents/drafts/history-readers-brief.md`](../../../.agents/drafts/history-readers-brief.md).

The ADR decides the convention leads from the history as a commons; no reader is named, so every rule below it is defended by taste. The iteration derives four properties from the history's readers, states them in the convention, and keeps the derivation in the ADR rather than the convention.

Out of scope: rewriting any existing rule against the properties (row 755b, retargeted to them), the message-rule row, and the `history-cleanup` row that cites them.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The convention opens on `## The series` and the four properties, before `## The commit message`. | read the first sections | Agent [x] |
| Each block carries its invariant, the reader it breaks, its check, its rewrite as *instead of X, do Y*, and its source at the foot. | read the four blocks | Agent [x] |
| Each property names an external source. | read the source lines | Agent [x] |
| The ADR records the derivation and the scaffold it came from. | `grep -c 'depend on it for' docs/adr/git_commit_history_commons.md` returns 1 | Agent [x] |
| The four citation records carry the fields `source_tracking.md` states. | read the JSON files | Agent [x] |
| The reader table is not in the convention. | `grep -c 'The readers' .agents/skills/git-discipline/SKILL.md` returns 0 | Agent [x] |
| Lint passes. | `bash scripts/lint.sh` | Agent [x] |
| The row closes with its outcome. | roadmap diff at pre-close | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The properties use the field's words: atomic, bisectable, self-explanatory, blameable. | The field already names them, so a reader meets a word that carries its meaning; a coined word would need the definition the field gives free. | the convention |
| Each block is five lines: the invariant, the reader it breaks, the check, the rewrite, the source. | A property is usable only if an agent can see when it holds, what to do instead, and where the claim comes from. | the convention |
| The source sits at the foot of the block, after the rewrite. | A reader meets the information before the citation, and the name is the citation; the adaptation record is one lookup away. | the convention |
| The reader set is scaffolding, not content. | It produced the properties; each property now names the reader it serves, so the set adds no instruction. The derivation stays in the ADR, which a later reader can follow. | the ADR |
| The delivery commit stands, and *bisectable* is checked on the series above it. | The delivery commit is the trunk's unit; the series above it is what a bisect can walk. | the convention |
| Four citation records; `git-blame(1)` is named inline. | The works argue the properties and this repository adapts them; the manual page is taken as it stands, with nothing dropped to record. | `.agents/registry/citations/` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The first draft's *ordered* property was impossible as stated: on a linear history every commit depends on the one below it, so the property is encapsulation (*atomic*). | record | a property no series can violate | this iteration |
| *no noise* had no external source; it is *atomic* applied to records, so it folded into that block, with Google's *Small CLs* added for the unrelated-churn rule. | record | a property defending itself | this iteration |
| The reader table restated the roles each property's *Violated when* names, and carried two readers no property serves. | record | a second index of the same roles | this iteration: the derivation moved to the ADR |
| Row 755b stated a premise that no longer holds: the rules derived from the reader set. | record | a downstream row built on the removed scaffold | the row retargeted to the four properties |

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/git-discipline/SKILL.md` | `## The series`: four properties with invariant, check, rewrite and source; the one-reader opening sentence is gone |
| `docs/adr/git_commit_history_commons.md` | the derivation and the scaffold, in place of the link sentence |
| `.agents/registry/citations/kernel-submitting-patches.json` | the kernel's logical-change and bisectability rules |
| `.agents/registry/citations/google-small-cls.json` | self-containment, and no unrelated churn |
| `.agents/registry/citations/chris-beams-commit-messages.json` | the seven message rules |
| `.agents/registry/citations/tim-pope-commit-messages.json` | the 50/72 numbers |
| `.agents/drafts/history-readers-brief.md` | `Delete when` retargeted to row 755b |
| `devlog/roadmap.md` | row 755a closes; row 755b retargeted to the four properties |
| (maintenance) | `roadmap-maintenance`: 0 findings; the commit-prompt row compacted last iteration, and no closed row carries open work. |
