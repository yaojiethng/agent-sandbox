# Instruction Surface Conventions

## What a surface is

An instruction surface is a folder an agent loads prompts or skills from. The surfaces are declared as data in [`src/build/container-interface.json`](../../src/build/container-interface.json), in its `cells` section, and the schema behind them is in [`docs/adr/instruction_surface_declaration.md`](../adr/instruction_surface_declaration.md).

A cell answers three questions about a surface:

1. **What lands there** -- the source folders that land on the runtime path.
2. **Where it runs** -- the runtime path, a `session` path when the project tree carries it, or `none` when no image carries the folder.
3. **Loaded when** -- the condition under which the agent can load a file from it.

A runtime path is the subject rather than a source folder, because two source folders can land on one, and then one cell names both. What the gate refuses is two cells on one path, because they would overwrite each other in the image.

A module's payload does not merge into the harness roots: `workflow/<module>/prompts/` lands on `/opt/workflow/agent/modules/<module>/prompts/`, its own root. A merge loses which module a file came from, and it lets one module's file shadow another's with nothing reported. That shadowing is checked instead: no two roots under one settings key may hold a file, or a skill directory, of the same name.

## Two surfaces

There are two kinds of instruction text here, and they are read in two different conditions.

The **working surface** is the two `AGENTS.md` files. A session receives them before any work starts, with no history and no other file read. Every line is read cold, so a line earns its place by being usable on its own: a path, a rule, an obligation. A term that only makes sense to someone who already knows how this repository is put together -- the layer split, the manifest, a surface, a cell -- is a defect in that file, whatever the sentence means to its author.

The **maintenance surface** is this document and the other documents that describe how the instruction text is built and checked. A session reaches it by being sent here on a job about the surface, having read nothing else, so the terms are allowed and each is defined the first time it is used rather than assumed.

The test for a line is whether a session that has read only this file can act on it: a path and what it holds pass, and a statement about which layer owns the path fails.

The problem both surfaces are reduced for is stated in the operator's words at [`.agents/instruction-surface-framing.md`](../../.agents/instruction-surface-framing.md).

## The shape

```json
{
  "sources": ["workflow/coding-agent/prompts/"],
  "runtime_path": "/opt/workflow/agent/modules/coding-agent/prompts/",
  "loader": "the running provider's config enables the module's package directory, whose prompts folder contributes every Markdown file here as a command"
}
```

| Field | Rule |
|---|---|
| `sources` | Every folder that lands on the runtime path, trailing slash, in the order the provider dockerfile copies them. No folder appears in two cells. |
| `runtime_path` | `/opt/...`, `$AGENT_HOME/...`, a path inside a `session` row, or `none`. |
| `loader` | The condition, not the mechanism. A surface that belongs to no provider names no provider here. |
| `provider` | Optional. Present only when the surface belongs to one provider, and then only to a provider that carries a dockerfile. |
| no fifth field | A cell declares no reach. What a file may reference is decided by the path space its reader holds, which the `image`, `provision`, `mounts` and `session` sections declare once per root. A cell that carries any other key fails the gate, so a retired field cannot come back as data nothing reads. |

## The session rows

The `session` section holds the paths every surface is read alongside: the project tree, the workspace directories, the image's roots, and `$AGENT_HOME/`. They describe the environment rather than a surface, so a cell does not restate them.

`$AGENT_HOME/` is the resolution for a provider's own config home. The variable is set in every provider image, so a surface that belongs to no provider names the variable and not the value.

## Scope

A surface with a runtime path ships in an image, and its files are read by an agent running in a container. A surface whose runtime path is `none` ships nowhere: it travels with the project, is reached by a reference that names it, and is read from the repository. Such a surface names no image path and no provider, in its cell or in its files. It states the project's own structure and nothing outside it.

A surface whose runtime path sits inside a `session` row is read from the project tree the session mounts, and it is loaded: a path under the project tree names a folder the running session reads, so the surface is invocable rather than linked to. No image row sends it anywhere - the project is already where it is read - and a provider is named, because the loader is that provider's settings record.

Two surfaces declare one provider's config home: the home itself, which carries the agent `AGENTS.md` and the settings record, and the prompt and skill folders inside it.

### What a project receives, and what this repository holds

Reach is a property of the reader, not of the subject: this document describes what ships and is itself repository-only.

| Artifact | A provisioned project receives it | Where the fact is decided |
|---|---|---|
| a cell's files | yes, the image carries them | `src/build/container-interface.json` |
| the seeded convention stubs | yes, `initialize` copies them into `.agents/skills/` | `initialize`'s `assets/conventions/` |
| `.agents/prompts/`, `.agents/skills/` | no, they travel with this project | the project tree |
| `docs/`, `devlog/`, `.agents/registry/` | no | this repository |
| this document | no | here |

A shipped file names a repository-only document as a name, which the linking gate allows, and the reader in a provisioned project cannot open it. A shipped file whose procedure depends on one states the rule itself.

## A surface the project tree carries

