---
date: 2026-11-12
milestone: M3.7.2 - The change model and its refinements
type: Workflow
status: Closed
---

# Handover - The statechart and the TLA are code

## Objective

Move the model's source out of the reference documents: the workflow and
discussion charts and the change model's chart, transition table and TLA+
module live in `tests/model/`, the references render the chart and the table,
and the gates read the home and fail on drift.

## Scope

Works M3.7.2's *The statechart and the TLA are code, apart from the documents*
and resolves *The change model's code lives with the tests*, its first instance.
The draft chart's home is the *one lifecycle from fork to deletion* row's, which
already names it, so this iteration leaves it in place. Out of scope: the
unified fork-to-deletion lifecycle.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The workflow chart, the discussion chart and the change model's chart and transition table have model homes under `tests/model/`, with the TLA+ module and config beside them. | `ls tests/model/*` | Agent [x] |
| The references render the chart and the table from the home, and the gates fail when the rendered copy drifts; `--write` restores it. | `tests/test_model_home.sh`'s drift and write cases; `scripts/check_statechart.sh` and `scripts/check_change_model.sh` clean on the tree | Agent [x] |
| The change model reference carries no TLA+ module and no repository-only path; the module stays in the home. | `tests/test_model_home.sh`'s shipped-path case | Agent [x] |
| `tests/model/` is named in the testing convention's test homes. | `grep -n "tests/model" .agents/skills/testing/references/test-homes.md` | Agent [x] |
| Every live gate and test that read the old document source is repointed. | `bash scripts/lint.sh` clean; `bash scripts/run_tests.sh` green | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The model home is `tests/model/<subject>/` with `chart.mmd`, `transitions.md` and the TLA+ module. | The model is the spec the tests and the gate validate; a test directory keeps it out of the shipped documentation and beside its check. | This record; `test-homes.md` |
| The shipped references carry no repository-only path; the provenance is the home's `model.md` and the gate. | A shipped reader cannot open a `tests/` target, so naming it sends the agent to a dead path. The home's own `model.md` gives the maintainer the provenance where it can be used. | This record; `tests/model/change_model/model.md` |
| The linking failure names the scope boundary, the naming form and the layer question. | The author meets the boundary in the failure, so the message is where the three legal moves belong; the shipped reader is the one the boundary protects. | This record; `scripts/lint/linking.mjs` |
| The reference renders the chart and the table; the TLA+ is named, not copied. | The chart and table are the prose reader's subject, so a rendered copy is worth its drift gate; the TLA+ is the machine artifact, so a copy is a second source. | This record; the roadmap row |
| `transitions.md` carries an H1 title above `## The transitions`; the scanner slices from the section heading. | The markdownlint gate requires a top-level heading, and the document's rendered section is the `## The transitions` block alone. | This record; `tests/model/change_model/transitions.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| A shipped reference cannot link or name a `tests/` target; the linking gate failed on the link, and the first fix named the path, which left the shipped reader a pointer it could not follow. | record | the row's "link the TLA" became "name it", then "carry no path"; the provenance moved to the home's `model.md`, and the gate's failure now names the boundary | the Decisions table; the row's landing note |
| The discussion chart is a second chart in `workflow_statechart.md`, not only the main chart. | record | it needed its own model home and drift check, or the reference kept authored Mermaid | fixed in this iteration |
| The draft chart's home is the unified fork-to-deletion row's, not this row's. | record | touching it now would be rework when the unified model subsume it | the unified row; this Scope |

## Completed

| File | One-line change summary |
|---|---|
| `tests/model/workflow_statechart/chart.mmd` | the main chart source (new) |
| `tests/model/workflow_statechart/discussion.mmd` | the discussion chart source (new) |
| `tests/model/change_model/chart.mmd` | the change chart source (new) |
| `tests/model/change_model/transitions.md` | the transition table source (new) |
| `tests/model/change_model/ChangeModel.tla` | the extracted TLA+ module (new) |
| `tests/model/change_model/ChangeModel.cfg` | the TLC config (new) |
| `tests/model/change_model/model.md` | the home's provenance and render rule (new) |
| `tests/model/workflow_statechart/model.md` | the home's provenance and render rule (new) |
| `scripts/lint/statechart.mjs` | reads the chart home, checks the rendered blocks, writes both |
| `scripts/lint/linking.mjs` | the failure names the scope boundary and the naming form |
| `scripts/lint/change_model.mjs` | reads the model home, checks the rendered chart and table, writes both |
| `scripts/check_statechart.sh` | the model and discussion-model defaults |
| `scripts/check_change_model.sh` | the model-dir default |
| `docs/reference/workflow_statechart.md` | the rendered copies kept; no repository-only path |
| `docs/reference/change_model.md` | the appendix removed; the rendered copy kept; no repository-only path |
| `.agents/skills/testing/references/test-homes.md` | the `tests/model/` home |
| `tests/test_model_home.sh` | the drift, write and shipped-path cases (new) |
| `tests/test_linking.sh` | asserts the scope wording on the failure |
| `devlog/roadmap.md` | the general row and the change-model instance closed |
| `devlog/handovers/M3.7.2/20261112-06-workflow-model_as_code.md` | this record |
