---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - the sentence-structure principle rewritten

## Objective

Rewrite `communication-principle-attach-as-you-read` so it reads as sentence-structure guidance in the vocabulary of its own field, and route the terminology case to the skill that owns it.

## Scope

The skill in both copies, the two `AGENTS.md` bullets that restated it, and this record.

Out of scope: the name, which stays, and the `unslop` conflict, which the previous handover recorded.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The title and headings follow the house shape | read the file: sentence-case title, four `##` sections | Agent [x] |
| The description names the situations that call for the skill | read the `description` | Agent [x] |
| The end-weight sentence no longer contradicts end-weight | read `## Where another rule wins` | Agent [x] |
| The test is three conditions and an action, not one run-on | read `## The test` | Agent [x] |
| The theoretical claim states its mechanism | read the last sentence of `## Why` | Agent [x] |
| The terminology case routes to its home | read the last paragraph | Agent [x] |
| `defined noun` appears in neither the skill nor `AGENTS.md` | `grep -c` returns 0 in all three files | Agent [x] |
| Both skill copies are byte-identical | `diff -q` over the two files | Agent [x] |
| The ledger and the gates are clean | `--check`, `scripts/lint.sh` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The linguistics terms stay | the previous turn established that the domain's own vocabulary is the precise one inside that domain | the whole file, and the STE100 exception |
| The name stays | it summarises the rule, the description carries the situation, and two carriers already cite it | this record |
| The description drops "when writing or editing a sentence, a prompt, a skill, or a document" | it selected every writing situation, so it routed nothing | the `description` |
| `A passive is felicitous` replaces `A passive is correct` | felicity is the domain's own axis, where correctness has no scale | `## Where another rule wins` |
| End-weight is stated in the direction it runs | the previous sentence claimed end-weight puts a heavy constituent first, which is the reverse of what it does | `## Where another rule wins` |
| The theory is named by its mechanism, not by a citation | the mechanism is what the writer acts on, and the repository holds no bibliography convention | `## Why` |
| `AGENTS.md` states the rule in one bullet and points at the skill | the second layer restated the rule in its own words, which is the second statement this milestone removes | both trees |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The previous `AGENTS.md` bullet carried three judgements in one sentence | fact | the split into two bullets is why the terminology rule reaches the second layer at all | both trees |
| `The test` stated three conditions and an action in one sentence | defect | a reader could read the fix as a fourth condition | the file |
| The description repeated the body's first line word for word | defect | the description is the router, so it must say what the body does not use its space to say | the file |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-attach-as-you-read/SKILL.md` | rewritten: sentence-case title, four sections, three-item test, corrected end-weight and felicity, terminology route |
| `~/.pi/agent/skills/communication-principle-attach-as-you-read/SKILL.md` | the installed copy, byte-identical |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | one bullet points at the skill, one at the terminology principle |
| `~/.pi/agent/AGENTS.md` | the same two bullets |
| `devlog/handovers/20261020-24-workflow-attach_as_you_read_rewrite.md` | this record |
