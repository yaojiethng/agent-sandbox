---
date: 2026-11-05
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the prose-entrypoint judgement stops being a principle

## Objective

The judgement that a skill wrapping a mechanism is a prose entrypoint over a script stops occupying a slot in the principle corpus. The pattern that already carries it stays its one home, the duplicate in the mounted corpus is removed, and the criterion that keeps the next authoring judgement out of the corpus is stated where an author chooses a type.

## Scope

The M3.3.3 row **The prose-entrypoint principle is an authoring pattern**, the sibling of the row the previous iteration closed.

The row's filesystem half had already landed. The pattern was filed on 2026-10-22 under `skill-scaffolder/patterns/prose-entrypoint.md` (handover [`20261022-04`](20261022-04-workflow-file_the_prose_entrypoint_pattern.md)), and the scaffolder's consolidation into `instruction-authoring` carried it to `instruction-authoring/patterns/prose-entrypoint.md`, which is the home this row names. No row was closed when the consolidation landed, so the roadmap has carried a task whose move was done.

What remains is the duplicate and the record. `$AGENT_HOME/agent/skills/` is a bind mount from `${SANDBOX_DIR}/.pi/agent/skills` on the host (`src/reasoning/providers/pi/docker-compose.pi.yml`), so the installed copy is a file no repository commit owns and no seed writes: `git ls-files` names no copy of the principle. Removing it is a container-local act; the durable outcome is the record that says why, and the criterion that a later writer applies.

The operator widened the pattern this iteration, before the scope gate: its subject is the instruction artifact that wraps functionality -- a script, a library, a service -- and a prompt is as much an entrypoint as a skill. The landed pattern scoped itself to a skill in its opening, its table and its tests, so a prompt over a script had no pattern. The skill-or-prompt choice stays in `SKILL.md` step 2, which already decides it, and the pattern cites that decision rather than restating it.

The two copies had diverged in one cell before this iteration: the pattern reads "a run's values hidden inside the skill", the installed principle "a fixed run's values". The pattern is the survivor. Nothing is ported back from the principle, and the widening comes from the operator rather than from the retired copy.

