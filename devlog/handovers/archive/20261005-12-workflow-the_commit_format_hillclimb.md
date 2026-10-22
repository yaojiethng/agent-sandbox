---
date: 2026-10-05
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - The Commit Format Hillclimb

## Objective

Raise the agent's compliance with the commit-message format, by changing only the phrasing of the project `AGENTS.md` and `docs/operations/git_policy.md`, measured by a frozen eval rather than by inspection.

## Scope

The operator's question was whether the wording in `git_policy.md`, and the pointer to it from `AGENTS.md`, actually hold an agent to the format. The previous unit answered it for a small change and found the metric saturated. This unit answers it for an iteration-scale change, and then climbs.

1. **The metric is a tuple.** Correctness is the mean fraction of the four format rules satisfied across runs. Consistency is the fraction of committed runs that satisfy all four. The climb target is the mean body length in characters, lower better. The tie-break is the total bytes of the two files under test, lower better. The rules are the type prefix, the subject at 50 characters or fewer, the body at 280 characters or fewer, and no path list in the body.
2. **The workload is iteration-scale and real.** One uncommitted change of 1,518 lines across 19 files, taken from this session's own delivery series, with the two instruction files excluded so the two variables cannot interact.
3. **The harness is frozen before the first edit.** `run_case.sh` builds one clone per run, plants the candidate files, applies the workload, fans out one child agent per run, and scores each delivery commit. `measure_commit.sh` scores one commit. Sixteen unit cases pin the measurement.
4. **The loop is the hillclimb playbook's.** Five iterations of three targeted edits each, one measurement per edit at three runs, keep only what moves the tuple, and revert the rest. Every row lands in `decision.tsv`, kept or reverted.
5. **The edits stay targeted.** Only the commit-message region of the two files changes. No unrelated section is touched.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The harness measures what the policy means | `bash tests/test_eval_harness.sh`, 16 cases | Agent [x] -- 16 passed |
| The harness separates a good instruction set from a bad one | the baseline and contrast candidates, three runs each | Agent [x] -- shipped instructions mean body 295 with 323 max; the stripped contrast never committed |
| Each iteration measures three edits at three runs and logs every row | `$HOME/workspace/output/evals/hillclimb-commit-format/decision.tsv` | Agent [x] -- iteration 1 logged, three rows |
| An accepted edit is applied to the repository and committed | `git log` | Agent [x] -- the e3 deletion, `wip:` commit |
| Five iterations run, or the predicate stops the loop | this handover's round table | Agent [x] -- five iterations, 15 edits, four kept. Iteration 5 kept nothing: all three edits lost to its control |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | the commands | Agent [x] |
| The handover closes | this handover | Operator [ ] |

---

[CORRECTION -- 2026-10-05: criterion 1 reported "16 passed" from `bash tests/test_eval_harness.sh`. The file invoked its seven test functions bare instead of through `run_test`, so none of them ran, the file produced no result, and the liveness gate failed the whole suite with seven `UNREGISTERED` findings. The 16 is the file's assertion count, not a run's result. The seven calls now go through `run_test` and all pass, and lint and the suite are clean. This correction rides this commit. Finding routed to handover `20261005-14`, whose iteration found the defect; no new roadmap row.]

---

## Hot files

| File | Why in scope |
|---|---|
| `workflow/coding-agent/skills/eval/scripts/run_case.sh` | new: fixture build, fan-out, scoring |
| `workflow/coding-agent/skills/eval/scripts/measure_commit.sh` | new: the four rules over one commit |
| `tests/test_eval_harness.sh` | new: 16 cases, including a stub-agent run of the whole harness |
| `docs/operations/git_policy.md` | the accepted deletion, and the file under test |
| `AGENTS.md` | the pointer under test, unchanged so far |
| `devlog/handovers/archive/20261005-12-workflow-the_commit_format_hillclimb.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The body length is the climb target, not the pass rate | the shipped instructions already pass the rules most of the time, so a pass rate saturates and stops carrying a gradient | this handover |
| The candidate files are excluded from the workload patch | otherwise the workload and the instruction variable interfere | `run_case.sh` |
| One new commit is a separate axis from committed at all | a run that splits the delivery violates the one-commit rule, and the first measurement conflated the two | `measure_commit.sh` |
| One project iteration holds the whole hillclimb, with `wip:` checkpoints | five iterations of the loop would otherwise need five handovers, and the delivery commit is one | `docs/operations/git_policy.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Batch-to-batch noise on identical text is larger than most single-iteration wins. The same policy text measured a 235, 274 and 153 character mean body across three batches. Only a paired control inside a batch is a usable comparison, so the cumulative result rests on four separate single-batch results. | evidence, measured | open | Triaged to: the decision log, and the next hillclimb, which needs more runs per candidate before it can claim a cumulative figure |
| Four of the five `wip:` commit bodies written during the hillclimb ran over the 280 character budget, the worst at 287. The agent writing them had the rule in its context. The delivery commit was measured before it was accepted. | evidence, caught at review | open | Triaged to: the case set, which now holds six overruns from this session |
| Three candidate builders aborted because an anchor had drifted, and the guards failed closed, so no child runs were spent. One dispatch spent four empty invocations before a brief-size check existed. | process | current iteration | Triaged to: the harness, whose scripts verify each anchor's match count and each brief's size before dispatch |
| Deleting two exhortation sentences next to the budget cut the mean body from 295 to 235 characters and took correctness and consistency to 1.0, while also leaving the shortest file of the three candidates. The prompt to write a narrative was the cause, not the missing budget rule. | evidence, measured | current iteration | Triaged to: applied to `docs/operations/git_policy.md` |
| The first harness build copied the candidate files after applying the workload patch, so the patch that touched `git_policy.md` was overwritten and every run measured an empty fixture. The unit test caught it. | defect, caught by the test | current iteration | Triaged to: `run_case.sh`, which now plants the candidate first and keeps the two files out of the workload |
| `jq` reads `label:` as a keyword, so the summary never emitted. Renaming the key fixed it. | defect, loud | current iteration | Triaged to: `run_case.sh` |
| An apostrophe inside `${VAR:-default}` is a syntax error, and `bash -n` reports it at the file's end. | defect, found by hand | current iteration | Triaged to: `devlog/AGENT_FEEDBACK.md` |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/eval/scripts/run_case.sh` | new: clone per run, candidate planting, workload patch, fan-out, scoring, and a re-score mode that needs no new runs |
| `workflow/coding-agent/skills/eval/scripts/measure_commit.sh` | new: the four rules, the commit count, and the clean-tree check |
| `tests/test_eval_harness.sh` | new: 16 cases over the rules and one end-to-end stub run |
| `docs/operations/git_policy.md` | the accepted deletion of the two exhorter sentences, 158 bytes shorter |
| `devlog/AGENT_FEEDBACK.md` | the Bash entry on the apostrophe trap |
| run artefacts, outside the tree | `$HOME/workspace/output/evals/hillclimb-commit-format/`: seven batches, 57 runs, `decision.tsv`, the workload patch, and the candidate directories |
| five iterations, 15 edits, four kept | iteration 1 kept e3, deleting the two sentences that invited a narrative body. Iteration 2 kept e4, deleting the handover-repeat sentence. Iteration 3 kept e7, naming the one-sentence shape. Iteration 4 kept e10, tightening the budget paragraph on the file-length tie-break. Iteration 5 kept nothing. Eleven edits reverted |
| `docs/operations/git_policy.md` | the four accepted edits, leaving the file set 403 bytes shorter than the baseline |
