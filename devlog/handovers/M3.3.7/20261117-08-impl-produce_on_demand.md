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

The M3.3.7 row, artifacts are produced before anything demands them and the corpus names only the deletion. This iteration resumes after two sidequests, [`20261117-09`](20261117-09-workflow-operator_authors_principles.md) and [`20261117-10`](20261117-10-workflow-acceptance_gate_stop.md), which changed the procedure this row runs under.

The work is one principle skill plus the edges it declares, produced through the sequence in [`principle-change.md`](../../../.agents/skills/instruction-authoring/runbooks/principle-change.md). The operator writes every part of the skill and the agent asks, assembles verbatim and checks. The four narrowing skills in the repo keep their bodies, because a BT/NT edge changes neither, and the operator rules the edge at the sequence's last question.

Out of scope: the two narrowing skills installed under `$AGENT_HOME`, `principle-guard-derived-state` and `communication-principle-cut-what-serves-nothing`. They are outside this tree, so the branch cannot carry their edge; the finding records it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every part of the skill is the operator's own wording, and the record carries each part with the question it answers. | Read the `## Decisions` table against the skill file: every clause traces to an answer, and no clause is the agent's. | Not yet. |
| The skill passes the corpus gate, and the corpus count rises by one. | `bash scripts/check_principle_frontmatter.sh` reports 27 principles and 0 findings. | Not yet. The gate reports 26 today. |
| The neighbours the operator rules are declared on both sides, so a reader of either side reaches the other. | `node scripts/principle_inventory.mjs` lists each ruled neighbour under the new name and the new name under each of them. | Not yet. |
| Every decision this iteration records is realized in the files. | Read each `## Decisions` row against the tree. | Not yet. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The iteration resumes at the runbook's question sequence, and every answer is the operator's. | The sidequests landed: the runbook now assigns each part to the operator and the assembly to the agent, and the agent adds no clause of its own. | `4bd26432`; this record. |
| The five content rulings and the quoted overlap case this record carried are withdrawn. | They were the agent's draft under the previous procedure, and the operator ruled the name, the neighbour set and the contents unsuitable. | This record; the row under `## Decisions pending`. |
| No ADR is opened before the answers arrive. | Whether the judgement outlives the iteration depends on what the operator writes, and a record of it now would answer a question nobody has asked. | This record. |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Question one of the sequence: what changes, and by which of the five intents? | The artefact, the name, the file set and every later question. | The five intents and the question each asks are in the reply, with the row's evidence. |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `principle-guard-derived-state` and `communication-principle-cut-what-serves-nothing` are narrowing skills of the judgement and sit under `$AGENT_HOME`, so the branch cannot declare the edge from either side. | boundary | Two edges of the family stay unrecorded in the tree, and a reader of either skill meets no pointer. | This record; a destination the operator picks, since a change to `$AGENT_HOME` is not a branch change. |
| The roadmap maintenance this iteration ran, and this handover, were swept into the sidequests' delivery commits `4bd26432` and `32709362` rather than awaiting this iteration's own commit. | git hygiene | The parent's write-back is already on the branch, so its pre-gate roadmap diff reads against `32709362` and carries nothing of the maintenance pass. | This record; the diff base named at the acceptance gate. |
| The roadmap's M3.3.7 section still speaks in the retired vocabulary and carries facts the tree falsified: ten rows said `card`, two carried census counts, one named the deleted `patterns/admission.md`, two sub-milestone criteria named the retired survey and map, and row 390 declared a dependency on a landed row. | drift | A reader of the task list met a term the registry no longer defines and links to files that no longer exist. | Applied in `4bd26432`, and recorded here. |
| The sub-milestone's closed rows carry expanded checklists and `Depends on` lines pointing at completed rows, which the survival table removes at compaction. | drift | The section reads as a change log rather than a task list. | `/milestone-close`, which owns sub-milestone compaction. |

| The sequence poses each part's question before any research exists, so the operator must first say what evidence to gather and then answer, two acts per part. The scaffold has to carry one research directive per part, so the brief is assembled before the question is posed and the answer is one line. | procedure | The question held in `## Decisions pending` is at the wrong granularity and stays unanswered until the directives land. | The sidequest [`20261117-11`](20261117-11-workflow-principle_discussion_scaffold.md), which rewrites the procedure before this row runs it. |

## Completed

None yet; the acceptance gate fills this table.
