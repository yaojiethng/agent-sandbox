---
date: 2026-10-05
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - The Module Skill Surface

## Objective

Make `workflow/<module>/` the toggle unit, and give the `coding-agent` module its own instruction roots in the image, enabled by a pi package entry.

## Scope

The three skills under `workflow/coding-agent/skills/` are repository-specific, and the earlier plan moved them to `.agents/skills/` to match. The operator directed otherwise: `workflow/` holds modules, a module is what gets toggled, and the module carries its own payload. So the skills stay in the module, gain a runtime path, and become a shipped instruction surface.

The repository cannot merge the module's payload into the harness roots. A prompt root reads files into commands and a skill root reads directories holding `SKILL.md`, so one folder cannot serve both, and a merge of two sources onto one root loses which module a file came from. The merge happens in the image instead, one level heavier: the harness payload keeps `/opt/workflow/agent/{prompts,skills}/`, and the module gets `/opt/workflow/agent/modules/coding-agent/{prompts,skills}/`.

The operator chose pi's package mechanism over an explicit root entry. Two `settings.json` entries would name the module's roots directly; a package entry names the module once and its conventional `prompts/` and `skills/` subdirectories contribute themselves. The choice is verified rather than assumed: a bare directory listed under `packages`, holding only those two subdirectories and no `package.json`, contributes its skills to the injected skill list and its prompts as commands, and a local package is loaded in place without a copy. A copy would have been the objection, because a stale copy is the defect the retired provider-config transport suffered.

1. **Put the skills in loadable shape.** `handover-maintenance` and `roadmap-maintenance` become directories holding `SKILL.md`, by `git mv`; `check-in` already has that shape, with its two supporting files beside it. A bare `.md` in a skill root is invisible to the loader.
2. **Ship the module.** Two `COPY` lines per provider, one per payload kind, under `/opt/workflow/agent/modules/coding-agent/`. Two lines, not one, because a copy of the whole module folder would also ship `drafts/` and `audits/`.
3. **Enable the module.** `src/reasoning/providers/pi/config/agent/settings.json` gains the package entry. Nothing else in the settings changes.
4. **Declare it.** The manifest gains two cells, each with one source; the harness prompt cell loses its second source; the project cell is deleted, and its `devlog/` reachable row moves to the module's skill cell.
5. **Teach the gate the package convention.** A cell whose runtime path is a package's conventional subdirectory is enabled by that package entry, so the settings derivation gains those subdirectories.
6. **Check the collision the structure can hide.** Two roots under one key may hold a file, or a skill directory, of the same name. The loader resolves one and ignores the other, with nothing said.
7. **Rewrite the references** so they resolve where the skills now run: the policy links become image paths, the intra-skill links follow the new shape, and the references to non-shipping paths stay named in code spans.
8. **Repoint the four dispatchers** -- `gm.md`, `milestone-close.md`, `wrapup.md`, `drafts/maintenance.md` -- at the module root.
9. **Record the outcome.** Amended roadmap row, a finding about the two enablement switches, closed handover, one commit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Each skill is a directory holding `SKILL.md`, discoverable from the module root | `find workflow/coding-agent/skills -name SKILL.md`; the directory name matches the frontmatter `name` | Agent [x] -- three directories, each name matching its folder |
| The module ships to all three provider images at its own roots | three dockerfiles, two lines each; `bash scripts/check_container_layout.sh` | Agent [x] -- six `COPY` lines; the gate is clean |
| The settings enable the module through one package entry | read `settings.json`; the layout gate derives the module roots from it | Agent [x] -- one entry; removing it fails the gate (`tests/test_container_layout.sh`) |
| The manifest declares both module cells and no dead cell | read the manifest; `tests/test_container_layout.sh` | Agent [x] -- seven cells, each with one source; the `none` cell is gone with its folder |
| Every link in the module's skills resolves in image space | `bash scripts/check_markdown.sh` | Agent [x] -- the policy links, the intra-skill links and the prompt pointers all resolve; the gate is clean |
| Two roots under one key may not hold the same name | `tests/test_container_layout.sh`, one case per kind | Agent [x] -- two cases, one prompt file name and one skill directory name |
| The four pointers name the module root | the four files read; `grep -rn "coding-agent/skills"` returns only image paths | Agent [x] -- seven pointers, not four: `iter.md`, `milestone-start.md` and `plan.md` name a skill too, and the last one broke with the root move |
| `bash scripts/lint.sh` is clean | the command | Agent [x] -- 8 gates, clean in 7s |
| `bash scripts/run_tests.sh` is clean | the command | Agent [x] -- 1089 tests, 0 failed; the pi config knowledge test passes 5 cases |
| The row is written back and the handover closes | `devlog/roadmap.md`; this handover | Operator [ ] |

