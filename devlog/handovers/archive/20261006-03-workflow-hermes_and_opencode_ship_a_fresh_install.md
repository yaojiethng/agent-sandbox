---
date: 2026-10-06
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - The Hermes and OpenCode Images Ship a Fresh Install

## Objective

Strip provider config specialization from the hermes and opencode images, so each ships an install of its own tool and nothing of the harness's choosing.

## Scope

The M3.3.1 ledger row `The hermes and opencode records name no instruction root`, resolved by the opposite route from the one the row assumed: rather than giving those providers a config transport, the harness stops shipping any config for them at all.

The survey found the state is already half-stripped and the remainder is dead weight.

- **hermes** carries `config/config.yaml`, 215 lines, and `config/env.stub`. Neither reaches the image: no dockerfile copies the directory and no mount names it, which the provider overlay's own comment states. The file is hermes's own default dump at `_config_version: 10`, with upstream defaults throughout (TTS and STT models, a `kawaii` personality, container images for sandboxes hermes would nest inside the harness's own container) and three harness-relevant entries: a model pin to `claude-sonnet-4-6` on `anthropic`, which is not this harness's model; `agent.max_turns: 90`, which the compose overlay already sets as `HERMES_MAX_ITERATIONS=90`; and `approvals.mode: manual`, which would stop an unattended run at the first command prompt. The `env.stub` names the same credentials the overlay already declares.
- **opencode** ships no config at all and installs with `npm install -g opencode-ai`, so it is a fresh install already. Only its dockerfile header still claims the entrypoint seeds a config template.

In scope: the hermes config directory; the two provider overlays' and dockerfiles' claims; the hermes quickstart's seeding section; the provider lifecycle document's fragility row and the ADR's edge-case sentence; `tests/test_onboard.sh`; the roadmap row. `onboard.sh` needs no logic change, because its seeding step already skips a provider whose config directory is absent or empty.

Out of scope, each with its reason: `measure`-style provider behaviour, which no run has exercised for either harness; the instruction payload's reachability, which stays open as its own question below.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Neither provider ships a config file | no `config/` directory, `*.yaml`, or `env.stub` under either provider tree | Agent [x] |
| The overlays state the rule | the hermes overlay's comment names the fresh install rather than an open row | Agent [x] |
| The dockerfile headers match the images | neither header claims a config template the image does not carry | Agent [x] |
| Onboarding seeds nothing for these providers | `bash tests/test_onboard.sh` passes with the hermes expectation changed | Agent [x] -- 23 cases |
| No document promises a hermes config template | the quickstart's seeding section and the lifecycle fragility row both read the fresh-install rule | Agent [x] |
| The payload question is settled as directed | the payload `COPY` lines left both dockerfiles, the manifest lost those eight rows, and the layout gate is clean in both directions | Agent [x] |
| Lint and the suite are clean | `bash scripts/lint.sh` and `bash scripts/run_tests.sh` | Agent [x] -- 8 gates clean, 1114 tests across 76 files, liveness clean |
| The handover closes | this handover | Operator [ ] |

## Hot files

| File | Why in scope |
|---|---|
| `src/reasoning/providers/hermes/config/config.yaml` | the dead config that goes |
| `src/reasoning/providers/hermes/config/env.stub` | the credential stub the overlay already carries |
| `src/reasoning/providers/hermes/docker-compose.hermes.yml` | the comment that documents the open row |
| `src/reasoning/providers/hermes/quickstart.md` | the seeding section that names a retired `setup.sh` |
| `src/reasoning/providers/opencode/provider.dockerfile` | the header's config-template claim |
| `src/reasoning/providers/hermes/provider.dockerfile` | the same claim, and the payload lines under question |
| `docs/architecture/provider_lifecycle.md` | the fragility row for an empty `AGENT_HOME` |
| `docs/adr/module_instruction_payload.md` | the edge-case sentence about the two providers' missing transport |
| `docs/operations/provider_onboarding_guide.md` | the onboarding step that describes a config directory |
| `tests/test_onboard.sh` | the hermes seeding expectation |
| `devlog/roadmap.md` | this row |
| `devlog/handovers/archive/20261006-03-workflow-hermes_and_opencode_ship_a_fresh_install.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The hermes config directory is deleted rather than shipped | nothing reads it, and every harness-relevant entry in it is either upstream's default, wrong for this harness, or already set by the compose overlay | this handover |
| The compose overlay keeps its environment block | credentials and the iteration cap are the operator's transport, not a config file the harness authors | this handover |
| `onboard.sh` gains no provider-specific branch | its seeding step already skips an absent or empty config directory, so the deletion is enough | this handover |
| The two providers are supported as fresh installs, and their payload reachability stays open | the harness's prompts and skills can be wired per harness when one is actually run, and doing it blind would ship a config nobody has tested | this handover |
| The payload copies leave both dockerfiles, at the operator's direction | a payload with no loader is unreachable, so shipping it would read as support that does not exist; the payload now ships in pi's image only, and the manifest lost the same eight rows | this handover, and the ADR's 2026-10-06 entry |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The hermes `config.yaml` is a full hermes default dump with a model pin this harness does not use and an iteration cap the compose already sets, so none of it is harness policy; the one entry that could bite is `approvals.mode: manual`, which would stop an unattended run at the first command prompt. That reading comes from the file, not from a run. | evidence, surveyed | current iteration, and a note for whoever first runs hermes |
| The hermes quickstart tells the operator that `setup.sh` seeds `.hermes/config.yaml` from the repo. No `setup.sh` exists in that provider tree, so the instruction has been dead since the transport was retired. | contradiction | current iteration |
| The hermes overlay's comment names this roadmap row as open, so the comment must move with the row when it closes. | evidence, surveyed | current iteration |
| The onboarding guide calls hermes "a provider with no agent compose overlay", while `docker-compose.hermes.yml` exists in that tree. The guide's table is wrong on that row; it is a separate correction and is not fixed here. | contradiction | roadmap, at the operator's word |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/hermes/config/` | deleted: `config.yaml` and `env.stub`, neither of which reached the image |
| `src/reasoning/providers/hermes/provider.dockerfile` | the four payload `COPY` lines removed with a note, and the header's config-template claim corrected |
| `src/reasoning/providers/opencode/provider.dockerfile` | the same four lines removed, and the same header claim corrected |
| `src/build/container-interface.json` | eight `image` rows removed; the layout gate is clean in both directions |
| `src/reasoning/providers/hermes/docker-compose.hermes.yml` | the comment states the fresh-install rule instead of an open row |
| `src/reasoning/providers/hermes/quickstart.md` | the provider-config section no longer seeds a `config.yaml` from a `setup.sh` that does not exist; credentials come from the sandbox `.env` |
| `docs/architecture/provider_lifecycle.md` | the fragility row reads the fresh-install rule |
| `docs/operations/provider_onboarding_guide.md` | the `config/` step names pi as its reference and states that a provider may ship none |
| `docs/adr/module_instruction_payload.md` | the 2026-10-06 decision: pi's image only, and two providers on a fresh install |
| `tests/test_onboard.sh` | the configs case asserts a provider with no config seeds nothing; the mode case reads pi's seeded tree; the `env.stub` promotion case uses a fixture provider, so the convention stays covered with no shipped example |
| `devlog/roadmap.md` | this row closed with its landing note |
