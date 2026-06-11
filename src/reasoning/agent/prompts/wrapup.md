---
description: Close a session. Runs Steps 7b, 8, and 9 of the minor loop (iteration_policy.md) — verifies acceptance criteria, runs propagation replay if applicable, reconciles scope, marks the roadmap, checks Trigger B, closes the handover, and seeds the next session. Use when implementation is complete and you are ready to close.
---

Running Steps 7b, 8, and 9 of the [minor loop](docs/operations/iteration_policy.md).

**AC verification (Step 7b gate):** Read the acceptance criteria from the active handover. For each criterion, state what was checked, what the result was, and whether it passes. If any criterion fails, stop — do not proceed to close until the gap is resolved or explicitly deferred with a reason.

**Propagation replay (Step 7b gate, if applicable):** If this session applied a change across multiple files under a shared rule — naming, structural convention, interface rename — produce a propagation replay table: `file | change planned | status`. Every row must have a status of `completed`, `deferred`, or `not started`. Any row that is not `completed` must appear in Deferred items before this gate closes. If no propagation check applies, state that explicitly.

**Do not proceed past this point until the operator releases the gate** (e.g. "proceed", "close the session").

**Scope reconciliation (Step 8):** Compare the confirmed scope from session open against the Completed this session table. Every item that was in scope but is not completed must appear in Deferred items with what it is, why it did not complete, and where it goes next.

**Roadmap and index update (Step 8):** Mark completed tasks `[x]` in `roadmap.md`. Update `project_index.md` for every file in the Completed this session table. Verify every in-scope architecture and concepts document describes the system as built — divergences must be resolved or recorded as deferred items that block Trigger B.

**Trigger B check (Step 8):** If all sub-milestone tasks are complete, all AC are met, and no doc divergence is deferred, run Trigger B per `roadmap_policy.md`. Otherwise state why it does not apply.

**Close the handover (Step 8):** Mark each AC as accepted or pushed to next session. Complete the Completed this session and Deferred items sections. Update Hot files. Set Status to `Closed`.

**Seed next session (Step 9):** Populate the Next session section per `handover_policy.md`. If the completed sub-milestone was the last in the major milestone, write: "Major loop required before next session."
