---
date: 2026-10-06
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - One Switch for the Harness Payload

## Objective

Make the `packages` entry the single switch that enables the harness payload, and drop the `skills` and `prompts` lists that name the same two roots again.

## Scope

The M3.3.1 ledger row `Enablement has two switches for the harness payload`, from the survey at handover `20261005-09`.

`settings.json` enables `/opt/workflow/agent` twice: once through `packages`, whose conventional `prompts/` and `skills/` subdirectories pi loads as roots, and again through the `skills` and `prompts` lists naming those same two paths. The two switches are not equivalent, because the module root `/opt/workflow/agent/modules/coding-agent` has no list entry at all: `packages` is the only thing that enables the module. The lists are the redundant half, so the asymmetry settles the decision the row was blocked on.

In scope: the shipped `settings.json`; `preflight.sh`'s `_ensure_harness_keys` merge and its verification; the four test files that read the keys; the three documents and the ADR that describe the route; the roadmap row.

Out of scope, each with its reason: the container manifest and the layout gate, which read the roots from either form and see the same four, because `settings_root_keys()` unions an explicit list with each package's conventional subdirectories; the retired `/opt/provider-config/`, swept in handover `20261005-05`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The shipped settings name the harness roots once | the `packages` entries are the only harness-root keys; no `skills` or `prompts` list remains | Agent [x] |
| The preflight merge re-injects the switch, both entries | `_ensure_harness_keys` writes `packages` holding the agent root and the module root, and its verification greps that key | Agent [x] |
| A user's own `skills` or `prompts` list is left alone | the preflight case that seeds a custom skills path still finds it afterwards | Agent [x] |
| The layout gate sees the same root set | `bash scripts/check_container_layout.sh` is clean against the tree, and its new package-only case passes | Agent [x] -- 24 cases |
| The knowledge test's recorded assumptions move with the decision | `bash tests/knowledge/knowledge_pi_config_cycle.sh`, every case passes with the new text | Agent [x] -- 4 cases |
| The documents name one switch | the three documents and the ADR's package route lose the redundant-list description | Agent [x] |
| Lint and the suite are clean | `bash scripts/lint.sh` and `bash scripts/run_tests.sh` | Agent [x] -- 8 gates clean, 1114 tests across 76 files, liveness clean |
| The handover closes | this handover | Operator [ ] |

## Hot files

| File | Why in scope |
|---|---|
| `src/reasoning/providers/pi/config/agent/settings.json` | the two lists that go |
| `src/reasoning/providers/pi/preflight.sh` | the merge and its verification |
| `tests/test_providers_pi_preflight.sh` | the merge cases, including the user-supplied path |
| `tests/knowledge/knowledge_pi_config_cycle.sh` | the recorded key assumptions |
| `tests/test_container_layout.sh` | the settings-root cases |
| `tests/test_provider_entrypoint.sh` | the seeded-config cases |
| `docs/concepts/agent_workflow.md` | the layer table and the auto-discovery note |
| `docs/architecture/provider_lifecycle.md` | the settings-seeding section |
| `docs/development/instruction-surface-conventions.md` | the module payload section |
| `docs/adr/module_instruction_payload.md` | the amendment recording the single switch |
| `devlog/roadmap.md` | this row |
| `devlog/handovers/20261006-02-workflow-one_switch_for_the_harness_payload.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `packages` is the switch, and the `skills` and `prompts` lists go | the module root is enabled only by `packages`, so the lists are the redundant half, and the ADR already rejected naming roots in the lists as two entries where one will do | this handover, and an amendment to the ADR |
| The preflight merge re-injects both package entries, not only the agent root | the module entry has no second switch, so it is the entry that must survive a runtime rewrite | this handover |
| The decision amends the existing ADR rather than adding one | the ADR already chose the package route and named the list route as a rejected alternative; this is the other half of that decision | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| `preflight.sh` re-injects `/opt/workflow/agent` into `packages` but not the module root, so the half of the payload with no second switch is the half the merge does not protect. | contradiction | current iteration |
| `tests/test_provider_entrypoint.sh` was named a hot file and needed no change: its `skills` and `prompts` mentions are directory names in the seeded config tree, not settings keys. | scope change | current iteration |
| The knowledge test's own comment said the roots reach the image "now that no merge step writes them", while the merge did write them. The comment and the merge now agree, and the merge is the half that changed. | contradiction | current iteration |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/settings.json` | the `skills` and `prompts` lists removed; `packages` holds both entries |
| `src/reasoning/providers/pi/preflight.sh` | `_ensure_harness_keys` re-injects both package entries, verifies `packages`, and no longer writes the two lists; the header comment states the single switch |
| `tests/test_providers_pi_preflight.sh` | the merge cases assert the two entries and the absent lists, the user's own list survives, and the deduplication case names a package entry |
| `tests/knowledge/knowledge_pi_config_cycle.sh` | the recorded assumptions and the roots case read `packages` only, and a check asserts that no list names a harness root |
| `tests/test_container_layout.sh` | a case pinning the package-only settings shape, 24 cases total |
| `docs/concepts/agent_workflow.md` | the layer table and the auto-discovery paragraph name the one key |
| `docs/architecture/provider_lifecycle.md` | the settings-seeding section and the sandbox-layer bullet name the one key |
| `docs/development/instruction-surface-conventions.md` | the module payload section states that the harness payload root arrives through the same key |
| `docs/adr/module_instruction_payload.md` | the 2026-10-06 decision: the package key is the payload's only switch |
| `devlog/roadmap.md` | this row closed with its landing note |
