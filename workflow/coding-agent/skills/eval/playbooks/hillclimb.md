# Hillclimb evals

**You own the metric and the experiment's integrity. Supervise and review. Delegate the attempts.** For sustained improvement of one measurable behaviour by changing an instruction set, one hypothesis at a time, when the metric is what an agent actually does. The plain loop is the hillclimb playbook, the plain case is the eval skill, and this is the two together.

Sources. The [hillclimb playbook](https://github.com/cursor/plugins/blob/main/pstack/skills/poteto-mode/playbooks/hillclimb.md) owns the loop, the log and the stop predicate. The [eval playbook](https://github.com/cursor/plugins/blob/main/pstack/skills/poteto-mode/playbooks/eval.md) owns blinding. The [agentskills guide](https://github.com/agentskills/agentskills/blob/main/docs/skill-creation/evaluating-skills.mdx) owns the case shape.

Core discipline: one change, one measurement, keep or revert. Never stack untested edits, and never claim a win from reading the wording (the **prove-it-works** principle skill).

1. **Ground the workload before choosing the metric.** Name the dimensions that can move the result: the scale of the change under test, how the task is framed, and the number of runs. Reproduce the complaint on the hardest realistic case. If no case reproduces it, fix the case instead of climbing, because a metric that never fails has no gradient.

2. **Fix the score tuple, in order.** Correctness first, then consistency, then the climb target, then a tie-break. Correctness is the mean fraction of the stated rules satisfied across runs. Consistency is the fraction of runs that satisfy all of them. The climb target is the quantity the operator wants to move, lower or higher. The tie-break, applied only when the earlier axes are equal, is size: prefer the smaller instruction set. State every rule so grading is mechanical, and where judgement is unavoidable have one blind grader score every candidate in a single pass.

3. **Build the harness, prove its sensitivity, then freeze it** (the **build-the-lever** principle skill). The harness builds one fixture per candidate per run, plants the candidate's files, applies a workload patch that excludes those files so the two variables cannot interact, fans out one child agent per run, and scores each result. Pin the measurement with unit cases, including one end-to-end run against a stub agent. Prove sensitivity with a contrast that must lose. Freeze the harness: a measurement change restarts the baseline and every result measured before it.

4. **Open the decision log before the first edit.** A `decision.tsv` outside the tree, one row per attempt: id, hypothesis, change, before, after, delta, tests, verdict, note. Read it before each attempt. Keep it out of the tree.

5. **One batch per iteration, and the paired control is not optional.** Each batch carries the previous state re-measured as a control, plus the iteration's edits, all at the same run count, all measured in one pass. Batch-to-batch drift on identical text has exceeded the size of most single-edit wins, so a candidate compared against an earlier batch proves nothing.

6. **Accept only what moves the tuple inside its batch, past the noise band.** Otherwise revert the edit in full. A change that might help is not kept. Stage only the files under test, and one commit per accepted edit.

7. **Every accepted edit so far has been a deletion or a named shape.** Say what the output is, in the document, rather than tightening a limit, and delete the prose that invites the wrong shape. An edit that only adds instruction has lost more often than it has won.

8. **Stop at the predicate, and don't relax it to meet it.** When the edits stop moving the tuple, change category rather than repeating the same mechanism. Surface a stall instead of spinning.

9. **Close cleanly.** Squash the iteration's checkpoints into the delivery commit, and record the round table in the handover. Say which numbers are paired and which are not, because a cross-batch figure is a story rather than a measurement.

**Harness requirements.** Fixtures start from a snapshot bundle or a trimmed copy of the working tree, outside the repository. Each configuration gets its own config directory, so the candidate differs by one entry. Children run at the model the operator names, each with its own session file and its own log. The measurement reads the artefact, never the child's own report.

**Reply:** the metric and target, the baseline to final with the percent delta, which figures are paired and which are not, the iterations run with kept and reverted counts, each accepted edit on one line, the `decision.tsv` path, the measured cost in runs and tokens, and the best idea you would try next.
