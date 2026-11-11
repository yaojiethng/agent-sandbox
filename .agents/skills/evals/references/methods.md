# The methods

A method makes a difference interpretable. Each one closes a named validity threat and leaves another open, so the design states both. The reference for all of them is the control's own variation, measured by an A/A pair before a treatment runs.

## A/A calibration

Run the control twice, or n times, and measure the spread in tokens, turns, wall clock and the graded outcome. That spread is the **noise band**: the system's own variation. It closes the statistical-conclusion threat, because a later delta is read against a measured floor rather than an assumed one. It does not touch construct validity: a stable measurement can still measure the wrong thing. The count is part of the design and is agreed before the treatment runs: a band measured after the fact cannot license a claim, and runs added once the data is in are exploratory.

Run it again after a model, fixture or measure change, because the band belongs to that instrument, and record the number with the run that measured it.

## A/B

One treatment against the control, in the same batch, at the same run count. It closes the internal-validity threat: one variable changed, so a difference is attributable. It cannot see an interaction, and it cannot see the difference between a method that works and one that happens to work on this fixture.

## The paired batch

The control re-run inside the same batch as the treatment, at the same n. It closes the drift threat: a candidate compared with an earlier batch proves nothing, because drift between batches moves text neither batch changed. The cost is the control's runs; the gain is that the comparison is paired.

## The factorial

Two variables, every combination, run as one batch: a 2x2 gives the control, each main effect and the interaction. It is the method when the question is "do these two edits interact", and the interaction is the result. A cell is the most expensive measurement a design has, so a 2x2 usually runs at the n a screen can afford, where a cell's movement is near the grader's own granularity; report that resolution instead of reading the movement as an interaction.

## The graded screen

Several arms at different levels of one idea, each run alone, to find which level is worth a proper trial. A screen ranks its arms by cost and by outcome, and selects one arm or none. It is not a dose-response curve: the arms are different methods, not doses of one, so it cannot claim a monotone effect. Call it a screen, and follow it with a paired A/B.

## Negative and positive controls

A **negative control** is a null edit that should produce no effect: the result must come back inconclusive. A **positive control** is a repair known to move the outcome: the result must be detected. Together they prove the instrument can say "no effect" and "effect", which a single arm cannot. A negative control that reports a win means the design or the grade is broken, not that the edit worked.

## Blinding and the grading standard

The grader sees sanitized labels only, and the map is opened after the verdict; the harness enforces that, so it is an invariant rather than a choice. Beyond blindness the judgement's reliability is a design choice -- a repeat pass, a second rater, another model, or another arrangement -- and the method states the one it uses, what it measured, and which bias it leaves open. Which procedure applies is agreed with the operator for the eval at hand.

## Attrition and valid n

An invalid run stays in the table and leaves the means. Report the valid n and the stop class, and report the planned n beside it. This closes the denominator threat: a cell that stopped at six runs is not the cell that was planned at eight. It does not replace the lost runs; a design with high attrition has a narrower band than its run count suggests.

## The minimum detectable effect

At n runs, a proportion moves in steps of 1/n: the smallest difference a run count can resolve is one run, which is 100/n percentage points. A median carries the measured band. The run count therefore fixes the minimum detectable effect: an effect smaller than 1/n is not testable at this n, and the answer is more runs or a different outcome, not a smaller claim. The effect is derived from n and the measured band, never declared as a threshold of its own.

## Admitting a check

Admitting a check takes answers to these questions: what property it asserts, which observable carries it, which input makes it fail, whether it is a gate or a discriminator, and which decision changes when it fails. A check with no false case is dropped.

| Failure class | What it does | Fix |
|---|---|---|
| Vacuous | passes on silence, because absence reads as compliance | require the artefact, and fail on absence |
| Tautological | passes when the treatment text is removed | prove it against the known-bad input |
| Nondiscriminatory | passes in every arm | drop it if it is a discriminator; keep and demote it if it is a gate |

A gate that saturates is not a failed check; it is a validity floor, and it was damaging only where it was relied on as the outcome. A measure that passes in every arm of the case it was built for is a floor, while the blind grade is the discriminator.

## The verdict

The decision rule is a predicate over the measured numbers, stated before the result. The verdict names the validity threat the design does not close, so the next design can close it.
