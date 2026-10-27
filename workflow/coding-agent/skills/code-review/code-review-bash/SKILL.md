---
name: code-review-bash
description: Review shell code against this repository's bash pattern set. Use when a change touches a shell script and needs a review, or when the operator asks for a bash review.
disable-model-invocation: true
---

# code-review-bash

A review of shell code. The standard is the pattern set beside this file, in `patterns/`: every finding names the entry it rests on, and the entry states what the wrong form does and what to report instead.

## Scope accepted

Two kinds.

A delta is the branch's changes read as a diff, and it resolves to the shell files the diff touches. A set is a list of named paths, and it resolves to the shell files those paths name, whether they are tracked, untracked or both.

A scope holding no shell file is a refused dispatch rather than an approving review.

## Focus

Focus narrows a run. A caller may state any of these, and nothing else:

- the library files only, meaning the ones written to be sourced by another script, where a failure reaches a caller rather than an operator
- the entry points only, meaning the scripts an operator or a container runs
- the test harness only, meaning the suite's own shell files
- one subject of the pattern set, named by the entries it covers: the failure-handling entries, or the two that govern a library against its caller, `p-13` and `p-27`

Anything outside the stated focus is a refused dispatch, not a finding. A shell file the delta does not touch is out of scope even when it holds the same fault.

## Returns

One finding per line: the file and line, the entry id, the wrong form as the code states it, and the form to write instead. Where the entry has no fence, the finding quotes the statement it fails.

The report opens with the scope read and the entries applied, and it carries the attribution, the scope and the log this environment requires. A fault with no entry behind it is an observation, listed under its own heading with the reason no entry covers it, because an observation is how the set grows and a finding needs a citation.

## Verdict

One verdict per run. `HOLD` when any finding is a failure path, a masked status or a success the command did not achieve; `APPROVE` otherwise. A HOLD names the finding that fails. A narrowed run gives no verdict, because the scope did not cover the whole subject.

## Does not judge

- container image construction, which is a Dockerfile's subject
- the interface conventions a script's output must satisfy, except where the script emits what they govern
- whether a test asserts the right thing, which is the suite's convention
- anything a formatter settles, such as indentation, alignment or line length
