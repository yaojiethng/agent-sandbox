---
date: 2026-10-22
milestone: M3.3 - Instruction Surface
type: Workflow
status: Closed
---

# Handover - The standard covers a reply, not only a document

## Objective

Make `communication-principle-write-for-the-reader` a general communication standard rather than a document rule, and leave it linked from one instruction layer.

## Scope

The skill and its installed copy, and one line of the project `AGENTS.md`. The provider layer needs no change: it already files the judgement under `## Communication Standards`, whose opening line is "General communication guidelines for all agent prose", and its bullet already reads "Write for the reader, not the session that produced it".

Three facts set the scope. The skill's opening sentence says "An artifact is written for its reader", which scopes the whole file to artifacts. The project layer restates the judgement under **Documents**, so a reader meets it as a document rule. And the rule is already correct for every class of text; the defect is the scope the reader is given.

Not in scope: the document-context citations in the `docs` convention, `.agents/skills/docs/SKILL.md`, and [`documentation_taxonomy.md`](../../docs/reference/documentation_taxonomy.md), which apply the judgement where it genuinely applies to documents; and [`prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md), which cites it as an example of the domain-prefixed name form.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The scope statement covers any text | the skill's first sentence reads "Every text is written for the reader who holds it" | Agent [x] |
| The reply is covered by the criterion, not by a case section | `grep -c "Where the reply"` on the skill returns 0, and the ruling is recorded under Decisions | Agent [x] |
| Nothing existing is lost | the six bolded paragraphs and both tables still stand | Agent [x] |
| The two copies are identical | `diff` on the repository path and the `$AGENT_HOME` path prints nothing | Agent [x] |
| The judgement is linked once | `grep -rn write-for-the-reader AGENTS.md src/reasoning/providers/pi/config/agent/AGENTS.md` returns the provider layer only | Agent [x] |
| Every gate passes | `bash scripts/lint.sh` prints `Lint: clean in 8s across 11 gates`; `bash scripts/run_tests.sh` prints `1287 passed, 0 failed` | Agent [x] |

## Decisions

The project layer drops its clause rather than rewording it. Two pointers to one judgement leave a reader no way to tell which layer owns it, and the layer that states the rule is the one that defines it.

The skill generalises by naming the classes of text, not by widening the rule. The rule already holds for a reply; the file never said so.

An enumeration of cases does not generalise a rule. The description listed six classes of text and still missed a reply, so the scope widened in the rule's own words -- "Every text" -- and no case section was added. A scope list is maintained by whoever notices a missing case; the criterion is maintained by nobody and stays true. The frontmatter description keeps its list because a routing agent reads that line before opening the file, and it now names a reply first.

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The two `AGENTS.md` layers have no test for which one owns a rule, so a rule can stand in both layers or in neither | gap | a reader cannot tell which layer is authoritative, and this edit repairs one instance of it | roadmap row under M3.3.1, filed in this iteration |
| Every skill's frontmatter description enumerates the cases it fires for, so the corpus repeats the maintenance tax this iteration removed from the body | gap | the words a routing agent reads are a scope list, and the next output class is missed by each file that did not name it | operator decision at the release gate: file a corpus-wide row, or record the convention as accepted |

## Completed

| File | Change |
|---|---|
| [`src/reasoning/providers/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md) | the scope sentence reads "Every text", `artifact` becomes `text` at three further points, and the description names a reply first |
| `$AGENT_HOME/agent/skills/communication-principle-write-for-the-reader/SKILL.md` | the same bytes |
| [`AGENTS.md`](../../AGENTS.md) | the **Documents** line drops its pointer to the judgement, and `Drafting rules` becomes `Drafting rule` |
| [`devlog/roadmap.md`](../roadmap.md) | the layer-ownership follow-on filed under M3.3.1 |
