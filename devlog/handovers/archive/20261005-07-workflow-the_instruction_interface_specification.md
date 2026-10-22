---
date: 2026-10-05
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - The Instruction Interface Specification

## Objective

Declare the instruction surfaces once, in the container interface manifest, and retire the five per-folder `CONTEXT.md` files that repeat the declaration.

## Scope

Roadmap row: **The instruction interface specification, and the retirement of `CONTEXT.md`**. Operator direction at handover `20261005-06`: one machine-readable specification in place of a file per folder.

The state to remove. Five `CONTEXT.md` files declare five instruction runtime paths in 210 lines, of which 59 are one twelve-row reachable set rewritten per file. `check_instruction_context.sh` compares those copies against each other, so the drift check exists only because the rows are repeated.

Nine items:

1. **The manifest gains `session` and `cells`.** `session` holds the twelve rows once: they are the environment of a session in a container, not a property of a surface, and no cell claims them. A cell carries its own source folders, runtime path, loader, an optional `provider`, and the reachable rows whose condition is not `always`. A cell may carry none.
2. **The name widens with the content.** `image-map.json` and `image-map.mjs` become `container-interface.json` and `container-interface.mjs` in `src/build/`, beside the `x-workspace` path table in `src/build/docker-compose.yml` that was this declaration in prose. `scripts/lint/` holds rules; this is not one. The gates stay in `scripts/`.
3. **The module owns the schema and the derivations.** `check` gains the field rules; the folder set for an `/opt` cell comes from the image rows landing there, for a `$AGENT_HOME` cell from the provision tree it sits in, and for a `none` cell from the folder no image row copies; every destination under `/opt/workflow/agent/` must be a cell or the provision template; each `/opt` cell runtime path must be a root in pi's `settings.json`, parsed rather than grepped; a `runtime_path: none` cell names no image path in its row; a cell with no `provider` names no provider name in its `loader`.
4. **The surfaces gate reads the manifest.** `check_image_map.sh` becomes `check_container_layout.sh`, and `check_instruction_context.sh` becomes `check_instruction_surfaces.sh` and keeps two checks: the two `AGENTS.md` `## Scope` tables partition the `session` rows, and the loop inventory matches the policy's `scope`. The file-shape checks, the drift comparison and the marker-over-declaration-text check go with their subject.
5. **The scoping rule over file content stays a hand rule.** The whitelist-and-blacklist scan is not built. Measured: it was checked by hand at `20261005-06` across the three candidate skills and found nothing, and a dead path in a shipped prompt root fails in front of a reader immediately. The scan stays on the outgoing-link and file-path gate row, unbuilt, with its shape recorded there.
6. **The model is recorded in an ADR.** `docs/adr/instruction_surface_declaration.md`: the scopes crossed with their loaders, the condition vocabulary, the single declaration, and the silence test that decided what is checked.
7. **The how-to replaces the template.** `docs/development/instruction-context-template.md` becomes `docs/development/instruction-surface-conventions.md`.
8. **The five `CONTEXT.md` files are deleted**, and every live reference follows. One over-claim is corrected on the way: `workflow/coding-agent/skills/CONTEXT.md` lists the twelve `/opt` rows although no image carries it, and its cell carries `devlog/` alone.
9. **The consumers and tests follow.** `record-links.mjs` imports the moved module and takes its instruction roots from `cells`; `tests/test_image_map.sh` becomes `tests/test_container_layout.sh`; `tests/test_instruction_context.sh` becomes `tests/test_instruction_surfaces.sh` with the retired cases removed and the count stated.

