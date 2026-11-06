---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - the plain-words rule admits domain language

## Objective

State the exception that lets a well-specified technical domain use its own terms, so a principle about sentence structure can be written in the vocabulary of linguistics.

## Scope

The STE100 statement and its phrasing bullet in `documentation_policy.md`, one bullet in `AGENTS.md` in both trees, the ledger rows the edits move, and this record.

Out of scope: the `unslop` skill, which lives only in the installed tree and bans several of this repository's own terms.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The exception names its two conditions | read the sentence at line 45: a well-specified domain, a reader who works in it | Agent [x] |
| The exception admits one field only | read the clause "use no other field's" | Agent [x] |
| A term the reader may not hold still needs a definition | read the pointer to `principle-define-terminology-before-use` | Agent [x] |
| The second statement of the same rule is gone | line 55 no longer says to keep technical nouns | Agent [x] |
| Both `AGENTS.md` copies carry the new bullet | `grep -c "unless the reader works in the domain"` returns 1 in each | Agent [x] |
| The ledger, the grouping and the gates are clean | `--check`, `--groups`, `scripts/lint.sh` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The exception sits on the STE100 statement and not in the phrasing list | the list holds detailed rules, and the exception governs all of them | `documentation_policy.md`, `### Simplified Technical English` |
| The exception admits one field, not several | a reader who holds three vocabularies pays the same cost as a reader who holds none | the sentence itself |
| The definition duty survives the exception | a domain term the reader may not hold is still undefined, and the terminology principle owns that | the pointer sentence |
| "Keep technical nouns the reader needs" is deleted | it stated the exception before the exception existed, so it became a second home | `documentation_policy.md:55` |
| `unslop` is not edited | it lives in the installed tree only, so an edit cannot be shipped, and it conflicts with the exception on several entries | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The repository had no plain-words rule to amend | fact | the plain-words discipline lives in the installed `unslop` skill and in the STE100 reference, so the exception is the first statement of the boundary inside the repository | this record |
| `unslop` rules 7, 26 and 31 ban words this repository relies on | record defect | an agent that loads both reads one rule that permits the term and one that bans it, and the installed copy cannot be corrected from here | a roadmap row is owed |
| A new judgement in a second document needs its own named group | process, recurrence | the second occurrence of this gate failure in two landings means the regroup step should name the new rows rather than dumping them into `j-ungrouped` | this record |

## Completed

| File | Change |
|---|---|
| `docs/policies/documentation_policy.md` | the exception at line 45, and line 55 narrowed to the STE100 clause |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | a bullet stating plain words unless the reader works in the domain |
| `~/.pi/agent/AGENTS.md` | the same bullet |
| `scripts/lint/norm-ownership.tsv` | both edited lines classified |
| `scripts/lint/norm-judgements.tsv` | two named groups, `j-ste100-domain-exception` and `j-ste100-scope` |
| `devlog/handovers/20261020-23-workflow-plain_words_domain_exception.md` | this record |
