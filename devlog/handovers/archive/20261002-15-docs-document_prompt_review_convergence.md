# Handover - The /document prompt review convergence

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Docs
**Status:** Closed

Convergence NOT reached. Three review rounds ran; two independent lenses, run twice, plus a third lens once. The findings from all three rounds are applied and the tree is green, but the two converging lenses have not stopped producing new material.

## Objective

Run independent reviewers against `workflow/coding-agent/prompts/document.md` under two lenses until they converge, evaluate a third lens, and record the result against M3.2.2.

## Method

| Round | Lens A (poteto, compressibility) | Lens B (authoring conventions plus documentation policy) | Applied |
|---|---|---|---|
| 1 | 22 findings | 7 findings | 29 of 29 |
| 2 | 20 findings | 10 findings | 22 of 30, 8 deferred as nitpick or judgement calls |
| c | -- | -- | 5 of 5, separate lens |

Every round ran as two independent `space-bunny-free` reviewers on separate branches, dispatched concurrently, briefed with one lens each and told explicitly not to report the other lens's territory.

## Convergence verdict

Not converged. Round 2 returned more findings than round 1 for lens B (7 then 10) and nearly as many for lens A (22 then 20). The count is not the whole signal, though, and the two lenses degraded differently.

Lens A saturated into nitpick by round 2. Its round-2 output proposed deleting the frontmatter scope summary because it repeats the Scope list, and deleting the routing sentence naming `/iter` and `/wrapup`. Both are load-bearing, and both were deferred. A lens whose remaining findings are deletions of required content has stopped discriminating.

Lens B did not saturate. Its round-2 findings were substantive: a lint-gate invocation offered as an acceptance-criterion shape when the lint gate is a universal precondition; an instruction to write the document type into the handover `**Type:**` field, which `handover_policy.md` reserves for the iteration type, so a literal reader overwrites it; a policy section cited that does not own the rule it was cited for; and three exit conditions ending on a judgement rather than a command.

## Regression found and fixed

Round 1 produced a real defect of its own. Reviewer B's round-1 finding told the applier to replace a judgement-shaped criterion with a command-shaped one. The applier over-applied it and replaced the architecture criterion that `/iter` Step 5 marks mandatory with its own substitute, without naming the substitution. Reviewer B caught this in round 2. This is the strongest single argument for running a second round rather than trusting the first: a lens that finds a defect is also a lens that misleads whoever applies it.

## Findings: the third lens

The third lens ran `documentation-pass.md` against the target and found five defects that the other two lenses could not see by construction. This is the effectiveness result worth recording.

| # | Defect | Why A and B are blind to it |
|---|---|---|
| 1 | The "a section the document gains" criterion is verified with `head`, which prints the same output whether the section exists or not, so the shape cannot produce the false-before / true-after delta Step 4 demands of every criterion | Both lenses read the command as a command. Neither executes it against both states. |
| 2 | The workflow-document branch points at a `## Compliance` section that belongs to `prompt-authoring-conventions.md` and governs the review pass, not the produced document | Both lenses check that a cited anchor exists. The anchor does exist, in the wrong document. |
| 3 | The "Any document" branch orders an improvised `documentation-pass.md` sweep that line 131 of the same prompt forbids and that the roadmap records as non-executable by an agent | Cross-step contradiction inside one prompt. Neither lens diffs a prompt against itself. |
| 4 | Subagent invocation routes to "the provider-layer `AGENTS.md`" while linking the project-level file | Both check the path resolves. It resolves; it is the wrong layer. |
| 5 | Step 5 applies `documentation_policy.md` Communication Standards to every produced document, but that policy disclaims prompts and skills, so for two of the five target kinds the governing standard does not apply | Requires reading the policy for what it excludes, not for what it requires. |

The structural reason all five survive: lens A reads the prompt as text and counts deletable words; lens B compares prompt wording against policy wording. Both mark a clause sound the moment it links a real section by the right name. The defect in all five cases is that the target behind the link does not contain what the citing line claims. A convergence campaign run on lenses A and B alone would have declared the prompt converged while these five defects stood.

## Verdict on documentation-pass.md

Usable as a checklist, not as a review method. To serve as the latter it needs three additions: a resolution step that follows every link and confirms the target section exists and carries what the citing line claims; a cross-step consistency check within one document; and a repair to its last item, whose two example symbols are empty code spans and cannot be recognised when they appear in a document.

## Deferred

- Convergence. A round 3 is required before the campaign can close. The evidence to bring is lens B's count falling, not lens A's.
- The distillation of `documentation-pass.md` into a procedure, which three separate things now demand and none of which can be satisfied until the register is executable by an agent.

## Files

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/document.md` | three rounds of findings applied |
| `devlog/handovers/archive/20261002-15-docs-document_prompt_review_convergence.md` | this handover |
