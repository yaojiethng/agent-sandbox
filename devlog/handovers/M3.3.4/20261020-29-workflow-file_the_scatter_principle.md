---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - file the scatter principle and amend one home per rule

## Objective

Give the scatter defect an owner, and state from the one-home side the distinction that stops a reader folding the two rules into one.

## Scope

The roadmap row **File `communication-principle-dont-scatter-what-belongs-together` and amend `principle-one-home-per-rule`**, acting on the decision in `20261020-27`. The source paragraph is `docs/development/prompt-authoring-conventions.md` line 44.

Out of scope: the progressive-disclosure paragraph above it, which owns a different judgement and keeps its text.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill exists in both trees and the copies match | `diff -q` returns nothing | Agent [x] |
| The paragraph names the skill and states no judgement of its own | `grep` the line: one clause of relation and one pointer | Agent [x] |
| The one-home why carries the hazard, and the boundary clause names the other skill | `grep` both sentences in both trees: the hazard closes the why paragraph, the boundary sits above the bridge clause | Agent [x] |
| The skill states one judgement | `grep -c "exception\|two questions"` returns 0 | Agent [x] |
| The map no longer reports `j-co-location`, and the ledger is clean | `--groups` omits it; `--check` reads 150 rows, 67 judgement, 45 description | Agent [x] |
| No candidate group remains except `j-write-plainly`, whose own row owns it | `--groups` | Agent [x] |
| The gates stay clean | `bash scripts/lint.sh` clean across 10 gates | Agent [x] |
| The roadmap row closes with its landing note | `grep` the row | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The scatter defect gets its own principle rather than a fold into one-home | a duplicate has two homes and drifts; a scattered rule has one home whose parts the reader does not reach, so the remedies differ and neither rule can own the other | the skill's `## Where another rule wins` |
| The one-home why gains the hazard rather than only drift | a duplicate forces the reader to decide which copy governs, and no record answers that, which is a cost drift describes only later | `principle-one-home-per-rule` |
| The boundary is stated in both skills | a reader may meet either one first, and one clause in one file leaves the other silent | both skills |
| The source paragraph keeps one clause naming its relation to progressive disclosure | the two moves are complements, and the paragraph is where a reader learns that they pair | `prompt-authoring-conventions.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|
| The pair of rules needed a two-sided boundary, not one clause in the new skill | design | a reader who meets one-home first would have no reason to look for the other | fixed in this iteration, in both skills |
| The draft's "a section answering two questions" row stated a second judgement, which the boundary then denied, and its test fired on this repository's own headings such as `## Purpose and scope` | defect | found by the reviewer; the row and the test are gone, and the skill now states one judgement | fixed in this iteration |
| "Exception" arrived as a third kind of part beside "caveat" and "definition", undefined, so one term carried two meanings | defect | found by the reviewer; the skill no longer uses the word | fixed in this iteration |
| The corpus does not name the inverse defect: a section that holds two unrelated concepts | design gap | the graft at `documentation_policy.md:49` reads as scatter from the term's side and as lumping from the section's side, and only the scatter reading has a home | `roadmap.md` |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-dont-scatter-what-belongs-together/SKILL.md` | the skill, new |
| `~/.pi/agent/skills/communication-principle-dont-scatter-what-belongs-together/SKILL.md` | the installed copy, byte-identical |
| `src/reasoning/providers/pi/config/agent/skills/principle-one-home-per-rule/SKILL.md` | the hazard closes the why paragraph, the boundary clause sits above the bridge clause |
| `~/.pi/agent/skills/principle-one-home-per-rule/SKILL.md` | the installed copy, byte-identical |
| `docs/development/prompt-authoring-conventions.md` | line 44 reduced to one relation clause and one pointer |
| `scripts/lint/norm-ownership.tsv` | regenerated: 150 rows |
| `scripts/lint/norm-judgements.tsv` | regrouped; the pointer row joined `j-pointer-rows`, and `j-co-location` is gone |
| `devlog/roadmap.md` | the landing row closed |
| `devlog/handovers/20261020-29-workflow-file_the_scatter_principle.md` | this record |
