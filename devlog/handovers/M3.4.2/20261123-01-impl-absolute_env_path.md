---
date: 2026-11-23
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - the record path is absolute

## Objective

Every accepted `--env` input resolves to an absolute `ENV_FILE`, so a caller and the process it hands the path to name the same record.

## Scope

The first slice of the three-way split of the M3.4.2 dispatcher work: resolver normalization only. The path contract lands in [`cli_surface.md`](../../../docs/adr/cli_surface.md) R12; the dispatcher change and the contract gate follow in `20261123-02` and `20261123-03`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A relative `--env` under a relative sandbox resolves to an absolute path. | `bash tests/test_env_resolve.sh` case `test_default_env_file_returns_an_absolute_path` | Agent [x] |
| The CWD fallback and an absolute input both stay absolute. | the same case | Agent [x] |
| `env_resolve_identity` exports the absolute path as `ENV_FILE`. | the same file, case `test_resolve_exports_an_absolute_env_file` | Agent [x] |
| The path contract is stated once in the CLI ADR. | `docs/adr/cli_surface.md` R12 and its 2026-11-23 entry | Agent [x] |
| The path paragraph in `resolution_model.md` points at R12 instead of restating it. | read `docs/adr/resolution_model.md` around the `--env` paragraph | Agent [x] |
| The suite and the gates pass. | `bash scripts/run_tests.sh`, `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The resolver owns path normalization, not the dispatcher. | Every caller of `env_resolve_identity` gets the same guarantee; the dispatcher stays a route table and does not become a second path owner. | This table; `cli_surface.md` R12 |
| `readlink -f` canonicalizes when it can; an unresolvable path is anchored at the invocation CWD. | A specified path may be absent, and its absence is reported by its reader; path construction must still return an absolute value. | This table; `src/libs/env_resolve.sh` |

## Decisions pending

None.

## Findings

| # | Finding | Triaged to |
|---|---|---|
| F1 | The vocabulary gate's `thing` ban matched the word "things" in the `seam` definition, so the gate blocked the tree before this iteration changed anything. | Applied here: the definition now says "two parts meet". |

## Completed

| File | Change |
|---|---|
| [`src/libs/env_resolve.sh`](../../../src/libs/env_resolve.sh) | `_env_abs_path` added; `default_env_file` returns an absolute path for every branch. |
| [`tests/test_env_resolve.sh`](../../../tests/test_env_resolve.sh) | Two cases: absolute path for relative inputs, and an absolute exported `ENV_FILE`. |
| [`docs/adr/cli_surface.md`](../../../docs/adr/cli_surface.md) | R12 and the 2026-11-23 entry. |
| [`docs/adr/resolution_model.md`](../../../docs/adr/resolution_model.md) | The path paragraph points at R12 and keeps only the historical precedence. |
| [`docs/reference/terminology.md`](../../../docs/reference/terminology.md) | The `seam` definition says "two parts meet", so the vocabulary gate no longer trips on its own definition. |
| [`devlog/roadmap.md`](../../roadmap.md) | The R1 row is added and closed. |
