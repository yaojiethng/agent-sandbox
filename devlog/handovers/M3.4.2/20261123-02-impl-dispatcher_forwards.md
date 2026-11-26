---
date: 2026-11-23
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - the dispatcher's record path and leading argument are observed

## Objective

A dispatch test asserts the leaf argv for a record-only invocation: the record the resolver reads through a relative `--env`, the resolved identity values, the row's leading argument, the normalized absolute record path, and the passthrough arguments. The mutation catalogue proves the case is sensitive to each forward.

## Scope

The M3.4.2 row **The dispatcher's two forwards are unpinned**, filed by handover [`20261122-09`](20261122-09-impl-catalog.md), extended by the operator's decision that the leaf receives the resolver's normalized absolute `$ENV_FILE`. The test builds a stub sandbox and a record, then runs the real dispatcher with a fixture repository root whose `start` leaf records its argv. The resolve-before-forward order landed at `8f421b4c`. The mutation run exposed F1, whose fix is in scope because the forward could not otherwise be observed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A record-only invocation with a relative `--env` starts the row's leaf with the resolved identity values, the leading argument first, the absolute record path, and the passthrough arguments. | `bash tests/test_agent_cli_dispatch.sh` case `test_dispatch_forwards_the_record_and_leading_argument` | Agent [x] |
| Dropping the resolver's env ref, dropping the leading argument, or forwarding the raw path each makes the case fail. | mutation rows D11-D13, filtered to `scripts/agent-sandbox.sh` | Agent [x] |
| An explicit empty env ref does not fall back to the global `ENV_REL`. | `bash tests/test_env_resolve.sh` case `test_explicit_empty_env_ref_does_not_fall_back` | Agent [x] |
| The mutation rows are proven and none survives. | `MUTATIONS_CATALOG=.scratchpad/dispatcher-mutations.jsonl MUTATIONS_REQUIRED_SUBJECTS='^scripts/agent-sandbox.sh$' bash scripts/mutations_run.sh` | Agent [x] |
| The suite and the gates pass. | `bash scripts/run_tests.sh`, `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The dispatcher forwards the resolver's normalized `$ENV_FILE`, not the raw `$ENV_REL`. | The leaf receives the same absolute record the resolver read, and the second path resolution at the leaf has nothing left to decide. A relative `--env` can no longer mean a different file at the leaf. | This table; `cli_surface.md` R13 |
| The test runs the real dispatcher and `exec`s a stub leaf in a fixture repository root. | The property is the argv the leaf process receives, so the case crosses the real `exec` boundary. Overriding `exec` in a sourced shell would stop one step short. | This table; `tests/test_agent_cli_dispatch.sh` |
| The case asserts the argv contract; the mutation rows are falsification only. | The test states what the leaf must receive for a record-only invocation, with expected values written from the fixture. A mutation row proves the assertion is not vacuous, but "fails when removed" is not the property. | This table; `tests/mutations/catalog.jsonl` |
| An explicit fourth argument is authoritative even when empty. | The resolver's `${4:-${ENV_REL:-}}` made an explicit empty look omitted, so the dispatcher's forward was shadowed by the same global and the mutation could not bite. | This table; `src/libs/env_resolve.sh` |

## Decisions pending

None.

## Findings

| # | Finding | Triaged to |
|---|---|---|
| F1 | `env_resolve_identity` could not distinguish an omitted env ref from an explicit empty one, so `resolve_identity ... ""` silently fell back to the caller's `ENV_REL`. | Applied here: the fourth argument is authoritative when present; the global fallback is only for an omitted argument. |

## Completed

| File | Change |
|---|---|
| [`scripts/agent-sandbox.sh`](../../../scripts/agent-sandbox.sh) | The `env` field forwards `--env=$ENV_FILE`. |
| [`src/libs/env_resolve.sh`](../../../src/libs/env_resolve.sh) | The fourth argument is read when present; an explicit empty value is no longer treated as omitted. |
| [`tests/test_agent_cli_dispatch.sh`](../../../tests/test_agent_cli_dispatch.sh) | The fixture root, stub leaf, and the argv-contract case. |
| [`tests/test_env_resolve.sh`](../../../tests/test_env_resolve.sh) | The explicit-empty-ref case. |
| [`tests/mutations/catalog.jsonl`](../../../tests/mutations/catalog.jsonl) | D11 lead removed, D12 resolver env dropped, D13 raw path forwarded. |
| [`docs/adr/cli_surface.md`](../../../docs/adr/cli_surface.md) | R13 and its 2026-11-23 entry. |
| [`devlog/roadmap.md`](../../roadmap.md) | The dispatcher row is closed with the normalized-path clause. |
