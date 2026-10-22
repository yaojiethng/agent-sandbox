---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - the plain-wording draft

## Objective

Settle the two class-2 candidates the map raised, and give the plain-wording judgement a place to live that is not a live skill.

## Scope

The follow-on the operator directed after the map closed: reject `one-term-one-meaning`, and land `write-plainly` as a draft whose provenance record states the future.

In scope: the draft directory, the two candidate decisions, the roadmap row, and the record updates those force.

Out of scope, with reason: promoting the draft, editing `documentation_policy.md` or the provider-layer `AGENTS.md`, and touching `/technical-writing`. All three belong to **The plain-wording standard**, which the roadmap row schedules behind the filing.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `one-term-one-meaning` is rejected and cannot drift back | `check_norm_ownership.sh --groups` classes `j-one-term-one-meaning` local | Agent [x] |
| The draft states no borrowed rule | read `SKILL.md`: every rule it names is a dispatch row, not a statement | Agent [x] |
| The draft borrows the shape, not the contents, of `/technical-writing` | the directory is a skill, the file dispatches to other principles, and each header states the provenance of what it holds | Agent [x] |
| The provenance record states the future and the blockers | `README.md` names the policy, the `AGENTS.md` restatement, the skill to subsume, its fork source, and the four blockers | Agent [x] |
| The draft is unreachable by every live path | it sits under `.agents/drafts/`; no dispatch names it | Agent [x] |
| The gates are clean with the new files in the tree | `bash scripts/lint.sh`, and the record-links gate resolves both new links | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The draft borrows `/technical-writing`'s shape and none of its content | the operator's correction: the draft is a home for the findings, and restating the standard would create the second statement the milestone removes | the report's `## The twelve proposed names`, and the draft's `## What the map measured` |
| The rejection settles the home and not the content | a skill for a judgement one document states would be a second home beside the policy; the content still has a future | `README.md`, `## Why it is not filed yet` |
| The draft stays under `.agents/drafts/` until the filing decides the pointer sentence's kind | the ledger kind decides whether the policy's section becomes a pointer, so promoting first would invert the home order | `README.md`, `## What blocks promotion` |
| `one-term-one-meaning` takes a local note | a rejection recorded only in prose can be undone by the next reader; the note makes the gate hold it | `norm-judgements.tsv` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The `record-links` gate rejects a link whose target is a directory | gate behaviour | a roadmap row must point at the draft's `SKILL.md`, not at its directory | the roadmap row |
| A link from `devlog/roadmap.md` needs one `../`, while the same target from `devlog/discussions/` needs two | result | both links now resolve, and the first attempt failed on exactly this | the two edited records |
| `write-plainly`'s five sites split three gated, two ungated | result | the standard's remaining job is the ungated residue plus the three-surface ownership question, not the whole style guide | the draft, `## What the map measured` |

## Completed

| File | Change |
|---|---|
| `.agents/drafts/communication-principle-write-plainly/SKILL.md` | new draft: what the map measured, what it would own, a dispatch table naming each rule's existing home, provenance per header |
| `.agents/drafts/communication-principle-write-plainly/README.md` | new: why it is not filed, what it becomes, the four blockers, the promotion route |
| `scripts/lint/norm-judgements.tsv` | `j-one-term-one-meaning` takes a local note, so the gate holds the rejection |
| `devlog/discussions/20261020-report-settled-duplication_map.md` | the two candidate outcomes rewritten as decisions |
| `devlog/roadmap.md` | new row **The plain-wording standard**, scheduled behind the filing |
| `devlog/handovers/20261020-10-workflow-plain_wording_draft.md` | this record |
