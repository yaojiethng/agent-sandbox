---
date: 2026-10-22
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - Move the git mechanism into the prompts

## Objective

Move the history mechanism out of `docs/policies/git_policy.md` into the prompts that run it, drop the landing model the system never used, and delete the file.

## Scope

`M3.3.2 - Retire the policy form`, slice `Retire git_policy`, unit 2 of 2. It continues the settled chain in [`20261014-design-settled-retire_the_policy_form.md`](../discussions/20261014-design-settled-retire_the_policy_form.md), after unit 1 (handover `20261022-09`).

The settled row sends Merge Policy to `merge`. Reading that prompt whole shows it is the replay runbook: it never runs a git merge, and three of the policy's four landing models appear nowhere in it. The operator ruled the models out: locally a branch lands by replay, the only `merge` is the remote's PR merge, and the agent has two situations, both replay. So the section is deleted rather than moved, and the skill's runbook rows name the two situations the agent meets.

The prompt `merge.md` states its case as finished sessions landing as-is; the practice it serves is recovering a corrupted or partial package export. That drift belongs to that prompt, so it is flagged rather than fixed here.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The policy file is deleted | `test ! -e docs/policies/git_policy.md` | Agent [x] |
| No live surface names it | `grep -rln 'git_policy' docs scripts src workflow .agents AGENTS.md tests` prints only the historical audit record | Agent [x] |
| `wrapup` carries checkpointing, the `wip:` rule, the three fold kinds and the stuck procedure | `grep -c` each of the four phrases | Agent [x] |
| `wrapup` B9 carries the interleaved-tree split | the three commands are present | Agent [x] |
| `record-correction` carries the port-and-stop line and the after-a-close line | `grep -c` both | Agent [x] |
| The skill's runbook rows name the two situations the agent meets | two rows carry `export` | Agent [x] |
| `bootstrap.md` no longer lists the file | 0 mentions | Agent [x] |
| The roadmap row closes and the parent reads six slices | `grep` the row and the parent line | Agent [x] |
| Lint, ledger, suite and handover gate clean | the four scripts | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The Merge Policy section is deleted, not relocated | It states how the operator and the remote land branches, and the agent has two replay situations instead. `merge` and `rebase` already state the replay rule | this record |
| Checkpointing and the `wip:` rule open Part A, and the fold kinds join A5 | Part A is the commit checkpoint, and the fold is the step that runs it | this record |
| Recovery joins B9 | B9 is where a mixed tree is prepared for the commit | this record |
| The skill's runbook rows name the two situations rather than the landing model | A reader arrives with a corrupted export or a stale one, not with a landing model | this record |
| The mechanism lands as the operation plus one clause per rule, not as the policy's prose | Rule paragraphs in `wrapup` grow the close without adding a step. A prompt states what it runs, and the convention-skill holds the rule | this record |
| The message shape names Conventional Commits as its upstream, with the project's two narrowings stated beside it | The specification decides the cases this skill leaves silent, and naming it makes that fallback reachable. Its scope field and its open type set are the two places the project diverges | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The Merge Policy's four landing models describe operations the system does not run locally: three use `merge` as the git operation, the history's only merges are remote PR merges, and the runbooks replay | defect | a reader would look for a squash-merge step that no prompt performs, and the review-gate and conflict rules restate invariants held elsewhere | the section is deleted |
| `merge.md` frames its case as finished sessions landing as-is, while the practice it serves is recovering a corrupted or partial export | gap | the prompt's mandate and its practice differ, so a session may treat a damaged export as a finished one | flagged; that prompt's premise is the operator's to restate |
| Deleting the policy left `merge.md` citing "the repo's transient-commit rules" with no target, and attributing the test-liveness gate to `lint.sh` | defect | a dangling citation and a gate the reader would not find | fixed in this unit |
| `history-cleanup` stated its four invariants twice, mixed second person into an imperative runbook, and pointed at "above" and "below" | defect | the reader re-reads a sentence they already know, and a positional pointer breaks when a section moves | fixed in this unit: a communication pass over both runbooks |
| The repo-side draft `src/reasoning/agent/drafts/recovery.skill.md` covers the re-authoring case: rebuilding lost work from a session log, one iteration per commit | gap | it is adjacent to `merge` and shares its per-iteration commit and suite discipline, but `merge` replays commits that exist and this reconstructs ones that do not. No surface references it, and the audit's "Keep" gives it no home | a roadmap row is filed in this unit |
| `git-discipline`'s runbook table named the landing model rather than the situation that opens each runbook | defect | a reader could not tell when to reach for `merge` or `rebase` | fixed in this unit |
| Moving the mechanism as prose instead of as an operation put five rule paragraphs into `wrapup`, two of them absolutes: never carry uncommitted changes or a stash across a boundary, and merge the session branch back before the session ends | defect | an over-prescribed close, and a rule that conflicts with [`/sidequest`](../../workflow/coding-agent/prompts/sidequest.md), which pauses an open iteration with its work possibly uncommitted | fixed in this unit: four clauses replace the prose |

## Completed

| File | Change |
|---|---|
| `docs/policies/git_policy.md` | deleted, its landing model dropped rather than moved |
| [`workflow/coding-agent/prompts/wrapup.md`](../../workflow/coding-agent/prompts/wrapup.md) | the checkpoint and `wip:` clauses, the fold kinds, the stuck fold, the interleaved-tree split in B9 |
| [`workflow/coding-agent/prompts/record-correction.md`](../../workflow/coding-agent/prompts/record-correction.md) | the port-and-stop line and the after-a-close line |
| [`workflow/coding-agent/prompts/merge.md`](../../workflow/coding-agent/prompts/merge.md) | the stale fold citation retargets, the gate attribution corrected |
| [`workflow/coding-agent/skills/history-cleanup/SKILL.md`](../../workflow/coding-agent/skills/history-cleanup/SKILL.md) | the duplicated invariant list, the voice mix and two positional pointers corrected |
| [`.agents/skills/decision-records/SKILL.md`](../../.agents/skills/decision-records/SKILL.md) | the duplicated status sentences merged, two sentences split one subject each |
| [`.agents/skills/work-log/SKILL.md`](../../.agents/skills/work-log/SKILL.md) | the opening sentence loses a clause the next one states |
| [`.agents/skills/git-discipline/SKILL.md`](../../.agents/skills/git-discipline/SKILL.md) | the `merge` and `rebase` rows name the situation that opens each |
| [`workflow/coding-agent/prompts/bootstrap.md`](../../workflow/coding-agent/prompts/bootstrap.md) | the policy set loses the file, two lists |
| [`docs/adr/task_type_taxonomy.md`](../../docs/adr/task_type_taxonomy.md) | two retargets, one a link that would otherwise dangle |
| [`docs/adr/closed_record_corrections.md`](../../docs/adr/closed_record_corrections.md) | one retarget, the landing rule names the convention |
| [`devlog/roadmap.md`](../roadmap.md) | the slice closed, the parent row reads six slices |
