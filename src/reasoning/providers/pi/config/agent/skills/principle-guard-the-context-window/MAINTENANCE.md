# Maintenance record

## Source

Forked from the `pont`/`pstack` agent skill set that the `poteto` skills are forked from, as `principle-guard-the-context-window`. The upstream text was installed by hand into the agent config home and carried no provenance, so the exact upstream revision is not recorded. What is known is the shape it arrived in and what this fork changed, recorded below.

`context.sh` beside `SKILL.md` has no upstream counterpart and was written here.

## Adapted

**Kept.** The name, the `**Why:**` sentence, and the shape of a short principle with a pattern list. The name is kept because the judgement holds for any agentic work rather than for one surface, so it takes the bare `principle-` form under the project's suggested skill-naming scheme, `[<domain>-]principle-<judgement>`.

**Rewritten.** Three clauses arrived that rebutted text the file no longer contained, addressed to whoever had made the edit rather than to a reader. The upstream text asserted "The context window is finite and non-renewable within a session", which is a capacity fact an agent cannot measure, and it instructed "set turn budgets, account for mechanism costs", which name no counter and no price. Both are gone. In their place is a rule that names the reading which settles the question, and a rule that makes a pass countable. The two bullets that upstream dropped, routing bulk to a subagent and keeping hot content inline, are restored, because both are executable and a skill that forbids nothing is not a guard.

**Added.** `context.sh`, so "measure the room" is a command rather than an intention. It reads the provider's own `usage.totalTokens` from `$PI_SESSION_FILE` and takes the denominator from the model catalog, so the number is measured rather than estimated.

**Dropped.** A stopgap note that stated the file would be overwritten by a package bump. It was false, because no package ships this skill, and it was addressed to an editor rather than to the agent reading the skill.

## Name

`principle-guard-the-context-window` stays. The judgement is that a claim about capacity must rest on a reading, which applies to implementation work as much as to prose, so the general `principle-` class scopes it correctly and a domain prefix would narrow it to one surface. A `communication-principle-` name was considered, and rejected on that ground.

**Install path.** The skill is installed to `$AGENT_HOME/skills/principle-guard-the-context-window/`, which is the path `SKILL.md` names for `context.sh`. A change to the install target needs the path in `SKILL.md` changed with it.
