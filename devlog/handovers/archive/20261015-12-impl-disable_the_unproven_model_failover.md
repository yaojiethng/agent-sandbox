---
date: 2026-10-15
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Implementation
status: Closed
---

# Handover - Disable the unproven model-failover extension

## Objective

Make the `model-failover` extension inert by default, behind a flag, because its value is unmeasured. The settled design record ordered this before any rebuild or A/B.

## Scope

The extension factory guard, the flag predicate, the extension's design record and changelog, and the suite that exercises the factory.

Out of scope: the runner seam and the provider decision, which are the other rows of M3.6.1.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The extension is inert when the flag is unset | `bash tests/test_model_failover.sh`, the `G3` case asserts zero registrations, zero handlers, zero entries | Accepted |
| The flag is off unless it names a truthy value | the same suite, the predicate case | Accepted |
| The enabled path still works | the same suite, 116 tests pass | Accepted |
| The invariant is recorded in its structure | `README.md` guard invariant `G3` | Accepted |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| An environment flag rather than a settings disable | pi has no per-extension disable; `--no-extensions` disables every extension, so it cannot isolate one for the A/B | this record; the extension `README.md` |
| Default off | no session carries a `model-failover/outcome` entry and the only shipped chain declares one route, so the feature has never run | this record; the settled design record |
| The flag is a pure predicate over the environment | a pure function is testable without a process, and the factory reads it once | `index.ts`, `failoverEnabled` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The extension is disabled in the repository, but the container's installed copy at `$AGENT_HOME/agent/extensions/model-failover/` is a separate copy. It gains the guard on the next image build or config sync. | environment | noted here; no action needed for the row |
| `opencode` is not on `PATH` in the reasoning container; it resolves at `$AGENT_HOME/opencode/node_modules/.bin/opencode` (v1.19.1). The runner seam must resolve the binary rather than assume `PATH`. | environment, gates M3.6.1 | the runner-seam row |

## Completed

| File | Change |
|---|---|
| [`index.ts`](../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/index.ts) | new: `failoverEnabled` predicate and a factory guard that returns before any work |
| [`README.md`](../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/README.md) | the config surface names the flag; guard invariant `G3` |
| [`CHANGELOG.md`](../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/CHANGELOG.md) | `0.3.0` records the inert default |
| [`tests/test_model_failover.sh`](../../../tests/test_model_failover.sh) | the node suite runs with the flag set |
| [`wire.test.ts`](../../../tests/extensions/pi/model-failover/wire.test.ts) | the predicate case and the inert-factory case |
| [`devlog/roadmap.md`](../../roadmap.md) | the disable row is complete |
