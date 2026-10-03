# Agent Handover

**Date:** 2026-09-27
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Type:** Implementation
**Status:** Closed

## Objective

Bring the two parallel-track branches back onto the session branch as the three units the operator approved, with the roadmap write-backs that follow from each landing.

## Scope

The consolidation of the work held on `exp/track-a` and `exp/track-b`, ported as three units, one commit each. The unit boundaries were set by the operator after reviewing the commit sizes and the entanglement between the track's last commit and its first two:

| Unit | Work | Type | Files owned |
|---|---|---|---|
| U1 | The tolerant parse mode removed, prune strict, the ADR brought into agreement, the strict-parse tests rewritten | `fix` | `src/libs/cli.sh`, `scripts/prune.sh`, `docs/adr/command_flag_parsing.md`, `tests/test_cli_lib.sh`, `tests/test_prune.sh` |
| U2 | The host requirement matrix, the install probe and the macOS bootstrap brought into agreement on `readlink -f`, `find -printf` and `rsync` | `fix` | `docs/development/host_requirements.md`, `scripts/install.sh`, `scripts/macos_bootstrap.sh`, `tests/test_install.sh`, `tests/test_macos_bootstrap.sh` |
| U3 | The commit-body and reference rules, and the design-document rule | `docs` | `docs/operations/git_policy.md`, `docs/operations/documentation_policy.md` |

U1 takes the first half of the track's last commit (the duplicate test name and the ADR date) and U2 takes the second half (the findutils `PATH` prefix and the matrix columns), because that commit repaired both units. U3 is the whole of the second track, two commits squashed into one.

Write-backs ride each unit's landing: two roadmap rows close, one row is annotated with a completed clause, and the design record's follow-up table records the consolidation.

## Carried forward

| Item | From handover |
|---|---|
| Consolidate and merge `exp/track-a` and `exp/track-b` into the main branch | `20260927-04-workflow-parallel_auto_experiment` |
| Vary the model across tracks to compare yield per unit | `20260927-04-workflow-parallel_auto_experiment` |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | U1 lands as one commit owning its five files and nothing else | `git show --stat` on the commit | Agent [x] accepted: `a5a274e`, 5 files |
| AC2 | U2 lands as one commit owning its five files and nothing else | `git show --stat` | Agent [x] accepted: `89a582b`, 5 files |
| AC3 | U3 lands as one commit owning its two files | `git show --stat` | Agent [x] accepted: `e775af2`, 2 files |
| AC4 | The suite is green after all three units, at the count the units imply | `bash scripts/run_tests.sh` | Agent [x] accepted: 1001 units, 0 failed, against 998 |
| AC5 | Negative check: no track commit is cherry-picked verbatim. The four track commits are consumed, not replayed, so the session branch holds three commits for the same work | `git log --oneline` and the track branch tips | Agent [x] accepted: three new hashes; all eleven files byte-identical to the track tips |
| AC6 | The `_CLI_TOLERANT` negative check passes outside the records: no hit in `src/`, `scripts/` or `tests/` | `grep -rn` | Agent [x] accepted: the only hit is the ADR's rejected-alternative sentence |
| AC7 | Two roadmap rows close and one is annotated; no row is closed on partial scope | read the three rows | Agent [x] accepted: host requirements, git-policy rewrite and design-doc amendment closed; the CLI-to-leaf row annotated as one landed clause |
| AC8 | The design record's follow-up table records the consolidation as landed | read the table | Agent [x] accepted |
| AC9 | The worktrees and the two track branches are pruned, since every commit they held is now on the session branch | `git worktree list` and `git branch --list` | Agent [x] accepted |
| AC10 | Lint gate clean, 0 findings | `bash scripts/lint.sh` | Agent [x] accepted |
| AC11 | Handover committed with the delivery commits, Status Closed | `git log` | Agent [x] accepted |

## Hot files

