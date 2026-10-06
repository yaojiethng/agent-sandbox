# Instruction Surface Conventions

## What a surface is

An instruction surface is a folder an agent loads prompts or skills from. The surfaces are declared as data in [`src/build/container-interface.json`](../../src/build/container-interface.json), in its `cells` section, and the model behind them is in [`docs/adr/instruction_surface_declaration.md`](../adr/instruction_surface_declaration.md).

A cell answers three questions about a surface:

1. **What lands there** -- the source folders that land on the runtime path.
2. **Where it runs** -- the runtime path, or `none` when no image carries the folder.
3. **Loaded when** -- the condition under which the agent can load a file from it.

A runtime path is the subject rather than a source folder, because two source folders can land on one. `src/reasoning/agent/prompts/` and `workflow/coding-agent/prompts/` both land on `/opt/workflow/agent/prompts/`, so one cell names both. Two cells on one path would overwrite each other in the image, and the gate fails on that.

## The shape

```json
{
  "sources": ["src/reasoning/agent/prompts/", "workflow/coding-agent/prompts/"],
  "runtime_path": "/opt/workflow/agent/prompts/",
  "loader": "the running provider's config lists this path as a prompt root",
  "reachable": [
    { "path": "workflow/coding-agent/skills/", "holds": "the coding-agent skills a prompt reads", "condition": "the reader has the repository tree" }
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

## The layers

The two `AGENTS.md` files carry the same claim one level up. The provider layer, `src/reasoning/providers/pi/config/agent/AGENTS.md`, holds a `## Scope` table for the container paths it covers; the project layer, `AGENTS.md`, holds one for the working tree the session runs in. Each table names runtime paths and nothing else.

The two tables split the `session` rows between them, and every row belongs to exactly one layer. The split is checked in both directions.

## The gates

Two gates read the declaration, both through [`src/build/container-interface.mjs`](../../src/build/container-interface.mjs), which is its only reader.

[`scripts/check_container_layout.sh`](../../scripts/check_container_layout.sh) holds the manifest equal to what implements it: the provider dockerfiles' `COPY` and `ENV` lines, the entrypoint's provisioning template, the provider settings record, and each cell's folder set. It fails on a manifest row no line carries, a line no row carries, a declared folder set that differs from the one derived, an `/opt` runtime path that is not a root in the provider's settings record, a destination in the agent tree that no cell declares, a surface with no runtime path that names an image path, a surface with no provider that names one in its loader, a malformed row, and two cells claiming one folder or one runtime path.

[`scripts/check_instruction_surfaces.sh`](../../scripts/check_instruction_surfaces.sh) holds the claims that live outside the manifest: the two `AGENTS.md` layer tables against the `session` rows, and the loop inventory against the policy's `scope`.

The gates are why a stale claim cannot survive. A `COPY` line added or removed fails the cell that described the old map, and a path that changes in the manifest and not in a layer table fails as a drift.
