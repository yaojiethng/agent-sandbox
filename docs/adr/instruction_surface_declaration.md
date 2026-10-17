# Instruction Surface Declaration

**Current:** 2026-10-17

## 2026-10-17 -- A surface read from the project tree is declared and named by the provider's settings record

**Decision:** A cell's runtime path may sit inside a `session` row. That declares a surface the project tree carries: no image row sends it anywhere, and the provider named on the cell must name the path in its settings record's `prompts` key. The gate holds the two equal, and a cell the record does not name is a finding.

`.agents/prompts/` is the first such cell. The pi settings record reads `"prompts": ["/home/agentuser/sandbox/.agents/prompts"]`, so the repository's own prompt files are invocable commands in a session in this project.

**Rationale:** pi discovers `.agents/skills/` by walking from the working directory to the git root, and has no equivalent rule for prompts. The surface therefore needs both a declaration and a carrier, and the two must be checked against each other: without the carry the surface is declared and never loaded, and nothing reports the loss. The settings record is the carrier because pi skips a missing path in that key silently, and because the value is the project mount the `session` rows already declare, so the declaration stays the single source.

**Rejected alternatives:**

- *A relative `prompts` value in the settings record* -- a user setting's resource path resolves from the agent directory, so `.agents/prompts` resolves to `$AGENT_HOME/agent/.agents/prompts` and loads nothing. The route was tried and reverted twice, in `20261015-02`.
- *A `--prompt-template` flag on the provider's launch command* -- the path can then be relative to the working directory, but pi records an error diagnostic for the flag's path when it is absent (`resource-loader.js`: `Prompt template path does not exist`), and the interactive UI renders it as a prompt conflict at session start in every project without the folder. The flag also loads only when the session starts at the mount root.
- *A project `.pi/settings.json`* -- it requires un-ignoring `.pi/`, which is operator-owned state and never committed, and `20261015-02` rejected it.
- *A `.agents` directory as a pi package* -- a package root does contribute `prompts/` beside `skills/`, but the entry still has to name an absolute path from the agent directory, and it re-adds the skill root pi already discovers.
- *Shipping the folder into the image* -- the files are the repository's own, and an image copy would give every project's session commands written for this one.

**Edge cases / drivers:** The absolute value names the mount, which every provider image sets to `/home/agentuser/sandbox`; a project tree mounted elsewhere would need the value changed with the mount. `none` still means no runtime path at all; the project-tree form is for a surface the session loads, which `none` does not describe. A missing settings record is reported once, as a missing record, rather than also as a cell it does not name.

## 2026-10-16 -- A runtime's surface is generated from the declaration, never restated by hand

**Decision:** Each runtime's native surface is generated from the manifest by one reader, and the generated surface is a checked artifact. `src/build/opencode-config.mjs` is OpenCode's reader. It emits four keys: `instructions` carries the ambient `AGENTS.md` files, `skills.paths` carries the cells whose source folder is a skill root, `command` carries one entry per prompt file under the prompt cells, and `references` carries the ambient directories worth advertising. A cell tagged with a provider reaches that provider only, so a cell tagged `provider: pi` reaches pi and no other runtime.

The prompt argument placeholder is `$ARGUMENTS`. pi accepts `$@` and `$ARGUMENTS`, OpenCode accepts `$ARGUMENTS` only, and one form serves both runtimes from one file.

Three properties make the generated surface trustworthy. `OPENCODE_CONFIG` is the seam, and OpenCode loads it as one local-scope config among the scopes it already merges, so the generated file is an additional config rather than the whole one. OpenCode rejects an unknown top-level key and refuses to start on an invalid config, so the emitted file names `$schema` and a check validates the output. And the generator is the only writer for the keys it owns, so a surface added to the manifest cannot fail to travel without the check failing.

**Rationale:** A hand-authored surface restates the declaration, and the comparison between the two exists only because of the repetition. That is the failure this declaration was written to prevent, and it had already happened in the generated case: the reader was written, tested, and invoked by nothing, so the surfaces it derives reached no runtime and no check reported it. A generated surface cannot drift from the declaration, and a check that validates the output catches the case where it stops matching.

This also retires a claim in the section below. That section reads "only pi's record is checked, because only pi declares its roots in one; the other providers' loader claims remain prose." OpenCode's loader claim is no longer prose: it is generated and checked.

**Rejected alternatives:**

- *A hand-authored `opencode.json`, managed the way pi's seed config is* -- it writes the same roots a second time with no gate between the two, and the failure is silent: a surface added to the manifest would simply not reach OpenCode.
- *The prompt roots as `references` only* -- a reference offers an alias in `@` autocomplete and a described directory, which is discovery. It does not make a prompt invocable, and invocation is the parity pi's prompt root already provides. The prompt cells are emitted as commands, and `references` carries the directories that are discovered rather than invoked.
- *One `<name>.md` file per command in a command directory* -- the inline `command` key takes `description` and `template` directly, so the generator emits entries without writing a second tree of prompt files.
- *Rewrite `$@` to `$ARGUMENTS` in the generator* -- it leaves two spellings in the repository and one of them is only ever correct after a transform. Unifying the files is the smaller lasting change.

