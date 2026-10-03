# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Pin the rules the capability and build layer rows name: the entrypoint, the compose generator, the commit hook, snapshot, seed_volume and the image build.

## Scope

Unit U8 of the coverage campaign (roadmap row 83), test files only. Register rows 107-110, 94, 95, 98, 99, 102-104, 117, 118, 114, 115, 87, 101, 113, 119, 97, 124.

## Carried forward

| Item | From handover |
|---|---|
| The coverage campaign, unit U8 | [20260925-19-test-entry_point_pins](20260925-19-test-entry_point_pins.md) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| Eighteen of the twenty rows are pinned by a unit that fails when their rule is removed | the bites | Agent [x] |
| Rows 113 and 115 stay open, each only partially pinnable | the register | Agent [x] |
| Production files are unchanged and byte-identical after every mutation | `git diff` and `cmp` | Agent [x] |
| Lint clean and the suite green | both gates | Agent [x] - 960 units, 64 files, 0 failed |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/test_capability_entrypoint_mount.sh`](../../tests/test_capability_entrypoint_mount.sh) | the entrypoint's mount and signal rules |
| [`tests/test_git_hook.sh`](../../tests/test_git_hook.sh) | the commit hook's staged-file rules |
| [`tests/test_compose_wait.sh`](../../tests/test_compose_wait.sh), [`tests/test_trace_compose_gen.sh`](../../tests/test_trace_compose_gen.sh) | the compose generator and its wait |
| [`tests/test_snapshot_host.sh`](../../tests/test_snapshot_host.sh), [`tests/test_seed_volume.sh`](../../tests/test_seed_volume.sh), [`tests/test_image_names.sh`](../../tests/test_image_names.sh), [`tests/test_trace_build.sh`](../../tests/test_trace_build.sh) | the snapshot, seed, image-name and build-trace rules |
| `src/capability/entrypoint.sh`, `snapshot.sh`, `seed_volume.sh`, `git-hooks/pre-commit.sh`, `src/build/compose.sh`, `image.sh` | mutation subjects, unmodified |
| [`devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl`](../discussions/20260924-design-active-test_suite_readthrough.jsonl) | eighteen rows resolved |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The signal-driven units keep the exec-and-settle pattern | the suites background the entrypoint and send SIGTERM; a signal that arrives before the trap registers is a false failure | the test files |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Rows 113 and 115 are only partially pinnable inside a test-only unit and stay open. | contradiction | next iteration |

## Completed

| File | Change |
|---|---|
| `tests/test_image_names.sh`, `test_compose_wait.sh`, `test_trace_compose_gen.sh`, `test_git_hook.sh`, `test_capability_entrypoint_mount.sh`, `test_snapshot_host.sh`, `test_seed_volume.sh`, `test_trace_build.sh` | units for the rules the eighteen rows name |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | eighteen rows resolved |
| `devlog/roadmap.md` | row 83 records the slice |

## Deferred items

None beyond the register.

## What's Next

Unit U9: the configuration, environment, CLI and stub remainder.

Read at iteration start: this handover, register rows 113 and 115, and roadmap row 83.

**Conclusions from this iteration:** the capability suites were the last group whose rules needed the harness's signal machinery; the remainder is small and file-local.
