---
date: 2026-11-22
milestone: M3.6.5 - The OpenCode provider is removed
type: Implementation
status: Closed
---

# Handover - The OpenCode provider is removed

## Objective

Execute the deletion the plan committed: remove the OpenCode provider image, its onboarding and instruction transport, the live documents and test fixtures that name it as a provider, and leave the pinned OpenCode CLI as the dispatch agent-runtime.

## Scope

This iteration works the open rows of `M3.6.5`, except `W1 is sandbox-only`, which landed in the plan commit `3cb6a10b`. It removes the provider directory and its manifest, compose, start, dry-run, Makefile and `.dockerignore` surfaces; deletes the dead `opencode-config.mjs` and its test; corrects the live provider documents; deletes the provider onboarding guide; retargets the second-provider test fixtures; and deletes the duplicated runtime documentation. The generic provider base and the rebuilt dispatch instruction transport are `M3.6.7` and out of scope. The OpenCode CLI, its pin, the dispatch seam, the role table's `opencode` and `opencode-go` model-provider prefixes, and the model-failure records are out of scope and stay.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The provider set is `pi` only and no manifest row names `opencode`. | `ls src/reasoning/agent-runtime/` prints `pi`; every provider key in `src/build/container-interface.json` reads `pi`. | Agent [x] |
| The provider image, its serve overlay, quickstart, config generator and generator test are gone. | `test ! -e src/reasoning/agent-runtime/opencode`; `test ! -e src/build/opencode-config.mjs`; `test ! -e tests/test_opencode_config.sh`. | Agent [x] |
| No live source, script or build file names `opencode` as a provider. | `grep -rn opencode src scripts tests .dockerignore docs --exclude-dir=archive` reviewed; remaining hits are the dispatch CLI, its pin, the role table's model prefixes and historical records. | Agent [x] |
| The provider onboarding guide is gone and no live document links it. | `test ! -e docs/development/provider_onboarding_guide.md`; `grep -rn provider_onboarding_guide docs workflow .agents AGENTS.md` prints nothing. | Agent [x] |
| The duplicated runtime documentation is gone and the authoring convention drops OpenCode's debug commands. | `test ! -e src/reasoning/agent/prompt-templates.md`; `grep -rn "opencode debug" .agents/skills/instruction-authoring` prints nothing. | Agent [x] |
| The second-provider test fixtures name a synthetic provider or `pi`, not `opencode`. | `grep -rn "opencode" tests/test_container_layout.sh tests/test_onboard.sh tests/test_run_agent.sh tests/test_trace_build.sh tests/test_prune.sh tests/test_resume.sh tests/test_resume_list.sh tests/test_session_inventory.sh` prints nothing. | Agent [x] |
| The affected tests and the gates pass. | `bash scripts/lint.sh`; the targeted tests; `TEST_PARALLEL=1 bash scripts/run_tests.sh`. | Agent [x] |
| Every completed roadmap row is `[x]`. | `grep -n "M3.6.5" -A 12 devlog/roadmap.md` shows the completed rows marked. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The second-provider test fixtures use the synthetic name `fixture`. | The fixtures exercise a provider-shaped path, not the removed provider; a synthetic name keeps the branch covered without naming a provider the tree does not serve. | The test files; this record |
| Serve mode is unsupported by the remaining provider. | The pi overlay starts in interactive mode; the OpenCode serve overlay left with the provider. | `tool_interface.md`; the pi serve overlay |
| The provider onboarding guide is deleted rather than rewritten. | The provider contract stays in `tool_interface.md`, the manifest and the layout gate; a new guide is written when a second provider is planned. | This record; the roadmap row |
| The duplicate prompt-template document is replaced by pi's shipped documentation path in the authoring convention. | The format is pi's; the local file restated it with no loader and no carrier. | `prompt-conventions.md`; this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `src/reasoning/agent-runtime/pi/docker-compose.serve.yml` named the removed provider as the serve alternative. | record | The comment is corrected; the overlay states pi serve is unsupported. | This iteration |
| `prompt-conventions.md` carried the OpenCode-only reason for `$ARGUMENTS`. | record | The reason is removed; the convention keeps the spelling because pi accepts it. | This iteration |
| `scripts/lint/code-snippets.baseline` carried six entries for the deleted guide. | record | The stale baseline rows are removed. | This iteration |
| The historical ADR entries still state OpenCode as a base-level provider. | record | They record what was true when written; the current entries supersede them. | Kept as history |
| The provider-removal sweep left two live OpenCode mentions in the conceptual model and the capability Dockerfile. | record | Both now use generic wording. | Review correction |
| `tests/test_onboard.sh` left the no-config provider assertion vacuous after the fixture retarget. | test | The test now asserts the call succeeds and seeds a configured provider as a positive control, so it cannot pass when `_provision_providers` never runs. | This iteration |
| `docs/reference/tool_interface.md` still described two registry-package agent-runtimes. | record | The tier names pi's frozen registry package and the pinned OpenCode CLI. | This iteration |
| `tests/test_skill_graph.sh` still constructed an `opencode` image row. | test | The second row uses `fixture`; the live-name audit now holds. | This iteration |
| The serve documents claimed a warning that `run_agent.sh` never emits. | record | The claim is dropped; serve stays unsupported and starts pi interactively. | This iteration |
| `docs/development/quickstart.md` sent readers to the pi integration notes for commands. | record | It points at `tool_interface.md`. | This iteration |
| The full serve path and the plural `providers` manifest form remain after the provider removal. | scope | Removing serve changes the CLI and is a product decision; the plural form is the kept extension point. | Review report; not this iteration |

