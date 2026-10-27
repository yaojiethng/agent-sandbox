# Harness Tier Unification - Run

**Status:** draft

**Scope:** the run directive for collapsing the pi and opencode provider bases into one shared harness tier, leaving the hermes path alone and removing the `agent-payload` image. It carries the premise under test, the facts the run must not re-derive, the rulings it must not cross, the phases and their order, the work units, the model assignment, the checks, and the forks that keep it a draft.

**Origin:** three operator rulings (2026-10-16). First, `agent-tools` is misnamed and the pi and opencode harnesses belong in one shared tier, with `<provider>-base` gone for those two and `<provider>-agent-<project>` becoming the specialization layer. Second, hermes keeps its own base path, because its install is a source build rather than a registry package; hermes is still swept by `Pin every build input`. Third, the `agent-payload` image is dropped, because `src/build/container-interface.json` and its layout gate already are the single declaration, and an image adds a carrier rather than a declaration. Supersedes the tier shape in `docs/adr/reasoning_layer_tiers.md` as it stands.

**Prerequisite reading:** `docs/adr/reasoning_layer_tiers.md`, `docs/adr/build_input_pinning.md`, `devlog/discussions/20261016-study-settled-install_step_census.md`.

## The premise

The tier list should not depend on which provider is reading it. Today `opencode-ai` is a shared-row install for the pi provider and a provider-own install for the opencode provider, because one binary is both the seam's second backend and the opencode provider's own agent. The premise under test is that one shared harness tier holding the pi and opencode installs, with `<provider>-base` gone for those two, is worth its cost.

Falsification would mean the image-size delta of adding `pi-coding-agent` to the opencode image is large enough that the uniformity is not worth it. That is the single remaining falsifier, because the hermes install is outside the shared tier and so cannot make any image fat. A falsified result leaves the current tier shape standing rather than softening the change.

Gain being bought, stated as a property rather than a benefit. Both unified images can dispatch to either backend. Today `dispatch_check` in `src/libs/dispatch.sh` refuses a role whose backend binary is absent, and `pi` is absent from the opencode image, so a pi-backend role is unrunnable there.

## What is already measured - do not re-derive

| Fact | Where it came from |
|---|---|
| A tier-3-only rebuild costs 1 second wall and 0.1 second of steps, warm | `devlog/handovers/archive/20261016-13-impl-the_host_build_probe.md`, host probe run 20261016T090725Z |
| A base change costs 3 seconds wall and 1.6 seconds of steps, warm | same run |
| A cold build costs 77 seconds wall and 75.4 seconds of steps | same run |
| The tiers were triggered 1, 22 and 448 times by commits, tier 1 to tier 3 | `devlog/discussions/20261016-study-settled-invalidation_history.md` |
| The reasoning layer has 41 install and copy steps: 6 in tier 1, 14 in tier 2, 21 in tier 3 | `devlog/discussions/20261016-study-settled-install_step_census.md` |
| `opencode-ai@1.19.1` installs in three Dockerfiles after unit 1: `src/reasoning/tools.dockerfile`, `providers/pi/base.dockerfile`, `providers/opencode/base.dockerfile` | the tree at `138f478b` |
| The seam has two backends and chooses by provider, `DISPATCH_OPENCODE_PROVIDERS` defaulting to `opencode` | `src/libs/dispatch.sh` |
| The payload is declared once in `src/reasoning/payload.dockerfile` and read by nothing yet | the tree at `138f478b`, superseded by the ruling of 2026-10-16, which drops the image |
| `check_container_layout.sh` holds the manifest's `image` rows equal to the Dockerfile COPY lines in both directions | `src/build/container-interface.json` `note`, and the gate |
| The hermes base clones `NousResearch/hermes-agent` at default-branch HEAD with no ref | `providers/hermes/base.dockerfile`, census row |
| The hermes install is a multi-stage build: builder with `gcc` and `libffi-dev`, `uv venv`, `uv pip install -e ".[all]"`, `npm install`; runtime with `ffmpeg` | `providers/hermes/base.dockerfile` |
| The image sizes are unmeasured | no run exists |

## The rulings

