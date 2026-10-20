---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - a banned word list yields to a domain term

## Objective

Settle the conflict between the domain exception and any rule that bans a word by name, so the exception is answerable when two loaded rules disagree.

## Scope

One clause in the STE100 exception and one in the `AGENTS.md` bullet that mirrors it, the ledger row the edit moves, and this record.

Out of scope: `unslop` itself, which stays installed-only.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The clause states the test, not a word list | read it: a word that names a thing in the domain is its term | Agent [x] |
| The clause states which rule wins | read "no list of banned words overrides it" | Agent [x] |
| Both `AGENTS.md` copies carry the clause | `grep -c` returns 1 in each | Agent [x] |
| The ledger, the grouping and the gates are clean | `--check`, `--groups`, `scripts/lint.sh` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The clause names a test rather than the words | the operator's ruling is that `harness` is always the domain term here, and a test covers `surface` and whatever the next word is without a list that ages | the STE100 exception |
| The clause states the precedence | a reader who loads `unslop` and the policy together holds two rules and no way to order them | the same clause |
| `unslop` is not shipped | the ruling settles the disagreement without moving a skill into the repository | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The domain's vocabulary collides with an installed rule at 401 occurrences | fact | the collision is large enough that the precedence clause is load-bearing rather than tidy | the policy and both `AGENTS.md` copies |
| The previous handover recorded a roadmap row owed for the `unslop` conflict | result | this landing discharges it, so no row is added | this record |
| `primitive` remains unread | fact | unslop bans it as a noun and the repository uses it 25 times, so a reading is owed before it is called a collision | the next prose pass |

## Completed

| File | Change |
|---|---|
| `docs/policies/documentation_policy.md` | the precedence clause in the STE100 exception |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | the same clause in the plain-words bullet |
| `~/.pi/agent/AGENTS.md` | the same bullet |
| `scripts/lint/norm-ownership.tsv` | the edited line reclassified |
| `scripts/lint/norm-judgements.tsv` | the row kept in `j-ste100-domain-exception` |
| `devlog/handovers/20261020-25-workflow-banned_word_lists_yield_to_domain_terms.md` | this record |
