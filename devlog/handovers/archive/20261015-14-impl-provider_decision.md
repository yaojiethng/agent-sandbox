---
date: 2026-10-15
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Implementation
status: Closed
---

# Handover - The provider decision

## Objective

Decide whether OpenCode stops being a base-level provider, land the decision, and give the runner seam a reproducible OpenCode binary in the pi image.

## Scope

The architecture decision record, the pi base image, the seam's binary resolution, and the roadmap row.

Out of scope: the launch-site sweep and the measurement, which are M3.6.3 and M3.6.2.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The decision is recorded | [`opencode_dispatch_backend.md`](../../../docs/adr/opencode_dispatch_backend.md) | Accepted |
| The pi image carries the OpenCode CLI | `src/reasoning/providers/pi/base.dockerfile` installs `opencode-ai@1.19.1`, the version `npm view opencode-ai version` returns and the installed copy reports | Accepted |
| The seam resolves the binary from `PATH` with a fallback | `bash tests/test_dispatch.sh`, 14 cases; the resolution order is override, `PATH`, agent home | Accepted |
| The container layout stays consistent | `bash scripts/lint.sh`, the container-layout gate is clean | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| OpenCode stays a base-level provider | a dispatch backend and a session runtime are different jobs; removing the runtime needs evidence it is unused | the ADR |
| The pi image installs `opencode-ai@1.19.1` | a fresh container would otherwise dispatch nothing, and the failure would read as a missing binary rather than a missing declaration | the ADR; `base.dockerfile` |
| The seam resolves the binary as override, `PATH`, then agent home | the override keeps the seam testable, and the fallback keeps an image that predates the install working | the lib; the ADR |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The image build is not run in this session, so the install lands as a declaration. The measurement that justifies it, the `403 FreeTierError`, is recorded in the ADR. | environment, inference about the build | the operator verifies on the next image build |
| `npm view opencode-ai version` returns `1.19.1`, equal to the installed copy, so the pin matches the measured CLI. | measurement | the ADR pin |

## Completed

| File | Change |
|---|---|
| [`docs/adr/opencode_dispatch_backend.md`](../../../docs/adr/opencode_dispatch_backend.md) | new: the provider decision |
| [`src/reasoning/providers/pi/base.dockerfile`](../../../src/reasoning/providers/pi/base.dockerfile) | installs `opencode-ai@1.19.1` |
| [`src/libs/dispatch.sh`](../../../src/libs/dispatch.sh) | the binary resolves from `PATH` before the agent-home fallback |
| [`devlog/roadmap.md`](../../roadmap.md) | the provider-decision row is complete |
