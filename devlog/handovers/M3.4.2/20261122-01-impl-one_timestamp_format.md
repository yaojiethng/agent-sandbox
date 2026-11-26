---
date: 2026-11-22
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - one timestamp format

## Objective

Give `YYYYMMDD-HHMMSS` one definition: `src/libs/time_format.sh` owns the format and both of its directions, and every producer and reader goes through it.

## Scope

The M3.4.2 row **One timestamp format**. This is the first of three sibling iterations this session runs, each with its own handover and delivery commit: the relative-time ladder next, then the resolution primitive's failure text. The file list is the scope proposal's and is presented at the scope gate.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One definition exists and writes both directions | `bash tests/test_time_format.sh` - `ts_now` matches the shape and `ts_from_epoch "$(ts_epoch "$t")"` round-trips | Agent [x] |
| Every producer writes through the definition | `grep -rn '%Y%m%d-%H%M%S' src/ scripts/ --include=*.sh` prints only `src/libs/time_format.sh` | Agent [x] - 0 hits outside the lib |
| No producer reads a local clock | `grep -rnE 'date \+.*%Y' src/ scripts/ --include=*.sh` prints nothing | Agent [x] - 0 hits |
| The gate bites | `bash tests/test_time_format.sh` fails when the test's fixture producer spells the format | Agent [x] - `test_the_scan_bites_a_fixture` |
| The reference sentences name the owner | `grep -n 'time_format' docs/reference/sandbox_identity.md docs/reference/execution_model.md` finds both | Agent [x] |
| The roadmap maintenance corrections land with the delivery commit | `grep -n 'design-settled-coding_agent_binding_surface' devlog/roadmap.md`; `grep -n 'feat/M3_4-project-supplied-environment' devlog/roadmap.md` | Agent [x] |
| Every decision this iteration recorded is realized in the files | the `## Decisions` table read against the delivery diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The format is defined once in `src/libs/time_format.sh`, holding the format string, the parse pattern, `ts_now`, `ts_from_epoch` and `ts_epoch`. | `src/libs/` ships whole to the capability image, so one lib reaches both layers with no per-image `COPY` change; the producers live in both layers. | This table; the lib docstring lands with the work. |
| `ts_to_epoch` moves out of `session_inventory.sh` into the format lib as `ts_epoch`. | The parse side is half the format's definition; leaving it in the session-inventory lib is the second copy the row names. | This table; `src/libs/session_inventory.sh` keeps its two callers. |
| Every producer writes UTC, including `mutations_run.sh`'s run filename, which read the local clock. | One format carrying two clocks is two formats, and every other producer already passes `-u`. The operator left the call to the agent; the run filename changes clock with this. | This table; `scripts/mutations_run.sh` |
| A reference sentence that states the shape names the owner instead of restating it. | A restated literal is a derived copy that goes stale silently. The operator left the placement to the agent: the two sentences that state the shape today name the lib, and no new document is opened. | This table; `sandbox_identity.md` and `execution_model.md` |
| The gate is a unit test that scans the production tree for a re-derived format, with its own failing fixture. | The row's defect is a literal re-derived at a producer, which only a tree-level scan holds, and a scan is unproven until something makes it fail. | This table; `tests/test_time_format.sh` |
| `ts_epoch` is the parse side's one name; `ts_to_epoch` is gone. | The parse side is half the format's definition; leaving the old name would give one function two names across two files. Its two unit tests move with it. | This table; `src/libs/session_inventory.sh`, `tests/test_session_inventory.sh`, `tests/test_session_log.sh` |
| The stub lib directory holds a shim to the real lib, as `dirs.sh` and `routing.sh` there already do, not a copy of it. | The stub dir is a second source root for the entrypoint: it neutralises the docker-facing libs, and every lib the entrypoint names must resolve from it. A copy would be a second definition; a shim keeps the mount tests asserting against the definition under test. The hand-kept list itself is the defect M3.4.7's inventory row owns -- a layered dir was tried and cannot work, because every stub resolves the repo at a fixed depth from its own path. | This table; `tests/stubs/libs/time_format.sh` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Seven closed M3.4.2 rows carry implementation narrative and counts, and name no handover. | record shape | The roadmap shows more than a closed row needs, and the numbers in it are true once. | `roadmap-maintenance` check 3.6; `/milestone-close` compaction owns the form. |
| The three rows this iteration and its siblings work carry counts and positional row references ("Row 20", "Row 31", "ten producers"), which the work itself falsifies. | record | A reader re-derives a stale measurement from the record. | This iteration's write-back, which replaces each row with its landing note. |
| M3.4.1 carries no `**Acceptance criteria:**` block. | record | The `task-list` convention requires one on an active sub-milestone, and discussion `20261112` records the absence as a scoping defect no row holds. | `/milestone-close` - the close owns the pre-close criteria gate; the operator left the call to the agent. |
| The M3.4.2 row **Structured where it helps: JSON and the parser dependency** is open against the milestone's own decision that no record becomes structured in this slice. | record | Two rows state opposite things about one subject. | `devlog/roadmap.md` - re-scoped to name the trigger that would reopen it. |
| The tree carries a second timestamp form: the three probe scripts write `%Y%m%dT%H%M%SZ` for their output names. | scope | A reader meets two timestamp shapes and cannot tell which is the harness's. | `devlog/roadmap.md` - filed as an open M3.4.2 row, out of this row's ten producers. |
| The stub lib directory mirrors the image's `/opt/sandbox/lib`, so a new lib that the entrypoint sources needs a stub entry before the mount tests can run. | test | A lib added to the entrypoint breaks nine mount tests until the stub dir carries it. | `devlog/roadmap.md` M3.4.7 **Per-image lib inventory manifest and drift test** - the operator assigned this item to that row at this iteration's release gate. The mount tests are fixed here. |

