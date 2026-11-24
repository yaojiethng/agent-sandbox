---
date: 2026-11-24
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - the identity paths have one fixed form

## Objective

`PROJECT_DIR`, `SANDBOX_DIR` and `ENV_FILE` leave the resolver absolute and canonical, one helper owns the normalization, and every leaf and label sees one spelling of a path.

## Scope

The third open M3.4.2 row. The iteration adds one path normalizer, applies it in the resolver to explicit flags and record values, and makes the existing sandbox and onboard checks callers of it. It changes no record format, no session-identity algorithm and no leaf flag. The timestamp row remains open, and the `env_resolve_identity` name/dir duplication stays a note.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `path_abs` expands `~`, resolves a symlink or trailing-slash spelling, and anchors a missing relative path at the invocation CWD. | `bash tests/test_common_lib.sh`, cases `test_sandbox_dir_canon_expands_tilde`, `test_sandbox_dir_canon_converges_spellings` and `test_path_abs_anchors_a_missing_relative_path` | Agent [x] |
| The resolver normalizes explicit `PROJECT_DIR` and `SANDBOX_DIR` spellings, and `ENV_FILE` stays absolute. | `bash tests/test_env_resolve.sh`, cases `test_resolve_normalizes_explicit_paths`, `test_resolve_normalizes_tilde_paths` and `test_resolve_exports_an_absolute_env_file` | Agent [x] |
| The resolver normalizes record-supplied `PROJECT_DIR` and `SANDBOX_DIR` spellings. | `bash tests/test_env_resolve.sh`, case `test_resolve_normalizes_record_paths` | Agent [x] |
| `sandbox_dir_canon` still rejects an unresolvable sandbox, and onboard still rejects a relative sandbox that does not resolve while writing canonical values. | `bash tests/test_common_lib.sh`, case `test_sandbox_dir_canon_rejects_unresolvable`; `bash tests/test_onboard.sh`, case `test_onboard_rejects_unresolvable_relative_sandbox` | Agent [x] |
| The resolution ADR and the two reference documents state the path rule and the helper as built. | `rg -n -e 'path_abs' -e 'one fixed form' docs/adr/resolution_model.md docs/reference/sandbox_identity.md docs/reference/execution_model.md`; the three documents read against the diff | Agent [x] |
| Every decision this iteration records is realized in the files. | the `## Decisions` table read against `git diff` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `path_abs` and its strict half `path_canon` in `src/libs/common.sh` are the one path rule. | The tree had `_env_abs_path`, `sandbox_dir_canon`, onboard's `realpath` and per-entrypoint canonicalization. One rule makes `~`, symlink, trailing-slash and missing-parent handling one rule. | This table; `docs/adr/resolution_model.md` entry 2026-11-24 |
| The resolver normalizes `PROJECT_DIR`, `SANDBOX_DIR` and `ENV_FILE` for both explicit flags and record values. | A path that crosses a process or label boundary cannot depend on the consumer's CWD or spelling. The resolver is the one site that sees every input level. | This table; `src/libs/env_resolve.sh` |
| `path_abs` normalizes without requiring the path to exist. | `SANDBOX_DIR` may not exist at onboard, and a specified `--env` path may be absent; existence is the reader's or the creation-time guard's decision, not path construction's. | This table; `src/libs/common.sh` |
| `sandbox_dir_canon` calls `path_canon` but still requires a resolvable directory. | The entrypoints need the early failure for a misspelt sandbox; normalization and existence are separate decisions. | This table; `src/libs/common.sh` |
| `onboard` uses `path_abs` and keeps its relative-unresolvable guard. | Onboard creates the sandbox, so a relative path whose parent does not exist is a creation-time error; it writes the canonical value only after that guard passes. | This table; `scripts/onboard.sh` |
| The session-identity algorithm is unchanged; it receives a canonical `SANDBOX_DIR`. | The row fixes the input spelling, not the hash or its factors. | This table; `docs/adr/session_identifier.md` unchanged |

## Decisions pending

None.

## Findings

| # | Finding | Impact | Triaged to |
|---|---|---|---|
| F1 | `sandbox_dir_canon` switched to `path_abs` plus an existence test, so it rejected `/tmp/sandbox` and `/d`, whose parent exists but whose final component does not; `test_checkpoint` and `test_resume` failed. | The old canonicalizer accepted a readlink-resolvable path without requiring the leaf. | Completed: `path_canon` keeps the strict readlink form, `path_abs` keeps the CWD anchor, and the suite is green. |

## Completed

| File | Change |
|---|---|
| [`src/libs/common.sh`](../../../src/libs/common.sh) | `path_canon` is the strict readlink normalizer, `path_abs` adds the CWD anchor, and `sandbox_dir_canon` calls the strict form. |
| [`src/libs/env_resolve.sh`](../../../src/libs/env_resolve.sh) | Explicit and record `PROJECT_DIR` and `SANDBOX_DIR` pass through `path_abs`; `default_env_file` uses it for `ENV_FILE`. |
| [`scripts/onboard.sh`](../../../scripts/onboard.sh) | `resolve_and_validate` normalizes through `path_abs` and keeps the relative-unresolvable guard. |
| [`tests/test_common_lib.sh`](../../../tests/test_common_lib.sh) | Pins the helper's missing-relative anchor alongside the existing sandbox canonicalizer cases. |
| [`tests/test_env_resolve.sh`](../../../tests/test_env_resolve.sh) | Pins explicit, record and `~` spellings for both identity paths. |
| [`docs/adr/resolution_model.md`](../../../docs/adr/resolution_model.md) | Entry 2026-11-24 states the one path rule, its existence split and the rejected alternatives. |
| [`docs/reference/sandbox_identity.md`](../../../docs/reference/sandbox_identity.md) | The canonical sandbox value and the resolvable-directory check name the new helpers. |
| [`docs/reference/execution_model.md`](../../../docs/reference/execution_model.md) | Both identity paths are absolute, and the resolver normalizes explicit and record values. |
| [`devlog/roadmap.md`](../../roadmap.md) | The path row closes and the decision is recorded. |
