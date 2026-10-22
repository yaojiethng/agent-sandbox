---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - The convention pointer becomes one sentence

## Objective

Replace the 239-character paragraph that every record-reading step carried with one sentence, and put the check in place that keeps the wording from diverging again.

## Scope

The 21 `## Project conventions` sections under `workflow/`, and one test beside them. The decision came from the redundancy investigation of 2026-10-20: the clause was the corpus's largest multi-carrier sentence, at 19 carriers before this change.

Ruled out of scope with a reason each. Deleting the links entirely was rejected: the coverage test measured the three unread convention skills at 4%, 24% and 5% contained in what those sessions already received, so their links point at unique content and earn no deletion. Moving the fallback into `initialize` was rejected because that skill's reader is the operator at setup, while the fallback's reader is the agent mid-step. An outcome comparison between sessions that read a convention and sessions that did not was rejected as unmeasurable at this traffic.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every section carries one sentence | `bash tests/test_convention_pointer.sh` | accepted, 4 tests pass |
| No carrier keeps the old paragraph | `grep -rn 'prescribes no fallback' workflow/` returns nothing | accepted |
| The tree is green | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | accepted, 10 gates clean, 1254 tests pass |
| The wording matches the operator's instruction | the sentence reads "raise it to the operator" | accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| One sentence, path plus escalation | the path is needed at every step, the escalation rarely, and both are short enough to keep together | this handover |
| Escalate rather than continue degraded | continuing without a convention hides the failure that `057d33e7` recorded | this handover |
| Apply to all 21 sections, `iter`, `gm` and `wrapup` included | all nine conventions exist here, so the missing branch never fires in this repository, which makes the edit inert in-repo | this handover |
| Keep the check as a test, not a lint rule | the rule is about prompt shape, and the suite already runs tests; a markdownlint rule would scan prose it cannot parse | `tests/test_convention_pointer.sh` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Whether retrieval repair gets an iteration | the corpus's poor retrieval in most workflows | repair one workflow with a deferred check, or wait for traffic |
| Whether the remaining 17 carriers get the same treatment for their convention lists | the bullet lists still differ per file | converge them, or leave each list to its step |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The clause changed twice in five months, touching 22 files and then 68 | measurement | the maintenance cost the operator described, measured rather than estimated | this handover |

## Completed

| File | Change |
|---|---|
| 21 files under `workflow/coding-agent/prompts/` and `workflow/coding-agent/skills/` | the 239-character paragraph replaced by the one-sentence pointer, 5,160 characters removed and 2,793 added, a net 2,367 removed |
| `tests/test_convention_pointer.sh` | new test: every `## Project conventions` section carries the sentence, with a fixture case for the offender path |