Ruled out of scope, with the reason: the M3.3.6 rows, which this iteration does not touch; and any corpus-wide sweep for the same misfiling, which is the criterion's job at the moment a type is chosen rather than a pass over the corpus.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The retired principle is absent from the installed corpus | `test ! -e /home/agentuser/.pi/agent/skills/principle-prose-entrypoint-over-mechanism` exits 0 | Agent [x] |
| No file in the tree carries it live | `git ls-files \| grep -c 'principle-prose-entrypoint'` prints `0`, and `rg -n 'principle-prose-entrypoint' --glob '!devlog/**'` names only the ADR entry that records the retirement | Agent [x] |
| The pattern that carries the judgement resolves from the skill | `rg -c 'patterns/prose-entrypoint\.md' .agents/skills/instruction-authoring/SKILL.md` prints `2`, one a step-2 citation and one the carried-file row | Agent [x] |
| The criterion keeping an authoring judgement out of the corpus is stated once | `rg -n 'writing of an instruction' .agents/skills/instruction-authoring/SKILL.md` prints the step-2 clause, and no second file carries it | Agent [x] |
| The retirement and the criterion are recorded in the ADR | `rg -n 'prose-entrypoint' docs/adr/principle_skill_shape.md` prints the dated entry | Agent [x] |
| The clause a later entry reversed is marked where it stands | `rg -n 'reversed by' docs/adr/principle_skill_shape.md` names the 2026-11-05 entry's rejected alternative about scoping the handoff judgement | Agent [x] |
| The roadmap row is closed and names what had landed before this iteration | the row reads `- [x]` and names handover `20261105-04` and the pattern's landing | Agent [x] |
| The pattern's subject is the instruction that wraps functionality, not the skill | `rg -in 'a skill' .agents/skills/instruction-authoring/patterns/prose-entrypoint.md` prints only the sentence that sends the surface choice to step 2, and the table, the conditions and the test read for a prompt too | Agent [x] |
| The skill-or-prompt choice is cited, not restated | the pattern names the step that decides it, and `rg -n 'disable-model-invocation\|carry files beside\|one file the operator starts'` on the pattern prints nothing | Agent [x] |
| The criteria the pattern points at are unchanged by this iteration | `git diff <iteration-base> -- .agents/skills/instruction-authoring/SKILL.md` shows the added criterion clause and no change to the type criteria | Agent [x] |
| Every decision this iteration recorded is realized in the files | the `## Decisions` table read against the tree | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The pattern needs no rework | The row's move landed on 2026-10-22 and the scaffolder's consolidation carried it to the row's named home, so the filesystem half is done and the iteration's work is the duplicate and the record | the roadmap landing note, and the ADR entry |
| The installed copy is deleted, and the deletion is container-local | The corpus is a bind mount and no repository file carries the principle, so the deletion clears the environment the session reads and ships nothing | this handover, and the ADR entry's edge cases |
| The criterion is stated in `SKILL.md` step 2, beside the sentence it completes | Step 2 is the moment an author chooses a type, and the existing sentence states half of the discriminator; a second statement in `skill-conventions.md` would be a second home for one criterion | `.agents/skills/instruction-authoring/SKILL.md` |
| The pattern wins the diverged cell and nothing is ported back | The pattern's "a run's values" reads with "the pin stated at the call site", and the widening the pattern takes is the operator's, not the retired copy's | the ADR entry |
| The pattern's subject is the instruction artifact, and a prompt is an entrypoint as much as a skill | The judgement needs a caller and an invocation, and a prompt has both; scoping it to a skill left a prompt over a script with no pattern | `patterns/prose-entrypoint.md`, and the ADR entry |
| The skill-or-prompt choice is cited from step 2, not restated in the pattern | Step 2 already decides it by whether the artifact carries files beside its body, and a second statement of that criterion is the duplication this row retires | `patterns/prose-entrypoint.md` |
| The pattern keeps its name | `prose-entrypoint` names the mechanism, and the widening changes the subject rather than the mechanism, so renaming would repoint two citations, the row and the closed records for no gain | `patterns/prose-entrypoint.md` |
| The reverse-direction clause is annotated in place rather than rewritten | The ADR is dated entries; a later entry supersedes a clause of an earlier one, and the earlier entry keeps what it decided that day | `docs/adr/principle_skill_shape.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The 2026-11-05 entry on the organizational judgement keeps a rejected alternative reading "Scope the handoff principle to skill authoring ... it stays in the general corpus, widened rather than narrowed", and the entry above it lands that same judgement in the authoring sheet | defect, record | a live clause asserts the opposite of what the corpus holds, and a reader who opens the SSOT entry first is misled | this iteration, the ADR being in scope |
| The pattern and the installed principle had diverged in one cell before either was reviewed together | drift | two copies of one judgement disagreed and nothing reported it, which is the failure the pattern's own `## Why` predicts | this iteration, by deleting the copy; the ADR entry names it as the evidence |
| The pattern as it landed named a skill as its subject throughout, so a prompt that turns an intent into a call had no pattern to read, though the judgement holds for it unchanged | defect, text | a caller whose entrypoint is a prompt re-derived the judgement or restated the flags | this iteration, on the operator's ruling at the scope gate |
| The row's move landed three iterations before the row was closed: the pattern was filed on 2026-10-22 and the scaffolder's consolidation carried it home | record | the roadmap carried an open row whose filesystem half was done, so a later session would have repeated it | this iteration, in the landing note |

## Completed

| File | Action |
|---|---|
| [`.agents/skills/instruction-authoring/patterns/prose-entrypoint.md`](../../.agents/skills/instruction-authoring/patterns/prose-entrypoint.md) | rewritten: the subject is the instruction artifact, the skill-or-prompt choice is cited from step 2, the conditions are two tables with the referent in the first column, and the boundary and test are cut |
| [`.agents/skills/instruction-authoring/SKILL.md`](../../.agents/skills/instruction-authoring/SKILL.md) | step 2 gains the complement of its own criterion: a judgement about the writing of an instruction is a pattern in this skill |
| [`docs/adr/principle_skill_shape.md`](../../docs/adr/principle_skill_shape.md) | the dated entry for the retirement and the criterion, and the annotation on the clause the handoff entry reversed |
| [`devlog/roadmap.md`](../roadmap.md) | the row closes, naming what had landed before this iteration |
| `/home/agentuser/.pi/agent/skills/principle-prose-entrypoint-over-mechanism/` | deleted from the mounted corpus; no repository file carried it, so nothing ships |
| roadmap-maintenance check | the check the loop runs before the handover was run: `active-milestone` reads `M3.3.3 - The skill maintenance pipeline` at `in-progress`, and that sub-milestone still carries an open row, so the record matches the state the prior handover claims and the skill's full report was not reached |