Items 1 to 4 are one change: the declaration, its reader and its gates land together.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every instruction source folder appears in exactly one cell, with its runtime path and loader | read `src/build/container-interface.json`; the layout gate fails on a folder no cell claims | Agent [x] -- six cells: the merged prompt root, the harness skill root, the pi config home, its prompt and skill folders, and the coding-agent skills |
| The twelve session rows are declared once and no cell restates them | read the manifest; a cell carries only rows whose condition is not `always` | Agent [x] -- `session` holds the twelve; the six cells carry ten conditioned rows between them |
| A `none` cell names no image path, and a cell with no `provider` names no provider in its loader | `tests/test_container_layout.sh` cases, one each | Agent [x] |
| The specification and its reader live in `src/build/`, the gates in `scripts/`, and nothing reads `scripts/lint/image-map.*` | `grep -rn "image-map"` across the tree, archives excluded | Agent [x] -- the two files moved; the only remaining mentions are historical records |
| The derived folder set, the workflow-tree coverage and the pi settings root are checked | `tests/test_container_layout.sh`; `bash scripts/check_container_layout.sh` | Agent [x] -- 20 cases; the gate is clean |
| The two layer tables and the loop inventory still hold | `bash scripts/check_instruction_surfaces.sh` | Agent [x] -- 8 cases; the gate is clean across 12 session rows |
| The five `CONTEXT.md` files are gone with no live reference, and the over-claim is corrected | `ls` the five paths; `grep -rn "CONTEXT\\.md"` across the tree, archives and the domain-model skill excluded | Agent [x] -- remaining mentions are the ADR's rationale and the historical roadmap rows |
| The model is in an ADR, the how-to in a development document | read `docs/adr/instruction_surface_declaration.md` and `docs/development/instruction-surface-conventions.md` | Agent [x] -- the conventions document is indexed from `docs/development/conventions.md` and named by the ADR |
| The rule takes its instruction roots from the declaration | read `scripts/lint/record-links.mjs`; `bash scripts/check_markdown.sh` | Agent [x] -- `instructionRoots` is the shipping cells' folder sets; the markdown gate is clean |
| The retired test cases are removed with the count stated | read `tests/test_instruction_surfaces.sh`; `bash scripts/run_tests.sh` | Agent [x] -- 30 cases became 28: 7 retired with their subject, 8 moved to the layout gate, 8 new; 1086 tests pass |
| `bash scripts/lint.sh` is clean | the command | Agent [x] -- 8 gates, clean in 7s |
| The declaration, the names, the ADR and the reduced scope are accepted | operator acceptance at the release gate | Operator [ ] |

## Hot files

