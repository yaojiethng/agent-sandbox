# Documentation Pass

**Status:** stub

A documentation pass is a dedicated review sweep that tests documents for policy compliance using the diagnostic checklists below. This document is a stub: it marks the home of the pass and carries its initial checklist content. It has not been expanded into a full procedure (trigger, scope, cadence, close-out) -- that expansion is deferred until the pass is first run.

The checklists are diagnostic -- they identify what has gone wrong, not what to do instead. The corresponding prescriptive rules for documents are in [`documentation_policy.md`](../../docs/operations/documentation_policy.md); rules governing skill files and prompt templates are in [`agent_workflow.md`](../../docs/concepts/agent_workflow.md#how-the-workflow-is-expressed). The canonical owner test appears in both `### Document depth and verbosity` (prescriptive) and here (diagnostic) -- this is intentional; the two registers serve different readers.

## Checklist

**Canonical owner test.** When a rule appears in two documents, ask: which document will an agent read when they need this rule? That document is the canonical owner. The other should link to it, not restate it.

**Signs of duplication to check:**
- The same constraint stated in both a workflow table cell and a child policy section
- Exit conditions in iteration_policy that restate rules already in handover_policy
- Index maintenance rules appearing outside project_index.md
- Temperature definitions appearing outside project_index.md

**Signs of misplaced content to check:**
- Future language (`will`, `plan`, `eventually`) in any `architecture/` document
- TODO items in any `architecture/` document
- Prescriptive rules in a skill file or prompt template with no corresponding entry in a policy document
- A rule that only exists in a skill file -- skills are fast paths, not sources of truth

**Signs of structural problems to check:**
- A section an agent would need to locate in isolation that has no `##` or `###` header
- A document that must be read in full to extract one fact
- A bridge document -- one that exists solely to connect two documents that could reference each other directly
- A document-level reference link carrying a section anchor -- anchors on document-level references imply narrower scope than intended
- Prose with a hard line break that does not fall on a sentence or paragraph boundary
- A word, phrase, or sentence a reader can delete without changing the required meaning
- Non-ASCII punctuation or a control/formatting symbol (for example `§` or `¶`) in any document
