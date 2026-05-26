# prompt-eval — Design Spec

## Purpose

`prompt-eval` is a generalized evaluation system for prompt templates and workflow skills. It serves two use cases:

1. **Regression testing** — verify that a template change fixes a target case without breaking existing cases.
2. **Model benchmarking** — measure how reliably a given model follows defined workflows, and compare models against each other.

The system is designed to be extended to any prompt template or skill, with a fixed test methodology applicable to any future prompt change or model evaluation.

---

## Directory Structure

```
prompt-eval/
├── README.md                        ← system overview and how to run
├── index.md                         ← case registry with status and scores
├── cases/
│   ├── case-001/
│   │   ├── case.md                  ← case definition (schema below)
│   │   └── context.jsonl            ← conversation state at failure time
│   ├── case-002/
│   │   └── ...
│   └── ...
├── contexts/                        ← reusable canonical context templates
│   ├── mid-implementation.jsonl
│   ├── post-ac-confirmed.jsonl
│   └── ...
├── prompts/                         ← prompt templates under test
│   ├── new-session.md               ← canonical current version
│   ├── new-session-v2.md            ← candidate variant (deleted after eval)
│   ├── wrapup.md
│   ├── defer.md
│   └── propagation-check.md
├── runs/
│   └── YYYYMMDD-HHMMSS-<label>/     ← one directory per test run
│       ├── run-config.json          ← model, prompt versions, case filter used
│       ├── case-001.json            ← raw output + score for this case
│       ├── case-002.json
│       └── report.md                ← aggregated report for this run
└── judge/
    ├── judge-prompt.md              ← judge model system prompt
    └── score-schema.json            ← expected output schema for judge
```

`prompt-eval/` lives as its own directory alongside skills. Its location relative to any specific project is not constrained by this design.

---

## Case Schema

Each `case.md` uses YAML frontmatter followed by markdown body sections.

```yaml
---
id: case-001
title: "/package-diff triggers end-session flow"
template: [package-diff, wrapup]
tags: [multi-template, tool-call, session-close]
execution: declaration
status: open
ground-truth:
  pass: 0
  fail: 0
  notes: ""
---
```

**Frontmatter fields:**

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique case identifier. Sequential, never reused. |
| `title` | string | Descriptive title. Should name the failure mode, not the template. |
| `template` | list | One or more templates involved. Matches filenames in `prompts/` without extension. |
| `tags` | list | Free-form labels for filtering. Common tags: `multi-template`, `tool-call`, `gate-sequence`, `ac`, `handover`, `scope`. |
| `execution` | enum | `declaration` or `intercept`. See Execution Model. |
| `status` | enum | `open` / `verified` / `regression`. |
| `ground-truth.pass` | float | Human-assigned pass score: 0, 0.5, or 1. Set when case is first verified. |
| `ground-truth.fail` | float | Human-assigned fail score for the known-bad behavior. Always 0 for a correctly recorded case. |
| `ground-truth.notes` | string | One sentence rationale for the ground truth verdict. |

**Body sections** (in fixed order):

```markdown
## Context

<Minimal reproducible scenario. The smallest sequence of operator inputs and agent
responses that reliably triggers the failure. Written as ordered steps, not prose.
References a file in contexts/ by name if a canonical context template applies.>

## Trigger

<The exact operator input that fires the failure. Usually a slash command plus arguments.>

## Expected behavior

<What the agent must do. Stated as observable actions, not internal state.
"Agent stops after scope proposal and waits for explicit release" not
"Agent understands the gate structure.">

## Pass criteria

<Explicit list. Each criterion is one observable thing. Partial fulfillment of this
list earns 0.5. Full fulfillment earns 1.>

- [ ] <criterion 1>
- [ ] <criterion 2>

## Failure criteria

<Explicit list. Each criterion is one observable failure signal. Partial fulfillment
of this list (some absent, some present) earns 0.5. Full fulfillment earns 0.>

- [ ] <failure signal 1>
- [ ] <failure signal 2>

## Root cause

<What in the template text (or absence of text) allows this failure. One paragraph.>

## Fix

<The minimal change that closes this gap. Stated as a constraint, not a step.
One sentence per constraint. Empty if no fix has been applied.>

## Fix applied

Yes / No — <date if yes>

## Notes

<Optional. Regression risk, related cases, open questions.>
```

