# The task-row form, measured

**Status:** draft

## Why this exists

The 2026-11-01 instruction-surface work failed three times at the same place: the task row. One row stated a diagnosis no reader could re-run - "a shipped payload is loaded twice" - and it was false. One row left the mechanism open, so a document would have satisfied every word of it while contradicting the decision that made it a gate. One row spanned two units and hid the load-bearing check inside another row's end sentence.

A stopgap landed in the same session: the `task-list` convention's task-granularity rule now names the mechanism class, names an excluded class where one is decided, cites the record that carries a fact's command, and the handover format gate refuses completed work with no acceptance criteria. That sentence is a habit with an anchor. It is not a design.

This document is the design's input. It is written now because the corpus is cheap to measure and the moment to measure it is before the stopping rule matters, not after. M3.5 owns the decision.

## The corpus

Measured 2026-11-01 against the record as it stands.

| Measure | Value |
|---|---|
| Commits touching `devlog/roadmap.md` | 607 |
| Rows in the current file | 271 - 178 open, 93 closed |
| Rows stating a nature of change | 63 |
| Rows stating a decidable end | 15 |
| Open rows stating neither | 106 |
| Closed rows stating a decidable end | 0 |
| Correction commits | 93 |
| `devlog/AGENT_FEEDBACK.md` entries | 32 |

The last line of the table is the sharpest: the decidable end is a recent idiom, used on 15 open rows and on no closed row. Nothing in the record shows an end clause ever deciding a close, so its value is unproven even where it is used.

## The hypotheses, not the findings

Three defect classes are suspected, derived from two failures. They are hypotheses until the correction history says which ones carry the weight:

1. **An unevidenced premise** - a present-tense diagnosis no command reproduces.
2. **An unstated mechanism** - the class is open where the operator has closed it.
3. **The wrong grain** - one row, two units or two ends.

## The work

1. **Code the corrected rows.** Reconstruct every historical form of the roadmap from `git log -p`, pair each row with the correction commit that followed it, and code the defect. Report the distribution.
2. **Build the scanner first, in report-only mode.** Slot presence per row by milestone, age and state. Publish the histogram before proposing enforcement.
3. **Place each slot where its evidence first exists.** A row's premise is established in the session that found it, not at write time, so the slot may belong to the finding or the feedback entry and the row may only cite it.
4. **Red-team the form.** Ten rows that satisfy it and are wrong. Any that passes is the form's blind spot and is reported as one.
5. **Measure the cost.** Characters added per row, the row-length distribution, and the escape-hatch rate. A form that fattens the record without changing what gets written has failed.
6. **Test a writer that never read it.** Dispatch a cold agent with a task, score the row it writes, blind.

## Worked examples

The two rows that carried false claims, and the test that rejects each. Both were in the roadmap on 2026-11-01 and both are gone from it now.

| Row | Test that rejects it | Why |
|---|---|---|
| "A shipped payload is loaded twice" | Truth, and grain | pi's loader reports 110 skills from four roots with zero collisions, so the premise was false; and the row carried two ends, "settings stop naming it twice" and "the drift is checked" |
| "30 collisions between the home and the image payload" | Truth | the comparison paired a committed path with its image copy, a build input against a build output; no pair in that set can race |

The grain test applied to a live unit split one row into two, and the split is what named the missing check: the declaration and its report are one row, and the closure check - with its own class, its own scanner dependency and its own end - is another. That row now exists, and it names two cells that declare no reach at all, which no row had said before.

## What would make the stopgap insufficient

- The class name becoming a ritual: every row carrying `code` because it is the default, with no exclusion ever stated.
- The citation becoming a hop nobody makes: rows citing records that do not carry the command.
- The rule binding only the writer who remembers it, which the cold-writer probe measures.

## Acceptance

- The rule's misses are the classes the corpus calls rare, stated as precision and recall against labels made before the rule existed.
- A writer that never read the rule produces an acceptable row.
- Two adjudicators agree on a twenty-row sample, and the disagreements are resolved in the rule, not in the sample.
- Enforcement is proposed only after the histogram, the red-team result and the cost numbers exist.

Raised by handover `20261101-05`. The stopgap itself is the roadmap row "The task row names its mechanism and its evidence".
