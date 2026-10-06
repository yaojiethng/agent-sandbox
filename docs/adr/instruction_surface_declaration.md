# Instruction Surface Declaration

**Current:** 2026-10-05

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

**Edge cases / drivers:** The session rows are the container's environment rather than any surface's property, which is why a cell may claim none and why a project-scope surface no longer asserts a container layout it must not depend on. The `mount` layer stays out of the manifest: the compose files declare it host-side, and this container cannot read them. A provider's settings record is the truth for an `/opt` path being loadable, and only pi's is checked, because only pi declares its roots in a settings file; the other providers' loader claims remain prose.
