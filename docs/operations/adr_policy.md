---
description: "Owns the ADR record: an ADR captures the reasoning behind a standing principle -- a pattern, an interface shape, a design philosophy, an invariant, or a user-interaction contract -- including the rejected alternatives and their reasons, and links to the documentation that describes the implementation it justifies."
scope: ["docs/adr/", "docs/adr/archive/"]
---

# ADR Policy

## Relationship to other records

A concept doc states a model. The ADR states why that model was selected over alternatives. A concept doc links to its ADRs as further reading, like a paper cites references. The concept is the parent. The ADR is the explainer.

The classification of each record type -- what it contains, whether it must be current, and its durability -- is the concept document [`documentation_taxonomy.md`](../concepts/documentation_taxonomy.md).

## Unit of record

The unit of record is a standing principle. An ADR encapsulates the principles behind a set of local design choices.

Local design choices do not each spawn a file. Spawn a new ADR only when a principle governs more than one local choice, or when no existing ADR covers it.

When a local choice proves its governing principles inadequate, encourage a redesign of that ADR. Do not carve out exceptions inside the ADR.

A component may host more than one independent principle. Name each its own ADR (see Naming). An ADR belongs to a principle, not to a source file or module.

## When an ADR begins

Designs begin as discussion documents (`devlog/discussions/`). Spawn an ADR when a design settles a principle whose consequences reach beyond the change that introduced it: a contract other components must match to stay compatible, or a rule that stabilizes the coding convention for future work.

A choice that affects only one implementation detail in one file does not spawn an ADR. Its rationale, if any, rides under an existing ADR.

Write the ADR when the principle is committed or being actively resolved. It is not required to be written when code lands. It may precede or follow implementation.

Suggest an ADR when:

- The feature introduces a primitive or model other components must reason about
- The area has non-obvious invariants that cannot be stated concisely in the architecture doc
- A design doc exists for the area and is too long or branched to serve as a stable reference

Distill a design doc into an ADR:

1. Remove delivery-sequence framing -- "Change N", "prerequisite", "introduced in".
2. Remove command shapes and implementation detail that belong in the architecture doc.
3. Keep primitives, invariants, design rationale, and collision or interaction tables.
4. During active development, links to design and discussion documents are expected.

## Liveness and evolution

An ADR is the current record of one principle. When the principle changes, edit the ADR in place and keep the timeline inside the file.

### Structure

```text

# <Principle>

**Current:** YYYY-MM-DD

## Requirements

| # | Requirement | Meaning |
|---|---|---|

## YYYY-MM-DD -- <decision name>

**Decision:** <chosen option>
**Rationale:** <why>
**Rejected alternatives:** <each alternative and its rejection reason>
**Edge cases / drivers:** <boundary conditions that shaped the choice>

## <prev date> -- <prior decision name>

**Decision:** ...
**Rationale:** ...
**Rejected alternatives:** ...
**Reason superseded by <new date>:** <why the old pattern was rejected>

```

The newest entry is at the top. The entry marked `Current:` is the live decision. Entries below it are historical.

**Requirements preamble.** A principle that has accumulated invariants across entries opens with a Requirements section between the `Current:` line and the first entry: a table of standing requirements (numbered), each with a one-line meaning. Solutions in the entries are judged against these requirements by name. The preamble is optional -- a young ADR with a single entry may omit it.

**Promotion cycle.** A rejected alternative states its failure locus: intent (the idea cannot satisfy the requirements), execution (the idea is sound, the implementation failed), or neither (rejected as insufficient, e.g. superseded by a strictly better option). A rejection that surfaces a new standing requirement or edge case promotes it into the Requirements table, marked with the entry that promoted it. The next solution is judged against the expanded set.

**Sub-headers.** An entry field may use `###` sub-headers when the field is long -- for example one Rationale subsection per requirement, or one sub-section per rejected alternative. The mandated field names stay; sub-headers nest inside them.

### Editing procedure

When a principle changes:

1. Move the current entry's content to the historical position.
2. Add the new decision as the new `Current:` entry.
3. On the demoted entry, add a line saying why the old pattern was rejected for the new.
4. Condense the demoted entry where possible, especially when it applied the pattern rather than changed it. Drop mechanical detail no reader needs. Keep the decision and its reason; do not delete or rewrite its rationale.

## Statuses

A file has no single status. A living file holds current and historical entries. Only each dated entry has a status.

| Entry status | Meaning |
|---|---|
| current | the live decision for this principle |
| historical | a prior decision, superseded by a later one |

A principle that is fully superseded stops carrying a current entry. Its last entry becomes historical and the file moves to `docs/adr/archive/`.

## Archive

`docs/adr/archive/` holds ADRs awaiting review for rewrite and consolidation under a new convention, and fully-superseded ADRs. Archive file names are unchanged. Reviewing archive is a maintenance task, not a user-facing status.

## Naming

Name live ADRs by the principle they govern. Keep the name stable so other documents can link to it.

Agent: recommend multiple choices with the following naming format: `docs/adr/<principle>[-<scope>].md`. The operator should always decide the final name.

The optional `<scope>` suffix is used for specialization when a principle has specialized application for different scopes. Use hyphens as delimiters, underscores as word separators. Do not put the date or a status in the name.

## Content

Keep each dated entry in the structure template's field order: Decision, Rationale, Rejected alternatives, Edge cases / drivers.

Link reserved terms to [terminology.md](../concepts/terminology.md) on first use. Do not redefine a reserved term in the ADR.
