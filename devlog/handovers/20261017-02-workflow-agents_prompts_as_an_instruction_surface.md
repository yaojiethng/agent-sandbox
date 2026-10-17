---
date: 2026-10-17
milestone: M3.6.5 - OpenCode as a first-class provider
type: Workflow
status: Closed
---

# Handover - `.agents/prompts/` as a declared instruction surface

## Objective

Make `.agents/prompts/` an instruction surface pi loads, so the project's own prompt commands are invocable in a dogfood session and the manifest declares where they come from.

## Scope

The M3.6.5 row **`.agents/prompts/` becomes a fourth instruction surface**, pulled ahead of its milestone order on operator direction (2026-10-17) while M3.6.4 stays the active milestone. The row's own content is what lands: a manifest cell, the surface contract, and its check.

The load mechanism is settled: the pi settings record names the mount path in its `prompts` key. The operator chose it over a `--prompt-template` flag on the provider's command after the first pass landed the flag: a missing folder in the settings key is skipped silently, where the flag records an error diagnostic for every project without the folder, and the flag loads only when the session starts at the mount root. Both forms are recorded in Decisions with the measurement that decided them.

Out of scope: the content of `.agents/prompts/auto.md` and `.agents/prompts/resync.md` beyond the paragraph in `resync.md` this change falsifies; OpenCode's generated command surface, which is M3.6.5's own rows; and the two commits that created these files without a handover, which is a record defect reported at check-in rather than repaired here.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| In this project, `resync` and `auto` are offered as prompt commands and expand when run, with no runtime flag | `pi -p "/resync"` in the project expanded the prompt and ran its four steps; type `/` in a session to see both in completion | `Agent [x]` |
| The manifest and the image agree, with the surface declared and named by the settings record | `bash scripts/check_container_layout.sh` prints `clean` | `Agent [x]` |
| Removing the path from the settings record's `prompts` key makes the gate fail | `bash tests/test_container_layout.sh`, plus the mutation run against the real tree | `Agent [x]` |
| A project-tree cell the settings record omits is a finding, and one the record names at a different path is a finding | `bash tests/test_container_layout.sh`, cases `test_project_tree_cell_missing_from_settings_flagged` and `test_project_tree_cell_named_at_another_path_flagged` | `Agent [x]` |
| A project-tree cell naming no provider is a finding | `bash tests/test_container_layout.sh`, case `test_project_tree_cell_with_no_provider_flagged` | `Agent [x]` |
| The surface contract states the project-tree scope and the settings carrier | `docs/development/instruction-surface-conventions.md` section `## A surface the project tree carries`, and the ADR entry dated 2026-10-17 | `Agent [x]` |
| `resync.md` no longer says the surface is undeclared | `grep -n "No manifest cell declares" .agents/prompts/resync.md` returns nothing | `Agent [x]` |
| The documents in scope describe the system as built | read the conventions doc's scope section and the ADR entry against `container-interface.json` | `Operator` |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The surface is declared on the session's project tree, not on an image path | the files travel with the project; no image carries them, and the mount is already declared as a `session` row | this record |
| The pi settings record names the mount path in its `prompts` key | a missing path in that key is skipped silently, so a project without the folder costs nothing; the absolute value is the mount the `session` rows already declare | this record; ADR `instruction_surface_declaration.md` |
| The `--prompt-template` flag is rejected | it records an error diagnostic for the flag's path when the folder is absent, which the interactive UI renders at every session start in a project without it, and it loads only when the session starts at the mount root | this record; ADR `instruction_surface_declaration.md` |
| The manifest cell names `provider: pi` | the loader is pi's settings record, and the provider field is present only when the surface belongs to one provider | this record |
| A cell under a `session` path must be named by its provider's `prompts` key | without the carry the surface is declared and never loaded, which is the silent failure the declaration exists to prevent | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Destination |
|---|---|---|---|
| The `--prompt-template` route reports every project without `.agents/prompts/` at session start, and loads only from the mount root | defect | the first pass landed an error surface in every session that is not this repository, for a relative path only | amended: the settings record is the carrier |
| `.agents/prompts/auto.md` names the `poteto-mode` skill, which no image ships, so `/auto` will fail in any container that does not carry the operator's installed copy | defect | the command is offered and its first instruction cannot be followed | roadmap row `auto.md` names a skill no image ships, under M3.6.5 |
| `.agents/prompts/` files are already in the frontmatter lint's subject set (`scripts/lint/frontmatter.mjs:71`), so no new content check is needed for them | constraint | the row's "and its check" is the layout gate, not a second lint pass | closed here |
| `.agents/prompts/auto.md` is the only file in the tree with no closing newline, and the Markdown gate reports it | defect | the whole-tree lint run fails until it is fixed, so it blocks any iteration's suite | closed here |
| The frontmatter gate listed `.agents/prompts` as a root a cell does not declare, and its subject-set test counted the roots without de-duplicating them, so the now-declared source was counted twice | defect | the test failed on a correct tree, and the gate's own comment stated a fact the manifest contradicts | closed here |
| Two commits added `.agents/prompts/auto.md` and `.agents/prompts/resync.md` with no handover and no roadmap row | process defect | the record cannot say why the files exist or what shape they were meant to take | new entry `[A] 2026-10-17` in `devlog/AGENT_FEEDBACK.md` |

## Completed

| File | Change |
|---|---|
| `src/build/container-interface.json` | one cell: `.agents/prompts/`, runtime path in the session's project tree, `provider: pi`, loader naming the settings record |
| `src/build/container-interface.mjs` | the project-tree branch in `check_surface` and its settings-record carry check; `check_no_copy` shared with the `none` branch |
| `src/reasoning/providers/pi/config/agent/settings.json` | the `prompts` key naming the project's prompt root |
| `tests/test_container_layout.sh` | five cases for the project-tree cell, its carry, and its two negatives; `add_project_cell` and `settings_edit` helpers |
| `docs/development/instruction-surface-conventions.md` | the fourth runtime-path scope, its section, the corrected `.agents/skills` sentence, and the gate's finding list |
| `docs/adr/instruction_surface_declaration.md` | a dated entry for the scope, the settings carrier and the five rejected routes |
| `.agents/prompts/resync.md` | the paragraph claiming no cell declares the surface |
| `.agents/prompts/auto.md` | the missing closing newline |
| `scripts/lint/frontmatter.mjs` | the root comment, which said no cell declares `.agents/prompts` |
| `scripts/check_container_layout.sh` | the header naming the project-tree finding |
| `tests/test_lint_umbrella.sh` | the subject-set test de-duplicates the roots it counts |
| `devlog/roadmap.md` | the row marked `[x]`; M3.6.5 promoted to `In progress`; the `auto.md` follow-on row filed |
| `devlog/AGENT_FEEDBACK.md` | the entry for the two unrecorded commits |
