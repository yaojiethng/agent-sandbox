# Agent Handover

**Date:** 2026-09-26
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Remove the legacy `TARGET` build variable and its wiring after the `--targets=` fix. The operator direction (2026-09-26): keep only the new flag and make variable, wired consistently everywhere. This supersedes the alias decision in handover `20260926-03`, which kept `TARGET` as a legacy alias to match the then-current tool-interface text.

## Root cause

`scripts/build.sh` reads `--targets=` only, and `scripts/agent-sandbox.sh` states that `--target` for build "is deprecated and will error". A legacy alias in the Make layer contradicts that stance: it keeps the deprecated name alive in the operator surface. Worse, an undeclared variable is silent in make -- a stale `make build TARGET=<p>` would build all images without error. The alias also forced the translator and its docs to carry a second spelling.

## Scope

The build-target surface only: `scripts/templates/Makefile.template`, its contract tests, the CLI usage hint, and the tool-interface text. The `confirm` command keeps `--target=<branch>` (TARGET_BRANCH): that flag selects the merge target branch and is unrelated to build target selection.

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| `make build TARGETS=<comma-list>` reaches the CLI as `--targets=<list>` | template expansion via `make -n` simulation | Agent [x] - `--targets=pi,sandbox` |
| `make build` default emits `--targets=all` | same | Agent [x] - `--targets=all` |
| A stray `make build TARGET=<p>` refuses loudly, not silently build-all | template guard | Agent [x] - `TARGET is not a Make variable... TARGETS` error |
| No `--target=` or legacy `TARGET` remains in the build surface | repo-wide grep | Agent [x] - zero hits outside `confirm`/TARGET_BRANCH and the guard test's own strings |
| Template contract tests pin the TARGETS-only contract | `tests/test_makefile_template.sh` | Agent [x] - 11 units, 0 failed |
| Suite green | `bash scripts/run_tests.sh` | Agent [x] - 990 tests, 0 failed |
| Lint clean | `bash scripts/lint.sh` | Agent [x] - 3 gates, 0 findings |
| Roadmap write-back | `devlog/roadmap.md` | none worked this iteration - operator-directed cleanup with no roadmap row |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/templates/Makefile.template`](../../scripts/templates/Makefile.template) | the make surface that still carried the legacy alias |
| [`tests/test_makefile_template.sh`](../../tests/test_makefile_template.sh) | pins the TARGETS-only contract and the loud-refusal guard |
| [`scripts/build.sh`](../../scripts/build.sh) | usage hint still named the legacy variable |
| [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | promised the legacy alias the CLI rejects |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Remove the alias entirely; do not keep a compatibility spelling | the CLI's own stance is "deprecated and will error"; one name on the make surface removes the drift class the operator hit twice (TARGET and TARGETS). | this handover |
| Refuse a stray `TARGET=` loudly instead of deleting the declaration silently | make ignores undeclared variable overrides; without a guard a stale `TARGET=` would silently build all. The template already refuses CHANNEL, STALE_ONLY, and NEW_BRANCH the same way. | this handover |
| Rename the internal translator `TARGET_FLAG` to `TARGETS_FLAG` | the translator is the wiring for this flag; a name echoing the retired flag invites the drift back. | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The tool-interface text promised a legacy alias the CLI rejects, and the 03 fix implemented that promise; the operator's review asked for a single spelling instead | contract drift | fixed here; supersedes the 03 alias decision |

## Completed

| File | Change |
|---|---|
| `scripts/templates/Makefile.template` | `TARGET ?=` removed; `TARGET_FLAG` renamed `TARGETS_FLAG` and emits `--targets=$(if $(TARGETS),$(TARGETS),all)`; comment block and help text carry only `TARGETS`; a guard refuses a stray `TARGET=` with a `TARGETS` hint |
| `scripts/build.sh` | usage hint drops the legacy note |
| `tests/test_makefile_template.sh` | accepted list drops `TARGET`; spec and guard use `TARGETS_FLAG`; `test_build_target_flag_is_targets_only` asserts the flag spelling, the absent `TARGET ?=`, and the loud-refusal guard |
| `tests/test_dispatch.sh` | the confirm-hint explanatory comments name `TARGETS` |
| `docs/architecture/tool_interface.md` | legacy-alias sentence removed |
| `devlog/AGENT_FEEDBACK.md` | the 2026-09-26 `[O]` entry's mitigation updated to the final state |
| `devlog/handovers/20260926-03-fix-build_targets_flag.md` | closed record, unchanged; the alias decision it recorded is superseded here |

## Deferred items

| Item | Reason |
|---|---|
| none | |