**Edge cases / drivers:** A `references` entry is advertised to the agent only when it carries a `description`, so a reference without one is an alias in autocomplete and nothing more. `hidden: true` keeps an entry out of autocomplete while leaving it reachable, which is the form for a directory the agent should read but the operator need not browse. A prompt file that uses a shell-style default such as `${@:-default}` has no OpenCode equivalent, and the tree carries none today; a future one would need the placeholder mapped per runtime rather than unified.

## 2026-10-05 -- The instruction surfaces are declared once, in the container interface manifest

**Decision:** The instruction surfaces are declared as data. `src/build/container-interface.json` carries two sections for them: `session`, the twelve paths a session reads whatever surface it is reading from, and `cells`, one row per instruction surface. A cell declares its source folders, its runtime path, its loader, and optionally the provider it belongs to, plus the reachable rows it adds to the session environment. A cell may add none.

The model is scope crossed with loader. The scope is the runtime path form. An `/opt/` path ships in every provider image and is loaded by the running provider's config listing it as a prompt or skill root. A `$AGENT_HOME/` path ships in one provider's image and is loaded by that provider from its config home. A `none` path ships nowhere, is loaded only by a reference that names it, and is read from the repository.

Three rules follow, and each is checked against the manifest rather than against prose. A cell's folder set is derived, not trusted: the `/opt` set is the `image` rows that land there, the `$AGENT_HOME` set is the provision template's source with the home prefix removed, and a `none` cell declares a folder no `COPY` line sends anywhere. Every destination in the agent tree is a cell or the provision template, so a `COPY` line into an instruction root with no declaration fails. A surface with no runtime path names no image path anywhere in its row, and a surface that belongs to no provider names no provider in its loader.

The per-folder `CONTEXT.md` files are retired. A surface is declared in the manifest, the model is stated here, and how to declare one is in [`instruction-surface-conventions.md`](../development/instruction-surface-conventions.md).

A check earns its place when the failure it catches is silent and arrives late. A record that describes a container layout which has changed fails that test: it is found months later, in a sweep, and it is the failure this declaration exists to prevent. An image path written into a surface that ships nowhere fails the opposite way: it breaks in front of a reader the first time that surface runs. So the declaration is checked and the content of a surface is not. The whitelist-and-blacklist scan over surface files stays unbuilt, on the outgoing-link and file-path gate row, until a consumer or a violation justifies its engine.

**Rationale:** Five `CONTEXT.md` files declared five runtime paths in 210 lines, and 59 of those lines were one twelve-row reachable set written out again per file. A gate compared the copies against each other, so the comparison existed only because of the repetition. Declaring the set once removes the repetition and the check together, and it makes a new surface one manifest row instead of a file in an exact shape -- which is what the fourth scope, the repository's own skills, otherwise costs.

The reading was already declared, in a different form. `src/build/docker-compose.yml` carries the `x-workspace` path table, which is the same statement as prose, so `src/build/` is the home this declaration belongs in rather than `scripts/lint/`, which holds rules.

The derivation also closed a defect the prose form could not. The pi skills row declared its runtime path as `$AGENT_HOME/skills/` while the parenthetical beside it read `/home/agentuser/.pi/agent/skills/`. The overlay confirms the parenthetical: the directory is `$AGENT_HOME/agent/skills/`. The old gate checked only that a copied parent existed, so a wrong suffix passed. Deriving the folder from the provision row makes the suffix part of the check.

**Rejected alternatives:**

- *Keep the per-folder files and their drift comparison* -- the repetition is the reason the comparison exists; removing one removes both, and five files must still be written for a fifth surface.
- *Derive the cell list from a hard-coded folder list in the gate* -- that is what the retired gate did, and it makes the declaration a second source rather than the only one.
- *Build the whitelist-and-blacklist scan over surface files now* -- intent failure. The path half is decidable but the failure is loud and immediate, and hand verification of the three candidate skills found no violation; the provider-marker half is an open set, so a blacklist buys a tripwire at the cost of an engine and a maintained list.

**Edge cases / drivers:** The session rows are the container's environment rather than any surface's property, which is why a cell may claim none and why a project-scope surface no longer asserts a container layout it must not depend on. No cell uses `none` today: the repository's own skills were the only occupant, and they moved into the module that owns them. The `mount` layer stays out of the manifest: the compose files declare it host-side, and this container cannot read them. A provider's settings record is the truth for an `/opt` path being loadable, and it enables a root either by naming it or by naming a package whose conventional subdirectory it is, which is how a module's payload is enabled by one entry. Only pi's record is checked, because only pi declares its roots in one; the other providers' loader claims remain prose.
