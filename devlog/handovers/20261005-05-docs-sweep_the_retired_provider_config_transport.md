---
date: 2026-10-05
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Documentation
status: Closed
---

# Handover - Sweep the Retired Provider Config Transport

## Objective

Make every live record describe the provider config transport the container actually runs, and leave the retired copy-in/copy-out cycle to the archive and the changelog.

## Scope

One roadmap row: **The provider config transport: the records describe a retired mechanism**. The mechanism was retired deliberately -- the archived design record `20260512-design-settled-provider_config_ownership_and_loading.md` settles "`/opt/provider-config` removed", and the commit that followed moved the pi mounts into the provider compose overlay and dropped the tmpfs. The records did not follow.

Measured at scope time, the live carriers of the retired description:

- `docs/architecture/execution_model.md` -- a section titled `### Why provider config uses a bind mount via /opt/provider-config/`.
- `docs/architecture/provider_lifecycle.md` -- the copy-in at line 27 and the copy-out EXIT trap at line 57, both naming `libs/provider-entrypoint.sh`.
- `docs/architecture/tool_interface.md` -- the mount table's `/opt/provider-config/` row, and `libs/provider-entrypoint.sh` in the provider contract.
- `docs/architecture/sandbox_lifecycle.md` -- copy-out language.
- `scripts/run_agent.sh` -- the header's config-lifecycle paragraph and the copy-out comment at line 446.
- `src/build/docker-compose.yml` -- the path-table row `provider_config_host`.
- `src/reasoning/entrypoint.sh` -- its own header names `libs/provider-entrypoint.sh`, the path it no longer has.
- `src/reasoning/providers/{pi,hermes,opencode}/provider.dockerfile`, `pi/setup.sh`, `pi/onboard.sh` -- copy-in/copy-out comments.
- `src/reasoning/providers/hermes/docker-compose.hermes.yml` -- "Provider config (config.yaml, .env) is seeded into AGENT_HOME by provider-entrypoint.sh at container start -- not mounted", which nothing performs: the manifest carries no hermes config row, and no mount names it.
- `src/reasoning/{agent,providers/pi/config/agent/prompts,providers/pi/config/agent/skills}/CONTEXT.md` -- three "not reachable" bullets that name `/opt/provider-config/` because "the compose path table documents it". The sweep removes that table row, so the citation has to change with it.
- `tests/knowledge/knowledge_pi_config_cycle.sh` and `tests/test_provider_entrypoint.sh` -- comments and a bind-mount reference to the retired path.

Out of scope: the archived handovers and discussions, and `devlog/changelog.md`, which record what was true when they were written. The current transport is not in question: the image bakes a config template at `/opt/workflow/agent/config/`, `src/reasoning/entrypoint.sh` copies it into `$AGENT_HOME/` at every start, and the provider overlay bind-mounts the persistent subdirectories.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No live file claims a copy-in or copy-out cycle, or a `/opt/provider-config/` mount | `grep -rn` the pattern across the tree, with `devlog/` archive paths, the changelog and this handover excluded | Agent [x] -- `/opt/provider-config` returns nothing live; the two remaining `copy-in` hits are the substring in `copy-install` |
| No live file names `libs/provider-entrypoint.sh` | the same grep | Agent [x] -- `entrypoint.sh`'s header, `tool_interface.md`, and the two test comments now name `src/reasoning/entrypoint.sh` or its image path |
| The architecture documents state the current transport: template in the image, seeded into `$AGENT_HOME` at start, persistent subdirectories bind-mounted | read `provider_lifecycle.md` and `execution_model.md` | Agent [x] -- `provider_lifecycle.md` rewritten around provisioning and persistence; `execution_model.md`'s rationale section, tree and diagram; `tool_interface.md`'s mount row and provider contract |
| The three `CONTEXT.md` not-reachable bullets match the tree after the sweep | read them; the compose path table no longer carries the row they cite | Agent [x] -- the bullets are gone, since the path they warned about is documented nowhere |
| The hermes config claim is resolved in the direction the operator chooses | read the overlay and the dockerfile; the claim matches what the build does | Agent [x] -- option (b): the overlay states that the build ships no hermes config, and the behaviour question is a roadmap row |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | both commands | Agent [x] -- 8 gates clean; 1088 tests, 0 failed; the rewritten knowledge test passes 4 of 4 |
| The sweep's coverage and the hermes direction are accepted | operator acceptance at the release gate | Operator [x] -- released |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/architecture/provider_lifecycle.md`](../docs/architecture/provider_lifecycle.md) | the copy-in and copy-out description |
| [`docs/architecture/execution_model.md`](../docs/architecture/execution_model.md) | a section justifying the retired bind mount |
| [`docs/architecture/tool_interface.md`](../docs/architecture/tool_interface.md) | the mount table row, and the provider contract's stale script path |
| [`docs/architecture/sandbox_lifecycle.md`](../docs/architecture/sandbox_lifecycle.md) | copy-out language |
| [`scripts/run_agent.sh`](../../scripts/run_agent.sh) | the header's lifecycle paragraph and the teardown comment |
| [`src/build/docker-compose.yml`](../../src/build/docker-compose.yml) | the path-table row |
| [`src/reasoning/entrypoint.sh`](../../src/reasoning/entrypoint.sh) | its own header names a path it no longer has |
| [`src/reasoning/providers/hermes/docker-compose.hermes.yml`](../../src/reasoning/providers/hermes/docker-compose.hermes.yml) | a claim that nothing performs |
| [`tests/knowledge/knowledge_pi_config_cycle.sh`](../../tests/knowledge/knowledge_pi_config_cycle.sh) | a bind-mount reference to the retired path |
| [`devlog/roadmap.md`](../devlog/roadmap.md) | the row, and the write-back |

