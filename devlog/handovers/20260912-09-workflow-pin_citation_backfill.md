# Handover 20260912-09 - workflow: pin-citation backfill (Anti-Pattern 6 rule application)

**Date opened:** 2026-09-12
**Type:** workflow
**Milestone:** M2.6 - Session Persistence
**Branch:** feat/M2_6_mount_model_redesign
**Status:** Closed

## Task

Apply the pin-citation rule (Anti-Pattern 6, `docs/development/testing-conventions.md`, landed in handover `20260912-08`) to the existing suite: add a citing header line to each test file whose exact-string pins are governed by a record, relax the two change-mirror-shaped assertions to meaning, and leave the two self-evident pins as-is.

## Origin

Operator-directed subagent audit (2026-09-12, gm follow-up to handover `20260912-08`). VERDICT: FINDINGS: 17 uncited pins needing disposition. Full audit reply preserved below (self-sufficient for a fresh session; the subagent session is gone).

## Audit findings (subagent, verbatim condensation)

Pin census: ~190 raw matches, ~60 excluded (fixture data, self-induced errors, echo-backs), ~130 contract-pin instances across 30 files. ~25 cited, ~105 uncited forming 17 pin-groups in 18 files. Every NONE has a plausible deciding record except two self-evident cases.

| File (group) | Pins | Deciding record found by audit |
|---|---|---|
| `tests/test_dry_run_probe.sh` | 37 | `20260828-design-settled-dry_run_phase_split.md` + `tool_interface.md` diagnostics-record section |
| `tests/test_dry_run_record.sh` | 15 | same design discussion; messages are operator-facing surface |
| `tests/test_dispatch.sh` | 29 | roadmap l.94 CLI-surface item + dispatch design discussion |
| `tests/test_interactive_session_select.sh` | ~3 | handover `20260809-03` task 6 (patches: N) -- nearest roadmap/story item should be cited; relax channel-name asserts |
| `tests/test_session_log.sh` | 14 | roadmap l.55 (relative-time strings + `---`, verbatim) |
| `tests/test_start_agent.sh` | 12 | `docs/concepts/sandbox_identity.md` label table + `tool_interface.md` naming |
| `tests/test_trace_resume.sh` | ~4 | `sandbox_identity.md` (labels, volume name), alongside existing R1-R4 list |
| `tests/test_trace_compose_gen.sh` | 1 | CHANGE-MIRROR: asserts absence of `name:` lines, cites the fix not a record; relax to "template + substitutions only" or cite the settling roadmap item |
| `tests/test_image_names.sh`, `tests/test_trace_build.sh` | 4+3 | `tool_interface.md` naming table (L15/28/266) |
| `tests/test_session_env.sh` | 6 | `tool_interface.md` naming + `20260730-design-settled-mount_model.md` (delivery default) |
| `tests/test_session_inventory.sh` | 6 | roadmap l.55 (list columns) + naming table |
| `tests/test_draft_state.sh`, `tests/test_draft_workflow.sh` | 9+ | `design_apply_draft_workflow.md` (field order, commit-subject format) |
| `tests/test_dirs.sh`, `tests/test_routing.sh` | 4+12 | `sandbox_identity.md` artefact-layout table + `design_workspace_path_resolution.md` |
| `tests/test_providers_pi_preflight.sh` | 8 | `design_provider_config_ownership_and_loading.md`; or relax message asserts to "warns and names the file" |
| `tests/test_onboard.sh` | 10 | `docs/operations/provider_onboarding_guide.md` (.env schema) |
| `tests/test_run_agent.sh` | 1 | `tool_interface.md` L175 SERVE_PORT row; or relax to "names the variable and the default" |
| `tests/test_prune.sh` | 1 | roadmap l.99 (prune output) |

Self-evident, no action: `tests/test_common_lib.sh` (INTERACTIVE_MAX_ENTRIES=10, value owned by the function under test); `tests/test_runner_selftest.sh` (plants its own `FAIL:` marker; code-owner citation already in `tests/libs/test_common.sh`). Optional polish: one code-owner header line in the selftest.

## Scope proposal

- Batch by record: one header citation line per file (18 files), naming the record(s) the audit identified. No assertion changes except the two relaxations below.
- Relax: `test_trace_compose_gen.sh` (`name:`-absence to template+substitutions meaning), and channel-name asserts in `test_interactive_session_select.sh` (if trivially safe; else cite and leave).
- Re-run suite; expect 752/0/0 unchanged (header comments only).
- Roadmap: no new row needed (this is backfill of the rule landed in `20260912-08`); record in the existing testing-conventions row's text if the operator wants it named.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | Every file with contract pins carries a header citation naming its deciding record (or an explicit self-evident note) | offline read | pass -- 21 files carry `# Pins cite:` headers (18 audit files + selftest code-owner line); `test_common_lib.sh` left as-is per audit (self-evident) |
| AC2 | Change-mirror pin in `test_trace_compose_gen.sh` relaxed to meaning | offline read | pass -- assertion now rejects only a top-level `^name:` key; indented service-block `name:` no longer pinned |
| AC3 | Full suite passes unchanged | suite | pass -- 752/0/0 (43 files) |

## Completed

| File | Change |
|---|---|
| 18 test files (batches 1-4) | `# Pins cite:` header citation added, record mapping operator-approved in batches of 5 |
| `tests/test_trace_compose_gen.sh` | change-mirror pin relaxed: top-level `^name:` key rejection only |
| `tests/test_interactive_session_select.sh` | cited, not relaxed (audit recommendation withdrawn -- channel names are contract) |
| `tests/test_runner_selftest.sh` | optional code-owner citation line added |
| This handover | audit record, batch mappings, corrections to subagent pointers |

## Decisions

| Decision | Rationale |
|---|---|
| Header-level citation per file (not per-assertion) | one pin-group per file shares one record; per-assertion citations would be noise |
| Relax over cite where the pin mirrors a change | Anti-Pattern 6's own remedy for change-mirror risk |

## Findings

- Subagent audit: provenance gap is systemic but shallow -- records exist one link away for all but two self-evident groups.
- Subagent record pointers needed correction in 3 of 21 mappings: "roadmap l.55" (blank line; real record is `tool_interface.md` l.55), "roadmap l.99" (prune; real row is l.140), and the interactive-session channel relax recommendation (channel names are contract per the channel tables -- cite, not relax).
- SERVE_PORT default value (46553) is recorded nowhere in docs -- only code-owner (`scripts/run_agent.sh` `SERVE_PORT_DEFAULT`); noted for the next `tool_interface.md` touch.

## Deferred items

- None.

## Operator approvals on record

- Iteration opened on operator instruction: "run the pin-citation audit in a subagent. then start a new iteration to process the findings." Scope confirmation pending (Gate 2).
