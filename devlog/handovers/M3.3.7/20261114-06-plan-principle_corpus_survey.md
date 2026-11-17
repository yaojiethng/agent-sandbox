---
date: 2026-11-14
milestone: M3.3.7 - The principle corpus admission
type: Plan
status: Closed
---

# Handover - The principle corpus is surveyed, not migrated

## Objective

Withdraw the per-skill neighbour migration and plan a survey that produces a loose corpus map and a conflict docket, so the edges are recorded without forcing a decision the corpus cannot support.

## Scope

The M3.3.7 rows **The neighbour field's empty value means "none declared"**, **The existing principle skills declare `[]`, and the baseline is deleted**, **The corpus survey process is written and the cross-references are censused**, **The five-card dry run**, **The full corpus survey over the 25**, and **The link form is normalised, conditional on the survey**. This record settles the `[]` meaning and the task split; it does not execute the rows.

Out of scope: the five open admission rows the survey feeds (relay, progressive context disclosure, colocation, the grammatical half of `cut`, and just-in-time), and any `metadata.neighbours` value on the existing corpus, which stays `[]`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `[]` means "no neighbour declared", and "surveyed, none" is carried by the survey map rather than the field. | Read the design record's decision bullet and the roadmap P0 row. | Agent [x] |
| The malformed migration row is replaced by six work rows whose dependencies name the survey prefactors. | Read the M3.3.7 task list; `bash scripts/lint.sh`. | Agent [x] |
| The design record's `## Remaining work` names the survey and no longer names the migration. | Read the section. | Agent [x] |
| The five existing admission rows depend on the survey row they need, not on the withdrawn migration. | Read each row's `**Depends on:**` clause. | Agent [x] |
| Every decision this iteration records is realized in the files. | Read the Decisions table against the roadmap, the design record and this record. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `[]` means "no neighbour declared"; a surveyed principle with no neighbour is recorded on the survey map, not as a different field value. | The field is a machine index for admission, not a claim that the corpus is mapped. Declaring `[]` on the 25 otherwise asserts a falsehood about most of them. | This record; the design record; roadmap P0 |
| The migration is withdrawn. The existing 25 declare `[]`, and the baseline and its `--update` are deleted. | The relation is not decidable per skill without a case: "neighbour" degrades to "shares a subject", a conflict has no state to be parked in, and unresolved edges propagate. | This record; the design record; roadmap P1 |
| The edges are produced by a survey: cards, the defect/grain/moment facets, families by literary warrant, bounded candidate edges, five relation kinds, a conflict docket and precedence rules. | Library classification gives independent facets and a non-transitive associative relation; case management gives the docket and the stay; conflict of laws gives the precedence order. | This record; roadmap P2--P4 |
| The link normalisation is conditional on the survey, not a prefactor. | There is no See-also heading to normalise. The relations sit under varying named parts and three pointer forms, and a required section would change the principle body shape before the relation kinds are settled. | This record; roadmap P5 |
| The task list replaces the malformed migration row with six rows and updates the dependent admission rows. | The old row assumed independent per-skill values reviewed as a batch, which is the premise the attempt disproved. | This record; `devlog/roadmap.md` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Where the survey procedure has its durable home. | The survey process row. | A reference under `instruction-authoring`; an ADR entry under `principle_skill_shape.md`; a runbook under the workflow. |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The migration produced four failures at once: the values blurred together, no criterion existed for a neighbour edge, real conflicts could not be resolved, and unresolved edges pulled their neighbours into a tangled group. The field has no state for a contested edge, so the unresolvedness had nowhere to stop. | record | The migration row's premise was false. The relation behaves as a connected component, so a skill-by-skill batch is the wrong review unit. | This record; roadmap P2--P4 |
| The see-also relation is loose in the corpus: there is no dedicated heading, the references sit under named parts that vary by principle, and three pointer forms are in use -- a relative Markdown link, a `$AGENT_HOME/...` code path, and a bare skill name. The `$AGENT_HOME` path is not open to a shipped reader. | record | A formatting pass would be a body-shape change and would encode today's ambiguity. A read-only census is the prefactor that decides whether normalisation is worth it. | This record; roadmap P2 and P5 |
| This record was an `Implementation` record for reverted work and stayed `Active` on the track. | record | The track's active record named a withdrawn iteration. | This record, converted to the Plan |

## Completed

| File | One-line change summary |
|---|---|
| `devlog/roadmap.md` | Replaces the migration row with the six survey rows; updates sequencing, dependencies, acceptance criteria and Not in scope. |
| `devlog/discussions/20261114-design-concluded-principle_corpus_admission.md` | Changes `[]` to "no neighbour declared"; withdraws the migration and re-points the remaining work at the survey. |
| `devlog/handovers/M3.3.7/20261114-06-plan-principle_corpus_survey.md` | This record; renamed from the reverted implementation record. |
