---
date: 2026-11-17
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Active
---

# Handover - The corpus states production before demand, and not only its deletion

## Objective

Add the judgement the corpus's three deletion rules share, so a reader meets the rule before producing an artifact rather than the correction after.

## Scope

The M3.3.7 row, artifacts are produced before anything demands them and the corpus names only the deletion. It is the change runbook's first application, and the runbook's case format governs how the change is judged.

The work is one principle skill plus the edges it declares. The four narrowing skills in the repo keep their bodies, because a BT/NT edge changes neither.

Out of scope: the two narrowing skills installed under `$AGENT_HOME`, `principle-guard-derived-state` and `communication-principle-cut-what-serves-nothing`. They are outside this tree, so the branch cannot carry their edge; the finding records it.

## Acceptance criteria

Not yet defined.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The intent is **Add**: no live artefact claims the judgement, so it lands as a new principle. | The overlap case is a design record produced after its decision landed, the kind iteration 07 deleted twice. Each of the four nearest rules does not fire on it: nothing derives the record, it forecasts no undone work, it is not a passthrough, and it serves its own mode. The new rule claims it alone. | This record; the case quoted below. |
| The edge is **BT/NT**, and the change takes *lex specialis*: it changes no narrowing body. | The four narrowing rules each fire after the artifact exists, at their own grain. The general rule states what they share and fires before. A case both claim, a passthrough with no consumer, is answered the same way by both, so the relation is narrowing rather than identity. | This record; the runbook's `## The edges the corpus records`. |
| No ADR for this change. | The skill's frontmatter is the decision's home, and the corpus's shape is already `principle_skill_shape.md`. A record for the decision itself would be an artifact produced before a demand, which is the rule being written. | This record. |
| No entry in `docs/reference/terminology.md`. | The leitwort is carried by the field that reads it. No other document in the tree uses the word, so a registry entry would be a second source with no reader. | This record. |
| The two `$AGENT_HOME` narrowing skills receive no edge. | The gate resolves a neighbour against the provider root, and `$AGENT_HOME` is outside this tree, so the branch cannot carry the change. | This record; the finding below. |

**The overlap case, quoted.** Iteration 07 deleted two concluded records, `20261116-report-concluded-principle_corpus_map.md` and `20261114-design-concluded-principle_corpus_admission.md`, because their conclusions had moved. Take the second: written on 2026-11-14 to settle the admission field, produced after the decision it recorded was already taken in conversation, and read by no task until it was deleted. `principle-justify-materialization-cost` does not fire, because nothing derives it. `communication-principle-dont-forecast-undone-work` does not fire, because it forecasts no undone work. `principle-remove-the-passthrough` does not fire, because it stands between no producer and consumer. `communication-principle-cut-metadiscourse` does not fire, because it serves its own mode. The change claims it: no demand held it, and it was produced anyway.

## Decisions pending

**Withdrawn 2026-11-17.** The operator writes every part of a principle, so these five are not the agent's to propose. The procedure that would ask them is the subject of the sidequest recorded in Findings.

| Question | What it blocks | Options |
|---|---|---|
| Does the principle land at all? | The whole iteration. | Admit it, or narrow the row back to a record of the diagnosis. |
| What is it named? | The skill's directory, its `name` and every edge that points at it. | `principle-produce-on-demand` (recommended: the name predicts the test), or `principle-just-in-time` (the operator's term for the system, and a cold reader needs the lean domain to predict the test). |
| Is `just-in-time` the leitwort rather than the name? | `metadata.leitwort`, and the description's wording. | Leitwort, with the name carrying the judgement; or the name carries the term and the leitwort stays empty. |
| Is the neighbour set four skills? | The four edges the change writes. | `communication-principle-cut-metadiscourse`, `communication-principle-dont-forecast-undone-work`, `principle-justify-materialization-cost`, `principle-remove-the-passthrough`; or fewer, and the rest named in prose. |
| Do the drafted `intent` and `mechanism` stand? | The frontmatter the gate reads. | `intent`: nothing is produced before a demand claims it, so the cost of an artifact falls on whoever asked for it. `mechanism`: pull -- name the demand before producing, and where nothing asks for the artifact, do not produce it. |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `principle-guard-derived-state` and `communication-principle-cut-what-serves-nothing` are narrowing skills of the new judgement and sit under `$AGENT_HOME`, so the branch cannot declare the edge from either side. | boundary | Two of the six edges the family wants stay unrecorded in the tree; a reader of either skill meets no pointer to the general rule. | This record; a destination the operator picks, since a change to `$AGENT_HOME` is not a branch change. |
| The roadmap's M3.3.7 section still speaks in the retired vocabulary and carries facts the tree falsifies: ten rows said `card`, two carried census counts, one named the deleted `patterns/admission.md`, two sub-milestone criteria named the retired survey and map, and row 390 still declared a dependency on a landed row. | drift | A reader of the task list meets a term the registry no longer defines and links to files that no longer exist. | Applied in this iteration's maintenance pass and recorded in the Completed table of this record. |

| The change runbook assigns the generation of a principle to the agent, and the operator is the author of every part of a skill. The reference states operator-led authorship for `intent` and `mechanism` only, and the runbook's first three steps generate the name, the nearest set and the case, with a ruling at the end. | contradiction | Every content row this iteration drafted is void, the five pending rulings are withdrawn, and the runbook is the artefact to change before the principle can be written. | The sidequest [20261117-09](20261117-09-workflow-operator_authors_principles.md), which rewrites the change procedure. |

## Completed

None yet; the release gate fills this table.
