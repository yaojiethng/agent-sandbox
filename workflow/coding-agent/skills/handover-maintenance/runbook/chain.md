# The chain runbook - the handovers already closed

Checks the chain of handovers already closed, which is where deferred items, status values, and stale references live. An operator audit opens it, and `check-in`'s thoroughness run dispatches it.

## When to run

| Trigger | Scope |
|---|---|
| Periodic | The last N handovers, where N is two weeks or 20 iterations, whichever comes first |
| Event-driven | The handover chain holding one named deferred item |
| A workflow that reads the chain | The prior iteration's handover |

This runbook is not an iteration type. The operator invokes it, or a workflow dispatches it.

## Procedure

Each step ends on a completion criterion.

### Step 1 - Scope the handovers

Determine the set of handovers to check.

- Periodic: list the handovers inside the date range, in the order the project's `work-log` convention states, and take them in that order.
- Event-driven: trace the deferred item through the roadmap rows it was written back to, and the handovers that cite it.

Completion criterion: the set is named, and each member has a reason for being in scope.

### Step 2 - Structural scan

For each handover in scope, run the project's record gate on it directly, when the project has one. Read `.agents/skills/work-log/SKILL.md` for the gate's path and its invocation.

The gate checks the frontmatter fields and the body section set over the named file, whatever its date. It reports every required section that is missing and every forbidden section present, and it treats a heading whose casing differs from the project's canonical form as that section missing.

An anomaly the gate reports as a missing section falls into one of two categories, and the finding names which:

- **Replaceable one to one.** The heading has a canonical equivalent that differs only in casing. The fix is a heading replacement plus a `[CORRECTION]` block.
- **Not replaceable one to one.** The heading carries custom content with no canonical equivalent. The fix is an `[AMENDMENT]` block, leaving the content unchanged.

Where the project has no gate, report the missing gate as a skip and check the body against the convention by hand.

Completion criterion: every handover in scope passes the gate, every anomaly is classified as replaceable or not, and every empty section carries its canonical marker.

### Step 3 - Landed claim and write-back

Handovers carry no deferred items: an item deferred with a destination is written back to the roadmap as an open row, and an item ruled out is a Scope sentence. For each handover in scope, confirm the landed claim and the write-back outcome instead.

1. Where the handover claims a task landed, confirm that task's roadmap row reflects it. A handover with no roadmap row of its own is not a violation: the write-back step is mandatory and its value may be None, so an iteration that changed no task has nothing to pair.
2. For items the handover ruled out of scope, confirm the Scope sentence carries the reason.
3. For deferred items recorded before the sections were removed (older handovers), trace them through the roadmap rows they were written back to; an item that vanished without a roadmap row or a resolution is a dropped item.

Completion criterion: every landed task the handovers in scope claim is reflected in its roadmap row, and every older deferred item is resolved by a roadmap row, reported as dropped, or reported for escalation.

### Step 4 - Status

Read each handover's `**Status:**` value.

- `Active` is valid only for the most recent handover.
- `Closed` is valid for every other handover.
- Any other value is a finding.

Completion criterion: every handover in scope carries `Active` or `Closed` in the position the rule requires, or is reported.

### Step 5 - Dangling references

For each file named in the completed section, confirm the file exists at the referenced path. A deleted or renamed file is a finding that names the deletion context.

For each function or variable named, grep the codebase to confirm it still exists. A removed symbol leaves a stale reference, and is a finding.

Completion criterion: every named file and symbol either exists or is reported.

### Step 6 - The correction form

Where a finding is a correction to a closed record, the report states the form the fix must take, and the fix carries it. The procedure that applies a correction is [`record-correction`](/opt/workflow/agent/modules/coding-agent/prompts/record-correction.md); the forms are:

- A **misrecording** gets the paragraph rewritten in place and the tag moved to a `[CORRECTION -- YYYY-MM-DD: ...]` block at the end of the corrected section.
- A non-standard format or a policy violation that cannot be corrected cleanly gets an `[AMENDMENT -- YYYY-MM-DD: ...]` block, leaving the content unchanged.
- An abandoned or superseded **changelog** entry gets `[REMOVED in MX.X]`; a closed **roadmap** row is edited in place, and a correction that creates work is a new open row.

The report names the form; it does not write the block. A correction that more than one form could satisfy is reported as one no record settles, not as a fix this run can recommend for application.

Completion criterion: every finding from Steps 2 to 5 that lands on a closed record names its correction form.

### Step 7 - Report

Write the report as JSONL at the path the dispatcher set, in the schema [`check-in/report-schema.md`](/opt/workflow/agent/modules/coding-agent/skills/check-in/report-schema.md) owns.

Completion criterion: the report covers every handover in scope and every finding, and every check that produced no finding has a skip line.

## Failure modes

- **A dropped deferred item reads as resolved.** Step 3 exists because an item can vanish from the chain silently. Older handovers carried deferred items in sections now removed; read the roadmap rows the items were written back to before concluding an item was resolved.
- **A reported correction loses its form.** A finding that names a fix without naming the `[CORRECTION]` or `[AMENDMENT]` form leaves the dispatcher to invent one, and the closed record's history is rewritten without a block that says what changed and why. Name the form.
- **A case-only header repair loses content.** Confirm a header differs only in casing before reporting it replaceable. A header with custom content is not replaceable one to one.
- **A skipped check reported as silence.** A run that reports no skip for a check it did not run reads as a clean chain. Report the skip.
