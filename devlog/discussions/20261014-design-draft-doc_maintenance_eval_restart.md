# The documentation-maintenance eval restart

**Status:** draft

## Context

The M3.3.1 skill unit replaced the `documentation-pass.md` register with an executable procedure, the `doc-maintenance` skill, which reads a document set, checks each claim against the implementation rather than against another document, and reports. The unit's handover is `20261006-09`.

An eval round followed, to answer two questions at once: whether the boundary between a `/document` session and the `doc-maintenance` pass changes what an agent does at a documentation close, and whether the skill itself does. Two iterations ran, a four-run pilot and a twelve-run paired batch, and the round is archived outside the repository at `$HOME/workspace/output/evals/20261006-doc-maintenance-boundary/`.

Its result does not carry. Three reasons, each independent of the others.

**The harness was never frozen.** The playbook requires a contrast that must lose before a batch is read. The batch's third rule, that the type-compliance read of a changed document stays with the session that produced it, was satisfied by no configuration at all, including the control built to invert it. Both scored zero. A rule no configuration satisfies measures the model, and by the eval method's own rule it is replaced rather than re-run.

**The model changed.** The batch ran on `opencode/space-bunny-free`. That provider's free tier now refuses this client, and the free tier moved to `opencode-go/step-5-preview-free`. The hillclimb playbook states that batch-to-batch drift on identical text has exceeded the size of most single-edit wins, which is why a candidate is never compared against an earlier batch. A model change is larger than that drift.

**The subject moved.** The batch measured a candidate that was never landed: a paragraph offered for the skill's trigger table, plus two sentences for `document.md`. The tree now carries the skill as landed, and `document.md` without the sentences. A restart would measure a different artifact from the one the batch measured.

One result is worth keeping. The first rule, that the plan schedules the maintenance pass over a named scope, went from none of three runs without the skill to all three with it. That is a clean separation on a paired batch, and it is the strongest single reading the round produced.

The open part of the T1 row `Skill and prompt eval infrastructure` already reads "neither case separates its configurations yet". The spent round did not fix that, and the restart inherits it.

## Options Considered

**Option 1 - extend the spent round.** Re-run its case on the new model and compare. Rejected. The harness's third rule never separated, so the comparison would measure a rule that measures nothing, and the model change breaks the pairing anyway. A cross-batch figure would be a story rather than a measurement.

**Option 2 - restart the same subject.** Run the boundary question again with a rule that separates, and a candidate moved to where the close is planned, `iter.md` Step 7, rather than the skill's trigger table. Defensible, and it keeps the fixture and the case. Rejected as a first subject. The question is a documentation nicety: the deliverable is one sentence in a close plan, and no configuration ever produced it, which says the instruction surface does not reach that decision. Writing prose to move a sentence nobody wrote is a poor first hillclimb.

**Option 3 - restart on a subject the skill actually decides.** Measure whether the review finds a claim a shipped document gets wrong. Chosen.

## Decision

Take option 3. The restart measures the skill's own job rather than a boundary between two instructions.

**The case.** A fixture trimmed from an eval snapshot of the current tree, holding a shipped document set and the code that decides its claims. One claim is planted that the implementation contradicts, with the source that decides it in the fixture. The operator message is organic: check the documents against the system and write what you find to `report.md`. The deliverable is written to a path the run commits, so the per-run bundle and patch carry it, which fixes the spent round's empty patches.

**The configurations.** Three. `none`, where the module root is absent from the run's pi config, so the skill does not load. `skill`, where the run's pi config names the fixture's own module root as a package, so the skill loads as landed. `inverted`, the contrast that must lose, where the skill's Step 3 is rewritten to check each claim against the other documents rather than against the implementation.

**The rules, stated so grading is mechanical.** R1 the report names the planted document and the section that carries the claim. R2 the report names the deciding source and what that source shows. R3 the report does not report the planted claim as correct, and does not report a contradiction that no source supports.

**The tuple.** Correctness is the mean fraction of the three rules satisfied across runs. Consistency is the fraction of runs satisfying all three. The climb target is correctness, then consistency. The tie-break is the smaller instruction set.

**Sensitivity first.** No batch is read until `inverted` loses R1 and R2. If it does not, the case is wrong and is fixed before any candidate is measured.

**What carries over from the spent round.** The fixture recipe, a trimmed copy of the tree outside the repository. The configuration trick, one package root per configuration pointing at the fixture's own module root, which is how the skill becomes the single variable without touching the image. The blind grading protocol: sanitized labels, one pass over every plan, a quote per rule. The pilot's finding that an instruction telling a pass to exclude the changed document fights the skill's own Step 3.

**What does not carry over.** The batch numbers, the baseline label, and the candidate wording. The batch-1 paragraph survives in three transcripts and the batch-2 `iter.md` line survives nowhere.

**Cost.** Nine child runs at `opencode-go/step-5-preview-free`, three configurations at three runs each, plus one grader pass. The spent round cost sixteen runs and 119 seconds of wall clock on the free tier.

## Consequences

The harness needs one change before this case runs. `workflow/coding-agent/skills/eval/scripts/run_case.sh` is specialized to the commit-body subject: it copies two named files and measures a commit. Generalizing it to take a candidate tree, a package root override and a pluggable measure is the lever, and it is what makes the case reproducible from the repository rather than from a throwaway script. The spent round's driver lived in a temp directory and is gone.

The boundary paragraph stays unwritten, on the evidence that it moved no measured behaviour, and the spent round's archive stays as a spent round rather than as a baseline.

This document settles when the restart produces a separating case, or when the operator rules the restart not worth its cost. If the restart lands the harness generalization as an ADR-worthy interface, the decision record belongs in `docs/adr/`, and this design stays the exploration.
