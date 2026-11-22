---
date: 2026-11-17
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
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
| Every part of the skill is the operator's own wording, and the record carries each part with the question it answers. | Read the `## Decisions` table against the skill file. | Accepted. The skill's prose is the operator's, and the agent supplied the friction research, the shape and the checks. |
| The skill passes the corpus gate, and the corpus count rises by one. | `bash scripts/check_principle_frontmatter.sh` reports 27 principles and 0 findings. | Accepted. `principle-frontmatter: 27 principle(s), 0 finding(s)`. |
| The neighbours the operator rules are declared on both sides, so a reader of either side reaches the other. | `node scripts/principle_inventory.mjs` lists each ruled neighbour under the new name and the new name under each of them. | Accepted. Two edges, symmetric, reported by the inventory. |
| Every decision this iteration records is realized in the files. | Read each `## Decisions` row against the tree. | Accepted. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The iteration resumes at the runbook's question sequence, and every answer is the operator's. | The sidequests landed: the runbook now assigns each part to the operator and the assembly to the agent, and the agent adds no clause of its own. | `4bd26432`; this record. |
| The judgement is named `principle-produce-just-in-time`. | The reference names the principle by that phrase, so the name and the citation match, and `single-source-of-truth` shows the corpus accepts a named principle as a skill name. `land` was rejected as the repo word for writing back into the tree. | Chat, 2026-11-18; this record. |
| The vocabulary is `unclaimed work` for the artifact, `clutter` for the effect, and `demand` for the field. | One word per job. `pending work` was rejected for its collision with "Decisions pending", and `deadweight` was tried as the descriptor and dropped. `demand` carries the act the test asks about, where `just-in-time` repeats the name and `on-demand` carries a delivery-model sense. | Chat, 2026-11-18; this record. |
| The skill is written now, in its incomplete state. | `approval-writes-the-artifact` holds that an approved artifact is written to its source of truth in the same unit of work, so the settled parts are in the tree and the unsettled ones wait. | `src/reasoning/agent-runtime/pi/config/agent/skills/principle-produce-just-in-time/SKILL.md`; this record. |
| The `**Why.**` is the operator text with the leitwort substituted. | The runbook keeps the Why claims the operator; the agent supplied the friction research and changed one word. | This record, quoted below. |
| The provenance is a citation of the reference principle, not the leitwort. | The leitwort names the cost and the citation carries the school, so `just-in-time` lives in the name and the citation rather than in the field. | This record. |
| The five content rulings and the quoted overlap case this record carried are withdrawn. | They were the agent's draft under the previous procedure, and the operator ruled the name, the neighbour set and the contents unsuitable. | This record; the row under `## Decisions pending`. |
| The intent reads "Produce only work demanded by the current scope." | The leitwort is `demand`, so the intent uses the same act as the field and the mechanism. | Chat, 2026-11-18; the skill's `metadata.intent`. |
| The judgement declares two neighbours, `communication-principle-dont-forecast-undone-work` and `principle-justify-materialization-cost`. | The scan offered four candidates and the operator ruled these two. `principle-remove-the-passthrough` and `communication-principle-cut-metadiscourse` are not declared. Both edges are symmetric and the inventory reports them. | Chat, 2026-11-18; the three skills' `metadata.neighbours`. |
| The guard is the scope, not a claim. | A claim is the wrong kind of statement to guard a task, and `state-intent-delegate-method` gives the rule: the pattern states the intent and leaves the method to the doer, so the pattern asks for scope fit and the reading is tested by restating it. | This record; the skill's pattern and test. |
| The gate is the scope and its intent, not a caller or a consumer. | Under TDD a fixture precedes its test and the test precedes the feature, and all three serve the iteration. So the test asks whether the work serves the intent and fits the scope, and a "who calls this" question would forbid the order the work needs. | Chat, 2026-11-18; the skill's test. |
| No ADR is opened before the answers arrive. | Whether the judgement outlives the iteration depends on what the operator writes, and a record of it now would answer a question nobody has asked. | This record. |

**The `**Why.**` text.**

> In a clean worktree every artifact has a reader, so a change reaches only what asked for it and the review reads only what was requested. Unclaimed work is deadweight, and clutter distracts from our purpose: files that neither the operator nor the agent use pull attention away from the work in hand, and every change pays a tax proportional to the surplus, since writing and reviewing spend processing to separate the change from the material that is not the change.

**The citation and its status.** Liker Principle 3, "Use 'pull' systems to avoid overproduction", glossed as "A pull system produces only the required material after a subsequent operation signals a need." The wording is corroborated by Wikipedia's summary of the fourteen principles and is unverified at source, since the book is not read here. `writing-for-agents` sets the precedent for a citation part by citing Sweller with journal and pages.

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

| The change runbook holds the file until the discussion ends, and a principle is better written as its decisions land. The operator asked for the incomplete principle in the tree, on `approval-writes-the-artifact`, so the runbook contradicts a live decision. | procedure | An approved part waits in the chat until the write, and a lost context loses it. | Deferred to the close, which raises a roadmap row for the runbook's write-back rule. The runbook stays as committed this iteration. |

## Completed

| File | One-line change summary |
|---|---|
| `src/reasoning/agent-runtime/pi/config/agent/skills/principle-produce-just-in-time/SKILL.md` | New: the judgement, its pattern, Why, test, boundary and provenance, with `demand` as the leitwort. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-dont-forecast-undone-work/SKILL.md` | Declares the new judgement as a neighbour. |
| `src/reasoning/agent-runtime/pi/config/agent/skills/principle-justify-materialization-cost/SKILL.md` | Declares the new judgement as a neighbour. |
| [`devlog/roadmap.md`](../../roadmap.md) | The row closes with its landed summary, and the runbook write-back rule is filed open. |
| `devlog/handovers/M3.3.7/20261117-08-impl-produce_on_demand.md` | This record. |
