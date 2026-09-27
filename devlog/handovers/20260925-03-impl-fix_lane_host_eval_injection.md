# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Close the draft-state record's `eval` injection: a record field carrying a command substitution or backtick executes when the record is read.

## Scope

Fix lane F2 of the read-through close, rows 38 and 242 - the same defect recorded from the emitter side and the consumer side.

## Carried forward

| Item | From handover |
|---|---|
| The host-eval security defect row of the immediate fix lane | roadmap M3.1 (`Read-through close: operator review, then a findings-to-tasks plan session`) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| A record field carrying a command substitution or a backtick does not execute on the read path | `tests/test_draft_state.sh` adversarial units | Agent [x] |
| The record's on-disk shape is unchanged, so no other consumer, fixture or document changes | the same units plus `git diff` scope | Agent [x] |
| Lint clean and suite green | both runs | Agent [x] (756 units at this unit's close) |

## Hot files

| File | Why in scope |
|---|---|
| [`src/libs/draft_state.sh`](../../src/libs/draft_state.sh) | the emitter and reader that build the `eval` input |
| [`tests/test_draft_state.sh`](../../tests/test_draft_state.sh) | the adversarial units |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Escape at the eval boundary with `%q` and an identifier-shape guard, not by changing the record shape | every consumer of the record lives inside this unit's owned files, but the smaller change leaves the on-disk format, the fixtures and the docs untouched | the register's rows 38 and 242 |
| Keep the KV-family redesign out of this unit | the family's single-reader shape is row 22, a design item | roadmap row 83 |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Every consumer of `draft_read_state_from_branch`, `draft_validate_branch` and the `.draft-state` record is inside the owned set, so the shape could have changed; the escaped-value fix was chosen anyway for its smaller blast radius. | steering | current iteration |
| A hostile left-hand field name is the same class as a hostile value; the identifier-shape guard covers it. | bug | current iteration |

## Completed

| File | Change |
|---|---|
| `src/libs/draft_state.sh` | both readers emit `printf '%s=%q\n'`; the obsolete empty-key guard replaced by an identifier-shape guard |
| `tests/test_draft_state.sh` | two adversarial units driven by a poisoned record fixture; both failed before the fix and pass after |

## Deferred items

None. The KV-family record design is roadmap row 83.

## What's Next

The next fix lane: dead code and local logic defects.

**Conclusions from this iteration:** escaping at the read boundary is sufficient to remove the injection without touching any consumer, so the record format stays stable.
