---
date: 2026-11-03
milestone: M3.3.3 - The skill maintenance pipeline
type: Implementation
status: Closed
---

# Handover - the image owns the config files, in the container and on the host

## Objective

Make one rule hold on both sides of the seam: a config file the image bakes is copied into `AGENT_HOME` at every container start and exists nowhere else, so the sandbox stops carrying copies nothing reads and the role table stops having a second home.

## Scope

In scope: the agent-home copy of the role table and everything that maintained it; the four image-owned config files the sandbox seed wrote; the documentation that described both.

Out of scope: the state directories the overlays mount, which the seed still provides.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The role table has one source | `defaultTableFile` returns `DISPATCH_REC_FILE` or the repository copy; `node --test tests/dispatch/machine/table.test.ts` 43 pass | Agent [x] |
| Nothing mounts or seeds the table | the mount row is gone from `container-interface.json` and `docker-compose.pi.yml`; `bash scripts/check_container_layout.sh` is clean | Agent [x] |
| The sandbox holds no image-owned config file | the seed excludes `AGENTS.md`, `auth.json`, `models.json` and `settings.json`; `bash tests/test_onboard.sh` 23 pass, asserting the absence | Agent [x] |
| The documentation names the manifest rather than restating it | `provider_lifecycle.md` cites the `provision` row for the copy-in rule | Agent [x] |
| `bash scripts/lint.sh` is clean | twenty gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The fallback is removed rather than deprecated | Two copies of one table answer one question twice, and the second answered a different one silently: a project that never wrote a table dispatched from a skeleton with empty role lines | `docs/adr/single_source_model_recommendations.md`, entry 2026-11-03 |
| The provider setup hook is deleted with its only job | `setup.sh` refreshed the host copy at every start, so removing the mount left it with nothing to do; no provider ships one now | `provider_onboarding_guide.md` Step 7 |
| The seed drops the config files rather than the whole `config/` tree | The mount sources are directories under that tree and the overlays need them on the first run; the files are the image's, and the entrypoint copies them in at every start | `scripts/onboard.sh` |

## Decisions pending

None.

## Findings

- Removing the fallback removed its tests with it: `tests/test_pi_model_recommendations.sh` covered the mount, the skeleton, the start refresh and the fallback, and all four subjects are gone.
- Two tests in `tests/test_run_agent.sh` drove the provider setup hook, one to prove sourcing and one to prove the abort attribution; both failed by construction once no provider ships a hook. They are removed, and the abort contract now has no fixture.
- The code-snippet baseline needed `--update`, because a fenced block in `execution_model.md` lost a line.

## Completed

| File | Change |
|---|---|
| `src/libs/dispatch/table.ts` | the agent-home fallback is gone |
| `src/build/container-interface.json` | the table's mount row is gone |
| `src/reasoning/providers/pi/docker-compose.pi.yml` | the table's mount is gone |
| `src/reasoning/providers/pi/setup.sh` | deleted, its only job was the host refresh |
| `src/reasoning/providers/pi/onboard.sh` | stops seeding the table |
| `src/reasoning/providers/pi/model-recommendations.skeleton.md` | deleted |
| `scripts/onboard.sh` | the seed writes no config file |
| `tests/test_pi_model_recommendations.sh` | deleted |
| `tests/dispatch/machine/table.test.ts` | the resolver test names two levels, not three |
| `tests/test_onboard.sh` | the mode assertion covers a seeded skill file, and the absence of `AGENTS.md` |
| `tests/test_run_agent.sh` | the two setup-hook tests are gone |
| `docs/adr/single_source_model_recommendations.md` | R8 restated, and a dated entry records the removal |
| `docs/reference/{dispatch,provider_lifecycle,execution_model,terminology}.md` | the table's second home and the stale onboard sentence are gone |
| `docs/development/provider_onboarding_guide.md` | Step 7 names no shipped hook |
| `devlog/roadmap.md` | the phantom row closes |
