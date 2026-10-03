# 20260927-11 - Plan: T1 Process-improvements row disposition

**Type:** Plan
**Milestone:** M3
**Status:** Closed

## Scope

Retire the T1 row `Process improvements (deferred from M2.7)`: the operator ruled all three sub-items stale -- fast-track's `/iter` form is M3.2.1's gate collapse and its non-iter form is `/auto`; decision recording rigor landed in the handover Decisions-table rule and the ADR policy; stale-skill-reference cleanup routes to chore commits by the git policy and is owned by M3.2.2's consolidation core.

## Files

| File | Change | Status |
|---|---|---|
| `devlog/roadmap.md` | close the row `[x]` with the piecemeal landing note; no replacement row (the row names no dangling artifacts) | done |
| `devlog/handovers/archive/20260927-11-plan-process_improvements_row_disposition.md` | this record, rides the commit | done |

## Assessment (recorded)

| Row | Verdict | Evidence |
|---|---|---|
| Decision recording rigor | covered | `handover_policy.md` Decisions table ("written immediately when something changes the plan"); `docs/adr/` populated under the ADR policy; the original complaint (`20260528-10`: rationale captured at close, not inline) is what the rule fixes |
| Stale-skill-reference cleanup | covered | `git_policy.md` routes stale-link fixes to `chore`; M3.2.2 owns the skill-file surface |
| Fast-track criteria | stale | gate overhead for mechanical sessions is owned by M3.2.1's gate-collapse and AC-machinery rows; operator-initiated fast-tracking is covered by `/auto`, which runs headless without the confirmation gates |

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | The row is `[x]` and its note names each sub-item's disposition and owner | read the row | Agent [x] accepted |
| AC2 | Lint clean, suite green | `lint.sh`, `run_tests.sh` | Agent [x] accepted: lint clean across 3 gates, 1001 passed, 0 failed |

## Findings

None.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Close as covered, no replacement row | the row names no artifacts, so nothing dangles | `roadmap.md`, T1 |

## What's Next

The check-in sweep over the remaining T1 rows continues; next verdicts land the same way.
