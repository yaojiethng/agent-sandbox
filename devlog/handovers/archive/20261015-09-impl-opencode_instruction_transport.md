---
date: 2026-10-15
milestone: M3.6 - Cost-Aware Dispatch
type: Implementation
status: Closed
---

# Handover - The OpenCode instruction transport

## Objective

Make the harness's declared skill surfaces and ambient instructions reachable to an OpenCode runtime, by generating an OpenCode config from the container interface manifest.

## Scope

The M3.6 task `The OpenCode instruction transport`, the W0 unit of the run directive [`cost-aware-dispatch-run.md`](../../../.agents/drafts/cost-aware-dispatch-run.md). Dispatched with the `sequential-work` shape: one unit, one fresh subagent on `opencode-go/cat-jam-free`, the primary parked, the return verified against the tree.

Out of scope: prompts as OpenCode commands. A command needs an agent and a model mapping the runner seam owns, recorded as a one-line decision in the test file.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | The generator emits valid JSON naming every skill cell | `bash tests/test_opencode_config.sh` is 4 passed, 0 failed | Accepted |
| 2 | The skill list is derived, not hardcoded | mutation: the derivation made inert fails `test_skills_one_entry_per_skills_cell`, restored byte-identical | Accepted |
| 3 | The Dockerfile sentence names the harness's work | the line names `src/build/container-interface.json` | Accepted |
| 4 | OpenCode reaches a real harness skill | `OPENCODE_CONFIG` set lists 24 skills against 8 without it | Accepted |
| 5 | Lint and suite clean | `bash scripts/lint.sh` clean across 8 gates; `bash scripts/run_tests.sh` 1145 passed | Accepted |

## Decisions

1. **The transport is a generated config, not a shipped one.** `src/build/opencode-config.mjs` reads the manifest, so a cell added there reaches OpenCode with no second declaration.
2. **Prompts are not emitted as OpenCode commands.** A command carries an agent and a model, which is the runner seam's mapping. Recorded in the test file's header.
3. **The generated config carries no `$schema` key.** It is valid without one, and the proof run used it directly.

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| This container has no `opencode` on PATH and `npm install -g` fails on permissions at `/usr/local/lib/node_modules`. A `--prefix` install under `$AGENT_HOME` works, and `/tmp` does not survive between tool calls, so the runtime and the run scratch live under `$AGENT_HOME`. | obstacle, measured | the run's dispatch |
| `opencode run` auto-rejects out-of-tree tool calls without `--auto`. | obstacle, measured | the dispatch line carries `--auto` |

## Completed

| File | Change |
|---|---|
| [`src/build/opencode-config.mjs`](../../../src/build/opencode-config.mjs) | new generator deriving the OpenCode `skills` and `instructions` from the manifest |
| [`tests/test_opencode_config.sh`](../../../tests/test_opencode_config.sh) | new test: valid JSON, one entry per skills cell, the named instructions, and an added cell changing the output |
| [`src/reasoning/providers/opencode/provider.dockerfile`](../../../src/reasoning/providers/opencode/provider.dockerfile) | the transport sentence names the harness's work and the manifest |
| [`devlog/roadmap.md`](../../../devlog/roadmap.md) | the M3.6 transport row closes `[x]` |
| [`devlog/handovers/archive/20261015-09-impl-opencode_instruction_transport.md`](20261015-09-impl-opencode_instruction_transport.md) | this record |
