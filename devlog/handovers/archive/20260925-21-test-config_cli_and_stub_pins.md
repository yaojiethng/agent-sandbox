# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Pin the last coverage rows: the configuration, environment and CLI surface, the docker stub's label filtering, and the remaining suite defects.

## Scope

Unit U9 of the coverage campaign (roadmap row 83). Register rows 1, 2, 5, 6, 9, 13, 42, 43, 16, 89, 132, 86, 113, 115, 129, 161, 171, 223, 239, 317.

## Carried forward

| Item | From handover |
|---|---|
| The coverage campaign, unit U9 | [20260925-20-test-capability_and_build_pins](20260925-20-test-capability_and_build_pins.md) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| Seventeen rows are pinned by a unit that fails when their rule is removed | the bites | Agent [x] |
| Rows 129 and 161 need a production change and stay open | the register | Agent [x] |
| Row 42 is partial and stays open | the register | Agent [x] |
| The docker stub filters by label rather than only logging | the prune and seed units | Agent [x] |
| Production files are unchanged and byte-identical after every mutation | `git diff` and `cmp` | Agent [x] |
| Lint clean and the suite green | both gates | Agent [x] - 977 units, 65 files, 0 failed |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/stubs/docker`](../../tests/stubs/docker) | label filtering for the orphan and seed paths |
| [`tests/libs/draft_fixtures.sh`](../../tests/libs/draft_fixtures.sh) | the orchestration replica that diverged from production |
| [`tests/test_env_resolve.sh`](../../tests/test_env_resolve.sh), [`tests/test_env.sh`](../../tests/test_env.sh), [`tests/test_common_lib.sh`](../../tests/test_common_lib.sh), [`tests/test_dirs.sh`](../../tests/test_dirs.sh), [`tests/test_interface_contract.sh`](../../tests/test_interface_contract.sh), [`tests/test_cli_lib.sh`](../../tests/test_cli_lib.sh), [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) | the configuration, environment, CLI and dispatcher rules |
| [`tests/test_draft_workflow.sh`](../../tests/test_draft_workflow.sh), [`tests/test_image_names.sh`](../../tests/test_image_names.sh), [`tests/test_seed_volume.sh`](../../tests/test_seed_volume.sh), [`tests/test_stop_fail_closed.sh`](../../tests/test_stop_fail_closed.sh) | the source selection, image names, the seed volume, and the new stop fail-closed suite |
| `src/libs/env_resolve.sh`, `env.sh`, `common.sh`, `dirs.sh`, `interface_contract.sh`, `cli.sh`, `scripts/install.sh`, `scripts/onboard.sh`, `scripts/workflows/draft.sh`, `src/capability/seed_volume.sh` | mutation subjects, unmodified |
| [`devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl`](../discussions/20260924-design-active-test_suite_readthrough.jsonl) | seventeen rows resolved |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The docker stub filters by label, not just logs | presence and spelling were already assertable; the untestable case was a query returning another project's resource | the stub's header |
| The draft fixtures now drive the shipped orchestration rather than a replica | row 223's defect is that the replica diverges from production | the fixture lib |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Rows 129 and 161 need a production change; row 42 is partial. All three stay open. | bug | next iteration |
| `tests/test_stop_fail_closed.sh` is new: the stop path's fail-closed refusal had no suite of its own. | bug | current iteration |

## Completed

| File | Change |
|---|---|
| `tests/stubs/docker` | label-map filtering for `ps` and `volume ls` |
| `tests/libs/draft_fixtures.sh` | drives the shipped orchestration instead of a replica |
| `tests/test_env_resolve.sh`, `test_env.sh`, `test_common_lib.sh`, `test_dirs.sh`, `test_interface_contract.sh`, `test_cli_lib.sh`, `test_dispatch.sh`, `test_draft_workflow.sh`, `test_image_names.sh`, `test_seed_volume.sh` | units for the rules the seventeen rows name |
| `tests/test_stop_fail_closed.sh` | new: the stop path's fail-closed refusal |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | seventeen rows resolved |
| `devlog/roadmap.md` | row 83 records the slice |

## Deferred items

None beyond the register: rows 42, 129 and 161 stay open.

## What's Next

The coverage campaign is complete for every row a unit can pin. What remains in the register is the code lane: the open `action_kind: code` rows (the redundant lines, the key injection, the `lvalue` family) and the two rows that need a production change.

Read at iteration start: this handover, the register's open code rows, and roadmap row 83.

**Conclusions from this iteration:** the campaign closed every coverage row that a unit can pin; the remainder is code work, which needs `fix:` units rather than test units.
