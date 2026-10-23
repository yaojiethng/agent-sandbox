# The content runbook - the handover the iteration is writing

Checks the content quality of the handover the current iteration is writing. `/iter` opens this runbook at its scope gate and again at its pre-close; `wrapup` B9 opens it over the closed record.

## When to run

| Check | Run at | Stop condition |
|---|---|---|
| Structured output format | The scope gate, before implementation | A required structured output has no format template in its own section |
| Validation tool coverage | The iteration's pre-close step | An acceptance criterion names a tool that does not catch its failure mode |

A finding does not block a gate, but the dispatcher must route it before the iteration closes.

## Procedure

Each step ends on a completion criterion.

### Step 1 - Structured output format

**Rule.** When the design sections require a structured output such as a coverage map, a propagation table, or a diff summary, the format must be defined in the handover before implementation begins. An open-ended analysis requirement with no stated format produces inconsistent results across iterations.

**Check.** Grep the handover for "propagation", "coverage", and "diff". For each hit, confirm that a format template is present in the same section.

Completion criterion: every hit above has a format template in its own section, or is reported.

### Step 2 - Validation tool coverage

**Rule.** When an acceptance criterion names a validation tool, confirm the tool catches the failure mode it guards. `bash -n` does not catch runtime-only bash errors such as `local` outside a function, a `set -u` violation in a conditional branch, or an arithmetic evaluation error. For scripts, use a runtime check that captures stderr from an actual run, or a targeted grep for the specific anti-pattern.

**Check.** For each acceptance criterion that names `bash -n`, confirm the failure mode is a syntax error and not a runtime error. Where it is uncertain, report it rather than passing it.

Completion criterion: each criterion names a tool that covers its failure mode, or is reported.

## Failure mode

- **A `bash -n` acceptance criterion reads as passed.** The check passes on syntax the script never executes. Confirm the failure mode is a syntax error, or report it.
