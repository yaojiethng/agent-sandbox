---
date: 2026-10-10
milestone: M3.4 - Configuration and Persisted Record Formats
type: Implementation
status: Closed
---

# Handover - Implementation: assert the probe record at the runner-derived path

## Objective

Turn the suite's one real red test green by asserting the diagnostics record at the path the probe was given, so the M3.4 verification gate can be trusted at every later unit.

## Scope

One assertion in `tests/test_dry_run_probe.sh`. The test `test_cap_failed_tempdir_precondition` resolved the record path from `${OUTPUT_DIR:-...}` at parent scope, but `_healthy_cap_env` exports `OUTPUT_DIR` inside the probe's subshell, so the assert read the ambient container variable (`/home/agentuser/workspace/output`) instead of the fixture path the probe actually used. The assert now reads the path the runner itself derived and recorded in the state file.

The probe was verified first, by reproduction with the same fixture and a bad `TMPDIR`: exit 1, both precondition causes named, and the record present at the fixture `OUTPUT_DIR`. The probe is not changed. The ambient-environment leak is recorded as a finding below, not fixed here, so this diff stays off the shared harness file.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `test_cap_failed_tempdir_precondition` passes with the probe behaviour unchanged | `bash tests/test_dry_run_probe.sh` | accepted: 22 passed, 0 failed |
| The edit cannot pass a probe that wrote no record | the assert reads `kv "$state" record`, the path the runner derived from the probe's own `OUTPUT_DIR` | accepted: the fixture reproduction shows the record appears exactly there |
| The full suite carries no real failure beyond the documented load class | `bash scripts/run_tests.sh`, then each reported file alone | accepted: residual timeouts and two further names all pass alone; `user` time is 7m27 against 2m05 real, oversubscription on this container |
| Lint clean | `bash scripts/lint.sh` | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/test_dry_run_probe.sh`](../../tests/test_dry_run_probe.sh) | the one assertion that resolved the record path from ambient environment |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Fix the test, not the probe | reproduction proves the probe honours its contract: exit 1, causes named, record written at the given `OUTPUT_DIR`; the test read a path the probe was never given | this handover |
| Do not unset the ambient path variables in `tests/libs/test_common.sh` here | that file is shared harness surface M3.1.2 owns; the fork keeps its diff off it, and the hermetism fix is a follow-on | this handover, as a finding |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The test harness is not hermetic against ambient environment: `OUTPUT_DIR` (and by shape `INPUT_DIR`, `CHANGES_DIR`) leak into tests from the container environment, and a parent-scope path resolution reads the container value rather than the fixture value. This failure hid as a probe defect for one full-suite run. A later unit should unset the ambient path variables in `test_setup`, which makes the class impossible by construction rather than remembered. [A] 2026-10-10 | bug | next iteration |

## Completed

| File | Change |
|---|---|
| [`tests/test_dry_run_probe.sh`](../../tests/test_dry_run_probe.sh) | the record assertion reads `kv "$state" record`, the path the runner derived, instead of the ambient `OUTPUT_DIR` |
