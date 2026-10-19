---
date: 2026-10-19
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - the disable-model-invocation reading and gate

## Objective

State which reading of `disable-model-invocation` governs, enforce the boolean type at the frontmatter gate, and decide the audience for a hidden skill's description.

## Scope

The roadmap row **`disable-model-invocation` states no rule and has no observer** in [`devlog/roadmap.md`](../roadmap.md). The field's reading and the gate land here; the upstream installed set is M3.3.3's pipeline, not this row.

Out of scope: rewriting the 31 upstream hidden-skill descriptions, which no repository file owns; the two plan rows and the `closed_record_corrections.md` assessment stay open.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The conventions paragraph states the strong reading: the field removes the skill from the model's prompt | read `docs/development/prompt-authoring-conventions.md` `**Skill frontmatter.**` | Agent [x] |
| The frontmatter gate rejects a non-boolean value | `FRONTMATTER_SCAN_ROOT` over a fixture with `disable-model-invocation: yes` returns rc 1; the two new cases in `tests/test_lint_umbrella.sh` | Agent [x] |
| A boolean value still passes | `FRONTMATTER_SCAN_ROOT` over a fixture with `disable-model-invocation: true` returns rc 0 | Agent [x] |
| The decision on a hidden skill's description is recorded | this record, Decisions | Operator [ ] |
| The gates and the suite are clean | `bash scripts/check_frontmatter.sh`, `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The gate's subject is the field's type, not its presence | the loader tests `=== true`, so a non-boolean silently means the opposite of the author's intent; presence is a design choice, type is a fact | `scripts/lint/frontmatter.mjs`; the two tests |
| A judgement skill stays model-visible and does not set the field | a writer reaches for a judgement mid-draft, so the skill must be discoverable; the milestone's premise depends on it | `prompt-authoring-conventions.md` `**Skill frontmatter.**` |
| A description on a hidden skill is written for the operator's skill list | the model never sees the hidden skill, so a model trigger in its description addresses nobody | this record |
| The 31 upstream hidden-skill descriptions are M3.3.3's | they live in `$AGENT_HOME`, which this repository does not own; the pipeline that ingests the set owns their rewrite | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The repository's five hidden skills all carry a boolean `true`, so no file change was needed for the values; the gate is a forward guard. | result | the field is consistent in the repo; the installed upstream set is not gated |
| The conventions paragraph named `every principle-` skill as hidden, while `principle-propagation-discipline` and `principle-minimal-corrections` are visible. | record defect | corrected in place as this row's one-clause fix |
| The field's effect is stronger than its name: it removes the skill from the prompt entirely, so discovery and firing are one loss. | clarification | stated in the conventions and this record |

## Completed

| File | Change |
|---|---|
| `docs/development/prompt-authoring-conventions.md` | `**Skill frontmatter.**` states the strong reading, the actual hidden set, and the operator audience for a hidden description |
| `scripts/lint/frontmatter.mjs` | a non-boolean `disable-model-invocation` value is a finding |
| `tests/test_lint_umbrella.sh` | two cases: a non-boolean fails, a boolean passes |
| `scripts/lint/norm-ownership.tsv` | regenerated; the edited paragraph reclassified `judgement` |
| `devlog/roadmap.md` | the row marked `[x]` |
