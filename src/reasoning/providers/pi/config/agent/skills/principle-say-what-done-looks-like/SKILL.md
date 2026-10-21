---
name: principle-say-what-done-looks-like
description: State where the work stops and what shows it is done, before starting it, so a finish can be checked rather than claimed. Use when starting a task, a step, or a segment of work, and when work is about to be reported complete.
---

# Say what done looks like

Work with no stated finish cannot be declared done. It can only be abandoned or claimed.

**The pattern.** Before you start, state two things.

1. The inventory, which is what the work covers, and the bound, which is what it excludes. Give the reason for each.
2. The acceptance criteria, one per line, each naming its verification: the tool or the method, other than the agent, whose output shows that criterion is met.

Run every verification that can run now, and show the output. A criterion that would fail on correct work is a specification bug, so fix it before the work starts.

**Why.** An agent with no inventory cannot say what it has finished. An agent with no bound cannot separate scope creep from thoroughness. An agent with no external check cannot separate done from its own belief that it is done.

**The three kinds of criterion.**

- An instrument exists. Name it, and let its output be the criterion.
- The work builds the instrument. Name the cases it must decide: one input it rejects, taken from a real breach, and one it accepts, both run by an instrument that already exists. The chain ends at something the environment already runs.
- Nothing mechanical decides. The criterion is an artifact and a test a reader applies to it. A person may confirm by reading the artifact or the output. A person's judgement is never itself the criterion.

**What it does not cover.** Whether the criteria are the right ones for the purpose of the work. The person who set the work owns that decision. This rule states criteria rather than setting them.

**The test.** Point at the inventory, the bound and one criterion. Name the instrument that criterion uses. If the answer is the agent's own judgement, the work is not bounded yet.