- **Hermes keeps its own base path.** Its install is a source build with a cloned tree, a Python venv, a compiler and its own apt packages, so it does not join the shared tier. The tier rule is the install's mechanism: a harness installed as a registry package sits in the shared tier, and a harness that needs a compiler, a cloned source tree or a language environment of its own keeps a provider base. Hermes is swept by `Pin every build input` regardless, and that sweep is an independent row rather than a dependency of this run.
- **Every harness install appears in exactly one Dockerfile.** The check is a search over the Dockerfiles for each package name, and it fails on a second home.
- **The provider interface does not change.** `AGENT_HOME`, `PROVIDER_NAME`, the entrypoint, the UID mapping, and the `agent-sandbox.interface-contract-version` label on the final image all stay exactly as they are.
- **The capability layer is untouched.** `sandbox-<project>`, its Dockerfile and its contract are out of scope.
- **The manifest is the single declaration.** `src/build/container-interface.json` declares every COPY pair, and `scripts/check_container_layout.sh` holds it equal to the Dockerfiles in both directions. No payload image exists, and each provider image copies the paths it needs directly. Deriving those COPY lines from the manifest instead of writing and gating them is the roadmap's T7 row `Evaluation of stage construction`, deliberately not this run.
- **No attribution spoofing.** Unchanged from M3.6.
- **pi stays installed.** The pi image keeps its own harness, and no image loses a backend it has today.
- **The extension and skills question is out of scope.** A pi package installed from a `packages` declaration is a mount and settings question, not a tier question.

## The phases

Order is a dependency chain, not a preference.

**Phase 1, the size measurement.** Question: what does the unification cost in image bytes? Deliverable: `docker image inspect --format '{{.Size}}'` for every reasoning image before the change, and the same list after. Host-side and operator-run, because the agent's container has no Docker. This phase gates the rest: if the delta is unacceptable the run stops and reports.

**Phase 2 is not a gate.** The pin sweep belongs to the existing M3.6.1 row `Pin every build input`, which covers the hermes rows as well as the shared tier's two installs. It does not gate this run, because nothing this run moves is unpinned today. Cited so it is not forgotten: a commit SHA for the hermes clone, and a lockfile with integrity hashes for its `uv pip` and `npm` resolutions, installed frozen.

**Phase 3, the shape.** Question: do both build paths come out right, with each harness installed once? Deliverable: `src/reasoning/harnesses.dockerfile` replacing `tools.dockerfile`, the pi and opencode `base.dockerfile` deleted and the hermes one kept, `payload.dockerfile` deleted, and each `providers/*/provider.dockerfile` carrying its own COPY lines, which is what they do today. The pi and opencode paths inherit the harness tier; the hermes path keeps inheriting `hermes-base`, which itself inherits `agent-base`.

**Phase 4, the gates follow.** Question: does the declaration still describe the images? Deliverable: the manifest's shared-row concept, the layout gate, the seam's refusal behaviour and its case.

**Phase 5, the record.** Question: does the ADR describe the shape that exists? Deliverable: the amendment.

## The run shape

Sequential. Phases 3, 4 and 5 touch disjoint file sets and could run as parallel tracks, but phase 3 changes the tree phases 4 and 5 describe, so phase 5 lands against a settled tree and phase 4 lands with or after phase 3. Phase 1 is operator-run and phase 2 is a dependency on an existing row. Widest wave: one unit.

## The work units

One concern per row. Each ends in a check, lands as one commit with one handover.

| Unit | Commit type | Owned files | Handover |
|---|---|---|---|
| U1 the shared harness tier lands | `build` | `src/reasoning/harnesses.dockerfile` (replaces `tools.dockerfile`), `src/reasoning/payload.dockerfile` (deleted), `src/reasoning/providers/{pi,opencode}/base.dockerfile` (deleted), `src/reasoning/providers/{pi,opencode}/provider.dockerfile`, `src/build/image.sh`, `scripts/build.sh`, `tests/test_trace_build.sh`, `tests/test_shared_base_contract.sh`, `.dockerignore` | one impl handover |
| U2 the seam's backend availability follows | `build` | `src/libs/dispatch.sh`, `scripts/dispatch.sh`, `tests/test_dispatch.sh` | one impl handover |
| U3 the manifest declares the shared rows | `build` | `src/build/container-interface.json`, `src/build/container-interface.mjs`, `scripts/check_container_layout.sh`, the layout test | one impl handover |
| U4 the tier ADR is amended | `docs` | `docs/adr/reasoning_layer_tiers.md`, `docs/adr/opencode_dispatch_backend.md` | one docs handover |

Order: U4 first, because the decision record precedes the implementation it describes. Then U1, then U2 and U3 in either order.

Filing is the caller's. `/wrapup` Part B's roadmap write-back is where these rows land.

## The model assignment