---

## Context Files

Each case has a `context.jsonl` file — a messages array in JSONL format representing the conversation state at the point the failure was observed.

**Format:** Standard Anthropic API messages array, one message per line.

```jsonl
{"role": "system", "content": "<system prompt including template text>"}
{"role": "user", "content": "<operator message 1>"}
{"role": "assistant", "content": "<agent response 1>"}
{"role": "user", "content": "<operator message 2>"}
```

**Construction discipline:**

- Captured at failure time from raw conversation logs. Do not reconstruct from memory.
- Pruned to the minimal sequence that reliably triggers the failure. Remove turns that don't affect the failure mode.
- The template text under test must be included in the system prompt or as an early assistant turn.
- The trigger (the operator input that fires the failure) is the final user message in the array.

**Canonical context templates** in `contexts/` are extracted when two or more cases share substantially the same session state. Cases reference them by filename. The full context file is retired when a canonical template is extracted.

**Size gate:** If a context file exceeds 10kb, it must be pruned to a minimal transcript or refactored to reference a canonical context template.

---

## Execution Model

Each case specifies one of two execution modes.

### Declaration (default)

A test harness instruction is added to the system prompt:

> "This is an evaluation run. Before executing any tool call, append a one-line summary of the action you are about to take, prefixed with `[INTENT]:`. Then proceed."

The model declares its decision in text before acting. The judge model evaluates the declaration against the pass/fail criteria. No tool call stubs required.

**Limitation:** The declaration instruction slightly modifies model behavior — the pause-and-declare may suppress some failure modes via self-correction. Use for cases where the failure is in the decision structure, not in execution detail.

### Intercept

A code-driven harness intercepts the API response stream at the first tool call boundary. The response up to that point is captured and evaluated. Tool calls are not executed. No declaration instruction needed.

**Use when:** Declaration consistently produces false passes — the model passes the declaration check but would fail if allowed to execute.

**Implementation:** Deferred. Design the system for declaration first. Promote cases to intercept if declaration proves insufficient.

---

## Prompt Versioning

Canonical prompt files use the base filename: `new-session.md`.

Candidate variants under evaluation use a suffix: `new-session-v2.md`.

The test runner detects any file matching `<template-name>-*.md` as a candidate variant and includes it automatically in comparison runs. After evaluation, the winner is renamed to the canonical filename and the loser is deleted. Git history preserves the old version.

---

## Scoring Model

Each case is scored 0 / 0.5 / 1.

| Score | Meaning |
|---|---|
| 1 | All pass criteria met. No failure criteria present. |
| 0.5 | Partial — correct path taken but at least one pass criterion missed, or at least one failure criterion present but not all. |
| 0 | Failure mode reproduced. All or most failure criteria present. |

**Ground truth:** Each case carries a human-assigned ground truth score in frontmatter. Set when the case is first verified against a known-good or known-bad model response.

**Judge model score:** Produced automatically on each run. Compared against ground truth. Divergences flagged in the report.

**Manual correction:** Test run output files are editable. Edit the score field in the case output JSON, then regenerate the report. The report is always derived from the output files — never from the judge model's raw response alone.

---

## Judge Model

The judge model reads the case definition and the model output, then produces a structured score.

### System prompt (`judge/judge-prompt.md`)

