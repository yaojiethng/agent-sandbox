---
date: 2026-10-03
milestone: M3.2.1 - Loops as Workflows
type: Documentation
status: Closed
---

# Handover - Record the producer-owns-the-definition rule

## Objective

Record the producer-owns-the-definition rule in policy, so the ownership split between a definition and its record has a binding home.

## Scope

The M3.2.1 row `Record the producer-owns-the-definition rule`. The policy map found the acceptance-criteria definition in three policies and settled the case (`iteration_policy.md` owns the model, `handover_policy.md` owns the table), but the general rule was not recorded mid-sweep. This iteration records the general rule in `documentation_policy.md` `## Rule authority`, beside the canonical-owner test it refines.

| In | Out |
|---|---|
| `docs/operations/documentation_policy.md` `## Rule authority` | A new ADR; `policy_declarative_framing.md` already carries the framing this rule applies |
| The roadmap row `Record the producer-owns-the-definition rule` | Re-deriving the acceptance-criteria model or its table; both already sit with their owners |
| The iteration handover | Any change to the acceptance-criteria invariants or the handover format |

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `documentation_policy.md` `## Rule authority` states the rule | `grep -n "Producer owns the definition" docs/operations/documentation_policy.md` | Agent [x] |
| The rule names the acceptance-criteria case with the two owners | the paragraph names `iteration_policy.md` as the model owner and `handover_policy.md` as the table owner | Agent [x] |
| The canonical-owner test and the no-bridge rule are unchanged | `git diff` on the section shows one added paragraph | Agent [x] |
| The rule has one home; nothing restates it | `grep -rn "Producer owns the definition\|owns its own shape" docs/ workflow/` returns only `documentation_policy.md` | Agent [x] |
| The roadmap row is `[x]` with the handover link | `grep -n "producer-owns-the-definition rule" devlog/roadmap.md` | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/documentation_policy.md`](../../docs/operations/documentation_policy.md) | `## Rule authority` is the rule's home |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the row this iteration closes |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The rule's home is `documentation_policy.md` `## Rule authority` | the rule refines the canonical-owner test, which that section owns; `policy_declarative_framing.md` is the ADR behind it and describes rather than binds | this handover |
| No new ADR | the 2026-09-30 framing entry in `policy_declarative_framing.md` already covers rule authority; this rule applies it to definitions and records | this handover |
| State the settled acceptance-criteria case as the example | the map's own finding is the evidence the rule was derived from, and a named example keeps the rule concrete | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|

None.

## Completed

| File | Change |
|---|---|
| `docs/operations/documentation_policy.md` | `## Rule authority` gains the producer-owns-the-definition paragraph |
| `devlog/roadmap.md` | the M3.2.1 row closed with its landing note |
