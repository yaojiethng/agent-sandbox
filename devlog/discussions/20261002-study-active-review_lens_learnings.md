# Study - What each review lens catches, and which of its instructions to keep

**Status:** active

## Status and lifetime

Active. This document exists to carry findings that are not yet in a policy or a convention. It is deleted when the two M3.2.2 rows it feeds land: the `/document` convergence row and the `documentation-pass.md` distillation row. Everything in `## Persist` moves into a named policy or convention before that happens. Everything in `## Discard` is deliberately dropped and needs no successor.

## The three lenses

The `/document` review campaign ran three independent lenses over one prompt file. Each was briefed with one lens and told explicitly not to report the other lenses' territory, so their blind spots did not overlap by construction.

| Lens | What it is | What it found | Where it is blind |
|---|---|---|---|
| A | poteto, compressibility. Delete-test every sentence. | 22 then 20 findings, almost all padding, restatement, term drift, and colon-as-connector | Reads the prompt as text. A link is sound if it points at a real section by the right name. |
| B | authoring conventions plus documentation policy. Rule compliance. | 7 then 10 findings, structural and policy-level | Compares prompt wording against policy wording. Never follows a link to see what the target actually contains. |
| C | `documentation-pass.md`, run as a diagnostic | 5 findings, all of them invisible to A and B | Text-internal checks only. Sees inconsistency and mis-filing, not whether the workflow the prompt drives matches the prompt. |

The campaign's central result is that A and B together would have declared the prompt converged with C's five defects standing. Both mark a clause sound on the strength of a resolvable link. Every one of C's findings is a link that resolves to the wrong thing, or a command that cannot discriminate the two states it is asked to tell apart.

## Persist

These are rules a lens found once and will find again. Each belongs in a named document, not in the prompt that happened to trip it.

| # | Rule | Target | Found by |
|---|---|---|---|
| 1 | An acceptance criterion's verification must produce different output in the two states it distinguishes. `head -<section-end-line> <path>` prints the same text whether the section exists or not, so it cannot carry a false-before, true-after criterion. | `prompt-authoring-conventions.md`, beside the no-magic-constants rule | C |
| 2 | A cited link must name the section that owns the rule, not a section that resembles it. Citing `## Principles` for a rule that lives in `### Acceptance-criteria invariants` is a broken link even though the file and the heading both exist. | `documentation_policy.md`, precise-link rule | B, C |
| 3 | When prose names a layer and the link points at a different layer, the link is wrong. "the provider-layer `AGENTS.md`" pointing at the project-level file passes every existence check. | `documentation_policy.md`, precise-link rule | C |
| 4 | A prompt must not contradict itself across its own steps. One branch ordering an improvised sweep that a later Non-goal forbids is invisible to any single-section review. | `prompt-authoring-conventions.md`, structure section | C |
| 5 | The standard a step applies must actually govern the document kind in scope. `documentation_policy.md` disclaims prompts and skills while also listing them in scope, so a step applying it to all five document kinds is wrong for two of them. | `prompt-authoring-conventions.md`, and the scope statement in `documentation_policy.md` | C |
| 6 | A universal precondition is not an acceptance criterion. Offering `bash scripts/lint.sh` as a criterion shape makes a gate that runs anyway into a per-unit pass condition. | `iteration_policy.md`, acceptance-criteria invariants | B |
| 7 | Do not write a value into a record field whose name another policy already owns. "Name the type in the handover" collides with the handover `**Type:**` field, which is the iteration type, and a literal reader overwrites it. | `prompt-authoring-conventions.md`, plus `handover_policy.md` cross-reference | B |
| 8 | One concept, one name in the document. `Exit condition` and `completion criterion` for the same thing; `standards check`, `quality pass`, and `standard that governs its type` for one other. | `documentation_policy.md`, term discipline | A |
| 9 | Never two names for one field, one step, or one concept across a prompt family. | `prompt-authoring-conventions.md` | A, B |

Rules 2 and 3 are one rule seen from two sides. Persist them as one addition to the precise-link rule rather than as two.

## Discard

These came out of the campaign and should not survive it.

| Rule not to persist | Why |
|---|---|
| "Delete every sentence that fails the delete-test." | Applied literally it deletes required content. Lens A proposed removing the frontmatter scope summary for repeating the Scope list, and the routing sentence naming `/iter` and `/wrapup`. Both are load-bearing. A lens whose remaining findings are deletions of required content has saturated and is no longer discriminating. |
| "Prefer the shorter sentence." | Restates the delete-test and inherits its failure mode. Length is not the property; redundancy is. |
| "A frontmatter description must not repeat the body's Scope." | The repetition is the point of a summary. Lens A flagged it as duplication; it is not. |
| "Any inline copy of a linked rule is a defect." | Correct only as an absolute, which the prompt violates harmlessly. The workable form is the fast-path rule already applied: an inline copy must name the policy that owns it. Persist that, not the absolute. |
| Any finding whose only justification is a reviewer style preference. | Eight of round 2's thirty findings were deferred on this basis, and the eight included several the campaign would otherwise have applied. |

## Process learnings

These are about running the campaign, not about the prompt. They belong in the agent-feedback record if they are generalised, and in the review prompts if they are given as procedure.

**A count is not convergence.** Lens B rose from 7 findings to 10 between rounds. The campaign did not converge, and a naive reading of "round 2 found fewer problems" would have called it done. Convergence is the count falling to zero, and the signal to watch is not the total but the shape of what remains.

**A lens that finds a defect is a lens that misleads whoever applies it.** Round 1 told an applier to replace a judgement-shaped criterion with a command-shaped one. The applier over-applied it and replaced an architecture criterion that `/iter` Step 5 marks mandatory, without naming the substitution. Round 2 caught it. This is the strongest argument for a second round: the applier trusts the finding, so the finding needs a second reader.

**Independence is cheap and buys more than depth would.** Two reviewers on separate branches with disjoint briefs cost one concurrent dispatch. They shared no blind spot, and C's five findings were structurally invisible to both rather than merely overlooked.

**The apply step needs its own authority to disagree.** The round-2 brief explicitly authorised leaving a finding unapplied, with a reason, and eight findings came back deferred. Without that licence an applier either obeys a bad instruction or silently skips it, and both are worse than a recorded disagreement.

**Verify the tree, never the report.** The round-1 applier reported 29 of 29 applied, and `git diff --stat HEAD` showed nothing, because it had committed. The tool reported success correctly; the check was wrong. `git diff HEAD` is empty after a commit. Reading `git log` is the reflex that catches it.

**A lens that cites a command has not run it.** C's best finding was one command. Every rule about verification commands in a prompt should be read as unverified until the command has been run against both states it claims to distinguish.

## Consequence for M3.2.2

`documentation-pass.md` cannot become the review method this campaign used lens C for until it gains the three things lens C had to improvise: a link-resolution step that follows every link and confirms the target section carries what the citing line claims, a cross-step consistency check within one document, and a repair to its last item, whose two example symbols are empty code spans and cannot be recognised when they appear. Rules 2, 3 and 4 above are the generalised form of the first two, and they are what the distilled procedure should encode rather than the checks themselves.
