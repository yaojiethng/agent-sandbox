---
description: Package an eval snapshot of this session -- a frozen transcript, a complete repository bundle, the operator turn stream, the session facts and a credential scan -- so a later eval can replay and score it. Use when the operator asks to save the session state for evals, when a closed series is worth scoring later, or when the operator asks what an eval would need.
trigger: /package-eval-snapshot
---
> $@

# Package an eval snapshot

**Scope:** Writes one snapshot directory and prints the operator reply. It does not author the iteration records, it does not export the branch, and it does not run the host workflow.

## Purpose

An eval needs three things: the task stream that was given, the state the work started from, and the state it reached. The script writes all three as files, so a snapshot taken today and one taken a month from now have the same shape and can be compared. The half that needs judgement -- what an eval would score, and whether the scan found a secret -- is this prompt's.

## When to use

- The operator asks to save the session, the chat log, or the repository state for evals.
- A delivery series closes and is worth scoring later.
- **Not** for exporting work to the host branch. That is `/package-branch`. Run it first when the state is worth exporting, and name its bundle in the README.

## Step 1 -- Choose the summary

`--snapshot-summary` names the snapshot directory. The shape is enforced: **3 to 48 characters, lowercase snake_case**, matched by `^[a-z0-9]+(_[a-z0-9]+)*$`. A prose phrase is rejected at the script.

Derive it from the commit subjects in the series, or from the session's subject when no series closed. State the summary you chose before running.

| Good | Bad |
|---|---|
| `instruction_surface_contract` | `Session with names` -- spaces, capitals |
| `task_queue_primitive` | `snapshot` -- too vague to name a session |

## Step 2 -- Run the script

```bash
bash /opt/sandbox/lib/package_eval_snapshot.sh --to=$HOME/workspace/output --snapshot-summary=<summary>
```

It writes `<to>/evals/<export-time>-<summary>-<session-id>/` holding:

| File | What it is |
|---|---|
| `chat.jsonl` | the transcript, byte-identical and point-in-time |
| `operator-turns.md` | the operator turns in order, one block each |
| `repo.bundle` | every ref, complete; an eval can clone it alone |
| `bundle-verify.txt` | the verification output naming the refs |
| `commits.txt` | the commit series from the base to HEAD |
| `eval-point.json` | the session facts, machine-readable |
| `credentials-scan.txt` | pattern counts, never a matched value |
| `.snapshot-status` | the machine-readable half of the reply block |

**Echo the script's output block verbatim.** Every value in it was computed from the repository and the environment; a paraphrase can carry a wrong base commit to the operator.

## Step 3 -- Triage the credential scan

Read `credentials-scan.txt`. The report holds a count per pattern and never a value.

A non-zero count is usually the scan itself: the transcript holds the command that ran the scan and the report it wrote, so the pattern text appears in both. Every other pattern's hit traces to one of those two, or to a policy or provider document that names a variable rather than a value.

When a count has no such explanation, the snapshot carries a credential. Stop, and tell the operator before the snapshot is read or shared: name the pattern, the count, and that the transcript cannot be redacted without changing the record. The file is theirs to delete; deleting one file from the snapshot does not make the transcript clean.

## Step 4 -- Write the README

Write `README.md` in the snapshot directory. The script writes no README, because its substance is a judgement about the session: what an eval would score, and which records hold the answer.

| Section | Content |
|---|---|
| The point | the session, the provider, the model and the thinking level, the base commit, the head commit, the branch, and what the session delivered, from `eval-point.json` |
| What is here | one row per artefact |
| How to use it | clone the bundle, replay the operator turns, score against the acceptance criteria the session's handovers list |
| The graded moments | the decisions the session made that an eval can score, each with the record that holds it. A redirection by the operator, a silent defect found in a record, a mechanism verified before adoption -- name the moment, what it tests, and where it is recorded |
| Provenance | the scan result in one sentence, and the fact that the transcript copy is point-in-time while the live session file kept growing |

## Step 5 -- Report

Print the snapshot path, its size, the artefact list, the scan result in one line, and the sibling bundle when `/package-branch` ran in this session. Name the base commit and whether the branch point moved.

## Non-goals

- Does not export the branch, apply anything on the host, or run the review workflow.
- Does not edit the handover, the roadmap, or any record.
- Does not redact the transcript. The record is the point of it, and the scan's report is what makes a secret visible.
