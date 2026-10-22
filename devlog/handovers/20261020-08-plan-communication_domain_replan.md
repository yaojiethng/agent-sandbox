---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Plan
status: Closed
---

# Handover - re-plan the communication domain

## Objective

Write one page that states what the census chain produced, what is settled, what is unknown and what will not be done, and cut the communication-surface filing from it.

## Scope

The M3.3.4 row **The communication-domain re-plan**. The deliverable is one design record plus the roadmap rows that page writes. The filing is cut from this page, and the iteration between them is the duplication map the page defines.

Out of scope, with reason: the filing itself; and the retirement of `20261019-design-draft-prose_standards_specs.md`, which stays until the filing closes because it is the only map from a judgement line to its proposed group.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The page exists, settled, and states the two-class triage | read `devlog/discussions/20261020-design-settled-communication_domain_replan.md` `## Decision` | Agent [x] |
| The page applies the landed home rule and cites its home | `grep -n "agent_workflow.md" devlog/discussions/20261020-design-settled-communication_domain_replan.md` finds the kind table | Agent [x] |
| The seven dedupe groups are subsumed rather than restated | the page's `## Decision` names the map as the successor of the dedupe table | Agent [x] |
| The filing is cut from the map, not from the page's prose | `grep -n "Cut from \*\*The cross-document duplication map\*\*" devlog/roadmap.md` finds the filing row | Agent [x] |
| The scaffolder's alignment is scoped and it is now editable | the page's `## Decision` names the alignment and the repo-owned copy; `test -d ~/.pi/agent/skills/skill-scaffolder` passes | Agent [x] |
| No census, no classifier call, and no deletion rides this iteration | `git status --short` names the page, the roadmap and this record only | Agent [x] |
| Every decision this iteration records is realized in the files | read this record's `## Decisions` against the tree | Operator [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The home rule applies as landed; the page does not re-open the skill-versus-in-place fork | `docs/reference/agent_workflow.md` `### Norm kinds` already states it, and handover `20261020-04` AC9 retired the older claim | the page, `## Decision` |
| Class 1 is a judgement used by two or more documents and becomes a skill; class 2 is one document's judgement that should generalise, flagged for review and not landed | the rule decides the home; the classes decide what is landed now and what is a candidate | the page, `## Decision` |
| The dedupe table is subsumed by the duplication map, not kept beside it | the dedupe table is within-document only, so one table carries both the dedupe groups and the cross-document overlap | the page, `## Decision` |
| Two iterations: the duplication map alone, then the filing | the map is the filing's work list, and the filing cannot be scoped without it; together they would be a page, a table and three surfaces of edits in one review | the page, `## Decision`; the roadmap rows |
| `skill-scaffolder` is editable by operator grant, and its repo-owned copy seeds the installed skill | an edit to the container copy alone is lost on the next image; the fix ships only from the repository | the page, `## Decision` |
| The spec census's exit is `rejected` then archived at the filing's close | it is a `draft`, and the status vocabulary does not move a draft to `superseded` | the page, `## Consequences` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The re-plan row cited handover `20261019-12`, which is the classifier-prompt iteration | record defect | corrected by this iteration's landing note | this record |
| `20261020-07` Completed names `20261019-design-settled-neutral_principle_census.md` as restored, and the file does not exist | record defect, closed record | a correction tag in the map iteration | the roadmap row **The cross-document duplication map** |
| The seven dedupe groups sit inside one document each, so they are within-document restatement and cannot size the tranche | result | the cross-document overlap was never enumerated; the map is that enumeration | the page, `## Decision` |
| `skill-scaffolder` exists only at `~/.pi/agent/skills/`, in neither repo skill root | result | the repo has never owned it, which is why its duplicate template persisted | the page, `## Decision` |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/20261020-design-settled-communication_domain_replan.md` | new settled page: the home rule applied, the two classes, the two-iteration sequence, the scaffolder alignment |
| `devlog/roadmap.md` | the re-plan row marked done with its landing note; new row **The cross-document duplication map**; the filing row rewritten to be cut from the map |
| `devlog/handovers/20261020-08-plan-communication_domain_replan.md` | this record |
