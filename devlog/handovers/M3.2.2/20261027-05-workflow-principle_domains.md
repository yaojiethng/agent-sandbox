---
date: 2026-10-27
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - Each principle states its own domain

## Objective

Give every principle in the prose cluster a domain -- what fires it, what it does not cover, and which neighbour owns the rest -- so a pointer can resolve to one judgement instead of choosing between seven.

## Scope

Opened after `20261027-04`, where the operator asked why the principles do not invoke, and settled that the fault is a trigger set shared by many principles rather than a missing link. Three passes, all on operator direction inside this unit. The first is the principles whose `description` named four or more prose subjects, eleven of fifty. The second is the instruction-scoping cluster the first uncovered: `hand-off-by-naming-the-boundary`, `match-precision-to-stakes` and `own-the-scope-you-declare`. The third leaves the cluster question behind: every one of the 26 principles whose trigger named a general prose subject as the thing it applies to now names the defect instead, because a trigger that says "when writing a document" is true of a dozen judgements and fires none of them. This unit writes domain lines and reports the overlap before and after; it places nothing. Out of scope: producer clauses, checker citations, and the classification of maintenance rules, which all belong to the placement unit that follows, because the classification exists to stop a clause duplicating a rule a script already enforces. Also out of scope: the other thirty-nine principles, any collapse of the principle set, and the instrument work.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every principle in the cluster states what fires it, what it does not cover, and its nearest neighbour | all seven name their neighbours by name | Agent [x] |
| Two principles that share a trigger are resolved by a citation edge, not by both restating the boundary | the prose cluster holds no pair sharing three subjects; the citation edges are `**Leaves to.**` lines | Agent [x] |
| The cluster's loaded cost falls | trigger characters across the seven, which is what the index carries: 1,524 to 1,405 | Agent [x] |
| The overlap report exists for the tree as it stands and again after the edits | the same script, run twice: eleven principles in a cluster with a seven-way collision, then five in a cluster with a three-way collision on a different subject | Agent [x] |
| No principle gains a rule it did not carry | every added line is a `**Fires on.**` or `**What it does not cover.**` boundary, and no obligation was added | Agent [x] |
| No trigger names a general prose subject as the thing it applies to | the sweep: 66 mentions to 23, and each survivor named the object of the rule rather than the medium | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Domains before placement, as a dependency rather than two parallel items | a pointer placed at a producer must choose between seven principles today, so it cannot fire; `writing-for-agents` states the rule that convicts us, one trigger per branch | this record |
| An overlapping pair is resolved by one citation edge, never by two restatements | two restatements is how the qualifying clauses grew in the first place | this record |
| The tree is mapped before `writing-for-agents` is read | reading it first would anchor the map; it is used afterwards as a check for combinable pairs and for titles that signal the domain | this record |
| `writing-for-agents` may supply a better domain map, combination candidates and stronger titles than our current set | operator judgement, recorded so the reading is not skipped; the stage it becomes useful is not settled | this record |
| The eleven lines in `## Communication Standards` stay | for the most frequent production moment they are the only place the judgement is in context for free | this record |

## Decisions pending

None.

## Findings

