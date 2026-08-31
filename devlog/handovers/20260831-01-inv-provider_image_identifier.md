# Handover — 20260831-01-inv PROVIDER image identifier

**Status:** Closed
**Iteration:** 20260831-01
**Type:** inv (investigation, no code change)
**Milestone:** M2.6 - Session Persistence (post-close from 54d26d6)
**Operator task:** Investigate the PROVIDER image-identifier question deferred from 20260828-05, by answering three questions:

1. What is the general docker-compose convention for starting multiple services — specify via `image:` or `container:`?
2. What is the general docker-compose convention for defining image versions (e.g. `FROM ubuntu:24.04`) — is there a more granular container tag?
3. Do we generate similar image versions when running `make build`? What do we do with these?

**Goal of the investigation:** determine whether a meaningful image identifier can be made registry-available (i.e. stored in the `.compose/<sid>.yml` record) so `make resume --list` can show `pi (<version>)` WITHOUT a docker dependency, resolving the deferred finding.

## Objective
Answer the three questions with: (a) the general docker-compose convention, (b) how our own `make build`/compose generation actually works today, and (c) a grounded recommendation for a registry-available image identifier. Produce NO code change this iteration (investigation only).

## Scope
- IN: read-only investigation of build/compose/image tooling; answer the 3 questions; recommend an identifier approach.
- OUT: any implementation/rollout of an identifier; changing `--list`; writing new docker-compose behavior.

## Carried forward
- Deferred from 20260828-05: PROVIDER image identifier (container-sig display rolled back; `pi [IMAGE_STALE]` is current).
- Standing: SERVE mode integration (roadmap); Bug E (`make stop` template + duplicate-ID); contextual-knowledge-light naming (conventions fold).

## Acceptance criteria
- AC1: Q1 answered — docker-compose convention for multiple services (`image:` vs `container_name:`/container reference), grounded.
- AC2: Q2 answered — docker-compose image versioning/tagging convention incl. finer-than-`:24.04` forms (tag vs digest), grounded.
- AC3: Q3 answered — how our `make build` produces/nannames images today and what happens to them.
- AC4: Recommendation: whether/how a meaningful, ideally registry-available image identifier could feed `--list` without a docker dependency.

## Hot files
- `src/build/image.sh`, `scripts/build.sh`, `src/build/compose.sh`, `src/build/docker-compose.yml`, capability/reasoning dockerfiles, `src/libs/container_sig.sh`, `src/libs/session_inventory.sh`, `scripts/resume_agent.sh`.

## Findings
- **Q1 (services convention):** a Compose `services:` service chooses its image via `image:` (pre-built tag) or `build:` (build-and-use, optionally also tagging with `image:`). `container_name:` is a SEPARATE, optional field that ONLY names the container *instance* (compose derives `<project>-<service>-<n>` otherwise); it never selects the image. Convention: use `image:`/`build:` to pick the image; reserve `container_name:` for when stable container identity is needed (our start/resume/stop do). Our `src/build/docker-compose.yml` does both: `image: {{…IMAGE_NAME}}` (selects built tag) + `container_name: {{…CONTAINER_NAME}}` (stable `<project>-<service>-<session-id>`).
- **Q2 (image versions / granularity):** Docker identity = `<repo>:<tag>` or `<repo>@<digest>`. Tags are mutable pointers (versioning schemes: semver, `<date>`, `<ref>-<sha7>`); the most granular/atomic form is the content **digest** `<repo>@sha256:<64hex>` (immutable, content-addressed). Even finer than a tag: build-time metadata labels (e.g. our own `agent-sandbox.container-sig`), which are not part of the tag/digest string.
- **Q3 (our `make build` produces versions? no):** images are tagged with the FIXED names `sandbox-<project>` and `<provider>-agent-<project>` — a mutable tag, re-tagged/overwritten on every build; NO version/date/sha component. The content `container-sig` is injected ONLY as a `--label` on the image, not in the tag. What we do with them: `make start` -> compose `image:` -> `docker compose up -d` runs them; `preflight` does `docker image inspect` (existence + `container-sig` staleness); `prune`/`resume --list` compute `[IMAGE_STALE]` from the baked label; removal via `docker image rm`. Because content identity is only a label, it is invisible to the `.yml` record -> the docker dependency 20260828-05 deferred.
- **Q4 / recommendation:** to surface a meaningful image identifier registry-available (no docker), bake the IMAGE CONTAINER-SIG into the `.compose/<sid>.yml` record at record-generation time as a new `x-session-labels` key (pattern-already-established: `agent-sandbox.host-head-sha`). Then `--list` reads it via the existing `record_label` path and shows `pi (<short-sig>)` with zero docker. Design nuance pending: the build tags the mutable name + `container-sig` label; the record-gen must obtain the BAKED sig (the one on the actual loaded image) without docker. Two candidate sources: (a) at build time write the sig to a side artifact readable by record-gen, or (b) reuse `current_sig` computed from source at record-gen (docker-free) — (b) reflects CURRENT source, approximate to the baked sig, cheap, but diverges if the running image predates source changes. Recommend investigating (a) for fidelity; (b) as a cheap fallback.

- AC1 MET: compose `image:` (or `build:`) selects the image; `container_name:` only names the container instance.
- AC2 MET: digest `@sha256:` is the atomic/most-granular form; tags are mutable version pointers; labels are even finer metadata (our `container-sig` is a label).
- AC3 MET: `make build` uses fixed mutable tags (`sandbox-<project>`, `<provider>-agent-<project>`), no version; `container-sig` is a label only; images consumed by compose/preflight/prune.
- AC4 MET (recommendation, no code change this iteration): bake image `container-sig` into the `.yml` record at gen-time as a new label (pattern = `host-head-sha`), read via `record_label`; docker-free. Design nuance (how record-gen obtains the BAKED sig without docker) pending.

## Deferred items
- Implementation of the baked-sig-into-record identifier (record-gen source of the baked sig: side-artifact vs current_sig fallback) -- next iteration if operator approves.
- Standing: SERVE mode integration (roadmap); Bug E (`make stop` template + duplicate-ID); contextual-knowledge-light naming fold.

## What's Next
M2.6 - Session Persistence. Investigation answer delivered (no code change).
Recommended next step (operator decision): an `impl` iteration to bake the image `container-sig` into the `.yml` record as a new `x-session-labels` key and surface `pi (<short-sig>)` in `--list` via `record_label` (docker-free). Open design question: how record-gen obtains the BAKED sig (side-artifact written at build vs docker-free `current_sig` fallback). Alternative: close this thread and move to SERVE/Bug E.
Watch-outs: dual-grep bridge; full-tree close-out greps.