## Decisions

None.

## Decisions pending

| Question | Blocks | Options |
|---|---|---|
| Does the hermes image ship `config/config.yaml`, or does the record stop claiming it does? | the overlay comment's correction, and whether the iteration adds a `COPY` and a manifest row | (a) Ship it: copy `src/reasoning/providers/hermes/config/` to the provisioning template in the hermes dockerfile, add the manifest `image` and `provision` rows, and the entrypoint seeds `$HERMES_HOME/` at start -- consistent with pi, and it makes the claim true. (b) Correct the record and file the behaviour question as its own row: nothing in the tree shows hermes reading that file, hermes is not exercised by any test, and a records sweep should not decide provider behaviour on a guess. (c) Correct the record only: state that hermes ships no config file, and accept that the provider runs on its defaults. |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| opencode is in the same state as hermes and one step further: no `config/` directory exists for it at all, it has no provider overlay, and the manifest declares no config row for it, so nothing seeds its `$AGENT_HOME`. Found while measuring the hermes correction, which named only hermes. | scope change | roadmap | Triaged to: `devlog/roadmap.md` M3.3.1, `The hermes and opencode images ship no provider config` |
| The knowledge test's premise was dead, not just its wording: it simulated the retired cycle with local `cp -r` helpers, and the `_ensure_harness_keys` merge it documented no longer exists in `entrypoint.sh`. Four of its five tests were removed rather than corrected; the surviving pair now asserts the shipped `settings.json` roots and the model-scope head. | scope change | current iteration | Triaged to: `tests/knowledge/knowledge_pi_config_cycle.sh` |
| `agent-sandbox onboard` still rsyncs `providers/<n>/config/` into `$SANDBOX_DIR/.<provider>/`, and the pi overlay mounts only `agent/{prompts,sessions,skills}` from that directory, so the host copy of `settings.json` is neither mounted nor read. The records now say what happens at run time; whether onboarding should keep writing that copy is behaviour, not record. | obstacle | next iteration | Triaged to: `devlog/roadmap.md` M3.3.1, `The hermes and opencode images ship no provider config` |

## Completed

| File | Change |
|---|---|
| [`docs/architecture/provider_lifecycle.md`](../docs/architecture/provider_lifecycle.md) | rewritten: provisioning and persistence replace copy-in and copy-out; the config files are image-owned and the mounted subdirectories carry state; the fragility table now names session-local config edits and the absent hermes/opencode template |
| [`docs/architecture/execution_model.md`](../docs/architecture/execution_model.md) | the rationale section becomes `Why the config files are seeded rather than mounted`; the tree, the state table and the session diagram say seeded, not copy-in |
| [`docs/architecture/tool_interface.md`](../docs/architecture/tool_interface.md) | the mount table names the provider overlay's three subdirectories; `config/`'s row states both consumers; the provider contract names the entrypoint's real path |
| [`docs/architecture/sandbox_lifecycle.md`](../docs/architecture/sandbox_lifecycle.md), [`docs/concepts/sandbox_host_interface.md`](../docs/concepts/sandbox_host_interface.md) | the cross-references name provisioning |
| [`scripts/run_agent.sh`](../../scripts/run_agent.sh) | the header's config-lifecycle paragraph and the teardown comment |
| [`src/build/docker-compose.yml`](../../src/build/docker-compose.yml) | the `provider_config_host` row is gone, replaced by a note pointing at the provider overlay |
| [`src/reasoning/entrypoint.sh`](../../src/reasoning/entrypoint.sh) | its own header names `src/reasoning/entrypoint.sh`; the seeding and mount comments state the current model |
| `src/reasoning/providers/{pi,hermes,opencode}/provider.dockerfile`, `pi/docker-compose.pi.yml`, `pi/onboard.sh`, `pi/setup.sh`, `pi/onboard-readme.md` | copy-in and copy-out wording replaced with seeding and mounting |
| [`src/reasoning/providers/hermes/docker-compose.hermes.yml`](../../src/reasoning/providers/hermes/docker-compose.hermes.yml) | the false seeding claim becomes the truth: the build ships no hermes config, and the question is filed |
| `src/reasoning/{agent,providers/pi/config/agent/prompts,providers/pi/config/agent/skills}/CONTEXT.md` | the three `/opt/provider-config/` bullets are removed |
| [`tests/knowledge/knowledge_pi_config_cycle.sh`](../../tests/knowledge/knowledge_pi_config_cycle.sh) | the four retired-cycle tests and their `cp -r` simulations are gone; the header states why; one test asserts the shipped harness roots |
| [`tests/test_provider_entrypoint.sh`](../../tests/test_provider_entrypoint.sh) | the header names the entrypoint's real path |
| [`devlog/roadmap.md`](../devlog/roadmap.md) | the row resolved, and the hermes/opencode config question filed under M3.3.1 |
