---
name: handover-maintenance
description: "Maintains handovers and leaves them correct. Use when the operator asks to check handover content quality, audit the handover chain, trace a deferred item across iterations, or correct handover structure and references."
---

# handover-maintenance

<!-- Merge provenance: Track A (the three content checks and their run conditions) is the substance of workflow/coding-agent/audits/handover-audit.skill.md. Track B (the triggers, the scope list, the seven-step procedure, and the report) is the substance of workflow/coding-agent/audits/audit.skill.md. Both files are superseded by this skill and were removed by handover 20261003-02. -->

## Purpose

Maintains handover documents and leaves them correct. The run finds each defect, corrects it where the correction is mechanical, and records what it changed. An audit only reports, so this runbook is not the place to stop at findings.

This runbook carries two tracks over one subject. Track A maintains the content quality of the handover the current iteration is writing. Track B maintains the chain of handovers already closed, which is where deferred items, status values, and stale references live.

The rules live in [`handover_policy.md`](../../../docs/operations/handover_policy.md) and [`documentation_policy.md`](../../../docs/operations/documentation_policy.md). This runbook is a convenience copy of the checks. Read the two policy documents before acting. Where this runbook and a policy disagree, the policy wins.

## When to run

### Track A - content checks on the active handover

| Check | Run at | Who | Severity |
|---|---|---|---|
| Design-to-source integrity | The scope gate, before implementation | Agent self-check | Warning |
| Structured output format | The scope gate, before implementation | Agent self-check | Warning |
| Validation tool coverage | Step 7 of the iteration, at pre-close | Agent self-check | Warning |

A Warning flag does not block a gate, but it must be triaged before the iteration closes.

### Track B - chain checks on closed handovers

| Trigger | Scope | Recommendation |
|---|---|---|
| Periodic | The last N handovers, where N is two weeks or 20 iterations, whichever comes first | Run when deferred items have survived several hops, or when the operator suspects an item was dropped |
| Event-driven | The handover chain holding one named deferred item | Run when a deferred item has survived two or more hops without resolution |
| Roadmap maintenance | The prior iteration's handover | Already covered by the roadmap check that opens an iteration |

Track B is not an iteration type. The operator invokes it.

## Procedure

Each step ends on a completion criterion.

### Track A

#### Step 1 - Design-to-source integrity

**Rule.** Any code block in the handover's design sections that will be copied into implementation must be validated against live source within the same iteration. The agent must have grepped or read the file during the iteration to confirm variable names, paths, and call signatures. Memory is not a substitute.

**Check.** For each code block in the design sections, read the handover's Hot files and Completed tables. The source file the code block names must appear in one of them.

**Correction.** Read the source file in this run, fix the code block from it, and record the file and the change.

Completion criterion: every code block in the design sections names a file that exists in Hot files or Completed, and the block matches that file as it stands now.

#### Step 2 - Structured output format

**Rule.** When the design sections require a structured output such as a coverage map, a propagation table, or a diff summary, the format must be defined in the handover before implementation begins. An open-ended analysis requirement with no stated format produces inconsistent results across iterations.

**Check.** Grep the handover for "propagation", "coverage", and "diff". For each hit, confirm that a format template is present in the same section.

**Correction.** Add the missing template to that section.

Completion criterion: every hit above has a format template in its own section.

#### Step 3 - Validation tool coverage

**Rule.** When an acceptance criterion names a validation tool, confirm the tool catches the failure mode it guards. `bash -n` does not catch runtime-only bash errors such as `local` outside a function, a `set -u` violation in a conditional branch, or an arithmetic evaluation error. For scripts, use a runtime check that captures stderr from an actual run, or a targeted grep for the specific anti-pattern.

**Check.** For each acceptance criterion that names `bash -n`, confirm the failure mode is a syntax error and not a runtime error. Where it is uncertain, flag it for operator review rather than passing it.

Completion criterion: each criterion names a tool that covers its failure mode, or the run holds it as a Warning for the operator.

### Track B

#### Step 4 - Scope the handovers

Determine the set of handovers to review.

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

An anomaly the gate reports as a missing section falls into one of two categories:

