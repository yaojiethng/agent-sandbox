# Maintenance record

## Source

Source: `mattpocock-skills`; see [`source-catalog.json`](../source-catalog.json).

## Adapted

**Kept.** The name, the glossary and its terms, the deepening process, the deletion test, and the parallel interface-design pattern.

**Rewritten.** `SKILL.md` step 1 told the reader to use the Agent tool with `subagent_type=Explore`, an API pi does not have. It now dispatches a read-only subagent through the `dispatch` skill. `INTERFACE-DESIGN.md` step 2 spawned 3+ sub-agents with the Agent tool; it now dispatches them through the same skill, one dispatch per brief, still read-only. The sibling files carry the repository-wide ASCII punctuation sweep.

**Added.** This maintenance record, and `disable-model-invocation: true` on 2026-10-29 so the operator invokes the skill deliberately.

**Dropped.** Nothing. The Claude-only API names are gone; the parallel design pattern and every sibling file remain.

## Name

`improve-codebase-architecture` stays. The name describes the act, not the provider, and the skill is still the one a reader reaches for when the work is architecture improvement.

**Install path.** The skill installs from `src/reasoning/agent/skills/improve-codebase-architecture/`; the config-home copy is seeded from this tree. A change to the install target needs this record and the install source changed together.
