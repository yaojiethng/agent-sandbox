# Instruction Surface Conventions

## What a surface is

An instruction surface is a folder an agent loads prompts or skills from. The surfaces are declared as data in [`src/build/container-interface.json`](../../src/build/container-interface.json), in its `cells` section, and the model behind them is in [`docs/adr/instruction_surface_declaration.md`](../adr/instruction_surface_declaration.md).

A cell answers three questions about a surface:

1. **What lands there** -- the source folders that land on the runtime path.
2. **Where it runs** -- the runtime path, or `none` when no image carries the folder.
3. **Loaded when** -- the condition under which the agent can load a file from it.

A runtime path is the subject rather than a source folder, because two source folders can land on one, and then one cell names both. What the gate refuses is two cells on one path, because they would overwrite each other in the image. A module's payload does not merge into the harness roots: `workflow/<module>/prompts/` lands on `/opt/workflow/agent/modules/<module>/prompts/`, its own root. A merge loses which module a file came from, and it lets one module's file shadow another's with nothing reported. That shadowing is checked instead: no two roots under one settings key may hold a file, or a skill directory, of the same name.

## The shape

```json
{
  "sources": ["workflow/coding-agent/prompts/"],
  "runtime_path": "/opt/workflow/agent/modules/coding-agent/prompts/",
  "loader": "the running provider's config enables the module's package directory, whose prompts folder contributes every Markdown file here as a command",
  "reachable": [
    { "path": "devlog/", "holds": "the records the workflow prompts read and write", "condition": "the reader has the repository tree" }
  ]
}
```

| Field | Rule |
|---|---|
| `sources` | Every folder that lands on the runtime path, trailing slash, in the order the provider dockerfile copies them. No folder appears in two cells. |
| `runtime_path` | `/opt/...`, `$AGENT_HOME/...`, or `none`. |
| `loader` | The condition, not the mechanism. A surface that belongs to no provider names no provider here. |
| `provider` | Optional. Present only when the surface belongs to one provider, and then only to a provider that carries a dockerfile. |
| `reachable` | The rows this surface adds to the session environment. Optional, and often absent. A row carries `path`, `holds` and `condition`. |

## The session rows

The `session` section holds the paths every surface is read alongside: the project tree, the workspace directories, the image's roots, and `$AGENT_HOME/`. They describe the environment rather than a surface, so a cell does not restate them.

A cell's own rows carry a condition that is not `always`. The condition vocabulary is:

| Condition | Meaning | Example |
|---|---|---|
| `<provider> delivery` | only that provider's image carries the path; legal only in that provider's cell | `/opt/workflow/agent/config/` under `pi delivery` |
| a named state | the session is in that state | `the reader has the repository tree` |

`$AGENT_HOME/` is the resolution for a provider's own config home. The variable is set in every provider image, so a surface that belongs to no provider names the variable and not the value.

## Scope

A surface with a runtime path ships in an image, and its files are read by an agent running in a container. A surface whose runtime path is `none` ships nowhere: it travels with the project, is reached by a reference that names it, and is read from the repository. Such a surface names no image path and no provider, in its cell or in its files. It states the project's own structure and nothing outside it.

Two surfaces declare one provider's config home: the home itself, which carries the agent `AGENTS.md` and the settings record, and the prompt and skill folders inside it.

## A module's payload

`workflow/<module>/` is a toggle unit. Its `prompts/` and `skills/` folders are its payload, and each ships to its own root under `/opt/workflow/agent/modules/<module>/`. A module is enabled by naming its directory as a package: pi's `settings.json` carries `/opt/workflow/agent/modules/coding-agent` in its `packages` key, and the package convention contributes that directory's `prompts` and `skills` subdirectories as roots, so one entry enables both. The harness's own payload root is reached through the same key and the same convention: the `/opt/workflow/agent` entry contributes `/opt/workflow/agent/prompts/` and `/opt/workflow/agent/skills/`, so no `skills` or `prompts` list names a harness root. The gate derives those roots from the entries, and a module root that no entry enables is a finding.

The repository keeps the two kinds apart because a prompt root reads files into commands and a skill root reads directories holding `SKILL.md`. A module's `prompts/` folder ships whole. Working records live outside a module: the repository's run briefs and audits are at `.agents/`, beside the `.agents/skills/` cell reserved for a skill specific to one repository, and the dockerfiles name a module's payload folders rather than the module directory.

## A module's conventions

A module may declare the project conventions it needs. A **convention** is a structure over a subset of content - the task list, the work log, the decision records. Each convention is served by a project-owned **convention-skill** under `.agents/skills/`.

The workflow ships a **default convention-skill corpus** in the `initialize` skill's `assets/conventions/`, one directory per convention. A shipped skill is a **stub**: it states that a skill is expected, that what was found is a stub, and a few open questions offered without direction. It is a failure mode for the agent to reason over, not a default convention. `initialize` installs and updates the corpus into the project.

A workflow step hands off to a convention-skill. When the skill is absent the handoff fails and the agent recovers; the workflow imposes nothing and runs no gate over a project, whose hooks it does not control. The corpus lives under a skill's `assets/` directory, so it ships with the `skills/` payload folder and no new surface is declared. A convention may cover more than one structure; `work-log` carries the work-unit record and the exploration record.

## The layers

The two `AGENTS.md` files carry the same claim one level up. The provider layer, `src/reasoning/providers/pi/config/agent/AGENTS.md`, holds a `## Scope` table for the container paths it covers; the project layer, `AGENTS.md`, holds one for the working tree the session runs in. Each table names runtime paths and nothing else.

The two tables split the `session` rows between them, and every row belongs to exactly one layer. The split is checked in both directions.

## The gates

Two gates read the declaration, both through [`src/build/container-interface.mjs`](../../src/build/container-interface.mjs), which is its only reader.

[`scripts/check_container_layout.sh`](../../scripts/check_container_layout.sh) holds the manifest equal to what implements it: the provider dockerfiles' `COPY` and `ENV` lines, the entrypoint's provisioning template, the provider settings record, and each cell's folder set. It fails on a manifest row no line carries, a line no row carries, a declared folder set that differs from the one derived, an `/opt` runtime path that is not a root in the provider's settings record, a destination in the agent tree that no cell declares, a surface with no runtime path that names an image path, a surface with no provider that names one in its loader, a malformed row, two cells claiming one folder or one runtime path, a module root that no settings entry enables, and one name held by two roots under one key.

[`scripts/check_instruction_surfaces.sh`](../../scripts/check_instruction_surfaces.sh) holds the claims that live outside the manifest: the two `AGENTS.md` layer tables against the `session` rows, and the loop inventory against the policy's `scope`.

The gates are why a stale claim cannot survive. A `COPY` line added or removed fails the cell that described the old map, and a path that changes in the manifest and not in a layer table fails as a drift.
