---
date: 2026-11-22
milestone: M3.3.7 - The principle corpus admission
type: Documentation
status: Closed
---

# Handover - the leitwort admits a phrase, preferring one word

## Objective

Let `metadata.leitwort` hold a phrase where no word carries the distinction, and keep the single word as the stated form so the allowance does not become the habit.

## Scope

The field row in `principle-skills.md`, `maximize-conceptual-leverage`'s rule and test, a fixture proving a phrase passes the gate, and the roadmap row that closes on them. Not in scope: the 16 blank leitworts, which `roadmap_future.md` files as a population task; and `order-for-incremental-parsing`'s value, which stays as the operator chose it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The field row admits a phrase and states the single word as the preferred form. | Read the `metadata.leitwort` row of `references/principle-skills.md`. | Agent [x] |
| The principle that owns the judgement carries the same rule, so the field and the skill agree. | Read `maximize-conceptual-leverage`'s `Choosing it` and `The test`. | Agent [x] |
| A phrase-valued leitwort passes the gate, and the fixture proves it. | `bash tests/test_principle_frontmatter.sh` reads `17 passed`. | Agent [x] |
| The corpus still passes its own frontmatter gate. | `bash scripts/check_principle_frontmatter.sh` reads `28 principle(s), 0 finding(s)`. | Agent [x] |
| The record and lint gates hold. | `check_handover_format.sh`, `check_record_citations.sh`, `check_record_lifecycle.sh`, `check_record_names.sh`, `lint.sh`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The field admits a phrase, and the principle says to take one word. | The operator widened the field and asked for a strong emphasis on the single word, so the allowance is the exception and the word is the rule. | The field row; `maximize-conceptual-leverage`. |
| The principle body changes with the field, not after it. | `maximize-conceptual-leverage` owns the judgement and argued the opposite; a field that admits phrases while the skill bars them would be two sources for one rule. | `maximize-conceptual-leverage`. |
| A fixture proves the phrase passes. | The gate already accepted any non-empty string, so the acceptance was a fact with nothing showing it; the fixture is the evidence a later tightening would break. | `tests/test_principle_frontmatter.sh`. |
| `order-for-incremental-parsing` keeps `incrementality`. | Handover `20261121-02` records the operator choosing the noun over the phrase, with two alternatives rejected; the row's claim that the convention forced it is false. | The roadmap row; this record. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row's evidence was falsified: it said `incrementality` was used "only because the convention asks for one word", and handover `20261121-02` records the operator choosing the noun over the phrase, rejecting `attachment` and `parse`. | Evidence | The clause is removed from the row, the value stays, and the row still lands because the field question it raises is real. | The roadmap row; this record. |
| The gate never constrained the value's shape: `principle-frontmatter.mjs` rejects only a non-string or an empty value. | Code | Nothing needed to accept a phrase beyond the documentation; the fixture records it. | `tests/test_principle_frontmatter.sh`; this record. |
| `maximize-conceptual-leverage` argues against phrases in three places: its why, its table and its test. | Design | The why and the table still hold as the preference; only the test's phrase clause was absolute and is now conditional on the word not carrying the distinction. | `maximize-conceptual-leverage`. |

## Completed

| File | One-line change summary |
|---|---|
| [`.agents/skills/instruction-authoring/references/principle-skills.md`](../../../.agents/skills/instruction-authoring/references/principle-skills.md) | The `metadata.leitwort` row reads "a single word, or a phrase where no word carries the distinction". |
| [`communication-principle-maximize-conceptual-leverage/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-maximize-conceptual-leverage/SKILL.md) | `Choosing it` says to take one word, with the exception named; `The test` makes its phrase clause conditional. |
| [`tests/test_principle_frontmatter.sh`](../../../tests/test_principle_frontmatter.sh) | A fixture with `leitwort: incremental parsing` passes the gate, at `17 passed`. |
| [`devlog/roadmap.md`](../../roadmap.md) | The leitwort row closes with its landing, the falsified clause removed. |
| [`20261122-05-docs-leitwort_phrase.md`](20261122-05-docs-leitwort_phrase.md) | This record. |