```
You are an evaluator for prompt template behavioral tests.

You will be given:
1. A test case definition including pass criteria and failure criteria
2. The model output produced during the test run

Your task:
- Check each pass criterion against the output. Mark each as met or not met.
- Check each failure criterion against the output. Mark each as present or absent.
- Assign a score: 1 (all pass criteria met, no failure criteria present), 0.5 (partial), or 0 (failure mode reproduced).
- Write one sentence of rationale explaining the score.

Return JSON only. No preamble. Schema:
{
  "pass_criteria": [{"criterion": "...", "met": true|false}],
  "failure_criteria": [{"criterion": "...", "present": true|false}],
  "score": 0 | 0.5 | 1,
  "rationale": "..."
}
```

### Output schema (`judge/score-schema.json`)

```json
{
  "case_id": "case-001",
  "model": "claude-haiku-4-5",
  "prompt_version": "new-session.md",
  "run_id": "20260422-143000-model-eval",
  "score": 0.5,
  "ground_truth": 0,
  "divergence": true,
  "pass_criteria": [
    {"criterion": "Agent stops after scope proposal", "met": true},
    {"criterion": "Agent waits for explicit release before Gate 2", "met": false}
  ],
  "failure_criteria": [
    {"criterion": "Agent presents AC in same turn as scope proposal", "present": true}
  ],
  "rationale": "Agent stopped after scope but proceeded to AC without waiting for explicit release.",
  "raw_output": "..."
}
```

---

## Test Runner

### Run configuration

A run is parameterized by:

```json
{
  "run_id": "20260422-143000-model-eval",
  "label": "model-eval",
  "models": ["claude-sonnet-4-6", "claude-haiku-4-5"],
  "prompt_versions": {
    "new-session": ["new-session.md", "new-session-v2.md"]
  },
  "case_filter": {
    "template": ["new-session"],
    "tags": [],
    "status": ["open", "verified"]
  },
  "execution": "declaration"
}
```

### Loop structure

The runner iterates the following nested loop:

```
for each model in models:
  for each prompt_version in prompt_versions:
    for each case matching case_filter:
      1. Load case.md and context.jsonl
      2. Inject template text and declaration instruction into system prompt
      3. Call model API with context + trigger
      4. Capture response
      5. Call judge model with case definition + response
      6. Write output to runs/<run_id>/case-<id>.json
  aggregate scores across cases for this model + prompt_version
write report to runs/<run_id>/report.md
```

### Implementation options

**Option A — Model-driven loop (default)**

A reasoning model (e.g. the agent itself running in the harness) is given the run configuration and the cases directory. It iterates the loop, calls the API for each case, calls the judge model, writes output files, and produces the report. The operator triggers the run and reviews the report on completion.

Start here. Lower infrastructure cost. Sufficient for most use cases.

**Option B — Code-driven harness**

A script using the Anthropic SDK iterates the loop programmatically. Tool call interception (Tier 2 execution) is implemented here. More reliable for large case sets and for cases requiring intercept execution.

Implement if Option A proves unreliable in practice — non-deterministic loop behavior, judge model errors not caught, or intercept cases needed at scale.

Both options produce the same output file structure and the same report format. The choice of runner does not affect case schema, scoring model, or report design.

---

## Report Format

Reports live at `runs/<run_id>/report.md`.

### Prompt change report (`--mode prompt-change`)

Generated when two or more prompt versions are compared.

```markdown
# Prompt Eval Report — <date>

**Mode:** Prompt change
**Models:** claude-sonnet-4-6
**Prompt versions compared:** new-session.md vs new-session-v2.md
**Cases run:** 12

## Summary

| Prompt | Score | Pass | Partial | Fail |
|---|---|---|---|---|
| new-session.md | 7/12 | 7 | 3 | 2 |
| new-session-v2.md | 10/12 | 9 | 1 | 2 |

## Target case

| Case | new-session.md | new-session-v2.md | Delta |
|---|---|---|---|
| case-004 — two gates compressed | 0 | 1 | +1 ✓ |

## Regressions

| Case | new-session.md | new-session-v2.md | Delta |
|---|---|---|---|
| case-002 — AC not updated in handover | 1 | 0.5 | -0.5 ⚠ |

## Partial results (0.5)

| Case | Prompt | Rationale |
|---|---|---|
| case-002 | new-session-v2.md | Agent updated handover but after implementation began |

## Judge model divergences

| Case | Ground truth | Judge score | Note |
|---|---|---|---|
| case-003 | 1 | 0.5 | Judge flagged AC as non-specific; human scored as pass |

## AI evaluation

<Narrative comparison generated by a model after scores are aggregated.
Covers: what changed between prompt versions, which failure modes were closed,
which regressions appeared, recommendation.>
```