`.agents/prompts/` is the repository's own prompt root, beside `.agents/skills/`, which pi discovers by walking from the working directory to the git root. No equivalent rule covers prompts, so the surface is declared and the provider's settings record names it:

```json
"prompts": ["/home/agentuser/sandbox/.agents/prompts"]
```

The value is the project mount, which the `session` rows already declare, so the record and the cell name one path and the gate holds them equal. It is absolute because a user setting's resource path resolves from the agent directory: the relative form `.agents/prompts` there resolves to `$AGENT_HOME/agent/.agents/prompts` and loads nothing.

A path the record names and the tree lacks is skipped silently (`collectFilesFromPaths` ignores a missing path), so a project without the folder costs nothing. That is the reason the record is the carrier rather than a launch flag: `--prompt-template` reports every project without the folder as a prompt conflict at session start. The flag also resolves from the working directory, so it loads only when the session starts at the mount root.

The settings key is the carrier, and the gate checks it: a project-tree cell whose path the provider's `prompts` key does not name is a finding, because the surface would be declared and never loaded, and nothing reports the loss.

## A module's payload

`workflow/<module>/` is a toggle unit. Its `prompts/` and `skills/` folders are its payload, and each ships to its own root under `/opt/workflow/agent/modules/<module>/`. A module is enabled by naming its directory as a package: pi's `settings.json` carries `/opt/workflow/agent/modules/coding-agent` in its `packages` key, and the package convention contributes that directory's `prompts` and `skills` subdirectories as roots, so one entry enables both.

The harness's own payload root is reached through the same key and the same convention: the `/opt/workflow/agent` entry contributes `/opt/workflow/agent/prompts/` and `/opt/workflow/agent/skills/`, so no `skills` or `prompts` list names a harness root. The gate derives those roots from the entries, and a module root that no entry enables is a finding.

The repository keeps the two kinds apart because a prompt root reads files into commands and a skill root reads directories holding `SKILL.md`. A module's `prompts/` folder ships whole. Working records live outside a module: the repository's run briefs and audits are at `.agents/`, and its two instruction folders are declared differently - `.agents/prompts/` is a cell the launch command carries, and `.agents/skills/` is discovered by pi from the working directory with no cell at all.

## A module's conventions

A module may declare the project conventions it needs. A **convention** is a structure over a subset of content - the task list, the work log, the decision records. Each convention is served by a project-owned **convention-skill** under `.agents/skills/`.

The workflow ships a **default convention-skill corpus** in the `initialize` skill's `assets/conventions/`, one directory per convention. A shipped skill is a **stub**: it states that a skill is expected, that what was found is a stub, and a few open questions offered without direction. It is a failure mode for the agent to reason over, not a default convention. `initialize` installs and updates the corpus into the project. A stated convention is the project's own, so the corpus does not carry one: this repository's `instruction-authoring` bar is stated here and is not seeded, and a project that wants one writes it.

A workflow step hands off to a convention-skill. When the skill is absent the handoff fails and the agent recovers; the workflow imposes nothing and runs no gate over a project, whose hooks it does not control. The corpus lives under a skill's `assets/` directory, so it ships with the `skills/` payload folder and no new surface is declared. A convention may cover more than one structure; `work-log` carries the work-unit record and the exploration record.

## The layers

The provider layer, `src/reasoning/providers/pi/config/agent/AGENTS.md`, holds a `## Scope` table of the resources the harness exposes and an index of the principle skills under `$AGENT_HOME/agent/skills/`. The project layer, `AGENTS.md`, holds a `## Scope` table of the working directories the session should use. Each table names runtime paths and nothing else.

The two tables split the `session` rows between them, and every row belongs to exactly one layer.

**What each layer owns.** The provider layer owns what is true of any project running in this container: the runtime, the mounts, the tool set, the dispatch mechanics, and the agent's own config home. The project layer owns what is true of one working tree: its records, its roadmap and conventions, its documents, and the code in it. The test for a section is whether its sentences would still be right for a different project running in the same container. Yes places it in the provider layer; no places it in the project's.

**What a layer may say about itself.** A layer names its paths in `## Scope` and stops there. The project layer also points here, because the session reading it may be about to edit it; the provider layer does not, because a project running on this image cannot edit it.

A rule about where sections belong is maintenance material and lives here, not in either layer. The reader of a layer is an agent doing the work, and the dividing test is whether the working agent can act on the sentence now, which a pointer passes and a filing rule fails. The rule's two reach points are a layer's pointer in `## Scope` and the check's failure message.

**Editing a layer.** A section added, renamed or moved takes its subject-table row in the same change, and the ruling is recorded on the iteration's handover. The provider layer's repo source and its installed copy are one file: edit the source and copy it to `$AGENT_HOME/agent/AGENTS.md`. Both layers pass the same gates as the rest of the tree.

**Standing in for the general provider layer.** A sentence true of every provider -- the sandbox boundary, no push, no secrets, the tool set -- has no provider-neutral always-loaded carrier: `src/reasoning/agent/` holds prompts and skills, and each provider seeds its own config home from its own template. Until that carrier exists, the pi provider layer stands in for the general provider layer, and such a sentence is filed there. Building the carrier is a filed roadmap row.

