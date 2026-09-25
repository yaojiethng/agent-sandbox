# Test-Suite / Source Read-Through - Run (Main-Agent Template)

## Purpose

Read the production tree one file at a time, pair each file with the tests that claim to cover it, and measure -- not reason about -- whether those tests pin the behaviour they name. The pass produces two outputs with different lifetimes: a per-file work product, and a durable findings register. The register is the deliverable; the per-file work product is the evidence that supports it; the chat presentation is a digest of the work product, not the deliverable.

This pass exists because a whole-tree read-through sees what a diff-scoped review and a test-only audit structurally cannot see. A diff review reads only the change under review, so a defect that landed earlier is outside its range. A test-only audit reads the test files without the production file each test claims to cover, so it judges an assertion by appearance rather than by measured behaviour. The read-through pairs the two subjects under one unit, mutates the production behaviour, and reads which unit turns red. Use it as a periodic sweep, never as a per-delivery gate. The review passes stay; they are cheaper and they catch a regression in the change that introduces it.

## Preconditions

1. **Operator release of scope.** The pass is a funded work item, not an iteration. Confirm the file list, the exclusions, and the register location with the operator before producing any output. Treat the tooling that validates the tree (the test runner, the lint umbrella, and the `check_*.sh` gates) as in scope: it is the instrument that validates every other claim, so its defects are the highest-yield findings.
2. **Committed tree, frozen per batch.** Start from a committed state. Each worker copies a read-only archive of that state (`git archive`) rather than reading a live shared tree, so a concurrent edit cannot race the read.
3. **One suite at a time.** Mutation runs parallelise; the test suite does not. Serialize every suite invocation across workers with a mutex or a staggered start. Parallel suites corrupt the load baseline and turn a healthy gate into a flake.
4. **Vocabulary fixed.** The sectors, the dispositions, the bite verdicts, and the per-file deliverable shape are fixed by this brief. Do not renegotiate format during collection.

## Triggers

Run the pass on one of three triggers, in this order of expected use:

1. **The start of a refactor or rewrite.** The pass supplies the defect inventory, the duplication inventory, and the cross-file recurrence map that scope the rewrite.
2. **A capability branch's close, before its invariants settle into an ADR.** The pass reads the branch while its contract is still soft, so an unpinned or wrongly pinned invariant surfaces before it hardens into an accepted decision.
3. **A milestone or calendar cadence when neither applies.** Run one whole-tree pass per milestone so a defect that no diff review will ever see does not accumulate indefinitely.

Do not run the pass on a single-iteration diff. That is the review pass's job.

## Unit of work

The unit is one production file plus its covering test file or files. A tightly coupled group -- a library and its orchestrator, a family of leaves -- is one unit when the seams between them are the finding rather than any single file's content.

Every unit ends with all five artifacts:

1. **Annotated source.** The production file in labelled chunks, each chunk followed by what it does. Call out dead code, redundant guards, and behavioural consequences.
2. **A units table with a bite column.** One row per `test_*` unit.
3. **A bites table.** One row per mutation, with the units that failed and the reading.
4. **The BDD write-back into the test file.** A comment block above each unit.
5. **Findings rows.** One row per finding, in the register's column shape.

Work the unit in a fixed sequence: present the annotated source; present every unit as Given / When / Then plus a one-line statement of what it is supposed to test; run the bite checks; write the BDD block back into the test file; record the units, the bites, and the findings in the register.

Every harness, bash, or methodology lesson the pass raises goes into `devlog/AGENT_FEEDBACK.md` in that file's own format. Grep the file for an existing entry on the topic first. Record a recurrence on that entry (re-open it and note the prior fix in `legacy:`) rather than as a new entry. A lesson that lives only in chat, or only in a progress bullet, is not kept.

## Per-unit frame

State the file's contract in one line before any code: what it owns, what it refuses, and what it leaves behind. That line is what a reader retains; the annotated source is reference material.

Frame each unit with four elements:

- **Property asserted.** What the unit claims to pin.
- **Why it matters.** The consequence of the behaviour changing.
- **Setup and trigger.** How the unit reaches the property.
- **Bite verdict.** The measured outcome of the mutation, or the reason no mutation was run.

