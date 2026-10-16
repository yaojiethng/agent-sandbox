---
date: 2026-10-16
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Implementation
status: Closed
---

# Handover - Test the CLI's run path

## Objective

Cover `scripts/dispatch.sh --run`, the one path of the runner seam that no case exercised. The path builds the command and executes it with `bash -c`, so an untested execution path is an untested runner.

## Scope

One case in `tests/test_dispatch.sh`, plus its coverage line in that file's header. `scripts/dispatch.sh` is unchanged; the case exposed no defect in it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The `--run` path executes the built command | `bash tests/test_dispatch.sh`, `test_cli_run_executes_built_command` | Agent [x] |
| The argv the stub received is asserted | the same case, `assert_eq "$ARGV" "$EXPECTED"` | Agent [x] |
| The brief is read at run time | the same case, `assert_contains "$ARGV" "the run brief"` | Agent [x] |
| The stub's exit code propagates | the same case, `assert_rc 7 "$RC"` | Agent [x] |
| The case fails on a regression | two mutations of `scripts/dispatch.sh` in a throwaway copy, print-only instead of exec, and a swallowed status; the case failed both | Agent [x] |
| Gates clean | shellcheck clean across 176 files | Agent [x] |
| The suite is green | `bash tests/test_dispatch.sh`, 20 passed, 0 failed | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The stub journals its argv one argument per line | a joined string cannot separate one argument that holds a space from two arguments | [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The case does not catch a build-time inlining of the brief into the command string, because `dispatch_command`'s use of `"$(cat <brief>)"` is already asserted by the two backend cases. The CLI case is not the carrier for that property, so the gap is covered elsewhere rather than open. | coverage note | none |

## Completed

| File | Change |
|---|---|
| [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) | `test_cli_run_executes_built_command`, and the header coverage line |
| [`devlog/roadmap.md`](../roadmap.md) | the run-path row is complete |
