---
date: 2026-11-07
milestone: M3.6.4 - The reasoning image refactor
type: Implementation
status: Closed
---

# Handover - every build input takes its class's strictest pin form

## Objective

Pin every build input at the strictest form its class supports, record what each one resolved to, and give the build a local drift warning and a blocking scan.

## Scope

The M3.6.4 row `Pin every build input, at the strictest form each input's class supports`, continued from the design exchange of 2026-11-07 recorded in handover `20261107-06`.

The design exchange settled the policy; this iteration builds it. Two inputs cannot reach the ADR's strict form and neither is a gap:

- **apt.** Debian's archive publishes a SHA256 per `.deb`, and apt has no syntax to require it, so the apt class takes the exact version in the Dockerfile and the resolved `.deb` SHA256 in the pins file. The strict form is the M7 row in `roadmap_future.md`, named as this relaxation's end.
- **the opencode platform binary.** Its postinstall downloads a platform-specific binary at install time. If the release publishes a checksum the pins file records it; otherwise the scan names the exemption and its trigger.

Out of scope: the host build runs, which are the row after this one; the M7 migration; and the bump path's automation, which the ADR's R3 asks for as a way to move a pin and which lands as the scan's `--bump` output rather than a new tool.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every input in the two Dockerfiles carries its class's form | `bash scripts/check_pins.sh`, 0 findings, and `--report` prints the fifteen inputs | Agent [x] |
| The pins file records what each input resolved to, and carries no value it does not also verify | `bash scripts/check_pins.sh --report` prints the digest, the eight `.deb` hashes, the two release checksums, the Python patch and the three lockfiles | Agent [x] |
| The gate fails on a Dockerfile version the pins file does not match, an input with no pin row, a pin with no movement path, a lockfile package with no integrity hash, and an install that is not `npm ci` | `tests/test_pins.sh`, 9 units, each failing before the fix | Agent [x] |
| The preflight warns locally and never blocks on a stale network | `tests/test_pins.sh`'s preflight unit: a mismatched pins file warns on stderr and the function returns 0 | Agent [x] |
| The shared tier installs both runtimes from committed lockfiles | `tests/test_shared_base_contract.sh`: one home per registry package, an exact version per dependency, and each install's scripts flag | Agent [x] |
| A build-only input is owned by the context gate and is not demanded by the layout gate | `tests/test_build_context_gate.sh` 9 units; `tests/test_container_layout.sh` 39 units; both gates clean | Agent [x] |
| The ADR records the relaxation with its end | the 2026-11-07 entry in `build_input_pinning.md`, with R1 and R3 amended and the M7 row named | Agent [x] |
| The suite and the lint pass | `bash scripts/run_tests.sh`: 1492 passed, 0 failed, 0 skipped; `bash scripts/lint.sh`: clean across 24 gates | Agent [x] |
| Every decision this iteration records is realized in the files | the Decisions table against the tree | Agent [x] |
| Architecture documents in scope describe the system as built | the pin ADR, the build page's `## The build inputs`, and the onboarding guide's step 2a | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The version stays in the Dockerfile and the resolved artifact stays in `src/build/pins.json`; the scan fails when the two disagree | the two carry different data, so neither restates the other. The Dockerfile cannot express a `.deb` hash, and the pins file cannot express which version to install. The comparison is the guard, and it is a derive-and-diff rather than a second copy | this record; the pin ADR entry |
| The preflight is offline and the scan is online | a network round-trip on every build is a cost with no decision attached to it: the build's own failure is the signal it needs. The local comparison catches the case that has a cheap answer, and the scan carries the re-resolution | this record; `scripts/build.sh` |
| The shared tier's lockfiles are declared by a new `build` layer in the manifest | the context gate owns every included path through `image[].source`, and a build-only input is in no image. `image` declares what lands in an image and `build` declares what the build reads, so the two layers carry two subjects | this record; the pin ADR entry |
| The apt relaxation is an ADR entry with the M7 row as its end | an amended requirement outlives the iteration, and the alternative was a policy nobody could point at | `docs/adr/build_input_pinning.md` |
| Every registry install gets its own lockfile directory under `src/reasoning/registry/`, markdownlint-cli2 included | the shared tier and the base both install registry packages, and exempting the linter would leave one install on the weaker form the policy exists to replace | `src/reasoning/registry/`; the pin ADR entry |
| An apt version is resolved across `bookworm`, `bookworm-updates` and `bookworm-security`, and the highest Debian version wins rather than the first suite read | a package and its library move together inside one suite, so a pin taken from `bookworm` alone can name a version whose dependency no longer exists, which is a broken build rather than a recorded drift | this record; the build page's `## The build inputs` |
| The Python patch is a pin whose artifact uv's own table fixes | a second record for the interpreter would restate a guarantee the tool already holds, and the patch is the part this tree decides | `src/build/pins.json`; the pin ADR entry |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The base image's Python install, `uv python install 3.11`, was an input the census never listed | audit | the pin sweep would have missed it; it now carries the exact patch and records the standalone build uv resolves | this record; `src/build/pins.json` |
| `tests/test_shared_base_contract.sh` asserted the old pin mechanism by grepping install commands, so four of its units failed on the change | test | fixed here: the units now read the registry directories and the scripts flag each install carries | this record |
| `build.sh` runs on the host, where node is not guaranteed | design | the preflight returns early when node is absent, so the warning is a nudge that a node-less host does not get; the blocking half is the in-container lint gate | this record; the Decisions table |
| The operator's first pinned build failed: `jq=1.6-2.1+deb12u2` was unsatisfiable because `libjq1` had already moved to `deb12u3` in `bookworm-security` | defect | the resolver read only `bookworm/main`, so it pinned what that suite served rather than what the image's apt installs | fixed here: the resolver reads all three suites, compares Debian versions, records the suite each version came from, and fails loudly when it cannot read one rather than resolving from the rest |
| The probe reported `cache_state: ran` for every tier of a fully cached build: BuildKit prints `DONE` for the `FROM` resolve whenever the base image is already local, and the rule counted any DONE as a ran step | defect | the cache signal, one of the four the instrument exists for, was always `ran`, so the reports could not answer "did the change rebuild what depends on it" | fixed here: only a step that changes the filesystem decides the state, with a unit over the real cached log and its paired positive |

