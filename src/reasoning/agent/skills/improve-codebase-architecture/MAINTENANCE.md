# Maintenance record

## Source

Forked from [`mattpocock/skills`](https://github.com/mattpocock/skills), imported at commit `440577fe` ("add: useful skills from mattpocock"). The exact upstream revision is not recorded, because the import copied the file set without a tag. The Claude-only subagent calls in `SKILL.md` and `INTERFACE-DESIGN.md` are the evidence of the source; this fork replaces them.

## Adapted

**Kept.** The name, the glossary and its terms, the deepening process, the deletion test, and the parallel interface-design pattern.

**Rewritten.** `SKILL.md` step 1 told the reader to "use the Agent tool with `subagent_type=Explore`", an API pi does not have. It now dispatches a read-only subagent through the `dispatch` skill. `INTERFACE-DESIGN.md` step 2 spawned 3+ sub-agents with the Agent tool; it now dispatches them through the same skill, one dispatch per brief, still read-only, so the design work cannot edit the tree.

**Added.** This maintenance record.

**Dropped.** Nothing. The Claude-only API names are gone; the parallel design pattern and every sibling file remain.

## Name

`improve-codebase-architecture` stays. The name describes the act, not the provider, and the skill is still the one a reader reaches for when the work is architecture improvement.

**Install path.** The skill installs from `src/reasoning/agent/skills/improve-codebase-architecture/`; the config-home copy is seeded from this tree. A change to the install target needs this record and the install source changed together.
