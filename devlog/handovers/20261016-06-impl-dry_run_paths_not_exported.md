---
date: 2026-10-16
milestone: M3.4.2 - Environment declaration seam
type: Implementation
status: Closed
---

# Handover - dry-run script paths stop being exported env

## Objective

Remove the last dry-run family exports from the host environment, so the two probe-script paths reach the compose generation call-scoped and the harness writes no `DRY_RUN_*` value into the process environment.

## Scope

Ported from the parked draft branch, commit `3e589549`. In: two changes in `scripts/run_agent.sh`. The dry-run case block keeps its two path computations as plain shell variables instead of `export DRY_RUN_SCRIPT` and `export DRY_RUN_CAPABILITY_SCRIPT`. The `compose_generate` call carries both as call-scoped assignments, so the `{{VAR}}` substitution inside `compose_generate` still resolves them while the values never enter the environment: bash restores a call-scoped assignment after the call and never exports it. The ported `scripts/run_agent.sh` differs from the branch's copy only in comments the mainline had already replaced. The code change is `export DRY_RUN_SCRIPT` and `export DRY_RUN_CAPABILITY_SCRIPT` removed, and the two paths passed call-scoped to `compose_generate` instead. The second consumer needed no change and is the reason the exports were unnecessary: `compose_dry_run` already received both paths as positional arguments at the call site, so the only reader that depended on the environment was the substitution inside `compose_generate`. `DRY_RUN_IDENTITY` was never a host export, since the dry-run overlay writes it directly into the container environment, which is the single generated write the canonical-prefix scheme allows. Out: the branch's `devlog/roadmap.md` change, which the current roadmap supersedes; the tool-knob rulings live on their current rows.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The bash mechanism holds: a call-scoped assignment is visible inside the callee, restored after, and never exported | a probe run before the edit | accepted |
| The dry-run overlay still substitutes both paths into the generated compose file | `bash tests/test_trace_dry_run.sh` | 6 passed, 0 failed |
| Compose generation is unaffected | `bash tests/test_trace_compose_gen.sh` | 20 passed, 0 failed |
| The record verify path is unaffected | `bash tests/test_dry_run_record.sh` | 11 passed, 0 failed |
| The start and run agent paths are unaffected | `bash tests/test_start_agent.sh`, `bash tests/test_run_agent.sh` | 32 passed and 41 passed, both alone |
| Gates clean | `bash scripts/check_shell.sh`, `bash scripts/lint.sh` | 0 warnings across 175 files; clean across 9 gates |
| No `DRY_RUN_*` export remains in the host path | `grep -n "export DRY_RUN" scripts/ src/` returns nothing | no matches (exit 1) |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Call-scoped assignment rather than new positional parameters | `compose_generate`'s positional signature is shared with `compose_file_from_args`, and growing it for two dry-run-only values would widen the change for no behavior gained | this handover |
| `DRY_RUN_RECORD_TIMEOUT` and `DOCKER_STUB_*` stay as they are | both are test-process-local knobs that never cross into a production environment; renaming them now buys nothing and the census gate keeps them visible | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The dry-run overlay is the model's clean case: `DRY_RUN_IDENTITY` never existed as host env, which shows the container-boundary write is already reachable without any host export. [A] 2026-10-10 | contradiction | current iteration | this-record |
| `VERBOSE` still passes through the environment from the Makefile into `run_tests.sh`; the operator ruled it argument-only, so that passthrough is the next small unit in the sequence. [A] 2026-10-10 | scope change | next iteration | the-roadmap |

## Completed

| File | Change |
|---|---|
| [`scripts/run_agent.sh`](../../scripts/run_agent.sh) | the two dry-run paths are plain variables, handed to `compose_generate` call-scoped; no export remains |
