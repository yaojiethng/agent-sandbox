---
name: test-review
description: Review a test change for evidence value -- a test that cannot fail catches nothing. Use when a diff adds or edits tests, or when a named test file is suspected of proving nothing.
disable-model-invocation: true
---

# test-review

A test is evidence or it is noise. This review asks one question of every assertion: would it fail if the behaviour it names were broken? A test that cannot turn red is deleted, not softened.

## Scope accepted

A delta: the tests in a commit range, `git diff <base>..<head> -- 'tests/**'`. Or a named set: test files given by path.

The behaviour under test is not the subject. A defect a test exposes is reported and left for the change that owns it.

## The criteria

One finding per form. Each names the file, the line and the assertion.

- **Change-mirror.** The assertion restates the change instead of the behaviour: it names the string that was added or removed, so it fails only when the edit is reverted.
- **Tautology.** The assertion restates its own setup: a value the test wrote, a mock returning its own stub, a check whose failure modes the fixture already ruled out.
- **Dead.** Defined but never registered with `run_test`, or left behind by a removed feature.
- **File-exists.** The assertion is that a file, directory or string is present, with no claim about its content or behaviour.
- **String-presence.** The assertion searches the source for a phrase rather than exercising the behaviour the phrase describes.
- **Removed feature.** The test exercises a path the product no longer has.
- **Pin with no record.** The assertion pins an output string or a count, and no ADR, design record or handover explains why it must not change.
- **Lock-step edit.** The test was edited in the same change as an output contract, with no propagation checklist, so it follows the change instead of holding it.
- **Cannot turn red.** The assertion is true whether or not the behaviour works: an unreachable branch, a guard the fixture guarantees, an awaited call that cannot fail.

## Proof

A finding without a demonstration is an opinion, and is not filed. For each one, show one of:

- the behaviour reverted, the assertion still green;
- the assertion restated in one sentence, and what it would take to fail;
- the record that would make a pin legitimate, and that it is absent.

Quote the assertion. Name the defect the test would miss.

## Voice

- **Direct.** Name the defect: "this asserts its own setup", not "this could be stronger".
- **Attributed.** Name the file, the line and the assertion.
- **Demonstrated.** The proof above, not a paraphrase of it.
- **Prioritised.** Blind evidence first, then a weak test, then a note. Never bury a green-but-blind test among observations.
- **Disposed.** Every finding ends in delete, rewrite, or keep with the reason.
- **Deletion is the default.** A test that proves nothing is worse than no test: it is green evidence that is not evidence.
- **Concrete.** Show the replacement assertion or the deletion; the report carries it, the caller applies it.

## Returns

A report: the scope read; each finding with its criterion, location, proof and disposition; and the files read with nothing found. A zero-finding run names what was checked and why the evidence holds.
