---
name: handover-maintenance
description: "Checks handover content and the closed handover chain against handover_policy.md and documentation_policy.md, and reports the violations. Use when the operator asks to check handover content quality, audit the handover chain, trace a deferred item across iterations, or correct handover structure. Writes nothing."
---

# handover-maintenance

<!-- Merge provenance: Track A (the three content checks and their run conditions) is the substance of workflow/coding-agent/audits/handover-audit.skill.md. Track B (the triggers, the scope list, the seven-step procedure, and the report) is the substance of workflow/coding-agent/audits/audit.skill.md. Both files are superseded by this skill and were removed by handover 20261003-02. The skill was made report-only by handover 20261004-10, which took back the part of commit c1bc00e that made a maintenance run write its corrections: the checks stay, the write authority leaves, and no audit file is restored. -->

## Purpose

Checks handover documents and reports the violations of [`handover_policy.md`](../../../docs/operations/handover_policy.md) and [`documentation_policy.md`](../../../docs/operations/documentation_policy.md). The run finds each violation and reports it in the form the dispatcher consumes. It writes no record, applies no correction, and invents no fact.

This runbook carries two tracks over one subject. Track A checks the content quality of the handover the current iteration is writing. Track B checks the chain of handovers already closed, which is where deferred items, status values, and stale references live.

The rules live in [`handover_policy.md`](../../../docs/operations/handover_policy.md) and [`documentation_policy.md`](../../../docs/operations/documentation_policy.md). This runbook is a convenience copy of the checks. Read the two policy documents before acting. Where this runbook and a policy disagree, the policy wins.

## When to run

### Track A - content checks on the active handover

| Check | Run at | Stop condition |
|---|---|---|
| Design-to-source integrity | The scope gate, before implementation | A code block names a file that does not appear in Hot files or Completed, or that no longer matches the file |
| Structured output format | The scope gate, before implementation | A required structured output has no format template in its own section |
| Validation tool coverage | Step 7 of the iteration, at pre-close | An acceptance criterion names a tool that does not catch its failure mode |

A Track A finding does not block a gate, but the dispatcher must route it before the iteration closes.

### Track B - chain checks on closed handovers

| Trigger | Scope |
|---|---|
| Periodic | The last N handovers, where N is two weeks or 20 iterations, whichever comes first |
| Event-driven | The handover chain holding one named deferred item |
| A workflow that reads the chain | The prior iteration's handover |

Track B is not an iteration type. The operator invokes it, or a workflow dispatches it.

## Procedure

Each step ends on a completion criterion.

### Track A

#### Step 1 - Design-to-source integrity

**Rule.** Any code block in the handover's design sections that will be copied into implementation must be validated against live source within the same iteration. Memory is not a substitute.

**Check.** For each code block in the design sections, read the handover's Hot files and Completed tables. The source file the code block names must appear in one of them.

Completion criterion: every code block in the design sections either names a file in Hot files or Completed and matches that file as it stands, or is reported.

#### Step 2 - Structured output format

**Rule.** When the design sections require a structured output such as a coverage map, a propagation table, or a diff summary, the format must be defined in the handover before implementation begins. An open-ended analysis requirement with no stated format produces inconsistent results across iterations.

**Check.** Grep the handover for "propagation", "coverage", and "diff". For each hit, confirm that a format template is present in the same section.

Completion criterion: every hit above has a format template in its own section, or is reported.

#### Step 3 - Validation tool coverage

**Rule.** When an acceptance criterion names a validation tool, confirm the tool catches the failure mode it guards. `bash -n` does not catch runtime-only bash errors such as `local` outside a function, a `set -u` violation in a conditional branch, or an arithmetic evaluation error. For scripts, use a runtime check that captures stderr from an actual run, or a targeted grep for the specific anti-pattern.

**Check.** For each acceptance criterion that names `bash -n`, confirm the failure mode is a syntax error and not a runtime error. Where it is uncertain, report it rather than passing it.

Completion criterion: each criterion names a tool that covers its failure mode, or is reported.

### Track B

#### Step 4 - Scope the handovers

Determine the set of handovers to check.

- Periodic: list the handovers in `devlog/handovers/` inside the date range and sort them by date.
- Event-driven: trace the deferred item through the roadmap rows it was written back to, and the handovers that cite it.

Completion criterion: the set is named, and each member has a reason for being in scope.

#### Step 5 - Structural scan

For each handover in scope, run the format gate on it directly:

```bash
bash scripts/check_handover_format.sh path/to/handover.md
```

The gate checks the frontmatter fields and the section set over the named file, whatever its date, so the maintenance pass and the commit-time gate share one rule. It reports every required section that is missing and every forbidden section present, and it treats a header whose casing differs from the canonical form as that section missing.

The required sections are Objective, Scope, Acceptance criteria, Hot files, Decisions, Decisions pending, Findings, and Completed. An empty section carries a null marker. `Decisions pending` applies from handover `20261001-03` forward, so a handover closed before that date is not flagged for its absence. The forbidden sections are `Deferred`, `Carried forward` and `What's Next`; a deferred item goes to the roadmap instead.

