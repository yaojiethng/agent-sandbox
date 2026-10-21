---
description: Dispatch the policy-slice writing advisor over the skills a policy-retirement slice touched. Use for a policy slice under Retire the policy form, when its carrier skills need a writing and structure review.
---

# Policy-slice document advisor

Dispatch two reviewer subagents with the brief below. The subject is fixed, the brief is fixed, and the only thing that varies is which slice is in flight.

## Before you dispatch

1. **Name the slice.** Which policy is retiring, and which files received its content.
2. **Snapshot first.** Commit or stash the working tree. The dispatch skill refuses a dirty tree, and for the same reason: a reviewer reading content you are still editing produces findings that cannot be attributed to a revision.
3. **Dispatch the pair.** Write the brief below to a file, then run the `pi-reviewer-dispatch` skill at `$AGENT_HOME/agent/skills/pi-reviewer-dispatch/SKILL.md`, passing that file and the scratch directory the provider `AGENTS.md` defines. The skill holds the reviewers, their full model ids, the thinking level and the preconditions; this prompt does not restate them. Read it and follow it.

## The brief to pass

Substitute the slice's file set for `<files>`, and pass the text below unchanged.

> You are the writing and structure advisor for a policy-retirement slice in `/home/agentuser/sandbox` (agent-sandbox). State the provider, model and thinking level in your report header.
>
> **Read-only.** Do not edit, do not commit, do not run the test suite. Report findings; the dispatcher applies them.
>
> **The subject.** `<files>`. These are the instruction surfaces that absorbed a retired `docs/policies/*_policy.md`. Read the retired policy with `git show <parent>:<policy path>` so you judge what moved, not only what landed.
>
> **The bars, read each before you judge.**
>
> - `docs/policies/documentation_policy.md`, the Communication Standards. The operative rule is the delete test. If a reader can delete a word, phrase or sentence without losing required meaning, delete it.
> - `docs/development/prompt-authoring-conventions.md`. The runbook, advisor, reference and completion-criterion bars, and the rule that a borrowed rule names its source of truth.
> - `docs/development/instruction-surface-conventions.md`. What a convention-skill is, and how it differs from a procedure.
> - `/home/agentuser/.pi/agent/skills/skill-scaffolder/SKILL.md`. The expected SKILL.md shape and frontmatter contract.
>
> **The lenses, in priority order.**
>
> 1. **Rule loss.** Walk every section of the retired policy and confirm each rule, table row and qualifier landed somewhere. Name anything that vanished. This is the highest-value check.
> 2. **Repeated content.** One rule with two homes, or the same rule stated twice in one file in different words. Name both halves and say which to keep.
> 3. **Misattributed content.** A sentence naming an owner that does not hold the rule, or pointing at a document that no longer exists, or citing a section that no longer exists. Run the pointer to its target.
> 4. **Inconsistent content.** Two files naming one concept differently, or one file using two terms for one thing. Name both forms and the file each sits in.
> 5. **Redundant or inconsistent structure.** A step with no completion criterion where its siblings have one; two heading styles inside one step; a subsection that exists to explain an absence; content of one kind, such as a rule, living in a document of another, such as a procedure or a prompt.
> 6. **Length.** Give a per-file length verdict, a target, and cuts quantified in lines and words. Order them by lines saved, with the text to delete or shrink and its replacement.
>
> **Rule preservation bounds every cut.** Losing a rule is a defect, not an edit. For each rule you could not shorten without losing it, say so and say why. A report that cuts aggressively and silently drops a rule fails the review.
>
> **Label the evidence.** Mark each finding measured, inferred, or guessed. A pointer you did not run is inferred, not measured. The label tells the dispatcher which claim to re-check first.
>
> **Report shape.** Numbered findings, ordered by severity, then a keep list naming the passages whose removal would lose a rule an agent needs, then a per-file length verdict. For each finding give the file, the line, the exact text, the bar it breaks, the correction, and the lines it saves. Quote exact text. State plainly when a category is clean; do not pad.
>
> **Take no position on architecture.** The slice's structural decisions were settled by the operator. Report a structural defect only where it costs a rule or a reader, or breaks the decision the slice recorded.

## After the review

- **Read both reports, then verify their claims.** Each report is evidence, not a conclusion. Check each finding against the tree before acting, and say which claims you refuted. A claim both advisors make independently is the one to act on first; a claim only one makes is the one to check hardest.
- **Fix, do not file.** A finding that names a defect in what the slice produced is fixed in the slice. Do not record it as a roadmap row.
- **Change nothing else.** A finding outside the slice's file set is reported to the operator, not fixed here.
- **Re-run the gates.** `bash scripts/lint.sh` and `bash scripts/run_tests.sh` end the pass.
