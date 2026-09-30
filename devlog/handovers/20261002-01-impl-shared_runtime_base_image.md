# Agent Handover

**Date:** 2026-10-01
**Milestone:** M3 -- Autonomous Task Execution, Manual Review Workflow
**Type:** Implementation
**Status:** Closed

## Objective

Give every reasoning-layer provider image the same runtime set: Node, Python, and uv. The dependencies live in one shared base image, `src/reasoning/base.dockerfile`, instead of three per-provider files that duplicate the same installs.

## Scope

The shared base owns the runtime set and the lint gates. Each provider base adds only its agent install. The image name, the build path, the two tests that name them, and the two architecture documents follow. The capability layer keeps its own runtime set and its documented boundary.

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
| This container has `hadolint`, `markdownlint-cli2`, and `shellcheck` on `PATH` but no `python3` and no `uv`, which confirms the pi base shipped the linters and no Python | evidence | resolved by this iteration |
| The Hermes image put uv under `/root/.local/bin`, which the unprivileged `agentuser` cannot read, so its `ENV PATH` line never reached the agent | bug | resolved by this iteration; both install directories moved outside `/root` |
| `docs/operations/provider_onboarding_guide.md` is stale beyond Step 2: its file tree is rooted at `providers/<n>/` instead of `src/reasoning/providers/<n>/`, and Step 3's sample `COPY` paths (`/libs/`, `/usr/local/bin/provider-entrypoint.sh`, `/opt/context/config/`) match no real provider image | documentation gap | deferred; out of scope for a runtime-set change |
| No docker in the agent container, so no test asserts the runtime set inside a built image | tooling gap | deferred; criterion 1 stays operator-verified until a build-capable environment can host such a test |

## Deferred items

| Item | Reason |
|---|---|
| Give the capability layer a Node and Python runtime set | declined at the release gate; it keeps its documented no-Node boundary |
| Fix the rest of `docs/operations/provider_onboarding_guide.md` (file tree root, Step 3 sample COPY paths) | a documentation gap raised by this change but not caused by it |
| A test that asserts the runtime set inside a built image | no docker in the agent container |

## What's Next
