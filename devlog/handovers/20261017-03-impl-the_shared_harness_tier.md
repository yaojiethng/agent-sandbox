---
date: 2026-10-17
milestone: M3.6.4 - The reasoning image refactor
type: Implementation
status: Closed
---

# Handover - The shared harness tier

## Objective

Collapse the pi and opencode provider bases into one shared `agent-harnesses` tier, so each registry-package harness installs in exactly one Dockerfile and hermes keeps the base its source build needs.

## Scope

The M3.6.4 row `The tier change lands`, its unit U1 of the run brief [`harness-tier-unification-run.md`](../../.agents/drafts/harness-tier-unification-run.md). The row's other units, and the rows `Pin every build input`, `The build-skip mechanism is removed` and `The host build probe is re-run against the new shape`, are out of scope for this unit. The pin sweep's subject moved with this unit: `pi-coding-agent` and `opencode-ai` now have one home, so the row pins them there.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Both registry-package harnesses install in exactly one Dockerfile | `bash tests/test_shared_base_contract.sh`, case `test_each_harness_package_installs_exactly_once` | Agent [x] |
| A pi build runs `agent-base`, then `agent-harnesses`, then the provider image | `bash tests/test_trace_build.sh`, case `test_build_order_pi_unified_harness_tier` | Agent [x] |
| A hermes build keeps its own base between the shared base and its image | `bash tests/test_trace_build.sh`, case `test_build_order_hermes_keeps_its_base` | Agent [x] |
| The pi and opencode provider images inherit the harness tier | `docs/adr`, then `grep "^ARG BASE_IMAGE=agent-harnesses$"` in both `provider.dockerfile` files | Agent [x] |
| The hermes Dockerfiles are unchanged | `git diff --stat src/reasoning/providers/hermes/` is empty | Agent [x] |
| The manifest and the Dockerfiles still agree in both directions | `bash scripts/check_container_layout.sh`, exit 0 | Agent [x] |
| The build context is curated and shadows no COPY source | `bash tests/test_build_context.sh`, case `test_dockerignore_curates_the_build_context` | Agent [x] |
| The lint umbrella passes | `bash scripts/lint.sh`, exit 0, 8 gates clean | Agent [x] |
| The probe still names real tier-2 files | `bash tests/test_build_probe.sh`, 12 passed | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Tier 2 is chosen by whether the provider carries a base Dockerfile | the file is the install's mechanism made visible: a source-built harness needs a stage the registry tier cannot hold, and a registry package needs none | `scripts/build.sh`, `build_agent` comment |
| `.dockerignore` excludes only what no `COPY` line reads, and a test holds that rule | the build context is the whole working tree, and an ignore entry that shadows a `COPY` source fails the build | `.dockerignore` header, `tests/test_build_context.sh` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Should the COPY layout be derived at build time from `src/build/container-interface.json`, or stay declared and gated? | the M3.6.4 design step; it would replace the COPY lines the provider Dockerfiles carry | keep the declaration and the gate; a builder stage derives the tree from the manifest; defer |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `src/reasoning/providers/pi/config/agent/skills/pi-bump/SKILL.md` named the deleted pi base as the pin's home, in four places | defect | the bump procedure would edit a file that no longer exists | closed here, repointed at `harnesses.dockerfile` |
| `scripts/build_probe.sh` resolved tier 2 from `providers/<provider>/base.dockerfile`, so the deleted files broke it | defect | the operator's one build measurement tool would refuse to start | closed here, resolved by the same rule as `build_agent` |
| The OpenCode dispatch route cannot run a worker in this container: both free models hang with no output, `cat-jam-free` answers an upstream server error, and the paid models answer `Insufficient account funds` or `Model access is disabled` | environment | the free-tier dispatch the milestone is built around is unusable here, so this run's units went through `pi -p` instead | `devlog/AGENT_FEEDBACK.md` candidate, not yet filed |
| The Markdown lint gate scans `.scratchpad/`, so a dispatch brief written there fails the gate on its own wrapping | process | every worker brief the harness writes must satisfy the prose rule or the gate blocks, which it did once in this unit until the brief moved out of the tree | `devlog/AGENT_FEEDBACK.md` candidate, not yet filed |

## Completed

| File | Change |
|---|---|
| `src/reasoning/harnesses.dockerfile` | the `agent-harnesses` tier, installing both registry-package harnesses once each |
| `src/reasoning/providers/pi/base.dockerfile` | deleted; its installs moved to the harness tier |
| `src/reasoning/providers/opencode/base.dockerfile` | deleted; its install moved to the harness tier |
| `src/reasoning/providers/pi/provider.dockerfile` | base image defaults to `agent-harnesses` |
| `src/reasoning/providers/opencode/provider.dockerfile` | base image defaults to `agent-harnesses`, and the stale base-layer comment corrected |
| `src/build/image.sh` | added `harnesses_base_image_name` |
| `scripts/build.sh` | `build_agent` resolves tier 2 by mechanism; the provider enumeration no longer requires a base Dockerfile |
| `scripts/build_probe.sh` | tier-2 resolution follows the same rule |
| `.dockerignore` | new; curates the build context by the rule that only unread paths are excluded |
| `tests/test_trace_build.sh` | the build-order cases for a unified provider and for hermes |
| `tests/test_shared_base_contract.sh` | the tier-2 cases widened, and the one-home case for each harness package added |
| `tests/test_build_context.sh` | the `.dockerignore` case, including the no-shadow rule |
| `src/reasoning/providers/pi/config/agent/skills/pi-bump/SKILL.md` | the pin's home repointed from the deleted base to the harness tier |
