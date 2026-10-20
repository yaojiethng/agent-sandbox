---
date: 2026-10-04
milestone: M3 - Manual Dispatch, Autonomous Execution, Manual Review
type: Plan
status: Closed
---

# Handover - Plan: consolidate the T12 rows and close the compatibility study

## Objective

Collapse the T12 pi-bump rows into the shape the operator asked for, and remove the two record defects the collapse exposed: the compatibility study left open past its decision, and `roadmap_policy.md` silent on how a completed task's sub-items and follow-ons are recorded.

## Scope

| In | Out |
|---|---|
| The T12 row set: one closed bump row, one `model-refresh` parent, one `pi upstream` parent, two standalone rows | The work the rows name; no extension, no checker, no skill behavior change |
| The capacity-signal row's move back to T7 | The signal itself |
| `roadmap_policy.md` compaction step 1 and the new `Sub-items and follow-ons` filing rule | The milestone-level compaction cascade |
| Removal of `20261002-study-pi_bump_extension_compatibility.md` and its `[REMOVED]` markers | The two reports against pi, which stay |
| `pi-bump` `SKILL.md` line 26 | The skill's assumption-walk steps |
| `workflow/coding-agent/prompts/plan.md` Close section | Every other prompt step |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | T12 holds six rows: the closed bump summary, `model-refresh` improvements, `pi upstream`, the checker gate, and `task-queue`'s bump-semantics record | `devlog/roadmap.md` | Accepted |
| 2 | The capacity-signal row sits under T7 | grep the row title | Accepted |
| 3 | No open row remains for the compatibility study, the fourth `opencode-go` round, or the default-model report not being closed upstream | grep each title | Accepted |
| 4 | Every link to the removed study carries `[REMOVED]`, and closed handover `20261002-09` carries a `[CORRECTION]` tag | `grep -rn pi_bump_extension_compatibility` | Accepted |
| 5 | `roadmap_policy.md` names the sub-item test from compaction step 1, and the new rule is reachable from that anchor | `devlog/roadmap.md`, `docs/operations/roadmap_policy.md` | Accepted |
| 6 | Gates clean | `bash scripts/lint.sh` | Accepted |

## Hot files

`devlog/roadmap.md`, `docs/operations/roadmap_policy.md`, `src/reasoning/agent/skills/pi-bump/SKILL.md`, and the two closed handovers carrying study links.

## Decisions

1. **The bump row compacts to one `- [x]` summary, not a parent with sub-rows.** U1 through U3 are units of one workflow's ordered execution, which the new `Sub-items and follow-ons` rule folds into the parent text. They have no separate outcome, acceptance, or independent close.
2. **The three open `model-refresh` rows nest under one `model-refresh improvements` parent.** Each child is work in its own right, so each keeps a row; the parent carries no work and reads as a group. It stays `- [ ]` until every child closes.
3. **`pi upstream` is a plain grouping row with one child.** A heading cannot carry a marker, and the child needs one.
4. **The default-model row absorbs the "not closed by 0.99.2 or 1.0.0" finding.** One subject, one row: the report, the mitigation, and the proof that no release fixes it.
5. **The compatibility study is removed, not settled.** The operator took the decision at operator level against `discussion_policy.md`'s rule that the agent does not delete a study. Its measurements survive in handovers `20261002-09` and `20261003-15`, and its one durable rule is already in `pi-bump` `SKILL.md`, which every bump reads.
6. **`pi-bump` `SKILL.md` line 26 is dropped.** It forbade editing `roadmap_future.md` over a note that has carried no version literal since handover `20260912-01`.
7. **The removal raises no roadmap row.** `roadmap_policy.md` **Single-edit record defects**: one edit fixes it, so the T1 row the 1.0.0 close raised is deleted with it.
8. **The fourth `opencode-go` round is dropped as answered.** The operator's answer is no; the module is not worth another round, so no row carries the question.

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| `roadmap_policy.md` prescribed nesting to the milestone level and said nothing at the task-row level, so both a four-row one-bump history and an open child under a completed parent passed review | policy | fixed by two policy sections |
| The `pi-bump` skill had accumulated a prohibition over a record condition that stopped holding in 2026-09 | skill | fixed by removal |
| Three T12 rows named one subject each rather than one row per subject | record | fixed by this collapse |
| The capacity-signal row rode a completed row, so it had no trackable home | record | moved to T7 |
| `/plan`'s Close section read `Land the plan single commit per git_policy.md`, a dropped word that reads as though a plan session skips its commit | prompt | fixed in this commit; no roadmap row, per **Single-edit record defects** |

## Completed

T12 rewritten to six rows; the T1 study-close row deleted; the capacity-signal row moved to T7; `roadmap_policy.md` compaction step 1 refined and the `Sub-items and follow-ons` rule added; `pi-bump` `SKILL.md` line 26 removed; the compatibility study deleted with `[REMOVED]` markers on its three links, a `[CORRECTION]` tag on closed handover `20261002-09`, and its 1.0.0 finding updated to record the removal as its outcome; `/plan`'s Close sentence corrected to name the single plan commit.
