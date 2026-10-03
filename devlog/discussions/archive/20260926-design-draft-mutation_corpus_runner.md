# Mutation Corpus Runner

**Status:** draft
**Date:** 2026-09-26
**Roadmap:** M3.1 row 87

## Purpose

Roadmap row 87 asked whether the project adopts a mutation suite. The read-through's mutation-bite method (2026-09-24/25) produced 49 throwaway sweep scripts under `tests/mutations/`. This record settles the adoption decision and the design the operator set in the scoping session of 2026-09-26.

## Decisions

| Decision | Source |
|---|---|
| Adopt a mutation tier, run on demand only, layered on the unit suite, never a hook | operator |
| Execution is nonstandard: `MUTATION=1` on the suite runner appends the tier after the standard run | operator |
| Reach is operator-triggered only; the regular frequency is decided in M4.1 | operator |
| Survivors collect into a dated jsonl findings register, resolved later (collect-then-process); a run never terminates on a survivor | operator |
| The sweep status is valid only in its source session; the session is the disposal unit | operator |
| A run is script-replayable; no agent in the loop | operator |
| The register is per run (one dated file per pass, resolved in place), not a standing mutable file | operator |
| The 49 throwaway sweep files are deleted after extraction; the catalog holds the use, the registers hold the verdicts | operator |
| The corpus is a catalogue, not a liveness obligation; freshness is run-and-see (`NO-OP` reporting), no commit-tag machinery | operator |

## The catalog

`tests/mutations/catalog.jsonl` is the maintained mutation record. The first line is metadata (`schema`, `last_updated`, `count`); each following line is one mutation:

| Field | Meaning |
|---|---|
| `id` | catalog row id |
| `name` | the read-through's bite name (e.g. `D1-range-upper-bound`) |
| `subject` | the production file the mutation targets, relative to the repo root |
| `old` | the exact text to replace (first occurrence, byte-exact, multi-line safe) |
| `new` | the replacement text |
| `source` | the original sweep file the row was extracted from |

### Extraction numbers

The 49 sweep files held 306 triple-form call sites. The extraction parsed 299 rows; 7 used exotic quoting and were transcribed by hand (all 7 match the tree). Of the 306, 59 no longer matched the tree (whole-file rewrites: `start_agent.sh`, `onboard.sh`, `prune.sh`; partial: `run_agent.sh`, `resume_agent.sh`, plus isolates) and were dropped at extraction, counted here. A first run surfaced 3 more structurally-stale rows (old matches, replacement breaks the current tree syntax: draft `D5-collection-order`, snapshot `P1`, compose `C11-printf-name-prefix`); they were dropped and counted with the dead set. The files that used one of the six older harnesses (`run_bite`, `run_case`, `run_mut`, `mut`, `run_one`, inline `awk`) carried no triple rows and contributed nothing; their verdicts live in the read-through register. The catalog holds 244 rows across 14 subjects; all 244 validated (old present, mutant `bash -n` clean).

## The runner

`scripts/mutations_run.sh` replays the catalog. Per row it copies the subject, applies the first exact occurrence of `old`, and checks the mutation is real: the mutant differs from the backup and `bash -n` passes. It then runs the subject's mapped test files (the lookup table uses the test-file naming rule of `testing_policy.md`; `MUTATIONS_SUBJECT_MAP` overlays fixture subjects for the test suite). Verdicts:

| Verdict | Meaning | Register |
|---|---|---|
| PROVEN | a targeted test failed against the mutant; the line is pinned | summary only |
| SURVIVED | all targeted tests passed; the line is unpinned | row, status `open` |
| NO-OP | the old text no longer matches, or the mutant is invalid | row, status `stale` |

The register is one dated file per run under `tests/mutations/runs/` (`<YYYYMMDD-HHMMSS>-mutation_run.jsonl`), using the seven-value status vocabulary of the findings-register format note (`open`, `resolved`, `accepted`, `blocked`, `needs-decision`, `stale`, `assigned`). Resolution happens in place later, as the read-through register does.

The budget defaults to 900s total with a 60s per-test deadline; rows beyond the budget are skipped and reported. A stale row costs one visible line and is excluded from the survivor denominator. The subject files are restored after every row, proven or not.

### First-run measurement (2026-09-26)

Full replay of the 247-row catalog (the 3 structural rows still present): 508s wall, zero budget skips. Verdicts: 182 proven, 62 survived, 3 no-op. The survivor run is recorded in `tests/mutations/runs/20260926-184023-mutation_run.jsonl` (62 rows status `open`, 3 rows status `stale`). The run fits a 15-minute budget with room; the heavy suites (`dispatch`, `resume`, `install`) dominate the wall.

### Subject map

| Subject | Targeted suites |
|---|---|
| `scripts/agent-sandbox.sh` | test_dispatch |
| `scripts/build.sh` | test_build_context |
| `scripts/install.sh` | test_install |
| `scripts/resume_agent.sh` | test_resume_list, test_resume |
| `scripts/run_agent.sh` | test_run_agent |
| `scripts/stop.sh` | test_stop_fail_closed, test_trace_stop |
| `scripts/workflows/apply.sh` | test_apply_workflow, test_rename_apply |
| `scripts/workflows/confirm.sh` | test_confirm_workflow |
| `scripts/workflows/draft.sh` | test_draft_workflow, test_draft_state |
| `src/build/compose.sh` | test_compose_wait, test_trace_compose_gen |
| `src/capability/entrypoint.sh` | test_capability_entrypoint_mount, test_dry_run_probe |
| `src/capability/git-hooks/pre-commit.sh` | test_git_hook |
| `src/capability/seed_volume.sh` | test_seed_volume |
| `src/capability/snapshot.sh` | test_snapshot_host |

## Refresh

A refresh is a re-baseline: re-point stale rows at the current tree, drop dead rows, add decision sites a new read-through finds, bump `last_updated`. The completion test is 100% row applicability against the new HEAD and a clean suite. The read-through cadence is the natural trigger; a `NO-OP` surge is the early warning for an unscheduled refresh. The formal run brief is a T1-scoped workflow edit (roadmap row 87's contingent clause).

## Out of scope

- An operator engine or AST parse: the read-through's value was picking decision sites by judgment; the catalogue encodes that judgment once.
- Commit-tag or provenance machinery: run-and-see covers freshness.
- A standing mutable register: the per-run file is the precedent.