- **Replaceable one to one.** The header has a canonical equivalent that differs only in casing. Replace it and record a `[CORRECTION]` block.
- **Not replaceable one to one.** The header carries custom content with no canonical equivalent. Add an `[AMENDMENT]` block and leave the content unchanged.

Completion criterion: every handover in scope passes the gate, every anomaly is classified as replaceable or not, and every empty section carries a null marker.

#### Step 6 - Deferred chain

Handovers carry no deferred items: an item deferred with a destination is written back to the roadmap as an open row, and an item ruled out is a Scope sentence. For each handover in scope, confirm the pairing instead.

1. Confirm the handover's commit pairs with exactly one roadmap write-back: its own task row, or the subtask row raised for it.
2. For items the handover ruled out of scope, confirm the Scope sentence carries the reason.
3. For deferred items recorded before the sections were removed (older handovers), trace them through the roadmap rows they were written back to; an item that vanished without a roadmap row or a resolution is a dropped item.

Completion criterion: every handover in scope has its write-back pairing, and every older deferred item is resolved by a roadmap row, flagged as dropped, or flagged for escalation.

#### Step 7 - Status

Read each handover's `**Status:**` value.

- `Active` is valid only for the most recent handover.
- `Closed` is valid for every other handover.
- Any other value is a correction.

Completion criterion: every handover in scope carries `Active` or `Closed` in the position the rule requires.

#### Step 8 - Dangling references

For each file named in `## Completed` or `## Hot files`, confirm the file exists at the referenced path. A deleted or renamed file gets a `[CORRECTION]` block that records the deletion context.

For each function or variable named, grep the codebase to confirm it still exists. A removed symbol leaves a stale reference.

Completion criterion: every named file and symbol either exists or carries a correction block.

#### Step 9 - Corrections and amendments

Apply the record blocks defined by `handover_policy.md`.

- `[CORRECTION -- YYYY-MM-DD]` for a factual error. Edit inline and append the correction block.
- `[AMENDMENT -- YYYY-MM-DD]` for a non-standard format or a policy violation that cannot be corrected cleanly.
- `[REMOVED in MX.X]` for an abandoned or superseded item.

Completion criterion: each defect from Steps 5 to 8 carries the block its kind calls for, and the handover still parses as a handover.

#### Step 10 - Report

Produce the report in the shape below.

Completion criterion: the report covers every handover in scope and every defect found.

## Output shape

The report opens with the handovers examined and the date range, then carries one table of corrections applied, then one row per dropped deferred item naming its originating handover, then one row per roadmap escalation, then the dangling references found, then the policy violations noted.

| # | Handover | Finding | Kind | Action |
|---|---|---|---|---|
| 1 | 20260912-13 | Deferred item "Session date" rename lost at hop 2 | Dropped | Escalated to roadmap |
| 2 | 20260911-02 | Header "## what's next" differs only in casing | Replaceable | `[CORRECTION -- 20261005]` |
| 3 | 20261001-04 | AC names `bash -n` for a runtime failure mode | Track A Warning | Held for operator |

A Track A finding carries severity Warning. It does not block a gate and must be triaged before the iteration closes.

## Non-goals

- Does not check the roadmap. That is [`roadmap-maintenance.md`](roadmap-maintenance.md).
- Does not write policy. A finding that no policy text covers is a gap to report, not a rule to add here.
- Does not close an iteration. Track B records what is already closed and what needs escalation.
- Does not audit handovers outside the scope set from Step 4. A wider sweep is a separate run with its own scope.

## Failure modes

- **A dropped deferred item reads as resolved.** Step 6 exists because an item can vanish from the chain silently. Older handovers carried deferred items in sections now removed; read the roadmap rows the items were written back to before concluding an item was resolved.
- **A correction destroys the record.** Edit inline only for a factual error, and append the block. Never rewrite a closed handover's history without a block that says what changed and why.
- **Case-only header repair loses content.** Confirm a header differs only in casing before replacing it. A header with custom content is not replaceable one to one.
- **A `bash -n` acceptance criterion reads as passed.** The check passes on syntax the script never executes. Confirm the failure mode is a syntax error, or hold the criterion as a Warning.
