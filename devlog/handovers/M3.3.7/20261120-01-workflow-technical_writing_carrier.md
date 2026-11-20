---
date: 2026-11-20
milestone: M3.3.7 - The principle corpus admission
type: Workflow
status: Closed
---

# Handover - The carrier that holds the technical-writing rows

## Objective

Subsume the unique, applicable content of `technical-writing` into the principles that own it, in the source's own words, and delete the skill.

## Scope

One subject, six roadmap rows: the four restatements (`align-the-mental-model`, `single-train-of-thought`, `link-what-the-reader-can-open`, `one-addressing-axis`), the `vacuous` word-ban row and the five-ownerless-rules decision.

The skill ships nowhere in this repository; its only copy was the installed `$AGENT_HOME/agent/skills/technical-writing/SKILL.md`, and that directory is removed with the retired copies beside it. The judgements move into seven principles, each in the standard's own sentence with its locator. The form rules retire with the skill, which closes the five-ownerless-rules row: none earns a principle and none keeps a carrier.

The installed root's staleness is an `[O]` entry in `devlog/AGENT_FEEDBACK.md`, because what is wrong is that nothing checks or updates the directory, not that two files needed deleting. `communication-principle-attach-as-you-read` is filed as its own open row, since this iteration added four paragraphs to a body the operator already reads as too long.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `technical-writing` exists in neither root. | `test -e .agents/skills/instruction-authoring/references/technical-writing.md` and `test -e $AGENT_HOME/agent/skills/technical-writing` both fail. | Agent [x] |
| The installed root no longer carries the two retired principles. | `ls $AGENT_HOME/agent/skills \| grep -c 'cut-what-serves-nothing\|only-derive-what-you-own'` reads 0. | Agent [x] |
| Each moved rule reads at least 1 in its owner, in the source's own sentence. | one `grep -c` per rule; each quotes the source's wording. | Agent [x] |
| The citation record parses with its five fields, and the four Global English paragraphs name it. | `node -e 'JSON.parse(...)'` prints ok, and `grep -c global-english` in `attach-as-you-read` reads 1. | Agent [x] |
| The dangling owner is closed. | `grep -c "Make every count or tree claim true"` in `single-source-of-truth` reads 1. | Agent [x] |
| The corpus holds no claim on a rule another carries. | `node scripts/principle_inventory.mjs` reports `0 finding(s)`. | Agent [x] |
| The six rows close, the cleanup row is open, and the installed-root sub-row is gone from the roadmap. | `grep -n '^- \[ \].*technical-writing'` returns the voice row alone, `grep -c "cleanup pass"` reads 1, and `grep -c "The installed root carries"` reads 0. | Agent [x] |
| The staleness entry exists, is open, operator-raised, and names the check gap. | `grep -c "The installed skill root goes stale"` reads 1, and its block reads `state: open` and `[O]`. | Agent [x] |
| Every decision this iteration records is realized in the files. | read `## Decisions` against the diff. | Agent [x] |
| The tree passes its gates. | `bash scripts/lint.sh` clean, and `bash scripts/run_tests.sh` green. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The skill is deleted, not reduced to a reference. | The operator's round-1 ruling. A reference that restates a standard is a third carrier beside the corpus and the installed skill, which is the defect the iteration was opened to remove. | This record, and the roadmap rows. |
| A rule taken from a standard keeps the standard's sentence. | `communication-principle-rewrite-syntax-never-semantics`: the wording is the source's, and the first pass paraphrased it into a rewrite. Every moved rule now carries its source's words, with the locator where it has one. | The seven principle bodies. |
| The writer's aside is metadiscourse, not vacuity: "simply", "easy", "quickly". | The operator's ruling. The sentence judges the discourse rather than carrying a claim about the system, so the deletion test applies and the vacuity test does not. | `communication-principle-cut-metadiscourse`. |
| The installed root's staleness is an `[O]` feedback entry, and the files are removed to settle the immediate case. | The operator's ruling. The durable defect is the missing check, which is a feedback entry's subject rather than a roadmap row's. | `devlog/AGENT_FEEDBACK.md`, and the files removed. |
| `single-source-of-truth` takes the prose-value rule its neighbour already delegates to it. | `principle-justify-materialization-cost` names that owner for a value stated in prose, and the owner did not carry it. | The leaf, and the delegating sentence. |
| No ADR. | No interface, gate or contract changes. | This record. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The first pass paraphrased every moved rule, inventing frames ("the word grain", "the writer's aside", "the modifier lands") for sentences the standard already states. | Evidence | A paraphrase is a rewrite whose meaning can drift from the source, and the operator caught it at the pre-close gate. The rules now quote or transplant the source's sentence with its locator. | The seven principle bodies, rewritten. |
| `technical-writing` was an orphan installed skill: no `packages` entry in either `settings.json`, and no store edge pinning its text. | Record | Six open rows named a file the tree neither held nor could pin, so no gate could see it drift. | The deletion, and the feedback entry below. |
| The installed root loads two principles this repository retired, and nothing compares the directory against the payload. | Record | The running session read a superseded corpus, and `check_instruction_surfaces.sh` reads only `AGENTS.md`. | `devlog/AGENT_FEEDBACK.md`, `[O] 2026-11-20`. |
| `principle-justify-materialization-cost` delegates a value stated in prose to `principle-single-source-of-truth`, and that leaf carried no such rule. | Carrier | The delegation pointed at nothing, so the rule had no owner. | The rule added to the leaf. |
| `organization.md` carries the whole Diataxis per-mode discipline, and `technical-writing` carried a third copy. | Record | Three copies of one rule set. | The deletion removes the third. |
| The M3.3.6 row `The mode frame is a principle of its own` described a plan whose skill half had already landed at `20261116-17`, and named `forms.md`, which no longer exists. | Record | A reader took the frame for unbuilt work, and the row named a file the tree no longer holds. | The row was moved to M3.3.7 and rewritten to the removal it still owes. |
| `communication-principle-attach-as-you-read` has no leitwort, a title and description that do not signpost, and a body longer than its subject. | Record | The operator read it during this iteration and named the defect; the four paragraphs added here make the length worse before the cleanup lands. | A new open roadmap row. |
| Two acceptance criteria named a proxy a correct implementation fails: `grep "Pick the mode first"` matched a form-rule example, and a count of `technical-writing` cannot fall while the closed rows keep the name. | Record | The gate would have reported a correct tree red. | Both criteria, rewritten before the close. |
| The closed rows in this sub-milestone still carry their implementation narrative, which the roadmap maintenance pass reports as its 3.6 finding. | Record | A closed row's count goes stale at the next change. | `/milestone-close`'s compaction. |

