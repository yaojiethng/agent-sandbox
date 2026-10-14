---
date: 2026-10-10
milestone: M3.4 - Configuration and Persisted Record Formats
type: Implementation
status: Closed
---

# Handover - Implementation: dry-run script paths stop being exported env

## Objective

Remove the last dry-run family exports from the host environment, so the two probe-script paths reach the compose generation call-scoped and the harness writes no `DRY_RUN_*` value into the process environment.

## Scope

Two changes in `scripts/run_agent.sh`. The dry-run case block keeps its two path computations as plain shell variables instead of `export DRY_RUN_SCRIPT` and `export DRY_RUN_CAPABILITY_SCRIPT`. The `compose_generate` call carries both as call-scoped assignments, so the `{{VAR}}` substitution inside `compose_generate` still resolves them while the values never enter the environment: bash restores a call-scoped assignment after the call and never exports it, which was verified by a probe before the edit.

The second consumer needed no change and is the reason the exports were unnecessary. `compose_dry_run` already received both paths as positional arguments at the call site, so the only reader that depended on the environment was the substitution inside `compose_generate`. `DRY_RUN_IDENTITY` was never a host export, since the dry-run overlay writes it directly into the container environment, which is the single generated write the canonical-prefix scheme allows.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The bash mechanism holds: a call-scoped assignment is visible inside the callee, restored after, and never exported | a probe run before the edit | accepted |
| The dry-run overlay still substitutes both paths into the generated compose file | `bash tests/test_trace_dry_run.sh` | accepted: 6 passed, 0 failed |
| Compose generation is unaffected | `bash tests/test_trace_compose_gen.sh` | accepted: 20 passed, 0 failed |
| The record verify path is unaffected | `bash tests/test_dry_run_record.sh` | accepted: 11 passed, 0 failed |
| The start and run agent paths are unaffected | `bash tests/test_start_agent.sh`, `bash tests/test_run_agent.sh` | accepted: 32 passed and 41 passed, both alone |
| Gates clean | `bash scripts/check_shell.sh`, `bash scripts/lint.sh` | accepted: 0 warnings, clean |
| No `DRY_RUN_*` export remains in the host path | `grep -n "export DRY_RUN" scripts/ src/` returns nothing | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/run_agent.sh`](../../scripts/run_agent.sh) | the two dry-run path exports and the `compose_generate` call |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Call-scoped assignment rather than new positional parameters | `compose_generate`'s positional signature is shared with `compose_file_from_args`, and growing it for two dry-run-only values would widen the change for no behavior gained | this handover |
| `DRY_RUN_RECORD_TIMEOUT` and `DOCKER_STUB_*` stay as they are | both are test-process-local knobs that never cross into a production environment; renaming them now buys nothing and the census gate keeps them visible | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The dry-run overlay is the model's clean case: `DRY_RUN_IDENTITY` never existed as host env, which shows the container-boundary write is already reachable without any host export. [A] 2026-10-10 | contradiction | current iteration |
| `VERBOSE` still passes through the environment from the Makefile into `run_tests.sh`; the operator ruled it argument-only, so that passthrough is the next small unit in the sequence. [A] 2026-10-10 | scope change | next iteration |

## Completed

| File | Change |
|---|---|
| [`scripts/run_agent.sh`](../../scripts/run_agent.sh) | the two dry-run paths are plain variables, handed to `compose_generate` call-scoped; no export remains |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the tool-knob rulings recorded: VERBOSE argument-only, INSTALL_DIR joins the canonical surface, the dry-run family's per-carrier disposition |
