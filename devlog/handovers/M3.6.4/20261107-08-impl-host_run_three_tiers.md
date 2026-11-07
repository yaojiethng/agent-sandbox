---
date: 2026-11-07
milestone: M3.6.4 - The reasoning image refactor
type: Implementation
status: Closed
---

# Handover - the host run records the three-tier shape

## Objective

Record the production run of the three-tier shape three times - the pre-removal baseline, the removal, and the pin - so the pair of deltas shows what each change did to the artifact, the cache and the cost.

## Scope

The M3.6.4 row `The host build probe is re-run against the new shape`. The operator ran the recorder on the host; this iteration reads what it produced and records it.

Out of scope: the build-cost question the delta opened, which is filed as its own row rather than settled here.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The recorder ran three times, once per shape, and each run exited 0 | the three reports in `$INPUT_DIR/build/`, each `run.exit_status: 0` | Agent [x] |
| Each report carries the four signals per tier | each report's `tiers[]` holds a digest, a size, a cache state and step seconds for all three tiers | Agent [x] |
| The three runs are identifiable by the commit each saw | `repo.head` reads `b6ffe28a`, `eaf1f678` and `d5b3aecc`, and each `repo.dirty` is false | Agent [x] |
| The removal's delta shows what it did to the artifact | sizes identical to the byte on all three tiers, the provider image `cached`, wall 2s | Agent [x] |
| The pin's delta shows what it did to the artifact and the cost | every tier rebuilt; `agent-runtimes` 528.9MB to 737.9MB; wall 2s to 82s | Agent [x] |
| The growth is filed rather than absorbed | the open row naming the 209MB and the measurement that localises it | Agent [x] |
| The suite and the lint pass | `bash scripts/run_tests.sh`; `bash scripts/lint.sh` | Agent [x] |
| Every decision this iteration records is realized in the files | the Decisions table, which carries one ruling: ship | Agent [x] |
| Architecture documents in scope describe the system as built | the build page's `## The host run` still describes what the recorder does | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The runtime tier ships at 737.9MB, and the reduction is filed rather than taken now | the pin buys a reproducible tree, the tier is internal and never distributed, and the reduction has a named next step; taking it first would add an iteration to a cost nobody has said they care about | this record; `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The pin's first host build failed on `jq=1.6-2.1+deb12u2`, whose `libjq1` had already moved to `deb12u3` in `bookworm-security`; the resolver read only `bookworm/main` | defect | a pinned set that could not install, found only on the host because the container resolves the same index the pin was taken from | fixed in the pin commit, handover `20261107-07` |
| The recorder reported `cache_state: ran` for every tier of a fully cached build, because the `FROM` resolve prints `DONE` whenever the base image is already local | defect | the cache signal was constant, so the reports could not answer the question the instrument exists for | fixed in the pin commit, handover `20261107-07` |
| `docker history`'s top row reported 1.01GB for a 737.9MB image, so its per-layer figures cannot be subtracted from | tooling | the 209MB growth is measured but not localised | the open row for the tier's size, which names the `du` measurement that settles it |
| The three reports live in `$INPUT_DIR/build/` and are not in the tree, so the numbers survive only in this record's table | record | the raw reports are operator-side; the handover carries the reading | this record |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | the host row closes with the three-run reading; the tier-2 size row is filed |
| `devlog/handovers/M3.6.4/20261107-08-impl-host_run_three_tiers.md` | this record |
