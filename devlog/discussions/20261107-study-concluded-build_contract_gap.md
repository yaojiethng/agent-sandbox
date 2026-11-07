# The build contract, instrument and catalog: a gap map

**Status:** concluded

## Direction and parent story

This study is the M3.6.4 audit. The operator's frame is to delegate the Docker
and provider-harness layout to an agent, and to keep the ability to judge and
refine it. That needs three things stated before the layout is delegated: the
build's requirements, instrumentation aimed at those requirements, and a
catalog of the domain facts and edge cases. The audit asks which of the three
already exist and which are gaps. It writes no requirements and no instrument;
it produces the gap map the next iterations consume. Parent row:
[`devlog/roadmap.md`](../roadmap.md#m364---the-reasoning-image-refactor).

The audit answers three questions. Are the requirements well understood? Is
there instrumentation that targets the qualities we care about, so unsatisfactory
work can be refined? Is there a record of the edge cases, user flows and
requirements: fast against slow, frequent against infrequent, security, layer
locking, and copy-in?

## Required reading

- [`src/reasoning/base.dockerfile`](../../src/reasoning/base.dockerfile) -- tier 1, `agent-base`
- [`src/reasoning/runtimes.dockerfile`](../../src/reasoning/runtimes.dockerfile) -- tier 2, `agent-runtimes`
- [`src/reasoning/providers/hermes/base.dockerfile`](../../src/reasoning/providers/hermes/base.dockerfile) -- the source-built tier 2, `hermes-base`
- [`src/reasoning/providers/pi/provider.dockerfile`](../../src/reasoning/providers/pi/provider.dockerfile) -- the pi image
- [`src/reasoning/providers/opencode/provider.dockerfile`](../../src/reasoning/providers/opencode/provider.dockerfile) -- the opencode image
- [`src/reasoning/providers/hermes/provider.dockerfile`](../../src/reasoning/providers/hermes/provider.dockerfile) -- the hermes image
- [`src/build/container-interface.json`](../../src/build/container-interface.json) -- the COPY and ENV declaration
- [`scripts/build.sh`](../../scripts/build.sh) -- the build orchestrator
- [`scripts/build_probe.sh`](../../scripts/build_probe.sh) -- the existing instrument
- [`scripts/check_container_layout.sh`](../../scripts/check_container_layout.sh) -- the layout gate
- [`docs/adr/reasoning_layer_tiers.md`](../../docs/adr/reasoning_layer_tiers.md) -- the tier requirements
- [`docs/adr/build_input_pinning.md`](../../docs/adr/build_input_pinning.md) -- the pin policy
- [`docs/adr/harness_versioning.md`](../../docs/adr/harness_versioning.md) -- image identity
- [`docs/reference/tool_interface.md`](../../docs/reference/tool_interface.md) -- the image, build and provider contract
- [`docs/development/provider_onboarding_guide.md`](../../docs/development/provider_onboarding_guide.md) -- the provider flow
- [`devlog/discussions/20261016-study-settled-install_step_census.md`](20261016-study-settled-install_step_census.md) -- the install and copy census
- [`devlog/discussions/20261016-study-settled-invalidation_history.md`](20261016-study-settled-invalidation_history.md) -- the invalidation history
- [`$AGENT_HOME/agent/sessions/`](../../../.pi/agent/sessions/) -- the old conversation logs
- [`reflect`](../../../.pi/agent/skills/reflect/SKILL.md) -- the transcript-location method

## Method

The audit read the six Dockerfiles, the manifest, the build script, the probe
and the layout gate; ran the five build tests and the layout gate; read the two
host reports under `$INPUT_DIR/build/`; and mined the session store with the
`reflect` skill's transcript-location method. It changed no live build file.

The session-store boundary is every `*.jsonl` transcript whose filename date is
before `2026-11-07`, the audit's date, so the audit's own session is excluded.
On that boundary the store held 798 transcripts. The store path is
`$AGENT_HOME/agent/sessions/`; the pi layout is one directory per workspace,
with one `*.jsonl` per session inside it. The `reflect` skill's `ls -t` form
over `<agent-transcripts>/*.jsonl` and `<agent-transcripts>/*/*.jsonl` resolves
the same set.

## Summary

The build's requirements are stated, but they are spread over two ADRs, one
identity ADR and the tool interface, and several are only in the old
conversation logs. The instrument measures the layer-cache rule and the
manifest layout; it does not measure the pin, copy-in, security, frequency or
concurrency requirements. The domain catalog exists in fragments in the tool
interface and the provider guide; the edge cases and frequencies live only in
the logs and a stale study. The only host baseline predates the current shape.
The gap map in section 9 sequences the work.

## Findings

### 1. The build as it stands

The reasoning layer is four tiers by kind, and three images in a provider's
build chain.

| Tier | Image | Dockerfile | Contents | Pin state |
|---|---|---|---|---|
| 1 | `agent-base` | `base.dockerfile` | `node:22.22.3-slim`, the apt set, uv, Python 3.11, hadolint, markdownlint-cli2 | node tag without a digest; apt, uv and Python patch unpinned; hadolint tag; markdownlint exact |
| 2 | `agent-runtimes` | `runtimes.dockerfile` | `pi-coding-agent@1.3.0`, `opencode-ai@1.19.1` | exact npm versions; no lockfile or integrity hash |
| 2 (hermes) | `hermes-base` | `providers/hermes/base.dockerfile` | apt `gcc` and `libffi-dev`, a clone at default-branch HEAD, a uv venv with `.[all]`, npm `--omit=dev`, apt `ffmpeg` | unpinned clone, pip and npm resolutions; only the base-image arg is fixed |
| 3 | `<provider>-agent-<project>` | `providers/<provider>/provider.dockerfile` | the manifest's COPY pairs, ENV, `USER agentuser` | the repository working tree, which the pin policy excludes by name |

The pi image carries nine COPY pairs, and the opencode and hermes images carry
three each. The manifest declares all nine, and the layout gate is clean. The
`docs/policies/` rows the 2026-10-16 census lists are gone: no current
Dockerfile copies that directory, so the census is a digest, not a source.

`scripts/build.sh` builds every tier on every call. Tier 1 and tier 2 receive
`--no-cache` when the caller sets `--rebuild`; tier 3's build call passes the
empty string for `no_cache`, so the flag stops at tier 2. That is what the
script's own comment says: `--no-cache: rebuild tiers 1 and 2 from scratch`.

### 2. The requirements

The tables below read the requirements from the ADRs and the tool interface,
and add the requirements the old logs state.

| Id | Requirement | State | Source |
|---|---|---|---|
| R1 | A tier's contents are decided by kind, not by provider | stated | `reasoning_layer_tiers.md` R1 |
| R2 | An agent-runtime installs exactly once | stated | R2 |
| R3 | The common payload is declared exactly once | stated; implemented by the manifest and the gate | R3 |
| R4 | Docker's layer cache is the only reuse rule | stated; implemented | R4 |
| R5 | A provider base installs only its own differential | stated; implemented for hermes | R5 |
| R6 | The tier list is the same for every provider that shares an install mechanism | stated; implemented | R6 |
| P1 | A pin fixes the resolved artifact, not the requested name | stated; not implemented | `build_input_pinning.md` R1 |
| P2 | One pin form per input class | stated; not implemented | P2 |
| P3 | Every pin is paired with a way to move it | stated; the bump path and scan are an open row | P3 |
| P4 | A working-tree input is excluded by name | stated | P4 |
| P5 | A missing or failing pin fails the build | stated; no check exists | P5 |
| H1 | The image identity is the docker image digest | stated; the build stamps the contract label and the probe records the image id | `harness_versioning.md` |
| H2 | A digest-less image is a hard error | stated; the check is the dry-run roundtrip, not the build | `harness_versioning.md` |
| B1 | The image names follow `<provider>-agent-<project>` | stated; tested | `tool_interface.md`, `test_image_names.sh` |
| B2 | `REBUILD=1` rebuilds everything from scratch; `REFRESH=1` reuses the base; `FAST=1` skips a rebuild | stated; the build applies `--no-cache` to tiers 1 and 2 only | `tool_interface.md`; the logs, 2026-09-12 and 2026-08-18 |
| B3 | A COPY or ENV line needs a manifest row in the same change | stated; enforced | `tool_interface.md`; the layout gate |
| B4 | No secret reaches an image | stated; no scan exists | `tool_interface.md` |
| B5 | The build runs on the host; the agent's container has no Docker | stated; the probe is host-run | `scripts/build_probe.sh` header |
| B6 | The build context is the repository root; a `.dockerignore` is worth adding | stated as a consequence of R4; no `.dockerignore` exists | `reasoning_layer_tiers.md`, 2026-10-16 entry |

The old logs add requirements that no current document states:

| Date | Requirement | Where it now lives |
|---|---|---|
| 2026-08-10 | a provider update does not need a docker rebuild; a package install inside the container updates it | not stated; the current model is rebuild-only |
| 2026-08-18 | a fresh session should start from the freshest container, and the harness should downgrade an unnecessary `--rebuild` to `--refresh` or a no-op | the `REFRESH`/`REBUILD` flags, but not the downgrade |
| 2026-08-31 | the image identity is the docker digest everywhere; the digest captures the dependency versions | `harness_versioning.md` |
| 2026-09-12 | the default is a cached build; `--rebuild` explicitly passes no-cache; `--fast` skips a rebuild | `REBUILD`/`FAST` in the tool interface; the build's tier-3 no-cache is not covered |
| 2026-09-12 | the copy-in of `settings.json` and the model catalog must not leave stale state | the manifest's `provision` row; no check |
| 2026-10-04 | one manifest declares the layout, and the Dockerfile reads it rather than a template | `container-interface.json` and the gate |
| 2026-10-15 | a lockfile per agent-runtime, installed frozen, is the pin form for a registry package | the pin policy, not implemented |
| 2026-10-16 | the runtime tier holds all registry-package agent-runtimes; a source build keeps its own base | the four-tier ADR |
| 2026-10-16 | the host probe is run by the operator and writes to `$INPUT_DIR/build/` | the probe and the host row |
| 2026-10-16 | M3.6.4 directly succeeds M3.6.1 and holds the pin, probe and tier work | the roadmap |
| 2026-11-05 | the Dockerfiles and compose files are clean | not answered by this audit |

### 3. The instrument

| Requirement | Instrument | State |
|---|---|---|
| R4, the layer cache is the only reuse rule | `scripts/build_probe.sh`'s five rows: baseline, mtime, content, restore, no-cache; `tests/test_build_probe.sh` (14 cases) | measured; the only two host reports are from 2026-10-16 |
| R3, the manifest layout | `scripts/check_container_layout.sh`; `tests/test_container_layout.sh` (37 cases) | measured; clean |
| B1, the image names | `tests/test_image_names.sh` (8 cases) | measured |
| the build order | `tests/test_trace_build.sh` (17 cases) | measured |
| the tier contract | `tests/test_shared_base_contract.sh` (8 cases) | measured |
| P1-P5, the pin forms | none: no digest, lockfile, checksum, snapshot or frozen-install check | missing |
| H1-H2, the image digest | the probe records `images.<name>.id`; the dry-run roundtrip is M3.4.5's | partial: the build's instrument does not assert the label |
| B2, `--rebuild` | the probe's `no-cache` row | partial: it observes a tier-3 step because the base changed, not because the layer was uncached; the build passes no-cache to tiers 1 and 2 only |
| B6, the context | none; no `.dockerignore` | missing |
| P4, the working-tree inputs | the manifest excludes them by name; no context-size or file-set check | partial |
| B4, no secrets | no secret scan; the Dockerfiles run as `agentuser` and copy no env file | partial |
| frequency: fast against slow, frequent against infrequent | the 2026-10-16 invalidation study | stale: it measures the old three-tier shape |
| concurrency and layer locking | none | missing |
| the probe's two refactor rows | the roadmap names a pi-pin bump row and a size row; `ROWS` has five rows and `image_fields` records `id` only | missing |
| the domain catalog | none | missing |

The probe's `ROWS` comments and the roadmap's acceptance criteria disagree.
The roadmap says two rows were added for this refactor: one bumps the pi pin and
asserts the opencode image rebuilds while every hermes layer stays `CACHED`, and
one records `docker image inspect --format '{{.Size}}'` per image. The current
`ROWS` array has five rows, `tests/test_build_probe.sh` asserts five, and
`row_json` records no size. The two rows the roadmap names do not exist. Both are not checks. The static wiring (which tier a provider inherits, where the pin lives) is a unit test on `build.sh` and the Dockerfiles; the host row is a measurement of the digest delta, not a rebuild assertion. The size is a recorded baseline, not a pass/fail. The current `mtime` and `restore` rows re-test Docker's content-addressed cache, and the `no-cache` row cannot fail for the reason it claims, because the base change forces the tier-3 observation.

### 4. The catalog

| Subject | State | Source |
|---|---|---|
| user flows: first build, rebuild, refresh, fast, dry-run, onboarding | stated | `tool_interface.md`; `provider_onboarding_guide.md` |
| operations: build all, build one provider, probe run, onboard | stated | `tool_interface.md` |
| fast against slow: the `FAST`/`REFRESH`/`REBUILD` semantics | partial: the flags are stated, the target times are not | `tool_interface.md`; the probe's wall and step seconds |
| frequent against infrequent: which inputs change, and how often | stale | the 2026-10-16 invalidation study |
| security: pins, checksums, the non-root user, no secrets, the build context | partial: the policy is stated, the checks are missing | `build_input_pinning.md`; the Dockerfiles' `USER agentuser` |
| layer locking: the cache key, the probe's perturbation, concurrent builds | partial: the cache is stated and probed; concurrency is unstated and untested | `reasoning_layer_tiers.md`; `build_probe.sh` |
| copy-in: the manifest, the COPY pairs, the provision row, the mounts, the context | partial: the pairs are declared and gated; the content and the context are not checked | `container-interface.json`; the layout gate |
| edge cases: dirty tree, no Docker, WSL2, partial build, network failure, name collision, stale image, `tar: File exists` | only in the old logs and the handover record | the logs; `devlog/handovers/` |

The operation and user-flow rows are derivable from `tool_interface.md` and the manifest; the edge-case, frequency and security rows are prose, because the tree does not carry them. The requirements-and-catalog row names which parts a generator produces and which are written.

The old logs carry the edge cases the documents do not. The probe refuses a
dirty tree and restores the Dockerfile on an interrupt; the agent's container
has no Docker by design; the first probe run produced no per-step lines because
`build_image` used `--quiet`, which is why the probe asks for `plain`; a
`make build --target=...` invocation failed as an unknown argument; a copy
delivery failed with `tar: ... Cannot open: File exists`; and the model catalog
cache was stale after a copy-in. Each is a catalog row with no current owner.

### 5. The old conversation logs

The store held 820 transcripts on 2026-11-07; 798 predate the audit. The
build-term transcript counts over that boundary are 270 for `scripts/build.sh`,
187 for `docker build`, 86 for `build_probe`, 65 for `Building image:` and 7 for
the current `Image up to date` string. In the main workspace, 231 unique
user-role messages across 127 transcripts match a strong build term; the
operator's own messages are the ones quoted below, and the subagent briefs in
the same set are not evidence.

The mining found requirements the documents do not hold. The table in section 2
names them by date. The load-bearing ones are:

- 2026-08-18: "agent-sandbox should be able to detect when --rebuild is not
  necessary, and downgrade it to a --refresh or no-op. the end result to the
  user is the same, the user expects a container that is never stale".
- 2026-08-31: "use docker image digest everywhere ... image also captures stuff
  like dependency versions ... currently not tracked, thats a leak".
- 2026-09-12: "rebuild is the default - but we use cache layers if they exist
  (whereas --rebuild flag explicitly passes NO_CACHE)".
- 2026-09-12: "always refresh UNLESS --fast ... fast should be a looser
  invocation, a run without triggering a rebuild".
- 2026-10-04: "a unified dockerfile manifest ... the dockerfile programmatically
  read the map ... COPY $src_var $dest_var".
- 2026-10-16: "why not just create a lockfile each for pi and opencode, and
  install from the lockfile? that way, we get pinned dependencies".
- 2026-10-16: the four-tier ruling: the shared tier holds the registry-package
  agent-runtimes, hermes keeps a base because its install is a source build.
- 2026-11-05: "dockerfiles clean? compose files?".

The logs are evidence, not a source of truth. A log figure names its transcript
set and date boundary; a count is a count of transcripts or messages, not of
builds. The store is live, so the numbers above name 2026-11-07.

### 6. The host evidence

Two host reports exist, both from 2026-10-16:
`20261016T084655Z.json` and `20261016T090725Z.json`. Both name the old
three-tier images `agent-base`, `pi-base` and `pi-agent-probe`, and both record
the removed `build_key` field. The first run had `step_seconds: 0` on every
row because the builder used `--quiet`; the second run is the settled one, with
`step_seconds` recorded, and its `no-cache` row is 77 seconds wall and 75.4
seconds of steps. Neither report measures the current shape, the `agent-runtimes`
tier, the optional hermes base, the pin coverage, the copy-in or the context.

The probe's own matrix on the current tree is unrun. The audit cannot run it:
this container has no Docker by design, and the probe refuses a dirty tree.

### 7. Source or digest

| Record | Class | Why |
|---|---|---|
| `reasoning_layer_tiers.md` | source | the tier requirements and the date-stamped decisions |
| `build_input_pinning.md` | source | the pin requirements and the input classes |
| `harness_versioning.md` | source | the image identity |
| `tool_interface.md` | source | the image names, the build flows and the mount contract |
| `container-interface.json` | source | the layout declaration |
| `scripts/build.sh` | source | the build's behaviour |
| `scripts/build_probe.sh` | source | the instrument's behaviour |
| `20261016-study-settled-install_step_census.md` | digest | it measures the old three-tier shape and the removed `docs/policies/` rows; re-derive it |
| `20261016-study-settled-invalidation_history.md` | digest | it measures the old shape; the counts are history |
| the two 2026-10-16 host reports | digest | the old shape and the removed `build_key` |
| the session log | raw evidence | it holds requirements and edge cases no document states; query it, do not cite it as a source |

### 8. Document lapses

| Document | Lapse | Destination |
|---|---|---|
| `20261016-study-settled-install_step_census.md` | describes three tiers, `pi-base` and `docs/policies/`; the tree is four tiers by kind and copies no policies | the requirements/catalog iteration; re-derive or mark historical |
| `20261016-study-settled-invalidation_history.md` | measures the old shape and old names; its cost side is a coverage gap it already states | the requirements/catalog iteration |
| `devlog/roadmap.md` M3.6.4 | the **Design step** asks whether the layout is built from the manifest or declared and gated; the operator's frame makes it an implementation outcome, judged by the instrument | the requirements/catalog iteration; replace it |
| `devlog/roadmap.md` M3.6.4 | the acceptance criteria name two probe rows that do not exist, and a pin check that does not exist | the instrument and pin rows |
| `scripts/build_probe.sh` | the `ROWS` comments say "three tiers" and "tier-2"; the tier-2 image is `agent-runtimes` for pi and `hermes-base` for hermes | the instrument row |
| `scripts/build.sh` | the `--no-cache` comment says tiers 1 and 2; the tool interface says `REBUILD=1` rebuilds everything | the requirements/catalog iteration states the intended semantics |
| `docs/reference/tool_interface.md` | `REBUILD=1` says "rebuilds everything from scratch"; the build passes no-cache to tiers 1 and 2 only | the requirements/catalog iteration |
| the repository | no `.dockerignore`; the whole tree including `.git/` and `devlog/` is the context | the build-context row |

### 9. The gap map

| Id | Gap | Destination |
|---|---|---|
| G1 | The requirements are stated but scattered; the log-only requirements and the edge cases have no document | a new M3.6.4 row, `The build requirements and domain catalog are stated` (docs) |
| G2 | The instrument measures the layer cache and the layout, not the pin, copy-in, security, frequency or concurrency requirements | a new M3.6.4 row, `The host build probe records the production run` (build) |
| G3 | The two refactor probe rows the roadmap names do not exist, and no current host baseline exists | G2, plus the open `The host build probe is re-run against the new shape` row |
| G4 | The pin policy has no implementation or scan | the open `Pin every build input` row |
| G5 | The `.dockerignore` and the context size are absent | a new M3.6.4 row, `The build context is narrowed to the declared inputs` (build) |
| G6 | `--rebuild` stops at tier 2, while the tool interface says everything | G1 states the semantics; G2 tests them |
| G7 | The census and the invalidation study are stale digests | G1; re-derive or mark historical |
| G8 | The M3.6.4 design step and the acceptance criteria describe a superseded frame | G1 rewrites the M3.6.4 text |
| G9 | The old logs are the only carrier of several requirements and edge cases | G1 writes them down with the transcript date |
| G10 | The provider directory rename is a separate open row | the existing `The provider directory is renamed to agent-runtime` row |

The next iterations in order: G1 (the operational model and catalog), G2 (the recorder and
baseline), G4 (pin implementation), G5 (context), then the host measurement.
The directory rename and the standing delegation rule are separate rows.

## Artifacts

The gap map is this study. The iteration record is
[`devlog/handovers/M3.6.4/20261107-02-audit-build_contract_gap.md`](../handovers/M3.6.4/20261107-02-audit-build_contract_gap.md).
The study is the evidence the requirements row links; the new rows own the work.
