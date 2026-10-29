---
name: principle-approval-writes-the-artifact
description: Write an approved artifact into the file that is its source of truth in the same unit of work as the approval, so the decision never lives only in the conversation. Use when a design, a scope, a plan, or a set of items will be produced later.
---

# An approval writes the artifact

When a decision approves an artifact, write it into the file that is its source of truth, in the same unit of work as the approval.

**The pattern.** This rule assumes version control, because it is what makes writing cheap. Where the tree has none, the file is the only copy, and writing it early matters more rather than less.

Name where the approved artifact lives before you move on. If the answer is the conversation, write it now, into the file that will carry it.

Writing the file costs nothing that cannot be undone. Holding the decision in the conversation is the expensive choice: it cannot be reverted, resumed or checked, and the task stalls while the work waits in it.

Edit the file in place. Do not park a copy beside it, and do not write a note that a later step will turn into the file. A parked copy is a second source of truth, and a note is re-derived by whoever reads it later.

A batch of approvals edits the live files as each item is approved. One file rewritten once per item is the accepted cost.

**Why.** The conversation does not travel with the work, compaction is lossy, and a re-typed clause fails no gate. Git holds the undo, so a written file is recoverable, and a copy kept beside it is one more thing to keep current.

This rule is the sum of four that each look local, which is why a batch shape survives review. A decision has one source of truth. Work is sequenced into units that each end green. Verification reads the real artifact rather than a re-telling. Context holding approved work that is not yet written is context at risk.

**What it does not cover.** A decision whose output is not an artifact. A preference, a direction, a refusal, and a scope boundary are durable as a record entry. The rule forbids approving an artifact and continuing. It does not forbid deciding and continuing.

**The test.** Point at the file, and at the diff that put the artifact in it. If there is no diff, the approval did not land.
