# Review a skill

Open this when a skill has just been written, or when an existing skill or prompt is about to change. The review reads one instruction surface against the bars it was written to and returns a findings table; the caller applies what it accepts.

This runbook runs only where a workflow prescribes it, or where the operator asks for it. The scaffolder may offer a review of what it just wrote; it does not dispatch one on its own.

## Called from

- The scaffolding procedure, for the skill it just wrote.
- The operator, for any instruction surface.

No other workflow dispatches it. A prompt that would benefit from a review names that to the operator; it does not run one.

The subject is an instruction surface: a skill or a prompt that was created, folded into, or shortened. The scaffolder offers this for the skill it just wrote, and a runbook that moves or cuts a prompt names it to the operator.

## Steps

1. **Name the subject and its source.** Name the files under review. When content moved into them, name the document it came from and the commit that held it, so the reviewer can read it with `git show <parent>:<path>`. Done when both are named and `git status --porcelain` prints nothing.
2. **Dispatch the pair.** The workflow or the operator has already called this runbook; this step does not decide whether a review happens. Write the brief below to a file with `<subject>` and `<source>` substituted, then run it per the provider `AGENTS.md` `## Running Review Subagents`. Done when both reviewers returned a non-empty report.
3. **Read, verify, apply.** Check each finding against the tree before acting, and name the claims you refuted. Agreement between the pair is the signal; a disagreement is where to check hardest. Done when every finding is either accepted with its correction or refuted with a reason.
4. **Fix, do not file.** A finding that names a defect in the surface under review is fixed here, and one outside it is reported to the operator. Done when `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean.

## The brief

Substitute the subject and the source, then pass the text below unchanged.

> You are reviewing an instruction surface in `/home/agentuser/sandbox` (agent-sandbox). State the provider, model and thinking level in your report header.
>
> **Read-only.** Do not edit, do not commit, do not run the test suite. Report findings; the caller applies them.
>
> **The subject.** `<subject>`. **The source**, when content moved into it: `<source>`, which you read with `git show <parent>:<path>`, so you judge what moved and not only what landed.
>
> **The bars, read each before you judge.**
>
> - `docs/development/prompt-authoring-conventions.md`: the runbook, advisor and completion-criterion shape, and the rule that a borrowed rule names its source of truth.
> - `docs/development/instruction-surface-conventions.md`: what a convention-skill is, and how it differs from a procedure.
> - The `patterns/` files this skill indexes: the sibling split and the prose entrypoint.
> - `doc-maintenance`'s `## The diagnostic register`, which owns the document checks: a rule with two homes, a pointer that does not resolve to its owner, two terms for one thing, a structural defect. Apply it; do not restate it here.
>
> **The lenses, in priority order.**
>
> 1. **Rule loss.** When content moved into the subject, walk the source and confirm every rule, table row and qualifier landed somewhere in the subject. When the operator directed a reduction of a live surface, confirm the reduction took only what the direction names. Name anything that vanished, and say where it belonged. This is the highest-value check, and the one no gate can make.
> 2. **Length.** Give a per-file verdict, a target, and cuts quantified in lines and words, ordered by lines saved, with the text to delete or shrink and its replacement.
> 3. **Settled design.** The surface's structural decisions were settled before this review. Report a structural defect only where it costs a rule or a reader.
>
> **Rule preservation bounds every cut on a move.** When content is being retired or folded into the subject, every rule, table row and qualifier in the source must land somewhere, and any rule you could not shorten without losing it is reported, not cut. When the operator has directed a reduction of a live surface, the direction decides what may go: a reviewer flags a rule it believes the direction missed, but does not restore it as lost.
>
> **Label the evidence.** Mark each finding measured, inferred or guessed. A pointer you did not run is inferred, not measured.
>
> **Report shape.** Numbered findings by severity, then a keep list naming the passages whose removal would lose a rule an agent needs, then a per-file length verdict. For each finding give the file, the line, the exact text, the bar it breaks, the correction, and the lines it saves. Quote exact text. State plainly when a category is clean; do not pad.
