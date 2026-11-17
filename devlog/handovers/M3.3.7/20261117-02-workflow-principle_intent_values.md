---
date: 2026-11-17
milestone: M3.3.7 - The principle corpus admission
type: Workflow
status: Closed
---

# Handover - Back-construct the principle intent values

## Objective

Fill `metadata.intent` and `metadata.mechanism` on the 20 principle cards the pilot did not cover, from the operator's own statements in the session logs, so every principle records the judgement it serves and the way that judgement exerts influence.

## Scope

Roadmap row "Every principle records its operator's intent and mechanism". In scope: the frontmatter of the 20 cards that carry neither field. Out of scope, one sentence each: the five reader-context cards already carry the operator's pilot values and are unchanged; the neighbour fields and the card bodies are other work; the load-level terms and the link normalisation are separate rows.

The values are back-constructed from the operator's statements in the session logs at `/home/agentuser/.pi/agent/sessions/--home-agentuser-sandbox--/`, chiefly the 2026-11-16 grouping (19:25, 19:35, 19:45, 19:51, 22:17 to 23:15), the dry-run table (17:53) and the 2026-11-15 one-by-one review (23:14 to 23:45). Each value names its provenance in the Decisions table.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| All 25 cards carry `intent` and `mechanism`, and the corpus gate is clean. | A directory walk counts 25 with both fields; `bash scripts/check_principle_frontmatter.sh` reports 25/0. | Agent [x] |
| Every value traces to the operator's wording or the card's approved sentence, and no value is invented. | Read the Decisions table against the sources it names; every row carries a provenance. | Agent [x] |
| The gate fails a card that lacks `intent` or `mechanism`, and its tests cover it. | `bash tests/test_principle_frontmatter.sh` reports 16 passed; the missing-intent and missing-mechanism cases assert the finding. | Agent [x] |
| The convention and the shape record state that both fields are required. | Read `skill-conventions.md` and the 2026-11-17 entry in `principle_skill_shape.md`. | Agent [x] |
| The document gate, the lint umbrella and the suite are clean. | `bash scripts/check_document_shape.sh`; `bash scripts/lint.sh`; `bash scripts/run_tests.sh` at `TEST_PARALLEL=2` reports 1642/1642. | Agent [x] |
| The roadmap row is `[x]` with its Landed note and handover link, and the four concluded records are named by the open rows that use them. | Read `devlog/roadmap.md`; `bash scripts/check_record_lifecycle.sh` reports clean. | Agent [x] |

## Decisions