| Seat | Model | Why |
|---|---|---|
| `_IMPLEMENTER` | `opencode/deepseek-v4.1-flash-free` at high, read from `$AGENT_HOME/model-recommendations.md` | the role's line, and the model that ran unit 1 |
| `_REVIEWER` | `opencode/deepseek-v4.1-flash-free` at high | the role's line |
| `_ADVISOR` for the size and layer-order judgement | `opencode/glm-5.3-flash-free` at high | a differing model, which is the only seat that gives an independent signal |

**Known weakness, stated rather than hidden.** The implementer and reviewer seats resolve to the same model, so the review is one model reading its own family's output. Unit 1 measured that cost: a small five-file unit returned with three defects, one of them a stale-image bug that the brief's own constraints named. Two consequences for this run. The primary verifies the tree itself and re-runs every check, not the report. And the two judgement calls, the size verdict and the layer order, go to the advisor seat rather than the reviewer.

**Dead seats.** `opencode-go/longcat-2.5-preview-free` is excluded by operator ruling. The pi backend cannot reach any `opencode/*` role, which is why every seat above is an OpenCode backend and the dispatch goes through `opencode run`.

## Verification

| Check | The artifact that proves it |
|---|---|
| each harness installs exactly once | a search over `src/reasoning/**/*.dockerfile` for `opencode-ai`, `pi-coding-agent` and the hermes install, returning one hit each |
| both build paths come out right | `tests/test_trace_build.sh` asserting the order for a unified provider, `agent-base` then `agent-harnesses` then `<provider>-agent-<project>`, and for hermes, `agent-base` then `hermes-base` then `hermes-agent-<project>` |
| the payload image is gone | no `src/reasoning/payload.dockerfile` exists, and no provider Dockerfile carries `COPY --from` |
| the shape survives a harness bump | a new `scripts/build_probe.sh` row: bump the pi pin, assert the opencode provider image rebuilds, and assert every hermes layer stays `CACHED`. Operator-run |
| the size cost is bounded | `docker image inspect --format '{{.Size}}'` per image, before and after, in the probe report. Operator-run |
| every provider image can dispatch to every backend | `scripts/dispatch.sh --check <role>` run inside each provider image, once per backend |
| the manifest still describes the images | `bash scripts/check_container_layout.sh`, which compares in both directions |
| the record agrees with the tree | read `docs/adr/reasoning_layer_tiers.md`: it names the shared harness tier, the hermes exception, and the install-mechanism rule that separates them |
| the context is curated | `.dockerignore` exists and a case asserts it excludes `.git/` and `devlog/` |
| nothing else regressed | `bash scripts/lint.sh` clean across its gates, and the full suite green |

A check the agent runs on its own test is not the verification for this brief. The three external ones are the image sizes, the daemon's `CACHED` and `DONE` lines, and the layout gate.

## Constraints and invariants

What the run must not do.

- Do not change the provider interface, the entrypoint's contract, or the interface-contract label.
- Do not change either hermes Dockerfile. The hermes path stays exactly as it is, install and COPY lines alike.
- Do not add a payload image. `src/build/container-interface.json` is the declaration and `scripts/check_container_layout.sh` is its check.
- Do not add a dispatch backend to the hermes image. It has none today and this run does not change that.
- Do not change the capability layer.
- Do not remove a backend from an image that has it today.
- Do not add a paid dependency or an unattributed route to a free model.
- Do not widen into M3.6.5's OpenCode surface work or the `packages` question.

What must stay true across the run.

- Every harness install has one home.
- Every pin is paired with a bump path and is checkable, per `build_input_pinning.md`.
- The library contract holds: library functions `return`, never `exit`; the flags rule in `p-18` is followed; the dual-use script guard is at the foot.
- No comment cites a change, a unit, a plan or a handover.

## What would settle this brief

Two inferences keep it a draft. Each carries the default taken and the word that reverses it.

**The image-size delta of `pi-coding-agent` in the opencode image.** Unmeasured, and now the only falsifier. Default taken: accept it, because the pi package is a registry install, the opencode image is rebuilt on every call anyway, and the hermes path is unaffected either way. Reverse word: `too-fat`.

**The shared tier's name.** The operator proposed `provider-base` with a hedge. `agent-tools` is wrong because it names tools the agent wields. `provider-base` now collides with `hermes-base`, which survives as the one provider base, so the two names would point at different kinds of thing. Default taken: `agent-harnesses`. Reverse word: `provider-base`.
