---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Active
---

# Handover - Name the defect the corpus leaves unnamed, a section that carries two subjects

## Objective

Name the inverse of scatter, a section that holds two unrelated subjects, so a writer who reads a section for one subject and meets another finds a rule that catches it.

## Scope

The row **Name the inverse defect: a section that holds two unrelated concepts** under M3.3.4, which is the last row of phase A. The corpus names scatter, a rule's parts sitting apart, and does not name lumping, one section carrying two subjects. The graft the row names is the bullet `One term, one meaning` at `documentation_policy.md:45`, inside `### Simplified Technical English`: read one way it is a terminology clause away from its home, and read the other way it is a foreign subject inside a section whose subject is sentence structure. Only the first reading has a home today.

One question blocks the scope, because the answer chooses the files. It is in `## Decisions pending`, and the scope gate releases it.

Ruled out of scope: moving the graft itself. Its home changes when M3.3.2 retires the policy's judgement rows, so a move now would be undone by the retirement that follows this row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The corpus names lumping, or records why scatter's rule already covers it | the principle that owns the defect states the second reading, and `bash scripts/check_skill_shape.sh` stays clean | Not yet run |
| The two readings of the graft are told apart, and each names its owner | the design record's table carries one row per reading, with the principle that owns it or the record that limits it | Not yet run |
| The shape gate still accepts the changed principle | `bash scripts/check_skill_shape.sh` prints its clean line across 23 skill(s), or 22 where no principle is added | Not yet run |
| The deciding test is not vacuous | the owning principle's test fires on a section that carries a second subject, and passes on a section that carries one | Not yet run |
| Every copy of the changed skill is identical | `diff -r` over the repo copy and the installed copy prints nothing | Not yet run |
| The umbrella and the suite are clean | `bash scripts/lint.sh` and `bash scripts/run_tests.sh` | Not yet run |
| Every decision this iteration recorded is realized in the files | one row per decision against the file and the check | Not yet run |

## Decisions

None.

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Which principle owns the inverse defect? | the scope's file list, and which principle the shape gate reads | 1. Widen `communication-principle-dont-scatter-what-belongs-together`: one adjacency law, read from either end, with the test asking what one subject a section serves. No new file, no new claim. 2. Fold into `principle-own-the-scope-you-declare`: a heading declares a subject and a second subject overruns it, which is the fold `20261020-13` proposed for `one-subject-per-prompt`. 3. File a new principle with its own claim line. 4. Record a scope limit on the scatter principle, stating that the second reading advances no decision. |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The naming clauses this row's rename depends on have no home | result | the rename needed a naming rule, and neither the routing skill nor the conventions doc could supply one without contradicting the other, so the work paused at the scope gate | sidequest `20261021-06-workflow-skill_routing_leitwort.md`, which lands the clauses before this row resumes |
| The row's line reference no longer points at the graft | result | the row names `documentation_policy.md:49`, and `e0e9cb0f` cut that section, so the bullet sits at `:45` today and the enclosing section is `### Simplified Technical English`, not a sentence-structure heading | the scope, which names `:45` and the section by name |

## Completed

No file changes this iteration.
