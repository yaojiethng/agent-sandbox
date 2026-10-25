---
date: 2026-10-22
milestone: M3.6.3 - Route and decide
type: Implementation
status: Closed
---

# Handover - A gate holds every launch site behind the library

## Objective

Make the launch-site rule a gate rather than a reading, and move the remaining launch sites behind the one entrypoint, so a call site added later cannot reopen the door the run closed.

## Scope

The roadmap row **The launch-site sweep**. The gate and its test, the umbrella wiring, the eval harness and the OpenCode worker's migration onto the entrypoint, and the prompt and draft carriers that named the retired launcher.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every launcher call is behind the library, the entrypoint or the reviewer's fixed run | `bash scripts/check_launch_sites.sh` prints `launch sites: clean; every launcher call is behind the library` | Agent [x] |
| The gate fails a call site that names a launcher's own flags | `bash tests/test_check_launch_sites.sh` prints `4 passed, 0 failed` | Agent [x] |
| The eval harness takes its command from the entrypoint | `bash tests/test_eval_harness.sh` prints `12 passed, 0 failed` | Agent [x] |
| The OpenCode worker calls the entrypoint and names no launcher flag | read [`SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/SKILL.md) | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` prints `Lint: clean in 7s across 12 gates` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The allowlist is the mechanism's own surface, not a list of callers | `launch.ts`, the entrypoint and the reviewer's fixed run are the only places a launcher's flags belong | [`check_launch_sites.sh`](../../scripts/check_launch_sites.sh) |
| Markdown is exempt, and so is a test | a document states an invocation as an example and runs nothing; a case asserts the argv a launch site builds | [`check_launch_sites.sh`](../../scripts/check_launch_sites.sh) |
| The reviewer's fixed run is outside dispatch | it pins its assignments and resolves nothing, so it reads no table | [`check_launch_sites.sh`](../../scripts/check_launch_sites.sh) |
| The rule is a gate in the umbrella | two sites were found by reading, which is not a mechanism | [`lint.sh`](../../scripts/lint.sh) |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The gate reports no live site after the migration, so its allowlist is the only exemption left | result | the two sites the run found by reading are now callers of the entrypoint | recorded here |

## Completed

| File | Change |
|---|---|
| [`check_launch_sites.sh`](../../scripts/check_launch_sites.sh) | the gate: a launcher's own flags outside the allowlist fail |
| [`test_check_launch_sites.sh`](../../tests/test_check_launch_sites.sh) | four cases over a fixture root: clean, a migrated site, an inline site, and the Markdown and test exemptions |
| [`lint.sh`](../../scripts/lint.sh) | the twelfth gate joins the umbrella and its header names it |
| [`run_case.sh`](../../workflow/coding-agent/skills/eval/scripts/run_case.sh), [`test_eval_harness.sh`](../../tests/test_eval_harness.sh) | the eval harness calls the entrypoint and composes no provider |
| [`SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/SKILL.md) | the worker carries the instruction and names no launcher flag |
| [`opencode-dispatch/dispatch.sh`](../../src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/dispatch.sh) | deleted; its launcher retired into the entrypoint |
| [`auto.md`](../../.agents/prompts/auto.md), [`close-the-model-bypass-run.md`](../../.agents/drafts/close-the-model-bypass-run.md) | the carriers name the entrypoint |
| [`devlog/roadmap.md`](../roadmap.md) | the row closed |