## Completed

| File | One-line change summary |
|---|---|
| [`communication-principle-cut-metadiscourse/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-cut-metadiscourse/SKILL.md) | "Cut every word that does no work", and Google's "simply", "easy", "quickly" sentence with its following line. |
| [`communication-principle-attach-as-you-read/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-attach-as-you-read/SKILL.md) | The four Global English sentences with their worked pairs, and the provenance line naming both citation records. |
| [`communication-principle-link-what-the-reader-can-open/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-link-what-the-reader-can-open/SKILL.md) | Google's pointer-text sentences. |
| [`communication-principle-show-dont-describe/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-show-dont-describe/SKILL.md) | The real symbol, and the failing case in place of the general claim. |
| [`communication-principle-structure-instructions-imperatively/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-structure-instructions-imperatively/SKILL.md) | ASD-STE100 Rule 5.2 quoted with its locator. |
| [`communication-principle-keep-a-subject-near/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-keep-a-subject-near/SKILL.md) | Google's "Put the common case first. Exceptions after." |
| [`principle-single-source-of-truth/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/principle-single-source-of-truth/SKILL.md) | The commit-time count rule, closing the delegation from `justify-materialization-cost`. |
| [`.agents/registry/citations/global-english.json`](../../../.agents/registry/citations/global-english.json) | New: Kohl's guide, as the trace for the four sentences the installed skill carried. |
| [`.agents/registry/sources/pstack-skills.json`](../../../.agents/registry/sources/pstack-skills.json) | The Diataxis edge's note now records the skill's deletion rather than that the install keeps it whole. |
| [`.agents/skills/instruction-authoring/SKILL.md`](../../../.agents/skills/instruction-authoring/SKILL.md) | No row added; the planned reference never landed. |
| [`devlog/AGENT_FEEDBACK.md`](../../AGENT_FEEDBACK.md) | `[O] 2026-11-20`, the installed root goes stale and nothing checks or updates it. |
| [`devlog/roadmap.md`](../../roadmap.md) | Six rows close with their outcome, the `attach-as-you-read` cleanup is filed, and the mode-frame row moves here from M3.3.6 rewritten to what it still owes. |
| `$AGENT_HOME/agent/skills/` | `technical-writing`, `communication-principle-cut-what-serves-nothing` and `communication-principle-only-derive-what-you-own` removed. |
