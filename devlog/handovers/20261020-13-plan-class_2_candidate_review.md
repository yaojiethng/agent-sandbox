---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Plan
status: Active
---

# Handover - the class-2 candidate review

## Objective

Decide a disposition for each of the ten candidates the duplication map flagged, and write one roadmap row per accepted candidate so each can land in its own iteration.

## Scope

The roadmap row **The class-2 candidate review**. One grill session settles the dispositions; the close writes the tranche rows and nothing else. No skill is filed and no source line is edited here.

Out of scope, with reason: the landings themselves, which the tranche rows schedule, and the fold edits, which belong to whichever landing performs them.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every candidate carries a disposition: land, fold, or reject | `awk -F'\t' '$3 ~ /^candidate/' scripts/lint/norm-judgements.tsv` returns no candidate without a disposition in this record | Agent [ ] |
| Each fold names the skill it folds into and the line of that skill which already states it | read the fold rows of this record | Agent [ ] |
| Each land names the evidence that carries it, a failure or a carrier set | read the land rows of this record | Agent [ ] |
| Each rejection names what it would have broken | read the reject rows of this record | Agent [ ] |
| The tranche rows are written, one per accepted candidate, and none for a rejection | `grep` the roadmap for one row per land | Agent [ ] |
| No skill is filed and no source line is edited | `git status --short` names only the roadmap and this record | Agent [ ] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `hand-off-by-naming-the-boundary` lands, with the long name | the operator approved the written item 2026-10-20; the four moves are a sequence a writer follows, so the body carries them as an ordered list | this record, and the item proposed in chat |
| `hand-off-by-naming-the-boundary` sets `disable-model-invocation: true` | the operator's direction: it is a principle for writing a skill or prompt, and a deliberate pass applies it rather than a writer reaching for it mid-draft. The tree agrees in part: `principle-check-placement`, `principle-guard-the-context-window` and `principle-one-home-per-rule` set the field, while the six `communication-principle-*` skills do not | this record |
| `own-the-step-you-write` is vague in the term `step` and is re-proposed | the operator's reading: a scoping convention rolled into a writing rule, with the boundary between a step of a flow and a step of a procedure undefined. The re-proposal defines `stage` and states what does not trigger it | this record |
| `principle-one-stage-one-owner` lands | replaced the ambiguous unit with the declared scope; the term `stage` is dropped | this record |
| `principle-say-what-done-looks-like` lands, bare and model-invoked | the operator widened it to a general principle for all agentic work, so it takes the bare `principle-` form, and it is model-invoked because an agent applies it while doing the work rather than as a pass over a finished artifact. That gives the class rule two data points: `hand-off-by-naming-the-boundary` is a pass over a prompt (operator-invoked), this one guides the work as it happens (model-invoked) | this record, and the item approved 2026-10-20 |
| `principle-say-what-done-looks-like` is written in general terms, with one labelled row for this repository | the operator's catch: `scope gate` is a local name, and a local name in the rule body makes the rule about this repository. The body names inventory, bound, acceptance criteria and verification; a row named `Where this repository holds it` carries the scope gate, the handover and the gates | this record |
| The skill was run against its own rule before approval | six changes: a formatting rule removed as a stage the skill did not own, `completeness criteria` replaced by the tree's `acceptance criteria`, a bound added with its reason, a semicolon sentence split, an unclear clause rewritten, and the claimed verification run and shown | this record |
| `principle-effective-skill-routing` lands, operator-invoked | the operator rejected `case`, `branch` and `trigger` as the rule's centre, because none of them decide what the model reads: pi advertises a name and a description, and loads the body after the decision. The rule is about spending description words on situations an agent matches. The name is the operator's, with the `principle-` prefix the naming scheme requires | this record, and the item approved 2026-10-20 |
| `principle-match-precision-to-stakes` lands, operator-invoked | the rule asks four questions in order: the assumption, how far a wrong move reaches, whether it can be undone, whether anything reports it. Stakes are stated rather than priced, so nothing needs a prediction. `assumptions` and `gaps` replace the known and unknown model, both being words this codebase already uses. The reach axis restores the expensive-versus-cheap intention after an earlier draft dropped it | this record, and the item approved 2026-10-20 |

## Decisions pending

| Candidate | Sites | Proposed disposition | Evidence |
|---|---|---|---|
| `define-before-you-use` | 1 | fold into `communication-principle-attach-as-you-read` | that skill's table already pairs "an imperative issued before the reader knows its object" with "the defined object first, then the imperative" |
| `end-a-step-on-a-check` | 2 | land | no fold: `principle-check-placement` places a check against its evidence, which is a different judgement; the nearer name it cites, `principle-sequence-verifiable-units`, is absent from every skill root |
| `co-location` | 1 | fold into `principle-guard-the-context-window` or land | unread; the disclosure ladder is that skill's territory |
| `hand-off-by-naming-the-boundary` | 6 | land | the conventions record that four prompts apply the shape and none of them names it |
| `own-the-step-you-write` | 5 | land | states its own failure mode: locally accurate and globally unreliable |
| `describe-only-what-is-true` | 2 | reject the general skill, keep the document-type rule local | the two sites are architecture-document obligations, and the general form would forbid the roadmap and the recorder layer the practice they exist for |
| `match-guidance-to-fragility` | 1 | land, on a carrier set | the prompts show both ends, an exact command and a heuristic |
| `one-subject-per-prompt` | 1 | land as one document's subject | the one site is a prompt rule whose subject is a document rule |
| `pointer-wording` | 1 | land | every skill's description is a pointer, so the carriers are the whole skill set |
| `write-plainly` | 5 | settled: a draft, with its promotion row | `20261020-10` |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `principle-check-placement` links to `principle-encode-lessons-in-structure` and `principle-sequence-verifiable-units`, and neither exists in any skill root | record defect | two dangling related-links in a filed skill | the roadmap row **The norm ledger names a principle skill as an observer**, or a new row at this close |
| `prompt-authoring-conventions.md` states that a judgement skill does not set `disable-model-invocation`, and three filed judgement skills set it | record defect | the stated rule and the tree disagree, so the class boundary is unreadable from either | the filing, which edits that file |
| Two of the six candidates turned on a unit the reader cannot determine: `step` in `own-the-step-you-write`, and the completion bound in `end-a-step-on-a-check` | result | the first was corrected to the declared scope; the second survives only because a runbook numbers its own steps, which is a declared unit | this record's items two and three |
| A candidate name made a universal claim its scope line contradicted: `principle-end-each-step-on-a-check` implied every prompt ends on a check, while the rule covered runbooks only | result | the name was replaced, and the check for the remaining candidates is whether the name is true of the scope rather than of a slogan | this record, item three |
| A general principle stated in local vocabulary becomes a local rule | result | the body now carries general terms only, and one labelled row carries the local instance; applied to the remaining candidates before they are proposed | this record |
| The pointer candidate's premise was false at the invocation layer | result | pi loads a skill's whole body after the decision, so a pointer inside a body routes nothing; the rule was rebuilt around the description, which is the only router | this record, item four |
| A rule that needs the cost of an error cannot be followed, because the cost is a counterfactual | result | the axis was restored as reach, which a writer can see before acting, and the name became `principle-match-precision-to-stakes` | this record, item five |
| A cognitive model imported as vocabulary makes the rule depend on a term the codebase does not use | result | known and unknown became assumptions and gaps, both already in use here, and each now does one job | this record, item five |

## Completed

None yet.
