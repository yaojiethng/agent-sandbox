# Agent Handover

**Date:** 2026-09-26
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Land roadmap row 87: a light, operator-triggered mutation tier behind a `MUTATION=1` flag, replayable by script, that replaces the read-through's 49 throwaway bite files with one maintained catalog and one runner, and collects survivors into a findings register for collect-then-process resolution.

## Scope

- `devlog/roadmap.md` row 87 (mutation test suite): the operator decisions from this session's check-in become the row's write-back. Adoption: on-demand only, operator-triggered, layered on the suite, never a commit hook. Regular frequency is deferred to M4 and recorded on `devlog/roadmap_future.md`.
- The catalog: the 318 `bite` triples and the reusable `bite` helper body (backup, env-passed literal substitution, `cmp` no-op guard, restore) extracted from `tests/mutations/` into one maintained catalog file and one light runner script.
- The runner: script-replayable, no agent in the loop; per mutation it targets the subject's own test file (derived from the test-file naming rule), applies the mutation, verifies it applied (`bash -n`, mutant differs from backup), records the verdict, never terminates on a survivor.
- The register: each run creates its own dated jsonl findings register under `tests/mutations/runs/` (the `20260925-design-draft-findings_register_format.md` seven-value format), one file per pass, resolved in place later -- the read-through precedent, not a standing mutable file.
- The design record: one design-draft discussion doc capturing the session's decisions and the catalog contract.
- Freshness is run-and-see: a mutation whose old-text no longer matches reports `NO-OP` and is excluded from the survivor denominator. No commit-tag or provenance machinery.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `MUTATION=1` appends the mutation tier after the standard unit run; the suite run without the flag is unchanged | run both | Agent [x] - with-flag run appended the tier; without: 991/0 |
| 2 | The catalog and runner exist; the 49 `tests/mutations/bite*.sh` files do not exist | file listing | Agent [x] - catalog 245 lines; 51 files deleted |
| 3 | The catalog rows parse clean, each `old` currently matches the tree, and the dead rows dropped at extraction are counted in the design record | parse + match sweep | Agent [x] - 244 rows, 0 problems; 62 dropped counted |
| 4 | A replay runs each mutation against the subject's own test file, reports per-row verdicts (proven / survived / no-op), writes survivors to a new dated register under `tests/mutations/runs/`, and never exits non-zero on a survivor | fixture run + register read | Agent [x] - full run 508s, rc 0, register 62 open + 3 stale |
| 5 | A deliberately-stale row reports `NO-OP`, is excluded from the survivor count, and does not fail the run | fixture run | Agent [x] - unit + the 3 real no-op rows, rc 0 |
| 6 | The suite stays green and lint stays clean after the tier lands | `bash scripts/run_tests.sh`, `bash scripts/lint.sh` | Agent [x] - 991/0; lint clean |
| 7 | Roadmap row 87 and `roadmap_future.md` carry the adoption decisions; the design record exists | read the files | Agent [x] - write-back verified by grep |

## Hot files

| File | Why in scope |
|---|---|
| `tests/mutations/` | The 49 bite files: extraction source, then replaced by the catalog + register |
| `scripts/run_tests.sh` | The `MUTATION=1` branch that appends the tier |
| `tests/mutations/catalog.jsonl` | The maintained mutation record (new) |
| `tests/mutations/runs/` | One dated survivor/no-op findings register per run (new) |
| `scripts/mutations_run.sh` | The light replayable runner (new) |
| `devlog/discussions/20260926-design-draft-mutation_corpus_runner.md` | The design record for this session's decisions (new) |
| `devlog/roadmap.md`, `devlog/roadmap_future.md` | Row 87 write-back; M4 frequency note |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Mutation suite: adopted, on-demand only, `MUTATION=1` tier, never a hook | the operator's call this session; a mutation harness must stay simpler than the agent harness it serves | roadmap row 87 write-back |
| Survivors collect into a per-run dated findings register under `tests/mutations/runs/`, resolved in place later | one dated jsonl per pass, like the read-through register; a standing mutable file mixes passes and loses provenance (operator steering 2026-09-26) | this handover |
| Runner replaces the corpus files; the 49 throwaway bite files are deleted after extraction | operator call 2026-09-26; the catalog holds the use, the per-run registers hold the verdicts | this handover |
| Extraction drops rows whose target is no longer in the tree, counted in the design record; 3 structurally-stale rows (old matches, replacement breaks current-tree syntax) dropped after the first run | keep what is useful, drop what the register already records as dead | design record, this handover |
| Freshness is run-and-see (`NO-OP` reporting), no provenance machinery | a stale row costs one visible line; the register keeps the durable record | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Register is per-run (dated, one file per pass, resolved in place), not a standing `tests/mutations/register.jsonl` | steering | current iteration -- design change, AC 4 reworded |
| Newline-bearing `old`/`new` fields split across lines in the row decoder (`mapfile` misalignment), so rows after a multi-line row mutated the wrong text; fixed with a NUL-separated decoder, then the full run re-measured | bug | current iteration -- caught by the first full run, invalidated its numbers; rerun on the fix gave the recorded verdicts |

Triaged to: the steering row is recorded in the Decisions table; the bug is fixed in-tree and pinned by the fixture unit (no AGENT_FEEDBACK entry -- the runner test is the durable record, approved at pre-close).

## Completed

| File | Change |
|---|---|
| `tests/mutations/catalog.jsonl` | new: the 244-row catalog (extracted from the 306 triple-form call sites; 62 dead/structural drops counted in the design record) |
| `scripts/mutations_run.sh` | new: the light replayable mutation runner (`MUTATION=1` tier, verdicts, budget, NUL-safe row decoder, per-run register writer) |
| `scripts/run_tests.sh` | `MUTATION=1` branch appends the tier after the standard run |
| `tests/test_mutations_runner.sh` | new: pins the verdict semantics, register shape, stale exclusion, restore guarantee (2 units) |
| `tests/mutations/` (49 bite files + `README.md`) | deleted; superseded by the catalog and the per-run registers |
| `tests/mutations/runs/20260926-184023-mutation_run.jsonl` | the first full run's register (62 open + 3 stale) |
| `devlog/discussions/20260926-design-draft-mutation_corpus_runner.md` | new: the design record (decisions, contracts, extraction numbers, first-run measurement) |
| `devlog/roadmap.md` row 87 | write-back: settled, on-demand `MUTATION=1` tier, T1 successor routed, M4 frequency |
| `devlog/roadmap_future.md` M4 | new task: decide the regular mutation-run frequency |
| this handover | written at close |

## Deferred items

None.

## What's Next

M3.1 - Backpressure. Roadmap maintenance: current, mid-milestone; rows 85 (compact the read-through record) and 88 (runner subset selection) remain the named open work beside this closed row. The mutation tier now lives at `tests/mutations/catalog.jsonl` + `scripts/mutations_run.sh` (operator-triggered via `MUTATION=1`; register under `tests/mutations/runs/`). The first run's 62 open survivor rows await collect-then-process disposition in the register; the T1 run-brief workflow edit and the M4 frequency decision are roadmap-named successors.

**Conclusions from this session:** the mutation corpus is a catalogue, not a liveness obligation; its freshness mechanism is per-run applicability reporting, not commit-tag validation. The 49 bite files hold two reusable pieces - the `bite` helper body and the `bite name 'old' 'new'` rows - and nothing that needs an AST or in-place-edit engine.
