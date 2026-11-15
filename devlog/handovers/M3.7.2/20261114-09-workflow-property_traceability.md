---
date: 2026-11-14
milestone: M3.7.2 - The change model and its refinements
type: Workflow
status: Closed
---

# Handover - Every kept rule names its property

## Objective

Give the convention its value proposition -- dense, self-carrying commits cost the writer a minute and save every later reader the reconstruction of intent -- and make each rule state the property it preserves, so a rule bearing no relation to one is visible to the review.

## Scope

Continues the parent row *The convention leads from history as a commons and owns the primitives* in M3.7.2, from [`20261114-08`](20261114-08-workflow-history_readers.md), and closes row 755b.

The audit found the convention stating what it requires and never why: the properties were rules with no reason above them, and the marker the iteration first added named the property without carrying it. The file now opens on what the discipline buys, and each rule states in its own sentence what it preserves -- or, where it preserves none, what it protects instead. The same pass removed the presentation scaffolding that had accumulated around the rules.

Out of scope: deleting a rule that preserves no property -- the review decides. The message-rule row that follows is untouched.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The convention opens on what the discipline buys, in one sentence, naming both parties. | read the opening | Agent [x] |
| Every rule section states the rule in the imperative first, and its reason names the property or what the rule protects instead. | read the five openers | Agent [x] |
| A section that preserves no property says what it protects instead. | the working-tree and branch-name openers | Agent [x] |
| Each property names its own unit: the commit, or the line. | read the four invariants | Agent [x] |
| The message section's template carries the parts, and the mood rule cites the manual's own wording. | read the section | Agent [x] |
| No ladder: no section opens on a maxim, supports it, then restates it, and none describes its own shape. | read the file; `grep -c 'rules below are\|states its own procedure'` returns 0 | Agent [x] |
| No count stands where a rule belongs. | `grep -c 'three grains\|two cases\|three tables'` returns 0 | Agent [x] |
| The delivery-type rule sits in the section whose property it preserves. | read `## The fold` | Agent [x] |
| No gap opened: *bisectable* is enforced by the close, not by a new rule. | the audit finding below | Agent [x] |
| Lint passes, and the instruction-growth report is read. | `bash scripts/lint.sh`; `bash scripts/report_instruction_growth.sh` | Agent [x] |
| The row closes with its outcome. | roadmap diff at pre-close | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The convention opens on the value proposition, not on a role inventory. | The parties are two, a reader and a writer, and the writer is the first reader; listing the uses invites a list that cannot be complete, while the trade is one sentence. | the convention |
| A rule states what it preserves, and why that matters to the reader. | The property is the rule's reason; a rule that carries it needs no separate justification, and one that cannot state it is the rule the review challenges. | the convention |
| The property is stated in the rule's sentence, never as a label above it. | A label the reader decodes helps no one; the rule that names what it protects carries its own reason. | this handover |
| A section that preserves no property states what it protects instead. | The rule is kept for a reason the section now carries, and the review can weigh the reason. | the convention |
| The property belongs to the commit, and the series inherits it. | A property stated of the series while every mechanism acts on one commit reads two ways; naming the commit makes the check the commit's. | the convention |
| The imperative mood cites the Git manual's wording. | The manual's sentence carries the rule and its reason together; an example of our own teaches one case. | the convention |
| The convention names no project-side destination for a reason the body cannot hold. | The body budget is git's business and the handover is the project's; a rule binding them couples two organisations that are otherwise orthogonal. | this handover |
| The parts table goes; the template carries the parts. | The table described the template the reader can see, in the same section. | the convention |
| The delivery-type rule belongs to the fold. | It decides what an intermediate may be, which is the fold's subject; under the message section its marker would have named the wrong property. | the convention |
| A count is not a rule. | *Three grains* and *two cases* stated the shape of the material instead of the rule; the rule is what the reader acts on. | this handover |
| Draft in the deciding register, then revise by deletion. | The trace sentence carried the claim; the draft added an introduction, a support clause and a restatement around it, and each rung reads as content so the cut principles pass it. | `AGENT_FEEDBACK.md`, `[A] 2026-11-14` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The convention had no statement of what the discipline buys: every rule was defensible only by taste. | record | the axis the whole file lacked | this iteration |
| The first attempt at the opening listed seven readers, which is a list that cannot be complete; the reader and the writer are the parties. | record | overprescription in the opening | this iteration: one sentence, both parties |
| The message section restated its template four times, and taught the imperative mood with one example of its own. | record | four statements of one template, and an example standing for a rule | this iteration |
| The sections stated destinations in the project's organisation -- the handover, the ADR -- as though they were the history's. | record | two organisations coupled in one rule | this iteration |
| *Three grains* and *two cases* counted material where the rule was the subject. | record | a shape standing in for a rule | this iteration |
| The two-case authority block restated *amend while the history is cheap, beyond that the operator rules*. | record | a second rule for one situation | this iteration: deleted |
| The property marker was a label the reader had to decode above the rule it named; the first restatement was declarative, so the rule arrived after its subject. | record | a rule that did not carry its own reason | this iteration, on the operator's review: each opener states its property instead |
| The *self-explanatory* invariant made the series its subject while the message rules act on one commit, so the opener could be read either way. | record | a property of two units | this iteration: the commit is the unit, and the series inherits it |
| Six more ladders survived the first pass: the message section's opener restated its own invariant, the fold's pointer described the section's shape, the discard list carried a bold label, the copy-aside sentence named "the case it serves", the grouping paragraph carried a maxim with no consumer, and the runbooks section closed by describing itself. | record | scaffolding around every rule | this iteration |
| The audit proposed a gap for *bisectable*: nothing runs the suite per commit. | record | none -- the premise was wrong | the close: `/iter` and `/wrapup` commit once and run the suite at commit time, and `history-cleanup` re-proves after it rewrites |
| `## Runbooks` and `## Where to look` are pointers, not rules. | record | no property to state | this handover |

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/git-discipline/SKILL.md` | opens on the trade; each rule states its property in the imperative with its reason; the message section reworked around its template; the two-case block deleted; the delivery-type rule moved into the fold; six ladders cut |
| `.agents/registry/citations/` | four records: kernel patches, Google small CLs, Beams, Pope |
| `docs/adr/git_commit_history_commons.md` | the derivation sentence names the series section; the body budget stated once, with no paragraphing rule |
| `devlog/AGENT_FEEDBACK.md` | `[A] 2026-11-14`: the ladder, and the deletion-only revision that removes it |
| `devlog/roadmap.md` | row 755b closes, compacted |
| (maintenance) | `roadmap-maintenance`: 0 findings; `handover-maintenance`: 0 findings. |
