---
date: 2026-10-16
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Implementation
status: Closed
---

# Handover - The install-step census

## Objective

Census every install and copy step in the three reasoning tiers, so the layer install design rests on a read of the tree rather than on recall. The census is one of the three inputs that row names, alongside the invalidation history and the measured build cost.

## Scope

One new study record, [`devlog/discussions/20261016-study-active-install_step_census.md`](../discussions/20261016-study-active-install_step_census.md). No Dockerfile, no build script and no source file changed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every install and copy step in the three tiers is enumerated | an independent reviewer re-enumerated the seven Dockerfiles: 41 steps, 6 in tier 1, 14 in tier 2, 21 in tier 3, no missed step and no spurious row | Agent [x] |
| Each row carries its file, line, input, output path and pin | the study's table, with the cited lines spot-checked against the files | Agent [x] |
| Every named class is covered | agent packages, pi extension payload, apt installs, curl installs, uv Python and every `COPY`; the opencode plugin set is named as absent, with the reason | Agent [x] |
| The pin claims are true | the npm pins, the hadolint release asset and the node tag checked against their upstreams | Agent [x] |
| The tier-3 gate claim is true | the study states that `_build_key` gates tiers 1 and 2, and that tier 3 is ungated and rebuilt on every call | Agent [x] |
| The record follows the discussion convention | study skeleton and section order, the naming rule, `**Status:** active` | Agent [x] |
| Gates clean | `bash scripts/lint.sh`, clean across 8 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A `base image` row counts as a step | it is the tier's input, and its provenance is the pin the rest of the tier inherits | the study |
| The census is a `study` record rather than a `report` | it gathers evidence for a design that is still open, and a report records a performed operation | [`discussion_policy.md`](../../docs/policies/discussion_policy.md) |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| Tier 3 is not content-gated. It is rebuilt by `build_image` on every `build_agent` call, while tiers 1 and 2 skip on `_build_key`. The first draft claimed tier 3 was gated and the review caught it, which matters because this is the fact the layer design reads. | correction | the layer install design row |
| The opencode base installs `opencode-ai` unpinned while the pi base pins `@1.19.1`, and the opencode Dockerfile's header names `providers/pi/base.dockerfile`. | measured gap | the dispatch-CLI pin and gate row |
| The hermes base clones `NousResearch/hermes-agent` at the default branch HEAD with no ref, and resolves its Python and npm dependencies at build time. It is the only external source in the tree fetched without a ref. | measured gap | the layer install design row |
| `node:22.22.3-slim` and the hadolint release are tag-pinned, not digest-pinned. | measured gap | the layer install design row |

## Completed

| File | Change |
|---|---|
| [`devlog/discussions/20261016-study-active-install_step_census.md`](../discussions/20261016-study-active-install_step_census.md) | the new study |
| [`devlog/roadmap.md`](../roadmap.md) | the census row is complete |
