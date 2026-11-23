---
date: 2026-11-22
milestone: M3.6.5 - The OpenCode provider is removed
type: Implementation
status: Closed
---

# Handover - The provider serve mode is removed

## Objective

Remove serve mode from the harness, because the only provider that implemented it left with M3.6.5 and the remaining path starts pi with no published port while reporting a browser URL.

## Scope

This iteration works the M3.6.5 row `The provider serve mode is removed`. It removes the mode from the Makefile, the agent-sandbox CLI, `start_agent.sh` and `run_agent.sh`, deletes the pi serve overlay, and corrects the live reference and onboarding documents, the `.env` stub and the tests. Serve-specific live sections whose subject the deletion removes are deleted with it; no new ADR is opened. Standard and dry-run modes, the compose merge, and every non-serve provider file stay. The review's manifest shared-row note, Makefile alignment, test-comment grammar and testing-pattern example are outside this iteration.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The serve mode is absent from the live CLI, build surface and templates. | `grep -rniE 'serve mode\|serve overlay\|serve port\|serve container\|SERVE_PORT\|--serve' scripts src docs tests` prints only historical or dated-correction lines. | Agent [x] |
| The serve overlay is deleted and no live file requires it. | `test ! -e src/reasoning/agent-runtime/pi/docker-compose.serve.yml`; `grep -rn "docker-compose.serve" .dockerignore docs scripts src tests` prints no hit. | Agent [x] |
| The `--serve` flag is removed and the Makefile has no `SERVE` variable. | `grep -rn -- "--serve" scripts src` prints no hit; `grep -n "SERVE" scripts/templates/Makefile.template` prints no hit. | Agent [x] |
| Onboarding and the live docs carry no serve port or serve mode. | `grep -rn "SERVE_PORT\|serve mode" scripts/onboard.sh docs/development/quickstart.md docs/reference/project_onboarding_guide.md docs/reference/tool_interface.md docs/reference/execution_model.md` prints no hit. | Agent [x] |
| The serve-specific tests are removed or retargeted and the gates pass. | `TEST_PARALLEL=1 bash scripts/run_tests.sh`; `bash scripts/lint.sh`. | Agent [x] |
| The architecture documents in scope describe the system as built. | Read the four live documents; no serve mode, port or required overlay remains. | Agent [x] |
| Every decision this iteration records is realized in the files. | The checks above. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Serve mode is deleted, not kept as a fail-closed stub. | The only serve implementation left with OpenCode; a stub still carries a flag, a port, an overlay and a URL with no provider to serve it. | This record; the roadmap row |
| `SERVE_PORT` is removed from the `.env` stub and the docs; existing `.env` keys are left untouched. | No mode reads the value; removing the write stops new sandboxes carrying it without rewriting an operator's file. | This record; `onboard.sh` |
| The provider contract no longer requires `docker-compose.serve.yml`. | The overlay exists only for serve; no provider supplies a supported one. | This record; `tool_interface.md` |
| The `SERVE` flag is removed entirely; a stale `SERVE=1` is an unused Make variable, not a guarded error. | The operator chose removal with no replacement surface, and a guard would add a second surface for a flag the tree no longer reads. | This record |
| No new ADR records the serve removal. | A feature deletion leaves no standing principle to govern; the live documents are deleted and the existing provider-removal ADR remains the authority for that decision. | This record |
| The provider AGENTS template is deleted with its reference section and `.dockerignore` line. | It was a reference for a second provider; the onboarding guide is gone and M3.6.7 builds the neutral base instead, so no consumer remains. | This record |
| No `.env.example` file is added. | The generated `.env` is the source; a static example would duplicate `_write_env_file` and drift. The docs name its keys and point at the generator. | This record; `onboard.sh` |
| The provider contract is enforced by a test, not another documentation row. | The lost entrypoint and host-ID requirements are build-time facts; `test_shared_base_contract.sh` now reads every provider Dockerfile. | This record; the test |
| A stale document or comment is deleted or replaced by a pointer to the code. | A description allowed to go stale is not read; the code is the contract. | This record |
| Historical ADR entries keep the state of their date; a dated correction note names the later change. | A dated entry is citable only when its date bounds its content. | This record; the two ADRs |
| This iteration supersedes handover 02's "serve mode is unsupported" decision: serve is removed. | A reader of 02 alone would think the mode still exists. | This record |
| This iteration closes on the propagation audit, not on the suite alone. | The suite and lint do not know the deleted tokens; the audit is the only check that finds a stale carrier. | This record; `propagation-check` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The 2026-11-22 thermo-nuclear review found serve mode live with no provider, a dead URL and a zero exit. | code | This iteration owns the removal. | The roadmap row |
| The review's manifest shared-row note, Makefile alignment, test-comment grammar and testing-pattern example are outside the serve surface. | scope | Left to a later iteration; not changed here. | This record, out of scope |
| `tests/test_start_agent.sh` still expected `--serve` in the help output. | test | The expectation is removed. | This iteration |
| `tests/mutations/catalog.jsonl` carried two serve mutation rows. | test | The rows are removed; the surviving catalog has no serve subject. | This iteration |
| The first serve sweep was case-sensitive and missed five live carriers: the PR template, the base compose comment, the dry-run overlay comment, the pi compose overlay comment and the capability entrypoint comment. | test | The corrected case-insensitive sweep is clean except the historical ADR; the carriers are fixed. | This iteration |
| The `SERVE_PORT` hunk removed the provider setup hook banner and its export sentence, and the test header cited the missing marker. | code | The banner, sentence and indentation are restored. | This iteration |
| The review's stale unit count, onboard pin cite, fixture grammar, roadmap serve-container clause and thin teardown helper were adjacent to the removal. | record | Corrected in the same pass. | This iteration |
| Two live OpenCode provider mentions remained in the conceptual model and the capability Dockerfile. | record | Both now use generic wording. | This iteration |
| The provider-authoring pointers named `providers/`, a root that does not exist; the AGENTS template had no consumer after the guide deletion. | record | The pointers now name `src/reasoning/agent-runtime/`, and the template and its reference section are deleted. | This review correction |
| The serve removal left a pointer to a deleted docker-wait comment. | code | The comment now states the teardown reason directly. | This review correction |
| `agent_workflow.md` still described the deleted AGENTS template as a live baseline. | record | The paragraph now points at the only provider AGENTS.md and M3.6.7's base. | This review correction |
| Three historical ADR entries were rewritten in place: `task_queue_primitive.md`, `resolution_model.md`, and `reasoning_layer_tiers.md`. | record | Reverted to their dates' states; each carries a dated correction note. | This review correction |
| The decision-records evolve pattern permitted "condense the demoted entry", which is how a historical rationale was rewritten twice. | instruction | Step 4 now forbids deleting, condensing or rewriting a historical rationale; the current-entry rule names the dated-entry exception. | This review correction |
| The current instruction-surface ADR said the manifest cells declare the neutral base, which no cell does and which does not exist yet. | record | The clause now says the cells declare the skill roots and the neutral base is M3.6.7's to create. | This review correction |
| The first-run `.env` step named provider variables that do not exist. | record | It names `INSTALL_DIR` and `AUTOSAVE_INTERVAL`; the provider-stub sentence points at `_provision_providers`. | This review correction |
| The provider contract lost the entrypoint and host-ID requirements with the guide. | gate | `test_shared_base_contract.sh` now reads every provider Dockerfile. | This review correction |
| `test_standard_teardown_is_last_compose` was an identity wrapper around a one-caller helper. | test | The helper is inlined and deleted. | This review correction |
| The test header said "the teardown verb per mode" and two double-blank gaps remained. | test | The header is current and the gaps are gone. | This review correction |
| Mutation B20 was dropped with the serve rows. | test | Retargeted to the remaining `dry-run` mode word. | This review correction |
| `pi/provider.dockerfile` set `AGENT_HOME` and `PROVIDER_NAME` twice. | code | The duplicate ENV lines are removed. | This review correction |
| The propagation sweep excluded all of `devlog/`, so it missed the live roadmap paths, and it did not cover the active drafts. | process | The sweep now classifies historical records separately and covers the live roadmap and drafts; the stale paths are corrected. | This review correction |