One line per seam, stating what crosses it, is worth more to the reader than the file's syntax. Lead the chat presentation with the contract, then the seam, then the finding, then only the minimal code under discussion. The full annotated source belongs in the persisted work product, which a reader can open when a specific claim matters.

## Bite requirement

Every unit that claims to pin a behaviour gets at least one mutation of that behaviour. A mutation edits the production file, runs the full suite, and names the units that turn red.

- **Proven** requires a named failing test file and a re-run to exclude the liveness gate. A single non-zero suite exit is not proof: a flaky gate can abort the suite for a reason unrelated to the mutation.
- **A surviving mutation is a coverage finding, not a pass.** Record it as a finding row; do not quietly accept it.
- **A mutation that cannot change behaviour is not a mutation.** Replace it with one that can.
- **Back up the subject before the mutation and byte-compare the restored file after it.** A mutation that is not restored contaminates every later unit.
- **Run one test suite at a time.** Two suites in flight make every baseline unsafe.

### Trap families

Three families produce a false verdict. Treat each as an explicit warning.

**(a) The no-op condition.** Appending `&& false` to an `[[ ]]` expression, or testing `-n /dev/null`, is not a mutation: the second operand is a non-empty string, the condition stays true, and the exit status does not change. Disable a guard with `if false; then` instead, and confirm the mutant file differs from its backup before the suite runs.

**(b) The silent perl interpolation.** In a perl substitution, `\Q...\E` does not stop `$VAR` interpolation, and it does stop `\n` from being a newline, so a replacement can match nothing while looking correct. Pass literals through the environment rather than interpolating them into the script text.

**(c) The killed-but-not-reaped process.** A test process that is killed but not reaped reports a false failure. Reap the child or confirm the process tree is empty before reading the verdict.

The mandatory controls that close this class are the byte-comparison of the mutant against its backup before the run and after the restore, the named failing unit, and the re-run.

## Output contract

The register is the durable output. It is a table whose columns are `#`, `Finding`, `File`, `Class`, and `Disposition`, with the bite evidence stated inside the finding text (a proven claim names its failing unit; a survived claim says so). Triage adds `Sector` and `Action` in a second table keyed by the same row number.

The per-file deliverable is the work product: the annotated source, the units table, the bites table, the BDD blocks, and the findings rows. It is machine-checkable and it is what the register is built from.

The chat presentation is a digest: the contract, the seam, the bite verdicts, and the finding titles. Do not treat a chat turn as the deliverable, and do not let a claim live only in chat.

Write the BDD block back above each `test_*` function in the test file:

```bash
# Given: <the precondition>
# When:  <the action>
# Then:  <the observable outcome>
# Asserts: <what the unit is supposed to test>
```

A rename alone is not a fix for a weak unit. Rewrite the unit to assert the intent its name claims.

## The register

### Bite identifiers

Name a bite `bite <row>.<n>`, derived from the finding row it supports, where `<n>` indexes the mutations run for that row. A bite is never named from an independent letter series: a per-pass letter collides across passes, cannot be resolved without the pass context, and reads as a semantic class when it is only a tag.

If a bite must be named before its row exists, use `<passtag>.<n>` and register the tag in the register's Format section in the same pass. Resolve every provisional name to a row number before the pass closes.

### Finding numbering

A finding row is a stable identifier and is never renumbered once another document cites it. Before assigning a new number, search the register for the finding itself, not for its class. When a finding recurs, extend its canonical row with the new evidence instead of adding a number. A duplicate row costs a duplicate disposition and a second fix in the plan.

### Register integrity

Keep the findings table contiguous: no blank line and no prose inside a table. Run a scripted integrity check after every batch, not at the close. The check confirms that every row number appears exactly once, that the numbers ascend in the table's order, and that every provisional key has been mapped to a row number. Split a sector into its own file once it passes about one hundred rows.

## Glossary

