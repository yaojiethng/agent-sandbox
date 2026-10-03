# Agent Handover

**Date:** 2026-10-01
**Milestone:** M3 -- Autonomous Task Execution, Manual Review Workflow
**Type:** Implementation
**Status:** Closed

## Objective

Give every reasoning-layer provider image the same runtime set: Node, Python, and uv. The dependencies live in one shared base image, `src/reasoning/base.dockerfile`, instead of three per-provider files that duplicate the same installs.

## Scope

The shared base owns the runtime set and the lint gates. Each provider base adds only its agent install. The image name, the build path, the two tests that name them, and the two architecture documents follow. The capability layer keeps its own runtime set and its documented boundary.

## Completed

| Work | Result |
|---|---|
| `node.dockerfile` renamed to `base.dockerfile`; image renamed `agent-node-base` to `agent-base` | the shared base is the single runtime owner; one canonical constant, one test assertion |
| Shared base gained uv and Python 3.11 (at or above the operator's 3.11.12 floor), and moved both tools out of `/root` | an agent running as `agentuser` has both on `PATH`, which the Hermes image did not |
| Hermes base rewritten on the shared base, both stages | its private NodeSource, uv, and `markdownlint-cli2` installs are gone, and it inherits `hadolint` |
| `tests/test_shared_base_contract.sh` added; `test_image_names.sh` and `test_trace_build.sh` follow the rename | 1008 tests across 68 files, lint clean, hadolint clean |
| `tool_interface.md` and `provider_onboarding_guide.md` describe the three-tier build and the shared base | the shared base is documented once, as the owner of the runtime set |

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | Every reasoning image runs `node -v`, `python3 -V`, `uv --version`, with Python at or above 3.11.12 | `docker run --rm <image> sh -c 'node -v; python3 -V; uv --version'` | Operator |
| 2 | `src/reasoning/base.dockerfile` installs Node, uv, Python 3.11, hadolint, and markdownlint-cli2 | `grep -n "python\|uv\|hadolint\|markdownlint" src/reasoning/base.dockerfile` | Agent [x] |
| 3 | `src/reasoning/node.dockerfile` is gone | `test ! -e src/reasoning/node.dockerfile` | Agent [x] |
| 4 | No provider base installs a runtime or a linter | `grep -rnE 'nodesource\|astral\.sh/uv\|install python3\|hadolint\|markdownlint-cli2' src/reasoning/providers/*/base.dockerfile` returns nothing | Agent [x] |
| 5 | `shared_base_image_name` returns `agent-base` | `bash tests/test_image_names.sh` | Agent [x] |
| 6 | The build suite passes | `bash scripts/run_tests.sh` | Agent [x] |
| 7 | Every changed Dockerfile is hadolint clean | `hadolint src/reasoning/base.dockerfile src/reasoning/providers/*/base.dockerfile` | Agent [x] |
| 8 | Architecture documents in scope describe the system as built | read `tool_interface.md` and `provider_onboarding_guide.md` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| `src/reasoning/base.dockerfile` | new shared runtime base, replaces `node.dockerfile` |
| `src/reasoning/providers/hermes/base.dockerfile` | drops its own Node, uv, and linter installs |
| `src/reasoning/providers/opencode/base.dockerfile` | agent install only |
| `src/reasoning/providers/pi/base.dockerfile` | agent install only |
| `src/build/image.sh` | shared base image name |
| `scripts/build.sh` | shared base dockerfile path |
| `tests/test_image_names.sh` | the canonical constant assertion |
| `tests/test_trace_build.sh` | the fixture that stages the shared base |
| `tests/test_shared_base_contract.sh` | new; the single-owner rule |
| `docs/architecture/tool_interface.md` | the three-tier image contract |
| `docs/operations/provider_onboarding_guide.md` | the shared-base step for a new provider |
| `devlog/roadmap.md` | the task row |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The shared image is `agent-base`, renamed from `agent-node-base` | the base carries Python and uv, so the "node" in the name is false; the constant had one canonical source and one test assertion, so the rename was one wave | `src/build/image.sh`, `tests/test_image_names.sh` |
| Python comes from `uv python install 3.11` into `/opt/uv-python`, not from apt | bookworm, the base of `node:22.22.3-slim`, ships python3 3.11.2, below the operator's 3.11.12 floor | `src/reasoning/base.dockerfile` header |
| Tools install outside `/root` | containers run as the unprivileged `agentuser`, so uv under `/root/.local/bin` was off the agent's PATH in the Hermes image | `src/reasoning/base.dockerfile` header |
| The lint gates stay in the shared base | the contract is "the linter ships in every provider base" (`git_hooks.md`); a provider base is the wrong owner and Hermes was already drifting from it | `src/reasoning/base.dockerfile` |
| Both Hermes stages start from `agent-base` | the build tools stay in the builder while the runtime keeps the full runtime set | `providers/hermes/base.dockerfile` |
| The capability layer keeps its own runtime set | confirmed at the release gate: it runs the diff pipeline, not agent code, and its dockerfile records that decision | `src/capability/dockerfile` |
| `python3-dev` dropped from the Hermes builder | the interpreter is uv-managed and ships its own headers; the apt package targets the system 3.11.2 the image no longer uses | `providers/hermes/base.dockerfile` |

## Findings

| Finding | Type | Impact |
|---|---|---|
| This container has `hadolint`, `markdownlint-cli2`, and `shellcheck` on `PATH` but no `python3` and no `uv`, which confirms the pi base shipped the linters and no Python | evidence | Triaged to: Completed -- the pre-state for criterion 1 |
| The Hermes image put uv under `/root/.local/bin`, which the unprivileged `agentuser` cannot read, so its `ENV PATH` line never reached the agent | bug | Triaged to: Completed -- both install directories moved outside `/root` |
| `docs/operations/provider_onboarding_guide.md` is stale beyond Step 2: its file tree is rooted at `providers/<n>/` instead of `src/reasoning/providers/<n>/`, and Step 3's sample `COPY` paths (`/libs/`, `/usr/local/bin/provider-entrypoint.sh`, `/opt/context/config/`) match no real provider image | documentation gap | Triaged to: roadmap -- task "Provider onboarding guide rewrite", iteration `20261002-02` |
| No docker in the agent container, so no test asserts the runtime set inside a built image | tooling gap | Triaged to: Deferred items |

## Deferred items

| Item | Reason |
|---|---|
| Give the capability layer a Node and Python runtime set | declined at the release gate; it keeps its documented no-Node boundary |
| A test that asserts the runtime set inside a built image | no docker in the agent container |

## What's Next

The capability layer runtime set is settled and needs no iteration. A build-capable environment would let the runtime set be asserted in CI rather than by the operator at each release.