## Completed

| File | Change |
|---|---|
| [`src/libs/time_format.sh`](../../../src/libs/time_format.sh) | New: `TS_FORMAT`, `TS_PATTERN`, `ts_now`, `ts_from_epoch`, `ts_epoch` - the one definition. |
| [`src/libs/session_inventory.sh`](../../../src/libs/session_inventory.sh) | Sources the format lib; `ts_to_epoch` removed and both callers call `ts_epoch`. |
| [`src/capability/entrypoint.sh`](../../../src/capability/entrypoint.sh) | Sources the format lib through `_source_lib`, as it does every lib it names; the three export-status stamps call `ts_now`. |
| [`src/libs/package_branch.sh`](../../../src/libs/package_branch.sh) | Sources the format lib; the bundle stamp calls `ts_now`. |
| [`src/libs/diff_export.sh`](../../../src/libs/diff_export.sh) | Sources the format lib; the export stamp calls `ts_now`. |
| [`src/libs/routing.sh`](../../../src/libs/routing.sh) | Sources the format lib; `EXPORT_TIME` calls `ts_now`. |
| [`scripts/run_agent.sh`](../../../scripts/run_agent.sh) | Sources the format lib; `last_started` and `last_stopped` call `ts_now`. |
| [`scripts/start_agent.sh`](../../../scripts/start_agent.sh) | Sources the format lib; `SESSION_TS` calls `ts_now`. |
| [`scripts/mutations_run.sh`](../../../scripts/mutations_run.sh) | Sources the format lib; the run filename calls `ts_now`, so it is UTC. |
| [`scripts/workflows/interactive.sh`](../../../scripts/workflows/interactive.sh) | Sources the format lib; both epoch conversions call `ts_from_epoch`. |
| [`tests/test_time_format.sh`](../../../tests/test_time_format.sh) | New gate: the shape, UTC, the round trip, and the producer scan with a fixture that makes it bite. |
| [`tests/test_session_inventory.sh`](../../../tests/test_session_inventory.sh) | The `ts_to_epoch` unit is `ts_epoch`. |
| [`tests/test_session_log.sh`](../../../tests/test_session_log.sh) | The `ts_to_epoch` unit is `ts_epoch`. |
| [`tests/stubs/libs/time_format.sh`](../../../tests/stubs/libs/time_format.sh) | New shim: the stub lib dir resolves the real definition, the shape `dirs.sh` and `routing.sh` already use there. |
| [`docs/reference/sandbox_identity.md`](../../../docs/reference/sandbox_identity.md) | The `SESSION_TS` row names the owner instead of restating the `date` command. |
| [`docs/reference/execution_model.md`](../../../docs/reference/execution_model.md) | The activity-log paragraph names the owner instead of restating the literal. |
| [`devlog/roadmap.md`](../../roadmap.md) | Line 217's link text named `20261014-design-draft-coding_agent_binding_surface.md` for a record on disk as `...-settled-...`; corrected. |
| [`devlog/roadmap.md`](../../roadmap.md) | M3.4's `**Branch state.**` named `feat/M3_4-container_execution-model`, which no ref carries; corrected to `feat/M3_4-project-supplied-environment`. |
| [`devlog/roadmap.md`](../../roadmap.md) | The **One timestamp format** row compacts to its landing note and handover link. |
| [`devlog/roadmap.md`](../../roadmap.md) | The **Structured where it helps** row is re-scoped to the trigger that would reopen it, per the milestone's decision. |
| [`devlog/roadmap.md`](../../roadmap.md) | New open row for the probe scripts' second timestamp form. |
