# Agent Handover

**Date:** 2026-09-24
**Milestone:** M3 -- T8 Documentation (record hygiene); M3.1 Backpressure (shellcheck-directive trap)
**Type:** Housekeeping
**Status:** Closed

## Objective

Fix the five record discrepancies the 2026-09-24 check-in surfaced, and add a shellcheck-directive lint rule with its doc warning.

## Scope

This iteration targets the record-hygiene discrepancies found in the check-in and the shellcheck-directive trap fix agreed in chat.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `gm.md` states the only permitted check-in change is a cosmetic record-bug fix, aggregated into a single `chore:` commit with no handover; the Survey reconcile line is present | `grep` on `gm.md` | Agent [x] |
| 2 | The `harness_iterative_improvement_loop` ADR is dated 2026-09-21 with no `2026-09-25` remaining | `grep "2026-09-25"` returns nothing | Agent [x] |
| 3 | `[O] 2026-08-12` feedback entry is `state: probation` | `grep` the entry state line | Agent [x] |
| 4 | The roadmap T1 Unify row carries no forward-looking "merge lands next iteration" text | `grep` returns nothing | Agent [x] |
| 5 | Handover 14's finding records the pointer fix as landed via a `[CORRECTION]` tag | read handover 14 | Operator |
| 6 | `check_shell.sh` reports a prose comment whose first token is `shellcheck` unless it is a real `disable=`/`enable=`/`source=` directive; valid directives pass | tests in `test_lint_umbrella.sh` | Agent [x] |
| 7 | `bash-coding-conventions.md` gains the directive-parse warning | `grep "parsed as a directive"` | Agent [x] |
| 8 | `[A] 2026-09-19` shellcheck-directive entry is `state: probation` | `grep` the entry state line | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`workflow/coding-agent/prompts/gm.md`](workflow/coding-agent/prompts/gm.md) | relax the no-change rule: aggregate a run's cosmetic fixes into one chore commit |
| [`docs/adr/harness_iterative_improvement_loop.md`](docs/adr/harness_iterative_improvement_loop.md) | re-date the forward-dated unified-record entry to 2026-09-21 |
| [`devlog/AGENT_FEEDBACK.md`](devlog/AGENT_FEEDBACK.md) | `[O] 2026-08-12` and `[A] 2026-09-19` entries: open to probation |
| [`devlog/roadmap.md`](devlog/roadmap.md) | T1 Unify row: remove forward-looking text |
| [`devlog/handovers/20260922-14-chore-roadmap_architecture_rows.md`](devlog/handovers/20260922-14-chore-roadmap_architecture_rows.md) | correct the stale host_requirements finding |
| [`scripts/check_shell.sh`](scripts/check_shell.sh) | add the shellcheck-directive prose-comment lint rule |
| [`docs/development/bash-coding-conventions.md`](docs/development/bash-coding-conventions.md) | add rule 4.6, the directive-parse warning |
| [`tests/test_lint_umbrella.sh`](tests/test_lint_umbrella.sh) | cover the new rule |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The shellcheck-directive trap gains a lint rule, not only the doc warning | a comment whose first token is the tool name parses as a directive; a mechanical gate beats a doc-only warning | this handover |
| The lint rule is a grep pass in `check_shell.sh`, not a markdownlint mjs rule | the trap is a shell comment, not Markdown; one gate, no `lint.sh` change | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The operator directs a `chore:`-typed commit with no handover for the record-hygiene fixes, aggregating a single run's cosmetic fixes into one commit | steering | current iteration |

## Completed

No file changes this iteration.

## Deferred items

None.

## What's Next

M3 -- T8 Documentation / M3.1 Backpressure follow-up.

**Conclusions from this iteration:** a single `/gm` run aggregates all its cosmetic fixes into one `chore:` commit; the shellcheck-directive trap is caught by the existing gate's directive-parse failure but with shellcheck's own wording, so a grep rule reports the prose form directly.
