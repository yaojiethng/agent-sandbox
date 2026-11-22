# Makefile Target Ownership

**Current:** 2026-11-22

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | One owner for the target set | The operator decides which make targets exist |
| R2 | One template | The per-project Makefile template is not forked |
| R3 | A new invocation is not a new target | A change that needs a command adds a script and states the command |
| R4 | The operator can still act | The rule binds the agent, not the operator |

## 2026-11-22 -- The Makefile target set is the operator's curated alias table

**Decision:** The root `Makefile` and `scripts/templates/Makefile.template` are the operator's curated alias table. An agent does not add, rename or remove a target, and does not add another Makefile template, unless the operator asks. A change that needs an invocation adds a script and states the command in the document that uses it, or asks the operator for the alias. The rule is stated in [`AGENTS.md`](../../AGENTS.md) under `## Constraints`.

**Evidence:** The Makefile and the CLI carry two invocation idioms, including 35 `$(if)` translators for one boolean convention, and every target adds a translation to keep in step; the M3.4.2 row `The Makefile and the CLI keep two invocation idioms` records that surface, and the T4 row `Evaluate whether make still earns its place` keeps the target set under question. The Makefile is also the operator's documented interface: [`tool_interface.md`](../reference/tool_interface.md) presents the make targets as the operator's command surface.

**Rejected alternatives:**

- *Let an agent add the target it needs.* Rejected on intent: the target set is a curated operator surface, not an implementation detail, and each addition deepens a translation surface the operator already owns.
- *Add a second Makefile template.* Rejected on intent: two templates fork the surface and its help and error text, and the per-project copy stops having one source.
- *Rely on operator review to reject a target.* Rejected on execution: review catches the addition after the surface has moved, and the template ships to every provisioned project.
- *Put the rule only in the git-discipline skill.* Rejected on intent: the rule governs the Makefile surface, not the commit history.

**Edge cases / drivers:**

- The operator adds, renames or removes a target; the rule binds the agent, not the operator.
- A bug fix to an existing target is allowed; it adds no target.
- The root `Makefile` and the template are both operator-owned; the template is the one that ships.
- A change that needs a command adds a script and states it in the document that uses it; the operator decides whether it also earns an alias.
