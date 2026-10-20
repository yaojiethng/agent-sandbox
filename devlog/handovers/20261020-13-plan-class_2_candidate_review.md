---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Plan
status: Closed
---

# Handover - the class-2 candidate review

## Objective

Decide a disposition for each of the ten candidates the duplication map flagged, and write one roadmap row per accepted candidate so each can land in its own iteration.

## Scope

The roadmap row **The class-2 candidate review**, run as one grill session over the ten candidates. This record closes with the five approved skills scheduled and the remaining four left undecided, because the operator requires an explicit grill session before a fold or a rejection lands.

Out of scope, with reason: the landings, and every fold and rejection. The folds and rejections are decisions the operator has not taken, so they are not recorded as decided here.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every candidate carries a disposition: land, fold, or reject | `awk -F'\t' '$3 ~ /^candidate/' scripts/lint/norm-judgements.tsv` still lists four candidates a disposition was proposed for and the operator did not approve | Agent [ ] |
| Each land names the evidence that carries it, a failure or a carrier set | read the `## Decisions` rows | Agent [x] |
| Each accepted skill has a roadmap row of its own | `grep` the roadmap for one row per landed skill | Agent [x] |
| No skill is filed and no source line is edited | `git status --short` names the roadmap and this record only | Agent [x] |
| No fold and no rejection is recorded as decided | read `## Decisions pending`: the four un-grilled candidates appear there, not in `## Decisions` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

The first criterion is open and stays open. The operator's ruling is that a fold or a rejection lands only after an explicit grill session, so four candidates carry a proposal and no decision. The row **The remaining class-2 candidates** schedules that session.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `communication-principle-hand-off-by-naming-the-boundary` lands, operator-invoked | six sites, and four prompts apply the shape without naming it. The four moves are a sequence, so the body carries them as an ordered list | this record, and the roadmap row |
| `principle-own-the-scope-you-declare` lands, operator-invoked | thirteen `TODO`-free sites across two documents; the unit is the scope the document declares, so nothing is inferred | this record, and the roadmap row |
| `principle-say-what-done-looks-like` lands, model-invoked, bare name | widened by the operator to all agentic work: an agent applies it while starting work, so it is model-invoked, not a pass over a finished artifact | this record, and the roadmap row |
| `principle-effective-skill-routing` lands, operator-invoked | pi advertises a name and a description and loads the body after the decision, so a description's words are the only router. `case`, `branch` and `trigger` were rejected as the rule's centre because none of them decide what the model reads | this record, and the roadmap row |
| `principle-match-precision-to-stakes` lands, operator-invoked | four questions in order: the assumption, the reach of a wrong move, reversibility, reporting. Stakes are stated rather than priced, and `assumptions` and `gaps` replace the known and unknown model | this record, and the roadmap row |
| Every landed skill is written in general terms, with one labelled row for this repository | a local name in the rule body makes the rule about this repository; the operator caught `scope gate` doing exactly that | every landed item |
| `write-plainly` was settled before this review, as a draft with its own promotion row | `20261020-10` | the roadmap row **The plain-wording standard** |
| No fold and no rejection is recorded here | the operator's ruling: a fold or a rejection lands in the next iteration only after an explicit grill session | `## Acceptance criteria`, first row |

## Decisions pending

| Candidate | Proposed in this session | Why it is not decided |
|---|---|---|
| `one-subject-per-prompt` | fold into `principle-own-the-scope-you-declare`, since two subjects are two stages | the fold needs its own grill session |
| `define-before-you-use` | fold into `communication-principle-attach-as-you-read`, whose table already states it | the fold needs its own grill session |
| `describe-only-what-is-true` | reject, because both sites are architecture-document obligations and the general form would forbid the roadmap | the rejection needs its own grill session |
| `co-location` | reject, because progressive disclosure already sits beside it in the same policy section | the rejection needs its own grill session |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| A candidate's unit must be readable from the document, or the rule cannot be applied | result | `stage` was rejected for inventing a unit; `step` survives only where a runbook numbers its steps; the five landed skills each read a unit the artifact declares | every landed item |
| Two candidates turned on terms that decide nothing about the runtime | result | `case`, `branch` and `trigger` were replaced by the description's words, after checking how pi advertises a skill | `principle-effective-skill-routing` |
| A rule resting on a counterfactual cannot be followed | result | the cost axis became reach, which a writer can see before acting | `principle-match-precision-to-stakes` |
| An imported cognitive model makes a rule depend on vocabulary the codebase does not use | result | known and unknown became assumptions and gaps | `principle-match-precision-to-stakes` |
| A candidate name can overclaim what its rule covers | result | `end-each-step-on-a-check` implied every prompt ends on a check; the name was replaced by the operator's phrase | `principle-say-what-done-looks-like` |
| `principle-check-placement` links to `principle-encode-lessons-in-structure` and `principle-sequence-verifiable-units`, and neither exists in the repository skill tree | record defect. [CORRECTION -- 2026-10-20] Both skills do exist, in `$AGENT_HOME/agent/skills/`; they are installed and not shipped, so the links resolve in a running container and would break in a rebuild | two related-links that survive a container and not an image | the roadmap row **Twelve ledger rows name an observer they do not have**, or a new row at the next close |
| `prompt-authoring-conventions.md` states that a judgement skill does not set `disable-model-invocation`, and three filed judgement skills set it | record defect | the stated rule and the tree disagree, so the class boundary is unreadable from either | the filing, which edits that file |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | five rows, one per landed skill, each naming its propagation; one row scheduling the four remaining candidates |
| `devlog/handovers/20261020-13-plan-class_2_candidate_review.md` | this record, closing with five approvals and four proposals |
