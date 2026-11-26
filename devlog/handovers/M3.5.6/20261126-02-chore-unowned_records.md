---
date: 2026-11-26
milestone: M3.5.6 - The discussion record corpus
type: Implementation
status: Closed
---

# Handover - Five discussion records, each deleted into its carrier

## Objective

Delete the five live discussion records that no open row owns and whose decision an ADR, a milestone or the principle corpus already carries, and correct every carrier that still pointed at one.

## Scope

Rows 1 and 2 of `M3.5.6`. Five files deleted, four citations re-pointed, one ADR section retired, one deferred scope statement corrected.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The five records are gone and listed by their removal commit. | `git ls-tree -r HEAD^ devlog/discussions \| grep -c 'code_agent_binding_surface\|retire_the_policy_form\|sentence_structure'` answers 3 | Agent [x] |
| No live document links a deleted record. | `bash scripts/lint.sh`; `bash scripts/check_record_citations.sh` both clean | Agent [x] |
| The ADR states that the structural moves landed, and defers to no record. | `grep -n 'In development' docs/adr/coding_agent_project_bindings.md` answers nothing | Agent [x] |
| The deferred artifact scope names where the nine-artifact census is recorded and why a generator is rejected. | `grep -n 'Building a generator is rejected' devlog/roadmap_future.md` | Agent [x] |
| A closed roadmap row names the deleted record as an id, never a link. | `grep -n '20261014-design-settled-coding_agent_binding_surface' devlog/roadmap.md` shows code spans only | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Delete all five in one change rather than one commit each. | They are one class -- a record whose carrier already holds its decision -- and each deletion's removal commit holds the file. | This record |
| The ADR's `### In development` heading retires with its claim. | The moves landed at `M3.3.2`, so the heading was the only thing still asserting otherwise. | `docs/adr/coding_agent_project_bindings.md` |
| The deferred scope gains R1--R4 as one line, not a section. | The rejections answer the section's first question, and the section is indefinitely deferred. | `devlog/roadmap_future.md` |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The plan measured the citation surface in files, not links: the two live files carried four links, and two of them were in a deferred section and an ADR body rather than in a closed roadmap row. | measurement | a deletion that trusted the plan's count would have left two dangling links | this record |
| `docs/adr/coding_agent_project_bindings.md` cited the retired-policy-form record from a decision body, not only from its development section. | record | the ADR pointed at evidence its own decision carried | this record |
| The deferred artifact scope cited the deleted record as the home of its nine-artifact classification. | record | the section would have sent its next reader to a deleted file | this record |
