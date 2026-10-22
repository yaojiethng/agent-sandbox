---
name: decision-records
description: agent-sandbox's decision-records convention - the architecture decision records, their unit and naming, the entry structure, the statuses and the archive.
---

# decision-records

An ADR records the reasoning behind one standing principle. It states the chosen option, the rejected alternatives and why each was rejected. The classification across record kinds is [`documentation_taxonomy.md`](../../../docs/reference/documentation_taxonomy.md).

## Judgements

- **Unit of record.** One ADR per standing principle. A local design choice rides under an existing ADR; it spawns a file only when its principle governs more than one local choice, or when no existing ADR covers it. A component may host several independent principles, each its own ADR, because an ADR belongs to a principle rather than to a file or module.
- **When one begins.** A design settles a principle whose consequences reach beyond the change that introduced it: a contract other components must match to stay compatible, or a rule that stabilizes a convention for future work. Reach, not size. A choice that affects one implementation detail in one file does not spawn an ADR.
- **Change the principle, change the record.** When a local choice outgrows its governing ADR, redesign the ADR. Do not carve out an exception inside it.
- **The record is current.** An ADR holds the live decision and its history. When the principle changes, edit it in place.

## Where to look

| File | Open when |
|---|---|
| [`assets/adr.md`](assets/adr.md) | you open a new ADR or add an entry |
| [`patterns/distil.md`](patterns/distil.md) | a discussion or design document settles into an ADR |
| [`patterns/evolve.md`](patterns/evolve.md) | the principle changes and the ADR absorbs the new decision |

## The record set

A concept document states a model; its ADR states why that model beat its alternatives. The concept is the parent and links its ADRs as further reading. The ADR does not restate the model.

## What an entry holds

The newest entry sits at the top. The entry marked `Current:` is the live decision, and the entries below it are historical. Each entry keeps the template's field order: Decision, Rationale, Rejected alternatives, Edge cases / drivers.

- **Requirements preamble.** A principle that has accumulated invariants across entries opens with a numbered requirements table between the `Current:` line and the first entry. The entries are judged against those requirements by name. The preamble is optional, and a young ADR with one entry may omit it.
- **A rejection states its failure locus.** Intent (the idea cannot satisfy the requirements), execution (the idea is sound and its implementation failed), or neither (rejected as insufficient, for example superseded by a strictly better option). A rejection that surfaces a new standing requirement promotes it into the requirements table, marked with the entry that promoted it.
- **Sub-headers.** A long entry field may use `###` sub-headers, for example one subsection per rejected alternative. The mandated field names stay, and the sub-headers nest inside them.
- **Reserved terms** link to [`terminology.md`](../../../docs/reference/terminology.md) on first use, and the ADR does not redefine them.

## Current and historical

A file has no single status: each dated entry carries its own.

| Entry status | Meaning |
|---|---|
| current | the live decision for this principle |
| historical | a prior decision, superseded by a later one |

A principle that is fully superseded stops carrying a current entry. Its last entry becomes historical, and the file moves to the archive.

## Naming

Name a live ADR for the principle it governs, and keep the name stable so other documents can link to it. The form is `docs/adr/<principle>[-<scope>].md`. Use hyphens as delimiters and underscores as word separators, and put no date or status in the name. The optional `<scope>` suffix specializes a principle for a different scope. The agent recommends the name, and the operator decides it.

## Archive

`docs/adr/archive/` holds ADRs awaiting review for rewrite and consolidation, and fully superseded ADRs. A file keeps its name when it moves. Reviewing the archive is maintenance, not a status.
