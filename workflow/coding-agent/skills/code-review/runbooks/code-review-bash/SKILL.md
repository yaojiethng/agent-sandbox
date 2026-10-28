---
name: code-review-bash
description: Review shell code against this repository's bash pattern set. Use when a change touches a shell script and needs a review, or when the operator asks for a bash review.
disable-model-invocation: true
---

# code-review-bash

A review of shell code. The standard is the pattern set beside this file, in `patterns/`: every finding names the entry it rests on, and the entry states what the wrong form does and what to report instead.

General shell style is the one subject the set does not restate: the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) is authoritative for naming, quoting, `local` and `readonly`, function and command-substitution form, flags, and output to stderr. Where a pattern entry and the guide meet on a project-specific convention, the entry wins, and the set's own entries are the reason this review exists.

## Scope accepted

Two kinds.

A delta is the branch's changes read as a diff, and it resolves to the shell files the diff touches. A set is a list of named paths, and it resolves to the shell files those paths name, whether they are tracked, untracked or both.

A scope holding no shell file is a refused dispatch rather than an approving review.

## Returns

One finding per line: the file and line, the entry id, the wrong form as the code states it, and the form to write instead. Where the entry has no fence, the finding quotes the statement it fails.

The report opens with the scope read and the entries applied, and it carries the attribution, the scope and the log this environment requires. A fault with no entry behind it is an observation, listed under its own heading with the reason no entry covers it, because an observation is how the set grows and a finding needs a citation.

## Verdict

One verdict per run. `HOLD` when any finding is a failure path, a masked status or a success the command did not achieve; `APPROVE` otherwise. A HOLD names the finding that fails.

## Does not judge

- container image construction, which is a Dockerfile's subject
- the interface conventions a script's output must satisfy, except where the script emits what they govern
- whether a test asserts the right thing, which [`test-review`](../test-review/SKILL.md) judges
