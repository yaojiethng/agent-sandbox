---
date: 2026-11-21
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - The `order-for-incremental-parsing` cleanup

## Objective

Give `communication-principle-order-for-incremental-parsing` a defined leitwort, a title and description that signpost its model, and a body organized around that model rather than its symptoms.

## Scope

The row is `Give communication-principle-order-for-incremental-parsing a cleanup pass`: no clear leitwort, a description and title that do not adequately signpost, a body longer than its subject needs, and no anchoring on the domain concepts its rules come from.

The design settles the leitwort, the title and description, the body's order, and the prose source line. The voice-rule row (`The voice rule has one owner, and the source carries a scope clause and a test the owner lacks`) and the clause-type rule stay out; they are separate open rows. The file list belongs to the scope proposal.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill directory and frontmatter name are `communication-principle-order-for-incremental-parsing`. | `grep -n '^name:'` reads the new name; `test -d` exits 0. | Agent [x] |
| The H1 is "Order clauses for incremental parsing". | `grep -n '^# '` reads 1. | Agent [x] |
| The description and provider index line trigger on the writing act and name the reader's benefit. | The description contains "Apply when writing or revising a sentence" and "so the reader can attach"; the index line contains "when writing". | Agent [x] |
| The body states the model once, orders the rules under the three failures, and carries the boundary and source line. | The `Prevent ...`, `Where another rule wins` and `Source:` sections are present; the opening names the writer, reader and sentence. | Agent [x] |
| The leitwort is `incrementality`, the mechanism names `incremental parsing`, and the intent is unchanged. | The `leitwort`, `mechanism` and `intent` fields read the expected values. | Agent [x] |
| The seven live carriers use the new name: the six neighbour lists and the act rule's prose pointer. | `node scripts/principle_inventory.mjs` reports 0 findings; no live old-name carrier remains in the skill tree. | Agent [x] |
| The provider index, `scope.md` and the open roadmap rows use the new name; the axis row exists and its handover link resolves. | `grep -c` reads 1 in the index and `scope.md`; the axis row is present; `check_record_citations.sh` is clean. | Agent [x] |
| The current handover is renamed and Active. | `ls` finds the new filename; `grep '^status:'` reads `Active`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The judgement and its mechanism stay as they are. | The operator confirmed both are right; the defect is the body's rigor, not the judgement. | This record. |
| The domain is sentence processing, and the model is incremental parsing. | The body already names working memory, the garden path and good-enough processing, which are that field's concepts. The model is a reader building structure under ambiguity, not a deterministic parser. | This record; the skill body. |
| The leitwort is `incrementality`. | The operator chose the one-word noun over the phrase `incremental-parsing`, which remains the model term in the mechanism and body. `attachment` and `parse` were rejected for ambiguity and deterministic connotations. | The skill frontmatter; this record. |
| The mechanism is `Order clauses for incremental parsing: each phrase must attach to existing structure, never force reanalysis.` | The operator dictated the concise form; it names the lever, the model, the success and the failure in one sentence. | The skill frontmatter; this record. |
| The skill is renamed to `communication-principle-order-for-incremental-parsing`. | The old name named the reader's action; the new name names the writer's action and the model. | The skill directory and frontmatter; the six neighbour lists; the provider index; the roadmap; this record. |
| The body is ordered by the three failures: a working-memory hold, a missing element, and reanalysis. | The three failures match the test and give every rule a reason to exist; the opening names the writer, the reader and the artifact. | This record; the skill body. |
| The family line is cut. | The metadata neighbours, the index line and the corpus map carry the placement, and the body is shorter. | The skill body. |
| The source line names five sources: the two style guides and three processing works. | Bever (1970) and Christianson et al. (2001) are secondary to the model's primary sources; the five cover the actor rule, the other surface rules, incremental parsing, working memory and good-enough processing. They are cited in prose; no new registry file. | The skill body; this record. |
| The description and index line trigger on the writing act, not a finished-sentence flaw. | The operator read the old description as firing only at rewrite; the new text names the writer and the reader's benefit. | The skill frontmatter; the provider index; this record. |
| The boundary section merges the other-rule and other-principle cases, cuts the end-weight and marked-construction sentences, and names the condition-first instruction as `structure-instructions-imperatively`'s. | The passive-voice and quote exceptions are necessary; the end-weight case is already carried by "long condition", and the marked-construction case by "commit to one reading". The condition-first instruction is the act rule's, not a duplicate here. The definition handoff moves into the ownership list. | The skill body; this record. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The roadmap maintenance run finds no stale active milestone. The only finding is the 3.6 closed-row narrative already recorded in `20261120-01` and owned by `/milestone-close`. | Record | None for this iteration; the finding is outside the changed surface. | This record. |
| The skill's Why uses processing concepts with no citation record; the corpus registry covers ASD-STE100 and Global English only. | Record | The domain model is uncited; the operator decides whether to add a record. | This record; the source line cites the processing works in prose. |
| The leitwort convention says "the one word the reader thinks with", but the model's term is the phrase `incremental parsing`. The skill uses the noun `incrementality` for now. | Record | The convention's shape is narrower than the model's term; a future principle may be forced into a less precise noun. | `roadmap.md`, the row `Expand the leitwort to a word or phrase`. |
| `write-for-the-reader` and `keep-a-subject-near` carry titles as nonspecific as the old `attach-as-you-read`; the operator flagged them while settling the boundary. | Record | A reader cannot tell from the title which axis each owns. | `roadmap.md`, the row `Name the axis each reference principle owns`. |
| `write-for-the-reader`'s intent ("context the reader does not have") can be read to include a sentence-internal missing antecedent, and `one-addressing-axis` shares the word "order" with this skill's clause order. The local boundary is the new `What it does not cover` line; the deeper ownership question is a corpus-map decision. `one-addressing-axis` was checked and is a false overlap: list form, not clause order. | Record | The titles and intents leave the ownership ambiguous; resolving it here would expand the cleanup into the corpus taxonomy. | `roadmap.md`, the row `Name the axis each reference principle owns`. |

