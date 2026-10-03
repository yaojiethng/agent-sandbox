# Agent Handover

**Date:** 2026-09-26
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Fix `make build`: every invocation fails with `Unknown argument: --target=...`. The generated sandbox Makefile passes `--target=`, but the `agent-sandbox build` CLI rejects that flag and reads `--targets=`. Reported by the operator against `make build TARGET=pi,sandbox`, `make build TARGETS=pi,sandbox`, and plain `make build` (2026-09-26).

## Root cause

The CLI renamed the build flag to `--targets=` when flag parsing centralized in `src/libs/cli.sh` (`b5d455a`); `agent-sandbox.sh` states `--target (singular) is deprecated and will error`, and `scripts/build.sh` parses `--targets=BUILD_TARGETS` only. The per-sandbox `scripts/templates/Makefile.template` still translates the build target wholly through `TARGET_FLAG = --target=$(if $(TARGET),$(TARGET),all)`. Because `parse_args` rejects unknown arguments, `make build` always fails -- with `REBUILD=1` and with no options at all -- not just with `TARGET`. The default path (`--target=all`) fails identically.

A second defect: `docs/architecture/tool_interface.md` documents the make variable as `TARGETS` (plural, primary) with `TARGET` as a legacy alias, but the template declares and reads only `TARGET`. The operator's `make build TARGETS=pi,sandbox` therefore produced `--target=all` (the fallback), silently ignoring the value.

## Scope

`scripts/templates/Makefile.template` (the flag translator, the variable declaration, the comment and help blocks), the same surface in the CLI usage hint and the operator docs, the two provider quickstarts, and the template contract tests. No change to the CLI: `--targets=` stays canonical.

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| `make build` emits `--targets=all` (default) | template expansion via `make -n` against a scratch sandbox | Agent [x] - `--targets=all --env=...`, no `--target=` |
| `TARGETS=<comma-list>` reaches the CLI as `--targets=<comma-list>` | `make -n build TARGETS=pi,sandbox` | Agent [x] - `--targets=pi,sandbox` |
| Legacy `TARGET=<p>` still works as an alias | `make -n build TARGET=pi` | Agent [x] - `--targets=pi` |
| `REBUILD=1` still passes `--rebuild` | `make -n build REBUILD=1` | Agent [x] |
| Template contract tests pin the `--targets=` spelling (regression guard) | `tests/test_makefile_template.sh` | Agent [x] - 12 units, 0 failed |
| Suite green | `bash scripts/run_tests.sh` | Agent [x] - 805 units, 0 failed |
| Lint clean | `bash scripts/lint.sh` | Agent [x] - 3 gates, 0 findings |
| Roadmap write-back | `devlog/roadmap.md` | none worked this iteration - standalone operator-reported fix with no roadmap row |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/templates/Makefile.template`](../../scripts/templates/Makefile.template) | the per-sandbox shim between the make variable and the CLI flag; the sole source of the broken `--target=` |
| [`scripts/build.sh`](../../scripts/build.sh) | its usage line presents the make invocation to direct CLI callers |
| [`tests/test_makefile_template.sh`](../../tests/test_makefile_template.sh) | contract tests for the template; regression guard added |
| [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | already documents the `TARGETS`/`TARGET` contract; unchanged, now implemented |
| [`docs/development/bash-coding-conventions.md`](../../docs/development/bash-coding-conventions.md) | stale dispatch example named the retired flag |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Fix the template, not the CLI | `agent-sandbox.sh` and `scripts/build.sh` deliberately deprecate `--target` for build and reject it via `parse_args`; the dispatch and trace tests already pin `--targets=`. Re-adding `--target` to the CLI would resurrect a deprecated surface. | this handover |
| Honor both `TARGETS` (primary) and `TARGET` (legacy alias) in the template | `tool_interface.md` documents exactly this contract; the operator tried both spellings. When both are set, `TARGETS` wins. | this handover |
| Regression guard lives in the template contract test | the drift class is "a CLI flag rename does not reach the generated-sandbox shim"; the guard asserts the translator emits `--targets=` and never `--target=`. `agent-sandbox.sh` already carries the deprecation note. | `tests/test_makefile_template.sh` |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The CLI renamed the build flag to `--targets=` (flag parsing centralized, commit `b5d455a`) and the generated-sandbox template was never updated; every `make build` path failed, and because `parse_args` rejects unknown arguments, the failure was loud -- the default invocation included | regression | fixed here |
| The template read only `TARGET` while `tool_interface.md` documented `TARGETS` as primary; the operator's `TARGETS=` attempt failed silently (fallback to `all`) before hitting the flag rejection | contract drift | fixed here |

## Completed

| File | Change |
|---|---|
| `scripts/templates/Makefile.template` | `TARGETS ?=` declared; `TARGET_FLAG` now emits `--targets=<TARGETS-or-TARGET-or-all>`; comment block and help text name `TARGETS` primary, `TARGET` legacy |
| `scripts/build.sh` | usage hint updated to `make build [TARGETS=<p>]` with the legacy note |
| `docs/development/bash-coding-conventions.md` | dispatch example spells `--targets="$TARGETS"` |
| `docs/development/quickstart.md`, `src/reasoning/providers/hermes/quickstart.md`, `src/reasoning/providers/opencode/quickstart.md` | `make build TARGETS=<provider>` |
| `tests/test_makefile_template.sh` | `TARGETS` added to the accepted-variable list; `test_build_target_flag_spells_targets` pins the `--targets=` spelling |
| `devlog/AGENT_FEEDBACK.md` | `[O] 2026-09-26` entry: a generated-sandbox shim must follow a CLI flag rename |

## Deferred items

| Item | Reason |
|---|---|
| none | |
