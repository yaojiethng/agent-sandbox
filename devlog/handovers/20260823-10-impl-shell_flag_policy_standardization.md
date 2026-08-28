# Agent Handover

**Date:** 2026-08-23
**Milestone:** M2.6 — Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Standardize shell option flags by writing down the de facto three-plus-one-class policy (§1.17) and aligning the few genuine stragglers. Scope emerged from operator-driven investigation: direct-exec prevention was considered and rejected (it *is* the §1.13 dispatch architecture, deliberately created in handover `20260528-05`), and audit-first inspection showed the dry-run diagnostics are compliant members of an unrecognized class, not outliers.

## Policy being codified (new §1.17)

| Context | Flags | Rationale |
|---|---|---|
| Orchestrator entry points | `set -euo pipefail` at top | fail-fast beats continuing with partial state |
| Dual-use (exec'd in production, sourced by tests) | flags inside `main()` / §1.11 guard only | a top-level set leaks into the sourcing consumer |
| Pure libraries | never set options | inherit consumer regime; correctness via §3.1/§4 idioms |
| Observe-and-report (test files, harness runners, diagnostic sweeps) | no `-e` — must run all checks and count failures; `set -uo pipefail` preferred | first-failure abort defeats reporting |

Weaker than `-uo pipefail` in the last row is permitted only with an inline rationale comment (dry-run diagnostics have one: explicit env-var guards instead of `-u`).

## Scope

| File | Change |
|---|---|
| [`docs/development/bash-coding-conventions.md`](../../docs/development/bash-coding-conventions.md) | New §1.17 policy table + rationale |
| [`tests/test_build_context.sh`](../../tests/test_build_context.sh) | `set -euo pipefail` → `set -uo pipefail` |
| [`tests/test_diff_rename.sh`](../../tests/test_diff_rename.sh) | same |
| [`tests/test_provider_entrypoint.sh`](../../tests/test_provider_entrypoint.sh) | same |
| [`tests/test_providers_pi_preflight.sh`](../../tests/test_providers_pi_preflight.sh) | same |

Explicitly **not** changed, with reasons:
- `build.sh` — dual-use flags already live inside its guard; design deliberate per handovers `20260528-05`/`20260528-06`; direct-exec prevention rejected (see Findings)
- `guards.sh`, `workflows/interactive.sh` — pure libraries; flagless is correct
- `dry_run_capability.sh`, `dry_run_reasoning.sh` — observe-and-report class with documented inline rationale
- `src/libs/**` — already conform (never set options)

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | §1.17 exists and matches enforced state | doc review | accepted |
| AC2 | Every repo shell script conforms to its class row | full-tree survey clean — one additional outlier found and fixed post-survey: `src/reasoning/agent/drafts/toc.sh` (executed command script, no source-consumers) gained `-euo pipefail`; `providers/pi/onboard.sh` reclassified as lib (sourced by `scripts/onboard.sh:288`) | accepted |
| AC3 | All 38 test files on `set -uo pipefail` | survey grep: 38 × `set -uo pipefail`, zero stragglers | accepted |
| AC4 | Suite green and deterministic ×2 | 629 tests / 38 files / 0 failed ×2 | accepted |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Direct-exec of subcommand scripts is deliberate architecture (§1.13 dispatch), created knowingly in `20260528-05`, guard-hardened in `20260528-06`; preventing it would add a wrapper file without collapsing the policy classes (testability dual-use remains regardless) | design review | Recorded here; build.sh untouched |
| The dry-run diagnostics' "intentionally no set -e/-u" comments are correct class behavior, not drift — same reasoning as the harness's `-uo` | resurvey | Added fourth policy row instead of forcing `-euo` |
| Initial outlier list overcounted: `guards.sh`/`interactive.sh` are pure libs; `build.sh` already compliant | resurvey | Scope reduced to 4 test files + doc |

## Completed

| File | Change |
|---|---|
| [`docs/development/bash-coding-conventions.md`](../../docs/development/bash-coding-conventions.md) | New §1.17: four-class flag policy table, weaker-than-`-uo` escape hatch requiring inline rationale, class-change rule |
| [`tests/test_build_context.sh`](../../tests/test_build_context.sh) | `-euo` → `-uo pipefail` (observe-and-report class) |
| [`tests/test_diff_rename.sh`](../../tests/test_diff_rename.sh) | same |
| [`tests/test_provider_entrypoint.sh`](../../tests/test_provider_entrypoint.sh) | same |
| [`tests/test_providers_pi_preflight.sh`](../../tests/test_providers_pi_preflight.sh) | same |
| [`src/reasoning/agent/drafts/toc.sh`](../../src/reasoning/agent/drafts/toc.sh) | Added `set -euo pipefail` (entry-point class; smoke-tested against a fixture) |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | Standardization recorded as complete bullet in the M2.6 refactor track |

## Decisions

| Decision | Rationale |
|---|---|
| Four policy rows, not uniform `-euo` | Libs must inherit consumer regime; observe-and-report scripts must run all checks; dual-use flags belong under the guard. Uniform application would break all three |
| Do not prevent direct exec of subcommand scripts | It is the §1.13 dispatch architecture, deliberate since `20260528-05`; prevention adds a wrapper without collapsing classes (operator reviewed and approved this reasoning) |

## Deferred items

- Error-message vs control-flow coherence trio — unblocked now that the regime is settled; next candidate iteration.
- Naming/header contradictions one-liners; empty-diff decision; savepoint decision.
