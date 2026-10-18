---
name: numbering
description: "Apply when writing or editing a document with ordered entries, findings, questions, decisions, recommendations, sections, or a task list, and when presenting numbered options in chat. Number what is read in order; give an identity code to what is unordered, long-lived, or cited from another document. Group chat items by letter so one token names one item."
---

# numbering

A unit takes a number when a reader reads it in order and cites it in place. It takes an identity code when it is unordered, long-lived, or cited from another document. The class decides, not the unit. Every rule below names the user story it serves.

## The unit letters

Four kinds take a letter inside a document. A letter restarts at 1 in each document or report.

| Letter | Kind | What it is |
|---|---|---|
| `F` | finding | an assertion about what is wrong, with its evidence |
| `Q` | open question | something not yet decided, and who decides it |
| `D` | decision | a choice made, with the alternatives and the reason |
| `R` | recommendation | an action the record proposes and has not turned into a task |

A section is dotted and hierarchical, arabic, no trailing dot. A unit is its letter and its number, `F3`. A reference from another document is the document's identity, a slash, then the unit, `20261018-NN/F3`. A reference inside the document is the number alone.

## The scheme per class

| Class | Scheme | Form | Story |
|---|---|---|---|
| Policy | sections numbered | `3.2` | S3 |
| ADR | sections numbered; each decision a `D` unit | `3.2`, `D1` | S3 |
| Concept or reference | sections numbered where the document navigates by number | `3.2` | S3 |
| Development document | sections numbered where the document navigates by number | `3.2` | S3 |
| Handover | identity `YYYYMMDD-NN`; `F`, `Q`, `D` units | `20261018-NN/F3` | S1, S5 |
| Discussion | identity date, type, slug; `F`, `Q` units | its slug, then `/F2` | S1 |
| Roadmap | identity `M` path for a milestone, identity `T` code for a track | `M3.3.4` | S5 |
| Changelog | append-only, version order; no unit numbers | `n/a` | S4 |
| Audit report | `F`, `Q`, `R` units, restarting in the report | `surface-area/F5` | S1, S2 |
| Chat reply | grouped letters, item `A1` | `A1` | S6 |

## Chat: one token per item

A reply that presents choices groups them. Each group takes the next letter, `A`, `B`, `C`. Each item takes its group's letter and its position in that group, `A1`, `A2`, `B1`. Continue the letter across the reply; do not restart it per section.

`A1` is unique inside its reply and means one item. A reply is the scope, so a second reply starts again at `A1`. When the operator answers with a label, it resolves against the reply that carried it. If two replies could hold the same label, quote the one meant or ask; never guess.

A group of one keeps its letter: `C1`, not a bare `C`.

## Write-back: a chat label does not become a reference

A chat label is a chat-scope address. When the operator's pick lands in a record, the record states the decision and gives it a `D` number. The label survives at most once, in a provenance line that says it was a reply label:

```text
D2. Bind the naming check to the commit, not the draft.
    Chosen from reply A1 (session 01a0d321).
```

`A1` on its own is a defect, because a reader later cannot resolve it. `option B` is the same defect, and this repository has paid for it before.

## Insertion

In an open document, insert where it belongs and renumber what follows. That is one pass and it costs nothing else. In a closed record, numbers are allocation order: place the unit where it belongs and give it the next free number, so `F7` may sit above `F2`. A closed record's numbers are frozen because another document may already quote them. The roadmap never renumbers: the `T3` slot was retired without a section, and the series runs `T1`, `T2`, `T4` onward.

## Direction of flow

A derived record cites its source. A handover cites a milestone, a discussion cites a decision, a roadmap row records the finding that raised it. A durable record does not cite a transient unit, because the reference would outlive its target's scope.

## Do not number

Prose, a bullet list read once, a unit nobody cites, and a chat item inside a paragraph. An unnumbered unit is not a defect; a numbered unit with a gap is.

## The stories

Each row is a use case the rule exists for. The test `test_numbering.sh` fails when a rule cites no story, or a story is served by no rule.

| Story | The use case | Served by |
|---|---|---|
| S1 | the operator quotes one entry of a long audit and means only that entry | the class table; the unit letters |
| S2 | an item derived from a finding, a task or a question, is quoted without confusion with its source | the unit letters; direction of flow |
| S3 | an agent inserts a unit mid-document while drafting, and nothing it already wrote changes meaning | insertion; the numbered classes |
| S4 | a closed record keeps an earlier quote true after the fact | insertion; the changelog row |
| S5 | a record cites a roadmap milestone or a task without naming a position | the class table; direction of flow |
| S6 | the operator answers a set of choices with one short token, and the answer is unambiguous | chat: one token per item; write-back |

## The check

`scripts/check_numbering.sh` reads one document at a time and holds no baseline and no counter. It fails when a numbered unit skips or repeats a number, when a numbered section does not follow the one before it, and when a qualified reference names a document or a unit that does not exist. Chat labels are not in the tree, so the chat form is unenforced by the gate; the assistant applies it while writing.

## The cost

One keystroke per unit while writing, one pass over the document after an insertion, one check at commit. Nothing runs while writing.