| Card | `intent` | `mechanism` | Provenance |
|---|---|---|---|
| align-the-mental-model | Aligning domain model and task intent. | Naming: one word for each thing and one meaning for each word. | Quote, "aligning domain model and task intent"; card. |
| cut-metadiscourse | Information is to be made as concise and dense and stripped-down as possible, and metadiscourse hampers that. | A deletion test on a sentence in the flow: a sentence that can be deleted without loss is cut whole. | Quote, "information is to be made as concise and dense and stripped-down as possible, and metadiscourse hampers that"; card. |
| dont-forecast-undone-work | Prevent speculative requirements, avoid overengineering, ensure that the content written back reflects reality. | A deletion rule for text: a forecast is removed, or moved to the record that holds the work. | Quote, "prevent speculative requirements, avoid overengineering, ensure that the content written back reflects reality"; "define a deletion rule for text". |
| keep-a-subject-near | Keep related concepts together, so the reader can point at what you are talking about. | Colocation: a subject and its parts share one place. | Quote, "colocation (keep related concepts together)"; "how do i point at what you are talking about?"; card. |
| maximize-conceptual-leverage | Choosing precise, descriptive domain terms, so that communication is as concise and dense and stripped-down as possible. | The best leading words are terms already prominent within a domain's problem language; prefer terms already common in the corpus. | Quote, "aims at choosing precise, descriptive domain terms, so that communication is as concise and dense and stripped-down as possible"; "prefer terms that are already common in the corpus". |
| name-the-value-not-a-literal | The reader can access a value the text presents, not the text assuming that the reader can. | Referents and labelling: how do I point at what you are talking about? A reference to the record that holds the value, so the reader can reach it. | Quote, "the reader being unable to access a value the text presents assuming that the reader can"; "its about referents and labelling. how do i point at what you are talking about?"; card. |
| one-addressing-axis | A numbered or lettered list asserts a relation between its items; print one axis per presentation. | List form: print one axis per presentation, and name each axis when two sets appear. | Card. |
| only-derive-what-you-own | A derived value is a copy of data held elsewhere, and the copy is what an update misses. | The sentence that states a total, a percentage or a count: it names the source rather than restating the derived value. | Card. |
| organize-by-diataxis | Organizing documents and contents according to the Diataxis mode, not conflating the technical concerns. | Name the Diataxis mode each unit serves, then file it under that mode, link the seam, and move what serves another need. | Quote, "organizing documents and contents according to the diataxis mode, not conflating the technical concerns"; card. |
| rewrite-syntax-never-semantics | Syntax may change; the quantifiers, negations, modals and keywords that decide what is required may not. | A diff against the author's words: the syntax is rearranged, the semantic keywords are held, and a disagreement names the clause. | Card. |
| show-dont-describe | When statements are backed up with evidence, it replaces a claim with a stronger modal equivalent: a fact. Less effort to verify, better input into decision making. | The prose: a template, a command, an example or the output stands where a description asks the reader to interpret. | Quote, "when statements are backed up with evidence, it replaces a claim with a stronger modal equivalent: a fact. less effort to verify, better input into decision making"; card. |
| state-intent-delegate-method | An instruction states what the work must achieve, and the route through it belongs to the party who holds the context. | The instruction's wording: the intent and the boundary are stated, and the method is left to the doer. | Card. |
| approval-writes-the-artifact | Making sure changes are not lost in chat: write them back, so that if the session is ended or lost, we won't drop decisions or changes. | The file that is the artifact's source of truth: the approved text is written there in the same unit of work as the approval. | Quote, "about making sure changes are not lost in chat - write them back, so that if the session is ended or lost, we wont drop decisions or changes"; card. |
| check-placement | A check reads evidence and produces a decision. Put the check where the evidence first exists, and where the decision is cheapest to take. | The check's position in the workflow: after the producer of its evidence and at the step that owns the decision. | Card. |
| guard-the-context-window | A capacity claim is a reading or an inference, and the reading comes from the window itself. | The claim about room left: measure the window, route bulk out, and name the unit each pass counts. | Card. |
| justify-materialization-cost | Whether to store a generated result is a decision you keep paying for: a materialized copy must be maintained, and it drifts without a warning. | The materialization decision: name what catches the drift, and store only when the cost is justified. | Card; the operator's "item B3 in the ruling" case. |
| match-precision-to-stakes | An instruction's precision follows what the writer can establish, not what the consequence would cost. | The rule's modal strength and its checks: rule, judgement or permission, with a check that reports a departure. | Card. |
| propagation-discipline | Maintaining the organization of the repo: preventing the occurrence of stale content by making sure that changes propagate to all related files. | Every carrier of the old state is part of the task, and a deletion's carriers include the descriptions as well as the references. | Quote, "maintaining the organization of the repo - preventing the occurence of stale content by making sure that changes propagate to all related files"; card. |
| say-what-done-looks-like | Agent-operator alignment during task dispatch: an agreement on the final result, so that no party is surprised. | The instruction and its acceptance: the finish, the bound, and one criterion with an instrument other than the agent's belief. | Quote, "focuses on agent-operator alignment during task dispatch. an agreement on the final result, so that no party is surprised"; card. |
| single-source-of-truth | Clarity in organization: the artifact has one authoritative place, the reader does not get conflicting information, and maintenance is easy. | One subject in one mode has one source of truth. | Quote, "its about clarity in organization. the reader does not get conflicting information. maintainence is easy... The artifact has one authoritative place"; card. |

The method decisions the values implied:

| Decision | Rationale | Where recorded |
|---|---|---|
| The gate makes `intent` and `mechanism` required. | All 25 cards are ratified, so an absent field now means a card was admitted without its provenance; the row names a presence gate. | This record; `principle_skill_shape.md` 2026-11-17. |
| The four concluded survey records move to the open rows that use them. | The census feeds the link normalisation, and the map feeds the load-level and just-in-time rows; deleting the records would remove live inputs. | `devlog/roadmap.md` rows 381 to 384. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The 2026-11-15 one-by-one intent review stopped after group 1, and the remaining intents came from the family-level grouping. | record | The values rest on the operator's family statements and the approved card sentences, not on a per-card review; this table is the per-card review. | This record; the pre-close table. |
| `single-train-of-thought` already carries an operator value, so the pilot's "correct" reply did not leave a gap. | record | No edit follows. | This record. |
| Closing row 380 left four concluded discussion records with no open row, and the record gate failed the close. | record | The records are live inputs to the remaining M3.3.7 rows. | Re-pointed to rows 381 to 384; gate clean. |

## Completed

| File | One-line change summary |
|---|---|
| The 20 principle `SKILL.md` files | Added `metadata.intent` and `metadata.mechanism` from the provenance table. |
| `scripts/lint/principle-frontmatter.mjs` | `intent` and `mechanism` are required; `leitwort` stays conditional. |
| `scripts/check_principle_frontmatter.sh` | Header states the required set. |
| `tests/test_principle_frontmatter.sh` | Fixtures carry the fields; the missing-intent and missing-mechanism cases added (16 tests). |
| `.agents/skills/instruction-authoring/references/skill-conventions.md` | Both fields required; the provisional-value clause removed. |
| `docs/adr/principle_skill_shape.md` | New 2026-11-17 entry: the fields are required. |
| `devlog/roadmap.md` | Row 380 closed with its Landed note; the four concluded records named by the open rows that use them. |
| `devlog/handovers/M3.3.7/20261117-02-workflow-principle_intent_values.md` | This record with the provenance table. |
