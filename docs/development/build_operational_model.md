# The Build's Operational Model

The reasoning image is the product of a build. The Dockerfile is the engineering source, `docker build` is the production run, and the image is what the run produces. This page states what the production run must answer, the signal that answers each question, the domain cases the model covers, and the signals deferred until a condition brings them in.

The requirements the run is judged against are the ADRs: [`reasoning_layer_tiers.md`](../adr/reasoning_layer_tiers.md) for the tier shape, [`build_input_pinning.md`](../adr/build_input_pinning.md) for the pinned inputs, and [`harness_versioning.md`](../adr/harness_versioning.md) for the image identity. The evidence for this model is the audit handover [`20261107-02-audit-build_contract_gap.md`](../../devlog/handovers/M3.6.4/20261107-02-audit-build_contract_gap.md), whose gap map and findings the record keeps. The page explains how the build meets those requirements; it does not restate them.

The layout is an implementation outcome, judged by the production run. A layout question is settled by what the run measures, not by what the Dockerfile looks like.

## The four questions

| Question | Signal | Source | Decision it supports |
|---|---|---|---|
| What did the build produce? | each tier's image ID and size, the git HEAD, and the Dockerfile hashes | `docker image inspect`; `git rev-parse`; `sha256sum` | is the artifact the intended one, and did it change? |
| What did the cache do? | each tier's cache state, the step that ran, and its step seconds | the `--progress=plain` log | did the change rebuild what depends on it, and nothing else? |
| Did it fail? | the exit status, the failing step, and the log | the build's exit status and its log | is the failure actionable, and where did it stop? |
| What did it cost? | the wall seconds, the step seconds, and the image size | the log and `docker image inspect` | is the build affordable to iterate? |

## The three layers

The production run is measured by [`scripts/build_probe.sh`](../../scripts/build_probe.sh) on the host, because the agent's container has no Docker by design. The static wiring is a unit test in the container, because a wiring defect is cheap to catch without a build: the flag reaches each tier, the provider selects its tier, the pin has one home, and the manifest is the only COPY declaration. The e2e is the dry-run, which proves the image starts and the agent runs; the general verification surface is M3.4.5's.

| Layer | What it proves | Where |
|---|---|---|
| the production run | the artifact, the cache, the cost and the failure | [`scripts/build.sh`](../../scripts/build.sh) and the recorder |
| the static wiring | the tier selection, the flag, the pin, the context, the COPY declaration | the container's unit tests |
| the e2e | the image starts and the agent runs | the dry-run, M3.4.5's surface |
| the gates | the manifest and the Dockerfiles agree; the context is the declared inputs; the pins and the Dockerfiles agree; the prose and links lint | [`check_container_layout.sh`](../../scripts/check_container_layout.sh); [`check_build_context.sh`](../../scripts/check_build_context.sh); [`check_pins.sh`](../../scripts/check_pins.sh); [`lint.sh`](../../scripts/lint.sh) |

The recorder does not grep a Dockerfile, the static test does not measure a build, and the dry-run does not measure the build's cost. Each layer reads the evidence that exists at its own point.

## The build context

The context's declared inputs are the manifest's `image[].source` and `build[].source` rows, plus every `COPY` source in every Dockerfile the repository builds. Both builds share the repository root as context, so the ignore file must serve both: a path the reasoning images never copy is still the capability image's input. `.dockerignore` is the complement of that union, so the context carries the sources, the dockerfiles and the ignore file, and nothing else. [`scripts/check_build_context.sh`](../../scripts/check_build_context.sh) holds the two equal in both directions: a source the ignore file would exclude, or an included path no source owns, is a finding. It prints the context's file count and bytes, so a widening shows as a number before a host run.

## The build inputs

Every input the build reads is pinned to the artifact it resolved to, and [`src/build/pins.json`](../../src/build/pins.json) records what that was. The Dockerfile carries the request; the pins file carries the artifact. [`scripts/check_pins.sh`](../../scripts/check_pins.sh) reads the request back out of the Dockerfiles and lockfiles and fails when the two disagree, so neither is a second copy of the other.

| Input class | What the Dockerfile carries | What the pins file records |
|---|---|---|
| a base image | the tag and the index digest | the digest and its media type |
| an apt package | the exact version, at the highest the three suites the image's apt reads resolve to | the resolved `.deb` SHA256 and the suite it came from |
| an archive or a binary fetched by URL | the release tag, and the checksum verified in the same `RUN` | the publisher's checksum |
| a registry package | nothing: the committed lockfile is the request | the resolved integrity hash and the lockfile |
| the Python build | the exact 3.11 patch | the standalone build uv resolves it to |

An apt pin has to be resolved across `bookworm`, `bookworm-updates` and `bookworm-security`, not from `bookworm` alone: a security update lands in the last of those first, and a package pinned behind its own library makes the set unsatisfiable. The scan therefore compares Debian versions rather than preferring a suite, and it fails loudly when it cannot read one rather than resolving from the others.

Two classes cannot reach the digest form on this base, and neither is an omission. Debian's archive publishes a SHA256 per `.deb` and apt has no syntax to require it, so the version is what apt enforces and the recorded hash is what the gate compares. The Python build is chosen by uv from its own table, so the pin fixes the patch and uv verifies the download. The strict form for the first is the M7 row in [`roadmap_future.md`](../../devlog/roadmap_future.md) that moves the base to one whose package set is content-addressed.