## Completed

| File | One-line change summary |
|---|---|
| `scripts/templates/Makefile.template` | The `SERVE` variable, translator, help rows and target argument are removed. |
| `scripts/start_agent.sh`, `scripts/run_agent.sh`, `scripts/agent-sandbox.sh` | The `--serve` flag, serve mode, overlay requirement, port resolution and browser URL are removed. |
| `scripts/onboard.sh` | `SERVE_PORT` leaves the `.env` stub and the onboarding summary. |
| `src/build/compose.sh`, `src/reasoning/entrypoint.sh` | The serve comments are removed. |
| `src/reasoning/agent-runtime/pi/docker-compose.serve.yml` | Deleted. |
| `.dockerignore` | The overlay line is removed. |
| `docs/reference/tool_interface.md`, `docs/reference/execution_model.md`, `docs/development/quickstart.md`, `docs/reference/project_onboarding_guide.md` | Serve mode, port, overlay and required-file claims are removed. |
| `tests/test_makefile_template.sh`, `tests/test_onboard.sh`, `tests/test_run_agent.sh`, `tests/test_trace_compose_gen.sh`, `tests/test_start_agent.sh` | Serve expectations are removed; refresh preservation and the compose runtime-var test use `AUTOSAVE_INTERVAL`. |
| `tests/mutations/catalog.jsonl`, `tests/test_cli_lib.sh` | The two serve mutation rows and the stale `--serve` passthrough example are removed. |
| `scripts/templates/PULL_REQUEST.md.template`, `src/build/docker-compose.yml`, `src/build/docker-compose.dry-run.yml`, `src/reasoning/agent-runtime/pi/docker-compose.pi.yml`, `src/capability/entrypoint.sh` | The remaining serve-mode comments and the PR checklist row are removed. |
| `docs/reference/two_layer_model.md`, `src/capability/dockerfile` | The remaining live OpenCode provider mentions are replaced with generic wording. |
| `tests/test_resume.sh`, `tests/test_onboard.sh`, `tests/test_run_agent.sh`, `devlog/roadmap.md` | Test grammar, the pin cite, the unit count and the teardown helper are corrected; the roadmap worker-scope row names the agent container. |
| `AGENTS.md`, `docs/reference/agent_workflow.md`, `scripts/run_agent.sh`, `src/build/docker-compose.yml`, `src/reasoning/agent-runtime/pi/`, `tests/test_shared_base_contract.sh`, `docs/adr/skill_layer_resolution.md` | The remaining `providers/` paths are corrected to `src/reasoning/agent-runtime/`; the stale docker-wait pointer is replaced with its reason. |
| `src/reasoning/agent-runtime/AGENTS.template.md`, `.dockerignore`, `docs/reference/agent_workflow.md` | The provider AGENTS template, its build-context exclusion and its reference section are deleted. |
| `docs/adr/task_queue_primitive.md`, `docs/adr/resolution_model.md`, `docs/adr/reasoning_layer_tiers.md`, `docs/development/quickstart.md`, `docs/reference/project_onboarding_guide.md`, `docs/reference/tool_interface.md` | The historical entries keep their dates and carry corrections; the `.env` instructions name the generated keys. |
| `devlog/roadmap.md`, `devlog/roadmap_future.md`, `.agents/drafts/m3_4-container_execution_model-run.md`, `.agents/drafts/cost-aware-dispatch-run.md` | The live roadmap and active drafts use the current provider paths; the cost run records the settled provider decision and drops the deleted Dockerfile tasks. |
| `docs/development/build_operational_model.md` | The URL-artifact subject is named as the OpenCode CLI, not the removed provider. |
| `.agents/skills/decision-records/SKILL.md`, `.agents/skills/decision-records/patterns/evolve.md` | The historical-entry rule now forbids condensing or rewriting a demoted entry's rationale. |
| `docs/adr/instruction_surface_declaration.md` | The current entry no longer claims a neutral-base cell exists. |
| `tests/test_shared_base_contract.sh`, `tests/test_run_agent.sh`, `tests/mutations/catalog.jsonl`, `src/reasoning/agent-runtime/pi/provider.dockerfile` | The provider entrypoint/host-ID contract is gated; the teardown test is inlined; B20 is retargeted; duplicate ENV lines are removed. |
| `devlog/roadmap.md` | The six closed M3.6.5 rows are compacted and the serve-mode row is marked. |
| `devlog/handovers/M3.6.5/20261122-03-impl-remove_the_provider_serve_mode.md` | This record. |
