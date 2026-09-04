# ADR Policy

Governs files in `docs/adr/`.

## Purpose

An ADR records the reasoning behind standing principles, such as: a pattern, an interface shape, a design philosophy, an invariant, or a user-interaction contract.

An ADR includes rejected alternatives and their reasons. Such reasons could include discovered edge cases and new requirements discovered during development. It is the durable place to retrieve the justification when iterating or extending a feature.

An ADR is not meant to replace documentation. An ADR links to the documentation (in `docs/concepts` or `docs/architecture`) that describes the implementation the ADR justifies.

## Relationship to other records

| Record | Contains | Expected current? | Immutable? |
|---|---|---|---|
| handover | the work done in one session (transaction log) | no | yes |
| `docs/` (interface, architecture, conventions) | the current interface and architecture of each component | yes | no |
| `docs/concepts/` | the models the system runs on | yes | no |
| ADR | the rationale for a standing principle: the chosen option, the rejected alternatives, the reasons | yes | no |

A concept doc states a model. The ADR states why that model was selected over alternatives. A concept doc links to its ADRs as further reading, like a paper cites references. The concept is the parent. The ADR is the explainer.

## Unit of record

The unit of record is a standing principle. An ADR encapsulates the principles behind a set of local design choices.

Local design choices do not each spawn a file. Spawn a new ADR only when a principle governs more than one local choice, or when no existing ADR covers it.

When a local choice proves its governing principles inadequate, encourage a redesign of that ADR. Do not carve out exceptions inside the ADR.

A component may host more than one independent principle. Name each its own ADR (see Naming). An ADR belongs to a principle, not to a source file or module.

## When an ADR begins

Designs begin as discussion documents (`devlog/discussions/`). Spawn an ADR when a design settles a principle whose consequences reach beyond the change that introduced it: a contract other components must match to stay compatible, or a rule that stabilizes the coding convention for future work.

A choice that affects only one implementation detail in one file does not spawn an ADR. Its rationale, if any, rides under an existing ADR.

Write the ADR when the principle is committed or being actively resolved. It is not required to be written when code lands. It may precede or follow implementation.

## Liveness and evolution

An ADR is the current record of one principle. When the principle changes, edit the ADR in place and keep the timeline inside the file.

### Structure

```

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