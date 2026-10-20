---
date: 2026-10-20
milestone: T1 - Workflow + Policy Organization
type: Workflow
status: Closed
---

# Handover - the dont-know-dont-care prompt

## Objective

Write the operator's stance on delegated decisions as a prompt: decide and build without asking, then record what was unknown so the next decision costs less.

## Scope

One prompt at `.agents/drafts/dont-know-dont-care.md`, from the operator's brief and two reference answers. The first is another agent's take on the same prompt. The second is `poteto-mode`'s prototype playbook, which covers an adjacent case. A prototype is an instrument for one decision and dies with it, so its quality bar inverts. This prompt covers the artifact that stays. The operator asked for an evaluation of each reference, then a bulk pass, then a cut pass over the result.

Out of scope: no other prompt root, and no change to how a prompt reaches the session. The operator approved the text at review, so the promotion landed in the same iteration as the draft: one commit moves the file from `.agents/drafts/` to `.agents/prompts/` and drops the draft marker.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The prompt keeps the reference answer's skeleton of execute first, record after | read `## Execution Workflow` | Agent [x] |
| The prompt is live, and the draft marker is gone | `git ls-files .agents/prompts/dont-know-dont-care.md`; read the file's head | Agent [x] |
| It prescribes no standards catalogue, and names why the four floor lines survive | read `## The floor` and `## Non-goals` | Agent [x] |
| It states the lifespan split that separates it from a prototype playbook | read `## Purpose` and `## When to use` | Agent [x] |
| Every step ends on a criterion | read each `Done when` line | Agent [x] |
| The seam is declared before the build, and the maintenance note lives with it | read `## Steps` step 2 | Agent [x] |
| The scope is bounded to a small surface, and the size gate is stated | read `## Purpose`, `## When to use` and `## Non-goals` | Agent [x] |
| Every entry the record asks for names the fact that would settle it | read `## The uncertainty record` | Agent [x] |
| The prompt carries the script for the operator's own trade-off, not a restatement of the project's rules | read `## Steps` step 1 and `## The floor` | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` | Agent [x] |
| The wording passes the writing bar | read against `docs/development/prompt-authoring-conventions.md` and the `unslop` and `technical-writing` skills | Agent [x] |
| Every decision this iteration records is realized in the file | read `## Decisions` against the draft | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The reference answer's three-part log becomes assumed, chosen, skipped | "unacceptable risks" invites hypotheticals, which is not information. A skip with a cost and a first symptom is | the draft, `## The uncertainty record` |
| The 80/20 catalogue is dropped, and four floor lines replace it | the catalogue names Zod, Pydantic, REST and vertical slicing, which are another project's defaults, and the rest is what an agent already does. The four survive because each is one way or invisible | the draft, `## The floor` |
| The floor yields to a project rule, and says so | a workflow document is a fast path. The project's rule is the home, so the prompt states the precedence rather than competing | the draft, `## The floor` |
| The record is written after the proof, not before | a record written first states intent. Written after, it states what happened | the draft, `## Invariants` |
| The artifact was a draft until the operator approved it, and promotion is the move | a prompt written in a session is unreviewed, and the location is the durable gate. The approval and the move land in one commit, so no draft commit survives in the history | the promotion, and `prompt-authoring-conventions.md` `## Draft status and the switch-over gate` |
| The live root is `.agents/prompts/` | the pi settings record names that folder as a prompt root read from the project tree, so a file there needs no copy step and takes effect on `/reload`. The coding-agent module's prompts root would make an operator stance look like a loop runbook | `resync.md`, and the manifest's prompt roots |
| The name stays `dont-know-dont-care` | `/dont-know-dont-care` reads to the operator as the instruction it is. The naming convention prefers a noun phrase, and the operator's word is the trigger here | this record |
| The bar is set by the artifact's lifespan, not by the operator's indifference | a prototype dies with its decision, so its bar can invert. A feature that stays cannot borrow that licence, which is the difference between the two prompts | the draft, `## Purpose` |
| Simplify the inside and keep four edges honest | the inside is rewritten anyway. The data shape, a called interface, a migration, and a cited name are what another part of the system pays for later | the draft, step 2 |
| The proof names the surface, not only the project's command | a passing test proves the harness. The prototype playbook's observation rule is the useful half of its verification step, and it fits an observation better than an assertion does | the draft, step 4 |
| The record opens with the artifact's state | a prototype playbook can say plainly that its artifact is throwaway. An artifact that stays needs that statement too, or the next reader treats a provisional cut as final | the draft, `## The uncertainty record` |
| The variant switcher and the reference-gathering step are not ingested | both serve an open design space the operator wants to see. A deprioritized feature has a settled direction, so three variants would be waste | this record |
| The scratch directory and the no-tests allowance are not ingested | both are licence that a throwaway artifact earns. A scratch directory would hide the work from the project it belongs to, and the project's gate still decides about tests | this record |
| The seam is declared before the build, not recorded after | a boundary written after the work describes what was built. Written first, it constrains the build, which is the only time it changes a decision | the draft, step 2 |
| Maintainability is stated as a test, not a virtue | "maintainable" invites agreement and changes nothing. One file and one command is checkable by the next reader, and it is the whole of what a sloppy inside needs | the draft, step 2 `Done when` line |
| The maintenance note folds into the seam, and splits out only for a called or shipped utility | a second document for a small tool is a second thing to keep true. The record holds four lines until other code depends on it, and then the code's own `README.md` is where a maintainer looks | the draft, step 2 |
| Expected contact replaces importance as the investment signal | "unimportant" is a feeling, and a neglected utility that everything calls still gets touched. The `State` line asks who will call it, which is checkable | the draft, `## The uncertainty record` |
| Small and utility-shaped is a stated scope condition, gated by the one-paragraph seam | the shortcut is safe while one person can hold the surface. A feature too large for a one-paragraph seam needs the iteration rhythm | the draft, `## When to use` |
| The seam is the contract, and the edge list is what the seam publishes | five carriers were an enumeration standing in for a definition. "A fact something else holds after you leave", plus three examples, generates the list for a project this prompt has never seen | the draft, steps 2 and 3 |
| The two principle citations leave the prompt | the steps carry the behaviour, and a citation in a prompt is a second home for the rule. The provenance is in this record | this record |
| `dont-know-dont-care` keeps the operator's preamble, Core Directive and two-move shape | the framing was sharper than mine: "we are both operating with high uncertainty" and "technical debt compounding silently" say in two clauses what my Purpose took a paragraph to say. The flesh belongs in the two moves, not in a new outline | the draft, `## Core Directive` and `## Execution Workflow` |
| The workflow grows from two steps to four | the two moves are execute and log. The contract must precede execute and the proof must precede the log, so each gets a step and all four are the operator's two moves with their supports | the draft, `## Execution Workflow` |
| The log keeps four fields and a closing question | `State` says whether anything may depend on the artifact. `Assumptions`, `Trade-offs` and `Skipped` keep the operator's names. `The question worth answering` is the line that makes the next session cheaper | the draft, `## The decision and debt log` |
| `Unacceptable Risks` becomes `Skipped`, and `The 80/20 Standard` is dropped | the risks field asked for a confession about hypotheticals, and most skips are unnoticed rather than deliberate. The 80/20 claim is made by the seam, not reported after the fact | the draft, the log |
| The cut prompt was 105 lines and is now 56 | the operator's structure carries the framing in fewer words, and the failure table, the separate Purpose and the When to use section had no job left | the draft |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Does the prompt get promoted, and into which root | its use as a live command | promote to `.agents/prompts/`, promote to the provider prompt set, or leave it a draft |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The reference answer's "skipped unit tests is okay" contradicts a project that runs a suite as a gate | review of the reference answer | a rule that fails the project's own gate | the draft states that the project's checks decide, and records the skip |
| The reference answer states "progressive disclosure" as a quality lens, which is a document-authoring term with a different meaning | wording | a reader in this repository meets a term that means something else here | dropped from the draft |
| The prototype playbook's quality inversion is safe only because its artifact is deleted | second reference, scope | the same wording in this prompt would licence a permanent artifact to rot | the lifespan split is stated in `## Purpose`, and the edge rule bounds the simplification |
| The scope word "important" decides nothing, because a neglected utility that many things call is still touched often | scope refinement, operator review | an investment rule keyed on importance would under-maintain the busiest small tools | the record asks for expected contact, and the state line carries it |
| The reference answer's `Unacceptable Risks` and `80/20` fields were the two that carried its standards catalogue | second reference, structure | keeping them would re-import the list the cut removed | both are replaced in the log, and the 80/20 claim moved into the seam |

## Completed

| Artifact | Change |
|---|---|
| `.agents/prompts/dont-know-dont-care.md` | live prompt: the operator's preamble and Core Directive, a four-step execution workflow, a five-field decision and debt log, the no-rules floor and two invariants. 55 lines |
| `.agents/drafts/dont-know-dont-care.md` | removed by the promotion |
| `devlog/roadmap.md` | one T1 row, closed with its landing note |
