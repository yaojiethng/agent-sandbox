---
date: 2026-10-27
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Documentation
status: Closed
---

# Handover - the growth rule, stated as the outcome it wants

## Objective

Close the half of the instruction-surface work a report cannot do: state the standing rule that keeps an instruction set lean, so that growth is a decision rather than a default.

## Scope

One paragraph in the provider layer's `## Write Discipline`, the roadmap row it resolves, and the installed copy of that layer. The report itself, `scripts/report_instruction_growth.sh` and its eight tests, landed in `20261027-01` and is unchanged here.

Out of scope: the sender of the rule. A rule can be stated and still be ignored, and measuring whether this one bites needs a later read of the growth report against a baseline, not another policy line.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The rule states the outcome, not the procedure | Two red pens. The first: prompt the What, not the How, which removed the sequence and the commit-body shape. The second: the operator's own three-line statement was shorter than the paragraph, so the rationale and the restatement of the instrument came out and 49 words became 23 | Agent [x] |
| The rule has a home that owns its subject | Provider layer `## Write Discipline`, which governs every edit to an instruction file. The row's original home, the `project-documentation` convention, now covers `docs/` only, so it would have been the same category error the narrowing removed | Agent [x] |
| The instrument is named rather than described | `scripts/report_instruction_growth.sh`, as a code span: the layer ships into an image and a link into the repository would not resolve there | Agent [x] |
| The repo source and the installed copy carry the same paragraph | both files read it at the same point in `## Write Discipline`, after the minimal-corrections paragraph | Agent [x] |
| The row records the correction | the roadmap row states the home change and the wording direction, and cites this record | Agent [x] |
| Gates and suite | `bash scripts/lint.sh` clean across 15 gates; `bash scripts/run_tests.sh` 1349 passed | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The rule is the outcome, not the edit procedure | A procedure tells an agent how to add a rule, which is the behaviour to remove. An outcome says what the surface should look like, and leaves the move to the editor | this record, and the paragraph |
| The home is the provider layer, not a convention | The rule binds every instruction file, and the convention corpus is scoped to one subject each. `## Write Discipline` already holds the two rules about writing to the artifact | this record |
| Placement is the end of the section | The three paragraphs above it govern a single edit: one iteration, one artifact, one correction. The growth rule governs the surface those edits accumulate into | the layer |
| The rule is two sentences | The operator's summary of what they wanted was three lines and said the same thing. An always-loaded rule is written at the length that changes the behaviour and no longer: the reason a line is expensive is the argument for the rule, not part of it | the layer, and this record |

## Decisions pending

None.

## Findings

- **The installed copy of the provider layer has diverged from the repository source by 168 diff lines, and it holds the lost iteration's text.** `$AGENT_HOME/agent/AGENTS.md` reads 105 lines against the source's 165, and carries `## The Container`, `### Two containers` and `## Subagents`, which are the subjects the rolled-back layer-ownership iteration wrote. The rule that the two copies stay identical is prose with no gate, so nothing reported it. The divergence is left in place here rather than resolved in passing: which copy wins is a recovery decision, and it belongs with the rebuild-or-abandon call on that iteration.
- **The roadmap row named a home that the unit before it had invalidated.** "It belongs in the `project-documentation` convention's drafting section" was written before that convention was narrowed to `docs/`, and the rows were not re-read against each other. The correction is one clause, but it was only findable by reading the destination.
- **A red pen narrowed the sentence by removing its mechanism.** The first draft told an agent to name the superseded line, change it in the same edit, and explain itself in the commit body. All three are ways of doing the thing the operator wants not done; the What replaces them with the state the surface should be in.
- **Filed to [AGENT_FEEDBACK](../AGENT_FEEDBACK.md) rather than fixed: the drafting agent cannot see the reader.** The second red pen was the operator's own three-line statement doing the work of the paragraph, and the first was a procedure where an outcome was wanted. Both failures were authored by the agent holding the argument, which is why the entry records a capability limit and files no mechanism: every attempt to encode awareness of the inherited argument adds a level read by the same agent holding the same argument.
- **The second red pen was the operator restating the rule in three lines.** The paragraph landed at 49 words and did not survive being compared with "the instruction set stays lean, growth is measured by the script, improve in place". What it carried that the short form did not was the reason (every line is paid every turn) and a restatement of the report's own columns. Both are the rule's argument, and an instruction artifact states the rule.

## Completed

- [x] The paragraph, in both copies of the provider layer.
- [x] The roadmap row closed, with its stated home corrected and the red pen recorded.
