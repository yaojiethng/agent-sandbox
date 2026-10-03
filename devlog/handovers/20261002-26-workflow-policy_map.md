---
date: 2026-10-02
milestone: T1 - Workflow + Policy Organization
type: Workflow
status: Closed
---

# Handover - The policy map for the roadmap-touching policies

## Objective

Produce the policy map -- one row per rule in the policy files that name the roadmap, giving each rule its current home, its correct home, and a verdict of move, point, or no home -- then apply the verdicts whose home is decidable from the map alone.

## Scope

The rule homes, over the eight policies that name `roadmap.md`, `roadmap_policy.md`, `roadmap_future.md` or `changelog.md`: `roadmap_policy`, `handover_policy`, `iteration_policy`, `story_policy`, `milestone_policy`, `documentation_policy`, `git_policy`, `study_policy`. The set is selected by mention, so a reader can reproduce it.

Two passes were carved out and are **not** this iteration:

- **The procedure map.** The same scope and row shape over the workflow prompts and skills that read or write the roadmap. Roadmap row *Procedure map across the procedures that touch the roadmap*.
- **The gap and collision analysis.** A policy mapping read against a procedure mapping is what makes leaks and overlaps visible; neither alone does. Roadmap row *Gap and collision analysis across the maps*.

The 40 `point` verdicts are deferred to the procedure map, because whether a policy needs a pointer depends on what the prompt it governs already says.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | The policy map covers every rule in the eight shortlisted policies | one row per rule: rule, current home, correct home, verdict | met -- 196 rules, all eight read in full |
| 2 | Every row carries one of the three verdicts | every row reads move, point or no home; none left blank | met -- 142 stay, 40 point, 12 move, 2 no home |
| 3 | The map returns a verdict on whether `milestone_policy.md` survives | the ruling settles the `milestone_policy` expansion row either way | met -- deleted, and the expansion row closed |
| 4 | The map is produced as a working document under `devlog/discussions/` | one row per rule, and the home moves land from it | met -- produced and used; the working document was deleted when the campaign closed |
| 5 | Suite and lint green | `bash scripts/run_tests.sh`; `bash scripts/lint.sh` | met -- 1037 passed; lint clean across 5 gates |

The home moves landed: `milestone_policy.md` is deleted, the policy layer lost its two duplicated preambles, the acceptance-criteria model moved to the policy that derives it, and the roadmap lost its `## User Stories` section. The map was the evidence for each; it was a working document and is not retained.

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/roadmap_policy.md`](../../docs/operations/roadmap_policy.md) | the densest rule set in the shortlist, and the file that receives the fold |
| [`docs/operations/handover_policy.md`](../../docs/operations/handover_policy.md) | a format policy carrying operational matter it does not own |
| [`docs/operations/iteration_policy.md`](../../docs/operations/iteration_policy.md) | six milestone-grain rules stranded in the iteration policy |
| [`docs/operations/milestone_policy.md`](../../docs/operations/milestone_policy.md) | deleted; 13 of its 19 rules pointed at or restated another document |
| [`docs/operations/story_policy.md`](../../docs/operations/story_policy.md) | the story-milestone coupling, and a roadmap section it alone required |
| [`docs/operations/study_policy.md`](../../docs/operations/study_policy.md) | the same coupling |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the `## User Stories` section, and the row set this iteration closes |

## Decisions

The full set, with rationale, was settled in the interview. The load-bearing ones:

1. **The completion test is the Canonical-owner test alone** -- one owner per rule, every other mention points. The stronger test, that no policy may be mostly pointers, was recorded as a roadmap task rather than adopted, because its threshold would be arbitrary.
2. **`milestone_policy.md` is deleted and its grain folds into `roadmap_policy.md`.** A milestone is a node in the roadmap's tree, so its structure and states are record rules. This replaced the map's own recommendation of a four-way distribution.
3. **The home is where the object lives, not where the workflow lives.** This withdrew the map's proposal to send the scoping criteria to `iteration_policy`; they were two record-shape rules, a duplicate, and a stale entry.
4. **The producer owns the definition.** `iteration_policy` owns the acceptance-criteria model; `handover_policy` owns the table that records it. The map had recommended the reverse.
5. **No task numbering below the sub-milestone.** Tasks group into functional areas and a group is shaped into a milestone; that relationship is stated, the numbers are not extended.
6. **Blocking is an ordering position, not a document state.** No marker. `blocker` as a Findings type was renamed `obstacle`, since it names a different thing.

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The stale story-milestone coupling is in three policies, not one. Deleting `milestone_policy.md` removed one instance; it persisted in `story_policy.md` and `study_policy.md`, both of which survive | contradiction | corrected this iteration. Triaged to: fixed in place. |
| Two state models existed for one milestone -- `active -> pre-close -> close` in `iteration_policy.md`, `ms:active -> ms:close-gate` in the ADR | contradiction | corrected this iteration. Triaged to: fixed in place. |
| Two of the map's own verdicts were wrong: `roadmap_policy` row 27 was marked `no home` and stays; `milestone_policy` entries 2 and 3 were misclassified as rules | bug | corrected this iteration. Triaged to: fixed in place. |
| The producer-owns-the-definition rule surfaced but was filed rather than adopted, because adopting a governance rule mid-sweep is how a sweep acquires rules it never examined | steering | roadmap. Triaged to: roadmap.md -- *Record the producer-owns-the-definition rule*. |
| The interview reframed the work twice -- from one rule map to two maps plus an analysis, and from a four-way distribution to a fold. Both were the operator's, and both narrowed the change | scope change | this iteration. |

## Completed

| File | Change |
|---|---|
| `docs/operations/roadmap_policy.md` | preambles out; `Description` and `Scope` in; new `## Milestone States`; `Objective`, `Dependencies` and `Ordering` rules; the *Open questions* rule generalised to the discussion document |
| `docs/operations/iteration_policy.md` | preambles and the two tail tables out to a `Description` and `Scope`; the acceptance-criteria model and its authoring standards in; the milestone-grain rows out |
| `docs/operations/handover_policy.md` | the acceptance-criteria model out, the table kept; three tail tables to a `Scope` line; `blocker` renamed `obstacle` |
| `docs/operations/story_policy.md` | the `## User Stories` list rules out; the story-milestone coupling corrected |
| `docs/operations/study_policy.md` | the same coupling corrected |
| `docs/operations/milestone_policy.md` | deleted |
| `docs/concepts/agent_workflow.md` | the milestone-planning row repointed |
| `workflow/coding-agent/prompts/iter.md` | `blocker` renamed `obstacle` |
| `workflow/coding-agent/prompts/plan.md` | the `milestone_policy.md` binding rule removed |
| `devlog/roadmap.md` | the `## User Stories` section retired for a task-row reference; four rows closed, three filed |