**Who reads a layer.** The reader of an `AGENTS.md` is the agent runtime, and the runtime is handed each section concatenated into its context window. A rule addressed to it therefore has to stand as a sentence on its own: a position in the document, a table's rows and the source's line breaks carry no meaning to that reader. The path tables in the two `## Scope` sections are not instructions; they serve the maintainer and `scripts/check_instruction_surfaces.sh`, which is why a rule whose only purpose is to keep a table well-formed belongs here rather than in a layer.

**The subject table.** One row per level-two section of either layer, naming the section and the layer that owns it. A section is filed by its subject, which is the noun its sentences are about rather than its heading.

| Subject | Section | Layer |
|---|---|---|
| this working tree | `Scope` | project |
| the product this repository builds | `System` | project |
| where work may be written | `Constraints` | project |
| how work is done on this repository | `Collaboration Protocol` | project |
| the instruction-surface budget | `Instruction Surface` | project |
| multi-file change audit | `Propagation Discipline` | project |
| the feedback record | `Feedback and Gotchas Record` | project |
| this repository's role table | `Model Recommendations` | project |
| output classes and their obligations | `Output Format` | project |
| an absent document | `Missing Documents` | project |
| the iteration | `Iteration Lifecycle` | project |
| the reading list a session opens with | `Iteration Start` | project |
| the container paths this layer covers | `Scope` | provider |
| the two containers and the tool set | `The Container` | provider |
| write rules | `Write Discipline` | provider |
| the prose principles | `Communication Standards` | provider |
| reading a tree before opening it | `Read Discipline` | provider |
| dispatching a subagent, and the review as its seat-count mode | `Subagents` | provider |
| the status a turn ends with | `Reporting` | provider |

The table is the judgement; it proves nothing about whether a ruling was right, which is what the ruling classes are for.

**Ruling classes.** Every section ends in exactly one, and a ruling is recorded on the iteration's handover.

| Ruling | Meaning |
|---|---|
| keep | the section is in its own layer and stays as written |
| move | the section belongs to the other layer; it moves whole |
| split | the section holds sentences for both layers; each sentence moves to its owner |
| merge | the section duplicates another section that already owns the subject, so the two become one |
| shrink | the section is in its own layer but carries text another file already states, so the duplicate goes and a pointer stays |

## Reading the surface from the tree

A fact held as data is read from the tree, not from prose here:

| Question | Command |
|---|---|
| which surfaces exist, and where each lands | `bash scripts/check_surface_table.sh` |
| which layer a skill resolves to, and how the loader orders them | `node scripts/skill_map.mjs` |
| what the seeded convention corpus holds | `ls workflow/coding-agent/skills/initialize/assets/conventions/` |
| whether every claim on this page still holds | `bash scripts/lint.sh` |

## The gates

Gates read the declaration through [`src/build/container-interface.mjs`](../../src/build/container-interface.mjs), which is its only reader. Each script's header states the rule it holds and the document that owns it; `bash scripts/lint.sh` runs them.

[`scripts/check_container_layout.sh`](../../scripts/check_container_layout.sh) holds the manifest equal to what implements it: the provider dockerfiles' lines, the entrypoint's template, the settings record and each cell's folder set, so a row no line carries, a line no row carries, a path outside the provider's roots and one name held by two roots under one key are each a finding.

[`scripts/check_instruction_surfaces.sh`](../../scripts/check_instruction_surfaces.sh) holds the two layers' `## Scope` tables against the `session` rows, the subject table against the layers' headings, and the loop inventory against the policy's `scope`. A section with no row, a row naming the layer the section is not in, and a row whose section no layer carries are each a finding.

[`scripts/check_surface_table.sh`](../../scripts/check_surface_table.sh) holds the mapping where a reference document states it: the table inside the marked block is the manifest's own output, so a hand edit inside it is a finding, and outside the block a table row naming a declared source and its destination, or a backticked repository path the tree does not hold, is a finding.

[`scripts/check_references.sh`](../../scripts/check_references.sh) holds two rules over the files the declaration names: a skill invocation must name a skill the tree provides, and an absolute mention inside a built zone must name a root the declaration builds. Both corpora are derived from the tree, so a project-scope skill counts as provided.

[`scripts/check_reach.sh`](../../scripts/check_reach.sh) holds the manifest's mount rows against the route table in [`documentation_taxonomy.md`](../reference/documentation_taxonomy.md) `## Reach`, reading both so neither copies the other's list. A folder the table calls repository-only fails when a manifest path reaches it.

[`scripts/lint/linking.mjs`](../../scripts/lint/linking.mjs), under the Markdown gate, resolves a link in the path space the citing file is read in: a shipped file's relative link is resolved against its image directory and mapped back to the source that populates it, an absolute one must be a declared image destination, and a link from a shipped file to a repository-only target fails, because that reader holds the image rather than the tree.
