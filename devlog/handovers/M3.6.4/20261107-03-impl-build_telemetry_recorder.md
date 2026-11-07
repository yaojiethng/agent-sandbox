---
date: 2026-11-07
milestone: M3.6.4 - The reasoning image refactor
type: Implementation
status: Closed
---

# Handover - The build operational model and its recorder

## Objective

State the reasoning image build's operational model and domain catalog, and turn the host build probe into a recorder that emits the model's four signals.

## Scope

Continues the audit [`20261107-02`](20261107-02-audit-build_contract_gap.md); realizes the two rows it filed as one instrument, on operator direction 2026-11-07.

In scope: [`The build's operational model and domain catalog are stated`](../../roadmap.md) and [`The host build probe records the production run`](../../roadmap.md). The page states the four questions (what the build produced, what the cache did, whether it failed, what it cost), the signal and source for each, the decision each supports, the domain catalog, the static and e2e layers, and the deferred signals with their triggers. The recorder replaces the probe's perturbation matrix with one JSON object per run: the git HEAD, the Dockerfile hashes, and per tier the image ID, size, cache state and step seconds. The `--rebuild` propagation is fixed and tested, because the recorder's `no-cache` row is replaced by the static test and the digest delta. The M3.6.4 design-step paragraph is replaced by a link to the page.

The iteration also reduces the comments in the two build files to non-obvious external context, on the operator's steering during the pre-close; the model, the contracts and the design decisions keep their own homes.

Out of scope: the real host run, which is the open [`The host build probe is re-run against the new shape`](../../roadmap.md) row because this container has no Docker; the `.dockerignore` and the pin implementation, which have their own rows; and the deferred signals named on the page.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The page states the four questions, the signal/source/decision for each, the domain catalog, the static/e2e layers and the deferred signals with triggers | read the three tables in the page; every row carries its signal, source and decision or trigger | Agent [x] |
| The recorder writes one JSON object per run with the git HEAD, the Dockerfile hashes, and per-tier image ID, size, cache state and step seconds; it mutates no Dockerfile | `bash tests/test_build_probe.sh`; `grep -n 'touch\|append\|restore\|mtime' scripts/build_probe.sh` | Agent [x] |
| The `mtime` and `restore` rows are gone; the `no-cache` row is replaced by the static propagation test and the digest delta | `grep -n 'ROWS' -A8 scripts/build_probe.sh`; no `mtime`, `restore` or `no-cache` row | Agent [x] |
| `--rebuild` reaches all three tiers, and the static test fails before the fix and passes after | `bash tests/test_build_rebuild.sh`; the test captures each `build_image` call | Agent [x] |
| The page's four signals and the recorder's fields agree | read the page's signal table against the report object constructed in `tests/test_build_probe.sh` | Agent [x] |
| The architecture documents in scope describe the system as built | read the `scripts/build.sh` usage, `docs/reference/tool_interface.md` and `docs/development/provider_onboarding_guide.md`; the `--rebuild` claim matches the code | Agent [x] |
| Every decision this iteration recorded is realized in the files | read the `## Decisions` table against the page, the probe and the build script | Agent [x] |
| The M3.6.4 design-step paragraph is replaced by a link to the page, and the two rows carry their landing notes | `git diff 77d2a4ec -- devlog/roadmap.md` | Agent [x] |
| The two files carry comments only for non-obvious external context; the model and the decisions are in the page and the handover, and the contracts are the code, the tests and `--help` | read `scripts/build_probe.sh` and `scripts/build.sh`; no comment states a design rationale or restates a usage or contract another home owns | Agent [x] |
| The roadmap is checked against the prior handover and no maintenance edit is needed | read the roadmap M3.6.4 section and the prior handover | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The two audit rows are one iteration, because the page and the recorder are one instrument: the page states the signals, the recorder emits them | the page without the recorder is a specification with no instrument, and the recorder without the page has no stated signals; the operator's confirmed deliverable is the pair | this record |
| The recorder records; it does not assert | the Dockerfile is the source and `docker build` the production run, so the run is measured, not grepped; pass/fail is the build's exit status and the static wiring tests | this record; the page |
| The `mtime` and `restore` rows go; the `no-cache` row becomes the static propagation test plus the digest delta | `mtime` and `restore` re-test Docker's content-addressed cache; the old `no-cache` observation is forced by the base change | this record; the page |
| The real host run is the host row, not this iteration | the agent container has no Docker by design; the recorder's tests use fixture logs | this record |
| The page owns the operational model; the ADRs own the requirements; the audit study owns the evidence | one subject in one mode has one source, so the page cites the ADRs and the study instead of restating their clauses | this record; the page |
| The layout is an implementation outcome, judged by the production run; the manifest stays the declaration and the gate, and the build-time derivation is not adopted | the operator's frame; the 2026-10-16 measured costs were whole-stage COPY invalidation, the shipping whitelist moving into a stage script, and the Dockerfile no longer stating the layout; the weaker agent-payload image was already dropped | this record; the page |
| Comments carry only non-obvious external context; the model is the page, the contracts are the code, the tests and the `--help`, and the design decisions are the handover and the ADRs | the comment volume restated the page, the usage and the provider guide, and explained a needless `_build_rc` sentinel; each content has one home | this record; the page |

## Decisions pending

None.

## Findings

| Finding | Triaged to |
|---|---|
| The audit study was orphaned when its owning row closed; the lifecycle gate flagged the file as a deletion that had not run | the open `The build context is narrowed to the declared inputs` row, which now cites the study |
| The operator's comment policy: comments carry only non-obvious external context, and the model, the contracts and the design decisions have one home each | this record's Decisions table; the page |
| The operator's first host run died at startup: the entry point read `PROBE_NO_CACHE`, which no code set, while the shared parser writes a bare `--rebuild` to `REBUILD`. The unit tests source the script and set the globals themselves, so every function was exercised and the one line wiring them was not | fixed here: the probe declares `REBUILD` and reads it, and `tests/test_build_probe.sh` gained an end-to-end unit that runs the program with docker stubbed |

## Completed

| File | Change |
|---|---|
| `docs/development/build_operational_model.md` | the model, the domain catalog, the three layers, the report schema and the deferred signals |
| `scripts/build_probe.sh` | the recorder: one JSON object per run; the perturbation matrix and the Dockerfile edits are gone |
| `tests/test_build_probe.sh` | the recorder's schema units, and the end-to-end unit that covers the program's wiring |
| `tests/test_build_probe.sh` | the parser, the tier schema and the report schema; the matrix tests are gone |
| `scripts/build.sh` | `--rebuild` reaches tier 3 |
| `scripts/build_probe.sh`, `scripts/build.sh` | the comments reduced to external context; the `_build_rc` sentinel simplified; the `substr` log offset replaced by a prefix match |
| `tests/test_build_rebuild.sh` | the static propagation test; it fails before the fix and passes after |
| `devlog/roadmap.md` | the two rows' landing notes and the design-step replacement |
| `devlog/roadmap.md` | roadmap checked against the prior handover; no completed sub-milestone is shown active; no maintenance edit needed |