An anomaly the gate reports as a missing section falls into one of two categories, and the finding names which:

- **Replaceable one to one.** The header has a canonical equivalent that differs only in casing. The fix is a header replacement plus a `[CORRECTION]` block.
- **Not replaceable one to one.** The header carries custom content with no canonical equivalent. The fix is an `[AMENDMENT]` block, leaving the content unchanged.

Completion criterion: every handover in scope passes the gate, every anomaly is classified as replaceable or not, and every empty section carries a null marker.

#### Step 6 - Landed claim and write-back

Handovers carry no deferred items: an item deferred with a destination is written back to the roadmap as an open row, and an item ruled out is a Scope sentence. For each handover in scope, confirm the landed claim and the write-back outcome instead.

1. Where the handover claims a task landed, confirm that task's roadmap row reflects it. A handover with no roadmap row of its own is not a violation: the write-back step is mandatory and its value may be None, so an iteration that changed no task has nothing to pair.
2. For items the handover ruled out of scope, confirm the Scope sentence carries the reason.
3. For deferred items recorded before the sections were removed (older handovers), trace them through the roadmap rows they were written back to; an item that vanished without a roadmap row or a resolution is a dropped item.

Completion criterion: every landed task the handovers in scope claim is reflected in its roadmap row, and every older deferred item is resolved by a roadmap row, reported as dropped, or reported for escalation.

#### Step 7 - Status

Read each handover's `**Status:**` value.

- `Active` is valid only for the most recent handover.
- `Closed` is valid for every other handover.
- Any other value is a finding.

Completion criterion: every handover in scope carries `Active` or `Closed` in the position the rule requires, or is reported.

#### Step 8 - Dangling references

For each file named in `## Completed` or `## Hot files`, confirm the file exists at the referenced path. A deleted or renamed file is a finding that names the deletion context.

For each function or variable named, grep the codebase to confirm it still exists. A removed symbol leaves a stale reference, and is a finding.

Completion criterion: every named file and symbol either exists or is reported.

#### Step 9 - The correction form

Where a finding is a correction to a closed record, the report states the form the fix must take, and the fix carries it. Read step 2 and step 3 of [`handover_policy.md`](../../../docs/operations/handover_policy.md) `## Corrections to Closed Handovers`:

- A **misrecording** gets the paragraph rewritten in place and the tag moved to a `[CORRECTION -- YYYY-MM-DD: ...]` block at the end of the corrected section.
- A non-standard format or a policy violation that cannot be corrected cleanly gets an `[AMENDMENT -- YYYY-MM-DD: ...]` block, leaving the content unchanged.
- An abandoned or superseded item gets `[REMOVED in MX.X]`.

The report names the form; it does not write the block. A correction that more than one form could satisfy is reported as one no record settles, not as a fix this run can recommend for application.

Completion criterion: every finding from Steps 5 to 8 that lands on a closed record names its correction form.

#### Step 10 - Report

Write the report as JSONL at the path the dispatcher set, in the schema [`workflow/coding-agent/skills/check-in/report-schema.md`](check-in/report-schema.md) owns.

Completion criterion: the report covers every handover in scope and every finding, and every check that produced no finding has a skip line.

## Output shape

The report is the JSONL file described in [`workflow/coding-agent/skills/check-in/report-schema.md`](check-in/report-schema.md), written at the path the dispatcher sets, outside the repository tree. It is never committed.

Print a one-line summary to stdout when the run ends: the findings count, the skip count, and the path.

A Track A finding is reported through the same schema as any other, with the recommendation its check supports. A finding that does not block a gate is still reported; the dispatcher decides where it is routed.

## Non-goals

- Does not write a record, apply a correction, or commit. The dispatcher applies the report.
- Does not close an iteration. Track B reports what is already closed and what needs escalation.
- Does not check the roadmap. That is [`roadmap-maintenance.md`](roadmap-maintenance.md).
- Does not write policy. A finding that no policy text covers is a gap to report, not a rule to add here.
- Does not audit handovers outside the scope set from Step 4. A wider sweep is a separate run with its own scope.
- Does not choose a commit shape, a message, or a fold. The report carries no field for one.

## Failure modes

- **A dropped deferred item reads as resolved.** Step 6 exists because an item can vanish from the chain silently. Older handovers carried deferred items in sections now removed; read the roadmap rows the items were written back to before concluding an item was resolved.
- **A reported correction loses its form.** A finding that names a fix without naming the `[CORRECTION]` or `[AMENDMENT]` form leaves the dispatcher to invent one, and the closed record's history is rewritten without a block that says what changed and why. Name the form.
- **A case-only header repair loses content.** Confirm a header differs only in casing before reporting it replaceable. A header with custom content is not replaceable one to one.
- **A `bash -n` acceptance criterion reads as passed.** The check passes on syntax the script never executes. Confirm the failure mode is a syntax error, or report it.
- **A skipped check reported as silence.** A run that reports no skip for a check it did not run reads as a clean chain. Report the skip.
