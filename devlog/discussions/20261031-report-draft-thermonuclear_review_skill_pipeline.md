---
date: 2026-10-31
milestone: M3.3.3 - The skill maintenance pipeline
type: report
status: draft
---

# Report - Thermo-nuclear review of the skill pipeline

## Context

The operator asked for a thermo-nuclear code-quality review, run as a loop to convergence, over the change the session started from: `git diff d1d5b636..HEAD` at the branch point recorded in `.git/SESSION_STATE`, whose `init_sha` is `a6b24204` and whose own delta was six commits of documentation. The range was widened to `d1d5b636` (`085e20dd~1`), the commit before the skill-pipeline work unit, so the review covered the code the pipeline added: the layer map, the provenance graph, the source-bump CLI, the record gate and their four test files.

The loop is defined in the review shell's `references/loop.md`: a fresh reviewer per round, a verdict per round, one fix round per blocker, seats resolved by the `_REVIEWER` role. Fifteen rounds ran, each with two seats, each seat's log kept under `.scratchpad/review/round-<n>/`.

## What came of it

Two seats disagreed in six of the fifteen rounds; a blocker from one seat counted as a blocker on the round. The blockers, in the order they were raised and closed:

| Round | Blocker | Closed by |
|---|---|---|
| 1 | Four readers carried a copy each of the layer table, the link grammar, the containment test, pi's discovery rule and its package entry. | `55e0c7a6`: `scripts/skill_layers.mjs`. |
| 1 | The graph parsed each `COPY` row, discarded the destination, and restated the pairs as string literals. | `55e0c7a6`: the image roots and copy edges come from the manifest's rows. |
| 2 | The graph took its subject from the shell's directory and reported clean over no evidence. | `35308fba`: the repository resolves from the module URL, and a missing row is a finding. |
| 2 | The record gate restated the agent layer's path and scanned one level deep. | `35308fba`: it imports the table and pi's discovery rule. |
| 3 | The host half of the graph was hand-asserted: a literal `AGENT_HOME` fallback, an exemption for a missing host root, and a seed edge from an unread string. | `9492185f`, then `5b60d337`: the host root and seed edge come from the provision and env rows. |
| 3 | The record gate printed clean over an empty agent layer. | `9492185f`: zero discovered directories is a finding. |
| 4 | A manifest row that reached no root was skipped in silence; a skill the peer copy lacked was hashed against the layer and reported as drift. | `5b60d337`: one pass reports what it cannot build; the missing skill is named. |
| 5 | A missing or unparseable manifest produced an empty graph and a clean check. | `10ca9f0c`: the finding names the file. |
| 6 | The layer map reported clean over four declared layers holding no skill. | `b8db8443`: a map with no skill is a finding. |
| 7 | The store had two readers; a skill node was keyed by its frontmatter name, so two directories sharing one name lost a node. | `2065d028`: `scripts/skill_store.mjs`, and node ids from the skill's path. |
| 8 | The store's identity rule had three sites and reported one bad id twice; `checkGraph` reported a missing path twice. | `bc487b0c`. |
| 9 | The branches the fix rounds added had no tests; the graph's schema had no reader. | `5501a1e5`: `checkGraph` validates against the schema. |
| 10 | The schema was read in one direction only: `items` rules and nested `required` lists were inert. | `43a2c5a8`: `checkShape` recurses. |
| 11 | A rule reached through `items` was never applied; a wrong-typed value was descended into and crashed. | `b4f8b608`: one value-first check. |
| 12 | One identity computed twice: the project layer's root id was `project:project` while the build loops looked up `project`; a malformed graph was reported and then walked. | `bf38d1c9`. |
| 13 | `namespace` carried two axes, so four consumers each carried an exception for one layer. | `6743a36f`: namespace names a location; the project layer is `repo:project`. |
| 14 | A link's scope was decided by a `/opt/` prefix and a copy's peer by a namespace preference, where the manifest declares both. | `5739e01c`; the resolution normalisation that disagreed with the scope check followed in `7b86f6cc`. |

Verification at the head of this range: `bash scripts/lint.sh` clean across 17 gates, `bash scripts/run_tests.sh` 1414 of 1414, and each round's seat log recorded under `.scratchpad/review/`.

## What the loop did not converge on

One blocker is open, and the two seats' remedies contradict earlier ones: round 15's seat 2 blocks on the edge model being one optional-field bag re-checked by a bespoke schema engine, and prescribes deleting `checkGraph`, `checkShape` and the schema in favour of constructive edge helpers, while rounds 9 to 11 blocked precisely because the schema was not enforced and prescribed a validator. Both cannot be satisfied at once, and which contract owns the graph's shape -- the schema file or the builder's types -- is a design decision, not a defect a fix round can close. It is left for the operator.

The loop also surfaced, and did not close, a set of recorded non-blockers. The ones a reader will meet first: `scripts/skill_map.mjs` and `scripts/lint/skill_sources.mjs` both own the `MAINTENANCE.md` rule at different severities; `scripts/source_bump.mjs` repeats the load-store-validate-refuse prologue at three commands; `scripts/render_skill_graph.mjs` is a second CLI over the same module and keeps `allowDrift: true` beside a `--check` that fails on drift; the vendored renderer's licence is copied from a gitignored session path; and `scripts/skill_graph.mjs --check` is run by no gate, because it compares this tree with an image built from an earlier commit.

## The lost instruction

The `code-review` shell and the `thermo-nuclear-code-quality-review` runbook that replaced this repository's review prompt no longer state where a review's commit range comes from. The shell says a review is given "a scope to read", the loop says "Name the range", and the runbook says "the current branch's changes"; the sentence that used to define the range in the prompt was lost in the move to the runbook format. On this branch the omission is load-bearing: `.git/SESSION_STATE`'s `init_sha` (`a6b24204`) and the work unit's own base (`d1d5b636`) are eleven commits apart, and the range had to be settled with the operator before the first seat was spent. In the AGENT_FEEDBACK entry `2026-10-31` the finding is recorded with this session's evidence.

## Artifacts

| Artifact | Source of truth |
|---|---|
| `scripts/skill_layers.mjs`, `scripts/skill_graph.mjs`, `scripts/skill_map.mjs`, `scripts/skill_store.mjs`, `scripts/source_bump.mjs`, `scripts/lint/skill_sources.mjs`, `scripts/render_skill_graph.mjs` | this commit; the executable sources. |
| `scripts/skill_graph.schema.json` | the graph's declared contract, validated by `checkGraph`. |
| `tests/test_skill_graph.sh`, `tests/test_skill_map.sh`, `tests/test_skill_sources.sh`, `tests/test_source_bump.sh`, `tests/skill_layer_loader.mjs`, `tests/skill_source_loader.mjs`, `tests/knowledge/knowledge_skill_layer_resolution.sh`, `tests/fixtures/skill_graph/*` | this commit. |
| `devlog/AGENT_FEEDBACK.md` | the review-range finding, entry `2026-10-31`. |
| The seat logs and briefs | `.scratchpad/review/round-1` to `round-15`, session-local and not committed. |