The pins file also carries how to move each pin. A pin with no way to move freezes its own vulnerabilities, so the gate fails a row with no movement path, and `--remote` re-resolves every input against its registry: a moved artifact is reported as drift rather than as a broken build, and `--write` records it.

The build's own nudge is cheaper. [`scripts/build.sh`](../../scripts/build.sh)'s preflight compares the Dockerfiles against the pins file locally and warns, because a network round-trip on every build is a cost with no decision attached to it. The blocking half is the lint gate.

## The domain catalog

The frequency bands are the audit's, from the 2026-11-07 log boundary; they order the cases, they are not counts.

| Subject | Case | Frequency | Requirement | Signal |
|---|---|---|---|---|
| first build | a cold host, an empty cache | rare | the image builds from a clean tree | the baseline record; the exit status |
| rebuild | no input changed | frequent | every tier is served from the layer cache | `cache_state=cached`; the wall seconds |
| rebuild | a pin bump | occasional | the shared tier and both provider images change | the image ID delta across two records |
| rebuild | a provider payload change | frequent | only the provider image changes | the image ID delta; the cache state |
| rebuild | a tier-1 change | occasional | tiers 2 and 3 rebuild | the cache state |
| rebuild | `--rebuild` | occasional | every tier runs from scratch | the static propagation test; the wall seconds |
| dirty tree | the delta run | frequent in development | the run records the dirty inputs | `repo.dirty`; the Dockerfile hashes; the HEAD |
| failure | a failed step | occasional | the exit status and the failing step are recorded | the exit status; the log |
| second provider | opencode beside pi | occasional | the provider selects its tier | the static test |
| boundary | the agent reads the report | every run | the report crosses through the input channel | the report path |
| security | pins, the non-root user, no secrets | every build | the pin policy holds; the image runs as the agent user | the pin gate; the static tests |
| pin drift | a republished or moved artifact | rare | the drift is reported rather than silent | the scan's `--remote` output; the preflight warning |
| layer locking | the cache key and copy-in | every build | the COPY declarations are the manifest's | the layout gate |
| context | the context set | every build | only the declared inputs travel to the builder | the check's files and bytes |
| concurrency | two builds on one host | rare | one build's cache is not corrupted by another's | deferred; the trigger is a second concurrent build |

## What the recorder writes

One JSON object per run, at `<input-dir>/build/<timestamp>.json`:

<!-- snippet: illustrative -->
```json
{
  "probe": "build_probe",
  "format": 2,
  "timestamp": "20261107T120000Z",
  "label": "baseline",
  "repo": {"root": "/path/to/repo", "head": "abc123", "dirty": false},
  "host": {"uname": "Linux x86_64", "docker": "Docker version 27.0.0"},
  "provider": "pi",
  "project": "probe",
  "run": {
    "no_cache": false,
    "exit_status": 0,
    "wall_seconds": 42,
    "error": "",
    "log": "/path/to/run/build.log"
  },
  "images": {"tier1": "agent-base", "tier2": "agent-runtimes", "tier3": "pi-agent-probe"},
  "dockerfiles": [{"path": "src/reasoning/base.dockerfile", "sha256": "..."}],
  "tiers": [
    {
      "name": "agent-base",
      "tier": 1,
      "id": "sha256:...",
      "size_bytes": 123456789,
      "cache_state": "cached",
      "step_seconds": 0.0
    }
  ]
}
```

| Field | Holds | Source |
|---|---|---|
| `probe`, `format` | the record's identity and its schema version | the recorder |
| `timestamp`, `label` | the run's time and the operator's baseline or delta label | the recorder |
| `repo` | the root, the HEAD and whether the tree was dirty | `git` |
| `host` | the kernel and the docker version | `uname`; `docker --version` |
| `run` | the no-cache flag, the exit status, the wall seconds, the last error and the log path | the build |
| `provider`, `project` | the chain and the image tag | the arguments |
| `images` | the three tier names | [`image.sh`](../../src/build/image.sh) |
| `dockerfiles` | each reasoning Dockerfile and its sha256 | the tree |
| `tiers` | each tier's name, number, image ID, size, cache state and step seconds | `docker image inspect`; the log |

## The host run

Two records make a measurement. Run the recorder on a clean tree for the baseline, make one change, a pin bump or a payload change, and run it again for the delta. Compare the two records: the image IDs show what the change rebuilt, the sizes show what it added, the cache states show what it skipped, and the step seconds show what it cost. A single record is a snapshot; the pair is the measurement.

The agent reads the report from the input channel at `/home/agentuser/workspace/input/build/<timestamp>.json`. The run command and its options are the recorder's `--help`.

## Deferred signals

| Signal | The trigger that brings it in |
|---|---|
| SBOM | a registry or a distributed image exists |
| vulnerability scan | a security requirement names a tool or a CVE gate |
| provenance and signing | images leave the host |
| p50/p95 over runs | enough runs exist to make a distribution meaningful |
| change correlation | a build-cost regression needs attribution |
| reproducibility as a standing gate | CI builds the same commit twice |
| concurrency | two builds on one host become common |

## What this page does not own

The requirements belong to the three ADRs. The e2e belongs to M3.4.5's verification surface. The dispatch measurement belongs to M3.6.2. The audit study holds the evidence and the gap map, and the [roadmap](../../devlog/roadmap.md) holds the work that remains.
