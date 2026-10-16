---
date: 2026-10-15
milestone: T12 - Pi Dependency and Extension Upkeep
type: Workflow
status: Closed
---

# Handover - model-refresh follows pi 1.3.0's opencode-go endpoints

## Objective

Move `model-refresh`'s declared `opencode-go` endpoints onto the ones pi 1.3.0 bakes, and re-walk the extension's assumption table against 1.3.0.

## Scope

The `model-refresh` upkeep under T12, opened by the pi 1.3.0 bump. This iteration owns `sources.json`, the two node tests that stub the old base URL, the two knowledge scripts that name the gateway, `models.json`'s `opencode-go` overrides, and `README.md`'s assumption table and `minimax-m2.7` note. The pin bump and its changelog record are the separate `chore:` commit `90deeaba`, committed before this iteration.

Two open T12 rows are ruled out of scope: the `task-queue` bump-semantics record, and the compat checker not running in `make lint`. Neither is touched.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The declared endpoints are pi 1.3.0's | `sources.json` matches the 1.3.0 bundle's `opencode-go` bases (`inference/go` and `inference/go/v1`) | Agent [x] |
| The new live listing endpoint answers | a `curl` with `OPENCODE_API_KEY` returns 200 and 37 models from `https://opencode.ai/inference/go/v1/models` | Agent [x] |
| The assumption table is re-walked against 1.3.0 | `README.md` `## Verified assumptions` carries `2026-10-15`, with A7, A8 and A10 marked `MOVED` | Agent [x] |
| The model-refresh suite is green | `bash tests/test_model_refresh.sh` reports 250 tests passing | Agent [x] |
| The lint gate is clean | `bash scripts/lint.sh` reports clean across 8 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Move the declared endpoints to `inference/go` rather than keep `zen/go` | pi 1.3.0 bakes `opencode.ai/inference/go` and `.../inference/go/v1`; the operator prefers the endpoint pi uses, and the old URLs are no longer what pi reaches | this record; `sources.json` |
| Remove the dead `opencode-go/deepseek-v4-flash` override | neither the installed 1.2.0 nor the 1.3.0 candidate bakes that id, so pi never applied the override, and `config.test.ts` exists to reject a key that names no baked model | this record; `models.json` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| A8 moved back: the Zen free tier re-enforces its client check. On 1.3.0 every client-header variant answers 403 `FreeTierError`, and a bogus key returns the same 403 rather than 401, so the 2026-10-03 "the gateway no longer enforces the check" note is false again. Triaged to: `README.md` A8. | technical | current iteration |
| A10 moved: the baked `opencode-go` catalog no longer carries `space-bunny-free` (29 chat ids, only `space-bunny`), and `space-bunny-free` now sits in the baked `opencode` catalog. Triaged to: `README.md` A10. | technical | current iteration |
| A7: the per-model split of `reasoning_effort: "none"` acceptance still holds, but its `space-bunny-free` 400/400 evidence no longer reproduces, because the model left the baked Go catalog and Zen answers 403. Re-probed onto models still in the catalog. Triaged to: `README.md` A7. | technical | current iteration |
| `models.json` named `opencode-go/deepseek-v4-flash`, which no pi 1.2.0 or 1.3.0 bakes, so `config.test.ts` was red before this iteration. The dead key is removed. Triaged to: current iteration. | technical | current iteration |
| `tests/knowledge/knowledge_pi_config_cycle.sh` fails one case: `enabledModels[0]` is `failover/*`, not the configured default `deepseek/deepseek-flash`. Pre-existing and unrelated to the bump; flagged, not fixed. Triaged to: operator decision on filing. | obstacle | out of scope |

## Completed

| File | Change |
|---|---|
| [`sources.json`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/sources.json) | `endpoint` and the three `baseUrls` move to `opencode.ai/inference/go` |
| [`README.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md) | the assumption table is re-walked against 1.3.0 (A7, A8, A10 moved; A2 and A11 corrected); the `minimax-m2.7` probe commands name the new path |
| [`CHANGELOG.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/CHANGELOG.md) | the `0.7.0` entry records the endpoint move and the walk |
| [`models.json`](../../src/reasoning/providers/pi/config/agent/models.json) | the dead `opencode-go/deepseek-v4-flash` override is removed |
| [`composition.test.ts`](../../tests/extensions/pi/model-refresh/composition.test.ts) | `V1_BASE` moves to `inference/go/v1` |
| [`wire.test.ts`](../../tests/extensions/pi/model-refresh/wire.test.ts) | the stubbed `baseUrl` moves to `inference/go/v1` |
| [`knowledge_opencode_gateway_matrix.sh`](../../tests/extensions/pi/model-refresh/knowledge/knowledge_opencode_gateway_matrix.sh) | the product comment names the new endpoints |
| [`knowledge_opencode_go_chain_health.sh`](../../tests/extensions/pi/model-failover/knowledge/knowledge_opencode_go_chain_health.sh) | the probe POST moves to `inference/go/v1/chat/completions` |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the T12 `pi bump to 1.3.0` row, marked `[x]` |
| [`devlog/handovers/20261015-09-workflow-model_refresh_follows_pi_1_3_0_endpoints.md`](20261015-09-workflow-model_refresh_follows_pi_1_3_0_endpoints.md) | this record |