| # | Finding | Type | Impact | Triaged to |
|---|---|---|---|---|
| 1 | 26 principles live in the repository and all have inbound links, in-degree 3 to 19, but only 8 principle-to-principle edges exist across the 26 | measurement | the set is a flat star: linked from records, never from each other | this record |
| 2 | 11 of 26 principles are unreachable from any production carrier, among them `link-what-the-reader-can-open`, `single-train-of-thought`, `define-terminology-before-use`, `own-the-scope-you-declare` and `say-what-done-looks-like` | measurement | the judgements a producing session needs are reachable only when someone reviews the corpus | the placement unit |
| 3 | `iter.md`, `wrapup.md`, `commit.md`, `work-log` and `git-discipline` name zero principles; `task-list` names one and `docs` three | measurement | the carriers that write records carry no judgement about writing them | the placement unit |
| 4 | Principle descriptions are 8,425 of 18,197 characters in the skills index, 46 per cent, from 50 of 116 skills | measurement | collapsing the principle set is the lever if domains do not cure the guessing; not taken this unit | this record |
| 5 | `check_handover_format.sh` enforces the structural rules and caught three defects on 2026-10-27 alone | evidence | mechanical rules belong in the script, which the classification unit will apply to the three maintenance skills | the placement unit |
| 6 | A handover opened on 2026-10-27 for the four instruction-defect classes was never committed and was stashed to the output mount rather than adopted | record defect | the roadmap row holds that plan; the record added nothing a task did not already carry | this record |
| 7 | With the triggers rewritten, the seven-way collision is gone: no principle in the prose cluster now shares three subjects with another | measurement | the overlap was wording, not the judgements being the same, so the merge this unit expected to propose is not justified | this record |
| 8 | A second cluster appears behind the first: `hand-off-by-naming-the-boundary`, `match-precision-to-stakes` and `own-the-scope-you-declare` all fire on scoping an instruction | measurement | the prose cluster is settled and the instruction-scoping cluster is the next candidate unit | the roadmap row for the instruction-defect classes |
| 9 | The scoping cluster's three principles shared 881 characters of trigger text that did not distinguish them, and now hold 619 | measurement | the same defect as the prose cluster: a trigger broad enough to be true of three judgements | this record |
| 10 | After both clusters, one overlapping pair remains in the whole 26-principle set: `link-what-the-reader-can-open` and `single-train-of-thought` share three subjects, and the third is `sentence`, which neither owns alone | measurement | below the four-subject bar this unit set; left for a later pass rather than forced | this record |
| 11 | The corpus already used `**What it does not cover.**` for this part, in `match-precision-to-stakes`, so the seven prose principles were relabelled from `**Leaves to.**` to match | observation | one part, one label; the shape gate reads labels, not their wording | this record |
| 12 | Two descriptions broke the frontmatter: an unquoted `description:` carrying a colon and a space parses as a nested mapping, and the shape gate reported it as a YAML error rather than a shape fault | observation | the descriptions are quoted where they carry a colon | this record |
| 13 | Across the 26 principles the triggers named 66 general prose subjects before the sweep and 23 after, and the trigger text fell from 6,124 to 5,484 characters | measurement | specificity and index cost moved together, which is the test that this is not merely rewording | this record |
| 14 | Seven triggers still name two prose subjects, all of them as the object of the rule rather than the thing it applies to, for example `only-derive-what-you-own` deriving a value "in a document" | measurement | the remainder is the medium named once inside a specific rule; a keyword count cannot tell the two apart, so this is where the instrument stops | this record |
| 15 | The shape gate caught the first placement of the domain lines: a named part belongs between `**Why.**` and `**The test.**`, per `docs/adr/principle_skill_shape.md` | observation | the shape rule is real and observed; the lines moved rather than the rule | this record |

## Completed

| File | Change |
|---|---|
| seven `communication-principle-*` skills | a specific trigger in place of the broad one, and `**Fires on.**` plus `**Leaves to.**` naming the neighbouring judgement; cluster 203 to 229 lines, trigger text 1,524 to 1,405 characters |
| `\$AGENT_HOME/agent/skills/` copies | the seven synced, diffed identical after the edit |
| three scoping `principle-*` skills | a specific trigger, `**Fires on.**` after `**Why.**`, and `**What it does not cover.**` naming the two neighbours; cluster 98 to 108 lines, trigger text 881 to 619 characters |
| the seven prose `**Leaves to.**` labels | relabelled `**What it does not cover.**`, the label `match-precision-to-stakes` already used for that part |
| nine more principle skills | the trigger names the defect instead of the medium: a pointer, text carrying two lines, a word whose meaning the reader supplies, a separated subject, a list with two axes, a rule about to exist twice, a sentence that must be re-read |
| every principle copy under `\$AGENT_HOME/agent/skills/` | re-synced for the whole `principle-*` set, not just the ten edited this unit |
| [`AGENTS.md`](../src/reasoning/providers/pi/config/agent/AGENTS.md) | `## Communication Standards` quoted two triggers the sweep replaced; both now name the case the skill states, and the installed copy is re-synced |
| the ten skills' neighbour citations | every principle named in a `**What it does not cover.**` line resolves to a skill on disk |
| the overlap report | a script run over both states; counts in findings 7, 10, 13 and 14, and in the acceptance table |
