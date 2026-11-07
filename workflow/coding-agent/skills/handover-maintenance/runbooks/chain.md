# The chain runbook - the handovers already closed

Checks the chain of handovers already closed, which is where deferred items, status values, and stale references live. An operator audit opens it.

## When to run

| Trigger | Scope |
|---|---|
| Periodic | The last N handovers, where N is two weeks or 20 iterations, whichever comes first |
| Event-driven | The handover chain holding one named deferred item |
| A workflow that reads the chain | The prior iteration's handover |

This runbook is not an iteration type. The operator invokes it, or a workflow runs it.

## Procedure

### Step 1 - Scope the handovers

Determine the set of handovers to check.

- Periodic: list the handovers inside the date range, in git order, and take them in that order. Read the project's `work-log` convention for the tool and the query; where the project has no tool, list the live folder and take the records in the order the convention states.
- Event-driven: trace the deferred item through the roadmap rows it was written back to, and the handovers that cite it.

### Step 2 - Structural scan

For each handover in scope, run the project's record gate on it directly, when the project has one. Read `.agents/skills/work-log/SKILL.md` for the gate's path and its invocation.

The gate checks the frontmatter fields and the body section set over the named file, whatever its date. It reports every required section that is missing and every forbidden section present, and it treats a heading whose casing differs from the project's canonical form as that section missing.

An anomaly the gate reports as a missing section falls into one of two categories, and the finding names which:

- **Replaceable one to one.** The heading has a canonical equivalent that differs only in casing. The fix is a heading replacement plus a `[CORRECTION]` block.
- **Not replaceable one to one.** The heading carries custom content with no canonical equivalent. The fix is an `[AMENDMENT]` block, leaving the content unchanged.

A section that is present but empty carries its canonical marker, and one that does not is an anomaly of the first category.

Where the project has no gate, report the missing gate as a skip and check the body against the convention by hand.

### Step 3 - Landed claim and write-back

Handovers carry no deferred items: an item deferred with a destination is written back to the roadmap as an open row, and an item ruled out is a Scope sentence. For each handover in scope, confirm the landed claim and the write-back outcome instead.

1. Where the handover claims a task landed, confirm that task's roadmap row reflects it. A handover with no roadmap row of its own is not a violation: the write-back step is mandatory and its value may be None, so an iteration that changed no task has nothing to pair.
2. For items the handover ruled out of scope, confirm the Scope sentence carries the reason.
3. For deferred items recorded before the sections were removed (older handovers), trace them through the roadmap rows they were written back to; an item that vanished without a roadmap row or a resolution is a dropped item, and is reported for escalation.

### Step 4 - Status

Read each handover's `**Status:**` value.

- `Active` is valid only for the most recent handover on its track.
- `Closed` is valid for every other handover.
- Any other value is a finding.

The project's `work-log` convention names the tool that answers the per-track check; where the project has none, read the track from the record's folder or its `milestone` field.

### Step 5 - Dangling references

For each file named in the completed section, confirm the file exists at the referenced path. A deleted or renamed file is a finding that names the deletion context.

For each function or variable named, grep the codebase to confirm it still exists. A removed symbol leaves a stale reference, and is a finding.

### Step 6 - The correction form

Where a finding is a correction to a closed record, the report states the form the fix must take, and the fix carries it. The procedure that applies a correction is [`record-correction`](/opt/workflow/agent/modules/coding-agent/prompts/record-correction.md); the forms are:

- A **misrecording** gets the paragraph rewritten in place and the tag moved to a `[CORRECTION -- YYYY-MM-DD: ...]` block at the end of the corrected section.
- A non-standard format or a policy violation that cannot be corrected cleanly gets an `[AMENDMENT -- YYYY-MM-DD: ...]` block, leaving the content unchanged.
- An abandoned or superseded **changelog** entry gets `[REMOVED in MX.X]`; a closed **roadmap** row is edited in place, and a correction that creates work is a new open row.

The report names the form; it does not write the block. A correction that more than one form could satisfy is reported as one no record settles, not as a fix this run can recommend for application.

### Step 7 - Report

Report every finding for every handover in scope in your reply. A check that produced no finding carries its skip and reason.

## Failure modes

- **A dropped deferred item reads as resolved.** Step 3 exists because an item can vanish from the chain silently. Older handovers carried deferred items in sections now removed; read the roadmap rows the items were written back to before concluding an item was resolved.
- **A reported correction loses its form.** A finding that names a fix without naming the `[CORRECTION]` or `[AMENDMENT]` form leaves the caller to invent one, and the closed record's history is rewritten without a block that says what changed and why. Name the form.
- **A case-only header repair loses content.** Confirm a header differs only in casing before reporting it replaceable. A header with custom content is not replaceable one to one.
- **A skipped check reported as silence.** A run that reports no skip for a check it did not run reads as a clean chain. Report the skip.
