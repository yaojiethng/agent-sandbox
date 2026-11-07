---
date: 2026-11-07
milestone: M3.6.4 - The reasoning image refactor
type: Implementation
status: Closed
---

# Handover - The runtime tier ships one pinned OpenCode binary

## Objective

Replace the OpenCode npm install in the shared tier with the pinned platform tarball, so the tier carries one verified executable instead of a package manager's platform matrix and its cache.

## Scope

Continues the host run of [`20261107-08`](20261107-08-impl-host_run_three_tiers.md), which measured the pin's cost at +209MB on `agent-runtimes` and filed it as a row. This record closes that row.

In scope: the two install steps in `src/reasoning/runtimes.dockerfile`, the pin row for OpenCode and its gate, `src/reasoning/registry/opencode/`, and the documents that state what the tier installs. pi keeps its frozen lockfile install and gains the cache clean, because the same layer problem holds there.

Out of scope: pi's install shape, which is a real dependency tree and needs its lockfile; the baseline binary's CPU features, which this decision makes moot; and any change to the provider images, which copy none of this.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The tier installs one binary and no npm tree for OpenCode | `bash tests/test_shared_base_contract.sh`; the install-command scan finds no `opencode-ai`, and the `RUN` carries the fetch, the checksum, the install and the link | Agent [x] |
| The binary is the one the npm route produced | its `sha256` `541bb0aa88d0b317967efbc947aa54506606c257d3b6ed1dee644756879fb4be` equals the platform package's `bin/opencode` and the file the postinstall placed at `opencode-ai/bin/opencode.exe` | Agent [x] |
| The installed binary runs | the extracted file prints `1.19.1` on `--version` | Agent [x] |
| The pin moves class and the gate holds it | `bash scripts/check_pins.sh`; clean, and `--report` carries one `opencode` row of class `url-artifact` | Agent [x] |
| The deleted registry directory leaves no carrier | `bash scripts/check_build_context.sh`; clean at 243 files, and no live document names `src/reasoning/registry/opencode/` | Agent [x] |
| The decision is recorded where the next reader looks | the dated ADR entry, the model page's input class note, and the marker on the tier entry it supersedes | Agent [x] |
| The tier records the saving on the host | `20261107T161651Z.json`: `agent-runtimes` 264.7MiB against the pin's 703.7MiB, and its history shows the opencode step as one 186MB layer with no `opencode-ai` install | Agent [x] |
| The suite and the lint pass | `bash scripts/run_tests.sh`; `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| OpenCode leaves the `registry-package` class and joins `url-artifact` | the class cannot reach one artifact for a package that names a binary per platform and per libc, and the failure is in `npm ci`, not in the pin | [`build_input_pinning.md`](../../../docs/adr/build_input_pinning.md) |
| The artifact is the registry tarball, not a GitHub release asset | the same binary, under a digest the pins file records, with no second publisher's naming scheme to track | the ADR entry |
| The `--remote` half downloads the tarball and hashes it | this publisher ships no checksum file, so the hash has to come from the bytes | `src/build/pins.mjs` |
| pi's install keeps its lockfile and gains `npm cache clean --force` in the same `RUN` | the cache is 28MB of tarballs beside the tree they unpacked into, and a second layer would not shrink the image | this record; the Dockerfile |
| The variants are removed by not installing them rather than by pruning after | 376MB of pruning leaves the baseline copy, the cache and the install machinery behind, and hides why they were there | the ADR entry |

## Decisions pending

None.

## Findings

| Finding | Triaged to |
|---|---|
| The recorded pair reads 703.7MiB -> 264.7MiB on the runtime tier, and the base reads 182.5MiB in both runs, so the whole movement is the opencode step and nothing else in the tree changed size | this record; the closed roadmap row |
| The 16:16 run rebuilt nothing -- every tier reports `cached` over 1s -- so it measures images built minutes earlier from the same commit rather than layers this run produced. The history is what makes that safe to read: the opencode layer is the new one-RUN fetch, and no `opencode-ai` install remains | this record, which states which half the probe proved and which the history did |
| `npm ci --libc=glibc` filters nothing; `npm install --libc=glibc` filters correctly but writes a lockfile that still lists every platform, so the next `ci` installs them again | the ADR entry's rejected alternatives, which record the measurement rather than the reasoning alone |
| The measured install was 730MB, while the host run's delta was +209MB: the variants predate the pin, and the pin's own addition was the cache | this record's Scope; the closed roadmap row |
| The lockfile for a package with per-platform binaries records the whole matrix whoever generates it, so `npm ci` is the wrong installer for any runtime that publishes binaries this way | `build_input_pinning.md`, which states the class's reach |

## Completed

| File | Change |
|---|---|
| `src/reasoning/runtimes.dockerfile` | the OpenCode step fetches, verifies and installs one binary; both installs clean npm's cache in their own layer |
| `src/reasoning/registry/opencode/` | deleted, with the lockfile it held |
| `src/build/pins.json` | the `npm:opencode` row becomes an `opencode` row of class `url-artifact` |
| `src/build/pins.mjs` | `opencode` joins the URL inputs, and the remote half hashes the artifact where the publisher ships no checksum |
| `tests/test_shared_base_contract.sh` | the postinstall test becomes the pinned-binary contract, and the dead opencode-ai readers go |
| `tests/test_pins.sh` | the report and integrity fixtures read the registry packages that remain |
| `docs/adr/build_input_pinning.md` | the dated entry, with the three rejected alternatives |
| `docs/adr/reasoning_layer_tiers.md` | the superseded marker on the tier entry's OpenCode claim |
| `docs/development/build_operational_model.md` | the input class note, with why OpenCode is the URL row |
| `devlog/roadmap.md` | the 209MB row closes with the measured outcome |
| `devlog/handovers/M3.6.4/20261107-11-impl-opencode_pinned_binary.md` | this record |