## Completed

| File | One-line change summary |
|---|---|
| `src/reasoning/agent-runtime/opencode/` | Deleted: provider Dockerfile, serve overlay and quickstart. |
| `src/build/opencode-config.mjs`, `tests/test_opencode_config.sh` | Deleted with the provider-shaped instruction transport. |
| `src/build/container-interface.json` | Provider rows are `pi` only; the OpenCode env rows are gone. |
| `src/build/docker-compose.yml`, `src/build/compose.sh`, `src/reasoning/base.dockerfile`, `scripts/agent-sandbox.sh`, `scripts/start_agent.sh`, `scripts/dry_run_reasoning.sh`, `scripts/templates/Makefile.template`, `scripts/templates/PULL_REQUEST.md.template`, `.dockerignore` | OpenCode provider examples and branches removed. |
| `src/reasoning/agent/prompt-templates.md`, `.agents/skills/instruction-authoring/references/prompt-conventions.md` | The duplicate runtime doc is deleted; the convention names pi's shipped prompt-template documentation. |
| `.agents/skills/testing/patterns/assertions.md` | The example provider name is `pi`. |
| `docs/development/provider_onboarding_guide.md` | Deleted. |
| `docs/development/quickstart.md`, `docs/development/security.md`, `docs/development/build_operational_model.md` | OpenCode provider references removed; the second-provider build case is gone; the quickstart points at the command reference. |
| `docs/reference/provider_lifecycle.md`, `docs/reference/tool_interface.md`, `docs/reference/agent_workflow.md`, `docs/reference/project_onboarding_guide.md` | Live provider set is `pi`; the guide links, the OpenCode serve row and the env example are removed; the tier names pi's package and the pinned CLI, and the false serve warning claim is dropped. |
| `docs/reference/two_layer_model.md`, `src/capability/dockerfile` | The remaining live OpenCode provider mentions are replaced with generic wording. |
| `src/reasoning/agent-runtime/AGENTS.template.md`, `src/reasoning/agent-runtime/pi/docker-compose.serve.yml` | Guide link and OpenCode serve suggestion removed; the false warning claim is dropped. |
| `tests/test_container_layout.sh`, `tests/test_onboard.sh`, `tests/test_run_agent.sh`, `tests/test_trace_build.sh`, `tests/test_prune.sh`, `tests/test_resume.sh`, `tests/test_resume_list.sh`, `tests/test_session_inventory.sh`, `tests/test_skill_graph.sh` | Second-provider fixtures use `fixture`; the no-config provider test is restored. |
| `scripts/lint/code-snippets.baseline` | Stale entries for the deleted guide removed. |
| `devlog/roadmap.md` | The five M3.6.5 deletion rows are `[x]`. |
| `devlog/handovers/M3.6.5/20261122-02-impl-remove_the_opencode_provider.md` | This record. |
