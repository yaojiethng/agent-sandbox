# Instruction Context Template

## What a context file is

An instruction folder holds the prompts or skills an agent loads. Each folder carries one file named `CONTEXT.md`, and that file describes the folder, not the files inside it.

A context file answers three questions about the folder:

1. **Loaded when** -- the condition under which the agent can load a file from this folder.
2. **Reachable** -- every path an agent working from this folder can read, with the condition attached to each.
3. **Not reachable** -- the paths a reader might expect and does not get.

A runtime path is the subject rather than a source folder, because two source folders can land on one. `src/reasoning/agent/prompts/` and `workflow/coding-agent/prompts/` both land on `/opt/workflow/agent/prompts/`, so one file covers both and names both. Two files would overwrite each other in the image.

The reachable set is written in full in every context file, because it is the same container in each case and a reader of one file should not need another. The rows marked `always` are identical in every file, and the gate fails when they drift apart.

## Provider-neutral and provider-specific

Four folders are provider-neutral: `src/reasoning/agent/prompts/`, `src/reasoning/agent/skills/`, `workflow/coding-agent/prompts/` and `workflow/coding-agent/skills/`. Their images all carry the same paths, so their context files may not name a provider, a provider home or a provider install path. A path that differs per provider is either given as `$AGENT_HOME`, which the container resolves for the running provider, or left out.

A provider's own folder, such as `src/reasoning/providers/pi/config/agent/prompts/`, may name that provider. Its rows are the only place a provider-specific path appears, and their condition carries the provider name.

## The five instruction runtime paths

| Runtime path | Source folders | File |
|---|---|---|
| `/opt/workflow/agent/prompts/` | `src/reasoning/agent/prompts/`, `workflow/coding-agent/prompts/` | `src/reasoning/agent/prompts/CONTEXT.md` |
| `/opt/workflow/agent/skills/` | `src/reasoning/agent/skills/` | `src/reasoning/agent/skills/CONTEXT.md` |
| `$AGENT_HOME/agent/prompts/` | `src/reasoning/providers/pi/config/agent/prompts/` | `src/reasoning/providers/pi/config/agent/prompts/CONTEXT.md` |
| `$AGENT_HOME/skills/` | `src/reasoning/providers/pi/config/agent/skills/` | `src/reasoning/providers/pi/config/agent/skills/CONTEXT.md` |
| none | `workflow/coding-agent/skills/` | `workflow/coding-agent/skills/CONTEXT.md` |

## Required shape

```markdown
# System Assumptions

<One sentence: what this folder holds and what loads it.>

## Runtime identity

| Field | Value |
|---|---|
| Source folders | `<every repository path landing on the runtime path, with trailing slashes>` |
| Runtime path | `<container path>`, `$AGENT_HOME/<path>`, or `none` |
| Loaded when | <the condition under which the agent can load a file here> |

## Reachable

| Path | Holds | Condition |
|---|---|---|
| `<absolute path, with trailing slash>` | <what is there> | always, or the condition |

## Not reachable

- <a path a reader might expect, and what holds it instead>

## Assumptions

- <what the folder takes for granted about the session>
```

## Field rules

| Field | Rule |
|---|---|
| Title | `# System Assumptions`, exactly. One per file. |
| Source folders | Every folder that lands on the runtime path, with trailing slashes, comma-separated in the order the provider dockerfile copies them. Includes the folder that holds the file. |
| Runtime path | One of three forms. An image path under `/opt/`, a provisioned path under `$AGENT_HOME`, or `none` for a folder no image copies. |
| Loaded when | The condition, not the mechanism: the settings root that lists the folder, or the reference that reads it. |
| Reachable | One row per path, absolute, with a trailing slash. `Condition` takes one of three forms, in the next table. The rows marked `always` are identical in every context file, and the gate fails when they drift apart. |
| Not reachable | One bullet per path. A relative link that cannot resolve is a `Not reachable` entry, and it names the folder the link starts from. |
| Assumptions | Session facts that no path row captures, such as what the operator does with the result. |

## Condition values

| Condition | Meaning | Example |
|---|---|---|
| `always` | every delivery carries the path | `/opt/sandbox/lib/` |
| `<provider> delivery` | only that provider's image carries the path; permitted only in that provider's own folder | `/opt/workflow/agent/config/` under `pi delivery` |
| a named state | the session is in that state | `the project carries the repository tree` |

`$AGENT_HOME/` is the resolution for a provider's own config home. The variable is set in every provider image, so a provider-neutral folder names the variable and not the value.

## The layers

The two `AGENTS.md` files carry the same claim one level up. The provider layer, `src/reasoning/providers/pi/config/agent/AGENTS.md`, holds a `## Scope` table for the container paths it covers; the project layer, `AGENTS.md`, holds one for the working tree the session runs in. Each table names runtime paths and nothing else.

The two tables are a view over the `## Reachable` rows above, not a second source. A path a layer names must be one of those rows or a path inside one, and every `always` row must be covered by exactly one layer.

## The gate

[`scripts/check_instruction_context.sh`](../../scripts/check_instruction_context.sh) reads the image manifest through [`scripts/lint/image-map.mjs`](../../scripts/lint/image-map.mjs) and the pi `settings.json`, and asserts each `CONTEXT.md` against them. It fails on a missing file, a missing heading, a runtime path the image does not produce, a `none` for a copied folder, a source folder the file leaves unlisted, a folder the image copies whose path carries no file, two files claiming one runtime path, a provider name in a provider-neutral file, and an `always` row that differs between files.

It checks the two layer tables in the same pass: a layer with no `## Scope` table, a row naming a path outside the `always` set, an `always` row no layer covers, and an `always` row two layers cover all fail.

The loop inventory is checked here too. `iteration_policy.md`'s frontmatter `scope` names the runbooks it governs; the project layer's `### Loop prompts` table is the inventory an agent reads. A prompt the policy names and the inventory omits fails, and so does an inventory row the policy does not govern.

The gate is why a stale claim cannot survive. A `COPY` line added or removed breaks the file that described the old map, and a container path that changes in one file and not the others fails as a drift.
