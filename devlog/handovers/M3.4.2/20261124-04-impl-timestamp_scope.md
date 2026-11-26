---
date: 2026-11-24
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - the timestamp invariant states its scope

## Objective

State whether the eval snapshot's `SNAPSHOT_TIME` is a harness stamp and make the format owner, the snapshot producer and the reference documents say the same thing.

## Scope

The fourth open M3.4.2 row. The iteration settles the scope of `src/libs/time_format.sh`'s one-format claim, renames the wall-clock producer to `ts_now_utc`, applies that decision to `src/libs/package_eval_snapshot.sh`, and closes when the code, the gate and the reference documents agree. It changes no snapshot artefact other than the timestamp value, and it opens no new external interface.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `ts_now_utc` is the one wall-clock producer; no current producer calls `ts_now`. | `rg -n '\bts_now\b' src scripts tests docs` prints nothing; `bash tests/test_time_format.sh` | Agent [x] |
| `SNAPSHOT_TIME` carries the harness shape in both `eval-point.json` and `.snapshot-status`, and the two agree. | `bash tests/test_package_eval_snapshot.sh`, case `test_snapshot_time_is_the_harness_format` | Agent [x] |
| The `time_format.sh` claim names the snapshot stamp and declares no external-artifact exception. | `bash tests/test_time_format.sh`; the header read against the diff | Agent [x] |
| The gate catches a non-harness stamp spelling, and the production tree has none. | `bash tests/test_time_format.sh`, cases `test_the_scan_bites_a_non_harness_stamp` and `test_no_producer_spells_a_non_harness_stamp` | Agent [x] |
| The ADR records the chosen rule, the rejected external-artifact exception and the edge cases. | `docs/adr/time_format.md` read against the diff; linked from `sandbox_host_interface.md` | Agent [x] |
| The reference and development documents agree with the claim. | `rg -n -e 'ts_now_utc' -e 'SNAPSHOT_TIME' -e 'time_format' docs/reference/sandbox_host_interface.md docs/development/build_operational_model.md docs/reference/sandbox_identity.md`; each read against the diff | Agent [x] |
| Every decision this iteration records is realized, the roadmap row closes, and the handover is closed. | the `## Decisions` table read against the delivery diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The wall-clock producer is `ts_now_utc`; `ts_epoch` and `ts_from_epoch` keep their names. | The failure the format guard prevents is a producer reading the local clock. The suffix marks the one function that chooses a clock; the two converters are deterministic format operations whose UTC behavior the lib states once. | This table; `docs/adr/time_format.md` entry 2026-11-24 |
| The eval snapshot's `SNAPSHOT_TIME` is a harness stamp, routed through `ts_now_utc`; there is no external-artifact exception. | The harness writes it, no code in the tree reads it back, and the snapshot directory already uses harness time. An exception would leave two timestamp shapes inside one snapshot for a consumer requirement that does not exist. | This table; `docs/adr/time_format.md`; `src/libs/package_eval_snapshot.sh` |
| The timestamp gate also rejects ISO 8601 and old probe-style spellings, not only the compact literal. | The defect was a producer spelling a format the existing scan could not see. The gate now covers the shapes a second producer is likely to reach for. | This table; `tests/test_time_format.sh` |
| The decision gets a new ADR, `docs/adr/time_format.md`, rather than an entry in an unrelated record. | The scope of the one-format claim governs every future producer, not only the snapshot. No existing ADR states the timestamp principle. | This table; `docs/adr/time_format.md` |
| The illustrative timestamp in `build_operational_model.md` is corrected to the harness shape. | The probe already writes harness time; the example carried the old ISO form and would teach the next producer the wrong shape. | This table; `docs/development/build_operational_model.md` |

## Decisions pending

None.

## Findings

None.

## Completed

| File | Change |
|---|---|
| [`src/libs/time_format.sh`](../../../src/libs/time_format.sh) | `ts_now_utc` is the one wall-clock producer; the claim names the snapshot stamp and the two deterministic conversions. |
| [`src/libs/package_eval_snapshot.sh`](../../../src/libs/package_eval_snapshot.sh) | Sources the format lib and stamps `SNAPSHOT_TIME` through `ts_now_utc`. |
| [`src/capability/entrypoint.sh`](../../../src/capability/entrypoint.sh) | The three export-status stamps call `ts_now_utc`. |
| [`src/libs/routing.sh`](../../../src/libs/routing.sh) | `EXPORT_TIME` calls `ts_now_utc`. |
| [`src/libs/diff_export.sh`](../../../src/libs/diff_export.sh) | The export stamp calls `ts_now_utc`. |
| [`src/libs/package_branch.sh`](../../../src/libs/package_branch.sh) | The bundle stamp calls `ts_now_utc`. |
| [`scripts/build_probe.sh`](../../../scripts/build_probe.sh) | The probe stamp calls `ts_now_utc`. |
| [`scripts/mutations_run.sh`](../../../scripts/mutations_run.sh) | The run filename calls `ts_now_utc`. |
| [`scripts/run_agent.sh`](../../../scripts/run_agent.sh) | The activity-log stamps call `ts_now_utc`. |
| [`scripts/start_agent.sh`](../../../scripts/start_agent.sh) | `SESSION_TS` calls `ts_now_utc`. |
| [`scripts/stop_probe.sh`](../../../scripts/stop_probe.sh) | The probe stamp calls `ts_now_utc`. |
| [`scripts/stop_signal_matrix.sh`](../../../scripts/stop_signal_matrix.sh) | The matrix stamp calls `ts_now_utc`. |
| [`tests/test_time_format.sh`](../../../tests/test_time_format.sh) | Pins the producer name and rejects compact, old-probe and ISO spellings with two fixtures. |
| [`tests/test_package_eval_snapshot.sh`](../../../tests/test_package_eval_snapshot.sh) | Pins the snapshot timestamp shape and the facts/status agreement. |
| [`docs/adr/time_format.md`](../../../docs/adr/time_format.md) | New ADR: every harness stamp is the harness format, and the snapshot is a harness stamp. |
| [`docs/reference/sandbox_host_interface.md`](../../../docs/reference/sandbox_host_interface.md) | States the snapshot timestamp rule and links the ADR. |
| [`docs/reference/sandbox_identity.md`](../../../docs/reference/sandbox_identity.md) | `SESSION_TS` names `ts_now_utc`. |
| [`docs/development/build_operational_model.md`](../../../docs/development/build_operational_model.md) | The illustrative build timestamp uses the harness shape. |
| [`devlog/roadmap.md`](../../roadmap.md) | The timestamp row closes and the decision is recorded. |
