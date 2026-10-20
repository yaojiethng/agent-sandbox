---
date: 2026-10-16
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Implementation
status: Closed
---

# Handover - Fix the build skip on a changed base

## Objective

Make a base tier's rebuild depend on the Dockerfile's content, so an edit to a tier-1 or tier-2 Dockerfile takes effect instead of being skipped because the image merely exists. This is the prefactor that lets the dispatch-CLI pin land and reach a container.

## Scope

The build key and the skip decision, the label that carries it, the docker stub that reports it, and the tests. Out of scope: the dispatch-CLI pin and the layer install design, which are the next rows of M3.6.1.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skip keys on the Dockerfile's content | `bash tests/test_trace_build.sh`, `test_build_key_tracks_dockerfile_content` | Agent [x] |
| A rebuilt base changes the key for the tier above it | the same suite, `test_build_key_tracks_the_base_image` | Agent [x] |
| A matching key skips the tier | the same suite, `test_build_if_missing_skips_on_matching_key` | Agent [x] |
| A stale key rebuilds the tier | the same suite, `test_build_if_missing_builds_on_stale_key` | Agent [x] |
| The real host build reflects a base edit | needs docker: edit a base Dockerfile, run the build, observe that tier rebuild | Operator |
| Gates clean | shellcheck clean across 176 files; `bash scripts/lint.sh` clean across 8 gates | Agent [x] |
| Full suite green | `bash scripts/run_tests.sh`, 1154 passed across 82 files, 0 failed | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The key is the Dockerfile's sha256, plus the base image's content id for a provider tier | content is what an edit changes, and a rebuilt shared base must force the tier above it; the mtime is deliberately excluded because it moves without content | `_build_key` in [`scripts/build.sh`](../../../scripts/build.sh) |
| The key rides the image as the label `agent-sandbox.base-build-key` | the skip comparison needs a recorded value, and a label needs no side file to drift from the image | `build_if_missing`; `image_label` |
| A missing or differing label rebuilds | fail-closed: an image built before the key existed must not be trusted as current | `build_if_missing` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The provider-decision install in `src/reasoning/providers/pi/base.dockerfile` is effective on the next build now that the tier-2 skip keys on content. The gap the runner-seam handover recorded, the install being inert on a machine with an existing `pi-base` image, is closed by this fix. | resolution | this record; the dispatch-CLI pin row |
| The build still cannot report what it rebuilt, because `build_image` runs `docker build --quiet`. The host probe in M3.6.2 supplies that data. | measurement gap | M3.6.2 |

## Completed

| File | Change |
|---|---|
| [`src/build/image.sh`](../../../src/build/image.sh) | `image_label`, the generic image-label reader |
| [`scripts/build.sh`](../../../scripts/build.sh) | `_build_key`, the top-level `build_if_missing` with the content-key check, the `extra_label` on `build_image`, and `build_agent` passing the base image so a rebuilt shared base propagates |
| [`tests/stubs/docker`](../../../tests/stubs/docker) | reports the `agent-sandbox.base-build-key` label |
| [`tests/test_trace_build.sh`](../../../tests/test_trace_build.sh) | four cases, and the base-key map in the default-targets count |
| [`devlog/roadmap.md`](../../roadmap.md) | the build-skip row is complete |
