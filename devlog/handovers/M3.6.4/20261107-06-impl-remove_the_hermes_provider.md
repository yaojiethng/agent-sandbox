---
date: 2026-11-07
milestone: M3.6.4 - The reasoning image refactor
type: Implementation
status: Closed
---

# Handover - the hermes provider is removed

## Objective

Remove the hermes provider, so the reasoning layer is the three tiers every remaining provider shares, and file its re-integration where the knowledge-store work can pick it up.

## Scope

The M3.6.4 row `The hermes provider is removed`, added by this iteration from the operator's ruling during the design exchange of 2026-11-07.

The provider is the only source-build provider, so it is the only thing that makes the tier list differ by provider: deleting it makes `<provider>-base` an unexercised extension point rather than a tier a shipped image occupies. The extension point stays, because the W row that re-integrates hermes needs it, and its test moves to a fixture provider so the branch keeps coverage without naming a removed provider.

Out of scope: the pin work, which follows on three tiers and takes the ADR entry that relaxes the apt form; the host build runs; the opencode platform binary's pin form. Each is carried by the row or the record named in Findings.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The provider tree holds pi and opencode, and the hermes path is gone | `ls src/reasoning/agent-runtime/` lists `pi` and `opencode`; `test ! -e src/reasoning/agent-runtime/hermes` | Agent [x] |
| The manifest names two providers and holds no hermes row | `jq -r '[.image[].providers[]?, .env[].provider?] \| unique \| join(" ")' src/build/container-interface.json` prints `opencode pi`; `bash scripts/check_container_layout.sh` clean | Agent [x] |
| Every live reference is gone | `grep -rn -i hermes src scripts tests docs/reference docs/development src/build AGENTS.md .dockerignore` returns no match | Agent [x] |
| The historical records keep theirs | `grep -rn -i hermes devlog/handovers devlog/discussions docs/adr` still returns them, and the ADR's entries above the new one are unchanged | Agent [x] |
| The provider-base branch keeps a test on a fixture provider | `bash tests/test_trace_build.sh` passes, and its order test names a fixture provider rather than hermes | Agent [x] |
| The ADR records three tiers as a dated entry, with the superseded entries left as written | the 2026-11-07 entry in `docs/adr/reasoning_layer_tiers.md`; the 2026-10-17 entry unchanged | Agent [x] |
| The W re-integration row and the M7 digest row exist | `grep` for both in `devlog/roadmap_future.md` | Agent [x] |
| The pin row drops hermes and states the strictest-achievable-form acceptance, and the host row states the three-run pair | `git diff c2e3575e -- devlog/roadmap.md` on those two rows | Agent [x] |
| The suite and the lint pass | `bash scripts/run_tests.sh`; `bash scripts/lint.sh` | Agent [x] |
| Every decision this iteration recorded is realized in the files | the Decisions table against the tree | Agent [x] |
| Architecture documents in scope describe the system as built | the five edited documents against the tree | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The hermes provider is removed, and the reasoning layer is three tiers for every provider | the operator's ruling: the provider is unused, has drifted, and is the only thing making the tier list differ by provider | this record; `docs/adr/reasoning_layer_tiers.md` |
| The re-integration is a W task rather than a dormant provider | a dormant provider is maintenance with no consumer; the knowledge-store work is what would give it one | `devlog/roadmap_future.md` |
| `<provider>-base` stays as an extension point, and its order test moves to a fixture provider | the W row re-adds a source-build provider, so deleting the branch would have to be undone; an unexercised branch with no test is worse than one with a test | this record; `tests/test_trace_build.sh` |
| The pin row and the host row are rewritten here to carry the pin policy the design exchange settled, including the temporary apt relaxation | those rows are the artifact of those decisions until their iteration lands, and the removal changes the input set they cover | `devlog/roadmap.md`; `devlog/roadmap_future.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The suite reported four per-file deadline expiries under parallel load; each of the four passes alone and the next full run was green at 1480 of 1480 | tooling | none on this change, but a red run that is not reproducible on demand | `devlog/AGENT_FEEDBACK.md`, a recurrence on the 2026-10-03 entry |
| The completed run brief and the two 2026-10-16 studies name hermes throughout, and the run brief is still cited by a closed roadmap row | record | none; they state what was true when the run executed | kept as history; the ADR entry names them |
| `agent_base_image_name` and the `<provider>-base` branch are now reached by no shipped provider | design | the branch keeps coverage through a fixture provider, and the W re-integration row is its consumer | this record; the ADR entry; `devlog/roadmap_future.md` |
| The pin ADR's 2026-10-16 rationale still names the hermes apt sets and clone in its census sentence | record | the sentence records what that census read, and the pin row amends the ADR with a dated entry | the pin row |

## Completed

| File | Change |
|---|---|
| `src/reasoning/agent-runtime/hermes/` | deleted: both Dockerfiles, both compose overlays and the quickstart |
| `src/build/container-interface.json` | three image rows list two providers, and the three `hermes` env rows are gone |
| `.dockerignore` | the hermes ignore line |
| `src/reasoning/base.dockerfile`, `src/reasoning/runtimes.dockerfile` | the provider comments name the providers that ship |
| `scripts/start_agent.sh`, `scripts/agent-sandbox.sh`, `scripts/dry_run_reasoning.sh`, `scripts/templates/Makefile.template`, `src/build/docker-compose.yml`, `src/reasoning/agent-runtime/pi/docker-compose.serve.yml` | the provider examples and the readiness case |
| `tests/test_trace_build.sh` | the provider-base order test rebuilt on a fixture provider; the `record_image` fixture renamed |
| `tests/test_container_layout.sh`, `tests/test_shared_base_contract.sh`, `tests/test_onboard.sh`, `tests/test_prune.sh`, `tests/test_skill_graph.sh`, `tests/test_resume.sh`, `tests/test_resume_list.sh` | the fixtures and comments that named a removed provider |
| `docs/reference/tool_interface.md`, `docs/reference/agent_workflow.md`, `docs/reference/provider_lifecycle.md`, `docs/development/provider_onboarding_guide.md`, `docs/development/build_operational_model.md` | the live statements of the provider set and the tier shape |
| `docs/adr/reasoning_layer_tiers.md` | the 2026-11-07 entry, and R5 and R6 revised in place |
| `devlog/roadmap.md` | the removal row; the section intro, the pin row, the host row and the M3.6.4 criteria line |
| `devlog/roadmap_future.md` | the W1 re-integration task, the M7 digest row, and the retired dormant-provider paragraph |
| `devlog/AGENT_FEEDBACK.md` | the 2026-11-07 recurrence on the per-file deadline entry |
