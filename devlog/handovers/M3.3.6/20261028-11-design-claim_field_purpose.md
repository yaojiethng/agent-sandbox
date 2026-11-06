---
date: 2026-10-28
milestone: M3.3.6 - The instruction corpus
type: Design
status: Closed
---

# Handover - the claim field, judged

## Objective

Settle whether a principle's `metadata.claim` earns its keep, and land the corpus change the ruling implies. The operator's doubt is that the five categories are arbitrary and that the classification therefore helps nobody.

## Scope

The field's carriers:

| File | Why in scope |
|---|---|
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | `## The principle claims` is the table's only home and the gate reads the set from it |
| [`scripts/lint/document-shape.mjs`](../../scripts/lint/document-shape.mjs) | the claim validation and the `--map` mode |
| [`scripts/check_document_shape.sh`](../../scripts/check_document_shape.sh) | the header documents the claim rule and `--map` |
| [`tests/test_document_shape.sh`](../../tests/test_document_shape.sh) | the missing-claim and unknown-claim cases |
| [`docs/adr/principle_skill_shape.md`](../../docs/adr/principle_skill_shape.md) | its edge-case clause states the declaration and the gate boundary |
| the twenty-seven principle skills under `src/reasoning/providers/pi/config/agent/skills/` | each carries the declaration in its frontmatter |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the new row, and the merged-instruction-writing-surface row that plans to inherit the table |

Out of scope: the corpus's other metadata (`leitwort`), which M3.2.2 settled, and the wording of the five tests beyond what the ruling requires.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No skill or prompt declares a claim | `grep -rn '^\s*claim:'` over `docs/`, `src/`, `workflow/`, `.agents/`, `AGENTS.md` returns 0 | Agent [x] |
| The convention states five tests as question headings, each with its test and a linked member list | read the section; the link gate passes | Agent [x] |
| The member lists are navigation and say so | one sentence in the section | Agent [x] |
| The index names every principle skill | 27 listed against 27 directories, no duplicate, none missing, no phantom | Agent [x] |
| The shape gate carries no claim rule and no `--map` | `grep` across the gate, its scanner and its tests returns 0; `tests/test_document_shape.sh` passes 11 with the three claim cases removed | Agent [x] |
| The ADR no longer asserts a field the tree does not hold | a new current entry names the retired clause; the historical entry stands | Agent [x] |
| The roadmap records the ruling and the merged-surface row drops the inherited table | the diff | Agent [x] |
| Every decision recorded is realized in the files | the decisions table | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The field is judged by whether anything decides on its value | the corpus's materialization rule asks what catches a stored copy's drift; the claim has no detector and no reader whose action changes | this record |
| The table's right column is the durable part, and the label is the copy | each row states a test in prose, and a test is read where it is written; a per-file label restates which test applies and is read by nothing | this record |
| The field is deleted and the five tests survive, grouped under question headings | the labels state a classification nothing can detect; the tests are the part a writer uses | this record, operator ruling |
| The member lists carry no coverage gate | they are navigation for someone using the conventions, not a registry; the description stays the routing surface, so a missing name is not a defect | the convention, in one sentence |
| The claim rule leaves prose only, with no replacement detector | the field's absence is verified once at this close and guarded by nothing after it | this record, operator ruling |
| The five headings name the points where a decision fails to cross from writer to reader-agent | the domain is the channel, not prose style; the old `reader` heading restated the corpus's goal and the old `authority` named an abstraction | this record |
| `reader` generalizes from "attach as you go" to whether the model gets built | the old heading took the corpus's own goal for a test, and its technique over-fitted the seven communication skills | the convention |
| `authority` becomes "Who owns this decision?", carrying the intent and method split | the new principle sharpened the test: the writer keeps the intent, the bound and the evidence, the doer takes the route | the convention |
| The section is named `## The five questions`, not "tests" | `test` is already the per-skill part (`**The test.**`), so the umbrella keeps a distinct word and no rule changes meaning | the convention |
| The member lists link the module-relative skill path | the linking gate rejects a `$AGENT_HOME` path as a link target while accepting it as inline code | the convention |
| The 2026-10-21 ADR entry keeps its clause as written | an entry below `Current:` is historical and records what was decided then; the new entry names the retired clause, and rewriting history would need a correction tag the convention reserves for a wrong claim | `docs/adr/principle_skill_shape.md` |
| Twenty-two frontmatters lose the whole `metadata:` block, five keep it | `leitwort` is a second key on five skills, and it stays | the frontmatters |

## Decisions pending

None.

## Findings

| Finding | Type | Triaged to |
|---|---|---|
| The field has one reader and takes no decision: the gate checks membership, `--map` prints a browse view, and no prompt, skill or gate selects a principle by its claim | evidence | this handover, Decisions |
| The five are not mutually exclusive: `scope` and `authority` both bound a text, and `evidence` and `source` both trace where a fact came from | evidence | this handover, Decisions |
| The distribution is near-uniform (reader 7, evidence 5, source 5, scope 5, authority 5 of 27), which is what a top-down set looks like after skills are filed into it | evidence | this handover, Decisions |
| Swapping two filings inside a family passes the gate and changes no consumer, so a mis-filing cannot be detected | evidence | this handover, Decisions |
| The merged-instruction-writing-surface row planned to inherit the claim table, so a deletion edits that row too | carrier | `devlog/roadmap.md`, edited with the ruling |
| The linking gate rejects an `$AGENT_HOME` path as a link target, though the same path passes as inline code | defect | fixed in this iteration by linking the module-relative path |
| The 2026-10-21 ADR entry still states the claim clause | decision | this handover, Decisions |

## Completed

| Item | Note |
|---|---|
| the handover opened | this record, type `Design`, from the operator's directive |
| the roadmap row filed | `devlog/roadmap.md`, under M3.3.6 |
| the field's consumers enumerated | `grep` over `scripts/`, `docs/`, and the skill roots; `--map` run |
| the field's extent measured | 27 files carry a `metadata:` block, all principle skills; keys in use are `claim` 27 and `leitwort` 5; no prompt or other skill carries one |
| the ruling recorded | option C, no coverage gate, prose-only rule, the five question headings |
| the convention rewritten | `## The five questions`, five question headings, 27 linked members, the navigation sentence, the two-skills rule kept |
| the field removed | 27 principle skills: 22 lost the `metadata:` block, five kept it for `leitwort` |
| the gate reduced | claim validation, the declared set reader and `--map` removed from the scanner, the shell header and three test cases |
| the ADR amended | a 2026-10-28 current entry, the 2026-10-21 entry left historical |
| the roadmap written | the row closed; the merged-surface row no longer inherits a claim table |
| the gates run | markdown, doc shape, handover format, instruction surfaces, lint (15 gates), suite: 1349 passed across 98 files |