| Term | Meaning |
|---|---|
| bite | A mutation of the production file, run against the full suite, used to test whether a named unit's claim is real. |
| proven | A mutation was run and the named unit failed. The same observation as a pinned behaviour, stated from the mutation's side. |
| survived | A mutation was run and no unit failed. This is a coverage finding. |
| read-assessed | No mutation was run and the claim was judged from source. State why. |
| probe-verified | No unit exists for the behaviour, so it was observed directly in a throwaway harness. The behaviour is documented but unguarded, and the observation is itself a coverage finding. |
| pinned | A behaviour is pinned when a unit fails if that behaviour is changed. Pinning an intended contract is a regression guard; pinning an accident forces a later correct fix to break the test first. Pinning is neither good nor bad by itself. |
| unpinned | The state behind a survived mutation: no unit fails when the behaviour changes. |
| vacuous | A unit exercises a path without pinning any behaviour inside it. |
| over-broad | An assertion pins an outcome without its reason, for example a return code without the diagnostic. The repository's rule for this state is "Assert the meaning, not the string" in `docs/development/testing-conventions.md`. |

## Fan-out protocol

A batch of units may fan out to fresh subagents, one subagent per file or file group. The primary collects the deliverables, verifies their claims against the tree, and writes the findings back. Apply these rules to the fan-out:

- **A frozen snapshot per batch.** Each subagent reads a `git archive` of a clean committed state, not the live shared tree.
- **One suite at a time.** Suites serialize across subagents; only the mutation work runs in parallel.
- **A machine-readable findings block.** Each subagent emits a findings block beside its prose, in the register's exact columns, keyed by file plus a one-line title. The primary maps the provisional keys to row numbers in one pass and appends with a script. Never append by an `edit` anchor copied from a previous round: an anchor that matches the wrong row duplicates it.
- **A scripted post-collection check.** Run the register integrity check once per batch, and diff the deliverable's BDD blocks against the subject test file. The check is a script, not a manual read.
- **Overlap batches with presentation.** Start the next batch's compute when the current batch's deliverables land, not when its presentation finishes; the operator reads one file at a time, so presentation is serial by nature.
- **Fold in verification.** Each subagent supplies a verification section (commands, baseline, mutation count, restore confirmation). The primary re-checks only the claims that fail the scripted check or contradict the tree.

## Handling the findings, by class

Every row gets one class and one lane. The two classes that need a decision before anything lands are an interface or contract defect and a design gap: each goes to its owning design note and an ADR entry at settlement. The classes that land without a decision are the test coverage gap, the vacuous or over-broad assertion, dead code, documentation drift, a local logic defect whose correct behaviour is unambiguous, and a security defect whose fix needs no interface change. Gate a coverage fix when the subject contract is undecided, because it would pin the wrong behaviour.

A test coverage gap can land as a batch ordered by file, with the acceptance check "suite green and the named unit added". A logic defect can land as a fix only while it is local and unambiguous; the moment the fix changes a caller, a record shape, or a failure contract, it is an interface change in disguise and it moves to the gated lane.

## Close

The close has five steps:

1. **Triage every row into one sector and one disposition.** A sector owns a coherent surface; a disposition is one of fix, note, docs, observe, or accepted.
2. **Build the consolidation map.** A row joins a group only when the finding recurs, not when the class recurs. Ordinary coverage-gap rows with different subjects stay individual. Never merge a row by relabelling: a group's single disposition lives in the document that works the finding, and the row stays its evidence.
3. **Open one design note per design-class sector and one policy doc for the test-organisation sector.** Each note is its own handover. Do not mix the design lane into the immediate lane.
4. **Write the roadmap back.** The roadmap is the task list; record the fix batches, the notes, and the deferred surfaces there.
5. **Report the counts that the close asserts.** A count in a close-out, a commit message, and the roadmap must agree.

The close does not close a milestone. The milestone closes only after the operator review and the findings-to-tasks plan session have mapped the fix batches and the notes.

## Invariants

- Every unit ends with all five artifacts. A unit with no findings says so; it does not omit the findings table.
- No bite verdict is read-assessed when a mutation was practical. State the reason when it was not.
- No row is merged, renumbered, or deleted once another document cites it.
- No claim survives on argument alone: the failing unit name and the re-run are the evidence.
- The register is the source of truth; the prose sections are generated from it.
- The chat presentation is a digest. Records state, not session history.
