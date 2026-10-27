---
name: code-review-container
description: Review container image construction against this repository's Dockerfile pattern set. Use when a change touches a Dockerfile or an image build and needs a review, or when the operator asks for a container review.
disable-model-invocation: true
---

# code-review-container

A review of image construction. The standard is the pattern set beside this file, in `patterns/`: every finding names the entry it rests on, and the entry states what the wrong form does and what to report instead.

## Scope accepted

Two kinds.

A delta is the branch's changes read as a diff, and it resolves to the files the diff touches whose subject is an image build: a `Dockerfile`, a `*.dockerfile`, or a build file a Dockerfile includes. A set is a list of named paths, and it resolves to those files among the paths, whether they are tracked, untracked or both.

A scope holding no image build is a refused dispatch rather than an approving review.

## Focus

Focus narrows a run. A caller may state any of these, and nothing else:

- one image only, named by its file, where a build graph spans several
- the runtime contract of an image, meaning its user, its work directory and its entrypoint
- the layer construction, meaning its base, its package installs and its copies
- one subject of the pattern set, named by the entries it covers: the privilege entries, or the two that decide what the built image carries, `p-49` and `p-53`

Anything outside the stated focus is a refused dispatch, not a finding. An image file the delta does not touch is out of scope even when it holds the same fault.

## Returns

One finding per line: the file and line, the entry id, the wrong form as the file states it, and the form to write instead. Where the entry has no fence, the finding quotes the statement it fails.

The report opens with the scope read and the entries applied, and it carries the attribution, the scope and the log this environment requires. A fault with no entry behind it is an observation, listed under its own heading with the reason no entry covers it, because an observation is how the set grows and a finding needs a citation.

## Verdict

One verdict per run. `HOLD` when any finding is a floating base image, a privilege that survives into the running container, or an image that produces a runtime with no `USER`; `APPROVE` otherwise. A HOLD names the finding that fails. A narrowed run gives no verdict, because the scope did not cover the whole subject.

## Does not judge

- the shell logic a build runs or an entrypoint script contains, which `code-review-bash` and the pattern set beside it answer
- what a registry or a pipeline does with the built image, which no file in the scope states
- the orchestration a deployment wraps the image in
- image size as a goal of its own, except where an entry names a copy that a build does not need
