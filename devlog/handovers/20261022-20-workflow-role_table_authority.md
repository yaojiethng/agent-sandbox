---
date: 2026-10-22
milestone: M3.6.3 - Route and decide
type: Workflow
status: Closed
---

# Handover - The committed role table is the authority

## Objective

Make the committed role table the source every reader resolves, and make the setup path refresh the container's copy from it, so a model choice is a reviewable edit and no second home survives.

## Scope

The roadmap row **The role table moves into version control**. This is a late write-back: the row's first landing is handover `20261020-05`, and the work recorded here is the ordered-assignment format, the project-copy refresh, and the reviewer's pair, which the call site resolves from the table rather than a pin inside a retired skill.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The resolver reads the committed table, with `DISPATCH_REC_FILE` as the explicit override | `node src/libs/dispatch/cli.ts table roles` prints the committed entries | Agent [x] |
| The setup path refreshes the container's copy from the project copy | `bash tests/test_pi_model_recommendations.sh` prints `9 passed, 0 failed` | Agent [x] |
| No shipped file binds a role to a model the operator did not write into the table | the same suite's `test_no_file_pins_a_role_to_a_model` | Agent [x] |
| The review runner carries no model, and its seats read back the pair the caller resolved from the table | `bash tests/test_review_dispatch.sh` prints `9 passed, 0 failed` | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` prints `Lint: clean in 7s across 12 gates` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The committed `.agents/model-recommendations.md` is the authority, and `$AGENT_HOME` is the explicit override | a model choice the operator sets is then visible to every diff, handover and verification sweep | [`model-recommendations.md`](../../.agents/model-recommendations.md), [`setup-model-recommendations/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/setup-model-recommendations/SKILL.md) |
| The setup path refreshes the container's copy from the project copy | the mounted home file is the fallback path, so it must not shadow the authority | [`setup.sh`](../../src/reasoning/providers/pi/setup.sh) |
| The table lists ordered assignments, and the free pool comes first | the walk spends the cheapest route that can answer, and an exhausted route cools rather than blocks | [`model-recommendations.md`](../../.agents/model-recommendations.md) |
| The review runner takes the pair its caller resolved, and carries none of its own | reproducibility is the contract, and a pin inside the runner is the bypass the table exists to close | [`review-dispatch.sh`](../../src/reasoning/providers/pi/config/agent/bin/review-dispatch.sh) |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row's landing and its write-back are two iterations apart, because the ordered-assignment format had to ship before the marker could be true | process | a late write-back is a record defect by itself; this unit closes it | recorded here |
| The retired `~/.pi/model-recommendations.md` is a bind mount the container cannot remove | environment | the resolver keeps the fallback path until the host removes the mount | recorded here; the behaviour is stated in the skill |
| The ADR's two-line header broke the doc-wrap rule once the file was edited, because the file's exemption ended with the edit | defect | the fix is a blank line between the two fields, and the stale exemption is removed so the rule holds the file directly | fixed in this unit |

## Completed

| File | Change |
|---|---|
| [`.agents/model-recommendations.md`](../../.agents/model-recommendations.md) | the committed table, with one ordered assignment list per role |
| [`single_source_model_recommendations.md`](../../docs/adr/single_source_model_recommendations.md) | R8 is superseded, the table's committed home is current, and the header fields are separated |
| [`.markdownlint-cli2.mjs`](../../.markdownlint-cli2.mjs) | the ADR leaves the doc-wrap legacy list, because its header no longer needs the exemption |
| [`setup.sh`](../../src/reasoning/providers/pi/setup.sh), [`onboard.sh`](../../src/reasoning/providers/pi/onboard.sh) | the container's copy refreshes from the project copy |
| [`model-recommendations.skeleton.md`](../../src/reasoning/providers/pi/model-recommendations.skeleton.md) | the skeleton names no model |
| [`setup-model-recommendations/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/setup-model-recommendations/SKILL.md) | the skill states the committed file as the authority |
| [`AGENTS.md`](../../AGENTS.md), [`AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | the role line states its ordered assignments, and the reviewer takes the pair its caller resolved |
| [`test_pi_model_recommendations.sh`](../../tests/test_pi_model_recommendations.sh) | the setup, the table's format and the no-pin rule |
| [`devlog/roadmap.md`](../roadmap.md) | the row closed with the late write-back named |
