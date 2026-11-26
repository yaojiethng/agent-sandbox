---
date: 2026-11-23
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - the resolution and dispatch contract has one declaration

## Objective

The path, identity and handoff rules are stated once in the CLI ADR, and a gate checks the catalogue, the leaf parse specs and the dispatcher against that statement, so the three carriers cannot drift silently.

## Scope

The third slice of the three-way split of the M3.4.2 dispatcher work: carrier consolidation and cleanup. R1 and R2 made the path absolute and the handoff observable; this slice states the contract in one table and gives it a gate. It does not add a runtime behaviour beyond the catalogue comment.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The CLI ADR states the contract once, with an owner and a gate per invariant. | `docs/adr/cli_surface.md` section `## The resolution and dispatch contract` | Agent [x] |
| Every catalogue row that declares `env` uses the identity resolver. | `bash tests/test_resolution_contract.sh` | Agent [x] |
| Every leaf named by an `env` row accepts `--env`. | the same file | Agent [x] |
| The dispatcher forwards `$ENV_FILE` and never `$ENV_REL`. | the same file | Agent [x] |
| The path constructor returns an absolute path. | the same file and `tests/test_env_resolve.sh` | Agent [x] |
| The catalogue comment states the `env` precondition. | `scripts/agent-sandbox.sh` catalog header | Agent [x] |
| The suite and the gates pass. | `bash scripts/run_tests.sh`, `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The contract is a table in the CLI ADR plus a gate, not a generated manifest. | The CLI runs where a manifest reader is absent, and a committed rendering would be a second source that drifts. The table is the one statement; the gate reads the real carriers. | This table; `cli_surface.md` contract section |
| The gate reads the catalogue through the dispatcher's own `CLI_CATALOG`, not a copy. | The catalogue is the declaration; a test copy would be the second declaration this slice exists to remove. | This table; `tests/test_resolution_contract.sh` |

## Decisions pending

None.

## Findings

None.

## Completed

| File | Change |
|---|---|
| [`docs/adr/cli_surface.md`](../../../docs/adr/cli_surface.md) | The contract table C1-C7, with owner and gate per row. |
| [`tests/test_resolution_contract.sh`](../../../tests/test_resolution_contract.sh) | Four cases over the catalogue, leaf specs, dispatcher and path constructor. |
| [`tests/test_env_resolve.sh`](../../../tests/test_env_resolve.sh) | The relative `--env` bootstrap case that gates C7. |
| [`scripts/agent-sandbox.sh`](../../../scripts/agent-sandbox.sh) | The catalogue header states that `env` requires the identity resolver. |
| [`devlog/roadmap.md`](../../roadmap.md) | The R3 row is added and closed. |
