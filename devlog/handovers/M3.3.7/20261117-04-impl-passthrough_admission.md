---
date: 2026-11-17
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - Admit the passthrough judgement as a sibling principle

## Objective

Land the passthrough judgement the operator raised on 2026-11-14, reframed at the scope gate: a bridge document, a forwarding function and a staged commit each stand between a producer and the result its consumer reads, and none has a consumer of its own. The admission ran before the card: the inventory and the case decided a new judgement, landed as a sibling.

## Scope

Roadmap row "A passthrough with no consumer has one judgement, not three fragments". The operator filed the row on 2026-11-14, before M3.3.7's method was settled, so the observation would not be lost. At the scope gate the operator reframed the judgement. The defect is not the missing guarantee. The passthrough has no consumer of its own, and it pays three costs: it carries no subject, so it is a copy (SSOT); it materializes a result with no justification (materialization); and a bridge of links, a wrapper's signature and a staged write each propagate every edge change (propagation).

In scope: the admission decision, the new principle card with its `metadata.neighbours`, `metadata.intent`, `metadata.mechanism` and body, and the row's title and text amended, then closed with its Landed note. Out of scope, one sentence each: the SSOT card is not edited, because the new card owns the class and cites SSOT for the copy angle; the corpus map is the 2026-11-16 run's evidence and is not rewritten; the other docket rows are separate iterations.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The new card exists with `name`, `description`, `intent`, `mechanism`, `leitwort`, `neighbours`, and the gate reports 26 cards clean. | `bash scripts/check_principle_frontmatter.sh`; read the path. | Agent [x] |
| The card separates what to remove from what to keep, and its test names the consumer and the paying factor. | Read the card. | Agent [x] |
| The card's sibling references are relative links, and the four neighbours are live. | `bash scripts/lint.sh`; the frontmatter gate. | Agent [x] |
| Row 382 carries the consumer framing and is `[x]` with its Landed note. | Read `devlog/roadmap.md`. | Agent [x] |
| Every decision this iteration records is realized in the files. | Read the Decisions table against the diff. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The passthrough class is a new judgement, landed as a sibling card. | No neighbour's test asks which consumer reads the artifact for itself, and the wrapper function is the instance the three neighbours miss. | This record; the placement check in chat; row 382. |
| The card cites the three costs and does not restate their tests. | A card that repeats SSOT, materialization and propagation would be a composite, and the duplicate test would fail. | This record. |
| The class term is `passthrough`, with `middleman` and `lazy class` stated as its literature names. | It is the operator's word, the design record's case name, and two established names from the domain; "relay" names a legitimate component. | This record; the card. |
| The title is `Remove the passthrough`, the name is `principle-remove-the-passthrough`, and the verb is `remove`. | The refactoring domain names the smell the middleman or the lazy class and the action remove; the title keeps one word for the thing. | This record; the card. |
| The card states the antipatterns to remove and the patterns that are fine, as two separate sets. | The passthrough shape is not the defect, and no antipattern pairs with a pattern; a paired table asserts a comparison that does not exist. | This record; the card. |
| The `**Why.**` answers why the operator or agent should apply the principle, and names the SSOT violation directly. | The part motivates the application, and the consequence is the second source that SSOT names, not a description of two consumers. | This record; the card. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row originated as a parked observation and a question, not an order to restore a lost rule. | record | The scope states what the operator asked, and the admission answers it; whether the three kinds are one class is the decision, not an assumption. | This record; `devlog/roadmap.md` row 382. |
| The operator reframed the judgement at the gate. The defect is the missing consumer, not the missing guarantee, and the card must not centre on "guarantee". | steering | The card's name, fields, test and body follow the consumer framing; the retired test is the check, not the centre. | This record; row 382's amended text. |
| The scope gate assumed the sibling outcome and skipped the admission's placement step. | process | The admission pattern and the inventory lever decide the outcome, and the design record's replay is evidence, not the decision. | This record; the placement question above. |
| The term "relay" is rejected. It names a legitimate pattern, a proxy or a router, and would legitimise the defect. | steering | The card is not written with "relay"; the class term is `passthrough`. | This record; the card. |
| The "wrapper function" row was underspecified. A decorator, an adapter or a monad shares the shape and is a legitimate pattern. | steering | The card states the pattern beside the antipattern, or it bans legitimate wrappers. | This record; the card's pattern part. |
| The `**Why.**` explained the defect, not the motivation to apply the principle, and the table paired patterns where no comparison exists. | steering | The Why is consequence-forward, and the card lists what to cut and what to keep as separate sets. | This record; the card. |
| The writing-for-agents pass finds the card is reference, with no steps and no disclosure need. The Why described an effect rather than naming the rule it becomes. | process | The card stays reference; the Why names the second source, and the boundary says SSOT catches it once a reader uses it. | This record; the card. |
| The domain survey finds the refactoring literature names the smell and the action, and the prose literature's "trim" is the surface action this corpus rejects. | process | The card takes `remove` as the verb, with `middleman` and `lazy class` as the literature's names. | This record; the card. |
| The boundary's SSOT case was passive, and the sibling names were code spans, not links. | steering | The boundary uses the operator's active sentence, and the card follows the corpus link form. | This record; the card. |
| The boundary referred to "this judgement" and to what SSOT's test cannot see, which is metadiscourse. | steering | The boundary states the SSOT case directly and the no-consumer case as a condition. | This record; the card. |
| The title "serves no consumer" was ambiguous in relation, and the card now takes the refactoring action. | steering | The title is `Remove the passthrough`, the name carries the verb, and the row title carries the consumer condition. | This record; the card; row 382. |

## Completed

| File | One-line change summary |
|---|---|
| `src/reasoning/agent-runtime/pi/config/agent/skills/principle-remove-the-passthrough/SKILL.md` | The new card with its six frontmatter fields and its body. |
| `devlog/roadmap.md` | Row 382 amended to the consumer framing and closed with its Landed note. |
| `devlog/handovers/M3.3.7/20261117-04-impl-passthrough_admission.md` | This record, renamed off the rejected term. |
