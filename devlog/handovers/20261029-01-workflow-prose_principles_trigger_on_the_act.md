---
date: 2026-10-29
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - the prose principles trigger on the act of writing

## Objective

Make the principles that govern a document being written fire while it is written, instead of only on a revision pass that no authoring path requires.

## Scope

The trigger surface of the description on every principle that governs a draft, the sentence that keeps a generation-governing trigger from drifting back to a property of finished text, and the read-back step in the two paths that produce prose. The brief was [`principle-trigger-handoff.md`](../../.agents/drafts/principle-trigger-handoff.md), retired with its row.

Out of scope, one sentence each with the reason: the corpus's rules, because the rules are right and their trigger was not; a gate, because the class is judgement and a keyword matcher would flag legitimate prose; the duplicate reference page, never committed and deleted.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A principle that governs a draft triggers on the act of writing | `grep '^description' src/reasoning/providers/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md` opens "Apply when writing or revising prose" | Agent [x] |
| The second one does too and keeps its leitwort | the same command over `communication-principle-cut-what-carries-nothing` opens on the act and carries `sediment` twice | Agent [x] |
| Every description that governs a draft names the act | `grep -l '^description: "Apply when writing or revising' src/reasoning/providers/pi/config/agent/skills/*/SKILL.md` prints 10, and the four that govern a reading are not among them | Agent [x] |
| The trigger shape is stated where descriptions are ruled | `prompt-authoring-conventions.md` `## The principle shape` carries the sentence, beside the parts table | Agent [x] |
| The documentation path reads its own draft back before it lands | `.agents/skills/project-documentation/SKILL.md` `## Drafting` names both judgements as a step, after the text exists | Agent [x] |
| The prompt path does the same and the two agree | `prompt-authoring-conventions.md` `## Compliance` names both, by the same two judgements | Agent [x] |
| Gates and suite | `bash scripts/lint.sh` clean across 15 gates; `bash scripts/run_tests.sh` 1349 passed across 98 files | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The sweep covers every description that governs a draft, ten of the fourteen communication principles | a rule that carriers break is a note, not a patch; the alternative left the corpus stating one trigger shape and using another | the ten `description` fields |
| A rule that governs a reading keeps a property trigger | `attach-as-you-read` fires on a sentence that has to be re-read, which is the reading's own finding; forcing it onto an act would cost the condition that discriminates the fault | `## The principle shape` |
| The rule lives in `## The principle shape`, not in an `AGENTS.md` layer | that section is where a principle skill is authored and it already rules on the description; the project layer's `## Instruction Surface` rules on the index's size, not on trigger shape, and the conventions document has no section a single sentence could join | `prompt-authoring-conventions.md` |
| The read-back is a step in both prose paths | documentation and prompts are the two places prose is authored here; a documentation-only step leaves the prompt path on the jurisdiction sentence that failed | `## Drafting` and `## Compliance` |
| The read-back states the two judgements rather than pointing at the corpus | selecting among fourteen is the step that failed; naming the two removes the choice | both paths |
| `greenfield.md` is left alone | it points at `../SKILL.md`, which now carries the step, so a second statement there would be a copy | unchanged file |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Whether the behavioural `principle-*` family takes the same treatment | nothing today: those govern decisions rather than prose, and their triggers name a situation already | sweep them, or leave them and let the rule govern new ones |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `prompt-authoring-conventions.md` still said the deleted `/document` stub defers here | docs | a carrier of the previous unit's deletion survived its sweep, and the file was opened in this unit for another reason | the clause deleted |
| The full suite failed once on `test_select_session_pagination_option_zero_persists`, then passed on rerun | test | the failure is unrelated to this diff, which touches no test and no line the test reads, and it passes in isolation on both trees | flagged here, unfiled; the operator decides whether it becomes a row |
| Ten descriptions named a property of finished text while the body under each carried a `**Fires on.**` part | workflow | the trigger existed and was unreachable, because selection reads the description alone | the ten rewrites |
| `check_document_shape.sh` reports its failure as `Permission denied` against a file that did not fail | scripts | observed live: a frontmatter error in a principle skill printed `.agents/skills/project-documentation/SKILL.md: Permission denied`, so the one line the reader gets names the wrong file | flagged here, unfiled; the same defect is named as the fourth consistency class's local instance on the roadmap |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md` | description triggers on writing or revising |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-cut-what-carries-nothing/SKILL.md` | the same, `sediment` kept in the list and the closing sentence |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-show-dont-describe/SKILL.md` | the same |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-keep-a-subject-near/SKILL.md` | the same, with `proximity` in the description |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-single-train-of-thought/SKILL.md` | the same |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-only-derive-what-you-own/SKILL.md` | the same |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-name-the-value-not-a-literal/SKILL.md` | the same |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-one-addressing-axis/SKILL.md` | the same |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-dont-forecast-undone-work/SKILL.md` | the same |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-hand-off-by-naming-the-boundary/SKILL.md` | the same |
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | `## The principle shape` states the trigger rule; `## Compliance` carries the read-back; the `/document` clause deleted |
| [`.agents/skills/project-documentation/SKILL.md`](../../.agents/skills/project-documentation/SKILL.md) | `## Drafting` replaces the jurisdiction sentence with the read-back step |
| `.agents/drafts/principle-trigger-handoff.md` | deleted with its row |
| [`devlog/roadmap.md`](../roadmap.md) | the row closes |