## Completed

| File | One-line change summary |
|---|---|
| [`communication-principle-order-for-incremental-parsing/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-order-for-incremental-parsing/SKILL.md) | The rename, H1, description, leitwort, mechanism, body, boundary and source line. |
| [`communication-principle-define-terminology-before-use/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-define-terminology-before-use/SKILL.md) | The `metadata.neighbours` entry updated. |
| [`communication-principle-keep-a-subject-near/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-keep-a-subject-near/SKILL.md) | The `metadata.neighbours` entry updated. |
| [`communication-principle-link-what-the-reader-can-open/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-link-what-the-reader-can-open/SKILL.md) | The `metadata.neighbours` entry updated. |
| [`communication-principle-single-train-of-thought/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-single-train-of-thought/SKILL.md) | The `metadata.neighbours` entry updated. |
| [`communication-principle-structure-instructions-imperatively/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-structure-instructions-imperatively/SKILL.md) | The `metadata.neighbours` entry and the prose pointer updated. |
| [`communication-principle-write-for-the-reader/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md) | The `metadata.neighbours` entry updated. |
| [`src/reasoning/agent-runtime/pi/config/agent/AGENTS.md`](../../../src/reasoning/agent-runtime/pi/config/agent/AGENTS.md) | The index label, path and writing-time text. |
| [`workflow/coding-agent/prompts/scope.md`](../../../workflow/coding-agent/prompts/scope.md) | The principle list entry. |
| [`devlog/roadmap.md`](../../roadmap.md) | The cleanup row closes with its outcome; the axis row, the leitwort row and the voice-row link are recorded. |
| [`20261121-02-impl-order_for_incremental_parsing_cleanup.md`](20261121-02-impl-order_for_incremental_parsing_cleanup.md) | The record. |