### Model evaluation report (`--mode model-eval`)

Generated when one or more models are evaluated against a fixed prompt set.

```markdown
# Prompt Eval Report — <date>

**Mode:** Model evaluation
**Models compared:** claude-sonnet-4-6, claude-haiku-4-5
**Prompt version:** new-session.md (canonical)
**Cases run:** 12

## Summary

| Model | Score | Pass | Partial | Fail |
|---|---|---|---|---|
| claude-sonnet-4-6 | 10/12 | 9 | 1 | 2 |
| claude-haiku-4-5 | 7/12 | 6 | 2 | 4 |

## Failed cases

| Case | sonnet-4-6 | haiku-4-5 |
|---|---|---|
| case-001 — package-diff triggers wrapup | 1 | 0 |
| case-004 — two gates compressed | 0 | 0 |

## Partial cases (0.5)

| Case | Model | Rationale |
|---|---|---|
| case-002 | haiku-4-5 | AC produced but not written to handover |

## Judge model divergences

...

## AI evaluation

<Narrative comparison generated by a model after scores are aggregated.
Covers: which model performed better overall, which templates or failure modes
show the largest gap, recommendation for which model to use.>
```

### Drill-down

Each case ID in the report links to the raw output file at `runs/<run_id>/case-<id>.json`. The raw output contains the full model response, judge model evaluation, per-criterion breakdown, and score.

To adjust a score: edit the `score` field in the case output JSON, then regenerate the report by re-running the aggregation step only (not the full eval loop).

---

## Index

`index.md` is the case registry. Updated manually when cases are added or status changes.

```markdown
# prompt-eval Case Index

| ID | Title | Template | Tags | Status | Ground truth |
|---|---|---|---|---|---|
| case-001 | /package-diff triggers end-session flow | package-diff, wrapup | multi-template, tool-call | open | — |
| case-002 | AC not updated in handover after Gate 2 | new-session | ac, handover | open | — |
| case-003 | AC were not operator-runnable | new-session | ac | open | — |
| case-004 | Scope gate and AC gate treated as one block | new-session | gate-sequence | open | — |
| case-005 | Hot files populated before compaction confirmed | new-session | handover | open | — |
| case-006 | /new-session without args defaults to wrong session | new-session | scope | open | — |
```

---

## Adding a New Case

1. Create `cases/case-NNN/` with the next sequential ID.
2. Write `case.md` using the schema above.
3. Save `context.jsonl` from the raw conversation log. Prune to minimal reproducible sequence.
4. Add a row to `index.md`.
5. Set `status: open` and leave `ground-truth` empty until first verified run.
6. If the case shares context with an existing case, extract a canonical context template to `contexts/` and update both cases to reference it.

---

## Extending to a New Template

No system changes required. Add cases with the new template name in the `template` frontmatter field. The runner discovers cases by reading frontmatter — it does not maintain a template registry.

If the new template introduces tool calls not yet seen, assess whether existing declaration stubs are sufficient or whether new intercept infrastructure is needed.

---

## Open Items

| Item | Status |
|---|---|
| Intercept execution implementation | Deferred — implement if declaration proves insufficient |
| Runner implementation (Option A vs B) | Deferred — start with Option A, promote to B if needed |
| Canonical context templates | Deferred — extract from cases when pattern emerges across 2+ cases |
| AI narrative generation prompt | Draft in judge-prompt.md when first model-eval run is ready |
