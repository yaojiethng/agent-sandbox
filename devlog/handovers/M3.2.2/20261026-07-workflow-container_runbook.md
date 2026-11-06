---
date: 2026-10-26
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - The container runbook, from kelsey's container half

## Objective

Take the ten container rules that `kelsey-code-reviewer.skill.md` states and no other file owns, decide which of them this repository holds, and land them as a container runbook beside `code-review-bash`. The carrier then goes, and the consolidation row loses its second third.

The pass runs as the operator-directed cleanup does: the goal-only prompt drives a two-seat census over the one carrier, the results are merged into a site ledger with the rulings left empty, and the operator rules the rows before any edit lands.

## Scope

In scope:

1. a two-seat census of `.agents/audits/kelsey-code-reviewer.skill.md`: seat 1 `deepseek/deepseek-flash`, seat 2 `openrouter/z-ai/glm-5.3-flash`, both on the goal-only prompt at thinking level `high`, both returning faults only.
2. the merged site ledger: one row per distinct site, the seat that raised it, the category, and the proposed destination with its reason. `Ruling` empty on every row.
3. on the operator's ruling, the container runbook, and the deletion of the carrier with its pointers repointed.

Out of scope: the bash half, which `code-review-bash` already owns; the other five carriers; and any change to the goal-only prompt or to the landed cleanup pass while the census is in flight.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Seat 1 reproduces the recorded B list for this carrier | the census record's `Arm B -- 14 faults` against seat 1's log, site by site | Agent [n/a] -- the carrier moved two lines after the census, so no site match is possible below `:90`. The comparison is a delta of judgements instead, and the reason is recorded in the census record |
| Seat 2 runs on the pinned assignment, not a fallback | `grep -o '"model":"[^"]*"' <session>` prints `openrouter/z-ai/glm-5.3-flash` once | Agent [n/a] -- the route answered `401 API key expired`, and the operator ruled the second seat unnecessary once seat 1 came back with no fault inside the container block |
| Neither seat is an empty turn | each log is non-empty and ends with a fault list | Agent [x] -- the one seat that ran logged 17 entries |
| Every site in the ledger names the seat or seats that raised it | the ledger, no empty `Seat` column | Agent [n/a] -- there is one seat, and its list is recorded verbatim rather than merged |
| Every row carries a proposal and a reason, and no row is ruled | the ledger, `Ruling` empty throughout | Agent [x] -- the census record carries the seat's own recommendations, unreworded and unruled |
| The tree is untouched by the census | `git status --porcelain` shows only records | Agent [ ] |
| The container rules that no file owns are each an entry or explicitly discarded with a reason | the runbook, one entry per rule, against the nine bullets the carrier states | Agent [x] -- nine entries, `p-49` to `p-57`, one per bullet, in `code-review-container/patterns/dockerfile.md` |
| `kelsey` is deleted only after every rule it states is an entry somewhere | a grep across the runbook and the pattern set for each of the nine container rules and the shell rules | Agent [n/a] -- not deleted. The shell and container halves are owned; the feedback-style block is not, and it is the subject of the next ruling |
| The gate is clean and the suite passes | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] -- the gate is clean across 13; the suite passes 1321 |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The census covers one carrier, not six | the operator scoped this iteration to the container rules, which live in one file. The other carriers' censuses already exist in `20261026-report-settled-census_six_carriers.md` | this handover |
| Seat 1 is the reproduction control | B over this carrier already ran and its 14 faults are on record, so a matching seat 1 establishes that the pinned-model invocation yields what the ablation harness yielded. That is cheaper than the `bash-audit` control and it tests the same thing | this handover |
| The second seat is a different model family, not a second prompt | the census shows the two prompts are equally good halves, so the remaining error is model variance. A second family is the axis with unexhausted information | this handover |
| Seat 1 settles the container block, so the run stops at one seat | the operator's ruling. Seat 1 raised nothing inside `## Review Standards -- Dockerfile`, and a second family re-reads the same nine bullets, so the second reading would have added cross-family agreement where there is nothing to agree about | this handover |
| The nine container rules become entries rather than a runbook body | a finding has to cite an entry, and an entry carries the wrong form beside the right one. A rule in a runbook body would make a container finding an observation, which is the state `bash-audit` was in before it was screened | `code-review-container/SKILL.md` |
| The container set gets its own `patterns/` rather than a shared directory | the template places an entry beside the runbook that cites it. A shared directory above both runbooks would be the cleaner home, and it is a migration of the bash set that this iteration did not open | `code-review-container/patterns/README.md` |

## Decisions pending

| Code | Item | State | Ruling |
|---|---|---|---|
| K1 | Which of the ten container rules survive into the runbook, and which are doctrine with no subject in this repository | Ruled | All nine survive, restated against the tree where the carrier's wording contradicted it: the uid is a build argument rather than a fixed literal, and a digest is stated as the condition a rebuild needs, because no build file here pins one |
| K2 | Who owns `kelsey`'s feedback-style block, which no runbook holds: `Direct`, `Prioritised`, `Concrete`, the output sections, and the nohedging rule | Open | The block is review-output discipline rather than a bash or a container form. Either the `code-review` shell states it for every runbook, or `prose-review` does, and the carrier is deleted after that |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| B over `kelsey` has already run, at 14 faults over 13 distinct sites | finding | the iteration's first seat is a control with a known answer rather than new work, which makes a mismatch informative instead of invisible | the census record, `Arm B` under `kelsey` |
| The carrier moved between the census and this run, so the reproduction control is void | finding | `kelsey` is 160 lines against the 158 the eval fixture froze. The absorb step rewrote the bash block to cite entry ids, so every recorded line number from :90 down names different text. Seat 1 cannot be matched to the recorded list by site, and the comparison is a delta of judgements | this handover |
| Seat 2 could not run: `openrouter` answered `401 API key expired` | defect | the second family has no reading, so the ledger has one seat and no cross-family agreement. Nothing is merged and no model was substituted | this handover |
| Seat 1 raised nothing against the nine Dockerfile bullets | finding | the container rules are unopposed by a fault census. Their fate is a ruling about which of them the repository holds, which is the operator step this iteration was built around | the container-rules census record |

## Completed

| File | Change |
|---|---|
| `code-review-container/SKILL.md` | the container runbook, five slots, naming `p-49` and `p-53` in its Focus and a float, a surviving privilege and a missing `USER` as the three `HOLD` conditions |
| `code-review-container/patterns/dockerfile.md` | nine entries, `p-49` to `p-57`, one per container rule the carrier states, each with a fence taken from a build file in this tree |
| `code-review-container/patterns/README.md` | the id rule by pointer rather than by copy, the search that finds an id, and what `hadolint 2.14.0` already settles |
| `workflow/coding-agent/skills/code-review/SKILL.md` | the Runbooks table gains the container row; the not-yet-accepted table loses the `bash-audit` row and states what of `kelsey` is still unowned |
| `20261026-report-draft-container_rules_census.md` | the one seat's fault list, verbatim and unruled, with the blocked second seat and the void control recorded above it |
