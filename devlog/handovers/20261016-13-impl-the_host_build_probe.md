---
date: 2026-10-16
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Implementation
status: Closed
---

# Handover - The host build probe

## Objective

Give the host one command that measures the build: what rebuilt, what it cost, and whether the cache behaved the way the key says it should. The agent's container has no Docker by design, so this is the one measurement it cannot take itself, and the layer install design waits on it.

## Scope

[`scripts/build_probe.sh`](../../scripts/build_probe.sh) and its test. The probe's run is the operator's. Nothing else changed, apart from the roadmap rows below and one amendment to the invalidation-history study.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The script runs its matrix and reports one JSON verdict | `bash tests/test_build_probe.sh`, 12 passed | Agent [x] |
| The report names the trigger | the report carries `git HEAD`, and every reasoning Dockerfile's sha256 | Agent [x] |
| The report carries the cost | each row's wall seconds and its summed `DONE` step seconds; the builder gained `--progress=<mode>`, because it builds with `--quiet` and the step lines are suppressed by default | Agent [x] |
| The report carries identity | each tier's image id and its `agent-sandbox.base-build-key` label | Agent [x] |
| A wrong cache is loud | every asserted row compares its observed rebuild set to an expected one, and the script exits 1 on a mismatch | Agent [x] |
| The tree is left as it was found | the probe refuses a dirty start, restores on exit through a trap, and adds a failure when the tree is dirty after the restore | Agent [x] |
| The host run itself | the operator runs it; it is the integration test no container can perform | Operator |
| Gates clean | shellcheck clean across 178 files; `bash scripts/lint.sh` clean across 8 gates | Agent [x] |

## How to run it

On the host, from the repo:

```bash
bash scripts/build_probe.sh
```

Options are `--input-dir=<path>` to override `$INPUT_DIR`, `--provider=<name>` for the chain to probe, default `pi`, and `--project=<name>` for the tier-3 tag, default `probe`. The script refuses to start on a dirty tree, because that is what makes the Dockerfile restore checkable.

The report lands at `<input-dir>/build/<timestamp>.json`, with each row's build log and its `docker history --no-trunc` dumps in `<input-dir>/build/<timestamp>/`. The agent reads the input channel at `/home/agentuser/workspace/input/`, so it reads the report at `input/build/<timestamp>.json` and the logs beside it.

## The matrix

| Row | Perturbation | Expected to rebuild |
|---|---|---|
| baseline | none | recorded, not asserted: it brings tiers 1 and 2 to their current key |
| mtime | touch the tier-2 Dockerfile | tier 3 alone, so tiers 1 and 2 skipping proves the key reads content, not the file's identity |
| content | append a comment to the tier-1 Dockerfile | tiers 1, 2 and 3, because tier 2 follows the tier-1 image's content id |
| restore | remove the comment | tiers 1, 2 and 3, because tier 1 holds a key describing the perturbed file |
| no-cache | `--rebuild` | tiers 1, 2 and 3 |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The probe refuses a dirty start | the restore is only checkable against a known-clean baseline, and a dirty tree makes a leftover edit indistinguishable from the operator's own work | the script header |
| The baseline row records rather than asserts | a cold machine builds and a warm one skips, so only the rows after the baseline have a determinate expectation | the matrix table in the script |
| The report is JSON with a hand-rolled escaper | the host carries no jq and no python3, per [`host_requirements.md`](../../docs/development/host_requirements.md), so the probe cannot depend on either | `json_string` |
| The script is dual-use, with the shell flags inside the execution guard | a test that sources it must keep its own shell regime, per bash-coding-conventions rule 1.17 | the foot of the script |
| The builder takes `--progress=<mode>` rather than reading an exported variable | a mode is a command input parsed once at ingestion, per bash-coding-conventions rules 1.12 and 1.13, and the probe must ask for the step lines explicitly | [`scripts/build.sh`](../../scripts/build.sh) |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The build's skip echo changed on 2026-10-16. `26595bff` reworded `Image exists, skipping:` to `Image up to date, skipping:` while fixing the cache key, which bundled a message change into a semantic fix. The invalidation-history study then counted the old string across the historical transcripts, where it is correct. The study now names both strings and their dates, and this probe parses the current one. | drift, corrected | the invalidation-history study |
| The probe cannot assert the baseline row, because the starting cache state is the machine's, not the tree's. | method | the matrix |
| The builder suppresses per-step output, which the first host run proved. `build_image` ran `docker build --quiet` to keep the harness log to one line per image, so the report carried `step_seconds` as 0 for every row. The builder now takes `--progress=<mode>` and the probe asks for `plain`. | defect, fixed | [`scripts/build.sh`](../../scripts/build.sh) |
| The host run passed all five rows, twice, and its wall seconds are the cost input the design row was waiting for. The settled run reads 1 second for the warm baseline, 1 for the mtime row, 3 for the content row, 2 for the restore row and 77 for the cold rebuild. The first run read 43 for its baseline, which priced a one-off npm install as the norm; the second run settled it. All of it is recorded in the invalidation-history study. | measurement | the layer install design row |

## Completed

| File | Change |
|---|---|
| [`scripts/build_probe.sh`](../../scripts/build_probe.sh) | the new host-side probe |
| [`scripts/build.sh`](../../scripts/build.sh) | the `--progress=<mode>` option, so a caller can ask for the per-step lines |
| [`tests/test_build_probe.sh`](../../tests/test_build_probe.sh) | 12 cases over the parsing, the emitters and the restore |
| [`tests/test_trace_build.sh`](../../tests/test_trace_build.sh) | 3 cases: the default passes `--quiet`, `plain` replaces it, and the CLI flag reaches docker |
| [`devlog/roadmap.md`](../roadmap.md) | the design row's pin scope widened, and the pinning row filed after it |
| [`devlog/discussions/20261016-study-active-invalidation_history.md`](../discussions/20261016-study-active-invalidation_history.md) | the skip-echo sentence corrected |
