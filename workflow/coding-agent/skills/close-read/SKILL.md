---
name: close-read
description: Read a named set of source files and their tests with the operator, one file at a time, as a knowledge transfer. Use when the operator directs a close read; the operator does the reading and you explain.
disable-model-invocation: true
---

# close-read

A close read is a knowledge transfer, not an audit. The operator reads; you supply what makes the reading possible and take the questions. The reading is the product and the findings are its by-product.

## Scope accepted

The operator names the set: a file, a directory, a module, a functionality, or the whole tree. The grain is the operator's call and the pass is fractal, so a one-file close read and a whole-tree one follow the same procedure.

Agree the file list before the first file and state it back, so both sides read the same set. A set holding nothing that runs is a refused invocation.

## Order

Dependency order: a library that sources nothing comes before its dependents, small files before the orchestration that calls them, and the libraries before the workflows that drive them. The operator may name a different order and it stands.

## Per file

State the contract in one line before any code: what the file owns, what it refuses, what it leaves behind. Then one line per seam, stating what crosses it.

Present each function under discussion in the order the file runs it: the fragment, then what it does, then what that shows and what it leaves open. Present only the function under discussion, never the whole file, and describe what it does rather than what it should do.

Present each `test_*` unit in the frame below, and present the findings last, as titles.

## The BDD frame

A test earns its place in two ways, and the frame carries both. Test-driven development is the ordering claim: the unit exists before the behaviour, and the behaviour is shaped by what the unit can assert. Behaviour-driven development is the wording claim: a unit is stated as Given, When and Then, which are the precondition the unit assumes, the invariant under test, and the postcondition it asserts. Stating a unit that way makes a reader build the model of the code instead of accepting a verdict about it, which is why the read uses it.

The frame is also what the read writes back into the tree. Above each `test_*` function, add:

```bash
# Given: <the precondition>
# When:  <the action>
# Then:  <the observable outcome>
# Asserts: <what the unit is supposed to test>
```

Say in one line what the unit is supposed to test, and say what it does not assert, because a unit's silence is where the coverage gaps live. Nothing else about the test file changes.

## Communication style

This is a knowledge transfer, so the operator is reading to learn rather than to approve. Ask what they already know about the language, the tooling and this part of the tree, and target every explanation to that level: a reader who knows programming but not bash needs the shell idiom spelled out, and needs nothing explaining about what a function is. Say when a passage is a consequence rather than a rule, and say when you do not know.

Hand over the material rather than your summary of it. Quote the fragment, then say in one sentence what it does, and in one sentence what that shows and what it leaves open. The fragment comes first so the reader can check the description against the code, and the limit comes with the claim so the description never reads as proof. State the silent behaviour too, the part a reader cannot see from the name.

A reader in a chat window cannot scroll back and has to hold the shape in their head, which is why the contract and the seams arrive before any code. Keep to one file a turn, and present only the function under discussion rather than the whole file. End the file on its findings, numbered and no more than three, and stop there.

Do not open with a preamble, a restatement of the task, or an opinion on the code. The reading is the answer.

The unit of a turn is one file, and its shape is:

```text
<fragment>
One sentence: what it does. One sentence: what that proves, and what it does not.
```

`assets/exemplar.md` is the turn the operator called the format to keep, trimmed to these beats.

## The record and the register

A run writes two files under `workspace/output/close-read/<YYYYMMDD>-<slug>/`: `report.md`, the record of the reading, and `register.jsonl`, the findings. The operator may name another location for the pair. The schema, the classes and the derivation are in [`references/register.md`](references/register.md).

The record carries per-file sections and no count, no status line and no roll-up: a number read from the register goes stale the moment the next file lands. Derive what you need when you need it.

A read writes nothing else. No roadmap row, no design note, no task row and no fix, because scheduling a finding is what pulls a read off the reading. Dispositioning the register is a later pass that the operator opens.

## Does not judge

- whether the code is good, which the review runbooks answer
- whether a behaviour is pinned by a mutation, which this read does not run
- whether a document still describes the system, which `reference-staleness` answers
- what to do about a finding, which a later pass owns