## Hot files

| File | Why in scope |
|---|---|
| `workflow/coding-agent/skills/handover-maintenance/SKILL.md`, `roadmap-maintenance/SKILL.md`, `check-in/SKILL.md` + two supporting files | the directory shape and every reference |
| `src/reasoning/providers/pi/provider.dockerfile`, `.../hermes/provider.dockerfile`, `.../opencode/provider.dockerfile` | two `COPY` lines each |
| `src/reasoning/providers/pi/config/agent/settings.json` | the package entry |
| `src/build/container-interface.json` | two module cells, one harness cell reduced, one project cell deleted |
| `src/build/container-interface.mjs` | the package convention in the settings derivation, and the collision check |
| `docs/development/instruction-surface-conventions.md` | the module root, the enablement rule, the collision rule |
| `docs/adr/instruction_surface_declaration.md` | the `none` cell keeps its rule and loses its only instance |
| `docs/architecture/tool_interface.md`, `docs/architecture/provider_lifecycle.md` | the agent tree gains a module level |
| `docs/concepts/agent_workflow.md`, `docs/concepts/autonomous_agent_loop.md`, `docs/development/conventions.md` | the layer table, two skill links, the skills index row |
| `workflow/coding-agent/prompts/gm.md`, `milestone-close.md`, `wrapup.md`, `workflow/coding-agent/drafts/maintenance.md` | the four pointers |
| `scripts/check_handover_format.sh`, `scripts/lint/handover-format.mjs` | two comments naming the skill's old shape |
| `tests/test_container_layout.sh` | the module cells, the package fixture, the collision cases |
| `devlog/roadmap.md` | this row, and the enablement-switch row this iteration files |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `workflow/<module>/` is the toggle unit, and nothing merges in the repository | the two loaders need two roots, and a merge loses provenance and hides a collision | this handover; the operator's direction |
| The module's skills ship to their own roots, not to `.agents/skills/` | the module owns its payload, and a shipped skill resolves in every container rather than only where the project is agent-sandbox | this handover, superseding roadmap row 192's earlier ruling |
| Enablement is a pi package entry | one entry toggles a module; the module's `prompts/` and `skills/` are already the package convention, so the repository layout does not change shape | this handover; verified in `/tmp` |
| A local package is loaded in place | no copy means no stale copy, which is the defect the retired provider-config transport suffered | `docs/packages.md`, verified |
| The gate derives roots from packages too | otherwise a module cell has no enablement to check against, and the declaration would drift from what loads | this handover |
| The collision check is added | the loader picks one of two same-named files silently, which is a failure with no signal | this handover |
| `.agents/skills/` stays the name for a skill that is specific to one repository | that scope has no occupant today, and an empty cell is dead config | `docs/development/instruction-surface-conventions.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The package route was verified before it was adopted, and the verification is what settles the decision: a bare directory under `packages`, holding only `prompts/` and `skills/` and no `package.json`, contributes its skills to the injected skill list and its prompts as commands, and a local package is loaded from its resolved path without a copy. The no-copy half matters: the retired provider-config transport failed because a stale copy shadowed the image's files. | evidence | current iteration | Triaged to: [`docs/adr/module_instruction_payload.md`](../adr/module_instruction_payload.md) and the knowledge test's `packages` case |
| Enablement has two switches. pi's `packages` key enables `/opt/workflow/agent`, whose `prompts/` and `skills/` subdirectories load by convention, and the `skills` and `prompts` lists name those same two paths again. The verification shows the package entry alone is enough, so the lists are redundant for that payload; `preflight.sh` re-injects them as harness-owned keys, so removing them is a change to that mechanism too. Deciding it here would widen a settled scope. | defect, silent | follow-up | Triaged to: a new roadmap row filed after this one |
| The wiring list this row carried was stale: it named `check_instruction_context.sh` (`INSTRUCTION_DIRS`, `NEUTRAL_DIRS`), `instruction-context-template.md` and a `CONTEXT.md` reachable row, all retired by handover `20261005-07`. It also named four pointers where the tree has seven: `iter.md` and `milestone-start.md` name the check-in skill, and `plan.md`'s link to the harness `grill-me` skill was correct while the two roots were siblings and broke when the module moved to its own root. | defect, silent | current iteration | Triaged to: the four pointer edits and the two extra documentation links; the checklist in the scope replaced the stale list |
| The module's payload ships in all three provider images, and only pi's config enables it. That is not a new gap -- neither hermes nor opencode names any instruction root today, so the harness payload is unloaded there too -- but the module now shares it. | scope limit | recorded | Triaged to: the existing row "The hermes and opencode images ship no provider config" |
| The delivery commit's body ran to 1248 characters against `git_policy.md`'s 280-character budget, and it repeated the handover's reasoning and listed paths, which the same paragraph forbids. Two earlier iterations' bodies were over as well, at 880 and 324. No gate reads a commit message, so the operator caught it by reading the log, and the correction rewrote all three messages. | defect, silent to every check | current iteration, and two closed iterations' commits | Triaged to: this fold, the amended messages, and the feedback entry "A commit body written as a second record" |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/{check-in,handover-maintenance,roadmap-maintenance}/` | `handover-maintenance` and `roadmap-maintenance` became directories holding `SKILL.md`; every reference rewritten so it resolves in image space |
| `src/reasoning/providers/{pi,hermes,opencode}/provider.dockerfile` | two `COPY` lines each, to the module's own roots |
| `src/reasoning/providers/pi/config/agent/settings.json` | the module package entry |
| `src/build/container-interface.json` | two module cells added, the harness prompt cell reduced to one source, the project cell deleted, one session row renamed |
| `src/build/container-interface.mjs` | the package convention in the settings derivation, `entry_names`, and `check_names` |
| `docs/adr/module_instruction_payload.md` | new: the decision, the verification, and the four rejected routes |
| `docs/adr/instruction_surface_declaration.md` | the enablement clause and the `none` cell's lost instance |
| `docs/development/instruction-surface-conventions.md` | the module root, the package enablement, the collision rule, and the example cell |
| `docs/architecture/tool_interface.md`, `provider_lifecycle.md`, `docs/concepts/agent_workflow.md` | the module roots and how they load |
| `docs/concepts/autonomous_agent_loop.md`, `docs/development/conventions.md`, `docs/development/prompt-authoring-conventions.md` | two skill links, the skills index row, and where a module's prompt runs |
| seven pointers across six prompt files and one draft | the module root, as links for the shipped prompts and as repository paths for the draft |
| `workflow/coding-agent/audits/surface-area-report.md` | four links to the skills' new shape |
| `scripts/check_handover_format.sh`, `scripts/lint/handover-format.mjs` | two comments naming the retired file name |
| `tests/test_container_layout.sh` | the module fixture, the package entry, and three cases: a module root with no entry, a prompt name in two roots, a skill name in two roots |
| `tests/knowledge/knowledge_pi_config_cycle.sh` | the module entry in the settings case |
| `devlog/roadmap.md` | this row and the enablement row |