| File | Why in scope |
|---|---|
| `src/libs/cli.sh`, `scripts/prune.sh` | U1 |
| `docs/adr/command_flag_parsing.md` | U1 |
| `tests/test_cli_lib.sh`, `tests/test_prune.sh` | U1 |
| `docs/development/host_requirements.md`, `scripts/install.sh`, `scripts/macos_bootstrap.sh` | U2 |
| `tests/test_install.sh`, `tests/test_macos_bootstrap.sh` | U2 |
| `docs/operations/git_policy.md`, `docs/operations/documentation_policy.md` | U3 |
| `devlog/roadmap.md` | write-backs |
| `devlog/discussions/20260927-design-draft-parallel_auto_experiment.md` | write-back |
| `devlog/handovers/20260927-06-impl-consolidate_parallel_track_branches.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Apply the track commits without committing, then land one commit per unit | the track's commits are repair-layered over two units; replaying them would put four typed commits and two orphaned repairs on the branch, which is the missing-record signal the commit discipline calls out | this handover |
| U1 and U2 are landed as `fix`, U3 as `docs` | the type follows the diff, not the handover | [`git_policy.md`](../docs/operations/git_policy.md) |
| Prune the worktrees only after all three units are on the branch and the suite is green | operator direction | this handover, AC9 |
| The experiment's missing arm is filed as a roadmap row rather than added to the closed trial handover | the corrections procedure allows a closed handover to be edited only for a factual error, and routes a new task to the roadmap | this handover, Findings |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| The trial tested the workflow but not the unit split: every unit was defined by the primary, so no subagent was ever asked to propose one, and the trial is silent on whether a subagent can | gap in the experiment | the scope-to-unit row's central question stays open, and the apparent finding that a subagent cannot split work is unsupported | routed to `roadmap.md` as a named row (trial the missing arm: a subagent proposes the work-unit split) |
| Every unit landed byte-identical to the track tips, and the count matched the trial's prediction, so the port lost nothing | verification | none; recorded as the evidence that the three-unit split was lossless | this handover, AC4 and AC5 |

## Completed

| File | Change |
|---|---|
| `src/libs/cli.sh` | U1: the `drop` parse mode and the `_CLI_TOLERANT` read removed |
| `scripts/prune.sh` | U1: parses strictly |
| `docs/adr/command_flag_parsing.md` | U1: the decision, the consequence and the rejected-alternative record amended |
| `tests/test_cli_lib.sh`, `tests/test_prune.sh` | U1: strict-mode coverage replaces the tolerant-mode tests; prune rejects an unknown flag |
| `docs/development/host_requirements.md` | U2: `readlink -f`, GNU findutils and rsync declared; the `PATH` and `brew install` guidance corrected |
| `scripts/install.sh` | U2: two new probes, and the coreutils probe tightened to what the code requires |
| `scripts/macos_bootstrap.sh` | U2: findutils and rsync installed, verified, and the findutils prefix put on `PATH` |
| `tests/test_install.sh`, `tests/test_macos_bootstrap.sh` | U2: probe coverage in isolation, the fixture rebuilt, a `PATH` assertion added |
| `docs/operations/git_policy.md` | U3: the body and reference rules |
| `docs/operations/documentation_policy.md` | U3: the design-document rule |
| `devlog/roadmap.md` | three rows closed, one annotated with its landed clause, one row filed for the trial's missing arm |
| `devlog/discussions/20260927-design-draft-parallel_auto_experiment.md` | the consolidation recorded as landed, and the limits section corrected |
| `devlog/handovers/20260927-06-impl-consolidate_parallel_track_branches.md` | this handover |

## Deferred items

| Item | Why deferred | Where it goes |
|---|---|---|
| Ask subagents to propose a work-unit split, and test the proposal against the independence and one-verification properties | operator direction: the priority is writing the changes and findings back, not a new split | the roadmap row filed from Findings |
| Vary the model across tracks to compare yield per unit | not this iteration's work | `20260927-04-workflow-parallel_auto_experiment` |

## What's Next

M3. Three units landed, four roadmap rows written back, the track branches retired.
