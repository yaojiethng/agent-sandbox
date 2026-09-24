# Agent Handover

**Date:** 2026-09-22
**Milestone:** M3.1 - Backpressure
**Type:** Impl
**Status:** Open

## Objective

U7 of the unified test-harness improvement plan: the final full per-assertion sweep as a fresh-subagent review pass, fixing what is unfair or unreliable.

## Sweep result (fresh-subagent, deepseek-v4-flash xhigh; log /tmp/u7-review.log)

All 58 files read in full (16,859 lines). Findings: item 1 (capture-and-assert) ~90 mostly diagnosis-quality sites; item 2 six vacuous assertions (cannot fail); item 3 zero; item 4 sixty redundant `rm -rf`; item 5 five silent-green sites incl. one provable; item 6 zero; item 7 zero.

## Fixed in this iteration

| Finding | Fix |
|---|---|
| Two `if trace_grep ... > /dev/null` conditions in test_trace_start.sh always true (trace_grep masks rc) | Use `trace_has` |
| test_start_refresh_volume_rm unconditional pass | Assert the seed-based reset: no explicit `volume rm` with a stale stub volume present |
| test_apply_force_mode / test_apply_patch_file_force unconditional pass | Capture rc and assert 0 |
| test_select_session_name_truncation vacuous else-branch | Make the else a fail (the fixture name must truncate) |
| test_resume_reuses_record_session_id asserted the fixture's own string | Assert resume rc before trusting the regenerated file |
| test_parse_args_help_exits_2 verified only rc | Capture output and assert the usage text |
| test_trace_compose_gen silent green when `docker compose config` fails (empty output satisfies the grep) | Assert rc 0 first |
| `_source_preflight` masked a failed preflight load with `\|\| true` | Propagate the rc; the negative test fails loud on a load failure |
| Invocation helpers (invoke_dry_run, invoke_build, invoke_stop) masked the run rc | Helpers return rc; every call site asserts rc 0 |
| **`scripts/prune.sh` missing its exec bit** -- stop.sh:137 executes it directly, so `stop --prune` returned 126 in production; the masked suites hid it | chmod +x + update-index chmod |
| 60 redundant `rm -rf` teardown lines in 5 files | Removed; the allocator owns the lifecycle |

## Verification

Full suite 710/710; lint Clean; order gate 58/58, 0 order-dependent.

## Hot files

`tests/libs/test_common.sh` (unchanged this iteration), 13 test files, `scripts/prune.sh` (mode).

## What's Next

The unified plan's work units U1-U7 are complete. The deferred items remain: re-port branch A and branch B onto the finished harness, re-measure on equal footing, settle the harness decision, then M3.1 close. Policy amendment for the design-document conventions (queued [O] 2026-09-22) also remains.
