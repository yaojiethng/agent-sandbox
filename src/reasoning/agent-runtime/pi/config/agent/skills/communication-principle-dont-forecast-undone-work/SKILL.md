---
name: communication-principle-dont-forecast-undone-work
description: "Apply when writing or revising text: a sentence that describes work no task holds -- a plan for a later milestone, a TODO, a pre-announcement, or a promise in a record. A forecast belongs where a task holds the work, and a guess is written as a gap."
---

# Don't forecast undone work

A description of undone work is a forecast, and a forecast belongs only where a task holds the work.

**The pattern.**

| Instead of | Give |
|---|---|
| a plan for a later milestone, written into a record | the task that owns it, and a pointer from the record |
| a TODO in a reference document | a gap, or the task that owns the work |
| "we will soon support X" in a guide | nothing, until X is built |
| a promise in a handover about work a later milestone owns | the task, or the gap it rests on |

**Why.** Two readers of one document take two different dates from it. The forecast reads as a commitment, and no task row made it, so a reader plans around work that no row owns and that nobody has scheduled.

Nothing reports the error. The sentence is grammatical, and it names a real milestone.

**Where a forecast is allowed.** A sentence that describes built behaviour is not a forecast, even in future grammar: "the loader will retry three times". Neither is a hypothesis that names its condition: "if we chose co-location, the pointer would break".

| Where the document sits | What it may forecast |
|---|---|
| a task row | its own work |
| a sub-milestone section | the tasks inside it |
| a milestone section | its own sub-milestones |
| a milestone's acceptance criteria | the check that its close runs |
| a handover | nothing past its own commit, so it points at the task |
| a discussion page | its own question and its options |
| a reference document, a changelog entry | nothing, because they describe what is built or in force |

**Where another rule wins.** A guess about how built work will behave is not a description of undone work, so it is not a forecast. `principle-match-precision-to-stakes` owns the assumption and the gap, at `$AGENT_HOME/agent/skills/principle-match-precision-to-stakes/SKILL.md`, and the `testing` skill's test homes own the knowledge test for a seam that cannot be changed.

**The test.** Name the task that owns the work. Where no task holds it, the sentence is a gap or it belongs to a task, and it goes in one of those two places. Then name the section the sentence sits in: if the work belongs to a different milestone, the sentence points at the task instead of describing the work.