| File | Why in scope |
|---|---|
| `src/build/container-interface.json` | new: the one declaration, from `scripts/lint/image-map.json` plus `session` and `cells` |
| `src/build/container-interface.mjs` | new: the only reader, from `scripts/lint/image-map.mjs`, plus the schema and the derivations |
| `scripts/lint/image-map.json`, `scripts/lint/image-map.mjs` | deleted by the move |
| `scripts/check_image_map.sh` | becomes `check_container_layout.sh` |
| `scripts/check_instruction_context.sh` | rewritten as `check_instruction_surfaces.sh` |
| `scripts/lint.sh` | the gate names, and the header that names one of them |
| `scripts/lint/record-links.mjs` | imports the moved module; roots come from `cells` |
| `docs/adr/instruction_surface_declaration.md` | new: the model |
| `docs/development/instruction-context-template.md` | replaced by `instruction-surface-conventions.md`, indexed from `conventions.md` |
| `docs/architecture/tool_interface.md`, `docs/architecture/provider_lifecycle.md` | name the manifest, its home, and the two sections |
| `docs/operations/iteration_policy.md` | names the surfaces gate |
| the five `CONTEXT.md` files | deleted |
| `tests/test_image_map.sh`, `tests/test_instruction_context.sh` | rewritten and renamed |
| `tests/knowledge/knowledge_pi_config_cycle.sh` | names the manifest in its reference list |
| `devlog/roadmap.md` | this row, the two amended rows, and the row that inherits the deferred scan |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The declaration and its reader move to `src/build/`, the gates stay in `scripts/` | `scripts/lint/` holds rules, and this is the container's layout rather than a rule about it; `src/build/docker-compose.yml` already carries the `x-workspace` path table, the same declaration in prose. Operator question answered at `20261005-06`. | this handover |
| One declaration replaces five files, and the drift check goes with the repetition | the twelve rows are the container's, not a folder's; five copies of one set is what required a comparison | this handover |
| The twelve rows are the session's, and a cell may claim none | a project-scope surface must not assume a container layout, so inheritance cannot be mandatory. Operator correction. | this handover |
| `provider` is optional rather than a `neutral` flag | `neutral` described "carried by every provider image", which is meaningless for a surface no image carries; its absence now means provider-agnostic | this handover |
| A check earns its place when the failure is silent and late, not when it is loud and immediate | the declaration drift is silent and was found a unit later; an image path in a project skill fails in front of a reader at once. This is why the declaration is checked and file content is not. Operator decision. | this handover, and the ADR |
| The model goes to an ADR, the how-to to a development document | an ADR states a decision and holds no live data | [`docs/operations/adr_policy.md`](../docs/operations/adr_policy.md) |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The pi skills surface declared its runtime path as `$AGENT_HOME/skills/` while the parenthetical beside it read `/home/agentuser/.pi/agent/skills/`. The compose overlay settles it: the directory is bind-mounted at `$AGENT_HOME/agent/skills/`, so the field was wrong. The retired gate never caught it, because its `$AGENT_HOME` branch checked only that a copied parent existed, not the suffix. Deriving the folder set from the provision row makes the suffix part of the check. | defect, silent | current iteration | Triaged to: `src/build/container-interface.json`, and the ADR's rationale |
| A sixth cell was needed beyond the five runtime paths. The pi config home itself carries the agent `AGENTS.md`, so it is a surface, and its prompt and skill folders are two more. Without it the link rule's instruction roots could only be derived with a hard-coded exception. | scope change | current iteration | Triaged to: this handover's Scope item 1, and the manifest |
| The retired gate's `always`-set drift check was the largest block of its bash and existed only because five files repeated one list. Its test cases (`drift`, `conditioned rows may differ`) went with it. | coverage change | current iteration | Triaged to: `tests/test_instruction_surfaces.sh`, with the count stated in the acceptance table |
| `docs/development/prompt-authoring-conventions.md` paired pi's agent home with the wrong source: "`~/.pi/agent/`, seeded from `src/reasoning/agent/`". The home is seeded from `src/reasoning/providers/pi/config/agent/` through the config template, and the two prompt folders feed `/opt/workflow/agent/prompts/`. Found by the operator's consistency question, not by a gate: the sentence is prose about a pairing, and only the paths in it were ever resolved. | defect, silent | current iteration | Triaged to: `docs/development/prompt-authoring-conventions.md`; fixed in this unit |

## Completed

| File | Change |
|---|---|
| `src/build/container-interface.json` | the declaration, moved from `scripts/lint/image-map.json`; `session` (12 rows) and `cells` (6 rows) added, with the note rewritten |
| `src/build/container-interface.mjs` | the reader, moved; `session_paths` and `check_cells` added, `check` extended with the cell schema and the derivations, `session` added to the CLI |
| `scripts/check_container_layout.sh` | from `check_image_map.sh`; wraps the module, names the wider subject, seam `CONTAINER_INTERFACE_SCAN_ROOT` |
| `scripts/check_instruction_surfaces.sh` | rewritten from `check_instruction_context.sh`: the layer split and the loop inventory only, 200 lines against 557 |
| `scripts/lint/record-links.mjs` | imports the moved module; `instructionRoots` derived from the shipping cells |
| `src/reasoning/agent/prompts/CONTEXT.md` and four siblings | deleted, 210 lines |
| `docs/development/instruction-surface-conventions.md` | new, replacing `instruction-context-template.md`; indexed from `conventions.md` |
| `docs/adr/instruction_surface_declaration.md` | new: the model, the derivations, the silence test, and the rejected alternatives |
| `docs/architecture/tool_interface.md`, `docs/architecture/provider_lifecycle.md`, `docs/development/prompt-authoring-conventions.md`, `docs/operations/iteration_policy.md`, `docs/development/conventions.md`, `devlog/roadmap.md` | the manifest's name and home, the surfaces gate's name, the reference rules rewritten around the real root-to-source pairing, the new index row, and four roadmap rows |
| `tests/test_container_layout.sh`, `tests/test_instruction_surfaces.sh` | from the two retired files: 30 cases became 28 -- 7 retired with their subject, 8 moved, 8 new |
| `tests/knowledge/knowledge_pi_config_cycle.sh` | the manifest's new path in its reference list |