## Completed

| File | Change |
|---|---|
| `src/reasoning/base.dockerfile` | the index digest, eight apt versions, the uv and hadolint checksums verified in their `RUN`, the Python patch, and the linter installed from its lockfile |
| `src/reasoning/runtimes.dockerfile` | both runtimes installed with `npm ci` from their lockfiles |
| `src/reasoning/registry/{markdownlint-cli2,pi,opencode}/` | three `package.json` and `package-lock.json` pairs, every resolved package carrying an integrity hash |
| `src/build/pins.json` | fifteen pins, each with its class, its resolved artifact and its way to move; the apt rows carry the suite their version came from |
| `src/build/pins.mjs`, `scripts/check_pins.sh` | the local gate, the remote drift report and the registry bump |
| `src/build/container-interface.json`, `src/build/container-interface.mjs` | the manifest's `build` layer and the check that its sources exist |
| `src/build/build-context.mjs` | the context owns the `build` sources beside the `image` ones |
| `scripts/build.sh` | the preflight's local warning |
| `tests/test_pins.sh` | 10 units over the gate's branches, the preflight and the Debian version ordering |
| `tests/test_build_context_gate.sh`, `tests/test_container_layout.sh` | the `build` layer's positive and negative in both gates |
| `tests/test_shared_base_contract.sh` | the four units that asserted the old install form |
| `scripts/lint.sh` | the pin gate registered |
| `docs/adr/build_input_pinning.md` | the 2026-11-07 relaxation entry; R1 and R3 amended |
| `docs/development/build_operational_model.md` | `## The build inputs`, the gates row and two catalog rows |
| `docs/development/provider_onboarding_guide.md` | step 2a, the pin form a new install owes |
| `devlog/roadmap.md` | the row closes |
