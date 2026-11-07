---
date: 2026-10-17
milestone: M3.6.4 - The reasoning image refactor
type: Implementation
status: Closed
---

# Handover - Docker's layer cache as the only reuse rule

## Objective

Remove the build-skip mechanism, so every tier is built on every call and docker's layer cache is the only thing that decides what is reused.

## Scope

The M3.6.4 row `The build-skip mechanism is removed`, applying the settled decision in [`reasoning_layer_tiers.md`](../../docs/adr/reasoning_layer_tiers.md) (`Docker's layer cache is the only reuse rule`). The remaining rows of the sub-milestone, `Pin every build input` and `The host build probe is re-run against the new shape`, are out of scope; the second is the operator's host run and this change alters what it measures.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skip machinery and its label are gone from source, scripts, tests and docs | `grep -rn "build_if_missing\|_build_key\|base-build-key\|image_label" src/ scripts/ tests/`, no match | Agent [x] |
| Every tier is built on every call | `bash tests/test_trace_build.sh`, the default-target count is one sandbox build plus three tiers per provider | Agent [x] |
| The probe reports a tier by whether any of its own steps ran uncached | `bash tests/test_build_probe.sh`, 14 passed, including the fully cached case | Agent [x] |
| A fully cached tier is reported cached rather than absent | `bash tests/test_build_probe.sh`, the fully-cached case | Agent [x] |
| The layout gate still holds | `bash scripts/check_container_layout.sh`, exit 0 | Agent [x] |
| The lint umbrella passes | `bash scripts/lint.sh`, exit 0, 8 gates clean | Agent [x] |
| The shipped suite passes | `bash scripts/run_tests.sh`, 1200 passed, 0 failed | Agent [x] |
| The probe's rows are measurement, not assertion | the operator's host run, still outstanding | Operator |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A tier's state rests only on steps that carry a build-instruction label | the `[internal]` load steps and the closing export step print `DONE` on a fully cached build, so counting every `DONE` line would report every tier as rerun | `scripts/build_probe.sh`, `tier_step_states` |
| The `content` probe row perturbs with a `LABEL` instruction rather than a comment | docker strips comments, so a comment append leaves every tier fully cached and the row proves nothing | `scripts/build_probe.sh`, the perturbation table |
| `image_label` goes with the skip that read it; `image_digest` stays | the digest is still read by compose generation, the dry-run record and the probe's report | `src/build/image.sh` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The `test_build_inspects_images` case asserted the `docker image inspect` the skip decision made, so its subject left with the mechanism | defect | the case would have failed after the removal; its coverage of preflight's own inspection survives in `test_preflight_*` | closed here, case removed |
| The probe's `mtime` and `restore` rows change meaning under the new reading, and now expect no tier to run a step | design | a byte-identical touch is a full cache hit, so the old expected set would have failed against a correct cache | closed here, expectations updated and reasoned rather than measured |
| The probe's new expectations are reasoned, not measured, because the agent's container carries no Docker | process | the operator's host run is the first real reading of the reworked rows | the row `The host build probe is re-run against the new shape` |
| `opencode-go` answers `401 api_key_expired`, so the role line naming it cannot dispatch, and the OpenCode free tier does not answer either | environment | every dispatch in this run that named a recommended model fell back to the pi backend's `deepseek/deepseek-flash` | `devlog/AGENT_FEEDBACK.md` candidate, not yet filed |
| An interrupted foreground dispatch leaves the tree clean and the worker's log complete, so a re-run is the recovery and nothing is lost | process | the first attempt of this unit was aborted; the tree carried no trace of it, and a parallel commit line reset the tree in between | recorded here; no record change |

## Completed

| File | Change |
|---|---|
| `scripts/build.sh` | `_build_key` and `build_if_missing` removed; every tier goes through `build_image`, and the tier comment states the layer-cache rule |
| `src/build/image.sh` | `image_label` removed with its comment; `image_digest` stays |
| `scripts/build_probe.sh` | the observation reads `CACHED` and `DONE` per tier; the rows, the report fields and the verdict follow, and the perturbation table gains a `LABEL` row |
| `scripts/start_agent.sh` | the `--refresh` comment no longer describes a skipped base tier |
| `tests/stubs/docker` | the base-build-key label branch removed |
| `tests/test_trace_build.sh` | the skip-only cases and key machinery removed; the default-target count is three tiers per provider |
| `tests/test_build_probe.sh` | fixtures and expectations rewritten to the cached/un-cached reading, plus the fully cached case |
