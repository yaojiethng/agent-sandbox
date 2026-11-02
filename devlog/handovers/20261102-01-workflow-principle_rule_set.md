---
date: 2026-11-02
milestone: M3.3.3 - The skill maintenance pipeline
status: Active
type: Workflow
---

# Handover - a principle governs a rule set

## Objective

`principle-own-the-scope-you-declare` fires on a rule set, so the judgement that keeps an instruction surface extendable belongs to the corpus rather than being invented as an acceptance criterion inside the iteration that needs it.

## Scope

This iteration delivers one part of the roadmap row **Move the documentation-writing and skill-writing guidelines under `skill-scaffolder`**, which is its parent: the strengthening that row's move depends on.

**In scope.** One file, the `principle-own-the-scope-you-declare` skill, which gains the rule-granularity case in six places: the description, the sentence under the title, `**The pattern.**`, `**Fires on.**`, a named part, and `**The test.**`.

**Deferred, and why.** The authoring surface itself - the two carrier sheets, the retired document, the carriers that name it, and the citation family - is a second iteration. Operator direction on 2026-11-02 is that this work land as individual edits read one at a time, and the surface is not one edit. Its material is held uncommitted in the working tree and is not part of this commit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The principle fires on a rule set, in every place its shape has for a trigger | `grep -n 'rule' .agents/skills' | Agent [x]: six places, the description, the title sentence, the pattern, the fires-on line, the named part and the test |
| The rule case states what makes a set extendable, so a reader can act on it | read `**The pattern.**` and `**The test.**` in the file: a second rule on one situation is one rule, and a rule a reader must hold another rule to apply is coupled | Agent [x]: both state it, and both name the action |
| Each half keeps one home: that a rule changes the reader's next action is named as `communication-principle-cut-what-carries-nothing`'s test and not restated | `grep -n 'cut-what-carries-nothing' <file>` names it once, in the named part, and the file states no second utility test | Agent [x]: one mention, in `**What it does not cover.**` |
| The edited file still satisfies the corpus shape the gate holds | `bash scripts/check_document_shape.sh` | Agent [x]: clean across 172 instruction files and 28 principle skills |
| One commit carries the principle, this record and the roadmap row the steering added, and nothing from the deferred surface | `git show --stat HEAD` | Agent [x]: three files, and the surface is absent from it |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The rule case joins this principle rather than becoming a new one | The judgement is the same with a different object: a document declares a scope, a rule declares a situation. A new principle would be the twenty-ninth statement of what this one already states | the principle; this record |
| The rule-changes-an-action test stays with `cut-what-carries-nothing`, named and not restated | Two principles answering one test is the overlap the corpus avoids, and that principle's test already covers a rule | the principle's named part |
| The change lands as one file, and the rest waits for its own iteration | Operator direction, 2026-11-02: individual edits, the operator calls each one | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The operator directed on 2026-11-02 that this work land as individual commits, after one commit carried eight artifacts and the intermediate decisions could not be read | measured | the operator could not rule on decisions that were already landed, which is the collaboration the row asked for | this record: the remaining material is unstaged and waits for its own iteration |
| The change alters a shipped judgement's scope, and the seeded copy under `$AGENT_HOME/agent/skills/` keeps the older wording until the next container start | inferred | a session reading the seed sees the previous text, so the corpus reads inconsistently within one session | this record: the source is the image, and the seed is replaced at start |
| The `**The test.**` section now holds two tests, a document's and a rule set's, and the corpus shape allows one | measured | a shape reader counts a second paragraph where the gate expects a single test block | not this iteration: the gate is clean, and splitting the tests would make one judgement into two principles, which is the overlap this row avoids |

| The operator read the landed principle as long, and directed a roadmap task for a close read rather than a fix now | measured | the case sits in six places of one file, so a reader meets the same judgement six times | `devlog/roadmap.md`, the row **The rule-set case gets a close read** |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/principle-own-the-scope-you-declare/SKILL.md` | the rule-granularity case, in six places |
| `devlog/handovers/20261102-01-workflow-principle_rule_set.md` | this record |
| `devlog/roadmap.md` | the row that carries the close read of the rule-set case, with its two ends and a checkable end state |
