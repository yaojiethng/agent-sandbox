---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - Name the defect the corpus leaves unnamed, a section that carries two subjects

## Objective

Name the inverse of scatter, a section that holds two unrelated subjects, so a writer who reads a section for one subject and meets another finds a rule that catches it.

## Scope

The row **Name the inverse defect: a section that holds two unrelated concepts** under M3.3.4, which is the last row of phase A. The corpus names scatter, a rule's parts sitting apart, and does not name lumping, one section carrying two subjects. The graft the row names is the bullet `One term, one meaning` at `documentation_policy.md:45`, inside `### Simplified Technical English`: read one way it is a terminology clause away from its home, and read the other way it is a foreign subject inside a section whose subject is sentence structure. Only the first reading has a home today.

The question is answered. [`20261021-design-settled-inverse_defect.md`](../discussions/20261021-design-settled-inverse_defect.md) widens the scatter principle and renames it to `communication-principle-keep-a-subject-near`, with `proximity` as its leading word. The scope carries the rename and the files that follow it, and the design record holds the list of them.

Ruled out of scope: moving the graft itself. Its home changes when M3.3.2 retires the policy's judgement rows, so a move now would be undone by the retirement that follows this row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The corpus names lumping, or records why scatter's rule already covers it | `communication-principle-keep-a-subject-near` states both readings, and `bash scripts/check_skill_shape.sh` printed `skill shape: clean across 22 skill(s)` | Agent [x] |
| The two readings of the graft are told apart, and each names its owner | the design record's `## Consequences` names both readings and the half of the widened principle that owns each | Agent [x] |
| The shape gate accepts the renamed principle | the gate printed its clean line, and `--map` printed `claim map: 22 skill(s) across 5 claim(s) of 22` with `reader` beside `communication-principle-keep-a-subject-near` | Agent [x] |
| The deciding test is not vacuous | read against `documentation_policy.md`, the section question fires on `### Simplified Technical English`, which carries the terminology bullet, and passes on `### Reserved terminology`, which serves one subject | Agent [x] |
| Every copy of the changed skill is identical, under the new name | `diff -r` printed nothing, and `ls` finds the new directory in both trees and no directory under the old name | Agent [x] |
| The umbrella and the suite are clean | `Lint: clean in 8s across 11 gates`; `1273 tests across 92 files, 1273 passed, 0 failed, 0 skipped` | Agent [x] |
| Every decision this iteration recorded is realized in the files | five decisions, each read against its file: the widened law, the rename, the four costs, the claim split with `one-home-per-rule`, and the rejection of the merge | Agent [x] |
| Every live carrier follows the rename, and every closed record keeps the old name | `grep -rl dont-scatter-what-belongs-together` returns six files: the design record, four closed roadmap rows and four closed handovers. Each states the old name as what the skill carried at the time, and no live instruction surface carries it | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The scatter principle widens and takes the lumping defect | the two readings are one law seen from either end, and the reader's cost is symmetric | [`20261021-design-settled-inverse_defect.md`](../discussions/20261021-design-settled-inverse_defect.md), `## Decision` |
| The principle is renamed to `communication-principle-keep-a-subject-near` | the name states the act, carries the leading word `proximity`, and stays clear of `home` and `place` that pull it toward `principle-one-home-per-rule` | the same record, and the naming rule in `principle-effective-skill-routing` |
| The law states proximity and reads it against four costs a writer can check | one property with its consequences, so the body argues once and the writer checks four things. The labels take the reader's vocabulary, after a review found the first set mixing engineering, agent-runtime and reader words | the same record, `## Decision` |
| The claim stays `reader`, and `principle-one-home-per-rule` keeps `source` | both questions ask what the reader holds, where the one-home test asks where the text lives, and a merge would have erased that distinction | the same record, `## Decision` |
| The two principles are not merged | the defects occur independently and their repairs differ, so a merged skill would carry three observations and three repairs, which is lumping at corpus level | the same record, `## Options Considered` |

## Decisions pending

None. The question this table held is answered in the design record, and the scope gate releases that answer with the scope.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `test_linking.sh` exceeded its deadline once under the full suite | result | the first suite run reported `TIMEOUT test_linking.sh (exceeded 10s deadline)`. Run alone the file passes 27 of 27 in 4.8 seconds, and the suite's second run was clean, so the deadline is tight under parallel load rather than the file being broken | not filed, because one occurrence on a loaded machine does not show a defect. A second occurrence goes to the record-check backlog as a test-liveness item |
| The naming clauses this row's rename depends on have no home | result | the rename needed a naming rule, and neither the routing skill nor the conventions doc could supply one without contradicting the other, so the work paused at the scope gate | sidequest `20261021-06-workflow-skill_routing_leitwort.md`, which lands the clauses before this row resumes |
| The pause cleared | result | sidequest `20261021-06` landed the naming and leading-word clauses in `principle-effective-skill-routing`, so the rename this row depends on now follows a stated rule, and the row resumes at its scope gate | this iteration, which resumed after the sidequest closed |
| The row's line reference no longer points at the graft | result | the row names `documentation_policy.md:49`, and `e0e9cb0f` moved the bullet to `:45`, so the line reference addresses nothing | the scope, which names `:45` |

## Completed

| File | Change |
|---|---|
| [`communication-principle-keep-a-subject-near/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/communication-principle-keep-a-subject-near/SKILL.md) | renamed from `communication-principle-dont-scatter-what-belongs-together`, with the `proximity` law, the four costs in the reader's vocabulary, both test questions, a fifth pattern row for the lumped section, `leitwort: proximity` and the new description |
| `$AGENT_HOME/agent/skills/communication-principle-keep-a-subject-near/SKILL.md` | the installed copy, and removal of the directories under both earlier names |
| [`principle-one-home-per-rule/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/principle-one-home-per-rule/SKILL.md) | the boundary line names the widened sibling and its path |
| [`AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md), [`prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | one citation each, and the installed `AGENTS.md` |
| [`scripts/lint/norm-ownership.tsv`](../../scripts/lint/norm-ownership.tsv), [`norm-judgements.tsv`](../../scripts/lint/norm-judgements.tsv) | regenerated; the co-location row is a judgement homed to the renamed skill, so the map regroups and 13 rows stay homed |
| [`devlog/roadmap.md`](../roadmap.md) | the row closes, and its stale line reference is corrected to `:45` with the section named |
| [`20261021-design-settled-inverse_defect.md`](../discussions/20261021-design-settled-inverse_defect.md) | the design record, with the four options, the merge rejection, the decision and the carrier list |
